if isServer() then
    return
end

require "RegionManager_Config"
require "RegionManager_ClientTick"

---@type table[]
local SIMBA_TSY_RegionBounds = {} -- Store region boundaries from server

---@type number
local SIMBA_TSY_BaselineSprinterChance = 0 -- Default when not in any region

---@type string[]
local SIMBA_TSY_SprinterWalkTypes = {"sprint1", "sprint2", "sprint3", "sprint4", "sprint5"}

local SIMBA_TSY_SamblerWalkTypes = {"slow1", "slow2", "slow3"}
local sandboxOptions = getSandboxOptions()

-- Create a persistent identifier for zombies (matches server logic)
local function SIMBA_TSY_GetZombiePersistentID(zombie)
    -- Combine attributes that are stable across respawns
    local outfit = zombie:getPersistentOutfitID()
    local female = zombie:isFemale() and 1 or 0

    return string.format("%d_%d", outfit, female)
end

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
local function SIMBA_TSY_GetSprinterChance(region)
    -- Check which region contains this position
    if region.sprinterChance and type(region.sprinterChance) == "number" then
        local chance = region.sprinterChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end

    -- No region found or region has no sprinter config
    return SIMBA_TSY_BaselineSprinterChance
end

-- Get shambler chance for current position based on known regions
---@param x number World X coordinate
---@param y number World Y coordinate
---@return number chance 0-100 sprinter percentage
local function SIMBA_TSY_GetHawkVisionChance(x, y)
    -- Check which region contains this position
    for _, region in ipairs(RegionManager.Client.zoneData) do
        local bounds = region.bounds
        if x >= bounds.minX and x <= bounds.maxX and y >= bounds.minY and y <= bounds.maxY then
            -- Check if region has sprinter configuration
            if region.visionChance and type(region.shamblerChance) == "number" then
                local chance = region.shamblerChance
                if chance < 1 then
                    chance = 0
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

-- Get shambler chance for current position based on known regions
---@param x number World X coordinate
---@param y number World Y coordinate
---@return number chance 0-100 sprinter percentage
local function SIMBA_TSY_GetShamblerChance(region)
    -- Check if region has shambler configuration
    if region.shamblerChance and type(region.shamblerChance) == "number" then
        local chance = region.shamblerChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end

    -- No region found or region has no sprinter config
    return SIMBA_TSY_BaselineSprinterChance
end

-- Get hawk vision chance for current position based on known regions
---@param region table Region data
---@return number chance 0-100 hawk vision percentage
local function SIMBA_TSY_GetHawkVisionChanceFromRegion(region)
    if region.hawkVisionChance and type(region.hawkVisionChance) == "number" then
        local chance = region.hawkVisionChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end
    return 0
end

-- Get bad vision chance for current position based on known regions
---@param region table Region data
---@return number chance 0-100 bad vision percentage
local function SIMBA_TSY_GetBadVisionChance(region)
    if region.badVisionChance and type(region.badVisionChance) == "number" then
        local chance = region.badVisionChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end
    return 0
end

-- Get good hearing chance for current position based on known regions
---@param region table Region data
---@return number chance 0-100 good hearing percentage
local function SIMBA_TSY_GetGoodHearingChance(region)
    if region.goodHearingChance and type(region.goodHearingChance) == "number" then
        local chance = region.goodHearingChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end
    return 0
end

-- Get bad hearing chance for current position based on known regions
---@param region table Region data
---@return number chance 0-100 bad hearing percentage
local function SIMBA_TSY_GetBadHearingChance(region)
    if region.badHearingChance and type(region.badHearingChance) == "number" then
        local chance = region.badHearingChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end
    return 0
end

-- Get zombie armor factor for current position based on known regions
---@param region table Region data
---@return number factor 0-100 armor factor percentage
local function SIMBA_TSY_GetZombieArmorFactor(region)
    if region.zombieArmorFactor and type(region.zombieArmorFactor) == "number" then
        local factor = region.zombieArmorFactor
        if factor < 0 then
            factor = 0
        end
        if factor > 100 then
            factor = 100
        end
        return factor
    end
    return 0
end

-- Get resistant chance for current position based on known regions
---@param region table Region data
---@return number chance 0-100 resistant percentage
local function SIMBA_TSY_GetResistantChance(region)
    if region.resistantChance and type(region.resistantChance) == "number" then
        local chance = region.resistantChance
        if chance < 1 then
            chance = 0
        end
        if chance > 100 then
            chance = 100
        end
        return chance
    end
    return 0
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

                if walkType and isSprinter then
                    modData.SIMBA_TSY_IsSprinter = true
                    modData.SIMBA_TSY_WalkType = walkType
                    zombie:setWalkType(walkType)
                    print("SIMBA_TSY Client: Applied sprinter " .. walkType .. " to zombie " .. zombieID ..
                              " (server confirmed)")
                else
                    modData.SIMBA_TSY_IsSprinter = false
                    print("SIMBA_TSY Client: Zombie " .. zombieID .. " confirmed as non-sprinter")
                end

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

