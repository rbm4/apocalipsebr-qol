--[[
    MM_MainServer.lua
    Vehicle Migration Module — Server-side vehicle spawning from JSONL

    Periodically checks for a JSONL file written by an external backend.
    Each line describes a vehicle to spawn (script, coordinates, items).
    Vehicles are created via addVehicleDebug, items placed into the correct
    part containers by ID, and a vehicle key is created in the first container.

    After all entries are processed the file is cleared (contents emptied).

    ---------------------------------------------------------------
    JSONL Entry Schema (one JSON object per line):
    ---------------------------------------------------------------
    {
        "scriptName": "Base.SportsCar",        -- required: vehicle script full type
        "x": 7073.5,                           -- required: world X coordinate
        "y": 7677.37,                          -- required: world Y coordinate
        "items": [                             -- optional: array of items
            {
                "fullType": "Base.WaterBottle", -- required: item full type
                "count": 1,                     -- optional: defaults to 1
                "container": "TruckBed"         -- required: must match a vehicle part ID
            }
        ]
    }

    Defaults (not required in the file):
        z         = 0          (ground level)
        createKey = true       (vehicle key placed in first available container)
    ---------------------------------------------------------------
]]

require "MigrationModule/MM_FileHandler"

-----------------------------------------------------------
-- Constants
-----------------------------------------------------------

local MIGRATION_FILENAME = "VehicleMigration.jsonl"
local DEFAULT_Z          = 0
local DEFAULT_DIR        = IsoDirections.S

-----------------------------------------------------------
-- Helpers
-----------------------------------------------------------

local function log(msg)
    MigrationFileHandler.log(msg)
end

--- Build a lookup table of part containers: { [partId] = ItemContainer }
--- @param vehicle IsoVehicle
--- @return table containers
local function buildContainerMap(vehicle)
    local containers = {}
    local partCount = vehicle:getPartCount()
    for i = 0, partCount - 1 do
        local part = vehicle:getPartByIndex(i)
        if part then
            local container = part:getItemContainer()
            if container then
                local partId = part:getId()
                if partId then
                    containers[partId] = container
                end
            end
        end
    end
    return containers
end

--- Get the first available ItemContainer from a vehicle (for key placement)
--- @param containers table The container map from buildContainerMap
--- @return ItemContainer|nil
local function getFirstContainer(containers)
    -- Prefer GloveBox > SeatFrontRight > any other
    local preferred = { "GloveBox", "SeatFrontRight", "SeatFrontLeft", "TruckBed" }
    for _, partId in ipairs(preferred) do
        if containers[partId] then
            return containers[partId]
        end
    end
    -- Fallback: return whatever is first
    for _, container in pairs(containers) do
        return container
    end
    return nil
end

-----------------------------------------------------------
-- Vehicle Preparation (clear loot + fill gas)
-----------------------------------------------------------

--- Clear all default items from every container and fill the gas tank
--- so the migrated vehicle is ready to drive with only the player's items.
--- @param vehicle IsoVehicle
--- @param containers table Container map from buildContainerMap
local function prepareVehicle(vehicle, containers)
    -- Clear all containers so the spawned default loot doesn't conflict with migrated items
    pcall(function()
        local clearedCount = 0
        for partId, container in pairs(containers) do
            local itemCount = container:getItems():size()
            if itemCount > 0 then
                container:removeAllItems()
                clearedCount = clearedCount + itemCount
            end
        end
        if clearedCount > 0 then
            log("Cleared " .. clearedCount .. " default items from all containers")
        end
    end)

    -- Fill gas tank to full so the player can use the vehicle immediately
    pcall(function()
        local tank = vehicle:getPartById("GasTank")
        if tank then
            local capacity = tank:getContainerCapacity()
            if capacity and capacity > 0 then
                tank:setContainerContentAmount(capacity)
                vehicle:transmitPartCondition(tank)
                log("Filled gas tank to " .. tostring(capacity) .. "L")
            end
        end
    end)

    -- Unlock all doors and trunk so the player can access the vehicle immediately
    pcall(function()
        local unlockedCount = 0
        local partCount = vehicle:getPartCount()
        for i = 0, partCount - 1 do
            local part = vehicle:getPartByIndex(i)
            if part then
                local door = part:getDoor()
                if door and door:isLocked() then
                    door:setLocked(false)
                    unlockedCount = unlockedCount + 1
                end
            end
        end
        if unlockedCount > 0 then
            log("Unlocked " .. unlockedCount .. " doors/trunk")
        end
    end)

    -- Set all vehicle parts to 100% condition so the vehicle is in perfect shape
    pcall(function()
        local repairedCount = 0
        local partCount = vehicle:getPartCount()
        for i = 0, partCount - 1 do
            local part = vehicle:getPartByIndex(i)
            if part then
                local condition = part:getCondition()
                if condition < 100 then
                    part:setCondition(100)
                    vehicle:transmitPartCondition(part)
                    repairedCount = repairedCount + 1
                end
            end
        end
        if repairedCount > 0 then
            log("Repaired " .. repairedCount .. " parts to 100% condition")
        end
    end)
