RegionManager.Shared = RegionManager.Shared or {}

-- Module dependencies
RegionManager.Shared.sandboxOptions = nil

-- Default number of extra hits tough zombies resist before dying (1-99)
-- Used as fallback when the region does not specify maxHits.
-- Shared between client & server code: change ONLY here.
---@type number
RegionManager.Shared.DEFAULT_MAX_HITS = 2

---@type string[]
local SIMBA_TSY_SprinterWalkTypes = {"sprint1", "sprint2", "sprint3", "sprint4", "sprint5"}

---@type number
local SIMBA_TSY_BaselineSprinterChance = 0 -- Default when not in any region

-- Cache for default stats
local defaultSpeed = nil
local defaultSight = nil
local defaultHearing = nil
local defaultToughness = nil
local defaultStrength = nil
local defaultCognition = nil
local defaultMemory = nil
local defaultArmorFactor = nil
local defaultMaxDefense = nil

-- Initialize sandbox options after game boot
local function InitializeSandboxOptions()
    if not RegionManager.Shared.sandboxOptions then
        RegionManager.Shared.sandboxOptions = getSandboxOptions()
        if RegionManager.Shared.sandboxOptions then
            print("SIMBA_TSY: Sandbox options initialized successfully")
        else
            print("SIMBA_TSY WARNING: Failed to initialize sandbox options")
        end
    end
end
-- Hook into early game events
if isServer() then
    Events.OnInitWorld.Add(InitializeSandboxOptions)
else
    Events.OnGameBoot.Add(InitializeSandboxOptions)
end

-- Get default zombie speed from sandbox options
function RegionManager.Shared.getDefaultSpeed()
    if defaultSpeed == nil then
        defaultSpeed = RegionManager.Shared.sandboxOptions:getOptionByName("ZombieLore.Speed") and
                           RegionManager.Shared.sandboxOptions:getOptionByName("ZombieLore.Speed"):getValue() or 2
    end
    return defaultSpeed
end
-- 1=Eagle, 2=Normal, 3=Poor, 4=Random, 5=Random between Normal and Poor
function RegionManager.Shared.getDefaultSight()
    if defaultSight == nil then
        defaultSight = RegionManager.Shared.sandboxOptions:getOptionByName("ZombieLore.Sight")
    end
    return defaultSight
end
-- 1=Pinpoint, 2=Normal, 3=Poor, 4=Random, 5=Random between Normal and Poor
function RegionManager.Shared.getDefaultHearing()
    if defaultHearing == nil then
        defaultHearing = RegionManager.Shared.sandboxOptions:getOptionByName("ZombieLore.Hearing")
    end
    return defaultHearing
end

-- 1=Tough, 2=Normal, 3=Fragile, 4=Random
function RegionManager.Shared.getDefaultToughness()
    if defaultToughness == nil then
        defaultToughness = RegionManager.Shared.sandboxOptions:getOptionByName("ZombieLore.Toughness")
    end
    return defaultToughness
end

-- 1=Superhuman, 2=Normal, 3=Weak, 4=Random
function RegionManager.Shared.getDefaultStrength()
    if defaultStrength == nil then
        defaultStrength = RegionManager.Shared.sandboxOptions:getOptionByName("ZombieLore.Strength")
    end
    return defaultStrength
end
-- 1=Navigate and Use Doors, 2=Navigate, 3=Basic Navigation, 4=Random
function RegionManager.Shared.getDefaultCognition()
    if defaultCognition == nil then
        defaultCognition = RegionManager.Shared.sandboxOptions:getOptionByName("ZombieLore.Cognition")
    end
    return defaultCognition
end

-- 1=Long, 2=Normal, 3=Short, 4=None, 5=Random, 6=Random between Normal and None
function RegionManager.Shared.getDefaultMemory()
    if defaultMemory == nil then
        defaultMemory = RegionManager.Shared.sandboxOptions:getOptionByName("ZombieLore.Memory")
    end
    return defaultMemory
