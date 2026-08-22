--***********************************************************************
-- Railroader / RR_CabClimate  -- the engine-facing half of the cab as shelter (Task 1.P)
--
-- The rules live in the pure, unit-tested shared/Railroader/RR_Cab.lua. This file
-- does the two things that need the live engine, and it does them through TWO
-- SEPARATE vanilla channels, because B42 keeps rain and temperature apart:
--
-- ==== 1. RAIN -- the shelter marker on the CHARACTER ====
--
-- Vanilla's "under a roof" is not a runtime switch. It is a chain fixed at chunk
-- load: a BlockRain/solidfloor tile above the square -> IsoGridSquare.haveRoof ->
-- the `exterior` property. `haveRoof` IS writable from Lua, but it is also
-- SERIALIZED INTO THE CHUNK HEADER, so roofing a rail tile under a moving loco would
-- bake a permanent roof into the save the first time that chunk is written. Not an
-- option for a loco that crosses the whole county.
--
-- There is a second, CHARACTER-level shelter path in the very same code, and it is
-- the one we use -- the tent branch:
--
--   BodyDamage.UpdateWetness (:749) : outside AND (asleep|sitting|RESTING)
--                                     AND getBed() != null AND getBed().isTent()
--                                     => treat as NOT outside
--   Clothing.getWetDryState  (:573) : the same test, plus it accepts a bed NAMED
--                                     "Shelter" outright -> worn clothes DRY
--   SleepingEvent.isExposedToPrecipitation (:363) : same test -> a sleeping driver
--                                     is not rained on either
--
-- We already set setIsResting(true) on boarding (RR_Ride, for the seated stamina
-- bonus), so the only missing input is the bed. IsoObject.isTent() (:5882) is
-- satisfied by an object whose NAME contains "Shelter", and the Lua-exposed
-- constructor IsoObject.new(square, tile) only fills fields -- it does NOT add the
-- object to the square. So one cached, world-less marker object named exactly
-- "Shelter" (the string Clothing compares against) turns the vanilla shelter path
-- on for whoever is in the cab, with ZERO world mutation and no custom wetness code.
-- Drying comes free with it: UpdateWetness's dry rate is read from the air
-- temperature, which channel 2 below is already raising.
--
-- OWNERSHIP (owner decision A, 2026-07-28): this file is the SINGLE owner of
-- IsoPlayer.setBed while the driver is in the cab. RR_Sleep must not clear it --
-- a night asleep is exactly when being rained on matters most.
--
-- ==== 2. WIND + HEAT -- an IsoHeatSource on the cab tile ====
--
-- The temperature path ignores roofs entirely: ClimateManager.getAirTemperatureForSquare
-- keys off isInARoom() only, and we cannot fake a Room. What it DOES honour is
-- IsoCell.getHeatSourceHighestTemperature, so the cab gets a real heat source of its
-- own -- the same channel a campfire uses -- pinned to the cab tile. That one object
-- buys everything downstream for free: thermoregulation, the cold moodle, the
-- clothes-drying rate, and the wind chill (the engine takes the MAX of air and heat
-- source, so pinning the source to raw un-windchilled air cancels the chill exactly).
--
-- Two engine facts this is built around:
--   * IsoHeatSource's x/y/z are FINAL. Moving one means remove + build a new one, so
--     the source is rebuilt only when the cab crosses a tile boundary; temperature is
--     settable in place and costs nothing.
--   * IsoCell.updateHeatSources() silently drops any source whose tile leaves the
--     loaded chunk map, leaving our handle live but unregistered. isInBounds() is
--     public, so we ask it every reconcile and rebuild rather than trust the handle.
--***********************************************************************

print("[Railroader] RR_CabClimate.lua: loading...")
require("Railroader/RR_Cab")
require("Railroader/RR_Body")

local Cab = RR and RR.Cab

local CabClimate = {}
CabClimate.enabled      = true
CabClimate.MIN_INTERVAL = 0.5    -- s between heat-source reconciles (heat is not a per-frame quantity)

