--***********************************************************************
-- Railroader / RR_Sleep  -- sleeping in the locomotive cab
--
-- The engine-facing half of the cab bunk; the rules live in the pure, unit-tested
-- shared/Railroader/RR_SleepRules.lua.
--
-- HOW SLEEP ACTUALLY WORKS IN B42 (verified in vanilla Lua + decompiled Java, not
-- guessed): a bed is NOT required. Sleeping in a car runs the identical code with
-- bed = nil -- ISVehicleMenu.onConfirmSleep -> ISWorldObjectContextMenu.
-- onSleepWalkToComplete(player, nil) -- and everything downstream is null-safe:
-- SleepingEvent guards getBed() (SleepingEvent.java:363), the stat recovery reads only
-- the bedType STRING (IsoPlayer.updateStats_Sleeping), and the wake-up is driven by
-- setForceWakeUpTime plus a hard 16-hour ceiling (IsoPlayer.java:3145). So all we do
-- is what vanilla does, with our own bed grade:
--     setBedType / setForceWakeUpTime / setAsleepTime(0) / setAsleep(true)
--     getSleepingEvent():setPlayerFallAsleep(p, hours)   -- rolls nightmares/intruders
--     UIManager fade + (if everyone is out) speed x3 and an autosave
--
-- THE BED OBJECT IS NOT OURS (Task 1.P, owner decision A, 2026-07-28). Vanilla's own
-- sleep-in-a-car path passes bed = nil, and that is still the fallback here -- but when
-- RR_CabClimate is loaded, the setBed FIELD is its property for as long as the driver is
-- in the cab: it parks a world-less object named "Shelter" there, which is what switches
-- vanilla's tent branch on in three places (BodyDamage.UpdateWetness, Clothing.
-- getWetDryState, SleepingEvent.isExposedToPrecipitation). Clearing it at bedtime would
-- put the sleeper back out in the rain for the whole night. Sleep QUALITY is unaffected:
-- it comes from the bedType STRING, the only thing IsoPlayer.updateStats_Sleeping reads.
-- Never call setBed here or on waking -- RR_Ride.dismount does the clearing, when the
-- driver actually leaves.
--
-- We do NOT call vanilla's onSleepWalkToComplete directly, for one concrete reason:
-- it grades the bed itself via getBedQuality, whose vehicle-seat branch is gated on
-- getVehicle() -- nil for our IsoAnimal loco -- so the cab would come out as "floor",
-- the worst tier there is. See RR_SleepRules for the bed-grade decision.
--
-- The loco's own state is not touched beyond idling the throttle: the driver is
-- asleep, not gone, and RR_TrainEntity keeps posing/pinning him exactly as before
-- (that also holds for a DERAILED loco -- tickDerailed still calls Ride.pinRider and
-- still keeps the collider chain pinned, so the wreck goes on walling zombies off
-- while its driver sleeps in it).
--
-- Entry point: RR.CabMenu (the V radial). RR_Ride gates its controls on isAsleep().
--***********************************************************************

require("Railroader/RR_SleepRules")
local Rules = RR and RR.SleepRules

local Sleep = {}
Sleep.modal = nil     -- the open confirm dialog, if any (one at a time)

--------------------------------------------------------------------------
-- serverFlag(name): a server option that is simply TRUE in single-player. Mirrors
-- vanilla's `not isClient() or getServerOptions():getBoolean(name)`.
--------------------------------------------------------------------------
local function serverFlag(name)
    local v = true
    pcall(function()
        if isClient() then v = getServerOptions():getBoolean(name) end
    end)
    return v
end

