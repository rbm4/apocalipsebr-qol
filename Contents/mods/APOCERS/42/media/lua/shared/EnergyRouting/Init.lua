-- Energy routing shared definitions
EnergyRouting = EnergyRouting or {}
require "EnergyRouting/Registry"
require "EnergyRouting/API"
require "EnergyRouting/ProducerBase"

EnergyRouting.VERSION = "1.0"
EnergyRouting.FRAMEWORK_VERSION = "1.0"
EnergyRouting.MOD_ID = "EnergyRouting"
EnergyRouting.SOLAR_BASE_W = 330
EnergyRouting.SOLAR_VERTICAL_BASE_W = 330
EnergyRouting.SOLAR_HORIZONTAL_BASE_W = 220
EnergyRouting.WIND_BASE_W = 450
EnergyRouting.HYDRO_BASE_W = 450
EnergyRouting.HYDRO_TICK_MS = 7000
EnergyRouting.CONTROLLER_RADIUS = 20
EnergyRouting.HYDRO_VALID_SPRITES = EnergyRouting.HYDRO_VALID_SPRITES or {
    blends_natural_02_0 = true,
    blends_natural_02_3 = true,
    blends_natural_02_5 = true,
    blends_natural_02_6 = true,
    blends_natural_02_7 = true,
}
EnergyRouting.Defaults = {
    EnableEnergyRoutingUI = true,
    DebugLogs = false,
    SolarWeatherImpact = 1.0,
    WindWeatherImpact = 1.0,
    AutoShutdownLowPriority = true,
    EnergyTickMinutes = 10,
    AllowManualOverride = true,
    AllowGeneratorOverride = false,
    BalancedReservePercent = 0.15,
    SurvivalReservePercent = 0.40,
    ComfortReservePercent = 0.05,
    DeviceScanRadius = 20,
    ControllerVerticalRange = 2,
    ConsumerScanIntervalHours = 6,
    StateSyncThreshold = 0.1,
    MaxWindTurbines = 3,
    MaxWindBatteries = 2,
    MaxHydroTurbines = 1,
    BaseWindBatteryCapacity = 100000,
    WindConditionLossRate = 0.0003,
    LootSpawnMultiplier = "x1",
}

EnergyRouting.GroupsList = {
    { id = "refrigeration", name = "Refrigeration", priority = "high", defaultToggle = true },
    { id = "lights", name = "Lights", priority = "low", defaultToggle = true },
    { id = "cooking", name = "Cooking Devices", priority = "medium", defaultToggle = true },
    { id = "industrial", name = "Industrial Devices", priority = "medium", defaultToggle = true },
}

EnergyRouting.GroupsById = EnergyRouting.GroupsById or {}
for _, group in ipairs(EnergyRouting.GroupsList) do
    EnergyRouting.GroupsById[group.id] = group
end

EnergyRouting.PriorityModes = {
    "Balanced",
    "Survival",
    "Comfort",
    "Manual",
}

EnergyRouting.PriorityOrderByMode = {
    Balanced = { "high", "medium", "low" },
    Survival = { "high" },
    Comfort = { "high", "medium", "low" },
    Manual = { "high", "medium", "low" },
}

EnergyRouting.Priorities = {
    high = 3,
    medium = 2,
    low = 1,
}

