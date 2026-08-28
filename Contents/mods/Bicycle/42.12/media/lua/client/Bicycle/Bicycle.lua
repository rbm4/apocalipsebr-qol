require "DebugUIs/AttachmentEditorUI"
require "ISUI/ISInventoryPaneContextMenu"
require('ISUI/ISScrollingListBox')
require('Vehicles/ISUI/ISUI3DScene')

local BicycleAttachments = require("Bicycle/SaddleBag/Saddlebag")
local BicycleDismountAction = require("Bicycle/TimedAction/BicycleDismountAction")
local BicycleThrowOverFenceAction = require("Bicycle/TimedAction/BicycleThrowOverFenceAction")
local BicycleUtils = require("Bicycle/Utils")

BicycleMenu = {};
BicycleMenu.typesTable = BicycleUtils.getBicycleTypes()
BicycleMenu.EquipHoldThresholdMs = 500

local function cancelBicycleTimedActions(playerObj)
    if not (playerObj and ISTimedActionQueue and ISTimedActionQueue.getTimedActionQueue) then
        return
    end

    local queue = ISTimedActionQueue.getTimedActionQueue(playerObj)

    for i = #queue.queue, 1, -1 do
        local action = queue.queue[i]
        if action and (action.Type == "BicycleHopOnAction" or action.Type == "BicycleDismountAction" or action.Type == "BicycleThrowOverFenceAction") then
            table.remove(queue.queue, i)
        end
    end
end

local function removeBicycleWorldItem(bicycleItem)
    if not (bicycleItem and bicycleItem.getWorldItem) then
        return
    end

    local worldItem = bicycleItem:getWorldItem()
    if not worldItem then
        return
    end

    local worldSq = worldItem.getSquare and worldItem:getSquare() or nil
    if worldSq then
        worldSq:transmitRemoveItemFromSquare(worldItem)
        if worldSq.removeWorldObject then
            worldSq:removeWorldObject(worldItem)
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

    if bicycleItem.setWorldItem then
        bicycleItem:setWorldItem(nil)
    end
end

BicycleMenu.removeWorldItem = removeBicycleWorldItem

local equipKeyState = {
    isDown = false,
    startMs = 0,
    actionTriggered = false,
}

local function isBicycleItem(item)
    return BicycleUtils.isBicycleItem(item)
end

local function hasBicycleInteractionTarget(pzPlayer)
    if not pzPlayer then
        return false
    end

    local currentItem = pzPlayer:getPrimaryHandItem()
    if currentItem and currentItem.isEquipped and not currentItem:isEquipped() then
        currentItem = nil
    end

    if isBicycleItem(currentItem) then
        return true
    end

    local sq = pzPlayer:getSquare()
    if not sq then
        return false
    end

    local closestBicycle = BicycleMenu.findNearestBicycleWithAttachments(sq, pzPlayer)
    return closestBicycle ~= nil
end

local function isBicycleType(itemType)
    return BicycleUtils.isBicycleType(itemType)
end

local function squareHasHoppable(square)
    if not square or not square.getObjects then
        return false
    end

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj.isHoppable and obj:isHoppable() then
            return true
        end
    end

    return false
end

local function playerNearHoppableFence(pzPlayer)
    if not pzPlayer then
        return false
    end

    local sq = pzPlayer:getSquare()
    if not sq then
        return false
    end

    if squareHasHoppable(sq) then
        return true
    end

    local neighbors = { sq:getN(), sq:getS(), sq:getE(), sq:getW() }
    for _, neighbor in ipairs(neighbors) do
        if squareHasHoppable(neighbor) then
            return true
        end
    end

    return false
end

local BICYCLE_WEAR_INTERVAL = 13500
local BICYCLE_WEAR_CONDITION_LOSS = 0.1

local function isTruckBedId(partId)
    if not partId then return false end
    return string.find(partId, "TruckBed", 1, true) ~= nil
end

local function isTruckBedPart(vehicle, part)
    if not part then return false end

    if not isTruckBedId(part:getId()) then
        return false
    end

    if vehicle then
        local trunkDoorPart = vehicle:getPartById("TrunkDoor") or vehicle:getPartById("DoorRear")
        if trunkDoorPart and (trunkDoorPart:getDoor() or trunkDoorPart:getInventoryItem()) then
            return false
        end
    end

    local area = part:getArea()
    if area then
        local lowerArea = string.lower(area)
        if string.find(lowerArea, "trunk", 1, true) or string.find(lowerArea, "boot", 1, true) then
            return false
        end
    end

    return true
end

local function drainPartCondition(part, amount)
    if not part or not part.getCondition then
        return false
    end

    local current = part:getCondition()
    if current <= 0 then
        return part:isBroken() == true
    end

    part:setCondition(math.max(0, current - amount))

    return part:isBroken() == true
end

local function handleBrokenAttachment(playerObj, bicycleItem, part)
    if not (playerObj and bicycleItem and part) then
        return
    end

    local dropSquare = playerObj.getSquare and playerObj:getSquare() or nil
    if not dropSquare and bicycleItem.getWorldItem then
        local worldObj = bicycleItem:getWorldItem()
        dropSquare = worldObj and worldObj:getSquare() or nil
    end

    local function dropBicycle()
        if not dropSquare then
            return
        end

        local container = bicycleItem.getContainer and bicycleItem:getContainer() or nil
        if container and container.DoRemoveItem then
            container:DoRemoveItem(bicycleItem)
        elseif container and container.Remove then
            container:Remove(bicycleItem)
        end

        dropSquare:AddWorldInventoryItem(bicycleItem, 0, 0, 0)
    end

    bicycleItem:detachWeaponPart(playerObj, part)

    if dropSquare then
        dropSquare:AddWorldInventoryItem(part, 0, 0, 0)
    else
        playerObj:getInventory():AddItem(part)
    end

    syncHandWeaponFields(playerObj, bicycleItem)
    BicycleMenu.onCompleteDrop(playerObj, bicycleItem)
    dropBicycle()
end

local function findVehicleStoragePart(vehicle)
    if not vehicle then return nil end

    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        if part and part:getItemContainer() then
            local id = part:getId()
            if id then
                if id ~= "TrunkDoor" and string.find(id, "Trunk", 1, true) then
                    return part
                end
                if isTruckBedId(id) then
                    return part
                end
            end
        end
    end

    return nil
end

local function bicycleHasLamp(bicycleItem)
    if not bicycleItem then return false end
    return bicycleItem and bicycleItem:getWeaponPart("Lamp") ~= nil
end

