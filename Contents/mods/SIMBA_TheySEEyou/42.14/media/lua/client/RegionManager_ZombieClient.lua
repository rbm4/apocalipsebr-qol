if isServer() then
    return
end

require "RegionManager_Config"
require "RegionManager_ClientTick"
require "RegionManager_ZombieShared"

local sandboxOptions = getSandboxOptions()

-- Handle server commands
---@param module string
---@param command string
---@param args table
local function SIMBA_TSY_OnServerCommand(module, command, args)
    if module ~= "SIMBA_TSY" then
        return
    end

    -- ========================================================================
    -- Handle tough zombie hit broadcast from server
    -- ========================================================================
    if command == "ToughZombieHit" then
        local zombieID = args.zombieID
        local hitCounter = args.hitCounter
        local maxHits = args.maxHits
        local isExhausted = args.isExhausted
        local zombieX = args.x
        local zombieY = args.y

        local player = getPlayer()
        if not player then
            return
        end
        local playerX = player:getX()
        local playerY = player:getY()
        
        -- Check distance between player and zombie
        local distance = math.sqrt((playerX - zombieX) ^ 2 + (playerY - zombieY) ^ 2)
        if distance > 200 then
            return
        end
        RegionManager.Shared.ApplyToughZombieHit(zombieID, hitCounter, maxHits, isExhausted)
        return
    end

    if command == "ConfirmZombie" then
        local player = getPlayer()
        if not player then
            return
        end

        
        -- Debug: Show received data from server
        print("SIMBA_TSY Client: Received zombie confirmation for ID: " .. tostring(args.zombieID))
        
        local zombieID = args.zombieID
        
        local cell = player:getCell()
        if not cell then
            return
        end

        local zombieList = cell:getZombieList()
        if not zombieList then
            return
        end
        -- Find zombie and apply all properties using shared function
        for i = 0, zombieList:size() - 1 do
            local zombie = zombieList:get(i)
            if zombie and not zombie:isDead() and zombie:getOnlineID() == zombieID then
                -- Apply all server-determined properties using the shared function
                RegionManager.Shared.ServerSideProperties(zombie, args, sandboxOptions)
                
                print("SIMBA_TSY Client: Applied properties to zombie " .. zombieID)
                if args.isSprinter then
                    print("  -> Converted to Sprinter")
                end
                if args.isShambler then
                    print("  -> Converted to Shambler")
                end
                if args.hawkVision then
                    print("  -> Hawk Vision applied")
                end
                if args.goodHearing or args.pinpointHearing then
                    print("  -> Enhanced Hearing applied")
                end
                if args.isTough then
                    print("  -> Tough applied")
                end
                if args.hasNavigation then
                    print("  -> Navigation enabled")
                end
                
                break
            end
        end
    end
end

Events.OnServerCommand.Add(SIMBA_TSY_OnServerCommand)

-------------------------- ZOMBIE SCANNING -------------------

-- Scan zombies and request their pre-determined properties from server
local function SIMBA_TSY_ProcessZombies(currentZones)
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

        -- Client no longer calculates chances or rolls
        -- Server makes all decisions in OnZombieCreate
        -- Client just scans and requests information
        
        for i = 0, zombies:size() - 1 do
            local zombie = zombies:get(i)

            if zombie and not zombie:isDead() then
                local zombieID = zombie:getOnlineID()
                local data = zombie:getModData()

                -- Only process if not already processed
                if not data.SIMBA_TSY_Processed then
                    data.SIMBA_TSY_Processed = true
                    
                    -- Generate persistent ID for server lookup
                    local persistentID = RegionManager.Shared.GetZombiePersistentID(zombie)

                    -- Request pre-determined properties from server
                    -- No rolling on client side - server decides everything in OnZombieCreate
                    table.insert(proposals, {
                        zombieID = zombieID,
                        persistentID = persistentID,
                        x = zombie:getX(),
                        y = zombie:getY()
                    })
                end
            end
        end

        -- Send requests to server for zombie information
        if #proposals > 0 then
            sendClientCommand(player, "SIMBA_TSY", "RequestZombieInfo", {
                zombies = proposals
            })
            print("SIMBA_TSY Client: Requested info for " .. #proposals .. " zombies from server")
        end
        return
    end
    sendClientCommand("RegionManager", "RequestAllBoundaries", {})
end

-- ============================================================================
-- Register with the central tick dispatcher
-- The sprinter module hooks into onTick to process zombies every interval.
-- ============================================================================
---@type TickModuleDef
local sprinterModule = {
    name = "SIMBA_TSY_Sprinters",

    -- Called every tick interval by the dispatcher
    onTick = function(player, currentZones)
        SIMBA_TSY_ProcessZombies(currentZones)
    end
}
RegionManager.ClientTick.registerModule(sprinterModule)

-- ============================================================================
-- Stuck Zombie Recovery Module
-- Periodically scans nearby zombies for stuck state (stateEventDelayTimer
-- deep in negatives with no target) and forces a state reset.
-- Runs on a slower cadence than the main sprinter tick to save performance.
-- ============================================================================

-- ---@type TickModuleDef
-- local unstickModule = {
--     name = "SIMBA_TSY_UnstickZombies",

--     onTick = function(player, currentZones)
--         RegionManager.Shared.ScanAndUnstickZombies()
--     end
-- }
-- RegionManager.ClientTick.registerModule(unstickModule)

-- ============================================================================
-- Zombie death handler
-- ============================================================================
local function onZombieDead(zombie)
    if not zombie then
        return
    end
    local player = getPlayer()
    if not player then
        return
    end
    
    local data = zombie:getModData()
    local attacker = zombie:getAttackedBy()

    local toughnessType = data.SIMBA_TSY_ToughnessType
    if toughnessType == "tough" then
        print("SIMBA_TSY Client: Tough zombie died - " .. zombie:getOnlineID())
        if attacker and attacker == player then
            ZKC_Main.recordKill(player,2)
            return
        end
    end
end
Events.OnZombieDead.Add(onZombieDead)