end

-----------------------------------------------------------
-- Missing Parts Installation
-----------------------------------------------------------

--- Install all missing parts defined in the vehicle script.
--- Some modded vehicles define parts (e.g. roof racks, extra containers) that
--- may not have their inventory items installed after addVehicleDebug.
--- This ensures every part slot is populated so its container is available.
--- Must be called BEFORE buildContainerMap so new containers are included.
--- @param vehicle IsoVehicle
local function installMissingParts(vehicle)
    local ok, err = pcall(function()
        local installedCount = 0
        local partCount = vehicle:getPartCount()
        for i = 0, partCount - 1 do
            local part = vehicle:getPartByIndex(i)
            if part and not part:getInventoryItem() then
                -- getItemType() returns a Java ArrayList<String>, not a plain string
                local itemTypes = part:getItemType()
                if itemTypes and not itemTypes:isEmpty() then
                    local itemType = itemTypes:get(0)
                    if itemType and itemType ~= "" then
                        -- Validate the item exists in script definitions before creating
                        local scriptItem = ScriptManager.instance:FindItem(itemType)
                        if scriptItem then
                            local item = instanceItem(itemType)
                            if item then
                                item:setCondition(item:getConditionMax())
                                part:setInventoryItem(item)
                                vehicle:transmitPartItem(part)
                                installedCount = installedCount + 1
                            end
                        else
                            log("WARNING: Item type '" .. tostring(itemType) .. "' for part '" .. (part:getId() or "?") .. "' not found in script definitions, skipping")
                        end
                    end
                end
            end
        end
        if installedCount > 0 then
            log("Installed " .. installedCount .. " missing parts on vehicle")
        end
    end)

    if not ok then
        log("ERROR: Failed to install missing parts: " .. tostring(err))
    end
end

-----------------------------------------------------------
-- Vehicle Spawning
-----------------------------------------------------------

--- Spawn a vehicle from a migration entry
--- @param entry table Parsed JSONL entry
--- @return IsoVehicle|nil vehicle The spawned vehicle, or nil on failure
--- @return string reason 'retry' if chunk not loaded (retryable), 'failed' otherwise
local function spawnVehicle(entry)
    local x = entry.x
    local y = entry.y
    local z = DEFAULT_Z

    local square = getCell():getGridSquare(x, y, z)
    if not square then
        log("RETRY: Could not get grid square at (" .. tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z) .. ") — chunk not loaded, will retry")
        return nil, "retry"
    end

    local ok, vehicle = pcall(function()
        return addVehicleDebug(entry.scriptName, DEFAULT_DIR, nil, square)
    end)

    if not ok or not vehicle then
        log("ERROR: Failed to spawn vehicle '" .. tostring(entry.scriptName) .. "' at (" .. tostring(x) .. ", " .. tostring(y) .. "): " .. tostring(vehicle))
        return nil, "failed"
    end

    log("Spawned vehicle '" .. entry.scriptName .. "' at (" .. tostring(x) .. ", " .. tostring(y) .. ")")
    return vehicle, "success"
end

-----------------------------------------------------------
-- Item Insertion (container-aware)
-----------------------------------------------------------

--- Insert items into the vehicle's specific part containers
--- @param vehicle IsoVehicle
--- @param items table Array of item entries from the JSONL
--- @param containers table Container map from buildContainerMap
local function insertItems(vehicle, items, containers)
    if not items or #items == 0 then
        return
    end

    local addedCount = 0
    local skippedCount = 0

    for _, itemData in ipairs(items) do
        local ok, err = pcall(function()
            -- Validate required fields
            if not itemData.fullType then
                log("WARNING: Item entry missing 'fullType', skipping")
                skippedCount = skippedCount + 1
                return
            end
            if not itemData.container then
                log("WARNING: Item '" .. itemData.fullType .. "' missing 'container' field, skipping")
                skippedCount = skippedCount + 1
                return
            end

            -- Find the target container by part ID
            local targetContainer = containers[itemData.container]
            if not targetContainer then
                log("WARNING: Container '" .. itemData.container .. "' not found on vehicle for item '" .. itemData.fullType .. "', skipping")
                skippedCount = skippedCount + 1
                return
            end

            -- Validate item type exists in script definitions before creating (avoids Java NPE on invalid types)
            local fullType = itemData.fullType
            local scriptItem = ScriptManager.instance:FindItem(fullType)
            if not scriptItem then
                log("WARNING: Item type '" .. fullType .. "' not found in script definitions, skipping")
                skippedCount = skippedCount + 1
                return
            end

            local newItem = instanceItem(fullType)
            if not newItem then
                log("WARNING: Could not create item instance for '" .. fullType .. "', skipping")
                skippedCount = skippedCount + 1
                return
            end

            -- Set count if > 1
            local count = itemData.count or 1
            if count > 1 then
                newItem:setCount(count)
            end

            -- Add to the correct container
            targetContainer:AddItem(newItem)
            addedCount = addedCount + 1
        end)

        if not ok then
            log("ERROR: Exception inserting item: " .. tostring(err))
            skippedCount = skippedCount + 1
        end
    end

    log("Inserted " .. addedCount .. " items into vehicle (" .. skippedCount .. " skipped)")
