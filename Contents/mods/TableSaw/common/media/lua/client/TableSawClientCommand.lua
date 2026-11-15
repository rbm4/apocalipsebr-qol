
TableSawClientCommand = TableSawClientCommand or {}

TableSawClientCommand.sounds = {}


local function getSawKey(args)
    if args.id then
        return tostring(args.id)
    end
    return args.x .. "," .. args.y .. "," .. args.z
end

-- 
function TableSawClientCommand.onServerCommand(_module, _command, _args)
    if _module ~= "TableSaw" then return end
    local key = getSawKey(_args)
    if _command == "PlaySound" then
        local existing = TableSawClientCommand.sounds[key]
        if existing and existing.emitter and existing.sound then
            existing.emitter:stopOrTriggerSound(existing.sound)
            TableSawClientCommand.sounds[key] = nil
        end
        local square = getCell():getGridSquare(_args.x, _args.y, _args.z)
        if square then
            local emitter = getWorld():getFreeEmitter(_args.x, _args.y, _args.z)
            if emitter then
                local sound = emitter:playSoundImpl("TableSaw1", square)
                if sound then
                    emitter:setVolume(sound, TableSawVolume:getValue())
                    TableSawClientCommand.sounds[key] = { emitter = emitter, sound = sound }
                end
            end
        end
    elseif _command == "StopPlaySound" then
        local entry = TableSawClientCommand.sounds[key]
        if entry and entry.emitter and entry.sound then
            entry.emitter:stopOrTriggerSound(entry.sound)
        end
        TableSawClientCommand.sounds[key] = nil
    end
end

Events.OnServerCommand.Add(TableSawClientCommand.onServerCommand)