
require "TimedActions/ISBaseTimedAction"

ISTableSawTimedAction = ISBaseTimedAction:derive("ISTableSawTimedAction");





function ISTableSawTimedAction:isValid()
	--if not self.wnd:getIsVisible() then 
	--	return false
	--end 
	if TableSawUI.g_hWnd == nil then 
		return false
	end 
	local modData = self.tablesaw:getModData();
	if modData.Durable then 
		if modData.Durable <= (TableSawMaxDurable * 0.1) then 
			return false
		end 
	end 
	if modData.SawBladeDurable then 
		if modData.SawBladeDurable <= 0.0 then 
			return false
		end 
	end 
    --if not self.item or not self.character:getInventory():contains(self.item) then
    --    return false
    --end
	return true
end


function ISTableSawTimedAction:update()
	self.item:setJobDelta(self:getJobDelta());
	if self.sq then 
		self.character:faceLocation(self.sq:getX(), self.sq:getY()) 
	end 
	if self.character:isSitOnGround() then
		self:forceStop();
	end
end

function ISTableSawTimedAction:forceComplete()
	if not isClient() then
		return;
	end
	self.maxTime = 0.0
	self.action:setTime(self.maxTime)
	self.item:setJobDelta(0.0);
	if self.action then
        self.action:stopTimedActionAnim();
    end

	self.action:forceComplete()

end



function ISTableSawTimedAction:start()
	self:setActionAnim("Bob_TableSawWood");
	self:setOverrideHandModels("Log", nil)

	if isClient() then 
		if self.sq then 
			local x = self.sq:getX()
			local y = self.sq:getY()
			local z = self.sq:getZ()
			sendClientCommand("TableSaw", "PlaySound", {rx = x, ry = y , rz = z});
			--print('client:send')
		end 
	else 
		local emitter = self.character:getEmitter()
		self.sound = emitter:playSound("TableSaw1")
		emitter:setVolume(self.sound, TableSawVolume:getValue())
	end 
	
	self.item:setJobType(getText("IGUI_Action_TableSawWood"));

	self.item:setJobDelta(0.0);

end

function ISTableSawTimedAction:stopsound()
	if isClient() then 
		if self.sq then 
			local x = self.sq:getX()
			local y = self.sq:getY()
			local z = self.sq:getZ()
			sendClientCommand("TableSaw", "StopPlaySound", {rx = x, ry = y , rz = z});
		end 
	else 
		if self.sound then 
			if TableSawInterruptSound:getValue() then 
				self.character:stopOrTriggerSound(self.sound)
			end 
			self.sound = nil
		end 
	end 
end 

function ISTableSawTimedAction:stop()
	self:stopsound()
	self.item:setJobDelta(0.0);
	
	ISBaseTimedAction.stop(self);
end

-- Integrated from TableSawMPFix: network item references can be missing or stale.
local function findSawWood(character, item)
	local inventory = character and character:getInventory()
	if not inventory then return nil end
	if item then
		if inventory:contains(item) and CanSawLogList[item:getType()] then
			return item
		end
		local same = inventory:getItemWithID(item:getID())
		if same and CanSawLogList[same:getType()] then return same end
	end
	for _, itemType in ipairs({ "Log", "LargeBranch", "Sapling" }) do
		if CanSawLogList[itemType] then
			local found = inventory:getFirstType(itemType)
			if found then return found end
		end
	end
	return nil
end

