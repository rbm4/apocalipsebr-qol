-- AACSServer.lua (Build 42 / MP-safe)
-- Server-side adoption registry + validation. Server is source of truth.

if not isServer() then return end

local ok = pcall(require, "AACSShared")
if not ok then return end
pcall(require, "AACSOverrideShared")

AACS = AACS or {}

local function _t(key, ...)
    local msg = getText(key)
    local args = { ... }
    for i = 1, #args do
        msg = msg:gsub("%%" .. i, tostring(args[i]))
    end
    return msg
end

local function _registry()
    return ModData.getOrCreate(AACS.REGISTRY_KEY)
end

local function _meta()
    return ModData.getOrCreate(AACS.REGISTRY_META_KEY or "AACS_RegistryMeta")
end

-- Sequential, persistent UID generator (01, 02, 03...).
-- Server-only, MP-safe: single source of truth + persisted in ModData.
function AACS.NextSequentialUID()
    local meta = _meta()
    local reg = _registry()

    -- Seed counter from existing numeric UIDs (if any)
    if meta.Counter == nil then
        local maxN = 0
        for uid, _ in pairs(reg) do
            -- Only seed from sequential-style IDs (avoid old timestamp-style IDs)
            if type(uid) == "string" and #uid <= 6 then
                local n = tonumber(uid)
                if n and n > maxN then maxN = n end
            end
        end
        meta.Counter = maxN
    end

    local n = tonumber(meta.Counter) or 0
    local uid = nil

    -- Find next free id (avoid collisions)
    for _i = 1, 1000000 do
        n = n + 1
        uid = string.format("%02d", n)
        if not reg[uid] then
            meta.Counter = n
            return uid
        end
    end

    -- Fallback (should never happen)
    return tostring(AACS.Now())
end


local function _isAdmin(playerObj)
    return AACS.IsAdmin(playerObj)
end

local function _sv()
    return (SandboxVars and SandboxVars.AACS) or {}
end

local function _playersOnline()
    local list = getOnlinePlayers()
    local t = {}
    if not list then return t end
    for i = 0, list:size() - 1 do
        table.insert(t, list:get(i))
    end
    return t
end

local function _broadcastToAdmins(cmd, args)
    for _, p in ipairs(_playersOnline()) do
        if _isAdmin(p) then
            sendServerCommand(p, "AACS", cmd, args)
        end
    end
end

local function _notify(playerObj, msg, kind)
    sendServerCommand(playerObj, "AACS", "notify", { msg = msg, kind = kind or "info" })
end

-- MP-safe localization:
-- Instead of translating on the server (which may not have the same language
-- or may not have translation tables loaded), send the translation key + args
-- and let each client translate locally.
local function _notifyKey(playerObj, key, kind, ...)
    sendServerCommand(playerObj, "AACS", "notify", { key = key, args = { ... }, kind = kind or "info" })
end

local function _getSquare(x,y,z)
    local cell = getCell()
    if not cell then return nil end
    return cell:getGridSquare(x, y, z)
end

local function _getAnimalByOnlineId(animalId)
    if not animalId then return nil end
    local key = tostring(animalId)

    AACS._animalIdCache = AACS._animalIdCache or { map = {}, nextRefresh = 0 }
    local cache = AACS._animalIdCache
    local now = getTimestamp()

    if now >= (cache.nextRefresh or 0) or not cache.map[key] then
        cache.map = {}
        cache.nextRefresh = now + 2 -- seconds

        local cell = getCell()
        if cell then
            local allObjects = cell:getObjectList()
            if allObjects then
                for i = 0, allObjects:size() - 1 do
                    local obj = allObjects:get(i)
                    if _isAnimalObject(obj) then
                        local objId = nil
                        pcall(function() objId = obj:getOnlineID() end)
                        if objId then
                            cache.map[tostring(objId)] = obj
                        end
                    end
                end
            end
        end
    end

    return cache.map[key]
end

local function _getOrCreateSquare(x, y, z)
    local cell = getCell()
    if not cell then return nil end

    local sq = cell:getGridSquare(x, y, z)
    if sq then return sq end

    -- Some servers don't have the square loaded yet; try to create/load if supported.
    if cell.getOrCreateGridSquare then
        local ok, created = pcall(function() return cell:getOrCreateGridSquare(x, y, z) end)
        if ok and created then return created end
    end

    return nil
end

local function _teleportPlayerTo(playerObj, x, y, z)
    -- MP note: server should initiate and confirm, but chunk-loading can vary.
    -- We therefore: (1) try server teleport without requiring a loaded square,
    -- (2) best-effort set square if available, (3) instruct client to force-teleport as a fallback.
    if not playerObj then return false end

    local px, py = x + 0.5, y + 0.5
    local did = false

    -- Try built-in teleport first (most reliable when available).
    if playerObj.teleportTo then
        local ok = pcall(function() playerObj:teleportTo(px, py, z) end)
        if ok then did = true end
    end

    -- Fallback: set raw coordinates even if the destination chunk isn't loaded.
    if not did then
        pcall(function() if playerObj.setX then playerObj:setX(px) end end)
        pcall(function() if playerObj.setY then playerObj:setY(py) end end)
        pcall(function() if playerObj.setZ then playerObj:setZ(z) end end)

        pcall(function() if playerObj.setLx then playerObj:setLx(px) end end)
        pcall(function() if playerObj.setLy then playerObj:setLy(py) end end)
        pcall(function() if playerObj.setLz then playerObj:setLz(z) end end)

        did = true
    end

    -- Best-effort: bind to a loaded square if it exists (helps some MP sync paths).
    local sq = _getSquare(x, y, z)
    if not sq then
        -- _getOrCreateSquare may still return nil if the chunk isn't loaded server-side; that's OK.
        sq = _getOrCreateSquare(x, y, z)
    end
    if sq then
        pcall(function() if playerObj.setSquare then playerObj:setSquare(sq) end end)
        pcall(function() if playerObj.setCurrentSquare then playerObj:setCurrentSquare(sq) end end)
        pcall(function() if playerObj.setCurrent then playerObj:setCurrent(sq) end end)
    end

    -- Nudge network sync (API varies by patch; keep pcall safe).
    pcall(function() if playerObj.transmitPosition then playerObj:transmitPosition() end end)
    pcall(function() if playerObj.sendObjectChange then playerObj:sendObjectChange("teleport") end end)

    -- Client fallback: force local teleport to avoid "nothing happens" when chunk isn't server-loaded yet.
    sendServerCommand(playerObj, "AACS", "forceTeleport", { x = px, y = py, z = z })

    return did
