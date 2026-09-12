local Debug = {}
local emitted = {}
local enabled = false

local function emit(level, message)
    print("[A10YL]" .. (level and ("[" .. level .. "]") or "") .. " " .. tostring(message))
end

function Debug.log(message)
    if enabled then emit(nil, message) end
end

function Debug.setEnabled(value)
    enabled = value == true
end

function Debug.isEnabled()
    return enabled
end

function Debug.warn(message)
    emit("WARN", message)
end

function Debug.error(message)
    emit("ERROR", message)
end

function Debug.once(key, level, message)
    key = tostring(key or message)
    if emitted[key] then
        return
    end
    emitted[key] = true
    emit(level, message)
end

return Debug
