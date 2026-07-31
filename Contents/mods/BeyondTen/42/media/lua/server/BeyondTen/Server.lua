require "BeyondTen/Shared"

if not isServer() then return end

BeyondTenServer = BeyondTenServer or {}

local BT = BeyondTen
local Server = BeyondTenServer

Server._players = Server._players or setmetatable({}, { __mode = "k" })
Server.STORE_KEY = "BeyondTen_ServerMastery_v1"
Server.MAX_UNKNOWN_XP = 1000000000

local function clampPerkXP(perk, value)
    return BT.Clamp(value, 0, BT.GetTotalMasteryCost(perk, BT.MAX_LEVEL))
end

local function loadMirrorXP(player)
    local result = {}
    local data = BT.GetData(player, false)
    local perks = data and data.perks
    if type(perks) ~= "table" then return result end

    for id, record in pairs(perks) do
        local value = type(record) == "table" and tonumber(record.xp) or tonumber(record)
        local perk = BT.ResolvePerk(id)
        if type(id) == "string" and #id <= 128 and BT.IsFinite(value)
            and perk and BT.IsTrainablePerk(perk) then
            result[id] = clampPerkXP(perk, value)
        end
    end
    return result
end

local function getStoreRoot()
    if not ModData or type(ModData.getOrCreate) ~= "function" then return nil end
    local root = ModData.getOrCreate(Server.STORE_KEY)
    root.version = 1
    if type(root.players) ~= "table" then root.players = {} end
    return root
end

local function identityToken(value)
    -- GlobalModData can be requested through vanilla's generic debug/network
    -- API. Keep account names out of the table while retaining a stable key.
    local first = 5381
    local second = 52711
    for index = 1, #value do
        local byte = string.byte(value, index)
        first = (first * 33 + byte) % 4294967291
        second = (second * 65599 + byte) % 4294967291
    end
    return tostring(math.floor(first)) .. "-" .. tostring(math.floor(second))
end

local function getPlayerStoreKey(player)
    local username = ""
    local okUsername, valueUsername = pcall(function() return player:getUsername() end)
    if okUsername and valueUsername ~= nil then username = tostring(valueUsername) end

    -- This is the same authenticated account/slot tuple used by ServerPlayerDB.
    -- SurvivorDesc IDs come from CreatePlayerPacket and are not authoritative.
    local playerIndex = -1
    local okIndex, valueIndex = pcall(function() return player:getIndex() end)
    if okIndex and valueIndex ~= nil then playerIndex = tonumber(valueIndex) or -1 end
    return identityToken("user:" .. username .. "|slot:" .. tostring(playerIndex))
end

local function sanitizeCanonicalXP(values)
    local result = {}
    if type(values) ~= "table" then return result end

    local count = 0
    -- Keep currently loaded perks first so corrupt orphan data can never crowd
    -- an active skill out of the bounded canonical table.
    for id, record in pairs(values) do
        local value = type(record) == "table" and tonumber(record.xp) or tonumber(record)
        local perk = BT.ResolvePerk(id)
        if count < 256 and type(id) == "string" and #id <= 128
            and BT.IsFinite(value) and perk and BT.IsTrainablePerk(perk) then
            result[id] = clampPerkXP(perk, value)
            count = count + 1
        end
    end
    -- Records already present in the server store may belong to a temporarily
    -- disabled custom-perk mod. Preserve bounded opaque IDs until it returns.
    for id, record in pairs(values) do
        local value = type(record) == "table" and tonumber(record.xp) or tonumber(record)
        local perk = BT.ResolvePerk(id)
        if count < 256 and result[id] == nil and type(id) == "string" and #id <= 128
            and BT.IsFinite(value) and (not perk or not BT.IsTrainablePerk(perk)) then
            result[id] = BT.Clamp(value, 0, Server.MAX_UNKNOWN_XP)
            count = count + 1
        end
    end
    return result
end

