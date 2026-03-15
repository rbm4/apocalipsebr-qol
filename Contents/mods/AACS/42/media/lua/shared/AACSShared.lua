-- AACSShared.lua (Build 42 / MP-safe)
-- Core helpers shared across client/server. Server is the source of truth.

AACS = AACS or {}
AACS.UI = AACS.UI or {}

AACS.MOD_ID = "AACS"
AACS.REGISTRY_KEY = "AACS_Registry"
AACS.REGISTRY_META_KEY = "AACS_RegistryMeta"
AACS.LASTLOGIN_KEY = "AACS_PlayerLastLogin" -- Global ModData: username -> last login/activity (unix seconds)

-- Per-animal modData keys
AACS.MD_UID        = "AACS_UID"
AACS.MD_OWNER      = "AACS_Owner"
AACS.MD_NICKNAME   = "AACS_Nickname"   -- Custom name for animal
AACS.MD_PICKUPMODE = "AACS_PickupMode" -- 1..4
AACS.MD_LEASHMODE  = "AACS_LeashMode"  -- 1..4
AACS.MD_ALLOWLIST  = "AACS_AllowList"  -- "user1;user2;user3"
AACS.MD_LASTX      = "AACS_LastX"
AACS.MD_LASTY      = "AACS_LastY"
AACS.MD_LASTZ      = "AACS_LastZ"
AACS.MD_LASTSEEN   = "AACS_LastSeen"

-- Permission modes
AACS.MODE_OWNER_ONLY   = 1
AACS.MODE_SAFEHOUSE    = 2
AACS.MODE_FACTION      = 3
AACS.MODE_SAFE_OR_FACT = 4

local function _sv()
    return (SandboxVars and SandboxVars.AACS) or {}
end

function AACS.SanitizeMode(mode)
    mode = tonumber(mode) or AACS.MODE_OWNER_ONLY
    if mode < 1 or mode > 4 then
        return AACS.MODE_OWNER_ONLY
    end

    local allowSafehouse = _sv().AllowSafehouse == true
    local allowFaction = _sv().AllowFaction == true

    if mode == AACS.MODE_SAFEHOUSE and not allowSafehouse then
        return AACS.MODE_OWNER_ONLY
    end
    if mode == AACS.MODE_FACTION and not allowFaction then
        return AACS.MODE_OWNER_ONLY
    end
    if mode == AACS.MODE_SAFE_OR_FACT then
        if allowSafehouse and allowFaction then
            return mode
        end
        if allowSafehouse then
            return AACS.MODE_SAFEHOUSE
        end
        if allowFaction then
            return AACS.MODE_FACTION
        end
        return AACS.MODE_OWNER_ONLY
    end
    return mode
end

function AACS.GetAllowedModes()
    local modes = { AACS.MODE_OWNER_ONLY }
    if _sv().AllowSafehouse then
        table.insert(modes, AACS.MODE_SAFEHOUSE)
    end
    if _sv().AllowFaction then
        table.insert(modes, AACS.MODE_FACTION)
    end
    if _sv().AllowSafehouse and _sv().AllowFaction then
        table.insert(modes, AACS.MODE_SAFE_OR_FACT)
    end
    return modes
end

function AACS.Log(msg)
    if _sv().VerboseLogs then
        print(string.format("[AACS] %s", tostring(msg)))
    end
end

function AACS.IsAdmin(playerObj)
    -- Strict access-level check.
    -- In SP (no server/client), allow admin tools for convenience.
    if not playerObj then return false end

    if (not isClient()) and (not isServer()) then
        return true
    end

    local lvl
    pcall(function() lvl = playerObj:getAccessLevel() end)
    if not lvl then return false end
    lvl = tostring(lvl):lower()
    local allowed = {
        admin = true,
        moderator = true,
        overseer = true,
        gm = true,
        observer = true,
    }
    return allowed[lvl] == true
end

function AACS.GetPlayerLastLogin(username)
    -- Returns unix timestamp in SECONDS.
    if not username or username == "" then return nil end

    -- Client: prefer cached table (kept in sync by serverCommand + GlobalModData requests)
    if isClient and isClient() and AACS.PlayerLastLoginDB then
        return tonumber(AACS.PlayerLastLoginDB[username])
    end

    -- Fallback: Global ModData (server or client after request)
    local db = ModData and ModData.getOrCreate and ModData.getOrCreate(AACS.LASTLOGIN_KEY) or nil
    if not db then return nil end
    return tonumber(db[username])