end
-- Zombie armor effectiveness multiplier. 0.00 to 100.00 (default 2)
function RegionManager.Shared.getDefaultArmorFactor()
    if defaultArmorFactor == nil then
        defaultArmorFactor = RegionManager.Shared.sandboxOptions:getOptionByName("ZombieLore.ZombiesArmorFactor")
    end
    return defaultArmorFactor
end

-- Maximum zombie armor defense percentage. 0 to 100
function RegionManager.Shared.getDefaultMaxDefense()
    if defaultMaxDefense == nil then
        defaultMaxDefense = RegionManager.Shared.sandboxOptions:getOptionByName("ZombieLore.ZombiesMaxDefense")
    end
    return defaultMaxDefense
end

-- Create a persistent identifier for zombies (matches server logic)
---@param zombie IsoZombie
---@return string persistentID
function RegionManager.Shared.GetZombiePersistentID(zombie)
    -- Combine attributes that are stable across respawns
    local outfit = zombie:getPersistentOutfitID()
    local female = zombie:isFemale() and 1 or 0

    return string.format("%d_%d", outfit, female)
end

-- Make zombie sprint
---@param zombie IsoZombie
function RegionManager.Shared.makeSprint(zombie, sandboxOptions)
    if defaultSpeed == nil then
        defaultSpeed = RegionManager.Shared.getDefaultSpeed()
    end

    zombie:makeInactive(true)
    sandboxOptions:set("ZombieLore.Speed", 1)
    zombie:makeInactive(false)
    sandboxOptions:set("ZombieLore.Speed", defaultSpeed)
end

-- Make zombie shamble
---@param zombie IsoZombie
function RegionManager.Shared.makeShamble(zombie, sandboxOptions)
    if defaultSpeed == nil then
        defaultSpeed = RegionManager.Shared.getDefaultSpeed()
    end

    zombie:makeInactive(true)
    sandboxOptions:set("ZombieLore.Speed", 3)
    zombie:makeInactive(false)
    sandboxOptions:set("ZombieLore.Speed", defaultSpeed)
end

-- Deterministic pseudo-random (matches server logic)
---@param zombieID number
---@param max number
---@return number
-- Deterministic pseudo-random (matches server logic)
---@param max number
---@return number
function RegionManager.Shared.GetDeterministicRandom(max)
    if not RegionManager.Shared._rngSeed then
        RegionManager.Shared._rngSeed = os.time()
    end
    local seed = RegionManager.Shared._rngSeed
    seed = ((seed * 1103515245) + 12345) % 2147483648
    RegionManager.Shared._rngSeed = seed
    return seed % max
end

-- Set the internal seed (call this with a zombie-specific value before calling GetDeterministicRandom)
---@param seed number
function RegionManager.Shared.SetDeterministicSeed(seed)
    if seed < 0 then
        seed = seed * -1
    end
    RegionManager.Shared._rngSeed = seed
end

-- Get sprinter chance for current position based on known regions
---@param region table Region data
---@return number chance 0-100 sprinter percentage
function RegionManager.Shared.GetSprinterChance(region)
    -- Check which region contains this position
    if region.properties.sprinterChance and type(region.properties.sprinterChance) == "number" then
        local chance = region.properties.sprinterChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end

    -- No region found or region has no sprinter config
    return 0
end

-- Get shambler chance for current position based on known regions
---@param region table Region data
---@return number chance 0-100 shambler percentage
function RegionManager.Shared.GetShamblerChance(region)
    -- Check if region has shambler configuration
    if region.properties.shamblerChance and type(region.properties.shamblerChance) == "number" then
        local chance = region.properties.shamblerChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end

    -- No region found or region has no shambler config
    return 0
end

-- Get hawk vision chance for current position based on known regions
---@param region table Region data
---@return number chance 0-100 hawk vision percentage
function RegionManager.Shared.GetHawkVisionChanceFromRegion(region)
    if region.properties.hawkVisionChance and type(region.properties.hawkVisionChance) == "number" then
        local chance = region.properties.hawkVisionChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end
    return 0
end

-- Get bad vision chance for current position based on known regions
---@param region table Region data
---@return number chance 0-100 bad vision percentage
function RegionManager.Shared.GetBadVisionChance(region)
    if region.properties.badVisionChance and type(region.properties.badVisionChance) == "number" then
        local chance = region.properties.badVisionChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end
    return 0
