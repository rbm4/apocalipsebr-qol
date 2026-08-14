--***********************************************************************
-- Railroader / RR_SwitchPlace  (put a turnout sprite on a BARE fork)
--
-- Some switches sit where the vanilla map has no turnout tile. Those RR_TrackGraph
-- switches carry a `place` field -- either a single sprite:
--     place = { x, y, z, sprite = "industry_railroad_05_52" }
-- or, for a turnout that is drawn as a MULTI-tile graphic (e.g. Стрелка 2 = _54 + _55),
-- a list placed at per-tile offsets from (x,y):
--     place = { x, y, z, sprites = { {sprite=".._54", dx=0, dy=0}, {sprite=".._55", dx=0, dy=-1} } }
-- This module drops those sprites into the world as their chunks stream in, so the
-- switch is VISIBLE and the context menu can anchor. Idempotent: it never adds a
-- second copy, whether or not the tiles persisted into the save.
--
-- Grounded in B42: sq:AddTileObject(IsoObject.new(sq, "<sprite>")) -- the exact
-- pattern vanilla scenarios use (DebugUIs/Scenarios/*). Injected via
-- Events.LoadGridsquare as the world loads (SP; MP would also need a transmit).
--***********************************************************************

print("[Railroader] RR_SwitchPlace.lua: loading...")
require("Railroader/RR_TrackGraph")

local SwitchPlace = {}

-- Index each TARGET TILE "x,y,z" -> sprite name, for an O(1) per-square lookup
-- (LoadGridsquare fires for every square that streams in, so this must be cheap).
-- A multi-tile `sprites` list expands to one entry per offset tile.
local INDEX
local function index()
    if INDEX then return INDEX end
    INDEX = {}
    if not (RR.TrackGraph and RR.TrackGraph.defs) then return INDEX end
    local function add(x, y, z, sprite)
        INDEX[math.floor(x) .. "," .. math.floor(y) .. "," .. math.floor(z or 0)] = sprite
    end
    for _, def in pairs(RR.TrackGraph.defs) do
        for _, sw in ipairs(def.switches or {}) do
            local p = sw.place
            if p then
                if p.sprite then add(p.x, p.y, p.z, p.sprite) end
                if p.sprites then
                    for _, s in ipairs(p.sprites) do
                        add(p.x + (s.dx or 0), p.y + (s.dy or 0), p.z, s.sprite)
                    end
                end
            end
        end
    end
    return INDEX
end

local function hasSprite(sq, sprite)
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local spr = objs:get(i):getSprite()
        if spr and spr:getName() == sprite then return true end
    end
    return false
end

function SwitchPlace.onLoadSquare(sq)
    if RR.MP and RR.MP.blocked() then return end     -- client-side AddTileObject = desync (RR_MP)
    if not sq then return end
    local key = math.floor(sq:getX()) .. "," .. math.floor(sq:getY()) .. "," .. math.floor(sq:getZ())
    local sprite = index()[key]
    if not sprite then return end
    if hasSprite(sq, sprite) then return end
    sq:AddTileObject(IsoObject.new(sq, sprite))
    print("[Railroader] placed switch sprite '" .. sprite .. "' at " .. key)
end

Events.LoadGridsquare.Add(SwitchPlace.onLoadSquare)

RR = RR or {}
RR.SwitchPlace = SwitchPlace
print("[Railroader] RR_SwitchPlace.lua: loaded OK")
return SwitchPlace
