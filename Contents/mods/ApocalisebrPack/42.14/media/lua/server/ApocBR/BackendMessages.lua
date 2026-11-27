-- Server-only producer. Consumers and business decisions belong to the backend.
if not isServer() then return end
require "ApocBR/Entities"

BackendMessages = BackendMessages or {}
local API = BackendMessages
if API._installed then return API end
API._installed = true
local repository

local function messages()
    if not repository then
        repository = ApocBREntities.define("ApocBR.BackendMessage", {
            table = "backend_message", appendOnly = true,
            fields = {
                message_id = { type = "uuid", id = true },
                character_id = { type = "uuid" },
                session_id = { type = "uuid" },
                source_server_id = { type = "integer" },
                world = { type = "string" },
                identity_mode = { type = "string" },
                identity_key = { type = "string" },
                player_index = { type = "integer" },
                event_type = { type = "string" },
                payload = { type = "string" },
            },
        })
    end
    return repository
end

function API.context(player, expectedSteamId)
    return ApocBREntities.messageContext(player, expectedSteamId)
end

local Publication = {}
Publication.__index = Publication
-- State stays private: callers cannot edit the UUID, capability or frozen payload.
local publications = setmetatable({}, { __mode = "k" })
function Publication:retry(callback)
    if type(callback) ~= "function" then error("Publication callback required") end
    local state = publications[self]
    if state.inFlight then error("Publication is busy") end
    state.inFlight = true
    local ok, accepted = pcall(function()
        return messages():append(state.context, state.id, state.values, function(result)
            state.inFlight = false
            result.messageId = state.id
            callback(result)
        end)
    end)
    if not ok then state.inFlight = false; error(accepted) end
    return accepted
end

local function killMessage(payload)
    if type(payload) ~= "table" then error("Kill payload required") end
    for key in pairs(payload) do if key ~= "count" then error("Unknown kill payload field") end end
    local count = payload.count
    if type(count) ~= "number" or count < 1 or count > 2147483647 or count ~= math.floor(count) then
        error("Positive integer kill count required")
    end
    return ApocBREntities.newMessageId(), '{"count":' .. string.format("%.0f", count) .. '}'
end

local function vehicleSpawnFailure(payload)
    if type(payload) ~= "table" then error("Vehicle failure payload required") end
    local requestId, steamId = payload.requestId, payload.steamId
    local id = type(requestId) == "string" and requestId:match("^car%-(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)$")
    if not id or type(steamId) ~= "string" or #steamId ~= 17 or not steamId:match("^[1-9]%d+$")
            or (payload.stage ~= "rejected" and payload.stage ~= "spawn") or type(payload.reviewRequired) ~= "boolean" then
        error("Invalid vehicle failure payload")
    end
    return id, ApocBREntities.encode({
        requestId = requestId, steamId = steamId, stage = payload.stage, reviewRequired = payload.reviewRequired,
    })
end

-- Explicit allowlist. Add future contracts here rather than accepting arbitrary commands.
local messagesByType = {
    ["ZombieKillsRecorded.v1"] = killMessage,
    ["VehiclePurchaseSpawnFailed.v1"] = vehicleSpawnFailure,
}

function API.publish(eventType, playerContext, payload, callback)
    if type(callback) ~= "function" then error("Publication callback required") end
    if not playerContext or playerContext.status ~= "OK" then error("Trusted player context required") end
    local prepare = messagesByType[eventType]
    if not prepare then error("Unsupported backend event") end
    local id, body = prepare(payload)
    local publication = setmetatable({}, Publication)
    publications[publication] = {
        id = id, context = { token = playerContext.token },
        values = { event_type = eventType, payload = body },
    }
    publication:retry(callback)
    return publication
end

Events.OnServerStarted.Add(function()
    local ok, failure = pcall(function()
        messages():validate(function(result)
            print("[ApocBR/BackendMessages] schema validation " .. tostring(result.status))
        end)
    end)
    if not ok then print("[ApocBR/BackendMessages] validation unavailable: " .. tostring(failure)) end
end)

return API