local function bicycleHasTapedFlashlight(bicycleItem)
    if not bicycleItem then return false end
    return bicycleItem and bicycleItem:getWeaponPart("TapedFlashlight") ~= nil
end

local function bicycleHasBottleHolder(bicycleItem)
    if not bicycleItem then return false end
    return bicycleItem and bicycleItem:getWeaponPart("BottleHolder") ~= nil
end

local function bicycleHasBell(bicycleItem)
    if not bicycleItem then return false end
    return bicycleItem and bicycleItem:getWeaponPart("Bell") ~= nil
end

local function updateBicycleShoutState(player, bicycleItem)
    if not player then
        return false
    end

    local hasBell = bicycleHasBell(bicycleItem)
    if player.setCanShout then
        player:setCanShout(not hasBell)
    end

    return hasBell
end

BicycleMenu.bicycleHasBell = bicycleHasBell
BicycleMenu.updateBicycleShoutState = updateBicycleShoutState

local wheelPartTypes = {
    FrontWheel = true,
    RearWheel = true,
}

local function isWheelPartType(partType)
    return partType and wheelPartTypes[partType] == true
end

local function applyFlatWheelName(part)
    if not part then
        return
    end

    local name = part:getDisplayName()
    if not string.find(name, " (Flat)", 1, true) then
        part:setName(name .. " (Flat)")
    end
    part:setCustomName(true)
end

local function bicycleHasChain(bicycleItem)
    return bicycleItem and bicycleItem:getWeaponPart("Chain") ~= nil
end

local function createPart(fullType)
    if not instanceItem then
        return nil
    end

    return instanceItem(fullType)
end

local function rollHighCondition()
    local highConditionFloor = 115 -- ~90% of 127
    if ZombRand(100) < 70 then
        return ZombRand(highConditionFloor, 128)
    end

    return ZombRand(0, highConditionFloor + 1)
end

local function createWheel(fullType)
    local wheel = createPart(fullType)
    if not wheel then
        return nil
    end

    if wheel.setCondition then
        wheel:setCondition(rollHighCondition())
    end

    if wheel.getModData and ZombRand(100) < 2 then
        wheel:getModData().flat = true
    end

    return wheel
end

local function attachPart(item, part)
    if item and part and item.attachWeaponPart then
        item:attachWeaponPart(part, true)
    end
end

local function createChain()
    local chain = createPart("Bicycle.Bicycle_Chain")
    if chain and chain.setCondition then
        chain:setCondition(rollHighCondition())
    end

    return chain
end

local function chooseWheelTypes()
    local preferStreet = ZombRand(100) < 75
    if preferStreet then
        return "Bicycle.Bicycle_StreetWheelFrontItem", "Bicycle.Bicycle_StreetWheelRearItem"
    end

    return "Bicycle.Bicycle_OffroadWheelFrontItem", "Bicycle.Bicycle_OffroadWheelRearItem"
end

local function attachOptionalPart(item, partFullType, chance)
    if ZombRand(100) < chance then
        attachPart(item, createPart(partFullType))
    end
end

local wheelTypeByName = {
    Bicycle_StreetWheelFrontItem = "street",
    Bicycle_StreetWheelRearItem = "street",
    Bicycle_OffroadWheelFrontItem = "offroad",
    Bicycle_OffroadWheelRearItem = "offroad",
}

BicycleMenu.OffroadSpeedMultiplier = 0.85

BicycleMenu.getAttachedWheels = function(bicycleItem, pzPlayer)
    local attachedWheels = {}

    local parts = bicycleItem and bicycleItem.getDetachableWeaponParts and bicycleItem:getDetachableWeaponParts(pzPlayer)
    if not parts then
        return attachedWheels
    end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part and isWheelPartType(part:getPartType()) then
            if part:getModData().flat == true then
                applyFlatWheelName(part)
            end
            table.insert(attachedWheels, {
                part = part,
                wheelType = wheelTypeByName[part:getType()],
                isFlat = part:getModData().flat == true,
            })
        end
    end

    return attachedWheels
end

BicycleMenu.getWheelConfiguration = function(bicycleItem, pzPlayer)
    local wheelConfig = {
        street = 0,
        offroad = 0,
    }

    local parts = bicycleItem and bicycleItem.getDetachableWeaponParts and bicycleItem:getDetachableWeaponParts(pzPlayer)
    if not parts then
        wheelConfig.total = 0
        return wheelConfig
    end

    for i = 0, parts:size() - 1 do
        local wheelType = wheelTypeByName[parts:get(i):getType()]
        if wheelType then
            wheelConfig[wheelType] = wheelConfig[wheelType] + 1
        end
    end

    wheelConfig.total = wheelConfig.street + wheelConfig.offroad

    return wheelConfig
end

local function bicycleHasRideRequirements(bicycleItem, pzPlayer)
    local wheelConfig = BicycleMenu.getWheelConfiguration(bicycleItem, pzPlayer)
    if wheelConfig.total == 0 then
        return false, getText("IGUI_Bicycle_MissingBothWheels"), wheelConfig
    end

    if wheelConfig.total < 2 then
        return false, getText("IGUI_Bicycle_MissingWheel"), wheelConfig
    end

    if not bicycleHasChain(bicycleItem) then
        return false, getText("IGUI_Bicycle_MissingChain"), wheelConfig
    end

    return true, nil, wheelConfig
end

local function removeVanillaUpgradeOptions(context)
    context:removeOptionByName(getText("ContextMenu_Add_Weapon_Upgrade"))
    context:removeOptionByName(getText("ContextMenu_Remove_Weapon_Upgrade"))
end

BicycleMenu.canAttachFrontWheelAsRear = function(bicycleItem, part)
    if not (bicycleItem and part and part.getPartType) then
        return false
    end

    if part:getPartType() ~= "FrontWheel" then
        return false
    end

    local hasFront = bicycleItem:getWeaponPart("FrontWheel") ~= nil
    local hasRear = bicycleItem:getWeaponPart("RearWheel") ~= nil

    return hasFront and not hasRear
end

