require "AutoMechanics"

--hook the menu to install our button
local genuine_ISVehicleMechanics_onListRightMouseUp = ISVehicleMechanics.onListRightMouseUp
function ISVehicleMechanics:onListRightMouseUp(x,y)
    genuine_ISVehicleMechanics_onListRightMouseUp(self,x,y);
    
    local trueself = self.parent;--PZ mixes ISVehicleMechanics uses between parent and children, onListRightMouseUp is called on children. but children are not initialized.
    if AutoMechanics.getVerbose() then print ("AutoMechanics ISVehicleMechanics:onListRightMouseUp. playernum= "..trueself.playerNum); end
    if trueself and not trueself.context then--in cases doPart never created the menu, we do it
        trueself.context = ISContextMenu.get(trueself.playerNum, x + self:getX() + trueself:getAbsoluteX(), y + self:getY() + trueself:getAbsoluteY())
        trueself:addAutoMechanicsButtons()
    end
end

local genuine_ISVehicleMechanics_doPartContextMenu = ISVehicleMechanics.doPartContextMenu
function ISVehicleMechanics:doPartContextMenu(part,x,y)
    genuine_ISVehicleMechanics_doPartContextMenu(self,part,x,y);
    
    if self.context and not self.inhibitAutoMechanics_doPartContextMenu then
        self:addAutoMechanicsButtons()
    end
end

local genuine_ISVehicleMechanics_onRightMouseUp = ISVehicleMechanics.onRightMouseUp
function ISVehicleMechanics:onRightMouseUp(x, y)
    self.inhibitAutoMechanics_doPartContextMenu = true
    genuine_ISVehicleMechanics_onRightMouseUp(self,x,y);
    self.inhibitAutoMechanics_doPartContextMenu = false

    if not self.context then--in cases doPart never created the menu, we do it
        self.context = ISContextMenu.get(self.playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY())
    end
    self:addAutoMechanicsButtons()
end

--------
function ISVehicleMechanics:addAutoMechanicsButtons()
    local trainOption = self.context:addOption(getText("ContextMenu_AutoMechanics"), self, ISVehicleMechanics.onAutoMechanicsTrain, self.chr, self.vehicle)
    local unallOption = self.context:addOption(getText("ContextMenu_AutoMechanics_UninstallAll"), self, ISVehicleMechanics.onAutoMechanicsUninstallAll, self.chr, self.vehicle)
    local description = getText("Tooltip_craft_Needs") .. " : <LINE>";
    local foundARecipe = false
    for i=0,self.vehicle:getPartCount()-1 do
        local part = self.vehicle:getPartByIndex(i)
        local keyvalues = part:getTable("uninstall");
        if keyvalues and keyvalues.recipes and keyvalues.recipes ~= "" then
            for _,recipe in ipairs(keyvalues.recipes:split(";")) do
                if not self.chr:isRecipeKnown(recipe) then
                    description = description .. " <RED> " .. getText("Tooltip_vehicle_requireRecipe", getRecipeDisplayName(recipe)) .. " <LINE>";
                else
                    description = description .. " <RGB:1,1,1> " .. getText("Tooltip_vehicle_requireRecipe", getRecipeDisplayName(recipe)) .. " <LINE>";
                end
                foundARecipe = true
            end
        end
        if foundARecipe then break end--Do only the first recipe found
    end
    description = description .. AutoMechanics.getTooltipLine(self.chr, "Screwdriver", "Screwdriver")--tag
    description = description .. AutoMechanics.getTooltipLine(self.chr, "Wrench"     , "Wrench")--tag
    description = description .. AutoMechanics.getTooltipLine(self.chr, "LugWrench" , "LugWrench")--tag
    description = description .. AutoMechanics.getTooltipLine(self.chr, "Jack")--item
    description = description .. AutoMechanics.getTooltipLineThreshold()
    --description = description .. AutoMechanics.getTooltipLine(self.chr, "TirePump"   )--useless for mechanics training
    local tooltip = ISToolTip:new();
    tooltip:initialise();
    tooltip:setVisible(true);
    tooltip.description = description
    trainOption.toolTip = tooltip
    unallOption.toolTip = tooltip
    if AutoMechanics.getVerbose() then print ("AutoMechanics "..tostring(trainOption.tooltip and trainOption.tooltip.description or 'nil')); end
    --weak attempt to get joypad working without being able to test it
    if JoypadState.players[self.playerNum+1] and self.context:getIsVisible() then
        self.context.mouseOver = 1
        self.context.origin = self
        JoypadState.players[self.playerNum+1].focus = self.context
        updateJoypadFocus(JoypadState.players[self.playerNum+1])
    end
end


--tool functions
function AutoMechanics.getTooltipLine(player, itemType, tag)
    local item = nil
    if tag then
        item = player:getInventory():getFirstTagRecurse(tag)
        if item and not itemType then itemType = tag end--for log consistency
    elseif itemType then
        item = player:getInventory():getFirstTypeRecurse(itemType)
    end
    if item then
        if AutoMechanics.getVerbose() then print ("AutoMechanics AutoMechanics.getTooltipLine with "..itemType); end
        return " <RGB:1,1,1>" .. item:getDisplayName() .. " 1/1 <LINE>";
    elseif itemType then
        item = instanceItem("Base."..itemType);--"Base."..itemType or just itemType ?
        if AutoMechanics.getVerbose() then print ("AutoMechanics AutoMechanics.getTooltipLine miss "..itemType); end
        return " <RED>" .. item:getDisplayName() .. " 0/1 <LINE>";
    end
end

function AutoMechanics.getTooltipLineThreshold()
    local clientThreshold = AutoMechanics.getConditionLossPercentageThresholdClient()
    local serverThreshold = AutoMechanics.getConditionLossPercentageThresholdServer()
    if serverThreshold < clientThreshold then
        return " <RGB:1,1,1>".. getText("Tooltip_chanceFailure") .. " " .. serverThreshold .. "% (server) <LINE>";
    else
        return " <RGB:1,1,1>".. getText("Tooltip_chanceFailure") .. " " .. clientThreshold .. "% (client) <LINE>";
    end

end

