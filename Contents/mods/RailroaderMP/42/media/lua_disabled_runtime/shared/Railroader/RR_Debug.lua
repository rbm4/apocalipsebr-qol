--***********************************************************************
-- Railroader / RR_Debug  -- one master switch for every development aid
--
-- FIELD MODE (this is the shipping default, RR.Debug.enabled = false): the mod behaves
-- exactly as a player meets it. No teleports, no conjured locomotives, no auto-drive, no
-- overlays, no calibration nudges -- the ONLY keys the mod answers are the ones a driver
-- uses (E board/leave, W/S throttle, R reverser, Space brake, F lights, Q horn, L bell).
--
-- WHY A GATE AND NOT A DELETE: the tools are how this mod got built (the габарит overlay,
-- the per-direction alignment nudger, the coord capture that authored 61 switches, the
-- test-car spawner). They cost sessions to make and they will be needed again the moment
-- rolling stock or a new route lands. Deleting them buys nothing that `enabled = false`
-- doesn't -- an inert key handler costs one comparison per keypress.
--
-- TURN THEM BACK ON for a development session, from the in-game console:
--     RR.Debug.set(true)
-- ...and off again with RR.Debug.set(false). It is deliberately NOT tied to the game's own
-- `-debug` flag: beta testers are told to run with the console open to report bugs, and
-- that must not silently re-arm a key that teleports the locomotive.
--
-- WHAT IS GATED (all of it is key-driven, i.e. reachable by accident):
--   O  goto the loco (else the depot shed)    RR_Depot
--   G  debug cruise (auto-drive, no driver)   RR_TrainEntity
--   P  goto switch s1 (spawns a warm loco)    RR_TrainEntity
--   C  clear the loco (re-arms the spawn)     RR_TrainEntity
--   J/H  capture / clear route coords         RR_TrainEntity
--   T  dump nearby tile sprites               RR_TrainEntity
--   N  throw the nearest switch remotely      RR_TrainEntity
--   K  legacy "leave the cab now"             RR_Ride
--   U  footprint (габарит) overlay            RR_BodyDebug
--   I  collider segment tiles                 RR_Collider
--   numpad  per-direction alignment nudger    RR_Calibrate
-- NOT gated, on purpose:
--   * the BAKED calibration offsets (RR_Calibrate.entries / offsetFor) -- that is live
--     geometry every pose is built on, not a tool;
--   * console-only helpers (RR.TrainEntity.spawn / .forceDerail, RR.ObstacleSweep.spawnCar
--     / .mark, RR.AlbumPlace.giveToPlayer, RR.DieselFluid.refuelNearestLoco, ...) -- they
--     cannot be hit by accident, and they are how a tester reproduces a report on demand;
--   * the `[Railroader]` console log -- that IS the bug report in a field beta.
--***********************************************************************

RR = RR or {}

local Debug = {}

-- SHIPPING DEFAULT (v1.0, owner 2026-07-30): the dev keys are INERT from load -- O/G/P/C/...
-- do nothing until a session arms them. That is the whole point of the gate: a player, or a
-- beta tester running with the console open, cannot teleport or conjure the locomotive by
-- pressing a letter. For a development session, type RR.Debug.set(true) in the console (and
-- .set(false) to disarm); nothing about this is persisted to the save.
Debug.enabled = false

--------------------------------------------------------------------------
-- isOn() -- the gate every debug key handler asks. Written defensively (no upvalue
-- capture of the flag) so `RR.Debug.enabled = true` typed in the console takes effect on
-- the very next keypress.
--------------------------------------------------------------------------
function Debug.isOn()
    return RR.Debug and RR.Debug.enabled and true or false
end

--------------------------------------------------------------------------
-- set(v) -- toggle from the console and say what just happened (a silent toggle is how
-- you end up wondering why O does nothing).
--------------------------------------------------------------------------
function Debug.set(v)
    RR.Debug.enabled = v and true or false
    if RR.Debug.enabled then
        print("[Railroader] DEBUG TOOLS ON -- O=goto-loco G=cruise P=goto-switch C=clear "
              .. "J/H=capture-coords T=dump-tiles N=throw-switch K=leave-cab U=footprint "
              .. "I=collider-tiles numpad=align")
    else
        print("[Railroader] debug tools OFF (field mode). RR.Debug.set(true) to re-arm.")
    end
    return RR.Debug.enabled
end

RR.Debug = Debug
print("[Railroader] RR_Debug.lua: loaded OK -- debug tools "
      .. (Debug.enabled and "ON" or "OFF (field mode); RR.Debug.set(true) to re-arm"))

return Debug
