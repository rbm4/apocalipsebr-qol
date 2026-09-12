-- Lightweight admin helper surface for v0.8.x pre-age jobs.
-- These functions send server-verified commands; the server still checks access.
local PreAgeClient = {}

local function send(action, args)
    args = type(args) == "table" and args or {}
    args.action = action
    if type(sendClientCommand) == "function" then
        sendClientCommand("A10YL", "preage", args)
        return true
    end
    print("[A10YL][PREAGE] sendClientCommand is unavailable in this runtime")
    return false
end

function PreAgeClient.radius(radiusChunks)
    return send("radius", { radius = tonumber(radiusChunks) or 12 })
end

function PreAgeClient.cell(cellX, cellY)
    return send("cell", { cellX = tonumber(cellX), cellY = tonumber(cellY) })
end

function PreAgeClient.chunkRadius(wx, wy, radiusChunks)
    return send("chunk-radius", {
        wx = tonumber(wx),
        wy = tonumber(wy),
        radius = tonumber(radiusChunks) or 12,
    })
end

function PreAgeClient.status()
    return send("status", {})
end

function PreAgeClient.pause()
    return send("pause", {})
end

function PreAgeClient.resume()
    return send("resume", {})
end

function PreAgeClient.stop()
    return send("stop", {})
end

function PreAgeClient.help()
    return send("help", {})
end

function PreAgeClient.route(fromTown, toTown)
    return send("route", { from = tostring(fromTown or ""), to = tostring(toTown or "") })
end

function PreAgeClient.disableAgeing()
    return send("disable-ageing", {})
end

function PreAgeClient.enableAgeing()
    return send("enable-ageing", {})
end

local function onServerCommand(module, command, args)
    if module ~= "A10YL" or command ~= "preageStatus" then return end
    args = type(args) == "table" and args or {}
    print("[A10YL][PREAGE] " .. tostring(args.message or "status received"))
end

if Events and Events.OnServerCommand and Events.OnServerCommand.Add then
    Events.OnServerCommand.Add(onServerCommand)
end

A10YLPreAge = PreAgeClient
return PreAgeClient
