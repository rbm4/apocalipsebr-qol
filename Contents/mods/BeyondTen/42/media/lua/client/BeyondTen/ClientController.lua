require "BeyondTen/Shared"
require "BeyondTen/ClientMasteryService"

BeyondTenClientController = BeyondTenClientController or {}
local Controller = BeyondTenClientController

function Controller.RequestSync(player)
    if isClient() and BeyondTenClientMasteryService.ShouldRequestSync(player) then
        -- No character UUID, XP value, repository name or database operation is sent.
        sendClientCommand(player, BeyondTen.MODULE, "RequestSync", {})
    end
end

function Controller.OnServerCommand(module, command, args)
    if module ~= BeyondTen.MODULE or type(args) ~= "table" then return end
    if command ~= "Sync" and command ~= "SyncPerk" then return end
    local onlineID = tonumber(args.player)
    if onlineID == nil then return end
    for index = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(index)
        if player and tonumber(player:getOnlineID()) == onlineID then
            BeyondTenClientMasteryService.Apply(player, command, args)
            return
        end
    end
end

if not Controller._installed then
    Controller._installed = true
    Events.OnServerCommand.Add(Controller.OnServerCommand)
end

return Controller
