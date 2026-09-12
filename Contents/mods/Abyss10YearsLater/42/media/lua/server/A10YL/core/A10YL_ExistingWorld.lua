
-- Existing-save handling for v0.7.0. The Project Zomboid Lua surface differs
-- between SP, hosted MP and dedicated MP, so this module uses safe API probes
-- and fails conservative for saves that appear established.
local Debug = require("A10YL/core/A10YL_Debug")

local ExistingWorld = {}

ExistingWorld.MODE_NEW_AREAS_ONLY = 1
ExistingWorld.MODE_AGE_EXISTING = 2
ExistingWorld.MODE_DISABLED = 3

local NEWNESS_METHODS = {
    "isNewChunk",
    "isNew",
    "isNewlyCreated",
    "wasNewChunk",
}

local EXISTING_METHODS = {
    "isLoadedFromDisk",
    "wasLoadedFromDisk",
    "isSavedChunk",
    "wasSavedChunk",
    "isFromSave",
}

local stats = {
    forcedExisting = 0,
    newChunks = 0,
    existingSkipped = 0,
    freshLineageAllowed = 0,
    unknownFreshAllowed = 0,
    unknownEstablishedSkipped = 0,
    disabledSkipped = 0,
}

local warnedUnknownEstablished = false
local loggedMode = nil

local function boolMethod(obj, name)
    if not obj then return nil end
    local fn = obj[name]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(function() return fn(obj) end)
    if not ok or type(value) ~= "boolean" then return nil end
    return value
end

local function boolField(obj, name)
    if not obj then return nil end
    local ok, value = pcall(function() return obj[name] end)
    if not ok or type(value) ~= "boolean" then return nil end
    return value
end

function ExistingWorld.classifyChunk(chunk)
    if not chunk then return "unknown" end

    for i = 1, #NEWNESS_METHODS do
        local value = boolMethod(chunk, NEWNESS_METHODS[i])
        if value == true then return "new" end
        -- B42 hosted worlds can report false after generation has already
        -- advanced past the "new chunk" moment. False is therefore unknown,
        -- not proof that the chunk predates A10YL.
    end

    for i = 1, #EXISTING_METHODS do
        local value = boolMethod(chunk, EXISTING_METHODS[i])
        if value == true then return "existing" end
        if value == false and EXISTING_METHODS[i] == "isLoadedFromDisk" then return "new" end
    end

    local fieldNew = boolField(chunk, "isNewChunk")
    if fieldNew == true then return "new" end
    -- false is deliberately not treated as proof of an existing-save chunk.

    local fieldLoaded = boolField(chunk, "loadedFromDisk") or boolField(chunk, "wasLoadedFromDisk")
    if fieldLoaded == true then return "existing" end
    if fieldLoaded == false then return "new" end

    return "unknown"
end

local function logMode(modeName)
    modeName = tostring(modeName or "unknown")
    if loggedMode == modeName then return end
    loggedMode = modeName
    Debug.log("existing save handling: " .. modeName)
end

function ExistingWorld.shouldAgeChunk(chunk, wx, wy, mode, modeName, freshWorldLineage)
    mode = tonumber(mode) or ExistingWorld.MODE_NEW_AREAS_ONLY
    logMode(modeName)

    if mode == ExistingWorld.MODE_DISABLED then
        stats.disabledSkipped = stats.disabledSkipped + 1
        return false, "disabled"
    end

    if mode == ExistingWorld.MODE_AGE_EXISTING then
        stats.forcedExisting = stats.forcedExisting + 1
        return true, "forced"
    end

    -- Checkpoint 68: on a world that was created with A10YL, PZ's transient
    -- isNewChunk()/loadedFromDisk flags are not authoritative. Hosted B42.20.4
    -- can report a just-created chunk as non-new before LoadChunk reaches Lua.
    -- Fresh-lineage eligibility is stable across restarts. Generator 26 then
    -- checks each live square's A10YL_PV marker before any mutation is planned.
    if freshWorldLineage == true then
        stats.freshLineageAllowed = stats.freshLineageAllowed + 1
        return true, "fresh-lineage"
    end

    local classification = ExistingWorld.classifyChunk(chunk)
    if classification == "new" then
        stats.newChunks = stats.newChunks + 1
        return true, "new"
    end
    if classification == "existing" then
        stats.existingSkipped = stats.existingSkipped + 1
        Debug.log("skipped existing save chunk under New Areas Only: " .. tostring(wx) .. ":" .. tostring(wy))
        return false, "existing"
    end

    -- Unknown means the current runtime did not expose a reliable new/existing
    -- flag for this chunk. Allow unknown chunks only when the save appears to be
    -- a fresh A10YL install, otherwise skip to protect existing servers.
    if freshWorldLineage == true then
        stats.unknownFreshAllowed = stats.unknownFreshAllowed + 1
        return true, "unknown-fresh"
    end

    stats.unknownEstablishedSkipped = stats.unknownEstablishedSkipped + 1
    if not warnedUnknownEstablished then
        warnedUnknownEstablished = true
        Debug.once(
            "existing-save-unknown-chunks", "WARN",
            "Existing Save Handling is set to New Areas Only, but this runtime did not expose a reliable new-chunk flag. Unknown chunks are being skipped to avoid modifying an established save. Use Age Existing Areas Too to force ageing in existing areas."
        )
    end
    return false, "unknown-established"
end

function ExistingWorld.getStats()
    return {
        forcedExisting = stats.forcedExisting,
        freshLineageAllowed = stats.freshLineageAllowed,
        newChunks = stats.newChunks,
        existingSkipped = stats.existingSkipped,
        unknownFreshAllowed = stats.unknownFreshAllowed,
        unknownEstablishedSkipped = stats.unknownEstablishedSkipped,
        disabledSkipped = stats.disabledSkipped,
    }
end

function ExistingWorld.resetRuntime()
    stats.forcedExisting = 0
    stats.freshLineageAllowed = 0
    stats.newChunks = 0
    stats.existingSkipped = 0
    stats.unknownFreshAllowed = 0
    stats.unknownEstablishedSkipped = 0
    stats.disabledSkipped = 0
    warnedUnknownEstablished = false
    loggedMode = nil
end

return ExistingWorld
