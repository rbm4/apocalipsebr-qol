require("TimedActions/ISBaseTimedAction")
require("Bicycle/BicycleCore")

local AttachmentActionUtils = require("Bicycle/AttachmentActionUtils")
local BicycleDebug = require("Bicycle/Debug")
local BicyclePartAttachmentService = require("Bicycle/PartAttachmentService")
local BicycleUtils = require("Bicycle/Utils")
local Core = Bicycle.Core

---@class BicycleAttachPartAction : ISBaseTimedAction, umbrella.NetworkedTimedAction
BicycleAttachPartAction = ISBaseTimedAction:derive("BicycleAttachPartAction")

---@param action BicycleAttachPartAction
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

---@param action BicycleAttachPartAction
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

---@param action BicycleAttachPartAction
---@return InventoryItem|nil
local function resolvePartItem(action)
    if not action.character then
        return nil
    end

    local inventory = action.character:getInventory()
    local part = action.part
    if part and part.getID then
        action.partId = part:getID()
        local inventoryPart = inventory:getItemWithID(action.partId)
        if inventoryPart then
            action.part = inventoryPart
            return inventoryPart
        end
    end

    if action.partId then
        local partId = tonumber(action.partId)
        if not partId then
            return nil
        end
        local inventoryPart = inventory:getItemWithID(partId)
        if inventoryPart then
            action.part = inventoryPart
            return inventoryPart
        end
    end

    return nil
end

---@param action BicycleAttachPartAction
---@return InventoryItem|nil
local function resolveDuctTapeItem(action)
    if not action.character then
        return nil
    end

    local inventory = action.character:getInventory()
    local ductTape = action.ductTape
    if ductTape and ductTape.getID then
        action.ductTapeId = ductTape:getID()
        local inventoryDuctTape = inventory:getItemWithID(action.ductTapeId)
        if inventoryDuctTape then
            action.ductTape = inventoryDuctTape
            return inventoryDuctTape
        end
    end

    if action.ductTapeId then
        local ductTapeId = tonumber(action.ductTapeId)
        if not ductTapeId then
            return nil
        end
        local inventoryDuctTape = inventory:getItemWithID(ductTapeId)
        if inventoryDuctTape then
            action.ductTape = inventoryDuctTape
            return inventoryDuctTape
        end
    end

    return nil
end

---@param action BicycleAttachPartAction
---@return string|nil
---@nodiscard
local function resolvePartType(action)
    return BicyclePartAttachmentService.resolveAttachPartType(
        action.weapon,
        action.part,
        action.bicyclePartType,
        action.sourceMode
    )
end

---@param action BicycleAttachPartAction
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

---@param action BicycleAttachPartAction
local function clearJobState(action)
    if action.character then
        action.character:setVariable("BicycleUpgrading", false)
    end
    if action.weapon then
        action.weapon:setJobDelta(0.0)
    end
    if action.part then
        action.part:setJobDelta(0.0)
    end
end

function BicycleAttachPartAction:waitToStart()
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
function BicycleAttachPartAction:isValid()
    self.weapon = resolveBikeItem(self)
    self.part = resolvePartItem(self)
    if self.sourceMode == BicyclePartAttachmentService.SourceModeTapedFlashlight then
        self.ductTape = resolveDuctTapeItem(self)
        if not self.partFullType then
            self.partFullType = BicyclePartAttachmentService.getTapedFlashlightPartFullType(self.part)
        end
    end
    self.bicyclePartType = resolvePartType(self)

    return BicyclePartAttachmentService.canAttachPart(
        self.character,
        self.weapon,
        self.part,
        self.bicyclePartType,
        self.sourceMode,
        self.ductTape,
        self.partFullType
    )
end

function BicycleAttachPartAction:start()
    if isClient() then
        self.weapon = resolveBikeItem(self)
        self.part = resolvePartItem(self)
        if self.sourceMode == BicyclePartAttachmentService.SourceModeTapedFlashlight then
            self.ductTape = resolveDuctTapeItem(self)
        end
    elseif isServer() then
        -- Server-side start is not used for this timed-action path.
    else
        -- Singleplayer path keeps the constructor item references.
    end

    if not (self.weapon and self.part) then
        return
    end

    faceBike(self)
    self:setActionAnim("Loot")
    self.weapon:setJobType(getText("ContextMenu_BicycleAttachPart"))
    self.weapon:setJobDelta(0.0)
    self.part:setJobType(getText("ContextMenu_BicycleAttachPart"))
    self.part:setJobDelta(0.0)
