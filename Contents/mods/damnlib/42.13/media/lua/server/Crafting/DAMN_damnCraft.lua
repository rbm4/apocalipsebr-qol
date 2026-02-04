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

--Packing... heat

function DAMN.OnCreate.PackStuff(craftRecipeData, character)

    local allCond = 0;
    local items = craftRecipeData:getAllConsumedItems();
    local result = craftRecipeData:getAllCreatedItems():get(0);

    for i=0,items:size() - 1 do
        allCond = allCond + items:get(i):getCondition()
    end

    local averageCond = allCond / items:size();

    if averageCond > 100 then
        averageCond = 100
    end

    result:setCondition(averageCond)
    
end 

function DAMN.OnCreate.UnpackStuff(craftRecipeData, character)

    local item = craftRecipeData:getAllConsumedItems():get(0);
    local itemCond = item:getCondition();
    local results = craftRecipeData:getAllCreatedItems();

    for i = 0, results:size() - 1 do
        results:get(i):setCondition(itemCond)
    end

end

function DAMN.OnCreate.PassSecondCond(craftRecipeData, character)

    local item = craftRecipeData:getAllConsumedItems():get(1);
    local itemCond = item:getCondition();
    local result = craftRecipeData:getAllCreatedItems():get(0);

    result:setCondition(itemCond)

end

function DAMN.OnCreate.CombineFirstTwo(craftRecipeData, character)

    local allCond = 0;
    local items = craftRecipeData:getAllConsumedItems();
    local result = craftRecipeData:getAllCreatedItems():get(0);

    for i = 0, 1 do
        if i < items:size() then
            allCond = allCond + items:get(i):getCondition()
        end
    end

    local averageCond = allCond / 2

    if averageCond > 100 then
        averageCond = 100
    end

    result:setCondition(averageCond)
    
end

function DAMN.OnCreate.CombineFirstFour(craftRecipeData, character)

    local allCond = 0;
    local items = craftRecipeData:getAllConsumedItems();
    local result = craftRecipeData:getAllCreatedItems():get(0);

    for i = 0, 3 do
        if i < items:size() then
            allCond = allCond + items:get(i):getCondition()
        end
    end

    local averageCond = allCond / 4

    if averageCond > 100 then
        averageCond = 100
    end

    result:setCondition(averageCond)
    
end

--Rubber

function DAMN.OnCreate.MakeRubberStrips(craftRecipeData, character)

    local item = craftRecipeData:getAllConsumedItems():get(0);
    local tireCond = item:getCondition();

    if tireCond < 26 then
        DAMN:addItemsToPlayerInventory({itemId = "damnCraft.RubberStrip",}, "DAMN.OnCreate.MakeRubberStrips", character);
    elseif tireCond < 81 then
        DAMN:addItemsToPlayerInventory({itemId = "damnCraft.RubberStrip", amount = 3,}, "DAMN.OnCreate.MakeRubberStrips", character);
    else
        DAMN:addItemsToPlayerInventory({itemId = "damnCraft.RubberStrip", amount = 6,}, "DAMN.OnCreate.MakeRubberStrips", character);
    end

end

--Scrap metal

function DAMN.OnCreate.GetScrapMetal(craftRecipeData, character)

    local chance = ZombRandBetween(0,100);

    if chance < 41 then
        DAMN:addItemsToPlayerInventory({itemId = "Base.ScrapMetal",}, "DAMN.OnCreate.GetScrapMetal", character);
    elseif chance < 82 then
        DAMN:addItemsToPlayerInventory({itemId = "Base.ScrapMetal", amount = 2,}, "DAMN.OnCreate.GetScrapMetal", character);
    else
        DAMN:addItemsToPlayerInventory({itemId = "Base.ScrapMetal", amount = 4,}, "DAMN.OnCreate.GetScrapMetal", character);
    end

end

--Tire Repair Kit

function DAMN.OnCreate.RepairTireOne(craftRecipeData, character)

    DAMN.RepairTire(craftRecipeData, character, 1, craftRecipeData:getFirstInputItemWithFlag("IsDamaged"))

end

function DAMN.OnCreate.RepairTireTwo(craftRecipeData, character)

    DAMN.RepairTire(craftRecipeData, character, 2, craftRecipeData:getFirstInputItemWithFlag("IsDamaged"))

