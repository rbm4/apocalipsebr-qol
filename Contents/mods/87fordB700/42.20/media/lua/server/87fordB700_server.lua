require "DAMN_Parts";
require "DAMN_Spawns";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

DAMN.Parts:processConfigV2("B700", {
	["BumperFront"] = {
		partId = "DAMNBumperFront",
		itemToModel = {
			["Base.87fordB700BumperFront0"] = "BumperFront0",
			["Base.87fordB700BumperFrontA"] = "BumperFrontA",
			["Base.87fordB700BullbarFrontA"] = "BullbarFrontA",
		},
		default = "first",
	},
    ["BumperFrontF"] = {
		partId = "DAMNBumperFront",
		itemToModel = {
			["Base.87fordF700BumperFront0"] = "BumperFrontASW",
			["Base.87fordF700BullbarFrontA"] = "BullbarFrontASW",
		},
		default = "random",
	},
	["BumperRear"] = {
		partId = "DAMNBumperRear",
		itemToModel = {
			["Base.87fordB700BumperRear0"] = "BumperRear0",
		},
		default = "trve_random",
		noPartChance = 5,
	},
    ["BumperRearX"] = {
		partId = "DAMNBumperRear",
		itemToModel = {
			["Base.87fordF700BumperRear1"] = "BumperRear1",
		},
		default = "trve_random",
		noPartChance = 25,
	},
	["WindshieldArmor"] = {
		partId = "DAMNWindshieldArmor",
		itemToModel = {
			["Base.87fordB700WindshieldArmor"] = "B700winda",
		},
	},
	["DoorFrontRightArmor"] = {
		partId = "DAMNFrontRightArmor",
		itemToModel = {
			["Base.87fordB700DoubleDoorArmor"] = "B700doorfra",
		},
	},
	["FrontLeftArmor"] = {
		partId = "DAMNFrontLeftArmor",
		itemToModel = {
			["Base.87fordB700SideArmor"] = "B700winfla",
		},
	},
	["FrontRightArmor"] = {
		partId = "DAMNFrontRightArmor",
		itemToModel = {
			["Base.87fordB700SideArmor"] = "B700winfra",
			["Base.87fordB700SideArmorPrison"] = "B700winfrap",
		},
	},
	["RearLeftArmor"] = {
		partId = "DAMNRearLeftArmor",
		itemToModel = {
			["Base.87fordB700SideArmor"] = "B700winrla",
			["Base.87fordB700SideArmorPrison"] = "B700winrlap",
		},
	},
	["RearRightArmor"] = {
		partId = "DAMNRearRightArmor",
		itemToModel = {
			["Base.87fordB700SideArmor"] = "B700winrla",
			["Base.87fordB700SideArmorPrison"] = "B700winrlap",
		},
	},
	["SideLeftArmor"] = {
		partId = "B700SideLeftArmor",
		itemToModel = {
			["Base.87fordB700LargeSideArmor"] = "B700sidela",
			["Base.87fordB700LargeSideArmorPrison"] = "B700sidelap",
		},
	},
	["SideRightArmor"] = {
		partId = "B700SideRightArmor",
		itemToModel = {
			["Base.87fordB700LargeSideArmor"] = "B700sidera",
			["Base.87fordB700LargeSideArmorPrison"] = "B700siderap",
		},
	},
	["RearArmor"] = {
		partId = "B700RearArmor",
		itemToModel = {
			["Base.87fordB700RearArmor"] = "B700ra",
		},
	},
	["Roofrack"] = {
		partId = "B700Roofrack",
		itemToModel = {
			["Base.87fordB700Roofrack2"] = "B700Roofrack0",
		},
	},
	["SpareTireOne"] = {
		partId = "B700SpareTireOne",
		itemToModel = {
			["Base.87fordB700Tire2"] = "B700Spare",
		},
	},
	["SpareTireTwo"] = {
		partId = "B700SpareTireTwo",
		itemToModel = {
			["Base.87fordB700Tire2"] = "B700Spare",
		},
	},
	["FrontRightArmorPrison"] = {
		partId = "DAMNFrontRightArmor",
		itemToModel = {
			["Base.87fordB700SideArmorPrison"] = "B700winfrap",
			["Base.87fordB700SideArmorPrison"] = "B700winfrap",
		},
		default = "first",
	},
	["RearLeftArmorPrison"] = {
		partId = "DAMNRearLeftArmor",
		itemToModel = {
			["Base.87fordB700SideArmorPrison"] = "B700winrlap",
			["Base.87fordB700SideArmor"] = "B700winrla",
		},
		default = "first",
	},
	["RearRightArmorPrison"] = {
		partId = "DAMNRearRightArmor",
		itemToModel = {
			["Base.87fordB700SideArmorPrison"] = "B700winrrap",
			["Base.87fordB700SideArmor"] = "B700winrra",
		},
		default = "first",
	},
	["SideLeftArmorPrison"] = {
		partId = "B700SideLeftArmor",
		itemToModel = {
			["Base.87fordB700LargeSideArmorPrison"] = "B700sidelap",
			["Base.87fordB700LargeSideArmor"] = "B700sidela",
		},
		default = "first",
	},
	["SideRightArmorPrison"] = {
		partId = "B700SideRightArmor",
		itemToModel = {
			["Base.87fordB700LargeSideArmorPrison"] = "B700siderap",
			["Base.87fordB700LargeSideArmor"] = "B700sidera",
		},
		default = "first",
	},
    ["WindshieldArmorX"] = {
		partId = "DAMNWindshieldArmor",
		itemToModel = {
			["Base.87fordF700WindshieldArmor"] = "B700winda",
		},
	},
    ["FrontLeftArmorX"] = {
		partId = "DAMNFrontLeftArmor",
		itemToModel = {
			["Base.87fordF700WindowFrontArmor"] = "B700leftwina",
		},
	},
    ["FrontRightArmorX"] = {
		partId = "DAMNFrontRightArmor",
		itemToModel = {
			["Base.87fordF700WindowFrontArmor"] = "B700rightwina",
		},
	},
    ["RoofLights"] = {
		partId = "B700RoofLights",
		itemToModel = {
			["Base.87fordF700RoofLights2"] = "B700RoofLights0",
		},
		default = "trve_random",
		noPartChance = 25,
	},
});


