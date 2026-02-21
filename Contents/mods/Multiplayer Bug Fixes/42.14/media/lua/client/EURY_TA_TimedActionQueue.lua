require "EURY_TA_Tag"

local DEBUG = getCore():getDebug()

local function enabled()
    return DEBUG
end

-- Load module and prefer returned table; fallback to global if present.
local TAQ = require "TimedActions/ISTimedActionQueue"
TAQ = TAQ or ISTimedActionQueue

if not (TAQ and TAQ.add) then
    EURY_TA.log("hook skipped ISTimedActionQueue missing")
    return
end

local _oldAdd = TAQ.add

TAQ.add = function(action)
    action = EURY_TA.ensureTag(action)

    if enabled() then
        local name = action and (action.Type or action.classname) or "nil"
        EURY_TA.log("add name=" .. tostring(name)
            .. " id=" .. tostring(action and action.EURY_id)
            .. " tag=" .. tostring(action and action.EURY_tag))
    end

    return _oldAdd(action)
end