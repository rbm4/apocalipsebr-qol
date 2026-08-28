local ContainerGuards = require("Bicycle/ContainerGuards")
local BicycleUtils = require("Bicycle/Utils")
local ThrowRotations = require("Bicycle/ThrowRotations")
require "Foraging/ISSearchManager"

local PLASTIC_BAG_FULL_TYPE = "Base.Plasticbag"
local TOOLBOX_FULL_TYPE = "Base.Toolbox"
local SPORTS_BOTTLE_FULL_TYPE = "Base.Sportsbottle"
local HAND_TORCH_FULL_TYPE = "Base.HandTorch"
local CRAFTED_FLASHLIGHT_FULL_TYPE = "Base.Flashlight_Crafted"
local DUCT_TAPE_FULL_TYPE = "Base.DuctTape"
local DUCT_TAPE_USAGE = 0.1
local SPORTS_BOTTLE_WATER_KEY = "BicycleSportsbottleWater"
local SPORTS_BOTTLE_CAPACITY = 1.0
local PLASTIC_BAG_PARTS = {
    PlasticBagLeft = true,
    PlasticBagRight = true,
}

-- Customize these to tune how the bicycle is thrown per facing direction when using the throwBicycle dismount.
local THROW_ROTATIONS_BY_DIRECTION = ThrowRotations.THROW_ROTATIONS_BY_DIRECTION

local CONTAINER_TYPES = {
    Saddlebag = {
        partType = "Saddlebag",
        fullType = "Bicycle.Saddlebag",
    },
    Basket = {
        partType = "Basket",
        fullType = "Bicycle.Basket",
    },
    Crate = {
        partType = "Crate",
        fullType = "Bicycle.Crate",
    },
    Toolbox = {
        partType = "Toolbox",
        fullType = "Bicycle.ToolboxContainer",
    },
    PlasticBagLeft = {
        partType = "PlasticBagLeft",
        fullType = "Bicycle.PlasticBagLeft",
    },
    PlasticBagRight = {
        partType = "PlasticBagRight",
        fullType = "Bicycle.PlasticBagRight",
    },
}

local function isPlasticBagPartType(partType)
    return PLASTIC_BAG_PARTS[partType] == true
end

local FOLLOW_UPDATE_INTERVAL = 1
local followTick = 0

BicycleAttachments = BicycleAttachments or {}
BicycleAttachments.DUCT_TAPE_USAGE = DUCT_TAPE_USAGE

local function refreshPlayerInventories(player)
    if not player then return end
    if triggerEvent then
        triggerEvent("OnContainerUpdate")
    end
    if not getPlayerData then return end
    local pdata = getPlayerData(player:getPlayerNum())
    if not pdata then return end
    if pdata.playerInventory and pdata.playerInventory.refreshBackpacks then
        pdata.playerInventory:refreshBackpacks()
    end
    if pdata.lootInventory and pdata.lootInventory.refreshBackpacks then
        pdata.lootInventory:refreshBackpacks()
    end
end

local function getBikeItem(itemOrWorld)
    if not itemOrWorld then return nil end
    if instanceof(itemOrWorld, "IsoWorldInventoryObject") then
        return itemOrWorld:getItem()
    end
    return itemOrWorld
end

local function getBikeModData(bikeItem)
    bikeItem = getBikeItem(bikeItem)
    if not (bikeItem and bikeItem.getModData) then return nil end
    local md = bikeItem:getModData()
    md.BicycleContainers = md.BicycleContainers or {}
    return md.BicycleContainers
end

local function getContainerData(bikeItem, key)
    local md = getBikeModData(bikeItem)
    if not md then return nil end
    md[key] = md[key] or {}
    return md[key]
end

local function getWorldInventoryObjectsAt(x, y, z)
    local cell = getCell and getCell()
    if not cell then return nil, nil end
    local sq = cell:getGridSquare(math.floor(x), math.floor(y), z)
    return sq, sq and sq:getWorldObjects() or nil
end

local function findWorldItemOnSquare(x, y, z, fullType, wantId)
    local sq, list = getWorldInventoryObjectsAt(x, y, z)
    if not list then return nil, sq end
    for i = 0, list:size() - 1 do
        local wo = list:get(i)
        if wo and wo.getItem then
            local it = wo:getItem()
            if it and it:getFullType() == fullType then
                if not wantId or (it.getID and it:getID() == wantId) then
                    return wo, sq
                end
            end
        end
    end
    return nil, sq
end

local function adoptNearbyWorldItem(square, fullType)
    if not square then return nil, nil end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local wo, sq = findWorldItemOnSquare(x + dx, y + dy, z, fullType, nil)
            if wo then return wo, sq end
        end
    end
    return nil, square
end

local function setDataForWorldObject(data, worldObj)
    if not (data and worldObj) then return end
    local sq = worldObj:getSquare()
    if sq then
        data.x, data.y, data.z = sq:getX(), sq:getY(), sq:getZ()
    end
    local item = worldObj:getItem()
    if item and item.getID then
        data.itemId = item:getID()
    else
        data.itemId = nil
    end
    data.packed = nil
end

local function clearContainerData(data)
    if not data then return end
    data.x, data.y, data.z = nil, nil, nil
    data.itemId = nil
    data.packed = nil
    data.storage = nil
end