end

function AACS.Now()
    -- getTimestamp() returns unix time in seconds (AVCS-style).
    -- AACS.Now() is used for cooldowns/ids => return milliseconds.
    if getTimestamp then return getTimestamp() * 1000 end
    return os.time() * 1000
end

function AACS.GenerateUID()
    -- Unique enough for practical use: timestamp + 4 random digits
    local r = ZombRand(1000, 9999)
    return tostring(AACS.Now()) .. tostring(r)
end

function AACS.GetAnimalUID(animal)
    if not animal or not animal.getModData then return nil end
    local md = animal:getModData()
    return md and md[AACS.MD_UID] or nil
end

function AACS.GetAnimalOwner(animal)
    if not animal or not animal.getModData then return nil end
    local md = animal:getModData()
    return md and md[AACS.MD_OWNER] or nil
end

function AACS.GetAnimalNickname(animal)
    if not animal or not animal.getModData then return nil end
    local md = animal:getModData()
    return md and md[AACS.MD_NICKNAME] or nil
end

function AACS.SetAnimalNickname(animal, nickname)
    if not animal or not animal.getModData then return end
    local md = animal:getModData()
    if md then
        md[AACS.MD_NICKNAME] = tostring(nickname or "")
    end
end

function AACS.IsClaimed(animal)
    return AACS.GetAnimalUID(animal) ~= nil
end

local function _trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function _splitAllowList(str)
    local t = {}
    if not str or str == "" then return t end
    for part in string.gmatch(str, "([^;]+)") do
        local u = _trim(part)
        if u ~= "" then t[u] = true end
    end
    return t
end

local function _joinAllowList(tbl)
    if not tbl then return "" end
    local parts = {}
    for _, u in ipairs(tbl) do
        if u and u ~= "" then
            table.insert(parts, u)
        end
    end
    return table.concat(parts, ";")
end

function AACS.AllowListContains(listStr, username)
    if not username or username == "" then return false end
    local m = _splitAllowList(listStr)
    return m[username] == true
end

function AACS.GetModeLabel(mode)
    if mode == AACS.MODE_OWNER_ONLY then return getText("IGUI_AACS_Mode1") end
    if mode == AACS.MODE_SAFEHOUSE then return getText("IGUI_AACS_Mode2") end
    if mode == AACS.MODE_FACTION then return getText("IGUI_AACS_Mode3") end
    if mode == AACS.MODE_SAFE_OR_FACT then return getText("IGUI_AACS_Mode4") end
    return tostring(mode)
end

-- Safehouse / Faction membership checks, mirrored from AVCS style usage.
function AACS.IsSafehouseMember(ownerUsername, username)
    if not _sv().AllowSafehouse then return false end
    if not ownerUsername or not username then return false end
    if not SafeHouse or not SafeHouse.hasSafehouse then return false end
    local safehouseObj = SafeHouse.hasSafehouse(ownerUsername)
    if not safehouseObj then return false end

    local players = safehouseObj:getPlayers()
    if players then
        for i = 0, players:size() - 1 do
            if players:get(i) == username then return true end
        end
    end

    local ok, owner = pcall(function() return safehouseObj:getOwner() end)
    if ok and owner == username then return true end
    return false
end

function AACS.IsFactionMember(ownerUsername, username)
    if not _sv().AllowFaction then return false end
    if not ownerUsername or not username then return false end
    if not Faction or not Faction.getPlayerFaction then return false end
    local factionObj = Faction.getPlayerFaction(ownerUsername)
    if not factionObj then return false end

    local ok, owner = pcall(function() return factionObj:getOwner() end)
    if ok and owner == username then return true end

    local players = factionObj:getPlayers()
    if players then
        for i = 0, players:size() - 1 do
            if players:get(i) == username then return true end
        end
    end
    return false
end

local function _getModeFromAnimal(animal, key, fallback)
    local md = animal:getModData()
    local v = md and md[key] or nil
    v = tonumber(v) or fallback
    if v < 1 or v > 4 then v = fallback end
    return AACS.SanitizeMode(v)
end

