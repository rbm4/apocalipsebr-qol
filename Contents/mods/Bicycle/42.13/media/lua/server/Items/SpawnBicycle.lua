-- Original by Viruana for Zupercarts, modified by RedChili for Bicycle

require("Items/SuburbsDistributions")
require("Items/BicycleRoomDefs")

local SpawnEngine = require("Bicycle/SpawnEngine")

-- World spawning is SERVER-AUTHORITATIVE. PZ loads media/lua/server on MP CLIENTS too, so without this
-- guard every connected client would run its own spawn pass. isClient() is false on the dedicated
-- server AND in singleplayer, so both still spawn; only a connected client bails. (A B42 "host" is
-- itself a client connected to a co-located dedicated server, so the server still spawns.) Do NOT use
-- `not isServer()` -- that is also true in SP and would silently disable spawning there.
if isClient() then return end

BikeSpawner = BikeSpawner or {}

local BICYCLE_ITEM_TYPES = {
    Bicycle = true,
    Bicycle_RedStreet = true,
}

---@return number
---@nodiscard
local function getSpawnRateMultiplier()
    local rate = 100
    if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.SpawnRate then
        rate = SandboxVars.Bicycle.SpawnRate
    end

    -- Slider at max means "always", matching the shipped behaviour of the previous spawner.
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
    for roomName, baseChance in pairs(Bicycle.RoomDefs) do
        chances[roomName] = math.max(0, math.min(100, baseChance * multiplier))
    end
    return chances
end

---@param roomName string
---@param unitRandom number
---@return string
---@nodiscard
local function pickFullType(roomName, unitRandom)
    if unitRandom < 0.5 then
        return "Bicycle.Bicycle"
    end
    return "Bicycle.Bicycle_RedStreet"
end

BikeSpawner.spec = {
    id = "bicycle",
    salt = 7411,
    itemTypes = BICYCLE_ITEM_TYPES,
    buildRoomChances = buildRoomChances,
    pickFullType = pickFullType,
}

SpawnEngine.register(BikeSpawner.spec)
