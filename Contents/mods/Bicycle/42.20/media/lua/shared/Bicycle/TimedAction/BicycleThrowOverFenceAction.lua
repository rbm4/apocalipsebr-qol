require("TimedActions/ISBaseTimedAction")
require("Bicycle/BicycleCore")

local BicycleActionUtils = require("Bicycle/ActionUtils")
local BicycleContainerManager = nil
local BicycleDropBehavior = require("Bicycle/DropBehavior")
local BicycleMountDismountState = require("Bicycle/MountDismountState")
local BicycleUtils = require("Bicycle/Utils")
local BicycleWorldUtils = require("Bicycle/WorldUtils")
if isClient() then
    BicycleContainerManager = nil
elseif isServer() then
    BicycleContainerManager = require("Bicycle/BicycleContainerManager")
else
    BicycleContainerManager = require("Bicycle/BicycleContainerManager")
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

---@param character IsoGameCharacter|IsoPlayer
---@param bicycleItem InventoryItem
---@param dismountData table|nil
local function runClientThrowCleanup(character, bicycleItem, dismountData)
    local BicycleMenu = require("Bicycle/BicycleMenu")
    BicycleMenu.onCompleteDrop(character, bicycleItem, dismountData)
end

---@class BicycleThrowOverFenceAction : ISBaseTimedAction
BicycleThrowOverFenceAction = ISBaseTimedAction:derive("BicycleThrowOverFenceAction")

---@param self BicycleThrowOverFenceAction
---@return boolean
function BicycleThrowOverFenceAction:isValid()
    -- Re-checked here because MP rebuilds this action server-side from serialized args, bypassing the menu.
    return self.character ~= nil
        and self.bicycleItem ~= nil
        and self.startDir ~= nil
        and self.targetSquare ~= nil
        and BicycleUtils.isBikeUnderPlayer(self.character, self.bicycleItem)
        and not BicycleUtils.hasSidecar(self.bicycleItem)
end

---@param self BicycleThrowOverFenceAction
---@return boolean
function BicycleThrowOverFenceAction:waitToStart()
    -- Turn and settle before the throw starts; turning mid-animation cuts it short and the finish event never fires.
    if self.startDir then
        self.character:setDir(self.startDir)
    end

    return self.character.isMoving and self.character:isMoving() or false
end

---@param self BicycleThrowOverFenceAction
function BicycleThrowOverFenceAction:start()
    if self.startDir then
        self.character:setDir(self.startDir)
    end
    self.character:setVariable("ThrowBicycleFence", true)
    self:setActionAnim("ThrowBicycleFence")
end

---@param self BicycleThrowOverFenceAction
function BicycleThrowOverFenceAction:update()
    if self.startDir and self.character:getDir() ~= self.startDir then
        self.character:setDir(self.startDir)
    end

    BicycleActionUtils.ensureEquipped(self.character, self.bicycleItem)

    if self.character:getVariableBoolean("ThrowBicycleFenceFinished") then
        self:forceComplete()
    end
end

---@param self BicycleThrowOverFenceAction
function BicycleThrowOverFenceAction:stop()
    self.character:setVariable("ThrowBicycleFence", false)
    -- In MP the client's copy is stopped, never performed, so clear the flag here or the guards see a stranded bike.
    self.character:setVariable("BicycleActive", "false")

    -- ensureEquipped lifts the bike off the ground on tick one; no container and no world item means an aborted
    -- throw left it in limbo, so hand it back rather than let it be destroyed.
    local item = self.bicycleItem
    if item then
        local hasWorldItem = item.getWorldItem and item:getWorldItem() ~= nil
        local hasContainer = item.getContainer and item:getContainer() ~= nil
        if not hasWorldItem and not hasContainer then
            local inventory = self.character and self.character:getInventory() or nil
            if inventory and inventory.AddItem then
                inventory:AddItem(item)
                if isServer() and sendEquip then
                    sendEquip(self.character)
                end
            end
        end
    end

    BicycleMountDismountState.finishDismount(self.character)
    ISBaseTimedAction.stop(self)
end

---@param self BicycleThrowOverFenceAction
function BicycleThrowOverFenceAction:perform()
    self.character:setVariable("ThrowBicycleFence", false)
    self.character:setVariable("ThrowBicycleFenceFinished", false)
    -- Clear on every exit path, not just the cleanup some paths reach.
    self.character:setVariable("BicycleActive", "false")
    if isClient() then
        if self.bicycleItem then
            -- No DropBike request from here: the server runs :complete() through NetTimedAction and places
            -- the bike itself, so sending one would place it twice.
            runClientThrowCleanup(self.character, self.bicycleItem, self.dismountData)
        else
            BicycleMountDismountState.finishDismount(self.character)
        end
    end
    ISBaseTimedAction.perform(self)
