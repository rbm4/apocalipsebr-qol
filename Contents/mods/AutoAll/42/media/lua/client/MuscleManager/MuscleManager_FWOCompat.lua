--[[
    [B42.20] Muscle Manager (Build 42 / SP + MP)
    ------------------------------------------------------------------
    Compatibility with "FWO Working Bench Press & Treadmill" (Steam Workshop
    3729663486), which adds a working treadmill and bench press.

    That mod registers "treadmill"/"treadmill_n/e/w/s" and
    "benchpress"/"benchpress_n/e/w/s" straight into FitnessExercises.exercisesType
    with no `item` field, so - left alone - our exercise rotation would treat
    them exactly like squats or push-ups and queue ISFitnessAction on the spot,
    wherever the character happens to be standing.

    Read from the mod's own source (media/lua/client/FWOWorkingTreadmillMenu.lua
    and FWOUseBenchPressMenu.lua): it only ever exercises through a world
    context-menu entry, added via Events.OnPreFillWorldObjectContextMenu, whose
    handler (onUseTreadmill / onUseBench) walks the character to the exact
    machine tile, faces it correctly, unequips hands/bags, equips the barbell
    for the bench, and only then queues the very same vanilla ISFitnessAction
    our own mod uses. Rather than re-deriving that sprite/offset/facing math
    (four directions times two machines, liable to drift out of sync with FWO's
    own updates), we call FWOWorkingTreadmillMenu2.onUseTreadmill / .onUseBench
    directly once we've located the machine ourselves with FWO's own finder
    functions - both are plain global Lua tables, not gated behind any event.
]]

MuscleManager = MuscleManager or {}
local MM = MuscleManager

if MM.fwoCompatLoaded then return end
MM.fwoCompatLoaded = true

-- base furniture type -> name of the global table FWO exposes for it
local FWO_MODULE_NAME = {
    treadmill  = "FWOWorkingTreadmillMenu2",
    benchpress = "FWOUseBenchPressMenu",
}

local function fwoModule(base)
    local name = FWO_MODULE_NAME[base]
    return name and _G[name]
end

--- Base furniture type ("treadmill"/"benchpress") for any FWO exercise id,
--- directional or not - nil if this isn't one of FWO's furniture exercises,
--- including when FWO itself simply isn't installed.
function MM.furnitureBaseType(exerciseType)
    if not exerciseType then return nil end
    local base = exerciseType:match("^(%a+)_[nsew]$") or exerciseType
    if fwoModule(base) then return base end
    return nil
end

local function findMachine(base, mod, player)
    local square = player:getSquare()
    if not square then return nil end
    local radius = MM.opt("travelRange") or 4
    if base == "treadmill" then
        return mod.findTreadmillNearSquare(square, radius)
    end
    return mod.findBenchNearSquare(square, radius)
end

--- True when the machine (and, for the bench, a barbell) is actually usable
--- right now - used to decide whether rotation may pick this exercise at all,
--- so we don't queue a set that FWO's own handler would silently refuse.
function MM.canUseFurnitureExercise(base, player)
    local mod = fwoModule(base)
    if not mod then return false end
    local machine = findMachine(base, mod, player)
    if not machine then return false end
    if base == "treadmill" and mod.hasPower and not mod.hasPower(machine) then
        return false
    end
    if base == "benchpress"
            and not player:getInventory():contains("Base.BarBell", true)
            and not player:getInventory():contains("Base.BarBell_Forged", true) then
        return false
    end
    return true
end

--- Finds the nearest machine and delegates the walk/face/equip/queue sequence
--- to FWO's own handler. Returns true once an attempt was made (even if FWO's
--- own moodle checks end up rejecting it) so the caller's normal
--- "didn't actually start" timeout handles that case the same as any other
--- failed set; false only when there is truly no machine nearby.
function MM.startFurnitureExercise(state, base)
    local mod = fwoModule(base)
    if not mod then return false end
    local player = state.player
    local machine = findMachine(base, mod, player)
    if not machine then return false end

    -- Same lookup FWO's own context menu uses: the directional id comes from
    -- the machine's actual sprite, never from whatever generic type our
    -- rotation happened to be holding.
    local spriteName = mod.getSpriteName(machine)
    local actionType = mod.spriteExerciseType[spriteName] or base

    if base == "treadmill" then
        mod.onUseTreadmill(nil, player, machine, actionType, state.minutes)
    else
        mod.onUseBench(nil, player, machine, actionType, state.minutes)
    end
    return true
end
