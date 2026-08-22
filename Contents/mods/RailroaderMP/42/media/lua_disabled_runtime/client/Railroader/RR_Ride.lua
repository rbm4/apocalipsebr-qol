--***********************************************************************
-- Railroader / RR_Ride  -- player seating + MANUAL DRIVE controls (Task 1.D)
--
-- Vanilla B42 has NO rideable system. This pins the player onto a moving custom
-- entity (camera tracks it, walking input blocked) using only Lua + verified
-- engine methods -- no BaseVehicle. Proven in the vertical slice; Task 1.D adds
-- the driver's controls on top of the same pin.
--
-- Seating (each grounded in decompiled B42):
--   * IsoPlayer:setBlockMovement(true)  -> freeze input-driven walking (exactly
--     what vanilla does while the world map / on-screen keyboard is open).
--   * Each tick, snap player x/y/z to the entity's current pose; camera follows.
--   * animal:setCollidable(false) so its separate() doesn't shove us off the seat.
--
-- Driving (writes the entity's RR_Drive control inputs; physics runs in
-- RR_TrainEntity.onTick):
--   E  board/leave (like a vehicle) -- see below.   L/K  legacy debug mount/dismount
--   W  throttle +1 notch    S  throttle -1 notch   (0=idle .. 8=Run 8)
--   R  reverser cycle F -> N -> R   (only near a standstill -- can't reverse a
--                                    rolling loco; realistic). Also turns the DRIVER
--                                    round: his default facing is the direction the
--                                    handle selects (travelFacing / Drive.faceSign).
--   Space (HOLD)  independent air brake  (ramps to full; release to release)
--   RMB (HOLD)  look toward the cursor (swings the driver's facing + vision cone);
--               release = face along the rails, the way the reverser points.
--               Reproduces vanilla free-look, which setBlockMovement disables (the
--               engine skips input turning while movement is blocked).
-- Mounting NO LONGER auto-departs -- the player drives (replaces old G auto-run;
-- G stays as a debug cruise when nobody is seated).
--
-- E-key board/leave (vehicle-like, the primary control):
--   * On foot, within MOUNT_REACH tiles OF THE LOCO'S DRAWN HULL (not its centre --
--     the body is 15 tiles long): board it (mountNearest gated by distance so E
--     elsewhere falls through to vanilla interact).
--   * Seated & stopped: step off -- placed a little to the SIDE of the loco by the
--     cab door, always on the CAMERA-FACING side (bottom of the iso screen) so the
--     body isn't hidden behind the hood.
--   * Seated & MOVING: cut throttle to idle + full service brake, then auto-step-off
--     the instant the loco comes to rest (pendingDismount, resolved in onTick).
--***********************************************************************

require("Railroader/RR_Drive")
require("Railroader/RR_Engine")
local Drive  = RR and RR.Drive
local Engine = RR and RR.Engine

local Ride = {}
Ride.current = nil     -- the active entity record from RR.TrainEntity.active
Ride.pendingDismount = false  -- E pressed while rolling: brake now, step off once stopped

-- v1.0.18: debug logging OFF by default (RR.dbgLog = true in the console to
-- re-arm the [RailroaderMP-dbg] prints).
RR.dbgLog = RR.dbgLog or false
local function dbg(fmt, ...)
    if RR.dbgLog then print(string.format("[RailroaderMP-dbg] " .. fmt, ...)) end
end

local REVERSE_GATE = 0.2   -- m/s below which the reverser may be switched

--------------------------------------------------------------------------
-- nowMs(): wall-clock milliseconds for the board lock (RR_MPClient uses the
-- same getTimestampMs global). Nil when unavailable -> lock disabled.
--------------------------------------------------------------------------
local function nowMs()
    if not getTimestampMs then return nil end
    local ok, t = pcall(function() return getTimestampMs() end)
    if ok and t then return t end
    return nil
end

-- Board lock: E-boarding in MP gives no feedback until the server round-trip
-- (~100 ms), so a fast second tap -- which players naturally make when the first
-- press "did nothing" -- immediately undoes the mount ("re-seated" then
-- "stepped off" 0.1-1 s later in the field log). E is swallowed for
-- BOARD_LOCK_MS after a board request, in BOTH directions.
local BOARD_LOCK_MS = 1000

--------------------------------------------------------------------------
-- seatWorld: the world point the driver sits at THIS frame. The pose is the loco's
-- body CENTRE (the two-truck chord); the driver belongs in the CAB, which sits a
-- fixed offset toward one end (RR.Body.seatOffset -- longitudinal + lateral + lift,
-- body-local). We turn that body-local offset into world coords with the pose's
-- forward + right vectors (right = forward rotated -90, matching RR_Collider /
-- RR.Body.toLocal). The pose direction is fixed to the route (NOT flipped by the
-- reverser -- see RR_LightsRender.leadSign), so the cab end is stable when reversing.
-- The size-derived offset is constant per loco, so it's cached on the record.
--------------------------------------------------------------------------
local function seatOffsets(e)
    if e._seat then return e._seat end
    local size = 0.7
    if e.animal then pcall(function() size = e.animal:getAnimalSize() end) end
    local u, w, lift = 0, 0, 0
    if RR.Body and RR.Body.seatOffset then u, w, lift = RR.Body.seatOffset(size) end
    e._seatSize = size
    e._seat = { u = u, w = w, lift = lift }
    return e._seat
end

-- Shared pure seat math (RR.Body.seatWorld): the server pins seated players to
-- the IDENTICAL world points (RR_ServerTrain), so every client sees the driver
-- and passengers standing on the train exactly where this client renders them.
local function seatWorld(e, pose)
    if RR.Body and RR.Body.seatWorld then
        seatOffsets(e)                                    -- populate _seatSize/_seat first
        return RR.Body.seatWorld(pose, e and e._seatSize or 0.7, e and e.seat or 0)
    end
    local s = seatOffsets(e)
    local passenger = e.seat and e.seat > 0 and (RR.Body and RR.Body.PASSENGER_SEATS or {})[e.seat]
    if passenger then s = { u = s.u + passenger.u, w = s.w + passenger.w, lift = s.lift } end
    local fx, fy = pose.dirX or 0, pose.dirY or 0
    local rx, ry = -fy, fx                       -- right of travel
    return pose.x + s.u * fx + s.w * rx,
           pose.y + s.u * fy + s.w * ry,
           (pose.z or 0) + (s.lift or 0)
end

--------------------------------------------------------------------------
-- travelFacing: the driver's DEFAULT facing -- along the rails, in the direction the
-- REVERSER has selected. The pose above is always the +distance tangent (the loco has
-- no wrong way round), so running in REVERSE means the driver faces the other way down
-- that same tangent: negate it. The seat does NOT move -- the cab end is fixed to the
-- body, the man in it just turns round, which is what makes the pose stable when the
-- handle is thrown.
--
-- The rule itself is pure and unit-tested (Drive.faceSign); its one piece of memory --
-- NEUTRAL keeps the direction last selected, so centring the handle to start or shut
-- down the diesel doesn't spin the driver round -- rides on the record as _faceSign.
--------------------------------------------------------------------------
local function travelFacing(e, pose)
    local s = 1
    if Drive and Drive.faceSign then
        s = Drive.faceSign(e and e.reverser, e and e._faceSign)
        if e then e._faceSign = s end
    end
    return (pose.dirX or 0) * s, (pose.dirY or 0) * s
end