local function loadCanonicalXP(player)
    local storeKey = getPlayerStoreKey(player)
    local root = getStoreRoot()
    if not root then return loadMirrorXP(player), storeKey, nil end

    local record = root.players[storeKey]
    local values
    local isCanonical = type(record) == "table"
        and (record.migrated == true or type(record.perks) == "table")
    if isCanonical then
        values = sanitizeCanonicalXP(record.perks)
    else
        -- One-time migration from the character-owned B41/B42 schema. After
        -- this record exists, inbound player ModData is never trusted again.
        values = loadMirrorXP(player)
        record = {}
        root.players[storeKey] = record
    end
    record.version = 1
    record.migrated = true
    record.perks = values
    return values, storeKey, record
end

local function publishCanonicalXP(player, state)
    local data = BT.GetData(player, true)
    local mirror = data.perks
    if type(mirror) ~= "table" then
        mirror = {}
        data.perks = mirror
    end

    for id, _record in pairs(mirror) do
        if state.canonicalXP[id] == nil then mirror[id] = nil end
    end
    for id, value in pairs(state.canonicalXP) do
        local perk = BT.ResolvePerk(id)
        if type(id) == "string" and BT.IsFinite(value) then
            if perk and BT.IsTrainablePerk(perk) then
                value = clampPerkXP(perk, value)
            else
                value = BT.Clamp(value, 0, Server.MAX_UNKNOWN_XP)
            end
            state.canonicalXP[id] = value
            local record = mirror[id]
            if type(record) ~= "table" then
                record = {}
                mirror[id] = record
            end
            record.xp = value
        else
            state.canonicalXP[id] = nil
            mirror[id] = nil
        end
    end
end

local function getState(player)
    local state = Server._players[player]
    if not state then
        local canonicalXP, storeKey, storeRecord = loadCanonicalXP(player)
        state = {
            active = {},
            applyingNative = {},
            canonicalXP = canonicalXP,
            storeKey = storeKey,
            storeRecord = storeRecord,
            scanTimer = 0,
            initialized = false,
            restoreAfterSave = false,
        }
        Server._players[player] = state
        publishCanonicalXP(player, state)
    end
    return state
end

local function readCanonicalXP(player, perk)
    if not player or not perk then return nil end
    if player:isDead() then return 0 end
    local state = getState(player)
    local id = perk:getId()
    local value = clampPerkXP(perk, state.canonicalXP[id] or 0)
    state.canonicalXP[id] = value
    return value
end

local function writeCanonicalXP(player, perk, value)
    if not player or not perk then return end
    if player:isDead() then return end
    local state = getState(player)
    state.canonicalXP[perk:getId()] = clampPerkXP(perk, value)
    publishCanonicalXP(player, state)
end

local function exportCanonicalXP(player)
    if not player then return nil end
    if player:isDead() then return {} end
    local state = getState(player)
    local result = {}
    for id, value in pairs(state.canonicalXP) do result[id] = value end
    return result
end

local function clearCanonicalXP(player)
    if not player then return end
    if player:isDead() then return end
    local state = getState(player)
    for id, _value in pairs(state.canonicalXP) do state.canonicalXP[id] = nil end
    publishCanonicalXP(player, state)
end

-- All shared mastery APIs (including bonus providers) read a server-authoritative
-- table persisted in GlobalModData. Player ModData is only a migration/client mirror
-- and cannot author XP once the server record has been created.
BT._storedXPReader = readCanonicalXP
BT._storedXPWriter = writeCanonicalXP
BT._storedXPExporter = exportCanonicalXP
BT._storedXPClearer = clearCanonicalXP

local function setRawXP(player, perk, level)
    if player and perk then player:getXp():setXPToLevel(perk, level) end
end

local function activatePerk(player, perk, state)
    if not player or not perk or BT.GetNativeLevel(player, perk) < BT.NATIVE_MAX_LEVEL then return false end
    local id = perk:getId()
    BT.GetPerkRecord(player, perk, true)
    state.active[id] = { perk = perk, baseline = BT.GetReservoirXP(perk) }
    setRawXP(player, perk, BT.RESERVOIR_LEVEL)
    return true
end

local function sendFullSync(player)
    sendServerCommand(player, BT.MODULE, "Sync", {
        player = player:getOnlineID(),
        perks = BT.ExportXP(player),
    })
end

local function sendPerkSync(player, perk)
    sendServerCommand(player, BT.MODULE, "SyncPerk", {
        player = player:getOnlineID(),
        perk = perk:getId(),
        xp = BT.GetStoredXP(player, perk),
    })
