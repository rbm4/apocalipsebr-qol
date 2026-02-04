--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

DAMN = DAMN or {}
DAMN.OnCreate = {}
DAMN.OnGiveXP = {}
DAMN.OnTest = {}

--XP functions

function DAMN.OnGiveXP.Mechanics2(recipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Mechanics, 2);
end

function DAMN.OnGiveXP.Mechanics5(recipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Mechanics, 5);
end

function DAMN.OnGiveXP.Mechanics10(recipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Mechanics, 10);
end

function DAMN.OnGiveXP.Mechanics15(recipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Mechanics, 15);
end

function DAMN.OnGiveXP.Mechanics20(recipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Mechanics, 20);
end

function DAMN.OnGiveXP.Tailoring10(recipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Tailoring, 10);
end

--Misc

function DAMN.OnCreate.OpenSchematicsBox(items, result, player, selectedItem)

    player:getInventory():AddItem("damnCraft.DoorSchematics");
    player:getInventory():AddItem("damnCraft.HoodSchematics");
    player:getInventory():AddItem("damnCraft.TrunkLidSchematics");
    player:getInventory():AddItem("damnCraft.SeatSchematics");
    player:getInventory():AddItem("damnCraft.RimSchematics");
    player:getInventory():AddItem("damnCraft.MufflerSchematics");
    player:getInventory():AddItem("damnCraft.BumperSchematics");
    player:getInventory():AddItem("damnCraft.BodyworkSchematics");

end

--Tires

function DAMN.OnCreate.DismantleTireSmall(items, result, player, selectedItem)

	local addType = "damnCraft.TireRubberDestroyedSmall"
    local tireCond = selectedItem:getCondition();

    if tireCond < 26 then
        addType = "damnCraft.TireRubberDestroyedSmall"

    elseif tireCond < 81 then
        addType = "damnCraft.TireRubberUsedSmall"
    else
        addType = "damnCraft.TireRubberNewSmall"
    end

    local tire = player:getInventory():AddItem(addType);
    tire:setCondition(tireCond)
    player:getXp():AddXP(Perks.Mechanics, 3);

end

function DAMN.OnCreate.DismantleTireLarge(items, result, player, selectedItem)

    local addType = "damnCraft.TireRubberDestroyedLarge"
    local tireCond = selectedItem:getCondition();

    if tireCond < 26 then
        addType = "damnCraft.TireRubberDestroyedLarge"

    elseif tireCond < 81 then
        addType = "damnCraft.TireRubberUsedLarge"
    else
        addType = "damnCraft.TireRubberNewLarge"
    end

    local tire = player:getInventory():AddItem(addType);
    tire:setCondition(tireCond)
    player:getXp():AddXP(Perks.Mechanics, 3);

end

function DAMN.OnCreate.MakeRubberStrips(items, result, player, selectedItem)

    local tireCond = selectedItem:getCondition();

    if tireCond < 26 then
        player:getInventory():AddItem("damnCraft.RubberStrip");
    elseif tireCond < 81 then
        player:getInventory():AddItem("damnCraft.RubberStrip");
        player:getInventory():AddItem("damnCraft.RubberStrip");
        player:getInventory():AddItem("damnCraft.RubberStrip");
    else
        player:getInventory():AddItem("damnCraft.RubberStrip");
        player:getInventory():AddItem("damnCraft.RubberStrip");
        player:getInventory():AddItem("damnCraft.RubberStrip");
        player:getInventory():AddItem("damnCraft.RubberStrip");
        player:getInventory():AddItem("damnCraft.RubberStrip");
        player:getInventory():AddItem("damnCraft.RubberStrip");
    end
    player:getXp():AddXP(Perks.Mechanics, 2);

end

function DAMN.OnCreate.MakeLargeTire(items, result, player, selectedItem)

    for i=0, items:size()-1 do
        local itemCond = 0;

       if items:get(i):getType() == "TireRubberDestroyedLarge" or items:get(i):getType() == "TireRubberUsedLarge" or items:get(i):getType() == "TireRubberNewLarge" then
            itemCond = items:get(i):getCondition();
       end

       result:setCondition(itemCond);
       player:getXp():AddXP(Perks.Mechanics, 2);
    end

end

