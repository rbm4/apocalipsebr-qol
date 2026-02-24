require "Hotbar/ISHotbar"
require "ISUI/ISButton"


CleanHotbarSettings = {}
CleanHotbarSettings.original_hotbar_render = nil
CleanHotbarSettings.original_reorderhotbar_render = nil
CleanHotbarSettings.original_hotbar_setSizeAndPosition = nil
CleanHotbarSettings.settingsButton = nil

local slotBackgroundTexture = getTexture("media/ui/CleanHotBar/CleanHotbar_Slot_BG.png")
local slotItemBorderTexture = getTexture("media/ui/CleanHotBar/CleanHotbar_Slot_ItemBorder.png")

local _isReorderTheHotbarActive = nil
local function isReorderTheHotbarActive()
    if _isReorderTheHotbarActive ~= nil then
        return _isReorderTheHotbarActive
    end
    
    if ReorderTheHotbar_Mod ~= nil then
        _isReorderTheHotbarActive = true
        return true
    end
    
    _isReorderTheHotbarActive = false
    return false
end

-- ----------------------------------------- --
-- initialise
-- ----------------------------------------- --

CleanHotbarSettingsButton = ISButton:derive("CleanHotbarSettingsButton")

function CleanHotbarSettingsButton:initialise()
    ISButton.initialise(self)
end

function CleanHotbarSettingsButton:new()
    local o = ISButton:new(0, 0, 0, 0)
    setmetatable(o, self)
    self.__index = self
    
    o.displayBackground = false
    o.buttonIcon = getTexture("media/ui/CleanHotBar/CleanHotbar_Settings_Icon.png")
    o.backgroundTex = getTexture("media/ui/CleanHotBar/CleanHotbar_Settings_BG.png")
    
    o.mouseOverHotbar = false
    o.mouseLeaveTime = 0
    o.hideDelay = 3000
    
    return o
end

function CleanHotbarSettingsButton:createChildren()
    ISButton.createChildren(self)
end

function CleanHotbarSettingsButton:render()
    local alpha = self:isMouseOver() and 1.0 or 0.4
    self:drawTextureScaled(self.backgroundTex, 0, 0, self.width, self.height, alpha, 0.6, 0.6, 0.6)
    
    self:drawTextureScaled(self.buttonIcon, 0, 0, self.width, self.height, 1.0, 0.6, 0.6, 0.6)
end

function CleanHotbarSettingsButton:updatePosition(hotbar)
    if not hotbar then return end
    
    local playerObj = hotbar.chr
    if not playerObj then return end

    if (playerObj:getPlayerNum() > 0) or JoypadState.players[playerObj:getPlayerNum()+1] then
        self:setVisible(false)
        return
    end
    
    if playerObj:getVehicle() and playerObj:getVehicle():isDriver(playerObj) then
        self:setVisible(false)
        return
    end
    
    local buttonSize = math.floor(hotbar.slotWidth / 2)
    local buttonX = hotbar:getX() + hotbar:getWidth()

    local slotY = hotbar:getY() + hotbar.margins + 1
    local slotCenterY = slotY + (hotbar.slotHeight / 2)

    local buttonY = slotCenterY - (buttonSize / 2)
    
    self:setX(buttonX)
    self:setY(buttonY)
    self:setWidth(buttonSize)
    self:setHeight(buttonSize)

    local mouseX, mouseY = getMouseX(), getMouseY()
    local hotbarX = hotbar:getX()
    local hotbarY = hotbar:getY()
    local hotbarWidth = hotbar:getWidth()
    local hotbarHeight = hotbar:getHeight()

    local isMouseOverHotbar = (mouseX >= hotbarX and mouseX <= hotbarX + hotbarWidth and
                              mouseY >= hotbarY and mouseY <= hotbarY + hotbarHeight)

    local isMouseOverButtonArea = (mouseX >= buttonX and mouseX <= buttonX + self:getWidth() and
                                 mouseY >= buttonY and mouseY <= buttonY + self:getHeight())

    local isMouseOver = isMouseOverHotbar or isMouseOverButtonArea
    
    if isMouseOver ~= self.mouseOverHotbar then
        self.mouseOverHotbar = isMouseOver
        if not isMouseOver then
            self.mouseLeaveTime = getTimestampMs()
        end
    end
    
    local shouldBeVisible = (self.mouseOverHotbar or (getTimestampMs() - self.mouseLeaveTime < self.hideDelay))
    
    self:setVisible(shouldBeVisible)
