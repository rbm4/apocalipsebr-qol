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
            scanTimer = 0,
            restoreAfterSave = false,
            requestedSync = false,
        }
        Client._players[player] = state
    end
    return state
end

local function setRawXP(player, perk, level)
    if player and perk then player:getXp():setXPToLevel(perk, level) end
end

local function activatePerk(player, perk, state)
    if not player or not perk or BT.GetNativeLevel(player, perk) < BT.NATIVE_MAX_LEVEL then return false end
    local id = perk:getId()
    BT.GetPerkRecord(player, perk, true)
    state.active[id] = {
        perk = perk,
        baseline = BT.GetReservoirXP(perk),
    }
    setRawXP(player, perk, BT.RESERVOIR_LEVEL)
    return true
end

local function notifyLevelUp(player, perk, oldLevel, newLevel)
    if newLevel <= oldLevel or newLevel <= BT.NATIVE_MAX_LEVEL then return end
    local message = getText("IGUI_BeyondTen_LevelUp", perk:getName(), newLevel)
    HaloTextHelper.addTextWithArrow(player, message, true, HaloTextHelper.getColorGreen())
    local emitter = player:getEmitter()
    if emitter and not emitter:isPlaying("GainExperienceLevel") then
        emitter:playSound("GainExperienceLevel")
    end
end

local function sendDelta(player, perk, amount)
    if not isClient() or not player or amount == 0 then return end
    sendClientCommand(player, BT.MODULE, "AddXP", {
        perk = perk:getId(),
        amount = amount,
    })
end

local function addMasteryXP(player, perk, amount, synchronize)
    local applied, oldLevel, newLevel = BT.AddStoredXP(player, perk, amount)
    if applied ~= 0 then
        if synchronize ~= false then sendDelta(player, perk, applied) end
        notifyLevelUp(player, perk, oldLevel, newLevel)
    end
    return applied
end

function Client.ScanPlayer(player, force)
    if not player or player:isDead() then return end
    local state = getState(player)
    if force then BT.RefreshPerkCatalog(true) end

    for _, perk in ipairs(BT.GetTrainablePerks()) do
        local id = perk:getId()
        local nativeLevel = BT.GetNativeLevel(player, perk)
        if nativeLevel >= BT.NATIVE_MAX_LEVEL then
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
                if not skipCapture then
                    local cap = BT.GetNativeCapXP(perk)
                    local lastRequirement = tonumber(perk:getXp10()) or 0
                    local looksLikeExternalRestore = rawXP >= cap - 0.01 and delta >= lastRequirement - 0.01
                    if not looksLikeExternalRestore then
                        addMasteryXP(player, perk, delta, true)
                    end
                end
                setRawXP(player, perk, BT.RESERVOIR_LEVEL)
            end
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
    state.allowStrengthLoss = false
end

function Client.OnAddXP(character, perk, amount)
    if not character or not perk or not isLocalPlayer(character) then return end
    if not BT.IsTrainablePerk(perk) then return end
    if BT.GetNativeLevel(character, perk) < BT.NATIVE_MAX_LEVEL then return end

    local state = getState(character)
    local active = state.active[perk:getId()]
    if not active then
        -- The XP award that reached native level 10 belongs to level 10. The
        -- mastery reservoir starts only after that award has finished.
        activatePerk(character, perk, state)
        return
    end

    local numericAmount = tonumber(amount) or 0
    local storedBefore = BT.GetStoredXP(character, perk)
    if perk == Perks.Strength and numericAmount < 0 and storedBefore + numericAmount < 0 then
        state.allowStrengthLoss = true
    end
    addMasteryXP(character, perk, numericAmount, true)
    setRawXP(character, perk, BT.RESERVOIR_LEVEL)
end

function Client.OnSave()
    for player, state in pairs(Client._players) do
        if player then
            for _, active in pairs(state.active) do
                if active.perk and BT.GetNativeLevel(player, active.perk) >= BT.NATIVE_MAX_LEVEL then
                    setRawXP(player, active.perk, BT.NATIVE_MAX_LEVEL)
                end
            end
            state.restoreAfterSave = true
        end
    end
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
        if perk then BT.SetStoredXP(player, perk, tonumber(args.xp) or 0) end
    end
end

local function installStrengthProtection()
    if not xpUpdate or type(xpUpdate.checkForLosingLevel) ~= "function" then return end
    if xpUpdate._BeyondTenOriginalCheckForLosingLevel then return end

    xpUpdate._BeyondTenOriginalCheckForLosingLevel = xpUpdate.checkForLosingLevel
    xpUpdate.checkForLosingLevel = function(player, perk)
        if player and perk == Perks.Strength and BT.GetNativeLevel(player, perk) >= BT.NATIVE_MAX_LEVEL then
            local state = Client._players[player]
            if state and state.allowStrengthLoss then
                state.allowStrengthLoss = false
                state.active[perk:getId()] = nil
                return xpUpdate._BeyondTenOriginalCheckForLosingLevel(player, perk)
            end
            setRawXP(player, perk, BT.RESERVOIR_LEVEL)
            return
        end
        return xpUpdate._BeyondTenOriginalCheckForLosingLevel(player, perk)
    end
end

local function onCreatePlayer(_playerIndex, player)
    Client.InitializePlayer(player)
end

local function onGameStart()
    Client._players = setmetatable({}, { __mode = "k" })
    BT.RefreshPerkCatalog(true)
    installStrengthProtection()
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

installStrengthProtection()
print("[BeyondTen] client boot OK v" .. BT.VERSION)
