-- Server-private, versioned save state for deterministic and crash-safe ageing.
-- Runtime queues/plans and live game objects must never be stored here.
local Random = require("A10YL/core/A10YL_Random")
local Debug = require("A10YL/core/A10YL_Debug")
local Text = require("A10YL/A10YL_Translation")

local Persistence = {}

Persistence.WORLD_STATE_KEY = "A10YL.WorldState"
Persistence.SCHEMA_VERSION = 1
-- Checkpoint #48 changes deterministic vegetation decisions for natural woody succession.
-- Roadmap point #4 changes deterministic road-overlay density plus streaming/
-- preload materialisation semantics. Generator 22 is v0.8.0: runtime optimisation,
-- lazy classification, reduced persistence checkpoint churn, chunk-level completion
-- summaries and the Background Only processing mode. Generator 23 is v0.8.1:
-- chunk area-context classification for wilderness/rural/roadside/town/industrial
-- weighting before future admin pre-age jobs are introduced. Generator 24 is v0.8.2
-- and remains current for v0.8.6 because the v0.8.3-v0.8.6 passes only optimise, polish command handling,
-- and harden runtime/persistence paths without changing deterministic output.
Persistence.GENERATOR_VERSION = 27
Persistence.BUILD_VERSION = "0.9.1"
Persistence.CHECKPOINT = 73
Persistence.WORLD_LINEAGE_VERSION = 2
Persistence.FINAL_STAGE = 7
Persistence.MIN_WORLD_SEED = 1
Persistence.MAX_WORLD_SEED = 2147483646
Persistence.COMPLETION_CHUNK_SIZE = 8
Persistence.COMPLETION_FLUSH_INTERVAL = 1
-- Hosted B42.20.4 has been observed to pass newGame=false even on the very
-- first load of a newly-created host world. At that point A10YL has no saved
-- state/backup and getWorldAgeHours() reports the initial world age (2 hours
-- in the verified default-start test). This narrow bootstrap window lets us
-- recognise that case without treating an established first-install save as
-- fresh merely because its chunk-newness API is unavailable.
Persistence.FRESH_BOOT_MAX_WORLD_AGE_HOURS = 6
-- Generator 26 is the live-square persistence generation. Squares completed by
-- generators 24/25 are deliberately eligible for one safe re-pass. Generator 26
-- moves save-sensitive mutation out of LoadChunk preload, restores B42's actual
-- 8x8 chunk geometry, and makes square modData the correctness authority.
Persistence.PERSISTENCE_REPAIR_FROM_GENERATORS = { [24] = true, [25] = true, [26] = true }

local runtime = {
    ready = false,
    failed = false,
    failureReason = nil,
    worldState = nil,
    worldStateCreatedThisInit = false,
    pendingNewGameSignal = nil,
    pendingNewGameSignalSource = nil,
    lineageSource = "unknown",
    completedChunkLevels = {},
    stats = {
        configPartialsSealed = 0,
        generatorPartialsSealed = 0,
        invalidPartialsSealed = 0,
        completionRecordsLoaded = 0,
        completionRecordsWritten = 0,
        completionRecordHits = 0,
        completionFlushes = 0,
        completedChunkLevelHits = 0,
        completedChunkLevelsLoaded = 0,
        completedChunkLevelsWritten = 0,
    },
    dirtyCompletionWrites = 0,
}

local function integer(value)
    value = tonumber(value)
    if value == nil then return nil end
    if value >= 0 then return math.floor(value) end
    return math.ceil(value)
end

local function exactInteger(value)
    value = tonumber(value)
    if value == nil or value ~= value then return nil end
    if value < 0 then
        if math.ceil(value) ~= value then return nil end
    elseif math.floor(value) ~= value then
        return nil
    end
    return value
end

local function resetStats()
    runtime.stats.configPartialsSealed = 0
    runtime.stats.generatorPartialsSealed = 0
    runtime.stats.invalidPartialsSealed = 0
    runtime.stats.completionRecordsLoaded = 0
    runtime.stats.completionRecordsWritten = 0
    runtime.stats.completionRecordHits = 0
    runtime.stats.completionFlushes = 0
    runtime.stats.completedChunkLevelHits = 0
    runtime.stats.completedChunkLevelsLoaded = 0
    runtime.stats.completedChunkLevelsWritten = 0
    runtime.completedChunkLevels = {}
    runtime.dirtyCompletionWrites = 0
end

local function fail(reason)
    runtime.ready = false
    runtime.failed = true
    runtime.failureReason = tostring(reason)
    runtime.worldState = nil
    Debug.once("persistence-disabled:" .. runtime.failureReason, "ERROR",
        Text.format(
            "IGUI_A10YL_Error_PersistenceDisabled",
            "{reason} A10YL ageing is disabled for this save.",
            { reason = runtime.failureReason }
        ))
    return false
end