end

-- Get good hearing chance for current position based on known regions
---@param region table Region data
---@return number chance 0-100 good hearing percentage
function RegionManager.Shared.GetGoodHearingChance(region)
    if region.properties.goodHearingChance and type(region.properties.goodHearingChance) == "number" then
        local chance = region.properties.goodHearingChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end
    return 0
end

-- Get bad hearing chance for current position based on known regions
---@param region table Region data
---@return number chance 0-100 bad hearing percentage
function RegionManager.Shared.GetBadHearingChance(region)
    if region.properties.badHearingChance and type(region.properties.badHearingChance) == "number" then
        local chance = region.properties.badHearingChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end
    return 0
end

-- Get zombie armor factor for current position based on known regions
---@param region table Region data
---@return number factor 0-100 armor factor percentage
function RegionManager.Shared.GetZombieArmorFactor(region)
    if region.properties.zombieArmorFactor and type(region.properties.zombieArmorFactor) == "number" then
        local factor = region.properties.zombieArmorFactor
        if factor < 0 then
            factor = 0
        end
        if factor > 100 then
            factor = 100
        end
        return factor
    end
    return 0
end

-- Get resistant chance for current position based on known regions
---@param region table Region data
---@return number chance 0-100 resistant percentage
function RegionManager.Shared.GetResistantChance(region)
    if region.properties.resistantChance and type(region.properties.resistantChance) == "number" then
        local chance = region.properties.resistantChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end
    return 0
end

-- Get normal vision chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetNormalVisionChance(region)
    if region.properties.normalVisionChance and type(region.properties.normalVisionChance) == "number" then
        return math.max(0, math.min(100, region.properties.normalVisionChance))
    end
    return 0
end

-- Get poor vision chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetPoorVisionChance(region)
    if region.properties.poorVisionChance and type(region.properties.poorVisionChance) == "number" then
        return math.max(0, math.min(100, region.properties.poorVisionChance))
    end
    return 0
end

-- Get random vision chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetRandomVisionChance(region)
    if region.properties.randomVisionChance and type(region.properties.randomVisionChance) == "number" then
        return math.max(0, math.min(100, region.properties.randomVisionChance))
    end
    return 0
end

-- Get pinpoint hearing chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetPinpointHearingChance(region)
    if region.properties.pinpointHearingChance and type(region.properties.pinpointHearingChance) == "number" then
        return math.max(0, math.min(100, region.properties.pinpointHearingChance))
    end
    return 0
end

-- Get normal hearing chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetNormalHearingChance(region)
    if region.properties.normalHearingChance and type(region.properties.normalHearingChance) == "number" then
        return math.max(0, math.min(100, region.properties.normalHearingChance))
    end
    return 0
end

-- Get poor hearing chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetPoorHearingChance(region)
    if region.properties.poorHearingChance and type(region.properties.poorHearingChance) == "number" then
        return math.max(0, math.min(100, region.properties.poorHearingChance))
    end
    return 0
end

-- Get random hearing chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetRandomHearingChance(region)
    if region.properties.randomHearingChance and type(region.properties.randomHearingChance) == "number" then
        return math.max(0, math.min(100, region.properties.randomHearingChance))
    end
    return 0
end

-- Get toughness chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetToughnessChance(region)
    if region.properties.toughnessChance and type(region.properties.toughnessChance) == "number" then
        return math.max(0, math.min(100, region.properties.toughnessChance))
    end
    return 0
end

-- Get normal toughness chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetNormalToughnessChance(region)
    if region.properties.normalToughnessChance and type(region.properties.normalToughnessChance) == "number" then
        return math.max(0, math.min(100, region.properties.normalToughnessChance))
    end
    return 0
end

-- Get fragile chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetFragileChance(region)
    if region.properties.fragileChance and type(region.properties.fragileChance) == "number" then
        return math.max(0, math.min(100, region.properties.fragileChance))
    end
    return 0
end

