--***********************************************************************
-- Railroader / RR_ObstacleSweep  -- obstacles on the rails: engine sweep (Task 1.N)
--
-- Sibling of RR_Collider / RR_Crush. Where crush kills CHARACTERS the moving loco
-- drives into, this reacts to STATIC WORLD obstacles, sampled DENSELY across the full
-- body width (габарит) at two probe reaches under the LEADING edge:
--   NEAR (half + NEAR_MARGIN): every ON-TILE obstacle. SMASHABLE (IsoThumpable fence/
--     gate/wall, IsoWindow, IsoDoor, plain HitByCar prop) -> DESTROYED by the engine-
--     native call for its type, loco keeps rolling with a small speed bleed (dvFrac);
--     at creep it stalls instead (a fence stops a crawl). HARD on its own tile
--     (ROLLING STOCK -- see below) -> HARD-STOP at contact.
--
-- THE LOCO FLATTENS EVERYTHING EXCEPT ROLLING STOCK (owner 2026-07-29). The old default was
-- "a solid tile we don't recognise stops us", which put every un-enumerated prop on the map
-- in the way of 112 tonnes -- the loco ended up parked against a BARREL. Enumerating props is
-- not a finite job, so the rule is inverted: HARD comes ONLY from railcarOn() (a named sprite
-- test for a vanilla railcar / another loco) and every other blocker is removed by the
-- flattenOn() catch-all. See RR.Obstacle.SOLID_IS_HARD + Sweep.SMASH_UNKNOWN.
--   FAR  (half + STOP_MARGIN, `solid` only): a big overhanging BODY (vanilla railcar/
--     wall) whose solid tile sits behind a sprite reaching toward the loco -> stop with
--     the standoff so the loco does not bury into the sprite.
-- See the CALIBRATION block for the one-knob-per-concern rationale (NEAR_MARGIN /
-- STOP_MARGIN / LAT_STEP). Shove/wreck (cars) and condition-damage/derail land later.
--
-- Pure POLICY lives in shared/RR_Obstacle (classify/effect, unit-tested). This file is
-- the engine glue: read the real IsoGridSquare + its objects, build the plain-data
-- descriptor, ask the policy, apply the outcome (stop / smash). No new unit tests
-- (engine-bound, like Collider/Crush).
--
-- ANTI-TUNNELING: a fast loco advances up to ~1.5 tiles per capped tick (DT_MAX). We
-- sub-sample the LEADING edge along the whole chord swept this tick (<= SAMPLE_STEP
-- apart) so a one-tile-wide obstacle between ticks is never skipped. The leading edge
-- is the body end in the direction of travel (nose when going forward, tail when
-- backing) -- picked from the sign of (motion . facing), so it is reverse-safe.
--
-- Driven from RR_TrainEntity.onTick right AFTER Drive.step advances e.distance: the
-- sweep returns a clamped distance + stopped flag; the caller rolls e.distance back to
-- the contact point and zeroes e.drive.v. Own rr_loco/rr_collider are IsoAnimals, not
-- tile objects, so getGridSquare never sees them -- no self-collision.
--***********************************************************************

print("[Railroader] RR_ObstacleSweep.lua: loading...")
require("Railroader/RR_Body")
require("Railroader/RR_Obstacle")

