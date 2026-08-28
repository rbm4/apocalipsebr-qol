require("Bicycle/BicycleCore")
require("ISUI/ISInventoryPaneContextMenu")

local AttachmentActionUtils = require("Bicycle/AttachmentActionUtils")
local BicycleAttachPartAction = require("Bicycle/TimedAction/BicycleAttachPartAction")
local ContainerGuards = require("Bicycle/ContainerGuards")
local BicycleContainers = require("Bicycle/Containers")
local BicycleDismountBehavior = require("Bicycle/DismountBehavior")
local BicycleOptions = require("Bicycle/BicycleOptions")
local BicyclePartAttachmentService = require("Bicycle/PartAttachmentService")
local BicycleUtils = require("Bicycle/Utils")
local BicycleVanillaPartMapping = require("Bicycle/VanillaPartMapping")
local SidecarAnimal = require("Bicycle/SidecarAnimal")
require("Foraging/ISSearchManager")

local HAND_TORCH_FULL_TYPE = "Base.HandTorch"
local CRAFTED_FLASHLIGHT_FULL_TYPE = "Base.Flashlight_Crafted"
local DUCT_TAPE_FULL_TYPE = "Base.DuctTape"
local DUCT_TAPE_USAGE = 0.1
local SPORTS_BOTTLE_WATER_KEY = "BicycleSportsbottleWater"
local SPORTS_BOTTLE_CAPACITY = 1.0

---@type table<string, boolean>
local PLASTIC_BAG_PARTS = {
    PlasticBagLeft = true,
    PlasticBagRight = true,
}

---@type table<string, BicycleContainerDefinition>
local CONTAINER_TYPES = {}
for _, definition in ipairs(BicycleContainers.getDefinitions()) do
    CONTAINER_TYPES[definition.partType] = definition
end

local CONTAINER_TYPES_BY_ITEM = {}
for _, definition in pairs(CONTAINER_TYPES) do
    CONTAINER_TYPES_BY_ITEM[definition.itemType] = definition
end

---@param partType string|nil
---@return boolean
---@nodiscard
local function isPlasticBagPartType(partType)
    return partType and PLASTIC_BAG_PARTS[partType] == true
end

BicycleAttachments = BicycleAttachments or {}
BicycleAttachments.DUCT_TAPE_USAGE = DUCT_TAPE_USAGE
BicycleAttachments.isPlasticBagPartType = isPlasticBagPartType

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@param srcContainer ItemContainer|nil
---@param destContainer ItemContainer|nil
---@param square IsoGridSquare|nil
---@param prefix string
local function addSerializedContainerRef(player, payload, prefix, container)
    if not (payload and prefix) then
        return
    end

    if ContainerGuards.isVehicleTrunkContainer(container) then
        local part = container and container.getVehiclePart and container:getVehiclePart() or nil
        local vehicle = part and part.getVehicle and part:getVehicle() or nil
        if vehicle and part and vehicle.getId then
            payload[prefix .. "Kind"] = "vehicle"
            payload[prefix .. "VehicleId"] = vehicle:getId()
            payload[prefix .. "PartId"] = part:getId()
        end
        return
    end

    if ContainerGuards.isPlayerInventory(container, player) then
        payload[prefix .. "Kind"] = "player"
        return
    end

    if container and container.getType and container:getType() == "floor" then
        payload[prefix .. "Kind"] = "floor"
    end
end

local function requestServerBikeContainerTransfer(player, bikeItem, srcContainer, destContainer, square)
    if not (player and bikeItem and sendClientCommand) then
        return
    end

    local payload = {
        itemId = bikeItem:getID(),
    }
    addSerializedContainerRef(player, payload, "src", srcContainer)
    addSerializedContainerRef(player, payload, "dest", destContainer)
    if square then
        payload.x = square:getX()
        payload.y = square:getY()
        payload.z = square:getZ()
    end

    sendClientCommand(player, Bicycle.Core.SyncModule, "TransferBikeContainers", payload)
end

---@param bikeItem InventoryItem|nil
---@param partType string|nil
---@param square IsoGridSquare|nil
local function requestServerContainerSync(bikeItem, partType, square)
    if not (bikeItem and bikeItem.getID) then
        return
    end
    if not (Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.requestTransferContainer) then
        return
    end
    Bicycle.ClientSync.requestTransferContainer(bikeItem:getID(), partType, square)
end

---@param player IsoPlayer|IsoGameCharacter|nil
local function refreshPlayerInventories(player)
    if not player then
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

---@param itemOrWorld InventoryItem|IsoWorldInventoryObject|nil
---@return InventoryItem|nil
---@nodiscard
local function getBikeItem(itemOrWorld)
    if not itemOrWorld then
        return nil
    end
    if instanceof(itemOrWorld, "IsoWorldInventoryObject") then
        return itemOrWorld:getItem()
    end
    return itemOrWorld
end

---@param bikeItem InventoryItem|IsoWorldInventoryObject|nil
---@return table|nil
local function getBikeModData(bikeItem)
    bikeItem = getBikeItem(bikeItem)
    if not (bikeItem and bikeItem.getModData) then
        return nil
    end
    local md = bikeItem:getModData()
    md.BicycleContainers = md.BicycleContainers or {}
    return md.BicycleContainers
end

---@param bikeItem InventoryItem|IsoWorldInventoryObject|nil
---@param key string
---@return table|nil
local function getContainerData(bikeItem, key)
    local md = getBikeModData(bikeItem)
    if not md then
        return nil
    end
    md[key] = md[key] or {}
    return md[key]
end

---@param x number
---@param y number
---@param z number
---@return IsoGridSquare|nil
---@return ArrayList|nil
local function getWorldInventoryObjectsAt(x, y, z)
    local cell = getCell and getCell()
    if not cell then
        return nil, nil
    end
    local square = cell:getGridSquare(math.floor(x), math.floor(y), z)
    return square, square and square:getWorldObjects() or nil
end

---@param x number
---@param y number
---@param z number
---@param fullType string
---@param wantId number|nil
---@return IsoWorldInventoryObject|nil
---@return IsoGridSquare|nil
local function findWorldItemOnSquare(x, y, z, fullType, wantId)
    local square, list = getWorldInventoryObjectsAt(x, y, z)
    if not list then
        return nil, square
    end
    for i = 0, list:size() - 1 do
        local worldObject = list:get(i)
        if worldObject and worldObject.getItem then
            local item = worldObject:getItem()
            if item and item:getFullType() == fullType then
                if not wantId or (item.getID and item:getID() == wantId) then
                    return worldObject, square
                end
            end
        end
    end
    return nil, square