-- The sprite the marker object carries. It is never drawn (the object is never added
-- to a square) -- it only has to EXIST, because Clothing.getWetDryState calls
-- isTent() without a null-check on the sprite. A tile the mod already references.
local SHELTER_SPRITE = "industry_railroad_05_52"
local SHELTER_NAME   = "Shelter"   -- exact string: Clothing compares equalsIgnoreCase

--------------------------------------------------------------------------
-- ambient(): raw outside air temperature in degC (NO wind chill -- that is the point;
-- see the header). Missing weather data => a mild default rather than nil.
--------------------------------------------------------------------------
local function ambient()
    local t
    pcall(function()
        local cm = getClimateManager()
        if cm then t = cm:getTemperature() end
    end)
    return t or 10
end

--------------------------------------------------------------------------
-- marker(): the cached shelter object. Built once per session, on first use.
-- Returns nil (and says so once) if the engine refused to build it -- the mod then
-- simply has no rain shelter, rather than handing vanilla a bed with a null sprite,
-- which would NPE inside Clothing's tent test.
--------------------------------------------------------------------------
local markerObj, markerTried
local function marker()
    if markerObj or markerTried then return markerObj end
    markerTried = true
    local p = getPlayer()
    local sq
    pcall(function() sq = p and p:getSquare() end)
    local o
    pcall(function()
        o = IsoObject.new(sq, SHELTER_SPRITE)   -- fields only: NOT added to the square
        o:setName(SHELTER_NAME)
    end)
    local sprite
    if o then pcall(function() sprite = o:getSprite() end) end
    if not (o and sprite) then
        print("[Railroader] cab shelter: could not build the marker object -- "
              .. "rain protection in the cab is OFF this session.")
        return nil
    end
    markerObj = o
    return markerObj
end

--------------------------------------------------------------------------
-- assertShelter(p) / clearShelter(p): the cab's roof, on and off. Called on
-- boarding, re-asserted every tick from RR_Ride.pinRider (setBed is a bare field
-- write -- cheaper than checking), and cleared on step-off.
--------------------------------------------------------------------------
function CabClimate.assertShelter(p)
    if not CabClimate.enabled then return false end
    p = p or getPlayer()
    local o = marker()
    if not (p and o) then return false end
    pcall(function() p:setBed(o) end)
    return true
end

function CabClimate.clearShelter(p)
    p = p or getPlayer()
    if not p then return end
    pcall(function() p:setBed(nil) end)
end

--------------------------------------------------------------------------
-- cabTile(rec): the world tile the DRIVER's seat is on -- not the body centre. The
-- loco is 15 tiles long; a heat source at its middle would warm the fuel tank and
-- miss the cab. Same body-local seat offset RR_Ride seats the driver with, so the
-- source lands on exactly the square the rider is pinned to.
--------------------------------------------------------------------------
local function cabTile(rec)
    local pose = rec and rec.lastPose
    if not pose then return nil end
    local size = 0.7
    if rec.animal then pcall(function() size = rec.animal:getAnimalSize() end) end
    local u, w, lift = 0, 0, 0
    if RR.Body and RR.Body.seatOffset then u, w, lift = RR.Body.seatOffset(size) end
    local fx, fy = pose.dirX or 0, pose.dirY or 0
    local rx, ry = -fy, fx                                   -- right of travel
    -- Z is FLOORED, not rounded: the engine matches a heat source to a character by
    -- `heatSource.getZ() == square.getZ()`, and a square's level is the truncation of the
    -- character's z. Rounding here would put the source on level 1 for any pose sitting
    -- above z=0.5 and the match would silently never happen.
    return math.floor(pose.x + u * fx + w * rx),
           math.floor(pose.y + u * fy + w * ry),
           math.floor((pose.z or 0) + (lift or 0))
end

