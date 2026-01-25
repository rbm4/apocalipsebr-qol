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

local carRecipe = "ATAMustangRecipes"

local NewCarTuningTable = {}
NewCarTuningTable["ATAMustang"] = {
    addPartsFromVehicleScript = "",
    parts = {}
}

NewCarTuningTable["ATAMustang"].parts["ATA2Bullbar"] = {
    ATABullbar1 = {
        icon = "media/ui/tuning2/mustang_bullbar_1.png",
        name = "IGUI_ATA2_Bullbar", -- необязательно
        category = "Bullbars",
        protection = {"HeadlightLeft", "HeadlightRight", "EngineDoor"},
        spawnChance = 20,
        install = {
            weight = "auto",
            animation = "ATA_PickLock",
            transmitFirstItemCondition = true,
            use = {
                ATA2__ATABullbar1Item = 1,
                Screws=35,
            },
            tools = {
                primary = "Base.Wrench",
            },
            skills = {
                Mechanics = 4,
            },
            recipes = {"Advanced Mechanics"},
            time = 30, 
        },
        uninstall = {
            weight = "auto",
            animation = "ATA_PickLock",
            tools = {
                primary = "Base.Wrench",
            },
            skills = {
                Mechanics = 3,
            },
            recipes = {"Advanced Mechanics"},
            transmitConditionOnFirstItem = true,
            result = {
                ATA2__ATABullbar1Item = 1,
                Screws=15,
            },
            time = 20,
        }
    },
    ATABullbar2 = {
        icon = "media/ui/tuning2/mustang_bullbar_2.png",
        name = "IGUI_ATA2_Bullbar_Police",
        category = "Bullbars",
        protection = {"HeadlightLeft", "HeadlightRight", "EngineDoor"},
        spawnChance = 10,
        install = {
            weight = "auto",
            animation = "ATA_PickLock",
            transmitFirstItemCondition = true,
            use = {
                ATA2__ATABullbar2Item = 1,
                Screws=35,
            },
            tools = {
                primary = "Base.Wrench",
            },
            skills = {
                Mechanics = 4,
            },
            recipes = {"Advanced Mechanics"},
            time = 30, 
        },
        uninstall = {
            weight = "auto",
            animation = "ATA_PickLock",
            tools = {
                primary = "Base.Wrench",
            },
            skills = {
                Mechanics = 3,
            },
            recipes = {"Advanced Mechanics"},
            transmitConditionOnFirstItem = true,
            result = {
                ATA2__ATABullbar2Item = 1,
                Screws=3,
            },
            time = 20,
        }
    },
    ATABullbar3 = {
        icon = "media/ui/tuning2/mustang_bullbar_3.png",
        name = "IGUI_ATA2_Bullbar_Lethal",
        category = "Bullbars",
        protection = {"HeadlightLeft", "HeadlightRight", "EngineDoor"},
        install = {
            weight = "auto",
            animation = "ATA_PickLock",
            use = {
                MetalPipe = 9,
                SheetMetal = 16,
                MetalBar=20,
                BlowTorch = 10,
                Screws=30,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
                primary = "Base.Wrench",
            },
            skills = {
                Mechanics = 4,
                MetalWelding = 6,
            },
            recipes = {carRecipe},
            time = 60, 
        },
        uninstall = {
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
            time = 30,
        }
    }
}

