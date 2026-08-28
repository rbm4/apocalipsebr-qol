require("TimedActions/ISBaseTimedAction")
require("Bicycle/BicycleCore")
require("Bicycle/BicycleOptions")

local BicycleDebug = require("Bicycle/Debug")
local BicycleKickstand = require("Bicycle/Kickstand")
local BicycleMigration = require("Bicycle/Migration")
local BicycleMountDismountState = require("Bicycle/MountDismountState")
local BicycleUtils = require("Bicycle/Utils")
local ThrowRotations = require("Bicycle/ThrowRotations")

---@type table|nil
local BicycleMenu = nil
---@type table|nil
local BicycleRidingSystem = nil

---@return table|nil
local function getBicycleMenu()
    if BicycleMenu then
        return BicycleMenu
    end

    if isClient() then
        BicycleMenu = require("Bicycle/BicycleMenu")
    elseif isServer() then
        BicycleMenu = nil
    else
        BicycleMenu = require("Bicycle/BicycleMenu")
    end

    return BicycleMenu
end

---@return table|nil
local function getBicycleRidingSystem()
    if BicycleRidingSystem then
        return BicycleRidingSystem
    end

    if isClient() then
        BicycleRidingSystem = require("Bicycle/Systems/RidingSystem")
    elseif isServer() then
        BicycleRidingSystem = nil
    else
        BicycleRidingSystem = require("Bicycle/Systems/RidingSystem")
    end

    return BicycleRidingSystem
end

---@return number
---@return number
local function resolveSpeedMultipliers()
    return Bicycle.Options.getSpeedMultipliers()
end

---@param bikeItem InventoryItem|nil
---@param xRot number|nil
---@param yRot number|nil
---@param zRot number|nil
---@return string
local function resolveMountAnim(bikeItem, xRot, yRot, zRot)
    local hasKickstandDown = bikeItem
        and bikeItem.getWeaponPart
        and bikeItem:getWeaponPart("KickstandDown") ~= nil
    if hasKickstandDown then
        return "kickstandUp"
    end

    local _, rotation = ThrowRotations.findMatchingRotation(xRot, yRot, zRot)
    if rotation then
        return "pickUp"
    end

    return "pickUp"
end

---@param action BicycleHopOnAction
---@return InventoryItem|nil
local function resolveBikeItem(action)
    if not action.character then
        return nil
    end

    local bikeItem = action.item and action.item.getItem and action.item:getItem() or action.item
    if BicycleUtils.isBicycleItem(bikeItem) then
        if bikeItem.getID then
            local inventoryItem = action.character:getInventory():getItemWithID(bikeItem:getID())
            if inventoryItem then
                action.item = inventoryItem
                return inventoryItem
            end
        end
        return bikeItem
    end

    if action.itemId then
        local inventoryItem = action.character:getInventory():getItemWithID(action.itemId)
        if BicycleUtils.isBicycleItem(inventoryItem) then
            action.item = inventoryItem
            return inventoryItem
        end

        local core = Bicycle and Bicycle.Core or nil
        local nearbyItem = core and core.findItemById and core.findItemById(action.character, action.itemId) or nil
        if BicycleUtils.isBicycleItem(nearbyItem) then
            action.item = nearbyItem
            return nearbyItem
        end
    end

    local primaryItem = action.character:getPrimaryHandItem()
    if BicycleUtils.isBicycleItem(primaryItem) then
        action.item = primaryItem
        return primaryItem
    end

    local secondaryItem = action.character:getSecondaryHandItem()
    if BicycleUtils.isBicycleItem(secondaryItem) then
        action.item = secondaryItem
        return secondaryItem
    end

    return nil
end

---@param action BicycleHopOnAction
---@return string
local function getMountAnim(action)
    if action.mountAnim and action.mountAnim ~= "" then
        return action.mountAnim
    end

    local bikeItem = resolveBikeItem(action)
    action.mountAnim = resolveMountAnim(bikeItem, action.bikeXRotation, action.bikeYRotation, action.bikeZRotation)
    return action.mountAnim
end

---@class BicycleHopOnAction : ISBaseTimedAction
BicycleHopOnAction = ISBaseTimedAction:derive("BicycleHopOnAction")

---@type BicycleHopOnAction|nil
local bicycleHopOnInstance = nil

