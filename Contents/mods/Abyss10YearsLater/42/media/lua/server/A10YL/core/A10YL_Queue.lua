local Config = require("A10YL/core/A10YL_Config")
if type(Config) ~= "table" then
    Config = A10YL_Config
end
local Processor = require("A10YL/core/A10YL_Processor")
local Debug = require("A10YL/core/A10YL_Debug")
local Persistence = require("A10YL/core/A10YL_Persistence")
local Text = require("A10YL/A10YL_Translation")
local Random = require("A10YL/core/A10YL_Random")
local ExistingWorld = require("A10YL/core/A10YL_ExistingWorld")
local Cache = require("A10YL/core/A10YL_Cache")
local AreaContext = require("A10YL/core/A10YL_AreaContext")

local Queue = {}

-- B42.20.4's documented IsoChunkMap contract is 8x8 squares per chunk.
-- Do not read the Java static chunk-size field from Lua: although the Java
-- API exposes it as a public static final field, B42.20.4 does not reliably
-- surface that field through Kahlua. The previous visibility check therefore
-- disabled ageing on a valid 42.20.4 runtime.
local B42_CHUNK_SIZE = 8

-- v0.8.2 keeps the accepted v0.6.7/v0.7.0 processing envelope for normal modes,
-- retains v0.8.0/v0.8.1 optimisation work, and exposes a bounded pre-age lane
-- for selected admin warm-up jobs.
local CORE_RADIUS_CHUNKS = 3
local INNER_RADIUS_CHUNKS = 8
local VISIBLE_RADIUS_CHUNKS = 24
local OUTER_VISIBLE_RADIUS_CHUNKS = 36

-- Time remains the primary safety valve. Live testing left substantial headroom,
-- so foreground throughput is raised again while hard counters remain only as
-- runaway/corruption guards.
local STREAMING_PRESETS = {
    [1] = { discoveryChecksPerTick = 384, plansPerTick = 48, mutationsPerTick = 192, timeBudgetMs = 5.0 },
    [2] = { discoveryChecksPerTick = 768, plansPerTick = 96, mutationsPerTick = 384, timeBudgetMs = 12.0 },
    [3] = { discoveryChecksPerTick = 1152, plansPerTick = 144, mutationsPerTick = 576, timeBudgetMs = 16.0 },
}

local NEAR_PLAYER_PRESETS = {
    [1] = { discoveryChecksPerTick = 768, plansPerTick = 96, mutationsPerTick = 384, timeBudgetMs = 8.0 },
    [2] = { discoveryChecksPerTick = 1536, plansPerTick = 192, mutationsPerTick = 768, timeBudgetMs = 18.0 },
    [3] = { discoveryChecksPerTick = 2304, plansPerTick = 288, mutationsPerTick = 1152, timeBudgetMs = 24.0 },
}

-- Trigger urgent frontier pressure earlier, before the player reaches the visible
-- ageing boundary rather than after a large high-priority backlog has formed.
local FRONTIER_PRESSURE_THRESHOLD = 16
local FRONTIER_PRESSURE_PRESETS = {
    [1] = { discoveryChecksPerTick = 1536, plansPerTick = 192, mutationsPerTick = 768, timeBudgetMs = 12.0 },
    [2] = { discoveryChecksPerTick = 3072, plansPerTick = 384, mutationsPerTick = 1536, timeBudgetMs = 28.0 },
    [3] = { discoveryChecksPerTick = 4608, plansPerTick = 576, mutationsPerTick = 2304, timeBudgetMs = 36.0 },
}

-- Teleports get a minimum boost long enough for new chunks to arrive, then stay
-- in catch-up only while the current target's high/visible backlog remains. A
-- hard maximum prevents a pathological map/mod interaction from monopolising
-- the server indefinitely. Old-location jobs are demoted on the same movement
-- pass, so they cannot steal the teleport budget from the new destination.
local TELEPORT_THRESHOLD_CHUNKS = 6
local TELEPORT_CATCHUP_MIN_MS = 2000
local TELEPORT_CATCHUP_MAX_MS = 30000
local TELEPORT_CATCHUP_MIN_TICKS = 120
local TELEPORT_CATCHUP_MAX_TICKS = 1800
local CATCHUP_PRESETS = {
    [1] = { discoveryChecksPerTick = 3072, plansPerTick = 384, mutationsPerTick = 1536, timeBudgetMs = 18.0 },
    [2] = { discoveryChecksPerTick = 6144, plansPerTick = 768, mutationsPerTick = 3072, timeBudgetMs = 45.0 },
    [3] = { discoveryChecksPerTick = 8192, plansPerTick = 1024, mutationsPerTick = 4096, timeBudgetMs = 55.0 },
}

local PRIORITY_RANK = { normal = 1, outer = 2, visible = 3, high = 4 }

local IMMEDIATE = {
    discoveryChecksPerTick = 131072,
    plansPerTick = 131072,
    mutationsPerTick = 131072,
    timeBudgetMs = 10000.0,
    readyLowWater = 131072,
    readyHighWater = 262144,
    operationChecksPerTick = 524288,
    readyChecksPerTick = 262144,
}
local IMMEDIATE_PASS_GUARD = 262144

local state = {
    disabled = false,
    chunkSize = B42_CHUNK_SIZE,

    generationConfig = nil,
    schedulerBudget = nil,
    existingSaveMode = ExistingWorld.MODE_NEW_AREAS_ONLY,
    existingSaveModeName = "New Areas Only",

    chunkQueue = {},
    chunkHead = 1,
    chunkTail = 0,
    outerChunkQueue = {},
    outerChunkHead = 1,
    outerChunkTail = 0,
    visibleChunkQueue = {},
    visibleChunkHead = 1,
    visibleChunkTail = 0,
    highChunkQueue = {},
    highChunkHead = 1,
    highChunkTail = 0,
    chunkKeys = {},
    seenChunks = {},
    pendingChunkJobs = 0,
    highPendingChunks = 0,
    visiblePendingChunks = 0,
    outerPendingChunks = 0,
    immediateJob = nil,
    playerChunkSignature = nil,
    lastPlayerChunks = nil,
    catchupMinUntilMs = 0,
    catchupDeadlineMs = 0,
    catchupMinTicksRemaining = 0,
    catchupMaxTicksRemaining = 0,

    readyQueue = {},
    readyHead = 1,
    readyTail = 0,
    outerReadyQueue = {},
    outerReadyHead = 1,
    outerReadyTail = 0,
    visibleReadyQueue = {},
    visibleReadyHead = 1,
    visibleReadyTail = 0,
    highReadyQueue = {},
    highReadyHead = 1,
    highReadyTail = 0,
    readyJobsCount = 0,
    highReadyCount = 0,
    visibleReadyCount = 0,
    outerReadyCount = 0,
    squareState = {},
    squareJobs = {},

    active = nil,
    failures = {},
    refillEnabled = true,
    warmupActive = false,
    preAgeActive = false,

    runtimeSmoke = {
        firstChunk = false,
        firstPlan = false,
        firstMutation = false,
        firstFeatureMutation = false,
        firstCompletion = false,
    },

    stats = {
        chunksQueued = 0,
        discoveryChecks = 0,
        squaresQueued = 0,
        plansBuilt = 0,
        operationChecks = 0,
        mutationsApplied = 0,
        featureMutationsApplied = 0,
        featureOperationsPlanned = 0,
        squaresCompleted = 0,
        squaresDroppedUnloaded = 0,
        squaresQuarantined = 0,
        peakPendingChunks = 0,
        peakReadySquares = 0,
        peakOperationsPerPlan = 0,
        teleportCatchups = 0,
        upperSquaresSkipped = 0,
        preAgeChunksQueued = 0,
    },
}

local function nowMs()
    if type(getTimestampMs) == "function" then
        local ok, value = pcall(getTimestampMs)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

local function elapsedMs(startMs)
    if startMs == 0 then return 0 end
    local current = nowMs()
    if current == 0 then return 0 end
    return current - startMs
end

local function timeAvailable(startMs, budget)
    return elapsedMs(startMs) < budget.timeBudgetMs
end

