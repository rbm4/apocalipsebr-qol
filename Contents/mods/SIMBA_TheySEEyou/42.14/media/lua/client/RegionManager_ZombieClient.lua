if isServer() then
    return
end

require "RegionManager_Config"
require "RegionManager_ClientTick"
require "RegionManager_ZombieShared"

local sandboxOptions = getSandboxOptions()

-- ============================================================================
-- Decode compact bit-encoded payload from server (Protocol v2)
-- Format: "BBBBBBBBBSXXXXXSYYYYYMM" (23 chars, fixed length)
--   B(9):  28 boolean flags packed as a zero-padded decimal integer
--   S(1):  coordinate sign digit (0 = negative, 1 = positive)
--   X(5):  absolute X coordinate, zero-padded
--   Y(5):  absolute Y coordinate, zero-padded
--   M(2):  maxHits for tough zombies, zero-padded
-- Bit layout (LSB first):
--   0:isSprinter  1:isShambler      2:hawkVision      3:badVision
--   4:normalVision 5:poorVision     6:randomVision    7:goodHearing
--   8:badHearing   9:pinpointHearing 10:normalHearing 11:poorHearing
--  12:randomHearing 13:isResistant  14:isTough        15:isNormalToughness
--  16:isFragile    17:isRandomToughness 18:isSuperhuman 19:isNormalToughness2
--  20:isWeak       21:isRandomToughness2 22:hasNavigation 23:hasMemoryLong
--  24:hasMemoryNormal 25:hasMemoryShort 26:hasMemoryNone 27:hasMemoryRandom
-- ============================================================================
local function decodeConfirmPayload(args)
    local r = args.r
    local bits    = tonumber(string.sub(r, 1, 9))   or 0
    local xSign   = tonumber(string.sub(r, 10, 10)) or 1
    local xAbs    = tonumber(string.sub(r, 11, 15)) or 0
    local ySign   = tonumber(string.sub(r, 16, 16)) or 1
    local yAbs    = tonumber(string.sub(r, 17, 21)) or 0
    local maxHits = tonumber(string.sub(r, 22, 23)) or RegionManager.Shared.DEFAULT_MAX_HITS

    local x = xSign == 1 and xAbs or -xAbs
    local y = ySign == 1 and yAbs or -yAbs

    local function hasBit(pos)
        return math.floor(bits / (2 ^ pos)) % 2 == 1
    end

    return {
        zombieID           = args.z,
        isSprinter         = hasBit(0),
        isShambler         = hasBit(1),
        hawkVision         = hasBit(2),
        badVision          = hasBit(3),
        normalVision       = hasBit(4),
        poorVision         = hasBit(5),
        randomVision       = hasBit(6),
        goodHearing        = hasBit(7),
        badHearing         = hasBit(8),
        pinpointHearing    = hasBit(9),
        normalHearing      = hasBit(10),
        poorHearing        = hasBit(11),
        randomHearing      = hasBit(12),
        isResistant        = hasBit(13),
        isTough            = hasBit(14),
        isNormalToughness  = hasBit(15),
        isFragile          = hasBit(16),
        isRandomToughness  = hasBit(17),
        isSuperhuman       = hasBit(18),
        isNormalToughness2 = hasBit(19),
        isWeak             = hasBit(20),
        isRandomToughness2 = hasBit(21),
        hasNavigation      = hasBit(22),
        hasMemoryLong      = hasBit(23),
        hasMemoryNormal    = hasBit(24),
        hasMemoryShort     = hasBit(25),
        hasMemoryNone      = hasBit(26),
        hasMemoryRandom    = hasBit(27),
        x       = x,
        y       = y,
        maxHits = maxHits,
    }
end

