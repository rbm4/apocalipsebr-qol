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

local carRecipe = "ATADodgeRecipes"
local NewCarTuningTable = {}
NewCarTuningTable["ATADodge"] = {
    addPartsFromVehicleScript = "",
    parts = {}
}

NewCarTuningTable["ATADodge"].parts["ATA2ProtectionWindowFrontLeft"] = {
    Default = {
        icon = "media/ui/tuning2/protection_window_side.png",
        secondModel = "StaticPart",
        category = "Protection",
        protection = {"WindowFrontLeft"},
        install = {
            weight = "auto",
            use = {
                MetalPipe = 6,
                SheetMetal = 3,
                MetalBar=7,
                Screws=4,
                BlowTorch = 10,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
                primary = "Base.Wrench",
            },
            skills = {
                MetalWelding = 5,
            },
            recipes = {carRecipe},
            requireInstalled = {"WindowFrontLeft"},
            time = 65,
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
                MetalWelding = 2,
            },
            result = "auto",
            requireUninstalled = {"ATA2BagOnProtectionWindowFrontLeft"},
            time = 40,
        }
    }
}

NewCarTuningTable["ATADodge"].parts["ATA2ProtectionWindowFrontRight"] = copy(NewCarTuningTable["ATADodge"].parts["ATA2ProtectionWindowFrontLeft"])
NewCarTuningTable["ATADodge"].parts["ATA2ProtectionWindowFrontRight"].Default.protection = {"WindowFrontRight"}
NewCarTuningTable["ATADodge"].parts["ATA2ProtectionWindowFrontRight"].Default.install.requireInstalled = {"WindowFrontRight"}
NewCarTuningTable["ATADodge"].parts["ATA2ProtectionWindowFrontRight"].Default.uninstall.requireUninstalled = {"ATA2BagOnProtectionWindowFrontRight"}

NewCarTuningTable["ATADodge"].parts["ATA2ProtectionWindshield"] = {
    Default = {
        removeIfBroken = true,
        icon = "media/ui/tuning2/protection_window_windshield.png",
        category = "Protection",
        protection = {"Windshield"},
        install = {
            area = "InstallWindshield",
            weight = "auto",
            use = {
                MetalPipe = 4,
                MetalBar=8,
                Screws=6,
                BlowTorch = 10,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
                primary = "Base.Screwdriver",
            },
            skills = {
                MetalWelding = 4,
            },
            recipes = {carRecipe},
            requireInstalled = {"Windshield"},
            time = 65,
        },
        uninstall = {
            area = "InstallWindshield",
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
            time = 40,
        }
    }
}

NewCarTuningTable["ATADodge"].parts["ATA2Bullbar"] = {
    ATADodge_Bullbar1 = {
        spawnChance = 20,
        icon = "media/ui/tuning2/dadge_bullbar_1.png",
        name = "IGUI_ATA2_Bullbar_Police",
        category = "Bullbars",
        install = {
            weight = "auto",
            transmitFirstItemCondition = true,
            use = {
                ATA2__ATABullbarPoliceItem1 = 1,
                Screws=6,
            },
            tools = {
                primary = "Base.Wrench",
            },
            skills = {
                Mechanics = 3,
            },
            recipes = {"Advanced Mechanics"},
            time = 30,
        },
        uninstall = {
            animation = "ATA_IdleLeverOpenLow",
            transmitConditionOnFirstItem = true,
            tools = {
                primary = "Base.Crowbar",
            },
            result = {
                ATA2__ATABullbarPoliceItem1=1,
                Screws=3,
            },
            time = 15,
        }
    },
    ATADodge_Bullbar2 = {
        removeIfBroken = true,
        icon = "media/ui/tuning2/dadge_bullbar_2.png",
        name = "IGUI_ATA2_Bullbar_Handmade",
        category = "Bullbars",
        protection = {"HeadlightLeft", "HeadlightRight"},
        install = {
            weight = "auto",
            use = {
                MetalPipe = 4,
                MetalBar=4,
                BlowTorch = 5,
                Screws=6,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
                primary = "Base.Screwdriver",
            },
            skills = {
                Mechanics = 3,
                MetalWelding = 4,
            },
            recipes = {"Advanced Mechanics", carRecipe},
            time = 65,
        },
        uninstall = {
            animation = "ATA_IdleLeverOpenLow",
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
            time = 40,
        }
    },
    ATADodge_Bullbar3 = {
        removeIfBroken = true,
        icon = "media/ui/tuning2/dadge_bullbar_3.png",
        name = "IGUI_ATA2_Bullbar_Lethal",
        category = "Bullbars",
        protection = {"EngineDoor", "HeadlightLeft", "HeadlightRight"},
        install = {
            weight = "auto",
            use = {
                MetalPipe = 3,
                SheetMetal=5,
                MetalBar=6,
                Screws=8,
                BlowTorch = 9,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
                primary = "Base.Screwdriver",
            },
            skills = {
                Mechanics = 3,
                MetalWelding = 7,
            },
            recipes = {"Advanced Mechanics", carRecipe},
            time = 65,
        },
        uninstall = {
            animation = "ATA_IdleLeverOpenLow",
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
            time = 40,
        }
    },
}

