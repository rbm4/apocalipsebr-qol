--        __     __                   
-- _|_   (_ ||\/|__) /\ _ _ _ _|   _  
--  |    __)||  |__)/--|_| (_(_||_|/_ 
--                     |              
if isServer() then
    return
end

local SIMBA_TSY_TickCounter = 0
local SIMBA_TSY_RequestedZombies = {} -- Track which zombies we've already requested

-- Handle server commands
local function SIMBA_TSY_OnServerCommand(module, command, args)
    if module ~= "SIMBA_TSY" then return end
    
    if command == "ApplySprinters" then
        local player = getPlayer()
        if not player then return end
        
        local cell = player:getCell()
        if not cell then return end
        
        local zombieList = cell:getZombieList()
        if not zombieList then return end
        
        local applied = 0
        local notApplied = 0
        
        -- Apply sprinter properties to each zombie in the list
        if args.sprinters then
            for _, sprinterData in ipairs(args.sprinters) do
                local zombieID = sprinterData.id
                local walkType = sprinterData.walkType
                local found = false
                
                -- Find the zombie
                for i = 0, zombieList:size() - 1 do
                    local zombie = zombieList:get(i)
                    if zombie and not zombie:isDead() and zombie:getOnlineID() == zombieID then
                        found = true
                        
                        -- Store in modData so we can reapply if game resets it
                        local modData = zombie:getModData()
                        modData.SIMBA_TSY_IsSprinter = true
                        modData.SIMBA_TSY_WalkType = walkType
                        
                        -- Apply sprinter properties
                        zombie:setWalkType(walkType)
                        
                        applied = applied + 1
                        print("SIMBA_TSY Client: Applied sprinter " .. walkType .. " to zombie " .. zombieID)
                        break
                    end
                end
                
                -- If zombie not found on client, don't mark as requested so we retry later
                if not found then
                    SIMBA_TSY_RequestedZombies[zombieID] = nil
                    notApplied = notApplied + 1
                end
            end
        end
        
        -- Handle zombies not found on server - retry them later
        if args.notFound then
            for _, zombieID in ipairs(args.notFound) do
                SIMBA_TSY_RequestedZombies[zombieID] = nil
            end
            if #args.notFound > 0 then
                print("SIMBA_TSY Client: " .. #args.notFound .. " zombies not found on server, will retry")
            end
        end
        
        -- Handle zombies confirmed as non-sprinters - keep marked so we don't ask again
        if args.processed then
            -- These stay in SIMBA_TSY_RequestedZombies so we don't repeatedly ask about them
        end
        
        if applied > 0 then
            print("SIMBA_TSY Client: Applied sprinter properties to " .. applied .. " zombies" .. (notApplied > 0 and (" (" .. notApplied .. " not yet loaded)") or ""))
        end
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
    -- Check if walkType OR speedType needs correction
    local currentWalkType = zombie:getVariableString("zombiewalktype")
    if currentWalkType ~= modData.SIMBA_TSY_WalkType then
        -- Reapply when game resets
        zombie:setWalkType(modData.SIMBA_TSY_WalkType)
        print("SIMBA_TSY Client: Corrected sprinter for zombie " .. zombie:getOnlineID())
    end
    
end
-- Client requests zombie sync from server
local function SIMBA_TSY_RequestZombieSync()
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

    -- Send list of zombie IDs to server (only if not already requested)
    local zombieIDs = {}
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        SIMBA_TSY_ValidateSprinters(zombie)
        if zombie and not zombie:isDead() then
            local zombieID = zombie:getOnlineID()
            if not SIMBA_TSY_RequestedZombies[zombieID] then
                table.insert(zombieIDs, zombieID)
                SIMBA_TSY_RequestedZombies[zombieID] = true
            end
        end
    end

    if #zombieIDs > 0 then
        sendClientCommand(player, "SIMBA_TSY", "RequestZombieSync", {
            zombieIDs = zombieIDs
        })
        print("SIMBA_TSY Client: Requested sync for " .. #zombieIDs .. " zombies")
    end
end

local function SIMBA_TSY_OnTick()
    SIMBA_TSY_TickCounter = SIMBA_TSY_TickCounter + 1

    -- Request sync from server every 120 ticks (2 seconds at 60 FPS)
    if SIMBA_TSY_TickCounter >= 120 then
        SIMBA_TSY_RequestZombieSync()
        SIMBA_TSY_TickCounter = 0
    end
end

Events.OnTick.Add(SIMBA_TSY_OnTick)


-- Clean up tracking on zombie death
local function SIMBA_TSY_OnZombieDead(zombie)
    if zombie then
        local zombieID = zombie:getOnlineID()
        if zombieID and SIMBA_TSY_RequestedZombies[zombieID] then
            SIMBA_TSY_RequestedZombies[zombieID] = nil
        end
        
        -- Clean up modData
        local modData = zombie:getModData()
        modData.SIMBA_TSY_IsSprinter = nil
        modData.SIMBA_TSY_WalkType = nil
    end
end

Events.OnZombieDead.Add(SIMBA_TSY_OnZombieDead)
