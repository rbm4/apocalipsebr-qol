if isClient() then return end

require("Railroader/RR_Spline")
require("Railroader/RR_Body")
require("Railroader/RR_Routes")
require("Railroader/RR_RealRoutes")
require("Railroader/RR_TrackGraph")
require("Railroader/RR_Drive")
require("Railroader/RR_Engine")
require("Railroader/RR_Spawn")
require("Railroader/RR_Profession")
require("Railroader/RR_Lights")
require("Railroader/RR_DieselFluid")
require("Railroader/RR_Refuel")
require("Railroader/RR_ServerCollision")

local Spline, Body, Drive, Engine = RR.Spline, RR.Body, RR.Drive, RR.Engine
local Diesel, Refuel = RR.DieselFluidMath, RR.Refuel
local Collision = RR.ServerCollision
local ServerTrain = { active = {}, byId = {}, readyPlayers = {}, ticks = 0,
                      history = {}, historyN = 0, _clientState = {} }

-- v1.0.18: debug logging OFF by default (RR.dbgLog = true in the server console
-- re-arms the [RailroaderMP-dbg] prints). Explicit console calls like
-- RR.ServerTrain.debugDump() always print.
RR.dbgLog = RR.dbgLog or false
local function dbg(fmt, ...)
    if RR.dbgLog then print(string.format("[RailroaderMP-dbg] " .. fmt, ...)) end
end

-- 60Hz state broadcast: each snapshot is stamped with the server tick it was
-- produced on, so the client can play the interpolated trajectory at its own
-- frame rate. Persistence (modData) stays at a slower cadence -- a crash loses
-- at most SAVE_TICKS of motion, and transmitModData is not on the hot path.
-- Doc alignment (train_net_sync_design.md):
--   §5.1 fixed-step sim: STEP_SEC accumulator driven by the wall clock, with a
--        game-time variable-step fallback when getTimestampMs() is unavailable.
--   §4.2 broadcast delta-encoded, with per-player distance bands (doc §7 LOD):
--        <=30 格 20Hz / 30-70 格 10Hz / 70-100 格 4Hz / >100 格 no packets --
--        reduced rate is still delta, so the client's interpolation keeps playing.
--   §7.2.2 alpha pin only while someone is aboard or within ALPHA_RANGE.
--   §11 command rate limit per player.
-- All timings are in SIM TICKS at 60Hz (STEP_SEC = 1/60s). The client treats
-- `tick` as the interpolation axis, so every rate below is expressed as "send
-- on every Nth tick" rather than wall-clock milliseconds -- the same schedule
-- holds whether the server runs 30 or 60 sim steps per second.
local SNAPSHOT_EVERY  = 3
local SAVE_TICKS      = 30
local HISTORY_MAX     = 32      -- authoritative snapshots retained for client re-sync (~0.5s)
local CONTROL_RANGE   = 12
local SERVICE_RANGE   = 2
local MAX_PASSENGERS  = 5
local STOPPED_SPEED   = 0.05
local STEP_SEC        = 1 / 60
local MAX_FRAME       = 0.25    -- s: largest accepted real frame (anti-spiral: a
                                -- 1s hitch after a stall must not queue 60 sim steps)
local NEAR_RANGE      = 30      -- tiles: full 20Hz stream (近距离)
local MID_RANGE       = 70      -- tiles: 10Hz stream, still interpolated (中距离)
local FAR_RANGE       = 100     -- tiles: 4Hz stream, still interpolated (远距离); beyond -> no packets
local MID_EVERY       = 6       -- sim ticks between MID-rate packets (10Hz)
local FAR_EVERY       = 15      -- sim ticks between FAR-rate packets (4Hz)
local FULL_GAP        = 90      -- ticks without a packet -> next one is full+resync
local ALPHA_RANGE     = 70      -- tiles: pin render alpha while a player is this close (mid band)
local RATE_LIMIT      = 40      -- control/switch/service commands per player per second
                                 -- (v1.0.2: the client now dedupes repeated control
                                 -- state, so 40 is a comfortable flood guard instead
                                 -- of a ceiling legit key-mashing trips over)

-- Why the bands matter (doc §7 LOD): PZ sends each packet to each player
-- separately, so broadcast cost is O(players x trains). A player 200 tiles away
-- cannot see the train, yet would still pay full 20Hz bandwidth for nothing --
-- so the rate (and even the existence) of a stream is per-player-per-train.
-- The client's interpolation is resilient to the sparse bands: it holds the
-- last snapshot, plays it out over the segment, and LAG_CAP bounds the delay.

local lastWallMs = 0            -- getTimestampMs() of the last frame (broadcast stamp)

-- next() is NOT available in Project Zomboid's Kahlua, so a bare
-- `next(t) ~= nil` call crashes. Non-empty check via pairs() instead.
local function tableNonEmpty(t)
    if not t then return false end
    for _ in pairs(t) do return true end
    return false
end

local function gameAgeHours()
    local hours = 0
    pcall(function() hours = getGameTime():getWorldAgeHours() end)
    return hours or 0
end

local function state(e)
    local a = e.animal
    return {
        id = e.id, tick = ServerTrain.ticks,
        simTime = ServerTrain.ticks * STEP_SEC,
        serverWallMs = lastWallMs or 0,
        gameAgeH = gameAgeHours(),
        routeId = e.routeId, distance = e.distance, v = e.drive.v,
        reverser = e.reverser, throttle = e.throttle, brakeInput = e.brakeInput,
        notchEff = e.drive.notchEff, brakeLevel = e.drive.brakeLevel,
        driver = e.driver, x = a:getX(), y = a:getY(), z = a:getZ(),
        passengers = e.passengers or {},
        dirX = e.dirX, dirY = e.dirY, engineOn = e.engine.running and true or false,
        enginePhase = e.engine.phase, warmupTime = e.engine.warmupTime,
        head = e.lightState.head, cab = e.lightState.cab and true or false,
        fuel = e.engine.fuel, battery = e.engine.battery, condition = e.engine.condition,
        derailed = e.derailed and true or false,
        faceSign = e.faceSign,
        lastCmdSeq = e._lastCmdSeq or 0,
        resync = e._resyncFlag and true or false,
    }
end

local function worldData()
    return ModData.getOrCreate("RR_World")
end

--------------------------------------------------------------------------
-- World-spawn flag: EITHER marker means "this save already got its one loco".
-- rrTrainSpawned is set by the server's add(); rrLocoSpawned is the original
-- SP depot flag (RR_Depot). Old SP saves converted to MP only carry
-- rrLocoSpawned -- treating it as the same fact stops the ready handler from
-- spawning a duplicate depot loco while the saved loco's chunk is still
-- unstreamed. markSpawned() writes BOTH so every side agrees (v1.0.7).
--------------------------------------------------------------------------
local function worldSpawned()
    local wd = worldData()
    return (wd.rrTrainSpawned and true) or (wd.rrLocoSpawned and true)
end

local function markSpawned()
    local wd = worldData()
    wd.rrTrainSpawned = true
    wd.rrLocoSpawned = true
end

local function station(id)
    return Refuel and Refuel.station(id) or nil
end

local function stationPoint(st)
    if st and st.at then return st.at.x, st.at.y, st.at.z or 0 end
    local depot = RR.Spawn and RR.Spawn.DEPOT
    if depot and depot.routeId and RR.Routes.exists(depot.routeId) then
        local p = Spline.sample(RR.Routes.get(depot.routeId), depot.distance)
        return p.x + 3, p.y, p.z or 0
    end
end

local function reserve(st)
    local wd = worldData()
    if wd[st.mdReserve] == nil then wd[st.mdReserve] = Refuel.rollReserve(0.5, Engine.C.FUEL_CAP) end
    return math.max(0, tonumber(wd[st.mdReserve]) or 0)
end

local function setReserve(st, value)
    worldData()[st.mdReserve] = math.max(0, value or 0)
end

local function placeStation(st)
    local wd = worldData()
    if wd[st.mdStand] then return end
    local x, y, z = stationPoint(st)
    if not x then return end
    local layout = {
        { 0, 0, { "industry_02_33", "industry_02_68" } }, { 1, 0, { "industry_02_26", "industry_02_69" } },
        { 2, 0, { "industry_02_70" } }, { 3, 0, { "industry_02_71" } },
        { 0, 1, { "industry_02_64" } }, { 1, 1, { "industry_02_65" } },
        { 2, 1, { "industry_02_66" } }, { 3, 1, { "industry_02_67" } },
    }
    for _, tile in ipairs(layout) do
        if not getCell():getGridSquare(math.floor(x) + tile[1], math.floor(y) + tile[2], math.floor(z)) then return end
    end
    for _, tile in ipairs(layout) do
        local target = getCell():getGridSquare(math.floor(x) + tile[1], math.floor(y) + tile[2], math.floor(z))
        if not target then return end
        for _, sprite in ipairs(tile[3]) do
            local obj = IsoObject.new(target, sprite, sprite)
            obj:getModData().rrFuelStand = true
            target:AddTileObject(obj)
            obj:transmitCompleteItemToClients()
        end
    end
    wd[st.mdStand] = { x = math.floor(x), y = math.floor(y), z = math.floor(z) }
end

local function ensureStations()
    for _, st in ipairs((Refuel and Refuel.STATIONS) or {}) do
        reserve(st)
        placeStation(st)
    end
end

local function placeSwitchSprite(x, y, z, sprite)
    local square = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z or 0))
    if not square then return end
    local objects = square:getObjects()
    for index = 0, objects:size() - 1 do
        local existing = objects:get(index)
        local existingSprite = existing and existing:getSprite()
        if existingSprite and existingSprite:getName() == sprite then return end
    end
    local object = IsoObject.new(square, sprite, sprite)
    square:AddTileObject(object)
    object:transmitCompleteItemToClients()
end