BicycleMenu.canAttachPart = function(bicycleItem, part, player)
    if not bicycleItem or not part then
        return false
    end

    local partType = part:getPartType()
    local canAttachConvertedFrontWheel = BicycleMenu.canAttachFrontWheelAsRear(bicycleItem, part)

    if partType == "Lamp" and bicycleHasTapedFlashlight(bicycleItem) then
        return false
    end

    if partType == "TapedFlashlight" and bicycleHasLamp(bicycleItem) then
        return false
    end

    if partType == "Sportsbottle" and not bicycleHasBottleHolder(bicycleItem) then
        return false
    end

    if partType == "Crate" and bicycleItem:getWeaponPart("Toolbox") then
        return false
    end

    if partType == "Toolbox" and bicycleItem:getWeaponPart("Crate") then
        return false
    end

    if partType == "TapedFlashlight" then
        local inv = player and player.getInventory and player:getInventory() or nil
        if not inv then
            return false
        end
        local hasDuctTape = inv:getFirstTypeRecurse("Base.DuctTape") ~= nil
        local hasFlashlight = inv:getFirstTypeRecurse("Base.HandTorch")
            or inv:getFirstTypeRecurse("Base.Flashlight_Crafted")
        if not (hasDuctTape and hasFlashlight) then
            return false
        end
    end

    if bicycleItem:getWeaponPart(partType) and not canAttachConvertedFrontWheel then
        return false
    end

    return true
end

local function syncWheelWearModData(part, elapsed)
    local modData = part:getModData()
    modData.bicycleWearElapsed = elapsed
    if part.transmitModData then
        part:transmitModData()
    end
end


local function syncChainWearModData(part, elapsed)
    local modData = part:getModData()
    modData.bicycleWearElapsed = elapsed
    if part.transmitModData then
        part:transmitModData()
    end
end

local function rollFlatTireChance(playerObj, wheel, part, isRoughSurface)
    if not wheel or not part or wheel.isFlat then
        return false
    end

    local chance = 0
    if isRoughSurface and wheel.wheelType == "street" then
        chance = 0.00001
    end

    if ZombRandFloat(0.0, 1.0) < chance then
        local modData = part:getModData()
        wheel.isFlat = true
        modData.flat = true
        applyFlatWheelName(part)
        local emitter = playerObj and playerObj.getEmitter and playerObj:getEmitter() or nil
        if emitter then
            local volume = PZAPI.ModOptions:getOptions("BicycleMod"):getOption("BicycleSoundVolume"):getValue()
            local sound = emitter:playSound('Bicycle_FlatTire')
            emitter:setVolume(sound, volume)
        end
        return true
    end

    return false
end

local function handleChainWear(playerObj, bicycleItem, delta)
    local part = bicycleItem and bicycleItem.getWeaponPart and bicycleItem:getWeaponPart("Chain") or nil
    if not part then
        return false
    end

    local modData = part:getModData()
    local elapsed = modData.bicycleWearElapsed or 0

    elapsed = elapsed + delta

    local conditionChanged = false

    while elapsed >= BICYCLE_WEAR_INTERVAL do
        elapsed = elapsed - BICYCLE_WEAR_INTERVAL

        if drainPartCondition(part, BICYCLE_WEAR_CONDITION_LOSS) then
            handleBrokenAttachment(playerObj, bicycleItem, part)
            syncChainWearModData(part, elapsed)
            return true
        end

        conditionChanged = true
    end

    if conditionChanged or (modData.bicycleWearElapsed or 0) ~= elapsed then
        syncChainWearModData(part, elapsed)
    end

    return false
end


local function handleWheelWear(playerObj, bicycleItem, wheel, delta, isRoughSurface)
    local part = wheel.part
    if not part then
        return false
    end

    rollFlatTireChance(playerObj, wheel, part, isRoughSurface)

    local modData = part:getModData()
    local elapsed = modData.bicycleWearElapsed or 0

    elapsed = elapsed + delta

    local conditionChanged = false

    while elapsed >= BICYCLE_WEAR_INTERVAL do
        local conditionLoss = BICYCLE_WEAR_CONDITION_LOSS

        if isRoughSurface and wheel.wheelType == "street" then
            conditionLoss = conditionLoss * 5
        end

        if wheel.isFlat then
            conditionLoss = conditionLoss * 100
        end

        elapsed = elapsed - BICYCLE_WEAR_INTERVAL

        if drainPartCondition(part, conditionLoss) then
            handleBrokenAttachment(playerObj, bicycleItem, part)
            syncWheelWearModData(part, elapsed)
            return true
        end
        conditionChanged = true
    end

    if conditionChanged or (modData.bicycleWearElapsed or 0) ~= elapsed then
        syncWheelWearModData(part, elapsed)
    end

    return false
end

BicycleMenu.drainWearParts = function(playerObj, bicycleItem)
    if not bicycleItem then
        return
    end

    local delta = GameTime.getInstance():getTimeDelta()
    -- Prevent huge offline deltas from draining parts instantly after loading.
    delta = math.min(delta, BICYCLE_WEAR_INTERVAL)
    if delta <= 0 then
        return
    end
    local isRoughSurface = BicycleHopOnAction.squareIsRough(playerObj:getSquare())
    local attachedWheels = BicycleMenu.getAttachedWheels(bicycleItem, playerObj)

    for _, wheel in ipairs(attachedWheels) do
        if handleWheelWear(playerObj, bicycleItem, wheel, delta, isRoughSurface) then
            return
        end
    end

    if handleChainWear(playerObj, bicycleItem, delta) then
        return
    end
end

BicycleMenu.onCompleteDrop = function(playerObj, weapon, dismountData)
    playerObj:removeFromHands(weapon);
    BicycleAttachments.onBikeDropped(playerObj, weapon, dismountData)
    local pdata = getPlayerData(0)
    if pdata and pdata.playerInventory then
        pdata.playerInventory:refreshBackpacks()
        pdata.lootInventory:refreshBackpacks()
    end
    BicycleClearUpdateHandlers()
    local emitter = playerObj:getEmitter()
    emitter:stopSoundByName('Bicycle_Riding')
    playerObj:setVariable("Bicycle_Riding", "false")
    playerObj:setVariable("BicycleActive", "false")
    playerObj:setBlockMovement(false)
    playerObj:setIgnoreMovement(false)
    playerObj:setTurnDelta(1)
    playerObj:setVariable("mountAnim", "")
    playerObj:setVariable("Bicycle_Stopping", false)
    playerObj:setAllowRun(true)
    playerObj:setForceSprint(false)
    playerObj:setCanShout(true)
    playerObj:setBannedAttacking(false)
    playerObj:setIgnoreAutoVault(false)
    playerObj:setVariable("Dismounting", false)
    playerObj:setVariable("DismountKickstand", false)
    playerObj:setVariable("dismountAnim", "")
end