end

function BicycleAttachPartAction:serverStart()
    BicycleDebug.log(
        "BicycleAttachPartAction:serverStart bikeId=" .. tostring(self.weaponId)
            .. ", partId=" .. tostring(self.partId)
            .. ", partType=" .. tostring(self.bicyclePartType)
            .. ", sourceMode=" .. tostring(self.sourceMode)
    )
end

function BicycleAttachPartAction:update()
    faceBike(self)
    if self.weapon then
        self.weapon:setJobDelta(self:getJobDelta())
    end
    if self.part then
        self.part:setJobDelta(self:getJobDelta())
    end
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function BicycleAttachPartAction:stop()
    clearJobState(self)
    ISBaseTimedAction.stop(self)
end

function BicycleAttachPartAction:serverStop()
    BicycleDebug.log(
        "BicycleAttachPartAction:serverStop bikeId=" .. tostring(self.weaponId)
            .. ", partId=" .. tostring(self.partId)
            .. ", partType=" .. tostring(self.bicyclePartType)
    )
end

function BicycleAttachPartAction:perform()
    clearJobState(self)
    if isClient() then
        self.weapon = resolveBikeItem(self)
        self.part = resolvePartItem(self)
        if self.sourceMode == BicyclePartAttachmentService.SourceModeTapedFlashlight then
            self.ductTape = resolveDuctTapeItem(self)
        end
        self.bicyclePartType = resolvePartType(self)
        AttachmentActionUtils.clearItemFromHands(self.character, self.part)
        BicyclePartAttachmentService.applyClientAttachPreview(
            self.character,
            self.weapon,
            self.part,
            self.bicyclePartType,
            self.sourceMode,
            self.ductTape,
            self.partFullType
        )
    end
    ISBaseTimedAction.perform(self)
end

---@return boolean
function BicycleAttachPartAction:complete()
    if isClient() then
        return true
    end

    self.weapon = resolveBikeItem(self)
    self.part = resolvePartItem(self)
    if self.sourceMode == BicyclePartAttachmentService.SourceModeTapedFlashlight then
        self.ductTape = resolveDuctTapeItem(self)
        if not self.partFullType then
            self.partFullType = BicyclePartAttachmentService.getTapedFlashlightPartFullType(self.part)
        end
    end
    self.bicyclePartType = resolvePartType(self)

    return BicyclePartAttachmentService.executeAttach(
        self.character,
        self.weapon,
        self.part,
        self.bicyclePartType,
        self.sourceMode,
        self.ductTape,
        self.partFullType
    )
end

---@return number
function BicycleAttachPartAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 50
end

---@param character IsoGameCharacter
---@param weapon InventoryItem
---@param part InventoryItem
---@param bicyclePartType string|nil
---@param sourceMode string|nil
---@param ductTape InventoryItem|nil
---@param partFullType string|nil
---@param x number|nil
---@param y number|nil
---@param z number|nil
---@return BicycleAttachPartAction
---@nodiscard
function BicycleAttachPartAction:new(character, weapon, part, bicyclePartType, sourceMode, ductTape, partFullType, x, y, z)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon = weapon
    o.weaponId = nil
    if weapon and weapon.getID then
        o.weaponId = weapon:getID()
    end
    o.part = part
    o.partId = nil
    if part and part.getID then
        o.partId = part:getID()
    end
    o.bicyclePartType = bicyclePartType
    o.sourceMode = sourceMode
    if not o.sourceMode then
        o.sourceMode = BicyclePartAttachmentService.SourceModePart
    end
    o.ductTape = ductTape
    o.ductTapeId = nil
    if ductTape and ductTape.getID then
        o.ductTapeId = ductTape:getID()
    end
    o.partFullType = partFullType
    o.x = x
    o.y = y
    o.z = z
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = o:getDuration()
    return o
end

_G[BicycleAttachPartAction.Type] = BicycleAttachPartAction

return BicycleAttachPartAction
