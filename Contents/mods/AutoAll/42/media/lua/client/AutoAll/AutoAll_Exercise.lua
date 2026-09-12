--[[
    Auto All - making the Auto Exercise switch stick (Build 42 / SP + MP)
    ------------------------------------------------------------------
    > *Panda:* "I disabled Auto Exercise when it appeared but the Muscle
    > Manager seems to still be taking effect. Is it possible to have a
    > toggle to turn Muscle Manager off or better, just use a separate mod
    > entry for it so people who only really wanted the Auto All
    > functionality can choose not to enable Muscle Manager on the
    > modlist?"

    The toggle exists and it is wired up: MuscleManager_Config defines
    MM.enabled(), which asks AutoAll.enabled("exercise"), and both
    MuscleManager_Core's onPlayerUpdate and MuscleManager_UI's
    ISFitnessUI:initialise return early when it says no.

    So why does it not stick? Because the standalone Muscle Manager
    (Workshop 3775968752) can be installed as well, and both mods ship
    files at the same relative paths:

        media/lua/client/MuscleManager/MuscleManager_Core.lua
        media/lua/client/MuscleManager/MuscleManager_Config.lua
        media/lua/client/MuscleManager/MuscleManager_UI.lua

    Project Zomboid keeps one file per relative path, so whichever mod
    loads later wins - all nine of them, together. The standalone has no
    MM.enabled() and no gates, because it has no Auto All tickbox to
    answer to. When it wins the race, the loop that runs is the ungated
    one and the Auto All switch is decoration.

    That cannot be fixed inside a file the standalone replaces. It can be
    fixed from here, because AutoAll_Exercise.lua exists only in this mod
    and is therefore always loaded.

    So the switch is enforced from the outside instead of asked politely
    from the inside: while Auto Exercise is off, any running training loop
    is stopped and the AUTO box is held unticked, whoever built it.

    ------------------------------------------------------------------
    On the separate mod entry

    Panda's second suggestion - ship Muscle Manager as its own entry in
    the mod list - would solve this outright, and is not done here. A new
    mod entry starts unticked, so every player currently using Auto
    Exercise would lose it on update with nothing on screen to explain
    why. Trading one silent surprise for another is not a fix. It is a
    real option, and it is the author's call rather than this file's.
]]

require "AutoAll/AutoAll_Core"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.exerciseGateLoaded then return end
AA.exerciseGateLoaded = true

-- Said once per session, not once per tick. Having to step in means the
-- ungated copy is the one running, and that is worth a line in
-- console.txt: it is the difference between "the option is broken" and
-- "you have both mods installed".
local warned = false

--- True when the Muscle Manager that actually loaded is one that never
--- asks Auto All anything.
local function ungatedCopy()
    return MuscleManager ~= nil and type(MuscleManager.enabled) ~= "function"
end

--- Whatever loaded, hold it to the switch.
local function enforce(player)
    if not player or not instanceof(player, "IsoPlayer") or not player:isLocalPlayer() then return end
    if MuscleManager == nil then return end
    if AA.enabled("exercise") then return end

    -- The AUTO box on the vanilla Fitness panel remembers itself between
    -- openings, and MM.autoDefault can tick it on its own. Held down
    -- rather than set once, because the panel writes it back.
    if MuscleManager.autoTicked == true then
        MuscleManager.autoTicked = false
    end

    local states = MuscleManager.states
    if type(states) ~= "table" then return end

    local state = states[player:getPlayerNum()]
    if not state or state.active ~= true then return end

    if not warned then
        warned = true
        print("[AutoAll] exercise is switched off but a Muscle Manager loop was running"
                .. (ungatedCopy() and " - the standalone Muscle Manager is loaded and"
                    .. " its files replace the bundled ones, so it never sees the switch."
                    .. " Stopping it from here." or " - stopping it."))
    end

    if type(MuscleManager.stop) == "function" then
        pcall(MuscleManager.stop, player, nil)
    else
        -- Nothing to call. Take the state away, which is what every
        -- decision in that loop is keyed on.
        state.active = false
        states[player:getPlayerNum()] = nil
    end
end

Events.OnPlayerUpdate.Add(enforce)

--- Hand the gate to a Muscle Manager that does not have one.
---
--- Harmless when the bundled copy won - it already defines this and the
--- check below leaves it alone. Worth doing for the case where a future
--- standalone starts asking: it gets the right answer without needing to
--- know Auto All exists.
Events.OnGameStart.Add(function()
    if MuscleManager == nil then return end
    if type(MuscleManager.enabled) == "function" then return end

    MuscleManager.enabled = function()
        return AA.enabled("exercise")
    end
    print("[AutoAll] exercise: installed the missing MuscleManager.enabled gate")
end)
