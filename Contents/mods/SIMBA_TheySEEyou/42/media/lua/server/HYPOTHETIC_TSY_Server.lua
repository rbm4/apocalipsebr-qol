-- 
-- Region-Based Sprinter System:
-- - Zombies are converted to sprinters based on region configuration
-- - Each region can specify "sprinterChance" (1-100) in customProperties
-- - If no region or no sprinterChance property, uses baseline (default: 50)
-- - Conversion is deterministic based on zombie ID for client-server sync
-- 
-- Usage in RegionManager_Config.lua:
--   customProperties = {
--       sprinterChance = 80  -- 80% of zombies become sprinters in this zone
--   }
if not isServer() then
    return
end

require "RegionManager_Config"

local SIMBA_TSY_MODULE = "SIMBA_TSY"
local SIMBA_TSY_CMD_REQUEST = "ScreamRequest"
local SIMBA_TSY_CMD_BROADCAST = "Scream"

local SIMBA_TSY_MaxSlots = 62
local SIMBA_TSY_DefaultAlertRadius = 80
local SIMBA_TSY_DefaultAlertEnabled = true
local SIMBA_TSY_DefaultClusterRadius = 35
local SIMBA_TSY_DefaultClusterCDHours = 0.01
local SIMBA_TSY_DefaultMaxCluster = 1
local SIMBA_TSY_MaxClusterEvents = 200

local SIMBA_TSY_TickCounter = 0
local SIMBA_TSY_Delayed = {}

-- Add near the top with other constants
local SIMBA_TSY_ZombieScanInterval = 100 -- Ticks between zombie scans (about every 1.67 seconds at 60 FPS)
local SIMBA_TSY_BaselineSprinterChance = 0 -- 1-100 baseline chance when region has no sprinter config
local SIMBA_TSY_ScanRadius = 70 -- Radius around players to scan for zombies
local SIMBA_TSY_LastZombieScan = 0
local SIMBA_TSY_EnforcementInterval = 60 -- Ticks between enforcement checks
local SIMBA_TSY_EnforcementCounter = 0

-- Sprinter walk types available in the game
local SIMBA_TSY_SprinterWalkTypes = {"Sprint1", "Sprint2", "Sprint3", "Sprint4", "Sprint5"}

-- Get sprinter conversion chance for a specific position
local function SIMBA_TSY_GetSprinterChance(x, y)
    -- Try to access RegionManager zones
    if RegionManager and RegionManager.Server and RegionManager.Server.registeredZones then
        -- Check which zone contains this position
        for id, data in pairs(RegionManager.Server.registeredZones) do
            local bounds = data.bounds
            -- Fast AABB collision check
            if x >= bounds.minX and x <= bounds.maxX and y >= bounds.minY and y <= bounds.maxY then
                local props = data.properties
                -- Check if zone has sprinter configuration
                if props.sprinterChance and type(props.sprinterChance) == "number" then
                    -- Clamp to 1-100 range
                    local chance = props.sprinterChance
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
    end

    -- No region found or region has no sprinter config, use baseline
    return SIMBA_TSY_BaselineSprinterChance
end

-- Deterministic pseudo-random using zombie's online ID as seed
-- This ensures all clients make the same decision for the same zombie
local function SIMBA_TSY_GetDeterministicRandom(zombieID, max)
    local hash = zombieID
    hash = ((hash * 1103515245) + 12345) % 2147483648
    local result = (hash % max)
    print("SIMBA_TSY: GetDeterministicRandom(zombieID=" .. zombieID .. ", max=" .. max .. ") = " .. result)
    return result
end

