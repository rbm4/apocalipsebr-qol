-- Chunk-level area context classifier for the v0.8.1 optimisation/accessibility pass.
-- This does not mutate the world. It scans a loaded 8x8 chunk once, caches the
-- broad place type, and lets feature systems avoid town-style debris or clutter
-- in wilderness/farm/open-field areas. It deliberately fails conservative when
-- a custom map exposes too little information.
local AreaContext = {}

local CHUNK_SIZE = 8
local MAX_AREA_ENTRIES = 2048

AreaContext.TYPE = {
    UNKNOWN = "unknown",
    URBAN = "urban",
    RESIDENTIAL = "residential",
    COMMERCIAL = "commercial",
    INDUSTRIAL = "industrial",
    ROADSIDE = "roadside",
    FARM_RURAL = "farm_rural",
    OPEN_FIELD = "open_field",
    FOREST = "forest",
    DEEP_WILDERNESS = "deep_wilderness",
    WATER_EDGE = "water_edge",
}

local cache = {}
local cacheEntries = 0
local stats = {
    hits = 0,
    misses = 0,
    clears = 0,
    classified = 0,
}

local function integer(value)
    value = tonumber(value)
    if value == nil then return nil end
    if value >= 0 then return math.floor(value) end
    return math.ceil(value)
end

