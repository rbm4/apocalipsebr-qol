-- Where is the player? Two sources, best first:
--   1. Region zones from each map's regions.lua (vanilla: Muldraugh, West Point, Riverside,
--      Rosewood, March Ridge, Louisville, Valley Station...). Exact town boundaries.
--   2. The town and landmark labels the world map draws, read from each map folder's
--      worldmap-annotations.lua. Covers the B42 towns that have no region zone (Ekron,
--      Brandenburg, Irvington, Echo Creek, Fallas Lake) and any modded map that ships labels.
SurvivorBriefing = SurvivorBriefing or {}
local SB = SurvivorBriefing

local Places = {}
SB.Places = Places

Places.IN_TOWN_RADIUS = 350     -- tiles from a town label that still count as "in" that town
Places.TOWN_SPREAD = 1500       -- inside a built-up zone, a town label this close names the town
Places.LANDMARK_RADIUS = 220    -- tiles from a landmark label to mention it as "near"

local towns, landmarks

-- The vanilla town labels, used only if a map folder's label file could not be read. Same
-- coordinates as media/maps/Muldraugh, KY/worldmap-annotations.lua.
local VANILLA_DIR = "Muldraugh, KY"
local VANILLA_TOWNS = {
    { "WestPoint", 11654, 6864 }, { "Riverside", 6450, 5430 }, { "Muldraugh", 10754, 9926 },
    { "Brandenburg", 2056, 6070 }, { "Ekron", 634, 9746 }, { "Irvington", 2427, 14185 },
    { "EchoCreek", 3589, 10952 }, { "Louisville", 13077, 2238 }, { "MarchRidge", 10130, 12801 },
    { "FallasLake", 7253, 8279 }, { "Rosewood", 8159, 11661 }, { "ValleyStation", 13447, 5278 },
}

-- "WestMapleCountryClub" -> "West Maple Country Club"
function Places.splitCamel(s)
    s = s:gsub("(%l)(%u)", "%1 %2")
    s = s:gsub("(%u)(%u%l)", "%1 %2")
    return s
end

local function cleanLabel(s)
    s = s:gsub("<[bB][rR]>", " ")
    s = s:gsub("%s+", " ")
    s = s:gsub("^ ", ""):gsub(" $", "")
    return s
end

local function textOrNil(key)
    local ok, s = pcall(getTextOrNull, key)
    if ok and s and s ~= "" then return s end
    return nil
end

-- "Muldraugh, KY" -> "KY"; a folder without a comma has no state suffix.
local function stateOf(dirName)
    return dirName:match(",%s*(%S.*)$")
end

local function classify(style)
    style = tostring(style or ""):lower()
    if style:find("town") or style:find("city") then return "town" end
    if style:find("water") or style:find("street") or style:find("road") or style:find("note") then return nil end
    return "landmark"
end

-- ---- For other mods ------------------------------------------------------------------------
-- A map pack or a compatibility patch can add its own places, so the briefing can name them:
--
--   SurvivorBriefing.addTown("Raccoon City", 10200, 10199, "KY")    -- state suffix is optional
--   SurvivorBriefing.addLandmark("Spencer Mansion", 10250, 10120)
--
-- x, y are world tile coordinates. The name is shown as given, so pass getText("MapLabel_X")
-- for a translated one. Call it any time (OnGameStart is fine). Only add a place when the map
-- that has it is actually loaded, or players without that map get its name too.
local extraTowns, extraMarks = {}, {}

local function addPlace(extra, live, entry)
    if type(entry.name) ~= "string" or entry.name == "" or type(entry.x) ~= "number" or type(entry.y) ~= "number" then
        return false
    end
    for _, e in ipairs(extra) do
        if e.name == entry.name and e.x == entry.x and e.y == entry.y then return true end
    end
    table.insert(extra, entry)
    if live then table.insert(live, entry) end
    return true
end

function Places.addTown(name, x, y, state)
    local shown = name
    if type(name) == "string" and type(state) == "string" and state ~= "" then shown = name .. ", " .. state end
    return addPlace(extraTowns, towns, { base = name, name = shown, x = x, y = y })
end

function Places.addLandmark(name, x, y)
    return addPlace(extraMarks, landmarks, { name = name, x = x, y = y })
end

SB.addTown = Places.addTown
SB.addLandmark = Places.addLandmark
SB.API_VERSION = 1

