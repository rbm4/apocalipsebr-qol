require "ISUI/ISToolTipInv"


local function SetBackPackProperty()
	local item1 = ScriptManager.instance:FindItem("Base.ResidentEvilBackPack")
	if item1 then 
		local WeightReduction = SandboxVars.ResidentEvilBackpackWeightReduction
		item1:DoParam('WeightReduction = ' .. tostring(WeightReduction))
	end 
	local item2 = ScriptManager.instance:FindItem("Base.ResidentEvilSuspenders")
	if item2 then 
		local WeightReduction = SandboxVars.ResidentEvilSuspendersWeightReduction
		item2:DoParam('WeightReduction = ' .. tostring(WeightReduction))
	end 
end 

Events.OnInitGlobalModData.Add(SetBackPackProperty)

function MyBackpack_hasRoomFor(fun)
	return function(self, player, item)
		local containerType = self:getType()
		--print('123')
		local parent = self:getParent()
		local ismy = false
		if instanceof(parent, "BaseVehicle") then
			local scriptName = parent:getScriptName()
			--print('scriptName:',scriptName)
			if scriptName == 'Base.Biochemical_PickupTruck' then 
				local containerType = self:getType()
				if containerType == 'TruckBed' or containerType == 'Biochemical_PickupTruck_RooftrackPart' then 
					--print('containerType:',containerType)
					ismy = true 
				end 
			end 
		end
		
		if containerType == 'ResidentEvilBackPack' or containerType == 'ResidentEvilSuspenders' or ismy then
			local nowWeight = self:getContentsWeight() 
			local nCapacity = self:getEffectiveCapacity(player)
			if type(item) == "number" then
				return item + nowWeight <= nCapacity
			elseif instanceof(item, "InventoryItem") then 
				--print('bb')
				--print('item:getUnequippedWeight():',item:getUnequippedWeight())
				return item:getUnequippedWeight() + nowWeight <= nCapacity
			end
			--return true
		end 

		return fun(self, player, item)
	end
end

local function getFinalCapacity(player, Capacity)
	if player then
		--self:getCapacity()
		if player:hasTrait(CharacterTrait.ORGANIZED) then 
			return math.ceil(Capacity * 1.3)
		elseif player:hasTrait(CharacterTrait.DISORGANIZED) then 
			return math.ceil(Capacity * 0.7)
		end
	end 
	return Capacity
end 

function MyBackpack_getEffectiveCapacity(fun)
	return function(self, player)
		local containerType = self:getType()
		
		local parent = self:getParent()
		if instanceof(parent, "BaseVehicle") then
			local scriptName = parent:getScriptName()
			if scriptName == 'Base.Biochemical_PickupTruck' then 
				--local containerType = self:getType()
				if containerType == 'TruckBed' then 
					return getFinalCapacity(player, 400)
				elseif containerType == 'Biochemical_PickupTruck_RooftrackPart' then 
					return getFinalCapacity(player, 200)
				end 
			end 
		end

		if containerType == 'ResidentEvilBackPack' or containerType == 'ResidentEvilSuspenders' then
			local nCapacity = 49
			--print('containerType:',containerType)
			if containerType == 'ResidentEvilBackPack' then 
				--print('aa')
				nCapacity = SandboxVars.ResidentEvilBackpackCapacity
			elseif containerType == 'ResidentEvilSuspenders' then 
				--print('bb')
				nCapacity = SandboxVars.ResidentEvilSuspendersCapacity
			end 
			if player then
				return getFinalCapacity(player, nCapacity)
			end
			return nCapacity
		end 
		--print('no')
		return fun(self, player)
	end
end




local function OnGameStart()
	-- 获取元表API
	local index = __classmetatables[ItemContainer.class].__index
	if index['getEffectiveCapacity'] then 
		local fun = index['getEffectiveCapacity']
		index['getEffectiveCapacity'] = MyBackpack_getEffectiveCapacity(fun) 
	end 
	if index['hasRoomFor'] then 
		local fun = index['hasRoomFor']
		index['hasRoomFor'] = MyBackpack_hasRoomFor(fun) 
	end 
end


Events.OnGameStart.Add(OnGameStart)
Events.OnServerStarted.Add(OnGameStart)

