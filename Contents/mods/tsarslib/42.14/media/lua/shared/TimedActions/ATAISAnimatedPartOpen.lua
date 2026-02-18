--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************

require "TimedActions/ISBaseTimedAction"

ATAISAnimatedPartOpen = ISBaseTimedAction:derive("ATAISAnimatedPartOpen")

function ATAISAnimatedPartOpen:isValid()
	return self.part and self.part:getDoor() and not self.part:getDoor():isOpen()
end

function ATAISAnimatedPartOpen:update()
	if self.character:getSpriteDef():isFinished() then
--	if self.door:isAnimationFinished() then
		self:forceComplete()
	end
end

function ATAISAnimatedPartOpen:start()
	-- TODO: sync part animation + sound
	self.vehicle:playPartAnim(self.part, "Open")
	self.vehicle:playPartSound(self.part, self.character, "Open")
	-- Set this here to negate the effects of injuries, negative moodles, etc.
	self.action:setTime(5)
end

function ATAISAnimatedPartOpen:stop()
	-- TODO: interrupted, close door again?
	ISBaseTimedAction.stop(self)
end

function ATAISAnimatedPartOpen:perform()
	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

function ATAISAnimatedPartOpen:complete()
    local door = self.part:getDoor()
    if door then
        door:setOpen(true)
        self.vehicle:transmitPartDoor(self.part)
        return true
    end
    return false
end

function ATAISAnimatedPartOpen:getDuration()
    return -1
end

function ATAISAnimatedPartOpen:new(character, vehicle, part)
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