---@param character IsoPlayer|IsoGameCharacter|nil
---@return string
local function describeHands(character)
    if not character then
        return "hands=nil"
    end

    return "primary=" .. BicycleDebug.describeItem(character:getPrimaryHandItem())
        .. ", secondary=" .. BicycleDebug.describeItem(character:getSecondaryHandItem())
end

---@param action BicycleHopOnAction
---@param label string
local function logHopOnState(action, label)
    BicycleDebug.log(
        "BicycleHopOnAction:" .. label
            .. " item=" .. BicycleDebug.describeItem(action.item)
            .. ", itemId=" .. tostring(action.itemId)
            .. ", resolved=" .. BicycleDebug.describeItem(resolveBikeItem(action))
            .. ", sourceSquare=" .. BicycleDebug.describeSquare(action.sourceSquare)
            .. ", restoreBikeToWorld=" .. tostring(action.restoreBikeToWorld)
            .. ", " .. describeHands(action.character)
    )
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@return boolean
local function clearBikeFromHandsById(character, bikeItem)
    if not (character and bikeItem and bikeItem.getID) then
        return false
    end

    local bikeId = bikeItem:getID()
    local changed = false

    local primaryItem = character:getPrimaryHandItem()
    if BicycleUtils.isBicycleItem(primaryItem) and primaryItem.getID and primaryItem:getID() == bikeId then
        character:setPrimaryHandItem(nil)
        changed = true
    end

    local secondaryItem = character:getSecondaryHandItem()
    if BicycleUtils.isBicycleItem(secondaryItem) and secondaryItem.getID and secondaryItem:getID() == bikeId then
        character:setSecondaryHandItem(nil)
        changed = true
    end

    if changed then
        character:resetEquippedHandsModels()
    end

    return changed
end

---@param action BicycleHopOnAction
local function restoreMountStartState(action)
    local character = action.character
    if not character then
        return
    end

    character:setBlockMovement(false)
    character:setIgnoreMovement(false)
    character:setTurnDelta(1)
    character:setVariable("Bicycle_Riding", "false")
    character:setVariable("BicycleActive", "false")
    character:setVariable("Bicycle_Stopping", false)
    character:setAllowRun(true)
    character:setForceSprint(false)
    character:setCanShout(true)
    character:setBannedAttacking(false)
    character:setIgnoreAutoVault(false)

    local ridingSystem = getBicycleRidingSystem()
    if ridingSystem then
        ridingSystem.clearUpdateHandlers()
    end
end

---@param self BicycleHopOnAction
function BicycleHopOnAction:isValid()
    local valid = self.character ~= nil and resolveBikeItem(self) ~= nil
    BicycleDebug.log("BicycleHopOnAction:isValid valid=" .. tostring(valid) .. ", resolved=" .. BicycleDebug.describeItem(resolveBikeItem(self)))
    return valid
end

---@param self BicycleHopOnAction
---@return boolean
function BicycleHopOnAction:waitToStart()
    return false
end

---@param self BicycleHopOnAction
function BicycleHopOnAction:update()
    if self.started and self.mountAnimSet and self.character:getVariableString("mountAnim") == "" then
        self:forceComplete()
    end
end

---@param self BicycleHopOnAction
function BicycleHopOnAction:start()
    logHopOnState(self, "start:before")
    self.started = true

    local bikeItem = resolveBikeItem(self)
    local mountAnim = getMountAnim(self)
    local bicycleMenu = getBicycleMenu()
    if bicycleMenu then
        bicycleMenu.enterMountedState(self.character, bikeItem, mountAnim)
    else
        BicycleMountDismountState.prepareMount(self.character, mountAnim)
    end
    self.mountAnimSet = mountAnim ~= nil and mountAnim ~= ""

    if self.mountDirection then
        self.character:setTurnDelta(100)
        self.character:setDir(self.mountDirection)
    end

    if isClient() then
        self.character:setVariable("Bicycle_MountPending", true)
        BicycleDebug.log("BicycleHopOnAction:start client visual mount; complete() runs on server")
    elseif isServer() then
        BicycleDebug.log("BicycleHopOnAction:start server-side visual mount skipped")
    else
        BicycleDebug.log("BicycleHopOnAction:start singleplayer visual mount active")
    end
    logHopOnState(self, "start:after")
end

