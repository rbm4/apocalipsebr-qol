local MOD = "ButcherFix"

local DEBUG = getCore():getDebug()

local function log(msg)
    if DEBUG then
        DebugLog.log(DebugType.General, "[" .. MOD .. "][S] " .. tostring(msg))
    end
end

local version = require("EuryBugs/_Version")
if not (version and version.isAtMax("42.13.1")) then
    log("skipped patch")
    return
end

local KEY_REQ = MOD .. "_reqId"

local function findItemByIdInContainer(container, targetId)
    if not container then return nil end
    local items = container:getItems()
    if not items then return nil end

    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it.getID and it:getID() == targetId then
            return it
        end

        if it and it.isInventoryContainer and it:isInventoryContainer() then
            local inner = it.getInventory and it:getInventory() or nil
            local found = findItemByIdInContainer(inner, targetId)
            if found then return found end
        end
    end

    return nil
end

local function distSq(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx*dx + dy*dy
end

local function isNearSquare(playerObj, sq, maxDist)
    if not (playerObj and sq) then return false end
    local psq = playerObj:getSquare()
    if not psq then return false end
    if psq:getZ() ~= sq:getZ() then return false end
    return distSq(psq:getX(), psq:getY(), sq:getX(), sq:getY()) <= (maxDist * maxDist)
end

local function findContainerOnObject(obj, contType)
    if not obj then return nil end

    -- Prefer exact container by type when available
    if contType and obj.getContainerByType then
        local c = obj:getContainerByType(contType)
        if c then return c end
    end

    -- Common fallbacks across IsoObject types
    if obj.getContainer then
        local c = obj:getContainer()
        if c then return c end
    end

    if obj.getItemContainer then
        local c = obj:getItemContainer()
        if c then return c end
    end

    return nil
end

local function findItemByIdOnSquareObjects(sq, itemId, contType)
    if not (sq and sq.getObjects) then return nil end
    local objects = sq:getObjects()
    if not objects then return nil end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local c = findContainerOnObject(obj, contType)
        local it = findItemByIdInContainer(c, itemId)
        if it then return it end
    end
    return nil
end

local function resolveCorpseItem(playerObj, itemId, containerArgs)
    -- 1) Vehicle container
    if containerArgs and containerArgs.kind == "vehicle" then
        local vehicleId = containerArgs.vehicleId
        local partId = containerArgs.partId

        if vehicleId and partId then
            local vehicle = getVehicleById(vehicleId)
            if vehicle and vehicle.getPartById then
                local vsq = vehicle.getSquare and vehicle:getSquare() or nil
                -- simple anti-abuse: player must be near the vehicle
                if vsq and isNearSquare(playerObj, vsq, 6) then
                    local part = vehicle:getPartById(partId)
                    local cont = part and part.getItemContainer and part:getItemContainer() or nil
                    local it = findItemByIdInContainer(cont, itemId)
                    if it then return it end
                end
            end
        end
        -- fall through to other resolutions
    end

    -- 2) World container
    if containerArgs and containerArgs.kind == "world" then
        local x, y, z = containerArgs.x, containerArgs.y, containerArgs.z
        if x and y and z then
            local sq = getCell():getGridSquare(x, y, z)
            if sq and isNearSquare(playerObj, sq, 6) then
 -- keep it “same interaction range” sane
                local objIndex = containerArgs.objIndex
                local contType = containerArgs.contType

                if objIndex ~= nil and sq.getObjects then
                    local objects = sq:getObjects()
                    if objects and objIndex >= 0 and objIndex < objects:size() then
                        local obj = objects:get(objIndex)
                        local c = findContainerOnObject(obj, contType)
                        local it = findItemByIdInContainer(c, itemId)
                        if it then return it end
                    end
                end

                -- fallback: scan all objects on the square for the itemId
                local it2 = findItemByIdOnSquareObjects(sq, itemId, contType)
                if it2 then return it2 end
            end
        end
        -- fall through
    end

    -- 3) Player inventory tree fallback (bags etc)
    return findItemByIdInContainer(playerObj:getInventory(), itemId)
