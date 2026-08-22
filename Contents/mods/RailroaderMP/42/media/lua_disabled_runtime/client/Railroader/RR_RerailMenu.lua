--***********************************************************************
-- RailroaderMP / RR_RerailMenu  -- "Put it back on the rails", ADMIN-GATED
--
-- Derailment is TERMINAL by design: the loco detaches from the spline, freezes
-- at a wreck pose, the engine dies and the controls refuse -- for good. A real
-- re-railing mechanic (crane, crew, hours of work) is a later plan; this file is
-- the admin recovery back door: one context-menu entry that lifts a wrecked loco
-- back onto the rails at the point it left them (RR_ServerTrain.rerail).
--
-- THE GATE IS THE SERVER ADMIN, NOT DEBUG (v1.0.8, user decision). The SP v1.0.2
-- original hangs this entry on the game's own -debug launch option -- fine for a
-- solo dev tool, but in multiplayer that would hand every debug client a free
-- undo of a derailment. This fork gates on the server access level instead:
--   * client: isAdmin() -- the official client-side flag (InvContextMedia /
--     AdminContextMenu use it) -- controls whether the entry is DRAWN;
--   * server: player:getAccessLevel() == "admin" (RR_ServerTrain.isAdminPlayer)
--     is the AUTHORITY -- a forged command from a non-admin is rejected.
-- No launch argument is needed for either side.
--
-- FAILS CLOSED, on purpose: if the admin test can't be made at all, there is no
-- entry. A gate whose whole job is to hide something from players must not open
-- itself when it is confused.
--
-- MP ONLY: the entry talks to the server (RR_MPClient.requestRerail), so it is
-- wired only when RR_MPClient is present (connected client / co-op host). A pure
-- singleplayer session of this mod has no server to ask -- the SP original mod
-- covers that path with its own -debug tool.
--
-- ANCHORING -- TWO PATHS, because neither alone covers a 17-tile body:
--   1. the WORLD-object menu (the square under the cursor) matched against the
--      wreck's own footprint box (RR.Body.hullDistance on the frozen pose, the
--      same measure the E-key boarding reach uses) rather than a radius from the
--      loco's centre, which for a 15-tile body puts "arm's length at the cab
--      door" and "two car-lengths off the nose" at the same distance;
--   2. the ANIMAL path -- RR_AnimalMenuFilter calls addForAnimal() as it
--      suppresses the livestock menu on one of ours. The engine fills
--      `clickedAnimals` from the 3x3 around the clicked square
--      (ISWorldObjectContextMenuLogic), and the body is lined with rr_collider
--      segments every ~2.2 tiles, so a click anywhere ALONG the hull hits one of
--      them -- with no dependence on the cursor->square projection at all.
--***********************************************************************

print("[RailroaderMP] RR_RerailMenu.lua: loading...")

local RerailMenu = {}

-- tiles of slack around the DRAWN hull for the world-menu path (see the
-- isometric-offset note in the SP original; the only thing within tiles of a
-- wreck is the wreck, so the pad is generous).
RerailMenu.CLICK_PAD = 6.0
-- tiles from one of OUR animals (loco body or a collider segment) to the wreck
-- it belongs to, for the animal path. A segment is never more than half a body
-- length off its own loco, so this only has to beat ~9 tiles; the slack costs
-- nothing because the search is over derailed locos only.
RerailMenu.ANIMAL_RADIUS = 30.0

--------------------------------------------------------------------------
-- txt(key, fallback): getText echoes the KEY back when a translation is missing,
-- so every label falls back to readable English instead of printing "IGUI_RR_...".
--------------------------------------------------------------------------
local function txt(key, fallback)
    local s = key
    pcall(function() s = getText(key) end)
    if not s or s == "" or s == key then return fallback or key end
    return s
end

--------------------------------------------------------------------------
-- adminGate(): is THIS client a server admin? isAdmin() is the official
-- client-side flag (InvContextMedia / AdminContextMenu). Wrapped because a
-- missing global must read FALSE (fail closed), not throw inside a context-menu
-- build.
--------------------------------------------------------------------------
local function adminGate()
    local on = false
    pcall(function() on = isAdmin() and true or false end)
    return on
end
RerailMenu.adminGate = adminGate   -- exposed for report()

--------------------------------------------------------------------------
-- derailedAt(sq): the DERAILED loco whose footprint (+ CLICK_PAD) covers this
-- square, nearest hull first, or nil. Only derailed ones are considered -- a
-- healthy loco has nothing to offer this menu.
--------------------------------------------------------------------------
local function derailedAt(sq)
    local T = RR.TrainEntity
    if not (sq and T and T.active and RR.Body) then return nil end
    local x, y = sq:getX() + 0.5, sq:getY() + 0.5
    local best, bestD
    for _, e in ipairs(T.active) do
        local pose = e.derailed and (e.derailPose or e.lastPose)
        if pose then
            local size = 1.0
            pcall(function() size = e.animal and e.animal:getAnimalSize() or 1.0 end)
            local d = RR.Body.hullDistance(pose, size, x, y)
            if d <= RerailMenu.CLICK_PAD and ((not bestD) or d < bestD) then
                best, bestD = e, d
            end
        end
    end
    return best
end

--------------------------------------------------------------------------
-- nearestDerailed(x, y, radius): the derailed loco whose WRECK CENTRE is nearest
-- (x,y) within `radius`, or nil. The centre is the right measure here -- the
-- caller already knows it is touching this loco (it clicked one of its own
-- animals), it just has to say WHICH loco that was.
--------------------------------------------------------------------------
local function nearestDerailed(x, y, radius)
    local T = RR.TrainEntity
    if not (T and T.active) then return nil end
    local best, bestD
    for _, e in ipairs(T.active) do
        local pose = e.derailed and (e.derailPose or e.lastPose)
        if pose then
            local dx, dy = (pose.x or 0) - x, (pose.y or 0) - y
            local d = math.sqrt(dx * dx + dy * dy)
            if d <= radius and ((not bestD) or d < bestD) then best, bestD = e, d end
        end
    end
    return best
