require("EuryBugs/AnimalWS")

AnimalWildSync.Client = AnimalWildSync.Client or {}
local ST = AnimalWildSync.Client

-- Client state
ST.interestedIDs   = ST.interestedIDs   or {}  -- [id]=true
ST.pendingRequest  = ST.pendingRequest  or {}  -- [id]=true
ST.knownWild       = ST.knownWild       or {}  -- [id]=bool
ST.pendingWild     = ST.pendingWild     or {}  -- [id]=bool
ST.lastSeenMs      = ST.lastSeenMs      or {}  -- [id]=now

ST.lastFlushMs     = ST.lastFlushMs     or 0
ST.lastKeepAliveMs = ST.lastKeepAliveMs or 0

-- Square queue (deferred processing)
ST.squareQueued    = ST.squareQueued    or {}  -- [key]=true
ST.squareQueue     = ST.squareQueue     or {}  -- array of {x,y,z,retries}
ST.squareQueueHead = ST.squareQueueHead or 1
ST.lastDiscoveryMs = ST.lastDiscoveryMs or 0
ST.lastPruneMs     = ST.lastPruneMs     or 0

-- Tunables (client-side only)
local DISCOVERY_MS = 200           -- how often we process loaded animals
local PRUNE_MS = 5000
local STALE_MS = 30000

local function isIsoAnimal(obj)
    -- works in your environment (avoid instanceof / class name)
    return obj and obj.isAnimal and obj:isAnimal()
end

local function registerAnimalId(id)
    if not id then return end
    ST.interestedIDs[id] = true
    if ST.knownWild[id] == nil then
        ST.pendingRequest[id] = true
    end
end

-- Best-effort ID lookup (apply immediately on server state packet)
local function tryGetAnimalById(id)
    if not id then return nil end

    -- Some mod stacks expose this globally; use if present.
    if getAnimal then
        local a = getAnimal(id)
        if a then return a end
    end

    -- Some builds expose lookups on the cell; probe safely.
    local cell = getCell and getCell()
    if cell then
        if cell.getAnimal then
            local a = cell:getAnimal(id)
            if a then return a end
        end
        if cell.getIsoAnimalByOnlineID then
            local a = cell:getIsoAnimalByOnlineID(id)
            if a then return a end
        end
    end

    return nil
end

local function tryApplyWildImmediate(id, w)
    local a = tryGetAnimalById(id)
    if a and isIsoAnimal(a) and a.setWild then
        a:setWild(w)
        AnimalWildSync.dlog("C", "Applied setWild immediately id " .. tostring(id) .. " wild " .. tostring(w))
        return true
    end
    return false
end

local function registerOrProcess(player)
    local cell = getCell()
    if not cell then return end

    local objects = cell:getObjectList()
    local count = objects and objects:size() or 0
    if count <= 0 then return end

    local nowMs = getTimestampMs()

    for i = 0, count - 1 do
        local object = objects:get(i)
        if object and instanceof(object, "IsoAnimal") then
            local animal = object
            local id = animal:getOnlineID()
            if id ~= nil then
                ST.lastSeenMs[id] = nowMs

                if ST.interestedIDs[id] == nil then
                    registerAnimalId(id)
                end

                local pending = ST.pendingWild[id]
                if pending ~= nil then
                    ST.knownWild[id] = pending
                    ST.pendingWild[id] = nil
                end

                local wildState = ST.knownWild[id]
                if wildState ~= nil then
                    if animal:isWild() ~= wildState then
                        animal:setWild(wildState)
                    end
                end
            end
        end
    end
end

local function pruneStaleInterests(nowMs)
    AnimalWildSync.dlog("C", "Pruning stale interests")
    for id, seenAt in pairs(ST.lastSeenMs) do
        if nowMs - seenAt > STALE_MS then
            ST.lastSeenMs[id] = nil
            ST.interestedIDs[id] = nil
            ST.pendingRequest[id] = nil
            AnimalWildSync.dlog("C", "Pruned stale id " .. tostring(id))
        end
    end
