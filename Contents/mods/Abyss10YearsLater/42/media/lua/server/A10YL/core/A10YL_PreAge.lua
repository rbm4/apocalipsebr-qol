-- v0.8.x admin pre-age core.
-- This module does not change visual balance. It stores durable admin jobs in
-- A10YL.WorldState, attempts conservative chunk access, then hands eligible work
-- to the same Queue/Processor/Persistence path used by live generation.
local Queue = require("A10YL/core/A10YL_Queue")
local Persistence = require("A10YL/core/A10YL_Persistence")
local Debug = require("A10YL/core/A10YL_Debug")
local AreaContext = require("A10YL/core/A10YL_AreaContext")

local PreAge = {}

local CHUNK_SIZE = 8
local MAP_CELL_SIZE = 300
local CHUNKS_PER_TICK = 2
local MAX_JOB_CHUNKS = 10000
local FORCE_LOAD_RECHECKS = 2
local FORCE_LOAD_PENDING_RETRIES = 8

local runtime = {
    announcedActive = false,
    lastStatusTick = 0,
    stats = {
        commands = 0,
        jobsStarted = 0,
        jobsCompleted = 0,
        jobsStopped = 0,
        chunksQueued = 0,
        chunksUnavailable = 0,
        chunksSkipped = 0,
        forceLoadAttempts = 0,
        forceLoadSuccess = 0,
    },
}

