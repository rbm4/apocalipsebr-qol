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
require "EnergyRouting/Init"
require "EnergyRouting/Weather"
require "EnergyRouting/Consumers"
require "ERS_BuildingPower"
require "EnergyController_Server"

print("[SPESS][Server] Server.lua loaded - registering events")
print("[SPESS][Server] Refrigeration lock patch v2 loaded (square hard-off)")

EnergyRouting.Server = EnergyRouting.Server or {}
local Server = EnergyRouting.Server

Server.edcs = Server.edcs or {}
Server.lastTickMinutes = Server.lastTickMinutes or 0
Server.energyProviders = Server.energyProviders or {}
Server.energyConsumers = Server.energyConsumers or {}
Server._powerStateLogById = Server._powerStateLogById or {}
Server._powerHeartbeatCounter = Server._powerHeartbeatCounter or 0
Server._manualEnforceTickCounter = Server._manualEnforceTickCounter or 0
Server._consumerCountLogById = Server._consumerCountLogById or {}
Server._consumerZeroDemandLogById = Server._consumerZeroDemandLogById or {}
Server._consumerDemandLogById = Server._consumerDemandLogById or {}
Server._consumerClassifiedLogById = Server._consumerClassifiedLogById or {}
Server._routingStateSignatureById = Server._routingStateSignatureById or {}
Server._broadcastStateSignatureById = Server._broadcastStateSignatureById or {}
Server._squareBusLogById = Server._squareBusLogById or {}
Server._groupStateDiagLogById = Server._groupStateDiagLogById or {}
Server._refrigerationForceLogById = Server._refrigerationForceLogById or {}
Server._lightsForceLogById = Server._lightsForceLogById or {}
Server._debugAreaPowerLogById = Server._debugAreaPowerLogById or {}
Server.DEBUG_SQUARE_BUS_ONLY = false
-- Keep vanilla-like/global building power path disabled by default.
-- It can energize whole buildings regardless of real ERS budget.
Server.USE_VANILLA_LIKE_ENERGY_FLOW = false
print("[SPESS][Server] Energy flow flags debugOnly=" .. tostring(Server.DEBUG_SQUARE_BUS_ONLY)
    .. " vanillaLike=" .. tostring(Server.USE_VANILLA_LIKE_ENERGY_FLOW))

local CONTROLLER_IDLE_CONSUMPTION = 25 -- W
local REFRIGERATION_CACHE_REFRESH_MINUTES = 10
local FULL_CONSUMER_RESCAN_MINUTES = 90
local DEFAULT_CONSUMER_SCAN_INTERVAL_HOURS = 6
local DEFAULT_CONTROLLER_VERTICAL_RANGE = 2
local DEFAULT_STATE_SYNC_THRESHOLD = 0.1
local ENABLE_WORLD_PASS_SCAN = false
local VANILLA_LIKE_SQUARE_REFRESH_MINUTES = 60
local VANILLA_LIKE_FULL_ENFORCE_MINUTES = 10
-- ON heartbeat is used only for anti-leak enforcement; keep it less aggressive.
local NON_VANILLA_HEARTBEAT_TICK_INTERVAL = 180
local REMOTE_CONTROLLER_UPDATE_INTERVAL_MINUTES = 10
local RUNTIME_NEARBY_PLAYER_DISTANCE = 32
local MANUAL_ENFORCE_MIN_INTERVAL_MS = 2500
local PERF_WARN_MS = 50
-- Simple ON/OFF architecture:
-- Keep consumer scanning/consumption, disable priority modes and per-group manual routing.
-- Legacy priority code remains below for future reactivation.
local SIMPLE_OUTPUT_ONLY_MODE = true
local isGroupEligibleForMode
local PRIORITY_GROUP_ORDER = { "refrigeration", "lights", "cooking", "industrial" }
local MODE_PRESET_TOGGLES = {
    Balanced = {
        refrigeration = true,
        lights = true,
        cooking = true,
        industrial = true,
    },
    Survival = {
        refrigeration = true,
        lights = true,
        cooking = false,
        industrial = false,
    },
    Comfort = {
        refrigeration = true,
        lights = true,
        cooking = true,
        industrial = false,
    },
}

local function forceAllTogglesOn(edc)
    if not edc then
        return
    end
    edc.toggles = edc.toggles or EnergyRouting.MakeDefaultToggles()
    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
        edc.toggles[group.id] = true
    end
end

local function getPresetToggleValue(mode, groupId)
    local preset = MODE_PRESET_TOGGLES[mode] or MODE_PRESET_TOGGLES.Balanced
    local value = preset and preset[groupId]
    if value == nil then
        value = (mode == "Survival") and false or true
    end
    return value == true
end

local function logEnergy(message)
    local debugEnabled = EnergyRouting and EnergyRouting.IsDebugEnabled and EnergyRouting.IsDebugEnabled() == true
    if not debugEnabled then
        return
    end
    print("[SPESS][EnergyTick] " .. tostring(message))
end

local function isVanillaLikeEnergyFlow()
    return Server.DEBUG_SQUARE_BUS_ONLY == true
        or Server.USE_VANILLA_LIKE_ENERGY_FLOW == true
end

local function getWorldMinutes()
    local gt = getGameTime()
    if not gt or not gt.getWorldAgeHours then
        return 0
    end
    return math.floor(gt:getWorldAgeHours() * 60)
end

local function getWorldHours()
    return getWorldMinutes() / 60
end

local function getConfiguredScanIntervalHours()
    local configured = tonumber(EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("ConsumerScanIntervalHours") or nil)
    if not configured or configured <= 0 then
        configured = tonumber(SandboxVars and SandboxVars.ERS and SandboxVars.ERS.ScanIntervalHours or nil)
    end
    if not configured or configured <= 0 then
        configured = DEFAULT_CONSUMER_SCAN_INTERVAL_HOURS
    end
    return configured
end

local function getConfiguredSyncThreshold()
    local configured = tonumber(EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("StateSyncThreshold") or nil)
    if not configured or configured <= 0 then
        configured = tonumber(SandboxVars and SandboxVars.ERS and SandboxVars.ERS.SyncThreshold or nil)
    end
    if not configured or configured <= 0 then
        configured = DEFAULT_STATE_SYNC_THRESHOLD
    end
    return configured
end

local function roundToStep(value, step)
    local numeric = tonumber(value) or 0
    local safeStep = tonumber(step) or DEFAULT_STATE_SYNC_THRESHOLD
    if safeStep <= 0 then
        safeStep = DEFAULT_STATE_SYNC_THRESHOLD
    end
    local rounded = math.floor((numeric / safeStep) + 0.5) * safeStep
    local decimals = 0
    local probe = safeStep
    while probe < 1 and decimals < 4 do
        probe = probe * 10
        decimals = decimals + 1
    end
    local format = "%." .. tostring(decimals) .. "f"
    local display = string.format(format, rounded)
    return tonumber(display) or rounded, display
end

local function getPerfNowMs()
    if getTimestampMs then
        local ok, value = pcall(getTimestampMs)
        if ok and type(value) == "number" then
            return value
        end
    end
    return math.floor((os.clock() or 0) * 1000)
end

local BITLIB = bit32 or bit
local BXOR = BITLIB and BITLIB.bxor or nil
local TOBIT = BITLIB and BITLIB.tobit or nil

local function u32(n)
    n = tonumber(n) or 0
    if TOBIT then
        n = TOBIT(n)
    end
    n = n % 4294967296
    if n < 0 then
        n = n + 4294967296
    end
    return n
end

local function mixSquareHash32(x, y, z)
    local v = (x * 73856093) + (y * 19349663) + (z * 83492791)
    local m = u32(v)
    if BXOR then
        m = BXOR(m, u32((x * 2654435761) + (y * 97531) + (z * 421)))
    end
    return u32(m)
end

local function getControllerSquare(edc)
    if not edc then
        return nil
    end
    local cell = getCell and getCell() or nil
    if not cell or not cell.getGridSquare then
        return nil
    end
    local x = math.floor(tonumber(edc.x) or 0)
    local y = math.floor(tonumber(edc.y) or 0)
    local z = math.floor(tonumber(edc.z) or 0)
    return cell:getGridSquare(x, y, z)
end

local function isControllerSquareLoaded(edcOrId)
    local edcId = edcOrId
    if type(edcOrId) == "table" then
        edcId = edcOrId.id
    end
    if type(edcId) ~= "string" then
        return false
    end
    local parseCoords = EnergyNetwork and EnergyNetwork.ParseCoordsFromId or nil
    if not parseCoords then
        return false
    end

    local x, y, z = parseCoords(edcId, "network")
    if not x then
        x, y, z = parseCoords(edcId, "energy_net")
    end
    if not x then
        return false
    end

    local cell = getCell and getCell() or nil
    if not cell or not cell.getGridSquare then
        return false
    end
    return cell:getGridSquare(x, y, z) ~= nil
end

local function hasNearbyOnlinePlayer(square, maxDistance)
    if not square then
        return false
    end
    local maxDist = math.max(1, tonumber(maxDistance) or 28)
    local function nearEnough(playerObj)
        if not playerObj or (playerObj.isDead and playerObj:isDead()) then
            return false
        end
        local psq = playerObj.getSquare and playerObj:getSquare() or nil
        if not psq or not psq.DistToProper then
            return false
        end
        return psq:DistToProper(square) <= maxDist
    end

    if getOnlinePlayers then
        local players = getOnlinePlayers()
        if players and players.size then
            for i = 0, players:size() - 1 do
                if nearEnough(players:get(i)) then
                    return true
                end
            end
        end
    end

    if getNumActivePlayers and getSpecificPlayer then
        local count = tonumber(getNumActivePlayers()) or 0
        for i = 0, count - 1 do
            if nearEnough(getSpecificPlayer(i)) then
                return true
            end
        end
    end

    return false
end

local function hasNearbyOnlinePlayerCached(edc, square, maxDistance, nowMinutes, cacheKey)
    if not square then
        return false
    end
    if not edc then
        return hasNearbyOnlinePlayer(square, maxDistance)
    end

    local distance = math.max(1, tonumber(maxDistance) or RUNTIME_NEARBY_PLAYER_DISTANCE)
    local minute = tonumber(nowMinutes) or -1
    local key = tostring(cacheKey or "runtime")

    local cache = edc._ersNearbyPlayerCache
    if type(cache) ~= "table" then
        cache = {}
        edc._ersNearbyPlayerCache = cache
    end

    local entry = cache[key]
    if type(entry) == "table"
        and tonumber(entry.minute) == minute
        and tonumber(entry.distance) == distance then
        return entry.result == true
    end

    local result = hasNearbyOnlinePlayer(square, distance)
    cache[key] = {
        minute = minute,
        distance = distance,
        result = (result == true),
    }
    return result == true
end

local function shouldProcessControllerNow(edc, nowMinutes, intervalMinutes, maxDistance)
    if not edc then
        return false
    end
    if edc._forceFullEnforce == true
        or edc._forceConsumerRescan == true
        or edc.isDirty == true
        or edc._ersOffEnforcePending == true then
        return true
    end

    local sq = getControllerSquare(edc)
    local distance = math.max(1, tonumber(maxDistance) or RUNTIME_NEARBY_PLAYER_DISTANCE)
    if sq and hasNearbyOnlinePlayerCached(edc, sq, distance, nowMinutes, "runtime") then
        edc._lastRuntimeControllerProcessAt = nowMinutes
        return true
    end

    local interval = math.max(1, tonumber(intervalMinutes) or REMOTE_CONTROLLER_UPDATE_INTERVAL_MINUTES)
    local last = tonumber(edc._lastRuntimeControllerProcessAt) or -999999
    if (tonumber(nowMinutes) or 0) - last >= interval then
        edc._lastRuntimeControllerProcessAt = nowMinutes
        return true
    end
    return false
end

local function getConsumerScanRadius()
    local radius = tonumber(EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("DeviceScanRadius") or nil)
    if not radius or radius <= 0 then
        radius = tonumber(EnergyRouting and EnergyRouting.CONTROLLER_RADIUS or nil)
    end
    if not radius or radius <= 0 then
        radius = 20
    end
    return math.floor(radius)
end

local function getControllerVerticalRange()
    local configured = tonumber(EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("ControllerVerticalRange") or nil)
    if not configured or configured < 0 then
        configured = tonumber(SandboxVars and SandboxVars.ERS and SandboxVars.ERS.ControllerVerticalRange or nil)
    end
    if not configured or configured < 0 then
        configured = tonumber(SandboxVars and SandboxVars.ERS and SandboxVars.ERS.VerticalRange or nil)
    end
    if not configured or configured < 0 then
        configured = DEFAULT_CONTROLLER_VERTICAL_RANGE
    end
    return math.floor(math.max(0, configured))
end

local function getControllerZBounds(cell, centerZ, customRange)
    local z = math.floor(tonumber(centerZ) or 0)
    local range = tonumber(customRange)
    if range == nil then
        range = getControllerVerticalRange()
    end
    range = math.floor(math.max(0, tonumber(range) or 0))

    local minZ = z - range
    if minZ < 0 then
        minZ = 0
    end
    local maxZ = z + range

    if cell and cell.getMaxZ then
        local ok, worldMaxZ = pcall(cell.getMaxZ, cell)
        if ok and type(worldMaxZ) == "number" and worldMaxZ >= 0 then
            worldMaxZ = math.floor(worldMaxZ)
            if maxZ > worldMaxZ then
                maxZ = worldMaxZ
            end
        end
    end

    if maxZ < minZ then
        maxZ = minZ
    end
    return minZ, maxZ
end

local function safeCall(obj, method, ...)
    if obj and obj[method] then
        local ok, result = pcall(obj[method], obj, ...)
        if ok then
            return result
        end
    end
    return nil
end

local function isInstanceOf(obj, className)
    if not obj or not className or not instanceof then
        return false
    end
    local ok, result = pcall(instanceof, obj, className)
    return ok and result == true
end

local function getObjectInventoryItem(obj)
    if not obj then
        return nil
    end
    return safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
end

local function hasContainerType(obj, containerType)
    if not obj or not containerType then
        return false
    end
    local wanted = string.lower(tostring(containerType))
    local function matchesTypeName(candidateType)
        if not candidateType then
            return false
        end
        local probe = string.lower(tostring(candidateType))
        return probe == wanted or probe:find(wanted, 1, true) ~= nil
    end
    if obj.getContainerByType and safeCall(obj, "getContainerByType", containerType) then
        return true
    end

    local direct = safeCall(obj, "getContainer")
    local directType = direct and safeCall(direct, "getType") or nil
    if matchesTypeName(directType) then
        return true
    end

    local item = getObjectInventoryItem(obj)
    local itemContainer = item and safeCall(item, "getContainer") or nil
    local itemContainerType = itemContainer and safeCall(itemContainer, "getType") or nil
    if matchesTypeName(itemContainerType) then
        return true
    end

    local count = safeCall(obj, "getContainerCount")
    if type(count) == "number" and count > 0 and obj.getContainerByIndex then
        for i = 0, count - 1 do
            local candidate = safeCall(obj, "getContainerByIndex", i)
            local candidateType = candidate and safeCall(candidate, "getType") or nil
            if matchesTypeName(candidateType) then
                return true
            end
        end
    end
    return false
end

local function appendProbePart(parts, value)
    if value == nil then
        return
    end
    local text = tostring(value)
    if text ~= "" then
        table.insert(parts, string.lower(text))
    end
end

local function lowerText(value)
    if value == nil then
        return nil
    end
    return string.lower(tostring(value))
end

local REFRIGERATION_TOKENS = {
    "fridge",
    "freezer",
    "isfridge",
    "refrigerator",
    "refrigeration",
    "icebox",
    "cooler",
    "nevera",
    "heladera",
    "refrigerador",
    "frigorifico",
    "geladeira",
}

local function textHasRefrigerationToken(text)
    local probe = lowerText(text)
    if not probe or probe == "" then
        return false
    end
    for _, token in ipairs(REFRIGERATION_TOKENS) do
        if probe:find(token, 1, true) then
            return true
        end
    end
    return false
end

local function getPropertyValue(props, key)
    if not props or not key then
        return nil
    end
    local value = nil
    if props.Val then
        value = safeCall(props, "Val", key)
    end
    if value == nil and props.value then
        value = safeCall(props, "value", key)
    end
    if value == nil then
        return nil
    end
    local text = tostring(value)
    if text == "" then
        return nil
    end
    return text
end

local function hasPropertyFlag(props, key)
    if not props or not key then
        return false
    end
    if props.Is and safeCall(props, "Is", key) then
        return true
    end
    local value = lowerText(getPropertyValue(props, key))
    if not value then
        return false
    end
    return value ~= "false" and value ~= "0" and value ~= "no"
end

local function propertyContains(props, key, needle)
    if not props or not key or not needle then
        return false
    end
    local value = lowerText(getPropertyValue(props, key))
    if not value then
        return false
    end
    return value:find(string.lower(tostring(needle)), 1, true) ~= nil
end

local function appendKnownPropertyTokens(parts, obj)
    local props = safeCall(obj, "getProperties")
    if not props then
        return
    end

    local keys = {
        "IsoType",
        "CustomName",
        "GroupName",
        "AmbientSound",
        "signal",
        "container",
        "Material",
        "Material2",
        "Material3",
        "TV",
        "Microwave",
        "IsFridge",
        "Freezer",
    }
    for _, key in ipairs(keys) do
        appendProbePart(parts, getPropertyValue(props, key))
        if hasPropertyFlag(props, key) then
            appendProbePart(parts, key)
        end
    end

    if hasPropertyFlag(props, "HasLightOnSprite") then
        appendProbePart(parts, "haslightonsprite")
    end
    if hasPropertyFlag(props, "solidtrans") then
        appendProbePart(parts, "solidtrans")
    end
    if hasPropertyFlag(props, "container") then
        appendProbePart(parts, "container")
    end
    if propertyContains(props, "signal", "tv") then
        appendProbePart(parts, "signal_tv")
    end
end

local function getObjectClassificationProbe(obj)
    if not obj then
        return ""
    end
    local parts = {}

    local sprite = safeCall(obj, "getSprite")
    appendProbePart(parts, sprite and safeCall(sprite, "getName") or nil)
    appendProbePart(parts, safeCall(obj, "getName"))
    appendProbePart(parts, safeCall(obj, "getObjectName"))

    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    if item then
        appendProbePart(parts, safeCall(item, "getFullType"))
        appendProbePart(parts, safeCall(item, "getDisplayName"))
        appendProbePart(parts, safeCall(item, "getName"))
        appendProbePart(parts, safeCall(item, "getType"))
    end

    if hasContainerType(obj, "fridge") then appendProbePart(parts, "fridge") end
    if hasContainerType(obj, "freezer") then appendProbePart(parts, "freezer") end
    if hasContainerType(obj, "stove") then appendProbePart(parts, "stove") end
    if hasContainerType(obj, "microwave") then appendProbePart(parts, "microwave") end
    if hasContainerType(obj, "oven") then appendProbePart(parts, "oven") end
    appendKnownPropertyTokens(parts, obj)

    appendProbePart(parts, tostring(obj))
    return table.concat(parts, " ")
end

local function inferGroupFromProbe(probe)
    if type(probe) ~= "string" or probe == "" then
        return nil
    end

    if textHasRefrigerationToken(probe) then
        return "refrigeration"
    end

    if probe:find("microwave", 1, true)
        or probe:find("stove", 1, true)
        or probe:find("oven", 1, true)
        or probe:find("isostove", 1, true)
        or probe:find("cooking", 1, true)
        or probe:find("toaster", 1, true)
        or probe:find("grill", 1, true) then
        return "cooking"
    end

    if probe:find("light", 1, true)
        or probe:find("lamp", 1, true)
        or probe:find("lighting", 1, true)
        or probe:find("haslightonsprite", 1, true)
        or probe:find("lightbulbambiance", 1, true)
        or probe:find("streetlight", 1, true)
        or probe:find("switch", 1, true) then
        return "lights"
    end

    if probe:find("television", 1, true)
        or probe:find("tv", 1, true)
        or probe:find("isotelevision", 1, true)
        or probe:find("clockambiance", 1, true)
        or probe:find("signal_tv", 1, true)
        or probe:find("radio", 1, true)
        or probe:find("jukebox", 1, true)
        or probe:find("entertainment", 1, true) then
        return "entertainment"
    end

    if probe:find("washer", 1, true)
        or probe:find("dryer", 1, true)
        or probe:find("washingmachine", 1, true)
        or probe:find("clotheswasher", 1, true)
        or probe:find("tumbledryer", 1, true)
        or probe:find("clothesdryer", 1, true)
        or probe:find("laundry", 1, true)
        or probe:find("lavadora", 1, true)
        or probe:find("secadora", 1, true) then
        return "industrial"
    end

    return nil
end

local HARD_BLOCK_TV_SPRITES = {
    appliances_television_01_2 = true,
    appliances_television_01_7 = true,
    appliances_television_01_10 = true,
}

local function getSpriteNameLower(obj)
    local sprite = obj and safeCall(obj, "getSprite") or nil
    local name = sprite and safeCall(sprite, "getName") or nil
    if not name or name == "" then
        return nil
    end
    return string.lower(tostring(name))
end

local function isHardBlockedTvSprite(obj)
    local name = getSpriteNameLower(obj)
    if not name then
        return false
    end
    return HARD_BLOCK_TV_SPRITES[name] == true
end

local function isEntertainmentDeviceObject(obj)
    if not obj then
        return false
    end
    if isHardBlockedTvSprite(obj) then
        return true
    end
    if isInstanceOf(obj, "IsoTelevision") or isInstanceOf(obj, "IsoRadio") then
        return true
    end

    local props = safeCall(obj, "getProperties")
    if hasPropertyFlag(props, "TV")
        or propertyContains(props, "IsoType", "IsoTelevision")
        or propertyContains(props, "signal", "tv")
        or propertyContains(props, "AmbientSound", "ClockAmbiance") then
        return true
    end

    local probe = getObjectClassificationProbe(obj)
    if type(probe) == "string" and probe ~= "" then
        if probe:find("television", 1, true)
            or probe:find("isotelevision", 1, true)
            or probe:find("signal_tv", 1, true)
            or probe:find("radio", 1, true)
            or probe:find("jukebox", 1, true)
            or probe:find("entertainment", 1, true) then
            return true
        end
    end
    return false
end

local function isPassiveTelevisionObject(obj)
    if not obj then
        return false
    end
    if EnergyRouting and EnergyRouting.Consumers and EnergyRouting.Consumers.isPassiveObject then
        return EnergyRouting.Consumers.isPassiveObject(obj) == true
    end
    if isInstanceOf(obj, "IsoTelevision") then
        return true
    end
    local props = safeCall(obj, "getProperties")
    return propertyContains(props, "IsoType", "IsoTelevision")
end

local function isPassiveTelevisionActive(obj)
    if not isPassiveTelevisionObject(obj) then
        return false
    end
    if EnergyRouting and EnergyRouting.Consumers and EnergyRouting.Consumers.detectPassive then
        return EnergyRouting.Consumers.detectPassive(obj) == true
    end
    return safeCall(obj, "isTurnedOn") == true
end

local function isBatteryRadioObject(obj)
    if not obj then
        return false
    end
    if isInstanceOf(obj, "IsoRadio") then
        return true
    end
    local props = safeCall(obj, "getProperties")
    if propertyContains(props, "signal", "radio") then
        return true
    end
    local probe = getObjectClassificationProbe(obj)
    return type(probe) == "string" and probe:find("radio", 1, true) ~= nil
end

local function isExplicitlyExcludedConsumerObject(obj)
    if not obj then
        return false
    end
    local consumersModule = EnergyRouting and EnergyRouting.Consumers or nil
    if consumersModule and consumersModule.isExcludedObject then
        return consumersModule.isExcludedObject(obj) == true
    end
    return false
end

local function getPassiveTelevisionWatts()
    local configured = EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("PassiveTelevisionWatts") or nil
    local watts = tonumber(configured) or 0
    if watts <= 0 then
        watts = tonumber(EnergyRouting and EnergyRouting.GroupDefaultWatts and EnergyRouting.GroupDefaultWatts.entertainment) or 80
    end
    if watts <= 0 then
        watts = 80
    end
    return watts
end

local function getDefaultWattsForGroup(groupId)
    local defaults = EnergyRouting and EnergyRouting.GroupDefaultWatts or nil
    local watts = defaults and defaults[groupId] or nil
    watts = tonumber(watts) or 0
    if watts <= 0 then
        watts = 100
    end
    return watts
end

local function normalizeWattsForGroup(groupId, watts)
    local gid = groupId
    if groupId then
        local probe = string.lower(tostring(groupId))
        if EnergyRouting.GroupsById and EnergyRouting.GroupsById[probe] then
            gid = probe
        else
            for _, group in ipairs(EnergyRouting.GroupsList or {}) do
                if string.lower(tostring(group.name or "")) == probe then
                    gid = group.id
                    break
                end
            end
        end
    end
    local value = tonumber(watts) or 0
    if EnergyRouting and EnergyRouting.NormalizeGroupConsumption then
        return EnergyRouting.NormalizeGroupConsumption(gid, value)
    end
    if value <= 0 then
        value = getDefaultWattsForGroup(gid)
    end
    return math.max(1, value)
end

local function capTotalWattsForGroup(groupId, watts)
    local value = tonumber(watts) or 0
    if value < 0 then
        value = 0
    end

    local gid = groupId and string.lower(tostring(groupId)) or nil
    if gid and not (EnergyRouting.GroupsById and EnergyRouting.GroupsById[gid]) then
        for _, group in ipairs(EnergyRouting.GroupsList or {}) do
            if string.lower(tostring(group.name or "")) == gid then
                gid = group.id
                break
            end
        end
    end
    local caps = EnergyRouting and EnergyRouting.GroupConsumptionCaps or nil
    local cap = caps and gid and tonumber(caps[gid]) or nil
    if cap and cap > 0 and value > cap then
        value = cap
    end
    return value
end

