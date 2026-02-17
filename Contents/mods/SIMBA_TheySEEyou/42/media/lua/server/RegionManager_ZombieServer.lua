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
require "RegionManager_ZombieShared"

-- Global ModData storage for zombie states
local function SIMBA_TSY_GetGlobalModData()
    local modData = ModData.getOrCreate("SIMBA_TSY_ZombieStates")
    if not modData.zombies then
        modData.zombies = {}
    end
    return modData
end

-- Clear all zombie states from ModData
local function SIMBA_TSY_ClearAllZombieStates()
    local globalData = SIMBA_TSY_GetGlobalModData()
    local count = 0
    if globalData.zombies then
        for k, v in pairs(globalData.zombies) do
            count = count + 1
        end
        globalData.zombies = {}
    end
    print("SIMBA_TSY Server: Cleared " .. count .. " zombie states from ModData")
    return count
end
-- Add near the top with other constants
local SIMBA_TSY_BaselineSprinterChance = 0 -- 1-100 baseline chance when region has no sprinter config

-- Sprinter walk types available in the game
local SIMBA_TSY_SprinterWalkTypes = {"sprint1", "sprint2", "sprint3", "sprint4", "sprint5"}

local SIMBA_TSY_SamblerWalkTypes = {"slow1", "slow2", "slow3"}

