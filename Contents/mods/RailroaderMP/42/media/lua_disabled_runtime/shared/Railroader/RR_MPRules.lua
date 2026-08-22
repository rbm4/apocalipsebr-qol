--***********************************************************************
-- Railroader / RR_MPRules  -- PURE: who is allowed to run the mod
--
-- Engine-free half of the multiplayer guard (client/Railroader/RR_MP.lua reads the
-- four engine flags and hands them here). Same split as RR_SleepRules/RR_Sleep and
-- RR_Cab/RR_CabClimate: the rule is a table in, a verdict out, unit-tested offline.
--
-- THE RULE. Railroader has no server authority: the loco is posed, the zombies are
-- killed, the obstacles are destroyed and the switches are thrown by client-side Lua.
-- That is the world in singleplayer, and a lie everywhere else. So:
--     singleplayer  -> run
--     co-op HOST    -> run  (his process owns the server; best-effort, unverified)
--     any other client -> stand down
-- An explicit override always wins, in both directions.
--***********************************************************************

local MPRules = {}

--------------------------------------------------------------------------
-- decide(env) -> blocked, reason
--   env.client    true if this game is a connected client (isClient())
--   env.coopHost  true if this process launched the co-op server
--   env.override  nil = follow the rule, true = force ON, false = force OFF
-- `reason` is a short stable token, meant for the log line and the tests -- not
-- for the player, who gets IGUI_RR_MPOff instead.
--------------------------------------------------------------------------
function MPRules.decide(env)
    env = env or {}
    if env.override == true  then return false, "forced-on"  end
    if env.override == false then return true,  "forced-off" end
    if not env.client        then return false, "singleplayer" end
    if env.coopHost          then return false, "coop-host" end
    return true, "client"
end

--------------------------------------------------------------------------
-- blocked(env) -- the boolean alone, for callers that don't want the reason.
--------------------------------------------------------------------------
function MPRules.blocked(env)
    local b = MPRules.decide(env)
    return b
end

RR = RR or {}
RR.MPRules = MPRules

return MPRules
