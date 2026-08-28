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
function SVU_ATAPetyarbuilt_TemplateVehicle()
	local SVUC = {}
	SVUC.protectionHealthTriger = SVUC_SandboxVars("protectionHealthTriger")
	SVUC.protectionLightHealthDelta = SVUC_SandboxVars("protectionLightHealthDelta")
	SVUC.protectionHeavyHealthDelta = SVUC_SandboxVars("protectionHeavyHealthDelta")
	SVUC.protectionReinforcedHealthDelta = SVUC_SandboxVars("protectionReinforcedHealthDelta")
	SVUC.protectionBullbarSmallHealthDelta = SVUC_SandboxVars("protectionBullbarLargeHealthDelta")*1.1
	SVUC.protectionPlowHealthDelta = SVUC_SandboxVars("protectionPlowHealthDelta")*1.1
	SVUC.protectionWheelsHealthDelta = SVUC_SandboxVars("protectionWheelsHealthDelta")
	SVUC.protectionEngineSmallPowerIncrease = 500
	SVUC.protectionEngineMediumPowerIncrease = 1350
	SVUC.protectionEngineLargePowerIncrease = 25000
	SVUC.protectionEnginePipedPowerIncrease = 25000
	SVUC.protectionMods = "protectionMods"
	SVUC.protectionEngineMods = SVUC.protectionMods
	SVUC.protectionLight = "protectionLight"
	SVUC.protectionHeavy = "protectionHeavy"
	SVUC.protectionReinforced = "protectionReinforced"

	ATAPetyarbuiltTuningTable = {}
	-- Entries
	ATAPetyarbuiltTuningTable["TemplateVehicle"] = {
		addPartsFromVehicleScript = "",
		parts = {}
	}

	-- TemplateVehicle
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"] = {
		Small = {
			icon = "media/ui/tuning2/mustang_bullbar_1.png",
			name = "IGUI_ATA2_Bullbar_Truck",
			category = SVUC.protectionMods,
			protection = {"HeadlightLeft", "HeadlightRight", "EngineDoor","Windshield"},
			protectionHealthDelta = SVUC.protectionBullbarLargeHealthDelta,
			protectionTriger = SVUC.protectionHealthTriger,
			removeIfBroken = true,
			install = {
				weight = "auto",
				animation = "ATA_PickLock",
				use = {
					MetalPipe = 6,
					MetalBar=6,
					Screws=24,
					BlowTorch = 8,
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
				time = 35, 
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
				time = 15,
			}
		}
	}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Small)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow.icon = "media/ui/tuning2/van_bullbar_3.png"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow.name = "IGUI_ATA2_Plow"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow.protectionHealthDelta = SVUC.protectionPlowHealthDelta
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow.install.use = {MetalPipe = 4, SheetMetal = 4, MetalBar=4, Screws=6, BlowTorch = 5,}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow.install.times = 60
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow.install.skills = {MetalWelding = 8, Mechanics = 6}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow.uninstall.skills = {MetalWelding = 7}

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpiked = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].Plow)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpiked.name = "IGUI_ATA2_Plow_Spiked"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpiked.install.use = {MetalPipe = 4, SheetMetal = 4, MetalBar=4, Screws=6, BlowTorch = 5,}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpiked.install.times = 60
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpiked.install.skills = {MetalWelding = 8, Mechanics = 6}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"].PlowSpiked.uninstall.skills = {MetalWelding = 7}


	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"] = {
		Light = {
			icon = "media/ui/tuning2/protection_window_side.png",
			name = "IGUI_VehiclePartATA2ProtectionWindowFrontLeftLight",
			category = SVUC.protectionLight,
			protection = {"WindowFrontLeft"},
			protectionHealthDelta = SVUC.protectionLightHealthDelta,
			protectionTriger = SVUC.protectionHealthTriger,
			removeIfBroken = true,
			install = {
				area = "SeatFrontLeft",
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
				time = 25,
			},
			uninstall = {
				area = "SeatFrontLeft",
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
				time = 15,
			}
		}
	}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Light)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.icon = "media/ui/tuning2/protection_window_sheet_side.png"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindowFrontLeftHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.category = SVUC.protectionHeavy
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.disableOpenWindowFromSeat = "SeatFrontLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.protectionHealthDelta = SVUC.protectionHeavyHealthDelta
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.install.use = {MetalPipe = 4, SheetMetal = 2, MetalBar=3, Screws=6, BlowTorch = 5,}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.install.skills = {MetalWelding = 6}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.install.time = 35
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.uninstall.skills = {MetalWelding = 5}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy.uninstall.time = 20

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Heavy)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindowFrontLeftReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.category = SVUC.protectionReinforced
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.protectionHealthDelta = SVUC.protectionReinforcedHealthDelta
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.install.use = {MetalPipe = 4, SheetMetal = 3, MetalBar=3, Screws=6, BlowTorch = 5,}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.install.skills = {MetalWelding = 8}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.install.time = 40
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.uninstall.skills = {MetalWelding = 7}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"].Reinforced.uninstall.time = 25

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Light.name = "IGUI_VehiclePartATA2ProtectionWindowFrontRightLight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Light.protection = {"WindowFrontRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Light.install.requireInstalled = {"WindowFrontRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Light.install.area = "SeatFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Light.uninstall.area = "SeatFrontRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindowFrontRightHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Heavy.protection = {"WindowFrontRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Heavy.install.requireInstalled = {"WindowFrontRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Heavy.disableOpenWindowFromSeat = "SeatFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Heavy.install.area = "SeatFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Heavy.uninstall.area = "SeatFrontRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindowFrontRightReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Reinforced.protection = {"WindowFrontRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Reinforced.install.requireInstalled = {"WindowFrontRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Reinforced.disableOpenWindowFromSeat = "SeatFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Reinforced.install.area = "SeatFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"].Reinforced.uninstall.area = "SeatFrontRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Light.name = "IGUI_VehiclePartATA2ProtectionWindowRearLeftLight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Light.protection = {"WindowRearLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Light.install.requireInstalled = {"WindowRearLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Light.install.area = "TireRearLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Light.uninstall.area = "TireRearLeft"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindowRearLeftHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Heavy.protection = {"WindowRearLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Heavy.install.requireInstalled = {"WindowRearLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Heavy.disableOpenWindowFromSeat = "SeatRearLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Heavy.install.area = "TireRearLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Heavy.uninstall.area = "TireRearLeft"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindowRearLeftReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Reinforced.protection = {"WindowRearLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Reinforced.install.requireInstalled = {"WindowRearLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Reinforced.disableOpenWindowFromSeat = "SeatRearLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Reinforced.install.area = "TireRearLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearLeft"].Reinforced.uninstall.area = "TireRearLeft"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Light.name = "IGUI_VehiclePartATA2ProtectionWindowRearRightLight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Light.protection = {"WindowRearRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Light.install.requireInstalled = {"WindowRearRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Light.install.area = "TireRearRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Light.uninstall.area = "TireRearRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindowRearRightHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Heavy.protection = {"WindowRearRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Heavy.install.requireInstalled = {"WindowRearRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Heavy.disableOpenWindowFromSeat = "SeatRearRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Heavy.install.area = "TireRearRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Heavy.uninstall.area = "TireRearRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindowRearRightReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Reinforced.protection = {"WindowRearRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Reinforced.install.requireInstalled = {"WindowRearRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Reinforced.disableOpenWindowFromSeat = "SeatRearRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Reinforced.install.area = "TireRearRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowRearRight"].Reinforced.uninstall.area = "TireRearRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Light.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleLeftLight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Light.protection = {"WindowMiddleLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Light.install.requireInstalled = {"WindowMiddleLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Light.install.area = "TireFrontLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Light.uninstall.area = "TireFrontLeft"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleLeftHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Heavy.protection = {"WindowMiddleLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Heavy.install.requireInstalled = {"WindowMiddleLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Heavy.disableOpenWindowFromSeat = nil
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Heavy.install.area = "TireFrontLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Heavy.uninstall.area = "TireFrontLeft"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleLeftReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Reinforced.protection = {"WindowMiddleLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Reinforced.install.requireInstalled = {"WindowMiddleLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Reinforced.disableOpenWindowFromSeat = nil
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Reinforced.install.area = "TireFrontLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleLeft"].Reinforced.uninstall.area = "TireFrontLeft"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Light.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleRightLight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Light.protection = {"WindowMiddleRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Light.install.requireInstalled = {"WindowMiddleRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Light.install.area = "TireFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Light.uninstall.area = "TireFrontRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleRightHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Heavy.protection = {"WindowMiddleRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Heavy.install.requireInstalled = {"WindowMiddleRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Heavy.disableOpenWindowFromSeat = nil
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Heavy.install.area = "TireFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Heavy.uninstall.area = "TireFrontRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindowMiddleRightReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Reinforced.protection = {"WindowMiddleRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Reinforced.install.requireInstalled = {"WindowMiddleRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Reinforced.disableOpenWindowFromSeat = nil
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Reinforced.install.area = "TireFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowMiddleRight"].Reinforced.uninstall.area = "TireFrontRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"] = {
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
				time = 30,
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
				time = 15,
			}
		}
	}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Light)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.icon = "media/ui/tuning2/protection_window_sheet_windshield.png"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindshieldHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.category = SVUC.protectionHeavy
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.protectionHealthDelta = SVUC.protectionHeavyHealthDelta
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.install.use = {MetalPipe = 4, SheetMetal = 2, MetalBar=3, Screws=6, BlowTorch = 5,}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.install.skills = {MetalWelding = 6}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.install.time = 40
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.uninstall.skills = {MetalWelding = 5}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy.uninstall.time = 20

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Heavy)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindshieldReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.category = SVUC.protectionReinforced
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.protectionHealthDelta = SVUC.protectionReinforcedHealthDelta
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.install.use = {MetalPipe = 4, SheetMetal = 3, MetalBar=3, Screws=6, BlowTorch = 5,}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.install.skills = {MetalWelding = 8}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.install.time = 45
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.uninstall.skills = {MetalWelding = 7}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"].Reinforced.uninstall.time = 25

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshield"])
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Light.name = "IGUI_VehiclePartATA2ProtectionWindshieldRearLight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Light.protection = {"WindshieldRear"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Light.install.requireInstalled = {"WindshieldRear"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Light.install.area = "TireRearRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Light.uninstall.area = "TireRearRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Heavy.name = "IGUI_VehiclePartATA2ProtectionWindshieldRearHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Heavy.protection = {"WindshieldRear"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Heavy.install.requireInstalled = {"WindshieldRear"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Heavy.install.area = "TireRearRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Heavy.uninstall.area = "TireRearRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionWindshieldRearReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Reinforced.protection = {"WindshieldRear"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Reinforced.install.requireInstalled = {"WindshieldRear"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Reinforced.install.area = "TireRearRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindshieldRear"].Reinforced.uninstall.area = "TireRearRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"] = {
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
				time = 35,
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
				time = 25,
			}
		}
	}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Light)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.icon = "media/ui/tuning2/van_hood_protection.png"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.name = "IGUI_VehiclePartATA2ProtectionDoorFrontLeftHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.category = SVUC.protectionHeavy
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.protectionHealthDelta = SVUC.protectionHeavyHealthDelta
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.install.use = {MetalPipe = 4, SheetMetal = 2, MetalBar=3, Screws=6, BlowTorch = 5,}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.install.skills = {MetalWelding = 6}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.install.time = 40
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.uninstall.skills = {MetalWelding = 5}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy.uninstall.time = 30

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Heavy)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionDoorFrontLeftReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.category = SVUC.protectionReinforced
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.protectionHealthDelta = SVUC.protectionReinforcedHealthDelta
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.install.use = {MetalPipe = 4, SheetMetal = 3, MetalBar=3, Screws=6, BlowTorch = 5,}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.install.skills = {MetalWelding = 8}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.install.time = 45
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.uninstall.skills = {MetalWelding = 7}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"].Reinforced.uninstall.time = 35

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Light.name = "IGUI_VehiclePartATA2ProtectionDoorFrontRightLight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Light.protection = {"DoorFrontRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Light.install.requireInstalled = {"DoorFrontRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Light.install.area = "TireFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Light.uninstall.area = "TireFrontRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Heavy.protection = {"DoorFrontRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Heavy.name = "IGUI_VehiclePartATA2ProtectionDoorFrontRightHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Heavy.install.requireInstalled = {"DoorFrontRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Heavy.install.area = "TireFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Heavy.uninstall.area = "TireFrontRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Reinforced.protection = {"DoorFrontRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionDoorFrontRightReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Reinforced.install.requireInstalled = {"DoorFrontRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Reinforced.install.area = "TireFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"].Reinforced.uninstall.area = "TireFrontRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Light.name = "IGUI_VehiclePartATA2ProtectionDoorRearLeftLight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Light.protection = {"DoorRearLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Light.install.requireInstalled = {"DoorRearLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Light.install.area = "TireRearLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Light.uninstall.area = "TireRearLeft"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Heavy.protection = {"DoorRearLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Heavy.name = "IGUI_VehiclePartATA2ProtectionDoorRearLeftHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Heavy.install.requireInstalled = {"DoorRearLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Heavy.install.area = "TireRearLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Heavy.uninstall.area = "TireRearLeft"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionDoorRearLeftReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Reinforced.protection = {"DoorRearLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Reinforced.install.requireInstalled = {"DoorRearLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Reinforced.install.area = "TireRearLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearLeft"].Reinforced.uninstall.area = "TireRearLeft"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Light.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleLeftLight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Light.protection = {"DoorMiddleLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Light.install.requireInstalled = {"DoorMiddleLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Light.install.area = "TireFrontLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Light.uninstall.area = "TireFrontLeft"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Heavy.protection = {"DoorMiddleLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Heavy.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleLeftHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Heavy.install.requireInstalled = {"DoorMiddleLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Heavy.install.area = "TireFrontLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Heavy.uninstall.area = "TireFrontLeft"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleLeftReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Reinforced.protection = {"DoorMiddleLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Reinforced.install.requireInstalled = {"DoorMiddleLeft"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Reinforced.install.area = "TireFrontLeft"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleLeft"].Reinforced.uninstall.area = "TireFrontLeft"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Light.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleRightLight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Light.protection = {"DoorMiddleRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Light.install.requireInstalled = {"DoorMiddleRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Light.install.area = "TireFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Light.uninstall.area = "TireFrontRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Heavy.protection = {"DoorMiddleRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Heavy.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleRightHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Heavy.install.requireInstalled = {"DoorMiddleRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Heavy.install.area = "TireFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Heavy.uninstall.area = "TireFrontRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionDoorMiddleRightReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Reinforced.protection = {"DoorMiddleRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Reinforced.install.requireInstalled = {"DoorMiddleRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Reinforced.install.area = "TireFrontRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorMiddleRight"].Reinforced.uninstall.area = "TireFrontRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Light.name = "IGUI_VehiclePartATA2ProtectionDoorRearRightLight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Light.protection = {"DoorRearRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Light.install.requireInstalled = {"DoorRearRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Light.install.area = "TireRearRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Light.uninstall.area = "TireRearRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Heavy.protection = {"DoorRearRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Heavy.name = "IGUI_VehiclePartATA2ProtectionDoorRearRightHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Heavy.install.requireInstalled = {"DoorRearRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Heavy.install.area = "TireRearRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Heavy.uninstall.area = "TireRearRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Reinforced.name = "IGUI_VehiclePartATA2ProtectionDoorRearRightReinforced"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Reinforced.protection = {"DoorRearRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Reinforced.install.requireInstalled = {"DoorRearRight"}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Reinforced.install.area = "TireRearRight"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorRearRight"].Reinforced.uninstall.area = "TireRearRight"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"] = {
		Normal = {
			icon = "media/ui/tuning2/roof_base.png",
			category = SVUC.protectionMods,
			name = "IGUI_VehiclePartATA2RoofLightbarNormal",
			spawnChance = 50,
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
				time = 25, 
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
				time = 15,
			}
		}
	}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Box1 = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Box1.name = "IGUI_VehiclePartATA2RoofLightbarBox1"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Box1.spawnChance = 25
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Box2 = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Box2.name = "IGUI_VehiclePartATA2RoofLightbarBox2"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Box2.spawnChance = 50
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Single = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Single.name = "IGUI_VehiclePartATA2RoofLightbarSingle"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Single.spawnChance = 25
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Double = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Double.name = "IGUI_VehiclePartATA2RoofLightbarDouble"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Double.spawnChance = 25
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].VShaped1 = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].VShaped1.name = "IGUI_VehiclePartATA2RoofLightbarV1"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].VShaped1.spawnChance = 50
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].VShaped2 = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].Normal)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].VShaped2.name = "IGUI_VehiclePartATA2RoofLightbarV2"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightbar"].VShaped2.spawnChance = 50

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2RoofLightFront"] = {
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
				time = 25,
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
				time = 15,
			}
		}
	}

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"] = {
		ATAProtection = {
			removeIfBroken = true,
			icon = "media/ui/tuning2/wheel_chain.png",
			category = SVUC.protectionMods, 
			protectionModel = true,
			protection = {"TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight", "TireMiddleRight", "TireMiddleLeft"}, 
			protectionHealthDelta = SVUC.protectionWheelsHealthDelta,
			protectionTriger = SVUC.protectionHealthTriger,
			install = {
				area = "TireFrontLeft",
				sound = "ATA2InstallWheelChain",
				use = { 
					ATA2__ATAProtectionWheelsChain = 1,
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
				requireInstalled = {"TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight", "TireMiddleRight", "TireMiddleLeft"}, 
				time = 35, 
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
				time = 15,
			}
		}
	}

--[[ 	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"] = {
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
				time = 60,
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
				time = 15,
				requireUninstalled = {"ATA2ProtectionHood"},
			}
		}
	}

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].SmallRound = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Small)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].SmallRound.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].SmallRound.name = "IGUI_VehiclePartATA2AirScoopSmallRound"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Small)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium.name = "IGUI_VehiclePartATA2AirScoopMedium"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium.powerIncrease = SVUC.protectionEngineMediumPowerIncrease
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium.install.use = {MetalPipe = 6, SheetMetal = 4, MetalBar=4, BlowTorch = 10, Screws=12,}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium.install.skills = {Mechanics = 3, MetalWelding = 4}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Medium.uninstall.skills = {Mechanics = 3, MetalWelding = 3}

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Small)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large.name = "IGUI_VehiclePartATA2AirScoopLarge"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large.powerIncrease = SVUC.protectionEngineLargePowerIncrease
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large.install.use = {MetalPipe = 8, SheetMetal = 6, MetalBar=4, BlowTorch = 10, Screws=12,}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large.install.skills = {Mechanics = 4, MetalWelding = 5}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large.uninstall.skills = {Mechanics = 4, MetalWelding = 4}

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].LargeRound = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Large)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].LargeRound.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].LargeRound.name = "IGUI_VehiclePartATA2AirScoopLargeRound"

	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Small)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped.icon = "media/ui/tuning2/delorean_protection_hood_bttf.png"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped.name = "IGUI_VehiclePartATA2AirScoopPiped"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped.powerIncrease = SVUC.protectionEnginePipedPowerIncrease
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped.install.use = {MetalPipe = 12, SheetMetal = 6, MetalBar=4, BlowTorch = 10, Screws=12,}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped.install.skills = {Mechanics = 5, MetalWelding = 6}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2AirScoop"].Piped.uninstall.skills = {Mechanics = 5, MetalWelding = 5}
 ]]
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"] = {
		Light = {
			icon = "media/ui/tuning2/bus_protection_window_side.png",
			name = "IGUI_VehiclePartATA2ProtectionTrunkLight",
			secondModel = "StaticPart",
			texture = "Vehicles/puv_parts",
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
				time = 35, 
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
				time = 25,
			}
		}
	}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Heavy = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Light)
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Heavy.name = "IGUI_VehiclePartATA2ProtectionTrunkHeavy"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Heavy.icon = "media/ui/tuning2/van_hood_protection.png"
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Heavy.category = SVUC.protectionMods
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Heavy.protectionHealthDelta = SVUC.protectionHeavyHealthDelta
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Heavy.install.use = {SheetMetal = 4, MetalPipe = 4, MetalBar = 2, Screws = 6, BlowTorch = 4,}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Heavy.install.skills = {MetalWelding = 6}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Heavy.install.time = 35
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Heavy.uninstall.skills = {MetalWelding = 5}
	ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Heavy.uninstall.time = 25




	return ATAPetyarbuiltTuningTable
