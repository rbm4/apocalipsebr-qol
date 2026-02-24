-- ============================================================================
-- File: media/lua/server/RegionManager_ZombieServerHelper.lua
-- Server-side helper utilities for zombie property resolution.
-- Aggregates region chances, rolls decisions, builds response payloads, etc.
-- Keeps RegionManager_ZombieServer.lua focused on command flow.
--
-- This module is self-contained: it does NOT depend on RegionManager.Shared.
-- All chance-reading, RNG and ID logic that the server needs is inlined here.
-- ============================================================================
if not isServer() then
    return
end

-- Ensure parent table exists so RegionManager_Config can attach to it
RegionManager = RegionManager or {}
require "RegionManager_Config"

local ZombieHelper = {}

-- ============================================================================
-- Low-level utilities (declared first so everything below can use them)
-- ============================================================================

--- Read a numeric property from a region, clamp to [0, 100], default 0.
---@param region table
---@param propName string  Key inside region.properties
---@return number 0-100
local function getChance(region, propName)
    local v = region.properties[propName]
    if v and type(v) == "number" then
        return math.max(0, math.min(100, v))
    end
    return 0
end

--- Read armor effectiveness multiplier (no upper clamp, default 1.0).
---@param region table
---@return number
local function getArmorEffectiveness(region)
    local v = region.properties.armorEffectivenessMultiplier
    if v and type(v) == "number" then
        return math.max(0, v)
    end
    return 1.0
end

-- ============================================================================
-- Deterministic pseudo-random number generator (LCG)
-- Self-contained: no dependency on RegionManager.Shared._rngSeed
-- ============================================================================

local _rngSeed = nil

--- Advance the LCG and return a value in [0, max-1].
---@param max number
---@return number
local function getDeterministicRandom(max)
    if not _rngSeed then
        _rngSeed = os.time()
    end
    _rngSeed = ((_rngSeed * 1103515245) + 12345) % 2147483648
    return _rngSeed % max
end

--- Set the LCG seed (call with a zombie-specific value before rolling).
---@param seed number
local function setDeterministicSeed(seed)
    if seed < 0 then seed = seed * -1 end
    _rngSeed = seed
end

-- Expose seed helpers so the server file can use them if needed
ZombieHelper.GetDeterministicRandom = getDeterministicRandom
ZombieHelper.SetDeterministicSeed   = setDeterministicSeed

-- ============================================================================
-- Persistent ID
-- ============================================================================

--- Build a stable string identifier for a zombie.
---@param zombie IsoZombie
---@return string|nil
function ZombieHelper.GetPersistentID(zombie)
    if not zombie then return nil end
    local ok, outfit = pcall(zombie.getPersistentOutfitID, zombie)
    if not ok then
        print("SIMBA_TSY ServerHelper: Failed to get PersistentOutfitID")
        return nil
    end
    local female = zombie:isFemale() and 1 or 0
    return string.format("%d_%d", outfit, female)
end

-- ============================================================================
-- Region lookup
-- ============================================================================

--- Find all registered zones that contain the given world position.
---@param x number World X coordinate
---@param y number World Y coordinate
---@return table<string, table> regions  Map of zoneId -> region (empty if none)
function ZombieHelper.FindRegionsAt(x, y)
    local result = {}
    if not RegionManager or not RegionManager.Server or not RegionManager.Server.registeredZones then
        return result
    end
    for zoneId, region in pairs(RegionManager.Server.registeredZones) do
        local bounds = region.bounds
        if x >= bounds.minX and x <= bounds.maxX and y >= bounds.minY and y <= bounds.maxY then
            result[zoneId] = region
        end
    end
    return result
end

-- ============================================================================
-- Aggregate chances across overlapping regions (max of each property)
-- ============================================================================

