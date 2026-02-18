-- ============================================================================
-- File: media/lua/client/RegionManager_PVP.lua
-- Client-side PVP state management module
-- Handles player Safety state based on zone properties and broadcasts to server
-- ============================================================================
if isServer() then
    return
end

require "RegionManager_Config"
require "RegionManager_ClientTick"

RegionManager.PVP = RegionManager.PVP or {}

-- Track required Safety state per player
local RequiredSafetyState = {} -- [playerNum] = boolean (true=safe, false=pvp, nil=no enforcement)

-- Abuse detection tracking
local ToggleAttempts = {} -- [playerNum] = { {timestamp1}, {timestamp2}, ... }
local FlaggedPlayers = {} -- [playerNum] = { startTick = number, endTick = number, totalTicks = number }

-- Constants for abuse detection
local MAX_TOGGLES = 5 -- Maximum allowed toggles
local DETECTION_WINDOW = 10 -- Time window in seconds
local PUNISHMENT_DURATION = 500 -- Punishment duration in ticks

local function log(msg)
    RegionManager.Log("PVP", msg)
end

-- ============================================================================
-- Abuse Detection System
-- Tracks toggle attempts and flags abusive players
-- ============================================================================
---@param playerNum number
---@return boolean isAbusing
local function trackToggleAttempt(player)
    local playerNum = player:getPlayerNum()
    local currentTime = getTimestampMs() / 1000 -- Convert to seconds

    if not ToggleAttempts[playerNum] then
        ToggleAttempts[playerNum] = {}
    end

    -- Add current attempt
    table.insert(ToggleAttempts[playerNum], currentTime)

    -- Remove attempts older than detection window
    local validAttempts = {}
    for _, timestamp in ipairs(ToggleAttempts[playerNum]) do
        if currentTime - timestamp <= DETECTION_WINDOW then
            
            table.insert(validAttempts, timestamp)
        end
    end
    ToggleAttempts[playerNum] = validAttempts

    -- Check if player is abusing
    if #validAttempts > MAX_TOGGLES then
        return true
    end

    return false
end

---@param playerNum number
local function flagPlayer(playerNum)
    FlaggedPlayers[playerNum] = {
        totalTicks = 0
    }

    log(" Player " .. playerNum .. " FLAGGED for PVP toggle abuse! Punishment: " .. PUNISHMENT_DURATION .. " ticks")
end

---@param playerNum number
---@return boolean isFlagged
local function isPlayerFlagged(playerNum)
    if not FlaggedPlayers[playerNum] then
        return false
    end

    local flagData = FlaggedPlayers[playerNum]

    -- Check if punishment period has ended
    if flagData.totalTicks >= PUNISHMENT_DURATION then
        FlaggedPlayers[playerNum] = nil
        ToggleAttempts[playerNum] = {} -- Reset attempts
        log(" Player " .. playerNum .. " punishment completed. Flags cleared.")
        return false
    end

    return true
end

-- ============================================================================
-- Tick Handler
-- Continuously enforces the required Safety state and manages punishments
-- ============================================================================
---@param player IsoPlayer
---@param currentZones table<string, ClientZoneData>
local function onTick(player, currentZones)
    if not player then
        return
    end

    local playerNum = player:getPlayerNum()
    local requiredState = RequiredSafetyState[playerNum]
    local isFlagged = isPlayerFlagged(playerNum)

    -- Only enforce if we have a required state
    if requiredState ~= nil then

        local currentState = player:getSafety():isEnabled()

        -- If player somehow changed it, detect abuse and revert
        if currentState ~= requiredState then

            -- Track this toggle attempt
            local isAbusing = trackToggleAttempt(player)

            -- Flag player if they're abusing the system
            if isAbusing and not isFlagged then
                player:Say("Abuso de Toogle detectado! Seu status PVP foi travado. Aguarde.")
                flagPlayer(playerNum)
                isFlagged = true
            end

            -- Revert the toggle
            player:getSafety():setCooldown(0)
            player:getSafety():toggleSafety()

            -- Sync the corrected state with the server
            sendClientCommand("RegionManager", "UpdatePvpState", {
                zoneId = nil,
                zoneName = "State Correction",
                isPvpZone = (requiredState == false),
                isSafeZone = (requiredState == true),
                safetyEnabled = requiredState
            })

            if isFlagged then
                log(
                    " FLAGGED player " .. playerNum .. " - State forcibly corrected (Safety=" .. tostring(requiredState) ..
                        ")")
            else
                log("State corrected and synced with server (Safety=" .. tostring(requiredState) .. ")")
            end
        end

        -- If player is flagged, continuously enforce state and increment punishment counter
        if isFlagged then
            local flagData = FlaggedPlayers[playerNum]
            flagData.totalTicks = flagData.totalTicks + 1
            -- Force the correct state every tick during punishment
            if player:getSafety():isEnabled() ~= requiredState then
                player:getSafety():toggleSafety()
            end
            player:getSafety():setCooldown(500 - flagData.totalTicks)

            -- Log progress every 100 ticks
            if flagData.totalTicks % 100 == 0 then
                local remaining = PUNISHMENT_DURATION - flagData.totalTicks
                log(" Player " .. playerNum .. " punishment: " .. flagData.totalTicks .. "/" .. PUNISHMENT_DURATION ..
                        " ticks (" .. remaining .. " remaining)")
            end
        end
    end
end

