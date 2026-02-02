-- Animal Fixes Server Commands
-- Handles server-side commands for testing and fixing
local Commands = {}
-- NEW: Function to recreate animals in new vehicle
local function recreateAnimals(vehicle, animalData, player)
    if not animalData or #animalData == 0 then
        return 0
    end

    local cell = vehicle:getCell()
    local x = vehicle:getX()
    local y = vehicle:getY()
    local z = vehicle:getZ()
    local recreatedCount = 0

    for _, animalInfo in ipairs(animalData) do
        -- Create new animal at vehicle location
        local newAnimal = addAnimal(cell, math.floor(x), math.floor(y), math.floor(z), animalInfo.animalType,
            animalInfo.breed, animalInfo.skeleton)

        if newAnimal then
            -- Add to trailer using proper network command
            sendAddAnimalInTrailer(newAnimal, player, vehicle)
            recreatedCount = recreatedCount + 1
        end
    end

    return recreatedCount
end

local function snapshotVehicle(vehicle)
    local data = {}

    data.script = vehicle:getScriptName()
    data.x = vehicle:getX()
    data.y = vehicle:getY()
    data.z = vehicle:getZ()
    -- Store vehicle heading as Z angle (yaw)
    data.dir = vehicle:getDir()

    data.skin = vehicle:getSkinIndex()
    data.rust = vehicle:getRust()
    -- Color is stored as HSV components, not a single value
    data.colorHue = vehicle:getColorHue()
    data.colorSaturation = vehicle:getColorSaturation()
    data.colorValue = vehicle:getColorValue()
    data.keyId = vehicle:getKeyId()

    data.engineQuality = vehicle:getEngineQuality()
    data.engineLoudness = vehicle:getEngineLoudness()
    data.enginePower = vehicle:getEnginePower()
    -- Battery is a part, not a direct property
    local battery = vehicle:getPartById("Battery")
    data.batteryCharge = battery and battery:getInventoryItem() and battery:getInventoryItem():getDelta() or 0

    data.modData = vehicle:getModData()

    data.parts = {}
    data.animalData = {}

    local partCount = vehicle:getPartCount()
    for i = 0, partCount - 1 do
        local part = vehicle:getPartByIndex(i)
        if part then
            local partData = {}
            partData.id = part:getId()
            partData.condition = part:getCondition()
            partData.have = part:getItemType() ~= nil

            if part:getInventoryItem() then
                partData.item = part:getInventoryItem():getFullType()
            end

            data.parts[partData.id] = partData
        end
    end
    local animals = vehicle:getAnimals()
    if animals then
        for i = 0, animals:size() - 1 do
            local animal = animals:get(i)
            if animal then -- Only capture valid animals
                table.insert(data.animalData, {
                    animalType = animal:getAnimalType(),
                    breed = animal:getBreed(), -- This is an AnimalBreed object reference
                    skeleton = animal:shouldBeSkeleton()
                })
            end
        end
    end

    pcall(function()
        -- Capture towing relationships
        data.isTowing = vehicle:getVehicleTowing() ~= nil
        data.isTowed = vehicle:getVehicleTowedBy() ~= nil
        if data.isTowing then
            local towedVehicle = vehicle:getVehicleTowing()
            data.towedVehicleId = towedVehicle:getId()
        end
        if data.isTowed then
            local towingVehicle = vehicle:getVehicleTowedBy()
            data.towingVehicleId = towingVehicle:getId()
        end
    end)

    pcall(function()
        data.tires = {}
        for wheelIndex = 0, 3 do -- MAX_WHEELS = 4
            -- Note: Can't directly get tire inflation from Lua, it's stored in wheel parts
            local wheel = vehicle:getPartById("Wheel" .. wheelIndex)
            if wheel then
                data.tires[wheelIndex] = {
                    inflation = wheel:getContainerContentAmount() or 100, -- Approximation
                    condition = wheel:getCondition()
                }
            end
        end
    end)

    return data
end

local function spawnVehicleFromData(data)
    local square = getCell():getGridSquare(data.x, data.y, data.z)
    if not square then
        return nil
    end

    -- addVehicleDebug signature: scriptName, direction, skinIndex, square
    local newVehicle = addVehicleDebug(data.script, data.dir, data.skin, square)

    return newVehicle
end

