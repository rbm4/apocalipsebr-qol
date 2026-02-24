CEWeaponState = {}

local barBackground = {
    Left = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_BG_Left.png"),
    Middle = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_BG_Middle.png"),
    Right = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_BG_Right.png"),
}
local barFillTex = {
    Left = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_Fill_Left.png"),
    Middle = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_Fill_Middle.png"),
    Right = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_Fill_Right.png"),
}
local handweaponBg = {
    Left = getTexture("media/ui/CleanHotBar/CleanHotbar_HandEquip_BG_L.png"),
    Middle = getTexture("media/ui/CleanHotBar/CleanHotbar_HandEquip_BG_M.png"),
    Right = getTexture("media/ui/CleanHotBar/CleanHotbar_HandEquip_BG_R.png"),
}
local weaponJamIcon = getTexture("media/ui/CleanHotBar/CleanHotbar_Weapon_Jammed.png")

-- ----------------------------------------- --
-- Get State Info
-- ----------------------------------------- --

function CEWeaponState.hasWeaponSpecialState(item)
    if not item then return false end
    return item:hasHeadCondition() or item:hasSharpness()
end

function CEWeaponState.getHeadConditionInfo(item)
    if not item:hasHeadCondition() then return 0, 0, 0, 0, 0 end
    
    local condition = item:getHeadCondition()
    local maxCondition = item:getConditionMax()
    
    if condition > 0 and maxCondition > 0 then
        local ratio = condition / maxCondition
        local r, g, b, a = 0.8, 0.4, 0.2, 0.8
        return ratio, r, g, b, a
    end
    return 0, 0, 0, 0, 0
end

function CEWeaponState.getSharpnessInfo(item)
    if not item:hasSharpness() then return 0, 0 end
    
    local currentSharpness = item:getSharpness()
    local maxSharpness = item:getMaxSharpness()
    
    return currentSharpness, maxSharpness
end


function CEWeaponState.isRangedWeapon(item)
    if not item then return false end
    if not instanceof(item, "HandWeapon") then return false end
    return item:isRanged()
end


function CEWeaponState.getAmmoInfo(item)
    if not CEWeaponState.isRangedWeapon(item) then return 0, 0 end
    
    local magazineAmmo = item:getCurrentAmmoCount()
    local maxAmmo = item:getMaxAmmo()
    
    local totalAmmo = magazineAmmo
    
    if item:haveChamber() and item:isRoundChambered() then
        totalAmmo = totalAmmo + 1
    end
    
    return totalAmmo, maxAmmo
end

function CEWeaponState.getInventoryAmmoCount(weapon)
    if not weapon or not CEWeaponState.isRangedWeapon(weapon) then return 0 end
    
    local player = getPlayer()
    if not player then return 0 end
    
    local ammoType = weapon:getAmmoType()
    if not ammoType then return 0 end

    return player:getInventory():getCountTypeRecurse(ammoType:getItemKey())
end

-- ----------------------------------------- --
-- Render
-- ----------------------------------------- --