local function clamp01(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function removeKickstandPart(bikeItem, player, partType)
    if not (bikeItem and bikeItem.getWeaponPart) then return end

    local part = bikeItem:getWeaponPart(partType)
    if not part then return end

    if bikeItem.detachWeaponPart then
        bikeItem:detachWeaponPart(player, part)
    end

    local container = part.getContainer and part:getContainer() or nil
    if container and container.DoRemoveItem then
        container:DoRemoveItem(part)
    elseif container and container.Remove then
        container:Remove(part)
    end

    local worldItem = part.getWorldItem and part:getWorldItem() or nil
    if worldItem and worldItem.removeFromWorld then
        worldItem:removeFromWorld()
    end
end

local function attachKickstandPart(bikeItem, fullType)
    if not (bikeItem and bikeItem.attachWeaponPart and instanceItem) then return end
    local part = instanceItem(fullType)
    if part then
        bikeItem:attachWeaponPart(part, true)
    end
end

local function ensureKickstandState(bikeItem, player, targetState)
    if not bikeItem then return end

    local hasKickstandUp = bikeItem.getWeaponPart and bikeItem:getWeaponPart("KickstandUp") ~= nil
    local hasKickstandDown = bikeItem.getWeaponPart and bikeItem:getWeaponPart("KickstandDown") ~= nil

    if not hasKickstandUp and not hasKickstandDown then
        return
    end

    if targetState == "up" then
        if hasKickstandUp then
            if hasKickstandDown then
                removeKickstandPart(bikeItem, player, "KickstandDown")
            end
            return
        end

        if not hasKickstandDown then
            return
        end

        removeKickstandPart(bikeItem, player, "KickstandDown")
        attachKickstandPart(bikeItem, "Bicycle.Bicycle_KickstandUp")
        return
    end

    -- Default to kickstand down for any other target state
    if hasKickstandDown then
        if hasKickstandUp then
            removeKickstandPart(bikeItem, player, "KickstandUp")
        end
        return
    end

    if not hasKickstandUp then
        return
    end

    removeKickstandPart(bikeItem, player, "KickstandUp")
    attachKickstandPart(bikeItem, "Bicycle.Bicycle_KickstandDown")
end

local function clampSportsbottleWaterAmount(item, amount)
    if not amount then return 0 end
    local maxAmount = SPORTS_BOTTLE_CAPACITY
    if item and item.getFluidContainer then
        local fluidContainer = item:getFluidContainer()
        if fluidContainer and fluidContainer.getCapacity then
            maxAmount = fluidContainer:getCapacity()
        end
    end
    return math.max(0, math.min(amount, maxAmount or SPORTS_BOTTLE_CAPACITY))
end

local function setSportsbottleWaterModData(item, amount)
    if not (item and item.getModData) then return 0 end
    local clamped = clampSportsbottleWaterAmount(item, amount or 0)
    local md = item:getModData()
    md[SPORTS_BOTTLE_WATER_KEY] = clamped
    if item.transmitModData then
        item:transmitModData()
    end
    return clamped
end

local function getSportsbottleWaterAmountFromModData(item)
    if not (item and item.getModData) then return 0 end
    local md = item:getModData()
    local stored = tonumber(md[SPORTS_BOTTLE_WATER_KEY]) or 0
    return clampSportsbottleWaterAmount(item, stored)
end

local function copyWaterToModData(part, vanillaSportsbottle)
    if not part then return 0 end
    local amount = 0
    if vanillaSportsbottle and vanillaSportsbottle.getFluidContainer then
        local fluidContainer = vanillaSportsbottle:getFluidContainer()
        if fluidContainer and fluidContainer.getAmount then
            amount = fluidContainer:getAmount()
        end
    end
    return setSportsbottleWaterModData(part, amount)
end

local function applyWaterAmountToVanillaSportsbottle(vanillaSportsbottle, amount)
    if not (vanillaSportsbottle and vanillaSportsbottle.getFluidContainer) then return end
    local fluidContainer = vanillaSportsbottle:getFluidContainer()
    if not fluidContainer then return end

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

local function getThrowRotation(direction, zRotation)
    local x, y, z = ThrowRotations.getThrowRotation(direction, zRotation)
    return x, y, z
end

local function layDownBicycle(worldObj, direction, zRotation, refreshIfAlreadyLaid)
    if not worldObj or not worldObj.getItem then return false end
    local item = worldObj:getItem()
    if not item then return false end

    local xRot, yRot, zRot = getThrowRotation(direction, zRotation)

    if refreshIfAlreadyLaid and item.getWorldZRotation then
        local currentZ = item:getWorldZRotation()
        if currentZ and zRot then
            local normalizedCurrent = BicycleUtils.normalizeZRotation(currentZ)
            local normalizedTarget = BicycleUtils.normalizeZRotation(zRot)
            if normalizedCurrent == normalizedTarget then
                zRot = BicycleUtils.normalizeZRotation(zRot + 1)
            end
        end
    end

    item:setWorldXRotation(xRot)
    item:setWorldYRotation(yRot)
    item:setWorldZRotation(zRot)

    worldObj:setOffX(0.39)
    worldObj:setOffY(1)
    worldObj:setOffZ(0.04)

    return true
end

local function applyDroppedBikeTransform(player, bikeItem, dismountData)
    if not bikeItem then return end

    local function applyTransform()
        local worldObj = bikeItem.getWorldItem and bikeItem:getWorldItem() or nil
        if not worldObj then return false end

        local hasKickstand = bikeItem.getWeaponPart and bikeItem:getWeaponPart("KickstandDown") ~= nil
        local shiftHeld = dismountData and dismountData.shiftHeld or false
        local usingKickstand = hasKickstand and not shiftHeld
        local direction = dismountData and dismountData.direction or nil
        local zRotation = dismountData and dismountData.zRotation or nil
        if not zRotation and player and player.getDir then
            zRotation = BicycleUtils.directionToZRotation(player:getDir())
        end
        if not direction and player and player.getDir then
            direction = player:getDir()
        end
        if zRotation then
            zRotation = BicycleUtils.normalizeZRotation(zRotation + 90)
        end
        if usingKickstand then
            local item = worldObj:getItem()
            if not item then return false end

            item:setWorldXRotation(0)
            item:setWorldYRotation(0)
            item:setWorldZRotation(zRotation or 360)

            worldObj:setOffX(0)
            worldObj:setOffY(0)
            worldObj:setOffZ(0)

            return true
        end

        return layDownBicycle(worldObj, direction, zRotation)
    end

    if applyTransform() then
        return
    end

    BicycleUtils.runAfter(0.1, function()
        applyTransform()
    end)
end

local function moveWorldObjectToSquare(worldObj, destSq)
    if not (worldObj and destSq) then return worldObj end
    local item = worldObj:getItem()
    if not item then return worldObj end
    if worldObj.removeFromSquare then worldObj:removeFromSquare() end
    if worldObj.removeFromWorld then worldObj:removeFromWorld() end
    destSq:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
    return item:getWorldItem() or worldObj
end

local function spawnContainerOnSquare(fullType, square)
    if not (fullType and square) then return nil end
    local item = square:AddWorldInventoryItem(fullType, 0.0, 0.0, 0.0)
    if not item then return nil end
    return item:getWorldItem()
end

local function takeWorldObjectToContainer(worldObj, destContainer)
    if not (worldObj and destContainer and destContainer.AddItem) then return nil end
    local item = worldObj:getItem()
    if not item then return nil end
    if worldObj.removeFromSquare then worldObj:removeFromSquare() end
    if worldObj.removeFromWorld then worldObj:removeFromWorld() end
    destContainer:AddItem(item)
    return item
end

local function removeItemFromContainer(item)
    if not item then return end
    local container = item:getContainer()
    if container and container.Remove then
        container:Remove(item)
    elseif container and container.DoRemoveItem then
        container:DoRemoveItem(item)
    end
end

local function findItemInContainer(container, fullType)
    if not container then return nil end
    if container.FindAndReturn then
        local found = container:FindAndReturn(fullType)
        if found then return found end
    end
    local items = container:getItems()
    if not items then return nil end
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it:getFullType() == fullType then
            return it
        end
    end
    return nil
end

local function findPackedContainerItem(bikeItem, def, owner)
    local data = getContainerData(bikeItem, def.partType)
    if not (data and data.packed) then return nil end
    local item
    if owner and owner.getInventory then
        item = findItemInContainer(owner:getInventory(), def.fullType)
        if item then return item end
    end
    if data.storage and data.storage.container and data.storage.container.getItems then
        item = findItemInContainer(data.storage.container, def.fullType)
        if item then return item end
    end
    return nil
end

local function storePackedLocation(data, container)
    data = data or {}
    data.packed = true
    data.x, data.y, data.z = nil, nil, nil
    data.itemId = nil
    data.storage = data.storage or {}
    data.storage.container = container
    return data
end

local function ensureWorldContainer(bikeItem, def, square, player, allowSpawn)
    if not (bikeItem and def) then return nil end
    local data = getContainerData(bikeItem, def.partType)
    if not data then return nil end
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
        if packedItem then
            removeItemFromContainer(packedItem)
            if square then
                square:AddWorldInventoryItem(packedItem, 0.0, 0.0, 0.0)
                worldObj = packedItem:getWorldItem()
            end
            data.packed = nil
            data.storage = nil
        end
    end
    if not worldObj and allowSpawn and square then
        worldObj = spawnContainerOnSquare(def.fullType, square)
    end
    if worldObj then
        setDataForWorldObject(data, worldObj)
    end
    return worldObj
end

local function bikeHasPart(bikeItem, partType)
    if not (bikeItem and bikeItem.getWeaponPart) then return false end
    return bikeItem:getWeaponPart(partType) ~= nil
end

local function bikeHasLamp(bikeItem)
    return bikeHasPart(bikeItem, "Lamp")
end

local function getMissingPlasticBagPartType(bikeItem)
    if not bikeItem then return nil end
    if not bikeHasPart(bikeItem, "PlasticBagLeft") then
        return "PlasticBagLeft"
    end
    if not bikeHasPart(bikeItem, "PlasticBagRight") then
        return "PlasticBagRight"
    end
    return nil
end

local function ensureContainersForBike(bikeItem, player, allowSpawn)
    if not bikeItem then return end
    local square
    if player then
        square = player:getSquare()
    end
    if not square then
        local worldItem = bikeItem.getWorldItem and bikeItem:getWorldItem() or nil
        if worldItem then square = worldItem:getSquare() end
    end
    if not square then return end
    for key, def in pairs(CONTAINER_TYPES) do
        if bikeHasPart(bikeItem, def.partType) then
            ensureWorldContainer(bikeItem, def, square, player, allowSpawn)
        else
            local data = getContainerData(bikeItem, def.partType)
            if data then clearContainerData(data) end
        end
    end
end

local function moveContainersToSquare(bikeItem, square)
    if not (bikeItem and square) then return end
    for key, def in pairs(CONTAINER_TYPES) do
        if bikeHasPart(bikeItem, def.partType) then
            local data = getContainerData(bikeItem, def.partType)
            local worldObj = data and data.itemId and select(1, findWorldItemOnSquare(data.x or square:getX(), data.y or square:getY(), data.z or square:getZ(), def.fullType, data.itemId)) or nil
            if not worldObj then
                worldObj = select(1, findWorldItemOnSquare(square:getX(), square:getY(), square:getZ(), def.fullType, nil))
            end
            if worldObj then
                worldObj = moveWorldObjectToSquare(worldObj, square)
                setDataForWorldObject(data, worldObj)
            end
        end
    end
end

local function copyItemsToTable(container)
    local out = {}
    if not container then return out end
    local items = container:getItems()
    if not items then return out end
    for i = 0, items:size() - 1 do
        table.insert(out, items:get(i))
    end
    return out
end

local function dropContainerContentsOnSquare(containerItem, square)
    if not (containerItem and containerItem.getInventory and square) then return end
    local container = containerItem:getInventory()
    if not container then return end
    local items = copyItemsToTable(container)
    for i = 1, #items do
        local item = items[i]
        if item and item:getContainer() == container then
            container:Remove(item)
            square:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
        end
    end
end

local function transferAllItems(character, srcContainer, dstContainer, dropSq)
    if not (srcContainer and dstContainer) then return end
    local toMove = copyItemsToTable(srcContainer)
    for i = 1, #toMove do
        local item = toMove[i]
        if item and item:getContainer() == srcContainer then
            if ISTransferAction and ISTransferAction.transferItem then
                ISTransferAction:transferItem(character, item, srcContainer, dstContainer, dropSq)
            else
                srcContainer:DoRemoveItem(item)
                dstContainer:AddItem(item)
            end
        end
    end
end

local function createVanillaPlasticBag(player, dropSquare)
    local inventory = player and player:getInventory()
    if inventory and inventory.AddItem then
        return inventory:AddItem("Base.Plasticbag")
    end

    if dropSquare and dropSquare.AddWorldInventoryItem then
        return dropSquare:AddWorldInventoryItem("Base.Plasticbag", 0.0, 0.0, 0.0)
    end

    return nil
end

local function createVanillaToolbox(player, dropSquare)
    local inventory = player and player:getInventory()
    if inventory and inventory.AddItem then
        return inventory:AddItem(TOOLBOX_FULL_TYPE)
    end

    if dropSquare and dropSquare.AddWorldInventoryItem then
        return dropSquare:AddWorldInventoryItem(TOOLBOX_FULL_TYPE, 0.0, 0.0, 0.0)
    end

    return nil
end

local function transferVanillaBagToContainer(player, vanillaBag, containerItem, dropSquare)
    if not (vanillaBag and containerItem and containerItem.getInventory) then return end
    local vanillaBagInventory = vanillaBag:getInventory()
    local containerInventory = containerItem:getInventory()
    transferAllItems(player, vanillaBagInventory, containerInventory, dropSquare)
    removeItemFromContainer(vanillaBag)
end

local function transferContainerToVanillaBag(player, containerItem, vanillaBag, dropSquare)
    if not (vanillaBag and containerItem and containerItem.getInventory) then return end
    local containerInventory = containerItem:getInventory()
    local vanillaBagInventory = vanillaBag:getInventory()
    transferAllItems(player, containerInventory, vanillaBagInventory, dropSquare)
end

local function transferVanillaToolboxToContainer(player, vanillaToolbox, containerItem, dropSquare)
    if not (vanillaToolbox and containerItem and containerItem.getInventory) then return end
    local toolboxInventory = vanillaToolbox:getInventory()
    local containerInventory = containerItem:getInventory()
    transferAllItems(player, toolboxInventory, containerInventory, dropSquare)
    removeItemFromContainer(vanillaToolbox)
end

local function transferContainerToVanillaToolbox(player, containerItem, vanillaToolbox, dropSquare)
    if not (vanillaToolbox and containerItem and containerItem.getInventory) then return end
    local containerInventory = containerItem:getInventory()
    local toolboxInventory = vanillaToolbox:getInventory()
    transferAllItems(player, containerInventory, toolboxInventory, dropSquare)
end

local function removePlasticBagWeaponPartFromInventory(player, partType)
    if not player then return end
    local partFullType
    if partType == "PlasticBagLeft" then
        partFullType = "Bicycle.Bicycle_PlasticBagLeft"
    elseif partType == "PlasticBagRight" then
        partFullType = "Bicycle.Bicycle_PlasticBagRight"
    end
    if not partFullType then return end

    local inv = player:getInventory()
    if not inv then return end
    local partItem = findItemInContainer(inv, partFullType)
    if partItem then
        removeItemFromContainer(partItem)
    end
end

local function removeSportsbottleWeaponPartFromInventory(player)
    if not player then return end
    local inv = player:getInventory()
    if not inv then return end
    local partItem = findItemInContainer(inv, "Bicycle.Bicycle_Sportsbottle")
    if partItem then
        removeItemFromContainer(partItem)
    end
end

local function removeToolboxWeaponPartFromInventory(player)
    if not player then return end
    local inv = player:getInventory()
    if not inv then return end
    local partItem = findItemInContainer(inv, "Bicycle.Bicycle_Toolbox")
    if partItem then
        removeItemFromContainer(partItem)
    end
end

function BicycleAttachments.getSportsbottleWaterAmount(part)
    return getSportsbottleWaterAmountFromModData(part)
end

function BicycleAttachments.setSportsbottleWaterAmount(part, amount)
    return setSportsbottleWaterModData(part, amount)
end

function BicycleAttachments.captureSportsbottleWater(part, vanillaSportsbottle)
    return copyWaterToModData(part, vanillaSportsbottle)
end

function BicycleAttachments.applyWaterToVanillaSportsbottle(vanillaSportsbottle, amount)
    applyWaterAmountToVanillaSportsbottle(vanillaSportsbottle, amount)
end

local function removeTapedFlashlightWeaponPartFromInventory(player)
    if not player then return end
    local inv = player:getInventory()
    if not inv then return end
    local partItem = findItemInContainer(inv, "Bicycle.Bicycle_TapedFlashlight")
        or findItemInContainer(inv, "Bicycle.Bicycle_TapedImprovisedFlashlight")
    if partItem then
        removeItemFromContainer(partItem)
    end
end

local function getDropSquareForBike(bikeItem, player)
    local dropSquare = player and player.getSquare and player:getSquare() or nil
    if not dropSquare then
        local worldItem = bikeItem.getWorldItem and bikeItem:getWorldItem() or nil
        dropSquare = worldItem and worldItem:getSquare() or nil
    end
    if not dropSquare and getCell and bikeItem.getX and bikeItem.getY and bikeItem.getZ then
        local cell = getCell()
        if cell then
            dropSquare = cell:getGridSquare(bikeItem:getX(), bikeItem:getY(), bikeItem:getZ())
        end
    end
    return dropSquare
end

local function createVanillaSportsbottle(player, dropSquare, waterAmount)
    local inventory = player and player:getInventory()
    if inventory and inventory.AddItem then
        local bottle = inventory:AddItem(SPORTS_BOTTLE_FULL_TYPE)
        applyWaterAmountToVanillaSportsbottle(bottle, waterAmount)
        return bottle
    end

    if dropSquare and dropSquare.AddWorldInventoryItem then
        local bottle = dropSquare:AddWorldInventoryItem(SPORTS_BOTTLE_FULL_TYPE, 0.0, 0.0, 0.0)
        applyWaterAmountToVanillaSportsbottle(bottle, waterAmount)
        return bottle
    end

    return nil
end

local function createVanillaFlashlight(player, dropSquare, fullType, usedDelta)
    local inventory = player and player:getInventory()
    local flashlight
    if inventory and inventory.AddItem then
        flashlight = inventory:AddItem(fullType)
    elseif dropSquare and dropSquare.AddWorldInventoryItem then
        flashlight = dropSquare:AddWorldInventoryItem(fullType, 0.0, 0.0, 0.0)
    end
    if flashlight and usedDelta and flashlight.setUsedDelta then
        flashlight:setUsedDelta(usedDelta)
    end
    return flashlight
end

local function findDuctTapeWithCharges(inv)
    if not inv then return nil end
    local ductTape = inv:getFirstTypeRecurse(DUCT_TAPE_FULL_TYPE)
    if ductTape and ductTape.getCurrentUsesFloat and ductTape:getCurrentUsesFloat() >= DUCT_TAPE_USAGE then
        return ductTape
    end
    return nil
end

local function packContainerTo(bikeItem, def, srcContainer, destContainer, player)
    if not destContainer then return end
    if not ContainerGuards.isAllowedInvisibleDestination(destContainer) then
        return
    end
    local data = getContainerData(bikeItem, def.partType)
    if not data then return end
    local worldObj
    if data.x and data.y and data.z then
        worldObj = select(1, findWorldItemOnSquare(data.x, data.y, data.z, def.fullType, data.itemId))
    end
    if not worldObj then
        worldObj = select(1, adoptNearbyWorldItem(player and player:getSquare() or nil, def.fullType))
    end
    if worldObj then
        local item = takeWorldObjectToContainer(worldObj, destContainer)
        if item then
            ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, srcContainer, destContainer, 0))
            refreshPlayerInventories(player)
            storePackedLocation(data, destContainer)
        end
    end