--------------------------------------------------------------------------
-- dropSource(rec): unregister the loco's heat source, if it has one.
--------------------------------------------------------------------------
local function dropSource(rec)
    local h = rec and rec.cabHeat
    if not (h and h.src) then if rec then rec.cabHeat = nil end return end
    pcall(function()
        local cell = getCell()
        if cell then cell:removeHeatSource(h.src) end
    end)
    rec.cabHeat = nil
end

--------------------------------------------------------------------------
-- reconcile(rec, ambientC): make the world's heat source match the model.
--------------------------------------------------------------------------
local function reconcile(rec, ambientC)
    if not Cab.wants(rec.cab, ambientC, rec.rider == true) then
        dropSource(rec)
        return
    end
    local tx, ty, tz = cabTile(rec)
    if not tx then return end

    local cabC = Cab.cabTempC(rec.cab and rec.cab.waterC, ambientC)
    local temp = Cab.heatSourceTemp(cabC, ambientC)

    local h = rec.cabHeat
    -- The engine culls sources whose tile has left the loaded chunk map, without
    -- telling us. A handle that is no longer in bounds is already gone (or about to
    -- be): forget it and let the rebuild below decide whether to make a new one.
    if h and h.src then
        local ok, inb = pcall(function() return h.src:isInBounds() end)
        if not ok or inb == false then rec.cabHeat = nil; h = nil end
    end

    if h and h.tx == tx and h.ty == ty and h.tz == tz then
        if h.temp ~= temp then
            pcall(function() h.src:setTemperature(temp) end)   -- settable in place, unlike x/y/z
            h.temp = temp
        end
        return
    end

    dropSource(rec)
    local src
    local ok, err = pcall(function()
        src = IsoHeatSource.new(tx, ty, tz, Cab.C.SRC_RADIUS, temp)
        getCell():addHeatSource(src)
    end)
    if ok and src then
        rec.cabHeat = { src = src, tx = tx, ty = ty, tz = tz, temp = temp }
        -- Say it ONCE per loco, the first time a source is really on the world. A silent
        -- pcall here is what made the first field failure undiagnosable: there was no way
        -- to tell "the heater is still warming" from "the API call never worked".
        if not rec.cabHeatLogged then
            rec.cabHeatLogged = true
            print(string.format("[Railroader] cab heat source placed at (%d,%d,%d) r=%d temp=%d "
                  .. "(cab %.1f C, air %.1f C).", tx, ty, tz, Cab.C.SRC_RADIUS, temp, cabC, ambientC))
        end
    else
        -- NEVER silent: a failure here means no warmth and no wind block, and the driver
        -- has no way to see it from inside the cab.
        if not rec.cabHeatFailed then
            rec.cabHeatFailed = true
            print("[Railroader] cab heat source FAILED to register: " .. tostring(err)
                  .. " -- the cab gives no warmth and does not block the wind this session.")
        end
    end
end

--------------------------------------------------------------------------
-- onSpawn(rec, waterC): give the record its climate state. waterC comes from
-- modData on a re-adoption (a loco parked warm an hour ago is still warm); a fresh
-- spawn starts at air temperature, which is where a machine that has stood in the
-- weather since the apocalypse actually is.
--------------------------------------------------------------------------
function CabClimate.onSpawn(rec, waterC)
    if not (CabClimate.enabled and rec) then return end
    rec.cab = Cab.newState(ambient())
    if waterC then rec.cab.waterC = waterC end
    rec.cabHeat = nil
    rec.cabAcc  = 0
end

