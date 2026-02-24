CleanHotbarItemState = {}
CleanHotbarItemState.lastItemConditions = {}
CleanHotbarItemState.itemAnimations = {}
CleanHotbarItemState.fadeAnimations = {}

local hotbarIcon = {
    ActiveOn = getTexture("media/ui/CleanHotBar/CleanHotbar_Activated_On.png"),
    ActiveOff = getTexture("media/ui/CleanHotBar/CleanHotbar_Activated_Off.png"),
    Empty = getTexture("media/ui/CleanHotBar/CleanHotbar_Empty_Drainable.png")
}

local timeActionTex = {
    bgLeft = getTexture("media/ui/CleanHotBar/loading/Loading_bg_left.png"),
    bgMiddle = getTexture("media/ui/CleanHotBar/loading/Loading_bg_middle.png"),
    bgRight = getTexture("media/ui/CleanHotBar/loading/Loading_bg_right.png"),
    fillLeft = getTexture("media/ui/CleanHotBar/loading/Loading_fill_left.png"),
    fillMiddle = getTexture("media/ui/CleanHotBar/loading/Loading_fill_middle.png"),
    fillRight = getTexture("media/ui/CleanHotBar/loading/Loading_fill_right.png")
}

-- ----------------------------------------- --
-- StateInfo
-- ----------------------------------------- --

function CleanHotbarItemState.getItemStateInfo(item)
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
    elseif item:getFluidContainer() then
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

function CleanHotbarItemState.getEquipActionInfo(item)
    if not item then return nil end
    
    local jobDelta = item:getJobDelta()
    local jobType = item:getJobType()
    
    if jobDelta > 0 and jobDelta < 1 and jobType and jobType ~= "" then
        local equip_primary = getText("ContextMenu_Equip_Primary")
        local equip_secondary = getText("ContextMenu_Equip_Secondary")
        local equip_two_hands = getText("ContextMenu_Equip_Two_Hands")
        local unequip = getText("ContextMenu_Unequip")
        
        local isEquipAction = (
            string.find(jobType, equip_primary, 1, true) or
            string.find(jobType, equip_secondary, 1, true) or
            string.find(jobType, equip_two_hands, 1, true)
        )
        
        local isUnequipAction = string.find(jobType, unequip, 1, true)
        
        if isEquipAction or isUnequipAction then
            return {
                isAction = true,
                isEquip = isEquipAction,
                isUnequip = isUnequipAction,
                progress = jobDelta
            }
        end
    end
    
    return nil
end