local function getExistingWorldState()
    if not ModData then
        return nil, Text.get(
            "IGUI_A10YL_Error_GlobalModDataUnavailable",
            "The game's global mod-data service is unavailable."
        )
    end

    if type(ModData.get) == "function" then
        local ok, value = pcall(ModData.get, Persistence.WORLD_STATE_KEY)
        if not ok then
            return nil, Text.get(
                "IGUI_A10YL_Error_GlobalModDataRead",
                "The saved A10YL world state could not be read."
            )
        end
        return value, nil
    end

    if type(ModData.exists) == "function" and type(ModData.getOrCreate) == "function" then
        local okExists, exists = pcall(ModData.exists, Persistence.WORLD_STATE_KEY)
        if not okExists then
            return nil, Text.get(
                "IGUI_A10YL_Error_GlobalModDataInspect",
                "The saved A10YL world state could not be inspected."
            )
        end
        if not exists then return nil, nil end
        local okGet, value = pcall(ModData.getOrCreate, Persistence.WORLD_STATE_KEY)
        if not okGet then
            return nil, Text.get(
                "IGUI_A10YL_Error_GlobalModDataReadExisting",
                "The existing A10YL world state could not be read."
            )
        end
        return value, nil
    end

    return nil, Text.get(
        "IGUI_A10YL_Error_GlobalModDataReadUnavailable",
        "The game cannot provide the saved A10YL world state."
    )
end


-- Small redundant world identity stored in GameTime modData. Global ModData is
-- still kept for diagnostics/acceleration, but generator seed and fresh-world
-- lineage no longer depend on it being present after a hosted-server restart.
local GT_SEED_KEY = "A10YL_WorldSeed"
local GT_FRESH_KEY = "A10YL_FreshWorldLineage"
local GT_LINEAGE_VERSION_KEY = "A10YL_WorldLineageVersion"
local GT_INITIAL_GENERATOR_KEY = "A10YL_InitialGeneratorVersion"

local function getGameTimeModData()
    local gameTime = nil
    if GameTime and type(GameTime.getInstance) == "function" then
        local ok, value = pcall(GameTime.getInstance)
        if ok then gameTime = value end
    end
    if not gameTime and type(getGameTime) == "function" then
        local ok, value = pcall(getGameTime)
        if ok then gameTime = value end
    end
    if not gameTime or type(gameTime.getModData) ~= "function" then return nil end
    local ok, value = pcall(gameTime.getModData, gameTime)
    if not ok or type(value) ~= "table" then return nil end
    return value
end

local function readGameTimeBackup()
    local data = getGameTimeModData()
    if not data then return nil end
    local seed = exactInteger(data[GT_SEED_KEY])
    if seed == nil or seed < Persistence.MIN_WORLD_SEED or seed > Persistence.MAX_WORLD_SEED then
        return nil
    end
    return {
        WorldSeed = seed,
        FreshWorldLineage = data[GT_FRESH_KEY] == true,
        WorldLineageVersion = exactInteger(data[GT_LINEAGE_VERSION_KEY]) or Persistence.WORLD_LINEAGE_VERSION,
        InitialGeneratorVersion = exactInteger(data[GT_INITIAL_GENERATOR_KEY]),
    }
end

local function writeGameTimeBackup(value)
    if type(value) ~= "table" then return false end
    local data = getGameTimeModData()
    if not data then return false end
    local seed = exactInteger(value.WorldSeed)
    if seed == nil then return false end
    data[GT_SEED_KEY] = seed
    data[GT_FRESH_KEY] = value.FreshWorldLineage == true
    data[GT_LINEAGE_VERSION_KEY] = exactInteger(value.WorldLineageVersion) or Persistence.WORLD_LINEAGE_VERSION
    data[GT_INITIAL_GENERATOR_KEY] = exactInteger(value.InitialGeneratorVersion) or Persistence.GENERATOR_VERSION
    return true
end

local function currentWorldAgeHours()
    if type(getGameTime) ~= "function" then return nil end
    local okTime, gameTime = pcall(getGameTime)
    if not okTime or not gameTime or type(gameTime.getWorldAgeHours) ~= "function" then
        return nil
    end
    local okAge, age = pcall(gameTime.getWorldAgeHours, gameTime)
    age = okAge and tonumber(age) or nil
    if age == nil or age ~= age or age < 0 then return nil end
    return age
end

local function canRepairFalseFreshLineage(value, backup)
    if type(value) ~= "table" or value.FreshWorldLineage == true then return false end
    -- Only repair a false primary flag when the already-saved redundant
    -- GameTime identity explicitly says this save was created as a fresh A10YL
    -- world. Never infer freshness merely because A10YL has no completion data.
    return backup ~= nil and backup.FreshWorldLineage == true
end