BicycleMenu.dropBicycleAtSquare = function(playerObj, bicycleItem, targetSquare, dismountData)
    if not (playerObj and bicycleItem and targetSquare) then
        return
    end

    removeBicycleWorldItem(bicycleItem)

    local container = bicycleItem.getContainer and bicycleItem:getContainer() or nil
    if container then
        if container.DoRemoveItem then
            container:DoRemoveItem(bicycleItem)
        elseif container.Remove then
            container:Remove(bicycleItem)
        end
    end

    targetSquare:AddWorldInventoryItem(bicycleItem, 0, 0, 0)
    BicycleMenu.onCompleteDrop(playerObj, bicycleItem, dismountData)
end
BicycleMenu.dropBicycle = function(worldobjects,items,player,isHold, stopOnWalk, stopOnRun, actionMaxTime)
    local pzPlayer = getSpecificPlayer(player)
    local current_weapon = pzPlayer:getPrimaryHandItem()
    if not current_weapon or not isBicycleItem(current_weapon) then
        return
    end
    cancelBicycleTimedActions(pzPlayer)
    local runKey = getCore():getKey("Run")
    local shiftHeld = runKey and runKey >= 0 and isKeyDown(runKey)
    local bicycleItem = items and items[1]
    local hasKickstand = bicycleItem and bicycleItem.getWeaponPart and bicycleItem:getWeaponPart("KickstandUp") ~= nil
    local isHeld = isHold == true
    local dismountAnim = isHeld and "kickstandDown" or "throwBicycle"
    local resolvedMaxTime = actionMaxTime
    if resolvedMaxTime == nil then
        resolvedMaxTime = isHeld and 90 or 50
    end
    pzPlayer:setVariable("dismountAnim", dismountAnim)
    local dismountRotation = BicycleUtils.directionToZRotation(pzPlayer:getDir())
    local action = BicycleDismountAction:new(
        pzPlayer,
        bicycleItem,
        {
            shiftHeld = shiftHeld,
            direction = pzPlayer:getDir(),
            zRotation = dismountRotation,
            dismountAnim = dismountAnim,
            kickstandDown = (isHeld and not shiftHeld and hasKickstand),
        },
        BicycleMenu.onCompleteDrop,
        stopOnWalk,
        stopOnRun,
        resolvedMaxTime
    )
    ISTimedActionQueue.add(action)
end

BicycleMenu.throwBicycleOverFence = function(worldobjects, player, bicycleItem, maxTime)
    local pzPlayer = getSpecificPlayer(player)
    if not (pzPlayer and bicycleItem) then
        return
    end

    local action = BicycleThrowOverFenceAction:new(pzPlayer, bicycleItem, maxTime)
    ISTimedActionQueue.add(action)
end

BicycleMenu.addEquippedContextOptions = function(pzPlayer, context, worldobjects)
    local current_weapon = pzPlayer:getPrimaryHandItem()
    if current_weapon ~= nil and isBicycleItem(current_weapon) then
        context:addOption(getText("ContextMenu_BicycleHopOff"), worldobjects, BicycleMenu.dropBicycle, {current_weapon}, pzPlayer:getPlayerNum())
        local vehicle = pzPlayer:getVehicle() or pzPlayer:getUseableVehicle() or pzPlayer:getNearVehicle()
        if vehicle then
            local playerInv = pzPlayer:getInventory()

            local trunk = findVehicleStoragePart(vehicle)
            if not trunk then
                trunk = vehicle:getPartById("TruckBed")
            end
            if not trunk then
                trunk = vehicle:getPartById("TruckBedOpen")
            end
            if not trunk then
                trunk = vehicle:getPartById("TrailerTrunk")
            end

            local trunkContainer = trunk and trunk:getItemContainer() or nil
            local isTruckBed = isTruckBedPart(vehicle, trunk)

            if trunkContainer then
                if isTruckBed then
                    context:addOption(getText("ContextMenu_BicycleStoreTruckBed"), worldobjects, BicycleMenu.transferToTrunk, pzPlayer, current_weapon, playerInv, trunkContainer, 80)
                else
                    local trunkDoorPart = vehicle:getPartById("TrunkDoor") or vehicle:getPartById("DoorRear")
                    if trunkDoorPart and trunkDoorPart:getDoor() and trunkDoorPart:getInventoryItem() then
                        if not vehicle:isTrunkLocked() then
                            trunkDoorPart:getDoor():setOpen(true)
                            context:addOption(getText("ContextMenu_BicycleStoreTrunk"), worldobjects, BicycleMenu.transferToTrunk, pzPlayer, current_weapon, playerInv, trunkContainer, 80)
                        elseif vehicle:isTrunkLocked() and vehicle:canUnlockDoor(trunkDoorPart, pzPlayer) then
                            trunkDoorPart:getDoor():setLocked(false)
                            trunkDoorPart:getDoor():setOpen(true)
                            context:addOption(getText("ContextMenu_BicycleUnlockTrunkAndStore"), worldobjects, BicycleMenu.transferToTrunk, pzPlayer, current_weapon, playerInv, trunkContainer, 80)
                        end
                    else
                        context:addOption(getText("ContextMenu_BicycleStoreTrunk"), worldobjects, BicycleMenu.transferToTrunk, pzPlayer, current_weapon, playerInv, trunkContainer, 80)
                    end
                end
            end
        end
        return true
    end
    return false
end

