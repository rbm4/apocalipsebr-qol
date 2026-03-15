require "DAMN_Parts";
require "DAMN_Spawns";

--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

DAMN.Parts:processConfigV2("STP85", {
	["FrontBumper"] = {
		partId = "DAMNBumperFront",
		itemToModel = {
			["Base.85chevyStepVanBumperFront0"] = "FrontBumper0",
			["Base.85chevyStepVanBumperFrontA"] = "FrontBumperA",
			["Base.85chevyStepVanBullbarFrontA"] = "FrontBullbarA",
		},
		default = "first",
	},
	["RearBumper"] = {
		partId = "DAMNBumperRear",
		itemToModel = {
			["Base.85chevyStepVanBumperRear0"] = "RearBumper0",
		},
		default = "first",
	},
	["WindshieldArmor"] = {
		partId = "DAMNWindshieldArmor",
		itemToModel = {
			["Base.85chevyStepVanWindshieldArmor"] = "winda",
            ["Base.85chevyStepVanWindshieldSWATArmor"] = "windas",
		},
	},
	["FrontLeftArmor"] = {
		partId = "DAMNFrontLeftArmor",
		itemToModel = {
			["Base.85chevyStepVanFrontWindowArmor"] = "fla",
            ["Base.85chevyStepVanFrontWindowSWATArmor"] = "flas",
		},
	},
	["FrontRightArmor"] = {
		partId = "DAMNFrontRightArmor",
		itemToModel = {
			["Base.85chevyStepVanFrontWindowArmor"] = "fra",
            ["Base.85chevyStepVanFrontWindowSWATArmor"] = "fras",
		},
	},
	["WindshieldRearArmor"] = {
		partId = "DAMNWindshieldRearArmor",
		itemToModel = {
			["Base.85chevyStepVanWindshieldRearArmor"] = "windra",
            ["Base.85chevyStepVanWindshieldRearSWATArmor"] = "windras",
		},
	},
	["Roofrack"] = {
		partId = "DAMNRoofrack",
		itemToModel = {
			["Base.85chevyStepVanRoofrack0"] = "Roofrack0",
		},
		default = "trve_random",
		noPartChance = 98,
	},

    ["WindshieldArmorS"] = {
		partId = "DAMNWindshieldArmor",
		itemToModel = {
			["Base.85chevyStepVanWindshieldArmor"] = "winda",
            ["Base.85chevyStepVanWindshieldSWATArmor"] = "windas",
		},
        default = "Base.85chevyStepVanWindshieldSWATArmor",
	},
	["FrontLeftArmorS"] = {
		partId = "DAMNFrontLeftArmor",
		itemToModel = {
			["Base.85chevyStepVanFrontWindowArmor"] = "fla",
            ["Base.85chevyStepVanFrontWindowSWATArmor"] = "flas",
		},
        default = "Base.85chevyStepVanFrontWindowSWATArmor",
	},
	["FrontRightArmorS"] = {
		partId = "DAMNFrontRightArmor",
		itemToModel = {
			["Base.85chevyStepVanFrontWindowArmor"] = "fra",
            ["Base.85chevyStepVanFrontWindowSWATArmor"] = "fras",
		},
        default = "Base.85chevyStepVanFrontWindowSWATArmor",
	},
	["WindshieldRearArmorS"] = {
		partId = "DAMNWindshieldRearArmor",
		itemToModel = {
			["Base.85chevyStepVanWindshieldRearArmor"] = "windra",
            ["Base.85chevyStepVanWindshieldRearSWATArmor"] = "windras",
		},
        default = "Base.85chevyStepVanWindshieldRearSWATArmor",
	},
});

function STP85.SideVent(player)
    local vehicle = player.getVehicle and player:getVehicle() or nil
    if not vehicle then return end

    if string.find(vehicle:getScriptName(), "85chevyStepVan") then
        local part = vehicle:getPartById("STP85Vent")
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

Events.OnPlayerUpdate.Add(STP85.SideVent)