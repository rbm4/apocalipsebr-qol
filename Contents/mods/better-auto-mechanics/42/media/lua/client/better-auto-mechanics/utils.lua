-- Ensure we have access to the UI global for the floor container
require "ISUI/ISInventoryPage"

BAM = BAM or {}


function BAM.GetNextUninstallablePart(player, vehicle)
    --DebugLog.log("-> Searching for next uninstallable part...")
    -- Collect all installed car parts into a list for sorting
    local validParts = {}
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        table.insert(validParts, part)
    end

    local sortedParts = BAM.SortParts(validParts)

    -- Check each part for uninstall possibility and XP eligibility, return the first one found
    for _, part in ipairs(sortedParts) do
        if BAM.PartCanBeUninstalled(player, vehicle, part) then
            return part
        end
    end
    return nil
end


function BAM.GetNextInstallablePartAndItem(player, vehicle)
    --DebugLog.log("-> Searching for next installable part...")
    -- Collect all uninstalled car parts into a list for sorting
    local validParts = {}
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        table.insert(validParts, part)
    end

    local sortedParts = BAM.SortParts(validParts)

    -- Check each part for install possibility, return the first one found
    for _, part in ipairs(sortedParts) do
        local item = BAM.PartCanBeInstalled(player, vehicle, part)
        if item then
            return part, item
        end
    end
    return nil, nil
end


function BAM.PartCanBeUninstalled(player, vehicle, part)
    --DebugLog.log("Checking if part " .. part:getId() .. " can be uninstalled...")
    -- 1. Check if the physical action is possible (tools, location, etc.)
    if not part:getInventoryItem() then
        --DebugLog.log("Part " .. part:getId() .. " has no item installed, cannot uninstall.")
        return false
    end
    if not part:getVehicle():canUninstallPart(player, part) then
        --DebugLog.log("Part " .. part:getId() .. " cannot be uninstalled due to physical constraints.")
        return false
    end
    if BAM.InaccessibleParts[part:getId()] then
        --DebugLog.log("Part " .. part:getId() .. " is marked as inaccessible, cannot uninstall.")
        return false
    end

    -- 2. Get part success chance
    local successChance = BAM.GetPartSuccessChance(player, part, "uninstall")
    if successChance < BAM.GetOptionMinPartSuccessChance() then
        --DebugLog.log("Part " .. part:getId() .. " has a success chance of " .. tostring(successChance) .. "%, which is below the minimum threshold.")
        return false
    end

    -- 3. Check for smashed cars, their front windows are inaccessible
    if part:getId():find("WindowFront") or part:getId():find("Seat") then
        local scriptName = vehicle:getScript():getName()
        --DebugLog.log("-> Vehicle script name: " .. scriptName)
        if string.find(scriptName, "Burnt") or string.find(scriptName, "Smashed") then
            --DebugLog.log("-> Vehicle is burnt or smashed, cannot uninstall " .. part:getId())
            return false
        end
    end

    -- 4. Check if the player is eligible for XP for this part (Cooldown check)
    -- Key format: PartID + VehicleID + "1" (1 is for Uninstall)
    if not BAM.CanGainXP(player, vehicle, part, 1) then
        --DebugLog.log("Player cannot gain XP for uninstalling part " .. part:getId() .. " due to cooldown.")
        return false
    end

    return true
end


