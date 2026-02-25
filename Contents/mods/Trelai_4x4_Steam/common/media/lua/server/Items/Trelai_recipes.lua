require "Recipecode"
require "XpSystem/XpUpdate"

DBZRecipe = {}
DBZRecipe.OnGiveXP = {}

--Define XP for crafting dragonballs   Xp Multiplayer? 250 = 25? 100 = 100?

function DBZRecipe.OnGiveXP.Fitness1000000(DBZRecipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Fitness, 1000000);
end

function DBZRecipe.OnGiveXP.Strength1000000(DBZRecipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Strength, 1000000);
end

function DBZRecipe.OnGiveXP.MetalWelding1000(DBZRecipe, ingredients, result, player)
    player:getXp():AddXP(Perks.MetalWelding, 1000);
end