local function addBicycleOptions(context, pzPlayer, bicycleItem, worldobjects, saddlebagItem, basketItem, crateItem, bicycleIso)
    if not bicycleItem or not instanceof(bicycleItem, "HandWeapon") or not isBicycleItem(bicycleItem) then
        return
    end

    local subMenuUp = context:getNew(context)
    local doIt = false
    local alreadyDoneList = {}

    local weaponParts = pzPlayer:getInventory():getItemsFromCategory("WeaponPart")
    if weaponParts and not weaponParts:isEmpty() then
        for i = 0, weaponParts:size() - 1 do
            local part = weaponParts:get(i)
            local convertibleFrontWheel = BicycleMenu.canAttachFrontWheelAsRear(bicycleItem, part)
            if part and not part:isBroken() and not alreadyDoneList[part:getName()] and (part:canAttach(pzPlayer, bicycleItem) or convertibleFrontWheel) and BicycleMenu.canAttachPart(bicycleItem, part, pzPlayer) then
                subMenuUp:addOption(part:getName(), bicycleItem, ISInventoryPaneContextMenu.onUpgradeWeapon, part, pzPlayer)
                alreadyDoneList[part:getName()] = true
                doIt = true
            end
        end
    end

    local vanillaBag = pzPlayer:getInventory():getFirstTypeRecurse("Base.Plasticbag")
    if vanillaBag then
        local hasLeft = bicycleItem:getWeaponPart("PlasticBagLeft") ~= nil
        local hasRight = bicycleItem:getWeaponPart("PlasticBagRight") ~= nil
        if not (hasLeft and hasRight) then
            subMenuUp:addOption(vanillaBag:getName(), bicycleItem, BicycleAttachments.attachVanillaPlasticBag, pzPlayer, bicycleItem, vanillaBag)
            doIt = true
        end
    end

    local vanillaToolbox = pzPlayer:getInventory():getFirstTypeRecurse("Base.Toolbox")
    if vanillaToolbox and not bicycleItem:getWeaponPart("Toolbox") and not bicycleItem:getWeaponPart("Crate") then
        subMenuUp:addOption(vanillaToolbox:getName(), bicycleItem, BicycleAttachments.attachVanillaToolbox, pzPlayer, bicycleItem, vanillaToolbox)
        doIt = true
    end

    local vanillaSportsbottle = pzPlayer:getInventory():getFirstTypeRecurse("Base.Sportsbottle")
    if vanillaSportsbottle and bicycleHasBottleHolder(bicycleItem) and not bicycleItem:getWeaponPart("Sportsbottle") then
        subMenuUp:addOption(vanillaSportsbottle:getName(), bicycleItem, BicycleAttachments.attachVanillaSportsbottle, pzPlayer, bicycleItem, vanillaSportsbottle)
        doIt = true
    end

    local ductTape = pzPlayer:getInventory():getFirstTypeRecurse("Base.DuctTape")
    if ductTape and not bicycleItem:getWeaponPart("TapedFlashlight") and not bicycleHasLamp(bicycleItem) then
        local handTorch = pzPlayer:getInventory():getFirstTypeRecurse("Base.HandTorch")
        if handTorch then
            subMenuUp:addOption(handTorch:getName(), bicycleItem, BicycleAttachments.attachTapedFlashlight, pzPlayer, bicycleItem, handTorch, ductTape)
            doIt = true
        end

        local improvisedFlashlight = pzPlayer:getInventory():getFirstTypeRecurse("Base.Flashlight_Crafted")
        if improvisedFlashlight then
            subMenuUp:addOption(improvisedFlashlight:getName(), bicycleItem, BicycleAttachments.attachImprovisedTapedFlashlight, pzPlayer, bicycleItem, improvisedFlashlight, ductTape)
            doIt = true
        end
    end

    if doIt then
        local upgradeOption = context:addOption(getText("ContextMenu_Add_Weapon_Upgrade"), worldobjects, nil)
        context:addSubMenu(upgradeOption, subMenuUp)
    end

    local detachableParts = bicycleItem:getDetachableWeaponParts(pzPlayer)
    if detachableParts and detachableParts:size() > 0 then
        local removeUpgradeOption = context:addOption(getText("ContextMenu_Remove_Weapon_Upgrade"), worldobjects, nil)
        local subMenuRemove = context:getNew(context)
        context:addSubMenu(removeUpgradeOption, subMenuRemove)
        for i = 0, detachableParts:size() - 1 do
            local part = detachableParts:get(i)
            subMenuRemove:addOption(part:getName(), bicycleItem, ISInventoryPaneContextMenu.onRemoveUpgradeWeapon, part, pzPlayer)
        end
    end

    if playerNearHoppableFence(pzPlayer) then
        context:addOption(getText("ContextMenu_BicycleThrowOverFence"), worldobjects, BicycleMenu.throwBicycleOverFence, pzPlayer:getPlayerNum(), bicycleItem)
    end

    if bicycleIso then
        local ready, errorText = bicycleHasRideRequirements(bicycleItem, pzPlayer)

        if ready then
            context:addOption(getText("ContextMenu_BicycleHopOn"), worldobjects, BicycleMenu.equipBicycle, pzPlayer:getPlayerNum(), bicycleIso, saddlebagItem, basketItem, crateItem)
        elseif errorText then
            pzPlayer:Say(errorText)
            pzPlayer:setBlockMovement(false)
        end
    end
end

BicycleMenu.findNearestBicycleWithAttachments = function(square, pzPlayer)
    local items = BicycleMenu.getItems(square)
    local closestBicycle = nil
    local closestBicycleDistance = 1000
    local saddlebagItem = nil
    local basketItem = nil
    local crateItem = nil

    for i = 1, #items do
        local worldObj = items[i]
        if instanceof(worldObj, "IsoWorldInventoryObject") then
            local item = worldObj:getItem()
            if isBicycleItem(item) then
                local dist = BicycleMenu.getDistance2D(worldObj:getWorldPosX(), worldObj:getWorldPosY(), square:getX(), square:getY())
                if dist < closestBicycleDistance then
                    closestBicycle = worldObj
                    closestBicycleDistance = dist
                end
            end
            if item:getType() == "Saddlebag" then
                saddlebagPresent = true
                saddlebagItem = item
            end
            if item:getType() == "Basket" then
                basketPresent = true
                basketItem = item
            end
            if item:getType() == "Crate" then
                cratePresent = true
                crateItem = item
            end
        end
    end

    if closestBicycle then
        local bicycleParts = closestBicycle:getItem():getDetachableWeaponParts(pzPlayer)
        local saddlebagFound = false
        local basketFound = false
        local crateFound = false
        for i = 0, bicycleParts:size()-1 do
            local partName = bicycleParts:get(i):getType()
            if partName == "Bicycle_Saddlebag" then
                saddlebagFound = true
                saddlebagItem = FindFloorItem(closestBicycle, "Saddlebag")
            end
            if partName == "Bicycle_Basket" then
                basketFound = true
                basketItem = FindFloorItem(closestBicycle, "Basket")
            end
            if partName == "Bicycle_Crate" then
                crateFound = true
                crateItem = FindFloorItem(closestBicycle, "Crate")
            end
        end
        if not saddlebagFound and not basketFound and not crateFound then return closestBicycle, nil, nil, nil end
        return closestBicycle, saddlebagItem, basketItem, crateItem
    end

    return closestBicycle, saddlebagItem, basketItem, crateItem
end