function BAM.PartCanBeInstalled(player, vehicle, part)
    -- 1. Check if the physical action is possible (tools, location, etc.)
    if part:getInventoryItem() ~= nil then
        --DebugLog.log("Part " .. part:getId() .. " already has an item installed, cannot install.")
        return nil
    end
    if not part:getVehicle():canInstallPart(player, part) then
        --DebugLog.log("Part " .. part:getId() .. " cannot be installed due to physical constraints.")
        return nil
    end
    if BAM.InaccessibleParts[part:getId()] then
        --DebugLog.log("Part " .. part:getId() .. " is marked as inaccessible, cannot install.")
        return nil
    end

    -- 2. Get part success chance
    local successChance = BAM.GetPartSuccessChance(player, part, "install")
    if successChance < BAM.GetOptionMinPartSuccessChance() then
        --DebugLog.log("Part " .. part:getId() .. " has a success chance of " .. tostring(successChance) .. "%, which is below the minimum threshold.")
        return nil
    end

    -- 3. Check if the player has the required part in inventory or on ground
    local item = BAM.GetAnyItemOnPlayerThatMatchesThatPart(player, part)
    if not item then
        --DebugLog.log("Player does not have required item for installing part " .. part:getId() .. ".")
        return nil
    end

    -- 4. Check if the item would fit into the players inventory if its not on the player
    if BAM.WouldExceedWeightLimit(player, item) then
        --DebugLog.log("Item " .. item:getName() .. " would exceed weight limit if used to install part " .. part:getId() .. ".")
        return nil
    end

    return item
end



----------------------------------------
-- CACHED SORTING DATA
----------------------------------------
local cachedRankLookup = nil
local function buildRankLookup()
    -- Define the train order
    -- Grouped by location on vehicle, and then by required tool to minimize tool switching
    local orderList = {
        -- Front
        "Radio", "Battery", "HeadlightLeft", "HeadlightRight", "Windshield", "EngineDoor",
        -- Front Left
        "BrakeFrontLeft", "SuspensionFrontLeft", "TireFrontLeft",
        -- Doors Left
        "SeatFrontLeft", "DoorFrontLeft", "WindowFrontLeft",
        "SeatMiddleLeft", "DoorMiddleLeft", "WindowMiddleLeft",
        "SeatRearLeft", "DoorRearLeft", "WindowRearLeft",
        -- Rear Left
        "BrakeRearLeft", "SuspensionRearLeft", "TireRearLeft",
        -- Rear
        "GasTank", "WindshieldRear", "HeadlightRearLeft", "HeadlightRearRight", "Muffler", "TrunkDoor", "DoorRear",
        -- Rear Right
        "BrakeRearRight", "SuspensionRearRight", "TireRearRight",
        -- Doors Right
        "SeatRearRight", "DoorRearRight", "WindowRearRight",
        "SeatMiddleRight", "DoorMiddleRight", "WindowMiddleRight",
        "SeatFrontRight", "DoorFrontRight", "WindowFrontRight",
        -- Front Right
        "BrakeFrontRight", "SuspensionFrontRight", "TireFrontRight",
        -- Impossible ones:
        "GloveBox", "Heater", "Engine", "TruckBed", "TruckBedOpen", "PassengerCompartment",
        "TrailerAnimalFood", "TrailerAnimalEggs",
    }

    -- Create a "Rank Map" for fast lookup
    -- This turns the list into: { ["Radio"] = 1, ["Battery"] = 2, ... }
    local lookup = {}
    for index, id in ipairs(orderList) do
        lookup[id] = index
    end
    return lookup
end


function BAM.SortParts(parts)
    -- Build cache only once
    if not cachedRankLookup then
        cachedRankLookup = buildRankLookup()
    end

    -- Sort the actual 'parts' table using the Rank Map
    table.sort(parts, function(a, b)
        local idA = a:getId()
        local idB = b:getId()

        -- Get the rank from our table.
        -- If an ID isn't in your list, we give it rank 999 (puts it at the very bottom)
        local rankA = cachedRankLookup[idA] or 999
        local rankB = cachedRankLookup[idB] or 999

        return rankA < rankB
    end)

    --DebugLog.log("Sorted parts order:")
    --for i, part in ipairs(parts) do
    --    DebugLog.log(i .. " - " .. part:getId())
    --end

    return parts
end


function BAM.GetAnyItemOnPlayerThatMatchesThatPart(player, part)
    if not part:getItemType() or part:getItemType():isEmpty() then return nil end

    local playerItems = VehicleUtils.getItems(player:getPlayerNum())

    -- Get all possible items on and around the player that can be installed
    for i = 0, part:getItemType():size() - 1 do
        local requiredItemType = part:getItemType():get(i)
        local matchingPlayerItems = playerItems[requiredItemType]

        if matchingPlayerItems and #matchingPlayerItems > 0 then
            for i, item in ipairs(matchingPlayerItems) do
                return item  -- Return the first matching item
            end
        end
    end
    return nil
