ContainerMap = {
    Saddlebag = "Saddlebag",
    Basket   = "Basket",
    Crate    = "Crate",
    Toolbox  = "ToolboxContainer",
    PlasticBagLeft = "PlasticBagLeft",
    PlasticBagRight = "PlasticBagRight",
}

local BicycleAttachments = require("Bicycle/SaddleBag/Saddlebag")
local BicycleUtils = require("Bicycle/Utils")
local options = PZAPI.ModOptions:getOptions("BicycleMod")

local function isWheelPart(part)
    if not part or not part.getPartType then
        return false
    end

    local partType = part:getPartType()
    return partType == "FrontWheel" or partType == "RearWheel"
end

local function getWheelVariantForTarget(part, targetPartType)
    local partType = part and part.getType and part:getType()
    if not partType then
        return nil
    end

    local isOffroad = string.find(partType, "Offroad", 1, true) ~= nil
    if targetPartType == "FrontWheel" then
        return isOffroad and "Bicycle.Bicycle_OffroadWheelFrontItem" or "Bicycle.Bicycle_StreetWheelFrontItem"
    end

    return isOffroad and "Bicycle.Bicycle_OffroadWheelRearItem" or "Bicycle.Bicycle_StreetWheelRearItem"
end

local function copyWheelState(source, target)
    if not (source and target) then
        return
    end

    if source.getCondition and target.setCondition then
        target:setCondition(source:getCondition())
    end

    local sourceData = source:getModData()
    local targetData = target:getModData()
    targetData.flat = sourceData.flat
    targetData.bicycleWearElapsed = sourceData.bicycleWearElapsed
    if source.getUsedDelta and target.setUsedDelta then
        target:setUsedDelta(source:getUsedDelta())
    end
end

local function resetWheelName(part)
    if not (part and isWheelPart(part) and part.getScriptItem) then
        return
    end

    part:setName(part:getScriptItem():getDisplayName())
    part:setCustomName(false)

    if part:getModData().flat then
        part:setName(part:getName() .. " (Flat)")
        part:setCustomName(true)
    end
end

local function maybeConvertWheelPartForTarget(part, weapon)
    if not (part and weapon and BicycleUtils.isBicycleItem(weapon) and isWheelPart(part)) then
        return part
    end

    local hasFront = weapon:getWeaponPart("FrontWheel") ~= nil
    local hasRear = weapon:getWeaponPart("RearWheel") ~= nil
    local partType = part:getPartType()

    local targetPartType = nil
    if partType == "FrontWheel" and hasFront and not hasRear then
        targetPartType = "RearWheel"
    elseif partType == "RearWheel" and hasRear and not hasFront then
        targetPartType = "FrontWheel"
    end

    if not targetPartType then
        return part
    end

    local container = part.getContainer and part:getContainer() or nil
    if not container then
        return part
    end
    if container and container.DoRemoveItem then
        container:DoRemoveItem(part)
    elseif container and container.Remove then
        container:Remove(part)
    end

    local targetType = getWheelVariantForTarget(part, targetPartType)
    local replacement = targetType and instanceItem(targetType) or nil
    if not replacement then
        if container and container.AddItem then
            container:AddItem(part)
        end
        return part
    end

    copyWheelState(part, replacement)
    resetWheelName(replacement)

    if container and container.AddItem then
        container:AddItem(replacement)
    end

    return replacement
end

local originalUpgrade = ISInventoryPaneContextMenu.onUpgradeWeapon

function ISInventoryPaneContextMenu.onUpgradeWeapon(weapon, part, player, vanillaBag, bicycleUpgradeData)
    local primaryItem = player:getPrimaryHandItem()
    local pzPlayer = player
    if not pzPlayer then
        pzPlayer = getSpecificPlayer(0)
    end
    if BicycleUtils.isBicycleItem(primaryItem) then pzPlayer:Say(getText("IGUI_Bicycle_HopOffFirst")) return end
    if BicycleUtils.isBicycleItem(weapon) then
        pzPlayer:setVariable("BicycleUpgrading", true)
        part = maybeConvertWheelPartForTarget(part, weapon)
        local upgradeAction = ISUpgradeWeapon:new(pzPlayer, weapon, part)
        if upgradeAction then
            upgradeAction.bicyclePartType = part and part.getPartType and part:getPartType()
        end
        upgradeAction.vanillaBag = vanillaBag
        upgradeAction.bicycleUpgradeData = bicycleUpgradeData
        ISTimedActionQueue.add(upgradeAction)
        return;
    end
    return originalUpgrade(weapon, part, pzPlayer)
