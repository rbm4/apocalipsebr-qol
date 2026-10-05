require "DAMN_Armor_Shared";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************
--v2.0.0

B700 = B700 or {};
F700 = F700 or {};
F700X = F700X or {};

function B700.activeArmor(player, vehicle)

		--

    		for i, nodisplay in ipairs ({"SeatP1", "SeatP2", "SeatP3", "SeatP4", "SeatP5", "SeatP6", "SeatP7", "SeatP8", "SeatP9", "SeatP10", "SeatP11", "SeatP12", "SeatP13", "SeatP14", "WindshieldRear", "DoorFrontLeft", "DoorRL", "DoorMR", "DoorRR", "SeatP4"})
				do
					if vehicle:getPartById(nodisplay) then
						local part = vehicle:getPartById(nodisplay)
					    	if part:getCondition() < 100 then
					    		DAMN.Armor:setPartCondition(part, 100);
							end
					end
			end

		--

			local part = vehicle:getPartById("B700Trunk")
				if part:getCondition() < 49 then
					DAMN.Armor:setPartCondition(part, 49);
				end
   
		--

			local protection = vehicle:getPartById("B700BumperFront")
			local inventoryItem = protection:getInventoryItem();
			local part = vehicle:getPartById("EngineDoor")
				if part and protection and part:getInventoryItem() and inventoryItem and part:getModData()
				then 
					if inventoryItem:getFullType() ~= "Base.87fordB700BumperFront0" then
						local partCond = tonumber(part:getModData().saveCond)
						if protection:getCondition() > 0 and partCond
						then
							if part:getCondition() < partCond
							then
								DAMN.Armor:setPartCondition(part, partCond);
								local cond = protection:getCondition() - (ZombRandBetween(0,100) <= 35 and ZombRandBetween(0,3) or 0);
								DAMN.Armor:setPartCondition(protection, cond);
							end
						end
				elseif inventoryItem:getFullType() == "Base.87fordB700BumperFront0" then
						local partCond = tonumber(part:getModData().saveCond)
						if protection:getCondition() > 0 and partCond
						then
							if part:getCondition() < partCond
							then
								DAMN.Armor:setPartCondition(part, partCond);
								local cond = protection:getCondition() - ZombRandBetween(0,4);
								DAMN.Armor:setPartCondition(protection, cond);
							end
						end
					end
				else
					local protection = vehicle:getPartById("B700BumperFront")
					local inventoryItem = protection:getInventoryItem();
					local part = vehicle:getPartById("Engine")
						if protection and inventoryItem and part and part:getModData()
						then
							if inventoryItem:getFullType() ~= "Base.87fordB700BumperFront0" then
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

			for partId, armorPartId in pairs({
				["DoorFrontRight"] = "B700DoorFrontRightArmor",
				["WindowFrontLeft"] = "B700FrontLeftArmor",
				["WindowFrontRight"] = "B700FrontRightArmor",
				["WindowRearLeft"] = "B700RearLeftArmor",
				["WindowRearRight"] = "B700RearRightArmor",
				["Windows"] = "B700SideLeftArmor",
				["Windows"] = "B700SideRightArmor",
			}) do
				local part = vehicle:getPartById(partId);
				local protection = vehicle:getPartById(armorPartId);
				if protection and protection:getInventoryItem() and part and part:getModData()
				then
					local partCond = tonumber(part:getModData().saveCond);
					if protection:getCondition() > 0 and partCond and part:getCondition() < partCond
					then
						DAMN.Armor:setPartCondition(part, partCond);
						local cond = protection:getCondition() - ZombRandBetween(0,4)
						DAMN.Armor:setPartCondition(protection, cond);
					end
				end
			end

		--

			for partId, armorPartId in pairs({
				["HeadlightLeft"] = "B700BumperFront",
				["HeadlightRight"] = "B700BumperFront",
				["HeadlightRearLeft"] = "B700BumperRear",
				["HeadlightRearRight"] = "B700BumperRear",
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

			local protection = vehicle:getPartById("B700WindshieldArmor")
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

			for i, freezeState in ipairs ({"B700Roofrack", "GasTank"})
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

			local protection = vehicle:getPartById("B700RearArmor")
			local part = vehicle:getPartById("DoorRear")
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

function F700.activeArmor(player, vehicle)

    --

        for i, nodisplay in ipairs ({"SeatP2", "SeatP3", "SeatP4", "SeatP5", "SeatP6", "SeatP7", "F700TrunkSW", "F700TrunkSWGunrack", "F700TrunkSWGuncabinet", "F700TrunkBN", "F700TrunkBX"})
            do
                if vehicle:getPartById(nodisplay) then
                    local part = vehicle:getPartById(nodisplay)
                        if part:getCondition() < 100 then
                            DAMN.Armor:setPartCondition(part, 100);
                        end
                end
        end

    --

        for i, viewportPart in ipairs ({"Windshield", "WindowFrontLeft", "WindowFrontRight", "WindowMiddleLeft", "WindowMiddleRight", "WindowRearLeft", "WindowRearRight", "WindshieldRear"})
        do
            if vehicle:getPartById(viewportPart) then
                local part = vehicle:getPartById(viewportPart)
                local viewportPart = 59;
                    if part:getCondition() < viewportPart then
                        DAMN.Armor:setPartCondition(part, viewportPart);
                    end
            end
    end

    --

        local protection = vehicle:getPartById("B700BumperFront")
        local inventoryItem = protection:getInventoryItem();
        local part = vehicle:getPartById("EngineDoor")
            if part and protection and part:getInventoryItem() and inventoryItem and part:getModData()
            then 
                if inventoryItem:getFullType() ~= "Base.87fordF700BumperFront0" then
                    local partCond = tonumber(part:getModData().saveCond)
                    if protection:getCondition() > 0 and partCond
                    then
                        if part:getCondition() < partCond
                        then
                            DAMN.Armor:setPartCondition(part, partCond);
                            local cond = protection:getCondition() - (ZombRandBetween(0,100) <= 35 and ZombRandBetween(0,3) or 0);
                            DAMN.Armor:setPartCondition(protection, cond);
                        end
                    end
            elseif inventoryItem:getFullType() == "Base.87fordF700BumperFront0" then
                    local partCond = tonumber(part:getModData().saveCond)
                    if protection:getCondition() > 0 and partCond
                    then
                        if part:getCondition() < partCond
                        then
                            DAMN.Armor:setPartCondition(part, partCond);
                            local cond = protection:getCondition() - ZombRandBetween(0,4);
                            DAMN.Armor:setPartCondition(protection, cond);
                        end
                    end
                end
            else
                local protection = vehicle:getPartById("B700BumperFront")
                local inventoryItem = protection:getInventoryItem();
                local part = vehicle:getPartById("Engine")
                    if protection and inventoryItem and part and part:getModData()
                    then
                        if inventoryItem:getFullType() ~= "Base.87fordF700BumperFront0" then
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

        for partId, armorPartId in pairs({
            ["HeadlightLeft"] = "B700BumperFront",
            ["HeadlightRight"] = "B700BumperFront",
            ["HeadlightRearLeft"] = "B700BumperRear",
            ["HeadlightRearRight"] = "B700BumperRear",
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

        for i, freezeState in ipairs ({"GasTank"})
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

    local protection = vehicle:getPartById("B700BumperRear")
    local inventoryItem = protection:getInventoryItem();
    local part = vehicle:getPartById("TrunkDoor")
        if part and protection and inventoryItem and part:getModData()
        then 
            local partCond = tonumber(part:getModData().saveCond)
            if protection:getCondition() > 0 and partCond
            then
                if part:getCondition() < partCond
                then
                    DAMN.Armor:setPartCondition(part, partCond);
                    local cond = protection:getCondition() - ZombRandBetween(0,3);
                    DAMN.Armor:setPartCondition(protection, cond);
                end
            end
        end

end

function F700X.activeArmor(player, vehicle)

    --

        local protection = vehicle:getPartById("B700BumperFront")
        local inventoryItem = protection:getInventoryItem();
        local part = vehicle:getPartById("EngineDoor")
            if part and protection and part:getInventoryItem() and inventoryItem and part:getModData()
            then 
                if inventoryItem:getFullType() ~= "Base.87fordB700BumperFront0" then
                    local partCond = tonumber(part:getModData().saveCond)
                    if protection:getCondition() > 0 and partCond
                    then
                        if part:getCondition() < partCond
                        then
                            DAMN.Armor:setPartCondition(part, partCond);
                            local cond = protection:getCondition() - (ZombRandBetween(0,100) <= 45 and ZombRandBetween(0,3) or 0);
                            DAMN.Armor:setPartCondition(protection, cond);
                        end
                    end
            elseif inventoryItem:getFullType() == "Base.87fordB700BumperFront0" then
                    local partCond = tonumber(part:getModData().saveCond)
                    if protection:getCondition() > 0 and partCond
                    then
                        if part:getCondition() < partCond
                        then
                            DAMN.Armor:setPartCondition(part, partCond);
                            local cond = protection:getCondition() - ZombRandBetween(0,4);
                            DAMN.Armor:setPartCondition(protection, cond);
                        end
                    end
                end
            else
                local protection = vehicle:getPartById("B700BumperFront")
                local inventoryItem = protection:getInventoryItem();
                local part = vehicle:getPartById("Engine")
                    if protection and inventoryItem and part and part:getModData()
                    then
                        if inventoryItem:getFullType() ~= "Base.87fordB700BumperFront0" then
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

        for partId, armorPartId in pairs({
            ["HeadlightLeft"] = "B700BumperFront",
            ["HeadlightRight"] = "B700BumperFront",
            ["HeadlightRearLeft"] = "B700BumperRear",
            ["HeadlightRearRight"] = "B700BumperRear",
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

    local protection = vehicle:getPartById("B700BumperRear")
    local inventoryItem = protection:getInventoryItem();
    local part = vehicle:getPartById("TrunkDoor")
        if part and protection and inventoryItem and part:getModData()
        then 
            local partCond = tonumber(part:getModData().saveCond)
            if protection:getCondition() > 0 and partCond
            then
                if part:getCondition() < partCond
                then
                    DAMN.Armor:setPartCondition(part, partCond);
                    local cond = protection:getCondition() - ZombRandBetween(0,6);
                    DAMN.Armor:setPartCondition(protection, cond);
                end
            end
        end

    --

        for partId, armorPartId in pairs({
            ["WindowFrontLeft"] = "B700FrontLeftArmor",
            ["WindowFrontRight"] = "B700FrontRightArmor",
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

        local protection = vehicle:getPartById("B700WindshieldArmor")
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

    for i, freezeState in ipairs ({"WindshieldRear"})
    do
        if vehicle:getPartById(freezeState) then
            local part = vehicle:getPartById(freezeState)
            local freezeCond = tonumber(part:getModData().saveCond)
                if freezeCond and part:getCondition() < freezeCond then
                    DAMN.Armor:setPartCondition(part, freezeCond)
                end
        end
end

end

DAMN.Armor:add("Base.87fordB700military", B700.activeArmor);
DAMN.Armor:add("Base.87fordB700prison", B700.activeArmor);
DAMN.Armor:add("Base.87fordB700school", B700.activeArmor);
DAMN.Armor:add("Base.87fordB700schoolmsb", B700.activeArmor);
DAMN.Armor:add("Base.87fordF700swat", F700.activeArmor);
DAMN.Armor:add("Base.87fordF700bank", F700.activeArmor);
DAMN.Armor:add("Base.87fordF700box", F700X.activeArmor);