local function applyVehicleData(vehicle, data)
    vehicle:setSkinIndex(data.skin)
    vehicle:setRust(data.rust)
    -- Use setColorHSV instead of setColor
    vehicle:setColorHSV(data.colorHue, data.colorSaturation, data.colorValue)
    -- Note: keyId cannot be set after creation, it's read-only

    -- Use setEngineFeature instead of individual setters
    vehicle:setEngineFeature(data.engineQuality, data.engineLoudness, data.enginePower)

    -- Set battery charge through the Battery part
    local battery = vehicle:getPartById("Battery")
    if battery and battery:getInventoryItem() and data.batteryCharge then
        battery:getInventoryItem():setDelta(data.batteryCharge)
    end

    local md = vehicle:getModData()
    for k, v in pairs(data.modData) do
        md[k] = v
    end

    for partId, partData in pairs(data.parts) do
        local part = vehicle:getPartById(partId)
        if part then
            part:setCondition(partData.condition)
            vehicle:transmitPartCondition(part)

            if partData.item then
                part:setInventoryItem(instanceItem(partData.item))
                vehicle:transmitPartItem(part)
            end
        end
    end

    -- Transmit all changes to clients
    vehicle:transmitEngine()
    vehicle:transmitRust()
    vehicle:transmitColorHSV()
    vehicle:transmitSkinIndex()

    pcall(function()
        if data.isTowed and data.towingVehicleId then
            local towingVehicle = getVehicleById(data.towingVehicleId)
            if towingVehicle then
                -- Need attachment names - check vehicle script for proper names
                towingVehicle:setVehicleTowing(vehicle, "rearattachment", "frontattachment")
                print("SERVER: Restored towing relationship")
            end
        end
    end)

    pcall(function()
        -- Restore tire pressure - wheels should be at normal inflation
        if data.tires then
            for wheelIndex, tireData in pairs(data.tires) do
                -- Set tire inflation to 100 (fully inflated)
                vehicle:setTireInflation(wheelIndex, 100)
                vehicle:setTireRemoved(wheelIndex, false)
            end
        end
    end)

    return vehicle
end