end

function BicycleAttachments.followPlayer(player, bikeItem)
    if not player then return end
    bikeItem = bikeItem or player:getPrimaryHandItem()
    if not BicycleUtils.isBicycleItem(bikeItem) then return end
    if bikeItem.getWorldItem and bikeItem:getWorldItem() then
        -- If the bicycle is already placed in the world, don't try to move it.
        -- This prevents dropped bikes from being snapped back to the player when pressing
        -- the interact key near doors or fences.
        return
    end
    if bikeItem.isInPlayerInventory and not bikeItem:isInPlayerInventory() then
        return
    end
    followTick = followTick + 1
    if followTick < FOLLOW_UPDATE_INTERVAL then return end
    followTick = 0
    ensureContainersForBike(bikeItem, player, true)
    local square = player:getSquare()
    if not square then return end
    moveContainersToSquare(bikeItem, square)
end

function BicycleAttachments.onMount(player, bikeItem)
    if not player then return end
    bikeItem = bikeItem or player:getPrimaryHandItem()
    if not bikeItem then return end
    ensureContainersForBike(bikeItem, player, true)
    moveContainersToSquare(bikeItem, player:getSquare())
    ensureKickstandState(bikeItem, player, "up")
end

function BicycleAttachments.dropContainers(bikeItem, player)
    player = player or getSpecificPlayer(0)
    bikeItem = bikeItem or (player and player:getPrimaryHandItem())
    if not bikeItem then return end
    bikeItem = getBikeItem(bikeItem)
    if not BicycleUtils.isBicycleItem(bikeItem) then return end
    local square
    local worldObj = bikeItem:getWorldItem()
    if worldObj then
        square = worldObj:getSquare()
    end
    if not square and player then
        square = player:getSquare()
    end
    ensureContainersForBike(bikeItem, player, true)
    if square then
        moveContainersToSquare(bikeItem, square)
    end