end

function DAMN.OnCreate.RepairTireFour(craftRecipeData, character)

    DAMN.RepairTire(craftRecipeData, character, 4, craftRecipeData:getFirstInputItemWithFlag("IsDamaged"))

end

function DAMN.RepairTire(craftRecipeData, character, amount, item, skill)

    if not item then item = craftRecipeData:getFirstInputItemWithFlag("IsDamaged") end
    if not amount then amount = 1 end
    if not character then character = craftRecipeData:getPlayer() end
    if not skill then skill  = character:getPerkLevel(Perks.Mechanics); end

    local tireCond = item:getCondition();
    local maxCond = item:getConditionMax();

    local newCond = tireCond + (ZombRand((2 + skill * 5), (5 + skill * 10)));

        if newCond > maxCond then item:setCondition(maxCond);
        else item:setCondition(newCond);
        end
        item:syncItemFields();

end

--Dismantling

function DAMN.OnCreate.DismantleTireSmallMounted(craftRecipeData, character)

    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()
    local addType

    if itemCond < 26 then
        addType = "damnCraft.TireRubberDestroyedSmall"
    elseif itemCond < 81 then
        addType = "damnCraft.TireRubberUsedSmall"
    else
        addType = "damnCraft.TireRubberNewSmall"
    end

    DAMN:addItemsToPlayerInventory({
        itemId = addType,
        condition = itemCond,
    }, "DAMN.OnCreate.DismantleTireSmallMounted", character)

end


function DAMN.OnCreate.DismantleTireLargeMounted(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()
    local addType

    if itemCond < 26 then
        addType = "damnCraft.TireRubberDestroyedLarge"
    elseif itemCond < 81 then
        addType = "damnCraft.TireRubberUsedLarge"
    else
        addType = "damnCraft.TireRubberNewLarge"
    end

    DAMN:addItemsToPlayerInventory({
        itemId = addType,
        condition = itemCond,
    }, "DAMN.OnCreate.DismantleTireLargeMounted", character)
end

--Recycling

function DAMN.OnCreate.DismantleTireSmall(craftRecipeData, character)

    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()
    local addType

    if itemCond < 26 then
        addType = "damnCraft.TireRubberDestroyedSmall"
    elseif itemCond < 81 then
        addType = "damnCraft.TireRubberUsedSmall"
    else
        addType = "damnCraft.TireRubberNewSmall"
    end

    DAMN:addItemsToPlayerInventory({
        itemId = addType,
        condition = itemCond,
    }, "DAMN.OnCreate.DismantleTireSmall", character)

end


function DAMN.OnCreate.DismantleTireLargeMedium(craftRecipeData, character)

    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()
    local addType

    if itemCond < 26 then
        addType = "damnCraft.TireRubberDestroyedLarge"
    elseif itemCond < 81 then
        addType = "damnCraft.TireRubberUsedLarge"
    else
        addType = "damnCraft.TireRubberNewLarge"
    end

    DAMN:addItemsToPlayerInventory({
        itemId = addType,
        condition = itemCond,
    }, "DAMN.OnCreate.DismantleTireLargeMedium", character)

end


function DAMN.OnCreate.DismantleHood(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({itemId = "Base.ScrapMetal",}, "DAMN.OnCreate.DismantleHood", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({itemId = "Base.ScrapMetal", amount = 3,}, "DAMN.OnCreate.DismantleHood", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.HingeLarge", amount = 2,}, {itemId = "Base.Screws",}, {itemId = "Base.SheetMetal",}}, "DAMN.OnCreate.DismantleHood", character);
    end
end

function DAMN.OnCreate.DismantleTrunkLid(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({itemId = "Base.ScrapMetal",}, "DAMN.OnCreate.DismantleTrunkLid", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}, {itemId = "damnCraft.HingeLarge",}, {itemId = "Base.Screws",}}, "DAMN.OnCreate.DismantleTrunkLid", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.HingeLarge", amount = 2,}, {itemId = "Base.Screws",}, {itemId = "Base.SheetMetal",}}, "DAMN.OnCreate.DismantleTrunkLid", character);
    end
end

function DAMN.OnCreate.DismantleTrunkLids(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({itemId = "Base.ScrapMetal",}, "DAMN.OnCreate.DismantleTrunkLids", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.HingeLarge", amount = 2,}, {itemId = "Base.Screws",}, {itemId = "Base.ScrapMetal",}}, "DAMN.OnCreate.DismantleTrunkLids", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.HingeLarge", amount = 4,}, {itemId = "Base.Screws", amount = 2,}, {itemId = "Base.SheetMetal", amount = 2,}}, "DAMN.OnCreate.DismantleTrunkLids", character);
    end
end

function DAMN.OnCreate.DismantleDoorModern(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.HingeSmall",}, {itemId = "Base.ScrapMetal",}}, "DAMN.OnCreate.DismantleDoorModern", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.HingeSmall",}, {itemId = "Base.ScrapMetal",}, {itemId = "damnCraft.HandleModern",}, {itemId = "Base.Screws",}}, "DAMN.OnCreate.DismantleDoorModern", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.HingeSmall", amount = 2,}, {itemId = "Base.Wire",}, {itemId = "damnCraft.HandleModern",}, {itemId = "Base.Screws",}, {itemId = "Base.SheetMetal",}}, "DAMN.OnCreate.DismantleDoorModern", character);
    end
end

function DAMN.OnCreate.DismantleDoorClassic(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.HingeSmall",}, {itemId = "Base.ScrapMetal",}}, "DAMN.OnCreate.DismantleDoorClassic", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.HingeSmall",}, {itemId = "Base.ScrapMetal",}, {itemId = "damnCraft.HandleClassic",}, {itemId = "Base.Screws",}}, "DAMN.OnCreate.DismantleDoorClassic", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.HingeSmall", amount = 2,}, {itemId = "Base.Wire",}, {itemId = "damnCraft.HandleClassic",}, {itemId = "Base.Screws",}, {itemId = "Base.SheetMetal",}}, "DAMN.OnCreate.DismantleDoorClassic", character);
    end
end

function DAMN.OnCreate.DismantleWindshield(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.RubberStrip",}, {itemId = "Base.BrokenGlass",}}, "DAMN.OnCreate.DismantleWindshield", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.RubberStrip",}, {itemId = "Base.BrokenGlass",}, {itemId = "Base.GlassPanel",}}, "DAMN.OnCreate.DismantleWindshield", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.RubberStrip", amount = 2,}, {itemId = "Base.GlassPanel", amount = 2,}}, "DAMN.OnCreate.DismantleWindshield", character);
    end
