require "BeyondTen/Shared"

BeyondTenClient = BeyondTenClient or {}

local BT = BeyondTen
local Client = BeyondTenClient

Client._players = Client._players or setmetatable({}, { __mode = "k" })

local function isLocalPlayer(player)
    if not player then return false end
    for playerIndex = 0, getNumActivePlayers() - 1 do
        if getSpecificPlayer(playerIndex) == player then return true end
    end
    return false
end

local function getState(player)
    local state = Client._players[player]
    if not state then
        state = {
            active = {},
            applyingNative = {},
            scanTimer = 0,
            requestedSync = false,
            restoreAfterSave = false,
        }
        Client._players[player] = state
    end
    return state
end

local function setRawXP(player, perk, level)
    -- B42 multiplayer XP is server-authoritative. A client must never write
    -- its Java XP map; it only mirrors mastery ModData received by command.
    if not isClient() and player and perk then
        player:getXp():setXPToLevel(perk, level)
    end
end

local function activatePerk(player, perk, state)
    if not player or not perk or BT.GetNativeLevel(player, perk) < BT.NATIVE_MAX_LEVEL then return false end
    local id = perk:getId()
    BT.GetPerkRecord(player, perk, true)
    state.active[id] = { perk = perk, baseline = BT.GetReservoirXP(perk) }
    setRawXP(player, perk, BT.RESERVOIR_LEVEL)
    return true
end

local function notifyLevelUp(player, perk, oldLevel, newLevel)
    if newLevel <= oldLevel or newLevel <= BT.NATIVE_MAX_LEVEL then return end
    local message = getText("IGUI_BeyondTen_LevelUp", perk:getName(), newLevel)
    HaloTextHelper.addTextWithArrow(player, message, "[br/]", true, HaloTextHelper.getGoodColor())
    local emitter = player:getEmitter()
    if emitter and not emitter:isPlaying("GainExperienceLevel") then
        emitter:playSound("GainExperienceLevel")
    end
end

local function addMasteryXP(player, perk, amount)
    local applied, oldLevel, newLevel = BT.AddStoredXP(player, perk, amount)
    if applied ~= 0 then notifyLevelUp(player, perk, oldLevel, newLevel) end
    return applied
end

local function applyNativeOverflow(player, perk, amount)
    -- Reapply the unabsorbed negative award from the true level-10 boundary.
    -- This preserves cap-minus-X XP when mastery is exhausted instead of
    -- leaving the character at the beginning of level 9.
    setRawXP(player, perk, BT.NATIVE_MAX_LEVEL)
    player:getXp():AddXP(perk, amount, false, false, false, false)
end

local function captureMasteryDelta(player, perk, state, id, amount)
    local applied = addMasteryXP(player, perk, amount)
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

function Client.ScanPlayer(player, force)
    if not player or player:isDead() then return end
    local state = getState(player)
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

function Client.InitializePlayer(player)
    if not player or not isLocalPlayer(player) then return end
    local state = getState(player)
    Client.ScanPlayer(player, true)
    if isClient() and not state.requestedSync then
        state.requestedSync = true
        sendClientCommand(player, BT.MODULE, "RequestSync", {})
    end
end

local function pollActivePerks(player, state)
    if isClient() then return end
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
                -- Some mods restore the visible level-10 total directly.
                -- Do not mistake that maintenance write for a giant XP award.
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

function Client.OnSave()
    if isClient() then return end
    -- GameWindow's B42 world-save path emits OnSave before serialising the
    -- character. Temporarily expose the real level-10 total so a save remains
    -- usable without the mod; the reservoir is restored on the next update.
    for player, state in pairs(Client._players) do
        if player then
            for _, active in pairs(state.active) do
                if active.perk and BT.GetNativeLevel(player, active.perk) >= BT.NATIVE_MAX_LEVEL then
                    player:getXp():setXPToLevel(active.perk, BT.NATIVE_MAX_LEVEL)
                end
            end
            state.restoreAfterSave = true
        end
    end
end

function Client.OnPlayerUpdate(player)
    if not player or not isLocalPlayer(player) then return end
    local state = getState(player)
    pollActivePerks(player, state)
    state.scanTimer = state.scanTimer + 1
    if state.scanTimer >= 60 then
        state.scanTimer = 0
        Client.ScanPlayer(player, false)
    end
end

function Client.OnAddXP(character, perk, amount)
    -- In B42 this event is emitted in singleplayer and on the dedicated
    -- server, but not by an MP client. The guard also prevents double credit
    -- if another mod manually triggers the event client-side.
    if isClient() then return end
    if not character or not perk or not isLocalPlayer(character) then return end
    if not BT.IsTrainablePerk(perk) then return end

    local state = getState(character)
    local id = perk:getId()
    if state.applyingNative[id] then return end
    if BT.GetNativeLevel(character, perk) < BT.NATIVE_MAX_LEVEL then return end
    local active = state.active[id]
    if not active then
        -- The award that reached native level 10 belongs to level 10.
        activatePerk(character, perk, state)
        return
    end

    captureMasteryDelta(character, perk, state, id, tonumber(amount) or 0)
end

function Client.OnServerCommand(module, command, args)
    if module ~= BT.MODULE or type(args) ~= "table" then return end
    local player = nil
    local onlineID = tonumber(args.player)
    for playerIndex = 0, getNumActivePlayers() - 1 do
        local candidate = getSpecificPlayer(playerIndex)
        if candidate and (onlineID == nil or tonumber(candidate:getOnlineID()) == onlineID) then
            player = candidate
            break
        end
    end
    if onlineID ~= nil and not player then return end
    player = player or getPlayer()
    if not player then return end

    if command == "Sync" and type(args.perks) == "table" then
        BT.ImportXP(player, args.perks, true)
        Client.ScanPlayer(player, true)
    elseif command == "SyncPerk" then
        local perk = BT.ResolvePerk(args.perk)
        if perk then
            local oldLevel = BT.GetEffectiveLevel(player, perk)
            BT.SetStoredXP(player, perk, tonumber(args.xp) or 0)
            notifyLevelUp(player, perk, oldLevel, BT.GetEffectiveLevel(player, perk))
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
            local state = Client._players[player]
            local id = perk:getId()
            local active = state and state.active[id]
            if active then
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

local function onCreatePlayer(_playerIndex, player)
    Client.InitializePlayer(player)
end

local function onGameStart()
    Client._players = setmetatable({}, { __mode = "k" })
    BT.RefreshPerkCatalog(true)
    installPassiveProtection()
    for playerIndex = 0, getNumActivePlayers() - 1 do
        Client.InitializePlayer(getSpecificPlayer(playerIndex))
    end
end

if not Client._eventsInstalled then
    Client._eventsInstalled = true
    Events.OnCreatePlayer.Add(onCreatePlayer)
    Events.OnGameStart.Add(onGameStart)
    Events.OnPlayerUpdate.Add(Client.OnPlayerUpdate)
    Events.AddXP.Add(Client.OnAddXP)
    Events.OnSave.Add(Client.OnSave)
    Events.OnServerCommand.Add(Client.OnServerCommand)
end

installPassiveProtection()
print("[BeyondTen/B42] client boot OK v" .. BT.VERSION)
