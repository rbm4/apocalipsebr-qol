require "Hotbar/ISHotbar"


local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

local numberTextures = {}
for i = 0, 20 do
    numberTextures[i] = getTexture("media/ui/CleanHotBar/numbers/" .. i .. ".png")
end

-- Button Texture
local toggleButtonTex = {
    show = getTexture("media/ui/CleanHotBar/CleanHotbar_Toggle_ShowIcon.png"),
    hide = getTexture("media/ui/CleanHotBar/CleanHotbar_Toggle_HideIcon.png")
}
-- Interface Texture
local tooltipBackground = {
    Left = getTexture("media/ui/CleanHotBar/CleanHotbar_Text_BG_Left.png"),
    Middle = getTexture("media/ui/CleanHotBar/CleanHotbar_Text_BG_Middle.png"),
    Right = getTexture("media/ui/CleanHotBar/CleanHotbar_Text_BG_Right.png")
}

local slotBackgroundTexture = getTexture("media/ui/CleanHotBar/CleanHotbar_Slot_BG.png")
local slotItemBorderTexture = getTexture("media/ui/CleanHotBar/CleanHotbar_Slot_ItemBorder.png")

local function getScaledNumberSize()
    local baseHeight = FONT_HGT_SMALL * 0.6
    local scale = CHBConfig.getConfig().hotbarScale or 1.0
    local effectiveScale = scale
    if scale > 1.0 then
        effectiveScale = 1.0 + (scale - 1.0) *(2/3)
    end
    
    return math.floor(baseHeight * effectiveScale), math.floor(baseHeight * effectiveScale)
end

local function drawNumberTexture(hotbar, num, x, y, alpha)
    alpha = alpha or 1.0
    
    local validNum = math.min(20, math.max(0, num))
    local tex = numberTextures[validNum]
    local height, width = getScaledNumberSize()
    local digitX = x - (width / 2)
    local digitY = y - (height / 2)
    hotbar:drawTextureScaled(tex, digitX, digitY, width, height, alpha, 1, 1, 1)
end

local function calculateStatusDisplayHeight(hotbar, item)
    if not item then return 0 end
    
    local config = CHBConfig.getConfig()
    local statusHeight = 0
    
    if CleanHotbarWeaponState.isRangedWeapon(item) then
        if config.showWeaponAmmo then
            local fontHeight = getTextManager():getFontHeight(UIFont.Small)
            local scaledFontHeight = fontHeight * 0.8
            local padding = 2
            statusHeight = scaledFontHeight + padding * 2
        end
    else
        local hasHeadCondition = item:hasHeadCondition() and config.showWeaponHeadCondition
        local hasSharpness = item:hasSharpness() and config.showWeaponSharpness
        
        if hasHeadCondition or hasSharpness then
            local statusBarScale = config.statusBarHeightScale or 1.0

            local minBarHeight = math.floor(hotbar.slotHeight / 6)
            local maxBarHeight = math.floor(hotbar.slotHeight / 2)
            local scaleFactor = (statusBarScale - 1.0) / 2.0 
            local barHeight = math.floor(minBarHeight + (maxBarHeight - minBarHeight) * scaleFactor)
            
            local barPadding = 2
            local barTopMargin = 3
            
            local barCount = 0
            if hasHeadCondition then barCount = barCount + 1 end
            if hasSharpness then barCount = barCount + 1 end
            
            statusHeight = barTopMargin + (barHeight * barCount) + (barPadding * (barCount - 1))
        end
    end
    
    return statusHeight
end

-- ----------------------------------------- --
-- ISHotbar:render override
-- ----------------------------------------- --

