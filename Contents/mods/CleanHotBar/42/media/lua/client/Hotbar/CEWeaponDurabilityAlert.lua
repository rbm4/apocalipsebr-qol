require "ISUI/ISUIElement"

CEWeaponDurabilityAlert = {}
CEWeaponDurabilityAlert.displayTime = 1500
CEWeaponDurabilityAlert.travelingY = 15
CEWeaponDurabilityAlert.baseOffsetY = -168
CEWeaponDurabilityAlert.baseZoom = 0.5
CEWeaponDurabilityAlert.baseIconSize = 48
CEWeaponDurabilityAlert.minIconSize = 24
CEWeaponDurabilityAlert.minLostRatio = 0.02
CEWeaponDurabilityAlert.exitSpeed = 3.0
CEWeaponDurabilityAlert.lastWeaponCondition = {}

CEDurabilityIcon = ISUIElement:derive("CEDurabilityIcon")
CEDurabilityIcon.instance = nil
-- ----------------------------------------- --
-- initialise
-- ----------------------------------------- --
function CEDurabilityIcon:initialise()
    ISUIElement.initialise(self)
end

function CEDurabilityIcon:new()
    local x = getCore():getScreenWidth() / 2
    local y = getCore():getScreenHeight() / 2
    local currentZoom = getCore():getCurrentPlayerZoom()
    local dynamicIconSize = CEWeaponDurabilityAlert.baseIconSize * (CEWeaponDurabilityAlert.baseZoom / currentZoom)
    dynamicIconSize = math.max(dynamicIconSize, CEWeaponDurabilityAlert.minIconSize)
    local size = dynamicIconSize * 2
    
    local o = ISUIElement:new(x - size/2, y - size/2, size, size)
    setmetatable(o, self)
    self.__index = self
    
    o.x = x - size/2
    o.y = y - size/2
    o.width = size
    o.height = size
    o.r = 1
    o.g = 1
    o.b = 1
    o.item = nil
    o.timeStamp = nil
    o.lostRatio = nil
    o.isDisplayed = false

    o.conditionDownTexture = getTexture("media/ui/CleanHotBar/CleanHotbar_Condition_Down.png")
    
    return o
end

function CEDurabilityIcon:setItem(item, timeStamp, lostRatio)
    if item then
        self.item = item
        self.timeStamp = timeStamp or getTimestampMs()
        self.lostRatio = lostRatio or 0.05
        
        if not self.isDisplayed then
            self:initialise()
            self:addToUIManager()
            self:setAlwaysOnTop(true)
            self:setVisible(true)
            self.isDisplayed = true
        end
    else
        self.item = nil
        self.timeStamp = nil
        
        if self.isDisplayed then
            self:setVisible(false)
            self.isDisplayed = false
            self:removeFromUIManager()
        end
    end
end

-- ----------------------------------------- --
-- Update
-- ----------------------------------------- --
function CEWeaponDurabilityAlert.update()
    local config = CHBConfig.getConfig()
    if not config or not config.showWeaponDurabilityAlert then
        if CEDurabilityIcon.instance and CEDurabilityIcon.instance.item and CEDurabilityIcon.instance.isDisplayed then
            CEDurabilityIcon.instance:setItem(nil)
            CEWeaponDurabilityAlert.hideTimer = nil
        end
        return
    end

    if CEDurabilityIcon.instance and CEDurabilityIcon.instance.item and CEWeaponDurabilityAlert.hideTimer then
        if getTimestampMs() >= CEWeaponDurabilityAlert.hideTimer then
            CEDurabilityIcon.instance:setItem(nil)
            CEWeaponDurabilityAlert.hideTimer = nil
        end
    end

    local player = getPlayer()
    if not player then return end
    local weapon = player:getPrimaryHandItem()
    if weapon and instanceof(weapon, "HandWeapon") then
        CEWeaponDurabilityAlert.checkWeaponCondition(weapon)
    end
end

