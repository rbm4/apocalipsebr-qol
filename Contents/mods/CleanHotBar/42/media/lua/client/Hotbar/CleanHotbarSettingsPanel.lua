require "ISUI/ISPanel"

local function isReorderTheHotbarActive()
    if ReorderTheHotbar_Mod ~= nil then return true end
    return false
end

CleanHotbarSettingsPanel = ISPanel:derive("CleanHotbarSettingsPanel")

-- ----------------------------------------- --
-- initialise
-- ----------------------------------------- --

function CleanHotbarSettingsPanel:initialise()
    ISPanel.initialise(self)
end

function CleanHotbarSettingsPanel:new(x, y)
    local o = ISPanel:new(x, y, 100, 100)
    setmetatable(o, self)
    self.__index = self

    o.moveWithMouse = true

    o.TitleBarBG = NinePatchTexture.getSharedTexture("media/ui/CleanHotBar/TitleBarTex.png")
    o.SettingContentBG = NinePatchTexture.getSharedTexture("media/ui/CleanHotBar/SettingContentBG.png")

    o.closeButtonTexture = getTexture("media/ui/CleanHotBar/SettingPanel_close.png")
    o.closeButtonTextureOver = getTexture("media/ui/CleanHotBar/SettingPanel_close_hover.png")

    o.buttonLeft = getTexture("media/ui/CleanHotBar/TextEntry_Left.png")
    o.buttonMiddle = getTexture("media/ui/CleanHotBar/TextEntry_Middle.png")
    o.buttonRight = getTexture("media/ui/CleanHotBar/TextEntry_Right.png")

    -- Minus/Plus Button
    o.MinusButton = getTexture("media/ui/CleanHotBar/SettingPanel_minus.png")
    o.PlusButton = getTexture("media/ui/CleanHotBar/SettingPanel_Plus.png")
    o.MinusButtonOver = getTexture("media/ui/CleanHotBar/SettingPanel_minus_hover.png")
    o.PlusButtonOver = getTexture("media/ui/CleanHotBar/SettingPanel_Plus_hover.png")

    -- Normal Button
    o.buttonBgLeftTex = getTexture("media/ui/CleanHotBar/button_bg_left.png")
    o.buttonBgMiddleTex = getTexture("media/ui/CleanHotBar/button_bg_middle.png")
    o.buttonBgRightTex = getTexture("media/ui/CleanHotBar/button_bg_right.png")
    o.buttonBorderLeftTex = getTexture("media/ui/CleanHotBar/button_border_left.png")
    o.buttonBorderMiddleTex = getTexture("media/ui/CleanHotBar/button_border_middle.png")
    o.buttonBorderRightTex = getTexture("media/ui/CleanHotBar/button_border_right.png")
    
    return o
end

-- ----------------------------------------- --
-- Calculate Text Width
-- ----------------------------------------- --

function CleanHotbarSettingsPanel:measureTextWidth(text, font)
    font = font or UIFont.Small
    return getTextManager():MeasureStringX(font, text)
end

function CleanHotbarSettingsPanel:calculateOptionsWidth()
    local optionsWidth = 0
    
    local settingTexts = {
        getText("Tooltip_weapon_HandleCondition"),
        getText("Tooltip_weapon_HeadCondition"),
        getText("Tooltip_weapon_Sharpness"),
        getText("IGUI_CleanHotBar_StatusBar_Height"),
        getText("Tooltip_weapon_AmmoCount"),
        getText("IGUI_CleanHotBar_AmmoText_Scale"),
        getText("IGUI_ShowTooltip"),
        getText("IGUI_AttachmentEditor_Scale"),
        getText("IGUI_CleanHotBar_DurabilityAlert"),
    }
    
    for _, text in ipairs(settingTexts) do
        local textWidth = self:measureTextWidth(text)
        if textWidth > optionsWidth then
            optionsWidth = textWidth
        end
    end
    
    return optionsWidth
end

-- ----------------------------------------- --
-- Calculate PanelSize
-- ----------------------------------------- --

