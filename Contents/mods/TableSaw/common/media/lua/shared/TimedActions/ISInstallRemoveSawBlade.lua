
require "TimedActions/ISBaseTimedAction"

ISInstallRemoveSawBlade = ISBaseTimedAction:derive("ISInstallRemoveSawBlade");



function ISInstallRemoveSawBlade:isValid()
	local modData = self.tablesaw:getModData()
	if self.type == 1 then 
		if modData.SawBladeDurable then 
			if modData.SawBladeDurable > 0 then 
				return false
			end 
		end 
	elseif self.type == 2 then 
		if modData.SawBladeDurable then 
			if modData.SawBladeDurable <= 0 then 
				return false
			end 
		end 
	end 
	return true
end

function ISInstallRemoveSawBlade:waitToStart()
	self.character:faceLocation(self.sq:getX(), self.sq:getY())
	return self.character:shouldBeTurning()
end

function ISInstallRemoveSawBlade:update()
	if TableSawUI.g_hWnd then 
		TableSawUI.g_hWnd.UpdateSawblade(TableSawUI.g_hWnd, self:getJobDelta(), self.type)
	end 
	--self.item:setJobDelta(self:getJobDelta());
	self.character:faceLocation(self.sq:getX(), self.sq:getY())
	if self.character:isSitOnGround() then
		self:forceStop();
	end
end

function ISInstallRemoveSawBlade:start()
	--print('start')

	self:setActionAnim("Craft");

	--self:setOverrideHandModels("Log", nil)

	self.sound = self.character:playSound("InstallRemove")
	
	--self.item:setJobType(getText("IGUI_Action_TableSawWood"));

	--self.item:setJobDelta(0.0);
end

function ISInstallRemoveSawBlade:stop()
	if self.sound then 
		self.character:stopOrTriggerSound(self.sound)
		self.sound = nil
	end 
	--self.item:setJobDelta(0.0);
	ISBaseTimedAction.stop(self);
	
	if TableSawUI.g_hWnd then 
		TableSawUI.g_hWnd.EndSawblade(TableSawUI.g_hWnd)
	end 
end

function ISInstallRemoveSawBlade:RemoveSawBlade()
	local inventory = self.character:getInventory()
	local modData = self.tablesaw:getModData()
	-- 拆
	if modData.SawBladeDurable and self.type == 2 then 
		local inventory = self.character:getInventory()
		local tItem = inventory:AddItem('Base.CircularSawblade')

		local itemData = tItem:getModData()
		itemData.SawBladeDurable = modData.SawBladeDurable
		--print('itemData.SawBladeDurable:',itemData.SawBladeDurable)
		modData.SawBladeDurable = 0
		
		--if isClient() then 
			local itemList = ArrayList.new()
			itemList:add(tItem)
			sendAddItemsToContainer(inventory, itemList);
		--end 
		--tItem:transmitModData();
		
	elseif self.type == 1 then 
		-- 装
		local Durable = SawBladeMaxDurable
		local items = inventory:getSomeTypeEvalRecurse('Base.CircularSawblade', buildUtil.predicateMaterial, 1)
		for i=1,items:size() do
			local item = items:get(i-1)

			local data = item:getModData()
			if data.SawBladeDurable then 
				--print('data.SawBladeDurable:',data.SawBladeDurable)
				Durable = data.SawBladeDurable
			end 

			local srcContainer = item:getContainer()
			srcContainer:DoRemoveItem(item)
			--if isClient() then 
				sendRemoveItemFromContainer(srcContainer, item)
			--end 

		end
		modData.SawBladeDurable = Durable
	end 
	self.tablesaw:transmitModData();
end 

function ISInstallRemoveSawBlade:perform()

	if self.sound then 
		self.character:stopOrTriggerSound(self.sound)
		self.sound = nil
	end 
	if TableSawUI.g_hWnd then 
		TableSawUI.g_hWnd.EndSawblade(TableSawUI.g_hWnd)
	end 
	
	ISBaseTimedAction.perform(self);

end

function ISInstallRemoveSawBlade:complete()

	self:RemoveSawBlade()

	return true
end 

function ISInstallRemoveSawBlade:new(character, sq,tablesaw, type)
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
	o.type = type;
	return o;
end
