require("TimedActions/ISBaseTimedAction")
require("Bicycle/BicycleCore")

local BicycleUtils = require("Bicycle/Utils")
local Core = Bicycle.Core

---@class BicycleReleaseAnimalAction : ISBaseTimedAction
---@field character IsoGameCharacter
---@field bikeItem InventoryItem|nil
---@field bikeItemId number|nil
---@field x number|nil
---@field y number|nil
---@field z number|nil
BicycleReleaseAnimalAction = ISBaseTimedAction:derive("BicycleReleaseAnimalAction")

---@param action BicycleReleaseAnimalAction
---@return IsoGridSquare|nil
---@nodiscard
local function getHintedSquare(action)
    if action.x == nil or action.y == nil or action.z == nil then
        return action.character:getSquare()
    end
    return getSquare(action.x, action.y, action.z)
end

---@param action BicycleReleaseAnimalAction
---@return InventoryItem|nil
local function resolveBikeItem(action)
    if BicycleUtils.isBicycleItem(action.bikeItem) then
        return action.bikeItem
    end
    if not action.bikeItemId then
        return nil
    end
    local found = Core.findItemById(action.character, action.bikeItemId, getHintedSquare(action))
    if BicycleUtils.isBicycleItem(found) then
        action.bikeItem = found
        return found
    end
    return nil
end

---@param action BicycleReleaseAnimalAction
local function faceBike(action)
    local bikeItem = resolveBikeItem(action)
    local worldItem = bikeItem and bikeItem:getWorldItem() or nil
    if worldItem then
        action.character:faceThisObject(worldItem)
    end
end

---@return boolean
function BicycleReleaseAnimalAction:waitToStart()
    faceBike(self)
    return self.character:shouldBeTurning()
end

---@return boolean
function BicycleReleaseAnimalAction:isValid()
    local bikeItem = resolveBikeItem(self)
    if not bikeItem then
        return false
    end
    return bikeItem:getWeaponPart("Sidecar") ~= nil
end

function BicycleReleaseAnimalAction:start()
    faceBike(self)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
end

function BicycleReleaseAnimalAction:update()
    faceBike(self)
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function BicycleReleaseAnimalAction:stop()
    ISBaseTimedAction.stop(self)
end

function BicycleReleaseAnimalAction:perform()
    local bikeItem = resolveBikeItem(self)
    if bikeItem then
        sendClientCommand(Core.SyncModule, "ReleaseAnimalFromSidecar", {
            bikeItemId = self.bikeItemId,
            x = self.x,
            y = self.y,
            z = self.z,
        })
    end

    ISBaseTimedAction.perform(self)
end

---@return boolean
function BicycleReleaseAnimalAction:complete()
    return true
end

---@return number
function BicycleReleaseAnimalAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 50
end

---@param character IsoGameCharacter
---@param bikeItem InventoryItem
---@param bikeSquare IsoGridSquare|nil
---@return BicycleReleaseAnimalAction
---@nodiscard
function BicycleReleaseAnimalAction:new(character, bikeItem, bikeSquare)
    local o = ISBaseTimedAction.new(self, character)
    o.bikeItem = bikeItem
    o.bikeItemId = bikeItem:getID()
    if bikeSquare then
        o.x = bikeSquare:getX()
        o.y = bikeSquare:getY()
        o.z = bikeSquare:getZ()
    end
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = o:getDuration()
    return o
end

_G[BicycleReleaseAnimalAction.Type] = BicycleReleaseAnimalAction

return BicycleReleaseAnimalAction