end



local function _isAnimalObject(o)
    if not o then return false end
    
    -- Gold standard: instanceof IsoAnimal is the ONLY reliable check in B42.
    local isAnimal = false
    pcall(function()
        isAnimal = instanceof(o, "IsoAnimal")
    end)
    if isAnimal then return true end

    -- Blacklist: reject known non-animal types BEFORE any fallback.
    local isBlacklisted = false
    pcall(function()
        isBlacklisted = instanceof(o, "IsoZombie") or instanceof(o, "IsoPlayer") or
                        instanceof(o, "IsoSurvivor") or instanceof(o, "IsoVehicle") or
                        instanceof(o, "IsoDeadBody")
    end)
    if isBlacklisted then return false end

    -- Secondary: IsoMovingObject with isAnimal() == true
    local isMoving = false
    pcall(function()
        isMoving = instanceof(o, "IsoMovingObject")
    end)
    
    if isMoving then
        if o.isAnimal and type(o.isAnimal) == "function" then
            local ok, res = pcall(function()
                return o:isAnimal()
            end)
            if ok and res == true then return true end
        end
        -- NOTE: Do NOT use getAnimalType/getAnimalID/getAnimalDef as heuristics!
        -- getAnimalType() exists on IsoPlayer too and causes false positives.
    end
    
    return false
end

local function _getAnimalDisplayName(animal)
    if not animal then return nil end
    if animal.getDisplayName then
        local ok, n = pcall(function() return animal:getDisplayName() end)
        if ok and n and n ~= "" then return n end
    end
    if animal.getFullName then
        local ok, n = pcall(function() return animal:getFullName() end)
        if ok and n and n ~= "" then return n end
    end
    if animal.getName then
        local ok, n = pcall(function() return animal:getName() end)
        if ok and n and n ~= "" then return n end
    end
    return nil
end

local function _normName(s)
    if not s then return nil end
    s = tostring(s)
    s = s:gsub("<[^>]+>", "")
    s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return s:lower()
end

