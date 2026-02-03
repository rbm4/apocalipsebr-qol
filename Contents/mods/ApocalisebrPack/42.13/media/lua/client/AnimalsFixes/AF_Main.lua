-- Animal Fixes Main Script
-- Handles null animal NPE issues in vehicle trailers through event-driven approach
-- Author: AI Assistant
-- Date: 2026-01-29
AF_Main = AF_Main or {}

-- Debug settings
AF_Main.DEBUG_MODE = true
AF_Main.REPRODUCE_ERROR = false -- Set to true to test null insertion

-- Statistics
AF_Main.stats = {
    vehicleInteractions = 0,
    animalContextMenus = 0,
    suspiciousActivity = 0,
    nullAnimalsFound = 0
}

-- Cache for recently accessed vehicles to avoid redundant checks
AF_Main.recentVehicles = {}
AF_Main.CACHE_TIMEOUT = 5000 -- 5 seconds

-- Main Event Handlers
-----------------------------------------------------------
-- Context Menu Builder
-----------------------------------------------------------

--- Add claim options to vehicle context menu
--- @param playerNum number
--- @param context ISContextMenu
--- @param worldObjects table
--- @param test boolean
local function findClosestVehicle(playerNum, context, worldObjects, test)
    if test then
        return
    end

    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    -- Find vehicle in clicked objects
    local vehicle = nil
    -- Check if the clicked square is inside the vehicle's area
    if not vehicle then
        local clickedSquare = nil
        for _, obj in ipairs(worldObjects) do
            if obj.getSquare then
                clickedSquare = obj:getSquare()
                break
            end
        end

        if clickedSquare then
            local clickX = clickedSquare:getX()
            local clickY = clickedSquare:getY()
            local clickZ = clickedSquare:getZ()

            local cell = getCell()
            if cell then
                local veh = cell:getVehicles()
                if veh then
                    local closestVehicle = nil
                    local closestDistance = 6.0

                    -- Find the closest vehicle to the clicked position
                    for i = 0, veh:size() - 1 do
                        local v = veh:get(i)
                        if v then
                            -- Calculate distance from clicked square to vehicle
                            local vx = v:getX()
                            local vy = v:getY()
                            local vz = v:getZ()

                            -- Only consider vehicles on same Z level
                            if vz == clickZ then
                                local dist = math.sqrt((clickX - vx) ^ 2 + (clickY - vy) ^ 2)

                                -- Keep track of closest vehicle
                                if dist < closestDistance then
                                    closestDistance = dist
                                    closestVehicle = v
                                end
                            end
                        end
                    end

                    -- Use the closest vehicle found
                    if closestVehicle then
                        vehicle = closestVehicle
                        print("[VehicleClaim] Found closest vehicle at distance: " ..
                                  string.format("%.2f", closestDistance))
                    end
                end
            end
        end
    end

    return vehicle

end
-- Handle right-click context menu on world objects (trailers)
local function onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    print("Starting context menu interception...")
    local player = getPlayer()
    if not player then
        return
    end

    local vehiclesFound = {}
    local closestVehicle = findClosestVehicle(playerNum, context, worldObjects, test)
    if closestVehicle then
        table.insert(vehiclesFound, closestVehicle)
    end

    -- Process found vehicles
    for _, vehicle in ipairs(vehiclesFound) do
        AF_Main.stats.vehicleInteractions = AF_Main.stats.vehicleInteractions + 1
        print("Context menu on trailer: " .. tostring(vehicle:getScript():getName()))

        if isClient() then
            sendClientCommand("AnimalFixes", "CleanAnimals", {
                vehicleId = v:getId()
            })
        end

        -- Cache this vehicle for post-interaction checking
        AF_Main.recentVehicles[vehicle] = getTimestampMs() + AF_Main.CACHE_TIMEOUT

        -- Add debug option to context menu if debug mode is on
        if AF_Main.DEBUG_MODE then

            -- Add error reproduction option (sends command to server)
            context:addOption("AF_DEBUG: Insert Null Animal (Server)", vehicle, function(v)
                if isClient() then
                    -- Send command to server
                    sendClientCommand("AnimalFixes", "InsertNullAnimal", {
                        vehicleId = v:getId()
                    })
                    player:Say("Sent null insertion command to server...")
                end
            end)

            -- Add scan all option
            context:addOption("AF_DEBUG: Scan & Clean All Vehicles", vehicle, function(v)
                if isClient() then
                    sendClientCommand("AnimalFixes", "ScanAndCleanAll", {})
                    player:Say("Scanning all vehicles on server...")
                end
            end)
        end
    end
end

-- Print statistics
function AF_Main.printStats()
    print("=== Animal Fixes Statistics ===")
    print("Vehicle interactions: " .. AF_Main.stats.vehicleInteractions)
    print("Animal context menus: " .. AF_Main.stats.animalContextMenus)
    print("Suspicious activity: " .. AF_Main.stats.suspiciousActivity)
    print("Null animals found: " .. AF_Main.stats.nullAnimalsFound)
    print("Cached vehicles: " .. table.getn(AF_Main.recentVehicles))
end

-- Called when game starts
local function onGameStart()

end
-- Event Registration
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

Events.OnGameStart.Add(onGameStart)

-- Initialize
print("Animal Fixes Main Script Loaded")
print("Debug mode: " .. tostring(AF_Main.DEBUG_MODE))
print("Error reproduction: " .. tostring(AF_Main.REPRODUCE_ERROR))
