CleanHotbarWeaponState = {}

local barBackground = {
    Left = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_BG_Left.png"),
    Middle = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_BG_Middle.png"),
    Right = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_BG_Right.png")
}
local barFillTex = {
    Left = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_Fill_Left.png"),
    Middle = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_Fill_Middle.png"),
    Right = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_Fill_Right.png")
}

-- ----------------------------------------- --
-- Weapon State
-- ----------------------------------------- --

function CleanHotbarWeaponState.hasWeaponSpecialState(item)
    if not item then return false end
    return item:hasHeadCondition() or item:hasSharpness()
end

function CleanHotbarWeaponState.getHeadConditionInfo(item)
    if not item:hasHeadCondition() then return 0, 0, 0, 0, 0 end
    
    local condition = item:getHeadCondition()
    local maxCondition = item:getConditionMax()
    
    if condition > 0 and maxCondition > 0 then
        local ratio = condition / maxCondition
        local r, g, b, a = 0.6, 0.4, 0.2, 0.8
        return ratio, r, g, b, a
    end
    
    return 0, 0, 0, 0, 0
end

function CleanHotbarWeaponState.getSharpnessInfo(item)
    if not item:hasSharpness() then return 0, 0 end
    
    local currentSharpness = item:getSharpness()
    local maxSharpness = item:getMaxSharpness()
    
    return currentSharpness, maxSharpness
end

function CleanHotbarWeaponState.isRangedWeapon(item)
    if not item then return false end
    if not instanceof(item, "HandWeapon") then return false end
    return item:isRanged()
end

function CleanHotbarWeaponState.getAmmoInfo(item)
    if not CleanHotbarWeaponState.isRangedWeapon(item) then return 0, 0 end
    
    local magazineAmmo = item:getCurrentAmmoCount()
    local maxAmmo = item:getMaxAmmo()
    
    local totalAmmo = magazineAmmo
    
    if item:haveChamber() and item:isRoundChambered() then
        totalAmmo = totalAmmo + 1
    end
    
    return totalAmmo, maxAmmo
end

-- ----------------------------------------- --
-- Render
-- ----------------------------------------- --

function CleanHotbarWeaponState.renderWeaponState(hotbar, item, slotX, slotY, slotWidth, slotHeight)
    local config = CHBConfig.getConfig()
    if not item then return end
    local isEquippedItem = hotbar.isEquippedItem or false
    local isRanged = CleanHotbarWeaponState.isRangedWeapon(item)
    
----- Gun --------------------------------------------------------------------------------------------------------------------------------
    if isRanged then
        local showAmmo = isEquippedItem and config.showWeaponAmmo.equipitem or config.showWeaponAmmo.hotbar
        if showAmmo then
            local totalAmmo, maxAmmo = CleanHotbarWeaponState.getAmmoInfo(item)
            local ammoText = tostring(totalAmmo) .. "/" .. tostring(maxAmmo)
            
            local ammoTextScale = config.ammoTextScale
            local baseWidth, baseHeight = CHBCommonUnit.getTextureSize()
            local effectiveScale = ammoTextScale * CHBCommonUnit.DEFAULT_SCALE_FACTOR
            local scaledHeight = baseHeight * effectiveScale
            local padding = 4
            local bgHeight = math.ceil(scaledHeight + padding * 2)
            local bgY = math.floor(slotY - bgHeight)

            local Ammo_Background = NinePatchTexture.getSharedTexture("media/ui/CleanHotBar/CleanHotbar_Ammo_BG.png")
            Ammo_Background:render(hotbar:getAbsoluteX()+slotX+1, hotbar:getAbsoluteY()+bgY+1, slotWidth-2, bgHeight, 0.5, 0.5, 0.5, 0.8)
            
            local textY = math.floor(bgY + (bgHeight - scaledHeight) / 2)
            local textWidth = CHBCommonUnit.measureTextWidth(ammoText, ammoTextScale)
            local textX = math.floor(slotX + (slotWidth - textWidth) / 2)
            
            CHBCommonUnit.renderText(hotbar, ammoText, textX, textY, ammoTextScale, 1.0, 1.0, 1.0, 1.0)
        end
        
        -- Jammed Weapon
        if item:isJammed() then
            local weaponJamIconTexture = getTexture("media/ui/CleanHotBar/CleanHotbar_Weapon_Jammed.png")
            local iconSize = math.min(slotWidth, slotHeight) / 4
            local iconX = slotX + 4
            local iconY = slotY + 4
            local time = getTimestampMs() % 1000
            local alpha = 0.7 + 0.3 * math.sin(time / 1000 * math.pi * 2)
            hotbar:drawTextureScaled(weaponJamIconTexture, iconX, iconY, iconSize, iconSize, alpha, 1, 1, 1)
        end
        
        return
    end
    