-- SERVER-SIDE: Make all decisions when zombie is created
-- Properties are no longer applied here - they're sent to client for application
local function RegionManagerZombie_OnZombieCreate(zombie)
    if not zombie then
        return
    end

    local persistentID = RegionManager.Shared.GetZombiePersistentID(zombie)
    local globalData = SIMBA_TSY_GetGlobalModData()

    -- Check if we already have a decision for this zombie
    if globalData.zombies[persistentID] then
        -- Already decided (zombie was spawned before), reuse existing decisions
        -- Properties will be applied client-side when requested
        return globalData.zombies[persistentID]
    end

    -- New zombie - make all decisions based on current region
    local zombieX = zombie:getX()
    local zombieY = zombie:getY()
    local zombieID = zombie:getOnlineID()

    -- Find which region(s) this zombie is in
    local currentRegions = {}
    local hasRegions = false
    if RegionManager and RegionManager.Server and RegionManager.Server.registeredZones then
        for zoneId, region in pairs(RegionManager.Server.registeredZones) do
            local bounds = region.bounds
            if zombieX >= bounds.minX and zombieX <= bounds.maxX and zombieY >= bounds.minY and zombieY <= bounds.maxY then
                currentRegions[zoneId] = region
                hasRegions = true
            end
        end
    end
    if hasRegions == false then
        return
    end

    local tempSettings = {}
    -- Calculate maximum chances from all zones the zombie is in
    local sprinterChance = 0
    local shamblerChance = 0
    local hawkVisionChance = 0
    local badVisionChance = 0
    local normalVisionChance = 0
    local poorVisionChance = 0
    local randomVisionChance = 0
    local goodHearingChance = 0
    local badHearingChance = 0
    local pinpointHearingChance = 0
    local normalHearingChance = 0
    local poorHearingChance = 0
    local randomHearingChance = 0
    local zombieArmorFactor = 0
    local resistantChance = 0
    local toughnessChance = 0
    local normalToughnessChance = 0
    local fragileChance = 0
    local randomToughnessChance = 0
    local superhuman = 0
    local normalToughness = 0
    local weak = 0
    local randomToughness = 0
    local navigationChance = 0
    local memoryLongChance = 0
    local memoryNormalChance = 0
    local memoryShortChance = 0
    local memoryNoneChance = 0
    local memoryRandomChance = 0
    local armorEffectivenessMultiplier = 0
    local armorDefensePercentage = 0

    for zoneId, region in pairs(currentRegions) do
        sprinterChance = math.max(sprinterChance, RegionManager.Shared.GetSprinterChance(region))
        shamblerChance = math.max(shamblerChance, RegionManager.Shared.GetShamblerChance(region))
        hawkVisionChance = math.max(hawkVisionChance, RegionManager.Shared.GetHawkVisionChanceFromRegion(region))
        badVisionChance = math.max(badVisionChance, RegionManager.Shared.GetBadVisionChance(region))
        normalVisionChance = math.max(normalVisionChance, RegionManager.Shared.GetNormalVisionChance(region))
        poorVisionChance = math.max(poorVisionChance, RegionManager.Shared.GetPoorVisionChance(region))
        randomVisionChance = math.max(randomVisionChance, RegionManager.Shared.GetRandomVisionChance(region))
        goodHearingChance = math.max(goodHearingChance, RegionManager.Shared.GetGoodHearingChance(region))
        badHearingChance = math.max(badHearingChance, RegionManager.Shared.GetBadHearingChance(region))
        pinpointHearingChance = math.max(pinpointHearingChance, RegionManager.Shared.GetPinpointHearingChance(region))
        normalHearingChance = math.max(normalHearingChance, RegionManager.Shared.GetNormalHearingChance(region))
        poorHearingChance = math.max(poorHearingChance, RegionManager.Shared.GetPoorHearingChance(region))
        randomHearingChance = math.max(randomHearingChance, RegionManager.Shared.GetRandomHearingChance(region))
        zombieArmorFactor = math.max(zombieArmorFactor, RegionManager.Shared.GetZombieArmorFactor(region))
        resistantChance = math.max(resistantChance, RegionManager.Shared.GetResistantChance(region))
        toughnessChance = math.max(toughnessChance, RegionManager.Shared.GetToughnessChance(region))
        normalToughnessChance = math.max(normalToughnessChance, RegionManager.Shared.GetNormalToughnessChance(region))
        fragileChance = math.max(fragileChance, RegionManager.Shared.GetFragileChance(region))
        randomToughnessChance = math.max(randomToughnessChance, RegionManager.Shared.GetRandomToughnessChance(region))
        superhuman = math.max(superhuman, RegionManager.Shared.GetSuperhumanChance(region))
        normalToughness = math.max(normalToughness, RegionManager.Shared.GetNormalToughness(region))
        weak = math.max(weak, RegionManager.Shared.GetWeakChance(region))
        randomToughness = math.max(randomToughness, RegionManager.Shared.GetRandomToughness(region))
        navigationChance = math.max(navigationChance, RegionManager.Shared.GetNavigationChance(region))
        memoryLongChance = math.max(memoryLongChance, RegionManager.Shared.GetMemoryLongChance(region))
        memoryNormalChance = math.max(memoryNormalChance, RegionManager.Shared.GetMemoryNormalChance(region))
        memoryShortChance = math.max(memoryShortChance, RegionManager.Shared.GetMemoryShortChance(region))
        memoryNoneChance = math.max(memoryNoneChance, RegionManager.Shared.GetMemoryNoneChance(region))
        memoryRandomChance = math.max(memoryRandomChance, RegionManager.Shared.GetMemoryRandomChance(region))
        armorEffectivenessMultiplier = math.max(armorEffectivenessMultiplier,
            RegionManager.Shared.GetArmorEffectivenessMultiplier(region))
        armorDefensePercentage =
            math.max(armorDefensePercentage, RegionManager.Shared.GetArmorDefensePercentage(region))
    end

    -- Roll for all properties using deterministic random
    local roll = RegionManager.Shared.GetDeterministicRandom(zombie:getPersistentOutfitID(), 100)

    -- Debug: Show chances and roll
    print("SIMBA_TSY Server: Creating zombie " .. zombieID .. " at (" .. zombieX .. ", " .. zombieY .. ")")
    print("  Roll: " .. roll)
    print("  sprinterChance: " .. sprinterChance)
    print("  shamblerChance: " .. shamblerChance)

    local isSprinter = roll < sprinterChance
    local isShambler = roll < shamblerChance

    print("  Result - isSprinter: " .. tostring(isSprinter))
    print("  Result - isShambler: " .. tostring(isShambler))
    local hawkVision = roll < hawkVisionChance
    local badVision = roll < badVisionChance
    local normalVision = roll < normalVisionChance
    local poorVision = roll < poorVisionChance
    local randomVision = roll < randomVisionChance
    local goodHearing = roll < goodHearingChance
    local badHearing = roll < badHearingChance
    local pinpointHearing = roll < pinpointHearingChance
    local normalHearing = roll < normalHearingChance
    local poorHearing = roll < poorHearingChance
    local randomHearing = roll < randomHearingChance
    local hasArmor = roll < zombieArmorFactor
    local isResistant = roll < resistantChance
    local isTough = roll < toughnessChance
    local isNormalToughness = roll < normalToughnessChance
    local isFragile = roll < fragileChance
    local isRandomToughness = roll < randomToughnessChance
    local isSuperhuman = roll < superhuman
    local isNormalToughness2 = roll < normalToughness
    local isWeak = roll < weak
    local isRandomToughness2 = roll < randomToughness
    local hasNavigation = roll < navigationChance
    local hasMemoryLong = roll < memoryLongChance
    local hasMemoryNormal = roll < memoryNormalChance
    local hasMemoryShort = roll < memoryShortChance
    local hasMemoryNone = roll < memoryNoneChance
    local hasMemoryRandom = roll < memoryRandomChance

    -- Store all decisions in global ModData
    globalData.zombies[persistentID] = {
        isSprinter = isSprinter,
        isShambler = isShambler,
        hawkVision = hawkVision,
        badVision = badVision,
        normalVision = normalVision,
        poorVision = poorVision,
        randomVision = randomVision,
        goodHearing = goodHearing,
        badHearing = badHearing,
        pinpointHearing = pinpointHearing,
        normalHearing = normalHearing,
        poorHearing = poorHearing,
        randomHearing = randomHearing,
        hasArmor = hasArmor,
        isResistant = isResistant,
        isTough = isTough,
        isNormalToughness = isNormalToughness,
        isFragile = isFragile,
        isRandomToughness = isRandomToughness,
        isSuperhuman = isSuperhuman,
        isNormalToughness2 = isNormalToughness2,
        isWeak = isWeak,
        isRandomToughness2 = isRandomToughness2,
        hasNavigation = hasNavigation,
        hasMemoryLong = hasMemoryLong,
        hasMemoryNormal = hasMemoryNormal,
        hasMemoryShort = hasMemoryShort,
        hasMemoryNone = hasMemoryNone,
        hasMemoryRandom = hasMemoryRandom,
        armorEffectivenessMultiplier = armorEffectivenessMultiplier,
        armorDefensePercentage = armorDefensePercentage,
        x = math.floor(zombieX),
        y = math.floor(zombieY)
    }

    return globalData.zombies[persistentID]