end

---@param square IsoGridSquare|nil
---@param fullType string
---@return IsoWorldInventoryObject|nil
---@return IsoGridSquare|nil
local function adoptNearbyWorldItem(square, fullType)
    if not square then
        return nil, nil
    end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local worldObject, foundSquare = findWorldItemOnSquare(x + dx, y + dy, z, fullType, nil)
            if worldObject then
                return worldObject, foundSquare
            end
        end
    end
    return nil, square
end

---@param data table|nil
---@param worldObj IsoWorldInventoryObject|nil
local function setDataForWorldObject(data, worldObj)
    if not (data and worldObj) then
        return
    end
    local square = worldObj:getSquare()
    if square then
        data.x, data.y, data.z = square:getX(), square:getY(), square:getZ()
    end
    local item = worldObj:getItem()
    if item and item.getID then
        data.itemId = item:getID()
    else
        data.itemId = nil
    end
    data.packed = nil
end

---@param data table|nil
local function clearContainerData(data)
    if not data then
        return
    end
    data.x, data.y, data.z = nil, nil, nil
    data.itemId = nil
    data.packed = nil
    data.storage = nil
end

---@param data table|nil
---@return boolean
---@nodiscard
local function hasContainerTrackingData(data)
    if not data then
        return false
    end
    if data.itemId then
        return true
    end
    if data.x and data.y and data.z then
        return true
    end
    if data.packed then
        return true
    end
    return false
end

---@param value number
---@return number
---@nodiscard
local function clamp01(value)
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

---@param item InventoryItem|nil
---@param amount number|nil
---@return number
---@nodiscard
local function clampSportsbottleWaterAmount(item, amount)
    if not amount then
        return 0
    end
    local maxAmount = SPORTS_BOTTLE_CAPACITY
    if item and item.getFluidContainer then
        local fluidContainer = item:getFluidContainer()
        if fluidContainer and fluidContainer.getCapacity then
            maxAmount = fluidContainer:getCapacity()
        end
    end
    return math.max(0, math.min(amount, maxAmount or SPORTS_BOTTLE_CAPACITY))
end

---@param item InventoryItem|nil
---@param amount number|nil
---@return number
local function setSportsbottleWaterModData(item, amount)
    if not (item and item.getModData) then
        return 0
    end
    local clamped = clampSportsbottleWaterAmount(item, amount or 0)
    local md = item:getModData()
    md[SPORTS_BOTTLE_WATER_KEY] = clamped
    if item.transmitModData then
        item:transmitModData()
    end
    return clamped
end

---@param item InventoryItem|nil
---@return number
---@nodiscard
local function getSportsbottleWaterAmountFromModData(item)
    if not (item and item.getModData) then
        return 0
    end
    local md = item:getModData()
    local stored = tonumber(md[SPORTS_BOTTLE_WATER_KEY]) or 0
    return clampSportsbottleWaterAmount(item, stored)
end

---@param part InventoryItem|nil
---@param vanillaSportsbottle InventoryItem|nil
---@return number
local function copyWaterToModData(part, vanillaSportsbottle)
    if not part then
        return 0
    end
    local amount = 0
    if vanillaSportsbottle and vanillaSportsbottle.getFluidContainer then
        local fluidContainer = vanillaSportsbottle:getFluidContainer()
        if fluidContainer and fluidContainer.getAmount then
            amount = fluidContainer:getAmount()
        end
    end
    return setSportsbottleWaterModData(part, amount)
end

---@param vanillaSportsbottle InventoryItem|nil
---@param amount number|nil
local function applyWaterAmountToVanillaSportsbottle(vanillaSportsbottle, amount)
    if not (vanillaSportsbottle and vanillaSportsbottle.getFluidContainer) then
        return
    end
    local fluidContainer = vanillaSportsbottle:getFluidContainer()
    if not fluidContainer then
        return
    end

    local clamped = clampSportsbottleWaterAmount(vanillaSportsbottle, amount or 0)
    if fluidContainer.Empty then
        fluidContainer:Empty()
    end

    if clamped <= 0 then
        return
    end

    if Fluid and Fluid.Water and fluidContainer.addFluid then
        fluidContainer:addFluid(Fluid.Water, clamped)
    elseif fluidContainer.adjustAmount then
        fluidContainer:adjustAmount(clamped)
    end
end

---@param worldObj IsoWorldInventoryObject|nil
---@param destSquare IsoGridSquare|nil
---@return IsoWorldInventoryObject|nil
local function moveWorldObjectToSquare(worldObj, destSquare)
    if not (worldObj and destSquare) then
        return worldObj
    end
    local item = worldObj:getItem()
    if not item then
        return worldObj
    end
    if worldObj.removeFromSquare then
        worldObj:removeFromSquare()
    end
    if worldObj.removeFromWorld then
        worldObj:removeFromWorld()
    end
    destSquare:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
    return item:getWorldItem() or worldObj
end

---@param fullType string|nil
---@param square IsoGridSquare|nil
---@return IsoWorldInventoryObject|nil
local function spawnContainerOnSquare(fullType, square)
    if not (fullType and square) then
        return nil
    end
    local item = square:AddWorldInventoryItem(fullType, 0.0, 0.0, 0.0)
    if not item then
        return nil
    end
    return item:getWorldItem()
end

---@param worldObj IsoWorldInventoryObject|nil
---@param destContainer ItemContainer|nil
---@return InventoryItem|nil
local function takeWorldObjectToContainer(worldObj, destContainer)
    if not (worldObj and destContainer and destContainer.AddItem) then
        return nil
    end
    local item = worldObj:getItem()
    if not item then
        return nil
    end
    if worldObj.removeFromSquare then
        worldObj:removeFromSquare()
    end
    if worldObj.removeFromWorld then
        worldObj:removeFromWorld()
    end
    destContainer:AddItem(item)
    return item
end

---@param container ItemContainer|nil
---@param fullType string
---@return InventoryItem|nil
local function findItemInContainer(container, fullType)
    if not container then
        return nil
    end
    if container.FindAndReturn then
        local found = container:FindAndReturn(fullType)
        if found then
            return found
        end
    end
    local items = container:getItems()
    if not items then
        return nil
    end
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it:getFullType() == fullType then
            return it
        end
    end
    return nil
end

