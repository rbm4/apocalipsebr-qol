if not TTF_KillStats then TTF_KillStats = {} end
local M = TTF_KillStats

local PSEUDO_WEAPON_VEHICLE = "__VEHICLE__"
local PSEUDO_WEAPON_UNARMED = "__UNARMED__"

local CATEGORY_KEYS = {
    "Axe", "LongBlade", "SmallBlade", "Spear", "Blunt", "SmallBlunt",
    "Firearm", "Vehicle", "Unarmed", "Other"
}

local SAVE_DIR = "statsMP/"

-- Weak table keyed by zombie
local lastHit = setmetatable({}, { __mode = "k" })

-- =========================================================
-- Local persistence (MP-only, client-only)
-- One file per character per server.
-- =========================================================

local __STATE = nil
local __STATE_KEY = nil
local __STATE_PATH = nil
local __NEXT_WRITE = 0
local __WRITE_COOLDOWN = 3 -- seconds

local function ensureStatsFolder()
    local ok, writer = pcall(getFileWriter, SAVE_DIR .. ".ttf_keep", true, false)
    if ok and writer then
        writer:close()
    end
end

local function __sanitizeFileComponent(s)
    s = tostring(s or "")
    s = s:gsub("[%s\r\n\t]", "")
    if s == "" then s = "x" end
    return (s:gsub("[^%w%._%-]", "_"))
end