-- Engine start/stop (engine-start mechanic). Cranking = HOLD W while the engine
-- is off & seated (polled each tick, like the brake); shutting down = HOLD S with
-- the throttle already at idle. See onTick.
local SHUTDOWN_HOLD  = 1.4   -- s of holding S at notch 0 to shut the engine down
local START_GATE_MSG = 2.0   -- s between repeated "can't start yet" console hints

--------------------------------------------------------------------------
-- startEnv: the weather inputs to Engine.startChance (cold/wet lower the catch
-- chance). Pulled from the live ClimateManager; missing data => ideal (no penalty).
-- getTemperature() is °C; isRaining() is the wet flag (verified in decompiled B42).
--------------------------------------------------------------------------
-- external power for a JUMP-START ("прикур"): a running generator powering the
-- loco's square, OR live grid power inside a building (a depot shed that is a mapped
-- room, while the world's electricity is still on). No hardcoded depot list -- the
-- square answers for itself, so any powered building or generator qualifies. There
-- is no wayside charger on the branch; a flat bank is jumped, then the engine's own
-- generator brings it back once running.
local function hasExternalPower(e)
    local sq = e and e.animal and e.animal:getSquare()
    if not sq then return false end
    local powered = false
    pcall(function()
        -- A running generator powering the square. We go through the CHUNK's
        -- isGeneratorPoweringSquare, which is what haveElectricity() checks AFTER its
        -- exterior gate -- calling it directly means the jump works from a generator
        -- outdoors too, regardless of the allowExteriorGenerator sandbox option.
        local ch = sq.getChunk and sq:getChunk()
        if ch and ch.isGeneratorPoweringSquare
           and ch:isGeneratorPoweringSquare(sq:getX(), sq:getY(), sq:getZ()) then
            powered = true
        elseif sq:haveElectricity() then
            powered = true
        elseif sq.hasGridPower and sq:hasGridPower() and sq:getRoom() ~= nil then
            powered = true   -- live grid inside a building (a depot shed with a room)
        end
    end)
    return powered
end

local function startEnv(e)
    local env = { licensed = Ride.isLicensed(e), externalPower = hasExternalPower(e) }
    pcall(function()
        local cm = getClimateManager()
        if cm then
            env.tempC = cm:getTemperature()
            env.wet   = cm:isRaining()
        end
    end)
    return env
end

--------------------------------------------------------------------------
-- sayBad(key, fallback): tell the PLAYER (not the log) why the cab won't answer.
-- The vanilla channel for "you can't do that" is a red halo over the character's
-- head -- HaloTextHelper.addBadText(player, getText(key)) -- which is exactly how a
-- vehicle refuses you ("can't sleep in a moving car", ISVehicleMenu.lua). getText
-- returns the KEY itself when a translation is missing, so fall back to plain text.
-- Every caller is behind a de-dupe gate (e._licGate / e._crankGate), so a held key
-- can't spam the halo. print() stays as the log trail.
--------------------------------------------------------------------------
local function sayBad(key, fallback)
    local p = getPlayer()
    if not p then return end
    pcall(function()
        local txt = getText(key)
        if not txt or txt == "" or txt == key then txt = fallback end
        HaloTextHelper.addBadText(p, txt)
    end)
end

--------------------------------------------------------------------------
-- isLicensed(e): may the character in this cab work the loco? (Task 1.F.) The
-- ONE place the engine-side trait query is read from; the pure model gets it as a
-- boolean (RR_Engine env.licensed). Cached on the record at boarding time -- a
-- character's profession never changes mid-game -- so we don't hit hasTrait every
-- tick. An EMPTY cab (debug G cruise, no driver) is unrestricted: nobody to card.
--------------------------------------------------------------------------
function Ride.isLicensed(e)
    if not e then return true end
    if e.licensed == nil then
        local P = RR and RR.Profession
        e.licensed = (not P) or P.hasLicense(getPlayer()) == true
    end
    return e.licensed == true
end

-- E-key board/leave tunables.
-- MOUNT_REACH is measured from the DRAWN HULL (RR.Body.hullDistance), not from the
-- loco's centre: the body is ~15 tiles long, so a centre radius means one number has
-- to cover both "arm's length at the cab door" and "two car-lengths off the nose".
-- 2.0 = you must be standing beside/at the loco, roughly a car's reach. Against the
-- old 8-tile CENTRE radius (owner, 2026-07-30) at the live size 0.7 (hull 14.96 x 3.14):
-- alongside the flanks the reach drops from ~6.4 tiles off the body to 2, while off the
-- nose/tail it goes from ~0.5 (the centre radius barely cleared the hull ends) to a
-- consistent 2. Same 2 tiles everywhere, measured off the body you can see.
local MOUNT_REACH    = 2.0   -- tiles from the loco's hull within which E boards it
local DISMOUNT_SIDE  = 2.0   -- tiles: how far to the side of the loco to place the body
local BOARDING_SPEED = 5 / 3.6  -- m/s: do not board or step off above 5 km/h
local DISMOUNT_SPEED = BOARDING_SPEED
local DRIVER_DISMOUNT_SPEED = 0.05

--------------------------------------------------------------------------
-- placePlayerBeside: after leaving the cab, set the player down a little to the
-- SIDE of the loco (by the door), always on the CAMERA-FACING side so the body
-- isn't drawn behind the hood. PZ's iso projection puts screen-down at larger
-- (x+y), so of the two perpendiculars to the travel direction we pick the one
-- whose (x+y) is positive -- that points toward the viewer (bottom of screen).
--------------------------------------------------------------------------
local function placePlayerBeside(e)
    local p = getPlayer()
    local pose = e and e.lastPose
    if not p or not pose then return end

    -- unit travel direction (fall back to +Y if degenerate)
    local dx, dy = pose.dirX or 0, pose.dirY or 0
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1e-4 then dx, dy, len = 0, 1, 1 end
    dx, dy = dx / len, dy / len

    -- perpendicular to travel; flip to the viewer side (px+py > 0 = toward camera)
    local px, py = -dy, dx
    if (px + py) < 0 then px, py = -px, -py end

    -- Step off beside the CAB DOOR: shift the base point down the body by the seat's
    -- longitudinal offset (same end the driver rode), then out to the side.
    local su = (seatOffsets(e) or {}).u or 0
    local bx = pose.x + su * dx
    local by = pose.y + su * dy

    local tx = bx + px * DISMOUNT_SIDE
    local ty = by + py * DISMOUNT_SIDE
    local tz = pose.z or 0

    p:setX(tx); p:setY(ty); p:setZ(tz)
    pcall(function() p:setLastX(tx); p:setLastY(ty) end)  -- no visual slide from the seat
    pcall(function() p:setForwardDirection(-px, -py) end)  -- turn to face the loco
    pcall(function() p:ensureOnTile() end)                 -- settle onto the square
end

