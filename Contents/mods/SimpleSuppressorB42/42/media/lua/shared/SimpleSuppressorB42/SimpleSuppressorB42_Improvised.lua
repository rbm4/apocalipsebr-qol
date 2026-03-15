SimpleSuppressorB42_Improvised = SimpleSuppressorB42_Improvised or {}

local IMPROVISED_SUPPRESSOR_FULL_TYPE = "SimpleSuppressorB42.ImprovisedSuppressor"
local SUPPRESSOR_SOUND_RADIUS_KEY = "SimpleSuppressorB42_SoundRadiusFactor"
local SUPPRESSOR_SOUND_VOLUME_KEY = "SimpleSuppressorB42_SoundVolumeFactor"
local SUPPRESSOR_DURABILITY_VERSION_KEY = "SimpleSuppressorB42_DurabilityVersion"
local SUPPRESSOR_DAMAGE_PER_SHOT_KEY = "SimpleSuppressorB42_DamagePerShot"
local SUPPRESSOR_DAMAGE_BUFFER_KEY = "SimpleSuppressorB42_DamageBuffer"
local SUPPRESSOR_CRAFT_GENERATION_KEY = "SimpleSuppressorB42_ImprovisedCraftGeneration"
local SUPPRESSOR_TIER_KEY = "SimpleSuppressorB42_ImprovisedTier"
local SUPPRESSOR_DISPLAY_NAME_KEY = "SimpleSuppressorB42_ImprovisedDisplayName"
local SUPPRESSOR_EXPECTED_SHOTS_KEY = "SimpleSuppressorB42_ImprovisedExpectedShots"
local SUPPRESSOR_HIT_CHANCE_KEY = "SimpleSuppressorB42_ImprovisedHitChance"
local SUPPRESSOR_AIMING_TIME_KEY = "SimpleSuppressorB42_ImprovisedAimingTime"
local LEGACY_SUPPRESSOR_SHOTS_PER_CONDITION_KEY = "SimpleSuppressorB42_ShotsPerCondition"
local LEGACY_SUPPRESSOR_SHOT_BUFFER_KEY = "SimpleSuppressorB42_ShotBuffer"
local ICON_TEXTURE_NAME = "Item_ImprovisedSuppressor"
local DEFAULT_DISPLAY_NAME = "Improvised Suppressor"

local DATA_VERSION = 4
local CURRENT_CRAFT_GENERATION = 1
local DISPLAY_CONDITION_MAX = 160

local TIER_CRUDE = {
    id = "crude",
    display_name = "Crude Improvised Suppressor",
    expected_shots = 25,
    sound_radius_factor = 0.62,
    sound_volume_factor = 0.48,
    hit_chance = -4,
    aiming_time = 3,
}

local TIER_IMPROVISED = {
    id = "improvised",
    display_name = DEFAULT_DISPLAY_NAME,
    expected_shots = 45,
    sound_radius_factor = 0.50,
    sound_volume_factor = 0.38,
    hit_chance = -2,
    aiming_time = 2,
}

local TIER_WELL_MADE = {
    id = "well_made",
    display_name = "Well-Made Improvised Suppressor",
    expected_shots = 70,
    sound_radius_factor = 0.42,
    sound_volume_factor = 0.32,
    hit_chance = -1,
    aiming_time = 1,
}

local TIER_METALWORKER = {
    id = "metalworker_made",
    display_name = "Metalworker-Made Improvised Suppressor",
    expected_shots = 100,
    sound_radius_factor = 0.35,
    sound_volume_factor = 0.27,
    hit_chance = 0,
    aiming_time = 0,
}

local TIERS = {
    TIER_CRUDE,
    TIER_IMPROVISED,
    TIER_WELL_MADE,
    TIER_METALWORKER,
}
local DEFAULT_DAMAGE_PER_SHOT = DISPLAY_CONDITION_MAX / TIER_IMPROVISED.expected_shots

local function isAuthoritativeContext()
    local client = isClient and isClient() or false
    local server = isServer and isServer() or false
    return server or (not client and not server)
end

local function clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    end

    if value > max_value then
        return max_value
    end

    return value
end

local function round(value)
    return math.floor(value + 0.5)
end

local function isImprovisedSuppressor(item)
    return item and item.getFullType and item:getFullType() == IMPROVISED_SUPPRESSOR_FULL_TYPE
end