end

local originalDowngrade = ISInventoryPaneContextMenu.onRemoveUpgradeWeapon

function ISInventoryPaneContextMenu.onRemoveUpgradeWeapon(weapon, part, playerObj)
    local primaryItem = playerObj:getPrimaryHandItem()
    if BicycleUtils.isBicycleItem(primaryItem) then playerObj:Say(getText("IGUI_Bicycle_HopOffFirst")) return end
    if BicycleUtils.isBicycleItem(weapon) then
        local partType = part:getPartType()
        playerObj:setVariable("BicycleUpgrading", true)
        local removeAction = ISRemoveWeaponUpgrade:new(playerObj, weapon, partType)
        removeAction.bicyclePartType = partType
        ISTimedActionQueue.add(removeAction)
        return;
    end
    return originalDowngrade(weapon, part, playerObj)
end

local function finishBicycleUpgrade(action)
    if not action then return end
    local weapon = action.weapon
    local player = action.character or getSpecificPlayer(0)
    if not (weapon and player) then return end

    local part = action.part
    local partType = part and part.getPartType and part:getPartType() or action.bicyclePartType
    if not part and partType and weapon.getWeaponPart then
        part = weapon:getWeaponPart(partType)
    end
    if not partType and part and part.getPartType then
        partType = part:getPartType()
    end

    local containerType = ContainerMap[partType]

    if containerType then
        local bike = BicycleAttachments.FindBicycle(player)
        if not bike then
            player:Say(getText("IGUI_Bicycle_StandCloser"))
            return
        end
        local bikeSq = bike:getSquare()
        if not bikeSq then
            player:Say(getText("IGUI_Bicycle_StandCloser"))
            return
        end
        local containerItem = bikeSq:AddWorldInventoryItem("Bicycle." .. containerType, 0.0, 0.0, 0.0)
        BicycleAttachments.onBikeDropped(player, weapon, { skipRotation = true })
        if containerItem and action.vanillaBag then
            if BicycleAttachments.isPlasticBagPartType(partType) then
                BicycleAttachments.transferVanillaPlasticBag(player, action.vanillaBag, containerItem, bikeSq)
            elseif partType == "Toolbox" then
                BicycleAttachments.transferVanillaToolbox(player, action.vanillaBag, containerItem, bikeSq)
            end
        end
        local pdata = getPlayerData(0)
        if pdata and pdata.playerInventory then
            pdata.playerInventory:refreshBackpacks()
            pdata.lootInventory:refreshBackpacks()
        end
    end
    if partType == "Sportsbottle" and action.vanillaBag and part then
        local vanillaBottle = action.vanillaBag
        BicycleAttachments.captureSportsbottleWater(part, vanillaBottle)
        local container = vanillaBottle:getContainer()
        if container and container.DoRemoveItem then
            container:DoRemoveItem(vanillaBottle)
        elseif container and container.Remove then
            container:Remove(vanillaBottle)
        end
    end

    if partType == "TapedFlashlight" and action.bicycleUpgradeData and part then
        local data = action.bicycleUpgradeData
        local flashlight = data.flashlight
        local ductTape = data.ductTape

        if not ductTape then
            local inv = player and player.getInventory and player:getInventory()
            if inv then
                local found = inv:getFirstTypeRecurse("Base.DuctTape")
                if found and found.getCurrentUsesFloat and found:getCurrentUsesFloat() >= BicycleAttachments.DUCT_TAPE_USAGE then
                    ductTape = found
                end
            end
        end

        if flashlight and flashlight.getContainer then
            local container = flashlight:getContainer()
            if container and container.DoRemoveItem then
                container:DoRemoveItem(flashlight)
            elseif container and container.Remove then
                container:Remove(flashlight)
            end
        end

        if flashlight and flashlight.getUsedDelta and part.setUsedDelta then
            part:setUsedDelta(flashlight:getUsedDelta())
        end

        if ductTape then
            local newDelta = math.max(0, ductTape:getCurrentUsesFloat() - BicycleAttachments.DUCT_TAPE_USAGE)
            ductTape:setCurrentUsesFloat(newDelta)
            if newDelta <= 0 then
                local container = ductTape:getContainer()
                if container and container.DoRemoveItem then
                    container:DoRemoveItem(ductTape)
                elseif container and container.Remove then
                    container:Remove(ductTape)
                end
            end
        end
    end
    local xRot = weapon:getWorldXRotation() or 0
    weapon:setWorldXRotation(xRot + 1)