end

--------------------------------------------------------------------------
-- perform(e): ask the server to do it (the server is the only one who may touch
-- a derailed loco's state). No walk-to and no timed action on purpose -- a timed
-- action would be pretending this is a mechanic. The "rerailed" reply shows the
-- green halo; a rejected command shows the red one through the normal channel.
--------------------------------------------------------------------------
function RerailMenu.perform(e)
    if not (RR.MPClient and RR.MPClient.requestRerail) then return end
    RR.MPClient.requestRerail(e)
end

-- The two option shapes. ISContextMenu passes the option's `param1` first, so
-- the world menu (param1 = worldobjects) and the animal menu (param1 = the
-- record) need different entry points into the same call.
function RerailMenu.onRerail(worldobjects, e) RerailMenu.perform(e) end
function RerailMenu.onRerailTarget(e)         RerailMenu.perform(e) end

--------------------------------------------------------------------------
-- offered(context, label): is this entry already on the menu? BOTH paths can
-- fire for one right-click -- the animal path runs first (inside
-- createMenuEntries, which triggers OnClickedAnimalForContext) and the world
-- path second (OnFillWorldObjectContextMenu, at the end of createMenu) -- and
-- the animal one is called once PER clicked animal, i.e. once per collider
-- segment in the 3x3. Without this the wreck would sprout four identical
-- entries, which reads as broken rather than as thorough.
--------------------------------------------------------------------------
local function offered(context, label)
    for i = 1, (context.numOptions or 1) - 1 do
        local o = context.options and context.options[i]
        if o and o.name == label then return true end
    end
    return false
end

--------------------------------------------------------------------------
-- addForAnimal(playerNum, context, animal, test): the ANIMAL path, called from
-- RR_AnimalMenuFilter at the exact point where it drops the vanilla livestock
-- menu for one of ours. `animal` is an rr_loco body or (far more often, since
-- they line the whole hull) an rr_collider segment; either way the wreck it
-- belongs to is the nearest derailed loco. Never adds anything twice.
--------------------------------------------------------------------------
function RerailMenu.addForAnimal(playerNum, context, animal, test)
    if not adminGate() then return end            -- admin only (no -debug gate)
    if not (RR.MPClient and RR.MPClient.requestRerail) then return end
    if not (animal and context) then return end
    local x, y
    pcall(function() x, y = animal:getX(), animal:getY() end)
    if not x then return end
    local e = nearestDerailed(x, y, RerailMenu.ANIMAL_RADIUS)
    if not e then return end
    local label = txt("IGUI_RR_Rerail", "Put it back on the rails")
    if offered(context, label) then return end
    context:addOption(label, e, RerailMenu.onRerailTarget)
end

--------------------------------------------------------------------------
-- OnFillWorldObjectContextMenu: (playerNum, context, worldobjects, test)
--------------------------------------------------------------------------
function RerailMenu.OnFill(playerNum, context, worldobjects, test)
    if not adminGate() then return end            -- admin only (no -debug gate)
    if not (RR.MPClient and RR.MPClient.requestRerail) then return end

    local sq
    for _, o in ipairs(worldobjects) do
        local s = o:getSquare()
        if s then sq = s; break end
    end
    if not sq then return end

    local e = derailedAt(sq)
    if not e then return end

    local label = txt("IGUI_RR_Rerail", "Put it back on the rails")
    if offered(context, label) then return end   -- the animal path already added it
    context:addOption(label, worldobjects, RerailMenu.onRerail, e)
end

Events.OnFillWorldObjectContextMenu.Add(RerailMenu.OnFill)

--------------------------------------------------------------------------
-- report(): why is the entry not there? Answers the whole gate chain in one
-- console line each -- the admin flag, the MP client, how many locos are active,
-- which of them are derailed and how far the PLAYER is from each wreck's hull.
--------------------------------------------------------------------------
function RerailMenu.report()
    local T = RR.TrainEntity
    print(string.format("[RailroaderMP] rerail menu: isAdmin=%s  mpClient=%s  active=%d",
        tostring(adminGate()),
        tostring(RR.MPClient and true or false),
        (T and T.active and #T.active) or -1))
    if not (T and T.active) then return end
    local p = getPlayer()
    for i, e in ipairs(T.active) do
        local pose = e.derailPose or e.lastPose
        local d = -1
        if p and pose and RR.Body then
            local size = 1.0
            pcall(function() size = e.animal and e.animal:getAnimalSize() or 1.0 end)
            d = RR.Body.hullDistance(pose, size, p:getX(), p:getY())
        end
        print(string.format("  [%d] derailed=%s at (%.1f,%.1f) -- player %.1f tiles from the hull "
              .. "(world-menu pad %.1f, animal radius %.1f)",
              i, tostring(e.derailed and true or false),
              (pose and pose.x) or 0, (pose and pose.y) or 0, d,
              RerailMenu.CLICK_PAD, RerailMenu.ANIMAL_RADIUS))
    end
end

RR = RR or {}
RR.RerailMenu = RerailMenu
print("[RailroaderMP] RR_RerailMenu.lua: loaded OK -- re-rail entry is "
      .. (adminGate() and "LIVE (you are a server admin)" or "hidden (admin only)")
      .. "; console: RR.RerailMenu.report().")
return RerailMenu
