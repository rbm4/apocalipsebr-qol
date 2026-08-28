require("DebugUIs/AttachmentEditorUI")
require("ISUI/ISInventoryPaneContextMenu")
require("ISUI/ISScrollingListBox")
require("Vehicles/ISUI/ISUI3DScene")
require("Bicycle/BicycleCore")
require("Bicycle/BicycleSyncClient")

local BicycleAttachments = require("Bicycle/SaddleBag/Saddlebag")
local AttachmentActionUtils = require("Bicycle/AttachmentActionUtils")
local BicycleAttachPartAction = require("Bicycle/TimedAction/BicycleAttachPartAction")
local BicycleDetachPartAction = require("Bicycle/TimedAction/BicycleDetachPartAction")
local BicycleDebug = require("Bicycle/Debug")
local BicycleMigration = require("Bicycle/Migration")
local BicycleMountDismountState = require("Bicycle/MountDismountState")
local BicycleMountRecovery = require("Bicycle/MountRecovery")
local BicycleOptions = require("Bicycle/BicycleOptions")
local BicyclePartAttachmentService = require("Bicycle/PartAttachmentService")
local BicycleRidingSystem = require("Bicycle/Systems/RidingSystem")
local BicycleItemInitializer = require("Bicycle/ItemInitializer")
local BicycleUtils = require("Bicycle/Utils")
local BicycleVanillaPartMapping = require("Bicycle/VanillaPartMapping")
local BicycleWorldUtils = require("Bicycle/WorldUtils")

---@class BicycleMenu
BicycleMenu = {}
BicycleMenu.typesTable = BicycleUtils.getBicycleTypes()
BicycleMenu.EquipHoldThresholdMs = 500
BicycleMenu.OffroadSpeedMultiplier = 0.9

BicycleRidingSystem.setMenu(BicycleMenu)

---@param playerObj IsoPlayer|IsoGameCharacter|nil
local function cancelBicycleTimedActions(playerObj)
    if not (playerObj and ISTimedActionQueue and ISTimedActionQueue.getTimedActionQueue) then
        return
    end

    local queue = ISTimedActionQueue.getTimedActionQueue(playerObj)

    for i = #queue.queue, 1, -1 do
        local action = queue.queue[i]
        if action
            and (action.Type == "BicycleHopOnAction"
                or action.Type == "BicycleDismountAction"
                or action.Type == "BicycleThrowOverFenceAction") then
            table.remove(queue.queue, i)
        end
    end
end

---@param bicycleItem InventoryItem|nil
local function removeBicycleWorldItem(bicycleItem)
    BicycleUtils.removeWorldItem(bicycleItem)
end

BicycleMenu.removeWorldItem = removeBicycleWorldItem

---@class BicycleEquipKeyState
---@field isDown boolean
---@field startMs number
---@field actionTriggered boolean
---@type BicycleEquipKeyState
local equipKeyState = {
    isDown = false,
    startMs = 0,
    actionTriggered = false,
}

---@param item InventoryItem|nil
---@return boolean
---@nodiscard
local function isBicycleItem(item)
    return BicycleUtils.isBicycleItem(item)
end

---@param pzPlayer IsoPlayer|IsoGameCharacter|nil
---@param item InventoryItem|nil
---@return boolean
---@nodiscard
local function isInvalidEquippedBicycle(pzPlayer, item)
    if not (pzPlayer and isBicycleItem(item)) then
        return false
    end

    if item.getWorldItem and item:getWorldItem() then
        return true
    end
    if item.isInPlayerInventory and not item:isInPlayerInventory() then
        return true
    end

    local playerInventory = pzPlayer:getInventory()
    local container = item.getContainer and item:getContainer() or nil
    if container and container ~= playerInventory then
        return true
    end

    return false
end

---@param pzPlayer IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@nodiscard
local function clearInvalidEquippedBicycles(pzPlayer)
    if not pzPlayer then
        return false
    end

    local cleared = false

    local primaryItem = pzPlayer:getPrimaryHandItem()
    if isInvalidEquippedBicycle(pzPlayer, primaryItem) then
        pzPlayer:setPrimaryHandItem(nil)
        cleared = true
    end

    local secondaryItem = pzPlayer:getSecondaryHandItem()
    if isInvalidEquippedBicycle(pzPlayer, secondaryItem) then
        pzPlayer:setSecondaryHandItem(nil)
        cleared = true
    end

    if not cleared then
        return false
    end

    pzPlayer:setVariable("Bicycle_Riding", "false")
    pzPlayer:setVariable("BicycleActive", "false")
    pzPlayer:setVariable("Bicycle_Stopping", false)
    pzPlayer:setVariable("droppingBicycle", "false")
    pzPlayer:setBlockMovement(false)
    pzPlayer:setIgnoreMovement(false)
    pzPlayer:setTurnDelta(1)
    pzPlayer:setAllowRun(true)
    pzPlayer:setForceSprint(false)
    pzPlayer:setCanShout(true)
    pzPlayer:setBannedAttacking(false)
    pzPlayer:setIgnoreAutoVault(false)
    pzPlayer:resetEquippedHandsModels()
    BicycleRidingSystem.clearUpdateHandlers()

    return true
end

---@param square IsoGridSquare|nil
---@return boolean
---@nodiscard
local function squareHasDoorWindowOrHoppable(square)
    if not square then
        return false
    end

    local objects = square:getObjects()
    if not objects then
        return false
    end

    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if object then
            if instanceof(object, "IsoDoor") or instanceof(object, "IsoWindow") then
                return true
            end
            if instanceof(object, "IsoThumpable") then
                if object:isDoor() or object:isWindow() or object:isHoppable() then
                    return true
                end
            elseif object.isHoppable and object:isHoppable() then
                return true
            end
        end
    end

    return false
end

---@param pzPlayer IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@nodiscard
local function hasBicycleInteractionTarget(pzPlayer)
    if not pzPlayer then
        return false
    end

    clearInvalidEquippedBicycles(pzPlayer)

    local currentItem = pzPlayer:getPrimaryHandItem()
    if currentItem and currentItem.isEquipped and not currentItem:isEquipped() then
        currentItem = nil
    end

    if isBicycleItem(currentItem) then
        return true
    end

    local square = pzPlayer:getSquare()
    if not square then
        return false
    end

    local closestBicycle = BicycleMenu.findNearestBicycleWithAttachments(square, pzPlayer)
    return closestBicycle ~= nil
end

---@param pzPlayer IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@nodiscard
local function playerNearHoppableFence(pzPlayer)
    if not pzPlayer then
        return false
    end

    local square = pzPlayer:getSquare()
    if not square then
        return false
    end

    if BicycleWorldUtils.squareHasHoppable(square) then
        return true
    end

    for _, neighbor in ipairs(BicycleWorldUtils.getNeighborSquares(square, false)) do
        if BicycleWorldUtils.squareHasHoppable(neighbor) then
            return true
        end
    end

    return false
end

local BICYCLE_WEAR_INTERVAL = 13500
local BICYCLE_WEAR_CONDITION_LOSS = 0.1

---@return BicycleDismountAction
local function getBicycleDismountAction()
    return require("Bicycle/TimedAction/BicycleDismountAction")
end

---@return BicycleThrowOverFenceAction
local function getBicycleThrowOverFenceAction()
    return require("Bicycle/TimedAction/BicycleThrowOverFenceAction")
end

---@return BicycleHopOnAction
local function getBicycleHopOnAction()
    return require("Bicycle/TimedAction/BicycleHopOnAction")
end

---@param partId string|nil
---@return boolean
---@nodiscard
local function isTruckBedId(partId)
    if not partId then
        return false
    end

    return string.find(partId, "TruckBed", 1, true) ~= nil
end

---@param vehicle BaseVehicle|nil
---@param part VehiclePart|nil
---@return boolean
---@nodiscard
local function isTruckBedPart(vehicle, part)
    if not part then
        return false
    end

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

---@param part VehiclePart|nil
---@param amount number
---@return boolean
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

---@param playerObj IsoPlayer|IsoGameCharacter|nil
---@param bicycleItem InventoryItem|nil
---@param part InventoryItem|nil
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

        BicycleUtils.removeItemFromContainer(bicycleItem)
        BicycleUtils.addPersistentWorldItem(dropSquare, bicycleItem, 0, 0, 0)
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

---@param vehicle BaseVehicle|nil
---@return VehiclePart|nil
---@nodiscard
local function findVehicleStoragePart(vehicle)
    if not vehicle then
        return nil
    end

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

---@param bicycleItem InventoryItem|nil
---@param partType string
---@return boolean
---@nodiscard
local function bicycleHasPart(bicycleItem, partType)
    if not bicycleItem or not bicycleItem.getWeaponPart then
        return false
    end

    return bicycleItem:getWeaponPart(partType) ~= nil
end

---@param bicycleItem InventoryItem|nil
---@return boolean
---@nodiscard
local function bicycleHasBell(bicycleItem)
    return bicycleHasPart(bicycleItem, "Bell")
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bicycleItem InventoryItem|nil
---@return boolean
function BicycleMenu.updateBicycleShoutState(player, bicycleItem)
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

---@type table<string, boolean>
local wheelPartTypes = {
    FrontWheel = true,
    RearWheel = true,
}