end


function BAM.DropBrokenItems(player)
    local inventory = player:getInventory()
    local items = inventory:getItems()
    local itemsToDrop = {}

    -- 1. Identify items to drop
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:isBroken() and not item:isFavorite() and not item:isEquipped() then
            table.insert(itemsToDrop, item)
        end
    end

    if #itemsToDrop == 0 then
        return
    end

    -- 2. Get the "Floor" Container
    -- In Zomboid, the floor is a virtual container managed by ISInventoryPage
    local playerNum = player:getPlayerNum()
    local floorContainer = ISInventoryPage.floorContainer[playerNum + 1]

    if not floorContainer then
        --DebugLog.log("Error: Could not find floor container!")
        return
    end

    --DebugLog.log("BAM: Dropping " .. #itemsToDrop .. " items to floor...")

    -- 3. Queue the Transfer Actions
    for _, item in ipairs(itemsToDrop) do
        -- ISInventoryTransferAction:new(character, item, srcContainer, destContainer, time)
        local action = ISInventoryTransferAction:new(
            player,
            item,
            item:getContainer(),
            floorContainer,
            10 -- Time in ticks (10 is very fast)
        )
        ISTimedActionQueue.add(action)
    end
end


function BAM.GetPartSuccessChance(player, part, actionType)
    local successChance = 0
    local keyvalues = part:getTable(actionType)
    if keyvalues then
        local perks = keyvalues.skills
        local perksTable = VehicleUtils.getPerksTableForChr(perks, player)
        successChance, _ = VehicleUtils.calculateInstallationSuccess(perks, player, perksTable)
    end
    return successChance
end


--- Checks if adding an item would exceed the player's hard carry limit.
-- @param player The IsoPlayer object (e.g., getPlayer())
-- @param item The IsoWorldInventoryObject to check
-- @return boolean true if it would exceed the limit, false otherwise
function BAM.WouldExceedWeightLimit(player, item)
    if not player or not item then return false end

    --DebugLog.log("Checking if adding item " .. item:getName() .. " would exceed weight limit...")
    -- 1. Get the actual item weight
    local inventory = player:getInventory()
    local itemWeight = item:getActualWeight()
    --DebugLog.log("Item weight: " .. tostring(itemWeight))

    -- 2. Check if the item is currently in the players inventory
    -- If it is already in the main inventory, we return false because it won't add any weight
    if inventory:contains(item) then
        --DebugLog.log("Item is already in inventory, so it will fit.")
        return false
    end

    -- 3. Calculate weight after adding the item
    local currentWeight = inventory:getCapacityWeight() -- Current weight in main inventory
    local limitWeight = inventory:getCapacity()
    --DebugLog.log("Current inventory weight:  " .. tostring(currentWeight) .. " / " .. tostring(limitWeight))
    --DebugLog.log("Expected inventory weight: " .. tostring(currentWeight + itemWeight) .. " / " .. tostring(limitWeight))

    return (currentWeight + itemWeight) > limitWeight
end


function BAM.WorkOnNextPartInXTicks(ticks)
    BAM.WorkDelayTimer = ticks
end


function BAM.CheckGameSpeedInXTicks(ticks)
    BAM.GameSpeedCheckTimer = ticks
end


function BAM.SaveGameSpeed()
    BAM.PrevGameSpeed = getGameSpeed()
    BAM.PrevTimeMultiplier = getGameTime():getTrueMultiplier()
    --DebugLog.log("SAVED GAMESPEED: " .. BAM.PrevGameSpeed .. " - " .. BAM.PrevTimeMultiplier)
end


function BAM.RestoreGameSpeed()
    -- Check if the game speed got randomly reset by the game and restore it in that case
    -- Currently this can interfere with the player manually changing the game speed while training
    if getGameSpeed() < BAM.PrevGameSpeed and getGameSpeed() == 1 then
        setGameSpeed(BAM.PrevGameSpeed)
        getGameTime():setMultiplier(BAM.PrevTimeMultiplier)
        DebugLog.log("Reset gamespeed back to: " .. getGameSpeed() .. " | " .. getGameTime():getMultiplier() .. " | " .. getGameTime():getTrueMultiplier())
    end
end


----------------------------------------
-- CACHED GAME VERSION
----------------------------------------
local cachedMajor, cachedMinor, cachedPatch = nil, nil, nil


function BAM.GetGameVersion()
    if cachedMajor then
        return cachedMajor, cachedMinor, cachedPatch
    end

    -- getCore():getGameVersion()) doesn't return the path, so we extract it from the full version string
    local ver_str = getCore():getVersion()                            -- Returns string like: "42.13.1 1267173a2044ba62aa3d0a0e9899b15e9057de5c 2025-12-18 10:34:47 (ZB)"
    local major, minor, patch = ver_str:match("^(%d+)%.(%d+)%.(%d+)") -- Extract major, minor, patch numbers, here "42", "13", "1"
    cachedMajor = tonumber(major)
    cachedMinor = tonumber(minor)
    cachedPatch = tonumber(patch)
    --DebugLog.log("Detected game version: " .. cachedMajor .. "." .. cachedMinor .. "." .. cachedPatch)

    return cachedMajor, cachedMinor, cachedPatch