----- Normal --------------------------------------------------------------------------------------------------------------------------------
    local hasHeadCondition = item:hasHeadCondition() and not item:hasSharpness() and (
        isEquippedItem 
        and config.showWeaponHeadCondition.equipitem
        or config.showWeaponHeadCondition.hotbar
    )

    local hasSharpness = item:hasSharpness() and (
        isEquippedItem 
        and config.showWeaponSharpness.equipitem
        or config.showWeaponSharpness.hotbar
    )
    
    if not hasHeadCondition and not hasSharpness then return end
    
    local statusBarScale = config.statusBarHeightScale

    local minBarHeight = math.floor(slotHeight / 6)
    local maxBarHeight = math.floor(slotHeight / 2)
    local scaleFactor = (statusBarScale - 1.0) / 2.0
    local barHeight = math.floor(minBarHeight + (maxBarHeight - minBarHeight) * scaleFactor)
    
    local barPadding = 2
    local barTopMargin = 3
    
    local barCount = 0
    if hasHeadCondition then barCount = barCount + 1 end
    if hasSharpness then barCount = barCount + 1 end
    
    local totalHeight = (barHeight * barCount) + (barPadding * (barCount - 1))
    
    local startY = slotY - barTopMargin - totalHeight
    
    local currentBar = 0
    -- Head condition
    if hasHeadCondition then
        local ratio, r, g, b, a = CleanHotbarWeaponState.getHeadConditionInfo(item)
        local barY = startY + (currentBar * (barHeight + barPadding))
        
        CHBCommonUnit.drawThreeSliceBar(hotbar, slotX, barY, slotWidth, barHeight,barBackground.Left, barBackground.Middle, barBackground.Right,0.6, 0.4, 0.4, 0.4)
        
        CHBCommonUnit.drawThreeSliceBarFill(hotbar, slotX, barY, slotWidth, barHeight, ratio,barFillTex.Left, barFillTex.Middle, barFillTex.Right,a, r, g, b)
        
        currentBar = currentBar + 1
    end
    -- Sharpness
    if hasSharpness then
        local currentSharpness, maxSharpness = CleanHotbarWeaponState.getSharpnessInfo(item)
        local barY = startY + (currentBar * (barHeight + barPadding))
        
        CHBCommonUnit.drawThreeSliceBar(hotbar, slotX, barY, slotWidth, barHeight,barBackground.Left, barBackground.Middle, barBackground.Right,0.6, 0.4, 0.4, 0.4)
        
        CHBCommonUnit.drawThreeSliceBarFill(hotbar, slotX, barY, slotWidth, barHeight, maxSharpness,barFillTex.Left, barFillTex.Middle, barFillTex.Right,0.8, 0.85, 0.2, 0.2)
        
        CHBCommonUnit.drawThreeSliceBarFill(hotbar, slotX, barY, slotWidth, barHeight, currentSharpness,barFillTex.Left, barFillTex.Middle, barFillTex.Right,1, 0.8, 0.8, 0.8)
    end
end

return CleanHotbarWeaponState