---@param partType string|nil
---@return boolean
---@nodiscard
local function isWheelPartType(partType)
    return partType and wheelPartTypes[partType] == true
end

---@type table<string, string>
local wheelTypeByName = {
    Bicycle_StreetWheelFrontItem = "street",
    Bicycle_StreetWheelRearItem = "street",
    Bicycle_OffroadWheelFrontItem = "offroad",
    Bicycle_OffroadWheelRearItem = "offroad",
    Bicycle_StreetWheelFrontFlatItem = "street",
    Bicycle_StreetWheelRearFlatItem = "street",
    Bicycle_OffroadWheelFrontFlatItem = "offroad",
    Bicycle_OffroadWheelRearFlatItem = "offroad",
}

---@type table<string, boolean>
local flatWheelTypeNames = {
    Bicycle_StreetWheelFrontFlatItem = true,
    Bicycle_StreetWheelRearFlatItem = true,
    Bicycle_OffroadWheelFrontFlatItem = true,
    Bicycle_OffroadWheelRearFlatItem = true,
}

---@type table<string, string>
local normalToFlat = {
    ["Bicycle.Bicycle_StreetWheelFrontItem"] = "Bicycle.Bicycle_StreetWheelFrontFlatItem",
    ["Bicycle.Bicycle_StreetWheelRearItem"] = "Bicycle.Bicycle_StreetWheelRearFlatItem",
    ["Bicycle.Bicycle_OffroadWheelFrontItem"] = "Bicycle.Bicycle_OffroadWheelFrontFlatItem",
    ["Bicycle.Bicycle_OffroadWheelRearItem"] = "Bicycle.Bicycle_OffroadWheelRearFlatItem",
}

---@param bicycleItem InventoryItem|nil
---@param pzPlayer IsoPlayer|IsoGameCharacter|nil
---@return table
---@nodiscard
function BicycleMenu.getAttachedWheels(bicycleItem, pzPlayer)
    local attachedWheels = {}

    local parts = bicycleItem and bicycleItem.getDetachableWeaponParts and bicycleItem:getDetachableWeaponParts(pzPlayer)
    if not parts then
        return attachedWheels
    end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part and isWheelPartType(part:getPartType()) then
            local typeName = part:getType()
            table.insert(attachedWheels, {
                part = part,
                wheelType = wheelTypeByName[typeName],
                isFlat = flatWheelTypeNames[typeName] == true,
            })
        end
    end

    return attachedWheels
end

---@param bicycleItem InventoryItem|nil
---@param pzPlayer IsoPlayer|IsoGameCharacter|nil
---@return table
---@nodiscard
function BicycleMenu.getWheelConfiguration(bicycleItem, pzPlayer)
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

---@param bicycleItem InventoryItem|nil
---@param pzPlayer IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@return string|nil
---@return table
---@nodiscard
local function bicycleHasRideRequirements(bicycleItem, pzPlayer)
    local wheelConfig = BicycleMenu.getWheelConfiguration(bicycleItem, pzPlayer)
    if wheelConfig.total == 0 then
        return false, getText("IGUI_Bicycle_MissingBothWheels"), wheelConfig
    end

    if wheelConfig.total < 2 then
        return false, getText("IGUI_Bicycle_MissingWheel"), wheelConfig
    end

    if not bicycleHasPart(bicycleItem, "Chain") then
        return false, getText("IGUI_Bicycle_MissingChain"), wheelConfig
    end

    return true, nil, wheelConfig
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@param mountAnim string|nil
---@return boolean
function BicycleMenu.enterMountedState(player, bikeItem, mountAnim)
    if not (player and bikeItem) then
        return false
    end

    BicycleMigration.normalizeKickstandState(bikeItem, player)

    local speedMultSlow, speedMultFast = BicycleOptions.getSpeedMultipliers()
    local wheelConfig = BicycleMenu.getWheelConfiguration(bikeItem, player)
    local hasOffroadPair = wheelConfig.offroad >= 2 and wheelConfig.street == 0

    if hasOffroadPair then
        speedMultSlow = speedMultSlow * BicycleMenu.OffroadSpeedMultiplier
        speedMultFast = speedMultFast * BicycleMenu.OffroadSpeedMultiplier
    end

    if mountAnim and mountAnim ~= "" then
        BicycleMountDismountState.prepareMount(player, mountAnim)
    else
        BicycleMountDismountState.clearDismountState(player)
    end

    player:setVariable("BumpFall", false)
    player:setVariable("BumpDone", true)
    player:setVariable("TripObstacleType", "")
    player:setVariable("BicycleActive", "true")
    if not player:getVariableBoolean("Bicycle_Riding") then
        player:setVariable("Bicycle_Riding", "false")
    end
    player:setVariable("BicycleSpeed", 1)
    player:setVariable("BicycleWalkSpeed", speedMultSlow)
    player:setVariable("BicycleRunSpeed", speedMultFast)
    player:setVariable("BicycleWalkSpeedRough", speedMultSlow)
    player:setVariable("BicycleRunSpeedRough", speedMultFast)
    player:setVariable("BicycleWalkSpeedTrees", speedMultSlow * 0.5)
    player:setVariable("BicycleRunSpeedTrees", speedMultFast * 0.5)
    player:setVariable("BicycleRough", false)
    player:setVariable("Bicycle_Stopping", false)
    player:setVariable("droppingBicycle", false)
    player:setBlockMovement(false)
    player:setIgnoreMovement(false)
    player:setTurnDelta(1)
    player:setBannedAttacking(true)
    player:setIgnoreAutoVault(true)
    player:setAllowRun(false)
    player:setForceSprint(false)
    BicycleMenu.updateBicycleShoutState(player, bikeItem)
    BicycleRidingSystem.updateBicycleFlag(player)
    BicycleRidingSystem.ensureUpdateHandlers()
    BicycleDebug.log(
        "BicycleMenu:enterMountedState player=" .. BicycleDebug.describePlayer(player)
            .. ", item=" .. BicycleDebug.describeItem(bikeItem)
            .. ", mountAnim=" .. BicycleDebug.describeValue(mountAnim)
    )

    return true
end

---@param context ISContextMenu
local function removeVanillaUpgradeOptions(context)
    context:removeOptionByName(getText("ContextMenu_Add_Weapon_Upgrade"))
    context:removeOptionByName(getText("ContextMenu_Remove_Weapon_Upgrade"))
end

---@param pzPlayer IsoPlayer|IsoGameCharacter|nil
---@param bicycleItem InventoryItem|nil
local function transferBicycleIfNeeded(pzPlayer, bicycleItem)
    if not (pzPlayer and bicycleItem) then
        return
    end
    if bicycleItem.getWorldItem and bicycleItem:getWorldItem() then
        return
    end
    ISInventoryPaneContextMenu.transferIfNeeded(pzPlayer, bicycleItem, true)
end

---@param pzPlayer IsoPlayer|IsoGameCharacter|nil
---@param item InventoryItem|nil
local function transferSourceIfNeeded(pzPlayer, item)
    if not (pzPlayer and item) then
        return
    end
    ISInventoryPaneContextMenu.transferIfNeeded(pzPlayer, item)
end

