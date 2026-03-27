require "EnergyRouting/Init"

EnergyRouting.Weather = EnergyRouting.Weather or {}

local function safeCall(obj, method, ...)
    if obj and obj[method] then
        local ok, result = pcall(obj[method], obj, ...)
        if ok then
            return result
        end
    end
    return nil
end

local function isNightTime()
    local gt = getGameTime()
    if not gt or not gt.getHour then
        return false
    end
    local hour = gt:getHour()
    return hour < 6 or hour >= 20
end

function EnergyRouting.Weather.GetWeatherSnapshot()
    local label = "Unknown"
    local multiplier = 1.0

    if isNightTime() then
        label = "Night"
        multiplier = 0.0
    else
        label = "Clear"
        multiplier = 1.0
    end

    local usw = rawget(_G, "UnseasonalWeather") or rawget(_G, "USW")
    if usw then
        local weatherType = safeCall(usw, "GetCurrentWeatherType") or safeCall(usw, "getCurrentWeather")
        if weatherType then
            local lowered = string.lower(tostring(weatherType))
            if lowered:find("storm") then
                label = "Storm"
                multiplier = 0.25
            elseif lowered:find("snow") then
                label = "Snow"
                multiplier = 0.15
            elseif lowered:find("cloud") then
                label = "Cloudy"
                multiplier = 0.6
            elseif lowered:find("clear") then
                label = "Clear"
                multiplier = 1.0
            end
        end
    else
        local cm = rawget(_G, "getClimateManager") and getClimateManager() or nil
        local cloud = safeCall(cm, "getCloudIntensity")
        local precipitation = safeCall(cm, "getPrecipitationIntensity")
        if precipitation and precipitation > 0.7 then
            label = "Storm"
            multiplier = 0.25
        elseif precipitation and precipitation > 0.2 then
            label = "Cloudy"
            multiplier = 0.6
        elseif cloud and cloud > 0.5 then
            label = "Cloudy"
            multiplier = 0.6
        end
    end

    multiplier = multiplier * (EnergyRouting.GetConfigValue("SolarWeatherImpact") or 1.0)
    if multiplier < 0 then
        multiplier = 0
    end

    return { label = label, multiplier = multiplier }
end

function EnergyRouting.Weather.GetWindSnapshot()
    local cm = rawget(_G, "getClimateManager") and getClimateManager() or nil
    local weatherLabel = "Clear"

    if isNightTime() then
        weatherLabel = "Night"
    end

    if cm then
        local rain = safeCall(cm, "getRainIntensity") or safeCall(cm, "getPrecipitationIntensity") or 0
        local fog = safeCall(cm, "getFogIntensity") or 0
        local cloud = safeCall(cm, "getCloudIntensity") or 0
        local thunder = safeCall(cm, "getThunderStormIntensity") or 0

        if thunder > 0.15 or rain > 0.8 then
            weatherLabel = "Storm"
        elseif rain > 0.2 then
            weatherLabel = "Rain"
        elseif fog > 0.25 then
            weatherLabel = "Fog"
        elseif cloud > 0.5 then
            weatherLabel = "Cloudy"
        elseif not isNightTime() then
            weatherLabel = "Clear"
        end
    end

    local map = {
        Clear = { mult = 0.5, speed = "low" },
        Cloudy = { mult = 1.0, speed = "medium" },
        Rain = { mult = 1.5, speed = "high" },
        Storm = { mult = 2.0, speed = "high" },
        Fog = { mult = 0.5, speed = "low" },
        Night = { mult = 0.5, speed = "low" },
    }

    local profile = map[weatherLabel] or map.Clear
    local mult = profile.mult or 0.5
    mult = mult * (EnergyRouting.GetConfigValue("WindWeatherImpact") or 1.0)
    if mult < 0 then
        mult = 0
    end

    return { label = weatherLabel, multiplier = mult, speed = profile.speed or "low" }
end