end

function DAMN.OnCreate.DismantleWindow(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.BrokenGlass",}}, "DAMN.OnCreate.DismantleWindow", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.BrokenGlass",}}, "DAMN.OnCreate.DismantleWindow", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "Base.GlassPanel",}}, "DAMN.OnCreate.DismantleWindow", character);
    end
end

function DAMN.OnCreate.DismantleWoodenArmor(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 26 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.UnusableWood",}}, "DAMN.OnCreate.DismantleWoodenArmor", character);
    elseif itemCond < 70 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.Plank",}, {itemId = "Base.UnusableWood",}, {itemId = "Base.Nails", amount = 2,}}, "DAMN.OnCreate.DismantleWoodenArmor", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "Base.Plank", amount = 2}, {itemId = "Base.UnusableWood",}, {itemId = "Base.Nails", amount = 3,}}, "DAMN.OnCreate.DismantleWoodenArmor", character);
    end
end

function DAMN.OnCreate.DismantleMetalArmor(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}}, "DAMN.OnCreate.DismantleMetalArmor", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}, {itemId = "Base.MetalPipe",}, {itemId = "Base.Screws",}}, "DAMN.OnCreate.DismantleMetalArmor", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}, {itemId = "Base.MetalPipe",}, {itemId = "Base.SmallSheetMetal",}, {itemId = "Base.Screws",}}, "DAMN.OnCreate.DismantleMetalArmor", character);
    end
end

function DAMN.OnCreate.DismantleMudflaps(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 50 then
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.RubberStrip",}}, "DAMN.OnCreate.DismantleMudflaps", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.RubberStrip", amount = 2,}}, "DAMN.OnCreate.DismantleMudflaps", character);
    end
end