function CleanHotbarSettingsPanel:calculatePanelSize()
    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    self.titleBarHeight = fontHeight*1.5

    local dividerSpacing = math.ceil(fontHeight / 4)
    local dividerHeight = 1
    local dividerTotalHeight = dividerHeight + dividerSpacing
    local rowHeight = fontHeight + 4 
    
    -- Options Count
    local options = 9
    local topPadding = 10
    local bottomPadding = 10

    local contentHeight = topPadding + (options * rowHeight) + ((options - 1) * dividerTotalHeight) + bottomPadding
    
    -- Button Width
    local labelsWidth = self:calculateOptionsWidth()
    local hotbarText = getText("IGUI_CleanHotBar_Hotbar")
    local equipText = getText("IGUI_CleanHotBar_EquipItem")
    local hotbarButtonWidth = self:measureTextWidth(hotbarText) + 20
    local equipButtonWidth = self:measureTextWidth(equipText) + 20

    local buttonSpacing = 10
    local totalButtonsWidth = hotbarButtonWidth + equipButtonWidth + buttonSpacing 

    local controlSize = fontHeight
    local controlWidth = controlSize * 2 + 5

    local minLabelControlSpace = 30
    
    -- Min Panel Width
    local minimumWidthForButtons = labelsWidth + minLabelControlSpace + totalButtonsWidth
    local minimumWidthForControls = labelsWidth + minLabelControlSpace + controlWidth
    local minContentWidth = math.max(minimumWidthForButtons, minimumWidthForControls)
    
    -- Panel Width & Height
    local sidePadding = 25
    local panelWidth = sidePadding * 2 + minContentWidth
    local panelHeight = self.titleBarHeight + contentHeight
    
    -- Min Width & Height
    panelWidth = math.max(panelWidth, fontHeight * 25)
    panelHeight = math.max(panelHeight, fontHeight * 15)

    self:setWidth(panelWidth)
    self:setHeight(panelHeight)
    
    return panelWidth, panelHeight
end

-- ----------------------------------------- --
-- CreateChildren
-- ----------------------------------------- --

function CleanHotbarSettingsPanel:createChildren()
    self:calculatePanelSize()
    
    self:createTitleBar()

    self:createSettingsOptions()
end


function CleanHotbarSettingsPanel:createDualButtonSetting(labelText, yPos, settingKey)
    -- Option Label
    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    local rowHeight = fontHeight + 4
    local labelY = yPos + (rowHeight - fontHeight) / 2 
    local label = ISLabel:new(10, labelY, 20, labelText, 1, 1, 1, 1, UIFont.Small, true)
    label:initialise()
    self:addChild(label)

    local textWidth = self:measureTextWidth(labelText)
    label.width = textWidth
    
    -- get Text Width
    local hotbarText = getText("IGUI_CleanHotBar_Hotbar")
    local equipText = getText("IGUI_CleanHotBar_EquipItem")
    
    local hotbarTextWidth = self:measureTextWidth(hotbarText)
    local equipTextWidth = self:measureTextWidth(equipText)
    local buttonPadding = 20
    local hotbarButtonWidth = hotbarTextWidth + buttonPadding
    local equipButtonWidth = equipTextWidth + buttonPadding
    
    -- Button Size and Position
    local panelWidth = self:getWidth()
    local buttonHeight = fontHeight + 4
    local rightMargin = 20
    local buttonSpacing = 10
    
    local equipButtonX = panelWidth - rightMargin - equipButtonWidth
    local hotbarButtonX = equipButtonX - hotbarButtonWidth - buttonSpacing
    local buttonY = yPos + (rowHeight - buttonHeight) / 2
    
    -- Draw Common Button
    local function createCustomRenderFunction(button)
        button.origRender = button.render
        button.render = function(btn, ...)
            btn.origRender(btn, ...)
            btn.backgroundColor.a = 0
            btn.backgroundColorMouseOver.a = 0
            btn.borderColor.a = 0
            
            -- 1. Draw Background
            local bgR, bgG, bgB, bgA
            
            local config = CHBConfig.getConfig()
            local isSelected = config[settingKey][btn.subKey]
            if isSelected then
                bgR, bgG, bgB, bgA = 0.3, 0.7, 0.3, 0.4
            else
                bgR, bgG, bgB, bgA = 0.5, 0.5, 0.5, 0.2
            end
            CHBCommonUnit.drawThreeSliceBar(btn, 0, 0, btn.width, btn.height,self.buttonBgLeftTex, self.buttonBgMiddleTex, self.buttonBgRightTex,bgA, bgR, bgG, bgB)
            
            -- 2. Draw Boarder
            local borderR, borderG, borderB, borderA
            if btn:isMouseOver() then
                borderR, borderG, borderB, borderA = 1.0, 1.0, 1.0, 0.9
            else
                borderR, borderG, borderB, borderA = 0.6, 0.6, 0.6, 0.7
            end
            
            CHBCommonUnit.drawThreeSliceBar(btn, 0, 0, btn.width, btn.height,self.buttonBorderLeftTex, self.buttonBorderMiddleTex, self.buttonBorderRightTex,borderA, borderR, borderG, borderB)
            
            -- 3. Draw Text
            local textX = (btn.width - getTextManager():MeasureStringX(UIFont.Small, btn.title)) / 2
            local textY = (btn.height - fontHeight) / 2
            
            btn:drawText(btn.title, textX, textY, 1, 1, 1, 1, btn.font)
        end
    end
    
    -- Creat Hotbar Button
    local hotbarButton = ISButton:new(hotbarButtonX, buttonY, hotbarButtonWidth, buttonHeight, hotbarText, self, function()
        self:onToggleSetting(settingKey, "hotbar")
    end)
    hotbarButton:initialise()
    hotbarButton.subKey = "hotbar" 
    hotbarButton.displayBackground = false
    hotbarButton.isSelected = false
    hotbarButton.setSelected = function(button, selected)
        button.isSelected = selected
    end
    createCustomRenderFunction(hotbarButton)
    self:addChild(hotbarButton)
    
    -- Creat Equipitem Button
    local equipButton = ISButton:new(equipButtonX, buttonY, equipButtonWidth, buttonHeight, equipText, self, function()
        self:onToggleSetting(settingKey, "equipitem")
    end)
    equipButton:initialise()
    equipButton.subKey = "equipitem" 
    equipButton.displayBackground = false
    equipButton.isSelected = false
    equipButton.setSelected = function(button, selected)
        button.isSelected = selected
    end
    createCustomRenderFunction(equipButton)
    self:addChild(equipButton)
    
    return hotbarButton, equipButton