end
Events.OnInitGlobalModData.Add(SVU_ATAPetyarbuilt_TemplateVehicle)

function SVUC_setATAPetyarbuiltPickup(tuningtable, vehicle)
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].Heavy.protection = {"TruckBedOpen", "GasTank"}
end
function SVUC_setATAPetyarbuiltPickupTruck(tuningtable, vehicle)
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].Heavy.protection = {"TruckBedOpen", "GasTank"}
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].Reinforced.protection = {"TruckBedOpen", "GasTank"}
end
function SVUC_setATAPetyarbuiltPickupTrunkDoor(tuningtable, vehicle)
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].Heavy.protection = {"TrunkDoor", "TruckBedOpen", "GasTank"}
end
function SVUC_setATAPetyarbuiltPickupDoorsRear(tuningtable, vehicle)
	tuningtable[vehicle].parts["ATA2ProtectionDoorsRear"].Heavy.protection = {"DoorRear", "TruckBedOpen", "GasTank"}
end
function SVUC_setATAPetyarbuiltRecipesProtection(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Light.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Heavy.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Reinforced.install.recipes = {carRecipe}
end
--[[ function SVUC_setATAPetyarbuiltRecipesProtectionHood(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Light.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Heavy.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Reinforced.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LightScoop.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].HeavyScoop.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].ReinforcedScoop.install.recipes = {carRecipe}
end ]]
function SVUC_setATAPetyarbuiltRecipesBullbars(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Small.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Plow.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].PlowSpiked.install.recipes = {carRecipe}
end
function SVUC_setATAPetyarbuiltRecipesBullbarsTruck(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Truck.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Small.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Medium.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Large.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LargeSpiked.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Plow.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].PlowSpiked.install.recipes = {carRecipe}
end
function SVUC_setATAPetyarbuiltRecipesMods(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Default.install.recipes = {carRecipe}
end
function SVUC_setATAPetyarbuiltRecipesWheels(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].ATAProtection.install.recipes = {carRecipe}
end
--[[ function SVUC_setATAPetyarbuiltRecipesScoops(tuningtable, carRecipe, vehicle, part)
--	tuningtable[vehicle].parts[part].None.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Small.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Medium.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Large.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Piped.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].SmallRound.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].LargeRound.install.recipes = {carRecipe}
end ]]
function SVUC_setATAPetyarbuiltRecipesRoofLightbar(tuningtable, carRecipe, vehicle, part)
	tuningtable[vehicle].parts[part].Normal.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Box1.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Box2.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Single.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].Double.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].VShaped1.install.recipes = {carRecipe}
	tuningtable[vehicle].parts[part].VShaped2.install.recipes = {carRecipe}
