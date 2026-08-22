# Railroader server
- RR_ServerTrain.lua: authority; fixed-step 60Hz sim (STEP_SEC accumulator on getTimestampMs, variable-step
  game-time fallback), per-step physics/pose/collision/seat-pin/alpha-gate; delta-encoded per-player
  distance-band broadcast (<=30 格 20Hz / 30-70 格 5Hz / 70-100 格 1Hz / >100 格不发;
  int16mm distance delta vs the player's own baseline + controls byte + changed-only engine/lights; first
  sight or >FULL_GAP re-entry = full+resync); state carries simTime/serverWallMs/gameAgeH/lastCmdSeq/resync;
  v1.0.7: one-loco-per-save across new AND old saves (worldSpawned() = rrTrainSpawned OR the SP
  rrLocoSpawned; add()/adopt() write BOTH via markSpawned() -- old SP saves converted to MP no longer
  race a depot duplicate against the saved loco's unstreamed chunk). Depot spawn stays on the ready
  handshake (client re-sends every ~300 ticks): once a player walks near the shed and the chunk loads,
  the next ready (~5s) materialises the loco -- same worldSpawned gate, once per save.
  v1.0.4: full "state" snapshot now carries the authoritative switch states (switchesState --
  { [baseId] = { [switchId] = "normal"|"reverse" } }) so late joiners never predict the default branch;
  v1.0.4 audit fixes: (a) offline PASSENGERS are pruned from e.passengers in the same per-tick online
  check that releases the driver -- disconnected riders no longer leak their seat (and pin alpha)
  until a restart; (b) save() persists rrV and adopt() restores it -- a restart mid-motion resumes
  with the no-driver emergency brake instead of the loco appearing parked; (c) reacquire() prefers an
  already-adopted animal when sweeping legacy duplicates and refuses to remove anything in byId, so a
  duplicate sweep can never kill the live locomotive.
  v1.0.5 (chunk unload / mass-disconnect edge): reacquire() detects when a record's animal left the
  loaded cell and PARKS it in memory (zero velocity, physics/broadcast/history skipped) so a
  disconnected train can never keep a phantom speed that resumes rolling into unloaded chunks;
  adopt() now RE-BINDS an existing record to a same-id animal that streams back after a chunk reload
  (rebind(): world-truth re-anchor + v=0 + collider wall chain rebuilt); stepOnce stashes released
  seats in e._lastSeats and restores them when the rider reconnects within FAR_RANGE while the train
  is stopped and its chunk is loaded (explicit board/release cancels the claim) -- players no longer
  respawn outside a train that glided away during their absence.
  control commands carry client seq (stale ignored) with per-player rate limit (40/s; client dedupes
  repeated control state); server pins game
  speed to 1 while a train is worked/rolling; authoritative seat pin (RR.Body.seatWorld) every sim tick;
  horn held-state tracked from control commands, EDGE broadcast as a "horn" event (driver loss / release
  force horn off + event);
  persistence save every 30 ticks; snapshot history ring (HISTORY_MAX) served on client "resync" requests;
  rejections carry the loco id so the client can roll its lever back.
- RR_ServerCollision.lua: authoritative collision; tagged `rrFuelStand` objects are hard obstacles, vehicle contact uses nose/body probes, and players are ejected from the body.
- RR_ServerCollision.lua (v1.0.2): every engine call wrapped individually (SP-style) + first-error log per
  loco -- one failing API no longer kills the whole sweep silently; zombies below CRUSH.V_MIN are ejected
  from the hull (stationary loco is a wall; the server never spawns rr_collider push segments); zombie kill
  = knockDown + dieNetwork(killer,nil,bGory,nil) with setHealth(0)+dieNetwork fallback (Kill() does not
  sync the death to clients on a dedicated server); the four subsystems (crush/ejectPlayers/ejectZombies/
  obstacle) are isolated so one failure cannot skip the others. v1.0.2: crush/ejectZombies are TWO-PHASE
  (collect inside bodies first, then kill/eject -- dieNetwork removes zombies from the cell list
  immediately, which threw IndexOutOfBounds mid-iteration and aborted crush every tick); the wall is the
  SP nearest-hull-edge eject (ejectTarget, z-floor gated) at ANY speed for zombies and players PLUS an
  engine-phase invisible rr_collider segment chain (Collision.onSpawn/pinWall -- separate() runs inside
  character movement resolution, same phase as vehicle collision, so a zombie AI cannot overwrite the
  push; orphan segments swept on start + every 60 ticks). v1.0.2: server-side PLAYER eject removed --
  it teleported the owner's own body to a second edge point (offset by one RTT) and fought the client's
  own eject, causing the convulsion; each client keeps its own player out (RR_MPClient.ejectLocalPlayer
  + block), the server wall handles zombies/remote bodies. Persistence: RR_World.rrTrainSpawned flag --
  ready() no longer spawns a depot duplicate when a saved locomotive exists but its chunk is not yet
  streamed (that race spawned a second loco and the duplicate sweep then deleted the parked original).
  RR_ServerTrain.applyPose facing =
  setTargetAndCurrentDirection (the only call that rotates the AnimationPlayer yaw; setForwardDirection
  just sets a vector that is gated for AI-suppressed animals).
- RR_ServerCollision.lua (v1.0.3c FINAL): car pass-through fix -- old code smashed a struck car but
  never moved it, and the per-tick 0.8 bleed lost to a held high throttle (~0.18 m/s equilibrium), so
  the loco crept THROUGH the car. Moving the car server-side was PROVEN impossible (spike
  RR_SpikeVehicleMove: applyImpulseGeneric is dropped on the sleeping Bullet body "isActive: false";
  setX/setY succeed but the server's vehicle update reverts the write within a tick). Final fallback:
  wreck the car ONCE (setSmashed + parts-kill + speed-ramped condition damage, per-object latch) and
  HARD-STOP the loco at it -- car probe runs at ANY speed so the stopped loco cannot lurch through on
  the next throttle tick; the hold releases when the car leaves the probe (towed/removed by players).
  v1.0.3d: condition damage is now RELATIVE-speed based (loco speed minus the car's speed along the
  rails, |loco|+|car| fallback) for BOTH sides -- the loco keeps the 1-3% VEHICLE curve, the car loses
  carImpactFrac (0 at 5 km/h crawl -> full wreck at 60 km/h closing, parts scaled proportionally).
  New carBodyHit sweep: a car DRIVING INTO the loco body (side/rear overlap) is damaged once and
  STOPPED every tick by an outward impulse (a moving car's Bullet body is active, so it lands); the
  nose probe stops a car driving into the loco front the same way.
  v1.0.3e: wall/building collision fixed -- old string read props:has("solid") fails in this B42 build
  (loco phased through every wall). Now per-object IsoFlagType.solid/solidtrans/collideN/collideW
  (proven server-side official pattern) + railcarStandIn (industry_railroad_* body, or carpentry_01_16
  on a rail square = the dev's parked-freight-car walls) -> HARD stop; every other blocker is
  flattened (SP policy "loco flattens everything except rolling stock") + RecalcAllWithNeighbours.
- RR_ServerTrain.lua (v1.0.3f): headlight direction (faceSign, +1 forward / -1 backward) is now
  server-authoritative: deadbanded motion rule (RR.Lights.faceSign: |v|>0.3 m/s decides, else the
  reverser, neutral keeps the last; first spawn = forward), persisted as rrFaceSign (save/adopt),
  broadcast as wire `fs` (full + changed-only), carried in the history snapshot (faceSign).
- RR_SpikeVehicleMove.lua (SPIKE, concluded, removable): setX/setY do NOT persist (server vehicle
  update reverts the write within a tick) -- kept only for manual retests via
  sendClientCommand("RailroaderMP","spikeVehicle",{d=5}); logs BEFORE/AFTER + 60-tick RECHECK.
- RR_ServerTrain.lua (v1.0.5): wrench repair now adds +5 durability points per repair
  (0.05 on condition; the "+25%" instant repair is gone) -- the client fronts it with a
  5 in-game-minute timed action (RR_RepairAction) and the server still owns wrench wear /
  the already-serviced reject / the actual +5.
- RR_ServerTrain.lua (v1.0.6, long-running-server log hygiene): per-action "control
  accepted" print removed (every lever move used to write a line); "control rejected"
  and "switch accepted" prints now throttled per player+reason / per switch
  (LOG_THROTTLE_TICKS=600, ~10s) -- the first occurrence still logs the greppable key,
  but a scripted client or a lever spammer can no longer grow the server log unboundedly.
  The ready-handler "saved locomotive exists but its chunk is not loaded yet" line is
  now logged ONCE PER BOOT (readyNoChunkLogged) -- a client re-sends "ready" every
  ~300 ticks to catch late chunk streams, and while a saved loco's chunk never
  streams the old unconditional print grew the log every few seconds for as long as
  anyone was online.
- RR_ServerCollision.lua (v1.0.5): ejectTarget keep-out inflated by RR.Body.REPEL_EXTRA
  (0.5 tiles) so zombie centres can't get into a seated player's lunge range; players
  and boarding/fuelling standoffs unchanged.
- RR_ServerCollision.lua (v1.0.5, derail = dead engine): stopHard() stops the prime
  mover the tick a HARD impact derails the loco (RR.Engine.stop) so the state stream
  carries engineOn=false and clients cut the engine hum on the wreck.
- RR_ServerCollision.lua (v1.0.5, B42.17 vehicles): carBodyHit iterates vehicles via
  new eachVehicle() -- getVehicles() returns a Set since 42.17 (no get(i)); the old
  indexed loop crashed with "Object tried to call nil". RR_SpikeVehicleMove
  nearVehicles got the same three-shape iteration.
- RR_ServerTrain.lua (v1.0.5, MP render lag): MID_EVERY 12->6 (10Hz) and FAR_EVERY
  60->15 (4Hz) -- the per-player relevance bands were so sparse that the client's
  one-segment-behind interpolation rendered up to 1s behind the train.
- RR_ServerTrain.lua / RR_ServerCollision.lua (v1.0.5, restart leftovers):
  adopt() drops persisted rr_collider walls (Collision.dropWalls) before spawning
  the fresh chain -- before, old-session walls were kept by the owner-only sweep
  and lingered as invisible blockers after a restart; sweepOrphanWalls now checks
  membership of the LIVE chains. Parked (chunk-unloaded) records removeWall() and
  re-onSpawn() on un-park -- no stale wall chain at an empty spot.
- RR_ServerCollision.lua (v1.0.8, SP v1.0.2 crush port): crush gate is now
  V_ROLL=0.2 + ROLL_GRACE=1.0s, not V_MIN -- a DOWNED zombie (isDown:
  isOnFloor/isCrawling/isGettingUp) is killed gory at ANY rolling speed (incl.
  braking to a stop ON it); standing bodies keep the old tiers; wildlife stays
  V_MIN; zombie blood via addBloodFromVehicleImpact (downed booked at V_GORE),
  knockdown dedup (struck/seen), no re-knock of downed bodies, impact events
  carry `downed` for the client squelch. ejectTarget: target == test boundary
  (EJECT_MARGIN overshoot removed -- old 0.15 dead band = SP jitter); ejectZombies
  re-stamps setLastX/Y.
- RR_ServerTrain.lua (v1.0.8, admin rerail): new "rerail" client command -- gated
  on isAdminPlayer (player:getAccessLevel()=="admin", NO -debug; forged commands
  rejected IGUI_RR_Reject_NotAdmin), validates derailed + CONTROL_RANGE; rerail()
  clears the wreck (derailed=false, throttle/brake/v=0, engine stays OFF,
  condition untouched), applyPose at e.distance, rebuilds the wall chain
  (removeWall/dropWalls/onSpawn), clears rrDerail* modData, save(), immediate
  full+resync sendState(nil) + "rerailed" ack. Collision.update now gets sim dt
  (crush grace timer).
- RR_ServerTrain.lua (v1.0.9, MP rain shelter): pinSeats arms the
  server-authoritative character's cab roof -- cached world-less IsoObject named
  "Shelter" (same trick as client RR_CabClimate) + setIsResting(true) every tick,
  so the server-side BodyDamage.UpdateWetness stops raining on seated
  driver/passengers; "release" clears both (unshelter). Marker build is fail-open
  with one log line.