-- ----------------------------------------- --
-- Render
-- ----------------------------------------- --
function CleanHotbarItemState.renderItemState(hotbar, item, slotX, slotY, slotWidth, slotHeight)
    CleanHotbarItemState.checkDurabilityChange(item)
    local config = CHBConfig.getConfig()

    local isEquippedItem = hotbar.isEquippedItem or false
    local showDurability = isEquippedItem and config.showItemDurability.equipitem or config.showItemDurability.hotbar
    
    if not showDurability then return end
    
    local ratio, r, g, b, a = CleanHotbarItemState.getItemStateInfo(item)
    
    if ratio > 0 then
        local fillHeight = math.floor(slotHeight * ratio)
        
        hotbar:setStencilRect(slotX, slotY + (slotHeight - fillHeight), slotWidth, fillHeight)
        hotbar:drawTextureScaled(hotbar.durabilityBgTexture, slotX, slotY, slotWidth, slotHeight, a, r, g, b)
        hotbar:clearStencilRect()

        local fadeAnim = CleanHotbarItemState.getFadeAnimationState(item)
        if fadeAnim and fadeAnim.isActive then
            local fadeAlpha = CleanHotbarItemState.calculateFadeAlpha(fadeAnim)
            if fadeAlpha > 0 then
                local fadeFillHeight = math.floor(slotHeight * fadeAnim.fadeRatio)
                local fadeStartY = slotY + (slotHeight - fillHeight - fadeFillHeight)

                if fadeFillHeight > 0 then
                    hotbar:setStencilRect(slotX, fadeStartY, slotWidth, fadeFillHeight)
                    hotbar:drawTextureScaled(hotbar.durabilityBgTexture, slotX, slotY, slotWidth, slotHeight, fadeAlpha, r, g, b)
                    hotbar:clearStencilRect()
                end
            end
        end
    end
    
    local isDrainableEmpty = false
    if item:getFluidContainer() then
        local fluidContainer = item:getFluidContainer()
        local amount = fluidContainer:getAmount()
        isDrainableEmpty = (amount <= 0)
    end
    
    if isDrainableEmpty then    
        local iconSize = math.min(slotWidth, slotHeight) / 4
        local iconX = slotX + 4
        local iconY = slotY + 4
        hotbar:drawTextureScaled(hotbarIcon.Empty, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
    end
end

function CleanHotbarItemState.renderActivationIcon(hotbar, item, slotX, slotY, slotWidth, slotHeight)
    if not item or not item:canBeActivated() then return end
    
    local isDrainableEmpty = false
    if instanceof(item, "DrainableComboItem") then
        local currentUses = item:getCurrentUsesFloat()
        isDrainableEmpty = (currentUses <= 0)
    end
    
    local iconSize = math.min(slotWidth, slotHeight) / 4
    local iconX = slotX + 4
    local iconY = slotY + 4
    
    if isDrainableEmpty then
        hotbar:drawTextureScaled(hotbarIcon.Empty, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
    else
        if item:isActivated() then
            hotbar:drawTextureScaled(hotbarIcon.ActiveOn, iconX, iconY, iconSize, iconSize, 1)
        else
            hotbar:drawTextureScaled(hotbarIcon.ActiveOff, iconX, iconY, iconSize, iconSize, 1)
        end
    end
end

function CleanHotbarItemState.renderActionProgress(hotbar, item, slotX, slotY, slotWidth, slotHeight)
    local actionInfo = CleanHotbarItemState.getEquipActionInfo(item)
    
    if actionInfo and actionInfo.isAction then
        local barWidth = slotWidth * 0.8
        local barHeight = slotHeight * 0.2
        local barX = slotX + (slotWidth - barWidth) / 2
        local barY = slotY + slotHeight / 2 - barHeight / 2

        CHBCommonUnit.drawThreeSliceBar(hotbar, barX, barY, barWidth, barHeight, timeActionTex.bgLeft, timeActionTex.bgMiddle, timeActionTex.bgRight, 0.6, 0.8, 0.8, 0.8)

        local fillRatio = actionInfo.isUnequip and (1 - actionInfo.progress) or actionInfo.progress

        CHBCommonUnit.drawThreeSliceBarFill(hotbar, barX, barY, barWidth, barHeight, fillRatio, timeActionTex.fillLeft, timeActionTex.fillMiddle, timeActionTex.fillRight, 0.9, 0.8, 0.8, 0.8)
    end
end

-- ----------------------------------------- --
-- Animation Setting
-- ----------------------------------------- --
function CleanHotbarItemState.getItemAnimationState(item)
    if not item then return nil end
    
    local itemID = item:getID()
    if not itemID or itemID == -1 then return nil end
    
    if not CleanHotbarItemState.itemAnimations[itemID] then
        CleanHotbarItemState.itemAnimations[itemID] = {
            isShaking = false,
            shakeDuration = 0,
            startTime = 0
        }
    end
    
    return CleanHotbarItemState.itemAnimations[itemID]
end

function CleanHotbarItemState.getFadeAnimationState(item)
    if not item then return nil end
    
    local itemID = item:getID()
    if not itemID or itemID == -1 then return nil end
    
    if not CleanHotbarItemState.fadeAnimations[itemID] then
        CleanHotbarItemState.fadeAnimations[itemID] = {
            isActive = false,
            startTime = 0,
            duration = 0,
            fadeRatio = 0
        }
    end
    
    return CleanHotbarItemState.fadeAnimations[itemID]
end

function CleanHotbarItemState.checkDurabilityChange(item)
    if not item then return end
    
    local itemID = item:getID()
    if not itemID or itemID == -1 then return end
    
    local currentCondition = 0
    
    if instanceof(item, "HandWeapon") then
        currentCondition = item:getCondition()
    elseif instanceof(item, "DrainableComboItem") then
        currentCondition = item:getCurrentUsesFloat() * 100
    elseif item:getFluidContainer() then
        local fluidContainer = item:getFluidContainer()
        currentCondition = fluidContainer:getAmount() * 100
    else
        return
    end
    
    local lastCondition = CleanHotbarItemState.lastItemConditions[itemID]
    
    if lastCondition and currentCondition < lastCondition then

        local animationState = CleanHotbarItemState.getItemAnimationState(item)
        
        animationState.isShaking = true
        animationState.shakeDuration = 1000
        animationState.startTime = getTimestampMs()

        local fadeAnimState = CleanHotbarItemState.getFadeAnimationState(item)

        local maxValue = 100
        if instanceof(item, "HandWeapon") then
            maxValue = item:getConditionMax()
        end
        
        local lostRatio = (lastCondition - currentCondition) / maxValue
        
        fadeAnimState.isActive = true
        fadeAnimState.startTime = getTimestampMs()
        fadeAnimState.duration = 1200
        fadeAnimState.fadeRatio = lostRatio
    end
    
    CleanHotbarItemState.lastItemConditions[itemID] = currentCondition
end

function CleanHotbarItemState.calculateShakeOffset(item)
    local animState = CleanHotbarItemState.getItemAnimationState(item)
    if not animState or not animState.isShaking then return 0 end
    
    local currentTime = getTimestampMs()
    local elapsedTime = currentTime - animState.startTime
    
    if elapsedTime >= animState.shakeDuration then
        animState.isShaking = false
        return 0
    end
    
    local progress = elapsedTime / animState.shakeDuration
    
    local maxOffset = 8
    local dampingFactor = 1 - progress
    local offset = math.sin(progress * math.pi * 6) * maxOffset * dampingFactor
    
    return offset
end

function CleanHotbarItemState.calculateFadeAlpha(fadeAnim)
    if not fadeAnim or not fadeAnim.isActive then return 0 end
    
    local currentTime = getTimestampMs()
    local elapsedTime = currentTime - fadeAnim.startTime

    if elapsedTime >= fadeAnim.duration then
        fadeAnim.isActive = false
        return 0
    end
    
    local progress = elapsedTime / fadeAnim.duration

    if progress < 0.75 then
        return (math.floor(progress * 8) % 2 == 0) and 0.9 or 0.4
    else
        local fadeProgress = (progress - 0.75) * 4
        return 0.4 * (1 - fadeProgress)
    end
end

return CleanHotbarItemState