local function _findAnimalNear(x, y, z, radius, preferName)
    radius = radius or 2
    local targetNN = _normName(preferName)
    local best, bestScore, bestD2 = nil, -1, 999999

    local function scoreName(animal)
        if not targetNN then return 0 end
        local nn = _normName(_getAnimalDisplayName(animal))
        if not nn then return -1 end
        if nn == targetNN then return 100 end
        if nn:find(targetNN, 1, true) or targetNN:find(nn, 1, true) then return 70 end
        return 10
    end

    for dx = -radius, radius do
        for dy = -radius, radius do
            local sq = _getSquare(x + dx, y + dy, z)
            if sq then
                local lists = {}

                local mov = sq.getMovingObjects and sq:getMovingObjects() or nil
                if mov then lists[#lists+1] = mov end

                if sq.getStaticMovingObjects then
                    local ok, smov = pcall(function() return sq:getStaticMovingObjects() end)
                    if ok and smov then lists[#lists+1] = smov end
                end

                for _, lst in ipairs(lists) do
                    for i = 0, lst:size() - 1 do
                        local o = lst:get(i)
                        if _isAnimalObject(o) then
                            local sc = scoreName(o)
                            if sc >= 0 then
                                local ox, oy = o:getX(), o:getY()
                                local d2 = (ox - x)*(ox - x) + (oy - y)*(oy - y)
                                if (sc > bestScore) or (sc == bestScore and d2 < bestD2) then
                                    bestScore = sc
                                    bestD2 = d2
                                    best = o
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end


-- Find an animal near a location by matching AACS UID in modData (more reliable than name matching).
local function _findAnimalNearByUID(x, y, z, radius, uid)
    radius = radius or 6
    uid = tostring(uid or "")
    if uid == "" then return nil end

    for dx = -radius, radius do
        for dy = -radius, radius do
            local sq = _getSquare(x + dx, y + dy, z)
            if sq then
                local lists = {}

                local mov = sq.getMovingObjects and sq:getMovingObjects() or nil
                if mov then lists[#lists+1] = mov end

                if sq.getStaticMovingObjects then
                    local ok, smov = pcall(function() return sq:getStaticMovingObjects() end)
                    if ok and smov then lists[#lists+1] = smov end
                end

                for _, lst in ipairs(lists) do
                    for i = 0, lst:size() - 1 do
                        local o = lst:get(i)
                        if _isAnimalObject(o) then
                            local ouid = AACS.GetAnimalUID(o)
                            if ouid and tostring(ouid) == uid then
                                return o
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- Prefer a stable, descriptive name for registry/UI; prefer getFullName to avoid placeholders.
local function _getAnimalBestName(animal)
    if not animal then return nil end
    local function safeCall(fn)
        local ok, res = pcall(fn)
        if ok and res ~= nil then
            local s = tostring(res)
            if s ~= "" then return s end
        end
        return nil
    end

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
    return n
end

-- Repair older/placeholder entries so the UI doesn't show the same name for everything.
local function _repairEntryName(entry)
    if not entry or not entry.UID then return end
    local cur = tostring(entry.AnimalName or "")
    local need = (cur == "")

    -- Common placeholder seen in some setups
    if not need then
        local lc = string.lower(cur)
        if lc == "bob" then need = true end
    end
    if not need then return end

    local x, y, z = tonumber(entry.LastX) or 0, tonumber(entry.LastY) or 0, tonumber(entry.LastZ) or 0
    local animal = _findAnimalNearByUID(x, y, z, 10, tostring(entry.UID))
    if animal then
        local best = _getAnimalBestName(animal)
        if best and best ~= "" then
            entry.AnimalName = best
            _registry()[tostring(entry.UID)] = entry
            ModData.transmit(AACS.REGISTRY_KEY)
            return
        end
    end

    -- Fallback: at least make it unique/stable in lists
    local at = tostring(entry.AnimalType or "animal")
    entry.AnimalName = string.format("%s #%s", at, tostring(entry.UID))
    _registry()[tostring(entry.UID)] = entry
    ModData.transmit(AACS.REGISTRY_KEY)
end



local function _entryToClient(entry)
    -- Shallow copy only.
    local out = {}
    for k,v in pairs(entry) do
        if k == "AllowList" then
            local a = {}
            if v then for _, u in ipairs(v) do table.insert(a, u) end end
            out[k] = a
        else
            out[k] = v
        end
    end
    return out
end

local function _entryAllowListContains(entry, username)
    if not entry or not entry.AllowList or not username then return false end
    for _, u in ipairs(entry.AllowList) do
        if u == username then return true end
    end
    return false
end

local function _entryModeAllows(owner, username, mode)
    if not owner or not username then return false end
    if mode == AACS.MODE_SAFEHOUSE then
        return AACS.IsSafehouseMember(owner, username)
    elseif mode == AACS.MODE_FACTION then
        return AACS.IsFactionMember(owner, username)
    elseif mode == AACS.MODE_SAFE_OR_FACT then
        return AACS.IsSafehouseMember(owner, username) or AACS.IsFactionMember(owner, username)
    end
    return false
end

local function _canPlayerInteractEntry(entry, playerObj)
    if not entry or not playerObj then return false end
    local username = playerObj:getUsername()
    if not username or username == "" then return false end

    if entry.Owner == username then return true end
    local svAACS2 = _sv()
    local adminBypassEnabled2 = (svAACS2 == nil) or (svAACS2.AdminBypass ~= false)
    if adminBypassEnabled2 and _isAdmin(playerObj) then return true end
    if _entryAllowListContains(entry, username) then return true end

    local pickupMode = tonumber(entry.PickupMode) or AACS.MODE_OWNER_ONLY
    local leashMode = tonumber(entry.LeashMode) or AACS.MODE_OWNER_ONLY
    return _entryModeAllows(entry.Owner, username, pickupMode) or _entryModeAllows(entry.Owner, username, leashMode)
end

local function _getOwnerEntries(owner)
    local reg = _registry()
    local entries = {}
    for uid, e in pairs(reg) do
        if e and e.Owner == owner then
            _repairEntryName(e)
            table.insert(entries, _entryToClient(e))
        end
    end    table.sort(entries, function(a,b)
        local an = tonumber(a.UID) or 999999999
        local bn = tonumber(b.UID) or 999999999
        if an ~= bn then return an < bn end
        return tostring(a.UID) < tostring(b.UID)
    end)
    return entries
end

local function _getInteractableEntries(playerObj)
    local reg = _registry()
    local entries = {}
    for uid, e in pairs(reg) do
        if e and _canPlayerInteractEntry(e, playerObj) then
            _repairEntryName(e)
            table.insert(entries, _entryToClient(e))
        end
    end
    table.sort(entries, function(a,b)
        local an = tonumber(a.UID) or 999999999
        local bn = tonumber(b.UID) or 999999999
        if an ~= bn then return an < bn end
        return tostring(a.UID) < tostring(b.UID)
    end)
    return entries
end

local function _getAllEntries()
    local reg = _registry()
    local entries = {}
    for uid, e in pairs(reg) do
        if e then
            _repairEntryName(e)
            table.insert(entries, _entryToClient(e))
        end
    end    table.sort(entries, function(a,b)
        local an = tonumber(a.UID) or 999999999
        local bn = tonumber(b.UID) or 999999999
        if an ~= bn then return an < bn end
        return tostring(a.UID) < tostring(b.UID)
    end)
    return entries
end

local function _applyRegistryToAnimal(animal, entry)
    if not animal then return end
    -- Keep last-seen updated in modData too
    AACS.SetAnimalClaimModData(animal, entry)
end

local function _removeRegistry(uid)
    local reg = _registry()
    local entry = reg[uid]
    reg[uid] = nil
    if entry and entry.Owner then
        AACS.Log("Removed adoption UID " .. uid .. " from registry (owner: " .. entry.Owner .. ")")
    end
end

local function _addOrUpdateRegistry(entry)
    local reg = _registry()
    reg[entry.UID] = entry
end

local function _updateLastSeen(animal, entry)
    if not entry or not animal then return end
    local sq = animal:getSquare()
    if sq then
        entry.LastX, entry.LastY, entry.LastZ = sq:getX(), sq:getY(), sq:getZ()
    end
    entry.LastSeen = AACS.Now()
    _addOrUpdateRegistry(entry)
    _applyRegistryToAnimal(animal, entry)
        _repairEntryName(entry)
end

local function _pushEntryUpdate(entry)
    local payload = { entry = _entryToClient(entry) }
    for _, p in ipairs(_playersOnline()) do
        if _isAdmin(p) or _canPlayerInteractEntry(entry, p) then
            sendServerCommand(p, "AACS", "updateEntry", payload)
        end
    end
end

local function _pushEntryRemove(entry)
    local uid = entry and entry.UID
    if not uid then return end
    for _, p in ipairs(_playersOnline()) do
        if _isAdmin(p) or _canPlayerInteractEntry(entry, p) then
            sendServerCommand(p, "AACS", "removeEntry", { uid = uid })
        end
    end
end

-----------------------------------------------------------------------
-- Helper: give a DocumentPet item to a player (server-side).
-- If inventory is full, drop it near the player.
-----------------------------------------------------------------------
local function _giveDocumentToPlayer(playerObj)
    if not playerObj then return false end
    local inv = playerObj:getInventory()
    if not inv then return false end

    -- B42 server: use instanceItem() instead of InventoryItemFactory
    local item = nil
    pcall(function()
        item = instanceItem(AACS.DOCUMENT_ITEM)
    end)

    if not item then
        -- Fallback: try InventoryItemFactory (for SP or older builds)
        pcall(function()
            item = InventoryItemFactory.CreateItem(AACS.DOCUMENT_ITEM)
        end)
    end

    if not item then
        AACS.Log("_giveDocumentToPlayer: failed to create " .. AACS.DOCUMENT_ITEM)
        return false
    end

    -- Ensure item is fresh and reusable (clear any flags)
    pcall(function()
        if item.setActivated then item:setActivated(false) end
        if item.setUsedDelta then item:setUsedDelta(0) end
        if item.setCondition then item:setCondition(100) end
    end)

    -- B42 MP: Add item using direct inventory manipulation + forced sync
    local added = false
    local synced = false
    local error_msg = nil

    -- Try MP sync method first
    local ok, err = pcall(function()
        if isServer() then
            -- B42 requires BOTH operations for reliable sync
            inv:AddItem(item)  -- Add locally first
            sendAddItemToContainer(inv, item)  -- Then sync to client
            added = true
            synced = true
        else
            -- SP: just add
            inv:AddItem(item)
            added = true
            synced = true
        end
    end)

    if not ok then
        error_msg = tostring(err)
        AACS.Log("ERROR in _giveDocumentToPlayer: " .. error_msg)
    end

    if not added then
        -- Fallback: drop near player
        local sq = playerObj:getSquare()
        if sq then
            sq:AddWorldInventoryItem(item, 0.5, 0.5, 0)
            _notifyKey(playerObj, "IGUI_AACS_Notify_DocumentDropped", "info")
            AACS.Log("Document dropped near " .. playerObj:getUsername() .. " (add failed: " .. (error_msg or "unknown") .. ")")
            return true
        end
        return false
    end

    AACS.Log("Document returned to " .. playerObj:getUsername() .. " (MP sync: " .. tostring(synced) .. ")")
    return true
end

-- Commands
function AACS.onClientCommand(module, command, playerObj, args)
    -- [FIX-3] INTERCEPTAR COMANDOS DO JOGO BASE PARA ANIMAIS
    -- Covers: leash, pickup/carry, kill/slaughter
    if module == "animal" then
        -- Map commands to AACS action types for permission checking
        local actionMap = {
            leash = "leash", setLeashed = "leash", unleash = "leash",
            pickup = "pickup", carryAnimal = "pickup", carry = "pickup",
            pickupAnimal = "pickup", grab = "pickup",
            kill = "kill", slaughter = "kill", killAnimal = "kill",
            slaughterAnimal = "kill",
        }
        
        local action = actionMap[command]
        if action then
            local animalId = args.id or args.animalId or args.animal
            if animalId then
                local animal = _getAnimalByOnlineId(animalId)
                
                if animal and AACS.IsClaimed(animal) then
                    if not AACS.CanPlayerDo(playerObj, animal, action) then
                        local owner = AACS.GetAnimalOwner(animal) or "?"
                        local uid = AACS.GetAnimalUID(animal) or "?"
                        local msg = _t("IGUI_AACS_Notify_Protected", owner, uid)
                        
                        sendServerCommand(playerObj, "AACS", "notify", { msg = msg, kind = "bad" })
                        AACS.Log(string.format("BLOCKED %s attempt by %s on animal %s (owner: %s)", 
                            command, playerObj:getUsername(), uid, owner))
                        
                        return -- BLOCK command
                    end
                end
            end
        end
        -- Let unrelated animal commands pass through (don't return here!)
        return
    end
    
    if module ~= "AACS" then return end
    args = args or {}
    local username = playerObj:getUsername()

    if command == "updateLastLogin" then
        -- Same strategy as AVCS: the client pings on join + every in-game hour.
        -- Server records the timestamp and broadcasts to all clients so UIs can show "Expires at" immediately.
        local ts = getTimestamp()
        AACS.SetLastLogin(username, ts)
        sendServerCommand("AACS", "updateClientLastLogin", { username = username, ts = ts })
        return
    end

    if command == "requestMyAnimals" then
        sendServerCommand(playerObj, "AACS", "myAnimalsData", { entries = _getOwnerEntries(username) })
        return
    end

    if command == "requestInteractableAnimals" then
        sendServerCommand(playerObj, "AACS", "interactableAnimalsData", { entries = _getInteractableEntries(playerObj) })
        return
    end

    if command == "requestAllAnimals" then
        if not _isAdmin(playerObj) then
            _notifyKey(playerObj, "IGUI_AACS_Notify_PermissionDenied", "bad")
            return
        end
        sendServerCommand(playerObj, "AACS", "allAnimalsData", { entries = _getAllEntries() })
        return
    end

    

    if command == "teleportToLocation" then
        AACS.SetLastLogin(username, getTimestamp()) -- activity
        if not _isAdmin(playerObj) then
            _notifyKey(playerObj, "IGUI_AACS_Notify_PermissionDenied", "bad")
            return
        end

        local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
        if not x or not y or z == nil then return end
        z = tonumber(z) or 0

        -- Simple anti-spam / cooldown per admin (non-persistent; avoids "works once then never" when timestamp units differ)
        AACS._tpCooldown = AACS._tpCooldown or {}
        local now = AACS.Now()
        local last = tonumber(AACS._tpCooldown[username]) or 0
        if now < last then last = 0 end
        local cdMs = 300 -- keep small; admin tool
        if (now - last) < cdMs then
            local remain = cdMs - (now - last)
            _notify(playerObj, _t("IGUI_AACS_Notify_TeleportCooldown", string.format("%.1f", remain / 1000)), "bad")
            return
        end
        AACS._tpCooldown[username] = now

        if not _teleportPlayerTo(playerObj, x, y, z) then
            _notifyKey(playerObj, "IGUI_AACS_Notify_TeleportFailed", "bad")
            return
        end

        _notify(playerObj, _t("IGUI_AACS_Notify_Teleported", x, y, z), "info")
        return
    end

    if command == "queryAnimalAt" then
        AACS.SetLastLogin(username, getTimestamp()) -- activity
        local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
        local requestId = tostring(args.requestId or "")
        local name = args.name and tostring(args.name) or nil
        if requestId == "" or (not x) or (not y) or (not z) then return end

        local animal = _findAnimalNear(x, y, z, 6, name)
        if not animal then
            sendServerCommand(playerObj, "AACS", "animalStatus", { requestId = requestId, found = false })
            return
        end

        local claimed = AACS.IsClaimed(animal)
        local owner = claimed and (AACS.GetAnimalOwner(animal) or "?") or nil
        local uid = claimed and (AACS.GetAnimalUID(animal) or "?") or nil
        local canManage = false
        if claimed then
            canManage = (owner == username) or _isAdmin(playerObj)
        end

        sendServerCommand(playerObj, "AACS", "animalStatus", {
            requestId = requestId,
            found = true,
            claimed = claimed,
            owner = owner,
            uid = uid,
            canManage = canManage,
        })
        return
    end

if command == "adoptAnimal" then
        AACS.SetLastLogin(username, getTimestamp()) -- adoption activity
        local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
        if not x or not y or not z then return end

        -- [NEW] Server-side: check adoption limit
        local maxAnimals = AACS.GetMaxAnimalsPerPlayer()
        local svAACS = _sv()
        local adminBypassEnabled = (svAACS == nil) or (svAACS.AdminBypass ~= false)
        local bypass = _isAdmin(playerObj) and adminBypassEnabled

        if maxAnimals > 0 and not bypass then
            local currentCount = AACS.CountPlayerAdoptions(username)
            AACS.Log("Adoption limit check: " .. username .. " has " .. currentCount .. " / " .. maxAnimals .. " animals")
            if currentCount >= maxAnimals then
                _notifyKey(playerObj, "IGUI_AACS_Require_Limit", "bad", currentCount, maxAnimals)
                return
            end
        end

        -- Find and validate animal FIRST (before consuming document)
        local animal = _findAnimalNear(x, y, z, 2)
        if not animal then
            _notifyKey(playerObj, "IGUI_AACS_Notify_AnimalNotFoundRetry", "bad")
            return
        end

        if AACS.IsClaimed(animal) and not bypass then
            local owner = AACS.GetAnimalOwner(animal) or "?"
            local uid = AACS.GetAnimalUID(animal) or "?"
            _notify(playerObj, _t("IGUI_AACS_Notify_AlreadyAdopted", owner, uid), "bad")
            return
        end

        -- Second-line defence: registry duplicate check.
        -- After a pickup/drop cycle the IsoAnimal is recreated and loses modData,
        -- so IsClaimed() above returns false even though the animal is still registered.
        -- We scan the registry for any entry whose name+type matches this animal AND
        -- whose last-known position is within a small radius. If found, re-stamp and block.
        do
            local anName  = _normName(_getAnimalDisplayName(animal))
            local anType  = nil
            pcall(function() anType = _normName(tostring(animal:getAnimalType())) end)
            local anSq    = animal:getSquare()
            local anX     = anSq and anSq:getX() or x
            local anY     = anSq and anSq:getY() or y
            local anZ     = anSq and anSq:getZ() or z
            local RADIUS2 = 36 -- 6 tiles squared

            local reg = _registry()
            for regUID, entry in pairs(reg) do
                if entry then
                    local ex = tonumber(entry.LastX) or 0
                    local ey = tonumber(entry.LastY) or 0
                    local ez = tonumber(entry.LastZ) or 0
                    local d2 = (anX - ex)*(anX - ex) + (anY - ey)*(anY - ey)

                    if ez == anZ and d2 <= RADIUS2 then
                        -- Position matches; check name+type
                        local nameMatch = false
                        if anName and anName ~= "" then
                            local en = _normName(entry.AnimalName or "")
                            if en ~= "" then
                                nameMatch = (en == anName)
                                    or en:find(anName, 1, true) ~= nil
                                    or anName:find(en, 1, true) ~= nil
                            end
                        end

                        local typeMatch = false
                        if anType and anType ~= "" then
                            local et = _normName(entry.AnimalType or "")
                            typeMatch = (et ~= "" and (et == anType
                                or et:find(anType, 1, true) ~= nil
                                or anType:find(et, 1, true) ~= nil))
                        end

                        if nameMatch or typeMatch then
                            -- Found a matching registry entry — re-stamp modData and reject adoption
                            AACS.SetAnimalClaimModData(animal, entry)
                            local eOwner = tostring(entry.Owner or "?")
                            local eUID   = tostring(entry.UID or "?")
                            AACS.Log(string.format(
                                "adoptAnimal: duplicate blocked — registry entry UID=%s owner=%s matched animal '%s' at %d,%d,%d",
                                eUID, eOwner, tostring(anName), anX, anY, anZ))
                            _notify(playerObj, _t("IGUI_AACS_Notify_AlreadyAdopted", eOwner, eUID), "bad")
                            return
                        end
                    end
                end
            end
        end

        -- [NEW] Server-side: check and consume document (ONLY after validating animal)
        if AACS.RequiresDocument() and not bypass then
            local inv = playerObj:getInventory()
            if not inv then
                _notifyKey(playerObj, "IGUI_AACS_Notify_NeedDocument", "bad")
                return
            end
            local docItem = inv:getFirstTypeRecurse(AACS.DOCUMENT_ITEM)
            if not docItem then
                _notifyKey(playerObj, "IGUI_AACS_Notify_NeedDocument", "bad")
                return
            end
            -- Consume the document (only when we KNOW the adoption will succeed)
            -- B42 MP: Remove using both local + sync for reliability
            local synced = false
            local ok, err = pcall(function()
                if isServer() then
                    -- B42 requires BOTH operations
                    inv:Remove(docItem)  -- Remove locally first
                    sendRemoveItemFromContainer(inv, docItem)  -- Then sync to client
                    synced = true
                else
                    -- SP fallback
                    inv:Remove(docItem)
                    synced = true
                end
            end)
            if not ok then
                AACS.Log("ERROR consuming document: " .. tostring(err))
            end
            AACS.Log("Document consumed for adoption by " .. username .. " (MP sync: " .. tostring(synced) .. ")")
        end

        local uid = AACS.NextSequentialUID()
        local entry = AACS.MakeEntry(username, animal, uid)
        _addOrUpdateRegistry(entry)
        _applyRegistryToAnimal(animal, entry)
        _repairEntryName(entry)

        -- Translate on client (server language may differ / may not have tables)
        _notifyKey(playerObj, "IGUI_AACS_Notify_AdoptedCode", "good", uid)
        _pushEntryUpdate(entry)

        -- Notify OTHER admins (not the player who adopted)
        for _, p in ipairs(_playersOnline()) do
            if _isAdmin(p) and p:getUsername() ~= username then
                sendServerCommand(p, "AACS", "notify", {
                    key = "IGUI_AACS_Notify_AdminAdopted",
                    args = { username, uid },
                    kind = "info"
                })
            end
        end
        return
    end

    if command == "unadoptAnimal" then
        AACS.SetLastLogin(username, getTimestamp()) -- adoption activity
        local uid = tostring(args.uid or "")
        if uid == "" then return end

        local reg = _registry()
        local entry = reg[uid]
        if not entry then
            _notifyKey(playerObj, "IGUI_AACS_Notify_RecordNotFound", "bad")
            return
        end

        if entry.Owner ~= username and not _isAdmin(playerObj) then
            _notifyKey(playerObj, "IGUI_AACS_Notify_NotOwner", "bad")
            return
        end

        -- Attempt to find the animal near last coords and clear its modData.
        local animal = _findAnimalNear(tonumber(entry.LastX) or 0, tonumber(entry.LastY) or 0, tonumber(entry.LastZ) or 0, 6)
        if animal and AACS.GetAnimalUID(animal) == uid then
            AACS.ClearAnimalClaimModData(animal)
        end

        _removeRegistry(uid)

        -- Force ModData sync to all clients
        if ModData and ModData.transmit then
            ModData.transmit(AACS.REGISTRY_KEY)
        end

        -- [NEW] Return document to the player who executes the unadopt, if enabled.
        if AACS.RequiresDocument() and AACS.ShouldReturnDocument() then
            if _giveDocumentToPlayer(playerObj) then
                _notifyKey(playerObj, "IGUI_AACS_Notify_DocumentReturned", "info")
                AACS.Log("Document returned to " .. username .. " on unadopt of UID " .. uid)
            end
        end

        -- Translate on client (server language may differ / may not have tables)
        _notifyKey(playerObj, "IGUI_AACS_Notify_UnadoptedCode", "good", uid)
        _pushEntryRemove(entry)
        return
    end

    if command == "renameAnimal" then
        AACS.SetLastLogin(username, getTimestamp()) -- activity
        local uid = tostring(args.uid or "")
        local nickname = tostring(args.nickname or "")
        
        if uid == "" or nickname == "" then return end
        
        local reg = _registry()
        local entry = reg[uid]
        if not entry then
            _notifyKey(playerObj, "IGUI_AACS_Notify_AnimalNotFound", "bad")
            return
        end
        
        if entry.Owner ~= username and not _isAdmin(playerObj) then
            _notifyKey(playerObj, "IGUI_AACS_Notify_RenameOwnerOnly", "bad")
            return
        end
        
        -- Update entry
        entry.Nickname = nickname
        reg[uid] = entry
        
        -- Update ModData of animal if possible
        local animal = _findAnimalNear(
            tonumber(entry.LastX) or 0, 
            tonumber(entry.LastY) or 0, 
            tonumber(entry.LastZ) or 0, 
            6
        )
        if animal and AACS.GetAnimalUID(animal) == uid then
            AACS.SetAnimalNickname(animal, nickname)
        end
        
        _notify(playerObj, _t("IGUI_AACS_Notify_Renamed", nickname), "good")
        _pushEntryUpdate(entry)
        return
    end

    if command == "setPermissions" then
        AACS.SetLastLogin(username, getTimestamp()) -- activity
        local uid = tostring(args.uid or "")
        if uid == "" then return end

        local reg = _registry()
        local entry = reg[uid]
        if not entry then
            _notifyKey(playerObj, "IGUI_AACS_Notify_RecordNotFound", "bad")
            return
        end

        if entry.Owner ~= username and not _isAdmin(playerObj) then
            _notifyKey(playerObj, "IGUI_AACS_Notify_NotOwner", "bad")
            return
        end

        local pickupMode = tonumber(args.pickupMode) or entry.PickupMode
        local leashMode  = tonumber(args.leashMode)  or entry.LeashMode
        if pickupMode < 1 or pickupMode > 4 then pickupMode = entry.PickupMode end
        if leashMode  < 1 or leashMode  > 4 then leashMode  = entry.LeashMode end
        pickupMode = AACS.SanitizeMode(pickupMode)
        leashMode = AACS.SanitizeMode(leashMode)

        entry.PickupMode = pickupMode
        entry.LeashMode  = leashMode

        -- AllowList array of usernames
        entry.AllowList = {}
        if args.allowList and type(args.allowList) == "table" then
            for _, u in ipairs(args.allowList) do
                if u and u ~= "" then table.insert(entry.AllowList, u) end
            end
        end

        -- Update last seen if we can locate animal
        local animal = _findAnimalNear(tonumber(entry.LastX) or 0, tonumber(entry.LastY) or 0, tonumber(entry.LastZ) or 0, 6)
        if animal and AACS.GetAnimalUID(animal) == uid then
            _updateLastSeen(animal, entry)
        else
            _addOrUpdateRegistry(entry)
        end

        _notifyKey(playerObj, "IGUI_AACS_Notify_PermissionsUpdated", "good")
        _pushEntryUpdate(entry)
        return
    end

    if command == "pingAnimal" then
        AACS.SetLastLogin(username, getTimestamp()) -- activity
        local uid = tostring(args.uid or "")
        if uid == "" then return end

        local reg = _registry()
        local entry = reg[uid]
        if not entry then return end

        local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
        if not x or not y or not z then return end

        local animal = _findAnimalNear(x, y, z, 2)
        if animal and AACS.GetAnimalUID(animal) == uid then
            -- Throttle last-seen updates to avoid excessive registry spam.
            AACS._pingThrottle = AACS._pingThrottle or {}
            local nowMs = AACS.Now()
            local last = AACS._pingThrottle[uid]
            local shouldUpdate = true

            if last and (nowMs - last.ts) < 15000 then
                local dx = (last.x or x) - x
                local dy = (last.y or y) - y
                local dz = (last.z or z) - z
                if (dx * dx + dy * dy + dz * dz) <= 1 then
                    shouldUpdate = false
                end
            end

            if shouldUpdate then
                AACS._pingThrottle[uid] = { ts = nowMs, x = x, y = y, z = z }
                _updateLastSeen(animal, entry)
                _pushEntryUpdate(entry)
            end
        end
        return
    end
end

-- Handler principal AACS
if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(AACS.onClientCommand)
end


-----------------------------------------------------------------------
-- Adoption Expiry (SandboxVars.AACS.AdoptionExpiryDays)
-- If > 0: when a player stays without logging in for N real days,
-- all their adopted animals are released (registry entries removed).
-- MP-safe: server is source of truth.
-----------------------------------------------------------------------

local AACS_LASTLOGIN_KEY = "AACS_PlayerLastLogin"

local function _aacsOnInitGlobalModData()
    -- Ensure the key exists so clients can ModData.request() it immediately.
    local db = ModData.getOrCreate(AACS_LASTLOGIN_KEY)
    if ModData and ModData.add then
        pcall(function() ModData.add(AACS_LASTLOGIN_KEY, db) end)
    end
end

pcall(function()
    if Events and Events.OnInitGlobalModData then
        Events.OnInitGlobalModData.Add(_aacsOnInitGlobalModData)
    end
end)
pcall(_aacsOnInitGlobalModData)


local function _aacsLastLoginDB()
    return ModData.getOrCreate(AACS_LASTLOGIN_KEY)
end

local function _aacsPersistLastLogin(db)
    -- Not required for logic, but helps ensure persistence across restarts.
    if ModData and ModData.add then
        pcall(function() ModData.add(AACS_LASTLOGIN_KEY, db) end)
    end
end

local function _aacsGetExpiryDays()
    local v = 0
    if SandboxVars and SandboxVars.AACS then
        v = SandboxVars.AACS.AdoptionExpiryDays
    end
    v = tonumber(v) or 0
    if v < 0 then v = 0 end
    return v
end


local function _aacsTransmitLastLoginThrottled()
    -- Avoid spamming global ModData transmit (heartbeat + actions can be frequent).
    AACS._nextLastLoginTransmit = AACS._nextLastLoginTransmit or 0
    local now = getTimestamp()
    if now < (AACS._nextLastLoginTransmit or 0) then return end
    AACS._nextLastLoginTransmit = now + 60 -- seconds
    if ModData and ModData.transmit then
        ModData.transmit(AACS_LASTLOGIN_KEY)
    end
end

function AACS.SetLastLogin(username, ts)
    if not username or username == "" then return end
    local db = _aacsLastLoginDB()
    db[username] = tonumber(ts) or getTimestamp()
    _aacsPersistLastLogin(db)
    _aacsTransmitLastLoginThrottled()
end

local function _aacsIsOnline(username)
    local list = getOnlinePlayers()
    if not list then return false end
    for i = 0, list:size() - 1 do
        local p = list:get(i)
        if p and p:getUsername() == username then
            return true
        end
    end
    return false
end

function AACS.ReleaseAdoptionsForOwner(ownerUsername, reason)
    if not ownerUsername or ownerUsername == "" then return 0 end
    local reg = _registry()

    local uids = {}
    for uid, entry in pairs(reg) do
        if entry and entry.Owner == ownerUsername then
            table.insert(uids, tostring(uid))
        end
    end
    if #uids == 0 then return 0 end

    local released = 0
    for _, uid in ipairs(uids) do
        local entry = reg[uid]
        if entry then
            -- Best-effort clear modData on a nearby loaded animal (may fail if chunk isn't loaded).
            local animal = _findAnimalNear(tonumber(entry.LastX) or 0, tonumber(entry.LastY) or 0, tonumber(entry.LastZ) or 0, 6)
            if animal and AACS.GetAnimalUID(animal) == uid then
                AACS.ClearAnimalClaimModData(animal)
            end

            _removeRegistry(uid)
            released = released + 1
            _pushEntryRemove(entry)
        end
    end

    -- Sync registry changes to clients using Global ModData.
    if ModData and ModData.transmit then
        ModData.transmit(AACS.REGISTRY_KEY)
    end

    -- Let admins know.
    _broadcastToAdmins("notify", {
        msg = _t("IGUI_AACS_Notify_AdoptionExpired", ownerUsername, released),
        kind = "info"
    })

    return released
end

local function _aacsCleanupOrphanAnimalClaims()
    -- If an animal keeps claim modData but its UID isn't in the registry, clear it.
    -- This prevents "ghost protection" when entries are removed while the animal wasn't loaded.
    local cell = getCell()
    if not cell then return end
    local objs = cell:getObjectList()
    if not objs then return end
    local reg = _registry()

    local cleared = 0
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if _isAnimalObject(obj) then
            local uid = AACS.GetAnimalUID(obj)
            if uid and not reg[tostring(uid)] then
                AACS.ClearAnimalClaimModData(obj)
                cleared = cleared + 1
            end
        end
    end

    if cleared > 0 then
        AACS.Log("Orphan cleanup: cleared " .. tostring(cleared) .. " animal claim modData.")
    end
end

function AACS.DoAdoptionExpiryCheck()
    local days = _aacsGetExpiryDays()
    if days <= 0 then return end

    local now = getTimestamp()
    local secondsLimit = days * 24 * 60 * 60

    local reg = _registry()
    local db = _aacsLastLoginDB()

    -- Heartbeat: refresh online players so they never expire while connected.
    local online = getOnlinePlayers()
    if online then
        for i = 0, online:size() - 1 do
            local p = online:get(i)
            if p then
                db[p:getUsername()] = now
            end
        end
    end

    local expiredOwners = {}
    local seeded = 0

    for _uid, entry in pairs(reg) do
        local owner = entry and entry.Owner or nil
        if owner and owner ~= "" then
            local last = tonumber(db[owner])
            if not last then
                -- Safety: if we have no record, seed from "now" so we don't auto-release legacy claims.
                db[owner] = now
                seeded = seeded + 1
            else
                -- If owner is online, ignore (already refreshed above).
                if not _aacsIsOnline(owner) then
                    if (now - last) > secondsLimit then
                        expiredOwners[owner] = true
                    end
                end
            end
        end
    end

    if seeded > 0 then
        AACS.Log("AdoptionExpiry: seeded last-login for " .. tostring(seeded) .. " owner(s) with no previous record.")
    end

    local totalReleased = 0
    for owner, _ in pairs(expiredOwners) do
        totalReleased = totalReleased + (AACS.ReleaseAdoptionsForOwner(owner, "expiry") or 0)
    end

    _aacsPersistLastLogin(db)

    if totalReleased > 0 then
        AACS.Log("AdoptionExpiry: released " .. tostring(totalReleased) .. " adoption(s).")
    end

    _aacsCleanupOrphanAnimalClaims()
end

-----------------------------------------------------------------------
-- Dead Animal Detection
-- Periodically scans loaded animals and checks for dead ones.
-- Removes dead animals from the adoption registry automatically.
-- Also uses isDead() checks during restamp and orphan cleanup.
-----------------------------------------------------------------------

local function _isAnimalDead(animal)
    if not animal then return true end -- treat nil as "gone"

    -- Primary: isDead() method (most reliable in B42)
    if animal.isDead and type(animal.isDead) == "function" then
        local ok, dead = pcall(function() return animal:isDead() end)
        if ok and dead == true then return true end
    end

    -- Secondary: health <= 0 (some B42 builds)
    if animal.getHealth and type(animal.getHealth) == "function" then
        local ok, hp = pcall(function() return animal:getHealth() end)
        if ok and hp ~= nil and tonumber(hp) ~= nil and tonumber(hp) <= 0 then return true end
    end

    -- Tertiary: check if the object has been removed from the world
    if animal.getSquare and type(animal.getSquare) == "function" then
        local ok, sq = pcall(function() return animal:getSquare() end)
        if ok and sq == nil then return true end -- no longer on any square
    end

    return false
end

function AACS.CheckForDeadAnimals()
    local cell = getCell()
    if not cell then return end
    local reg = _registry()

    local deadUIDs = {}

    -- Scan all loaded objects for dead animals with claim data
    local objs = cell:getObjectList()
    if objs then
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            if _isAnimalObject(obj) then
                local uid = AACS.GetAnimalUID(obj)
                if uid and reg[tostring(uid)] then
                    if _isAnimalDead(obj) then
                        deadUIDs[tostring(uid)] = true
                        -- Clear modData from the dead animal/carcass
                        AACS.ClearAnimalClaimModData(obj)
                    end
                end
            end
        end
    end

    -- Also: for each registry entry, try to find the animal and check if dead.
    -- This catches animals that died while loaded but weren't in objectList scan.
    for uid, entry in pairs(reg) do
        if entry and not deadUIDs[tostring(uid)] then
            local x = tonumber(entry.LastX) or 0
            local y = tonumber(entry.LastY) or 0
            local z = tonumber(entry.LastZ) or 0
            local animal = _findAnimalNearByUID(x, y, z, 8, tostring(uid))
            if animal and _isAnimalDead(animal) then
                deadUIDs[tostring(uid)] = true
                AACS.ClearAnimalClaimModData(animal)
            end
        end
    end

    -- Remove dead entries from registry and notify
    local removed = 0
    for uid, _ in pairs(deadUIDs) do
        local entry = reg[uid]
        if entry then
            local animalName = entry.AnimalName or entry.AnimalType or "?"
            local owner = entry.Owner or "?"

            _removeRegistry(uid)
            _pushEntryRemove(entry)
            removed = removed + 1

            -- Notify the owner if online
            for _, p in ipairs(_playersOnline()) do
                if p:getUsername() == owner then
                    _notifyKey(p, "IGUI_AACS_Notify_AnimalDied", "bad", animalName, uid)
                    break
                end
            end

            -- Notify admins
            _broadcastToAdmins("notify", {
                msg = string.format("[AACS] Animal '%s' (code %s, owner: %s) died. Adoption removed.", animalName, uid, owner),
                kind = "info"
            })

            AACS.Log(string.format("Dead animal detected: UID=%s, Name=%s, Owner=%s. Adoption removed.", uid, animalName, owner))
        end
    end

    if removed > 0 then
        if ModData and ModData.transmit then
            ModData.transmit(AACS.REGISTRY_KEY)
        end
        AACS.Log("Dead animal cleanup: removed " .. tostring(removed) .. " adoption(s).")
    end
end

-----------------------------------------------------------------------

-- Run expiry check + dead animal check periodically: every 10 minutes.
local function _aacsEveryTenMinutes()
    pcall(AACS.DoAdoptionExpiryCheck)
    pcall(AACS.CheckForDeadAnimals)
end
Events.EveryTenMinutes.Add(_aacsEveryTenMinutes)


-- Backup: if server exposes OnPlayerConnect, refresh immediately.
pcall(function()
    if Events and Events.OnPlayerConnect then
        Events.OnPlayerConnect.Add(function(playerObj)
            if playerObj and playerObj.getUsername then
                AACS.SetLastLogin(playerObj:getUsername(), getTimestamp())
            end
        end)
    end
end)

-- Immediate re-stamp when an animal is added/placed back into the world.
-- This prevents the "double adoption" bug caused by pickup/drop cycles:
-- after a drop the IsoAnimal is recreated without modData, so IsClaimed()
-- returns false. By re-stamping on object add we close the window before
-- any other player can see the animal as unclaimed.
pcall(function()
    if Events and Events.OnObjectAdded then
        Events.OnObjectAdded.Add(function(obj)
            if not obj then return end
            -- Only care about actual animal objects
            local isAnimal = false
            pcall(function() isAnimal = instanceof(obj, "IsoAnimal") end)
            if not isAnimal then
                -- Secondary check via isAnimal()
                local isMoving = false
                pcall(function() isMoving = instanceof(obj, "IsoMovingObject") end)
                if isMoving and obj.isAnimal and type(obj.isAnimal) == "function" then
                    local ok2, res = pcall(function() return obj:isAnimal() end)
                    if ok2 and res == true then isAnimal = true end
                end
            end
            if not isAnimal then return end

            -- If the animal already has claim modData, nothing to do
            if AACS.IsClaimed(obj) then return end

            -- Search the registry for a matching entry
            local anName = _normName(_getAnimalDisplayName(obj))
            local anType = nil
            pcall(function() anType = _normName(tostring(obj:getAnimalType())) end)
            local anSq = nil
            pcall(function() anSq = obj:getSquare() end)
            if not anSq then return end

            local anX, anY, anZ = anSq:getX(), anSq:getY(), anSq:getZ()
            local RADIUS2 = 25 -- 5 tiles squared

            local reg = _registry()
            for regUID, entry in pairs(reg) do
                if entry then
                    local ex = tonumber(entry.LastX) or 0
                    local ey = tonumber(entry.LastY) or 0
                    local ez = tonumber(entry.LastZ) or 0
                    local d2 = (anX - ex)*(anX - ex) + (anY - ey)*(anY - ey)

                    if ez == anZ and d2 <= RADIUS2 then
                        local nameMatch = false
                        if anName and anName ~= "" then
                            local en = _normName(entry.AnimalName or "")
                            if en ~= "" then
                                nameMatch = (en == anName)
                                    or en:find(anName, 1, true) ~= nil
                                    or anName:find(en, 1, true) ~= nil
                            end
                        end
                        local typeMatch = false
                        if anType and anType ~= "" then
                            local et = _normName(entry.AnimalType or "")
                            typeMatch = (et ~= "" and (et == anType
                                or et:find(anType, 1, true) ~= nil
                                or anType:find(et, 1, true) ~= nil))
                        end

                        if nameMatch or typeMatch then
                            -- Re-stamp immediately so IsClaimed() works again
                            AACS.SetAnimalClaimModData(obj, entry)
                            entry.LastX, entry.LastY, entry.LastZ = anX, anY, anZ
                            entry.LastSeen = AACS.Now()
                            reg[tostring(regUID)] = entry
                            AACS.Log(string.format(
                                "OnObjectAdded: re-stamped UID=%s owner=%s on animal '%s' at %d,%d,%d",
                                tostring(entry.UID), tostring(entry.Owner), tostring(anName), anX, anY, anZ))
                            -- Only restamp once per object
                            return
                        end
                    end
                end
            end
        end)
    end
end)