end

local function flushRequestBatch(player)
    local ids = AnimalWildSync.setToList(ST.pendingRequest)
    if #ids == 0 then return end

    AnimalWildSync.dlog("C", "Flushing RequestAnimalWild count " .. tostring(#ids))

    local chunks = AnimalWildSync.chunkList(ids, AnimalWildSync.MAX_IDS_PER_MSG)
    for _, chunk in ipairs(chunks) do
        AnimalWildSync.dlog("C", "Sent RequestAnimalWild chunk size " .. tostring(#chunk))
        sendClientCommand(player, AnimalWildSync.MODULE, AnimalWildSync.CMD_REQUEST, { ids = chunk })
    end

    for i = 1, #ids do
        ST.pendingRequest[ids[i]] = nil
    end
end

local function sendKeepAlive(player)
    local ids = AnimalWildSync.setToList(ST.interestedIDs)
    if #ids == 0 then return end

    local chunks = AnimalWildSync.chunkList(ids, AnimalWildSync.MAX_IDS_PER_MSG)
    for _, chunk in ipairs(chunks) do
        sendClientCommand(player, AnimalWildSync.MODULE, AnimalWildSync.CMD_KEEPALIVE, { ids = chunk })
    end
end

local function onClientTick()
    local player = getSpecificPlayer and getSpecificPlayer(0)
    if not player then return end
    if not isClient or not isClient() then return end

    local now = AnimalWildSync.nowMs()

    -- Deferred animal discovery + delayed apply
    if (now - ST.lastDiscoveryMs) >= DISCOVERY_MS then
        ST.lastDiscoveryMs = now
        registerOrProcess(player)
    end

    -- Prune stale insterests
    if (now - ST.lastPruneMs > PRUNE_MS) then
        ST.lastPruneMs = now
        pruneStaleInterests(now)
    end

    -- Request batching
    if (now - ST.lastFlushMs) >= AnimalWildSync.FLUSH_MS then
        ST.lastFlushMs = now
        if AnimalWildSync.hasAny(ST.pendingRequest) then
            flushRequestBatch(player)
        end
    end

    -- Keepalive lease
    if (now - ST.lastKeepAliveMs) >= (AnimalWildSync.KEEPALIVE_S * 1000) then
        ST.lastKeepAliveMs = now
        if AnimalWildSync.hasAny(ST.interestedIDs) then
            sendKeepAlive(player)
        end
    end
end

local function onServerCommand(module, command, args)
    if module ~= AnimalWildSync.MODULE then return end
    if command ~= AnimalWildSync.CMD_STATE then return end
    if not (args and args.ids and args.wild) then return end

    AnimalWildSync.dlog("C", "Recv AnimalWildState ids " .. tostring(#args.ids))

    local ids = args.ids
    local wild = args.wild

    for i = 1, #ids do
        local id = ids[i]
        local w = wild[i]
        if id ~= nil and w ~= nil then
            AnimalWildSync.dlog("C", "State id " .. tostring(id) .. " wild " .. tostring(w))
            ST.knownWild[id] = w

            -- Try immediate apply by ID lookup. If that fails, queue for later.
            if not tryApplyWildImmediate(id, w) then
                ST.pendingWild[id] = w
            end
        end
    end
end

-- Hook registration
local function safeAddEvent(name, evTable, fn)
    if evTable and evTable.Add then
        evTable.Add(fn)
        AnimalWildSync.dlog("C", "Hooked event " .. tostring(name))
        return true
    end
    AnimalWildSync.dlog("C", "Missing event " .. tostring(name))
    return false
end

local function init()
    safeAddEvent("OnTick", Events and Events.OnTick, onClientTick)
    safeAddEvent("OnServerCommand", Events and Events.OnServerCommand, onServerCommand)

    AnimalWildSync.dlog("C", "Initialised (queued-square discovery + immediate apply)")
end

init()