end

local function snapContainersToBike(bikeItem, player)
    bikeItem = getBikeItem(bikeItem)
    if not bikeItem then return end
    local worldObj = bikeItem:getWorldItem()
    local square = worldObj and worldObj:getSquare() or (player and player:getSquare())
    if square then
        moveContainersToSquare(bikeItem, square)
    end
end

function BicycleAttachments.attachVanillaPlasticBag(test, player, bikeItem, vanillaBag)
    bikeItem = getBikeItem(bikeItem)
    if not (player and bikeItem and vanillaBag) then return end
    if vanillaBag:getFullType() ~= PLASTIC_BAG_FULL_TYPE then return end

    local partType = getMissingPlasticBagPartType(bikeItem)
    if not partType then return end

    local partFullType
    if partType == "PlasticBagLeft" then
        partFullType = "Bicycle.Bicycle_PlasticBagLeft"
    else
        partFullType = "Bicycle.Bicycle_PlasticBagRight"
    end
    if not partFullType then return end
    local inv = player:getInventory()
    if not inv then return end

    local part = inv:AddItem(partFullType)
    ISInventoryPaneContextMenu.onUpgradeWeapon(bikeItem, part, player, vanillaBag)
end

function BicycleAttachments.attachVanillaToolbox(test, player, bikeItem, vanillaToolbox)
    bikeItem = getBikeItem(bikeItem)
    if not (player and bikeItem and vanillaToolbox) then return end
    if vanillaToolbox:getFullType() ~= TOOLBOX_FULL_TYPE then return end
    if bikeItem:getWeaponPart("Toolbox") then return end
    if bikeItem:getWeaponPart("Crate") then return end

    local inv = player:getInventory()
    if not inv then return end

    local part = inv:AddItem("Bicycle.Bicycle_Toolbox")
    if not part then return end

    ISInventoryPaneContextMenu.onUpgradeWeapon(bikeItem, part, player, vanillaToolbox)