EnergyRouting.DeviceRegistry = EnergyRouting.DeviceRegistry or {}
EnergyRouting.GroupDefaultWatts = EnergyRouting.GroupDefaultWatts or {
    refrigeration = 120,
    lights = 40,
    cooking = 300,
    industrial = 200,
    entertainment = 80,
}
EnergyRouting.GroupConsumptionCaps = EnergyRouting.GroupConsumptionCaps or {
    refrigeration = 220,
    lights = 300,
    cooking = 1000,
    industrial = 600,
    entertainment = 80,
}
EnergyRouting.ConsumerMap = EnergyRouting.ConsumerMap or {
    Refrigerator = { group = "refrigeration", watts = 150 },
    Freezer = { group = "refrigeration", watts = 150 },
    refrigeration = { group = "refrigeration", watts = 150 },
    appliance_refrigeration = { group = "refrigeration", watts = 150 },
    appliances_refrigeration = { group = "refrigeration", watts = 150 },
    isfridge = { group = "refrigeration", watts = 150 },
    Stove = { group = "cooking", watts = 1000 },
    Oven = { group = "cooking", watts = 1000 },
    Microwave = { group = "cooking", watts = 700 },
    cooking = { group = "cooking", watts = 300 },
    appliance_cooking = { group = "cooking", watts = 300 },
    appliances_cooking = { group = "cooking", watts = 300 },
    isostove = { group = "cooking", watts = 300 },
    Light = { group = "lights", watts = 60 },
    Lamp = { group = "lights", watts = 60 },
    lighting = { group = "lights", watts = 40 },
    lighting_indoor = { group = "lights", watts = 40 },
    haslightonsprite = { group = "lights", watts = 40 },
    lightbulbambiance = { group = "lights", watts = 40 },
    Television = { group = "entertainment", watts = 200 },
    TV = { group = "entertainment", watts = 200 },
    Radio = { group = "entertainment", watts = 50 },
    entertainment = { group = "entertainment", watts = 80 },
    appliances_television = { group = "entertainment", watts = 200 },
    isotelevision = { group = "entertainment", watts = 200 },
    signal_tv = { group = "entertainment", watts = 200 },
    clockambiance = { group = "entertainment", watts = 15 },
    washer = { group = "industrial", watts = 400 },
    washingmachine = { group = "industrial", watts = 400 },
    clotheswasher = { group = "industrial", watts = 400 },
    laundry = { group = "industrial", watts = 400 },
    lavadora = { group = "industrial", watts = 400 },
    dryer = { group = "industrial", watts = 500 },
    tumbledryer = { group = "industrial", watts = 500 },
    clothesdryer = { group = "industrial", watts = 500 },
    secadora = { group = "industrial", watts = 500 },
}

local function normalizeKey(value)
    if not value then
        return nil
    end
    return string.lower(tostring(value))
end

function EnergyRouting.RegisterDeviceType(deviceType, groupId)
    if not deviceType or not groupId then
        return
    end
    EnergyRouting.DeviceRegistry[normalizeKey(deviceType)] = groupId
end

function EnergyRouting.GetRegisteredGroup(deviceType)
    if not deviceType then
        return nil
    end
    return EnergyRouting.DeviceRegistry[normalizeKey(deviceType)]
end

function EnergyRouting.GetSandboxVar(name, defaultValue)
    if SandboxVars then
        local vars = SandboxVars.EnergyRoutingSystem
        if vars and vars[name] ~= nil then
            return vars[name]
        end
        -- Legacy namespace compatibility.
        vars = SandboxVars.EnergyRouting
        if vars and vars[name] ~= nil then
            return vars[name]
        end
    end
    return defaultValue
end

function EnergyRouting.GetConfigValue(name)
    return EnergyRouting.GetSandboxVar(name, EnergyRouting.Defaults[name])
end

function EnergyRouting.IsDebugEnabled()
    local debugLogs = EnergyRouting.GetConfigValue("DebugLogs")
    if debugLogs ~= nil then
        return debugLogs == true
    end
    -- Legacy fallback
    return EnergyRouting.GetConfigValue("DebugUI") == true
end

function EnergyRouting.DebugPrint(...)
    if not EnergyRouting.IsDebugEnabled() then
        return
    end
    local printer = (_G and _G.print) or print
    if printer then
        printer(...)
    end
end

function EnergyRouting.IsValidHydroSpriteName(spriteName)
    if type(spriteName) ~= "string" or spriteName == "" then
        return false
    end
    local lowered = string.lower(spriteName)
    local whitelist = EnergyRouting.HYDRO_VALID_SPRITES or {}
    if whitelist[lowered] == true then
        return true
    end
    -- B42 maps frequently use these tileset prefixes for river/lake surfaces.
    if lowered:find("blends_natural_01_", 1, true) == 1 then
        return true
    end
    if lowered:find("blends_natural_02_", 1, true) == 1 then
        return true
    end
    -- Fallback for custom maps with explicit "water" naming.
    if lowered:find("water", 1, true) ~= nil then
        return true
    end
    return false
end

function EnergyRouting.MakeDefaultToggles()
    local toggles = {}
    for _, group in ipairs(EnergyRouting.GroupsList) do
        toggles[group.id] = group.defaultToggle
    end
    return toggles
end

function EnergyRouting.CloneTable(source)
    local copy = {}
    if source then
        for k, v in pairs(source) do
            copy[k] = v
        end
    end
    return copy