function CEWeaponState.renderWeaponState(panel, item, x, y, width, height, isPrimary)
    local config = CHBConfig.getConfig()
    if not item then return end

    local ammoTextScale = config.ammoTextScale or 0.8
    local centerX = x + width / 2
    local centerY = y + height / 2
    local isRanged = CEWeaponState.isRangedWeapon(item)
    
    -- Gun
    if isRanged and config.showWeaponAmmo.equipitem then
        local weaponBgWidth = width * 2
        local weaponBgHeight = height
        local weaponBgX = centerX
        local weaponBgY = y
        CHBCommonUnit.drawThreeSliceBar(panel, weaponBgX, weaponBgY, weaponBgWidth, weaponBgHeight,handweaponBg.Left, handweaponBg.Middle, handweaponBg.Right,0.8, 0.7, 0.7, 0.7)

        local totalAmmo, maxAmmo = CEWeaponState.getAmmoInfo(item)

        local inventoryAmmo = CEWeaponState.getInventoryAmmoCount(item)
        local inventoryAmmoText = "ALL : " .. tostring(inventoryAmmo)

        local effectiveScale = ammoTextScale * CHBCommonUnit.DEFAULT_SCALE_FACTOR
        local scaledHeight = CHBCommonUnit.getTextureSize() * effectiveScale
        local itemRightEdge = x + width
        local bgCenterX = weaponBgX + weaponBgWidth / 2

        -- Current Ammo Count
        local ammoText = tostring(totalAmmo) .. "/" .. tostring(maxAmmo)
        local textWidth = CHBCommonUnit.measureTextWidth(ammoText, ammoTextScale)
        local textX = bgCenterX - (textWidth / 2) 
        local textY = centerY - scaledHeight/2
        CHBCommonUnit.renderText(panel, ammoText, textX, textY, ammoTextScale, 1.0, 1.0, 1.0, 1.0)

        -- All Ammo Count
        local threeQuartersHeight = y + (height * 0.1)
        local inventoryTextY = threeQuartersHeight - (scaledHeight / 2 * 0.8)
        local inventoryTextX = itemRightEdge + 2
        CHBCommonUnit.renderText(panel, inventoryAmmoText, inventoryTextX, inventoryTextY, ammoTextScale*0.8, 0.7, 1.0, 1.0, 1.0)

        -- Gun Jam
        if isRanged and item:isJammed() then      
            local iconSize = math.min(width, height) / 3
            local rightEdgeX = x + width
            local iconX = rightEdgeX - (iconSize / 2) - rightEdgeX/16
            local iconY = centerY - (iconSize / 2)
            
            local time = getTimestampMs() % 1000
            local alpha = 0.7 + 0.3 * math.sin(time / 1000 * math.pi * 2)
            
            panel:drawTextureScaled(weaponJamIcon, iconX, iconY, iconSize, iconSize, alpha, 1, 1, 1)
        end
    end
    
    -- Normal
    if not isRanged then
        local hasHeadCondition = item:hasHeadCondition() and not item:hasSharpness() and config.showWeaponHeadCondition.equipitem
        local hasSharpness = item:hasSharpness() and config.showWeaponSharpness.equipitem
        
        if hasHeadCondition or hasSharpness then
            local statusBarScale = config.statusBarHeightScale or 1.0
            local minBarHeight = math.floor(height / 6)
            local maxBarHeight = math.floor(height / 3)
            local scaleFactor = (statusBarScale - 1.0) / 2.0
            local barHeight = math.floor(minBarHeight + (maxBarHeight - minBarHeight) * scaleFactor)
            
            local barPadding = 2
            local upperBarY, lowerBarY
            
            if hasHeadCondition and hasSharpness then
                upperBarY = centerY - barHeight - barPadding/2
                lowerBarY = centerY + barPadding/2
            else
                upperBarY = centerY - barHeight/2
                lowerBarY = centerY - barHeight/2
            end
            local statusBarX = x + width
            local statusBarWidth = width*1.2
            
            -- HeadCondition
            if hasHeadCondition then
                local ratio, r, g, b, a = CEWeaponState.getHeadConditionInfo(item)
                
                CHBCommonUnit.drawThreeSliceBar(panel, statusBarX, upperBarY, statusBarWidth, barHeight,barBackground.Left, barBackground.Middle, barBackground.Right,1.0, 0.4, 0.4, 0.4)
                
                CHBCommonUnit.drawThreeSliceBarFill(panel, statusBarX, upperBarY, statusBarWidth, barHeight, ratio,barFillTex.Left, barFillTex.Middle, barFillTex.Right,a, r, g, b)
            end
            
            -- Sharpness
            if hasSharpness then
                local currentSharpness, maxSharpness = CEWeaponState.getSharpnessInfo(item)
                local barY = hasHeadCondition and lowerBarY or upperBarY
                
                CHBCommonUnit.drawThreeSliceBar(panel, statusBarX, barY, statusBarWidth, barHeight,barBackground.Left, barBackground.Middle, barBackground.Right,1.0, 0.4, 0.4, 0.4)

                local maxRatio = maxSharpness / 1.0
                CHBCommonUnit.drawThreeSliceBarFill(panel, statusBarX, barY, statusBarWidth, barHeight, maxRatio,barFillTex.Left, barFillTex.Middle, barFillTex.Right,0.8, 0.85, 0.2, 0.2)
                
                local currentRatio = currentSharpness / 1.0
                CHBCommonUnit.drawThreeSliceBarFill(panel, statusBarX, barY, statusBarWidth, barHeight, currentRatio,barFillTex.Left, barFillTex.Middle, barFillTex.Right,1, 0.8, 0.8, 0.8)
            end
        end
    end
end

return CEWeaponState