-- Final profile/category/advanced sandbox resolver from checkpoints #23/#24.
-- Systems receive only immutable effective values, never raw inheritance enums.
local Identity = require("A10YL/A10YL_Identity")

local Config = {}

Config.RESOLVER_VERSION = 6

local CATEGORY_NAMES = {
    "VegetationIntensity",
    "WoodyEncroachment",
    "ShrubDensity",
    "VineGrowth",
    "HardSurfaceEncroachment",
    "RoadDeterioration",
    "DebrisIntensity",
    "HardscapeReclamation",
    "OpeningDamage",
    "HumanLegacy",
    "StructuralDeterioration",
    "InteriorIntrusion",
    "FenceDeterioration",
}

local ADVANCED_PARENTS = {
    LargeTreeFrequency = "WoodyEncroachment",
    RoadCoreVegetation = "HardSurfaceEncroachment",
    RoadBreakup = "RoadDeterioration",
    ExteriorDebris = "DebrisIntensity",
    InteriorDebris = "DebrisIntensity",
    WindowDamage = "OpeningDamage",
    DoorDamage = "OpeningDamage",
    BarricadeRemnants = "HumanLegacy",
    RoofFailure = "StructuralDeterioration",
    InteriorWoodyGrowth = "InteriorIntrusion",
}

local ADVANCED_NAMES = {
    "LargeTreeFrequency",
    "RoadCoreVegetation",
    "RoadBreakup",
    "ExteriorDebris",
    "InteriorDebris",
    "WindowDamage",
    "DoorDamage",
    "BarricadeRemnants",
    "RoofFailure",
    "InteriorWoodyGrowth",
}

-- Levels: 0 Disabled, 1 Low, 2 Moderate, 3 High, 4 Extreme.

-- Realistic is the canonical visual baseline. The stronger profiles are derived
-- from that baseline by category offsets rather than maintained as separate,
-- hand-tuned tables. This keeps Overgrown and Extreme moving in step whenever
-- Realistic is adjusted during balance passes.
local REALISTIC_PROFILE_LEVELS = {
    VegetationIntensity = 3,
    WoodyEncroachment = 2,
    ShrubDensity = 3,
    VineGrowth = 2,
    HardSurfaceEncroachment = 3,
    RoadDeterioration = 3,
    DebrisIntensity = 2,
    HardscapeReclamation = 3,
    OpeningDamage = 2,
    HumanLegacy = 2,
    StructuralDeterioration = 2,
    InteriorIntrusion = 1,
    FenceDeterioration = 2,
}

local PROFILE_LEVEL_OFFSETS = {
    [1] = {},
    [2] = {
        VegetationIntensity = 1,
        WoodyEncroachment = 1,
        ShrubDensity = 1,
        VineGrowth = 1,
        HardSurfaceEncroachment = 1,
        RoadDeterioration = 0,
        DebrisIntensity = 1,
        HardscapeReclamation = 1,
        OpeningDamage = 1,
        HumanLegacy = 1,
        StructuralDeterioration = 1,
        InteriorIntrusion = 1,
        FenceDeterioration = 1,
    },
    [3] = {
        VegetationIntensity = 1,
        WoodyEncroachment = 2,
        ShrubDensity = 1,
        VineGrowth = 2,
        HardSurfaceEncroachment = 1,
        RoadDeterioration = 1,
        DebrisIntensity = 2,
        HardscapeReclamation = 1,
        OpeningDamage = 2,
        HumanLegacy = 2,
        StructuralDeterioration = 2,
        InteriorIntrusion = 3,
        FenceDeterioration = 2,
    },
}

