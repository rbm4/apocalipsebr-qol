function ISInsertMagazine:complete()
    local Magazine = instanceItem(self.gun:getMagazineType() .. "_Attachment")
    if Magazine then
        self.gun:attachWeaponPart(Magazine, true)
    end
    return true
end

function ISEjectMagazine:complete()
    local Magazine = self.gun:getWeaponPart("Clip")
    if Magazine then
        self.gun:detachWeaponPart(self.character, Magazine)
    end
    return true
end

local function ISAttachMagazine(wielder, weapon)
    if weapon == nil then return end
    if not weapon:IsWeapon() or not weapon:isRanged() then return end
    local magazineType = weapon:getMagazineType()
    if magazineType and weapon:isContainsClip() then
        weapon:attachWeaponPart(instanceItem(magazineType .. "_Attachment"))
    elseif magazineType and not weapon:isContainsClip() then
        weapon:detachWeaponPart(weapon:getWeaponPart("Clip"))
    end
end

Events.OnEquipPrimary.Add(ISAttachMagazine)

local original_ISRemoveUpgradeWeapon = ISRemoveWeaponUpgrade.isValid

function ISRemoveWeaponUpgrade:isValid()
    if isClient() and self.weapon then
        return self.character:getInventory():containsID(self.weapon:getID())
    else
        if not self.character:getInventory():contains(self.weapon) then
            return false
        end
    end
    return self.weapon:getWeaponPart(self.partType) ~= nil
end


function ISUpgradeWeapon:isValid()
    if self.part:getPartType() == "Clip" then
        return false
    end
    if self.weapon:getWeaponPart(self.part:getPartType()) then
        return false
    end
    if isClient() and self.part and self.weapon then
        return self.character:getInventory():containsID(self.part:getID()) and
               self.character:getInventory():containsID(self.weapon:getID())
    else
        return self.character:getInventory():contains(self.part)
    end
end


function ISRemoveWeaponUpgrade:perform()
    self.character:resetEquippedHandsModels()
    ISBaseTimedAction.perform(self)
end

function ISUpgradeWeapon:perform()
    self.weapon:setJobDelta(0.0)
    self.part:setJobDelta(0.0)
    self.character:resetEquippedHandsModels()
    ISBaseTimedAction.perform(self)
end