-- Server-confirmed kills only. No file export or character-stat snapshots.
if not isServer() then return end
require "ZKC_Config"
require "ApocBR/BackendMessages"

ZKC_ServerHandler = ZKC_ServerHandler or {}
local Service = ZKC_ServerHandler
local entries, unresolved = {}, {}
local entryCount, unresolvedCount = 0, 0
local nextCheck = 0
local lastWarning = -30000

local function warn(reason)
    local now = getTimestampMs()
    if now - lastWarning >= 30000 then
        print("[ZKC_Server] " .. reason)
        lastWarning = now
    end
end

local function connected(player)
    if not player or player:isDead() then return false end
    local id = player:getOnlineID()
    return id and id >= 0 and getPlayerByOnlineID(id) == player
end

local function contextFor(player)
    local ok, context = pcall(BackendMessages.context, player)
    if ok and context.status == "OK" then return context end
    return nil
end

local function add(context, count)
    local key = context.session .. ":" .. context.characterId
    local entry = entries[key]
    if not entry then
        if entryCount + unresolvedCount >= ZKC_Config.maxEntries then
            warn("capacity reached; new-life kills dropped")
            return
        end
        entry = { key = key, context = context, pending = 0,
            due = getTimestampMs() + ZKC_Config.flushIntervalMs }
        entries[key] = entry
        entryCount = entryCount + 1
    end
    if entry.pending > 2147483647 - count then
        warn("pending kill count limit reached; excess kills dropped")
        return
    end
    entry.pending = entry.pending + count
end

local function flush(entry)
    if entry.inFlight or entry.blocked then return end
    if not entry.batch then
        if entry.pending == 0 then return end
        entry.batch = { count = entry.pending }
        entry.pending = 0
    end
    local batch = entry.batch
    entry.inFlight = true
    local function completed(result)
        entry.inFlight = false
        entry.due = getTimestampMs() + ZKC_Config.retryIntervalMs
        if result.status == "OK" then
            entry.batch = nil
            entry.lastStatus = nil
            if entry.pending == 0 then
                entries[entry.key] = nil
                entryCount = entryCount - 1
            end
        else
            if result.status == "CONFLICT" or result.status == "SCHEMA_ERROR" or result.status == "INVALID_DATA" then
                entry.blocked = true
            end
            if entry.lastStatus ~= result.status then
                print("[ZKC_Server] publication " .. tostring(result.status) .. "; batch retained in memory")
                entry.lastStatus = result.status
            end
        end
    end
    local ok, failure = pcall(function()
        if batch.publication then
            batch.publication:retry(completed)
        else
            batch.publication = BackendMessages.publish("ZombieKillsRecorded.v1", entry.context,
                { count = batch.count }, completed)
        end
    end)
    if not ok then
        entry.inFlight = false
        entry.due = getTimestampMs() + ZKC_Config.retryIntervalMs
        warn("bridge unavailable; batch retained in memory: " .. tostring(failure))
    end
end

local function dropUnresolved(player)
    if unresolved[player] then
        unresolved[player] = nil
        unresolvedCount = unresolvedCount - 1
        warn("unbound player disconnected/died; unresolved kills dropped")
    end
end

local function resolvePending()
    for player, pending in pairs(unresolved) do
        if not connected(player) then
            dropUnresolved(player)
        else
            local context = contextFor(player)
            if context then
                unresolved[player] = nil
                unresolvedCount = unresolvedCount - 1
                add(context, pending)
            end
        end
    end
end

function Service.flushPending()
    resolvePending()
    for _, entry in pairs(entries) do flush(entry) end
end

local function onZombieDead(zombie)
    if not ZKC_Config.enabled or not zombie then return end
    local player = zombie:getAttackedBy()
    if not player or not instanceof(player, "IsoPlayer") or not connected(player) then return end
    local context = contextFor(player)
    if context then
        local count = (unresolved[player] or 0) + 1
        if unresolved[player] then unresolved[player] = nil; unresolvedCount = unresolvedCount - 1 end
        add(context, count)
    else
        if not unresolved[player] then
            if entryCount + unresolvedCount >= ZKC_Config.maxEntries then
                warn("capacity reached; unbound kills dropped")
                return
            end
            unresolved[player] = 0
            unresolvedCount = unresolvedCount + 1
        end
        if unresolved[player] < 2147483647 then unresolved[player] = unresolved[player] + 1 end
    end
end

-- Wall-clock cadence, including PauseEmpty; never use accelerated game-minute events.
Events.OnTickEvenPaused.Add(function()
    local now = getTimestampMs()
    if now < nextCheck then return end
    nextCheck = now + 1000
    resolvePending()
    for _, entry in pairs(entries) do
        if now >= entry.due then flush(entry) end
    end
end)
Events.OnZombieDead.Add(onZombieDead)
Events.OnPlayerDeath.Add(dropUnresolved)
Events.OnSave.Add(Service.flushPending)
return Service
