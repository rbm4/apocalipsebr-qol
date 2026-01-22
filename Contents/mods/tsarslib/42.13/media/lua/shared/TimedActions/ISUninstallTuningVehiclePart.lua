require "TimedActions/ISBaseTimedAction"

ISUninstallTuningVehiclePart = ISBaseTimedAction:derive("ISUninstallTuningVehiclePart")

function ISUninstallTuningVehiclePart:isValid()
	if ISVehicleMechanics.cheat then return true; end
	return self.part:getInventoryItem() and self.vehicle:canUninstallPart(self.character, self.part)
end

function ISUninstallTuningVehiclePart:waitToStart()
	if ISVehicleMechanics.cheat then return false; end
	self.character:faceThisObject(self.vehicle)
	return self.character:shouldBeTurning()
end

function ISUninstallTuningVehiclePart:update()
	self.character:faceThisObject(self.vehicle)
    self.character:setMetabolicTarget(Metabolics.MediumWork);
    if not self.vehicle:getEmitter():isPlaying(self.sound) then
        self.vehicle:getEmitter():playSound(self.sound)
    end
end

function ISUninstallTuningVehiclePart:start()
	if self.animation then
        self:setActionAnim(self.animation)
    elseif self.part:getWheelIndex() ~= -1 or self.part:getId():contains("Brake") then
		self:setActionAnim("VehicleWorkOnTire")
	else
		self:setActionAnim("VehicleWorkOnMid")
	end
    self.vehicle:getEmitter():playSound(self.sound)
--	self:setOverrideHandModels(nil, nil)
end

function ISUninstallTuningVehiclePart:stop()
    self.vehicle:getEmitter():stopSoundByName(self.sound)
    ISBaseTimedAction.stop(self)
end

local RandomSoundPerform = {
    "PrisonMetalDoorBlocked",
    "MetalDoorBlocked",
    "MetalGateBlocked",
    "AddBarricadeMetal",
}

function ISUninstallTuningVehiclePart:perform()
    self.vehicle:getEmitter():stopSoundByName(self.sound)
    self.character:playSound(RandomSoundPerform[ZombRand(#RandomSoundPerform) + 1])
    UIManager.getSpeedControls():SetCurrentGameSpeed(1);
	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

function ISUninstallTuningVehiclePart:complete()
    ATA.consumeItems(self.use, self.character)
    
    ATA2Commands.uninstallTuning(self.vehicle, self.part, self.modelName, self.character)
    
    return true
end

function ISUninstallTuningVehiclePart:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return (self.time - (self.character:getPerkLevel(Perks.Mechanics) * (self.time/15))) * 100;
end

function ISUninstallTuningVehiclePart:new(character, part, modelName)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.vehicle = part:getVehicle()
    o.part = part
    o.modelName = modelName
    o.jobType = getText("Tooltip_Vehicle_Uninstalling", part:getInventoryItem():getDisplayName());
    o.stopOnWalk = true
    o.stopOnRun  = true
    o.stopOnAim  = false;
    o.time = 50
    
    -- заполнение переменных из таблицы тюнинга
    local vehicleName = o.vehicle:getScript():getName()
    local partName = part:getId()
    local vehicleTable = ATA2TuningTable[vehicleName]
    local part = vehicleTable and vehicleTable.parts[partName]
    local modelStruct = part and part[modelName]
    local ltable = modelStruct and modelStruct.uninstall
    if ltable then
        if ltable.sound and GameSounds.isKnownSound(ltable.sound) then
            o.sound = ltable.sound
        else
            o.sound = "ATA2InstallGeneral"
        end
        if ltable.use then
            o.use = ltable.use
        end
        if ltable.animation then
            o.animation = ltable.animation
        end
        if ltable.time then
            o.time = ltable.time
        end
    end
    
    o.maxTime = o:getDuration()
    
    return o
end