---@param self BicycleHopOnAction
function BicycleHopOnAction:stop()
    logHopOnState(self, "stop:before")

    local bikeItem = resolveBikeItem(self)
    if bikeItem then
        clearBikeFromHandsById(self.character, bikeItem)
    end
    restoreMountStartState(self)
    BicycleMountDismountState.finishMount(self.character)
    self.character:setVariable("Bicycle_MountPending", false)

    if isClient() then
        if Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.requestCancelMount then
            local rotation = nil
            if self.bikeXRotation or self.bikeYRotation or self.bikeZRotation then
                rotation = {
                    x = self.bikeXRotation,
                    y = self.bikeYRotation,
                    z = self.bikeZRotation
                }
            end
            Bicycle.ClientSync.requestCancelMount(self.itemId, self.sourceSquare, rotation, self.mountActionId)
        end
    elseif isServer() then
    else
        if self.restoreBikeToWorld and self.sourceSquare then
            local bikeItem = resolveBikeItem(self)
            if bikeItem and bikeItem:getContainer() == self.character:getInventory() then
                BicycleUtils.removeItemFromContainer(bikeItem)
                local droppedBikeItem = BicycleUtils.addPersistentWorldItem(self.sourceSquare, bikeItem, 0, 0, 0) or bikeItem
                if self.bikeXRotation and droppedBikeItem.setWorldXRotation then
                    droppedBikeItem:setWorldXRotation(self.bikeXRotation)
                end
                if self.bikeYRotation and droppedBikeItem.setWorldYRotation then
                    droppedBikeItem:setWorldYRotation(self.bikeYRotation)
                end
                if self.bikeZRotation and droppedBikeItem.setWorldZRotation then
                    droppedBikeItem:setWorldZRotation(self.bikeZRotation)
                end
            end
        end
    end

    bicycleHopOnInstance = nil
    logHopOnState(self, "stop:after")
    ISBaseTimedAction.stop(self)
end

---@param self BicycleHopOnAction
function BicycleHopOnAction:perform()
    logHopOnState(self, "perform:before")
    if self.mountDirection then
        self.character:setBlockMovement(false)
        self.character:setIgnoreMovement(false)
        self.character:setTurnDelta(1)
    end

    if isClient() then
        if Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.syncState then
            Bicycle.ClientSync.syncState(self.character, true)
        end
    elseif isServer() then
        -- Server mutates in :complete().
    else
        -- SP mutates in :complete().
    end

    BicycleMountDismountState.finishMount(self.character)
    bicycleHopOnInstance = nil

    logHopOnState(self, "perform:after")
    ISBaseTimedAction.perform(self)
end

---@param self BicycleHopOnAction
---@return boolean
function BicycleHopOnAction:complete()
    local bikeItem = resolveBikeItem(self)
    if not bikeItem then
        BicycleDebug.log("BicycleHopOnAction:complete abort no resolved bike")
        return false
    end

    if isServer() and Bicycle.Sync and Bicycle.Sync.consumeMountCancel
        and Bicycle.Sync.consumeMountCancel(self.character:getOnlineID(), bikeItem:getID(), self.mountActionId) then
        BicycleDebug.log("BicycleHopOnAction:complete cancelled before commit itemId=" .. tostring(bikeItem:getID()))
        return false
    end

    local inventory = self.character:getInventory()
    local container = bikeItem:getContainer()

    if bikeItem:getWorldItem() then
        BicycleUtils.removeWorldItem(bikeItem)
    end

    if container and container ~= inventory then
        BicycleUtils.removeItemFromContainer(bikeItem)
    end

    if bikeItem:getContainer() ~= inventory then
        inventory:AddItem(bikeItem)
        if isServer() then
            sendAddItemToContainer(inventory, bikeItem)
        end
    end

    BicycleMigration.normalizeKickstandState(bikeItem, self.character)
    BicycleKickstand.ensureState(bikeItem, self.character, "up")
    self.character:setVariable("BicycleActive", "true")
    self.character:setVariable("Bicycle_Riding", "false")
    self.character:setVariable("Bicycle_Stopping", false)
    self.character:setVariable("droppingBicycle", false)

    if isClient() then
    elseif isServer() then
        sendServerCommand(self.character, Bicycle.Core.SyncModule, "MountEquip", {
            itemId = bikeItem:getID()
        })
    else
        -- Singleplayer: no packet races.
        self.character:setPrimaryHandItem(bikeItem)
        self.character:setSecondaryHandItem(bikeItem)
        self.character:resetEquippedHandsModels()
    end

    BicycleDebug.log("BicycleHopOnAction:complete equipped bike=" .. BicycleDebug.describeItem(bikeItem))
    return true