function DAMN.OnCreate.MakeSmallTire(items, result, player, selectedItem)

    for i=0, items:size()-1 do
        local itemCond = 0;

       if items:get(i):getType() == "TireRubberDestroyedSmall" or items:get(i):getType() == "TireRubberUsedSmall" or items:get(i):getType() == "TireRubberNewSmall" then
            itemCond = items:get(i):getCondition();
       end

       result:setCondition(itemCond);
       player:getXp():AddXP(Perks.Mechanics, 2);
    end

end

--Axles

function DAMN.OnCreate.Dismantle2LargeTires(items, result, player, selectedItem)

    local addType = "runFlat.LargeTire"
    local tireCond = selectedItem:getCondition();

    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getXp():AddXP(Perks.Mechanics, 4);

end

function DAMN.OnCreate.Dismantle4LargeTires(items, result, player, selectedItem)

    local addType = "runFlat.LargeTire"
    local tireCond = selectedItem:getCondition();

    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getXp():AddXP(Perks.Mechanics, 4);

end

function DAMN.OnCreate.Dismantle4MediumTires(items, result, player, selectedItem)

    local addType = "runFlat.MediumTire"
    local tireCond = selectedItem:getCondition();

    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getXp():AddXP(Perks.Mechanics, 4);

end

function DAMN.OnCreate.MakeDouble(items, result, player, selectedItem)

    local allCond = 0

    for i = 1, items:size() - 1
    do
        allCond = allCond + items:get(i):getCondition();
    end

    result:setCondition(allCond / 2);
end

function DAMN.OnCreate.Make2Axle(items, result, player, selectedItem)

    local allCond = 0

    for i = 3, items:size() - 1
    do
        allCond = allCond + items:get(i):getCondition();
    end

    result:setCondition(allCond / 2);
end

function DAMN.OnCreate.Make4Axle(items, result, player, selectedItem)

    local allCond = 0

    for i = 3, items:size() - 1
    do
        allCond = allCond + items:get(i):getCondition();
    end

    local tempResult = (allCond / 4);

    if tempResult > 100 then result:setCondition(100);
        else result:setCondition(tempResult);
    end
end

--Rim

function DAMN.OnCreate.DismantleRim(items, result, player, selectedItem)

    local chance = ZombRandBetween(0,100);

    if chance < 41 then
        player:getInventory():AddItem("Base.ScrapMetal");
        player:getXp():AddXP(Perks.MetalWelding, 1);
    elseif chance < 82 then
        player:getInventory():AddItem("Base.ScrapMetal");
        player:getInventory():AddItem("Base.ScrapMetal");
        player:getXp():AddXP(Perks.MetalWelding, 2);
    else
        player:getInventory():AddItem("Base.ScrapMetal");
        player:getInventory():AddItem("Base.ScrapMetal");
        player:getInventory():AddItem("Base.ScrapMetal");
        player:getInventory():AddItem("Base.ScrapMetal");
        player:getXp():AddXP(Perks.MetalWelding, 3);
    end

end

--Hood

function DAMN.OnCreate.DismantleHood(items, result, player, selectedItem)

    local hoodCond = selectedItem:getCondition();

    if hoodCond < 10 then
        player:getInventory():AddItem("Base.ScrapMetal");
        player:getXp():AddXP(Perks.MetalWelding, 1);
    elseif hoodCond < 76 then
        player:getInventory():AddItem("Base.ScrapMetal");
        player:getInventory():AddItem("damnCraft.HingeLarge");
        player:getInventory():AddItem("Base.Screws");
        player:getXp():AddXP(Perks.MetalWelding, 3);
    else
        player:getInventory():AddItem("damnCraft.HingeLarge");
        player:getInventory():AddItem("damnCraft.HingeLarge");
        player:getInventory():AddItem("Base.Screws");
        player:getInventory():AddItem("Base.Screws");
        player:getXp():AddXP(Perks.MetalWelding, 5);
    end

end

--Trunk Lid

function DAMN.OnCreate.DismantleTrunkLid(items, result, player, selectedItem)

    local trunkLidCond = selectedItem:getCondition();

    if trunkLidCond < 10 then
        player:getInventory():AddItem("Base.ScrapMetal");
        player:getXp():AddXP(Perks.MetalWelding, 1);
    elseif trunkLidCond < 76 then
        player:getInventory():AddItem("Base.ScrapMetal");
        player:getInventory():AddItem("damnCraft.HingeLarge");
        player:getInventory():AddItem("Base.Screws");
        player:getXp():AddXP(Perks.MetalWelding, 3);
    else
        player:getInventory():AddItem("damnCraft.HingeLarge");
        player:getInventory():AddItem("damnCraft.HingeLarge");
        player:getInventory():AddItem("Base.Screws");
        player:getInventory():AddItem("Base.Screws");
        player:getXp():AddXP(Perks.MetalWelding, 5);
    end