end-- Store decisions only - client will apply properties when it receives them
-- Periodic cleanup of stale zombie entries (zombies that no longer exist)
local function SIMBA_TSY_PeriodicCleanup()
    local globalData = SIMBA_TSY_GetGlobalModData()
    local cell = getCell()
    if not cell then return end
    
    local activeZombies = {}
    local zombies = cell:getZombieList()
    if zombies then
        for i = 0, zombies:size() - 1 do
            local zombie = zombies:get(i)
            if zombie and not zombie:isDead() then
                local persistentID = RegionManager.Shared.GetZombiePersistentID(zombie)
                activeZombies[persistentID] = true
            end
        end
    end
    
    -- Remove entries for zombies that no longer exist
    local removed = 0
    for persistentID, data in pairs(globalData.zombies) do
        if not activeZombies[persistentID] then
            globalData.zombies[persistentID] = nil
            removed = removed + 1
        end
    end
    
    if removed > 0 then
        print("SIMBA_TSY Server: Periodic cleanup removed " .. removed .. " stale zombie entries")
    end
end

-- SERVER handles client requests for zombie information
local function SIMBA_TSY_OnClientCommand(module, command, player, args)
    if module ~= "SIMBA_TSY" then
        return
    end
    
    -- Admin command to clear all zombie states
    if command == "ClearZombieStates" then
        if player and player:getAccessLevel() ~= "None" then
            local count = SIMBA_TSY_ClearAllZombieStates()
            sendServerCommand(player, "SIMBA_TSY", "ClearConfirm", {count = count})
            print("SIMBA_TSY Server: Admin " .. player:getUsername() .. " cleared zombie ModData (" .. count .. " entries)")
        else
            print("SIMBA_TSY Server: Non-admin " .. player:getUsername() .. " attempted to clear zombie ModData")
        end
        return
    end
    
    local function FindZombieByID(zombieID)
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

    -- ========================================================================
    -- Handle tough zombie hit: validate, update counter, broadcast to clients
    -- ========================================================================
    if command == "ZombieHitTough" and player and args.zombieID then
        local zombieID = args.zombieID
        local persistentID = args.persistentID
        local globalData = SIMBA_TSY_GetGlobalModData()
        local stored = globalData.zombies[persistentID]
        if stored and stored.isTough then
            -- Initialize server-side toughness tracking if not present
            if not stored.toughnessHitCounter then
                stored.toughnessHitCounter = 0
            end
            if not stored.toughnessMaxHits then
                stored.toughnessMaxHits = 5
            end
            
            local isExhausted = false
            if stored.toughnessHitCounter < stored.toughnessMaxHits then
                stored.toughnessHitCounter = stored.toughnessHitCounter + 1
                print("SIMBA_TSY Server: Tough zombie " .. zombieID .. " hit (" ..
                      stored.toughnessHitCounter .. "/" .. stored.toughnessMaxHits .. ")")
                    else
                isExhausted = true
                print("SIMBA_TSY Server: Tough zombie " .. zombieID .. " exhausted all lives")
            end
            
            -- Broadcast to ALL connected players so everyone sees the effect
            -- Use sendServerCommand without a specific player to broadcast
            local connectedPlayers = getOnlinePlayers()
            if connectedPlayers then
                for i = 0, connectedPlayers:size() - 1 do
                    local p = connectedPlayers:get(i)
                    if p then
                        sendServerCommand(p, "SIMBA_TSY", "ToughZombieHit", {
                            zombieID = zombieID,
                            hitCounter = stored.toughnessHitCounter,
                            maxHits = stored.toughnessMaxHits,
                            isExhausted = isExhausted
                        })
                    end
                end
            end
        else
            --broadcast exausted in case store doesn't exist
            local connectedPlayers = getOnlinePlayers()
            if connectedPlayers then
                for i = 0, connectedPlayers:size() - 1 do
                    local p = connectedPlayers:get(i)
                    if p then
                        sendServerCommand(p, "SIMBA_TSY", "ToughZombieHit", {
                            zombieID = zombieID,
                            hitCounter = 5,
                            maxHits = 5,
                            isExhausted = true
                        })
                    end
                end
            end
        end
        return
    end

    if command == "RequestZombieInfo" and player and args.zombies then
        -- Client is requesting information about zombies
        -- All decisions should have been made in OnZombieCreate
        local globalData = SIMBA_TSY_GetGlobalModData()
        local found = 0
        local notFound = 0

        for _, request in ipairs(args.zombies) do
            local zombieID = request.zombieID
            local persistentID = request.persistentID

            -- Look up pre-determined state from global ModData
            local stored = globalData.zombies[persistentID]

            if stored then
                -- Found pre-determined state, send to client
                found = found + 1
                print("SIMBA_TSY Server: Sending zombie " .. zombieID .. " data:")
                print("  isSprinter: " .. tostring(stored.isSprinter))
                print("  isShambler: " .. tostring(stored.isShambler))
                print("  persistentID: " .. persistentID)

            else
                -- Zombie not found in ModData
                local zed = FindZombieByID(zombieID)
                stored = RegionManagerZombie_OnZombieCreate(zed)
                notFound = notFound + 1
                print("SIMBA_TSY Server WARNING: Zombie " .. persistentID .. " not found in ModData")
            end
            --  stored can be null if the zombie is outside any regions
            if stored then
                sendServerCommand(player, "SIMBA_TSY", "ConfirmZombie", {
                    zombieID = zombieID,
                    isSprinter = stored.isSprinter or false,
                    isShambler = stored.isShambler or false,
                    hawkVision = stored.hawkVision or false,
                    badVision = stored.badVision or false,
                    normalVision = stored.normalVision or false,
                    poorVision = stored.poorVision or false,
                    randomVision = stored.randomVision or false,
                    goodHearing = stored.goodHearing or false,
                    badHearing = stored.badHearing or false,
                    pinpointHearing = stored.pinpointHearing or false,
                    normalHearing = stored.normalHearing or false,
                    poorHearing = stored.poorHearing or false,
                    randomHearing = stored.randomHearing or false,
                    hasArmor = stored.hasArmor or false,
                    isResistant = stored.isResistant or false,
                    isTough = stored.isTough or false,
                    isNormalToughness = stored.isNormalToughness or false,
                    isFragile = stored.isFragile or false,
                    isRandomToughness = stored.isRandomToughness or false,
                    isSuperhuman = stored.isSuperhuman or false,
                    isNormalToughness2 = stored.isNormalToughness2 or false,
                    isWeak = stored.isWeak or false,
                    isRandomToughness2 = stored.isRandomToughness2 or false,
                    hasNavigation = stored.hasNavigation or false,
                    hasMemoryLong = stored.hasMemoryLong or false,
                    hasMemoryNormal = stored.hasMemoryNormal or false,
                    hasMemoryShort = stored.hasMemoryShort or false,
                    hasMemoryNone = stored.hasMemoryNone or false,
                    hasMemoryRandom = stored.hasMemoryRandom or false,
                    armorEffectivenessMultiplier = stored.armorEffectivenessMultiplier or 0,
                    armorDefensePercentage = stored.armorDefensePercentage or 0,
                    walkType = stored.walkType or "1"
                })
            end
        end

        if found > 0 or notFound > 0 then
            print("SIMBA_TSY Server: Sent info for " .. found .. " zombies, " .. notFound .. " not found to " ..
                      player:getUsername())
        end
    end
