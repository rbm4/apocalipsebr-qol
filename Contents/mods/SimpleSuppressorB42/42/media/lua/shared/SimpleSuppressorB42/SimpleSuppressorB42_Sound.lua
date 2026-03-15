require "TimedActions/ISUpgradeWeapon"
require "TimedActions/ISRemoveWeaponUpgrade"
require "SimpleSuppressorB42/SimpleSuppressorB42_Improvised"

local STANDARD_SUPPRESSOR_FULL_TYPE = "SimpleSuppressorB42.Suppressor"
local IMPROVISED_SUPPRESSOR_FULL_TYPE = "SimpleSuppressorB42.ImprovisedSuppressor"
local SUPPRESSED_SWING_SOUND = "SimpleSuppressorB42_SuppressedFire"
local SUPPRESSOR_ATTACH_SOUND = "SimpleSuppressorB42_SuppressorAttach"
local SUPPRESSOR_DETACH_SOUND = "SimpleSuppressorB42_SuppressorDetach"
local ORIGINAL_SWING_SOUND_KEY = "SimpleSuppressorB42_OriginalSwingSound"
local ORIGINAL_SOUND_RADIUS_KEY = "SimpleSuppressorB42_OriginalSoundRadius"
local ORIGINAL_SOUND_VOLUME_KEY = "SimpleSuppressorB42_OriginalSoundVolume"
local SUPPRESSOR_SOUND_RADIUS_KEY = "SimpleSuppressorB42_SoundRadiusFactor"
local SUPPRESSOR_SOUND_VOLUME_KEY = "SimpleSuppressorB42_SoundVolumeFactor"
local STANDARD_SUPPRESSOR_STATE_VERSION_KEY = "SimpleSuppressorB42_StandardStateVersion"
local STANDARD_SUPPRESSOR_REMAINING_KEY = "SimpleSuppressorB42_StandardRemainingCondition"
local SOUND_RADIUS_FACTOR = 0.28
local SOUND_VOLUME_FACTOR = 0.22
local IMPROVISED_DEFAULT_SOUND_RADIUS_FACTOR = 0.46
local IMPROVISED_DEFAULT_SOUND_VOLUME_FACTOR = 0.34
local STANDARD_SUPPRESSOR_DISPLAY_CONDITION_MAX = 200
local STANDARD_SUPPRESSOR_DAMAGE_PER_SHOT = 1
local STANDARD_SUPPRESSOR_STATE_VERSION = 4
local MIN_SUPPRESSED_SOUND_RADIUS = 10
local MIN_SUPPRESSED_SOUND_VOLUME = 3
local INVENTORY_RECONCILE_INTERVAL = 180

local inventory_reconcile_ticks = {}
local breakSuppressorPart

local function isAuthoritativeContext()
    local client = isClient and isClient() or false
    local server = isServer and isServer() or false
    return server or (not client and not server)
end

local SUPPORTED_WEAPONS = {
    ["Base.Pistol"] = true,
    ["Base.Pistol2"] = true,
    ["Base.Pistol3"] = true,
    ["Base.AssaultRifle"] = true,
    ["Base.AssaultRifle2"] = true,
    ["Base.HuntingRifle"] = true,
    ["Base.VarmintRifle"] = true,
}

local function isSuppressorPart(part)
    if not part or not part.getFullType then
        return false
    end

    local full_type = part:getFullType()
    return full_type == STANDARD_SUPPRESSOR_FULL_TYPE or full_type == IMPROVISED_SUPPRESSOR_FULL_TYPE
end

local function isSupportedWeapon(weapon)
    return weapon and weapon.getFullType and SUPPORTED_WEAPONS[weapon:getFullType()] == true
end

