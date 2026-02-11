-- ============================================================================
-- File: media/lua/server/RegionManager_PVP_Server.lua
-- Server-side PVP state management
-- Receives client PVP state updates and broadcasts to other clients
-- ============================================================================

if not isServer() then return end

require "RegionManager_Config"

RegionManager.PVP_Server = RegionManager.PVP_Server or {}

local function log(msg)
    RegionManager.Log("PVP_Server", msg)
end

-- ============================================================================
-- Client Command Handler
-- Receives PVP state updates from clients and broadcasts to others
-- ============================================================================
---@param module string
---@param command string
---@param player IsoPlayer
---@param args table
local function OnClientCommand(module, command, player, args)
    if module ~= "RegionManager" then return end
    
    if command == "UpdatePvpState" then
        local playerIndex = player:getPlayerNum()
        local username = player:getUsername()
        
        log("Received PVP state update from " .. username .. " (ID:" .. playerIndex .. ")")
        log("  Zone: " .. (args.zoneName or "Unknown"))
        log("  PVP Zone: " .. tostring(args.isPvpZone))
        log("  Safe Zone: " .. tostring(args.isSafeZone))
        log("  Safety Enabled: " .. tostring(args.safetyEnabled))
        
        -- Broadcast this player's PVP state to all OTHER clients
        local broadcast = {
            playerIndex = playerIndex,
            username = username,
            zoneId = args.zoneId,
            zoneName = args.zoneName,
            isPvpZone = args.isPvpZone,
            isSafeZone = args.isSafeZone,
            safetyEnabled = args.safetyEnabled
        }
        
        -- Send to all players except the sender
        for i = 0, getNumActivePlayers() - 1 do
            local otherPlayer = getSpecificPlayer(i)
            if otherPlayer and otherPlayer ~= player then
                sendServerCommand(otherPlayer, "RegionManager", "PvpStateChanged", broadcast)
            end
        end
        
        log("Broadcasted PVP state to " .. (getNumActivePlayers() - 1) .. " other players")
    end
end

-- ============================================================================
-- Event Registration
-- ============================================================================
Events.OnClientCommand.Add(OnClientCommand)

log("RegionManager PVP Server module loaded")

return RegionManager.PVP_Server
