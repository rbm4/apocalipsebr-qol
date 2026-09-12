-- Deterministic building-level abandonment history for checkpoint #41.
-- Profiles are regenerated from stable BuildingDef identity + A10YL world seed;
-- no per-building database is persisted into the save.
local Random = require("A10YL/core/A10YL_Random")
local Context = require("A10YL/core/A10YL_Context")

local BuildingProfile = {}

BuildingProfile.SIGNATURE = {
    QUIET_ABANDONED = "QUIET_ABANDONED",
    DISTURBED = "DISTURBED",
    LOOTED_BREACHED = "LOOTED_BREACHED",
    DEFENDED = "DEFENDED",
    DEFENDED_BREACHED = "DEFENDED_BREACHED",
}

local cache = {}
local cacheOrder = {}
local cacheHead = 1
local cacheTail = 0
local cacheCount = 0
local MAX_CACHE_ENTRIES = 1024

local function cacheProfile(key, profile)
    if cache[key] ~= nil then
        cache[key] = profile
        return
    end

    cache[key] = profile
    cacheTail = cacheTail + 1
    cacheOrder[cacheTail] = key
    cacheCount = cacheCount + 1

    while cacheCount > MAX_CACHE_ENTRIES do
        local expired = cacheOrder[cacheHead]
        cacheOrder[cacheHead] = nil
        cacheHead = cacheHead + 1
        if expired ~= nil and cache[expired] ~= nil then
            cache[expired] = nil
            cacheCount = cacheCount - 1
        end
    end

    -- Compact only the small Lua key queue, never the profile values. This is
    -- infrequent and keeps long-running dedicated servers from accumulating an
    -- ever-growing numeric cache-order index.
    if cacheHead > 512 and cacheHead > math.floor(cacheTail / 2) then
        local compacted = {}
        local tail = 0
        for i = cacheHead, cacheTail do
            local value = cacheOrder[i]
            if value ~= nil then
                tail = tail + 1
                compacted[tail] = value
            end
        end
        cacheOrder = compacted
        cacheHead = 1
        cacheTail = tail
    end
end

local SIGNATURE_EFFECTS = {
    QUIET_ABANDONED = {
        debris = 0.55,
        interiorDebris = 0.35,
        exteriorDebris = 0.55,
        interiorIntrusion = 0.35,
        openingDamage = 0.88,
        barricade = 0.00,
        vines = 1.20,
        fence = 0.95,
        fenceSeverity = 0.85,
        structure = 0.90,
    },
    DISTURBED = {
        debris = 1.05,
        interiorDebris = 1.00,
        exteriorDebris = 1.10,
        interiorIntrusion = 0.80,
        openingDamage = 1.08,
        barricade = 0.20,
        vines = 1.00,
        fence = 1.05,
        fenceSeverity = 1.00,
        structure = 1.00,
    },
    LOOTED_BREACHED = {
        debris = 1.55,
        interiorDebris = 1.85,
        exteriorDebris = 1.65,
        interiorIntrusion = 1.85,
        openingDamage = 1.70,
        barricade = 0.05,
        vines = 1.10,
        fence = 1.30,
        fenceSeverity = 1.35,
        structure = 1.00,
    },
    DEFENDED = {
        debris = 0.90,
        interiorDebris = 0.55,
        exteriorDebris = 0.75,
        interiorIntrusion = 0.20,
        openingDamage = 0.90,
        barricade = 1.80,
        vines = 0.75,
        fence = 0.80,
        fenceSeverity = 0.65,
        structure = 0.90,
    },
    DEFENDED_BREACHED = {
        debris = 1.35,
        interiorDebris = 1.55,
        exteriorDebris = 1.45,
        interiorIntrusion = 1.45,
        openingDamage = 1.45,
        barricade = 1.55,
        vines = 1.05,
        fence = 1.35,
        fenceSeverity = 1.30,
        structure = 1.05,
    },
}

local HISTORY_THRESHOLDS = {
    [Context.BUILT_USE.RESIDENTIAL] = { 40, 62, 73, 92 },
    [Context.BUILT_USE.COMMERCIAL] = { 18, 43, 76, 88 },
    [Context.BUILT_USE.INDUSTRIAL] = { 22, 50, 78, 90 },
    [Context.BUILT_USE.FARMYARD] = { 48, 69, 80, 94 },
    [Context.BUILT_USE.CIVIC] = { 24, 49, 70, 90 },
    [Context.BUILT_USE.UNKNOWN] = { 34, 59, 77, 91 },
}