---@param pzPlayer IsoPlayer|IsoGameCharacter|nil
---@param bicycleItem InventoryItem|nil
---@param sourceItem InventoryItem|nil
---@param partType string|nil
---@param sourceMode string|nil
---@param ductTape InventoryItem|nil
---@param partFullType string|nil
local function queueAttachPart(_target, pzPlayer, bicycleItem, sourceItem, partType, sourceMode, ductTape, partFullType)
    if not (pzPlayer and bicycleItem and sourceItem) then
        return
    end

    local targetPartType = BicyclePartAttachmentService.resolveAttachPartType(bicycleItem, sourceItem, partType, sourceMode)
    if not targetPartType then
        return
    end

    transferBicycleIfNeeded(pzPlayer, bicycleItem)
    transferSourceIfNeeded(pzPlayer, sourceItem)
    if ductTape then
        transferSourceIfNeeded(pzPlayer, ductTape)
    end

    local square = AttachmentActionUtils.resolveBikeSquare(pzPlayer, bicycleItem)
    local x = nil
    local y = nil
    local z = nil
    if square then
        x = square:getX()
        y = square:getY()
        z = square:getZ()
    end
    pzPlayer:setVariable("BicycleUpgrading", true)
    ISTimedActionQueue.add(BicycleAttachPartAction:new(
        pzPlayer,
        bicycleItem,
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

---@param pzPlayer IsoPlayer|IsoGameCharacter|nil
---@param bicycleItem InventoryItem|nil
---@param part InventoryItem|nil
local function queueDetachPart(_target, pzPlayer, bicycleItem, part)
    if not (pzPlayer and bicycleItem and part and part.getPartType) then
        return
    end

    transferBicycleIfNeeded(pzPlayer, bicycleItem)
    local square = AttachmentActionUtils.resolveBikeSquare(pzPlayer, bicycleItem)
    local x = nil
    local y = nil
    local z = nil
    if square then
        x = square:getX()
        y = square:getY()
        z = square:getZ()
    end
    pzPlayer:setVariable("BicycleUpgrading", true)
    ISTimedActionQueue.add(BicycleDetachPartAction:new(
        pzPlayer,
        bicycleItem,
        part:getPartType(),
        x,
        y,
        z
    ))
end

---@param bicycleItem InventoryItem|nil
---@param part InventoryItem|nil
---@return boolean
---@nodiscard
function BicycleMenu.canAttachFrontWheelAsRear(bicycleItem, part)
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

---@param bicycleItem InventoryItem|nil
---@param part InventoryItem|nil
---@return boolean
---@nodiscard
function BicycleMenu.canAttachWheelInOppositeSlot(bicycleItem, part)
    if not (bicycleItem and part and part.getPartType) then
        return false
    end

    local sourcePartType = part:getPartType()
    if not isWheelPartType(sourcePartType) then
        return false
    end

    local targetPartType = BicyclePartAttachmentService.resolveAttachPartType(
        bicycleItem,
        part,
        nil,
        BicyclePartAttachmentService.SourceModePart
    )
    return targetPartType ~= nil and targetPartType ~= sourcePartType
end

---@param bicycleItem InventoryItem|nil
---@param part InventoryItem|nil
---@param player IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@nodiscard
function BicycleMenu.canAttachPart(bicycleItem, part, player)
    if not bicycleItem or not part then
        return false
    end

    local partType = BicyclePartAttachmentService.resolveAttachPartType(
        bicycleItem,
        part,
        nil,
        BicyclePartAttachmentService.SourceModePart
    )
    return BicyclePartAttachmentService.canAttachPart(
        player,
        bicycleItem,
        part,
        partType,
        BicyclePartAttachmentService.SourceModePart,
        nil,
        nil
    )
end

---@param part InventoryItem|nil
---@param elapsed number
local function syncWearModData(part, elapsed)
    if not part or not part.getModData then
        return
    end

    local modData = part:getModData()
    modData.bicycleWearElapsed = elapsed
    if part.transmitModData then
        part:transmitModData()
    end
end

---@param playerObj IsoPlayer|IsoGameCharacter|nil
---@param bicycleItem InventoryItem
---@param wheel table
---@param part InventoryItem
---@param isRoughSurface boolean
---@return boolean
local function rollFlatTireChance(playerObj, bicycleItem, wheel, part, isRoughSurface)
    if not wheel or not part or wheel.isFlat then
        return false
    end

    local chance = 0
    if isRoughSurface and wheel.wheelType == "street" then
        chance = 0.00001
    end

    if ZombRandFloat(0.0, 1.0) < chance then
        local flatFullType = normalToFlat[part:getFullType()]
        if not flatFullType then
            return false
        end

        local flatPart = instanceItem(flatFullType)
        if not flatPart then
            return false
        end

        if part.getCondition and flatPart.setCondition then
            flatPart:setCondition(part:getCondition())
        end
        if part.getUsedDelta and flatPart.setUsedDelta then
            flatPart:setUsedDelta(part:getUsedDelta())
        end
        local sourceModData = part:getModData()
        local targetModData = flatPart:getModData()
        targetModData.bicycleWearElapsed = sourceModData.bicycleWearElapsed

        bicycleItem:detachWeaponPart(playerObj, part)
        BicycleUtils.removeItemFromContainer(part)
        bicycleItem:attachWeaponPart(flatPart, true)

        local bikeModData = bicycleItem:getModData()
        local mdKey = "bicycleFlat" .. flatPart:getPartType()
        bikeModData[mdKey] = flatFullType
        if bicycleItem.transmitModData then
            bicycleItem:transmitModData()
        end

        wheel.isFlat = true
        wheel.part = flatPart

        -- Immediately sync flat tire to server (don't wait for next wear interval)
        if isClient() and Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.requestWearTick then
            local wearElapsed = sourceModData.bicycleWearElapsed or 0
            Bicycle.ClientSync.requestWearTick(bicycleItem, flatPart:getPartType(), 0, wearElapsed, true)
        end

        local emitter = playerObj and playerObj.getEmitter and playerObj:getEmitter() or nil
        if emitter then
            local volume = PZAPI.ModOptions:getOptions("BicycleMod"):getOption("BicycleSoundVolume"):getValue()
            local sound = emitter:playSound("Bicycle_FlatTire")
            emitter:setVolume(sound, volume)
        end
        return true
    end

    return false
end

---@param playerObj IsoPlayer|IsoGameCharacter|nil
---@param bicycleItem InventoryItem|nil
---@param delta number
---@return boolean
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

        if isClient() and Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.requestWearTick then
            Bicycle.ClientSync.requestWearTick(
                bicycleItem,
                "Chain",
                BICYCLE_WEAR_CONDITION_LOSS,
                elapsed,
                false
            )
            conditionChanged = true
            break
        end

        if drainPartCondition(part, BICYCLE_WEAR_CONDITION_LOSS) then
            handleBrokenAttachment(playerObj, bicycleItem, part)
            syncWearModData(part, elapsed)
            return true
        end

        conditionChanged = true
    end

    if conditionChanged or (modData.bicycleWearElapsed or 0) ~= elapsed then
        syncWearModData(part, elapsed)
    end

    return false
end

---@param playerObj IsoPlayer|IsoGameCharacter|nil
---@param bicycleItem InventoryItem|nil
---@param wheel table
---@param delta number
---@param isRoughSurface boolean
---@return boolean
local function handleWheelWear(playerObj, bicycleItem, wheel, delta, isRoughSurface)
    local part = wheel.part
    if not part then
        return false
    end

    rollFlatTireChance(playerObj, bicycleItem, wheel, part, isRoughSurface)
    part = wheel.part

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

        if isClient() and Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.requestWearTick then
            Bicycle.ClientSync.requestWearTick(
                bicycleItem,
                part:getPartType(),
                conditionLoss,
                elapsed,
                wheel.isFlat == true
            )
            conditionChanged = true
            break
        end

        if drainPartCondition(part, conditionLoss) then
            handleBrokenAttachment(playerObj, bicycleItem, part)
            syncWearModData(part, elapsed)
            return true
        end
        conditionChanged = true
    end

    if conditionChanged or (modData.bicycleWearElapsed or 0) ~= elapsed then
        syncWearModData(part, elapsed)
    end

    return false
end

---@param playerObj IsoPlayer|IsoGameCharacter|nil
---@param bicycleItem InventoryItem|nil
function BicycleMenu.drainWearParts(playerObj, bicycleItem)
    if not bicycleItem then
        return
    end

    local delta = GameTime.getInstance():getTimeDelta()
    delta = math.min(delta, BICYCLE_WEAR_INTERVAL)
    if delta <= 0 then
        return
    end
    local isRoughSurface = BicycleWorldUtils.isRoughSurface(playerObj:getSquare())
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

---@param playerObj IsoPlayer|IsoGameCharacter
---@param weapon InventoryItem
---@param dismountData table|nil
function BicycleMenu.onCompleteDrop(playerObj, weapon, dismountData)
    playerObj:removeFromHands(weapon)
    if playerObj.setTimedActionToRetrigger then
        playerObj:setTimedActionToRetrigger(nil)
    end
    equipKeyState.isDown = false
    equipKeyState.startMs = 0
    equipKeyState.actionTriggered = false
    if weapon and weapon.getID then
        local weaponId = weapon:getID()
        local primaryItem = playerObj:getPrimaryHandItem()
        if isBicycleItem(primaryItem) and primaryItem.getID and primaryItem:getID() == weaponId then
            playerObj:setPrimaryHandItem(nil)
        end

        local secondaryItem = playerObj:getSecondaryHandItem()
        if isBicycleItem(secondaryItem) and secondaryItem.getID and secondaryItem:getID() == weaponId then
            playerObj:setSecondaryHandItem(nil)
        end

        local inventory = playerObj:getInventory()
        if inventory then
            -- Remove ALL references to this bicycle from inventory.
            -- ISInventoryTransferAction or ISEquipWeaponAction can leave
            -- duplicate item references in the container's internal list;
            -- DoRemoveItem only strips one per call.
            for _removePass = 1, 10 do
                local dup = inventory:getItemWithID(weapon:getID())
                if not dup then break end
                inventory:DoRemoveItem(dup)
                if dup.setContainer then
                    dup:setContainer(nil)
                end
                if dup.setWorldItem then
                    dup:setWorldItem(nil)
                end
            end
        end
    end
    if isClient() then
        BicycleUtils.removeItemFromContainer(weapon)
    elseif isServer() then
        BicycleAttachments.onBikeDropped(playerObj, weapon, dismountData)
    else
        BicycleAttachments.onBikeDropped(playerObj, weapon, dismountData)
    end
    if isClient() then
        local pdata = getPlayerData(playerObj:getPlayerNum())
        if pdata and pdata.playerInventory then
            pdata.playerInventory:refreshBackpacks()
            pdata.lootInventory:refreshBackpacks()
        end
    end
    BicycleRidingSystem.clearUpdateHandlers()
    local emitter = playerObj:getEmitter()
    emitter:stopSoundByName("Bicycle_Riding")
    playerObj:setVariable("Bicycle_Riding", "false")
    playerObj:setVariable("BicycleActive", "false")
    playerObj:setBlockMovement(false)
    playerObj:setIgnoreMovement(false)
    playerObj:setTurnDelta(1)
    playerObj:setVariable("Bicycle_Stopping", false)
    playerObj:setAllowRun(true)
    playerObj:setForceSprint(false)
    playerObj:setCanShout(true)
    playerObj:setBannedAttacking(false)
    playerObj:setIgnoreAutoVault(false)
    BicycleMountDismountState.finishMount(playerObj)
    BicycleMountDismountState.finishDismount(playerObj)
    if Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.syncState then
        Bicycle.ClientSync.syncState(playerObj, true)
    end

end

---@param playerObj IsoPlayer|IsoGameCharacter|nil
---@return string
local function describeTimedActionQueue(playerObj)
    if not (playerObj and ISTimedActionQueue and ISTimedActionQueue.getTimedActionQueue) then
        return "queue=nil"
    end

    local queue = ISTimedActionQueue.getTimedActionQueue(playerObj)
    if not queue then
        return "queue=nil"
    end

    local parts = {}
    for i = 1, #queue.queue do
        local action = queue.queue[i]
        parts[#parts + 1] = tostring(i) .. ":" .. tostring(action and action.Type or "nil")
    end

    return "current=" .. tostring(queue.current and queue.current.Type or "nil")
        .. ", queue=[" .. table.concat(parts, ",") .. "]"
end

---@param playerObj IsoPlayer|IsoGameCharacter|nil
---@param bicycleItem InventoryItem|nil
---@param targetSquare IsoGridSquare|nil
---@param dismountData table|nil
function BicycleMenu.dropBicycleAtSquare(playerObj, bicycleItem, targetSquare, dismountData)
    if not (playerObj and bicycleItem and targetSquare) then
        return
    end


    if isClient() then
        -- Pass the square through; without it the server drops the bike wherever the player is standing.
        if Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.requestDropBike then
            Bicycle.ClientSync.requestDropBike(bicycleItem, dismountData, targetSquare)
        end
        BicycleMenu.onCompleteDrop(playerObj, bicycleItem, dismountData)
        return
    elseif isServer() then
        BicycleUtils.removeWorldItem(bicycleItem)
        BicycleUtils.removeItemFromContainer(bicycleItem)
    else
        BicycleUtils.removeWorldItem(bicycleItem)
        BicycleUtils.removeItemFromContainer(bicycleItem)
    end

    BicycleUtils.addPersistentWorldItem(targetSquare, bicycleItem, 0, 0, 0)
    BicycleMenu.onCompleteDrop(playerObj, bicycleItem, dismountData)
end

---@param worldobjects IsoObject[]|nil
---@param items InventoryItem[]|nil
---@param player number
---@param isHold boolean|nil
---@param stopOnWalk boolean|nil
---@param stopOnRun boolean|nil
function BicycleMenu.dropBicycle(worldobjects, items, player, isHold, stopOnWalk, stopOnRun)
    local pzPlayer = getSpecificPlayer(player)
    local currentWeapon = pzPlayer:getPrimaryHandItem()
    if not currentWeapon or not isBicycleItem(currentWeapon) then
        return
    end
    if stopOnWalk == nil then
        stopOnWalk = true
    end
    if stopOnRun == nil then
        stopOnRun = true
    end
    cancelBicycleTimedActions(pzPlayer)
    local runKey = getCore():getKey("Run")
    local shiftHeld = runKey and runKey >= 0 and isKeyDown(runKey)
    local bicycleItem = items and items[1]
    local hasKickstand = bicycleItem
        and bicycleItem.getWeaponPart
        and (bicycleItem:getWeaponPart("KickstandUp") ~= nil or bicycleItem:getWeaponPart("KickstandDown") ~= nil)
    local isHeld = isHold == true
    -- With a sidecar there is only one way off: the kickstand dismount, which leaves the bike standing.
    local sidecarAttached = BicycleUtils.hasSidecar(bicycleItem)
    if sidecarAttached then
        isHeld = true
        shiftHeld = false
    end
    local dismountAnim = isHeld and "kickstandDown" or "throwBicycle"
    local dismountRotation = BicycleUtils.directionToZRotation(pzPlayer:getDir())
    local action = getBicycleDismountAction():new(
        pzPlayer,
        bicycleItem,
        {
            shiftHeld = shiftHeld,
            direction = pzPlayer:getDir(),
            zRotation = dismountRotation,
            dismountAnim = dismountAnim,
            -- Not gated on hasKickstand: a sidecar bike must end upright whether or not the part is fitted.
            kickstandDown = (isHeld and not shiftHeld and (hasKickstand or sidecarAttached)),
        },
        BicycleMenu.onCompleteDrop,
        stopOnWalk,
        stopOnRun
    )
    ISTimedActionQueue.add(action)
end

---@param worldobjects IsoObject[]|nil
---@param player number
---@param bicycleItem InventoryItem|nil
---@param maxTime number|nil
function BicycleMenu.throwBicycleOverFence(worldobjects, player, bicycleItem, maxTime)
    local pzPlayer = getSpecificPlayer(player)
    if not (pzPlayer and bicycleItem) then
        return
    end

    -- Refused at the entry point too, so a keybind or compat mod cannot throw a sidecar bike either.
    if BicycleUtils.hasSidecar(bicycleItem) then
        return
    end

    -- Resolve the fence client-side and pass the direction by name: the server rebuilds this action from those
    -- args and places the bike itself, so the landing square has to match the one just animated.
    local fenceDir = BicycleWorldUtils.findHoppableDirection(pzPlayer)
    if not fenceDir then
        return
    end
    if not BicycleWorldUtils.findThrowLandingSquare(pzPlayer, fenceDir) then
        return
    end
    -- Refused at the entry point too, not just hidden in the menu.
    if not BicycleUtils.isBikeUnderPlayer(pzPlayer, bicycleItem) then
        return
    end

    cancelBicycleTimedActions(pzPlayer)
    local action = getBicycleThrowOverFenceAction():new(
        pzPlayer, bicycleItem, BicycleWorldUtils.directionToName(fenceDir))
    ISTimedActionQueue.add(action)
end

---@param pzPlayer IsoPlayer|IsoGameCharacter
---@param context ISContextMenu
---@param worldobjects IsoObject[]
---@return boolean
function BicycleMenu.addEquippedContextOptions(pzPlayer, context, worldobjects)
    local currentWeapon = pzPlayer:getPrimaryHandItem()
    if currentWeapon ~= nil and isBicycleItem(currentWeapon) then
        if not pzPlayer:getVariableBoolean("BicycleActive") then
            return false
        end
        context:addOption(
            getText("ContextMenu_BicycleHopOff"),
            worldobjects,
            BicycleMenu.dropBicycle,
            { currentWeapon },
            pzPlayer:getPlayerNum(),
            nil,
            true,
            true
        )
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
                    context:addOption(
                        getText("ContextMenu_BicycleStoreTruckBed"),
                        worldobjects,
                        BicycleMenu.transferToTrunk,
                        pzPlayer,
                        currentWeapon,
                        playerInv,
                        trunkContainer,
                        80
                    )
                else
                    local trunkDoorPart = vehicle:getPartById("TrunkDoor") or vehicle:getPartById("DoorRear")
                    if trunkDoorPart and trunkDoorPart:getDoor() and trunkDoorPart:getInventoryItem() then
                        if not vehicle:isTrunkLocked() then
                            trunkDoorPart:getDoor():setOpen(true)
                            context:addOption(
                                getText("ContextMenu_BicycleStoreTrunk"),
                                worldobjects,
                                BicycleMenu.transferToTrunk,
                                pzPlayer,
                                currentWeapon,
                                playerInv,
                                trunkContainer,
                                80
                            )
                        elseif vehicle:isTrunkLocked() and vehicle:canUnlockDoor(trunkDoorPart, pzPlayer) then
                            trunkDoorPart:getDoor():setLocked(false)
                            trunkDoorPart:getDoor():setOpen(true)
                            context:addOption(
                                getText("ContextMenu_BicycleUnlockTrunkAndStore"),
                                worldobjects,
                                BicycleMenu.transferToTrunk,
                                pzPlayer,
                                currentWeapon,
                                playerInv,
                                trunkContainer,
                                80
                            )
                        end
                    else
                        context:addOption(
                            getText("ContextMenu_BicycleStoreTrunk"),
                            worldobjects,
                            BicycleMenu.transferToTrunk,
                            pzPlayer,
                            currentWeapon,
                            playerInv,
                            trunkContainer,
                            80
                        )
                    end
                end
            end
        end
        return true
    end
    return false
end

---@param context ISContextMenu
---@param pzPlayer IsoPlayer|IsoGameCharacter
---@param bicycleItem InventoryItem|nil
---@param worldobjects IsoObject[]
---@param saddlebagItem InventoryItem|nil
---@param basketItem InventoryItem|nil
---@param crateItem InventoryItem|nil
---@param bicycleIso IsoWorldInventoryObject|nil
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
            local partType = BicyclePartAttachmentService.resolveAttachPartType(
                bicycleItem,
                part,
                nil,
                BicyclePartAttachmentService.SourceModePart
            )
            if part
                and not part:isBroken()
                and not alreadyDoneList[part:getName()]
                and partType
                and BicyclePartAttachmentService.canAttachPart(
                    pzPlayer,
                    bicycleItem,
                    part,
                    partType,
                    BicyclePartAttachmentService.SourceModePart,
                    nil,
                    nil
                ) then
                subMenuUp:addOption(
                    part:getName(),
                    bicycleItem,
                    queueAttachPart,
                    pzPlayer,
                    bicycleItem,
                    part,
                    partType,
                    BicyclePartAttachmentService.SourceModePart,
                    nil,
                    nil
                )
                alreadyDoneList[part:getName()] = true
                doIt = true
            end
        end
    end

    -- Either bag part type resolves the same accepted-source list; the side is picked below.
    local vanillaBag = BicycleVanillaPartMapping.findVanillaSourceInInventory(pzPlayer:getInventory(), "PlasticBagLeft")
    if vanillaBag then
        local targetPartType = BicyclePartAttachmentService.resolveAttachPartType(
            bicycleItem,
            vanillaBag,
            nil,
            BicyclePartAttachmentService.SourceModeVanilla
        )
        if BicyclePartAttachmentService.canAttachPart(
            pzPlayer,
            bicycleItem,
            vanillaBag,
            targetPartType,
            BicyclePartAttachmentService.SourceModeVanilla,
            nil,
            nil
        ) then
            subMenuUp:addOption(
                vanillaBag:getName(),
                bicycleItem,
                queueAttachPart,
                pzPlayer,
                bicycleItem,
                vanillaBag,
                targetPartType,
                BicyclePartAttachmentService.SourceModeVanilla,
                nil,
                nil
            )
            doIt = true
        end
    end

    local vanillaToolbox = BicycleVanillaPartMapping.findVanillaSourceInInventory(pzPlayer:getInventory(), "Toolbox")
    if vanillaToolbox then
        local targetPartType = BicyclePartAttachmentService.resolveAttachPartType(
            bicycleItem,
            vanillaToolbox,
            nil,
            BicyclePartAttachmentService.SourceModeVanilla
        )
        if BicyclePartAttachmentService.canAttachPart(
            pzPlayer,
            bicycleItem,
            vanillaToolbox,
            targetPartType,
            BicyclePartAttachmentService.SourceModeVanilla,
            nil,
            nil
        ) then
            subMenuUp:addOption(
                vanillaToolbox:getName(),
                bicycleItem,
                queueAttachPart,
                pzPlayer,
                bicycleItem,
                vanillaToolbox,
                targetPartType,
                BicyclePartAttachmentService.SourceModeVanilla,
                nil,
                nil
            )
            doIt = true
        end
    end

    local vanillaSportsbottle = BicycleVanillaPartMapping.findVanillaSourceInInventory(pzPlayer:getInventory(), "Sportsbottle")
    if vanillaSportsbottle then
        local targetPartType = BicyclePartAttachmentService.resolveAttachPartType(
            bicycleItem,
            vanillaSportsbottle,
            nil,
            BicyclePartAttachmentService.SourceModeVanilla
        )
        if BicyclePartAttachmentService.canAttachPart(
            pzPlayer,
            bicycleItem,
            vanillaSportsbottle,
            targetPartType,
            BicyclePartAttachmentService.SourceModeVanilla,
            nil,
            nil
        ) then
            subMenuUp:addOption(
                vanillaSportsbottle:getName(),
                bicycleItem,
                queueAttachPart,
                pzPlayer,
                bicycleItem,
                vanillaSportsbottle,
                targetPartType,
                BicyclePartAttachmentService.SourceModeVanilla,
                nil,
                nil
            )
            doIt = true
        end
    end

    local ductTape = BicyclePartAttachmentService.findDuctTapeWithCharges(pzPlayer:getInventory())
    if ductTape and not bicycleHasPart(bicycleItem, "TapedFlashlight") and not bicycleHasPart(bicycleItem, "Lamp") then
        local handTorch = pzPlayer:getInventory():getFirstTypeRecurse("Base.HandTorch")
        if handTorch then
            local partFullType = BicyclePartAttachmentService.getTapedFlashlightPartFullType(handTorch)
            if BicyclePartAttachmentService.canAttachPart(
                pzPlayer,
                bicycleItem,
                handTorch,
                "TapedFlashlight",
                BicyclePartAttachmentService.SourceModeTapedFlashlight,
                ductTape,
                partFullType
            ) then
                subMenuUp:addOption(
                    handTorch:getName(),
                    bicycleItem,
                    queueAttachPart,
                    pzPlayer,
                    bicycleItem,
                    handTorch,
                    "TapedFlashlight",
                    BicyclePartAttachmentService.SourceModeTapedFlashlight,
                    ductTape,
                    partFullType
                )
                doIt = true
            end
        end

        local improvisedFlashlight = pzPlayer:getInventory():getFirstTypeRecurse("Base.Flashlight_Crafted")
        if improvisedFlashlight then
            local partFullType = BicyclePartAttachmentService.getTapedFlashlightPartFullType(improvisedFlashlight)
            if BicyclePartAttachmentService.canAttachPart(
                pzPlayer,
                bicycleItem,
                improvisedFlashlight,
                "TapedFlashlight",
                BicyclePartAttachmentService.SourceModeTapedFlashlight,
                ductTape,
                partFullType
            ) then
                subMenuUp:addOption(
                    improvisedFlashlight:getName(),
                    bicycleItem,
                    queueAttachPart,
                    pzPlayer,
                    bicycleItem,
                    improvisedFlashlight,
                    "TapedFlashlight",
                    BicyclePartAttachmentService.SourceModeTapedFlashlight,
                    ductTape,
                    partFullType
                )
                doIt = true
            end
        end
    end

    if doIt then
        local upgradeOption = context:addOption(getText("ContextMenu_BicycleAttachPart"), worldobjects, nil)
        context:addSubMenu(upgradeOption, subMenuUp)
    end

    local detachableParts = bicycleItem:getDetachableWeaponParts(pzPlayer)
    if detachableParts and detachableParts:size() > 0 then
        local removeUpgradeOption = context:addOption(getText("ContextMenu_BicycleRemovePart"), worldobjects, nil)
        local subMenuRemove = context:getNew(context)
        context:addSubMenu(removeUpgradeOption, subMenuRemove)
        for i = 0, detachableParts:size() - 1 do
            local part = detachableParts:get(i)
            subMenuRemove:addOption(part:getName(), bicycleItem, queueDetachPart, pzPlayer, bicycleItem, part)
        end
    end

    -- Three conditions, all required: beside a fence, somewhere on the far side to land, and the bike under the
    -- player. A fence backed by a wall passes the adjacency check alone, showing an option with nowhere to land.
    local throwDir = BicycleWorldUtils.findHoppableDirection(pzPlayer)
    local throwLanding = throwDir and BicycleWorldUtils.findThrowLandingSquare(pzPlayer, throwDir) or nil
    if throwLanding
        and BicycleUtils.isBikeUnderPlayer(pzPlayer, bicycleItem)
        and not BicycleUtils.hasSidecar(bicycleItem) then
        context:addOption(getText("ContextMenu_BicycleThrowOverFence"), worldobjects, BicycleMenu.throwBicycleOverFence, pzPlayer:getPlayerNum(), bicycleItem)
    end

    if bicycleIso then
        local ready, errorText = bicycleHasRideRequirements(bicycleItem, pzPlayer)

        if ready then
            context:addOption(
                getText("ContextMenu_BicycleHopOn"),
                worldobjects,
                BicycleMenu.equipBicycle,
                pzPlayer:getPlayerNum(),
                bicycleIso,
                saddlebagItem,
                basketItem,
                crateItem
            )
        elseif errorText then
            pzPlayer:Say(errorText)
            pzPlayer:setBlockMovement(false)
        end
    end
end

---@param square IsoGridSquare
---@param pzPlayer IsoPlayer|IsoGameCharacter
---@return IsoWorldInventoryObject|nil
---@return InventoryItem|nil
---@return InventoryItem|nil
---@return InventoryItem|nil
function BicycleMenu.findNearestBicycleWithAttachments(square, pzPlayer)
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
                saddlebagItem = item
            end
            if item:getType() == "Basket" then
                basketItem = item
            end
            if item:getType() == "Crate" then
                crateItem = item
            end
        end
    end

    if closestBicycle then
        local bicycleParts = closestBicycle:getItem():getDetachableWeaponParts(pzPlayer)
        local saddlebagFound = false
        local basketFound = false
        local crateFound = false
        for i = 0, bicycleParts:size() - 1 do
            local partName = bicycleParts:get(i):getType()
            if partName == "Bicycle_Saddlebag" then
                saddlebagFound = true
                saddlebagItem = BicycleAttachments.FindFloorItem(closestBicycle, "Saddlebag")
            end
            if partName == "Bicycle_Basket" then
                basketFound = true
                basketItem = BicycleAttachments.FindFloorItem(closestBicycle, "Basket")
            end
            if partName == "Bicycle_Crate" then
                crateFound = true
                crateItem = BicycleAttachments.FindFloorItem(closestBicycle, "Crate")
            end
        end
        if not saddlebagFound and not basketFound and not crateFound then
            return closestBicycle, nil, nil, nil
        end
        return closestBicycle, saddlebagItem, basketItem, crateItem
    end

    return closestBicycle, saddlebagItem, basketItem, crateItem
end

---@param item InventoryItem|nil
---@return InventoryItem|nil
function BicycleMenu.onCreateBicycle(item)
    return BicycleItemInitializer.onCreateBicycle(item)
end

-- Wheel/pedal spin rotates the frame model's wheel + pedal ATTACHMENT objects directly. The rotation
-- lands on the shared ModelScript attachment, which the renderer reads every frame, so every render of
-- that frame shows the spin -- no editor scene, no invalidation needed. (The old AttachmentEditorUI scene
-- only supplied the delta math; constructing it at OnGameStart crashed outside a debug state.) Each bike
-- frame model needs its own rig -- the red bike rides on a separate frame model (Bicycle_Frame_RedStreet).
local ROTATION_FRAME_MODELS = { "Base.Bicycle_Frame", "Base.Bicycle_Frame_RedStreet" }

-- Both the wheel hub and the pedal crank spin on the attachment's X axis.
local SPIN_AXIS = 0

---@type table[] each entry: { modelName, frontWheel, backWheel, pedals }
local rotationRigs = {}

---@param modelName string
---@return table|nil
local function buildRotationRig(modelName)
    if not (ScriptManager and ScriptManager.instance) then
        return nil
    end
    local modelScript = ScriptManager.instance:getModelScript(modelName)
    if not modelScript then
        return nil
    end

    local rig = { modelName = modelName }
    for i = 1, modelScript:getAttachmentCount() do
        local att = modelScript:getAttachment(i - 1)
        local id = att and att:getId() or nil
        if id == "FrontWheel" then
            rig.frontWheel = att
        elseif id == "RearWheel" then
            rig.backWheel = att
        elseif id == "Pedals" then
            rig.pedals = att
        end
    end

    return rig
end

---@return nil
function BicycleMenu.initRotationRigs()
    rotationRigs = {}
    for i = 1, #ROTATION_FRAME_MODELS do
        local rig = buildRotationRig(ROTATION_FRAME_MODELS[i])
        if rig then
            rotationRigs[#rotationRigs + 1] = rig
        end
    end
end

---Advance an attachment's spin axis by a delta. Free-running -- used for the wheels, which are radially
---symmetric and so need no phase lock.
---@param att any
---@param deltaDeg number
local function advancePartSpin(att, deltaDeg)
    if not att then
        return
    end
    local rot = att:getRotate()
    rot:setComponent(SPIN_AXIS, (rot:x() + deltaDeg) % 360)
end

---Set an attachment's spin axis to an ABSOLUTE angle. Used for the pedal crank, which must stay phase
---locked to the rider's feet and therefore cannot be driven by a free-running delta.
---@param att any
---@param angleDeg number
local function setPartSpin(att, angleDeg)
    if not att then
        return
    end
    att:getRotate():setComponent(SPIN_AXIS, angleDeg % 360)
end

---@return nil
function BicycleMenu.rotateWheels()
    for i = 1, #rotationRigs do
        local rig = rotationRigs[i]
        advancePartSpin(rig.frontWheel, 10)
        advancePartSpin(rig.backWheel, 10)
    end
end

---@return nil
function BicycleMenu.rotatePedals()
    for i = 1, #rotationRigs do
        advancePartSpin(rotationRigs[i].pedals, -6.5)
    end
end

---Drive the pedal crank to an absolute angle on every frame rig (phase-locked to the pedal animation).
---@param angleDeg number
function BicycleMenu.setPedalCrank(angleDeg)
    for i = 1, #rotationRigs do
        setPartSpin(rotationRigs[i].pedals, angleDeg)
    end
end

---Introspection for tests/calibration: report each frame rig, which spin parts it captured, and the
---pedal crank's current angle (so calibration can read back what the rider is looking at).
---@return table[]
function BicycleMenu.getRotationRigInfo()
    local out = {}
    for i = 1, #rotationRigs do
        local rig = rotationRigs[i]
        out[#out + 1] = {
            modelName = rig.modelName,
            hasFrontWheel = rig.frontWheel ~= nil,
            hasBackWheel = rig.backWheel ~= nil,
            hasPedals = rig.pedals ~= nil,
            pedalAngle = rig.pedals and rig.pedals:getRotate():x() or nil,
        }
    end
    return out
end

-- ---------------------------------------------------------------------------------------------------
-- Pedal crank phase lock
-- ---------------------------------------------------------------------------------------------------
-- A crank turns at CONSTANT angular velocity within one pedal cycle, so linear interpolation between two
-- loop boundaries is exact, not an approximation. Each pedal clip carries a percentage-timed SetVariable
-- event at m_TimePc=0, which the engine re-fires on every loop wrap. We consume that marker, measure the
-- period of the loop that just ended, and sweep the crank one revolution across the next one.
--
-- Because each loop measures its own period, this self-adapts to any pedal cadence and any clip length:
-- the fast-pedal clip (Bob_Bicycle_PedalFast_New) needs no separate rate constant, and there is no drift
-- to accumulate because every loop re-anchors.
local PEDAL_MARK_VAR = "Bicycle_PedalMark"
local PEDAL_PERIOD_MIN_MS = 80
local PEDAL_PERIOD_MAX_MS = 4000
-- The pedal-loop marker only stops arriving up to a full period after a stop, which left the crank
-- coasting ~1-2s. Detect the stop directly by movement and freeze the crank within this grace. Small
-- enough to feel prompt, big enough to ride through a 1-frame position-delta dip. (isPlayerMoving reports
-- key input only, not click-to-walk, so we use position delta.)
local PEDAL_MOVE_GRACE_MS = 140

---Calibrated per clip. startAngle = crank angle at the loop marker; degreesPerLoop = how far the crank
---turns over one clip loop (360 if the clip is a full revolution, 180 if it authors a single leg stroke).
---Tunable at runtime so calibration needs no reboot.
BicycleMenu.PedalCalibration = {
    walk = { startAngle = 191, degreesPerLoop = -360 },
    fast = { startAngle = 191, degreesPerLoop = -360 },
}

---When set, the crank is pinned to this angle instead of being driven. Calibration aid: freeze the crank
---while the pedal animation keeps playing, so the rider can see which angle lines up with the foot.
BicycleMenu.PedalManualAngle = nil

---@type table<number, number>
local pedalMarkAtMs = {}
---@type table<number, number>
local pedalPeriodMs = {}
---@type table<number, string>
local pedalClip = {}
---@type table<number, {x: number, y: number}>
local pedalLastPos = {}
---@type table<number, number>
local pedalMovingUntil = {}

---Drive the pedal crank for one tick. Call every tick while the bike is held.
---@param player IsoPlayer|IsoGameCharacter
function BicycleMenu.updatePedalCrank(player)
    if BicycleMenu.PedalManualAngle then
        BicycleMenu.setPedalCrank(BicycleMenu.PedalManualAngle)
        return
    end

    local pnum = player:getPlayerNum()
    local nowMs = getTimestampMs()

    -- Consume the marker: clearing it lets the anim event set it again on the next loop wrap.
    local mark = player:getVariableString(PEDAL_MARK_VAR)
    if mark and mark ~= "" then
        player:setVariable(PEDAL_MARK_VAR, "")
        local last = pedalMarkAtMs[pnum]
        if last then
            local period = nowMs - last
            if period >= PEDAL_PERIOD_MIN_MS and period <= PEDAL_PERIOD_MAX_MS then
                pedalPeriodMs[pnum] = period
            end
        end
        pedalMarkAtMs[pnum] = nowMs
        pedalClip[pnum] = mark
    end

    local markAt = pedalMarkAtMs[pnum]
    local period = pedalPeriodMs[pnum]
    if not (markAt and period) then
        return
    end

    -- Stop the crank promptly when the rider stops. Track movement by position delta and hold the crank
    -- (leave it at its last angle) once movement has been absent past the grace window.
    local px, py = player:getX(), player:getY()
    local lp = pedalLastPos[pnum]
    if lp and (math.abs(px - lp.x) > 0.001 or math.abs(py - lp.y) > 0.001) then
        pedalMovingUntil[pnum] = nowMs + (BicycleMenu.PedalStopGraceMs or PEDAL_MOVE_GRACE_MS)
    end
    pedalLastPos[pnum] = { x = px, y = py }
    if not (pedalMovingUntil[pnum] and nowMs < pedalMovingUntil[pnum]) then
        return
    end

    -- Backstop: if a marker somehow stops arriving while still moving, don't sweep past the loop it
    -- belongs to.
    local elapsed = nowMs - markAt
    if elapsed > period * 2 then
        return
    end

    local cal = BicycleMenu.PedalCalibration[pedalClip[pnum] or "walk"] or BicycleMenu.PedalCalibration.walk
    BicycleMenu.setPedalCrank(cal.startAngle + cal.degreesPerLoop * (elapsed / period))
end

---Forget a rider's crank phase (dismount), so the next mount re-anchors from a fresh marker.
---@param player IsoPlayer|IsoGameCharacter
function BicycleMenu.clearPedalCrank(player)
    local pnum = player:getPlayerNum()
    pedalMarkAtMs[pnum] = nil
    pedalPeriodMs[pnum] = nil
    pedalClip[pnum] = nil
    pedalLastPos[pnum] = nil
    pedalMovingUntil[pnum] = nil
end

---Calibration readout: what the crank driver currently believes.
---@param player IsoPlayer|IsoGameCharacter
---@return table
function BicycleMenu.getPedalCrankState(player)
    local pnum = player:getPlayerNum()
    local markAt = pedalMarkAtMs[pnum]
    local period = pedalPeriodMs[pnum]
    local rig = rotationRigs[1]
    return {
        clip = pedalClip[pnum],
        periodMs = period,
        sinceMarkMs = markAt and (getTimestampMs() - markAt) or nil,
        phase = (markAt and period) and ((getTimestampMs() - markAt) / period) or nil,
        crankAngle = rig and rig.pedals and rig.pedals:getRotate():x() or nil,
        manualAngle = BicycleMenu.PedalManualAngle,
        calibration = BicycleMenu.PedalCalibration,
    }
end

---@param pzPlayer IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@nodiscard
local function isNearDoorOrHoppable(pzPlayer)
    if not pzPlayer then
        return false
    end

    local midSquare = pzPlayer:getSquare()
    if not midSquare then
        return false
    end
    local squares = {
        midSquare,
        midSquare:getN(),
        midSquare:getS(),
        midSquare:getE(),
        midSquare:getW(),
    }

    for i = 1, #squares do
        if squareHasDoorWindowOrHoppable(squares[i]) then
            return true
        end
    end

    if playerNearHoppableFence(pzPlayer) then
        local closestBicycle = BicycleMenu.findNearestBicycleWithAttachments(midSquare, pzPlayer)
        if closestBicycle then
            return true
        end
    end

    return false
end

---@param key number
function BicycleMenu.onKeyPressed(key)
    local bicycleOptions = PZAPI.ModOptions:getOptions("BicycleMod")
    local equipKey = bicycleOptions:getOption("BicycleEquipButton"):getValue()
    local pzPlayer = getSpecificPlayer(0)
    clearInvalidEquippedBicycles(pzPlayer)
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

        local hasBell = BicycleMenu.updateBicycleShoutState(pzPlayer, bicycleItem)
        if not hasBell then
            return
        end

        local emitter = pzPlayer:getEmitter()
        local soundVolume = PZAPI.ModOptions:getOptions("BicycleMod"):getOption("BicycleSoundVolume"):getValue()
        local sound = emitter:playSound("Bicycle_Bell")
        emitter:setVolume(sound, soundVolume)
        addSound(nil, pzPlayer:getX(), pzPlayer:getY(), pzPlayer:getZ(), 20, 20)
    end
    if key ~= equipKey then
        return
    end
    if not equipKeyState.isDown then
        if not hasBicycleInteractionTarget(pzPlayer) then
            return
        end
        equipKeyState.isDown = true
        equipKeyState.startMs = getTimestampMs()
        equipKeyState.actionTriggered = false
    end
end

---@param key number
function BicycleMenu.onEquipKeyStart(key)
    local bicycleOptions = PZAPI.ModOptions:getOptions("BicycleMod")
    local equipKey = bicycleOptions:getOption("BicycleEquipButton"):getValue()
    if key ~= equipKey then
        return
    end

    local pzPlayer = getSpecificPlayer(0)
    clearInvalidEquippedBicycles(pzPlayer)
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

---@param pzPlayer IsoPlayer|IsoGameCharacter|nil
---@return boolean
---@nodiscard
local function shouldPreventEquipInteraction(pzPlayer)
    if not pzPlayer then
        return true
    end
    if pzPlayer:isDoingActionThatCanBeCancelled() then
        return true
    end

    if isNearDoorOrHoppable(pzPlayer) then
        return true
    end

    return false
end

---@param wasHeld boolean
---@return boolean
local function performEquipInteraction(wasHeld, playerNum)
    local pzPlayer = getSpecificPlayer(playerNum or 0)
    if shouldPreventEquipInteraction(pzPlayer) then
        return false
    end

    clearInvalidEquippedBicycles(pzPlayer)
    cancelBicycleTimedActions(pzPlayer)
    local currentItem = pzPlayer:getPrimaryHandItem()
    if currentItem and currentItem.isEquipped and not currentItem:isEquipped() then
        currentItem = nil
    end

    if isBicycleItem(currentItem) then
        if not pzPlayer:getVariableBoolean("BicycleActive") then
            return false
        end
        BicycleMenu.dropBicycle(nil, { currentItem }, pzPlayer:getPlayerNum(), wasHeld, true, true)
        return true
    end

    local square = pzPlayer:getSquare()
    local closestBicycle, saddlebagItem, basketItem, crateItem = BicycleMenu.findNearestBicycleWithAttachments(square, pzPlayer)
    if closestBicycle then
        local ready, errorText = bicycleHasRideRequirements(closestBicycle:getItem(), pzPlayer)
        if not bicycleHasPart(closestBicycle:getItem(), "Chain") then
            pzPlayer:Say(getText("IGUI_Bicycle_MissingChain"))
            pzPlayer:setBlockMovement(false)
            return true
        end
        if not ready then
            pzPlayer:Say(errorText)
            pzPlayer:setBlockMovement(false)
            return true
        end
        BicycleMenu.equipBicycle({ closestBicycle }, pzPlayer:getPlayerNum(), closestBicycle, saddlebagItem, basketItem, crateItem)
    end

    return false
end

---@return nil
local function handleEquipKeyHold()
    local bicycleOptions = PZAPI.ModOptions:getOptions("BicycleMod")
    local equipKey = bicycleOptions:getOption("BicycleEquipButton"):getValue()

    if not equipKeyState.isDown or not isKeyDown(equipKey) or equipKeyState.actionTriggered then
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

---@return nil
local function handleEquipKeyRelease()
    local bicycleOptions = PZAPI.ModOptions:getOptions("BicycleMod")
    local equipKey = bicycleOptions:getOption("BicycleEquipButton"):getValue()
    if not equipKeyState.isDown or isKeyDown(equipKey) then
        return
    end

    local pzPlayer = getSpecificPlayer(0)
    clearInvalidEquippedBicycles(pzPlayer)
    if shouldPreventEquipInteraction(pzPlayer) then
        equipKeyState.isDown = false
        equipKeyState.actionTriggered = false
        return
    end
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

---@return nil
function BicycleMenu.updateKeyState()
    handleEquipKeyHold()
    handleEquipKeyRelease()
end

---@param worldObjects IsoObject[]|nil
---@param playerObj IsoPlayer|IsoGameCharacter
---@param item InventoryItem
---@param src ItemContainer
---@param dest ItemContainer
---@param time number
function BicycleMenu.transferToTrunk(worldObjects, playerObj, item, src, dest, time)
    local action = ISInventoryTransferAction:new(playerObj, item, src, dest, time)
    if action and dest then
        action.bicycleForcedAttachmentDest = dest
    end
    ISTimedActionQueue.add(action)
end

---@param player number
---@param context ISContextMenu
---@param worldobjects IsoObject[]
---@param test boolean
function BicycleMenu.addWorldContext(player, context, worldobjects, test)
    local pzPlayer = getSpecificPlayer(player)
    if BicycleMenu.addEquippedContextOptions(pzPlayer, context, worldobjects) then
        return
    end

    local origSquare = worldobjects[1]:getSquare()
    if not instanceof(origSquare, "IsoGridSquare") then
        return
    end

    local closestBicycle, saddlebagItem, basketItem, crateItem = BicycleMenu.findNearestBicycleWithAttachments(origSquare, pzPlayer)

    if closestBicycle then
        addBicycleOptions(context, pzPlayer, closestBicycle:getItem(), worldobjects, saddlebagItem, basketItem, crateItem, closestBicycle)
    end
end

---@param player number
---@param context ISContextMenu
---@param items table
function BicycleMenu.addInventoryContext(player, context, items)
    local pzPlayer = getSpecificPlayer(player)

    if BicycleMenu.addEquippedContextOptions(pzPlayer, context, items) then
        return
    end

    local bicycleItem = nil

    for _, value in ipairs(items) do
        local testItem = value
        if not instanceof(value, "InventoryItem") and value.items then
            testItem = value.items[1]
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

---@param worldobjects IsoObject[]|nil
---@param player number
---@param item IsoWorldInventoryObject|InventoryItem
---@param saddlebag IsoWorldInventoryObject|InventoryItem|nil
---@param basket IsoWorldInventoryObject|InventoryItem|nil
---@param crate IsoWorldInventoryObject|InventoryItem|nil
function BicycleMenu.equipBicycle(worldobjects, player, item, saddlebag, basket, crate)
    local pzPlayer = getSpecificPlayer(player)
    cancelBicycleTimedActions(pzPlayer)
    local inventoryItem = item and item.getItem and item:getItem() or item
    if not inventoryItem then
        return
    end

    if isClient() and inventoryItem.getID then
        local duplicateItem = pzPlayer:getInventory():getItemWithID(inventoryItem:getID())
        if duplicateItem and duplicateItem ~= inventoryItem then
            BicycleUtils.removeItemFromContainer(duplicateItem)
        end
    end

    local worldItem = inventoryItem:getWorldItem()
    local squarePlayer = pzPlayer:getSquare()
    local squareItem = worldItem and worldItem:getSquare() or (item and item.getSquare and item:getSquare() or nil)
    BicycleDebug.log(
        "BicycleMenu:equipBicycle start player=" .. BicycleDebug.describePlayer(pzPlayer)
            .. ", item=" .. BicycleDebug.describeItem(inventoryItem)
            .. ", worldSquare=" .. BicycleDebug.describeSquare(squareItem)
            .. ", playerSquare=" .. BicycleDebug.describeSquare(squarePlayer)
            .. ", " .. describeTimedActionQueue(pzPlayer)
    )
    if not (squarePlayer and squareItem) then
        BicycleDebug.log("BicycleMenu:equipBicycle abort missing square context")
        return
    end
    local itemX = squareItem:getX()
    local itemY = squareItem:getY()

    pzPlayer:faceLocation(itemX, itemY)

    local distance = BicycleMenu.getDistance2D(squarePlayer:getX(), squarePlayer:getY(), itemX, itemY)
    if distance > 1.5 then
        ISTimedActionQueue.add(ISWalkToTimedAction:new(pzPlayer, squareItem))
    end

    pzPlayer:setBlockMovement(true)
    BicycleUtils.runAfter(0.4, function()
        pzPlayer:setBlockMovement(false)
    end)
    BicycleMigration.normalizeKickstandState(inventoryItem, pzPlayer)

    if inventoryItem:getWorldItem() then
        -- A bike lying on the ground has no source container: IsoWorldInventoryObject's constructor
        -- calls item:setContainer(null). Handing that nil straight to the transfer action makes
        -- ISInventoryTransferAction:new bail out early, before it builds queueList/transactions, and
        -- vanilla only survives that half-built action because isValid() returns false and the engine
        -- stops it. Our bicycleMount short-circuit in isValid() forces it valid, so the engine runs it
        -- to completion and perform() dies on table.remove(nil, 1) -- stranding the queue and dropping
        -- the equip + hop-on actions behind it, so the bike never mounts.
        --
        -- Vanilla picks ground items up by transferring them out of the per-player pseudo "floor"
        -- container (ISTransferAction:transferItem removes the world item when srcContainer:getType() is
        -- "floor"). Reuse that exact container: ISInventoryTransferAction:isValid() rejects any source
        -- that ISInventoryPaneContextMenu.getContainers() doesn't list, so a freshly built one would not
        -- survive a non-bicycleMount validity check.
        local srcContainer = inventoryItem:getContainer()
        if not srcContainer then
            srcContainer = ISInventoryPage.floorContainer and ISInventoryPage.floorContainer[player + 1] or nil
        end
        if not srcContainer and squareItem then
            srcContainer = ItemContainer.new("floor", squareItem, nil)
        end

        local transferAction = ISInventoryTransferUtil.newInventoryTransferAction(
            pzPlayer,
            inventoryItem,
            srcContainer,
            pzPlayer:getInventory()
        )
        transferAction.maxTime = 1
        transferAction.stopOnWalk = false
        transferAction.stopOnRun = false
        transferAction.bicycleMount = true
        ISTimedActionQueue.add(transferAction)
        BicycleDebug.log(
            "BicycleMenu:equipBicycle queued transfer action type=" .. tostring(transferAction.Type)
                .. ", item=" .. BicycleDebug.describeItem(inventoryItem)
                .. ", srcContainer=" .. tostring(srcContainer and srcContainer:getType() or "nil")
                .. ", " .. describeTimedActionQueue(pzPlayer)
        )

        local equipAction = ISEquipWeaponAction:new(pzPlayer, inventoryItem, 1, true, true)
        equipAction.stopOnWalk = false
        equipAction.stopOnRun = false
        ISTimedActionQueue.add(equipAction)
        BicycleDebug.log(
            "BicycleMenu:equipBicycle queued equip action type=" .. tostring(equipAction.Type)
                .. ", item=" .. BicycleDebug.describeItem(inventoryItem)
                .. ", " .. describeTimedActionQueue(pzPlayer)
        )
    else
        ISInventoryPaneContextMenu.equipWeapon(inventoryItem, true, true, player)
        BicycleDebug.log(
            "BicycleMenu:equipBicycle used vanilla equipWeapon item=" .. BicycleDebug.describeItem(inventoryItem)
                .. ", " .. describeTimedActionQueue(pzPlayer)
        )
    end

    local action = getBicycleHopOnAction():new(pzPlayer, inventoryItem, saddlebag, basket, crate)
    ISTimedActionQueue.add(action)
    BicycleDebug.log(
        "BicycleMenu:equipBicycle queued hopOn item=" .. BicycleDebug.describeItem(inventoryItem)
            .. ", " .. describeTimedActionQueue(pzPlayer)
    )
    BicycleMountRecovery.schedule(pzPlayer, inventoryItem)
end

---@param square IsoGridSquare
---@return IsoObject[]
---@nodiscard
function BicycleMenu.getItems(square)
    if instanceof(square, "IsoGridSquare") == false then
        return {}
    end

    return BicycleWorldUtils.getLuaTileObjects(square)
end

---@return nil
function BicycleMenu.initBicycle(playerNum)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local speedMultSlow, speedMultFast = BicycleOptions.getSpeedMultipliers()
    local primaryItem = player:getPrimaryHandItem()
    local hasBike = isBicycleItem(primaryItem)

    if not hasBike then
        BicycleMountDismountState.resetAllBikeVariables(player)
        player:setIgnoreAutoVault(false)
        player:setBannedAttacking(false)
        player:setBlockMovement(false)
        player:setIgnoreMovement(false)
        player:setAllowRun(true)
        player:setForceSprint(false)
        player:setCanShout(true)
        player:setVariable("BicycleWalkSpeed", speedMultSlow)
        player:setVariable("BicycleRunSpeed", speedMultFast)
    end

    BicycleRidingSystem.ensureUpdateHandlers()

    if hasBike then
        BicycleMenu.enterMountedState(player, primaryItem, nil)
    end
end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number
---@nodiscard
function BicycleMenu.getDistance2D(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

---@return nil
function SpawnBicycle()
    local player = getSpecificPlayer(0)
    if isClient() then
        if not BicycleOptions.canUseSpawnButtons(player) then
            return
        end
        Bicycle.ClientSync.requestSpawnDebugItem("Bicycle.Bicycle")
    elseif isServer() then
        if not BicycleOptions.canUseSpawnButtons(player) then
            return
        end
        local item = player:getInventory():AddItem("Bicycle.Bicycle")
        if item then
            sendAddItemToContainer(player:getInventory(), item)
        end
    else
        player:getInventory():AddItem("Bicycle.Bicycle")
    end
end

---@return nil
function SpawnBicycleSaddlebag()
    local player = getSpecificPlayer(0)
    if isClient() then
        if not BicycleOptions.canUseSpawnButtons(player) then
            return
        end
        Bicycle.ClientSync.requestSpawnDebugItem("Bicycle.Bicycle_Saddlebag")
    elseif isServer() then
        if not BicycleOptions.canUseSpawnButtons(player) then
            return
        end
        local item = player:getInventory():AddItem("Bicycle.Bicycle_Saddlebag")
        if item then
            sendAddItemToContainer(player:getInventory(), item)
        end
    else
        player:getInventory():AddItem("Bicycle.Bicycle_Saddlebag")
    end
end

---@return nil
function SpawnBicycleBasket()
    local player = getSpecificPlayer(0)
    if isClient() then
        if not BicycleOptions.canUseSpawnButtons(player) then
            return
        end
        Bicycle.ClientSync.requestSpawnDebugItem("Bicycle.Bicycle_Basket")
    elseif isServer() then
        if not BicycleOptions.canUseSpawnButtons(player) then
            return
        end
        local item = player:getInventory():AddItem("Bicycle.Bicycle_Basket")
        if item then
            sendAddItemToContainer(player:getInventory(), item)
        end
    else
        player:getInventory():AddItem("Bicycle.Bicycle_Basket")
    end
end

---@return nil
function SpawnBicycleCrate()
    local player = getSpecificPlayer(0)
    if isClient() then
        if not BicycleOptions.canUseSpawnButtons(player) then
            return
        end
        Bicycle.ClientSync.requestSpawnDebugItem("Bicycle.Bicycle_Crate")
    elseif isServer() then
        if not BicycleOptions.canUseSpawnButtons(player) then
            return
        end
        local item = player:getInventory():AddItem("Bicycle.Bicycle_Crate")
        if item then
            sendAddItemToContainer(player:getInventory(), item)
        end
    else
        player:getInventory():AddItem("Bicycle.Bicycle_Crate")
    end
end

---@return nil
function FixAutoVault()
    local player = getSpecificPlayer(0)
    player:setIgnoreAutoVault(false)
end

Events.OnKeyPressed.Add(BicycleMenu.onKeyPressed)
if Events.OnKeyStartPressed then
    Events.OnKeyStartPressed.Add(BicycleMenu.onEquipKeyStart)
end
Events.OnPlayerUpdate.Add(BicycleMenu.updateKeyState)
Events.OnGameStart.Add(BicycleMenu.initRotationRigs)
Events.OnCreatePlayer.Add(BicycleMenu.initBicycle)
Events.OnPreFillWorldObjectContextMenu.Add(BicycleMenu.addWorldContext)
Events.OnPreFillInventoryObjectContextMenu.Add(BicycleMenu.addInventoryContext)

return BicycleMenu