---@param bikeItem InventoryItem|nil
---@param def BicycleContainerDefinition
---@param owner IsoPlayer|IsoGameCharacter|nil
---@return InventoryItem|nil
local function findPackedContainerItem(bikeItem, def, owner)
    local data = getContainerData(bikeItem, def.partType)
    if not (data and data.packed) then
        return nil
    end
    local item
    if owner and owner.getInventory then
        item = findItemInContainer(owner:getInventory(), def.fullType)
        if item then
            return item
        end
    end
    if data.storage and data.storage.container and data.storage.container.getItems then
        item = findItemInContainer(data.storage.container, def.fullType)
        if item then
            return item
        end
    end
    return nil
end

---@param bikeItem InventoryItem|nil
---@param partType string
---@return boolean
---@nodiscard
local function bikeHasPart(bikeItem, partType)
    if not (bikeItem and bikeItem.getWeaponPart) then
        return false
    end
    return bikeItem:getWeaponPart(partType) ~= nil
end

---@param bikeItem InventoryItem|nil
---@return boolean
---@nodiscard
local function bikeHasLamp(bikeItem)
    return bikeHasPart(bikeItem, "Lamp")
end

---@param bikeItem InventoryItem|nil
---@return string|nil
---@nodiscard
local function getMissingPlasticBagPartType(bikeItem)
    if not bikeItem then
        return nil
    end
    if not bikeHasPart(bikeItem, "PlasticBagLeft") then
        return "PlasticBagLeft"
    end
    if not bikeHasPart(bikeItem, "PlasticBagRight") then
        return "PlasticBagRight"
    end
    return nil
end

---@param container ItemContainer|nil
---@return InventoryItem[]
---@nodiscard
local function copyItemsToTable(container)
    local out = {}
    if not container then
        return out
    end
    local items = container:getItems()
    if not items then
        return out
    end
    for i = 0, items:size() - 1 do
        table.insert(out, items:get(i))
    end
    return out
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param srcContainer ItemContainer|nil
---@param dstContainer ItemContainer|nil
---@param dropSquare IsoGridSquare|nil
local function transferAllItems(character, srcContainer, dstContainer, dropSquare)
    if not (srcContainer and dstContainer) then
        return
    end
    local toMove = copyItemsToTable(srcContainer)
    for i = 1, #toMove do
        local item = toMove[i]
        if item and item:getContainer() == srcContainer then
            if ISTransferAction and ISTransferAction.transferItem then
                ISTransferAction:transferItem(character, item, srcContainer, dstContainer, dropSquare)
            else
                srcContainer:DoRemoveItem(item)
                dstContainer:AddItem(item)
            end
        end
    end
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param vanillaBag InventoryItem|nil
---@param containerItem InventoryItem|nil
---@param dropSquare IsoGridSquare|nil
local function transferVanillaBagToContainer(player, vanillaBag, containerItem, dropSquare)
    if not (vanillaBag and containerItem and containerItem.getInventory) then
        return
    end
    local vanillaBagInventory = vanillaBag:getInventory()
    local containerInventory = containerItem:getInventory()
    transferAllItems(player, vanillaBagInventory, containerInventory, dropSquare)
    BicycleUtils.removeItemFromContainer(vanillaBag)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param vanillaToolbox InventoryItem|nil
---@param containerItem InventoryItem|nil
---@param dropSquare IsoGridSquare|nil
local function transferVanillaToolboxToContainer(player, vanillaToolbox, containerItem, dropSquare)
    if not (vanillaToolbox and containerItem and containerItem.getInventory) then
        return
    end
    local toolboxInventory = vanillaToolbox:getInventory()
    local containerInventory = containerItem:getInventory()
    transferAllItems(player, toolboxInventory, containerInventory, dropSquare)
    BicycleUtils.removeItemFromContainer(vanillaToolbox)
end

---@param inv ItemContainer|nil
---@return InventoryItem|nil
---@nodiscard
local function findDuctTapeWithCharges(inv)
    if not inv then
        return nil
    end
    local ductTape = inv:getFirstTypeRecurse(DUCT_TAPE_FULL_TYPE)
    if ductTape and ductTape.getCurrentUsesFloat and ductTape:getCurrentUsesFloat() >= DUCT_TAPE_USAGE then
        return ductTape
    end
    return nil
end

---@param data table|nil
---@param container ItemContainer|nil
---@return table
local function storePackedLocation(data, container)
    data = data or {}
    data.packed = true
    data.x, data.y, data.z = nil, nil, nil
    data.itemId = nil
    data.storage = data.storage or {}
    data.storage.container = container
    return data
end

---@param bikeItem InventoryItem|nil
---@param def BicycleContainerDefinition
---@param square IsoGridSquare|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param allowSpawn boolean|nil
---@return IsoWorldInventoryObject|nil
local function ensureWorldContainer(bikeItem, def, square, player, allowSpawn)
    if not (bikeItem and def) then
        return nil
    end
    local data = getContainerData(bikeItem, def.partType)
    if not data then
        return nil
    end
    local worldObj
    if data.itemId and data.x and data.y and data.z then
        worldObj = select(1, findWorldItemOnSquare(data.x, data.y, data.z, def.fullType, data.itemId))
    end
    if not worldObj and square then
        worldObj = select(1, findWorldItemOnSquare(square:getX(), square:getY(), square:getZ(), def.fullType, data.itemId))
    end
    if not worldObj then
        worldObj = select(1, adoptNearbyWorldItem(square, def.fullType))
    end
    if not worldObj and data.packed and player then
        local packedItem = findPackedContainerItem(bikeItem, def, player)
        if packedItem and square then
            BicycleUtils.removeItemFromContainer(packedItem)
            square:AddWorldInventoryItem(packedItem, 0.0, 0.0, 0.0)
            worldObj = packedItem:getWorldItem()
        end
    end
    if not worldObj and allowSpawn and square and not hasContainerTrackingData(data) then
        worldObj = spawnContainerOnSquare(def.fullType, square)
    end
    if worldObj then
        setDataForWorldObject(data, worldObj)
    end
    return worldObj
end

---@param bikeItem InventoryItem|nil
---@param def BicycleContainerDefinition
---@param square IsoGridSquare|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param allowSpawn boolean|nil
---@return IsoWorldInventoryObject|nil
local function ensureWorldContainerOnSquare(bikeItem, def, square, player, allowSpawn)
    local worldObj = ensureWorldContainer(bikeItem, def, square, player, allowSpawn)
    if worldObj and square and worldObj.getSquare and worldObj:getSquare() ~= square then
        worldObj = moveWorldObjectToSquare(worldObj, square)
    end
    return worldObj