local Sweep = {}
Sweep.enabled = true
Sweep.debug   = false           -- diagnosis done; flip to true for probe/stop console logs
-- CALIBRATION mode (hands-off, no console): while true the loco NEVER auto-stops, so
-- you can drive it right up to an obstacle and brake where it SHOULD stop. The moment
-- it comes to rest with a solid tile close ahead, it prints the ideal STOP_MARGIN once.
-- Read it from the log, bake it into STOP_MARGIN, then set this false.
Sweep.calibrate = false
-- ============================ CALIBRATION (all object types) ============================
-- The leading edge is at centre + half along travel. Two probe reaches decide where the
-- loco reacts, and one lateral step decides how densely the body WIDTH is covered:
--
--   NEAR_MARGIN (small) -- the gap the nose keeps from any ON-TILE obstacle. Nearly every
--     obstacle is on-tile: a cone/sign/fence (its object sits on its own tile) and a small
--     solid barrier (concrete "Block" via `solidtrans`, a buffer stop, a brick wall via
--     `solid`). The near scan SMASHES smashables and STOPS at hard ones, both ~NEAR_MARGIN
--     from the nose. One reach, one calibration, all on-tile types.
--
--   STOP_MARGIN (big) -- the EXTRA standoff only a large overhanging BODY needs: a vanilla
--     railcar / wall sets its `solid` flag on a FAR tile while its isometric sprite reaches
--     toward the loco, so the loco must halt STOP_MARGIN before that solid tile or it buries
--     into the sprite. The far scan fires only on the strong `solid` flag (HARD_FAR_SOLID_ONLY)
--     -- a small `solidtrans` prop is left to the near scan so it is NOT stopped a standoff
--     early. A railcar's near tiles are non-solid, so the near scan never trips on it.
--     (Railroad floor tiles are `solidfloor`, which neither isSolid nor isSolidTrans reads,
--     so a railcar's HARD comes from its body sprites; those are normally `solid`. If one is
--     `solidtrans`-only, flip HARD_FAR_SOLID_ONLY=false to make the far scan catch it.)
--
--   LAT_STEP -- lateral sampling resolution across the FULL body width (габарит). The old
--     3-point flanks (0, +/-quarter-width) skipped obstacles between the probe lines, so
--     cones on the rails survived (owner feedback 2026-07). We now sample every LAT_STEP
--     tile from -halfWidth..+halfWidth, so nothing inside the loading gauge is missed;
--     obstacles OUTSIDE the width (trackside fences) are still never touched.
--
--   NOSE_TRIM -- the collision footprint (RR_Body.extents, ~15.5 tiles long) is LONGER than
--     the DRAWN model: the U (RR_BodyDebug) overlay showed the green footprint sticking out
--     ~1.5 tiles PAST the visible body at each end (owner-confirmed in-game 2026-07-23). The
--     footprint's mesh constant (Body.MESH.long = 17.10) was itself set from an inflated
--     J-capture, so it over-covers the model. Keying the near stop to the raw footprint nose
--     therefore parks the loco ~1.5 tiles short of an obstacle. NOSE_TRIM shortens the NEAR
--     nose by exactly that overhang so the stop keys to the DRAWN nose -- which lands the
--     visible nose right at the obstacle for EVERY type (no per-obstacle guessing). The FAR
--     (railcar) standoff keeps the full footprint, since STOP_MARGIN was calibrated on it.
--     Lower if the loco clips into obstacles; raise if it stops short.
--
--   WIDTH_TRIM -- the LATERAL twin of NOSE_TRIM. The footprint WIDTH is Body.MESH.wide (3.56) *
--     1.5 * getAnimalSize(); at the LIVE size 0.7 (loco.minSize=maxSize=0.7 -> getAnimalSize
--     clamps to 0.7; the old docs' 0.604 is STALE) that is 3.74 wide -> raw half-width ~1.87.
--     That bbox includes the GRAB IRONS / STEPS / WALKWAYS poking past the visible hull, so the
--     raw half-width over-covers the drawn body sideways exactly as the raw nose over-covered it
--     lengthwise. It made the sweep smash trackside FENCES and DERAIL on roadside BOULDERS a tile
--     or so off the rails (owner in-game 2026-07-25: "ломает секции заборов в стороне; сошёл на
--     boulders_35"). WIDTH_TRIM shaves this off EACH side so the lateral span keys to the drawn
--     HULL, not the mesh bbox. Calibrate: drive PAST a fence/boulder that should NOT be touched;
--     the HARD-trigger log prints `lat=<offset>/halfW=<span>` -- raise WIDTH_TRIM until halfW <
--     that lat. Lower it if the loco starts phasing through things genuinely fouling the rails.
--     (The U overlay / RR_BodyDebug draws the RAW footprint, so the sideways overhang it shows
--     past the drawn hull IS the WIDTH_TRIM to dial in -- same method that set NOSE_TRIM.)
--
--   (Width note) The J-capture width (4.06) was inflated the same way; the sweep starts from the
--     footprint half-width (RR_Body.extents, ~1.87 at size 0.7) and subtracts WIDTH_TRIM to reach
--     the drawn hull -- LOCO_HALFW still hard-overrides the whole computation (left nil).
--
-- Tune live: RR.ObstacleSweep.STOP_MARGIN / .NEAR_MARGIN / .LAT_STEP / .NOSE_TRIM / .WIDTH_TRIM / .LOCO_HALFW.
Sweep.LOCO_HALFW  = nil     -- optional drawn half-WIDTH override; nil => footprint half-width - WIDTH_TRIM
Sweep.STOP_MARGIN = 6.8     -- far standoff for a big overhanging body (railcar), `solid` only
Sweep.NEAR_MARGIN = 0.75    -- nose gap to on-tile obstacles; 0.75 splits the plate (wants 0.5)
                            -- vs a solidtrans railcar whose sprite overhangs more (wants ~1.0)
-- The two trims are the SAME "bbox air" numbers as RR_Body.END_TRIM / .SIDE_TRIM (which
-- RR_Body.hullExtents/hullDistance use for the E-key boarding reach), so they are sourced
-- from there -- one place to re-measure if the mesh changes. The literals are the fallback
-- for a load order that hasn't reached RR_Body yet; tuning either field live still works,
-- since every use site reads Sweep.NOSE_TRIM / .WIDTH_TRIM at call time.
Sweep.NOSE_TRIM   = (RR.Body and RR.Body.END_TRIM)  or 1.5
                            -- trim the oversized footprint to the DRAWN nose (U-confirmed ~1.5)
Sweep.WIDTH_TRIM  = (RR.Body and RR.Body.SIDE_TRIM) or 0.3
                            -- trim the mesh-bbox overhang (grab-irons/steps) to the DRAWN hull SIDES
                            -- (per side); raw half-width ~1.87 (size 0.7) -> ~1.57 (~full body width).
                            -- HISTORY: briefly pulled to 0.9 to stop a shed-doorway corner-catch on a
                            -- curve, but that was really the STRAIGHT-probe OVERSHOOT (now fixed by the
                            -- spline-following leadAt()); the narrow width then left an on-track CONCRETE
                            -- barrier only PARTLY smashed, one side surviving (owner in-game 2026-07-27).
                            -- So width is back to ~full габарit -- the sweep must cover the whole body it
                            -- physically sweeps. Calibrate via lat=/halfW=.
Sweep.LAT_STEP    = 0.5     -- lateral probe spacing across the body width (<1 => no gaps)
-- Build the probe frame on the CALIBRATED pose (the one the model, the collider keep-out
-- box and the crush sweep all use) instead of the raw spline point -- see poseAt. The two
-- differ by up to ~0.57 tile ACROSS the rails, which is what made the gauge reach further
-- on one flank than the other. false = pre-2026-07-27 behaviour (raw spline frame).
Sweep.USE_CALIB   = true
-- Residual lateral re-centring lives in ONE shared place, RR_Body.LAT_BIAS (tiles,
-- + = right of travel) -- the collider/crush/overlay read the same knob, so the габарит
-- can never drift apart between them again. Calibrate it with U (see RR_Body).
-- IGNORE stone boulders entirely. Natural `boulders_*` rocks are forest scenery that NEVER sit on
-- the rails, but the loco габарit can clip one on a curve (owner in-game 2026-07-25: derailed on
-- `boulders_35`). They carry `solidtrans`, so without this they classify HARD. When ON, a square
-- whose ONLY solidity is a boulder (no strong wall, nothing smashable) is dropped to NEGLIGIBLE --
-- the loco phases through roadside rocks. A real wall (`solid`) on the same tile is unaffected.
Sweep.IGNORE_BOULDERS = true
Sweep.IGNORE_PREFIXES = { "boulders_" }   -- sprite-name prefixes never treated as an obstacle
-- ============ THE LOCO FLATTENS EVERYTHING EXCEPT ROLLING STOCK (owner 2026-07-29) ============
-- The old rule was "a solid tile we don't recognise STOPS the loco". Backwards: the map is full
-- of un-enumerable one-off props, and each one that carries a solidity flag and nothing else
-- brought 112 tonnes to a stand -- owner in-game, the loco parked against an ordinary BARREL.
-- Enumerating every prop type is not a finite job, so the policy is inverted: HARD is now an
-- EXPLICIT list of ONE thing (rolling stock), and everything else that fouls the gauge is
-- flattened. RR.Obstacle.classify does the deciding (SOLID_IS_HARD=false); this file supplies
-- the two halves it needs -- the `railcar` hint, and a destroy target for a prop with no
-- vanilla break path.
--   SMASH_UNKNOWN : off => an unrecognised solid has no destroy target, so the loco phases
--                   through it (the class is SMASHABLE but nothing is destroyed). On (default)
--                   => flattenOn() picks the blocking object and applySmash removes it.
--   RAILCAR_PREFIXES : a solid object whose OWN sprite starts with one of these is rolling
--                   stock. `industry_railroad` covers vanilla's metal railcars (…_05_8/25 =
--                   WallW/WallN, …_05_45). The running rails/switches of the same tileset are
--                   FLOOR sprites (solidfloor only), so they never carry a solidity flag and
--                   never match -- the loco is not stopped by the track it rides on.
--   RAILCAR_SPRITES : exact sprite names that are railcar BODIES from a non-railroad tileset --
--                   a wooden boxcar's walls are `carpentry_01_16` (solidtrans), which is a
--                   generic carpentry wall elsewhere on the map. Only honoured on a square that
--                   ALSO carries a rail sprite, so an ordinary wooden building is still flattened.
Sweep.SMASH_UNKNOWN    = true
Sweep.RAILCAR_PREFIXES = { "industry_railroad" }
Sweep.RAILCAR_SPRITES  = { ["carpentry_01_16"] = true }
Sweep.HARD_FAR_SOLID_ONLY = true   -- far scan ignores solidtrans-only (leave to the near scan)
-- Treat movement-COLLIDE tiles (collideN/collideW) as HARD -- the ONLY signal a vanilla METAL
-- railcar wall (industry_railroad_05_8/25 = WallW/WallN) sets: it carries `collide*` but NOT
-- `solid`/`solidtrans`, so the loco phased straight through metal railcars while wooden boxcars
-- (carpentry_01_16 = solidtrans) stopped it. ON, but RESTRICTED to RAILCAR wall sprites
-- (industry_railroad_*): a bare collide read also stopped the loco DEAD at the depot shed doorway
-- (building/shed walls carry collide too -- owner in-game: "can't enter the shed"), so we only
-- honour collide when an industry_railroad sprite sits on the square. Shed walls are carpentry/
-- brick and the running rails/switches are FLOOR (no collide), so neither trips it. (This was left
-- OFF when the sprite restriction landed, un-reverified -- the loco went back to phasing through
-- metal railcars; re-enabled 2026-07-24. VERIFY in-game: metal railcar STOPS + shed still enterable.)
Sweep.HARD_USE_COLLIDE = true
-- ...and the collide flag must belong to the RAILROAD OBJECT itself, not just share a square
-- with one. Rails run INTO the engine shed, so a doorway square carries a railroad floor sprite
-- AND the building's collide -- the square-level test let every shed gate read as a railcar wall
-- and parked the loco in its own doorway. Set false for the legacy square-level behaviour.
Sweep.HARD_COLLIDE_PER_OBJECT = true
-- FAR standoff (STOP_MARGIN, ~6.8 tiles) exists for ONE thing: a big overhanging vanilla
-- RAILCAR sprite whose `solid` flag sits on a far tile. Applied to everything else it stops the
-- loco 6.8 tiles short of any solid wall -- e.g. the jamb beside a shed gate, which reads as
-- "won't go in" long before the nose is anywhere near it. So the far scan only fires on squares
-- that carry an `industry_railroad_*` sprite; every other wall is left to the NEAR scan, which
-- stops at contact. false = old behaviour (far standoff on any solid square).
Sweep.FAR_RAIL_ONLY = true
-- Cap on total speed bled by SMASHABLE strikes in a single tick, so a cluster of fences
-- can never brake the loco to a crawl (each fence is DV.SMASH ~= 0.02; a big loco shrugs
-- them off). HARD is a separate full stop; this only bounds the smash bleed.
Sweep.SMASH_DV_CAP = 0.20
-- VEHICLE (Step 4) impulse tuning. applyImpulseGeneric applies an IMPULSE (kg*m/s) at a point;
-- the car's sideways Delta-v = strength / mass. We set strength = getFudgedMass() * absV * factor,
-- so Delta-v = absV * factor (mass cancels) -- `factor` is "how many times the loco's own speed"
-- the car is flung sideways. Bullet horizontal origin units are ~world TILES (verified in
-- the BaseVehicle spike, RR_VehicleTest, since deleted: origin:add(dx,0,dy) moved the car by
-- world deltas), so Delta-v is ~tiles/sec:
-- to clear a ~3-tile-wide car off the rails before the 15-tile loco body passes over it, we
-- need Delta-v ~15-30. The impulse is applied at the car's CENTRE (pure translation, no spin),
-- so the WHOLE car slides clear -- an edge hit torqued it and left one end on the rails ("part
-- stayed on the rails, loco went through", owner in-game 2026-07). CLEAR_DV_MAX caps the fling
-- so a fast wreck doesn't rocket across the map. All IN-GAME TUNABLES:
--   RR.ObstacleSweep.SHOVE_FACTOR / .WRECK_FACTOR / .CLEAR_DV_MAX.
-- The impulse is consumed by the engine as a Bullet CENTRAL FORCE (applyCentralForceToVehicle,
-- BaseVehicle.java:3765) capped at 1500*fudgedMass. A GROUNDED car resists a sideways force by
-- design (tire lateral grip), so a pure-horizontal push only "scoots" it (owner in-game: the
-- car changed to its smashed model but barely moved). The unlock is to LOFT the car -- add an
-- UPWARD component so the tires leave the ground, then the lateral force actually throws it
-- clear. *_UP is the vertical fraction of the impulse; *_FACTOR/CLEAR_DV_MAX set the magnitude
-- (much higher now -- the old values were far below what a grounded car needs). All live-tunable.
-- A deterministic teleport-slide was tried (move the car relative to the rail axis) but is NOT
-- POSSIBLE from Lua: the `Transform` class is not a Lua global (`Transform.new()` throws
-- "attempted index: new of non-table: null"), BaseVehicle has no Lua-reachable position setter,
-- and vanilla Lua never moves a vehicle. So the impulse is the ONLY lever. The unlock for a
-- GROUNDED car (tire grip fights a pure lateral push -- it only "scoots") is to LOFT it: an
-- UPWARD impulse component lifts the tires off the ground, then the lateral force throws it clear.
-- *_UP is the vertical fraction; *_FACTOR/CLEAR_DV_MAX the magnitude. Delta-v = strength/mass =
-- absV*factor (~tiles/sec); the engine caps the force at 1500*mass. All live-tunable -- raise the
-- factor/loft if a car barely clears, lower if it rockets off.
-- Magnitudes are BIG on purpose: the engine applies the impulse as a one-frame central force
-- that a parked car's mass + grip largely absorb, so "reasonable" values barely rock it. The
-- force is capped at 1500*fudgedMass, and Delta-v = strength/mass = absV*factor, so we push the
-- factor/cap toward that ceiling. Lower them if a car rockets off; raise if it still won't clear.
Sweep.SHOVE_FACTOR = 80.0   -- slow car shoved clear (intact)
Sweep.WRECK_FACTOR = 80.0   -- fast car thrown clear (smashed)
Sweep.CLEAR_DV_MAX = 1200   -- cap the impulse magnitude (Delta-v ~tiles/sec) -- near the engine's 1500
Sweep.CLEAR_DV_MIN = 30     -- FLOOR: min throw so even a creep touch clears the (now-wrecked) car
Sweep.SHOVE_UP     = 0.3    -- loft on a shove so the tires leave the ground and it slides clear
Sweep.WRECK_UP     = 0.4    -- loft on a wreck (the flip below does most of the clearing)
-- FORWARD drag (fraction of the lateral push aimed along the loco's TRAVEL direction), so the car
-- is carried DIAGONALLY -- swept aside AND dragged ahead -- instead of purely sideways. 0 = pure
-- sideways; ~1 = 45 deg forward. Live-tunable.
Sweep.SHOVE_FWD    = 0.5
Sweep.WRECK_FWD    = 0.6
-- FLIP: apply the lateral impulse a point ABOVE the car centre instead of AT it, so it makes a
-- ROLL torque (torque = relPos x impulse, BaseVehicle.java:3757) and the car TUMBLES onto its
-- side in the shove direction -- off the rails. Verified geometry: lateral push (right vector)
-- applied `FLIP_HEIGHT` above centre => torque along the loco TRAVEL axis => a sideways roll.
-- Torque ~ mass*Delta-v*FLIP_HEIGHT, so raise FLIP_HEIGHT for a more violent flip, 0 = no spin
-- (pure slide, impulse at centre). Live-tunable.
Sweep.FLIP         = true
Sweep.FLIP_HEIGHT  = 1.0    -- tiles above the car centre to apply the push (moment arm)
-- A car BELOW this fudged-mass is treated as a LIGHT / WHEELLESS hull (a burnt остов: mass ~500 +
-- crawlThroughWheel = no real wheels). It has no tire grip to beat, so it gets a plain horizontal
-- shove (no loft, no flip) that slides it straight off -- the loft+flip otherwise flings such a
-- hull into a long floaty tumble that never clears the rails. Normal cars are ~800. Live-tunable.
Sweep.LIGHT_MASS   = 650
-- KEEP_SKIN: setSmashed swaps the car to a "…Smashed{Side}" SCRIPT whose skin (paint) index
-- resets (CarNormal's smashed def has no `skin`, so it defaults to 0 -> the car changes colour).
-- With this on we capture the pre-hit skin index and re-apply it to the smashed model, so the
-- BODY crumples but the PAINT stays. (Best-effort: if the smashed variant has a different skin
-- set, the colour may still shift.)
Sweep.KEEP_SKIN    = true
-- Collision SOUNDS -- the vanilla vehicle-crash foley (sounds_vehicle_foley.txt), tiered by
-- impact like BaseVehicle.getCrashSound (BaseVehicle.java:4833): a light bump on a creep touch,
-- a heavier crunch on a shove/wreck. Played off the loco's own emitter (same path as the
-- SMASHABLE "VehicleHitObject" one-shot), once per hit. Set SOUND=false to mute; swap the names
-- for other events. VehicleCrash1 = light, VehicleCrash2 = medium, VehicleCrash = heavy.
Sweep.SOUND        = true
Sweep.SOUND_TOUCH  = "VehicleCrash1"   -- creep touch (minimal speed)
Sweep.SOUND_SHOVE  = "VehicleCrash2"   -- shove (low speed)
Sweep.SOUND_WRECK  = "VehicleCrash"    -- wreck (high speed)
-- ADAPTIVE re-push. Some cars (pre-placed BURNT wrecks with destroyed/flat tires) grip the ground
-- so hard the single lateral impulse is absorbed -- they pop UP (the vertical isn't fought) but
-- don't slide off. So for up to PUSH_TICKS ticks after a hit, if the car has moved LESS than
-- PUSH_MOVE_MIN horizontally (still stuck), shove it laterally AGAIN -- by now the loft has lifted
-- the tires and the push translates it. A car that IS clearing moved past the threshold -> dropped
-- immediately, so the nicely-thrown fresh cars are unaffected. PUSH_TICKS=0 disables it.
Sweep.PUSH_TICKS    = 8
Sweep.PUSH_MOVE_MIN = 0.25   -- tiles/tick; below this horizontal move a car counts as "stuck"
Sweep.pushes = {}            -- in-flight adaptive re-pushes (processed OnTick)
-- Ticks a hit car stays de-duplicated (so it is not re-wrecked while it clears). Keyed by the
-- car OBJECT, not car:getId() (which is -1 until physics init -> non-unique across cars).
Sweep.HIT_TTL       = 40
-- How far AHEAD of the drawn nose to catch a car (tiles). Bigger than NEAR_MARGIN so the car
-- starts clearing a beat BEFORE the nose arrives -- cuts the visible "loco through car" frame.
Sweep.VEH_MARGIN   = 2.5
-- Default script for the debug car spawn (RR.ObstacleSweep.spawnCar); has a smashed variant.
Sweep.CAR_SCRIPT   = "Base.CarNormal"

local SAMPLE_STEP = 0.5         -- tiles between leading-edge samples (< 1 => no 1-tile skip)
local DBG_INTERVAL = 0.5        -- s between debug prints per loco

local function sizeOf(rec)
    local size = 0.7
    if rec.animal then pcall(function() size = rec.animal:getAnimalSize() end) end
    return size
end

--------------------------------------------------------------------------
-- Body pose (world coords) at an arbitrary route distance -- mirrors
-- RR_TrainEntity.poseFor / RR_Collider.bodyFrame (bodyPose + the per-direction
-- RR_Calibrate offset + the record's world offset).
--
-- THE CALIB OFFSET IS PART OF THE FRAME, not a render nicety (it used to be skipped
-- here "because square sampling is tile-resolution"). It is up to ~0.57 tile and it is
-- PERPENDICULAR to the rails on most headings (N -0.45, E -0.45, SE/NW ~0.55), while
-- the sweep's whole lateral span is only ~1.57 per side -- so ignoring it slid the probe
-- band a third of a gauge sideways: the loco reacted to things a tile off the rails on
-- one flank and phased through things fouling the other (owner in-game 2026-07-27:
-- "по правому борту габарит меньше, чем по левому"). The visible loco, the collider
-- keep-out box and the crush sweep are ALL built on the calibrated pose, so this one had
-- to join them. Set USE_CALIB=false to A/B the old behaviour in-game.
--------------------------------------------------------------------------
local function poseAt(rec, d, hw)
    local p = RR.Spline.bodyPose(rec.route, d, hw)
    local cox, coy, coz = 0, 0, 0
    if Sweep.USE_CALIB and RR.Calib and RR.Calib.offsetFor then
        cox, coy, coz = RR.Calib.offsetFor(p.dirX or 0, p.dirY or 0)
    end
    p.x = p.x + cox + (rec.ox or 0)
    p.y = p.y + coy + (rec.oy or 0)
    p.z = p.z + (coz or 0) + (rec.oz or 0)
    return p
end

--------------------------------------------------------------------------
-- Find the first SMASHABLE object on a square and return (obj, kind) where kind is
-- one of "thumpable" / "door" / "window" / "hitByCar" / "fence" / "tree", else nil. STEP 3.
--   IsoThumpable  (player-built fence/gate/wall)  : obj:Damage + animalHit  -> destroy
--   IsoDoor       (has NO Damage(float) in B42)  : obj:destroy()
--   IsoWindow                                    : obj:smashWindow()
--   IsoTree       (map vegetation)               : obj:toppleTree(loco) -- felled, see below
--   plain IsoObject w/ the HitByCar sprite flag  : crush sound + DamagedSprite / remove
--   map FENCE/barrier (sprite `fencing_*`)        : same removal -- see below
-- (The CATCH-ALL "flatten" kind -- a barrel/crate/bin/lamp post/map wall with no break path
--  at all -- is NOT found here: it comes from flattenOn(), called by classAt only when this
--  function found nothing typed. Same removal, different origin.)
-- Detection is by OBJECT TYPE (instanceof) first, so the rails/switches the loco rides on
-- (industry_railroad_*) never read as smashable. `has(String)`/`getName` on a sprite are
-- the vanilla-proven safe reads. Everything is pcall-wrapped: a bad object never throws.
--
-- FENCE case: map fences like the quarantine "Military Barrier" (fencing_01_96) carry only
-- `solidtrans` -- no HitByCar, no DamagedSprite, not IsoThumpable -- so vanilla's car path
-- would NOT break them (a car just stops). But a 112 t loco flattens a chain-link/wire/
-- wood fence, so we treat the whole `fencing_*` tileset as smashable-by-removal. Heavy
-- barriers keep their own sprites (concrete Block = street_decoration_*, railcar =
-- carpentry_/industry_railroad_*), so they stay HARD; only `fencing_*` is flattened.
--
-- TREE case (owner 2026-07-29): a tree square is `solid` and carries NO destroy flag, so it
-- used to fall through to the plain solid->HARD rule -- i.e. it read as a RAILCAR, and a габарит
-- flank clipping one roadside holly on the inside of a 45deg corner DERAILED the loco at 74 km/h
-- (`e_americanholly_1_3` at 6526,14620, console 2026-07-29). Vanilla is no guide here: a CAR
-- cannot fell a tree (IsoTree.HitByVehicle plays a sound and calls Damage(this.damage), which
-- takes only 5% off), but a 112 t locomotive does. Detected by TYPE (instanceof IsoTree --
-- vanilla-proven, ISObjectClickHandler.lua:33), never by sprite name, so every tileset's trees
-- are covered at once.
--------------------------------------------------------------------------
local function smashableOn(sq)
    local outObj, outKind
    pcall(function()
        local objs = sq:getObjects()
        if not objs then return end
        for oi = 0, objs:size() - 1 do
            local o = objs:get(oi)
            if o then
                if instanceof(o, "IsoThumpable") then
                    outObj, outKind = o, "thumpable"; return
                elseif instanceof(o, "IsoWindow") then
                    outObj, outKind = o, "window"; return
                elseif instanceof(o, "IsoDoor") then
                    outObj, outKind = o, "door"; return
                elseif instanceof(o, "IsoTree") then
                    outObj, outKind = o, "tree"; return
                else
                    local sp = o:getSprite()
                    local props = sp and sp:getProperties()
                    if props and props:has("HitByCar") then
                        outObj, outKind = o, "hitByCar"; return
                    end
                    local nm = sp and sp:getName()
                    if nm and string.sub(nm, 1, 8) == "fencing_" then
                        outObj, outKind = o, "fence"; return
                    end
                    -- Concrete road block / barrier: the vanilla `StopCar` sprite flag (what
                    -- gates car-vs-barrier in IsoObject.Collision) -- no destroy path, but a
                    -- loco punches it through at speed (BARRIER class), stops at a creep.
                    if props and props:has("StopCar") then
                        outObj, outKind = o, "barrier"; return
                    end
                    -- Light MOVABLE barrier -- a wooden/plastic road barricade (construction_01_*
                    -- "Block/Road", Material Wood, IsMoveAble, solidtrans) has no HitByCar /
                    -- destroy path but a 112 t loco flattens it. Gate on Material so the CONCRETE
                    -- block (Stone, caught by StopCar above) never falls here.
                    if props and props:has("IsMoveAble") then
                        local mat = props:get("Material")   -- get(String): safe overload
                        if mat == "Wood" or mat == "Plastic" then
                            outObj, outKind = o, "fence"; return   -- flatten (removal path)
                        end
                    end
                end
            end
        end
    end)
    return outObj, outKind
end

--------------------------------------------------------------------------
-- vehicleAt(x,y,z) -> (car, sq) : the BaseVehicle intersecting the square, or nil.
-- STEP 4. A car on a level crossing is a BaseVehicle, NOT a tile object, so it never
-- shows up in getObjects()/smashableOn -- we ask the square directly.
--   sq:getVehicleContainer() (IsoGridSquare.java:10279) scans the nearby chunks and
--   returns the first vehicle whose body intersects (x,y,z), else nil. Our own
--   rr_loco/rr_collider are IsoAnimals (never in chunk.vehicles), so they can't be
--   returned here -- but we still gate on the `rr_` script-name prefix defensively.
-- Everything pcall'd: a mid-stream chunk unload never throws out of the sweep.
--------------------------------------------------------------------------
local function vehicleAt(x, y, z)
    local cell = getCell()
    if not cell then return nil end
    local gx, gy = math.floor(x), math.floor(y)
    local gz = math.floor((z or 0) + 0.5)
    if gz < 0 then gz = 0 end
    local sq, car
    pcall(function() sq = cell:getGridSquare(gx, gy, gz) end)
    if not sq then return nil end
    pcall(function() car = sq:getVehicleContainer() end)
    if car then
        local nm
        pcall(function() nm = car:getScriptName() end)
        if nm and string.sub(nm, 1, 3) == "rr_" then car = nil end   -- never our own
    end
    return car, sq
end

--------------------------------------------------------------------------
-- Which SIDE of the car the loco struck -> "Front"|"Rear"|"Left"|"Right" (the string
-- setSmashed/setBloodIntensity want -- RVSCarCrash.java:69-70). We compare the loco's
-- TRAVEL direction (mux,muy) against the car's forward vector: the struck face is the
-- one whose outward normal is most opposed to the incoming loco.
--   getForwardVector(Vector3f) (BaseVehicle.java:4423) = basis column 2; the world
--   horizontal plane is bullet (x,z) (see applyImpulseGeneric's relPos mapping), so the
--   car's world forward is (fwd.x, fwd.z).
-- df>0 (loco moving WITH the car's nose) => it caught the car's REAR; df<0 => FRONT.
-- Lateral hits pick Left/Right. Exact L/R handedness is cosmetic (which panel deforms +
-- where blood lands); Front/Rear vs side is what reads.
--------------------------------------------------------------------------
local function carHitSide(car, mux, muy)
    local fx, fy
    pcall(function()
        local v = Vector3f.new()
        car:getForwardVector(v)
        fx, fy = v:x(), v:z()
    end)
    if not (fx and fy) then return "Front" end
    local fl = math.sqrt(fx * fx + fy * fy)
    if fl < 1e-6 then return "Front" end
    fx, fy = fx / fl, fy / fl
    local rx, ry = -fy, fx                 -- car's right (one perpendicular; handedness cosmetic)
    local df = mux * fx + muy * fy         -- travel . car-forward
    local dr = mux * rx + muy * ry         -- travel . car-right
    if math.abs(df) >= math.abs(dr) then
        return (df > 0) and "Rear" or "Front"
    else
        return (dr > 0) and "Left" or "Right"
    end
end

--------------------------------------------------------------------------
-- hasIgnoredSprite(sq) -> true if the square carries a sprite whose name starts with any
-- Sweep.IGNORE_PREFIXES entry (e.g. "boulders_"). Used to drop natural scenery that sets a
-- solidity flag but must NEVER be an obstacle: stone boulders are never on the rails, but the
-- loco габарit can clip one on a curve. pcall-wrapped like every square read.
--------------------------------------------------------------------------
local function spriteIgnored(nm)
    local prefixes = Sweep.IGNORE_PREFIXES
    if not (nm and prefixes) then return false end
    for pi = 1, #prefixes do
        local p = prefixes[pi]
        if string.sub(nm, 1, #p) == p then return true end
    end
    return false
end

local function hasIgnoredSprite(sq)
    local prefixes = Sweep.IGNORE_PREFIXES
    if not (prefixes and #prefixes > 0) then return false end
    local hit = false
    pcall(function()
        local objs = sq:getObjects()
        if not objs then return end
        for oi = 0, objs:size() - 1 do
            local o  = objs:get(oi)
            local sp = o and o:getSprite()
            local nm = sp and sp:getName()
            if spriteIgnored(nm) then hit = true; return end
        end
    end)
    return hit
end

--------------------------------------------------------------------------
-- hasRailSprite(sq) -> true if any object on the square carries an `industry_railroad_*`
-- sprite. Used to scope the FAR standoff to vanilla railcars (Sweep.FAR_RAIL_ONLY): the
-- 6.8-tile standoff is a compensation for a railcar's overhanging sprite, and applying it
-- to ordinary building walls stops the loco a standoff short of things it should reach --
-- most visibly the engine-shed gate. pcall-wrapped like every square read.
--------------------------------------------------------------------------
local function hasRailSprite(sq)
    local hit = false
    pcall(function()
        local objs = sq and sq:getObjects()
        if not objs then return end
        for oi = 0, objs:size() - 1 do
            local o  = objs:get(oi)
            local sp = o and o:getSprite()
            local nm = sp and sp:getName()
            if nm and string.sub(nm, 1, 17) == "industry_railroad" then hit = true; return end
        end
    end)
    return hit
end

--------------------------------------------------------------------------
-- blocksMovement(o) -> true if the OBJECT ITSELF carries a solidity/collision flag
-- (`solid` / `solidtrans` / `collideN` / `collideW`). Per-OBJECT, never per-square: a
-- square pools the flags of everything standing on it, which is how the engine-shed
-- DOORWAY (rail floor + the building's collide) used to read as a railcar wall.
-- `props:has(IsoFlagType.x)` is the proven-safe read -- `PropertyContainer:Is` throws on
-- an object in this B42 build (see the HARD_USE_COLLIDE block below).
--------------------------------------------------------------------------
local function blocksMovement(o)
    local blocks = false
    pcall(function()
        local pr = o and o:getProperties()
        if not pr then return end
        blocks = pr:has(IsoFlagType.solid) or pr:has(IsoFlagType.solidtrans)
              or pr:has(IsoFlagType.collideN) or pr:has(IsoFlagType.collideW)
    end)
    return blocks
end

--------------------------------------------------------------------------
-- railcarOn(sq) -> true if ROLLING STOCK (a vanilla parked railcar / another loco) stands
-- on this square. This is now the ONLY source of the HARD class (owner 2026-07-29: the loco
-- flattens everything except rolling stock), so it is deliberately a NAMED, narrow test
-- rather than the old "solid and we don't recognise it" catch-all.
--   * a BLOCKING object whose own sprite is `industry_railroad_*` -- vanilla's metal railcar
--     walls/bodies. The running rails and switches of the same tileset are FLOOR sprites
--     (solidfloor only, no solid/solidtrans/collide), so the track the loco rides on never
--     matches: blocksMovement is what separates them, not the sprite name.
--   * a BLOCKING object whose sprite is in RAILCAR_SPRITES (a wooden boxcar body is
--     `carpentry_01_16`, a sprite that is an ordinary wall elsewhere) AND the square also
--     carries a rail sprite -- so a wooden HOUSE beside the right-of-way is still flattened
--     while a boxcar standing on the yard track still stops the loco.
--------------------------------------------------------------------------
local function railcarOn(sq)
    local hit = false
    pcall(function()
        local objs = sq and sq:getObjects()
        if not objs then return end
        local prefixes = Sweep.RAILCAR_PREFIXES or {}
        local exact    = Sweep.RAILCAR_SPRITES or {}
        local onRail   = nil                     -- lazily resolved (one extra pass, only if needed)
        for oi = 0, objs:size() - 1 do
            local o  = objs:get(oi)
            local sp = o and o:getSprite()
            local nm = sp and sp:getName()
            if nm and blocksMovement(o) then
                for pi = 1, #prefixes do
                    local p = prefixes[pi]
                    if string.sub(nm, 1, #p) == p then hit = true; return end
                end
                if exact[nm] then
                    if onRail == nil then onRail = hasRailSprite(sq) end
                    if onRail then hit = true; return end
                end
            end
        end
    end)
    return hit
end

--------------------------------------------------------------------------
-- flattenOn(sq) -> the object to REMOVE on a square that blocks but has no vanilla break
-- path -- a barrel, a crate, a bin, a lamp post, a map wall. The counterpart to the
-- inverted policy (RR.Obstacle.SOLID_IS_HARD = false): classify() already calls such a
-- square SMASHABLE, but effect().destroy needs something to destroy, and without a target
-- the loco would silently PHASE through it instead of flattening it.
-- Only ever called for a square that is solid, carries no typed smashable (thumpable/
-- window/door/tree/HitByCar/fence/concrete -- those have their own, better break paths) and
-- is NOT rolling stock. Picks the object that actually carries the blocking flag, so a
-- decorative sprite sharing the tile is left alone; IGNORE_PREFIXES scenery (boulders) and
-- railcar sprites are skipped, and a floor never qualifies (it carries `solidfloor`, which
-- blocksMovement does not read). nil => nothing to flatten and
-- the loco keeps rolling (the square's solidity came from something we refuse to touch).
--------------------------------------------------------------------------
local function flattenOn(sq)
    if Sweep.SMASH_UNKNOWN == false then return nil end
    local out
    pcall(function()
        local objs = sq and sq:getObjects()
        if not objs then return end
        local exact = Sweep.RAILCAR_SPRITES or {}
        for oi = 0, objs:size() - 1 do
            local o  = objs:get(oi)
            local sp = o and o:getSprite()
            local nm = sp and sp:getName()
            -- No floor test is needed (and B42 has no `IsoFloor` class to instanceof against):
            -- a floor carries `solidfloor`, which blocksMovement does not read, so the tile the
            -- loco stands on can never be picked as the thing to remove.
            if nm and not spriteIgnored(nm) and not exact[nm]
                    and string.sub(nm, 1, 17) ~= "industry_railroad"
                    and blocksMovement(o) then
                out = o; return
            end
        end
    end)
    return out
end

--------------------------------------------------------------------------
-- Classify the square at world (x,y,z) and return
--   class, solid, sq, smashObj, smashKind, solidStrong, solidTrans
-- via the pure policy. Fills `solid` (HARD tile) AND scans getObjects() for a smashable
-- object (STEP 3). Precedence lives in RR.Obstacle.classify: a destroyable thing
-- (thumpable/window/hitByCar) is SMASHABLE even when the square also reads solid (a
-- fence sets collideN/W), so a fence is smashed, never HARD-stopped.
--   solidStrong = sq:isSolid()      (flag `solid`      -- walls, big bodies)
--   solidTrans  = sq:isSolidTrans() (flag `solidtrans` -- thin on-tile barriers: a
--                                     concrete block, a buffer stop)
-- The HARD scan uses the split to stand off far from a big overhanging body (railcar)
-- but stop right at a small on-tile barrier -- see Sweep.update.
--------------------------------------------------------------------------
local function classAt(x, y, z)
    local cell = getCell()
    if not cell then return nil end
    local gx, gy = math.floor(x), math.floor(y)
    local gz = math.floor((z or 0) + 0.5)
    if gz < 0 then gz = 0 end
    local sq
    pcall(function() sq = cell:getGridSquare(gx, gy, gz) end)
    if not sq then return nil end

    local solidStrong, solidTrans = false, false
    pcall(function() solidStrong = sq:isSolid() end)
    pcall(function() solidTrans  = sq:isSolidTrans() end)
    -- Movement-collision flags -- the SAME ones a walking character stops on. A vanilla
    -- METAL railcar wall (industry_railroad_05_8/25 = WallW/WallN) sets `collide*` but NOT
    -- `solidtrans`, so the old solid/solidtrans-only test phased the loco straight through it
    -- (only a boxcar's carpentry wall, which does set solidtrans, stopped it). Reading the
    -- collide flags makes the loco stop wherever a pedestrian would. (Fences/concrete carry
    -- collide too, but classify precedence sends those to SMASHABLE/BARRIER first.)
    -- B42 IsoFlagType has ONLY collideN and collideW (walls live on a tile's N/W edges; a
    -- south/east wall belongs to the next tile over). There is NO collideS / collideE.
    -- OFF by default (Sweep.HARD_USE_COLLIDE) -- building/shed walls carry collide and would stop
    -- the loco at the depot shed doorway. When ON, only a RAILCAR wall (industry_railroad_* sprite)
    -- counts, so it stops at metal railcars but never at a building.
    local collide = false
    if Sweep.HARD_USE_COLLIDE then
        pcall(function()
            collide = sq:has(IsoFlagType.collideN) or sq:has(IsoFlagType.collideW)
        end)
        if collide then
            -- WHOSE collide flag is it? The square-level test ("any industry_railroad sprite
            -- here?") was WRONG at exactly one place, and it is the place the loco lives: the
            -- ENGINE SHED DOORWAY. The rails run INTO the shed, so a gate square carries BOTH
            -- the railroad FLOOR sprite (rail = true) AND the building's collide flag -- the
            -- restriction that was supposed to exclude buildings passed them straight through,
            -- and the loco stopped dead in its own doorway (owner in-game, twice).
            -- So attribute the flag to an OBJECT: the collide must be carried by the railroad
            -- sprite ITSELF (a metal railcar wall, industry_railroad_05_8/25 = WallW/WallN),
            -- not merely share a square with one. A rail floor carries no collide, so the
            -- doorway now reads clear while a railcar still stops the loco.
            -- `props:has(IsoFlagType.x)` is the proven-safe read (the fence branch below uses
            -- it); `PropertyContainer:Is` throws on an object in this B42 build -- don't.
            local rail = false
            pcall(function()
                local objs = sq:getObjects()
                if objs then
                    for oi = 0, objs:size() - 1 do
                        local o = objs:get(oi)
                        local sp = o and o:getSprite()
                        local nm = sp and sp:getName()
                        if nm and string.sub(nm, 1, 17) == "industry_railroad" then
                            if Sweep.HARD_COLLIDE_PER_OBJECT == false then
                                rail = true; break              -- legacy square-level test
                            end
                            local pr = o:getProperties()
                            if pr and (pr:has(IsoFlagType.collideN) or pr:has(IsoFlagType.collideW)) then
                                rail = true; break
                            end
                        end
                    end
                end
            end)
            collide = rail
        end
    end
    local solid = solidStrong or solidTrans or collide

    local smashObj, smashKind = smashableOn(sq)

    -- Ignore stone boulders (any IGNORE_PREFIXES scenery): if the square is solid ONLY because
    -- such a prop set solidtrans/collide (no strong `solid` wall, nothing smashable), drop the
    -- soft solidity so it classifies NEGLIGIBLE and the loco phases through it. A real `solid`
    -- wall on the same tile is untouched (solidStrong stays), so this only clears roadside rock.
    if Sweep.IGNORE_BOULDERS and solid and not solidStrong and not smashObj then
        if hasIgnoredSprite(sq) then
            solidTrans, collide = false, false
            solid = solidStrong          -- false here; the boulder no longer reads as HARD
        end
    end

    -- ROLLING STOCK is the only HARD thing left (owner 2026-07-29). Everything else that
    -- blocks is flattened -- but effect().destroy needs a TARGET, and a barrel/crate/bin/
    -- lamp post/map wall has no typed break path, so pick the blocking object itself.
    -- Suppressed on a railcar square: a railcar's own walls carry the blocking flag and
    -- would otherwise be handed over as a flatten target, which would make classify()
    -- read the railcar as SMASHABLE (SMASHABLE outranks HARD) and dismantle it tile by tile.
    local railcar = railcarOn(sq)
    if solid and not smashObj and not railcar then
        local fo = flattenOn(sq)
        if fo then smashObj, smashKind = fo, "flatten" end
    end

    local info = {
        solid     = solid,
        railcar   = railcar or nil,                                             -- the ONLY HARD hint
        thumpable = (smashKind == "thumpable" or smashKind == "door") or nil,
        window    = (smashKind == "window") or nil,
        hitByCar  = (smashKind == "hitByCar" or smashKind == "fence") or nil,  -- both = removal path
        tree      = (smashKind == "tree") or nil,                               -- IsoTree: felled
        barrier   = (smashKind == "barrier") or nil,                            -- concrete block
    }
    return RR.Obstacle.classify(info), solid, sq, smashObj, smashKind, solidStrong, (solidTrans or collide)
end

--------------------------------------------------------------------------
-- applySmash(obj, kind, sq, rec, absSpeed, smashed) -- destroy a SMASHABLE via the
-- engine-native call for its type. `smashed` is a per-tick list used to DEDUP: the sweep
-- takes several sub-probes per tick, and a destroyed thumpable/door leaves getObjects()
-- immediately (synchronous destroy) but a smashed WINDOW keeps its object (sprite swap
-- only) -- so we skip anything we already hit this tick. Every engine call is pcall'd so
-- a mid-tick removal (object already gone) never throws out of the sweep. Returns true if
-- it actually smashed something new (so the caller counts the strike).
--------------------------------------------------------------------------
local function applySmash(obj, kind, sq, rec, absSpeed, smashed)
    if not (obj and kind) then return false end
    for i = 1, #smashed do
        if smashed[i] == obj then return false end   -- already smashed this tick
    end
    smashed[#smashed + 1] = obj

    if kind == "thumpable" then
        -- Speed-scaled Damage, floored high enough to flatten any thumpable (default
        -- health tops out at ~2000 for a metal wall) at any V >= V_MIN -- a 112 t loco
        -- does not bounce off a fence. Then animalHit for the free break sound + event +
        -- destroy (it sees health<=0 and finishes the job). getHealth<=0 -> destroy is
        -- the belt-and-braces fallback if animalHit is a no-op for some object.
        local amt = 2500 + 500 * (absSpeed or 0)
        pcall(function() obj:Damage(amt) end)
        pcall(function() obj:animalHit(rec.animal) end)
        pcall(function() if obj:getHealth() <= 0 then obj:destroy() end end)
    elseif kind == "door" then
        -- IsoDoor has no Damage(float) in B42 -- destroy() drops plank/hinge/doorknob
        -- debris and removes itself. Speed gate already applied by effect() (creep=stop).
        pcall(function() obj:destroy() end)
    elseif kind == "window" then
        pcall(function() obj:smashWindow() end)   -- internally guarded by !destroyed
    elseif kind == "tree" then
        -- IsoTree.toppleTree(owner) IS the vanilla felling call (IsoTree.java:651): it removes
        -- the tree from the square, plays "FallingTree" off the owner's emitter, drops the log/
        -- branch/twig yield and recalcs the square + LOS. Passing our loco as `owner` is what
        -- gives the sound a position (the no-arg overload is silent). SP/host only by its own
        -- `!GameClient.client` guard -- same limitation as the rest of the sweep.
        -- NOT obj:Damage(): IsoTree.Damage only subtracts amount*0.05 and would need the tree's
        -- exact health to fell it in one strike (that is why a CAR never fells one).
        local done = false
        pcall(function() obj:toppleTree(rec.animal); done = true end)
        if not done then pcall(function() obj:toppleTree(); done = true end)  end
        if not done then pcall(function() sq:transmitRemoveItemFromSquare(obj) end) end
    elseif kind == "hitByCar" then
        -- Reproduce IsoObject.HitByVehicle without a BaseVehicle to hand it:
        --   1) the vanilla crush ONE-SHOT ("VehicleHitObject"), played off the loco's own
        --      emitter (positioned at the loco, always valid);
        --   2) swap the prop to its DamagedSprite if the sprite defines one -- a run-over
        --      cone becomes its flat crushed FloorOverlay, which carries NO HitByCar and
        --      is not solid, so it is inert and never re-triggers (self-dedup, no reliance
        --      on the per-tick `==` list); otherwise remove it outright.
        -- (No setDamage: IsoObject.setDamage wants a Java `short` and Kahlua refuses to
        -- narrow a Lua number to it -- "expected argument of type short, got Double" -- so
        -- the call throws and spams the console. The counter is moot here anyway.)
        pcall(function() rec.animal:getEmitter():playSound("VehicleHitObject") end)
        local dmgName
        pcall(function()
            local pr = obj:getSprite() and obj:getSprite():getProperties()
            if pr then dmgName = pr:get("DamagedSprite") end   -- get(String): safe overload
        end)
        if dmgName and dmgName ~= "" then
            pcall(function()
                local ns = getSprite(dmgName)
                if ns then obj:setSprite(ns) end
                sq:RecalcProperties()
            end)
        else
            pcall(function() sq:transmitRemoveItemFromSquare(obj) end)
        end
    elseif kind == "fence" then
        -- A `fencing_*` barrier. Use the VANILLA fence-break where the tile is registered
        -- (proper dented/debris sprite + break sound + dropped items), else flatten it.
        -- dir mirrors DebugContextMenu.OnBreakFence (collide flags + which side we hit from).
        local dir = IsoDirections.N
        pcall(function()
            local props = obj:getProperties()
            local ox, oy = sq:getX(), sq:getY()
            local lx, ly = rec.animal:getX(), rec.animal:getY()
            if props:has(IsoFlagType.collideN) then
                dir = (ly >= oy) and IsoDirections.N or IsoDirections.S
            else
                dir = (lx >= ox) and IsoDirections.W or IsoDirections.E
            end
        end)
        local done = false
        -- Registered BREAKABLE fence (wood etc.): destroyFence -> debris + break sound + items.
        pcall(function()
            if BrokenFences.getInstance():isBreakableObject(obj) then
                obj:destroyFence(dir); done = true
            end
        end)
        -- Registered BENDABLE fence (chain-link): collapse it in one loco pass.
        if not done then pcall(function()
            if BentFences.getInstance():isBendableFence(obj) then
                BentFences.getInstance():smashFence(obj, dir); done = true
            end
        end) end
        -- Unregistered barrier (e.g. Military Barrier fencing_01_96 -- no vanilla dented/debris
        -- sprite exists): a 112 t loco flattens it -> break sound + remove.
        if not done then
            pcall(function() rec.animal:getEmitter():playSound("BreakObject") end)
            pcall(function() sq:transmitRemoveItemFromSquare(obj) end)
        end
    elseif kind == "barrier" then
        -- Concrete road block (StopCar/Stone): no vanilla destroy path -> a loco punches it
        -- through. Heavy break one-shot + remove. (Condition damage is applied by the caller
        -- from RR.Obstacle.impactDamage(BARRIER, speed).)
        pcall(function() rec.animal:getEmitter():playSound("BreakObject") end)
        pcall(function() sq:transmitRemoveItemFromSquare(obj) end)
    elseif kind == "flatten" then
        -- The CATCH-ALL (owner 2026-07-29): a thing that blocks and has no vanilla break path
        -- of any kind -- a barrel, a crate, a bin, a lamp post, a map wall. There is nothing to
        -- call, so the loco simply takes it away: break one-shot + remove + recalc the square
        -- and its neighbours (a wall's collide flags live on the tile edges, so the neighbours
        -- must be recalculated too or the loco keeps stopping on a wall that is already gone).
        -- Same removal the unregistered-fence branch above uses, which is proven in-game.
        pcall(function() rec.animal:getEmitter():playSound("BreakObject") end)
        pcall(function() sq:transmitRemoveItemFromSquare(obj) end)
        pcall(function() sq:RecalcAllWithNeighbours(true) end)
    end
    return true
end

--------------------------------------------------------------------------
-- applyVehicleImpact(car, action, rec, p, sx, sy, absV) -> (car, side)
-- STEP 4. Clear a car off the rails ("shove") or crush it + clear it ("wreck"). Returns the
-- (possibly NEW) vehicle so the caller can flag its id for dedup -- setSmashed replaces the
-- object with a fresh one when a smashed variant exists.
--   1) wreck only: swap to the smashed model -- car = car:setSmashed(side) (BaseVehicle:10693,
--      returns a NEW vehicle, or `this` unchanged for a script with no smashed variant -> then
--      the parts-kill fallback: setCondition(0) over every part, VehiclePart:858). No blood
--      overlay (owner: damage, not gore).
--   2) CLEAR the car off the rails: a LOFT-IMPULSE at the car centre (pure translation, no spin)
--      -- lateral (off the rails) + UP so the tires leave the ground and the lateral force can
--      actually throw it clear (a grounded car's grip fights a flat push). applyImpulseGeneric
--      (from, dirX,dirY,dirZ, s) maps dir to bullet (dirX, dirZ, dirY) -- bullet Y is UP -- so
--      the 6th arg is the vertical kick; it normalizes (dir)*strength internally.
--   (A deterministic teleport-slide was ruled out: `Transform` is not a Lua global and there is
--    no Lua-reachable BaseVehicle position setter -- the impulse is the only lever.)
-- Every engine call pcall'd; a car mid-teleport never throws out of the sweep.
--------------------------------------------------------------------------
-- Play a vanilla vehicle-crash one-shot off the loco emitter (nil/"" or SOUND=false => silent).
local function playVehSound(rec, name)
    if Sweep.SOUND == false or not name or name == "" then return end
    pcall(function() rec.animal:getEmitter():playSound(name) end)
end

-- Zombie-audible collision noise. Every crash foley above is FMOD playback, which the AI
-- cannot hear -- this is the WorldSoundManager event that actually makes zombies come and
-- look. Radius/tier live in the pure RR_SoundConfig.impactNoiseRadius; RR_Sound throttles.
-- Positioned at the CONTACT point (sx, sy), not at the loco, so they converge on the wreck.
local function impactNoise(rec, kind, absV, sx, sy, sz)
    if not (RR.Sound and RR.Sound.impactNoise) then return end
    pcall(function() RR.Sound.impactNoise(rec, kind, absV, sx, sy, sz) end)
end

local function applyVehicleImpact(car, action, rec, p, sx, sy, absV)
    if not car then return car, nil end
    -- Impact sound tiered by SPEED (the visual is always a wreck now, but a slow touch should
    -- still sound light): VehicleCrash1 (touch) < V_MIN, VehicleCrash2 (shove) < V_WRECK, else heavy.
    do
        local T = RR.Obstacle.THRESH or {}
        local snd = Sweep.SOUND_WRECK
        if absV < (T.V_WRECK or 4.0) then snd = Sweep.SOUND_SHOVE end
        if absV < (T.V_MIN or 1.0)  then snd = Sweep.SOUND_TOUCH end
        playVehSound(rec, snd)
    end
    -- ...and the zombie-audible half: a one-shot world noise AT THE CAR. Deliberately not
    -- gated on Sweep.SOUND -- that flag mutes debug foley, but who hears a wreck is
    -- gameplay, not audio.
    impactNoise(rec, "vehicle", absV, sx, sy, p and p.z)
    local rx, ry = -(p.dirY or 0), (p.dirX or 0)          -- loco pose RIGHT (lateral off-rails)
    local rl = math.sqrt(rx * rx + ry * ry)
    if rl > 1e-6 then rx, ry = rx / rl, ry / rl else rx, ry = 1, 0 end
    local mux, muy = (p.dirX or 0), (p.dirY or 0)         -- forward pose (travel + hit-side)
    local ml = math.sqrt(mux * mux + muy * muy)
    if ml > 1e-6 then mux, muy = mux / ml, muy / ml else mux, muy = 0, 0 end

    local function throw(theCar, factor, up, fwd)
        local mass = 1000
        pcall(function() mass = theCar:getFudgedMass() end)
        pcall(function() theCar:setPhysicsActive(true) end)
        local dv = absV * (factor or 1.0)
        local floor = Sweep.CLEAR_DV_MIN or 0     -- min throw so a SLOW touch still clears the car
        if dv < floor then dv = floor end
        local cap = Sweep.CLEAR_DV_MAX or 250
        if dv > cap then dv = cap end
        -- LIGHT / WHEELLESS hull (a BURNT остов: mass ~500 + crawlThroughWheel = no wheels). The
        -- loft+flip is meant to beat a grounded car's TIRE GRIP -- but a wheelless hull has none,
        -- so the same impulse just launches it into a long floaty tumble that never clears the
        -- rails (owner in-game). It has no grip to fight, so a plain HORIZONTAL shove at the
        -- CENTRE slides it straight off -- kill the loft + flip for it. (LIGHT_MASS sits between
        -- burnt ~500 and normal ~800.)
        local isLight = mass < (Sweep.LIGHT_MASS or 650)
        local eUp    = isLight and 0 or (up or 0)
        local eFlipH = isLight and 0 or ((Sweep.FLIP ~= false) and (Sweep.FLIP_HEIGHT or 1.0) or 0)
        local strength = mass * dv
        local cx, cy, cz = sx, sy, (p.z or 0)
        pcall(function() cx = theCar:getX(); cy = theCar:getY(); cz = theCar:getZ() end)
        -- Horizontal push = lateral (right, off the rails) + FORWARD along the loco's travel
        -- (fwd fraction), so the car is carried DIAGONALLY -- swept aside AND dragged ahead,
        -- not purely sideways. applyImpulseGeneric normalizes (dir)*strength internally.
        local hx = rx + mux * (fwd or 0)
        local hy = ry + muy * (fwd or 0)
        -- Apply the push eFlipH above the car centre -> moment arm -> roll torque -> flip (0 for
        -- a light hull => pure translation, no tumble).
        pcall(function() theCar:applyImpulseGeneric(cx, cy, cz + eFlipH, hx, hy, eUp, strength) end)
        -- Register for the adaptive re-push (helps a stuck/burnt car; a moving car self-drops).
        -- Store the SAME horizontal dir so the re-push carries the forward drag too.
        if (Sweep.PUSH_TICKS or 0) > 0 then
            Sweep.pushes[#Sweep.pushes + 1] =
                { car = theCar, dirX = hx, dirY = hy, dv = dv, n = Sweep.PUSH_TICKS, lastX = cx, lastY = cy }
        end
    end

    local side = carHitSide(car, mux, muy)

    if action == "wreck" then
        -- Remember the pre-hit paint. A car's colour = base SKIN (livery texture) + an HSB TINT
        -- (colorHue/Saturation/Value, applied at BaseVehicle.java:1122). setSmashed builds a fresh
        -- vehicle and copies NEITHER, so the paint resets -- we capture both and re-apply them.
        local origSkin, oh, os_, ov
        if Sweep.KEEP_SKIN ~= false then
            pcall(function() origSkin = car:getSkinIndex() end)
            pcall(function() oh = car:getColorHue(); os_ = car:getColorSaturation(); ov = car:getColorValue() end)
        end
        local newCar = car
        pcall(function() newCar = car:setSmashed(side) or car end)
        local replaced = (newCar ~= nil and newCar ~= car)
        if not replaced then
            pcall(function()                                -- no smashed variant: kill the parts
                local n = car:getPartCount() or 0
                for i = 0, n - 1 do
                    local part = car:getPartByIndex(i)
                    if part then pcall(function() part:setCondition(0) end) end
                end
            end)
        end
        car = newCar or car
        -- Re-apply the original livery + HSB tint so the crumpled model keeps its pre-hit colour.
        if Sweep.KEEP_SKIN ~= false then
            if origSkin ~= nil then pcall(function() car:setSkinIndex(origSkin); car:updateSkin() end) end
            if oh ~= nil and os_ ~= nil and ov ~= nil then
                pcall(function() car:setColorHSV(oh, os_, ov) end)   -- vanilla-proven (FenrisScenario)
            end
        end
        throw(car, Sweep.WRECK_FACTOR or 80.0, Sweep.WRECK_UP or 0.4, Sweep.WRECK_FWD or 0.6)
    else
        throw(car, Sweep.SHOVE_FACTOR or 80.0, Sweep.SHOVE_UP or 0.3, Sweep.SHOVE_FWD or 0.5)
    end
    return car, side
end

--------------------------------------------------------------------------
-- Debug: list every object's sprite name on a square, e.g.
-- "industry_railroad_05_45 carpentry_01_16". Lets us see how far a large object
-- (a railcar) reaches toward the loco during the approach. (Per-object solidity is
-- intentionally NOT queried here: PropertyContainer:Is on an object throws in this
-- B42 build, and even a pcall-caught throw spams the console every tick.)
--------------------------------------------------------------------------
local function spriteReport(sq)
    local out = ""
    pcall(function()
        local objs = sq and sq:getObjects()
        if objs then
            for oi = 0, objs:size() - 1 do
                local o = objs:get(oi)
                local sp = o and o:getSprite()
                local nm = sp and sp:getName()
                if nm then out = out .. nm .. " " end
            end
        end
    end)
    return out
end

--------------------------------------------------------------------------
-- update(rec, d0, d1, dt) -> { distance, stopped, dvFrac }
-- Sub-samples the leading edge from d0 (pre-step) to d1 (post-step), and at each sub-step
-- probes DENSELY across the full width (lats) at two reaches:
--   * NEAR reach (half + NEAR_MARGIN): on-tile obstacles. SMASHABLE -> destroyed, loco
--     keeps rolling, bleeding a small dvFrac (summed, capped at SMASH_DV_CAP); distance is
--     NOT clamped. HARD (solid/solidtrans) -> stop at the last-clear distance.
--   * FAR reach (half + STOP_MARGIN, `solid` only): a big overhanging body (railcar) ->
--     stop with the standoff so the loco does not bury into the sprite.
-- The first square that classifies to a STOP effect returns the last-clear distance and
-- stopped=true (no tunnelling). HARD wins over smash within a tick (a wall behind a fence
-- still stops the loco). Nothing hit -> d1 unchanged, stopped=false, dvFrac=0.
--------------------------------------------------------------------------
function Sweep.update(rec, d0, d1, dt)
    local NO = { distance = d1, stopped = false, dvFrac = 0 }
    if not (Sweep.enabled and rec and rec.animal and rec.route
            and RR.Spline and RR.Body and RR.Obstacle) then
        return NO
    end

    local dd = (d1 or 0) - (d0 or 0)

    -- CALIBRATION: never stop; when the loco comes to REST with a solid tile close
    -- ahead of an end, print the ideal STOP_MARGIN once (re-armed once it moves again).
    if Sweep.calibrate then
        local moving = (dd > 1e-4 or dd < -1e-4)
        if moving then
            rec._calibDone = false
        elseif not rec._calibDone and rec.lastPose then
            local half = RR.Body.extents(sizeOf(rec)) * 0.5
            local p = rec.lastPose
            local fx, fy = p.dirX or 0, p.dirY or 0
            local function scanSolid(sx, sy, dx, dy)
                for k = 0, 24 do
                    local _, solid = classAt(sx + dx * k, sy + dy * k, p.z)
                    if solid then return k end
                end
                return nil
            end
            local kf = scanSolid(p.x + fx * half, p.y + fy * half, fx, fy)
            local kb = scanSolid(p.x - fx * half, p.y - fy * half, -fx, -fy)
            local best = kf
            if kb and (not best or kb < best) then best = kb end
            if best then
                rec._calibDone = true
                print(string.format(
                    "[Railroader] CALIBRATE: park here -> STOP_MARGIN = %d   (front end %s / rear end %s tiles to solid)",
                    best, tostring(kf), tostring(kb)))
            end
        end
        return NO
    end

    if dd > -1e-6 and dd < 1e-6 then return NO end      -- not moving: nothing to sweep

    local size    = sizeOf(rec)
    local hw        = rec.hw or RR.Body.halfWheelbase(size)
    local len, wid  = RR.Body.extents(size)
    -- half = collider footprint half-length (~7.8). The DRAWN body is ~1.5 tiles SHORTER per
    -- end (U overlay 2026-07-23: green footprint overhangs the model), so the near stop keys
    -- off half MINUS NOSE_TRIM to land the DRAWN nose at the obstacle; the far scan (railcar)
    -- keeps the full footprint, on which STOP_MARGIN was calibrated.
    local half      = len * 0.5
    local nearHalf  = half - (Sweep.NOSE_TRIM or 0)
    if nearHalf < 0 then nearHalf = 0 end
    local nearReach = nearHalf + (Sweep.NEAR_MARGIN or 0)   -- on-tile obstacles (smash + hard)
    local farReach  = half + (Sweep.STOP_MARGIN or 0)       -- big overhanging body (railcar), solid only
    local absV      = math.abs(rec.speed or (rec.drive and rec.drive.v) or 0)
    local smashed   = {}     -- objects smashed THIS tick (dedup across sub-probes)
    local dvAccum   = 0      -- total SMASHABLE speed-bleed this tick (capped below)
    -- VEHICLE dedup (Step 4). A car spans several tiles and lingers a few ticks after a hit,
    -- so without a latch we would re-shove/re-wreck the SAME car every sub-probe and every tick.
    -- Keyed by the car OBJECT (Kahlua == is reliable for the same Java vehicle -- the sub-probe
    -- dedup already relies on it), NOT by car:getId(): getId() returns vehicleId, which is -1
    -- until createPhysics() allocates it, so multiple fresh/pre-placed cars can ALL read -1 --
    -- the old id-keyed latch then flagged -1 on the first car and skipped every later car (loco
    -- drove through them, owner in-game 2026-07). Each entry carries a TTL (ticks) so the latch
    -- self-expires once the car has cleared; a wreck's NEW object is latched too.
    rec._hitCars = rec._hitCars or {}
    do                                        -- age the latch once per tick, drop expired
        local kept = {}
        for i = 1, #rec._hitCars do
            local e = rec._hitCars[i]
            e.ttl = (e.ttl or 0) - 1
            if e.ttl > 0 and e.car then kept[#kept + 1] = e end
        end
        rec._hitCars = kept
    end
    local function carSeen(car)
        for i = 1, #rec._hitCars do if rec._hitCars[i].car == car then return true end end
        return false
    end
    local function latchCar(car)
        if car and not carSeen(car) then
            rec._hitCars[#rec._hitCars + 1] = { car = car, ttl = Sweep.HIT_TTL or 40 }
        end
    end

    -- Lateral offsets covering the drawn HULL width at LAT_STEP resolution (габарit), so no
    -- on-track obstacle between the old 3 flanks is skipped. Includes the exact edges. Starts
    -- from the footprint half-width and subtracts WIDTH_TRIM per side so it keys to the DRAWN
    -- hull, not the mesh bbox (whose grab-irons/steps over-cover sideways -- see the CALIBRATION
    -- block; this stops the sweep smashing trackside fences / derailing on roadside boulders).
    -- LOCO_HALFW still hard-overrides. Floored so a bad trim can never collapse the gauge to 0.
    local halfW = Sweep.LOCO_HALFW or (wid * 0.5 - (Sweep.WIDTH_TRIM or 0))
    if halfW < 0.5 then halfW = 0.5 end
    -- Centre the band on the HULL centreline (anchor + LAT_BIAS), the same centreline the
    -- collider box and the crush footprint use -- otherwise the span is symmetric about a
    -- point that isn't the middle of the drawn loco, i.e. a gauge that is wider on one
    -- side than the other.
    local latC  = (RR.Body.LAT_BIAS or 0)
    local lats  = {}
    local ls    = Sweep.LAT_STEP or 0.5
    if ls < 0.1 then ls = 0.1 end
    local nlat  = math.floor(halfW / ls + 1e-6)
    for k = -nlat, nlat do lats[#lats + 1] = latC + k * ls end
    if (lats[#lats] - latC) < halfW - 1e-6 then           -- ensure the two edges are probed
        lats[#lats + 1] = latC + halfW
        lats[#lats + 1] = latC - halfW
    end

    -- Unit TRAVEL direction from this tick's motion. Robust: it always points the way
    -- the loco is actually going (so the leading edge is the end going INTO the
    -- obstacle), it is well-defined whenever the loco moves, and it never collapses to
    -- ~0 the way a facing/chord sign (s * pose.dirX) could on reverse or a degenerate
    -- pose -- which was letting the stop trip on the mid/trailing edge (loco half-in).
    local c0 = poseAt(rec, d0, hw)
    local c1 = poseAt(rec, d1, hw)
    local mvx, mvy = c1.x - c0.x, c1.y - c0.y
    local moveLen  = math.sqrt(mvx * mvx + mvy * mvy)
    if moveLen < 1e-6 then return NO end
    local mux, muy = mvx / moveLen, mvy / moveLen
    -- Signed route direction of travel this tick (+1 = increasing distance / forward).
    local travelSign = (dd > 0) and 1 or -1

    local nsteps = math.ceil(moveLen / SAMPLE_STEP)
    if nsteps < 1 then nsteps = 1 end

    -- Build the last-clear stop point + debug line, shared by the HARD standoff stop and
    -- the SMASHABLE creep-stop (a fence a crawling loco cannot get moving through).
    -- via = which scan fired ("near"/"far"/"creep") and flags = "solid"/"solidtrans" -- so a
    -- single railcar test tells us whether the FAR scan caught it (and on which flag).
    local function stopAt(prevD, cls, sx, sy, sq, via, flags, latUsed)
        local contact = prevD
        if dd > 0 and contact < d0 then contact = d0 end
        if dd < 0 and contact > d0 then contact = d0 end
        if Sweep.debug then
            rec._obsStopCd = (rec._obsStopCd or 0) - (dt or 0)   -- own throttle (not shared with PROBE)
            if rec._obsStopCd <= 0 then
                rec._obsStopCd = DBG_INTERVAL
                local cc = poseAt(rec, contact, hw)
                local gap = math.sqrt((sx - cc.x) ^ 2 + (sy - cc.y) ^ 2)
                print(string.format(
                    "[Railroader] obstacle STOP: class=%s via=%s flags=%s speed=%.2f | half=%.1f near=%.1f far=%.1f | centre(%.1f,%.1f) sample(%.1f,%.1f) gap=%.1f | sprites=[%s]",
                    tostring(cls), tostring(via or "?"), tostring(flags or "?"), rec.speed or 0,
                    half, Sweep.NEAR_MARGIN or 0, Sweep.STOP_MARGIN or 0,
                    cc.x, cc.y, sx, sy, gap, spriteReport(sq)))
            end
        end
        -- impactV/impactClass let the caller apply HARD condition damage + a derail roll ONCE
        -- per contact (RR_TrainEntity.onTick), using the speed AT impact (absV, pre-stop).
        -- impactVia/impactFlags/impactSprites/impactAt: ALWAYS-ON diagnostic (a stop is rare, so
        -- spriteReport here costs nothing) -- the caller logs them on a HARD impact / derail so a
        -- FALSE stop names its trigger (which scan, which flag, which sprite, which world tile)
        -- without turning on the per-tick Sweep.debug spam.
        -- Lateral offset of the trigger from the loco CENTRELINE (tiles, + = right of travel).
        -- Prefer the ACTUAL probe offset (latUsed, within +/-halfW) -- unambiguous. The geometric
        -- fallback (sample vs the contact-centre frame) is SKEWED on a curve, which is exactly
        -- what made a straight-projected probe read lat -3.7 at halfW 0.76. Tells an edge/roadside
        -- false-catch (|w| ~ halfW) from a genuine on-track block (|w| ~ 0).
        -- Reported in the HULL frame (probe offset minus the band's centre), so the
        -- invariant the log is read against stays |lat| <= halfW whatever LAT_BIAS is --
        -- same frame the RR_Body.toLocal fallback below measures in.
        local impW = latUsed and (latUsed - latC) or nil
        if impW == nil then
            pcall(function()
                local cc = poseAt(rec, contact, hw)
                local _, w = RR.Body.toLocal(cc, sx, sy)
                impW = w
            end)
        end
        return { distance = contact, stopped = true, dvFrac = 0, impactV = absV, impactClass = cls,
                 impactVia = via, impactFlags = flags, impactSprites = spriteReport(sq),
                 impactX = sx, impactY = sy, impactW = impW, impactHalfW = halfW }
    end

    -- Leading-edge probe base at `reach` ahead of the sub-step centre, FOLLOWING THE SPLINE
    -- (curve-aware) rather than a straight projection off the motion tangent. A straight ~7-tile
    -- (near) / ~15-tile (far) projection swings OFF the rails on a curve and trips on trackside
    -- structure -- the loco "упирается" short of the shed doorway (owner in-game 2026-07-25: tile
    -- with industry_bunker/fixtures read at lat -3.7 vs halfW 0.76). Sampling the route at
    -- d + sign*reach keeps the probe ON the rails; the lateral is perpendicular to the LOCAL rail
    -- tangent there, so the width sweep aligns with the track through the curve. pcall-guarded:
    -- if the ahead distance runs past a route end, fall back to the old straight projection.
    local function leadAt(d, reach)
        local lp
        pcall(function() lp = poseAt(rec, d + travelSign * reach, hw) end)
        if not lp then
            local c = poseAt(rec, d, hw)
            lp = { x = c.x + mux * reach, y = c.y + muy * reach, z = c.z, dirX = mux, dirY = muy }
        end
        local lrx, lry = -(lp.dirY or 0), (lp.dirX or 0)
        local ln = math.sqrt(lrx * lrx + lry * lry)
        if ln > 1e-6 then lrx, lry = lrx / ln, lry / ln else lrx, lry = -muy, mux end
        return lp, lrx, lry
    end

    local prevD = d0
    for i = 1, nsteps do
        local d = d0 + dd * (i / nsteps)
        local p = poseAt(rec, d, hw)      -- sub-step CENTRE pose (used for the vehicle shove dir)

        -- VEHICLE probe (Step 4 -- level crossing). A car is a BaseVehicle, not a tile
        -- object, and classify(vehicle) BEATS the tile flags on the same square, so we test
        -- it FIRST, before the tile near-scan. A car straddling the track always overlaps the
        -- CENTRELINE, so probing the axis + the two width edges at the near reach catches it
        -- cheaply (one getVehicleContainer per point) -- no need for the dense lat sweep.
        --   creep (< V_MIN)  : hard stop AT the car (path locked -- the loco can't shove a car
        --                      from a crawl). Returned like a HARD stop (clamp distance).
        --   shove (< V_WRECK): applyImpulseGeneric off the rails, car intact, loco rolls on.
        --   wreck (>= V_WRECK): setSmashed + blood + big lateral throw, loco rolls on.
        -- Shove/wreck are ONE-SHOT per car (rec._hitCars, by object + TTL); the creep-stop is
        -- re-evaluated fresh every tick (a standing car keeps blocking). Condition damage +
        -- the derail roll are applied INLINE here (mirrors the BARRIER block below).
        do
            -- Catch the car VEH_MARGIN ahead of the drawn nose (> NEAR_MARGIN) so it launches
            -- sideways a beat before the loco body arrives -- cuts the "loco through car" frame.
            local vehReach = nearHalf + (Sweep.VEH_MARGIN or 2.5)
            local lpV, lrxV, lryV = leadAt(d, vehReach)
            for _, lat in ipairs({ latC, latC + halfW, latC - halfW }) do
                local sx, sy = lpV.x + lrxV * lat, lpV.y + lryV * lat
                local car, vsq = vehicleAt(sx, sy, lpV.z)
                if car then
                    local eff = RR.Obstacle.effect(RR.Obstacle.CLASS.VEHICLE, absV)
                    if eff and eff.stop then
                        -- (VEHICLE never stops now -- it wrecks at any speed. Kept as a safety
                        -- net if the policy is ever reverted to a creep-stop tier.)
                        return stopAt(prevD, RR.Obstacle.CLASS.VEHICLE, sx, sy, vsq, "veh-creep", "vehicle", lat)
                    elseif eff and (eff.action == "shove" or eff.action == "wreck") then
                        if not carSeen(car) then
                            local newCar, side = applyVehicleImpact(car, eff.action, rec, p, sx, sy, absV)
                            latchCar(car)
                            if newCar and newCar ~= car then latchCar(newCar) end  -- wreck's new object
                            dvAccum = dvAccum + (eff.dvFrac or 0)
                            -- Loco damage + derail roll (few % / ~5% at high) -- once per car.
                            local dmg = RR.Obstacle.impactDamage(RR.Obstacle.CLASS.VEHICLE, absV) or 0
                            if dmg > 0 and rec.engine and rec.engine.condition then
                                rec.engine.condition = math.max(0, rec.engine.condition - dmg)
                            end
                            -- No derail from a car (owner decision A, Task 1.N step 6): derailment
                            -- is DETERMINISTIC + HARD-only (Obstacle.shouldDerailImpact) plus the
                            -- broken open end -- a VEHICLE only debits condition. The probabilistic
                            -- VEHICLE roll is deferred to a future re-railing plan (owner B).
                            if Sweep.debug then
                                print(string.format(
                                    "[Railroader] obstacle VEHICLE: action=%s side=%s v=%.2f (%.0f km/h) dvFrac=%.3f dmg=%.3f cond=%.2f",
                                    tostring(eff.action), tostring(side), rec.speed or 0, (rec.speed or 0) * 3.6,
                                    eff.dvFrac or 0, dmg, (rec.engine and rec.engine.condition) or -1))
                            end
                        end
                        -- shove/wreck: NOT a stop -- fall through, the loco keeps rolling.
                    end
                end
            end
        end

        -- NEAR scan (half + NEAR_MARGIN), dense across the full width: handles every ON-TILE
        -- obstacle at the nose. SMASHABLE -> destroyed (loco keeps rolling, small dvFrac), or
        -- AT creep a stop instead (a fence stalls a crawling loco -- "упирается"). HARD (solid
        -- OR solidtrans, on its own tile: concrete Block, buffer stop, brick wall) -> stop.
        local lpN, lrxN, lryN = leadAt(d, nearReach)
        for _, lat in ipairs(lats) do
            local sx, sy = lpN.x + lrxN * lat, lpN.y + lryN * lat
            local cls, _solid, sq, obj, kind, ss, st = classAt(sx, sy, lpN.z)
            if cls == RR.Obstacle.CLASS.SMASHABLE or cls == RR.Obstacle.CLASS.BARRIER then
                -- SMASHABLE (fence/cone) and BARRIER (concrete block) share the near-scan
                -- shape: below their stop speed they STOP (a creep upирается), above they are
                -- destroyed and the loco rolls on. BARRIER also bleeds more speed and debits
                -- real condition (impactDamage tiers); SMASHABLE debits a tiny amount.
                local eff = RR.Obstacle.effect(cls, absV)
                if eff and eff.stop then
                    return stopAt(prevD, cls, sx, sy, sq, "creep",
                                  (cls == RR.Obstacle.CLASS.BARRIER) and "barrier" or "smashable", lat)
                elseif eff and eff.destroy and obj then
                    if applySmash(obj, kind, sq, rec, absV, smashed) then
                        dvAccum = dvAccum + (eff.dvFrac or 0)
                        -- Zombies hear the destruction (the break foley above is FMOD-only).
                        -- Throttled in RR_Sound, so a fence LINE is one bang, not one per post.
                        impactNoise(rec, (cls == RR.Obstacle.CLASS.BARRIER) and "barrier" or "smashable",
                                    absV, sx, sy, lpN.z)
                        -- Condition damage (Task 1.N): ONLY a BARRIER (concrete block) debits
                        -- the loco's condition, by the owner's speed-tiered curve. Fences/cones
                        -- (SMASHABLE) are negligible (design: <0.1%) -> no condition hit. Already
                        -- persisted (stashState -> md.rrCond); HUD gauge + immobilize-at-0 later.
                        -- CONCRETE (BARRIER): monotonic condition damage ONLY. Owner decision A
                        -- (Task 1.N step 6): concrete does NOT derail -- derailment is DETERMINISTIC
                        -- + HARD-only (Obstacle.shouldDerailImpact) plus the broken open end. The
                        -- probabilistic concrete-hump derail is deferred to a future re-railing plan
                        -- (owner B). Fences/cones (SMASHABLE) do 0 damage.
                        local dmg = 0
                        if cls == RR.Obstacle.CLASS.BARRIER then
                            dmg = RR.Obstacle.impactDamage(cls, absV) or 0
                            if dmg > 0 and rec.engine and rec.engine.condition then
                                rec.engine.condition = math.max(0, rec.engine.condition - dmg)
                            end
                        end
                        if Sweep.debug then
                            print(string.format(
                                "[Railroader] obstacle SMASH: kind=%s class=%s v=%.2f (%.0f km/h) dvFrac=%.3f dmg=%.3f cond=%.2f | sprites=[%s]",
                                tostring(kind), tostring(cls), rec.speed or 0, (rec.speed or 0) * 3.6,
                                eff.dvFrac or 0, dmg, (rec.engine and rec.engine.condition) or -1,
                                spriteReport(sq)))
                        end
                    end
                end
            elseif cls == RR.Obstacle.CLASS.HARD and (ss or st) then
                local eff = RR.Obstacle.effect(cls, absV)
                if eff and eff.stop then
                    return stopAt(prevD, cls, sx, sy, sq, "near", ss and "solid" or "solidtrans/collide", lat)
                end
            end
        end

        -- FAR scan (half + STOP_MARGIN), dense: only a big overhanging BODY (vanilla railcar/
        -- wall) whose `solid` tile sits behind a sprite that reaches toward the loco -- the
        -- standoff halts it before the sprite. By default only the strong `solid` flag fires
        -- here (HARD_FAR_SOLID_ONLY), so a small `solidtrans` prop is NOT stopped a whole
        -- standoff early -- the near scan already handled it above.
        local lpF, lrxF, lryF = leadAt(d, farReach)
        for _, lat in ipairs(lats) do
            local sx, sy = lpF.x + lrxF * lat, lpF.y + lryF * lat
            local cls, _solid, sq, _o, _k, ss, st = classAt(sx, sy, lpF.z)
            local farHit
            if Sweep.HARD_FAR_SOLID_ONLY then farHit = ss else farHit = (ss or st) end
            -- Scope the standoff to what it was calibrated on: a vanilla railcar. Any other
            -- solid (a shed jamb, a house wall beside the right-of-way) is left to the near
            -- scan, which stops at contact instead of 6.8 tiles early.
            if farHit and Sweep.FAR_RAIL_ONLY and not hasRailSprite(sq) then farHit = false end
            if cls == RR.Obstacle.CLASS.HARD and farHit then
                local eff = RR.Obstacle.effect(cls, absV)
                if eff and eff.stop then
                    return stopAt(prevD, cls, sx, sy, sq, "far", ss and "solid" or "solidtrans/collide", lat)
                end
            end
        end
        prevD = d
    end

    if dvAccum > (Sweep.SMASH_DV_CAP or 1) then dvAccum = Sweep.SMASH_DV_CAP end

    -- STEP-2 DIAGNOSTIC PROBE: while moving and NOT stopping, report the furthest
    -- leading-edge square each interval, so we can see whether the intended obstacle
    -- actually reads as solid (isSolid). If the loco visibly reaches a railcar but the
    -- probe says solid=false, isSolid is insufficient and we switch to object-level
    -- collide detection (getObjects + collideN|W).
    if Sweep.debug then
        rec._obsDbgCd = (rec._obsDbgCd or 0) - (dt or 0)
        if rec._obsDbgCd <= 0 then
            rec._obsDbgCd = DBG_INTERVAL
            local p = poseAt(rec, d1, hw)
            local ex = p.x + mux * half
            local ey = p.y + muy * half
            local cls, solid, sq = classAt(ex, ey, p.z)
            print(string.format(
                "[Railroader] obstacle PROBE: class=%s solid=%s speed=%.2f | edge(%.1f,%.1f) | sprites=[%s]",
                tostring(cls), tostring(solid), rec.speed or 0, ex, ey, spriteReport(sq)))
        end
    end
    -- Nothing hard-stopped us: keep rolling, but hand back any SMASHABLE speed-bleed so
    -- the caller debits it from RR_Drive (distance NOT clamped -- the loco drives on).
    return { distance = d1, stopped = false, dvFrac = dvAccum }
end

--------------------------------------------------------------------------
-- CALIBRATION helper. Drive the loco (with the sweep OFF: RR.ObstacleSweep.enabled
-- = false) up to where it should stop, then call RR.ObstacleSweep.mark() in the
-- console. It prints each body end and how many tiles from that end to the nearest
-- solid tile ahead -- the tile count from the end touching the obstacle IS the ideal
-- STOP_MARGIN. Not gated on debug.
--------------------------------------------------------------------------
function Sweep.mark()
    local rec = (RR.Ride and RR.Ride.current)
        or (RR.TrainEntity and RR.TrainEntity.active and RR.TrainEntity.active[1])
    if not (rec and rec.lastPose and RR.Body) then
        print("[Railroader] MARK: no active loco / pose")
        return
    end
    local size = sizeOf(rec)
    local len  = RR.Body.extents(size)
    local half = len * 0.5
    local p    = rec.lastPose
    local fx, fy = p.dirX or 0, p.dirY or 0

    -- Scan outward from a point along (dx,dy) for the first solid tile (up to 24 tiles).
    local function scanSolid(sx, sy, dx, dy)
        for k = 0, 24 do
            local _, solid = classAt(sx + dx * k, sy + dy * k, p.z)
            if solid then return k, sx + dx * k, sy + dy * k end
        end
        return nil
    end

    local fEx, fEy = p.x + fx * half, p.y + fy * half   -- +facing end
    local bEx, bEy = p.x - fx * half, p.y - fy * half   -- -facing end
    local kf = scanSolid(fEx, fEy, fx, fy)
    local kb = scanSolid(bEx, bEy, -fx, -fy)

    print(string.format("[Railroader] MARK: dist=%.2f centre(%.1f,%.1f) dir(%.2f,%.2f) half=%.1f",
        rec.distance or 0, p.x, p.y, fx, fy, half))
    print(string.format("   +end(%.1f,%.1f): solid %s tiles ahead  => if THIS end touches, STOP_MARGIN=%s",
        fEx, fEy, tostring(kf), tostring(kf)))
    print(string.format("   -end(%.1f,%.1f): solid %s tiles ahead  => if THIS end touches, STOP_MARGIN=%s",
        bEx, bEy, tostring(kb), tostring(kb)))
end

--------------------------------------------------------------------------
-- Debug (Step 4): spawn a test car ON the running rails, `tilesAhead` down the route
-- from the loco -- a level-crossing sim. Facing E = perpendicular to a N-S track.
-- Console only: RR.ObstacleSweep.spawnCar() (no key binding). Try scripts with a
-- smashed variant (Base.CarNormal / ModernCar / PickUpTruck) AND one WITHOUT (e.g. a
-- van) to exercise the setCondition(0) fallback.
--   addVehicleDebug(scriptName, IsoDirections, nil, square) -> BaseVehicle (vanilla
--   global, ProfessionVehicles.lua:26 -- sets the facing, the reliable spawn path).
--------------------------------------------------------------------------
function Sweep.spawnCar(script, tilesAhead)
    script = script or Sweep.CAR_SCRIPT or "Base.CarNormal"
    local rec = (RR.TrainEntity and RR.TrainEntity.active and RR.TrainEntity.active[1])
    if not (rec and rec.route) then print("[Railroader] no loco (press O first)"); return end
    local d = (rec.distance or 0) + (tilesAhead or 18)
    local p = RR.Spline.sample(rec.route, d)
    -- match the loco's world offset so the car lands on the SAME rails the loco rides
    local wx = p.x + (rec.ox or 0)
    local wy = p.y + (rec.oy or 0)
    local wz = math.floor((p.z or 0) + (rec.oz or 0))
    local car
    pcall(function()
        local sq = getCell():getGridSquare(math.floor(wx), math.floor(wy), wz)
        car = addVehicleDebug(script, IsoDirections.E, nil, sq)
    end)
    print(string.format("[Railroader] test car '%s' at (%.0f,%.0f,%d) d=%.0f -> %s",
        script, wx, wy, wz, d, tostring(car)))
    return car
end

-- Adaptive re-push (see Sweep.PUSH_TICKS). Each tick, for every car still being cleared: measure
-- how far it moved HORIZONTALLY since last tick. If it cleared the PUSH_MOVE_MIN threshold it is
-- sliding fine -> drop it (fresh cars land here after one tick, unchanged behaviour). If it is
-- STILL stuck (a burnt wreck whose flat tires grip the ground) shove it laterally again -- the
-- loft has lifted the tires by now, so the push finally translates it. Bounded by n ticks.
local function stepPushes()
    local list = Sweep.pushes
    if not list or #list == 0 then return end
    local keep = {}
    for i = 1, #list do
        local s = list[i]
        if s and s.car and s.n and s.n > 0 then
            local x, y, moved = s.lastX, s.lastY, 0
            pcall(function() x, y = s.car:getX(), s.car:getY() end)
            moved = math.sqrt((x - s.lastX) ^ 2 + (y - s.lastY) ^ 2)
            s.lastX, s.lastY = x, y
            if moved < (Sweep.PUSH_MOVE_MIN or 0.25) then      -- still stuck: shove again (same diagonal dir)
                pcall(function()
                    local mass = s.car:getFudgedMass() or 1000
                    local cz = s.car:getZ() or 0
                    s.car:applyImpulseGeneric(x, y, cz, s.dirX or 0, s.dirY or 0, 0, mass * (s.dv or 0))
                end)
                s.n = s.n - 1
                if s.n > 0 then keep[#keep + 1] = s end
            end
            -- else: it's clearing on its own -> drop it (do not re-push a moving car)
        end
    end
    Sweep.pushes = keep
end
Events.OnTick.Add(stepPushes)

RR = RR or {}
RR.ObstacleSweep = Sweep
print("[Railroader] RR_ObstacleSweep.lua: loaded OK (step 2: HARD stop | step 3: SMASHABLE | step 4: VEHICLE shove/wreck).")

return Sweep