local function isCharacterProfession(character, profession)
    local descriptor = character and character.getDescriptor and character:getDescriptor() or nil
    return descriptor and descriptor.isCharacterProfession and descriptor:isCharacterProfession(profession)
end

local function getTierById(tier_id)
    for i = 1, #TIERS do
        local tier = TIERS[i]
        if tier.id == tier_id then
            return tier
        end
    end

    return TIER_IMPROVISED
end

local function getCraftTier(character, metalworking_level)
    local level = metalworking_level or 0
    local engineer_profession = CharacterProfession and CharacterProfession.ENGINEER or nil
    local metalworker_profession = CharacterProfession and CharacterProfession.METALWORKER or nil
    local is_engineer = engineer_profession and isCharacterProfession(character, engineer_profession)
    local is_metalworker = metalworker_profession and isCharacterProfession(character, metalworker_profession)

    if level <= 1 then
        if is_engineer or is_metalworker then
            return TIER_IMPROVISED
        end

        return TIER_CRUDE
    end

    if level <= 3 then
        if is_engineer or is_metalworker then
            return TIER_WELL_MADE
        end

        return TIER_IMPROVISED
    end

    if is_metalworker then
        return TIER_METALWORKER
    end

    return TIER_WELL_MADE
end

local function refreshIconTexture(item)
    if not item or not item.setTexture or not getTexture then
        return false
    end

    local texture = getTexture(ICON_TEXTURE_NAME)
    if not texture then
        texture = getTexture("item_ImprovisedSuppressor")
    end
    if not texture then
        return false
    end

    local current_texture = item:getTex()
    if current_texture and current_texture:getName() == texture:getName() then
        return false
    end

    item:setTexture(texture)
    return true
end

local function getLegacyRemainingFraction(item, mod_data, current_condition, current_max)
    if current_max <= 0 then
        return 1
    end

    local legacy_shots_per_condition = tonumber(mod_data[LEGACY_SUPPRESSOR_SHOTS_PER_CONDITION_KEY])
    if legacy_shots_per_condition and current_max <= 20 then
        local legacy_shot_buffer = tonumber(mod_data[LEGACY_SUPPRESSOR_SHOT_BUFFER_KEY]) or 0
        local total_shots = math.max(current_max * legacy_shots_per_condition, 1)
        local remaining_shots = math.max(current_condition * legacy_shots_per_condition - legacy_shot_buffer, 0)
        return clamp(remaining_shots / total_shots, 0, 1)
    end

    return clamp(current_condition / current_max, 0, 1)
end

local function getExpectedShotsForItem(item, mod_data)
    local expected_shots = tonumber(mod_data[SUPPRESSOR_EXPECTED_SHOTS_KEY])
    if expected_shots and expected_shots > 0 then
        return expected_shots
    end

    local damage_per_shot = tonumber(mod_data[SUPPRESSOR_DAMAGE_PER_SHOT_KEY])
    if damage_per_shot and damage_per_shot > 0 then
        return DISPLAY_CONDITION_MAX / damage_per_shot
    end

    local current_max = item:getConditionMax() or 0
    local legacy_shots_per_condition = tonumber(mod_data[LEGACY_SUPPRESSOR_SHOTS_PER_CONDITION_KEY])
    if legacy_shots_per_condition and current_max > 0 then
        return current_max * legacy_shots_per_condition
    end

    return TIER_IMPROVISED.expected_shots
end

local function getLegacyTier(item, mod_data)
    local expected_shots = getExpectedShotsForItem(item, mod_data)
    local radius_factor = tonumber(mod_data[SUPPRESSOR_SOUND_RADIUS_KEY])
    local volume_factor = tonumber(mod_data[SUPPRESSOR_SOUND_VOLUME_KEY])
    local closest_tier = TIER_IMPROVISED
    local closest_score = math.huge

    for i = 1, #TIERS do
        local tier = TIERS[i]
        local score = math.abs(expected_shots - tier.expected_shots)

        if radius_factor then
            score = score + (math.abs(radius_factor - tier.sound_radius_factor) * 100)
        end

        if volume_factor then
            score = score + (math.abs(volume_factor - tier.sound_volume_factor) * 100)
        end

        if score < closest_score then
            closest_score = score
            closest_tier = tier
        end
    end

    return closest_tier
end

