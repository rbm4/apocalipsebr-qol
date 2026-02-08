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
                    if chance < 1 then chance = 1 end
                    if chance > 100 then chance = 100 end
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

-- SERVER processes zombie marking and responds to client requests
local function SIMBA_TSY_OnClientCommand(module, command, player, args)
    if module ~= "SIMBA_TSY" then
        return
    end

    if command == "RequestZombieSync" and player and args.zombieIDs then
        local cell = player:getCell()
        if not cell then
            return
        end

        local synced = 0
        local marked = 0
        local checked = 0
        local sprintersToSync = {} -- Collect sprinters to send to client
        local notFoundIDs = {} -- Track zombies not found on server
        local processedIDs = {} -- Track zombies we've confirmed as non-sprinters

        for _, zombieID in ipairs(args.zombieIDs) do
            local found = false
            -- Find zombie by ID
            local zombies = cell:getZombieList()
            if zombies then
                for i = 0, zombies:size() - 1 do
                    local zombie = zombies:get(i)

                    if zombie and not zombie:isDead() and zombie:getOnlineID() == zombieID then
                        found = true
                        local modData = zombie:getModData()

                        -- Check if zombie needs processing
                        if not modData.SIMBA_TSY_Checked then
                            checked = checked + 1
                            modData.SIMBA_TSY_Checked = true

                            -- Get region-specific sprinter chance based on zombie position
                            local zombieX = zombie:getX()
                            local zombieY = zombie:getY()
                            local sprinterChance = SIMBA_TSY_GetSprinterChance(zombieX, zombieY)

                            -- Deterministic conversion decision
                            local roll = SIMBA_TSY_GetDeterministicRandom(zombieID, 100)
                            if roll < sprinterChance then
                                -- Store walk type in modData (server-side tracking only)
                                local walkType = SIMBA_TSY_GetRandomSprinterWalkType(zombieID)
                                modData.SIMBA_TSY_WalkType = walkType
                                modData.SIMBA_TSY_IsSprinter = true

                                -- Apply walk type on server (for AI/pathfinding)
                                zombie:setWalkType(walkType)
                                zombie:DoZombieSpeeds(0.85)
                                
                                marked = marked + 1

                                -- Add to sync list
                                table.insert(sprintersToSync, {
                                    id = zombieID,
                                    walkType = walkType
                                })
                            else
                                -- Not a sprinter, add to processed list so client knows
                                table.insert(processedIDs, zombieID)
                            end
                        elseif modData.SIMBA_TSY_IsSprinter then
                            -- Already marked checked for sprinter, just add to sync list
                            table.insert(sprintersToSync, {
                                id = zombieID,
                                walkType = modData.SIMBA_TSY_WalkType
                            })
                        else
                            -- Already checked, not a sprinter
                            table.insert(processedIDs, zombieID)
                        end
                        break
                    end
                end
            end
            
            if not found then
                table.insert(notFoundIDs, zombieID)
            end
        end

        -- Always send response so client knows we processed the request
        sendServerCommand(player, "SIMBA_TSY", "ApplySprinters", {
            sprinters = sprintersToSync,
            notFound = notFoundIDs,
            processed = processedIDs
        })
        
        if #sprintersToSync > 0 or #notFoundIDs > 0 then
            print("SIMBA_TSY Server: Synced " .. #sprintersToSync .. " sprinters, " .. #notFoundIDs .. " not found, " .. #processedIDs .. " processed")
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

-- Clean up modData on zombie death to prevent memory leaks
local function SIMBA_TSY_OnZombieDead(zombie)
    if zombie then
        local modData = zombie:getModData()
        if modData.SIMBA_TSY_Checked then
            modData.SIMBA_TSY_Checked = nil
            modData.SIMBA_TSY_WalkType = nil
            modData.SIMBA_TSY_IsSprinter = nil
        end
    end
end

Events.OnZombieDead.Add(SIMBA_TSY_OnZombieDead)