--------------------------------------------------------------------------
-- state(e): the live inputs RR_SleepRules needs, all read defensively -- a missing
-- getter must degrade to "no objection" rather than kill the menu build.
--------------------------------------------------------------------------
function Sleep.state(e)
    local p = getPlayer()
    local s = {
        seated       = (RR.Ride ~= nil and RR.Ride.current == e and e ~= nil),
        speed        = (e and e.drive and e.drive.v) or 0,
        sleepAllowed = serverFlag("SleepAllowed"),
        sleepNeeded  = serverFlag("SleepNeeded"),
        fatigue      = 1.0,
        zombies      = false,
        painLevel    = 0,
        panicLevel   = 0,
        pills        = 0,
        hoursSurvived   = 0,
        lastHourSleeped = 0,
        engineRunning   = (e and e.engine and e.engine.running) == true,
        lightsOn        = false,
    }
    if not p then return s end
    pcall(function() s.fatigue = p:getStats():get(CharacterStat.FATIGUE) end)
    pcall(function()
        local st = p:getStats()
        s.zombies = st:getNumVisibleZombies() > 0 or st:getNumChasingZombies() > 0
                    or st:getNumVeryCloseZombies() > 0
    end)
    pcall(function() s.painLevel  = p:getMoodles():getMoodleLevel(MoodleType.PAIN) end)
    pcall(function() s.panicLevel = p:getMoodles():getMoodleLevel(MoodleType.PANIC) end)
    pcall(function() s.pills = p:getSleepingTabletEffect() end)
    pcall(function() s.hoursSurvived = p:getHoursSurvived() end)
    pcall(function() s.lastHourSleeped = p:getLastHourSleeped() end)
    -- Lights: what is ACTUALLY lit (the battery may already be refusing the switch),
    -- which is also what the battery is being billed for.
    pcall(function()
        if RR.Lights and e and e.lightState then
            local eff = RR.Lights.effective(e.lightState, e.engine)
            s.lightsOn = (eff.head ~= RR.Lights.OFF) or eff.cab == true
        end
    end)
    return s
end

--------------------------------------------------------------------------
-- check(e) -> ok, reasonKey  /  warnings(e) -> { key, ... }
-- Thin wrappers so the menu never has to know how state is gathered.
--------------------------------------------------------------------------
function Sleep.check(e)     return Rules.canSleep(Sleep.state(e)) end
function Sleep.warnings(e)  return Rules.warnings(Sleep.state(e)) end

--------------------------------------------------------------------------
-- traitsOf(p): the three sleep-length traits, as the pure module wants them.
-- CharacterTrait enum constants, exactly as vanilla queries them
-- (ISWorldObjectContextMenu.lua:1080-1088) -- NOT strings (a String where B42 wants
-- an enum is the hasTag class of bug: it throws deep in Kahlua).
--------------------------------------------------------------------------
local function traitsOf(p)
    local t = {}
    pcall(function()
        t.insomniac      = p:hasTrait(CharacterTrait.INSOMNIAC)
        t.needsLessSleep = p:hasTrait(CharacterTrait.NEEDS_LESS_SLEEP)
        t.needsMoreSleep = p:hasTrait(CharacterTrait.NEEDS_MORE_SLEEP)
    end)
    return t
end