local function SIMBA_TSY_GetRandomSprinterWalkType(zombieID)
    local index = SIMBA_TSY_GetDeterministicRandom(zombieID, #SIMBA_TSY_SprinterWalkTypes)
    return SIMBA_TSY_SprinterWalkTypes[index + 1]
end

-- Global authoritative zombie state storage
local SIMBA_TSY_ZombieStates = {} -- zombieID -> {isSprinter, walkType}

-- Build region data to send to clients
local function SIMBA_TSY_BuildRegionData()
    local regions = {}

    if RegionManager and RegionManager.Server and RegionManager.Server.registeredZones then
        print("SIMBA_TSY: Building region data from RegionManager.Server.registeredZones")
        local count = 0
        for id, data in pairs(RegionManager.Server.registeredZones) do
            count = count + 1
            local props = data.properties
            print("SIMBA_TSY: Region " .. id .. " has sprinterChance: " .. tostring(props.sprinterChance))
            if props.sprinterChance then
                table.insert(regions, {
                    id = id,
                    bounds = data.bounds,
                    sprinterChance = props.sprinterChance
                })
            end
        end
        print("SIMBA_TSY: Found " .. count .. " total zones, " .. #regions .. " have sprinterChance")
    else
        print("SIMBA_TSY: WARNING - RegionManager.Server.registeredZones not available!")
    end

    return regions
end

-- SERVER validates client proposals and stores authoritative state
local function SIMBA_TSY_OnClientCommand(module, command, player, args)
    -- Function to find a zombie by its online ID
    local function SIMBA_TSY_FindZombieByID(zombieID)
        local cell = getCell()
        if cell then
            local zombies = cell:getZombieList()
            if zombies then
                for j = 0, zombies:size() - 1 do
                    local zombie = zombies:get(j)
                    if zombie and not zombie:isDead() and zombie:getOnlineID() == zombieID then
                        return zombie
                    end
                end
            end
        end
        return nil -- Zombie not found
    end

    if module ~= "SIMBA_TSY" then
        return
    end

    -- Ensure state table exists (defensive programming for Lua resets)
    if not SIMBA_TSY_ZombieStates or type(SIMBA_TSY_ZombieStates) ~= "table" then
        print("SIMBA_TSY: WARNING - ZombieStates was nil, reinitializing")
        SIMBA_TSY_ZombieStates = {}
    end

    if command == "RequestRegionData" then
        -- Send region data to client
        local regions = SIMBA_TSY_BuildRegionData()
        sendServerCommand(player, "SIMBA_TSY", "RegionData", {
            regions = regions
        })
        print("SIMBA_TSY Server: Sent " .. #regions .. " region configurations to " .. player:getUsername())

    elseif command == "ProposeZombies" and player and args.zombies then
        -- Process client proposals
        local accepted = 0
        local rejected = 0

        for _, proposal in ipairs(args.zombies) do
            local zombieID = proposal.zombieID
            local isSprinter = proposal.isSprinter
            local walkType = proposal.walkType

            -- Check if we already have authoritative state for this zombie
            if SIMBA_TSY_ZombieStates[zombieID] then
                -- Already processed - return stored state
                rejected = rejected + 1
                local stored = SIMBA_TSY_ZombieStates[zombieID]
                sendServerCommand(player, "SIMBA_TSY", "ConfirmZombie", {
                    zombieID = zombieID,
                    isSprinter = stored.isSprinter,
                    walkType = stored.walkType
                })
            else
                -- New zombie - accept client's proposal
                accepted = accepted + 1

                -- Apply to server-side zombie if we can find it
                local zombie = SIMBA_TSY_FindZombieByID(zombieID)
                if zombie and isSprinter then
                    -- Verify methods exist before calling
                    if type(zombie.setWalkType) == "function" then
                        zombie:setWalkType(walkType)
                    else
                        print("SIMBA_TSY: WARNING - zombie:setWalkType is not available for zombie " .. zombieID)
                    end

                    if type(zombie.DoZombieSpeeds) == "function" then
                        zombie:DoZombieSpeeds(0.85)
                    else
                        print("SIMBA_TSY: WARNING - zombie:DoZombieSpeeds is not available for zombie " .. zombieID)
                    end
                end

                SIMBA_TSY_ZombieStates[zombieID] = {
                    isSprinter = isSprinter,
                    walkType = walkType,
                    zombie = zombie
                }

                -- Confirm to client
                sendServerCommand(player, "SIMBA_TSY", "ConfirmZombie", {
                    zombieID = zombieID,
                    isSprinter = isSprinter,
                    walkType = walkType
                })
            end
        end

        if accepted > 0 or rejected > 0 then
            print("SIMBA_TSY Server: Accepted " .. accepted .. " new zombies, returned " .. rejected ..
                      " existing states to " .. player:getUsername())
        end
    end
end

Events.OnClientCommand.Add(SIMBA_TSY_OnClientCommand)

-- Set basic sandbox settings
Events.OnInitWorld.Add(function()
    local sandbox = SandboxVars
    if sandbox and sandbox.ZombieLore then
        sandbox.ZombieLore.Speed = 2 -- Random (can't have shamblers for mod to work)
        sandbox.ZombieLore.SprinterPercentage = 0 -- We'll handle conversion manually
        sandbox.ZombieLore.ActiveOnly = 1 -- Both day and night

        print("SIMBA_TSY Server: Zombie settings initialized - Manual sprinter conversion enabled")
    end

    -- Note: ModData cleanup is handled by OnZombieDead event
    -- ModData is stored on zombie instances and is automatically cleaned up when zombies are removed
end)

-- Clean up state storage on zombie death to prevent memory leaks
local function SIMBA_TSY_OnZombieDead(zombie)
    if not SIMBA_TSY_ZombieStates or type(SIMBA_TSY_ZombieStates) ~= "table" then
        return
    end

    if zombie then
        local zombieID = zombie:getOnlineID()
        if zombieID and SIMBA_TSY_ZombieStates[zombieID] then
            SIMBA_TSY_ZombieStates[zombieID] = nil
        end
    end
end

Events.OnZombieDead.Add(SIMBA_TSY_OnZombieDead)

-- Server-side enforcement to maintain sprinter states against network sync
local function SIMBA_TSY_EnforceSprinterStates()
    -- Ensure state table exists
    if not SIMBA_TSY_ZombieStates or type(SIMBA_TSY_ZombieStates) ~= "table" then
        SIMBA_TSY_ZombieStates = {}
        return -- Skip this tick if state was reset
    end

    -- Ensure counter is a valid number
    if type(SIMBA_TSY_EnforcementCounter) ~= "number" then
        SIMBA_TSY_EnforcementCounter = 0
        print("SIMBA_TSY: WARNING - EnforcementCounter was not a number, resetting to 0")
    end
    if type(SIMBA_TSY_EnforcementInterval) ~= "number" then
        SIMBA_TSY_EnforcementInterval = 60
        print("SIMBA_TSY: WARNING - EnforcementInterval was not a number, resetting to 60")
    end

    SIMBA_TSY_EnforcementCounter = SIMBA_TSY_EnforcementCounter + 1
    if SIMBA_TSY_EnforcementCounter < SIMBA_TSY_EnforcementInterval then
        return
    end
    SIMBA_TSY_EnforcementCounter = 0

    local enforced = 0
    for zombieID, state in pairs(SIMBA_TSY_ZombieStates) do
        if state.isSprinter then
            local zombie = SIMBA_TSY_FindZombieByID(zombieID)
            if zombie then
                -- Check if zombie's state has been reset by multiplayer sync
                local currentWalkType = zombie:getVariableString("zombieWalkType")
                if currentWalkType ~= state.walkType then
                    -- Verify methods exist before calling
                    if type(zombie.setWalkType) == "function" and type(zombie.DoZombieSpeeds) == "function" then
                        zombie:setWalkType(state.walkType)
                        zombie:DoZombieSpeeds(0.85)
                        enforced = enforced + 1
                    end
                end
                -- Update our reference
                state.zombie = zombie
            else
                -- Zombie no longer exists, clean up
                SIMBA_TSY_ZombieStates[zombieID] = nil
            end
        end
    end

    if enforced > 0 then
        print("SIMBA_TSY: Enforced sprinter state on " .. enforced .. " zombies")
    end
end

-- Initialize enforcement system after server starts
local function SIMBA_TSY_InitEnforcement()
    print("SIMBA_TSY: Initializing sprinter enforcement system")
    Events.OnTick.Add(SIMBA_TSY_EnforceSprinterStates)
end

Events.OnServerStarted.Add(SIMBA_TSY_InitEnforcement)

-- Add this function to intercept network packets
local function SIMBA_TSY_OnSendCommand(module, command, player, args)
    if not SIMBA_TSY_ZombieStates or type(SIMBA_TSY_ZombieStates) ~= "table" then
        return
    end

    if module == "zombie" and command == "ZombiePacket" and args and args.id then
        local zombieID = args.id
        local state = SIMBA_TSY_ZombieStates[zombieID]
        if state and state.isSprinter then
            -- Override packet data to maintain sprinter state
            args.walkType = state.walkType
            args.speedMod = 850 -- 0.85 * 1000 (network format)
        end
    end
end

Events.OnSendCommand.Add(SIMBA_TSY_OnSendCommand)
