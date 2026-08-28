require("TimedActions/ISBaseTimedAction")
require("Bicycle/BicycleCore")

local BicycleContainerManager = nil
local BicycleDropBehavior = require("Bicycle/DropBehavior")
local BicycleKickstand = require("Bicycle/Kickstand")
local BicycleMigration = require("Bicycle/Migration")
local BicycleMountDismountState = require("Bicycle/MountDismountState")
local BicycleUtils = require("Bicycle/Utils")
local BicycleRidingSystem = nil
if isClient() then
    BicycleContainerManager = nil
    BicycleRidingSystem = require("Bicycle/Systems/RidingSystem")
elseif isServer() then
    BicycleContainerManager = require("Bicycle/BicycleContainerManager")
    BicycleRidingSystem = nil
else
    BicycleContainerManager = require("Bicycle/BicycleContainerManager")
    BicycleRidingSystem = require("Bicycle/Systems/RidingSystem")
end

-- Retried on first use, not captured at load time. On a dedicated server this file loads BEFORE
-- server/Bicycle/BicycleContainerManager.lua, so the require above fails and the upvalue stays nil
-- for the whole session -- silently skipping container sync for every bike put down.
---@return BicycleContainerManager|nil
local function getBicycleContainerManager()
    if BicycleContainerManager then
        return BicycleContainerManager
    end
    if isClient() then
        return nil
    end
    BicycleContainerManager = require("Bicycle/BicycleContainerManager")
    return BicycleContainerManager
end

---@param value any
---@return string|nil
---@nodiscard
local function boolToString(value)
    if value == true or value == "true" then return "true" end
    if value == false or value == "false" then return "false" end
    return nil
end

---@param value any
---@return boolean|nil
---@nodiscard
local function parseBool(value)
    if value == true or value == "true" then return true end
    if value == false or value == "false" then return false end
    return nil
end

---@class BicycleDismountAction : ISBaseTimedAction
BicycleDismountAction = ISBaseTimedAction:derive("BicycleDismountAction")

---@param action BicycleDismountAction
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
    end

    local primaryItem = action.character:getPrimaryHandItem()
    if BicycleUtils.isBicycleItem(primaryItem) then
        action.item = primaryItem
        return primaryItem
    end

    return nil
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
local function clearBikeFromHandsById(character, bikeItem)
    if not (character and bikeItem and bikeItem.getID) then
        return
    end

    local bikeId = bikeItem:getID()
    local primaryItem = character:getPrimaryHandItem()
    if BicycleUtils.isBicycleItem(primaryItem) and primaryItem.getID and primaryItem:getID() == bikeId then
        character:setPrimaryHandItem(nil)
    end

    local secondaryItem = character:getSecondaryHandItem()
    if BicycleUtils.isBicycleItem(secondaryItem) and secondaryItem.getID and secondaryItem:getID() == bikeId then
        character:setSecondaryHandItem(nil)
    end
end

---@param action BicycleDismountAction
local function restoreMountedState(action)
    local character = action.character
    if not character then
        return
    end

    character:setVariable("BicycleActive", "true")
    character:setIgnoreAutoVault(true)
    character:setBannedAttacking(true)
    character:setAllowRun(false)

    local bikeItem = resolveBikeItem(action)
    if bikeItem and bikeItem.getID and not character:getInventory():getItemWithID(bikeItem:getID()) then
        bikeItem = nil
    end
    if bikeItem and character:getPrimaryHandItem() ~= bikeItem then
        character:setPrimaryHandItem(bikeItem)
        character:setSecondaryHandItem(bikeItem)
        if isServer() then
            syncHandWeaponFields(character, bikeItem)
            if sendEquip then
                sendEquip(character)
            end
        elseif not isClient() then
            character:resetEquippedHandsModels()
        end
    end

    if BicycleRidingSystem then
        BicycleRidingSystem.updateBicycleFlag(character)
        BicycleRidingSystem.ensureUpdateHandlers()
    end
end

---@param self BicycleDismountAction
---@return boolean
function BicycleDismountAction:isValid()
    return self.character ~= nil and resolveBikeItem(self) ~= nil
end

---@param self BicycleDismountAction
---@return boolean
function BicycleDismountAction:waitToStart()
    return false
end

---@param self BicycleDismountAction
function BicycleDismountAction:update()
    if self.started
        and self.character:getVariableString("dismountAnim") == ""
        and not self.character:getVariableBoolean("Dismounting") then
        self:forceComplete()
    end
