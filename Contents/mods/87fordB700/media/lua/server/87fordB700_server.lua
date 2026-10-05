require "DAMN_Parts";
require "DAMN_Spawns";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

DAMN.Parts:processConfigV2("B700", {
	["BumperFront"] = {
		partId = "B700BumperFront",
		itemToModel = {
			["Base.87fordB700BumperFront0"] = "BumperFront0",
			["Base.87fordB700BumperFrontA"] = "BumperFrontA",
			["Base.87fordB700BullbarFrontA"] = "BullbarFrontA",
		},
		default = "first",
	},
    ["BumperFrontF"] = {
		partId = "B700BumperFront",
		itemToModel = {
			["Base.87fordF700BumperFront0"] = "BumperFrontASW",
			["Base.87fordF700BullbarFrontA"] = "BullbarFrontASW",
		},
		default = "random",
	},
	["BumperRear"] = {
		partId = "B700BumperRear",
		itemToModel = {
			["Base.87fordB700BumperRear0"] = "BumperRear0",
		},
		default = "trve_random",
		noPartChance = 5,
	},
    ["BumperRearX"] = {
		partId = "B700BumperRear",
		itemToModel = {
			["Base.87fordF700BumperRear1"] = "BumperRear1",
		},
		default = "trve_random",
		noPartChance = 25,
	},
	["WindshieldArmor"] = {
		partId = "B700WindshieldArmor",
		itemToModel = {
			["Base.87fordB700WindshieldArmor"] = "B700winda",
		},
	},
	["DoorFrontRightArmor"] = {
		partId = "B700DoorFrontRightArmor",
		itemToModel = {
			["Base.87fordB700DoubleDoorArmor"] = "B700doorfra",
		},
	},
	["FrontLeftArmor"] = {
		partId = "B700FrontLeftArmor",
		itemToModel = {
			["Base.87fordB700SideArmor"] = "B700winfla",
		},
	},
	["FrontRightArmor"] = {
		partId = "B700FrontRightArmor",
		itemToModel = {
			["Base.87fordB700SideArmor"] = "B700winfra",
			["Base.87fordB700SideArmorPrison"] = "B700winfrap",
		},
	},
	["RearLeftArmor"] = {
		partId = "B700RearLeftArmor",
		itemToModel = {
			["Base.87fordB700SideArmor"] = "B700winrla",
			["Base.87fordB700SideArmorPrison"] = "B700winrlap",
		},
	},
	["RearRightArmor"] = {
		partId = "B700RearRightArmor",
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
		partId = "B700FrontRightArmor",
		itemToModel = {
			["Base.87fordB700SideArmorPrison"] = "B700winfrap",
			["Base.87fordB700SideArmorPrison"] = "B700winfrap",
		},
		default = "first",
	},
	["RearLeftArmorPrison"] = {
		partId = "B700RearLeftArmor",
		itemToModel = {
			["Base.87fordB700SideArmorPrison"] = "B700winrlap",
			["Base.87fordB700SideArmor"] = "B700winrla",
		},
		default = "first",
	},
	["RearRightArmorPrison"] = {
		partId = "B700RearRightArmor",
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
		partId = "B700WindshieldArmor",
		itemToModel = {
			["Base.87fordF700WindshieldArmor"] = "B700winda",
		},
	},
    ["FrontLeftArmorX"] = {
		partId = "B700FrontLeftArmor",
		itemToModel = {
			["Base.87fordF700WindowFrontArmor"] = "B700leftwina",
		},
	},
    ["FrontRightArmorX"] = {
		partId = "B700FrontRightArmor",
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


DAMN.Spawns:add("Base.87fordB700school", 10604, 9973, {
    direction = IsoDirections.S, 
    chance = 40,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700school", 11755, 6936, {
    direction = IsoDirections.W, 
    chance = 30,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700school", 6433, 5413, {
    direction = IsoDirections.E, 
    chance = 28,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700school", 6415, 5413, {
    direction = IsoDirections.E, 
    chance = 25,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700school", 13608, 2762, {
    direction = IsoDirections.S, 
    chance = 23,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700school", 13608, 2749, {
    direction = IsoDirections.S, 
    chance = 23,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700prison", 7725, 11780, {
    direction = IsoDirections.W, 
    chance = 40,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700prison", 13783, 1268, {
    direction = IsoDirections.N, 
    chance = 60,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700military", 10080, 12769, {
    direction = IsoDirections.E, 
    chance = 40,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700military", 12516, 4173, {
    direction = IsoDirections.S, 
    chance = 30,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordB700military", 12516, 4206, {
    direction = IsoDirections.S, 
    chance = 30,
    sandboxVar = "AllowMrBusSpawns",
});

DAMN.Spawns:add("Base.87fordF700box", 10625, 10638, {
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

DAMN.Spawns:add("Base.87fordF700box", 13059, 1649, {
    direction = IsoDirections.W, 
    chance = 50,
    skinIndex = 3,
    sandboxVar = "AllowMcBoxySpawns",
});

DAMN.Spawns:add("Base.87fordF700box", 10623, 9636, {
    direction = IsoDirections.W, 
    chance = 36,
    skinIndex = 3,
    sandboxVar = "AllowMcBoxySpawns",
});

DAMN.Spawns:add("Base.87fordF700box", 13306, 1337, {
    direction = IsoDirections.E, 
    chance = 30,
    skinIndex = 3,
    sandboxVar = "AllowMcBoxySpawns",
});

DAMN.Spawns:add("Base.87fordF700box", 14004, 5800, {
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

DAMN.Spawns:add("Base.87fordF700bank", 6491, 5291, {
    direction = IsoDirections.N, 
    chance = 40,
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

DAMN.Spawns:add("Base.87fordF700swat", 8065, 11750, {
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

function B700.ContainerAccess.Trunk(vehicle, part, chr)
	if chr:getVehicle() then return false end
	if not vehicle:isInArea(part:getArea(), chr) then return false end
	local Trunk = vehicle:getPartById("DoorRear")
	if Trunk and Trunk:getDoor() then
		if not Trunk:getInventoryItem() then return true end
		if not Trunk:getDoor():isOpen() then return false end
	end
	--
	return true
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

function B700.ContainerAccess.TrunkF(vehicle, part, chr)
	if chr:getVehicle() == vehicle then
		local seat = vehicle:getSeat(chr)
		return seat >= 0;
	elseif chr:getVehicle() then
		return false
	else
		if not vehicle:isInArea(part:getArea(), chr) then return false end
		local doorPart = vehicle:getPartById("TrunkDoor")
		if doorPart and doorPart:getDoor() and not doorPart:getDoor():isOpen() then
			return false
		end
		return true
	end
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

function B700.ContainerAccess.Roofrack(vehicle, part, chr)
	if chr:getVehicle() then return false end
	if not vehicle:isInArea(part:getArea(), chr) then return false end
	return true
end

function B700.Dismantle2LargeTires(items, result, player, selectedItem)

    local addType = "Base.87fordB700Tire2"
    local tireCond = selectedItem:getCondition();

    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getXp():AddXP(Perks.Mechanics, 4);

end

function B700.ContainerAccess.Gunrack(vehicle, part, chr)
	if chr:getVehicle() == vehicle then
		local seat = vehicle:getSeat(chr)
		return seat == 1 or seat == 0;
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