-------------------------- SPRINT MANIPULATION -------------------

local defaultSpeed = nil

local function getDefaultSpeed()
    if defaultSpeed == nil then
        defaultSpeed = sandboxOptions:getOptionByName("ZombieLore.Speed") and
                           sandboxOptions:getOptionByName("ZombieLore.Speed"):getValue() or 2
    end
    return defaultSpeed
end

local function makeSprint(zombie)
    if defaultSpeed == nil then
        defaultSpeed = getDefaultSpeed()
    end

    zombie:makeInactive(true)
    sandboxOptions:set("ZombieLore.Speed", 1)
    zombie:makeInactive(false)
    sandboxOptions:set("ZombieLore.Speed", defaultSpeed)

end

local function makeShamble(zombie)
    if defaultSpeed == nil then
        defaultSpeed = getDefaultSpeed()
    end

    zombie:makeInactive(true)
    sandboxOptions:set("ZombieLore.Speed", 3)
    zombie:makeInactive(false)
    sandboxOptions:set("ZombieLore.Speed", defaultSpeed)

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
            -- SIMBA_TSY_ValidateSprinters(zombie)

            if zombie and not zombie:isDead() then
                local zombieID = zombie:getOnlineID()
                local data = zombie:getModData()

                -- Only process if not already processed
                if not data.SIMBA_TSY_Processed then
                    data.SIMBA_TSY_Processed = true

                    -- Get zombie position
                    local zombieX = zombie:getX()
                    local zombieY = zombie:getY()

                    -- Determine chance to apply the properties based on region
                    local sprinterChance = 0
                    local shamblerChance = 0
                    local hawkVisionChance = 0
                    local badVisionChance = 0
                    local goodHearingChance = 0
                    local badHearingChance = 0
                    local zombieArmorFactor = 0
                    local resistantChance = 0


                    for _, region in ipairs(RegionManager.Client.zoneData) do
                        local bounds = region.bounds
                        if zombieX >= bounds.minX and zombieX <= bounds.maxX and zombieY >= bounds.minY and zombieY <=
                            bounds.maxY then
                            sprinterChance = SIMBA_TSY_GetSprinterChance(region)
                            shamblerChance = SIMBA_TSY_GetShamblerChance(region)
                            hawkVisionChance = SIMBA_TSY_GetHawkVisionChanceFromRegion(region)
                            badVisionChance = SIMBA_TSY_GetBadVisionChance(region)
                            goodHearingChance = SIMBA_TSY_GetGoodHearingChance(region)
                            badHearingChance = SIMBA_TSY_GetBadHearingChance(region)
                            zombieArmorFactor = SIMBA_TSY_GetZombieArmorFactor(region)
                            resistantChance = SIMBA_TSY_GetResistantChance(region)

                        end
                    end

                    local walkType = nil
                    local isSprinter = false
                    local isShambler = false
                    local roll = SIMBA_TSY_GetDeterministicRandom(zombieID, 100)

                    isShambler = roll < shamblerChance
                    local hawkVision = roll < hawkVisionChance
                    local badVision = roll < badVisionChance
                    local goodHearing = roll < goodHearingChance
                    local badHearing = roll < badHearingChance
                    local hasArmor = roll < zombieArmorFactor
                    local isResistant = roll < resistantChance
                    
                    if (sprinterChance > 0) or (shamblerChance > 0) or (hawkVisionChance > 0) or (badVisionChance > 0) or (goodHearingChance > 0) or (badHearingChance > 0) or (zombieArmorFactor > 0) or (resistantChance > 0) then
                        -- Roll for sprinter
                        isSprinter = roll < sprinterChance

                        if isSprinter then
                            makeSprint(zombie)
                        end
                        if isShambler then
                            makeShamble(zombie)
                        end
                        -- if hawkVision then
                        --     makeHawkEye(zombie)
                        -- end
                        -- if badVision then
                        --     makeBadVision(zombie)
                        -- end
                        -- if goodHearing then
                        --     makeGoodHearing(zombie)
                        -- end
                        -- if badHearing then
                        --     makeBadHearing(zombie)
                        -- end
                        -- if hasArmor then
                        --     makeArmored(zombie)
                        -- end
                        -- if isResistant then
                        --     makeResistant(zombie)
                        -- end

                        -- Generate persistent ID for global tracking
                        local persistentID = SIMBA_TSY_GetZombiePersistentID(zombie)

                        -- Propose to server
                        table.insert(proposals, {
                            zombieID = zombieID,
                            persistentID = persistentID,
                            isSprinter = isSprinter,
                            isShambler = isShambler,
                            hawkVision = hawkVision,
                            badVision = badVision,
                            goodHearing = goodHearing,
                            badHearing = badHearing,
                            hasArmor = hasArmor,
                            isResistant = isResistant,
                            x = math.floor(zombieX),
                            y = math.floor(zombieY)
                        })
                    end
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
    end
}
RegionManager.ClientTick.registerModule(sprinterModule)