function Persistence.noteNewGameSignal(newGame, source)
    source = tostring(source or "unknown")

    -- Some hosted builds fire OnLoadRadioScripts after Global ModData has
    -- already initialised. A late TRUE signal is still authoritative and may
    -- safely promote only the state created during this same first bootstrap.
    -- Late FALSE signals are ignored so they cannot leak into a later world in
    -- the same Lua VM.
    if runtime.ready == true then
        if newGame == true and runtime.worldStateCreatedThisInit == true
            and type(runtime.worldState) == "table"
        then
            runtime.worldState.FreshWorldLineage = true
            runtime.worldState.WorldLineageVersion = Persistence.WORLD_LINEAGE_VERSION
            runtime.lineageSource = source .. "-late"
            writeGameTimeBackup(runtime.worldState)
            print("[A10YL] LATE NEW-GAME SIGNAL: " .. source .. " promoted this first-bootstrap world to fresh-A10YL-world")
        end
        return
    end

    if newGame == true then
        runtime.pendingNewGameSignal = true
        runtime.pendingNewGameSignalSource = source
    elseif runtime.pendingNewGameSignal == nil then
        runtime.pendingNewGameSignal = false
        runtime.pendingNewGameSignalSource = source
    end
end

function Persistence.getLineageSource()
    return tostring(runtime.lineageSource or "unknown")
end

local function createWorldState()
    if not ModData or type(ModData.getOrCreate) ~= "function" then
        return nil, Text.get(
            "IGUI_A10YL_Error_GlobalModDataCreateUnavailable",
            "The game cannot create the A10YL world state."
        )
    end
    local ok, value = pcall(ModData.getOrCreate, Persistence.WORLD_STATE_KEY)
    if not ok or value == nil then
        return nil, Text.get(
            "IGUI_A10YL_Error_GlobalModDataCreate",
            "The A10YL world state could not be created."
        )
    end
    return value, nil
end

local function normalizeSeed(value)
    value = exactInteger(value)
    if value == nil then return nil end
    local span = Persistence.MAX_WORLD_SEED
    value = value % span
    if value < 0 then value = value + span end
    return value + 1
end

local function hashSeedString(text)
    text = tostring(text or "")
    if text == "" then return nil end
    local value = 0
    local span = Persistence.MAX_WORLD_SEED
    for i = 1, #text do
        value = (value * 131 + string.byte(text, i)) % span
    end
    return value + 1
end

-- Checkpoint 72: deterministic ageing is anchored to Project Zomboid's own
-- persisted world-generation seed. A10YL's previous random private seed could
-- change after a hosted-server restart when Global/GameTime modData failed to
-- survive, which made a reconstructed area look different after restarting.
local function getProjectZomboidWorldSeed()
    if WorldGenParams and WorldGenParams.INSTANCE then
        local okSeed, seed = pcall(function()
            return WorldGenParams.INSTANCE:getSeed()
        end)
        seed = okSeed and normalizeSeed(seed) or nil
        if seed ~= nil then
            local seedString = nil
            local okString, value = pcall(function()
                return WorldGenParams.INSTANCE:getSeedString()
            end)
            if okString and value ~= nil then seedString = tostring(value) end
            return seed, "WorldGenParams.getSeed", seedString
        end

        local okString, value = pcall(function()
            return WorldGenParams.INSTANCE:getSeedString()
        end)
        if okString and value ~= nil then
            local hashed = hashSeedString(value)
            if hashed ~= nil then
                return hashed, "WorldGenParams.getSeedString", tostring(value)
            end
        end
    end
    return nil, nil, nil
end

local function freshSeed()
    local seed
    if type(ZombRand) == "function" then
        local ok, value = pcall(ZombRand, Persistence.MAX_WORLD_SEED)
        if ok then seed = integer(value) end
    end
    if seed == nil and type(getTimestampMs) == "function" then
        local ok, value = pcall(getTimestampMs)
        if ok then seed = integer(value) end
    end
    return normalizeSeed(seed or 0)
end


local function squareCoordinates(square)
    if not square then return nil, nil, nil end
    local getX, getY, getZ = square.getX, square.getY, square.getZ
    if type(getX) ~= "function" or type(getY) ~= "function" or type(getZ) ~= "function" then
        return nil, nil, nil
    end
    local okX, x = pcall(getX, square)
    local okY, y = pcall(getY, square)
    local okZ, z = pcall(getZ, square)
    if not okX or not okY or not okZ then return nil, nil, nil end
    x, y, z = integer(x), integer(y), integer(z)
    if x == nil or y == nil or z == nil then return nil, nil, nil end
    return x, y, z
end

local function localIndex(value)
    local size = Persistence.COMPLETION_CHUNK_SIZE
    return value - math.floor(value / size) * size
end

local function completionKeyFromCoords(x, y, z)
    local size = Persistence.COMPLETION_CHUNK_SIZE
    return tostring(math.floor(x / size)) .. ":" .. tostring(math.floor(y / size)) .. ":" .. tostring(z)
end

local function completionKeyFromChunkLevel(wx, wy, z)
    return tostring(integer(wx)) .. ":" .. tostring(integer(wy)) .. ":" .. tostring(integer(z))
end