-- Get random toughness chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetRandomToughnessChance(region)
    if region.properties.randomToughnessChance and type(region.properties.randomToughnessChance) == "number" then
        return math.max(0, math.min(100, region.properties.randomToughnessChance))
    end
    return 0
end

-- Get navigation chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetNavigationChance(region)
    if region.properties.navigationChance and type(region.properties.navigationChance) == "number" then
        return math.max(0, math.min(100, region.properties.navigationChance))
    end
    return 0
end

-- Get armor effectiveness multiplier
---@param region table Region data
---@return number multiplier
function RegionManager.Shared.GetArmorEffectivenessMultiplier(region)
    if region.properties.armorEffectivenessMultiplier and type(region.properties.armorEffectivenessMultiplier) ==
        "number" then
        return math.max(0, region.properties.armorEffectivenessMultiplier)
    end
    return 1.0
end

-- Get armor defense percentage
---@param region table Region data
---@return number percentage 0-100
function RegionManager.Shared.GetArmorDefensePercentage(region)
    if region.properties.armorDefensePercentage and type(region.properties.armorDefensePercentage) == "number" then
        return math.max(0, math.min(100, region.properties.armorDefensePercentage))
    end
    return 0
end

-- Get superhuman toughness chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetSuperhumanChance(region)
    if region.properties.superhumanChance and type(region.properties.superhumanChance) == "number" then
        return math.max(0, math.min(100, region.properties.superhumanChance))
    end
    return 0
end

-- Get normal toughness chance (alt naming)
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetNormalToughness(region)
    if region.properties.normalToughness and type(region.properties.normalToughness) == "number" then
        return math.max(0, math.min(100, region.properties.normalToughness))
    end
    return 0
end

-- Get weak toughness chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetWeakChance(region)
    if region.properties.weakChance and type(region.properties.weakChance) == "number" then
        return math.max(0, math.min(100, region.properties.weakChance))
    end
    return 0
end

-- Get random toughness chance (alt naming)
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetRandomToughness(region)
    if region.properties.randomToughness and type(region.properties.randomToughness) == "number" then
        return math.max(0, math.min(100, region.properties.randomToughness))
    end
    return 0
end

-- Get memory long chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetMemoryLongChance(region)
    if region.properties.memoryLongChance and type(region.properties.memoryLongChance) == "number" then
        return math.max(0, math.min(100, region.properties.memoryLongChance))
    end
    return 0
end

-- Get memory normal chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetMemoryNormalChance(region)
    if region.properties.memoryNormalChance and type(region.properties.memoryNormalChance) == "number" then
        return math.max(0, math.min(100, region.properties.memoryNormalChance))
    end
    return 0
end

-- Get memory short chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetMemoryShortChance(region)
    if region.properties.memoryShortChance and type(region.properties.memoryShortChance) == "number" then
        return math.max(0, math.min(100, region.properties.memoryShortChance))
    end
    return 0
end

-- Get memory none chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetMemoryNoneChance(region)
    if region.properties.memoryNoneChance and type(region.properties.memoryNoneChance) == "number" then
        return math.max(0, math.min(100, region.properties.memoryNoneChance))
    end
    return 0
end

-- Get memory random chance
---@param region table Region data
---@return number chance 0-100 percentage
function RegionManager.Shared.GetMemoryRandomChance(region)
    if region.properties.memoryRandomChance and type(region.properties.memoryRandomChance) == "number" then
        return math.max(0, math.min(100, region.properties.memoryRandomChance))
    end
    return 0
end

-- ============================================================================
-- Reflection helpers (like BLTRandomZombies)
-- ============================================================================

-- Cached field references
local cognitionField = nil
local speedField = nil
local sightField = nil
local hearingField = nil

-- Cached ConfigOption references (NOT just values)
local speedConfigOption = nil
local cognitionConfigOption = nil
local sightConfigOption = nil
local hearingConfigOption = nil
local toughnessConfigOption = nil
local strengthConfigOption = nil
local memoryConfigOption = nil

-- Find a field by name using reflection (BLTRandomZombies approach)
local function findField(o, fname)
    for i = 0, getNumClassFields(o) - 1 do
        local f = getClassField(o, i)
        if tostring(f) == fname then
            return f
        end
    end
    return nil
