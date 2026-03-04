require "ATA2TuningTable"

local function copy(obj, seen)
	if type(obj) ~= 'table' then return obj end
	if seen and seen[obj] then return seen[obj] end
	local s = seen or {}
	local res = setmetatable({}, getmetatable(obj))
	s[obj] = res
	for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
	return res
end

local function SVUC_SandboxVars(input)
	return SandboxVars.SVUC[input]
end
Events.OnInitGlobalModData.Add(SVUC_SandboxVars)
function SVUC_TemplateVehicle()
	local SVUC = {}
	SVUC.timeLight = SVUC_SandboxVars("timeLight")
	SVUC.timeHeavy = SVUC_SandboxVars("timeHeavy")
	SVUC.timeReinforced = SVUC_SandboxVars("timeReinforced")
	SVUC.timeMods = SVUC_SandboxVars("timeMods")
	SVUC.timeWheels = SVUC_SandboxVars("timeWheels")
	SVUC.protectionHealthTriger = SVUC_SandboxVars("protectionHealthTriger")
	SVUC.protectionLightHealthDelta = SVUC_SandboxVars("protectionLightHealthDelta")
	SVUC.protectionHeavyHealthDelta = SVUC_SandboxVars("protectionHeavyHealthDelta")
	SVUC.protectionReinforcedHealthDelta = SVUC_SandboxVars("protectionReinforcedHealthDelta")
	SVUC.protectionBullbarSmallHealthDelta = SVUC_SandboxVars("protectionBullbarSmallHealthDelta")
	SVUC.protectionBullbarMediumHealthDelta = SVUC_SandboxVars("protectionBullbarMediumHealthDelta")
	SVUC.protectionBullbarLargeHealthDelta = SVUC_SandboxVars("protectionBullbarLargeHealthDelta")
	SVUC.protectionPlowHealthDelta = SVUC_SandboxVars("protectionPlowHealthDelta")
	SVUC.protectionWheelsHealthDelta = SVUC_SandboxVars("protectionWheelsHealthDelta")
	SVUC.protectionEngineSmallPowerIncrease = SVUC_SandboxVars("protectionEngineSmallPowerIncrease") * 10
	SVUC.protectionEngineMediumPowerIncrease = SVUC_SandboxVars("protectionEngineMediumPowerIncrease") * 10
	SVUC.protectionEngineLargePowerIncrease = SVUC_SandboxVars("protectionEngineLargePowerIncrease") * 10
	SVUC.protectionEnginePipedPowerIncrease = SVUC_SandboxVars("protectionEnginePipedPowerIncrease") * 10
	SVUC.protectionEngineSnorkelPowerIncrease = SVUC_SandboxVars("protectionEngineSnorkelPowerIncrease") * 10
	SVUC.protectionMods = "protectionMods"
	SVUC.protectionEngineMods = "protectionEngineMods"
	SVUC.protectionLight = "protectionLight"
	SVUC.protectionHeavy = "protectionHeavy"
	SVUC.protectionLightSpiked = "protectionLightSpiked"
	SVUC.protectionHeavySpiked = "protectionHeavySpiked"
	SVUC.protectionLightRusted = "protectionLightRusted"
	SVUC.protectionHeavyRusted = "protectionHeavyRusted"
	SVUC.protectionLightSpikedRusted = "protectionLightSpikedRusted"
	SVUC.protectionHeavySpikedRusted = "protectionHeavySpikedRusted"
	SVUC.protectionReinforced = "protectionReinforced"
	SVUC.protectionReinforcedRusted = "protectionReinforcedRusted"

	TemplateTuningTable = {}
	-- Entries
	TemplateTuningTable["TemplateVehicle"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}

	-- TemplateVehicle
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"] = {
		Small = {
			icon = "media/ui/tuning2/mustang_bullbar_1.png",
			name = "IGUI_ATA2_Bullbar_Small",
			category = SVUC.protectionMods,
			protection = {"HeadlightLeft", "HeadlightRight", "EngineDoor"},
			protectionHealthDelta = SVUC.protectionBullbarSmallHealthDelta,
			protectionTriger = SVUC.protectionHealthTriger,
			removeIfBroken = true,
			install = {
				weight = "auto",
				animation = "ATA_PickLock",
				use = {
					MetalPipe = 4,
					MetalBar=2,
					Screws=4,
					BlowTorch = 5,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					MetalWelding = 3,
					Mechanics = 2,
				},
				time = SVUC.timeMods, 
			},
			uninstall = {
				weight = "auto",
				animation = "ATA_Crowbar_DoorLeft",
				use = {
					BlowTorch=4,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					both = "Base.Crowbar",
				},
				skills = {
					MetalWelding = 2,
				},
				result = "auto",
				time = SVUC.timeMods,
			}
		}
	}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"] = {
		Small = {
			icon = "media/ui/tuning2/mustang_bullbar_1.png",
			name = "IGUI_ATA2_Bullbar_Small",
			category = SVUC.protectionMods,
			protection = {"HeadlightLeft", "HeadlightRight", "EngineDoor"},
			protectionHealthDelta = SVUC.protectionBullbarSmallHealthDelta,
			protectionTriger = SVUC.protectionHealthTriger,
			removeIfBroken = true,
			install = {
				weight = "auto",
				animation = "ATA_PickLock",
				use = {
					MetalPipe = 4,
					MetalBar=2,
					Screws=4,
					BlowTorch = 5,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					MetalWelding = 3,
					Mechanics = 2,
				},
				time = SVUC.timeMods, 
			},
			uninstall = {
				weight = "auto",
				animation = "ATA_Crowbar_DoorLeft",
				use = {
					BlowTorch=4,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					both = "Base.Crowbar",
				},
				skills = {
					MetalWelding = 2,
				},
				result = "auto",
				time = SVUC.timeMods,
			}
		}
	}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Medium = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Small)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Medium.icon = "media/ui/tuning2/dadge_bullbar_1.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Medium.name = "IGUI_ATA2_Bullbar_Medium"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Medium.protectionHealthDelta = SVUC.protectionBullbarMediumHealthDelta
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Medium.install.use = {MetalPipe = 4, MetalBar=4, Screws=6, BlowTorch = 5,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Medium.install.skills = {MetalWelding = 5, Mechanics = 3}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Medium.uninstall.skills = {MetalWelding = 4}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Large = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Small)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Large.icon = "media/ui/tuning2/van_bullbar_1.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Large.name = "IGUI_ATA2_Bullbar_Large"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Large.protectionHealthDelta = SVUC.protectionBullbarLargeHealthDelta
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Large.install.use = {MetalPipe = 6, MetalBar=6, Screws=8, BlowTorch = 5,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Large.install.skills = {MetalWelding = 6, Mechanics = 4}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Large.uninstall.skills = {MetalWelding = 5}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].LargeSpiked = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Large)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].LargeSpiked.icon = "media/ui/tuning2/van_bullbar_1.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].LargeSpiked.name = "IGUI_ATA2_Bullbar_Large_Spiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].LargeSpiked.install.use = {MetalPipe = 6, MetalBar=6, Screws=8, BlowTorch = 5,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].LargeSpiked.install.skills = {MetalWelding = 7, Mechanics = 5}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].LargeSpiked.uninstall.skills = {MetalWelding = 6}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Small)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow.icon = "media/ui/tuning2/van_bullbar_3.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow.name = "IGUI_ATA2_Plow"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow.protectionHealthDelta = SVUC.protectionPlowHealthDelta
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow.install.use = {MetalPipe = 4, SheetMetal = 4, MetalBar=4, Screws=6, BlowTorch = 5,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow.install.skills = {MetalWelding = 8, Mechanics = 6}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow.uninstall.skills = {MetalWelding = 7}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowRusted.name = "IGUI_ATA2_Plow_Rusted"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpiked = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpiked.name = "IGUI_ATA2_Plow_Spiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpiked.install.use = {MetalPipe = 4, SheetMetal = 4, MetalBar=4, Screws=6, BlowTorch = 5,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpiked.install.skills = {MetalWelding = 8, Mechanics = 6}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpiked.uninstall.skills = {MetalWelding = 7}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpikedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpiked)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpikedRusted.name = "IGUI_ATA2_Plow_Spiked_Rusted"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarTruck"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarTruck"].Truck = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarTruck"].Large)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarTruck"].Truck.name = "IGUI_ATA2_Bullbar_Truck"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarTruck"].Truck.spawnChance = 20

	TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarPolice"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarPolice"].Small.spawnChance = 75

	TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarPoliceSUV"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarPoliceSUV"].Small.spawnChance = 40
	TemplateTuningTable["TemplateVehicle"].parts["ATA2BullbarPoliceSUV"].Large.spawnChance = 60

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"] = {
		Light = {
			icon = "media/ui/tuning2/protection_window_side.png",
			name = "IGUI_VehiclePartATA2ProtectionWindowFrontLeftLight",
			category = SVUC.protectionLight,
			protection = {"WindowFrontLeft"},
			protectionHealthDelta = SVUC.protectionLightHealthDelta,
			protectionTriger = SVUC.protectionHealthTriger,
			removeIfBroken = true,
			install = {
				area = "TireFrontLeft",
				weight = "auto",
				use = {
					MetalPipe = 4,
					MetalBar=4,
					Screws=6,
					BlowTorch = 5,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					MetalWelding = 3,
				},
				requireInstalled = {"WindowFrontLeft"},
				time = SVUC.timeLight,
			},
			uninstall = {
				area = "TireFrontLeft",
				animation = "ATA_IdleLeverOpenMid",
				use = {
					BlowTorch=4,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					both = "Base.Crowbar",
				},
				skills = {
					MetalWelding = 2,
				},
				result = "auto",
				time = SVUC.timeLight,
			}
		}
	}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.icon = "media/ui/tuning2/protection_window_sheet_side.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindowFrontLeftHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.category = SVUC.protectionHeavy
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.disableOpenWindowFromSeat = "SeatFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.protectionHealthDelta = SVUC.protectionHeavyHealthDelta
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.install.use = {MetalPipe = 4, SheetMetal = 2, MetalBar=4, Screws=6, BlowTorch = 5,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.install.skills = {MetalWelding = 6}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.install.time = SVUC.timeHeavy
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.uninstall.skills = {MetalWelding = 5}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.uninstall.time = SVUC.timeHeavy

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].LightRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionWindowFrontLeftLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].LightRusted.category = SVUC.protectionLightRusted
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].HeavyRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionWindowFrontLeftHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].HeavyRusted.category = SVUC.protectionHeavyRusted

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].LightSpiked = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionWindowFrontLeftLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].LightSpiked.category = SVUC.protectionLightSpiked
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].HeavySpiked = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionWindowFrontLeftHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].HeavySpiked.category = SVUC.protectionHeavySpiked

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].LightSpikedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowFrontLeftLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].LightSpikedRusted.category = SVUC.protectionLightSpikedRusted
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].HeavySpikedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowFrontLeftHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].HeavySpikedRusted.category = SVUC.protectionHeavySpikedRusted

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindowFrontLeftReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.category = SVUC.protectionReinforced
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.protectionHealthDelta = SVUC.protectionReinforcedHealthDelta
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.install.use = {MetalPipe = 4, SheetMetal = 4, MetalBar=4, Screws=6, BlowTorch = 5,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.install.skills = {MetalWelding = 8}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.install.time = SVUC.timeReinforced
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.uninstall.skills = {MetalWelding = 7}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.uninstall.time = SVUC.timeReinforced

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].ReinforcedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowFrontLeftReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].ReinforcedRusted.category = SVUC.protectionReinforcedRusted

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Light.name = "IGUI_VehiclePartATA2ProtectionWindowFrontRightLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Light.protection = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Light.install.requireInstalled = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Light.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Light.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindowFrontRightHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Heavy.protection = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Heavy.install.requireInstalled = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Heavy.disableOpenWindowFromSeat = "SeatFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Heavy.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Heavy.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionWindowFrontRightLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightRusted.protection = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightRusted.install.requireInstalled = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionWindowFrontRightHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavyRusted.protection = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavyRusted.install.requireInstalled = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavyRusted.disableOpenWindowFromSeat = "SeatFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavyRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavyRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionWindowFrontRightLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightSpiked.protection = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightSpiked.install.requireInstalled = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightSpiked.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightSpiked.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionWindowFrontRightHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavySpiked.protection = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavySpiked.install.requireInstalled = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavySpiked.disableOpenWindowFromSeat = "SeatFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavySpiked.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavySpiked.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowFrontRightLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightSpikedRusted.protection = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightSpikedRusted.install.requireInstalled = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightSpikedRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].LightSpikedRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowFrontRightHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavySpikedRusted.protection = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavySpikedRusted.install.requireInstalled = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavySpikedRusted.disableOpenWindowFromSeat = "SeatFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavySpikedRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].HeavySpikedRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindowFrontRightReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Reinforced.protection = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Reinforced.install.requireInstalled = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Reinforced.disableOpenWindowFromSeat = "SeatFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Reinforced.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Reinforced.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowFrontRightReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].ReinforcedRusted.protection = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].ReinforcedRusted.install.requireInstalled = {"WindowFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].ReinforcedRusted.disableOpenWindowFromSeat = "SeatFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].ReinforcedRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].ReinforcedRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Light.name = "IGUI_VehiclePartATA2ProtectionWindowRearLeftLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Light.protection = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Light.install.requireInstalled = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Light.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Light.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindowRearLeftHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Heavy.protection = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Heavy.install.requireInstalled = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Heavy.disableOpenWindowFromSeat = "SeatRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Heavy.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Heavy.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionWindowRearLeftLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightRusted.protection = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightRusted.install.requireInstalled = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightRusted.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightRusted.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionWindowRearLeftHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavyRusted.protection = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavyRusted.install.requireInstalled = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavyRusted.disableOpenWindowFromSeat = "SeatRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavyRusted.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavyRusted.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionWindowRearLeftLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightSpiked.protection = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightSpiked.install.requireInstalled = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightSpiked.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightSpiked.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionWindowRearLeftHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavySpiked.protection = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavySpiked.install.requireInstalled = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavySpiked.disableOpenWindowFromSeat = "SeatRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavySpiked.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavySpiked.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowRearLeftLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightSpikedRusted.protection = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightSpikedRusted.install.requireInstalled = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightSpikedRusted.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].LightSpikedRusted.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowRearLeftHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavySpikedRusted.protection = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavySpikedRusted.install.requireInstalled = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavySpikedRusted.disableOpenWindowFromSeat = "SeatRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavySpikedRusted.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].HeavySpikedRusted.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindowRearLeftReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Reinforced.protection = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Reinforced.install.requireInstalled = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Reinforced.disableOpenWindowFromSeat = "SeatRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Reinforced.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Reinforced.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowRearLeftReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].ReinforcedRusted.protection = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].ReinforcedRusted.install.requireInstalled = {"WindowRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].ReinforcedRusted.disableOpenWindowFromSeat = "SeatRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].ReinforcedRusted.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].ReinforcedRusted.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Light.name = "IGUI_VehiclePartATA2ProtectionWindowRearRightLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Light.protection = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Light.install.requireInstalled = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Light.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Light.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindowRearRightHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Heavy.protection = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Heavy.install.requireInstalled = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Heavy.disableOpenWindowFromSeat = "SeatRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Heavy.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Heavy.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionWindowRearRightLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightRusted.protection = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightRusted.install.requireInstalled = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionWindowRearRightHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavyRusted.protection = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavyRusted.install.requireInstalled = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavyRusted.disableOpenWindowFromSeat = "SeatRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavyRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavyRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionWindowRearRightLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightSpiked.protection = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightSpiked.install.requireInstalled = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightSpiked.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightSpiked.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionWindowRearRightHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavySpiked.protection = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavySpiked.install.requireInstalled = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavySpiked.disableOpenWindowFromSeat = "SeatRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavySpiked.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavySpiked.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowRearRightLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightSpikedRusted.protection = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightSpikedRusted.install.requireInstalled = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightSpikedRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].LightSpikedRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowRearRightHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavySpikedRusted.protection = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavySpikedRusted.install.requireInstalled = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavySpikedRusted.disableOpenWindowFromSeat = "SeatRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavySpikedRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].HeavySpikedRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindowRearRightReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Reinforced.protection = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Reinforced.install.requireInstalled = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Reinforced.disableOpenWindowFromSeat = "SeatRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Reinforced.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Reinforced.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowRearRightReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].ReinforcedRusted.protection = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].ReinforcedRusted.install.requireInstalled = {"WindowRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].ReinforcedRusted.disableOpenWindowFromSeat = "SeatRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].ReinforcedRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].ReinforcedRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Light.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleLeftLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Light.protection = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Light.install.requireInstalled = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Light.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Light.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleLeftHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Heavy.protection = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Heavy.install.requireInstalled = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Heavy.disableOpenWindowFromSeat = nil
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Heavy.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Heavy.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleLeftLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightRusted.protection = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightRusted.install.requireInstalled = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightRusted.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightRusted.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleLeftHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavyRusted.protection = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavyRusted.install.requireInstalled = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavyRusted.disableOpenWindowFromSeat = nil
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavyRusted.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavyRusted.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleLeftLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightSpiked.protection = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightSpiked.install.requireInstalled = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightSpiked.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightSpiked.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleLeftHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavySpiked.protection = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavySpiked.install.requireInstalled = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavySpiked.disableOpenWindowFromSeat = nil
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavySpiked.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavySpiked.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleLeftLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightSpikedRusted.protection = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightSpikedRusted.install.requireInstalled = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightSpikedRusted.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].LightSpikedRusted.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleLeftHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavySpikedRusted.protection = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavySpikedRusted.install.requireInstalled = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavySpikedRusted.disableOpenWindowFromSeat = nil
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavySpikedRusted.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].HeavySpikedRusted.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleLeftReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Reinforced.protection = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Reinforced.install.requireInstalled = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Reinforced.disableOpenWindowFromSeat = nil
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Reinforced.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Reinforced.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleLeftReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].ReinforcedRusted.protection = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].ReinforcedRusted.install.requireInstalled = {"WindowMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].ReinforcedRusted.disableOpenWindowFromSeat = nil
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].ReinforcedRusted.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].ReinforcedRusted.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Light.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleRightLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Light.protection = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Light.install.requireInstalled = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Light.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Light.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleRightHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Heavy.protection = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Heavy.install.requireInstalled = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Heavy.disableOpenWindowFromSeat = nil
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Heavy.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Heavy.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleRightLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightRusted.protection = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightRusted.install.requireInstalled = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleRightHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavyRusted.protection = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavyRusted.install.requireInstalled = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavyRusted.disableOpenWindowFromSeat = nil
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavyRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavyRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleRightLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightSpiked.protection = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightSpiked.install.requireInstalled = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightSpiked.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightSpiked.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleRightHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavySpiked.protection = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavySpiked.install.requireInstalled = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavySpiked.disableOpenWindowFromSeat = nil
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavySpiked.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavySpiked.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleRightLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightSpikedRusted.protection = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightSpikedRusted.install.requireInstalled = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightSpikedRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].LightSpikedRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleRightHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavySpikedRusted.protection = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavySpikedRusted.install.requireInstalled = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavySpikedRusted.disableOpenWindowFromSeat = nil
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavySpikedRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].HeavySpikedRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleRightReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Reinforced.protection = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Reinforced.install.requireInstalled = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Reinforced.disableOpenWindowFromSeat = nil
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Reinforced.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Reinforced.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleRightReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].ReinforcedRusted.protection = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].ReinforcedRusted.install.requireInstalled = {"WindowMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].ReinforcedRusted.disableOpenWindowFromSeat = nil
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].ReinforcedRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].ReinforcedRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"] = {
		Light = {
			icon = "media/ui/tuning2/protection_window_windshield.png",
			name = "IGUI_VehiclePartATA2ProtectionWindshieldLight",
			category = SVUC.protectionLight,
			protection = {"Windshield"},
			protectionHealthDelta = SVUC.protectionLightHealthDelta,
			protectionTriger = SVUC.protectionHealthTriger,
			removeIfBroken = true,
			install = {
				area = "TireFrontRight",
				weight = "auto",
				use = {
					MetalPipe = 4,
					MetalBar=4,
					Screws=6,
					BlowTorch = 5,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					MetalWelding = 3,
				},
				requireInstalled = {"Windshield"},
				time = SVUC.timeLight,
			},
			uninstall = {
				area = "TireFrontRight",
				animation = "ATA_IdleLeverOpenMid",
				use = {
					BlowTorch=4,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					both = "Base.Crowbar",
				},
				skills = {
					MetalWelding = 2,
				},
				result = "auto",
				time = SVUC.timeLight,
			}
		}
	}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.icon = "media/ui/tuning2/protection_window_sheet_windshield.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindshieldHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.category = SVUC.protectionHeavy
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.protectionHealthDelta = SVUC.protectionHeavyHealthDelta
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.install.use = {MetalPipe = 4, SheetMetal = 2, MetalBar=4, Screws=6, BlowTorch = 5,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.install.skills = {MetalWelding = 6}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.install.time = SVUC.timeHeavy
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.uninstall.skills = {MetalWelding = 5}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.uninstall.time = SVUC.timeHeavy

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].LightRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionWindshieldLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].LightRusted.category = SVUC.protectionLightRusted
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].HeavyRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionWindshieldHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].HeavyRusted.category = SVUC.protectionHeavyRusted

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].LightSpiked = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionWindshieldLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].LightSpiked.category = SVUC.protectionLightSpiked
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].HeavySpiked = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionWindshieldHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].HeavySpiked.category = SVUC.protectionHeavySpiked

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].LightSpikedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindshieldLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].LightSpikedRusted.category = SVUC.protectionLightSpikedRusted
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].HeavySpikedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindshieldHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].HeavySpikedRusted.category = SVUC.protectionHeavySpikedRusted

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindshieldReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.category = SVUC.protectionReinforced
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.protectionHealthDelta = SVUC.protectionReinforcedHealthDelta
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.install.use = {MetalPipe = 4, SheetMetal = 4, MetalBar=4, Screws=6, BlowTorch = 5,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.install.skills = {MetalWelding = 8}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.install.time = SVUC.timeReinforced
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.uninstall.skills = {MetalWelding = 7}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.uninstall.time = SVUC.timeReinforced

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].ReinforcedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionWindshieldReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].ReinforcedRusted.category = SVUC.protectionReinforcedRusted

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Light.name = "IGUI_VehiclePartATA2ProtectionWindshieldRearLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Light.protection = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Light.install.requireInstalled = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Light.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Light.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindshieldRearHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Heavy.protection = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Heavy.install.requireInstalled = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Heavy.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Heavy.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionWindshieldRearLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightRusted.protection = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightRusted.install.requireInstalled = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionWindshieldRearHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavyRusted.protection = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavyRusted.install.requireInstalled = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavyRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavyRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionWindshieldRearLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightSpiked.protection = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightSpiked.install.requireInstalled = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightSpiked.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightSpiked.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionWindshieldRearHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavySpiked.protection = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavySpiked.install.requireInstalled = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavySpiked.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavySpiked.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindshieldRearLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightSpikedRusted.protection = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightSpikedRusted.install.requireInstalled = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightSpikedRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].LightSpikedRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionWindshieldRearHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavySpikedRusted.protection = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavySpikedRusted.install.requireInstalled = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavySpikedRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].HeavySpikedRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindshieldRearReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Reinforced.protection = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Reinforced.install.requireInstalled = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Reinforced.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Reinforced.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionWindshieldRearReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].ReinforcedRusted.protection = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].ReinforcedRusted.install.requireInstalled = {"WindshieldRear"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].ReinforcedRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].ReinforcedRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"] = {
		Light = {
			icon = "media/ui/tuning2/bus_protection_window_side.png",
			name = "IGUI_VehiclePartATA2ProtectionTrunkLight",
			category = SVUC.protectionLight,
			protection = {"TruckBed", "TrunkDoor", "GasTank"},
			protectionHealthDelta = SVUC.protectionLightHealthDelta,
			protectionTriger = SVUC.protectionHealthTriger,
			removeIfBroken = true,
			install = {
				use = {
					MetalPipe = 4,
					MetalBar=4,
					Screws=6,
					BlowTorch = 5,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					MetalWelding = 4,
				},
				requireInstalled = {"TruckBed"},
				time = SVUC.timeLight, 
			},
			uninstall = {
				animation = "ATA_IdleLeverOpenMid",
				use = {
					BlowTorch=4,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					both = "Base.Crowbar",
				},
				skills = {
					MetalWelding = 3,
				},
				result = "auto",
				time = SVUC.timeLight,
			}
		}
	}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy.name = "IGUI_VehiclePartATA2ProtectionTrunkHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy.icon = "media/ui/tuning2/van_hood_protection.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy.category = SVUC.protectionHeavy
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy.protectionHealthDelta = SVUC.protectionHeavyHealthDelta
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy.install.use = {SheetMetal = 4, MetalPipe = 4, MetalBar = 2, Screws = 6, BlowTorch = 4,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy.install.skills = {MetalWelding = 6}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy.install.time = SVUC.timeHeavy
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy.uninstall.skills = {MetalWelding = 5}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy.uninstall.time = SVUC.timeHeavy

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].LightRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].LightRusted.category = SVUC.protectionLightRusted
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionTrunkLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].HeavyRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionTrunkHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].HeavyRusted.category = SVUC.protectionHeavyRusted

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].LightSpiked = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionTrunkLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].LightSpiked.category = SVUC.protectionLightSpiked
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].HeavySpiked = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionTrunkHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].HeavySpiked.category = SVUC.protectionHeavySpiked

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].LightSpikedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionTrunkLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].LightSpikedRusted.category = SVUC.protectionLightSpikedRusted
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].HeavySpikedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionTrunkHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].HeavySpikedRusted.category = SVUC.protectionHeavySpikedRusted

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Reinforced = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionTrunkReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Reinforced.category = SVUC.protectionReinforced
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Reinforced.protectionHealthDelta = SVUC.protectionReinforcedHealthDelta
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Reinforced.install.use = {MetalPipe = 4, SheetMetal = 4, MetalBar=4, Screws=6, BlowTorch = 5,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Reinforced.install.skills = {MetalWelding = 8}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Reinforced.install.time = SVUC.timeReinforced
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Reinforced.uninstall.skills = {MetalWelding = 7}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Reinforced.uninstall.time = SVUC.timeReinforced

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].ReinforcedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].Reinforced)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionTrunkReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"].ReinforcedRusted.category = SVUC.protectionReinforcedRusted

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Light.name = "IGUI_VehiclePartATA2ProtectionDoorsRearLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Light.protection = {"TruckBed", "DoorRear", "GasTank"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Heavy.name = "IGUI_VehiclePartATA2ProtectionDoorsRearHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Heavy.protection = {"TruckBed", "DoorRear", "GasTank"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionDoorsRearLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].LightSpiked.protection = {"TruckBed", "DoorRear", "GasTank"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionDoorsRearHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].HeavySpiked.protection = {"TruckBed", "DoorRear", "GasTank"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionDoorsRearLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].LightRusted.protection = {"TruckBed", "DoorRear", "GasTank"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionDoorsRearHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].HeavyRusted.protection = {"TruckBed", "DoorRear", "GasTank"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorsRearLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].LightSpikedRusted.protection = {"TruckBed", "DoorRear", "GasTank"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorsRearHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].HeavySpikedRusted.protection = {"TruckBed", "DoorRear", "GasTank"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionDoorsRearReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Reinforced.protection = {"TruckBed", "DoorRear", "GasTank"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorsRearReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].ReinforcedRusted.protection = {"TruckBed", "DoorRear", "GasTank"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Light.name = "IGUI_VehiclePartATA2ProtectionHoodLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Light.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Light.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Light.install.requireUninstalled = {"ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Heavy.name = "IGUI_VehiclePartATA2ProtectionHoodHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Heavy.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Heavy.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Heavy.install.requireUninstalled = {"ATA2AirScoop"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionHoodLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpiked.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpiked.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpiked.install.requireUninstalled = {"ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionHoodHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpiked.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpiked.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpiked.install.requireUninstalled = {"ATA2AirScoop"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionHoodLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightRusted.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightRusted.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightRusted.install.requireUninstalled = {"ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionHoodHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavyRusted.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavyRusted.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavyRusted.install.requireUninstalled = {"ATA2AirScoop"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionHoodLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpikedRusted.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpikedRusted.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpikedRusted.install.requireUninstalled = {"ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionHoodHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpikedRusted.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpikedRusted.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpikedRusted.install.requireUninstalled = {"ATA2AirScoop"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionHoodReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Reinforced.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Reinforced.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Reinforced.install.requireUninstalled = {"ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionHoodReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].ReinforcedRusted.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].ReinforcedRusted.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].ReinforcedRusted.install.requireUninstalled = {"ATA2AirScoop"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightScoop = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightScoop.name = "IGUI_VehiclePartATA2ProtectionHoodLightScoop"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightScoop.install.requireInstalled = {"EngineDoor", "ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightScoop.install.requireUninstalled = nil

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavyScoop = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavyScoop.name = "IGUI_VehiclePartATA2ProtectionHoodHeavyScoop"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavyScoop.install.requireInstalled = {"EngineDoor", "ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavyScoop.install.requireUninstalled = nil

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpikedScoop = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpiked)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpikedScoop.name = "IGUI_VehiclePartATA2ProtectionHoodLightSpikedScoop"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpikedScoop.install.requireInstalled = {"EngineDoor", "ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpikedScoop.install.requireUninstalled = nil

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpikedScoop = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpiked)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpikedScoop.name = "IGUI_VehiclePartATA2ProtectionHoodHeavySpikedScoop"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpikedScoop.install.requireInstalled = {"EngineDoor", "ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpikedScoop.install.requireUninstalled = nil

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightRustedScoop = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightRusted)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightRustedScoop.name = "IGUI_VehiclePartATA2ProtectionHoodLightRustedScoop"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightRustedScoop.install.requireInstalled = {"EngineDoor", "ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightRustedScoop.install.requireUninstalled = nil

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavyRustedScoop = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavyRusted)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavyRustedScoop.name = "IGUI_VehiclePartATA2ProtectionHoodHeavyRustedScoop"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavyRustedScoop.install.requireInstalled = {"EngineDoor", "ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavyRustedScoop.install.requireUninstalled = nil

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpikedRustedScoop = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpikedRusted)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpikedRustedScoop.name = "IGUI_VehiclePartATA2ProtectionHoodLightSpikedRustedScoop"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpikedRustedScoop.install.requireInstalled = {"EngineDoor", "ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].LightSpikedRustedScoop.install.requireUninstalled = nil

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpikedRustedScoop = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpikedRusted)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpikedRustedScoop.name = "IGUI_VehiclePartATA2ProtectionHoodHeavySpikedRustedScoop"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpikedRustedScoop.install.requireInstalled = {"EngineDoor", "ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].HeavySpikedRustedScoop.install.requireUninstalled = nil

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].ReinforcedScoop = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].Reinforced)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].ReinforcedScoop.name = "IGUI_VehiclePartATA2ProtectionHoodReinforcedScoop"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].ReinforcedScoop.install.requireInstalled = {"EngineDoor", "ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].ReinforcedScoop.install.requireUninstalled = nil

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].ReinforcedRustedScoop = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].ReinforcedRusted)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].ReinforcedRustedScoop.name = "IGUI_VehiclePartATA2ProtectionHoodReinforcedRustedScoop"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].ReinforcedRustedScoop.install.requireInstalled = {"EngineDoor", "ATA2AirScoop"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"].ReinforcedRustedScoop.install.requireUninstalled = nil


	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionTrunk"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].Light.name = "IGUI_VehiclePartATA2ProtectionHoodLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].Light.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].Light.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].Heavy.name = "IGUI_VehiclePartATA2ProtectionHoodHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].Heavy.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].Heavy.install.requireInstalled = {"EngineDoor"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionHoodLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].LightSpiked.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].LightSpiked.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionHoodHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].HeavySpiked.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].HeavySpiked.install.requireInstalled = {"EngineDoor"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionHoodLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].LightRusted.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].LightRusted.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionHoodHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].HeavyRusted.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].HeavyRusted.install.requireInstalled = {"EngineDoor"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionHoodLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].LightSpikedRusted.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].LightSpikedRusted.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionHoodHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].HeavySpikedRusted.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].HeavySpikedRusted.install.requireInstalled = {"EngineDoor"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionHoodReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].Reinforced.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].Reinforced.install.requireInstalled = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionHoodReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].ReinforcedRusted.protection = {"EngineDoor"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionHoodNoScoop"].ReinforcedRusted.install.requireInstalled = {"EngineDoor"}


	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"] = {
		Light = {
			icon = "media/ui/tuning2/bus_protection_window_side.png",
			name = "IGUI_VehiclePartATA2ProtectionDoorFrontLeftLight",
			secondModel = "StaticPart",
			category = SVUC.protectionLight,
			protection = {"DoorFrontLeft"},
			protectionHealthDelta = SVUC.protectionLightHealthDelta,
			protectionTriger = SVUC.protectionHealthTriger,
			removeIfBroken = true,
			install = {
				area = "TireFrontLeft",
				weight = "auto",
				use = {
					MetalPipe = 4,
					MetalBar=4,
					Screws=6,
					BlowTorch = 5,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					MetalWelding = 4,
				},
				requireInstalled = {"DoorFrontLeft"},
				time = SVUC.timeLight,
			},
			uninstall = {
				area = "TireFrontLeft",
				animation = "ATA_IdleLeverOpenMid",
				use = {
					BlowTorch=4,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					both = "Base.Crowbar",
				},
				skills = {
					MetalWelding = 3,
				},
				result = "auto",
				time = SVUC.timeLight,
			}
		}
	}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.icon = "media/ui/tuning2/van_hood_protection.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.name = "IGUI_VehiclePartATA2ProtectionDoorFrontLeftHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.category = SVUC.protectionHeavy
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.protectionHealthDelta = SVUC.protectionHeavyHealthDelta
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.install.use = {MetalPipe = 4, SheetMetal = 2, MetalBar=4, Screws=6, BlowTorch = 5,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.install.skills = {MetalWelding = 6}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.install.time = SVUC.timeHeavy
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.uninstall.skills = {MetalWelding = 5}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.uninstall.time = SVUC.timeHeavy

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].LightRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionDoorFrontLeftLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].LightRusted.category = SVUC.protectionLightRusted
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].HeavyRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionDoorFrontLeftHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].HeavyRusted.category = SVUC.protectionHeavyRusted

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].LightSpiked = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionDoorFrontLeftLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].LightSpiked.category = SVUC.protectionLightSpiked
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].HeavySpiked = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionDoorFrontLeftHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].HeavySpiked.category = SVUC.protectionHeavySpiked

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].LightSpikedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Light)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorFrontLeftLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].LightSpikedRusted.category = SVUC.protectionLightSpikedRusted
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].HeavySpikedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorFrontLeftHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].HeavySpikedRusted.category = SVUC.protectionHeavySpikedRusted

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionDoorFrontLeftReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.category = SVUC.protectionReinforced
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.protectionHealthDelta = SVUC.protectionReinforcedHealthDelta
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.install.use = {MetalPipe = 4, SheetMetal = 4, MetalBar=4, Screws=6, BlowTorch = 5,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.install.skills = {MetalWelding = 8}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.install.time = SVUC.timeReinforced
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.uninstall.skills = {MetalWelding = 7}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.uninstall.time = SVUC.timeReinforced

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].ReinforcedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorFrontLeftReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].ReinforcedRusted.category = SVUC.protectionReinforcedRusted

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Light.name = "IGUI_VehiclePartATA2ProtectionDoorFrontRightLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Light.protection = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Light.install.requireInstalled = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Light.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Light.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Heavy.protection = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Heavy.name = "IGUI_VehiclePartATA2ProtectionDoorFrontRightHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Heavy.install.requireInstalled = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Heavy.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Heavy.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightRusted.protection = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionDoorFrontRightLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightRusted.install.requireInstalled = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavyRusted.protection = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionDoorFrontRightHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavyRusted.install.requireInstalled = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavyRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavyRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightSpiked.protection = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionDoorFrontRightLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightSpiked.install.requireInstalled = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightSpiked.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightSpiked.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavySpiked.protection = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionDoorFrontRightHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavySpiked.install.requireInstalled = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavySpiked.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavySpiked.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightSpikedRusted.protection = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorFrontRightLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightSpikedRusted.install.requireInstalled = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightSpikedRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].LightSpikedRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavySpikedRusted.protection = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorFrontRightHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavySpikedRusted.install.requireInstalled = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavySpikedRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].HeavySpikedRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Reinforced.protection = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionDoorFrontRightReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Reinforced.install.requireInstalled = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Reinforced.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Reinforced.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].ReinforcedRusted.protection = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorFrontRightReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].ReinforcedRusted.install.requireInstalled = {"DoorFrontRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].ReinforcedRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].ReinforcedRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Light.name = "IGUI_VehiclePartATA2ProtectionDoorRearLeftLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Light.protection = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Light.install.requireInstalled = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Light.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Light.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Heavy.protection = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Heavy.name = "IGUI_VehiclePartATA2ProtectionDoorRearLeftHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Heavy.install.requireInstalled = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Heavy.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Heavy.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightSpiked.protection = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionDoorRearLeftLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightSpiked.install.requireInstalled = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightSpiked.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightSpiked.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionDoorRearLeftHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavySpiked.protection = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavySpiked.install.requireInstalled = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavySpiked.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavySpiked.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionDoorRearLeftLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightRusted.protection = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightRusted.install.requireInstalled = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightRusted.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightRusted.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionDoorRearLeftHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavyRusted.protection = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavyRusted.install.requireInstalled = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavyRusted.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavyRusted.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorRearLeftLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightSpikedRusted.protection = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightSpikedRusted.install.requireInstalled = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightSpikedRusted.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].LightSpikedRusted.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorRearLeftHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavySpikedRusted.protection = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavySpikedRusted.install.requireInstalled = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavySpikedRusted.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].HeavySpikedRusted.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionDoorRearLeftReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Reinforced.protection = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Reinforced.install.requireInstalled = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Reinforced.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Reinforced.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorRearLeftReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].ReinforcedRusted.protection = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].ReinforcedRusted.install.requireInstalled = {"DoorRearLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].ReinforcedRusted.install.area = "TireRearLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].ReinforcedRusted.uninstall.area = "TireRearLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Light.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleLeftLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Light.protection = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Light.install.requireInstalled = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Light.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Light.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Heavy.protection = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Heavy.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleLeftHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Heavy.install.requireInstalled = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Heavy.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Heavy.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleLeftLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightRusted.protection = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightRusted.install.requireInstalled = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightRusted.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightRusted.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavyRusted.protection = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleLeftHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavyRusted.install.requireInstalled = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavyRusted.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavyRusted.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleLeftLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightSpiked.protection = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightSpiked.install.requireInstalled = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightSpiked.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightSpiked.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavySpiked.protection = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleLeftHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavySpiked.install.requireInstalled = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavySpiked.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavySpiked.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleLeftLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightSpikedRusted.protection = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightSpikedRusted.install.requireInstalled = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightSpikedRusted.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].LightSpikedRusted.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavySpikedRusted.protection = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleLeftHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavySpikedRusted.install.requireInstalled = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavySpikedRusted.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].HeavySpikedRusted.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleLeftReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Reinforced.protection = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Reinforced.install.requireInstalled = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Reinforced.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Reinforced.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].ReinforcedRusted.protection = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleLeftReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].ReinforcedRusted.install.requireInstalled = {"DoorMiddleLeft"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].ReinforcedRusted.install.area = "TireFrontLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].ReinforcedRusted.uninstall.area = "TireFrontLeft"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Light.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleRightLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Light.protection = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Light.install.requireInstalled = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Light.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Light.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Heavy.protection = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Heavy.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleRightHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Heavy.install.requireInstalled = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Heavy.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Heavy.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleRightLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightRusted.protection = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightRusted.install.requireInstalled = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavyRusted.protection = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleRightHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavyRusted.install.requireInstalled = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavyRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavyRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleRightLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightSpiked.protection = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightSpiked.install.requireInstalled = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightSpiked.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightSpiked.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavySpiked.protection = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleRightHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavySpiked.install.requireInstalled = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavySpiked.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavySpiked.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleRightLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightSpikedRusted.protection = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightSpikedRusted.install.requireInstalled = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightSpikedRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].LightSpikedRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavySpikedRusted.protection = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleRightHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavySpikedRusted.install.requireInstalled = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavySpikedRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].HeavySpikedRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleRightReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Reinforced.protection = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Reinforced.install.requireInstalled = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Reinforced.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Reinforced.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].ReinforcedRusted.protection = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleRightReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].ReinforcedRusted.install.requireInstalled = {"DoorMiddleRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].ReinforcedRusted.install.area = "TireFrontRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].ReinforcedRusted.uninstall.area = "TireFrontRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Light.name = "IGUI_VehiclePartATA2ProtectionDoorRearRightLight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Light.protection = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Light.install.requireInstalled = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Light.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Light.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Heavy.protection = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Heavy.name = "IGUI_VehiclePartATA2ProtectionDoorRearRightHeavy"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Heavy.install.requireInstalled = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Heavy.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Heavy.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightRusted.name = "IGUI_VehiclePartATA2ProtectionDoorRearRightLightRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightRusted.protection = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightRusted.install.requireInstalled = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavyRusted.protection = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavyRusted.name = "IGUI_VehiclePartATA2ProtectionDoorRearRightHeavyRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavyRusted.install.requireInstalled = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavyRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavyRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightSpiked.name = "IGUI_VehiclePartATA2ProtectionDoorRearRightLightSpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightSpiked.protection = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightSpiked.install.requireInstalled = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightSpiked.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightSpiked.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavySpiked.protection = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavySpiked.name = "IGUI_VehiclePartATA2ProtectionDoorRearRightHeavySpiked"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavySpiked.install.requireInstalled = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavySpiked.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavySpiked.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightSpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorRearRightLightSpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightSpikedRusted.protection = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightSpikedRusted.install.requireInstalled = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightSpikedRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].LightSpikedRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavySpikedRusted.protection = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavySpikedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorRearRightHeavySpikedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavySpikedRusted.install.requireInstalled = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavySpikedRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].HeavySpikedRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionDoorRearRightReinforced"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Reinforced.protection = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Reinforced.install.requireInstalled = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Reinforced.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Reinforced.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].ReinforcedRusted.protection = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].ReinforcedRusted.name = "IGUI_VehiclePartATA2ProtectionDoorRearRightReinforcedRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].ReinforcedRusted.install.requireInstalled = {"DoorRearRight"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].ReinforcedRusted.install.area = "TireRearRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].ReinforcedRusted.uninstall.area = "TireRearRight"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2InteractiveTrunkRoofRack"] = {
		Default = {
			icon = "media/ui/tuning2/roof_rack_2.png",
			category = SVUC.protectionMods,
			--interactiveTrunk = {
				--filling = {"ATA_VanDeRumba_roof_bag1", "ATA_VanDeRumba_roof_bag2", "ATA_VanDeRumba_roof_bag3", "ATA_VanDeRumba_roof_bag4", "ATA_VanDeRumba_roof_bag5", "ATA_VanDeRumba_roof_bag6"},
				--items = {
					--{
						--itemTypes = {"MetalDrum"},
						--modelNameByCount = {"ATA_VanDeRumba_roof_barrel"},
					--},
					--{
						--itemTypes = {"PetrolCan", "EmptyPetrolCan"},
						--modelNameByCount = {"ATA_VanDeRumba_roof_gascan0", "ATA_VanDeRumba_roof_gascan1", "ATA_VanDeRumba_roof_gascan2", "ATA_VanDeRumba_roof_gascan3", "ATA_VanDeRumba_roof_gascan4", "ATA_VanDeRumba_roof_gascan5", "ATA_VanDeRumba_roof_gascan6", "ATA_VanDeRumba_roof_gascan7", "ATA_VanDeRumba_roof_gascan8", },
					--},
				--}
			--},
			containerCapacity = 50,
			install = {
				area = "TruckBed",
				use = {
					MetalPipe = 6,
					SheetMetal = 6,
					MetalBar=4,
					BlowTorch = 10,
					Screws=12,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					MetalWelding = 4,
				},
				requireUninstalled = {"ATA2RoofTaxiAdvert", "ATA2RoofLightbar", "ATA2Megaphone"},
				time = SVUC.timeMods, 
			},
			uninstall = {
				area = "TruckBed",
				animation = "ATA_IdleLeverOpenHigh",
				use = {
					BlowTorch=8,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					both = "Base.Crowbar",
				},
				skills = {
					MetalWelding = 3,
				},
				result = "auto",
				time = SVUC.timeMods,
			}
		}
	}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2InteractiveTrunkRoofRackLightbar"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2InteractiveTrunkRoofRack"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2InteractiveTrunkRoofRackLightbar"].Default.install.requireUninstalled = {"ATA2RoofTaxiAdvert", "ATA2Megaphone"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiSign"] = {
		Default = {
			icon = "media/ui/tuning2/roof_base.png",
			category = SVUC.protectionMods,
			name = "IGUI_VehiclePartATA2RoofTaxiSign",
			spawnChance = 100,
			install = {
				area = "Engine",
				use = {
					MetalPipe = 2,
					SheetMetal = 1,
					MetalBar=2,
					Screws=6,
				},
				tools = {
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					Mechanics = 2,
					MetalWelding = 3,
				},
				requireUninstalled = {"ATA2RoofLightFront"},
				time = SVUC.timeMods, 
			},
			uninstall = {
				area = "Engine",
				animation = "ATA_IdleLeverOpenHigh",
				tools = {
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					Mechanics = 2,
					MetalWelding = 2,
				},
				result = {
					MetalPipe = 1,
					SheetMetal = 1,
					MetalBar=1,
					Screws=2,
				},
				time = SVUC.timeMods,
			}
		}
	}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiAdvert"] = {}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiAdvert"].WokNRolls = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiSign"].Default)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiAdvert"].WokNRolls.name = "IGUI_VehiclePartATA2RoofTaxiAdvertWokNRolls"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiAdvert"].WokNRolls.spawnChance = 25
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiAdvert"].WokNRolls.install.requireUninstalled = {"ATA2InteractiveTrunkRoofRack", "ATA2Megaphone"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiAdvert"].Spiffo = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiSign"].Default)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiAdvert"].Spiffo.name = "IGUI_VehiclePartATA2RoofTaxiAdvertSpiffo"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiAdvert"].Spiffo.spawnChance = 25
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiAdvert"].Spiffo.install.requireUninstalled = {"ATA2InteractiveTrunkRoofRack", "ATA2Megaphone"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiAdvert"].Insurance = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiSign"].Default)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiAdvert"].Insurance.name = "IGUI_VehiclePartATA2RoofTaxiAdvertInsurance"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiAdvert"].Insurance.spawnChance = 25
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofTaxiAdvert"].Insurance.install.requireUninstalled = {"ATA2InteractiveTrunkRoofRack", "ATA2Megaphone"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"] = {
		Normal = {
			icon = "media/ui/tuning2/roof_base.png",
			category = SVUC.protectionMods,
			name = "IGUI_VehiclePartATA2RoofLightbarNormal",
			spawnChance = 35,
			install = {
				area = "Engine",
				use = {
					ATA2__ATAFrontRoofLightItem = 1,
					MetalPipe = 2,
					SheetMetal = 1,
					MetalBar=2,
					Screws=6,
				},
				tools = {
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					Mechanics = 2,
					MetalWelding = 3,
				},
				requireUninstalled = {"ATA2InteractiveTrunkRoofRack", "ATA2Megaphone"},
				time = SVUC.timeMods, 
			},
			uninstall = {
				area = "Engine",
				animation = "ATA_IdleLeverOpenHigh",
				tools = {
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					Mechanics = 2,
					MetalWelding = 2,
				},
				result = {
					ATA2__ATAFrontRoofLightItem = 1,
					MetalPipe = 1,
					SheetMetal = 1,
					MetalBar=1,
					Screws=2,
				},
				time = SVUC.timeMods,
			}
		}
	}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Box1 = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Box1.name = "IGUI_VehiclePartATA2RoofLightbarBox1"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Box2 = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Box2.name = "IGUI_VehiclePartATA2RoofLightbarBox2"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Box3 = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Box3.name = "IGUI_VehiclePartATA2RoofLightbarBox3"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Single = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Single.name = "IGUI_VehiclePartATA2RoofLightbarSingle"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Double = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Double.name = "IGUI_VehiclePartATA2RoofLightbarDouble"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].VShaped1 = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].VShaped1.name = "IGUI_VehiclePartATA2RoofLightbarV1"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].VShaped2 = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].VShaped2.name = "IGUI_VehiclePartATA2RoofLightbarV2"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Flat1 = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Flat1.name = "IGUI_VehiclePartATA2RoofLightbarFlat1"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Flat2 = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Flat2.name = "IGUI_VehiclePartATA2RoofLightbarFlat2"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2Megaphone"] = {}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Megaphone"].Megaphone = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Megaphone"].Megaphone.name = "IGUI_VehiclePartATA2RoofLightbarMegaphone"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Megaphone"].Megaphone.spawnChance = 0
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Megaphone"].Megaphone.install.use = {MetalPipe = 2,SheetMetal = 1,MetalBar=2,Screws=6,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Megaphone"].Megaphone.install.requireUninstalled = {"ATA2RoofLightbar", "ATA2RoofTaxiSign", "ATA2InteractiveTrunkRoofRack", "ATA2InteractiveTrunkRoofRackLightbar"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Megaphone"].Megaphone.uninstall.result = {MetalPipe = 1,SheetMetal = 1,MetalBar=1,Screws=2,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Megaphone"].MegaphoneRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Megaphone"].MegaphoneRusted.name = "IGUI_VehiclePartATA2RoofLightbarMegaphoneRusted"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Megaphone"].MegaphoneRusted.spawnChance = 0
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Megaphone"].MegaphoneRusted.install.use = {MetalPipe = 2,SheetMetal = 1,MetalBar=2,Screws=6,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Megaphone"].MegaphoneRusted.install.requireUninstalled = {"ATA2RoofLightbar", "ATA2RoofTaxiSign", "ATA2InteractiveTrunkRoofRack", "ATA2InteractiveTrunkRoofRackLightbar"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Megaphone"].MegaphoneRusted.uninstall.result = {MetalPipe = 1,SheetMetal = 1,MetalBar=1,Screws=2,}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbarRoofRack"] = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"])
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbarRoofRack"].Normal.install.requireUninstalled = {"ATA2Megaphone"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbarRoofRack"].Box1.install.requireUninstalled = {"ATA2Megaphone"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbarRoofRack"].Box2.install.requireUninstalled = {"ATA2Megaphone"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbarRoofRack"].Box3.install.requireUninstalled = {"ATA2Megaphone"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbarRoofRack"].Single.install.requireUninstalled = {"ATA2Megaphone"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbarRoofRack"].Double.install.requireUninstalled = {"ATA2Megaphone"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbarRoofRack"].VShaped1.install.requireUninstalled = {"ATA2Megaphone"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbarRoofRack"].VShaped2.install.requireUninstalled = {"ATA2Megaphone"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbarRoofRack"].Flat1.install.requireUninstalled = {"ATA2Megaphone"}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightbarRoofRack"].Flat2.install.requireUninstalled = {"ATA2Megaphone"}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"] = {
		Left = {
			icon = "media/ui/tuning2/roof_base.png",
			category = SVUC.protectionMods,
			name = "IGUI_VehiclePartATA2PoliceAntennaLeft",
			spawnChance = 100,
			removeIfBroken = true,
			install = {
				area = "Engine",
				use = {
					SteelBar = 2,
					SteelPiece = 2,
					Screws=6,
				},
				tools = {
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					Mechanics = 2,
					MetalWelding = 1,
					Electricity = 1,
				},
				time = SVUC.timeMods, 
			},
			uninstall = {
				area = "Engine",
				animation = "ATA_IdleLeverOpenHigh",
				tools = {
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					Mechanics = 1,
					MetalWelding = 1,
				},
				result = "auto",
				time = SVUC.timeMods,
			}
		}
	}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"].Center = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"].Left)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"].Center.name = "IGUI_VehiclePartATA2PoliceAntennaCenter"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"].Right = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"].Left)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"].Right.name = "IGUI_VehiclePartATA2PoliceAntennaRight"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"].Outer = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"].Left)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"].Outer.name = "IGUI_VehiclePartATA2PoliceAntennaOuter"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"].Full = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"].Left)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"].Full.name = "IGUI_VehiclePartATA2PoliceAntennaFull"

    TemplateTuningTable["TemplateVehicle"].parts["ATA2RadioAntenna"] = {}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RadioAntenna"].Default = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2PoliceAntenna"].Left)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2RadioAntenna"].Default.name = "IGUI_VehiclePartATA2RadioAntenna"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"] = {
		Default = {
			icon = "media/ui/tuning2/roof_light.png",
			modelList = {"SecondModel"},
			category = SVUC.protectionMods,
			install = {
				area = "Engine",
				transmitFirstItemCondition = true,
				use = {
					ATA2__ATAFrontRoofLightItem = 1,
					Screws=8,
				},
				tools = {
					primary = "Base.Screwdriver",
				},
				skills = {
					Mechanics = 2,
					MetalWelding = 3,
				},
				requireUninstalled = {"ATA2RoofTaxiSign"},
				time = SVUC.timeMods,
			},
			uninstall = {
				area = "Engine",
				tools = {
					primary = "Base.Screwdriver",
				},
				skills = {
					Mechanics = 2,
					MetalWelding = 2,
				},
				transmitConditionOnFirstItem = true,
				result = {
					ATA2__ATAFrontRoofLightItem = 1,
				},
				time = SVUC.timeMods,
			}
		}
	}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"] = {
		ATAProtection = {
			removeIfBroken = true,
			icon = "media/ui/tuning2/wheel_chain.png",
			category = SVUC.protectionMods, 
			protectionModel = true,
			protection = {"TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight"}, 
			protectionHealthDelta = SVUC.protectionWheelsHealthDelta,
			protectionTriger = SVUC.protectionHealthTriger,
			install = {
				area = "TireFrontLeft",
				sound = "ATA2InstallWheelChain",
				use = { 
					ATAProtectionWheelsChain = 1,
					BlowTorch = 4,
				},
				tools = { 
					bodylocation = "Base.WeldingMask", 
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					Mechanics = 2,
					MetalWelding = 3,
				},
				requireInstalled = {"TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight"},
				time = SVUC.timeWheels, 
			},
			uninstall = {
				area = "TireFrontLeft",
				sound = "ATA2InstallWheelChain",
				use = {
					BlowTorch=4,
				},
				tools = {
					bodylocation = "Base.WeldingMask",
					both = "Base.Crowbar",
				},
				skills = {
					Mechanics = 2,
					MetalWelding = 2,
				},
				result = {
					UnusableMetal=2,
				},
				time = SVUC.timeWheels,
			}
		}
	}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"] = {
		Small = {
			icon = "media/ui/tuning2/delorean_protection_hood_bttf.png",
			category = SVUC.protectionEngineMods,
			name = "IGUI_VehiclePartATA2AirScoopSmall",
			engineUpgrade = true,
			powerIncrease = SVUC.protectionEngineSmallPowerIncrease,
			install = {
				area = "Engine",
				use = {
					MetalPipe = 6,
					SheetMetal = 2,
					MetalBar=4,
					BlowTorch = 10,
					Screws=12,
				},
				tools = {
					bodylocation = "Base.WeldingMask", 
					primary = "Base.Wrench",
					secondary = "Base.Screwdriver",
				},
				skills = {
					Mechanics = 2,
					MetalWelding = 3,
				},
				requireInstalled = {"EngineDoor"},
				requireUninstalled = {"ATA2ProtectionHood"},
				time = SVUC.timeMods,
			},
			uninstall = {
				area = "Engine",
				tools = {
					bodylocation = "Base.WeldingMask", 
					both = "Base.Crowbar",
				},
				skills = {
					Mechanics = 2,
					MetalWelding = 2,
				},
				result = "auto",
				time = SVUC.timeMods,
				requireUninstalled = {"ATA2ProtectionHood"},
			}
		}
	}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].SmallRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Small)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].SmallRusted.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].SmallRusted.name = "IGUI_VehiclePartATA2AirScoopSmallRusted"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Small)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium.name = "IGUI_VehiclePartATA2AirScoopMedium"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium.powerIncrease = SVUC.protectionEngineMediumPowerIncrease
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium.install.use = {MetalPipe = 6, SheetMetal = 4, MetalBar=4, BlowTorch = 10, Screws=12,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium.install.skills = {Mechanics = 3, MetalWelding = 4}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium.uninstall.skills = {Mechanics = 3, MetalWelding = 3}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].MediumRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].MediumRusted.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].MediumRusted.name = "IGUI_VehiclePartATA2AirScoopMediumRusted"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Small)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large.name = "IGUI_VehiclePartATA2AirScoopLarge"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large.powerIncrease = SVUC.protectionEngineLargePowerIncrease
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large.install.use = {MetalPipe = 8, SheetMetal = 6, MetalBar=4, BlowTorch = 10, Screws=12,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large.install.skills = {Mechanics = 4, MetalWelding = 5}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large.uninstall.skills = {Mechanics = 4, MetalWelding = 4}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].LargeRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].LargeRusted.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].LargeRusted.name = "IGUI_VehiclePartATA2AirScoopLargeRusted"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Small)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped.name = "IGUI_VehiclePartATA2AirScoopPiped"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped.powerIncrease = SVUC.protectionEnginePipedPowerIncrease
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped.install.use = {MetalPipe = 12, SheetMetal = 6, MetalBar=4, BlowTorch = 10, Screws=12,}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped.install.skills = {Mechanics = 5, MetalWelding = 6}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped.uninstall.skills = {Mechanics = 5, MetalWelding = 5}

	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].PipedRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].PipedRusted.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].PipedRusted.name = "IGUI_VehiclePartATA2AirScoopPipedRusted"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].SmallRound = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Small)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].SmallRound.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].SmallRound.name = "IGUI_VehiclePartATA2AirScoopSmallRound"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].SmallRoundRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].SmallRound)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].SmallRoundRusted.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].SmallRoundRusted.name = "IGUI_VehiclePartATA2AirScoopSmallRoundRusted"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].LargeRound = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].LargeRound.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].LargeRound.name = "IGUI_VehiclePartATA2AirScoopLargeRound"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].LargeRoundRusted = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].LargeRound)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].LargeRoundRusted.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].LargeRoundRusted.name = "IGUI_VehiclePartATA2AirScoopLargeRoundRusted"

	TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"] = {}
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"].SnorkelLeft = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Small)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"].SnorkelLeft.icon = "media/ui/tuning2/snorkel.png"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"].SnorkelLeft.name = "IGUI_VehiclePartATA2SnorkelLeft"
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"].SnorkelLeft.powerIncrease = SVUC.protectionEngineSnorkelPowerIncrease
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"].SnorkelLeft.install.requireUninstalled = nil
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"].SnorkelLeft.uninstall.requireUninstalled = nil

	TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"].SnorkelRight = copy(TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"].SnorkelLeft)
	TemplateTuningTable["TemplateVehicle"].parts["ATA2Snorkel"].SnorkelRight.name = "IGUI_VehiclePartATA2SnorkelRight"

	return TemplateTuningTable