end

Events.OnClientCommand.Add(SIMBA_TSY_OnClientCommand)

-- Set basic sandbox settings
Events.OnInitWorld.Add(function()
    local sandbox = SandboxVars
    if sandbox and sandbox.ZombieLore then
        sandbox.ZombieLore.Speed = 2 -- Random
        sandbox.ZombieLore.SprinterPercentage = 0 -- We'll handle conversion manually
        sandbox.ZombieLore.ActiveOnly = 1 -- Both day and night

        print("SIMBA_TSY Server: Zombie settings initialized - Manual sprinter conversion enabled")
    end

    -- Clear zombie state cache on server startup/restart
    local count = SIMBA_TSY_ClearAllZombieStates()
    print("SIMBA_TSY Server: Server startup - ModData cleared")
    
    -- Schedule periodic cleanup every 30 minutes (1800 seconds)
    -- Events.EveryTenMinutes.Add(SIMBA_TSY_PeriodicCleanup)
    print("SIMBA_TSY Server: Periodic cleanup scheduled (every 10 minutes)")
end)

-- Clean up state storage on zombie death to prevent memory leaks
local function RegionManagerZombie_OnZombieDead(zombie)
    if zombie then
        -- Clean up global ModData entry
        local persistentID = RegionManager.Shared.GetZombiePersistentID(zombie)
        local globalData = SIMBA_TSY_GetGlobalModData()
        if globalData.zombies[persistentID] then
            globalData.zombies[persistentID] = nil
        end
    end
end

Events.OnZombieDead.Add(RegionManagerZombie_OnZombieDead)
--Events.OnZombieCreate.Add(RegionManagerZombie_OnZombieCreate)
