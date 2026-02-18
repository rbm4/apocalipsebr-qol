require "DAMN_Parts";
require "DAMN_Spawns";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

DAMN.Parts:processConfigV2("KI5TR", {
    ["Tarp"] = {
		partId = "KI5TRTarp",
		itemToModel = {
			["Base.KI5trailersTarp2"] = "Tarp1",
		},
		default = "trve_random",
		noPartChance = 50,
	},
    ["ToolBox"] = {
		partId = "KI5TRToolBox",
		itemToModel = {
			["Base.KI5trailersToolBox2"] = "Toolbox0",
		},
		default = "trve_random",
		noPartChance = 50,
	},
	["SpareTire"] = {
		partId = "KI5TRSpareTire",
		itemToModel = {
			["damnCraft.SmallTire1"] = {"Spare0", "Strap0"},
            ["damnCraft.SmallTire2"] = {"Spare1", "Strap1"},
		},
		default = "trve_random",
		noPartChance = 33,
	},
    ["Mudflaps"] = {
		partId = "KI5TRMudflaps",
		itemToModel = {
			["Base.KI5trailersMudflaps2"] = "Mudflaps1",
		},
		default = "trve_random",
		noPartChance = 50,
	},
    ["GasCanLeft"] = {
		partId = "KI5TRGasCanLeft",
		itemToModel = {
			["USMIL.GasCan0"] = {"StrapGL", "GasCanL"},
            ["USMIL.emptyGasCan0"] = {"StrapGLE", "GasCanLE"},
            ["USMIL.WaterCan0"] = {"StrapWL", "WaterCanL"},
            ["USMIL.emptyWaterCan0"] = {"StrapWLE", "WaterCanLE"},
		},
		default = "trve_random",
		noPartChance = 35,
	},
    ["GasCanRight"] = {
		partId = "KI5TRGasCanRight",
		itemToModel = {
			["USMIL.GasCan0"] = {"StrapGR", "GasCanR"},
            ["USMIL.emptyGasCan0"] = {"StrapGRE", "GasCanRE"},
            ["USMIL.WaterCan0"] = {"StrapWR", "WaterCanR"},
            ["USMIL.emptyWaterCan0"] = {"StrapWRE", "WaterCanRE"},
		},
		default = "trve_random",
		noPartChance = 35,
	},
	["TireFrontLeft"] = {
		partId = "TireFrontLeft",
		itemToModel = {
			["damnCraft.SmallTire1"] = "KI5TRTire0",
            ["damnCraft.SmallTire2"] = "KI5TRTire1",
		},
	},
	["TireFrontRight"] = {
		partId = "TireFrontRight",
		itemToModel = {
			["damnCraft.SmallTire1"] = "KI5TRTire0",
            ["damnCraft.SmallTire2"] = "KI5TRTire1",
		},
	},
	["TireRearLeft"] = {
		partId = "TireRearLeft",
		itemToModel = {
			["damnCraft.SmallTire1"] = "KI5TRTire0",
            ["damnCraft.SmallTire2"] = "KI5TRTire1",
		},
	},
	["TireRearRight"] = {
		partId = "TireRearRight",
		itemToModel = {
			["damnCraft.SmallTire1"] = "KI5TRTire0",
            ["damnCraft.SmallTire2"] = "KI5TRTire1",
		},
	},
    ["FlaresL"] = {
		partId = "KI5TRCFlares",
		itemToModel = {
			["Base.KI5trailersSideFlaresLarge2"] = {"Flares0", "Flares0X"},
		},
		default = "trve_random",
		noPartChance = 65,
	},
    ["FlaresM"] = {
		partId = "KI5TRCFlares",
		itemToModel = {
			["Base.KI5trailersSideFlaresMedium2"] = {"Flares0", "Flares0X"},
		},
		default = "trve_random",
		noPartChance = 65,
	},
    ["FlaresS"] = {
		partId = "KI5TRCFlares",
		itemToModel = {
			["Base.KI5trailersSideFlaresSmall2"] = {"Flares0", "Flares0X"},
		},
		default = "trve_random",
		noPartChance = 65,
	},
});


function KI5TR.ContainerAccess.TruckBed(vehicle, part, chr)
	if chr:getVehicle() then return false end
	if vehicle:isInArea("TruckBed", chr) then
		local trunkDoor = vehicle:getPartById("TrunkDoor")
		if trunkDoor and trunkDoor:getDoor() then
			if not trunkDoor:getInventoryItem() then return true end
			if not trunkDoor:getDoor():isOpen() then return false end
		end
		return true
	end

	if vehicle:isInArea("TruckBed2", chr) then
		local tarp = vehicle:getPartById("KI5TRTarp")
		if tarp and tarp:getInventoryItem() then return false
		else
			return true 
        end
	end
	return false
end

function KI5TR.ContainerAccess.Toolbox(vehicle, part, chr)
	if chr:getVehicle() then return false end
	if not vehicle:isInArea(part:getArea(), chr) then return false end
	return true
end