function BicycleMenu.onCreateBicycle(item)
    if not item then return end

    local frontWheelType, rearWheelType = chooseWheelTypes()
    local frontWheel = createWheel(frontWheelType)
    local rearWheel = createWheel(rearWheelType)

    if not (frontWheel and rearWheel) then
        frontWheel = frontWheel or createWheel("Bicycle.Bicycle_StreetWheelFrontItem")
        rearWheel = rearWheel or createWheel("Bicycle.Bicycle_StreetWheelRearItem")
    end

    attachPart(item, frontWheel)
    attachPart(item, rearWheel)
    attachPart(item, createChain())
    attachPart(item, createPart("Bicycle.Bicycle_KickstandDown"))

    attachOptionalPart(item, "Bicycle.Bicycle_Bell", 85)
    attachOptionalPart(item, "Bicycle.Bicycle_Saddlebag", 5)
    attachOptionalPart(item, "Bicycle.Bicycle_Lamp", 5)
    attachOptionalPart(item, "Bicycle.Bicycle_BottleHolder", 5)
    attachOptionalPart(item, "Bicycle.Bicycle_Basket", 10)

    if ZombRand(100) < 10 then
        local storagePart = ZombRand(2) == 0 and "Bicycle.Bicycle_Crate" or "Bicycle.Bicycle_Toolbox"
        attachPart(item, createPart(storagePart))
    end

    return item
end

AttachUI = nil
FrontWheel = nil
BackWheel = nil
Pedals = nil

function BicycleMenu.initRotationUI()
    AttachUI = AttachmentEditorUI:new(0, 0, 0, 0)
    AttachUI:initialise()
    AttachUI:instantiate()
    local modelScript = ScriptManager.instance:getModelScript("Base.Bicycle_Frame")
    AttachUI.editUI.attachments:setSelectedModel(modelScript)

    local list2 = AttachUI.editUI.attachments.list2
    list2:clear()
    for i=1, modelScript:getAttachmentCount() do
        local att = modelScript:getAttachment(i-1)
        list2:addItem(att:getId(), att)
    end

    list2:setSelectedRow(2)
    FrontWheel = list2:getSelectedItems()[1].item
    list2:setSelectedRow(4)
    BackWheel = list2:getSelectedItems()[1].item
    list2:setSelectedRow(6)
    Pedals = list2:getSelectedItems()[1].item
end

function BicycleMenu.rotateWheels()
    if not AttachUI then return end
    if not FrontWheel then return end
    if not BackWheel then return end

    local delta = Vector3f.new(10, 0, 0)

    local rot = FrontWheel:getRotate():set(
        FrontWheel:getRotate():x(),
        FrontWheel:getRotate():y(),
        FrontWheel:getRotate():z()
    )
    local rot2 = BackWheel:getRotate():set(
        BackWheel:getRotate():x(),
        BackWheel:getRotate():y(),
        BackWheel:getRotate():z()
    )

    AttachUI.scene.javaObject:fromLua2("applyDeltaRotation", rot, delta)
    AttachUI.scene.javaObject:fromLua2("applyDeltaRotation", rot2, delta)
end

function BicycleMenu.rotatePedals()
    if not AttachUI then return end
    if not Pedals then return end

    local delta = Vector3f.new(-6.5, 0, 0)

    local rot = Pedals:getRotate():set(
        Pedals:getRotate():x(),
        Pedals:getRotate():y(),
        Pedals:getRotate():z()
    )

    AttachUI.scene.javaObject:fromLua2("applyDeltaRotation", rot, delta)
end


local function isNearDoorOrHoppable(pzPlayer)
    if not pzPlayer then return false end

    local midSq = pzPlayer:getSquare()
    if not midSq then return false end
    local squares = {}
    table.insert(squares, midSq)
    table.insert(squares, midSq:getN())
    table.insert(squares, midSq:getS())
    table.insert(squares, midSq:getE())
    table.insert(squares, midSq:getW())

    for i, sq in ipairs(squares) do
        local door = sq and sq.getIsoDoor and sq:getIsoDoor()
        if door then
            if door:getSquare() == midSq or door:isAdjacentToSquare(midSq) then
                return true
            end
        end
    end

    if playerNearHoppableFence(pzPlayer) then
        local closestBicycle = BicycleMenu.findNearestBicycleWithAttachments(midSq, pzPlayer)
        if closestBicycle then
            return true
        end
    end

    return false
end


BicycleMenu.onKeyPressed = function(key)
    local bicycleOptions = PZAPI.ModOptions:getOptions("BicycleMod")
    local Equip_KEY = bicycleOptions:getOption("BicycleEquipButton"):getValue()
    local pzPlayer = getSpecificPlayer(0)
    if not (pzPlayer and pzPlayer:getVariableBoolean("BicycleActive")) then
        if isNearDoorOrHoppable(pzPlayer) then
            return
        end
    end
    if getCore():isKey("Shout", key) and pzPlayer:getVariableBoolean("BicycleActive") then
        local bicycleItem = pzPlayer:getPrimaryHandItem()
        if not isBicycleItem(bicycleItem) then
            bicycleItem = pzPlayer:getSecondaryHandItem()
            if bicycleItem and not isBicycleItem(bicycleItem) then
                bicycleItem = nil
            end
        end

        local hasBell = updateBicycleShoutState(pzPlayer, bicycleItem)
        if not hasBell then
            return
        end

        local emitter = pzPlayer:getEmitter()
        local soundVolume = PZAPI.ModOptions:getOptions("BicycleMod"):getOption("BicycleSoundVolume"):getValue()
        local sound = emitter:playSound('Bicycle_Bell')
        emitter:setVolume(sound, soundVolume)
        addSound(nil, pzPlayer:getX(), pzPlayer:getY(), pzPlayer:getZ(), 20, 20)
    end
    if key ~= Equip_KEY then return end
    if not equipKeyState.isDown then
        if not hasBicycleInteractionTarget(pzPlayer) then
            return
        end
        equipKeyState.isDown = true
        equipKeyState.startMs = getTimestampMs()
        equipKeyState.actionTriggered = false
    end
end

BicycleMenu.onEquipKeyStart = function(key)
    local bicycleOptions = PZAPI.ModOptions:getOptions("BicycleMod")
    local Equip_KEY = bicycleOptions:getOption("BicycleEquipButton"):getValue()
    if key ~= Equip_KEY then
        return
    end

    local pzPlayer = getSpecificPlayer(0)
    if not (pzPlayer and pzPlayer:getVariableBoolean("BicycleActive")) then
        if isNearDoorOrHoppable(pzPlayer) then
            return
        end
    end
    if not hasBicycleInteractionTarget(pzPlayer) then
        return
    end

    equipKeyState.isDown = true
    equipKeyState.startMs = getTimestampMs()
    equipKeyState.actionTriggered = false
end

