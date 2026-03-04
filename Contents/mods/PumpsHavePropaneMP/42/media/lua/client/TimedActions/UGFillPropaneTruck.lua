require "TimedActions/ISBaseTimedAction"

UGFillPropaneTruck = ISBaseTimedAction:derive("ISRefuelFromGasPump")

function UGFillPropaneTruck:isValid()

	return true;
end

function UGFillPropaneTruck:waitToStart()

	self.character:faceThisObject(self.vehicle)

	return self.character:shouldBeTurning()
end

function UGFillPropaneTruck:update()

	local litres = self.tankStart + self.takeLitres * self:getJobDelta()
	litres = math.ceil(litres)
	if self.part:getContainerContentAmount() ~= self.tankTarget then

		local args = { vehicle = self.vehicle:getId(), part = self.part:getId(), amount = litres }
		sendClientCommand(self.character, 'vehicle', 'setContainerContentAmount', args)
	end
end

function UGFillPropaneTruck:start()

	self.partData = self.part:getModData()
	self.tankStart = self.part:getContainerContentAmount()
	local tankLitresFree = self.part:getContainerCapacity() - self.tankStart
	self.takeLitres = tankLitresFree
	self.tankTarget = self.tankStart + self.takeLitres
	self.action:setTime(self.takeLitres * 10)
	self:setActionAnim("fill_container_tap")
	self:setOverrideHandModels(nil, nil)
end


function UGFillPropaneTruck:stop()

	ISBaseTimedAction.stop(self)
end

function UGFillPropaneTruck:perform()

	ISBaseTimedAction.perform(self)
end

function UGFillPropaneTruck:new(part, character, time)

	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.vehicle = part:getVehicle()
	o.part = part
	o.maxTime = time

	return o
end
