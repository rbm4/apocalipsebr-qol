--***********************************************************************
-- Railroader / RR_MP  -- the multiplayer guard
--
-- WHAT THIS IS. Railroader has no server half: `server/Railroader/` is still empty,
-- and every system that moves the locomotive, poses the collider chain, runs zombies
-- over, smashes obstacles, places switch stands and bulk tanks or throws points lives
-- in `client/` and runs on the local machine. In singleplayer that IS the world. On a
-- connected client it is not: the same code would
--     * run the approach spawn on EVERY client -> several K&L 800s, one per player,
--       each one a locally-added IsoAnimal the others cannot see;
--     * fight the server for the loco's position (animals are server-authoritative,
--       and we setX/setY it 60 times a second);
--     * destroy world objects and kill zombies with no authority to do either;
--     * write the spawn flag, the diesel reserves and the switch positions into a
--       per-client global ModData table that is never transmitted.
-- So on a client the mod STANDS DOWN: nothing spawns, nothing ticks, no context-menu
-- entries, and the vanilla V / F / walk-to keys are left alone instead of being claimed.
--
-- WHO IS ALLOWED TO RUN IT. Singleplayer, and the co-op HOST. The host's game process
-- is the one running the server, so his client is the closest thing we have to authority
-- -- that is the "SP/host" the Workshop page claims. It is still not verified in-game and
-- remote players will not see his locomotive; the warning below says so.
--
-- HOW WE TELL THEM APART (verified against the B42 decompile, not guessed):
--   isClient()      = GameClient.client   -- TRUE for any connected client, the co-op
--                                            host included (he connects to his own server)
--   isServer()      = GameServer.server   -- the server process only
--   CoopServer:isRunning()                -- CoopMaster.isRunning(): MY process launched
--                                            the co-op server. Locally authoritative, and
--                                            the check vanilla's own InviteFriends.lua uses.
--   isCoopHost()    = GameClient.connection.isCoopHost -- fallback ONLY. The server sets it
--                                            from `connections.size() == 1` (LoginPacket),
--                                            i.e. the FIRST player to join a dedicated
--                                            server gets it too. Used just in case the
--                                            CoopServer table is missing.
--
-- OVERRIDE, from the in-game console (session-only, nothing persisted):
--     RR.MP.set(true)    -- run it anyway; you accept the duplicates and the desync
--     RR.MP.set(false)   -- stand down even in singleplayer
--     RR.MP.set("auto")  -- back to the rule above
--     RR.MP.report()     -- what it decided and why
--***********************************************************************

RR = RR or {}

local MP = {}

-- nil = follow the rule; true = force ON; false = force OFF.
MP.override = nil

local cached = nil          -- MP.info() result; cleared on OnGameStart (the client has
                            -- connected by then, so the flags are finally meaningful)
local warned = false        -- the on-screen warning is once per session

--------------------------------------------------------------------------
-- evaluate() -- read the four engine flags, defensively. Every one of them is a global
-- that may not exist in some launch path, so each gets its own pcall and a false default.
--------------------------------------------------------------------------
local function evaluate()
    local i = { client = false, server = false, coopHost = false, coopCheck = "none" }

    pcall(function() i.client = isClient() == true end)
    pcall(function() i.server = isServer() == true end)

    -- Preferred: does MY process run the co-op server?
    local haveCoopTable = false
    pcall(function()
        if CoopServer and CoopServer.isRunning then
            haveCoopTable = true
            i.coopHost = CoopServer:isRunning() == true
        end
    end)
    if haveCoopTable then
        i.coopCheck = "CoopServer:isRunning"
    else
        -- Fallback: the server's own opinion. Coarse (see the header), but better than
        -- locking the host out of his own game because a global went missing.
        pcall(function() i.coopHost = isCoopHost() == true end)
        i.coopCheck = "isCoopHost"
    end

    return i
end

--------------------------------------------------------------------------
-- info() -- the cached flags.
--------------------------------------------------------------------------
function MP.info()
    if not cached then cached = evaluate() end
    return cached
end

