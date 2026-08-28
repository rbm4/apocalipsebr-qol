---@class BicycleContainers
local BicycleContainers = {}

---@class BicycleContainerDefinition
---@field partType string
---@field itemType string
---@field fullType string

---@type table<string, BicycleContainerDefinition>
local CONTAINER_DEFINITIONS = {
    Saddlebag = {
        partType = "Saddlebag",
        itemType = "Saddlebag",
        fullType = "Bicycle.Saddlebag",
    },
    Basket = {
        partType = "Basket",
        itemType = "Basket",
        fullType = "Bicycle.Basket",
    },
    Crate = {
        partType = "Crate",
        itemType = "Crate",
        fullType = "Bicycle.Crate",
    },
    Sidecar = {
        partType = "Sidecar",
        itemType = "Sidecar",
        fullType = "Bicycle.Sidecar",
    },
    Toolbox = {
        partType = "Toolbox",
        itemType = "ToolboxContainer",
        fullType = "Bicycle.ToolboxContainer",
    },
    PlasticBagLeft = {
        partType = "PlasticBagLeft",
        itemType = "PlasticBagLeft",
        fullType = "Bicycle.PlasticBagLeft",
    },
    PlasticBagRight = {
        partType = "PlasticBagRight",
        itemType = "PlasticBagRight",
        fullType = "Bicycle.PlasticBagRight",
    },
}

---@param partType string|nil
---@return string|nil
---@nodiscard
function BicycleContainers.getContainerItemType(partType)
    if not partType then
        return nil
    end

    local definition = CONTAINER_DEFINITIONS[partType]
    return definition and definition.itemType or nil
end

---@param partType string|nil
---@return string|nil
---@nodiscard
function BicycleContainers.getContainerFullType(partType)
    if not partType then
        return nil
    end

    local definition = CONTAINER_DEFINITIONS[partType]
    return definition and definition.fullType or nil
end

---@param itemType string|nil
---@return boolean
---@nodiscard
function BicycleContainers.isContainerItemType(itemType)
    if not itemType then
        return false
    end

    for _, definition in pairs(CONTAINER_DEFINITIONS) do
        if definition.itemType == itemType then
            return true
        end
    end

    return false
end

---@param partType string|nil
---@return boolean
---@nodiscard
function BicycleContainers.isContainerPartType(partType)
    if not partType then
        return false
    end

    return CONTAINER_DEFINITIONS[partType] ~= nil
end

---@return BicycleContainerDefinition[]
---@nodiscard
function BicycleContainers.getDefinitions()
    local results = {}
    for _, definition in pairs(CONTAINER_DEFINITIONS) do
        table.insert(results, definition)
    end

    table.sort(results, function(left, right)
        return left.partType < right.partType
    end)

    return results
end

return BicycleContainers
