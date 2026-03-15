require "DAMN_Parts";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

DAMN.Parts:processConfigV2("DEF89", {
	["BumperFront"] = {
		partId = "DAMNBumperFront",
		itemToModel = {
			["Base.89defenderBumperFront0"] = "FrontBumper0",
			["Base.89defenderBullbarFrontA"] = "FrontBullbarA",
		},
		default = "trve_random",
		noPartChance = 33,
	},
	["BumperRear110"] = {
		partId = "DAMNBumperRear",
		itemToModel = {
			["Base.89defenderBumperRear0"] = "RearBumper110",
            ["Base.89defenderWolfBumperettes0"] = "RearBumperWolf",
		},
		allowedForRandom = {
            "Base.89defenderBumperRear0"
        },
		default = "trve_random",
		noPartChance = 5,
	},
    ["BumperRearW"] = {
		partId = "DAMNBumperRear",
		itemToModel = {
			["Base.89defenderBumperRear0"] = "RearBumper110",
            ["Base.89defenderWolfBumperettes0"] = "RearBumperWolf",
		},
		allowedForRandom = {
            "Base.89defenderWolfBumperettes0"
        },
		default = "trve_random",
		noPartChance = 5,
	},
    ["BumperRear130"] = {
		partId = "DAMNBumperRear",
		itemToModel = {
			["Base.89defender130Bumperettes0"] = "RearBumper130",
		},
		default = "trve_random",
		noPartChance = 50,
	},
	["SidestepsShort"] = {
		partId = "DAMNSideSteps",
		itemToModel = {
			["Base.89defenderSidestepsShort2"] = "DEF89step0",
		},
		default = "trve_random",
		noPartChance = 45,
	},
	["SidestepsLong"] = {
		partId = "DAMNSideSteps",
		itemToModel = {
			["Base.89defenderSidestepsLong2"] = "DEF89step1",
		},
		default = "trve_random",
		noPartChance = 45,
	},
	["Mudflaps"] = {
		partId = "DAMNMudflaps",
		itemToModel = {
			["Base.89defenderMudflaps2"] = "DEF89MudflapsFront",
		},
		default = "trve_random",
		noPartChance = 35,
	},
	["TruckBedAddons130"] = {
        partId = "DEF89TruckBedAddon",
        itemToModel = {
            ["Base.89defenderRollbarWithToolbox2"] = "DEF89Rollbar",
            ["Base.89defenderTarpCover2"] = {
                "DEF89TarpCoverLid", "DEF89TarpCover"
            },
            ["Base.89defenderHardCover2"] = {
                "DEF89HardCoverLid", "DEF89HardCover"
            },
        },
        default = "random",
    },
    ["Snorkel"] = {
		partId = "DAMNSnorkel",
		itemToModel = {
			["Base.89defenderSnorkel2"] = "DEF89Snorkel",
            ["Base.89defenderWolfSnorkel2"] = "DEF89Snorkel2",
		},
		default = "trve_random",
		noPartChance = 50,
	},
    ["SnorkelW"] = {
		partId = "DAMNSnorkel",
		itemToModel = {
			["Base.89defenderSnorkel2"] = "DEF89Snorkel",
            ["Base.89defenderWolfSnorkel2"] = "DEF89Snorkel2",
		},
		default = "Base.89defenderWolfSnorkel2",
	},
    ["Roof"] = {
		partId = "DEF89Roof",
		itemToModel = {
			["Base.89defenderWolfHardCover2"] = "DEF89RoofH",
            ["Base.89defenderWolfTarpCover2"] = "DEF89RoofS",
		},
		default = "trve_random",
		noPartChance = 1,
	},
	["SpareTire"] = {
		partId = "DAMNSpareTire",
		itemToModel = {
			["Base.89defenderTire2"] = "DEF89SpareTire0",
            ["Base.89defenderDakarTire2"] = "DEF89SpareTire1",
            ["Base.89defenderMilitaryTire2"] = "DEF89SpareTire2",
            ["damnCraft.SmallTire2"] = "DEF89SpareTire3",
		},
		default = "trve_random",
		noPartChance = 25,
	},
    ["SpareTire2"] = {
		partId = "DAMNSpareTire2",
		itemToModel = {
			["Base.89defenderTire2"] = "DEF89SpareTire0",
            ["Base.89defenderDakarTire2"] = "DEF89SpareTire1",
            ["Base.89defenderMilitaryTire2"] = "DEF89SpareTire2",
            ["damnCraft.SmallTire2"] = "DEF89SpareTire3",
		},
		default = "Base.89defenderMilitaryTire2",
	},
	["SpareTireT"] = {
		partId = "DAMNSpareTire",
		itemToModel = {
			["Base.89defenderTire2"] = "DEF89SpareTireT1",
            ["Base.89defenderDakarTire2"] = "DEF89SpareTireT2",
            ["Base.89defenderMilitaryTire2"] = "DEF89SpareTire3",
            ["damnCraft.SmallTire2"] = "DEF89SpareTireT4",
		},
		default = "trve_random",
		noPartChance = 25,
	},
	["RoofrackM"] = {
		partId = "DEF89Roofrack",
		itemToModel = {
			["Base.89defenderRoofrackM2"] = "DEF89RoofrackM",
		},
	},
	["WindshieldArmor"] = {
		partId = "DAMNWindshieldArmor",
		itemToModel = {
			["Base.89defenderWindshieldArmor"] = "DEF89winda0",
		},
	},
	["WindshieldRearArmor"] = {
		partId = "DAMNWindshieldRearArmor",
		itemToModel = {
			["Base.89defenderWindshieldRearArmor"] = "DEF89windra",
		},
	},
	["FrontLeftArmor"] = {
		partId = "DAMNFrontLeftArmor",
		itemToModel = {
			["Base.89defenderFrontWindowArmor"] = "DEF89leftdoora",
		},
	},
	["FrontRightArmor"] = {
		partId = "DAMNFrontRightArmor",
		itemToModel = {
			["Base.89defenderFrontWindowArmor"] = "DEF89rightdoora",
		},
	},
	["RearLeftArmor"] = {
		partId = "DAMNRearLeftArmor",
		itemToModel = {
			["Base.89defenderRearWindowArmor"] = "DEF89leftdoorra",
		},
	},
	["RearRightArmor"] = {
		partId = "DAMNRearRightArmor",
		itemToModel = {
			["Base.89defenderRearWindowArmor"] = "DEF89rightdoorra",
		},
	},
	["BackLeftArmor"] = {
		partId = "DAMNBackLeftArmor",
		itemToModel = {
			["Base.89defenderBackWindowArmor"] = "DEF89leftwindowba",
		},
	},
	["BackRightArmor"] = {
		partId = "DAMNBackRightArmor",
		itemToModel = {
			["Base.89defenderBackWindowArmor"] = "DEF89rightwindowba",
		},
	},
    ["TireFrontLeft"] = {
		partId = "TireFrontLeft",
		itemToModel = {
            ["Base.89defenderTire2"] = "Tire0",
            ["Base.89defenderDakarTire2"] = "Tire1",
            ["Base.89defenderMilitaryTire2"] = "Tire2",
            ["damnCraft.SmallTire2"] = "Tire3",
		},
	},
	["TireFrontRight"] = {
		partId = "TireFrontRight",
		itemToModel = {
            ["Base.89defenderTire2"] = "Tire0",
            ["Base.89defenderDakarTire2"] = "Tire1",
            ["Base.89defenderMilitaryTire2"] = "Tire2",
            ["damnCraft.SmallTire2"] = "Tire3",
		},
	},
	["TireRearLeft"] = {
		partId = "TireRearLeft",
		itemToModel = {
            ["Base.89defenderTire2"] = "Tire0",
            ["Base.89defenderDakarTire2"] = "Tire1",
            ["Base.89defenderMilitaryTire2"] = "Tire2",
            ["damnCraft.SmallTire2"] = "Tire3",
		},
	},
	["TireRearRight"] = {
		partId = "TireRearRight",
		itemToModel = {
            ["Base.89defenderTire2"] = "Tire0",
            ["Base.89defenderDakarTire2"] = "Tire1",
            ["Base.89defenderMilitaryTire2"] = "Tire2",
            ["damnCraft.SmallTire2"] = "Tire3",
		},
	},
    ["TireFrontLeftW"] = {
		partId = "TireFrontLeft",
		itemToModel = {
            ["Base.89defenderTire2"] = "Tire0",
            ["Base.89defenderDakarTire2"] = "Tire1",
            ["Base.89defenderMilitaryTire2"] = "Tire2",
            ["damnCraft.SmallTire2"] = "Tire3",
		},
        default = "Base.89defenderMilitaryTire2",
	},
	["TireFrontRightW"] = {
		partId = "TireFrontRight",
		itemToModel = {
            ["Base.89defenderTire2"] = "Tire0",
            ["Base.89defenderDakarTire2"] = "Tire1",
            ["Base.89defenderMilitaryTire2"] = "Tire2",
            ["damnCraft.SmallTire2"] = "Tire3",
		},
        default = "Base.89defenderMilitaryTire2",
	},
	["TireRearLeftW"] = {
		partId = "TireRearLeft",
		itemToModel = {
            ["Base.89defenderTire2"] = "Tire0",
            ["Base.89defenderDakarTire2"] = "Tire1",
            ["Base.89defenderMilitaryTire2"] = "Tire2",
            ["damnCraft.SmallTire2"] = "Tire3",
		},
        default = "Base.89defenderMilitaryTire2",
	},
	["TireRearRightW"] = {
		partId = "TireRearRight",
		itemToModel = {
            ["Base.89defenderTire2"] = "Tire0",
            ["Base.89defenderDakarTire2"] = "Tire1",
            ["Base.89defenderMilitaryTire2"] = "Tire2",
            ["damnCraft.SmallTire2"] = "Tire3",
		},
        default = "Base.89defenderMilitaryTire2",
	},
});

function DEF89.WindshieldVents(player)
    local vehicle = player.getVehicle and player:getVehicle() or nil
    if not vehicle then return end

    if string.find(vehicle:getScriptName(), "89defender") then
        local part = vehicle:getPartById("DEF89Vents")
        local opened = part:getDoor():isOpen()
        local heater = vehicle:getPartById("Heater")
        local modData = heater:getModData()
        local active = modData.active  
        local temperature = tonumber(modData.temperature) or 0

        local coolingON = active and temperature < 0 

        if coolingON and not opened then
            vehicle:playPartAnim(part, "Open")
            vehicle:playPartSound(part, player, "Open")
            part:getDoor():setOpen(true)
            vehicle:transmitPartDoor(part)
        elseif not coolingON and opened then
            vehicle:playPartAnim(part, "Close")
            vehicle:playPartSound(part, player, "Close")
            part:getDoor():setOpen(false) 
            vehicle:transmitPartDoor(part)
        end
    end
end

Events.OnPlayerUpdate.Add(DEF89.WindshieldVents)