function DAMN.OnCreate.DismantleSidesteps(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}}, "DAMN.OnCreate.DismantleSidesteps", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}, {itemId = "Base.Screws",}}, "DAMN.OnCreate.DismantleSidesteps", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}, {itemId = "Base.SmallSheetMetal",}, {itemId = "Base.Screws",}}, "DAMN.OnCreate.DismantleSidesteps", character);
    end
end

function DAMN.OnCreate.DismantleMetalBumper(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}}, "DAMN.OnCreate.DismantleMetalBumper", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}, {itemId = "Base.SmallSheetMetal",}, {itemId = "Base.Screws",}}, "DAMN.OnCreate.DismantleMetalBumper", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}, {itemId = "Base.SmallSheetMetal", amount = 2,}, {itemId = "Base.Screws",}}, "DAMN.OnCreate.DismantleMetalBumper", character);
    end
end

function DAMN.OnCreate.DismantleMetalRoofrack(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}}, "DAMN.OnCreate.DismantleMetalRoofrack", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}, {itemId = "Base.MetalPipe",}, {itemId = "Base.Screws",}}, "DAMN.OnCreate.DismantleMetalRoofrack", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}, {itemId = "Base.MetalPipe", amount = 2,}, {itemId = "Base.Screws", amount = 2,}}, "DAMN.OnCreate.DismantleMetalRoofrack", character);
    end
end

function DAMN.OnCreate.DismantleToolbox(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}}, "DAMN.OnCreate.DismantleToolbox", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({{itemId = "Base.ScrapMetal",}, {itemId = "Base.Screws",}}, "DAMN.OnCreate.DismantleToolbox", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "Base.SheetMetal",}, {itemId = "Base.Screws",}}, "DAMN.OnCreate.DismantleToolbox", character);
    end
end

function DAMN.OnCreate.DismantleTarpSmall(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.RubberStrip",}}, "DAMN.OnCreate.DismantleTarpSmall", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.RubberStrip", amount = 2,}}, "DAMN.OnCreate.DismantleTarpSmall", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.RubberStrip",}, {itemId = "Base.Tarp",}}, "DAMN.OnCreate.DismantleTarpSmall", character);
    end
end