NewCarTuningTable["ATADodge"].parts["ATA2InteractiveTrunkRoofRack"] = {
    Default = {
        icon = "media/ui/tuning2/dadge_roof_rack.png",
        category = "Trunks",
        containerCapacity = 65,
        interactiveTrunk = {
            filling = {"Filling1", "Filling2"},
            items = {
                {
                    modelNameByCount = {"Item1"},
                    itemTypes = {"OldTire3", "NormalTire3", "ModernTire3"}
                },
            }
        },
        install = {
            weight = "auto",
            use = {
                MetalPipe = 4,
                SheetMetal = 3,
                MetalBar=4,
                Screws=4,
                BlowTorch = 7,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
                primary = "Base.Screwdriver",
            },
            skills = {
                Mechanics = 3,
                MetalWelding = 5,
            },
            recipes = {carRecipe},
            time = 65, 
        },
        uninstall = {
            area = "TireRearRight",
            animation = "ATA_IdleLeverOpenHigh",
            use = {
                BlowTorch=3,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
                both = "Base.Crowbar",
            },
            skills = {
                MetalWelding = 2,
            },
            result = "auto",
            time = 40,
        }
    }
}

NewCarTuningTable["ATADodge"].parts["ATA2InteractiveTrunkWindowRearRack"] = {
    Default = {
        icon = "media/ui/tuning2/dadge_window_rack.png",
        category = "Trunks",
        containerCapacity = 60,
        interactiveTrunk = {
            fillingOnlyOne = {"FillingOnlyOne1", "FillingOnlyOne2", "FillingOnlyOne3"},
        },
        protection = {"WindshieldRear"}, 
        install = { 
            area = "TireRearLeft",
            weight = "auto",
            use = { 
                MetalPipe = 5,
                MetalBar=7,
                Screws=4,
                BlowTorch = 7,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
                primary = "Base.Screwdriver",
            },
            skills = {
                Mechanics = 2,
                MetalWelding = 4,
            },
            recipes = {carRecipe},
            time = 65, 
        },
        uninstall = {
            area = "TireRearLeft",
            animation = "ATA_Crowbar_DoorLeft",
            use = {
                BlowTorch=3,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
                both = "Base.Crowbar",
            },
            skills = { 
                MetalWelding = 2,
            },
            result = "auto",
            time = 40,
        }
    }
}

NewCarTuningTable["ATADodge"].parts["ATA2BagOnProtectionWindowFrontLeft"] = copy(ATA2TuningTableTemplate.Bags)
NewCarTuningTable["ATADodge"].parts["ATA2BagOnProtectionWindowFrontRight"] = copy(ATA2TuningTableTemplate.Bags)
for _, bagTable in pairs(NewCarTuningTable["ATADodge"].parts["ATA2BagOnProtectionWindowFrontLeft"]) do
    bagTable.install.requireInstalled = {"ATA2ProtectionWindowFrontLeft"}
end
for _, bagTable in pairs(NewCarTuningTable["ATADodge"].parts["ATA2BagOnProtectionWindowFrontRight"]) do
    bagTable.install.requireInstalled = {"ATA2ProtectionWindowFrontRight"}
end

NewCarTuningTable["ATADodge"].parts["ATA2ProtectionWheels"] = {
    ATAProtection = {
        removeIfBroken = true,
        icon = "media/ui/tuning2/wheel_chain.png",
        category = "Protection", 
        protectionModel = true, 
        protection = {"TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight"}, 
        install = { 
            sound = "ATA2InstallWheelChain",
            use = { 
                ATAProtectionWheelsChain = 1,
                BlowTorch = 4,
            },
            tools = { 
                bodylocation = "Base.WeldingMask", 
                primary = "Base.Wrench",
            },
            skills = {
                Mechanics = 2,
                MetalWelding = 3,
            },
            recipes = {"Basic Tuning"},
            requireInstalled = {"TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight"},
            time = 65, 
        },
        uninstall = {
            sound = "ATA2InstallWheelChain",
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
            result = {
                UnusableMetal=2,
            },
            time = 40,
        }
    }
}

NewCarTuningTable["ATADodgePpg"] = NewCarTuningTable["ATADodge"]

ATA2Tuning_AddNewCars(NewCarTuningTable)