
TableSawServerCommand = TableSawServerCommand or {}



-- The sound's distanceMax is 5 tiles; allow a small delivery margin.
local SOUND_RADIUS_SQUARED = 10 * 10
local activeSounds = {}

local function isFiniteNumber(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function stopForListeners(entry, players)
    for i = 0, players:size() - 1 do
        local listener = players:get(i)
        if entry.listeners[listener] then
            sendServerCommand(listener, "TableSaw", "StopPlaySound", entry.args)
        end
    end
end

function TableSawServerCommand.onClientCommand(module, command, player, args)
    if module ~= "TableSaw" then return end
    if command ~= "PlaySound" and command ~= "StopPlaySound" then return end
    if not args or not isFiniteNumber(args.rx) or not isFiniteNumber(args.ry)
        or not isFiniteNumber(args.rz) then return end

    local key = args.rx .. "," .. args.ry .. "," .. args.rz
    local players = getOnlinePlayers()
    local now = getTimestamp()

    -- Expire bookkeeping after a missing stop (e.g. disconnect), without ticks.
    -- The sound clip itself is finite.
    for soundKey, entry in pairs(activeSounds) do
        if now - entry.startedAt > 120 then
            stopForListeners(entry, players)
            activeSounds[soundKey] = nil
        end
    end

    local previous = activeSounds[key]
    if previous then
        -- Stop reaches the original listeners even if they have walked away.
        stopForListeners(previous, players)
        activeSounds[key] = nil
    end
    if command == "StopPlaySound" then return end

    local soundArgs = { x = args.rx, y = args.ry, z = args.rz }
    local listeners = {}
    for i = 0, players:size() - 1 do
        local listener = players:get(i)
        local dx = listener:getX() - soundArgs.x
        local dy = listener:getY() - soundArgs.y
        local dz = listener:getZ() - soundArgs.z
        if dx * dx + dy * dy + dz * dz <= SOUND_RADIUS_SQUARED then
            sendServerCommand(listener, "TableSaw", "PlaySound", soundArgs)
            listeners[listener] = true
        end
    end
    if next(listeners) then
        activeSounds[key] = { args = soundArgs, listeners = listeners, startedAt = now }
    end
end

Events.OnClientCommand.Add(TableSawServerCommand.onClientCommand)
