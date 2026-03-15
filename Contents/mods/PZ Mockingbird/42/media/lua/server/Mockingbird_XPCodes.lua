Recipe = Recipe or {}
Recipe.OnCreate = Recipe.OnCreate or {}
--[[
Recipe.OnGiveXP = Recipe.OnGiveXP or {}

function Recipe.OnGiveXP.DismantleModernTV(recipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Electricity, 5);
end

Give5ElectricityXP = Recipe.OnGiveXP.DismantleModernTV
--]]
function Recipe.OnCreate.DismantleModernTV(recipe, ingredients, result, player)
    local success = 50 + (player:getPerkLevel(Perks.Electricity)*5);
    for i=1,ZombRand(1,6) do
        local r = ZombRand(1,4);
        if r==1 then
            player:getInventory():AddItem("Base.ElectronicsScrap");
        elseif r==2 then
            player:getInventory():AddItem("Radio.ElectricWire");
        elseif r==3 then
            player:getInventory():AddItem("Base.Aluminum");
        end
    end
    if ZombRand(0,100)<success then
        player:getInventory():AddItem("Base.Amplifier");
        player:getInventory():AddItem("Base.LightBulb");
        player:getInventory():AddItem("Base.LightBulbRed");
		player:getInventory():AddItem("Base.LightBulbGreen");
    end
end

DismantleModernTVOnCreate = Recipe.OnCreate.DismantleModernTV