function AACS.CanPlayerDo(playerObj, animal, action)
    -- action: "pickup", "leash" (rope), or "kill" (slaughter)
    if not playerObj or not animal then return false end

    local md = animal:getModData()
    local uid = md and md[AACS.MD_UID] or nil
    if not uid then return true end -- unclaimed animal

    local owner = md[AACS.MD_OWNER]
    local username = playerObj:getUsername()

    if owner == username then return true end
    local svAACS3 = _sv()
    local adminBypassEnabled3 = (svAACS3 == nil) or (svAACS3.AdminBypass ~= false)
    if adminBypassEnabled3 and AACS.IsAdmin(playerObj) then return true end

    -- Allowlist
    if AACS.AllowListContains(md[AACS.MD_ALLOWLIST], username) then
        return true
    end

    -- Kill action: owner + allowlist + admin only (no safehouse/faction for safety)
    if action == "kill" then
        return false
    end

    local mode = AACS.MODE_OWNER_ONLY
    if action == "pickup" then
        mode = _getModeFromAnimal(animal, AACS.MD_PICKUPMODE, AACS.MODE_OWNER_ONLY)
    elseif action == "leash" then
        mode = _getModeFromAnimal(animal, AACS.MD_LEASHMODE, AACS.MODE_OWNER_ONLY)
    end

    if mode == AACS.MODE_SAFEHOUSE then
        return AACS.IsSafehouseMember(owner, username)
    elseif mode == AACS.MODE_FACTION then
        return AACS.IsFactionMember(owner, username)
    elseif mode == AACS.MODE_SAFE_OR_FACT then
        return AACS.IsSafehouseMember(owner, username) or AACS.IsFactionMember(owner, username)
    end

    return false
end

function AACS.SetAnimalClaimModData(animal, entry)
    if not animal or not entry then return end
    local md = animal:getModData()
    md[AACS.MD_UID]        = entry.UID
    md[AACS.MD_OWNER]      = entry.Owner
    md[AACS.MD_PICKUPMODE] = AACS.SanitizeMode(tonumber(entry.PickupMode) or AACS.MODE_OWNER_ONLY)
    md[AACS.MD_LEASHMODE]  = AACS.SanitizeMode(tonumber(entry.LeashMode) or AACS.MODE_OWNER_ONLY)
    md[AACS.MD_ALLOWLIST]  = _joinAllowList(entry.AllowList)
    md[AACS.MD_LASTX]      = entry.LastX
    md[AACS.MD_LASTY]      = entry.LastY
    md[AACS.MD_LASTZ]      = entry.LastZ
    md[AACS.MD_LASTSEEN]   = entry.LastSeen

    -- MP: ensure clients receive updated claim data
    if isServer and isServer() then
        if animal.transmitModData then
            animal:transmitModData()
        elseif animal.transmitModDataToClients then
            animal:transmitModDataToClients()
        end
    end
end

function AACS.ClearAnimalClaimModData(animal)
    if not animal then return end
    local md = animal:getModData()
    md[AACS.MD_UID]        = nil
    md[AACS.MD_OWNER]      = nil
    md[AACS.MD_PICKUPMODE] = nil
    md[AACS.MD_LEASHMODE]  = nil
    md[AACS.MD_ALLOWLIST]  = nil
    md[AACS.MD_LASTX]      = nil
    md[AACS.MD_LASTY]      = nil
    md[AACS.MD_LASTZ]      = nil
    md[AACS.MD_LASTSEEN]   = nil

    -- MP: ensure clients receive cleared claim data
    if isServer and isServer() then
        if animal.transmitModData then
            animal:transmitModData()
        elseif animal.transmitModDataToClients then
            animal:transmitModDataToClients()
        end
    end
end


-- Prefer a stable, descriptive animal name for UI/registry.
-- Note: some vanilla animals may return placeholder display names; prefer getFullName when available.
function AACS.GetAnimalBestName(animal)
    if not animal then return "" end

    local function safeCall(fn)
        local ok, res = pcall(fn)
        if ok and res ~= nil then
            local s = tostring(res)
            if s ~= "" then return s end
        end
        return nil
    end

    -- Prefer full name (usually includes species/sex/stage)
    local n = nil
    if animal.getFullName then
        n = safeCall(function() return animal:getFullName() end)
    end
    if not n and animal.getDisplayName then
        n = safeCall(function() return animal:getDisplayName() end)
    end
    if not n and animal.getName then
        n = safeCall(function() return animal:getName() end)
    end
    return n or ""