local function normalizeGroupId(groupId)
    if not groupId then
        return nil
    end
    local probe = string.lower(tostring(groupId))
    if EnergyRouting.GroupsById and EnergyRouting.GroupsById[probe] then
        return probe
    end
    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
        if string.lower(tostring(group.name or "")) == probe then
            return group.id
        end
    end
    return nil
end

local function getObjectModData(obj)
    if not obj then
        return nil
    end
    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    if item and item.getModData then
        return item:getModData()
    end
    return safeCall(obj, "getModData")
end

local function transmitObjectModData(obj)
    if not obj then
        return
    end
    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    if item and item.transmitModData then
        item:transmitModData()
        return
    end
    if obj.transmitModData then
        obj:transmitModData()
    end
end

local function setModDataField(md, key, value)
    if not md or key == nil then
        return false
    end
    if md[key] == value then
        return false
    end
    md[key] = value
    return true
end

local function hasAnyEntries(tbl)
    if type(tbl) ~= "table" then
        return false
    end
    for _ in pairs(tbl) do
        return true
    end
    return false
end

local function togglesDiffer(a, b)
    if type(a) ~= "table" then
        return hasAnyEntries(b)
    end
    if type(b) ~= "table" then
        return hasAnyEntries(a)
    end
    local seen = {}
    for k, v in pairs(a) do
        seen[k] = true
        if b[k] ~= v then
            return true
        end
    end
    for k, v in pairs(b) do
        if not seen[k] and a[k] ~= v then
            return true
        end
    end
    return false
end

local function normalizeToggles(source)
    local normalized = EnergyRouting.MakeDefaultToggles and EnergyRouting.MakeDefaultToggles() or {}
    if type(source) ~= "table" then
        return normalized
    end
    for key, value in pairs(source) do
        local groupId = normalizeGroupId(key) or tostring(key)
        if type(value) == "boolean" then
            normalized[groupId] = value
        else
            normalized[groupId] = value ~= false
        end
    end
    return normalized
end

local function syncEdcConfigWithController(edc, controllerObj)
    if type(edc) ~= "table" or not controllerObj then
        return false
    end
    local md = getObjectModData(controllerObj)
    if not md then
        return false
    end
    md.energyController = md.energyController or {}
    local controller = md.energyController
    local edcChanged = false
    local controllerChanged = false

    if edc.outputEnabled == nil then
        edc.outputEnabled = true
        edcChanged = true
    end
    if edc.mode == nil or edc.mode == "" then
        edc.mode = "Balanced"
        edcChanged = true
    end
    if type(edc.toggles) ~= "table" then
        edc.toggles = EnergyRouting.MakeDefaultToggles and EnergyRouting.MakeDefaultToggles() or {}
        edcChanged = true
    end

    if controller.outputEnabled ~= nil then
        local outputFromController = (controller.outputEnabled ~= false)
        if (edc.outputEnabled ~= false) ~= outputFromController then
            edc.outputEnabled = outputFromController
            edcChanged = true
        end
    else
        controller.outputEnabled = (edc.outputEnabled ~= false)
        controllerChanged = true
    end

    local controllerMode = nil
    if type(controller.mode) == "string" and controller.mode ~= "" then
        controllerMode = controller.mode
    elseif type(controller.priorityMode) == "string" and controller.priorityMode ~= "" then
        controllerMode = controller.priorityMode
    end
    if controllerMode then
        if edc.mode ~= controllerMode then
            edc.mode = controllerMode
            edcChanged = true
        end
    else
        controller.mode = edc.mode
        controller.priorityMode = edc.mode
        controllerChanged = true
    end

    if edc.mode ~= "Manual" then
        local presetToggles = {}
        for _, group in ipairs(EnergyRouting.GroupsList or {}) do
            presetToggles[group.id] = getPresetToggleValue(edc.mode, group.id)
        end
        if togglesDiffer(edc.toggles, presetToggles) then
            edc.toggles = presetToggles
            edcChanged = true
        end
        local controllerToggles = (type(controller.toggles) == "table") and normalizeToggles(controller.toggles) or {}
        if togglesDiffer(controllerToggles, presetToggles) then
            controller.toggles = EnergyRouting.CloneTable(presetToggles)
            controllerChanged = true
        end
    elseif type(controller.toggles) == "table" and hasAnyEntries(controller.toggles) then
        local normalizedControllerToggles = normalizeToggles(controller.toggles)
        if togglesDiffer(edc.toggles, normalizedControllerToggles) then
            edc.toggles = normalizedControllerToggles
            edcChanged = true
        end
    else
        controller.toggles = EnergyRouting.CloneTable(edc.toggles or {})
        controllerChanged = true
    end

    if controllerChanged then
        transmitObjectModData(controllerObj)
    end
    return edcChanged or controllerChanged
end

function Server.GetControllerObject(edcId)
    if not edcId then
        return nil
    end
    if EnergyController and EnergyController.Server and EnergyController.Server.GetControllerById then
        return EnergyController.Server.GetControllerById(edcId)
    end
    return nil
end

local function getBuildingKeyFromSquare(square)
    if not square then
        return nil
    end
    local building = safeCall(square, "getBuilding")
    if not building then
        local room = safeCall(square, "getRoom")
        building = room and safeCall(room, "getBuilding") or nil
    end
    if not building then
        return nil
    end
    local buildingId = safeCall(building, "getID")
    if buildingId ~= nil then
        return tostring(buildingId)
    end
    return tostring(building)
end

function Server.FindControllerInRange(square, maxRange)
    if not square then
        return nil, nil, nil
    end

    local range = tonumber(maxRange) or (EnergyRouting.CONTROLLER_RADIUS or 20)
    local rangeSq = range * range
    local bestId = nil
    local bestEdc = nil
    local bestDistSq = nil
    local bestPriority = -1
    local z = square:getZ()
    local x = square:getX()
    local y = square:getY()
    local sourceBuildingKey = getBuildingKeyFromSquare(square)
    local cell = getCell and getCell() or nil
    local edcBuildingKeyCache = {}

    for edcId, edc in pairs(Server.edcs or {}) do
        if edc and edc.x and edc.y then
            local dx = edc.x - x
            local dy = edc.y - y
            local distSq = dx * dx + dy * dy
            if distSq <= rangeSq then
                local sameFloor = (edc.z == z)
                local sameBuilding = false
                if sourceBuildingKey and cell and edc.z ~= nil then
                    local cached = edcBuildingKeyCache[edcId]
                    if cached == nil then
                        local edcSq = cell:getGridSquare(edc.x, edc.y, edc.z)
                        cached = getBuildingKeyFromSquare(edcSq) or false
                        edcBuildingKeyCache[edcId] = cached
                    end
                    sameBuilding = (cached ~= false) and (cached == sourceBuildingKey)
                end

                local priority = 0
                if sameBuilding then
                    -- Allow cross-floor routing when consumer and controller share building.
                    priority = 2
                elseif sameFloor then
                    -- Preserve legacy behavior as fallback when not in the same building.
                    priority = 1
                end

                if priority > bestPriority or (priority == bestPriority and (not bestDistSq or distSq < bestDistSq)) then
                    bestPriority = priority
                    bestDistSq = distSq
                    bestId = edcId
                    bestEdc = edc
                end
            end
        end
    end

    if not bestId then
        return nil, nil, nil
    end

    local controllerObj = Server.GetControllerObject(bestId)
    return controllerObj, bestId, bestEdc
end

function Server.UpdateVanillaGeneratorFallback(edc)
    if not edc then
        return
    end
    if EnergyRouting.GetConfigValue("AllowGeneratorOverride") then
        return
    end
    local controllerObj = Server.GetControllerObject(edc.id)
    if not controllerObj then
        return
    end
    local sq = safeCall(controllerObj, "getSquare")
    if not sq then
        return
    end
    local building = safeCall(sq, "getBuilding")
    if not building then
        return
    end
    local generator = safeCall(building, "getGenerator")
    if not generator then
        return
    end
    local isOn = safeCall(generator, "isActivated") == true

    if edc.outputEnabled == false then
        if isOn then
            safeCall(generator, "setActivated", false)
        end
        return
    end

    local ersPoweringBuilding = false
    if Server.IsTotalBuildingPowerMode and Server.IsTotalBuildingPowerMode() then
        ersPoweringBuilding = (edc._ersBuildingPowerState == true)
    else
        ersPoweringBuilding = (edc.powerSource == "ERS")
            and (((edc.authorizedPowerWatts or 0) > 0)
                or ((edc.storage or 0) > 0)
                or ((edc.poweredConsumerCount or 0) > 0))
    end

    if ersPoweringBuilding then
        if isOn then
            safeCall(generator, "setActivated", false)
        end
    else
        if not isOn then
            safeCall(generator, "setActivated", true)
        end
    end
end

function Server.MakeEDCId(x, y, z)
    return string.format("network_%d_%d_%d", x, y, z)
end

