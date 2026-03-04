require "TimedActions/ISBaseTimedAction"

print("[PumpsHavePropaneMP] UGTakePropane v8 LOADED")

UGTakePropane = ISBaseTimedAction:derive("UGTakePropane")

function UGTakePropane:isValid()
	if not self.pump then return false end
	if not self.tank then return false end
	if not self.tank:getContainer() then return false end
	return true
end

function UGTakePropane:waitToStart()
	self.character:faceLocation(self.pump:getSquare():getX(), self.pump:getSquare():getY())
	return self.character:shouldBeTurning()
end

function UGTakePropane:update()
	self.tank:setJobDelta(self:getJobDelta())
	self.character:faceLocation(self.pump:getSquare():getX(), self.pump:getSquare():getY())
	self.character:setMetabolicTarget(Metabolics.LightWork)
end

function UGTakePropane:start()
	if self.istorch then
		self:setOverrideHandModels(nil, "BlowTorch")
		self:setActionAnim("Loot")
	else
		self:setOverrideHandModels(nil, "PropaneTank")
		self:setActionAnim("TakeGasFromPump")
	end
	self.tank:setJobType(getText("ContextMenu_TakePropaneFromPump"))
	self.tank:setJobDelta(0.0)
end

function UGTakePropane:stop()
	self.tank:setJobDelta(0.0)
	ISBaseTimedAction.stop(self)
end

function UGTakePropane:perform()
	self.tank:setJobDelta(0.0)

	if isClient() then
		-- MP: let server handle the fill and broadcast to all clients
		sendClientCommand(self.character, "PumpsHavePropaneMP", "refillItem", {
			itemId = self.tank:getID()
		})
	else
		-- SP: fill locally
		if self.tank.setUsedDelta then self.tank:setUsedDelta(1.0) end
		local maxUses = 1
		if self.tank.getMaxUses then maxUses = self.tank:getMaxUses() end
		if maxUses < 1 then maxUses = 1 end
		if self.tank.setCurrentUses then self.tank:setCurrentUses(maxUses) end
	end

	-- Update character model
	local container = self.tank:getContainer()
	if container and container:getParent() and container:getParent() == self.character then
		self.character:resetModel()
	end

	ISBaseTimedAction.perform(self)
end

function UGTakePropane:new(pump, tank, player, time, duration, istorch)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = player
	o.pump = pump
	o.tank = tank
	o.maxTime = time
	o.istorch = istorch
	o.stopOnWalk = true
	o.stopOnRun = true
	return o
end