ISHotbar.render = function(self)
    self:noBackground()
    local config = CHBConfig.getConfig()
    local scale = config.hotbarScale or 1.0
    local originalSlotWidth = 60
    local originalSlotHeight = 60

    self.slotWidth = math.floor(originalSlotWidth * scale)
    self.slotHeight = math.floor(originalSlotHeight * scale)

    if (self.playerNum > 0) or JoypadState.players[self.playerNum+1] then
        self:setVisible(false);
    end
    local mouseOverSlotIndex = self:getSlotIndexAt(self:getMouseX(), self:getMouseY())
    local draggedItem = nil
    if ISMouseDrag.dragging and (mouseOverSlotIndex ~= -1) then
        local dragging = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
        local slot = self.availableSlot[mouseOverSlotIndex]
        for _,item in ipairs(dragging) do
            if self:canBeAttached(slot, item) then
                draggedItem = item
                break
            end
        end
    end

    -- ( Show/Hide Empty Slot )Button
    local toggleButtonSize = math.floor(self.slotWidth / 3)
    local toggleButtonX = self.margins + 1
    local toggleButtonY = self.margins + 1 + (self.slotHeight - toggleButtonSize) / 2

    local iconTexture = config.showEmptySlots and toggleButtonTex.hide or toggleButtonTex.show
    local alpha = 0.6
    if self:getMouseX() >= toggleButtonX and self:getMouseX() <= toggleButtonX + toggleButtonSize and
    self:getMouseY() >= toggleButtonY and self:getMouseY() <= toggleButtonY + toggleButtonSize then
        alpha = 0.8
    end
    self:drawTextureScaled(iconTexture, toggleButtonX, toggleButtonY, toggleButtonSize, toggleButtonSize, alpha, 0.8, 0.8, 0.8)

    -- start from here
    local slotX = toggleButtonX + toggleButtonSize + self.slotPad
    for i, slot in pairs(self.availableSlot) do
        local item = self.attachedItems[i]
        local isMouseOver = (i == mouseOverSlotIndex)

        if not config.showEmptySlots and not item and not (isMouseOver and draggedItem) then
            -- do nothing (skip this slot)
        else
            local bgBrightness = isMouseOver and 0.5 or 0.35
            local r, g, b = bgBrightness, bgBrightness, bgBrightness
            
            if isMouseOver and ISMouseDrag.dragging and not draggedItem then
                r, g, b = 0.5, 0.3, 0.3
            end
            
            self:drawTextureScaled(slotBackgroundTexture, slotX, self.margins+1, self.slotWidth, self.slotHeight, 0.6, r, g, b)
            if item then
                CleanHotbarItemState.renderItemState(self, item, slotX, self.margins+1, self.slotWidth, self.slotHeight)
                CleanHotbarWeaponState.renderWeaponState(self, item, slotX, self.margins+1, self.slotWidth, self.slotHeight)
                self:drawTextureScaled(getTexture("media/ui/CleanHotBar/CleanHotbar_Item_Hover.png"), slotX, self.margins+1, self.slotWidth, self.slotHeight, 0.6, 0.98, 0.95, 0.85)
            end
            
            -- Draw Boarder
            if item then
                if item:isEquipped() then
                    self:drawTextureScaled(slotItemBorderTexture, slotX, self.margins+1, self.slotWidth, self.slotHeight, 1.0, 0.6, 0.9, 0.9)
                else
                    self:drawTextureScaled(slotItemBorderTexture, slotX, self.margins+1, self.slotWidth, self.slotHeight, 0.6, 0.6, 0.6, 0.6)
                end
            end
        
            -- Draw Number
            local slotBottomY = self.margins + 1 + self.slotHeight

            local numberHeight = getScaledNumberSize()
            local bgPadding = 4 * (CHBConfig.getConfig().hotbarScale or 1.0)
            local bgSize = numberHeight + bgPadding
                    
            local slotCenterX = slotX + (self.slotWidth / 2)
            local bgX = slotCenterX - (bgSize / 2)
            local bgY = slotBottomY - (bgSize / 2)

            self:drawTextureScaled(getTexture("media/ui/CleanHotBar/CleanHotbar_Number_BG.png"), bgX, bgY, bgSize, bgSize, 1, 0.8, 0.8, 0.8)  
            drawNumberTexture(self, i, slotCenterX, slotBottomY, 1.0)
            
            -- Draw Attachment Tooltip
            if isMouseOver then
                if draggedItem then
                    item = draggedItem
                end
                
                local slotName = getTextOrNull("IGUI_HotbarAttachment_" .. slot.slotType) or slot.name;
                local textWid = getTextManager():MeasureStringX(UIFont.Small, slotName)

                local tooltipPadding = FONT_HGT_SMALL /4
                local tooltipWidth = textWid + tooltipPadding * 2
                local tooltipHeight = FONT_HGT_SMALL + tooltipPadding * 2
                local tooltipX = slotX + (self.slotWidth - tooltipWidth) / 2
                
                local statusDisplayHeight = 0
                if item then 
                    statusDisplayHeight = calculateStatusDisplayHeight(self, item)
                end
                
                local tooltipY = 0 - tooltipHeight
                if statusDisplayHeight > 0 then
                    tooltipY = tooltipY - statusDisplayHeight
                end
                
                CHBCommonUnit.drawThreeSliceBar(self, tooltipX, tooltipY, tooltipWidth, tooltipHeight,tooltipBackground.Left, tooltipBackground.Middle, tooltipBackground.Right,  0.8, 0.2, 0.2, 0.2)
                
                local textY = tooltipY + tooltipPadding
                self:drawText(slotName, slotX + (self.slotWidth - textWid) / 2, textY, self.textColor.r, self.textColor.g, self.textColor.b, self.textColor.a, self.font);
            elseif item == draggedItem then
                item = nil
            end

            -- Draw ItemIcon
            if item then
                local shakeOffset = CleanHotbarItemState.calculateShakeOffset(item)
                local scale = CHBConfig.getConfig().hotbarScale or 1.0
                local texSize = 32 * scale

                local itemX = slotX + (self.slotWidth - texSize) / 2 + shakeOffset
                local itemY = self.margins + 1 + (self.slotHeight - texSize) / 2
                self:drawTextureScaledAspect(item:getTexture(), itemX, itemY, texSize, texSize, 1, 1, 1, 1)
                -- Render Activation Ion
                CleanHotbarItemState.renderActivationIcon(self, item, slotX, self.margins+1, self.slotWidth, self.slotHeight)
                -- Render TimeAction
                CleanHotbarItemState.renderActionProgress(self, item, slotX, self.margins+1, self.slotWidth, self.slotHeight)

            -- Draw EmptySlot's Attachment
            elseif slot.texture then
                local scale = CHBConfig.getConfig().hotbarScale or 1.0
                local texSize = 32 * scale

                local texX = slotX + (self.slotWidth - texSize) / 2
                local texY = self.margins + 1 + (self.slotHeight - texSize) / 2

                self:drawTextureScaledAspect(slot.texture, texX, texY, texSize, texSize, 0.3, 1.0, 1.0, 1.0)
            end
            slotX = slotX + self.slotWidth + self.slotPad
        end
    end
    self:updateTooltip()
