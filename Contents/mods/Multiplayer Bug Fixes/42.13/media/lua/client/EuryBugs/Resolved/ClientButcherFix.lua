local MOD = "ButcherFix"

local DEBUG = getCore():getDebug()

local function log(msg)
    if DEBUG then
        DebugLog.log(DebugType.General, "[" .. MOD .. "][C] " .. tostring(msg))
    end
end

local version = require("EuryBugs/_Version")
if not (version and version.isAtMax("42.13.1")) then
    log("skipped patch")
    return
end

require "ISUI/Animal/ISAnimalContextMenu"
require "TimedActions/ISTimedActionQueue"
require "EuryBugs/ButcherFix"

local NEXT_REQ = 0

local function nextReqId()
    NEXT_REQ = NEXT_REQ + 1
    return NEXT_REQ
end

local function equipKnifeLikeVanilla(chr, knife)
    if not knife then return end
    ISWorldObjectContextMenu.transferIfNeeded(chr, knife)
    ISWorldObjectContextMenu.equip(chr, chr:getPrimaryHandItem(), knife, true, false)
end

local function getSquareObjectIndex(sq, obj)
    if not (sq and obj and sq.getObjects) then return nil end
    local objects = sq:getObjects()
    if not objects then return nil end
    for i = 0, objects:size() - 1 do
        if objects:get(i) == obj then
            return i
        end
    end
    return nil
end

local function buildContainerArgs(corpseItem)
    if not (corpseItem and corpseItem.getContainer) then return nil end

    local cont = corpseItem:getContainer()
    if not cont then return nil end

    -- Vehicle part container (trunk/seat/glovebox)
    if cont.isVehiclePart and cont:isVehiclePart() then
        local veh = cont.getVehicle and cont:getVehicle() or nil
        local part = cont.getVehiclePart and cont:getVehiclePart() or nil
        if veh and part and veh.getId and part.getId then
            return {
                kind = "vehicle",
                vehicleId = veh:getId(),
                partId = part:getId(),
            }
        end
        return { kind = "vehicle" } -- fallback, server will fall back to player search
    end

    -- World container (crate/fridge/cabinet/etc)
    local parent = cont.getParent and cont:getParent() or nil
    if parent and parent.getSquare then
        local sq = parent:getSquare()
        if sq then
            local idx = getSquareObjectIndex(sq, parent)
            local contType = cont.getType and cont:getType() or nil
            return {
                kind = "world",
                x = sq:getX(), y = sq:getY(), z = sq:getZ(),
                objIndex = idx,     -- may be nil if not found
                contType = contType -- helps server pick the right container if multiple exist
            }
        end
    end

    -- Default: player inventory tree (bags etc)
    return { kind = "player" }
end

local function requestServerSpawn(chr, corpseItem, knife, actionType)
    if not (chr and corpseItem) then return end

    local itemId = corpseItem.getID and corpseItem:getID() or nil
    if not itemId then
        log("Corpse item has no ID; cannot request server spawn")
        return
    end

    equipKnifeLikeVanilla(chr, knife)

    local reqId = nextReqId()

    EURY_ButcherFix = EURY_ButcherFix or {}
    EURY_ButcherFix.REQS = EURY_ButcherFix.REQS or {}
    EURY_ButcherFix.REQS[reqId] = { actionType = actionType, x=nil, y=nil, z=nil }

    local containerArgs = buildContainerArgs(corpseItem)

    sendClientCommand(chr, MOD, "ButcherFromInv_Request", {
        reqId = reqId,
        itemId = itemId,
        actionType = actionType,
        container = containerArgs, -- {kind="player"} / {kind="vehicle",...} / {kind="world",...}
    })

    ISTimedActionQueue.add(TimedButcherFix:new(chr, reqId, actionType))
end

local function onServerCommand(module, command, args)
    if module ~= MOD then return end
    if command ~= "ButcherFromInv_Spawned" then return end
    if not args then return end

    local reqId = args.reqId
    if not reqId then return end

    if not (EURY_ButcherFix and EURY_ButcherFix.REQS and EURY_ButcherFix.REQS[reqId]) then
        return
    end

    EURY_ButcherFix.REQS[reqId].x = args.x
    EURY_ButcherFix.REQS[reqId].y = args.y
    EURY_ButcherFix.REQS[reqId].z = args.z
end

Events.OnServerCommand.Add(onServerCommand)

local function patch()
    if not AnimalContextMenu or AnimalContextMenu._EURY_ButcherFixPatched then return end
    AnimalContextMenu._EURY_ButcherFixPatched = true

    local oldButcher = AnimalContextMenu.onButcherAnimalFromInv
    local oldBones   = AnimalContextMenu.onGetAnimalBonesFromInv

    AnimalContextMenu.onButcherAnimalFromInv = function(body, chr, knife)
        if not isClient() then
            return oldButcher(body, chr, knife)
        end
        requestServerSpawn(chr, body, knife, "butcher")
    end

    AnimalContextMenu.onGetAnimalBonesFromInv = function(body, chr, knife)
        if not isClient() then
            return oldBones(body, chr, knife)
        end
        requestServerSpawn(chr, body, knife, "bones")
    end

    log("Patched inventory butcher handlers (server spawn via tryAddCorpseToWorld)")
end

Events.OnGameStart.Add(patch)
