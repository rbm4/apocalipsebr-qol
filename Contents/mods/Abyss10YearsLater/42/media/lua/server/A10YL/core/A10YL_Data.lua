-- Abyss's 10 Year Later - central deterministic asset/data registry.
-- Compiled vegetation assets are statically validated; final visual/runtime behavior
-- is still verified later in the in-game test phase.
local Compatibility = require("A10YL/core/A10YL_Compatibility")

local Data = {}

-- Runtime Fix 7: legacy TYL vegetation textures were removed completely.
-- Core A10YL now uses only Project Zomboid B42 vegetation/debris sprites.
-- Keeping this small status table lets diagnostics/addons detect that there is
-- deliberately no private vegetation pack or tiledef to load.
Data.vegetationAssets = {
    removed = true,
    releaseBlocked = false,
}

-- Surface classification moved to A10YL_Context at checkpoint #41.
-- Do not reintroduce the old exact-list road detector or blends_natural road
-- fallback here; compatibility addons register custom terrain explicitly.

-- Growth class is data, never inferred for core assets at placement time.
Data.treeGrowthClasses = {
    standard = {
        "e_carolinasilverbell_1_0",
        "e_easternredbud_1_0",
        "e_americanlinden_1_0",
        "e_americanholly_1_1",
        "e_canadianhemlock_1_1",
        "e_riverbirch_1_0",
        "e_virginiapine_1_0",
        "e_redmaple_1_0",
        "e_cockspurhawthorn_1_0",
        "e_dogwood_1_0",
        "e_yellowwood_1_0",
    },
    jumbo = {
        "e_americanhollyJUMBO_1_0",
        "e_americanlindenJUMBO_1_0",
        "e_canadianhemlockJUMBO_1_0",
        "e_carolinasilverbellJUMBO_1_0",
        "e_cockspurhawthornJUMBO_1_0",
        "e_dogwoodJUMBO_1_0",
        "e_easternredbudJUMBO_1_0",
        "e_redmapleJUMBO_1_0",
        "e_riverbirchJUMBO_1_0",
        "e_virginiapineJUMBO_1_0",
        "e_yellowwoodJUMBO_1_0",
    },
    xl = {
        "e_americanhollyJUMBOXL_1_0",
        "e_americanlindenJUMBOXL_1_0",
        "e_canadianhemlockJUMBOXL_1_0",
        "e_carolinasilverbellJUMBOXL_1_0",
        "e_cockspurhawthornJUMBOXL_1_0",
        "e_dogwoodJUMBOXL_1_0",
        "e_easternredbudJUMBOXL_1_0",
        "e_redmapleJUMBOXL_1_0",
        "e_riverbirchJUMBOXL_1_0",
        "e_virginiapineJUMBOXL_1_0",
        "e_yellowwoodJUMBOXL_1_0",
    },
    xxl = {
        "e_americanhollyJUMBOXXL_1_0",
        "e_americanlindenJUMBOXXL_1_0",
        "e_canadianhemlockJUMBOXXL_1_0",
        "e_carolinasilverbellJUMBOXXL_1_0",
        "e_cockspurhawthornJUMBOXXL_1_0",
        "e_dogwoodJUMBOXXL_1_0",
        "e_easternredbudJUMBOXXL_1_0",
        "e_redmapleJUMBOXXL_1_0",
        "e_riverbirchJUMBOXXL_1_0",
        "e_virginiapineJUMBOXXL_1_0",
        "e_yellowwoodJUMBOXXL_1_0",
    },
}

-- Retain the legacy flattened field for compatibility with addons that inspect
-- Data, while core placement consumes the explicit class pools below.
Data.trees = {}
for _, className in ipairs({ "standard", "jumbo", "xl", "xxl" }) do
    local values = Data.treeGrowthClasses[className]
    for i = 1, #values do Data.trees[#Data.trees + 1] = values[i] end
end

Data.grass = {
    "e_newgrass_1_34", 
    "e_newgrass_1_33", 
    "e_newgrass_1_24", 
    "e_newgrass_1_27", 
    "e_newgrass_1_28",
    "e_newgrass_1_29",
    "e_newgrass_1_53", 
    "e_newgrass_1_52", 
    "e_newgrass_1_51", 
    "e_newgrass_1_48",
    "e_newgrass_1_73",
    "e_newgrass_1_74",
    "e_newgrass_1_75"
}

