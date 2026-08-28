require("Items/SuburbsDistributions")
require("Items/SidecarRoomDefs")

local SpawnEngine = require("Bicycle/SpawnEngine")

-- Server-authoritative (see SpawnBicycle.lua): PZ loads media/lua/server on MP clients too, so guard
-- the sidecar spawn pass to the server + SP. Never use `not isServer()` (true in SP too).
if isClient() then return end

SidecarSpawner = SidecarSpawner or {}

local SIDECAR_ITEM_TYPES = {
    Bicycle_SidecarRed = true,
    Bicycle_SidecarWhite = true,
    Bicycle_SidecarPink = true,
    Bicycle_SidecarBlack = true,
    Bicycle_SidecarBlue = true,
    Bicycle_SidecarSpiffo = true,
}

---@return number
---@nodiscard
local function getSpawnRateMultiplier()
    local rate = 100
    if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.SidecarSpawnRate then
        rate = SandboxVars.Bicycle.SidecarSpawnRate
    end

    if rate >= 100 then
        return 100
    end
    return math.max(0, rate / 100)
end

---@return table<string, number>
---@nodiscard
local function buildRoomChances()
    local multiplier = getSpawnRateMultiplier()
    local chances = {}

    for roomName, baseChance in pairs(Bicycle.SidecarRoomDefs) do
        chances[roomName] = math.max(0, math.min(100, baseChance * multiplier))
    end

    -- Spiffo is a fixed-rate rare find: it ignores the SidecarSpawnRate slider so it stays a 10%
    -- storeroom drop no matter how the common coloured sidecars are tuned.
    for roomName, baseChance in pairs(Bicycle.SidecarSpiffoRoomDefs) do
        chances[roomName] = math.max(0, math.min(100, baseChance))
    end

    return chances
end

---@param roomName string
---@param unitRandom number
---@return string
---@nodiscard
local function pickFullType(roomName, unitRandom)
    if Bicycle.SidecarSpiffoRoomDefs[roomName] then
        return Bicycle.SidecarSpiffoFullType
    end

    local variants = Bicycle.SidecarVariants
    local index = math.floor(unitRandom * #variants) + 1
    if index > #variants then
        index = #variants
    end
    return variants[index]
end

SidecarSpawner.spec = {
    id = "sidecar",
    salt = 20393,
    itemTypes = SIDECAR_ITEM_TYPES,
    buildRoomChances = buildRoomChances,
    pickFullType = pickFullType,
}

SpawnEngine.register(SidecarSpawner.spec)