--------------------------------------------------------------------------
-- blocked() -- THE gate. `if RR.MP and RR.MP.blocked() then return end` is the one line
-- every entry point carries. Written so a missing RR.MP means "run" -- the guard failing
-- to load must never take the mod down in singleplayer. The rule itself is pure and
-- unit-tested in shared/Railroader/RR_MPRules.lua; this only feeds it the engine flags.
--------------------------------------------------------------------------
function MP.blocked()
    local i = MP.info()
    if RR.MPClient and i.client then return true end
    local Rules = RR.MPRules
    if not Rules then                              -- shared module missing: fail OPEN in SP,
        if MP.override ~= nil then return not MP.override end   -- closed on a client
        return (i.client and not i.coopHost) and true or false
    end
    local b = Rules.decide({ client = i.client, coopHost = i.coopHost, override = MP.override })
    return b and true or false
end

--------------------------------------------------------------------------
-- describe() -- one line for the log.
--------------------------------------------------------------------------
function MP.describe()
    local i = MP.info()
    local blocked = MP.blocked()
    local reason = "?"
    if RR.MPRules then
        local _, r = RR.MPRules.decide({ client = i.client, coopHost = i.coopHost,
                                         override = MP.override })
        reason = r
    end
    local who
    if not i.client then         who = "singleplayer"
    elseif i.coopHost then       who = "co-op HOST (" .. i.coopCheck .. ")"
    else                         who = "connected CLIENT (" .. i.coopCheck .. ")" end
    return who .. "; rule=" .. reason .. " -> " .. (blocked and "STOOD DOWN" or "running")
end

--------------------------------------------------------------------------
-- report() / set() -- console helpers, in the shape of RR.Debug's.
--------------------------------------------------------------------------
function MP.report()
    print("[Railroader] MP guard: " .. MP.describe())
    return not MP.blocked()
end

function MP.set(v)
    if v == "auto" or v == nil then MP.override = nil
    else MP.override = v and true or false end
    cached = nil
    return MP.report()
end

--------------------------------------------------------------------------
-- The one-time notice. A player who joined a server with Railroader installed must be
-- told why there is no locomotive -- otherwise the mod reads as broken. Console line
-- always; a red halo once the survivor exists (the vanilla refusal channel, same as the
-- licence gate uses).
--------------------------------------------------------------------------
local function announce()
    if RR.MPClient then return end
    if warned then return end
    if not MP.blocked() then return end
    if MP.override == false then return end        -- turned off on purpose: no nag
    local p = nil
    pcall(function() p = getPlayer() end)
    if not p then return end                       -- retried by warnTick below
    warned = true
    pcall(function()
        HaloTextHelper.addBadText(p, getText("IGUI_RR_MPOff"))
    end)
    print("[Railroader] Railroader is a singleplayer/host mod for now: the locomotive, the "
          .. "switches and the diesel tanks are not server-authoritative, so on a connected "
          .. "client the mod stands down rather than duplicate them. RR.MP.set(true) runs it "
          .. "anyway (expect duplicates and desync); RR.MP.report() explains the decision.")
end

-- The halo needs a survivor, which may not exist the instant OnGameStart fires. Poll for
-- three seconds, then unhook for good. (Declared BEFORE the OnGameStart handler that
-- resets `tries`: a Lua closure only captures a local already in scope, so writing to it
-- from above would silently create a global instead.)
local tries    = 0
local polling  = false
local warnTick                                     -- forward declaration; see below

local function startPolling()
    if polling then return end
    tries, polling = 0, true
    Events.OnTick.Add(warnTick)
end

warnTick = function()
    tries = tries + 1
    if warned or (not MP.blocked()) or tries > 180 then
        polling = false
        Events.OnTick.Remove(warnTick)      -- vanilla does the same (ISButtonPrompt.lua:241)
        return
    end
    if tries % 30 == 0 then pcall(announce) end
end

Events.OnGameStart.Add(function()
    cached = nil                                   -- re-read now the connection is up
    warned = false
    print("[Railroader] MP guard: " .. MP.describe())   -- the log line: exactly once
    pcall(announce)
    if not warned then startPolling() end          -- no survivor yet: keep trying briefly
end)

RR.MP = MP
print("[Railroader] RR_MP.lua: loaded OK -- multiplayer guard armed (RR.MP.report()).")

return MP
