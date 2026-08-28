require("TimedActions/ISBaseTimedAction")
require("Bicycle/BicycleCore")

local BicycleUtils = require("Bicycle/Utils")
local Core = Bicycle.Core

---@class BicycleStowAnimalAction : ISBaseTimedAction
---@field character IsoGameCharacter
---@field bikeItem InventoryItem|nil
---@field bikeItemId number|nil
---@field sourceMode string
---@field animalItemId number|nil
---@field worldAnimal IsoAnimal|nil
---@field sound number|nil
---@field x number|nil
---@field y number|nil
---@field z number|nil
BicycleStowAnimalAction = ISBaseTimedAction:derive("BicycleStowAnimalAction")

---@param action BicycleStowAnimalAction
---@return IsoGridSquare|nil
---@nodiscard
local function getHintedSquare(action)
    if action.x == nil or action.y == nil or action.z == nil then
        return action.character:getSquare()
    end
    return getSquare(action.x, action.y, action.z)
end

---@param action BicycleStowAnimalAction
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

---@param action BicycleStowAnimalAction
local function faceBike(action)
    local bikeItem = resolveBikeItem(action)
    local worldItem = bikeItem and bikeItem:getWorldItem() or nil
    if worldItem then
        action.character:faceThisObject(worldItem)
    elseif action.sourceMode == "world" and action.worldAnimal then
        action.character:faceThisObject(action.worldAnimal)
    end
end

---@return boolean
function BicycleStowAnimalAction:waitToStart()
    faceBike(self)
    return self.character:shouldBeTurning()
end

---@return boolean
function BicycleStowAnimalAction:isValid()
    local bikeItem = resolveBikeItem(self)
    if not bikeItem then
        return false
    end
    if not bikeItem:getWeaponPart("Sidecar") then
        return false
    end
    if self.sourceMode == "held" then
        local animalItem = self.character:getInventory():getItemWithID(self.animalItemId)
        if not animalItem then
            return false
        end
        return true
    end
    if self.sourceMode == "world" then
        if not self.worldAnimal then
            return false
        end
        return self.worldAnimal:isExistInTheWorld()
    end
    return false
end

function BicycleStowAnimalAction:start()
    faceBike(self)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    if self.sourceMode == "world" and self.worldAnimal then
        self.sound = self.worldAnimal:playBreedSound("pick_up")
        self.worldAnimal:getBehavior():setBlockMovement(true)
    end
end

function BicycleStowAnimalAction:update()
    faceBike(self)
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function BicycleStowAnimalAction:stop()
    if self.sourceMode == "world" and self.worldAnimal then
        if self.sound then
            self.character:stopOrTriggerSound(self.sound)
        end
        self.worldAnimal:getBehavior():setBlockMovement(false)
    end
    ISBaseTimedAction.stop(self)
end

function BicycleStowAnimalAction:perform()
    if self.sourceMode == "world" and self.worldAnimal then
        if self.sound then
            self.character:stopOrTriggerSound(self.sound)
        end
        self.worldAnimal:getBehavior():setBlockMovement(false)
    end

    local bikeItem = resolveBikeItem(self)
    if bikeItem then
        local payload = {
            bikeItemId = self.bikeItemId,
            sourceMode = self.sourceMode,
            x = self.x,
            y = self.y,
            z = self.z,
        }

        if self.sourceMode == "held" then
            payload.animalItemId = self.animalItemId
        elseif self.sourceMode == "world" and self.worldAnimal then
            payload.worldAnimalId = self.worldAnimal:getOnlineID()
            payload.worldAnimalType = self.worldAnimal:getAnimalType()
            local animalSquare = self.worldAnimal:getSquare()
            if animalSquare then
                payload.worldAnimalX = animalSquare:getX()
                payload.worldAnimalY = animalSquare:getY()
                payload.worldAnimalZ = animalSquare:getZ()
            end
        end

        sendClientCommand(Core.SyncModule, "PlaceAnimalInSidecar", payload)
    end

    ISBaseTimedAction.perform(self)
end

---@return boolean
function BicycleStowAnimalAction:complete()
    return true
end

---@return number
function BicycleStowAnimalAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 50
end

---@param character IsoGameCharacter
---@param bikeItem InventoryItem
---@param animalItem InventoryItem
---@param bikeSquare IsoGridSquare|nil
---@return BicycleStowAnimalAction
---@nodiscard
function BicycleStowAnimalAction:newFromHeld(character, bikeItem, animalItem, bikeSquare)
    local o = ISBaseTimedAction.new(self, character)
    o.bikeItem = bikeItem
    o.bikeItemId = bikeItem:getID()
    o.sourceMode = "held"
    o.animalItemId = animalItem:getID()
    o.worldAnimal = nil
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

---@param character IsoGameCharacter
---@param bikeItem InventoryItem
---@param worldAnimal IsoAnimal
---@param bikeSquare IsoGridSquare|nil
---@return BicycleStowAnimalAction
---@nodiscard
function BicycleStowAnimalAction:newFromWorldAnimal(character, bikeItem, worldAnimal, bikeSquare)
    local o = ISBaseTimedAction.new(self, character)
    o.bikeItem = bikeItem
    o.bikeItemId = bikeItem:getID()
    o.sourceMode = "world"
    o.animalItemId = nil
    o.worldAnimal = worldAnimal
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

_G[BicycleStowAnimalAction.Type] = BicycleStowAnimalAction

return BicycleStowAnimalAction