end

-- Initialize field and config option references (call once)
local function initializeReflectionCache()
    if not speedConfigOption then
        local dummyZombie = IsoZombie.new(nil)

        -- Find private fields using reflection
        cognitionField = findField(dummyZombie, "public int zombie.characters.IsoZombie.cognition")
        speedField = findField(dummyZombie, "public int zombie.characters.IsoZombie.speedType")
        sightField = findField(dummyZombie, "public int zombie.characters.IsoZombie.sight")
        hearingField = findField(dummyZombie, "public int zombie.characters.IsoZombie.hearing")

        -- Get ConfigOption references (NOT just sandbox options)
        local sandbox = getSandboxOptions()
        speedConfigOption = sandbox:getOptionByName("ZombieLore.Speed"):asConfigOption()
        cognitionConfigOption = sandbox:getOptionByName("ZombieLore.Cognition"):asConfigOption()
        sightConfigOption = sandbox:getOptionByName("ZombieLore.Sight"):asConfigOption()
        hearingConfigOption = sandbox:getOptionByName("ZombieLore.Hearing"):asConfigOption()
        toughnessConfigOption = sandbox:getOptionByName("ZombieLore.Toughness"):asConfigOption()
        strengthConfigOption = sandbox:getOptionByName("ZombieLore.Strength"):asConfigOption()
        memoryConfigOption = sandbox:getOptionByName("ZombieLore.Memory"):asConfigOption()

        print("SIMBA_TSY: Reflection cache initialized")
    end
end

-- Constants for zombie properties (matching BLTRandomZombies)
local SPEED_SPRINTER = 1
local SPEED_FAST_SHAMBLER = 2
local SPEED_SHAMBLER = 3

local COGNITION_NAVIGATE_DOORS = 1
local COGNITION_NAVIGATE = 2
local COGNITION_BASIC = 3
local COGNITION_RANDOM = 4

local SIGHT_EAGLE = 1
local SIGHT_NORMAL = 2
local SIGHT_POOR = 3

local HEARING_PINPOINT = 1
local HEARING_NORMAL = 2
local HEARING_POOR = 3

local TOUGHNESS_TOUGH = 1
local TOUGHNESS_NORMAL = 2
local TOUGHNESS_FRAGILE = 3

local STRENGTH_SUPERHUMAN = 1
local STRENGTH_NORMAL = 2
local STRENGTH_WEAK = 3

local MEMORY_LONG = 1
local MEMORY_NORMAL = 2
local MEMORY_SHORT = 3
local MEMORY_NONE = 4
local MEMORY_RANDOM = 5

