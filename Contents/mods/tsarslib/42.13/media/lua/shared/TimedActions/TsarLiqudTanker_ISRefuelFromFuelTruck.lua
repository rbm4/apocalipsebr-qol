--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************

require "TimedActions/ISBaseTimedAction"

ISRefuelFromLiqudTanker = ISBaseTimedAction:derive("ISRefuelFromLiqudTanker")

function ISRefuelFromLiqudTanker:isValid()
    return self.vehicle:isInArea(self.part:getArea(), self.character)
end

function ISRefuelFromLiqudTanker:waitToStart()
    self.character:faceThisObject(self.vehicle)
    return self.character:shouldBeTurning()
end

function ISRefuelFromLiqudTanker:update()
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic);
end

function ISRefuelFromLiqudTanker:start()
    self:setActionAnim("fill_container_tap")
    self:setOverrideHandModels(nil, nil)
    
    self.character:reportEvent("EventTakeWater");
    self.sound = self.character:playSound("VehicleAddFuelFromGasPump")
end

function ISRefuelFromLiqudTanker:stop()
    self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.stop(self)
end

function ISRefuelFromLiqudTanker:serverStop()
    local pumpUnits = self.pumpStart + (self.pumpTarget - self.pumpStart) * self.netAction:getProgress()
    pumpUnits = math.ceil(pumpUnits)
    self.tank:setContainerContentAmount(pumpUnits)
    self.tank:getVehicle():transmitPartModData(self.tank)
    
    local litres = self.tankStart + (self.tankTarget - self.tankStart) * self.netAction:getProgress()
    self.part:setContainerContentAmount(math.floor(litres))
    self.vehicle:transmitPartModData(self.part)
end

function ISRefuelFromLiqudTanker:perform()
    self.character:stopOrTriggerSound(self.sound)
    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

function ISRefuelFromLiqudTanker:complete()
    self.tank:setContainerContentAmount(math.ceil(self.pumpTarget))
    self.tank:getVehicle():transmitPartModData(self.tank)

    self.part:setContainerContentAmount(math.floor(self.tankTarget))
    self.vehicle:transmitPartModData(self.part)

    return true
end

function ISRefuelFromLiqudTanker:getDuration()
    self.tankStart = self.part:getContainerContentAmount()
    -- Pumps start with 100 units of fuel.  8 pump units = 1 PetrolCan according to ISTakeFuel.
    self.pumpStart = self.tank:getContainerContentAmount();
    local pumpLitresAvail = self.pumpStart --* (Vehicles.JerryCanLitres / 8)
    local tankLitresFree = self.part:getContainerCapacity() - self.tankStart
    local takeLitres = math.min(tankLitresFree, pumpLitresAvail)
    self.tankTarget = self.tankStart + takeLitres
    self.pumpTarget = self.pumpStart - takeLitres --/ (Vehicles.JerryCanLitres / 8)
    self.amountSent = self.tankStart

    return takeLitres * 50
end

function ISRefuelFromLiqudTanker:new(character, part, square, time_OBSOLETE, tank)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.part = part
    o.square = square
    o.time_OBSOLETE = time_OBSOLETE--todo remove
    o.tank = tank
    o.vehicle = part:getVehicle()
    o.maxTime = o:getDuration()
    o.stopOnAim  = false;
    return o
end

