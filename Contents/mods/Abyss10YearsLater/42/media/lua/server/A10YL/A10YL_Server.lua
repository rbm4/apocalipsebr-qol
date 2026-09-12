-- Abyss's 10 Year Later - sole server event bootstrap.
local function isClientOnlyRuntime()
    if type(isServer) == "function" and isServer() then return false end
    return type(isClient) == "function" and isClient()
end

if isClientOnlyRuntime() then
    print("[A10YL] server bootstrap ignored in client-only runtime")
    return {}
end

local Queue = require("A10YL/core/A10YL_Queue")
local Persistence = require("A10YL/core/A10YL_Persistence")
local PreAge = require("A10YL/core/A10YL_PreAge")
local PersistentPlacement = require("A10YL/core/A10YL_PersistentPlacement")
require("A10YL/A10YL_VanillaVegetationBridge")

local Server = {}

-- Runtime smoke-test marker: one line per Lua bootstrap load, independent of
-- Debug Diagnostics, so admins can prove the server/SP authority layer loaded.
print("[A10YL] ==================================================")
print("[A10YL] BUILD: v" .. tostring(Persistence.BUILD_VERSION) .. " checkpoint" .. tostring(Persistence.CHECKPOINT))
print("[A10YL] GENERATOR: " .. tostring(Persistence.GENERATOR_VERSION))
print("[A10YL] server bootstrap loaded")
print("[A10YL] ==================================================")

function Server.onLoadChunk(chunk)
    -- Discovery only. Do not mutate the chunk synchronously while PZ is still
    -- materialising it; the bounded OnTick queue performs the actual ageing.
    Queue.enqueueChunk(chunk)
end

function Server.onLoadGridSquare(square)
    -- Live-square hint/catch-up path. This only queues coordinates; mutation is
    -- still deferred to OnTick so save-sensitive changes occur after load.
    Queue.enqueueLoadedSquare(square)
end

function Server.onTick()
    PreAge.onTick()
    Queue.onTick()
end

function Server.onSave()
    PreAge.onSave()
    Persistence.onSave()
    PersistentPlacement.logSummary("save")
end


function Server.onClientCommand(module, command, player, args)
    if PreAge.onClientCommand(module, command, player, args) then
        return
    end
end

function Server.onLoadRadioScripts(scriptManager, newGame)
    Persistence.noteNewGameSignal(newGame, "OnLoadRadioScripts")
end

function Server.onInitGlobalModData(newGame)
    -- Treat Global ModData initialisation as an explicit world-session boundary.
    -- Runtime scheduler state must never leak between saves in the same Lua VM.
    Queue.resetRuntime()
    local ready = Persistence.onInitGlobalModData(newGame)
    if ready then
        print("[A10YL] world state ready; generator=" .. tostring(Persistence.GENERATOR_VERSION))
        print("[A10YL] WORLD LINEAGE: " .. (Persistence.isFreshWorldLineage() and "fresh-A10YL-world" or "existing/unknown-save"))
        print("[A10YL] NEW AREAS POLICY: fresh-bootstrap + live-square/square-moddata")
        print("[A10YL] PERSISTENCE MODE: live-square + native-placement + hot-save")
    end
end

if Events.OnLoadRadioScripts and Events.OnLoadRadioScripts.Add then
    Events.OnLoadRadioScripts.Add(Server.onLoadRadioScripts)
end
Events.OnInitGlobalModData.Add(Server.onInitGlobalModData)
Events.LoadChunk.Add(Server.onLoadChunk)
if Events.LoadGridsquare and Events.LoadGridsquare.Add then
    Events.LoadGridsquare.Add(Server.onLoadGridSquare)
end
Events.OnTick.Add(Server.onTick)
if Events.OnSave and Events.OnSave.Add then
    Events.OnSave.Add(Server.onSave)
end
if Events.OnClientCommand and Events.OnClientCommand.Add then
    Events.OnClientCommand.Add(Server.onClientCommand)
end

return Server