local function integer(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    if value >= 0 then return math.floor(value) end
    return math.ceil(value)
end

local function now()
    if type(getTimestampMs) == "function" then
        local ok, value = pcall(getTimestampMs)
        if ok and value ~= nil then return integer(value, 0) or 0 end
    end
    if os and type(os.time) == "function" then
        local ok, value = pcall(os.time)
        if ok and value ~= nil then return integer(value, 0) or 0 end
    end
    return 0
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function safeCall(callback, fallback)
    local ok, a, b, c = pcall(callback)
    if not ok then return fallback end
    return a, b, c
end

local function isStandaloneOrHost()
    local server = type(isServer) == "function" and isServer()
    local client = type(isClient) == "function" and isClient()
    return not server and not client
end

local function isAdmin(player)
    if isStandaloneOrHost() then return true end
    if not player then return false end
    local level = safeCall(function()
        if player.getAccessLevel then return player:getAccessLevel() end
        return nil
    end, nil)
    level = lower(level)
    return level == "admin" or level == "administrator" or level == "moderator"
        or level == "overseer" or level == "gm"
end

local function playerName(player)
    return safeCall(function()
        if player and player.getUsername then return player:getUsername() end
        if player and player.getDisplayName then return player:getDisplayName() end
        return "server"
    end, "server") or "server"
end

local function notify(player, command, args)
    args = args or {}
    print("[A10YL][PREAGE] " .. tostring(args.message or command or "status"))
    if player and type(sendServerCommand) == "function" then
        local ok = pcall(sendServerCommand, player, "A10YL", command or "preageStatus", args)
        if not ok then
            pcall(sendServerCommand, "A10YL", command or "preageStatus", args)
        end
    end
end

local function worldState()
    return Persistence.getWorldState and Persistence.getWorldState() or nil
end

local function ensureStore(create)
    local ws = worldState()
    if not ws then return nil end
    if type(ws.PreAge) ~= "table" then
        if not create then return nil end
        ws.PreAge = {
            SchemaVersion = 1,
            NextJobId = 1,
            Jobs = {},
            LastUpdated = now(),
        }
    end
    local store = ws.PreAge
    if type(store.Jobs) ~= "table" then store.Jobs = {} end
    store.NextJobId = integer(store.NextJobId, 1) or 1
    return store
end

local function touch(reason)
    local store = ensureStore(false)
    if store then store.LastUpdated = now() end
    if Persistence.touch then Persistence.touch("preage:" .. tostring(reason or "update"), false) end
end

local function makeRange(minWx, maxWx, minWy, maxWy)
    minWx, maxWx = integer(minWx, 0) or 0, integer(maxWx, 0) or 0
    minWy, maxWy = integer(minWy, 0) or 0, integer(maxWy, 0) or 0
    if minWx > maxWx then minWx, maxWx = maxWx, minWx end
    if minWy > maxWy then minWy, maxWy = maxWy, minWy end
    return { minWx = minWx, maxWx = maxWx, minWy = minWy, maxWy = maxWy }
end

local function rangeChunkCount(range)
    if type(range) ~= "table" then return 0 end
    return math.max(0, (integer(range.maxWx, 0) - integer(range.minWx, 0) + 1))
        * math.max(0, (integer(range.maxWy, 0) - integer(range.minWy, 0) + 1))
end

local function totalChunkCount(ranges)
    local total = 0
    if type(ranges) ~= "table" then return 0 end
    for i = 1, #ranges do total = total + rangeChunkCount(ranges[i]) end
    return total
end

local function chunkRangeForCell(cellX, cellY)
    cellX = integer(cellX, 0) or 0
    cellY = integer(cellY, 0) or 0
    local minX = cellX * MAP_CELL_SIZE
    local minY = cellY * MAP_CELL_SIZE
    local maxX = minX + MAP_CELL_SIZE - 1
    local maxY = minY + MAP_CELL_SIZE - 1
    return makeRange(
        math.floor(minX / CHUNK_SIZE),
        math.floor(maxX / CHUNK_SIZE),
        math.floor(minY / CHUNK_SIZE),
        math.floor(maxY / CHUNK_SIZE)
    )
end

local function chunkRangeAroundSquare(x, y, radiusChunks)
    x = integer(x, nil)
    y = integer(y, nil)
    radiusChunks = math.max(0, integer(radiusChunks, 8) or 8)
    if x == nil or y == nil then return nil end
    local wx = math.floor(x / CHUNK_SIZE)
    local wy = math.floor(y / CHUNK_SIZE)
    return makeRange(wx - radiusChunks, wx + radiusChunks, wy - radiusChunks, wy + radiusChunks)
end

local function activeJob()
    local store = ensureStore(false)
    if not store then return nil end
    local jobs = store.Jobs
    for i = 1, #jobs do
        local job = jobs[i]
        if type(job) == "table" and job.status == "running" then return job end
    end
    for i = 1, #jobs do
        local job = jobs[i]
        if type(job) == "table" and job.status == "paused" then return job end
    end
    return nil
end

local function runningJob()
    local job = activeJob()
    if job and job.status == "running" then return job end
    return nil
end

local function nextJobId(store)
    local id = integer(store.NextJobId, 1) or 1
    store.NextJobId = id + 1
    return id
end

local function initialiseCursor(job)
    job.rangeIndex = integer(job.rangeIndex, 1) or 1
    local range = job.ranges and job.ranges[job.rangeIndex] or nil
    if not range then return false end
    job.cursorWx = integer(job.cursorWx, range.minWx) or range.minWx
    job.cursorWy = integer(job.cursorWy, range.minWy) or range.minWy
    return true
end

local function advanceCursor(job)
    local ranges = job.ranges
    if type(ranges) ~= "table" then return false end
    if not initialiseCursor(job) then return false end

    local range = ranges[job.rangeIndex]
    local wx = job.cursorWx
    local wy = job.cursorWy

    job.cursorWx = job.cursorWx + 1
    if job.cursorWx > range.maxWx then
        job.cursorWx = range.minWx
        job.cursorWy = job.cursorWy + 1
        if job.cursorWy > range.maxWy then
            job.rangeIndex = job.rangeIndex + 1
            range = ranges[job.rangeIndex]
            if range then
                job.cursorWx = range.minWx
                job.cursorWy = range.minWy
            else
                job.cursorWx = nil
                job.cursorWy = nil
            end
        end
    end

    return wx, wy
end

local function getLoadedSquare(x, y, z)
    if type(isServer) == "function" and isServer() then
        if ServerMap and ServerMap.instance and ServerMap.instance.getGridSquare then
            return safeCall(function() return ServerMap.instance:getGridSquare(x, y, z) end, nil)
        end
        return nil
    end
    local cell = type(getCell) == "function" and getCell() or nil
    if cell and cell.getGridSquare then
        return safeCall(function() return cell:getGridSquare(x, y, z) end, nil)
    end
    return nil
end

local function getChunkObject(wx, wy)
    local chunk
    if type(isServer) == "function" and isServer() and ServerMap and ServerMap.instance then
        if ServerMap.instance.getChunk then
            chunk = safeCall(function() return ServerMap.instance:getChunk(wx, wy) end, nil)
            if chunk then return chunk end
        end
    end
    local cell = type(getCell) == "function" and getCell() or nil
    if cell then
        if cell.getChunk then
            chunk = safeCall(function() return cell:getChunk(wx, wy) end, nil)
            if chunk then return chunk end
        end
        if cell.getChunkForGridSquare then
            chunk = safeCall(function() return cell:getChunkForGridSquare(wx * CHUNK_SIZE, wy * CHUNK_SIZE) end, nil)
            if chunk then return chunk end
        end
    end
    return nil
end

local function chunkHasLoadedGround(wx, wy)
    local baseX = wx * CHUNK_SIZE
    local baseY = wy * CHUNK_SIZE
    return getLoadedSquare(baseX, baseY, 0) ~= nil
        or getLoadedSquare(baseX + math.floor(CHUNK_SIZE / 2), baseY + math.floor(CHUNK_SIZE / 2), 0) ~= nil
        or getLoadedSquare(baseX + CHUNK_SIZE - 1, baseY + CHUNK_SIZE - 1, 0) ~= nil
end

local function attemptDebugLoadChunk(wx, wy)
    local attempted = false
    local function attempt(label, callback)
        local ok = pcall(callback)
        if ok then attempted = true end
    end

    if type(debugLoadChunk) == "function" then
        attempt("global", function() debugLoadChunk(wx, wy) end)
    end
    if MapObjects and type(MapObjects.debugLoadChunk) == "function" then
        attempt("MapObjects", function() MapObjects.debugLoadChunk(wx, wy) end)
    end

    if attempted then runtime.stats.forceLoadAttempts = runtime.stats.forceLoadAttempts + 1 end
    return attempted
end

local function ensureChunkAccessible(wx, wy)
    if getChunkObject(wx, wy) then return true, "chunk" end
    if chunkHasLoadedGround(wx, wy) then return true, "square" end

    local attempted = attemptDebugLoadChunk(wx, wy)
    if attempted then
        for _ = 1, FORCE_LOAD_RECHECKS do
            if getChunkObject(wx, wy) then
                runtime.stats.forceLoadSuccess = runtime.stats.forceLoadSuccess + 1
                return true, "debug-chunk"
            end
            if chunkHasLoadedGround(wx, wy) then
                runtime.stats.forceLoadSuccess = runtime.stats.forceLoadSuccess + 1
                return true, "debug-square"
            end
        end
    end

    return false, attempted and "force-load-unavailable" or "no-loader"
end

local function summariseJob(job)
    if type(job) ~= "table" then return "no pre-age job" end
    return "job #" .. tostring(job.id)
        .. " " .. tostring(job.label or job.kind or "preage")
        .. " status=" .. tostring(job.status)
        .. " queued=" .. tostring(job.queued or 0)
        .. " skipped=" .. tostring(job.skipped or 0)
        .. " unavailable=" .. tostring(job.unavailable or 0)
        .. " cursor=" .. tostring(job.processed or 0) .. "/" .. tostring(job.totalChunks or 0)
end

local function createJob(kind, label, ranges, player)
    local store = ensureStore(true)
    if not store then return nil, "world-state-unavailable" end
    if runningJob() then return nil, "another-job-running" end

    local total = totalChunkCount(ranges)
    if total < 1 then return nil, "empty-job" end
    if total > MAX_JOB_CHUNKS then return nil, "too-large" end

    local id = nextJobId(store)
    local timestamp = now()
    local job = {
        id = id,
        schema = 1,
        kind = tostring(kind or "custom"),
        label = tostring(label or kind or "custom"),
        status = "running",
        ranges = ranges,
        rangeIndex = 1,
        cursorWx = ranges[1].minWx,
        cursorWy = ranges[1].minWy,
        totalChunks = total,
        processed = 0,
        queued = 0,
        skipped = 0,
        unavailable = 0,
        errors = 0,
        areaCounts = {},
        createdAt = timestamp,
        updatedAt = timestamp,
        createdBy = playerName(player),
    }
    store.Jobs[#store.Jobs + 1] = job
    runtime.stats.jobsStarted = runtime.stats.jobsStarted + 1
    touch("job-start")
    print("[A10YL][PREAGE] started " .. summariseJob(job))
    return job, nil
end

function PreAge.startCell(cellX, cellY, player)
    cellX = integer(cellX, nil)
    cellY = integer(cellY, nil)
    if cellX == nil or cellY == nil then return nil, "invalid-cell" end
    return createJob("cell", "cell " .. tostring(cellX) .. ":" .. tostring(cellY), { chunkRangeForCell(cellX, cellY) }, player)
end

function PreAge.startRadiusAroundPlayer(player, radiusChunks)
    if not player then return nil, "missing-player" end
    local x = safeCall(function() return player:getX() end, nil)
    local y = safeCall(function() return player:getY() end, nil)
    x, y = integer(x, nil), integer(y, nil)
    if x == nil or y == nil then return nil, "invalid-player-position" end
    radiusChunks = math.max(1, math.min(64, integer(radiusChunks, 12) or 12))
    local range = chunkRangeAroundSquare(x, y, radiusChunks)
    if not range then return nil, "invalid-radius" end
    return createJob("radius", "radius " .. tostring(radiusChunks) .. " chunks around " .. playerName(player), { range }, player)
end

function PreAge.startChunkRadius(wx, wy, radiusChunks, player)
    wx = integer(wx, nil)
    wy = integer(wy, nil)
    if wx == nil or wy == nil then return nil, "invalid-chunk" end
    radiusChunks = math.max(1, math.min(64, integer(radiusChunks, 12) or 12))
    local range = makeRange(wx - radiusChunks, wx + radiusChunks, wy - radiusChunks, wy + radiusChunks)
    return createJob("chunk-radius", "radius " .. tostring(radiusChunks) .. " chunks around chunk " .. tostring(wx) .. ":" .. tostring(wy), { range }, player)
end

function PreAge.pause(player)
    local job = runningJob()
    if not job then return nil, "no-running-job" end
    job.status = "paused"
    job.updatedAt = now()
    touch("pause")
    print("[A10YL][PREAGE] paused " .. summariseJob(job))
    return job, nil
end

function PreAge.resume(player)
    local job = activeJob()
    if not job or job.status ~= "paused" then return nil, "no-paused-job" end
    job.status = "running"
    job.updatedAt = now()
    touch("resume")
    print("[A10YL][PREAGE] resumed " .. summariseJob(job))
    return job, nil
end

function PreAge.stop(player)
    local job = activeJob()
    if not job or (job.status ~= "running" and job.status ~= "paused") then return nil, "no-active-job" end
    job.status = "stopped"
    job.updatedAt = now()
    runtime.stats.jobsStopped = runtime.stats.jobsStopped + 1
    touch("stop")
    print("[A10YL][PREAGE] stopped " .. summariseJob(job))
    return job, nil
end

function PreAge.status()
    local store = ensureStore(false)
    local job = activeJob()
    return {
        active = job ~= nil,
        summary = summariseJob(job),
        jobId = job and job.id or nil,
        status = job and job.status or nil,
        queued = job and job.queued or 0,
        skipped = job and job.skipped or 0,
        unavailable = job and job.unavailable or 0,
        processed = job and job.processed or 0,
        totalChunks = job and job.totalChunks or 0,
        storedJobs = store and store.Jobs and #store.Jobs or 0,
        chunksQueued = runtime.stats.chunksQueued,
        chunksUnavailable = runtime.stats.chunksUnavailable,
        chunksSkipped = runtime.stats.chunksSkipped,
        forceLoadAttempts = runtime.stats.forceLoadAttempts,
        forceLoadSuccess = runtime.stats.forceLoadSuccess,
        roadRoutePreAge = "deferred",
    }
end

local function recordArea(job, wx, wy)
    local square = getLoadedSquare(wx * CHUNK_SIZE, wy * CHUNK_SIZE, 0)
    if not square then return end
    local context = AreaContext.get(square)
    local areaType = context and context.kind or "unknown"
    job.areaCounts = job.areaCounts or {}
    job.areaCounts[areaType] = (job.areaCounts[areaType] or 0) + 1
end

local function enqueuePreAgeChunk(job, wx, wy)
    local accessible = false
    local reason = "unknown"
    accessible, reason = ensureChunkAccessible(wx, wy)
    if not accessible then
        if reason == "force-load-unavailable" and (integer(job.retryCount, 0) or 0) < FORCE_LOAD_PENDING_RETRIES then
            job.retryWx = wx
            job.retryWy = wy
            job.retryCount = (integer(job.retryCount, 0) or 0) + 1
            return false, "force-load-pending"
        end
        job.retryWx = nil
        job.retryWy = nil
        job.retryCount = 0
        job.unavailable = (job.unavailable or 0) + 1
        runtime.stats.chunksUnavailable = runtime.stats.chunksUnavailable + 1
        return false, reason
    end

    job.retryWx = nil
    job.retryWy = nil
    job.retryCount = 0
    recordArea(job, wx, wy)

    local chunk = getChunkObject(wx, wy)
    local queued, queueReason
    if chunk then
        queued, queueReason = Queue.enqueueChunk(chunk)
    else
        queued, queueReason = Queue.enqueuePreAgeChunk(wx, wy, 0, 0, "normal")
    end

    if queued then
        job.queued = (job.queued or 0) + 1
        runtime.stats.chunksQueued = runtime.stats.chunksQueued + 1
        return true, queueReason or "queued"
    end

    job.skipped = (job.skipped or 0) + 1
    runtime.stats.chunksSkipped = runtime.stats.chunksSkipped + 1
    return false, queueReason or "skipped"
end

function PreAge.onTick()
    if not Persistence.canAgeWorld() then
        Queue.setPreAgeActive(false)
        return
    end

    local job = runningJob()
    Queue.setPreAgeActive(job ~= nil)
    if not job then
        runtime.announcedActive = false
        return
    end

    if not runtime.announcedActive then
        runtime.announcedActive = true
        Debug.log("[PREAGE] active " .. summariseJob(job))
    end

    local processedThisTick = 0
    while processedThisTick < CHUNKS_PER_TICK do
        local wx, wy
        if job.retryWx ~= nil and job.retryWy ~= nil then
            wx, wy = integer(job.retryWx, nil), integer(job.retryWy, nil)
        else
            wx, wy = advanceCursor(job)
            if wx ~= nil and wy ~= nil then
                job.processed = (job.processed or 0) + 1
            end
        end

        if wx == nil or wy == nil then
            job.status = "complete"
            job.updatedAt = now()
            runtime.stats.jobsCompleted = runtime.stats.jobsCompleted + 1
            Queue.setPreAgeActive(false)
            touch("complete")
            print("[A10YL][PREAGE] complete " .. summariseJob(job))
            return
        end

        enqueuePreAgeChunk(job, wx, wy)
        processedThisTick = processedThisTick + 1
    end

    job.updatedAt = now()
    if (job.processed or 0) % 128 == 0 then
        touch("progress")
        Debug.log("[PREAGE] progress " .. summariseJob(job))
    end
end

function PreAge.onSave()
    touch("save")
end


local function helpMessage()
    return "pre-age commands: status, radius <chunks>, cell <cellX> <cellY>, chunk-radius <wx> <wy> <chunks>, pause, resume, stop, disable-ageing, enable-ageing. Road-route pre-age is deferred; use selected cells/radius for route testing."
end

local function commandError(player, reason)
    notify(player, "preageStatus", { ok = false, message = "pre-age command failed: " .. tostring(reason) })
end

function PreAge.onClientCommand(module, command, player, args)
    if module ~= "A10YL" or command ~= "preage" then return false end
    runtime.stats.commands = runtime.stats.commands + 1
    args = type(args) == "table" and args or {}

    if not isAdmin(player) then
        commandError(player, "admin-only")
        return true
    end

    local action = lower(args.action or args[1] or "status")
    local job, err

    if action == "status" then
        local status = PreAge.status()
        status.ok = true
        status.message = status.summary
        notify(player, "preageStatus", status)
        return true
    elseif action == "help" then
        notify(player, "preageStatus", { ok = true, message = helpMessage() })
        return true
    elseif action == "route" or action == "road-route" or action == "roadroute" then
        notify(player, "preageStatus", { ok = false, message = "road-route pre-age is deferred; use radius/cell/chunk-radius jobs for v0.8.5 testing" })
        return true
    elseif action == "cell" then
        job, err = PreAge.startCell(args.cellX or args.x or args[2], args.cellY or args.y or args[3], player)
    elseif action == "radius" then
        job, err = PreAge.startRadiusAroundPlayer(player, args.radius or args.radiusChunks or args[2])
    elseif action == "chunk-radius" or action == "chunkradius" then
        job, err = PreAge.startChunkRadius(args.wx or args.x or args[2], args.wy or args.y or args[3], args.radius or args.radiusChunks or args[4], player)
    elseif action == "pause" then
        job, err = PreAge.pause(player)
    elseif action == "resume" then
        job, err = PreAge.resume(player)
    elseif action == "stop" then
        job, err = PreAge.stop(player)
    elseif action == "disable-ageing" or action == "disable-aging" or action == "disable" then
        Queue.setDisabled(true, "admin-command")
        notify(player, "preageStatus", { ok = true, message = "A10YL ageing disabled" })
        return true
    elseif action == "enable-ageing" or action == "enable-aging" or action == "enable" then
        Queue.setDisabled(false, "admin-command")
        notify(player, "preageStatus", { ok = true, message = "A10YL ageing enabled" })
        return true
    else
        err = "unknown-action"
    end

    if not job then
        commandError(player, err)
        return true
    end

    notify(player, "preageStatus", { ok = true, message = summariseJob(job), jobId = job.id })
    return true
end

function PreAge.getStats()
    local status = PreAge.status()
    status.commands = runtime.stats.commands
    status.jobsStarted = runtime.stats.jobsStarted
    status.jobsCompleted = runtime.stats.jobsCompleted
    status.jobsStopped = runtime.stats.jobsStopped
    return status
end

return PreAge