end

local function applyNativeOverflow(player, perk, amount)
    -- The mastery reservoir lives at the level-9 total while the real perk
    -- remains level 10. If a negative award exhausts mastery, reconstruct the
    -- award from the true level-10 boundary so Java keeps the remaining XP
    -- instead of dropping the character to the start of level 9.
    setRawXP(player, perk, BT.NATIVE_MAX_LEVEL)
    player:getXp():AddXP(perk, amount, false, false, false, false)
end

local function captureMasteryDelta(player, perk, state, id, amount)
    local applied = BT.AddStoredXP(player, perk, amount)
    if applied ~= 0 then sendPerkSync(player, perk) end

    local overflow = (tonumber(amount) or 0) - applied
    if overflow < -0.0001 then
        state.active[id] = nil
        state.applyingNative[id] = true
        local ok, errorMessage = pcall(applyNativeOverflow, player, perk, overflow)
        state.applyingNative[id] = nil
        if not ok then error(errorMessage) end
        return false
    end

    setRawXP(player, perk, BT.RESERVOIR_LEVEL)
    return true
end

function Server.ScanPlayer(player, force)
    if not player or player:isDead() then return end
    local state = getState(player)
    state.initialized = true
    if force then BT.RefreshPerkCatalog(true) end

    for _, perk in ipairs(BT.GetTrainablePerks()) do
        local id = perk:getId()
        if BT.GetNativeLevel(player, perk) >= BT.NATIVE_MAX_LEVEL then
            if not state.active[id] then activatePerk(player, perk, state) end
        elseif state.active[id] then
            state.active[id] = nil
        end
    end
end

local function resetReservoirs(player, state)
    local skipCapture = state.restoreAfterSave
    state.restoreAfterSave = false
    for id, active in pairs(state.active) do
        local perk = active.perk
        if not perk or BT.GetNativeLevel(player, perk) < BT.NATIVE_MAX_LEVEL then
            state.active[id] = nil
        else
            local rawXP = tonumber(player:getXp():getXP(perk)) or active.baseline
            local delta = rawXP - active.baseline
            if math.abs(delta) > 0.0001 then
                -- Events.AddXP normally consumed this already. This fallback
                -- preserves compatibility with mods that write the XP map
                -- directly instead of calling XP:AddXP/addXp.
                local cap = BT.GetNativeCapXP(perk)
                local lastRequirement = tonumber(perk:getXp10()) or 0
                local looksLikeExternalRestore = rawXP >= cap - 0.01
                    and delta >= lastRequirement - 0.01
                if skipCapture or looksLikeExternalRestore then
                    setRawXP(player, perk, BT.RESERVOIR_LEVEL)
                else
                    captureMasteryDelta(player, perk, state, id, delta)
                end
            end
        end
    end
end

function Server.OnPlayerUpdate(player)
    if not player or player:isDead() then return end
    local state = getState(player)
    -- ObjectModDataPacket can replace a player's whole ModData table. Restore
    -- the server mirror every tick; gameplay reads never depend on that mirror.
    publishCanonicalXP(player, state)
    if not state.initialized then Server.ScanPlayer(player, false) end
    resetReservoirs(player, state)
    state.scanTimer = state.scanTimer + 1
    if state.scanTimer >= 60 then
        state.scanTimer = 0
        Server.ScanPlayer(player, false)
    end
end

function Server.OnPlayerDeath(player)
    if not player then return end
    local state = Server._players[player]
    local storeKey = state and state.storeKey or getPlayerStoreKey(player)
    local root = getStoreRoot()
    if root and root.players then
        -- Keep an authoritative empty tombstone. Deleting the slot would let a
        -- respawned client's ModData re-enter the one-time migration path.
        root.players[storeKey] = { version = 1, migrated = true, perks = {} }
    end

    local data = BT.GetData(player, true)
    data.perks = {}
    Server._players[player] = nil
end

function Server.OnCharacterDeath(character)
    if character and instanceof(character, "IsoPlayer") then
        Server.OnPlayerDeath(character)
    end
end

