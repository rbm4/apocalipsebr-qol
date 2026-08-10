-- Zombie Kill Counter - Server-Side Handler
-- Tracks kills on the server and writes aggregated player data to file

require "ZombieKillCounter/ZKC_Config"

ZKC_ServerHandler = ZKC_ServerHandler or {}
ZKC_ServerHandler.playerStatsById = ZKC_ServerHandler.playerStatsById or {}
ZKC_ServerHandler.playerKeys = ZKC_ServerHandler.playerKeys or {}
ZKC_ServerHandler.lastFlushTime = ZKC_ServerHandler.lastFlushTime or os.time()

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
        totalSessionKills = 0,
        baselineZombieKills = nil,
        lastKnownZombieKills = nil
    }

    ZKC_ServerHandler.playerStatsById[playerKey] = stats
    ZKC_ServerHandler.playerKeys[#ZKC_ServerHandler.playerKeys + 1] = playerKey
    return stats, playerKey
end

local function getBeyondTen()
    if BeyondTen then return BeyondTen end
    pcall(require, "BeyondTen/Shared")
    return BeyondTen
end

local function hasTableValues(values)
    if type(values) ~= "table" then return false end
    for _key, _value in pairs(values) do return true end
    return false
end

local function collectBeyondTenData(player)
    local BT = getBeyondTen()
    if not BT or type(BT.ExportXP) ~= "function" then return nil, nil end

    local masteryXP = BT.ExportXP(player)
    if not hasTableValues(masteryXP) then return nil, nil end

    local effectiveLevels = {}
    if type(BT.GetEffectiveLevel) == "function" and type(BT.ResolvePerk) == "function" then
        for perkId, _xp in pairs(masteryXP) do
            local perk = BT.ResolvePerk(perkId)
            if perk then
                effectiveLevels[perkId] = BT.GetEffectiveLevel(player, perk)
            end
        end
    end

    return masteryXP, hasTableValues(effectiveLevels) and effectiveLevels or nil
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

        local beyondTenSkills, effectiveSkillLevels = collectBeyondTenData(player)
        if beyondTenSkills then
            data.beyondTenSkills = beyondTenSkills
        end
        if effectiveSkillLevels then
            data.effectiveSkillLevels = effectiveSkillLevels
        end
    end

    return data
end

local function queueTrackedPlayers()
    local payloads = {}
    local flushedStats = {}
    local flushedByKey = {}

    local onlinePlayers = getOnlinePlayers()
    if onlinePlayers then
        for playerIndex = 0, onlinePlayers:size() - 1 do
            local player = onlinePlayers:get(playerIndex)
            if player then
                local stats, playerKey = getOrCreatePlayerStats(player)
                stats.playerName = player:getUsername()
                payloads[#payloads + 1] = serializeValue(collectPlayerData(player, stats))
                flushedStats[#flushedStats + 1] = stats
                flushedByKey[playerKey] = true
            end
        end
    end

    local playerKeys = ZKC_ServerHandler.playerKeys
    local playerStatsById = ZKC_ServerHandler.playerStatsById
    for i = 1, #playerKeys do
        local playerKey = playerKeys[i]
        local stats = playerStatsById[playerKey]
        if stats and stats.killsSinceLastUpdate > 0 and not flushedByKey[playerKey] then
            local player = getPlayerByOnlineID(tonumber(playerKey:match("^online:(%-?%d+)$")) or -1)
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
        ZKC_ServerHandler.lastFlushTime = os.time()
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
    ZKC_ServerHandler.lastFlushTime = os.time()
    return true
end

local function samplePlayerKillDelta(player)
    if not ZKC_Config.enabled or not isServer() or not player then
        return
    end

    local currentZombieKills = player:getZombieKills()
    if type(currentZombieKills) ~= "number" then
        return
    end

    local stats = getOrCreatePlayerStats(player)
    stats.playerName = player:getUsername()

    if not stats.lastKnownZombieKills then
        stats.baselineZombieKills = currentZombieKills
        stats.lastKnownZombieKills = currentZombieKills
        log("Baseline kill count for " .. tostring(stats.playerName) .. ": " .. tostring(currentZombieKills))
        return
    end

    if currentZombieKills < stats.lastKnownZombieKills then
        if stats.killsSinceLastUpdate > 0 then
            ZKC_ServerHandler.flushPendingPayloads()
        end

        log(
            "Kill count reset for " .. tostring(stats.playerName) .. " (" ..
                tostring(stats.lastKnownZombieKills) .. " -> " .. tostring(currentZombieKills) .. "); rebasing"
        )
        stats.baselineZombieKills = currentZombieKills
        stats.lastKnownZombieKills = currentZombieKills
        stats.killsSinceLastUpdate = 0
        stats.totalSessionKills = 0
        return
    end

    local delta = currentZombieKills - stats.lastKnownZombieKills
    if delta <= 0 then
        return
    end

    stats.lastKnownZombieKills = currentZombieKills
    stats.killsSinceLastUpdate = stats.killsSinceLastUpdate + delta
    stats.totalSessionKills = currentZombieKills - (stats.baselineZombieKills or currentZombieKills)

    if ZKC_Config.Storage.debug then
        log(
            "Kill delta for " .. tostring(stats.playerName) .. ": +" .. tostring(delta) ..
                " (vanilla: " .. tostring(currentZombieKills) ..
                ", pending: " .. tostring(stats.killsSinceLastUpdate) ..
                ", session: " .. tostring(stats.totalSessionKills) .. ")"
        )
    end
end

function ZKC_ServerHandler.sampleOnlinePlayers()
    if not ZKC_Config.enabled or not isServer() then
        return
    end

    local onlinePlayers = getOnlinePlayers()
    if not onlinePlayers then
        return
    end

    local shouldFlush = false
    for playerIndex = 0, onlinePlayers:size() - 1 do
        local player = onlinePlayers:get(playerIndex)
        if player then
            samplePlayerKillDelta(player)

            local stats = ZKC_ServerHandler.playerStatsById[getPlayerKey(player)]
            if ZKC_Config.Batch.enabled and stats and stats.killsSinceLastUpdate >= ZKC_Config.Batch.maxBatchSize then
                shouldFlush = true
            end
        end
    end

    if shouldFlush then
        ZKC_ServerHandler.flushPendingPayloads()
    end
end

function ZKC_ServerHandler.checkPeriodicFlush()
    if not ZKC_Config.enabled or not ZKC_Config.Batch.enabled then
        return
    end

    local elapsedSeconds = os.time() - (ZKC_ServerHandler.lastFlushTime or 0)
    if elapsedSeconds >= ZKC_Config.Batch.maxBatchTimeSeconds then
        ZKC_ServerHandler.flushPendingPayloads()
    end
end

function ZKC_ServerHandler.updateOnlinePlayersAndFlush()
    ZKC_ServerHandler.sampleOnlinePlayers()
    ZKC_ServerHandler.checkPeriodicFlush()
end


Events.EveryHours.Add(ZKC_ServerHandler.flushPendingPayloads)
Events.EveryOneMinute.Add(ZKC_ServerHandler.updateOnlinePlayersAndFlush)

log("Server handler initialized for vanilla kill-count sampling")

return ZKC_ServerHandler
