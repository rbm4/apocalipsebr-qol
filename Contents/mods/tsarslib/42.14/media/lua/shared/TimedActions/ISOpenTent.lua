--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************

require "TimedActions/ISBaseTimedAction"

ISOpenTent = ISBaseTimedAction:derive("ISOpenTent")

function ISOpenTent:isValid()
-- print("ISOpenTent:isValid()")
	if self.part:getInventoryItem() and (self.open or (ATATuning.UninstallTest.RoofClose(self.vehicle, self.vehicle:getPartById("SeatMiddleLeft"), self.character) and ATATuning.UninstallTest.RoofClose(self.vehicle, self.vehicle:getPartById("SeatMiddleRight"), self.character))) then
		return true
	else
		return false
	end	

end

function ISOpenTent:waitToStart()
-- print("ISOpenTent:waitToStart()")
	self.character:faceThisObject(self.vehicle)
	return self.character:shouldBeTurning()
end

function ISOpenTent:update()
-- print("ISOpenTent:update()")
	self.character:faceThisObject(self.vehicle)
    self.character:setMetabolicTarget(Metabolics.MediumWork);
end

function ISOpenTent:start()
-- print("ISOpenTent:start()")
	self:setActionAnim("VehicleWorkOnMid")
--	self:setOverrideHandModels(nil, nil)
end

function ISOpenTent:stop()
    ISBaseTimedAction.stop(self)
end

function ISOpenTent:perform()
    ISBaseTimedAction.perform(self)
end

function ISOpenTent:complete()
    sendClientCommand(self.character, 'atatuning2', 'usePart', {vehicle = self.vehicle:getId(), partName = self.part:getId(),})
    return true
end

function ISOpenTent:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return (self.time - (self.character:getPerkLevel(Perks.Mechanics) * (self.time/15))) * 100;
end

function ISOpenTent:new(character, vehicle, part, open)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.vehicle = vehicle
    o.part = part
    o.open = open
    o.time = 50
    o.maxTime = o:getDuration()
    return o
end