local function ensureSwitches()
    for _, def in pairs((RR.TrackGraph and RR.TrackGraph.defs) or {}) do
        for _, sw in ipairs(def.switches or {}) do
            local place = sw.place
            if place then
                if place.sprite then placeSwitchSprite(place.x, place.y, place.z, place.sprite) end
                for _, sprite in ipairs(place.sprites or {}) do
                    placeSwitchSprite(place.x + (sprite.dx or 0), place.y + (sprite.dy or 0), place.z, sprite.sprite)
                end
            end
        end
    end
end

local function stationsState()
    local out = {}
    for _, st in ipairs((Refuel and Refuel.STATIONS) or {}) do out[st.id] = reserve(st) end
    return out
end

-- v1.0.4: authoritative switch states ride the full snapshot (join / periodic
-- "ready"), so a client that joined after a throw never predicts the default
-- branch at a thrown switch. Same shape as RR_World.rrSwitches:
-- { [baseId] = { [switchId] = "normal"|"reverse" } }.
local function switchesState()
    local out = {}
    for baseId, def in pairs((RR.TrackGraph and RR.TrackGraph.defs) or {}) do
        local states = def and def.states
        if states then
            local t = {}
            for switchId, st in pairs(states) do t[switchId] = st end
            out[baseId] = t
        end
    end
    return out
end

local function pushHistory(full)
    ServerTrain.historyN = ServerTrain.historyN + 1
    ServerTrain.history[(ServerTrain.historyN - 1) % HISTORY_MAX + 1] = full
end

--------------------------------------------------------------------------
-- Wire encoding (doc §4.2): the hot broadcast is delta-encoded --
--   * distance: int16 delta in millimetres (s.d); full float (s.dist) when the
--     delta overflows or on resync;
--   * controls: one byte (s.c) = notch(4b) + reverser(2b) + brake(1b);
--   * engine/lights fields travel ONLY when they changed since the last packet;
--   * position/heading always travel (the client re-anchors its route from them).
-- Lua 5.1 (Kahlua): no bitwise operators, so the byte is packed arithmetically.
--
-- The delta baseline is PER-PLAYER, not per-train-global: ctx.last points at
-- this player's private tracker for this train (ServerTrain._clientState[pid]
-- [e.id]). That is what makes the sparse MID/FAR bands correct -- a 4Hz FAR
-- client's delta is measured against the last value IT received, so a packet
-- every 15 ticks still decodes to the exact absolute position. A client that
-- just entered the band has no tracker entry: it gets a FULL packet (see
-- broadcastStates), which also seeds the tracker so the next packet is a delta.
--
-- Wire short names (decoded by RR_MPClient.decodeWire):
--   id/tick/simTime/wall/game/rid  -- identity + timing axes
--   drv/pax                        -- driver online id / passenger seat map
--   v/ne/bl                         -- velocity, notchEff, brakeLevel
--   x/y/z/dx/dy                     -- world pose + heading (always present)
--   dr/rk/lc/fs                     -- derailed / resync / lastCmdSeq / faceSign
--   dist | d/c                      -- full distance, or delta-mm + controls byte
--   t/r/b/eo/ep/wt/ef/eb/ec/hd/cb   -- full-only expanded fields
--------------------------------------------------------------------------
local function controlsByte(e)
    -- One byte packs the three control states a 4Hz client needs to keep its
    -- physics mirror correct between full snapshots: notch 0..8 (4 bits),
    -- reverser -1..1 shifted +1 (2 bits), brake on/off (1 bit). Arithmetic
    -- packing: t + r*16 + b*64. The client re-expands via % and floor(/).
    local t = math.max(0, math.min(8, math.floor((e.throttle or 0) + 0.5)))
    local r = math.max(0, math.min(2, (e.reverser or 0) + 1))
    local b = (e.brakeInput or 0) > 0 and 1 or 0
    return t + r * 16 + b * 64
end

local function wireState(e, ctx)
    ctx = ctx or {}
    local last = ctx.last
    -- Always-present frame: identity, time axes, pose and heading. The pose is
    -- sent every packet (even though it is derivable from distance) so the
    -- client can re-anchor its spline route on world truth after a switch
    -- throw or a chunk reload -- distance alone is ambiguous across routes.
    local s = {
        id = e.id, tick = ServerTrain.ticks,
        simTime = ServerTrain.ticks * STEP_SEC,
        wall = lastWallMs, game = gameAgeHours(),
        rid = e.routeId, rk = (ctx.full and true or false) or (e._resyncFlag and true or false),
        drv = e.driver, pax = e.passengers or {},
        v = e.drive.v, ne = e.drive.notchEff, bl = e.drive.brakeLevel,
        x = e.animal:getX(), y = e.animal:getY(), z = e.animal:getZ(),
        dx = e.dirX, dy = e.dirY, dr = e.derailed and true or false,
        lc = e._lastCmdSeq or 0,
    }
    local dist = e.distance or 0
    if ctx.full then
        -- FULL snapshot (first sight, re-entry after FULL_GAP, ready/reboard):
        -- absolute distance + every engine/light field, tagged resync so the
        -- client discards its interpolation buffer and re-bases on truth.
        s.dist = dist
        s.t, s.r, s.b = e.throttle, e.reverser, e.brakeInput
        s.eo, s.ep, s.wt = e.engine.running and true or false, e.engine.phase, e.engine.warmupTime
        s.ef, s.eb, s.ec = e.engine.fuel, e.engine.battery, e.engine.condition
        s.hd, s.cb = e.lightState.head, e.lightState.cab and true or false
        s.fs = e.faceSign
    else
        -- Delta is relative to what THIS player last received (per-player
        -- tracker), so a MID/FAR-rate client still decodes exact positions.
        -- No baseline -> absolute distance (client drops it until then anyway).
        local base = last and last.dist
        local deltaMm = base and math.floor((dist - base) * 1000 + 0.5) or nil
        -- int16 range (+-32.767m) is far larger than any per-tick motion; a
        -- teleport / derail / re-anchor falls outside it and degrades to a
        -- full distance + resync, which is exactly the recovery we want.
        if deltaMm and deltaMm >= -32767 and deltaMm <= 32767 then s.d = deltaMm
        else s.dist = dist end
        s.c = controlsByte(e)
        -- Engine/lights fields are change-only in the delta stream: the client
        -- keeps its last value when the key is absent, so a 4Hz FAR client
        -- still tracks fuel/headlight/faceSign without paying for them every
        -- packet. `last` caches the previously-sent values for this player.
        if not last or (e.engine.running and true or false) ~= last.eo then s.eo = e.engine.running and true or false end
        if not last or e.engine.phase ~= last.ep then s.ep = e.engine.phase end
        if not last or e.engine.fuel ~= last.ef then s.ef = e.engine.fuel end
        if not last or e.engine.battery ~= last.eb then s.eb = e.engine.battery end
        if not last or e.engine.condition ~= last.ec then s.ec = e.engine.condition end
        if not last or e.engine.warmupTime ~= last.wt then s.wt = e.engine.warmupTime end
        if not last or e.lightState.head ~= last.hd then s.hd = e.lightState.head end
        if not last or (e.lightState.cab and true or false) ~= last.cb then s.cb = e.lightState.cab and true or false end
        if not last or e.faceSign ~= last.fs then s.fs = e.faceSign end
    end
    if last then
        -- Roll the tracker forward to what was just sent, so the next packet's
        -- delta and change-detection compare against THIS packet.
        last.tick = ServerTrain.ticks
        last.dist = dist
        last.eo = e.engine.running and true or false
        last.ep = e.engine.phase
        last.wt = e.engine.warmupTime
        last.ef = e.engine.fuel
        last.eb = e.engine.battery
        last.ec = e.engine.condition
        last.hd = e.lightState.head
        last.cb = e.lightState.cab and true or false
        last.fs = e.faceSign
    end
    return s
end