end

function CleanHotbarSettingsPanel:createTitleBar()
    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    self.titleBarHeight = fontHeight + 4
    
    -- Title Text
    self.titleLabel = ISLabel:new(10, 2, self.titleBarHeight, "Clean HotBar", 1, 1, 1, 1, UIFont.Small, true)
    self.titleLabel:initialise()
    self.titleLabel:instantiate()
    self:addChild(self.titleLabel)

    local closeSize = self.titleBarHeight
    local closeButtonX = self:getWidth() - closeSize - 2

    if isReorderTheHotbarActive() then
        local LOCK_TEX = getTexture("media/ui/CleanHotBar/locked.png")
        local UNLOCK_TEX = getTexture("media/ui/CleanHotBar/unlocked.png")
        local INSERT_TEX = getTexture("media/ui/CleanHotBar/insert.png")
        local SWAP_TEX = getTexture("media/ui/CleanHotBar/swap.png")
        
        local buttonSize = self.titleBarHeight
        local swapButtonX = closeButtonX - buttonSize - 2
        local lockButtonX = swapButtonX - buttonSize - 2
        
        -- Lock & Unlock Button
        self.lockButton = ISButton:new(lockButtonX, 2, buttonSize, buttonSize, "", self, CleanHotbarSettingsPanel.onLockToggle)
        self.lockButton:initialise()
        self.lockButton.displayBackground = false
        self.lockButton.origRender = self.lockButton.render
        self.lockButton.render = function(button)
            button.origRender(button)
            local playerModData = getPlayer():getModData()
            local isLocked = playerModData["RTH_locked"]
            button:setImage(isLocked and LOCK_TEX or UNLOCK_TEX)
        end
        self:addChild(self.lockButton)
        
        -- Swap Mode Button
        self.swapButton = ISButton:new(swapButtonX, 2, buttonSize, buttonSize, "", self, CleanHotbarSettingsPanel.onSwapToggle)
        self.swapButton:initialise()
        self.swapButton.displayBackground = false
        self.swapButton.origRender = self.swapButton.render
        self.swapButton.render = function(button)
            button.origRender(button)
            local playerModData = getPlayer():getModData()
            local isSwap = playerModData["RTH_swap"]
            button:setImage(isSwap and INSERT_TEX or SWAP_TEX)
        end
        self:addChild(self.swapButton)
    end
    
    -- Close Button
    self.closeButton = ISButton:new(closeButtonX, 2, closeSize, closeSize, "", self, CleanHotbarSettingsPanel.close)
    self.closeButton:initialise()
    self.closeButton.displayBackground = false
    self.closeButton:setImage(self.closeButtonTexture)
    self.closeButton.origRender = self.closeButton.render
    self.closeButton.render = function(button, ...)
        button.origRender(button, ...)
        if button:isMouseOver() then
            button:setImage(self.closeButtonTextureOver)
        else
            button:setImage(self.closeButtonTexture)
        end
    end
    self:addChild(self.closeButton)
