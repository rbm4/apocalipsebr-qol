local MOD = "ButcherFix"

local DEBUG = getCore():getDebug()

local function log(msg)
    if DEBUG then
        DebugLog.log(DebugType.General, "[" .. MOD .. "][SH] " .. tostring(msg))
    end
end

local version = require("EuryBugs/_Version")
if not (version and version.isAtMax("42.13.1")) then
    log("skipped patch")
    return
end

require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/Animals/ISButcherAnimal"
require "TimedActions/Animals/ISGetAnimalBones"

TimedButcherFix = ISBaseTimedAction:derive("TimedButcherFix")


local KEY_REQ = MOD .. "_reqId"

EURY_ButcherFix = EURY_ButcherFix or {}
EURY_ButcherFix.REQS = EURY_ButcherFix.REQS or {}

local function getSquare(x, y, z)
    local cell = getCell()
    if not cell then return nil end
    return cell:getGridSquare(x, y, z)
end

local function getDeadBodiesList(square)
    if not square then return nil end
    if square.getDeadBodys then return square:getDeadBodys() end
    if square.getDeadBodies then return square:getDeadBodies() end
    return nil
end

local function listSize(list)
    if not list or not list.size then return 0 end
    return list:size()
end

local function listGet(list, idx)
    if not list or not list.get then return nil end
    return list:get(idx)
end

local function findCorpseByReqIdOnSquare(square, reqId)
    local list = getDeadBodiesList(square)
    local n = listSize(list)
    if n <= 0 then return nil end

    for i = 0, n - 1 do
        local corpse = listGet(list, i)
        if corpse and corpse.getModData then
            local md = corpse:getModData()
            if md and md[KEY_REQ] == reqId then
                return corpse
            end
        end
    end

    return nil
end

function TimedButcherFix:isValid()
    return self.character ~= nil
end

function TimedButcherFix:start()
end

function TimedButcherFix:update()
    if self._corpse then return end

    local st = EURY_ButcherFix.REQS[self.reqId]
    if not st then return end
    if not st.x then return end

    local sq = getSquare(st.x, st.y, st.z)
    if not sq then return end

    local corpse = findCorpseByReqIdOnSquare(sq, self.reqId)
    if corpse then
        self._corpse = corpse
        self.actionType = st.actionType or self.actionType
        self:forceComplete()
    end
end

function TimedButcherFix:perform()
    local corpse = self._corpse
    if corpse then
        if self.actionType == "bones" then
            ISTimedActionQueue.add(ISGetAnimalBones:new(self.character, corpse))
        else
            ISTimedActionQueue.add(ISButcherAnimal:new(self.character, corpse))
        end
    else
        log("Did not resolve corpse for reqId=" .. tostring(self.reqId) .. " before timeout")
    end

    EURY_ButcherFix.REQS[self.reqId] = nil
    ISBaseTimedAction.perform(self)
end

function TimedButcherFix:stop()
    ISBaseTimedAction.stop(self)
end

function TimedButcherFix:new(character, reqId, actionType)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.reqId = reqId
    o.actionType = actionType or "butcher"
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 180 -- ~3 seconds
    return o
end
