# Railroader client
- RR_MPClient.lua: server snapshot/input bridge; wire decode (delta distance int16mm + controls byte +
  changed-only engine/lights; deltas dropped until a full/resync baseline); ~20Hz snapshots ->
  per-render-frame route-distance Hermite interpolation (spline pose, rail-exact), switch re-anchor
  mirror, hold/capped extrapolation on loss; driven loco runs local Drive.step (client-side prediction)
  with small-error blending and authoritative ROLLBACK on large divergence; starvation threshold scales
  with the observed snapshot cadence (FAR 1Hz never spams resync); starved remote buffer fetches the
  server's retained snapshot ring (resync/history). v1.0.2 render mode (D1 spike fix): a connected client
  re-applies the per-frame interpolated/predicted pose to the LOCAL animal (applyPoseLocal -- a local-only
  render write; the engine's coarse animal sync no longer shows a segment-teleporting body) and pins its
  OWN rider (Ride.pinRider, camera rides the train); the co-op host skips both (isServerProcess -- its
  server half already writes the live pose/pin in-process).
  v1.0.4: switch-route fix -- apply() no longer overwrites a switch net's through-route with the base
  registry route (that silently reverted routing to the DEFAULT branch every packet, so the client
  predicted the default direction at a thrown switch and rubber-banded on every snapshot); applySwitches
  folds the server's authoritative switch states (now riding the full "state" snapshot) into TrackGraph
  and re-anchors/re-bases affected locos only when the state actually changed -- late joiners can no
  longer keep predicting the default branch. reanchorNets keeps the interpolation buffer when the
  thrown switch is AHEAD of a train (shared prefix, parameterization unchanged) and only resets when
  the train already crossed the fork -- a player throwing a switch at a faraway junction never
  freezes a watching client's train; the "switch" event re-anchors its net unconditionally (the
  thrower may already hold the state optimistically).
  v1.0.4 audit fixes: (a) the periodic authoritative reconcile now only heals STARVED buffers (no
  segment playing, nothing queued) -- comparing the intentionally-delayed render pose against the
  newest snapshot used to false-trigger on moving trains (esp. the 5Hz MID band) and re-snap the
  model every 2s; (b) passengers no longer poll the SPACE air brake into the local re-sim -- their
  prediction mirrors the server's controls, so holding Space can't drift a passenger into rollbacks.
  re-applies the per-frame interpolated/predicted pose to the LOCAL animal (applyPoseLocal -- a local-only
  render write; the engine's coarse animal sync no longer shows a segment-teleporting body) and pins its
  OWN rider (Ride.pinRider, camera rides the train); the co-op host skips both (isServerProcess -- its
  server half already writes the live pose/pin in-process). Control sends are deduped to state-changes
  only (old ~20Hz heartbeat + key-edge sends tripped the server's rate limit). Local animal writes are
  setX/Y/Z + setTargetAndCurrentDirection (v1.0.2: the AnimationPlayer yaw only rotates via
  setTargetAndCurrentDirection; setForwardDirection/setDir left the model stuck). v1.0.2 wall fix:
  ejectLocalPlayer pushes the OWNER out of any hull they are not seated on every render frame (the
  server's eject does not mirror back to the local player's own screen); anti-twitch: while inside the
  hull the client freezes walk input (setBlockMovement) + pushes out, held while movement keys stay
  down (0.8 s cap) -- no per-frame teleport oscillation, and the server-side player teleport was
  removed so nothing writes the owner to a second edge point. v1.0.2: driven loco render reverted to the
  local sim (the server-truth buffer render made driving visibly stuttery; on a local host RTT~0 so no
  alignment gain). Driven loco keeps
  its own lever (snapshots never overwrite throttle/reverser, server truth stashed for rejection rollback)
  so the HUD notch can't flash back; control commands carry seq; observer audio/lights are distance-gated
  (SOUND_RANGE=200 = 鸣笛上限, LIGHT_RANGE=70); render LOD: beyond RENDER_RANGE (70 格 = 远距离/off-screen)
  the pose pass is skipped but the record/buffer stay warm. NO client-side collider in MP
  (RR_Collider.ejectIntruders would teleport zombies/players locally -- the server is the wall);
  receives the server's "horn" edge event and plays it on the specific loco with 200 格 falloff
  (driver client skips replay); RR_Sound.mixer applies per-class distance attenuation
  (ambient 50 / brake 100 / horn 200 tiles, shared RR_SoundConfig.distanceGain); mirrors HUD/lights,
  brake and sound.
- RR_Ride.lua: cab interaction/input; seat world math delegated to shared RR.Body.seatWorld (identical to
  the server's pin); in MP the rider is positioned by the server.
- RR_TrainEntity.lua: local authority simulation; disabled while RR_MPClient mirrors server snapshots; avoids unavailable animal turn states.
- RR_SwitchAction.lua: sends completed MP switch throws to server authority.
- RR_MP.lua: disables legacy client simulation in MP.
- RR_DriveHud.lua / RR_HudModel.lua: control-stand HUD; v1.0.3 added a durability
  readout (engine.condition 0..1 -> 0-100) under the rightmost dial, coloured with
  the same safe/caution/danger band as the COND lamp (server-authoritative in MP).
- RR_MPClient.applyPoseLocal / RR_Body.smoothFacing: v1.0.3e ultra-low-speed turning
  stutter fix -- the visible yaw (AnimationPlayer angle) is now exponential-smoothed
  (tau 0.04s) with a ~0.17deg deadband before setTargetAndCurrentDirection, so a crawl
  through a corner no longer re-snaps/re-triggers the clip-less cow anim state machine
  every frame; physics keeps the raw spline heading (lastPose/renderPose unchanged).
- RR_MPClient (v1.0.3f): periodic authoritative render reconcile -- every 2s each in-range
  loco is checked against its NEWEST server snapshot; on position (>1.5 tiles) or orientation
  (>~20deg) drift the rendered model is re-based on authority (remote: reset buffer + apply
  pos+dir; driven: sim snap + rollback bridge), healing server-normal/client-broken edge cases
  without nudging correct play. Headlight end: remote locos mirror the server's fs; the driven
  loco uses the same deadbanded local rule (Lights.faceSign, neutral keeps last) -- no RTT
  flicker. RR_LightsRender.leadSign now reads rec.faceSign instead of the raw reverser, so the
  beam stays on the last direction in neutral (old code killed the beam) and first spawn faces
  forward. RR_Lights beams are brighter and longer (BRIGHT to 32 tiles).
- RR_Collider.lua (v1.0.5): ejectIntruders inflates ONLY the ZOMBIE keep-out box by
  RR.Body.REPEL_EXTRA (0.5 tiles, push to inflated edge + EJECT_MARGIN) so a trackside
  lunge cannot reach a seated player; the local-player wall stays hull-exact.
- TimedActions/RR_ServiceActions.lua (v1.0.5): new RR_RepairAction -- 5 in-game-minute
  wrench-repair progress bar (maxTime 300 = vanilla ISRepairEngine's one-repair time,
  VehicleWorkOnMid anim, wrench in hand); perform() sends the "fuel"/repair command to
  the server (SP + MP, same round-trip as the old instant repair).
- RR_DieselFluidBridge.lua (v1.0.5): the repair context option queues RR_RepairAction
  instead of sending the instant repair command.
- RR_MPClient.lua (v1.0.5, derail = dead engine): apply() forces engine.running=false
  / phase="off" on any snapshot marked derailed -- the server stops the engine on
  derail, and this belt-and-braces keeps a stale/buffered pre-derail snapshot from
  resurrecting the engine hum on the wreck.
- RR_MPClient.lua (v1.0.5, MP test pass): (a) render lag -- bufferPose now bounds
  the remote playout delay to LAG_CAP (0.12s): on a normal sparse-band segment it
  jumps into the segment so the render sits ~LAG_CAP behind the newest snapshot
  instead of a full packet interval (NEAR 20Hz untouched); RENDER_RANGE 70->100
  (matches the server's FAR band, which was previously received but never posed);
  (b) start -- the start/stop latch is held until the server's engineOn confirms
  (~1.5s cap) with forced re-sends, so a swallowed W retries instead of silently
  doing nothing; (c) sound stacking -- stale remote records (no snapshot for ~8s)
  are pruned with full teardown (Sound/LightsRender/Collider/CabClimate), fixing
  doubled emitters when a loco is removed/re-spawned and phantom engine loops.
- RR_RerailMenu.lua (v1.0.8, NEW): "Put it back on the rails" -- ADMIN-gated
  (isAdmin(), NO -debug, fail closed), MP-only: right-click a derailed wreck ->
  sendClientCommand "rerail" (RR_MPClient.requestRerail); world path
  (Body.hullDistance + CLICK_PAD 6) + animal path (RR_AnimalMenuFilter hook,
  ANIMAL_RADIUS 30), de-duped, RR.RerailMenu.report().
- RR_AnimalMenuFilter.lua (v1.0.8): doMenu suppression now also calls
  RR.RerailMenu.addForAnimal (SP v1.0.2 hook) -- the livestock menu stays off, the
  admin rerail entry is the only addition on a derailed loco.
- RR_MPClient.lua (v1.0.8): ejectLocalPlayer -- EJECT_PAD 0.30 pads BOTH the
  containment test and the clamp target (player centre lands against the plating,
  not half inside; margin 0 = no dead band = no walk-in/fling-out sawtooth) +
  setLastX/Y on eject; impact "crush" handler throttles the thud
  (CRUSH_MIN_INTERVAL) and plays Sound.squelch when `downed`; "rerailed" server
  ack -> green halo; Client.requestRerail.
- RR_Sound.lua (v1.0.8): Sound.squelch(e) -- BloodSplatter one-shot at the loco
  for DOWNED crush kills (dedicated servers have no audio; the event flag drives
  this on every client), pcall-wrapped.
- RR_DriveHud.lua (v1.0.8): TONE gains terminal (defensive -- band() never emits it
  today, but a missing key falls back to amber); the banded-lamp ring is drawn only
  in colourblind mode (SP v1.0.2) -- colour is primary now the danger tone renders.
- RR_Sleep.lua (v1.0.9, MP sleep sync): begin() sends the vanilla
  "player"/"onVehicleSleep" {id, isAsleep=true} command so the server's character
  enters the asleep state too -- client-only setAsleep left the server copy awake;
  with the server Shelter bed (RR_ServerTrain.pinSeats) the asleep branch of
  BodyDamage.UpdateWetness now protects the sleeper on a dedicated server.
- RR_Sound.lua (v1.0.10, MP sound fix): playOnce/playLooped go through
  playSoundImpl/playSoundLoopedImpl -- B42 auto-relays playSound/playSoundLooped
  (PlaySoundPacket / PlayWorldSoundPacket) to every other client, so "each client
  plays it" stacked N copies per listener (the overlap / drowned-out bug).
  engineRunning fails closed; snd.lastRunning gates the shutdown spin-down;
  onRemove's engineStop is local-only + gated (was unconditional + relayed);
  prime/crank loops gated on `not running`.
- RR_MPClient.lua (v1.0.10): apply() fires engineCatch/engineStop on the
  server-authoritative running<->off edge (local-only, every client, once per
  transition; first engine field per record never fires) -- MP stalls /
  immobilize / derail now sound the stop; stale enginePhase self-heals (server
  now sends ep change-only in deltas).
- RR_Ride.lua (v1.0.11, seat race): dismount(skipRelease) -- the quiet unmount
  from apply() skips the redundant "release" command (was rejected NotAboard);
  clears _starting/_stopping/_startTries/_stopTries on step-off (a stale auto-
  remount can no longer re-send held W/S and flip the server engine, re-firing
  the catch/stop one-shots); stamps e._dismountAt; mountNearest marks
  e._boardPending for explicit re-boards.
- RR_MPClient.lua (v1.0.11): apply() seat block -- 2s dismount grace suppresses
  the stale pre-release re-seat ("reload: re-seated driver" 0.5s after every
  "stepped off", which made E toggle dismount instead of boarding) unless the
  player just pressed E (_boardPending); seat -> nil while locally mounted now
  drops the phantom mount quietly (dismount(true)). sendControl: stop wins over
  start when both latches are held.
- RR_Sound.lua (v1.0.11): onRemove is silent -- no engine-stop one-shot on
  record teardown (the real spin-down plays once on the running->off edge; the
  teardown play rang on every approach/leave cycle of an idling loco).
- RR_Ride.lua (v1.0.12, board lock): E is swallowed for BOARD_LOCK_MS (1 s)
  after an MP board request (Ride._boardAt). MP boarding confirms on the server
  round-trip (~100 ms) with no instant feedback, so the player's second tap
  used to board then instantly alight ("re-seated" -> "stepped off" 0.1-1 s
  apart in the field log). Deliberate get-off still works after the lock.
- RR_MPClient.lua (v1.0.12): the seat->nil quiet-dismount is gated on a valid
  onlineId (nil onlineId = "seat not computable", not "seat gone").
- RR_Ride.lua (v1.0.14): E on a derailed loco prints the refusal reason
  (admin rerail / server-console debugRerail hint) instead of silently failing.
- RR_MPClient.lua (v1.0.14): logs the first derailed state packet per record
  (wreck pos + dir) for diagnosis.
