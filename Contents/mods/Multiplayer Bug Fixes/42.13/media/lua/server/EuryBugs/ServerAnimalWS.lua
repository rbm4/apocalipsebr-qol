require("EuryBugs/AnimalWS")

AnimalWildSync.Server = AnimalWildSync.Server or {}
local ST = AnimalWildSync.Server

-- Server state
ST.interest = ST.interest or {}  -- [playerOnlineID] = { [animalID] = { lastSentWild=bool|nil, lastSeenAt=sec } }
ST.watch    = ST.watch    or {}  -- [animalID] = { lastWild=bool|nil, owners={ [playerOnlineID]=true }, animal=IsoAnimal|nil }
ST.dirty    = ST.dirty    or {}  -- [animalID]=true
ST.anyDirty = ST.anyDirty or false

ST.lastVerifyAt = ST.lastVerifyAt or 0
ST.lastPruneAt  = ST.lastPruneAt  or 0

-- Helpers

local function getOwnerKey(playerObj)
    if not playerObj then return nil end
    return playerObj.getOnlineID and playerObj:getOnlineID()
end

local function distSq(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx*dx + dy*dy
end

local function isRelevant(playerObj, animal)
    if not (playerObj and animal) then return false end
    local px, py = playerObj:getX(), playerObj:getY()
    local ax, ay = animal:getX(), animal:getY()
    local r = AnimalWildSync.RELEVANT_DIST_TILES
    return distSq(px, py, ax, ay) <= (r * r)
end

local function ensureInterest(ownerKey)
    if not ownerKey then return nil end
    local t = ST.interest[ownerKey]
    if not t then
        t = {}
        ST.interest[ownerKey] = t
    end
    return t
end

local function ensureWatch(id)
    local w = ST.watch[id]
    if not w then
        w = { lastWild = nil, owners = {}, animal = nil }
        ST.watch[id] = w
    end
    return w
end

local function markDirty(id)
    if not id then return end
    ST.dirty[id] = true
    ST.anyDirty = true
end

local function markDirtyForAll(animalID)
    local w = ensureWatch(animalID)
    if not w then return end

    for ownerKey, _ in pairs(w.owners or {}) do
        local interest = ensureInterest(ownerKey)
        if interest then
            local entry = interest[animalID]
            if entry then
                entry.lastSentWild = nil
            else
                interest[animalID] = { lastSentWild = nil, lastSeenAt = getTimestampMs() / 1000 }
            end
        end
    end

    markDirty(animalID)
end

-- Cheap resolver: find the animal near one of its owners (bounded, no world scan)
local function findAnimalNearPlayer(playerObj, targetId)
    if not (playerObj and targetId) then return nil end
    local sq = playerObj:getSquare()
    if not sq then return nil end

    -- small bounded radius search around player
    local radius = 12
    local cx, cy, cz = sq:getX(), sq:getY(), sq:getZ()
    local cell = getCell()
    if not cell then return nil end

    for dx = -radius, radius do
        for dy = -radius, radius do
            local s = cell:getGridSquare(cx + dx, cy + dy, cz)
            if s then
                local mos = s:getMovingObjects()
                local size = mos and mos.size and mos:size() or 0
                if size > 0 then
                    for i = 0, size - 1 do
                        local o = mos:get(i)
                        if o and instanceof and instanceof(o, "IsoAnimal") then
                            local id = o.getOnlineID and o:getOnlineID()
                            if id == targetId then
                                return o
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function resolveWatchedAnimal(id)
    local w = ST.watch[id]
    if not w then return nil end

    -- If we already have a cached reference and it still matches the ID, use it.
    local a = w.animal
    if a and a.getOnlineID and a:getOnlineID() == id then
        return a
    end

    local found = getAnimal(id)
    if found then return found end
    return nil
end

-- Networking handlers

local function handleRequest(playerObj, ids)
    if not (playerObj and ids) then return end
    AnimalWildSync.dlog("S", "HandleRequest count " .. tostring(ids and #ids))
    
    local ownerKey = getOwnerKey(playerObj)
    if not ownerKey then return end

    local nowS = AnimalWildSync.nowS()
    local it = ensureInterest(ownerKey)

    local outIds = {}
    local outWild = {}

    for i = 1, #ids do
        local id = ids[i]
        if id ~= nil then
            local w = ensureWatch(id)
            w.owners[ownerKey] = true

            local animal = resolveWatchedAnimal(id)
            if not animal then
                AnimalWildSync.dlog("S", "Resolve FAIL id " .. tostring(id))
            else
                if isRelevant(playerObj, animal) then
                    local wild = animal.isWild and animal:isWild()
                    if wild ~= nil then
                        AnimalWildSync.dlog("S", "Resolve OK id " .. tostring(id) .. " wild " .. tostring(animal:isWild()))
                        local entry = it[id]
                        if not entry then
                            entry = { lastSentWild = nil, lastSeenAt = nowS }
                            it[id] = entry
                        else
                            entry.lastSeenAt = nowS
                        end

                        -- only send if new for this owner or changed since last sent
                        if entry.lastSentWild == nil or entry.lastSentWild ~= wild then
                            outIds[#outIds+1] = id
                            outWild[#outWild+1] = wild
                            entry.lastSentWild = wild
                            AnimalWildSync.dlog("S", "Queue reply id " .. tostring(id) .. " wild " .. tostring(wild))
                        end

                        -- initialise watch lastWild if unset
                        if w.lastWild == nil then
                            w.lastWild = wild
                        end
                    end
                else
                    AnimalWildSync.dlog("S", "Not relevant id " .. tostring(id) .. " skipping")
                end
            end
        end
    end

    if #outIds > 0 then
        sendServerCommand(playerObj, AnimalWildSync.MODULE, AnimalWildSync.CMD_STATE, { ids = outIds, wild = outWild })
        AnimalWildSync.dlog("S", "Sent AnimalWildState count " .. tostring(#outIds) .. " to " .. tostring(playerObj:getUsername()))
    end
end

local function handleKeepAlive(playerObj, ids)
    if not (playerObj and ids) then return end
    local ownerKey = getOwnerKey(playerObj)
    if not ownerKey then return end

    local it = ensureInterest(ownerKey)
    local nowS = AnimalWildSync.nowS()

    for i = 1, #ids do
        local id = ids[i]
        if id ~= nil then
            local entry = it[id]
            if entry then
                entry.lastSeenAt = nowS
            end
            -- keepalive does not subscribe new IDs; request does that.
        end
    end
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= AnimalWildSync.MODULE then return end
    if not (playerObj and args) then return end

    if command == AnimalWildSync.CMD_REQUEST then
        handleRequest(playerObj, args.ids)
        return
    end

    if command == AnimalWildSync.CMD_KEEPALIVE then
        handleKeepAlive(playerObj, args.ids)
        return
    end
end

-- Periodic phases

local function verifyWatchedAnimals()
    local nowS = AnimalWildSync.nowS()
    for id, w in pairs(ST.watch) do
        local animal = resolveWatchedAnimal(id)
        if not animal then
            -- let prune clean this up if owners expire; also clear dirty entry
        else
            local cur = animal.isWild and animal:isWild()
            if cur ~= nil then
                if w.lastWild == nil then
                    w.lastWild = cur
                elseif cur ~= w.lastWild then
                    w.lastWild = cur
                    markDirty(id)
                    AnimalWildSync.dlog("S", "Dirty wild flip id " .. tostring(id) .. " to " .. tostring(cur))
                end
            end
        end
    end
    ST.lastVerifyAt = nowS
end

local function processDirty()
    if not ST.anyDirty then return end

    -- Batch per owner
    local batches = {} -- [ownerKey] = { ids={}, wild={} }

    for id, _ in pairs(ST.dirty) do
        local w = ST.watch[id]
        local curWild = w and w.lastWild

        if curWild ~= nil and w and w.owners then
            for ownerKey, _ in pairs(w.owners) do
                local owner = getPlayerByOnlineID and getPlayerByOnlineID(ownerKey)
                local it = ST.interest[ownerKey]
                local entry = it and it[id]

                if owner and entry then
                    local animal = resolveWatchedAnimal(id)
                    if animal and isRelevant(owner, animal) then
                        if entry.lastSentWild ~= curWild then
                            local b = batches[ownerKey]
                            if not b then
                                b = { ids = {}, wild = {} }
                                batches[ownerKey] = b
                            end
                            b.ids[#b.ids+1] = id
                            b.wild[#b.wild+1] = curWild
                            entry.lastSentWild = curWild
                            AnimalWildSync.dlog("S", "Push id " .. tostring(id) .. " wild " .. tostring(curWild) .. " to owner " .. tostring(ownerKey))
                        end
                    end
                end
            end
        end

        ST.dirty[id] = nil
    end

    for ownerKey, b in pairs(batches) do
        local owner = getPlayerByOnlineID and getPlayerByOnlineID(ownerKey)
        if owner and b and #b.ids > 0 then
            sendServerCommand(owner, AnimalWildSync.MODULE, AnimalWildSync.CMD_STATE, b)
        end
    end

    ST.anyDirty = (AnimalWildSync.hasAny(ST.dirty) ~= nil)
end

local function pruneInterest()
    local nowS = AnimalWildSync.nowS()
    local cutoff = AnimalWildSync.PRUNE_AFTER_S

    for ownerKey, it in pairs(ST.interest) do
        local owner = getPlayerByOnlineID and getPlayerByOnlineID(ownerKey)

        for id, entry in pairs(it) do
            local age = nowS - (entry.lastSeenAt or 0)
            if age > cutoff or not owner then
                it[id] = nil
                local w = ST.watch[id]
                if w and w.owners then
                    w.owners[ownerKey] = nil
                end
            end
        end

        if AnimalWildSync.hasAny(it) == nil then
            ST.interest[ownerKey] = nil
        end
    end

    for id, w in pairs(ST.watch) do
        if not (w.owners and AnimalWildSync.hasAny(w.owners) ~= nil) then
            ST.watch[id] = nil
            ST.dirty[id] = nil
        end
    end

    ST.anyDirty = (AnimalWildSync.hasAny(ST.dirty) ~= nil)
    ST.lastPruneAt = nowS
end

local function onServerTick()
    if not isServer or not isServer() then return end

    local nowS = AnimalWildSync.nowS()

    if (nowS - (ST.lastVerifyAt or 0)) >= AnimalWildSync.VERIFY_TICK_S then
        verifyWatchedAnimals()
    end

    if ST.anyDirty then
        processDirty()
    end

    if (nowS - (ST.lastPruneAt or 0)) >= AnimalWildSync.PRUNE_TICK_S then
        pruneInterest()
    end
end

-- Hook registration (guarded, since event names vary across builds/mod setups)
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
    safeAddEvent("OnClientCommand", Events and Events.OnClientCommand, onClientCommand)
    safeAddEvent("OnTick", Events and Events.OnTick, onServerTick)

    AnimalWildSync.dlog("S", "Initialised")
end

init()

function AnimalWildSync.Server.forceDirtyInterest(playerObj, animalID)
    AnimalWildSync.dlog("S", "Register Interest for id " .. tostring(animalID))
    handleRequest(playerObj, { ids = { animalID } })
    markDirtyForAll(animalID)
end
