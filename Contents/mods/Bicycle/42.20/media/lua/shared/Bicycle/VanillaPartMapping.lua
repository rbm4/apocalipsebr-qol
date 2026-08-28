---@class BicycleVanillaPartMapping
local BicycleVanillaPartMapping = {}

local PLASTIC_BAG_FULL_TYPES = {
    "Base.Plasticbag",
    "Base.Plasticbag_Bags",
    "Base.Plasticbag_Clothing",
    "Base.GroceryBag1",
    "Base.GroceryBag2",
    "Base.GroceryBag3",
    "Base.GroceryBag4",
    "Base.GroceryBag5",
    "Base.GroceryBagGourmet",
}

local TOOLBOX_FULL_TYPES = {
    "Base.Toolbox",
    "Base.Bag_JanitorToolbox",
    "Base.Toolbox_Farming",
    "Base.Toolbox_Fishing",
    "Base.Toolbox_Gardening",
    "Base.Toolbox_Mechanic",
}

local SPORTSBOTTLE_FULL_TYPES = {
    "Base.Sportsbottle",
}

---@type table<string, string[]>
local VANILLA_SOURCES_BY_PART_TYPE = {
    Toolbox = TOOLBOX_FULL_TYPES,
    PlasticBagLeft = PLASTIC_BAG_FULL_TYPES,
    PlasticBagRight = PLASTIC_BAG_FULL_TYPES,
    Sportsbottle = SPORTSBOTTLE_FULL_TYPES,
}

local PART_FULL_TYPE_BY_PART_TYPE = {
    Toolbox = "Bicycle.Bicycle_Toolbox",
    PlasticBagLeft = "Bicycle.Bicycle_PlasticBagLeft",
    PlasticBagRight = "Bicycle.Bicycle_PlasticBagRight",
    Sportsbottle = "Bicycle.Bicycle_Sportsbottle",
}

---@type table<string, table<string, boolean>>
local ACCEPTED_SET_BY_PART_TYPE = {}
---@type table<string, boolean>
local VANILLA_SOURCE_TYPES = {}

for partType, fullTypes in pairs(VANILLA_SOURCES_BY_PART_TYPE) do
    local accepted = {}
    for i = 1, #fullTypes do
        accepted[fullTypes[i]] = true
        VANILLA_SOURCE_TYPES[fullTypes[i]] = true
    end
    ACCEPTED_SET_BY_PART_TYPE[partType] = accepted
end

---@param partType string|nil
---@param fullType string|nil
---@return boolean
---@nodiscard
local function acceptsFullType(partType, fullType)
    if not (partType and fullType) then
        return false
    end

    local accepted = ACCEPTED_SET_BY_PART_TYPE[partType]
    return accepted ~= nil and accepted[fullType] == true
end

---@param partType string|nil
---@return string|nil
---@nodiscard
function BicycleVanillaPartMapping.getVanillaFullTypeForPartType(partType)
    if not partType then
        return nil
    end

    local fullTypes = VANILLA_SOURCES_BY_PART_TYPE[partType]
    return fullTypes and fullTypes[1] or nil
end

---@param partType string|nil
---@return string[]|nil
---@nodiscard
function BicycleVanillaPartMapping.getAcceptedVanillaFullTypes(partType)
    if not partType then
        return nil
    end
    return VANILLA_SOURCES_BY_PART_TYPE[partType]
end

---@param partType string|nil
---@return string|nil
---@nodiscard
function BicycleVanillaPartMapping.getPartFullType(partType)
    if not partType then
        return nil
    end
    return PART_FULL_TYPE_BY_PART_TYPE[partType]
end

---@param fullType string|nil
---@return boolean
---@nodiscard
function BicycleVanillaPartMapping.isVanillaSourceFullType(fullType)
    if not fullType then
        return false
    end
    return VANILLA_SOURCE_TYPES[fullType] == true
end

---@param item InventoryItem|nil
---@param partType string|nil
---@return boolean
---@nodiscard
function BicycleVanillaPartMapping.isVanillaSourceForPartType(item, partType)
    if not (item and item.getFullType and partType) then
        return false
    end

    return acceptsFullType(partType, item:getFullType())
end

---@param inventory ItemContainer|nil
---@param partType string|nil
---@return InventoryItem|nil
---@nodiscard
function BicycleVanillaPartMapping.findVanillaSourceInInventory(inventory, partType)
    if not (inventory and partType) then
        return nil
    end

    local fullTypes = VANILLA_SOURCES_BY_PART_TYPE[partType]
    if not fullTypes then
        return nil
    end

    for i = 1, #fullTypes do
        local found = inventory:getFirstTypeRecurse(fullTypes[i])
        if found then
            return found
        end
    end

    return nil
end

---@param bikeItem InventoryItem|nil
---@param vanillaItem InventoryItem|nil
---@return string|nil
---@nodiscard
function BicycleVanillaPartMapping.resolveAttachPartTypeForVanillaItem(bikeItem, vanillaItem)
    if not (bikeItem and vanillaItem and vanillaItem.getFullType and bikeItem.getWeaponPart) then
        return nil
    end

    local fullType = vanillaItem:getFullType()

    if acceptsFullType("Toolbox", fullType) then
        if bikeItem:getWeaponPart("Toolbox") then
            return nil
        end
        if bikeItem:getWeaponPart("Crate") then
            return nil
        end
        return "Toolbox"
    end

    if acceptsFullType("PlasticBagLeft", fullType) then
        if not bikeItem:getWeaponPart("PlasticBagLeft") then
            return "PlasticBagLeft"
        end
        if not bikeItem:getWeaponPart("PlasticBagRight") then
            return "PlasticBagRight"
        end
        return nil
    end

    if acceptsFullType("Sportsbottle", fullType) then
        if not bikeItem:getWeaponPart("BottleHolder") then
            return nil
        end
        if bikeItem:getWeaponPart("Sportsbottle") then
            return nil
        end
        return "Sportsbottle"
    end

    return nil
end

return BicycleVanillaPartMapping