local function ensureStandardSuppressorState(item)
    if not isAuthoritativeContext() or not item or not item.getFullType or item:getFullType() ~= STANDARD_SUPPRESSOR_FULL_TYPE then
        return false
    end

    local mod_data = item:getModData()
    local state_version = tonumber(mod_data[STANDARD_SUPPRESSOR_STATE_VERSION_KEY]) or 0
    local stored_remaining = tonumber(mod_data[STANDARD_SUPPRESSOR_REMAINING_KEY])
    local target_remaining = STANDARD_SUPPRESSOR_DISPLAY_CONDITION_MAX
    local changed = false

    if state_version < STANDARD_SUPPRESSOR_STATE_VERSION or stored_remaining == nil then
        target_remaining = STANDARD_SUPPRESSOR_DISPLAY_CONDITION_MAX
    else
        target_remaining = math.floor(stored_remaining + 0.5)
        if target_remaining < 0 then
            target_remaining = 0
        elseif target_remaining > STANDARD_SUPPRESSOR_DISPLAY_CONDITION_MAX then
            target_remaining = STANDARD_SUPPRESSOR_DISPLAY_CONDITION_MAX
        end
    end

    -- The standard suppressor keeps its real durability only in modData.
    -- Leaving the native WeaponPart condition disabled avoids engine-side breakage states in MP.
    if (item:getConditionMax() or 0) ~= 0 then
        item:setConditionMax(0)
        changed = true
    end

    if (item:getCondition() or 0) ~= STANDARD_SUPPRESSOR_DISPLAY_CONDITION_MAX then
        item:setCondition(STANDARD_SUPPRESSOR_DISPLAY_CONDITION_MAX)
        changed = true
    end

    if tonumber(mod_data[STANDARD_SUPPRESSOR_REMAINING_KEY]) ~= target_remaining then
        mod_data[STANDARD_SUPPRESSOR_REMAINING_KEY] = target_remaining
        changed = true
    end

    if state_version ~= STANDARD_SUPPRESSOR_STATE_VERSION then
        mod_data[STANDARD_SUPPRESSOR_STATE_VERSION_KEY] = STANDARD_SUPPRESSOR_STATE_VERSION
        changed = true
    end

    return changed
end

local function isBrokenSuppressorPart(part)
    if not part then
        return false
    end

    if part.getFullType and part:getFullType() == STANDARD_SUPPRESSOR_FULL_TYPE then
        local mod_data = part:getModData()
        local stored_remaining = tonumber(mod_data[STANDARD_SUPPRESSOR_REMAINING_KEY])
        if stored_remaining ~= nil then
            return math.floor(stored_remaining + 0.5) <= 0
        end

        return false
    end

    if part.isBroken and part:isBroken() then
        return true
    end

    if part.getCondition and part.getConditionMax then
        local current_max = part:getConditionMax() or 0
        local current_condition = part:getCondition() or 0
        return current_max > 0 and current_condition <= 0
    end

    return false
end

local function getAttachedSuppressorPart(weapon)
    if not isSupportedWeapon(weapon) then
        return nil
    end

    local parts = weapon:getAllWeaponParts()
    if not parts then
        return nil
    end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if isSuppressorPart(part) then
            return part
        end
    end

    return nil
end

local function getSuppressorSoundFactors(part)
    if not part or not part.getFullType then
        return SOUND_RADIUS_FACTOR, SOUND_VOLUME_FACTOR
    end

    if part:getFullType() ~= IMPROVISED_SUPPRESSOR_FULL_TYPE then
        return SOUND_RADIUS_FACTOR, SOUND_VOLUME_FACTOR
    end

    local mod_data = part:getModData()
    local radius_factor = tonumber(mod_data[SUPPRESSOR_SOUND_RADIUS_KEY]) or IMPROVISED_DEFAULT_SOUND_RADIUS_FACTOR
    local volume_factor = tonumber(mod_data[SUPPRESSOR_SOUND_VOLUME_KEY]) or IMPROVISED_DEFAULT_SOUND_VOLUME_FACTOR

    return radius_factor, volume_factor
end

local function cacheOriginalSoundProfile(weapon, script_item, target_radius, target_volume)
    local mod_data = weapon:getModData()
    local current_swing = weapon:getSwingSound()
    local current_radius = weapon:getSoundRadius()
    local current_volume = weapon:getSoundVolume()

    if not mod_data[ORIGINAL_SWING_SOUND_KEY] or mod_data[ORIGINAL_SWING_SOUND_KEY] == "" then
        if current_swing and current_swing ~= "" and current_swing ~= SUPPRESSED_SWING_SOUND then
            mod_data[ORIGINAL_SWING_SOUND_KEY] = current_swing
        else
            mod_data[ORIGINAL_SWING_SOUND_KEY] = script_item:getSwingSound()
        end
    end

    if mod_data[ORIGINAL_SOUND_RADIUS_KEY] == nil then
        if current_radius ~= target_radius then
            mod_data[ORIGINAL_SOUND_RADIUS_KEY] = current_radius
        else
            mod_data[ORIGINAL_SOUND_RADIUS_KEY] = script_item:getSoundRadius()
        end
    end

    if mod_data[ORIGINAL_SOUND_VOLUME_KEY] == nil then
        if current_volume ~= target_volume then
            mod_data[ORIGINAL_SOUND_VOLUME_KEY] = current_volume
        else
            mod_data[ORIGINAL_SOUND_VOLUME_KEY] = script_item:getSoundVolume()
        end
    end
