--***********************************************************************
-- Railroader / RR_Geom
-- Small, engine-independent math helpers used by the spline core.
-- Pure Lua: no PZ globals referenced. Safe to require() in a standalone
-- Lua interpreter for offline unit tests, and also loaded by PZ where it
-- registers itself under the global RR namespace.
--***********************************************************************

-- Lua 5.1 (Kahlua, used by PZ) has math.atan2; Lua 5.3+ removed it in favour
-- of math.atan(y, x). Support both so the same file runs in-game and offline.
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local Geom = {}

-- Linear interpolation.
function Geom.lerp(a, b, t)
    return a + (b - a) * t
end

-- 2D distance (horizontal). Z (floor) is intentionally ignored here: arc length
-- along a route should stay ~ ground distance so "speed" feels right even when a
-- segment changes floor. Z is still interpolated, just not counted in length.
function Geom.dist2d(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
end

-- Heading (radians, math convention: 0 = +X "east", CCW positive) from a->b.
function Geom.heading2d(ax, ay, bx, by)
    return atan2(by - ay, bx - ax)
end

-- Normalize a 2D vector. Returns (0,0) for a zero-length input.
function Geom.normalize2d(x, y)
    local len = math.sqrt(x * x + y * y)
    if len < 1e-9 then return 0, 0 end
    return x / len, y / len
end

Geom.atan2 = atan2

-- Register under the shared RR namespace for in-game use (PZ does not use
-- require(); files are loaded into a shared global environment).
RR = RR or {}
RR.Geom = Geom

return Geom
