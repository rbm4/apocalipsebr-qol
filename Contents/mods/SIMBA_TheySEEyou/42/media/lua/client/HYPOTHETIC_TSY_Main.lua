if isServer() then
    return
end

require "RegionManager_Config"
require "RegionManager_ClientTick"

---@type table<number, boolean>
local SIMBA_TSY_ProcessedZombies = {} -- Track which zombies we've already processed

---@type table[]
local SIMBA_TSY_RegionBounds = {} -- Store region boundaries from server

---@type number
local SIMBA_TSY_BaselineSprinterChance = 0 -- Default when not in any region

---@type string[]
local SIMBA_TSY_SprinterWalkTypes = {"Sprint1", "Sprint2", "Sprint3", "Sprint4", "Sprint5"}

-- Deterministic pseudo-random (matches server logic)
---@param zombieID number
---@param max number
---@return number
local function SIMBA_TSY_GetDeterministicRandom(zombieID, max)
    local hash = zombieID
    hash = ((hash * 1103515245) + 12345) % 2147483648
    return (hash % max)
end

---@param zombieID number
---@return string walkType
local function SIMBA_TSY_GetRandomSprinterWalkType(zombieID)
    local index = SIMBA_TSY_GetDeterministicRandom(zombieID, #SIMBA_TSY_SprinterWalkTypes)
    return SIMBA_TSY_SprinterWalkTypes[index + 1]
end

-- Get sprinter chance for current position based on known regions
---@param x number World X coordinate
---@param y number World Y coordinate
---@return number chance 0-100 sprinter percentage
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
---@param module string
---@param command string
---@param args table
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
---@param zombie IsoZombie
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

-- ============================================================================
-- Register with the central tick dispatcher
-- The sprinter module hooks into onTick to process zombies every interval.
-- ============================================================================
---@type TickModuleDef
local sprinterModule = {
    name = "SIMBA_TSY_Sprinters",

    -- Called every tick interval by the dispatcher
    onTick = function(player, currentZones)
        SIMBA_TSY_ProcessZombies()
    end,
}
RegionManager.ClientTick.registerModule(sprinterModule)

-- Request region data for sprinter system when player spawns
local function SIMBA_TSY_OnPlayerSpawn()
    local player = getPlayer()
    if player then
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
