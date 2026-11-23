require "Vehicles/TimedActions/ISRemoveBurntVehicle"

NepWrecks = NepWrecks or {}
NepWrecks.Options = {}
-- NepWrecks.Options.Debug = true  -- Now in SandboxVars
-- NepWrecks.Options.FuelUsed = 2  -- Now in SandboxVars
-- NepWrecks.Options.NeedMask = false -- Now in SandboxVars
NepWrecks.Options.DropParts = false -- drop parts from the car
NepWrecks.Options.ConvertPartsToLoot = true -- if true and parts not dropped, get more loot
NepWrecks.Options.ConvertPartsToLootRatio = 200 -- a typical intact car has ~31 parts for ~3000 total condition if new.
NepWrecks.Options.LootRollsBase = 0 --Vanilla is zero
NepWrecks.Options.LootRollsWeldingMultiplier = 2 --vanilla is 2
NepWrecks.Options.LootRollsWeldingBonusStart = 5 --vanilla is 5
NepWrecks.Options.LootRollsWeldingSkillGainMult = 1.0 -- 1.0 is probably fine, a full condition car is only ~double a wreck


-- items that can be dropped. 
NepWrecks.RandomLoot={
	"ElectricWire",
	"NutsBolts",
	"Wire",
	"SteelBar",
	"SteelBarHalf",
	"SteelBarQuarter",
	"SteelPiece",
	"SteelBlock",
	"SteelChunk",
	"MetalBar",
	"MetalPipe",
	"SheetMetal",
	"SmallSheetMetal",
	"ScrapMetal",
}

function NepWrecks.DebugSay(message)
	if SandboxVars.NepWrecks.DebugMode then print("NepWrecks: " .. message) end
end

function NepWrecks.isUsableTorch(item)
	return (item ~= nil) and
		(item:hasTag(ItemTag.BLOW_TORCH) or item:getType() == "BlowTorch") and
		(item:getCurrentUses() >= SandboxVars.NepWrecks.FuelUsed)
end