end

function CleanHotbarSettingsPanel:createSettingsOptions()
    local startY = self.titleBarHeight + 10
    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    local dividerSpacing = math.ceil(fontHeight / 4)

    local controlSize = fontHeight
    local buttonSpacing = 5
    local rightMargin = 20
    local rowHeight = fontHeight + 4

    local function addDivider(yPos)
        local divider = ISPanel:new(10, yPos, self:getWidth() - 20, 1)
        divider:initialise()
        divider.backgroundColor = {r=0.4, g=0.4, b=0.4, a=0.5}
        divider.borderColor = {r=0, g=0, b=0, a=0}
        self:addChild(divider)
        return dividerSpacing + 1
    end

    local currentY = startY
    
    -- Common Setting Element
    local function addSettingsRow(labelText, controlType, callbackFunction)
        local labelY = currentY + (rowHeight - fontHeight) / 2 
        local label = ISLabel:new(10, labelY, 20, labelText, 1, 1, 1, 1, UIFont.Small, true)
        label:initialise()
        self:addChild(label)
        local controlY = currentY + (rowHeight - controlSize) / 2
        
        -- TickBox
        if controlType == "tickbox" then
            local checkboxX = self:getWidth() - rightMargin - controlSize
            
            local option = ISTickBox:new(checkboxX, controlY, controlSize, controlSize, "", self, callbackFunction)
            option:initialise()
            option:addOption("")
            self:addChild(option)
            return option
        elseif controlType == "buttons" then
            local totalButtonsWidth = (controlSize * 2) + buttonSpacing
            local buttonsX = self:getWidth() - rightMargin - totalButtonsWidth
            -- DecreaseButton
            local decreaseButton = ISButton:new(buttonsX, controlY, controlSize, controlSize, "", self, function() end)
            decreaseButton:initialise()
            decreaseButton.displayBackground = false
            decreaseButton.render = function(button)
                local brightness = button:isMouseOver() and 1 or 0.8
                button:drawTextureScaled(self.MinusButton, 0, 0, controlSize, controlSize, 1, brightness, brightness, brightness)
            end
            self:addChild(decreaseButton)
            
            -- IncreaseButton
            local increaseButton = ISButton:new(buttonsX + controlSize + buttonSpacing, controlY, controlSize, controlSize, "", self, function() end)
            increaseButton:initialise()
            increaseButton.displayBackground = false
            increaseButton.origRender = increaseButton.render
            increaseButton.render = function(button)
                local brightness = button:isMouseOver() and 1 or 0.8
                button:drawTextureScaled(self.PlusButton, 0, 0, controlSize, controlSize, 1, brightness, brightness, brightness)
            end
            self:addChild(increaseButton)
            
            return decreaseButton, increaseButton
        end
    end
    
    -- Show/Hide Item Durability
    self.showItemDurabilityHotbarButton, self.showItemDurabilityEquipButton = 
    self:createDualButtonSetting(getText("Tooltip_weapon_HandleCondition"), currentY, "showItemDurability")
    currentY = currentY + rowHeight
    currentY = currentY + addDivider(currentY)
    
    -- Show/Hide HeadCondition
    self.showWeaponHeadConditionHotbarButton, self.showWeaponHeadConditionEquipButton = 
    self:createDualButtonSetting(getText("Tooltip_weapon_HeadCondition"), currentY, "showWeaponHeadCondition")
    currentY = currentY + rowHeight
    currentY = currentY + addDivider(currentY)
    
    -- Show/Hide Sharpeness
    self.showWeaponSharpnessHotbarButton, self.showWeaponSharpnessEquipButton = 
    self:createDualButtonSetting(getText("Tooltip_weapon_Sharpness"), currentY, "showWeaponSharpness")
    currentY = currentY + rowHeight
    currentY = currentY + addDivider(currentY)
    
    -- StateBar Height
    self.decreaseBarHeightButton, self.increaseBarHeightButton = addSettingsRow(getText("IGUI_CleanHotBar_StatusBar_Height"), "buttons")
    self.decreaseBarHeightButton.onMouseDown = function() self:onDecreaseBarHeight() end
    self.increaseBarHeightButton.onMouseDown = function() self:onIncreaseBarHeight() end
    currentY = currentY + rowHeight
    currentY = currentY + addDivider(currentY)
    
    -- Show/Hide Ammo
    self.showWeaponAmmoHotbarButton, self.showWeaponAmmoEquipButton = 
        self:createDualButtonSetting(getText("Tooltip_weapon_AmmoCount"), currentY, "showWeaponAmmo")
    currentY = currentY + rowHeight
    currentY = currentY + addDivider(currentY)

    -- Scale Ammo Text Height
    self.decreaseAmmoTextScaleButton, self.increaseAmmoTextScaleButton = addSettingsRow(getText("IGUI_CleanHotBar_AmmoText_Scale"), "buttons")
    self.decreaseAmmoTextScaleButton.onMouseDown = function() self:onDecreaseAmmoTextScale() end
    self.increaseAmmoTextScaleButton.onMouseDown = function() self:onIncreaseAmmoTextScale() end
    currentY = currentY + rowHeight
    currentY = currentY + addDivider(currentY)
    
    -- Weapon Durability Alert
    self.showWeaponDurabilityAlertOption = addSettingsRow(getText("IGUI_CleanHotBar_DurabilityAlert"), "tickbox", CleanHotbarSettingsPanel.onShowWeaponDurabilityAlertChange)
    local config = CHBConfig.getConfig()
    self.showWeaponDurabilityAlertOption:setSelected(1, config.showWeaponDurabilityAlert)
    currentY = currentY + rowHeight
    currentY = currentY + addDivider(currentY)
    
    -- Show/Hide Tooltips
    self.showItemTooltipHotbarButton, self.showItemTooltipEquipButton = 
        self:createDualButtonSetting(getText("IGUI_ShowTooltip"), currentY, "showItemTooltip")
    currentY = currentY + rowHeight
    currentY = currentY + addDivider(currentY)

    -- Scale ComboBox
    local scaleY = currentY + (rowHeight - fontHeight) / 2
    local scaleLabel = ISLabel:new(10, scaleY, 20, getText("IGUI_AttachmentEditor_Scale"), 1, 1, 1, 1, UIFont.Small, true)
    scaleLabel:initialise()
    scaleLabel:instantiate()
    self:addChild(scaleLabel)

    self.hotbarScaleOptions = {0.6, 0.8, 1.0, 1.2, 1.5, 1.8, 2.0}
    local comboWidth = 100
    local comboHeight = fontHeight + 4
    local comboX = self:getWidth() - rightMargin - comboWidth
    local comboY = currentY + (rowHeight - comboHeight) / 2

    self.hotbarScaleComboBox = ISComboBox:new(comboX, comboY, comboWidth, comboHeight, self, self.onHotbarScaleSelected)
    self.hotbarScaleComboBox:initialise()
    for i, scale in ipairs(self.hotbarScaleOptions) do
        local text = scale .. "x"
        self.hotbarScaleComboBox:addOption(text)
    end
    local config = CHBConfig.getConfig()
    for i, scale in ipairs(self.hotbarScaleOptions) do
        if math.abs(config.hotbarScale - scale) < 0.01 then
            self.hotbarScaleComboBox:setSelected(i)
            break
        end
    end

    self:addChild(self.hotbarScaleComboBox)
