
require "TimedActions/ISBaseTimedAction"

ISRepairTableSaw = ISBaseTimedAction:derive("ISRepairTableSaw");



function ISRepairTableSaw:isValid()
	return true
end

function ISRepairTableSaw:waitToStart()
	self.character:faceLocation(self.sq:getX(), self.sq:getY())
	return self.character:shouldBeTurning()
end

function ISRepairTableSaw:update()
	if TableSawUI.g_hWnd then 
		TableSawUI.g_hWnd.UpdateRepairDurable(TableSawUI.g_hWnd, self:getJobDelta())
	end 
	--self.item:setJobDelta(self:getJobDelta());
	self.character:faceLocation(self.sq:getX(), self.sq:getY())
	if self.character:isSitOnGround() then
		self:forceStop();
	end
end

function ISRepairTableSaw:start()
	--print('start')

	self:setActionAnim("Craft");

	--self:setOverrideHandModels("Log", nil)

	self.sound = self.character:playSound("RepairTableSaw")
	
	--self.item:setJobType(getText("IGUI_Action_TableSawWood"));

	--self.item:setJobDelta(0.0);
end

function ISRepairTableSaw:stop()
	if self.sound then 
		self.character:stopOrTriggerSound(self.sound)
		self.sound = nil
	end 
	--self.item:setJobDelta(0.0);
	ISBaseTimedAction.stop(self);
	--self.func()
	if TableSawUI.g_hWnd then 
		TableSawUI.g_hWnd.EndRepairDurable(TableSawUI.g_hWnd)
	end 
end

function ISRepairTableSaw:Repair()
	
	--local cheat = false 
	--if not isClient() then 
	--	if ISBuildMenu.cheat then 
	--		cheat = true
	--	end 
	--end 
	--if not cheat then 
		local playerInv = self.character:getInventory()
		for i = 1,#RepairTableSawNeed do 
			local items = playerInv:getSomeTypeEvalRecurse(RepairTableSawNeed[i][1], buildUtil.predicateMaterial, RepairTableSawNeed[i][2])
			for i=1,items:size() do
				local item = items:get(i-1)
				--self.character:removeFromHands(item)
				--if item:getContainer() then
				--	item:getContainer():Remove(item);
				--	sendRemoveItemFromContainer(item:getContainer(), item);
				--else
				--	playerInv:Remove(item)
				--	sendRemoveItemFromContainer(playerInv, item);
				--end
				local srcContainer = item:getContainer()
				srcContainer:DoRemoveItem(item)
				sendRemoveItemFromContainer(srcContainer, item)
			end
		end 
	--end 

	local modData = self.tablesaw:getModData()
	if modData.Durable then 
		local result = math.min(100, modData.Durable + 30)
		modData.Durable = result
		self.tablesaw:transmitModData();
	end 
end 

function ISRepairTableSaw:perform()

	if self.sound then 
		self.character:stopOrTriggerSound(self.sound)
		self.sound = nil
	end 
	

	if TableSawUI.g_hWnd then 
		TableSawUI.g_hWnd.EndRepairDurable(TableSawUI.g_hWnd)
	end 
	

	
	ISBaseTimedAction.perform(self);

end

function ISRepairTableSaw:complete()
	self:Repair()
	return true
end 

function ISRepairTableSaw:new(character, sq, tablesaw)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	--o.playerNum = playerNum;
	o.character = character;
	o.sq = sq;
	o.stopOnWalk = true;
	o.stopOnRun = true;

	o.maxTime = 120;
	o.timer = 100;
	o.tick = 0;
	o.sound = nil;
	--o.func = func;
	--o.wnd = wnd;
	o.tablesaw = tablesaw;
	return o;
end
