local Notifier = require("AdaptiveTraits/Notifier")

local M = {}

M.addTrait = function(player, trait, positive)
    if player:hasTrait(trait) then
        return
    end
    if isClient() then
        sendClientCommand(player, "AdaptiveTraits", "addTrait", {
            traitId = trait:toString(),
            positive = positive,
        })
        return
    end
    local traits = player:getCharacterTraits()
    traits:add(trait)
    local definition = CharacterTraitDefinition.getCharacterTraitDefinition(trait)
    local xpBoosts = transformIntoKahluaTable(definition:getXpBoosts())
    local xp = player:getXp()
    for perk, boost in pairs(xpBoosts) do
        xp:setPerkBoost(perk, boost)
    end
    local grantedRecipes = definition:getGrantedRecipes()
    local knownRecipes = player:getKnownRecipes()
    for i = 0, grantedRecipes:size() - 1 do
        local recipe = grantedRecipes:get(i)
        if not knownRecipes:contains(recipe) then
            knownRecipes:add(recipe)
        end
    end
    if isServer() then
        sendServerCommand(player, "AdaptiveTraits", "traitAdded", {
            traitId = trait:toString(),
            positive = positive,
        })
    else
        Notifier.notify(player, trait, true, positive)
    end
end

M.removeTrait = function(player, trait, positive)
    if not player:hasTrait(trait) then
        return
    end
    if isClient() then
        sendClientCommand(player, "AdaptiveTraits", "removeTrait", {
            traitId = trait:toString(),
            positive = positive,
        })
        return
    end
    local traits = player:getCharacterTraits()
    traits:remove(trait)
    if trait == CharacterTrait.SMOKER then
        local stats = player:getStats()
        stats:reset(CharacterStat.NICOTINE_WITHDRAWAL)
    end
    if isServer() then
        sendServerCommand(player, "AdaptiveTraits", "traitRemoved", {
            traitId = trait:toString(),
            positive = positive,
        })
    else
        Notifier.notify(player, trait, false, positive)
    end
end

return M
