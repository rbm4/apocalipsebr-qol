-- Zombie Kill Counter & Player Tracker - Main Module
-- Tracks zombie kills, player position, and manages batching
require "ZombieKillCounter/ZKC_Config"
require "ZombieKillCounter/ZKC_API"

ZKC_Main = ZKC_Main or {}

-- Tracking data
ZKC_Main.killCount = 0 -- Kills since last send
ZKC_Main.totalKills = 0 -- Total session kills
ZKC_Main.lastBatchSendTime = 0
ZKC_Main.lastPosition = {
    x = 0,
    y = 0,
    z = 0
}
ZKC_Main.updatesSent = 0

-- Initialize the mod
function ZKC_Main.initialize()
    print("[ZKC] Zombie Kill Counter & Player Tracker initialized!")

    if not ZKC_Config.enabled then
        print("[ZKC] Feature is disabled in config")
        return
    end

    -- Initialize tracking
    ZKC_Main.killCount = 0
    ZKC_Main.totalKills = 0
    ZKC_Main.lastBatchSendTime = os.time()
    ZKC_Main.updatesSent = 0

    -- Initialize position tracking
    local player = getSpecificPlayer(0)
    if player then
        ZKC_Main.lastPosition.x = player:getX()
        ZKC_Main.lastPosition.y = player:getY()
        ZKC_Main.lastPosition.z = player:getZ()
    end

    print("[ZKC] Update interval: " .. ZKC_Config.Batch.maxBatchTimeSeconds .. " seconds")
    print("[ZKC] Max batch size: " .. ZKC_Config.Batch.maxBatchSize .. " kills")
    print("[ZKC] Data file: " .. ZKC_Config.Storage.filename)
    print("[ZKC] Writing to file-based storage for external API consumption")
end

-- Record a zombie kill
-- @param player IsoPlayer who made the kill
-- @param value number that credit this kill
function ZKC_Main.recordKill(player,value)
    if not ZKC_Config.enabled or not player then
        return
    end

    ZKC_Main.killCount = ZKC_Main.killCount + value
    ZKC_Main.totalKills = ZKC_Main.totalKills + value

    if ZKC_Config.Storage.debug then
        print("[ZKC] Kill #" .. ZKC_Main.totalKills .. " recorded (pending: " .. ZKC_Main.killCount .. "/" ..
                  ZKC_Config.Batch.maxBatchSize .. ")")
    end

    -- Check if we should send immediately due to kill threshold
    if ZKC_Config.Batch.enabled and ZKC_Main.killCount >= ZKC_Config.Batch.maxBatchSize then
        ZKC_Main.sendUpdate(player, "kill_threshold")
    end
end

-- Calculate distance between two positions
local function getDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Check if player moved enough to warrant an update
local function hasMovedEnough(player)
    if ZKC_Config.PlayerData.minimumMovementDistance <= 0 then
        return true
    end

    local currentX = player:getX()
    local currentY = player:getY()

    local distance = getDistance(ZKC_Main.lastPosition.x, ZKC_Main.lastPosition.y, currentX, currentY)

    return distance >= ZKC_Config.PlayerData.minimumMovementDistance
end

-- Collect comprehensive player data
local function collectPlayerData(player)
    local data = {
        playerName = player:getUsername(),
        playerId = player:getSteamID(),
        timestamp = os.time(),
        serverName = " ",
        updateNumber = ZKC_Main.updatesSent
    }
    local steamId = player:getSteamID()
    local high = math.floor(steamId / 4294967296) -- Upper 32 bits
    local low = steamId % 4294967296 -- Lower 32 bits
    data.playerIdHigh = high
    data.playerIdLow = low
    -- Kill data (always included)
    data.killsSinceLastUpdate = ZKC_Main.killCount
    data.totalSessionKills = ZKC_Main.totalKills

    -- Position data
    if ZKC_Config.PlayerData.includePosition then
        data.x = math.floor(player:getX())
        data.y = math.floor(player:getY())
        data.z = math.floor(player:getZ())

        -- Update last known position
        ZKC_Main.lastPosition.x = data.x
        ZKC_Main.lastPosition.y = data.y
        ZKC_Main.lastPosition.z = data.z
    end

    -- Health data
    if ZKC_Config.PlayerData.includeHealth then
        local bodyDamage = player:getBodyDamage()
        data.health = math.floor(bodyDamage:getOverallBodyHealth())
        data.infected = bodyDamage:IsInfected()
        data.isDead = player:isDead()
    end

    -- Vehicle info
    if ZKC_Config.PlayerData.includeVehicle then
        local vehicle = player:getVehicle()
        data.inVehicle = vehicle ~= nil
        if vehicle then
            data.vehicleType = vehicle:getScriptName()
        end
    end

    -- Character info
    if ZKC_Config.PlayerData.includeCharacterInfo then
        data.hoursSurvived = math.floor(player:getHoursSurvived())
    end

    return data
end

-- Send player update with kills and position data
-- @param player IsoPlayer
-- @param reason string reason for update ("timer", "kill_threshold", "manual")
function ZKC_Main.sendUpdate(player, reason)
    if not ZKC_Config.enabled or not player then
        return
    end

    -- Check movement requirement (skip for kill threshold)
    if reason ~= "kill_threshold" and not hasMovedEnough(player) then
        if ZKC_Config.Storage.debug then
            print("[ZKC] Player hasn't moved enough, skipping update")
        end
        return
    end

    -- Collect comprehensive player data
    local playerData = collectPlayerData(player)
    playerData.updateReason = reason

    if ZKC_Config.Storage.debug then
        print("[ZKC] Writing update #" .. ZKC_Main.updatesSent .. " (" .. reason .. "): " .. ZKC_Main.killCount ..
                  " kills")
    end

    -- Write to data file
    ZKC_API.sendKillData(playerData)

    -- Reset counters
    ZKC_Main.killCount = 0
    ZKC_Main.lastBatchSendTime = os.time()
    ZKC_Main.updatesSent = ZKC_Main.updatesSent + 1
end

-- Check if periodic update should be sent
function ZKC_Main.checkPeriodicUpdate()
    if not ZKC_Config.enabled or not ZKC_Config.Batch.enabled then
        return
    end

    local player = getSpecificPlayer(0)
    if not player then
        return
    end

    -- Check if time threshold reached
    local currentTime = os.time()
    local timeSinceLastSend = currentTime - ZKC_Main.lastBatchSendTime

    if timeSinceLastSend >= ZKC_Config.Batch.maxBatchTimeSeconds then
        ZKC_Main.sendUpdate(player, "timer")
    end
end

-- Get player statistics
function ZKC_Main.getStats()
    return {
        totalKills = ZKC_Main.totalKills,
        pendingKills = ZKC_Main.killCount,
        updatesSent = ZKC_Main.updatesSent,
        lastUpdateTime = ZKC_Main.lastBatchSendTime
    }
end

return ZKC_Main