end

---@param bikeItem InventoryItem|nil
---@param def BicycleContainerDefinition
---@param square IsoGridSquare|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@return IsoWorldInventoryObject|nil
local function spawnOrAdoptContainer(bikeItem, def, square, player)
    local worldObj = ensureWorldContainer(bikeItem, def, square, player, true)
    if worldObj and square then
        return moveWorldObjectToSquare(worldObj, square)
    end
    return worldObj
end

---@param bikeItem InventoryItem|nil
---@param def BicycleContainerDefinition
---@param square IsoGridSquare|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@return IsoWorldInventoryObject|nil
local function findOrSpawnContainer(bikeItem, def, square, player)
    local worldObj = ensureWorldContainer(bikeItem, def, square, player, false)
    if worldObj then
        return worldObj
    end
    return spawnOrAdoptContainer(bikeItem, def, square, player)
end

---@param bikeItem InventoryItem|nil
---@param def BicycleContainerDefinition
---@param square IsoGridSquare|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param allowSpawn boolean|nil
---@return InventoryItem|nil
local function ensureContainerInInventory(bikeItem, def, square, player, allowSpawn)
    if not (player and def) then
        return nil
    end

    local data = getContainerData(bikeItem, def.partType)
    if data and data.packed then
        local packedItem = findPackedContainerItem(bikeItem, def, player)
        if packedItem then
            return packedItem
        end
    end

    if not allowSpawn then
        return nil
    end

    local worldObj = findOrSpawnContainer(bikeItem, def, square, player)
    if not worldObj then
        return nil
    end

    local item = takeWorldObjectToContainer(worldObj, player:getInventory())
    if item then
        storePackedLocation(data, player:getInventory())
    end

    return item
end

---@param bikeItem InventoryItem|nil
---@param def BicycleContainerDefinition
---@param square IsoGridSquare|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param allowSpawn boolean|nil
---@return InventoryItem|nil
local function ensureContainerOnSquare(bikeItem, def, square, player, allowSpawn)
    local worldObj = ensureWorldContainerOnSquare(bikeItem, def, square, player, allowSpawn)
    if not worldObj then
        return nil
    end

    return worldObj:getItem()
end

---@param bikeItem InventoryItem|nil
---@param def BicycleContainerDefinition
---@param square IsoGridSquare|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param allowSpawn boolean|nil
---@return InventoryItem|nil
local function ensureContainerOnSquareOrInventory(bikeItem, def, square, player, allowSpawn)
    local item = ensureContainerOnSquare(bikeItem, def, square, player, allowSpawn)
    if item then
        return item
    end

    return ensureContainerInInventory(bikeItem, def, square, player, allowSpawn)
end

---@param player IsoPlayer|IsoGameCharacter
---@param bikeItem InventoryItem
---@param dismountData table|nil
function BicycleAttachments.onBikeDropped(player, bikeItem, dismountData)
    local dropSquare = bikeItem.getWorldItem and bikeItem:getWorldItem() and bikeItem:getWorldItem():getSquare() or nil
    if not dropSquare then
        dropSquare = player:getSquare()
    end

    if isClient() then
        requestServerContainerSync(bikeItem, nil, dropSquare)
    elseif isServer() then
    else
        for _, def in pairs(CONTAINER_TYPES) do
            local part = bikeItem:getWeaponPart(def.partType)
            if part then
                ensureContainerOnSquareOrInventory(bikeItem, def, dropSquare, player, true)
            end
        end
    end

    BicycleDismountBehavior.applyDroppedBikeTransform(player, bikeItem, dismountData)
    if dismountData and dismountData.kickstandDown ~= nil then
        local targetState = dismountData.kickstandDown and "down" or "up"
        BicycleDismountBehavior.ensureKickstandState(bikeItem, player, targetState)
    end
    refreshPlayerInventories(player)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
function BicycleAttachments.followPlayer(player, bikeItem)
    if not (player and bikeItem) then
        return
    end
    if isClient() then
        return
    elseif isServer() then
        return
    else
        return
    end
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
function BicycleAttachments.dropContainers(bikeItem, player)
    if not bikeItem then
        return
    end

    local worldObj = bikeItem.getWorldItem and bikeItem:getWorldItem() or nil
    local square = worldObj and worldObj.getSquare and worldObj:getSquare() or nil
    if not square and player then
        square = player:getSquare()
    end

    if isClient() then
        requestServerContainerSync(bikeItem, nil, square)
        return
    elseif isServer() then
        return
    else
        for _, def in pairs(CONTAINER_TYPES) do
            if bikeItem:getWeaponPart(def.partType) then
                ensureContainerOnSquare(bikeItem, def, square, player, true)
            end
        end
    end
end