end

local function applySuppressedSoundProfile(weapon, suppressor_part)
    local script_item = weapon and weapon:getScriptItem()
    if not script_item then
        return false
    end

    local radius_factor, volume_factor = getSuppressorSoundFactors(suppressor_part)
    local target_radius = math.max(MIN_SUPPRESSED_SOUND_RADIUS, math.floor(script_item:getSoundRadius() * radius_factor + 0.5))
    local target_volume = math.max(MIN_SUPPRESSED_SOUND_VOLUME, math.floor(script_item:getSoundVolume() * volume_factor + 0.5))
    local changed = false

    cacheOriginalSoundProfile(weapon, script_item, target_radius, target_volume)

    if weapon:getSwingSound() ~= SUPPRESSED_SWING_SOUND then
        weapon:setSwingSound(SUPPRESSED_SWING_SOUND)
        changed = true
    end

    if weapon:getSoundRadius() ~= target_radius then
        weapon:setSoundRadius(target_radius)
        changed = true
    end

    if weapon:getSoundVolume() ~= target_volume then
        weapon:setSoundVolume(target_volume)
        changed = true
    end

    return changed
end

local function restoreDefaultSoundProfile(weapon)
    local script_item = weapon and weapon:getScriptItem()
    if not script_item then
        return false
    end

    local mod_data = weapon:getModData()
    local target_swing = mod_data[ORIGINAL_SWING_SOUND_KEY]
    local target_radius = mod_data[ORIGINAL_SOUND_RADIUS_KEY]
    local target_volume = mod_data[ORIGINAL_SOUND_VOLUME_KEY]
    local changed = false

    if not target_swing or target_swing == "" then
        target_swing = script_item:getSwingSound()
    end

    if target_radius == nil then
        target_radius = script_item:getSoundRadius()
    end

    if target_volume == nil then
        target_volume = script_item:getSoundVolume()
    end

    if weapon:getSwingSound() ~= target_swing then
        weapon:setSwingSound(target_swing)
        changed = true
    end

    if weapon:getSoundRadius() ~= target_radius then
        weapon:setSoundRadius(target_radius)
        changed = true
    end

    if weapon:getSoundVolume() ~= target_volume then
        weapon:setSoundVolume(target_volume)
        changed = true
    end

    return changed
end

local function syncWeaponState(character, weapon)
    if not character or not weapon then
        return
    end

    -- Build 42.14.1 has native part visuals, but not a native WeaponPart sound profile.
    -- Attachment condition and the live sound profile both still have to be written back to the HandWeapon instance.
    if syncHandWeaponFields then
        syncHandWeaponFields(character, weapon)
    end

    if isClient() and weapon.transmitCompleteItemToServer then
        weapon:transmitCompleteItemToServer()
    end

    if isServer() and weapon.transmitCompleteItemToClients then
        weapon:transmitCompleteItemToClients()
    end
end

local function reconcileWeaponSound(character, weapon, force_sync)
    if not isSupportedWeapon(weapon) then
        return false
    end

    local suppressor_part = getAttachedSuppressorPart(weapon)
    local changed = false
    if suppressor_part then
        if isAuthoritativeContext() then
            if suppressor_part:getFullType() == IMPROVISED_SUPPRESSOR_FULL_TYPE then
                changed = SimpleSuppressorB42_Improvised.ensureItemState(suppressor_part, true) or false
            elseif suppressor_part:getFullType() == STANDARD_SUPPRESSOR_FULL_TYPE then
                changed = ensureStandardSuppressorState(suppressor_part) or false
            end

            if isBrokenSuppressorPart(suppressor_part) then
                breakSuppressorPart(character, weapon, suppressor_part)
                return true
            end
        end

        changed = applySuppressedSoundProfile(weapon, suppressor_part) or changed
    else
        changed = restoreDefaultSoundProfile(weapon)
    end

    if changed or force_sync then
        syncWeaponState(character, weapon)
    end

    return changed
end

local function playCharacterSound(character, sound_name)
    if character and sound_name and sound_name ~= "" then
        character:playSound(sound_name)
    end
end

