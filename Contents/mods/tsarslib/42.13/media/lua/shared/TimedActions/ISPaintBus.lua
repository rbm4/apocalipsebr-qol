--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************

require "TimedActions/ISBaseTimedAction"

ISPaintBus = ISBaseTimedAction:derive("ISPaintBus")

function ISPaintBus:isValid()
	return self.vehicle:isInArea(self.area, self.character)
end

function ISPaintBus:waitToStart()
	self.character:faceThisObject(self.vehicle)
	return self.character:shouldBeTurning()
end

function ISPaintBus:update()
	
end

function ISPaintBus:start()
	self:setActionAnim(CharacterActionAnims.Paint)
    self:setOverrideHandModels("PaintBrush", nil)
end

function ISPaintBus:stop()
	ISBaseTimedAction.stop(self)
end

function ISPaintBus:complete()
    self.vehicle:setSkinIndex(self.skinIndex)
    self.vehicle:transmitSkinIndex()
    return true
end

function ISPaintBus:perform()
    ISBaseTimedAction.perform(self)
end

function ISPaintBus:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 200
end

function ISPaintBus:new(character, vehicle, area, skinIndex)
    local o = ISBaseTimedAction.new(self, character)
	o.character = character
	o.vehicle = vehicle
	o.area = area
	o.skinIndex = skinIndex
	o.maxTime = o:getDuration()
    o.stopOnAim  = false;
	return o
end