-- Runs one annotations file against a stand-in map UI that records every text label and
-- swallows every other call, so the file never needs the real world-map renderer.
-- (A community map-label patch wraps this function and uses Places.splitCamel, so keep both and
-- their arguments as they are. New integrations should use addTown / addLandmark above.)
function Places.readAnnotations(fn, state, outTowns, outMarks)
    local stub = {}
    local function record(_, text, style, x, y)
        local kind = classify(style)
        x, y = tonumber(x), tonumber(y)
        if kind and type(text) == "string" and x and y then
            -- Town labels are translation keys. Some languages ship them empty (vanilla UA, AR),
            -- so fall back to the key's own name: MapLabel_WestPoint -> "West Point".
            local key = text:match("^MapLabel_(.+)$")
            local name = cleanLabel(textOrNil(text) or (key and Places.splitCamel(key)) or text)
            if name ~= "" then
                if kind == "town" then
                    table.insert(outTowns, { base = name, name = state and (name .. ", " .. state) or name, x = x, y = y })
                else
                    table.insert(outMarks, { name = name, x = x, y = y })
                end
            end
        end
        return stub
    end
    -- Another mod's label file may do more with the map API than vanilla does (call a returned
    -- object, add to a size it asked for). The stand-in answers all of that with itself, so the
    -- labels after such a line are still read.
    local function self() return stub end
    setmetatable(stub, {
        __index = function(_, k)
            if k == "addUntranslatedText" or k == "addTranslatedText" then return record end
            return self
        end,
        __call = self, __add = self, __sub = self, __mul = self, __div = self, __unm = self, __concat = self,
    })
    return pcall(fn, { javaObject = stub })
end