local function clampChance(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 100 then return 100 end
    return value
end

local function callValue(object, methodName)
    if not object or type(methodName) ~= "string" then return nil end
    local method = object[methodName]
    if type(method) ~= "function" then return nil end
    local ok, value = pcall(method, object)
    if not ok then return nil end
    return value
end

local function buildingDefForSquare(square)
    if not square then return nil end

    if square.getBuildingDef then
        local ok, def = pcall(function() return square:getBuildingDef() end)
        if ok and def then return def end
    end

    local roomDef = square.getRoomDef and square:getRoomDef() or nil
    if roomDef and roomDef.getBuilding then
        local ok, def = pcall(function() return roomDef:getBuilding() end)
        if ok then return def end
    end

    return nil
end

local function buildingIdentity(def)
    if not def then return nil end

    local idString = callValue(def, "getIDString")
    local id = callValue(def, "getID")
    local x = tonumber(callValue(def, "getX"))
    local y = tonumber(callValue(def, "getY"))
    local x2 = tonumber(callValue(def, "getX2"))
    local y2 = tonumber(callValue(def, "getY2"))
    if not x or not y then return nil end

    local key = table.concat({
        tostring(idString or id or "building"),
        tostring(x), tostring(y), tostring(x2 or x), tostring(y2 or y),
    }, ":")
    return key, math.floor(x), math.floor(y)
end

local function buildingContainsRoom(def, roomName)
    if not def or type(def.containsRoom) ~= "function" then return false end
    local ok, value = pcall(function() return def:containsRoom(roomName) end)
    return ok and value == true
end

local function zoneType(def)
    if not def or type(def.getZone) ~= "function" then return "" end
    local ok, value = pcall(function()
        local zone = def:getZone()
        return zone and zone.getType and zone:getType() or nil
    end)
    if not ok or value == nil then return "" end
    return string.lower(tostring(value))
end

local function inferBuildingUse(def)
    local zone = zoneType(def)
    if zone:find("farm", 1, true) then return Context.BUILT_USE.FARMYARD end
    if zone:find("industrial", 1, true) then return Context.BUILT_USE.INDUSTRIAL end
    if zone:find("commercial", 1, true) or zone:find("business", 1, true) then
        return Context.BUILT_USE.COMMERCIAL
    end
    if zone:find("residential", 1, true) or zone:find("trailer", 1, true) then
        return Context.BUILT_USE.RESIDENTIAL
    end

    if buildingContainsRoom(def, "bedroom") or buildingContainsRoom(def, "kitchen")
        or buildingContainsRoom(def, "livingroom") or buildingContainsRoom(def, "bathroom")
    then
        return Context.BUILT_USE.RESIDENTIAL
    end
    if buildingContainsRoom(def, "shop") or buildingContainsRoom(def, "store")
        or buildingContainsRoom(def, "office") or buildingContainsRoom(def, "restaurant")
    then
        return Context.BUILT_USE.COMMERCIAL
    end
    if buildingContainsRoom(def, "warehouse") or buildingContainsRoom(def, "factory")
        or buildingContainsRoom(def, "garage")
    then
        return Context.BUILT_USE.INDUSTRIAL
    end
    if buildingContainsRoom(def, "school") or buildingContainsRoom(def, "hospital")
        or buildingContainsRoom(def, "police") or buildingContainsRoom(def, "firestorage")
    then
        return Context.BUILT_USE.CIVIC
    end

    return Context.BUILT_USE.UNKNOWN
end

local function selectSignature(use, roll)
    local threshold = HISTORY_THRESHOLDS[use] or HISTORY_THRESHOLDS[Context.BUILT_USE.UNKNOWN]
    if roll <= threshold[1] then return BuildingProfile.SIGNATURE.QUIET_ABANDONED end
    if roll <= threshold[2] then return BuildingProfile.SIGNATURE.DISTURBED end
    if roll <= threshold[3] then return BuildingProfile.SIGNATURE.LOOTED_BREACHED end
    if roll <= threshold[4] then return BuildingProfile.SIGNATURE.DEFENDED end
    return BuildingProfile.SIGNATURE.DEFENDED_BREACHED
end

local function pressureFactor(pressure)
    -- Pressure modifies an already semantic sandbox chance rather than creating
    -- a second hidden percentage setting. Range is intentionally modest.
    pressure = clampChance(pressure)
    return 0.75 + (pressure / 100) * 0.50
end

function BuildingProfile.get(square)
    local def = buildingDefForSquare(square)
    local key, x, y = buildingIdentity(def)
    if not key then return nil end

    local worldSeed = tostring(Random.getWorldSeed() or "0")
    local cacheKey = worldSeed .. ":" .. key
    local existing = cache[cacheKey]
    if existing then return existing end

    local builtUse = inferBuildingUse(def)
    local weather = Random.coordinatePercent(x, y, 0, "building:weather:" .. key)
    local human = Random.coordinatePercent(x, y, 0, "building:human:" .. key)
    local history = Random.coordinatePercent(x, y, 0, "building:history:" .. key)
    local signature = selectSignature(builtUse, history)

    local profile = {
        key = key,
        anchorX = x,
        anchorY = y,
        builtUse = builtUse,
        weatherPressure = weather,
        humanPressure = human,
        signature = signature,
    }
    cacheProfile(cacheKey, profile)
    return profile
end

function BuildingProfile.getEffect(profile, effectName)
    if not profile or type(effectName) ~= "string" then return 1.0 end
    local effects = SIGNATURE_EFFECTS[profile.signature] or SIGNATURE_EFFECTS.DISTURBED
    return tonumber(effects[effectName]) or 1.0
end

function BuildingProfile.weatherChance(baseChance, profile, effectName)
    local factor = profile and pressureFactor(profile.weatherPressure) or 1.0
    if effectName then factor = factor * BuildingProfile.getEffect(profile, effectName) end
    return clampChance((tonumber(baseChance) or 0) * factor)
end

function BuildingProfile.humanChance(baseChance, profile, effectName)
    local factor = profile and pressureFactor(profile.humanPressure) or 1.0
    if effectName then factor = factor * BuildingProfile.getEffect(profile, effectName) end
    return clampChance((tonumber(baseChance) or 0) * factor)
end

function BuildingProfile.isDefended(profile)
    return profile ~= nil and (
        profile.signature == BuildingProfile.SIGNATURE.DEFENDED
        or profile.signature == BuildingProfile.SIGNATURE.DEFENDED_BREACHED
    )
end

function BuildingProfile.isBreachedHistory(profile)
    return profile ~= nil and (
        profile.signature == BuildingProfile.SIGNATURE.LOOTED_BREACHED
        or profile.signature == BuildingProfile.SIGNATURE.DEFENDED_BREACHED
    )
end


function BuildingProfile.getNearby(square)
    if not square then return nil end

    local direct = BuildingProfile.get(square)
    if direct then return direct end

    -- Stable cardinal-first lookup gives exterior apron/fence squares the same
    -- abandonment story as the nearest building without persisting extra state.
    local groups = { Context.offsets.cardinal, Context.offsets.adjacent }
    local seen = {}
    for g = 1, #groups do
        local offsets = groups[g]
        for i = 1, #offsets do
            local offset = offsets[i]
            local key = tostring(offset[1]) .. ":" .. tostring(offset[2])
            if not seen[key] then
                seen[key] = true
                local nearby = Context.getOffsetSquare(square, offset[1], offset[2], offset[3] or 0)
                local profile = nearby and BuildingProfile.get(nearby) or nil
                if profile then return profile end
            end
        end
    end
    return nil
end

function BuildingProfile.matchesSquareOrNearby(square, key, signature)
    if key == nil and signature == nil then return true end
    local profile = BuildingProfile.get(square)
    if not profile then profile = BuildingProfile.getNearby(square) end
    if not profile then return false end
    if key ~= nil and tostring(profile.key) ~= tostring(key) then return false end
    if signature ~= nil and tostring(profile.signature) ~= tostring(signature) then return false end
    return true
end

function BuildingProfile.matches(square, key, signature)
    if key == nil and signature == nil then return true end
    local profile = BuildingProfile.get(square)
    if not profile then return false end
    if key ~= nil and tostring(profile.key) ~= tostring(key) then return false end
    if signature ~= nil and tostring(profile.signature) ~= tostring(signature) then return false end
    return true
end

function BuildingProfile.clearCache()
    cache = {}
    cacheOrder = {}
    cacheHead = 1
    cacheTail = 0
    cacheCount = 0
end

function BuildingProfile.getCacheStats()
    return { entries = cacheCount, limit = MAX_CACHE_ENTRIES }
end

return BuildingProfile