--- Given a set of regions, compute the maximum chance value for every zombie
--- property across all of them.
---@param regions table<string, table>
---@return table chances  Flat table with a key per property chance
function ZombieHelper.AggregateChances(regions)
    local c = {
        sprinter              = 0,
        shambler              = 0,
        hawkVision            = 0,
        badVision             = 0,
        normalVision          = 0,
        poorVision            = 0,
        randomVision          = 0,
        goodHearing           = 0,
        badHearing            = 0,
        pinpointHearing       = 0,
        normalHearing         = 0,
        poorHearing           = 0,
        randomHearing         = 0,
        zombieArmor           = 0,
        resistant             = 0,
        toughness             = 0,
        normalToughness       = 0,
        fragile               = 0,
        randomToughness       = 0,
        superhuman            = 0,
        normalToughness2      = 0,
        weak                  = 0,
        randomToughness2      = 0,
        navigation            = 0,
        memoryLong            = 0,
        memoryNormal          = 0,
        memoryShort           = 0,
        memoryNone            = 0,
        memoryRandom          = 0,
        armorEffectiveness    = 0,
        armorDefense          = 0,
        maxHits               = RegionManager.Shared.DEFAULT_MAX_HITS,  -- default tough zombie extra hits
    }

    for _, region in pairs(regions) do
        c.sprinter           = math.max(c.sprinter,           getChance(region, "sprinterChance"))
        c.shambler           = math.max(c.shambler,           getChance(region, "shamblerChance"))
        c.hawkVision         = math.max(c.hawkVision,         getChance(region, "hawkVisionChance"))
        c.badVision          = math.max(c.badVision,          getChance(region, "badVisionChance"))
        c.normalVision       = math.max(c.normalVision,       getChance(region, "normalVisionChance"))
        c.poorVision         = math.max(c.poorVision,         getChance(region, "poorVisionChance"))
        c.randomVision       = math.max(c.randomVision,       getChance(region, "randomVisionChance"))
        c.goodHearing        = math.max(c.goodHearing,        getChance(region, "goodHearingChance"))
        c.badHearing         = math.max(c.badHearing,         getChance(region, "badHearingChance"))
        c.pinpointHearing    = math.max(c.pinpointHearing,    getChance(region, "pinpointHearingChance"))
        c.normalHearing      = math.max(c.normalHearing,      getChance(region, "normalHearingChance"))
        c.poorHearing        = math.max(c.poorHearing,        getChance(region, "poorHearingChance"))
        c.randomHearing      = math.max(c.randomHearing,      getChance(region, "randomHearingChance"))
        c.zombieArmor        = math.max(c.zombieArmor,        getChance(region, "zombieArmorFactor"))
        c.resistant          = math.max(c.resistant,           getChance(region, "resistantChance"))
        c.toughness          = math.max(c.toughness,           getChance(region, "toughnessChance"))
        c.normalToughness    = math.max(c.normalToughness,     getChance(region, "normalToughnessChance"))
        c.fragile            = math.max(c.fragile,             getChance(region, "fragileChance"))
        c.randomToughness    = math.max(c.randomToughness,     getChance(region, "randomToughnessChance"))
        c.superhuman         = math.max(c.superhuman,          getChance(region, "superhumanChance"))
        c.normalToughness2   = math.max(c.normalToughness2,    getChance(region, "normalToughness"))
        c.weak               = math.max(c.weak,                getChance(region, "weakChance"))
        c.randomToughness2   = math.max(c.randomToughness2,    getChance(region, "randomToughness"))
        c.navigation         = math.max(c.navigation,          getChance(region, "navigationChance"))
        c.memoryLong         = math.max(c.memoryLong,          getChance(region, "memoryLongChance"))
        c.memoryNormal       = math.max(c.memoryNormal,        getChance(region, "memoryNormalChance"))
        c.memoryShort        = math.max(c.memoryShort,         getChance(region, "memoryShortChance"))
        c.memoryNone         = math.max(c.memoryNone,          getChance(region, "memoryNoneChance"))
        c.memoryRandom       = math.max(c.memoryRandom,        getChance(region, "memoryRandomChance"))
        c.armorEffectiveness = math.max(c.armorEffectiveness,   getArmorEffectiveness(region))
        c.armorDefense       = math.max(c.armorDefense,         getChance(region, "armorDefensePercentage"))

        -- maxHits: number of extra hits tough zombies resist (not a chance, direct value)
        local regionMaxHits = region.properties.maxHits
        if regionMaxHits and type(regionMaxHits) == "number" then
            c.maxHits = math.max(c.maxHits, math.floor(math.max(1, math.min(99, regionMaxHits))))
        end
    end

    return c