end

function AACS.MakeEntry(ownerUsername, animal, uid)
    local sq = animal and animal.getSquare and animal:getSquare() or nil
    local x, y, z = 0, 0, 0
    if sq then x, y, z = sq:getX(), sq:getY(), sq:getZ() end

    local entry = {
        UID = uid,
        Owner = ownerUsername,
        AnimalType = tostring(animal and animal.getAnimalType and animal:getAnimalType() or "animal"),
        AnimalName = AACS.GetAnimalBestName(animal),
        PickupMode = AACS.SanitizeMode(_sv().DefaultPickupMode or AACS.MODE_OWNER_ONLY),
        LeashMode  = AACS.SanitizeMode(_sv().DefaultLeashMode  or AACS.MODE_OWNER_ONLY),
        AllowList = {},
        LastX = x, LastY = y, LastZ = z,
        LastSeen = AACS.Now(),
    }
    return entry
end

function AACS.FormatLocation(entry)
    if not entry then return "-" end
    return string.format("%d, %d, %d", tonumber(entry.LastX) or 0, tonumber(entry.LastY) or 0, tonumber(entry.LastZ) or 0)
end

function AACS.FormatLastSeen(entry)
    if not entry or not entry.LastSeen then return "-" end
    local ms = tonumber(entry.LastSeen) or 0
    local seconds = math.floor(ms / 1000)
    -- Avoid locale issues; show raw timestamp seconds
    return tostring(seconds)
end

-----------------------------------------------------------------------
-- Document & Limit helpers (shared so client can do pre-checks for UI)
-----------------------------------------------------------------------

AACS.DOCUMENT_ITEM = "Base.DocumentPet"

--- Check if the RequireDocumentToAdopt sandbox option is enabled.
function AACS.RequiresDocument()
    return _sv().RequireDocumentToAdopt == true
end

--- Check if the ReturnDocumentOnUnadopt sandbox option is enabled.
function AACS.ShouldReturnDocument()
    return _sv().ReturnDocumentOnUnadopt == true
end

--- Get the max adopted animals per player (0 = unlimited).
function AACS.GetMaxAnimalsPerPlayer()
    local v = tonumber(_sv().MaxAdoptedAnimalsPerPlayer) or 0
    if v < 0 then v = 0 end
    return v
end

--- Count how many animals a player owns in the registry.
--- Works on both client (from cache) and server (from ModData).
function AACS.CountPlayerAdoptions(username)
    if not username or username == "" then return 0 end
    local count = 0

    if isServer and isServer() then
        -- Server: read directly from registry
        local reg = ModData.getOrCreate(AACS.REGISTRY_KEY)
        for _, e in pairs(reg) do
            if e and e.Owner == username then
                count = count + 1
            end
        end
    elseif isClient and isClient() then
        -- Client: read from cache (best-effort hint; server validates)
        if AACS.ClientCache and AACS.ClientCache.myEntries then
            count = #AACS.ClientCache.myEntries
        else
            -- Cache not loaded yet; return 0 (server will validate anyway)
            count = 0
        end
    else
        -- SP: read directly from registry
        local reg = ModData.getOrCreate(AACS.REGISTRY_KEY)
        for _, e in pairs(reg) do
            if e and e.Owner == username then
                count = count + 1
            end
        end
    end

    return count
end

--- Check if a player has reached the adoption limit.
--- Returns true if blocked, false if allowed.
function AACS.IsAtAdoptionLimit(username)
    local max = AACS.GetMaxAnimalsPerPlayer()
    if max <= 0 then return false end -- unlimited
    return AACS.CountPlayerAdoptions(username) >= max
end

--- Check if a player's inventory contains a DocumentPet.
--- Client-side check for UI hints; server re-validates.
function AACS.PlayerHasDocument(playerObj)
    if not playerObj then return false end
    local inv = playerObj:getInventory()
    if not inv then return false end
    local item = inv:getFirstTypeRecurse(AACS.DOCUMENT_ITEM)
    return item ~= nil
end

-- SP helper (no server/client split)
function AACS.SP_GetRegistry()
    if not ModData or not ModData.getOrCreate then return {} end
    return ModData.getOrCreate(AACS.REGISTRY_KEY)
end