DAMN.Spawns:add("Base.87fordB700school", 10638, 9967, {
    direction = IsoDirections.S, 
    chance = 30,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700school", 2932, 9115, {
    direction = IsoDirections.N, 
    chance = 28,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700school", 12346, 3291, {
    direction = IsoDirections.W, 
    chance = 29,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700school", 13606, 2760, {
    direction = IsoDirections.S, 
    chance = 31,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700school", 13058, 1741, {
    direction = IsoDirections.S, 
    chance = 28,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700school", 10002, 12695, {
    direction = IsoDirections.W, 
    chance = 29,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700prison", 6421, 5413, {
    direction = IsoDirections.E, 
    chance = 20,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700prison", 7824, 11881, {
    direction = IsoDirections.W, 
    chance = 30,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700military", 8353, 11586, {
    direction = IsoDirections.E, 
    chance = 28,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700military", 8332, 11587, {
    direction = IsoDirections.E, 
    chance = 25,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700military", 12516, 4206, {
    direction = IsoDirections.S, 
    chance = 30,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordF700box", 10628, 10647, {
    direction = IsoDirections.S, 
    chance = 70,
    sandboxVar = "AllowMcBoxySpawns",
});

DAMN.Spawns:add("Base.87fordF700box", 10715, 9808, {
    direction = IsoDirections.N, 
    chance = 30,
    skinIndex = 4,
    sandboxVar = "AllowMcBoxySpawns",
});

DAMN.Spawns:add("Base.87fordF700box", 13123, 1743, {
    direction = IsoDirections.E, 
    chance = 25,
    skinIndex = 4,
    sandboxVar = "AllowMcBoxySpawns",
});

DAMN.Spawns:add("Base.87fordF700box", 13059, 1650, {
    direction = IsoDirections.W, 
    chance = 50,
    skinIndex = 3,
    sandboxVar = "AllowMcBoxySpawns",
});

DAMN.Spawns:add("Base.87fordF700box", 10632, 9652, {
    direction = IsoDirections.S, 
    chance = 36,
    skinIndex = 3,
    sandboxVar = "AllowMcBoxySpawns",
});

DAMN.Spawns:add("Base.87fordF700box", 13309, 1340, {
    direction = IsoDirections.E, 
    chance = 30,
    skinIndex = 3,
    sandboxVar = "AllowMcBoxySpawns",
});

DAMN.Spawns:add("Base.87fordF700box", 14005, 5800, {
    direction = IsoDirections.E, 
    chance = 80,
    sandboxVar = "AllowMcBoxySpawns",
});

DAMN.Spawns:add("Base.87fordF700bank", 12591, 1707, {
    direction = IsoDirections.S, 
    chance = 50,
    skinIndex = 2,
    sandboxVar = "AllowCashcowSpawns",
});