local function shouldPreventEquipInteraction(pzPlayer)
    if not pzPlayer then return true end
    if pzPlayer:isDoingActionThatCanBeCancelled() then return true end

    if isNearDoorOrHoppable(pzPlayer) then
        return true
    end

    return false
end

local function applyMountDismountAnimations(pzPlayer, currentItem, wasHeld)
    if isBicycleItem(currentItem) then
        local dismountAnim = wasHeld and "kickstandDown" or "throwBicycle"
        pzPlayer:setVariable("dismountAnim", dismountAnim)
    elseif currentItem == nil then
        local sq = pzPlayer:getSquare()
        local closestBicycle = sq and BicycleMenu.findNearestBicycleWithAttachments(sq, pzPlayer)
        if closestBicycle and closestBicycle.getItem then
            local bicycleItem = closestBicycle:getItem()
            local hasKickstandDown = bicycleItem and bicycleItem.getWeaponPart and bicycleItem:getWeaponPart("KickstandDown") ~= nil
            local mountAnim = hasKickstandDown and "kickstandUp" or "pickUp"
            pzPlayer:setVariable("mountAnim", mountAnim)
        end
    end
end

local function performEquipInteraction(wasHeld)
    local pzPlayer = getSpecificPlayer(0)
    if shouldPreventEquipInteraction(pzPlayer) then
        return false
    end

    cancelBicycleTimedActions(pzPlayer)
    local currentItem = pzPlayer:getPrimaryHandItem()
    if currentItem and currentItem.isEquipped and not currentItem:isEquipped() then
        currentItem = nil
    end
    applyMountDismountAnimations(pzPlayer, currentItem, wasHeld)

    if isBicycleItem(currentItem) then
        BicycleMenu.dropBicycle(nil, {currentItem}, 0, wasHeld)
        return true
    end

    local sq = pzPlayer:getSquare()
    local closestBicycle, saddlebagItem, basketItem, crateItem = BicycleMenu.findNearestBicycleWithAttachments(sq, pzPlayer)
    if closestBicycle then
        local bicycleParts = closestBicycle:getItem():getDetachableWeaponParts(pzPlayer)
        local ready, errorText = bicycleHasRideRequirements(closestBicycle:getItem(), pzPlayer)
        if not bicycleHasChain(closestBicycle:getItem()) then
            pzPlayer:Say(getText("IGUI_Bicycle_MissingChain"))
            pzPlayer:setBlockMovement(false)
            return true
        end
        if not ready then
            pzPlayer:Say(errorText)
            pzPlayer:setBlockMovement(false)
            return true
        end
        BicycleMenu.equipBicycle({closestBicycle}, 0, closestBicycle, saddlebagItem, basketItem, crateItem)
    end

    return false
end

local function handleEquipKeyHold()
    local bicycleOptions = PZAPI.ModOptions:getOptions("BicycleMod")
    local Equip_KEY = bicycleOptions:getOption("BicycleEquipButton"):getValue()

    if not equipKeyState.isDown or not isKeyDown(Equip_KEY) or equipKeyState.actionTriggered then
        return
    end

    local heldMs = math.max(0, getTimestampMs() - equipKeyState.startMs)
    if heldMs < BicycleMenu.EquipHoldThresholdMs then
        return
    end

    local pzPlayer = getSpecificPlayer(0)
    if not pzPlayer then
        return
    end

    local currentItem = pzPlayer:getPrimaryHandItem()
    if currentItem and currentItem.isEquipped and not currentItem:isEquipped() then
        currentItem = nil
    end
    if not isBicycleItem(currentItem) then
        return
    end

    if performEquipInteraction(true) then
        equipKeyState.actionTriggered = true
    end
end

local function handleEquipKeyRelease()
    local bicycleOptions = PZAPI.ModOptions:getOptions("BicycleMod")
    local Equip_KEY = bicycleOptions:getOption("BicycleEquipButton"):getValue()
    if not equipKeyState.isDown or isKeyDown(Equip_KEY) then
        return
    end

    local pzPlayer = getSpecificPlayer(0)
    if not hasBicycleInteractionTarget(pzPlayer) then
        equipKeyState.isDown = false
        equipKeyState.actionTriggered = false
        return
    end

    equipKeyState.isDown = false
    local wasTriggered = equipKeyState.actionTriggered
    equipKeyState.actionTriggered = false
    if wasTriggered then
        return
    end

    local heldMs = math.max(0, getTimestampMs() - equipKeyState.startMs)
    local wasHeld = heldMs >= BicycleMenu.EquipHoldThresholdMs

    performEquipInteraction(wasHeld)
end

function BicycleMenu.updateKeyState()
    handleEquipKeyHold()
    handleEquipKeyRelease()
end

BicycleMenu.transferToTrunk = function(worldObjects, playerObj, item, src, dest, time)
    local action = ISInventoryTransferAction:new(playerObj, item, src, dest, time)
    if action and dest then
        action.bicycleForcedAttachmentDest = dest
    end
    ISTimedActionQueue.add(action)
end

BicycleMenu.addWorldContext = function(player, context, worldobjects, test)
    local pzPlayer = getSpecificPlayer(player)
    if BicycleMenu.addEquippedContextOptions(pzPlayer, context, worldobjects) then
        return
    end

    local origSq = worldobjects[1]:getSquare()
    if not instanceof(origSq, "IsoGridSquare") then
        return
    end

    local closestBicycle, saddlebagItem, basketItem, crateItem = BicycleMenu.findNearestBicycleWithAttachments(origSq, pzPlayer)

    if closestBicycle then
        addBicycleOptions(context, pzPlayer, closestBicycle:getItem(), worldobjects, saddlebagItem, basketItem, crateItem, closestBicycle)
    end
end

BicycleMenu.addInventoryContext = function(player, context, items)
    local pzPlayer = getSpecificPlayer(player)

    if BicycleMenu.addEquippedContextOptions(pzPlayer, context, items) then
        return
    end

    local bicycleItem = nil

    for i, v in ipairs(items) do
        local testItem = v
        if not instanceof(v, "InventoryItem") and v.items then
            testItem = v.items[1]
        end

        if testItem and instanceof(testItem, "InventoryItem") and isBicycleItem(testItem) then
            bicycleItem = testItem
            break
        end
    end

    if not bicycleItem then
        return
    end

    removeVanillaUpgradeOptions(context)

    local bicycleIso = bicycleItem:getWorldItem()
    local saddlebagItem, basketItem, crateItem = nil, nil, nil
    local worldobjects = {}

    if bicycleIso and bicycleIso:getSquare() then
        local closest, saddlebag, basket, crate = BicycleMenu.findNearestBicycleWithAttachments(bicycleIso:getSquare(), pzPlayer)
        if closest then
            bicycleIso = closest
        end
        saddlebagItem = saddlebag
        basketItem = basket
        crateItem = crate
        table.insert(worldobjects, bicycleIso)
    else
        worldobjects = items
    end

    addBicycleOptions(context, pzPlayer, bicycleItem, worldobjects, saddlebagItem, basketItem, crateItem, bicycleIso)