-- Remove null animals from the vehicle's animals ArrayList
-- This allows permanentlyRemove() to complete without NPE
-- but must be executed after the 1st permanentlyRemove() 
-- to allow the thread in loop to free the object reference
local function removeNullAnimalsFromVehicle(vehicle)
    if not vehicle then
        return 0
    end

    local animals = vehicle:getAnimals()
    if not animals then
        return 0
    end

    local removedCount = 0
    local originalCount = animals:size()

    print("SERVER: Attempting to remove " .. originalCount .. " animals (including nulls)")

    -- Collect indices of null animals
    local nullIndices = {}
    for i = 0, originalCount - 1 do
        local animal = animals:get(i)
        if animal == nil then
            table.insert(nullIndices, i)
        end
    end

    -- Remove from highest index to lowest to avoid index shifting issues
    for i = #nullIndices, 1, -1 do
        local idx = nullIndices[i]
        local success, err = pcall(function()
            -- Try ArrayList.remove() directly
            animals:remove(idx)
        end)

        if success then
            removedCount = removedCount + 1
            print("SERVER: Removed null animal at index " .. idx)
        else
            print("SERVER: Failed to remove null at index " .. idx .. ": " .. tostring(err))
        end
    end

    print("SERVER: Successfully removed " .. removedCount .. " of " .. #nullIndices .. " null animals")
    return removedCount
end

-- Clean null animals from a vehicle's animals ArrayList
-- By completely replacing the corrupted vehicle with a fresh one using /addvehicle command
local function cleanVehicleAnimals(vehicle,player)
    if not vehicle then
        print("SERVER: cleanVehicleAnimals - vehicle is nil")
        return 0
    end

    local animals = vehicle:getAnimals()
    if not animals then
        print("SERVER: cleanVehicleAnimals - vehicle has no animals array")
        return 0
    end

    local originalCount = animals:size()
    local removedCount = 0

    print("SERVER: Cleaning vehicle animals, original count: " .. originalCount)

    -- Collect valid animals first
    local validAnimals = {}
    for i = 0, originalCount - 1 do
        local animal = animals:get(i)
        if animal ~= nil then
            table.insert(validAnimals, animal)
            print("SERVER: Found valid animal at index " .. i)
        else
            removedCount = removedCount + 1
            print("SERVER: Found null animal at index " .. i)
        end
    end

    if removedCount == 0 then
        print("SERVER: No null animals found, no replacement needed")
        return 0
    end

    print("SERVER: Vehicle is corrupted with " .. removedCount .. " null animals")
    print("SERVER: Removing corrupted vehicle to free stuck thread")
    print("SERVER: WARNING: Animals in this vehicle will be lost!")

    -- Store properties for logging
    local scriptName = vehicle:getScriptName()
    local oldX = vehicle:getX()
    local oldY = vehicle:getY()
    local oldZ = vehicle:getZ()
    local oldId = vehicle:getId()

    print("SERVER: Corrupted vehicle details:")
    print("SERVER:   ID: " .. oldId)
    print("SERVER:   Script: " .. scriptName)
    print("SERVER:   Position: " .. oldX .. ", " .. oldY .. ", " .. oldZ)
    print("SERVER:   Total animals: " .. originalCount)
    print("SERVER:   Null animals: " .. removedCount)

    -- Snapshot vehicle data before removal
    local newVehiclenSnapshot = snapshotVehicle(vehicle)

    -- Remove old corrupted vehicle FIRST to avoid conflicts
    -- We expect this to throw an NPE due to the null animal, but it DOES remove the vehicle and unstuck the thread
    local success, err = pcall(function()
        vehicle:permanentlyRemove()
    end)

    if success then
        print("SERVER: Removed corrupted vehicle cleanly")
    else
        print("SERVER: Removed corrupted vehicle (expected error caught: " .. tostring(err) .. ")")
    end

    local newVehicle = spawnVehicleFromData(newVehiclenSnapshot)
    applyVehicleData(newVehicle, newVehiclenSnapshot)
    print("SERVER: Copied visual properties")

    -- Recreate animals in new vehicle
    local animalCount = recreateAnimals(newVehicle, newVehiclenSnapshot.animalData, player)
    print("[AnimalsFixes] Recreated " .. animalCount .. " animals in new vehicle")

    print("SERVER: Vehicle replacement complete!")
    print("SERVER: Cleaned vehicle animals: " .. originalCount .. " -> " .. #validAnimals .. " (removed " ..
              removedCount .. " nulls)")

    print("Trying o clear the old vehicle reference")
    local success, err = pcall(function()
        removeNullAnimalsFromVehicle(vehicle)
        vehicle:permanentlyRemove()
    end)
    return removedCount
end

Commands.InsertNullAnimal = function(player, args)
    print("SERVER: Received InsertNullAnimal command from player " .. player:getUsername())

    local vehicleId = args.vehicleId
    if not vehicleId then
        print("SERVER: No vehicle ID provided")
        return
    end

    -- Find the vehicle by ID
    local vehicle = getVehicleById(vehicleId)
    if not vehicle then
        print("SERVER: Vehicle not found with ID: " .. tostring(vehicleId))
        return
    end

    print("SERVER: Found vehicle: " .. tostring(vehicle:getScript():getName()))

    -- Insert null animal on SERVER side
    local animals = vehicle:getAnimals()
    if animals then
        animals:add(nil)
        print("SERVER: !!! NULL ANIMAL INSERTED !!! This should cause server-side NPE loop")
        print("SERVER: Animals count after null insertion: " .. animals:size())
    else
        print("SERVER: Vehicle has no animals array")
    end
end

Commands.CleanAnimals = function(player, args)
    print("SERVER: Received CleanAnimals command from player " .. player:getUsername())

    local vehicleId = args.vehicleId
    if not vehicleId then
        print("SERVER: No vehicle ID provided")
        return
    end

    -- Find the vehicle by ID on the SERVER
    local vehicle = getVehicleById(vehicleId)
    if not vehicle then
        print("SERVER: Vehicle not found with ID: " .. tostring(vehicleId))
        return
    end

    print("SERVER: Found vehicle: " .. tostring(vehicle:getScript():getName()))

    -- Clean null animals on SERVER side
    local removedCount = cleanVehicleAnimals(vehicle,player)

    -- Notify the client
    sendServerCommand(player, "AnimalFixes", "CleanResult", {
        vehicleId = vehicleId,
        removedCount = removedCount
    })
end

-- Scan all vehicles on server and auto-clean
Commands.ScanAndCleanAll = function(player, args)
    print("SERVER: Received ScanAndCleanAll command from player " .. player:getUsername())

    local totalCleaned = 0
    local vehiclesProcessed = 0

    local cell = getCell()
    if not cell then
        print("SERVER: No cell found")
        return
    end

    local vehicles = cell:getVehicles()
    if not vehicles then
        print("SERVER: No vehicles found")
        return
    end

    for i = 0, vehicles:size() - 1 do
        local vehicle = vehicles:get(i)
        if vehicle then
            vehiclesProcessed = vehiclesProcessed + 1
            local animals = vehicle:getAnimals()
            if animals and animals:size() > 0 then
                local removed = cleanVehicleAnimals(vehicle)
                totalCleaned = totalCleaned + removed
            end
        end
    end

    print("SERVER: Scan complete - processed " .. vehiclesProcessed .. " vehicles, cleaned " .. totalCleaned ..
              " null animals")

    -- Notify the client
    sendServerCommand(player, "AnimalFixes", "ScanResult", {
        vehiclesProcessed = vehiclesProcessed,
        totalCleaned = totalCleaned
    })
end

-- Register server commands
local function OnClientCommand(module, command, player, args)
    if module == "AnimalFixes" and Commands[command] then
        Commands[command](player, args)
    end
end

Events.OnClientCommand.Add(OnClientCommand)

print("Animal Fixes Server Commands Loaded")
