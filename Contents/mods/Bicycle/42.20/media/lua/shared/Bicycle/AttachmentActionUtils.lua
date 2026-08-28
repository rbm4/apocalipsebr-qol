local BicycleUtils = require("Bicycle/Utils")
local BicycleVanillaPartMapping = require("Bicycle/VanillaPartMapping")

local AttachmentActionUtils = {}

local VANILLA_SOURCE_TYPE_KEY = "BicycleVanillaSourceType"
local VANILLA_SOURCE_ID_KEY = "BicycleVanillaSourceID"

---@param partType string|nil
---@return boolean
---@nodiscard
local function isWheelPartType(partType)
    return partType == "FrontWheel" or partType == "RearWheel"
end

---@param sourcePart InventoryItem|nil
---@param targetPartType string|nil
---@return string|nil
---@nodiscard
local function getWheelVariantFullType(sourcePart, targetPartType)
    if not (sourcePart and sourcePart.getType and isWheelPartType(targetPartType)) then
        return nil
    end

    local sourceType = sourcePart:getType()
    if not sourceType then
        return nil
    end

    local isOffroad = string.find(sourceType, "Offroad", 1, true) ~= nil
    local isFlat = string.find(sourceType, "Flat", 1, true) ~= nil
    if targetPartType == "FrontWheel" then
        if isOffroad then
            return isFlat and "Bicycle.Bicycle_OffroadWheelFrontFlatItem" or "Bicycle.Bicycle_OffroadWheelFrontItem"
        end
        return isFlat and "Bicycle.Bicycle_StreetWheelFrontFlatItem" or "Bicycle.Bicycle_StreetWheelFrontItem"
    end

    if isOffroad then
        return isFlat and "Bicycle.Bicycle_OffroadWheelRearFlatItem" or "Bicycle.Bicycle_OffroadWheelRearItem"
    end
    return isFlat and "Bicycle.Bicycle_StreetWheelRearFlatItem" or "Bicycle.Bicycle_StreetWheelRearItem"
end

---@param sourcePart InventoryItem|nil
---@param targetPart InventoryItem|nil
local function copyWheelState(sourcePart, targetPart)
    if not (sourcePart and targetPart) then
        return
    end

    if sourcePart.getCondition and targetPart.setCondition then
        targetPart:setCondition(sourcePart:getCondition())
    end

    local sourceData = sourcePart.getModData and sourcePart:getModData() or nil
    local targetData = targetPart.getModData and targetPart:getModData() or nil
    if sourceData and targetData then
        targetData.bicycleWearElapsed = sourceData.bicycleWearElapsed
    end

    if sourcePart.getUsedDelta and targetPart.setUsedDelta then
        targetPart:setUsedDelta(sourcePart:getUsedDelta())
    end
end

---@param weapon InventoryItem|nil
---@param part InventoryItem|nil
---@return string|nil
---@nodiscard
function AttachmentActionUtils.resolveConvertibleWheelPartType(weapon, part)
    if not (weapon and part and weapon.getWeaponPart and part.getPartType) then
        return nil
    end

    local sourcePartType = part:getPartType()
    if sourcePartType == "FrontWheel" then
        if weapon:getWeaponPart("FrontWheel") and not weapon:getWeaponPart("RearWheel") then
            return "RearWheel"
        end
        return nil
    end

    if sourcePartType == "RearWheel" then
        if weapon:getWeaponPart("RearWheel") and not weapon:getWeaponPart("FrontWheel") then
            return "FrontWheel"
        end
        return nil
    end

    return nil
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@return boolean
---@nodiscard
function AttachmentActionUtils.isWorldBikeReachable(character, bikeItem)
    local worldItem = bikeItem and bikeItem.getWorldItem and bikeItem:getWorldItem() or nil
    if not worldItem then
        return false
    end

    local bikeSquare = worldItem:getSquare()
    local playerSquare = character and character:getSquare() or nil
    if not (bikeSquare and playerSquare) then
        return false
    end

    if bikeSquare:getZ() ~= playerSquare:getZ() then
        return false
    end

    local dx = bikeSquare:getX() - playerSquare:getX()
    local dy = bikeSquare:getY() - playerSquare:getY()
    return dx * dx + dy * dy <= 9
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@return boolean
---@nodiscard
function AttachmentActionUtils.isBikeInInventory(character, bikeItem)
    if not (character and bikeItem) then
        return false
    end

    return character:getInventory():contains(bikeItem)
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@return IsoGridSquare|nil
---@nodiscard
function AttachmentActionUtils.resolveBikeSquare(character, bikeItem)
    local worldItem = bikeItem and bikeItem.getWorldItem and bikeItem:getWorldItem() or nil
    local square = worldItem and worldItem:getSquare() or nil
    if square then
        return square
    end

    return character and character:getSquare() or nil