---@param player IsoPlayer|IsoGameCharacter
---@param bikeItem InventoryItem
---@param partType string
function BicycleAttachments.onAttachmentRemoved(player, bikeItem, partType)
    local def = CONTAINER_TYPES[partType]
    if not def then
        return
    end

    local square = player:getSquare()
    if isClient() then
        requestServerContainerSync(bikeItem, partType, square)
        return
    elseif isServer() then
        return
    end

    local containerItem = ensureContainerOnSquareOrInventory(bikeItem, def, square, player, true)
    if containerItem then
        if partType == "Toolbox" and player and player:getInventory() then
            local vanillaToolbox = BicycleVanillaPartMapping.findVanillaSourceInInventory(player:getInventory(), "Toolbox")
            BicycleAttachments.transferVanillaToolbox(player, vanillaToolbox, containerItem, square)
        end
        if isPlasticBagPartType(partType) and player and player:getInventory() then
            local vanillaBag = BicycleVanillaPartMapping.findVanillaSourceInInventory(player:getInventory(), partType)
            BicycleAttachments.transferVanillaPlasticBag(player, vanillaBag, containerItem, square)
        end
    end
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@param square IsoGridSquare
---@return InventoryItem|nil
local function findDroppedContainerBySquare(player, item, square)
    local items = BicycleAttachments.getItems(square)
    for i = 1, #items do
        local worldObj = items[i]
        if instanceof(worldObj, "IsoWorldInventoryObject") and worldObj:getItem():getType() == item:getType() then
            return worldObj:getItem()
        end
    end
    return nil
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@param square IsoGridSquare
---@return InventoryItem|nil
local function findDroppedContainer(player, item, square)
    if not square then
        return nil
    end

    local squareItem = findDroppedContainerBySquare(player, item, square)
    if squareItem then
        return squareItem
    end

    local nearby = {
        square:getN(),
        square:getS(),
        square:getE(),
        square:getW(),
    }

    for _, nearSquare in ipairs(nearby) do
        if nearSquare then
            local found = findDroppedContainerBySquare(player, item, nearSquare)
            if found then
                return found
            end
        end
    end

    return nil
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param item InventoryItem|nil
---@param square IsoGridSquare|nil
---@return boolean
local function transferContainerToBicycle(player, item, square)
    if not (player and item and square) then
        return false
    end

    local worldObj = BicycleAttachments.FindBicycle(player)
    if not worldObj then
        return false
    end

    local bikeItem = worldObj:getItem()
    if not bikeItem then
        return false
    end

    local itemType = item:getType()
    local def = CONTAINER_TYPES_BY_ITEM[itemType]
    if not def then
        return false
    end

    local partType = def.partType
    if bikeItem:getWeaponPart(partType) then
        return false
    end

    local droppedContainer = findDroppedContainer(player, item, square)
    if not droppedContainer then
        return false
    end

    local weaponPart = instanceItem("Bicycle.Bicycle_" .. partType)
    if weaponPart then
        bikeItem:attachWeaponPart(weaponPart, true)
        local data = getContainerData(bikeItem, partType)
        if data then
            clearContainerData(data)
        end
        if isClient() then
            requestServerContainerSync(bikeItem, partType, square)
        end
    end

    BicycleUtils.removeItemFromContainer(droppedContainer)
    local worldItem = droppedContainer:getWorldItem()
    if worldItem then
        if worldItem.removeFromWorld then
            worldItem:removeFromWorld()
        end
        if worldItem.removeFromSquare then
            worldItem:removeFromSquare()
        end
        droppedContainer:setWorldItem(nil)
    end

    refreshPlayerInventories(player)
    return true
end

---@param square IsoGridSquare
---@return IsoObject[]
---@nodiscard
function BicycleAttachments.getItems(square)
    local items = {}
    local squares = { square }
    if not instanceof(square, "IsoGridSquare") then
        return items
    end
    if square.getN and square:getN() then
        table.insert(squares, square:getN())
    end
    if square.getN and square:getN() and square:getN().getE then
        table.insert(squares, square:getN():getE())
    end
    if square.getN and square:getN() and square:getN().getW then
        table.insert(squares, square:getN():getW())
    end
    if square.getS and square:getS() then
        table.insert(squares, square:getS())
    end
    if square.getS and square:getS() and square:getS().getE then
        table.insert(squares, square:getS():getE())
    end
    if square.getS and square:getS() and square:getS().getW then
        table.insert(squares, square:getS():getW())
    end
    if square.getE and square:getE() then
        table.insert(squares, square:getE())
    end
    if square.getW and square:getW() then
        table.insert(squares, square:getW())
    end
    for _, sq in ipairs(squares) do
        for _, item in ipairs(sq:getLuaTileObjectList()) do
            table.insert(items, item)
        end
    end
    return items
end

---@param bikeItem InventoryItem|nil
---@return number containerCount, number contentsWeight
---@nodiscard
function BicycleAttachments.measureContainerLoad(bikeItem)
    local count = 0
    local weight = 0
    if not bikeItem then
        return count, weight
    end

    if bikeItem.getModData then
        local md = bikeItem:getModData()
        local load = md.BicycleLoad
        if load then
            return load.count or 0, load.weight or 0
        end
    end

    for _, def in pairs(CONTAINER_TYPES) do
        local data = getContainerData(bikeItem, def.partType)
        if data and data.itemId and data.x and data.y and data.z then
            local worldObj = select(1, findWorldItemOnSquare(data.x, data.y, data.z, def.fullType, data.itemId))
            if worldObj and worldObj.getItem then
                local item = worldObj:getItem()
                if item then
                    count = count + 1
                    local sub = item.getItemContainer and item:getItemContainer()
                    if sub then
                        weight = weight + sub:getContentsWeight()
                    end
                end
            end
        end
    end
    return count, weight
end

---@param part InventoryItem|nil
---@return number
---@nodiscard
function BicycleAttachments.getSportsbottleWaterAmount(part)
    return getSportsbottleWaterAmountFromModData(part)
end

---@param part InventoryItem|nil
---@param amount number
---@return number
function BicycleAttachments.setSportsbottleWaterAmount(part, amount)
    return setSportsbottleWaterModData(part, amount)
end

---@param part InventoryItem|nil
---@param vanillaBottle InventoryItem|nil
function BicycleAttachments.captureSportsbottleWater(part, vanillaBottle)
    copyWaterToModData(part, vanillaBottle)
end

---@param player IsoPlayer|IsoGameCharacter
---@param bikeItem InventoryItem
---@param vanillaBag InventoryItem
---@param containerItem InventoryItem
---@param square IsoGridSquare
function BicycleAttachments.transferVanillaPlasticBag(player, vanillaBag, containerItem, square)
    local dropSquare = square or (player and player.getSquare and player:getSquare())
    transferVanillaBagToContainer(player, vanillaBag, containerItem, dropSquare)
    refreshPlayerInventories(player)
end

---@param player IsoPlayer|IsoGameCharacter
---@param vanillaToolbox InventoryItem|nil
---@param containerItem InventoryItem|nil
---@param square IsoGridSquare|nil
function BicycleAttachments.transferVanillaToolbox(player, vanillaToolbox, containerItem, square)
    local dropSquare = square or (player and player.getSquare and player:getSquare())
    transferVanillaToolboxToContainer(player, vanillaToolbox, containerItem, dropSquare)
    refreshPlayerInventories(player)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|IsoWorldInventoryObject|nil
---@param srcContainer ItemContainer|nil
---@param destContainer ItemContainer|nil
function BicycleAttachments.transferContainersToContainer(player, bikeItem, srcContainer, destContainer)
    bikeItem = getBikeItem(bikeItem)
    if not bikeItem then
        return
    end

    requestServerBikeContainerTransfer(player, bikeItem, srcContainer, destContainer, player and player:getSquare() or nil)
    refreshPlayerInventories(player)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|IsoWorldInventoryObject|nil
---@param srcContainer ItemContainer|nil
---@param dropSquare IsoGridSquare|nil
---@param destContainer ItemContainer|nil
function BicycleAttachments.transferContainersFromContainer(player, bikeItem, srcContainer, dropSquare, destContainer)
    bikeItem = getBikeItem(bikeItem)
    if not bikeItem then
        return
    end

    requestServerBikeContainerTransfer(
        player,
        bikeItem,
        srcContainer,
        destContainer,
        dropSquare or (player and player:getSquare() or nil)
    )
    refreshPlayerInventories(player)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
