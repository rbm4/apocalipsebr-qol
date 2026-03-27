pcall(require, "PZAPI/ModOptions")

EnergyRouting = EnergyRouting or {}
EnergyRouting.ClientOptions = EnergyRouting.ClientOptions or {}
local ClientOptions = EnergyRouting.ClientOptions

ClientOptions.MOD_OPTIONS_ID = "EnergyRouting_Client"
ClientOptions.DEFAULT_AMBIENT_VOLUME = 100
ClientOptions._ambientVolume = ClientOptions._ambientVolume or ClientOptions.DEFAULT_AMBIENT_VOLUME
ClientOptions._registered = ClientOptions._registered or false

local function clampVolumePercent(value)
    local num = tonumber(value) or ClientOptions.DEFAULT_AMBIENT_VOLUME
    if num < 0 then
        num = 0
    end
    if num > 100 then
        num = 100
    end
    return math.floor(num + 0.5)
end

local function splitByPipe(line)
    if luautils and luautils.split then
        return luautils.split(line, "|")
    end
    local out = {}
    for part in tostring(line):gmatch("([^|]+)") do
        table.insert(out, part)
    end
    return out
end

local function loadSavedAmbientVolume(defaultValue)
    if not getFileReader then
        return defaultValue
    end
    local file = getFileReader("ModOptions.ini", true)
    if not file then
        return defaultValue
    end
    local value = defaultValue
    while true do
        local line = file:readLine()
        if not line then
            break
        end
        local t = splitByPipe(line)
        if t[1] == "slider" and t[2] == ClientOptions.MOD_OPTIONS_ID and t[3] == "AmbientSoundVolume" then
            local parsed = tonumber(t[4])
            if parsed then
                value = parsed
            end
            break
        end
    end
    file:close()
    return clampVolumePercent(value)
end

function ClientOptions.getAmbientVolumePercent()
    return clampVolumePercent(ClientOptions._ambientVolume)
end

function ClientOptions.getAmbientVolumeMultiplier()
    return ClientOptions.getAmbientVolumePercent() / 100
end

function EnergyRouting.GetClientAmbientVolumeMultiplier()
    return ClientOptions.getAmbientVolumeMultiplier()
end

local function registerModOptions()
    if ClientOptions._registered then
        return
    end
    if not (PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.create) then
        return
    end

    local initial = loadSavedAmbientVolume(ClientOptions.DEFAULT_AMBIENT_VOLUME)
    ClientOptions._ambientVolume = initial

    local options = PZAPI.ModOptions:getOptions(ClientOptions.MOD_OPTIONS_ID)
    if not options then
        options = PZAPI.ModOptions:create(ClientOptions.MOD_OPTIONS_ID, "Energy Routing System")
    end
    if not options then
        return
    end

    local existing = options.getOption and options:getOption("AmbientSoundVolume") or nil
    if existing then
        existing.value = clampVolumePercent(existing.value)
        existing.onChangeApply = function(value)
            ClientOptions._ambientVolume = clampVolumePercent(value)
        end
        ClientOptions._ambientVolume = existing.value
        ClientOptions._registered = true
        return
    end

    options:addTitle("Audio")
    options:addDescription("Client-only ambient volume for ERS wind and hydro sounds.")

    local slider = options:addSlider(
        "AmbientSoundVolume",
        "Ambient Volume",
        0,
        100,
        5,
        initial,
        "Adjusts wind/hydro turbine ambient sounds in ERS UI."
    )

    slider.onChangeApply = function(value)
        ClientOptions._ambientVolume = clampVolumePercent(value)
    end

    ClientOptions._registered = true
end

registerModOptions()
