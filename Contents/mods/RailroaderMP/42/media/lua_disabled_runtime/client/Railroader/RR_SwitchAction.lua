--***********************************************************************
-- Railroader / RR_SwitchAction  (throwing a switch is WORK, not a click)
--
-- A 1990s branch-line switch is hand-thrown: the crew walks to the stand and
-- heaves the lever over. So the context menu does not flip the state instantly --
-- it walks the survivor to the turnout (luautils.walkAdj) and queues this timed
-- action, which shows the usual progress bar for ~2.5s.
--
-- The state is applied ONLY in perform(), so an interrupted throw (the player
-- walks off, runs, or aims -- stopOnWalk/stopOnRun/stopOnAim) leaves the switch
-- exactly as it was. That is also the honest behaviour: a half-thrown switch is
-- not thrown.
--
-- Grounded in decompiled B42: IsoGameCharacter has faceThisObject(IsoObject) but
-- NOT faceLocation, hence the action holds the turnout IsoObject, not a square.
--***********************************************************************

print("[Railroader] RR_SwitchAction.lua: loading...")
require "TimedActions/ISBaseTimedAction"
require("Railroader/RR_TrackGraph")

ISRRThrowSwitch = ISBaseTimedAction:derive("ISRRThrowSwitch")

--------------------------------------------------------------------------
-- Valid while the graph still knows this switch AND it isn't already where we
-- want it (clicking the already-checked option is a no-op, not a 2.5s wait).
--------------------------------------------------------------------------
function ISRRThrowSwitch:isValid()
    if not (RR and RR.TrackGraph and RR.TrackGraph.has(self.baseId)) then return false end
    return RR.TrackGraph.getState(self.baseId, self.switchId) ~= self.state
end

function ISRRThrowSwitch:start()
    self:setActionAnim("Loot")
    self.character:faceThisObject(self.object)
end

function ISRRThrowSwitch:update()
    self.character:faceThisObject(self.object)
end

function ISRRThrowSwitch:stop()
    ISBaseTimedAction.stop(self)
end

--------------------------------------------------------------------------
-- The lever goes over: this is the ONLY place the switch state changes.
--------------------------------------------------------------------------
function ISRRThrowSwitch:perform()
    if RR.MPClient then
        sendClientCommand(self.character, "RailroaderMP", "switch", {
            baseId = self.baseId, switchId = self.switchId, state = self.state,
        })
        ISBaseTimedAction.perform(self)
        return
    end
    RR.TrackGraph.setState(self.baseId, self.switchId, self.state)
    -- Remember the lever position across save/reload (RR_SwitchPersist -> RR_World
    -- ModData). Done here, not in setState, so the graph module stays engine-free.
    if RR.SwitchPersist then pcall(RR.SwitchPersist.save) end
    -- The points slam over. Played as a POSITIONAL WORLD one-shot at the turnout square
    -- (getSoundManager():PlayWorldSound -- the same path the loco engine/crush sounds use,
    -- and vanilla's ISShovelGround). NOT self.character:playSound: in B42 the character
    -- emitter went silent on our loose .wav (it seems to want bank events now), and this
    -- was the mod's only sound on that path. Only in perform(): an interrupted throw stays
    -- silent because nothing moved.
    pcall(function()
        local sq = (self.object and self.object.getSquare and self.object:getSquare())
                   or (self.character and self.character:getSquare())
        if sq then
            getSoundManager():PlayWorldSound("RR_SwitchThrow", sq, 0, 18, 1.0, true)
        end
    end)
    local label = (self.state == "reverse") and getText("IGUI_RR_SwitchDiverge")
                                            or  getText("IGUI_RR_SwitchMain")
    print(string.format("[Railroader] switch '%s' (%s) thrown to %s.",
          self.switchId, self.baseId, self.state))
    pcall(function()
        HaloTextHelper.addText(self.character, getText("IGUI_RR_SwitchThrown", label))
    end)
    ISBaseTimedAction.perform(self)
end

function ISRRThrowSwitch:new(character, object, baseId, switchId, state)
    local o = ISBaseTimedAction.new(self, character)
    o.object     = object
    o.baseId     = baseId
    o.switchId   = switchId
    o.state      = state
    o.maxTime    = 150      -- ~2.5s: a real heave on the stand
    o.stopOnWalk = true
    o.stopOnRun  = true
    return o
end

print("[Railroader] RR_SwitchAction.lua: loaded OK")
return ISRRThrowSwitch