local function applyTierDisplayName(item, tier)
    if not item or not item.setName then
        return false
    end

    local changed = false
    if item:getName() ~= tier.display_name then
        item:setName(tier.display_name)
        changed = true
    end

    local use_custom_name = tier.display_name ~= DEFAULT_DISPLAY_NAME
    if item.setCustomName and item:isCustomName() ~= use_custom_name then
        item:setCustomName(use_custom_name)
        changed = true
    end

    return changed
end

local function applyTierStatsToItem(item, mod_data, tier, remaining_fraction)
    local changed = false
    local target_condition = 0
    local target_damage_per_shot = DISPLAY_CONDITION_MAX / tier.expected_shots

    if remaining_fraction == nil then
        remaining_fraction = 1
    end

    if item:getCondition() <= 0 then
        target_condition = 0
    else
        target_condition = math.max(1, round(DISPLAY_CONDITION_MAX * clamp(remaining_fraction, 0, 1)))
    end

    if item:getConditionMax() ~= DISPLAY_CONDITION_MAX then
        item:setConditionMax(DISPLAY_CONDITION_MAX)
        changed = true
    end

    if item:getCondition() ~= target_condition then
        item:setCondition(target_condition)
        changed = true
    end

    if item.getHitChance and item:getHitChance() ~= tier.hit_chance then
        item:setHitChance(tier.hit_chance)
        changed = true
    end

    if item.getAimingTime and item:getAimingTime() ~= tier.aiming_time then
        item:setAimingTime(tier.aiming_time)
        changed = true
    end

    if mod_data[SUPPRESSOR_TIER_KEY] ~= tier.id then
        changed = true
    end
    mod_data[SUPPRESSOR_TIER_KEY] = tier.id

    if mod_data[SUPPRESSOR_DISPLAY_NAME_KEY] ~= tier.display_name then
        changed = true
    end
    mod_data[SUPPRESSOR_DISPLAY_NAME_KEY] = tier.display_name

    if tonumber(mod_data[SUPPRESSOR_EXPECTED_SHOTS_KEY]) ~= tier.expected_shots then
        changed = true
    end
    mod_data[SUPPRESSOR_EXPECTED_SHOTS_KEY] = tier.expected_shots

    if tonumber(mod_data[SUPPRESSOR_HIT_CHANCE_KEY]) ~= tier.hit_chance then
        changed = true
    end
    mod_data[SUPPRESSOR_HIT_CHANCE_KEY] = tier.hit_chance

    if tonumber(mod_data[SUPPRESSOR_AIMING_TIME_KEY]) ~= tier.aiming_time then
        changed = true
    end
    mod_data[SUPPRESSOR_AIMING_TIME_KEY] = tier.aiming_time

    if tonumber(mod_data[SUPPRESSOR_SOUND_RADIUS_KEY]) ~= tier.sound_radius_factor then
        changed = true
    end
    mod_data[SUPPRESSOR_SOUND_RADIUS_KEY] = tier.sound_radius_factor

    if tonumber(mod_data[SUPPRESSOR_SOUND_VOLUME_KEY]) ~= tier.sound_volume_factor then
        changed = true
    end
    mod_data[SUPPRESSOR_SOUND_VOLUME_KEY] = tier.sound_volume_factor

    if tonumber(mod_data[SUPPRESSOR_DAMAGE_PER_SHOT_KEY]) ~= target_damage_per_shot then
        changed = true
    end
    mod_data[SUPPRESSOR_DAMAGE_PER_SHOT_KEY] = target_damage_per_shot

    if tonumber(mod_data[SUPPRESSOR_DAMAGE_BUFFER_KEY]) ~= 0 then
        changed = true
    end
    mod_data[SUPPRESSOR_DAMAGE_BUFFER_KEY] = 0

    if mod_data[LEGACY_SUPPRESSOR_SHOTS_PER_CONDITION_KEY] ~= nil then
        changed = true
    end
    mod_data[LEGACY_SUPPRESSOR_SHOTS_PER_CONDITION_KEY] = nil

    if mod_data[LEGACY_SUPPRESSOR_SHOT_BUFFER_KEY] ~= nil then
        changed = true
    end
    mod_data[LEGACY_SUPPRESSOR_SHOT_BUFFER_KEY] = nil

    if tonumber(mod_data[SUPPRESSOR_DURABILITY_VERSION_KEY]) ~= DATA_VERSION then
        mod_data[SUPPRESSOR_DURABILITY_VERSION_KEY] = DATA_VERSION
        changed = true
    end

    changed = applyTierDisplayName(item, tier) or changed
    changed = refreshIconTexture(item) or changed

    return changed