-- ============================================================================
-- Zone Enter Handler
-- Called when player enters a zone, applies PVP/Safe zone rules
-- Ensures flagged players receive correct state for new zone
-- ============================================================================
---@param player IsoPlayer
---@param zoneId string
---@param zoneData ClientZoneData
local function onZoneEntered(player, zoneId, zoneData)
    if not player then
        return
    end
    local playerNum = player:getPlayerNum()
    player:getSafety():setCooldown(0)
    FlaggedPlayers[playerNum] = nil
    ToggleAttempts[playerNum] = {} -- Reset attempts
    local isSafeZone = (zoneData.pvpEnabled == false)
    local isPvpZone = (zoneData.pvpEnabled == true)
    local isFlagged = isPlayerFlagged(playerNum)

    -- Apply Safety state locally and track required state
    if isPvpZone then
        if (player:getSafety():isEnabled()) then
            player:getSafety():toggleSafety()
        end
        RequiredSafetyState[playerNum] = false

        if isFlagged then
            log(" FLAGGED player " .. playerNum .. " entered PVP zone: " .. zoneData.name ..
                    " (Safety=false, punishment active)")
        else
            log("Applied PVP state locally for zone: " .. zoneData.name .. " (Safety=false)")
        end
    elseif isSafeZone then
        -- Since version 42.13.2+ safezones were fixed, there is no need to toogle pvp when user enters a non-pvp zone.
        if not (player:getSafety():isEnabled()) then
            player:getSafety():toggleSafety()
        end
        RequiredSafetyState[playerNum] = true

        if isFlagged then
            log(" FLAGGED player " .. playerNum .. " entered Safe zone: " .. zoneData.name ..
                    " (Safety=true, punishment active)")
        else
            log("Applied Safe Zone state locally for zone: " .. zoneData.name .. " (Safety=true)")
        end
    else
        -- Neutral zone - no PVP state change
        -- automatic non-pvp zones are generated, the code shouldn't fall in here naturally, 
        -- zones are always being entered when leaving another one, and if it is a non-pvp
        -- then the pvp state get's changed to safety = true
        -- other implementations may use the onExit hook since they will need to manage
        -- exiting their specific state
        RequiredSafetyState[playerNum] = nil
        return
    end

    -- Notify server to broadcast this player's PVP state to other clients
    sendClientCommand("RegionManager", "UpdatePvpState", {
        zoneId = zoneId,
        zoneName = zoneData.name,
        isPvpZone = isPvpZone,
        isSafeZone = isSafeZone,
        safetyEnabled = player:getSafety():isEnabled()
    })

    log("Sent PVP state update to server for zone: " .. zoneData.name)
end

-- ============================================================================
-- Zone Exit Handler
-- Called when player exits a zone
-- ============================================================================
---@param player IsoPlayer
---@param zoneId string
---@param zoneData ClientZoneData
local function onZoneExited(player, zoneId, zoneData)
    if not player then
        return
    end

    -- Note: We don't restore Safety toggle because player will always be in 
    -- either a PVP or Safe zone. The next zone entry will handle the state.
    log("Player exited zone: " .. zoneData.name)

    -- Optional: Notify server about zone exit if needed for tracking
    -- sendClientCommand("RegionManager", "UpdatePvpState", {
    --     zoneId = nil,
    --     zoneName = "None",
    --     isPvpZone = false,
    --     isSafeZone = false,
    --     safetyEnabled = player:getSafety():isEnabled()
    -- })
end
local function getSpecificPlayer(username)
    local allPlayers = getOnlinePlayers()
    for i = 0, allPlayers:size() - 1 do
        local otherPlayer = allPlayers:get(i)
        if otherPlayer.username == username then
            return otherPlayer
        end
    end
end
-- ============================================================================
-- Server Command Handler
-- Receives PVP state updates from server about other players
-- ============================================================================
---@param module string
---@param command string
---@param args table
local function OnServerCommand(module, command, args)
    if module ~= "RegionManager" then
        return
    end

    if command == "PvpStateChanged" then
        -- Another player's PVP state changed - update their skull icon
        -- local targetPlayer = getSpecificPlayer(args.username)
        -- if targetPlayer then
        --     if args.isPvpZone == true then
        --         -- Other player entered PVP zone
        --         targetPlayer:getSafety():setEnabled(false)
        --         log("Updated player " .. args.username .. " PVP state: ENABLED (Safety=false)")
        --     elseif args.isSafeZone == true then
        --         -- Other player entered safe zone
        --         targetPlayer:getSafety():setEnabled(true)
        --         log("Updated player " .. args.username .. " PVP state: DISABLED (Safety=true)")
        --     end
        -- else
        --     -- log("WARNING: Could not find player with index " .. args.username)
        -- end
    end
end

-- ============================================================================
-- Module Registration
-- Register this module with ClientTick dispatcher
-- ============================================================================
local function initPvpModule()
    RegionManager.ClientTick.registerModule({
        name = "PVP",
        onZoneEntered = onZoneEntered,
        onZoneExited = onZoneExited,
        onTick = onTick
    })

    log("PVP module registered with ClientTick dispatcher (with onTick enforcement)")
end

-- ============================================================================
-- Event Registration
-- ============================================================================
Events.OnServerCommand.Add(OnServerCommand)
Events.OnGameStart.Add(initPvpModule)

log("RegionManager PVP module loaded")

return RegionManager.PVP