end
Events.OnInitGlobalModData.Add(SVUC_TemplateVehicle)

function SVUC_setVehiclePickup(tuningtable, vehicle)
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].Light.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].Heavy.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].LightRusted.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].HeavyRusted.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].LightSpiked.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].HeavySpiked.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].LightSpikedRusted.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].HeavySpikedRusted.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].Reinforced.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].ReinforcedRusted.protection = {"TruckBedOpen", "GasTank"}
end
function SVUC_setVehiclePickupTruck(tuningtable, vehicle)
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].Light.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].Heavy.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].LightRusted.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].HeavyRusted.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].LightSpiked.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].HeavySpiked.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].LightSpikedRusted.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].HeavySpikedRusted.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].Reinforced.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].ReinforcedRusted.protection = {"TruckBedOpen", "GasTank"}
end
function SVUC_setVehiclePickupTrunkDoor(tuningtable, vehicle)
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].Light.protection = {"TrunkDoor", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].Heavy.protection = {"TrunkDoor", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].LightRusted.protection = {"TrunkDoor", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].HeavyRusted.protection = {"TrunkDoor", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].LightSpiked.protection = {"TrunkDoor", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].HeavySpiked.protection = {"TrunkDoor", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].LightSpikedRusted.protection = {"TrunkDoor", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].HeavySpikedRusted.protection = {"TrunkDoor", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].Reinforced.protection = {"TrunkDoor", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionTrunk"].ReinforcedRusted.protection = {"TrunkDoor", "TruckBedOpen", "GasTank"}
end
function SVUC_setVehiclePickupDoorsRear(tuningtable, vehicle)
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].Light.protection = {"DoorRear", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].Heavy.protection = {"DoorRear", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].LightRusted.protection = {"DoorRear", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].HeavyRusted.protection = {"DoorRear", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].LightSpiked.protection = {"DoorRear", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].HeavySpiked.protection = {"DoorRear", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].LightSpikedRusted.protection = {"DoorRear", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].HeavySpikedRusted.protection = {"DoorRear", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].Reinforced.protection = {"DoorRear", "TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].ReinforcedRusted.protection = {"DoorRear", "TruckBedOpen", "GasTank"}
end
function SVUC_setVehicleRecipesArmor(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Light.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Heavy.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LightRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].HeavyRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LightSpiked.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].HeavySpiked.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LightSpikedRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].HeavySpikedRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Reinforced.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].ReinforcedRusted.install.recipes = {carRecipe}
end
function SVUC_setVehicleRecipesArmorHood(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Light.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Heavy.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LightRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].HeavyRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LightSpiked.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].HeavySpiked.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LightSpikedRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].HeavySpikedRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Reinforced.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].ReinforcedRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LightScoop.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].HeavyScoop.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LightRustedScoop.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].HeavyRustedScoop.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LightSpikedScoop.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].HeavySpikedScoop.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LightSpikedRustedScoop.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].HeavySpikedRustedScoop.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].ReinforcedScoop.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].ReinforcedRustedScoop.install.recipes = {carRecipe}
end
function SVUC_setVehicleRecipesBullbars(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Small.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Medium.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Large.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LargeSpiked.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Plow.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].PlowRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].PlowSpiked.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].PlowSpikedRusted.install.recipes = {carRecipe}
end
function SVUC_setVehicleRecipesBullbarsTruck(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Truck.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Small.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Medium.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Large.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LargeSpiked.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Plow.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].PlowRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].PlowSpiked.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].PlowSpikedRusted.install.recipes = {carRecipe}
end
function SVUC_setVehicleRecipesMods(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Default.install.recipes = {carRecipe}
end
function SVUC_setVehicleRecipesWheels(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].ATAProtection.install.recipes = {carRecipe}
end
function SVUC_setVehicleRecipesScoops(tuningtable, carRecipe, vehicle, part)
--	tuningtable[vehicle].parts[part].None.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Small.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].SmallRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Medium.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].MediumRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Large.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LargeRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Piped.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].PipedRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].SmallRound.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].SmallRoundRusted.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LargeRound.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LargeRoundRusted.install.recipes = {carRecipe}
end
function SVUC_setVehicleRecipesSnorkels(tuningtable, carRecipe, vehicle, part)
--	tuningtable[vehicle].parts[part].SnorkelNone.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].SnorkelLeft.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].SnorkelRight.install.recipes = {carRecipe}
end
function SVUC_setVehicleRecipesRoofLightbar(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Normal.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Box1.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Box2.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Box3.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Single.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Double.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].VShaped1.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].VShaped2.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Flat1.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Flat2.install.recipes = {carRecipe}
	--tuningtable[vehicle].parts[part].Megaphone.install.recipes = {carRecipe}
	--tuningtable[vehicle].parts[part].MegaphoneRusted.install.recipes = {carRecipe}
end
function SVUC_setVehicleRecipesMegaphone(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Megaphone.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].MegaphoneRusted.install.recipes = {carRecipe}
end
function SVUC_setVehicleRecipesPoliceAntenna(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Left.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Center.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Right.install.recipes = {carRecipe}
    tuningtable[vehicle].parts[part].Outer.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Full.install.recipes = {carRecipe}
end
function SVUC_setVehicleRecipesRoofTaxiAdvert(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].WokNRolls.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Spiffo.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Insurance.install.recipes = {carRecipe}
end
