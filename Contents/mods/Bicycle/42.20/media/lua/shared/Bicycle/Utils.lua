---@class BicycleUtils
local BicycleUtils = {}

---@type table<string, boolean>
local BICYCLE_TYPES = {
    Bicycle = true,
    Bicycle_RedStreet = true,
}

---@type table<IsoDirections, number>
local DIRECTION_TO_ROTATION = {
    [IsoDirections.N] = 0,
    [IsoDirections.NE] = 45,
    [IsoDirections.E] = 90,
    [IsoDirections.SE] = 135,
    [IsoDirections.S] = 180,
    [IsoDirections.SW] = 225,
    [IsoDirections.W] = 270,
    [IsoDirections.NW] = 315,
}

---@param rotation number|nil
---@return number|nil
---@nodiscard
function BicycleUtils.normalizeZRotation(rotation)
    if rotation == nil then
        return nil
    end

    local normalized = rotation % 360
    if normalized < 0 then
        normalized = normalized + 360
    end

    return normalized
end

---@param direction IsoDirections|nil
---@return number|nil
---@nodiscard
function BicycleUtils.directionToZRotation(direction)
    if not direction then
        return nil
    end

    return DIRECTION_TO_ROTATION[direction]
end

---@param rotation number|nil
---@return IsoDirections|nil
---@nodiscard
function BicycleUtils.zRotationToDirection(rotation)
    local normalized = BicycleUtils.normalizeZRotation(rotation)
    if normalized == nil then
        return nil
    end

    local closestDir = nil
    local smallestDiff = nil
    for dir, angle in pairs(DIRECTION_TO_ROTATION) do
        local diff = math.abs(angle - normalized)
        diff = math.min(diff, 360 - diff)

        if not smallestDiff or diff < smallestDiff then
            smallestDiff = diff
            closestDir = dir
        end
    end

    return closestDir
end

---@param itemType string|nil
---@return boolean
---@nodiscard
function BicycleUtils.isBicycleType(itemType)
    if not itemType then
        return false
    end

    return BICYCLE_TYPES[itemType] == true
end

---@param item InventoryItem|nil
---@return boolean
---@nodiscard
function BicycleUtils.isBicycleItem(item)
    if not (item and item.getType) then
        return false
    end

    return BicycleUtils.isBicycleType(item:getType())
end

-- A sidecar bike cannot be laid down: it would bury the sidecar and any animal in it. Every dismount path
-- funnels through this predicate. Animal parts need no check -- an animal can only attach to a sidecar.
---@param bikeItem InventoryItem|nil
---@return boolean
---@nodiscard
function BicycleUtils.hasSidecar(bikeItem)
    if not (bikeItem and bikeItem.getWeaponPart) then
        return false
    end

    return bikeItem:getWeaponPart("Sidecar") ~= nil
end

-- A throw requires the bike under the player, carried or on their own square. Reaching to a neighbouring
-- square starts the action mid-transfer and mid-turn, which is the window where throws lost bikes.
---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@return boolean
---@nodiscard
function BicycleUtils.isBikeUnderPlayer(player, bikeItem)
    if not (player and bikeItem) then
        return false
    end

    local worldItem = bikeItem.getWorldItem and bikeItem:getWorldItem() or nil
    if not worldItem then
        -- Carried, so by definition under them.
        return true
    end

    local bikeSquare = worldItem.getSquare and worldItem:getSquare() or nil
    local playerSquare = player.getSquare and player:getSquare() or nil
    if not (bikeSquare and playerSquare) then
        return false
    end

    return bikeSquare:getX() == playerSquare:getX()
        and bikeSquare:getY() == playerSquare:getY()
        and bikeSquare:getZ() == playerSquare:getZ()
end

---@return string[]
---@nodiscard
function BicycleUtils.getBicycleTypes()
    local results = {}
    for typeName, _ in pairs(BICYCLE_TYPES) do
        table.insert(results, typeName)
    end

    table.sort(results)
    return results
end

---@param item InventoryItem|nil
---@return ItemContainer|nil
function BicycleUtils.removeItemFromContainer(item)
    if not (item and item.getContainer) then
        return nil
    end

    local container = item:getContainer()
    if not container then
        return nil
    end

    if container.DoRemoveItem then
        container:DoRemoveItem(item)
    elseif container.Remove then
        container:Remove(item)
    end

    if isClient() then
        sendRemoveItemFromContainer(container, item)
    elseif isServer() then
        sendRemoveItemFromContainer(container, item)
    else
        -- Singleplayer: no peers to notify.
    end

    return container
end

---@param item InventoryItem|nil
function BicycleUtils.removeWorldItem(item)
    if not (item and item.getWorldItem) then
        return
    end

    local worldItem = item:getWorldItem()
    if not worldItem then
        return
    end

    local worldSquare = worldItem.getSquare and worldItem:getSquare() or nil
    if worldSquare then
        worldSquare:transmitRemoveItemFromSquare(worldItem)
        if worldSquare.removeWorldObject then
            worldSquare:removeWorldObject(worldItem)
        end
    end

    if worldItem.removeFromWorld then
        worldItem:removeFromWorld()
    end
    if worldItem.removeFromSquare then
        worldItem:removeFromSquare()
    end
    if worldItem.setSquare then
        worldItem:setSquare(nil)
    end

    if item.setWorldItem then
        item:setWorldItem(nil)
    end
end

---@param square IsoGridSquare|nil
---@param item InventoryItem|string|nil
---@param x number|nil
---@param y number|nil
---@param z number|nil
---@return InventoryItem|nil
function BicycleUtils.addPersistentWorldItem(square, item, x, y, z)
    if not (square and item) then
        return nil
    end

    if x == nil then
        x = 0.0
    end
    if y == nil then
        y = 0.0
    end
    if z == nil then
        z = 0.0
    end

    local inventoryItem = item
    if type(item) == "string" then
        inventoryItem = instanceItem(item)
    end
    if not inventoryItem then
        return nil
    end

    local placedItem = square:AddWorldInventoryItem(inventoryItem, x, y, z, false)
    if not placedItem then
        return inventoryItem
    end

    local worldItem = nil
    if placedItem.getWorldItem then
        worldItem = placedItem:getWorldItem()
    end
    if worldItem then
        worldItem:setIgnoreRemoveSandbox(true)
        worldItem:setExtendedPlacement(false)
        -- Server->clients only: transmitCompleteItemToServer is not in the API and threw on every client-side
        -- placement, leaving the bike in no container and no world. Clients go through DropBike instead.
        if isServer() then
            worldItem:transmitCompleteItemToClients()
        end
    end

    return placedItem
end

---@param seconds number
---@param callback fun(...)
---@param ... unknown
---@return fun()
function BicycleUtils.runAfter(seconds, callback, ...)
    local elapsed = 0 --[[@as number]]
    local gameTime = GameTime.getInstance()
    local args = { ... }

    local function tick()
        elapsed = elapsed + gameTime:getTimeDelta()
        if elapsed < seconds then
            return
        end

        Events.OnTick.Remove(tick)
        callback(unpack(args))
    end

    Events.OnTick.Add(tick)

    return function()
        Events.OnTick.Remove(tick)
    end
end

return BicycleUtils