end

function CleanHotbarSettingsButton:onMouseUp(x, y)
    if self:isMouseOver() then
        CleanHotbarSettingsPanel.open()
        return true
    end
    return false
end

function CleanHotbarSettingsButton:update()
    local hotbar = getPlayerHotbar(0)
    if not hotbar then return end
    
    local isHotbarVisible = hotbar:isVisible()
    
    if not isHotbarVisible then
        self:setVisible(false)
        return
    end
    
    self:updatePosition(hotbar)
end

-- ----------------------------------------- --
-- Override
-- ----------------------------------------- --

function CleanHotbarSettings.setSizeAndPosition(self)
    CleanHotbarSettings.original_hotbar_setSizeAndPosition(self)
    
    if CleanHotbarSettings.settingsButton then
        CleanHotbarSettings.settingsButton:updatePosition(self)
    end
end

function CleanHotbarSettings.reorder_render_override(self)
    if not CleanHotbarSettings.original_hotbar_render then
        CleanHotbarSettings.original_hotbar_render = ReorderTheHotbar_Mod.original_hotbar_render
    end
    
    if CleanHotbarSettings.original_hotbar_render then
        CleanHotbarSettings.original_hotbar_render(self)
    end
    
    if self.isDraggingASlot then
        local slot = self.availableSlot[self.draggingSlotIndex]
        local item = self.attachedItems[self.draggingSlotIndex]
        
        local x = self:getMouseX() - self.slotWidth / 2
        local y = self:getMouseY() - self.slotHeight / 2
        -- Draw Background
        self:drawTextureScaled(slotBackgroundTexture, x, y, self.slotWidth, self.slotHeight, 0.6, 0.4, 0.4, 0.4)
        
        -- Draw Boarder
        if item then
            if item:isEquipped() then
                self:drawTextureScaled(slotItemBorderTexture, x, y, self.slotWidth, self.slotHeight, 1.0, 0.6, 0.9, 0.9)
            else
                self:drawTextureScaled(slotItemBorderTexture, x, y, self.slotWidth, self.slotHeight, 0.6, 0.8, 0.8, 0.8)
            end
        end
        
        -- Draw ItemIcon or AttachmentIcon
        if item then
            local scale = CHBConfig.getConfig().hotbarScale
            local texSize = 32 * scale

            local texX = x + (self.slotWidth - texSize) / 2
            local texY = y + (self.slotHeight - texSize) / 2
            self:drawTextureScaledAspect(item:getTexture(), texX, texY, texSize, texSize, 1, 1, 1, 1)
        elseif slot.texture then
            local scale = CHBConfig.getConfig().hotbarScale
            local texSize = 32 * scale
            
            local texX = x + (self.slotWidth - texSize) / 2
            local texY = y + (self.slotHeight - texSize) / 2
            self:drawTextureScaledAspect(slot.texture, texX, texY, texSize, texSize, 0.3, 1.0, 1.0, 1.0)
        end
    end
end

-- ----------------------------------------- --
-- initializeOverrides
-- ----------------------------------------- --

local function initializeOverrides()
    if not CleanHotbarSettings.settingsButton then
        CleanHotbarSettings.settingsButton = CleanHotbarSettingsButton:new()
        CleanHotbarSettings.settingsButton:addToUIManager()
    end
    
    if isReorderTheHotbarActive() then
        if not CleanHotbarSettings.original_reorderhotbar_render and ISHotbar.reorder_render then
            CleanHotbarSettings.original_reorderhotbar_render = ISHotbar.reorder_render
            ISHotbar.reorder_render = CleanHotbarSettings.reorder_render_override
        end
    end
end

Events.OnGameStart.Add(initializeOverrides)

return CleanHotbarSettings