end

---@param self BicycleDismountAction
function BicycleDismountAction:start()
    self.started = true
    BicycleMountDismountState.beginDismount(self.character, self.dismountData)
    self:setActionAnim(self.actionAnim)
end

---@param self BicycleDismountAction
function BicycleDismountAction:stop()
    if isClient() then
        restoreMountedState(self)
    elseif isServer() then
        restoreMountedState(self)
    else
        if self.character and self.character.setTimedActionToRetrigger then
            self.character:setTimedActionToRetrigger(nil)
        end
    end
    BicycleMountDismountState.finishDismount(self.character)
    if BicycleRidingSystem and BicycleRidingSystem.clearFallDropScheduled then
        BicycleRidingSystem.clearFallDropScheduled(self.character)
    end
    ISBaseTimedAction.stop(self)
end

---@param self BicycleDismountAction
function BicycleDismountAction:perform()
    if isClient() then
        local currentBikeItem = resolveBikeItem(self)
        if self.onComplete and currentBikeItem then
            self.onComplete(self.character, currentBikeItem, self.dismountData)
        else
            BicycleMountDismountState.finishDismount(self.character)
        end
    end

    ISBaseTimedAction.perform(self)
end

---@param self BicycleDismountAction
---@return boolean
function BicycleDismountAction:complete()
    local currentBikeItem = resolveBikeItem(self)
    if not currentBikeItem then
        return false
    end
    self.item = currentBikeItem

    if not self.dismountData or self.dismountData.kickstandDown == nil then
        local kickstandDown = parseBool(self.dm_kickstandDown)
        local shiftHeld = parseBool(self.dm_shiftHeld)

        if kickstandDown == nil and shiftHeld == nil then
            local anim = self.dm_dismountAnim or self.actionAnim
            if anim == "kickstandDown" then
                kickstandDown = true
                shiftHeld = false
            else
                kickstandDown = false
                shiftHeld = true
            end
        end

        self.dismountData = {
            kickstandDown = kickstandDown,
            shiftHeld = shiftHeld,
            dismountAnim = self.dm_dismountAnim or self.actionAnim,
            zRotation = self.dm_zRotation,
            direction = self.character:getDir(),
        }
    end

    -- Outside the block above on purpose: a sidecar overrides an explicit kickstandDown=false too, or the stand
    -- stays retracted while DropBehavior stands the bike up.
    if BicycleUtils.hasSidecar(currentBikeItem) then
        self.dismountData = self.dismountData or {}
        self.dismountData.kickstandDown = true
        self.dismountData.shiftHeld = false
    end

    -- Build flatWheels from local weapon parts (singleplayer) or modData (server fallback)
    if currentBikeItem.getWeaponPart then
        local wheelSlots = {"FrontWheel", "RearWheel"}
        for i = 1, #wheelSlots do
            local partType = wheelSlots[i]
            local wheelPart = currentBikeItem:getWeaponPart(partType)
            if wheelPart and wheelPart.getType then
                local typeName = wheelPart:getType()
                if string.find(typeName, "Flat", 1, true) then
                    if not self.dismountData.flatWheels then
                        self.dismountData.flatWheels = {}
                    end
                    self.dismountData.flatWheels[partType] = {
                        fullType = wheelPart:getFullType(),
                        condition = wheelPart.getCondition and wheelPart:getCondition() or nil,
                        usedDelta = wheelPart.getUsedDelta and wheelPart:getUsedDelta() or nil,
                        wearElapsed = wheelPart.getModData and wheelPart:getModData().bicycleWearElapsed or nil,
                    }
                end
            end
        end
    end

    clearBikeFromHandsById(self.character, currentBikeItem)
    if isServer() and sendEquip then
        sendEquip(self.character)
    end

    if self.dismountData and self.dismountData.dismountAnim == "throwBicycle" then
        self.dismountData.direction = self.character:getDir()
        self.dismountData.zRotation = BicycleUtils.directionToZRotation(self.character:getDir())
    end

    BicycleMigration.normalizeKickstandState(currentBikeItem, self.character)
    if self.dismountData and self.dismountData.kickstandDown ~= nil then
        local targetState = self.dismountData.kickstandDown and "down" or "up"
        BicycleKickstand.ensureState(currentBikeItem, self.character, targetState)
    end

    local inventory = self.character:getInventory()
    if inventory and currentBikeItem.getID then
        local inventoryDuplicate = inventory:getItemWithID(currentBikeItem:getID())
        if inventoryDuplicate and inventoryDuplicate ~= currentBikeItem then
            BicycleUtils.removeItemFromContainer(inventoryDuplicate)
            if inventoryDuplicate.setContainer then
                inventoryDuplicate:setContainer(nil)
            end
        end
    end

    BicycleUtils.removeWorldItem(currentBikeItem)
    BicycleUtils.removeItemFromContainer(currentBikeItem)

    local square = self.character:getSquare()
    if square then
        local droppedBikeItem = BicycleUtils.addPersistentWorldItem(square, currentBikeItem, 0, 0, 0) or currentBikeItem

        local function applyDroppedBikeState()
            BicycleDropBehavior.applyDropState(droppedBikeItem, self.character, self.dismountData)
        end

        applyDroppedBikeState()
        BicycleUtils.runAfter(0.1, function()
            if droppedBikeItem and droppedBikeItem.getWorldItem and droppedBikeItem:getWorldItem() then
                applyDroppedBikeState()
            end
        end)
        local containerManager = getBicycleContainerManager()
        if containerManager then
            containerManager.syncBikeContainers(self.character, droppedBikeItem, square, nil)
        end
    end

    if self.onComplete and not isServer() and not isClient() then
        self.onComplete(self.character, currentBikeItem, self.dismountData)
    else
        BicycleMountDismountState.finishDismount(self.character)
    end

    if isClient() then
        if Bicycle and Bicycle.ClientSync and Bicycle.ClientSync.syncState then
            Bicycle.ClientSync.syncState(self.character, true)
        end
    end

    if self.character and self.character.setTimedActionToRetrigger then
        self.character:setTimedActionToRetrigger(nil)
    end

    return true
