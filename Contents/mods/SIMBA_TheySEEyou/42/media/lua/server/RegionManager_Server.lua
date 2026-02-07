-- ============================================================================
-- File: media/lua/server/RegionManager_Server.lua
-- Server-side zone registration and management
-- ============================================================================

if not isServer() then return end

require "RegionManager_Config"

RegionManager.Server = RegionManager.Server or {}

local function log(msg)
    print("[RegionManager Server] " .. tostring(msg))
end

-- Store registered zones in ModData
local function saveRegisteredZones()
    local modData = ModData.getOrCreate(RegionManager.Config.MODDATA_KEY)
    modData.zones = modData.zones or {}
    modData.lastUpdate = getGameTime():getWorldAgeHours()
    ModData.add(RegionManager.Config.MODDATA_KEY, modData)
    log("Saved " .. #modData.zones .. " zones to ModData")
end

-- Load registered zones from ModData
local function loadRegisteredZones()
    local modData = ModData.get(RegionManager.Config.MODDATA_KEY)
    if modData and modData.zones then
        log("Loaded " .. #modData.zones .. " zones from ModData")
        return modData.zones
    end
    return {}
end

-- Merge category properties with region customProperties
local function getMergedProperties(region)
    local props = {}
    
    -- Apply all category properties
    for _, catName in ipairs(region.categories or {}) do
        local category = RegionManager.Config.Categories[catName]
        if category then
            for k, v in pairs(category) do
                if props[k] == nil then
                    props[k] = v
                end
            end
        end
    end
    
    -- Override with custom properties
    if region.customProperties then
        for k, v in pairs(region.customProperties) do
            props[k] = v
        end
    end
    
    return props
end

-- Register a single region as a zone
local function registerRegion(region)
    if not region.enabled then
        log("Skipping disabled region: " .. region.id)
        return false
    end
    
    local world = getWorld()
    if not world then
        log("ERROR: World not available!")
        return false
    end
    
    -- Get merged properties
    local props = getMergedProperties(region)
    
    -- Build zone properties table for the game engine
    local zoneProps = {}
    
    -- Register the zone with the game engine
    local zone = world:registerZone(
        region.id,           -- unique zone name
        "Custom",            -- zone type
        region.x,
        region.y,
        region.z,
        region.width,
        region.height
    )
    
    if zone then
        log("Successfully registered zone: " .. region.id .. 
            " at (" .. region.x .. "," .. region.y .. ") " ..
            "size: " .. region.width .. "x" .. region.height)
        
        -- Store region data for later use
        if not RegionManager.Server.registeredZones then
            RegionManager.Server.registeredZones = {}
        end
        
        RegionManager.Server.registeredZones[region.id] = {
            region = region,
            properties = props,
            zone = zone
        }
        
        return true
    else
        log("WARNING: Failed to register zone: " .. region.id)
        return false
    end
end

-- Register all configured regions
local function registerAllRegions()
    log("=== Starting Region Registration ===")
    
    local registered = 0
    local failed = 0
    
    for _, region in ipairs(RegionManager.Config.Regions) do
        if registerRegion(region) then
            registered = registered + 1
        else
            failed = failed + 1
        end
    end
    
    log("=== Registration Complete ===")
    log("Registered: " .. registered .. " | Failed: " .. failed)
    
    -- Save to ModData
    saveRegisteredZones()
    
    -- Verify zones are loaded
    getWorld():checkVehiclesZones()
end

-- Export configuration to JSON file
local function exportConfig()
    log("Exporting region configuration...")
    
    local success, err = pcall(function()
        local filename = RegionManager.Config.ExportPath
        local writer = getFileWriter(filename, true, false)
        
        if not writer then
            log("ERROR: Could not open file for writing: " .. filename)
            return
        end
        
        -- Build JSON manually (simple format)
        writer:write("{\n")
        writer:write('  "version": "1.0",\n')
        writer:write('  "exportDate": "' .. os.date("%Y-%m-%d %H:%M:%S") .. '",\n')
        writer:write('  "regions": [\n')
        
        for i, region in ipairs(RegionManager.Config.Regions) do
            writer:write("    {\n")
            writer:write('      "id": "' .. region.id .. '",\n')
            writer:write('      "name": "' .. region.name .. '",\n')
            writer:write('      "x": ' .. region.x .. ',\n')
            writer:write('      "y": ' .. region.y .. ',\n')
            writer:write('      "z": ' .. region.z .. ',\n')
            writer:write('      "width": ' .. region.width .. ',\n')
            writer:write('      "height": ' .. region.height .. ',\n')
            writer:write('      "enabled": ' .. tostring(region.enabled) .. ',\n')
            writer:write('      "categories": [')
            for j, cat in ipairs(region.categories) do
                writer:write('"' .. cat .. '"')
                if j < #region.categories then writer:write(", ") end
            end
            writer:write("]\n")
            writer:write("    }")
            if i < #RegionManager.Config.Regions then
                writer:write(",")
            end
            writer:write("\n")
        end
        
        writer:write("  ]\n")
        writer:write("}\n")
        writer:close()
        
        log("Configuration exported successfully to: " .. filename)
    end)
    
    if not success then
        log("ERROR exporting config: " .. tostring(err))
    end
end

-- Handle server commands
local function OnClientCommand(module, command, player, args)
    if module ~= "RegionManager" then return end
    
    if command == "RequestZoneInfo" then
        -- Send zone info to client
        local x = args.x
        local y = args.y
        
        -- Find which zones contain this point
        local zonesAtLocation = {}
        
        for id, data in pairs(RegionManager.Server.registeredZones or {}) do
            local r = data.region
            if x >= r.x and x <= (r.x + r.width) and
               y >= r.y and y <= (r.y + r.height) then
                table.insert(zonesAtLocation, {
                    id = r.id,
                    name = r.name,
                    categories = r.categories
                })
            end
        end
        
        sendServerCommand(player, "RegionManager", "ZoneInfo", {
            zones = zonesAtLocation
        })
    elseif command == "ExportConfig" then
        -- Admin command to export config
        if player:getAccessLevel() ~= "None" then
            exportConfig()
            sendServerCommand(player, "RegionManager", "ExportComplete", {})
        end
    end
end

-- Initialize on server start
local function OnServerStarted()
    log("Server started, waiting for map zones to load...")
end

-- Initialize zones after map loads
local function OnLoadMapZones()
    log("Map zones loading, registering custom regions...")
    registerAllRegions()
end

-- Player enters/exits zone detection
local function checkPlayerZone(player)
    if not player then return end
    
    local x = player:getX()
    local y = player:getY()
    
    local playerData = player:getModData()
    playerData.RegionManager = playerData.RegionManager or {}
    playerData.RegionManager.currentZones = playerData.RegionManager.currentZones or {}
    
    local currentZones = {}
    
    -- Check which zones player is in
    for id, data in pairs(RegionManager.Server.registeredZones or {}) do
        local r = data.region
        if x >= r.x and x <= (r.x + r.width) and
           y >= r.y and y <= (r.y + r.height) then
            currentZones[id] = true
            
            -- Player entered this zone
            if not playerData.RegionManager.currentZones[id] then
                local props = data.properties
                
                -- Send notification to client
                if props.announceEntry then
                    local message = props.message or ("Entering: " .. r.name)
                    sendServerCommand(player, "RegionManager", "ZoneEntered", {
                        id = r.id,
                        name = r.name,
                        message = message,
                        color = props.color
                    })
                end
                
                -- Apply zone effects
                applyZoneEffects(player, data)
            end
        end
    end
    
    -- Check for zone exits
    for id, _ in pairs(playerData.RegionManager.currentZones) do
        if not currentZones[id] then
            local data = RegionManager.Server.registeredZones[id]
            if data then
                local props = data.properties
                
                -- Send notification to client
                if props.announceExit then
                    sendServerCommand(player, "RegionManager", "ZoneExited", {
                        id = data.region.id,
                        name = data.region.name
                    })
                end
                
                -- Remove zone effects
                removeZoneEffects(player, data)
            end
        end
    end
    
    -- Update player's current zones
    playerData.RegionManager.currentZones = currentZones
end

-- Apply zone effects to player
function applyZoneEffects(player, zoneData)
    local props = zoneData.properties
    local modData = player:getModData()
    
    -- Store original values for later restoration
    modData.RegionManager.originalValues = modData.RegionManager.originalValues or {}
    
    -- Example effects (you can expand these)
    if props.zombieSpeed then
        -- This would need server-side zombie modification
        log("Zone effect: Zombie speed modifier for " .. player:getUsername())
    end
    
    if props.lootModifier then
        log("Zone effect: Loot modifier active for " .. player:getUsername())
    end
end

-- Remove zone effects from player
function removeZoneEffects(player, zoneData)
    local modData = player:getModData()
    
    -- Restore original values
    if modData.RegionManager.originalValues then
        -- Restore player state
        log("Removing zone effects for " .. player:getUsername())
    end
end

-- Tick handler for periodic checks
local tickCounter = 0
local function OnTick()
    tickCounter = tickCounter + 1
    
    -- Check every 10 second (60 ticks)
    if tickCounter >= 600 then
        tickCounter = 0
        
        -- Check all online players
        local players = getOnlinePlayers()
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            checkPlayerZone(player)
        end
    end
end

-- Event registration
Events.OnServerStarted.Add(OnServerStarted)
Events.OnLoadMapZones.Add(OnLoadMapZones)
Events.OnClientCommand.Add(OnClientCommand)
Events.OnTick.Add(OnTick)

log("RegionManager Server module loaded")

return RegionManager.Server