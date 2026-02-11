-- ============================================================================
-- File: media/lua/client/RegionManager_Client.lua
-- Client-side UI and notifications
-- ============================================================================

if not isClient() then return end

require "RegionManager_Config"

RegionManager.Client = RegionManager.Client or {}

---@type ClientZoneData[]|nil
RegionManager.Client.zoneData = nil -- Store zone boundary data

local function log(msg)
    RegionManager.Log("Client", msg)
end

-- Draw zone boundaries and labels in the game world
local function drawZoneOutlines()
    local player = getPlayer()
    if not player then return end
    
    -- Only draw if we have zone data
    if not RegionManager.Client.zoneData then return end
    
    for id, zone in pairs(RegionManager.Client.zoneData) do
        local bounds = zone.bounds
        local color = zone.color or {r=0, g=1, b=0}
        
        -- Normalize color values (0-1 range for drawing)
        local r = (color.r or 0) / 255
        local g = (color.g or 255) / 255
        local b = (color.b or 0) / 255
        
        -- Calculate zone center for label
        local centerX = (bounds.minX + bounds.maxX) / 2
        local centerY = (bounds.minY + bounds.maxY) / 2
        
        -- Draw zone name label in the world at center
        local zoneName = zone.name or zone.id
        getCore():DrawText(zoneName, centerX, centerY, r, g, b, 1)
        
        -- Draw corner markers (smaller text markers)
        local cornerMarker = "T"
        getCore():DrawText(cornerMarker, bounds.minX, bounds.minY, r, g, b, 0.8)
        getCore():DrawText(cornerMarker, bounds.maxX, bounds.minY, r, g, b, 0.8)
        getCore():DrawText(cornerMarker, bounds.minX, bounds.maxY, r, g, b, 0.8)
        getCore():DrawText(cornerMarker, bounds.maxX, bounds.maxY, r, g, b, 0.8)
    end
end

-- Show zone notification
---@param zoneName string
---@param message string
---@param color? ColorRGB
---@param isEntry boolean
local function showZoneNotification(zoneName, message, color, isEntry)
    local player = getPlayer()
    if not player then return end
    
    -- Use game's HaloNote system for notifications
    local r = color and color.r or 1.0
    local g = color and color.g or 1.0
    local b = color and color.b or 1.0
    
    player:Say(message, r, g, b, UIFont.Medium, 3, "radio")
    
    -- Log to console
    local prefix = isEntry and "[ENTERED]" or "[LEFT]"
    log(prefix .. " " .. zoneName)
end

-- Handle server commands
---@param module string
---@param command string
---@param args table
local function OnServerCommand(module, command, args)
    if module ~= "RegionManager" then return end
    
    if command == "ZoneInfo" then
        -- Display zone info UI
        log("Current zones: " .. #args.zones)
        for _, zone in ipairs(args.zones) do
            log("  - " .. zone.name)
        end
        
    elseif command == "ExportComplete" then
        local player = getPlayer()
        if player then
            player:Say("Region configuration exported successfully!", 0, 1, 0, UIFont.Medium, 3, "radio")
        end
        
    elseif command == "AllZoneBoundaries" then
        -- Receive all zone boundary data from server
        RegionManager.Client.zoneData = args.zones or {}
        log("Received " .. tostring(#RegionManager.Client.zoneData) .. " zone boundaries from server")
        log("Zone outlines will be drawn continuously via OnPostRender")
    end
end

-- Request zone info for current position
local function requestZoneInfo()
    local player = getPlayer()
    if not player then return end
    
    sendClientCommand("RegionManager", "RequestZoneInfo", {
        x = player:getX(),
        y = player:getY()
    })
end

-- Debug command to show current zones
local function showCurrentZones()
    requestZoneInfo()
end


-- Event registration
Events.OnServerCommand.Add(OnServerCommand)

-- Register debug command (optional)
-- You can call this from console: /showzones
if isDebugEnabled() then
    RegionManager.Client.ShowZones = showCurrentZones
    RegionManager.Client.DrawOutlines = drawZoneOutlines
end

log("RegionManager Client module loaded")

return RegionManager.Client