--------------------------------------------------------------------------
-- sendState(player): FULL, resync-tagged snapshot for one player (ready/reboard).
-- Unlike the banded broadcast, this pushes EVERY train unconditionally -- it is
-- the "welcome packet" a joining client needs to render anything at all, and it
-- doubles as the authoritative switch/station download (late joiners can never
-- keep predicting the default branch at a thrown switch, v1.0.4).
--------------------------------------------------------------------------
local function sendState(player)
    local states = {}
    local pid = player and player:getOnlineID()
    for _, e in ipairs(ServerTrain.active) do
        -- v1.0.5: a chunk-unloaded loco has nothing authoritative to send (its
        -- animal is not in the world); it re-enters the stream on re-bind.
        if e._unloaded then
            -- keep the per-player baseline untouched so the re-bind packet
            -- arrives as full+resync
        else
            -- Seed this player's per-train baseline so the next banded packet
            -- can be a delta instead of repeating a full snapshot.
            local last
            if pid then
                local pt = ServerTrain._clientState[pid]
                if not pt then pt = {}; ServerTrain._clientState[pid] = pt end
                last = pt[e.id] or {}
                pt[e.id] = last
            end
            states[#states + 1] = wireState(e, { full = true, last = last })
            pushHistory(state(e))
        end
    end
    local args = { entities = states, reserves = stationsState(), switches = switchesState() }
    if player then sendServerCommand(player, "RailroaderMP", "state", args)
    else sendServerCommand("RailroaderMP", "state", args) end
end

--------------------------------------------------------------------------
-- Per-player distance-band broadcast (doc §7 LOD):
--   <= NEAR_RANGE : 20Hz delta stream (SNAPSHOT_EVERY)
--   <= MID_RANGE  : 10Hz delta stream (MID_EVERY)   -- still interpolated
--   <= FAR_RANGE  :  4Hz delta stream (FAR_EVERY)   -- still interpolated
--   beyond FAR    : no packets (client may skip rendering)
-- v1.0.5 (MP render lag): MID was 5Hz and FAR was 1Hz -- the client plays one
-- snapshot segment behind by design, so those bands rendered a full packet
-- interval behind the train's actual position (0.2s / up to 1s of visible lag).
-- Raised to 10Hz / 4Hz; the client's LAG_CAP bounds the playout delay on top.
-- First sight, or re-entry after a gap > FULL_GAP ticks, sends a FULL packet
-- so the client re-bases its interpolation buffer on truth.
--------------------------------------------------------------------------
local function broadcastStates()
    if ServerTrain.ticks % SNAPSHOT_EVERY ~= 0 then return end
    -- One pass over players x active trains per 20Hz slot: compute the distance
    -- band for this player, and only when this tick is a multiple of the band's
    -- cadence build the packet. Trains beyond FAR_RANGE produce no packet at
    -- all (zero bandwidth), and re-enter with a full+resync (gap > FULL_GAP).
    local players = getOnlinePlayers()
    if players then
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            local pid = p and p:getOnlineID()
            if pid then
                local states = {}
                for _, e in ipairs(ServerTrain.active) do
                    if not e._unloaded then
                        local dx, dy = p:getX() - e.animal:getX(), p:getY() - e.animal:getY()
                        local d2 = dx * dx + dy * dy
                        local rate = 0
                        if d2 <= NEAR_RANGE * NEAR_RANGE then rate = SNAPSHOT_EVERY
                        elseif d2 <= MID_RANGE * MID_RANGE then rate = MID_EVERY
                        elseif d2 <= FAR_RANGE * FAR_RANGE then rate = FAR_EVERY end
                        if rate > 0 and ServerTrain.ticks % rate == 0 then
                            local pt = ServerTrain._clientState[pid]
                            if not pt then pt = {}; ServerTrain._clientState[pid] = pt end
                            local last = pt[e.id]
                            local gap = ServerTrain.ticks - (last and last.tick or -1e9)
                            -- FULL when we have no baseline for this player, or
                            -- when the gap is old enough that the delta chain
                            -- could be broken (player walked out of range and
                            -- back in). FULL seeds the baseline and resyncs.
                            local full = (not last) or gap > FULL_GAP
                            if not last then last = {}; pt[e.id] = last end
                            states[#states + 1] = wireState(e, { full = full, last = last })
                        end
                    end
                end
                if #states > 0 then
                    sendServerCommand(p, "RailroaderMP", "state",
                        { entities = states, reserves = stationsState() })
                end
            end
        end
    end
    -- Keep the authoritative snapshot ring warm for gap re-sync requests:
    -- history[] is a ring of the last HISTORY_MAX full states; a starved client
    -- requests "resync" and receives every retained tick newer than its own.
    for _, e in ipairs(ServerTrain.active) do
        if not e._unloaded then pushHistory(state(e)) end
    end
end

local function pose(e)
    local size = 0.7
    pcall(function() size = e.animal:getAnimalSize() end)
    return Spline.bodyPose(e.route, e.distance, Body.halfWheelbase(size))
end

local function applyPose(e)
    local p = pose(e)
    e.animal:setX(p.x); e.animal:setY(p.y); e.animal:setZ(p.z)
    -- Facing (v1.0.2 fix): setTargetAndCurrentDirection is the Railroader-verified
    -- rotation mechanism (reference RR_TrainEntity.applyPose: setForwardDirection
    -- only sets the VECTOR; the visible 3D model yaw comes from the AnimationPlayer
    -- angle, which is gated for our AI-suppressed animal -- so without this call
    -- the model never turns with the rails). It sets the vector AND snaps the
    -- AnimationPlayer angle to the route chord heading. v1.0.3e: the raw heading
    -- is fed through Body.smoothFacing (exponential smoothing + deadband) so a
    -- crawl through a corner does not re-snap/re-trigger the angle every tick
    -- (visible stutter); the SIM pose stays exact -- e.dirX/e.dirY and e.pose
    -- keep the raw spline heading for physics.
    local sx, sy, changed = Body.smoothFacing(e, p.dirX, p.dirY, 1 / 60)
    if changed then e.animal:setTargetAndCurrentDirection(sx, sy) end
    e.dirX, e.dirY = p.dirX, p.dirY
end

local function reanchor(e)
    -- Rebuild the train's THROUGH-ROUTE from the track graph after a switch
    -- (points) throw. `e.route` is the concrete polyline the loco rides; the
    -- graph's through-route encodes WHICH branch was taken at every switch up
    -- to the end. The loco's world position + heading locate it on a unique
    -- graph edge; buildThrough() re-derives the full route FROM that edge, so
    -- distance keeps its meaning after the topology changed. Runs on every
    -- switch throw (command handler) so the server always drives the correct
    -- branch and the client mirrors it via the same shared TrackGraph code.
    if not (e.baseId and RR.TrackGraph and RR.TrackGraph.has(e.baseId)) then return end
    local p = pose(e)
    local loc = RR.TrackGraph.graphLocate(RR.TrackGraph.netEdges(e.baseId), p.x, p.y)
    if not loc then return end
    local dot = (p.dirX or 1) * loc.tx + (p.dirY or 0) * loc.ty
    local route, distance = RR.TrackGraph.buildThrough(e.baseId, {
        edge = loc.edge, s = loc.s, dir = dot >= 0 and 1 or -1,
    })
    if route then e.route, e.distance = route, distance end
end

local function save(e)
    -- Persist the authoritative sim state into the animal's modData (IsoAnimal
    -- save/load round-trips modData, Railroader-verified). Called every
    -- SAVE_TICKS (0.5s), on derail, and on every state-mutating event, so a
    -- crash or restart loses at most half a second of motion. rrLoco marks the
    -- animal as ours so reacquire()/adopt() can find it after a restart; rrV
    -- (v1.0.4) keeps a mid-motion restart bleeding speed with the no-driver
    -- emergency brake instead of appearing parked at the save point.
    local md = e.animal:getModData()
    md.rrLoco = true; md.rrRouteId = e.routeId; md.rrDistance = e.distance
    md.rrV = e.drive.v
    md.rrReverser = e.reverser; md.rrEngineOn = e.engine.running and true or false
    md.rrFuel = e.engine.fuel; md.rrBattery = e.engine.battery; md.rrCond = e.engine.condition
    md.rrDirX = e.dirX; md.rrDirY = e.dirY
    md.rrHead = e.lightState.head; md.rrCabLight = e.lightState.cab and true or false
    md.rrDerailed = e.derailed and true or false
    md.rrFaceSign = e.faceSign
    pcall(function() e.animal:transmitModData() end)
end

--------------------------------------------------------------------------
-- rerail(e): the exact inverse of a derail -- lift the loco back onto its rails
-- at the point it left them and hand the controls back. This is an ADMIN/RECOVERY
-- tool (v1.0.8, user decision: admin-gated, NO -debug), not a gameplay mechanic:
-- derailment is terminal by design, and a real re-railing mechanic (crane, crew,
-- hours) is a later plan. The client menu is display-gated on isAdmin(); this is
-- the authority.
--
-- e.distance is untouched by the wreck, so the spline pose at e.distance is still
-- the point where the wheels came off -- no search. Everything the wreck froze is
-- put back at rest. What it deliberately does NOT do: repair `condition`, refuel,
-- or restart the diesel -- a loco re-railed after a heavy hit can come back OUT OF
-- ORDER and refuse to crank; that is the real state, and healing it here would hide
-- exactly the bug an admin is re-railing to look at.
--------------------------------------------------------------------------
local function rerail(e)
    if not (e and e.derailed and e.animal and e.route) then return false end
    e.derailed   = false
    e.throttle   = 0
    e.brakeInput = 0
    e.drive.v    = 0
    e.drive.brakeLevel = 0
    e._resyncFlag = true
    -- Pose onto the rails THIS tick: the wall chain, seat pins and the state
    -- stream all hang off the applied pose, so a frame left at the wreck spot
    -- with derailed already false would drag them across the gap.
    applyPose(e)
    -- Drop the old (possibly stale, pinned at the pre-derail spot) wall chain and
    -- rebuild it around the re-railed body -- same cleanup as a chunk re-bind.
    if Collision then
        if Collision.removeWall then Collision.removeWall(e) end
        if Collision.dropWalls then Collision.dropWalls(e) end
        if Collision.onSpawn then Collision.onSpawn(e) end
    end
    -- Clear any persisted wreck coords (belt-and-braces: the MP server never
    -- writes rrDerail*, but stale keys from an SP-era save must not linger).
    local md = e.animal:getModData()
    md.rrDerailX, md.rrDerailY, md.rrDerailZ = nil, nil, nil
    md.rrDerailDX, md.rrDerailDY = nil, nil
    save(e)
    -- Immediate full+resync welcome packet to EVERY client: the wreck pose drops
    -- at once instead of waiting for each player's next distance-band slot.
    sendState(nil)
    sendServerCommand("RailroaderMP", "rerailed", { id = e.id })
    print(string.format("[RailroaderMP] RE-RAILED %s at d=%.2f -- engine stays OFF, condition %.2f.",
        tostring(e.id), e.distance or 0, (e.engine and e.engine.condition) or -1))
    return true
end

--------------------------------------------------------------------------
-- rebind(e, animal): a chunk unload/reload streams the SAME saved loco back as
-- a fresh animal object with the same id. Re-point the existing record at the
-- fresh object, re-anchor on the WORLD position the chunk restored (the
-- in-memory distance may have drifted while unloaded), park the sim (no driver
-- survives a disconnect -- never resume a phantom speed into unloaded chunks),
-- and rebuild the collider wall chain around the new object.
--------------------------------------------------------------------------
local function rebind(e, animal)
    e.animal = animal
    e._unloaded = false
    pcall(function() animal:setGodMod(true) end)
    pcall(function() animal:setIsInvincible(true) end)
    local behavior = animal:getBehavior()
    if behavior then pcall(function() behavior:setBlockMovement(true) end) end
    local x, y = animal:getX(), animal:getY()
    local loc = RR.TrackGraph.graphLocate(RR.TrackGraph.netEdges(e.baseId), x, y)
    if loc then
        local dot = (e.dirX or 1) * loc.tx + (e.dirY or 0) * loc.ty
        local route, distance = RR.TrackGraph.buildThrough(e.baseId, {
            edge = loc.edge, s = loc.s, dir = dot >= 0 and 1 or -1,
        })
        if route then e.route, e.distance = route, distance end
    end
    e.drive.v = 0
    applyPose(e)
    save(e)
    if Collision then
        if Collision.removeWall then Collision.removeWall(e) end
        -- Drop any rr_collider segments that streamed back with the chunk, then
        -- re-create the chain around the fresh loco object.
        if Collision.dropWalls then Collision.dropWalls(e) end
        if Collision.onSpawn then Collision.onSpawn(e) end
    end
    print("[RailroaderMP] loco chunk reloaded -- re-bound record " .. tostring(e.id))
end

local function add(routeId, distance)
    if #ServerTrain.active > 0 then return ServerTrain.active[1] end
    routeId = routeId or RR.Routes.DEFAULT_ID
    if not RR.Routes.exists(routeId) then return nil end
    local route = RR.Routes.get(routeId)
    local start = Spline.sample(route, distance or 0)
    local def = AnimalDefinitions.getDef("rr_loco")
    if not def then return nil end
    local animal = addAnimal(getCell(), math.floor(start.x), math.floor(start.y), math.floor(start.z or 0), "rr_loco", def:getRandomBreed())
    if not animal then return nil end
    animal:addToWorld()
    animal:setGodMod(true); animal:setIsInvincible(true)
    local behavior = animal:getBehavior()
    if behavior then behavior:setBlockMovement(true) end
    local e = { animal = animal, id = animal:getAnimalID(), route = route, routeId = routeId,
        distance = distance or 0, drive = Drive.newState(), engine = Engine.newState(), baseId = routeId,
        reverser = 0, throttle = 0, brakeInput = 0, lightState = RR.Lights.newState(),
        hornOn = false, faceSign = 1, _lastCmdSeq = 0, _resyncFlag = true }
    ServerTrain.active[#ServerTrain.active + 1] = e; ServerTrain.byId[e.id] = e
    reanchor(e)
    applyPose(e); save(e)
    if Collision and Collision.onSpawn then Collision.onSpawn(e) end
    -- v1.0.2 (persistence): remember that a locomotive EXISTS in this world. On a
    -- restart the old loco's chunk may not be streamed yet when a client sends
    -- "ready"; without this flag the ready handler spawned a SECOND loco at the
    -- depot, and the later duplicate sweep then removed one of them (the parked
    -- train the player had left behind). See the ready handler.
    markSpawned()
    dbg("SERVER add loco %s route=%s d=%.2f engine=%s pos=(%.1f,%.1f,%.1f) dir=(%.3f,%.3f)",
        tostring(e.id), tostring(routeId), distance or 0, tostring(e.engine.running),
        animal:getX(), animal:getY(), animal:getZ() or 0, e.dirX or 0, e.dirY or 0)
    return e
end

local function adopt(animal)
    local md = animal:getModData()
    if not (md and md.rrLoco) then return end
    local id = animal:getAnimalID()
    local existing = ServerTrain.byId[id]
    if existing then
        -- v1.0.5 (chunk reload): the same saved id can stream back as a NEW
        -- object after an unload -- re-bind the record instead of skipping, so
        -- the sim keeps driving the reloaded body from the world's truth.
        if existing.animal ~= animal then
            rebind(existing, animal)
        else
            existing._unloaded = false
        end
        return
    end
    local routeId = md.rrRouteId or RR.Routes.DEFAULT_ID
    if not RR.Routes.exists(routeId) then return end
    local e = { animal = animal, id = id, route = RR.Routes.get(routeId), routeId = routeId,
        distance = tonumber(md.rrDistance) or 0, drive = Drive.newState(), engine = Engine.newState(), baseId = routeId,
        reverser = tonumber(md.rrReverser) or 0, throttle = 0, brakeInput = 0,
        lightState = { head = tonumber(md.rrHead) or RR.Lights.OFF, cab = md.rrCabLight and true or false, boards = true },
        hornOn = false, faceSign = tonumber(md.rrFaceSign) or 1, _lastCmdSeq = 0, _resyncFlag = true }
    e.engine.fuel = tonumber(md.rrFuel) or e.engine.fuel
    e.engine.battery = tonumber(md.rrBattery) or e.engine.battery
    e.engine.condition = tonumber(md.rrCond) or e.engine.condition
    -- v1.0.4 (restart continuity): restore the last saved velocity -- a restart
    -- mid-motion resumes with the no-driver emergency brake bleeding it to a
    -- stop instead of the loco magically appearing parked at the save point.
    if md.rrV then e.drive.v = tonumber(md.rrV) or 0 end
    e.derailed = md.rrDerailed and true or false
    -- Don't resume running an out-of-order loco (condition 0): the immobilization
    -- stall below would only stop it on the first tick. Same rule as the SP client.
    if md.rrEngineOn and (e.engine.condition or 1) > (Engine.C.IMMOBILIZE_AT or 0) then
        Engine.forceStart(e.engine)
    end
    ServerTrain.active[#ServerTrain.active + 1] = e; ServerTrain.byId[id] = e
    -- A saved loco just streamed back in: this save HAS had its one spawn, so
    -- no later depot attempt may create a second one (v1.0.7 flag unification).
    markSpawned()
    reanchor(e)
    applyPose(e)
    dbg("SERVER adopt loco %s derailed=%s route=%s d=%.2f engine=%s pos=(%.1f,%.1f,%.1f) dir=(%.3f,%.3f)",
        tostring(id), tostring(e.derailed), tostring(e.routeId), e.distance or 0,
        tostring(e.engine.running), animal:getX(), animal:getY(), animal:getZ() or 0,
        e.dirX or 0, e.dirY or 0)
    if Collision then
        -- v1.0.5 (restart leftovers): the PREVIOUS session's rr_collider wall
        -- segments are persisted in the save with the same rrWallLoco. Drop them
        -- before spawning the fresh chain, or they linger as invisible blockers
        -- at the old spot ("重启后车不见了，原地留下碰撞箱").
        if Collision.dropWalls then Collision.dropWalls(e) end
        if Collision.onSpawn then Collision.onSpawn(e) end
    end
end

local function reacquire()
    local animals = getCell():getAnimals()
    if not animals then return end
    local found = {}
    local chosen, duplicates = nil, {}
    for index = 0, animals:size() - 1 do
        local animal = animals:get(index)
        local md = animal:getModData()
        if md and md.rrLoco then
            found[animal:getAnimalID()] = animal
            -- v1.0.4: prefer the animal we are ALREADY simulating (so a legacy
            -- duplicate sweep can never remove the live loco, whichever order the
            -- cell returns them), then a non-derailed one; the rest are duplicates.
            local adopted = ServerTrain.byId[animal:getAnimalID()] ~= nil
            if not chosen or adopted
               or (chosen:getModData().rrDerailed and not md.rrDerailed) then
                if chosen then duplicates[#duplicates + 1] = chosen end
                chosen = animal
            else
                duplicates[#duplicates + 1] = animal
            end
        end
    end
    -- v1.0.5 (chunk unload edge case): a record whose animal is no longer in a
    -- loaded chunk must PARK in memory (zero velocity, skip physics) -- a
    -- disconnected train must never keep an invisible phantom speed that would
    -- resume rolling into unloaded chunks when the chunk streams back.
    for _, e in ipairs(ServerTrain.active) do
        if found[e.id] then
            e._unloaded = false
            -- v1.0.5: the wall chain was dropped while the loco was parked
            -- (chunk unloaded); re-create it now that the animal is back in the
            -- loaded cell. No-op when the chain already exists.
            if e.animal and Collision and Collision.onSpawn then
                pcall(function() Collision.onSpawn(e) end)
            end
        elseif not e._unloaded and not e.driver
               and not tableNonEmpty(e.passengers) then
            e._unloaded = true
            e.drive.v = 0
            e.throttle = 0
            e.brakeInput = 1
            -- Parked in memory: no visible body in this chunk, so no wall chain
            -- either -- a stale chain would sit as invisible blockers at the
            -- last pose. Rebuilt on re-bind / un-park.
            if Collision and Collision.removeWall then
                pcall(function() Collision.removeWall(e) end)
            end
            pcall(function() if e.animal then save(e) end end)
            print("[RailroaderMP] loco chunk unloaded -- parked in memory: " .. tostring(e.id))
        end
    end
    if chosen then adopt(chosen) end
    for _, animal in ipairs(duplicates) do
        if ServerTrain.byId[animal:getAnimalID()] then
            print("[RailroaderMP] keeping adopted locomotive: " .. tostring(animal:getAnimalID()))
        else
            print("[RailroaderMP] removing duplicate locomotive: " .. tostring(animal:getAnimalID()))
            pcall(function() animal:removeFromWorld(); animal:removeFromSquare() end)
        end
    end
end

local function size(e)
    local v = 0.7
    pcall(function() v = e.animal:getAnimalSize() end)
    return v
end

--------------------------------------------------------------------------
-- Cab shelter (Task 1.P, MP side). Vanilla's wetness/thermo checks
-- (BodyDamage.UpdateWetness / Clothing.getWetDryState) run on the SERVER's
-- copy of the character, so the client-only "Shelter" bed marker
-- (RR_CabClimate) leaves a seated player rained on in MP. Same world-less
-- IsoObject trick here: named "Shelter", never added to a square, so no
-- save pollution. setBed + setIsResting are bare field writes -- asserted
-- every sim tick from pinSeats, cleared on release.
--------------------------------------------------------------------------
local SHELTER_SPRITE = "industry_railroad_05_52"
local SHELTER_NAME   = "Shelter"   -- exact string: Clothing compares equalsIgnoreCase
local shelterMarker, shelterTried

local function shelterMarkerObj()
    if shelterMarker or shelterTried then return shelterMarker end
    shelterTried = true
    local players = getOnlinePlayers()
    local sq
    pcall(function()
        if players and players:size() > 0 then sq = players:get(0):getSquare() end
    end)
    local o
    pcall(function()
        o = IsoObject.new(sq, SHELTER_SPRITE)
        o:setName(SHELTER_NAME)
    end)
    local sprite
    if o then pcall(function() sprite = o:getSprite() end) end
    if not (o and sprite) then
        print("[RailroaderMP] cab shelter marker unavailable -- MP rain shelter is OFF this boot.")
        return nil
    end
    shelterMarker = o
    return shelterMarker
end

-- shelterSeat(pl): arm the cab's roof on the server-authoritative character.
-- Fail-open: a marker build failure costs the rain shelter, never the seat.
local function shelterSeat(pl)
    local o = shelterMarkerObj()
    if not (pl and o) then return false end
    pcall(function() pl:setIsResting(true) end)
    pcall(function() pl:setBed(o) end)
    return true
end

-- unshelter(pl): back out in the weather the moment the player leaves the
-- cab (or is dropped from a seat).
local function unshelter(pl)
    if not pl then return end
    pcall(function() pl:setIsResting(false) end)
    pcall(function() pl:setBed(nil) end)
end

--------------------------------------------------------------------------
-- Server-side seat pin (doc §9.1). The server is authoritative for seated
-- players: driver (seat 0) and passengers are moved onto the EXACT seat world
-- point the client computes (shared RR.Body.seatWorld), every sim tick, so ALL
-- clients see seated bodies on the train and the driver's camera rides the body.
-- Each seated player is also frozen (setBlockMovement) and muted (setCanShout
-- false -- Q is the horn) exactly like a vanilla vehicle seat.
-- NOTE on the two-pin split (v1.0.2): the server write above is what OTHER
-- clients see, while the seated player's OWN client additionally re-pins
-- locally per render frame (RR_MPClient -> Ride.pinRider) so the camera tracks
-- the interpolated body smoothly. The two writes do not fight: the server's is
-- authoritative for the shared view, the local one only corrects the local
-- frame between server syncs.
--------------------------------------------------------------------------
local function pinSeats(e)
    local p = pose(e)
    local players = getOnlinePlayers()
    if not players then return end
    -- Build the seat map first: driver is always seat 0, passengers carry
    -- their assigned seat index (1..MAX_PASSENGERS).
    local seated = {}
    if e.driver then seated[e.driver] = 0 end
    if e.passengers then
        for id, seat in pairs(e.passengers) do seated[id] = seat end
    end
    for i = 0, players:size() - 1 do
        local pl = players:get(i)
        local seat = seated[pl:getOnlineID()]
        if seat ~= nil then
            local sx, sy, sz = RR.Body.seatWorld(p, size(e), seat)
            pl:setX(sx); pl:setY(sy); pl:setZ(sz)
            -- setNextX/Y so the engine's own movement resolution also targets
            -- the seat (belt-and-braces: setX alone can be reverted by the
            -- character-movement phase).
            pcall(function() pl:setNextX(sx); pl:setNextY(sy) end)
            -- Facing: driver looks along motion (reverser sign), passengers
            -- look along the route heading. e._faceSign caches the driver's
            -- last direction so neutral keeps it (see RR_Lights.faceSign).
            local s = 1
            if seat == 0 and Drive.faceSign then
                s = Drive.faceSign(e.reverser, e._faceSign)
                e._faceSign = s
            end
            pcall(function() pl:setForwardDirection(p.dirX * s, p.dirY * s) end)
            pcall(function() pl:setBlockMovement(true) end)
            pcall(function() pl:setCanShout(false) end)
            -- Cab roof (Task 1.P): the server-authoritative character must carry
            -- the same Shelter marker + resting flag the client asserts locally,
            -- or BodyDamage.UpdateWetness rains on a seated player (wetness is
            -- server-side). Re-asserted every tick, like the client's pinRider.
            shelterSeat(pl)
        end
    end
end

--------------------------------------------------------------------------
-- Alpha gate (doc §7.2.2): pin the loco's render alpha to 1 ONLY while a player
-- is aboard or within ALPHA_RANGE. Otherwise leave the engine's culling alone --
-- a per-tick global pin would force-render the train for every client on the map.
--------------------------------------------------------------------------
local function pinAlpha(e)
    if e.driver or tableNonEmpty(e.passengers) then
        pcall(function() e.animal:setAlphaAndTarget(1) end)
        return
    end
    local players = getOnlinePlayers()
    if not players then return end
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        local dx, dy = p:getX() - e.animal:getX(), p:getY() - e.animal:getY()
        if dx * dx + dy * dy <= ALPHA_RANGE * ALPHA_RANGE then
            pcall(function() e.animal:setAlphaAndTarget(1) end)
            return
        end
    end
end

--------------------------------------------------------------------------
-- Fast-forward interlock (doc §5.2): a train being worked -- or rolling -- pins
-- the server game speed to 1, exactly like a vanilla car driver. Same rule as
-- RR_Ride.holdRealtime, but enforced on the server so a REMOTE driver's train
-- cannot be fast-forwarded by the host.
-- Why: the network sim runs on real time. If the host hits x40, the client's
-- wall-clock interpolation axis (snapshot tick + serverWallMs) would stretch
-- while the fixed-step accumulator keeps stepping 60Hz sim per real second --
-- the train would visually crawl while the sim burns game days. One loco
-- rolling therefore locks everyone's clock, the same trade a vanilla car
-- driver already imposes.
--------------------------------------------------------------------------
local function enforceRealtime()
    for _, e in ipairs(ServerTrain.active) do
        local moving = math.abs(e.drive.v or 0) > STOPPED_SPEED
        if moving or e.driver then
            if moving then
                -- Rolling wins unconditionally: even a standing-by driver
                -- cannot be fast-forwarded while the loco is moving.
                pcall(function()
                    if getGameSpeed and getGameSpeed() > 1 then setGameSpeed(1); getGameTime():setMultiplier(1) end
                end)
                return
            end
            -- Stationary but worked: hold 1x only while the prime mover is
            -- being cranked / warming up / throttled -- an idling parked loco
            -- with a sleeping crew may still be fast-forwarded.
            local eng = e.engine
            local cranking = eng and not eng.running
                and (eng.phase == "priming" or eng.phase == "cranking"
                     or (eng.crankTime or 0) > 0 or (eng.primeTime or 0) > 0)
            if eng and eng.phase == "warmup" then cranking = true end
            if Drive.needsRealtime(e.drive, { throttle = e.throttle, brakeInput = e.brakeInput, cranking = cranking }) then
                pcall(function()
                    if getGameSpeed and getGameSpeed() > 1 then setGameSpeed(1); getGameTime():setMultiplier(1) end
                end)
                return
            end
        end
    end
end

--------------------------------------------------------------------------
-- One fixed sim step (doc §5.1). `sim` is the game-seconds motion step (capped),
-- `game` the game-seconds clock step (fuel/battery/warm-up run on it).
-- Order matters: (1) rider bookkeeping first so a just-disconnected driver is
-- released BEFORE the physics check below decides the no-driver fallback;
-- (2) physics/pose/collision only when the loco is alive, not derailed and not
-- chunk-unloaded; (3) seats and alpha are pinned even for derailed wrecks so
-- riders do not fall through; (4) periodic reacquire AFTER the bookkeeping so
-- the unload-park decision sees current rider state.
--------------------------------------------------------------------------
local function stepOnce(sim, game)
    ServerTrain.ticks = ServerTrain.ticks + 1
    local online = {}
    local players = getOnlinePlayers()
    if players then
        for i = 0, players:size() - 1 do
            local pl = players:get(i)
            online[pl:getOnlineID()] = pl
        end
    end
    for _, e in ipairs(ServerTrain.active) do
        if e.animal then
            -- Seat bookkeeping runs regardless of chunk state: release offline
            -- riders but STASH their seat (v1.0.5 grace) so a reconnect during
            -- a chunk unload/reload puts them back ON the parked train instead
            -- of leaving the body behind where it disconnected.
            if e.driver and not online[e.driver] then
                e._lastSeats = e._lastSeats or {}
                e._lastSeats[e.driver] = 0
                e.driver = nil
                dbg("driver seat STASHED (offline) loco %s", tostring(e.id))
            end
            -- v1.0.4 (disconnect cleanup): an offline passenger must release
            -- their seat like the driver does -- otherwise the seat leaks (and
            -- alpha stays pinned) until the next server restart.
            if e.passengers then
                for id in pairs(e.passengers) do
                    if not online[id] then
                        e._lastSeats = e._lastSeats or {}
                        e._lastSeats[id] = e.passengers[id]
                        e.passengers[id] = nil
                    end
                end
            end
            -- v1.0.5 (reconnect after unload): restore a stashed seat when its
            -- rider is back online and the train is stopped (or nearly so) and
            -- its chunk is loaded and the rider is near enough -- never yank a
            -- body across unloaded chunks. The claim is dropped on derail /
            -- when another player took the seat / once restored.
            if tableNonEmpty(e._lastSeats) then
                for id, seat in pairs(e._lastSeats) do
                    if online[id] and not e._unloaded then
                        local pl = online[id]
                        local dx, dy = pl:getX() - e.animal:getX(), pl:getY() - e.animal:getY()
                        local near = dx * dx + dy * dy <= FAR_RANGE * FAR_RANGE
                        local slow = math.abs(e.drive.v or 0) <= 5 / 3.6
                        if e.derailed then
                            e._lastSeats[id] = nil
                        elseif seat == 0 then
                            if not e.driver and slow and near then
                                e.driver = id
                                e._lastSeats[id] = nil
                                dbg("stashed driver seat RESTORED for %s loco %s", tostring(id), tostring(e.id))
                            elseif e.driver ~= id then
                                e._lastSeats[id] = nil   -- seat taken while away
                            end
                        elseif not seatTaken(e, seat) then
                            if slow and near then
                                e.passengers = e.passengers or {}
                                e.passengers[id] = seat
                                e._lastSeats[id] = nil
                            end
                        else
                            e._lastSeats[id] = nil       -- seat taken while away
                        end
                    end
                end
            end
        end
        if e.animal and not e.animal:isDead() and not e.derailed and not e._unloaded then
            if not e.driver then
                -- No driver: throttle to 0, release the horn, and emergency
                -- brake while moving (or stop dead if already stopped). This
                -- is the same "abandoned train bleeds to a halt" rule as SP.
                e.throttle = 0
                if e.hornOn then
                    e.hornOn = false
                    sendServerCommand("RailroaderMP", "horn", { id = e.id, on = false })
                end
                if math.abs(e.drive.v or 0) > STOPPED_SPEED then
                    e.brakeInput = 1
                else
                    e.drive.v = 0; e.brakeInput = 0; e.reverser = 0
                end
            end
            local behavior = e.animal:getBehavior()
            if behavior then behavior:setBlockMovement(true) end
            -- The prime mover only produces traction while running: a dead or
            -- immobilised loco rolls as a pure coasting mass (throttle ignored).
            local throttle = e.engine.running and e.throttle or 0
            if e.engine.running then
                Engine.warmupTick(e.engine, game)
                if Engine.runTick(e.engine, game, throttle / Drive.C.NOTCH_MAX) then Engine.stop(e.engine) end
                -- IMMOBILIZATION (Task 1.N step 5): the moment condition reaches 0 a
                -- still-running diesel is SHUT DOWN -- same rule as the SP client
                -- (RR_TrainEntity), so a worn-out loco goes silent and can't be
                -- started again (startRefusal / forceStart both gate on condition).
                if e.engine.running and (e.engine.condition or 1) <= (Engine.C.IMMOBILIZE_AT or 0) then
                    Engine.stop(e.engine)
                    print(string.format("[RailroaderMP] condition 0 -> engine SHUT DOWN (out of order). speed=%.2f m/s",
                        math.abs(e.drive.v or 0)))
                end
            end
            -- Advance motion by the pure shared Drive.step (same function the
            -- client's prediction uses, so both sides agree), then clamp at the
            -- route ends for non-looped track.
            e.distance = e.distance + Drive.step(e.drive, { reverser = e.reverser, throttle = throttle, brakeInput = e.brakeInput }, sim)
            if not e.route.looped then
                if e.distance < 0 then e.distance = 0; e.drive.v = 0
                elseif e.distance > e.route.length then e.distance = e.route.length; e.drive.v = 0 end
            end
            -- v1.0.3f: the headlight end follows motion / reverser / last
            -- direction (neutral keeps the last; first spawn forward). The sign is
            -- authoritative, persisted (save/adopt) and broadcast as wire `fs`.
            if RR.Lights and RR.Lights.faceSign then
                e.faceSign = RR.Lights.faceSign(e.drive.v, e.reverser, e.faceSign)
            end
            applyPose(e)
            if Collision then
                -- One pcall around the whole sweep per tick: a single failing
                -- engine call must not abort the remaining physics (the sweep
                -- itself isolates its subsystems too); the error is logged
                -- once per loco so a persistent fault is visible but not spammy.
                -- v1.0.8: dt reaches the collision sweep (crush ROLL_GRACE timer).
                local okC, errC = pcall(Collision.update, e, pose(e), sim)
                if not okC and not e._collErr then
                    e._collErr = true
                    print("[RailroaderMP] Collision.update failed: " .. tostring(errC))
                end
            end
            -- Derail is a hard state change worth persisting immediately (a
            -- crash right after derailing must not resurrect an on-rails loco).
            if e.derailed then save(e) end
            if ServerTrain.ticks % SAVE_TICKS == 0 then save(e) end
        end
        pinSeats(e)          -- derailed wrecks still pin their riders (no floor)
        pinAlpha(e)          -- alpha gate independent of derail state
    end
    -- v1.0.5: run the periodic re-acquire AFTER the seat bookkeeping above, so
    -- the unload-park decision sees the CURRENT rider state (a just-disconnected
    -- driver is already released) instead of a one-tick-stale one.
    if ServerTrain.ticks % 60 == 1 then
        reacquire()
        if Collision and Collision.sweepOrphanWalls then Collision.sweepOrphanWalls() end
    end
    broadcastStates()
end

local accumulator = 0
local lastFrameMs = 0

local function frameDt()
    local ok, ms = pcall(function() return getTimestampMs() end)
    if not ok or not ms or ms <= 0 then return nil end
    lastWallMs = ms
    if lastFrameMs <= 0 then lastFrameMs = ms; return 0 end
    local dtReal = math.max(0, math.min((ms - lastFrameMs) / 1000, MAX_FRAME))
    lastFrameMs = ms
    return dtReal
end

--------------------------------------------------------------------------
-- Fixed-step driver (doc §5.1): wall-clock accumulator stepping 1/60 s of sim,
-- each step carrying its share of the frame's game-time advance. Fallback
-- (doc §5.4): no wall clock -> one variable step per frame, exactly the old
-- behaviour (tick numbers then scale with server fps, everything else holds).
--
-- Why an accumulator: PZ's OnTick fires once per rendered frame at whatever fps
-- the server manages (30, 60, 20 under load). Physics must see a CONSTANT step
-- (1/60s) or the fixed 60Hz tick stamps the client interpolates on would drift.
-- The accumulator converts irregular real frames into whole sim steps; MAX_FRAME
-- caps a single frame so a 2s hitch cannot queue 120 backlog steps (spiral).
-- Each sim step carries gameDt = STEP_SEC * (game multiplier in seconds/real
-- second), so fuel/warm-up still advance at game pace even though motion is
-- capped by DT_MAX per step.
--------------------------------------------------------------------------
local function onFrame()
    enforceRealtime()
    local frame = frameDt()
    if frame and frame > 0 then
        accumulator = math.min(accumulator + frame, MAX_FRAME)
        local mult = 0.8
        pcall(function() mult = getGameTime():getMultiplier() end)
        -- gamePerReal: how many GAME seconds elapse per real second at the
        -- current multiplier (e.g. 40 at x40, 1 at 1x). Each 1/60 sim step then
        -- burns STEP_SEC * gamePerReal game-seconds.
        local gamePerReal = (frame > 1e-6) and (Drive.dtGame(mult) / frame) or 1
        while accumulator >= STEP_SEC do
            local gameDt = STEP_SEC * gamePerReal
            stepOnce(math.min(gameDt, Drive.C.DT_MAX), gameDt)
            accumulator = accumulator - STEP_SEC
        end
    else
        -- No wall clock (dedicated-host edge): variable step per frame using
        -- the game-time-derived dt; sim tick count then follows server fps,
        -- which the client tolerates (it plays segments, not absolute ticks).
        local mult = 0.8
        pcall(function() mult = getGameTime():getMultiplier() end)
        stepOnce(Drive.dtSim(mult), Drive.dtGame(mult))
    end
end

local function near(player, e)
    local dx, dy = player:getX() - e.animal:getX(), player:getY() - e.animal:getY()
    return dx * dx + dy * dy <= CONTROL_RANGE * CONTROL_RANGE
end

local function nearStation(player, st)
    local x, y = stationPoint(st)
    if not x then return false end
    local dx, dy = player:getX() - x, player:getY() - y
    return dx * dx + dy * dy <= SERVICE_RANGE * SERVICE_RANGE
end

local function atStation(e, st)
    local x, y
    if st.rail then x, y = st.rail.x, st.rail.y
    else
        local depot = RR.Spawn and RR.Spawn.DEPOT
        if depot and RR.Routes.exists(depot.routeId) then
            local p = Spline.sample(RR.Routes.get(depot.routeId), depot.distance)
            x, y = p.x, p.y
        end
    end
    if not (x and e and e.animal) then return false end
    local dx, dy = e.animal:getX() - x, e.animal:getY() - y
    local r = st.zone or 14
    return dx * dx + dy * dy <= r * r and math.abs(e.drive.v or 0) < 0.2
end

local function item(player, id)
    if not (player and id) then return nil end
    return player:getInventory():getItemById(tonumber(id))
end

local function fluidName(fc)
    local f = fc and fc:getPrimaryFluid()
    return f and f:getFluidTypeString() or nil
end

local function dieselFluid()
    return (Fluid and Fluid.Get and Fluid.Get(Diesel.FLUID)) or Diesel.FLUID
end

local function service(player, e, args)
    local op = args.op
    local invItem = item(player, args.itemId)
    local fc = invItem and invItem:getFluidContainer()
    if op == "pour" then
        if not (fc and Diesel.isDiesel(fluidName(fc))) then return false, "IGUI_RR_Reject_DieselCan" end
        local res = Diesel.pour(e.engine.fuel, Engine.C.FUEL_CAP, fc:getAmount())
        if res.addedUnits <= 0 then return false, "IGUI_RR_Reject_Transfer" end
        fc:removeFluid(res.drawnLitres); e.engine.fuel = res.newFuel
    elseif op == "siphon" then
        if not (fc and Diesel.acceptsFluid(fluidName(fc))) then return false, "IGUI_RR_Reject_EmptyContainer" end
        local res = Diesel.siphon(e.engine.fuel, fc:getAmount(), fc:getCapacity())
        if res.addedLitres <= 0 then return false, "IGUI_RR_Reject_Transfer" end
        fc:addFluid(dieselFluid(), res.addedLitres); e.engine.fuel = res.newFuel
    elseif op == "depot" or op == "depotCan" then
        local st = station(args.station)
        if not (st and nearStation(player, st)) then return false, "IGUI_RR_Reject_TankTooFar" end
        if op == "depot" and not atStation(e, st) then return false, "IGUI_RR_Reject_LocoNotAtTank" end
        placeStation(st)
        local r = reserve(st)
        if op == "depot" then
            local amount = Refuel.fillAmount(e.engine.fuel, Engine.C.FUEL_CAP, r)
            if amount <= 0 then return false, "IGUI_RR_Reject_Transfer" end
            e.engine.fuel = e.engine.fuel + amount; setReserve(st, r - amount)
        else
            if not (fc and Diesel.acceptsFluid(fluidName(fc))) then return false, "IGUI_RR_Reject_EmptyContainer" end
            local res = Diesel.siphon(r, fc:getAmount(), fc:getCapacity())
            if res.addedLitres <= 0 then return false, "IGUI_RR_Reject_Transfer" end
            fc:addFluid(dieselFluid(), res.addedLitres); setReserve(st, res.newFuel)
        end
    elseif op == "repair" then
        if not (invItem and invItem:getFullType() == "Base.Wrench") then return false, "IGUI_RR_Reject_Wrench" end
        local condition = invItem:getCondition()
        if not condition or condition <= 0 then return false, "IGUI_RR_Reject_WrenchBroken" end
        if (e.engine.condition or 0) >= 1 then return false, "IGUI_RR_LocoServiced" end
        -- v1.0.5: one repair = +5 durability points (0.05 on the 0..1 condition
        -- the HUD shows as 0-100). The client runs the 5 in-game-minute read
        -- bar (RR_RepairAction) before sending this command.
        invItem:setCondition(condition - 1); e.engine.condition = math.min(1, (e.engine.condition or 0) + 0.05)
        -- Visible confirmation for the clicker (the state broadcast alone is easy to
        -- miss): a green halo "Repaired (+5%)" so the menu never reads as a no-op.
        sendServerCommand(player, "RailroaderMP", "serviced",
            { id = e and e.id, condition = e.engine.condition })
    else
        return false, "IGUI_RR_Reject_Unknown"
    end
    if invItem then pcall(function() invItem:syncItemFields() end) end
    if e then save(e) end
    return true
end

-- Long-running dedicated servers must not drown in per-action log spam: the
-- first occurrence of a repeatable event is logged, repeats are silenced for
-- LOG_THROTTLE_TICKS sim ticks (~10s). Support can still grep the stable key,
-- but a scripted client (or a lever-happy driver) cannot grow the log
-- unboundedly.
local LOG_THROTTLE_TICKS = 600
local logThrottles = {}
local function throttledLog(key, msg)
    local last = logThrottles[key]
    if last and ServerTrain.ticks - last < LOG_THROTTLE_TICKS then return end
    logThrottles[key] = ServerTrain.ticks
    print(msg)
end

-- reject(player, reasonKey, id): tell the driver why a command was refused.
-- reasonKey is a TRANSLATION KEY (IGUI_RR_Reject_*) - the client resolves it
-- with getText(), so every player sees the message in his own language. The
-- server log prints the key itself (stable and greppable for support), but
-- throttled per player+reason so rejection floods cannot spam the log.
--------------------------------------------------------------------------
-- isAdmin(player): server-side access-level gate (v1.0.8 rerail). The client's
-- isAdmin() display gate is cosmetic -- this is the authority. player:getAccessLevel()
-- is the reference-mod pattern on the server (TikitownPowerPlant); isAdmin() is the
-- official-server pattern (server/ISDestroyCursor.lua).
--------------------------------------------------------------------------
local function isAdminPlayer(player)
    local admin = false
    pcall(function()
        local lvl = player and player.getAccessLevel and tostring(player:getAccessLevel() or ""):lower()
        admin = lvl == "admin"
    end)
    if admin then return true end
    pcall(function() admin = isAdmin() and true or false end)
    return admin
end

local function reject(player, reasonKey, id)
    local onlineId = player and player:getOnlineID()
    throttledLog("reject:" .. tostring(onlineId) .. ":" .. tostring(reasonKey),
        "[RailroaderMP] control rejected: " .. reasonKey)
    local args = { reason = reasonKey }
    if id then args.id = id end
    sendServerCommand(player, "RailroaderMP", "rejected", args)
end

-- Doc §11: per-player command rate limit (RATE_LIMIT = 40/s) so a scripted
-- client cannot flood the sim or the state stream. A sliding window of 60
-- ticks (1 sim second) counts control/switch/fuel commands per player; over
-- the limit -> "rejected" so the legit client's lever rolls back visibly
-- instead of silently diverging from the server.
local rateBuckets = {}
local function rateLimited(player)
    local id = player and player:getOnlineID()
    if not id then return true end
    local now = ServerTrain.ticks
    local b = rateBuckets[id]
    if not b or now - b.t >= 60 then b = { n = 0, t = now }; rateBuckets[id] = b end
    b.n = b.n + 1
    return b.n > RATE_LIMIT
end

local function removePassenger(e, onlineId)
    if e.passengers then e.passengers[onlineId] = nil end
end

local function passengerSeat(e)
    e.passengers = e.passengers or {}
    for seat = 1, MAX_PASSENGERS do
        local occupied = false
        for _, assignedSeat in pairs(e.passengers) do
            if assignedSeat == seat then occupied = true; break end
        end
        if not occupied then return seat end
    end
end

local function seatTaken(e, seat)
    if not e.passengers then return false end
    for _, assigned in pairs(e.passengers) do
        if assigned == seat then return true end
    end
    return false
end

local function switchAt(baseId, switchId)
    local def = RR.TrackGraph and RR.TrackGraph.defs and RR.TrackGraph.defs[baseId]
    if not def then return nil end
    for _, sw in ipairs(def.switches or {}) do
        if sw.id == switchId then return sw end
    end
end

local function saveSwitches()
    local wd = ModData.getOrCreate("RR_World")
    wd.rrSwitches = wd.rrSwitches or {}
    for baseId, def in pairs(RR.TrackGraph.defs or {}) do
        local states = {}
        for _, sw in ipairs(def.switches or {}) do states[sw.id] = def.states[sw.id] or "normal" end
        wd.rrSwitches[baseId] = states
    end
end

local function loadSwitches()
    local wd = ModData.getOrCreate("RR_World")
    for baseId, states in pairs(wd.rrSwitches or {}) do
        for switchId, state in pairs(states) do
            RR.TrackGraph.setState(baseId, switchId, state)
        end
    end
end

-- v1.0.6: a client re-sends "ready" every ~300 ticks to catch late chunk
-- streams. While a saved loco's chunk has never streamed this boot, that
-- periodic handshake used to print the "waiting for reacquire" line every few
-- seconds for as long as anyone was online -- log it once per boot instead
-- (the state cannot change until reacquire adopts the loco, so repeats add no
-- information).
local readyNoChunkLogged = false

--------------------------------------------------------------------------
-- OnClientCommand funnel (doc §4.4 / §11). Every client->server command lands
-- here. Validation order is deliberate:
--   1. module gate + a shared per-player rate limiter for the hot commands;
--   2. switch commands get their own geometry check (must stand within
--      CONTROL_RANGE of the frog -- "any player can throw a far switch by
--      WALKING there", matching SP);
--   3. ready/resync/fuel-depotCan have no train target;
--   4. everything else resolves the train by id, then requires the player to
--      be within CONTROL_RANGE of the loco (anti-teleport: you cannot board
--      or drive from across the map);
--   5. per-command authorization (board speed gate, driver identity,
--      profession licence, stop-before-leave).
-- Nothing from `args` is trusted: ranges are clamped, states whitelisted,
-- ids parsed as numbers.
--------------------------------------------------------------------------
local function command(module, name, player, args)
    if module ~= "RailroaderMP" then return end
    args = args or {}
    if name == "dbgState" then
        -- v1.0.15: client heartbeat -- the client console.txt is overwritten on
        -- every relaunch, so the client reports its loco-record view to the ONE
        -- log that survives. Grep the server log for "[RailroaderMP-dbg] CLIENT".
        dbg("CLIENT %s: active=%s ids=[%s] derailed=[%s] pending=%s ride=%s",
            tostring(player and player:getUsername() or "?"), tostring(args.active),
            tostring(args.ids), tostring(args.der), tostring(args.pending), tostring(args.ride))
        return
    end
    if name == "control" or name == "switch" or name == "fuel" then
        if rateLimited(player) then reject(player, "IGUI_RR_Reject_RateLimit"); return end
    end
    if name == "switch" then
        -- Switches are world objects, not train-bound: any nearby player may
        -- throw one. The state is applied to the shared TrackGraph, persisted
        -- (saveSwitches) and the through-routes of every active loco are
        -- re-anchored so the server immediately drives the new branch.
        local sw = switchAt(args.baseId, args.switchId)
        if not sw or (args.state ~= "normal" and args.state ~= "reverse") then
            reject(player, "IGUI_RR_Reject_SwitchNotFound")
            return
        end
        local dx, dy = player:getX() - sw.at.x, player:getY() - sw.at.y
        if dx * dx + dy * dy > CONTROL_RANGE * CONTROL_RANGE then
            reject(player, "IGUI_RR_Reject_SwitchTooFar")
            return
        end
        RR.TrackGraph.setState(args.baseId, args.switchId, args.state)
        saveSwitches()
        for _, e in ipairs(ServerTrain.active) do reanchor(e) end
        throttledLog("switch:" .. tostring(args.baseId) .. ":" .. tostring(args.switchId),
            "[RailroaderMP] switch accepted: " .. tostring(args.switchId) .. "=" .. args.state)
        broadcastStates()
        sendServerCommand("RailroaderMP", "switch", {
            baseId = args.baseId, switchId = args.switchId, state = args.state,
        })
        return
    end
    if name == "ready" then
        -- Client join handshake: re-acquire any saved loco whose chunk may
        -- have streamed in since the last scan, spawn the depot loco if this
        -- world never had one (worldSpawned -- rrTrainSpawned OR the SP
        -- rrLocoSpawned -- prevents a duplicate when the saved loco's chunk
        -- simply has not loaded yet), then send the full+resync welcome state
        -- for every train + switches + fuel reserves.
        reacquire()
        ensureStations()
        ensureSwitches()
        if #ServerTrain.active == 0 and not worldSpawned() then
            local depot = RR.Spawn and RR.Spawn.DEPOT
            add(depot and depot.routeId, depot and depot.distance)
        elseif #ServerTrain.active == 0 then
            if not readyNoChunkLogged then
                readyNoChunkLogged = true
                print("[RailroaderMP] ready: saved locomotive exists but its chunk is not"
                      .. " loaded yet -- waiting for reacquire instead of spawning a duplicate.")
            end
        end
        local onlineId = player:getOnlineID()
        if not ServerTrain.readyPlayers[onlineId] then
            ServerTrain.readyPlayers[onlineId] = true
            print("[RailroaderMP] client ready: player=" .. tostring(onlineId)
                  .. " locomotives=" .. tostring(#ServerTrain.active))
        end
        sendState(player)
        return
    end
    if name == "resync" then
        -- Ship the retained authoritative snapshots newer than the client's last
        -- accepted tick (empty = everything kept), oldest first, so the client can
        -- replay the gap instead of freezing / extrapolating on stale data.
        local after = tonumber(args.afterTick) or 0
        local out = {}
        local n = ServerTrain.historyN
        local start = math.max(1, n - HISTORY_MAX + 1)
        for i = start, n do
            local st = ServerTrain.history[(i - 1) % HISTORY_MAX + 1]
            if st and st.tick and st.tick > after then out[#out + 1] = st end
        end
        sendServerCommand(player, "RailroaderMP", "history", { entities = out })
        return
    end
    if name == "fuel" and args.op == "depotCan" then
        local ok, reason = service(player, nil, args)
        if not ok then reject(player, reason); return end
        broadcastStates()
        return
    end
    local e = ServerTrain.byId[tonumber(args.id)]
    if not e then reject(player, "IGUI_RR_Reject_NoLoco"); return end
    if not near(player, e) then reject(player, "IGUI_RR_Reject_LocoTooFar", e.id); return end
    local onlineId = player:getOnlineID()
    if name == "rerail" then
        -- Admin-only recovery (v1.0.8, user decision -- NO debug gate): lift a
        -- derailed loco back onto the rails at the point it left them. The client
        -- menu is display-gated on isAdmin(); this check is the authority (a
        -- forged command from a non-admin gets rejected).
        if not isAdminPlayer(player) then reject(player, "IGUI_RR_Reject_NotAdmin", e.id); return end
        if not e.derailed then reject(player, "IGUI_RR_Reject_NotDerailed", e.id); return end
        rerail(e)
        return
    end
    if name == "board" then
        -- Boarding: speed gate first (a 50 km/h train is not a bus stop),
        -- then take the driver seat if free, else the lowest free passenger
        -- seat (1..MAX_PASSENGERS). Explicit board also cancels any pending
        -- auto-restore claim (v1.0.5) so a player who walked away on purpose
        -- is not yanked back when the chunk reloads.
        if e.derailed then reject(player, "IGUI_RR_Reject_Derailed", e.id); return end
        if math.abs(e.drive.v or 0) > 5 / 3.6 then reject(player, "IGUI_RR_Reject_TooFastBoard", e.id); return end
        -- v1.0.5: explicit boarding cancels any pending auto-restore claim for
        -- this player (and any claim on the seat they take).
        if e._lastSeats then e._lastSeats[onlineId] = nil end
        if e.driver == onlineId or (e.passengers and e.passengers[onlineId]) then broadcastStates(); return end
        if not e.driver then
            e.driver = onlineId
            dbg("board: %s takes DRIVER of loco %s", tostring(onlineId), tostring(e.id))
        else
            local seat = passengerSeat(e)
            if not seat then reject(player, "IGUI_RR_Reject_SeatsFull", e.id); return end
            e.passengers[onlineId] = seat
            dbg("board: %s takes passenger seat %s of loco %s", tostring(onlineId), tostring(seat), tostring(e.id))
            if e._lastSeats then
                for sid, sseat in pairs(e._lastSeats) do
                    if sseat == seat then e._lastSeats[sid] = nil end
                end
            end
        end
        broadcastStates()
        return
    end
    if name == "control" then
        -- Control authorization: only the assigned driver may move the
        -- controls, and only with the Railroader licence -- the same
        -- profession gate as SP, now enforced where it cannot be modded out.
        if e.derailed then reject(player, "IGUI_RR_Reject_Derailed", e.id); return end
        if e.driver ~= onlineId then reject(player, "IGUI_RR_Reject_DriverSeat", e.id); return end
        if not (RR.Profession and RR.Profession.hasLicense(player)) then reject(player, "IGUI_RR_Reject_NoProfession", e.id); return end
    end
    if name == "control" then
        -- Doc §4.1: every control command carries a client seq; stale (<= last
        -- accepted) commands are ignored, and lastCmdSeq is echoed in the state
        -- stream so the client knows its input reached the server.
        local seq = tonumber(args.seq) or 0
        if seq > 0 and seq <= (e._lastCmdSeq or 0) then return end
        e._lastCmdSeq = seq > 0 and seq or (e._lastCmdSeq or 0)
        e.throttle = math.max(0, math.min(8, tonumber(args.throttle) or 0))
        e.reverser = math.max(-1, math.min(1, tonumber(args.reverser) or 0))
        e.brakeInput = (tonumber(args.brake) or 0) > 0 and 1 or 0
        -- Horn is a held state: broadcast the EDGE to every client so observers
        -- (up to 200 tiles) play it with their own distance falloff; the driver
        -- client already played it locally and skips the replay.
        if args.horn ~= nil and (args.horn and true or false) ~= (e.hornOn and true or false) then
            e.hornOn = args.horn and true or false
            sendServerCommand("RailroaderMP", "horn", { id = e.id, on = e.hornOn })
        end
        -- Start/stop are edge latches the client keeps re-sending until the
        -- engine state confirms: start requires reverser in neutral, fuel in
        -- the tank and condition above the immobilisation threshold; stop
        -- requires the loco stopped and the throttle already at 0.
        if args.start and not e.engine.running and e.reverser == 0
           and e.engine.fuel > 0 and (e.engine.condition or 1) > (Engine.C.IMMOBILIZE_AT or 0) then
            Engine.forceStart(e.engine)
        end
        if args.stop and math.abs(e.drive.v) <= 0.05 and e.throttle == 0 then Engine.stop(e.engine) end
        if args.head ~= nil then e.lightState.head = math.max(0, math.min(2, tonumber(args.head) or 0)) end
        if args.cab ~= nil then e.lightState.cab = args.cab and true or false end
    elseif name == "release" then
        -- Leaving: driver must stop first (moving loco + empty cab = runaway
        -- with no one to brake; the server would emergency-brake anyway, but
        -- we do not let the player teleport out mid-roll), passenger must slow
        -- to boarding speed. Releasing also re-enables movement/shouting and
        -- drops the pending seat-restore claim.
        if e.driver == onlineId then
            if math.abs(e.drive.v or 0) > STOPPED_SPEED then reject(player, "IGUI_RR_Reject_StopToLeave", e.id); return end
            e.driver = nil; e.throttle = 0; e.brakeInput = 1
            dbg("release: %s leaves DRIVER of loco %s", tostring(onlineId), tostring(e.id))
            if e._lastSeats then e._lastSeats[onlineId] = nil end
            if e.hornOn then
                e.hornOn = false
                sendServerCommand("RailroaderMP", "horn", { id = e.id, on = false })
            end
        elseif e.passengers and e.passengers[onlineId] then
            if math.abs(e.drive.v or 0) > 5 / 3.6 then reject(player, "IGUI_RR_Reject_TooFastLeave", e.id); return end
            removePassenger(e, onlineId)
            if e._lastSeats then e._lastSeats[onlineId] = nil end
        else
            reject(player, "IGUI_RR_Reject_NotAboard", e.id)
            return
        end
        pcall(function() player:setBlockMovement(false) end)
        pcall(function() player:setCanShout(true) end)
        unshelter(player)   -- off the loco = back out in the weather (Task 1.P)
    elseif name == "fuel" then
        local ok, reason = service(player, e, args)
        if not ok then reject(player, reason); return end
    end
    broadcastStates()
end

-- Events.OnClientCommand.Add(command)
-- Events.OnTick.Add(onFrame)
-- Events.OnServerStarted.Add(function()
--     loadSwitches()
--     reacquire()
--     if Collision and Collision.sweepOrphanWalls then Collision.sweepOrphanWalls() end
-- end)

--------------------------------------------------------------------------
-- Server-console recovery/diagnostics (testing aid; the server console is
-- trusted by definition -- no auth check). Type into the server console:
--   RR.ServerTrain.debugDump()                    -- state of every active loco
--   RR.ServerTrain.debugRerail()                  -- re-rail ALL derailed locos
--   RR.ServerTrain.debugRerail(id)                -- re-rail one loco by id
-- This is the quick un-stick path when a test save has a wrecked loco: the
-- in-game admin right-click re-rail also works, but the console works even if
-- no player is aboard / nobody is in-game.
--------------------------------------------------------------------------
function ServerTrain.debugDump()
    for _, e in ipairs(ServerTrain.active) do
        print(string.format("[RailroaderMP-dbg] DUMP loco %s derailed=%s route=%s d=%.2f engine=%s pos=(%.1f,%.1f,%.1f) dir=(%.3f,%.3f)",
            tostring(e.id), tostring(e.derailed), tostring(e.routeId), e.distance or 0,
            tostring(e.engine and e.engine.running), e.animal and e.animal:getX() or 0,
            e.animal and e.animal:getY() or 0, e.animal and e.animal:getZ() or 0,
            e.dirX or 0, e.dirY or 0))
    end
    if #ServerTrain.active == 0 then print("[RailroaderMP-dbg] DUMP: no active locos") end
end

function ServerTrain.debugRerail(id)
    local n = 0
    for _, e in ipairs(ServerTrain.active) do
        if (not id or tostring(e.id) == tostring(id)) and e.derailed then
            if rerail(e) then n = n + 1 end
        end
    end
    print(string.format("[RailroaderMP-dbg] debugRerail: re-railed %d loco(s)%s", n, id and (" (id " .. tostring(id) .. ")") or ""))
end

RR.ServerTrain = ServerTrain
return ServerTrain