end

function BicycleAttachments.attachVanillaSportsbottle(test, player, bikeItem, vanillaSportsbottle)
    bikeItem = getBikeItem(bikeItem)
    if not (player and bikeItem and vanillaSportsbottle) then return end
    if vanillaSportsbottle:getFullType() ~= SPORTS_BOTTLE_FULL_TYPE then return end
    if not bikeItem:getWeaponPart("BottleHolder") then return end
    if bikeItem:getWeaponPart("Sportsbottle") then return end

    local inv = player:getInventory()
    if not inv then return end

    local part = inv:AddItem("Bicycle.Bicycle_Sportsbottle")
    copyWaterToModData(part, vanillaSportsbottle)
    ISInventoryPaneContextMenu.onUpgradeWeapon(bikeItem, part, player, vanillaSportsbottle)
end

local function attachTapedFlashlight(player, bikeItem, flashlight, ductTape, expectedFullType, partFullType)
    bikeItem = getBikeItem(bikeItem)
    if not (player and bikeItem and flashlight) then return end
    if flashlight:getFullType() ~= expectedFullType then return end
    if bikeHasLamp(bikeItem) then return end
    if bikeItem:getWeaponPart("TapedFlashlight") then return end

    local inv = player:getInventory()
    if not inv then return end

    local ductTapeItem = ductTape or findDuctTapeWithCharges(inv)
    if ductTapeItem and ductTapeItem.getCurrentUsesFloat and ductTapeItem:getCurrentUsesFloat() < DUCT_TAPE_USAGE then
        ductTapeItem = nil
    end
    if not ductTapeItem then return end

    local part = inv:AddItem(partFullType)
    if not part then return end

    if flashlight.getUsedDelta and part.setUsedDelta then
        part:setUsedDelta(flashlight:getUsedDelta())
    end

    local upgradeData = {
        flashlight = flashlight,
        ductTape = ductTapeItem,
        flashlightFullType = expectedFullType,
        partFullType = partFullType,
    }

    ISInventoryPaneContextMenu.onUpgradeWeapon(bikeItem, part, player, nil, upgradeData)
