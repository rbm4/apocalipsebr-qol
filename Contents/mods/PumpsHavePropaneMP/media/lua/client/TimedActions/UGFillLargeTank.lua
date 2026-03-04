require "TimedActions/ISBaseTimedAction"

UGFillLargeTank = ISBaseTimedAction:derive("UGFillLargeTank")

function UGFillLargeTank.isValid()

	--print( "keyword: UGFillLargeTank:isValid() called")
	return true
end

function UGFillLargeTank:waitToStart()

	self.character:faceLocation( self.propanetankobject:getSquare():getX(), self.propanetankobject:getSquare():getY())
	return self.character:shouldBeTurning()
end

function UGFillLargeTank:update()

	--print( "keyword: UGFillLargeTank:update() called")
	self.character:faceLocation(self.propanetankobject:getSquare():getX(), self.propanetankobject:getSquare():getY())
	self.FillCurrent = self.FillCurrent + (self.Step * self:getJobDelta())

	if self.FillCurrent >= 1 and self.propanetankobjectdata.PropaneContent < 100 then

		self.propanetankobjectdata.PropaneContent = self.propanetankobjectdata.PropaneContent + 1
		self.propanetankobject:transmitModData()
		self.FillCurrent = 0
	end

	self.character:setMetabolicTarget(Metabolics.UsingTools)
end

function UGFillLargeTank:start()

	--print( "keyword: UGFillLargeTank:start() called")
end

function UGFillLargeTank:stop()

	--print( "keyword: UGFillLargeTank:stop() called")
    ISBaseTimedAction.stop( self);
end

function UGFillLargeTank:perform()

	ISBaseTimedAction.perform( self)
end

function UGFillLargeTank:new( propanetankobject, character, time)

	--print( "keyword: UGFillLargeTank:new() called")
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
    o.propanetankobject = propanetankobject
	o.propanetankobjectdata = propanetankobject:getModData()
	o.FillCurrent = 0
	o.Step = time / 100
	o.maxTime = time
	o.stopOnWalk = true
	o.stopOnRun = true
	return o
end