Data.floorleaves = {
    "d_floorleaves_1_10",
    "d_floorleaves_1_5",
    "d_floorleaves_1_8",
    "d_floorleaves_1_7",
    "d_floorleaves_1_2",
    "d_floorleaves_1_9",
    "d_floorleaves_1_4",
    "d_floorleaves_1_11",
    "d_floorleaves_1_6"
}

Data.custom_grass = {}

Data.bushes = {
    "f_bushes_1_1",
    "f_bushes_1_2",
    "f_bushes_1_3",
    "f_bushes_1_4",
    "f_bushes_1_5",
    "f_bushes_1_6",
    "f_bushes_1_7",
    "f_bushes_1_8",
    "f_bushes_1_9",
    "f_bushes_1_10",
    "f_bushes_1_11",
    "f_bushes_1_12",
    "f_bushes_1_13",
    "f_bushes_1_14",
    "f_bushes_1_15"
}

-- Explicitly validated foliage choices replace the legacy base-index-plus-32
-- calculation. These names remain deterministic but no longer depend on sprite
-- sheet arithmetic at runtime.
Data.bushLeafPriority = {
    "f_bushes_1_99", "f_bushes_1_96", "f_bushes_1_97", "f_bushes_1_108",
    "f_bushes_1_101", "f_bushes_1_73", "f_bushes_1_111", "f_bushes_1_109",
    "f_bushes_1_110", "f_bushes_1_102", "f_bushes_1_98", "f_bushes_1_106",
    "f_bushes_1_69", "f_bushes_1_100", "f_bushes_1_103", "f_bushes_1_107",
    "f_bushes_1_78", "f_bushes_1_66", "f_bushes_1_70", "f_bushes_1_104",
    "f_bushes_1_77", "f_bushes_1_105", "f_bushes_1_76", "f_bushes_1_67",
    "f_bushes_1_79", "f_bushes_1_68", "f_bushes_1_71", "f_bushes_1_74",
    "f_bushes_1_75", "f_bushes_1_65", "f_bushes_1_64", "f_bushes_1_72",
    "f_bushes_1_9",
}

Data.bushLeafByBase = {
    f_bushes_1_1 = "f_bushes_1_33",
    f_bushes_1_2 = "f_bushes_1_34",
    f_bushes_1_3 = "f_bushes_1_35",
    f_bushes_1_4 = "f_bushes_1_36",
    f_bushes_1_5 = "f_bushes_1_37",
    f_bushes_1_6 = "f_bushes_1_38",
    f_bushes_1_7 = "f_bushes_1_39",
    f_bushes_1_8 = "f_bushes_1_40",
    f_bushes_1_9 = "f_bushes_1_41",
    f_bushes_1_10 = "f_bushes_1_42",
    f_bushes_1_11 = "f_bushes_1_43",
    f_bushes_1_12 = "f_bushes_1_44",
    f_bushes_1_13 = "f_bushes_1_45",
    f_bushes_1_14 = "f_bushes_1_46",
    f_bushes_1_15 = "f_bushes_1_47",
}



Data.wallW     = {"f_wallvines_1_43","f_wallvines_1_42","f_wallvines_1_37","f_wallvines_1_36","f_wallvines_1_31","f_wallvines_1_30","f_wallvines_1_25","f_wallvines_1_24"}
Data.wallW_top = {"f_wallvines_1_37","f_wallvines_1_36","f_wallvines_1_31","f_wallvines_1_30","f_wallvines_1_25","f_wallvines_1_24"}
Data.wallW_low = {"f_wallvines_1_25","f_wallvines_1_24"}
Data.wallN     = {"f_wallvines_1_45","f_wallvines_1_44","f_wallvines_1_39","f_wallvines_1_38","f_wallvines_1_33","f_wallvines_1_32","f_wallvines_1_27","f_wallvines_1_26"}
Data.wallN_top = {"f_wallvines_1_39","f_wallvines_1_38","f_wallvines_1_33","f_wallvines_1_32","f_wallvines_1_27","f_wallvines_1_26"}
Data.wallN_low = {"f_wallvines_1_27","f_wallvines_1_26"}
Data.wallNW    = {"f_wallvines_1_47","f_wallvines_1_46","f_wallvines_1_41","f_wallvines_1_40","f_wallvines_1_34","f_wallvines_1_35","f_wallvines_1_29","f_wallvines_1_28"}
Data.wallNW_top = {"f_wallvines_1_41","f_wallvines_1_40","f_wallvines_1_34","f_wallvines_1_35","f_wallvines_1_29","f_wallvines_1_28"}
Data.wallNW_low = {"f_wallvines_1_29","f_wallvines_1_28"}


