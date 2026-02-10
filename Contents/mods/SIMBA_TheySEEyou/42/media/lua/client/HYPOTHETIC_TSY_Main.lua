if isServer() then
    return
end

require "RegionManager_Config"

local SIMBA_TSY_TickCounter = 0
local SIMBA_TSY_ProcessedZombies = {} -- Track which zombies we've already processed
local SIMBA_TSY_RegionBounds = {} -- Store region boundaries from server
local SIMBA_TSY_BaselineSprinterChance = 0 -- Default when not in any region
local SIMBA_TSY_SprinterWalkTypes = {"Sprint1", "Sprint2", "Sprint3", "Sprint4", "Sprint5"}
local SIMBA_TSY_PlayerCurrentZones = {} -- Track which zones player is currently in
local SIMBA_TSY_PlayerPreviousZones = {} -- Track previous zones for comparison

-- Deterministic pseudo-random (matches server logic)
local function SIMBA_TSY_GetDeterministicRandom(zombieID, max)
    local hash = zombieID
    hash = ((hash * 1103515245) + 12345) % 2147483648
    return (hash % max)
end

local function SIMBA_TSY_GetRandomSprinterWalkType(zombieID)
    local index = SIMBA_TSY_GetDeterministicRandom(zombieID, #SIMBA_TSY_SprinterWalkTypes)
    return SIMBA_TSY_SprinterWalkTypes[index + 1]
end

-- Get sprinter chance for current position based on known regions
local function SIMBA_TSY_GetSprinterChance(x, y)
    -- Check which region contains this position
    for _, region in ipairs(RegionManager.Client.zoneData) do
        local bounds = region.bounds
        if x >= bounds.minX and x <= bounds.maxX and y >= bounds.minY and y <= bounds.maxY then
            -- Check if region has sprinter configuration
            if region.sprinterChance and type(region.sprinterChance) == "number" then
                local chance = region.sprinterChance
                if chance < 1 then
                    chance = 1
                end
                if chance > 100 then
                    chance = 100
                end
                return chance
            end
        end
    end

    -- No region found or region has no sprinter config
    return SIMBA_TSY_BaselineSprinterChance
end

-- Handle server commands
local function SIMBA_TSY_OnServerCommand(module, command, args)
    if module ~= "SIMBA_TSY" then
        return
    end

    if command == "ConfirmZombie" then
        local player = getPlayer()
        if not player then
            return
        end

        local cell = player:getCell()
        if not cell then
            return
        end

        local zombieList = cell:getZombieList()
        if not zombieList then
            return
        end

        local zombieID = args.zombieID
        local isSprinter = args.isSprinter
        local walkType = args.walkType

        -- Find and apply
        for i = 0, zombieList:size() - 1 do
            local zombie = zombieList:get(i)
            if zombie and not zombie:isDead() and zombie:getOnlineID() == zombieID then
                local modData = zombie:getModData()

                if isSprinter then
                    modData.SIMBA_TSY_IsSprinter = true
                    modData.SIMBA_TSY_WalkType = walkType
                    zombie:setWalkType(walkType)
                    print("SIMBA_TSY Client: Applied sprinter " .. walkType .. " to zombie " .. zombieID ..
                              " (server confirmed)")
                else
                    modData.SIMBA_TSY_IsSprinter = false
                    print("SIMBA_TSY Client: Zombie " .. zombieID .. " confirmed as non-sprinter")
                end

                -- Mark as processed so we don't recompute
                SIMBA_TSY_ProcessedZombies[zombieID] = true
                break
            end
        end
    elseif command == "RegionData" then
        -- Receive region boundaries with sprinter chances
        SIMBA_TSY_RegionBounds = args.regions or {}
        print("SIMBA_TSY Client: Received " .. #SIMBA_TSY_RegionBounds .. " region configurations")
    end
end

Events.OnServerCommand.Add(SIMBA_TSY_OnServerCommand)

-- Continuously validate and reapply sprinter walkType
local function SIMBA_TSY_ValidateSprinters(zombie)
    if not zombie or zombie:isDead() then
        return
    end

    local modData = zombie:getModData()

    if not modData.SIMBA_TSY_WalkType then
        return
    end

    -- Check if walkType needs correction
    local currentWalkType = zombie:getVariableString("zombiewalktype")
    zombie:setWalkType(modData.SIMBA_TSY_WalkType)
end

-- Check player zone changes and notify server
local function SIMBA_TSY_CheckPlayerZone(player)
    if not player then return end
    
    -- Request zone data if not loaded yet
    if not RegionManager or not RegionManager.Client or not RegionManager.Client.zoneData then
        sendClientCommand("RegionManager", "RequestAllBoundaries", {})
        print("[DEBUG CLIENT] Waiting for zone data, RequestAllBoundaries sent")
        return
    end
    
    local playerX = player:getX()
    local playerY = player:getY()
    
    -- Build current zones list
    local currentZones = {}
    for _, zone in ipairs(RegionManager.Client.zoneData) do
        local bounds = zone.bounds
        -- Check if player is inside this zone (AABB collision)
        if playerX >= bounds.minX and playerX <= bounds.maxX and 
           playerY >= bounds.minY and playerY <= bounds.maxY then
            currentZones[zone.id] = zone
        end
    end
    
    -- Check for zone entries (in current but not in previous)
    for zoneId, zoneData in pairs(currentZones) do
        if not SIMBA_TSY_PlayerPreviousZones[zoneId] then
            -- Player ENTERED this zone
            print("[DEBUG CLIENT] Player ENTERED zone: " .. zoneData.name)
            
            -- Determine zone type from properties sent by server
            local isSafeZone = (zoneData.pvpEnabled == false)
            local isPvpZone = (zoneData.pvpEnabled == true)
            
            -- Apply Safety state locally
            if isPvpZone then
                player:getSafety():setEnabled(false)
                player:getSafety():setCooldown(999999)
                print("[DEBUG CLIENT] Applied PVP state locally (Safety=false)")
            elseif isSafeZone then
                player:getSafety():setEnabled(true)
                player:getSafety():setCooldown(999999)
                print("[DEBUG CLIENT] Applied Safe Zone state locally (Safety=true)")
            end
            
            -- Show notification message if announceEntry is enabled
            if zoneData.announceEntry ~= false then
                local message = "Entering: " .. zoneData.name
                local color = zoneData.color or {r=255, g=255, b=255}
                player:Say(message, color.r / 255, color.g / 255, color.b / 255, UIFont.Medium, 3, "radio")
                print("[DEBUG CLIENT] Showed entry notification for " .. zoneData.name)
            else
                print("[DEBUG CLIENT] Suppressed entry notification (announceEntry=false)")
            end
            
            -- Notify server to sync with other clients (always send, regardless of announceEntry)
            sendClientCommand("RegionManager", "ClientZoneEntered", {
                zoneId = zoneId,
                zoneName = zoneData.name,
                isPvpZone = isPvpZone,
                isSafeZone = isSafeZone,
                safetyEnabled = player:getSafety():isEnabled()
            })
            print("[DEBUG CLIENT] Sent ClientZoneEntered to server for sync")
        end
    end
    
    -- Check for zone exits (in previous but not in current)
    for zoneId, zoneData in pairs(SIMBA_TSY_PlayerPreviousZones) do
        if not currentZones[zoneId] then
            -- Player EXITED this zone
            print("[DEBUG CLIENT] Player EXITED zone: " .. zoneData.name)
            
            -- Restore Safety state locally
            player:getSafety():setCooldown(0) -- Re-enable toggle button
            print("[DEBUG CLIENT] Restored Safety toggle on zone exit")
            
            -- Show notification message if announceExit is enabled
            if zoneData.announceExit ~= false then
                local message = "Left: " .. zoneData.name
                player:Say(message, 0.5, 0.5, 0.5, UIFont.Medium, 3, "radio")
                print("[DEBUG CLIENT] Showed exit notification for " .. zoneData.name)
            else
                print("[DEBUG CLIENT] Suppressed exit notification (announceExit=false)")
            end
            
            -- Notify server to sync with other clients (always send, regardless of announceExit)
            sendClientCommand("RegionManager", "ClientZoneExited", {
                zoneId = zoneId,
                zoneName = zoneData.name,
                safetyEnabled = player:getSafety():isEnabled()
            })
            print("[DEBUG CLIENT] Sent ClientZoneExited to server for sync")
        end
    end
    
    -- Update previous zones for next check
    SIMBA_TSY_PlayerPreviousZones = currentZones
end

-- Process unmarked zombies: compute roll and propose to server
local function SIMBA_TSY_ProcessZombies()
    local player = getPlayer()
    if not player then
        return
    end

    local cell = player:getCell()
    if not cell then
        return
    end

    local zombies = cell:getZombieList()
    if not zombies then
        return
    end

    if RegionManager and RegionManager.Client and RegionManager.Client.zoneData then
        local proposals = {}

        for i = 0, zombies:size() - 1 do
            local zombie = zombies:get(i)

            -- Validate existing sprinters
            SIMBA_TSY_ValidateSprinters(zombie)

            if zombie and not zombie:isDead() then
                local zombieID = zombie:getOnlineID()

                -- Only process if not already processed
                if not SIMBA_TSY_ProcessedZombies[zombieID] then
                    SIMBA_TSY_ProcessedZombies[zombieID] = true

                    -- Get zombie position
                    local zombieX = zombie:getX()
                    local zombieY = zombie:getY()

                    -- Determine sprinter chance based on region
                    local sprinterChance = SIMBA_TSY_GetSprinterChance(zombieX, zombieY)

                    -- Roll for sprinter
                    local roll = SIMBA_TSY_GetDeterministicRandom(zombieID, 100)
                    local isSprinter = roll < sprinterChance
                    local walkType = nil

                    if isSprinter then
                        walkType = SIMBA_TSY_GetRandomSprinterWalkType(zombieID)
                    end

                    -- Propose to server
                    table.insert(proposals, {
                        zombieID = zombieID,
                        isSprinter = isSprinter,
                        walkType = walkType
                    })
                end
            end
        end

        -- Send proposals to server
        if #proposals > 0 then
            sendClientCommand(player, "SIMBA_TSY", "ProposeZombies", {
                zombies = proposals
            })
            print("SIMBA_TSY Client: Proposed " .. #proposals .. " zombie states to server")
        end
        return
    end
    sendClientCommand("RegionManager", "RequestAllBoundaries", {})
    print("[DEBUG CLIENT] RequestAllBoundaries sent")
end

local function SIMBA_TSY_OnTick()
    SIMBA_TSY_TickCounter = SIMBA_TSY_TickCounter + 1

    -- Process zones and zombies every 120 ticks (2 seconds at 60 FPS)
    if SIMBA_TSY_TickCounter >= 120 then
        local player = getPlayer()
        if player then
            -- Check player zone changes first
            SIMBA_TSY_CheckPlayerZone(player)
            -- Then process zombies
            SIMBA_TSY_ProcessZombies()
        end
        SIMBA_TSY_TickCounter = 0
    end
end

Events.OnTick.Add(SIMBA_TSY_OnTick)

-- Request region data when player spawns and clear previous zone state
local function SIMBA_TSY_OnPlayerSpawn()
    local player = getPlayer()
    if player then
        -- Clear previous zone state (player could spawn inside a zone)
        SIMBA_TSY_PlayerPreviousZones = {}
        SIMBA_TSY_PlayerCurrentZones = {}
        print("SIMBA_TSY Client: Cleared zone state on player spawn")
        
        -- Request zone boundaries from RegionManager
        sendClientCommand("RegionManager", "RequestAllBoundaries", {})
        print("SIMBA_TSY Client: Requesting zone boundaries from server")
        
        -- Request region data for sprinter system
        sendClientCommand(player, "SIMBA_TSY", "RequestRegionData", {})
        print("SIMBA_TSY Client: Requesting region data from server")
    end
end

Events.OnCreatePlayer.Add(SIMBA_TSY_OnPlayerSpawn)

-- Clean up tracking on zombie death
local function SIMBA_TSY_OnZombieDead(zombie)
    if zombie then
        local zombieID = zombie:getOnlineID()
        if zombieID and SIMBA_TSY_ProcessedZombies[zombieID] then
            SIMBA_TSY_ProcessedZombies[zombieID] = nil
        end
    end
end

Events.OnZombieDead.Add(SIMBA_TSY_OnZombieDead)