local function __getServerFingerprint()
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

    local ipIsNumeric = ip:match("^%d+$") ~= nil
    local ipLooksLikeAddress = (ip:match("[%a]") ~= nil) or (ip:match("[%.:]") ~= nil)

    local parts = {}

    if name ~= "" and name ~= "nil" then
        parts[#parts + 1] = name
    end
    if port ~= "" and port ~= "nil" and port ~= "0" then
        parts[#parts + 1] = port
    end
    if ip ~= "" and ip ~= "nil" and (not ipIsNumeric) and ipLooksLikeAddress then
        parts[#parts + 1] = ip
    end

    if #parts == 0 then
        return "mp"
    end

    return __sanitizeFileComponent(table.concat(parts, "_"))
end

local function __buildStateKey(player)
    local desc = player and player.getDescriptor and player:getDescriptor() or nil

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
        if desc and desc.getID then charId = desc:getID() end
    end)
    if charId == nil or tostring(charId) == "" or tostring(charId) == "0" or tostring(charId) == "nil" then
        pcall(function()
            if desc and desc.getPersistentId then charId = desc:getPersistentId() end
        end)
    end

    local serverFP = __getServerFingerprint()

    if charId ~= nil and tostring(charId) ~= "" and tostring(charId) ~= "0" and tostring(charId) ~= "nil" then
        local raw = serverFP .. "_cid" .. tostring(charId) .. "_" .. forename .. "_" .. surname
        return __sanitizeFileComponent(raw)
    end

    local uname = ""
    pcall(function()
        if player and player.getUsername then
            uname = tostring(player:getUsername() or "")
        end
    end)
    if uname == "" or uname == "nil" then uname = "noname" end

    local raw = serverFP .. "_" .. uname .. "_" .. forename .. "_" .. surname
    return __sanitizeFileComponent(raw)
end

local function __encodeKey(s)
    s = tostring(s or "")
    return (s:gsub("([^%w%._%-])", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function __decodeKey(s)
    s = tostring(s or "")
    return (s:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function __readKV(path)
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

local function __ensureState(player)
    local localPlayer = getPlayer()
    if not localPlayer or not player or player ~= localPlayer then return nil end

    ensureStatsFolder()

    local key  = __buildStateKey(player)
    local path = SAVE_DIR .. "TTF_MPStats_" .. key .. ".txt" -- shared file (MPState + KillStats)

    if __STATE and __STATE_KEY == key and __STATE_PATH == path then
        return __STATE
    end

    local function fileReadable(relPath)
        local ok, r = pcall(getFileReader, relPath, false)
        if ok and r then
            pcall(function() r:close() end)
            return true
        end
        return false
    end

    local function hasKillKeys(raw)
        if raw["ks.vehicleKills"] ~= nil then return true end
        for k, _ in pairs(raw) do
            if type(k) == "string" and k:sub(1, 3) == "ks." then
                return true
            end
        end
        return false
    end

    local function sumKillKeys(raw)
        local total = tonumber(raw["ks.vehicleKills"]) or 0

        for _, cat in ipairs(CATEGORY_KEYS) do
            total = total + (tonumber(raw["ks.cat." .. cat]) or 0)
        end

        for k, v in pairs(raw) do
            if type(k) == "string" and k:sub(1, 7) == "ks.wpn." then
                total = total + (tonumber(v) or 0)
            end
        end

        return total
    end

    -- If the target file exists and already has ks.* keys, just load it.
    local rawTarget = __readKV(path) or {}

    -- One-time merge migration:
    -- If ks.* keys are missing in the target file, pull them from the best legacy file ending in _Forename_Surname.txt.
    if not hasKillKeys(rawTarget) then
        local okJava = (luajava and luajava.bindClass) and true or false
        if okJava then
            local okBind, File = pcall(luajava.bindClass, "java.io.File")
            if okBind and File then
                local sep = (getFileSeparator and getFileSeparator()) or "/"
                local doc = (getMyDocumentFolder and getMyDocumentFolder()) or ""

                local function normalizeDir(p)
                    p = tostring(p or "")
                    p = p:gsub("[/\\]+", sep)
                    if p:sub(-1) == sep then p = p:sub(1, -2) end
                    return p
                end

                local statsDirRel = normalizeDir(SAVE_DIR)
                local absStatsDir = (doc ~= "" and (normalizeDir(doc) .. sep .. "Lua" .. sep .. statsDirRel)) or
                statsDirRel

                local desc = player and player.getDescriptor and player:getDescriptor() or nil
                local fnSafe = desc and desc.getForename and tostring(desc:getForename() or "unknown") or "unknown"
                local snSafe = desc and desc.getSurname and tostring(desc:getSurname() or "unknown") or "unknown"
                fnSafe = __sanitizeFileComponent(fnSafe)
                snSafe = __sanitizeFileComponent(snSafe)

                local function escapePattern(s)
                    return (tostring(s):gsub("(%W)", "%%%1"))
                end
                local suffixPat = "_" .. escapePattern(fnSafe) .. "_" .. escapePattern(snSafe) .. "%.txt$"

                local bestRel = nil
                local bestKills = -1
                local bestMTime = -1

                local okDir, dir = pcall(function()
                    if File.new then return File.new(absStatsDir) end
                    return File(absStatsDir)
                end)

                if okDir and dir and dir.exists and dir:exists() and dir.isDirectory and dir:isDirectory() then
                    local okList, arr = pcall(function() return dir:listFiles() end)
                    if okList and arr then
                        local function getAt(i)
                            if arr.get then return arr:get(i) end
                            return arr[i] or arr[i + 1] or arr[i - 1]
                        end

                        local function consider(n, mt)
                            -- Skip current target file name
                            local fullRel = SAVE_DIR .. n
                            if fullRel == path then return end

                            if not n:match("^TTF_MPStats_") then return end
                            if not n:match(suffixPat) then return end

                            local legacyRaw = __readKV(fullRel) or {}
                            local kills = sumKillKeys(legacyRaw)
                            if kills > bestKills or (kills == bestKills and mt > bestMTime) then
                                bestKills = kills
                                bestMTime = mt
                                bestRel = fullRel
                            end
                        end

                        if arr.size then
                            for i = 0, (arr:size() - 1) do
                                local f = getAt(i)
                                if f and f.getName then
                                    local n = tostring(f:getName() or "")
                                    local mt = (f.lastModified and f:lastModified()) or 0
                                    consider(n, mt)
                                end
                            end
                        else
                            for i = 1, #arr do
                                local f = arr[i]
                                if f and f.getName then
                                    local n = tostring(f:getName() or "")
                                    local mt = (f.lastModified and f:lastModified()) or 0
                                    consider(n, mt)
                                end
                            end
                        end
                    end
                end

                if bestRel and fileReadable(bestRel) and bestKills > 0 then
                    local legacyRaw = __readKV(bestRel) or {}

                    -- Merge ks.* keys only into the target (keep mp.* keys untouched)
                    for k, v in pairs(legacyRaw) do
                        if type(k) == "string" and (k:sub(1, 3) == "ks." or k == "version") then
                            rawTarget[k] = v
                        end
                    end

                    -- Persist merged ks.* keys via normal writer (keeps mp.* intact)
                    local stTmp = {
                        categories = {},
                        weapons = {},
                        vehicleKills = tonumber(rawTarget["ks.vehicleKills"]) or 0
                    }

                    for _, cat in ipairs(CATEGORY_KEYS) do
                        stTmp.categories[cat] = tonumber(rawTarget["ks.cat." .. cat]) or 0
                    end

                    for k, v in pairs(rawTarget) do
                        if type(k) == "string" and k:sub(1, 7) == "ks.wpn." then
                            local enc = k:sub(8)
                            local fullType = __decodeKey(enc)
                            stTmp.weapons[fullType] = tonumber(v) or 0
                        end
                    end

                    __writeState(path, stTmp)

                    -- Reload after write to ensure we read exactly what's on disk
                    rawTarget = __readKV(path) or rawTarget
                end
            end
        end
    end

    local st = {
        categories = {},
        weapons = {},
        vehicleKills = tonumber(rawTarget["ks.vehicleKills"]) or 0
    }

    for _, cat in ipairs(CATEGORY_KEYS) do
        st.categories[cat] = tonumber(rawTarget["ks.cat." .. cat]) or 0
    end

    for k, v in pairs(rawTarget) do
        if type(k) == "string" and k:sub(1, 7) == "ks.wpn." then
            local enc = k:sub(8)
            local fullType = __decodeKey(enc)
            st.weapons[fullType] = tonumber(v) or 0
        end
    end

    __STATE = st
    __STATE_KEY = key
    __STATE_PATH = path

    return __STATE
end

local function __writeState(path, st)
    -- Merge-write into the shared file (do not erase mp.* keys written by TwisTonFireStats.lua)
    local raw = __readKV(path) or {}

    -- Remove old ks.* keys to avoid stale leftovers
    for k, _ in pairs(raw) do
        if type(k) == "string" and k:sub(1, 3) == "ks." then
            raw[k] = nil
        end
    end

    raw["version"] = 2
    raw["ks.vehicleKills"] = tostring(tonumber(st.vehicleKills) or 0)

    for _, cat in ipairs(CATEGORY_KEYS) do
        raw["ks.cat." .. cat] = tostring(tonumber(st.categories[cat]) or 0)
    end

    for fullType, count in pairs(st.weapons) do
        raw["ks.wpn." .. __encodeKey(fullType)] = tostring(tonumber(count) or 0)
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

local function __flushState(player, force)
    local st = __ensureState(player)
    if not st or not __STATE_PATH then return end

    local now = getTimestamp()
    if not force and now < __NEXT_WRITE then return end

    __NEXT_WRITE = now + __WRITE_COOLDOWN
    __writeState(__STATE_PATH, st)
end

-- =========================================================
-- Counting helpers
-- =========================================================

local function __incCategory(player, cat)
    local st = __ensureState(player); if not st then return end
    cat = cat or "Other"
    st.categories[cat] = (tonumber(st.categories[cat]) or 0) + 1
    __flushState(player, false)
end

local function __incWeapon(player, fullType)
    local st = __ensureState(player); if not st then return end
    if not fullType or fullType == "" then fullType = "Unknown" end
    st.weapons[fullType] = (tonumber(st.weapons[fullType]) or 0) + 1
    __flushState(player, false)
end

local function __incVehicle(player)
    local st = __ensureState(player); if not st then return end
    st.vehicleKills = (tonumber(st.vehicleKills) or 0) + 1
    __flushState(player, false)
end

local function classifyWeapon(weapon)
    if not weapon then return "Unarmed", nil end

    local fullType = weapon.getFullType and weapon:getFullType() or nil
    local wtype = weapon.getType and weapon:getType() or ""
    if wtype == "BareHands" or fullType == "Base.BareHands" then
        return "Unarmed", nil
    end

    if weapon.isRanged and weapon:isRanged() then
        return "Firearm", fullType
    end

    local si = weapon.getScriptItem and weapon:getScriptItem() or nil
    if si and si.containsWeaponCategory and WeaponCategory then
        if WeaponCategory.AXE and si:containsWeaponCategory(WeaponCategory.AXE) then
            return "Axe", fullType
        end
        if WeaponCategory.LONG_BLADE and si:containsWeaponCategory(WeaponCategory.LONG_BLADE) then
            return "LongBlade", fullType
        end
        if WeaponCategory.SMALL_BLADE and si:containsWeaponCategory(WeaponCategory.SMALL_BLADE) then
            return "SmallBlade", fullType
        end
        if WeaponCategory.SPEAR and si:containsWeaponCategory(WeaponCategory.SPEAR) then
            return "Spear", fullType
        end
        if WeaponCategory.BLUNT and si:containsWeaponCategory(WeaponCategory.BLUNT) then
            return "Blunt", fullType
        end
        if WeaponCategory.SMALL_BLUNT and si:containsWeaponCategory(WeaponCategory.SMALL_BLUNT) then
            return "SmallBlunt", fullType
        end
    end

    if weapon.getSubCategory then
        local sub = weapon:getSubCategory()
        if sub and sub ~= "" then
            return sub, fullType
        end
    end

    return "Other", fullType
end

local function playerDriving(player)
    local veh = player and player.getVehicle and player:getVehicle() or nil
    if not veh then return nil, false end
    if veh.getDriverRegardlessOfTow and veh:getDriverRegardlessOfTow() == player then return veh, true end
    if veh.getDriver and veh:getDriver() == player then return veh, true end
    if veh.getSeat and veh:getSeat(player) == 0 then return veh, true end
    if veh.getCharacter and veh:getCharacter(0) == player then return veh, true end
    return veh, false
end

-- =========================================================
-- Events (local-player only)
-- =========================================================

local function onWeaponHitCharacter(attacker, target, weapon, _damage)
    local localPlayer = getPlayer()
    if not localPlayer then return end
    if attacker ~= localPlayer then return end

    if not target or not instanceof(target, "IsoZombie") then return end

    local cat, full = classifyWeapon(weapon)
    if not full and cat == "Unarmed" then full = PSEUDO_WEAPON_UNARMED end

    lastHit[target] = { cat = cat, full = full }
end

local function onZombieDead(zombie)
    local localPlayer = getPlayer()
    if not localPlayer then return end

    if not zombie or zombie:isFakeDead() then return end

    local killer = zombie.getAttackedBy and zombie:getAttackedBy() or nil
    if killer ~= localPlayer then
        -- MP-only: ignore other players entirely
        lastHit[zombie] = nil
        return
    end

    local veh, isDriver = playerDriving(localPlayer)
    if veh and isDriver then
        __incVehicle(localPlayer)
        __incCategory(localPlayer, "Vehicle")
        __incWeapon(localPlayer, PSEUDO_WEAPON_VEHICLE)
        lastHit[zombie] = nil
        return
    end

    local lh = lastHit[zombie]
    local cat, full

    if lh then
        cat, full = lh.cat, lh.full
    else
        local w = (localPlayer.getPrimaryHandItem and localPlayer:getPrimaryHandItem()) or nil
        cat, full = classifyWeapon(w)
        if not full and cat == "Unarmed" then full = PSEUDO_WEAPON_UNARMED end
    end

    __incCategory(localPlayer, cat)
    if full then __incWeapon(localPlayer, full) end

    lastHit[zombie] = nil
end

local function onCreatePlayer(_idx, player)
    local localPlayer = getPlayer()
    if not localPlayer or not player or player ~= localPlayer then return end
    __ensureState(player)
    __flushState(player, true)
end

-- =========================================================
-- API for UI/other modules
-- =========================================================

function TTF_KillStats.Get(_playerNum)
    local p = getPlayer()
    if not p then return nil end
    return __ensureState(p)
end

-- =========================================================
-- Wire up (prevent duplicate installs on reload)
-- =========================================================

if not M.__TTF_HooksInstalled then
    Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
    Events.OnZombieDead.Add(onZombieDead)
    Events.OnCreatePlayer.Add(onCreatePlayer)
    M.__TTF_HooksInstalled = true
end