end

local function SVU_ATAPetyarbuilt_TuningTable()
	if not getActivatedMods():contains("SCKCO") and not getActivatedMods():contains("VVSR_Continued") then
		local ATAPetyarbuiltTuningTable = SVU_ATAPetyarbuilt_TemplateVehicle()
		local NewCarTuningTable = {}

		-- Specify each vehicle script here.
		-- Entries
		NewCarTuningTable["ATAPetyarbuilt"] = {
			addPartsFromVehicleScript = "",
			parts = {}
		}
		NewCarTuningTable["ATAPetyarbuiltSleeper"] = {
			addPartsFromVehicleScript = "",
			parts = {}
		}
		NewCarTuningTable["ATAPetyarbuiltSleeperLong"] = {
			addPartsFromVehicleScript = "",
			parts = {}
		}
		NewCarTuningTable["TrailerTSMega"] = {
			addPartsFromVehicleScript = "",
			parts = {}
		}
		NewCarTuningTable["TrailerTSMegaAnimal"] = {
			addPartsFromVehicleScript = "",
			parts = {}
		}

		-- Things are done much cleaner this time around.
		-- Simply follow the format below to assign parts to your vehicles.
		-- Parts HAVE to be defined in the vehicle Protection script!

		-- ATAPetyarbuilt
 		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionWindowFrontLeft"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontLeft"])
		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionWindowFrontRight"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWindowFrontRight"])
		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2Bullbar"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2Bullbar"])

		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionHood"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionHood"])
		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionDoorFrontLeft"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontLeft"])
		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionDoorFrontRight"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorFrontRight"])

		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionWheels"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
	
	
		NewCarTuningTable["TrailerTSMega"].parts["ATA2ProtectionWheels"] = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionWheels"])
		NewCarTuningTable["TrailerTSMega"].parts["ATA2ProtectionWheels"].ATAProtection.protection = {"TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight"}
		NewCarTuningTable["TrailerTSMega"].parts["ATA2ProtectionWheels"].ATAProtection.install.requireInstalled = {"TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight"}
		NewCarTuningTable["TrailerTSMegaAnimal"].parts["ATA2ProtectionWheels"] = {}	
		NewCarTuningTable["TrailerTSMegaAnimal"].parts["ATA2ProtectionWheels"] = copy(NewCarTuningTable["TrailerTSMega"].parts["ATA2ProtectionWheels"])	


		NewCarTuningTable["TrailerTSMega"].parts["ATA2ProtectionDoorsRear"] = {}
		NewCarTuningTable["TrailerTSMega"].parts["ATA2ProtectionDoorsRear"].Heavy = {}
		NewCarTuningTable["TrailerTSMega"].parts["ATA2ProtectionDoorsRear"].Heavy = copy(ATAPetyarbuiltTuningTable["TemplateVehicle"].parts["ATA2ProtectionDoorsRear"].Heavy)
		NewCarTuningTable["TrailerTSMega"].parts["ATA2ProtectionDoorsRear"].Heavy.category = "protectionMods"
		NewCarTuningTable["TrailerTSMega"].parts["ATA2ProtectionDoorsRear"].Heavy.install.requireInstalled = {"DoorRear"}

		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionSideLeft"] = {
			Default = {
				icon = "media/ui/tuning2/petyar_protection_side.png",
				secondModel = "StaticPart",
				category = "Protection",
				protection = {"DoorFrontLeft", "WindowFrontLeft"},
				disableOpenWindowFromSeat = "SeatFrontLeft",
				install = {
					weight = "auto",
					use = {
						MetalPipe = 4,
						MetalBar=4,
						SheetMetal=5,
						Screws=10,
						BlowTorch = 15,
					},
					tools = {
						bodylocation = "Base.WeldingMask",
						primary = "Base.Wrench",
					},
					skills = {
						MetalWelding = 8,
					},
					recipes = {carRecipe},
					requireInstalled = {"WindowFrontLeft"},
					requireUninstalled = {"ATA2ProtectionWindowFrontLeft","ATA2ProtectionDoorFrontLeft"},
					time = 45,
				},
				uninstall = {
					animation = "ATA_IdleLeverOpenMid",
					use = {
						BlowTorch=8,
					},
					tools = {
						bodylocation = "Base.WeldingMask",
						both = "Base.Crowbar",
					},
					skills = {
						MetalWelding = 4,
					},
					requireUninstalled = {"ATA2ProtectionSideFront", "ATA2ProtectionSideTop"},
					result = "auto",
					time = 35,
				}
			}
		}
		
		
		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionSideRight"] = copy(NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionSideLeft"])
		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionSideRight"].Default.protection = {"DoorFrontRight", "WindowFrontRight"}
		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionSideRight"].Default.disableOpenWindowFromSeat = "SeatFrontRight"
		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionSideRight"].Default.install.requireInstalled = {"WindowFrontRight","DoorFrontRight"}
		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionSideRight"].Default.install.requireUninstalled = {"ATA2ProtectionSideFront", "ATA2ProtectionSideTop","ATA2ProtectionWindowFrontRight","ATA2ProtectionDoorFrontRight"}

		
		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionSideFront"] = {
		Default = {
				icon = "media/ui/tuning2/petyar_protection_front.png",
				secondModel = "StaticPart",
				category = "Protection",
				protection = {"EngineDoor", "HeadlightLeft", "HeadlightRight"},
				install = {
					area = "FrontArea",
					weight = "auto",
					use = {
						MetalPipe = 2,
						MetalBar=4,
						SheetMetal=6,
						Screws=10,
						BlowTorch = 14,
					},
					tools = {
						bodylocation = "Base.WeldingMask",
						primary = "Base.Wrench",
					},
					skills = {
						MetalWelding = 9,
					},
					recipes = {carRecipe},
					requireInstalled = {"ATA2ProtectionSideRight", "ATA2ProtectionSideLeft"},
					requireUninstalled = {"ATA2Bullbar","ATA2ProtectionHood"},
					time = 45,
						},
				uninstall = {
					area = "FrontArea",
					animation = "ATA_IdleLeverOpenMid",
					use = {
						BlowTorch=7,
					},
					tools = {
						bodylocation = "Base.WeldingMask",
						both = "Base.Crowbar",
					},
					skills = {
						MetalWelding = 4,
					},
					requireUninstalled = {"ATA2ProtectionSideTop"},
					result = "auto",
					time = 35,
				}
		}
	}		
		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionSideTop"] = {
			Default = {
				icon = "media/ui/tuning2/petyar_protection_top.png",
				category = "Protection",
				protection = {"Windshield"},
				install = {
					weight = "auto",
					use = {
						MetalPipe = 2,
						SheetMetal=4,
						Screws=10,
						BlowTorch = 14,
					},
					tools = {
						bodylocation = "Base.WeldingMask",
						primary = "Base.Wrench",
					},
					skills = {
						MetalWelding = 10,
					},
					requireUninstalled = {"ATA2ProtectionHood"},
					recipes = {carRecipe},
					time = 45,
				},
				uninstall = {
					animation = "ATA_IdleLeverOpenHigh",
					use = {
						BlowTorch=7,
					},
					tools = {
						bodylocation = "Base.WeldingMask",
						both = "Base.Crowbar",
					},
					skills = {
						MetalWelding = 5,
					},
					requireUninstalled = {"ATA2RoofLightFront", "ATA2RoofLightLeft", "ATA2RoofLightRight","ATA2ProtectionHood"},
					result = "auto",
					time = 35,
				}
			}
		}
		
		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionGasTank"] = {
			Default = {
				icon = "media/ui/tuning2/petyar_protection.png",
				category = "Protection",
				protection = {"GasTank"},
				install = {
					weight = "auto",
					use = {
						MetalPipe = 6,
						MetalBar = 6,
						SheetMetal = 2,
						Screws=10,
						BlowTorch=8,
					},
					tools = {
						bodylocation = "Base.WeldingMask",
						primary = "Base.Wrench",
					},
					skills = {
						MetalWelding = 5,
					},
					requireInstalled = {"GasTank"},
					recipes = {carRecipe},
					time = 45,
				},
				uninstall = {
					animation = "ATA_IdleLeverOpenMid",
					use = {
						BlowTorch=5,
					},
					tools = {
						bodylocation = "Base.WeldingMask",
						both = "Base.Crowbar",
					},
					skills = {
						MetalWelding = 2,
					},
					result = "auto",
					time = 30,
				}
			},
		}
		
		NewCarTuningTable["ATAPetyarbuilt"].parts["ATA2ProtectionSleeper"] = {
			Default = {
				icon = "media/ui/tuning2/petyar_protection_sleeper.png",
				category = "Protection",
				protection = {"WindowRearLeft", "WindowRearRight", "GasTank",},
				install = {
					weight = "auto",
					use = {
						MetalPipe = 6,
						MetalBar = 3,
						SheetMetal = 5,
						Screws=10,
						BlowTorch=18,
					},
					tools = {
						bodylocation = "Base.WeldingMask",
						primary = "Base.Wrench",
					},
					skills = {
						MetalWelding = 10,
					},
					requireInstalled = {"WindowRearLeft", "WindowRearRight", "GasTank",},
					recipes = {carRecipe},
					time = 40,
				},
				uninstall = {
					animation = "ATA_IdleLeverOpenMid",
					use = {
						BlowTorch=9,
					},
					tools = {
						bodylocation = "Base.WeldingMask",
						both = "Base.Crowbar",
					},
					skills = {
						MetalWelding = 5,
					},
					result = "auto",
					time = 25,
				}
			},
		}

		NewCarTuningTable["ATAPetyarbuiltSleeper"] = NewCarTuningTable["ATAPetyarbuilt"]
		NewCarTuningTable["ATAPetyarbuiltSleeperLong"] = NewCarTuningTable["ATAPetyarbuilt"]

		ATA2Tuning_AddNewCars(NewCarTuningTable)
	end
end
Events.OnInitGlobalModData.Add(SVU_ATAPetyarbuilt_TuningTable) 