end

---@param bikeItem InventoryItem|nil
function AttachmentActionUtils.refreshWorldBike(bikeItem)
    local worldItem = bikeItem and bikeItem.getWorldItem and bikeItem:getWorldItem() or nil
    if not worldItem then
        return
    end

    local square = worldItem:getSquare()
    if not square then
        return
    end

    BicycleUtils.removeWorldItem(bikeItem)
    BicycleUtils.removeItemFromContainer(bikeItem)
    BicycleUtils.addPersistentWorldItem(square, bikeItem, 0.0, 0.0, 0.0)
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
function AttachmentActionUtils.refreshBikeState(character, bikeItem)
    if not (character and bikeItem) then
        return
    end

    local container = bikeItem:getContainer()
    if isServer() and container then
        syncHandWeaponFields(character, bikeItem)
    end
    AttachmentActionUtils.refreshBikeWorldModel(bikeItem)
    if bikeItem.transmitModData then
        bikeItem:transmitModData()
    end
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param item InventoryItem|nil
---@return boolean
function AttachmentActionUtils.clearItemFromHands(character, item)
    if not (character and item) then
        return false
    end

    local changed = false
    if character:getPrimaryHandItem() == item then
        character:setPrimaryHandItem(nil)
        changed = true
    end
    if character:getSecondaryHandItem() == item then
        character:setSecondaryHandItem(nil)
        changed = true
    end

    if changed and isServer() and sendEquip then
        sendEquip(character)
    end

    return changed
end

---@param bikeItem InventoryItem|nil
---@return InventoryItem|nil
local function resolveTargetItem(target)
    if not target then
        return nil
    end
    if target.getItem then
        return target:getItem()
    end
    return target
end

---@param target InventoryItem|IsoWorldInventoryObject|nil
---@param item InventoryItem|nil
---@return IsoWorldInventoryObject|nil
local function resolveTargetWorldObject(target, item)
    if target and target.getItem then
        return target
    end
    if item and item.getWorldItem then
        return item:getWorldItem()
    end
    return nil
end

---@param target InventoryItem|IsoWorldInventoryObject|nil
---@return InventoryItem|nil
function AttachmentActionUtils.refreshBikeWorldModel(target)
    local item = resolveTargetItem(target)
    if not item then
        return nil
    end

    local worldObject = resolveTargetWorldObject(target, item)
    if worldObject and isClient() then
        return item
    end

    if item.getWorldZRotation and item.setWorldZRotation then
        local zRotation = item:getWorldZRotation()
        if zRotation == nil then
            zRotation = 0
        end
        item:setWorldZRotation(zRotation + 360)
    end

    if worldObject and isServer() then
        AttachmentActionUtils.refreshWorldBike(item)
        return item
    end

    if worldObject and worldObject.updateSprite then
        worldObject:updateSprite()
    end
    if worldObject and worldObject.transmitUpdatedSprite then
        worldObject:transmitUpdatedSprite()
    end

    return item
end

---@param partType string|nil
---@return string|nil
---@nodiscard
function AttachmentActionUtils.getVanillaCounterpartFullType(partType)
    return BicycleVanillaPartMapping.getVanillaFullTypeForPartType(partType)
end

---@param weapon InventoryItem|nil
---@param part InventoryItem|nil
---@param fallbackPartType string|nil
---@return string|nil
---@nodiscard
function AttachmentActionUtils.resolveUpgradePartType(weapon, part, fallbackPartType)
    if fallbackPartType and fallbackPartType ~= "" then
        return fallbackPartType
    end

    local convertedWheelPartType = AttachmentActionUtils.resolveConvertibleWheelPartType(weapon, part)
    if convertedWheelPartType then
        return convertedWheelPartType
    end

    local partType = part and part.getPartType and part:getPartType() or nil
    if partType and partType ~= "" then
        return partType
    end

    return BicycleVanillaPartMapping.resolveAttachPartTypeForVanillaItem(weapon, part)
