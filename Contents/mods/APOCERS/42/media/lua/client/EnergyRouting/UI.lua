-- ERS_DEBUG_PRINT_GUARD
local _ERS_RAW_PRINT = (_G and _G.print) or print
local function ersDebugLogsEnabled()
    if EnergyRouting and EnergyRouting.IsDebugEnabled then
        return EnergyRouting.IsDebugEnabled()
    end
    if EnergyRouting and EnergyRouting.GetConfigValue then
        return EnergyRouting.GetConfigValue("DebugLogs") == true
    end
    local vars = SandboxVars and (SandboxVars.EnergyRoutingSystem or SandboxVars.EnergyRouting) or nil
    return vars and vars.DebugLogs == true
end
local function debugPrint(...)
    if ersDebugLogsEnabled() then
        _ERS_RAW_PRINT(...)
    end
end
local print = debugPrint
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISComboBox"
require "ISUI/ISLabel"
require "EnergyRouting/Init"
require "EnergyNetwork"
require "EnergyRouting/Weather"
require "EnergyRouting/ClientOptions"

print("[SPESS][UI] EnergyRouting/UI.lua loaded")

local UI_STRINGS = {
    controller_title = { en = "Energy Routing Panel", es = "Panel de Enrutamiento de Energia" },
    readonly_suffix = { en = " (Read-Only)", es = " (Solo lectura)" },
    total_storage = { en = "Total Storage: %s", es = "Almacen total: %s" },
    stored_energy = { en = "Stored energy: %s kWh", es = "Energia almacenada: %s kWh" },
    max_capacity = { en = "Maximum capacity: %s kWh", es = "Capacidad maxima: %s kWh" },
    estimated_autonomy = { en = "Estimated autonomy: %s h", es = "Autonomia estimada: %s h" },
    total_production = { en = "Total Production: %s W", es = "Total produccion: %s W" },
    weather = { en = "Weather: %s", es = "Clima: %s" },
    role = { en = "Role: %s", es = "Rol: %s" },
    panels_connected = { en = "Panels Connected: %s", es = "Paneles conectados: %s" },
    batteries_connected = { en = "Batteries Connected: %s", es = "Baterias conectadas: %s" },
    wind_turbines_connected = { en = "Wind Turbines Connected: %s", es = "Aerogeneradores conectados: %s" },
    wind_batteries_connected = { en = "Wind Batteries Connected: %s", es = "Baterias eolicas conectadas: %s" },
    section_solar = { en = "Solar", es = "Solar" },
    section_wind = { en = "Wind", es = "Wind" },
    section_hydraulic = { en = "Hydraulic", es = "Hydraulic" },
    section_panels = { en = "Panels: %s", es = "Paneles: %s" },
    section_batteries = { en = "Batteries: %s", es = "Baterias: %s" },
    section_turbines = { en = "Turbines: %s", es = "Aerogeneradores: %s" },
    section_hydro_turbines = { en = "Turbines: %s", es = "Turbinas: %s" },
    section_wind_batteries = { en = "Wind Batteries: %s", es = "Bat. eolicas: %s" },
    section_production = { en = "Total production: %s W", es = "Total produccion: %s W" },
    section_storage = { en = "Stored energy: %s kWh", es = "Energia almacenada: %s kWh" },
    section_bonus_accumulated = { en = "Accumulated bonus: %s%%", es = "Bonus acumulado: %s%%" },
    section_state_active = { en = "Active", es = "Activa" },
    section_state_inactive = { en = "Inactive", es = "Inactiva" },
    section_state_disconnected = { en = "Disconnected", es = "Desconectada" },
    section_batteries_title = { en = "Batteries", es = "Baterias" },
    master_battery = { en = "Master Battery: %s", es = "Bateria master: %s" },
    priority_mode = { en = "Priority Mode", es = "Modo de prioridad" },
    mode_balanced = { en = "Balanced", es = "Equilibrado" },
    mode_survival = { en = "Survival", es = "Supervivencia" },
    mode_comfort = { en = "Comfort", es = "Confort" },
    mode_manual = { en = "Manual", es = "Manual" },
    mode_desc_balanced = {
        en = "Balanced - Automatically distributes energy while preserving battery life.",
        es = "Equilibrado - Distribuye energia automaticamente y preserva la bateria.",
    },
    mode_desc_survival = {
        en = "Survival - Powers only critical groups and keeps a large battery reserve.",
        es = "Supervivencia - Solo alimenta grupos criticos y mantiene gran reserva de bateria.",
    },
    mode_desc_comfort = {
        en = "Comfort - Tries to power everything and allows deeper battery usage.",
        es = "Confort - Intenta alimentar todo y permite usar mas la bateria.",
    },
    mode_desc_manual = {
        en = "Manual - Uses your toggles only. No automatic protections.",
        es = "Manual - Solo respeta tus toggles. Sin protecciones automaticas.",
    },
    groups = { en = "Groups", es = "Grupos" },
    group_name_refrigeration = { en = "Refrigeration", es = "Refrigeracion" },
    group_name_lights = { en = "Lights", es = "Luces" },
    group_name_cooking = { en = "Cooking Devices", es = "Dispositivos de cocina" },
    group_name_medical = { en = "Medical Equipment", es = "Equipos medicos" },
    group_name_industrial = { en = "Industrial Devices", es = "Dispositivos industriales" },
    group_name_entertainment = { en = "Entertainment", es = "Entretenimiento" },
    close = { en = "Close", es = "Cerrar" },
    output_on = { en = "Energy ON", es = "Energia ON" },
    output_off = { en = "Energy OFF", es = "Energia OFF" },
    none = { en = "none", es = "ninguna" },
    unknown = { en = "Unknown", es = "Desconocido" },

    battery_title = { en = "Battery Status", es = "Estado de bateria" },
    solar_battery_title = { en = "Solar Battery Status", es = "Estado de bateria solar" },
    wind_battery_title = { en = "Wind Battery Status", es = "Estado de bateria eolica" },
    controller = { en = "Controller: %s", es = "Controlador: %s" },
    battery_role = { en = "Role: %s", es = "Rol: %s" },
    storage = { en = "Storage: %s / %s", es = "Almacen: %s / %s" },
    status = { en = "Status: %s", es = "Estado: %s" },
    state = { en = "State: %s", es = "Flujo: %s" },
    status_connected = { en = "Connected", es = "Conectado" },
    status_disconnected = { en = "Disconnected", es = "Desconectado" },
    producer_state_critical = { en = "Status: Critical", es = "Estado: Critico" },
    producer_state_offline = { en = "Status: Inoperative (requires repair)", es = "Estado: Inoperativo (requiere reparacion)" },
    state_charging = { en = "Charging", es = "Cargando" },
    state_discharging = { en = "Discharging", es = "Descargando" },
    state_idle = { en = "Idle", es = "En reposo" },
    state_empty = { en = "Empty", es = "Vacia" },

    panel_title = { en = "Solar panel", es = "Panel solar" },
    aerogenerator_panel_title = { en = "Aerogenerador panel", es = "Panel de aerogenerador" },
    hydro_panel_title = { en = "Hydraulic turbine", es = "Turbina hidraulica" },
    turbine_status = { en = "Turbine Status: %s", es = "Estado de la turbina: %s" },
    turbine_state_active = { en = "Active", es = "Activa" },
    turbine_state_idle = { en = "Idle", es = "Idle" },
    turbine_state_no_water = { en = "No Water", es = "Sin agua" },
    turbine_state_damaged = { en = "Damaged", es = "Danada" },
    wind_speed_line = { en = "Wind Speed: %s", es = "Velocidad de viento: %s" },
    wind_speed_high = { en = "Hight", es = "Alta" },
    wind_speed_medium = { en = "Medium", es = "Media" },
    wind_speed_low = { en = "Low", es = "Baja" },
    type = { en = "Type: %s", es = "Tipo: %s" },
    bonus = { en = "Bonus: %s", es = "Bono: %s" },
    condition = { en = "Condition: %s%%", es = "Condicion: %s%%" },
    integrity = { en = "Integrity: %s%%%s", es = "Integridad: %s%%%s" },
    integrity_worn_suffix = {
        en = " (production reduced by wear)",
        es = " (produccion reducida por desgaste)",
    },
    production = { en = "Current production: %s W", es = "Produccion actual: %s W" },
    max = { en = "Maximum production: %s W", es = "Produccion maxima: %s W" },
    efficiency = { en = "Efficiency: %s%%", es = "Eficiencia: %s%%" },

    weather_clear = { en = "Clear", es = "Despejado" },
    weather_cloudy = { en = "Cloudy", es = "Nublado" },
    weather_rain = { en = "Rain", es = "Lluvia" },
    weather_fog = { en = "Fog", es = "Niebla" },
    weather_storm = { en = "Storm", es = "Tormenta" },
    weather_snow = { en = "Snow", es = "Nieve" },
    weather_night = { en = "Night", es = "Noche" },
    role_master = { en = "Master", es = "Maestro" },
    role_slave = { en = "Slave", es = "Esclavo" },
    role_controller = { en = "Controller", es = "Controlador" },
    group_disabled = { en = "Disabled", es = "Desactivado" },
    group_powered = { en = "Powered", es = "Activo" },
    group_limited = { en = "Limited", es = "Limitado" },
    show_consumption_details = { en = "Show consumption details", es = "Mostrar detalles de consumo" },
    hide_consumption_details = { en = "Hide consumption details", es = "Ocultar detalles de consumo" },
    consumption_details = { en = "Consumption Details", es = "Detalles de consumo" },
    total_consumption = { en = "Total consumption: %s W", es = "Total consumo: %s W" },
    detail_production = { en = "Total production: %s W", es = "Total produccion: %s W" },
    balance_line = { en = "Balance: %s W%s", es = "Balance: %s W%s" },
    balance_using_battery_suffix = { en = " (Using battery)", es = " (Usando bateria)" },
    balance_charging_suffix = { en = " (Charging battery)", es = " (Cargando bateria)" },
}

local COLORS = {
    bg = { r = 0.05, g = 0.12, b = 0.08, a = 0.90 },           -- #0E1A12
    border = { r = 0.18, g = 0.80, b = 0.44, a = 0.80 },       -- #2ECC71
    title = { r = 0.48, g = 1.00, b = 0.72, a = 1.00 },        -- #7CFFB2
    text = { r = 0.81, g = 1.00, b = 0.89, a = 1.00 },         -- #CFFFE2
    disabled = { r = 0.31, g = 0.42, b = 0.35, a = 1.00 },     -- #4F6B5A
}

local SECTION_COLORS = {
    fill = { r = 0.07, g = 0.13, b = 0.10, a = 0.45 },
    border = { r = 0.18, g = 0.25, b = 0.22, a = 0.75 },
    borderStrong = { r = 0.21, g = 0.31, b = 0.27, a = 0.92 },
    title = { r = 0.62, g = 0.88, b = 0.74, a = 0.95 },
}

local SHOW_PANEL_TYPE_DEBUG = false
if EnergyRouting and EnergyRouting.GetConfigValue then
    SHOW_PANEL_TYPE_DEBUG = EnergyRouting.GetConfigValue("DebugUI") == true
end
-- ON/OFF-only controller UI: hide priority selector and keep groups as state display only.
local SIMPLE_OUTPUT_ONLY_MODE = true

local WIND_TURBINE_SOUND_BY_SPEED = {
    low = "SPESS_WindTurbine_Low",
    medium = "SPESS_WindTurbine_Medium",
    high = "SPESS_WindTurbine_High",
}

local WIND_TURBINE_VOLUME_BY_SPEED = {
    low = 0.22,
    medium = 0.50,
    high = 0.82,
}

local HYDRO_TURBINE_SOUND = "SPESS_HydroTurbine_Medium"
local HYDRO_TURBINE_VOLUME = 0.56
local HYDRO_TURBINE_ONE_SHOT_REPLAY_MS = 24000
local HYDRO_UI_AMBIENT_DELAY_MS = 1500

local WIND_TURBINE_ONE_SHOT_REPLAY_MS = 7000
local PRODUCER_CRITICAL_THRESHOLD = 0.30
local PRODUCER_OFFLINE_THRESHOLD = 0.20
local PRODUCER_CRITICAL_MULT = 0.50

local function clamp01(value)
    local num = tonumber(value) or 0
    if num < 0 then return 0 end
    if num > 1 then return 1 end
    return num
end

local function getClientAmbientVolumeMultiplier()
    if EnergyRouting and EnergyRouting.GetClientAmbientVolumeMultiplier then
        return clamp01(EnergyRouting.GetClientAmbientVolumeMultiplier())
    end
    return 1.0
end

local function scaleAmbientVolume(baseVolume)
    local base = clamp01(baseVolume)
    if getGameSpeed then
        local ok, speed = pcall(getGameSpeed)
        if ok and (tonumber(speed) or 1) > 1 then
            return 0
        end
    end
    return clamp01(base * getClientAmbientVolumeMultiplier())
end

local function getWorldTimestampMs()
    if getTimestampMs then
        local ok, value = pcall(getTimestampMs)
        if ok and type(value) == "number" and value > 0 then
            return value
        end
    end
    local gt = getGameTime and getGameTime() or nil
    local hours = gt and gt.getWorldAgeHours and gt:getWorldAgeHours() or 0
    return math.floor((hours or 0) * 3600000)
end

local function isFastForwardAudioSuppressed()
    if getGameSpeed then
        local ok, speed = pcall(getGameSpeed)
        if ok and (tonumber(speed) or 1) > 1 then
            return true
        end
    end
    return false
end

local function isValidSoundHandle(handle)
    if type(handle) == "number" then
        return handle ~= 0
    end
    if type(handle) == "string" then
        return handle ~= ""
    end
    return handle ~= nil
end

local function getLang()
    local core = getCore and getCore() or nil
    local lang = core and core.getOptionLanguage and core:getOptionLanguage() or nil
    if (not lang or tostring(lang) == "") and core and core.getOptionLanguageName then
        lang = core:getOptionLanguageName()
    end
    if not lang or tostring(lang) == "" then
        local tm = getTextManager and getTextManager() or nil
        local cl = tm and tm.getCurrentLanguage and tm:getCurrentLanguage() or nil
        if cl and cl.name then
            local ok, value = pcall(cl.name, cl)
            if ok and value then
                lang = value
            end
        end
        if (not lang or tostring(lang) == "") and cl and cl.toString then
            local ok, value = pcall(cl.toString, cl)
            if ok and value then
                lang = value
            end
        end
    end
    if type(lang) ~= "string" then
        return "en"
    end
    lang = string.lower(lang)
    if lang:find("es", 1, true) or lang:find("spa", 1, true) or lang:find("span", 1, true) then
        return "es"
    end
    return "en"