end

---@param self BicycleDismountAction
---@return number
function BicycleDismountAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    if self.dismountData and self.dismountData.dismountAnim == "kickstandDown" then
        return 90
    end

    return 50
end

---@param character IsoGameCharacter
---@param item InventoryItem
---@param dismountData table|nil
---@param onComplete fun(character: IsoGameCharacter, item: InventoryItem, dismountData: table)|nil
---@param stopOnWalk boolean|nil
---@param stopOnRun boolean|nil
---@return BicycleDismountAction
function BicycleDismountAction:new(character, item, dismountData, onComplete, stopOnWalk, stopOnRun)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.itemId = item and item.getID and item:getID() or nil
    o.dismountData = dismountData or {}
    o.dm_kickstandDown = boolToString(o.dismountData.kickstandDown)
    o.dm_shiftHeld = boolToString(o.dismountData.shiftHeld)
    o.dm_dismountAnim = o.dismountData.dismountAnim
    o.dm_zRotation = o.dismountData.zRotation
    -- Capture flat wheel state NOW (on client, where the swap happened)
    -- These dm_ fields travel with the action to the server
    if item and item.getWeaponPart then
        local wheelSlots = {"FrontWheel", "RearWheel"}
        for i = 1, #wheelSlots do
            local partType = wheelSlots[i]
            local wheelPart = item:getWeaponPart(partType)
            if wheelPart and wheelPart.getType then
                local typeName = wheelPart:getType()
                if string.find(typeName, "Flat", 1, true) then
                    o["dm_flat" .. partType] = wheelPart:getFullType()
                end
            end
        end
    end
    o.onComplete = onComplete
    o.stopOnWalk = stopOnWalk == true
    o.stopOnRun = stopOnRun == true
    o.stopOnAim = false
    -- Enforced here, not just at the call sites, so any future caller gets the standing animation.
    local actionAnim = o.dismountData.dismountAnim or "throwBicycle"
    if BicycleUtils.hasSidecar(item) then
        actionAnim = "kickstandDown"
        o.dismountData.dismountAnim = actionAnim
        o.dismountData.kickstandDown = true
        o.dismountData.shiftHeld = false
        o.dm_dismountAnim = actionAnim
        o.dm_kickstandDown = "true"
        o.dm_shiftHeld = "false"
    end
    o.actionAnim = actionAnim
    o.maxTime = o:getDuration()
    return o
end

_G[BicycleDismountAction.Type] = BicycleDismountAction

return BicycleDismountAction