function Server.NormalizeEDCId(edcId)
    if type(edcId) ~= "string" then
        return edcId
    end
    if string.find(edcId, ",", 1, true) then
        local xs, ys, zs = edcId:match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
        if xs and ys and zs then
            return Server.MakeEDCId(tonumber(xs), tonumber(ys), tonumber(zs))
        end
    end
    local xs, ys, zs = edcId:match("^energy_net_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
    if xs and ys and zs then
        return Server.MakeEDCId(tonumber(xs), tonumber(ys), tonumber(zs))
    end
    return edcId
end

function Server.EnsureEDCOptimizationState(edc, forceDirty)
    if type(edc) ~= "table" then
        return
    end

    if type(edc.consumerCache) ~= "table" then
        edc.consumerCache = {}
    end
    if edc.totalConsumptionRate == nil then
        edc.totalConsumptionRate = 0
    else
        edc.totalConsumptionRate = tonumber(edc.totalConsumptionRate) or 0
    end

    edc.scanIntervalHours = getConfiguredScanIntervalHours()
    edc.syncThreshold = getConfiguredSyncThreshold()

    if edc.lastConsumerScanTime == nil then
        local legacyLastScanMinutes = tonumber(edc._lastScannedAt)
        edc.lastConsumerScanTime = legacyLastScanMinutes and (legacyLastScanMinutes / 60) or -1
    else
        edc.lastConsumerScanTime = tonumber(edc.lastConsumerScanTime) or -1
    end

    if edc.isDirty == nil then
        edc.isDirty = forceDirty == true
    elseif forceDirty == true then
        edc.isDirty = true
    end

    if edc.lastSentEnergy == nil then
        edc.lastSentEnergy = -1
    else
        edc.lastSentEnergy = tonumber(edc.lastSentEnergy) or -1
    end

    if edc.outputEnabled == false then
        if edc._ersSkipConsumerScanWhileOff == nil then
            edc._ersSkipConsumerScanWhileOff = true
        end
    else
        edc._ersSkipConsumerScanWhileOff = nil
        edc._ersOffEnforcePending = nil
    end
end

local function shouldSkipDirtyScanWhileOff(edc)
    return type(edc) == "table"
        and (edc.outputEnabled == false)
        and (edc._ersSkipConsumerScanWhileOff == true)
end

local function isControllerOffIdleSkip(edc)
    return type(edc) == "table"
        and (edc.outputEnabled == false)
        and (edc._ersSkipConsumerScanWhileOff == true)
        and (edc._ersOffEnforcePending ~= true)
end

function Server.MarkConsumersDirtyById(edcId, reason)
    local normalizedId = Server.NormalizeEDCId(edcId)
    if not normalizedId then
        return false
    end
    local edc = Server.edcs and Server.edcs[normalizedId] or nil
    if not edc then
        return false
    end
    Server.EnsureEDCOptimizationState(edc, true)
    if shouldSkipDirtyScanWhileOff(edc) then
        edc.isDirty = false
        edc._forceConsumerRescan = nil
        if reason then
            edc._dirtyReason = reason
        end
        return true
    end
    edc._forceConsumerRescan = true
    if reason then
        edc._dirtyReason = reason
    end
    return true
end

function Server.MarkConsumersDirty(edcOrId, reason)
    if type(edcOrId) == "table" then
        Server.EnsureEDCOptimizationState(edcOrId, true)
        if shouldSkipDirtyScanWhileOff(edcOrId) then
            edcOrId.isDirty = false
            edcOrId._forceConsumerRescan = nil
            if reason then
                edcOrId._dirtyReason = reason
            end
            return true
        end
        edcOrId._forceConsumerRescan = true
        if reason then
            edcOrId._dirtyReason = reason
        end
        return true
    end
    return Server.MarkConsumersDirtyById(edcOrId, reason)
end

function Server.LoadModData()
    local data = ModData.getOrCreate("EnergyRouting")
    Server.modData = data
    Server.edcs = data.edcs or {}
    data.edcs = Server.edcs
    data.links = data.links or { controllers = {}, objects = {} }
    data.links.controllers = data.links.controllers or {}
    data.links.objects = data.links.objects or {}
    Server.linkCache = data.links

    -- MIGRACIÓN: "x,y,z" -> "network_x_y_z"
    local migrated = {}
    for id, edc in pairs(Server.edcs) do
        if type(id) == "string" and string.find(id, ",", 1, true) then
            local x,y,z = id:match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
            x,y,z = tonumber(x), tonumber(y), tonumber(z)
            if x and y and z then
                local newId = Server.MakeEDCId(x,y,z)
                edc.id = newId
                migrated[newId] = edc
                Server.edcs[id] = nil
            end
        end
    end
    for k,v in pairs(migrated) do
        Server.edcs[k] = v
    end

    local cell = getCell()
    if cell then
        for _, edc in pairs(Server.edcs) do
            Server.EnsureEDCOptimizationState(edc, true)
            local square = cell:getGridSquare(edc.x, edc.y, edc.z)
            if square then
                local md = square:getModData()
                md.EnergyRoutingEDCId = edc.id
                if square.transmitModData then
                    square:transmitModData()
                end
            end
        end
    else
        for _, edc in pairs(Server.edcs) do
            Server.EnsureEDCOptimizationState(edc, true)
        end
    end

    if EnergyRouting and EnergyRouting.Consumers and EnergyRouting.Consumers.RestoreFromEDCs then
        EnergyRouting.Consumers.RestoreFromEDCs(Server.edcs)
    end
end

function Server.EnsureLinkCache()
    if not Server.modData then
        Server.modData = ModData.getOrCreate("EnergyRouting")
    end
    local links = Server.modData.links
    if type(links) ~= "table" then
        links = {}
    end
    if type(links.controllers) ~= "table" then
        links.controllers = {}
    end
    if type(links.objects) ~= "table" then
        links.objects = {}
    end
    Server.modData.links = links
    Server.linkCache = links
    return links
end

local function ensureLinkEntry(cache, edcId)
    if not cache or not edcId then
        return nil
    end
    local entry = cache.controllers[edcId]
    if not entry or type(entry) ~= "table" then
        entry = { panels = {}, batteries = {}, turbines = {}, hydroTurbines = {}, windBatteries = {} }
        cache.controllers[edcId] = entry
    end
    if type(entry.panels) ~= "table" then
        entry.panels = {}
    end
    if type(entry.batteries) ~= "table" then
        entry.batteries = {}
    end
    if type(entry.turbines) ~= "table" then
        entry.turbines = {}
    end
    if type(entry.hydroTurbines) ~= "table" then
        entry.hydroTurbines = {}
    end
    if type(entry.windBatteries) ~= "table" then
        entry.windBatteries = {}
    end
    -- Backward compatibility for older cache keys.
    if type(entry.windTurbines) == "table" then
        for windId in pairs(entry.windTurbines) do
            entry.turbines[windId] = true
        end
        entry.windTurbines = nil
    end
    return entry
end

local function hasAnyEntry(list)
    if type(list) ~= "table" then
        return false
    end
    for _ in pairs(list) do
        return true
    end
    return false
end

local function addIdToList(list, id)
    if not list or not id then
        return list
    end
    if list[id] then
        return list
    end
    for _, value in pairs(list) do
        if value == id then
            return list
        end
    end
    list[id] = true
    return list
end

local function forEachId(list, fn)
    if not list or not fn then
        return
    end
    for k, v in pairs(list) do
        if type(k) == "string" then
            fn(k)
        elseif type(v) == "string" then
            fn(v)
        end
    end
end

function Server.RecordLink(edcId, kind, objId)
    if not edcId or not objId then
        return
    end
    local cache = Server.EnsureLinkCache()
    if not cache then
        return
    end
    local bucket = nil
    if kind == "panel" then
        bucket = "panels"
    elseif kind == "battery" then
        bucket = "batteries"
    elseif kind == "turbine" then
        bucket = "turbines"
    elseif kind == "hydro" then
        bucket = "hydroTurbines"
    elseif kind == "windBattery" then
        bucket = "windBatteries"
    end
    if not bucket then
        return
    end
    local entry = ensureLinkEntry(cache, edcId)
    local previous = cache.objects[objId]
    if previous and previous ~= edcId then
        local prevEntry = cache.controllers[previous]
        if prevEntry and prevEntry[bucket] then
            prevEntry[bucket][objId] = nil
        end
    end
    cache.objects[objId] = edcId
    entry[bucket][objId] = true
    Server.SaveModData()
end

function Server.RemoveLink(edcId, kind, objId)
    if not edcId or not objId then
        return
    end
    local cache = Server.EnsureLinkCache()
    if not cache then
        return
    end
    local bucket = nil
    if kind == "panel" then
        bucket = "panels"
    elseif kind == "battery" then
        bucket = "batteries"
    elseif kind == "turbine" then
        bucket = "turbines"
    elseif kind == "hydro" then
        bucket = "hydroTurbines"
    elseif kind == "windBattery" then
        bucket = "windBatteries"
    end
    if not bucket then
        return
    end
    local entry = cache.controllers[edcId]
    if entry and entry[bucket] then
        entry[bucket][objId] = nil
    end
    if cache.objects[objId] == edcId then
        cache.objects[objId] = nil
    end
    Server.SaveModData()
end

function Server.RestoreLinksForController(controllerObj)
    if not controllerObj then
        return
    end
    local md = getObjectModData(controllerObj)
    local controller = (md and type(md.energyController) == "table") and md.energyController or nil
    if not controller or not controller.networkId then
        return
    end
    local cache = Server.EnsureLinkCache()
    if not cache then
        return
    end
    local entry = ensureLinkEntry(cache, controller.networkId)
    if not entry then
        return
    end

    controller.panels = controller.panels or {}
    controller.batteries = controller.batteries or {}
    controller.windTurbines = controller.windTurbines or {}
    controller.hydroTurbines = controller.hydroTurbines or {}
    controller.windBatteries = controller.windBatteries or {}

    local hasCache = hasAnyEntry(entry.panels)
        or hasAnyEntry(entry.batteries)
        or hasAnyEntry(entry.turbines)
        or hasAnyEntry(entry.hydroTurbines)
        or hasAnyEntry(entry.windBatteries)
    if hasCache then
        for panelId in pairs(entry.panels) do
            addIdToList(controller.panels, panelId)
        end
        for batteryId in pairs(entry.batteries) do
            addIdToList(controller.batteries, batteryId)
        end
        for windId in pairs(entry.turbines) do
            addIdToList(controller.windTurbines, windId)
        end
        for hydroId in pairs(entry.hydroTurbines) do
            addIdToList(controller.hydroTurbines, hydroId)
        end
        for windBatteryId in pairs(entry.windBatteries) do
            addIdToList(controller.windBatteries, windBatteryId)
        end
    else
        forEachId(controller.panels, function(panelId)
            entry.panels[panelId] = true
            cache.objects[panelId] = controller.networkId
        end)
        forEachId(controller.batteries, function(batteryId)
            entry.batteries[batteryId] = true
            cache.objects[batteryId] = controller.networkId
        end)
        forEachId(controller.windTurbines, function(windId)
            entry.turbines[windId] = true
            cache.objects[windId] = controller.networkId
        end)
        forEachId(controller.hydroTurbines, function(hydroId)
            entry.hydroTurbines[hydroId] = true
            cache.objects[hydroId] = controller.networkId
        end)
        forEachId(controller.windBatteries, function(windBatteryId)
            entry.windBatteries[windBatteryId] = true
            cache.objects[windBatteryId] = controller.networkId
        end)
        Server.SaveModData()
    end
    md.energyController = controller
    transmitObjectModData(controllerObj)
end

function Server.RestoreLinkForObject(obj, kind, objId)
    if not obj or not objId then
        return
    end
    local cache = Server.EnsureLinkCache()
    if not cache then
        return
    end
    local md = getObjectModData(obj)
    if not md then
        return
    end
    local controllerId = cache.objects[objId]
    if not controllerId then
        if kind == "panel" then
            controllerId = (md.panel and md.panel.controllerId) or (md.energyPanel and md.energyPanel.controllerId)
        elseif kind == "battery" then
            controllerId = md.energy and md.energy.controllerId
        elseif kind == "turbine" then
            controllerId = md.wind and md.wind.controllerId
        elseif kind == "hydro" then
            controllerId = md.hydro and md.hydro.controllerId
        elseif kind == "windBattery" then
            controllerId = md.windBattery and md.windBattery.controllerId
        end
        if controllerId then
            Server.RecordLink(controllerId, kind, objId)
            cache = Server.EnsureLinkCache()
            controllerId = cache and cache.objects and cache.objects[objId] or controllerId
        else
            return
        end
    end
    local controllerObj = nil
    if EnergyController and EnergyController.Server and EnergyController.Server.GetControllerById then
        controllerObj = EnergyController.Server.GetControllerById(controllerId)
    end
    if not controllerObj then
        local knownEdc = Server.GetEDCById and Server.GetEDCById(controllerId) or nil
        if not knownEdc then
            local entry = cache.controllers and cache.controllers[controllerId] or nil
            if entry then
                if kind == "panel" and entry.panels then
                    entry.panels[objId] = nil
                elseif kind == "battery" and entry.batteries then
                    entry.batteries[objId] = nil
                elseif kind == "turbine" and entry.turbines then
                    entry.turbines[objId] = nil
                elseif kind == "hydro" and entry.hydroTurbines then
                    entry.hydroTurbines[objId] = nil
                elseif kind == "windBattery" and entry.windBatteries then
                    entry.windBatteries[objId] = nil
                end
            end
            if cache.objects and cache.objects[objId] == controllerId then
                cache.objects[objId] = nil
            end
            if kind == "panel" then
                if md.panel then
                    md.panel.controllerId = nil
                end
                if md.energyPanel then
                    md.energyPanel.controllerId = nil
                end
                md.energy = md.energy or {}
                md.energy.controllerId = nil
                md.energy.connected = false
            elseif kind == "battery" then
                md.energy = md.energy or {}
                md.energy.controllerId = nil
                md.energy.connected = false
                md.energy.role = nil
            elseif kind == "turbine" then
                md.wind = md.wind or {}
                md.wind.controllerId = nil
                md.wind.connected = false
                md.energy = md.energy or {}
                md.energy.controllerId = nil
                md.energy.connected = false
            elseif kind == "hydro" then
                md.hydro = md.hydro or {}
                md.hydro.controllerId = nil
                md.hydro.connected = false
                md.energy = md.energy or {}
                md.energy.controllerId = nil
                md.energy.connected = false
            elseif kind == "windBattery" then
                md.windBattery = md.windBattery or {}
                md.windBattery.controllerId = nil
                md.windBattery.connected = false
                md.windBattery.role = nil
                md.energy = md.energy or {}
                md.energy.controllerId = nil
                md.energy.connected = false
            end
            Server.SaveModData()
            transmitObjectModData(obj)
        end
        return
    end
    if kind == "panel" then
        md.panel = md.panel or {}
        if not md.panel.controllerId then
            md.panel.controllerId = controllerId
        end
        md.energyPanel = md.energyPanel or {}
        if not md.energyPanel.controllerId then
            md.energyPanel.controllerId = controllerId
        end
        md.energy = md.energy or {}
        md.energy.type = md.energy.type or "solar"
        md.energy.controllerId = controllerId
        md.energy.connected = true
    elseif kind == "battery" then
        md.energy = md.energy or {}
        if not md.energy.controllerId then
            md.energy.controllerId = controllerId
        end
        md.energy.type = md.energy.type or "battery"
        md.energy.connected = true
    elseif kind == "turbine" then
        md.wind = md.wind or {}
        md.wind.controllerId = controllerId
        md.wind.connected = true
    elseif kind == "hydro" then
        md.hydro = md.hydro or {}
        md.hydro.controllerId = controllerId
        md.hydro.connected = true
        md.energy = md.energy or {}
        md.energy.type = "hydro"
        md.energy.controllerId = controllerId
        md.energy.connected = true
    elseif kind == "windBattery" then
        md.windBattery = md.windBattery or {}
        if not md.windBattery.controllerId then
            md.windBattery.controllerId = controllerId
        end
        md.windBattery.connected = true
    end

    if EnergyController and EnergyController.Server and EnergyController.Server.EnsureControllerForObject then
        EnergyController.Server.EnsureControllerForObject(controllerObj)
    end
    local cmd = getObjectModData(controllerObj)
    if not cmd then
        return
    end
    cmd.energyController = cmd.energyController or {
        networkId = controllerId,
        panels = {},
        batteries = {},
        windTurbines = {},
        hydroTurbines = {},
        windBatteries = {},
    }
    if kind == "panel" then
        cmd.energyController.panels = addIdToList(cmd.energyController.panels or {}, objId)
    elseif kind == "battery" then
        cmd.energyController.batteries = addIdToList(cmd.energyController.batteries or {}, objId)
    elseif kind == "turbine" then
        cmd.energyController.windTurbines = addIdToList(cmd.energyController.windTurbines or {}, objId)
    elseif kind == "hydro" then
        cmd.energyController.hydroTurbines = addIdToList(cmd.energyController.hydroTurbines or {}, objId)
    elseif kind == "windBattery" then
        cmd.energyController.windBatteries = addIdToList(cmd.energyController.windBatteries or {}, objId)
    end
    transmitObjectModData(controllerObj)

    transmitObjectModData(obj)
end

function Server.MergeLinksFromController(controller)
    if not controller or not controller.networkId then
        return
    end
    local cache = Server.EnsureLinkCache()
    if not cache then
        return
    end
    local entry = ensureLinkEntry(cache, controller.networkId)
    local changed = false
    forEachId(controller.panels, function(panelId)
        if not entry.panels[panelId] then
            entry.panels[panelId] = true
            cache.objects[panelId] = controller.networkId
            changed = true
        end
    end)
    forEachId(controller.batteries, function(batteryId)
        if not entry.batteries[batteryId] then
            entry.batteries[batteryId] = true
            cache.objects[batteryId] = controller.networkId
            changed = true
        end
    end)
    forEachId(controller.windTurbines, function(windId)
        if not entry.turbines[windId] then
            entry.turbines[windId] = true
            cache.objects[windId] = controller.networkId
            changed = true
        end
    end)
    forEachId(controller.hydroTurbines, function(hydroId)
        if not entry.hydroTurbines[hydroId] then
            entry.hydroTurbines[hydroId] = true
            cache.objects[hydroId] = controller.networkId
            changed = true
        end
    end)
    forEachId(controller.windBatteries, function(windBatteryId)
        if not entry.windBatteries[windBatteryId] then
            entry.windBatteries[windBatteryId] = true
            cache.objects[windBatteryId] = controller.networkId
            changed = true
        end
    end)
    if changed then
        Server.SaveModData()
    end
end

function Server.SaveModData()
    if not Server.modData then
        Server.modData = ModData.getOrCreate("EnergyRouting")
    end
    Server.modData.edcs = Server.edcs
    ModData.transmit("EnergyRouting")
end

function Server.IsEDCObject(obj)
    local md = getObjectModData(obj)
    return md and md.EnergyRoutingEDC == true
end

function Server.RegisterEDC(square, creator, forcedId)
    if not square then
        return nil
    end
    local edcId = forcedId or Server.MakeEDCId(square:getX(), square:getY(), square:getZ())
    local entry = Server.edcs[edcId]
    if not entry then
        entry = {
            id = edcId,
            x = square:getX(),
            y = square:getY(),
            z = square:getZ(),
            mode = "Balanced",
            outputEnabled = true,
            toggles = EnergyRouting.MakeDefaultToggles(),
            groupStates = {},
            energyAvailable = 0,
            production = 0,
            storage = 0,
            weather = "Unknown",
            batteries = {},
            lastConsumerScanTime = -1,
            consumerCache = {},
            totalConsumptionRate = 0,
            scanIntervalHours = getConfiguredScanIntervalHours(),
            isDirty = true,
            lastSentEnergy = -1,
            syncThreshold = getConfiguredSyncThreshold(),
        }
        Server.edcs[edcId] = entry
    else
        entry.x = square:getX()
        entry.y = square:getY()
        entry.z = square:getZ()
        entry.toggles = entry.toggles or EnergyRouting.MakeDefaultToggles()
        entry.groupStates = entry.groupStates or {}
        entry.mode = entry.mode or "Balanced"
        if entry.outputEnabled == nil then
            entry.outputEnabled = true
        end
    end
    Server.EnsureEDCOptimizationState(entry, entry.consumerCache == nil or entry._lastScannedGroups == nil)

    local sqMd = square:getModData()
    sqMd.EnergyRoutingEDCId = edcId
    if square.transmitModData then
        square:transmitModData()
    end

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if Server.IsEDCObject(obj) then
            local objMd = getObjectModData(obj)
            if objMd then
                objMd.EnergyRoutingEDCId = edcId
                syncEdcConfigWithController(entry, obj)
                transmitObjectModData(obj)
            end
        end
    end

    Server.SaveModData()
    return entry
end

function Server.GetEDCById(edcId)
    edcId = Server.NormalizeEDCId(edcId)
    return edcId and Server.edcs[edcId] or nil
end

function Server.RemoveEDC(edcId)
    if not edcId then
        return
    end
    edcId = Server.NormalizeEDCId(edcId)
    local edc = Server.edcs[edcId]
    if edc then
        local square = getCell() and getCell():getGridSquare(edc.x, edc.y, edc.z) or nil
        if square then
            local md = square:getModData()
            if md and md.EnergyRoutingEDCId == edcId then
                md.EnergyRoutingEDCId = nil
                if square.transmitModData then
                    square:transmitModData()
                end
            end
        end
    end
    Server.edcs[edcId] = nil
    local cache = Server.EnsureLinkCache and Server.EnsureLinkCache() or nil
    if cache and type(cache.controllers) == "table" then
        local entry = cache.controllers[edcId]
        if type(entry) == "table" then
            local function clearBucket(bucket)
                if type(bucket) ~= "table" then
                    return
                end
                for objId in pairs(bucket) do
                    if cache.objects and cache.objects[objId] == edcId then
                        cache.objects[objId] = nil
                    end
                end
            end
            clearBucket(entry.panels)
            clearBucket(entry.batteries)
            clearBucket(entry.turbines)
            clearBucket(entry.hydroTurbines)
            clearBucket(entry.windBatteries)
        end
        cache.controllers[edcId] = nil
    end
    Server.SaveModData()
end

function Server.GetEDCBySquare(square)
    if not square then
        return nil
    end
    local md = square:getModData()
    if md and md.EnergyRoutingEDCId then
        return Server.edcs[md.EnergyRoutingEDCId]
    end
    return nil
end

local function countUnique(list)
    local count = 0
    local seen = {}
    if not list then return 0 end
    for k, v in pairs(list) do
        if type(k) == "string" then
            if not seen[k] then seen[k] = true; count = count + 1 end
        elseif type(v) == "string" then
            if not seen[v] then seen[v] = true; count = count + 1 end
        end
    end
    return count
end

local function normalizeEdcBatteries(edc)
    if not edc then
        return
    end
    if not edc.batteries then
        edc.batteries = {}
        return
    end
    local normalized = {}
    for _, entry in ipairs(edc.batteries) do
        if type(entry) == "string" then
            table.insert(normalized, { id = entry, role = nil })
        elseif type(entry) == "table" and entry.id then
            table.insert(normalized, entry)
        end
    end
    edc.batteries = normalized
end

local function ensureMasterBattery(edc)
    if not edc or not edc.batteries or #edc.batteries == 0 then
        return nil
    end
    for _, entry in ipairs(edc.batteries) do
        if entry.role == "master" then
            return entry.id
        end
    end
    edc.batteries[1].role = "master"
    return edc.batteries[1].id
end

local function normalizeBatteryRoles(edc)
    if not edc or not edc.batteries then
        return nil
    end
    local masterId = ensureMasterBattery(edc)
    for _, entry in ipairs(edc.batteries) do
        if entry.id ~= masterId then
            entry.role = "slave"
        end
    end
    return masterId
end

function Server.GetEnergySnapshot(edc)
    local snapshot = {
        available = 0,
        production = 0,
        storage = 0,
        capacity = 0,
        totalCapacity = 0,
        solarCapacity = 0,
        windCapacity = 0,
        hydroProduction = 0,
        hydroCount = 0,
        otherProduction = 0,
        otherCount = 0,
        weather = "Unknown",
    }
    local providerSnapshot = nil
    local edcId = edc and edc.id or nil
    if type(edcId) == "string" then
        if string.find(edcId, "^network_") and EnergyController and EnergyController.Server
            and EnergyController.Server.GetSnapshotForEDC then
            local ok, result = pcall(EnergyController.Server.GetSnapshotForEDC, edc)
            if ok and result then
                providerSnapshot = result
            end
        elseif string.find(edcId, "^energy_net_") and EnergyNetwork and EnergyNetwork.Server
            and EnergyNetwork.Server.GetSnapshotForEDC then
            local ok, result = pcall(EnergyNetwork.Server.GetSnapshotForEDC, edc)
            if ok and result then
                providerSnapshot = result
            end
        end
    end

    if providerSnapshot then
        snapshot.available = providerSnapshot.available or snapshot.available
        snapshot.production = providerSnapshot.production or snapshot.production
        snapshot.storage = providerSnapshot.storage or snapshot.storage
        snapshot.weather = providerSnapshot.weather or snapshot.weather
        snapshot.solarProduction = providerSnapshot.solarProduction
        snapshot.windProduction = providerSnapshot.windProduction
        snapshot.hydroProduction = providerSnapshot.hydroProduction
        snapshot.otherProduction = providerSnapshot.otherProduction
        snapshot.solarStorage = providerSnapshot.solarStorage
        snapshot.windStorage = providerSnapshot.windStorage
        snapshot.capacity = providerSnapshot.capacity or providerSnapshot.totalCapacity
        snapshot.totalCapacity = providerSnapshot.totalCapacity or providerSnapshot.capacity
        snapshot.solarCapacity = providerSnapshot.solarCapacity
        snapshot.windCapacity = providerSnapshot.windCapacity
        snapshot.panelCount = providerSnapshot.panelCount
        snapshot.batteryCount = providerSnapshot.batteryCount
        snapshot.windCount = providerSnapshot.windCount
        snapshot.hydroCount = providerSnapshot.hydroCount
        snapshot.otherCount = providerSnapshot.otherCount
        snapshot.windBatteryCount = providerSnapshot.windBatteryCount
        snapshot.solarBonusPercent = providerSnapshot.solarBonusPercent
        snapshot.windBonusPercent = providerSnapshot.windBonusPercent
    end

    local providers = Server.energyProviders
    if not providerSnapshot and (not providers or #providers == 0) and Server.energyProvider then
        providers = { Server.energyProvider }
    end
    if not providerSnapshot and providers and #providers > 0 then
        local lastResult = nil
        for _, provider in ipairs(providers) do
            local ok, result = pcall(provider, edc)
            if ok and result then
                lastResult = result
                local weather = result.weather
                if weather ~= "No Network" and weather ~= "Offline" then
                    providerSnapshot = result
                    break
                end
            end
        end
        if not providerSnapshot and lastResult then
            providerSnapshot = lastResult
        end
        if providerSnapshot then
            snapshot.available = providerSnapshot.available or snapshot.available
            snapshot.production = providerSnapshot.production or snapshot.production
            snapshot.storage = providerSnapshot.storage or snapshot.storage
            snapshot.weather = providerSnapshot.weather or snapshot.weather
            snapshot.solarProduction = providerSnapshot.solarProduction
            snapshot.windProduction = providerSnapshot.windProduction
            snapshot.hydroProduction = providerSnapshot.hydroProduction
            snapshot.otherProduction = providerSnapshot.otherProduction
            snapshot.solarStorage = providerSnapshot.solarStorage
            snapshot.windStorage = providerSnapshot.windStorage
            snapshot.capacity = providerSnapshot.capacity or providerSnapshot.totalCapacity
            snapshot.totalCapacity = providerSnapshot.totalCapacity or providerSnapshot.capacity
            snapshot.solarCapacity = providerSnapshot.solarCapacity
            snapshot.windCapacity = providerSnapshot.windCapacity
            snapshot.panelCount = providerSnapshot.panelCount
            snapshot.batteryCount = providerSnapshot.batteryCount
            snapshot.windCount = providerSnapshot.windCount
            snapshot.hydroCount = providerSnapshot.hydroCount
            snapshot.otherCount = providerSnapshot.otherCount
            snapshot.windBatteryCount = providerSnapshot.windBatteryCount
            snapshot.solarBonusPercent = providerSnapshot.solarBonusPercent
            snapshot.windBonusPercent = providerSnapshot.windBonusPercent
        end
    end

    local weatherSnapshot = EnergyRouting.Weather.GetWeatherSnapshot()
    if snapshot.weather == "Unknown" then
        snapshot.weather = weatherSnapshot.label
    end

    if not providerSnapshot or not providerSnapshot.weatherApplied then
        snapshot.production = snapshot.production * (weatherSnapshot.multiplier or 1.0)
    end

    if EnergyController and EnergyController.Server and EnergyController.Server.GetControllerById then
        local controllerObj = EnergyController.Server.GetControllerById(edc.id)
        if controllerObj then
            local md = getObjectModData(controllerObj)
            local controller = (md and type(md.energyController) == "table") and md.energyController or nil
            if controller then
                snapshot.panelCount = countUnique(controller.panels)
                snapshot.batteryCount = countUnique(controller.batteries)
                snapshot.windCount = countUnique(controller.windTurbines)
                snapshot.hydroCount = countUnique(controller.hydroTurbines)
                snapshot.windBatteryCount = countUnique(controller.windBatteries)
                snapshot.otherCount = tonumber(controller.otherCount) or snapshot.otherCount or 0
                snapshot.solarBonusPercent = tonumber(controller.solarBonusPercent) or 0
                snapshot.windBonusPercent = tonumber(controller.windBonusPercent) or 0
                snapshot.hydroProduction = tonumber(controller.hydroProduction) or snapshot.hydroProduction or 0
                snapshot.otherProduction = tonumber(controller.otherProduction) or snapshot.otherProduction or 0
                snapshot.totalCapacity = tonumber(controller.totalCapacity) or snapshot.totalCapacity or 0
                snapshot.capacity = snapshot.totalCapacity
                snapshot.windCapacity = tonumber(controller.windCapacity) or snapshot.windCapacity or 0
                if (snapshot.solarCapacity or 0) <= 0 and (snapshot.totalCapacity or 0) > 0 then
                    snapshot.solarCapacity = math.max(0, (snapshot.totalCapacity or 0) - (snapshot.windCapacity or 0))
                end
            end
        end
    end

    snapshot.masterBatteryId = nil
    snapshot.slaveCount = 0
    if edc then
        normalizeEdcBatteries(edc)
        local masterId = normalizeBatteryRoles(edc)
        snapshot.masterBatteryId = masterId
        for _, entry in ipairs(edc.batteries or {}) do
            if entry.role == "slave" then
                snapshot.slaveCount = snapshot.slaveCount + 1
            end
        end
    end

    return snapshot
end

function EnergyRouting.RegisterEnergyProvider(providerFn)
    if type(providerFn) ~= "function" then
        return
    end
    Server.energyProviders = Server.energyProviders or {}
    table.insert(Server.energyProviders, providerFn)
    Server.energyProvider = providerFn
end

function EnergyRouting.RegisterEnergyConsumer(consumerFn)
    if type(consumerFn) ~= "function" then
        return
    end
    Server.energyConsumers = Server.energyConsumers or {}
    table.insert(Server.energyConsumers, consumerFn)
    Server.energyConsumer = consumerFn
end

function Server.GetDevicePowerUsage(obj)
    local power = safeCall(obj, "getPower")
    if type(power) ~= "number" or power <= 0 then
        power = safeCall(obj, "getPowerUsage")
    end
    if type(power) ~= "number" or power <= 0 then
        power = safeCall(obj, "getPowerUsageBase")
    end
    power = tonumber(power) or 0

    local md = getObjectModData(obj)
    local mdWatts = md and tonumber(md.EnergyRoutingConsumption) or nil
    local groupId = Server.ClassifyDevice(obj)

    if power > 0 then
        return normalizeWattsForGroup(groupId, power)
    end

    if mdWatts and mdWatts > 0 then
        return normalizeWattsForGroup(groupId, mdWatts)
    end

    if groupId then
        return normalizeWattsForGroup(groupId, getDefaultWattsForGroup(groupId))
    end

    return 1
end

function Server.IsElectricDevice(obj)
    if not obj then
        return false
    end
    if Server.IsEDCObject(obj) then
        return false
    end
    if isInstanceOf(obj, "IsoGenerator") then
        return false
    end
    if isBatteryRadioObject(obj) then
        return false
    end
    if isExplicitlyExcludedConsumerObject(obj) then
        return false
    end

    if isInstanceOf(obj, "IsoLightSwitch")
        or isInstanceOf(obj, "IsoStove")
        or isInstanceOf(obj, "IsoTelevision")
        or isInstanceOf(obj, "IsoCarBatteryCharger")
        or isInstanceOf(obj, "IsoClothingWasher")
        or isInstanceOf(obj, "IsoClothingDryer")
        or isInstanceOf(obj, "IsoCombinationWasherDryer")
        or isInstanceOf(obj, "IsoStackedWasherDryer") then
        return true
    end

    if hasContainerType(obj, "fridge")
        or hasContainerType(obj, "freezer")
        or hasContainerType(obj, "stove")
        or hasContainerType(obj, "microwave")
        or hasContainerType(obj, "oven") then
        return true
    end

    if safeCall(obj, "getPower") or safeCall(obj, "getPowerUsage") then
        return true
    end

    local props = safeCall(obj, "getProperties")
    if hasPropertyFlag(props, "electricity")
        or hasPropertyFlag(props, "Electricity")
        or hasPropertyFlag(props, "HasLightOnSprite")
        or hasPropertyFlag(props, "TV")
        or hasPropertyFlag(props, "Microwave")
        or hasPropertyFlag(props, "IsFridge")
        or propertyContains(props, "IsoType", "IsoTelevision")
        or propertyContains(props, "IsoType", "IsoStove")
        or propertyContains(props, "AmbientSound", "LightBulbAmbiance")
        or propertyContains(props, "AmbientSound", "ClockAmbiance")
        or propertyContains(props, "Material", "Electric")
        or propertyContains(props, "Material2", "Electric")
        or propertyContains(props, "Material3", "Electric")
        or propertyContains(props, "container", "fridge")
        or propertyContains(props, "container", "freezer")
        or propertyContains(props, "container", "stove")
        or propertyContains(props, "container", "microwave")
        or propertyContains(props, "container", "oven")
        or propertyContains(props, "signal", "tv") then
        return true
    end

    if obj.getLight or obj.isLight or obj.isLightSwitch then
        return true
    end

    local probe = getObjectClassificationProbe(obj)
    if inferGroupFromProbe(probe) ~= nil then
        return true
    end

    return false
end

function Server.ClassifyDevice(obj)
    if not obj then
        return nil
    end
    if isBatteryRadioObject(obj) then
        return nil
    end
    if isExplicitlyExcludedConsumerObject(obj) then
        return nil
    end

    local props = safeCall(obj, "getProperties")
    if hasPropertyFlag(props, "IsFridge")
        or propertyContains(props, "container", "fridge")
        or propertyContains(props, "container", "freezer")
        or hasContainerType(obj, "fridge")
        or hasContainerType(obj, "freezer") then
        return "refrigeration"
    end

    if isInstanceOf(obj, "IsoLightSwitch") or obj.getLight or obj.isLight or obj.isLightSwitch then
        return "lights"
    end
    if isInstanceOf(obj, "IsoStove") then
        return "cooking"
    end
    if isInstanceOf(obj, "IsoTelevision") or isInstanceOf(obj, "IsoRadio") then
        return "entertainment"
    end

    if hasPropertyFlag(props, "HasLightOnSprite")
        or propertyContains(props, "AmbientSound", "LightBulbAmbiance") then
        return "lights"
    end
    if hasPropertyFlag(props, "Microwave")
        or propertyContains(props, "IsoType", "IsoStove")
        or propertyContains(props, "container", "stove")
        or propertyContains(props, "container", "microwave")
        or propertyContains(props, "container", "oven") then
        return "cooking"
    end
    if hasPropertyFlag(props, "TV")
        or propertyContains(props, "IsoType", "IsoTelevision")
        or propertyContains(props, "signal", "tv")
        or propertyContains(props, "AmbientSound", "ClockAmbiance") then
        return "entertainment"
    end

    local md = safeCall(obj, "getModData")
    if md and md.EnergyRoutingGroup then
        local normalizedMd = normalizeGroupId(md.EnergyRoutingGroup)
        if normalizedMd then
            return normalizedMd
        end
    end

    if hasContainerType(obj, "fridge") or hasContainerType(obj, "freezer") then
        return "refrigeration"
    end
    if hasContainerType(obj, "stove")
        or hasContainerType(obj, "microwave")
        or hasContainerType(obj, "oven") then
        return "cooking"
    end

    local name = safeCall(obj, "getName")
    local objectName = safeCall(obj, "getObjectName")
    local spriteName = nil
    local sprite = safeCall(obj, "getSprite")
    if sprite then
        spriteName = safeCall(sprite, "getName")
    end
    local item = safeCall(obj, "getItem") or safeCall(obj, "getInventoryItem")
    local itemType = item and safeCall(item, "getFullType") or nil

    local registered = EnergyRouting.GetRegisteredGroup(name)
        or EnergyRouting.GetRegisteredGroup(objectName)
        or EnergyRouting.GetRegisteredGroup(spriteName)
        or EnergyRouting.GetRegisteredGroup(itemType)

    if registered then
        return normalizeGroupId(registered) or registered
    end

    local probe = getObjectClassificationProbe(obj)
    local inferred = inferGroupFromProbe(probe)
    if inferred then
        return normalizeGroupId(inferred) or inferred
    end
    return nil
end

function Server.SetDevicePowered(obj, powered)
    if not obj then
        return
    end

    local md = safeCall(obj, "getModData")
    if powered then
        if md then
            if md.EnergyRoutingWasOn ~= nil then
                powered = md.EnergyRoutingWasOn
                md.EnergyRoutingWasOn = nil
            end
            md.EnergyRoutingForcedOff = false
        end
    else
        if md and md.EnergyRoutingWasOn == nil then
            local wasOn = safeCall(obj, "isActivated")
            if wasOn == nil then
                wasOn = safeCall(obj, "isActive")
            end
            if wasOn == nil then
                wasOn = safeCall(obj, "isTurnedOn")
            end
            md.EnergyRoutingWasOn = wasOn
        end
        if md then
            md.EnergyRoutingForcedOff = true
        end
    end

    local setSuccess = false
    if obj.setPowered then
        setSuccess = pcall(obj.setPowered, obj, powered)
    end
    if not setSuccess and obj.setActivated then
        setSuccess = pcall(obj.setActivated, obj, powered)
    end
    if not setSuccess and obj.setActive then
        setSuccess = pcall(obj.setActive, obj, powered)
    end
    if not setSuccess and obj.setIsTurnedOn then
        setSuccess = pcall(obj.setIsTurnedOn, obj, powered)
    end
    if not setSuccess and obj.setTurnedOn then
        setSuccess = pcall(obj.setTurnedOn, obj, powered)
    end
    if not setSuccess and obj.switchLight then
        setSuccess = pcall(obj.switchLight, obj, powered)
        if not setSuccess then
            local current = safeCall(obj, "isActivated")
            if current == nil then
                current = safeCall(obj, "isActive")
            end
            if current == nil then
                current = safeCall(obj, "isTurnedOn")
            end
            current = (current == true)
            if current ~= powered then
                local toggled = pcall(obj.switchLight, obj)
                if toggled then
                    local after = safeCall(obj, "isActivated")
                    if after == nil then
                        after = safeCall(obj, "isActive")
                    end
                    if after == nil then
                        after = safeCall(obj, "isTurnedOn")
                    end
                    setSuccess = (after == true) == (powered == true)
                end
            end
        end
    end

    if md and obj.transmitModData then
        obj:transmitModData()
    end
end

local function getSquareElectricityState(sq)
    if not sq then
        return nil
    end
    local state = safeCall(sq, "hasElectricity")
    if state == nil then
        state = safeCall(sq, "haveElectricity")
    end
    if state == nil then
        state = safeCall(sq, "isElectricity")
    end
    if state == nil then
        return nil
    end
    return state == true
end

local function setSquareElectricityState(sq, powered)
    if not sq then
        return false
    end
    local current = getSquareElectricityState(sq)
    if current ~= nil and current == (powered == true) then
        return false
    end
    if sq.setHaveElectricity then
        pcall(sq.setHaveElectricity, sq, powered)
    end
    if sq.setHasElectricity then
        pcall(sq.setHasElectricity, sq, powered)
    end
    if sq.setElectricity then
        pcall(sq.setElectricity, sq, powered)
    end
    return true
end

local function setObjectSquareElectricity(obj, powered)
    if not obj then
        return
    end
    local sq = safeCall(obj, "getSquare")
    if not sq then
        return
    end
    setSquareElectricityState(sq, powered)
end

local function setSquareElectricityByCoords(x, y, z, powered)
    local cell = getCell and getCell() or nil
    if not cell then
        return
    end
    local sq = cell:getGridSquare(x, y, z)
    if not sq then
        return
    end
    setSquareElectricityState(sq, powered)
end

local function setLightRoomElectricity(obj, powered)
    if not obj then
        return
    end
    local sq = safeCall(obj, "getSquare")
    if not sq then
        return
    end

    local room = safeCall(sq, "getRoom")
    if not room then
        setObjectSquareElectricity(obj, powered)
        return
    end

    local squares = safeCall(room, "getSquares")
    if not squares then
        setObjectSquareElectricity(obj, powered)
        return
    end

    for i = 0, squares:size() - 1 do
        local roomSq = squares:get(i)
        if roomSq then
            local x = safeCall(roomSq, "getX")
            local y = safeCall(roomSq, "getY")
            local z = safeCall(roomSq, "getZ")
            if x and y and z then
                setSquareElectricityByCoords(x, y, z, powered)
            end
        end
    end
end

local function setConsumerSquarePower(obj, powered)
    if not obj then
        return
    end

    local sq = safeCall(obj, "getSquare")
    if not sq then
        return
    end

    local sx = tonumber(safeCall(sq, "getX"))
    local sy = tonumber(safeCall(sq, "getY"))
    local sz = tonumber(safeCall(sq, "getZ"))
    if sx == nil or sy == nil or sz == nil then
        setObjectSquareElectricity(obj, powered)
        return
    end

    sx = math.floor(sx)
    sy = math.floor(sy)
    sz = math.floor(sz)

    Server._squarePowerRefs = Server._squarePowerRefs or {}
    Server._objectSquarePowerFlags = Server._objectSquarePowerFlags or {}
    local refs = Server._squarePowerRefs
    local objFlags = Server._objectSquarePowerFlags
    local key = tostring(sx) .. ":" .. tostring(sy) .. ":" .. tostring(sz)
    local objKey = tostring(obj)
    local md = safeCall(obj, "getModData")
    local wasMarkedPowered = false
    if md and md.EnergyRoutingSquarePowered ~= nil then
        wasMarkedPowered = (md.EnergyRoutingSquarePowered == true)
    else
        wasMarkedPowered = (objFlags[objKey] == true)
    end

    if powered then
        if wasMarkedPowered and (tonumber(refs[key]) or 0) > 0 then
            return
        end
        refs[key] = (tonumber(refs[key]) or 0) + 1
        setObjectSquareElectricity(obj, true)
        if md then
            md.EnergyRoutingSquarePowered = true
        else
            objFlags[objKey] = true
        end
        return
    end

    if not wasMarkedPowered then
        return
    end

    local nextCount = (tonumber(refs[key]) or 0) - 1
    if nextCount <= 0 then
        refs[key] = nil
        setObjectSquareElectricity(obj, false)
    else
        refs[key] = nextCount
    end
    if md then
        md.EnergyRoutingSquarePowered = false
    else
        objFlags[objKey] = false
    end
end

local function getObjectPowerState(obj)
    if not obj then
        return false
    end
    local state = safeCall(obj, "isActivated")
    if state == nil then
        state = safeCall(obj, "isActive")
    end
    if state == nil then
        state = safeCall(obj, "isTurnedOn")
    end
    if state == nil then
        state = safeCall(obj, "isPowered")
    end
    return state == true
end

local function setObjectPowerState(obj, powered)
    if not obj then
        return false
    end
    local desired = (powered == true)
    local current = getObjectPowerState(obj)
    if current == desired then
        return false
    end

    local setSuccess = false
    if obj.setPowered then
        setSuccess = pcall(obj.setPowered, obj, powered)
    end
    if not setSuccess and obj.setActivated then
        setSuccess = pcall(obj.setActivated, obj, powered)
    end
    if not setSuccess and obj.setActive then
        setSuccess = pcall(obj.setActive, obj, powered)
    end
    if not setSuccess and obj.setIsTurnedOn then
        setSuccess = pcall(obj.setIsTurnedOn, obj, powered)
    end
    if not setSuccess and obj.setTurnedOn then
        setSuccess = pcall(obj.setTurnedOn, obj, powered)
    end
    if not setSuccess and obj.switchLight then
        setSuccess = pcall(obj.switchLight, obj, powered)
        if not setSuccess then
            local current = safeCall(obj, "isActivated")
            if current == nil then
                current = safeCall(obj, "isActive")
            end
            if current == nil then
                current = safeCall(obj, "isTurnedOn")
            end
            current = (current == true)
            if current ~= desired then
                local toggled = pcall(obj.switchLight, obj)
                if toggled then
                    local after = safeCall(obj, "isActivated")
                    if after == nil then
                        after = safeCall(obj, "isActive")
                    end
                    if after == nil then
                        after = safeCall(obj, "isTurnedOn")
                    end
                    setSuccess = (after == true) == desired
                end
            end
        end
    end
    return setSuccess
end

local function forceObjectHardOff(obj)
    local function forceTargetState(target, powered)
        if not target then
            return
        end
        local desired = (powered == true)
        local current = getObjectPowerState(target)
        if current == desired then
            return
        end
        if target.setPowered then
            pcall(target.setPowered, target, powered)
        end
        if target.setActivated then
            pcall(target.setActivated, target, powered)
        end
        if target.setActive then
            pcall(target.setActive, target, powered)
        end
        if target.setIsTurnedOn then
            pcall(target.setIsTurnedOn, target, powered)
        end
        if target.setTurnedOn then
            pcall(target.setTurnedOn, target, powered)
        end
    end

    if not obj then
        return
    end

    forceTargetState(obj, false)
    forceTargetState(getObjectInventoryItem(obj), false)

    if obj.switchLight and getObjectPowerState(obj) then
        local ok = pcall(obj.switchLight, obj, false)
        if not ok and getObjectPowerState(obj) then
            pcall(obj.switchLight, obj)
        end
    end
end

local function forceObjectHardOn(obj)
    if not obj then
        return
    end

    local function forceTargetState(target, powered)
        if not target then
            return
        end
        local desired = (powered == true)
        local current = getObjectPowerState(target)
        if current == desired then
            return
        end
        if target.setPowered then
            pcall(target.setPowered, target, powered)
        end
        if target.setActivated then
            pcall(target.setActivated, target, powered)
        end
        if target.setActive then
            pcall(target.setActive, target, powered)
        end
        if target.setIsTurnedOn then
            pcall(target.setIsTurnedOn, target, powered)
        end
        if target.setTurnedOn then
            pcall(target.setTurnedOn, target, powered)
        end
    end

    forceTargetState(obj, true)
    forceTargetState(getObjectInventoryItem(obj), true)
end

local function isRefrigerationLikeObject(obj)
    if not obj then
        return false
    end

    local item = getObjectInventoryItem(obj)
    if item then
        local fullType = lowerText(safeCall(item, "getFullType"))
        local itemName = lowerText(safeCall(item, "getDisplayName")) or lowerText(safeCall(item, "getName"))
        if textHasRefrigerationToken(fullType) or textHasRefrigerationToken(itemName) then
            return true
        end
    end

    local props = safeCall(obj, "getProperties")
    if hasPropertyFlag(props, "IsFridge")
        or propertyContains(props, "container", "fridge")
        or propertyContains(props, "container", "freezer") then
        return true
    end

    if hasContainerType(obj, "fridge") or hasContainerType(obj, "freezer") then
        return true
    end

    local probe = getObjectClassificationProbe(obj)
    return inferGroupFromProbe(probe) == "refrigeration" or textHasRefrigerationToken(probe)
end

local function setObjectPoweredCapability(obj, powered)
    if not obj then
        return false
    end
    local changed = false
    local function setOnTarget(target)
        if not target then
            return false
        end
        local current = safeCall(target, "isPowered")
        if current ~= nil and (current == true) == (powered == true) then
            return false
        end
        if target.setPowered then
            pcall(target.setPowered, target, powered)
            return true
        end
        return false
    end
    changed = setOnTarget(obj) or changed
    changed = setOnTarget(getObjectInventoryItem(obj)) or changed
    return changed
end

local function getContainerPowerState(container)
    if not container then
        return nil
    end
    local state = safeCall(container, "isPowered")
    if state == nil then
        state = safeCall(container, "getPowered")
    end
    if state == nil then
        state = safeCall(container, "isHasElectricity")
    end
    if state == nil then
        state = safeCall(container, "hasElectricity")
    end
    if state == nil then
        return nil
    end
    return state == true
end

local function setObjectContainerPowered(obj, powered)
    if not obj then
        return false
    end

    local changed = false
    local seen = {}
    local function apply(container)
        if not container then
            return
        end
        local key = tostring(container)
        if seen[key] then
            return
        end
        seen[key] = true
        local current = getContainerPowerState(container)
        if current ~= nil and current == (powered == true) then
            return
        end
        changed = true
        if container.setPowered then
            pcall(container.setPowered, container, powered)
        end
        if container.setIsPowered then
            pcall(container.setIsPowered, container, powered)
        end
        if container.setHaveElectricity then
            pcall(container.setHaveElectricity, container, powered)
        end
        if container.setHasElectricity then
            pcall(container.setHasElectricity, container, powered)
        end
    end

    apply(safeCall(obj, "getContainer"))
    local item = getObjectInventoryItem(obj)
    apply(item and safeCall(item, "getContainer") or nil)
    if obj.getContainerByType then
        apply(safeCall(obj, "getContainerByType", "fridge"))
        apply(safeCall(obj, "getContainerByType", "freezer"))
        apply(safeCall(obj, "getContainerByType", "refrigerator"))
    end
    local count = safeCall(obj, "getContainerCount")
    if type(count) == "number" and count > 0 and obj.getContainerByIndex then
        for i = 0, count - 1 do
            apply(safeCall(obj, "getContainerByIndex", i))
        end
    end
    return changed
end

local function resolveConsumerObjectAndGroup(consumer)
    local obj = consumer and (consumer.object or consumer) or nil
    if not obj then
        return nil, nil
    end

    local groupId = normalizeGroupId(consumer and consumer.group or nil)
    if not groupId then
        groupId = normalizeGroupId(Server.ClassifyDevice(obj))
    end
    if groupId == "kitchen" then
        groupId = "cooking"
    end
    return obj, groupId
end

local function applyConsumerPowerState(consumer, powered)
    local obj, groupId = resolveConsumerObjectAndGroup(consumer)
    if not obj or not groupId then return end

    local md = getObjectModData(obj)
    local mdChanged = false

    if not powered then
        if md and md.EnergyRoutingForcedOff ~= true then
            mdChanged = setModDataField(md, "EnergyRoutingWasOn", getObjectPowerState(obj)) or mdChanged
        end

        if groupId == "refrigeration" then
            setObjectContainerPowered(obj, false)
            -- Fridges can re-arm from square electricity; force the hosting square OFF too.
            setObjectSquareElectricity(obj, false)
        elseif groupId == "lights" then
            -- Cut room power for this switch while lights group is disabled.
            setLightRoomElectricity(obj, false)
        elseif groupId == "cooking" then
            -- Remove local square power feed for kitchen devices.
            setConsumerSquarePower(obj, false)
        end

        -- Hard-off by object. This runs repeatedly so user UI cannot keep it ON.
        if groupId == "lights" then
            forceObjectHardOff(obj)
        elseif groupId == "refrigeration" then
            if getObjectPowerState(obj) then
                forceObjectHardOff(obj)
            end
        else
            setObjectPoweredCapability(obj, false)
            setObjectPowerState(obj, false)
        end

        if md then
            mdChanged = setModDataField(md, "EnergyRoutingForcedOff", true) or mdChanged
            mdChanged = setModDataField(md, "EnergyRoutingGroupForcedOff", true) or mdChanged
            mdChanged = setModDataField(md, "EnergyRoutingIndustrialBlocked", (groupId == "industrial")) or mdChanged
        end

    else
        -- Group ON: release forced-off state and restore required powered capabilities.
        setObjectPoweredCapability(obj, true)

        if groupId == "refrigeration" then
            setObjectContainerPowered(obj, true)
            -- Restore square electricity for refrigeration objects when the group is enabled.
            setObjectSquareElectricity(obj, true)

            -- Refrigeration must run whenever its group is powered.
            if not getObjectPowerState(obj) then
                forceObjectHardOn(obj)
                setObjectPowerState(obj, true)
            end
        elseif groupId == "lights" then
            -- Restore room electricity when lights group is enabled.
            setLightRoomElectricity(obj, true)
        elseif groupId == "cooking" then
            -- Provide local square power for stoves/microwaves without energizing the full building bus.
            setConsumerSquarePower(obj, true)
        end

        if md then
            mdChanged = setModDataField(md, "EnergyRoutingWasOn", nil) or mdChanged
            mdChanged = setModDataField(md, "EnergyRoutingForcedOff", false) or mdChanged
            mdChanged = setModDataField(md, "EnergyRoutingGroupForcedOff", false) or mdChanged
            mdChanged = setModDataField(md, "EnergyRoutingIndustrialBlocked", false) or mdChanged
        end
    end

    if md and mdChanged then
        transmitObjectModData(obj)
    end
end

local function addRefrigerationCacheObject(cache, seen, obj)
    if not cache or not seen or not obj then
        return
    end
    local key = tostring(obj)
    if seen[key] then
        return
    end
    if not isRefrigerationLikeObject(obj) then
        return
    end
    seen[key] = true
    cache[#cache + 1] = obj
end

local function refreshRefrigerationObjectCache(edc, groups, forceRefresh)
    if not edc then
        return {}
    end

    local nowMinutes = getWorldMinutes()
    local last = tonumber(edc._refrigerationObjectCacheAt) or -1
    local cache = edc._refrigerationObjectCache
    if not forceRefresh and cache and (nowMinutes - last) < REFRIGERATION_CACHE_REFRESH_MINUTES then
        return cache
    end

    local rebuilt = {}
    local seen = {}

    for _, groupData in pairs(groups or {}) do
        for _, consumer in ipairs((groupData and groupData.devices) or {}) do
            local obj = consumer and (consumer.object or consumer) or nil
            addRefrigerationCacheObject(rebuilt, seen, obj)
        end
    end

    local doDeepScan = forceRefresh or (#rebuilt <= 0)
    if doDeepScan then
        local cell = getCell and getCell() or nil
        local controllerSq = cell and cell:getGridSquare(edc.x, edc.y, edc.z) or nil
        if controllerSq then
            local buildings = Server.GetBuildingsInRange(controllerSq)
            for _, building in ipairs(buildings or {}) do
                local rooms = safeCall(building, "getRooms")
                if rooms then
                    for i = 0, rooms:size() - 1 do
                        local room = rooms:get(i)
                        local squares = room and safeCall(room, "getSquares") or nil
                        if squares then
                            for j = 0, squares:size() - 1 do
                                local sq = squares:get(j)
                                local objects = sq and safeCall(sq, "getObjects") or nil
                                if objects then
                                    for k = 0, objects:size() - 1 do
                                        addRefrigerationCacheObject(rebuilt, seen, objects:get(k))
                                    end
                                end
                                local worldObjects = sq and safeCall(sq, "getWorldObjects") or nil
                                if worldObjects then
                                    for k = 0, worldObjects:size() - 1 do
                                        addRefrigerationCacheObject(rebuilt, seen, worldObjects:get(k))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    edc._refrigerationObjectCache = rebuilt
    edc._refrigerationObjectCacheAt = nowMinutes
    return rebuilt
end

local function forceRefrigerationObjectsOff(edc, groups)
    if not edc and not groups then
        return 0
    end

    local count = 0
    local seen = {}
    local function forceObj(obj)
        if not obj then
            return
        end
        local key = tostring(obj)
        if seen[key] then
            return
        end
        seen[key] = true
        if isRefrigerationLikeObject(obj) then
            applyConsumerPowerState({ object = obj, group = "refrigeration" }, false)
            count = count + 1
        end
    end

    local refrigerationGroup = groups and groups.refrigeration or nil
    for _, consumer in ipairs((refrigerationGroup and refrigerationGroup.devices) or {}) do
        local obj = consumer and (consumer.object or consumer) or nil
        forceObj(obj)
    end

    if not edc then
        return count
    end

    local cache = refreshRefrigerationObjectCache(edc, groups, false)
    for _, obj in ipairs(cache or {}) do
        forceObj(obj)
    end

    return count
end

local function forceRefrigerationObjectsOn(edc, groups)
    if not edc and not groups then
        return 0
    end

    local count = 0
    local seen = {}
    local function powerObj(obj)
        if not obj then
            return
        end
        local key = tostring(obj)
        if seen[key] then
            return
        end
        seen[key] = true
        if isRefrigerationLikeObject(obj) then
            applyConsumerPowerState({ object = obj, group = "refrigeration" }, true)
            count = count + 1
        end
    end

    local refrigerationGroup = groups and groups.refrigeration or nil
    for _, consumer in ipairs((refrigerationGroup and refrigerationGroup.devices) or {}) do
        local obj = consumer and (consumer.object or consumer) or nil
        powerObj(obj)
    end

    if not edc then
        return count
    end

    local cache = refreshRefrigerationObjectCache(edc, groups, false)
    for _, obj in ipairs(cache or {}) do
        powerObj(obj)
    end

    return count
end

local function isLightLikeObject(obj)
    if not obj then
        return false
    end
    if isInstanceOf(obj, "IsoLightSwitch") or obj.getLight or obj.isLight or obj.isLightSwitch then
        return true
    end
    local groupId = normalizeGroupId(Server.ClassifyDevice(obj))
    if groupId == "lights" then
        return true
    end
    local probe = getObjectClassificationProbe(obj)
    return inferGroupFromProbe(probe) == "lights"
end

local function addLightsCacheObject(cache, seen, obj)
    if not cache or not seen or not obj then
        return
    end
    local key = tostring(obj)
    if seen[key] then
        return
    end
    if not isLightLikeObject(obj) then
        return
    end
    seen[key] = true
    cache[#cache + 1] = obj
end

local function refreshLightsObjectCache(edc, groups, forceRefresh)
    if not edc then
        return {}
    end

    local nowMinutes = getWorldMinutes()
    local last = tonumber(edc._lightsObjectCacheAt) or -1
    local cache = edc._lightsObjectCache
    if not forceRefresh and cache and (nowMinutes - last) < REFRIGERATION_CACHE_REFRESH_MINUTES then
        return cache
    end

    local rebuilt = {}
    local seen = {}

    local lightsGroup = groups and groups.lights or nil
    for _, consumer in ipairs((lightsGroup and lightsGroup.devices) or {}) do
        local obj = consumer and (consumer.object or consumer) or nil
        addLightsCacheObject(rebuilt, seen, obj)
    end

    local doDeepScan = forceRefresh or (#rebuilt <= 0)
    if doDeepScan then
        local cell = getCell and getCell() or nil
        local controllerSq = cell and cell:getGridSquare(edc.x, edc.y, edc.z) or nil
        if controllerSq then
            local buildings = Server.GetBuildingsInRange(controllerSq)
            for _, building in ipairs(buildings or {}) do
                local rooms = safeCall(building, "getRooms")
                if rooms then
                    for i = 0, rooms:size() - 1 do
                        local room = rooms:get(i)
                        local squares = room and safeCall(room, "getSquares") or nil
                        if squares then
                            for j = 0, squares:size() - 1 do
                                local sq = squares:get(j)
                                local objects = sq and safeCall(sq, "getObjects") or nil
                                if objects then
                                    for k = 0, objects:size() - 1 do
                                        addLightsCacheObject(rebuilt, seen, objects:get(k))
                                    end
                                end
                                local worldObjects = sq and safeCall(sq, "getWorldObjects") or nil
                                if worldObjects then
                                    for k = 0, worldObjects:size() - 1 do
                                        addLightsCacheObject(rebuilt, seen, worldObjects:get(k))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    edc._lightsObjectCache = rebuilt
    edc._lightsObjectCacheAt = nowMinutes
    return rebuilt
end

local function forceLightsObjectsOff(edc, groups)
    if not edc and not groups then
        return 0
    end

    local count = 0
    local seen = {}
    local function forceObj(obj)
        if not obj then
            return
        end
        local key = tostring(obj)
        if seen[key] then
            return
        end
        seen[key] = true
        if isLightLikeObject(obj) then
            applyConsumerPowerState({ object = obj, group = "lights" }, false)
            setLightRoomElectricity(obj, false)
            count = count + 1
        end
    end

    local lightsGroup = groups and groups.lights or nil
    for _, consumer in ipairs((lightsGroup and lightsGroup.devices) or {}) do
        local obj = consumer and (consumer.object or consumer) or nil
        forceObj(obj)
    end

    if not edc then
        return count
    end

    local cache = refreshLightsObjectCache(edc, groups, false)
    for _, obj in ipairs(cache or {}) do
        forceObj(obj)
    end

    return count
end

function Server.ApplyGroupState(groupId, state, devices)
    if not devices then
        return
    end
    if state == "limited" and not EnergyRouting.GetConfigValue("AutoShutdownLowPriority") then
        return
    end
    local powered = state == "powered"
    for _, consumer in ipairs(devices) do
        if powered then
            Server.PowerOnConsumer(consumer)
        else
            Server.PowerOffConsumer(consumer)
        end
    end
end

function Server.PowerOnConsumer(consumer)
    applyConsumerPowerState(consumer, true)
end

function Server.PowerOffConsumer(consumer)
    applyConsumerPowerState(consumer, false)
end

function Server.PowerOffGroup(consumers)
    if not consumers then
        return
    end
    for _, consumer in ipairs(consumers) do
        Server.PowerOffConsumer(consumer)
    end
end

local function getConsumerWattsForGroup(consumer, groupId)
    local watts = tonumber(consumer and consumer.consumption) or 0
    watts = normalizeWattsForGroup(groupId, watts)
    if watts <= 0 then
        watts = 1
    end
    return watts
end

local function getGroupMinConsumerWatts(groupId, groupData)
    local minWatts = nil
    local devices = groupData and groupData.devices or nil
    for _, consumer in ipairs(devices or {}) do
        local watts = getConsumerWattsForGroup(consumer, groupId)
        if not minWatts or watts < minWatts then
            minWatts = watts
        end
    end
    return minWatts
end

local function applyLimitedGroupPower(groupId, groupData, budgetWatts)
    local devices = groupData and groupData.devices or nil
    if not devices or #devices == 0 then
        return 0, 0
    end

    local budget = math.max(0, tonumber(budgetWatts) or 0)
    if budget <= 0 then
        Server.PowerOffGroup(devices)
        return 0, 0
    end

    local ordered = {}
    for _, consumer in ipairs(devices) do
        ordered[#ordered + 1] = {
            consumer = consumer,
            watts = getConsumerWattsForGroup(consumer, groupId),
        }
    end
    table.sort(ordered, function(a, b)
        if a.watts == b.watts then
            return tostring(a.consumer) < tostring(b.consumer)
        end
        return a.watts < b.watts
    end)

    local selected = {}
    local used = 0
    local poweredCount = 0
    local remaining = budget
    for _, entry in ipairs(ordered) do
        if remaining + 0.001 >= entry.watts then
            selected[entry.consumer] = true
            remaining = remaining - entry.watts
            used = used + entry.watts
            poweredCount = poweredCount + 1
        end
    end

    for _, consumer in ipairs(devices) do
        if selected[consumer] then
            Server.PowerOnConsumer(consumer)
        else
            Server.PowerOffConsumer(consumer)
        end
    end

    return used, poweredCount
end

local function applyGroupStatesToConsumers(groups, groupStates, groupConsumption)
    if not groups then
        return
    end
    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
        local groupData = groups[group.id] or nil
        local state = groupStates and groupStates[group.id] or "disabled"
        if groupData and groupData.devices then
            if state == "powered" then
                for _, consumer in ipairs(groupData.devices) do
                    Server.PowerOnConsumer(consumer)
                end
            elseif state == "limited" then
                applyLimitedGroupPower(group.id, groupData, groupConsumption and groupConsumption[group.id] or 0)
            else
                Server.PowerOffGroup(groupData.devices)
            end
        end
    end
end

local function getGroupOrderForMode(mode)
    local order = {}
    local seen = {}
    local function push(groupId)
        if groupId and not seen[groupId] then
            seen[groupId] = true
            table.insert(order, groupId)
        end
    end

    for _, groupId in ipairs(PRIORITY_GROUP_ORDER) do
        push(groupId)
    end

    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
        push(group.id)
    end

    return order
end

isGroupEligibleForMode = function(edc, groupId, mode)
    local toggleOn = edc and edc.toggles and edc.toggles[groupId] ~= false
    if not toggleOn then
        return false
    end
    if mode == "Survival" then
        return groupId == "refrigeration" or groupId == "lights"
    end
    return true
end

local function applyModeLogic(edc, snapshot, groups, mode)
    local groupStates = {}
    local totalConsumption = 0
    local poweredConsumerCount = 0
    local groupConsumption = {}
    local groupDemand = {}
    local outputEnabled = (edc and edc.outputEnabled ~= false)

    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
        local groupData = groups[group.id] or { devices = {}, requiredPower = 0 }
        groupDemand[group.id] = capTotalWattsForGroup(group.id, tonumber(groupData.requiredPower) or 0)
        groupConsumption[group.id] = 0
        groupStates[group.id] = "disabled"
    end

    if not outputEnabled then
        local offIdleSkip = isControllerOffIdleSkip(edc)
        if not offIdleSkip then
            for _, group in ipairs(EnergyRouting.GroupsList or {}) do
                local groupData = groups[group.id] or { devices = {} }
                Server.PowerOffGroup(groupData.devices)
            end
            if edc then
                edc._ersOffEnforcePending = nil
            end
        end
        return groupStates, 0, 0, 0, groupConsumption, groupDemand
    end

    local energyAvailable = math.max(0, tonumber(snapshot and snapshot.available) or 0)
    energyAvailable = energyAvailable + math.max(0, tonumber(snapshot and snapshot.production) or 0)

    local order = getGroupOrderForMode(mode)
    for _, groupId in ipairs(order) do
        local groupData = groups[groupId] or { devices = {}, requiredPower = 0 }
        local required = groupDemand[groupId] or capTotalWattsForGroup(groupId, tonumber(groupData.requiredPower) or 0)
        local eligible = isGroupEligibleForMode(edc, groupId, mode)

        if eligible and energyAvailable > 0 then
            if energyAvailable >= required then
                groupStates[groupId] = "powered"
                groupConsumption[groupId] = required
                energyAvailable = energyAvailable - required
                totalConsumption = totalConsumption + required
                poweredConsumerCount = poweredConsumerCount + #((groupData and groupData.devices) or {})
            else
                local minWatts = getGroupMinConsumerWatts(groupId, groupData)
                if minWatts and energyAvailable >= minWatts then
                    groupStates[groupId] = "limited"
                    groupConsumption[groupId] = energyAvailable
                    totalConsumption = totalConsumption + energyAvailable
                    poweredConsumerCount = poweredConsumerCount + 1
                    energyAvailable = 0
                else
                    groupStates[groupId] = "disabled"
                    groupConsumption[groupId] = 0
                end
            end
        else
            groupStates[groupId] = "disabled"
            groupConsumption[groupId] = 0
        end
    end

    applyGroupStatesToConsumers(groups, groupStates, groupConsumption)
    return groupStates, totalConsumption, energyAvailable, poweredConsumerCount, groupConsumption, groupDemand
end

local function applyModePresetToggles(edc, mode)
    if not edc or mode == "Manual" then
        return
    end

    edc.toggles = edc.toggles or EnergyRouting.MakeDefaultToggles()
    for _, group in ipairs(EnergyRouting.GroupsList) do
        edc.toggles[group.id] = getPresetToggleValue(mode, group.id)
    end
end

function Server.ScanDevices(edc)
    local groups = {}
    for _, group in ipairs(EnergyRouting.GroupsList) do
        groups[group.id] = { devices = {}, requiredPower = 0 }
    end

    local cell = getCell()
    if not cell then
        return groups
    end

    local radius = EnergyRouting.GetConfigValue("DeviceScanRadius")
    local minZ, maxZ = getControllerZBounds(cell, edc and edc.z, getControllerVerticalRange())
    for x = edc.x - radius, edc.x + radius do
        for y = edc.y - radius, edc.y + radius do
            for z = minZ, maxZ do
                local square = cell:getGridSquare(x, y, z)
                if square then
                    local objects = square:getObjects()
                    for i = 0, objects:size() - 1 do
                        Server.TryRegisterConsumer(objects:get(i), groups, edc and edc.id or nil)
                    end
                    local worldObjects = square:getWorldObjects()
                    if worldObjects then
                        for i = 0, worldObjects:size() - 1 do
                            Server.TryRegisterConsumer(worldObjects:get(i), groups, edc and edc.id or nil)
                        end
                    end
                end
            end
        end
    end

    return groups
end

function Server.GetSquaresInRadius(centerSq, radius)
    local squares = {}
    if not centerSq or not radius then
        return squares
    end
    local cx, cy, cz = centerSq:getX(), centerSq:getY(), centerSq:getZ()
    local cell = getCell and getCell() or nil
    if not cell then
        return squares
    end
    local minZ, maxZ = getControllerZBounds(cell, cz, getControllerVerticalRange())
    for x = cx - radius, cx + radius do
        for y = cy - radius, cy + radius do
            for z = minZ, maxZ do
                local sq = cell:getGridSquare(x, y, z)
                if sq then
                    table.insert(squares, sq)
                end
            end
        end
    end
    return squares
end

function Server.GetBuildingsInRange(controllerSq)
    local buildings = {}
    local seen = {}
    if not controllerSq then
        return buildings
    end
    local radius = EnergyRouting.CONTROLLER_RADIUS or 20
    for _, sq in ipairs(Server.GetSquaresInRadius(controllerSq, radius)) do
        local b = sq:getBuilding()
        if b and not seen[b] then
            seen[b] = true
            table.insert(buildings, b)
        end
    end
    return buildings
end

function Server.ForceBuildingHasElectricityOff(edc)
    if not edc or not edc.id then
        return
    end
    local controllerObj = Server.GetControllerObject and Server.GetControllerObject(edc.id) or nil
    local controllerSq = controllerObj and safeCall(controllerObj, "getSquare") or nil
    if not controllerSq then
        return
    end
    local buildings = Server.GetBuildingsInRange(controllerSq)
    if not buildings or #buildings == 0 then
        return
    end
    for _, building in ipairs(buildings) do
        if building then
            if building.setHasElectricity then
                pcall(building.setHasElectricity, building, false)
            end
            local bdef = safeCall(building, "getDef")
            if bdef and bdef.setHasElectricity then
                pcall(bdef.setHasElectricity, bdef, false)
            end
        end
    end
end

function Server.SetBuildingsInRangeElectricity(edc, powered)
    if not edc or not edc.id then
        return 0
    end
    local controllerObj = Server.GetControllerObject and Server.GetControllerObject(edc.id) or nil
    local controllerSq = controllerObj and safeCall(controllerObj, "getSquare") or nil
    if not controllerSq then
        return 0
    end
    local buildings = Server.GetBuildingsInRange(controllerSq)
    if not buildings or #buildings == 0 then
        return 0
    end

    local applied = 0
    local hasPower = powered and true or false
    for _, building in ipairs(buildings) do
        if building then
            if building.setHasElectricity then
                pcall(building.setHasElectricity, building, hasPower)
            end
            local bdef = safeCall(building, "getDef")
            if bdef and bdef.setHasElectricity then
                pcall(bdef.setHasElectricity, bdef, hasPower)
            end
            applied = applied + 1
        end
    end
    return applied
end

function Server.ApplyDebugVanillaLikePower(edc, forceApply)
    if not edc then
        return 0
    end
    local desired = (edc.outputEnabled ~= false)
    if ERS and ERS.BuildingPower and ERS.BuildingPower.applyDebugGeneratorBus then
        local ok, chunksApplied = pcall(ERS.BuildingPower.applyDebugGeneratorBus, edc, desired, forceApply == true)
        if ok and type(chunksApplied) == "number" then
            return chunksApplied
        end
    end
    -- Fallback path if debug generator bus is unavailable.
    Server.SetBuildingsInRangeElectricity(edc, desired)
    return -1
end

function Server.SetBuildingElectricity(edc, powered)
    if not edc or not edc.id then
        return
    end
    -- In total mode, building-level power can be enabled when the controller
    -- budget is enough to cover full virtual demand. Otherwise keep it OFF.
    local controllerObj = Server.GetControllerObject and Server.GetControllerObject(edc.id) or nil
    local controllerSq = controllerObj and safeCall(controllerObj, "getSquare") or nil
    if not controllerSq then
        return
    end
    local buildings = Server.GetBuildingsInRange(controllerSq)
    if not buildings or #buildings == 0 then
        return
    end
    local hasPower = powered and true or false
    for _, building in ipairs(buildings) do
        if building then
            if building.setHasElectricity then
                pcall(building.setHasElectricity, building, hasPower)
            end
            local bdef = safeCall(building, "getDef")
            if bdef and bdef.setHasElectricity then
                pcall(bdef.setHasElectricity, bdef, hasPower)
            end
        end
    end
end

function Server.ApplySquarePowerBus(edc)
    if not edc then
        return
    end
    local powered = (edc.outputEnabled ~= false)
    local applied = false

    local squaresCount = 0
    if EnergyNetwork_Server and EnergyNetwork_Server.SetSquaresElectricity then
        local ok, result = pcall(EnergyNetwork_Server.SetSquaresElectricity, edc, powered)
        if ok and type(result) == "number" then
            squaresCount = result
        end
        applied = true
    elseif EnergyNetwork and EnergyNetwork.Server and EnergyNetwork.Server.SetSquaresElectricity then
        local ok, result = pcall(EnergyNetwork.Server.SetSquaresElectricity, edc, powered)
        if ok and type(result) == "number" then
            squaresCount = result
        end
        applied = true
    end

    if not applied then
        local cell = getCell and getCell() or nil
        if not cell then
            return
        end
        local radius = tonumber(EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("DeviceScanRadius") or nil)
        if not radius or radius <= 0 then
            radius = tonumber(EnergyRouting and EnergyRouting.CONTROLLER_RADIUS or nil)
        end
        if not radius or radius <= 0 then
            radius = 20
        end
        local cx = tonumber(edc.x)
        local cy = tonumber(edc.y)
        local cz = tonumber(edc.z)
        if not cx or not cy or not cz then
            return
        end
        cx = math.floor(cx)
        cy = math.floor(cy)
        cz = math.floor(cz)
        local minZ, maxZ = getControllerZBounds(cell, cz, getControllerVerticalRange())
        for x = cx - radius, cx + radius do
            for y = cy - radius, cy + radius do
                for z = minZ, maxZ do
                    local sq = cell:getGridSquare(x, y, z)
                    if sq then
                        if sq.setHaveElectricity then
                            pcall(sq.setHaveElectricity, sq, powered)
                        end
                        if sq.setHasElectricity then
                            pcall(sq.setHasElectricity, sq, powered)
                        end
                        if sq.setElectricity then
                            pcall(sq.setElectricity, sq, powered)
                        end
                        squaresCount = squaresCount + 1
                    end
                end
            end
        end
    end
    return squaresCount
end

local function resetGroupsForDebug(edc)
    local states = {}
    local consumption = {}
    local demand = {}
    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
        states[group.id] = "disabled"
        consumption[group.id] = 0
        demand[group.id] = 0
    end
    edc.groupStates = states
    edc.groupConsumption = consumption
    edc.groupDemand = demand
end

local function addConsumerToBucket(consumersByGroup, consumer)
    if not consumersByGroup or not consumer then
        return
    end
    if consumer.object
        and (isPassiveTelevisionObject(consumer.object)
            or isBatteryRadioObject(consumer.object)
            or isExplicitlyExcludedConsumerObject(consumer.object)) then
        return
    end
    local groupId = normalizeGroupId(consumer.group)
    local detectedGroup = nil
    if consumer.object then
        detectedGroup = normalizeGroupId(Server.ClassifyDevice(consumer.object))
    end
    if detectedGroup then
        local needsCorrection = (groupId == nil)
            or ((groupId == "lights" or groupId == "industrial")
                and (detectedGroup == "refrigeration" or detectedGroup == "cooking"))
        if needsCorrection then
            groupId = detectedGroup
        end
    elseif groupId == "industrial" then
        -- Purge legacy broad industrial tags when live classification no longer matches.
        groupId = nil
    end
    local bucket = groupId and consumersByGroup[groupId] or nil
    if not bucket then
        return
    end
    local watts = tonumber(consumer.consumption) or 0
    if consumer.object and detectedGroup and groupId == detectedGroup and normalizeGroupId(consumer.group) ~= groupId then
        local detectedWatts = Server.GetDevicePowerUsage and Server.GetDevicePowerUsage(consumer.object) or nil
        if tonumber(detectedWatts) and tonumber(detectedWatts) > 0 then
            watts = tonumber(detectedWatts)
        end
    end
    watts = normalizeWattsForGroup(groupId, watts)
    consumer.group = groupId
    consumer.consumption = watts
    bucket.requiredPower = capTotalWattsForGroup(groupId, (bucket.requiredPower or 0) + math.max(0, watts))
    table.insert(bucket.devices, consumer)

    local consumerLogId = consumer.id
    if not consumerLogId and consumer.object and EnergyRouting and EnergyRouting.Consumers
        and EnergyRouting.Consumers.GetObjectId then
        consumerLogId = EnergyRouting.Consumers.GetObjectId(consumer.object)
    end
    if not consumerLogId and consumer.object then
        consumerLogId = tostring(consumer.object)
    end
    if consumerLogId and not Server._consumerClassifiedLogById[consumerLogId] then
        Server._consumerClassifiedLogById[consumerLogId] = true
        local sprite = consumer.object and safeCall(consumer.object, "getSprite") or nil
        local spriteName = sprite and safeCall(sprite, "getName") or nil
        print("[SPESS][Consumers] classify id=" .. tostring(consumerLogId)
            .. " group=" .. tostring(groupId)
            .. " watts=" .. tostring(math.floor(watts))
            .. " sprite=" .. tostring(spriteName))
    end
end

function Server.TryRegisterConsumer(obj, consumersByGroup, edcId)
    if not obj or not consumersByGroup then
        return
    end
    if Server.IsEDCObject(obj) then
        return
    end
    if isPassiveTelevisionObject(obj)
        or isBatteryRadioObject(obj)
        or isExplicitlyExcludedConsumerObject(obj) then
        return
    end

    local consumer = nil
    if EnergyRouting and EnergyRouting.RegisterConsumer then
        consumer = EnergyRouting.RegisterConsumer(obj)
    end

    if not consumer then
        local sprite = safeCall(obj, "getSprite")
        local spriteName = sprite and safeCall(sprite, "getName") or nil
        local probe = getObjectClassificationProbe(obj)
        local groupId, watts = EnergyRouting.ClassifyObject(spriteName)
        if not groupId and probe ~= "" then
            groupId, watts = EnergyRouting.ClassifyObject(probe)
        end
        if not groupId and Server.IsElectricDevice(obj) then
            groupId = Server.ClassifyDevice(obj)
            watts = Server.GetDevicePowerUsage(obj)
        end
        groupId = normalizeGroupId(groupId)
        if not groupId then
            return
        end
        watts = tonumber(watts) or 0
        watts = normalizeWattsForGroup(groupId, watts)
        consumer = {
            object = obj,
            group = groupId,
            consumption = watts or 0,
            controllerId = (EnergyRouting.GetControllerForConsumer and EnergyRouting.GetControllerForConsumer(obj)) or nil,
        }
    end

    if edcId and consumer.controllerId and consumer.controllerId ~= edcId then
        return
    end

    addConsumerToBucket(consumersByGroup, consumer)
end

local function countDevicesInGroups(groups)
    local total = 0
    for _, groupData in pairs(groups or {}) do
        total = total + #((groupData and groupData.devices) or {})
    end
    return total
end

local function countLiveObjectsInGroups(groups)
    local total = 0
    for _, groupData in pairs(groups or {}) do
        for _, consumer in ipairs((groupData and groupData.devices) or {}) do
            if consumer and consumer.object then
                total = total + 1
            end
        end
    end
    return total
end

local function collectPassiveTelevisionLoad(edc)
    if not edc then
        return 0, 0
    end

    local cell = getCell and getCell() or nil
    if not cell then
        return 0, 0
    end

    local controllerSq = cell:getGridSquare(edc.x, edc.y, edc.z)
    if not controllerSq then
        return 0, 0
    end

    local radius = tonumber(EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("DeviceScanRadius") or nil)
    if not radius or radius <= 0 then
        radius = tonumber(EnergyRouting and EnergyRouting.CONTROLLER_RADIUS or nil)
    end
    if not radius or radius <= 0 then
        radius = 20
    end

    local seen = {}
    local count = 0
    local function scanObject(obj)
        if not obj or not isPassiveTelevisionActive(obj) then
            return
        end
        local key = tostring(obj)
        if seen[key] then
            return
        end
        seen[key] = true
        count = count + 1
    end

    for _, sq in ipairs(Server.GetSquaresInRadius(controllerSq, radius)) do
        local objects = safeCall(sq, "getObjects")
        if objects then
            for i = 0, objects:size() - 1 do
                scanObject(objects:get(i))
            end
        end
        local worldObjects = safeCall(sq, "getWorldObjects")
        if worldObjects then
            for i = 0, worldObjects:size() - 1 do
                scanObject(worldObjects:get(i))
            end
        end
    end

    local watts = count * getPassiveTelevisionWatts()
    return watts, count
end

local function getActiveGroupsForPassiveLoad(edc, mode)
    local active = {}
    if not edc or edc.outputEnabled == false then
        return active
    end
    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
        if isGroupEligibleForMode(edc, group.id, mode) then
            active[#active + 1] = group.id
        end
    end
    return active
end

local function redistributePassiveLoad(edc, mode, groupConsumption, groupDemand, passiveLoadW, activeGroups)
    local watts = tonumber(passiveLoadW) or 0
    if watts <= 0 then
        return 0, 0
    end

    local groups = activeGroups or getActiveGroupsForPassiveLoad(edc, mode)
    if #groups <= 0 then
        return watts, 0
    end

    local share = watts / #groups
    for _, groupId in ipairs(groups) do
        groupDemand[groupId] = (tonumber(groupDemand[groupId]) or 0) + share
        groupConsumption[groupId] = (tonumber(groupConsumption[groupId]) or 0) + share
    end
    return 0, #groups
end

local function addHardBlockedTvEntry(entries, seenBySquare, obj, sx, sy, sz)
    if not entries or not seenBySquare then
        return
    end

    local targetObj = obj
    if targetObj and not isHardBlockedTvSprite(targetObj) then
        targetObj = nil
    end

    if (sx == nil or sy == nil or sz == nil) and targetObj then
        local sq = safeCall(targetObj, "getSquare")
        if sq then
            sx, sy, sz = sq:getX(), sq:getY(), sq:getZ()
        end
    end

    sx = tonumber(sx)
    sy = tonumber(sy)
    sz = tonumber(sz)
    if not (sx and sy and sz) then
        return
    end
    sx = math.floor(sx)
    sy = math.floor(sy)
    sz = math.floor(sz)

    local key = tostring(sx) .. ":" .. tostring(sy) .. ":" .. tostring(sz)
    local existing = seenBySquare[key]
    if existing then
        if not existing.object and targetObj then
            existing.object = targetObj
        end
        return
    end

    local entry = { object = targetObj, x = sx, y = sy, z = sz }
    seenBySquare[key] = entry
    entries[#entries + 1] = entry
end

local function cacheHardBlockedTvEntriesFromGroups(groups, entries, seenBySquare)
    for _, groupData in pairs(groups or {}) do
        for _, consumer in ipairs((groupData and groupData.devices) or {}) do
            local obj = consumer and (consumer.object or consumer) or nil
            if obj and isHardBlockedTvSprite(obj) then
                addHardBlockedTvEntry(entries, seenBySquare, obj)
            end
        end
    end
end

local function cacheHardBlockedTvEntriesFromRadius(edc, entries, seenBySquare)
    if not edc then
        return
    end

    local cell = getCell and getCell() or nil
    if not cell then
        return
    end

    local controllerSq = cell:getGridSquare(edc.x, edc.y, edc.z)
    if not controllerSq then
        return
    end

    local radius = tonumber(EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("DeviceScanRadius") or nil)
    if not radius or radius <= 0 then
        radius = tonumber(EnergyRouting and EnergyRouting.CONTROLLER_RADIUS or nil)
    end
    if not radius or radius <= 0 then
        radius = 20
    end

    for _, sq in ipairs(Server.GetSquaresInRadius(controllerSq, radius)) do
        local objects = safeCall(sq, "getObjects")
        if objects then
            for i = 0, objects:size() - 1 do
                local sqObj = objects:get(i)
                if isHardBlockedTvSprite(sqObj) then
                    addHardBlockedTvEntry(entries, seenBySquare, sqObj)
                end
            end
        end

        local worldObjects = safeCall(sq, "getWorldObjects")
        if worldObjects then
            for i = 0, worldObjects:size() - 1 do
                local sqObj = worldObjects:get(i)
                if isHardBlockedTvSprite(sqObj) then
                    addHardBlockedTvEntry(entries, seenBySquare, sqObj)
                end
            end
        end
    end
end

local function cacheHardBlockedTvEntries(edc, groups)
    if not edc then
        return 0
    end
    local entries = {}
    local seenBySquare = {}
    cacheHardBlockedTvEntriesFromGroups(groups, entries, seenBySquare)
    cacheHardBlockedTvEntriesFromRadius(edc, entries, seenBySquare)
    edc._hardBlockedTvEntries = entries
    edc._hardBlockedTvCacheAt = getWorldMinutes()
    return #entries
end

local function sumRequiredPower(groups)
    local total = 0
    for _, groupData in pairs(groups or {}) do
        total = total + math.max(0, tonumber(groupData and groupData.requiredPower) or 0)
    end
    return total
end

local function makeEmptyGroups()
    local groups = {}
    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
        groups[group.id] = { devices = {}, requiredPower = 0 }
    end
    return groups
end

local function updateConsumerCacheState(edc, groups)
    if not edc then
        return
    end
    local safeGroups = groups
    if type(safeGroups) ~= "table" then
        safeGroups = makeEmptyGroups()
    end
    edc.consumerCache = safeGroups
    edc.cachedGroups = safeGroups
    edc._lastScannedGroups = safeGroups
    edc.detectedConsumerCount = countDevicesInGroups(safeGroups)
    edc.totalConsumptionRate = sumRequiredPower(safeGroups)
end

local function resolveConsumerGroups(edc)
    Server.EnsureEDCOptimizationState(edc)
    if not edc then
        return makeEmptyGroups()
    end

    local nowMinutes = getWorldMinutes()
    local offIdleSkip = isControllerOffIdleSkip(edc)
    if offIdleSkip then
        local groups = edc.consumerCache or edc.cachedGroups or edc._lastScannedGroups
        if type(groups) ~= "table" then
            groups = makeEmptyGroups()
            -- First OFF-idle pass still seeds counters/caches.
            updateConsumerCacheState(edc, groups)
        else
            -- Keep cache references synchronized without recounting every OFF tick.
            edc.consumerCache = groups
            edc.cachedGroups = groups
            edc._lastScannedGroups = groups
            if edc.detectedConsumerCount == nil then
                edc.detectedConsumerCount = countDevicesInGroups(groups)
            end
            if edc.totalConsumptionRate == nil then
                edc.totalConsumptionRate = sumRequiredPower(groups)
            end
        end
        edc._lastScanSource = "off-idle-skip"
        edc.isDirty = false
        edc._forceConsumerRescan = nil
        edc._lastScannedAt = edc._lastScannedAt or nowMinutes
        return groups
    end

    local nowHours = getWorldHours()
    local scanIntervalHours = math.max(0.016, tonumber(edc.scanIntervalHours) or getConfiguredScanIntervalHours())
    local lastScanHour = tonumber(edc.lastConsumerScanTime)
    if not lastScanHour then
        local legacyLastScanMinutes = tonumber(edc._lastScannedAt)
        lastScanHour = legacyLastScanMinutes and (legacyLastScanMinutes / 60) or -1
    end

    local periodicScanDue = (lastScanHour < 0) or ((nowHours - lastScanHour) >= scanIntervalHours)
    local dirtyScan = edc.isDirty == true
    local mandatoryScan = edc._lastScannedGroups == nil
        or edc._forceConsumerRescan
        or edc._forceFullEnforce
        or edc._ersOffEnforcePending == true

    local bootstrapPending = (edc._consumerBootstrapDone ~= true)
    local shouldScan = mandatoryScan or dirtyScan or periodicScanDue or bootstrapPending
    if shouldScan and periodicScanDue and (not mandatoryScan) and (not dirtyScan) then
        local sq = getControllerSquare(edc)
        local scanRadius = getConsumerScanRadius() + 8
        if sq and not hasNearbyOnlinePlayerCached(edc, sq, scanRadius, nowMinutes, "scan") then
            shouldScan = false
            edc._lastScannedAt = nowMinutes
            edc.lastConsumerScanTime = nowHours
        end
    end

    local groups = nil
    if shouldScan then
        local t0 = getPerfNowMs()
        groups = Server.ScanConsumers(edc)
        local dt = getPerfNowMs() - t0
        if dt > PERF_WARN_MS then
            print("[ERS][PERF] ScanConsumers took " .. tostring(dt) .. "ms id=" .. tostring(edc.id))
            print("[ERS][PERF] ScanConsumers source=" .. tostring(edc._lastScanSource or "unknown")
                .. " id=" .. tostring(edc.id))
        end
        edc._lastScannedAt = nowMinutes
        edc.lastConsumerScanTime = nowHours
        edc.isDirty = false
        edc._forceConsumerRescan = nil
    else
        groups = edc.consumerCache or edc.cachedGroups or edc._lastScannedGroups
    end

    if type(groups) ~= "table" then
        groups = makeEmptyGroups()
    end
    if shouldScan or type(edc.consumerCache) ~= "table" then
        updateConsumerCacheState(edc, groups)
    else
        -- No new scan: keep references in sync and avoid recounting every update.
        edc.consumerCache = groups
        edc.cachedGroups = groups
        edc._lastScannedGroups = groups
        if edc.detectedConsumerCount == nil then
            edc.detectedConsumerCount = countDevicesInGroups(groups)
        end
        if edc.totalConsumptionRate == nil then
            edc.totalConsumptionRate = sumRequiredPower(groups)
        end
    end
    edc._lastScannedAt = edc._lastScannedAt or nowMinutes
    return groups
end

local function makeGroupDemandSignature(groupDemand)
    local parts = {}
    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
        local watts = math.floor(tonumber(groupDemand and groupDemand[group.id]) or 0)
        parts[#parts + 1] = group.id .. ":" .. tostring(watts)
    end
    return table.concat(parts, "|")
end

function Server.ScanConsumers(edc)
    local groups = {}
    for _, group in ipairs(EnergyRouting.GroupsList) do
        groups[group.id] = { devices = {}, requiredPower = 0 }
    end

    local cell = getCell()
    if not cell or not edc then
        return groups
    end

    local nowMinutes = getWorldMinutes()
    local lastFullRescan = tonumber(edc._lastFullConsumerRescanAt) or -1
    local fullRescanDue = (lastFullRescan < 0) or ((nowMinutes - lastFullRescan) >= FULL_CONSUMER_RESCAN_MINUTES)
    local scanSource = "none"
    local forceBootstrapWorldPass = false
    local bootstrapPending = (edc._consumerBootstrapDone ~= true)
    local cachedGroups = edc.consumerCache or edc.cachedGroups or edc._lastScannedGroups
    local hasCachedConsumers = countDevicesInGroups(cachedGroups) > 0

    -- Fast path: direct registry bucket lookup (no reclass/reassign each scan).
    if EnergyRouting and EnergyRouting.Consumers then
        local consumersModule = EnergyRouting.Consumers
        local bucket = consumersModule.byController and consumersModule.byController[edc.id] or nil
        local registry = consumersModule.registry or nil
        if bucket and registry then
            local found = 0
            for consumerId in pairs(bucket) do
                local entry = registry[consumerId]
                if entry and entry.object and normalizeGroupId(entry.group) then
                    addConsumerToBucket(groups, entry)
                    found = found + 1
                else
                    -- Prune stale entries cheaply; expensive reclassification is deferred.
                    bucket[consumerId] = nil
                end
            end

            if found > 0 then
                local registeredDemand = sumRequiredPower(groups)
                if registeredDemand <= 0 then
                    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
                        local groupBucket = groups[group.id]
                        if groupBucket and #groupBucket.devices > 0 and (tonumber(groupBucket.requiredPower) or 0) <= 0 then
                            local fallbackWatts = normalizeWattsForGroup(group.id, getDefaultWattsForGroup(group.id))
                            groupBucket.requiredPower = fallbackWatts * #groupBucket.devices
                        end
                    end
                end
                if fullRescanDue then
                    edc._lastFullConsumerRescanAt = nowMinutes
                end
                local logKey = edc.id or (tostring(edc.x) .. ":" .. tostring(edc.y) .. ":" .. tostring(edc.z))
                Server._consumerZeroDemandLogById[logKey] = nil
                edc._consumerBootstrapDone = true
                edc._lastScanSource = "registry-fast"
                return groups
            end

            -- Bootstrap or empty cache must execute one world-pass when registry is empty/stale.
            if bootstrapPending or not hasCachedConsumers then
                forceBootstrapWorldPass = true
            elseif not fullRescanDue then
                -- If bucket exists but empty/not live, keep cached groups and avoid world-scan spam.
                edc._lastScanSource = "registry-empty-cached"
                return cachedGroups
            end
        elseif bootstrapPending or not hasCachedConsumers then
            -- First scan after load (or cache empty): seed registry from world even in registry-only mode.
            forceBootstrapWorldPass = true
        elseif not fullRescanDue then
            -- No bucket yet; keep cached groups and avoid expensive world-scan spam.
            edc._lastScanSource = "registry-miss-cached"
            return cachedGroups
        end

        -- Slow fallback only when full rescan is due (rare): refresh mapping once.
        if fullRescanDue and consumersModule.GetByController then
            local registered = consumersModule.GetByController(edc.id)
            if registered and #registered > 0 then
                for _, consumer in ipairs(registered) do
                    addConsumerToBucket(groups, consumer)
                end
                if countDevicesInGroups(groups) > 0 then
                    edc._lastFullConsumerRescanAt = nowMinutes
                    edc._consumerBootstrapDone = true
                    edc._lastScanSource = "registry-refresh"
                    return groups
                end
            end
        end
    end

    local allowWorldPass = ENABLE_WORLD_PASS_SCAN == true
        or edc._forceConsumerRescan == true
        or edc._forceFullEnforce == true
        or forceBootstrapWorldPass

    if not allowWorldPass then
        -- Registry-only mode: avoid expensive periodic world scans that cause freezes.
        edc._lastFullConsumerRescanAt = nowMinutes
        edc._lastScanSource = "registry-only"
        return groups
    end

    -- Full rescan optimized: single tile pass, no rooms/buildings helper, no temp square lists.
    local cx = math.floor(tonumber(edc.x) or 0)
    local cy = math.floor(tonumber(edc.y) or 0)
    local cz = math.floor(tonumber(edc.z) or 0)
    local controllerSq = cell:getGridSquare(cx, cy, cz)
    if not controllerSq then
        edc._lastFullConsumerRescanAt = nowMinutes
        edc._lastScanSource = "world-no-controller"
        return groups
    end

    local seenObjects = {}
    local function registerObject(obj)
        if not obj then
            return
        end
        if seenObjects[obj] then
            return
        end
        seenObjects[obj] = true
        Server.TryRegisterConsumer(obj, groups, edc.id)
    end

    local radius = tonumber(EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("DeviceScanRadius") or nil)
    if not radius or radius <= 0 then
        radius = tonumber(EnergyRouting and EnergyRouting.CONTROLLER_RADIUS or 20)
    end
    if not radius or radius <= 0 then
        radius = 20
    end

    local minZ, maxZ = getControllerZBounds(cell, cz, getControllerVerticalRange())
    for x = cx - radius, cx + radius do
        for y = cy - radius, cy + radius do
            for z = minZ, maxZ do
                local sq = cell:getGridSquare(x, y, z)
                if sq then
                    local objs = sq:getObjects()
                    if objs then
                        for i = 0, objs:size() - 1 do
                            registerObject(objs:get(i))
                        end
                    end
                    local worldObjs = sq:getWorldObjects()
                    if worldObjs then
                        for i = 0, worldObjs:size() - 1 do
                            registerObject(worldObjs:get(i))
                        end
                    end
                end
            end
        end
    end

    edc._lastFullConsumerRescanAt = nowMinutes
    edc._consumerBootstrapDone = true
    edc._lastScanSource = "world-pass"
    return groups
end

local function tableCount(T)
    local count = 0
    if T then
        for _ in pairs(T) do count = count + 1 end
    end
    return count
end

local function buildConsumersSnapshot(groups)
    local snapshot = {}
    for groupId, groupData in pairs(groups or {}) do
        for _, consumer in ipairs((groupData and groupData.devices) or {}) do
            local consumerId = consumer and consumer.id or nil
            if not consumerId and consumer and consumer.object
                and EnergyRouting and EnergyRouting.Consumers
                and EnergyRouting.Consumers.GetObjectId then
                consumerId = EnergyRouting.Consumers.GetObjectId(consumer.object)
            end
            if consumerId then
                local entry = {
                    group = consumer.group or groupId,
                    consumption = tonumber(consumer.consumption) or 0,
                }
                local sq = consumer.object and safeCall(consumer.object, "getSquare") or nil
                if sq then
                    entry.x = sq:getX()
                    entry.y = sq:getY()
                    entry.z = sq:getZ()
                end
                snapshot[consumerId] = entry
            end
        end
    end
    return snapshot
end

local function cloneEnergizedSquares(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end
    for _, square in ipairs(source) do
        local x = square and tonumber(square.x) or nil
        local y = square and tonumber(square.y) or nil
        local z = square and tonumber(square.z) or nil
        if x and y and z then
            copy[#copy + 1] = {
                x = math.floor(x),
                y = math.floor(y),
                z = math.floor(z),
            }
        end
    end
    return copy
end

local function buildEnergizedSquares(groups, groupStates, outputEnabled)
    local squaresByKey = {}
    local squaresList = {}
    if outputEnabled == false then
        return squaresByKey, squaresList, "0|"
    end

    local xorHash = 0
    local sumHash = 0
    local seen = {}
    local function pushSquare(x, y, z)
        local nx = tonumber(x)
        local ny = tonumber(y)
        local nz = tonumber(z)
        if not nx or not ny or not nz then
            return
        end
        nx = math.floor(nx)
        ny = math.floor(ny)
        nz = math.floor(nz)
        local key = tostring(nx) .. "_" .. tostring(ny) .. "_" .. tostring(nz)
        if seen[key] then
            return
        end
        seen[key] = true
        squaresByKey[key] = true
        squaresList[#squaresList + 1] = { x = nx, y = ny, z = nz }
        local mixed = mixSquareHash32(nx, ny, nz)
        if BXOR then
            xorHash = u32(BXOR(xorHash, mixed))
        else
            xorHash = u32(xorHash + mixed)
        end
        sumHash = u32(sumHash + u32(mixed * 2246822519))
    end

    for groupId, groupData in pairs(groups or {}) do
        local state = groupStates and groupStates[groupId] or "disabled"
        if state == "powered" then
            for _, consumer in ipairs((groupData and groupData.devices) or {}) do
                local obj = consumer and consumer.object or nil
                local sq = obj and safeCall(obj, "getSquare") or nil
                if sq then
                    pushSquare(sq:getX(), sq:getY(), sq:getZ())
                else
                    pushSquare(consumer and consumer.x, consumer and consumer.y, consumer and consumer.z)
                end
            end
        end
    end

    local count = #squaresList
    if count <= 0 then
        return squaresByKey, squaresList, "0|"
    end
    local signatureHash = u32(xorHash + u32(sumHash * 3266489917) + count)
    return squaresByKey, squaresList, tostring(count) .. "|" .. tostring(signatureHash)
end

local function buildRoutingStateSignature(edc)
    if not edc then
        return "nil"
    end
    local storageRounded = roundToStep(tonumber(edc.storage) or 0, tonumber(edc.syncThreshold) or getConfiguredSyncThreshold())
    local parts = {
        tostring(math.floor(tonumber(edc.x) or 0)),
        tostring(math.floor(tonumber(edc.y) or 0)),
        tostring(math.floor(tonumber(edc.z) or 0)),
        tostring(edc.mode or "Balanced"),
        tostring(edc.outputEnabled ~= false),
        tostring(math.floor(tonumber(edc.production) or 0)),
        tostring(math.floor(tonumber(edc.hydroProduction) or 0)),
        tostring(storageRounded),
        tostring(math.floor(tonumber(edc.consumptionTotal or edc.consumption) or 0)),
        tostring(math.floor(tonumber(edc.balance) or 0)),
        tostring(math.floor(tonumber(edc.detectedConsumerCount) or 0)),
        tostring(math.floor(tonumber(edc.panelCount) or 0)),
        tostring(math.floor(tonumber(edc.batteryCount) or 0)),
        tostring(math.floor(tonumber(edc.windCount) or 0)),
        tostring(math.floor(tonumber(edc.hydroCount) or 0)),
        tostring(math.floor(tonumber(edc.windBatteryCount) or 0)),
        tostring(math.floor(tonumber(edc.solarBonusPercent) or 0)),
        tostring(math.floor(tonumber(edc.windBonusPercent) or 0)),
        tostring(edc.weather or "Unknown"),
        tostring(edc.energizedSquaresSignature or "0|"),
    }
    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
        parts[#parts + 1] = tostring(group.id) .. "=" .. tostring(math.floor(tonumber(edc.groupConsumption and edc.groupConsumption[group.id]) or 0))
        parts[#parts + 1] = tostring(group.id) .. "d=" .. tostring(math.floor(tonumber(edc.groupDemand and edc.groupDemand[group.id]) or 0))
        parts[#parts + 1] = tostring(group.id) .. "s=" .. tostring(edc.groupStates and edc.groupStates[group.id] or "disabled")
    end
    return table.concat(parts, "|")
end

function Server.CacheRoutingStateOnController(edc)
    if not edc or not edc.id then
        return
    end
    local controllerObj = Server.GetControllerObject and Server.GetControllerObject(edc.id) or nil
    if not controllerObj then
        return
    end

    local sigStartMs = getPerfNowMs()
    local signature = buildRoutingStateSignature(edc)
    local sigDtMs = getPerfNowMs() - sigStartMs
    if sigDtMs > PERF_WARN_MS then
        print("[ERS][PERF] buildRoutingStateSignature(cache) took " .. tostring(sigDtMs)
            .. "ms id=" .. tostring(edc.id))
    end
    if Server._routingStateSignatureById[edc.id] == signature then
        return
    end
    Server._routingStateSignatureById[edc.id] = signature

    local md = getObjectModData(controllerObj)
    if not md then
        return
    end
    md.energyController = md.energyController or {}
    md.energyController.routingState = {
        id = edc.id,
        mode = edc.mode or "Balanced",
        outputEnabled = edc.outputEnabled ~= false,
        toggles = EnergyRouting.CloneTable(edc.toggles),
        groupStates = EnergyRouting.CloneTable(edc.groupStates),
        groupConsumption = EnergyRouting.CloneTable(edc.groupConsumption),
        groupDemand = EnergyRouting.CloneTable(edc.groupDemand),
        consumptionTotal = edc.consumptionTotal or edc.consumption or 0,
        consumption = edc.consumption or 0,
        detectedConsumerCount = edc.detectedConsumerCount or 0,
        balance = edc.balance or 0,
        usesBattery = edc.usesBattery == true,
        production = edc.production or 0,
        storage = edc.storage or 0,
        capacity = edc.capacity or edc.totalCapacity or 0,
        totalCapacity = edc.totalCapacity or edc.capacity or 0,
        solarCapacity = edc.solarCapacity or 0,
        windCapacity = edc.windCapacity or 0,
        solarProduction = edc.solarProduction or 0,
        windProduction = edc.windProduction or 0,
        hydroProduction = edc.hydroProduction or 0,
        solarStorage = edc.solarStorage or 0,
        windStorage = edc.windStorage or 0,
        weather = edc.weather or "Unknown",
        panelCount = edc.panelCount or 0,
        batteryCount = edc.batteryCount or 0,
        windCount = edc.windCount or 0,
        hydroCount = edc.hydroCount or 0,
        windBatteryCount = edc.windBatteryCount or 0,
        solarBonusPercent = edc.solarBonusPercent or 0,
        windBonusPercent = edc.windBonusPercent or 0,
        energizedSquares = nil,
        energizedSquaresCount = edc.energizedSquares and #edc.energizedSquares or 0,
        energizedSquaresSignature = tostring(edc.energizedSquaresSignature or "0|"),
    }
    transmitObjectModData(controllerObj)
end

function Server.IsTotalBuildingPowerMode()
    if SIMPLE_OUTPUT_ONLY_MODE then
        return true
    end
    local configured = nil
    if EnergyRouting and EnergyRouting.GetConfigValue then
        configured = EnergyRouting.GetConfigValue("TotalBuildingPowerMode")
    end
    if configured ~= nil then
        return configured == true
    end
    -- Temporary default: prioritize full building power before consumer routing.
    return true
end

function Server.GetAuthorizedBuildingPower(edc, snapshot)
    local available = tonumber((snapshot and snapshot.available) or (edc and edc.energyAvailable) or 0) or 0
    local production = tonumber((snapshot and snapshot.production) or (edc and edc.production) or 0) or 0
    local storage = tonumber((snapshot and snapshot.storage) or (edc and edc.storage) or 0) or 0

    local authorizedWatts = math.max(0, available + production)
    local hasEnergy = (authorizedWatts > 0) or (storage > 0)
    return hasEnergy, authorizedWatts, storage, available, production
end

function Server.ApplyTotalBuildingPowerState(edc, snapshot, reason, forceApply)
    if not edc then
        return "Vanilla"
    end
    if edc.outputEnabled == nil then
        edc.outputEnabled = true
    end

    snapshot = snapshot or Server.GetEnergySnapshot(edc)
    local hasEnergy, authorizedWatts, storage, available, production =
        Server.GetAuthorizedBuildingPower(edc, snapshot)
    local virtualDemand = tonumber(edc._ersVirtualDemand) or 0
    local demandAllowsPower = true
    if edc._ersDemandAllowPower ~= nil then
        demandAllowsPower = (edc._ersDemandAllowPower ~= false)
    elseif virtualDemand > 0 then
        demandAllowsPower = virtualDemand <= authorizedWatts
    end
    if edc.outputEnabled == false then
        demandAllowsPower = false
    end
    edc._ersDemandAllowPower = demandAllowsPower

    local panelCount = math.max(0, tonumber(snapshot and snapshot.panelCount) or 0)
    local windCount = math.max(0, tonumber(snapshot and snapshot.windCount) or 0)
    local hydroCount = math.max(0, tonumber(snapshot and snapshot.hydroCount) or 0)
    local otherCount = math.max(0, tonumber(snapshot and snapshot.otherCount) or 0)
    local hasAnyProducer = (panelCount + windCount + hydroCount + otherCount) > 0

    local source = "Vanilla"
    if edc.outputEnabled == false then
        source = "Off"
    elseif not demandAllowsPower then
        source = "Off"
    elseif hasEnergy then
        source = "ERS"
    elseif hasAnyProducer then
        -- Prevent fallback-to-vanilla infinite power when a controller has producers but no real energy.
        source = "Off"
    end

    local virtualDemandNow = math.max(0, tonumber(edc._ersVirtualDemand) or 0)
    local modeName = tostring(edc.mode or "Balanced")
    local allGroupsEnabled = true
    local allowBuildingBus = true
    local allowFullBuildingPower = false
    local hasPoweredLoad = ((tonumber(edc.poweredConsumerCount) or 0) > 0)
        or (virtualDemandNow > 0 and demandAllowsPower)
    local hasAuthorizedEnergy = ((tonumber(authorizedWatts) or 0) > 0) or ((tonumber(storage) or 0) > 0)
    if SIMPLE_OUTPUT_ONLY_MODE then
        -- ON/OFF-only mode: keep house power tied to real ERS availability only.
        -- In MP, aggregate demand can spike as more chunks are loaded; avoid all-or-nothing cutoff.
        allowFullBuildingPower = (source == "ERS")
        modeName = "OnOff"
    else
        local manualMode = (modeName == "Manual")
        local toggles = edc.toggles or {}
        allGroupsEnabled = (toggles.refrigeration ~= false)
            and (toggles.lights ~= false)
            and (toggles.cooking ~= false)
            and (toggles.industrial ~= false)
        -- In Manual mode with any group disabled, avoid full-building bus to prevent cross-group leakage.
        allowBuildingBus = (not manualMode) or allGroupsEnabled
        allowFullBuildingPower = (source == "ERS")
            and allowBuildingBus
            and demandAllowsPower
            and hasAuthorizedEnergy
            and (
                virtualDemandNow <= 0
                or (tonumber(authorizedWatts) or 0) >= virtualDemandNow
                or hasPoweredLoad
            )
    end
    local desiredPowered = allowFullBuildingPower

    edc.production = snapshot.production or 0
    edc.storage = snapshot.storage or 0
    edc.energyAvailable = authorizedWatts
    edc.controllerHasEnergy = hasEnergy
    edc.authorizedPowerWatts = authorizedWatts
    edc.powerSource = source

    local releasedToVanilla = false
    if ERS and ERS.BuildingPower and ERS.BuildingPower.applyPowerState then
        if source == "ERS" then
            ERS.BuildingPower.applyPowerState(edc, allowFullBuildingPower, forceApply == true)
        elseif source == "Off" then
            ERS.BuildingPower.applyPowerState(edc, false, true)
        elseif edc._ersBuildingPowerState == true then
            -- Release ERS hold once; do not keep forcing false while vanilla fallback is active.
            ERS.BuildingPower.applyPowerState(edc, false, true)
            releasedToVanilla = true
        end
    end

    if source == "ERS" then
        Server.SetBuildingElectricity(edc, allowFullBuildingPower)
    elseif source == "Off" then
        Server.SetBuildingElectricity(edc, false)
    elseif releasedToVanilla then
        Server.SetBuildingElectricity(edc, false)
    end

    local logKey = edc.id
    if not logKey then
        logKey = tostring(edc.x) .. ":" .. tostring(edc.y) .. ":" .. tostring(edc.z)
    end
    local signature = tostring(source) .. ":" .. tostring(desiredPowered)
    if Server._powerStateLogById[logKey] ~= signature then
        Server._powerStateLogById[logKey] = signature
        print("[SPESS][BuildingPower] mode=TOTAL reason=" .. tostring(reason or "n/a")
            .. " id=" .. tostring(edc.id)
            .. " output=" .. tostring(edc.outputEnabled ~= false)
            .. " source=" .. tostring(source)
            .. " desired=" .. tostring(desiredPowered)
            .. " demand=" .. tostring(math.floor(tonumber(edc._ersVirtualDemand) or 0))
            .. " demandAllow=" .. tostring(demandAllowsPower)
            .. " available=" .. tostring(math.floor(available))
            .. " production=" .. tostring(math.floor(production))
            .. " storage=" .. tostring(math.floor(storage))
            .. " authorized=" .. tostring(math.floor(authorizedWatts))
            .. " mode=" .. tostring(modeName)
            .. " allGroupsEnabled=" .. tostring(allGroupsEnabled)
            .. " bus=" .. tostring(allowFullBuildingPower)
            .. " vgenChunks=" .. tostring(edc._ersVirtualGeneratorChunkCount or 0))
    end

    return source
end

function Server.UpdateEDC(edc)
    if not edc then
        return
    end
    Server.EnsureEDCOptimizationState(edc)
    if edc.outputEnabled == nil then
        edc.outputEnabled = true
    end
    local offIdleSkip = isControllerOffIdleSkip(edc)
    local debugChunksCount = 0
    local squaresCount = 0
    if isVanillaLikeEnergyFlow() then
        if not offIdleSkip then
            debugChunksCount = Server.ApplyDebugVanillaLikePower(edc, false)
        end
    else
        if not offIdleSkip then
            Server.ForceBuildingHasElectricityOff(edc)
            -- Bus eléctrico del área (independiente de grupos).
            squaresCount = Server.ApplySquarePowerBus(edc)
        end
    end

    if isVanillaLikeEnergyFlow() then
        local snapshot = Server.GetEnergySnapshot(edc)
        local groups = resolveConsumerGroups(edc)
        if not offIdleSkip then
            refreshRefrigerationObjectCache(edc, groups, false)
        end

        local mode = edc.mode or "Balanced"
        if mode == "Manual" and not EnergyRouting.GetConfigValue("AllowManualOverride") then
            mode = "Balanced"
            edc.mode = mode
        end
        applyModePresetToggles(edc, mode)

        edc.toggles = edc.toggles or EnergyRouting.MakeDefaultToggles()
        for _, group in ipairs(EnergyRouting.GroupsList or {}) do
            if edc.toggles[group.id] == nil then
                edc.toggles[group.id] = group.defaultToggle
            end
        end

        local passiveLoadW, passiveConsumerCount = 0, 0
        if (edc.outputEnabled ~= false) and (tonumber(edc.detectedConsumerCount) or 0) > 0 then
            passiveLoadW, passiveConsumerCount = collectPassiveTelevisionLoad(edc)
        end
        local passiveActiveGroups = getActiveGroupsForPassiveLoad(edc, mode)
        local passiveIdleConsumption = 0
        local passiveGroupCount = 0
        if passiveLoadW > 0 then
            if #passiveActiveGroups > 0 then
                local share = passiveLoadW / #passiveActiveGroups
                for _, groupId in ipairs(passiveActiveGroups) do
                    groups[groupId] = groups[groupId] or { devices = {}, requiredPower = 0 }
                    groups[groupId].requiredPower =
                        capTotalWattsForGroup(groupId, (tonumber(groups[groupId].requiredPower) or 0) + share)
                end
                passiveGroupCount = #passiveActiveGroups
            else
                passiveIdleConsumption = passiveLoadW
            end
        end

        local groupStates, totalConsumption, remainingEnergy, poweredConsumerCount, groupConsumption, groupDemand =
            applyModeLogic(edc, snapshot, groups, mode)

        local idleConsumption = 0
        if edc.outputEnabled ~= false then
            idleConsumption = CONTROLLER_IDLE_CONSUMPTION
        end
        idleConsumption = idleConsumption + passiveIdleConsumption
        totalConsumption = (tonumber(totalConsumption) or 0) + idleConsumption

        edc.production = snapshot.production or 0
        edc.storage = snapshot.storage or 0
        edc.capacity = snapshot.capacity or snapshot.totalCapacity or 0
        edc.totalCapacity = snapshot.totalCapacity or snapshot.capacity or 0
        edc.solarCapacity = snapshot.solarCapacity or 0
        edc.windCapacity = snapshot.windCapacity or 0
        edc.solarProduction = snapshot.solarProduction or 0
        edc.windProduction = snapshot.windProduction or 0
        edc.hydroProduction = snapshot.hydroProduction or 0
        edc.otherProduction = snapshot.otherProduction or 0
        edc.solarStorage = snapshot.solarStorage or 0
        edc.windStorage = snapshot.windStorage or 0
        edc.solarBonusPercent = tonumber(snapshot.solarBonusPercent) or 0
        edc.windBonusPercent = tonumber(snapshot.windBonusPercent) or 0
        edc.weather = snapshot.weather or "Unknown"

        edc.groupStates = groupStates or {}
        edc.groupConsumption = groupConsumption or {}
        edc.groupDemand = groupDemand or {}
        edc.poweredConsumerCount = poweredConsumerCount or 0

        edc.energyAvailable = remainingEnergy or 0
        edc.authorizedPowerWatts = (snapshot.available or 0) + (snapshot.production or 0)
        edc.controllerHasEnergy = ((snapshot.available or 0) > 0) or ((snapshot.production or 0) > 0)
        edc.idleConsumption = idleConsumption
        edc.passiveConsumption = passiveLoadW or 0
        edc.passiveConsumerCount = passiveConsumerCount or 0
        edc.passiveDistributedGroupCount = passiveGroupCount or 0
        edc.consumption = totalConsumption or 0
        edc.consumptionTotal = edc.consumption
        edc.totalConsumptionRate = tonumber(totalConsumption) or 0
        edc.balance = (edc.production or 0) - (edc.consumptionTotal or 0)
        edc.usesBattery = (edc.outputEnabled ~= false)
            and ((edc.consumptionTotal or 0) > (edc.production or 0))
            and ((edc.storage or 0) > 0)
        edc.hasPower = (edc.outputEnabled ~= false)
            and (((edc.authorizedPowerWatts or 0) > 0) or ((edc.storage or 0) > 0))
        edc.powerSource = (edc.outputEnabled ~= false) and "ERS" or "Off"
        edc.consumers = buildConsumersSnapshot(groups)
        local sqStartMs = getPerfNowMs()
        edc.energizedSquaresMap, edc.energizedSquares, edc.energizedSquaresSignature =
            buildEnergizedSquares(groups, edc.groupStates, edc.outputEnabled ~= false)
        local sqDtMs = getPerfNowMs() - sqStartMs
        if sqDtMs > PERF_WARN_MS then
            print("[ERS][PERF] buildEnergizedSquares took " .. tostring(sqDtMs)
                .. "ms id=" .. tostring(edc.id)
                .. " squares=" .. tostring(edc.energizedSquares and #edc.energizedSquares or 0))
        end

        edc._ersVirtualDemand = nil
        edc._ersVirtualAvailable = nil
        edc._ersDemandAllowPower = nil

        if snapshot.panelCount ~= nil then
            edc.panelCount = snapshot.panelCount
        end
        if snapshot.batteryCount ~= nil then
            edc.batteryCount = snapshot.batteryCount
        end
        if snapshot.windCount ~= nil then
            edc.windCount = snapshot.windCount
        end
        if snapshot.hydroCount ~= nil then
            edc.hydroCount = snapshot.hydroCount
        end
        if snapshot.otherCount ~= nil then
            edc.otherCount = snapshot.otherCount
        end
        if snapshot.windBatteryCount ~= nil then
            edc.windBatteryCount = snapshot.windBatteryCount
        end

        if Server._inTick and EnergyController and EnergyController.Server and EnergyController.Server.ApplyConsumption then
            local ok, updatedStorage = pcall(EnergyController.Server.ApplyConsumption, edc, totalConsumption, tonumber(edc.production) or 0)
            if ok and type(updatedStorage) == "number" then
                edc.storage = updatedStorage
            end
        end

        Server.CacheRoutingStateOnController(edc)

        local logKey = edc.id or (tostring(edc.x) .. ":" .. tostring(edc.y) .. ":" .. tostring(edc.z))
        local sig = tostring(edc.outputEnabled ~= false) .. ":" .. tostring(debugChunksCount or 0)
            .. ":" .. tostring(edc.detectedConsumerCount or 0)
            .. ":" .. makeGroupDemandSignature(edc.groupDemand)
        local debugEnabled = EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("DebugUI") == true
        if debugEnabled and Server._squareBusLogById[logKey] ~= sig then
            Server._squareBusLogById[logKey] = sig
            print("[SPESS][VanillaLikeDebug] id=" .. tostring(edc.id)
                .. " output=" .. tostring(edc.outputEnabled ~= false)
                .. " chunks=" .. tostring(debugChunksCount or 0)
                .. " detected=" .. tostring(edc.detectedConsumerCount or 0)
                .. " demandR=" .. tostring(math.floor(tonumber(edc.groupDemand.refrigeration) or 0))
                .. " demandL=" .. tostring(math.floor(tonumber(edc.groupDemand.lights) or 0))
                .. " demandC=" .. tostring(math.floor(tonumber(edc.groupDemand.cooking) or 0))
                .. " demandI=" .. tostring(math.floor(tonumber(edc.groupDemand.industrial) or 0)))
        end

        Server.SaveModData()
        Server.BroadcastState(edc)
        return
    end

    local snapshot = Server.GetEnergySnapshot(edc)
    local useBuildingPowerMode = SIMPLE_OUTPUT_ONLY_MODE or Server.IsTotalBuildingPowerMode()
    local groups = resolveConsumerGroups(edc)
    if not offIdleSkip then
        refreshRefrigerationObjectCache(edc, groups, false)
    end
    local countLogKey = edc.id or (tostring(edc.x) .. ":" .. tostring(edc.y) .. ":" .. tostring(edc.z))
    if Server._consumerCountLogById[countLogKey] ~= edc.detectedConsumerCount then
        Server._consumerCountLogById[countLogKey] = edc.detectedConsumerCount
        print("[SPESS][Consumers] id=" .. tostring(edc.id)
            .. " detected=" .. tostring(edc.detectedConsumerCount)
            .. " mode=" .. tostring(edc.mode or "Balanced")
            .. " scanSource=" .. tostring(edc._lastScanSource or "unknown"))
    end

    local mode = edc.mode or "Balanced"
    if SIMPLE_OUTPUT_ONLY_MODE then
        -- ON/OFF-only behavior: keep toggles/group UI read-only and always ON internally.
        edc.mode = "Balanced"
        mode = edc.mode
        forceAllTogglesOn(edc)
    else
        if mode == "Manual" and not EnergyRouting.GetConfigValue("AllowManualOverride") then
            mode = "Balanced"
            edc.mode = mode
        end
        applyModePresetToggles(edc, mode)

        edc.toggles = edc.toggles or EnergyRouting.MakeDefaultToggles()
        for _, group in ipairs(EnergyRouting.GroupsList) do
            if edc.toggles[group.id] == nil then
                edc.toggles[group.id] = group.defaultToggle
            end
        end
    end

    local passiveLoadW, passiveConsumerCount = 0, 0
    if (edc.outputEnabled ~= false) and (tonumber(edc.detectedConsumerCount) or 0) > 0 then
        passiveLoadW, passiveConsumerCount = collectPassiveTelevisionLoad(edc)
    end
    local passiveActiveGroups = getActiveGroupsForPassiveLoad(edc, mode)
    local groupStates, totalConsumption, remainingEnergy, poweredConsumerCount, groupConsumption, groupDemand
    local passiveIdleConsumption = 0
    local passiveGroupCount = 0

    if SIMPLE_OUTPUT_ONLY_MODE then
        groupStates = {}
        groupConsumption = {}
        groupDemand = {}

        local demandByGroups = 0
        for _, group in ipairs(EnergyRouting.GroupsList or {}) do
            local groupData = groups[group.id] or { devices = {}, requiredPower = 0 }
            local required = tonumber(groupData.requiredPower) or 0
            if required < 0 then
                required = 0
            end
            required = capTotalWattsForGroup(group.id, required)
            groupDemand[group.id] = required
            groupConsumption[group.id] = 0
            groupStates[group.id] = "disabled"
            demandByGroups = demandByGroups + required
        end

        local passiveDemand = math.max(0, tonumber(passiveLoadW) or 0)
        local totalDemand = demandByGroups + passiveDemand
        local hasEnoughEnergy, authorizedWatts = Server.GetAuthorizedBuildingPower(edc, snapshot)
        local outputOn = (edc.outputEnabled ~= false)
        local canPowerAll = outputOn and hasEnoughEnergy

        if canPowerAll then
            for _, group in ipairs(EnergyRouting.GroupsList or {}) do
                groupStates[group.id] = "powered"
                groupConsumption[group.id] = groupDemand[group.id] or 0
            end
            totalConsumption = demandByGroups + passiveDemand
            poweredConsumerCount = tonumber(edc.detectedConsumerCount) or countDevicesInGroups(groups)
        else
            totalConsumption = 0
            poweredConsumerCount = 0
        end

        remainingEnergy = math.max(0, (tonumber(authorizedWatts) or 0) - (canPowerAll and totalDemand or 0))
        edc._ersVirtualDemand = totalDemand
        edc._ersVirtualAvailable = tonumber(authorizedWatts) or 0
        edc._ersDemandAllowPower = canPowerAll

        if not offIdleSkip then
            if canPowerAll then
                applyGroupStatesToConsumers(groups, groupStates, groupDemand)
            else
                for _, group in ipairs(EnergyRouting.GroupsList or {}) do
                    local groupData = groups[group.id] or nil
                    if groupData and groupData.devices then
                        Server.PowerOffGroup(groupData.devices)
                    end
                end
            end
            if edc.outputEnabled == false and edc._ersOffEnforcePending == true then
                edc._ersOffEnforcePending = nil
            end
        end
    else
        -- Legacy priority/group routing (kept for future reactivation).
        if useBuildingPowerMode then
            groupStates = {}
            groupConsumption = {}
            groupDemand = {}
            local hasEnoughEnergy, authorizedWatts, storage = Server.GetAuthorizedBuildingPower(edc, snapshot)
            local availableTotal = authorizedWatts
            if availableTotal <= 0 then
                availableTotal = tonumber(storage) or 0
            end

            local virtualDemand = 0
            local manualHasEnabledGroup = false
            for _, group in ipairs(EnergyRouting.GroupsList) do
                local groupData = groups[group.id] or { devices = {}, requiredPower = 0 }
                local required = tonumber(groupData.requiredPower) or 0
                if required < 0 then
                    required = 0
                end
                required = capTotalWattsForGroup(group.id, required)
                local eligible = isGroupEligibleForMode(edc, group.id, mode)
                groupDemand[group.id] = required
                if eligible then
                    if mode == "Manual" then
                        manualHasEnabledGroup = true
                    end
                    virtualDemand = virtualDemand + required
                end
            end
            if passiveLoadW > 0 and #passiveActiveGroups > 0 then
                virtualDemand = virtualDemand + passiveLoadW
            end

            edc._ersVirtualDemand = virtualDemand
            edc._ersVirtualAvailable = availableTotal
            local manualAllowsPower = (mode ~= "Manual") or manualHasEnabledGroup
            local availableForGroups = math.max(0, tonumber(availableTotal) or 0)
            if edc.outputEnabled == false or not hasEnoughEnergy or not manualAllowsPower then
                availableForGroups = 0
            end

            for _, group in ipairs(EnergyRouting.GroupsList) do
                groupStates[group.id] = "disabled"
                groupConsumption[group.id] = 0
            end

            totalConsumption = 0
            poweredConsumerCount = 0
            for _, groupId in ipairs(getGroupOrderForMode(mode)) do
                local groupData = groups[groupId] or { devices = {}, requiredPower = 0 }
                local required = tonumber(groupData.requiredPower) or 0
                if required < 0 then
                    required = 0
                end
                required = capTotalWattsForGroup(groupId, required)
                local eligible = isGroupEligibleForMode(edc, groupId, mode)

                if hasEnoughEnergy
                    and availableForGroups > 0
                    and eligible
                    and edc.outputEnabled ~= false
                    and manualAllowsPower then
                    if availableForGroups >= required then
                        groupStates[groupId] = "powered"
                        groupConsumption[groupId] = required
                        availableForGroups = availableForGroups - required
                        totalConsumption = totalConsumption + required
                        poweredConsumerCount = poweredConsumerCount + #((groupData and groupData.devices) or {})
                    else
                        local minWatts = getGroupMinConsumerWatts(groupId, groupData)
                        if minWatts and availableForGroups >= minWatts then
                            groupStates[groupId] = "limited"
                            groupConsumption[groupId] = availableForGroups
                            totalConsumption = totalConsumption + availableForGroups
                            poweredConsumerCount = poweredConsumerCount + 1
                            availableForGroups = 0
                        else
                            groupStates[groupId] = "disabled"
                            groupConsumption[groupId] = 0
                        end
                    end
                else
                    groupStates[groupId] = "disabled"
                    groupConsumption[groupId] = 0
                end
            end

            remainingEnergy = math.max(0, availableForGroups)
            local anyGroupPowered = poweredConsumerCount > 0
            edc._ersDemandAllowPower = (edc.outputEnabled ~= false)
                and hasEnoughEnergy
                and manualAllowsPower
                and (anyGroupPowered or virtualDemand <= 0)

            -- Apply real per-consumer state in total building mode too.
            if not offIdleSkip then
                applyGroupStatesToConsumers(groups, groupStates, groupConsumption)
                if edc.outputEnabled == false and edc._ersOffEnforcePending == true then
                    edc._ersOffEnforcePending = nil
                end
            end
        else
            groupStates, totalConsumption, remainingEnergy, poweredConsumerCount, groupConsumption, groupDemand =
                applyModeLogic(edc, snapshot, groups, mode)
            edc._ersVirtualDemand = nil
            edc._ersVirtualAvailable = nil
            edc._ersDemandAllowPower = nil
        end

        passiveIdleConsumption, passiveGroupCount = redistributePassiveLoad(
            edc,
            mode,
            groupConsumption or {},
            groupDemand or {},
            passiveLoadW,
            passiveActiveGroups
        )
        local passiveSharedConsumption = math.max(0, (tonumber(passiveLoadW) or 0) - (tonumber(passiveIdleConsumption) or 0))
        if not useBuildingPowerMode and passiveSharedConsumption > 0 then
            totalConsumption = (tonumber(totalConsumption) or 0) + passiveSharedConsumption
        end
    end

    local idleConsumption = 0
    if edc.outputEnabled ~= false then
        idleConsumption = CONTROLLER_IDLE_CONSUMPTION
    end
    idleConsumption = idleConsumption + passiveIdleConsumption
    totalConsumption = (tonumber(totalConsumption) or 0) + idleConsumption

    edc.groupStates = groupStates
    edc.energyAvailable = remainingEnergy or 0
    edc.production = snapshot.production or 0
    edc.storage = snapshot.storage or 0
    edc.capacity = snapshot.capacity or snapshot.totalCapacity or 0
    edc.totalCapacity = snapshot.totalCapacity or snapshot.capacity or 0
    edc.solarCapacity = snapshot.solarCapacity or 0
    edc.windCapacity = snapshot.windCapacity or 0
    edc.solarProduction = snapshot.solarProduction or 0
    edc.windProduction = snapshot.windProduction or 0
    edc.hydroProduction = snapshot.hydroProduction or 0
    edc.otherProduction = snapshot.otherProduction or 0
    edc.solarStorage = snapshot.solarStorage or 0
    edc.windStorage = snapshot.windStorage or 0
    edc.solarBonusPercent = tonumber(snapshot.solarBonusPercent) or 0
    edc.windBonusPercent = tonumber(snapshot.windBonusPercent) or 0
    edc.weather = snapshot.weather or "Unknown"
    edc.idleConsumption = idleConsumption
    edc.passiveConsumption = passiveLoadW or 0
    edc.passiveConsumerCount = passiveConsumerCount or 0
    edc.passiveDistributedGroupCount = passiveGroupCount or 0
    edc.consumption = totalConsumption or 0
    edc.consumptionTotal = edc.consumption
    edc.totalConsumptionRate = tonumber(totalConsumption) or 0
    edc.groupConsumption = groupConsumption or {}
    edc.groupDemand = groupDemand or {}
    edc.poweredConsumerCount = poweredConsumerCount or 0
    local demandSignature = tostring(edc.detectedConsumerCount or 0) .. "|"
        .. makeGroupDemandSignature(edc.groupDemand)
    if Server._consumerDemandLogById[countLogKey] ~= demandSignature then
        Server._consumerDemandLogById[countLogKey] = demandSignature
        print("[SPESS][Consumers] demand id=" .. tostring(edc.id)
            .. " detected=" .. tostring(edc.detectedConsumerCount or 0)
            .. " scanSource=" .. tostring(edc._lastScanSource or "unknown")
            .. " refrigeration=" .. tostring(math.floor(tonumber(edc.groupDemand.refrigeration) or 0))
            .. " lights=" .. tostring(math.floor(tonumber(edc.groupDemand.lights) or 0))
            .. " cooking=" .. tostring(math.floor(tonumber(edc.groupDemand.cooking) or 0))
            .. " industrial=" .. tostring(math.floor(tonumber(edc.groupDemand.industrial) or 0)))
    end

    local diagParts = {
        tostring(math.floor(tonumber(edc.energyAvailable) or 0)),
    }
    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
        diagParts[#diagParts + 1] = tostring(group.id) .. ":" .. tostring(edc.groupStates and edc.groupStates[group.id] or "nil")
    end
    local diagSignature = table.concat(diagParts, "|")
    if Server._groupStateDiagLogById[countLogKey] ~= diagSignature then
        Server._groupStateDiagLogById[countLogKey] = diagSignature
        print("[SPESS][Diag] id=" .. tostring(edc.id)
            .. " EnergyAvailable=" .. tostring(math.floor(tonumber(edc.energyAvailable) or 0)))
        for _, group in ipairs(EnergyRouting.GroupsList or {}) do
            print("[SPESS][Diag] Group=" .. tostring(group.id)
                .. " State=" .. tostring(edc.groupStates and edc.groupStates[group.id] or "nil")
                .. " Required=" .. tostring(math.floor(tonumber(edc.groupDemand and edc.groupDemand[group.id]) or 0)))
        end
    end

    edc.controllerHasEnergy = ((snapshot.available or 0) > 0) or ((snapshot.production or 0) > 0)
    edc.authorizedPowerWatts = (snapshot.available or 0) + (snapshot.production or 0)
    local balanceDemand = (edc.consumptionTotal or 0)
    if useBuildingPowerMode and edc._ersVirtualDemand ~= nil then
        balanceDemand = (tonumber(edc._ersVirtualDemand) or 0) + idleConsumption
    end
    edc.balance = (edc.production or 0) - balanceDemand
    edc.usesBattery = (edc.outputEnabled ~= false)
        and ((edc.consumptionTotal or 0) > (edc.production or 0))
        and ((edc.storage or 0) > 0)
    if useBuildingPowerMode then
        edc.hasPower = (edc.outputEnabled ~= false)
            and (edc._ersDemandAllowPower == true)
            and (((edc.authorizedPowerWatts or 0) > 0) or ((snapshot.storage or 0) > 0))
    else
        edc.hasPower = (edc.outputEnabled ~= false)
            and (((snapshot.available or 0) > 0) or ((edc.poweredConsumerCount or 0) > 0))
    end
    edc.consumers = buildConsumersSnapshot(groups)
    local sqStartMs = getPerfNowMs()
    edc.energizedSquaresMap, edc.energizedSquares, edc.energizedSquaresSignature =
        buildEnergizedSquares(groups, edc.groupStates, edc.outputEnabled ~= false)
    local sqDtMs = getPerfNowMs() - sqStartMs
    if sqDtMs > PERF_WARN_MS then
        print("[ERS][PERF] buildEnergizedSquares took " .. tostring(sqDtMs)
            .. "ms id=" .. tostring(edc.id)
            .. " squares=" .. tostring(edc.energizedSquares and #edc.energizedSquares or 0))
    end

    if snapshot.panelCount ~= nil then
        edc.panelCount = snapshot.panelCount
    else
        edc.panelCount = nil
    end

    if snapshot.batteryCount ~= nil then
        edc.batteryCount = snapshot.batteryCount
    else
        edc.batteryCount = nil
    end

    if snapshot.windCount ~= nil then
        edc.windCount = snapshot.windCount
    else
        edc.windCount = nil
    end

    if snapshot.hydroCount ~= nil then
        edc.hydroCount = snapshot.hydroCount
    else
        edc.hydroCount = nil
    end

    if snapshot.otherCount ~= nil then
        edc.otherCount = snapshot.otherCount
    else
        edc.otherCount = nil
    end

    if snapshot.windBatteryCount ~= nil then
        edc.windBatteryCount = snapshot.windBatteryCount
    else
        edc.windBatteryCount = nil
    end

    Server.CacheRoutingStateOnController(edc)

    local storageConsumed = false
    local totalProductionNow = tonumber(edc.production) or 0
    local shouldApplyStorageFlow = (totalConsumption > 0) or (totalProductionNow > 0)
    if Server._inTick and shouldApplyStorageFlow then
        local edcId = edc and edc.id or nil
        if type(edcId) == "string" and string.find(edcId, "^network_")
            and EnergyController and EnergyController.Server
            and EnergyController.Server.ApplyConsumption then
            local ok, updatedStorage = pcall(EnergyController.Server.ApplyConsumption, edc, totalConsumption, totalProductionNow)
            if ok and type(updatedStorage) == "number" then
                edc.storage = updatedStorage
                if EnergyController.Server.GetControllerById then
                    local controllerObj = EnergyController.Server.GetControllerById(edcId)
                    local md = controllerObj and getObjectModData(controllerObj) or nil
                    local controller = (md and type(md.energyController) == "table") and md.energyController or nil
                    if controller then
                        if tonumber(controller.solarStorage) ~= nil then
                            edc.solarStorage = tonumber(controller.solarStorage) or edc.solarStorage or 0
                        end
                        if tonumber(controller.windStorage) ~= nil then
                            edc.windStorage = tonumber(controller.windStorage) or edc.windStorage or 0
                        end
                        if tonumber(controller.totalStorage) ~= nil then
                            edc.storage = tonumber(controller.totalStorage) or edc.storage or 0
                        end
                    end
                end
                storageConsumed = true
            end
        elseif type(edcId) == "string" and string.find(edcId, "^energy_net_")
            and EnergyNetwork and EnergyNetwork.Server
            and EnergyNetwork.Server.ApplyConsumption then
            local ok, updatedStorage = pcall(EnergyNetwork.Server.ApplyConsumption, edc, totalConsumption, totalProductionNow)
            if ok and type(updatedStorage) == "number" then
                edc.storage = updatedStorage
                storageConsumed = true
            end
        end

        if not storageConsumed then
            local consumers = Server.energyConsumers
            if (not consumers or #consumers == 0) and Server.energyConsumer then
                consumers = { Server.energyConsumer }
            end
            if consumers and #consumers > 0 then
                for _, consumer in ipairs(consumers) do
                    local ok, updatedStorage = pcall(consumer, edc, totalConsumption, totalProductionNow)
                    if ok and type(updatedStorage) == "number" then
                        edc.storage = updatedStorage
                        storageConsumed = true
                        break
                    end
                end
            end
        end

        if storageConsumed then
            edc.energyAvailable = (tonumber(edc.production) or 0) + (tonumber(edc.storage) or 0)
            edc.authorizedPowerWatts = edc.energyAvailable
            edc.controllerHasEnergy = (edc.energyAvailable or 0) > 0
            edc.usesBattery = (edc.outputEnabled ~= false)
                and ((edc.consumptionTotal or 0) > (edc.production or 0))
                and ((edc.storage or 0) > 0)
            if useBuildingPowerMode then
                edc.hasPower = (edc.outputEnabled ~= false)
                    and (edc._ersDemandAllowPower == true)
                    and (((edc.authorizedPowerWatts or 0) > 0) or ((edc.storage or 0) > 0))
            else
                edc.hasPower = (edc.outputEnabled ~= false)
                    and (((edc.authorizedPowerWatts or 0) > 0) or ((edc.poweredConsumerCount or 0) > 0))
            end
        end
    end

    logEnergy("UpdateEDC id=" .. tostring(edc.id)
        .. " production=" .. tostring(math.floor(edc.production or 0))
        .. " solarProduction=" .. tostring(math.floor(edc.solarProduction or 0))
        .. " windProduction=" .. tostring(math.floor(edc.windProduction or 0))
        .. " storage=" .. tostring(math.floor(edc.storage or 0))
        .. " solarStorage=" .. tostring(math.floor(edc.solarStorage or 0))
        .. " windStorage=" .. tostring(math.floor(edc.windStorage or 0))
        .. " available=" .. tostring(math.floor(edc.energyAvailable or 0))
        .. " consumption=" .. tostring(math.floor(edc.consumption or 0))
        .. " poweredConsumers=" .. tostring(edc.poweredConsumerCount or 0)
        .. " panels=" .. tostring(edc.panelCount or 0)
        .. " batteries=" .. tostring(edc.batteryCount or 0)
        .. " turbines=" .. tostring(edc.windCount or 0)
        .. " hydro=" .. tostring(edc.hydroCount or 0)
        .. " windBatteries=" .. tostring(edc.windBatteryCount or 0)
        .. " detectedConsumers=" .. tostring(edc.detectedConsumerCount or 0)
        .. " virtualDemand=" .. tostring(math.floor(tonumber(edc._ersVirtualDemand) or 0))
        .. " demandAllow=" .. tostring(edc._ersDemandAllowPower)
        .. " weather=" .. tostring(edc.weather))

    if useBuildingPowerMode then
        Server.ApplyTotalBuildingPowerState(edc, snapshot, "UpdateEDC", true)
        -- FIXED: Enforce groups always if outputEnabled is true, 
        -- but respecting the computed states from UpdateEDC.
        Server.EnforceManualConsumerGroups(edc, groups)
    elseif ERS and ERS.BuildingPower and ERS.BuildingPower.applyControllerDecision then
        local source = ERS.BuildingPower.applyControllerDecision(edc)
        edc.powerSource = source
        if source == "ERS" then
            -- Preserve non-total mode behavior (object-level routing only).
            Server.SetBuildingElectricity(edc, false)
        elseif source == "Off" then
            Server.SetBuildingElectricity(edc, false)
        end
    end

    Server.UpdateVanillaGeneratorFallback(edc)
    Server.SaveModData()
    Server.BroadcastState(edc)
end

function Server.SerializeEDC(edc, options)
    options = options or {}
    local includeSquares = options.includeSquares == true
    local role = "controller"
    local panelCount = edc and edc.panelCount or nil
    local batteryCount = edc and edc.batteryCount or nil
    local windCount = edc and edc.windCount or nil
    local hydroCount = edc and edc.hydroCount or nil
    local otherCount = edc and edc.otherCount or nil
    local windBatteryCount = edc and edc.windBatteryCount or nil
    local function countUnique(list)
        local count = 0
        local seen = {}
        if not list then
            return 0
        end
        for k, v in pairs(list) do
            if type(k) == "string" then
                if not seen[k] then
                    seen[k] = true
                    count = count + 1
                end
            elseif type(v) == "string" then
                if not seen[v] then
                    seen[v] = true
                    count = count + 1
                end
            end
        end
        return count
    end
    if panelCount == nil or batteryCount == nil or windCount == nil or hydroCount == nil
        or otherCount == nil or windBatteryCount == nil then
        if EnergyController and EnergyController.Server and EnergyController.Server.GetControllerById then
            local controllerObj = EnergyController.Server.GetControllerById(edc.id)
            if controllerObj then
                local md = getObjectModData(controllerObj)
                local controller = (md and type(md.energyController) == "table") and md.energyController or nil
                if controller then
                    panelCount = panelCount or countUnique(controller.panels)
                    batteryCount = batteryCount or countUnique(controller.batteries)
                    windCount = windCount or countUnique(controller.windTurbines)
                    hydroCount = hydroCount or countUnique(controller.hydroTurbines)
                    windBatteryCount = windBatteryCount or countUnique(controller.windBatteries)
                end
            end
        end
    end
    panelCount = panelCount or 0
    batteryCount = batteryCount or 0
    windCount = windCount or 0
    hydroCount = hydroCount or 0
    otherCount = otherCount or 0
    windBatteryCount = windBatteryCount or 0
    normalizeEdcBatteries(edc)
    normalizeBatteryRoles(edc)
    local batteries = {}
    local energizedSquares = nil
    if includeSquares then
        energizedSquares = cloneEnergizedSquares(edc and edc.energizedSquares)
    end
    for _, entry in ipairs(edc.batteries or {}) do
        table.insert(batteries, { id = entry.id, role = entry.role })
    end
    return {
        id = edc.id,
        x = edc.x,
        y = edc.y,
        z = edc.z,
        mode = edc.mode,
        outputEnabled = edc.outputEnabled ~= false,
        toggles = EnergyRouting.CloneTable(edc.toggles),
        groupStates = EnergyRouting.CloneTable(edc.groupStates),
        groupConsumption = EnergyRouting.CloneTable(edc.groupConsumption),
        groupDemand = EnergyRouting.CloneTable(edc.groupDemand),
        consumptionTotal = edc.consumptionTotal or edc.consumption or 0,
        consumption = edc.consumption or 0,
        detectedConsumerCount = edc.detectedConsumerCount or 0,
        balance = edc.balance or 0,
        usesBattery = edc.usesBattery == true,
        powerSource = edc.powerSource or nil,
        energyAvailable = edc.energyAvailable or 0,
        production = edc.production or 0,
        storage = edc.storage or 0,
        capacity = edc.capacity or edc.totalCapacity or 0,
        totalCapacity = edc.totalCapacity or edc.capacity or 0,
        solarCapacity = edc.solarCapacity or 0,
        windCapacity = edc.windCapacity or 0,
        solarProduction = edc.solarProduction or 0,
        windProduction = edc.windProduction or 0,
        hydroProduction = edc.hydroProduction or 0,
        otherProduction = edc.otherProduction or 0,
        solarStorage = edc.solarStorage or 0,
        windStorage = edc.windStorage or 0,
        weather = edc.weather or "Unknown",
        role = role,
        panelCount = panelCount,
        batteryCount = batteryCount,
        windCount = windCount,
        hydroCount = hydroCount,
        otherCount = otherCount,
        windBatteryCount = windBatteryCount,
        solarBonusPercent = edc.solarBonusPercent or 0,
        windBonusPercent = edc.windBonusPercent or 0,
        batteries = batteries,
        energizedSquares = energizedSquares,
        energizedSquaresCount = edc and edc.energizedSquares and #edc.energizedSquares or 0,
        energizedSquaresSignature = tostring(edc and edc.energizedSquaresSignature or "0|"),
    }
end

function Server.BroadcastState(edc)
    if not edc then return end
    Server.EnsureEDCOptimizationState(edc)
    local sigStartMs = getPerfNowMs()
    local signature = buildRoutingStateSignature(edc)
    local sigDtMs = getPerfNowMs() - sigStartMs
    if sigDtMs > PERF_WARN_MS then
        print("[ERS][PERF] buildRoutingStateSignature(broadcast) took " .. tostring(sigDtMs)
            .. "ms id=" .. tostring(edc.id))
    end
    if Server._broadcastStateSignatureById[edc.id] == signature then
        return
    end
    Server._broadcastStateSignatureById[edc.id] = signature
    local roundedEnergy = roundToStep(tonumber(edc.storage) or 0, tonumber(edc.syncThreshold) or getConfiguredSyncThreshold())
    edc.lastSentEnergy = roundedEnergy

    local t0 = getPerfNowMs()
    local payload = { edc = Server.SerializeEDC(edc, { includeSquares = false }) }
    local dt = getPerfNowMs() - t0
    if dt > PERF_WARN_MS then
        print("[ERS][PERF] SerializeEDC(light) took " .. tostring(dt) .. "ms id=" .. tostring(edc.id))
    end
    local sqCount = edc and edc.energizedSquares and #edc.energizedSquares or 0
    if sqCount >= 500 then
        print("[ERS][PERF] energizedSquares=" .. tostring(sqCount) .. " id=" .. tostring(edc.id))
    end

    -- Single global broadcast to avoid duplicate per-player sends.
    sendServerCommand("EnergyRouting", "UpdateState", payload)
end

function Server.SendStateToPlayer(player, edc, includeSquares)
    if not edc then return end
    local withSquares = includeSquares == true

    Server._lastSendStateLog = Server._lastSendStateLog or {}
    local last = Server._lastSendStateLog[edc.id]
    local panelCount = edc.panelCount
    local batteryCount = edc.batteryCount
    local windCount = edc.windCount
    local hydroCount = edc.hydroCount
    local windBatteryCount = edc.windBatteryCount
    if not last or last.panelCount ~= panelCount or last.batteryCount ~= batteryCount
        or last.windCount ~= windCount or last.hydroCount ~= hydroCount
        or last.windBatteryCount ~= windBatteryCount then
        Server._lastSendStateLog[edc.id] = {
            panelCount = panelCount,
            batteryCount = batteryCount,
            windCount = windCount,
            hydroCount = hydroCount,
            windBatteryCount = windBatteryCount,
        }
        local debugEnabled = EnergyRouting and EnergyRouting.GetConfigValue and EnergyRouting.GetConfigValue("DebugUI") == true
        if debugEnabled then
            print("[EnergyRouting][Server] SendStateToPlayer id=" .. tostring(edc.id)
                .. " panelCount=" .. tostring(panelCount)
                .. " batteryCount=" .. tostring(batteryCount)
                .. " windCount=" .. tostring(windCount)
                .. " hydroCount=" .. tostring(hydroCount)
                .. " windBatteryCount=" .. tostring(windBatteryCount))
        end
    end

    local payload = { edc = Server.SerializeEDC(edc, { includeSquares = withSquares }) }
    -- Send only to requester (or local player fallback) to avoid extra traffic.
    if player then
        sendServerCommand(player, "EnergyRouting", "UpdateState", payload)
    else
        local localPlayer = (getSpecificPlayer and getSpecificPlayer(0)) or (getPlayer and getPlayer() or nil)
        if localPlayer then
            sendServerCommand(localPlayer, "EnergyRouting", "UpdateState", payload)
        end
    end
end

function Server.HandleToggleGroup(player, args)
    if SIMPLE_OUTPUT_ONLY_MODE then
        -- Legacy per-group manual toggles disabled in ON/OFF-only mode.
        return
    end
    if not args or not args.edcId or not args.groupId then
        return
    end

    local edc = Server.GetEDCById(args.edcId)
    if not edc then
        return
    end
    if edc.mode and edc.mode ~= "Manual" then
        Server.UpdateEDC(edc)
        return
    end

    edc.toggles = edc.toggles or EnergyRouting.MakeDefaultToggles()
    edc.toggles[args.groupId] = args.enabled and true or false
    Server.MarkConsumersDirty(edc, "toggle_group_" .. tostring(args.groupId))
    if args.groupId == "refrigeration" then
        edc._lastFullConsumerRescanAt = -1
        edc._refrigerationObjectCacheAt = -1
        edc._lastScannedGroups = nil
        edc._forceConsumerRescan = true
        edc._forceSquareRefresh = true
        edc._forceFullEnforce = true
    end

    if EnergyController and EnergyController.Server and EnergyController.Server.GetControllerById then
        local controllerObj = EnergyController.Server.GetControllerById(edc.id)
        if controllerObj then
            local md = getObjectModData(controllerObj)
            if not md then
                return
            end
            md.energyController = md.energyController or {}
            md.energyController.toggles = md.energyController.toggles or {}
            md.energyController.toggles[args.groupId] = edc.toggles[args.groupId]
            transmitObjectModData(controllerObj)
        end
    end

    Server.SaveModData()
    Server.UpdateEDC(edc)
    edc._forceFullEnforce = nil
    Server.ApplyRefrigerationImmediate(edc)
    Server.EnforceGroups(edc, edc.cachedGroups or edc._lastScannedGroups)
end

function Server.HandleSetMode(player, args)
    if SIMPLE_OUTPUT_ONLY_MODE then
        -- Legacy priority modes disabled in ON/OFF-only mode.
        return
    end
    if not args or not args.edcId or not args.mode then
        return
    end

    local edc = Server.GetEDCById(args.edcId)
    if not edc then
        return
    end

    edc.mode = args.mode
    applyModePresetToggles(edc, edc.mode)

    if EnergyController and EnergyController.Server and EnergyController.Server.GetControllerById then
        local controllerObj = EnergyController.Server.GetControllerById(edc.id)
        if controllerObj then
            local md = getObjectModData(controllerObj)
            if md then
                md.energyController = md.energyController or {}
                md.energyController.mode = edc.mode
                md.energyController.priorityMode = edc.mode
                md.energyController.toggles = EnergyRouting.CloneTable(edc.toggles or {})
                transmitObjectModData(controllerObj)
            end
        end
    end

    Server.SaveModData()
    Server.UpdateEDC(edc)
end

function Server.HandleSetOutputEnabled(player, args)
    if not args or not args.edcId then
        return
    end
    local edc = Server.GetEDCById(args.edcId)
    if not edc then
        return
    end
    local previous = (edc.outputEnabled ~= false)
    local requestedEnabled = args.enabled ~= false
    edc.outputEnabled = requestedEnabled
    if requestedEnabled then
        edc._ersSkipConsumerScanWhileOff = nil
        edc._ersOffEnforcePending = nil
        Server.MarkConsumersDirty(edc, "output_enabled_changed_on")
        edc._forceFullEnforce = true
    else
        edc._ersSkipConsumerScanWhileOff = true
        edc._ersOffEnforcePending = true
        edc.isDirty = false
        edc._forceConsumerRescan = nil
    end
    local current = (edc.outputEnabled ~= false)
    print("[SPESS][OutputToggle] id=" .. tostring(edc.id)
        .. " player=" .. tostring(player and player:getUsername() or "nil")
        .. " previous=" .. tostring(previous)
        .. " requested=" .. tostring(requestedEnabled)
        .. " current=" .. tostring(current))

    if EnergyController and EnergyController.Server and EnergyController.Server.GetControllerById then
        local controllerObj = EnergyController.Server.GetControllerById(edc.id)
        if controllerObj then
            local md = getObjectModData(controllerObj)
            if md then
                md.energyController = md.energyController or {}
                md.energyController.outputEnabled = edc.outputEnabled
                transmitObjectModData(controllerObj)
            end
        end
    end

    Server.SaveModData()
    Server.UpdateEDC(edc)
end

function Server.GetOrCreateEDC(edcId)
    edcId = Server.NormalizeEDCId(edcId)
    if not edcId then
        return nil
    end

    local edc = Server.GetEDCById(edcId)
    if edc then
        local controllerObj = Server.GetControllerObject and Server.GetControllerObject(edcId) or nil
        if not controllerObj then
            return nil
        end
        if controllerObj and syncEdcConfigWithController(edc, controllerObj) then
            Server.SaveModData()
        end
        return edc
    end

    if not EnergyNetwork or not EnergyNetwork.ParseCoordsFromId then
        return nil
    end

    local x, y, z = EnergyNetwork.ParseCoordsFromId(edcId, "network")
    if not x then
        return nil
    end

    local cell = getCell()
    if not cell then
        return nil
    end
    local sq = cell:getGridSquare(x, y, z)
    if not sq then
        return nil
    end

    local cObj = nil
    if EnergyController and EnergyController.Server and EnergyController.Server.GetControllerById then
        cObj = EnergyController.Server.GetControllerById(edcId)
    end
    if not cObj then
        return nil
    end

    edc = Server.RegisterEDC(sq, nil, edcId)

    local md = getObjectModData(cObj)
    if not md then
        return edc
    end
    if type(md.energyController) ~= "table" then
        md.energyController = {
            networkId = edcId,
            panels = {},
            batteries = {},
            windTurbines = {},
            hydroTurbines = {},
            windBatteries = {},
            priorityMode = "Balanced",
            mode = "Balanced",
            outputEnabled = true,
            toggles = {},
        }
    end
    md.energyController.mode = md.energyController.mode or md.energyController.priorityMode or edc.mode or "Balanced"
    md.energyController.priorityMode = md.energyController.priorityMode or md.energyController.mode
    if md.energyController.outputEnabled == nil then
        md.energyController.outputEnabled = (edc.outputEnabled ~= false)
    end
    if type(md.energyController.toggles) ~= "table" or not hasAnyEntries(md.energyController.toggles) then
        local fallbackToggles = edc.toggles
        if type(fallbackToggles) ~= "table" then
            fallbackToggles = EnergyRouting.MakeDefaultToggles and EnergyRouting.MakeDefaultToggles() or {}
        end
        md.energyController.toggles = EnergyRouting.CloneTable(fallbackToggles)
    end
    if syncEdcConfigWithController(edc, cObj) then
        Server.SaveModData()
    end
    transmitObjectModData(cObj)

    return edc
end

function Server.HandleRequestState(player, args)
    if not args or not args.edcId then
        return
    end

    local edc = Server.GetOrCreateEDC(args.edcId)
    if not edc then
        return
    end
    -- Refresh snapshot before responding so production/storage are current.
    if Server.UpdateEDC then
        Server.UpdateEDC(edc)
    end
    local includeSquares = args and args.includeSquares == true
    Server.SendStateToPlayer(player, edc, includeSquares)
end

function Server.OnClientCommand(module, command, player, args)
    if module ~= "EnergyRouting" and module ~= EnergyRouting.MOD_ID then
        return
    end

    if command == "ToggleGroup" then
        Server.HandleToggleGroup(player, args)
    elseif command == "SetMode" then
        Server.HandleSetMode(player, args)
    elseif command == "SetOutputEnabled" then
        Server.HandleSetOutputEnabled(player, args)
    elseif command == "RequestState" then
        Server.HandleRequestState(player, args)
    end
end

function Server.RunTick()
    local tickMinutes = EnergyRouting.GetConfigValue("EnergyTickMinutes")
    if not tickMinutes or tickMinutes <= 0 then
        tickMinutes = 10
    end
    if isVanillaLikeEnergyFlow() then
        tickMinutes = 1
    end

    local nowMinutes = getWorldMinutes()
    if nowMinutes - Server.lastTickMinutes < tickMinutes then
        return
    end

    Server.lastTickMinutes = nowMinutes
    logEnergy("RunTick now=" .. tostring(nowMinutes)
        .. " tickMinutes=" .. tostring(tickMinutes)
        .. " edcs=" .. tostring(tableCount(Server.edcs)))
    Server._inTick = true
    if EnergyNetwork and EnergyNetwork.Server and EnergyNetwork.Server.TickNetworks then
        EnergyNetwork.Server.TickNetworks()
    end
    if EnergyController and EnergyController.Server and EnergyController.Server.TickEnergyControllers then
        EnergyController.Server.TickEnergyControllers()
    elseif EnergyController and EnergyController.Server and EnergyController.Server.TickControllers then
        EnergyController.Server.TickControllers()
    end
    local staleEdcIds = {}
    for edcId, edc in pairs(Server.edcs or {}) do
        local controllerObj = Server.GetControllerObject and Server.GetControllerObject(edc and edc.id or edcId) or nil
        if not controllerObj then
            if edc and isControllerSquareLoaded(edc) then
                edc._missingControllerTicks = (tonumber(edc._missingControllerTicks) or 0) + 1
                if edc._missingControllerTicks >= 3 then
                    table.insert(staleEdcIds, edcId)
                end
            elseif edc then
                edc._missingControllerTicks = 0
            end
        else
            edc._missingControllerTicks = 0
        end
    end
    for _, staleId in ipairs(staleEdcIds) do
        print("[SPESS][EDC] Removing stale EDC with missing controller: " .. tostring(staleId))
        Server.RemoveEDC(staleId)
    end

    for _, edc in pairs(Server.edcs or {}) do
        if isVanillaLikeEnergyFlow() then
            local fullNow = getWorldMinutes()
            edc._lastFullUpdate = tonumber(edc._lastFullUpdate) or 0
            if (fullNow - edc._lastFullUpdate) >= 5 or edc._forceFullEnforce then
                Server.UpdateEDC(edc)
                edc._lastFullUpdate = fullNow
                edc._forceFullEnforce = nil
            else
                if not isControllerOffIdleSkip(edc) then
                    Server.EnforceGroups(edc, edc.cachedGroups or edc._lastScannedGroups)
                end
            end
        else
            -- OFF-idle controllers are enforced when toggled and can skip periodic heavy updates.
            if not isControllerOffIdleSkip(edc) then
                if shouldProcessControllerNow(
                    edc,
                    nowMinutes,
                    REMOTE_CONTROLLER_UPDATE_INTERVAL_MINUTES,
                    RUNTIME_NEARBY_PLAYER_DISTANCE
                ) then
                    Server.UpdateEDC(edc)
                end
            end
        end
    end
    Server._inTick = false
end

function Server.EnforceManualConsumerGroups(edc, preScannedGroups)
    if not edc then
        return
    end

    local groups = preScannedGroups or edc.cachedGroups or edc._lastScannedGroups
    if not groups then
        groups = resolveConsumerGroups(edc)
    end
    if not groups then
        return
    end

    edc.toggles = edc.toggles or EnergyRouting.MakeDefaultToggles()
    local states = edc.groupStates or {}
    local refrigerationDisabled = (states.refrigeration == "disabled")
        or (edc.toggles and edc.toggles.refrigeration == false)
    local lightsDisabled = (states.lights == "disabled")
        or (edc.toggles and edc.toggles.lights == false)

    local function buildManualEnforceSignature()
        local parts = {
            tostring(edc.outputEnabled ~= false),
        }
        for _, group in ipairs(EnergyRouting.GroupsList or {}) do
            local groupId = group.id
            local groupData = groups[groupId] or nil
            local deviceCount = 0
            if groupData and type(groupData.devices) == "table" then
                deviceCount = #groupData.devices
            end
            parts[#parts + 1] = tostring(groupId)
                .. ":" .. tostring(states[groupId] or "disabled")
                .. ":" .. tostring(edc.toggles and edc.toggles[groupId] ~= false)
                .. ":" .. tostring(deviceCount)
        end
        return table.concat(parts, "|")
    end

    local enforceSignature = buildManualEnforceSignature()
    local nowMs = getPerfNowMs()
    local lastSignature = edc._manualEnforceSignature
    local lastEnforceAtMs = tonumber(edc._manualEnforceAtMs) or 0
    local bypassThrottle = (edc._forceFullEnforce == true)
        or (edc._forceConsumerRescan == true)
        or (edc._ersOffEnforcePending == true)
    if (not bypassThrottle)
        and lastSignature == enforceSignature
        and (nowMs - lastEnforceAtMs) < MANUAL_ENFORCE_MIN_INTERVAL_MS then
        return
    end
    edc._manualEnforceSignature = enforceSignature
    edc._manualEnforceAtMs = nowMs

    for _, group in ipairs(EnergyRouting.GroupsList or {}) do
        local groupData = groups[group.id] or nil
        if groupData and groupData.devices then
            local state = states[group.id]
            if (edc.outputEnabled ~= false) and state == "powered" then
                for _, consumer in ipairs(groupData.devices) do
                    local obj = consumer and (consumer.object or consumer) or nil
                    if refrigerationDisabled and isRefrigerationLikeObject(obj) then
                        applyConsumerPowerState({ object = obj, group = "refrigeration" }, false)
                    else
                        Server.PowerOnConsumer(consumer)
                    end
                end
            elseif state == "disabled" then
                Server.PowerOffGroup(groupData.devices)
            end
        end
    end

    if refrigerationDisabled then
        local forcedCount = forceRefrigerationObjectsOff(edc, groups)
        edc._refrigerationOnEnforceSig = nil
        local logKey = edc.id or (tostring(edc.x) .. ":" .. tostring(edc.y) .. ":" .. tostring(edc.z))
        local signature = tostring(states.refrigeration) .. ":" .. tostring(edc.toggles and edc.toggles.refrigeration)
            .. ":" .. tostring(forcedCount)
        if Server._refrigerationForceLogById[logKey] ~= signature then
            Server._refrigerationForceLogById[logKey] = signature
            print("[SPESS][Refrigeration] id=" .. tostring(edc.id)
                .. " state=" .. tostring(states.refrigeration)
                .. " toggle=" .. tostring(edc.toggles and edc.toggles.refrigeration)
                .. " forcedOff=" .. tostring(forcedCount))
        end
    elseif (edc.outputEnabled ~= false) and states.refrigeration == "powered" then
        local onSig = tostring(states.refrigeration)
            .. ":" .. tostring(edc.toggles and edc.toggles.refrigeration)
            .. ":" .. tostring(edc.outputEnabled ~= false)
        if edc._refrigerationOnEnforceSig ~= onSig then
            edc._refrigerationOnEnforceSig = onSig
            forceRefrigerationObjectsOn(edc, groups)
        end
    end

    if lightsDisabled then
        local forcedLights = forceLightsObjectsOff(edc, groups)
        local logKey = edc.id or (tostring(edc.x) .. ":" .. tostring(edc.y) .. ":" .. tostring(edc.z))
        local signature = tostring(states.lights) .. ":" .. tostring(edc.toggles and edc.toggles.lights)
            .. ":" .. tostring(forcedLights)
        if Server._lightsForceLogById[logKey] ~= signature then
            Server._lightsForceLogById[logKey] = signature
            print("[SPESS][Lights] id=" .. tostring(edc.id)
                .. " state=" .. tostring(states.lights)
                .. " toggle=" .. tostring(edc.toggles and edc.toggles.lights)
                .. " forcedOff=" .. tostring(forcedLights))
        end
    end
end

function Server.EnforceGroups(edc, preScannedGroups)
    if not edc then
        return
    end
    local groups = preScannedGroups or edc.cachedGroups or edc._lastScannedGroups
    if not groups then
        return
    end
    Server.EnforceManualConsumerGroups(edc, groups)
end

function Server.ApplyRefrigerationImmediate(edc)
    if not edc or not edc.groupStates then
        return
    end

    local state = edc.groupStates.refrigeration
    local toggleOn = not (edc.toggles and edc.toggles.refrigeration == false)
    local shouldPower = (edc.outputEnabled ~= false) and toggleOn and (state == "powered" or state == "limited")

    local groups = edc.cachedGroups or edc._lastScannedGroups
    if not groups then
        groups = resolveConsumerGroups(edc)
        edc.cachedGroups = groups
        edc._lastScannedGroups = groups
        edc._lastScannedAt = getWorldMinutes()
    end

    refreshRefrigerationObjectCache(edc, groups, true)
    if shouldPower then
        forceRefrigerationObjectsOn(edc, groups)
    else
        forceRefrigerationObjectsOff(edc, groups)
        edc._refrigerationOnEnforceSig = nil
    end
end

function Server.EnforceEntertainmentHardOff(edc)
    -- Deprecated by passive fallback consumer model:
    -- TVs are not hard-off controlled by group toggles anymore.
    return
end

local function shouldRefreshVanillaLikeSquareBus(edc)
    if not edc then
        return false
    end
    local nowMinutes = getWorldMinutes()
    if edc._forceSquareRefresh then
        edc._forceSquareRefresh = nil
        edc._lastVanillaLikeSquareRefreshAt = nowMinutes
        return true
    end
    local last = tonumber(edc._lastVanillaLikeSquareRefreshAt) or -1
    if last < 0 or (nowMinutes - last) >= VANILLA_LIKE_SQUARE_REFRESH_MINUTES then
        edc._lastVanillaLikeSquareRefreshAt = nowMinutes
        return true
    end
    return false
end

local function enforceRefrigerationHeartbeatOnly(edc, groups)
    if not edc or not groups then
        return
    end
    edc.toggles = edc.toggles or EnergyRouting.MakeDefaultToggles()
    local states = edc.groupStates or {}
    local refrigerationDisabled = (states.refrigeration == "disabled")
        or (edc.toggles and edc.toggles.refrigeration == false)
        or (edc.outputEnabled == false)
    if refrigerationDisabled then
        forceRefrigerationObjectsOff(edc, groups)
        edc._refrigerationOnEnforceSig = nil
    else
        edc._refrigerationHeartbeatCounter = 0
    end
end

function Server.RefreshBuildingPower()
    if isVanillaLikeEnergyFlow() then
        for _, edc in pairs(Server.edcs or {}) do
            if (not isControllerOffIdleSkip(edc)) and shouldRefreshVanillaLikeSquareBus(edc) then
                Server.ApplyDebugVanillaLikePower(edc, false)
            end
        end
        return
    end
    if not (ERS and ERS.BuildingPower) then
        return
    end
    local nowMinutes = getWorldMinutes()
    for _, edc in pairs(Server.edcs or {}) do
        if not isControllerOffIdleSkip(edc) then
            if shouldProcessControllerNow(
                edc,
                nowMinutes,
                REMOTE_CONTROLLER_UPDATE_INTERVAL_MINUTES,
                RUNTIME_NEARBY_PLAYER_DISTANCE
            ) then
                Server.ForceBuildingHasElectricityOff(edc)
                Server.ApplySquarePowerBus(edc)
                local snapshot = Server.GetEnergySnapshot(edc)
                if Server.IsTotalBuildingPowerMode() then
                    Server.ApplyTotalBuildingPowerState(edc, snapshot, "EveryOneMinute", true)
                elseif ERS.BuildingPower.applyControllerDecision then
                    edc.production = snapshot.production or 0
                    edc.storage = snapshot.storage or 0
                    edc.capacity = snapshot.capacity or snapshot.totalCapacity or 0
                    edc.totalCapacity = snapshot.totalCapacity or snapshot.capacity or 0
                    edc.solarCapacity = snapshot.solarCapacity or 0
                    edc.windCapacity = snapshot.windCapacity or 0
                    edc.energyAvailable = (snapshot.available or 0) + (snapshot.production or 0)
                    edc.controllerHasEnergy = edc.energyAvailable > 0
                    edc.authorizedPowerWatts = edc.energyAvailable
                    if edc.outputEnabled == nil then
                        edc.outputEnabled = true
                    end
                    local source = ERS.BuildingPower.applyControllerDecision(edc)
                    edc.powerSource = source
                    if source == "ERS" then
                        Server.SetBuildingElectricity(edc, false)
                    elseif source == "Off" then
                        Server.SetBuildingElectricity(edc, false)
                    end
                end

                Server.UpdateVanillaGeneratorFallback(edc)

                Server.EnforceManualConsumerGroups(edc)
            end
        end
    end
end

function Server.RefreshBuildingPowerHeartbeat()
    local nowMinutes = getWorldMinutes()
    if isVanillaLikeEnergyFlow() then
        Server._manualEnforceTickCounter = (Server._manualEnforceTickCounter or 0) + 1
        if Server._manualEnforceTickCounter < 30 then
            return
        end
        Server._manualEnforceTickCounter = 0
        for _, edc in pairs(Server.edcs or {}) do
            local groups = edc and (edc.cachedGroups or edc._lastScannedGroups) or nil
            if groups and (not isControllerOffIdleSkip(edc))
                and shouldProcessControllerNow(
                    edc,
                    nowMinutes,
                    REMOTE_CONTROLLER_UPDATE_INTERVAL_MINUTES,
                    RUNTIME_NEARBY_PLAYER_DISTANCE
                ) then
                enforceRefrigerationHeartbeatOnly(edc, groups)
            end
        end
        return
    end
    Server._nonVanillaHeartbeatTickCounter = (Server._nonVanillaHeartbeatTickCounter or 0) + 1
    if Server._nonVanillaHeartbeatTickCounter < NON_VANILLA_HEARTBEAT_TICK_INTERVAL then
        return
    end
    Server._nonVanillaHeartbeatTickCounter = 0
    local useBuildingPowerMode = Server.IsTotalBuildingPowerMode()
    for _, edc in pairs(Server.edcs or {}) do
        if not isControllerOffIdleSkip(edc)
            and shouldProcessControllerNow(
                edc,
                nowMinutes,
                REMOTE_CONTROLLER_UPDATE_INTERVAL_MINUTES,
                RUNTIME_NEARBY_PLAYER_DISTANCE
            ) then
            if not useBuildingPowerMode then
                Server.ForceBuildingHasElectricityOff(edc)
            end
            if edc and not edc._lastScannedGroups then
                edc._lastScannedGroups = resolveConsumerGroups(edc)
                edc.cachedGroups = edc._lastScannedGroups
            end
            -- FIXED: Always enforce groups if we have data, to counteract grid leakage
            if edc and edc._lastScannedGroups then
                Server.EnforceManualConsumerGroups(edc, edc._lastScannedGroups)
            end
        end
    end
end

Events.OnInitGlobalModData.Add(Server.LoadModData)
Events.OnClientCommand.Add(Server.OnClientCommand)
if Events.EveryOneMinute then
    Events.EveryOneMinute.Add(Server.RunTick)
    Events.EveryOneMinute.Add(Server.RefreshBuildingPower)
else
    Events.EveryTenMinutes.Add(Server.RunTick)
end
if Events.OnTick then
    Events.OnTick.Add(Server.RefreshBuildingPowerHeartbeat)
end

