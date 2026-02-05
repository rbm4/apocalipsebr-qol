--        __     __                   
-- _|_   (_ ||\/|__) /\ _ _ _ _|   _  
--  |    __)||  |__)/--|_| (_(_||_|/_ 
--                     |              
if not isServer() then
    return
end

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

local function SIMBA_TSY_Delay(fn, delayTicks)
    if type(fn) ~= "function" then
        return
    end
    delayTicks = tonumber(delayTicks) or 1
    table.insert(SIMBA_TSY_Delayed, {
        t = SIMBA_TSY_TickCounter + delayTicks,
        fn = fn
    })
end

local function SIMBA_TSY_OnTick()
    SIMBA_TSY_TickCounter = SIMBA_TSY_TickCounter + 1

    if #SIMBA_TSY_Delayed == 0 then
        return
    end

    for i = #SIMBA_TSY_Delayed, 1, -1 do
        local job = SIMBA_TSY_Delayed[i]
        if job and job.t <= SIMBA_TSY_TickCounter then
            table.remove(SIMBA_TSY_Delayed, i)
            pcall(job.fn)
        end
    end
end

Events.OnTick.Add(SIMBA_TSY_OnTick)

local function SIMBA_TSY_GetSandbox()
    if SandboxVars and SandboxVars.SIMBAproduz_TSY then
        return SandboxVars.SIMBAproduz_TSY
    end
    return nil
end

local SIMBA_TSY_NightThreshold = 0.5

local function SIMBA_TSY_GetNightStrength()
    local cm = getClimateManager()
    if cm then
        return cm:getNightStrength()
    end
    return 0
end

local function SIMBA_TSY_TimeAllowed()
    local vars = SIMBA_TSY_GetSandbox()
    local mode = 0
    if vars and vars.TimeMode ~= nil then
        mode = vars.TimeMode
    end

    local nightStrength = SIMBA_TSY_GetNightStrength()

    if mode == 1 and nightStrength > SIMBA_TSY_NightThreshold then
        return false
    end
    if mode == 2 and nightStrength <= SIMBA_TSY_NightThreshold then
        return false
    end
    return true
end

local SIMBA_TSY_ClusterEvents = {}

local function SIMBA_TSY_CanClusterScream(x, y, timeNow, vars)
    local radius = SIMBA_TSY_DefaultClusterRadius
    local cdHours = SIMBA_TSY_DefaultClusterCDHours
    local maxCount = SIMBA_TSY_DefaultMaxCluster

    if vars then
        if vars.ClusterRadius and vars.ClusterRadius > 0 then
            radius = vars.ClusterRadius
        end
        if vars.ClusterCooldownHours and vars.ClusterCooldownHours > 0 then
            cdHours = vars.ClusterCooldownHours
        end
        if vars.MaxClusterScreams and vars.MaxClusterScreams > 0 then
            maxCount = vars.MaxClusterScreams
        end
    end

    for i = #SIMBA_TSY_ClusterEvents, 1, -1 do
        local e = SIMBA_TSY_ClusterEvents[i]
        if (timeNow - e.t) > cdHours then
            table.remove(SIMBA_TSY_ClusterEvents, i)
        end
    end

    local rr = radius * radius
    local count = 0

    for i = 1, #SIMBA_TSY_ClusterEvents do
        local e = SIMBA_TSY_ClusterEvents[i]
        local dx = x - e.x
        local dy = y - e.y
        if (dx * dx + dy * dy) <= rr then
            count = count + 1
            if count >= maxCount then
                return false
            end
        end
    end

    return true
end

local function SIMBA_TSY_RegisterClusterScream(x, y, timeNow)
    table.insert(SIMBA_TSY_ClusterEvents, {
        x = x,
        y = y,
        t = timeNow
    })
    if #SIMBA_TSY_ClusterEvents > SIMBA_TSY_MaxClusterEvents then
        table.remove(SIMBA_TSY_ClusterEvents, 1)
    end
end

local function SIMBA_TSY_Broadcast(args)
    local players = getOnlinePlayers()
    if not players then
        return
    end

    for i = 0, players:size() - 1 do
        local p = players:get(i)
        sendServerCommand(p, SIMBA_TSY_MODULE, SIMBA_TSY_CMD_BROADCAST, args)
    end
end

local function SIMBA_TSY_PullHorde(player, x, y, vars)
    local enabled = SIMBA_TSY_DefaultAlertEnabled
    local radius = SIMBA_TSY_DefaultAlertRadius

    if vars then
        if vars.AlertNearbyZombies ~= nil then
            enabled = vars.AlertNearbyZombies
        end
        if vars.AlertRadius and vars.AlertRadius > 0 then
            radius = vars.AlertRadius
        end
    end

    if not enabled or radius <= 0 then
        return
    end

    local function pulse()
        addSound(player, x, y, 0, radius, radius)
    end

    pulse()
    SIMBA_TSY_Delay(pulse, 20)
    SIMBA_TSY_Delay(pulse, 40)
    SIMBA_TSY_Delay(pulse, 60)
    SIMBA_TSY_Delay(pulse, 80)
end

local function SIMBA_TSY_OnClientCommand(module, command, player, args)
    if module ~= SIMBA_TSY_MODULE then
        return
    end
    if command ~= SIMBA_TSY_CMD_REQUEST then
        return
    end
    if not player or not args then
        return
    end

    if not SIMBA_TSY_TimeAllowed() then
        return
    end

    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local voiceIndex = tonumber(args.voiceIndex)
    local screamType = tostring(args.screamType or "far") -- "far" | "near" | "chase"

    if not x or not y then
        return
    end
    if not voiceIndex or voiceIndex < 1 or voiceIndex > SIMBA_TSY_MaxSlots then
        return
    end

    local vars = SIMBA_TSY_GetSandbox()
    local timeNow = getGameTime():getWorldAgeHours()

    if not SIMBA_TSY_CanClusterScream(x, y, timeNow, vars) then
        return
    end

    SIMBA_TSY_RegisterClusterScream(x, y, timeNow)

    SIMBA_TSY_PullHorde(player, x, y, vars)

    SIMBA_TSY_Broadcast({
        x = x,
        y = y,
        z = 0,
        voiceIndex = voiceIndex,
        screamType = screamType
    })
end

Events.OnClientCommand.Add(SIMBA_TSY_OnClientCommand)
-- Server-side mod to enforce sprinter settings
Events.OnInitWorld.Add(function()
    local sandbox = SandboxVars
    if sandbox then
        -- Or use a percentage:
        sandbox.ZombieLore.Speed = 4 -- Random
        sandbox.ZombieLore.SprinterPercentage = 100 -- 10% sprinters

        sandbox.ZombieLore.ActiveOnly = 2
        SIMBA_TSY_Delay(function()
            sandbox.ZombieLore.ActiveOnly = 1
        end, 100) -- 100 ticks delay
    end
end)

-- local function OnZombieDead(zombie)
--     if not isServer() then
--         return
--     end

--     -- Check if it's a sprinter
--     if zombie and zombie.getVariableString then
--         local walkType = zombie:getVariableString("zombiewalktype")
--         if walkType and (string.find(walkType, "WTSprint") or string.find(string.lower(walkType), "sprint")) then

--             local square = zombie:getSquare()
--             if square then
--                 -- Add items to the ground where zombie died

--                 -- Example: Random chance for good loot
--                 if ZombRand(100) < 10 then -- 10% chance
--                     local inv = zombie:getInventory()
--                     if inv then
--                         inv:AddItem("Base.Money")
--                     end
--                 end

--                 if ZombRand(100) < 5 then -- 5% chance
--                     local inv = zombie:getInventory()
--                     if inv then
--                         inv:AddItem("Base.Money")
--                     end
--                 end

--                 if ZombRand(100) < 1 then -- 1% chance
--                     local inv = zombie:getInventory()
--                     if inv then
--                         inv:AddItem("Base.Money")
--                     end
--                 end

--                 if ZombRand(1000) < 1 then -- 0.1% chance
--                     local inv = zombie:getInventory()
--                     if inv then
--                         inv:AddItem("Base.Money")
--                     end
--                 end

--             end
--         end
--     end
-- end

-- Events.OnZombieDead.Add(OnZombieDead)