end

-- ============================================================================
-- Roll decisions from aggregated chances
-- ============================================================================

--- Roll a single deterministic random value and compare against every chance
--- to produce boolean decisions for all zombie properties.
---@param chances table  Output of AggregateChances
---@param x number       World X (stored in result)
---@param y number       World Y (stored in result)
---@return table decisions  Flat table with boolean keys + position + armor values
function ZombieHelper.RollDecisions(chances, x, y)
    local roll = getDeterministicRandom(100)

    return {
        isSprinter              = roll < chances.sprinter,
        isShambler              = roll < chances.shambler,
        hawkVision              = roll < chances.hawkVision,
        badVision               = roll < chances.badVision,
        normalVision            = roll < chances.normalVision,
        poorVision              = roll < chances.poorVision,
        randomVision            = roll < chances.randomVision,
        goodHearing             = roll < chances.goodHearing,
        badHearing              = roll < chances.badHearing,
        pinpointHearing         = roll < chances.pinpointHearing,
        normalHearing           = roll < chances.normalHearing,
        poorHearing             = roll < chances.poorHearing,
        randomHearing           = roll < chances.randomHearing,
        hasArmor                = roll < chances.zombieArmor,
        isResistant             = roll < chances.resistant,
        isTough                 = roll < chances.toughness,
        isNormalToughness       = roll < chances.normalToughness,
        isFragile               = roll < chances.fragile,
        isRandomToughness       = roll < chances.randomToughness,
        isSuperhuman            = roll < chances.superhuman,
        isNormalToughness2      = roll < chances.normalToughness2,
        isWeak                  = roll < chances.weak,
        isRandomToughness2      = roll < chances.randomToughness2,
        hasNavigation           = roll < chances.navigation,
        hasMemoryLong           = roll < chances.memoryLong,
        hasMemoryNormal         = roll < chances.memoryNormal,
        hasMemoryShort          = roll < chances.memoryShort,
        hasMemoryNone           = roll < chances.memoryNone,
        hasMemoryRandom         = roll < chances.memoryRandom,
        armorEffectivenessMultiplier = chances.armorEffectiveness,
        armorDefensePercentage       = chances.armorDefense,
        maxHits = chances.maxHits,
        x = math.floor(x),
        y = math.floor(y),
    }
end

-- ============================================================================
-- Build the network payload sent to clients via ConfirmZombie
-- ============================================================================

