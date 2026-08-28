local BicycleKickstand = require("Bicycle/Kickstand")
local BicycleUtils = require("Bicycle/Utils")
local ThrowRotations = require("Bicycle/ThrowRotations")

---@class BicycleDropBehavior
local BicycleDropBehavior = {}

---@param value any
---@return boolean
---@nodiscard
local function isTrueBool(value)
    return value == true or value == "true"
end

---@param direction IsoDirections|nil
---@param zRotation number|nil
---@return number
---@return number
---@return number
---@nodiscard
local function getThrowRotation(direction, zRotation)
    local x, y, z = ThrowRotations.getThrowRotation(direction, zRotation)
    return x, y, z
end

---@param worldObj IsoWorldInventoryObject|nil
---@param direction IsoDirections|nil
---@param zRotation number|nil
---@return boolean
local function layDownBicycle(worldObj, direction, zRotation)
    if not worldObj or not worldObj.getItem then
        return false
    end

    local item = worldObj:getItem()
    if not item then
        return false
    end

    local xRot, yRot, zRot = getThrowRotation(direction, zRotation)
    item:setWorldXRotation(xRot)
    item:setWorldYRotation(yRot)
    item:setWorldZRotation(zRot)

    worldObj:setOffX(0.39)
    worldObj:setOffY(1)
    worldObj:setOffZ(0.04)

    return true
end

---@param worldObj IsoWorldInventoryObject|nil
local function syncExtendedPlacement(worldObj)
    if not (worldObj and worldObj.syncExtendedPlacement) then
        return
    end

    if isClient() then
        return
    elseif isServer() then
        worldObj:syncExtendedPlacement()
    else
        worldObj:syncExtendedPlacement()
    end
end

---@param bikeItem InventoryItem|nil
---@param dismountData table|nil
---@return boolean
---@nodiscard
local function shouldUseKickstandDrop(bikeItem, dismountData)
    if dismountData and dismountData.kickstandDown ~= nil then
        return isTrueBool(dismountData.kickstandDown)
    end

    return BicycleKickstand.getCurrentState(bikeItem) == "down"
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@param dismountData table|nil
---@return boolean
local function tryApplyDroppedBikeTransform(player, bikeItem, dismountData)
    if not bikeItem then
        return false
    end

    local worldObj = bikeItem.getWorldItem and bikeItem:getWorldItem() or nil
    if not worldObj then
        return false
    end
    if dismountData and isTrueBool(dismountData.skipRotation) then
        return true
    end

    local shiftHeld = dismountData and isTrueBool(dismountData.shiftHeld)
    local wantsKickstandDown = shouldUseKickstandDrop(bikeItem, dismountData)
    local direction = dismountData and dismountData.direction or nil
    local zRotation = dismountData and dismountData.zRotation or nil

    if not zRotation and player and player.getDir then
        zRotation = BicycleUtils.directionToZRotation(player:getDir())
    end
    if not direction and player and player.getDir then
        direction = player:getDir()
    end

    if zRotation then
        zRotation = BicycleUtils.normalizeZRotation(zRotation + 90)
    end

    -- Last word on landing upright: knock-offs and wall collisions build their own dismountData, and in MP it can
    -- arrive from a client. A sidecar bike stays upright regardless of what it says.
    local usingKickstand = BicycleUtils.hasSidecar(bikeItem) or (wantsKickstandDown and not shiftHeld)
    if usingKickstand then
        local item = worldObj:getItem()
        if item then
            item:setWorldXRotation(0)
            item:setWorldYRotation(0)
            item:setWorldZRotation(zRotation or 360)
            worldObj:setOffX(0)
            worldObj:setOffY(0)
            worldObj:setOffZ(0)
            syncExtendedPlacement(worldObj)
            return true
        end
    end

    layDownBicycle(worldObj, direction, zRotation)
    syncExtendedPlacement(worldObj)
    return true
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@param dismountData table|nil
function BicycleDropBehavior.applyDroppedBikeTransform(player, bikeItem, dismountData)
    if tryApplyDroppedBikeTransform(player, bikeItem, dismountData) then
        return
    end

    BicycleUtils.runAfter(0.1, function()
        tryApplyDroppedBikeTransform(player, bikeItem, dismountData)
    end)
end

---@type table<string, string>
local FLAT_WHEEL_MD_KEYS = {
    FrontWheel = "bicycleFlatFrontWheel",
    RearWheel = "bicycleFlatRearWheel",
}

