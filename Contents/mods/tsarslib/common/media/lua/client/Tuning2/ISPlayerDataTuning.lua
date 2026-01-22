local old_removeInventoryUI = removeInventoryUI

local newTuningMenu = true

function removeInventoryUI(id)
    old_removeInventoryUI(id)
    local data = getPlayerData(id);
    if data == nil then return end;
    if data.tuningUI then
        print("removing tuningUI")
        data.tuningUI:removeFromUIManager()
    end
    data.tuningUI = nil
end

function getPlayerTuningUI(id)
    local data = getPlayerData(id)
    return data and data.tuningUI
end

local old_ISPlayerDataObject_createInventoryInterface = ISPlayerDataObject.createInventoryInterface

function ISPlayerDataObject:createInventoryInterface()
    old_ISPlayerDataObject_createInventoryInterface(self)
    
    local playerObj = getSpecificPlayer(self.id);
    local register = self.id == 0;
    if isMouse then
        print("player ".. self.id .. " is mouse");
        zoom = 1.34;
    else
        register = false;
    end
    
    if newTuningMenu then
        self.tuningUI = ISVehicleTuning2:new(0,0, 800, 700, playerObj);--TODO use HandCraftingMenu
    else
        self.tuningUI = ISVehicleTuning2:new(0,0, 800, 700, playerObj);
    end
    self.tuningUI:initialise();
    self.tuningUI:setVisible(false);
    self.tuningUI:setEnabled(false);
    
    if register then
        ISLayoutManager.RegisterWindow('tuning'..self.id, ISVehicleTuning2, self.tuningUI)
    end
end


--------------------debug B42
--local upperLayer_populateRecipesList = ISCraftingUI.populateRecipesList
--function ISCraftingUI:populateRecipesList()
--    local allRecipes = getAllRecipes();
--
--    for i=0,allRecipes:size()-1 do
--        local newItem = {};
--        local recipe = allRecipes:get(i);
--        print ('Recipe ',i,recipe:getName())
--        local hidden = recipe:isHidden()
--        local ntbl = recipe:needToBeLearn()
--        local known = self.character and self.character:isRecipeKnown(recipe)
--    end
--    upperLayer_populateRecipesList(self)
--end
