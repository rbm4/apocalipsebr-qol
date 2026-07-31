require "BeyondTen/Shared"

if not isServer() then return end

BeyondTenServer = BeyondTenServer or {}

local BT = BeyondTen
local Server = BeyondTenServer

Server._players = Server._players or setmetatable({}, { __mode = "k" })

local function getState(player)
    local state = Server._players[player]
    if not state then
        state = { active = {}, scanTimer = 0, restoreAfterSave = false }
        Server._players[player] = state
    end
    return state
end

local function setRawXP(player, perk, level)
    if player and perk then player:getXp():setXPToLevel(perk, level) end
end

local function activatePerk(player, perk, state)
    if BT.GetNativeLevel(player, perk) < BT.NATIVE_MAX_LEVEL then return false end
    local id = perk:getId()
    BT.GetPerkRecord(player, perk, true)
    state.active[id] = { perk = perk, baseline = BT.GetReservoirXP(perk) }
    setRawXP(player, perk, BT.RESERVOIR_LEVEL)
    return true
end

function Server.ScanPlayer(player, force)
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

local function resetReservoirs(player, state)
    local skip = state.restoreAfterSave
    state.restoreAfterSave = false
    for id, active in pairs(state.active) do
        local perk = active.perk
        if not perk or BT.GetNativeLevel(player, perk) < BT.NATIVE_MAX_LEVEL then
            state.active[id] = nil
        else
            -- Native MP AddXP packets are still allowed into the Java XP map,
            -- but mastery itself is synchronized with the owner's final,
            -- post-multiplier AddXP amount through the command below.
            local rawXP = tonumber(player:getXp():getXP(perk)) or active.baseline
            if math.abs(rawXP - active.baseline) > 0.0001 then
                setRawXP(player, perk, BT.RESERVOIR_LEVEL)
            end
        end
    end
    return skip
end

function Server.OnPlayerUpdate(player)
    if not player then return end
    local state = getState(player)
    resetReservoirs(player, state)
    state.scanTimer = state.scanTimer + 1
    if state.scanTimer >= 60 then
        state.scanTimer = 0
        Server.ScanPlayer(player, false)
    end
end

function Server.OnTick()
    local players = getOnlinePlayers()
    if not players then return end
    for index = 0, players:size() - 1 do
        Server.OnPlayerUpdate(players:get(index))
    end
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

function Server.OnClientCommand(module, command, player, args)
    if module ~= BT.MODULE or not player then return end
    args = type(args) == "table" and args or {}

    if command == "RequestSync" then
        Server.ScanPlayer(player, true)
        sendFullSync(player)
        return
    end

    if command ~= "AddXP" then return end
    if type(args.perk) ~= "string" or not BT.IsFinite(args.amount) then return end
    local perk = BT.ResolvePerk(args.perk)
    if not perk or not BT.IsTrainablePerk(perk) then return end
    if BT.GetNativeLevel(player, perk) < BT.NATIVE_MAX_LEVEL then return end

    local maximumAward = math.max(1, tonumber(perk:getXp10()) or 1)
    local amount = tonumber(args.amount)
    if math.abs(amount) > maximumAward + 0.01 then return end
    if amount == 0 then return end

    local state = getState(player)
    if not state.active[perk:getId()] then activatePerk(player, perk, state) end
    BT.AddStoredXP(player, perk, amount)
    setRawXP(player, perk, BT.RESERVOIR_LEVEL)
    sendPerkSync(player, perk)
end

function Server.OnSave()
    for player, state in pairs(Server._players) do
        if player then
            for _, active in pairs(state.active) do
                if active.perk and BT.GetNativeLevel(player, active.perk) >= BT.NATIVE_MAX_LEVEL then
                    setRawXP(player, active.perk, BT.NATIVE_MAX_LEVEL)
                end
            end
            player:getXp():recalcSumm()
            state.restoreAfterSave = true
        end
    end
end

local function installStrengthProtection()
    if not xpUpdate or type(xpUpdate.checkForLosingLevel) ~= "function" then return end
    if xpUpdate._BeyondTenOriginalCheckForLosingLevel then return end

    xpUpdate._BeyondTenOriginalCheckForLosingLevel = xpUpdate.checkForLosingLevel
    xpUpdate.checkForLosingLevel = function(player, perk)
        if player and perk == Perks.Strength and BT.GetNativeLevel(player, perk) >= BT.NATIVE_MAX_LEVEL then
            setRawXP(player, perk, BT.RESERVOIR_LEVEL)
            return
        end
        return xpUpdate._BeyondTenOriginalCheckForLosingLevel(player, perk)
    end
end

local function onServerStarted()
    Server._players = setmetatable({}, { __mode = "k" })
    BT.RefreshPerkCatalog(true)
    installStrengthProtection()
end

if not Server._eventsInstalled then
    Server._eventsInstalled = true
    Events.OnServerStarted.Add(onServerStarted)
    -- Dedicated-server players are remote IsoPlayers and do not emit the
    -- normal OnPlayerUpdate event. OnTick covers every connected player.
    Events.OnTick.Add(Server.OnTick)
    Events.OnClientCommand.Add(Server.OnClientCommand)
    Events.OnSave.Add(Server.OnSave)
end

installStrengthProtection()
print("[BeyondTen] server boot OK v" .. BT.VERSION)
