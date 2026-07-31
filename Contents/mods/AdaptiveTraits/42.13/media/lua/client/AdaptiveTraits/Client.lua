local Registry = require("AdaptiveTraits/Registry")
local Utils = require("AdaptiveTraits/Utils")
local Notifier = require("AdaptiveTraits/Notifier")

Events.EveryOneMinute.Add(function()
    local entries = Registry.getEntries()
    local player = getPlayer()
    for _, entry in pairs(entries) do
        entry.update(player)
    end
end)

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "AdaptiveTraits" then
        return
    end
    if command == "traitAdded" then
        local player = getPlayer()
        local trait = Utils.getTraitById(args.traitId)
        if trait then
            Notifier.notify(player, trait, true, args.positive)
        end
    elseif command == "traitRemoved" then
        local player = getPlayer()
        local trait = Utils.getTraitById(args.traitId)
        if trait then
            Notifier.notify(player, trait, false, args.positive)
        end
    end
end)