-- Apply zombie properties based on server-determined data
-- This function is called CLIENT-SIDE after receiving decisions from the server
-- Uses BLTRandomZombies approach: reflection + ConfigOptions + incremental application
---@param zombie IsoZombie The zombie to modify
---@param data table Property decisions from server
---@param sandboxOptions table Sandbox options (unused, kept for compatibility)
function RegionManager.Shared.ServerSideProperties(zombie, data, sandboxOptions)
    if not zombie or not data then
        return
    end

    -- Initialize reflection cache if needed
    initializeReflectionCache()

    -- Store original config option values (BLTRandomZombies approach)
    local originalSpeed = speedConfigOption:getValue()
    local originalCognition = cognitionConfigOption:getValue()
    local originalSight = sightConfigOption:getValue()
    local originalHearing = hearingConfigOption:getValue()
    local originalToughness = toughnessConfigOption:getValue()
    local originalStrength = strengthConfigOption:getValue()
    local originalMemory = memoryConfigOption:getValue()

    -- ========================================================================
    -- 1. APPLY SPEED (Sprinter/Shambler) - BLTRandomZombies style
    -- Uses makeInactive() WITHOUT DoZombieStats()
    -- Store expected speed in modData for owner-change revalidation
    -- ========================================================================
    local modData = zombie:getModData()
    if data.isSprinter then
        speedConfigOption:setValue(SPEED_SPRINTER)
        zombie:makeInactive(true)
        zombie:makeInactive(false)
        modData.SIMBA_TSY_ExpectedSpeed = "sprinter"
    elseif data.isShambler then
        speedConfigOption:setValue(SPEED_SHAMBLER)
        zombie:makeInactive(true)
        zombie:makeInactive(false)
        modData.SIMBA_TSY_ExpectedSpeed = "shambler"
    end

    speedConfigOption:setValue(originalSpeed)

    -- ========================================================================
    -- 2. APPLY COGNITION - Requires DoZombieStats() call
    -- ========================================================================
    if data.hasNavigation then
        cognitionConfigOption:setValue(COGNITION_NAVIGATE_DOORS)
    end

    -- ========================================================================
    -- 3. APPLY SIGHT - Uses DoZombieStats()
    -- ========================================================================
    if data.hawkVision then
        sightConfigOption:setValue(SIGHT_EAGLE)
    elseif data.normalVision then
        sightConfigOption:setValue(SIGHT_NORMAL)
    elseif data.poorVision or data.badVision then
        sightConfigOption:setValue(SIGHT_POOR)
    end


    -- ========================================================================
    -- 4. APPLY HEARING - Uses DoZombieStats()
    -- ========================================================================
    if data.pinpointHearing or data.goodHearing then
        hearingConfigOption:setValue(HEARING_PINPOINT)
    elseif data.normalHearing then
        hearingConfigOption:setValue(HEARING_NORMAL)
    elseif data.poorHearing or data.badHearing then
        hearingConfigOption:setValue(HEARING_POOR)
    end


    -- ========================================================================
    -- 5. APPLY TOUGHNESS - Hybrid approach
    -- Store toughness in ModData for OnHit event handling
    -- Initial health set + dynamic damage mitigation
    -- ========================================================================
    -- Re-use modData from speed section above (already declared)
    if not zombie:getAttackedBy() and not zombie:isOnFire() then
        local health = 0.1 * ZombRand(4) -- Random 0.0 to 0.3 base
        if data.isTough then
            health = health + 3.5 -- Tough: 3.5 to 3.8 initial health
            modData.SIMBA_TSY_ToughnessType = "tough"
            modData.SIMBA_TSY_ToughnessHitCounter = 0 -- Track hits taken
            modData.SIMBA_TSY_ToughnessMaxHits = data.maxHits or RegionManager.Shared.DEFAULT_MAX_HITS -- Region-configured extra hits
            zombie:setHealth(health)
        elseif data.isFragile then
            health = health + 0.5 -- Fragile: 0.5 to 0.8
            modData.SIMBA_TSY_ToughnessType = "fragile"
            zombie:setHealth(health)
        elseif data.isNormalToughness then
            health = health + 1.5 -- Normal: 1.5 to 1.8
            modData.SIMBA_TSY_ToughnessType = "normal"
            zombie:setHealth(health)
        end
    end

    -- ========================================================================
    -- 6. APPLY STRENGTH - Uses DoZombieStats()
    -- ========================================================================
    if data.isSuperhuman then
        strengthConfigOption:setValue(STRENGTH_SUPERHUMAN)
    elseif data.isNormalToughness2 or data.isNormalToughness then
        strengthConfigOption:setValue(STRENGTH_NORMAL)
    elseif data.isWeak then
        strengthConfigOption:setValue(STRENGTH_WEAK)
    end


    -- ========================================================================
    -- 7. APPLY MEMORY - Uses DoZombieStats()
    -- ========================================================================
    if data.hasMemoryLong then
        memoryConfigOption:setValue(MEMORY_LONG)
    elseif data.hasMemoryNormal then
        memoryConfigOption:setValue(MEMORY_NORMAL)
    elseif data.hasMemoryShort then
        memoryConfigOption:setValue(MEMORY_SHORT)
    elseif data.hasMemoryNone then
        memoryConfigOption:setValue(MEMORY_NONE)
    elseif data.hasMemoryRandom then
        memoryConfigOption:setValue(MEMORY_RANDOM)
    end

    
    zombie:DoZombieStats()
    memoryConfigOption:setValue(originalMemory)
    strengthConfigOption:setValue(originalStrength)
    hearingConfigOption:setValue(originalHearing)
    sightConfigOption:setValue(originalSight)
    cognitionConfigOption:setValue(originalCognition)

    -- ========================================================================
    -- 8. COMPUTE KILL BONUS - Dynamic difficulty-based reward stored in modData
    -- Hard properties add points, weak properties deduct. Min extra = 0.
    -- ========================================================================
    local killBonus = 0
    -- Speed: sprinter = hard, shambler = weak
    if data.isSprinter then killBonus = killBonus + 5 end
    if data.isShambler then killBonus = killBonus - 5 end
    -- Vision: hawk = hard, poor/bad = weak
    if data.hawkVision then killBonus = killBonus + 1 end
    if data.poorVision or data.badVision then killBonus = killBonus - 1 end
    -- Hearing: pinpoint/good = hard, poor/bad = weak
    if data.pinpointHearing or data.goodHearing then killBonus = killBonus + 1 end
    if data.poorHearing or data.badHearing then killBonus = killBonus - 1 end
    -- Toughness: tough = hard, fragile = weak
    if data.isTough then killBonus = killBonus + 3 end
    if data.isFragile then killBonus = killBonus - 1 end
    -- Strength: superhuman = hard, weak = weak
    if data.isSuperhuman then killBonus = killBonus + 1 end
    if data.isWeak then killBonus = killBonus - 1 end
    -- Cognition: navigation = hard
    if data.hasNavigation then killBonus = killBonus + 2 end
    -- Memory: long = hard, short/none = weak
    if data.hasMemoryLong then killBonus = killBonus + 1 end
    if data.hasMemoryShort then killBonus = killBonus - 1 end
    if data.hasMemoryNone then killBonus = killBonus - 2 end
    -- Resistant = hard
    if data.isResistant then killBonus = killBonus + 1 end
    if data.maxHits then killBonus = killBonus + math.floor(data.maxHits * 0.5) end

    -- Clamp: extra never goes below 0
    modData.SIMBA_TSY_KillBonus = math.max(0, killBonus)
    
    -- Note: Armor settings are not applied here as BLTRandomZombies doesn't handle them
    -- and they may not be directly modifiable per-zombie
