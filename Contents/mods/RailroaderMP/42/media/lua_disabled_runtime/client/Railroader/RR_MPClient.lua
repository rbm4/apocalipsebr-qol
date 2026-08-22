--***********************************************************************
-- Railroader / RR_MPClient -- the connected-client snapshot bridge
--
-- Server authority (RR_ServerTrain) simulates on a fixed 1/60 s tick and
-- broadcasts a delta-encoded state stream at ~20 Hz (full+resync packets on
-- join / re-board / after the relevance quiet stretch), each stamped with the
-- server tick it was produced on. This module turns those snapshots into
-- smooth, rail-following motion:
--
--   * REMOTE locos: a small snapshot queue plays the PREVIOUS segment while the
--     newest waits (one segment of latency, absorbing network jitter). Between
--     the two bracketing snapshots the ROUTE DISTANCE is cubic-Hermite
--     interpolated with the endpoint speeds, and the pose is re-sampled from
--     the shared spline -- the body rides the rails (curves, 45deg kinks,
--     switch routes) exactly, instead of the old per-snapshot teleport and
--     straight-line drift. If the queue starves (packet loss) the loco HOLDS,
--     then extrapolates at its last speed for at most EXTRAP_CAP before
--     freezing -- it never jumps.
--     (Doc §3.2 Option A, v1.0.2 render mode: the visible body is the server's
--     authoritative animal -- a SINGLE entity, no local copy. The connected
--     client re-applies this interpolated pose to that same animal every render
--     frame (applyPoseLocal, a local-only smoothing write; the co-op host skips
--     it because its in-process server half already writes the live pose). The
--     same pose also feeds HUD / sound / lights / camera, and the periodic
--     reconcile re-bases it on authority if the local write ever drifts.)
--
--   * DRIVEN loco (Ride.current): client-side prediction -- the SAME shared
--     Drive.step is re-run on the record, so input response is instant and the
--     motion follows the route. Snapshots VALIDATE the prediction: small errors
--     blend over BLEND_TIME; a large divergence (RESYNC_DIST / RESYNC_V -- loss
--     gap, obstacle stop, derail, stall) triggers an AUTHORITATIVE ROLLBACK to
--     the server snapshot, bridging the RENDER pose at RESYNC_SPEED for at most
--     ROLLBACK_DUR_MAX (teleport beyond ROLLBACK_SNAP).
--
--   * LOSS: a starved remote buffer (RESYNC_STARVE) asks the server for its
--     retained authoritative snapshot ring (resync -> history) and replays the
--     gap on truth instead of extrapolating indefinitely.
--
--   * Poses are APPLIED on OnRenderTick (every rendered frame) with the rider
--     pinned in the same frame, so camera and body never desync; the logic pose
--     (e.lastPose) is still refreshed every OnTick for collider/sound/lights.
--
-- The through-route (switch graph) is rebuilt on the client with the SAME
-- shared TrackGraph code as the server whenever a switch command arrives, so
-- both sides measure `distance` on the identical parameterization; a
-- pose-vs-snapshot mismatch self-heals by re-anchoring (world-space lerp only
-- as a last resort).
--***********************************************************************
if not isClient() then return end

require("Railroader/RR_Routes")
require("Railroader/RR_Spline")
require("Railroader/RR_Body")
require("Railroader/RR_Drive")
require("Railroader/RR_Engine")
require("Railroader/RR_TrackGraph")
require("Railroader/RR_Lights")

local Client = { pending = {}, reserves = {} }

-- v1.0.18: debug logging OFF by default. RR.dbgLog = true (client or server
-- console) re-arms the [RailroaderMP-dbg] prints + the CLIENT heartbeat; with
-- it off, normal play logs only the mod's regular lifecycle lines.
RR.dbgLog = RR.dbgLog or false
local function dbg(fmt, ...)
    if RR.dbgLog then print(string.format("[RailroaderMP-dbg] " .. fmt, ...)) end
end

-- Interpolation tunables.
local INTERP_QUEUE_MAX  = 6      -- pending snapshots before dropping the oldest (burst catch-up)
local BLEND_TIME        = 0.2    -- s: driven-loco correction window (distance + speed)
local RESYNC_DIST       = 3.0    -- tiles: driven-loco distance error that forces a server resync
local RESYNC_V          = 2.0    -- m/s: driven-loco speed error that forces a server resync
local RESYNC_SPEED      = 25.0   -- tiles/s cap for visual recovery (rollback bridge / catch-up)
local ROLLBACK_DUR_MIN  = 0.08   -- s
local ROLLBACK_DUR_MAX  = 0.35   -- s
local ROLLBACK_SNAP     = 10.0   -- tiles: beyond this the rollback teleports instead of bridging
local HOLD_EXTRAP_DELAY = 0.1    -- s: buffer-starved grace before extrapolating
local EXTRAP_CAP        = 0.25   -- s: max capped extrapolation past the last snapshot
local LAG_CAP           = 0.12   -- s: max remote-render playout delay per segment (sparse bands)
local STALE_PRUNE_TICKS = 480    -- ~8 s without a snapshot: prune a stale remote record (sound-stacking fix)
local ROUTE_TOL         = 1.5    -- tiles: client-route vs snapshot pose mismatch -> reanchor
local RESYNC_STARVE     = 0.6    -- s: remote buffer starved this long -> fetch server history
local PRED_LOCK_TIME    = 1.5    -- s: hold client prediction after a rollback (released early when the server moves)
local SOUND_RANGE       = 200    -- tiles: run Sound.update up to the horn's max range (doc §7.1);
                                 -- per-class falloff inside RR_Sound (50/100/200 tiles)
local LIGHT_RANGE       = 70     -- tiles: observer renders remote headlights inside the mid band
local RENDER_RANGE      = 100    -- tiles: match the server's FAR band; beyond = no packets (doc §7 LOD)

local frameDt = 1 / 60           -- seconds since the last render frame (set in onRender)
local recAcc = 0                 -- periodic authoritative-render reconcile timer (v1.0.3f)

-- v1.0.16: client-relative tick counter (OnTick calls). Records stamp their own
-- "_lastSeen" with this. Do NOT compare it against the server's sim tick
-- (s.tick) -- the two clocks have different origins (the server's starts at
-- boot, this one at client load), so `ticks - _lastTick` was already > 8s the
-- moment any record was created, and the stale-prune deleted every record on
-- the next tick. E only worked in the same-frame window between apply() and
-- the prune -- the "you have to time E to a tick" symptom.
local clientTicks = 0

-- v1.0.3f: periodic full-authority render check. Every RECONCILE_EVERY seconds the
-- rendered model's position AND orientation are verified against the newest server
-- snapshot and re-based on it when they drifted -- heals the edge cases where the
-- server is normal but a client render got stuck (chunk re-stream, stale route
-- anchor, un-healed prediction). No-op while the render already matches, so correct
-- play never gets a periodic nudge (no jitter).
local RECONCILE_EVERY = 2.0    -- s
local RECONCILE_DIST  = 1.5    -- tiles: position error that heals
local RECONCILE_ANG   = 0.35   -- rad (~20 deg): orientation error that heals

function Client.sendControl(e)
    local player = getPlayer()
    if not (player and e and e.id) or e.passenger then return end
    -- Doc §4.1: every control command carries a client seq; the server echoes the
    -- last accepted seq in the state stream (lastCmdSeq) as the ack.
    -- v1.0.2 (rate-limit fix): the old code re-sent the SAME state every 3rd tick
    -- (~20/s) plus one command per W/S/R/F key edge. A driver working the throttle
    -- then exceeded the server's 25/s guard ("control rejected: command rate
    -- exceeded") and every rejection rolled the levers back on the client. Control
    -- is state, not an event stream, and the channel is TCP: only send when the
    -- state actually changed. The server keeps the flood guard; this makes legit
    -- driving fit comfortably under it.
    local args = {
        id = e.id, throttle = e.throttle, reverser = e.reverser, brake = e.brakeInput,
        horn = e.snd and e.snd.hornOn and true or false,
        -- v1.0.11: stop WINS over start when both latches are held (a W then S
        -- burst, or a stale latch on a phantom remount). Sending both in one
        -- command made the server force-start then immediately stop the engine,
        -- and the retry loop re-fired the catch/stop one-shots repeatedly.
        start = e._starting and not e._stopping and true or false,
        stop = e._stopping and true or false,
        head = e.lightState and e.lightState.head, cab = e.lightState and e.lightState.cab,
    }
    local key = table.concat({ args.throttle or 0, args.reverser or 0, args.brake or 0,
        args.horn and 1 or 0, args.start and 1 or 0, args.stop and 1 or 0,
        args.head or -1, args.cab and 1 or 0 }, ":")
    if e._sentKey == key then return end
    e._sentKey = key
    e._sendSeq = (e._sendSeq or 0) + 1
    args.seq = e._sendSeq
    sendClientCommand(player, "RailroaderMP", "control", args)