end

-- ----------------------------------------- --
-- Scale the Hotbar
-- ----------------------------------------- --
if not CleanHotbar_original_setSizeAndPosition then
    CleanHotbar_original_setSizeAndPosition = ISHotbar.setSizeAndPosition
end

ISHotbar.setSizeAndPosition = function(self)
    local config = CHBConfig.getConfig()
    local scale = config.hotbarScale or 1.0
    
    local originalSlotWidth = 60
    local originalSlotHeight = 60
    
    self.slotWidth = math.floor(originalSlotWidth * scale)
    self.slotHeight = math.floor(originalSlotHeight * scale)
    self.height = self.slotHeight + (self.margins * 2) + 2
    local toggleButtonSize = math.floor(self.slotWidth / 3)
    local visibleSlotCount = 0
    
    for i, _ in pairs(self.availableSlot) do
        if config.showEmptySlots or self.attachedItems[i] then
            visibleSlotCount = visibleSlotCount + 1
        end
    end
    
    -- Calculate Width
    local width = toggleButtonSize + self.slotPad
    width = width + (visibleSlotCount * self.slotWidth)
    if visibleSlotCount > 0 then
        width = width + ((visibleSlotCount - 1) * self.slotPad)
    end
    self:setWidth(width + self.margins*2 + 2)

    -- Get Screen
    local screenX = getPlayerScreenLeft(self.playerNum)
    local screenY = getPlayerScreenTop(self.playerNum)
    local screenW = getPlayerScreenWidth(self.playerNum)
    local screenH = getPlayerScreenHeight(self.playerNum)

    -- Scale Number
    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    local defaultBaseHeight = fontHeight * 0.6
    local defaultPadding = 4
    local defaultNumberSize = defaultBaseHeight + defaultPadding

    local currentBaseHeight = fontHeight * 0.6 * scale
    local currentPadding = 4 * scale
    local currentNumberSize = currentBaseHeight + currentPadding

    local defaultOverflow = defaultNumberSize / 2
    local currentOverflow = currentNumberSize / 2
    local upwardOffset = currentOverflow - defaultOverflow
    upwardOffset = (scale > 1.0) and upwardOffset or 0

    self:setX(screenX + (screenW - self.width) / 2)
    self:setY(screenY + screenH - self.height - upwardOffset)
    
    if CleanHotbarSettings and CleanHotbarSettings.settingsButton then
        CleanHotbarSettings.settingsButton:updatePosition(self)
    end