local function load()
    towns, landmarks = {}, {}
    local ok, dirs = pcall(getLotDirectories)
    if not ok or not dirs then
        print("[SurvivorBriefing] no map folders yet (" .. tostring(dirs) .. ")")
        return
    end
    local names, vanilla = {}, false
    for i = 0, dirs:size() - 1 do
        local dir = dirs:get(i)
        table.insert(names, dir)
        if dir == VANILLA_DIR then vanilla = true end
        local file = "media/maps/" .. dir .. "/worldmap-annotations.lua"
        if fileExists(file) then
            local okLoad, fn = pcall(reloadLuaFile, file)
            if okLoad and type(fn) == "function" then
                local okRun, err = Places.readAnnotations(fn, stateOf(dir), towns, landmarks)
                if not okRun then print("[SurvivorBriefing] labels partly read from " .. file .. ": " .. tostring(err)) end
            else
                print("[SurvivorBriefing] could not load " .. file .. ": " .. tostring(fn))
            end
        end
    end
    if #towns == 0 and vanilla then
        local state = stateOf(VANILLA_DIR)
        for _, t in ipairs(VANILLA_TOWNS) do
            local base = textOrNil("MapLabel_" .. t[1]) or Places.splitCamel(t[1])
            table.insert(towns, { base = base, name = base .. ", " .. state, x = t[2], y = t[3] })
        end
    end
    for _, e in ipairs(extraTowns) do table.insert(towns, e) end
    for _, e in ipairs(extraMarks) do table.insert(landmarks, e) end
    print("[SurvivorBriefing] places: " .. #towns .. " towns, " .. #landmarks .. " landmarks from " .. table.concat(names, " | "))
end

-- Test hook: inject label tables directly.
function Places.setLabels(t, m) towns, landmarks = t, m end

local function nearest(list, x, y)
    local best, bestD2
    for _, p in ipairs(list) do
        local dx, dy = p.x - x, p.y - y
        local d2 = dx * dx + dy * dy
        if not bestD2 or d2 < bestD2 then best, bestD2 = p, d2 end
    end
    if not best then return nil end
    return best, math.sqrt(bestD2)
end

-- Compass direction of (x, y) as seen from (fromX, fromY). North is -y on the PZ map.
function Places.compass(fromX, fromY, x, y)
    local east, north = x - fromX, fromY - y
    local ax, ay = math.abs(east), math.abs(north)
    local T = 0.4142 -- tan(22.5 deg)
    if ay <= ax * T then return east >= 0 and "E" or "W" end
    if ax <= ay * T then return north >= 0 and "N" or "S" end
    return (north >= 0 and "N" or "S") .. (east >= 0 and "E" or "W")
end

-- One tile is roughly one metre.
function Places.distance(tiles, metric)
    if metric then
        if tiles < 950 then
            return getText("IGUI_SurvivorBriefing_Metres", string.format("%d", math.max(100, math.floor(tiles / 100 + 0.5) * 100)))
        end
        return getText("IGUI_SurvivorBriefing_Km", string.format("%.1f", tiles / 1000))
    end
    return getText("IGUI_SurvivorBriefing_Miles", string.format("%.1f", math.max(0.1, tiles / 1609.34)))
end

-- Built-up areas. The vanilla Region zones are broad (Muldraugh's covers ~21 km2 of the woods
-- around the town), so a region name alone would call a forest "Muldraugh".
local TOWN_TYPES = { TownZone = true, TownZones = true, TrailerPark = true }

local function zoneNames(x, y)
    local region, building, inTown
    local ok, zones = pcall(function() return getWorld():getMetaGrid():getZonesAt(x, y, 0) end)
    if ok and zones then
        for i = 0, zones:size() - 1 do
            local z = zones:get(i)
            local t = z:getType()
            local n = z:getName()
            if TOWN_TYPES[t] then inTown = true end
            if n and n ~= "" then
                -- "Jefferson" covers the whole county; any town zone overlapping it wins.
                if t == "Region" and (not region or region == "Jefferson") then region = n end
                if t == "BuildingName" and not building then building = n end
            end
        end
    end
    return region, building, inTown
end

-- Region names match the map's own label keys (Muldraugh -> MapLabel_Muldraugh), and the
-- same town's label carries the state suffix, so reuse that where there is one.
local function regionDisplay(name)
    local own = textOrNil("IGUI_SurvivorBriefing_Region_" .. name)
    if own then return own end
    local base = textOrNil("MapLabel_" .. name) or Places.splitCamel(name)
    for _, t in ipairs(towns) do
        if t.base:lower() == base:lower() then return t.name end
    end
    return base
end

-- Vanilla already names every BuildingName zone for its key rings: IGUI_KnoxBankKey etc.
local function buildingDisplay(name)
    return textOrNil("IGUI_" .. name .. "Key") or Places.splitCamel(name)
end

-- The town (or named built-up area, like the airport) a spot is in, nil out in the wild:
--   in a built-up zone:  the region's town, else the nearest town label within TOWN_SPREAD
--   anywhere else:       the town if its label is within IN_TOWN_RADIUS
local function townAt(x, y, region, inTown)
    if inTown and region then return regionDisplay(region) end
    local t, d = nearest(towns, x, y)
    if t and (d <= Places.IN_TOWN_RADIUS or (inTown and d <= Places.TOWN_SPREAD)) then return t.name end
    return nil
end

-- Read the labels on first use, and again whenever the last read found no towns at all.
local function ready() if not towns or #towns == 0 then load() end end

function Places.town(x, y)
    ready()
    x, y = math.floor(x), math.floor(y)
    local region, _, inTown = zoneNames(x, y)
    return townAt(x, y, region, inTown)
end

-- Returns place, near. place is always a string; near may be nil. The town, else
-- "2.4 km NW of X" from the nearest town label.
function Places.describe(x, y, metric)
    ready()
    x, y = math.floor(x), math.floor(y)
    local region, building, inTown = zoneNames(x, y)
    local place, near = townAt(x, y, region, inTown), nil
    if not place then
        local t, d = nearest(towns, x, y)
        if t then
            place = getText("IGUI_SurvivorBriefing_FromTown", Places.distance(d, metric),
                getText("IGUI_SurvivorBriefing_Dir_" .. Places.compass(t.x, t.y, x, y)), t.name)
        elseif region then
            place = regionDisplay(region)
        end
    end
    if building then
        near = buildingDisplay(building)
    else
        local m, dm = nearest(landmarks, x, y)
        if m and dm <= Places.LANDMARK_RADIUS then near = m.name end
    end
    if near and place and near:lower() == place:lower() then near = nil end
    if not place then
        print("[SurvivorBriefing] no place for " .. x .. "," .. y .. " (towns " .. #towns .. ", region "
            .. tostring(region) .. ", built-up " .. tostring(inTown) .. ")")
    end
    return place or getText("IGUI_SurvivorBriefing_Unknown"), near
end