end

local function formatNumber(value)
    local num = tonumber(value) or 0
    local rounded = math.floor(num * 100 + 0.5) / 100
    local text = string.format("%.2f", rounded)
    text = text:gsub("%.?0+$", "")
    if text == "" then
        text = "0"
    end
    return text
end

local function formatKWh(value)
    local wh = tonumber(value) or 0
    return formatNumber(wh / 1000)
end

local function formatAutonomyHours(storedEnergy, currentConsumption)
    local stored = tonumber(storedEnergy) or 0
    local consumption = tonumber(currentConsumption) or 0
    if consumption <= 0 then
        return "--"
    end
    return formatNumber(stored / consumption)
end

local function getProducerWearInfo(degradation)
    local d = tonumber(degradation) or 1.0
    if d < 0 then
        d = 0
    elseif d > 1 then
        d = 1
    end
    if d < PRODUCER_OFFLINE_THRESHOLD then
        return 0, "offline", d
    end
    if d < PRODUCER_CRITICAL_THRESHOLD then
        return d * PRODUCER_CRITICAL_MULT, "critical", d
    end
    return d, "normal", d
end

local function t(key, ...)
    local entry = UI_STRINGS[key]
    local text = entry and (entry[getLang()] or entry.en) or key
    if select("#", ...) > 0 then
        return string.format(text, ...)
    end
    return text
end

local function getModeDescription(mode)
    if mode == "Survival" then
        return t("mode_desc_survival")
    end
    if mode == "Comfort" then
        return t("mode_desc_comfort")
    end
    if mode == "Manual" then
        return t("mode_desc_manual")
    end
    return t("mode_desc_balanced")
end

local function localizeMode(mode)
    if mode == "Survival" then
        return t("mode_survival")
    end
    if mode == "Comfort" then
        return t("mode_comfort")
    end
    if mode == "Manual" then
        return t("mode_manual")
    end
    return t("mode_balanced")
end

local function localizeGroupName(groupId, fallbackName)
    if not groupId then
        return fallbackName or ""
    end
    local key = "group_name_" .. tostring(groupId)
    if UI_STRINGS[key] then
        return t(key)
    end
    return fallbackName or tostring(groupId)
end


local function localizeWeather(label)
    if not label then
        return t("unknown")
    end
    local lowered = string.lower(tostring(label))
    if lowered:find("clear") then
        return t("weather_clear")
    end
    if lowered:find("cloud") then
        return t("weather_cloudy")
    end
    if lowered:find("rain") then
        return t("weather_rain")
    end
    if lowered:find("fog") then
        return t("weather_fog")
    end
    if lowered:find("storm") then
        return t("weather_storm")
    end
    if lowered:find("snow") then
        return t("weather_snow")
    end
    if lowered:find("night") then
        return t("weather_night")
    end
    return t("unknown")
end

local function localizeRole(role)
    if not role then
        return t("none")
    end
    local lowered = string.lower(tostring(role))
    if lowered == "master" then
        return t("role_master")
    end
    if lowered == "slave" then
        return t("role_slave")
    end
    if lowered == "controller" then
        return t("role_controller")
    end
    return tostring(role)
end

local function localizeWindSpeedByMultiplier(multiplier)
    local m = tonumber(multiplier)
    if not m then
        return t("unknown")
    end
    if m >= 0.85 then
        return t("wind_speed_high")
    end
    if m >= 0.65 then
        return t("wind_speed_medium")
    end
    return t("wind_speed_low")
end

local function getControllerWindSpeedText(state)
    local weather = EnergyRouting and EnergyRouting.Weather or nil
    local snapshot = weather and weather.GetWindSnapshot and weather.GetWindSnapshot() or nil
    local mult = tonumber(snapshot and snapshot.multiplier)
    if not mult then
        local windProduction = math.max(0, tonumber(state and state.windProduction) or 0)
        local windCount = math.max(0, tonumber(state and state.windCount) or 0)
        if windCount <= 0 then
            return t("unknown")
        end
        local nominalMax = windCount * 450
        if nominalMax <= 0 then
            return t("unknown")
        end
        mult = windProduction / nominalMax
    end
    return localizeWindSpeedByMultiplier(mult)
end

local function getSolarEfficiency()
    local climate = getClimateManager and getClimateManager() or nil
    if not climate then
        local gt = getGameTime and getGameTime() or nil
        local hour = gt and gt.getHour and gt:getHour() or nil
        if hour and hour >= 6 and hour < 20 then
            return 1.0
        end
        return 0
    end
    local dayLight = climate.getDayLightStrength and climate:getDayLightStrength() or 0
    local isDay = climate.isDay and climate:isDay() or (dayLight and dayLight > 0)
    if not isDay or dayLight <= 0 then
        local gt = getGameTime and getGameTime() or nil
        local hour = gt and gt.getHour and gt:getHour() or nil
        if hour and hour >= 6 and hour < 20 then
            dayLight = 1.0
        else
            return 0
        end
    end
    local cloud = climate.getCloudIntensity and climate:getCloudIntensity() or 0
    local rain = climate.getRainIntensity and climate:getRainIntensity() or 0
    local fog = climate.getFogIntensity and climate:getFogIntensity() or 0
    local efficiency = dayLight
    efficiency = efficiency * (1 - cloud * 0.5)
    efficiency = efficiency * (1 - rain * 0.3)
    efficiency = efficiency * (1 - fog * 0.2)
    if EnergyRouting and EnergyRouting.GetConfigValue then
        efficiency = efficiency * (EnergyRouting.GetConfigValue("SolarWeatherImpact") or 1.0)
    end
    if efficiency < 0 then
        efficiency = 0
    elseif efficiency > 1 then
        efficiency = 1
    end
    return efficiency
end

local function localizeGroupState(value)
    if SIMPLE_OUTPUT_ONLY_MODE then
        return (value == "powered") and t("group_powered") or t("group_disabled")
    end
    if value == "powered" then
        return t("group_powered")
    end
    if value == "limited" then
        return t("group_limited")
    end
    return t("group_disabled")
end

local function getSquareFromObj(obj)
    if obj and obj.getSquare then
        return obj:getSquare()
    end
    return nil
end

local function getWorldItem(obj)
    if not obj then
        return nil
    end
    if obj.getItem then
        return obj:getItem()
    end
    if obj.getInventoryItem then
        return obj:getInventoryItem()
    end
    if obj.item then
        return obj.item
    end
    if obj.items and obj.items[1] then
        return obj.items[1]
    end
    return nil
end

local function getObjectModData(obj)
    if not obj then
        return nil
    end
    local item = getWorldItem(obj)
    if item and item.getModData then
        return item:getModData()
    end
    if obj.getModData then
        return obj:getModData()
    end
    return nil
end

local function getItemFullType(item)
    if not item then
        return nil
    end
    if item.getFullType then
        return item:getFullType()
    end
    if item.getType then
        local moduleName = item.getModule and item:getModule() or nil
        local typeName = item:getType()
        if moduleName and typeName then
            return moduleName .. "." .. typeName
        end
        return typeName
    end
    return nil
end

local function matchesSprite(obj, token)
    if not obj or not obj.getSprite then
        return false
    end
    local sprite = obj:getSprite()
    if not sprite or not sprite.getName then
        return false
    end
    local name = sprite:getName()
    return type(name) == "string" and string.find(name, token, 1, true) ~= nil
end

local function playHydroUiOpenSound(panelObj)
    local soundName = HYDRO_TURBINE_SOUND
    if isFastForwardAudioSuppressed() then
        return
    end
    local square = getSquareFromObj(panelObj)
    if not square then
        return
    end
    local world = getWorld and getWorld() or nil
    if not (world and world.getFreeEmitter) then
        return
    end
    local emitter = world:getFreeEmitter()
    if not emitter then
        return
    end
    if emitter.setPos then
        emitter:setPos(square:getX(), square:getY(), square:getZ())
    end
    if emitter.playSound then
        local ok, result = pcall(emitter.playSound, emitter, soundName)
        if ok and isValidSoundHandle(result) then
            local volume = scaleAmbientVolume(HYDRO_TURBINE_VOLUME)
            if volume <= 0 then
                return
            end
            if emitter.setVolume then
                pcall(emitter.setVolume, emitter, result, volume)
            elseif emitter.setVolumeAll then
                pcall(emitter.setVolumeAll, emitter, volume)
            end
        end
    end
end

local function hasWorldItemBacking(obj)
    return getWorldItem(obj) ~= nil
end

local function isWindBatteryObject(obj)
    if not obj then
        return false
    end
    local md = getObjectModData(obj)
    if md and md.windBattery then
        return true
    end
    local fullType = getItemFullType(getWorldItem(obj))
    if fullType == "EnergyRouting.WindBattery" or fullType == "WindBattery" then
        return true
    end
    return hasWorldItemBacking(obj) and matchesSprite(obj, "WindBattery")
end

local function isWindPanelObject(obj)
    if not obj then
        return false
    end
    local md = getObjectModData(obj)
    if md and md.wind then
        return true
    end
    local fullType = getItemFullType(getWorldItem(obj))
    if fullType == "EnergyRouting.Aerogenerador" or fullType == "Aerogenerador" then
        return true
    end
    return hasWorldItemBacking(obj) and (matchesSprite(obj, "Aerogenerador") or matchesSprite(obj, "WindTurbine"))
end

local function isHydroPanelObject(obj)
    if not obj then
        return false
    end
    local md = getObjectModData(obj)
    if md and md.hydro then
        return true
    end
    local fullType = getItemFullType(getWorldItem(obj))
    if fullType == "EnergyRouting.TurbinaHidraulica" or fullType == "TurbinaHidraulica" then
        return true
    end
    return hasWorldItemBacking(obj) and matchesSprite(obj, "TurbinaHidraulica")
end

local function hasBatteryMeta(obj)
    local md = getObjectModData(obj)
    if not md then
        return false
    end
    if md and md.windBattery then
        return true
    end
    local energy = md and md.energy or nil
    if not energy then
        return false
    end
    if energy.type == "solar" then
        return false
    end
    if energy.type == "battery" then
        return true
    end
    return energy.capacity ~= nil or energy.storedEnergy ~= nil
end

local function hasPanelMeta(obj)
    local md = getObjectModData(obj)
    return md and (md.panel ~= nil or md.wind ~= nil or md.hydro ~= nil)
end

local function findObjectOnSquare(square, predicate)
    if not square or not predicate then
        return nil
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if predicate(obj) then
            return obj
        end
    end
    if square.getSpecialObjects then
        local specialObjects = square:getSpecialObjects()
        for i = 0, specialObjects:size() - 1 do
            local obj = specialObjects:get(i)
            if predicate(obj) then
                return obj
            end
        end
    end
    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local obj = worldObjects:get(i)
        if predicate(obj) then
            return obj
        end
    end
    return nil
end

local function getSquareKey(square)
    if not square then
        return "no_square"
    end
    return tostring(square:getX()) .. "_" .. tostring(square:getY()) .. "_" .. tostring(square:getZ())
end

local function getObjectUiKey(obj, kind)
    if not obj then
        return nil
    end

    local md = getObjectModData(obj)
    if kind == "battery" then
        local windBattery = md and md.windBattery or nil
        if windBattery and windBattery.id then
            return "battery:" .. tostring(windBattery.id)
        end
        local energy = md and md.energy or nil
        if energy and energy.id then
            return "battery:" .. tostring(energy.id)
        end
    elseif kind == "panel" then
        local hydro = md and md.hydro or nil
        if hydro and hydro.id then
            return "panel:" .. tostring(hydro.id)
        end
        local wind = md and md.wind or nil
        if wind and wind.id then
            return "panel:" .. tostring(wind.id)
        end
        local panel = md and md.panel or nil
        if panel and panel.id then
            return "panel:" .. tostring(panel.id)
        end
        local energyPanel = md and md.energyPanel or nil
        if energyPanel and energyPanel.id then
            return "panel:" .. tostring(energyPanel.id)
        end
    end

    local squareKey = getSquareKey(getSquareFromObj(obj))
    local fullType = getItemFullType(getWorldItem(obj)) or "unknown"
    return tostring(kind or "object") .. ":" .. squareKey .. ":" .. tostring(fullType)
end

local function focusExistingUi(ui)
    if not ui then
        return false
    end
    if ui.setVisible then
        ui:setVisible(true)
    end
    if ui.bringToTop then
        ui:bringToTop()
    end
    return true
end

local EnergyOutputButton = ISButton:derive("EnergyOutputButton")

function EnergyOutputButton:new(x, y, width, height, target, onClick)
    local o = ISButton:new(x, y, width, height, "", target, onClick)
    setmetatable(o, self)
    self.__index = self
    o.powerEnabled = true
    return o
end

function EnergyOutputButton:setPowerEnabled(enabled)
    self.powerEnabled = enabled ~= false
    if self.powerEnabled then
        self:setTitle(t("output_on"))
    else
        self:setTitle(t("output_off"))
    end
end

function EnergyOutputButton:render()
    local color = self.powerEnabled and { r = 0.10, g = 0.42, b = 0.18, a = 0.95 }
        or { r = 0.72, g = 0.10, b = 0.10, a = 0.98 }
    self:drawRect(0, 0, self.width, self.height, color.a, color.r, color.g, color.b)
    self:drawRectBorder(0, 0, self.width, self.height, COLORS.border.a, COLORS.border.r, COLORS.border.g, COLORS.border.b)

    local txt = self.title or ""
    local font = UIFont.Small
    local tx = (self.width - getTextManager():MeasureStringX(font, txt)) / 2
    local ty = (self.height - getTextManager():getFontHeight(font)) / 2
    self:drawText(txt, tx, ty, 1, 1, 1, 1, font)
end

EnergyRoutingUI = ISPanel:derive("EnergyRoutingUI")

