local BicycleContainers = require("Bicycle/Containers")
local BicycleUtils = require("Bicycle/Utils")
local SidecarAnimal = require("Bicycle/SidecarAnimal")
require("Foraging/forageSystem")

---@class BicycleContainerGuards
local Guards = {}

---@type table<string, boolean>
local INVISIBLE_CONTAINER_TYPES = {
    ["Bicycle.Saddlebag"] = true,
    ["Bicycle.Basket"] = true,
    ["Bicycle.Crate"] = true,
    ["Bicycle.ToolboxContainer"] = true,
    ["Bicycle.PlasticBagLeft"] = true,
    ["Bicycle.PlasticBagRight"] = true,
}

---@param text string|nil
---@return string
---@nodiscard
local function toLower(text)
    if not text then
        return ""
    end

    return string.lower(text)
end

---@param text string|nil
---@return boolean
---@nodiscard
local function matchesTrunkKeyword(text)
    local lower = toLower(text)
    if lower:find("trunk", 1, true) ~= nil then
        return true
    end
    if lower:find("truckbed", 1, true) ~= nil then
        return true
    end
    if lower:find("boot", 1, true) ~= nil then
        return true
    end
    if lower:find("trailer", 1, true) ~= nil then
        return true
    end
    return false
end

---@param fullType string|nil
---@return boolean
---@nodiscard
function Guards.isInvisibleContainerFullType(fullType)
    if not fullType then
        return false
    end

    return INVISIBLE_CONTAINER_TYPES[fullType] == true
end

---@param item InventoryItem|nil
---@return boolean
---@nodiscard
function Guards.isInvisibleContainerItem(item)
    if not (item and item.getFullType) then
        return false
    end

    return Guards.isInvisibleContainerFullType(item:getFullType())
end

---@param container ItemContainer|nil
---@return boolean
---@nodiscard
function Guards.isInvisibleContainer(container)
    if not (container and container.getContainingItem) then
        return false
    end

    return Guards.isInvisibleContainerItem(container:getContainingItem())
end

---@param item InventoryItem|nil
---@return boolean
---@nodiscard
function Guards.isBicycleItem(item)
    return BicycleUtils.isBicycleItem(item)
end

---@param container ItemContainer|nil
---@return boolean
---@nodiscard
function Guards.isVehicleTrunkContainer(container)
    if not (container and container.getVehiclePart) then
        return false
    end

    local part = container:getVehiclePart()
    if not part then
        return false
    end

    if matchesTrunkKeyword(part:getId()) then
        return true
    end

    if matchesTrunkKeyword(part:getArea()) then
        return true
    end

    return false
end

---@param container ItemContainer|nil
---@return boolean
---@nodiscard
function Guards.isFloorContainer(container)
    return container and container.getType and container:getType() == "floor"
end

---@param container ItemContainer|nil
---@return boolean
---@nodiscard
function Guards.isAllowedInvisibleDestination(container)
    if Guards.isFloorContainer(container) then
        return true
    end

    if Guards.isVehicleTrunkContainer(container) then
        return true
    end

    return false
end

---@param container ItemContainer|nil
---@param player IsoPlayer|nil
---@return boolean
---@nodiscard
function Guards.isPlayerInventory(container, player)
    if not (container and container.isInCharacterInventory and player) then
        return false
    end

    return container:isInCharacterInventory(player)
end

---@param item InventoryItem|nil
---@return boolean
---@nodiscard
function Guards.canStoreInInvisibleContainer(item)
    if Guards.isBicycleItem(item) then
        return false
    end

    return true
end

---@param container ItemContainer|nil
---@param item InventoryItem|nil
---@return boolean
function Bicycle_InvisibleContainerAcceptItem(container, item)
    if Guards.canStoreInInvisibleContainer(item) then
        return true
    end

    return false
end

---@param container ItemContainer|nil
---@param item InventoryItem|nil
---@return boolean
function Bicycle_SidecarAcceptItem(container, item)
    if not Guards.canStoreInInvisibleContainer(item) then
        return false
    end

    if SidecarAnimal.isAnimalItem(item) then
        return false
    end

    if container and container.getContainingItem then
        local parentBike = container:getContainingItem()
        if SidecarAnimal.bikeHasAnyAnimalPart(parentBike) then
            return false
        end
    end

    return true
end

Events.onAddForageDefs.Add(function()
    for _, definition in ipairs(BicycleContainers.getDefinitions()) do
        forageSystem.removeItemDef({ type = definition.fullType })
    end
end)

---@return nil
local function removeBasket()
    if forageSystem and forageSystem.isInitialised then
        for _, definition in ipairs(BicycleContainers.getDefinitions()) do
            forageSystem.removeItemDef({ type = definition.fullType })
        end
    end
end

Events.OnGameStart.Add(removeBasket)
Events.OnConnected.Add(removeBasket)

return Guards
