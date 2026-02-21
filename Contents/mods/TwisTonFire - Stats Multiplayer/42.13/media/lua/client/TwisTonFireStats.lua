require "ISUI/ISLayoutManager"
require "ISUI/ISContextMenu"
pcall(require, "TTF_Stats_ModOptions")
-- require "TWITCHSTATS_ContextMenu"

TwisTonFireStats = TwisTonFireStats or {}

STATSTabClass = ISPanel:derive("STATSTab")

-- This table remains global for the UI
STATSTab = {}
STATSTab.showCalendar = true
STATSTab.showKills = true
STATSTab.showTraveled = true
STATSTab.showWeight = true
STATSTab.showDailyKills = true
STATSTab.showAvgKills = true
STATSTab.calendarMode = 1
STATSTab.positions = {
    calendar = -15,
    kills = 25,
    traveled = 65,
    weight = 105,
    dailyKills = 145,
    avgKills = 185,
}

print("----------------LOADING TWITCH STATS UI ------------------")
local modId                    = "\\twistonfirestats"
local lastPosition             = { x = 0, y = 0 }
local distanceTracker          = 0
local saveInterval             = 5
local nextInterval             = getTimestamp()

-- Textures
local calendarTexture          = getTexture("media/ui/calendar.png")
local zedsKillsTexture         = getTexture("media/ui/zedkills.png")
local traveledTexture          = getTexture("media/ui/travelled.png")
local weightTexture            = getTexture("media/ui/peso.png")
local dailyTexture             = getTexture("media/ui/daily.png")
local avgTexture               = getTexture("media/ui/schnitt.png")
local indicatorHighTexture     = getTexture("media/ui/indicator_high.png")
local indicatorLowTexture      = getTexture("media/ui/indicator_low.png")
local indicatorHighHighTexture = getTexture("media/ui/indicator_highhigh.png")
local indicatorLowLowTexture   = getTexture("media/ui/indicator_lowlow.png")
local fontTexture              = getTexture("media/ui/font.png")
local alignTexture             = getTexture("media/ui/align.png")
local SAVE_DIR                 = "statsMP/"

local function ensureStatsFolder()
    if createFolder then
        createFolder(SAVE_DIR)
    end
end

-- =========================================================
-- MP-only: local persistent state (client-side only)
-- Stores all custom (non-vanilla) values in ONE file per character.
-- =========================================================

local __TTF_MPState = nil
local __TTF_MPStateKey = nil
local __TTF_MPStatePath = nil
local __TTF_MPStateNextWrite = 0
local __TTF_MPStateWriteCooldown = 3 -- seconds

-- MP-only: in-game date stamp (server-synced)
local function __ttfGetIngameDateStamp()
    local gt = getGameTime()
    local y = gt:getYear()
    local m = (gt:getMonth() or 0) + 1
    local d = (gt:getDay() or 0) + 1
    return (y * 10000) + (m * 100) + d
end

local function __ttfSanitizeFileComponent(s)
    s = tostring(s or "")
    s = s:gsub("[%s\r\n\t]", "")
    if s == "" then s = "x" end
    return (s:gsub("[^%w%._%-]", "_"))
end

function __ttfGetServerFingerprint()
    local ip = ""
    local port = ""
    local name = ""

    local ok

    ok, ip = pcall(getServerIP)
    if not ok or ip == nil then ip = "" end
    ip = tostring(ip)

    ok, port = pcall(getServerPort)
    if not ok or port == nil then port = "" end
    port = tostring(port)

    ok, name = pcall(getServerName)
    if not ok or name == nil then name = "" end
    name = tostring(name)

    -- In MP, getServerIP() can be a RakNet/GUID-like numeric string that changes per reconnect.
    -- Treat that as unstable and ignore it for fingerprinting.
    local ipIsNumeric = ip:match("^%d+$") ~= nil
    local ipLooksLikeAddress = (ip:match("[%a]") ~= nil) or (ip:match("[%.:]") ~= nil)

    local fpParts = {}

    if name ~= "" and name ~= "nil" then
        table.insert(fpParts, name)
    end

    if port ~= "" and port ~= "nil" and port ~= "0" then
        table.insert(fpParts, port)
    end

    -- Only include IP if it looks like a real address/hostname (not a pure numeric GUID)
    if ip ~= "" and ip ~= "nil" and (not ipIsNumeric) and ipLooksLikeAddress then
        table.insert(fpParts, ip)
    end

    local fp
    if #fpParts == 0 then
        fp = "mp"
    else
        fp = table.concat(fpParts, "_")
    end

    return __ttfSanitizeFileComponent(fp)
end

