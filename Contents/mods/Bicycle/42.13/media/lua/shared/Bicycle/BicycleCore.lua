---@class BicycleCore
Bicycle = Bicycle or {}
Bicycle.Core = Bicycle.Core or {}

local Core = Bicycle.Core
local WORLD_ITEM_SEARCH_RADIUS = 3

Core.SyncModule = "BicycleSync"

Core.PlayerVars = {
    Active = "BicycleActive",
    Riding = "Bicycle_Riding",
    RollingTimestamp = "Bicycle_RollingTimestamp",
    WalkSpeed = "BicycleWalkSpeed",
    RunSpeed = "BicycleRunSpeed",
    Speed = "BicycleSpeed"
}

---@nodiscard
---@param rawItem InventoryItem|IsoWorldInventoryObject|nil
---@return InventoryItem|nil
function Core.getInventoryItem(rawItem)
    if instanceof(rawItem, "InventoryItem") then
        return rawItem
    end

    if rawItem and rawItem.getItem then
        return rawItem:getItem()
    end

    return nil
end

---@param square IsoGridSquare|nil
---@param itemId number
---@return InventoryItem|nil
---@nodiscard
local function findWorldItemOnSquareById(square, itemId)
    if not square then
        return nil
    end

    local worldObjects = square:getWorldObjects()
    if not worldObjects then
        return nil
    end

    for index = 0, worldObjects:size() - 1 do
        local worldObj = worldObjects:get(index)
        local item = worldObj and worldObj.getItem and worldObj:getItem() or nil
        if item and item.getID and item:getID() == itemId then
            return item
        end
    end

    return nil
end

---@nodiscard
---@param player IsoPlayer|IsoGameCharacter|nil
---@param itemId number|nil
---@param searchSquare IsoGridSquare|nil
---@return InventoryItem|nil
function Core.findItemById(player, itemId, searchSquare)
    if not (player and itemId) then
        return nil
    end

    local inventory = player:getInventory()
    if inventory and inventory.getItemWithID then
        local item = inventory:getItemWithID(itemId)
        if item then
            return item
        end
    end

    local square = searchSquare or player:getSquare()
    if not square then
        return nil
    end

    local centerX = square:getX()
    local centerY = square:getY()
    local centerZ = square:getZ()
    local radius = WORLD_ITEM_SEARCH_RADIUS

    for dx = -radius, radius do
        for dy = -radius, radius do
            if dx * dx + dy * dy <= radius * radius then
                local candidate = getSquare(centerX + dx, centerY + dy, centerZ)
                local worldItem = findWorldItemOnSquareById(candidate, itemId)
                if worldItem then
                    return worldItem
                end
            end
        end
    end

    return nil
end

return Core