--------------------------------------------------------------------------
-- begin(e): put the driver under. Re-checks the gates first -- the confirm dialog
-- gives the world a couple of seconds to change its mind (a zombie can walk into
-- view while it is open), and vanilla re-checks at this point too.
--------------------------------------------------------------------------
function Sleep.begin(e)
    local p = getPlayer()
    if not p or not e then return end

    local ok, reason = Sleep.check(e)
    if not ok then
        if reason then
            pcall(function() HaloTextHelper.addBadText(p, getText(reason)) end)
        end
        return
    end

    -- Hands off the controls before the screen fades: a notch left standing would be
    -- waiting for the engine on wake-up, and the brake is released the same way
    -- Ride.dismount does it (a parked loco holds on its own resistance).
    e.throttle   = 0
    e.brakeInput = 0

    local u = 0.5
    pcall(function() u = ZombRandFloat(0.0, 1.0) end)
    local hours = Rules.sleepFor(Sleep.state(e).fatigue, traitsOf(p), u)

    local timeOfDay = 0
    pcall(function() timeOfDay = GameTime.getInstance():getTimeOfDay() end)
    local wake = Rules.wakeHour(hours, timeOfDay)

    -- Exercise bookkeeping + a clean action queue, both straight out of vanilla's
    -- sleep path (a running exercise blocks sleep outright).
    pcall(function()
        p:setVariable("ExerciseStarted", false)
        p:setVariable("ExerciseEnded", true)
        ISTimedActionQueue.clear(p)
    end)

    -- The bed OBJECT is owned by RR_CabClimate (owner decision A, 2026-07-28): while the
    -- driver is in the cab it holds the "Shelter" marker that makes vanilla treat the cab
    -- as a tent -- no rain on the sleeper (SleepingEvent.isExposedToPrecipitation), and
    -- clothes dry instead of soaking (Clothing.getWetDryState). Clearing it here would
    -- put him back out in the weather for the whole night, which is the one time it
    -- matters most. Sleep still grades the bed itself, by the bedType STRING below --
    -- that is what IsoPlayer.updateStats_Sleeping reads, and the marker never enters it.
    if RR.CabClimate then pcall(function() RR.CabClimate.assertShelter(p) end)
    else pcall(function() p:setBed(nil) end) end               -- no cab climate: vanilla car behaviour
    pcall(function() p:setBedType(Rules.C.BED_TYPE) end)      -- "badBed" -- a seat, like a car's
    pcall(function() p:setForceWakeUpTime(wake) end)
    pcall(function() p:setAsleepTime(0.0) end)
    pcall(function() p:setAsleep(true) end)
    -- MP: mirror vanilla vehicle sleep -- the server's copy of the character
    -- must be asleep too, or the server-side wetness check (BodyDamage.
    -- UpdateWetness: asleep|sitting|RESTING + Shelter bed) keeps the cab "out
    -- in the rain" all night on a dedicated server. Same command vanilla sends
    -- from ISWorldObjectContextMenu.onSleepWalkToComplete (onVehicleSleep).
    pcall(function()
        if isClient() then
            sendClientCommand(p, "player", "onVehicleSleep", { id = p:getOnlineID(), isAsleep = true })
        end
    end)
    pcall(function() getSleepingEvent():setPlayerFallAsleep(p, hours) end)

    local num = 0
    pcall(function() num = p:getPlayerNum() end)
    pcall(function()
        UIManager.setFadeBeforeUI(num, true)
        UIManager.FadeOut(num, 1)
    end)
    -- Everyone asleep -> vanilla speeds the world up and saves. Our per-tick stashState
    -- has already written the loco into modData, so the save is consistent.
    pcall(function()
        if IsoPlayer.allPlayersAsleep() then
            UIManager.getSpeedControls():SetCurrentGameSpeed(3)
            save(true)
        end
    end)

    print(string.format("[Railroader] asleep in the cab for ~%.1f h (wake at %.1f, bed=%s).",
          hours, wake, Rules.C.BED_TYPE))
end

--------------------------------------------------------------------------
-- Confirm dialog -- the same modal a bed and a car seat put up
-- (ISModalDialog:new(x,y,w,h,text,yesno,target,onclick,player,param1,param2), which
-- fires onclick(target, button, param1, param2)).
--------------------------------------------------------------------------
function Sleep.onConfirm(_target, button, e)
    Sleep.modal = nil
    if button and button.internal == "YES" then
        Sleep.begin(e)
    end
end

function Sleep.confirm(e)
    -- One dialog at a time -- but only while it is really still on screen. The stored
    -- handle is cleared by our own YES/NO callback; anything that closes the panel
    -- WITHOUT firing it (an ESC, a UI reset) would otherwise leave a stale reference
    -- here and the menu entry would go dead for the rest of the session.
    if Sleep.modal then
        local live = false
        pcall(function() live = Sleep.modal:isReallyVisible() end)
        if live then return end
        Sleep.modal = nil
    end
    local p = getPlayer()
    if not p or not e then return end
    local num = 0
    pcall(function() num = p:getPlayerNum() end)
    Sleep.modal = ISModalDialog:new(0, 0, 250, 150, getText("IGUI_ConfirmSleep"),
                                    true, nil, Sleep.onConfirm, num, e, nil)
    Sleep.modal:initialise()
    Sleep.modal:addToUIManager()
    pcall(function()
        if JoypadState.players[num + 1] then setJoypadFocus(num, Sleep.modal) end
    end)
end

--------------------------------------------------------------------------
-- isAsleep(): the one-liner every cab system asks before it does anything. A sleeping
-- driver must not crank the starter, notch up, brake, or hold the game at 1x.
--------------------------------------------------------------------------
function Sleep.isAsleep()
    local p = getPlayer()
    if not p then return false end
    local a = false
    pcall(function() a = p:isAsleep() end)
    return a == true
end

RR = RR or {}
RR.Sleep = Sleep

return Sleep
