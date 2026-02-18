-- ============================================================================
-- File: media/lua/server/RegionManager_Server.lua
-- Server-side zone registration and management
-- ============================================================================
if not isServer() then
    return
end

require "RegionManager_Config"
require "RegionManager_AutoSafeZones"

local JSON = require "RegionManager_JSON"

RegionManager.Server = RegionManager.Server or {}

---@type table<string, RegisteredZoneData>
RegionManager.Server.registeredZones = RegionManager.Server.registeredZones or {}

local function log(msg)
    RegionManager.Log("Server", msg)
end

-- Store registered zones in ModData
---@param allRegions RegionDefinition[]
local function saveRegisteredZones(allRegions)
    local modData = ModData.getOrCreate(RegionManager.Config.MODDATA_KEY)
    modData.zones = allRegions or {}
    modData.lastUpdate = getGameTime():getWorldAgeHours()
    ModData.add(RegionManager.Config.MODDATA_KEY, modData)
    log("Saved " .. #modData.zones .. " zones to ModData")
end

-- Merge category properties with region customProperties.
-- Flattens category defaults + customProperties into a single ZoneProperties table.
---@param region RegionDefinition
---@return ZoneProperties
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

    -- Override with custom properties (customProperties take priority)
    if region.customProperties then
        for k, v in pairs(region.customProperties) do
            props[k] = v
        end
    end

    return props
end

-- Register a single region as a zone
---@param region RegionDefinition
---@return boolean success
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
        
        -- Create NonPvpZone for safe zones (pvpEnabled = false)
        -- SafetySystemManager automatically detects NonPvpZone and manages Safety state
        if props.pvpEnabled == false then
            local zoneName = "SafeZone_" .. region.id
            NonPvpZone.addNonPvpZone(zoneName, minX, minY, maxX, maxY)
            log("Created NonPvpZone: " .. zoneName .. " - SafetySystemManager will auto-manage this zone")
        end

        return true
    else
        log("WARNING: Failed to register zone: " .. region.id)
        return false
    end
end

-- ============================================================================
-- External regions file I/O
-- ============================================================================

-- Write current regions to the external JSON file
---@param regions RegionDefinition[]
---@return boolean success
local function writeRegionsFile(regions)
    local filename = RegionManager.Config.RegionsFilePath
    log("Writing regions file: " .. filename)
    
    local data = {
        version = "1.0",
        lastUpdated = os.date("%Y-%m-%d %H:%M:%S"),
        regions = regions
    }
    
    local jsonStr = JSON.encode(data)
    
    local writer = getFileWriter(filename, true, false)
    if not writer then
        log("ERROR: Could not open file for writing: " .. filename)
        return false
    end
    
    writer:write(jsonStr)
    writer:close()
    
    log("Successfully wrote " .. #regions .. " regions to " .. filename)
    return true
end

-- Read regions from the external JSON file, or create the file with defaults if missing
---@return RegionDefinition[]
local function loadRegionsFromFile()
    local filename = RegionManager.Config.RegionsFilePath
    log("Loading regions from file: " .. filename)
    
    -- Try to read the file
    local reader = getFileReader(filename, true)
    if not reader then
        -- File does not exist: create it with the default configured regions
        log("Regions file not found, creating with default configured regions...")
        writeRegionsFile(RegionManager.Config.Regions)
        return RegionManager.Config.Regions
    end
    
    -- Read entire file content
    local lines = {}
    local line = reader:readLine()
    while line ~= nil do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()
    
    local content = table.concat(lines, "\n")
    if content == "" or content:match("^%s*$") then
        log("WARNING: Regions file is empty, using default configured regions")
        writeRegionsFile(RegionManager.Config.Regions)
        return RegionManager.Config.Regions
    end
    
    -- Parse JSON
    local success, data = pcall(JSON.parse, content)
    if not success or not data then
        log("ERROR: Failed to parse regions file: " .. tostring(data))
        log("Falling back to default configured regions")
        return RegionManager.Config.Regions
    end
    
    local regions = data.regions
    if not regions or type(regions) ~= "table" then
        log("ERROR: Regions file has no 'regions' array")
        log("Falling back to default configured regions")
        return RegionManager.Config.Regions
    end
    
    log("Successfully loaded " .. #regions .. " regions from file")
    return regions
end

-- Register all configured regions
local function registerAllRegions()
    log("=== Starting Region Registration ===")

    -- Load regions from external JSON file (creates file with defaults if missing)
    local fileRegions = loadRegionsFromFile()
    log("Loaded " .. #fileRegions .. " regions from external file")

    -- Generate auto-safe zones by subtracting PVP zones from file-loaded regions
    local allRegions = RegionManager.AutoSafeZones.mergeWithConfigured(fileRegions)
    log("Processing " .. #allRegions .. " total regions (auto-generated + file-loaded)")

    local registered = 0
    local failed = 0

    for _, region in ipairs(allRegions) do
        if registerRegion(region) then
            registered = registered + 1
        else
            failed = failed + 1
        end
    end

    log("=== Registration Complete ===")
    log("Registered: " .. registered .. " | Failed: " .. failed)

    -- Save to ModData
    saveRegisteredZones(allRegions)

    -- Verify zones are loaded
    getWorld():checkVehiclesZones()
end

-- NOTE: Player zone detection is now handled client-side (RegionManager_ClientTick.lua).
-- Each client detects zone enter/exit and sends commands to the server for broadcast.
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
---@param module string
---@param command string
---@param player IsoPlayer
---@param args table
local function OnClientCommand(module, command, player, args)
    if module ~= "RegionManager" then
        return
    end

    if command == "RequestAllBoundaries" then
        local zoneList = {}
        
        for id, data in pairs(RegionManager.Server.registeredZones or {}) do
            print(data.properties.shamblerChance)
            table.insert(zoneList, {
                id = data.region.id,
                name = data.region.name,
                bounds = data.bounds,
                color = data.properties.color or {r=0, g=255, b=0},
                pvpEnabled = data.properties.pvpEnabled or false,
                sprinterChance = data.properties.sprinterChance or 0,
                shamblerChance = data.properties.shamblerChance or 0,
                hawkVisionChance = data.properties.hawkVisionChance or 0,
                badVisionChance = data.properties.badVisionChance or 0,
                goodHearingChance = data.properties.goodHearingChance or 0,
                badHearingChance = data.properties.badHearingChance or 0,
                zombieArmorFactor = data.properties.zombieArmorFactor or 0,
                resistantChance = data.properties.resistantChance or 0,
                announceEntry = data.properties.announceEntry or false,
                announceExit = data.properties.announceExit or false,
                message = data.properties.message or ""
            })
        end
        
        sendServerCommand(player, "RegionManager", "AllZoneBoundaries", {
            zones = zoneList
        })
        
        print("Sent " .. #zoneList .. " zone boundaries to " .. player:getUsername())
        
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
    elseif command == "ClientZoneEntered" then
        -- Client detected zone entry, sync with other players
        local zoneId = args.zoneId
        local zoneName = args.zoneName
        local isPvpZone = args.isPvpZone
        local isSafeZone = args.isSafeZone
        local safetyEnabled = args.safetyEnabled
        
        print("[DEBUG SERVER] Player " .. player:getUsername() .. " entered zone: " .. zoneName .. 
              " (PVP=" .. tostring(isPvpZone) .. ", Safe=" .. tostring(isSafeZone) .. ")")
        
        -- Broadcast PVP state change to all other players for skull icon sync
        -- local allPlayers = getOnlinePlayers()
        -- for i = 0, allPlayers:size() - 1 do
        --     local otherPlayer = allPlayers:get(i)
        --     if otherPlayer ~= player then
        --         sendServerCommand(otherPlayer, "RegionManager", "PlayerPvpStateChanged", {
        --             playerIndex = player:getPlayerNum(),
        --             pvpEnabled = isPvpZone,
        --             safetyEnabled = safetyEnabled
        --         })
        --     end
        -- end
        print("[DEBUG SERVER] Broadcasted zone entry to " .. (allPlayers:size() - 1) .. " other players")
        
    elseif command == "ClientZoneExited" then
        -- Client detected zone exit, sync with other players
        -- local zoneId = args.zoneId
        -- local zoneName = args.zoneName
        -- local safetyEnabled = args.safetyEnabled
        
        print("[DEBUG SERVER] Player " .. player:getUsername() .. " exited zone: " .. zoneName)
        
        -- Send zone exited notification to the player
        -- sendServerCommand(player, "RegionManager", "ZoneExited", {
        --     id = zoneId,
        --     name = zoneName,
        --     safetyEnabled = safetyEnabled
        -- })
        
        -- Broadcast PVP state reset to all other players
        -- local allPlayers = getOnlinePlayers()
        -- for i = 0, allPlayers:size() - 1 do
        --     local otherPlayer = allPlayers:get(i)
        --     if otherPlayer ~= player then
        --         sendServerCommand(otherPlayer, "RegionManager", "PlayerPvpStateChanged", {
        --             playerIndex = player:getPlayerNum(),
        --             pvpEnabled = false,
        --             safetyEnabled = safetyEnabled
        --         })
        --     end
        -- end
        -- print("[DEBUG SERVER] Broadcasted zone exit to " .. (allPlayers:size() - 1) .. " other players")
        
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


-- NOTE: Zone effects (PVP/Safety state) are now applied client-side.
-- The server receives ClientZoneEntered/ClientZoneExited and broadcasts to other clients.

-- Event registration
Events.OnServerStarted.Add(OnServerStarted)
Events.OnLoadMapZones.Add(OnLoadMapZones)
Events.OnClientCommand.Add(OnClientCommand)

log("RegionManager Server module loaded")

return RegionManager.Server
