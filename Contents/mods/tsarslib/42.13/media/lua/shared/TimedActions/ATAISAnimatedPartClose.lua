--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************

require "TimedActions/ISBaseTimedAction"

ATAISAnimatedPartClose = ISBaseTimedAction:derive("ATAISAnimatedPartClose")

function ATAISAnimatedPartClose:isValid()
	return self.part and self.part:getDoor() and self.part:getDoor():isOpen()
end

function ATAISAnimatedPartClose:update()
	if self.character:getSpriteDef():isFinished() then
		self:forceComplete()
	end
end

function ATAISAnimatedPartClose:start()
	-- TODO: sync part animation + sound
	self.vehicle:playPartAnim(self.part, "Close")
	self.vehicle:playPartSound(self.part, self.character, "Close")
	-- Set this here to negate the effects of injuries, negative moodles, etc.
	self.action:setTime(4)
end

function ATAISAnimatedPartClose:stop()
	-- TODO: interrupted, close door again?
	ISBaseTimedAction.stop(self)
end

function ATAISAnimatedPartClose:perform()
	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

function ATAISAnimatedPartClose:complete()
    local door = self.part:getDoor()
    if door then
        door:setOpen(false)
        self.vehicle:transmitPartDoor(self.part)
        return true
    end
    return false
end

function ATAISAnimatedPartClose:getDuration()
    return -1
end

function ATAISAnimatedPartClose:new(character, vehicle, part)
    local o = ISBaseTimedAction.new(self, character)
	o.character = character
	o.vehicle = vehicle
	o.part = part
	o.maxTime = o:getDuration()
    o.stopOnWalk = false;
    o.stopOnRun  = false;
    o.stopOnAim  = false;
	return o
end