function NepWrecks.getRandomLoot()
	return NepWrecks.RandomLoot[ZombRand(#NepWrecks.RandomLoot)+1]
end

-- Build 42.22.2 drops intact vehicles in the vanilla constructor.
-- Keep character/vehicle as fields for NetTimedAction reconstruction on the server.
function ISRemoveBurntVehicle:new(character, vehicle)
	local action = ISBaseTimedAction.new(self, character)
	action.vehicle = vehicle
	action.stopOnWalk = false
	action.stopOnRun = false
	action.maxTime = action:getDuration()
	return action
end

function ISRemoveBurntVehicle:isValid()
	return self.vehicle ~= nil and not self.vehicle:isRemovedFromWorld()
		and NepWrecks.isUsableTorch(self.character:getPrimaryHandItem())
		and not (VehicleClaim and VehicleClaim.isClaimed and VehicleClaim.isClaimed(self.vehicle))
end

function ISRemoveBurntVehicle:complete()
	if not self.vehicle or self.vehicle:isRemovedFromWorld() or not self.vehicle:getSquare() then
		return false
	end
	-- The torch must still be equipped when the server completes the action.
	if not self.character or not NepWrecks.isUsableTorch(self.item)
		or self.character:getPrimaryHandItem() ~= self.item then
		return false
	end

	local totalXp = 5;
	-- Count the non-scrap parts 
	local parts = self.vehicle:getPartCount()
	local partsFound=0
	local partsFoundTotalCondition=0
	--NepWrecks.DebugSay("Parts count: "..parts)
	if parts > 0 then
		for  i=0,parts-1 do
			local --[[@VehiclePart]]part = self.vehicle:getPartByIndex(i)		
			if part ~= nil then 
				local partInventoryItem = part:getInventoryItem()
				local partCond = part:getCondition() or 0
				local partContainer = part:getItemContainer()
				if partInventoryItem ~= nil then
					NepWrecks.DebugSay("VehiclePart["..i.."] -> part: "..partInventoryItem:getType().. " Condition: "..partCond)
					partsFound=partsFound+1
					partsFoundTotalCondition=partsFoundTotalCondition+partCond
					if (partContainer ~= nil) then
						NepWrecks.DebugSay("Pulling Stuff Out of Container")
						local carJunk=partContainer:getItems()
						for j=0,carJunk:size()-1 do
							local junk=carJunk:get(j)
							if junk ~= nil then 
								self.vehicle:getSquare():AddWorldInventoryItem(junk,ZombRandFloat(0,0.9), ZombRandFloat(0,0.9),0.0)
							end
						end
					end
					if NepWrecks.Options.DropParts then
						--Need to exclude Trunk & Glove Box, since they have world items but shoudl not be geting dropped
						--Or filter by "has an inventory item" which will catch modded things too?
						--if not(string.match(partItem:getType(), "GloveBox%d") or string.match(partItem:getType(),"%a+Trunk%d" )) then	
						if not (partInventoryItem) then 
							local itemOnGround = self.vehicle:getSquare():AddWorldInventoryItem(partInventoryItem,ZombRandFloat(0,0.9), ZombRandFloat(0,0.9),0.0)
							itemOnGround:setCondition(partCond)
						end
					end
				end
			end
		end
	end
	NepWrecks.DebugSay("Parts Found: "..partsFound.." TotalCondition: "..partsFoundTotalCondition)
	

	-----------------------
	-- for reference: 
	--[[
	function ISRemoveBurntVehicle:checkAddItem(item, baseChance)
		if ZombRand(baseChance-self.character:getPerkLevel(Perks.MetalWelding)) == 0 then
			self.vehicle:getSquare():AddWorldInventoryItem(item, ZombRandFloat(0,0.9), ZombRandFloat(0,0.9), 0);
			return true;
		elseif (not item == "BrokenGlass") and ZombRand(baseChance-self.character:getPerkLevel(Perks.MetalWelding)) == 0 then
			self.vehicle:getSquare():AddWorldInventoryItem("UnusableMetal", ZombRandFloat(0,0.9), ZombRandFloat(0,0.9), 0);
		end
		return false;
	end	
	]]

	--roll for loot
	local rolls = NepWrecks.Options.LootRollsBase 
	-- (better of LootRollsWeldingBonusStart and Welding skill) * Multiplier
	rolls = rolls + math.max(NepWrecks.Options.LootRollsWeldingBonusStart, self.character:getPerkLevel(Perks.MetalWelding)) * NepWrecks.Options.LootRollsWeldingMultiplier
	-- extra rolls from having more functional part on the car.
	if not(NepWrecks.Options.DropParts) and NepWrecks.Options.ConvertPartsToLoot then
		rolls = rolls + math.floor(partsFoundTotalCondition/NepWrecks.Options.ConvertPartsToLootRatio)
	end
	-- extra loot from sandbox options (or potentially less loot I guess)
	if (SandboxVars.NepWrecks.LootMult ~= 1.0) then
		rolls = math.floor(rolls * SandboxVars.NepWrecks.LootMult)
	end

	NepWrecks.DebugSay("Rolling for loot: "..rolls.." times.")
	for i=1,rolls do
		if self:checkAddItem("AluminumScrap", 12) then totalXp = totalXp + 1 end;
		if self:checkAddItem("CopperScrap", 12) then totalXp = totalXp + 1 end;
		if self:checkAddItem("ElectricWire", 25) then totalXp = totalXp + 1 end;
        if self:checkAddItem("EngineParts", 25) then totalXp = totalXp + 1 end;
		if self:checkAddItem("IronBand", 25) then totalXp = totalXp + 1 end;
		if self:checkAddItem("IronBandSmall", 15) then totalXp = totalXp + 1 end;
		if self:checkAddItem("IronScrap", 12) then totalXp = totalXp + 1 end;
		if self:checkAddItem("MetalBar", 15) then totalXp = totalXp + 1 end;
		if self:checkAddItem("MetalPipe", 15) then totalXp = totalXp + 1 end;
		if self:checkAddItem("NutsBolts", 25) then totalXp = totalXp + 1 end;
		if self:checkAddItem("ScrapMetal", 12) then totalXp = totalXp + 1 end;
		if self:checkAddItem("Screws", 25) then totalXp = totalXp + 1 end;
		if self:checkAddItem("SheetMetal", 25) then totalXp = totalXp + 1 end;
		if self:checkAddItem("SmallSheetMetal", 15) then totalXp = totalXp + 1 end;
        if self:checkAddItem("SteelBar", 25) then totalXp = totalXp + 1 end;
        if self:checkAddItem("SteelBarHalf", 15) then totalXp = totalXp + 1 end;
        if self:checkAddItem("SteelBarQuarter", 12) then totalXp = totalXp + 1 end;
        if self:checkAddItem("SteelBlock", 25) then totalXp = totalXp + 1 end;
        if self:checkAddItem("SteelChunk", 15) then totalXp = totalXp + 1 end;
        if self:checkAddItem("SteelPiece", 12) then totalXp = totalXp + 1 end;
		if self:checkAddItem("Wire", 25) then totalXp = totalXp + 1 end;
	end

	if SandboxVars.NepWrecks.FuelUsed > 0 then 
		for i=1,SandboxVars.NepWrecks.FuelUsed do
			self.item:Use(false, false, true);
		end
	end

	local totalXpadjusted = math.floor(totalXp * NepWrecks.Options.LootRollsWeldingSkillGainMult)
	NepWrecks.DebugSay("XP Earned[modified]: "..totalXp.. "["..totalXpadjusted.."]")	
	addXp(self.character, Perks.MetalWelding, totalXp);
	self.vehicle:permanentlyRemove()
	return true
end
