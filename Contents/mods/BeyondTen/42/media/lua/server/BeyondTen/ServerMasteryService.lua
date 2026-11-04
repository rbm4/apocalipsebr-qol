if not isServer() then return end
require "BeyondTen/Shared"
require "BeyondTen/Persistence/MasteryEntity"

BeyondTenServerMasteryService = BeyondTenServerMasteryService or {}
local Service = BeyondTenServerMasteryService
local entries = {}
local byState = {}
local hooks
local nextTick = 0
local FLUSH_MS = 5000

local function current(entry)
    return entries[entry.player] == entry and not entry.player:isDead()
end

local function report(entry, status)
    if entry.lastStatus ~= status then
        print("[BeyondTen/Persistence] mastery " .. status .. "; local GlobalModData retained")
        entry.lastStatus = status
    end
end

local function fail(entry, status)
    entry.inFlight = false
    if status == "STALE_SESSION" then
        entry.ready = false
        entry.state.persistenceReady = false
    end
    -- A conflict/uncertain commit needs reconciliation, never an automatic overwrite.
    if status == "CONFLICT" or status == "OUTCOME_UNKNOWN" or status == "STALE_SESSION"
        or status == "SCHEMA_ERROR" or status == "INVALID_DATA" then
        entry.blocked = true
    end
    entry.retryAt = getTimestampMs() + FLUSH_MS
    report(entry, status)
end

local function rowsFor(entry, seed)
    local rows = {}
    local values = {}
    for id, xp in pairs(entry.state.canonicalXP) do values[id] = xp end
    if seed then
        -- These real zero rows also record successful initialization of an empty character.
        local count = 0
        for _ in pairs(values) do count = count + 1 end
        for _, perk in ipairs(BeyondTen.GetTrainablePerks()) do
            local id = perk:getId()
            if values[id] == nil and count < 256 then values[id] = 0; count = count + 1 end
        end
        if entry.state.storeRecord and entry.state.storeRecord.characterId
            and entry.state.storeRecord.characterId ~= entry.context.characterId then
            for id in pairs(values) do values[id] = 0 end
        end
    else
        -- Clearing mastery writes zeroes; it must not delete the initialization evidence.
        for id in pairs(entry.revisions) do if values[id] == nil then values[id] = 0 end end
    end
    for id, xp in pairs(values) do
        rows[#rows + 1] = { values = { perk_id = id, xp = xp },
            revision = seed and "0" or (entry.revisions[id] or "0") }
    end
    return rows
end

local function revisions(entry, rows, replace)
    if replace then entry.revisions = {} end
    for _, row in ipairs(rows) do entry.revisions[row.values.perk_id] = row.revision end
end

local function initialize(entry)
    if not current(entry) or entry.inFlight or entry.blocked then return end
    local repository = BeyondTenPersistence.Mastery
    if not repository then fail(entry, "UNAVAILABLE"); return end
    entry.inFlight = true
    local ok = pcall(ApocBREntities.resolveCharacter, entry.player, function(context)
        if not current(entry) then return end
        if context.status ~= "OK" then fail(entry, context.status); return end
        entry.context = context
        local submitted, failure = pcall(function()
            repository:loadOrCreateForCharacter(entry.player, context, rowsFor(entry, true), function(result)
                if not current(entry) then return end
                if result.status ~= "OK" then fail(entry, result.status); return end
                entry.inFlight = false
                revisions(entry, result.rows, true)
                entry.snapshot = repository:characterSnapshot(result.rows)
                local values = {}
                for _, row in ipairs(result.rows) do values[row.values.perk_id] = row.values.xp end
                entry.ready = true
                entry.state.persistenceReady = true
                entry.lastStatus = nil
                entry.retryAt = getTimestampMs() + FLUSH_MS
                hooks.loaded(entry.player, entry.state, hooks.sanitize(values), context)
                print("[BeyondTen/Persistence] mastery READY; source=" .. (result.imported and "server GlobalModData" or "PostgreSQL"))
            end)
        end)
        if not submitted then fail(entry, "BRIDGE_ERROR"); print("[BeyondTen/Persistence] " .. tostring(failure)) end
    end)
    if not ok then fail(entry, "UNAVAILABLE") end
end

local function flush(entry)
    if not current(entry) or not entry.ready or entry.inFlight or entry.blocked
        or entry.generation == entry.savedGeneration then return end
    entry.inFlight = true
    local generation = entry.generation
    local ok, failure = pcall(function()
        entry.snapshot:patch(entry.player, entry.context, rowsFor(entry, false), function(result)
            if not current(entry) then return end
            if result.status ~= "OK" then fail(entry, result.status); return end
            revisions(entry, result.rows)
            entry.savedGeneration = generation
            entry.inFlight = false
            entry.lastStatus = nil
            entry.retryAt = getTimestampMs() + FLUSH_MS
        end)
    end)
    if not ok then fail(entry, "BRIDGE_ERROR"); print("[BeyondTen/Persistence] " .. tostring(failure)) end
end

function Service.Configure(callbacks)
    hooks = callbacks
end

function Service.Initialize(player, state)
    if entries[player] then return end
    state.persistenceReady = false
    state.pendingMasteryXP = state.pendingMasteryXP or {}
    local count = 0
    for _ in pairs(entries) do count = count + 1 end
    if count >= 512 then
        if not state.persistenceCapacityLogged then
            print("[BeyondTen/Persistence] service capacity reached; mastery initialization deferred")
            state.persistenceCapacityLogged = true
        end
        return
    end
    local entry = { player = player, state = state, revisions = {}, generation = 0,
        savedGeneration = 0, retryAt = 0 }
    entries[player] = entry
    byState[state] = entry
    initialize(entry)
end

function Service.Defer(state, kind, perk, value)
    if #state.pendingMasteryXP >= 4096 then
        if not state.pendingQueueFull then
            print("[BeyondTen/Persistence] pending mastery queue full; initialization must recover before more deferred changes")
            state.pendingQueueFull = true
        end
        return false
    end
    state.pendingMasteryXP[#state.pendingMasteryXP + 1] = { kind = kind, perk = perk, value = value }
    return true
end

function Service.MarkDirty(state)
    local entry = byState[state]
    if entry and entry.ready then entry.generation = entry.generation + 1 end
end

function Service.RequestSync(player, state)
    if state.persistenceReady then hooks.sync(player, state) end
    -- Initialization itself publishes a full sync when ready; requests never supply XP or IDs.
end

function Service.Flush(player)
    if player then
        if entries[player] then flush(entries[player]) end
    else
        for _, entry in pairs(entries) do flush(entry) end
    end
end

function Service.Forget(player)
    if entries[player] then byState[entries[player].state] = nil end
    entries[player] = nil
end

function Service.Reset()
    entries = {}
    byState = {}
end

Events.OnTickEvenPaused.Add(function()
    if not hooks then return end
    local now = getTimestampMs()
    if now < nextTick then return end
    nextTick = now + 1000
    local online = {}
    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do online[players:get(index)] = true end
    for player, entry in pairs(entries) do
        if player:isDead() then
            Service.Forget(player)
        elseif not online[player] and not entry.inFlight
            and (not entry.ready or entry.savedGeneration == entry.generation) then
            Service.Forget(player)
        elseif now >= entry.retryAt then
            if entry.ready then flush(entry) elseif online[player] then initialize(entry) end
        end
    end
end)

return Service