local function completionSlotFromCoords(x, y)
    return tostring(localIndex(y) * Persistence.COMPLETION_CHUNK_SIZE + localIndex(x) + 1)
end

local function completionVersion(value)
    -- Boolean chunk summaries from older optimisation builds are unversioned.
    -- Do not treat them as current on their own; rebuild current summaries from
    -- explicit per-square generator-version records below.
    if value == true then return nil end
    return integer(value)
end

local function isCurrentCompletionVersion(value)
    return completionVersion(value) == Persistence.GENERATOR_VERSION
end

local function ensureCompletionStore(create)
    if not runtime.worldState then return nil end
    if type(runtime.worldState.CompletedSquares) ~= "table" then
        if not create then return nil end
        runtime.worldState.CompletedSquares = {}
    end
    return runtime.worldState.CompletedSquares
end

local function countCompletionRecords(store)
    if type(store) ~= "table" then return 0 end
    local count = 0
    local ok = pcall(function()
        for _, chunkRecord in pairs(store) do
            if type(chunkRecord) == "table" then
                for _, value in pairs(chunkRecord) do
                    if value ~= nil then count = count + 1 end
                end
            end
        end
    end)
    if not ok then return 0 end
    return count
end

local function rebuildCompletedChunkLevelIndex(value)
    runtime.completedChunkLevels = {}
    local saved = type(value.CompletedChunkLevels) == "table" and value.CompletedChunkLevels or {}
    for key, flag in pairs(saved) do
        if flag == true then
            -- Unversioned summary only; it will be recreated below if all 64
            -- per-square records are explicitly current-version completions.
            saved[key] = nil
        elseif isCurrentCompletionVersion(flag) then
            runtime.completedChunkLevels[tostring(key)] = Persistence.GENERATOR_VERSION
        end
    end

    local completedSquares = type(value.CompletedSquares) == "table" and value.CompletedSquares or {}
    for key, chunkRecord in pairs(completedSquares) do
        if type(chunkRecord) == "table" then
            local count = 0
            for _, slotValue in pairs(chunkRecord) do
                if isCurrentCompletionVersion(slotValue) then count = count + 1 end
            end
            if count >= (Persistence.COMPLETION_CHUNK_SIZE * Persistence.COMPLETION_CHUNK_SIZE) then
                runtime.completedChunkLevels[tostring(key)] = Persistence.GENERATOR_VERSION
                saved[tostring(key)] = Persistence.GENERATOR_VERSION
            end
        end
    end

    local count = 0
    for _, _ in pairs(runtime.completedChunkLevels) do count = count + 1 end
    runtime.stats.completedChunkLevelsLoaded = count
end

local function markCompletedChunkLevel(key)
    if not key or runtime.completedChunkLevels[key] == Persistence.GENERATOR_VERSION then return false end
    runtime.completedChunkLevels[key] = Persistence.GENERATOR_VERSION
    if runtime.worldState then
        if type(runtime.worldState.CompletedChunkLevels) ~= "table" then
            runtime.worldState.CompletedChunkLevels = {}
        end
        runtime.worldState.CompletedChunkLevels[key] = Persistence.GENERATOR_VERSION
    end
    runtime.stats.completedChunkLevelsWritten = runtime.stats.completedChunkLevelsWritten + 1
    runtime.dirtyCompletionWrites = runtime.dirtyCompletionWrites + 1
    return true
end

local function touchWorldState(reason, force)
    if not runtime.ready or not runtime.worldState then return false end

    -- ModData.getOrCreate returns the registered persistent table. Keep the
    -- runtime reference tied to that table so B42's normal Global ModData save
    -- path serialises the advisory index and world identity.
    if ModData and type(ModData.getOrCreate) == "function" then
        local ok, registered = pcall(ModData.getOrCreate, Persistence.WORLD_STATE_KEY)
        if not ok or type(registered) ~= "table" then
            Debug.once("global-moddata-touch-failed", "WARN", "A10YL could not access its registered Global ModData table while saving world state.")
            return false
        end
        if registered ~= runtime.worldState then
            for key, value in pairs(runtime.worldState) do
                registered[key] = value
            end
            runtime.worldState = registered
        end
    end

    -- Redundant primitive backup for the two correctness-critical identity
    -- fields used before any square is processed after a restart.
    writeGameTimeBackup(runtime.worldState)

    runtime.dirtyCompletionWrites = 0
    runtime.stats.completionFlushes = runtime.stats.completionFlushes + 1
    if force == true then
        Debug.log("A10YL persistent world metadata flushed: " .. tostring(reason or "manual"))
    end
    return true
end