--------------------------------------------------------------------------
-- update(rec, dtGame): called every tick from RR_TrainEntity (driving AND derailed
-- -- a wreck is still a cab with a seat and a roof in it).
--
-- The water temperature runs on GAME time, like fuel and the battery: an idling loco
-- left under x40 warms up 40x faster, and so does the block cooling overnight. The
-- heat source is reconciled at MIN_INTERVAL, because it has no visual and the cab
-- crosses a tile several times a second at track speed.
--------------------------------------------------------------------------
function CabClimate.update(rec, dtGame)
    if not (CabClimate.enabled and rec) then return end
    if not rec.cab then CabClimate.onSpawn(rec) end

    local amb = ambient()
    local before = Cab.heatFrac(rec.cab.waterC)
    Cab.tick(rec.cab, dtGame or 0, {
        running  = (rec.engine and rec.engine.running) == true,
        ambientC = amb,
    })
    rec.cab.ambientC = amb        -- cached so the seated HUD line can show the cab temperature

    -- The heater crossing its threshold is the one moment the driver most wants to know
    -- about, in both directions: it is the difference between "wait, it is coming" and
    -- "get out and find a house".
    local after = Cab.heatFrac(rec.cab.waterC)
    if before <= 0 and after > 0 then
        print(string.format("[Railroader] cab heater: water past %d C -- the cab is starting to warm.",
              Cab.C.HEAT_MIN_C))
    elseif before > 0 and after <= 0 then
        print("[Railroader] cab heater: the water has gone cold -- no more heat in the cab.")
    end

    rec.cabAcc = (rec.cabAcc or 0) + (dtGame or 0)
    if rec.cabAcc < CabClimate.MIN_INTERVAL then return end
    rec.cabAcc = 0
    reconcile(rec, amb)
end

--------------------------------------------------------------------------
-- onRemove(rec): the loco is gone. The heat source must go with it, or a patch of
-- empty track stays warm for the rest of the session.
--------------------------------------------------------------------------
function CabClimate.onRemove(rec)
    dropSource(rec)
    if rec then rec.cab = nil end
end

--------------------------------------------------------------------------
-- Console helper: what does the cab read right now? (Not gated -- a console call
-- can't be hit by accident, and it is how a tester reports "the cab is freezing".)
--
-- It prints BOTH sides on purpose: what our model INTENDS (water / cab temperature /
-- the heat-source integer we built) and what the ENGINE actually gives the character
-- back (Thermoregulator.getTemperatureAirAndWind -- the number that already has the
-- wind chill and every heat source folded in). Those two agreeing is the whole test:
-- eyeballing the cold moodle cannot tell a working heat source from a lucky day.
--   * "felt" == cab  while seated  -> the source and the wind-chill cancel both work
--   * "felt" <  air  while stood outside in wind -> that is the chill we are cancelling
--   * bed=Shelter -> the rain path is armed; wet should fall, not climb, in a downpour
--------------------------------------------------------------------------
function CabClimate.report()
    local list = (RR.TrainEntity and RR.TrainEntity.active) or {}
    local amb = ambient()
    print(string.format("[Railroader] outside air %.1f C", amb))

    -- The character's own side of it, straight from the engine.
    local p = getPlayer()
    if p then
        local felt, core, bed, wet
        pcall(function()
            local tr = p:getBodyDamage():getThermoregulator()
            felt = tr:getTemperatureAirAndWind()
            core = tr:getCoreTemperature()
        end)
        pcall(function()
            local b = p:getBed()
            bed = b and b:getName() or "none"
        end)
        pcall(function()
            local bps, sum, n = p:getBodyDamage():getBodyParts(), 0, 0
            for i = 0, bps:size() - 1 do sum = sum + bps:get(i):getWetness(); n = n + 1 end
            if n > 0 then wet = sum / n end
        end)
        print(string.format("  player: felt %.1f C  core %.2f C  wetness %.1f%%  bed=%s  resting=%s",
              felt or -999, core or -999, wet or -1, tostring(bed),
              tostring(p:isResting() == true)))
    end

    for i, e in ipairs(list) do
        local w = e.cab and e.cab.waterC
        print(string.format("  loco %d: water %.1f C (%s)  cab %.1f C  source=%s  rider=%s",
              i, w or -1, Cab.waterLabel(w), Cab.cabTempC(w, amb),
              e.cabHeat and tostring(e.cabHeat.temp) or "none",
              tostring(e.rider == true)))
    end
end

RR = RR or {}
RR.CabClimate = CabClimate
print("[Railroader] RR_CabClimate.lua: loaded OK.")

return CabClimate
