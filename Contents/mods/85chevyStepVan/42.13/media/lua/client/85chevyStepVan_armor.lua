require "DAMN_Armor_Shared";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************
--v2.0.0

STP85 = STP85 or {};

function STP85.activeArmor(player, vehicle)
   
		--

			local protection = vehicle:getPartById("DAMNBumperFront")
			local inventoryItem = protection:getInventoryItem();
			local part = vehicle:getPartById("EngineDoor")
				if part and protection and part:getInventoryItem() and inventoryItem and part:getModData()
				then 
					if inventoryItem:getFullType() ~= "Base.85chevyStepVanBumperFront0" then
						local partCond = tonumber(part:getModData().saveCond)
						if protection:getCondition() > 0 and partCond
						then
							if part:getCondition() < partCond
							then
								DAMN.Armor:setPartCondition(part, partCond);
								local cond = protection:getCondition() - (ZombRandBetween(0,100) <= 50 and ZombRandBetween(0,4) or 0);
								DAMN.Armor:setPartCondition(protection, cond);
							end
						end
					elseif inventoryItem:getFullType() == "Base.85chevyStepVanBumperFront0" then
						local partCond = tonumber(part:getModData().saveCond)
						if protection:getCondition() > 0 and partCond
						then
							if part:getCondition() < partCond
							then
								DAMN.Armor:setPartCondition(part, partCond);
								local cond = protection:getCondition() - ZombRandBetween(1,12);
								DAMN.Armor:setPartCondition(protection, cond);
							end
						end
					end
					else
						local part = vehicle:getPartById("Engine")
							if protection and inventoryItem and part and part:getModData()
							then
								if inventoryItem:getFullType() ~= "Base.85chevyStepVanBumperFront0" then
									local partCond = tonumber(part:getModData().saveCond)
									if protection:getCondition() > 0 and partCond
									then
										if part:getCondition() < partCond
										then
											DAMN.Armor:setPartCondition(part, partCond);
											local cond = protection:getCondition() - ZombRandBetween(1,3);
											DAMN.Armor:setPartCondition(protection, cond);
										end
									end
								end
							end
				end

			--

			local protection = vehicle:getPartById("DAMNBumperRear")
			local inventoryItem = protection:getInventoryItem();
			local part = vehicle:getPartById("TrunkDoor")
				if part and protection and part:getInventoryItem() and inventoryItem and part:getModData()
				then 
					if inventoryItem:getFullType() == "Base.85chevyStepVanBumperRear0" then
						local partCond = tonumber(part:getModData().saveCond)
						if protection:getCondition() > 0 and partCond
						then
							if part:getCondition() < partCond
							then
								DAMN.Armor:setPartCondition(part, partCond);
								local cond = protection:getCondition() - ZombRandBetween(1,11);
								DAMN.Armor:setPartCondition(protection, cond);
							end
						end
					end
				end

		--

			for partId, armorPartId in pairs({
				["WindowFrontLeft"] = "DAMNFrontLeftArmor",
				["WindowFrontRight"] = "DAMNFrontRightArmor",
			}) do
				local part = vehicle:getPartById(partId);
				local protection = vehicle:getPartById(armorPartId);
				if protection and protection:getInventoryItem() and part and part:getModData()
				then
					local partCond = tonumber(part:getModData().saveCond);
					if protection:getCondition() > 0 and partCond and part:getCondition() < partCond
					then
						DAMN.Armor:setPartCondition(part, partCond);
					end
				end
			end

		--

			for partId, armorPartId in pairs({
				["HeadlightLeft"] = "DAMNBumperFront",
				["HeadlightRight"] = "DAMNBumperFront",
				["HeadlightRearLeft"] = "DAMNBumperRear",
				["HeadlightRearRight"] = "DAMNBumperRear",
				["STP85Trunk1"] = "DAMNBumperRear",
				["TrunkDoor"] = "DAMNBumperRear",
			}) do
				local part = vehicle:getPartById(partId);
				local protection = vehicle:getPartById(armorPartId);
				if protection and protection:getInventoryItem() and part and part:getModData()
				then
					local partCond = tonumber(part:getModData().saveCond);
					if protection:getCondition() > 0 and partCond and part:getCondition() < partCond
					then
						DAMN.Armor:setPartCondition(part, partCond);
					end
				end
			end

		--

		for i, freezeState in ipairs ({"DAMNSpareTire", "STP85Roofrack", "STP85Vent", "DAMNBarrier", "DAMNGasCanOne", "DAMNGenerator", "DAMNTent", "DAMNSpareTireRoof", "DAMNSpareTireRoof2"})
				do
					if vehicle:getPartById(freezeState) then
						local part = vehicle:getPartById(freezeState)
						local freezeCond = tonumber(part:getModData().saveCond)
					    	if freezeCond and part:getCondition() < freezeCond then
					    		DAMN.Armor:setPartCondition(part, freezeCond)
							end
					end
			end

		--

		for partId, armorPartId in pairs({
			["Windshield"] = "DAMNWindshieldArmor",
			["WindshieldRear"] = "DAMNWindshieldRearArmor",
		}) do
			local part = vehicle:getPartById(partId);
			local protection = vehicle:getPartById(armorPartId);
			if protection and protection:getInventoryItem() and part and part:getModData()
			then
				local partCond = tonumber(part:getModData().saveCond);
				if protection:getCondition() > 0 and partCond and part:getCondition() < partCond
				then
					DAMN.Armor:setPartCondition(part, partCond);
					local cond = protection:getCondition() - ZombRand(4);
					DAMN.Armor:setPartCondition(protection, cond);
				end
			end
		end

end

DAMN.Armor:add("Base.85chevyStepVan", STP85.activeArmor);
DAMN.Armor:add("Base.85chevyStepVanSWAT", STP85.activeArmor);