local function transmitSquareModData(square, reason)
    -- Checkpoint 72: A10YL processing markers are server-private bookkeeping.
    -- Sending begin/stage/final ModData for every square flooded B42 hosted MP's
    -- ReceiveModData/ObjectModData packet budget. Persist locally by dirtying and
    -- hot-saving the square/chunk; clients do not need A10YL_PG/PS/PH/PV.
    if not square then return false end
    if type(square.setSquareChanged) == "function" then
        pcall(square.setSquareChanged, square)
    end
    if type(square.flagForHotSave) == "function" then
        pcall(square.flagForHotSave, square)
    end
    if type(square.getChunk) == "function" then
        local okChunk, chunk = pcall(square.getChunk, square)
        if okChunk and chunk and type(chunk.flagForHotSave) == "function" then
            pcall(chunk.flagForHotSave, chunk)
        end
    end
    return true
end

local function recordCompletion(square, version)
    local x, y, z = squareCoordinates(square)
    if x == nil then return false end

    local store = ensureCompletionStore(true)
    if not store then return false end

    local chunkKey = completionKeyFromCoords(x, y, z)
    local slot = completionSlotFromCoords(x, y)
    local chunkRecord = store[chunkKey]
    if type(chunkRecord) ~= "table" then
        chunkRecord = {}
        store[chunkKey] = chunkRecord
    end

    local currentVersion = integer(version) or Persistence.GENERATOR_VERSION
    local wroteNewSlot = chunkRecord[slot] ~= currentVersion
    if wroteNewSlot then
        runtime.stats.completionRecordsWritten = runtime.stats.completionRecordsWritten + 1
        runtime.dirtyCompletionWrites = runtime.dirtyCompletionWrites + 1
        chunkRecord[slot] = currentVersion
    end

    if wroteNewSlot then
        local count = 0
        for _, slotValue in pairs(chunkRecord) do
            if isCurrentCompletionVersion(slotValue) then count = count + 1 end
        end
        if count >= (Persistence.COMPLETION_CHUNK_SIZE * Persistence.COMPLETION_CHUNK_SIZE) then
            markCompletedChunkLevel(chunkKey)
        end
    end

    if runtime.dirtyCompletionWrites >= Persistence.COMPLETION_FLUSH_INTERVAL then
        -- v0.8.6: persistence testing showed that delayed completion-index
        -- flushing was too fragile during hosted-server restart checks. Flush
        -- every completed square for now; deterministic output is unchanged.
        touchWorldState("completion")
    end
    return true
end

local function hasCompletionRecord(square)
    local x, y, z = squareCoordinates(square)
    if x == nil then return false end
    local store = ensureCompletionStore(false)
    if not store then return false end
    local chunkRecord = store[completionKeyFromCoords(x, y, z)]
    if type(chunkRecord) ~= "table" then return false end
    return isCurrentCompletionVersion(chunkRecord[completionSlotFromCoords(x, y)])
end

local function validateWorldState(value)
    if type(value) ~= "table" then
        return false, Text.get(
            "IGUI_A10YL_Error_WorldStateInvalid",
            "The saved A10YL world state is invalid."
        )
    end
    if exactInteger(value.SchemaVersion) ~= Persistence.SCHEMA_VERSION then
        return false, Text.format(
            "IGUI_A10YL_Error_WorldStateVersion",
            "The saved A10YL world-state version ({version}) is not supported.",
            { version = value.SchemaVersion }
        )
    end
    local seed = exactInteger(value.WorldSeed)
    if seed == nil or seed < Persistence.MIN_WORLD_SEED
        or seed > Persistence.MAX_WORLD_SEED
    then
        return false, Text.get(
            "IGUI_A10YL_Error_WorldStateSeed",
            "The saved A10YL world state has no valid ageing seed."
        )
    end
    return true, seed
end