local function startsWith(value, prefix)
    return type(value) == "string"
        and type(prefix) == "string"
        and string.sub(value, 1, #prefix) == prefix
end

local function lower(value)
    if value == nil then return "" end
    return string.lower(tostring(value))
end

local function safeCall(callback, fallback)
    local ok, value = pcall(callback)
    if not ok then return fallback end
    return value
end

local function squareCoords(square)
    if not square then return nil, nil, nil end
    local x = safeCall(function() return square:getX() end, nil)
    local y = safeCall(function() return square:getY() end, nil)
    local z = safeCall(function() return square:getZ() end, nil)
    return integer(x), integer(y), integer(z)
end

local function chunkKeyFromSquare(square)
    local x, y = squareCoords(square)
    if x == nil or y == nil then return nil, nil, nil end
    local wx = math.floor(x / CHUNK_SIZE)
    local wy = math.floor(y / CHUNK_SIZE)
    return tostring(wx) .. ":" .. tostring(wy), wx, wy
end

local function isWaterSquare(square)
    return safeCall(function()
        local properties = square.getProperties and square:getProperties() or nil
        return properties ~= nil and properties:has(IsoFlagType.water)
    end, false) == true
end

local function floorSpriteName(square)
    return safeCall(function()
        local floor = square and square:getFloor() or nil
        local sprite = floor and floor:getSprite() or nil
        local name = sprite and sprite:getName() or nil
        return name and tostring(name) or nil
    end, nil)
end

local function classifyFloor(spriteName)
    spriteName = lower(spriteName)
    if spriteName == "" then return nil end
    if startsWith(spriteName, "blends_street_01_")
        or startsWith(spriteName, "floors_exterior_street_")
    then
        return "road"
    end
    if startsWith(spriteName, "location_community_railroad_")
        or startsWith(spriteName, "location_community_train_")
        or startsWith(spriteName, "location_train_")
        or startsWith(spriteName, "railroad_")
    then
        return "rail"
    end
    if startsWith(spriteName, "blends_natural_01")
        or startsWith(spriteName, "blends_natural_02")
    then
        return "natural"
    end
    if startsWith(spriteName, "floors_exterior_")
        or startsWith(spriteName, "blends_gravel_")
    then
        return "hardscape"
    end
    return nil
end

local function hasText(value, needles)
    value = lower(value)
    if value == "" or type(needles) ~= "table" then return false end
    for i = 1, #needles do
        if value:find(needles[i], 1, true) then return true end
    end
    return false
end

local INDUSTRIAL_HINTS = { "industrial", "industry", "factory", "warehouse", "loading", "storage" }
local COMMERCIAL_HINTS = { "commercial", "business", "shop", "store", "town", "downtown", "restaurant", "office" }
local RESIDENTIAL_HINTS = { "residential", "trailer", "house", "livingroom", "bedroom", "kitchen", "bathroom" }
local FARM_HINTS = { "farm", "ranch", "crop", "field", "pasture", "rural", "barn" }
local DEEP_FOREST_HINTS = { "deepforest", "deep forest", "wilderness" }
local FOREST_HINTS = { "forest", "woods", "woodland", "vegitation", "vegetation" }

local function addPlaceHints(text, result)
    if text == nil or text == "" then return end
    if hasText(text, INDUSTRIAL_HINTS) then result.industrialHint = result.industrialHint + 1 end
    if hasText(text, COMMERCIAL_HINTS) then result.commercialHint = result.commercialHint + 1 end
    if hasText(text, RESIDENTIAL_HINTS) then result.residentialHint = result.residentialHint + 1 end
    if hasText(text, FARM_HINTS) then result.farmHint = result.farmHint + 1 end
    if hasText(text, DEEP_FOREST_HINTS) then result.deepForestHint = result.deepForestHint + 1 end
    if hasText(text, FOREST_HINTS) then result.forestHint = result.forestHint + 1 end
end

local function zoneType(square)
    return safeCall(function()
        local zone = square and square.getZone and square:getZone() or nil
        return zone and zone.getType and zone:getType() or nil
    end, nil)
end

local function roomName(square)
    return safeCall(function()
        local room = square and square.getRoom and square:getRoom() or nil
        return room and room.getName and room:getName() or nil
    end, nil)
end

local function hasRoomOrBuilding(square)
    return safeCall(function()
        if not square then return false end
        local room = square.getRoom and square:getRoom() or nil
        local building = square.getBuilding and square:getBuilding() or nil
        return room ~= nil or building ~= nil
    end, false) == true
end

local function objectSpriteName(obj)
    return safeCall(function()
        if not obj then return nil end
        if obj.getSpriteName then
            local spriteName = obj:getSpriteName()
            if spriteName then return tostring(spriteName) end
        end
        if obj.getTextureName then
            local textureName = obj:getTextureName()
            if textureName then return tostring(textureName) end
        end
        return nil
    end, nil)
end

local function isBuiltContextSprite(spriteName)
    spriteName = lower(spriteName)
    if spriteName == "" then return false end
    if startsWith(spriteName, "f_") or startsWith(spriteName, "e_") then return false end
    return startsWith(spriteName, "walls_")
        or startsWith(spriteName, "fixtures_")
        or startsWith(spriteName, "fencing_")
        or startsWith(spriteName, "location_")
        or startsWith(spriteName, "street_")
        or startsWith(spriteName, "industry_")
        or startsWith(spriteName, "appliances_")
        or startsWith(spriteName, "carpentry_")
end

local function inspectObjects(square, result)
    local objects = safeCall(function() return square and square:getObjects() or nil end, nil)
    if not objects then return end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            local isTree = safeCall(function()
                return instanceof(obj, "IsoTree")
            end, false) == true
            if isTree then
                result.treeCount = result.treeCount + 1
            end

            local builtObject = safeCall(function()
                return instanceof(obj, "IsoDoor")
                    or instanceof(obj, "IsoWindow")
                    or instanceof(obj, "IsoThumpable")
                    or instanceof(obj, "IsoObject")
            end, false) == true

            local spriteName = objectSpriteName(obj)
            if isBuiltContextSprite(spriteName) then
                result.builtCount = result.builtCount + 1
                addPlaceHints(spriteName, result)
            elseif builtObject and not isTree then
                local lowered = lower(spriteName)
                if lowered ~= "" and not startsWith(lowered, "f_") and not startsWith(lowered, "e_") then
                    addPlaceHints(lowered, result)
                end
            end
        end
    end
end

local function newAccumulator()
    return {
        total = 0,
        waterCount = 0,
        naturalCount = 0,
        roadCount = 0,
        hardscapeCount = 0,
        railCount = 0,
        roomCount = 0,
        builtCount = 0,
        treeCount = 0,
        industrialHint = 0,
        commercialHint = 0,
        residentialHint = 0,
        farmHint = 0,
        forestHint = 0,
        deepForestHint = 0,
    }
end

local function inspectSquare(square, result)
    if not square then return end
    result.total = result.total + 1

    if isWaterSquare(square) then
        result.waterCount = result.waterCount + 1
    end

    local floorClass = classifyFloor(floorSpriteName(square))
    if floorClass == "natural" then
        result.naturalCount = result.naturalCount + 1
    elseif floorClass == "road" then
        result.roadCount = result.roadCount + 1
    elseif floorClass == "hardscape" then
        result.hardscapeCount = result.hardscapeCount + 1
    elseif floorClass == "rail" then
        result.railCount = result.railCount + 1
    end

    if hasRoomOrBuilding(square) then
        result.roomCount = result.roomCount + 1
    end

    addPlaceHints(zoneType(square), result)
    addPlaceHints(roomName(square), result)
    inspectObjects(square, result)
end

local function getSquareAt(cell, x, y, z)
    return safeCall(function()
        if not cell then return nil end
        return cell:getGridSquare(x, y, z)
    end, nil)
end

local function scanChunk(square, wx, wy)
    local result = newAccumulator()
    local cell = safeCall(function() return square:getCell() end, nil) or (type(getCell) == "function" and getCell() or nil)
    local startX = wx * CHUNK_SIZE
    local startY = wy * CHUNK_SIZE

    for localY = 0, CHUNK_SIZE - 1 do
        for localX = 0, CHUNK_SIZE - 1 do
            local sq = getSquareAt(cell, startX + localX, startY + localY, 0)
            inspectSquare(sq, result)
        end
    end

    -- Fallback for test doubles or unusual runtimes where the candidate square
    -- exists but the chunk scan did not return any members.
    if result.total <= 0 then
        inspectSquare(square, result)
    end

    return result
end

local function density(count, total)
    total = tonumber(total) or 0
    if total <= 0 then return 0 end
    return (tonumber(count) or 0) / total
end

local function chooseKind(result)
    local total = tonumber(result.total) or 0
    if total <= 0 then return AreaContext.TYPE.UNKNOWN end

    local builtDensity = density(result.builtCount + result.roomCount, total)
    local roadHardDensity = density(result.roadCount + result.hardscapeCount + result.railCount, total)
    local naturalDensity = density(result.naturalCount, total)
    local treeDensity = density(result.treeCount, total)

    -- Clear authored/built context wins over biome heuristics. A shop beside a
    -- forested edge should still age like a commercial area, not deep wilderness.
    if result.industrialHint > 0 and (builtDensity >= 0.03 or roadHardDensity >= 0.12) then
        return AreaContext.TYPE.INDUSTRIAL
    end
    if result.commercialHint > 0 and (builtDensity >= 0.03 or roadHardDensity >= 0.12) then
        return AreaContext.TYPE.COMMERCIAL
    end
    if result.residentialHint > 0 and builtDensity >= 0.03 then
        return AreaContext.TYPE.RESIDENTIAL
    end
    if builtDensity >= 0.22 then
        return AreaContext.TYPE.URBAN
    end

    if result.farmHint > 0 then
        return AreaContext.TYPE.FARM_RURAL
    end

    if result.roadCount > 0 and builtDensity < 0.08 then
        return AreaContext.TYPE.ROADSIDE
    end
    if roadHardDensity >= 0.22 and builtDensity < 0.10 then
        return AreaContext.TYPE.ROADSIDE
    end

    if result.deepForestHint > 0
        or (treeDensity >= 0.30 and roadHardDensity < 0.10 and builtDensity < 0.05)
    then
        return AreaContext.TYPE.DEEP_WILDERNESS
    end
    if result.forestHint > 0
        or (treeDensity >= 0.12 and roadHardDensity < 0.15 and builtDensity < 0.08)
    then
        return AreaContext.TYPE.FOREST
    end

    if result.waterCount > 0 and builtDensity < 0.08 and roadHardDensity < 0.12 then
        return AreaContext.TYPE.WATER_EDGE
    end

    if naturalDensity >= 0.55 then
        return AreaContext.TYPE.OPEN_FIELD
    end

    return AreaContext.TYPE.UNKNOWN
end

local function clearCache()
    cache = {}
    cacheEntries = 0
    stats.clears = stats.clears + 1
end

function AreaContext.classify(square)
    local key, wx, wy = chunkKeyFromSquare(square)
    if not key then
        return {
            kind = AreaContext.TYPE.UNKNOWN,
            key = nil,
            wx = nil,
            wy = nil,
            total = 0,
        }
    end

    local cached = cache[key]
    if cached ~= nil then
        stats.hits = stats.hits + 1
        return cached
    end

    stats.misses = stats.misses + 1
    local sample = scanChunk(square, wx, wy)
    local kind = chooseKind(sample)
    local result = {
        kind = kind,
        key = key,
        wx = wx,
        wy = wy,
        total = sample.total,
        waterCount = sample.waterCount,
        naturalCount = sample.naturalCount,
        roadCount = sample.roadCount,
        hardscapeCount = sample.hardscapeCount,
        roomCount = sample.roomCount,
        builtCount = sample.builtCount,
        treeCount = sample.treeCount,
    }

    if cacheEntries >= MAX_AREA_ENTRIES then clearCache() end
    if cache[key] == nil then cacheEntries = cacheEntries + 1 end
    cache[key] = result
    stats.classified = stats.classified + 1
    return result
end

function AreaContext.get(square)
    return AreaContext.classify(square)
end

function AreaContext.getType(square)
    local area = AreaContext.classify(square)
    return area and area.kind or AreaContext.TYPE.UNKNOWN
end

function AreaContext.naturalDebrisMultiplier(kind)
    if kind == AreaContext.TYPE.DEEP_WILDERNESS then return 0.00 end
    if kind == AreaContext.TYPE.FOREST then return 0.05 end
    if kind == AreaContext.TYPE.WATER_EDGE then return 0.05 end
    if kind == AreaContext.TYPE.OPEN_FIELD then return 0.10 end
    if kind == AreaContext.TYPE.FARM_RURAL then return 0.18 end
    if kind == AreaContext.TYPE.ROADSIDE then return 0.45 end
    if kind == AreaContext.TYPE.RESIDENTIAL then return 0.75 end
    if kind == AreaContext.TYPE.COMMERCIAL or kind == AreaContext.TYPE.INDUSTRIAL
        or kind == AreaContext.TYPE.URBAN
    then
        return 1.00
    end
    return 0.35
end

function AreaContext.roadDebrisMultiplier(kind)
    if kind == AreaContext.TYPE.DEEP_WILDERNESS then return 0.25 end
    if kind == AreaContext.TYPE.FOREST then return 0.35 end
    if kind == AreaContext.TYPE.WATER_EDGE then return 0.35 end
    if kind == AreaContext.TYPE.OPEN_FIELD then return 0.45 end
    if kind == AreaContext.TYPE.FARM_RURAL then return 0.55 end
    if kind == AreaContext.TYPE.ROADSIDE then return 0.80 end
    return 1.00
end

function AreaContext.hardscapeDebrisMultiplier(kind)
    if kind == AreaContext.TYPE.DEEP_WILDERNESS then return 0.15 end
    if kind == AreaContext.TYPE.FOREST then return 0.20 end
    if kind == AreaContext.TYPE.WATER_EDGE then return 0.25 end
    if kind == AreaContext.TYPE.OPEN_FIELD then return 0.40 end
    if kind == AreaContext.TYPE.FARM_RURAL then return 0.65 end
    if kind == AreaContext.TYPE.INDUSTRIAL then return 1.20 end
    return 1.00
end

local DEFAULT_VEGETATION_MULTIPLIERS = { tree = 0.80, mature = 0.70, bush = 0.85, grass = 0.90, leaf = 0.75, road = 0.80, hardscape = 0.80 }
local VEGETATION_MULTIPLIERS = {
    [AreaContext.TYPE.DEEP_WILDERNESS] = { tree = 1.65, mature = 1.50, bush = 1.20, grass = 0.90, leaf = 1.20, road = 0.45, hardscape = 0.45 },
    [AreaContext.TYPE.FOREST] = { tree = 1.35, mature = 1.30, bush = 1.10, grass = 0.85, leaf = 1.10, road = 0.55, hardscape = 0.55 },
    [AreaContext.TYPE.OPEN_FIELD] = { tree = 0.45, mature = 0.35, bush = 0.75, grass = 1.00, leaf = 0.60, road = 0.70, hardscape = 0.70 },
    [AreaContext.TYPE.FARM_RURAL] = { tree = 0.45, mature = 0.35, bush = 0.65, grass = 0.95, leaf = 0.55, road = 0.75, hardscape = 0.75 },
    [AreaContext.TYPE.WATER_EDGE] = { tree = 0.75, mature = 0.70, bush = 0.85, grass = 0.90, leaf = 0.70, road = 0.65, hardscape = 0.65 },
    [AreaContext.TYPE.ROADSIDE] = { tree = 0.60, mature = 0.50, bush = 0.85, grass = 0.95, leaf = 0.75, road = 1.00, hardscape = 0.90 },
    [AreaContext.TYPE.RESIDENTIAL] = { tree = 0.55, mature = 0.45, bush = 0.75, grass = 0.90, leaf = 0.75, road = 1.00, hardscape = 1.00 },
    [AreaContext.TYPE.COMMERCIAL] = { tree = 0.45, mature = 0.35, bush = 0.70, grass = 0.85, leaf = 0.75, road = 1.00, hardscape = 1.00 },
    [AreaContext.TYPE.URBAN] = { tree = 0.45, mature = 0.35, bush = 0.70, grass = 0.85, leaf = 0.75, road = 1.00, hardscape = 1.00 },
    [AreaContext.TYPE.INDUSTRIAL] = { tree = 0.35, mature = 0.25, bush = 0.60, grass = 0.80, leaf = 0.65, road = 0.95, hardscape = 0.90 },
}

function AreaContext.vegetationMultipliers(kind)
    return VEGETATION_MULTIPLIERS[kind] or DEFAULT_VEGETATION_MULTIPLIERS
end

function AreaContext.clearAll()
    clearCache()
end

function AreaContext.getStats()
    return {
        entries = cacheEntries,
        hits = stats.hits,
        misses = stats.misses,
        clears = stats.clears,
        classified = stats.classified,
    }
end

return AreaContext