end

if not CleanHotbar_original_onMouseUp then
    CleanHotbar_original_onMouseUp = ISHotbar.onMouseUp
end
ISHotbar.onMouseUp = function(self, x, y)
    local toggleButtonSize = math.floor(self.slotWidth / 3)
    local toggleButtonX = self.margins + 1
    local toggleButtonY = self.margins + 1 + (self.slotHeight - toggleButtonSize) / 2
    
    if x >= toggleButtonX and x <= toggleButtonX + toggleButtonSize and
       y >= toggleButtonY and y <= toggleButtonY + toggleButtonSize then
        local config = CHBConfig.getConfig()
        config.showEmptySlots = not config.showEmptySlots
        CHBConfig.updateConfig("showEmptySlots", config.showEmptySlots)
        getSoundManager():playUISound("UIToggleTickBox")
        self:setSizeAndPosition()
        return true
    end

    return CleanHotbar_original_onMouseUp(self, x, y)
end

if not CleanHotbar_original_getSlotIndexAt then
    CleanHotbar_original_getSlotIndexAt = ISHotbar.getSlotIndexAt
end
ISHotbar.getSlotIndexAt = function(self, x, y)
    local config = CHBConfig.getConfig()
    local toggleButtonSize = math.floor(self.slotWidth / 3)

    local slotStartX = self.margins + 1 + toggleButtonSize + self.slotPad
    
    if x >= slotStartX and x < self.width and y >= 0 and y < self.height then
        local relativeX = x - slotStartX
        local slotWidth = self.slotWidth + self.slotPad
        local slotIndex = math.floor(relativeX / slotWidth) + 1
        if not config.showEmptySlots then
            local visibleIndex = 0
            for i=1, #self.availableSlot do
                if self.attachedItems[i] then
                    visibleIndex = visibleIndex + 1
                    if visibleIndex == slotIndex then
                        return i
                    end
                end
            end
            return -1
        else
            if slotIndex <= #self.availableSlot then
                return slotIndex
            end
        end
    end
    return -1
end

-- ----------------------------------------- --
-- Tooltip Manager
-- ----------------------------------------- --

ISHotbar.updateTooltip = function(self)
    if not CHBConfig.getConfig().showItemTooltip.hotbar then
        if self.tooltipRender and self.tooltipRender:isVisible() then
            self.tooltipRender:removeFromUIManager()
            self.tooltipRender:setVisible(false)
        end
        return
    end

    local index = self:getSlotIndexAt(self:getMouseX(), self:getMouseY())
    local item = nil
    
    if index ~= -1 then
        item = self.attachedItems[index]
    end
    
    if item then
        if self.tooltipRender then
            self.tooltipRender:setItem(item)
            self.tooltipRender:setVisible(true)
            self.tooltipRender:addToUIManager()
            self.tooltipRender:bringToTop()
        else
            self.tooltipRender = ISToolTipInv:new(item)
            self.tooltipRender.followMouse = false
            self.tooltipRender:initialise()
            self.tooltipRender:addToUIManager()
            self.tooltipRender:setVisible(true)
            self.tooltipRender:setOwner(self)
            self.tooltipRender:setCharacter(self.character)
        end
        
        local physicalIndex = 0
        for i = 1, index do
            if CHBConfig.getConfig().showEmptySlots or self.attachedItems[i] then
                if i == index then break end
                physicalIndex = physicalIndex + 1
            end
        end
        local toggleButtonSize = math.floor(self.slotWidth / 3)
        local slotX = self:getAbsoluteX() + self.margins + toggleButtonSize + self.slotPad + (self.slotWidth + self.slotPad) * physicalIndex
        local slotY = self:getAbsoluteY()
        local slotBottomY = slotY + self.slotHeight
        
        self.tooltipRender.prerender = function(tooltip)
            ISToolTipInv.prerender(tooltip)
            
            local tooltipWidth = tooltip:getWidth()
            local tooltipHeight = tooltip:getHeight()

            local tooltipX = slotX - tooltipWidth - 5
            local tooltipY = slotBottomY - tooltipHeight

            tooltip:setX(tooltipX)
            tooltip:setY(tooltipY)
        end
    elseif self.tooltipRender and self.tooltipRender:isVisible() then
        self.tooltipRender:removeFromUIManager()
        self.tooltipRender:setVisible(false)
    end
end