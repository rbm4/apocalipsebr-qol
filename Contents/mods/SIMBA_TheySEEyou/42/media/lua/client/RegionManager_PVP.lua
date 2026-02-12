-- ============================================================================
-- File: media/lua/client/RegionManager_PVP.lua
-- Client-side PVP state management module
-- Handles player Safety state based on zone properties and broadcasts to server
-- ============================================================================

if isServer() then return end

require "RegionManager_Config"
require "RegionManager_ClientTick"

RegionManager.PVP = RegionManager.PVP or {}

-- Track required Safety state per player
local RequiredSafetyState = {} -- [playerNum] = boolean (true=safe, false=pvp, nil=no enforcement)

local function log(msg)
    RegionManager.Log("PVP", msg)
end

-- ============================================================================
-- Tick Handler
-- Continuously enforces the required Safety state without using cooldown
-- ============================================================================
---@param player IsoPlayer
---@param currentZones table<string, ClientZoneData>
local function onTick(player, currentZones)
    if not player then return end
    
    local playerNum = player:getPlayerNum()
    local requiredState = RequiredSafetyState[playerNum]
    
    -- Only enforce if we have a required state
    if requiredState ~= nil then
        
        local currentState = player:getSafety():isEnabled()
        
        -- If player somehow changed it, revert immediately
        if currentState ~= requiredState then
            player:getSafety():setEnabled(requiredState)
            player:getSafety():setCooldown(0)
            player:getSafety():setToggle(0)
            
            -- Sync the corrected state with the server
            sendClientCommand("RegionManager", "UpdatePvpState", {
                zoneId = nil,
                zoneName = "State Correction",
                isPvpZone = (requiredState == false),
                isSafeZone = (requiredState == true),
                safetyEnabled = requiredState
            })
            
            log("State corrected and synced with server (Safety=" .. tostring(requiredState) .. ")")
        end
    end
end

-- ============================================================================
-- Zone Enter Handler
-- Called when player enters a zone, applies PVP/Safe zone rules
-- ============================================================================
---@param player IsoPlayer
---@param zoneId string
---@param zoneData ClientZoneData
local function onZoneEntered(player, zoneId, zoneData)
    if not player then return end
    
    local isSafeZone = (zoneData.pvpEnabled == false)
    local isPvpZone  = (zoneData.pvpEnabled == true)
    local playerNum = player:getPlayerNum()
    
    -- Apply Safety state locally and track required state
    if isPvpZone then
        player:getSafety():setEnabled(false)
        RequiredSafetyState[playerNum] = false
        log("Applied PVP state locally for zone: " .. zoneData.name .. " (Safety=false)")
    elseif isSafeZone then
        player:getSafety():setEnabled(true)
        RequiredSafetyState[playerNum] = true
        log("Applied Safe Zone state locally for zone: " .. zoneData.name .. " (Safety=true)")
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
    if not player then return end
    
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
    if module ~= "RegionManager" then return end
    
    if command == "PvpStateChanged" then
        -- Another player's PVP state changed - update their skull icon
        local targetPlayer = getSpecificPlayer(args.username)
        if targetPlayer then
            if args.isPvpZone == true then
                -- Other player entered PVP zone
                targetPlayer:getSafety():setEnabled(false)
                log("Updated player " .. args.username .. " PVP state: ENABLED (Safety=false)")
            elseif args.isSafeZone == true then
                -- Other player entered safe zone
                targetPlayer:getSafety():setEnabled(true)
                log("Updated player " .. args.username .. " PVP state: DISABLED (Safety=true)")
            end
        else
            --log("WARNING: Could not find player with index " .. args.username)
        end
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
