require "DAMN_Parts";
require "DAMN_Spawns";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

DAMN.Parts:processConfigV2("HLX88", {
	["BumperFront"] = {
		partId = "DAMNBumperFront",
		itemToModel = {
			["Base.88toyotaHiluxBumperFront0"] = "FrontBumper0",
			["Base.88toyotaHiluxBullbarFrontA"] = "FrontBullbarA",
		},
		default = "trve_random",
		noPartChance = 5,
	},
	["BumperRear"] = {
		partId = "DAMNBumperRear",
		itemToModel = {
			["Base.88toyotaHiluxBumperRear0"] = "RearBumper0",
			["Base.88toyotaHiluxBullbarRearA"] = "RearBullbarA",
		},
		default = "trve_random",
		noPartChance = 80,
	},
    ["WindshieldArmor"] = {
		partId = "DAMNWindshieldArmor",
		itemToModel = {
			["Base.88toyotaHiluxWindshieldArmor"] = "HLX88windfa",
		},
	},
	["FrontLeftArmor"] = {
		partId = "DAMNFrontLeftArmor",
		itemToModel = {
			["Base.88toyotaHiluxFrontWindowArmor"] = "HLX88winfla",
		},
	},
	["FrontRightArmor"] = {
		partId = "DAMNFrontRightArmor",
		itemToModel = {
			["Base.88toyotaHiluxFrontWindowArmor"] = "HLX88winfra",
		},
	},
    ["BackLeftArmor"] = {
		partId = "DAMNBackLeftArmor",
		itemToModel = {
			["Base.88toyotaHiluxBackWindowArmor"] = "HLX88winbla",
		},
	},
	["BackRightArmor"] = {
		partId = "DAMNBackRightArmor",
		itemToModel = {
			["Base.88toyotaHiluxBackWindowArmor"] = "HLX88winbra",
		},
	},
    ["WindshieldRearArmor"] = {
		partId = "DAMNWindshieldRearArmor",
		itemToModel = {
			["Base.88toyotaHiluxWindshieldRearArmor"] = "HLX88windra",
		},
	},
	["TruckBedExtras"] = {
		partId = "HLX88TruckBedExtras",
		itemToModel = {
			["Base.88toyotaHiluxRollbar2"] = "HLX88Rollbar",
            ["Base.88toyotaHiluxBedCap2"] = "HLX88Cap",
		},
		default = "trve_random",
		noPartChance = 25,
	},
    ["TruckBedExtrasS"] = {
		partId = "HLX88TruckBedExtras",
		itemToModel = {
			["Base.88toyotaHiluxRollbar2"] = "HLX88Rollbar",
            ["Base.88toyotaHiluxBedCap2"] = "HLX88Cap",
		},
		default = "Base.88toyotaHiluxBedCap2",
	},
    ["SideSteps"] = {
		partId = "DAMNSideSteps",
		itemToModel = {
			["Base.88toyotaHiluxSideSteps2"] = "SideSteps0",
		},
		default = "trve_random",
		noPartChance = 50,
	},
    ["Mudflaps"] = {
		partId = "DAMNMudflaps",
		itemToModel = {
			["Base.88toyotaHiluxMudflaps2"] = {"DAMNMudflapsF", "DAMNMudflapsR"},
		},
		default = "trve_random",
		noPartChance = 50,
	},
    ["TireFrontLeft"] = {
		partId = "TireFrontLeft",
		itemToModel = {
            ["Base.88toyotaHiluxTire2"] = "HLX88Tire0",
            ["damnCraft.SmallTire2"] = "HLX88Tire5",
		},
	},
	["TireFrontRight"] = {
		partId = "TireFrontRight",
		itemToModel = {
            ["Base.88toyotaHiluxTire2"] = "HLX88Tire0",
            ["damnCraft.SmallTire2"] = "HLX88Tire5",
		},
	},
	["TireRearLeft"] = {
		partId = "TireRearLeft",
		itemToModel = {
            ["Base.88toyotaHiluxTire2"] = "HLX88Tire0",
            ["damnCraft.SmallTire2"] = "HLX88Tire5",
		},
	},
	["TireRearRight"] = {
		partId = "TireRearRight",
		itemToModel = {
            ["Base.88toyotaHiluxTire2"] = "HLX88Tire0",
            ["damnCraft.SmallTire2"] = "HLX88Tire5",
		},
	},
    ["SpareTire"] = {
		partId = "DAMNSpareTire",
		itemToModel = {
            ["Base.88toyotaHiluxTire2"] = "na",
            ["damnCraft.SmallTire2"] = "na",
		},
        default = "trve_random",
		noPartChance = 50,
	},
    ["SpareTireBed"] = {
		partId = "DAMNSpareTireBed",
		itemToModel = {
            ["Base.88toyotaHiluxTire2"] = "SpareTire",
            ["damnCraft.SmallTire2"] = "SpareTire2",
		},
        default = "trve_random",
		noPartChance = 50,
	},
});