local function compact(queueName, headName, tailName)
    local head = state[headName]
    local tail = state[tailName]

    -- The common discovery pattern is pop-one/requeue-one. When the pop makes
    -- the queue temporarily empty, reset the numeric cursors in O(1) and reuse
    -- the existing table. Without this, a long exploration session steadily
    -- advances indices and periodically allocates a replacement queue table.
    if head > tail then
        state[headName] = 1
        state[tailName] = 0
        return
    end

    if head <= 256 or head <= math.floor(tail / 2) then
        return
    end

    local old = state[queueName]
    local new = {}
    local newTail = 0
    for i = head, tail do
        local value = old[i]
        if value ~= nil then
            newTail = newTail + 1
            new[newTail] = value
        end
    end

    state[queueName] = new
    state[headName] = 1
    state[tailName] = newTail
end

local function push(queueName, tailName, value)
    state[tailName] = state[tailName] + 1
    state[queueName][state[tailName]] = value
end

local function pop(queueName, headName, tailName)
    if state[headName] > state[tailName] then
        return nil
    end

    local value = state[queueName][state[headName]]
    state[queueName][state[headName]] = nil
    state[headName] = state[headName] + 1
    compact(queueName, headName, tailName)
    return value
end

local function readyCount()
    return state.readyJobsCount or 0
end

local function pendingChunkCount()
    return state.pendingChunkJobs or 0
end

