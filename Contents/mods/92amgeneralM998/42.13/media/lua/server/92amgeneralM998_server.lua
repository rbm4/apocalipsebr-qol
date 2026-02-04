require "DAMN_Parts";
require "DAMN_Spawns";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

DAMN.Parts:processConfigV2("M998", {
	["BumperFront"] = {
		partId = "DAMNBumperFront",
		itemToModel = {
			["Base.92amgeneralM998BullbarA"] = "BullbarA",
			["Base.92amgeneralM998BullbarB"] = "BullbarB",
		},
		default = "trve_random",
		noPartChance = 33,
	},
	["FrontLeftArmor"] = {
		partId = "DAMNFrontLeftArmor",
		itemToModel = {
			["Base.92amgeneralM998FrontArmor"] = "M998leftwina",
		},
	},
	["FrontRightArmor"] = {
		partId = "DAMNFrontRightArmor",
		itemToModel = {
			["Base.92amgeneralM998FrontArmor"] = "M998rightwina",
		},
	},
	["RearLeftArmor"] = {
		partId = "DAMNRearLeftArmor",
		itemToModel = {
			["Base.92amgeneralM998RearArmor"] = "M998leftrearwina",
		},
	},
	["RearRightArmor"] = {
		partId = "DAMNRearRightArmor",
		itemToModel = {
			["Base.92amgeneralM998RearArmor"] = "M998rightrearwina",
		},
	},
	["WindshieldArmor"] = {
		partId = "DAMNWindshieldArmor",
		itemToModel = {
			["Base.92amgeneralM998WindshieldArmor0"] = "M998winda1",
            ["Base.92amgeneralM998WindshieldArmor1"] = "M998winda2",
		},
	},
	["SpareTire"] = {
		partId = "DAMNSpareTire",
		itemToModel = {
			["runFlat.SmallTire"] = {"SpareTire1", "SpareTire1Mount"},
		},
		default = "trve_random",
		noPartChance = 50,
	},
	["Roofrack"] = {
		partId = "M998Roofrack",
		itemToModel = {
			["Base.92amgeneralM998Roofrack"] = "Roofrack1",
		},
		default = "trve_random",
		noPartChance = 95,
	},
	["Mudflaps"] = {
		partId = "DAMNMudflaps",
		itemToModel = {
			["Base.92amgeneralM998Mudflap0"] = "Mudflaps1",
		},
		default = "trve_random",
		noPartChance = 50,
	},
    ["Muffler"] = {
		partId = "M998Muffler",
		itemToModel = {
			["Base.92amgeneralM998Muffler1"] = "Muffler1",
            ["Base.92amgeneralM998Muffler2"] = "Muffler2",
		},
		default = "trve_random",
		noPartChance = 10,
	},
    ["BackCover"] = {
		partId = "M998BackCover",
		itemToModel = {
			["Base.92amgeneralM998BackCover2"] = "BackCover1",
		},
		default = "first",
	},
    ["TrunkBarrier"] = {
		partId = "M998TrunkBarrier",
		itemToModel = {
			["Base.92amgeneralM998TrunkBarrier2"] = "TrunkBarrier1",
            ["Base.92amgeneralM998TrunkBarrier1"] = "TrunkBarrier2",
		},
		default = "trve_random",
		noPartChance = 10,
	},
});

DAMN.Parts:processConfigV2("M101A3", {
	["Cover"] = {
		partId = "M101A3Cover",
		itemToModel = {
			["Base.M101A3Cover2"] = "Cover1",
		},
        default = "first",
	},
	["Tarp"] = {
		partId = "M101A3Tarp",
		itemToModel = {
			["Base.KI5trailersTarp2"] = "Tarp1",
		},
	},
	["SpareTrailer"] = {
		partId = "DAMNSpareTire",
		itemToModel = {
			["runFlat.SmallTire"] = {"SpareM101", "MountM101"},
		},
        default = "trve_random",
		noPartChance = 50,
	},
});

function M101A3.ContainerAccess.TruckBed(vehicle, part, chr)
    if chr:getVehicle() then return false end
    if vehicle:isInArea("TruckBed", chr) then
        local trunkDoor = vehicle:getPartById("TrunkDoor")
        if trunkDoor and trunkDoor:getDoor() then
            if not trunkDoor:getInventoryItem() then return true end
            if not trunkDoor:getDoor():isOpen() then return false end
        end
        return true
    end

    if vehicle:isInArea("TruckBed3", chr) then
        local tarp = vehicle:getPartById("M101A3Tarp")
        local cover = vehicle:getPartById("M101A3Cover")
        if (tarp and tarp:getInventoryItem()) or (cover and cover:getInventoryItem()) then 
            return false
        else
            return true 
        end
    end
    return false
end
