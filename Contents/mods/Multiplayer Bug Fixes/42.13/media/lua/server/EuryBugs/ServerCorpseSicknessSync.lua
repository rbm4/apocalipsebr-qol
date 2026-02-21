local MOD = "CorpseSicknessSync"

local DEBUG = getCore():getDebug()

local function log(msg)
    if DEBUG then
        DebugLog.log(DebugType.General, "[" .. MOD .. "][C] " .. tostring(msg))
    end
end

local CMD = "SyncCorpseSicknessRate"

local tickCount = 0
local lastRate   = {}

local function getCorpseSicknessRate(player)
    if not player then return 0 end
    local rate = player.getCorpseSicknessRate and player:getCorpseSicknessRate() or 0
    return rate
end

local function onPlayerTick(player)
    if not player then return end
    if player.isDead and player:isDead() then return end
    if player.isLocalPlayer and player:isLocalPlayer() then
        -- Dedicated server: false. Listen server: host has a local player too.
        -- We still want to sync to the owning connection only; sendServerCommand(player,...) handles that.
    end

    local id = player.getOnlineID and player:getOnlineID() or -1
    if id < 0 then return end


    local rate = getCorpseSicknessRate(player)
    local prev = lastRate[id]

    -- log("Corpse Sickness Rate for " .. tostring(player:getUsername()) .. " = " .. tostring(rate))

    if prev == nil then
        lastRate[id] = rate

        sendServerCommand(player, MOD, CMD, { r = rate })
        return
    end

    if rate ~= prev then
        lastRate[id] = rate

        sendServerCommand(player, MOD, CMD, { r = rate })

        -- log("Sent rate " .. tostring(rate) .. " to onlineID " .. tostring(id))
    end
end

local function onTick()
    if isServer() then
        local t = tickCount or 0
        if t < 60 then
            tickCount = t + 1
            return
        end
        tickCount = 0
        local players = getOnlinePlayers()
        if not players then return end
        for i=0,players:size()-1 do
            local p = players:get(i)
            onPlayerTick(p)
        end
    end
end

Events.OnTick.Add(onTick)