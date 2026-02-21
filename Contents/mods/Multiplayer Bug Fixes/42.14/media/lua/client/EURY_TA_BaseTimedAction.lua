require "EURY_TA_Tag"
require "TimedActions/ISBaseTimedAction"

local DEBUG = getCore():getDebug()

local function enabled()
    return DEBUG
end

local _oldStart   = ISBaseTimedAction.start
function ISBaseTimedAction:start()
    EURY_TA.ensureTag(self)
    if enabled() then
        local name = self.Type or self.classname or "TimedAction"
        EURY_TA.log("start name=" .. tostring(name)
            .. " id=" .. tostring(self.EURY_id)
            .. " tag=" .. tostring(self.EURY_tag))
    end
    if _oldStart then return _oldStart(self) end
end

local _oldStop    = ISBaseTimedAction.stop
function ISBaseTimedAction:stop()
    EURY_TA.ensureTag(self)
    if enabled() then
        local name = self.Type or self.classname or "TimedAction"
        EURY_TA.log("stop name=" .. tostring(name)
            .. " id=" .. tostring(self.EURY_id)
            .. " tag=" .. tostring(self.EURY_tag))
    end
    if _oldStop then return _oldStop(self) end
end

local _oldPerform = ISBaseTimedAction.perform
function ISBaseTimedAction:perform()
    EURY_TA.ensureTag(self)
    if enabled() then
        local name = self.Type or self.classname or "TimedAction"
        EURY_TA.log("perform name=" .. tostring(name)
            .. " id=" .. tostring(self.EURY_id)
            .. " tag=" .. tostring(self.EURY_tag))
    end
    if _oldPerform then return _oldPerform(self) end
end
