-- Read-only contextual classification for the locked #19/#22 realism model.
-- Systems may consume these helpers, but all neighbouring-square reads remain
-- here so feature modules never perform cross-square lookups or mutations.
local Compatibility = require("A10YL/core/A10YL_Compatibility")
local Protection = require("A10YL/core/A10YL_Protection")
local Cache = require("A10YL/core/A10YL_Cache")
local AreaContext = require("A10YL/core/A10YL_AreaContext")

local Context = {}

Context.SURFACE = {
    INVALID = "invalid",
    PROTECTED = "protected",
    WATER = "water",
    NATURAL = "natural",
    ROAD = "road",
    HARDSCAPE = "hardscape",
    RAIL = "rail",
    INTERIOR = "interior",
    UPPER_EXPOSED = "upper_exposed",
    UNKNOWN = "unknown",
}

Context.EXPOSURE = {
    OUTSIDE = "OUTSIDE",
    SEALED_INTERIOR = "SEALED_INTERIOR",
    BREACHED_INTERIOR = "BREACHED_INTERIOR",
    HEAVILY_EXPOSED_INTERIOR = "HEAVILY_EXPOSED_INTERIOR",
}

Context.BUILT_USE = {
    RESIDENTIAL = "RESIDENTIAL",
    COMMERCIAL = "COMMERCIAL_SERVICE",
    INDUSTRIAL = "INDUSTRIAL",
    FARMYARD = "FARMYARD",
    CIVIC = "CIVIC_OTHER",
    UNKNOWN = "UNKNOWN_BUILT",
}

Context.AREA = AreaContext.TYPE

Context.offsets = {
    cardinal = {
        {-1, 0}, {1, 0}, {0, -1}, {0, 1},
    },
    adjacent = {
        {-1, -1}, {0, -1}, {1, -1},
        {-1,  0},          {1,  0},
        {-1,  1}, {0,  1}, {1,  1},
    },
    woodySeed = {
        {-1, -1}, {0, -1}, {1, -1},
        {-1,  0},          {1,  0},
        {-1,  1}, {0,  1}, {1,  1},
        {-2,  0}, {2,  0}, {0, -2}, {0,  2},
    },
    largeTreeClearance = {
        {-1, -1}, {0, -1}, {1, -1},
        {-1,  0},          {1,  0},
        {-1,  1}, {0,  1}, {1,  1},
        {-2,  0}, {2,  0}, {0, -2}, {0,  2},
    },
}

Context.offsets.treeClearance = {
    standard = {},
    jumbo = Context.offsets.adjacent,
    xl = Context.offsets.largeTreeClearance,
    xxl = {
        {-2, -2}, {-1, -2}, {0, -2}, {1, -2}, {2, -2},
        {-2, -1}, {-1, -1}, {0, -1}, {1, -1}, {2, -1},
        {-2,  0}, {-1,  0},          {1,  0}, {2,  0},
        {-2,  1}, {-1,  1}, {0,  1}, {1,  1}, {2,  1},
        {-2,  2}, {-1,  2}, {0,  2}, {1,  2}, {2,  2},
    },
}