DAMN.Spawns:add("Base.87fordF700bank", 13435, 1359, {
    direction = IsoDirections.N, 
    chance = 50,
    skinIndex = 2,
    sandboxVar = "AllowCashcowSpawns",
});

DAMN.Spawns:add("Base.87fordF700bank", 12641, 1572, {
    direction = IsoDirections.N, 
    chance = 40,
    skinIndex = 2,
    sandboxVar = "AllowCashcowSpawns",
});

DAMN.Spawns:add("Base.87fordF700bank", 13585, 3029, {
    direction = IsoDirections.s, 
    chance = 30,
    skinIndex = 2,
    sandboxVar = "AllowCashcowSpawns",
});

DAMN.Spawns:add("Base.87fordF700swat", 5591, 12483, {
    direction = IsoDirections.W, 
    chance = 80,
    skinIndex = 2,
    sandboxVar = "AllowChonkerSpawns",
});

DAMN.Spawns:add("Base.87fordF700swat", 12514, 4145, {
    direction = IsoDirections.S, 
    chance = 60,
    skinIndex = 2,
    sandboxVar = "AllowChonkerSpawns",
});

DAMN.Spawns:add("Base.87fordF700swat", 8066, 11752, {
    direction = IsoDirections.S, 
    chance = 21,
    skinIndex = 1,
    sandboxVar = "AllowChonkerSpawns",
});

function B700.ContainerAccess.Blank(vehicle, part, chr)
--
end

function B700.stahp(player)
    local vehicle = player.getVehicle and player:getVehicle() or nil
        if (vehicle and string.find( vehicle:getScriptName(), "87fordB700school" )) then

            local part = vehicle:getPartById("B700StopSign")
            local opened = part:getDoor():isOpen()
            local activeLights = vehicle:getLightbarLightsMode() > 0

            if activeLights and opened then return end

            if not activeLights and opened then
                vehicle:playPartAnim(part, "Close")
                vehicle:playPartSound(part, player, "Close")
                part:getDoor():setOpen(false)
                vehicle:transmitPartDoor(part)
            elseif activeLights and not opened then
                vehicle:playPartAnim(part, "Open")
                vehicle:playPartSound(part, player, "Open")
                part:getDoor():setOpen(true)
                vehicle:transmitPartDoor(part)
            end
        end
end

function B700.ContainerAccess.TrunkX(vehicle, part, chr)
	if chr:getVehicle() then return false end
	if not vehicle:isInArea(part:getArea(), chr) then return false end
	local Trunk = vehicle:getPartById("TrunkDoor")
	if Trunk and Trunk:getDoor() then
		if not Trunk:getInventoryItem() then return true end
		if not Trunk:getDoor():isOpen() then return false end
	end
	--
	return true
end

function B700.ContainerAccess.TrunkLeft(vehicle, part, chr)
	if chr:getVehicle() then return false end
	if not vehicle:isInArea(part:getArea(), chr) then return false end
	local TrunkLeft = vehicle:getPartById("StorageLidLeft")
	if TrunkLeft and TrunkLeft:getDoor() then
		if not TrunkLeft:getInventoryItem() then return true end
		if not TrunkLeft:getDoor():isOpen() then return false end
	end
	--
	return true
end

function B700.ContainerAccess.TrunkRight(vehicle, part, chr)
	if chr:getVehicle() then return false end
	if not vehicle:isInArea(part:getArea(), chr) then return false end
	local TrunkRight = vehicle:getPartById("StorageLidRight")
	if TrunkRight and TrunkRight:getDoor() then
		if not TrunkRight:getInventoryItem() then return true end
		if not TrunkRight:getDoor():isOpen() then return false end
	end
	--
	return true
end

function B700.ContainerAccess.GloveBox(vehicle, part, chr)
	if chr:getVehicle() == vehicle then
		local seat = vehicle:getSeat(chr)
		return seat == 1 or seat == 0;
	elseif chr:getVehicle() then
		return false
	end
end

function B700.ContainerAccess.Guncabinet(vehicle, part, chr)
    if chr:getVehicle() == vehicle then
		local seat = vehicle:getSeat(chr)
		return seat >= 0;
	elseif chr:getVehicle() then
		return false
	else
		if not vehicle:isInArea("SeatRearRight", chr) then return false end
		local doorPart = vehicle:getPartById("DoorRearRight")
		if doorPart and doorPart:getDoor() and not doorPart:getDoor():isOpen() then
			return false
		end
		return true
	end
end

Events.OnPlayerUpdate.Add(B700.stahp);