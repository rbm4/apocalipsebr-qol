require "DAMN_Parts";
require "DAMN_Spawns";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

DAMN.Parts:processConfigV2("F350", {
	["FrontBumper"] = {
		partId = "F350FrontBumper",
		itemToModel = {
			["Base.90fordF350BumperFront"] = "FrontBumper0",
			["Base.90fordF350BullbarFront"] = "FrontBumper1",
			["Base.90fordF350ReinforcedBumperFront"] = "FrontBumper2",
		},
		default = "first",
	},
	["RearBumper"] = {
		partId = "F350RearBumper",
		itemToModel = {
			["Base.90fordF350BumperRear"] = "RearBumper",
		},
		default = "first",
	},
	["WindshieldArmor"] = {
		partId = "F350WindshieldArmor",
		itemToModel = {
			["Base.90fordF350WindshieldArmor"] = "F350winda",
		},
	},
	["WindowFrontLeftArmor"] = {
		partId = "F350WindowFrontLeftArmor",
		itemToModel = {
			["Base.90fordF350WindowFrontArmor"] = "F350leftwina",
		},
	},
	["WindowFrontRightArmor"] = {
		partId = "F350WindowFrontRightArmor",
		itemToModel = {
			["Base.90fordF350WindowFrontArmor"] = "F350rightwina",
		},
	},
	["WindowRearLeftArmor"] = {
		partId = "F350WindowRearLeftArmor",
		itemToModel = {
			["Base.90fordF350WindowRearRightArmor"] = "F350leftrearwina",
		},
	},
	["WindowRearRightArmor"] = {
		partId = "F350WindowRearRightArmor",
		itemToModel = {
			["Base.90fordF350WindowRearRightArmor"] = "F350rightrearwina",
		},
	},
	["WindshieldRearArmor"] = {
		partId = "F350WindshieldRearArmor",
		itemToModel = {
			["Base.90fordF350WindshieldRearArmor"] = "F350rearwina",
		},
	},
	["Sidesteps"] = {
		partId = "F350Sidesteps",
		itemToModel = {
			["Base.90fordF350Sidesteps2"] = "Sidesteps",
		},
		default = "trve_random",
		noPartChance = 25,
	},
    ["Stretcher"] = {
		partId = "DAMNStretcher",
		itemToModel = {
			["USMIL.Stretcher0"] = "StretcherMil",
            ["USMIL.Stretcher1"] = "StretcherCiv",
		},
		default = "trve_random",
		noPartChance = 33,
	},
});


function F350.ContainerAccess.TrunkCorner(vehicle, part, chr)
	if chr:getVehicle() then return false end
	if not vehicle:isInArea(part:getArea(), chr) then return false end
	local Trunk = vehicle:getPartById("TrunkDoorCorner")
	if Trunk and Trunk:getDoor() then
		if not Trunk:getInventoryItem() then return true end
		if not Trunk:getDoor():isOpen() then return false end
	end
	--
	return true
end

function F350.ContainerAccess.TrunkLeft(vehicle, part, chr)
	if chr:getVehicle() then return false end
	if not vehicle:isInArea(part:getArea(), chr) then return false end
	local TrunkLeft = vehicle:getPartById("TrunkDoorLeft")
	if TrunkLeft and TrunkLeft:getDoor() then
		if not TrunkLeft:getInventoryItem() then return true end
		if not TrunkLeft:getDoor():isOpen() then return false end
	end
	--
	return true
end

function F350.ContainerAccess.TrunkRight(vehicle, part, chr)
	if chr:getVehicle() then return false end
	if not vehicle:isInArea(part:getArea(), chr) then return false end
	local TrunkRight = vehicle:getPartById("TrunkDoorRightA")
	if TrunkRight and TrunkRight:getDoor() then
		if not TrunkRight:getInventoryItem() then return true end
		if not TrunkRight:getDoor():isOpen() then return false end
	end
	--
	return true
end

function F350.ContainerAccess.InsideLeft(vehicle, part, chr)
	if chr:getVehicle() == vehicle then
		local seat = vehicle:getSeat(chr)
		return seat == 4 or seat == 3 or seat == 2;
	elseif chr:getVehicle() then
		return false
	else
		if not vehicle:isInArea(part:getArea(), chr) then return false end
		local doorPart = vehicle:getPartById("DoorRear")
		if doorPart and doorPart:getDoor() and not doorPart:getDoor():isOpen() then
			return false
		end
		return true
	end
end

function F350.ContainerAccess.InsideFront(vehicle, part, chr)
	if chr:getVehicle() == vehicle then
		local seat = vehicle:getSeat(chr)
		return seat == 4 or seat == 3 or seat == 2;
	elseif chr:getVehicle() then
		return false
	else
		if not vehicle:isInArea(part:getArea(), chr) then return false end
		local doorPart = vehicle:getPartById("DoorRearRight")
		if doorPart and doorPart:getDoor() and not doorPart:getDoor():isOpen() then
			return false
		end
		return true
	end
end

function F350.Dismantle2Tires(items, result, player, selectedItem)

    local addType = "Base.90fordF350Tire2"
    local tireCond = selectedItem:getCondition();

    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getXp():AddXP(Perks.Mechanics, 4);

end