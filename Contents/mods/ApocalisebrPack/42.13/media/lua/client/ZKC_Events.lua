-- Zombie Kill Counter & Player Tracker - Event Handlers
-- Hooks into game events to track zombie kills and player position

require "ZombieKillCounter/ZKC_Main"

ZKC_Events = ZKC_Events or {}

-- Tick counter for throttled updates
local tickCounter = 0

-- Called when a zombie dies
-- @param zombie IsoZombie that was killed
local function onZombieDead(zombie)
    if not zombie or not ZKC_Config.enabled then
        return
    end
    
    -- Get the local player
    local player = getPlayer()
    if not player then
        return
    end
    
    -- Check if this player killed the zombie
    -- Method 1: Check attacker reference
    local attacker = zombie:getAttackedBy()
    if attacker and attacker == player then
        ZKC_Main.recordKill(player)
        return
    end
    
    -- Method 2: Check if zombie is in player's kill range and recently damaged by player
    -- This handles edge cases where getAttackedBy() might be nil
    local distanceToPlayer = IsoUtils.DistanceTo(zombie:getX(), zombie:getY(), player:getX(), player:getY())
    
    -- If zombie is very close and player is wielding a weapon, attribute to player
    if distanceToPlayer <= 2.5 then  -- Melee range
        local weapon = player:getPrimaryHandItem()
        if weapon and (weapon:isWeapon() or weapon:getCategory() == "Weapon") then
            ZKC_Main.recordKill(player)
            return
        end
    elseif distanceToPlayer <= 30 then  -- Ranged weapon range
        local weapon = player:getPrimaryHandItem()
        if weapon and weapon:isRangedWeapon() then
            ZKC_Main.recordKill(player)
            return
        end
    end
end

-- Called every tick (throttled)
local function onTick()
    if not ZKC_Config.enabled then
        return
    end
    
    tickCounter = tickCounter + 1
    
    -- Only check for periodic updates at configured interval
    if tickCounter >= ZKC_Config.Performance.updateCheckInterval then
        tickCounter = 0
        ZKC_Main.checkPeriodicUpdate()
    end
end

-- Called when game starts
local function onGameStart()
    ZKC_Main.initialize()
    
    -- Send initial update
    local player = getPlayer()
    if player then
        ZKC_Main.sendUpdate(player, "game_start")
    end
end

-- Called when player disconnects (send final update)
local function onDisconnect()
    if not ZKC_Config.enabled then
        return
    end
    
    local player = getPlayer()
    if player then
        print("[ZKC] Sending final update before disconnect...")
        ZKC_Main.sendUpdate(player, "disconnect")
    end
end

-- Called when player dies (immediate notification)
local function onPlayerDeath(player)
    if not ZKC_Config.enabled then
        return
    end
    
    -- Check if this is the local player
    if player == getPlayer() then
        print("[ZKC] Player died! Sending death update...")
        ZKC_Main.sendUpdate(player, "death")
    end
end

-- Register event handlers
Events.OnZombieDead.Add(onZombieDead)
Events.OnTick.Add(onTick)
Events.OnGameStart.Add(onGameStart)
Events.OnDisconnect.Add(onDisconnect)
Events.OnPlayerDeath.Add(onPlayerDeath)

print("[ZKC] Event handlers registered")

return ZKC_Events