end


function BAM.GameVersionNewerThanOrEqual(majorReq, minorReq, patchReq)
    local major, minor, patch = BAM.GetGameVersion()

    if major > majorReq then
        return true
    elseif major == majorReq then
        if minor > minorReq then
            return true
        elseif minor == minorReq then
            return patch >= patchReq
        end
    end

    return false
end


----------------------------------------
-- UNINSTALL CATEGORIES
----------------------------------------

-- Each category maps to an explicit list of part IDs.
-- "Everything" uses nil to match all parts.
BAM.UninstallCategories = {
    {
        key = "everything",
        ids = nil,  -- nil means match all parts
    },
    {
        key = "tires",
        ids = { "TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight" },
    },
    {
        key = "doors",
        ids = { "DoorFrontLeft", "DoorFrontRight", "DoorMiddleLeft", "DoorMiddleRight", "DoorRearLeft", "DoorRearRight", "DoorRear", "TrunkDoor" },
    },
    {
        key = "windows",
        ids = { "WindowFrontLeft", "WindowFrontRight", "WindowMiddleLeft", "WindowMiddleRight", "WindowRearLeft", "WindowRearRight", "Windshield", "WindshieldRear" },
    },
    {
        key = "seats",
        ids = { "SeatFrontLeft", "SeatFrontRight", "SeatMiddleLeft", "SeatMiddleRight", "SeatRearLeft", "SeatRearRight" },
    },
    {
        key = "lights",
        ids = { "HeadlightLeft", "HeadlightRight", "HeadlightRearLeft", "HeadlightRearRight" },
    },
    {
        key = "brakes",
        ids = { "BrakeFrontLeft", "BrakeFrontRight", "BrakeRearLeft", "BrakeRearRight" },
    },
    {
        key = "suspension",
        ids = { "SuspensionFrontLeft", "SuspensionFrontRight", "SuspensionRearLeft", "SuspensionRearRight" },
    },
}


--- Returns a list of parts on the vehicle that the player can uninstall, filtered by category.
-- @param player IsoPlayer
-- @param vehicle BaseVehicle
-- @param categoryIds table|nil  A set-like table { ["TireFrontLeft"]=true, ... } or nil for all parts
-- @return table  List of VehiclePart objects
function BAM.GetUninstallablePartsByCategory(player, vehicle, categoryIds)
    local parts = {}
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        local id = part:getId()

        -- Filter: if categoryIds is provided, only include matching parts
        if categoryIds == nil or categoryIds[id] then
            -- Check if this part can actually be uninstalled (has item, game allows it)
            if part:getInventoryItem() and vehicle:canUninstallPart(player, part) then
                table.insert(parts, part)
            end
        end
    end
    return parts
end


