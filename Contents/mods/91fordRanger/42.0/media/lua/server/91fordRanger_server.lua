require "DAMN_Parts";
require "DAMN_Spawns";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

DAMN.Parts:processConfigV2("RNG91", {
	["BumperFront"] = {
		partId = "DAMNBumperFront",
		itemToModel = {
			["Base.91fordRangerBumperFront0"] = "FrontBumper0",
            ["Base.91fordRangerBumperFrontA"] = "FrontBumperA",
			["Base.91fordRangerBullbarFrontA"] = "FrontBullbarA",
		},
		default = "first",
		noPartChance = 5,
	},
    ["BumperFrontPD"] = {
		partId = "DAMNBumperFront",
		itemToModel = {
			["Base.91fordRangerBumperFront0"] = "FrontBumper0",
            ["Base.91fordRangerBumperFrontA"] = "FrontBumperA",
			["Base.91fordRangerBullbarFrontA"] = "FrontBullbarA",
		},
		default = "Base.91fordRangerBumperFrontA",
	},
	["BumperRear"] = {
		partId = "DAMNBumperRear",
		itemToModel = {
			["Base.91fordRangerBumperRear0"] = "RearBumper0",
		},
		default = "trve_random",
		noPartChance = 10,
	},
    ["WindshieldArmor"] = {
		partId = "DAMNWindshieldArmor",
		itemToModel = {
			["Base.91fordRangerWindshieldArmor"] = "RNG91windfa",
		},
	},
	["FrontLeftArmor"] = {
		partId = "DAMNFrontLeftArmor",
		itemToModel = {
			["Base.91fordRangerFrontWindowArmor"] = "RNG91winfla",
		},
	},
	["FrontRightArmor"] = {
		partId = "DAMNFrontRightArmor",
		itemToModel = {
			["Base.91fordRangerFrontWindowArmor"] = "RNG91winfra",
		},
	},
    ["BackLeftArmor"] = {
		partId = "DAMNBackLeftArmor",
		itemToModel = {
			["Base.91fordRangerBackWindowArmor"] = "RNG91winbla",
		},
	},
	["BackRightArmor"] = {
		partId = "DAMNBackRightArmor",
		itemToModel = {
			["Base.91fordRangerBackWindowArmor"] = "RNG91winbra",
		},
	},
	["TruckBedExtras"] = {
		partId = "RNG91TruckBedExtras",
		itemToModel = {
			["Base.91fordRangerRollbar2"] = "RNG91Rollbar",
            ["Base.91fordRangerBedCap2"] = "RNG91Cap",
		},
		default = "trve_random",
		noPartChance = 75,
	},
    ["TruckBedExtrasPD"] = {
		partId = "RNG91TruckBedExtras",
		itemToModel = {
			["Base.91fordRangerRollbar2"] = "RNG91Rollbar",
            ["Base.91fordRangerBedCap2"] = "RNG91Cap",
		},
	},
    ["Mudflaps"] = {
		partId = "DAMNMudflaps",
		itemToModel = {
			["Base.91fordRangerMudflaps2"] = "DAMNMudflapsR",
		},
		default = "trve_random",
		noPartChance = 40,
	},
    ["TireFrontLeft"] = {
		partId = "TireFrontLeft",
		itemToModel = {
            ["Base.91fordRangerTire2"] = "RNG91Tire0",
            ["damnCraft.SmallTire2"] = "RNG91Tire5",
		},
	},
	["TireFrontRight"] = {
		partId = "TireFrontRight",
		itemToModel = {
            ["Base.91fordRangerTire2"] = "RNG91Tire0",
            ["damnCraft.SmallTire2"] = "RNG91Tire5",
		},
	},
	["TireRearLeft"] = {
		partId = "TireRearLeft",
		itemToModel = {
            ["Base.91fordRangerTire2"] = "RNG91Tire0",
            ["damnCraft.SmallTire2"] = "RNG91Tire5",
		},
	},
	["TireRearRight"] = {
		partId = "TireRearRight",
		itemToModel = {
            ["Base.91fordRangerTire2"] = "RNG91Tire0",
            ["damnCraft.SmallTire2"] = "RNG91Tire5",
		},
	},
    ["SpareTire"] = {
		partId = "DAMNSpareTire",
		itemToModel = {
            ["Base.91fordRangerTire2"] = "na",
            ["damnCraft.SmallTire2"] = "na",
		},
        default = "trve_random",
		noPartChance = 50,
	},
});