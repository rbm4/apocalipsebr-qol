require "TimedActions/ISBaseTimedAction"

LabActionTakeAlbumin = ISBaseTimedAction:derive("LabActionTakeAlbumin");

-- Works from to 15% to 85%, max eff after 50%
local albuminEff = {
	[1] = 2,
	[2] = 3,
	[3] = 5,
	[4] = 7,
	[5] = 9,
	[6] = 11,
	[7] = 12,
	[8] = 11,
	[9] = 9,
	[10] = 8,
};

function LabActionTakeAlbumin:isValid()
	return self.character:getInventory():contains(self.pills);
end--function

function LabActionTakeAlbumin:update()
	self.pills:setJobDelta(self:getJobDelta());
end--function

function LabActionTakeAlbumin:start()
	self.pills:setJobType(getText("ContextMenu_Take_pills"));
	self.pills:setJobDelta(0.0);
	self:setActionAnim(CharacterActionAnims.TakePills);
	self:setOverrideHandModels(nil, self.pills);
	self.character:playSound("Pills_A");
end--function

function LabActionTakeAlbumin:stop()
	ISBaseTimedAction.stop(self);
	self.pills:setJobDelta(0.0);
end--function

function LabActionTakeAlbumin:perform()
	self.pills:getContainer():setDrawDirty(true);
	self.pills:setJobDelta(0.0);
	local body = self.character:getBodyDamage();
	local health = body:getOverallBodyHealth();
	if health < 99 then
		body:AddGeneralHealth(math.min(health+14, 100)-health);
	end--if
	
	if body:isInfected() and self.character:getModData().AlbuminDoses ~= nil and self.character:getModData().AlbuminDoses > 0 then
		local rate =  math.ceil((LabRecipes_InfectionRate(self.character)*100-14)/7);
		if albuminEff[rate] then
			body:setInfectionTime(body:getInfectionTime()+body:getInfectionMortalityDuration()*albuminEff[rate]/100);
		end--if
	end--if
	self.pills:Use();
	LabRecipes_PrintTestInfo(self.character,nil);
	ISBaseTimedAction.perform(self);
end--function

function LabActionTakeAlbumin:new(character, pills)
	local o = {};
	setmetatable(o, self);
	self.__index = self;
	o.character = character;
	o.pills = pills;
	o.maxTime = 100;
	o.stopOnWalk = false;
	o.stopOnRun = false;
	return o;
end--function
