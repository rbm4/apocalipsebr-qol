require "ATA2TuningTable"


-- NewCarTuningTable["Имя_Машины"].parts["Имя_Запчасти"] = {
    -- Имя_Модели = {
        -- shader = "vehiclewheel", -- генераторю vehiclewheel (для независимых предметов), vehicle (для  предметов использующих основную текстуру и анимированных предметов). По умолчанию - vehiclewheel.
        -- spawnChance = 30, -- значение от 0 до 100. По умолчанию - 0.
        -- isConfig = false, -- не отображает рецепт, и игнорирует таблицы установки/снятия
        -- hideIfNotValid = false, -- Скрывать рецепт, если он недоступен
        -- icon = "media/ui/tuning2/protection_window_side.png",
        -- name = "Имя_предмета", -- необязательно
        -- secondModel = "Имя_Второй_Модели", -- Для стационарной части анимированной защиты, либо для разных предметов, использующих одну модель
        -- modelList = {"Имя_Второй_Модели", "Имя_Третьей_Модели"},
        -- category = "Категория_Тюнинга", -- необязательно. Если не задано, категория будет "Общее". Варианты: Bullbars ProtectionWindow ProtectionDoor Protection Trunks Another Storage Bumpers Visual
        -- containerCapacity = 18, -- емкость контейнера
        -- interactiveTrunk = {
            -- filling = {"ATA2DodgeRoofBag1", "ATA2DodgeRoofBag2"}, -- По ходу заполнения багажника появляются модели, первые появившиеся модели также видны.
            -- fillingOnlyOne = {"ATA2DodgeWindowRackBag1", "ATA2DodgeWindowRackBag2", "ATA2DodgeWindowRackBag3"}, -- По ходу заполнения багажника первые модели отключаются, следующие появляются
            -- items = {
                -- {
                    -- itemTypes = {"OldTire3", "NormalTire3", "ModernTire3"}, -- количество предметов суммируется
                    -- modelNameByCount = {"ATA2DodgeRoofWheel"}, -- на основании этой суммы, активируется нужно число моделей
                -- },
            -- }
        -- },
        -- protectionModel = true, -- если true модель активируется на всех элементах авто, указанных в таблице "protection"
        -- protection = {"WindowFrontLeft"}, -- необязательно. Список предметов, которые будут защищаться этой деталью. Частые варианты: EngineDoor HeadlightLeft HeadlightRight HeadlightRearLeft HeadlightRearRight WindowFrontLeft WindowFrontRight WindowMiddleLeft WindowMiddleRight WindowRearLeft WindowRearRight Windshield WindshieldRear TireFrontLeft TireFrontRight TireRearLeft TireRearRight
        -- protectionHealthDelta = 3, -- НЕ НАСТРОЕНО. уровень уменьшения состояния защиты при каждом восстановлении защищаемой детали. По умолчанию 3.
        -- protectionTriger = 80,  -- НЕ НАСТРОЕНО. уровень состояния детали, при котором срабатывает восстановления состояния детали. Число от 20 до 80.
        -- disableOpenWindowFromSeat = "SeatFrontLeft", -- запретить открытие окна, если защита установлена. Aвтоматически закрывает окно. Варианты: SeatFrontLeft SeatFrontRight SeatMiddleLeft SeatMiddleRight SeatRearLeft SeatRearRight
        -- removeIfBroken = true, -- удалять деталь, если сломана. Пока этот параметр работает только для деталей обеспечивающих защиту (деталей вызывающих "ATATuning2.Update.Protection"). Если предмет имеет контейнер (part:getItemContainer()), параметр игнорируется. По умолчанию false. 
        -- install = { -- предметы и правила крафта/установки детали
            -- weight = "auto", --  weight = 10.3, -- вес детали. Если "auto", то суммируется вес стальных деталей (из таблицы ATA2TuningItemList) и делится на 2.
            -- area = "GasTank", -- необязательно. Если не указано, использует area из скриптов.
            -- animation = "ATA_IdleLeverOpenLow", -- необязательно. Варианты: ATA_Crowbar_DoorLeft ATA_FishingSpearStrike ATA_IdleHammering ATA_IdleHammering_Low ATA_IdleLeverOpenHigh ATA_IdleLeverOpenLow ATA_IdleLeverOpenMidATA_PickLock ATA_IdlePainting VehicleWorkOnMid VehicleWorkOnTire ATA_IdleLooting_High ATA_IdleLooting_Low ATA_IdleLooting_Mid 
            -- sound = "BlowTorch", -- необязательно. По умолчанию высчитывается в зависимости от используемых предметов
            -- transmitFirstItemCondition = true, -- установить состояние детали равной состоянию первому предметы в use. Используется для уникальных предметов (палатки, фабричных бамперов и др.)
            -- use = { -- необязательно. "__" заменяется на "."
                -- MetalPipe = 6,
                -- SheetMetal = 3,
                -- MetalBar=7,
                -- Screws=4,
                -- BlowTorch = 10,
            -- },
            -- tools = { -- необязательно
                -- bodylocation = "Base.WeldingMask", -- предмет, который будет одеваться на тело. Нужно обязательно указывать модуль предмета ("Base.")
                -- primary = "Base.Wrench", -- нужно обязательно указывать модуль предмета ("Base.")
                -- secondary = "Base.Screwdriver", -- нужно обязательно указывать модуль предмета ("Base.")
                -- both = "Base.Crowbar", -- нужно обязательно указывать модуль предмета ("Base.")
            -- },
            -- skills = { -- необязательно. Варианты: Mechanics MetalWelding Strength Crafting Electricity Maintenance Tailoring Survivalist
                -- MetalWelding = 5,
            -- },
            -- recipes = {"Intermediate Mechanics", carRecipe}, -- необязательно. Варианты: "Intermediate Mechanics"
            -- requireInstalled = {"WindowFrontLeft"},  -- необязательно
            -- requireModel = "ATAVanDeRumbaBullbar2", -- Проверяет, что уже установлена указанная модели.
            -- requireUninstalled = {"ATABagOnProtectionWindowFrontLeft"},  -- необязательно
            -- time = 65, 
        -- },
        -- uninstall = { -- предметы и правила демонтажа детали
            -- area = "GasTank", -- необязательно. Если не указано, использует area из скриптов.
            -- animation = "ATA_IdleLeverOpenLow", -- необязательно. Варианты: ATA_IdleLeverOpenHigh ATA_IdleLeverOpenLow ATA_IdleLeverOpenMid ATA_Crowbar_DoorLeft ATA_FishingSpearStrike ATA_IdleHammering ATA_IdleHammering_Low ATA_IdleLooting_High ATA_IdleLooting_Low ATA_IdleLooting_Mid ATA_PickLock
            -- sound = "BlowTorch", -- необязательно.
            -- use = { -- необязательно. "__" заменяется на "."
                -- BlowTorch=4,
            -- },
            -- tools = { -- необязательно
                -- bodylocation = "Base.WeldingMask", -- предмет, который будет одеваться на тело. Нужно обязательно указывать модуль предмета ("Base.")
                -- primary = "Base.Wrench", -- нужно обязательно указывать модуль предмета ("Base.")
                -- secondary = "Base.Screwdriver", -- нужно обязательно указывать модуль предмета ("Base.")
                -- both = "Base.Crowbar", -- нужно обязательно указывать модуль предмета ("Base.")
            -- },
            -- skills = { -- необязательно. Варианты: Mechanics MetalWelding Strength Crafting Electricity Maintenance Tailoring Survivalist
                -- MetalWelding = 2,
            -- },
            -- transmitConditionOnFirstItem = true, -- установить состояние детали - первому предмету из result. Не зависимо сколько предметов указано в result, игрок получит только один
            -- result = {  -- ОБЯЗАТЕЛЬНО (проверить) .. -- result = "auto", -- "__" заменяется на "."
                -- SheetMetal=2,
                -- MetalBar=3,
                -- Screws=2,
                -- UnusableMetal=2,
            -- },
            -- requireInstalled = {"WindowFrontLeft"},  -- необязательно
            -- requireUninstalled = {"ATABagOnProtectionWindowFrontLeft"},  -- необязательно
            -- time = 65,
        -- }
    -- }
-- }

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
NewCarTuningTable["ATAMustang66"] = {
    addPartsFromVehicleScript = "",
    parts = {}
}