end

--Windows

function DAMN.OnCreate.DismantleWindshield(items, result, player, selectedItem)

    local windshieldCond = selectedItem:getCondition();

    if windshieldCond < 10 then
        player:getInventory():AddItem("damnCraft.RubberStrip");
    elseif windshieldCond < 76 then
        player:getInventory():AddItem("damnCraft.RubberStrip");
        player:getInventory():AddItem("damnCraft.GlassPaneSmall");
    else
        player:getInventory():AddItem("damnCraft.RubberStrip");
        player:getInventory():AddItem("damnCraft.GlassPaneLarge");
    end

end

function DAMN.OnCreate.DismantleWindow(items, result, player, selectedItem)

    local windowCond = selectedItem:getCondition();

    if windowCond < 76 then
        player:getInventory():AddItem("damnCraft.RubberStrip");
    else
        player:getInventory():AddItem("damnCraft.RubberStrip");
        player:getInventory():AddItem("damnCraft.GlassPaneSmall");
    end

end

function DAMN.OnCreate.PackViewports(items, result, player, selectedItem)

    local allCond = 0

    for i = 1, items:size() - 1
    do
        allCond = allCond + items:get(i):getCondition();
    end

    result:setCondition(allCond / items:size());
    
end 

function DAMN.OnCreate.UnpackLargeViewports(items, result, player, selectedItem)

    local addType = "USMIL.LargeViewport0"
    local tireCond = selectedItem:getCondition();

    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getXp():AddXP(Perks.Mechanics, 1);

end

function DAMN.OnCreate.UnpackSmallViewports(items, result, player, selectedItem)

    local addType = "USMIL.SmallViewport0"
    local tireCond = selectedItem:getCondition();

    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getInventory():AddItem(addType):setCondition(tireCond);
    player:getXp():AddXP(Perks.Mechanics, 1);

end

function DAMN.OnCreate.CombineSmallGlassPanes(items, result, player, selectedItem)

    local allCond = 0

    for i = 1, items:size() - 1
    do
        allCond = allCond + items:get(i):getCondition();
        print (allCond)
    end

    print (allCond);
    result:setCondition(allCond / 2);
    
end 

function DAMN.OnCreate.CutLargeGlassPane(items, result, player, selectedItem)

    local addType = "damnCraft.GlassPaneSmall"
    local tireCond = selectedItem:getCondition();

    player:getInventory():AddItem(addType):setCondition(tireCond);
    result:setCondition(tireCond);
    player:getXp():AddXP(Perks.Mechanics, 1);

end

--Door

function DAMN.OnCreate.DismantleDoor(items, result, player, selectedItem)

    local doorCond = selectedItem:getCondition();

    if doorCond < 10 then
        player:getInventory():AddItem("Base.ScrapMetal");
        player:getInventory():AddItem("damnCraft.HingeSmall");
        player:getXp():AddXP(Perks.MetalWelding, 1);
    elseif doorCond < 80 then
        player:getInventory():AddItem("Base.ScrapMetal");
        player:getInventory():AddItem("damnCraft.HingeSmall");
        player:getInventory():AddItem("damnCraft.HandleModern");
        player:getInventory():AddItem("Base.Screws");
        player:getXp():AddXP(Perks.MetalWelding, 3);
    else
        player:getInventory():AddItem("damnCraft.HingeSmall");
        player:getInventory():AddItem("damnCraft.HingeSmall");
        player:getInventory():AddItem("damnCraft.RubberStrip");
        player:getInventory():AddItem("Base.Wire");
        player:getInventory():AddItem("damnCraft.HandleModern");
        player:getInventory():AddItem("Base.Screws");
        player:getInventory():AddItem("Base.Screws");
        player:getXp():AddXP(Perks.MetalWelding, 5);
    end

end

--Seat