end

function Client.board(e)
    local player = getPlayer()
    if player and e and e.id then sendClientCommand(player, "RailroaderMP", "board", { id = e.id }) end
end

--------------------------------------------------------------------------
-- requestResync: ask the server for the authoritative snapshots newer than this
-- record's last accepted tick, to re-base the interpolation buffer after a loss
-- gap. Reply arrives as command "history".
--------------------------------------------------------------------------
function Client.requestResync(e)
    local player = getPlayer()
    if not (player and e and e.id) then return end
    sendClientCommand(player, "RailroaderMP", "resync", { afterTick = e._lastTick or 0 })
end

--------------------------------------------------------------------------
-- requestRerail(e): admin-only recovery -- ask the server to put a derailed loco
-- back on the rails. The right-click entry only exists for isAdmin() players
-- (RR_RerailMenu); the server re-validates the access level anyway, so a forged
-- command from a non-admin gets "rejected".
--------------------------------------------------------------------------
function Client.requestRerail(e)
    local player = getPlayer()
    if player and e and e.id then
        sendClientCommand(player, "RailroaderMP", "rerail", { id = e.id })
    end
end

--------------------------------------------------------------------------
-- Wire decode (doc §4.2): the server's hot broadcast is delta-encoded --
-- distance as an int16 millimetre delta, controls as one packed byte, engine /
-- lights fields omitted when unchanged. decodeWire() turns it back into the
-- full snapshot shape apply() expects.
--------------------------------------------------------------------------
local lastWireDist = {}

local function decodeWire(s)
    local out = {
        id = s.id, tick = tonumber(s.tick) or 0,
        simTime = s.simTime, wall = s.wall, game = s.game,
        routeId = s.rid, rk = s.rk and true or false,
        driver = s.drv, passengers = s.pax or {}, derailed = s.dr and true or false,
        v = s.v or 0, ne = s.ne or 0, bl = s.bl or 0,
        notchEff = s.ne or 0, brakeLevel = s.bl or 0,
        x = s.x or 0, y = s.y or 0, z = s.z or 0,
        dirX = s.dx or 0, dirY = s.dy or 0,
        lastCmdSeq = tonumber(s.lc) or 0,
    }
    if s.dist ~= nil then
        out.distance = s.dist
        lastWireDist[s.id] = s.dist
    elseif s.d ~= nil then
        local base = lastWireDist[s.id]
        if base == nil then return nil end   -- no baseline yet: wait for a full/resync packet
        out.distance = base + s.d / 1000
        lastWireDist[s.id] = out.distance
    end
    if s.c ~= nil then
        out.throttle = s.c % 16
        out.reverser = math.floor(s.c / 16) % 4 - 1
        out.brakeInput = math.floor(s.c / 64) % 2
    else
        out.throttle, out.reverser, out.brakeInput = s.t or 0, s.r or 0, s.b or 0
    end
    if s.eo ~= nil then out.engineOn = s.eo and true or false end
    if s.ep ~= nil then out.enginePhase = s.ep end
    if s.wt ~= nil then out.warmupTime = s.wt end
    if s.ef ~= nil then out.fuel = s.ef end
    if s.eb ~= nil then out.battery = s.eb end
    if s.ec ~= nil then out.condition = s.ec end
    if s.hd ~= nil then out.head = s.hd end
    if s.cb ~= nil then out.cab = s.cb and true or false end
    return out
end

local function animal(id)
    local found
    pcall(function() found = getAnimal(tonumber(id)) end)
    if found then return found end
    local list = getCell() and getCell():getAnimals()
    if list then
        for index = 0, list:size() - 1 do
            local a = list:get(index)
            if a:getAnimalID() == tonumber(id) then return a end
        end
    end
end

--------------------------------------------------------------------------
-- Half the truck spacing for the rigid-body chord, cached per record.
--------------------------------------------------------------------------
local function halfWheelbase(e)
    if e.hw then return e.hw end
    local size = 0.7
    if e.animal then pcall(function() size = e.animal:getAnimalSize() end) end
    e.hw = (RR.Body and RR.Body.halfWheelbase(size)) or 0
    return e.hw
end

--------------------------------------------------------------------------
-- splinePose: route distance -> exact rail pose (world coords, chord heading).
--------------------------------------------------------------------------
local function splinePose(e, d)
    if not (e and e.route and RR.Spline) then return nil end
    return RR.Spline.bodyPose(e.route, d, halfWheelbase(e))
end

--------------------------------------------------------------------------
-- reanchorRoute: rebuild the through-route for this loco. Mirrors the server's
-- reanchor (same shared TrackGraph code + the snapshot's world pos/heading), so
-- both sides measure `distance` on the SAME route parameterization. Non-graph
-- routes just re-pull the base route from the registry.
--------------------------------------------------------------------------
local function reanchorRoute(e, x, y, dx, dy)
    if not (e.baseId and RR.TrackGraph and RR.TrackGraph.has(e.baseId)) then
        e.route = (RR.Routes and RR.Routes.get(e.routeId)) or e.route
        e.routeStateKey = ""
        return e.route ~= nil
    end
    local loc = RR.TrackGraph.graphLocate(RR.TrackGraph.netEdges(e.baseId), x, y)
    if not loc then return false end
    local dir = ((dx or 1) * loc.tx + (dy or 0) * loc.ty) >= 0 and 1 or -1
    local route, sHere = RR.TrackGraph.buildThrough(e.baseId, { edge = loc.edge, s = loc.s, dir = dir })
    if not route then return false end
    e.route = route
    e.distance = sHere
    e.routeStateKey = RR.TrackGraph.stateKey(e.baseId)
    return true
end

--------------------------------------------------------------------------
-- Interpolation buffer per record:
--   e.hold  -- the last applied snapshot (base when idle)
--   e.seq   -- pending snapshots, oldest first (bounded by INTERP_QUEUE_MAX)
--   e.seg   -- the segment currently playing between two snapshots
--   e.segT  -- seconds played into e.seg
--------------------------------------------------------------------------
local function resetBuffer(e)
    e.seq = {}
    e.seg = nil
    e.segT = 0
    e.hold = nil
    e._lastTick = nil
    e._holdAge = 0
    e._extrapD, e._extrapPose = nil, nil
    e._rollback = nil
end

local function snapshotOf(s)
    return {
        tick = tonumber(s.tick) or 0,
        distance = s.distance or 0,
        v = s.v or 0,
        x = s.x or 0, y = s.y or 0, z = s.z or 0,
        dirX = s.dirX or 0, dirY = s.dirY or 0,
    }
end

local function pushSnapshot(e, snap)
    local tick = snap.tick or 0
    if tick <= 0 then tick = (e._lastTick or 0) + 1; snap.tick = tick end
    if e._lastTick and tick <= e._lastTick then return end   -- dedupe ad-hoc re-sends
    if e._lastTick and tick > e._lastTick then e._snapGap = tick - e._lastTick end
    e._lastTick = tick
    if not e.hold then
        e.hold = snap
        e._holdAge = 0
        e._extrapD, e._extrapPose = nil, nil
        return
    end
    if #e.seq >= INTERP_QUEUE_MAX then table.remove(e.seq, 1) end
    e.seq[#e.seq + 1] = snap
end

local function nlerp2d(ax, ay, bx, by, t)
    local x, y = ax + (bx - ax) * t, ay + (by - ay) * t
    local len = math.sqrt(x * x + y * y)
    if len < 1e-9 then return bx or 0, by or 0 end
    return x / len, y / len
end

local function worldPoseAt(a, b, t)
    local dx, dy = nlerp2d(a.dirX or 0, a.dirY or 0, b.dirX or 0, b.dirY or 0, t)
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
        z = (a.z or 0) + ((b.z or 0) - (a.z or 0)) * t,
        dirX = dx, dirY = dy,
    }
end

--------------------------------------------------------------------------
-- blendPose: world-space pose blend (x/y/z lerp + heading nlerp) used to bridge
-- a driven-loco rollback so the eye never sees a teleport.
--------------------------------------------------------------------------
local function blendPose(a, b, t)
    local dx, dy = nlerp2d(a.dirX or 0, a.dirY or 0, b.dirX or 0, b.dirY or 0, t)
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
        z = (a.z or 0) + ((b.z or 0) - (a.z or 0)) * t,
        dirX = dx, dirY = dy,
    }
end