local function transferBicycleIfNeeded(player, bikeItem)
    if not (player and bikeItem) then
        return
    end
    if bikeItem.getWorldItem and bikeItem:getWorldItem() then
        return
    end
    ISInventoryPaneContextMenu.transferIfNeeded(player, bikeItem, true)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param item InventoryItem|nil
local function transferSourceIfNeeded(player, item)
    if not (player and item) then
        return
    end
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|IsoWorldInventoryObject|nil
---@param sourceItem InventoryItem|nil
---@param partType string|nil
---@param sourceMode string|nil
---@param ductTape InventoryItem|nil
---@param partFullType string|nil
local function queueAttachPartAction(player, bikeItem, sourceItem, partType, sourceMode, ductTape, partFullType)
    bikeItem = getBikeItem(bikeItem)
    if not (player and bikeItem and sourceItem) then
        return
    end

    local targetPartType = BicyclePartAttachmentService.resolveAttachPartType(bikeItem, sourceItem, partType, sourceMode)
    if not targetPartType then
        return
    end

    transferBicycleIfNeeded(player, bikeItem)
    transferSourceIfNeeded(player, sourceItem)
    if ductTape then
        transferSourceIfNeeded(player, ductTape)
    end

    local square = AttachmentActionUtils.resolveBikeSquare(player, bikeItem)
    local x = nil
    local y = nil
    local z = nil
    if square then
        x = square:getX()
        y = square:getY()
        z = square:getZ()
    end
    player:setVariable("BicycleUpgrading", true)
    ISTimedActionQueue.add(BicycleAttachPartAction:new(
        player,
        bikeItem,
        sourceItem,
        targetPartType,
        sourceMode,
        ductTape,
        partFullType,
        x,
        y,
        z
    ))
end

---@param test InventoryItem|IsoWorldInventoryObject|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|IsoWorldInventoryObject|nil
---@param vanillaBag InventoryItem|nil
function BicycleAttachments.attachVanillaPlasticBag(test, player, bikeItem, vanillaBag)
    bikeItem = getBikeItem(bikeItem)
    if not (player and bikeItem and vanillaBag) then
        return
    end
    if not BicycleVanillaPartMapping.isVanillaSourceForPartType(vanillaBag, "PlasticBagLeft") then
        return
    end

    local targetPartType = BicycleVanillaPartMapping.resolveAttachPartTypeForVanillaItem(bikeItem, vanillaBag)
    if targetPartType ~= "PlasticBagLeft" and targetPartType ~= "PlasticBagRight" then
        return
    end

    queueAttachPartAction(
        player,
        bikeItem,
        vanillaBag,
        targetPartType,
        BicyclePartAttachmentService.SourceModeVanilla,
        nil,
        nil
    )
end

---@param test InventoryItem|IsoWorldInventoryObject|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|IsoWorldInventoryObject|nil
---@param vanillaToolbox InventoryItem|nil
function BicycleAttachments.attachVanillaToolbox(test, player, bikeItem, vanillaToolbox)
    bikeItem = getBikeItem(bikeItem)
    if not (player and bikeItem and vanillaToolbox) then
        return
    end
    if not BicycleVanillaPartMapping.isVanillaSourceForPartType(vanillaToolbox, "Toolbox") then
        return
    end
    if BicycleVanillaPartMapping.resolveAttachPartTypeForVanillaItem(bikeItem, vanillaToolbox) ~= "Toolbox" then
        return
    end

    queueAttachPartAction(
        player,
        bikeItem,
        vanillaToolbox,
        "Toolbox",
        BicyclePartAttachmentService.SourceModeVanilla,
        nil,
        nil
    )
end

---@param test InventoryItem|IsoWorldInventoryObject|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|IsoWorldInventoryObject|nil
---@param vanillaSportsbottle InventoryItem|nil
function BicycleAttachments.attachVanillaSportsbottle(test, player, bikeItem, vanillaSportsbottle)
    bikeItem = getBikeItem(bikeItem)
    if not (player and bikeItem and vanillaSportsbottle) then
        return
    end
    if not BicycleVanillaPartMapping.isVanillaSourceForPartType(vanillaSportsbottle, "Sportsbottle") then
        return
    end
    if BicycleVanillaPartMapping.resolveAttachPartTypeForVanillaItem(bikeItem, vanillaSportsbottle) ~= "Sportsbottle" then
        return
    end

    queueAttachPartAction(
        player,
        bikeItem,
        vanillaSportsbottle,
        "Sportsbottle",
        BicyclePartAttachmentService.SourceModeVanilla,
        nil,
        nil
    )
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|IsoWorldInventoryObject|nil
---@param flashlight InventoryItem|nil
---@param ductTape InventoryItem|nil
---@param expectedFullType string
---@param partFullType string
local function attachTapedFlashlight(player, bikeItem, flashlight, ductTape, expectedFullType, partFullType)
    bikeItem = getBikeItem(bikeItem)
    if not (player and bikeItem and flashlight) then
        return
    end
    if flashlight:getFullType() ~= expectedFullType then
        return
    end
    if bikeHasLamp(bikeItem) then
        return
    end
    if bikeItem:getWeaponPart("TapedFlashlight") then
        return
    end

    local inv = player:getInventory()
    if not inv then
        return
    end

    local ductTapeItem = ductTape or findDuctTapeWithCharges(inv)
    if ductTapeItem and ductTapeItem.getCurrentUsesFloat and ductTapeItem:getCurrentUsesFloat() < DUCT_TAPE_USAGE then
        ductTapeItem = nil
    end
    if not ductTapeItem then
        return
    end

    queueAttachPartAction(
        player,
        bikeItem,
        flashlight,
        "TapedFlashlight",
        BicyclePartAttachmentService.SourceModeTapedFlashlight,
        ductTapeItem,
        partFullType
    )
end

---@param test InventoryItem|IsoWorldInventoryObject|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|IsoWorldInventoryObject|nil
---@param flashlight InventoryItem|nil
---@param ductTape InventoryItem|nil
function BicycleAttachments.attachTapedFlashlight(test, player, bikeItem, flashlight, ductTape)
    attachTapedFlashlight(player, bikeItem, flashlight, ductTape, HAND_TORCH_FULL_TYPE, "Bicycle.Bicycle_TapedFlashlight")
end