end

---@param weapon InventoryItem|nil
---@param part InventoryItem|nil
---@param partType string|nil
---@return boolean
---@nodiscard
function AttachmentActionUtils.isValidatedVanillaAttach(weapon, part, partType)
    if not (weapon and part and partType) then
        return false
    end
    if not BicycleVanillaPartMapping.isVanillaSourceForPartType(part, partType) then
        return false
    end
    return BicycleVanillaPartMapping.resolveAttachPartTypeForVanillaItem(weapon, part) == partType
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param part InventoryItem|nil
---@param partType string|nil
---@return InventoryItem|nil
function AttachmentActionUtils.findVanillaSourceItem(character, part, partType)
    if not (character and part and partType) then
        return nil
    end

    local inventory = character:getInventory()
    local expectedFullType = AttachmentActionUtils.getVanillaCounterpartFullType(partType)
    if not expectedFullType then
        return nil
    end

    if part.getFullType and part:getFullType() == expectedFullType then
        if part.getID then
            local byPartId = inventory:getItemWithID(part:getID())
            if byPartId and byPartId:getFullType() == expectedFullType then
                return byPartId
            end
        end

        return inventory:getFirstTypeRecurse(expectedFullType)
    end

    if not part.getModData then
        return nil
    end

    local md = part:getModData()
    local sourceType = md[VANILLA_SOURCE_TYPE_KEY]
    if type(sourceType) ~= "string" or sourceType == "" then
        return nil
    end
    if sourceType ~= expectedFullType then
        return nil
    end

    local sourceId = tonumber(md[VANILLA_SOURCE_ID_KEY])
    if sourceId then
        local byId = inventory:getItemWithID(sourceId)
        if byId and byId:getFullType() == sourceType then
            return byId
        end
    end

    return inventory:getFirstTypeRecurse(sourceType)
end

---@param inventory ItemContainer|nil
---@param item InventoryItem|nil
function AttachmentActionUtils.removeInventoryItem(inventory, item)
    if not (inventory and item) then
        return
    end

    if item.getID and inventory.containsID and inventory:getItemWithID(item:getID()) then
        item = inventory:getItemWithID(item:getID())
    end

    if not item then
        return
    end

    inventory:Remove(item)
    if isServer() then
        sendRemoveItemFromContainer(inventory, item)
    end
end

---@param inventory ItemContainer|nil
---@param item InventoryItem|nil
function AttachmentActionUtils.addInventoryItem(inventory, item)
    if not (inventory and item) then
        return
    end

    if item.getID and inventory.containsID and inventory:containsID(item:getID()) then
        return
    end

    inventory:AddItem(item)
    if isServer() then
        sendAddItemToContainer(inventory, item)
    end
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param sourceItem InventoryItem|nil
function AttachmentActionUtils.consumeVanillaSourceItem(character, sourceItem)
    local inventory = character and character:getInventory() or nil
    if not (inventory and sourceItem) then
        return
    end

    AttachmentActionUtils.removeInventoryItem(inventory, sourceItem)
end

---@param part InventoryItem|nil
---@param partType string|nil
---@return InventoryItem|nil
function AttachmentActionUtils.convertDetachedPartToVanillaItem(part, partType)
    if not part then
        return nil
    end

    local vanillaFullType = AttachmentActionUtils.getVanillaCounterpartFullType(partType)
    if not vanillaFullType then
        return part
    end

    local vanillaItem = instanceItem(vanillaFullType)
    if not vanillaItem then
        return part
    end

    return vanillaItem
end

---@param part InventoryItem|nil
---@param targetPartType string|nil
---@return InventoryItem|nil
function AttachmentActionUtils.createPartForAttach(part, targetPartType)
    if not (part and targetPartType) then
        return nil
    end

    local sourcePartType = part.getPartType and part:getPartType() or nil
    if sourcePartType == targetPartType then
        return part
    end

    if not (isWheelPartType(sourcePartType) and isWheelPartType(targetPartType)) then
        return part
    end

    local targetFullType = getWheelVariantFullType(part, targetPartType)
    if not targetFullType then
        return nil
    end

    local convertedPart = instanceItem(targetFullType)
    if not convertedPart then
        return nil
    end

    copyWheelState(part, convertedPart)
    return convertedPart
end

return AttachmentActionUtils
