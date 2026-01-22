require "TimedActions/ISBaseTimedAction"

ISInstallTuningVehiclePart = ISBaseTimedAction:derive("ISInstallTuningVehiclePart")

function ISInstallTuningVehiclePart:isValid()
-- print("ISInstallTuningVehiclePart:isValid")
    if ISVehicleMechanics.cheat then return true; end
    self.character:getModData().tryInstallTuning2Model = self.modelName--TODO check if that must be adapted to B42.13
    return self.vehicle:canInstallPart(self.character, self.part)
end

function ISInstallTuningVehiclePart:waitToStart()
    if ISVehicleMechanics.cheat then return false; end
    self.character:faceThisObject(self.vehicle)
    return self.character:shouldBeTurning()
end

function ISInstallTuningVehiclePart:update()
    self.character:faceThisObject(self.vehicle)
    self.character:setMetabolicTarget(Metabolics.MediumWork);
    if not self.vehicle:getEmitter():isPlaying(self.sound) then
        self.vehicle:getEmitter():playSound(self.sound)
    end
end

function ISInstallTuningVehiclePart:start()
-- print("ISInstallTuningVehiclePart:start")
    if self.animation then
        self:setActionAnim(self.animation)
    elseif self.part:getWheelIndex() ~= -1 or self.part:getId():contains("Brake") then
        self:setActionAnim("VehicleWorkOnTire")
    else
        self:setActionAnim("VehicleWorkOnMid")
    end
    -- print(self.sound)
    self.vehicle:getEmitter():playSound(self.sound) -- getPlayer():getVehicle():getEmitter():playSound("BlowTorch")
--    self:setOverrideHandModels(nil, nil)
end

function ISInstallTuningVehiclePart:stop()
-- print("ISInstallTuningVehiclePart:stop")
    self.vehicle:getEmitter():stopSoundByName(self.sound)
    ISBaseTimedAction.stop(self)
end

local RandomSoundPerform = {
    "BuildMetalStructureSmall",
    "BuildMetalStructureMedium",
    "BuildMetalStructureSmallScrap",
    "BuildMetalStructureLargePoleFence",
    "BuildMetalStructureSmallPoleFence",
    "BuildMetalStructureLargeWiredFence",
    "BuildMetalStructureSmallWiredFence",
    "BuildMetalStructureWallFrame",
}

function ISInstallTuningVehiclePart:perform()
-- print("ISInstallTuningVehiclePart:perform")
    local pdata = getPlayerData(self.character:getPlayerNum());
    if pdata ~= nil then
        pdata.playerInventory:refreshBackpacks();
        pdata.lootInventory:refreshBackpacks();
    end
    
    self.vehicle:getEmitter():stopSoundByName(self.sound)
    self.character:playSound(RandomSoundPerform[ZombRand(#RandomSoundPerform) + 1])
    UIManager.getSpeedControls():SetCurrentGameSpeed(1);
    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

function ISInstallTuningVehiclePart:complete()
    -- сохраняем состояние первого предмета для передачи в состояние детали.
    local firstCondition = ATA.consumeItems(self.use, self.character)
    
    ATA2Commands.installTuning(self.vehicle, self.part, self.modelName, firstCondition)
    
    return true
end

function ISInstallTuningVehiclePart:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return (self.time - (self.character:getPerkLevel(Perks.Mechanics) * (self.time/15))) * 100;
end

function ISInstallTuningVehiclePart:new(character, part, modelName)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.vehicle = part:getVehicle()
    o.part = part
    o.modelName = modelName
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
    local ltable = modelStruct and modelStruct.install
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
    -- o.jobType = getText("Tooltip_Vehicle_Installing", item:getDisplayName());
    return o
end

