--***********************************************************************
-- Railroader / RR_Sound  -- engine-sound adapter (Task 1.E)
--
-- Each spawned loco gets ONE world free-emitter (getWorld():getFreeEmitter),
-- which we OWN and reposition to the loco every tick. Multiple looped handles
-- ride on it (idle + run1..4 + wheel + brake apply/squeal), each with its own
-- volume/pitch set per tick from the drive state; one-shots (start/stop, clacks,
-- horn, brake release, compressor) are fired as needed.
--
-- Why a world emitter and not animal:getEmitter(): the character emitter has NO
-- playSoundLooped and its setPitch/setVolume fan out to all sub-emitters
-- (vocals/footsteps/extra) -- verified in decompiled B42. The world emitter gives
-- code-controlled loops with independent per-handle mixing. Cost: we setPos()
-- each tick (we already compute e.lastPose) and return the emitter on removal.
--
-- MP NETWORK NOTE (verified in decompiled B42, FMODSoundEmitter.playSound/
-- playSoundLooped): on a client, playSound()/playSoundLooped() ALSO emit a
-- PlaySoundPacket (emitter parent = moving object) or PlayWorldSoundPacket
-- (world free-emitter), which the server relays to EVERY OTHER client -- the
-- sender excluded. So a sound "played once per client" is heard N times per
-- listener (once local + once per other client's relay): the stacked, slightly
-- desynced duplicates drown out every other audio channel near the loco, and a
-- single event (e.g. an engine-stop on record teardown) rings out on ALL
-- clients. playSoundImpl()/playSoundLoopedImpl() queue the same FMOD playback
-- WITHOUT any network packet (the same local-only path reference mods use for
-- "transmit=false" sounds). Every playback below therefore goes through the
-- local-only helpers; events that must be heard by everyone are driven by the
-- server-authoritative state stream / event packets instead of client relays.
--
-- Pure mixing math lives in shared/RR_SoundConfig.lua (unit-tested). This file is
-- only the engine glue. All engine calls are pcall-wrapped (same defensive style
-- as the rest of the client layer) so a missing sound never aborts the tick.
--
-- Extra keys: Q = horn (tap), B = bell (toggle). Act on the loco you're driving
-- (RR_Ride.current) or, if none, the first spawned loco.
--***********************************************************************

print("[Railroader] RR_Sound.lua: loading...")
require("Railroader/RR_SoundConfig")
local Cfg = RR and RR.SoundConfig

local Sound = {}

--------------------------------------------------------------------------
-- Small guarded emitter helpers (handle may be nil/0 if a sound failed to load).
--------------------------------------------------------------------------
local function playLooped(em, name)
    local h = nil
    -- Local-only loop start: playSoundLoopedImpl() queues the loop without the
    -- PlayWorldSoundPacket one-shot relay (10 loops per spawned loco record used
    -- to make every other client burst engine/wheel/brake clips at the loco).
    -- Fall back to playSoundLooped if the *Impl binding is missing (audible
    -- beats silent; the relay is then one transient one-shot per loop start).
    local ok = pcall(function() h = em:playSoundLoopedImpl(name) end)
    if not ok or h == nil then
        h = nil
        pcall(function() h = em:playSoundLooped(name) end)
    end
    return h
end
local function playOnce(em, name, vol)
    -- Local-only one-shot: playSoundImpl() does NOT emit PlaySound/
    -- PlayWorldSound packets (the 3-arg form is proven in the WaterPump +
    -- Lifestyle reference mods; the 2-arg form is the same abstract method).
    -- Every client computes its own copy from the same server-authoritative
    -- state, so a relayed duplicate would stack -- the sound-overlap bug.
    local h = nil
    local ok = pcall(function() h = em:playSoundImpl(name, false, nil) end)
    if not ok or h == nil then
        h = nil
        local ok2 = pcall(function() h = em:playSoundImpl(name, nil) end)
        if not ok2 or h == nil then
            pcall(function() h = em:playSound(name) end)
        end
    end
    if vol and h and h ~= 0 then pcall(function() em:setVolume(h, vol) end) end
end
local function setVol(em, h, v)
    if h and h ~= 0 then pcall(function() em:setVolume(h, v) end) end
end
local function setPitch(em, h, p)
    if h and h ~= 0 then pcall(function() em:setPitch(h, p) end) end
end
-- Move `cur` toward `tgt` at a rate that spans the full 0..1 range in `tau` seconds
-- (linear). Used for the start-sequence crossfades + the engine-layer swell.
local function approach(cur, tgt, tau, dt)
    cur = cur or 0
    local step = (dt or 0) / math.max(tau or 0.2, 1e-3)
    if cur < tgt then return math.min(tgt, cur + step)
    elseif cur > tgt then return math.max(tgt, cur - step)
    else return cur end
end

--------------------------------------------------------------------------
-- onSpawn(e): allocate the emitter, start the continuous loops (engine + wheel +
-- brake, all at volume 0 until update() sets them), fire the start one-shot.
--------------------------------------------------------------------------
function Sound.onSpawn(e)
    if not Cfg or not e or not e.animal then return end
    local em = nil
    pcall(function()
        local x, y, z = e.animal:getX(), e.animal:getY(), e.animal:getZ()
        em = getWorld():getFreeEmitter(x, y, z)
        getWorld():takeOwnershipOfEmitter(em)   -- persist across ticks (don't let world recycle it)
    end)
    if not em then print("[Railroader] RR_Sound: could not get a free emitter"); return end

    local snd = {
        emitter       = em,
        engineIdle    = playLooped(em, Cfg.names.engineIdle),
        engineRun     = {},
        wheel         = playLooped(em, Cfg.names.wheelRoll),
        brakeApply    = playLooped(em, Cfg.names.brakeApply),
        brakeSqueal   = playLooped(em, Cfg.names.brakeSqueal),
        bell          = nil,
        bellOn        = false,
        axleIdx       = {},          -- per-axle last rail-joint index (filled on first update)
        compTimer     = 0,
        prevBrake     = 0,
    }
    for i, nm in ipairs(Cfg.names.engineRun) do
        snd.engineRun[i] = playLooped(em, nm)
    end

    e.snd = snd
    -- Engine-start mechanic: a spawned loco is COLD. Do NOT fire the start one-shot
    -- or an idle here -- update() keeps every engine layer silent until e.engine is
    -- running (the driver cranks it with W). The idle/run loops exist at volume 0.
    Sound.update(e, 0)                    -- set initial mix (all engine layers silent while off)
end

--------------------------------------------------------------------------
-- engineRunning(e): is the prime mover turning? Horn and bell are AIR devices on a
-- GP7 -- the compressor that feeds them hangs off the diesel -- so a dead engine
-- means a dead horn and a dead bell. (Coarse model: we don't track reservoir
-- pressure, we just require the engine.) A record with no e.engine at all is legacy
-- always-on, same convention as the audio mix below. FAILS CLOSED: a record
-- with no engine state is treated as OFF, never as "legacy always-on" -- the
-- nil-engine branch was a phantom-engine source (an MP record whose engine
-- field had not arrived yet would hum the idle/run loops on an OFF loco).
--------------------------------------------------------------------------
local function engineRunning(e)
    return (e ~= nil) and (e.engine ~= nil) and (e.engine.running == true)
end

-- sayBad: the vanilla "you can't do that" channel -- a red halo over the driver's
-- head. Same call RR_Ride uses to refuse an unlicensed cab; getText returns the KEY
-- when a translation is missing, so fall back to plain text.
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
-- update(e, dt): reposition the emitter and set every layer's volume/pitch from
-- the current drive state. Called from RR_TrainEntity.onTick after e.lastPose.
--------------------------------------------------------------------------
function Sound.update(e, dt)
    local snd = e and e.snd
    if not snd or not snd.emitter then return end
    local em = snd.emitter

    -- Emitter position. When the player is SEATED in THIS loco, place the emitter AT the
    -- listener (the player/camera), not at the body centre. The driver sits at the cab -- a
    -- fixed offset from the body centre -- so as the loco turns, that offset rotates in world
    -- space and a body-centre emitter ORBITS the listener: the mix pans L/R and its volume
    -- swims with the loco's heading (the reported bug). Emitter == listener => distance 0,
    -- always centred and constant no matter how the loco is turned. From OUTSIDE the cab we
    -- keep it on the body so a passer-by hears it correctly positioned.
    local pose   = e.lastPose
    local seated = RR.Ride and RR.Ride.current == e
    if seated then
        local p = getPlayer()
        if p then pcall(function() em:setPos(p:getX(), p:getY(), p:getZ()) end)
        elseif pose then pcall(function() em:setPos(pose.x, pose.y, pose.z) end) end
    elseif pose then
        pcall(function() em:setPos(pose.x, pose.y, pose.z) end)
    end

    -- Simulated sound propagation (doc §7.1): each class falls off linearly to
    -- silence at its range -- ambient 50 / brake 100 / horn 200 tiles. Seated
    -- in the cab the listener IS the source, so distance 0 -> full volume.
    local dist = 0
    if not seated then
        local p = getPlayer()
        if p and pose then
            local ddx, ddy = p:getX() - pose.x, p:getY() - pose.y
            dist = math.sqrt(ddx * ddx + ddy * ddy)
        end
    end
    local gA = Cfg.distanceGain(dist, Cfg.RANGE_AMBIENT)
    local gB = Cfg.distanceGain(dist, Cfg.RANGE_BRAKE)
    local gH = Cfg.distanceGain(dist, Cfg.RANGE_HORN)

    local speed    = (e.drive and e.drive.v) or 0
    local notchEff = (e.drive and e.drive.notchEff) or (e.throttle or 0)
    local brakeLvl = (e.drive and e.drive.brakeLevel) or 0

    -- Engine: crossfade idle + run1..4 by throttle notch -- but ONLY while the prime
    -- mover is actually running (engine-start mechanic). A cold/off engine keeps every
    -- engine layer silent; the starter loop (crankStart/Stop) covers cranking instead.
    local running = engineRunning(e)                        -- nil engine = OFF (fails closed)
    -- The whole idle/run layer swells IN when the diesel catches and OUT on shutdown,
    -- so it doesn't snap on over the catch "vroom" or cut off dead. (Part of the start
    -- crossfade -- #1.)
    snd.engineFade = approach(snd.engineFade or 0, running and 1 or 0, Cfg.ENGINE_FADE, dt)
    do
        local ef = snd.engineFade
        local w  = Cfg.engineMix(notchEff)
        setVol(em, snd.engineIdle, w[1] * ef * gA)
        for i = 1, #snd.engineRun do setVol(em, snd.engineRun[i], (w[i + 1] or 0) * ef * gA) end
    end

    -- Start-sequence layers (fuel-pump prime + starter crank), CROSSFADED by engine phase
    -- rather than hard start/stop, so prime -> crank -> catch flows as one continuous event.
    -- Each layer's volume eases toward a per-phase target; its loop is lazily started when
    -- first needed and stopped once it has faded to silence. update() is the sole driver --
    -- Sound.primeStart/crankStart/... are now no-ops kept only for call-site compatibility.
    do
        local phase    = e.engine and e.engine.phase
        -- The start sequence is a transient state of an OFF engine: prime/crank
        -- loops must never sound while the prime mover is RUNNING, and a stale
        -- client phase (the delta wire only carried ep on full/resync packets
        -- before v1.0.10) must never leave the starter humming on an OFF loco.
        -- Belt-and-braces on top of the server now sending ep change-only.
        local primeTgt = (phase == "priming")  and not running and Cfg.PRIME_MASTER or 0
        local crankTgt = (phase == "cranking") and not running and Cfg.CRANK_MASTER or 0
        snd.primeVol = approach(snd.primeVol or 0, primeTgt, Cfg.START_FADE, dt)
        snd.crankVol = approach(snd.crankVol or 0, crankTgt, Cfg.START_FADE, dt)

        if primeTgt > 0 and not snd.primeLoop then snd.primeLoop = playLooped(em, Cfg.names.enginePrime) end
        if snd.primeLoop then
            setVol(em, snd.primeLoop, snd.primeVol * gA)
            if snd.primeVol <= 0.001 and primeTgt == 0 then
                pcall(function() em:stopSound(snd.primeLoop) end); snd.primeLoop = nil
            end
        end

        if crankTgt > 0 and not snd.crankLoop then snd.crankLoop = playLooped(em, Cfg.names.engineCrank) end
        if snd.crankLoop then
            setVol(em, snd.crankLoop, snd.crankVol * gA)
            if snd.crankVol <= 0.001 and crankTgt == 0 then
                pcall(function() em:stopSound(snd.crankLoop) end); snd.crankLoop = nil
            end
        end
    end

    -- Wheels: volume by speed only. We deliberately DON'T setPitch here: on a shared
    -- emitter B42's setPitch appears to bleed onto the other handles (engine/horn), so
    -- pitching the wheel by speed was also raising the engine/horn pitch with throttle
    -- (wrong). Speed is already conveyed by the volume ramp + the distance-triggered
    -- clack tempo, so dropping the roll's pitch shift costs little. (If we ever want it
    -- back, give the wheel roll its OWN emitter so its pitch can't leak.)
    local wvol = Cfg.wheelMix(speed)
    setVol(em, snd.wheel, wvol * gA)

    -- Brakes: apply hiss + low-speed squeal; release one-shot on the falling edge.
    local apply, squeal = Cfg.brakeMix(brakeLvl, speed)
    setVol(em, snd.brakeApply, apply * gB)
    setVol(em, snd.brakeSqueal, squeal * gB)
    if snd.prevBrake > Cfg.BRAKE_RELEASE_EDGE and brakeLvl <= Cfg.BRAKE_RELEASE_EDGE then
        playOnce(em, Cfg.names.brakeRelease, gB)
    end
    snd.prevBrake = brakeLvl

    -- Rail-joint clacks: 8 wheel sources (4 axles x left/right rail, joints STAGGERED half
    -- a rail) each clack as they cross a joint -- the real dense jointed-track clatter of a
    -- 4-axle Geep, not stylised truck pairs (see RR_SoundConfig.clackOffsets). We always
    -- track each wheel's joint index (so crossing the speed threshold never dumps a burst)
    -- but only PLAY while moving above CLACK_MIN_MPS.
    do
        local d      = e.distance or 0
        local moving = math.abs(speed) > Cfg.CLACK_MIN_MPS
        local offs   = Cfg.clackOffsets()
        local names  = Cfg.names.clacks
        for i = 1, #offs do
            local jidx = math.floor((d + offs[i]) / Cfg.RAIL_LEN)
            if snd.axleIdx[i] == nil then
                snd.axleIdx[i] = jidx                     -- init: no clack on first frame
            elseif jidx ~= snd.axleIdx[i] then
                snd.axleIdx[i] = jidx
                if moving then
                    local pick = 1
                    pcall(function() pick = ZombRand(#names) + 1 end)
                    if pick < 1 or pick > #names then pick = 1 end
                    playOnce(em, names[pick], Cfg.CLACK_MASTER * gA)
                end
            end
        end
    end

    -- Bell rides the horn's 200-tile air-device class: re-apply each tick so a
    -- ringing bell fades with distance instead of staying at full volume.
    if snd.bell then
        setVol(em, snd.bell, Cfg.BELL_MASTER * gH)
    end

    -- Air dies with the diesel: a horn held (or a bell left ringing) when the engine is
    -- shut down or stalls on empty goes quiet the same tick. Both stops play their normal
    -- release, so it reads as the driver letting go rather than the sound being cut.
    if not running then
        if snd.hornOn then Sound.hornStop() end
        if snd.bellOn then Sound.toggleBell(e) end
    end

    -- Horn attack: swell the held horn up to full over HORN_ATTACK seconds (an air horn
    -- builds pressure; it must not slam on). Done here, not as a fade inside the loop
    -- file, which would dip on every wrap.
    if snd.hornOn and snd.hornLoop then
        local rate = Cfg.HORN_MASTER / math.max(Cfg.HORN_ATTACK, 1e-3)
        snd.hornVol = math.min(Cfg.HORN_MASTER, (snd.hornVol or 0) + rate * (dt or 0))
        setVol(em, snd.hornLoop, snd.hornVol * gH)
    elseif snd.hornReleasing and snd.hornLoop then
        -- Release: FADE the loop out (the rr_horn_stop one-shot plays the decay on top).
        -- Hard-stopping it mid-cycle was the "spike" the driver heard on Q-up.
        local rate = Cfg.HORN_MASTER / math.max(Cfg.HORN_RELEASE, 1e-3)
        snd.hornVol = math.max(0, (snd.hornVol or 0) - rate * (dt or 0))
        setVol(em, snd.hornLoop, snd.hornVol * gH)
        if snd.hornVol <= 0.001 then
            pcall(function() em:stopSound(snd.hornLoop) end)
            snd.hornLoop = nil; snd.hornReleasing = false
        end
    end

    -- Zombie attraction: emit a WorldSoundManager event (global addSound) every
    -- WORLD_SOUND_PERIOD seconds with a radius = the loudest current source. FMOD
    -- playback above is inaudible to the AI; this is what actually draws zombies.
    -- A loco is loud -- idle pulls a little, full throttle a lot, horn the horde.
    -- Impact-noise throttle (Sound.impactNoise) runs down here, where dt lives. If
    -- Sound.update never runs for this loco the cooldown just stays at 0 -- impacts
    -- then emit unthrottled, which is noisier but never wrong.
    if (e._impactNoiseCd or 0) > 0 then
        e._impactNoiseCd = math.max(0, e._impactNoiseCd - (dt or 0))
    end

    snd.noiseTimer = (snd.noiseTimer or 0) + (dt or 0)
    if snd.noiseTimer >= Cfg.WORLD_SOUND_PERIOD then
        snd.noiseTimer = 0
        if pose then
            local cranking = e.engine and e.engine.phase == "cranking"
            local priming  = e.engine and e.engine.phase == "priming"
            -- `running` gates the engine idle floor: a shut-down loco makes no engine
            -- noise (so no phantom attraction). Same flag as the engine audio above.
            local r = Cfg.worldNoiseRadius(notchEff, speed, snd.bellOn, snd.hornOn, cranking, running, priming)
            if r > 0 then   -- stopped + silent => emit nothing (no attraction)
                pcall(function()
                    addSound(e.animal, math.floor(pose.x), math.floor(pose.y), math.floor(pose.z or 0), r, r)
                end)
            end
        end
    end

    -- Air compressor: a full pump cycle every COMPRESSOR_PERIOD seconds -- but ONLY while
    -- the diesel is running. On a GP7 the compressor is belt/gear-driven off the prime
    -- mover, so a shut-down loco can't pump air (its timer just holds). Same `running`
    -- gate as the engine audio + world noise.
    if running then
        snd.compTimer = (snd.compTimer or 0) + (dt or 0)
        if snd.compTimer >= Cfg.COMPRESSOR_PERIOD then
            snd.compTimer = 0
            playOnce(em, Cfg.names.compressor, Cfg.COMPRESSOR_MASTER * gA)
        end
    end

    -- The engine state this tick finished with -- the pre-stop state for the
    -- one-shot callers, which stop the engine BEFORE calling Sound.engineStop.
    -- Gates the shutdown spin-down: an already-off loco must never play it.
    snd.lastRunning = running

    pcall(function() em:tick() end)
end

--------------------------------------------------------------------------
-- Engine start/stop one-shots + starter loop (engine-start mechanic). Driven from
-- RR_Ride's crank poll (hold W) and shutdown (hold S), and from RR_TrainEntity on a
-- fuel-out stall. All emitter calls guarded; a missing sound never breaks the tick.
--   crankStart/Stop : the looped starter-motor sound while the driver cranks.
--   engineCatch     : the "vroom" when the diesel fires (crank -> warm-up).
--   engineFail      : failed catch / dead-battery click.
--   engineStop      : shutdown / stall spin-down (also used by RR_TrainEntity stall).
--------------------------------------------------------------------------
-- FUEL PRIME + CRANK loops are now CROSSFADED by engine phase inside Sound.update
-- (see the "Start-sequence layers" block) so prime -> crank -> catch flows smoothly.
-- These four are kept as NO-OPS purely so RR_Ride's existing call sites don't error;
-- the phase in e.engine drives everything.
function Sound.primeStart(e) end
function Sound.primeStop(e)  end
function Sound.crankStart(e) end
function Sound.crankStop(e)  end

-- Engine start/stop one-shots go through the loco ANIMAL's own character emitter
-- (positional + reliable), NOT our manually-ticked world free-emitter: the looped
-- layers (idle/run/brake) work on the free emitter, but a lone one-shot playSound
-- on it proved inaudible (why the catch "vroom" never sounded while the idle loop
-- did). LOCAL-ONLY (getEmitter():playSoundImpl): in MP the server-authoritative
-- transition hook in RR_MPClient.apply calls these on EVERY client, so a relayed
-- duplicate (IsoGameCharacter:playSound -> PlaySoundPacket) would stack the sound
-- on each listener once per client -- the overlap bug. Falls back to the world
-- free-emitter (also local-only), then to the transmit variant as a last resort
-- (audible beats silent).
local function playEvent(e, name, vol)
    local a = e and e.animal
    if a then
        local ok = pcall(function() a:getEmitter():playSoundImpl(name, nil) end)
        if ok then return end
        pcall(function() a:playSound(name) end)
        return
    end
    local snd = e and e.snd
    if snd and snd.emitter then playOnce(snd.emitter, name, vol) end
end

function Sound.engineCatch(e)
    -- Only on an actual catch edge: a record that never saw the engine OFF must
    -- not "vroom" (a late joiner near a running loco, or a spurious re-call).
    local snd = e and e.snd
    if snd and snd.lastRunning ~= false then return end
    playEvent(e, Cfg.names.engineStart)
end

function Sound.engineFail(e)
    playEvent(e, Cfg.names.startFail, Cfg.CRANK_MASTER)
end

function Sound.engineStop(e)
    Sound.crankStop(e)
    Sound.primeStop(e)
    -- Only a REAL shutdown: an already-off loco must not play the spin-down
    -- (the "exit / record teardown plays engine-off sound" bug). Callers stop
    -- the engine BEFORE calling us, so lastRunning is the pre-stop state.
    local snd = e and e.snd
    if snd and snd.lastRunning == true then
        playEvent(e, Cfg.names.engineStop)
    end
end
Sound.engineStall = Sound.engineStop   -- same spin-down when it dies on empty

--------------------------------------------------------------------------
-- actionLoopStart(x,y,z, name) / actionLoopStop(h): a stoppable positional loop for a
-- timed action (refuelling etc.). Uses the WORLD free-emitter path -- the same one the
-- switch-throw fix uses -- because self.character:playSound proved silent in this B42
-- build (both our loose .wav AND vanilla fuel events went inaudible on the player
-- emitter). Vanilla fuel sounds ARE registered GameSounds, so they play fine by name on
-- a world emitter. Returns a handle (nil on failure); pass it to actionLoopStop.
--------------------------------------------------------------------------
-- IMPORTANT (verified in decompiled IsoWorld.update, ~:2881): the world only ticks
-- emitters that are in its `currentEmitters` list, and it is that TICK which actually
-- starts a queued sound. getFreeEmitter() ADDS the emitter to currentEmitters; DO NOT
-- takeOwnershipOfEmitter here -- that REMOVES it from the list, so the world never ticks
-- it, the queued sound never starts, and refuelling is silent (the bug). Left in the
-- world's list, it is ticked (sound starts), and once we stopSound it (or the loop is
-- otherwise empty) the world recycles it back to the free pool on its own -- no leak,
-- no manual tick needed. (The LOCO emitter takes ownership because RR_Sound.update ticks
-- it by hand every frame; a one-off action sound has no such per-tick driver.)
function Sound.actionLoopStart(x, y, z, name)
    local h = nil
    pcall(function()
        local em = getWorld():getFreeEmitter(x, y, z)
        h = { emitter = em, id = playLooped(em, name) }
    end)
    return h
end

function Sound.actionLoopStop(h)
    if not h or not h.emitter then return end
    pcall(function()
        if h.id then h.emitter:stopSound(h.id) end
    end)
end

--------------------------------------------------------------------------
-- onRemove(e): stop the loops and return the emitter so it doesn't leak. Called
-- from RR_TrainEntity.clear() and from RR_MPClient's stale-record prune. A
-- record teardown is NOT a shutdown: the real spin-down plays once on the
-- engine's running->off EDGE (RR_MPClient.apply / RR_Ride), so ANY one-shot here
-- is a duplicate -- and on an idling loco it rang again every approach/leave
-- cycle ("engine-off sound keeps playing after getting off"). Teardown is silent
-- by design: the loops just stop and the emitter is recycled.
--------------------------------------------------------------------------
function Sound.onRemove(e)
    local snd = e and e.snd
    if not snd then return end
    local em = snd.emitter
    if em then pcall(function() em:stopAll() end) end
    if em then pcall(function() getWorld():returnOwnershipOfEmitter(em) end) end
    e.snd = nil
end

--------------------------------------------------------------------------
-- worldOneShot(pose, name, vol): a local-only one-shot at a world position via a
-- temporary free emitter. The world ticks (and later recycles) it; playOnce is
-- local-only, so no PlayWorldSoundPacket relay -- every client that has the loco
-- record plays its own copy from the server-authoritative impact event instead.
--------------------------------------------------------------------------
local function worldOneShot(pose, name, vol)
    if not pose then return end
    pcall(function()
        local em = getWorld():getFreeEmitter(pose.x, pose.y, pose.z or 0)
        if em then playOnce(em, name, vol) end
    end)
end

--------------------------------------------------------------------------
-- crushImpact(e): one-shot thud when the loco runs a zombie over (Task 1.H,
-- called from RR_Crush on a lethal hit). Plays on the loco's own emitter (already
-- repositioned to the loco each tick); falls back to a world sound at the last
-- pose if the emitter isn't up yet. Throttling is the caller's job (RR_Crush).
--------------------------------------------------------------------------
function Sound.crushImpact(e)
    if not Cfg then return end
    local snd = e and e.snd
    if snd and snd.emitter then
        playOnce(snd.emitter, Cfg.names.crushHit, Cfg.CRUSH_MASTER)
        return
    end
    local pose = e and e.lastPose
    if pose then
        worldOneShot(pose, Cfg.names.crushHit, Cfg.CRUSH_MASTER)
    end
end

--------------------------------------------------------------------------
-- squelch(e): the blood-splatter half of a DOWNED crush kill (v1.0.8, SP v1.0.2
-- runOverFoley): a body already on the ground is pulped, not thrown -- vanilla's
-- own car plays the BloodSplatter squelch for exactly that. A dedicated server
-- has no audio, so the impact event's `downed` flag triggers this on every client
-- instead; the blood decal itself is applied server-side before the kill.
-- Wrapped: an unregistered sound name must never break the crush.
--------------------------------------------------------------------------
function Sound.squelch(e)
    if not e then return end
    local pose = e.lastPose
    if not pose and e.animal then
        pcall(function() pose = { x = e.animal:getX(), y = e.animal:getY(), z = e.animal:getZ() } end)
    end
    if not pose then return end
    worldOneShot(pose, "BloodSplatter", 1)
end

--------------------------------------------------------------------------
-- hardImpact(e, absSpeed, derailed): tiered HARD-collision foley (Task 1.N) -- the loco
-- drives into a railcar / another loco. The layers (speed tier + a derail wreck boom) are
-- chosen by the pure RR_SoundConfig.hardImpactLayers; we just play each through the loco
-- ANIMAL's own emitter (playEvent), the reliable one-shot path the VEHICLE crash + engine
-- one-shots already use. Called ONCE per contact from RR_TrainEntity's HARD-impact block
-- (its _hardImpactDone latch dedups, so holding the throttle against a wall won't machine-gun).
--------------------------------------------------------------------------
function Sound.hardImpact(e, absSpeed, derailed)
    if not Cfg or not Cfg.hardImpactLayers or not e then return end
    local layers = Cfg.hardImpactLayers(absSpeed, derailed)
    for i = 1, #layers do
        playEvent(e, layers[i].name, layers[i].volume)
    end
    -- ...and let the ZOMBIES hear it too (the layers above are FMOD-only). NOT on a derail:
    -- there the noise depends on WHY it derailed (a strike vs simply running off a broken
    -- open end), which only TrainEntity.derail knows -- it emits its own impactNoise.
    if not derailed then
        Sound.impactNoise(e, "hard", absSpeed)
    end
end

--------------------------------------------------------------------------
-- impactNoise(e, kind, absSpeed, x, y, z, derailed): the zombie-audible half of a
-- COLLISION (Task 1.N). Crash foley is FMOD playback and the AI is deaf to it, so every
-- contact also fires a ONE-SHOT WorldSoundManager event -- the same channel as the
-- periodic engine noise in Sound.update, just louder and momentary. Radius comes from
-- the pure Cfg.impactNoiseRadius (kind + speed tier + derail); kind is "smashable" /
-- "barrier" / "vehicle" / "hard".
--
-- x/y/z default to the loco itself; pass the CONTACT point where the caller has it, so
-- zombies walk to the smashed car rather than to wherever the loco ended up.
--
-- Throttled by IMPACT_NOISE.MIN_INTERVAL so ploughing through a fence line is one bang
-- instead of one per post -- but a LOUDER impact inside the window still fires (a car
-- wreck must not be swallowed by the fence it just followed).
--------------------------------------------------------------------------
function Sound.impactNoise(e, kind, absSpeed, x, y, z, derailed)
    if not (Cfg and Cfg.impactNoiseRadius and e) then return end
    local r = Cfg.impactNoiseRadius(kind, absSpeed, derailed)
    if not r or r <= 0 then return end
    if (e._impactNoiseCd or 0) > 0 and r <= (e._impactNoiseLast or 0) then return end
    e._impactNoiseCd   = (Cfg.IMPACT_NOISE and Cfg.IMPACT_NOISE.MIN_INTERVAL) or 0.15
    e._impactNoiseLast = r

    if not (x and y) then
        local a = e.animal
        if a then
            pcall(function() x, y, z = a:getX(), a:getY(), a:getZ() end)
        end
        if not (x and y) then
            local pose = e.lastPose
            if not pose then return end
            x, y, z = pose.x, pose.y, pose.z
        end
    end
    pcall(function()
        addSound(e.animal, math.floor(x), math.floor(y), math.floor(z or 0), r, r)
    end)
end

--------------------------------------------------------------------------
-- Horn (Q, tap) + bell (B, toggle). Target the ridden loco, else the first one.
--------------------------------------------------------------------------
-- Horn and bell are CAB controls: only the SEATED driver works them. (There used to be
-- a "first spawned loco" fallback, which meant pressing Q on foot honked a loco across
-- the map -- and Q is also the vanilla shout key, so it fired constantly.)
local function currentLoco()
    return (RR.Ride and RR.Ride.current) or nil
end

-- Horn = HELD (Q). Press: attack one-shot + start the sustained loop. Release:
-- stop the loop + play the release tail, so a long press = a long horn. We track
-- the horning loco so release stops the same one even if the "current" loco changes.
Sound._hornE = nil

-- All three horn phases are the REAL recording (rr_horn.wav), cut at one common gain so
-- attack -> sustain -> release stay continuous in level, exactly like the source:
--   start : the recording's true onset (fades out over its last 40 ms)
--   loop  : the recording's sustain, rebuilt as a 1 s pitch-synchronous granular loop --
--           real grains, phase-locked and wrapped circularly, so it is seamless and does
--           NOT repeat audibly (a short slice of the raw sustain tremolo'd like a siren).
--           Measured timbre match to the source: 99%.
--   stop  : the recording's true decay tail.
-- The loop swells in over HORN_ATTACK while the start one-shot fades out -> they cross
-- over cleanly instead of doubling, and no fade is baked into the loop (that would dip
-- on every wrap).
-- hornGain(e): the horn's 200-tile falloff for THIS listener (driver in the cab
-- -> 1; a remote observer -> attenuated to 0 at Cfg.RANGE_HORN tiles).
local function hornGain(e)
    local snd = e and e.snd
    if not snd or not snd.emitter then return 1 end
    local p = getPlayer()
    if not p then return 1 end
    local pose = e.lastPose
    if not pose and e.animal then
        pose = { x = e.animal:getX(), y = e.animal:getY(), z = e.animal:getZ() }
    end
    if not pose then return 1 end
    local dx, dy = p:getX() - pose.x, p:getY() - pose.y
    return Cfg.distanceGain(math.sqrt(dx * dx + dy * dy), Cfg.RANGE_HORN)
end

-- hornOnLocomotive(e): start the horn on an EXPLICIT record -- the local driver
-- (Sound.hornStart, key poll) or a remote observer who just got the server's
-- "horn" edge event. Beyond the 200-tile range nothing plays at all.
function Sound.hornOnLocomotive(e)
    if not e or not e.snd then return end
    local snd = e.snd
    if snd.hornOn then return end
    -- Air gate only applies to the LOCAL driver: a remote observer plays the
    -- horn because the server accepted it (the diesel was running over there).
    local localDriver = (RR.Ride and RR.Ride.current == e)
    if localDriver and not engineRunning(e) then
        sayBad("IGUI_RR_NoAir", "The engine is dead -- there's no air for the horn")
        return
    end
    local g = hornGain(e)
    if g <= 0 then return end            -- beyond horn range: inaudible, skip
    -- If a previous release is still fading its loop out, stop it now so we don't orphan it.
    if snd.hornLoop then pcall(function() snd.emitter:stopSound(snd.hornLoop) end); snd.hornLoop = nil end
    snd.hornReleasing = false
    playOnce(snd.emitter, Cfg.names.hornStart, Cfg.HORN_MASTER * g)
    snd.hornLoop = playLooped(snd.emitter, Cfg.names.hornLoop)
    snd.hornVol  = 0
    setVol(snd.emitter, snd.hornLoop, 0)
    snd.hornOn = true
    Sound._hornE = e
end

function Sound.hornStart()
    Sound.hornOnLocomotive(currentLoco())
end

-- hornStop(e): e defaults to the loco that started the horn (key release). update()
-- passes an explicit record when the engine dies under a held horn.
-- hornOffLocomotive(e): stop the horn on an explicit record (driver release or a
-- remote observer's "horn off" edge event). The release tail is distance-gated too.
function Sound.hornOffLocomotive(e)
    e = e or Sound._hornE
    if Sound._hornE == e then Sound._hornE = nil end
    if not e or not e.snd or not e.snd.hornOn then return end
    local snd = e.snd
    -- Don't hard-stop the loop here -- flag it for the fade-out in update() (the abrupt
    -- mid-cycle cut was the click/spike on release). The release tail plays on top now.
    snd.hornOn        = false
    snd.hornReleasing = true
    local g = hornGain(e)
    if g > 0 then playOnce(snd.emitter, Cfg.names.hornStop, Cfg.HORN_MASTER * g) end
end

function Sound.hornStop(e)
    Sound.hornOffLocomotive(e)
end

-- toggleBell(e): e defaults to the cab you're sitting in (the L key). update() passes
-- an explicit record to silence a ringing bell when the engine dies. Silencing is
-- always allowed; only STARTING the bell needs the engine (it's air-rung too).
function Sound.toggleBell(e)
    e = e or currentLoco()
    if not e or not e.snd then return end
    local snd = e.snd
    if snd.bellOn then
        if snd.bell then pcall(function() snd.emitter:stopSound(snd.bell) end) end
        snd.bell = nil; snd.bellOn = false
        print("[Railroader] bell OFF")
    elseif not engineRunning(e) then
        sayBad("IGUI_RR_NoAir", "The engine is dead -- there's no air for the bell")
    else
        snd.bell = playLooped(snd.emitter, Cfg.names.bell)
        setVol(snd.emitter, snd.bell, Cfg.BELL_MASTER)
        snd.bellOn = true
        print("[Railroader] bell ON")
    end
end

-- Bell = toggle (L, discrete press). NOT B -- vanilla binds B to the crafting menu.
-- Horn = held: polled each tick (isKeyDown is the reliable held-state check; OnKey*
-- events only fire on edges -- same reason the brake is polled). Q is also vanilla
-- "Shout" + opens the gesture radial menu ("Emote") on a long hold -- RR_Ride mutes
-- the yell (setCanShout false) and unbinds "Emote" while seated, so in the cab Q only
-- sounds the horn.
local function onKeyDown(key)
    if key == Keyboard.KEY_L then Sound.toggleBell() end
end
Events.OnKeyStartPressed.Add(onKeyDown)

local hornWasDown = false
local function hornTick()
    -- (v1.0.1) Direct call, not pcall: a per-tick `pcall(function() ... end)` allocates a
    -- closure every frame the horn is polled, and isKeyDown cannot throw (see RR_Ride).
    local down = Keyboard.isKeyDown(Keyboard.KEY_Q)
    if down and not hornWasDown then
        Sound.hornStart()
    elseif (not down) and hornWasDown then
        Sound.hornStop()
    end
    hornWasDown = down
end
Events.OnTick.Add(hornTick)

print("[Railroader] RR_Sound.lua: loaded OK (Cfg=" .. tostring(Cfg ~= nil) .. "). Q(hold)=horn L=bell.")

RR = RR or {}
RR.Sound = Sound

return Sound