NewCarTuningTable["ATAMustang"].parts["ATA2ProtectionWindowFrontLeft"] = {
    Default = {
        icon = "media/ui/tuning2/protection_window_side.png",
        secondModel = "StaticPart",
        category = "Protection",
        protection = {"WindowFrontLeft"},
        install = {
            weight = "auto",
            use = {
                SmallSheetMetal = 9,
                SheetMetal = 4,
                MetalBar=12,
                Screws=35,
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
    }
}

NewCarTuningTable["ATAMustang"].parts["ATA2ProtectionWindowFrontRight"] = copy(NewCarTuningTable["ATAMustang"].parts["ATA2ProtectionWindowFrontLeft"])
NewCarTuningTable["ATAMustang"].parts["ATA2ProtectionWindowFrontRight"].Default.protection = {"WindowFrontRight"}
NewCarTuningTable["ATAMustang"].parts["ATA2ProtectionWindowFrontRight"].Default.install.requireInstalled = {"WindowFrontRight"}
NewCarTuningTable["ATAMustang"].parts["ATA2ProtectionWindowFrontRight"].Default.uninstall.requireUninstalled = {"ATA2BagOnProtectionWindowFrontRight"}


NewCarTuningTable["ATAMustang"].parts["ATA2ProtectionWindshield"] = {
    Default = {
        removeIfBroken = true,
        icon = "media/ui/tuning2/protection_window_windshield.png",
        category = "Protection",
        protection = {"Windshield"},
        install = {
            area = "TireFrontLeft",
            weight = "auto",
            use = {
                MetalPipe = 7,
                SheetMetal=4,
                Screws=35,
                BlowTorch = 8,
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
            area = "TireFrontLeft",
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

NewCarTuningTable["ATAMustang"].parts["ATA2ProtectionWindshieldRear"] = {
    Default = {
        icon = "media/ui/tuning2/protection_window_windshield.png",
        category = "Protection",
        protection = {"WindshieldRear"},
        removeIfBroken = true,
        install = {
            weight = "auto",
            area = "TireRearRight",
            use = {
                MetalPipe = 16,
                Screws = 35,
                BlowTorch = 5,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
            },
            skills = {
                MetalWelding = 4,
            },
            recipes = {carRecipe},
            requireInstalled = {"WindshieldRear"},
            time = 65, 
        },
        uninstall = {
            area = "TireRearRight",
            animation = "ATA_IdleLeverOpenMid",
            tools = {
                both = "Base.Crowbar",
            },
            result = "auto",
            time = 65,
        }
    }
}

NewCarTuningTable["ATAMustang"].parts["ATA2InteractiveTrunkRoofRack"] = {
    ATARoofrack = {
        icon = "media/ui/tuning2/roof_rack_1.png",
        category = "Trunks",
        containerCapacity = 90,
        interactiveTrunk = {
            filling = {"ATARoofBag1", "ATARoofBag2", "ATARoofBag3"},
            items = {
                {
                    itemTypes = {"Suitcase"},
                    modelNameByCount = {"ATARoofCase1", "ATARoofCase1"}
                },
                {
                    itemTypes = {"Cooler"},
                    modelNameByCount = {"ATACooler"}
                },
                {
                    itemTypes = {"PetrolCan", "EmptyPetrolCan"},
                    modelNameByCount = {"ATAGasCan1", "ATAGasCan2", "ATAGasCan3"}
                },
                {
                    itemTypes = {"Guitarcase"},
                    modelNameByCount = {"ATAGuitarCase"}
                },
            }
        },
        install = {
            weight = "auto",
            use = {
                MetalPipe = 14,
                SheetMetal = 13,
                MetalBar=9,
                Screws=35,
                BlowTorch = 10,
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
            animation = "ATA_IdleLeverOpenHigh",
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

NewCarTuningTable["ATAMustang"].parts["ATA2VisualSpoilerFront"] = {
    Default = {
        spawnChance = 20,
        icon = "media/ui/tuning2/spoiler_front_1.png",
        category = "Visual",
        install = {
            animation = "VehicleWorkOnTire",
            transmitFirstItemCondition = true,
            use = {
                ATA2__ATASpoilerFrontItem = 1,
                Screws=30,
            },
            tools = {
                primary = "Base.Screwdriver",
            },
            skills = {
                Mechanics = 4,
            },
            recipes = {"Advanced Mechanics"},
            time = 20,
        },
        uninstall = {
            animation = "VehicleWorkOnTire",
            tools = {
                primary = "Base.Screwdriver",
            },
            recipes = {"Advanced Mechanics"},
            transmitConditionOnFirstItem = true,
            skills = {
                Mechanics = 3,
            },
            result = {
                ATA2__ATASpoilerFrontItem=1,
                Screws=3,
            },
            time = 15,
        }
    }
}

NewCarTuningTable["ATAMustang"].parts["ATA2VisualSpoilerRear"] = {
    ATASpoilerRear1 = {
        spawnChance = 70,
        icon = "media/ui/tuning2/spoiler_rear_1.png",
        category = "Visual",
        install = {
            transmitFirstItemCondition = true,
            use = {
                ATA2__ATASpoilerRear1Item = 1,
                Screws=35,
            },
            tools = {
                primary = "Base.Screwdriver",
            },
            skills = {
                Mechanics = 4,
            },
            recipes = {"Advanced Mechanics"},
            time = 30,
        },
        uninstall = {
            
            tools = {
                primary = "Base.Screwdriver",
            },
            skills = {
                Mechanics = 3,
            },
            recipes = {"Advanced Mechanics"},
            transmitConditionOnFirstItem = true,
            result = {
                ATA2__ATASpoilerRear1Item=1,
                Screws=3,
            },
            time = 30,
        }
    },
    ATASpoilerRear2 = {
        spawnChance = 30,
        icon = "media/ui/tuning2/spoiler_rear_2.png",
        category = "Visual",
        install = {
            transmitFirstItemCondition = true,
            use = {
                ATA2__ATASpoilerRear2Item = 1,
                Screws=35,
            },
            tools = {
                primary = "Base.Screwdriver",
            },
            skills = {
                Mechanics = 4,
            },
            recipes = {"Advanced Mechanics"},
            time = 30,
        },
        uninstall = {
            
            tools = {
                primary = "Base.Screwdriver",
            },
            skills = {
                Mechanics = 3,
            },
            recipes = {"Advanced Mechanics"},
            transmitConditionOnFirstItem = true,
            result = {
                ATA2__ATASpoilerRear2Item=1,
                Screws=2,
            },
            time = 30,
        }
    }
}

NewCarTuningTable["ATAMustang"].parts["ATA2VisualSkirtsSide"] = {
    Default = {
        spawnChance = 20,
        icon = "media/ui/tuning2/skirts.png",
        category = "Visual",
        install = {
            animation = "VehicleWorkOnTire",
            transmitFirstItemCondition = true,
            use = {
                ATA2__ATASkirtsSideItem = 1,
                Screws=35,
            },
            tools = {
                primary = "Base.Screwdriver",
            },
            skills = {
                Mechanics = 5,
            },
            recipes = {"Advanced Mechanics"},
            time = 30,
        },
        uninstall = {
            animation = "VehicleWorkOnTire",
            tools = {
                primary = "Base.Screwdriver",
            },
            recipes = {"Advanced Mechanics"},
            skills = {
                Mechanics = 4,
            },
            transmitConditionOnFirstItem = true,
            result = {
                ATA2__ATASkirtsSideItem=1,
                Screws=2,
            },
            time = 30,
        }
    }
}

NewCarTuningTable["ATAMustang"].parts["ATA2VisualFendersWide"] = {
    Default = {
        spawnChance = 20,
        icon = "media/ui/tuning2/fenders_wide.png",
        category = "Visual",
        install = {
            transmitFirstItemCondition = true,
            use = {
                ATA2__ATAFendersWideItem = 1,
                BlowTorch = 4,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
            },
            skills = {
                Mechanics = 4,
                MetalWelding = 4,
            },
            recipes = {"Advanced Mechanics"},
            time = 40,
        },
        uninstall = {
            recipes = {carRecipe},
            use = {
                BlowTorch = 4,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
            },
            skills = {
                MetalWelding = 2,
            },
            recipes = {"Advanced Mechanics"},
            result = {
                UnusableMetal=4,
            },
            time = 20,
        }
    }
}

NewCarTuningTable["ATAMustang"].parts["ATA2ProtectionWheels"] = { -- не забыть сделать особые настройки колес
    ATAProtection = {
        removeIfBroken = true,
        icon = "media/ui/tuning2/wheel_chain.png",
        category = "Protection", 
        protectionModel = true, 
        protection = {"TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight"}, 
        install = { 
            sound = "ATA2InstallWheelChain",
            use = { 
                ATA2__ATAProtectionWheelsChain = 1,
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

NewCarTuningTable["ATAMustangClassic"] = NewCarTuningTable["ATAMustang"]
NewCarTuningTable["ATAMustangPolice"] = NewCarTuningTable["ATAMustang"]

ATA2Tuning_AddNewCars(NewCarTuningTable)
