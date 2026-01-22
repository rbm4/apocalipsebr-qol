--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************

require "TimedActions/ISBaseTimedAction"

ISOpenTuningUIAction = ISBaseTimedAction:derive("ISOpenTuningUIAction")

function ISOpenTuningUIAction:isValid()
	return true;
end

function ISOpenTuningUIAction:waitToStart()
	if self.character:getVehicle() then return false end
	self.character:faceThisObject(self.vehicle)
	return self.character:shouldBeTurning()
end

function ISOpenTuningUIAction:update()
	self.character:faceThisObject(self.vehicle)
end

function ISOpenTuningUIAction:start()
	self:setActionAnim("ExamineVehicle");
	self:setOverrideHandModels(nil, nil)
end

function ISOpenTuningUIAction:stop()
	ISBaseTimedAction.stop(self)
end

function ISOpenTuningUIAction:perform()
	local ui = getPlayerTuningUI(self.character:getPlayerNum());
	ui.vehicle = self.vehicle;
	ui:setVisible(true, JoypadState.players[self.character:getPlayerNum()+1])
	ui:addToUIManager()
	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

function ISOpenTuningUIAction:complete()
    return true
end

function ISOpenTuningUIAction:getDuration()
    if self.character:isTimedActionInstant() or (self.vehicle:getScript() and self.vehicle:getScript():getWheelCount() == 0) then
        return 1
    end
    return 75 - (self.character:getPerkLevel(Perks.Mechanics) * (75/15));
end

function ISOpenTuningUIAction:new(character, vehicle, usedHood)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.vehicle = vehicle
    o.usedHood = usedHood
    o.stopOnWalk = false;
    o.stopOnRun  = false;
    o.stopOnAim  = false;
    o.maxTime = o:getDuration()
    return o
end