-- Mature-tree infill must be seeded by existing trees, but not so close that
-- a newly spawned full-size tree overlaps an existing trunk. Use a ring around
-- the candidate square rather than immediate adjacency.
Context.offsets.matureTreeSeed = {}
for dx = -5, 5 do
    for dy = -5, 5 do
        local distance = math.max(math.abs(dx), math.abs(dy))
        if distance >= 2 and distance <= 5 then
            Context.offsets.matureTreeSeed[#Context.offsets.matureTreeSeed + 1] = { dx, dy }
        end
    end
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

local function safeBoolean(callback, fallback)
    local ok, value = pcall(callback)
    if not ok then return fallback == true end
    return value == true
end

function Context.create(square)
    return { square = square }
end

function Context.getOffsetSquare(square, offsetX, offsetY, offsetZ)
    if not square then return nil end
    local cell = square:getCell() or getCell()
    if not cell then return nil end
    return cell:getGridSquare(
        square:getX() + (offsetX or 0),
        square:getY() + (offsetY or 0),
        square:getZ() + (offsetZ or 0)
    )
end

function Context.anySquareAtOffsets(square, offsets, predicate)
    if not square or type(offsets) ~= "table" or type(predicate) ~= "function" then
        return false
    end
    for i = 1, #offsets do
        local offset = offsets[i]
        local nearby = Context.getOffsetSquare(square, offset[1], offset[2], offset[3] or 0)
        if nearby and predicate(nearby) then return true end
    end
    return false
end

function Context.getFloorSpriteName(square)
    if not square then return nil end
    return Cache.getFloorSpriteName(square)
end

function Context.isNaturalSpriteName(spriteName)
    spriteName = lower(spriteName)
    return startsWith(spriteName, "blends_natural_01")
        or startsWith(spriteName, "blends_natural_02")
end

function Context.isRoadSpriteName(spriteName)
    spriteName = lower(spriteName)
    return startsWith(spriteName, "blends_street_01_")
        or startsWith(spriteName, "floors_exterior_street_")
end

-- Rail detection is deliberately narrow. Unknown/custom track tiles must use
-- the compatibility terrain registry rather than being guessed destructively.
function Context.isRailSpriteName(spriteName)
    spriteName = lower(spriteName)
    return startsWith(spriteName, "location_community_railroad_")
        or startsWith(spriteName, "location_community_train_")
        or startsWith(spriteName, "location_train_")
        or startsWith(spriteName, "railroad_")
end

function Context.isHardscapeSpriteName(spriteName)
    spriteName = lower(spriteName)
    if Context.isRoadSpriteName(spriteName) or Context.isRailSpriteName(spriteName) then
        return false
    end
    return startsWith(spriteName, "floors_exterior_")
        or startsWith(spriteName, "blends_gravel_")
end

local function squareHasRailObject(square)
    local objects = square and square:getObjects() or nil
    if not objects then return false end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and Context.isRailSpriteName(obj:getSpriteName()) then return true end
    end
    return false
end

local function classifySurfaceUncached(square)
    local compatClass, hasCompatClass = Compatibility.classifyTerrain(square)
    if hasCompatClass then
        if compatClass == "natural" then return Context.SURFACE.NATURAL end
        if compatClass == "road" then return Context.SURFACE.ROAD end
        if compatClass == "hardscape" then return Context.SURFACE.HARDSCAPE end
        if compatClass == "rail" then return Context.SURFACE.RAIL end
        if compatClass == "water" then return Context.SURFACE.WATER end
        return Context.SURFACE.PROTECTED
    end

    local room = square.getRoom and square:getRoom() or nil
    local outside = true
    if square.isOutside then outside = square:isOutside() == true end
    if room ~= nil or not outside then return Context.SURFACE.INTERIOR end

    local spriteName = Context.getFloorSpriteName(square)
    if squareHasRailObject(square) or Context.isRailSpriteName(spriteName) then
        return Context.SURFACE.RAIL
    end
    if Context.isRoadSpriteName(spriteName) then return Context.SURFACE.ROAD end
    if Context.isNaturalSpriteName(spriteName) then return Context.SURFACE.NATURAL end
    if Context.isHardscapeSpriteName(spriteName) then return Context.SURFACE.HARDSCAPE end

    if square:getZ() ~= 0 and square:isSolidFloor() then
        return Context.SURFACE.UPPER_EXPOSED
    end

    return Context.SURFACE.UNKNOWN
end

function Context.classifySurface(square, context)
    if not square then return Context.SURFACE.INVALID end

    -- Water and player/mod protection are live safety checks. Do not cache them;
    -- they must reflect recent player construction or moved objects.
    local properties = square.getProperties and square:getProperties() or nil
    if properties and properties:has(IsoFlagType.water) then
        return Context.SURFACE.WATER
    end

    if Protection.isProtectedSquare(square, context) then
        return Context.SURFACE.PROTECTED
    end

    return Cache.getSurface(square, classifySurfaceUncached) or Context.SURFACE.UNKNOWN
end

function Context.isNaturalFloor(square)
    return Context.classifySurface(square) == Context.SURFACE.NATURAL
end

function Context.isRoad(square)
    return Context.classifySurface(square) == Context.SURFACE.ROAD
end

function Context.isHardscape(square)
    return Context.classifySurface(square) == Context.SURFACE.HARDSCAPE
end

function Context.isRail(square)
    return Context.classifySurface(square) == Context.SURFACE.RAIL
end

function Context.hasNaturalAtOffsets(square, offsets)
    return Context.anySquareAtOffsets(square, offsets, Context.isNaturalFloor)
end

function Context.hasTreeAtOffsets(square, offsets)
    return Context.anySquareAtOffsets(square, offsets, function(nearby)
        local objects = nearby:getObjects()
        if not objects then return false end
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj and instanceof(obj, "IsoTree") then return true end
        end
        return false
    end)
end

function Context.countTreeAtOffsets(square, offsets)
    if not square or type(offsets) ~= "table" then return 0 end
    local count = 0
    for i = 1, #offsets do
        local offset = offsets[i]
        local nearby = Context.getOffsetSquare(square, offset[1], offset[2], offset[3] or 0)
        local objects = nearby and nearby:getObjects() or nil
        if objects then
            for objectIndex = 0, objects:size() - 1 do
                local obj = objects:get(objectIndex)
                if obj and instanceof(obj, "IsoTree") then
                    count = count + 1
                    break
                end
            end
        end
    end
    return count
end

function Context.hasShrubAtOffsets(square, offsets)
    return Context.anySquareAtOffsets(square, offsets, function(nearby)
        local objects = nearby:getObjects()
        if not objects then return false end
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            local spriteName = obj and lower(obj:getSpriteName()) or ""
            if startsWith(spriteName, "f_bushes_") then return true end
        end
        return false
    end)
end

-- Natural woody succession is not source-propagation. It combines bounded
-- live-world seed signals with biome context, while deterministic patch fields
-- in Vegetation decide the final coordinate. This lets open land establish
-- sparse saplings without turning every natural tile into forest.
function Context.getWoodySuccessionFactor(square, knownSurface)
    local surface = knownSurface or Context.classifySurface(square)
    if surface ~= Context.SURFACE.NATURAL then return 0 end

    local zone = lower(Context.getZoneType(square))
    local factor = 0.35 -- sparse spontaneous establishment on open natural land
    if zone:find("deepforest", 1, true) then
        factor = 2.40
    elseif zone:find("forest", 1, true) then
        factor = 1.80
    end

    if Context.hasTreeAtOffsets(square, Context.offsets.woodySeed) then
        factor = factor + 0.80
    end
    if Context.hasShrubAtOffsets(square, Context.offsets.woodySeed) then
        factor = factor + 0.25
    end

    if factor > 2.75 then factor = 2.75 end
    return factor
end

function Context.isSurfaceEdge(square, surfaceName)
    if not square or type(surfaceName) ~= "string" then return false end
    for i = 1, #Context.offsets.cardinal do
        local offset = Context.offsets.cardinal[i]
        local nearby = Context.getOffsetSquare(square, offset[1], offset[2], 0)
        if nearby and Context.classifySurface(nearby) ~= surfaceName then return true end
    end
    return false
end

function Context.isRoadEdge(square, roadPredicate)
    if roadPredicate ~= nil and type(roadPredicate) == "function" then
        for i = 1, #Context.offsets.cardinal do
            local offset = Context.offsets.cardinal[i]
            local nearby = Context.getOffsetSquare(square, offset[1], offset[2], 0)
            if nearby and not roadPredicate(nearby) then return true end
        end
        return false
    end
    return Context.isSurfaceEdge(square, Context.SURFACE.ROAD)
end

function Context.getRoadClass(square, knownSurface)
    local surface = knownSurface or Context.classifySurface(square)
    if surface ~= Context.SURFACE.ROAD then return nil end
    if Context.isRoadEdge(square) then return "ROAD_EDGE" end
    return "ROAD_CORE"
end

function Context.getHardscapeClass(square, knownSurface)
    local surface = knownSurface or Context.classifySurface(square)
    if surface ~= Context.SURFACE.HARDSCAPE then return nil end
    if Context.isSurfaceEdge(square, Context.SURFACE.HARDSCAPE) then
        return "EXTERIOR_HARDSCAPE_EDGE"
    end
    return "EXTERIOR_HARDSCAPE_CENTER"
end

function Context.getRailClass(square, knownSurface)
    local surface = knownSurface or Context.classifySurface(square)
    if surface ~= Context.SURFACE.RAIL then return nil end
    if Context.isSurfaceEdge(square, Context.SURFACE.RAIL) then return "RAIL_EDGE" end
    return "RAIL_CORRIDOR"
end

function Context.getZoneType(square)
    if not square or not square.getZone then return nil end
    local ok, value = pcall(function()
        local zone = square:getZone()
        return zone and zone.getType and zone:getType() or nil
    end)
    if not ok or value == nil then return nil end
    return tostring(value)
end

local function currentSquareBreaches(square)
    local breaches = 0
    local objects = square and square:getObjects() or nil
    if not objects then return breaches end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and instanceof(obj, "IsoWindow") then
            local ok, breached = pcall(function()
                return obj:isSmashed() or obj:isDestroyed() or obj:isGlassRemoved()
            end)
            if ok and breached then breaches = breaches + 1 end
        elseif obj and instanceof(obj, "IsoDoor") then
            local ok, breached = pcall(function() return obj:isDestroyed() end)
            if ok and breached then breaches = breaches + 1 end
        end
    end

    return breaches
end

function Context.isInteriorPerimeter(square)
    if not square or Context.classifySurface(square) ~= Context.SURFACE.INTERIOR then
        return false
    end
    for i = 1, #Context.offsets.cardinal do
        local offset = Context.offsets.cardinal[i]
        local nearby = Context.getOffsetSquare(square, offset[1], offset[2], 0)
        if nearby then
            local okOutside, outside = pcall(function()
                return nearby.isOutside and nearby:isOutside() == true
            end)
            local nearbySurface = Context.classifySurface(nearby)
            if (okOutside and outside)
                or nearbySurface == Context.SURFACE.NATURAL
                or nearbySurface == Context.SURFACE.ROAD
                or nearbySurface == Context.SURFACE.HARDSCAPE
            then
                return true
            end
        end
    end
    return false
end

function Context.getExposure(square, knownSurface)
    if not square then return Context.EXPOSURE.SEALED_INTERIOR end
    local surface = knownSurface or Context.classifySurface(square)
    if surface ~= Context.SURFACE.INTERIOR then return Context.EXPOSURE.OUTSIDE end

    -- Exposure is deliberately local rather than building-wide: a smashed
    -- window should affect the nearby room, not magically turn every room in
    -- the building into an exterior biome. Cardinal reads stay in Context.
    local breaches = currentSquareBreaches(square)
    for i = 1, #Context.offsets.cardinal do
        local offset = Context.offsets.cardinal[i]
        local nearby = Context.getOffsetSquare(square, offset[1], offset[2], 0)
        if nearby then breaches = breaches + currentSquareBreaches(nearby) end
        if breaches >= 2 then break end
    end

    if breaches >= 2 then return Context.EXPOSURE.HEAVILY_EXPOSED_INTERIOR end
    if breaches == 1 then return Context.EXPOSURE.BREACHED_INTERIOR end
    return Context.EXPOSURE.SEALED_INTERIOR
end

function Context.inferBuiltUse(square)
    local zone = lower(Context.getZoneType(square))
    if zone:find("farm", 1, true) then return Context.BUILT_USE.FARMYARD end
    if zone:find("industrial", 1, true) then return Context.BUILT_USE.INDUSTRIAL end
    if zone:find("commercial", 1, true) or zone:find("business", 1, true)
        or zone:find("town", 1, true)
    then
        return Context.BUILT_USE.COMMERCIAL
    end
    if zone:find("residential", 1, true) or zone:find("trailer", 1, true) then
        return Context.BUILT_USE.RESIDENTIAL
    end

    local roomName = ""
    local ok, name = pcall(function()
        local room = square and square:getRoom() or nil
        return room and room.getName and room:getName() or nil
    end)
    if ok then roomName = lower(name) end

    if roomName:find("bedroom", 1, true) or roomName:find("kitchen", 1, true)
        or roomName:find("livingroom", 1, true) or roomName:find("bathroom", 1, true)
    then
        return Context.BUILT_USE.RESIDENTIAL
    end
    if roomName:find("shop", 1, true) or roomName:find("store", 1, true)
        or roomName:find("office", 1, true) or roomName:find("restaurant", 1, true)
    then
        return Context.BUILT_USE.COMMERCIAL
    end
    if roomName:find("warehouse", 1, true) or roomName:find("factory", 1, true)
        or roomName:find("garage", 1, true)
    then
        return Context.BUILT_USE.INDUSTRIAL
    end
    if roomName:find("school", 1, true) or roomName:find("hospital", 1, true)
        or roomName:find("police", 1, true) or roomName:find("fire", 1, true)
        or roomName:find("church", 1, true)
    then
        return Context.BUILT_USE.CIVIC
    end

    return Context.BUILT_USE.UNKNOWN
end

local function isBuiltOrRoadNeighbour(square, roadPredicate)
    return Context.anySquareAtOffsets(square, Context.offsets.adjacent, function(nearby)
        if type(roadPredicate) == "function" then
            local ok, isRoad = pcall(roadPredicate, nearby)
            if ok and isRoad then return true end
        end
        local okSurface, surface = pcall(Context.classifySurface, nearby)
        if not okSurface then return true end
        if surface == Context.SURFACE.ROAD or surface == Context.SURFACE.HARDSCAPE
            or surface == Context.SURFACE.RAIL
        then
            return true
        end
        local ok, built = pcall(function()
            local room = nearby.getRoom and nearby:getRoom() or nil
            local building = nearby.getBuilding and nearby:getBuilding() or nil
            return room ~= nil or building ~= nil
        end)
        return not ok or built == true
    end)
end

function Context.treeGrowthContext(square, surface, roadPredicate)
    if not square then return "constrained" end
    local okInterior, interior = pcall(function()
        local room = square.getRoom and square:getRoom() or nil
        local outside = true
        if square.isOutside then outside = square:isOutside() == true end
        return room ~= nil or not outside
    end)
    if not okInterior or interior then return "interior" end

    if surface == Context.SURFACE.ROAD or surface == Context.SURFACE.HARDSCAPE
        or surface == Context.SURFACE.RAIL
    then
        return "road"
    end
    if surface == Context.SURFACE.INTERIOR then return "interior" end

    if isBuiltOrRoadNeighbour(square, roadPredicate) then return "constrained" end

    local areaType = AreaContext.getType(square)
    if areaType == AreaContext.TYPE.DEEP_WILDERNESS or areaType == AreaContext.TYPE.FOREST then
        return "forest"
    end
    if areaType == AreaContext.TYPE.URBAN
        or areaType == AreaContext.TYPE.RESIDENTIAL
        or areaType == AreaContext.TYPE.COMMERCIAL
        or areaType == AreaContext.TYPE.INDUSTRIAL
    then
        return "constrained"
    end

    local zoneType = lower(Context.getZoneType(square))
    if zoneType:find("deepforest", 1, true) or zoneType:find("forest", 1, true) then
        return "forest"
    end
    return "open"
end

function Context.isBuiltContextObject(obj)
    if not obj or instanceof(obj, "IsoTree") then return false end
    local square = obj.getSquare and obj:getSquare() or nil
    if Compatibility.isProtectedObject(obj, square) or Protection.isProtectedObject(obj, square) then return true end
    if instanceof(obj, "BaseVehicle") then return true end

    local spriteName = lower(obj:getSpriteName())
    if spriteName == "" then return false end
    if startsWith(spriteName, "f_") or startsWith(spriteName, "e_") then return false end

    return startsWith(spriteName, "walls_")
        or startsWith(spriteName, "fixtures_")
        or startsWith(spriteName, "fencing_")
        or startsWith(spriteName, "location_")
        or startsWith(spriteName, "street_")
        or startsWith(spriteName, "industry_")
end

local LAZY_CONTEXT = {}
LAZY_CONTEXT.__index = function(context, key)
    local square = rawget(context, "square")
    local surface = rawget(context, "surface")
    local value = nil
    if key == "exposure" then
        value = Context.getExposure(square, surface)
    elseif key == "builtUse" then
        value = Context.inferBuiltUse(square)
    elseif key == "roadClass" then
        value = Context.getRoadClass(square, surface)
    elseif key == "hardscapeClass" then
        value = Context.getHardscapeClass(square, surface)
    elseif key == "railClass" then
        value = Context.getRailClass(square, surface)
    elseif key == "areaContext" then
        value = AreaContext.get(square)
    elseif key == "areaType" then
        local area = AreaContext.get(square)
        value = area and area.kind or AreaContext.TYPE.UNKNOWN
    elseif key == "areaModifiers" then
        local area = AreaContext.get(square)
        value = AreaContext.vegetationMultipliers(area and area.kind or AreaContext.TYPE.UNKNOWN)
    end
    if value ~= nil then
        rawset(context, key, value)
        return value
    end
    return nil
end

function Context.describeSquare(square, context)
    -- Plan-time context is lazy. v0.8.1 also exposes cached chunk area context. The surface itself is still resolved
    -- once up front, but exposure, built-use and edge classes are only computed
    -- if a system actually needs them. This avoids neighbour scans and room/zone
    -- lookups on the many squares that end up with no contextual operations.
    -- v0.8.3 permits callers to pass a per-square planning context so live
    -- protection scans are reused within the same plan only, not across ticks.
    context = type(context) == "table" and context or { square = square }
    context.square = square
    context.surface = Context.classifySurface(square, context)
    return setmetatable(context, LAZY_CONTEXT)
end

return Context