function Persistence.onInitGlobalModData(newGame)
    runtime.ready = false
    runtime.failed = false
    runtime.failureReason = nil
    runtime.worldState = nil
    runtime.worldStateCreatedThisInit = false
    runtime.lineageSource = "unknown"
    resetStats()

    local value, readError = getExistingWorldState()
    if readError then return fail(readError) end
    local stateExisted = value ~= nil
    local backup = readGameTimeBackup()
    local worldAgeHours = currentWorldAgeHours()
    local pzWorldSeed, pzSeedSource, pzSeedString = getProjectZomboidWorldSeed()

    -- B42 documents OnInitGlobalModData(newGame), but hosted-server testing can
    -- reach this callback with false after a host reset. OnLoadRadioScripts also
    -- exposes a newGame boolean. Checkpoint 71 also has a narrow first-boot
    -- world-age fallback for hosted worlds where both timing paths fail.
    local initSignal = newGame == true
    local radioSignal = runtime.pendingNewGameSignal == true
    local freshBootstrapHeuristic = stateExisted == false
        and backup == nil
        and worldAgeHours ~= nil
        and worldAgeHours <= Persistence.FRESH_BOOT_MAX_WORLD_AGE_HOURS
    local isNewGame = initSignal or radioSignal or freshBootstrapHeuristic

    if value == nil then
        value, readError = createWorldState()
        if not value then return fail(readError) end
        value.SchemaVersion = Persistence.SCHEMA_VERSION
        value.WorldSeed = pzWorldSeed or (backup and backup.WorldSeed) or freshSeed()
        value.InitialGeneratorVersion = backup and backup.InitialGeneratorVersion or Persistence.GENERATOR_VERSION
        value.ExistingSaveSupportVersion = 1
        value.FirstRunWorldAgeHours = worldAgeHours
        if isNewGame then
            value.FreshWorldLineage = true
        elseif backup then
            value.FreshWorldLineage = backup.FreshWorldLineage == true
        else
            value.FreshWorldLineage = false
        end
        value.WorldLineageVersion = backup and backup.WorldLineageVersion or Persistence.WORLD_LINEAGE_VERSION
        runtime.worldStateCreatedThisInit = true
    else
        -- Project Zomboid's world-generation seed is the deterministic authority.
        -- This intentionally overrides the old private A10YL seed so reconstruction
        -- remains identical even if A10YL Global/GameTime metadata is absent.
        if pzWorldSeed ~= nil then
            value.WorldSeed = pzWorldSeed
        elseif value.WorldSeed == nil and backup then
            value.WorldSeed = backup.WorldSeed
        end

        local repairedFalseLineage = canRepairFalseFreshLineage(value, backup)
        if value.FreshWorldLineage == nil or repairedFalseLineage then
            if isNewGame or repairedFalseLineage then
                value.FreshWorldLineage = true
            elseif backup then
                value.FreshWorldLineage = backup.FreshWorldLineage == true
            else
                value.FreshWorldLineage = false
            end
        end
        if value.WorldLineageVersion == nil or repairedFalseLineage then
            value.WorldLineageVersion = Persistence.WORLD_LINEAGE_VERSION
        end
    end

    if type(value.CompletedSquares) ~= "table" then value.CompletedSquares = {} end
    if type(value.CompletedChunkLevels) ~= "table" then value.CompletedChunkLevels = {} end
    if value.ExistingSaveSupportVersion == nil then value.ExistingSaveSupportVersion = 1 end
    if value.InitialGeneratorVersion == nil then value.InitialGeneratorVersion = Persistence.GENERATOR_VERSION end

    local valid, seedOrError = validateWorldState(value)
    if not valid then return fail(seedOrError) end

    if value.FreshWorldLineage == true then
        if initSignal then
            runtime.lineageSource = "OnInitGlobalModData"
        elseif radioSignal then
            runtime.lineageSource = "OnLoadRadioScripts"
        elseif backup and backup.FreshWorldLineage == true then
            runtime.lineageSource = "GameTime-backup"
        elseif freshBootstrapHeuristic then
            runtime.lineageSource = "fresh-first-boot-world-age"
        elseif stateExisted then
            runtime.lineageSource = "saved-world-state"
        else
            runtime.lineageSource = "created-world-state"
        end
    else
        runtime.lineageSource = stateExisted and "saved-existing-world" or "existing-world-first-install"
    end

    Random.setWorldSeed(seedOrError)
    runtime.worldState = value
    runtime.ready = true
    runtime.stats.completionRecordsLoaded = countCompletionRecords(value.CompletedSquares)
    rebuildCompletedChunkLevelIndex(value)
    print("[A10YL] loaded advisory completion records=" .. tostring(runtime.stats.completionRecordsLoaded)
        .. "; advisory chunk-level records=" .. tostring(runtime.stats.completedChunkLevelsLoaded))
    print("[A10YL] LINEAGE INPUT: OnInitGlobalModData=" .. tostring(newGame)
        .. "; OnLoadRadioScripts=" .. tostring(runtime.pendingNewGameSignal)
        .. "(" .. tostring(runtime.pendingNewGameSignalSource) .. ")"
        .. "; stateExisted=" .. tostring(stateExisted)
        .. "; backup=" .. tostring(backup ~= nil)
        .. "; worldAgeHours=" .. tostring(worldAgeHours)
        .. "; freshBootstrapHeuristic=" .. tostring(freshBootstrapHeuristic)
        .. "<=" .. tostring(Persistence.FRESH_BOOT_MAX_WORLD_AGE_HOURS))
    print("[A10YL] LINEAGE SOURCE: " .. tostring(runtime.lineageSource))
    print("[A10YL] AGEING SEED: " .. tostring(seedOrError)
        .. "; source=" .. tostring(pzSeedSource or (backup and "saved-A10YL-backup" or "A10YL-fallback"))
        .. "; pzSeedString=" .. tostring(pzSeedString))
    Debug.log("loaded advisory completion records: " .. tostring(runtime.stats.completionRecordsLoaded))
    touchWorldState("init", true)
    Debug.log(Text.format(
        "IGUI_A10YL_Diagnostic_WorldStateLoaded",
        "Loaded the A10YL world state (schema {schema}, generator {generator}).",
        { schema = Persistence.SCHEMA_VERSION, generator = Persistence.GENERATOR_VERSION }
    ))

    -- Consume the pre-init signal so a later save in the same Lua VM cannot
    -- inherit a stale "new game" result.
    runtime.pendingNewGameSignal = nil
    runtime.pendingNewGameSignalSource = nil
    return true