function CEWeaponDurabilityAlert.checkWeaponCondition(weapon)
    local itemID = weapon:getID()
    if not itemID or itemID == -1 then return end
    
    local currentCondition = weapon:getCondition()
    local maxCondition = weapon:getConditionMax()
    local lastCondition = CEWeaponDurabilityAlert.lastWeaponCondition[itemID]
    CEWeaponDurabilityAlert.lastWeaponCondition[itemID] = currentCondition
    if lastCondition and currentCondition < lastCondition then
        local lostRatio = (lastCondition - currentCondition) / maxCondition
        if lostRatio >= CEWeaponDurabilityAlert.minLostRatio then
            CEWeaponDurabilityAlert.showAlert(weapon, lostRatio)
        end
    end
end

function CEWeaponDurabilityAlert.showAlert(item, lostRatio)
    if not CEDurabilityIcon.instance then
        local iconPanel = CEDurabilityIcon:new()
        CEDurabilityIcon.instance = iconPanel
    end
    
    CEDurabilityIcon.instance:setItem(item, getTimestampMs(), lostRatio)
    CEWeaponDurabilityAlert.hideTimer = getTimestampMs() + CEWeaponDurabilityAlert.displayTime
end
-- ----------------------------------------- --
-- Render
-- ----------------------------------------- --
function CEDurabilityIcon:render()
    if not self.item or not self.timeStamp then return end

    local currentTime = getTimestampMs()
    local timeSinceCreation = currentTime - self.timeStamp
    local totalTime = CEWeaponDurabilityAlert.displayTime
    
    local baseProgress = math.min(1.0, timeSinceCreation / totalTime)
    
    -- Fade in and out
    local fadeInTime = totalTime * 0.15
    local fadeOutTime = totalTime * 0.15
    local fadeOutStart = totalTime - fadeOutTime
    
    local alpha = 0.8
    if timeSinceCreation < fadeInTime then
        alpha = (timeSinceCreation / fadeInTime) * 0.8
    elseif timeSinceCreation > fadeOutStart then
        alpha = (1.0 - ((timeSinceCreation - fadeOutStart) / fadeOutTime)) * 0.8
        
        -- Speed up when exit
        local exitProgress = (timeSinceCreation - fadeOutStart) / fadeOutTime
        baseProgress = baseProgress + (exitProgress * exitProgress * 0.5 * CEWeaponDurabilityAlert.exitSpeed)
    end

    local tex = self.item:getTexture()
    if not tex then return end

    local currentZoom = getCore():getCurrentPlayerZoom()
    local dynamicIconSize = CEWeaponDurabilityAlert.baseIconSize * (CEWeaponDurabilityAlert.baseZoom / currentZoom)
    dynamicIconSize = math.max(dynamicIconSize, CEWeaponDurabilityAlert.minIconSize)

    local texW = tex:getWidth()
    local texH = tex:getHeight()
    local scale = dynamicIconSize / math.max(texW, texH)
    local width = texW * scale
    local height = texH * scale

    -- Draw ItemIcon
    local dynamicOffsetY = CEWeaponDurabilityAlert.baseOffsetY * (CEWeaponDurabilityAlert.baseZoom / currentZoom)
    local moveY = CEWeaponDurabilityAlert.travelingY * baseProgress
    local x = (self.width - width) / 2
    local y = (self.height - height) / 2 + dynamicOffsetY + moveY
    self:drawTextureScaled(tex, x, y, width, height, alpha, 1, 1, 1)
    
    -- Draw DownIcon 
    local conditionIconSize = dynamicIconSize
    local conditionX = x + width + 2
    local conditionY = y + (height - conditionIconSize) / 2
    self:drawTextureScaled(self.conditionDownTexture, conditionX, conditionY, conditionIconSize, conditionIconSize, alpha, 1, 0.7, 0.3)
end

Events.OnTick.Add(CEWeaponDurabilityAlert.update)

return CEWeaponDurabilityAlert