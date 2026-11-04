require "BeyondTen/Shared"

BeyondTenClientMasteryService = BeyondTenClientMasteryService or {}
local Service = BeyondTenClientMasteryService
local requests = setmetatable({}, { __mode = "k" })

function Service.ShouldRequestSync(player)
    local state = requests[player]
    local now = getTimestampMs()
    if state and (state.ready or now < state.retryAt) then return false end
    requests[player] = { retryAt = now + 5000 }
    return true
end

function Service.Apply(player, command, args)
    if command == "Sync" and type(args.perks) == "table" then
        requests[player] = { ready = true }
        BeyondTenClient.ApplyFullSync(player, args.perks)
    elseif command == "SyncPerk" then
        BeyondTenClient.ApplyPerkSync(player, args.perk, args.xp)
    end
end

return Service