function EnergyRoutingUI:new(edcId, readOnly)
    local width = 560
    local desiredHeight = SIMPLE_OUTPUT_ONLY_MODE and 680 or 760
    local maxHeight = math.max(420, (getCore():getScreenHeight() or 1080) - 40)
    local height = math.min(desiredHeight, maxHeight)
    local x = (getCore():getScreenWidth() / 2) - (width / 2)
    local y = (getCore():getScreenHeight() / 2) - (height / 2)

    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.edcId = edcId
    o.readOnly = readOnly and true or false
    o.backgroundColor = COLORS.bg
    o.borderColor = COLORS.border
    o.moveWithMouse = false
    o.groupControls = {}
    o.groupOrder = {}
    o.showConsumptionDetails = false
    o.baseHeight = height
    o.expandedHeight = height
    o.consumptionGroupLabels = {}
    o.consumptionDetailControls = {}
    o.detailsContentBottom = height

    return o
end

function EnergyRoutingUI:initialise()
    ISPanel.initialise(self)
end

function EnergyRoutingUI:getProductionColumnLayout()
    local panelW = (self._layout and self._layout.panelW) or (self.width - 12)
    local pad = 12
    local gap = 14
    local usable = math.max(150, panelW - (pad * 2) - (gap * 2))
    local colW = math.floor(usable / 3)
    local leftX = pad
    local midX = leftX + colW + gap
    local rightX = midX + colW + gap
    return leftX, midX, rightX, colW
end