--------------------------------------------------------------------------
-- mountRecord: seat the player onto a SPECIFIC active entity record and take its
-- controls. Shared by mountNearest (L key) and the reload auto-remount
-- (RR_TrainEntity.adoptAnimal, when the loco was saved with a rider aboard).
-- Sets e.rider = true so stashState persists the seated state into modData.
--------------------------------------------------------------------------
function Ride.mountRecord(e, quiet, seat)
    local p = getPlayer()
    if not p or not e or not e.animal then return end
    Ride.current = e
    e.seat = seat or 0
    e.passenger = e.seat > 0
    e.rider = true                                          -- persisted via stashState -> modData (Task 1.G)
    pcall(function() p:setBlockMovement(true) end)          -- freeze walking input
    pcall(function() p:setCanShout(false) end)              -- Q = horn in the cab, not the vanilla yell
    -- Seated benefit: the driver is resting in his seat. B42 keys the "sitting" stat
    -- bonus off isResting() (the flag ISRestAction uses) -- 5x endurance regen
    -- (ZomboidGlobals.sittingEnduranceMultiplier) + ~1.5x slower fatigue accrual,
    -- applied by IsoPlayer.updateEndurance/updateStats_Awake. A pure bool -> no anim,
    -- so it doesn't fight the standing pin. The vanilla in-vehicle path is unreachable
    -- (it's gated on getVehicle()~=nil and !isAnimal(); our loco is an IsoAnimal).
    pcall(function() p:setIsResting(true) end)
    -- Shelter (Task 1.P): the cab has a roof. isResting above is HALF of vanilla's
    -- tent test -- RR_CabClimate supplies the other half (the "Shelter" bed marker),
    -- and together they stop the rain wetting the driver and let his clothes dry.
    -- Warmth is a separate channel entirely (a heat source on the cab tile, driven
    -- from RR_TrainEntity); see the RR_CabClimate header.
    if RR.CabClimate then pcall(function() RR.CabClimate.assertShelter(p) end) end
    -- Holding Q for a long horn otherwise pops the vanilla gesture radial menu (bound
    -- to "Emote"); its own guard only skips inside a real vehicle, not our animal-loco.
    -- Temporarily unbind "Emote" while seated (restored on dismount) so a long horn
    -- doesn't open it. (Mirrors how the vanilla tutorial rebinds "Shout".)
    pcall(function()
        Ride.savedEmoteKey = getCore():getKey("Emote")
        getCore():addKeyBinding("Emote", 0, 0, false, false, false)  -- B42: addKeyBinding takes 6 args
    end)
    pcall(function() e.animal:setCollidable(false) end)     -- stop separate() shove
    -- Snap the player onto the seat immediately so a reload remount doesn't leave
    -- them a frame adrift (onTick re-pins every frame after this).
    local pose = e.lastPose
    if pose then
        local sx, sy, sz = seatWorld(e, pose)
        p:setX(sx); p:setY(sy); p:setZ(sz)
        -- Facing along the rails the way the reverser points -- boarding a loco that was
        -- saved in REVERSE must not show one frame of the driver looking the wrong way.
        local fx, fy = travelFacing(e, pose)
        pcall(function() p:setForwardDirection(fx, fy) end)
    end
    -- Licence (Task 1.F): re-read it for whoever just climbed in. Boarding is NOT
    -- gated -- anyone can sit in the cab and look at the controls; only working them
    -- is. That reads friendlier than a silent "E does nothing" at the door, and the
    -- cab itself explains the rule (HUD + console tell you what you're missing).
    e.licensed = nil
    local licensed = Ride.isLicensed(e)

    if not quiet then
        if not licensed then
            sayBad("IGUI_RR_NoLicense", "You don't know how to run a locomotive")
            print("[Railroader] IN THE CAB -- but you don't know how to run a locomotive. "
                  .. "The controls mean nothing to you. (Railroader profession required.)")
        else
            local off = e.engine and Engine and not e.engine.running
            if off then
                print("[Railroader] IN THE CAB. Engine OFF -- reverser to N, then HOLD W to start. Space=brake  E=leave.")
            else
                print("[Railroader] IN THE CAB. W/S=throttle  R=reverser(F/N/R)  Space=brake  hold S(idle)=stop engine  E=leave.")
            end
        end
    else
        -- v1.0.17: this quiet-mount message also fires on EVERY normal MP board
        -- confirmation (apply() -> mountRecord(quiet=true)); the old wording
        -- ("was riding at save") made the log look like the player had never
        -- actually got off. Say what it really is.
        print(string.format("[Railroader] server confirmed seat %s (in the cab).",
            (seat and seat > 0) and ("passenger " .. tostring(seat)) or "driver"))
    end
end

--------------------------------------------------------------------------
-- mountNearest: grab the closest spawned rail entity and take its controls.
-- Does NOT depart -- you drive it (set reverser Forward, notch up).
--   maxDist (tiles, optional): only board if a loco is within this range OF ITS HULL
--     (RR.Body.hullDistance -- 0 while you stand on the body itself), and stay
--     SILENT when nothing is close enough -- lets the E key fall through to vanilla
--     interaction when the player isn't by a loco. K/debug callers pass no maxDist =
--     board the nearest loco anywhere.
-- Returns true if it boarded.
--------------------------------------------------------------------------
-- Distance (tiles) from the player to a loco record's DRAWN HULL. The pose is the one
-- RR_TrainEntity applied this tick (rec.lastPose, calibration included), so the box is
-- where the model is. A record without a pose yet (spawned this frame) falls back to
-- centre distance less the hull half-length -- an under-estimate of the true gap in the
-- worst case (off a corner), never a bigger reach than the ends already have.
local function hullDistTo(p, e)
    if not e.animal then return nil end
    local dx = e.animal:getX() - p:getX()
    local dy = e.animal:getY() - p:getY()
    local size = 0.7
    pcall(function() size = e.animal:getAnimalSize() end)
    if e.lastPose and RR.Body and RR.Body.hullDistance then
        return (RR.Body.hullDistance(e.lastPose, size, p:getX(), p:getY()))
    end
    local d = math.sqrt(dx * dx + dy * dy)
    local half = 0
    if RR.Body and RR.Body.hullExtents then half = RR.Body.hullExtents(size) * 0.5 end
    return math.max(0, d - half)
end

function Ride.mountNearest(maxDist)
    local p = getPlayer()
    if not p then return false end
    local active = RR.TrainEntity and RR.TrainEntity.active or {}
    local best, bestDist
    for _, e in ipairs(active) do
        local d = hullDistTo(p, e)
        if d and (not bestDist or d < bestDist) then best, bestDist = e, d end
    end
    if not best then
        if not maxDist then print("[Railroader] no rail entity to mount (press O to spawn one first)") end
        if maxDist then
            dbg("E: no loco in reach -- active records=%d", #active)
        end
        return false
    end
    if maxDist and bestDist > maxDist then
        dbg("E: loco hull %.2f tiles away (reach %.1f)", bestDist, maxDist)
        return false   -- loco too far: let E do its vanilla job
    end
    if best.derailed then
        print("[Railroader] this locomotive is derailed -- it can't be boarded. (Admin: right-click the wreck -> Put it back on the rails, or server console RR.ServerTrain.debugRerail().)")
        return false
    end
    if math.abs((best.drive and best.drive.v) or 0) > BOARDING_SPEED then
        dbg("E: loco moving %.2f m/s -- slow below 5 km/h before boarding.", math.abs((best.drive and best.drive.v) or 0))
        return false
    end
    if RR.MPClient then
        -- v1.0.11 (seat race): mark the explicit board intent so RR_MPClient's
        -- auto-mount grace (which suppresses a STALE pre-release packet that
        -- re-seats the player right after a manual dismount) still honours a
        -- genuine re-board confirmation.
        best._boardPending = true
        Ride._boardAt = nowMs()
        RR.MPClient.board(best)
        return true
    end
    Ride.mountRecord(best)
    return true
end

--------------------------------------------------------------------------
-- dismount: hand control back to the player. Idle the throttle so the loco can't
-- run away unattended and release the brake the instant you step off -- the brake
-- is only held as part of the "stop a rolling loco, then step off" sequence
-- (requestDismount + onTick), so once the player is off, it comes back off (a
-- parked loco with throttle 0 stays put on its own resistance). The player is set
-- down beside the cab door on the camera-facing side (placePlayerBeside).
--------------------------------------------------------------------------
function Ride.dismount(skipRelease)
    local e = Ride.current
    local p = getPlayer()
    if p then
        pcall(function() p:setBlockMovement(false) end)
        pcall(function() p:setCanShout(true) end)          -- restore the vanilla yell
        pcall(function() p:setIsResting(false) end)        -- end the seated rest bonus on step-off
        -- Off the loco = back out in the weather, the same tick (Task 1.P).
        if RR.CabClimate then pcall(function() RR.CabClimate.clearShelter(p) end) end
        pcall(function()                                    -- restore the gesture radial ("Emote") key
            if Ride.savedEmoteKey ~= nil then
                getCore():addKeyBinding("Emote", Ride.savedEmoteKey, 0, false, false, false)
                Ride.savedEmoteKey = nil
            end
        end)
    end
    if e then
        e.throttle   = 0         -- no drive force -> parked loco stays put (reverser kept)
        e.brakeInput = 0         -- release the brake as soon as we're off (it only held to stop us)
        if RR.MPClient and e.id and not skipRelease then
            sendClientCommand(getPlayer(), "RailroaderMP", "release", { id = e.id })
        end
        e.rider      = false     -- clear persisted seated state (won't re-seat on reload)
        e.licensed   = nil       -- cab empty: re-read the licence for the next driver
        e._licGate   = nil
        -- v1.0.11 (seat race + phantom engine toggles): drop the start/stop
        -- latches on step-off -- a stale auto-remount must not re-send a held
        -- W/S as control commands that flip the server engine (each flip played
        -- the catch/stop one-shot again -- the "engine-off sound keeps playing
        -- after getting off" report). Stamp the dismount time so RR_MPClient can
        -- suppress a stale pre-release packet that would re-seat the player.
        e._starting, e._stopping = nil, nil
        e._startTries, e._stopTries = nil, nil
        e._boardPending = nil
        if getTimestampMs then
            pcall(function() e._dismountAt = getTimestampMs() end)
        end
        if e.animal then
            pcall(function() e.animal:setCollidable(true) end)
        end
    end
    -- Clear the seat BEFORE repositioning so onTick stops re-pinning the player onto
    -- the loco, then step them off to the side (uses e.lastPose, still valid here).
    Ride.pendingDismount = false
    Ride._boardAt = nil
    Ride.current = nil
    if e then placePlayerBeside(e) end
    print("[Railroader] stepped off beside the loco." .. (skipRelease and " [auto: server seat cleared]" or ""))
end

--------------------------------------------------------------------------
-- requestDismount: the E key while seated. Stopped -> step off now. Rolling ->
-- cut throttle + full brake and defer the step-off to onTick, which fires it the
-- moment the loco falls under DISMOUNT_SPEED. Mirrors leaving a moving car.
--------------------------------------------------------------------------
function Ride.requestDismount()
    local e = Ride.current
    if not e then return end
    local speed = math.abs((e.drive and e.drive.v) or 0)
    if not e.passenger and speed > DRIVER_DISMOUNT_SPEED then
        print("[Railroader] stop before leaving the driver seat.")
        return
    end
    if speed > DISMOUNT_SPEED then
        if not e.passenger then
            e.throttle = 0
            e.brakeInput = 1
        end
        Ride.pendingDismount = true
        print("[Railroader] E: braking to a stop, then stepping off...")
    else
        Ride.dismount()
    end
end

--------------------------------------------------------------------------
-- toggle: the E key. On foot near a loco -> board; seated -> leave.
--------------------------------------------------------------------------
function Ride.toggle()
    -- v1.0.12 (board lock): swallow E for BOARD_LOCK_MS after a board request.
    -- The MP mount is confirmed on the server round-trip (~100 ms), so a second
    -- tap right after the first used to board then instantly alight (the field
    -- log shows "re-seated" -> "stepped off" 0.1-1 s apart). Applies to both
    -- branches: a second tap must neither re-send the board nor undo it.
    local now = nowMs()
    if Ride._boardAt and now and (now - Ride._boardAt) < BOARD_LOCK_MS then
        dbg("E swallowed (board in flight)")
        return
    end
    if Ride.current then
        dbg("E: requestDismount (seated)")
        Ride.requestDismount()
    else
        dbg("E: mountNearest")
        Ride.mountNearest(MOUNT_REACH)
    end
end

--------------------------------------------------------------------------
-- Reverser cycle F(+1) -> N(0) -> R(-1) -> F. Gated to a near-standstill.
--------------------------------------------------------------------------
local function cycleReverser(e)
    local speed = math.abs((e.drive and e.drive.v) or 0)
    if speed > REVERSE_GATE then
        print("[Railroader] stop before changing the reverser (still rolling).")
        return
    end
    -- The order itself is a RULE, so it lives in the pure module where it can be
    -- tested: N -> F -> R -> N, and see Drive.nextReverser for why it is not the
    -- lever's own sweep. The panel keeps the real F - N - R legend order.
    local r = Drive.nextReverser(e.reverser)
    e.reverser = r
    print("[Railroader] reverser -> " .. (Drive and Drive.reverserLabel(r) or tostring(r)))
end

--------------------------------------------------------------------------
-- Look-at-cursor while seated. Hold the look button (default RMB, matching vanilla
-- free-look) to turn the driver's facing -- and with it the VISION CONE, which reads
-- the AnimationPlayer angle = getLookAngleRadians() -- toward the mouse cursor. Our
-- setBlockMovement(true) otherwise disables this (the engine skips input-driven turning
-- while movement is blocked -- IsoPlayer.java:6310), so we drive the facing ourselves.
-- Released -> face along the rails (travel direction). Set LOOK_HOLD_LMB=true for LMB.
--------------------------------------------------------------------------
local LOOK_HOLD_LMB = false  -- false = hold Right Mouse to look at the cursor (matches vanilla free-look); true = Left Mouse
local LOOK_MIN_DIST = 0.25   -- tiles: ignore a cursor sitting on the seat (avoids jittery facing)

--------------------------------------------------------------------------
-- lookFacing: the unit facing the seated driver should use THIS frame. While the
-- look button is held, points from the seat toward the world tile under the cursor
-- (screenToIso at the player's Z -- the vanilla mouse->world pattern, DiggingUtil.lua);
-- otherwise (and on any failure/degenerate vector) falls back to the travel heading.
--------------------------------------------------------------------------
local function lookFacing(p, e, pose)
    -- The cab radial menu (RR_CabMenu, V) is picked with the mouse: while it is up, a
    -- held button is aiming at a SLICE, not at the world, so the driver must not swing
    -- around with it. Face along the rails until the menu closes.
    if RR.CabMenu and RR.CabMenu.radialVisible() then return travelFacing(e, pose) end
    local holding = false
    pcall(function()
        if LOOK_HOLD_LMB then holding = Mouse.isLeftDown() else holding = Mouse.isRightDown() end
    end)
    if holding then
        local dx, dy
        local ok = pcall(function()
            local idx = p:getIndex()
            local mx = screenToIsoX(idx, getMouseX(), getMouseY(), p:getZ())
            local my = screenToIsoY(idx, getMouseX(), getMouseY(), p:getZ())
            dx, dy = mx - p:getX(), my - p:getY()
        end)
        if ok and dx then
            local len = math.sqrt(dx * dx + dy * dy)
            if len > LOOK_MIN_DIST then return dx / len, dy / len end
        end
    end
    return travelFacing(e, pose)
end

--------------------------------------------------------------------------
-- pinRider: snap the seated player onto the entity's current pose (+ re-assert the
-- movement/shout locks). Called from RR_TrainEntity.onTick THIS frame, right after
-- the loco pose is computed -- NOT from Ride.onTick. Reason: the camera tracks the
-- player's instantaneous getX() (IsoCamera), and the loco body also renders at its
-- instantaneous getX(); if we pinned the player in a separate OnTick handler that
-- runs BEFORE the loco advances (alphabetical load: RR_Ride < RR_TrainEntity), the
-- camera sat one frame behind the loco. That gap = v*dt, and since dt jitters frame
-- to frame, the loco visibly shuddered along the travel axis -- worse at speed
-- (bigger v*dt) and when zoomed out (lower/noisier FPS, small loco vs lots of
-- ground). Pinning after the pose in the same frame makes camera == loco == same
-- pose, so the loco is rock-steady relative to the camera.
--------------------------------------------------------------------------
function Ride.pinRider(e)
    local p = getPlayer()
    if not p or not e or not e.animal then return end
    -- Prefer the pose applied THIS rendered frame (RR_MPClient.onRender writes
    -- rec.renderPose); fall back to the last tick's logic pose for SP/host.
    local pose = e.renderPose or e.lastPose
    if pose then
        local sx, sy, sz = seatWorld(e, pose)
        p:setX(sx); p:setY(sy); p:setZ(sz)
        -- Facing = cursor while the look button is held, else the travel heading.
        -- Do not force an AnimationPlayer transition on a movement-blocked player:
        -- B42's player animset has no turning180 state in this path.
        local fx, fy = lookFacing(p, e, pose)
        pcall(function() p:setForwardDirection(fx, fy) end)
    end
    pcall(function() p:setBlockMovement(true) end)   -- re-assert; some systems clear it
    pcall(function() p:setCanShout(false) end)       -- keep the yell muted while seated (Q=horn)
    pcall(function() p:setIsResting(true) end)       -- re-assert seated rest bonus (resetResting() can clear it)
    -- Re-assert the shelter marker too (Task 1.P): setBed is a bare field write, so
    -- re-stating it every tick is cheaper than reading it back, and it means nothing
    -- else that touches the bed field can quietly put the driver back out in the rain.
    if RR.CabClimate then pcall(function() RR.CabClimate.assertShelter(p) end) end
end

--------------------------------------------------------------------------
-- Seconds this tick (frame-rate independent), mirroring RR_TrainEntity's motion
-- step so the prime/crank/shutdown HOLD timers advance at the same real rate as the
-- physics -- capped (Drive.dtSim), because these are HELD-KEY timers: one 0.7 s
-- fast-forward tick must not swallow a whole 1.6 s crank.
--------------------------------------------------------------------------
local function dtNow()
    local mult = 0.8
    if getGameTime then pcall(function() mult = getGameTime():getMultiplier() end) end
    if Drive and Drive.dtSim then return Drive.dtSim(mult) end
    return mult / ((Drive and Drive.C and Drive.C.DT_PER_MULT) or 48)
end

--------------------------------------------------------------------------
-- FAST-FORWARD INTERLOCK -- the same contract vanilla gives a car driver.
--
-- PZ does not grey out the speed buttons when you get in a car: it lets you press
-- them and then snaps the speed back to 1 from the vehicle's own controller, every
-- frame the driver applies gas / reverse / brake (CarController.java:258 ->
-- UIManager.speedControls.SetCurrentGameSpeed(1); SetCurrentGameSpeed also resets
-- the GameTime multiplier). Parked with your hands off the controls, fast-forward
-- works fine -- that is how you wait in a car.
--
-- None of that machinery reaches us: our loco is an IsoAnimal, there is no
-- CarController, and a seated rider has setBlockMovement(true) so IsoPlayer's own
-- isJustMoved() kick-back never fires either. So we reproduce the rule here: rolling,
-- or a hand on the throttle / brake / starter (Drive.needsRealtime) => back to 1x.
-- Parked and idle => fast-forward from the cab stays legal.
--
-- getGameSpeed()/setGameSpeed() are the vanilla Lua globals (LuaManager -> SpeedControls);
-- in MP getCurrentGameSpeed() hard-returns 1, so this is a no-op there.
--------------------------------------------------------------------------
local function holdRealtime(e)
    local eng = e.engine
    -- Phase-driven, not key-driven -- which is what lets the start sequence run on
    -- its own after a tap of W. `warmup` counts too: it is a 4 s timer, and letting
    -- x40 skip it would hand the player a free instant start.
    -- `not eng.running` first: once the diesel is alive there is no starter to hold, so
    -- no start-sequence timer may pin a parked, idling loco to 1x. (It did: tryStart
    -- consumed the crank timer but left primeTime standing, and this test read that as
    -- a hand on the starter forever after the first successful start.)
    local cranking = (eng ~= nil) and (not eng.running)
                     and (eng.phase == "priming" or eng.phase == "cranking"
                          or (eng.crankTime or 0) > 0 or (eng.primeTime or 0) > 0)
    -- Warm-up is the one RUNNING phase that still blocks it: a 4 s timer x40 would hand
    -- the player a free instant start.
    if eng ~= nil and eng.phase == "warmup" then cranking = true end
    local controls = { throttle = e.throttle, brakeInput = e.brakeInput, cranking = cranking }
    if not Drive.needsRealtime(e.drive, controls) then return end

    -- No de-dupe flag needed: we snap the speed to 1 on the very tick it goes up, so
    -- the >1 test is naturally edge-triggered -- it can only be true again if the
    -- player pressed a speed key again, which deserves the message again.
    pcall(function()
        if getGameSpeed and getGameSpeed() > 1 then
            setGameSpeed(1)                      -- also resets the GameTime multiplier
            sayBad("IGUI_RR_NoFastForward", "You can't fast-forward while driving")
            -- Say WHICH control is holding it. A parked, idle-looking cab that still
            -- refuses to fast-forward is indistinguishable from a broken interlock (it
            -- happened in the 20:12 field log: ~20 refusals at speed 0.0 / notch 0),
            -- and only the four inputs below can be responsible.
            local why = {}
            local v = math.abs((e.drive and e.drive.v) or 0)
            if v > (Drive.C.V_IDLE or 0.05) then why[#why + 1] = string.format("rolling (%.3f m/s)", v) end
            if (e.throttle or 0) ~= 0   then why[#why + 1] = "throttle at notch " .. tostring(e.throttle) end
            if (e.brakeInput or 0) ~= 0 then why[#why + 1] = "brake applied (Space held)" end
            if cranking                 then why[#why + 1] = "start sequence running (" .. tostring(eng and eng.phase) .. ")" end
            print("[Railroader] fast-forward cancelled -- " .. table.concat(why, " + ")
                  .. ". Stop the loco and let go of the controls to skip time from the cab.")
        end
    end)
end

--------------------------------------------------------------------------
-- Engine start/stop controls for the seated driver (engine-start mechanic):
--   * Engine OFF: HOLD W to crank. Gated by reverser-in-Neutral + a live battery;
--     after CRANK_TIME of continuous cranking a catch is rolled against
--     Engine.startChance (battery/cold/wet/condition). Success -> warm-up; failure
--     -> keep cranking (battery keeps draining -> eventually a flat "click"). No
--     fuel = it cranks but never fires.
--   * Engine RUNNING: HOLD S with the throttle at idle (notch 0) to shut down.
-- Both are POLLED (isKeyDown) like the air brake -- OnKey* events only fire on edges.
-- Console hints are de-duped via e._crankGate so a held key doesn't spam the log.
--------------------------------------------------------------------------
local function updateEngineControls(e, dt)
    local eng = e.engine
    if not eng or not Engine then return end
    -- Derailed (Task 1.N step 6): the loco is off the rails and terminal -- the starter,
    -- shutdown and everything else are dead. Nothing to crank; just refuse silently.
    if e.derailed then return end

    -- Licence gate (Task 1.F): an unlicensed driver can sit here all day. The starter
    -- never turns (so no battery is wasted proving it) and the throttle makes no power
    -- (clamped to notch 0 in RR_TrainEntity via Engine.maxNotch(eng, env)). The brake
    -- still works -- a runaway you can't stop would be a cruel bug, not a rule.
    if not Ride.isLicensed(e) then
        if e._licGate ~= true then
            sayBad("IGUI_RR_NoLicense", "You don't know how to run a locomotive")
            print("[Railroader] you don't know how to operate a locomotive -- "
                  .. "the Railroader profession is required to start and drive it.")
            e._licGate = true
        end
        return
    end
    e._licGate = nil

    if eng.running then
        -- Shut down. A TAP of S latches the sequence and it runs itself; a second tap
        -- aborts. Gated on a STOPPED loco at idle, which is what makes the tap safe:
        -- coming down from Run 8 is a burst of S presses, and without the stop gate the
        -- last one would kill the diesel by accident. The hold used to protect against
        -- that; the gate does now, and the radial covers the rare "shut down while
        -- rolling" case.
        if e._stopping then
            e._shutdownHold = (e._shutdownHold or 0) + dt
            if e._shutdownHold >= SHUTDOWN_HOLD then
                Engine.stop(eng)
                if RR.Sound and RR.Sound.engineStop then pcall(function() RR.Sound.engineStop(e) end) end
                e._shutdownHold, e._stopping = 0, nil
                print("[Railroader] engine SHUT DOWN.")
            end
        else
            e._shutdownHold = 0
        end
        e._crankGate = nil
        return
    end

    -- Engine off. The start sequence is LATCHED (e._starting), set by a tap of W or by
    -- the cab radial -- it is not polled from the key any more. Holding a key through a
    -- multi-second sequence the player cannot influence taught nothing and read as
    -- "W does nothing"; a tap is what everyone tries first.
    if not e._starting then
        if (eng.crankTime or 0) > 0 or (eng.primeTime or 0) > 0
           or eng.phase == "cranking" or eng.phase == "priming" then
            -- Aborted mid-sequence: stop the noise but KEEP the prime, so the next
            -- attempt goes straight to the starter (a primed system stays primed).
            eng.phase = "off"
            if RR.Sound and RR.Sound.crankStop then pcall(function() RR.Sound.crankStop(e) end) end
            if RR.Sound and RR.Sound.primeStop then pcall(function() RR.Sound.primeStop(e) end) end
        end
        e._crankGate = nil
        return
    end

    -- Refusals. Each one ends the attempt: with a tap there is no held key to keep
    -- retrying against, so a refusal has to be terminal and say why exactly once.
    local why = Ride.startRefusal(e)
    if why then
        sayBad(why, "The starter won't turn")
        print("[Railroader] start refused: " .. tostring(why))
        if why == "IGUI_RR_BatteryFlat" and RR.Sound and RR.Sound.engineFail then
            pcall(function() RR.Sound.engineFail(e) end)
        end
        e._starting = nil
        return
    end

    -- FUEL PRIME first (real EMD sequence): the electric fuel pump hums for PRIME_TIME
    -- and only THEN does the starter engage.
    if not Engine.primeReady(eng) then
        Engine.primeTick(eng, dt)
        if RR.Sound and RR.Sound.primeStart then pcall(function() RR.Sound.primeStart(e) end) end
        if e._crankGate ~= "prime" then
            print("[Railroader] FUEL PRIME -- fuel pump priming...")
            e._crankGate = "prime"
        end
        return
    end
    if RR.Sound and RR.Sound.primeStop then pcall(function() RR.Sound.primeStop(e) end) end
    if e._crankGate == "prime" then
        print("[Railroader] ENGINE START -- cranking...")
        e._crankGate = nil
    end

    -- Turn the starter this tick (drains battery, accrues crank time) + loop sound.
    Engine.crankTick(eng, dt)
    if RR.Sound and RR.Sound.crankStart then pcall(function() RR.Sound.crankStart(e) end) end

    if Engine.crankReady(eng) then
        local roll = 0.5
        pcall(function() roll = ZombRandFloat(0.0, 1.0) end)
        local res = Engine.tryStart(eng, startEnv(e), roll)
        -- One tap = one attempt, whatever the outcome. That keeps the cost of a start
        -- countable (each attempt drains the battery) instead of a held key quietly
        -- burning the bank, and it gives the player a beat to read what happened.
        e._starting = nil
        if RR.Sound and RR.Sound.crankStop then pcall(function() RR.Sound.crankStop(e) end) end
        if res == "started" then
            if RR.Sound and RR.Sound.engineCatch then pcall(function() RR.Sound.engineCatch(e) end) end
            print("[Railroader] engine STARTED -- warming up. R=reverser, then W=throttle.")
        elseif res == "nofuel" then
            sayBad("IGUI_RR_NoFuel", "No fuel -- the engine won't fire")
            print("[Railroader] cranking... no fuel -- engine won't fire.")
        elseif res == "flat" then
            sayBad("IGUI_RR_BatteryFlat", "The battery is flat")
            print("[Railroader] battery flat -- starter won't turn.")
        else
            -- The prime survives, so the next tap goes straight to the starter.
            print("[Railroader] engine didn't catch -- press W to try again.")
        end
    end
end

--------------------------------------------------------------------------
-- Public start/stop. Shared by the W/S keys and by the cab radial menu, so the
-- two can never drift apart on what is allowed.
--
-- startRefusal(e) -> nil if the starter may turn, else the getText key saying why.
-- The radial uses it to label a dead slice; the key handler uses it for a halo.
--------------------------------------------------------------------------
function Ride.startRefusal(e)
    local eng = e and e.engine
    if not eng or not Engine then return "IGUI_RR_NoLicense" end
    if e.derailed then return "IGUI_RR_Derailed" end
    if not Ride.isLicensed(e) then return "IGUI_RR_NoLicense" end
    -- IMMOBILIZATION (Task 1.N step 5): condition 0 = OUT OF ORDER -- the starter
    -- must not turn (startChance is 0 anyway). Refuse up-front so W and the cab
    -- radial both say why instead of cranking a dead loco.
    if (eng.condition or 1) <= (Engine.C and Engine.C.IMMOBILIZE_AT or 0) then
        return "IGUI_RR_OutOfOrder"
    end
    if (e._restartCooldown or 0) > 0 then return "IGUI_RR_Cooling" end
    if (e.reverser or 0) ~= 0 then return "IGUI_RR_ReverserNeutral" end
    if (eng.fuel or 0) <= 0 then return "IGUI_RR_NoFuel" end
    if not Engine.canCrank(eng, startEnv(e)) then return "IGUI_RR_BatteryFlat" end
    return nil
end

function Ride.canStop(e)
    local eng = e and e.engine
    if not eng or not eng.running then return false end
    if (e.throttle or 0) ~= 0 then return false end
    return math.abs((e.drive and e.drive.v) or 0) <= 0.05
end

-- startEngine(e): latch an attempt. A second call while one is running aborts it.
function Ride.startEngine(e)
    e = e or Ride.current
    local eng = e and e.engine
    if not eng or eng.running then return false end
    if e._starting then e._starting = nil; return false end
    local why = Ride.startRefusal(e)
    if why then
        sayBad(why, "The starter won't turn")
        return false
    end
    e._starting = true
    print("[Railroader] starter engaged.")
    return true
end

function Ride.stopEngine(e)
    e = e or Ride.current
    if not e then return false end
    if e._stopping then e._stopping = nil; return false end
    if not Ride.canStop(e) then return false end
    e._stopping = true
    return true
end

--------------------------------------------------------------------------
-- Per-tick: poll the held brake, handle the pending step-off, and print a throttled
-- HUD. The POSITION pin lives in Ride.pinRider (driven from RR_TrainEntity.onTick,
-- same frame as the loco pose -- see pinRider for why). e.lastPose is written there
-- (already world-offset applied).
--------------------------------------------------------------------------
local function onTick()
    if RR.MP and RR.MP.blocked() and not RR.MPClient then return end
    local e = Ride.current
    if not e then return end
    local p = getPlayer()
    if not p or not e.animal then Ride.dismount(); return end
    -- v1.0.13 (MP health desync): the server owns life/death (the loco is
    -- invincible there). The client's replicated animal can transiently report
    -- isDead() from a stale health sync, which used to auto-dismount the player
    -- right after every board. Only trust the death check in SP (no MPClient).
    if e.animal:isDead() and not RR.MPClient then Ride.dismount(); return end

    -- In MP, RR_MPClient applies the server snapshot and owns the rider pin. Do
    -- not advance a second local engine/control state machine against that state.
    if RR.MPClient then
        if Ride.pendingDismount
           and math.abs((e.drive and e.drive.v) or 0) <= DISMOUNT_SPEED then
            Ride.dismount()
        end
        return
    end

    -- ASLEEP IN THE CAB (RR_Sleep): the driver is aboard but out cold. Two things must
    -- stop, and both would otherwise be silent bugs:
    --   * the control polls below (Space / hold-W / hold-S are isKeyDown, not edges) --
    --     a key still down as the screen faded would go on cranking the starter or
    --     holding the brake for the whole night;
    --   * holdRealtime -- sleep runs the world at speed 3, and our fast-forward
    --     interlock would snap it back to 1x every tick, so the night would pass in
    --     real time. Skipping it entirely is safe here: nothing is driving.
    -- The pose pin stays (it lives in RR_TrainEntity.onTick -> pinRider), so the sleeper
    -- keeps his seat. Controls are left at rest rather than merely unread.
    if RR.Sleep and RR.Sleep.isAsleep() then
        e.throttle   = 0
        e.brakeInput = 0
        return
    end

    -- Pending step-off (E pressed while rolling): keep throttle idle + full brake,
    -- overriding the held-Space poll, and step off once we're under DISMOUNT_SPEED.
    if Ride.pendingDismount then
        e.throttle   = 0
        e.brakeInput = 1
        holdRealtime(e)       -- still rolling + full brake: no fast-forward through the stop
        if math.abs((e.drive and e.drive.v) or 0) <= DISMOUNT_SPEED then
            Ride.dismount()   -- clears pendingDismount + Ride.current, places the body
        end
        return
    end

    -- Derailed (Task 1.N step 6): terminal wreck -- don't poll the brake or any control. Leaving
    -- the poll active would re-apply a still-held Space into e.brakeInput every tick; since the
    -- driving pipeline (Drive.step) no longer runs to ramp it back down, the brake apply/squeal
    -- loop would then play forever. Keep the input at rest and skip the control section; the pose
    -- pin + HUD live in RR_TrainEntity.tickDerailed, and E-to-leave is on the key edge (onKeyDown).
    if e.derailed then
        e.brakeInput = 0
        return
    end

    -- Independent air brake = HOLD Space. Polled every tick (Keyboard.isKeyDown is
    -- the reliable held-state check; OnKey* events fire only on edges).
    -- (v1.0.1) Called direct, not through pcall: `pcall(function() ... end)` builds a fresh
    -- closure on EVERY tick, and Keyboard.isKeyDown cannot throw for a static key constant --
    -- this file already calls it bare at the Shift poll below, as does vanilla throughout.
    e.brakeInput = Keyboard.isKeyDown(Keyboard.KEY_SPACE) and 1 or 0

    -- Engine start/stop (hold W to crank when off, hold S at idle to shut down).
    updateEngineControls(e, dtNow())

    -- Fast-forward interlock (vanilla car parity): a rolling loco or a hand on the
    -- controls snaps the game back to 1x. Runs AFTER the inputs for this tick are in.
    holdRealtime(e)

    -- (v1.0.1) The once-a-second console HUD line was removed: it ran unconditionally for
    -- every second in the cab, formatting five numbers and a climate string into console.txt
    -- whether or not anyone was reading it. Everything it printed is on the control stand
    -- (Task 2.D) and, for the cab climate specifically, in RR.CabClimate.report().
end
Events.OnTick.Add(onTick)

--------------------------------------------------------------------------
-- Driving keys. Bound to OnKeyStartPressed -- it fires ONCE the moment a key
-- goes DOWN. (OnKeyPressed fires on key RELEASE in B42 -- verified in
-- GameKeyboard.java -- which is why an earlier build ignored held keys.)
-- Throttle/reverser are one step per press; the brake is held (polled in onTick).
--------------------------------------------------------------------------
local function onKeyDown(key)
    -- Asleep (RR_Sleep): swallow every cab key. Vanilla bails out of its own UI and
    -- interaction handlers on isAsleep() the same way (ISButtonPrompt, ISInventoryPane).
    if RR.Sleep and RR.Sleep.isAsleep() then return end
    if key == Keyboard.KEY_E then Ride.toggle();        return end   -- board / leave (vehicle-like)
    -- K = legacy "leave the cab NOW" (skips the stop-the-train courtesy E does). A dev
    -- escape hatch, gated: in the field a mis-hit K would drop the driver out of a moving
    -- locomotive. E is the player-facing way off.
    if key == Keyboard.KEY_K and RR.Debug and RR.Debug.isOn() then
        Ride.dismount(); return
    end
    -- (L was legacy debug-board; freed for the bell in RR_Sound. Board with E.)

    local e = Ride.current
    if not e then return end
    if e.passenger then return end

    -- LIGHTS (Task 1.K). F = the headlight's three-position switch, OFF -> DIM ->
    -- BRIGHT -> OFF; SHIFT+F = the cab dome light. Deliberately BEFORE the licence
    -- gate: flipping a light switch is not operating a locomotive, and a survivor who
    -- can't drive the thing should still be able to light the shed up with it.
    -- Which END the headlight burns on follows the reverser (RR_LightsRender.leadSign).
    if key == Keyboard.KEY_F then
        if not RR.LightsRender then return end
        local shift = false
        pcall(function()
            shift = Keyboard.isKeyDown(Keyboard.KEY_LSHIFT) or Keyboard.isKeyDown(Keyboard.KEY_RSHIFT)
        end)
        if shift then RR.LightsRender.toggleCab(e) else RR.LightsRender.cycleHead(e) end
        if RR.MPClient then RR.MPClient.sendControl(e) end
        return
    end

    -- Derailed (Task 1.N step 6): the loco is a terminal wreck -- throttle/reverser do nothing.
    -- (F for the lights is left above the gate, same as the licence rule; the headlight reads
    -- DEAD anyway with the engine off.)
    if e.derailed then return end
    -- No licence, no controls: swallow throttle/reverser edges entirely so the HUD
    -- can't show notches climbing on a loco that will never answer them.
    if not Ride.isLicensed(e) then
        sayBad("IGUI_RR_NoLicense", "You don't know how to run a locomotive")
        print("[Railroader] control refused: Railroader profession required.")
        return
    end
    -- With the engine OFF, W is the STARTER: a tap latches the sequence (prime ->
    -- crank -> catch roll) and it runs on its own; a second tap aborts. The throttle
    -- edge is swallowed while off so a tap cannot pre-load a notch that would lurch
    -- the moment the engine catches.
    local off = e.engine and Engine and not e.engine.running
    if key == Keyboard.KEY_W then
        if off then
            Ride.startEngine(e)
            if RR.MPClient then RR.MPClient.sendControl(e) end
            return
        end

        -- Reverser interlock. A real EMD control stand is mechanically interlocked:
        -- the throttle handle will not move with the reverser centred. Reproducing
        -- that is what stops the guaranteed first-drive trap -- the engine can only
        -- be started in NEUTRAL, so EVERY player arrives here, notches up and goes
        -- nowhere. Refusing the notch (rather than letting it climb against a dead
        -- drive) means the confusing state cannot be entered at all.
        --
        -- Silent while the on-panel hint is still teaching this, so the driver is not
        -- told off twice for one thing; once the hint has been retired, the halo is a
        -- useful reminder. See RR_HudModel.hint.
        if (e.reverser or 0) == 0 then
            if RR.HudHints and RR.HudHints.done("reverser") then
                sayBad("IGUI_RR_ReverserCentred", "Reverser is centred -- select F or R to move")
            end
            return
        end

        local before = e.throttle or 0
        e.throttle = math.min(8, before + 1)
        if e.throttle > before then
            print("[Railroader] throttle -> notch " .. e.throttle)
            -- Throttle-up stall (Task 1.N step 5): DEMANDING more power can kill a worn
            -- engine. Only below STALL_AT (healthy engines never roll this). On a stall the
            -- shared TrainEntity.stallEngine cuts power + sets the restart cool-down.
            local eng = e.engine
            if eng and eng.running and (eng.condition or 1) < Engine.C.STALL_AT then
                local pd   = Engine.stallChanceThrottleUp(eng.condition)
                local roll = 1
                pcall(function() roll = ZombRandFloat(0.0, 1.0) end)
                if pd > 0 and roll < pd and RR.TrainEntity and RR.TrainEntity.stallEngine then
                    RR.TrainEntity.stallEngine(e, "throttle-up")
                end
            end
        end
        if RR.MPClient then RR.MPClient.sendControl(e) end
    elseif key == Keyboard.KEY_S then
        if off then return end
        -- At idle AND stopped, S is the shutdown (a tap latches it). Everywhere else
        -- it is notch-down -- so a burst of S coming off Run 8 can never trip it.
        if (e.throttle or 0) == 0 then
            if Ride.canStop(e) then Ride.stopEngine(e) end
            return
        end
        e.throttle = math.max(0, (e.throttle or 0) - 1)
        print("[Railroader] throttle -> notch " .. e.throttle)
        if RR.MPClient then RR.MPClient.sendControl(e) end
    elseif key == Keyboard.KEY_R then
        cycleReverser(e)
        if RR.HudHints then RR.HudHints.markFromState(e) end
        if RR.MPClient then RR.MPClient.sendControl(e) end
    end
end
Events.OnKeyStartPressed.Add(onKeyDown)

--------------------------------------------------------------------------
-- F is DOUBLE-BOUND in vanilla (media/lua/shared/keyBinding.lua): it is both
-- "ToggleVehicleHeadlights" and "Equip/Turn On/Off Light Source". Which one you get
-- is decided in ItemBindingHandler.toggleLight -- it takes the headlight branch only
-- when playerObj:getVehicle() is a real BaseVehicle, and ours never is. So without
-- this patch, every press of F in our cab would ALSO strobe the flashlight in the
-- driver's hands, which is exactly the sort of thing that reads as a bug.
--
-- We take F for the locomotive ONLY while seated, and hand it straight back the
-- moment the driver steps off. Patched on OnGameStart, not at load: the vanilla
-- handler is a global that may not exist yet when this file runs.
--------------------------------------------------------------------------
local function claimLightKey()
    if RR.MP and RR.MP.blocked() and not RR.MPClient then return end
    if not ItemBindingHandler or ItemBindingHandler.rrPatched then return end
    local vanillaToggleLight = ItemBindingHandler.toggleLight
    ItemBindingHandler.toggleLight = function(key)
        if RR.Ride and RR.Ride.current then return end   -- in the cab: F is the loco's headlight
        return vanillaToggleLight(key)
    end
    ItemBindingHandler.rrPatched = true
end
Events.OnGameStart.Add(claimLightKey)

--------------------------------------------------------------------------
-- "WALK HERE" (Y) INTERLOCK -- disable the click-to-walk command while seated.
--
-- Pressing Y is the vanilla "WalkTo" binding: Java IsoPlayer.checkWalkTo() fires
-- the Lua event OnPressWalkTo, whose vanilla handler
-- (ISWorldObjectContextMenu.onWalkTo) opens a walk-to cursor and queues an
-- ISWalkToTimedAction. That is a PATHFINDING/timed-action route, NOT input-driven
-- walking, so our setBlockMovement(true) doesn't stop it -- the driver would path
-- straight out of the cab and off the moving loco.
--
-- Wrapping the global onWalkTo (the way we take the F key) would NOT work here:
-- Events.OnPressWalkTo.Add captured the function by VALUE at load, so the event
-- keeps calling the original even after a reassignment. Instead we REMOVE the
-- vanilla handler and register a guard that no-ops while seated (Ride.current set)
-- and otherwise passes straight through. Silent by design: checkWalkTo triggers the
-- event EVERY tick Y is held (isKeyDownInWorld == held, not an edge), so any halo/
-- print here would spam. Patched on OnGameStart so the vanilla handler is already
-- registered (and ISWorldObjectContextMenu.onWalkTo still holds its reference).
--------------------------------------------------------------------------
local function claimWalkToKey()
    if RR.MP and RR.MP.blocked() and not RR.MPClient then return end
    if not ISWorldObjectContextMenu or ISWorldObjectContextMenu.rrWalkToPatched then return end
    local vanillaOnWalkTo = ISWorldObjectContextMenu.onWalkTo
    if not vanillaOnWalkTo then return end
    local function guardedOnWalkTo(worldobjects, item, playerNum)
        if RR.Ride and RR.Ride.current then return end   -- in the cab: no "walk here"
        return vanillaOnWalkTo(worldobjects, item, playerNum)
    end
    pcall(function() Events.OnPressWalkTo.Remove(vanillaOnWalkTo) end)
    Events.OnPressWalkTo.Add(guardedOnWalkTo)
    ISWorldObjectContextMenu.rrWalkToPatched = true
end
Events.OnGameStart.Add(claimWalkToKey)

print("[Railroader] drive controls ready. E=board/leave (K debug leave) W/S=throttle R=reverser Space(hold)=brake F=headlight (Shift+F=cab light) RMB(hold)=look.")

RR = RR or {}
RR.Ride = Ride

return Ride
