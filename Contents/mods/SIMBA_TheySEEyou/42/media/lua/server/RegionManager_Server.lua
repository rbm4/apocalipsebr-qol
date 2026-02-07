-- ============================================================================
-- File: media/lua/server/RegionManager_Server.lua
-- Server-side zone registration and management
-- ============================================================================
if not isServer() then
    return
end

require "RegionManager_Config"

RegionManager.Server = RegionManager.Server or {}

local function log(msg)
    RegionManager.Log("Server", msg)
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

    -- Pre-calculate rectangle bounds from two opposite corners
    -- This ensures min/max are correctly ordered
    local minX = math.min(region.x1, region.x2)
    local maxX = math.max(region.x1, region.x2)
    local minY = math.min(region.y1, region.y2)
    local maxY = math.max(region.y1, region.y2)

    -- Calculate center and dimensions for game engine registration
    local centerX = minX
    local centerY = minY
    local width = maxX - minX
    local height = maxY - minY

    -- Register the zone with the game engine
    local zone = world:registerZone(region.id, -- unique zone name
    "Custom", -- zone type
    centerX, centerY, region.z, width, height)

    if zone then
        log(
            "Successfully registered zone: " .. region.id .. " at (" .. minX .. "," .. minY .. ") to (" .. maxX .. "," ..
                maxY .. ") " .. "size: " .. width .. "x" .. height)

        -- Store region data with pre-calculated bounds
        if not RegionManager.Server.registeredZones then
            RegionManager.Server.registeredZones = {}
        end

        RegionManager.Server.registeredZones[region.id] = {
            region = region,
            properties = props,
            zone = zone,
            -- Store pre-calculated bounds for fast collision checking
            bounds = {
                minX = minX,
                maxX = maxX,
                minY = minY,
                maxY = maxY
            }
        }
        
        -- Create SafeHouse zone for safe zones (pvpEnabled = false)
        if props.pvpEnabled == false then
            local safehouseName = "SafeZone_" .. region.id
            SafeHouse.addSafeHouse(safehouseName, "", minX, minY, maxX, maxY, true)
            log("Created SafeHouse zone: " .. safehouseName)
        end

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
                if j < #region.categories then
                    writer:write(", ")
                end
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
    if module ~= "RegionManager" then
        return
    end

    if command == "RequestAllBoundaries" then
        -- Send all zone boundaries to client for visualization
        local zoneList = {}
        
        for id, data in pairs(RegionManager.Server.registeredZones or {}) do
            table.insert(zoneList, {
                id = data.region.id,
                name = data.region.name,
                bounds = data.bounds,
                color = data.properties.color or {r=0, g=255, b=0}
            })
        end
        
        sendServerCommand(player, "RegionManager", "AllZoneBoundaries", {
            zones = zoneList
        })
        
        log("Sent " .. #zoneList .. " zone boundaries to " .. player:getUsername())
        
    elseif command == "RequestZoneInfo" then
        -- Send zone info to client
        local x = args.x
        local y = args.y

        -- Find which zones contain this point using pre-calculated bounds
        local zonesAtLocation = {}

        for id, data in pairs(RegionManager.Server.registeredZones or {}) do
            local bounds = data.bounds
            -- Fast AABB collision check using pre-calculated bounds
            if x >= bounds.minX and x <= bounds.maxX and y >= bounds.minY and y <= bounds.maxY then
                table.insert(zonesAtLocation, {
                    id = data.region.id,
                    name = data.region.name,
                    categories = data.region.categories
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
    if not player then
        return
    end

    local x = player:getX()
    local y = player:getY()

    local playerData = player:getModData()
    playerData.RegionManager = playerData.RegionManager or {}
    
    -- Get previous zones (deep copy to compare)
    local previousZones = playerData.RegionManager.currentZones or {}
    local currentZones = {}

    -- Debug: Count previous zones
    local prevCount = 0
    for _ in pairs(previousZones) do prevCount = prevCount + 1 end
    
    -- Check which zones player is in using pre-calculated bounds
    for id, data in pairs(RegionManager.Server.registeredZones or {}) do
        local bounds = data.bounds
        -- Fast AABB collision check
        if x >= bounds.minX and x <= bounds.maxX and y >= bounds.minY and y <= bounds.maxY then
            currentZones[id] = true

            -- Player entered this zone (NEW zone, not in previous zones)
            if not previousZones[id] then
                local props = data.properties

                -- Send notification to client
                if props.announceEntry then
                    local message = props.message or ("Entering: " .. data.region.name)
                    sendServerCommand(player, "RegionManager", "ZoneEntered", {
                        id = data.region.id,
                        name = data.region.name,
                        message = message,
                        color = props.color,
                        pvpEnabled = props.pvpEnabled,
                        safetyEnabled = player:getSafety():isEnabled()
                    })
                    log("Player " .. player:getUsername() .. " ENTERED zone: " .. data.region.name .. " (had " .. prevCount .. " previous zones)")
                end

                -- Apply zone effects
                applyZoneEffects(player, data)
            end
        end
    end

    -- Check for zone exits (was in previous zones, not in current zones)
    for id, _ in pairs(previousZones) do
        if not currentZones[id] then
            local data = RegionManager.Server.registeredZones[id]
            if data then
                local props = data.properties

                -- Send notification to client
                if props.announceExit then
                    sendServerCommand(player, "RegionManager", "ZoneExited", {
                        id = data.region.id,
                        name = data.region.name,
                        pvpEnabled = props.pvpEnabled,
                        safetyEnabled = player:getSafety():isEnabled()
                    })
                    log("Player " .. player:getUsername() .. " EXITED zone: " .. data.region.name)
                end

                -- Remove zone effects
                removeZoneEffects(player, data)
            end
        end
    end

    -- Debug: Count current zones
    local currCount = 0
    for _ in pairs(currentZones) do currCount = currCount + 1 end
    
    -- Update player's current zones (this persists the state)
    playerData.RegionManager.currentZones = currentZones
    
    -- Debug logging
    if currCount > 0 or prevCount > 0 then
        log("DEBUG: Player " .. player:getUsername() .. " - Previous zones: " .. prevCount .. ", Current zones: " .. currCount)
    end
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

    -- PVP Zone: Force skull activation to enable player damage
    if props.pvpEnabled == true then
        log("PVP Zone: Activating PVP skull for " .. player:getUsername())
        -- Store original Safety state for restoration
        if not modData.RegionManager.originalValues.safetyEnabled then
            modData.RegionManager.originalValues.safetyEnabled = player:getSafety():isEnabled()
        end
        -- Store PVP state in modData
        modData.RegionManager.isPvpZone = true
        -- Force PVP mode on (skull icon) - requires BOTH calls
        player:setFactionPvp(true)
        player:getSafety():setEnabled(false)
        log("PVP Zone: Set factionPvp=true, Safety=false for " .. player:getUsername())
    end

    -- SAFE ZONE: Player enters safe zone (SafeHouse already created at startup)
    if props.pvpEnabled == false then
        log("Safe Zone: Player " .. player:getUsername() .. " in safe zone")
        -- Store original Safety state for restoration
        if not modData.RegionManager.originalValues.safetyEnabled then
            modData.RegionManager.originalValues.safetyEnabled = player:getSafety():isEnabled()
        end
        modData.RegionManager.isPvpZone = false
        -- Disable faction PVP and enable Safety protection
        player:setFactionPvp(false)
        player:getSafety():setEnabled(true)
        log("Safe Zone: Set factionPvp=false, Safety=true for " .. player:getUsername())
    end
end

-- Remove zone effects from player
function removeZoneEffects(player, zoneData)
    local modData = player:getModData()
    local props = zoneData.properties

    -- Restore PVP state
    if props.pvpEnabled ~= nil then
        log("Removing PVP zone effects for " .. player:getUsername())
        -- Reset to default (no forced PVP)
        player:setFactionPvp(false)
        
        -- Restore original Safety state
        if modData.RegionManager.originalValues and modData.RegionManager.originalValues.safetyEnabled ~= nil then
            player:getSafety():setEnabled(modData.RegionManager.originalValues.safetyEnabled)
            log("Restored Safety state to: " .. tostring(modData.RegionManager.originalValues.safetyEnabled))
            modData.RegionManager.originalValues.safetyEnabled = nil
        end
        
        modData.RegionManager.isPvpZone = nil
    end
    
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
    if tickCounter >= 60 then
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
