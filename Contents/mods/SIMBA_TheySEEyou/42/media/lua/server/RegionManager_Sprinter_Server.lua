-- 
-- Region-Based Sprinter System:
-- - Zombies are converted to sprinters based on region configuration
-- - Each region can specify "sprinterChance" (1-100) in customProperties
-- - If no region or no sprinterChance property, uses baseline (default: 0)
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

-- At the top of HYPOTHETIC_TSY_Server.lua
local function SIMBA_TSY_GetGlobalModData()
    local modData = ModData.getOrCreate("SIMBA_TSY_ZombieStates")
    if not modData.zombies then
        modData.zombies = {}
    end
    return modData
end

-- Create a persistent identifier for zombies
local function SIMBA_TSY_GetZombiePersistentID(zombie)
    -- Combine attributes that are stable across respawns
    local outfit = zombie:getPersistentOutfitID()
    local female = zombie:isFemale() and 1 or 0

    return string.format("%d_%d", outfit, female)
end

-- Add near the top with other constants
local SIMBA_TSY_BaselineSprinterChance = 0 -- 1-100 baseline chance when region has no sprinter config
local SIMBA_TSY_EnforcementInterval = 60 -- Ticks between enforcement checks
local SIMBA_TSY_EnforcementCounter = 0

-- Sprinter walk types available in the game
local SIMBA_TSY_SprinterWalkTypes = {"sprint1", "sprint2", "sprint3", "sprint4", "sprint5"}

local SIMBA_TSY_SamblerWalkTypes = {"slow1", "slow2", "slow3"}

-- NOTE: Zombie states are now stored in global ModData (persists across unload/reload)
-- and instance ModData (for quick access on loaded zombies)

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
        local globalData = SIMBA_TSY_GetGlobalModData()

        for _, proposal in ipairs(args.zombies) do
            local zombieID = proposal.zombieID
            local persistentID = proposal.persistentID
            local isSprinter = proposal.isSprinter
            local isShambler = proposal.isShambler
            local walkType = proposal.walkType

            -- Check if we already have a decision for this persistent ID in global storage
            if globalData.zombies[persistentID] then
                -- Already decided - use stored state from global ModData
                rejected = rejected + 1
                local stored = globalData.zombies[persistentID]

                sendServerCommand(player, "SIMBA_TSY", "ConfirmZombie", {
                    zombieID = zombieID,
                    isSprinter = stored.isSprinter,
                    isShambler = stored.isShambler,
                    walkType = stored.walkType
                })
            else
                -- New decision - store in global ModData (persists across unload/reload)
                accepted = accepted + 1

                globalData.zombies[persistentID] = {
                    isSprinter = isSprinter,
                    walkType = walkType,
                    x = proposal.x,
                    y = proposal.y
                }

                sendServerCommand(player, "SIMBA_TSY", "ConfirmZombie", {
                    zombieID = zombieID,
                    isSprinter = isSprinter,
                    isShambler = isShambler,
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
    if zombie then
        -- Clean up global ModData entry
        local persistentID = SIMBA_TSY_GetZombiePersistentID(zombie)
        local globalData = SIMBA_TSY_GetGlobalModData()
        if globalData.zombies[persistentID] then
            globalData.zombies[persistentID] = nil
        end
    end
end

Events.OnZombieDead.Add(SIMBA_TSY_OnZombieDead)
