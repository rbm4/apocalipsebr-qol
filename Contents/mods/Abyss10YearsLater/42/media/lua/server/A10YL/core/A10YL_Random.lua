-- Deterministic save-seeded coordinate random helpers.
-- Generation code must not expose/order-depend on mutable RNG state.
local Random = {}

local worldSeed = 0
local HASH_MOD = 2147483647
local SALT_MOD = 1000003
local MAX_SALT_CACHE = 256
local saltCache = {}
local saltCacheEntries = 0

local function normalizeInteger(value)
    value = tonumber(value) or 0
    if value >= 0 then
        return math.floor(value)
    end
    return math.ceil(value)
end

local function saltHash(salt)
    if type(salt) == "number" then
        local value = normalizeInteger(salt) % SALT_MOD
        if value < 0 then
            value = value + SALT_MOD
        end
        return value
    end

    local text = tostring(salt or "")
    local cached = saltCache[text]
    if cached ~= nil then return cached end

    local value = 0
    for i = 1, #text do
        value = (value * 131 + string.byte(text, i)) % SALT_MOD
    end

    if saltCacheEntries >= MAX_SALT_CACHE then
        saltCache = {}
        saltCacheEntries = 0
    end
    if saltCache[text] == nil then saltCacheEntries = saltCacheEntries + 1 end
    saltCache[text] = value
    return value
end

function Random.setWorldSeed(seed)
    worldSeed = normalizeInteger(seed)
end

function Random.getWorldSeed()
    return worldSeed
end

local MIX_MOD = 1000003

local function positiveMod(value, modulus)
    value = normalizeInteger(value) % modulus
    if value < 0 then value = value + modulus end
    return value
end

local function avalanche(value)
    -- Keep every intermediate below 2^53 so Lua-number arithmetic remains exact.
    -- The quadratic rounds deliberately break the linear x/y bands produced by
    -- the old affine hash while remaining deterministic and bit-library free.
    value = (value * value + value * 7919 + 104729) % MIX_MOD
    value = (value * value + value * 1543 + 32452843) % MIX_MOD
    return value
end

function Random.coordinateHash(x, y, z, salt)
    local sx = positiveMod(x, MIX_MOD)
    local sy = positiveMod(y, MIX_MOD)
    local sz = positiveMod(z, MIX_MOD)
    local seedPart = positiveMod(worldSeed, MIX_MOD)

    local value = (saltHash(salt) + seedPart * 97 + 17) % MIX_MOD
    value = avalanche((value * 1009 + sx * 313) % MIX_MOD)
    value = avalanche((value * 9176 + sy * 911) % MIX_MOD)
    value = avalanche((value * 6113 + sz * 353) % MIX_MOD)

    -- Return the same broad positive integer contract as before.
    return (value * 2141 + 12820163) % HASH_MOD
end

function Random.coordinatePercent(x, y, z, salt)
    return (Random.coordinateHash(x, y, z, salt) % 100) + 1
end

function Random.coordinateIndex(x, y, z, salt, count)
    count = normalizeInteger(count)
    if count < 1 then
        return nil
    end

    return (Random.coordinateHash(x, y, z, salt) % count) + 1
end

function Random.coordinateElement(list, x, y, z, salt)
    if type(list) ~= "table" or #list < 1 then
        return nil
    end

    local index = Random.coordinateIndex(x, y, z, salt, #list)
    return index and list[index] or nil
end

function Random.patchPercent(x, y, z, salt, scale)
    scale = normalizeInteger(scale)
    if scale < 1 then
        scale = 1
    end

    return Random.coordinatePercent(
        math.floor((tonumber(x) or 0) / scale),
        math.floor((tonumber(y) or 0) / scale),
        z,
        tostring(salt or "") .. ":patch"
    )
end

return Random
