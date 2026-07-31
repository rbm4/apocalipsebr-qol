local Utils = require("AdaptiveTraits/Utils")
local Manager = require("AdaptiveTraits/Manager")

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "AdaptiveTraits" then
        return
    end
    if command == "addTrait" then
        local trait = Utils.getTraitById(args.traitId)
        if trait then
            Manager.addTrait(player, trait, args.positive)
        end
    elseif command == "removeTrait" then
        local trait = Utils.getTraitById(args.traitId)
        if trait then
            Manager.removeTrait(player, trait, args.positive)
        end
    end
end)