-- Handle server commands
---@param module string
---@param command string
---@param args table
local function SIMBA_TSY_OnServerCommand(module, command, args)
    if module ~= "SIMBA_TSY" then
        return
    end

    -- ========================================================================
    -- Handle tough zombie hit broadcast from server
    -- ========================================================================
    if command == "ToughZombieHit" then
        local zombieID = args.zombieID
        local hitCounter = args.hitCounter
        local maxHits = args.maxHits
        local isExhausted = args.isExhausted
        local zombieX = args.x
        local zombieY = args.y

        local player = getPlayer()
        if not player then
            return
        end
        local playerX = player:getX()
        local playerY = player:getY()

        -- Check distance between player and zombie
        local distance = math.sqrt((playerX - zombieX) ^ 2 + (playerY - zombieY) ^ 2)
        if distance > 200 then
            return
        end
        RegionManager.Shared.ApplyToughZombieHit(zombieID, hitCounter, maxHits, isExhausted)
        return
    end

    if command == "ConfirmZombie" then
        local player = getPlayer()
        if not player then
            return
        end

        -- Decode compact bit-encoded payload (Protocol v2)
        local data = decodeConfirmPayload(args)
        local zombieID = data.zombieID

        local cell = player:getCell()
        if not cell then
            return
        end

        local zombieList = cell:getZombieList()
        if not zombieList then
            return
        end
        -- Find zombie and apply all properties using shared function
        for i = 0, zombieList:size() - 1 do
            local zombie = zombieList:get(i)
            if zombie and not zombie:isDead() and zombie:getOnlineID() == zombieID then
                -- Apply all server-determined properties using the shared function
                RegionManager.Shared.ServerSideProperties(zombie, data, sandboxOptions)

                -- print("SIMBA_TSY Client: Applied properties to zombie " .. zombieID)
                if data.isSprinter then
                    print("  -> Converted to Sprinter")
                end
                if data.isShambler then
                    print("  -> Converted to Shambler")
                end
                if data.hawkVision then
                    print("  -> Hawk Vision applied")
                end
                if data.goodHearing or data.pinpointHearing then
                    print("  -> Enhanced Hearing applied")
                end
                if data.isTough then
                    print("  -> Tough applied (maxHits=" .. tostring(data.maxHits) .. ")")
                end
                if data.hasNavigation then
                    print("  -> Navigation enabled")
                end

                break
            end
        end
    end
end

Events.OnServerCommand.Add(SIMBA_TSY_OnServerCommand)

-------------------------- ZOMBIE SCANNING -------------------

-- Scan zombies and request their pre-determined properties from server
local function SIMBA_TSY_ProcessZombies(currentZones)
    local player = getPlayer()
    if not player then
        return
    end

    local cell = player:getCell()
    if not cell then
        return
    end

    local zombies = cell:getZombieList()
    if not zombies then
        return
    end

    if RegionManager and RegionManager.Client and RegionManager.Client.zoneData then
        local proposals = {}

        -- Client no longer calculates chances or rolls
        -- Server makes all decisions in OnZombieCreate
        -- Client just scans and requests information

        for i = 0, zombies:size() - 1 do
            local zombie = zombies:get(i)

            if zombie and not zombie:isDead() then
                local zombieID = zombie:getOnlineID()
                local data = zombie:getModData()

                -- Only process if not already processed
                if not data.SIMBA_TSY_Processed then
                    data.SIMBA_TSY_Processed = true

                    -- Generate persistent ID for server lookup
                    local persistentID = RegionManager.Shared.GetZombiePersistentID(zombie)

                    -- Request pre-determined properties from server
                    -- No rolling on client side - server decides everything in OnZombieCreate
                    table.insert(proposals, {
                        zombieID = zombieID,
                        persistentID = persistentID,
                        x = zombie:getX(),
                        y = zombie:getY()
                    })
                elseif data.SIMBA_TSY_Processed then
                    -- =================================================================
                    -- SPEED REVALIDATION PASS
                    -- Check already-processed zombies whose walkType no longer matches
                    -- the expected speed (owner change reset). Reapply if needed.
                    -- =================================================================
                    local zombie = zombies:get(i)
                    if zombie and not zombie:isDead() then
                        RegionManager.Shared.RevalidateZombieSpeed(zombie, sandboxOptions)
                    end
                end
            end
        end

        -- Send requests to server for zombie information
        if #proposals > 0 then
            sendClientCommand(player, "SIMBA_TSY", "RequestZombieInfo", {
                zombies = proposals
            })
            -- print("SIMBA_TSY Client: Requested info for " .. #proposals .. " zombies from server")
        end
        return
    end
    sendClientCommand("RegionManager", "RequestAllBoundaries", {})
end

-- ============================================================================
-- Register with the central tick dispatcher
-- The sprinter module hooks into onTick to process zombies every interval.
-- ============================================================================
---@type TickModuleDef
local sprinterModule = {
    name = "SIMBA_TSY_Sprinters",

    -- Called every tick interval by the dispatcher
    onTick = function(player, currentZones)
        SIMBA_TSY_ProcessZombies(currentZones)
    end
}
RegionManager.ClientTick.registerModule(sprinterModule)

-- ============================================================================
-- Zombie death handler
-- ============================================================================
local function onZombieDead(zombie)
    if not zombie then
        return
    end
    local player = getPlayer()
    if not player then
        return
    end

    local attacker = zombie:getAttackedBy()
    if not attacker or attacker ~= player then
        return
    end

    local modData = zombie:getModData()
    local killBonus = modData.SIMBA_TSY_KillBonus or 0
    -- Base kill = 1, plus difficulty bonus (already clamped to >= 0)
    local totalKillValue = 1 + killBonus
    ZKC_Main.recordKill(player, totalKillValue)
    if killBonus > 0 then
        print("SIMBA_TSY: Player earned +" .. killBonus .. " extra kill points (total " .. totalKillValue .. ")")
    end
end
Events.OnZombieDead.Add(onZombieDead)