---Unwrap IsoWorldInventoryObject to get the underlying InventoryItem.
---applyDropState receives the return of AddWorldInventoryItem which is
---a world object, not an InventoryItem. ModData and weapon-part methods
---live on the InventoryItem, so we must extract it first.
---@param obj any
---@return InventoryItem|nil
local function unwrapItem(obj)
    if not obj then
        return nil
    end
    if obj.getItem then
        local inner = obj:getItem()
        if inner then
            return inner
        end
    end
    return obj
end

---Re-apply a flat wheel swap on a single slot if the current part
---doesn't match the expected flat type.
---@param item InventoryItem
---@param player IsoPlayer|IsoGameCharacter|nil
---@param partType string
---@param flatFullType string
---@param savedState table|nil  condition/usedDelta/wearElapsed from dismountData
local function reapplyFlatWheel(item, player, partType, flatFullType, savedState)
    local currentPart = item:getWeaponPart(partType)
    if not currentPart then
        return
    end
    if currentPart:getFullType() == flatFullType then
        return
    end

    local flatPart = instanceItem(flatFullType)
    if not flatPart then
        return
    end

    if savedState then
        if savedState.condition and flatPart.setCondition then
            flatPart:setCondition(savedState.condition)
        end
        if savedState.usedDelta and flatPart.setUsedDelta then
            flatPart:setUsedDelta(savedState.usedDelta)
        end
        if savedState.wearElapsed then
            flatPart:getModData().bicycleWearElapsed = savedState.wearElapsed
        end
    else
        if currentPart.getCondition and flatPart.setCondition then
            flatPart:setCondition(currentPart:getCondition())
        end
        if currentPart.getUsedDelta and flatPart.setUsedDelta then
            flatPart:setUsedDelta(currentPart:getUsedDelta())
        end
        local srcData = currentPart.getModData and currentPart:getModData() or nil
        if srcData then
            flatPart:getModData().bicycleWearElapsed = srcData.bicycleWearElapsed
        end
    end

    item:detachWeaponPart(player, currentPart)
    BicycleUtils.removeItemFromContainer(currentPart)
    item:attachWeaponPart(flatPart, true)
end

---Verify that flat wheel state survived the equip→world transition.
---Uses dismountData.flatWheels (captured before drop) as primary source,
---falls back to bicycle modData backup keys.
---@param bikeItem InventoryItem|IsoWorldInventoryObject|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param dismountData table|nil
local function ensureFlatWheelState(bikeItem, player, dismountData)
    local item = unwrapItem(bikeItem)
    if not item then
        return
    end

    local flatWheels = dismountData and dismountData.flatWheels or nil
    if flatWheels then
        for partType, saved in pairs(flatWheels) do
            local flatFullType = type(saved) == "table" and saved.fullType or saved
            if type(flatFullType) == "string" and flatFullType ~= "" then
                reapplyFlatWheel(item, player, partType, flatFullType, type(saved) == "table" and saved or nil)
            end
        end
    end

    if item.getModData then
        local bikeModData = item:getModData()
        for partType, mdKey in pairs(FLAT_WHEEL_MD_KEYS) do
            local expectedFlatType = bikeModData[mdKey]
            if type(expectedFlatType) == "string" and expectedFlatType ~= "" then
                if not (flatWheels and flatWheels[partType]) then
                    reapplyFlatWheel(item, player, partType, expectedFlatType, nil)
                end
                bikeModData[mdKey] = nil
            end
        end
        if item.transmitModData then
            item:transmitModData()
        end
    end
end

---@param bikeItem InventoryItem|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param dismountData table|nil
function BicycleDropBehavior.applyDropState(bikeItem, player, dismountData)
    if not bikeItem then
        return
    end

    ensureFlatWheelState(bikeItem, player, dismountData)

    -- The transform stands a sidecar bike up unconditionally, so the stand comes down with it.
    if BicycleUtils.hasSidecar(bikeItem) then
        BicycleKickstand.ensureState(bikeItem, player, "down")
    elseif dismountData and dismountData.kickstandDown ~= nil then
        local targetState = isTrueBool(dismountData.kickstandDown) and "down" or "up"
        BicycleKickstand.ensureState(bikeItem, player, targetState)
    end

    BicycleDropBehavior.applyDroppedBikeTransform(player, bikeItem, dismountData)
end

return BicycleDropBehavior
