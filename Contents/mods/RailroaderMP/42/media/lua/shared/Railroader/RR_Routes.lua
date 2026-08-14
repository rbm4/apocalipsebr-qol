--***********************************************************************
-- Railroader / RR_Routes  (Task 1.B: real routes on the map)
--
-- A tiny REGISTRY over the engine-independent route core. A route DEFINITION is
-- plain data: { looped = bool, nodes = { {x,y,z,name?}, ... } } in TRUE world
-- tile coords (no player offset). Definitions are registered by string id from
-- any shared Lua file (see RR_RealRoutes.lua) and BUILT on demand via
-- RR_TrackData.buildRoute (cached). The spline core is unchanged: it only ever
-- sees a built route.
--
-- Why data-in-Lua and not a bespoke file format: a Lua table IS a file under
-- media, auto-loaded by PZ, trivially hand-authored, and round-trips through the
-- same node shape the core already uses. Task 1.C (in-world editor) will WRITE
-- these node lists to a file via B42 file IO; the format stays identical.
--***********************************************************************

print("[Railroader] RR_Routes.lua: loading...")
local TrackData = RR and RR.TrackData or require("Railroader/RR_TrackData")

local Routes = {}
Routes.defs     = {}      -- id -> { looped=bool, nodes={ {x,y,z,name?}, ... } }
Routes._built   = {}      -- id -> built route (cache)
Routes.DEFAULT_ID = "main"  -- route the O key spawns ON when it exists

--------------------------------------------------------------------------
-- register(id, def): store a route definition (plain data). Safe at file load.
-- Re-registering the same id replaces it and invalidates the built cache.
--------------------------------------------------------------------------
function Routes.register(id, def)
    assert(type(id) == "string", "RR_Routes.register: id must be a string")
    assert(type(def) == "table" and type(def.nodes) == "table",
        "RR_Routes.register: def.nodes must be a table")
    Routes.defs[id]   = def
    Routes._built[id] = nil
    print("[Railroader] route registered: '" .. id .. "' (" .. tostring(#def.nodes)
          .. " nodes, looped=" .. tostring(def.looped == true) .. ")")
    return def
end

--------------------------------------------------------------------------
-- exists(id): true if a usable (>= 2 node) definition is registered.
--------------------------------------------------------------------------
function Routes.exists(id)
    local def = Routes.defs[id]
    return def ~= nil and type(def.nodes) == "table" and #def.nodes >= 2
end

--------------------------------------------------------------------------
-- get(id): BUILT route by id (cached), or nil if unknown / < 2 nodes.
-- Nodes authored as {x=,y=,z=,name=} are already the plain-table shape the core
-- consumes, so no conversion is needed.
--------------------------------------------------------------------------
function Routes.get(id)
    if Routes._built[id] then return Routes._built[id] end
    if not Routes.exists(id) then return nil end
    local def   = Routes.defs[id]
    local built = TrackData.buildRoute(def.nodes, { looped = def.looped == true })
    Routes._built[id] = built
    return built
end

--------------------------------------------------------------------------
-- ids(): list of registered route ids (for debug / menus later).
--------------------------------------------------------------------------
function Routes.ids()
    local out = {}
    for id in pairs(Routes.defs) do out[#out + 1] = id end
    return out
end

RR = RR or {}
RR.Routes = Routes
print("[Railroader] RR_Routes.lua: loaded OK")
return Routes
