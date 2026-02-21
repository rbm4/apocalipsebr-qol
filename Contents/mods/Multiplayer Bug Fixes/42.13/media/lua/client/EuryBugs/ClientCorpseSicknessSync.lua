local MOD = "CorpseSicknessSync"

local DEBUG = getCore():getDebug()

local function log(msg)
    if DEBUG then
        DebugLog.log(DebugType.General, "[" .. MOD .. "][C] " .. tostring(msg))
    end
end

local CMD = "SyncCorpseSicknessRate"

local function onServerCommand(module, command, args)
    if module ~= MOD or command ~= CMD then return end
    if not args then return end

    local player = getSpecificPlayer(0)
    if not player then return end

    local rate = tonumber(args.r) or 0
    if player.setCorpseSicknessRate then
        player:setCorpseSicknessRate(rate)
    end

    -- Uncomment for debugging:
    log("Applied rate " .. tostring(rate) .. " level " .. tostring(args.l) .. " on client")
end

Events.OnServerCommand.Add(onServerCommand)