end

---@param self BicycleThrowOverFenceAction
---@return boolean
function BicycleThrowOverFenceAction:complete()
    local dropSquare = self.targetSquare or self.character:getSquare()
    if not dropSquare then
        return false
    end

    if not self.bicycleItem then
        return false
    end

    if not self.dismountData or self.dismountData.kickstandDown == nil then
        local kickstandDown = parseBool(self.dm_kickstandDown)
        local shiftHeld = parseBool(self.dm_shiftHeld)

        if kickstandDown == nil and shiftHeld == nil then
            kickstandDown = false
            shiftHeld = true
        end

        self.dismountData = {
            kickstandDown = kickstandDown,
            shiftHeld = shiftHeld,
            dismountAnim = self.dm_dismountAnim or "throwBicycle",
            zRotation = self.dm_zRotation,
            direction = self.character:getDir(),
        }
    end

    -- removeItemFromContainer does not clear hand slots; leave it equipped and the bike syncs back as a duplicate.
    local character = self.character
    if character and character.getPrimaryHandItem then
        if character:getPrimaryHandItem() == self.bicycleItem
            or character:getSecondaryHandItem() == self.bicycleItem then
            character:removeFromHands(self.bicycleItem)
            if isServer() and sendEquip then
                sendEquip(character)
            end
        end
    end

    -- A client-side placement is a phantom that vanishes on the next sync; the server owns world items.
    if isClient() then
        return true
    end

    BicycleUtils.removeWorldItem(self.bicycleItem)
    BicycleUtils.removeItemFromContainer(self.bicycleItem)

    -- addPersistentWorldItem returns the item even when the placement was refused; only a world item proves it landed.
    local placed = BicycleUtils.addPersistentWorldItem(dropSquare, self.bicycleItem, 0, 0, 0)
    local placedWorldItem = placed and placed.getWorldItem and placed:getWorldItem() or nil
    if not placedWorldItem then
        local inventory = self.character and self.character:getInventory()
        if inventory and inventory.AddItem then
            inventory:AddItem(self.bicycleItem)
        end
        BicycleMountDismountState.finishDismount(self.character)
        return false
    end

    local droppedBikeItem = placed
    BicycleDropBehavior.applyDropState(droppedBikeItem, self.character, self.dismountData)
    local containerManager = getBicycleContainerManager()
    if containerManager then
        containerManager.syncBikeContainers(self.character, droppedBikeItem, dropSquare, nil)
    end
    if isServer() then
        BicycleMountDismountState.finishDismount(self.character)
    elseif isClient() then
        BicycleMountDismountState.finishDismount(self.character)
    else
        runClientThrowCleanup(self.character, droppedBikeItem, self.dismountData)
    end

    return true
end

---@param self BicycleThrowOverFenceAction
---@return number
function BicycleThrowOverFenceAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    -- -1 means run until the animation says stop, but the dedicated server has no animation and reads this
    -- as an endTime in the past. Give it a real one; the client still finishes on the anim event.
    if isServer() then
        return 120
    end

    return -1
end

---@param character IsoGameCharacter
---@param bicycleItem InventoryItem
---@param fenceDirName string|nil
---@return BicycleThrowOverFenceAction
function BicycleThrowOverFenceAction:new(character, bicycleItem, fenceDirName)
    local o = ISBaseTimedAction.new(self, character)
    o.bicycleItem = bicycleItem
    o.stopOnWalk = true
    o.stopOnRun = true

    -- Passed in rather than discovered, because NetTimedAction re-runs this constructor server-side and
    -- re-discovery there can pick a different neighbour than the client animated against.
    local fenceDir = BicycleWorldUtils.directionFromName(fenceDirName)
        or BicycleWorldUtils.findHoppableDirection(character)
    o.startDir = fenceDir
    o.fenceDirName = BicycleWorldUtils.directionToName(fenceDir)
    o.targetSquare = fenceDir and BicycleWorldUtils.findThrowLandingSquare(character, fenceDir) or nil
    o.dismountData = {
        direction = o.startDir,
        zRotation = BicycleUtils.directionToZRotation(o.startDir),
        dismountAnim = "throwBicycle",
        kickstandDown = false,
        shiftHeld = true
    }
    o.dm_kickstandDown = boolToString(o.dismountData.kickstandDown)
    o.dm_shiftHeld = boolToString(o.dismountData.shiftHeld)
    o.dm_dismountAnim = o.dismountData.dismountAnim
    o.dm_zRotation = o.dismountData.zRotation

    o.maxTime = o:getDuration()

    return o
end

_G[BicycleThrowOverFenceAction.Type] = BicycleThrowOverFenceAction

return BicycleThrowOverFenceAction