end

-- ============================================================================
-- Speed Revalidation
-- When a zombie changes authority owner in MP, the new owner may recalculate
-- its speed from sandbox defaults, losing the sprinter/shambler override.
-- This function checks a single zombie's current walkType against the expected
-- speed stored in modData and reapplies if mismatched.
-- Returns true if the speed was corrected.
-- ============================================================================
---@param zombie IsoZombie
---@param sandboxOptions table
---@return boolean corrected
function RegionManager.Shared.RevalidateZombieSpeed(zombie, sandboxOptions)
    if not zombie or zombie:isDead() then
        return false
    end

    -- Only fix zombies we are currently simulating (we are the auth owner)
    if zombie:isRemoteZombie() then
        return false
    end

    local modData = zombie:getModData()
    local expected = modData.SIMBA_TSY_ExpectedSpeed
    if not expected then
        return false -- not a zombie we modified, skip
    end

    -- Read the current walkType from the animation variable
    local walkType = zombie:getVariableString("zombiewalktype")
    if not walkType then
        walkType = ""
    end
    walkType = string.lower(tostring(walkType))

    if expected == "sprinter" then
        -- Sprinter walkType should contain "sprint"
        if string.find(walkType, "sprint") then
            return false -- already correct
        end
        -- Mismatch: zombie should be sprinting but isn't
        RegionManager.Shared.makeSprint(zombie, sandboxOptions)
        print("SIMBA_TSY: Revalidated sprinter zombie " .. tostring(zombie:getOnlineID())
              .. " (walkType was '" .. walkType .. "')")
        return true

    elseif expected == "shambler" then
        -- Shambler walkType should contain "slow" (slow1, slow2, slow3)
        if string.find(walkType, "slow") then
            return false -- already correct
        end
        -- Also accept empty/nil as possibly OK if the zombie is idle,
        -- but if it contains "sprint" that is definitely wrong
        if not string.find(walkType, "sprint") then
            return false -- not clearly wrong, leave it
        end
        -- Mismatch: zombie is sprinting but should be shambling
        RegionManager.Shared.makeShamble(zombie, sandboxOptions)
        print("SIMBA_TSY: Revalidated shambler zombie " .. tostring(zombie:getOnlineID())
              .. " (walkType was '" .. walkType .. "')")
        return true
    end

    return false
