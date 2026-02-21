EURY_TA = EURY_TA or {}
EURY_TA.nextId = EURY_TA.nextId or 0

local DEBUG = getCore():getDebug()

local function enabled()
    return DEBUG
end

local function ctx()
    if isServer and isServer() then return "SERVER" end
    if isClient and isClient() then return "CLIENT" end
    return "LOCAL"
end

function EURY_TA.log(msg)
    if enabled() then
        DebugLog.log(DebugType.General, "[TA][" .. ctx() .. "] " .. tostring(msg))
    end
end

function EURY_TA.ensureTag(action)
    if not action then return action end

    if not action.EURY_id then
        EURY_TA.nextId = EURY_TA.nextId + 1
        action.EURY_id = EURY_TA.nextId
    end

    if not action.EURY_tag then
        local name = action.Type or action.classname or "TimedAction"
        action.EURY_tag = tostring(name)
    end

    return action
end

function EURY_TA.buildArgString(value, seen)
    seen = seen or {}

    local t = type(value)

    if t == "nil" then
        return "nil"
    elseif t == "string" then
        return '"' .. value .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "userdata" then
        return "<userdata:" .. tostring(value) .. ">"
    elseif t ~= "table" then
        return "<" .. t .. ":" .. tostring(value) .. ">"
    end

    if seen[value] then
        return "<cycle>"
    end
    seen[value] = true

    local parts = {}
    for k, v in pairs(value) do
        local key = EURY_TA.buildArgString(k, seen)
        local val = EURY_TA.buildArgString(v, seen)
        parts[#parts + 1] = key .. "=" .. val
    end

    seen[value] = nil

    return "{" .. table.concat(parts, ", ") .. "}"
end