end

function BicycleAttachments.attachTapedFlashlight(test, player, bikeItem, flashlight, ductTape)
    attachTapedFlashlight(player, bikeItem, flashlight, ductTape, HAND_TORCH_FULL_TYPE, "Bicycle.Bicycle_TapedFlashlight")
end

function BicycleAttachments.attachImprovisedTapedFlashlight(test, player, bikeItem, flashlight, ductTape)
    attachTapedFlashlight(player, bikeItem, flashlight, ductTape, CRAFTED_FLASHLIGHT_FULL_TYPE, "Bicycle.Bicycle_TapedImprovisedFlashlight")
end

function BicycleAttachments.transferVanillaPlasticBag(player, vanillaBag, containerItem, dropSquare)
    dropSquare = dropSquare or (player and player.getSquare and player:getSquare())
    transferVanillaBagToContainer(player, vanillaBag, containerItem, dropSquare)
    refreshPlayerInventories(player)
end

function BicycleAttachments.transferVanillaToolbox(player, vanillaToolbox, containerItem, dropSquare)
    dropSquare = dropSquare or (player and player.getSquare and player:getSquare())
    transferVanillaToolboxToContainer(player, vanillaToolbox, containerItem, dropSquare)
    refreshPlayerInventories(player)
end

function BicycleAttachments.isPlasticBagPartType(partType)
    return isPlasticBagPartType(partType)
end

function BicycleAttachments.transferContainersToContainer(player, bikeItem, srcContainer, destContainer)
    bikeItem = getBikeItem(bikeItem)
    if not bikeItem then return end
    ensureContainersForBike(bikeItem, player, true)
    local destAllowed = ContainerGuards.isAllowedInvisibleDestination(destContainer)
    if not destAllowed and player and player.getSquare then
        local square = player:getSquare()
        if square then
            moveContainersToSquare(bikeItem, square)
        end
    end
    for key, def in pairs(CONTAINER_TYPES) do
        if bikeHasPart(bikeItem, def.partType) or def.fullType == bikeItem:getFullType() then
            if destAllowed then
                packContainerTo(bikeItem, def, srcContainer, destContainer, player)
            end
        end
    end
    refreshPlayerInventories(player)
end

function BicycleAttachments.transferContainersFromContainer(player, bikeItem, srcContainer, dropSquare, destContainer)
    bikeItem = getBikeItem(bikeItem)
    if not bikeItem then return end
    dropSquare = dropSquare or (player and player:getSquare())
    for key, def in pairs(CONTAINER_TYPES) do
        local data = getContainerData(bikeItem, def.partType)
        if data then
            local item = findItemInContainer(srcContainer, def.fullType)
            if item then
                removeItemFromContainer(item)
                if destContainer and ContainerGuards.isAllowedInvisibleDestination(destContainer) then
                    destContainer:AddItem(item)
                    storePackedLocation(data, destContainer)
                elseif dropSquare then
                    dropSquare:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
                    local worldObj = item:getWorldItem()
                    if worldObj then
                        setDataForWorldObject(data, worldObj)
                    end
                    data.storage = nil
                else
                    local square = player and player:getSquare()
                    if square then
                        square:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
                        local worldObj = item:getWorldItem()
                        if worldObj then
                            setDataForWorldObject(data, worldObj)
                        end
                    else
                        storePackedLocation(data, nil)
                    end
                end
            end
        end
    end
    refreshPlayerInventories(player)
end

function BicycleAttachments.onBikeDropped(player, bikeItem, dismountData)
    bikeItem = getBikeItem(bikeItem)
    if not bikeItem then return end
    local skipRotation = type(dismountData) == "table" and dismountData.skipRotation == true
    local kickstandTarget = "down"
    if dismountData then
        if dismountData.kickstandDown == false then
            kickstandTarget = "up"
        elseif dismountData.kickstandDown == true then
            kickstandTarget = "down"
        end
    end

    ensureKickstandState(bikeItem, player, kickstandTarget)
    ensureContainersForBike(bikeItem, player, true)
    snapContainersToBike(bikeItem, player)
    if skipRotation then
        return
    end
    applyDroppedBikeTransform(player, bikeItem, dismountData)