---@param test InventoryItem|IsoWorldInventoryObject|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|IsoWorldInventoryObject|nil
---@param flashlight InventoryItem|nil
---@param ductTape InventoryItem|nil
function BicycleAttachments.attachImprovisedTapedFlashlight(test, player, bikeItem, flashlight, ductTape)
    attachTapedFlashlight(
        player,
        bikeItem,
        flashlight,
        ductTape,
        CRAFTED_FLASHLIGHT_FULL_TYPE,
        "Bicycle.Bicycle_TapedImprovisedFlashlight"
    )
end

---@param player IsoPlayer|IsoGameCharacter
---@param bikeItem InventoryItem
---@param dismountData table|nil
function BicycleAttachments.onMount(player, bikeItem, dismountData)
    BicycleDismountBehavior.ensureKickstandState(bikeItem, player, "up")
end

---@param item InventoryItem|nil
---@return boolean
---@nodiscard
function BicycleAttachments.isBicycleContainerItem(item)
    if not item then
        return false
    end
    return BicycleContainers.isContainerItemType(item:getType())
end

---@param character IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@return boolean
function BicycleAttachments.canEquipContainer(character, item)
    if not item then
        return false
    end
    if not BicycleAttachments.isBicycleContainerItem(item) then
        return false
    end
    if character and character:getPrimaryHandItem() then
        if BicycleUtils.isBicycleItem(character:getPrimaryHandItem()) then
            character:Say(getText("IGUI_Bicycle_HopOffFirst"))
            return false
        end
    end
    return true
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@return boolean
function BicycleAttachments.onContainerEquipped(player, item)
    if not item then
        return false
    end

    if not BicycleAttachments.isBicycleContainerItem(item) then
        return false
    end

    if not player then
        return false
    end

    local square = player:getSquare()
    if not square then
        return false
    end

    local result = transferContainerToBicycle(player, item, square)
    if result then
        return true
    end

    return false
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@param square IsoGridSquare
---@return boolean
function BicycleAttachments.onContainerDropped(player, item, square)
    if not (player and item) then
        return false
    end

    if not BicycleAttachments.isBicycleContainerItem(item) then
        return false
    end

    return transferContainerToBicycle(player, item, square)
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@return boolean
function BicycleAttachments.onContainerTaken(player, item)
    if not (player and item) then
        return false
    end

    if not BicycleAttachments.isBicycleContainerItem(item) then
        return false
    end

    if not player:getSquare() then
        return false
    end

    return transferContainerToBicycle(player, item, player:getSquare())
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@return boolean
function BicycleAttachments.onContainerUnEquip(player, item)
    if not (player and item) then
        return false
    end

    if not BicycleAttachments.isBicycleContainerItem(item) then
        return false
    end

    return true
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@param square IsoGridSquare
---@return boolean
function BicycleAttachments.onContainerGrabbed(player, item, square)
    if not (player and item and square) then
        return false
    end

    if not BicycleAttachments.isBicycleContainerItem(item) then
        return false
    end

    return transferContainerToBicycle(player, item, square)
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@param square IsoGridSquare
---@return boolean
function BicycleAttachments.onContainerMoved(player, item, square)
    if not (player and item and square) then
        return false
    end

    if not BicycleAttachments.isBicycleContainerItem(item) then
        return false
    end

    return transferContainerToBicycle(player, item, square)
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@param square IsoGridSquare
---@return boolean
function BicycleAttachments.onContainerDroppedOnGround(player, item, square)
    if not (player and item and square) then
        return false
    end

    if not BicycleAttachments.isBicycleContainerItem(item) then
        return false
    end

    return transferContainerToBicycle(player, item, square)
end

---@param item InventoryItem|nil
---@return boolean
---@nodiscard
function BicycleAttachments.canTransferBicycleItem(item)
    if not item then
        return false
    end
    if BicycleUtils.isBicycleItem(item) then
        return false
    end
    if BicycleAttachments.isBicycleContainerItem(item) then
        return false
    end
    return true
end

---@param item InventoryItem|nil
---@return boolean
---@nodiscard
function BicycleAttachments.isBicycleItem(item)
    return BicycleUtils.isBicycleItem(item)
end

---@param container ItemContainer|nil
---@param item InventoryItem|nil
---@return boolean
function BicycleAttachments.canAddToContainer(container, item)
    if not ContainerGuards.isInvisibleContainer(container) then
        return true
    end
    return ContainerGuards.canStoreInInvisibleContainer(item)
end

---@param container ItemContainer|nil
---@param item InventoryItem|nil
---@return boolean
function BicycleAttachments.canRemoveFromContainer(container, item)
    if not ContainerGuards.isInvisibleContainer(container) then
        return true
    end
    return ContainerGuards.canStoreInInvisibleContainer(item)
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@return boolean
function BicycleAttachments.onContainerDroppedByPlayer(player, item)
    if not player then
        return false
    end
    if not BicycleAttachments.isBicycleContainerItem(item) then
        return false
    end

    return transferContainerToBicycle(player, item, player:getSquare())
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@return boolean
function BicycleAttachments.onContainerEquippedByPlayer(player, item)
    return BicycleAttachments.onContainerEquipped(player, item)
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@return boolean
function BicycleAttachments.onContainerDroppedByGrab(player, item)
    return BicycleAttachments.onContainerDropped(player, item, player:getSquare())
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@param square IsoGridSquare
---@return boolean
function BicycleAttachments.onContainerDroppedByGrabSquare(player, item, square)
    return BicycleAttachments.onContainerDropped(player, item, square)
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@param square IsoGridSquare
---@return boolean
function BicycleAttachments.onContainerGrabbedByPlayer(player, item, square)
    return BicycleAttachments.onContainerGrabbed(player, item, square)
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@param square IsoGridSquare
---@return boolean
function BicycleAttachments.onContainerMovedByPlayer(player, item, square)
    return BicycleAttachments.onContainerMoved(player, item, square)
end

---@param player IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@param square IsoGridSquare
---@return boolean
function BicycleAttachments.onContainerDroppedOnGroundByPlayer(player, item, square)
    return BicycleAttachments.onContainerDroppedOnGround(player, item, square)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return IsoWorldInventoryObject|nil