-- Vanilla erosion wall cracks. B42.20.4 still loads d_wallcracks_1_0..71.
-- The erosion wall-overlay family uses the same repeating six-sprite face layout
-- as the vanilla wall-vine family already used above: W pair, N pair, NW pair.
-- Keep face-specific pools so an additive crack is never deliberately placed on
-- the wrong wall orientation. Every chosen sprite is still runtime-validated
-- with getSprite() before planning/applying.
Data.wallCracks = { W = {}, N = {}, NW = {} }
for i = 0, 71 do
    local name = "d_wallcracks_1_" .. tostring(i)
    local face = i % 6
    if face <= 1 then
        Data.wallCracks.W[#Data.wallCracks.W + 1] = name
    elseif face <= 3 then
        Data.wallCracks.N[#Data.wallCracks.N + 1] = name
    else
        Data.wallCracks.NW[#Data.wallCracks.NW + 1] = name
    end
end

-- Roof weathering remains deliberately empty. Point #5 only enables cosmetic,
-- additive wall cracks; wall/roof removal or destructive structural failure is
-- still outside the safe implementation.
Data.structureWeathering = {
    wall = Data.wallCracks,
    roof = {},
}

Data.trash = {}
for i = 0, 51 do
    Data.trash[#Data.trash + 1] = "trash_01_" .. tostring(i)
end

-- Stable public compatibility pool names. Compatibility addons may append
-- sprites to these pools without replacing A10YL's core data. Returned pools
-- are sorted by compatibility sprite name and cached by registry revision so
-- mod load order does not change the final deterministic choice.
local OUTPUT_BASE = {
    tree = "trees",
    grass = "grass",
    leaf = "floorleaves",
    customgrass = "custom_grass",
    bush = "bushes",
    debris = "trash",
    vinew = "wallW",
    vinewtop = "wallW_top",
    vinewlow = "wallW_low",
    vinen = "wallN",
    vinentop = "wallN_top",
    vinenlow = "wallN_low",
    vinenw = "wallNW",
    vinenwtop = "wallNW_top",
    vinenwlow = "wallNW_low",
}

local outputCache = {}
local treeClassCache = {}
local coreTreeClassBySprite = {}

for className, values in pairs(Data.treeGrowthClasses) do
    for i = 1, #values do
        coreTreeClassBySprite[values[i]] = className
    end
end

function Data.classifyTreeSprite(spriteName)
    if type(spriteName) ~= "string" or spriteName == "" then return nil end
    if coreTreeClassBySprite[spriteName] then return coreTreeClassBySprite[spriteName] end

    -- Compatibility additions have no class parameter in API v1. Recognise
    -- only the established, unambiguous class tokens; otherwise treat the
    -- addition conservatively as a standard tree.
    local normalized = string.lower(spriteName)
    if normalized:find("jumboxxl", 1, true) then return "xxl" end
    if normalized:find("jumboxl", 1, true) then return "xl" end
    if normalized:find("jumbo", 1, true) then return "jumbo" end
    return "standard"
end

function Data.getTreeGrowthPool(className)
    className = type(className) == "string" and string.lower(className) or nil
    if not Data.treeGrowthClasses[className] then return {} end

    local revision = Compatibility.getRevision()
    local cached = treeClassCache[className]
    if cached and cached.revision == revision then return cached.values end

    local values, seen = {}, {}
    local base = Data.treeGrowthClasses[className]
    for i = 1, #base do
        values[#values + 1] = base[i]
        seen[base[i]] = true
    end

    local additions = Compatibility.getOutputSprites("tree")
    for i = 1, #additions do
        local spriteName = additions[i]
        if not seen[spriteName] and Data.classifyTreeSprite(spriteName) == className then
            values[#values + 1] = spriteName
            seen[spriteName] = true
        end
    end

    treeClassCache[className] = { revision = revision, values = values }
    return values
end

function Data.getBushLeafForBase(spriteName)
    return Data.bushLeafByBase[tostring(spriteName or "")]
end

function Data.getStructureWeatheringPool(kind, orientation)
    kind = type(kind) == "string" and string.lower(kind) or nil
    local values = kind and Data.structureWeathering[kind] or nil
    if type(values) ~= "table" then return {} end
    if kind == "wall" then
        orientation = type(orientation) == "string" and string.upper(orientation) or nil
        local pool = orientation and values[orientation] or nil
        return type(pool) == "table" and pool or {}
    end
    return values
end

function Data.validateVegetationRegistry()
    local report = {
        errors = {},
        treeCounts = {},
        customGroundCoverCount = #Data.custom_grass,
        bushCount = #Data.bushes,
        bushLeafPriorityCount = #Data.bushLeafPriority,
    }
    local seen = {}

    local function invalid(message)
        report.errors[#report.errors + 1] = message
    end

    for _, className in ipairs({ "standard", "jumbo", "xl", "xxl" }) do
        local values = Data.treeGrowthClasses[className]
        report.treeCounts[className] = #values
        if #values < 1 then invalid("empty tree class: " .. className) end
        for i = 1, #values do
            local spriteName = values[i]
            if type(spriteName) ~= "string" or spriteName == "" then
                invalid("invalid tree sprite in class: " .. className)
            elseif seen[spriteName] then
                invalid("duplicate tree sprite: " .. spriteName)
            else
                local normalized = string.lower(spriteName)
                local markerClass = "standard"
                if normalized:find("jumboxxl", 1, true) then
                    markerClass = "xxl"
                elseif normalized:find("jumboxl", 1, true) then
                    markerClass = "xl"
                elseif normalized:find("jumbo", 1, true) then
                    markerClass = "jumbo"
                end
                if markerClass ~= className
                    or Data.classifyTreeSprite(spriteName) ~= className
                then
                    invalid("tree class mismatch: " .. spriteName)
                end
            end
            if type(spriteName) == "string" then seen[spriteName] = true end
        end
    end

    seen = {}
    for i = 1, #Data.bushes do
        local spriteName = Data.bushes[i]
        if seen[spriteName] then invalid("duplicate bush sprite: " .. spriteName) end
        seen[spriteName] = true
        if not Data.bushLeafByBase[spriteName] then
            invalid("missing explicit bush leaf: " .. spriteName)
        end
    end

    local mappedLeaves = 0
    for baseSprite, leafSprite in pairs(Data.bushLeafByBase) do
        mappedLeaves = mappedLeaves + 1
        if not seen[baseSprite] then invalid("leaf mapping for unknown bush: " .. baseSprite) end
        if type(leafSprite) ~= "string" or leafSprite == "" then
            invalid("invalid mapped bush leaf: " .. baseSprite)
        end
    end
    if mappedLeaves ~= #Data.bushes then invalid("bush leaf mapping count mismatch") end

    seen = {}
    for i = 1, #Data.bushLeafPriority do
        local spriteName = Data.bushLeafPriority[i]
        if type(spriteName) ~= "string" or spriteName == "" then
            invalid("invalid priority bush leaf")
        elseif seen[spriteName] then
            invalid("duplicate priority bush leaf: " .. spriteName)
        end
        if type(spriteName) == "string" then seen[spriteName] = true end
    end

    seen = {}
    for i = 1, #Data.custom_grass do
        local spriteName = Data.custom_grass[i]
        if type(spriteName) ~= "string" or spriteName == "" then
            invalid("invalid custom ground cover sprite")
        elseif seen[spriteName] then
            invalid("duplicate custom ground cover: " .. spriteName)
        end
        if type(spriteName) == "string" then seen[spriteName] = true end
    end

    return #report.errors == 0, report
end

function Data.getOutputPool(poolName)
    if type(poolName) ~= "string" then return {} end
    local normalized = string.lower(poolName)
    local baseName = OUTPUT_BASE[normalized]
    if not baseName then return {} end

    local revision = Compatibility.getRevision()
    local cached = outputCache[normalized]
    if cached and cached.revision == revision then
        return cached.values
    end

    local values = {}
    local base = Data[baseName] or {}
    for i = 1, #base do values[#values + 1] = base[i] end

    local additions = Compatibility.getOutputSprites(normalized)
    for i = 1, #additions do values[#values + 1] = additions[i] end

    outputCache[normalized] = { revision = revision, values = values }
    return values
end

return Data