end

function BicycleAttachments.onAttachmentRemoved(player, bikeItem, partType)
    bikeItem = getBikeItem(bikeItem)
    if not (bikeItem and partType) then return end

    if partType == "KickstandDown" then
        local worldObj = bikeItem.getWorldItem and bikeItem:getWorldItem() or nil
        if worldObj then
            local direction = player and player.getDir and player:getDir() or nil
            local zRotation = direction and BicycleUtils.directionToZRotation(direction) or nil
            layDownBicycle(worldObj, direction, zRotation, true)
        end
        return
    end

    if partType == "FrontWheel" or partType == "RearWheel" then
        local worldObj = bikeItem.getWorldItem and bikeItem:getWorldItem() or nil
        if worldObj then
            local direction = player and player.getDir and player:getDir() or nil
            local zRotation = direction and BicycleUtils.directionToZRotation(direction) or nil
            if bikeItem:getWeaponPart("KickstandDown") then
                layDownBicycle(worldObj, direction, zRotation, true)
            else
                local currentX = worldObj and worldObj.getItem and worldObj:getItem() and worldObj:getItem():getWorldXRotation() or 0
                local item = worldObj:getItem()
                if item and item.setWorldXRotation then
                    item:setWorldXRotation((currentX or 0) + 1)
                end
            end
        end
        return
    end

    if partType == "Sportsbottle" then
        local dropSquare = getDropSquareForBike(bikeItem, player)

        local inv = player and player:getInventory()
        local partItem = inv and findItemInContainer(inv, "Bicycle.Bicycle_Sportsbottle") or nil

        local part = bikeItem:getWeaponPart(partType)
        local storedWater = getSportsbottleWaterAmountFromModData(part)
        if storedWater <= 0 then
            storedWater = getSportsbottleWaterAmountFromModData(partItem)
        end

        createVanillaSportsbottle(player, dropSquare, storedWater)
        BicycleUtils.runAfter(0.2, function()
            removeSportsbottleWeaponPartFromInventory(player)
        end)

        if player then
            refreshPlayerInventories(player)
        end
        return
    end

    if partType == "TapedFlashlight" then
        local dropSquare = getDropSquareForBike(bikeItem, player)
        local inv = player and player:getInventory()
        local partItem = inv and (findItemInContainer(inv, "Bicycle.Bicycle_TapedFlashlight")
            or findItemInContainer(inv, "Bicycle.Bicycle_TapedImprovisedFlashlight"))
        local flashlightFullType = HAND_TORCH_FULL_TYPE
        if partItem and partItem.getFullType and partItem:getFullType() == "Bicycle.Bicycle_TapedImprovisedFlashlight" then
            flashlightFullType = CRAFTED_FLASHLIGHT_FULL_TYPE
        end
        local usedDelta = partItem and partItem.getUsedDelta and partItem:getUsedDelta() or nil

        createVanillaFlashlight(player, dropSquare, flashlightFullType, usedDelta)
        BicycleUtils.runAfter(0.2, function()
            removeTapedFlashlightWeaponPartFromInventory(player)
        end)

        if player then
            refreshPlayerInventories(player)
        end
        return
    end
    local def = CONTAINER_TYPES[partType]
    if not def then return end
    local data = getContainerData(bikeItem, partType)
    local dropSquare = player and player.getSquare and player:getSquare() or nil
    if not dropSquare then
        local worldItem = bikeItem.getWorldItem and bikeItem:getWorldItem() or nil
        dropSquare = worldItem and worldItem:getSquare() or nil
    end
    if not dropSquare and data and data.x and data.y and data.z and getCell then
        local cell = getCell()
        if cell then
            dropSquare = cell:getGridSquare(data.x, data.y, data.z)
        end
    end

    local worldObj = ensureWorldContainer(bikeItem, def, dropSquare, player, false)
    local existingItem = worldObj and worldObj:getItem() or nil
    if worldObj and not dropSquare then
        dropSquare = worldObj:getSquare()
    end

    if not existingItem and data and data.packed then
        existingItem = findPackedContainerItem(bikeItem, def, player)
    end

    if not existingItem and player then
        existingItem = findItemInContainer(player:getInventory(), def.fullType)
    end

    if existingItem and existingItem:getContainer() then
        removeItemFromContainer(existingItem)
    end

    local vanillaContainer
    local transferToVanilla
    if isPlasticBagPartType(partType) then
        vanillaContainer = createVanillaPlasticBag(player, dropSquare)
        transferToVanilla = transferContainerToVanillaBag
    elseif partType == "Toolbox" then
        vanillaContainer = createVanillaToolbox(player, dropSquare)
        transferToVanilla = transferContainerToVanillaToolbox
    end

    if vanillaContainer and existingItem and transferToVanilla then
        transferToVanilla(player, existingItem, vanillaContainer, dropSquare)
    elseif existingItem and dropSquare then
        dropContainerContentsOnSquare(existingItem, dropSquare)
    elseif existingItem and player and player.getSquare then
        local square = player:getSquare()
        if square then
            dropContainerContentsOnSquare(existingItem, square)
            dropSquare = square
        end
    end

    if worldObj then
        if worldObj.removeFromSquare then worldObj:removeFromSquare() end
        if worldObj.removeFromWorld then worldObj:removeFromWorld() end
    elseif existingItem then
        removeItemFromContainer(existingItem)
    end

    clearContainerData(data)

    if partType == "Toolbox" then
        BicycleUtils.runAfter(0.2, function()
            removeToolboxWeaponPartFromInventory(player)
        end)
    elseif isPlasticBagPartType(partType) then
        BicycleUtils.runAfter(0.2, function()
            removePlasticBagWeaponPartFromInventory(player, partType)
        end)
    end

    if player then
        refreshPlayerInventories(player)
    end