local function profileLevel(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 4 then return 4 end
    return value
end

local function buildProfileLevels(profile)
    local result = {}
    local offsets = PROFILE_LEVEL_OFFSETS[profile] or PROFILE_LEVEL_OFFSETS[1]
    for _, name in ipairs(CATEGORY_NAMES) do
        result[name] = profileLevel((REALISTIC_PROFILE_LEVELS[name] or 0) + (offsets[name] or 0))
    end
    return result
end

local PROFILE_LEVELS = {
    [1] = buildProfileLevels(1),
    [2] = buildProfileLevels(2),
    [3] = buildProfileLevels(3),
}

local PROFILE_NAMES = {
    [1] = "Realistic",
    [2] = "Overgrown",
    [3] = "Extreme",
}

local PROCESSING_MODE_NAMES = {
    [1] = "Conservative",
    [2] = "Balanced",
    [3] = "Fast",
    [4] = "Custom",
    [5] = "Background Only",
}

local EXISTING_SAVE_MODE_NAMES = {
    [1] = "New Areas Only",
    [2] = "Age Existing Areas Too",
    [3] = "Disabled",
}

-- Balanced is the release baseline. Conservative deliberately reduces work for
-- hosted servers, weaker CPUs and large player counts. Fast is faster but does
-- not reintroduce the v0.6.4/v0.6.5 blocking startup burst behaviour.
local SCHEDULER_PRESETS = {
    [1] = { discoveryChecksPerTick = 8, plansPerTick = 1, mutationsPerTick = 2, timeBudgetMs = 1.0 },
    [2] = { discoveryChecksPerTick = 16, plansPerTick = 1, mutationsPerTick = 4, timeBudgetMs = 2.0 },
    [3] = { discoveryChecksPerTick = 32, plansPerTick = 2, mutationsPerTick = 8, timeBudgetMs = 4.0 },
    -- v0.8.0 accessibility mode. This keeps ageing active but removes boosted
    -- foreground/catch-up budgets and synchronous preload work in Queue.
    [5] = { discoveryChecksPerTick = 4, plansPerTick = 1, mutationsPerTick = 1, timeBudgetMs = 0.75 },
}

-- Each curve is indexed by semantic level + 1. Values are contextual chances,
-- not the semantic intensity scalars exposed below.
local CURVES = {
    groundGrass = { 0, 25, 50, 75, 95 },
    groundLeaves = { 0, 4, 10, 20, 32 },
    groundDetail = { 0, 3, 8, 16, 28 },
    naturalTrees = { 0, 0.5, 1, 2, 4 },
    naturalShrubs = { 0, 2, 5, 10, 18 },
    vines = { 0, 20, 45, 70, 90 },
    roadGrass = { 0, 3, 8, 16, 28 },
    roadShrubs = { 0, 0, 0.5, 1.5, 3 },
    roadDetail = { 0, 0, 0, 0, 0 },
    roadTrees = { 0, 0, 0.25, 0.5, 1 },
    largeTreeShare = { 0, 5, 10, 16, 24 },
    -- Sparse mature-tree infill is separate from ordinary sapling/young-tree
    -- succession. It only triggers on natural ground near existing live trees,
    -- so presets can add the occasional fully grown tree inside established
    -- tree areas without planting them in roads, houses, hardscape or roofs.
    matureTreesNearExisting = { 0, 0.25, 0.60, 1.00, 1.60 },
    -- Point #5 final road balance: neglected roads remain visibly weathered,
    -- but crack overlays no longer dominate the pavement texture.
    roadCracks = { 0, 4, 8, 15, 24 },
    dirtCracks = { 0, 4, 8, 14, 22 },
    exteriorTrash = { 0, 1, 3, 7, 14 },
    nearObjectTrash = { 0, 10, 25, 45, 70 },
    roadTrash = { 0, 0, 1, 3, 6 },
    interiorTrash = { 0, 5, 15, 30, 50 },
    openingDamage = { 0, 20, 50, 80, 100 },
    barricades = { 0, 8, 20, 40, 65 },
    -- Cosmetic vanilla erosion cracks only. Live Point #5 testing showed the
    -- first curve was too sparse, especially under Realistic. These remain
    -- additive overlays only; walls are never removed, replaced or weakened.
    wallCracks = { 0, 10, 20, 35, 50 },
    roofs = { 0, 0, 0.5, 1.5, 4 },
    interiorGrowth = { 0, 1, 4, 10, 25 },
    fences = { 0, 10, 25, 50, 80 },
}

local READ_ONLY_BACKING = {}

local function immutable(value, memo)
    if type(value) ~= "table" then return value end
    if READ_ONLY_BACKING[value] then return value end
    memo = memo or {}
    if memo[value] then return memo[value] end

    local proxy = {}
    local backing = {}
    memo[value] = proxy
    for key, child in pairs(value) do
        backing[key] = immutable(child, memo)
    end
    READ_ONLY_BACKING[proxy] = backing
    return setmetatable(proxy, {
        __index = backing,
        __newindex = function()
            error("A10YL effective configuration is immutable", 2)
        end,
        __pairs = function() return next, backing, nil end,
        __len = function() return #backing end,
        __metatable = false,
    })
end

local function getValue(sandbox, name, default)
    local option = sandbox and sandbox:getOptionByName(name) or nil
    if option then
        local value = option:getValue()
        if value ~= nil then return value end
    end
    return default
end

local function clampInteger(value, minValue, maxValue, default)
    value = tonumber(value)
    if value == nil then return default end
    value = math.floor(value)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function clampNumber(value, minValue, maxValue, default)
    value = tonumber(value)
    if value == nil then return default end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function booleanValue(value, default)
    if type(value) == "boolean" then return value end
    if value == 1 or value == "true" then return true end
    if value == 0 or value == "false" then return false end
    return default == true
end

local function levelFromOverride(rawValue, inheritedLevel)
    local choice = clampInteger(rawValue, 1, 6, 1)
    if choice == 1 then return inheritedLevel end
    return choice - 2
end

local function intensity(level)
    return clampInteger(level, 0, 4, 0) * 0.25
end

local function curve(name, level)
    return CURVES[name][clampInteger(level, 0, 4, 0) + 1]
end

local function copySchedulerBudget(source)
    local budget = {}
    for key, value in pairs(source) do budget[key] = value end
    budget.readyLowWater = 32
    budget.readyHighWater = 64
    budget.retryLimit = 2
    budget.operationChecksPerTick = math.max(24, budget.mutationsPerTick * 8)
    budget.readyChecksPerTick = math.max(16, budget.plansPerTick * 8)
    return budget
end

local function resolveSchedulerMutable(mode, customPlans, customMutations, customTimeBudgetMs)
    mode = clampInteger(mode, 1, 5, 2)
    local budget
    if mode <= 3 or mode == 5 then
        budget = copySchedulerBudget(SCHEDULER_PRESETS[mode])
    else
        local plans = clampInteger(customPlans, 1, 4, 1)
        local mutations = clampInteger(customMutations, 1, 16, 4)
        budget = copySchedulerBudget({
            discoveryChecksPerTick = math.min(64, math.max(8, plans * 16)),
            plansPerTick = plans,
            mutationsPerTick = mutations,
            timeBudgetMs = clampNumber(customTimeBudgetMs, 0.5, 6.0, 2.0),
        })
    end
    budget.mode = mode
    return budget
end

local function buildGeneration(categoryLevel, advancedLevel)
    local categories = {}
    local advanced = {}
    for _, name in ipairs(CATEGORY_NAMES) do
        categories[name] = intensity(categoryLevel[name])
    end
    for _, name in ipairs(ADVANCED_NAMES) do
        advanced[name] = intensity(advancedLevel[name])
    end

    local vineLevel = categoryLevel.VineGrowth
    local roadBreakupLevel = advancedLevel.RoadBreakup
    local structuralLevel = categoryLevel.StructuralDeterioration
    -- Roof failure remains reserved/hidden. Keep the legacy RoofFailure key tolerated
    -- for old sandbox files, but force the runtime feature off until a safe roof
    -- ageing implementation exists. This avoids dead roof checks in hot planning.
    local wallPercentage = curve("wallCracks", structuralLevel)
    local roofPercentage = 0

    return {
        resolverVersion = Config.RESOLVER_VERSION,
        intensities = {
            categories = categories,
            advanced = advanced,
        },
        features = {
            vines = vineLevel > 0,
            vineNeighbor = vineLevel >= 2,
            cracks = roadBreakupLevel > 0,
            walls = wallPercentage > 0,
            roofs = false,
        },

        treePercentage = curve("naturalTrees", categoryLevel.WoodyEncroachment),
        bushesPercentage = curve("naturalShrubs", categoryLevel.ShrubDensity),
        grassPercentage = curve("groundGrass", categoryLevel.VegetationIntensity),
        floorleavesPercentage = curve("groundLeaves", categoryLevel.VegetationIntensity),
        customGrassPercentage = curve("groundDetail", categoryLevel.VegetationIntensity),
        vinePercentage = curve("vines", vineLevel),

        treePercentageOnRoad = curve("roadTrees", advancedLevel.RoadCoreVegetation),
        bushesPercentageOnRoad = curve("roadShrubs", categoryLevel.HardSurfaceEncroachment),
        grassPercentageOnRoad = curve("roadGrass", categoryLevel.HardSurfaceEncroachment),
        customGrassPercentageOnRoad = curve("roadDetail", categoryLevel.HardSurfaceEncroachment),
        roadCoreGrassPercentage = curve("roadGrass", advancedLevel.RoadCoreVegetation),
        roadCoreLeafPercentage = curve("groundLeaves", advancedLevel.RoadCoreVegetation),
        roadCoreDetailPercentage = curve("roadDetail", advancedLevel.RoadCoreVegetation),
        largeTreePercentage = curve("largeTreeShare", advancedLevel.LargeTreeFrequency),
        matureTreePercentage = curve("matureTreesNearExisting", advancedLevel.LargeTreeFrequency),

        roadCrackOverlayPercentage = curve("roadCracks", roadBreakupLevel),
        dirtCrackOverlayPercentage = curve("dirtCracks", categoryLevel.HardscapeReclamation),

        trashPercentage = curve("exteriorTrash", advancedLevel.ExteriorDebris),
        trashNearObjectsPercentage = curve("nearObjectTrash", advancedLevel.ExteriorDebris),
        trashOnRoadPercentage = curve("roadTrash", advancedLevel.ExteriorDebris),
        trashPercentageInterior = curve("interiorTrash", advancedLevel.InteriorDebris),

        ruinedWindowPercentage = curve("openingDamage", advancedLevel.WindowDamage),
        ruinedDoorPercentage = curve("openingDamage", advancedLevel.DoorDamage),
        barricadePercentage = curve("barricades", advancedLevel.BarricadeRemnants),
        overgrowthInteriorPercentage = curve("interiorGrowth", advancedLevel.InteriorWoodyGrowth),
        wallPercentage = wallPercentage,
        roofPercentage = roofPercentage,
        fencePercentage = curve("fences", categoryLevel.FenceDeterioration),
    }
end

function Config.resolve(sandbox)
    if not sandbox then return nil end

    local profile = clampInteger(getValue(sandbox, "A10YL.AgeingProfile", 1), 1, 3, 1)
    local existingSaveMode = clampInteger(getValue(sandbox, "A10YL.ExistingSaveMode", 1), 1, 3, 1)
    local base = PROFILE_LEVELS[profile]
    local categoryLevel = {}
    for _, name in ipairs(CATEGORY_NAMES) do
        categoryLevel[name] = levelFromOverride(
            getValue(sandbox, "A10YL." .. name, 1), base[name]
        )
    end

    local advancedLevel = {}
    for _, name in ipairs(ADVANCED_NAMES) do
        advancedLevel[name] = levelFromOverride(
            getValue(sandbox, "A10YL." .. name, 1),
            categoryLevel[ADVANCED_PARENTS[name]]
        )
    end

    local processingMode = clampInteger(
        getValue(sandbox, "A10YL.ProcessingMode", 2), 1, 5, 2
    )
    local customPlans = getValue(sandbox, "A10YL.CustomPlansPerTick", 1)
    local customMutations = getValue(sandbox, "A10YL.CustomMutationsPerTick", 4)
    local customTime = getValue(sandbox, "A10YL.CustomTimeBudgetMs", 2.0)
    local debugMode = booleanValue(getValue(sandbox, "A10YL.DebugMode", false), false)

    local generation = buildGeneration(categoryLevel, advancedLevel)
    -- Cache this once per resolved sandbox config. Processor.buildPlan is a hot
    -- per-square path and must not recursively canonicalise the same config table
    -- thousands of times while walking/driving/pre-ageing.
    generation.generationHash = Config.generationHash(generation)

    return immutable({
        generation = generation,
        scheduler = resolveSchedulerMutable(
            processingMode, customPlans, customMutations, customTime
        ),
        debugMode = debugMode,
        profileName = PROFILE_NAMES[profile],
        processingModeName = PROCESSING_MODE_NAMES[processingMode],
        existingSaveMode = existingSaveMode,
        existingSaveModeName = EXISTING_SAVE_MODE_NAMES[existingSaveMode],
    })
end

function Config.readAll()
    local sandbox = type(getSandboxOptions) == "function" and getSandboxOptions() or nil
    return Config.resolve(sandbox)
end

function Config.read()
    local resolved = Config.readAll()
    return resolved and resolved.generation or nil
end

function Config.readScheduler()
    local resolved = Config.readAll()
    return resolved and resolved.scheduler or nil
end

function Config.resolveScheduler(mode, customPlans, customMutations, customTimeBudgetMs)
    return immutable(resolveSchedulerMutable(
        mode, customPlans, customMutations, customTimeBudgetMs
    ))
end

local function canonicalValue(value)
    local valueType = type(value)
    if valueType == "nil" then return "nil" end
    if valueType == "boolean" then return value and "true" or "false" end
    if valueType == "number" then return string.format("%.17g", value) end
    if valueType == "string" then return string.format("%q", value) end
    if valueType ~= "table" then
        error("generation config contains unsupported value type: " .. valueType)
    end

    local source = READ_ONLY_BACKING[value] or value
    local keys = {}
    for key, _ in pairs(source) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local typeA, typeB = type(a), type(b)
        if typeA ~= typeB then return typeA < typeB end
        return tostring(a) < tostring(b)
    end)

    local parts = { "{" }
    for i = 1, #keys do
        local key = keys[i]
        parts[#parts + 1] = canonicalValue(key)
        parts[#parts + 1] = "="
        parts[#parts + 1] = canonicalValue(source[key])
        parts[#parts + 1] = ";"
    end
    parts[#parts + 1] = "}"
    return table.concat(parts)
end

function Config.generationHash(config)
    if type(config) ~= "table" then return nil end
    local source = READ_ONLY_BACKING[config] or config
    local cached = source and source.generationHash or nil
    if type(cached) == "string" and cached ~= "" then
        return cached
    end
    return Identity.shortToken(canonicalValue(config))
end

-- PZ dedicated servers can occasionally return nil for an already-loaded Lua
-- module through require(). Keep one explicit singleton as a recovery path for
-- server modules that need the resolver after the loader cache has been primed.
A10YL_Config = Config

return Config