end

-- ----------------------------------------- --
-- Button CallBack
-- ----------------------------------------- --

function CleanHotbarSettingsPanel:roundToDecimal(value, decimalPlaces)
    local mult = 10^(decimalPlaces or 1)
    return math.floor(value * mult + 0.5) / mult
end

function CleanHotbarSettingsPanel:onShowWeaponDurabilityAlertChange(index, selected)
    CHBConfig.updateConfig("showWeaponDurabilityAlert", selected)
end

function CleanHotbarSettingsPanel:onDecreaseBarHeight()
    local config = CHBConfig.getConfig()
    local currentValue = config.statusBarHeightScale
    local newValue = math.max(1.0, currentValue - 0.1)
    newValue = self:roundToDecimal(newValue, 1)
    
    if newValue ~= currentValue then
        CHBConfig.updateConfig("statusBarHeightScale", newValue)
    end
end

function CleanHotbarSettingsPanel:onIncreaseBarHeight()
    local config = CHBConfig.getConfig()
    local currentValue = config.statusBarHeightScale
    local newValue = math.min(2.8, currentValue + 0.1)
    newValue = self:roundToDecimal(newValue, 1)
    
    if newValue ~= currentValue then
        CHBConfig.updateConfig("statusBarHeightScale", newValue)
    end
