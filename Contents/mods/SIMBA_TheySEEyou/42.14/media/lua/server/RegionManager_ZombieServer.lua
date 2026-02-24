-- ============================================================================
-- File: media/lua/server/RegionManager_ZombieServer.lua
-- Server-side core flow: handles zombie state management and client commands.
-- Heavy lifting (chance aggregation, rolling, payload building) lives in
-- RegionManager_ZombieServerHelper.lua.
-- ============================================================================
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

-- Helper handles all RegionManager.Shared / RegionManager_Config dependencies
local ZombieHelper = require "RegionManager_ZombieServerHelper"

-- ========================================================================
-- ModData storage
-- ========================================================================

local function SIMBA_TSY_GetGlobalModData()
    local modData = ModData.getOrCreate("SIMBA_TSY_ZombieStates")
    if not modData.zombies then
        modData.zombies = {}
    end
    return modData
end

local function SIMBA_TSY_ClearAllZombieStates()
    local globalData = SIMBA_TSY_GetGlobalModData()
    local count = 0
    if globalData.zombies then
        for _ in pairs(globalData.zombies) do
            count = count + 1
        end
        globalData.zombies = {}
    end
    -- print("SIMBA_TSY Server: Cleared " .. count .. " zombie states from ModData")
    return count
end

-- ========================================================================
-- Zombie decision making
-- ========================================================================

--- Resolve (or retrieve cached) zombie decisions for a given persistentID.
---@param persistentID string
---@param x number
---@param y number
---@return table|nil decisions
local function RegionManagerZombie_OnZombieCreate(persistentID, x, y)
    if not persistentID then
        return nil
    end

    local globalData = SIMBA_TSY_GetGlobalModData()

    -- Return cached decision when available
    if globalData.zombies[persistentID] then
        return globalData.zombies[persistentID]
    end

    -- Find overlapping regions
    local regions = ZombieHelper.FindRegionsAt(x, y)
    local hasRegions = false
    for _ in pairs(regions) do hasRegions = true; break end
    if not hasRegions then
        return nil
    end

    -- Aggregate max chances across overlapping zones then roll
    local chances = ZombieHelper.AggregateChances(regions)
    if not chances then
        return nil
    end

    local decisions = ZombieHelper.RollDecisions(chances, x, y)

    -- print("SIMBA_TSY Server: Creating zombie " .. persistentID ..
    --       " at (" .. x .. ", " .. y .. ")")

    -- Persist
    globalData.zombies[persistentID] = decisions
    return decisions
end

-- ========================================================================
-- Periodic cleanup of stale entries
-- ========================================================================

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
                local pid = ZombieHelper.GetPersistentID(zombie)
                if pid then
                    activeZombies[pid] = true
                end
            end
        end
    end

    local removed = 0
    for pid in pairs(globalData.zombies) do
        if not activeZombies[pid] then
            globalData.zombies[pid] = nil
            removed = removed + 1
        end
    end

    if removed > 0 then
        print("SIMBA_TSY Server: Periodic cleanup removed " .. removed .. " stale zombie entries")
    end
end

-- ========================================================================
-- Client command handler
-- ========================================================================