function ISTableSawTimedAction:SawWood()
	self.item = findSawWood(self.character, self.item)
	if not self.item then
		return -1
	end 
	local givename = CanSawLogList[self.item:getType()]

	--self.item:Use();
	local inventory = self.character:getInventory()
	--inventory:Remove(self.item)

	local srcContainer = self.item:getContainer()
	srcContainer:DoRemoveItem(self.item)
	sendRemoveItemFromContainer(srcContainer, self.item)

	--local num = SandboxVars.More_GiveBoardNum
	local num = SandboxVars.TableSawCreatePlankNum
	if givename == 'Base.TreeBranch2' then 
		num = num / 2 
	end 
	for i = 1,num do 
		local tItem = inventory:AddItem(givename)
		if inventory:contains(tItem) then
			inventory:Remove(tItem)
		end
		if self.sq then 
			local tmpx = self.sq:getX() + TableSawSpriteList[self.sprite][7]
			local tmpy = self.sq:getY() + TableSawSpriteList[self.sprite][8]
			local tmpz = self.sq:getZ() 
			local tmpsq = getSquare(tmpx, tmpy, tmpz)
			local dropSq = self.sq
			if not tmpsq:has(TableSawSpriteList[self.sprite][9]) then 
				local dropSqX = self.sq:getX() + TableSawSpriteList[self.sprite][3]
				local dropSqY = self.sq:getY() + TableSawSpriteList[self.sprite][4]
				local dropSqZ = self.sq:getZ() 
				dropSq = getSquare(dropSqX, dropSqY, dropSqZ)
			end 
			if SandboxVars.TableSawPlankArrangeNeatly then 
				dropSq:AddWorldInventoryItem(tItem, 0.5, 0.5, 0)
			else 
				dropSq:AddWorldInventoryItem(tItem, 0, 0, 0)
			end 
		end 
	end 
	
	if not SandboxVars.TableSawIsUnGiveWoodworkXp then 
		if isServer() then 
			addXp(self.character, Perks.Woodwork, 1)
		else 
			self.character:getXp():AddXP(Perks.Woodwork, 1);
		end 
	end 
	
	-- 掉耐久逻辑
	local nLevel = self.character:getPerkLevel(Perks.Woodwork)
	--print('nLevel:',nLevel)
	local modData = self.tablesaw:getModData();
	if not modData.SawBladeDurable then 
		modData.SawBladeDurable = SawBladeMaxDurable - ZombRandFloat(0.00,8.00)
	end 
	if not modData.Durable then 
		modData.Durable = SawBladeMaxDurable - ZombRandFloat(0.00,8.00)
	end 
	if nLevel <= 3 then 
		modData.SawBladeDurable = modData.SawBladeDurable - 1.00
	else 
		local pro = 24 - ((nLevel - 3) * 2)
		local randpro = ZombRand(1,100)
		if randpro < pro then 
			modData.SawBladeDurable = modData.SawBladeDurable - 1.00
		end 
	end 
	-- 台锯本身不受木工影响
	local randpro = ZombRand(1,100)
	if randpro < 20 then 
		modData.Durable = modData.Durable - 1.00
	end 
	-- 同步
	self.tablesaw:transmitModData();
	-- 手受伤
	if SandboxVars.TableSawIsEnableDamageHand then 
		if nLevel <= 4 then 
			local pro = 5 - nLevel * 1
			local ranDamage = ZombRand(0,100)
			if ranDamage < pro then 
				local hand = BodyPartType.Hand_R
				local ranhand = ZombRand(1,2)
				if ranhand == 1 then 
					hand = BodyPartType.Hand_L
				end 
				local bodyPart = self.character:getBodyDamage():getBodyPart(hand)
				local ranType = ZombRand(0,100)
				if ranType <= 10 then 
					-- 设置深度伤口
					bodyPart:setDeepWoundTime(3.0)
					bodyPart:setDeepWounded(true)
	
					-- 设置流血状态
					bodyPart:setBleedingTime(1.0)
					bodyPart:setBleeding(true)
	
					-- 设置疼痛和伤害
					local newPain = math.min(bodyPart:getAdditionalPain() + 15.0, 100)
					bodyPart:setAdditionalPain(newPain)
					local newHealth = math.max(bodyPart:getHealth() - 50.0, 0)
					bodyPart:SetHealth(newHealth)
				else 
					-- 擦伤
					bodyPart:setScratchTime(3.0)
					bodyPart:setScratched(true,true);
					-- 设置流血状态
					bodyPart:setBleedingTime(1.0);
					bodyPart:setBleeding(true);
					
					-- 设置疼痛和伤害
					local newPain = math.min(bodyPart:getAdditionalPain() + 5.0, 100)
					bodyPart:setAdditionalPain(newPain)
					local newHealth = math.max(bodyPart:getHealth() - 20.0, 0)
					bodyPart:SetHealth(newHealth)
				end 
				if isClient() then 
					self.character:playSound("TableSawDamage")
				end 
				return -2
			end 
		end 
	end 
	return 0
end 

function ISTableSawTimedAction:perform()
	--print('perform')
	self:stopsound()

	if self.onCompleteFunc then
		local args = self.onCompleteArgs
		self.onCompleteFunc(args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8])
	end
	
	ISBaseTimedAction.perform(self);
end

function ISTableSawTimedAction:setOnComplete(func, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
	self.onCompleteFunc = func
	self.onCompleteArgs = { arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8 }
end 

function ISTableSawTimedAction:complete()
	local nRet = true
	if self:SawWood() ~= 0 then 
		nRet = false
	end 

	return nRet
end 

function ISTableSawTimedAction:new(character, item, tablesaw, sprite, maxTime)
--function ISTableSawTimedAction:new(playerNum, item, wnd, sprite)
	--local o = {}
	--setmetatable(o, self)
	--self.__index = self
	local o = ISBaseTimedAction.new(self, character)
	--o.playerNum = playerNum;
	--o.character = getSpecificPlayer(playerNum);
	o.character = character;
	o.item = item;
	o.stopOnWalk = true;
	o.stopOnRun = true;
	--o.wnd = wnd;
	--o.tablesaw = wnd.tablesaw;
	o.tablesaw = tablesaw;
	o.sq = tablesaw:getSquare() ;
	o.sprite = sprite;
	o.maxTime = maxTime;
	o.timer = o.maxTime / 5
	--o.timer = 100;
	o.tick = 0;
	o.sound = nil;
	--o.func = func;
	return o;
end