end

function CleanHotbarSettingsPanel:onLockToggle()
    local playerModData = getPlayer():getModData()
    playerModData["RTH_locked"] = not playerModData["RTH_locked"]
    getSoundManager():playUISound("UIToggleTickBox")
end

function CleanHotbarSettingsPanel:onSwapToggle()
    local playerModData = getPlayer():getModData()
    playerModData["RTH_swap"] = not playerModData["RTH_swap"]
    getSoundManager():playUISound("UIToggleTickBox")
end

function CleanHotbarSettingsPanel:onDecreaseAmmoTextScale()
    local config = CHBConfig.getConfig()
    local currentValue = config.ammoTextScale
    local newValue = math.max(0.5, currentValue - 0.1)
    newValue = self:roundToDecimal(newValue, 1)
    
    if newValue ~= currentValue then
        CHBConfig.updateConfig("ammoTextScale", newValue)
    end
end

function CleanHotbarSettingsPanel:onIncreaseAmmoTextScale()
    local config = CHBConfig.getConfig()
    local currentValue = config.ammoTextScale
    local newValue = math.min(1.6, currentValue + 0.1)
    newValue = self:roundToDecimal(newValue, 1)
    
    if newValue ~= currentValue then
        CHBConfig.updateConfig("ammoTextScale", newValue)
    end
end

function CleanHotbarSettingsPanel:onHotbarScaleSelected(box)
    local selectedScale = self.hotbarScaleOptions[box.selected]
    if selectedScale then
        CHBConfig.updateConfig("hotbarScale", selectedScale)

        local playerIndex = getSpecificPlayer(0):getPlayerNum()
        local hotbar = getPlayerHotbar(playerIndex)
        if hotbar then
            hotbar:setSizeAndPosition()
        end
    end
end

function CleanHotbarSettingsPanel:onToggleSetting(settingKey, subKey)
    local config = CHBConfig.getConfig()
    local newValue = not config[settingKey][subKey]
    CHBConfig.updateConfig(settingKey, newValue, subKey)
end

-- ----------------------------------------- --
-- Panel Control
-- ----------------------------------------- --
function CleanHotbarSettingsPanel.open()
    if CleanHotbarSettingsPanel.instance ~= nil then return end

    local panel = CleanHotbarSettingsPanel:new(0, 0)
    panel:initialise()

    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local x = (screenWidth - panel:getWidth()) / 2
    local y = (screenHeight - panel:getHeight()) / 2

    panel:setX(x)
    panel:setY(y)
    
    panel:addToUIManager()
    panel:setVisible(true)

    CleanHotbarSettingsPanel.instance = panel
    
    return panel
end

function CleanHotbarSettingsPanel:close()
    
    CleanHotbarSettingsPanel.instance = nil
    
    self:setVisible(false)
    self:removeFromUIManager()
end

function CleanHotbarSettingsPanel:onMouseDown(x, y)
    if y > self.titleBarHeight then
        return false
    end
    return ISPanel.onMouseDown(self, x, y)
end

-- ----------------------------------------- --
-- Render
-- ----------------------------------------- --

function CleanHotbarSettingsPanel:prerender()

    local TitleBarBG = NinePatchTexture.getSharedTexture("media/ui/CleanHotBar/TitleBarTex.png")
    TitleBarBG:render(self:getAbsoluteX(), self:getAbsoluteY(), self:getWidth(), self.titleBarHeight, 1, 1, 1, 1)

    local SettingContentBG = NinePatchTexture.getSharedTexture("media/ui/CleanHotBar/SettingContentBG.png")
    SettingContentBG:render(self:getAbsoluteX(), self:getAbsoluteY() + self.titleBarHeight, self:getWidth(), self:getHeight() - self.titleBarHeight, 1, 1, 1, 1)
end

return CleanHotbarSettingsPanel