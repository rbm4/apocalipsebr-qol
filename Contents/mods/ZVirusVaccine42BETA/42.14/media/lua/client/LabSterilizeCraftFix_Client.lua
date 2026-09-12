require "Entity/ISUI/CraftRecipe/ISWidgetHandCraftControl"
require "ISUI/ISInventoryPaneContextMenu"

local STERILIZE_RECIPES = {
    ChmSterilizeGlasses = true,
    ChmSterilizeGlassesHW = true,
    ChmSterilizeGlassesHWPot = true,
    ChmSterilizeGlassesHWPot2 = true,
    ChmSterilizeGlassesHWBucket = true,
    ChmSterilizeGlassesHWBucket2 = true,
    ChmSterilizeLabSyringeReusable = true,
}

local originalStartHandcraft = ISWidgetHandCraftControl.startHandcraft

local function addInputIds(items, knownIds)
    if not items then return end

    for i = 1, items:size() do
        local item = items:get(i - 1)
        if item then
            knownIds[item:getID()] = true
        end
    end
end

local function transferIfNeeded(playerObj, item, knownIds)
    if not playerObj or not item then return end
    if knownIds[item:getID()] then return end

    knownIds[item:getID()] = true
    if item:getContainer() and item:getContainer() ~= playerObj:getInventory() then
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    end
end

local function transferResourceItems(playerObj, recipeData, knownIds)
    if not playerObj or not recipeData then return end

    for i = 0, recipeData:getAllViableResourcesCount() - 1 do
        local resource = recipeData:getViableResource(i)
        if resource and resource:getType() == ResourceType.Item then
            for itemIndex = 0, resource:getItemAmount() - 1 do
                transferIfNeeded(playerObj, resource:peekItem(itemIndex), knownIds)
            end
        end
    end
end

function ISWidgetHandCraftControl:startHandcraft(force)
    local recipe = self.logic and self.logic:getRecipe()
    if recipe and STERILIZE_RECIPES[recipe:getName()] then
        local recipeData = self.logic:getRecipeData()
        local knownIds = {}
        addInputIds(recipeData and recipeData:getAllInputItems(), knownIds)
        transferResourceItems(self.player, recipeData, knownIds)
    end

    return originalStartHandcraft(self, force)
end