end

local function getStoredTier(item, mod_data)
    local stored_tier_id = mod_data[SUPPRESSOR_TIER_KEY]
    if stored_tier_id then
        return getTierById(stored_tier_id)
    end

    local stored_display_name = mod_data[SUPPRESSOR_DISPLAY_NAME_KEY]
    if stored_display_name then
        for i = 1, #TIERS do
            local tier = TIERS[i]
            if tier.display_name == stored_display_name then
                return tier
            end
        end
    end

    return getLegacyTier(item, mod_data)
end

local function isLegacyGrandfathered(mod_data)
    return tonumber(mod_data[SUPPRESSOR_CRAFT_GENERATION_KEY]) ~= CURRENT_CRAFT_GENERATION
end

local function applyLegacyNonDurableState(item, mod_data)
    local tier = getStoredTier(item, mod_data)
    local changed = false

    if mod_data[SUPPRESSOR_TIER_KEY] ~= tier.id then
        mod_data[SUPPRESSOR_TIER_KEY] = tier.id
        changed = true
    end

    if mod_data[SUPPRESSOR_DISPLAY_NAME_KEY] ~= tier.display_name then
        mod_data[SUPPRESSOR_DISPLAY_NAME_KEY] = tier.display_name
        changed = true
    end

    if tonumber(mod_data[SUPPRESSOR_EXPECTED_SHOTS_KEY]) ~= tier.expected_shots then
        mod_data[SUPPRESSOR_EXPECTED_SHOTS_KEY] = tier.expected_shots
        changed = true
    end

    if tonumber(mod_data[SUPPRESSOR_SOUND_RADIUS_KEY]) ~= tier.sound_radius_factor then
        mod_data[SUPPRESSOR_SOUND_RADIUS_KEY] = tier.sound_radius_factor
        changed = true
    end

    if tonumber(mod_data[SUPPRESSOR_SOUND_VOLUME_KEY]) ~= tier.sound_volume_factor then
        mod_data[SUPPRESSOR_SOUND_VOLUME_KEY] = tier.sound_volume_factor
        changed = true
    end

    if tonumber(mod_data[SUPPRESSOR_HIT_CHANCE_KEY]) ~= tier.hit_chance then
        mod_data[SUPPRESSOR_HIT_CHANCE_KEY] = tier.hit_chance
        changed = true
    end

    if tonumber(mod_data[SUPPRESSOR_AIMING_TIME_KEY]) ~= tier.aiming_time then
        mod_data[SUPPRESSOR_AIMING_TIME_KEY] = tier.aiming_time
        changed = true
    end

    if mod_data[SUPPRESSOR_DAMAGE_PER_SHOT_KEY] ~= nil then
        mod_data[SUPPRESSOR_DAMAGE_PER_SHOT_KEY] = nil
        changed = true
    end

    if mod_data[SUPPRESSOR_DAMAGE_BUFFER_KEY] ~= nil then
        mod_data[SUPPRESSOR_DAMAGE_BUFFER_KEY] = nil
        changed = true
    end

    changed = applyTierDisplayName(item, tier) or changed
    changed = refreshIconTexture(item) or changed

    return changed
end

function SimpleSuppressorB42_Improvised.applyCraftQuality(item, character, metalworking_level)
    if not isImprovisedSuppressor(item) or not isAuthoritativeContext() then
        return false
    end

    local mod_data = item:getModData()
    local tier = getCraftTier(character, metalworking_level or 0)

    if item:getCondition() <= 0 then
        item:setCondition(DISPLAY_CONDITION_MAX)
    end

    local changed = applyTierStatsToItem(item, mod_data, tier, 1)
    if tonumber(mod_data[SUPPRESSOR_CRAFT_GENERATION_KEY]) ~= CURRENT_CRAFT_GENERATION then
        mod_data[SUPPRESSOR_CRAFT_GENERATION_KEY] = CURRENT_CRAFT_GENERATION
        changed = true
    end

    return changed
end

