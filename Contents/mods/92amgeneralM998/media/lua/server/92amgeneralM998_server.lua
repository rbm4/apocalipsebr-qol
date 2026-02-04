require "DAMN_Parts";
require "DAMN_Spawns";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

DAMN.Parts:processConfigV2("M998", {
	["Bullbar"] = {
		partId = "M998Bullbar",
		itemToModel = {
			["Base.M998Bullbar1_Item"] = "Bullbar1",
			["Base.M998Bullbar2_Item"] = "Bullbar2",
		},
		default = "trve_random",
		noPartChance = 33,
	},
	["DoorFrontLeftArmor"] = {
		partId = "M998DoorFrontLeftArmor",
		itemToModel = {
			["Base.M998CarFrontDoorArmor1_Item"] = "DoorFrontLeftArmor1",
		},
	},
	["DoorFrontRightArmor"] = {
		partId = "M998DoorFrontRightArmor",
		itemToModel = {
			["Base.M998CarFrontDoorArmor1_Item"] = "DoorFrontRightArmor1",
		},
	},
	["DoorRearLeftArmor"] = {
		partId = "M998DoorRearLeftArmor",
		itemToModel = {
			["Base.M998CarRearDoorArmor1_Item"] = "DoorRearLeftArmor1",
		},
	},
	["DoorRearRightArmor"] = {
		partId = "M998DoorRearRightArmor",
		itemToModel = {
			["Base.M998CarRearDoorArmor1_Item"] = "DoorRearRightArmor1",
		},
	},
	["WindshieldArmor"] = {
		partId = "M998WindshieldArmor",
		itemToModel = {
			["Base.M998WindshieldArmor1_Item"] = "WindshieldArmor1",
            ["Base.M998WindshieldArmor2_Item"] = "WindshieldArmor2",
		},
	},
	["SpareTire"] = {
		partId = "M998SpareTire",
		itemToModel = {
			["runFlat.SmallTire"] = {"SpareTire1", "SpareTire1Mount"},
            ["Base.V101Tire2"] = {"SpareTire2", "SpareTire1Mount2"},
		},
		default = "trve_random",
		noPartChance = 50,
	},
	["Roofrack"] = {
		partId = "M998Roofrack",
		itemToModel = {
			["Base.M998Roofrack1_Item"] = "Roofrack1",
		},
		default = "trve_random",
		noPartChance = 95,
	},
	["Mudflaps"] = {
		partId = "M998Mudflaps",
		itemToModel = {
			["Base.M998Mudflaps1_Item"] = "Mudflaps1",
		},
		default = "trve_random",
		noPartChance = 25,
	},
    ["Muffler"] = {
		partId = "M998Muffler",
		itemToModel = {
			["Base.M998Muffler1_Item"] = "Muffler1",
            ["Base.M998Muffler2_Item"] = "Muffler2",
		},
		default = "random",
	},
    ["BackCover"] = {
		partId = "M998BackCover",
		itemToModel = {
			["Base.M998BackCover1_Item"] = "BackCover1",
		},
		default = "first",
	},
    ["TrunkBarrier"] = {
		partId = "M998TrunkBarrier",
		itemToModel = {
			["Base.M998TrunkBarrier1_Item"] = "TrunkBarrier1",
            ["Base.M998TrunkBarrier2_Item"] = "TrunkBarrier2",
		},
		default = "trve_random",
		noPartChance = 33,
	},
});

DAMN.Parts:processConfigV2("M101A3", {
	["Cover"] = {
		partId = "M101A3Cover",
		itemToModel = {
			["Base.M101A3Cover1_Item"] = "Cover1",
		},
        default = "first",
	},
	["Tarp"] = {
		partId = "M101A3Tarp",
		itemToModel = {
			["Base.M101A3Tarp1_Item"] = "Tarp1",
            ["Base.KI5trailersTarp2"] = "Tarp2",
		},
	},
	["Spare"] = {
		partId = "M101A3Spare",
		itemToModel = {
            ["runFlat.SmallTire"] = {"SpareTire1", "SpareTire1Mount"},
            ["Base.V101Tire2"] = {"SpareTire2", "SpareTire1Mount2"},
		},
        default = "trve_random",
		noPartChance = 33,
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
