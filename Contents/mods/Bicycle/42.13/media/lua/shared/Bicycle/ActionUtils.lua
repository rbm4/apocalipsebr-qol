local BicycleUtils = require("Bicycle/Utils")

---@class BicycleActionUtils
local BicycleActionUtils = {}

---@param character IsoGameCharacter|IsoPlayer|nil
---@param bicycleItem InventoryItem|nil
function BicycleActionUtils.ensureEquipped(character, bicycleItem)
    if not (character and bicycleItem) then
        return
    end

    if isClient() then
        BicycleUtils.removeWorldItem(bicycleItem)
        BicycleUtils.removeItemFromContainer(bicycleItem)
    elseif isServer() then
        BicycleUtils.removeWorldItem(bicycleItem)
        BicycleUtils.removeItemFromContainer(bicycleItem)
    else
        BicycleUtils.removeWorldItem(bicycleItem)
        BicycleUtils.removeItemFromContainer(bicycleItem)
    end

    if bicycleItem:getContainer() ~= character:getInventory() then
        character:getInventory():AddItem(bicycleItem)
    end

    character:setPrimaryHandItem(bicycleItem)
    character:setSecondaryHandItem(bicycleItem)
    character:setVariable("BicycleActive", "true")
    character:setIgnoreAutoVault(true)
end

return BicycleActionUtils