end

-- Vanilla tryAddCorpseToWorld schedules removal through IsoCell, but in practice
-- we also remove from the container authoritatively to avoid dupes if a mod interrupts.
local function removeItemServerSide(item)
    if not item then return end
    local container = item.getContainer and item:getContainer() or nil
    if not container then return end

    if sendRemoveItemFromContainer then
        sendRemoveItemFromContainer(container, item)
    end

    -- container:Remove is safe even if already removed
    container:Remove(item)
end

local function spawnCorpseViaTryAdd(square, corpseItem)
    if not (square and corpseItem) then return nil end

    -- The method signature is (InventoryItem, float xOff, float yOff, boolean isVisible)
    if square.tryAddCorpseToWorld then
        -- Drop at square origin offsets; vanilla callers tend to pass 0/0.
        local corpse = square:tryAddCorpseToWorld(corpseItem, 0.0, 0.0, true)
        return corpse
    end

    return nil
end

local function spawnCorpseFallback(square, corpseItem)
    if not (square and corpseItem) then return nil end
    if not square.createAnimalCorpseFromItem then return nil end

    local corpse = square:createAnimalCorpseFromItem(corpseItem)
    if not corpse then return nil end

    if square.addCorpse then
        square:addCorpse(corpse, false)
    end

    -- Best-effort spawn replication fallback
    if GameServer and GameServer.sendCorpse then
        GameServer.sendCorpse(corpse)
    elseif corpse.transmitCompleteItemToClients then
        corpse:transmitCompleteItemToClients()
    end

    return corpse
end

local function handleRequest(playerObj, args)
    if not (playerObj and args) then return end

    local reqId = args.reqId
    local itemId = args.itemId
    local actionType = args.actionType or "butcher"

    if not (reqId and itemId) then
        log("Bad request missing reqId/itemId")
        return
    end

    local corpseItem = resolveCorpseItem(playerObj, itemId, args.container)
    if not corpseItem then
        log("Could not find corpse item id=" .. tostring(itemId))
        return
    end

    local sq = playerObj:getCurrentSquare()
    if not sq then
        log("No player square")
        return
    end

    -- 1) Spawn corpse using canonical engine path
    local corpse = spawnCorpseViaTryAdd(sq, corpseItem)
    if not corpse then
        -- If tryAddCorpseToWorld isn't bridged to Lua, fallback
        corpse = spawnCorpseFallback(sq, corpseItem)
    end
    if not corpse then
        log("Failed to spawn corpse (tryAddCorpseToWorld + fallback)")
        return
    end

    -- 2) Stamp reqId so the client can resolve the exact corpse
    if corpse.getModData then
        local md = corpse:getModData()
        md[KEY_REQ] = reqId
    end

    -- Ensure the reqId stamp is replicated
    if corpse.transmitModData then
        corpse:transmitModData()
    end

    -- 3) Remove corpse item server-side (authoritative)
    removeItemServerSide(corpseItem)

    -- 4) Respond with corpse square coords (use corpse square in case it differs)
    local csq = corpse.getSquare and corpse:getSquare() or sq
    local x = csq and csq:getX() or sq:getX()
    local y = csq and csq:getY() or sq:getY()
    local z = csq and csq:getZ() or sq:getZ()

    if sendServerCommand then
        sendServerCommand(playerObj, MOD, "ButcherFromInv_Spawned", {
            reqId = reqId,
            actionType = actionType,
            x = x, y = y, z = z,
        })
    end
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= MOD then return end
    if command ~= "ButcherFromInv_Request" then return end
    handleRequest(playerObj, args)
end

Events.OnClientCommand.Add(onClientCommand)

log("Server handler loaded (uses IsoGridSquare.tryAddCorpseToWorld when available)")