end

function Persistence.canAgeWorld()
    return runtime.ready == true and runtime.failed ~= true
end

function Persistence.getFailureReason()
    return runtime.failureReason
end

function Persistence.getWorldSeed()
    if not runtime.ready or not runtime.worldState then return nil end
    return integer(runtime.worldState.WorldSeed)
end

function Persistence.isProcessed(square)
    if not square then return false end
    local modData = square:getModData()
    -- Generator 26 correctness rule: only state stored on the square itself may
    -- seal that square. Global completion records are advisory acceleration data
    -- and are never allowed to hide missing physical mutations.
    return modData ~= nil and integer(modData.A10YL_PV) == Persistence.GENERATOR_VERSION
end

-- Returns one of: processed, fresh, resume, seal.
function Persistence.inspectSquare(square, configHash)
    if not square or not runtime.ready then return "disabled", nil end
    local modData = square:getModData()
    if not modData then return "disabled", nil end
    local processedVersion = integer(modData.A10YL_PV)
    if processedVersion == Persistence.GENERATOR_VERSION then
        return "processed", { processedVersion = processedVersion }
    elseif processedVersion ~= nil then
        modData.A10YL_PV = nil
    end
    if hasCompletionRecord(square) then
        -- Advisory index disagrees with the square: reprocess safely rather than
        -- trusting an index whose physical mutations may not have survived.
        runtime.stats.completionRecordHits = runtime.stats.completionRecordHits + 1
    end

    local hasPartial = modData.A10YL_PG ~= nil
        or modData.A10YL_PS ~= nil or modData.A10YL_PH ~= nil
    if not hasPartial then
        return "fresh", { savedStage = 0 }
    end

    local generator = integer(modData.A10YL_PG)
    local stage = integer(modData.A10YL_PS)
    local savedHash = modData.A10YL_PH ~= nil and tostring(modData.A10YL_PH) or nil
    local info = {
        processingGenerator = generator,
        savedStage = stage,
        savedHash = savedHash,
    }

    if generator == nil or stage == nil or stage < 0
        or stage > Persistence.FINAL_STAGE or savedHash == nil
    then
        info.reason = "invalid-partial"
        info.sealVersion = generator or Persistence.GENERATOR_VERSION
        return "seal", info
    end
    if generator ~= Persistence.GENERATOR_VERSION then
        if Persistence.PERSISTENCE_REPAIR_FROM_GENERATORS[generator] == true then
            -- v0.8.7 persistence repair: an interrupted v24 square is safe to
            -- restart. Existing A10YL-owned operations are detected by stable
            -- operation ids, while native opening/removal mutations are
            -- revalidated before application.
            modData.A10YL_PG = nil
            modData.A10YL_PS = nil
            modData.A10YL_PH = nil
            transmitSquareModData(square, "persistence-repair-partial")
            return "fresh", { savedStage = 0, repairedFromGenerator = generator }
        end
        info.reason = "generator-mismatch"
        info.sealVersion = generator
        return "seal", info
    end
    if savedHash ~= tostring(configHash or "") then
        info.reason = "config-mismatch"
        info.sealVersion = generator
        return "seal", info
    end

    return "resume", info
end

function Persistence.beginSquare(square, configHash)
    if not square or not runtime.ready then return false, false end
    local modData = square:getModData()
    if not modData then return false, false end
    local processedVersion = integer(modData.A10YL_PV)
    if processedVersion == Persistence.GENERATOR_VERSION then return false, false end
    if processedVersion ~= nil then modData.A10YL_PV = nil end

    if modData.A10YL_PG ~= nil or modData.A10YL_PS ~= nil or modData.A10YL_PH ~= nil then
        return integer(modData.A10YL_PG) == Persistence.GENERATOR_VERSION
            and integer(modData.A10YL_PS) == 0
            and tostring(modData.A10YL_PH or "") == tostring(configHash or ""), false
    end

    modData.A10YL_PG = Persistence.GENERATOR_VERSION
    modData.A10YL_PS = 0
    modData.A10YL_PH = tostring(configHash or "")
    transmitSquareModData(square, "begin-square")
    return true, true
end

function Persistence.checkpointStage(square, stage, configHash)
    if not square or not runtime.ready then return false, false end
    stage = integer(stage)
    local modData = square:getModData()
    if not modData or stage == nil or stage < 1 or stage > Persistence.FINAL_STAGE then
        return false, false
    end
    if integer(modData.A10YL_PG) ~= Persistence.GENERATOR_VERSION
        or tostring(modData.A10YL_PH or "") ~= tostring(configHash or "")
    then
        return false, false
    end

    local savedStage = integer(modData.A10YL_PS)
    if savedStage == nil then return false, false end
    if savedStage >= stage then return true, false end

    -- v0.8.0 may omit empty stage checkpoints. A later checkpoint is therefore
    -- allowed to advance across stages that had no feature operations in the plan.
    modData.A10YL_PS = stage
    transmitSquareModData(square, "checkpoint-stage")
    return true, true
