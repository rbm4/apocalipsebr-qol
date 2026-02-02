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

local function isVehicleTrailer(vehicle)
    -- removed trailer logic because it was faulty, we should check any vehicle now
    return true
end

local function getVehicleAnimalCount(vehicle)
    if not vehicle then
        print("AF_DEBUG: vehicle is nil")
        return 0
    end

    print("AF_DEBUG: vehicle type = " .. type(vehicle))
    print("AF_DEBUG: vehicle class = " .. tostring(vehicle:getClass()))

    -- Try different ways to access animals
    local animalCount = 0
    local animals = nil

    -- Method 1: Try getAnimals() method
    if vehicle.getAnimals then
        print("AF_DEBUG: Found getAnimals() method")
        animals = vehicle:getAnimals()
        if animals then
            animalCount = animals:size()
            print("AF_DEBUG: getAnimals() returned array with " .. animalCount .. " animals")
        else
            print("AF_DEBUG: getAnimals() returned nil")
        end
    else
        print("AF_DEBUG: No getAnimals() method found")
    end

    -- Method 2: Try direct field access
    if animalCount == 0 and vehicle.animals then
        print("AF_DEBUG: Trying direct field access to .animals")
        animals = vehicle.animals
        if animals then
            animalCount = animals:size()
            print("AF_DEBUG: Direct field access returned array with " .. animalCount .. " animals")
        else
            print("AF_DEBUG: Direct field .animals is nil")
        end
    end

    -- Method 3: Try with reflection or other approaches
    if animalCount == 0 then
        print("AF_DEBUG: Both methods failed, trying alternative approaches...")

        -- Check if vehicle has any animal-related methods
        local methods = {"getAnimalList", "getAnimalArray", "getAnimalCount", "getAnimalSize"}
        for _, methodName in ipairs(methods) do
            if vehicle[methodName] then
                print("AF_DEBUG: Found method: " .. methodName)
                local result = vehicle[methodName](vehicle)
                if result then
                    if type(result) == "number" then
                        animalCount = result
                        print("AF_DEBUG: " .. methodName .. " returned count: " .. animalCount)
                        break
                    elseif result.size then
                        animalCount = result:size()
                        print("AF_DEBUG: " .. methodName .. " returned array with " .. animalCount .. " animals")
                        break
                    end
                end
            end
        end
    end

    print("AF_DEBUG: Final animal count: " .. animalCount)
    return animalCount
end

local function hasValidAnimals(vehicle)
    if not vehicle then
        print("AF_DEBUG: hasValidAnimals - vehicle is nil")
        return true
    end

    local animals = nil

    -- Try same methods as getVehicleAnimalCount
    if vehicle.getAnimals then
        animals = vehicle:getAnimals()
    elseif vehicle.animals then
        animals = vehicle.animals
    end

    if not animals then
        print("AF_DEBUG: hasValidAnimals - no animals array found")
        return true
    end

    print("AF_DEBUG: hasValidAnimals - checking " .. animals:size() .. " animals for nulls")

    for i = 0, animals:size() - 1 do
        local animal = animals:get(i)
        if animal == nil then
            print("AF_DEBUG: hasValidAnimals - found null animal at index " .. i)
            return false
        end
    end

    print("AF_DEBUG: hasValidAnimals - all animals are valid")
    return true
end

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
        if isVehicleTrailer(vehicle) then
            AF_Main.stats.vehicleInteractions = AF_Main.stats.vehicleInteractions + 1
            print("Context menu on trailer: " .. tostring(vehicle:getScript():getName()))

            -- Check for existing null animals before any interaction
            if not hasValidAnimals(vehicle) then
                AF_Main.stats.nullAnimalsFound = AF_Main.stats.nullAnimalsFound + 1
                print("WARNING: Found null animals in trailer BEFORE interaction!")

                -- Add cleanup option to context menu
                context:addOption("Fix Animal Issues", vehicle, function(v)
                    AF_Main.cleanVehicleAnimals(v, player)
                end)
            end

            -- Cache this vehicle for post-interaction checking
            AF_Main.recentVehicles[vehicle] = getTimestampMs() + AF_Main.CACHE_TIMEOUT

            -- Add debug option to context menu if debug mode is on
            if AF_Main.DEBUG_MODE then
                -- Add server-side cleanup option
                context:addOption("AF_DEBUG: Clean Animals (Server)", vehicle, function(v)
                    if isClient() then
                        sendClientCommand("AnimalFixes", "CleanAnimals", {
                            vehicleId = v:getId()
                        })
                        player:Say("Sent clean command to server...")
                    end
                end)

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
end

-- Function to clean null animals from a vehicle
function AF_Main.cleanVehicleAnimals(vehicle, player)
    if not vehicle or not vehicle.animals then
        print("Vehicle has no animals array to clean")
        if player then
            player:Say("Vehicle has no animals to clean.")
        end
        return 0
    end

    local originalCount = vehicle.animals:size()
    local removedCount = 0

    -- Iterate backwards to safely remove null entries
    for i = originalCount - 1, 0, -1 do
        local animal = vehicle.animals:get(i)
        if animal == nil then
            vehicle.animals:remove(i)
            removedCount = removedCount + 1
            print("Removed null animal at index " .. i)
        end
    end

    local finalCount = vehicle.animals:size()
    print("Cleaned vehicle animals: " .. originalCount .. " -> " .. finalCount .. " (removed " .. removedCount ..
              " nulls)")

    if player then
        if removedCount > 0 then
            player:Say("Cleaned " .. removedCount .. " null animals from trailer.")
        else
            player:Say("No null animals found to clean.")
        end
    end

    return removedCount
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

AF_Main.isVehicleTrailer = isVehicleTrailer
AF_Main.hasValidAnimals = hasValidAnimals
