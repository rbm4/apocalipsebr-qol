--***********************************************************************
-- Railroader / RR_SleepRules  -- may the driver sleep in the cab, and for how long?
--
-- PURE (no engine calls) so it can be unit-tested offline, exactly like RR_Drive /
-- RR_Engine. The adapter that reads the live player/loco and actually puts the
-- character under is client/Railroader/RR_Sleep.lua.
--
-- WHY THIS EXISTS AT ALL: vanilla B42 already has everything needed to sleep
-- ANYWHERE -- the whole mechanic is five setters on IsoPlayer plus one
-- SleepingEvent call, and NOTHING in it requires a bed or a vehicle. Sleeping in a
-- car goes through the very same code with bed = nil (ISVehicleMenu.onConfirmSleep
-- -> ISWorldObjectContextMenu.onSleepWalkToComplete(player, nil)); SleepingEvent
-- null-guards getBed(), and wake-up is driven by the clock. So the cab needs no new
-- machinery -- only the RULES: who may lie down, and how good the sleep is.
--
-- BED QUALITY. Vanilla decides it in ISWorldObjectContextMenu.getBedQuality, whose
-- "vehicle seat" branch is gated on playerObj:getVehicle() -- always nil for us (the
-- loco is an IsoAnimal), so calling vanilla would grade the cab as "floor": the
-- WORST tier (wake up MORE tired, 1-in-5 neck injury, 1.6x slower to drop off).
-- A GP7 driver's seat is a padded seat with a backrest -- the same thing a car gives
-- you -- so we force "badBed", the vehicle tier. Owner decision (2026-07-28): that
-- holds even for a DERAILED loco. A wreck is still a cab with a seat in it; the
-- night you put 112 t on the ground is punishing enough without also breaking the
-- driver's neck for it.
--
-- THE GATES are vanilla's own list for a car (ISVehicleMenu.lua:190-227) plus one of
-- ours (a rolling loco). Deliberately NOT gated: the Railroader licence (sleeping in
-- a seat is not operating a locomotive) and the derail state (see above).
--
-- Reason strings returned here are TRANSLATION KEYS, so the caller just getText()s
-- them; vanilla keys are reused where vanilla already says the same thing.
--***********************************************************************

local Rules = {}