--------------------------------------------------------------------------
-- poseAt: interpolated pose between snapshots a and b at alpha in [0,1].
-- Route distance is cubic-Hermite interpolated with the endpoint speeds (so
-- acceleration/braking stays smooth) and the pose is re-sampled from the
-- spline -- the body rides the rails exactly. World-space lerp is the fallback
-- when the client route could not be matched (e._posFallback).
--------------------------------------------------------------------------
local function poseAt(e, a, b, alpha)
    local t = alpha
    if e._posFallback or not e.route then return worldPoseAt(a, b, t) end
    if t >= 1 then
        local p = splinePose(e, b.distance)
        if p then return p end
        return worldPoseAt(a, b, 1)
    end
    if t <= 0 then
        local p = splinePose(e, a.distance)
        if p then return p end
        return worldPoseAt(a, b, 0)
    end
    local dt = math.max(1e-4, (b.tick - a.tick) / 60)
    local t2, t3 = t * t, t * t * t
    local h00 = 2 * t3 - 3 * t2 + 1
    local h10 = t3 - 2 * t2 + t
    local h01 = -2 * t3 + 3 * t2
    local h11 = t3 - t2
    local d = h00 * a.distance + h10 * dt * (a.v or 0)
            + h01 * b.distance + h11 * dt * (b.v or 0)
    local lo, hi = math.min(a.distance, b.distance), math.max(a.distance, b.distance)
    if d < lo then d = lo elseif d > hi then d = hi end
    local p = splinePose(e, d)
    if p then return p end
    return worldPoseAt(a, b, t)
end

--------------------------------------------------------------------------
-- bufferPose: per-render-frame pose for a REMOTE loco. Plays the queued segment
-- (previous snapshot -> newest), then falls back to hold + capped extrapolation
-- when the queue starves -- freeze, never jump.
--------------------------------------------------------------------------
local function bufferPose(e)
    if not e.animal then return nil end
    if e.seg then
        e.segT = e.segT + frameDt
        if e.segT >= e.seg.ticks then
            e.hold = e.seg.to
            e.seg = nil
            e.segT = 0
            e._holdAge = 0
        end
    end
    if not e.seg and #e.seq > 0 then
        local nxt = table.remove(e.seq, 1)
        local from = e.hold or nxt
        -- After a starvation gap the render is ahead of the stale snapshot (capped
        -- extrapolation); start the catch-up segment THERE so the stream resumes
        -- without a snap-back.
        if e._extrapPose then
            from = {
                tick = from.tick + math.floor((e._holdAge or 0) * 60),
                distance = e._extrapD or from.distance,
                v = from.v or 0,
                x = e._extrapPose.x, y = e._extrapPose.y, z = e._extrapPose.z or 0,
                dirX = e._extrapPose.dirX or 0, dirY = e._extrapPose.dirY or 0,
            }
        end
        e._extrapD, e._extrapPose = nil, nil
        -- Duration in SECONDS: at least the real tick gap, but stretched when the
        -- distance gap is anomalous (starvation catch-up) so the recovery never
        -- streaks -- the visual motion is capped at RESYNC_SPEED tiles/s.
        local realGap = math.max(1 / 60, (nxt.tick or 0) - (from.tick or 0)) / 60
        local dur = realGap
        local gap = math.abs((nxt.distance or 0) - (from.distance or 0))
        if gap > 1e-4 then dur = math.max(dur, gap / RESYNC_SPEED) end
        -- v1.0.5 (MP render lag): a healthy buffer used to play each segment at
        -- 1x, so a sparse-band train always rendered a full packet interval
        -- behind its actual position (0.2s MID / up to 1s FAR). Bound the
        -- playout delay: on a NORMAL gap (not a stretched catch-up) jump INTO
        -- the segment so the render reaches the newest snapshot LAG_CAP after it
        -- was sent; the capped extrapolation below covers the wait for the next
        -- packet. The 20Hz NEAR band is untouched (gap <= LAG_CAP).
        if dur == realGap and dur > LAG_CAP and not e._posFallback then
            local u = 1 - LAG_CAP / dur
            from = {
                tick = from.tick + math.floor(((nxt.tick or 0) - from.tick) * u + 0.5),
                distance = (from.distance or 0) + ((nxt.distance or 0) - (from.distance or 0)) * u,
                v = (from.v or 0) + ((nxt.v or 0) - (from.v or 0)) * u,
                x = (from.x or 0) + ((nxt.x or 0) - (from.x or 0)) * u,
                y = (from.y or 0) + ((nxt.y or 0) - (from.y or 0)) * u,
                z = (from.z or 0) + ((nxt.z or 0) - (from.z or 0)) * u,
                dirX = (from.dirX or 0) + ((nxt.dirX or 0) - (from.dirX or 0)) * u,
                dirY = (from.dirY or 0) + ((nxt.dirY or 0) - (from.dirY or 0)) * u,
            }
            dur = LAG_CAP
        end
        e.seg = { from = from, to = nxt, ticks = dur }
        e.segT = 0
        e._holdAge = 0
    end
    if e.seg then
        return poseAt(e, e.seg.from, e.seg.to, math.min(1, e.segT / e.seg.ticks))
    end
    if not e.hold then return nil end
    e._holdAge = (e._holdAge or 0) + frameDt
    -- Starvation threshold scales with the observed snapshot cadence: a FAR-band
    -- train arrives at 1Hz, so a fixed 0.6s would spam resync requests forever.
    local starveSec = math.max(RESYNC_STARVE, (e._snapGap or 3) * 2.5 / 60)
    if e._holdAge > starveSec and not e._resyncReq and not e._posFallback then
        e._resyncReq = true
        Client.requestResync(e)
    end
    if not e._posFallback and e._holdAge > HOLD_EXTRAP_DELAY and math.abs(e.hold.v or 0) > 1e-4 then
        local over = math.min(e._holdAge - HOLD_EXTRAP_DELAY, EXTRAP_CAP)
        e._extrapD = e.hold.distance + (e.hold.v or 0) * over
        local p = splinePose(e, e._extrapD)
        if p then
            e._extrapPose = p
            return p
        end
        e._extrapD = nil
    end
    return poseAt(e, e.hold, e.hold, 0)
end