end

---@param itemId number
---@return string|nil
function BicycleHopOnAction.getQueuedMountAnimForItemId(itemId)
    if bicycleHopOnInstance and bicycleHopOnInstance.itemId == itemId then
        return bicycleHopOnInstance.mountAnim
    end

    return nil
end

---@param item InventoryItem|nil
---@return string|nil
function BicycleHopOnAction.getQueuedMountAnimForItem(item)
    if not (item and item.getID) then
        return nil
    end

    return BicycleHopOnAction.getQueuedMountAnimForItemId(item:getID())
end

---@param self BicycleHopOnAction
---@return number
function BicycleHopOnAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    if getMountAnim(self) == "kickstandUp" then
        return 60
    end

    return 90
end

---@param character IsoPlayer|IsoGameCharacter
---@param item InventoryItem|IsoWorldInventoryObject
---@param saddlebag InventoryItem|IsoWorldInventoryObject|nil
---@param basket InventoryItem|IsoWorldInventoryObject|nil
---@param crate InventoryItem|IsoWorldInventoryObject|nil
---@return BicycleHopOnAction
function BicycleHopOnAction:new(character, item, saddlebag, basket, crate)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.inventory = character:getInventory()
    o.mountActionId = getTimestampMs()
    local bikeItem = item and item.getItem and item:getItem() or item
    local worldItem = bikeItem and bikeItem.getWorldItem and bikeItem:getWorldItem() or nil
    o.item = bikeItem or item
    o.itemId = bikeItem and bikeItem.getID and bikeItem:getID() or nil
    o.saddlebag = nil
    o.basket = nil
    o.crate = nil
    o.restoreBikeToWorld = worldItem ~= nil
    o.sourceSquare = worldItem and worldItem:getSquare() or nil
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = false
    o.speedMultSlow, o.speedMultFast = resolveSpeedMultipliers()

    local wheelConfig = { offroad = 0, street = 0 }
    local bicycleMenu = getBicycleMenu()
    if bicycleMenu then
        wheelConfig = bicycleMenu.getWheelConfiguration(bikeItem, character)
    end

    local hasOffroadPair = wheelConfig.offroad >= 2 and wheelConfig.street == 0
    if hasOffroadPair then
        local speedMultiplier = bicycleMenu and bicycleMenu.OffroadSpeedMultiplier or 1
        o.speedMultSlow = o.speedMultSlow * speedMultiplier
        o.speedMultFast = o.speedMultFast * speedMultiplier
    end

    o.bikeXRotation = bikeItem and bikeItem.getWorldXRotation and bikeItem:getWorldXRotation() or nil
    o.bikeYRotation = bikeItem and bikeItem.getWorldYRotation and bikeItem:getWorldYRotation() or nil
    o.bikeZRotation = bikeItem and bikeItem.getWorldZRotation and bikeItem:getWorldZRotation() or nil
    o.mountAnim = resolveMountAnim(bikeItem, o.bikeXRotation, o.bikeYRotation, o.bikeZRotation)

    local normalizedZRotation = o.bikeZRotation and BicycleUtils.normalizeZRotation(o.bikeZRotation - 90) or nil
    o.mountDirection = BicycleUtils.zRotationToDirection(normalizedZRotation)

    if character and character.getVariableString and character:getVariableString("mountAnim") == "pickUp" then
        local _, rotation = ThrowRotations.findMatchingRotation(o.bikeXRotation, o.bikeYRotation, o.bikeZRotation)
        if rotation and rotation.faceDir then
            local faceDirRotation = BicycleUtils.normalizeZRotation(rotation.faceDir)
            local faceDirection = BicycleUtils.zRotationToDirection(faceDirRotation)
            if faceDirection then
                o.mountDirection = faceDirection
            end
        end
    end

    if saddlebag then
        o.saddlebag = saddlebag.getItem and saddlebag:getItem() or saddlebag
    end
    if basket then
        o.basket = basket.getItem and basket:getItem() or basket
    end
    if crate then
        o.crate = crate.getItem and crate:getItem() or crate
    end

    o.maxTime = o:getDuration()

    bicycleHopOnInstance = o
    logHopOnState(o, "new")
    return o
end

_G[BicycleHopOnAction.Type] = BicycleHopOnAction

return BicycleHopOnAction