end

-----------------------------------------------------------
-- Key Creation
-----------------------------------------------------------

--- Create a vehicle key and place it in the first available container
--- @param vehicle IsoVehicle
--- @param containers table Container map from buildContainerMap
local function createAndPlaceKey(vehicle, containers)
    local ok, err = pcall(function()
        local key = vehicle:createVehicleKey()
        if not key then
            log("WARNING: createVehicleKey() returned nil")
            return
        end

        local container = getFirstContainer(containers)
        if container then
            container:AddItem(key)
            log("Created vehicle key and placed in container")
        else
            log("WARNING: No container available to place vehicle key")
        end
    end)

    if not ok then
        log("ERROR: Failed to create vehicle key: " .. tostring(err))
    end
end

-----------------------------------------------------------
-- Entry Processing
-----------------------------------------------------------

--- Validate that a JSONL entry has the required fields
--- @param entry table
--- @param index number Line/entry index for logging
--- @return boolean
local function validateEntry(entry, index)
    if not entry.scriptName or type(entry.scriptName) ~= "string" or entry.scriptName == "" then
        log("ERROR: Entry #" .. index .. " missing or invalid 'scriptName', skipping")
        return false
    end
    if not entry.x or type(entry.x) ~= "number" then
        log("ERROR: Entry #" .. index .. " missing or invalid 'x' coordinate, skipping")
        return false
    end
    if not entry.y or type(entry.y) ~= "number" then
        log("ERROR: Entry #" .. index .. " missing or invalid 'y' coordinate, skipping")
        return false
    end
    return true
end

--- Process a single migration entry: spawn vehicle, insert items, create key
--- @param entry table Parsed JSONL entry
--- @param index number Entry index for logging
--- @return string result 'success', 'failed' (permanent), or 'retry' (chunk not loaded)
local function processEntry(entry, index)
    if not validateEntry(entry, index) then
        return "failed"
    end

    -- Spawn the vehicle
    local vehicle, reason = spawnVehicle(entry)
    if not vehicle then
        return reason -- 'retry' for unloaded chunk, 'failed' for other errors
    end

    -- Install any missing parts before building the container map,
    -- so newly installed parts (e.g. modded roof racks) have their containers available
    installMissingParts(vehicle)

    -- Build container map once for item insertion and key placement
    local containers = buildContainerMap(vehicle)

    -- Clear default spawned items and fill gas tank
    prepareVehicle(vehicle, containers)

    -- Insert items into their specific containers
    insertItems(vehicle, entry.items, containers)

    -- Create key (default: true)
    local shouldCreateKey = true
    if entry.createKey == false then
        shouldCreateKey = false
    end
    if shouldCreateKey then
        createAndPlaceKey(vehicle, containers)
    end

    return "success"
end

-----------------------------------------------------------
-- Periodic Hook
-----------------------------------------------------------

--- Main processing function — called every in-game minute
--- Checks for the JSONL file, processes all entries, then clears the file.
--- Entries that failed due to unloaded chunks are written back for retry.
local function onPeriodicCheck()
    if not isServer() then return end

    local entries, rawLines = MigrationFileHandler.readEntries(MIGRATION_FILENAME)
    if #entries == 0 then
        return -- No file or empty file — silent, no log spam
    end

    log("Read " .. #entries .. " entries from " .. MIGRATION_FILENAME)

    local successCount = 0
    local failCount = 0
    local retryLines = {}

    for i, entry in ipairs(entries) do
        local result = processEntry(entry, i)
        if result == "success" then
            successCount = successCount + 1
        elseif result == "retry" then
            -- Keep the raw line for retry on next cycle
            table.insert(retryLines, rawLines[i])
        else
            failCount = failCount + 1
        end
    end

    -- Write back only the retryable entries, or clear if none remain
    if #retryLines > 0 then
        MigrationFileHandler.writeLines(MIGRATION_FILENAME, retryLines)
        log("Processing complete: " .. successCount .. " succeeded, " .. failCount .. " failed, " .. #retryLines .. " pending retry")
    else
        MigrationFileHandler.clearFile(MIGRATION_FILENAME)
        log("Processing complete: " .. successCount .. " succeeded, " .. failCount .. " failed — file cleared")
    end
end

-----------------------------------------------------------
-- Event Registration
-----------------------------------------------------------

Events.EveryOneMinute.Add(onPeriodicCheck)

log("MM_MainServer module loaded — checking '" .. MIGRATION_FILENAME .. "' every minute")