function EnergyRoutingUI:createChildren()
    local y = 12
    if SIMPLE_OUTPUT_ONLY_MODE then
        -- Let reflow derive height from actual visible sections (no dead space).
        self.baseMinHeight = nil
        self.expandedMinHeight = nil
    else
        self.baseMinHeight = 640
        self.expandedMinHeight = 780
    end
    self._layout = { panelX = 6, panelW = self.width - 12, contentTop = 8, gap = 8, footerH = 38, footerBottom = 6 }

    self.contentPanel = ISPanel:new(self._layout.panelX, self._layout.contentTop, self._layout.panelW, self.height - self._layout.footerH - 20)
    self.contentPanel:initialise()
    self.contentPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.contentPanel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self:addChild(self.contentPanel)

    self.headerBox = self:createSectionPanel(true)
    self.storageBox = self:createSectionPanel(false)
    self.productionBox = self:createSectionPanel(false)
    self.modeBox = self:createSectionPanel(false)
    self.groupsBox = self:createSectionPanel(false)
    self.detailsBox = self:createSectionPanel(false)

    local owner = self
    local function updateDragPosition()
        local mx = getMouseX and getMouseX() or nil
        local my = getMouseY and getMouseY() or nil
        if not mx or not my then
            return false
        end
        local nx = math.floor((mx - (owner._dragOffsetX or 0)) + 0.5)
        local ny = math.floor((my - (owner._dragOffsetY or 0)) + 0.5)
        owner:setX(nx)
        owner:setY(ny)
        return true
    end

    self.headerBox.onMouseDown = function(_, x, yMouse)
        owner:bringToTop()
        owner.dragging = true
        owner.dragX = x or 0
        owner.dragY = yMouse or 0
        local mx = getMouseX and getMouseX() or nil
        local my = getMouseY and getMouseY() or nil
        if mx and my then
            owner._dragOffsetX = mx - owner.x
            owner._dragOffsetY = my - owner.y
        else
            owner._dragOffsetX = owner.dragX
            owner._dragOffsetY = owner.dragY
        end
        return true
    end
    self.headerBox.onMouseMove = function(_, dx, dy)
        if owner.dragging then
            if not updateDragPosition() then
                owner:setX(math.floor((owner.x + (dx or 0)) + 0.5))
                owner:setY(math.floor((owner.y + (dy or 0)) + 0.5))
            end
            return true
        end
        return false
    end
    self.headerBox.onMouseMoveOutside = function(_, dx, dy)
        if owner.dragging then
            if not updateDragPosition() then
                owner:setX(math.floor((owner.x + (dx or 0)) + 0.5))
                owner:setY(math.floor((owner.y + (dy or 0)) + 0.5))
            end
            return true
        end
        return false
    end
    self.headerBox.onMouseUp = function()
        owner.dragging = false
        owner._dragOffsetX = nil
        owner._dragOffsetY = nil
        return true
    end
    self.headerBox.onMouseUpOutside = function()
        owner.dragging = false
        owner._dragOffsetX = nil
        owner._dragOffsetY = nil
        return true
    end

    self.footerPanel = ISPanel:new(self._layout.panelX, self.height - self._layout.footerH - self._layout.footerBottom, self._layout.panelW, self._layout.footerH)
    self.footerPanel:initialise()
    self.footerPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.footerPanel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self:addChild(self.footerPanel)

    local title = t("controller_title")
    if self.readOnly then
        title = title .. t("readonly_suffix")
    end
    self.titleLabel = ISLabel:new(12, y, 20, title, COLORS.title.r, COLORS.title.g, COLORS.title.b, COLORS.title.a, UIFont.Medium, true)
    self.headerBox:addChild(self.titleLabel)
    y = y + 28

    self.batterySectionLabel = ISLabel:new(12, y, 20, t("section_batteries_title"), COLORS.title.r, COLORS.title.g, COLORS.title.b, COLORS.title.a, UIFont.Small, true)
    self.storageBox:addChild(self.batterySectionLabel)
    y = y + 18

    self.storedEnergyLabel = ISLabel:new(12, y, 20, t("stored_energy", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.storageBox:addChild(self.storedEnergyLabel)
    y = y + 18

    self.maxCapacityLabel = ISLabel:new(12, y, 20, t("max_capacity", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.storageBox:addChild(self.maxCapacityLabel)
    y = y + 18

    self.autonomyLabel = ISLabel:new(12, y, 20, t("estimated_autonomy", "--"), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.storageBox:addChild(self.autonomyLabel)
    y = y + 18

    self.productionLabel = ISLabel:new(12, y, 20, t("total_production", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.storageBox:addChild(self.productionLabel)
    y = y + 18

    local leftX, midX, rightX = self:getProductionColumnLayout()
    local sectionHeaderColor = COLORS.title
    local rowSpacing = 16
    
    self.weatherLabel = ISLabel:new(leftX, y, 20, t("weather", t("unknown")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.weatherLabel)
    self.windSummaryLabel = ISLabel:new(midX, y, 20, t("wind_speed_line", t("unknown")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.windSummaryLabel)
    self.roleLabel = ISLabel:new(rightX, y, 20, t("role", localizeRole("controller")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.roleLabel)
    y = y + 18

    local sectionY = y + 64

    self.solarSectionLabel = ISLabel:new(leftX, sectionY, 20, t("section_solar"), sectionHeaderColor.r, sectionHeaderColor.g, sectionHeaderColor.b, sectionHeaderColor.a, UIFont.Small, true)
    self.productionBox:addChild(self.solarSectionLabel)
    self.windSectionLabel = ISLabel:new(midX, sectionY, 20, t("section_wind"), sectionHeaderColor.r, sectionHeaderColor.g, sectionHeaderColor.b, sectionHeaderColor.a, UIFont.Small, true)
    self.productionBox:addChild(self.windSectionLabel)
    self.hydroSectionLabel = ISLabel:new(rightX, sectionY, 20, t("section_hydraulic"), sectionHeaderColor.r, sectionHeaderColor.g, sectionHeaderColor.b, sectionHeaderColor.a, UIFont.Small, true)
    self.productionBox:addChild(self.hydroSectionLabel)
    sectionY = sectionY + 18

    self.solarPanelCountLabel = ISLabel:new(leftX, sectionY, 20, t("section_panels", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.solarPanelCountLabel)
    self.windCountLabel = ISLabel:new(midX, sectionY, 20, t("section_turbines", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.windCountLabel)
    self.hydroCountLabel = ISLabel:new(rightX, sectionY, 20, t("section_hydro_turbines", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.hydroCountLabel)
    sectionY = sectionY + rowSpacing

    self.solarBatteryCountLabel = ISLabel:new(leftX, sectionY, 20, t("section_batteries", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.solarBatteryCountLabel)
    self.windBatteryCountLabel = ISLabel:new(midX, sectionY, 20, t("section_wind_batteries", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.windBatteryCountLabel)
    self.hydroProductionLabel = ISLabel:new(rightX, sectionY, 20, t("section_production", "0"), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.hydroProductionLabel)
    sectionY = sectionY + rowSpacing

    self.solarProductionLabel = ISLabel:new(leftX, sectionY, 20, t("section_production", "0"), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.solarProductionLabel)
    self.windProductionLabel = ISLabel:new(midX, sectionY, 20, t("section_production", "0"), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.windProductionLabel)
    self.hydroStateLabel = ISLabel:new(rightX, sectionY, 20, t("status", t("section_state_disconnected")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.hydroStateLabel)
    sectionY = sectionY + rowSpacing

    self.solarStorageLabel = ISLabel:new(leftX, sectionY, 20, t("section_storage", "0"), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.solarStorageLabel)
    self.windStorageLabel = ISLabel:new(midX, sectionY, 20, t("section_storage", "0"), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.windStorageLabel)
    self.hydroBonusLabel = ISLabel:new(rightX, sectionY, 20, t("section_bonus_accumulated", "0"), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.hydroBonusLabel)
    sectionY = sectionY + rowSpacing

    self.solarBonusLabel = ISLabel:new(leftX, sectionY, 20, t("section_bonus_accumulated", "0"), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.solarBonusLabel)
    self.windBonusLabel = ISLabel:new(midX, sectionY, 20, t("section_bonus_accumulated", "0"), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.productionBox:addChild(self.windBonusLabel)
    y = sectionY + rowSpacing + 14

    self.modeLabel = ISLabel:new(12, y, 20, t("priority_mode"), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.modeBox:addChild(self.modeLabel)
    y = y + 14

    self.modeCombo = ISComboBox:new(12, y, 200, 20)
    self.modeCombo:initialise()
    self.modeValueByIndex = {}
    self.modeIndexByValue = {}
    local allowManual = EnergyRouting.GetConfigValue("AllowManualOverride")
    for _, mode in ipairs(EnergyRouting.PriorityModes) do
        if mode ~= "Manual" or allowManual then
            self.modeCombo:addOption(localizeMode(mode))
            local optionIndex = #self.modeCombo.options
            self.modeValueByIndex[optionIndex] = mode
            self.modeIndexByValue[mode] = optionIndex
        end
    end
    self.modeCombo.onChange = function()
        self:onModeChange()
    end
    self.modeBox:addChild(self.modeCombo)
    if SIMPLE_OUTPUT_ONLY_MODE then
        if self.modeBox.setVisible then
            self.modeBox:setVisible(false)
        end
        if self.modeLabel.setVisible then
            self.modeLabel:setVisible(false)
        end
        if self.modeCombo.setVisible then
            self.modeCombo:setVisible(false)
        end
        if self.modeCombo.setEnabled then
            self.modeCombo:setEnabled(false)
        end
    end
    y = y + 40

    y = y + 22

    local rowHeight = 18
    self.groupRows = {}
    self.groupsBox.padL = 12
    self.groupsBox.padR = 12
    self.groupsBox.colToggleW = 22
    self.groupsBox.colStateW = 110
    self.groupsBox.rowHeight = rowHeight
    self.groupsBox.rowsTop = 28
    self.groupsBox.rowTextOffset = 2
    self.groupsShowCheckboxes = false
    self.groupsBox.showCheckboxColumn = false

    local owner = self
    self.groupsBox.prerender = function(panel)
        ISPanel.prerender(panel)
        local tm = getTextManager()
        local font = UIFont.Small
        local innerW = panel.width - panel.padL - panel.padR
        local showCheckbox = panel.showCheckboxColumn == true
        local xName = showCheckbox and (panel.padL + panel.colToggleW + 6) or panel.padL
        local xStateR = panel.padL + innerW
        local stateColLeft = xStateR - panel.colStateW
        panel:drawText(t("groups"), panel.padL, 8, COLORS.title.r, COLORS.title.g, COLORS.title.b, COLORS.title.a, font)
        local fh = tm:getFontHeight(font)
        local stateOffsetY = math.floor((panel.rowHeight - fh) / 2)
        for _, row in ipairs(owner.groupRows or {}) do
            local control = owner.groupControls and owner.groupControls[row.groupId] or nil
            if control then
                local rowY = panel.rowsTop + ((control.row - 1) * panel.rowHeight)
                local textY = rowY + stateOffsetY
                panel:drawText(control.nameText or "", xName, textY, COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, font)
                local stateText = control.stateText or t("group_disabled")
                local tw = tm:MeasureStringX(font, tostring(stateText))
                local sx = math.max(stateColLeft, xStateR - tw)
                local c = control.stateColor or COLORS.disabled
                panel:drawText(stateText, sx, textY, c.r or COLORS.disabled.r, c.g or COLORS.disabled.g, c.b or COLORS.disabled.b, c.a or COLORS.disabled.a, font)
            end
        end
    end

    for rowIndex, group in ipairs(EnergyRouting.GroupsList) do
        local groupId = group.id
        local checkbox = ISTickBox:new(12, y + ((rowIndex - 1) * rowHeight), 22, rowHeight, "", self, function(target, _, selected)
            target:onGroupToggleById(groupId, selected)
        end)
        checkbox:initialise()
        if checkbox.setFont then
            checkbox:setFont(UIFont.Small)
        end
        checkbox.itemHgt = rowHeight
        checkbox.boxSize = 14
        checkbox:addOption("")
        self.groupsBox:addChild(checkbox)

        self.groupControls[group.id] = {
            index = 1,
            row = rowIndex,
            checkbox = checkbox,
            nameText = localizeGroupName(group.id, group.name),
            stateText = t("group_disabled"),
            stateColor = { r = COLORS.disabled.r, g = COLORS.disabled.g, b = COLORS.disabled.b, a = COLORS.disabled.a },
        }
        table.insert(self.groupOrder, group.id)
        table.insert(self.groupRows, { groupId = groupId, checkbox = checkbox })
    end

    y = y + (#EnergyRouting.GroupsList * rowHeight) + 8

    self.detailsToggleButton = ISButton:new(0, 0, 210, 24, t("show_consumption_details"), self, EnergyRoutingUI.onToggleConsumptionDetails)
    self.detailsToggleButton:initialise()
    self.footerPanel:addChild(self.detailsToggleButton)
    y = y + 26

    self.consumptionHeaderLabel = ISLabel:new(12, y, 20, t("consumption_details"), COLORS.title.r, COLORS.title.g, COLORS.title.b, COLORS.title.a, UIFont.Small, true)
    self.detailsBox:addChild(self.consumptionHeaderLabel)
    table.insert(self.consumptionDetailControls, self.consumptionHeaderLabel)
    y = y + 18

    for _, group in ipairs(EnergyRouting.GroupsList) do
        local label = ISLabel:new(12, y, 20, localizeGroupName(group.id, group.name) .. ": 0 W", COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
        self.detailsBox:addChild(label)
        self.consumptionGroupLabels[group.id] = label
        table.insert(self.consumptionDetailControls, label)
        y = y + 16
    end

    self.consumptionSeparatorLabel = ISLabel:new(12, y, 20, "--------------------------------", COLORS.disabled.r, COLORS.disabled.g, COLORS.disabled.b, COLORS.disabled.a, UIFont.Small, true)
    self.detailsBox:addChild(self.consumptionSeparatorLabel)
    table.insert(self.consumptionDetailControls, self.consumptionSeparatorLabel)
    y = y + 18

    self.totalConsumptionLabel = ISLabel:new(12, y, 20, t("total_consumption", "0"), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.detailsBox:addChild(self.totalConsumptionLabel)
    table.insert(self.consumptionDetailControls, self.totalConsumptionLabel)
    y = y + 18

    self.detailProductionLabel = ISLabel:new(12, y, 20, t("detail_production", "0"), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.detailsBox:addChild(self.detailProductionLabel)
    table.insert(self.consumptionDetailControls, self.detailProductionLabel)
    y = y + 18

    self.balanceLabel = ISLabel:new(12, y, 20, t("balance_line", "0", ""), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.detailsBox:addChild(self.balanceLabel)
    table.insert(self.consumptionDetailControls, self.balanceLabel)
    self.detailsContentBottom = y + 20

    if self.readOnly then
        if self.modeCombo and self.modeCombo.setEnabled then
            self.modeCombo:setEnabled(false)
        end
        for _, control in pairs(self.groupControls or {}) do
            if control.checkbox and control.checkbox.setEnabled then
                control.checkbox:setEnabled(false)
            end
        end
    end

    self.outputButton = EnergyOutputButton:new(0, 0, 80, 24, self, EnergyRoutingUI.onOutputToggle)
    self.outputButton:initialise()
    self.outputButton:setPowerEnabled(true)
    self.footerPanel:addChild(self.outputButton)
    print("[SPESS][UI] NEW_OUTPUT_BUTTON created edcId=" .. tostring(self.edcId))

    self.closeButton = ISButton:new(0, 0, 80, 24, t("close"), self, EnergyRoutingUI.onClose)
    self.closeButton:initialise()
    self.footerPanel:addChild(self.closeButton)

    self:setConsumptionDetailsVisible(false)
    self:updateOutputButton(true)
end

function EnergyRoutingUI:createSectionPanel(strong)
    local panel = ISPanel:new(0, 0, self.width - 12, 20)
    panel:initialise()
    panel.backgroundColor = { r = SECTION_COLORS.fill.r, g = SECTION_COLORS.fill.g, b = SECTION_COLORS.fill.b, a = SECTION_COLORS.fill.a }
    local border = strong and SECTION_COLORS.borderStrong or SECTION_COLORS.border
    panel.borderColor = { r = border.r, g = border.g, b = border.b, a = border.a }
    self:addChild(panel)
    return panel
end

local function createStyledSection(parent, strong)
    local panel = ISPanel:new(0, 0, parent.width - 12, 20)
    panel:initialise()
    panel.backgroundColor = { r = SECTION_COLORS.fill.r, g = SECTION_COLORS.fill.g, b = SECTION_COLORS.fill.b, a = SECTION_COLORS.fill.a }
    local border = strong and SECTION_COLORS.borderStrong or SECTION_COLORS.border
    panel.borderColor = { r = border.r, g = border.g, b = border.b, a = border.a }
    parent:addChild(panel)
    return panel
end

local function attachHeaderDrag(owner, headerBox)
    if not owner or not headerBox then
        return
    end

    local function updateDragPosition()
        local mx = getMouseX and getMouseX() or nil
        local my = getMouseY and getMouseY() or nil
        if not mx or not my then
            return false
        end
        local nx = math.floor((mx - (owner._dragOffsetX or 0)) + 0.5)
        local ny = math.floor((my - (owner._dragOffsetY or 0)) + 0.5)
        owner:setX(nx)
        owner:setY(ny)
        return true
    end

    headerBox.onMouseDown = function(_, x, yMouse)
        owner:bringToTop()
        owner.dragging = true
        owner.dragX = x or 0
        owner.dragY = yMouse or 0
        local mx = getMouseX and getMouseX() or nil
        local my = getMouseY and getMouseY() or nil
        if mx and my then
            owner._dragOffsetX = mx - owner.x
            owner._dragOffsetY = my - owner.y
        else
            owner._dragOffsetX = owner.dragX
            owner._dragOffsetY = owner.dragY
        end
        return true
    end

    headerBox.onMouseMove = function(_, dx, dy)
        if owner.dragging then
            if not updateDragPosition() then
                owner:setX(math.floor((owner.x + (dx or 0)) + 0.5))
                owner:setY(math.floor((owner.y + (dy or 0)) + 0.5))
            end
            return true
        end
        return false
    end

    headerBox.onMouseMoveOutside = function(_, dx, dy)
        if owner.dragging then
            if not updateDragPosition() then
                owner:setX(math.floor((owner.x + (dx or 0)) + 0.5))
                owner:setY(math.floor((owner.y + (dy or 0)) + 0.5))
            end
            return true
        end
        return false
    end

    headerBox.onMouseUp = function()
        owner.dragging = false
        owner._dragOffsetX = nil
        owner._dragOffsetY = nil
        return true
    end

    headerBox.onMouseUpOutside = function()
        owner.dragging = false
        owner._dragOffsetX = nil
        owner._dragOffsetY = nil
        return true
    end
end

if EnergyRouting and EnergyRouting._windWorldSoundTick and Events and Events.OnTick and Events.OnTick.Remove then
    pcall(Events.OnTick.Remove, EnergyRouting._windWorldSoundTick)
    EnergyRouting._windWorldSoundTick = nil
end

function EnergyRoutingUI:layoutFooter()
    if not self.footerPanel then
        return
    end
    local panelW = self.footerPanel.width
    local btnH = 24
    local pad = 6
    local gap = 10
    local y = math.floor((self.footerPanel.height - btnH) / 2)
    local closeW = 80
    local outputW = 80
    local closeX = panelW - closeW - pad
    local outputX = closeX - gap - outputW
    local detailsX = pad
    local detailsW = math.max(160, outputX - gap - detailsX)
    if self.detailsToggleButton then
        self.detailsToggleButton:setX(detailsX)
        self.detailsToggleButton:setY(y)
        self.detailsToggleButton:setWidth(detailsW)
        self.detailsToggleButton:setHeight(btnH)
    end
    if self.outputButton then
        self.outputButton:setX(outputX)
        self.outputButton:setY(y)
        self.outputButton:setWidth(outputW)
        self.outputButton:setHeight(btnH)
    end
    if self.closeButton then
        self.closeButton:setX(closeX)
        self.closeButton:setY(y)
        self.closeButton:setWidth(closeW)
        self.closeButton:setHeight(btnH)
    end
end

function EnergyRoutingUI:reflow()
    local layout = self._layout or { panelX = 6, panelW = self.width - 12, contentTop = 8, gap = 8, footerH = 38, footerBottom = 6 }
    local panelX = layout.panelX or 6
    local panelW = layout.panelW or (self.width - 12)
    local top = layout.contentTop or 8
    local gap = layout.gap or 8
    local footerH = layout.footerH or 38
    local footerBottom = layout.footerBottom or 6
    local maxHeight = math.max(420, (getCore() and getCore():getScreenHeight() or 1080) - 40)
    local leftX, midX, rightX = self:getProductionColumnLayout()
    local rowSpacing = 16

    local y = top
    self.headerBox:setX(panelX)
    self.headerBox:setY(y)
    self.headerBox:setWidth(panelW)
    self.headerBox:setHeight(34)
    self.titleLabel:setX(leftX)
    self.titleLabel:setY(8)
    y = y + self.headerBox.height + gap

    self.storageBox:setX(panelX)
    self.storageBox:setY(y)
    self.storageBox:setWidth(panelW)
    self.storageBox:setHeight(116)
    local sy = 8
    self.batterySectionLabel:setX(leftX); self.batterySectionLabel:setY(sy); sy = sy + 18
    self.storedEnergyLabel:setX(leftX); self.storedEnergyLabel:setY(sy); sy = sy + 18
    self.maxCapacityLabel:setX(leftX); self.maxCapacityLabel:setY(sy); sy = sy + 18
    self.autonomyLabel:setX(leftX); self.autonomyLabel:setY(sy); sy = sy + 18
    self.productionLabel:setX(leftX); self.productionLabel:setY(sy)
    y = y + self.storageBox.height + gap

    self.productionBox:setX(panelX)
    self.productionBox:setY(y)
    self.productionBox:setWidth(panelW)
    self.productionBox:setHeight(136)
    local py = 8
    self.weatherLabel:setX(leftX); self.weatherLabel:setY(py)
    self.windSummaryLabel:setX(midX); self.windSummaryLabel:setY(py)
    self.roleLabel:setX(rightX); self.roleLabel:setY(py); py = py + 20
    self.solarSectionLabel:setX(leftX); self.solarSectionLabel:setY(py)
    self.windSectionLabel:setX(midX); self.windSectionLabel:setY(py)
    self.hydroSectionLabel:setX(rightX); self.hydroSectionLabel:setY(py); py = py + 18
    self.solarPanelCountLabel:setX(leftX); self.solarPanelCountLabel:setY(py)
    self.windCountLabel:setX(midX); self.windCountLabel:setY(py)
    self.hydroCountLabel:setX(rightX); self.hydroCountLabel:setY(py); py = py + rowSpacing
    self.solarBatteryCountLabel:setX(leftX); self.solarBatteryCountLabel:setY(py)
    self.windBatteryCountLabel:setX(midX); self.windBatteryCountLabel:setY(py)
    self.hydroProductionLabel:setX(rightX); self.hydroProductionLabel:setY(py); py = py + rowSpacing
    self.solarProductionLabel:setX(leftX); self.solarProductionLabel:setY(py)
    self.windProductionLabel:setX(midX); self.windProductionLabel:setY(py)
    self.hydroStateLabel:setX(rightX); self.hydroStateLabel:setY(py); py = py + rowSpacing
    self.solarStorageLabel:setX(leftX); self.solarStorageLabel:setY(py)
    self.windStorageLabel:setX(midX); self.windStorageLabel:setY(py)
    self.hydroBonusLabel:setX(rightX); self.hydroBonusLabel:setY(py); py = py + rowSpacing
    self.solarBonusLabel:setX(leftX); self.solarBonusLabel:setY(py)
    self.windBonusLabel:setX(midX); self.windBonusLabel:setY(py)
    y = y + self.productionBox.height + gap

    if SIMPLE_OUTPUT_ONLY_MODE then
        self.modeBox:setX(panelX)
        self.modeBox:setY(y)
        self.modeBox:setWidth(panelW)
        self.modeBox:setHeight(0)
        if self.modeBox.setVisible then
            self.modeBox:setVisible(false)
        end
    else
        self.modeBox:setX(panelX)
        self.modeBox:setY(y)
        self.modeBox:setWidth(panelW)
        self.modeBox:setHeight(70)
        if self.modeBox.setVisible then
            self.modeBox:setVisible(true)
        end
        self.modeLabel:setX(leftX); self.modeLabel:setY(8)
        self.modeCombo:setX(leftX); self.modeCombo:setY(28)
        y = y + self.modeBox.height + gap
    end

    self.groupsBox:setX(panelX)
    self.groupsBox:setY(y)
    self.groupsBox:setWidth(panelW)
    local padL = self.groupsBox.padL or 12
    local rowH = self.groupsBox.rowHeight or 18
    local showCheckbox = self.groupsShowCheckboxes == true
    self.groupsBox.showCheckboxColumn = showCheckbox
    local colToggle = padL
    local gy = self.groupsBox.rowsTop or 28
    local groupsBottom = gy + padL
    for _, group in ipairs(EnergyRouting.GroupsList) do
        local control = self.groupControls[group.id]
        if control then
            local row = control.row or 1
            local rowY = gy + ((row - 1) * rowH)
            if control.checkbox then
                control.checkbox:setX(colToggle)
                control.checkbox:setY(rowY)
                control.checkbox.itemHgt = rowH
                control.checkbox.boxSize = 14
                if control.checkbox.setVisible then
                    control.checkbox:setVisible(showCheckbox)
                end
            end
            groupsBottom = math.max(groupsBottom, rowY + rowH + padL)
        end
    end
    local minGroupsHeight = (self.groupsBox.rowsTop or 28) + padL
    local groupsHeight = math.max(minGroupsHeight, groupsBottom)
    self.groupsBox:setHeight(groupsHeight)
    y = y + groupsHeight + gap
    local collapsedBottom = y - gap

    self.detailsBox:setX(panelX)
    self.detailsBox:setY(y)
    self.detailsBox:setWidth(panelW)
    local detailsPadX = 10
    local detailsPadTop = 8
    local detailsPadBottom = 8
    local dy = detailsPadTop
    self.consumptionHeaderLabel:setX(detailsPadX); self.consumptionHeaderLabel:setY(dy); dy = dy + 18
    for _, group in ipairs(EnergyRouting.GroupsList) do
        local label = self.consumptionGroupLabels[group.id]
        if label then
            label:setX(detailsPadX)
            label:setY(dy)
        end
        dy = dy + 16
    end
    self.consumptionSeparatorLabel:setX(detailsPadX); self.consumptionSeparatorLabel:setY(dy); dy = dy + 18
    self.totalConsumptionLabel:setX(detailsPadX); self.totalConsumptionLabel:setY(dy); dy = dy + 18
    self.detailProductionLabel:setX(detailsPadX); self.detailProductionLabel:setY(dy); dy = dy + 18
    self.balanceLabel:setX(detailsPadX); self.balanceLabel:setY(dy); dy = dy + 20
    self.detailsBox:setHeight(dy + detailsPadBottom)
    if self.showConsumptionDetails then
        self.detailsBox:setVisible(true)
        y = y + self.detailsBox.height + gap
    else
        self.detailsBox:setVisible(false)
    end
    local expandedBottom = self.showConsumptionDetails and (y - gap) or collapsedBottom

    local collapsedHeightWanted = collapsedBottom + footerH + footerBottom + 2
    local expandedHeightWanted = expandedBottom + footerH + footerBottom + 2
    self.baseHeight = math.min(math.max(collapsedHeightWanted, self.baseMinHeight or collapsedHeightWanted), maxHeight)
    self.expandedHeight = math.min(math.max(expandedHeightWanted, self.expandedMinHeight or self.baseHeight), maxHeight)
    local targetHeight = self.showConsumptionDetails and self.expandedHeight or self.baseHeight
    if SIMPLE_OUTPUT_ONLY_MODE then
        -- Compact simple mode to the true bottom of visible content.
        local lastContentBottom = collapsedBottom
        if self.showConsumptionDetails and self.detailsBox and self.detailsBox.getIsVisible and self.detailsBox:getIsVisible() then
            lastContentBottom = math.max(lastContentBottom, (self.detailsBox:getY() or 0) + (self.detailsBox:getHeight() or 0))
        elseif self.groupsBox then
            lastContentBottom = math.max(lastContentBottom, (self.groupsBox:getY() or 0) + (self.groupsBox:getHeight() or 0))
        end
        local compactWanted = lastContentBottom + footerH + footerBottom + 2
        targetHeight = math.min(targetHeight, math.min(compactWanted, maxHeight))
    end
    local oldY = self.y
    if self.setHeight then
        self:setHeight(targetHeight)
    else
        self.height = targetHeight
    end
    self:setY(oldY)
    local screenH = (getCore() and getCore():getScreenHeight() or 1080)
    local bottomMargin = 10
    local topMargin = 10
    local bottom = self.y + targetHeight
    local maxBottom = screenH - bottomMargin
    if bottom > maxBottom then
        self:setY(math.max(topMargin, maxBottom - targetHeight))
    elseif self.y < topMargin then
        self:setY(topMargin)
    end

    self.contentPanel:setX(panelX)
    self.contentPanel:setY(top)
    self.contentPanel:setWidth(panelW)
    self.contentPanel:setHeight(self.height - footerH - footerBottom - top)
    self.footerPanel:setX(panelX)
    self.footerPanel:setY(self.height - footerH - footerBottom)
    self.footerPanel:setWidth(panelW)
    self.footerPanel:setHeight(footerH)
    self:layoutFooter()
end

function EnergyRoutingUI:refreshSectionBoxes()
    self:reflow()
end

function EnergyRoutingUI:prerender()
    ISPanel.prerender(self)
end

function EnergyRoutingUI:onMouseUp(x, y)
    self.dragging = false
    self._dragOffsetX = nil
    self._dragOffsetY = nil
    return ISPanel.onMouseUp(self, x, y)
end

function EnergyRoutingUI:onMouseUpOutside(x, y)
    self.dragging = false
    self._dragOffsetX = nil
    self._dragOffsetY = nil
    if ISPanel.onMouseUpOutside then
        return ISPanel.onMouseUpOutside(self, x, y)
    end
    return true
end

function EnergyRoutingUI:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    if EnergyRouting and EnergyRouting.UI then
        EnergyRouting.UI.instance = nil
    end
    if EnergyRouting and EnergyRouting.Client and EnergyRouting.Client.OnPanelClosed then
        EnergyRouting.Client.OnPanelClosed(self.edcId)
    end
end

function EnergyRoutingUI:onModeChange()
    if SIMPLE_OUTPUT_ONLY_MODE then
        return
    end
    if self.readOnly then
        return
    end
    if not self.edcId then
        return
    end
    local selected = self.modeValueByIndex and self.modeValueByIndex[self.modeCombo.selected] or self.modeCombo.options[self.modeCombo.selected]
    if selected then
        EnergyRouting.Client.SendMode(self.edcId, selected)
        self:updateModeHint(selected)
    end
end

function EnergyRoutingUI:onGroupToggle(index, selected)
    local groupId = self.groupOrder[index]
    if groupId then
        self:onGroupToggleById(groupId, selected)
    end
end

function EnergyRoutingUI:onGroupToggleById(groupId, selected)
    if SIMPLE_OUTPUT_ONLY_MODE then
        return
    end
    if self._suppressGroupToggle then
        return
    end
    if self.readOnly then
        return
    end
    local state = EnergyRouting and EnergyRouting.Client and EnergyRouting.Client.GetState and EnergyRouting.Client.GetState(self.edcId) or nil
    local mode = state and state.mode or "Balanced"
    if mode ~= "Manual" then
        local control = groupId and self.groupControls and self.groupControls[groupId] or nil
        local keepSelected = state and state.toggles and state.toggles[groupId]
        if control and control.checkbox and control.checkbox.setSelected then
            control.checkbox:setSelected(1, keepSelected ~= false)
        end
        return
    end
    if not groupId then
        return
    end
    EnergyRouting.Client.SendToggle(self.edcId, groupId, selected)
end

function EnergyRoutingUI:onOutputToggle()
    if self.readOnly or not self.edcId then
        return
    end
    local state = EnergyRouting and EnergyRouting.Client and EnergyRouting.Client.GetState and EnergyRouting.Client.GetState(self.edcId) or nil
    local current = true
    if state and state.outputEnabled ~= nil then
        current = state.outputEnabled ~= false
    elseif self.outputEnabled ~= nil then
        current = self.outputEnabled ~= false
    end
    local nextEnabled = not current
    self.outputEnabled = nextEnabled
    self:updateOutputButton(nextEnabled)
    if EnergyRouting and EnergyRouting.Client and EnergyRouting.Client.SendOutputEnabled then
        EnergyRouting.Client.SendOutputEnabled(self.edcId, nextEnabled)
    end
end

function EnergyRoutingUI:onToggleConsumptionDetails()
    self:setConsumptionDetailsVisible(not self.showConsumptionDetails)
end

function EnergyRoutingUI:setConsumptionDetailsVisible(visible)
    self.showConsumptionDetails = visible and true or false
    if self.detailsToggleButton then
        self.detailsToggleButton:setTitle(t(self.showConsumptionDetails and "hide_consumption_details" or "show_consumption_details"))
    end

    for _, control in ipairs(self.consumptionDetailControls or {}) do
        if control and control.setVisible then
            control:setVisible(self.showConsumptionDetails)
        end
    end
    self:reflow()
end

function EnergyRoutingUI:updateOutputButton(enabled)
    if not self.outputButton then
        return
    end
    local isOn = enabled ~= false
    if self.outputButton.setPowerEnabled then
        self.outputButton:setPowerEnabled(isOn)
    else
        self.outputButton:setTitle(t(isOn and "output_on" or "output_off"))
    end
end

function EnergyRoutingUI:applyState(state)
    if not state then
        return
    end

    if not state.groupStates then
        local fallback = {}
        local hasPower = ((state.production or 0) > 0) or ((state.storage or 0) > 0)
        local toggles = state.toggles or (EnergyRouting.MakeDefaultToggles and EnergyRouting.MakeDefaultToggles()) or {}
        for _, group in ipairs(EnergyRouting.GroupsList) do
            if toggles[group.id] ~= false then
                fallback[group.id] = hasPower and "powered" or (SIMPLE_OUTPUT_ONLY_MODE and "disabled" or "limited")
            else
                fallback[group.id] = "disabled"
            end
        end
        state.groupStates = fallback
    end

    local totalConsumption = tonumber(state.consumptionTotal or state.consumption) or 0
    local totalStorage = tonumber(state.storage) or 0
    local totalCapacity = tonumber(state.capacity or state.totalCapacity) or 0
    local solarCapacity = tonumber(state.solarCapacity) or 0
    local windCapacity = tonumber(state.windCapacity) or 0
    if totalCapacity <= 0 then
        totalCapacity = solarCapacity + windCapacity
    end

    if self.storedEnergyLabel then
        self.storedEnergyLabel:setName(t("stored_energy", formatKWh(totalStorage)))
    end
    if self.maxCapacityLabel then
        self.maxCapacityLabel:setName(t("max_capacity", formatKWh(totalCapacity)))
    end
    if self.autonomyLabel then
        self.autonomyLabel:setName(t("estimated_autonomy", formatAutonomyHours(totalStorage, totalConsumption)))
    end
    if self.productionLabel then
        self.productionLabel:setName(t("total_production", formatNumber(state.production)))
    end
    if self.productionLabel then
        local energySource = state.energySource
        if not energySource then
            if (state.production or 0) > 0 then
                energySource = "solar"
            elseif (state.storage or 0) > 0 then
                energySource = "battery"
            end
        end
        if energySource == "solar" then
            self.productionLabel.r = 0.4
            self.productionLabel.g = 1.0
            self.productionLabel.b = 0.4
        elseif energySource == "battery" then
            self.productionLabel.r = 1.0
            self.productionLabel.g = 0.9
            self.productionLabel.b = 0.4
        else
            self.productionLabel.r = COLORS.text.r
            self.productionLabel.g = COLORS.text.g
            self.productionLabel.b = COLORS.text.b
        end
    end
    if self.weatherLabel then
        self.weatherLabel:setName(t("weather", localizeWeather(state.weather)))
    end
    if self.windSummaryLabel then
        self.windSummaryLabel:setName(t("wind_speed_line", getControllerWindSpeedText(state)))
    end
    if self.roleLabel then
        self.roleLabel:setName(t("role", localizeRole(state.role or "controller")))
    end
    if self.solarPanelCountLabel then
        self.solarPanelCountLabel:setName(t("section_panels", tostring(state.panelCount or 0)))
    end
    if self.solarBatteryCountLabel then
        self.solarBatteryCountLabel:setName(t("section_batteries", tostring(state.batteryCount or 0)))
    end
    local solarProductionTotal = tonumber(state.solarProduction) or 0
    local windProductionTotal = tonumber(state.windProduction) or 0
    local hydroCount = tonumber(state.hydroCount) or 0
    local hydroProductionTotal = tonumber(state.hydroProduction) or 0
    local hydroBonusPercent = tonumber(state.hydroBonusPercent) or 0
    local hydroStateText = t("section_state_disconnected")
    if hydroCount > 0 then
        if hydroProductionTotal > 0 then
            hydroStateText = t("section_state_active")
        else
            hydroStateText = t("section_state_inactive")
        end
    end
    if self.solarProductionLabel then
        self.solarProductionLabel:setName(t("section_production", formatNumber(solarProductionTotal)))
    end
    if self.solarStorageLabel then
        self.solarStorageLabel:setName(t("section_storage", formatKWh(state.solarStorage or 0)))
    end
    if self.solarBonusLabel then
        self.solarBonusLabel:setName(t("section_bonus_accumulated", formatNumber(state.solarBonusPercent or 0)))
    end
    if self.windCountLabel then
        self.windCountLabel:setName(t("section_turbines", tostring(state.windCount or 0)))
    end
    if self.windBatteryCountLabel then
        self.windBatteryCountLabel:setName(t("section_wind_batteries", tostring(state.windBatteryCount or 0)))
    end
    if self.windProductionLabel then
        self.windProductionLabel:setName(t("section_production", formatNumber(windProductionTotal)))
    end
    if self.windStorageLabel then
        self.windStorageLabel:setName(t("section_storage", formatKWh(state.windStorage or 0)))
    end
    if self.windBonusLabel then
        self.windBonusLabel:setName(t("section_bonus_accumulated", formatNumber(state.windBonusPercent or 0)))
    end
    if self.hydroCountLabel then
        self.hydroCountLabel:setName(t("section_hydro_turbines", tostring(hydroCount)))
    end
    if self.hydroProductionLabel then
        self.hydroProductionLabel:setName(t("section_production", formatNumber(hydroProductionTotal)))
    end
    if self.hydroStateLabel then
        self.hydroStateLabel:setName(t("status", hydroStateText))
    end
    if self.hydroBonusLabel then
        self.hydroBonusLabel:setName(t("section_bonus_accumulated", formatNumber(hydroBonusPercent)))
    end
    if self.batteryRoleLabel then
        local master = t("none")
        if state.batteries then
            for _, battery in ipairs(state.batteries) do
                if battery.role == "master" then
                    master = battery.id
                    break
                end
            end
        end
        self.batteryRoleLabel:setName(t("master_battery", tostring(master)))
    end

    if self.modeCombo and not SIMPLE_OUTPUT_ONLY_MODE then
        local idx = self.modeIndexByValue and self.modeIndexByValue[state.mode] or nil
        if idx then
            self.modeCombo.selected = idx
        end
        self:updateModeHint(state.mode)
    end
    do
        local editable = (not SIMPLE_OUTPUT_ONLY_MODE) and (not self.readOnly) and (state.mode == "Manual")
        self.groupsShowCheckboxes = editable
        if self.groupsBox then
            self.groupsBox.showCheckboxColumn = editable
        end
        for _, control in pairs(self.groupControls or {}) do
            if control.checkbox then
                if control.checkbox.setEnabled then
                    control.checkbox:setEnabled(editable)
                end
                if control.checkbox.setVisible then
                    control.checkbox:setVisible(editable)
                end
            end
        end
    end
    if self.outputButton then
        self.outputEnabled = state.outputEnabled ~= false
        self:updateOutputButton(self.outputEnabled)
        if self.outputButton.setEnable then
            self.outputButton:setEnable(not self.readOnly)
        elseif self.outputButton.setEnabled then
            self.outputButton:setEnabled(not self.readOnly)
        end
    end

    local byGroup = state.groupConsumption or {}
    local demandByGroup = state.groupDemand or {}
    local hasLiveConsumption = false
    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
        if (tonumber(byGroup[group.id]) or 0) > 0 then
            hasLiveConsumption = true
            break
        end
    end
    -- If current consumption is zero (for example right after storage topology changes),
    -- keep details useful by showing detected demand instead of hard-resetting to 0.
    if (not hasLiveConsumption) and (tonumber(state.detectedConsumerCount) or 0) > 0 then
        byGroup = demandByGroup
    end
    if self.consumptionGroupLabels then
        for _, group in ipairs(EnergyRouting.GroupsList) do
            local label = self.consumptionGroupLabels[group.id]
            if label then
                local watts = tonumber(byGroup[group.id]) or 0
                label:setName(localizeGroupName(group.id, group.name) .. ": " .. formatNumber(watts) .. " W")
            end
        end
    end

    local detailProduction = solarProductionTotal + windProductionTotal + hydroProductionTotal
    if detailProduction <= 0 then
        detailProduction = tonumber(state.production) or 0
    end
    if state.detectedConsumerCount ~= nil and self._lastDetectedConsumerCount ~= state.detectedConsumerCount then
        self._lastDetectedConsumerCount = state.detectedConsumerCount
        print("[SPESS][UI] detectedConsumers=" .. tostring(state.detectedConsumerCount)
            .. " totalConsumption=" .. tostring(math.floor(totalConsumption)))
    end
    local balance = tonumber(state.balance)
    -- If displayed consumption is zero, show balance equal to total production.
    if math.abs(totalConsumption) < 0.005 then
        balance = detailProduction
    elseif balance == nil then
        balance = detailProduction - totalConsumption
    end
    local balanceText = formatNumber(balance)
    if balance > 0 then
        balanceText = "+" .. balanceText
    end
    local balanceSuffix = ""
    if balance < 0 and (state.usesBattery == true or (tonumber(state.storage) or 0) > 0) then
        balanceSuffix = t("balance_using_battery_suffix")
    elseif balance > 0 then
        balanceSuffix = t("balance_charging_suffix")
    end

    if self.totalConsumptionLabel then
        self.totalConsumptionLabel:setName(t("total_consumption", formatNumber(totalConsumption)))
    end
    if self.detailProductionLabel then
        self.detailProductionLabel:setName(t("detail_production", formatNumber(detailProduction)))
    end
    if self.balanceLabel then
        self.balanceLabel:setName(t("balance_line", balanceText, balanceSuffix))
        if balance < 0 then
            self.balanceLabel.r = 1.0
            self.balanceLabel.g = 0.72
            self.balanceLabel.b = 0.25
        elseif balance > 0 then
            self.balanceLabel.r = 0.4
            self.balanceLabel.g = 1.0
            self.balanceLabel.b = 0.4
        else
            self.balanceLabel.r = COLORS.text.r
            self.balanceLabel.g = COLORS.text.g
            self.balanceLabel.b = COLORS.text.b
        end
    end

    self._suppressGroupToggle = true
    for groupId, control in pairs(self.groupControls) do
        local toggle = SIMPLE_OUTPUT_ONLY_MODE and false or (state.toggles and state.toggles[groupId])
        if toggle ~= nil and control.checkbox and control.checkbox.setSelected then
            control.checkbox:setSelected(1, toggle)
        end

        local stateValue = state.groupStates and state.groupStates[groupId] or "disabled"
        if SIMPLE_OUTPUT_ONLY_MODE then
            stateValue = (stateValue == "powered") and "powered" or "disabled"
        end
        control.stateText = localizeGroupState(stateValue)
        if stateValue == "powered" then
            control.stateColor = { r = 0.4, g = 1.0, b = 0.4, a = 1.0 }
        elseif stateValue == "limited" then
            control.stateColor = { r = 1.0, g = 0.8, b = 0.2, a = 1.0 }
        else
            control.stateColor = { r = COLORS.disabled.r, g = COLORS.disabled.g, b = COLORS.disabled.b, a = COLORS.disabled.a }
        end
    end
    self._suppressGroupToggle = false
end

function EnergyRoutingUI:updateModeHint(mode)
    return
end

function EnergyRoutingUI:update()
    local state = nil
    if EnergyRouting and EnergyRouting.Client then
        if EnergyRouting.Client.GetState then
            state = EnergyRouting.Client.GetState(self.edcId)
        elseif EnergyRouting.Client.stateById then
            state = EnergyRouting.Client.stateById[self.edcId]
        end
    end
    if not state then
        return
    end
    self:applyState(state)
end

EnergyBatteryUI = ISPanel:derive("EnergyBatteryUI")

function EnergyBatteryUI:new(batteryObj)
    local width = 320
    local height = 258
    local x = (getCore():getScreenWidth() / 2) - (width / 2)
    local y = (getCore():getScreenHeight() / 2) - (height / 2)

    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.batteryObj = batteryObj
    o.batterySquare = getSquareFromObj(batteryObj)
    o.uiObjectKey = getObjectUiKey(batteryObj, "battery")
    o.lastStoredEnergy = nil
    o.backgroundColor = COLORS.bg
    o.borderColor = COLORS.border
    o.moveWithMouse = false

    return o
end

function EnergyBatteryUI:initialise()
    ISPanel.initialise(self)
end

function EnergyBatteryUI:createChildren()
    local panelX = 6
    local panelW = self.width - 12
    local top = 8
    local gap = 8
    local infoPadX = 10
    local infoPadY = 8

    local isWind = isWindBatteryObject(self.batteryObj)
    local titleKey = isWind and "wind_battery_title" or "solar_battery_title"

    self.headerBox = createStyledSection(self, true)
    self.headerBox:setX(panelX)
    self.headerBox:setY(top)
    self.headerBox:setWidth(panelW)
    self.headerBox:setHeight(34)
    attachHeaderDrag(self, self.headerBox)

    self.infoBox = createStyledSection(self, false)
    self.infoBox:setX(panelX)
    self.infoBox:setY(top + self.headerBox.height + gap)
    self.infoBox:setWidth(panelW)

    self.titleLabel = ISLabel:new(infoPadX, 8, 20, t(titleKey), COLORS.title.r, COLORS.title.g, COLORS.title.b, COLORS.title.a, UIFont.Medium, true)
    self.headerBox:addChild(self.titleLabel)

    local y = infoPadY
    self.controllerLabel = ISLabel:new(infoPadX, y, 20, t("controller", t("none")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.controllerLabel)
    y = y + 18

    self.roleLabel = ISLabel:new(infoPadX, y, 20, t("battery_role", t("none")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.roleLabel)
    y = y + 18

    self.storedEnergyLabel = ISLabel:new(infoPadX, y, 20, t("stored_energy", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.storedEnergyLabel)
    y = y + 18

    self.maxCapacityLabel = ISLabel:new(infoPadX, y, 20, t("max_capacity", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.maxCapacityLabel)
    y = y + 18

    self.autonomyLabel = ISLabel:new(infoPadX, y, 20, t("estimated_autonomy", "--"), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.autonomyLabel)
    y = y + 18

    self.statusLabel = ISLabel:new(infoPadX, y, 20, t("status", t("status_disconnected")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.statusLabel)
    y = y + 18

    self.stateLabel = ISLabel:new(infoPadX, y, 20, t("state", t("unknown")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.stateLabel)
    y = y + 20

    self.infoBox:setHeight(y + infoPadY)

    self.closeButton = ISButton:new(self.width - 90, self.height - 32, 80, 24, t("close"), self, EnergyBatteryUI.onClose)
    self.closeButton:initialise()
    self:addChild(self.closeButton)
end

function EnergyBatteryUI:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    if EnergyRouting and EnergyRouting.UI then
        if self.uiObjectKey and EnergyRouting.UI.batteryUiByKey
            and EnergyRouting.UI.batteryUiByKey[self.uiObjectKey] == self then
            EnergyRouting.UI.batteryUiByKey[self.uiObjectKey] = nil
        end
        if EnergyRouting.UI.batteryInstance == self then
            EnergyRouting.UI.batteryInstance = nil
        end
    end
end

function EnergyBatteryUI:update()
    local batteryObj = self.batteryObj
    if not (batteryObj and batteryObj.getModData) then
        batteryObj = findObjectOnSquare(self.batterySquare, hasBatteryMeta)
        self.batteryObj = batteryObj
    end

    if not (batteryObj and batteryObj.getModData) then
        if self.controllerLabel then
            self.controllerLabel:setName(t("controller", t("none")))
        end
        if self.roleLabel then
            self.roleLabel:setName(t("battery_role", t("none")))
        end
        if self.storedEnergyLabel then
            self.storedEnergyLabel:setName(t("stored_energy", 0))
        end
        if self.maxCapacityLabel then
            self.maxCapacityLabel:setName(t("max_capacity", 0))
        end
        if self.autonomyLabel then
            self.autonomyLabel:setName(t("estimated_autonomy", "--"))
        end
        if self.statusLabel then
            self.statusLabel:setName(t("status", t("status_disconnected")))
        end
        if self.stateLabel then
            self.stateLabel:setName(t("state", t("unknown")))
        end
        return
    end

    local md = getObjectModData(batteryObj)
    local windBattery = md and md.windBattery or nil
    local energy = md and md.energy or nil
    local useWind = isWindBatteryObject(batteryObj)
    local controllerId = useWind and (windBattery and windBattery.controllerId or nil) or (energy and energy.controllerId or nil)
    local role = useWind and (windBattery and windBattery.role or nil) or (energy and energy.role or nil)
    local stored = useWind and (windBattery and windBattery.charge or 0) or (energy and energy.storedEnergy or 0)
    local capacity = useWind and (windBattery and windBattery.capacity or 0) or (energy and energy.capacity or 0)

    if self.titleLabel then
        self.titleLabel:setName(t(useWind and "wind_battery_title" or "solar_battery_title"))
    end

    if self.controllerLabel then
        self.controllerLabel:setName(t("controller", tostring(controllerId or t("none"))))
    end
    if self.roleLabel then
        self.roleLabel:setName(t("battery_role", localizeRole(role)))
    end
    local controllerState = nil
    if controllerId and EnergyRouting and EnergyRouting.Client and EnergyRouting.Client.GetState then
        controllerState = EnergyRouting.Client.GetState(controllerId)
    end
    local currentConsumption = tonumber(controllerState and (controllerState.consumptionTotal or controllerState.consumption) or 0) or 0

    if self.storedEnergyLabel then
        self.storedEnergyLabel:setName(t("stored_energy", formatKWh(stored)))
    end
    if self.maxCapacityLabel then
        self.maxCapacityLabel:setName(t("max_capacity", formatKWh(capacity)))
    end
    if self.autonomyLabel then
        self.autonomyLabel:setName(t("estimated_autonomy", formatAutonomyHours(stored, currentConsumption)))
    end
    if self.statusLabel then
        local connected = useWind and (windBattery and windBattery.connected) or controllerId
        local statusKey = connected and "status_connected" or "status_disconnected"
        self.statusLabel:setName(t("status", t(statusKey)))
    end
    if self.stateLabel then
        local stateKey = "unknown"
        if useWind and capacity > 0 and stored <= 0 then
            stateKey = "state_empty"
        elseif useWind and windBattery and windBattery.state then
            local raw = string.lower(tostring(windBattery.state))
            if raw == "charging" then
                stateKey = "state_charging"
            elseif raw == "discharging" then
                stateKey = "state_discharging"
            elseif raw == "idle" then
                stateKey = "state_idle"
            end
        elseif capacity > 0 and stored <= 0 then
            stateKey = "state_empty"
        elseif controllerState and type(controllerState.production) == "number" then
            if controllerState.production > 0 and stored < capacity then
                stateKey = "state_charging"
            elseif controllerState.production <= 0 and stored > 0 then
                stateKey = "state_idle"
            else
                stateKey = "state_idle"
            end
        elseif self.lastStoredEnergy ~= nil then
            if stored > self.lastStoredEnergy then
                stateKey = "state_charging"
            elseif stored < self.lastStoredEnergy then
                stateKey = "state_discharging"
            else
                stateKey = "state_idle"
            end
        end
        self.stateLabel:setName(t("state", t(stateKey)))
        if stateKey == "state_charging" then
            local gt = getGameTime and getGameTime() or nil
            local hours = gt and gt.getWorldAgeHours and gt:getWorldAgeHours() or 0
            local pulse = 0.6 + 0.4 * math.sin(hours * math.pi * 4)
            self.stateLabel.r = 0.4
            self.stateLabel.g = 1.0 * pulse
            self.stateLabel.b = 0.4
        elseif stateKey == "state_discharging" then
            self.stateLabel.r = 1.0
            self.stateLabel.g = 0.8
            self.stateLabel.b = 0.2
        elseif stateKey == "state_empty" then
            self.stateLabel.r = 1.0
            self.stateLabel.g = 0.3
            self.stateLabel.b = 0.3
        else
            self.stateLabel.r = COLORS.disabled.r
            self.stateLabel.g = COLORS.disabled.g
            self.stateLabel.b = COLORS.disabled.b
        end
    end
    self.lastStoredEnergy = stored
end

EnergyPanelUI = ISPanel:derive("EnergyPanelUI")

function EnergyPanelUI:new(panelObj)
    local width = 320
    local height = 322
    local x = (getCore():getScreenWidth() / 2) - (width / 2)
    local y = (getCore():getScreenHeight() / 2) - (height / 2)

    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.panelObj = panelObj
    o.panelSquare = getSquareFromObj(panelObj)
    o.uiObjectKey = getObjectUiKey(panelObj, "panel")
    o.backgroundColor = COLORS.bg
    o.borderColor = COLORS.border
    o.moveWithMouse = false
    o.windSoundHandle = nil
    o.windSoundName = nil
    o.windSoundEmitter = nil
    o.windSoundAudio = nil
    o.windSoundLooped = false
    o.windSoundNextReplayMs = 0
    o.windSoundVolume = 0
    o.hydroOpenSuppressAmbientUntilMs = 0

    return o
end

function EnergyPanelUI:initialise()
    ISPanel.initialise(self)
end

function EnergyPanelUI:getWindSoundEmitter()
    local square = getSquareFromObj(self.panelObj) or self.panelSquare
    if self.windSoundEmitter then
        if square and self.windSoundEmitter.setPos then
            self.windSoundEmitter:setPos(square:getX(), square:getY(), square:getZ())
        end
        return self.windSoundEmitter
    end
    if not square then
        return nil
    end
    local world = getWorld and getWorld() or nil
    if not (world and world.getFreeEmitter) then
        return nil
    end
    local emitter = world:getFreeEmitter()
    if emitter and emitter.setPos then
        emitter:setPos(square:getX(), square:getY(), square:getZ())
    end
    self.windSoundEmitter = emitter
    return emitter
end

function EnergyPanelUI:applyWindSoundVolume(volume)
    local vol = scaleAmbientVolume(volume)
    if self.windSoundAudio and self.windSoundAudio.setVolume then
        pcall(self.windSoundAudio.setVolume, self.windSoundAudio, vol)
    end
    if self.windSoundEmitter and self.windSoundEmitter.setVolume and isValidSoundHandle(self.windSoundHandle) then
        pcall(self.windSoundEmitter.setVolume, self.windSoundEmitter, self.windSoundHandle, vol)
    end
    self.windSoundVolume = vol
end

function EnergyPanelUI:stopWindAmbient()
    if isValidSoundHandle(self.windSoundHandle) then
        if self.windSoundEmitter and self.windSoundEmitter.stopSound then
            pcall(self.windSoundEmitter.stopSound, self.windSoundEmitter, self.windSoundHandle)
        end
    end
    self.windSoundHandle = nil
    self.windSoundName = nil
    self.windSoundEmitter = nil
    self.windSoundAudio = nil
    self.windSoundLooped = false
    self.windSoundNextReplayMs = 0
    self.windSoundVolume = 0
end

function EnergyPanelUI:startWindAmbient(soundName, volume, oneShotReplayMs, loopOnly)
    if not soundName then
        self:stopWindAmbient()
        return
    end
    if isFastForwardAudioSuppressed() then
        return
    end

    local now = getWorldTimestampMs()
    local emitter = self:getWindSoundEmitter()
    local handle = nil
    local looped = false

    if emitter and emitter.playSoundLooped then
        local ok, result = pcall(emitter.playSoundLooped, emitter, soundName)
        if ok then
            handle = result
        end
        looped = isValidSoundHandle(handle)
    end
    if (not loopOnly) and (not isValidSoundHandle(handle)) and emitter and emitter.playSound then
        local ok, result = pcall(emitter.playSound, emitter, soundName)
        if ok then
            handle = result
        end
        looped = false
    end

    self.windSoundName = soundName
    self.windSoundHandle = handle
    self.windSoundEmitter = emitter
    self.windSoundAudio = nil
    self.windSoundLooped = looped
    self.windSoundNextReplayMs = now + (tonumber(oneShotReplayMs) or WIND_TURBINE_ONE_SHOT_REPLAY_MS)
    self:applyWindSoundVolume(volume)
end

function EnergyPanelUI:updateWindAmbient(speedKey, overrideSoundName, overrideVolume, oneShotReplayMs, replayNonLooped, loopOnly)
    local key = speedKey or "low"
    local soundName = overrideSoundName or WIND_TURBINE_SOUND_BY_SPEED[key] or WIND_TURBINE_SOUND_BY_SPEED.low
    local volume = overrideVolume or WIND_TURBINE_VOLUME_BY_SPEED[key] or WIND_TURBINE_VOLUME_BY_SPEED.low
    local replayMs = tonumber(oneShotReplayMs) or WIND_TURBINE_ONE_SHOT_REPLAY_MS
    local allowReplay = replayNonLooped ~= false
    local now = getWorldTimestampMs()

    if isFastForwardAudioSuppressed() then
        if self.windSoundHandle or self.windSoundAudio then
            self:applyWindSoundVolume(0)
        end
        return
    end

    local needsRestart = false
    if self.windSoundName ~= soundName then
        needsRestart = true
    end
    if not isValidSoundHandle(self.windSoundHandle) and not self.windSoundAudio then
        if allowReplay and now >= (self.windSoundNextReplayMs or 0) then
            needsRestart = true
        end
    end

    if not needsRestart and self.windSoundLooped and self.windSoundEmitter and self.windSoundEmitter.isPlaying
        and isValidSoundHandle(self.windSoundHandle) then
        local ok, playing = pcall(self.windSoundEmitter.isPlaying, self.windSoundEmitter, self.windSoundHandle)
        if ok and not playing then
            needsRestart = true
        end
    end
    if not needsRestart and allowReplay and (not self.windSoundLooped) and now >= (self.windSoundNextReplayMs or 0) then
        needsRestart = true
    end

    if needsRestart then
        self:stopWindAmbient()
        self:startWindAmbient(soundName, volume, replayMs, loopOnly == true)
    else
        self:applyWindSoundVolume(volume)
    end
end

function EnergyPanelUI:createChildren()
    local panelX = 6
    local panelW = self.width - 12
    local top = 8
    local gap = 8
    local infoPadX = 10
    local infoPadY = 8

    local isWind = isWindPanelObject(self.panelObj)
    local isHydro = isHydroPanelObject(self.panelObj)
    self.headerBox = createStyledSection(self, true)
    self.headerBox:setX(panelX)
    self.headerBox:setY(top)
    self.headerBox:setWidth(panelW)
    self.headerBox:setHeight(34)
    attachHeaderDrag(self, self.headerBox)

    self.infoBox = createStyledSection(self, false)
    self.infoBox:setX(panelX)
    self.infoBox:setY(top + self.headerBox.height + gap)
    self.infoBox:setWidth(panelW)

    local panelTitleKey = "panel_title"
    if isHydro then
        panelTitleKey = "hydro_panel_title"
    elseif isWind then
        panelTitleKey = "aerogenerator_panel_title"
    end
    self.titleLabel = ISLabel:new(infoPadX, 8, 20, t(panelTitleKey), COLORS.title.r, COLORS.title.g, COLORS.title.b, COLORS.title.a, UIFont.Medium, true)
    self.headerBox:addChild(self.titleLabel)

    local y = infoPadY
    self.controllerLabel = ISLabel:new(infoPadX, y, 20, t("controller", t("none")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.controllerLabel)
    y = y + 18

    self.statusLabel = ISLabel:new(infoPadX, y, 20, t("status", t("status_disconnected")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.statusLabel)
    y = y + 18

    self.weatherLabel = ISLabel:new(infoPadX, y, 20, t("weather", t("unknown")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.weatherLabel)
    y = y + 18

    if isWind or isHydro then
        self.turbineStateLabel = ISLabel:new(infoPadX, y, 20, t("turbine_status", t("turbine_state_idle")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
        self.infoBox:addChild(self.turbineStateLabel)
        y = y + 18
    end
    if isWind then
        self.windSpeedLabel = ISLabel:new(infoPadX, y, 20, t("wind_speed_line", t("wind_speed_low")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
        self.infoBox:addChild(self.windSpeedLabel)
        y = y + 18
    end

    self.efficiencyLabel = ISLabel:new(infoPadX, y, 20, t("efficiency", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.efficiencyLabel)
    y = y + 18

    if SHOW_PANEL_TYPE_DEBUG then
        self.typeLabel = ISLabel:new(infoPadX, y, 20, t("type", t("unknown")), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
        self.infoBox:addChild(self.typeLabel)
        y = y + 18
    end

    self.bonusLabel = ISLabel:new(infoPadX, y, 20, t("bonus", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.bonusLabel)
    y = y + 18

    self.productionLabel = ISLabel:new(infoPadX, y, 20, t("production", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.productionLabel)
    y = y + 18

    self.maxLabel = ISLabel:new(infoPadX, y, 20, t("max", 0), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.maxLabel)
    y = y + 18

    self.integrityLabel = ISLabel:new(infoPadX, y, 20, t("integrity", "100", ""), COLORS.text.r, COLORS.text.g, COLORS.text.b, COLORS.text.a, UIFont.Small, true)
    self.infoBox:addChild(self.integrityLabel)
    y = y + 20

    self.infoBox:setHeight(y + infoPadY)

    self.closeButton = ISButton:new(self.width - 90, self.height - 32, 80, 24, t("close"), self, EnergyPanelUI.onClose)
    self.closeButton:initialise()
    self:addChild(self.closeButton)
end

function EnergyPanelUI:onClose()
    self:stopWindAmbient()
    self:setVisible(false)
    self:removeFromUIManager()
    if EnergyRouting and EnergyRouting.UI then
        if self.uiObjectKey and EnergyRouting.UI.panelUiByKey
            and EnergyRouting.UI.panelUiByKey[self.uiObjectKey] == self then
            EnergyRouting.UI.panelUiByKey[self.uiObjectKey] = nil
        end
        if EnergyRouting.UI.panelInstance == self then
            EnergyRouting.UI.panelInstance = nil
        end
    end
end

function EnergyPanelUI:update()
    local panelObj = self.panelObj
    if not (panelObj and panelObj.getModData) then
        panelObj = findObjectOnSquare(self.panelSquare, hasPanelMeta)
        self.panelObj = panelObj
    end

    if not (panelObj and panelObj.getModData) then
        self:stopWindAmbient()
        if self.controllerLabel then
            self.controllerLabel:setName(t("controller", t("none")))
        end
        if self.statusLabel then
            self.statusLabel:setName(t("status", t("status_disconnected")))
        end
        if self.weatherLabel then
            self.weatherLabel:setName(t("weather", t("unknown")))
        end
        if self.turbineStateLabel then
            self.turbineStateLabel:setName(t("turbine_status", t("turbine_state_idle")))
        end
        if self.windSpeedLabel then
            self.windSpeedLabel:setName(t("wind_speed_line", t("wind_speed_low")))
        end
        if self.efficiencyLabel then
            self.efficiencyLabel:setName(t("efficiency", 0))
        end
        if self.typeLabel then
            self.typeLabel:setName(t("type", t("unknown")))
        end
        if self.bonusLabel then
            self.bonusLabel:setName(t("bonus", 0))
        end
        if self.productionLabel then
            self.productionLabel:setName(t("production", 0))
        end
        if self.maxLabel then
            self.maxLabel:setName(t("max", 0))
        end
        if self.integrityLabel then
            self.integrityLabel:setName(t("integrity", "100", ""))
            self.integrityLabel.r = COLORS.text.r
            self.integrityLabel.g = COLORS.text.g
            self.integrityLabel.b = COLORS.text.b
        end
        return
    end

    local md = getObjectModData(panelObj)
    local panel = md and md.panel or nil
    local solar = md and md.solar or nil
    local wind = md and md.wind or nil
    local hydro = md and md.hydro or nil
    local isWind = isWindPanelObject(panelObj)
    local isHydro = (not isWind) and isHydroPanelObject(panelObj)
    local controllerId = nil
    if isHydro then
        controllerId = (hydro and hydro.controllerId)
            or (md and md.energy and md.energy.controllerId)
            or nil
    elseif isWind then
        controllerId = (wind and wind.controllerId) or nil
    else
        controllerId = (panel and panel.controllerId) or nil
    end
    local panelType = panel and panel.type or t("unknown")
    local bonus = panel and panel.bonus or 0
    local production = 0
    local efficiencyPercent = 0
    local maxProduction = 0
    local secondaryText = nil
    local typeText = nil
    local integrityPercent = 100
    local producerState = "normal"
    local turbineStatusText = t("turbine_state_idle")
    local windSpeedText = t("wind_speed_low")
    local windSpeedKey = "low"
    local turbineActive = false

    local weatherSnapshot = nil
    if isHydro then
        local conditionPercent = tonumber(hydro and hydro.condition) or 100
        if conditionPercent < 0 then
            conditionPercent = 0
        elseif conditionPercent > 100 then
            conditionPercent = 100
        end
        local baseOutput = tonumber(hydro and hydro.baseOutput) or ((EnergyRouting and EnergyRouting.HYDRO_BASE_W) or 450)
        local validWater = hydro and hydro.validWater ~= false
        local active = hydro and hydro.isActive ~= false
        local currentProduction = tonumber(hydro and hydro.currentProduction) or 0
        if (not validWater) or (not active) or conditionPercent <= 0 then
            currentProduction = 0
        end
        production = math.max(0, currentProduction)
        maxProduction = math.max(0, baseOutput)
        integrityPercent = conditionPercent
        producerState = (conditionPercent <= 0) and "offline" or "normal"
        if conditionPercent <= 0 then
            turbineStatusText = t("turbine_state_damaged")
        elseif not validWater then
            turbineStatusText = t("turbine_state_no_water")
        elseif production > 0 then
            turbineStatusText = t("turbine_state_active")
        else
            turbineStatusText = t("turbine_state_idle")
        end
        turbineActive = (controllerId and production and production > 0) and true or false
        efficiencyPercent = (maxProduction > 0) and math.floor((production / maxProduction) * 100 + 0.5) or 0
        secondaryText = t("status", turbineStatusText)
        typeText = t("type", tostring(hydro and hydro.spriteType or panelType))
        weatherSnapshot = { label = t("unknown") }
    elseif isWind then
        weatherSnapshot = EnergyRouting.Weather and EnergyRouting.Weather.GetWindSnapshot
            and EnergyRouting.Weather.GetWindSnapshot() or { label = t("unknown") }
        local windEfficiency = (wind and wind.efficiency) or 1.0
        local windCondition = (wind and wind.condition)
        if windCondition == nil or type(windCondition) ~= "number" then
            windCondition = 1.0
        end
        if windCondition < 0 then
            windCondition = 0
        elseif windCondition > 1 then
            windCondition = 1
        end
        local productionMeta = md and md.production or nil
        local windDegradation = tonumber(productionMeta and productionMeta.degradation) or windCondition
        local windWearFactor = 1.0
        windWearFactor, producerState, windDegradation = getProducerWearInfo(windDegradation)
        integrityPercent = (windDegradation or 1.0) * 100
        maxProduction = wind and wind.baseProduction or ((EnergyRouting and EnergyRouting.WIND_BASE_W) or 400)
        production = wind and wind.currentProduction or 0
        if (not production or production <= 0) and maxProduction > 0 then
            local windMult = (weatherSnapshot and weatherSnapshot.multiplier) or 0.6
            production = maxProduction * windEfficiency * windWearFactor * windMult
        end
        local windMult = tonumber((weatherSnapshot and weatherSnapshot.multiplier) or 0.6) or 0.6
        if windMult >= 1.1 then
            windSpeedText = t("wind_speed_high")
            windSpeedKey = "high"
        elseif windMult >= 0.7 then
            windSpeedText = t("wind_speed_medium")
            windSpeedKey = "medium"
        else
            windSpeedText = t("wind_speed_low")
            windSpeedKey = "low"
        end
        turbineActive = (controllerId and production and production > 0) and true or false
        turbineStatusText = turbineActive
            and t("turbine_state_active")
            or t("turbine_state_idle")
        efficiencyPercent = math.floor((windEfficiency or 1.0) * 100 + 0.5)
        local conditionPercent = math.floor((windCondition or 1.0) * 100 + 0.5)
        local bonusPercent = 0
        if controllerId and controllerId ~= "" then
            bonusPercent = 25
        end
        secondaryText = t("bonus", tostring(bonusPercent) .. "%")
        typeText = t("condition", conditionPercent)
    else
        if panel then
            production = panel.production or panel.productionRate or 0
        end
        local fullType = getItemFullType(getWorldItem(panelObj))
        local horizontalBase = (EnergyRouting and EnergyRouting.SOLAR_HORIZONTAL_BASE_W) or 220
        local verticalBase = (EnergyRouting and EnergyRouting.SOLAR_VERTICAL_BASE_W)
            or (EnergyRouting and EnergyRouting.SOLAR_BASE_W)
            or 330
        local baseRate = verticalBase
        if fullType == "EnergyRouting.SolarPanelHorizontal"
            or fullType == "SolarPanelHorizontal"
            or (type(fullType) == "string" and string.find(fullType, "SolarPanelHorizontal", 1, true)) then
            baseRate = horizontalBase
        end

        local baseEfficiency = tonumber(solar and solar.baseEfficiency) or 1.0
        local degradation = tonumber(solar and solar.degradation) or 1.0
        if baseEfficiency < 0 then
            baseEfficiency = 0
        elseif baseEfficiency > 1 then
            baseEfficiency = 1
        end
        if degradation < 0 then
            degradation = 0
        elseif degradation > 1 then
            degradation = 1
        end
        local productionMeta = md and md.production or nil
        local panelDegradation = tonumber(productionMeta and productionMeta.degradation) or degradation
        local solarWearFactor = 1.0
        solarWearFactor, producerState, panelDegradation = getProducerWearInfo(panelDegradation)
        integrityPercent = (panelDegradation or 1.0) * 100
        degradation = panelDegradation

        local qualityBonus = tonumber(solar and solar.qualityBonus)
        if qualityBonus == nil then
            qualityBonus = tonumber(bonus) or 0
        end
        if qualityBonus < 0 then
            qualityBonus = 0
        end

        local climateEfficiency = getSolarEfficiency()
        local panelEfficiency = baseEfficiency * climateEfficiency * solarWearFactor
        if panelEfficiency < 0 then
            panelEfficiency = 0
        elseif panelEfficiency > 1 then
            panelEfficiency = 1
        end

        local mdMaxProduction = tonumber(panel and panel.maxProduction)
            or tonumber(md and md.energyPanel and md.energyPanel.maxProduction)
            or nil
        maxProduction = mdMaxProduction or (baseRate * (1 + qualityBonus))
        if (not production or production <= 0) and maxProduction > 0 then
            production = maxProduction * panelEfficiency
        end
        if production > maxProduction then
            maxProduction = production
        end
        efficiencyPercent = math.floor(panelEfficiency * 100 + 0.5)
        local bonusPercent = math.floor((qualityBonus or 0) * 100 + 0.5)
        secondaryText = t("bonus", tostring(bonusPercent) .. "%")
        typeText = t("type", tostring(panelType))
        weatherSnapshot = EnergyRouting.Weather and EnergyRouting.Weather.GetWeatherSnapshot
            and EnergyRouting.Weather.GetWeatherSnapshot() or { label = t("unknown") }
    end

    if self.titleLabel then
        if isHydro then
            self.titleLabel:setName(t("hydro_panel_title"))
        else
            self.titleLabel:setName(isWind and t("aerogenerator_panel_title") or t("panel_title"))
        end
    end

    if self.controllerLabel then
        self.controllerLabel:setName(t("controller", tostring(controllerId or t("none"))))
    end
    if self.statusLabel then
        if not controllerId or controllerId == "" then
            self.statusLabel:setName(t("status", t("status_disconnected")))
            self.statusLabel.r = COLORS.text.r
            self.statusLabel.g = COLORS.text.g
            self.statusLabel.b = COLORS.text.b
        elseif producerState == "offline" then
            self.statusLabel:setName(t("producer_state_offline"))
            self.statusLabel.r = 1.0
            self.statusLabel.g = 0.35
            self.statusLabel.b = 0.35
        elseif producerState == "critical" then
            self.statusLabel:setName(t("producer_state_critical"))
            self.statusLabel.r = 1.0
            self.statusLabel.g = 0.65
            self.statusLabel.b = 0.20
        else
            self.statusLabel:setName(t("status", t("status_connected")))
            self.statusLabel.r = COLORS.text.r
            self.statusLabel.g = COLORS.text.g
            self.statusLabel.b = COLORS.text.b
        end
    end
    if self.weatherLabel then
        self.weatherLabel:setName(t("weather", localizeWeather(weatherSnapshot.label)))
    end
    if self.turbineStateLabel then
        self.turbineStateLabel:setName(t("turbine_status", turbineStatusText))
        if self.turbineStateLabel.setVisible then
            self.turbineStateLabel:setVisible(isWind or isHydro)
        end
    end
    if self.windSpeedLabel then
        self.windSpeedLabel:setName(t("wind_speed_line", windSpeedText))
        if self.windSpeedLabel.setVisible then
            self.windSpeedLabel:setVisible(isWind)
        end
    end
    if self.efficiencyLabel then
        self.efficiencyLabel:setName(t("efficiency", efficiencyPercent))
    end
    if self.typeLabel then
        self.typeLabel:setName(typeText or t("type", t("unknown")))
    end
    if self.bonusLabel then
        self.bonusLabel:setName(secondaryText or t("bonus", 0))
    end
    if self.productionLabel then
        self.productionLabel:setName(t("production", tostring(math.floor(production))))
    end
    if self.maxLabel then
        self.maxLabel:setName(t("max", tostring(math.floor(maxProduction))))
    end
    if self.integrityLabel then
        local criticalThreshold = PRODUCER_CRITICAL_THRESHOLD * 100
        local suffix = ""
        if integrityPercent < criticalThreshold then
            suffix = t("integrity_worn_suffix")
        end
        self.integrityLabel:setName(t("integrity", formatNumber(integrityPercent), suffix))
        if integrityPercent < 30 then
            self.integrityLabel.r = 1.0
            self.integrityLabel.g = 0.35
            self.integrityLabel.b = 0.35
        elseif integrityPercent <= 60 then
            self.integrityLabel.r = 1.0
            self.integrityLabel.g = 0.85
            self.integrityLabel.b = 0.35
        else
            self.integrityLabel.r = 0.4
            self.integrityLabel.g = 1.0
            self.integrityLabel.b = 0.4
        end
    end

    if isWind and turbineActive then
        self:updateWindAmbient(windSpeedKey)
    elseif isHydro and turbineActive then
        local nowMs = getWorldTimestampMs()
        if nowMs < (tonumber(self.hydroOpenSuppressAmbientUntilMs) or 0) then
            self:stopWindAmbient()
        else
            self:updateWindAmbient(
                nil,
                HYDRO_TURBINE_SOUND,
                HYDRO_TURBINE_VOLUME,
                HYDRO_TURBINE_ONE_SHOT_REPLAY_MS,
                false,
                true
            )
        end
    else
        self:stopWindAmbient()
    end
end

EnergyRouting.UI = EnergyRouting.UI or {}
EnergyRouting.UI.Panel = EnergyRoutingUI
EnergyRouting.UI.BatteryPanel = EnergyBatteryUI
EnergyRouting.UI.SolarPanel = EnergyPanelUI

function EnergyRouting.UI.OpenController(edcId, readOnly)
    if not edcId then
        return
    end
    if EnergyRouting.Client and EnergyRouting.Client.OpenPanel then
        EnergyRouting.Client.OpenPanel(edcId, readOnly and true or false)
    end
end

function EnergyRouting.UI.OpenBattery(batteryObj)
    if not batteryObj then
        return
    end
    EnergyRouting.UI.batteryUiByKey = EnergyRouting.UI.batteryUiByKey or {}
    local objectKey = getObjectUiKey(batteryObj, "battery")
    if objectKey then
        local existing = EnergyRouting.UI.batteryUiByKey[objectKey]
        if existing and focusExistingUi(existing) then
            return
        end
        EnergyRouting.UI.batteryUiByKey[objectKey] = nil
    end
    local ui = EnergyBatteryUI:new(batteryObj)
    ui.uiObjectKey = objectKey or ui.uiObjectKey
    ui:initialise()
    ui:addToUIManager()
    ui:setVisible(true)
    if ui.uiObjectKey then
        EnergyRouting.UI.batteryUiByKey[ui.uiObjectKey] = ui
    end
    EnergyRouting.UI.batteryInstance = ui
    local md = getObjectModData(batteryObj)
    local isWind = isWindBatteryObject(batteryObj)
    local controllerId = (isWind and md and md.windBattery and md.windBattery.controllerId)
        or ((not isWind) and md and md.energy and md.energy.controllerId)
        or (md and md.windBattery and md.windBattery.controllerId)
        or (md and md.energy and md.energy.controllerId)
        or nil
    if controllerId and EnergyRouting.Client and EnergyRouting.Client.RequestState then
        EnergyRouting.Client.RequestState(controllerId)
    end
end

function EnergyRouting.UI.OpenPanel(panelObj)
    if not panelObj then
        return
    end
    EnergyRouting.UI.panelUiByKey = EnergyRouting.UI.panelUiByKey or {}
    local objectKey = getObjectUiKey(panelObj, "panel")
    if objectKey then
        local existing = EnergyRouting.UI.panelUiByKey[objectKey]
        if existing and focusExistingUi(existing) then
            return
        end
        EnergyRouting.UI.panelUiByKey[objectKey] = nil
    end
    local ui = EnergyPanelUI:new(panelObj)
    ui.uiObjectKey = objectKey or ui.uiObjectKey
    ui:initialise()
    ui:addToUIManager()
    ui:setVisible(true)
    if ui.uiObjectKey then
        EnergyRouting.UI.panelUiByKey[ui.uiObjectKey] = ui
    end
    EnergyRouting.UI.panelInstance = ui
    local md = getObjectModData(panelObj)
    local isWind = isWindPanelObject(panelObj)
    local isHydro = (not isWind) and isHydroPanelObject(panelObj)
    local hydro = md and md.hydro or nil
    local controllerId = (isHydro and md and md.hydro and md.hydro.controllerId)
        or (isWind and md and md.wind and md.wind.controllerId)
        or ((not isWind and not isHydro) and md and md.panel and md.panel.controllerId)
        or (md and md.wind and md.wind.controllerId)
        or (md and md.hydro and md.hydro.controllerId)
        or (md and md.panel and md.panel.controllerId)
        or nil
    if isHydro then
        playHydroUiOpenSound(panelObj)
        ui.hydroOpenSuppressAmbientUntilMs = getWorldTimestampMs() + HYDRO_UI_AMBIENT_DELAY_MS
    end
    if controllerId and EnergyRouting.Client and EnergyRouting.Client.RequestState then
        EnergyRouting.Client.RequestState(controllerId)
    end
end

function EnergyRouting.UI.Open(worldObj, playerObj)
    if not worldObj then
        return
    end
    local md = getObjectModData(worldObj)
    if md and type(md.energyController) == "table" and md.energyController.networkId then
        EnergyRouting.UI.OpenController(md.energyController.networkId, false)
        return
    end
    if isWindBatteryObject(worldObj) then
        EnergyRouting.UI.OpenBattery(worldObj)
        return
    end
    if hasBatteryMeta(worldObj) then
        EnergyRouting.UI.OpenBattery(worldObj)
        return
    end
    if isWindPanelObject(worldObj) then
        EnergyRouting.UI.OpenPanel(worldObj)
        return
    end
    if isHydroPanelObject(worldObj) then
        EnergyRouting.UI.OpenPanel(worldObj)
        return
    end
    if hasPanelMeta(worldObj) then
        EnergyRouting.UI.OpenPanel(worldObj)
        return
    end
end

local function closeUiInstance(ui)
    if not ui then
        return
    end
    if ui.onClose then
        ui:onClose()
    else
        if ui.setVisible then
            ui:setVisible(false)
        end
        if ui.removeFromUIManager then
            ui:removeFromUIManager()
        end
    end
end

function EnergyRouting.UI.CloseController(edcId)
    if not edcId then
        return
    end
    if EnergyRouting and EnergyRouting.Client and EnergyRouting.Client.uiById then
        local ui = EnergyRouting.Client.uiById[edcId]
        if ui then
            closeUiInstance(ui)
            return
        end
    end
    local ui = EnergyRouting and EnergyRouting.UI and EnergyRouting.UI.instance or nil
    if ui and ui.edcId == edcId then
        closeUiInstance(ui)
    end
end

local function closeObjectUiByKey(kind, objectKey)
    if not objectKey or not EnergyRouting or not EnergyRouting.UI then
        return
    end
    if kind == "panel" then
        local byKey = EnergyRouting.UI.panelUiByKey
        local ui = byKey and byKey[objectKey] or nil
        if ui then
            closeUiInstance(ui)
        end
        return
    end
    if kind == "battery" then
        local byKey = EnergyRouting.UI.batteryUiByKey
        local ui = byKey and byKey[objectKey] or nil
        if ui then
            closeUiInstance(ui)
        end
    end
end

local function closeUiForRemovedWorldObject(obj)
    if not obj then
        return
    end

    local md = getObjectModData(obj)
    local controllerId = md and md.energyController and md.energyController.networkId or nil
    if not controllerId then
        local sq = getSquareFromObj(obj)
        local sqMd = sq and sq.getModData and sq:getModData() or nil
        controllerId = sqMd and sqMd.EnergyRoutingEDCId or nil
    end
    if controllerId then
        EnergyRouting.UI.CloseController(controllerId)
    end

    if isWindPanelObject(obj) or isHydroPanelObject(obj) or hasPanelMeta(obj) then
        closeObjectUiByKey("panel", getObjectUiKey(obj, "panel"))
    end
    if isWindBatteryObject(obj) or hasBatteryMeta(obj) then
        closeObjectUiByKey("battery", getObjectUiKey(obj, "battery"))
    end
end

if Events and Events.OnObjectAboutToBeRemoved then
    if Events.OnObjectAboutToBeRemoved.Remove then
        Events.OnObjectAboutToBeRemoved.Remove(closeUiForRemovedWorldObject)
    end
    Events.OnObjectAboutToBeRemoved.Add(closeUiForRemovedWorldObject)
elseif Events and Events.OnObjectRemoved then
    if Events.OnObjectRemoved.Remove then
        Events.OnObjectRemoved.Remove(closeUiForRemovedWorldObject)
    end
    Events.OnObjectRemoved.Add(closeUiForRemovedWorldObject)
end