--------------------------------------------------------------------------
-- apply: fold one server state into the record. Motion fields for REMOTE locos
-- feed the interpolation buffer; for the DRIVEN loco they feed smooth blend
-- corrections (never a teleport). e.lastPose is the LOGIC pose (collider /
-- sound / lights); the visible pose is applied per render frame in onRender().
--------------------------------------------------------------------------
local function apply(s)
    local T = RR.TrainEntity
    if not T then return end
    local e = Client.pending[s.id]
    if not e then
        for _, candidate in ipairs(T.active) do if candidate.id == s.id then e = candidate; break end end
    end
    local a = animal(s.id)
    if not a then Client.pending[s.id] = e or s; return end
    if not e or not e.animal then
        e = { id = s.id, animal = a, drive = RR.Drive.newState(), engine = RR.Engine.newState() }
        T.active[#T.active + 1] = e
        -- v1.0.13 (client animal protection): mirror RR_TrainEntity.suppressAI
        -- on the REPLICATED animal. The server makes the loco invincible, but the
        -- client's own copy carries its own health -- a stale/zero-health copy
        -- made e.animal:isDead() true, and RR_Ride.onTick then auto-dismounted
        -- the player right after every board. Revive + invincible here so the
        -- client copy never reports a phantom death.
        pcall(function() a:setGodMod(true) end)
        pcall(function() a:setIsInvincible(true) end)
        pcall(function() if (a:getHealth() or 1) <= 0 then a:setHealth(100) end end)
        dbg("client record created: loco %s", tostring(s.id))
    end

    -- Doc §4.2: resync-tagged packets (fresh full snapshot / wake-up after the
    -- relevance quiet stretch) re-base the buffer on truth -- no interpolation
    -- across the gap.
    if s.rk then
        resetBuffer(e)
        e._dCorr, e._vCorr, e._rollback = nil, nil, nil
        e._posFallback = false
        e._wasRidden = false
        e.distance = s.distance or 0
        e.drive.v = s.v or 0
        e.drive.notchEff = s.ne or 0
        e.drive.brakeLevel = s.bl or 0
    end

    e.routeId = s.routeId
    e.baseId = e.baseId or s.routeId
    -- Engine/lights travel only when they changed (delta wire), so update the
    -- record only when the field is present -- never regress a stale default.
    if s.engineOn ~= nil then
        local wasRunning = e.engine.running
        -- v1.0.5 (derail = dead engine): a wrecked loco's prime mover is OFF no
        -- matter what the stream says. The server stops the engine on derail; this
        -- belt-and-braces stops a stale/buffered pre-derail snapshot from
        -- resurrecting the engine hum on the wreck.
        e.engine.running = s.derailed and false or (s.engineOn and true or false)
        e.engine.phase = s.derailed and "off" or (s.enginePhase or (e.engine.running and "running" or "off"))
        -- v1.0.10 (sound sync): the engine one-shots (catch "vroom" / shutdown
        -- spin-down) are played HERE on the server-authoritative running<->off
        -- EDGE, on every client, LOCAL-ONLY (RR_Sound uses playSoundImpl, so the
        -- game's PlaySound/PlayWorldSound auto-replication cannot stack the sound
        -- per client). In MP this is the only path for these one-shots (RR_Ride's
        -- key sequence early-outs); it also covers stalls / immobilize / derail,
        -- which previously were silent in MP. The FIRST engine field per record
        -- (join / first sight) never fires an edge -- a late joiner near a running
        -- loco must not hear a catch "vroom".
        if e._engineSeen and RR.Sound and RR.Sound.engineCatch and RR.Sound.engineStop then
            if e.engine.running and not wasRunning then
                pcall(function() RR.Sound.engineCatch(e) end)
            elseif not e.engine.running and wasRunning then
                pcall(function() RR.Sound.engineStop(e) end)
            end
        end
        e._engineSeen = true
    end
    if s.warmupTime ~= nil then e.engine.warmupTime = s.warmupTime end
    if s.fuel ~= nil then e.engine.fuel = s.fuel end
    if s.battery ~= nil then e.engine.battery = s.battery end
    if s.condition ~= nil then e.engine.condition = s.condition end
    -- v1.0.4 (switch-route fix): a switch net's route MUST stay the through-route
    -- (TrackGraph.buildThrough, switch-aware). Overwriting it with the base
    -- registry route here silently reverted routing to the DEFAULT branch on
    -- every packet -- the client then predicted the default direction at a
    -- thrown switch and rubber-banded on every snapshot (routeStateKey still
    -- matched, so the re-anchor guard below never rebuilt it). Non-graph routes
    -- keep the registry as their source of truth.
    if not (e.baseId and RR.TrackGraph and RR.TrackGraph.has(e.baseId)) then
        e.route = RR.Routes and RR.Routes.get(s.routeId) or e.route
    end
    e.lightState = e.lightState or RR.Lights.newState()
    if s.head ~= nil then e.lightState.head = s.head end
    if s.cab ~= nil then e.lightState.cab = s.cab and true or false end
    -- v1.0.3f: headlight end (faceSign) is server-authoritative for REMOTE locos.
    -- The DRIVEN loco keeps its own deadbanded local value (no RTT flicker); the
    -- periodic reconcile below re-checks it against this authoritative one.
    local riddenHere = RR.Ride and RR.Ride.current == e
    if not riddenHere then
        if s.fs ~= nil then e.faceSign = s.fs
        elseif s.faceSign ~= nil then e.faceSign = s.faceSign end
    end
    e.driver, e.passengers, e.derailed = s.driver, s.passengers or {}, s.derailed and true or false
    if s.derailed then
        if not e._dbgDerailed then
            e._dbgDerailed = true
            dbg("loco %s is DERAILED: pos=(%.1f,%.1f,%.1f) dir=(%.3f,%.3f)",
                tostring(s.id), s.x or 0, s.y or 0, s.z or 0, s.dirX or 0, s.dirY or 0)
        end
    else
        e._dbgDerailed = nil
    end
    e._lastAckSeq = s.lastCmdSeq or e._lastAckSeq
    local player = getPlayer()
    local onlineId = player and player:getOnlineID()
    local seat = onlineId and ((s.driver == onlineId and 0) or e.passengers[onlineId])
    if seat ~= nil then
        e.seat, e.passenger = seat, seat > 0
        if RR.Ride and RR.Ride.current ~= e then
            -- v1.0.11 (seat race): suppress the STALE pre-release packet. A state
            -- packet generated before the server processed our "release" still
            -- lists us as driver; auto-mounting from it re-seated the player a
            -- few frames after every dismount ("reload: re-seated driver in the
            -- cab"), so E toggled dismount instead of boarding and the follow-up
            -- release was rejected (NotAboard). Skip the auto-mount within a
            -- 2s grace of a MANUAL dismount unless the player explicitly pressed
            -- E to board again (RR_Ride.mountNearest sets _boardPending).
            local justDismounted = false
            if e._dismountAt and getTimestampMs then
                pcall(function() justDismounted = (getTimestampMs() - e._dismountAt) < 2000 end)
            end
            if not justDismounted or e._boardPending then
                dbg("seat=%s for loco %s: MOUNT", tostring(seat), tostring(s.id))
                RR.Ride.mountRecord(e, true, seat)
            else
                dbg("seat=%s for loco %s: stale re-seat SKIPPED (dismount grace)", tostring(seat), tostring(s.id))
            end
        end
        e._boardPending = nil
    elseif onlineId and RR.Ride and RR.Ride.current == e then
        -- v1.0.11 (seat race): the server no longer seats this player (release
        -- processed / kicked / seat pruned) but the client is still mounted --
        -- drop the phantom mount QUIETLY (no release command: the server already
        -- knows). Before this, the client stayed "seated" with dead controls and
        -- E kept fighting the phantom seat instead of re-boarding.
        dbg("seat=nil for loco %s while mounted: QUIET DISMOUNT", tostring(s.id))
        RR.Ride.dismount(true)
    end

    local ridden = RR.Ride and RR.Ride.current == e
    -- Control fields: server truth for REMOTE locos only. The DRIVEN loco keeps
    -- its OWN lever (the player's intent) -- a lagging snapshot must not flash the
    -- HUD notch back after W/S/R. Server truth is stashed so a rejected control
    -- can roll the lever back. (The driver's v/notchEff are likewise never
    -- overwritten while riding: the local sim owns them, so the needles stay smooth.)
    e._sReverser, e._sThrottle, e._sBrake = s.reverser, s.throttle, s.brakeInput
    -- Passengers (and remote locos) still mirror the server's lever; only the
    -- DRIVER keeps his own.
    if not ridden or (ridden and e.passenger) then
        e.reverser, e.throttle, e.brakeInput = s.reverser, s.throttle, s.brakeInput
    end

    -- Route identity: rebuild the through-route when it can have changed (first
    -- sight, switch state, route id). Re-parameterization rebases the buffer.
    local stateKey = ""
    if e.baseId and RR.TrackGraph and RR.TrackGraph.has(e.baseId) then
        stateKey = RR.TrackGraph.stateKey(e.baseId)
    end
    if (not e.route) or e.routeStateKey ~= stateKey or e._routeIdSeen ~= s.routeId then
        e._routeIdSeen = s.routeId
        reanchorRoute(e, s.x, s.y, s.dirX, s.dirY)
        resetBuffer(e)
        e._dCorr, e._vCorr, e._posFallback = nil, nil, false
    end
    if e.distance == nil then e.distance = s.distance or 0 end   -- non-graph routes: distance comes from the snapshot

    -- Self-heal a route/snapshot mismatch (e.g. a switch state we haven't seen yet).
    if e.route then
        local p = splinePose(e, s.distance or 0)
        if p then
            local dx, dy = p.x - s.x, p.y - s.y
            if dx * dx + dy * dy > ROUTE_TOL * ROUTE_TOL then
                reanchorRoute(e, s.x, s.y, s.dirX, s.dirY)
                resetBuffer(e)
                p = splinePose(e, s.distance or 0)
                local q = p and ((p.x - s.x) * (p.x - s.x) + (p.y - s.y) * (p.y - s.y))
                         or ((ROUTE_TOL + 1) * (ROUTE_TOL + 1))
                if q > ROUTE_TOL * ROUTE_TOL then e._posFallback = true end
            end
        end
    else
        e._posFallback = true
    end

    if e.derailed then
        -- Terminal wreck: pin the server pose; no interpolation.
        resetBuffer(e)
        e.distance = s.distance or 0
        e.lastPose = { x = s.x, y = s.y, z = s.z, dirX = s.dirX, dirY = s.dirY }
        e.renderPose = e.lastPose
    elseif ridden then
        -- Driven loco: client-side prediction validated against the server.
        if not e._wasRidden then
            e._wasRidden = true
            resetBuffer(e)
            e._dCorr, e._vCorr = nil, nil
        end
        local errD = s.distance - (e.distance or 0)
        local errV = (s.v or 0) - (e.drive.v or 0)
        -- Post-rollback prediction lock: while it holds, the local sim stays
        -- frozen at the authoritative state (blend corrections still track the
        -- server). Released once the server actually moves, or after PRED_LOCK_TIME
        -- -- this stops the predict -> rollback -> predict rubber-band against a
        -- persistent obstacle stop.
        local justReleased = false
        if e._predLock and e._predLock > 0 then
            e._predLock = e._predLock - 1 / 60
            if (s.v or 0) ~= 0 then
                e._predLock = 0
                justReleased = true
            end
        end
        if e._rollback then
            -- render bridge in progress: the sim is frozen at the authoritative
            -- state; the next snapshot after it completes re-establishes the blend.
        elseif not justReleased and (math.abs(errD) > RESYNC_DIST or math.abs(errV) > RESYNC_V) then
            -- AUTHORITATIVE ROLLBACK: the prediction diverged (loss gap, obstacle
            -- stop, derail, stall). Snap the SIM state to the server snapshot and
            -- bridge the RENDER pose at RESYNC_SPEED for ROLLBACK_DUR_MIN..MAX
            -- (teleport past ROLLBACK_SNAP -- a bridge that long reads as slow-mo).
            local from = e.renderPose or splinePose(e, e.distance or s.distance)
            e.distance = s.distance
            e.drive.v = s.v or 0
            e.drive.notchEff = s.notchEff or 0
            e.drive.brakeLevel = s.brakeLevel or 0
            e._dCorr, e._vCorr = nil, nil
            e._predLock = PRED_LOCK_TIME
            local to = splinePose(e, e.distance)
            local gap = math.abs(errD)
            if to and gap <= ROLLBACK_SNAP then
                e._rollback = {
                    from = from, to = to, t = 0,
                    dur = math.max(ROLLBACK_DUR_MIN, math.min(ROLLBACK_DUR_MAX, gap / RESYNC_SPEED)),
                }
            else
                e._rollback = nil
            end
            print(string.format("[RailroaderMP] prediction rollback: errD=%.2f errV=%.2f", errD, errV))
        else
            -- Small error: normal network lead / prediction noise -- blend.
            e._dCorr = errD
            e._vCorr = errV
        end
        if not e._posFallback then
            e.lastPose = splinePose(e, e.distance or 0) or e.lastPose
        end
    else
        if e._wasRidden then
            e._wasRidden = false
            resetBuffer(e)
            e._predLock = nil
        end
        if not e._lastTick or (s.tick or 0) > e._lastTick then
            e.distance = s.distance or 0
            e.drive.v = s.v or 0
            e.drive.notchEff = s.notchEff or 0
            e.drive.brakeLevel = s.brakeLevel or 0
            pushSnapshot(e, snapshotOf(s))
            e._resyncReq = false                            -- stream alive again
            if e._posFallback then
                e.lastPose = { x = s.x, y = s.y, z = s.z, dirX = s.dirX, dirY = s.dirY }
            else
                e.lastPose = splinePose(e, e.distance) or
                    { x = s.x, y = s.y, z = s.z, dirX = s.dirX, dirY = s.dirY }
            end
        end
    end

    -- v1.0.16: stamp the packet as "just seen" with the CLIENT clock so the
    -- stale-prune compares like with like (see clientTicks note).
    e._lastSeen = clientTicks
    if RR.LightsRender and not e.lights then RR.LightsRender.onSpawn(e) end
    if RR.Sound and not e.snd then RR.Sound.onSpawn(e) end
    Client.pending[s.id] = nil
end

--------------------------------------------------------------------------
-- next() is NOT available in Project Zomboid's Kahlua, so a bare
-- `next(nets)` call crashes the client ("Object tried to call nil").
-- Non-empty check via pairs() instead.
local function tableNonEmpty(t)
    if not t then return false end
    for _ in pairs(t) do return true end
    return false
end

--------------------------------------------------------------------------
-- reanchorNets(nets): rebuild the through-route of every loco on the listed
-- base nets (centred on its current world pose, so nothing jumps) and rebase
-- its interpolation buffer / corrections. v1.0.4 (far-junction fix): a switch
-- thrown AHEAD of a train leaves the shared-prefix parameterization unchanged,
-- so the buffer and distance are kept -- a player throwing a switch at a
-- faraway junction never freezes a watching client's train. Only when the
-- train already crossed the fork (old-route tail inside the buffer) do we
-- reset and re-baseline.
--------------------------------------------------------------------------
local function reanchorNets(nets)
    local T = RR.TrainEntity
    if not (T and nets and tableNonEmpty(nets)) then return end
    for _, rec in ipairs(T.active) do
        if rec.baseId and nets[rec.baseId] and rec.animal then
            local oldRoute = rec.route
            local oldDist = rec.distance
            local px, py, fx, fy = rec.animal:getX(), rec.animal:getY(), 1, 0
            if rec.lastPose then
                px, py = rec.lastPose.x, rec.lastPose.y
                fx, fy = rec.lastPose.dirX or 1, rec.lastPose.dirY or 0
            end
            if not reanchorRoute(rec, px, py, fx, fy) then
                -- route could not be rebuilt: leave everything as-is
            elseif oldRoute and oldDist ~= nil then
                local prefix = RR.TrackGraph.sharedPrefixDist(oldRoute, rec.route)
                local crossed = (rec.distance or 0) > prefix + 1e-3
                if not crossed then
                    if rec.hold and (rec.hold.distance or 0) > prefix + 1e-3 then crossed = true end
                    if rec.seq then
                        for _, snap in ipairs(rec.seq) do
                            if (snap.distance or 0) > prefix + 1e-3 then crossed = true break end
                        end
                    end
                end
                rec._rollback = nil
                if crossed then
                    resetBuffer(rec)
                    rec._dCorr, rec._vCorr = nil, nil
                end
            else
                resetBuffer(rec)
                rec._dCorr, rec._vCorr, rec._rollback = nil, nil, nil
            end
        end
    end
end

--------------------------------------------------------------------------
-- applySwitches(switches): fold the server's authoritative switch states into
-- the local TrackGraph (shape { [baseId] = { [switchId] = "normal"|"reverse" } })
-- and re-anchor the nets whose state actually changed (world pose stays
-- continuous). Used by the full "state" snapshot (late joiner / periodic ready
-- -- switch states are server-authoritative, so a client that joined after a
-- throw must not keep predicting the default branch). The one-shot "switch"
-- event re-anchors its net unconditionally via reanchorNets.
--------------------------------------------------------------------------
local function applySwitches(switches)
    if not (switches and RR.TrackGraph) then return end
    local changedNets = {}
    for baseId, states in pairs(switches) do
        if type(states) == "table" and RR.TrackGraph.has(baseId) then
            local before = RR.TrackGraph.stateKey(baseId)
            for switchId, state in pairs(states) do
                if state == "normal" or state == "reverse" then
                    RR.TrackGraph.setState(baseId, switchId, state)
                end
            end
            if RR.TrackGraph.stateKey(baseId) ~= before then changedNets[baseId] = true end
        end
    end
    reanchorNets(changedNets)
end

local function receive(module, command, args)
    if module ~= "RailroaderMP" then return end
    if command == "state" then
        Client.reserves = (args or {}).reserves or Client.reserves
        -- v1.0.4: authoritative switch states ride the full snapshot, so apply
        -- them BEFORE the entities (the state-key guard re-anchors correctly).
        applySwitches(args and args.switches)
        for _, s in ipairs((args or {}).entities or {}) do
            local dec = decodeWire(s)
            if dec then apply(dec) end
        end
    elseif command == "switch" then
        -- v1.0.4: mirror the server's immediate re-anchor for this net. The
        -- thrower's own client may already hold the state (RR_SwitchAction
        -- applies it optimistically), so always re-materialize here instead of
        -- change-detecting.
        if RR.TrackGraph and RR.TrackGraph.has(args.baseId)
           and (args.state == "normal" or args.state == "reverse") then
            RR.TrackGraph.setState(args.baseId, args.switchId, args.state)
        end
        reanchorNets({ [args.baseId] = true })
    elseif command == "impact" then
        local e = Client.pending[args.id]
        if not e then
            for _, candidate in ipairs((RR.TrainEntity and RR.TrainEntity.active) or {}) do
                if candidate.id == args.id then e = candidate; break end
            end
        end
        if e and RR.Sound then
            if args.kind == "crush" then
                -- v1.0.8: throttle the thud like the SP client (CRUSH_MIN_INTERVAL)
                -- -- a crowd going under together is one hit, not a wall of them.
                e._crushSndCd = (e._crushSndCd or 0) - 1 / 60
                if e._crushSndCd <= 0 then
                    e._crushSndCd = (RR.SoundConfig and RR.SoundConfig.CRUSH_MIN_INTERVAL) or 0.12
                    if RR.Sound.crushImpact then RR.Sound.crushImpact(e) end
                    -- v1.0.8 (SP v1.0.2 foley): a DOWNED body was pulped on the
                    -- ground -- play the blood-splatter squelch on top of the
                    -- thud, throttled with it (the SP caps one splat per tick).
                    if args.downed and RR.Sound.squelch then RR.Sound.squelch(e) end
                end
            elseif RR.Sound.hardImpact then RR.Sound.hardImpact(e, 0, false) end
        end
    elseif command == "horn" then
        -- Server-broadcast horn edge (the driver's own client already played it
        -- locally at the key poll, so only OTHER clients replay the sound, each
        -- with its own distance falloff -- 0 at 200 tiles).
        local e
        for _, candidate in ipairs((RR.TrainEntity and RR.TrainEntity.active) or {}) do
            if candidate.id == args.id then e = candidate; break end
        end
        if e and RR.Sound and RR.Ride and RR.Ride.current ~= e then
            if args.on then RR.Sound.hornOnLocomotive(e)
            else RR.Sound.hornOffLocomotive(e) end
        end
    elseif command == "rejected" then
        local reason = (args and args.reason) or "IGUI_RR_Reject_Unknown"
        print("[RailroaderMP] " .. reason)
        -- Reject reasons are translation keys (IGUI_RR_Reject_*); resolve them
        -- so the player sees localised text, keep the key as a last fallback.
        pcall(function()
            local txt = getText(reason)
            if not txt or txt == "" or txt == reason then txt = reason end
            HaloTextHelper.addBadText(getPlayer(), txt)
        end)
        -- The server refused a control: roll the lever back to the last server
        -- state so the HUD can't sit on a phantom notch the server never accepted.
        local id = args and args.id
        local e = RR.Ride and RR.Ride.current
        if id and e and e.id == id and e._sThrottle ~= nil then
            e.throttle = e._sThrottle
            e.reverser = e._sReverser or 0
            e.brakeInput = e._sBrake or 0
        end
    elseif command == "history" then
        -- Authoritative re-baseline after a loss gap: replay the server's retained
        -- snapshots into the interpolation buffer (the driven loco is skipped --
        -- it re-syncs through live snapshots + rollback).
        local riddenRec = RR.Ride and RR.Ride.current
        for _, s in ipairs((args or {}).entities or {}) do
            if not (riddenRec and riddenRec.id == s.id) then apply(s) end
        end
    elseif command == "serviced" then
        -- Server confirmation for a successful wrench repair: green halo + a log
        -- line, so the context-menu click has immediate visible feedback.
        local p = getPlayer()
        if p and HaloTextHelper then
            pcall(function() HaloTextHelper.addText(p, getText("IGUI_RR_Repaired", "Locomotive repaired (+5%)")) end)
        end
        print(string.format("[RailroaderMP] locomotive %s repaired, condition %.2f",
            tostring(args and args.id), tonumber(args and args.condition) or -1))
    elseif command == "rerailed" then
        -- v1.0.8: server confirmation for an admin re-rail -- green halo so the
        -- right-click click has immediate visible feedback (the state stream
        -- already dropped the wreck pose for every client).
        local p = getPlayer()
        if p and HaloTextHelper then
            pcall(function() HaloTextHelper.addGoodText(p, getText("IGUI_RR_Rerailed", "Back on the rails")) end)
        end
        print(string.format("[RailroaderMP] locomotive %s re-railed", tostring(args and args.id)))
    end
end

local function tick()
    clientTicks = clientTicks + 1
    if clientTicks == 1 or clientTicks % 300 == 0 then sendClientCommand(getPlayer(), "RailroaderMP", "ready", {}) end
    -- v1.0.18: the CLIENT heartbeat only runs with RR.dbgLog (v1.0.15-17 ran it
    -- unconditionally while diagnosing the record-prune bug -- pure noise now).
    if RR.dbgLog and clientTicks % 300 == 0 then
        local T = RR.TrainEntity
        local ids, der = {}, {}
        if T then
            for _, rec in ipairs(T.active) do
                ids[#ids + 1] = tostring(rec.id)
                der[#der + 1] = tostring(rec.derailed and true or false)
            end
        end
        local nPending = 0
        for _ in pairs(Client.pending) do nPending = nPending + 1 end
        sendClientCommand(getPlayer(), "RailroaderMP", "dbgState",
            { active = #(T and T.active or {}), ids = table.concat(ids, ","),
              der = table.concat(der, ","), pending = nPending,
              ride = RR.Ride and RR.Ride.current and tostring(RR.Ride.current.id) or "nil" })
    end
    local e = RR.Ride and RR.Ride.current
    if e and e.id and not e.derailed then
        -- Ride.onTick owns the brake poll (and its sleep/step-off overrides); only
        -- mirror it here when the DRIVER is awake so a sleeper holding Space
        -- can't drag the train. v1.0.4: passengers never poll the air brake --
        -- their local re-sim must mirror the server's controls, not their own
        -- keyboard (a passenger holding Space used to diverge the prediction
        -- and trip rollbacks).
        if not e.passenger and not (RR.Sleep and RR.Sleep.isAsleep()) then
            e.brakeInput = Keyboard.isKeyDown(Keyboard.KEY_SPACE) and 1 or 0
        end
        local mult = 0.8
        pcall(function() mult = getGameTime():getMultiplier() end)
        local dt = RR.Drive.dtSim(mult)
        -- Local physics: the SAME shared Drive.step the server runs, so the
        -- driven loco responds instantly and follows the route (no straight-line
        -- drift, no per-snapshot snap-back). Frozen while a rollback bridge is
        -- playing or the post-rollback prediction lock holds: the sim re-predicts
        -- only once the server is moving again.
        if e.route and not e._rollback and not (e._predLock and e._predLock > 0) then
            local effThrottle = e.throttle or 0
            local tmult = 1
            if RR.Engine and e.engine then
                effThrottle = math.min(effThrottle, RR.Engine.maxNotch(e.engine, { licensed = e.licensed ~= false }))
                tmult = RR.Engine.tractionMult(e.engine.condition or 1)
            end
            local delta = RR.Drive.step(e.drive, {
                reverser = e.reverser, throttle = effThrottle,
                brakeInput = e.brakeInput, tractionMult = tmult,
            }, dt)
            e.distance = (e.distance or 0) + delta
            -- v1.0.3f: local headlight end (deadbanded; neutral keeps the last).
            -- The server's authoritative fs comes back in snapshots and the
            -- periodic reconcile below verifies this against it.
            if RR.Lights and RR.Lights.faceSign then
                e.faceSign = RR.Lights.faceSign(e.drive.v, e.reverser, e.faceSign)
            end
        end
        -- Absorb the server's authoritative corrections smoothly (never teleport).
        if e._vCorr and math.abs(e._vCorr) > 1e-6 then
            local k = math.min(1, dt / BLEND_TIME)
            e.drive.v = e.drive.v + e._vCorr * k
            e._vCorr = e._vCorr * (1 - k)
        end
        if e._dCorr and math.abs(e._dCorr) > 1e-6 then
            local k = math.min(1, dt / BLEND_TIME)
            e.distance = e.distance + e._dCorr * k
            e._dCorr = e._dCorr * (1 - k)
        end
        if not e._posFallback then
            e.lastPose = splinePose(e, e.distance) or e.lastPose   -- logic pose (collider/sound)
        end
        if RR.LightsRender then RR.LightsRender.update(e, dt) end
        if RR.Sound then RR.Sound.update(e, dt) end
        -- v1.0.5 (MP start): the start/stop latch used to be cleared after 3 ticks
        -- whether or not the server had processed it, so a swallowed/rejected W
        -- (board race, stale engine state) silently did nothing. Keep the latch
        -- until the server's engineOn flips to confirm, force a re-send every few
        -- ticks while it is held, and give up after ~1.5 s.
        if e._starting then
            e._startTries = (e._startTries or 0) + 1
            if e.engine.running then e._starting, e._startTries = nil, nil
            elseif e._startTries > 90 then e._starting, e._startTries = nil, nil end
        end
        if e._stopping then
            e._stopTries = (e._stopTries or 0) + 1
            if not e.engine.running then e._stopping, e._stopTries = nil, nil
            elseif e._stopTries > 90 then e._stopping, e._stopTries = nil, nil end
        end
        if clientTicks % 3 == 0 then
            if (e._starting or e._stopping) and clientTicks % 9 == 0 then e._sentKey = nil end
            Client.sendControl(e)
        end
    end
    -- Doc §7.1: observer audio/lights are distance-gated -- a remote loco only
    -- spends world emitters / light sources while someone is within hearing/sight.
    local T = RR.TrainEntity
    if T then
        local p = getPlayer()
        local px, py = p and p:getX() or 0, p and p:getY() or 0
        for _, rec in ipairs(T.active) do
            if rec ~= e and rec.lastPose then
                local dx, dy = (rec.lastPose.x or 0) - px, (rec.lastPose.y or 0) - py
                local d2 = dx * dx + dy * dy
                if d2 <= SOUND_RANGE * SOUND_RANGE and RR.Sound then RR.Sound.update(rec, 1 / 60) end
                if d2 <= LIGHT_RANGE * LIGHT_RANGE and RR.LightsRender then RR.LightsRender.update(rec, 1 / 60) end
            end
        end
        -- v1.0.5 (MP sound stacking): client records were never pruned -- a loco
        -- that stopped being streamed (removed / re-spawned under a new id) kept
        -- its world emitter playing the last engine state, and re-spawns created a
        -- SECOND record for the same train -> doubled/stacked sound. Drop stale
        -- remote records (no snapshot for STALE_PRUNE_TICKS) and free their
        -- sound/light/collider assets; they re-create cleanly on the next
        -- snapshot (first sight = full).
        local rideRec = RR.Ride and RR.Ride.current
        for i = #T.active, 1, -1 do
            local rec = T.active[i]
            if rec ~= rideRec and not rec.rider
               and (rec._lastSeen or 0) > 0
               and (clientTicks - rec._lastSeen) > STALE_PRUNE_TICKS then
                if RR.Sound then pcall(function() RR.Sound.onRemove(rec) end) end
                if RR.LightsRender then pcall(function() RR.LightsRender.onRemove(rec) end) end
                if RR.Collider then pcall(function() RR.Collider.onRemove(rec) end) end
                if RR.CabClimate then pcall(function() RR.CabClimate.onRemove(rec) end) end
                table.remove(T.active, i)
            end
        end
    end
    -- NO client-side collider in MP: RR_Collider.ejectIntruders teleports zombies
    -- and the local player on this client only, which fights the server's
    -- authoritative collision (RR_ServerCollision). The server is the wall.
end

--------------------------------------------------------------------------
-- Per-render-frame pose computation (doc §3.2 Option A / §6.3). This pass
-- computes rec.renderPose (HUD / sound / lights / camera helper) from the
-- interpolation buffer or the driven local sim.
--------------------------------------------------------------------------
-- v1.0.2 (D1 spike fix): in-game the engine's animal sync is NOT smooth -- a
-- connected client saw the server-driven loco move in discrete jumps (one per
-- sync packet). Writing the per-frame interpolated/predicted pose to the LOCAL
-- animal object is a local-only render write: it never reaches the server, and
-- the next server packet simply refills the interpolation buffer, so the body
-- glides between authoritative positions instead of snapping. The co-op HOST
-- skips this: his server half already writes the live 60Hz pose in-process, so
-- the buffer would fight it (isServerProcess). Same reason the host keeps the
-- server-side rider pin; a connected client must pin its OWN body locally (the
-- engine does not mirror server-set positions of the local player back to the
-- owner), which is what makes the camera ride the train again.
--------------------------------------------------------------------------
local serverProc
local function isServerProcess()
    if serverProc ~= nil then return serverProc end
    serverProc = false
    pcall(function() serverProc = isServer() == true end)
    return serverProc
end

-- Mirror of RR_ServerTrain.applyPose (same call set). v1.0.2 fix: the visible
-- yaw is the AnimationPlayer angle, driven ONLY by setTargetAndCurrentDirection
-- (reference RR_TrainEntity.applyPose); setForwardDirection just sets a vector
-- and is gated for AI-suppressed animals, so it never turned the model. Snapping
-- the target each frame from the (already interpolated) pose keeps the yaw glued
-- to the rails. v1.0.3e: the target is fed through Body.smoothFacing first --
-- at a crawl the heading barely moves and per-frame re-snapping re-triggers the
-- clip-less cow animation state machine (visible stutter); smoothing + deadband
-- makes the yaw glide through corners at any speed. The pose used for physics
-- (lastPose/renderPose) stays the raw spline pose.
local function applyPoseLocal(rec, pose)
    local animal = rec and rec.animal
    if not (animal and pose) then return end
    pcall(function() animal:setX(pose.x) end)
    pcall(function() animal:setY(pose.y) end)
    pcall(function() animal:setZ(pose.z) end)
    if RR.Body and RR.Body.smoothFacing then
        local sx, sy, changed = RR.Body.smoothFacing(rec, pose.dirX or 0, pose.dirY or 0, frameDt)
        if changed then pcall(function() animal:setTargetAndCurrentDirection(sx, sy) end) end
    else
        pcall(function() animal:setTargetAndCurrentDirection(pose.dirX or 0, pose.dirY or 0) end)
    end
end

--------------------------------------------------------------------------
-- v1.0.2 (wall fix): the server ejects REMOTE players/zombies, but the engine
-- does not mirror server-set positions of the LOCAL player back to its own
-- screen (the same authority split that forced the local seat pin) -- so on a
-- connected client the owner walked straight through a parked loco. Every render
-- frame we eject the LOCAL player from any hull they are NOT seated on, with the
-- same nearest-edge math the server uses (RR_ServerCollision.ejectTarget).
-- v1.0.2 anti-twitch: a pure per-frame teleport fought the walk input and made
-- the owner convulse at the wall. While inside the hull we now freeze the walk
-- input (setBlockMovement, exactly what a vanilla car seat does) and push out;
-- the freeze is held while movement keys stay down (hard cap 0.8 s so an "away"
-- key always escapes), then released a few frames after the keys stop. The
-- server-side player teleport was removed: it wrote the same player to a second
-- edge point (offset by one RTT) and was the real convulsion source.
--------------------------------------------------------------------------
local wallBlocked = false
local wallBlockFrames = 0

local function ejectLocalPlayer(rec, pose)
    local p = getPlayer()
    if not (p and pose) then return end
    local size = 0.7
    if rec.animal then pcall(function() size = rec.animal:getAnimalSize() end) end
    local fx, fy = pose.dirX or 0, pose.dirY or -1
    if fx == 0 and fy == 0 then fx, fy = 0, -1 end
    local rx, ry = -fy, fx
    local len, wid = RR.Body.extents(size)
    -- v1.0.8 (SP v1.0.2 EJECT_PAD): the wall stands EJECT_PAD outside the raw
    -- hull for BOTH the containment test and the clamp target, so a player's
    -- centre lands against the plating, not half-sunk into it (the body radius).
    local pad = 0.30
    local hl, hw = len * 0.5 + pad, wid * 0.5 + pad
    local bias = RR.Body.LAT_BIAS or 0
    local dx, dy = p:getX() - pose.x, p:getY() - pose.y
    local pf = dx * fx + dy * fy
    local pr = dx * rx + dy * ry - bias
    if math.abs(pf) >= hl or math.abs(pr) >= hw then return end
    if (pose.z or 0) ~= nil and math.abs(p:getZ() - (pose.z or 0)) >= 1 then return end
    -- Inside the hull: freeze input so the walk update stops fighting the push.
    -- v1.0.17: do NOT reset wallBlockFrames every frame -- the old reset meant
    -- releaseWallBlock's counter never accumulated, so neither the 3-frame
    -- keys-up release nor the hard cap ever fired, and the player was pinned
    -- permanently at the hull ("approach the loco -> stuck, can't move").
    if not wallBlocked then
        wallBlocked = true
        wallBlockFrames = 0
    end
    pcall(function() p:setBlockMovement(true) end)
    -- Clamp ONTO the test boundary (m = 0): with target == test there is no dead
    -- band for the walk to creep through between frames -- the player stops like
    -- a vanilla wall. (The old +0.15 overshoot was the SP v1.0.1 jitter bug.)
    local nx, ny
    if (hw - math.abs(pr)) <= (hl - math.abs(pf)) then
        local npr = ((pr >= 0) and 1 or -1) * hw + bias
        nx = pose.x + pf * fx + npr * rx
        ny = pose.y + pf * fy + npr * ry
    else
        local npf = ((pf >= 0) and 1 or -1) * hl
        nx = pose.x + npf * fx + (pr + bias) * rx
        ny = pose.y + npf * fy + (pr + bias) * ry
    end
    pcall(function() p:setX(nx); p:setY(ny) end)
    pcall(function() p:setNextX(nx); p:setNextY(ny) end)
    -- v1.0.8 (SP EJECT_SYNC_LAST): re-stamp where the player came FROM so nothing
    -- rolls back to a position inside the hull.
    pcall(function() p:setLastX(nx); p:setLastY(ny) end)
end

-- Released only when the player is not seated on any loco (the seat pin owns the
-- block then). While the player keeps pushing INTO the wall the freeze holds; a
-- hard cap (0.8 s) guarantees an "away" key always escapes (walking backwards
-- still counts as a movement key, so we cannot just wait for keys-up).
local function movementKeysDown()
    local k = Keyboard
    if not k then return false end
    return k.isKeyDown(k.KEY_W) or k.isKeyDown(k.KEY_S) or k.isKeyDown(k.KEY_A) or k.isKeyDown(k.KEY_D)
        or k.isKeyDown(k.KEY_UP) or k.isKeyDown(k.KEY_DOWN) or k.isKeyDown(k.KEY_LEFT) or k.isKeyDown(k.KEY_RIGHT)
end

local function releaseWallBlock()
    if not wallBlocked then return end
    if RR.Ride and RR.Ride.current then return end
    wallBlockFrames = wallBlockFrames + 1
    -- v1.0.17: the cap fires even while the player keeps pushing (it used to be
    -- defeated by the per-frame counter reset -> permanent pin). The position
    -- clamp still holds the hull boundary every frame, so releasing the input
    -- freeze cannot let the player inside -- it just stops the "stuck forever"
    -- feel and lets them slide along / walk away.
    local CAP = 30   -- ~0.5 s of continuous pushing against the wall
    if wallBlockFrames >= CAP then
        wallBlocked = false
        pcall(function() getPlayer():setBlockMovement(false) end)
        return
    end
    if not movementKeysDown() and wallBlockFrames >= 3 then
        wallBlocked = false
        pcall(function() getPlayer():setBlockMovement(false) end)
    end
end

local lastMs
local function onRender()
    local now = 0
    if getTimestampMs then pcall(function() now = getTimestampMs() end) end
    if lastMs then
        frameDt = math.min(0.1, math.max(0.001, (now - lastMs) / 1000))
    end
    lastMs = now
    local T = RR.TrainEntity
    if not T then return end
    local p = getPlayer()
    local px, py = p and p:getX() or 0, p and p:getY() or 0
    for _, rec in ipairs(T.active) do
        if rec.animal and not rec.animal:isDead() then
            -- Doc §7 LOD: a remote loco beyond RENDER_RANGE is off-screen --
            -- skip its pose pass entirely (the record and its buffer stay warm).
            local dx, dy = rec.animal:getX() - px, rec.animal:getY() - py
            if dx * dx + dy * dy <= RENDER_RANGE * RENDER_RANGE then
                local pose
                if rec.derailed then
                    pose = rec.lastPose                    -- frozen wreck pose
                elseif RR.Ride and RR.Ride.current == rec then
                    -- Driven loco: render the local sim (smooth; on the local
                    -- server RTT~0 so it coincides with the server wall). v1.0.2
                    -- reverted: the server-truth buffer render made driving
                    -- visibly stuttery (20Hz segments + interp delay) for no
                    -- alignment gain on a local host.
                    local rb = rec._rollback
                    if rb and rb.to then
                        rb.t = rb.t + frameDt
                        local u = math.min(1, rb.t / rb.dur)
                        local eu = 1 - (1 - u) * (1 - u)   -- ease-out bridge
                        pose = blendPose(rb.from, rb.to, eu)
                        if u >= 1 then rec._rollback = nil end
                    else
                        pose = splinePose(rec, rec.distance) -- driven: local sim
                    end
                else
                    pose = bufferPose(rec)                 -- remote: snapshot interp
                end
                if pose then
                    rec.renderPose = pose
                    if not isServerProcess() then
                        -- Smooth the visible body locally (see applyPoseLocal note).
                        applyPoseLocal(rec, pose)
                        -- Force full visibility, mirroring the SP client (RR_TrainEntity):
                        -- a connected client's TestIfSeen judges the animal's ORIGIN square
                        -- only, so when that point is behind the camera/player the whole
                        -- 15-tile mesh fades out like a zombie. Pin alpha every rendered
                        -- frame so the loco stays visible ("always display"). Collider
                        -- segments are separate animals, not in T.active, so untouched.
                        pcall(function() rec.animal:setAlphaAndTarget(1.0) end)
                        -- Pin the local player to the SAME render pose this frame
                        -- (Ride.pinRider reads rec.renderPose), so the camera and
                        -- the body ride the train; the server keeps its own
                        -- authoritative pin for the OTHER clients' view.
                        if RR.Ride and RR.Ride.current == rec and RR.Ride.pinRider then
                            RR.Ride.pinRider(rec)
                        else
                            -- Not seated on this loco: keep the owner OUT of the
                            -- hull (the server's eject does not show locally).
                            ejectLocalPlayer(rec, pose)
                        end
                    end
                end
            end
        end
    end

    -- v1.0.3f periodic authoritative reconcile (see the constants above).
    recAcc = recAcc + frameDt
    if recAcc >= RECONCILE_EVERY then
        recAcc = 0
        for _, rec in ipairs(T.active) do
            -- v1.0.4 (reconcile fix): a healthy interpolation buffer plays one
            -- segment behind the newest snapshot BY DESIGN; comparing the render
            -- pose against the newest snapshot then false-triggers at speed
            -- (esp. the 5Hz MID band, where one segment > RECONCILE_DIST) and
            -- re-bases/snaps the model every RECONCILE_EVERY seconds. Only heal
            -- genuinely starved buffers: nothing playing and nothing queued.
            if rec.seg or (rec.seq and #rec.seq > 0) then
                -- buffer healthy: the render is intentionally behind -- skip.
            else
                local snap = (rec.seq and rec.seq[#rec.seq]) or rec.hold
                if snap and rec.animal and not rec.animal:isDead() then
                    local dx, dy = rec.animal:getX() - px, rec.animal:getY() - py
                    if dx * dx + dy * dy <= RENDER_RANGE * RENDER_RANGE then
                        local authPose
                        if rec.route and not rec._posFallback then
                            authPose = splinePose(rec, snap.distance or 0)
                        end
                        if not authPose then
                            authPose = { x = snap.x or 0, y = snap.y or 0, z = snap.z or 0,
                                         dirX = snap.dirX or 0, dirY = snap.dirY or -1 }
                        end
                        local rp = rec.renderPose
                        if rp then
                            local ex = rp.x - authPose.x
                            local ey = rp.y - authPose.y
                            local distErr = math.sqrt(ex * ex + ey * ey)
                            local cross = math.abs((rp.dirX or 0) * (authPose.dirY or 0)
                                                 - (rp.dirY or 0) * (authPose.dirX or 0))
                            if distErr > RECONCILE_DIST or cross > RECONCILE_ANG then
                                if RR.Ride and RR.Ride.current == rec then
                                    -- Driven loco: snap the SIM to authority and
                                    -- bridge the RENDER (same path as the
                                    -- snapshot rollback).
                                    local from = rec.renderPose or splinePose(rec, rec.distance)
                                    local gap = (snap.distance or rec.distance) - (rec.distance or 0)
                                    rec.distance = snap.distance or rec.distance
                                    rec.drive.v = snap.v or rec.drive.v
                                    rec.drive.notchEff = snap.ne or rec.drive.notchEff
                                    rec.drive.brakeLevel = snap.bl or rec.drive.brakeLevel
                                    rec._dCorr, rec._vCorr = nil, nil
                                    rec._predLock = PRED_LOCK_TIME
                                    rec.faceSign = snap.fs or rec.faceSign
                                    local to = splinePose(rec, rec.distance)
                                    if to and math.abs(gap) <= ROLLBACK_SNAP then
                                        rec._rollback = {
                                            from = from, to = to, t = 0,
                                            dur = math.max(ROLLBACK_DUR_MIN,
                                                          math.min(ROLLBACK_DUR_MAX, math.abs(gap) / RESYNC_SPEED)),
                                        }
                                    else
                                        rec._rollback = nil
                                    end
                                    print(string.format("[RailroaderMP] reconcile driven: errD=%.2f", distErr))
                                else
                                    -- Remote loco: re-base the buffer on truth and
                                    -- apply the authoritative pose (position +
                                    -- orientation) straight to the rendered model.
                                    if rec._posFallback then
                                        reanchorRoute(rec, authPose.x, authPose.y, authPose.dirX, authPose.dirY)
                                    end
                                    resetBuffer(rec)
                                    rec.hold = snap
                                    applyPoseLocal(rec, authPose)
                                    print(string.format("[RailroaderMP] reconcile remote: errD=%.2f", distErr))
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    releaseWallBlock()
end

Events.OnServerCommand.Add(receive)
Events.OnTick.Add(tick)
Events.OnRenderTick.Add(onRender)
RR.MPClient = Client
return Client