function BicycleAttachments.FindBicycle(player)
    if not player then
        return nil
    end
    local square = player:getSquare()
    if not square then
        return nil
    end
    local cell = getCell and getCell()
    if not cell then
        return nil
    end
    local best, bestDist
    local x, y, z = square:getX(), square:getY(), square:getZ()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local testSquare = cell:getGridSquare(x + dx, y + dy, z)
            if testSquare and testSquare.getWorldObjects then
                local list = testSquare:getWorldObjects()
                for i = 0, list:size() - 1 do
                    local worldObj = list:get(i)
                    local item = worldObj and worldObj:getItem() or nil
                    if BicycleUtils.isBicycleItem(item) then
                        local dist = (testSquare:getX() - x) * (testSquare:getX() - x)
                            + (testSquare:getY() - y) * (testSquare:getY() - y)
                        if not best or dist < bestDist then
                            best, bestDist = worldObj, dist
                        end
                    end
                end
            end
        end
    end
    return best
end

---@param playerOrObject IsoPlayer|IsoGameCharacter|IsoWorldInventoryObject|IsoGridSquare|nil
---@param item string
---@return IsoWorldInventoryObject|nil
function BicycleAttachments.FindFloorItem(playerOrObject, item)
    if not playerOrObject then
        return nil
    end
    local square = playerOrObject.getSquare and playerOrObject:getSquare() or playerOrObject
    if not square then
        return nil
    end
    local cell = getCell and getCell()
    if not cell then
        return nil
    end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local best, bestDist
    for dx = -1, 1 do
        for dy = -1, 1 do
            local testSquare = cell:getGridSquare(x + dx, y + dy, z)
            if testSquare and testSquare.getWorldObjects then
                local list = testSquare:getWorldObjects()
                for i = 0, list:size() - 1 do
                    local worldObj = list:get(i)
                    local worldItem = worldObj and worldObj:getItem() or nil
                    if worldItem and string.find(worldItem:getType(), item) then
                        local dist = (testSquare:getX() - x) * (testSquare:getX() - x)
                            + (testSquare:getY() - y) * (testSquare:getY() - y)
                        if not best or dist < bestDist then
                            best, bestDist = worldObj, dist
                        end
                    end
                end
            end
        end
    end
    return best
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return IsoWorldInventoryObject|nil
function FindBicycle(player)
    return BicycleAttachments.FindBicycle(player)
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param item string
---@return IsoWorldInventoryObject|nil
function FindFloorItem(player, item)
    return BicycleAttachments.FindFloorItem(player, item)
end

local originalTransferIsValid = ISInventoryTransferAction.isValid

---@param containerType string|nil
---@return boolean
---@nodiscard
local function isTrunkType(containerType)
    if not containerType then
        return false
    end
    if containerType == "TruckBed" or containerType == "TruckBedOpen" or containerType == "TrailerTrunk" then
        return true
    end

    return string.find(containerType, "Trunk", 1, true) ~= nil
end

---@param container ItemContainer|nil
---@return boolean
---@nodiscard
local function isTrunkContainer(container)
    if ContainerGuards.isVehicleTrunkContainer(container) then
        return true
    end

    local containerType = container and container.getType and container:getType() or nil
    return isTrunkType(containerType)
end

---@param item InventoryItem|nil
---@return boolean
---@nodiscard
local function isInvisibleContainerItem(item)
    return ContainerGuards.isInvisibleContainerItem(item)
end

---@return boolean
---@nodiscard
local function canTransferBicycleToPlayerInventory()
    return BicycleOptions.canTransferToPlayerInventory()
end

---@return boolean
function ISInventoryTransferAction:isValid()
    if BicycleUtils.isBicycleItem(self.item) or isInvisibleContainerItem(self.item) then
        if self.bicycleMount then
            return true
        end

        local character = self.character
        local bikeItem = self.item
        local destContainer = self.destContainer
        local srcContainer = self.srcContainer

        if BicycleUtils.isBicycleItem(bikeItem) and SidecarAnimal.bikeHasAnyAnimalPart(bikeItem) then
            character:Say(getText("IGUI_Bicycle_Sidecar_AnimalBlocksPack"))
            return false
        end
        local destType = destContainer and destContainer.getType and destContainer:getType() or nil

        local destIsFloor = destType == "floor"
        local destIsTrunk = isTrunkContainer(destContainer)
        local srcIsTrunk = isTrunkContainer(srcContainer)
        local destIsPlayerInv = destContainer and ContainerGuards.isPlayerInventory(destContainer, character)
        local srcIsPlayerInv = srcContainer and ContainerGuards.isPlayerInventory(srcContainer, character)
        local allowPlayerInv = canTransferBicycleToPlayerInventory()

        if not BicycleUtils.isBicycleItem(self.item) and not ContainerGuards.isAllowedInvisibleDestination(destContainer) then
            return false
        end
        if not BicycleUtils.isBicycleItem(self.item) and ContainerGuards.isPlayerInventory(destContainer, self.character) then
            return false
        end
        if destContainer and ContainerGuards.isInvisibleContainer(destContainer) then
            return false
        end
        if destIsPlayerInv and not allowPlayerInv then
            return false
        end

        local destIsAllowed = destIsFloor or destIsTrunk or (destIsPlayerInv and allowPlayerInv)
        if not destIsAllowed then
            return false
        end

        self:setOnComplete(
            function(player, bike, src, dest, dropToFloor, destTrunk, destPlayerInv, sourceTrunk, sourcePlayerInv)
                local shouldFollowPlayer = false

                if sourceTrunk then
                    local playerSquare = player and player:getSquare() or nil
                    BicycleAttachments.transferContainersFromContainer(player, bike, src, playerSquare, nil)
                    if destPlayerInv then
                        shouldFollowPlayer = true
                    end
                elseif sourcePlayerInv and dropToFloor then
                    BicycleAttachments.transferContainersFromContainer(player, bike, src, player and player:getSquare(), nil)
                end

                if destTrunk or (destPlayerInv and not (sourceTrunk or dropToFloor)) then
                    BicycleAttachments.transferContainersToContainer(player, bike, src, dest)
                end

                if dropToFloor then
                    BicycleMenu.onCompleteDrop(player, bike)
                elseif not (destTrunk or destPlayerInv) then
                    BicycleAttachments.onBikeDropped(player, bike)
                end

                if shouldFollowPlayer then
                    BicycleAttachments.onBikeDropped(player, bike)
                    BicycleAttachments.followPlayer(player, bike)
                end
            end,
            character,
            bikeItem,
            srcContainer,
            destContainer,
            destIsFloor,
            destIsTrunk,
            destIsPlayerInv,
            srcIsTrunk,
            srcIsPlayerInv
        )
        return true
    end

    return originalTransferIsValid(self)
end

return BicycleAttachments
