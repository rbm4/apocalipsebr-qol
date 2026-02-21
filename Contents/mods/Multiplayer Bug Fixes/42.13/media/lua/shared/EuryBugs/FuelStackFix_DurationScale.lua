local MOD = "FuelStackFix"

local DEBUG = getCore():getDebug()

local function dlog(msg)
    if DEBUG then
        DebugLog.log(DebugType.General, "[" .. MOD .. "] " .. tostring(msg))
    end
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Tune REF/MIN/MAX to taste.
local REF = 150      -- fuelAmt that should take ~100
local MIN = 5      -- minimum ticks per step
local MAX = 100     -- maximum ticks per step

local function scaledDuration(self)
    if self.character and self.character:isTimedActionInstant() then
        return 1
    end

    local amt = tonumber(self.fuelAmt) or 0
    if amt <= 0 then
        return 100 -- fallback to vanilla-ish if something weird happens
    end

    -- linear scale around REF -> 100
    local t = math.floor((amt / REF) * 100 + 0.5)
    return clamp(t, MIN, MAX)
end

local function patchOne(classTable, className)
    if not classTable then return end
    if classTable.__FuelStackFixScaledDuration then return end

    classTable.__FuelStackFixScaledDuration = true

    local oldGetDuration = classTable.getDuration

    classTable.getDuration = function(self)
        return scaledDuration(self)
    end

    dlog("Patched duration for " .. tostring(className))
end

-- These globals exist once their lua files are loaded.
-- In most mod load orders they will be loaded by the time shared mods run,
-- but we guard in case and allow later re-run safely.
patchOne(_G.ISAddFuelAction, "ISAddFuelAction")
patchOne(_G.ISBBQAddFuel, "ISBBQAddFuel")