end

function BicycleAttachments.FindBicycle(player)
    if not player then return nil end
    local square = player:getSquare()
    if not square then return nil end
    local cell = getCell and getCell()
    if not cell then return nil end
    local best, bestDist
    local x, y, z = square:getX(), square:getY(), square:getZ()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(x + dx, y + dy, z)
            if sq and sq.getWorldObjects then
                local list = sq:getWorldObjects()
                for i = 0, list:size() - 1 do
                    local wo = list:get(i)
                    local item = wo and wo:getItem() or nil
                    if BicycleUtils.isBicycleItem(item) then
                        local dist = (sq:getX() - x) * (sq:getX() - x) + (sq:getY() - y) * (sq:getY() - y)
                        if not best or dist < bestDist then
                            best, bestDist = wo, dist
                        end
                    end
                end
            end
        end
    end
    return best
end

function BicycleAttachments.FindFloorItem(player, item)
    if not player then return nil end
    local square = player:getSquare()
    if not square then return nil end
    local cell = getCell and getCell()
    if not cell then return nil end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local best, bestDist
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(x + dx, y + dy, z)
            if sq and sq.getWorldObjects then
                local list = sq:getWorldObjects()
                for i = 0, list:size() - 1 do
                    local wo = list:get(i)
                    local worldItem = wo and wo:getItem() or nil
                    if worldItem and string.find(worldItem:getType(), item) then
                        local dist = (sq:getX() - x) * (sq:getX() - x) + (sq:getY() - y) * (sq:getY() - y)
                        if not best or dist < bestDist then
                            best, bestDist = wo, dist
                        end
                    end
                end
            end
        end
    end
    return best
end

function BicycleAttachments.FindInventoryItem(player, item)
    if not player then return nil end
    local bags = player:getInventory():getAllCategory("Container")
    if not bags then return nil end
    for i = 0, bags:size() - 1 do
        local bag = bags:get(i)
        if bag and bag.getInventory then
            local foundItem = bag:getInventory():getFirstTypeRecurse("Bicycle." .. item)
            if foundItem then
                return foundItem, bag
            end
        end
    end
    return nil
end

function BicycleAttachments.FindEquippedItem(player, item)
    if not player then return nil end
    local inv = player:getInventory()
    if not inv then return nil end
    return inv:getFirstTypeRecurse("Bicycle." .. item)
end

local originalTransferIsValid = ISInventoryTransferAction.isValid

local function isTrunkType(containerType)
    if not containerType then return false end
    if containerType == "TruckBed" or containerType == "TruckBedOpen" or containerType == "TrailerTrunk" then
        return true
    end
    return containerType:find("Trunk") ~= nil
end

local function isTrunkContainer(container)
    if ContainerGuards.isVehicleTrunkContainer(container) then
        return true
    end
    local containerType = container and container.getType and container:getType() or nil
    return isTrunkType(containerType)
end

local function isInvisibleContainerItem(item)
    return ContainerGuards.isInvisibleContainerItem(item)
end

local function canTransferBicycleToPlayerInventory()
    if not (PZAPI and PZAPI.ModOptions) then
        return false
    end
    local options = PZAPI.ModOptions:getOptions("BicycleMod")
    if not options then
        return false
    end
    local option = options:getOption("BicycleTransferInv")
    if not option then
        return false
    end
    return option:getValue() == true
end

function ISInventoryTransferAction:isValid()
    if BicycleUtils.isBicycleItem(self.item) or isInvisibleContainerItem(self.item) then
        if self.bicycleMount then
            return true
        end
        local character = self.character
        local bikeItem = self.item
        local destContainer = self.destContainer
        local srcContainer = self.srcContainer
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

        self:setOnComplete(function(player, bike, src, dest, dropToFloor, destTrunk, destPlayerInv, srcTrunk, srcPlayerInv)
            local shouldFollowPlayer = false

            if srcTrunk then
                local playerSquare = player and player:getSquare() or nil
                BicycleAttachments.transferContainersFromContainer(player, bike, src, playerSquare, nil)
                if destPlayerInv then
                    shouldFollowPlayer = true
                end
            elseif srcPlayerInv and dropToFloor then
                BicycleAttachments.transferContainersFromContainer(player, bike, src, player and player:getSquare(), nil)
            end

            if destTrunk or (destPlayerInv and not (srcTrunk or dropToFloor)) then
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
        end, character, bikeItem, srcContainer, destContainer, destIsFloor, destIsTrunk, destIsPlayerInv, srcIsTrunk, srcIsPlayerInv)
        return true
    end
    return originalTransferIsValid(self)
end


function FindBicycle(player)
    return BicycleAttachments.FindBicycle(player)
end

function FindFloorItem(player, item)
    return BicycleAttachments.FindFloorItem(player, item)
end

function FindInventoryItem(player, item)
    return BicycleAttachments.FindInventoryItem(player, item)
end

function FindEquippedItem(player, item)
    return BicycleAttachments.FindEquippedItem(player, item)
end

local function removeBasket()
    ISSearchManager.ignoredItemTypes = ISSearchManager.ignoredItemTypes or {}
    ISSearchManager.ignoredItemTypes["Bicycle.Saddlebag"] = true
    ISSearchManager.ignoredItemTypes["Bicycle.ToolboxContainer"] = true
    ISSearchManager.ignoredItemTypes["Bicycle.Crate"] = true
    ISSearchManager.ignoredItemTypes["Bicycle.Basket"] = true
    ISSearchManager.ignoredItemTypes["Bicycle.PlasticBagLeft"] = true
    ISSearchManager.ignoredItemTypes["Bicycle.PlasticBagRight"] = true
end

Events.OnGameStart.Add(removeBasket)
Events.OnConnected.Add(removeBasket)

return BicycleAttachments
