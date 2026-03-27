-- EnergyRouting/Distributions.lua (B42.13)
EnergyRouting = EnergyRouting or {}

local LOOT_SPAWN_MULTIPLIERS = {
    [1] = 0.25,
    [2] = 0.5,
    [3] = 0.75,
    [4] = 1,
    [5] = 2,
    [6] = 3,
    [7] = 5,
}

local function normalizeLootSpawnMultiplier(numericValue)
    numericValue = tonumber(numericValue) or 1
    if math.floor(numericValue) == numericValue and LOOT_SPAWN_MULTIPLIERS[numericValue] then
        return LOOT_SPAWN_MULTIPLIERS[numericValue]
    elseif numericValue <= 0 then
        return 1
    elseif numericValue <= 0.25 then
        return 0.25
    elseif numericValue <= 0.5 then
        return 0.5
    elseif numericValue <= 0.75 then
        return 0.75
    elseif numericValue <= 1 then
        return 1
    elseif numericValue <= 2 then
        return 2
    elseif numericValue <= 3 then
        return 3
    end
    return 5
end

local function parseLootSpawnMultiplier(value)
    if type(value) == "number" then
        return normalizeLootSpawnMultiplier(value)
    end
    if type(value) ~= "string" then
        return 1
    end
    local lowered = string.lower(tostring(value)):gsub("%s+", "")
    if string.sub(lowered, 1, 1) == "x" then
        lowered = string.sub(lowered, 2)
    end
    local numericValue = tonumber(lowered)
    if numericValue then
        return normalizeLootSpawnMultiplier(numericValue)
    end
    return 1
end

local function getLootSpawnMultiplier()
    local value = nil
    if EnergyRouting and EnergyRouting.GetConfigValue then
        value = EnergyRouting.GetConfigValue("LootSpawnMultiplier")
    end
    if value == nil and SandboxVars then
        if SandboxVars.EnergyRoutingSystem then
            value = SandboxVars.EnergyRoutingSystem.LootSpawnMultiplier
        end
        if value == nil and SandboxVars.EnergyRouting then
            value = SandboxVars.EnergyRouting.LootSpawnMultiplier
        end
    end
    return parseLootSpawnMultiplier(value)
end