local function rebroadcastEquippedWeapon(character, weapon)
    if not character or not weapon or not sendEquip then
        return
    end

    if character:getPrimaryHandItem() == weapon or character:getSecondaryHandItem() == weapon then
        sendEquip(character)
    end
end

local function refreshLocalEquippedWeaponModel(character, weapon)
    if not character or not weapon or isServer() then
        return
    end

    if not character.isLocalPlayer or not character:isLocalPlayer() then
        return
    end

    if not character.resetEquippedHandsModels then
        return
    end

    if character:getPrimaryHandItem() == weapon or character:getSecondaryHandItem() == weapon then
        character:resetEquippedHandsModels()
    end
end

local function transmitInventoryItemState(item)
    if not item then
        return
    end

    if isClient() and item.transmitCompleteItemToServer then
        item:transmitCompleteItemToServer()
    end

    if isServer() and item.transmitCompleteItemToClients then
        item:transmitCompleteItemToClients()
    end
end

local function reconcileInventoryItem(item, allow_condition_migration)
    if not item then
        return false
    end

    if not isAuthoritativeContext() then
        return false
    end

    local changed = false
    if item.getFullType then
        local full_type = item:getFullType()
        if full_type == IMPROVISED_SUPPRESSOR_FULL_TYPE then
            changed = SimpleSuppressorB42_Improvised.ensureItemState(item, allow_condition_migration) or false
        elseif full_type == STANDARD_SUPPRESSOR_FULL_TYPE then
            changed = ensureStandardSuppressorState(item) or false
        end

        if changed then
            transmitInventoryItemState(item)
        end
    end

    if item.getCategory and item:getCategory() == "Container" and item.getInventory then
        local inner_inventory = item:getInventory()
        if inner_inventory then
            local inner_items = inner_inventory:getItems()
            for i = 0, inner_items:size() - 1 do
                if reconcileInventoryItem(inner_items:get(i), allow_condition_migration) then
                    changed = true
                end
            end
        end
    end

    return changed
end

local function reconcileCharacterInventorySuppressors(character, allow_condition_migration)
    if not character or not character.getInventory then
        return false
    end

    local inventory = character:getInventory()
    if not inventory then
        return false
    end

    local changed = false
    local items = inventory:getItems()
    for i = 0, items:size() - 1 do
        if reconcileInventoryItem(items:get(i), allow_condition_migration) then
            changed = true
        end
    end

    return changed
end

breakSuppressorPart = function(character, weapon, suppressor_part)
    weapon:detachWeaponPart(character, suppressor_part)
    reconcileWeaponSound(character, weapon, true)
    rebroadcastEquippedWeapon(character, weapon)
    refreshLocalEquippedWeaponModel(character, weapon)
end

local function consumeSuppressorCondition(character, weapon)
    if not isAuthoritativeContext() or not character or not isSupportedWeapon(weapon) then
        return
    end

    local suppressor_part = getAttachedSuppressorPart(weapon)
    if not suppressor_part then
        return
    end

    local condition_changed = false
    local did_break = false
    local full_type = suppressor_part:getFullType()

    if full_type == IMPROVISED_SUPPRESSOR_FULL_TYPE then
        SimpleSuppressorB42_Improvised.ensureItemState(suppressor_part, true)
        condition_changed, did_break = SimpleSuppressorB42_Improvised.consumeShot(suppressor_part)
    elseif full_type == STANDARD_SUPPRESSOR_FULL_TYPE then
        ensureStandardSuppressorState(suppressor_part)
        local mod_data = suppressor_part:getModData()
        local stored_remaining = tonumber(mod_data[STANDARD_SUPPRESSOR_REMAINING_KEY]) or STANDARD_SUPPRESSOR_DISPLAY_CONDITION_MAX
        local current_remaining = math.max(math.floor(stored_remaining + 0.5), 0)
        local next_remaining = math.max(current_remaining - STANDARD_SUPPRESSOR_DAMAGE_PER_SHOT, 0)
        if next_remaining ~= current_remaining then
            mod_data[STANDARD_SUPPRESSOR_REMAINING_KEY] = next_remaining
            condition_changed = true
            did_break = next_remaining <= 0
        end
    else
        return
    end

    if not condition_changed then
        return
    end

    if did_break then
        breakSuppressorPart(character, weapon, suppressor_part)
    else
        syncWeaponState(character, weapon)
    end
end

local base_upgrade_complete = ISUpgradeWeapon.complete
local base_upgrade_start = ISUpgradeWeapon.start
local base_remove_complete = ISRemoveWeaponUpgrade.complete
local base_remove_start = ISRemoveWeaponUpgrade.start

