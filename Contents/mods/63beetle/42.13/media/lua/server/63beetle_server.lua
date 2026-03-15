require "DAMN_Parts";
require "DAMN_Spawns";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

DAMN.Parts:processConfigV2("BTL63", {
	["FrontBumper"] = {
		partId = "DAMNBumperFront",
		itemToModel = {
			["Base.63beetleBumperFront0"] = "FrontBumper0",
			["Base.63beetleBumperFront1"] = "FrontBumper1",
			["Base.63beetleBumperFront2"] = "FrontBumper2",
		},
		default = "trve_random",
		noPartChance = 5,
	},
	["FrontBumperOFF"] = {
		partId = "DAMNBumperFront",
		itemToModel = {
			["Base.63beetleBumperFront0"] = "FrontBumper0",
			["Base.63beetleBumperFront1"] = "FrontBumper1",
			["Base.63beetleBumperFront2"] = "FrontBumper2",
		},
	},
	["RearBumper"] = {
		partId = "DAMNBumperRear",
		itemToModel = {
			["Base.63beetleBumperRear0"] = "RearBumper0",
			["Base.63beetleBumperRear1"] = "RearBumper1",
		},
		default = "trve_random",
		noPartChance = 5,
	},
	["RearBumperOFF"] = {
		partId = "DAMNBumperRear",
		itemToModel = {
			["Base.63beetleBumperRear0"] = "RearBumper0",
			["Base.63beetleBumperRear1"] = "RearBumper1",
		},
	},
	["WindshieldArmor"] = {
		partId = "DAMNWindshieldArmor",
		itemToModel = {
			["Base.63beetleWindshieldArmor"] = "BTL63winda",
		},
	},
	["WindshieldRearArmor"] = {
		partId = "DAMNWindshieldRearArmor",
		itemToModel = {
			["Base.63beetleWindshieldRearArmor"] = "BTL63windra",
		},
	},
	["FrontLeftArmor"] = {
		partId = "DAMNFrontLeftArmor",
		itemToModel = {
			["Base.63beetleFrontWindowArmor"] = "BTL63fla",
		},
	},
	["FrontRightArmor"] = {
		partId = "DAMNFrontRightArmor",
		itemToModel = {
			["Base.63beetleFrontWindowArmor"] = "BTL63fra",
		},
	},
	["RearLeftArmor"] = {
		partId = "DAMNRearLeftArmor",
		itemToModel = {
			["Base.63beetleRearWindowArmor"] = "BTL63rla",
		},
	},
	["RearRightArmor"] = {
		partId = "DAMNRearRightArmor",
		itemToModel = {
			["Base.63beetleRearWindowArmor"] = "BTL63rra",
		},
	},
	["SpareTire"] = {
		partId = "DAMNSpareTire",
		itemToModel = {
			["Base.63vwStockTire1"] = "BTL63spare0",
            ["damnCraft.SmallTire1"] = "BTL63spare1",
		},
		default = "trve_random",
		noPartChance = 10,
	},
	["SpareTires"] = {
		partId = "DAMNSpareTire",
		itemToModel = {
			["Base.63vwStockTire1"] = "BTL63spare0",
			["Base.63beetleTireSlick3"] = "BTL63spare1",
            ["damnCraft.SmallTire1"] = "BTL63spare0",
		},
		default = "trve_random",
		noPartChance = 15,
	},
	["SpareTireOffroadA"] = {
		partId = "BTL63SpareA",
		itemToModel = {
			["Base.63beetleTireOffroad2"] = "BTL63spareA",
		},
		default = "trve_random",
		noPartChance = 15,
	},
	["SpareTireOffroadB"] = {
		partId = "BTL63SpareB",
		itemToModel = {
			["Base.63beetleTireOffroad2"] = "BTL63spareB",
		},
		default = "trve_random",
		noPartChance = 15,
	},
	["SpareTireOffroadC"] = {
		partId = "BTL63SpareC",
		itemToModel = {
			["Base.63beetleTireOffroad2"] = "BTL63spareC",
		},
		default = "trve_random",
		noPartChance = 15,
	},
	["SpareTireOffroadD"] = {
		partId = "BTL63SpareD",
		itemToModel = {
			["Base.63beetleTireOffroad2"] = "BTL63spareD",
		},
		default = "trve_random",
		noPartChance = 15,
	},
	["Roofrack"] = {
		partId = "BTL63Roofrack",
		itemToModel = {
			["Base.63beetleRoofrack1"] = "BTL63Roofrack0",
		},
		default = "trve_random",
		noPartChance = 95,
	},
	["BuggySpoiler"] = {
		partId = "DAMNSpoiler",
		itemToModel = {
			["Base.63beetleBuggySpoiler0"] = "BTL63spoilerB",
		},
		default = "trve_random",
		noPartChance = 10,
	},
	["SmallSpoiler"] = {
		partId = "DAMNSpoiler",
		itemToModel = {
			["Base.63beetleSmallSpoiler0"] = "BTL63spoilerS2",
		},
		default = "trve_random",
		noPartChance = 10,
	},
	["SmallSpoilerS"] = {
		partId = "DAMNSpoiler",
		itemToModel = {
			["Base.63beetleSmallSpoiler0"] = "BTL63spoilerS3",
		},
		default = "trve_random",
		noPartChance = 98,
	},
	["Sidesteps"] = {
		partId = "DAMNSideSteps",
		itemToModel = {
			["Base.63beetleSidesteps0"] = "BTL63step0",
		},
		default = "trve_random",
		noPartChance = 5,
	},
	["SidestepsOFF"] = {
		partId = "DAMNSideSteps",
		itemToModel = {
			["Base.63beetleSidesteps0"] = "BTL63step0",
		},
	},
	["Bodykit"] = {
		partId = "BTL63Bodykit",
		itemToModel = {
			["Base.63beetleBodykit0"] = "BTL63kit0",
		},
		default = "trve_random",
		noPartChance = 5,
	},
	["TireFrontLeft"] = {
		partId = "TireFrontLeft",
		itemToModel = {
			["Base.63vwStockTire1"] = "BTL63Tire",
			["Base.63beetleTireSlick3"] = "BTL63TireS",
			["Base.63beetleTireOffroad2"] = "BTL63TireO",
            ["damnCraft.SmallTire1"] = "63beetleuniTireL",
		},
	},
	["TireFrontRight"] = {
		partId = "TireFrontRight",
		itemToModel = {
			["Base.63vwStockTire1"] = "BTL63Tire",
			["Base.63beetleTireSlick3"] = "BTL63TireS",
			["Base.63beetleTireOffroad2"] = "BTL63TireO",
            ["damnCraft.SmallTire1"] = "63beetleuniTireR",
		},
	},
	["TireRearLeft"] = {
		partId = "TireRearLeft",
		itemToModel = {
			["Base.63vwStockTire1"] = "BTL63Tire",
			["Base.63beetleTireSlick3"] = "BTL63TireS",
			["Base.63beetleTireOffroad2"] = "BTL63TireO",
            ["damnCraft.SmallTire1"] = "63beetleuniTireL",
		},
	},
	["TireRearRight"] = {
		partId = "TireRearRight",
		itemToModel = {
			["Base.63vwStockTire1"] = "BTL63Tire",
			["Base.63beetleTireSlick3"] = "BTL63TireS",
			["Base.63beetleTireOffroad2"] = "BTL63TireO",
            ["damnCraft.SmallTire1"] = "63beetleuniTireR",
		},
	},
});