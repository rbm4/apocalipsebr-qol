require "TimedActions/ISBaseTimedAction"
local BicycleUtils = require("Bicycle/Utils")

local BicycleDismountAction = ISBaseTimedAction:derive("BicycleDismountAction")

function BicycleDismountAction:isValid()
    return self.character and BicycleUtils.isBicycleItem(self.item)
end

function BicycleDismountAction:waitToStart()
    return false
end

function BicycleDismountAction:start()
    if self.dismountData then
        self.character:setVariable("DismountKickstand", self.dismountData.kickstandDown == true)
        if self.dismountData.dismountAnim then
            self.character:setVariable("dismountAnim", self.dismountData.dismountAnim)
        end
    end
    self:setActionAnim(self.actionAnim)
    self.character:setVariable("Dismounting", true)
end

function BicycleDismountAction:stop()
    self.character:setVariable("Dismounting", false)
    self.character:setVariable("DismountKickstand", false)
    self.character:setVariable("dismountAnim", "")
    ISBaseTimedAction.stop(self)
end

function BicycleDismountAction:perform()
    local currentBikeItem = self.character:getPrimaryHandItem()
    if not BicycleUtils.isBicycleItem(currentBikeItem) then
        ISBaseTimedAction.stop(self)
        return
    end
    if self.dismountData and self.dismountData.dismountAnim == "throwBicycle" then
        self.dismountData.direction = self.character:getDir()
        self.dismountData.zRotation = BicycleUtils.directionToZRotation(self.character:getDir())
    end

    if BicycleMenu and BicycleMenu.removeWorldItem then
        BicycleMenu.removeWorldItem(self.item)
    end

    local container = self.item and self.item.getContainer and self.item:getContainer() or nil
    if container then
        if container.DoRemoveItem then
            container:DoRemoveItem(self.item)
        elseif container.Remove then
            container:Remove(self.item)
        end
    end

    local square = self.character and self.character.getSquare and self.character:getSquare() or nil
    if square then
        square:AddWorldInventoryItem(self.item, 0, 0, 0)
    end

    if self.onComplete then
        self.onComplete(self.character, self.item, self.dismountData)
    end

    self.character:setVariable("Dismounting", false)
    self.character:setVariable("DismountKickstand", false)
    self.character:setVariable("dismountAnim", "")

    ISBaseTimedAction.perform(self)
end

function BicycleDismountAction:new(character, bicycleItem, dismountData, onComplete, stopOnWalk, stopOnRun, maxTime)
    local o = ISBaseTimedAction.new(self, character)
    o.item = bicycleItem
    o.dismountData = dismountData or {}
    o.onComplete = onComplete
    o.stopOnWalk = stopOnWalk ~= false
    o.stopOnRun = stopOnRun ~= false
    o.maxTime = maxTime or 30
    local actionAnim = o.dismountData.dismountAnim or "throwBicycle"
    o.actionAnim = actionAnim
    return o
end

return BicycleDismountAction
