require "ISUI/ISEquippedItem"


local activatedOnTexture = getTexture("media/ui/CleanHotBar/CleanHotbar_Activated_On.png")
local activatedOffTexture = getTexture("media/ui/CleanHotBar/CleanHotbar_Activated_Off.png")
local emptyDrainableTexture = getTexture("media/ui/CleanHotBar/CleanHotbar_Empty_Drainable.png")

CEEquippedItemState = CEEquippedItemState or {}
CEEquippedItemState.hooked = CEEquippedItemState.hooked or {}
CEEquippedItemState.textureWidth = 48
CEEquippedItemState.textureHeight = 48

if not CEEquippedItemState.hooked.render then
    CEEquippedItemState.hooked.render = ISEquippedItem.render
end

if not CEEquippedItemState.hooked.checkToolTip then
    CEEquippedItemState.hooked.checkToolTip = ISEquippedItem.checkToolTip
end

local function getTextureSize()
    local size = getCore():getOptionSidebarSize()
    if size == 6 then
        size = getCore():getOptionFontSizeReal() - 1
    end
    
    local textureWidth = 48
    if size == 2 then
        textureWidth = 64
    elseif size == 3 then
        textureWidth = 80
    elseif size == 4 then
        textureWidth = 96
    elseif size == 5 then
        textureWidth = 128
    end
    
    CEEquippedItemState.textureWidth = textureWidth
    CEEquippedItemState.textureHeight = textureWidth
end

local function getCircleTexture(isPrimary)
    getTextureSize()
    
    local textureName = ""
    if isPrimary then
        textureName = "media/ui/CleanHotBar/Equipitem/durability_circle_primary_" .. CEEquippedItemState.textureWidth .. ".png"
    else
        textureName = "media/ui/CleanHotBar/Equipitem/durability_circle_secondary_" .. CEEquippedItemState.textureWidth .. ".png"
    end
    
    local texture = getTexture(textureName)
    
    return texture
end

-- ----------------------------------------- --
-- Get State Info
-- ----------------------------------------- --

function CEEquippedItemState.getItemStateInfo(item)
    local ratio = 0
    local r, g, b, a = 0.2, 0.8, 0.2, 0.7
    
    if instanceof(item, "HandWeapon") then
        local condition = item:getCondition()
        local maxCondition = item:getConditionMax()
        
        if condition > 0 and maxCondition > 0 then
            ratio = condition / maxCondition
            
            if ratio > 2/3 then
                r, g, b, a = 0.3, 0.7, 0.3, 0.3
            elseif ratio > 1/3 then
                r, g, b, a = 0.9, 0.8, 0.3, 0.5
            else
                r, g, b, a = 0.8, 0.3, 0.3, 0.9
            end
        end
    elseif instanceof(item, "DrainableComboItem") then
        local currentUses = item:getCurrentUsesFloat()
        ratio = math.max(0, math.min(1, currentUses))
        
        if ratio > 2/3 then
            r, g, b, a = 0.3, 0.7, 0.3, 0.3
        elseif ratio > 1/3 then
            r, g, b, a = 0.9, 0.8, 0.3, 0.5
        else
            r, g, b, a = 0.8, 0.3, 0.3, 0.9
        end
    elseif item.getFluidContainer and item:getFluidContainer() then
        local fluidContainer = item:getFluidContainer()
        
        local amount = fluidContainer:getAmount()
        local capacity = fluidContainer:getCapacity()
        
        if capacity > 0 then
            ratio = amount / capacity
            r, g, b, a = CHBLiquidColors:getLiquidColor(fluidContainer)
        end
    end
    
    return ratio, r, g, b, a
end

-- ----------------------------------------- --
-- Tooltip Manager
-- ----------------------------------------- --
function ISEquippedItem:checkToolTip()
    local config = CHBConfig.getConfig()
    
    if not config.showItemTooltip.equipitem then
        if self.tooltipRender then
            self.tooltipRender:removeFromUIManager()
            self.tooltipRender:setVisible(false)
            self.tooltipRender = nil
        end
        return CEEquippedItemState.hooked.checkToolTip(self)
    end
    
    local mx, my = getMouseX(), getMouseY()
    local mouseOverID = -1
    if self.mouseOverList ~= nil then
        for k, v in ipairs(self.mouseOverList) do
            if self:checkBounds(v.object, mx, my) then
                mouseOverID = k
            end
        end
    end
    if mouseOverID == 1 or mouseOverID == 2 then
        if self.toolTip and self.toolTip:getIsVisible() then
            self.toolTip:removeFromUIManager()
            self.toolTip:setVisible(false)
        end
    else
        CEEquippedItemState.hooked.checkToolTip(self)
        if self.tooltipRender and self.tooltipRender:isVisible() then
            self.tooltipRender:removeFromUIManager()
            self.tooltipRender:setVisible(false)
        end
        return
    end
    
    local item
    if mouseOverID == 1 then 
        item = self.chr:getPrimaryHandItem()
    elseif mouseOverID == 2 then 
        item = self.chr:getSecondaryHandItem()
    end
    
    if getPlayerContextMenu(self.chr:getPlayerNum()) and getPlayerContextMenu(self.chr:getPlayerNum()):isAnyVisible() then
        item = nil
    end
    
    if item and self.tooltipRender and item == self.tooltipRender.item and self.tooltipRender:isVisible() then
        return
    end
    
    if item then
        if self.tooltipRender then
            self.tooltipRender:setItem(item)
            self.tooltipRender:setVisible(true)
            self.tooltipRender:addToUIManager()
            self.tooltipRender:bringToTop()
        else
            self.tooltipRender = ISToolTipInv:new(item)
            self.tooltipRender.backgroundColor.a = 0.7
            self.tooltipRender.followMouse = true
            self.tooltipRender:initialise()
            self.tooltipRender:addToUIManager()
            self.tooltipRender:setVisible(true)
            self.tooltipRender:setOwner(self)
            self.tooltipRender:setCharacter(self.chr)
        end
    elseif self.tooltipRender and self.tooltipRender:isVisible() then
        self.tooltipRender:removeFromUIManager()
        self.tooltipRender:setVisible(false)
    end
