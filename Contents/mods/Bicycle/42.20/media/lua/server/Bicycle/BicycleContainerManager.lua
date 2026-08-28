if isClient() then
    return
end

local BicycleContainers = require("Bicycle/Containers")
local ContainerGuards = require("Bicycle/ContainerGuards")
local BicycleDebug = require("Bicycle/Debug")
local BicycleUtils = require("Bicycle/Utils")
local SidecarAnimal = require("Bicycle/SidecarAnimal")

---@class BicycleContainerManager
local Manager = {}

---@type table<string, BicycleContainerDefinition>
local CONTAINER_DEFS_BY_PART = {}
---@type table<string, BicycleContainerDefinition>
local CONTAINER_DEFS_BY_FULL_TYPE = {}
---@type string[]
local CONTAINER_PART_TYPES = {}
---@type string[]
local BICYCLE_ITEM_TYPES = BicycleUtils.getBicycleTypes()

do
    local defs = BicycleContainers.getDefinitions()
    for i = 1, #defs do
        local def = defs[i]
        CONTAINER_DEFS_BY_PART[def.partType] = def
        CONTAINER_DEFS_BY_FULL_TYPE[def.fullType] = def
        CONTAINER_PART_TYPES[#CONTAINER_PART_TYPES + 1] = def.partType
    end
end

---@param player IsoPlayer|nil
local function refreshInventories(player)
    if not player then
        return
    end
    if isServer() then
        return
    end

    if triggerEvent then
        triggerEvent("OnContainerUpdate")
    end
    if not getPlayerData then
        return
    end

    local pdata = getPlayerData(player:getPlayerNum())
    if not pdata then
        return
    end
    if pdata.playerInventory and pdata.playerInventory.refreshBackpacks then
        pdata.playerInventory:refreshBackpacks()
    end
    if pdata.lootInventory and pdata.lootInventory.refreshBackpacks then
        pdata.lootInventory:refreshBackpacks()
    end
end

---@param bikeItem InventoryItem
---@return table<string, table>
local function getBikeContainersModData(bikeItem)
    local md = bikeItem:getModData()
    md.BicycleContainers = md.BicycleContainers or {}
    return md.BicycleContainers
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@return IsoGridSquare|nil
---@nodiscard
local function getBikeWorldSquare(bikeItem)
    if not (bikeItem and bikeItem.getWorldItem) then
        return nil
    end

    local worldItem = bikeItem:getWorldItem()
    if not worldItem then
        return nil
    end

    return worldItem:getSquare()
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@return boolean
---@nodiscard
local function isBikeInPlayerHands(player, bikeItem)
    if not (player and bikeItem) then
        return false
    end
    return player:getPrimaryHandItem() == bikeItem or player:getSecondaryHandItem() == bikeItem
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@return IsoGridSquare|nil
---@nodiscard
local function getBikeTrackingSquare(player, bikeItem)
    local square = getBikeWorldSquare(bikeItem)
    if square then
        return square
    end
    if player and isBikeInPlayerHands(player, bikeItem) then
        return player:getSquare()
    end
    return nil
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@return ItemContainer|nil
---@nodiscard
local function getBikeStorageContainer(player, bikeItem)
    local container = nil
    if bikeItem and bikeItem.getContainer then
        container = bikeItem:getContainer()
    end
    if container then
        return container
    end

    if not (player and bikeItem) then
        return nil
    end

    local inventory = player:getInventory()
    if inventory:contains(bikeItem) then
        return inventory
    end
    if player:getPrimaryHandItem() == bikeItem then
        return inventory
    end
    if player:getSecondaryHandItem() == bikeItem then
        return inventory
    end

    return nil
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@return IsoGridSquare|nil
---@nodiscard
local function getTargetSquare(player, bikeItem)
    local square = getBikeWorldSquare(bikeItem)
    if square then
        return square
    end
    if player then
        return player:getSquare()
    end
    return nil
end

---@param worldItem IsoWorldInventoryObject|nil
---@return table|nil
local function getContainerMarker(worldItem)
    if not (worldItem and worldItem.getItem) then
        return nil
    end
    local item = worldItem:getItem()
    if not (item and item.getModData) then
        return nil
    end
    local md = item:getModData()
    if not md.Bicycle then
        return nil
    end
    return md.Bicycle.container
end

---@param item InventoryItem|nil
local function clearContainerItemMarker(item)
    if not (item and item.getModData) then
        return
    end

    local md = item:getModData()
    if not md.Bicycle then
        return
    end

    md.Bicycle.container = nil
    if item.transmitModData then
        item:transmitModData()
    end
end

---@param worldItem IsoWorldInventoryObject|nil
local function clearContainerMarker(worldItem)
    if not (worldItem and worldItem.getItem) then
        return
    end
    local item = worldItem:getItem()
    clearContainerItemMarker(item)
    if worldItem.transmitModData then
        worldItem:transmitModData()
    end
end

---@param item InventoryItem|nil
---@param containerInfo table|nil
---@param bikeItemId number
---@param partType string
local function setContainerItemMarker(item, containerInfo, bikeItemId, partType)
    if not (item and item.getModData) then
        return
    end

    local itemId = nil
    if containerInfo then
        itemId = containerInfo.itemId
    end
    if item.getID then
        itemId = item:getID()
    end

    local md = item:getModData()
    md.Bicycle = md.Bicycle or {}
    md.Bicycle.container = {
        bikeItemId = bikeItemId,
        partType = partType,
        itemId = itemId
    }

    if item.transmitModData then
        item:transmitModData()
    end
end

---@param worldItem IsoWorldInventoryObject|nil
---@param fullType string
---@param expectedItemId number|nil
---@return boolean
local function isMatchingWorldItem(worldItem, fullType, expectedItemId)
    if not (worldItem and worldItem.getItem) then
        return false
    end

    local item = worldItem:getItem()
    if not item then
        return false
    end

    if item:getFullType() ~= fullType then
        return false
    end

    if expectedItemId ~= nil and item.getID and item:getID() ~= expectedItemId then
        return false
    end

    return true
end

---@param worldObj IsoWorldInventoryObject|nil
---@param bikeItemId number
---@return boolean
---@nodiscard
local function isOwnedByOtherBike(worldObj, bikeItemId)
    local marker = getContainerMarker(worldObj)
    if not (marker and marker.bikeItemId) then
        return false
    end

    return marker.bikeItemId ~= bikeItemId
end

---@param square IsoGridSquare|nil
---@param fullType string
---@param expectedItemId number|nil
---@param bikeItemId number
---@param partType string
---@return IsoWorldInventoryObject|nil
local function findContainerOnSquare(square, fullType, expectedItemId, bikeItemId, partType)
    if not (square and square.getWorldObjects) then
        return nil
    end

    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local worldObj = worldObjects:get(i)
        if worldObj and worldObj.getItem then
            local item = worldObj:getItem()
            if item and item:getFullType() == fullType and not isOwnedByOtherBike(worldObj, bikeItemId) then
                if expectedItemId ~= nil and item.getID and item:getID() == expectedItemId then
                    return worldObj
                end

                local marker = getContainerMarker(worldObj)
                if marker
                    and marker.bikeItemId == bikeItemId
                    and marker.partType == partType
                    and (expectedItemId == nil or marker.itemId == expectedItemId) then
                    return worldObj
                end
            end
        end
    end

    return nil
end

---@param square IsoGridSquare|nil
---@param fullType string
---@param bikeItemId number
---@return IsoWorldInventoryObject|nil
local function findAnyContainerOnSquare(square, fullType, bikeItemId)
    if not (square and square.getWorldObjects) then
        return nil
    end

    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local worldObj = worldObjects:get(i)
        if worldObj and worldObj.getItem then
            local item = worldObj:getItem()
            if item and item:getFullType() == fullType and not isOwnedByOtherBike(worldObj, bikeItemId) then
                return worldObj
            end
        end
    end

    return nil
end

---@param square IsoGridSquare|nil
---@param fullType string
---@param expectedItemId number|nil
---@param bikeItemId number
---@param partType string
---@return IsoWorldInventoryObject|nil
local function findContainerNearSquare(square, fullType, expectedItemId, bikeItemId, partType)
    if not square then
        return nil
    end

    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local candidate = getSquare(x + dx, y + dy, z)
            local found = findContainerOnSquare(candidate, fullType, expectedItemId, bikeItemId, partType)
            if found then
                return found
            end
        end
    end

    return nil
end

---@param square IsoGridSquare|nil
---@param fullType string
---@param bikeItemId number
---@return IsoWorldInventoryObject|nil
local function findAnyContainerNearSquare(square, fullType, bikeItemId)
    if not square then
        return nil
    end

    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local candidate = getSquare(x + dx, y + dy, z)
            local found = findAnyContainerOnSquare(candidate, fullType, bikeItemId)
            if found then
                return found
            end
        end
    end

    return nil
end

---@param square IsoGridSquare|nil
---@param fullType string
---@param bikeItemId number
---@param partType string
---@return IsoWorldInventoryObject|nil
function Manager.findOrAdoptContainer(square, fullType, bikeItemId, partType)
    return findContainerNearSquare(square, fullType, nil, bikeItemId, partType)
end

---@param worldItem IsoWorldInventoryObject
---@param containerInfo table
---@param bikeItemId number
---@param partType string
function Manager.setContainerData(worldItem, containerInfo, bikeItemId, partType)
    local item = worldItem:getItem()
    if not item then
        return
    end

    containerInfo.worldItem = worldItem
    containerInfo.x = worldItem:getX()
    containerInfo.y = worldItem:getY()
    containerInfo.z = worldItem:getZ()
    containerInfo.fullType = item:getFullType()
    containerInfo.itemId = item.getID and item:getID() or containerInfo.itemId
    containerInfo.packed = nil
    containerInfo.storage = nil

    setContainerItemMarker(item, containerInfo, bikeItemId, partType)
    if worldItem.transmitModData then
        worldItem:transmitModData()
    end
end

---@param square IsoGridSquare|nil
---@param fullType string
---@return IsoWorldInventoryObject|nil
local function spawnManagedContainer(square, fullType)
    if not square then
        return nil
    end

    local item = square:AddWorldInventoryItem(fullType, 0.0, 0.0, 0.0, false, true)
    if not item then
        return nil
    end
    return item:getWorldItem()
end

---@param worldItem IsoWorldInventoryObject|nil
local function detachWorldItemFromSquare(worldItem)
    if not (worldItem and worldItem.getItem) then
        return
    end

    local square = worldItem:getSquare()
    if square and square.transmitRemoveItemFromSquare then
        square:transmitRemoveItemFromSquare(worldItem)
        if square.removeWorldObject then
            square:removeWorldObject(worldItem)
        end
    end

    local item = worldItem:getItem()
    if worldItem.removeFromWorld then
        worldItem:removeFromWorld()
    end
    if worldItem.removeFromSquare then
        worldItem:removeFromSquare()
    end
    if worldItem.setSquare then
        worldItem:setSquare(nil)
    end
    if item and item.setWorldItem then
        item:setWorldItem(nil)
    end
end

---@param square IsoGridSquare|nil
---@param containerInfo table
---@param worldItem IsoWorldInventoryObject
---@param bikeItemId number
---@param partType string
---@return IsoWorldInventoryObject|nil
function Manager.moveWorldItem(square, containerInfo, worldItem, bikeItemId, partType)
    if not (square and worldItem and worldItem.getItem) then
        return worldItem
    end

    local currentSquare = worldItem:getSquare()
    if currentSquare == square then
        return worldItem
    end

    local item = worldItem:getItem()
    if not item then
        return nil
    end

    detachWorldItemFromSquare(worldItem)
    square:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
    local movedWorldItem = item:getWorldItem()
    if movedWorldItem then
        Manager.setContainerData(movedWorldItem, containerInfo, bikeItemId, partType)
    end
    return movedWorldItem or worldItem
end

---@param containerInfo table|nil
local function clearContainerInfo(containerInfo)
    if not containerInfo then
        return
    end
    containerInfo.worldItem = nil
    containerInfo.x = nil
    containerInfo.y = nil
    containerInfo.z = nil
    containerInfo.fullType = nil
    containerInfo.itemId = nil
    containerInfo.packed = nil
    containerInfo.storage = nil
end

---@param containerInfo table|nil
---@return boolean
---@nodiscard
local function hasContainerTrackingData(containerInfo)
    if not containerInfo then
        return false
    end
    if containerInfo.worldItem then
        return true
    end
    if containerInfo.itemId then
        return true
    end
    if containerInfo.x and containerInfo.y and containerInfo.z then
        return true
    end
    if containerInfo.packed then
        return true
    end
    return false
end

---@param container ItemContainer|nil
---@return InventoryItem[]
---@nodiscard
local function copyContainerItems(container)
    local out = {}
    if not container then
        return out
    end

    local items = container:getItems()
    if not items then
        return out
    end

    for i = 0, items:size() - 1 do
        out[#out + 1] = items:get(i)
    end

    return out
end

---@param container ItemContainer|nil
---@param fullType string
---@param expectedItemId number|nil
---@return InventoryItem|nil
---@nodiscard
local function findContainerItem(container, fullType, expectedItemId)
    if not (container and fullType) then
        return nil
    end

    local items = container:getItems()
    if not items then
        return nil
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item:getFullType() == fullType then
            if expectedItemId == nil then
                return item
            end
            if item.getID and item:getID() == expectedItemId then
                return item
            end
        end
    end

    return nil
end

---@param containerInfo table|nil
---@param item InventoryItem|nil
---@param storageContainer ItemContainer|nil
---@param bikeItemId number|nil
---@param partType string|nil
local function storePackedContainerInfo(containerInfo, item, storageContainer, bikeItemId, partType)
    if not (containerInfo and item) then
        return
    end

    containerInfo.worldItem = nil
    containerInfo.x = nil
    containerInfo.y = nil
    containerInfo.z = nil
    containerInfo.fullType = item:getFullType()
    if item.getID then
        containerInfo.itemId = item:getID()
    else
        containerInfo.itemId = nil
    end
    containerInfo.packed = true
    containerInfo.storage = containerInfo.storage or {}
    containerInfo.storage.container = storageContainer
    if bikeItemId and partType then
        setContainerItemMarker(item, containerInfo, bikeItemId, partType)
    end
end

---@param container ItemContainer|nil
---@param item InventoryItem|nil
local function sendRemoveFromContainer(container, item)
    if isServer() and container and item then
        sendRemoveItemFromContainer(container, item)
    end
end

---@param container ItemContainer|nil
---@param item InventoryItem|nil
local function sendAddToContainer(container, item)
    if isServer() and container and item then
        sendAddItemToContainer(container, item)
    end
end

---@param container ItemContainer|nil
---@param item InventoryItem|nil
local function removeItemFromContainer(container, item)
    if not (container and item and item:getContainer() == container) then
        return
    end

    container:DoRemoveItem(item)
    sendRemoveFromContainer(container, item)
end

---@param container ItemContainer|nil
---@param item InventoryItem|nil
local function addItemToContainer(container, item)
    if not (container and item) then
        return
    end
    if item:getContainer() == container then
        return
    end

    container:AddItem(item)
    sendAddToContainer(container, item)
end

---@param square IsoGridSquare|nil
---@param item InventoryItem|nil
---@return IsoWorldInventoryObject|nil
---@nodiscard
local function placeContainerItemOnSquare(square, item)
    if not (square and item) then
        return nil
    end

    local placedItem = square:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
    if placedItem and placedItem.getWorldItem then
        return placedItem:getWorldItem()
    end
    if item.getWorldItem then
        return item:getWorldItem()
    end
    return nil
end

---@param item InventoryItem|nil
---@param square IsoGridSquare|nil
local function spillContainerItemContents(item, square)
    if not (item and square and item.getItemContainer) then
        return
    end

    local container = item:getItemContainer()
    if not container then
        return
    end

    local toDrop = copyContainerItems(container)
    for i = 1, #toDrop do
        local entry = toDrop[i]
        if entry and entry:getContainer() == container then
            container:DoRemoveItem(entry)
            sendRemoveFromContainer(container, entry)
            square:AddWorldInventoryItem(entry, 0.0, 0.0, 0.0)
        end
    end
end

---@param srcContainer ItemContainer|nil
---@param destContainer ItemContainer|nil
---@param character IsoPlayer|IsoGameCharacter|nil
local function transferAllContainerItems(srcContainer, destContainer, character)
    if not (srcContainer and destContainer) then
        return
    end

    local items = srcContainer:getItems()
    if not items then
        return
    end

    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and item:getContainer() == srcContainer then
            srcContainer:DoRemoveItem(item)
            sendRemoveFromContainer(srcContainer, item)
            destContainer:AddItem(item)
            sendAddToContainer(destContainer, item)
        end
    end
end

---@param sourceItem InventoryItem|nil
---@param destItem InventoryItem|nil
local function copyContainerVisuals(sourceItem, destItem)
    if not (sourceItem and destItem) then
        return
    end

    if destItem.setName and sourceItem.getDisplayName then
        destItem:setName(sourceItem:getDisplayName())
    end
    if destItem.setIcon and sourceItem.getIcon then
        destItem:setIcon(sourceItem:getIcon())
    end
    if isServer() and destItem.syncItemFields then
        destItem:syncItemFields()
    end
end

---@param bikeItem InventoryItem
---@param def BicycleContainerDefinition
---@param containerInfo table|nil
---@param targetSquare IsoGridSquare|nil
---@return IsoWorldInventoryObject|nil
local function unpackStoredContainerToWorld(bikeItem, def, containerInfo, targetSquare)
    if not (bikeItem and def and containerInfo and containerInfo.packed and targetSquare) then
        return nil
    end

    local storageContainer = nil
    if containerInfo.storage then
        storageContainer = containerInfo.storage.container
    end
    if not storageContainer then
        return nil
    end

    local containerItem = findContainerItem(storageContainer, def.fullType, containerInfo.itemId)
    if not containerItem then
        containerItem = findContainerItem(storageContainer, def.fullType, nil)
    end
    if not (containerItem and containerItem:getContainer() == storageContainer) then
        return nil
    end

    storageContainer:DoRemoveItem(containerItem)
    sendRemoveFromContainer(storageContainer, containerItem)

    local worldItem = placeContainerItemOnSquare(targetSquare, containerItem)
    if not (worldItem and worldItem.getItem) then
        addItemToContainer(storageContainer, containerItem)
        return nil
    end

    Manager.setContainerData(worldItem, containerInfo, bikeItem:getID(), def.partType)
    containerInfo.packed = nil
    containerInfo.storage = nil
    return worldItem
end

---@param worldItem IsoWorldInventoryObject|nil
---@param square IsoGridSquare|nil
local function spillContainerContents(worldItem, square)
    if not (worldItem and square and worldItem.getItem) then
        return
    end

    spillContainerItemContents(worldItem:getItem(), square)
end

---@param bikeItem InventoryItem
---@param partType string
---@param def BicycleContainerDefinition
---@param containerInfo table|nil
---@param targetSquare IsoGridSquare|nil
---@return IsoWorldInventoryObject|nil
local function resolveDetachContainerWorldItem(bikeItem, partType, def, containerInfo, targetSquare)
    if not (bikeItem and partType and def) then
        return nil
    end

    local bikeItemId = bikeItem:getID()
    local expectedItemId = nil
    local worldItem = nil
    if containerInfo then
        expectedItemId = containerInfo.itemId
        worldItem = containerInfo.worldItem
    end
    if not isMatchingWorldItem(worldItem, def.fullType, expectedItemId) then
        worldItem = nil
    end

    if not worldItem and containerInfo and containerInfo.itemId and containerInfo.x and containerInfo.y and containerInfo.z then
        local oldSquare = getSquare(containerInfo.x, containerInfo.y, containerInfo.z)
        worldItem = findContainerOnSquare(oldSquare, def.fullType, containerInfo.itemId, bikeItemId, partType)
    end

    if not worldItem and containerInfo and containerInfo.x and containerInfo.y and containerInfo.z then
        local oldSquare = getSquare(containerInfo.x, containerInfo.y, containerInfo.z)
        worldItem = findContainerOnSquare(oldSquare, def.fullType, nil, bikeItemId, partType)
    end

    if not worldItem and targetSquare then
        worldItem = findContainerOnSquare(targetSquare, def.fullType, expectedItemId, bikeItemId, partType)
    end

    if not worldItem and targetSquare then
        worldItem = findContainerNearSquare(targetSquare, def.fullType, expectedItemId, bikeItemId, partType)
    end

    if not worldItem and targetSquare then
        worldItem = findContainerNearSquare(targetSquare, def.fullType, nil, bikeItemId, partType)
    end

    if not worldItem and containerInfo and containerInfo.x and containerInfo.y and containerInfo.z then
        local oldSquare = getSquare(containerInfo.x, containerInfo.y, containerInfo.z)
        worldItem = findAnyContainerOnSquare(oldSquare, def.fullType, bikeItemId)
    end

    if not worldItem and targetSquare then
        worldItem = findAnyContainerOnSquare(targetSquare, def.fullType, bikeItemId)
    end

    if not worldItem and targetSquare then
        worldItem = findAnyContainerNearSquare(targetSquare, def.fullType, bikeItemId)
    end

    return worldItem
end

---@param worldItem IsoWorldInventoryObject|nil
---@param fallbackSquare IsoGridSquare|nil
local function removeManagedWorldItem(worldItem, fallbackSquare)
    if not worldItem then
        return
    end

    detachWorldItemFromSquare(worldItem)
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem
---@param def BicycleContainerDefinition
---@param containerInfo table|nil
---@return InventoryItem|nil
---@return ItemContainer|nil
---@nodiscard
local function findPackedContainerForBike(player, bikeItem, def, containerInfo)
    local storageContainer = nil
    local itemId = nil
    if containerInfo then
        itemId = containerInfo.itemId
        if containerInfo.storage then
            storageContainer = containerInfo.storage.container
        end
    end

    local containerItem = findContainerItem(storageContainer, def.fullType, itemId)
    if containerItem then
        return containerItem, storageContainer
    end

    storageContainer = getBikeStorageContainer(player, bikeItem)
    containerItem = findContainerItem(storageContainer, def.fullType, itemId)
    if containerItem then
        return containerItem, storageContainer
    end

    if not containerInfo then
        return nil, nil
    end
    if not containerInfo.itemId then
        return nil, nil
    end

    containerItem = findContainerItem(storageContainer, def.fullType, nil)
    if containerItem then
        return containerItem, storageContainer
    end

    return nil, nil
end

---@param bikeItem InventoryItem
---@param def BicycleContainerDefinition
---@param containerInfo table
---@param worldItem IsoWorldInventoryObject|nil
---@param destContainer ItemContainer|nil
---@return InventoryItem|nil
local function packWorldContainerIntoContainer(bikeItem, def, containerInfo, worldItem, destContainer)
    if not (bikeItem and def and containerInfo and worldItem and destContainer and worldItem.getItem) then
        return nil
    end

    local containerItem = worldItem:getItem()
    if not containerItem then
        return nil
    end

    detachWorldItemFromSquare(worldItem)
    addItemToContainer(destContainer, containerItem)
    storePackedContainerInfo(containerInfo, containerItem, destContainer, bikeItem:getID(), def.partType)
    return containerItem
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem
---@param def BicycleContainerDefinition
---@param containerInfo table
---@param sourceItem InventoryItem|nil
---@param sourceIsVanillaContainer boolean|nil
---@param destContainer ItemContainer|nil
---@return InventoryItem|nil
local function createPackedContainerForAttachment(
    player,
    bikeItem,
    def,
    containerInfo,
    sourceItem,
    sourceIsVanillaContainer,
    destContainer
)
    if not (bikeItem and def and containerInfo and destContainer) then
        return nil
    end

    local containerItem = instanceItem(def.fullType)
    if not containerItem then
        return nil
    end

    copyContainerVisuals(sourceItem, containerItem)
    addItemToContainer(destContainer, containerItem)
    storePackedContainerInfo(containerInfo, containerItem, destContainer, bikeItem:getID(), def.partType)

    if sourceIsVanillaContainer == true and sourceItem and sourceItem.getItemContainer then
        local srcContainer = sourceItem:getItemContainer()
        local destInner = nil
        if containerItem.getItemContainer then
            destInner = containerItem:getItemContainer()
        end
        if srcContainer and destInner then
            transferAllContainerItems(srcContainer, destInner, player)
        end
    end

    return containerItem
end

---@param player IsoPlayer|nil
---@param destContainer ItemContainer|nil
---@return boolean
---@nodiscard
local function isInternalPackedDestination(player, destContainer)
    if ContainerGuards.isAllowedInvisibleDestination(destContainer) then
        return true
    end

    return ContainerGuards.isPlayerInventory(destContainer, player)
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem
---@param partType string
---@param storageContainer ItemContainer|nil
local function syncPartContainerToStorage(player, bikeItem, partType, storageContainer)
    local def = CONTAINER_DEFS_BY_PART[partType]
    if not def then
        return
    end

    local containers = getBikeContainersModData(bikeItem)
    local containerInfo = containers[partType]
    local hasPart = bikeItem:getWeaponPart(partType) ~= nil

    if not hasPart then
        local worldItem = resolveDetachContainerWorldItem(bikeItem, partType, def, containerInfo, nil)
        if worldItem then
            local spillSquare = worldItem:getSquare()
            if not spillSquare and player then
                spillSquare = player:getSquare()
            end
            if not spillSquare then
                return
            end
            spillContainerContents(worldItem, spillSquare)
            clearContainerMarker(worldItem)
            removeManagedWorldItem(worldItem, spillSquare)
        end

        local packedItem, packedContainer = findPackedContainerForBike(player, bikeItem, def, containerInfo)
        if packedItem then
            local spillSquare = nil
            if player then
                spillSquare = player:getSquare()
            end
            if not spillSquare then
                return
            end
            spillContainerItemContents(packedItem, spillSquare)
            clearContainerItemMarker(packedItem)
            removeItemFromContainer(packedContainer, packedItem)
        end

        clearContainerInfo(containerInfo)
        containers[partType] = nil
        return
    end

    if not storageContainer then
        return
    end

    if not containerInfo then
        return
    end

    local packedItem, packedContainer = findPackedContainerForBike(player, bikeItem, def, containerInfo)
    if packedItem then
        if packedContainer ~= storageContainer then
            removeItemFromContainer(packedContainer, packedItem)
            addItemToContainer(storageContainer, packedItem)
        end
        storePackedContainerInfo(containerInfo, packedItem, storageContainer, bikeItem:getID(), partType)
        return
    end

    local worldItem = resolveDetachContainerWorldItem(bikeItem, partType, def, containerInfo, nil)
    if worldItem then
        packWorldContainerIntoContainer(bikeItem, def, containerInfo, worldItem, storageContainer)
    end
end

---@param bikeItem InventoryItem
---@param partType string
---@param targetSquare IsoGridSquare|nil
local function syncPartContainer(bikeItem, partType, targetSquare)
    local def = CONTAINER_DEFS_BY_PART[partType]
    if not def then
        return
    end

    local containers = getBikeContainersModData(bikeItem)
    local containerInfo = containers[partType]
    local hasPart = bikeItem:getWeaponPart(partType) ~= nil

    if not hasPart then
        local worldItem = resolveDetachContainerWorldItem(bikeItem, partType, def, containerInfo, targetSquare)
        if worldItem then
            local spillSquare = targetSquare or worldItem:getSquare()
            if not spillSquare and containerInfo and containerInfo.x and containerInfo.y and containerInfo.z then
                spillSquare = getSquare(containerInfo.x, containerInfo.y, containerInfo.z)
            end
            spillContainerContents(worldItem, spillSquare)
            clearContainerMarker(worldItem)
            removeManagedWorldItem(worldItem, spillSquare)
            clearContainerInfo(containerInfo)
            containers[partType] = nil
            return
        end

        if not containerInfo then
            containers[partType] = nil
            return
        end

        local hasCoordinates = containerInfo.x and containerInfo.y and containerInfo.z
        if not containerInfo.worldItem and not containerInfo.itemId and not hasCoordinates then
            clearContainerInfo(containerInfo)
            containers[partType] = nil
        end

        return
    end

    if not containerInfo then
        containerInfo = {}
        containers[partType] = containerInfo
    end

    local bikeItemId = bikeItem:getID()
    local fullType = def.fullType
    local worldItem = containerInfo.worldItem
    if not isMatchingWorldItem(worldItem, fullType, containerInfo.itemId) then
        worldItem = nil
    end

    if not worldItem and containerInfo.packed and targetSquare then
        worldItem = unpackStoredContainerToWorld(bikeItem, def, containerInfo, targetSquare)
    end

    if not worldItem and containerInfo.itemId and containerInfo.x and containerInfo.y and containerInfo.z then
        local knownSquare = getSquare(containerInfo.x, containerInfo.y, containerInfo.z)
        worldItem = findContainerOnSquare(knownSquare, fullType, containerInfo.itemId, bikeItemId, partType)
    end

    if not worldItem and targetSquare then
        worldItem = findContainerOnSquare(targetSquare, fullType, containerInfo.itemId, bikeItemId, partType)
    end

    if not worldItem and targetSquare then
        worldItem = findContainerNearSquare(targetSquare, fullType, containerInfo.itemId, bikeItemId, partType)
    end

    if not worldItem and targetSquare then
        worldItem = Manager.findOrAdoptContainer(targetSquare, fullType, bikeItemId, partType)
    end

    if not worldItem and targetSquare and not hasContainerTrackingData(containerInfo) then
        worldItem = spawnManagedContainer(targetSquare, fullType)
    end

    if not worldItem then
        return
    end

    if targetSquare and worldItem:getSquare() ~= targetSquare then
        worldItem = Manager.moveWorldItem(targetSquare, containerInfo, worldItem, bikeItemId, partType)
    end

    if worldItem then
        Manager.setContainerData(worldItem, containerInfo, bikeItemId, partType)
    end
end

---@param bikeItem InventoryItem|nil
local function cacheBikeLoad(bikeItem)
    if not (bikeItem and bikeItem.getModData and bikeItem.getWeaponPart) then
        return
    end

    local containers = getBikeContainersModData(bikeItem)
    local count = 0
    local weight = 0

    for i = 1, #CONTAINER_PART_TYPES do
        local partType = CONTAINER_PART_TYPES[i]
        if bikeItem:getWeaponPart(partType) then
            count = count + 1

            local info = containers[partType]
            local containerItem = nil
            if info then
                if info.worldItem and info.worldItem.getItem then
                    containerItem = info.worldItem:getItem()
                end
                if not containerItem and info.packed and info.storage and info.storage.container then
                    local def = CONTAINER_DEFS_BY_PART[partType]
                    if def then
                        containerItem = findContainerItem(info.storage.container, def.fullType, info.itemId)
                    end
                end
            end

            if containerItem and containerItem.getItemContainer then
                local sub = containerItem:getItemContainer()
                if sub then
                    weight = weight + sub:getContentsWeight()
                end
            end
        end
    end

    local md = bikeItem:getModData()
    local prev = md.BicycleLoad
    if prev and prev.count == count and math.abs((prev.weight or 0) - weight) <= 0.001 then
        return
    end

    md.BicycleLoad = { count = count, weight = weight }
    if bikeItem.transmitModData then
        bikeItem:transmitModData()
    end
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@param targetSquare IsoGridSquare|nil
---@param partTypeOrNil string|nil
function Manager.syncBikeContainers(player, bikeItem, targetSquare, partTypeOrNil)
    if not (player and bikeItem and BicycleUtils.isBicycleItem(bikeItem)) then
        return
    end

    local square = getBikeTrackingSquare(player, bikeItem)
    if not square then
        local storageContainer = getBikeStorageContainer(player, bikeItem)
        if partTypeOrNil then
            BicycleDebug.log(
                "syncBikeContainers packed bike=" .. BicycleDebug.describeItem(bikeItem)
                    .. ", partType=" .. tostring(partTypeOrNil)
            )
            syncPartContainerToStorage(player, bikeItem, partTypeOrNil, storageContainer)
        else
            for i = 1, #CONTAINER_PART_TYPES do
                syncPartContainerToStorage(player, bikeItem, CONTAINER_PART_TYPES[i], storageContainer)
            end
        end
        cacheBikeLoad(bikeItem)
        return
    end

    if partTypeOrNil then
        BicycleDebug.log(
            "syncBikeContainers bike=" .. BicycleDebug.describeItem(bikeItem)
                .. ", partType=" .. tostring(partTypeOrNil)
                .. ", square=" .. BicycleDebug.describeSquare(square)
        )
        syncPartContainer(bikeItem, partTypeOrNil, square)
    else
        for i = 1, #CONTAINER_PART_TYPES do
            syncPartContainer(bikeItem, CONTAINER_PART_TYPES[i], square)
        end
    end

    cacheBikeLoad(bikeItem)
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@param partType string|nil
---@param sourceItem InventoryItem|nil
---@param sourceIsVanillaContainer boolean|nil
---@param square IsoGridSquare|nil
function Manager.attachContainerPartNow(player, bikeItem, partType, sourceItem, sourceIsVanillaContainer, square)
    local def = nil
    if partType then
        def = CONTAINER_DEFS_BY_PART[partType]
    end
    if not (player and bikeItem and def and sourceItem) then
        BicycleDebug.log(
            "attachContainerPartNow aborted bike=" .. BicycleDebug.describeItem(bikeItem)
                .. ", partType=" .. tostring(partType)
                .. ", source=" .. BicycleDebug.describeItem(sourceItem)
        )
        return
    end

    local targetSquare = getBikeWorldSquare(bikeItem)

    BicycleDebug.log(
        "attachContainerPartNow bike=" .. BicycleDebug.describeItem(bikeItem)
            .. ", partType=" .. tostring(partType)
            .. ", source=" .. BicycleDebug.describeItem(sourceItem)
            .. ", sourceIsVanillaContainer=" .. tostring(sourceIsVanillaContainer)
            .. ", square=" .. BicycleDebug.describeSquare(targetSquare)
    )

    local containers = getBikeContainersModData(bikeItem)
    local containerInfo = containers[partType]
    if not containerInfo then
        containerInfo = {}
        containers[partType] = containerInfo
    end

    if not targetSquare then
        local storageContainer = getBikeStorageContainer(player, bikeItem)
        if not storageContainer then
            BicycleDebug.log("attachContainerPartNow no storage for bike=" .. BicycleDebug.describeItem(bikeItem))
            return
        end

        local packedItem = createPackedContainerForAttachment(
            player,
            bikeItem,
            def,
            containerInfo,
            sourceItem,
            sourceIsVanillaContainer,
            storageContainer
        )
        if packedItem then
            BicycleDebug.log(
                "attachContainerPartNow packed container=" .. BicycleDebug.describeItem(packedItem)
                    .. ", partType=" .. tostring(partType)
            )
            refreshInventories(player)
        end
        return
    end

    local bikeItemId = bikeItem:getID()
    local expectedItemId = containerInfo.itemId
    local worldItem = containerInfo.worldItem
    if not isMatchingWorldItem(worldItem, def.fullType, expectedItemId) then
        worldItem = nil
    end

    if not worldItem and containerInfo.itemId and containerInfo.x and containerInfo.y and containerInfo.z then
        local knownSquare = getSquare(containerInfo.x, containerInfo.y, containerInfo.z)
        worldItem = findContainerOnSquare(knownSquare, def.fullType, containerInfo.itemId, bikeItemId, partType)
    end

    if not worldItem then
        worldItem = findContainerOnSquare(targetSquare, def.fullType, expectedItemId, bikeItemId, partType)
    end

    if not worldItem then
        worldItem = findContainerNearSquare(targetSquare, def.fullType, expectedItemId, bikeItemId, partType)
    end

    if not worldItem then
        worldItem = Manager.findOrAdoptContainer(targetSquare, def.fullType, bikeItemId, partType)
    end

    if not worldItem then
        worldItem = spawnManagedContainer(targetSquare, def.fullType)
    end
    if not (worldItem and worldItem.getItem) then
        BicycleDebug.log("attachContainerPartNow failed to resolve world container for partType=" .. tostring(partType))
        return
    end

    if worldItem:getSquare() ~= targetSquare then
        worldItem = Manager.moveWorldItem(targetSquare, containerInfo, worldItem, bikeItemId, partType)
    end
    if not (worldItem and worldItem.getItem) then
        return
    end

    local containerItem = worldItem:getItem()
    if containerItem.setName and sourceItem.getDisplayName then
        containerItem:setName(sourceItem:getDisplayName())
    end
    if containerItem.setIcon and sourceItem.getIcon then
        containerItem:setIcon(sourceItem:getIcon())
    end

    local destContainer = nil
    if containerItem.getItemContainer then
        destContainer = containerItem:getItemContainer()
    end
    if not destContainer then
        return
    end

    Manager.setContainerData(worldItem, containerInfo, bikeItemId, partType)
    BicycleDebug.log(
        "attachContainerPartNow resolved world container=" .. BicycleDebug.describeItem(containerItem)
            .. ", square=" .. BicycleDebug.describeSquare(worldItem:getSquare())
    )
    if isServer() and containerItem.syncItemFields then
        containerItem:syncItemFields()
    end

    if sourceIsVanillaContainer == true and sourceItem.getItemContainer then
        local srcContainer = sourceItem:getItemContainer()
        if srcContainer then
            transferAllContainerItems(srcContainer, destContainer, player)
        end
    end
    refreshInventories(player)
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@param partType string|nil
---@param detachedItem InventoryItem|nil
---@param square IsoGridSquare|nil
function Manager.detachContainerPartNow(player, bikeItem, partType, detachedItem, square)
    local def = nil
    if partType then
        def = CONTAINER_DEFS_BY_PART[partType]
    end
    if not (player and bikeItem and def) then
        BicycleDebug.log(
            "detachContainerPartNow aborted bike=" .. BicycleDebug.describeItem(bikeItem)
                .. ", partType=" .. tostring(partType)
                .. ", detachedItem=" .. BicycleDebug.describeItem(detachedItem)
        )
        return
    end

    local containers = getBikeContainersModData(bikeItem)
    local containerInfo = containers[partType]
    if not containerInfo then
        return
    end

    local targetSquare = square or getTargetSquare(player, bikeItem)
    BicycleDebug.log(
        "detachContainerPartNow bike=" .. BicycleDebug.describeItem(bikeItem)
            .. ", partType=" .. tostring(partType)
            .. ", detachedItem=" .. BicycleDebug.describeItem(detachedItem)
            .. ", square=" .. BicycleDebug.describeSquare(targetSquare)
    )
    local worldItem = resolveDetachContainerWorldItem(
        bikeItem,
        partType,
        def,
        containerInfo,
        targetSquare
    )

    if worldItem and worldItem.getItem then
        local containerItem = worldItem:getItem()
        local srcContainer = nil
        if containerItem.getItemContainer then
            srcContainer = containerItem:getItemContainer()
        end
        if srcContainer then
            local destContainer = nil
            if detachedItem and detachedItem.getItemContainer then
                destContainer = detachedItem:getItemContainer()
            end
            if destContainer then
                transferAllContainerItems(srcContainer, destContainer, player)
            else
                local spillSquare = targetSquare or worldItem:getSquare()
                spillContainerContents(worldItem, spillSquare)
            end
        end

        clearContainerMarker(worldItem)
        removeManagedWorldItem(worldItem, targetSquare)
        BicycleDebug.log(
            "detachContainerPartNow removed world container square="
                .. BicycleDebug.describeSquare(worldItem:getSquare())
        )
    else
        local packedItem, packedContainer = findPackedContainerForBike(player, bikeItem, def, containerInfo)
        if packedItem then
            local srcContainer = nil
            if packedItem.getItemContainer then
                srcContainer = packedItem:getItemContainer()
            end
            if srcContainer then
                local destContainer = nil
                if detachedItem and detachedItem.getItemContainer then
                    destContainer = detachedItem:getItemContainer()
                end
                if destContainer then
                    transferAllContainerItems(srcContainer, destContainer, player)
                else
                    local spillSquare = targetSquare
                    if not spillSquare and player then
                        spillSquare = player:getSquare()
                    end
                    spillContainerItemContents(packedItem, spillSquare)
                end
            end

            clearContainerItemMarker(packedItem)
            removeItemFromContainer(packedContainer, packedItem)
            BicycleDebug.log(
                "detachContainerPartNow removed packed container=" .. BicycleDebug.describeItem(packedItem)
            )
        end
    end

    clearContainerInfo(containerInfo)
    containers[partType] = nil
    refreshInventories(player)
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem
---@param def BicycleContainerDefinition
---@param containerInfo table|nil
---@param srcContainer ItemContainer|nil
---@param destContainer ItemContainer|nil
local function packPartContainerIntoContainer(player, bikeItem, def, containerInfo, srcContainer, destContainer)
    if not destContainer then
        return
    end

    local expectedItemId = nil
    if containerInfo then
        expectedItemId = containerInfo.itemId
    end
    local containerItem = findContainerItem(srcContainer, def.fullType, expectedItemId)
    if containerItem and containerItem:getContainer() == srcContainer then
        if srcContainer == destContainer then
            storePackedContainerInfo(containerInfo, containerItem, destContainer, bikeItem:getID(), def.partType)
            return
        end

        removeItemFromContainer(srcContainer, containerItem)
    else
        local worldItem = resolveDetachContainerWorldItem(
            bikeItem,
            def.partType,
            def,
            containerInfo,
            getTargetSquare(player, bikeItem)
        )
        containerItem = nil
        if worldItem and worldItem.getItem then
            containerItem = worldItem:getItem()
        end
        if worldItem then
            detachWorldItemFromSquare(worldItem)
        end
    end

    if not containerItem then
        return
    end

    addItemToContainer(destContainer, containerItem)
    storePackedContainerInfo(containerInfo, containerItem, destContainer, bikeItem:getID(), def.partType)
end

---@param bikeItem InventoryItem
---@param def BicycleContainerDefinition
---@param containerInfo table|nil
---@param player IsoPlayer|nil
---@param srcContainer ItemContainer|nil
---@param dropSquare IsoGridSquare|nil
---@param destContainer ItemContainer|nil
local function unpackPartContainerFromContainer(bikeItem, def, containerInfo, player, srcContainer, dropSquare, destContainer)
    if not srcContainer then
        return
    end

    local expectedItemId = nil
    if containerInfo then
        expectedItemId = containerInfo.itemId
    end
    local containerItem = findContainerItem(srcContainer, def.fullType, expectedItemId)
    if not containerItem then
        containerItem = findContainerItem(srcContainer, def.fullType, nil)
    end
    if not (containerItem and containerItem:getContainer() == srcContainer) then
        return
    end

    if destContainer and isInternalPackedDestination(player, destContainer) then
        if srcContainer ~= destContainer then
            removeItemFromContainer(srcContainer, containerItem)
            addItemToContainer(destContainer, containerItem)
        end
        storePackedContainerInfo(containerInfo, containerItem, destContainer, bikeItem:getID(), def.partType)
        return
    end

    if not dropSquare then
        if containerInfo then
            containerInfo.storage = nil
        end
        return
    end

    removeItemFromContainer(srcContainer, containerItem)
    local worldItem = placeContainerItemOnSquare(dropSquare, containerItem)
    if not (worldItem and worldItem.getItem) then
        addItemToContainer(srcContainer, containerItem)
        if containerInfo then
            containerInfo.storage = nil
        end
        return
    end

    Manager.setContainerData(worldItem, containerInfo, bikeItem:getID(), def.partType)
    if containerInfo then
        containerInfo.packed = nil
        containerInfo.storage = nil
    end
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@param srcContainer ItemContainer|nil
---@param destContainer ItemContainer|nil
function Manager.transferBikeContainersToContainer(player, bikeItem, srcContainer, destContainer)
    if not (bikeItem and BicycleUtils.isBicycleItem(bikeItem) and destContainer) then
        return
    end

    if SidecarAnimal.bikeHasAnyAnimalPart(bikeItem) then
        if player then
            sendServerCommand(player, Bicycle.Core.SyncModule, "SidecarAnimalFailed", {
                reason = "animal_blocks_pack"
            })
        end
        return
    end

    local containers = getBikeContainersModData(bikeItem)
    for i = 1, #CONTAINER_PART_TYPES do
        local partType = CONTAINER_PART_TYPES[i]
        if bikeItem:getWeaponPart(partType) then
            local def = CONTAINER_DEFS_BY_PART[partType]
            local containerInfo = containers[partType]
            if not containerInfo then
                containerInfo = {}
                containers[partType] = containerInfo
            end
            packPartContainerIntoContainer(player, bikeItem, def, containerInfo, srcContainer, destContainer)
        end
    end

    refreshInventories(player)
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@param srcContainer ItemContainer|nil
---@param dropSquare IsoGridSquare|nil
---@param destContainer ItemContainer|nil
function Manager.transferBikeContainersFromContainer(player, bikeItem, srcContainer, dropSquare, destContainer)
    if not (bikeItem and BicycleUtils.isBicycleItem(bikeItem) and srcContainer) then
        return
    end

    if SidecarAnimal.bikeHasAnyAnimalPart(bikeItem) then
        if player then
            sendServerCommand(player, Bicycle.Core.SyncModule, "SidecarAnimalFailed", {
                reason = "animal_blocks_pack"
            })
        end
        return
    end

    local containers = getBikeContainersModData(bikeItem)
    for i = 1, #CONTAINER_PART_TYPES do
        local partType = CONTAINER_PART_TYPES[i]
        if bikeItem:getWeaponPart(partType) then
            local def = CONTAINER_DEFS_BY_PART[partType]
            local containerInfo = containers[partType]
            if containerInfo then
                unpackPartContainerFromContainer(
                    bikeItem,
                    def,
                    containerInfo,
                    player,
                    srcContainer,
                    dropSquare,
                    destContainer
                )
            end
        end
    end

    refreshInventories(player)
end

---@param item InventoryItem|nil
---@return BicycleContainerDefinition|nil
---@nodiscard
local function getContainerDefForItem(item)
    if not (item and item.getFullType) then
        return nil
    end

    return CONTAINER_DEFS_BY_FULL_TYPE[item:getFullType()]
end

---@param item InventoryItem|nil
---@return boolean
---@nodiscard
local function isContainerItemEmpty(item)
    if not (item and item.getItemContainer) then
        return true
    end

    local container = item:getItemContainer()
    if not container then
        return true
    end

    local items = container:getItems()
    if not items then
        return true
    end

    return items:size() == 0
end

---@param knownBikes table<number, InventoryItem>
---@param item InventoryItem|nil
local function rememberKnownBike(knownBikes, item)
    if not BicycleUtils.isBicycleItem(item) then
        return
    end
    if not item.getID then
        return
    end

    knownBikes[item:getID()] = item
end

---@param knownBikes table<number, InventoryItem>
---@param player IsoPlayer|nil
local function rememberCarriedBikes(knownBikes, player)
    if not player then
        return
    end

    local inventory = player:getInventory()
    if inventory then
        for i = 1, #BICYCLE_ITEM_TYPES do
            local items = inventory:getAllTypeRecurse(BICYCLE_ITEM_TYPES[i])
            for j = 0, items:size() - 1 do
                rememberKnownBike(knownBikes, items:get(j))
            end
        end
    end

    rememberKnownBike(knownBikes, player:getPrimaryHandItem())
    rememberKnownBike(knownBikes, player:getSecondaryHandItem())
end

---@return table<number, InventoryItem>
---@nodiscard
local function collectCarriedBikesAllPlayers()
    ---@type table<number, InventoryItem>
    local knownBikes = {}

    if isServer() then
        local onlinePlayers = getOnlinePlayers()
        if onlinePlayers then
            for i = 0, onlinePlayers:size() - 1 do
                rememberCarriedBikes(knownBikes, onlinePlayers:get(i))
            end
        end
    else
        local playerCount = getNumActivePlayers()
        for i = 0, playerCount - 1 do
            rememberCarriedBikes(knownBikes, getSpecificPlayer(i))
        end
    end

    return knownBikes
end

---@param worldItem IsoWorldInventoryObject|nil
---@param square IsoGridSquare|nil
local function spillAndRemoveHiddenWorldItem(worldItem, square)
    if not worldItem then
        return
    end

    local spillSquare = square or worldItem:getSquare()
    if not spillSquare then
        return
    end

    spillContainerContents(worldItem, spillSquare)
    clearContainerMarker(worldItem)
    removeManagedWorldItem(worldItem, spillSquare)
end

---@param worldItem IsoWorldInventoryObject
---@param def BicycleContainerDefinition
---@param player IsoPlayer|nil
---@param bikeItem InventoryItem
---@param partType string
local function relinkHiddenWorldItem(worldItem, def, player, bikeItem, partType)
    local containers = getBikeContainersModData(bikeItem)
    local containerInfo = containers[partType]
    if not containerInfo then
        containerInfo = {}
        containers[partType] = containerInfo
    end

    local bikeSquare = getBikeTrackingSquare(player, bikeItem)
    if bikeSquare then
        local movedWorldItem = worldItem
        if worldItem:getSquare() ~= bikeSquare then
            movedWorldItem = Manager.moveWorldItem(bikeSquare, containerInfo, worldItem, bikeItem:getID(), partType)
        end
        if movedWorldItem then
            Manager.setContainerData(movedWorldItem, containerInfo, bikeItem:getID(), partType)
        end
        return
    end

    local storageContainer = getBikeStorageContainer(player, bikeItem)
    if storageContainer then
        packWorldContainerIntoContainer(bikeItem, def, containerInfo, worldItem, storageContainer)
    end
end

---@param player IsoPlayer|nil
---@param worldItem IsoWorldInventoryObject
---@param def BicycleContainerDefinition
---@param knownBikes table<number, InventoryItem>
---@param claimedContainerKeys table<string, boolean>
---@param globalKnownBikes table<number, InventoryItem>|nil all online players' carried bikes; gates the spill terminal
local function cleanupHiddenContainerWorldItem(player, worldItem, def, knownBikes, claimedContainerKeys, globalKnownBikes)
    local item = worldItem:getItem()
    if not item then
        return
    end

    local marker = getContainerMarker(worldItem)
    if not marker then
        if isContainerItemEmpty(item) then
            removeManagedWorldItem(worldItem, worldItem:getSquare())
        end
        return
    end

    local bikeItemId = tonumber(marker.bikeItemId)
    local partType = marker.partType
    local bikeItem = nil
    if bikeItemId then
        bikeItem = knownBikes[bikeItemId]
    end

    local key = tostring(bikeItemId) .. ":" .. tostring(partType)
    if claimedContainerKeys[key] == true then
        return
    end

    if bikeItem and partType == def.partType and bikeItem:getWeaponPart(partType) then
        claimedContainerKeys[key] = true
        relinkHiddenWorldItem(worldItem, def, player, bikeItem, partType)
        return
    end

    if bikeItem then
        clearContainerMarker(worldItem)
        return
    end

    if bikeItemId and globalKnownBikes and globalKnownBikes[bikeItemId] then
        return
    end

    spillAndRemoveHiddenWorldItem(worldItem, worldItem:getSquare())
end

---@param square IsoGridSquare|nil
---@param knownBikes table<number, InventoryItem>
local function rememberWorldBikesOnSquare(square, knownBikes)
    if not (square and square.getWorldObjects) then
        return
    end

    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local worldObj = worldObjects:get(i)
        local item = nil
        if worldObj and worldObj.getItem then
            item = worldObj:getItem()
        end
        rememberKnownBike(knownBikes, item)
    end
end

---@param square IsoGridSquare|nil
---@return table[]
---@nodiscard
local function copyHiddenContainerWorldItems(square)
    local out = {}
    if not (square and square.getWorldObjects) then
        return out
    end

    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local worldObj = worldObjects:get(i)
        local item = nil
        if worldObj and worldObj.getItem then
            item = worldObj:getItem()
        end
        local def = getContainerDefForItem(item)
        if worldObj and def then
            out[#out + 1] = {
                worldItem = worldObj,
                def = def,
            }
        end
    end

    return out
end

---@param player IsoPlayer|nil
---@param centerSquare IsoGridSquare|nil
---@param knownBikes table<number, InventoryItem>
---@param globalKnownBikes table<number, InventoryItem>|nil all online players' carried bikes; gates the spill terminal
local function cleanupLeakedHiddenContainers(player, centerSquare, knownBikes, globalKnownBikes)
    if not centerSquare then
        return
    end

    local x = centerSquare:getX()
    local y = centerSquare:getY()
    local z = centerSquare:getZ()

    for dx = -1, 1 do
        for dy = -1, 1 do
            rememberWorldBikesOnSquare(getSquare(x + dx, y + dy, z), knownBikes)
        end
    end

    ---@type table<string, boolean>
    local claimedContainerKeys = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            local square = getSquare(x + dx, y + dy, z)
            local hiddenItems = copyHiddenContainerWorldItems(square)
            for i = 1, #hiddenItems do
                local entry = hiddenItems[i]
                cleanupHiddenContainerWorldItem(
                    player,
                    entry.worldItem,
                    entry.def,
                    knownBikes,
                    claimedContainerKeys,
                    globalKnownBikes
                )
            end
        end
    end
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@return InventoryItem|nil
---@nodiscard
function Manager.findSidecarContainerItem(player, bikeItem)
    if not (bikeItem and BicycleUtils.isBicycleItem(bikeItem)) then
        return nil
    end

    local def = CONTAINER_DEFS_BY_PART["Sidecar"]
    if not def then
        return nil
    end

    local containers = getBikeContainersModData(bikeItem)
    local containerInfo = containers["Sidecar"]
    local targetSquare = getTargetSquare(player, bikeItem)

    local worldItem = resolveDetachContainerWorldItem(bikeItem, "Sidecar", def, containerInfo, targetSquare)
    if worldItem and worldItem.getItem then
        local item = worldItem:getItem()
        if item and item:getFullType() == def.fullType then
            return item
        end
    end

    local packedItem = findPackedContainerForBike(player, bikeItem, def, containerInfo)
    if packedItem and packedItem:getFullType() == def.fullType then
        return packedItem
    end

    return nil
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@param partType string|nil
---@param accessory InventoryItem|nil
function Manager.initContainer(player, bikeItem, partType, accessory)
    Manager.attachContainerPartNow(
        player,
        bikeItem,
        partType,
        accessory,
        accessory and accessory.getItemContainer ~= nil,
        nil
    )
end

---@param player IsoPlayer|nil
---@param bikeItem InventoryItem|nil
---@param partType string|nil
---@param accessory InventoryItem|nil
function Manager.removeContainer(player, bikeItem, partType, accessory)
    Manager.detachContainerPartNow(player, bikeItem, partType, accessory, nil)
end

---@param player IsoPlayer
---@param item InventoryItem|nil
---@param square IsoGridSquare
---@param seenItems table<InventoryItem, boolean>
---@param knownBikes table<number, InventoryItem>
local function syncTrackedBikeItem(player, item, square, seenItems, knownBikes)
    if not item then
        return
    end
    rememberKnownBike(knownBikes, item)
    if seenItems[item] then
        return
    end

    seenItems[item] = true
    if BicycleUtils.isBicycleItem(item) then
        Manager.syncBikeContainers(player, item, square, nil)
    end
end

---@param player IsoPlayer
---@param container ItemContainer
---@param square IsoGridSquare
---@param seenItems table<InventoryItem, boolean>
---@param knownBikes table<number, InventoryItem>
local function syncInventoryBikeItems(player, container, square, seenItems, knownBikes)
    for i = 1, #BICYCLE_ITEM_TYPES do
        local items = container:getAllTypeRecurse(BICYCLE_ITEM_TYPES[i])
        for j = 0, items:size() - 1 do
            syncTrackedBikeItem(player, items:get(j), square, seenItems, knownBikes)
        end
    end
end

---@param player IsoPlayer
---@param centerSquare IsoGridSquare
---@param seenItems table<InventoryItem, boolean>
---@param knownBikes table<number, InventoryItem>
local function syncWorldBikesAround(player, centerSquare, seenItems, knownBikes)
    if not (player and centerSquare) then
        return
    end

    local x = centerSquare:getX()
    local y = centerSquare:getY()
    local z = centerSquare:getZ()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local square = getSquare(x + dx, y + dy, z)
            if square and square.getWorldObjects then
                local worldObjects = square:getWorldObjects()
                for i = 0, worldObjects:size() - 1 do
                    local worldObj = worldObjects:get(i)
                    if worldObj and worldObj.getItem then
                        local item = worldObj:getItem()
                        if item and BicycleUtils.isBicycleItem(item) then
                            syncTrackedBikeItem(player, item, square, seenItems, knownBikes)
                        end
                    end
                end
            end
        end
    end
end

---@param player IsoPlayer|nil
---@param globalKnownBikes table<number, InventoryItem>|nil all online players' carried bikes; built on demand when omitted
function Manager.trackPlayerBikes(player, globalKnownBikes)
    if not player then
        return
    end

    local square = player:getSquare()
    if not square then
        return
    end

    if not globalKnownBikes then
        globalKnownBikes = collectCarriedBikesAllPlayers()
    end

    ---@type table<InventoryItem, boolean>
    local seenItems = {}
    ---@type table<number, InventoryItem>
    local knownBikes = {}
    syncInventoryBikeItems(player, player:getInventory(), square, seenItems, knownBikes)
    syncTrackedBikeItem(player, player:getPrimaryHandItem(), square, seenItems, knownBikes)
    syncTrackedBikeItem(player, player:getSecondaryHandItem(), square, seenItems, knownBikes)
    syncWorldBikesAround(player, square, seenItems, knownBikes)
    cleanupLeakedHiddenContainers(player, square, knownBikes, globalKnownBikes)
end

local TRACK_UPDATE_INTERVAL = 5
local TRACK_FORCE_REFRESH_PASSES = 12
local trackTick = 0
local trackPass = 0
---@type table<IsoPlayer, table>
local playerTrackStates = {}

---@param player IsoPlayer|nil
---@return boolean
local function shouldTrackPlayer(player)
    if not player then
        return false
    end

    local square = player:getSquare()
    if not square then
        return false
    end

    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    local state = playerTrackStates[player]
    if not state then
        playerTrackStates[player] = {
            x = x,
            y = y,
            z = z,
            pass = trackPass,
        }
        return true
    end

    if state.x ~= x or state.y ~= y or state.z ~= z then
        state.x = x
        state.y = y
        state.z = z
        state.pass = trackPass
        return true
    end

    if trackPass - state.pass >= TRACK_FORCE_REFRESH_PASSES then
        state.pass = trackPass
        return true
    end

    return false
end

local function onTick()
    trackTick = trackTick + 1
    if trackTick < TRACK_UPDATE_INTERVAL then
        return
    end
    trackTick = 0
    trackPass = trackPass + 1

    if isClient() then
        return
    end

    local carriedBikes = collectCarriedBikesAllPlayers()

    if isServer() then
        local onlinePlayers = getOnlinePlayers()
        if not onlinePlayers then
            return
        end

        for i = 0, onlinePlayers:size() - 1 do
            local player = onlinePlayers:get(i)
            if shouldTrackPlayer(player) then
                Manager.trackPlayerBikes(player, carriedBikes)
            end
        end
    else
        local playerCount = getNumActivePlayers()
        for i = 0, playerCount - 1 do
            local player = getSpecificPlayer(i)
            if shouldTrackPlayer(player) then
                Manager.trackPlayerBikes(player, carriedBikes)
            end
        end
    end
end

Events.OnTick.Add(onTick)

return Manager