local C = {
    STOPPED_MPS      = 0.15,   -- m/s: at/below this the loco counts as parked (mirrors RR_Ride.DISMOUNT_SPEED)
    FATIGUE_MIN      = 0.3,    -- below this you are simply not tired enough
    PAIN_LEVEL       = 2,      -- pain moodle at/above this blocks sleep...
    PAIN_FATIGUE     = 0.85,   -- ...unless you are this exhausted (vanilla lets pain lose to fatigue)
    PANIC_LEVEL      = 1,      -- any panic blocks sleep
    PILLS_OVERRIDE   = 2000,   -- sleeping-tablet effect that suppresses the pain/panic gates
    RECENT_SLEEP_H   = 1,      -- hours survived since the last sleep, below which you can't go back down
                               -- (vanilla's anti sleeping-pill-exploit rule)
    BED_TYPE         = "badBed",  -- the cab seat == a car seat (see header)
    SLEEP_MIN_H      = 3,
    SLEEP_MAX_H      = 16,
}
Rules.C = C

--------------------------------------------------------------------------
-- canSleep(s) -> ok, reasonKey
--
--   s.sleepAllowed   -- server option (SP: true)
--   s.sleepNeeded    -- server option (SP: true). Vanilla applies it to the
--                       tired/zombies/too-early gates but NOT to pain/panic.
--   s.seated         -- is the character actually in a cab
--   s.speed          -- |v| of the loco, m/s
--   s.fatigue        -- CharacterStat.FATIGUE, 0..1
--   s.zombies        -- any visible/chasing/very-close zombies
--   s.painLevel, s.panicLevel   -- moodle levels
--   s.pills          -- getSleepingTabletEffect()
--   s.hoursSurvived, s.lastHourSleeped
--
-- ok == false with reasonKey == nil means "offer nothing at all" (sleep is switched
-- off server-side, or there is no cab) -- the caller adds no menu entry. A reasonKey
-- means "show a dead entry that says why", which is exactly how vanilla's vehicle
-- radial explains a refusal.
--------------------------------------------------------------------------
function Rules.canSleep(s)
    s = s or {}
    if s.sleepAllowed == false then return false, nil end
    if not s.seated then return false, nil end

    -- Ours: you cannot sleep in a moving locomotive (vanilla: not vehicle:isStopped()).
    if math.abs(s.speed or 0) > C.STOPPED_MPS then
        return false, "IGUI_RR_NoSleepMoving"
    end

    local needed = (s.sleepNeeded ~= false)
    if needed and (s.fatigue or 0) <= C.FATIGUE_MIN then
        return false, "IGUI_Sleep_NotTiredEnough"
    end
    if needed and s.zombies then
        return false, "IGUI_Sleep_NotSafe"
    end
    if needed and ((s.hoursSurvived or 0) - (s.lastHourSleeped or 0)) <= C.RECENT_SLEEP_H then
        return false, "ContextMenu_NoSleepTooEarly"
    end
    -- Sleeping pills counter the pain/panic problems (vanilla comment, vanilla threshold).
    if (s.pills or 0) < C.PILLS_OVERRIDE then
        if (s.painLevel or 0) >= C.PAIN_LEVEL and (s.fatigue or 0) <= C.PAIN_FATIGUE then
            return false, "ContextMenu_PainNoSleep"
        end
        if (s.panicLevel or 0) >= C.PANIC_LEVEL then
            return false, "ContextMenu_PanicNoSleep"
        end
    end
    return true, nil
end

--------------------------------------------------------------------------
-- warnings(s) -> { translationKey, ... }
--
-- Things that will not stop you lying down but WILL cost you something by morning.
-- Both are pure consequences of systems we already run, and both are worth saying out
-- loud in the menu because neither is visible once the screen fades:
--
--   * engineRunning -- an idling GP7 fires a WorldSoundManager event of radius
--     NOISE_IDLE (30 tiles) every half second (RR_SoundConfig). Zombies walk in, and
--     SleepingEvent.update wakes you the moment one is very close -- with +70 panic.
--     Shutting down before you sleep is the whole point of the warning.
--   * lightsOn -- with the engine off the headlight runs off the battery
--     (RR_Lights.DRAW_BRIGHT): a full bank reaches the protective CUTOFF in about six
--     in-game hours, i.e. roughly one night's sleep. You wake to dark glass.
--------------------------------------------------------------------------
function Rules.warnings(s)
    s = s or {}
    local w = {}
    if s.engineRunning then w[#w + 1] = "IGUI_RR_SleepEngineRunning" end
    if s.lightsOn and not s.engineRunning then w[#w + 1] = "IGUI_RR_SleepLightsOn" end
    return w
end

--------------------------------------------------------------------------
-- sleepFor(fatigue, traits, u) -> hours
--
-- Reproduces vanilla's roll (ISWorldObjectContextMenu.onSleepWalkToComplete):
--     sleepFor = ZombRand(fatigue*10, fatigue*13) + 1
--     badBed   -> +1 hour   (our fixed bed type)
--     traits   -> insomniac x0.5, needsLessSleep x0.75, needsMoreSleep x1.18
--     clamped to [3, 16]
-- `u` is the random draw as a fraction in [0,1) -- the caller passes ZombRandFloat,
-- the tests pass a constant. ZombRand(lo, hi) is integer and hi-exclusive, hence the
-- floor().
--------------------------------------------------------------------------
function Rules.sleepFor(fatigue, traits, u)
    fatigue = fatigue or 0
    traits  = traits or {}
    local lo, hi = fatigue * 10, fatigue * 13
    local h = math.floor(lo + (u or 0) * (hi - lo)) + 1
    h = h + 1                                            -- badBed
    if traits.insomniac      then h = h * 0.5  end
    if traits.needsLessSleep then h = h * 0.75 end
    if traits.needsMoreSleep then h = h * 1.18 end
    if h > C.SLEEP_MAX_H then h = C.SLEEP_MAX_H end
    if h < C.SLEEP_MIN_H then h = C.SLEEP_MIN_H end
    return h
end

--------------------------------------------------------------------------
-- wakeHour(sleepFor, timeOfDay) -> hour of day to force the wake-up at (0..24).
-- setForceWakeUpTime takes a TIME OF DAY, not a duration, so it has to wrap.
--------------------------------------------------------------------------
function Rules.wakeHour(sleepFor, timeOfDay)
    local h = (sleepFor or 0) + (timeOfDay or 0)
    while h >= 24 do h = h - 24 end
    return h
end

RR = RR or {}
RR.SleepRules = Rules

return Rules