end

-- ----------------------------------------- --
-- Render
-- ----------------------------------------- --
function ISEquippedItem:render()
    local primaryItem = self.chr:getPrimaryHandItem()
    local secondaryItem = self.chr:getSecondaryHandItem()

    if primaryItem then
        CEEquippedItemState.renderItemState(self, primaryItem, self.mainHand.x, self.mainHand.y, self.mainHand.width, self.mainHand.height, true)
        CEEquippedItemState.renderStateIcon(self, primaryItem, self.mainHand.x, self.mainHand.y, self.mainHand.width, self.mainHand.height, true)
        CEWeaponState.renderWeaponState(self, primaryItem, self.mainHand.x, self.mainHand.y, self.mainHand.width, self.mainHand.height, true)
    end
    
    if secondaryItem then
        CEEquippedItemState.renderItemState(self, secondaryItem, self.offHand.x, self.offHand.y, self.offHand.width, self.offHand.height, false)
        CEEquippedItemState.renderStateIcon(self, secondaryItem, self.offHand.x, self.offHand.y, self.offHand.width, self.offHand.height, false)
    end

    CEEquippedItemState.hooked.render(self)
end

-- Render State Icon
function CEEquippedItemState.renderStateIcon(panel, item, x, y, width, height, isPrimary)
    if not item then
        return
    end
    
    local isDrainableEmpty = false
    
    if instanceof(item, "DrainableComboItem") then
        local currentUses = item:getCurrentUsesFloat()
        isDrainableEmpty = (currentUses <= 0)
    elseif item.getFluidContainer and item:getFluidContainer() then
        local fluidContainer = item:getFluidContainer()
        local amount = fluidContainer:getAmount()
        isDrainableEmpty = (amount <= 0)
    end
    
    local iconSize, iconX, iconY
    
    if isPrimary then 
        iconSize = math.min(width, height) / 2.5
        iconX = x + width - iconSize - width/64
        iconY = y + height - iconSize - width/64
    else 
        iconSize = math.min(width, height) *0.45
        iconX = x + width - iconSize - width/16
        iconY = y + height - iconSize + width/64
    end
    
    if item:canBeActivated() then
        if isDrainableEmpty then
            panel:drawTextureScaled(emptyDrainableTexture, iconX, iconY, iconSize, iconSize, 1)
        else if item:isActivated() then
                panel:drawTextureScaled(activatedOnTexture, iconX, iconY, iconSize, iconSize, 1)
            else
                panel:drawTextureScaled(activatedOffTexture, iconX, iconY, iconSize, iconSize, 1)
            end
        end
    end
end

-- Render Durability
function CEEquippedItemState.renderItemState(panel, item, x, y, width, height, isPrimary)
    local config = CHBConfig.getConfig()
    
    if not config.showItemDurability.equipitem then
        return
    end

    local durabilityCircle = getCircleTexture(isPrimary)
    if not durabilityCircle then
        return
    end
    
    local ratio, r, g, b, a = CEEquippedItemState.getItemStateInfo(item)
    
    if ratio > 0 then
        local centerX = x + width / 2
        local centerY = y + height / 2
        local circleSize = math.min(width, height)
        local offsetX = centerX - circleSize / 2
        local offsetY = centerY - circleSize / 2

        panel.javaObject:DrawTexturePercentageBottomUp(durabilityCircle, ratio, offsetX, offsetY, circleSize, circleSize, r, g, b, a)
    end

    local isDrainableEmpty = false
    
    if not item:canBeActivated() then
        if instanceof(item, "DrainableComboItem") then
            local currentUses = item:getCurrentUsesFloat()
            isDrainableEmpty = (currentUses <= 0)
        elseif item.getFluidContainer and item:getFluidContainer() then
            local fluidContainer = item:getFluidContainer()
            local amount = fluidContainer:getAmount()
            isDrainableEmpty = (amount <= 0)
        end
        
        if isDrainableEmpty then
            local iconSize = math.min(width, height) / 4
            local iconX, iconY
            
            if isPrimary then
                iconX = x + width/16
                iconY = y + height/16
            else
                iconX = x + width/16
                iconY = y + height/16
            end
            
            panel:drawTextureScaled(emptyDrainableTexture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
        end
    end
end
return CEEquippedItemState