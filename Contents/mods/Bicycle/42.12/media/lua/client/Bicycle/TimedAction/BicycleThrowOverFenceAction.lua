require "TimedActions/ISBaseTimedAction"
local BicycleUtils = require("Bicycle/Utils")

local BicycleThrowOverFenceAction = ISBaseTimedAction:derive("BicycleThrowOverFenceAction")

local directionVectors = {
    [IsoDirections.N] = { x = 0, y = -1 },
    [IsoDirections.S] = { x = 0, y = 1 },
    [IsoDirections.E] = { x = 1, y = 0 },
    [IsoDirections.W] = { x = -1, y = 0 },
    [IsoDirections.NE] = { x = 1, y = -1 },
    [IsoDirections.NW] = { x = -1, y = -1 },
    [IsoDirections.SE] = { x = 1, y = 1 },
    [IsoDirections.SW] = { x = -1, y = 1 },
}

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

local function getFenceDirection(character)
    local square = character and character:getSquare()
    if not square then
        return nil
    end

    if squareHasHoppable(square) then
        local props = square:getProperties()
        if props and props:Is(IsoFlagType.HoppableN) then
            return IsoDirections.N
        end
        if props and props:Is(IsoFlagType.HoppableW) then
            return IsoDirections.W
        end
    end

    local neighbors = {
        { dir = IsoDirections.N, square = square:getN() },
        { dir = IsoDirections.S, square = square:getS() },
        { dir = IsoDirections.E, square = square:getE() },
        { dir = IsoDirections.W, square = square:getW() },
    }

    for _, entry in ipairs(neighbors) do
        if squareHasHoppable(entry.square) then
            return entry.dir
        end
    end

    return nil
end

local function getTargetSquare(character, startDir)
    local startSq = character and character:getSquare()
    if not (startSq and character) then
        return nil
    end

    local delta = directionVectors[startDir or IsoDirections.S]
    if not delta then
        return startSq
    end

    local cell = character:getCell()
    local targetX = startSq:getX() + delta.x * 3
    local targetY = startSq:getY() + delta.y * 3

    return cell and cell:getGridSquare(targetX, targetY, startSq:getZ()) or startSq
end

local function ensureEquipped(character, bicycleItem)
    if not (character and bicycleItem) then
        return
    end

    if BicycleMenu and BicycleMenu.removeWorldItem then
        BicycleMenu.removeWorldItem(bicycleItem)
    end

    local container = bicycleItem.getContainer and bicycleItem:getContainer() or nil
    if container and container ~= character:getInventory() then
        if container.DoRemoveItem then
            container:DoRemoveItem(bicycleItem)
        elseif container.Remove then
            container:Remove(bicycleItem)
        end
    end

    if bicycleItem:getContainer() ~= character:getInventory() then
        character:getInventory():AddItem(bicycleItem)
    end

    character:setPrimaryHandItem(bicycleItem)
    character:setSecondaryHandItem(bicycleItem)
    character:setVariable("BicycleActive", "true")
    character:setIgnoreAutoVault(true)
end

function BicycleThrowOverFenceAction:isValid()
    return self.character and self.bicycleItem ~= nil
end

function BicycleThrowOverFenceAction:waitToStart()
    return false
end

function BicycleThrowOverFenceAction:start()
    self.character:setDir(self.startDir)
end

function BicycleThrowOverFenceAction:update()
    if self.character:getDir() == self.startDir then
        ensureEquipped(self.character, self.bicycleItem)
        self:setActionAnim("ThrowBicycleFence")
        self.character:setVariable("ThrowBicycleFence", true)
    end
    if self.character:setVariable("ThrowBicycleFence", true) and self.character:getVariableBoolean("ThrowBicycleFenceFinished") == true then
        self:forceComplete()
    end
end

function BicycleThrowOverFenceAction:stop()
    self.character:setVariable("ThrowBicycleFence", false)
    BicycleMenu.dropBicycleAtSquare(self.character, self.bicycleItem, self.character:getSquare(), self.dismountData)
    ISBaseTimedAction.stop(self)
end

function BicycleThrowOverFenceAction:perform()
    local dropSquare = self.targetSquare or self.character:getSquare()
    self.character:setVariable("ThrowBicycleFence", false)
    BicycleMenu.dropBicycleAtSquare(self.character, self.bicycleItem, dropSquare, self.dismountData)
    self.character:setVariable("ThrowBicycleFenceFinished", false)
    ISBaseTimedAction.perform(self)
end

function BicycleThrowOverFenceAction:new(character, bicycleItem, maxTime)
    local o = ISBaseTimedAction.new(self, character)
    o.bicycleItem = bicycleItem
    local fenceDir = getFenceDirection(character)
    o.startDir = fenceDir
    o.targetSquare = getTargetSquare(character, o.startDir)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = -1
    o.dismountData = {
        direction = o.startDir,
        zRotation = BicycleUtils.directionToZRotation(o.startDir),
        dismountAnim = "throwBicycle",
        kickstandDown = false,
        shiftHeld = true,
    }
    return o
end

return BicycleThrowOverFenceAction
