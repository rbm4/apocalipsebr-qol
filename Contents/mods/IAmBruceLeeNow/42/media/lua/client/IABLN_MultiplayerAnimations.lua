
local MODULE = "IABLN"
local COMMAND = "syncAnimationState"
local HEARTBEAT_MS = 1500
local STALE_STATE_MS = 5000

local lastLocalState = {}
local remoteStates = {}

local function getLocalState(player)
    local combo = tonumber(player:getVariableString("IABLNCombo")) or 0
    return {
        active = player:getVariableBoolean("IABLNActive"),
        combo = math.max(0, math.min(6, combo)),
        left = player:getVariableBoolean("IABLNLeftStance"),
        attacking = player:getVariableBoolean("AttackAnim"),
    }
end

local function stateChanged(previous, current)
    return not previous or previous.active ~= current.active or
        previous.combo ~= current.combo or previous.left ~= current.left or
        previous.attacking ~= current.attacking
end

local function sendLocalState(player, now)
    if not isClient() or not player then return end

    local playerNum = player:getPlayerNum()
    local current = getLocalState(player)
    local previous = lastLocalState[playerNum]
    if not stateChanged(previous, current) and
            now - (previous.sentAt or 0) < HEARTBEAT_MS then
        return
    end

    sendClientCommand(player, MODULE, COMMAND, current)
    current.sentAt = now
    lastLocalState[playerNum] = current
end

local function applyRemoteState(player, state)
    if not player or IsoPlayer.isLocalPlayer(player) then return end
    player:setVariable("IABLNActive", state.active == true)
    player:setVariable("IABLNCombo", tostring(state.combo or 0))
    player:setVariable("IABLNLeftStance", state.left == true)
    if state.active == true then
        -- The owner and server can both have the authoritative hidden proxy
        -- while a remote observer still sees primary=nil and Weapon="" until a
        -- traversal transition refreshes equipped-hand state. Our custom nodes
        -- live in melee/1handed, so maintain only the observer-side animation
        -- selector while the server-validated IABLN state is active.
        player:setVariable("Weapon", "1handed")
    end
    player:setVariable("AttackAnim", state.attacking == true)
end

local function updateAnimationReplication()
    if not isClient() then return end
    local now = getTimestampMs()

    for playerNum = 0, getNumActivePlayers() - 1 do
        sendLocalState(getSpecificPlayer(playerNum), now)
    end

    local onlinePlayers = getOnlinePlayers()
    for index = 0, onlinePlayers:size() - 1 do
        local player = onlinePlayers:get(index)
        if player and not IsoPlayer.isLocalPlayer(player) then
            local onlineID = player:getOnlineID()
            local state = remoteStates[onlineID]
            if state and now - state.receivedAt <= STALE_STATE_MS then
                applyRemoteState(player, state)
            elseif state then
                player:setVariable("IABLNActive", false)
                player:setVariable("IABLNCombo", "0")
                player:setVariable("IABLNLeftStance", false)
                player:setVariable("AttackAnim", false)
                remoteStates[onlineID] = nil
            end
        end
    end
end

local function onServerCommand(module, command, args)
    if module ~= MODULE or command ~= COMMAND or not args then return end

    local onlineID = tonumber(args.onlineID)
    local combo = tonumber(args.combo) or 0
    if not onlineID or combo < 0 or combo > 6 then return end

    local localPlayer = getPlayer()
    if localPlayer and localPlayer:getOnlineID() == onlineID then return end

    local state = {
        active = args.active == true,
        combo = combo,
        left = args.left == true,
        attacking = args.attacking == true,
        receivedAt = getTimestampMs(),
    }
    remoteStates[onlineID] = state
    local remotePlayer = getPlayerByOnlineID(onlineID)
    applyRemoteState(remotePlayer, state)
end

Events.OnTick.Add(updateAnimationReplication)
Events.OnServerCommand.Add(onServerCommand)