NewCarTuningTable["ATAMustang66"].parts["ATA2Bumper"] = {
    Bumper2 = {
        icon = "media/ui/tuning2/datsun_bumper_2.png", -- TODO
        name = "IGUI_ATA2_Bullbar", -- TODO
        category = "Bumpers", -- TODO
        secondModel = "Bumper2_light",
        spawnChance = 10,
        protection = {"HeadlightLeft", "HeadlightRight", "EngineDoor"},
        install = {
            weight = "auto",
            animation = "ATA_PickLock",
            transmitFirstItemCondition = true,
            use = {
                ATA2__ATABullbar3Item = 1,
                Screws=5,
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
                ATA2__ATABullbar3Item = 1,
            },
            time = 20,
        }
    },
    Bumper1 = {
        icon = "media/ui/tuning2/datsun_bumper_1.png", -- TODO
        name = "IGUI_ATA2_Bumper_Classic", -- TODO
        category = "Bumpers", -- TODO
        spawnChance = 100,
        install = {
            weight = "auto",
            animation = "ATA_PickLock",
            transmitFirstItemCondition = true,
            use = {
                Autotsar__ATAMustang66BumperItem = 1,
                Screws=5,
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
                Autotsar__ATAMustang66BumperItem = 1,
            },
            time = 20,
        }
    },
    Bumper3 = {
        icon = "media/ui/tuning2/dadge_bullbar_3.png",
        name = "IGUI_ATA2_Bullbar_Lethal",
        category = "Bumpers",
        protection = {"HeadlightLeft", "HeadlightRight", "EngineDoor"},
        install = {
            weight = "auto",
            animation = "ATA_PickLock",
            use = {
                MetalPipe = 3,
                SheetMetal = 6,
                MetalBar=6,
                BlowTorch = 10,
                Screws=6,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
                primary = "Base.Wrench",
            },
            skills = {
                Mechanics = 4,
                MetalWelding = 6,
            },
            recipes = {"Intermediate Mechanics", carRecipe},
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

NewCarTuningTable["ATAMustang66"].parts["ATA2BumperRear"] = {
    Bumper1 = {
        icon = "media/ui/tuning2/datsun_bumper_1.png",
        name = "IGUI_ATA2_Bumper_Rear_Classic",
        category = "Bumpers",
        spawnChance = 100,
        install = {
            weight = "auto",
            animation = "ATA_PickLock",
            transmitFirstItemCondition = true,
            use = {
                Autotsar__ATAMustang66BumperRearItem = 1,
                Screws=5,
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
                Autotsar__ATAMustang66BumperRearItem = 1,
            },
            time = 20,
        }
    },
    Bumper2 = {
        icon = "media/ui/tuning2/datsun_bumper_3.png",
        name = "IGUI_ATA2_Bumper_Rear_Handmade",
        category = "Bumpers",
        protection = {"TrunkDoor"},
        install = {
            weight = "auto",
            animation = "ATA_PickLock",
            use = {
                MetalPipe = 5,
                MetalBar=2,
                BlowTorch = 6,
                Screws=5,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
                primary = "Base.Wrench",
            },
            skills = {
                Mechanics = 4,
                MetalWelding = 4,
            },
            recipes = {"Intermediate Mechanics", carRecipe},
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

NewCarTuningTable["ATAMustang66"].parts["ATA2ProtectionWindowFrontLeft"] = {
    Default = {
        icon = "media/ui/tuning2/protection_window_side.png",
        modelList = {"StaticPart", "StaticPart2"},
        category = "Protection",
        protection = {"WindowFrontLeft"},
        install = {
            weight = "auto",
            use = {
                SmallSheetMetal = 3,
                SheetMetal = 2,
                MetalBar=5,
                Screws=5,
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

NewCarTuningTable["ATAMustang66"].parts["ATA2ProtectionWindowFrontRight"] = copy(NewCarTuningTable["ATAMustang66"].parts["ATA2ProtectionWindowFrontLeft"])
NewCarTuningTable["ATAMustang66"].parts["ATA2ProtectionWindowFrontRight"].Default.protection = {"WindowFrontRight"}
NewCarTuningTable["ATAMustang66"].parts["ATA2ProtectionWindowFrontRight"].Default.install.requireInstalled = {"WindowFrontRight"}


NewCarTuningTable["ATAMustang66"].parts["ATA2ProtectionWindshield"] = {
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
                SheetMetal=2,
                Screws=6,
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

NewCarTuningTable["ATAMustang66"].parts["ATA2ProtectionWindshieldRear"] = {
    Default = {
        icon = "media/ui/tuning2/protection_window_windshield.png",
        category = "Protection",
        protection = {"WindshieldRear"},
        removeIfBroken = true,
        install = {
            weight = "auto",
            area = "TireRearRight",
            use = {
                MetalPipe = 8,
                Screws = 8,
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

NewCarTuningTable["ATAMustang66"].parts["ATA2InteractiveTrunkRoofRack"] = {
    ATARoofrack = {
        icon = "media/ui/tuning2/roof_rack_1.png",
        category = "Trunks",
        containerCapacity = 50,
        interactiveTrunk = {
            filling = {"ATARoofBag1", "ATARoofBag2", "ATARoofBag3"},
            items = {
                {
                    itemTypes = {"Suitcase"},
                    modelNameByCount = {"ATARoofCase1", "ATARoofCase1"}
                },
                {
                    itemTypes = {"Bag_BigHikingBag", "Bag_ALICEpack_Army", "Bag_ALICEpack", "Bag_NormalHikingBag"},
                    modelNameByCount = {"BigHikingBagBlue", "BigHikingBagGreen"}
                },
                {
                    itemTypes = {"Cooler"},
                    modelNameByCount = {"ATACooler"}
                },
                {
                    itemTypes = {"PetrolCan", "EmptyPetrolCan"},
                    modelNameByCount = {"ATAGasCan1", "ATAGasCan2", "ATAGasCan3"}
                },
            }
        },
        install = {
            weight = "auto",
            use = {
                MetalPipe = 4,
                SheetMetal = 7,
                MetalBar=4,
                Screws=4,
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

NewCarTuningTable["ATAMustang66"].parts["ATA2VisualSkirtsSide"] = {
    Default = {
        icon = "media/ui/tuning2/datsun_skirts.png",
        category = "Visual",
        install = {
            animation = "VehicleWorkOnTire",
            use = {
                MetalPipe = 2,
                SheetMetal = 2,
                MetalBar=4,
                Screws=5,
                BlowTorch = 5,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
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
            use = {
                BlowTorch=3,
            },
            tools = {
                bodylocation = "Base.WeldingMask",
            },
            recipes = {"Advanced Mechanics"},
            skills = {
                Mechanics = 4,
            },
            result = "auto",
            time = 30,
        }
    }
}

NewCarTuningTable["ATAMustang66"].parts["ATA2RoofLightFront"] = {
    Default = {
        spawnChance = 10,
        icon = "media/ui/tuning2/datsun_roof_light.png",
        modelList = {"SecondModel"},
        category = "Visual",
        install = {
            area = "ATARoof",
            transmitFirstItemCondition = true,
            use = {
                ATA2__ATAFrontRoofLightItem = 1,
                Screws=4,
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
            area = "ATARoof",
            tools = {
                primary = "Base.Screwdriver",
            },
            recipes = {"Advanced Mechanics"},
            skills = {
                Mechanics = 4,
            },
            transmitConditionOnFirstItem = true,
            result = {
                ATA2__ATAFrontRoofLightItem=1,
            },
            time = 30,
        }
    }
}

NewCarTuningTable["ATAMustang66"].parts["ATA2ProtectionWheels"] = { -- не забыть сделать особые настройки колес
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

NewCarTuningTable["ATAMustang66Custom"] = NewCarTuningTable["ATAMustang66"]

ATA2Tuning_AddNewCars(NewCarTuningTable)