end

local originalUpgradePerform = ISUpgradeWeapon.perform

function ISUpgradeWeapon:perform()
    local result = originalUpgradePerform(self)
    if BicycleUtils.isBicycleItem(self.weapon) then
        finishBicycleUpgrade(self)
        if self.character then
            self.character:setVariable("BicycleUpgrading", false)
        end
    end
    return result
end

local originalUpgradeStop = ISUpgradeWeapon.stop

function ISUpgradeWeapon:stop()
    if BicycleUtils.isBicycleItem(self.weapon) then
        if self.character then
            self.character:setVariable("BicycleUpgrading", false)
        end
        if self.vanillaBag and self.part then
            local inv = self.character and self.character:getInventory()
            if inv then
                if self.part:getContainer() then
                    self.part:getContainer():DoRemoveItem(self.part)
                else
                    inv:DoRemoveItem(self.part)
                end
            end
        end
        if self.bicycleUpgradeData and self.part then
            local inv = self.character and self.character:getInventory()
            if inv then
                if self.part:getContainer() then
                    self.part:getContainer():DoRemoveItem(self.part)
                else
                    inv:DoRemoveItem(self.part)
                end
            end
        end
    end
    return originalUpgradeStop(self)
end

local originalDowngradeValid = ISRemoveWeaponUpgrade.isValid

function ISRemoveWeaponUpgrade:isValid()
    if BicycleUtils.isBicycleItem(self.weapon) then
        return self.weapon:getWeaponPart(self.partType) ~= nil
    end;
    return originalDowngradeValid(self)
end

local originalRemovePerform = ISRemoveWeaponUpgrade.perform

function ISRemoveWeaponUpgrade:perform()
    local result = originalRemovePerform(self)
    if BicycleUtils.isBicycleItem(self.weapon) and self.bicyclePartType then
        if self.part then
            resetWheelName(self.part)
        end
        BicycleAttachments.onAttachmentRemoved(self.character, self.weapon, self.bicyclePartType)
        if self.character then
            self.character:setVariable("BicycleUpgrading", false)
        end
        local xRot = self.weapon:getWorldXRotation()
        self.weapon:setWorldXRotation(xRot + 1)
    end
    return result
end

local originalRemoveStop = ISRemoveWeaponUpgrade.stop

function ISRemoveWeaponUpgrade:stop()
    if BicycleUtils.isBicycleItem(self.weapon) then
        if self.character then
            self.character:setVariable("BicycleUpgrading", false)
        end
    end
    return originalRemoveStop(self)
end

local originalNewAttachmentEditor = AttachmentEditorUI.new

function AttachmentEditorUI:new(x, y, width, height)
    local editorFix = options:getOption("BicycleEditorFix"):getValue()
    if editorFix then
        return originalNewAttachmentEditor(self, x, y, width, height)
    end
    local o = ISPanel.new(self, x, y, width, height)
	o:setAnchorRight(true)
	o:setAnchorBottom(true)
	o:noBackground()
	o:setWantKeyEvents(true)
	return o
end

local originalAttachmentOnExit = AttachmentEditorUI.onExit

function AttachmentEditorUI:onExit(button, x, y)
    local editorFix = options:getOption("BicycleEditorFix"):getValue()
    if editorFix then
        return originalAttachmentOnExit(self, button, x, y)
    end
    print(getText("IGUI_Bicycle_AttachmentEditorReminder"))
    getAttachmentEditorState():fromLua0("exit")
end

local originalAttachmentOnSave = AttachmentEditorUI.onSave

function AttachmentEditorUI:onSave(button, x, y)
    local editorFix = options:getOption("BicycleEditorFix"):getValue()
    if editorFix then
        return originalAttachmentOnSave(self, button, x, y)
    end
	local item = self.editUI.attachments.list:getSelectedItems()[1]
	if item then
		-- Empty to override attachment editor state check
	end
end

local EditAttachment = AttachmentEditorUI_EditAttachment

function EditAttachment:setPlayerAnimationCombo()
    local editorFix = options:getOption("BicycleEditorFix"):getValue()
    if editorFix then
        return originalAttachmentOnExit(self)
    end
	-- Empty to override attachment editor state check
end