function DAMN.OnCreate.DismantleTarpLarge(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return end

    local itemCond = item:getCondition()

    if itemCond < 10 then
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.RubberStrip",}}, "DAMN.OnCreate.DismantleTarpLarge", character);
    elseif itemCond < 81 then
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.RubberStrip",}, {itemId = "Base.Tarp",}}, "DAMN.OnCreate.DismantleTarpLarge", character);
    else
        DAMN:addItemsToPlayerInventory({{itemId = "damnCraft.RubberStrip",}, {itemId = "Base.Tarp", amount = 2,}}, "DAMN.OnCreate.DismantleTarpLarge", character);
    end
end

--Repair Metal

function DAMN.OnCreate.RepairMetal(craftRecipeData, character)
    local item = craftRecipeData:getFirstInputItemWithFlag("IsDamaged")
    character = character or craftRecipeData:getPlayer()
    local skill = character:getPerkLevel(Perks.MetalWelding)

    if not item then return end

    local itemCond = item:getCondition()
    local maxCond = item:getConditionMax()

    local newCond = itemCond + ZombRand((2 + skill * 5), (5 + skill * 10))

    if newCond > maxCond then
        item:setCondition(maxCond)
    else
        item:setCondition(newCond)
    end

    item:syncItemFields()
end

--Plastic Welding Kit

-- function DAMN.OnCreate.PlasticWeldingGunBatteryRemoval(craftRecipeData, character)
--     local items = craftRecipeData:getAllKeepInputItems()
--     local result = craftRecipeData:getAllCreatedItems():get(0)

--     for i=0, items:size()-1 do
--         local item = items:get(i)
--         if item:getFullType() == "damnCraft.PlasticWeldingGun" then
--             result:setUsedDelta(item:getCurrentUsesFloat())
--             item:setUsedDelta(0)
--             item:syncItemFields()
--         end
--     end

--     result:syncItemFields()
-- end


-- function DAMN.OnCreate.PlasticWeldingGunBatteryInsert(craftRecipeData, character)

--     local items = craftRecipeData:getAllConsumedItems();
-- 	local result = craftRecipeData:getAllCreatedItems():get(0);

--     for i=0, items:size()-1 do
--     if items:get(i):getType() == "Battery" then
--         result:setUsedDelta(items:get(i):getCurrentUsesFloat());
--     end
--   end

-- end

function DAMN.OnCreate.RepairPlastic(craftRecipeData, character)
    local items = craftRecipeData:getAllKeepInputItems()
    local item = craftRecipeData:getFirstInputItemWithFlag("IsDamaged")
    character = character or craftRecipeData:getPlayer()
    local skill = character:getPerkLevel(Perks.Mechanics)

    local itemCond = item:getCondition()
    local maxCond = item:getConditionMax()
    local newCond = itemCond + ZombRand((2 + skill * 5), (5 + skill * 10))

    if newCond > maxCond then
        item:setCondition(maxCond)
    else
        item:setCondition(newCond)
    end

    for i = 0, items:size() - 1 do
        local welder = items:get(i)
        if welder:getFullType() == "damnCraft.PlasticWeldingGun" then
            local currentCharge = welder:getCurrentUsesFloat() 
            local usageCost = 0.05

            if currentCharge >= usageCost then
                welder:setCurrentUsesFloat(currentCharge - usageCost)
                welder:syncItemFields()
            end
        end
    end
end

--Repair Tarp

function DAMN.OnCreate.RepairTarp(craftRecipeData, character)

    if not item then item = craftRecipeData:getFirstInputItemWithFlag("IsDamaged") end
    if not character then character = craftRecipeData:getPlayer() end
    if not skill then skill  = character:getPerkLevel(Perks.Mechanical); end

    local itemCond = item:getCondition();
    local maxCond = item:getConditionMax();

    local newCond = itemCond + (ZombRand((2 + skill * 5), (5 + skill * 10)));

        if newCond > maxCond then item:setCondition(maxCond);
        else item:setCondition(newCond);
        end
        item:syncItemFields();

end

--Plastic Molding

function DAMN.OnCreate.MakePlasterMold(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    local originalItem = item:getFullType()
    local itemCond = item:getCondition()

    local result = craftRecipeData:getAllCreatedItems():get(0)

    local text = getText(item:getDisplayName())
    result:setName(text .. " Plaster Mold")

    local modData = result:getModData()
    modData.damnOriginalItemType = originalItem
    modData.damnOriginalDisplayName = text
    modData.damnOriginalItemCond = itemCond
end

-- function DAMN.OnCreate.RemoveOldPartFromMold(craftRecipeData, character)
--     local item = craftRecipeData:getAllConsumedItems():get(0)
--     local result = craftRecipeData:getAllCreatedItems():get(0)

--     local modData = item:getModData()
--     local damnOriginalItemType = modData.damnOriginalItemType
--     local damnOriginalDisplayName = modData.damnOriginalDisplayName
--     local damnOriginalItemCond = modData.damnOriginalItemCond

--     if damnOriginalItemType and damnOriginalItemCond then
--         local oldItem = character:getInventory():AddItem(damnOriginalItemType)
--         oldItem:setCondition(damnOriginalItemCond)

--         result:setName(damnOriginalDisplayName .. " Negative Mold")

--         local resultModData = result:getModData()
--         resultModData.damnOriginalItemType = damnOriginalItemType
--         resultModData.damnOriginalDisplayName = damnOriginalDisplayName
--     end
-- end

function DAMN.OnCreate.PourPasteInMold(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    local modData = item:getModData()
    local damnOriginalItemType = modData.damnOriginalItemType
    local damnOriginalDisplayName = modData.damnOriginalDisplayName

    if not damnOriginalDisplayName then
        character:Say("What did i expect?")
        damnOriginalDisplayName = "Failed mess"
    end

    local result = craftRecipeData:getAllCreatedItems():get(0)
    result:setName(damnOriginalDisplayName .. " in Negative Filled Mold")

    local resultModData = result:getModData()
    resultModData.damnOriginalItemType = damnOriginalItemType
end


function DAMN.OnCreate.RemoveNewPartFromMold(craftRecipeData, character)
    local item = craftRecipeData:getAllConsumedItems():get(0)
    local modData = item:getModData()
    local damnOriginalItemType = modData.damnOriginalItemType

    DAMN:addItemsToPlayerInventory({{itemId = damnOriginalItemType, condition = ZombRandBetween(75,90), }});
end