end

BicycleMenu.equipBicycle = function(worldobjects, player, item, saddlebag, basket, crate)
    local pzPlayer = getSpecificPlayer(0)
    cancelBicycleTimedActions(pzPlayer)
    local sqP = pzPlayer:getSquare()
    local sqC = item:getSquare()
    local sqCx = sqC:getX()
    local sqCy = sqC:getY()

    pzPlayer:faceLocation(sqCx, sqCy)

    local d = BicycleMenu.getDistance2D(sqP:getX(), sqP:getY(), sqCx, sqCy)
    if d > 1.5 then
        ISTimedActionQueue.add(ISWalkToTimedAction:new(pzPlayer, item:getSquare()))
        pzPlayer:setBlockMovement(true)
        BicycleUtils.runAfter(0.4, function()
            pzPlayer:setBlockMovement(false)
        end)
        ISTimedActionQueue.add(BicycleHopOnAction:new(item, pzPlayer, saddlebag, basket, crate))
    else
        pzPlayer:setBlockMovement(true)
        BicycleUtils.runAfter(0.4, function()
            pzPlayer:setBlockMovement(false)
        end)
        ISTimedActionQueue.add(BicycleHopOnAction:new(item, pzPlayer, saddlebag, basket, crate))
    end
end

BicycleMenu.getItems = function(square)
	local items ={}
	local squares ={}
	if instanceof(square, "IsoGridSquare") == false then return items end
	table.insert(squares,square)
    if square.getN and square:getN() then
        table.insert(squares,square:getN())
    end
    if square.getN and square:getN() and square:getN().getE then
        table.insert(squares,square:getN():getE())
    end
    if square.getN and square:getN() and square:getN().getW then
        table.insert(squares,square:getN():getW())
    end
    if square.getS and square:getS() then
        table.insert(squares,square:getS())
    end
    if square.getS and square:getS() and square:getS().getE then
        table.insert(squares,square:getS():getE())
    end
    if square.getS and square:getS() and square:getS().getW then
        table.insert(squares,square:getS():getW())
    end
    if square.getE and square:getE() then
        table.insert(squares,square:getE())
    end
    if square.getW and square:getW() then
        table.insert(squares,square:getW())
    end
	for si,s in ipairs(squares) do
		for ii,i in ipairs(s:getLuaTileObjectList()) do
			table.insert(items,i)
		end
	end
	return items
end

BicycleMenu.initBicycle = function()
	local player = getSpecificPlayer(0)
    if BicycleClearUpdateHandlers then
        BicycleClearUpdateHandlers()
    end
    local options = PZAPI.ModOptions:getOptions("BicycleMod")
    local speedMultSlow = options:getOption("SpeedMultSlow"):getValue()
    local speedMultFast = options:getOption("SpeedMultFast"):getValue()
    local primaryItem = player:getPrimaryHandItem()
    if not primaryItem then
        player:setVariable("BicycleActive", "false")
        player:setIgnoreAutoVault(false)
        player:setBannedAttacking(false)
        return
    end
    if isBicycleItem(primaryItem) then
        updateBicycleShoutState(player, primaryItem)
        local wheelConfig = BicycleMenu.getWheelConfiguration(primaryItem, player)
        local hasOffroadPair = wheelConfig.offroad >= 2 and wheelConfig.street == 0

        if hasOffroadPair then
            speedMultSlow = speedMultSlow * BicycleMenu.OffroadSpeedMultiplier
            speedMultFast = speedMultFast * BicycleMenu.OffroadSpeedMultiplier
        end
        player:setVariable("BicycleActive", "true")
        updateBicycleShoutState(player, primaryItem)
        player:setBannedAttacking(true)
		player:setIgnoreAutoVault(true)
        Events.OnPlayerUpdate.Add(UpdateBicycleFlag)
        Events.OnPlayerUpdate.Add(UpdateBicycleAudio)
        Events.OnPlayerUpdate.Add(UpdateBicycleSprint)
	end

    player:setVariable("BicycleWalkSpeed", speedMultSlow)
    player:setVariable("BicycleRunSpeed", speedMultFast)
	player:setVariable("Bicycle_Riding", false)
	player:setVariable("Bicycle_Stopping", false)
	player:setVariable("droppingBicycle", false)
	player:setVariable("BicycleRollingTimestamp", "0")
end

BicycleMenu.getDistance2D = function(_x1, _y1, _x2, _y2)
	return math.sqrt(math.abs(_x2 - _x1)^2 + math.abs(_y2 - _y1)^2);
end

function SpawnBicycle()
    local player = getSpecificPlayer(0)
    local playerInv = player:getInventory()
    playerInv:AddItem("Bicycle.Bicycle")
end

function SpawnBicycleSaddlebag()
    local player = getSpecificPlayer(0)
    local playerInv = player:getInventory()
    playerInv:AddItem("Bicycle.Bicycle_Saddlebag")
end

function SpawnBicycleBasket()
    local player = getSpecificPlayer(0)
    local playerInv = player:getInventory()
    playerInv:AddItem("Bicycle.Bicycle_Basket")
end

function SpawnBicycleCrate()
    local player = getSpecificPlayer(0)
    local playerInv = player:getInventory()
    playerInv:AddItem("Bicycle.Bicycle_Crate")
end

function FixAutoVault()
    local player = getSpecificPlayer(0)
    player:setIgnoreAutoVault(false)
end

Events.OnKeyPressed.Add(BicycleMenu.onKeyPressed)
if Events.OnKeyStartPressed then
    Events.OnKeyStartPressed.Add(BicycleMenu.onEquipKeyStart)
end
Events.OnPlayerUpdate.Add(BicycleMenu.updateKeyState)
Events.OnGameStart.Add(BicycleMenu.initRotationUI)
Events.OnCreatePlayer.Add(BicycleMenu.initBicycle)
Events.OnPreFillWorldObjectContextMenu.Add(BicycleMenu.addWorldContext)
Events.OnPreFillInventoryObjectContextMenu.Add(BicycleMenu.addInventoryContext)