end

function EnergyRouting.GetGroupPriority(groupId)
    local group = EnergyRouting.GroupsById[groupId]
    if not group then
        return "low"
    end
    return group.priority
end

function EnergyRouting.GetGroupsByPriority()
    local list = {}
    for _, group in ipairs(EnergyRouting.GroupsList) do
        table.insert(list, group)
    end
    table.sort(list, function(a, b)
        return (EnergyRouting.Priorities[a.priority] or 0) > (EnergyRouting.Priorities[b.priority] or 0)
    end)
    return list
end

function EnergyRouting.NormalizeGroupConsumption(groupId, watts)
    local groupKey = groupId and string.lower(tostring(groupId)) or nil
    local value = tonumber(watts) or 0
    if value < 0 then
        value = 0
    end

    local defaults = EnergyRouting.GroupDefaultWatts or nil
    if value <= 0 and defaults and groupKey and defaults[groupKey] ~= nil then
        value = tonumber(defaults[groupKey]) or 0
    end

    local caps = EnergyRouting.GroupConsumptionCaps or nil
    local cap = caps and groupKey and tonumber(caps[groupKey]) or nil
    if cap and cap > 0 then
        value = math.min(value, cap)
    end

    if value <= 0 then
        value = 1
    end
    return value
end

function EnergyRouting.ClassifyObject(spriteName)
    if not spriteName then
        return nil
    end
    local registered = EnergyRouting.GetRegisteredGroup(spriteName)
    if registered then
        local watts = (EnergyRouting.GroupDefaultWatts and EnergyRouting.GroupDefaultWatts[registered]) or 100
        return registered, watts
    end

    local probe = string.lower(tostring(spriteName))
    local function defaultWatts(groupId, fallback)
        local defaults = EnergyRouting.GroupDefaultWatts or {}
        local value = tonumber(defaults[groupId]) or tonumber(fallback) or 100
        return value
    end
    local function matchAny(list)
        for _, needle in ipairs(list or {}) do
            if string.find(probe, needle, 1, true) then
                return true
            end
        end
        return false
    end

    -- Deterministic priority to avoid accidental "lights" matches stealing
    -- cooking/refrigeration objects when probe text contains mixed tokens.
    if matchAny({ "isfridge", "refrigerator", "refrigeration", "freezer", "fridge", "appliance_refrigeration", "appliances_refrigeration" }) then
        return "refrigeration", defaultWatts("refrigeration", 150)
    end
    if matchAny({ "isostove", "microwave", "oven", "stove", "appliance_cooking", "appliances_cooking", "cooking" }) then
        return "cooking", defaultWatts("cooking", 300)
    end
    if matchAny({ "haslightonsprite", "lightbulbambiance", "lighting_indoor", "lighting", "lamp", "light", "switch" }) then
        return "lights", defaultWatts("lights", 40)
    end
    if matchAny({ "isotelevision", "signal_tv", "television", "clockambiance", "tv", "radio", "entertainment" }) then
        return "entertainment", defaultWatts("entertainment", 80)
    end

    -- Final deterministic fallback on consumer map, longest keys first.
    local ranked = {}
    for key, data in pairs(EnergyRouting.ConsumerMap or {}) do
        ranked[#ranked + 1] = { key = string.lower(tostring(key)), data = data }
    end
    table.sort(ranked, function(a, b)
        local la = #(a.key or "")
        local lb = #(b.key or "")
        if la == lb then
            return (a.key or "") < (b.key or "")
        end
        return la > lb
    end)
    for _, entry in ipairs(ranked) do
        if entry.key ~= "" and string.find(probe, entry.key, 1, true) then
            local data = entry.data or {}
            return data.group, data.watts
        end
    end
    return nil
end

-- Basic vanilla mappings (safe no-op if types do not exist)
EnergyRouting.RegisterDeviceType("Base.Fridge", "refrigeration")
EnergyRouting.RegisterDeviceType("Base.Freezer", "refrigeration")
EnergyRouting.RegisterDeviceType("Base.Stove", "cooking")
EnergyRouting.RegisterDeviceType("Base.Microwave", "cooking")
EnergyRouting.RegisterDeviceType("Base.Radio", "entertainment")
EnergyRouting.RegisterDeviceType("Base.TV", "entertainment")
