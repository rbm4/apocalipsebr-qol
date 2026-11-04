if not isServer() then return end
require "BeyondTen/Shared"
require "BeyondTen/ServerMasteryService"

BeyondTenServerController = BeyondTenServerController or {}
local Controller = BeyondTenServerController
local lastSync = setmetatable({}, { __mode = "k" })
local handlers

function Controller.OnClientCommand(module, command, player, _args)
    if module ~= BeyondTen.MODULE or command ~= "RequestSync" or not player or player:isDead() then return end
    local now = getTimestampMs()
    if lastSync[player] and now - lastSync[player] < 1000 then return end
    lastSync[player] = now
    BeyondTenServerMasteryService.RequestSync(player, handlers.getState(player))
end

function Controller.Install(callbacks)
    handlers = callbacks
    if Controller._installed then return end
    Controller._installed = true
    Events.OnClientCommand.Add(Controller.OnClientCommand)
end

return Controller