function Server.OnTick()
    local players = getOnlinePlayers()
    if not players then return end
    for index = 0, players:size() - 1 do
        Server.OnPlayerUpdate(players:get(index))
    end
end

function Server.OnAddXP(character, perk, amount)
    if not character or not instanceof(character, "IsoPlayer") then return end
    if character:isDead() then return end
    if not perk or not BT.IsTrainablePerk(perk) then return end

    local state = getState(character)
    local id = perk:getId()
    if state.applyingNative[id] then return end
    if BT.GetNativeLevel(character, perk) < BT.NATIVE_MAX_LEVEL then return end
    if not state.active[id] then
        -- Do not count the award that completed vanilla level 10 twice.
        activatePerk(character, perk, state)
        return
    end

    captureMasteryDelta(character, perk, state, id, tonumber(amount) or 0)
end

function Server.OnClientCommand(module, command, player, args)
    if module ~= BT.MODULE or not player then return end
    if command ~= "RequestSync" then return end
    if player:isDead() then return end
    publishCanonicalXP(player, getState(player))
    Server.ScanPlayer(player, true)
    sendFullSync(player)
end

function Server.OnSave()
    -- B42's world-save path triggers this before character serialisation.
    -- Exit/autosave PlayerDB paths can run independently, so the package does
    -- not promise perfectly uninstall-clean raw XP for every shutdown path.
    for player, state in pairs(Server._players) do
        if player then
            publishCanonicalXP(player, state)
            for _, active in pairs(state.active) do
                if active.perk and BT.GetNativeLevel(player, active.perk) >= BT.NATIVE_MAX_LEVEL then
                    setRawXP(player, active.perk, BT.NATIVE_MAX_LEVEL)
                end
            end
            state.restoreAfterSave = true
        end
    end
end

local function installPassiveProtection()
    if not xpUpdate or type(xpUpdate.checkForLosingLevel) ~= "function" then return end
    if xpUpdate._BeyondTenB42OriginalCheckForLosingLevel then return end

    xpUpdate._BeyondTenB42OriginalCheckForLosingLevel = xpUpdate.checkForLosingLevel
    xpUpdate.checkForLosingLevel = function(player, perk)
        local passive = perk == Perks.Strength or perk == Perks.Fitness
        if player and passive and BT.GetNativeLevel(player, perk) >= BT.NATIVE_MAX_LEVEL then
            local state = Server._players[player]
            local id = perk:getId()
            local active = state and state.active[id]
            if active then
                -- B42.19 normally emits AddXP for addXp as well. This raw-delta
                -- path remains a fallback for direct XP-map writers and runs
                -- before vanilla can restore the level-9 reservoir.
                local rawXP = tonumber(player:getXp():getXP(perk)) or active.baseline
                local delta = rawXP - active.baseline
                if math.abs(delta) > 0.0001 then
                    captureMasteryDelta(player, perk, state, id, delta)
                else
                    setRawXP(player, perk, BT.RESERVOIR_LEVEL)
                end
                return
            end
        end
        return xpUpdate._BeyondTenB42OriginalCheckForLosingLevel(player, perk)
    end
end

local function onServerStarted()
    Server._players = setmetatable({}, { __mode = "k" })
    BT.RefreshPerkCatalog(true)
    installPassiveProtection()
end

local function onInitGlobalModData()
    -- GlobalModData.init() replaces every loaded table. Drop any pre-init
    -- references defensively; the next player tick binds to the loaded store.
    Server._players = setmetatable({}, { __mode = "k" })
end

if not Server._eventsInstalled then
    Server._eventsInstalled = true
    Events.OnServerStarted.Add(onServerStarted)
    Events.OnInitGlobalModData.Add(onInitGlobalModData)
    Events.OnTick.Add(Server.OnTick)
    Events.AddXP.Add(Server.OnAddXP)
    Events.OnClientCommand.Add(Server.OnClientCommand)
    Events.OnSave.Add(Server.OnSave)
    Events.OnServerStartSaving.Add(Server.OnSave)
    Events.OnCharacterDeath.Add(Server.OnCharacterDeath)
end

installPassiveProtection()
print("[BeyondTen/B42] server boot OK v" .. BT.VERSION)