local function registerDistributions()
    local pd = ProceduralDistributions
    if not pd or not pd.list then
        return false
    end

    if EnergyRouting._distributionsRegistered then
        return true
    end
    EnergyRouting._distributionsRegistered = true

    local lootSpawnMultiplier = getLootSpawnMultiplier()

    local function add(procName, item, weight)
        local t = pd.list[procName]
        if not t then
            return
        end
        t.items = t.items or {}
        local finalWeight = tonumber(weight) or 0
        if type(item) == "string" and string.find(item, "EnergyRouting.", 1, true) == 1 then
            finalWeight = finalWeight * lootSpawnMultiplier
        end
        table.insert(t.items, item)
        table.insert(t.items, finalWeight)
    end

    local PANEL_SOLAR = "EnergyRouting.SolarPanel"
    local PANEL_SOLAR_H = "EnergyRouting.SolarPanelHorizontal"
    local TURBINE_WIND = "EnergyRouting.Aerogenerador"
    local TURBINE_HYDRO = "EnergyRouting.TurbinaHidraulica"
    local BATTERY_SOLAR = "EnergyRouting.BatteryTank"
    local BATTERY_WIND = "EnergyRouting.WindBattery"
    local CONTROLLER = "EnergyRouting.EnergyController"
    local CABLE = "EnergyRouting.WireTransferEnergy"
    local PANEL_INDIVIDUAL = "EnergyRouting.SolarPanel_Individual"
    local WIND_MOTOR = "EnergyRouting.WindTurbineMotor"
    local HYDRO_HELICE = "EnergyRouting.TurbineHelice"

    -- Common electronics loot (cables + individual parts)
    add("GarageTools",               CABLE, 6.0)
    add("CrateTools",                CABLE, 6.0)
    add("CrateElectronics",          CABLE, 6.0)
    add("ElectronicStoreMisc",       CABLE, 6.0)
    add("ElectronicStoreAppliances", CABLE, 6.0)
    add("ElectronicStoreComputers",  CABLE, 6.0)
    add("StoreShelfElectronics",     CABLE, 6.0)
    add("MechanicShelfElectric",     CABLE, 6.0)
    add("ArmyStorageElectronics",    CABLE, 6.0)
    add("ArmyBunkerStorage",         CABLE, 6.0)
    add("ElectronicStoreCases",      CABLE, 6.0)
    add("ElectronicStoreHAMRadio",   CABLE, 6.0)
    add("ElectronicStoreLights",     CABLE, 6.0)
    add("GigamartHouseElectronics",  CABLE, 6.0)


    add("GarageTools",               PANEL_INDIVIDUAL, 6.0)
    add("CrateTools",                PANEL_INDIVIDUAL, 6.0)
    add("CrateElectronics",          PANEL_INDIVIDUAL, 6.0)
    add("ElectronicStoreMisc",       PANEL_INDIVIDUAL, 6.0)
    add("ElectronicStoreAppliances", PANEL_INDIVIDUAL, 6.0)
    add("StoreShelfElectronics",     PANEL_INDIVIDUAL, 6.0)
    add("OfficeShelfSupplies",       PANEL_INDIVIDUAL, 6.0)
    add("ElectronicStoreComputers",  PANEL_INDIVIDUAL, 6.0)
    add("MechanicShelfElectric",     PANEL_INDIVIDUAL, 6.0)
    add("ArmyStorageElectronics",    PANEL_INDIVIDUAL, 6.0)
    add("ArmyBunkerStorage",         PANEL_INDIVIDUAL, 6.0)
    add("ElectronicStoreCases",      PANEL_INDIVIDUAL, 6.0)
    add("ElectronicStoreHAMRadio",   PANEL_INDIVIDUAL, 6.0)
    add("ElectronicStoreLights",     PANEL_INDIVIDUAL, 6.0)
    add("GigamartHouseElectronics",  PANEL_INDIVIDUAL, 6.0)

    add("GarageTools",               WIND_MOTOR, 6.0)
    add("CrateTools",                WIND_MOTOR, 6.0)
    add("CrateElectronics",          WIND_MOTOR, 6.0)
    add("ElectronicStoreMisc",       WIND_MOTOR, 6.0)
    add("ElectronicStoreAppliances", WIND_MOTOR, 6.0)
    add("StoreShelfElectronics",     WIND_MOTOR, 6.0)
    add("MechanicShelfElectric",     WIND_MOTOR, 6.0)
    add("ArmyStorageElectronics",    WIND_MOTOR, 6.0)
    add("ArmyBunkerStorage",         WIND_MOTOR, 6.0)
    add("ElectronicStoreCases",      WIND_MOTOR, 6.0)
    add("ElectronicStoreHAMRadio",   WIND_MOTOR, 6.0)
    add("ElectronicStoreLights",     WIND_MOTOR, 6.0)
    add("GigamartHouseElectronics",  WIND_MOTOR, 6.0)

    add("GarageTools",               HYDRO_HELICE, 6.0)
    add("CrateTools",                HYDRO_HELICE, 6.0)
    add("CrateElectronics",          HYDRO_HELICE, 6.0)
    add("ElectronicStoreMisc",       HYDRO_HELICE, 6.0)
    add("MechanicShelfElectric",     HYDRO_HELICE, 6.0)
    add("ArmyStorageElectronics",    HYDRO_HELICE, 6.0)
    add("ArmyBunkerStorage",         HYDRO_HELICE, 6.0)
    add("ElectronicStoreCases",      HYDRO_HELICE, 6.0)
    add("ElectronicStoreHAMRadio",   HYDRO_HELICE, 6.0)
    add("ElectronicStoreLights",     HYDRO_HELICE, 6.0)
    add("GigamartHouseElectronics",  HYDRO_HELICE, 6.0)

    -- Mid-tier components (panels + controller)
    add("ToolStoreTools",            PANEL_SOLAR_H, 2.8)
    add("GarageMechanics",           PANEL_SOLAR_H, 2.8)
    add("GarageMetalwork",           PANEL_SOLAR_H, 2.8)
    add("CrateToolsOld",             PANEL_SOLAR_H, 2.8)
    add("ElectronicStoreAppliances", PANEL_SOLAR_H, 2.8)
    add("StoreShelfElectronics",     PANEL_SOLAR_H, 2.8)

    add("ToolStoreTools",            PANEL_SOLAR, 2.5)
    add("GarageMechanics",           PANEL_SOLAR, 2.5)
    add("GarageMetalwork",           PANEL_SOLAR, 2.5)
    add("CrateToolsOld",             PANEL_SOLAR, 2.5)
    add("ElectronicStoreAppliances", PANEL_SOLAR, 2.5)
    add("StoreShelfElectronics",     PANEL_SOLAR, 2.5)

    add("ToolStoreTools",            PANEL_INDIVIDUAL, 2.5)
    add("GarageMechanics",           PANEL_INDIVIDUAL, 2.5)
    add("GarageMetalwork",           PANEL_INDIVIDUAL, 2.5)
    add("CrateToolsOld",             PANEL_INDIVIDUAL, 2.5)
    add("ElectronicStoreAppliances", PANEL_INDIVIDUAL, 2.5)
    add("StoreShelfElectronics",     PANEL_INDIVIDUAL, 2.5)

    add("ElectronicStoreMisc",       CONTROLLER, 4.5)
    add("ElectronicStoreComputers",  CONTROLLER, 4.5)
    add("ElectronicStoreAppliances", CONTROLLER, 4.5)
    add("StoreShelfElectronics",     CONTROLLER, 4.5)
    add("MechanicShelfElectric",     CONTROLLER, 4.5)
    add("CrateElectronics",          CONTROLLER, 4.5)
    add("ArmyStorageElectronics",    CONTROLLER, 4.5)
    add("ArmyBunkerStorage",         CONTROLLER, 4.5)
    add("ElectronicStoreCases",      CONTROLLER, 4.5)
    add("ElectronicStoreHAMRadio",   CONTROLLER, 4.5)
    add("ElectronicStoreLights",     CONTROLLER, 4.5)
    add("GigamartHouseElectronics",  CONTROLLER, 4.5)

    -- Heavy/industrial tier (batteries + wind turbine)
    add("ToolFactoryTools",          BATTERY_SOLAR, 2.8)
    add("CabinetFactoryTools",       BATTERY_SOLAR, 2.8)
    add("CrateMetalwork",            BATTERY_SOLAR, 2.8)
    add("CrateMechanics",            BATTERY_SOLAR, 2.8)
    add("FactoryLockers",            BATTERY_SOLAR, 2.8)

    add("ToolFactoryTools",          BATTERY_WIND, 2.8)
    add("CabinetFactoryTools",       BATTERY_WIND, 2.8)
    add("CrateMetalwork",            BATTERY_WIND, 2.8)
    add("CrateMechanics",            BATTERY_WIND, 2.8)
    add("FactoryLockers",            BATTERY_WIND, 2.8)

    add("ToolFactoryTools",          WIND_MOTOR, 2.2)
    add("CabinetFactoryTools",       WIND_MOTOR, 2.2)
    add("CrateMetalwork",            WIND_MOTOR, 2.2)
    add("CrateMechanics",            WIND_MOTOR, 2.2)
    add("FactoryLockers",            WIND_MOTOR, 2.2)

    add("ToolFactoryTools",          TURBINE_WIND, 2.2)
    add("CabinetFactoryTools",       TURBINE_WIND, 2.2)
    add("CrateMechanics",            TURBINE_WIND, 2.2)
    add("CrateMetalwork",            TURBINE_WIND, 2.2)
    add("ArmyStorageElectronics",    TURBINE_WIND, 2.2)
    add("ArmyBunkerStorage",         TURBINE_WIND, 2.2)

    add("ToolFactoryTools",          TURBINE_HYDRO, 1.8)
    add("CabinetFactoryTools",       TURBINE_HYDRO, 1.8)
    add("CrateMechanics",            TURBINE_HYDRO, 1.8)
    add("CrateMetalwork",            TURBINE_HYDRO, 1.8)
    add("ArmyStorageElectronics",    TURBINE_HYDRO, 1.8)
    add("ArmyBunkerStorage",         TURBINE_HYDRO, 1.8)

    add("ToolFactoryTools",          HYDRO_HELICE, 1.8)
    add("CabinetFactoryTools",       HYDRO_HELICE, 1.8)
    add("CrateMechanics",            HYDRO_HELICE, 1.8)
    add("CrateMetalwork",            HYDRO_HELICE, 1.8)
    add("ArmyStorageElectronics",    HYDRO_HELICE, 1.8)
    add("ArmyBunkerStorage",         HYDRO_HELICE, 1.8)

    return true
end

Events.OnPreDistributionMerge.Add(registerDistributions)