local function SIMBA_TSY_OnClientCommand(module, command, player, args)
    if module ~= "SIMBA_TSY" then
        return
    end

    -- ---- Admin: clear all zombie states ----
    if command == "ClearZombieStates" then
        if player and player:getAccessLevel() ~= "None" then
            local count = SIMBA_TSY_ClearAllZombieStates()
            sendServerCommand(player, "SIMBA_TSY", "ClearConfirm", {count = count})
            print("SIMBA_TSY Server: Admin " .. player:getUsername() ..
                  " cleared zombie ModData (" .. count .. " entries)")
        else
            print("SIMBA_TSY Server: Non-admin " .. player:getUsername() ..
                  " attempted to clear zombie ModData")
        end
        return
    end

    -- ---- Tough zombie hit ----
    if command == "ZombieHitTough" and player and args.zombieID then
        local zombieID     = args.zombieID
        local persistentID = args.persistentID
        local x, y         = args.x, args.y
        local globalData   = SIMBA_TSY_GetGlobalModData()
        local stored       = globalData.zombies[persistentID]

        if stored and stored.isTough then
            if not stored.toughnessHitCounter then stored.toughnessHitCounter = 0 end
            local maxHits = stored.maxHits or RegionManager.Shared.DEFAULT_MAX_HITS

            local isExhausted = false
            if stored.toughnessHitCounter < maxHits then
                stored.toughnessHitCounter = stored.toughnessHitCounter + 1
                print("SIMBA_TSY Server: Tough zombie " .. zombieID .. " hit (" ..
                      stored.toughnessHitCounter .. "/" .. maxHits .. ")")
            else
                isExhausted = true
                print("SIMBA_TSY Server: Tough zombie " .. zombieID .. " exhausted all lives")
            end

            ZombieHelper.BroadcastToAll("SIMBA_TSY", "ToughZombieHit", {
                zombieID    = zombieID,
                hitCounter  = stored.toughnessHitCounter,
                maxHits     = maxHits,
                x           = x,
                y           = y,
                isExhausted = isExhausted,
            })
        else
            -- No stored data – broadcast exhausted so client stops mitigating
            ZombieHelper.BroadcastToAll("SIMBA_TSY", "ToughZombieHit", {
                zombieID    = zombieID,
                hitCounter  = RegionManager.Shared.DEFAULT_MAX_HITS,
                maxHits     = RegionManager.Shared.DEFAULT_MAX_HITS,
                x           = x,
                y           = y,
                isExhausted = true,
            })
        end
        return
    end

    -- ---- Client requesting zombie info ----
    if command == "RequestZombieInfo" and player and args.zombies then
        local globalData = SIMBA_TSY_GetGlobalModData()
        local found, notFound = 0, 0

        for _, request in ipairs(args.zombies) do
            local zombieID     = request.zombieID
            local persistentID = request.persistentID

            local stored = globalData.zombies[persistentID]

            -- Position-mismatch check (discard if zombie teleported/recycled)
            if stored and request.x and request.y then
                local dx = math.abs((stored.x or 0) - request.x)
                local dy = math.abs((stored.y or 0) - request.y)
                if dx > 300 or dy > 300 then
                    -- print("SIMBA_TSY Server: Zombie " .. persistentID ..
                    --       " position mismatch, discarding stored data")
                    globalData.zombies[persistentID] = nil
                    stored = nil
                end
            end

            if stored then
                found = found + 1
            else
                -- First time or stale – resolve now
                stored = RegionManagerZombie_OnZombieCreate(persistentID, request.x, request.y)
                notFound = notFound + 1
            end

            if stored then
                local payload = ZombieHelper.BuildConfirmPayload(zombieID, stored)
                sendServerCommand(player, "SIMBA_TSY", "ConfirmZombie", payload)
            end
        end

        if found > 0 or notFound > 0 then
            -- print("SIMBA_TSY Server: Sent info for " .. found .. " zombies, " ..
            --       notFound .. " not found to " .. player:getUsername())
        end
    end
end

Events.OnClientCommand.Add(SIMBA_TSY_OnClientCommand)

-- ========================================================================
-- Initialisation
-- ========================================================================

Events.OnInitWorld.Add(function()
    local sandbox = SandboxVars
    if sandbox and sandbox.ZombieLore then
        sandbox.ZombieLore.Speed = 2               -- Random
        sandbox.ZombieLore.SprinterPercentage = 0   -- Manual conversion
        sandbox.ZombieLore.ActiveOnly = 1           -- Day + night
        print("SIMBA_TSY Server: Zombie settings initialized - Manual sprinter conversion enabled")
    end

    -- Completely remove persisted ModData so nothing survives a restart
    if ModData.exists("SIMBA_TSY_ZombieStates") then
        ModData.remove("SIMBA_TSY_ZombieStates")
    end
    -- Recreate a fresh, empty table
    local freshData = ModData.getOrCreate("SIMBA_TSY_ZombieStates")
    freshData.zombies = {}
    print("SIMBA_TSY Server: Server startup - ModData fully wiped and recreated")

    -- Events.EveryTenMinutes.Add(SIMBA_TSY_PeriodicCleanup)
    -- print("SIMBA_TSY Server: Periodic cleanup scheduled (every 10 minutes)")
end)

-- ========================================================================
-- Cleanup on zombie death
-- ========================================================================

local function RegionManagerZombie_OnZombieDead(zombie)
    if not zombie then return end
    local persistentID = ZombieHelper.GetPersistentID(zombie)
    if not persistentID then return end
    local globalData = SIMBA_TSY_GetGlobalModData()
    if globalData.zombies[persistentID] then
        globalData.zombies[persistentID] = nil
    end
end

Events.OnZombieDead.Add(RegionManagerZombie_OnZombieDead)
