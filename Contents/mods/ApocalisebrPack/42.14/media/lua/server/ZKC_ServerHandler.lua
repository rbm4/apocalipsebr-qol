-- Zombie Kill Counter - Server-Side Handler
-- Tracks kills on the server and writes aggregated player data to file

require "ZombieKillCounter/ZKC_Config"

ZKC_ServerHandler = ZKC_ServerHandler or {}
ZKC_ServerHandler.playerStatsById = ZKC_ServerHandler.playerStatsById or {}
ZKC_ServerHandler.playerKeys = ZKC_ServerHandler.playerKeys or {}

-- Logging helper
local function log(message)
    if ZKC_Config.Storage.debug then
        print("[ZKC_Server] " .. tostring(message))
    end
end

local function serializeValue(value)
    local valueType = type(value)
    if valueType == "string" then
        return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
    elseif valueType == "number" then
        if value == math.floor(value) then
            return string.format("%.0f", value)
        end
        return tostring(value)
    elseif valueType == "boolean" then
        return value and "true" or "false"
    elseif valueType == "table" then
        local parts = {}
        for key, nestedValue in pairs(value) do
            parts[#parts + 1] = '"' .. tostring(key) .. '":' .. serializeValue(nestedValue)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return '"' .. tostring(value) .. '"'
end

local function getPlayerKey(player)
    local steamId = player:getSteamID()
    if steamId and steamId ~= 0 then
        return tostring(steamId)
    end
    return "online:" .. tostring(player:getOnlineID())
end

local function getOrCreatePlayerStats(player)
    local playerKey = getPlayerKey(player)
    local stats = ZKC_ServerHandler.playerStatsById[playerKey]
    if stats then
        return stats, playerKey
    end

    stats = {
        playerKey = playerKey,
        updateNumber = 0,
        killsSinceLastUpdate = 0,
        totalSessionKills = 0
    }

    ZKC_ServerHandler.playerStatsById[playerKey] = stats
    ZKC_ServerHandler.playerKeys[#ZKC_ServerHandler.playerKeys + 1] = playerKey
    return stats, playerKey
end

local function collectPlayerData(player, stats)
    local steamId = player:getSteamID()
    local high = math.floor(steamId / 4294967296)
    local low = steamId % 4294967296
    local data = {
        playerName = player:getUsername(),
        playerId = steamId,
        playerIdHigh = high,
        playerIdLow = low,
        timestamp = os.time(),
        serverName = " ",
        updateNumber = stats.updateNumber,
        killsSinceLastUpdate = stats.killsSinceLastUpdate,
        totalSessionKills = stats.totalSessionKills,
        updateReason = "timer"
    }

    if ZKC_Config.PlayerData.includePosition then
        data.x = math.floor(player:getX())
        data.y = math.floor(player:getY())
        data.z = math.floor(player:getZ())
    end

    if ZKC_Config.PlayerData.includeHealth then
        local bodyDamage = player:getBodyDamage()
        data.health = math.floor(bodyDamage:getOverallBodyHealth())
        data.infected = bodyDamage:IsInfected()
        data.isDead = player:isDead()
    end

    if ZKC_Config.PlayerData.includeVehicle then
        local vehicle = player:getVehicle()
        data.inVehicle = vehicle ~= nil
        if vehicle then
            data.vehicleType = vehicle:getScriptName()
        end
    end

    if ZKC_Config.PlayerData.includeCharacterInfo then
        data.hoursSurvived = math.floor(player:getHoursSurvived())

        local skills = {}
        local xpObj = player:getXp()
        for i = 1, Perks.getMaxIndex() - 1 do
            local perk = Perks.fromIndex(i)
            if perk and perk:getParent():getId() ~= "None" then
                skills[perk:getId()] = xpObj:getXP(perk)
            end
        end
        data.skills = skills
    end

    return data
end

local function queueTrackedPlayers()
    local playerKeys = ZKC_ServerHandler.playerKeys
    local playerStatsById = ZKC_ServerHandler.playerStatsById
    local payloads = {}
    local flushedStats = {}

    for i = 1, #playerKeys do
        local playerKey = playerKeys[i]
        local stats = playerStatsById[playerKey]
        if stats and stats.killsSinceLastUpdate > 0 then
            local player = getPlayerByOnlineID(tonumber(playerKey:match("^online:(%-?%d+)$")) or -1)
            if not player and stats.playerName then
                local onlinePlayers = getOnlinePlayers()
                for playerIndex = 0, onlinePlayers:size() - 1 do
                    local onlinePlayer = onlinePlayers:get(playerIndex)
                    if onlinePlayer and getPlayerKey(onlinePlayer) == playerKey then
                        player = onlinePlayer
                        break
                    end
                end
            end

            if player then
                payloads[#payloads + 1] = serializeValue(collectPlayerData(player, stats))
                flushedStats[#flushedStats + 1] = stats
            else
                log("Skipping flush for missing player session: " .. tostring(playerKey))
            end
        end
    end

    return payloads, flushedStats
end

function ZKC_ServerHandler.flushPendingPayloads()
    local payloads, flushedStats = queueTrackedPlayers()
    local payloadCount = #payloads
    if payloadCount == 0 then
        return true
    end

    local filename = ZKC_Config.Storage.filename
    local success, written, errorMessage = pcall(function()
        local writer = getFileWriter(filename, true, true)
        if not writer then
            return false, "Failed to open file for writing: " .. filename
        end

        for i = 1, payloadCount do
            writer:write(payloads[i])
            writer:write("\n")
        end
        writer:close()
        return true
    end)

    if not success then
        log("Error flushing " .. payloadCount .. " queued entries: " .. tostring(written))
        return false
    end
    if not written then
        log("ERROR: " .. tostring(errorMessage))
        return false
    end

    for i = 1, #flushedStats do
        local stats = flushedStats[i]
        stats.killsSinceLastUpdate = 0
        stats.updateNumber = stats.updateNumber + 1
    end

    log("Flushed " .. payloadCount .. " queued entries to " .. filename)
    return true
end

function recordKill(player, value)
    if not ZKC_Config.enabled or not player or type(value) ~= "number" or value <= 0 then
        return
    end

    local stats = getOrCreatePlayerStats(player)
    stats.playerName = player:getUsername()
    stats.killsSinceLastUpdate = stats.killsSinceLastUpdate + value
    stats.totalSessionKills = stats.totalSessionKills + value

    if ZKC_Config.Storage.debug then
        log(
            "Kill recorded for " .. tostring(stats.playerName) .. " (pending: " ..
                tostring(stats.killsSinceLastUpdate) .. ", total: " .. tostring(stats.totalSessionKills) .. ")"
        )
    end
end

-- Called when a zombie dies
-- @param zombie IsoZombie that was killed
local function onZombieDead(zombie)
    if not zombie or not ZKC_Config.enabled or not isServer() then
        return
    end

    local modData = zombie:getModData()
    if modData.ZKC_KillRecorded then
        return
    end

    -- Check if this player killed the zombie
    -- Method 1: Check attacker reference
    local attacker = zombie:getAttackedBy()
    if attacker and instanceof(attacker, "IsoPlayer") then
        modData.ZKC_KillRecorded = true
        recordKill(attacker, 1)
    end
end

Events.EveryHours.Add(ZKC_ServerHandler.flushPendingPayloads)
Events.OnZombieDead.Add(onZombieDead)

log("Server handler initialized for server-side kill tracking")

return ZKC_ServerHandler