function DAMN.OnCreate.DismantleSeat(items, result, player, selectedItem)

    player:getInventory():AddItem("damnCraft.SeatFabric");
    player:getInventory():AddItem("damnCraft.SeatFoam");
    player:getInventory():AddItem("Base.Screws");

end

--Tire Repair Kit

function DAMN.OnCreate.OpenTireRepairKit(items, result, player, selectedItem)

    player:getInventory():AddItem("damnCraft.TireRepairRubberSolution");
    player:getInventory():AddItem("damnCraft.TireRepairStrips");

end

function DAMN.OnCreate.RepairTire(items, result, player, selectedItem, sourceItem)

    local itemName = selectedItem:getFullType();
    local tireCond = selectedItem:getCondition();
    local playerSkill = player:getPerkLevel(Perks.Mechanics);
    local maxCond = selectedItem:getConditionMax();

    local tire = player:getInventory():AddItem(itemName);
    local newCond = tireCond + (ZombRand((2 + playerSkill * 5), (5 + playerSkill * 10)));

        if newCond > maxCond then tire:setCondition(maxCond);
        else tire:setCondition(newCond);
        end

end

--Plastic Welding Kit

function DAMN.OnCreate.OpenPlasticWeldingKit(items, result, player, selectedItem)

    player:getInventory():AddItem("damnCraft.PlasticWeldingStaples100Pack");

end

function DAMN.OnTest.PlasticWeldingGunBatteryInsert(sourceItem, result)
    if sourceItem:getType() == "damnCraft.PlasticWeldingGun" then
        return sourceItem:getUsedDelta() == 0;
    end
    return true
end

function DAMN.OnCreate.PlasticWeldingGunBatteryInsert(items, result, player)

    for i=0, items:size()-1 do
    if items:get(i):getType() == "Battery" then
        result:setUsedDelta(items:get(i):getUsedDelta());
    end
  end
end

function DAMN.OnTest.PlasticWeldingGunBatteryRemoval(sourceItem, result)
    return sourceItem:getUsedDelta() > 0;
end

function DAMN.OnCreate.PlasticWeldingGunBatteryRemoval(items, result, player)

    for i=0, items:size()-1 do
        local item = items:get(i)
        if item:getFullType() == "damnCraft.PlasticWeldingGun"  then
            result:setUsedDelta(item:getUsedDelta());
            item:setUsedDelta(0);
        end
    end

end

--Mounts

function DAMN.OnCreate.MountSmallTire(items, result, player, selectedItem)

     for i=0, items:size()-1 do
        local itemCond = 0;

       if items:get(i):getType() == "TireRubberDestroyedSmall" or items:get(i):getType() == "TireRubberUsedSmall" or items:get(i):getType() == "TireRubberNewSmall" then
            itemCond = items:get(i):getCondition();
       end

       result:setCondition(itemCond);
       player:getXp():AddXP(Perks.Mechanics, 2);
    end

end

function DAMN.OnCreate.MountLargeTire(items, result, player, selectedItem)

     for i=0, items:size()-1 do
        local itemCond = 0;

       if items:get(i):getType() == "TireRubberDestroyedLarge" or items:get(i):getType() == "TireRubberUsedLarge" or items:get(i):getType() == "TireRubberNewLarge" then
            itemCond = items:get(i):getCondition();
       end

       result:setCondition(itemCond);
       player:getXp():AddXP(Perks.Mechanics, 2);
    end

end

function DAMN.OnCreate.DismantleWoodenArmor(items, result, player, selectedItem)

	local armorCond = selectedItem:getCondition();

	if armorCond < 26 then
    	player:getInventory():AddItem("Base.UnusableWood");
    elseif armorCond < 81 then
    	player:getInventory():AddItem("Base.Plank");
    	player:getInventory():AddItem("Base.UnusableWood");
    	player:getInventory():AddItem("Base.Nails");
    	player:getInventory():AddItem("Base.Nails");
    else
    	player:getInventory():AddItem("Base.Plank");
        player:getInventory():AddItem("Base.Plank");
    	player:getInventory():AddItem("Base.UnusableWood");
    	player:getInventory():AddItem("Base.Nails");
    	player:getInventory():AddItem("Base.Nails");
    	player:getInventory():AddItem("Base.Nails");
    end
    selectedItem:setCondition(armorCond);
    player:getXp():AddXP(Perks.Woodwork, 3);

end