local function integer(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    if value >= 0 then return math.floor(value) end
    return math.ceil(value)
end

local function chunkKey(wx, wy)
    return tostring(wx) .. ":" .. tostring(wy)
end

local function squareKey(x, y, z)
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

local function collectPlayerChunkPositions()
    local result = {}

    local function addPlayer(player)
        if not player or type(player.getX) ~= "function" or type(player.getY) ~= "function" then
            return
        end
        local okX, x = pcall(function() return player:getX() end)
        local okY, y = pcall(function() return player:getY() end)
        local okZ, z = pcall(function() return player:getZ() end)
        x = okX and tonumber(x) or nil
        y = okY and tonumber(y) or nil
        z = okZ and tonumber(z) or 0
        if x == nil or y == nil then return end
        result[#result + 1] = {
            wx = math.floor(x / B42_CHUNK_SIZE),
            wy = math.floor(y / B42_CHUNK_SIZE),
            z = integer(z, 0),
        }
    end

    if type(isServer) == "function" and isServer() and type(getOnlinePlayers) == "function" then
        local ok, players = pcall(getOnlinePlayers)
        if ok and players and type(players.size) == "function" and type(players.get) == "function" then
            for i = 0, players:size() - 1 do addPlayer(players:get(i)) end
        end
    elseif type(getSpecificPlayer) == "function" then
        local ok, player = pcall(getSpecificPlayer, 0)
        if ok then addPlayer(player) end
    end

    return result
end

local function classifyChunkPriority(wx, wy, players)
    players = players or collectPlayerChunkPositions()
    local best = "normal"
    local bestRank = PRIORITY_RANK.normal
    for i = 1, #players do
        local dx = math.abs(wx - players[i].wx)
        local dy = math.abs(wy - players[i].wy)
        local distance = math.max(dx, dy)
        if distance <= CORE_RADIUS_CHUNKS then
            return "core"
        end

        local candidate = "normal"
        if distance <= INNER_RADIUS_CHUNKS then
            candidate = "high"
        elseif distance <= VISIBLE_RADIUS_CHUNKS then
            candidate = "visible"
        elseif distance <= OUTER_VISIBLE_RADIUS_CHUNKS then
            candidate = "outer"
        end
        local rank = PRIORITY_RANK[candidate] or PRIORITY_RANK.normal
        if rank > bestRank then
            best, bestRank = candidate, rank
        end
    end
    return best
end

local function normalizedPriority(priority)
    return PRIORITY_RANK[priority] and priority or "normal"
end

local function demotePriority(priority, steps)
    priority = normalizedPriority(priority)
    steps = math.max(0, integer(steps, 0))
    local order = { "normal", "outer", "visible", "high" }
    local rank = PRIORITY_RANK[priority] or 1
    return order[math.max(1, rank - steps)]
end

-- Ground terrain keeps the horizontal priority unchanged. First upper floors
-- remain foreground so ordinary two-storey houses age naturally. Higher
-- interiors become background unless a player is on/next to that Z level, while
-- tall-building exterior envelopes stay visible-priority but do not compete with
-- ground terrain. This preserves Louisville-scale buildings without making every
-- roof/floor level equally urgent.
local function priorityForSquare(basePriority, z, workClass, players)
    basePriority = normalizedPriority(basePriority)
    z = integer(z, 0)
    if z == 0 then return basePriority end

    players = players or collectPlayerChunkPositions()
    local nearestZ = nil
    for i = 1, #players do
        local dz = math.abs(z - (integer(players[i].z, 0)))
        if nearestZ == nil or dz < nearestZ then nearestZ = dz end
    end
    if nearestZ ~= nil and nearestZ <= 1 then return basePriority end

    if z == 1 then return basePriority end
    if workClass == "envelope" then return demotePriority(basePriority, 1) end
    return "normal"
end

local function buildLevelOrder(minZ, maxZ, players)
    local levels, used = {}, {}
    local function add(z)
        z = integer(z, nil)
        if z ~= nil and z >= minZ and z <= maxZ and not used[z] then
            used[z] = true
            levels[#levels + 1] = z
        end
    end

    add(0)
    players = players or collectPlayerChunkPositions()
    for i = 1, #players do
        local z = integer(players[i].z, 0)
        add(z)
        add(z - 1)
        add(z + 1)
    end
    add(1)
    add(-1)
    for z = math.max(2, minZ), maxZ do add(z) end
    for z = math.min(-2, maxZ), minZ, -1 do add(z) end
    return levels
end

local function adjustPendingPriority(priority, delta)
    priority = normalizedPriority(priority)
    if priority == "high" then
        state.highPendingChunks = math.max(0, state.highPendingChunks + delta)
    elseif priority == "visible" then
        state.visiblePendingChunks = math.max(0, state.visiblePendingChunks + delta)
    elseif priority == "outer" then
        state.outerPendingChunks = math.max(0, state.outerPendingChunks + delta)
    end
end

local function adjustReadyPriority(priority, delta)
    priority = normalizedPriority(priority)
    if priority == "high" then
        state.highReadyCount = math.max(0, state.highReadyCount + delta)
    elseif priority == "visible" then
        state.visibleReadyCount = math.max(0, state.visibleReadyCount + delta)
    elseif priority == "outer" then
        state.outerReadyCount = math.max(0, state.outerReadyCount + delta)
    end
end

local function queueChunkJob(job)
    if not job then return end
    local lane = normalizedPriority(job.priority)
    job.queuedLane = lane
    if lane == "high" then
        push("highChunkQueue", "highChunkTail", job)
    elseif lane == "visible" then
        push("visibleChunkQueue", "visibleChunkTail", job)
    elseif lane == "outer" then
        push("outerChunkQueue", "outerChunkTail", job)
    else
        push("chunkQueue", "chunkTail", job)
    end
end

local function popValidChunkFrom(queueName, headName, tailName, lane)
    while true do
        local job = pop(queueName, headName, tailName)
        if not job then return nil end
        if job.queuedLane == lane and state.chunkKeys[job.key] == job then
            job.queuedLane = nil
            return job
        end
    end
end

local function popChunkJob()
    local job = popValidChunkFrom("highChunkQueue", "highChunkHead", "highChunkTail", "high")
    if job then return job end
    job = popValidChunkFrom("visibleChunkQueue", "visibleChunkHead", "visibleChunkTail", "visible")
    if job then return job end
    job = popValidChunkFrom("outerChunkQueue", "outerChunkHead", "outerChunkTail", "outer")
    if job then return job end
    return popValidChunkFrom("chunkQueue", "chunkHead", "chunkTail", "normal")
end

local function queueReadyJob(job, alreadyCounted)
    if not job then return false end
    local lane = normalizedPriority(job.priority)
    job.priority = lane
    job.queuedLane = lane
    if lane == "high" then
        push("highReadyQueue", "highReadyTail", job)
    elseif lane == "visible" then
        push("visibleReadyQueue", "visibleReadyTail", job)
    elseif lane == "outer" then
        push("outerReadyQueue", "outerReadyTail", job)
    else
        push("readyQueue", "readyTail", job)
    end
    if not alreadyCounted then
        state.readyJobsCount = state.readyJobsCount + 1
        adjustReadyPriority(lane, 1)
    end
    return true
end

local function popValidReadyFrom(queueName, headName, tailName, lane)
    while true do
        local job = pop(queueName, headName, tailName)
        if not job then return nil end
        if job.queuedLane == lane and state.squareState[job.key] == "ready"
            and state.squareJobs[job.key] == job
        then
            job.queuedLane = nil
            state.readyJobsCount = math.max(0, state.readyJobsCount - 1)
            adjustReadyPriority(job.priority, -1)
            return job
        end
    end
end

local function popReadyJob()
    local job = popValidReadyFrom("highReadyQueue", "highReadyHead", "highReadyTail", "high")
    if job then return job end
    job = popValidReadyFrom("visibleReadyQueue", "visibleReadyHead", "visibleReadyTail", "visible")
    if job then return job end
    job = popValidReadyFrom("outerReadyQueue", "outerReadyHead", "outerReadyTail", "outer")
    if job then return job end
    return popValidReadyFrom("readyQueue", "readyHead", "readyTail", "normal")
end

local function getLoadedSquare(x, y, z)
    -- Dedicated/listen servers use the authoritative ServerMap only. Falling
    -- through to getCell() after ServerMap reports nil could accidentally treat
    -- a non-server square view as authoritative. Single-player keeps the normal
    -- cell lookup because ServerMap is not its world owner.
    if type(isServer) == "function" and isServer() then
        if ServerMap and ServerMap.instance and ServerMap.instance.getGridSquare then
            return ServerMap.instance:getGridSquare(x, y, z)
        end
        return nil
    end

    local cell = type(getCell) == "function" and getCell() or nil
    return cell and cell:getGridSquare(x, y, z) or nil
end

local function getChunkSquare(job, localX, localY, z)
    if not job or not job.chunk or type(job.chunk.getGridSquare) ~= "function" then
        return nil
    end

    local ok, square = pcall(function()
        return job.chunk:getGridSquare(localX, localY, z)
    end)
    if not ok or not square then return nil end
    return square
end

local function getJobSquare(job)
    if not job then return nil end
    local x = integer(job.x, nil)
    local y = integer(job.y, nil)
    local z = integer(job.z, nil)
    if x == nil or y == nil or z == nil then return nil end

    local chunkSquare = getChunkSquare(job, x % state.chunkSize, y % state.chunkSize, z)
    if chunkSquare then return chunkSquare end
    return getLoadedSquare(x, y, z)
end

-- Priority is ground level, then positive floors ascending, then basements
-- descending away from ground: 0, 1, 2, ... -1, -2, ...
local function levelCount(minZ, maxZ)
    local count = 0
    if minZ <= 0 and maxZ >= 0 then count = count + 1 end

    local positiveStart = math.max(1, minZ)
    if maxZ >= positiveStart then
        count = count + (maxZ - positiveStart + 1)
    end

    local negativeStart = math.min(-1, maxZ)
    if minZ <= negativeStart then
        count = count + (negativeStart - minZ + 1)
    end
    return count
end

local function levelAt(minZ, maxZ, slot)
    if minZ <= 0 and maxZ >= 0 then
        if slot == 1 then return 0 end
        slot = slot - 1
    end

    local positiveStart = math.max(1, minZ)
    local positiveCount = maxZ >= positiveStart and (maxZ - positiveStart + 1) or 0
    if slot <= positiveCount then
        return positiveStart + slot - 1
    end
    slot = slot - positiveCount

    local negativeStart = math.min(-1, maxZ)
    local negativeCount = minZ <= negativeStart and (negativeStart - minZ + 1) or 0
    if slot <= negativeCount then
        return negativeStart - slot + 1
    end
    return nil
end

local function isProcessed(square)
    return Persistence.isProcessed(square)
end

local function enqueueReady(job)
    if not job then return false end

    local key = squareKey(job.x, job.y, job.z)
    if state.squareState[key] ~= nil then return false end

    job.key = key
    job.chunkKey = job.chunkKey or chunkKey(
        math.floor(job.x / state.chunkSize), math.floor(job.y / state.chunkSize)
    )
    job.priority = normalizedPriority(job.priority)
    state.squareState[key] = "ready"
    state.squareJobs[key] = job
    queueReadyJob(job, false)
    state.stats.squaresQueued = state.stats.squaresQueued + 1
    if state.stats.squaresQueued == 1 then
        Debug.log("first square queued for ageing at " .. tostring(job.x) .. ":" .. tostring(job.y) .. ":" .. tostring(job.z))
    end
    local count = readyCount()
    if count > state.stats.peakReadySquares then state.stats.peakReadySquares = count end
    return true
end

local function updateBackpressure(budget)
    local count = readyCount()
    if count >= budget.readyHighWater then
        state.refillEnabled = false
    elseif count <= budget.readyLowWater then
        state.refillEnabled = true
    end
end

local function finishChunkJob(job)
    local key = job.key or chunkKey(job.wx, job.wy)
    job.queuedLane = nil
    if job.restartRequested then
        -- A duplicate LoadChunk arrived while this coordinate-only job was
        -- still being expanded. Run one fresh pass so squares that were
        -- unloaded during the earlier pass can be rediscovered.
        job.restartRequested = false
        job.cursor = 0
        job.levels = buildLevelOrder(job.minZ, job.maxZ, state.lastPlayerChunks)
        job.reorderLevelsRequested = false
        job.missedLoadedSquare = false
        queueChunkJob(job)
        return
    end

    state.chunkKeys[key] = nil
    state.pendingChunkJobs = math.max(0, state.pendingChunkJobs - 1)
    adjustPendingPriority(job.priority, -1)
    if job.missedLoadedSquare then
        -- Do not session-seal a chunk whose squares disappeared while it was
        -- being expanded. A later LoadChunk must be allowed to rediscover it.
        state.seenChunks[key] = nil
    end
end

local function refreshRemainingLevelOrder(job, players)
    if not job or not job.levels then return end
    local squaresPerLevel = state.chunkSize * state.chunkSize
    if (job.cursor % squaresPerLevel) ~= 0 then
        job.reorderLevelsRequested = true
        return
    end

    local completed = math.floor(job.cursor / squaresPerLevel)
    local prefix, used = {}, {}
    for i = 1, completed do
        local z = job.levels[i]
        prefix[#prefix + 1] = z
        used[z] = true
    end

    local wanted = buildLevelOrder(job.minZ, job.maxZ, players)
    for i = 1, #wanted do
        if not used[wanted[i]] then prefix[#prefix + 1] = wanted[i] end
    end
    job.levels = prefix
    job.reorderLevelsRequested = false
end

local function advanceChunkJob(job)
    local levels = job.levels or buildLevelOrder(job.minZ, job.maxZ, state.lastPlayerChunks)
    job.levels = levels
    if #levels < 1 then
        finishChunkJob(job)
        return
    end

    local squaresPerLevel = state.chunkSize * state.chunkSize
    if job.reorderLevelsRequested and (job.cursor % squaresPerLevel) == 0 then
        refreshRemainingLevelOrder(job, state.lastPlayerChunks)
        levels = job.levels
    end

    local total = squaresPerLevel * #levels
    if job.cursor >= total then
        finishChunkJob(job)
        return
    end

    local cursor = job.cursor
    local levelSlot = math.floor(cursor / squaresPerLevel) + 1
    local rawLocalIndex = cursor % squaresPerLevel
    local z = levels[levelSlot]

    if z ~= nil and rawLocalIndex == 0 and Persistence.isCompletedChunkLevel(job.wx, job.wy, z) then
        job.cursor = math.min(total, levelSlot * squaresPerLevel)
        if job.cursor >= total then
            finishChunkJob(job)
        else
            queueChunkJob(job)
        end
        return
    end

    -- Do not discover 8 adjacent squares in row order. Even with a good
    -- placement hash, row-by-row discovery makes a live warm-up visibly draw
    -- stripes. A coprime permutation visits all 64 cells exactly once while
    -- chunk-specific offsetting breaks alignment between neighbouring chunks.
    local offset = 0
    if z ~= nil then
        offset = (Random.coordinateIndex(job.wx, job.wy, z, "queue:visit-order", squaresPerLevel) or 1) - 1
    end
    local localIndex = (rawLocalIndex * 37 + offset) % squaresPerLevel
    local localX = localIndex % state.chunkSize
    local localY = math.floor(localIndex / state.chunkSize)
    job.cursor = job.cursor + 1

    if z ~= nil then
        local x = job.wx * state.chunkSize + localX
        local y = job.wy * state.chunkSize + localY
        local key = squareKey(x, y, z)

        if state.squareState[key] == nil then
            local square = getChunkSquare(job, localX, localY, z) or getLoadedSquare(x, y, z)
            if square and not isProcessed(square) then
                local workClass = Processor.classifySquareWork(square)
                if workClass ~= "skip" then
                    enqueueReady({
                        x = x, y = y, z = z,
                        chunkKey = job.key,
                        chunk = job.chunk,
                        workClass = workClass,
                        priority = priorityForSquare(job.priority, z, workClass, state.lastPlayerChunks),
                    })
                else
                    state.stats.upperSquaresSkipped = state.stats.upperSquaresSkipped + 1
                end
            elseif not square then
                job.missedLoadedSquare = true
            end
        end
    end

    if job.cursor >= total then
        finishChunkJob(job)
    else
        -- Round-robin expansion: inspect one coordinate, then rotate this chunk
        -- behind other pending chunk jobs in the same priority lane.
        queueChunkJob(job)
    end
end

local function traceback(err)
    local text = tostring(err)
    if debug and type(debug.traceback) == "function" then
        return debug.traceback(text, 2)
    end
    return text
end

-- B42.20.4's Kahlua runtime exposes pcall but does not reliably expose
-- xpcall. Using xpcall here caused buildNextPlan/applyActive to call nil on
-- every OnTick as soon as a square reached the planner. Keep all scheduler
-- error containment on the pcall API that is available in the live runtime.
local function protectedCall(fn)
    local ok, first, second, third = pcall(fn)
    if not ok then
        return false, traceback(first), nil, nil
    end
    return true, first, second, third
end

local function quarantine(key, err)
    state.squareState[key] = "quarantined"
    state.squareJobs[key] = nil
    state.failures[key] = nil
    state.stats.squaresQuarantined = state.stats.squaresQuarantined + 1
    Debug.once(
        "quarantine:" .. key,
        "ERROR",
        Text.format(
            "IGUI_A10YL_Error_SquareQuarantined",
            "Ageing was stopped at square {square} for this server session after repeated errors: {error}",
            { square = key, error = err }
        )
    )
end

local function recordFailure(key, retryLimit, err)
    local count = (state.failures[key] or 0) + 1
    state.failures[key] = count
    if count > retryLimit then
        quarantine(key, err)
        return false
    end
    return true
end

local function clearSquareRuntime(key, unloaded)
    local job = state.squareJobs[key]
    if unloaded and job and job.chunkKey then
        state.seenChunks[job.chunkKey] = nil
    end
    state.squareState[key] = nil
    state.squareJobs[key] = nil
    state.failures[key] = nil
end

local function dropActiveUnloaded()
    local active = state.active
    if not active then return end

    clearSquareRuntime(active.key, true)
    state.active = nil
    state.stats.squaresDroppedUnloaded = state.stats.squaresDroppedUnloaded + 1
end

local function ensureConfig()
    if type(Config) ~= "table" or type(Config.readAll) ~= "function" then
        Config = A10YL_Config
        if type(Config) ~= "table" or type(Config.readAll) ~= "function" then
            if not state.configModuleErrorLogged then
                state.configModuleErrorLogged = true
                print("[A10YL][ERROR] configuration resolver unavailable; ageing paused safely instead of retrying every tick")
            end
            return false
        end
    end

    if not state.generationConfig or not state.schedulerBudget then
        local resolved = Config.readAll()
        if not resolved then return false end
        state.generationConfig = resolved.generation
        state.schedulerBudget = resolved.scheduler
        state.existingSaveMode = resolved.existingSaveMode or ExistingWorld.MODE_NEW_AREAS_ONLY
        state.existingSaveModeName = resolved.existingSaveModeName or "New Areas Only"
        Debug.setEnabled(resolved.debugMode)
        Debug.log(Text.format(
            "IGUI_A10YL_Diagnostic_ConfigurationResolved",
            "Using ageing profile '{profile}' with processing mode '{mode}'. Existing-save handling: {existing}.",
            {
                profile = resolved.profileName,
                mode = resolved.processingModeName,
                existing = state.existingSaveModeName,
            }
        ))
    end
    return true
end

local function applyActive(startMs, budget, mutationCredits, operationChecks)
    while state.active and mutationCredits > 0 and operationChecks > 0 and timeAvailable(startMs, budget) do
        local active = state.active
        local square = getJobSquare(active.job) or getLoadedSquare(active.plan.x, active.plan.y, active.plan.z)
        if not square then
            dropActiveUnloaded()
            break
        end

        local ok, status, didMutate, isFeatureMutation = protectedCall(function()
            return Processor.applyNext(active.plan, square)
        end)

        operationChecks = operationChecks - 1
        state.stats.operationChecks = state.stats.operationChecks + 1

        if not ok then
            if not recordFailure(active.key, budget.retryLimit, status) then
                state.active = nil
            end
            break
        end

        -- The failed operation, if any, has now completed successfully or was
        -- safely skipped, so its consecutive retry counter can be cleared.
        state.failures[active.key] = nil

        if didMutate then
            state.stats.mutationsApplied = state.stats.mutationsApplied + 1
            if not state.runtimeSmoke.firstMutation then
                state.runtimeSmoke.firstMutation = true
                Debug.log("first world mutation applied")
            end

            -- Persistence bookkeeping is required for save safety but must not
            -- consume the same scarce credit as visible vegetation/debris/etc.
            if isFeatureMutation then
                mutationCredits = mutationCredits - 1
                state.stats.featureMutationsApplied = state.stats.featureMutationsApplied + 1
                if not state.runtimeSmoke.firstFeatureMutation then
                    state.runtimeSmoke.firstFeatureMutation = true
                    Debug.log("first visible feature mutation applied")
                end
            end
        end

        if status == "done" then
            clearSquareRuntime(active.key)
            state.active = nil
            state.stats.squaresCompleted = state.stats.squaresCompleted + 1
            if not state.runtimeSmoke.firstCompletion then
                state.runtimeSmoke.firstCompletion = true
                Debug.log("first square completed")
            end
        elseif status == "unloaded" then
            dropActiveUnloaded()
            break
        end
    end

    return mutationCredits, operationChecks
end

local function buildNextPlan(startMs, budget, planCredits, readyChecks)
    while not state.active and planCredits > 0 and readyChecks > 0 and timeAvailable(startMs, budget) do
        local job = popReadyJob()
        if not job then break end

        readyChecks = readyChecks - 1
        local key = job.key or squareKey(job.x, job.y, job.z)
        local square = getJobSquare(job)

        if not square then
            clearSquareRuntime(key, true)
            state.stats.squaresDroppedUnloaded = state.stats.squaresDroppedUnloaded + 1
        elseif isProcessed(square) then
            clearSquareRuntime(key)
        else
            planCredits = planCredits - 1
            local ok, plan, reason = protectedCall(function()
                return Processor.buildPlan(square, state.generationConfig)
            end)

            if not ok then
                if recordFailure(key, budget.retryLimit, plan) then
                    state.squareState[key] = nil
                    state.squareJobs[key] = nil
                    enqueueReady({
                        x = job.x, y = job.y, z = job.z,
                        chunkKey = job.chunkKey,
                        chunk = job.chunk,
                        workClass = job.workClass,
                        priority = job.priority,
                    })
                end
            elseif reason == "processed" then
                clearSquareRuntime(key)
            elseif plan then
                state.squareState[key] = "active"
                state.active = { key = key, plan = plan, job = job, workClass = job.workClass, priority = job.priority }
                state.failures[key] = nil
                state.stats.plansBuilt = state.stats.plansBuilt + 1
                if not state.runtimeSmoke.firstPlan then
                    state.runtimeSmoke.firstPlan = true
                    Debug.log("first square plan built at " .. tostring(job.x) .. ":" .. tostring(job.y) .. ":" .. tostring(job.z))
                end
                local operationCount = #plan.operations
                local featureOperationCount = 0
                for i = 1, operationCount do
                    if plan.operations[i].system ~= "processor" then
                        featureOperationCount = featureOperationCount + 1
                    end
                end
                state.stats.featureOperationsPlanned = state.stats.featureOperationsPlanned + featureOperationCount
                if operationCount > state.stats.peakOperationsPerPlan then
                    state.stats.peakOperationsPerPlan = operationCount
                end
                if state.stats.plansBuilt == 1 then
                    Debug.log("first plan feature operations=" .. tostring(featureOperationCount))
                end
            else
                clearSquareRuntime(key)
            end
        end
    end

    return planCredits, readyChecks
end

local function refillReady(startMs, budget, discoveryCredits)
    updateBackpressure(budget)
    if not state.refillEnabled then return discoveryCredits end

    while discoveryCredits > 0 and timeAvailable(startMs, budget) do
        updateBackpressure(budget)
        if not state.refillEnabled or readyCount() >= budget.readyHighWater then break end

        local job = popChunkJob()
        if not job then break end

        discoveryCredits = discoveryCredits - 1
        state.stats.discoveryChecks = state.stats.discoveryChecks + 1
        advanceChunkJob(job)
    end

    return discoveryCredits
end


function Queue.resetRuntime()
    -- World/session boundary only. Persistent A10YL state lives in Global ModData,
    -- square PV/PG/PS/PH and object/effect metadata, never in this scheduler.
    -- Resetting here prevents a same-Lua-session world change from carrying a
    -- queued square, cached config, quarantine or disabled flag into another save.
    state.disabled = false
    state.chunkSize = B42_CHUNK_SIZE

    state.generationConfig = nil
    state.schedulerBudget = nil
    state.existingSaveMode = ExistingWorld.MODE_NEW_AREAS_ONLY
    state.existingSaveModeName = "New Areas Only"
    ExistingWorld.resetRuntime()

    state.chunkQueue = {}
    state.chunkHead = 1
    state.chunkTail = 0
    state.outerChunkQueue = {}
    state.outerChunkHead = 1
    state.outerChunkTail = 0
    state.visibleChunkQueue = {}
    state.visibleChunkHead = 1
    state.visibleChunkTail = 0
    state.highChunkQueue = {}
    state.highChunkHead = 1
    state.highChunkTail = 0
    state.chunkKeys = {}
    state.seenChunks = {}
    state.pendingChunkJobs = 0
    state.highPendingChunks = 0
    state.visiblePendingChunks = 0
    state.outerPendingChunks = 0
    state.immediateJob = nil
    state.playerChunkSignature = nil
    state.lastPlayerChunks = nil
    state.catchupMinUntilMs = 0
    state.catchupDeadlineMs = 0
    state.catchupMinTicksRemaining = 0
    state.catchupMaxTicksRemaining = 0

    state.readyQueue = {}
    state.readyHead = 1
    state.readyTail = 0
    state.outerReadyQueue = {}
    state.outerReadyHead = 1
    state.outerReadyTail = 0
    state.visibleReadyQueue = {}
    state.visibleReadyHead = 1
    state.visibleReadyTail = 0
    state.highReadyQueue = {}
    state.highReadyHead = 1
    state.highReadyTail = 0
    state.readyJobsCount = 0
    state.highReadyCount = 0
    state.visibleReadyCount = 0
    state.outerReadyCount = 0
    state.squareState = {}
    state.squareJobs = {}

    state.active = nil
    state.failures = {}
    state.refillEnabled = true
    state.warmupActive = false
    state.preAgeActive = false

    state.runtimeSmoke = {
        firstChunk = false,
        firstPlan = false,
        firstMutation = false,
        firstFeatureMutation = false,
        firstCompletion = false,
    }

    Cache.clearAll()
    AreaContext.clearAll()

    state.stats = {
        chunksQueued = 0,
        discoveryChecks = 0,
        squaresQueued = 0,
        plansBuilt = 0,
        operationChecks = 0,
        mutationsApplied = 0,
        featureMutationsApplied = 0,
        featureOperationsPlanned = 0,
        squaresCompleted = 0,
        squaresDroppedUnloaded = 0,
        squaresQuarantined = 0,
        peakPendingChunks = 0,
        peakReadySquares = 0,
        peakOperationsPerPlan = 0,
        teleportCatchups = 0,
        upperSquaresSkipped = 0,
        preAgeChunksQueued = 0,
    }
end

local function deriveChunkCoordinates(chunk, minZ, maxZ)
    -- In B42.20.4 IsoChunk.wx/wy are public Java fields, but Kahlua does not
    -- reliably expose those fields to Lua. Prefer them when available (useful
    -- for test doubles/compatible runtimes), then derive the chunk coordinate
    -- from a real square through the documented IsoChunk:getGridSquare API.
    local wx = integer(chunk.wx, nil)
    local wy = integer(chunk.wy, nil)
    if wx ~= nil and wy ~= nil then
        return wx, wy
    end

    local function probeLevel(z)
        for localY = 0, B42_CHUNK_SIZE - 1 do
            for localX = 0, B42_CHUNK_SIZE - 1 do
                local okSquare, square = pcall(function()
                    return chunk:getGridSquare(localX, localY, z)
                end)
                if okSquare and square then
                    local okX, x = pcall(function() return square:getX() end)
                    local okY, y = pcall(function() return square:getY() end)
                    x = okX and integer(x, nil) or nil
                    y = okY and integer(y, nil) or nil
                    if x ~= nil and y ~= nil then
                        return math.floor(x / B42_CHUNK_SIZE), math.floor(y / B42_CHUNK_SIZE)
                    end
                end
            end
        end
        return nil, nil
    end

    -- Ground level is by far the common case and avoids a level scan for normal
    -- terrain chunks. Fall back through the chunk's actual valid level range.
    if minZ <= 0 and maxZ >= 0 then
        wx, wy = probeLevel(0)
        if wx ~= nil and wy ~= nil then return wx, wy end
    end

    for slot = 1, levelCount(minZ, maxZ) do
        local z = levelAt(minZ, maxZ, slot)
        if z ~= nil and z ~= 0 then
            wx, wy = probeLevel(z)
            if wx ~= nil and wy ~= nil then return wx, wy end
        end
    end

    return nil, nil
end

function Queue.enqueueChunk(chunk)
    if state.disabled or not Persistence.canAgeWorld() or not chunk then
        return false
    end
    if not ensureConfig() then return false end

    -- Checkpoint 69 never mutates synchronously from LoadChunk. Clear any
    -- legacy immediate-job residue and queue discovery only.
    state.immediateJob = nil

    local okMin, minZ = pcall(function() return chunk:getMinLevel() end)
    local okMax, maxZ = pcall(function() return chunk:getMaxLevel() end)
    if not okMin or not okMax then
        Debug.once(
            "chunk-level-api-failed",
            "ERROR",
            Text.get(
                "IGUI_A10YL_Error_ChunkLevels",
                "A10YL could not read the height range of a map chunk; affected chunks are skipped."
            )
        )
        return false
    end

    minZ = integer(minZ, nil)
    maxZ = integer(maxZ, nil)
    if minZ == nil or maxZ == nil or minZ > maxZ then
        Debug.once(
            "chunk-invalid-level-range",
            "WARN",
            Text.get(
                "IGUI_A10YL_Warning_ChunkLevelRange",
                "The game supplied an invalid map-chunk height range; affected chunks are skipped."
            )
        )
        return false
    end

    -- Prevent a corrupt/future API result from creating an unbounded job.
    if minZ < -32 or maxZ > 31 then
        Debug.once(
            "chunk-unsupported-level-range",
            "ERROR",
            Text.get(
                "IGUI_A10YL_Error_ChunkLevelLimit",
                "The game supplied an unsupported map-chunk height range; affected chunks are skipped to protect the world."
            )
        )
        return false
    end

    local wx, wy = deriveChunkCoordinates(chunk, minZ, maxZ)
    if wx == nil or wy == nil then
        Debug.once(
            "chunk-missing-coordinates",
            "WARN",
            Text.get(
                "IGUI_A10YL_Warning_ChunkCoordinates",
                "A10YL could not derive coordinates from a loaded map chunk; that chunk was skipped."
            )
        )
        return false
    end

    local key = chunkKey(wx, wy)

    -- Chunk-level completion is advisory only in generator 26. The persistence
    -- layer deliberately returns false here so live square modData is checked
    -- before any square is skipped.
    local allCompleted = true
    for z = minZ, maxZ do
        if not Persistence.isCompletedChunkLevel(wx, wy, z) then
            allCompleted = false
            break
        end
    end
    if allCompleted then
        state.seenChunks[key] = true
        return false
    end

    local allowedByExistingMode = ExistingWorld.shouldAgeChunk(
        chunk, wx, wy,
        state.existingSaveMode,
        state.existingSaveModeName,
        Persistence.isFreshWorldLineage()
    )
    if not allowedByExistingMode then
        state.seenChunks[key] = true
        return false
    end

    local priorityClass = classifyChunkPriority(wx, wy)
    local priority = priorityClass == "core" and "high" or normalizedPriority(priorityClass)

    local existingJob = state.chunkKeys[key]
    if existingJob then
        -- Multiple players and maximum zoom-out can rediscover the same server
        -- chunk repeatedly. Coalesce it into one discovery job and only promote
        -- its lane when the player gets closer.
        if (PRIORITY_RANK[priority] or 1) > (PRIORITY_RANK[existingJob.priority] or 1) then
            adjustPendingPriority(existingJob.priority, -1)
            existingJob.priority = priority
            adjustPendingPriority(existingJob.priority, 1)
            if existingJob.queuedLane ~= nil then
                queueChunkJob(existingJob)
            end
        end
        -- Do not request a second pass merely because LoadChunk fired again.
        -- Only a job that already observed an unavailable square may request one
        -- recovery pass; ordinary duplicate load events are fully coalesced.
        if existingJob.cursor > 0 and existingJob.missedLoadedSquare then
            existingJob.restartRequested = true
        end
        return false
    end

    -- A fully discovered chunk remains session-deduplicated until one of its
    -- queued/active squares proves that it unloaded before completion.
    if state.seenChunks[key] then
        return false
    end

    local job = {
        key = key,
        wx = wx,
        wy = wy,
        chunk = chunk,
        minZ = minZ,
        maxZ = maxZ,
        levels = buildLevelOrder(minZ, maxZ),
        cursor = 0,
        restartRequested = false,
        missedLoadedSquare = false,
        priority = priority,
        preloadEligible = false,
    }
    state.chunkKeys[key] = job
    state.seenChunks[key] = true
    state.pendingChunkJobs = state.pendingChunkJobs + 1
    adjustPendingPriority(priority, 1)
    queueChunkJob(job)
    state.warmupActive = true
    state.stats.chunksQueued = state.stats.chunksQueued + 1
    if not state.runtimeSmoke.firstChunk then
        state.runtimeSmoke.firstChunk = true
        Debug.log("first map chunk queued at " .. tostring(wx) .. ":" .. tostring(wy))
    end
    local count = pendingChunkCount()
    if count > state.stats.peakPendingChunks then state.stats.peakPendingChunks = count end
    return true
end

function Queue.enqueueLoadedSquare(square)
    if state.disabled or not Persistence.canAgeWorld() or not square then return false end
    if not ensureConfig() then return false end

    local x = integer(square:getX(), nil)
    local y = integer(square:getY(), nil)
    local z = integer(square:getZ(), nil)
    if x == nil or y == nil or z == nil then return false end

    -- On established saves in New Areas Only mode, LoadChunk remains the gate
    -- because it is the only place where PZ may expose new-vs-existing chunk
    -- information. Fresh A10YL lineages and Age Existing mode can safely queue
    -- live squares directly.
    if state.existingSaveMode == ExistingWorld.MODE_NEW_AREAS_ONLY
        and not Persistence.isFreshWorldLineage()
    then
        return false
    end

    if Persistence.isProcessed(square) then return false end
    local workClass = Processor.classifySquareWork(square)
    if workClass == "skip" then return false end

    local wx = math.floor(x / state.chunkSize)
    local wy = math.floor(y / state.chunkSize)
    local priorityClass = classifyChunkPriority(wx, wy)
    local priority = priorityClass == "core" and "high" or normalizedPriority(priorityClass)
    return enqueueReady({
        x = x, y = y, z = z,
        chunkKey = chunkKey(wx, wy),
        workClass = workClass,
        priority = priorityForSquare(priority, z, workClass, state.lastPlayerChunks),
    })
end

function Queue.enqueuePreAgeChunk(wx, wy, minZ, maxZ, priority)
    if state.disabled or not Persistence.canAgeWorld() then
        return false, "disabled"
    end
    if not ensureConfig() then return false, "config" end

    wx = integer(wx, nil)
    wy = integer(wy, nil)
    minZ = integer(minZ, 0) or 0
    maxZ = integer(maxZ, 0) or 0
    if wx == nil or wy == nil then return false, "invalid-coordinates" end
    if minZ > maxZ then minZ, maxZ = maxZ, minZ end
    if minZ < -32 or maxZ > 31 then return false, "unsupported-level-range" end

    local key = chunkKey(wx, wy)
    local allCompleted = true
    for z = minZ, maxZ do
        if not Persistence.isCompletedChunkLevel(wx, wy, z) then
            allCompleted = false
            break
        end
    end
    if allCompleted then
        state.seenChunks[key] = true
        return false, "completed"
    end

    local allowedByExistingMode, existingReason = ExistingWorld.shouldAgeChunk(
        nil, wx, wy,
        state.existingSaveMode,
        state.existingSaveModeName,
        Persistence.isFreshWorldLineage()
    )
    if not allowedByExistingMode then
        state.seenChunks[key] = true
        return false, existingReason or "existing-save-skip"
    end

    priority = normalizedPriority(priority or "normal")
    local existingJob = state.chunkKeys[key]
    if existingJob then
        if (PRIORITY_RANK[priority] or 1) > (PRIORITY_RANK[existingJob.priority] or 1) then
            adjustPendingPriority(existingJob.priority, -1)
            existingJob.priority = priority
            adjustPendingPriority(existingJob.priority, 1)
            if existingJob.queuedLane ~= nil then queueChunkJob(existingJob) end
        end
        return false, "already-queued"
    end
    if state.seenChunks[key] then return false, "already-seen" end

    local job = {
        key = key,
        wx = wx,
        wy = wy,
        minZ = minZ,
        maxZ = maxZ,
        levels = buildLevelOrder(minZ, maxZ, state.lastPlayerChunks),
        cursor = 0,
        restartRequested = false,
        missedLoadedSquare = false,
        priority = priority,
        preloadEligible = false,
        source = "preage",
    }

    state.chunkKeys[key] = job
    state.seenChunks[key] = true
    state.pendingChunkJobs = state.pendingChunkJobs + 1
    adjustPendingPriority(priority, 1)
    queueChunkJob(job)
    state.warmupActive = true
    state.preAgeActive = true
    state.stats.chunksQueued = state.stats.chunksQueued + 1
    state.stats.preAgeChunksQueued = state.stats.preAgeChunksQueued + 1
    local count = pendingChunkCount()
    if count > state.stats.peakPendingChunks then state.stats.peakPendingChunks = count end
    return true, "queued"
end

function Queue.setPreAgeActive(value)
    state.preAgeActive = value == true
end

function Queue.setDisabled(value, reason)
    state.disabled = value == true
    print("[A10YL] ageing " .. (state.disabled and "disabled" or "enabled")
        .. " by " .. tostring(reason or "runtime"))
    return true
end

function Queue.isDisabled()
    return state.disabled == true
end

local function hasHighPriorityWork()
    return (state.active and state.active.priority == "high")
        or state.highPendingChunks > 0
        or state.highReadyCount > 0
end

local function hasForegroundWork()
    if state.active and state.active.priority ~= "normal" then return true end
    return state.highPendingChunks > 0
        or state.visiblePendingChunks > 0
        or state.outerPendingChunks > 0
        or state.highReadyCount > 0
        or state.visibleReadyCount > 0
        or state.outerReadyCount > 0
end

local function highPriorityBacklog()
    local count = state.highPendingChunks + state.highReadyCount
    if state.active and state.active.priority == "high" then count = count + 1 end
    return count
end

local function playerChunkSignature(players)
    local keys = {}
    for i = 1, #players do
        keys[#keys + 1] = tostring(players[i].wx) .. ":" .. tostring(players[i].wy) .. ":" .. tostring(integer(players[i].z, 0))
    end
    table.sort(keys)
    return table.concat(keys, "|")
end

local function copyPlayerChunks(players)
    local result = {}
    for i = 1, #players do
        result[#result + 1] = { wx = players[i].wx, wy = players[i].wy, z = integer(players[i].z, 0) }
    end
    return result
end

local function largePlayerJump(players, previous)
    if type(previous) ~= "table" or #previous == 0 then return false end
    for i = 1, #players do
        local nearest = nil
        for j = 1, #previous do
            local distance = math.max(
                math.abs(players[i].wx - previous[j].wx),
                math.abs(players[i].wy - previous[j].wy)
            )
            if nearest == nil or distance < nearest then nearest = distance end
        end
        if nearest ~= nil and nearest >= TELEPORT_THRESHOLD_CHUNKS then
            return true
        end
    end
    return false
end

local function hasTeleportCriticalWork()
    if state.active and (state.active.priority == "high" or state.active.priority == "visible") then
        return true
    end
    return state.highPendingChunks > 0
        or state.visiblePendingChunks > 0
        or state.highReadyCount > 0
        or state.visibleReadyCount > 0
end

local function startCatchupBurst()
    local timestamp = nowMs()
    if timestamp > 0 then
        state.catchupMinUntilMs = timestamp + TELEPORT_CATCHUP_MIN_MS
        state.catchupDeadlineMs = timestamp + TELEPORT_CATCHUP_MAX_MS
    else
        state.catchupMinTicksRemaining = TELEPORT_CATCHUP_MIN_TICKS
        state.catchupMaxTicksRemaining = TELEPORT_CATCHUP_MAX_TICKS
    end
    state.stats.teleportCatchups = state.stats.teleportCatchups + 1
    Debug.log("large player position jump detected; target-aware bounded ageing catch-up enabled")
end

local function catchupActive()
    local timestamp = nowMs()
    if timestamp > 0 then
        if (state.catchupDeadlineMs or 0) <= timestamp then return false end
        if (state.catchupMinUntilMs or 0) > timestamp then return true end
        return hasTeleportCriticalWork()
    end
    if (state.catchupMaxTicksRemaining or 0) <= 0 then return false end
    if (state.catchupMinTicksRemaining or 0) > 0 then return true end
    return hasTeleportCriticalWork()
end

-- Reclassification is deliberately two-way. After a teleport, jobs from the old
-- location must be demoted as well as new-location jobs promoted, otherwise stale
-- high-priority work can consume the entire catch-up budget. Stale queue entries
-- are harmless because queuedLane validation rejects them when popped.
local function setChunkJobPriority(job, newPriority, players)
    if not job then return false end
    newPriority = normalizedPriority(newPriority)
    local oldPriority = normalizedPriority(job.priority)
    if newPriority == oldPriority then
        if job.reorderLevelsRequested then refreshRemainingLevelOrder(job, players) end
        return false
    end
    adjustPendingPriority(oldPriority, -1)
    job.priority = newPriority
    adjustPendingPriority(newPriority, 1)
    job.reorderLevelsRequested = true
    if (job.cursor % (state.chunkSize * state.chunkSize)) == 0 then
        refreshRemainingLevelOrder(job, players)
    end
    if job.queuedLane ~= nil then queueChunkJob(job) end
    return true
end

local function setReadyJobPriority(key, job, newPriority)
    if not job or state.squareState[key] ~= "ready" then return false end
    newPriority = normalizedPriority(newPriority)
    local oldPriority = normalizedPriority(job.priority)
    if newPriority == oldPriority then return false end
    adjustReadyPriority(oldPriority, -1)
    job.priority = newPriority
    adjustReadyPriority(newPriority, 1)
    if job.queuedLane ~= nil then queueReadyJob(job, true) end
    return true
end

local function promoteNearPlayerWork()
    local players = collectPlayerChunkPositions()
    if #players == 0 then
        state.playerChunkSignature = nil
        state.lastPlayerChunks = nil
        return
    end

    -- Include Z in the signature so climbing a tall building immediately
    -- reprioritises that floor and its neighbours even without crossing an XY
    -- chunk boundary. Large XY discontinuities still trigger teleport catch-up.
    local signature = playerChunkSignature(players)
    if signature == state.playerChunkSignature then return end
    local jumped = largePlayerJump(players, state.lastPlayerChunks)
    state.playerChunkSignature = signature
    state.lastPlayerChunks = copyPlayerChunks(players)

    for _, job in pairs(state.chunkKeys) do
        if job then
            local priorityClass = classifyChunkPriority(job.wx, job.wy, players)
            local wanted = priorityClass == "core" and "high" or normalizedPriority(priorityClass)
            setChunkJobPriority(job, wanted, players)
            if not job.reorderLevelsRequested then
                refreshRemainingLevelOrder(job, players)
            end
        end
    end

    for key, job in pairs(state.squareJobs) do
        if state.squareState[key] == "ready" and job then
            local wx = math.floor(job.x / state.chunkSize)
            local wy = math.floor(job.y / state.chunkSize)
            local priorityClass = classifyChunkPriority(wx, wy, players)
            local horizontal = priorityClass == "core" and "high" or normalizedPriority(priorityClass)
            local wanted = priorityForSquare(horizontal, job.z, job.workClass, players)
            setReadyJobPriority(key, job, wanted)
        end
    end

    if state.active and state.active.plan then
        local wx = math.floor(state.active.plan.x / state.chunkSize)
        local wy = math.floor(state.active.plan.y / state.chunkSize)
        local priorityClass = classifyChunkPriority(wx, wy, players)
        local horizontal = priorityClass == "core" and "high" or normalizedPriority(priorityClass)
        state.active.priority = priorityForSquare(
            horizontal, state.active.plan.z, state.active.workClass, players
        )
    end

    -- Start the burst after reprioritising so old-location queues are already
    -- demoted before the first catch-up budget is selected.
    if jumped then startCatchupBurst() end
end

local function expandedBudget(base, preset, lowWater, highWater)
    return {
        discoveryChecksPerTick = math.max(base.discoveryChecksPerTick, preset.discoveryChecksPerTick),
        plansPerTick = math.max(base.plansPerTick, preset.plansPerTick),
        mutationsPerTick = math.max(base.mutationsPerTick, preset.mutationsPerTick),
        timeBudgetMs = math.max(base.timeBudgetMs, preset.timeBudgetMs),
        readyLowWater = math.max(base.readyLowWater, lowWater),
        readyHighWater = math.max(base.readyHighWater, highWater),
        retryLimit = base.retryLimit,
        operationChecksPerTick = math.max(base.operationChecksPerTick, preset.mutationsPerTick * 8),
        readyChecksPerTick = math.max(base.readyChecksPerTick, preset.plansPerTick * 8),
        mode = base.mode,
    }
end

local function effectiveBudget()
    local base = state.schedulerBudget
    local mode = tonumber(base.mode) or 2
    -- Custom means custom. Background Only means deliberately unboosted. Priority
    -- ordering still applies, but A10YL does not silently override these modes.
    if mode == 4 or mode == 5 then return base end

    -- Admin pre-age runs when the server may have no players connected, so normal
    -- near-player foreground logic cannot drive throughput. Give selected pre-age
    -- jobs the same bounded streaming budget used for visible loaded areas, not
    -- the crash-prone synchronous burst used by rejected test builds.
    if state.preAgeActive and (pendingChunkCount() > 0 or readyCount() > 0 or state.active ~= nil) then
        return expandedBudget(base, STREAMING_PRESETS[mode] or STREAMING_PRESETS[2], 512, 1024)
    end

    if catchupActive() and hasForegroundWork() then
        return expandedBudget(base, CATCHUP_PRESETS[mode] or CATCHUP_PRESETS[2], 1024, 2048)
    end
    if hasHighPriorityWork() then
        if highPriorityBacklog() >= FRONTIER_PRESSURE_THRESHOLD then
            return expandedBudget(
                base, FRONTIER_PRESSURE_PRESETS[mode] or FRONTIER_PRESSURE_PRESETS[2], 768, 1536
            )
        end
        return expandedBudget(base, NEAR_PLAYER_PRESETS[mode] or NEAR_PLAYER_PRESETS[2], 512, 1024)
    end
    if hasForegroundWork() then
        return expandedBudget(base, STREAMING_PRESETS[mode] or STREAMING_PRESETS[2], 256, 512)
    end
    return base
end

local function noteImmediatePlan(plan, x, y, z)
    state.stats.plansBuilt = state.stats.plansBuilt + 1
    if not state.runtimeSmoke.firstPlan then
        state.runtimeSmoke.firstPlan = true
        Debug.log("first square plan built at " .. tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z))
    end
    local operationCount = #plan.operations
    local featureOperationCount = 0
    for i = 1, operationCount do
        if plan.operations[i].system ~= "processor" then
            featureOperationCount = featureOperationCount + 1
        end
    end
    state.stats.featureOperationsPlanned = state.stats.featureOperationsPlanned + featureOperationCount
    if operationCount > state.stats.peakOperationsPerPlan then
        state.stats.peakOperationsPerPlan = operationCount
    end
    if state.stats.plansBuilt == 1 then
        Debug.log("first plan feature operations=" .. tostring(featureOperationCount))
    end
end

local function noteImmediateMutation(didMutate, isFeatureMutation)
    if not didMutate then return end
    state.stats.mutationsApplied = state.stats.mutationsApplied + 1
    if not state.runtimeSmoke.firstMutation then
        state.runtimeSmoke.firstMutation = true
        Debug.log("first world mutation applied")
    end
    if isFeatureMutation then
        state.stats.featureMutationsApplied = state.stats.featureMutationsApplied + 1
        if not state.runtimeSmoke.firstFeatureMutation then
            state.runtimeSmoke.firstFeatureMutation = true
            Debug.log("first visible feature mutation applied")
        end
    end
end

local function processSquareImmediate(square, key, budget)
    if not square or isProcessed(square) then return true end
    state.squareState[key] = "active"

    local plan, reason
    while true do
        local ok, built, why = protectedCall(function()
            return Processor.buildPlan(square, state.generationConfig)
        end)
        if ok then
            plan, reason = built, why
            state.failures[key] = nil
            break
        end
        if not recordFailure(key, budget.retryLimit, built) then
            return true
        end
    end

    if reason == "processed" or not plan then
        clearSquareRuntime(key)
        return true
    end

    noteImmediatePlan(plan, square:getX(), square:getY(), square:getZ())
    while true do
        local ok, status, didMutate, isFeatureMutation = protectedCall(function()
            return Processor.applyNext(plan, square)
        end)
        state.stats.operationChecks = state.stats.operationChecks + 1

        if not ok then
            if not recordFailure(key, budget.retryLimit, status) then
                return true
            end
        else
            state.failures[key] = nil
            noteImmediateMutation(didMutate, isFeatureMutation)
            if status == "done" then
                clearSquareRuntime(key)
                state.stats.squaresCompleted = state.stats.squaresCompleted + 1
                if not state.runtimeSmoke.firstCompletion then
                    state.runtimeSmoke.firstCompletion = true
                    Debug.log("first square completed")
                end
                return true
            elseif status == "unloaded" then
                clearSquareRuntime(key, true)
                state.stats.squaresDroppedUnloaded = state.stats.squaresDroppedUnloaded + 1
                return false
            end
        end
    end
end

function Queue.processLoadedNow()
    -- Checkpoint 69: retained as a compatibility no-op. World mutation during
    -- the LoadChunk/preload callback produced changes that were visible in the
    -- live session but could disappear from the saved chunk on restart. All
    -- authoritative ageing now runs through the bounded live-square OnTick path.
    state.immediateJob = nil
    return false
end

function Queue.onTick()
    if state.disabled or not Persistence.canAgeWorld() or not ensureConfig() then return end

    -- Chunks that loaded at maximum zoom-out may have entered a lower lane
    -- before the player approached them. Promote remaining discovery/ready work
    -- without rediscovery, and detect teleport-sized player jumps.
    promoteNearPlayerWork()

    local budget = effectiveBudget()
    if nowMs() == 0 then
        if state.catchupMinTicksRemaining > 0 then
            state.catchupMinTicksRemaining = state.catchupMinTicksRemaining - 1
        end
        if state.catchupMaxTicksRemaining > 0 then
            state.catchupMaxTicksRemaining = state.catchupMaxTicksRemaining - 1
        end
    end
    local startMs = nowMs()
    local mutationCredits = budget.mutationsPerTick
    local planCredits = budget.plansPerTick
    local operationChecks = budget.operationChecksPerTick
    local readyChecks = budget.readyChecksPerTick
    local discoveryCredits = budget.discoveryChecksPerTick

    -- Keep discovery and planning pipelined, but do not let discovery starve
    -- already-ready squares in very small Background Only budgets.
    if readyCount() == 0 and timeAvailable(startMs, budget) then
        local initialDiscovery = math.max(1, math.floor(discoveryCredits / 2))
        local unusedInitial = refillReady(startMs, budget, initialDiscovery)
        discoveryCredits = discoveryCredits - (initialDiscovery - unusedInitial)
    end

    -- Priority is fixed: finish an active square first, then build/apply the next
    -- plan(s) while hard credits remain, then use any remaining discovery budget
    -- to keep the pipeline filled for the following tick.
    mutationCredits, operationChecks = applyActive(
        startMs, budget, mutationCredits, operationChecks
    )

    while not state.active and planCredits > 0 and mutationCredits > 0
        and operationChecks > 0 and readyChecks > 0 and timeAvailable(startMs, budget)
    do
        planCredits, readyChecks = buildNextPlan(
            startMs, budget, planCredits, readyChecks
        )
        if state.active then
            mutationCredits, operationChecks = applyActive(
                startMs, budget, mutationCredits, operationChecks
            )
        else
            break
        end
    end

    if timeAvailable(startMs, budget) and discoveryCredits > 0 then
        refillReady(startMs, budget, discoveryCredits)
    end

    if state.warmupActive and pendingChunkCount() == 0 and readyCount() == 0 and not state.active then
        state.warmupActive = false
        Debug.log("loaded-area warm-up complete")
    end
end

function Queue.getStats()
    local persistenceStats = Persistence.getStats()
    local existingStats = ExistingWorld.getStats()
    local cacheStats = Cache.getStats()
    local areaStats = AreaContext.getStats()
    return {
        disabled = state.disabled or not Persistence.canAgeWorld(),
        chunkSize = state.chunkSize,
        pendingChunks = pendingChunkCount(),
        highPendingChunks = state.highPendingChunks,
        visiblePendingChunks = state.visiblePendingChunks,
        outerPendingChunks = state.outerPendingChunks,
        readySquares = readyCount(),
        highReadySquares = state.highReadyCount,
        visibleReadySquares = state.visibleReadyCount,
        outerReadySquares = state.outerReadyCount,
        activeSquare = state.active and state.active.key or nil,
        catchupActive = catchupActive(),
        teleportCatchups = state.stats.teleportCatchups,
        upperSquaresSkipped = state.stats.upperSquaresSkipped,
        preAgeChunksQueued = state.stats.preAgeChunksQueued,
        chunksQueued = state.stats.chunksQueued,
        discoveryChecks = state.stats.discoveryChecks,
        squaresQueued = state.stats.squaresQueued,
        plansBuilt = state.stats.plansBuilt,
        operationChecks = state.stats.operationChecks,
        mutationsApplied = state.stats.mutationsApplied,
        featureMutationsApplied = state.stats.featureMutationsApplied,
        featureOperationsPlanned = state.stats.featureOperationsPlanned,
        warmupActive = state.warmupActive,
        preAgeActive = state.preAgeActive,
        squaresCompleted = state.stats.squaresCompleted,
        squaresDroppedUnloaded = state.stats.squaresDroppedUnloaded,
        squaresQuarantined = state.stats.squaresQuarantined,
        peakPendingChunks = state.stats.peakPendingChunks,
        peakReadySquares = state.stats.peakReadySquares,
        peakOperationsPerPlan = state.stats.peakOperationsPerPlan,
        configPartialsSealed = persistenceStats.configPartialsSealed,
        generatorPartialsSealed = persistenceStats.generatorPartialsSealed,
        invalidPartialsSealed = persistenceStats.invalidPartialsSealed,
        completionRecordsLoaded = persistenceStats.completionRecordsLoaded,
        completionRecordsWritten = persistenceStats.completionRecordsWritten,
        completionRecordHits = persistenceStats.completionRecordHits,
        completionFlushes = persistenceStats.completionFlushes,
        completedChunkLevelHits = persistenceStats.completedChunkLevelHits,
        completedChunkLevelsLoaded = persistenceStats.completedChunkLevelsLoaded,
        completedChunkLevelsWritten = persistenceStats.completedChunkLevelsWritten,
        cacheSurfaceEntries = cacheStats.surfaceEntries,
        cacheSurfaceHits = cacheStats.surfaceHits,
        cacheSurfaceMisses = cacheStats.surfaceMisses,
        cacheFloorEntries = cacheStats.floorEntries,
        cacheFloorHits = cacheStats.floorHits,
        cacheFloorMisses = cacheStats.floorMisses,
        areaContextEntries = areaStats.entries,
        areaContextHits = areaStats.hits,
        areaContextMisses = areaStats.misses,
        areaContextsClassified = areaStats.classified,
        existingForcedChunks = existingStats.forcedExisting,
        existingNewChunks = existingStats.newChunks,
        existingSkippedChunks = existingStats.existingSkipped,
        existingUnknownFreshAllowed = existingStats.unknownFreshAllowed,
        existingUnknownEstablishedSkipped = existingStats.unknownEstablishedSkipped,
        existingDisabledSkipped = existingStats.disabledSkipped,
    }
end

return Queue