function SimpleSuppressorB42_Improvised.ensureItemState(item, allow_condition_migration)
    if not isImprovisedSuppressor(item) or not isAuthoritativeContext() then
        return false
    end

    local mod_data = item:getModData()
    if isLegacyGrandfathered(mod_data) then
        return applyLegacyNonDurableState(item, mod_data)
    end

    local changed = false
    local tier = nil

    if allow_condition_migration and (
        item:getConditionMax() ~= DISPLAY_CONDITION_MAX or
        tonumber(mod_data[SUPPRESSOR_DURABILITY_VERSION_KEY]) ~= DATA_VERSION or
        tonumber(mod_data[SUPPRESSOR_DAMAGE_PER_SHOT_KEY]) == nil or
        mod_data[SUPPRESSOR_TIER_KEY] == nil or
        tonumber(mod_data[SUPPRESSOR_SOUND_RADIUS_KEY]) == nil or
        tonumber(mod_data[SUPPRESSOR_SOUND_VOLUME_KEY]) == nil or
        tonumber(mod_data[SUPPRESSOR_HIT_CHANCE_KEY]) == nil or
        tonumber(mod_data[SUPPRESSOR_AIMING_TIME_KEY]) == nil
    ) then
        local current_condition = item:getCondition() or 0
        local current_max = item:getConditionMax() or 0
        local remaining_fraction = getLegacyRemainingFraction(item, mod_data, current_condition, current_max)

        tier = getStoredTier(item, mod_data)
        changed = applyTierStatsToItem(item, mod_data, tier, remaining_fraction) or changed
    else
        tier = getStoredTier(item, mod_data)
        changed = applyTierDisplayName(item, tier) or changed

        if tonumber(mod_data[SUPPRESSOR_SOUND_RADIUS_KEY]) == nil then
            mod_data[SUPPRESSOR_SOUND_RADIUS_KEY] = tier.sound_radius_factor
            changed = true
        end

        if tonumber(mod_data[SUPPRESSOR_SOUND_VOLUME_KEY]) == nil then
            mod_data[SUPPRESSOR_SOUND_VOLUME_KEY] = tier.sound_volume_factor
            changed = true
        end

        local stored_hit_chance = tonumber(mod_data[SUPPRESSOR_HIT_CHANCE_KEY])
        if stored_hit_chance == nil then
            stored_hit_chance = tier.hit_chance
            mod_data[SUPPRESSOR_HIT_CHANCE_KEY] = stored_hit_chance
            changed = true
        end
        if stored_hit_chance ~= nil and item.getHitChance and item:getHitChance() ~= stored_hit_chance then
            item:setHitChance(stored_hit_chance)
            changed = true
        end

        local stored_aiming_time = tonumber(mod_data[SUPPRESSOR_AIMING_TIME_KEY])
        if stored_aiming_time == nil then
            stored_aiming_time = tier.aiming_time
            mod_data[SUPPRESSOR_AIMING_TIME_KEY] = stored_aiming_time
            changed = true
        end
        if stored_aiming_time ~= nil and item.getAimingTime and item:getAimingTime() ~= stored_aiming_time then
            item:setAimingTime(stored_aiming_time)
            changed = true
        end

        if tonumber(mod_data[SUPPRESSOR_DAMAGE_BUFFER_KEY]) == nil then
            mod_data[SUPPRESSOR_DAMAGE_BUFFER_KEY] = 0
            changed = true
        end

        if refreshIconTexture(item) then
            changed = true
        end
    end

    return changed
end

function SimpleSuppressorB42_Improvised.consumeShot(item)
    if not isImprovisedSuppressor(item) then
        return false, false
    end

    local mod_data = item:getModData()
    if isLegacyGrandfathered(mod_data) then
        return false, false
    end

    local damage_per_shot = tonumber(mod_data[SUPPRESSOR_DAMAGE_PER_SHOT_KEY]) or DEFAULT_DAMAGE_PER_SHOT
    local damage_buffer = tonumber(mod_data[SUPPRESSOR_DAMAGE_BUFFER_KEY]) or 0

    damage_buffer = damage_buffer + damage_per_shot
    local condition_loss = math.floor(damage_buffer)
    if condition_loss <= 0 then
        mod_data[SUPPRESSOR_DAMAGE_BUFFER_KEY] = damage_buffer
        return false, false
    end

    mod_data[SUPPRESSOR_DAMAGE_BUFFER_KEY] = damage_buffer - condition_loss

    local next_condition = math.max((item:getCondition() or 0) - condition_loss, 0)
    item:setCondition(next_condition)

    return true, next_condition <= 0
end
