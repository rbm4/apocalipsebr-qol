require "DAMN_Parts";
require "DAMN_Spawns";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

DAMN.Parts:processConfigV2("F350", {
	["FrontBumper"] = {
		partId = "DAMNBumperFront",
		itemToModel = {
			["Base.90fordF350ambBumperFront"] = "FrontBumper0",
			["Base.90fordF350ambBullbarFront"] = "FrontBumper1",
			["Base.90fordF350ambReinforcedBumperFront"] = "FrontBumper2",
		},
		default = "first",
	},
	["RearBumper"] = {
		partId = "DAMNBumperRear",
		itemToModel = {
			["Base.90fordF350ambBumperRear"] = "RearBumper",
		},
		default = "first",
	},
	["WindshieldArmor"] = {
		partId = "DAMNWindshieldArmor",
		itemToModel = {
			["Base.90fordF350ambWindshieldArmor"] = "winda",
		},
	},
	["WindowFrontLeftArmor"] = {
		partId = "DAMNFrontLeftArmor",
		itemToModel = {
			["Base.90fordF350ambWindowFrontArmor"] = "leftwina",
		},
	},
	["WindowFrontRightArmor"] = {
		partId = "DAMNFrontRightArmor",
		itemToModel = {
			["Base.90fordF350ambWindowFrontArmor"] = "rightwina",
		},
	},
	["WindowRearRightArmor"] = {
		partId = "DAMNRearRightArmor",
		itemToModel = {
			["Base.90fordF350ambWindowRearArmor"] = "rightrearwina",
		},
	},
	["WindshieldRearArmor"] = {
		partId = "DAMNWindshieldRearArmor",
		itemToModel = {
			["Base.90fordF350ambWindshieldRearArmor"] = "rearwina",
		},
	},
	["Sidesteps"] = {
		partId = "DAMNSideSteps",
		itemToModel = {
			["Base.90fordF350ambSidesteps2"] = "Sidesteps",
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