--- Build the compact payload sent to clients via ConfirmZombie.
--- Protocol v2: Bit-encoded communication for minimal network overhead.
--- Payload:  { z = zombieID, r = "BBBBBBBBBSXXXXXSYYYYYMM" }
---   B(9):  28 boolean flags packed as a zero-padded decimal integer
---   S(1):  coordinate sign digit (0 = negative, 1 = positive)
---   X(5):  absolute X coordinate, zero-padded
---   Y(5):  absolute Y coordinate, zero-padded
---   M(2):  maxHits for tough zombies, zero-padded
--- Bit layout (LSB first):
---   0:isSprinter  1:isShambler      2:hawkVision      3:badVision
---   4:normalVision 5:poorVision     6:randomVision    7:goodHearing
---   8:badHearing   9:pinpointHearing 10:normalHearing 11:poorHearing
---  12:randomHearing 13:isResistant  14:isTough        15:isNormalToughness
---  16:isFragile    17:isRandomToughness 18:isSuperhuman 19:isNormalToughness2
---  20:isWeak       21:isRandomToughness2 22:hasNavigation 23:hasMemoryLong
---  24:hasMemoryNormal 25:hasMemoryShort 26:hasMemoryNone 27:hasMemoryRandom
---@param zombieID number   Online ID of the zombie
---@param stored table      Decision data from ModData
---@return table payload
function ZombieHelper.BuildConfirmPayload(zombieID, stored)
    -- Pack 28 booleans into a single integer
    local bits = 0
    local function setBit(pos, value)
        if value then bits = bits + (2 ^ pos) end
    end

    setBit(0,  stored.isSprinter)
    setBit(1,  stored.isShambler)
    setBit(2,  stored.hawkVision)
    setBit(3,  stored.badVision)
    setBit(4,  stored.normalVision)
    setBit(5,  stored.poorVision)
    setBit(6,  stored.randomVision)
    setBit(7,  stored.goodHearing)
    setBit(8,  stored.badHearing)
    setBit(9,  stored.pinpointHearing)
    setBit(10, stored.normalHearing)
    setBit(11, stored.poorHearing)
    setBit(12, stored.randomHearing)
    setBit(13, stored.isResistant)
    setBit(14, stored.isTough)
    setBit(15, stored.isNormalToughness)
    setBit(16, stored.isFragile)
    setBit(17, stored.isRandomToughness)
    setBit(18, stored.isSuperhuman)
    setBit(19, stored.isNormalToughness2)
    setBit(20, stored.isWeak)
    setBit(21, stored.isRandomToughness2)
    setBit(22, stored.hasNavigation)
    setBit(23, stored.hasMemoryLong)
    setBit(24, stored.hasMemoryNormal)
    setBit(25, stored.hasMemoryShort)
    setBit(26, stored.hasMemoryNone)
    setBit(27, stored.hasMemoryRandom)

    -- Encode coordinates: sign digit (0=neg, 1=pos) + 5-digit zero-padded absolute
    local x = math.floor(stored.x or 0)
    local y = math.floor(stored.y or 0)
    local xSign = x >= 0 and 1 or 0
    local ySign = y >= 0 and 1 or 0
    local xAbs = math.abs(x)
    local yAbs = math.abs(y)

    -- maxHits: 2-digit zero-padded (1-99)
    local maxHits = math.min(99, math.max(1, stored.maxHits or RegionManager.Shared.DEFAULT_MAX_HITS))

    -- Format: BBBBBBBBB SXXXXX SYYYYY MM  (23 chars, no separators)
    local r = string.format("%09d%d%05d%d%05d%02d", bits, xSign, xAbs, ySign, yAbs, maxHits)

    return {
        z = zombieID,
        r = r,
    }
end

-- ============================================================================
-- Broadcast helper
-- ============================================================================

--- Send a server command to every connected player.
---@param module string   Module name (e.g. "SIMBA_TSY")
---@param command string  Command name
---@param payload table   Data table
function ZombieHelper.BroadcastToAll(module, command, payload)
    local players = getOnlinePlayers()
    if not players then return end
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then
            sendServerCommand(p, module, command, payload)
        end
    end
end

-- ============================================================================
-- Find zombie in the current cell by online ID
-- ============================================================================

---@param zombieID number
---@return IsoZombie|nil
function ZombieHelper.FindZombieByOnlineID(zombieID)
    local cell = getCell()
    if not cell then return nil end
    local zombies = cell:getZombieList()
    if not zombies then return nil end
    for j = 0, zombies:size() - 1 do
        local zombie = zombies:get(j)
        if zombie and not zombie:isDead() and zombie:getOnlineID() == zombieID then
            return zombie
        end
    end
    return nil
end

return ZombieHelper