function __ttfBuildStateKey(player)
    if not player then
        return __ttfSanitizeFileComponent("mp_unknown")
    end

    local serverFP = __ttfGetServerFingerprint()

    local desc     = (player.getDescriptor and player:getDescriptor()) or nil

    local forename = "unknown"
    local surname  = "unknown"
    if desc then
        if desc.getForename then
            local fn = desc:getForename()
            if fn ~= nil and tostring(fn) ~= "" and tostring(fn) ~= "nil" then
                forename = tostring(fn)
            end
        end
        if desc.getSurname then
            local sn = desc:getSurname()
            if sn ~= nil and tostring(sn) ~= "" and tostring(sn) ~= "nil" then
                surname = tostring(sn)
            end
        end
    end

    local charId = nil
    pcall(function()
        if desc and desc.getID then
            charId = desc:getID()
        end
    end)
    if charId == nil or tostring(charId) == "" or tostring(charId) == "0" or tostring(charId) == "nil" then
        pcall(function()
            if desc and desc.getPersistentId then
                charId = desc:getPersistentId()
            end
        end)
    end

    -- Preferred: stable character ID (prevents duplicates + avoids name collisions)
    if charId ~= nil and tostring(charId) ~= "" and tostring(charId) ~= "0" and tostring(charId) ~= "nil" then
        local raw = serverFP .. "_cid" .. tostring(charId) .. "_" .. forename .. "_" .. surname
        return __ttfSanitizeFileComponent(raw)
    end

    -- Fallback: username + character name (only if character ID isn't available)
    local uname = ""
    pcall(function()
        if player.getUsername then
            uname = tostring(player:getUsername() or "")
        end
    end)
    if uname == "" or uname == "nil" then
        uname = "noname"
    end

    local raw = serverFP .. "_" .. uname .. "_" .. forename .. "_" .. surname
    return __ttfSanitizeFileComponent(raw)
end

local function __ttfReadKV(path)
    local ok, reader = pcall(getFileReader, path, false)
    if not ok or not reader then return nil end

    local t = {}
    while true do
        local line = reader:readLine()
        if not line then break end
        local k, v = line:match("^([^=]+)=(.*)$")
        if k then t[k] = v end
    end

    pcall(function() reader:close() end)
    return t
end

local function __ttfWriteKV(path, state)
    -- Merge-write into the shared file (do not erase ks.* keys written by TTF_KillStats.lua)
    local raw = __ttfReadKV(path) or {}

    -- Remove old mp.* keys to avoid stale leftovers
    for k, _ in pairs(raw) do
        if type(k) == "string" and k:sub(1, 3) == "mp." then
            raw[k] = nil
        end
    end

    raw["version"]               = 2

    raw["mp.PersistentUniqueID"] = tostring(state.PersistentUniqueID or "")
    raw["mp.distanceTracker"]    = tostring(tonumber(state.distanceTracker) or 0)
    raw["mp.distanceMax"]        = tostring(tonumber(state.distanceMax) or 0)
    raw["mp.dailyKillRecord"]    = tostring(tonumber(state.dailyKillRecord) or 0)

    raw["mp.baselineDateStamp"]  = tostring(tonumber(state.baselineDateStamp) or 0)
    raw["mp.lastSeenDateStamp"]  = tostring(tonumber(state.lastSeenDateStamp) or 0)
    raw["mp.lastSeenKills"]      = tostring(tonumber(state.lastSeenKills) or 0)

    -- Only persist if known; keep missing => nil-on-first-run behavior
    if state.killsAtMidnight ~= nil then
        raw["mp.killsAtMidnight"] = tostring(tonumber(state.killsAtMidnight) or 0)
    end

    local ok, writer = pcall(getFileWriter, path, true, false)
    if not ok or not writer then return false end

    -- Stable output: version first, then sorted keys
    writer:write("version=" .. tostring(raw["version"]) .. "\n")

    local keys = {}
    for k, _ in pairs(raw) do
        if k ~= "version" then keys[#keys + 1] = k end
    end
    table.sort(keys)

    for _, k in ipairs(keys) do
        writer:write(tostring(k) .. "=" .. tostring(raw[k]) .. "\n")
    end

    pcall(function() writer:close() end)
    return true
end

function __ttfEnsureMPState(player)
    if not player then return nil end

    ensureStatsFolder()

    local key = __ttfBuildStateKey(player)
    local fileName = "TTF_MPStats_" .. key .. ".txt"
    local path = SAVE_DIR .. fileName

    if __TTF_MPState ~= nil and __TTF_MPStateKey == key and __TTF_MPStatePath == path then
        return __TTF_MPState
    end

    local function fileReadable(relPath)
        local ok, r = pcall(getFileReader, relPath, false)
        if ok and r then
            pcall(function() r:close() end)
            return true
        end
        return false
    end

    local function writeRawKV(relPath, raw)
        raw = raw or {}
        raw["version"] = raw["version"] or 2

        local ok, w = pcall(getFileWriter, relPath, true, false)
        if not ok or not w then return false end

        w:write("version=" .. tostring(raw["version"]) .. "\n")

        local keys = {}
        for k, _ in pairs(raw) do
            if k ~= "version" then keys[#keys + 1] = k end
        end
        table.sort(keys)

        for _, k in ipairs(keys) do
            w:write(tostring(k) .. "=" .. tostring(raw[k]) .. "\n")
        end

        pcall(function() w:close() end)
        return true
    end

    local function ksTotal(raw)
        local total = tonumber(raw["ks.vehicleKills"]) or 0

        local cats = {
            "Axe", "LongBlade", "SmallBlade", "Spear", "Blunt", "SmallBlunt",
            "Firearm", "Vehicle", "Unarmed", "Other"
        }
        for _, cat in ipairs(cats) do
            total = total + (tonumber(raw["ks.cat." .. cat]) or 0)
        end

        for k, v in pairs(raw) do
            if type(k) == "string" and k:sub(1, 7) == "ks.wpn." then
                total = total + (tonumber(v) or 0)
            end
        end

        return total
    end

    local function mpScore(raw)
        local dist = tonumber(raw["mp.distanceMax"]) or tonumber(raw["mp.distanceTracker"]) or 0
        local kills = tonumber(raw["mp.lastSeenKills"]) or 0
        return dist, kills
    end

    local function findBestLegacyCandidates(playerObj)
        local desc = (playerObj.getDescriptor and playerObj:getDescriptor()) or nil
        local fn = "unknown"
        local sn = "unknown"
        if desc then
            if desc.getForename then
                local v = desc:getForename()
                if v ~= nil and tostring(v) ~= "" and tostring(v) ~= "nil" then fn = tostring(v) end
            end
            if desc.getSurname then
                local v = desc:getSurname()
                if v ~= nil and tostring(v) ~= "" and tostring(v) ~= "nil" then sn = tostring(v) end
            end
        end

        fn = __ttfSanitizeFileComponent(fn)
        sn = __ttfSanitizeFileComponent(sn)

        local function escapePattern(s)
            return (tostring(s):gsub("(%W)", "%%%1"))
        end
        local suffixPat = "_" .. escapePattern(fn) .. "_" .. escapePattern(sn) .. "%.txt$"

        local okJava = (luajava and luajava.bindClass) and true or false
        if not okJava then return nil, nil end

        local okBind, File = pcall(luajava.bindClass, "java.io.File")
        if not okBind or not File then return nil, nil end

        local sep = (getFileSeparator and getFileSeparator()) or "/"
        local doc = (getMyDocumentFolder and getMyDocumentFolder()) or ""

        local function normalizeDir(p)
            p = tostring(p or "")
            p = p:gsub("[/\\]+", sep)
            if p:sub(-1) == sep then p = p:sub(1, -2) end
            return p
        end

        local statsDirRel = normalizeDir(SAVE_DIR)
        local absStatsDir = (doc ~= "" and (normalizeDir(doc) .. sep .. "Lua" .. sep .. statsDirRel)) or statsDirRel

        local okDir, dir = pcall(function()
            if File.new then return File.new(absStatsDir) end
            return File(absStatsDir)
        end)
        if not okDir or not dir or not (dir.exists and dir:exists()) or not (dir.isDirectory and dir:isDirectory()) then
            return nil, nil
        end

        local okList, arr = pcall(function() return dir:listFiles() end)
        if not okList or not arr then return nil, nil end

        local bestMP = nil
        local bestMPDist = -1
        local bestMPKills = -1

        local bestKS = nil
        local bestKSTotal = -1

        local function considerFile(n)
            if n == fileName then return end
            if not n:match("^TTF_MPStats_") then return end
            if not n:match(suffixPat) then return end

            local rel = SAVE_DIR .. n
            local raw = __ttfReadKV(rel) or {}

            local dist, lk = mpScore(raw)
            if dist > bestMPDist or (dist == bestMPDist and lk > bestMPKills) then
                bestMPDist = dist
                bestMPKills = lk
                bestMP = rel
            end

            local kt = ksTotal(raw)
            if kt > bestKSTotal then
                bestKSTotal = kt
                bestKS = rel
            end
        end

        if arr.size then
            for i = 0, (arr:size() - 1) do
                local f = arr:get(i)
                if f and f.getName then
                    considerFile(tostring(f:getName() or ""))
                end
            end
        else
            for i = 1, #arr do
                local f = arr[i]
                if f and f.getName then
                    considerFile(tostring(f:getName() or ""))
                end
            end
        end

        return bestMP, bestKS
    end

    -- If our canonical file doesn't exist yet, merge legacy duplicates into it once.
    if not fileReadable(path) then
        local bestMP, bestKS = findBestLegacyCandidates(player)

        if bestMP and fileReadable(bestMP) then
            local rawMP = __ttfReadKV(bestMP) or {}

            if bestKS and bestKS ~= bestMP and fileReadable(bestKS) then
                local rawKS = __ttfReadKV(bestKS) or {}

                for k, v in pairs(rawKS) do
                    if type(k) == "string" and k:sub(1, 3) == "ks." then
                        rawMP[k] = v
                    end
                end

                -- Prefer PersistentUniqueID from the file that has real kill data (avoids creating new CSV logs)
                if rawKS["mp.PersistentUniqueID"] ~= nil and tostring(rawKS["mp.PersistentUniqueID"]) ~= "" then
                    rawMP["mp.PersistentUniqueID"] = rawKS["mp.PersistentUniqueID"]
                end
            end

            writeRawKV(path, rawMP)
        end
    end

    local raw             = __ttfReadKV(path) or {}

    __TTF_MPState         = __TTF_MPState or {}
    local st              = __TTF_MPState

    st.PersistentUniqueID = tostring(raw["mp.PersistentUniqueID"] or "")
    st.distanceTracker    = tonumber(raw["mp.distanceTracker"]) or 0
    st.distanceMax        = tonumber(raw["mp.distanceMax"]) or 0
    st.dailyKillRecord    = tonumber(raw["mp.dailyKillRecord"]) or 0
    st.baselineDateStamp  = tonumber(raw["mp.baselineDateStamp"]) or 0
    st.lastSeenDateStamp  = tonumber(raw["mp.lastSeenDateStamp"]) or 0
    st.lastSeenKills      = tonumber(raw["mp.lastSeenKills"]) or 0

    if raw["mp.killsAtMidnight"] ~= nil then
        st.killsAtMidnight = tonumber(raw["mp.killsAtMidnight"]) or 0
    else
        st.killsAtMidnight = nil
    end

    __TTF_MPStateKey  = key
    __TTF_MPStatePath = path

    return st
end

local function __ttfMirrorStateToModData(player)
    if not player then return end
    local st = __ttfEnsureMPState(player)
    if not st then return end

    local md = player:getModData()
    if not md then return end

    md.PersistentUniqueID = st.PersistentUniqueID
    md.distanceTracker    = st.distanceTracker
    md.distanceMax        = st.distanceMax
    md.killsAtMidnight    = st.killsAtMidnight or md.killsAtMidnight
    md["dailyKillRecord"] = st.dailyKillRecord
end

local function __ttfFlushMPState(player, force)
    if not player then return end
    local st = __ttfEnsureMPState(player)
    if not st or not __TTF_MPStatePath then return end

    local now = getTimestamp()
    if not force and now < __TTF_MPStateNextWrite then return end

    __TTF_MPStateNextWrite = now + __TTF_MPStateWriteCooldown
    __ttfWriteKV(__TTF_MPStatePath, st)
end

local function __ttfUpdateLastSeenSnapshot(player)
    local st = __ttfEnsureMPState(player)
    if not st then return end
    st.lastSeenKills = tonumber(player:getZombieKills()) or 0
    st.lastSeenDateStamp = __ttfGetIngameDateStamp()
end


local function getFontForStats(fontSizeMode)
    if fontSizeMode == 2 then
        return UIFont.Medium
    elseif fontSizeMode == 3 then
        return UIFont.Small
    else
        return UIFont.Large
    end
end

local colorModes    = {
    { 1,    1,    1 },
    { 1,    0.4,  0 },
    { 0.57, 0.27, 1 },
    { 0.2,  1,    0.2 },
    { 0,    0.8,  1 },
}

local SAVE_ALIVE    = 1
local SAVE_KILLS    = 2
local SAVE_DISTANCE = 4
local SAVE_ALL      = SAVE_ALIVE + SAVE_KILLS + SAVE_DISTANCE

local function EnsureStatsUi()
    if STATSTab and STATSTab.setVisible then return STATSTab end
    local x, y = LoadUi()
    STATSTab = STATSTabClass:new(x, y, 120, 160)
    STATSTab:addToUIManager()
    STATSTab:setVisible(true)
    if STATSTab.updatePositions then STATSTab:updatePositions() end
    return STATSTab
end

local function HasFlag(value, flag)
    return PZMath.floor(value / flag) % 2 ~= 0
end

local SaveDailyKillRecord
local ensureUniqueLogWithHeader
local UniqueCharacterLog

local function InitializeMod(playerNum, player)
    local localPlayer = getPlayer()
    if not localPlayer or not player or player ~= localPlayer then
        return
    end

    print("--------TWITCH STATS LOADED----------")

    -- Ensure UI
    if STATSTab and STATSTab.setVisible then
        STATSTab:setVisible(true)
    else
        local x, y = LoadUi()
        STATSTab = STATSTabClass:new(x, y, 120, 160)
        STATSTab:addToUIManager()
        STATSTab:setVisible(true)
        if STATSTab.updatePositions then STATSTab:updatePositions() end
    end

    local st = __ttfEnsureMPState(player)
    if not st then return end

    -- Ensure UniqueID exists (persisted)
    if not st.PersistentUniqueID or st.PersistentUniqueID == "" then
        local desc        = player:getDescriptor()
        local rawForename = desc and desc:getForename() or ""
        local rawSurname  = desc and desc:getSurname() or ""

        local function clean(s)
            if not s or s == "" then return nil end
            s = tostring(s):gsub("[%s\t]", "")
            if s == "" then return nil end
            return s
        end

        local forename = clean(rawForename)
        local surname  = clean(rawSurname)

        local parts    = {}
        if forename then table.insert(parts, forename) end
        if surname then table.insert(parts, surname) end
        if #parts == 0 then parts = { "Unknown" } end

        st.PersistentUniqueID = table.concat(parts, "_") .. "_" .. tostring(os.time())
    end

    TwisTonFireStats.UniquePlayerID = st.PersistentUniqueID

    -- Distance baseline (monotonic)
    local persisted                 = tonumber(st.distanceTracker) or 0
    local maxMark                   = tonumber(st.distanceMax) or 0
    local baseline                  = math.max(persisted, maxMark)
    if baseline < 0 or baseline ~= baseline then baseline = 0 end

    st.distanceTracker = baseline
    st.distanceMax     = baseline
    distanceTracker    = baseline

    local function __ttfCatchupDailyReset(player)
        local st = __ttfEnsureMPState(player)
        if not st then return end

        local curStamp = __ttfGetIngameDateStamp()
        local curKills = tonumber(player:getZombieKills()) or 0

        -- First ever init
        if st.killsAtMidnight == nil then
            st.killsAtMidnight = curKills
        end
        if not st.baselineDateStamp or st.baselineDateStamp == 0 then
            st.baselineDateStamp = curStamp
        end

        -- If a new in-game day started while the player was offline:
        if curStamp ~= st.baselineDateStamp then
            -- Only finalize yesterday if our "lastSeen" belongs to that baseline day
            if st.lastSeenDateStamp == st.baselineDateStamp then
                local base = tonumber(st.killsAtMidnight) or 0
                local endKills = tonumber(st.lastSeenKills) or curKills
                local dayKills = math.max(0, endKills - base)

                if dayKills > (tonumber(st.dailyKillRecord) or 0) then
                    st.dailyKillRecord = dayKills
                    local md = player:getModData()
                    if md then md["dailyKillRecord"] = dayKills end
                    SaveDailyKillRecord(player, dayKills)
                end

                -- Optional: write a row for the finished day
                -- (uses current formatting; good enough for MP-only)
                local md = player:getModData()
                if md then md.killsAtMidnight = base end
                UniqueCharacterLog(player)
            end

            -- Start the new day fresh from current kills
            st.killsAtMidnight = curKills
            st.baselineDateStamp = curStamp
        end

        -- Update lastSeen snapshot for next time
        st.lastSeenKills = curKills
        st.lastSeenDateStamp = curStamp

        local md = player:getModData()
        if md then
            md.killsAtMidnight = st.killsAtMidnight
            md["dailyKillRecord"] = st.dailyKillRecord
        end

        __ttfFlushMPState(player, true)
    end
    -- Daily-kill baseline
    if st.killsAtMidnight == nil then
        st.killsAtMidnight = tonumber(player:getZombieKills()) or 0
    end

    __ttfMirrorStateToModData(player)
    __ttfFlushMPState(player, true)
    __ttfCatchupDailyReset(player)

    -- Ensure per-character CSV exists (header)
    ensureUniqueLogWithHeader(player)
end
Events.OnCreatePlayer.Add(InitializeMod)

local function StopStatsUi()
    if STATSTab then
        SaveUi()
        STATSTab:setVisible(false)
    end
end

local killsAtMidnight = 0
local CHARACTER_DAILY_RECORD = "dailyKillRecord"

local function GetPlayerName(player)
    return player:getUsername() or player:getDisplayName() or "Unknown"
end

SaveDailyKillRecord = function(player, record)
    local writer = getFileWriter("daily_kill_record.txt", true, false)
    if writer then
        writer:write(tostring(record))
        writer:close()
    else
        print("Error: Could not write to daily_kill_record.txt (file handle nil).")
    end
end

ensureUniqueLogWithHeader = function(playerObj)
    ensureStatsFolder()

    local uniqueID = SetOrGetPersistentUniqueID(playerObj)
    if not uniqueID then return end

    local path = SAVE_DIR .. uniqueID .. ".txt"

    local reader = getFileReader(path, false)
    if reader then
        reader:close()
        return
    end

    local writer = getFileWriter(path, true, false) -- createIfNull=true, append=false
    if writer then
        writer:write("forename,surname,zkills,dailykills,averagekills,dayssurvived,date\n")
        writer:close()
    else
        print("Error: Could not write header to " .. path .. " (file handle nil).")
    end
end

UniqueCharacterLog = function(player)
    ensureStatsFolder()

    local uniqueID = SetOrGetPersistentUniqueID(player)
    if not uniqueID then return end

    local desc     = player:getDescriptor()
    local forename = desc and desc:getForename() or ""
    local surname  = desc and desc:getSurname() or ""

    -- Strip whitespace/tabs from names; allow empty fields
    local function cleanOrEmpty(s) return (s and s:gsub("[%s\t]", "")) or "" end
    forename            = cleanOrEmpty(forename)
    surname             = cleanOrEmpty(surname)

    local zkills        = player:getZombieKills()
    local hoursSurvived = player:getHoursSurvived() or 0
    local daysSurvived  = math.floor(hoursSurvived / 24)
    local date          = os.date("%Y-%m-%d")

    local modData       = player:getModData()
    local baseKills     = modData and modData.killsAtMidnight or 0
    local dailyKills    = zkills - baseKills
    local averageKills  = (daysSurvived > 0) and (zkills / daysSurvived) or 0

    local newLine       = string.format("%s,%s,%d,%d,%.2f,%d,%s",
        forename,
        surname,
        tonumber(zkills) or 0,
        tonumber(dailyKills) or 0,
        averageKills,
        daysSurvived,
        tostring(date)
    )

    local path          = SAVE_DIR .. uniqueID .. ".txt"
    local writer        = getFileWriter(path, true, true) -- createIfNull=true, append=true (safe)
    if writer then
        writer:write(newLine .. "\n")
        writer:close()
    else
        print("Error: Could not write to " .. path)
    end
end

local function ResetDailyKills()
    local player = getPlayer()
    if not player then return end

    local st = __ttfEnsureMPState(player)
    if not st then return end

    local curStamp = __ttfGetIngameDateStamp()
    local currentKills = tonumber(player:getZombieKills()) or 0

    if st.killsAtMidnight == nil then
        st.killsAtMidnight = currentKills
    end
    if not st.baselineDateStamp or st.baselineDateStamp == 0 then
        st.baselineDateStamp = curStamp
    end

    local baseKills = tonumber(st.killsAtMidnight) or 0
    local dailyKills = math.max(0, currentKills - baseKills)

    local md = player:getModData()
    if md then md.killsAtMidnight = baseKills end

    UniqueCharacterLog(player)

    local record = tonumber(st.dailyKillRecord) or 0
    if dailyKills > record then
        st.dailyKillRecord = dailyKills
        if md then md["dailyKillRecord"] = dailyKills end
        SaveDailyKillRecord(player, dailyKills)
    elseif md and md["dailyKillRecord"] == nil then
        md["dailyKillRecord"] = record
    end

    -- Start the new day baseline + keep MP catch-up in sync
    st.killsAtMidnight = currentKills
    st.baselineDateStamp = curStamp
    st.lastSeenKills = currentKills
    st.lastSeenDateStamp = curStamp

    if md then md.killsAtMidnight = currentKills end

    __ttfFlushMPState(player, true)
end
Events.EveryDays.Add(ResetDailyKills)

local function UpdateDistance(eventPlayer)
    local player = getPlayer()
    if not player then return end

    -- Only track the actively played character on this client
    if eventPlayer and eventPlayer ~= player then return end

    local st = __ttfEnsureMPState(player)
    if not st then return end

    local persisted = tonumber(st.distanceTracker) or 0
    local maxMark   = tonumber(st.distanceMax) or 0

    local floorVal  = math.max(persisted, maxMark)
    if distanceTracker < floorVal then distanceTracker = floorVal end

    local currentX = player:getX()
    local currentY = player:getY()

    if not lastPosition._init then
        lastPosition.x = currentX
        lastPosition.y = currentY
        lastPosition._init = true
        return
    end

    local dx       = currentX - lastPosition.x
    local dy       = currentY - lastPosition.y
    local d        = math.sqrt(dx * dx + dy * dy) or 0

    lastPosition.x = currentX
    lastPosition.y = currentY

    if d ~= d or d <= 0 then return end

    -- Clamp extreme corrections/teleports
    local inVehicle = player.getVehicle and player:getVehicle() ~= nil
    local MAX_STEP = inVehicle and 120.0 or 25.0
    if d > MAX_STEP then
        return
    end

    distanceTracker = distanceTracker + d

    local newVal = distanceTracker
    if newVal < floorVal then
        newVal = floorVal
        distanceTracker = floorVal
    end

    st.distanceTracker = newVal
    if newVal > maxMark then
        st.distanceMax = newVal
    end

    -- Mirror into modData for runtime/UI
    local md = player:getModData()
    if md then
        md.distanceTracker = st.distanceTracker
        md.distanceMax     = st.distanceMax
    end

    __ttfFlushMPState(player, false)
end
Events.OnPlayerUpdate.Add(UpdateDistance)

local function GetDistanceTraveled()
    if not distanceTracker then return 0, 0 end
    local km = math.floor(distanceTracker / 1000)
    local meters = math.floor(distanceTracker % 1000)
    return km, meters
end

local function getFatigueColor(fatigue)
    if fatigue < 0.15 then
        return 0.1, 0.5, 0.1
    elseif fatigue < 0.30 then
        return 0.2, 1, 0.2
    elseif fatigue < 0.50 then
        return 1, 1, 0
    elseif fatigue < 0.55 then
        return 1, 0.4, 0
    elseif fatigue < 0.60 then
        return 0.57, 0.27, 1
    else
        return 1, 0, 0
    end
end

local function getColorModeRGB(mode)
    mode = tonumber(mode)
    if not mode or not colorModes[mode] then
        print("Warning: Invalid colorMode: " .. tostring(mode) .. ". Resetting to 1.")
        return 1, 1, 1
    end
    local c = colorModes[mode]
    return c[1], c[2], c[3]
end

local function UpdateAlive()
    local player = getPlayer()
    if not player then return end

    __ttfUpdateLastSeenSnapshot(player)
    __ttfFlushMPState(player, false)

    SaveFiles(player, SAVE_ALIVE)
end
Events.EveryTenMinutes.Add(UpdateAlive)

local __TTF_LastSavedZKills = -1

local function UpdateZKill()
    local player = getPlayer()
    if not player then return end

    local zkills = tonumber(player:getZombieKills()) or 0
    if zkills == __TTF_LastSavedZKills then
        return
    end

    __TTF_LastSavedZKills = zkills

    __ttfUpdateLastSeenSnapshot(player)
    __ttfFlushMPState(player, false)

    SaveFiles(player, SAVE_KILLS)
end
Events.OnZombieDead.Add(UpdateZKill)

local function GetPlayerWeight(player)
    if not player or not player:getNutrition() then return 0 end
    return string.format("%.1f", player:getNutrition():getWeight())
end

local function getWeightColor(weight, colorMode)
    local w = tonumber(weight)
    if not w then
        return getColorModeRGB(colorMode)
    end
    if w <= 75 or w >= 85 then
        return 1, 0.2, 0.2
    elseif (w > 75 and w < 76.5) or (w > 83.5 and w < 85) then
        return 1, 0.85, 0
    elseif w >= 76 and w <= 84 then
        return getColorModeRGB(colorMode)
    end
    return getColorModeRGB(colorMode)
end

function SaveFiles(player, flag)
    -- swallow-all helper: open, write, close without ever throwing
    local function tryWrite(path, text, append)
        local ok, writer = pcall(getFileWriter, path, true, append == true)
        if not ok or not writer then
            return false
        end
        pcall(function()
            writer:write(tostring(text))
            if append == true then writer:write("\n") end
        end)
        pcall(function() writer:close() end)
        return true
    end

    if HasFlag(flag, SAVE_ALIVE) and player then
        local timeSurvived = player:getTimeSurvived()
        if timeSurvived then
            tryWrite("timealive.txt", tostring(timeSurvived), true)
        end
    end

    if HasFlag(flag, SAVE_KILLS) and player then
        local totalKills = player:getZombieKills()
        if totalKills then
            tryWrite("zkills.txt", tostring(totalKills), true)
        end
    end

    if HasFlag(flag, SAVE_DISTANCE) then
        local km, meters = GetDistanceTraveled()
        tryWrite("distance.txt", string.format("%d km %d m", km, meters), true)
    end

    if HasFlag(flag, SAVE_ALL) then
        -- even if PTraits fails, never bubble
        pcall(PTraits)
    end
end

function PTraits()
    local player = getPlayer()
    if not player then return end

    local traits = nil
    local mode = "none"

    -- Build 42.13+ path: CharacterTraits -> getKnownTraits()
    if player.getCharacterTraits then
        local okCT, ct = pcall(function() return player:getCharacterTraits() end)
        if okCT and ct and ct.getKnownTraits then
            local okKT, list = pcall(function() return ct:getKnownTraits() end)
            if okKT and list then
                traits = list
                mode = "characterTraits"
            end
        end
    end

    -- Legacy fallback (older builds / edge cases)
    if not traits and player.getTraits then
        local okOld, oldTraits = pcall(function() return player:getTraits() end)
        if okOld and oldTraits then
            traits = oldTraits
            mode = "legacyTraits"
        end
    end

    if not traits then return end

    local okW, writer = pcall(getFileWriter, "PlayerTraits.txt", true, false)
    if not okW or not writer then return end

    local function safeClose()
        pcall(function() writer:close() end)
    end

    local function tryGetText(key)
        if getTextOrNull then return getTextOrNull(key) end
        return nil
    end

    local function stripNamespace(id)
        id = tostring(id or "")
        id = id:gsub("^%s*", ""):gsub("%s*$", "")
        id = id:gsub("^[^:]+:", "")    -- "Base:insomniac" -> "insomniac"
        id = id:match("[^%.]+$") or id -- "Base.Insomniac" -> "Insomniac"
        return id
    end

    local function humanize(id)
        id = stripNamespace(id)
        id = id:gsub("_", " ")
        id = id:gsub("(%l)(%u)", "%1 %2")
        id = id:gsub("^%s*", ""):gsub("%s*$", "")
        id = id:lower():gsub("^%l", string.upper)
        return id
    end

    local function _pcallRet(fn, selfObj)
        local ok, v = pcall(fn, selfObj)
        if ok then return v end
        return nil
    end

    local function resolveOccupationLabel()
        local desc = (player.getDescriptor and _pcallRet(player.getDescriptor, player)) or nil
        if not desc then return "Unknown" end

        -- Build 42.13+ path: CharacterProfession -> CharacterProfessionDefinition (localized label)
        if desc.getCharacterProfession then
            local cp = _pcallRet(desc.getCharacterProfession, desc)
            if cp then
                if CharacterProfessionDefinition and CharacterProfessionDefinition.getCharacterProfessionDefinition then
                    local ok, def = pcall(function()
                        return CharacterProfessionDefinition.getCharacterProfessionDefinition(cp)
                    end)
                    if ok and def then
                        local lbl = nil
                        if def.getLabel then lbl = _pcallRet(def.getLabel, def) end
                        if (not lbl or lbl == "") and def.getUIName then lbl = _pcallRet(def.getUIName, def) end
                        if (not lbl or lbl == "") and def.getName then lbl = _pcallRet(def.getName, def) end
                        if lbl and lbl ~= "" then
                            return tostring(lbl)
                        end

                        -- If we couldn't get a label, try resolving by id/type
                        local id = nil
                        if def.getType then id = _pcallRet(def.getType, def) end
                        if (not id or id == "") and def.getId then id = _pcallRet(def.getId, def) end
                        if id and id ~= "" then
                            local sid = stripNamespace(tostring(id))
                            local t = tryGetText("UI_profession_" .. sid)
                            if t and t ~= "" then return tostring(t) end
                            return humanize(tostring(id))
                        end
                    end
                end

                -- Last resort: translate enum/string form
                local raw = tostring(cp)
                local sid = stripNamespace(raw)
                local keys = {
                    "UI_profession_" .. sid,
                    "UI_prof_" .. sid,
                    "IGUI_profession_" .. sid,
                    "UI_professionname_" .. sid,
                }
                for _, k in ipairs(keys) do
                    local t = tryGetText(k)
                    if t and t ~= "" then return tostring(t) end
                end
                return humanize(raw)
            end
        end

        -- Legacy path (pre-42.13)
        local prof = nil
        if desc.getProfession then
            prof = _pcallRet(desc.getProfession, desc)
        end
        if not prof and desc.getProfessionName then
            prof = _pcallRet(desc.getProfessionName, desc)
        end

        if not prof then return "Unemployed" end

        local label = nil
        if type(prof) == "userdata" then
            if prof.getLabel then label = _pcallRet(prof.getLabel, prof) end
            if (not label or label == "") and prof.getUIName then label = _pcallRet(prof.getUIName, prof) end
            if (not label or label == "") and prof.getName then label = _pcallRet(prof.getName, prof) end
            if (not label or label == "") and prof.getType then label = _pcallRet(prof.getType, prof) end
        end

        if not label or label == "" then
            label = tostring(prof)
        end

        label = tostring(label or "")
        if label == "" then return "Unemployed" end

        local sid = stripNamespace(label)
        local keys = {
            "UI_profession_" .. sid,
            "UI_prof_" .. sid,
            "IGUI_profession_" .. sid,
            "UI_professionname_" .. sid,
        }
        for _, k in ipairs(keys) do
            local t = tryGetText(k)
            if t and t ~= "" then
                return tostring(t)
            end
        end

        return humanize(label)
    end

    local function pascalFromSnake(id)
        id = stripNamespace(id):lower()
        local out = {}
        for part in id:gmatch("[^_]+") do
            out[#out + 1] = part:sub(1, 1):upper() .. part:sub(2)
        end
        return table.concat(out, "")
    end

    local function snakeFromPascal(id)
        id = stripNamespace(id)
        local s = id:gsub("(%l)(%u)", "%1_%2")
        return s:lower()
    end

    local function resolveLabelLegacy(rawId)
        if not rawId or rawId == "" then return nil end

        local ids = {
            tostring(rawId),
            stripNamespace(rawId),
            pascalFromSnake(rawId),
            snakeFromPascal(rawId),
        }

        if TraitFactory and TraitFactory.getTrait then
            for _, id in ipairs(ids) do
                local ok, traitObj = pcall(function() return TraitFactory.getTrait(id) end)
                if ok and traitObj then
                    local ok2, label = pcall(function()
                        if traitObj.getLabel then return traitObj:getLabel() end
                        if traitObj.getDisplayName then return traitObj:getDisplayName() end
                        return nil
                    end)
                    if ok2 and label and label ~= "" then
                        return tostring(label)
                    end
                end
            end
        end

        for _, id in ipairs(ids) do
            local key = "UI_trait_" .. stripNamespace(id)
            local txt = tryGetText(key)
            if txt and txt ~= "" then return txt end
        end

        return humanize(tostring(rawId))
    end

    local function resolveLabelCharacterTrait(trait)
        if not trait then return nil end

        if CharacterTraitDefinition and CharacterTraitDefinition.getCharacterTraitDefinition then
            local okDef, def = pcall(CharacterTraitDefinition.getCharacterTraitDefinition, trait)
            if okDef and def and def.getLabel then
                local okLb, lb = pcall(def.getLabel, def)
                if okLb and lb and lb ~= "" then
                    return tostring(lb)
                end
            end
        end

        if trait.getName then
            local okNm, nm = pcall(trait.getName, trait)
            if okNm and nm and nm ~= "" then
                return humanize(tostring(nm))
            end
        end

        return humanize(tostring(trait))
    end

    local collected = {}

    if traits.size and traits.get then
        local n = traits:size()
        for i = 0, n - 1 do
            local t = traits:get(i)
            if t then
                if mode == "characterTraits" then
                    local label = resolveLabelCharacterTrait(t)
                    if label and label ~= "" then
                        collected[#collected + 1] = label
                    end
                else
                    local label = resolveLabelLegacy(tostring(t))
                    if label and label ~= "" then
                        collected[#collected + 1] = label
                    end
                end
            end
        end
    else
        collected[#collected + 1] = humanize(tostring(traits))
    end

    local occupationLabel = resolveOccupationLabel()

    pcall(function()
        writer:write("Occupation: " .. tostring(occupationLabel) .. " || Live Traits: ")
        local seen = {}
        for _, label in ipairs(collected) do
            local key = tostring(label):lower()
            if key ~= "" and not seen[key] then
                seen[key] = true
                writer:write(tostring(label) .. " | ")
            end
        end
        writer:write("\n")
    end)

    safeClose()
end

--########################## Interface ################################
-- Initializes, Render and Events
function STATSTabClass:initialise()
    ISPanel.initialise(self)

    -- Read user settings only (Lua path). No mod-folder usage.
    local settingsReader = getFileReader("TWSTATSsettings.txt", false)
    if settingsReader then
        self.showCalendar      = settingsReader:readLine() == "true"
        self.showKills         = settingsReader:readLine() == "true"
        self.showTraveled      = settingsReader:readLine() == "true"
        self.showWeight        = settingsReader:readLine() == "true"
        self.showDailyKills    = settingsReader:readLine() == "true"
        self.showAvgKills      = settingsReader:readLine() == "true"

        local colorModeLine    = settingsReader:readLine()
        local fontSizeLine     = settingsReader:readLine()
        local alignLine        = settingsReader:readLine()
        local calendarModeLine = settingsReader:readLine()
        settingsReader:close()

        self.colorMode     = tonumber(colorModeLine)
        self.fontSizeMode  = tonumber(fontSizeLine)
        self.alignmentMode = (alignLine == "right") and "right" or (alignLine == "left" and "left" or nil)
        self.calendarMode  = tonumber(calendarModeLine)
    end

    -- Script defaults (your chosen standards), used if file missing or values invalid
    if self.showCalendar == nil then self.showCalendar = true end
    if self.showKills == nil then self.showKills = true end
    if self.showTraveled == nil then self.showTraveled = true end
    if self.showWeight == nil then self.showWeight = true end
    if self.showDailyKills == nil then self.showDailyKills = true end
    if self.showAvgKills == nil then self.showAvgKills = true end

    if type(self.colorMode) ~= "number" then self.colorMode = 2 end
    if type(self.fontSizeMode) ~= "number" then self.fontSizeMode = 1 end
    if self.alignmentMode ~= "right" and self.alignmentMode ~= "left" then
        self.alignmentMode = "left"
    end
    if type(self.calendarMode) ~= "number" then self.calendarMode = 1 end

    -- Panel internals
    self.positions = {
        calendar   = -15,
        kills      = 25,
        traveled   = 65,
        weight     = 105,
        dailyKills = 145,
        avgKills   = 185,
    }
    self.lastCalendarWidth = 120

    -- Safe call; will early-return if UI not yet fully ready.
    if self.updatePositions then self:updatePositions() end
end

function STATSTabClass:new(x, y, w, h)
    local stats = ISPanel:new(x, y, w, h)
    setmetatable(stats, self)
    self.__index = self
    stats.background = false
    stats.moveWithMouse = true
    stats.lastCalendarWidth = 120
    stats:initialise()
    return stats
end

local function drawTextCenteredVertical(ui, text, x, y, w, h, r, g, b, a, font, alignRight)
    local fontHeight = getTextManager():getFontHeight(font)
    local textY = y + (h - fontHeight) / 2
    if alignRight then
        ui:drawTextRight(text, x + w, textY, r, g, b, a, font)
    else
        ui:drawText(text, x, textY, r, g, b, a, font)
    end
end

function STATSTabClass:render()
    local player = getPlayer()
    if not player then return end

    if not self.positions then
        print("ERROR: positions is nil in render!")
        return
    end

    -- Robust font height here as well
    local font       = getFontForStats(self.fontSizeMode or 1)
    local tm         = getTextManager()
    local fontHeight = 24
    if tm and tm.getFontHeight and font then
        local fh = tm:getFontHeight(font)
        fh = tonumber(fh) or 24
        if fh > 0 then fontHeight = fh end
    end

    -- ModOptions (default ON)
    local showFatigueIndicator = true
    local showWeightIndicator  = true

    if TTF_StatsOptions then
        if TTF_StatsOptions.IsFatigueIndicatorEnabled then
            showFatigueIndicator = (TTF_StatsOptions.IsFatigueIndicatorEnabled() == true)
        end
        if TTF_StatsOptions.IsWeightIndicatorEnabled then
            showWeightIndicator = (TTF_StatsOptions.IsWeightIndicatorEnabled() == true)
        end
    end

    local boxHeight      = fontHeight + 10
    local iconSize       = math.max(20, math.min(math.floor(fontHeight * 1.25), 68))
    local iconTextGap    = math.floor(iconSize * 0.10)
    local iconX          = (self.alignmentMode == "right") and (self:getWidth() - iconSize) or 0
    local padding_stats  = 1
    local textAlignRight = (self.alignmentMode == "right")

    -- (…keep the **rest** of your existing render() body exactly as-is…)
    -- Everything below is unchanged in your file; no logic changes required.
    -- ─────────────────────────────────────────────────────────────────────
    -- === showCalendar ===
    if self.showCalendar then
        local iconY = self.positions.calendar
        local boxY  = iconY + (iconSize - boxHeight) / 2

        local text  = ""
        if self.calendarMode == 1 then
            text = player:getTimeSurvived()
        else
            local hours = math.floor(player:getHoursSurvived() or 0)
            local totalDays = math.floor(hours / 24)
            local years = math.floor(totalDays / 360)
            local daysInYear = totalDays % 360
            local months = math.floor(daysInYear / 30)
            local days = daysInYear % 30
            local remainingHours = hours % 24

            text = ""
            if years > 0 then text = text .. years .. getText("UI_TWIST_STATS_YEAR") .. ", " end
            if months > 0 or years > 0 then text = text .. months .. getText("UI_TWIST_STATS_MONTH") .. ", " end
            if days > 0 or months > 0 or years > 0 then text = text .. days .. getText("UI_TWIST_STATS_DAYS") .. ", " end
            text = text .. remainingHours .. getText("UI_TWIST_STATS_HOURS")
        end

        local textWidth = getTextManager():MeasureStringX(font, text) + padding_stats
        local textX, boxX
        if textAlignRight then
            textX = iconX - iconTextGap - textWidth
            boxX  = textX
        else
            textX = iconX + iconSize + iconTextGap
            boxX  = textX
        end

        local r, g, b = getColorModeRGB(self.colorMode)

        self:drawTextureScaled(calendarTexture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
        self:drawRect(boxX, boxY, textWidth, boxHeight, 0.6, 0, 0, 0)
        drawTextCenteredVertical(self, text, textX, boxY, textWidth, boxHeight, r, g, b, 1, font, textAlignRight)
    end

    -- === showKills ===
    if self.showKills then
        local iconY      = self.positions.kills
        local boxY       = iconY + (iconSize - boxHeight) / 2

        local totalKills = player:getZombieKills()
        local text       = tostring(totalKills)
        local textWidth  = getTextManager():MeasureStringX(font, text) + padding_stats


        local textAlignRight = false
        local textX, boxX

        if self.alignmentMode == "right" then
            textAlignRight = true

            textX          = iconX - iconTextGap - textWidth
            boxX           = textX
        else
            textX = iconX + iconSize + iconTextGap
            boxX  = textX
        end

        local r, g, b = getColorModeRGB(self.colorMode)


        self:drawTextureScaled(zedsKillsTexture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
        self:drawRect(boxX, boxY, textWidth, boxHeight, 0.6, 0, 0, 0)
        drawTextCenteredVertical(self, text, textX, boxY, textWidth, boxHeight, r, g, b, 1, font, textAlignRight)
    end

    -- === showTraveled ===
    if self.showTraveled then
        local iconY      = self.positions.traveled
        local boxY       = iconY + (iconSize - boxHeight) / 2

        local km, meters = GetDistanceTraveled()
        local text       = string.format("%d km %d m", km, meters)
        local textWidth  = getTextManager():MeasureStringX(font, text) + padding_stats

        local fatigue = 0

        if player and player.getStats then
            local stats = player:getStats()
            if stats then
                -- Build 42.13.2+ (new Stats API)
                local ok, v = pcall(function()
                    if stats.get and CharacterStat and CharacterStat.FATIGUE then
                        return stats:get(CharacterStat.FATIGUE)
                    end
                    if stats.get and CharacterStat and CharacterStat["FATIGUE"] then
                        return stats:get(CharacterStat["FATIGUE"])
                    end
                    return nil
                end)

                if ok and v ~= nil then
                    fatigue = tonumber(v) or 0
                elseif stats.getFatigue then
                    -- Older builds fallback
                    fatigue = tonumber(stats:getFatigue()) or 0
                end
            end
        end

        if fatigue < 0 then fatigue = 0 end
        if fatigue > 1 then fatigue = 1 end

        local r, g, b = getFatigueColor(fatigue)
        local rText, gText, bText = getColorModeRGB(self.colorMode)

        local indicatorSize = math.floor(iconSize / 3)
        local textAlignRight = false
        local textX, boxX, indicatorX

        if self.alignmentMode == "right" then
            textAlignRight = true
            textX = iconX - iconTextGap - textWidth
            boxX = textX
            indicatorX = textX - iconTextGap - indicatorSize
        else
            textX = iconX + iconSize + iconTextGap
            boxX = textX
            indicatorX = textX + textWidth + iconTextGap
        end
        local indicatorY = boxY + (boxHeight - indicatorSize) / 2

        self:drawTextureScaled(traveledTexture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
        self:drawRect(boxX, boxY, textWidth, boxHeight, 0.6, 0, 0, 0)
        drawTextCenteredVertical(self, text, textX, boxY, textWidth, boxHeight, rText, gText, bText, 1, font,
            textAlignRight)
        if showFatigueIndicator then
            self:drawRect(indicatorX, indicatorY, indicatorSize, indicatorSize, 1, r, g, b)
        end
    end

    -- === showWeight ===
    if self.showWeight then
        local iconY            = self.positions.weight
        local boxY             = iconY + (iconSize - boxHeight) / 2

        local nutrition        = player:getNutrition()
        local weight           = GetPlayerWeight(player)
        local calories         = nutrition and nutrition:getCalories() or 0
        local text             = weight .. " kg"
        local textWidth        = getTextManager():MeasureStringX(font, text) + padding_stats

        local indicatorTexture = nil
        if calories < -2000 then
            indicatorTexture = indicatorLowLowTexture
        elseif calories < -1000 then
            indicatorTexture = indicatorLowTexture
        elseif calories > 3000 then
            indicatorTexture = indicatorHighHighTexture
        elseif calories > 2000 then
            indicatorTexture = indicatorHighTexture
        end
        if not showWeightIndicator then
            indicatorTexture = nil
        end
        local indicatorSize = math.floor(iconSize / 2)
        local iconWidth = indicatorTexture and (indicatorSize + iconTextGap) or 0

        local textAlignRight = false
        local textX, boxX, indicatorX
        local rectWidth = textWidth + (indicatorTexture and iconWidth or 0)

        if self.alignmentMode == "right" then
            textAlignRight = true
            if indicatorTexture then
                boxX = (iconX - iconTextGap - textWidth) - (iconTextGap + indicatorSize)
                indicatorX = boxX
                textX = boxX + iconWidth
            else
                boxX = iconX - iconTextGap - textWidth
                textX = boxX
            end
        else
            textX = iconX + iconSize + iconTextGap
            boxX = textX
            if indicatorTexture then
                indicatorX = textX + textWidth + iconTextGap
            end
        end

        local indicatorY = boxY + (boxHeight - indicatorSize) / 2

        self:drawTextureScaled(weightTexture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
        self:drawRect(boxX, boxY, rectWidth, boxHeight, 0.6, 0, 0, 0)
        local r, g, b = getWeightColor(weight, self.colorMode)
        drawTextCenteredVertical(self, text, textX, boxY, textWidth, boxHeight, r, g, b, 1, font, textAlignRight)

        if indicatorTexture then
            self:drawTextureScaled(indicatorTexture, indicatorX, indicatorY, indicatorSize, indicatorSize, 1, 1, 1, 1)
        end
    end

    -- === showDailyKills ===
    if self.showDailyKills then
        local iconY          = self.positions.dailyKills
        local boxY           = iconY + (iconSize - boxHeight) / 2

        local currentKills   = player:getZombieKills()
        local modData        = player:getModData()
        local baseKills      = modData and modData.killsAtMidnight or 0
        local dailyKills     = currentKills - baseKills

        local dailyText      = getText("UI_TWIST_STATS_DAILY_UI_ELEMENT") .. tostring(dailyKills)
        local textWidth      = getTextManager():MeasureStringX(font, dailyText) + padding_stats
        local r, g, b        = getColorModeRGB(self.colorMode)

        local textAlignRight = false
        local textX, boxX

        if self.alignmentMode == "right" then
            textAlignRight = true
            textX          = iconX - iconTextGap - textWidth
            boxX           = textX
        else
            textX = iconX + iconSize + iconTextGap
            boxX  = textX
        end

        self:drawTextureScaled(dailyTexture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
        self:drawRect(boxX, boxY, textWidth, boxHeight, 0.6, 0, 0, 0)
        drawTextCenteredVertical(self, dailyText, textX, boxY, textWidth, boxHeight, r, g, b, 1, font, textAlignRight)
    end

    -- === showAvgKills ===
    if self.showAvgKills then
        local iconY          = self.positions.avgKills
        local boxY           = iconY + (iconSize - boxHeight) / 2

        local totalKills     = player:getZombieKills()
        local daysSurvived   = player:getHoursSurvived() / 24
        local avgKills       = (daysSurvived > 0) and string.format("%.1f", totalKills / daysSurvived) or "0.0"

        local avgText        = getText("UI_TWIST_STATS_AVERAGE_UI_ELEMENT_1") ..
            avgKills .. getText("UI_TWIST_STATS_AVERAGE_UI_ELEMENT_2")
        local textWidth      = getTextManager():MeasureStringX(font, avgText) + padding_stats
        local r, g, b        = getColorModeRGB(self.colorMode)

        local textAlignRight = false
        local textX, boxX

        if self.alignmentMode == "right" then
            textAlignRight = true
            textX          = iconX - iconTextGap - textWidth
            boxX           = textX
        else
            textX = iconX + iconSize + iconTextGap
            boxX  = textX
        end

        self:drawTextureScaled(avgTexture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
        self:drawRect(boxX, boxY, textWidth, boxHeight, 0.6, 0, 0, 0)
        drawTextCenteredVertical(self, avgText, textX, boxY, textWidth, boxHeight, r, g, b, 1, font, textAlignRight)
    end

    -- === Autosave as usual ===
    local currentTime = getTimestamp()
    if currentTime > nextInterval then
        SaveFiles(player, SAVE_ALL)
        nextInterval = currentTime + (saveInterval * 60)
    end
end

function STATSTabClass:onMouseDoubleClick(x, y)
    self.colorMode = self.colorMode + 1
    if self.colorMode > #colorModes then
        self.colorMode = 1
    end
    SaveUi()
end

function STATSTabClass:updatePositions()
    -- Hard guard: if the panel isn’t fully formed yet, bail once.
    if type(self.getX) ~= "function" then
        print("[TWF][Stats] getX missing on UI element – aborting updatePositions() once.")
        return
    end

    -- Robust font height: never nil / <= 0
    local font       = getFontForStats(self.fontSizeMode or 1)
    local tm         = getTextManager()
    local fontHeight = 24
    if tm and tm.getFontHeight and font then
        local fh = tm:getFontHeight(font)
        fh = tonumber(fh) or 24
        if fh > 0 then fontHeight = fh end
    end

    local iconSize     = math.max(18, math.min(math.floor(fontHeight * 1.25), 68))
    local iconTextGap  = math.max(4, math.floor(iconSize * 0.10))
    local minWidth     = 60
    local maxTextWidth = 0

    local player       = getPlayer()

    -- Calendar line width (compute text even if hidden so panel keeps a sane min width)
    local calendarText = ""
    if player then
        if self.calendarMode == 1 then
            calendarText = player:getTimeSurvived()
        elseif self.calendarMode == 2 then
            calendarText = os.date("%Y-%m-%d")
        else
            local h      = math.floor((player:getHoursSurvived() or 0))
            local days   = math.floor(h / 24)
            local hours  = h % 24
            calendarText = getText("UI_TWIST_STATS_ALIVE_DAYS", tostring(days), tostring(hours))
        end
    else
        calendarText = getText("UI_TWIST_STATS_ALIVE_DAYS", "0", "0")
    end

    local calWidth = iconSize + iconTextGap + getTextManager():MeasureStringX(font, calendarText) + 14
    if self.showCalendar then
        if calWidth > maxTextWidth then maxTextWidth = calWidth end
        self.lastCalendarWidth = calWidth
    end

    -- Kills
    if self.showKills and player then
        local text = tostring(player:getZombieKills() or 0)
        local w = iconSize + iconTextGap + getTextManager():MeasureStringX(font, text) + 14
        if w > maxTextWidth then maxTextWidth = w end
    end

    -- Distance
    if self.showTraveled and player then
        local km, meters = GetDistanceTraveled()
        local text = string.format("%d km %d m", km or 0, meters or 0)
        local w = iconSize + iconTextGap + getTextManager():MeasureStringX(font, text) + 34
        if w > maxTextWidth then maxTextWidth = w end
    end

    -- Weight
    if self.showWeight and player then
        local text = tostring(GetPlayerWeight(player) or "0.0") .. " kg"
        local w = iconSize + iconTextGap + getTextManager():MeasureStringX(font, text) + 34
        if w > maxTextWidth then maxTextWidth = w end
    end

    -- Daily kills
    if self.showDailyKills and player then
        local md   = player:getModData()
        local base = (md and md.killsAtMidnight) or 0
        local dk   = (player:getZombieKills() or 0) - base
        local text = getText("UI_TWIST_STATS_DAILY_UI_ELEMENT") .. tostring(dk)
        local w    = iconSize + iconTextGap + getTextManager():MeasureStringX(font, text) + 14
        if w > maxTextWidth then maxTextWidth = w end
    end

    -- Average kills
    if self.showAvgKills and player then
        local total = player:getZombieKills() or 0
        local days  = (player:getHoursSurvived() or 0) / 24
        local avg   = (days > 0) and string.format("%.1f", total / days) or "0.0"
        local text  = getText("UI_TWIST_STATS_AVERAGE_UI_ELEMENT_1") ..
            avg .. getText("UI_TWIST_STATS_AVERAGE_UI_ELEMENT_2")
        local w     = iconSize + iconTextGap + getTextManager():MeasureStringX(font, text) + 14
        if w > maxTextWidth then maxTextWidth = w end
    end

    -- Keep last calendar width if everything is hidden
    if not (self.showCalendar or self.showKills or self.showTraveled or self.showWeight or self.showDailyKills or self.showAvgKills) then
        maxTextWidth = self.lastCalendarWidth or maxTextWidth
    end

    -- Width: single safe call
    local finalWidth = tonumber(math.max(minWidth, maxTextWidth)) or minWidth
    self:setWidth(finalWidth)

    -- Alignment
    if self.alignmentMode == "right" then
        local rightX = self.savedRightX or (self:getX() + self:getWidth())
        self:setX(rightX - self:getWidth())
    else
        local leftX = self.savedLeftX or self:getX()
        self:setX(leftX)
    end

    -- Vertical layout
    local boxHeight  = fontHeight + 10
    local minSpacing = math.max(2, math.floor(fontHeight * 0.10))
    local step       = math.max(boxHeight + minSpacing, iconSize + 2)
    local y          = -7
    local visible    = 0

    if self.showCalendar then
        self.positions.calendar = y; y = y + step; visible = visible + 1
    end
    if self.showKills then
        self.positions.kills = y; y = y + step; visible = visible + 1
    end
    if self.showTraveled then
        self.positions.traveled = y; y = y + step; visible = visible + 1
    end
    if self.showWeight then
        self.positions.weight = y; y = y + step; visible = visible + 1
    end
    if self.showDailyKills then
        self.positions.dailyKills = y; y = y + step; visible = visible + 1
    end
    if self.showAvgKills then
        self.positions.avgKills = y; y = y + step; visible = visible + 1
    end

    self:setHeight((visible * step) + 10)
end

function STATSTabClass:onMouseUp(x, y)
    ISPanel.onMouseUp(self, x, y)
    if self.alignmentMode == "right" then
        self.savedRightX = self:getX() + self:getWidth()
    else
        self.savedLeftX = self:getX()
    end
    SaveUi()
end

local randomMessages = {
    "UI_TWIST_RANDOM_MESSAGE1",
    "UI_TWIST_RANDOM_MESSAGE2",
    "UI_TWIST_RANDOM_MESSAGE3"
}

local function ensureAtLeastOneStatVisible(target)
    if not (target.showCalendar or target.showKills or target.showTraveled or target.showWeight or target.showDailyKills or target.showAvgKills) then
        target.showKills = true
        if getPlayer() then
            local idx = ZombRand(#randomMessages) + 1
            getPlayer():Say(getText(randomMessages[idx]))
        end
    end
end

function STATSTabClass:onRightMouseUp(x, y)
    if not self:isMouseOver() then return end
    local context = ISContextMenu.get(0, getMouseX(), getMouseY())

    local chartTexture = getTexture("media/ui/stats.png")
    local chartOption = context:addOption(getText("UI_TWIST_STATS_OPEN_CHART"), self, function()
        require "TwisTonFireStats_Chart"
        if TwisTonFireStats_Chart and TwisTonFireStats_Chart.toggle then
            TwisTonFireStats_Chart.toggle()
        end
    end)
    chartOption.iconTexture = chartTexture

    -- === existing entries ===
    local calendarOption = context:addOption(getText("UI_TWIST_STATS_TIMEALIVE"), nil)
    calendarOption.iconTexture = calendarTexture
    local subContext = ISContextMenu:getNew(context)
    context:addSubMenu(calendarOption, subContext)

    subContext:addOption(self.showCalendar and getText("UI_TWIST_STATS_HIDE") or getText("UI_TWIST_STATS_SHOW"), self,
        function(target)
            target.showCalendar = not target.showCalendar
            ensureAtLeastOneStatVisible(target)
            target:updatePositions()
            SaveUi()
        end)

    if self.showCalendar then
        subContext:addOption(getText("UI_TWIST_STATS_SWITCHCALENDAR"), self, function(target)
            target.calendarMode = (target.calendarMode == 1) and 2 or 1
            target:updatePositions()
            SaveUi()
        end)
    end

    local killsOption = context:addOption(getText("UI_TWIST_STATS_ZOMBIEKILLS"), nil)
    killsOption.iconTexture = zedsKillsTexture
    subContext = ISContextMenu:getNew(context)
    context:addSubMenu(killsOption, subContext)
    subContext:addOption(self.showKills and getText("UI_TWIST_STATS_HIDE") or getText("UI_TWIST_STATS_SHOW"), self,
        function(target)
            target.showKills = not target.showKills
            ensureAtLeastOneStatVisible(target)
            target:updatePositions()
            SaveUi()
        end)

    local traveledOption = context:addOption(getText("UI_TWIST_STATS_TRAVELED"), nil)
    traveledOption.iconTexture = traveledTexture
    subContext = ISContextMenu:getNew(context)
    context:addSubMenu(traveledOption, subContext)
    subContext:addOption(self.showTraveled and getText("UI_TWIST_STATS_HIDE") or getText("UI_TWIST_STATS_SHOW"), self,
        function(target)
            target.showTraveled = not target.showTraveled
            ensureAtLeastOneStatVisible(target)
            target:updatePositions()
            SaveUi()
        end)

    local weightOption = context:addOption(getText("UI_TWIST_STATS_WEIGHT"), nil)
    weightOption.iconTexture = weightTexture
    subContext = ISContextMenu:getNew(context)
    context:addSubMenu(weightOption, subContext)
    subContext:addOption(self.showWeight and getText("UI_TWIST_STATS_HIDE") or getText("UI_TWIST_STATS_SHOW"), self,
        function(target)
            target.showWeight = not target.showWeight
            ensureAtLeastOneStatVisible(target)
            target:updatePositions()
            SaveUi()
        end)

    local dailyOption = context:addOption(getText("UI_TWIST_STATS_DAILYKILLS"), nil)
    dailyOption.iconTexture = dailyTexture
    subContext = ISContextMenu:getNew(context)
    context:addSubMenu(dailyOption, subContext)
    subContext:addOption(self.showDailyKills and getText("UI_TWIST_STATS_HIDE") or getText("UI_TWIST_STATS_SHOW"), self,
        function(target)
            target.showDailyKills = not target.showDailyKills
            ensureAtLeastOneStatVisible(target)
            target:updatePositions()
            SaveUi()
        end)

    local averageOption = context:addOption(getText("UI_TWIST_STATS_AVERAGE"), nil)
    averageOption.iconTexture = avgTexture
    subContext = ISContextMenu:getNew(context)
    context:addSubMenu(averageOption, subContext)
    subContext:addOption(self.showAvgKills and getText("UI_TWIST_STATS_HIDE") or getText("UI_TWIST_STATS_SHOW"), self,
        function(target)
            target.showAvgKills = not target.showAvgKills
            ensureAtLeastOneStatVisible(target)
            target:updatePositions()
            SaveUi()
        end)

    local fontOption = context:addOption(getText("UI_TWIST_STATS_FONTSIZE"), nil)
    fontOption.iconTexture = fontTexture
    local fontSubMenu = ISContextMenu:getNew(context)
    context:addSubMenu(fontOption, fontSubMenu)

    fontSubMenu:addOption(getText("UI_TWIST_STATS_LARGE"), self, function(target)
        target.fontSizeMode = 1
        target:updatePositions()
        SaveUi()
    end)
    fontSubMenu:addOption(getText("UI_TWIST_STATS_MEDIUM"), self, function(target)
        target.fontSizeMode = 2
        target:updatePositions()
        SaveUi()
    end)
    fontSubMenu:addOption(getText("UI_TWIST_STATS_SMALL"), self, function(target)
        target.fontSizeMode = 3
        target:updatePositions()
        SaveUi()
    end)

    local alignOption = context:addOption(getText("UI_TWIST_STATS_ALIGNMENT"), nil)
    alignOption.iconTexture = alignTexture
    local alignSubMenu = ISContextMenu:getNew(context)
    context:addSubMenu(alignOption, alignSubMenu)

    if self.alignmentMode == "right" then
        alignSubMenu:addOption(getText("UI_TWIST_STATS_ALIGN_LEFT"), self, function(target)
            local leftEdge = target:getX()
            target.alignmentMode = "left"
            target:updatePositions()
            target:setX(leftEdge)
            SaveUi()
        end)
    else
        alignSubMenu:addOption(getText("UI_TWIST_STATS_ALIGN_RIGHT"), self, function(target)
            local rightEdge = target:getX() + target:getWidth()
            target.alignmentMode = "right"
            target:updatePositions()
            target:setX(rightEdge - target:getWidth())
            SaveUi()
        end)
    end
end

------------------------- Load/Save Interface Positions -----------------------------
function SaveUi()
    if not STATSTab then return end
    local x = STATSTab:getX()
    local y = STATSTab:getY()
    if STATSTab.alignmentMode == "right" then
        x = x + STATSTab:getWidth()
    end
    print("Saving UI position (Lua path): ", x, y)

    -- Write to user/Lua path so it persists across mod updates
    local writer = getFileWriter("TWSTATSpos.txt", true, false) -- create=true, append=false
    if not writer then
        print("Error: Could not open Lua writer for TWSTATSpos.txt")
        return
    end
    writer:write(tostring(x) .. "\n" .. tostring(y) .. "\n")
    writer:close()

    -- keep writing settings to Lua path (already correct)
    local settingsWriter = getFileWriter("TWSTATSsettings.txt", true, false)
    if settingsWriter then
        settingsWriter:write(tostring(STATSTab.showCalendar) .. "\n")
        settingsWriter:write(tostring(STATSTab.showKills) .. "\n")
        settingsWriter:write(tostring(STATSTab.showTraveled) .. "\n")
        settingsWriter:write(tostring(STATSTab.showWeight) .. "\n")
        settingsWriter:write(tostring(STATSTab.showDailyKills) .. "\n")
        settingsWriter:write(tostring(STATSTab.showAvgKills) .. "\n")
        settingsWriter:write(tostring(STATSTab.colorMode) .. "\n")
        settingsWriter:write(tostring(STATSTab.fontSizeMode or 1) .. "\n")
        settingsWriter:write(tostring(STATSTab.alignmentMode or "left") .. "\n")
        settingsWriter:write(tostring(STATSTab.calendarMode or 1) .. "\n")
        settingsWriter:close()
    end
end

function LoadUi()
    -- Read from user/Lua path only.
    local reader = getFileReader("TWSTATSpos.txt", false)
    if reader then
        local mx = reader:readLine()
        local my = reader:readLine()
        reader:close()
        local x = tonumber(mx)
        local y = tonumber(my)
        if x and y then
            -- Clamp to screen, so bad files never push the panel off-screen
            local core = getCore and getCore() or nil
            local sw   = (core and core.getScreenWidth and core:getScreenWidth()) or 1920
            local sh   = (core and core.getScreenHeight and core:getScreenHeight()) or 1080
            local clx  = math.max(0, math.min(x, sw - 32))
            local cly  = math.max(0, math.min(y, sh - 32))
            return clx, cly
        else
            print("[TWF][Stats] Bad TWSTATSpos.txt (x=" ..
                tostring(mx) .. ", y=" .. tostring(my) .. ") -> using script defaults.")
        end
    end

    -- Script defaults (your chosen standards); no mod-folder fallback.
    return 16, 582
end

function SetOrGetPersistentUniqueID(playerObj)
    local localPlayer = getPlayer()
    if not localPlayer or not playerObj or playerObj ~= localPlayer then
        return nil
    end

    local st = __ttfEnsureMPState(playerObj)
    if not st then return nil end

    if st.PersistentUniqueID and st.PersistentUniqueID ~= "" then
        TwisTonFireStats.UniquePlayerID = st.PersistentUniqueID
        __ttfMirrorStateToModData(playerObj)
        return st.PersistentUniqueID
    end

    local desc = playerObj.getDescriptor and playerObj:getDescriptor() or nil
    if not desc then return nil end

    local fn = ""
    local sn = ""
    if desc.getForename then fn = tostring(desc:getForename() or "") end
    if desc.getSurname then sn = tostring(desc:getSurname() or "") end

    fn = tostring(fn):gsub("[%s\t]", "")
    sn = tostring(sn):gsub("[%s\t]", "")

    if fn == "" and sn == "" then
        fn = "Unknown"
    end

    local charId = nil
    pcall(function()
        if desc.getID then charId = desc:getID() end
    end)
    if charId == nil or tostring(charId) == "" or tostring(charId) == "0" or tostring(charId) == "nil" then
        pcall(function()
            if desc.getPersistentId then charId = desc:getPersistentId() end
        end)
    end

    local uniqueID
    if charId ~= nil and tostring(charId) ~= "" and tostring(charId) ~= "0" and tostring(charId) ~= "nil" then
        uniqueID = __ttfSanitizeFileComponent(fn .. "_" .. sn .. "_cid" .. tostring(charId))
    else
        -- Last resort: keep old behavior if no character ID exists
        uniqueID = __ttfSanitizeFileComponent(fn .. "_" .. sn .. "_" .. tostring(os.time()))
    end

    st.PersistentUniqueID = uniqueID

    TwisTonFireStats.UniquePlayerID = uniqueID
    __ttfMirrorStateToModData(playerObj)
    __ttfFlushMPState(playerObj, true)

    return uniqueID
end

local function OnGameStart_SaveDailyRecord()
    local player = getPlayer()
    if not player then return end

    local st = __ttfEnsureMPState(player)
    local dailyRecord = (st and tonumber(st.dailyKillRecord)) or 0
    SaveDailyKillRecord(player, dailyRecord)
end

function TwisTonFireStats.GetUniqueID()
    return TwisTonFireStats.UniquePlayerID
end

function TwisTonFireStats.ToggleMainUI()
    local ui = EnsureStatsUi()
    if not ui then return end
    local vis = ui:isVisible()
    if vis then
        SaveUi() -- persist position when hiding
        ui:setVisible(false)
    else
        ui:setVisible(true)
        if ui.updatePositions then ui:updatePositions() end
    end
end

function TwisTonFireStats.GetStatsFilePath()
    local player = getPlayer()
    if not player then return nil end
    local id = TwisTonFireStats.UniquePlayerID or SetOrGetPersistentUniqueID(player)
    if not id then return nil end
    return ("stats/" .. id .. ".txt")
end

function TwisTonFireStats.GetTodayDailyKills()
    local p = getPlayer()
    if not p then return 0 end
    local md = p:getModData()
    if not md then return 0 end
    local base = md.killsAtMidnight or 0
    local now  = p:getZombieKills() or 0
    local diff = now - base
    return (diff >= 0) and diff or 0
end

function TwisTonFireStats.RepairStatsFile(opts)
    opts = opts or {}
    local path = TwisTonFireStats.GetStatsFilePath and TwisTonFireStats.GetStatsFilePath()
    if not path then
        print("[TTF_Stats] Repair: no stats file path."); return false
    end

    local r = getFileReader(path, false)
    if not r then
        print("[TTF_Stats] Repair: cannot open " .. tostring(path)); return false
    end

    local zByDay, dateByDay = {}, {}
    local firstForename, firstSurname = nil, nil
    local uniqueInDays = {}
    local header = r:readLine() -- skip header
    while true do
        local line = r:readLine()
        if not line then break end
        line = line:gsub("\r", "")
        if line ~= "" then
            -- naive CSV split (we don't expect commas in names)
            local cols = {}
            for part in string.gmatch(line, "([^,]+)") do cols[#cols + 1] = part end
            local fn, sn = cols[1] or "", cols[2] or ""
            if not firstForename then firstForename = fn end
            if not firstSurname then firstSurname = sn end

            local z   = tonumber(cols[3] or "")
            local day = tonumber(cols[6] or "")
            local ds  = cols[7] or ""
            if z and z >= 0 and day and day >= 0 then
                uniqueInDays[day] = true
                if (not zByDay[day]) or (z > zByDay[day]) then zByDay[day] = z end
                if ds ~= "" then
                    local cur = dateByDay[day]
                    if (not cur) or (ds < cur) then dateByDay[day] = ds end -- earliest date wins
                end
            end
        end
    end
    r:close()

    local inDayCount = 0; for _ in pairs(uniqueInDays) do inDayCount = inDayCount + 1 end
    local days = {}; for d, _ in pairs(zByDay) do table.insert(days, d) end
    table.sort(days)
    if #days == 0 then
        print("[TTF_Stats] Repair: no valid rows found."); return false
    end

    -- SAFETY: Don’t drop lots of days unless forced
    if not opts.force and #days < math.floor(inDayCount * 0.9) then
        print(string.format("[TTF_Stats] Repair aborted: would drop too many rows (%d of %d). Use {force=true}.", #days,
            inDayCount))
        return false
    end

    -- Always keep original name if present; fallback to descriptor only if empty/missing
    if (not firstForename or firstForename == "") or (not firstSurname or firstSurname == "") then
        local p       = getPlayer()
        local desc    = p and p:getDescriptor() or nil
        firstForename = firstForename or (desc and desc:getForename()) or ""
        firstSurname  = firstSurname or (desc and desc:getSurname()) or ""
    end

    -- Backup original
    if opts.backup ~= false then
        local ts  = os.date("%Y%m%d_%H%M%S")
        local bak = path .. ".bak." .. ts
        local r2  = getFileReader(path, false)
        local w2  = getFileWriter(bak, false, false)
        if r2 and w2 then
            local ln = r2:readLine()
            while ln do
                w2:write(ln .. "\n"); ln = r2:readLine()
            end
            r2:close(); w2:close()
            print("[TTF_Stats] Backup written: " .. bak)
        else
            print("[TTF_Stats] WARN: backup failed, continuing anyway.")
        end
    end

    -- Rewrite cleaned file
    local w = getFileWriter(path, false, false)
    if not w then
        print("[TTF_Stats] Repair: cannot write " .. tostring(path)); return false
    end
    w:write("forename,surname,zkills,dailykills,averagekills,dayssurvived,date\n")

    local prevZ, relIdx = 0, 0
    for i = 1, #days do
        relIdx   = relIdx + 1
        local d  = days[i]
        local z  = zByDay[d] or 0
        local dk = z - prevZ; if dk < 0 then dk = 0 end
        local av   = z / relIdx -- matches your CSV semantics (per entry/day average)
        local dat  = dateByDay[d] or os.date("%Y-%m-%d")
        local line = string.format("%s,%s,%d,%d,%.2f,%d,%s",
            firstForename, firstSurname, z, dk, av, d, tostring(dat))
        w:write(line .. "\n")
        prevZ = z
    end
    w:close()

    print(string.format("[TTF_Stats] Repair: done. Wrote %d rows to %s", #days, path))
    return true
end

local function _onKeyPressed_TTFStats_Main(key)
    local want =
        (TTF_StatsOptions and TTF_StatsOptions.GetToggleMainKey and TTF_StatsOptions.GetToggleMainKey())
        or (Keyboard and (Keyboard.KEY_NUMPAD8 or Keyboard.KEY_KP8 or Keyboard.KEY_8))
        or 56
    if key == want then
        TwisTonFireStats.ToggleMainUI()
    end
end
Events.OnKeyPressed.Add(_onKeyPressed_TTFStats_Main)

Events.OnGameStart.Add(OnGameStart_SaveDailyRecord)

Events.OnGameStart.Add(function() if STATSTab and STATSTab.updatePositions then STATSTab:updatePositions() end end)
