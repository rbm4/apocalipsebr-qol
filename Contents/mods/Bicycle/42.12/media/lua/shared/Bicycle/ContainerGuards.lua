local Guards = {}
require "Foraging/forageSystem"
local BicycleUtils = require("Bicycle/Utils")

local INVISIBLE_CONTAINER_TYPES = {
    ["Bicycle.Saddlebag"] = true,
    ["Bicycle.Basket"] = true,
    ["Bicycle.Crate"] = true,
    ["Bicycle.ToolboxContainer"] = true,
    ["Bicycle.PlasticBagLeft"] = true,
    ["Bicycle.PlasticBagRight"] = true,
}

local function toLower(text)
    if not text then return "" end
    return string.lower(text)
end

local function matchesTrunkKeyword(text)
    local lower = toLower(text)
    if lower:find("trunk", 1, true) ~= nil then return true end
    if lower:find("truckbed", 1, true) ~= nil then return true end
    if lower:find("boot", 1, true) ~= nil then return true end
    if lower:find("trailer", 1, true) ~= nil then return true end
    return false
end

function Guards.isInvisibleContainerFullType(fullType)
    return INVISIBLE_CONTAINER_TYPES[fullType] == true
end

function Guards.isInvisibleContainerItem(item)
    if not (item and item.getFullType) then return false end
    return Guards.isInvisibleContainerFullType(item:getFullType())
end

function Guards.isInvisibleContainer(container)
    if not (container and container.getContainingItem) then return false end
    return Guards.isInvisibleContainerItem(container:getContainingItem())
end

function Guards.isBicycleItem(item)
    return BicycleUtils.isBicycleItem(item)
end

function Guards.isVehicleTrunkContainer(container)
    if not (container and container.getVehiclePart) then return false end
    local part = container:getVehiclePart()
    if not part then return false end
    if matchesTrunkKeyword(part:getId()) then return true end
    if matchesTrunkKeyword(part:getArea()) then return true end
    return false
end

function Guards.isFloorContainer(container)
    return container and container.getType and container:getType() == "floor"
end

function Guards.isAllowedInvisibleDestination(container)
    if Guards.isFloorContainer(container) then
        return true
    end
    if Guards.isVehicleTrunkContainer(container) then
        return true
    end
    return false
end

function Guards.isPlayerInventory(container, player)
    if not (container and container.isInCharacterInventory and player) then return false end
    return container:isInCharacterInventory(player)
end

function Guards.canStoreInInvisibleContainer(item)
    if Guards.isBicycleItem(item) then
        return false
    end
    return true
end

function Bicycle_InvisibleContainerAcceptItem(container, item)
    if Guards.canStoreInInvisibleContainer(item) then
        return true
    end
    return false
end

Events.onAddForageDefs.Add(function()
    forageSystem.removeItemDef({ type = "Bicycle.Saddlebag" })
    forageSystem.removeItemDef({ type = "Bicycle.Basket" })
    forageSystem.removeItemDef({ type = "Bicycle.Crate" })
end)

local function removeBasket()
    if forageSystem and forageSystem.isInitialised then
        forageSystem.removeItemDef({ type = "Bicycle.Saddlebag" })
        forageSystem.removeItemDef({ type = "Bicycle.Basket" })
        forageSystem.removeItemDef({ type = "Bicycle.Crate" })
    end
end

Events.OnGameStart.Add(removeBasket)
Events.OnConnected.Add(removeBasket)

return Guards