end

-- ============================================================================
-- Dynamic Toughness System - Networked OnHit Handler
-- Tough zombies get extra resilience through server-authoritative hit tracking.
-- Flow: Client detects hit -> sends to server -> server validates & broadcasts
--       -> all nearby clients apply avoidDamage + stagger
-- ============================================================================

-- CLIENT-SIDE: Apply the toughness effect received from server broadcast
-- Called by the client command handler in RegionManager_ZombieClient.lua
---@param zombieID number The online ID of the zombie
---@param hitCounter number The authoritative hit counter from server
---@param maxHits number The maximum hits before zombie can die
---@param isExhausted boolean True if zombie has used all its extra lives
function RegionManager.Shared.ApplyToughZombieHit(zombieID, hitCounter, maxHits, isExhausted)
    local player = getPlayer()
    if not player then
        return
    end

    local cell = player:getCell()
    if not cell then
        return
    end

    local zombieList = cell:getZombieList()
    if not zombieList then
        return
    end

    for i = 0, zombieList:size() - 1 do
        local zombie = zombieList:get(i)
        if zombie and not zombie:isDead() and zombie:getOnlineID() == zombieID then
            local modData = zombie:getModData()

            -- Sync authoritative counter from server
            modData.SIMBA_TSY_ToughnessHitCounter = hitCounter
            modData.SIMBA_TSY_ToughnessMaxHits = maxHits

            if not isExhausted then
                -- Still has lives: make immune to this hit + stagger
                zombie:setAvoidDamage(true)
                zombie:setKnockedDown(false)
                zombie:setStaggerBack(true)
                print("SIMBA_TSY: Tough zombie " .. zombieID .. " resisted hit (" .. hitCounter .. "/" .. maxHits .. ")")
            else
                -- All lives used up: zombie can now be killed normally
                zombie:setAvoidDamage(false)
                zombie:setStaggerBack(true)
                print("SIMBA_TSY: Tough zombie " .. zombieID .. " exhausted all lives, now vulnerable")
            end
            break
        end
    end
end

-- CLIENT-SIDE: Detect weapon hit on tough zombie then notify server
local function OnWeaponHitCharacter(attacker, target, weapon, damage)
    -- Only the attacker's client sends the command to avoid duplicates
    local player = getPlayer()
    if not player or attacker ~= player then
        return
    end

    -- Verify target is a living zombie
    if not instanceof(target, "IsoZombie") or not target:isAlive() then
        return
    end

    local modData = target:getModData()
    local toughnessType = modData.SIMBA_TSY_ToughnessType
    if toughnessType == "tough" then
        local zombieID = target:getOnlineID()
        local hitCounter = modData.SIMBA_TSY_ToughnessHitCounter or 0
        local maxHits = modData.SIMBA_TSY_ToughnessMaxHits or RegionManager.Shared.DEFAULT_MAX_HITS

        -- Optimistic local application: immediately protect the zombie on this client
        -- The server will send the authoritative state back shortly
        if hitCounter < maxHits then
            target:setAvoidDamage(true)
            target:setKnockedDown(false)
            target:setStaggerBack(true)
        end

        -- Send to server for authoritative processing
        sendClientCommand(player, "SIMBA_TSY", "ZombieHitTough", {
            zombieID = zombieID,
            x = target:getX(),
            y = target:getY(),
            persistentID = RegionManager.Shared.GetZombiePersistentID(target)
        })
    end
end

-- Register the event handler (client-side only)
if not isServer() then
    Events.OnWeaponHitCharacter.Add(OnWeaponHitCharacter)
    print("SIMBA_TSY: Networked toughness system initialized (OnWeaponHitCharacter)")
end


