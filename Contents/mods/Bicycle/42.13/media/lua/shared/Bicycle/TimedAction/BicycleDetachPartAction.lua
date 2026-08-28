require("TimedActions/ISBaseTimedAction")
require("Bicycle/BicycleCore")

local AttachmentActionUtils = require("Bicycle/AttachmentActionUtils")
local BicycleDebug = require("Bicycle/Debug")
local BicyclePartAttachmentService = require("Bicycle/PartAttachmentService")
local BicycleUtils = require("Bicycle/Utils")
local Core = Bicycle.Core

---@class BicycleDetachPartAction : ISBaseTimedAction, umbrella.NetworkedTimedAction
BicycleDetachPartAction = ISBaseTimedAction:derive("BicycleDetachPartAction")

---@param action BicycleDetachPartAction
---@return IsoGridSquare|nil
---@nodiscard
local function getHintedSquare(action)
    if not action then
        return nil
    end
    if action.x == nil or action.y == nil or action.z == nil then
        if action.character then
            return action.character:getSquare()
        end
        return nil
    end
    return getSquare(action.x, action.y, action.z)
end

---@param action BicycleDetachPartAction
---@return InventoryItem|nil
local function resolveBikeItem(action)
    if not action.character then
        return nil
    end

    local bikeItem = action.weapon and action.weapon.getItem and action.weapon:getItem() or action.weapon
    if BicycleUtils.isBicycleItem(bikeItem) then
        if bikeItem.getID then
            action.weaponId = bikeItem:getID()
            local inventoryItem = action.character:getInventory():getItemWithID(action.weaponId)
            if BicycleUtils.isBicycleItem(inventoryItem) then
                action.weapon = inventoryItem
                return inventoryItem
            end

            local worldItem = Core.findItemById(action.character, action.weaponId, getHintedSquare(action))
            if BicycleUtils.isBicycleItem(worldItem) then
                action.weapon = worldItem
                return worldItem
            end
        end
        return bikeItem
    end

    if action.weaponId then
        local bikeId = tonumber(action.weaponId)
        if not bikeId then
            return nil
        end
        local inventoryItem = action.character:getInventory():getItemWithID(bikeId)
        if BicycleUtils.isBicycleItem(inventoryItem) then
            action.weapon = inventoryItem
            return inventoryItem
        end

        local worldItem = Core.findItemById(action.character, bikeId, getHintedSquare(action))
        if BicycleUtils.isBicycleItem(worldItem) then
            action.weapon = worldItem
            return worldItem
        end
    end

    return nil
end

---@param action BicycleDetachPartAction
local function faceBike(action)
    local bikeItem = resolveBikeItem(action)
    local worldItem = nil
    if bikeItem and bikeItem.getWorldItem then
        worldItem = bikeItem:getWorldItem()
    end
    if worldItem then
        action.character:faceThisObject(worldItem)
    end
end

---@param action BicycleDetachPartAction
local function clearJobState(action)
    if action.character then
        action.character:setVariable("BicycleUpgrading", false)
    end
    if action.weapon then
        action.weapon:setJobDelta(0.0)
    end
end

function BicycleDetachPartAction:waitToStart()
    local bikeItem = resolveBikeItem(self)
    local worldItem = nil
    if bikeItem and bikeItem.getWorldItem then
        worldItem = bikeItem:getWorldItem()
    end
    if worldItem then
        self.character:faceThisObject(worldItem)
        return self.character:shouldBeTurning()
    end
    return false
end

---@return boolean
function BicycleDetachPartAction:isValid()
    self.weapon = resolveBikeItem(self)
    if isClient() then
        if not (self.character and self.weapon and self.bicyclePartType) then
            return false
        end
        if not BicyclePartAttachmentService.canAccessBike(self.character, self.weapon) then
            return false
        end
        return self.weapon:getWeaponPart(self.bicyclePartType) ~= nil
    elseif isServer() then
        return BicyclePartAttachmentService.canDetachPart(self.character, self.weapon, self.bicyclePartType)
    else
        return BicyclePartAttachmentService.canDetachPart(self.character, self.weapon, self.bicyclePartType)
    end
end

function BicycleDetachPartAction:start()
    if isClient() then
        self.weapon = resolveBikeItem(self)
    elseif isServer() then
        -- Server-side start is not used for this timed-action path.
    else
        -- Singleplayer path keeps the constructor item reference.
    end

    if not self.weapon then
        return
    end

    faceBike(self)
    self:setActionAnim("Loot")
    self.weapon:setJobType(getText("ContextMenu_BicycleRemovePart"))
    self.weapon:setJobDelta(0.0)
end

function BicycleDetachPartAction:serverStart()
    BicycleDebug.log(
        "BicycleDetachPartAction:serverStart bikeId=" .. tostring(self.weaponId)
            .. ", partType=" .. tostring(self.bicyclePartType)
    )
end

function BicycleDetachPartAction:update()
    faceBike(self)
    if self.weapon then
        self.weapon:setJobDelta(self:getJobDelta())
    end
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function BicycleDetachPartAction:stop()
    clearJobState(self)
    ISBaseTimedAction.stop(self)
end

function BicycleDetachPartAction:serverStop()
    BicycleDebug.log(
        "BicycleDetachPartAction:serverStop bikeId=" .. tostring(self.weaponId)
            .. ", partType=" .. tostring(self.bicyclePartType)
    )
end

function BicycleDetachPartAction:perform()
    clearJobState(self)
    if isClient() then
        self.weapon = resolveBikeItem(self)
        BicyclePartAttachmentService.applyClientDetachPreview(self.character, self.weapon, self.bicyclePartType)
    end
    ISBaseTimedAction.perform(self)
end

---@return boolean
function BicycleDetachPartAction:complete()
    if isClient() then
        return true
    end

    self.weapon = resolveBikeItem(self)
    return BicyclePartAttachmentService.executeDetach(self.character, self.weapon, self.bicyclePartType)
end

---@return number
function BicycleDetachPartAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 50
end

---@param character IsoGameCharacter
---@param weapon InventoryItem
---@param bicyclePartType string
---@param x number|nil
---@param y number|nil
---@param z number|nil
---@return BicycleDetachPartAction
---@nodiscard
function BicycleDetachPartAction:new(character, weapon, bicyclePartType, x, y, z)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon = weapon
    o.weaponId = nil
    if weapon and weapon.getID then
        o.weaponId = weapon:getID()
    end
    o.bicyclePartType = bicyclePartType
    o.x = x
    o.y = y
    o.z = z
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = o:getDuration()
    return o
end

_G[BicycleDetachPartAction.Type] = BicycleDetachPartAction

return BicycleDetachPartAction
