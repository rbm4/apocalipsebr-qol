require "DAMN_Armor_Shared";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************
--v2.0.0

BTL63 = BTL63 or {};

function BTL63.activeArmor(player, vehicle)

		--

			local protection = vehicle:getPartById("BTL63FrontBumper")
			local inventoryItem = protection:getInventoryItem();
			local part = vehicle:getPartById("EngineDoor")
				if part and protection and inventoryItem and part:getModData()
				then 
						local partCond = tonumber(part:getModData().saveCond)
						if protection:getCondition() > 0 and partCond
						then
							if part:getCondition() < partCond
							then
								DAMN.Armor:setPartCondition(part, partCond);
								local cond = protection:getCondition() - (ZombRandBetween(0,100) <= 65 and ZombRandBetween(0,5) or 0);
								DAMN.Armor:setPartCondition(protection, cond);
							end
						end
				else
					local protection = vehicle:getPartById("BTL63FrontBumper")
					local inventoryItem = protection:getInventoryItem();
					local part = vehicle:getPartById("Engine")
						if protection and inventoryItem and part and part:getModData()
						then
								local partCond = tonumber(part:getModData().saveCond)
								if protection:getCondition() > 0 and partCond
								then
									if part:getCondition() < partCond
									then
										DAMN.Armor:setPartCondition(part, partCond);
										local cond = protection:getCondition() - ZombRandBetween(1,4);
										DAMN.Armor:setPartCondition(protection, cond);
									end
								end
						end
				end

		--

			local protection = vehicle:getPartById("BTL63RearBumper")
				if protection 
				then
				    local part = vehicle:getPartById("TrunkDoor")
				    if part and protection and part:getInventoryItem() and protection:getInventoryItem() and part:getModData()
				    then 
				        local partCond = tonumber(part:getModData().saveCond)
				        if protection:getCondition() > 0 and partCond and part:getCondition() < partCond
				        then
				            DAMN.Armor:setPartCondition(part, partCond);
				            local cond = protection:getCondition() - (ZombRandBetween(0,100) <= 75 and ZombRandBetween(0,5) or 0);
				            DAMN.Armor:setPartCondition(protection, cond);
				        end
				    end
				end

		--

			for partId, armorPartId in pairs({
				["WindowFrontLeft"] = "BTL63FrontLeftArmor",
				["WindowFrontRight"] = "BTL63FrontRightArmor",
                ["WindowRearLeft"] = "BTL63RearLeftArmor",
				["WindowRearRight"] = "BTL63RearRightArmor",
			}) do
				local part = vehicle:getPartById(partId);
				local protection = vehicle:getPartById(armorPartId);
				if protection and protection:getInventoryItem() and part and part:getModData()
				then
					local partCond = tonumber(part:getModData().saveCond);
					if protection:getCondition() > 0 and partCond and part:getCondition() < partCond
					then
						DAMN.Armor:setPartCondition(part, partCond);
                        local cond = protection:getCondition() - ZombRandBetween(0,2)
						DAMN.Armor:setPartCondition(protection, cond);
					end
				end
			end

		--

			for partId, armorPartId in pairs({
				["HeadlightLeft"] = "BTL63FrontBumper",
				["HeadlightRight"] = "BTL63FrontBumper",
				["HeadlightRearLeft"] = "BTL63RearBumper",
				["HeadlightRearRight"] = "BTL63RearBumper",
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

			local protection = vehicle:getPartById("BTL63WindshieldArmor")
			local part = vehicle:getPartById("Windshield")
			if protection and protection:getInventoryItem() and part and part:getModData()
			then
				local partCond = tonumber(part:getModData().saveCond)
				if protection:getCondition() > 0 and partCond
				then
					if part:getCondition() < partCond
					then
						DAMN.Armor:setPartCondition(part, partCond);
						local cond = protection:getCondition() - (ZombRandBetween(0,100) <= 65 and ZombRandBetween(0,3) or 0)
						DAMN.Armor:setPartCondition(protection, cond);
					end
				end
			end

		--

		for i, freezeState in ipairs ({"BTL63Spare","BTL63SpareA","BTL63SpareB","BTL63SpareC","BTL63SpareD", "BTL63Roofrack",})
				do
					if vehicle:getPartById(freezeState) then
						local part = vehicle:getPartById(freezeState)
						local freezeCond = tonumber(part:getModData().saveCond)
					    	if freezeCond and part:getCondition() < freezeCond then
					    		DAMN.Armor:setPartCondition(part, freezeCond);
							end
					end
			end

		--

			local protection = vehicle:getPartById("BTL63WindshieldRearArmor")
			local part = vehicle:getPartById("WindshieldRear")
			if protection and protection:getInventoryItem() and part and part:getModData()
			then
				local partCond = tonumber(part:getModData().saveCond)
				if protection:getCondition() > 0 and partCond
				then
					if part:getCondition() < partCond
					then
						DAMN.Armor:setPartCondition(part, partCond);
						local cond = protection:getCondition() - (ZombRandBetween(0,100) <= 65 and ZombRandBetween(0,3) or 0)
						DAMN.Armor:setPartCondition(protection, cond);
					end
				end
			end
end

DAMN.Armor:add("Base.63beetle", BTL63.activeArmor);
DAMN.Armor:add("Base.63beetleHP", BTL63.activeArmor);
DAMN.Armor:add("Base.63beetleBuggy", function(player, vehicle)
    BTL63.activeArmor(player, vehicle);
    	local part = vehicle:getPartById("EngineDoor")
				if part and part:getCondition() < 30 then
					DAMN.Armor:setPartCondition(part, 30);
				end
end);