function ISUpgradeWeapon:start()
    base_upgrade_start(self)

    if isSuppressorPart(self.part) then
        playCharacterSound(self.character, SUPPRESSOR_ATTACH_SOUND)
    end
end

function ISUpgradeWeapon:complete()
    local is_suppressor = isSuppressorPart(self.part)
    if is_suppressor and self.part and self.part.getFullType and self.part:getFullType() == STANDARD_SUPPRESSOR_FULL_TYPE then
        ensureStandardSuppressorState(self.part)
    end
    local result = base_upgrade_complete(self)

    if result and is_suppressor and self.weapon then
        local attached_part = self.part and self.part.getPartType and self.weapon:getWeaponPart(self.part:getPartType()) or nil
        if attached_part and attached_part.getFullType and attached_part:getFullType() == STANDARD_SUPPRESSOR_FULL_TYPE then
            ensureStandardSuppressorState(attached_part)
        end
        reconcileWeaponSound(self.character, self.weapon)
        rebroadcastEquippedWeapon(self.character, self.weapon)
        refreshLocalEquippedWeaponModel(self.character, self.weapon)
    end

    return result
end

function ISRemoveWeaponUpgrade:start()
    base_remove_start(self)

    local part = self.weapon and self.weapon:getWeaponPart(self.partType) or nil
    if isSuppressorPart(part) then
        playCharacterSound(self.character, SUPPRESSOR_DETACH_SOUND)
    end
end

function ISRemoveWeaponUpgrade:complete()
    local removed_part = self.weapon and self.weapon:getWeaponPart(self.partType) or nil
    local is_suppressor = isSuppressorPart(removed_part)
    if is_suppressor and removed_part and removed_part.getFullType and removed_part:getFullType() == STANDARD_SUPPRESSOR_FULL_TYPE then
        ensureStandardSuppressorState(removed_part)
    end
    local result = base_remove_complete(self)

    if result and is_suppressor and self.weapon then
        reconcileWeaponSound(self.character, self.weapon)
        rebroadcastEquippedWeapon(self.character, self.weapon)
        refreshLocalEquippedWeaponModel(self.character, self.weapon)
    end

    return result
end

local function onWeaponSwingHitPoint(player, weapon)
    if not weapon or not weapon.isRanged or not weapon:isRanged() then
        return
    end

    consumeSuppressorCondition(player, weapon)
end

local function onPlayerAttackFinished(player, weapon)
    if not weapon or not weapon.isRanged or not weapon:isRanged() then
        return
    end

    local suppressor_part = getAttachedSuppressorPart(weapon)
    if not suppressor_part or not suppressor_part.getFullType then
        return
    end

    if suppressor_part:getFullType() == STANDARD_SUPPRESSOR_FULL_TYPE then
        reconcileWeaponSound(player, weapon)
    end
end

local function onEquipPrimary(player, item)
    reconcileWeaponSound(player, item)
end

local function onEquipSecondary(player, item)
    reconcileWeaponSound(player, item)
end

local function reconcileLocalPlayerWeapons()
    local player = getSpecificPlayer and getSpecificPlayer(0) or nil
    if not player then
        return
    end

    if isAuthoritativeContext() then
        reconcileCharacterInventorySuppressors(player, true)
    end
    reconcileWeaponSound(player, player:getPrimaryHandItem())
    reconcileWeaponSound(player, player:getSecondaryHandItem())
end

local function onPlayerUpdate(player)
    if not player then
        return
    end

    local player_num = player.getPlayerNum and player:getPlayerNum() or -1
    inventory_reconcile_ticks[player_num] = (inventory_reconcile_ticks[player_num] or 0) + 1
    if inventory_reconcile_ticks[player_num] < INVENTORY_RECONCILE_INTERVAL then
        return
    end

    inventory_reconcile_ticks[player_num] = 0
    if isAuthoritativeContext() then
        reconcileCharacterInventorySuppressors(player, true)
    end
end

Events.OnEquipPrimary.Add(onEquipPrimary)
Events.OnEquipSecondary.Add(onEquipSecondary)
Events.OnWeaponSwingHitPoint.Add(onWeaponSwingHitPoint)
Events.OnPlayerAttackFinished.Add(onPlayerAttackFinished)
Events.OnGameStart.Add(reconcileLocalPlayerWeapons)
Events.OnCreatePlayer.Add(reconcileLocalPlayerWeapons)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