end

local function clearPartial(modData)
    modData.A10YL_PG = nil
    modData.A10YL_PS = nil
    modData.A10YL_PH = nil
end

function Persistence.completeSquare(square)
    if not square or not runtime.ready then return false, false end
    local modData = square:getModData()
    if not modData then return false, false end
    if integer(modData.A10YL_PV) == Persistence.GENERATOR_VERSION then return true, false end

    local generator = integer(modData.A10YL_PG)
    if generator == nil or integer(modData.A10YL_PS) ~= Persistence.FINAL_STAGE then
        return false, false
    end

    modData.A10YL_PV = generator
    clearPartial(modData)
    recordCompletion(square, generator)
    transmitSquareModData(square, "complete-square")
    return true, true
end

function Persistence.sealPartial(square, reason, sealVersion)
    if not square or not runtime.ready then return false, false end
    local modData = square:getModData()
    if not modData then return false, false end
    if integer(modData.A10YL_PV) == Persistence.GENERATOR_VERSION then return true, false end

    sealVersion = integer(sealVersion) or Persistence.GENERATOR_VERSION
    modData.A10YL_PV = sealVersion
    clearPartial(modData)
    recordCompletion(square, sealVersion)
    transmitSquareModData(square, "seal-partial")

    local counter = "invalidPartialsSealed"
    if reason == "config-mismatch" then
        counter = "configPartialsSealed"
    elseif reason == "generator-mismatch" then
        counter = "generatorPartialsSealed"
    end
    runtime.stats[counter] = runtime.stats[counter] + 1
    local reasonText = Text.get(
        "IGUI_A10YL_Warning_PartialReasonInvalid",
        "its saved progress was invalid"
    )
    if reason == "config-mismatch" then
        reasonText = Text.get(
            "IGUI_A10YL_Warning_PartialReasonSettings",
            "the active ageing settings changed"
        )
    elseif reason == "generator-mismatch" then
        reasonText = Text.get(
            "IGUI_A10YL_Warning_PartialReasonGenerator",
            "the ageing generator changed"
        )
    end

    Debug.once("sealed-partial:" .. tostring(square:getX()) .. ":" .. tostring(square:getY())
        .. ":" .. tostring(square:getZ()), "WARN",
        Text.format(
            "IGUI_A10YL_Warning_PartialSealed",
            "Stopped unfinished ageing at square {x}:{y}:{z} under generator {generator} because {reason}; mixed results were not applied.",
            {
                x = square:getX(),
                y = square:getY(),
                z = square:getZ(),
                generator = sealVersion,
                reason = reasonText,
            }
        ))
    return true, true
end


function Persistence.getFirstRunWorldAgeHours()
    if not runtime.worldState then return nil end
    local age = tonumber(runtime.worldState.FirstRunWorldAgeHours)
    if age == nil and runtime.worldStateCreatedThisInit then
        age = currentWorldAgeHours()
        if age ~= nil then runtime.worldState.FirstRunWorldAgeHours = age end
    end
    return age
end

function Persistence.isFreshWorldLineage()
    if not runtime.ready or not runtime.worldState then return false end
    return runtime.worldState.FreshWorldLineage == true
end

-- Backwards-compatible alias for any private callers from older checkpoints.
function Persistence.isLikelyFreshWorldInstall()
    return Persistence.isFreshWorldLineage()
end

function Persistence.isCompletedChunkLevel(wx, wy, z)
    -- Generator 26 deliberately does not use the global chunk summary as a
    -- correctness gate. Queue discovery must reach live squares so A10YL_PV can
    -- be checked on the square that PZ will actually save.
    return false
end


function Persistence.getWorldState()
    if not runtime.ready or not runtime.worldState then return nil end
    return runtime.worldState
end

function Persistence.touch(reason, force)
    return touchWorldState(reason, force == true)
end

function Persistence.getStats()
    return {
        ready = runtime.ready,
        failed = runtime.failed,
        configPartialsSealed = runtime.stats.configPartialsSealed,
        generatorPartialsSealed = runtime.stats.generatorPartialsSealed,
        invalidPartialsSealed = runtime.stats.invalidPartialsSealed,
        completionRecordsLoaded = runtime.stats.completionRecordsLoaded,
        completionRecordsWritten = runtime.stats.completionRecordsWritten,
        completionRecordHits = runtime.stats.completionRecordHits,
        completionFlushes = runtime.stats.completionFlushes,
        completedChunkLevelHits = runtime.stats.completedChunkLevelHits,
        completedChunkLevelsLoaded = runtime.stats.completedChunkLevelsLoaded,
        completedChunkLevelsWritten = runtime.stats.completedChunkLevelsWritten,
    }
end

function Persistence.onSave()
    return touchWorldState("save", true)
end

return Persistence
