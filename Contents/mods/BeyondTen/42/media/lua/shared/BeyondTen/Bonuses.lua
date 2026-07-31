require "BeyondTen/Shared"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISReloadWeaponAction"

local BT = BeyondTen

BT._bonusPlayersB42 = BT._bonusPlayersB42 or setmetatable({}, { __mode = "k" })
BT._maintenanceAttacksB42 = BT._maintenanceAttacksB42 or setmetatable({}, { __mode = "k" })
BT._maintenanceTrackersB42 = BT._maintenanceTrackersB42 or setmetatable({}, { __mode = "k" })
BT._scaledWeaponsB42 = BT._scaledWeaponsB42 or setmetatable({}, { __mode = "k" })

local maintenanceGeneration = 0

local EXACT_ACTION_PERKS = {
    ISAddItemInRecipe = Perks.Cooking,
    ISApplyBandage = Perks.Doctor,
    ISCleanBurn = Perks.Doctor,
    ISComfreyCataplasm = Perks.Doctor,
    ISDisinfect = Perks.Doctor,
    ISGarlicCataplasm = Perks.Doctor,
    ISMedicalCheckAction = Perks.Doctor,
    ISPlantainCataplasm = Perks.Doctor,
    ISRemoveBullet = Perks.Doctor,
    ISRemoveGlass = Perks.Doctor,
    ISSplint = Perks.Doctor,
    ISStitch = Perks.Doctor,
    ISFixGenerator = Perks.Electricity,
    ISLightActions = Perks.Electricity,
    ISRepairClothing = Perks.Tailoring,
    ISRemovePatch = Perks.Tailoring,
    ISCheckFishingNetAction = Perks.Fishing,
    ISForageAction = Perks.PlantScavenging,
    ISCheckTrapAction = Perks.Trapping,
    ISAddBaitAction = Perks.Trapping,
    ISRemoveBaitAction = Perks.Trapping,
    ISRemoveTrapAction = Perks.Trapping,
    ISPlaceTrap = Perks.Trapping,
    ISTakeTrap = Perks.Trapping,
    ISCurePlantAction = Perks.Farming,
    ISFertilizeAction = Perks.Farming,
    ISHarvestPlantAction = Perks.Farming,
    ISPlantInfoAction = Perks.Farming,
    ISPlowAction = Perks.Farming,
    ISSeedActionNew = Perks.Farming,
    ISShovelAction = Perks.Farming,
    ISWaterPlantAction = Perks.Farming,
    ISBuildAction = Perks.Woodwork,
    ISMultiStageBuild = Perks.Woodwork,
    ISBarricadeAction = Perks.Woodwork,
    ISUnbarricadeAction = Perks.Woodwork,
    ISPlasterAction = Perks.Woodwork,
    ISRemoveBurntVehicle = Perks.MetalWelding,
}

local function isLocalPlayer(player)
    if not player then return false end
    for playerIndex = 0, getNumActivePlayers() - 1 do
        if getSpecificPlayer(playerIndex) == player then return true end
    end
    return false
end

local function actionTypeOf(action)
    return tostring(action and (action.Type or action.type) or "")
end

local function recipePerk(action)
    local recipe = action and (action.craftRecipe or action.recipe)
    if not recipe or not recipe.getRequiredSkillCount then return nil end

    local bestPerk = nil
    local bestRanks = 0
    for index = 0, recipe:getRequiredSkillCount() - 1 do
        local requiredSkill = recipe:getRequiredSkill(index)
        local perk = requiredSkill and requiredSkill:getPerk() or nil
        local ranks = perk and BT.GetMasteryRanks(action.character, perk) or 0
        if ranks > bestRanks then
            bestRanks = ranks
            bestPerk = perk
        end
    end
    return bestPerk
end

function BT.ResolveActionPerk(action)
    if not action then return nil end
    local explicit = BT.ResolvePerk(action.BeyondTenPerk)
    if explicit then return explicit end

    local actionType = actionTypeOf(action)
    local registered = BT._actionPerks[actionType]
    if registered then return registered end

    if actionType == "ISBarricadeAction" then
        if action.isMetal or action.isMetalBar then return Perks.MetalWelding end
        return Perks.Woodwork
    elseif actionType == "ISUnbarricadeAction" and action.item then
        local barricade = action.item:getBarricadeForCharacter(action.character)
        if barricade and (barricade:isMetal() or barricade:isMetalBar()) then
            return Perks.MetalWelding
        end
        return Perks.Woodwork
    end

    if EXACT_ACTION_PERKS[actionType] then return EXACT_ACTION_PERKS[actionType] end
    local fromRecipe = recipePerk(action)
    if fromRecipe then return fromRecipe end

    if string.find(actionType, "VehiclePart", 1, true)
        or string.find(actionType, "Engine", 1, true)
        or string.find(actionType, "Mechanic", 1, true) then
        return Perks.Mechanics
    end
    if string.find(actionType, "Weld", 1, true) then return Perks.MetalWelding end
    if string.find(actionType, "Build", 1, true)
        or string.find(actionType, "Barricade", 1, true) then
        return Perks.Woodwork
    end
    return nil
end

local function installTimedActionBonus()
    if ISBaseTimedAction.adjustMaxTime == BT._timedActionBonusWrapperB42 then return end
    local originalAdjustMaxTime = ISBaseTimedAction.adjustMaxTime
    if type(originalAdjustMaxTime) ~= "function" then return end

    BT._timedActionBonusWrapperB42 = function(action, maxTime)
        local adjusted = originalAdjustMaxTime(action, maxTime)
        -- B42 uses zero as a second instant-action sentinel (for example
        -- ISPlantInfoAction). Never turn an already-instant action into a
        -- one-tick action while extending mastery timing.
        if adjusted <= 0 or not action.character then return adjusted end
        local perk = BT.ResolveActionPerk(action)
        local ranks = perk and BT.GetMasteryRanks(action.character, perk) or 0
        if ranks <= 0 then return adjusted end
        return math.max(1, adjusted * (1 - 0.025 * ranks))
    end
    ISBaseTimedAction.adjustMaxTime = BT._timedActionBonusWrapperB42
end

local function installReloadingBonus()
    if ISReloadWeaponAction.setReloadSpeed == BT._reloadingBonusWrapperB42 then return end
    local originalSetReloadSpeed = ISReloadWeaponAction.setReloadSpeed
    if type(originalSetReloadSpeed) ~= "function" then return end

    BT._reloadingBonusWrapperB42 = function(character, rack)
        originalSetReloadSpeed(character, rack)
        local ranks = BT.GetMasteryRanks(character, Perks.Reloading)
        if ranks <= 0 then return end

        local rate = rack and 0.04 or 0.10
        local panicPenalty = rack and 0
            or character:getMoodles():getMoodleLevel(MoodleType.PANIC) * 0.05
        local nativeBase = math.max(0.1,
            0.8 + BT.GetNativeLevel(character, Perks.Reloading) * rate - panicPenalty)
        local extendedBase = nativeBase + ranks * rate
        local currentSpeed = character:getVariableFloat("ReloadSpeed", 1.0)
        character:setVariable("ReloadSpeed", currentSpeed * (extendedBase / nativeBase))
    end
    ISReloadWeaponAction.setReloadSpeed = BT._reloadingBonusWrapperB42
end

local VANILLA_WEAPON_PERKS = {
    { category = WeaponCategory.AXE, perk = Perks.Axe },
    { category = WeaponCategory.BLUNT, perk = Perks.Blunt },
    { category = WeaponCategory.SMALL_BLUNT, perk = Perks.SmallBlunt },
    { category = WeaponCategory.LONG_BLADE, perk = Perks.LongBlade },
    { category = WeaponCategory.SMALL_BLADE, perk = Perks.SmallBlade },
    { category = WeaponCategory.SPEAR, perk = Perks.Spear },
}

local function resolveCustomCategory(category)
    if not category then return nil end
    local candidates = {}
    local function addCandidate(value)
        value = value and tostring(value) or nil
        if not value or value == "" then return end
        candidates[#candidates + 1] = value
        local separator = string.find(value, ":", 1, true)
        if separator then candidates[#candidates + 1] = string.sub(value, separator + 1) end
    end

    local okName, translationName = pcall(function() return category:getTranslationName() end)
    if okName then addCandidate(translationName) end
    local okId, id = pcall(function() return category:toString() end)
    if okId then addCandidate(id) end

    for _, candidate in ipairs(candidates) do
        local perk = BT.ResolvePerk(candidate)
        local okCustom, custom = pcall(function() return perk and perk:isCustom() end)
        if perk and okCustom and custom and BT.IsTrainablePerk(perk) then return perk end
    end
    return nil
end

local function customCategoryPerk(scriptItem)
    if not scriptItem then return nil end
    local categories = scriptItem:getWeaponCategories()
    if not categories then return nil end
    local iterator = categories:iterator()
    while iterator:hasNext() do
        local perk = resolveCustomCategory(iterator:next())
        if perk then return perk end
    end
    return nil
end

local function weaponPerk(weapon)
    if not weapon then return nil end
    local scriptItem = weapon:getScriptItem()
    if weapon:isRanged() then
        return customCategoryPerk(scriptItem) or Perks.Aiming
    end
    if scriptItem then
        for _, mapping in ipairs(VANILLA_WEAPON_PERKS) do
            if scriptItem:containsWeaponCategory(mapping.category) then return mapping.perk end
        end
    end
    return customCategoryPerk(scriptItem)
end

local function weaponTypeId(weapon)
    if not weapon then return nil end
    local ok, fullType = pcall(function() return weapon:getFullType() end)
    return ok and fullType and tostring(fullType) or nil
end

local function trackMaintenanceAttack(player, weapon)
    if not player or not weapon or weapon:isUseSelf() then return end
    local ranks = BT.GetMasteryRanks(player, Perks.Maintenance)
    local condition = tonumber(weapon:getCondition()) or 0
    if ranks <= 0 or condition <= 0 then return end

    local current = BT._maintenanceAttacksB42[player]
    if current and current.weapon == weapon then return end
    BT._maintenanceAttacksB42[player] = {
        weapon = weapon,
        fullType = weaponTypeId(weapon),
        conditionBefore = condition,
        wasPrimary = player:getPrimaryHandItem() == weapon,
        wasSecondary = player:getSecondaryHandItem() == weapon,
    }
end

local function onPlayerAttackFinished(player, eventWeapon)
    if not player or not isLocalPlayer(player) then return end
    local attack = BT._maintenanceAttacksB42[player]
    BT._maintenanceAttacksB42[player] = nil
    if not attack then return end

    local candidates = {}
    local function addCandidate(item)
        if not item or not instanceof(item, "HandWeapon") then return end
        for _, existing in ipairs(candidates) do
            if existing == item then return end
        end
        candidates[#candidates + 1] = item
    end
    addCandidate(attack.weapon)
    addCandidate(eventWeapon)
    addCandidate(player:getPrimaryHandItem())
    addCandidate(player:getSecondaryHandItem())

    local candidate = nil
    local lowestCondition = attack.conditionBefore
    for _, item in ipairs(candidates) do
        local sameType = item == attack.weapon
            or (attack.fullType and weaponTypeId(item) == attack.fullType)
        local condition = tonumber(item:getCondition()) or attack.conditionBefore
        if sameType and condition < lowestCondition then
            candidate = item
            lowestCondition = condition
        end
    end
    if not candidate then return end

    local ranks = BT.GetMasteryRanks(player, Perks.Maintenance)
    local restored = 0
    for _index = 1, math.max(0, attack.conditionBefore - lowestCondition) do
        if ranks > 0 and ZombRand(100) < ranks * 6 then restored = restored + 1 end
    end
    if restored <= 0 then return end

    candidate:setCondition(math.min(candidate:getConditionMax(), lowestCondition + restored))
    -- B42 non-melee condition loss is owned by the MP client. Send the
    -- successful restoration through the same reliable item-field channel so
    -- the authoritative inventory copy receives the final condition.
    if isClient() then candidate:syncItemFields() end
    local inventory = player:getInventory()
    if lowestCondition <= 0 and inventory and inventory:contains(candidate) then
        if attack.wasPrimary then player:setPrimaryHandItem(candidate) end
        if attack.wasSecondary then player:setSecondaryHandItem(candidate) end
    end
end

local function restoreScaledWeapons()
    for weapon, original in pairs(BT._scaledWeaponsB42) do
        if weapon and original then
            weapon:setMinDamage(original.minDamage)
            weapon:setMaxDamage(original.maxDamage)
        end
        BT._scaledWeaponsB42[weapon] = nil
    end
end

local function maintenanceCondition(weapon)
    return math.max(0, math.floor(tonumber(weapon:getCondition()) or 0))
end

local function processServerMaintenanceLoss(weapon, record)
    local current = maintenanceCondition(weapon)
    local previous = math.max(0, math.floor(tonumber(record.condition) or current))
    local lost = math.max(0, previous - current)
    if lost <= 0 then
        record.condition = current
        return
    end

    local ranks = math.max(0, math.floor(tonumber(record.ranks) or 0))
    local chance = math.min(30, ranks * 6)
    local restored = 0
    for _index = 1, lost do
        if chance > 0 and ZombRand(100) < chance then restored = restored + 1 end
    end

    if restored > 0 then
        local conditionMax = math.max(0, math.floor(tonumber(weapon:getConditionMax()) or 0))
        local desired = math.min(conditionMax, current + restored)
        if desired > current then
            weapon:setCondition(desired)
            weapon:syncItemFields()
            local owner = record.owner
            local inventory = owner and owner:getInventory() or nil
            if current <= 0 and inventory and inventory:contains(weapon) then
                if record.wasPrimary then owner:setPrimaryHandItem(weapon) end
                if record.wasSecondary then owner:setSecondaryHandItem(weapon) end
            end
            current = desired
        end
    end
    record.condition = current
end

local function trackServerMaintenanceWeapon(player, weapon, generation)
    -- B42 melee/tree condition loss is authoritative on the server. Non-melee
    -- loss is client-owned and is handled by the attack-finished restoration.
    if not player or not weapon or not instanceof(weapon, "HandWeapon")
        or not weapon:isMelee() then return end

    local record = BT._maintenanceTrackersB42[weapon]
    if record then processServerMaintenanceLoss(weapon, record) end

    local ranks = BT.GetMasteryRanks(player, Perks.Maintenance)
    if ranks <= 0 then
        BT._maintenanceTrackersB42[weapon] = nil
        return
    end
    if not record then
        record = {}
        BT._maintenanceTrackersB42[weapon] = record
    end

    record.owner = player
    record.ranks = ranks
    record.condition = maintenanceCondition(weapon)
    record.wasPrimary = player:getPrimaryHandItem() == weapon
    record.wasSecondary = player:getSecondaryHandItem() == weapon
    record.seen = generation
end

local function updateMaintenanceProtection(player, generation)
    local primary = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()
    trackServerMaintenanceWeapon(player, primary, generation)
    if secondary ~= primary then trackServerMaintenanceWeapon(player, secondary, generation) end
end

local function processUnseenMaintenanceTrackers(generation)
    for weapon, record in pairs(BT._maintenanceTrackersB42) do
        if record.seen ~= generation then
            -- A last-point break may remove the weapon from both hands before
            -- OnTick. Process that pending decrease before forgetting it.
            processServerMaintenanceLoss(weapon, record)
            BT._maintenanceTrackersB42[weapon] = nil
        end
    end
end

local function onServerWeaponMaintenanceEvent(owner, weapon)
    if not isServer() then return end
    -- OnWeaponHitXp is pre-loss for character hits; the next invocation first
    -- settles any preceding multi-hit loss. OnWeaponHitTree is post-loss and
    -- therefore settles an existing tracker immediately. Polling remains the
    -- fallback for objects, vehicles and the final hit in a sequence.
    trackServerMaintenanceWeapon(owner, weapon, maintenanceGeneration)
end

local function onWeaponSwingHitPoint(attacker, weapon)
    -- B42 calculates a local player's hit and packet immediately after this
    -- event. Dedicated-server remote players do not traverse the same melee
    -- path, so handling only local players avoids a second multiplier in MP.
    if not attacker or not weapon or not isLocalPlayer(attacker) then return end
    if attacker:isDoShove() and not attacker:isAimAtFloor() then return end
    -- Native B42 MP melee durability is server-owned and protected by the
    -- post-loss tracker above. Non-melee durability remains client-owned; SP
    -- keeps the original attack-finished restoration for every weapon.
    if not isClient() or not weapon:isMelee() then
        trackMaintenanceAttack(attacker, weapon)
    end

    local perk = weaponPerk(weapon)
    local weaponRanks = perk and BT.GetMasteryRanks(attacker, perk) or 0
    local strengthRanks = weapon:isRanged() and 0
        or BT.GetMasteryRanks(attacker, Perks.Strength)
    local bonusFraction = weaponRanks * 0.03 + strengthRanks * 0.02
    if bonusFraction <= 0 then return end

    local minDamage = tonumber(weapon:getMinDamage())
    local maxDamage = tonumber(weapon:getMaxDamage())
    if not BT.IsFinite(minDamage) or not BT.IsFinite(maxDamage) then return end
    if minDamage < 0 or maxDamage < minDamage then return end

    local previous = BT._scaledWeaponsB42[weapon]
    if previous then
        weapon:setMinDamage(previous.minDamage)
        weapon:setMaxDamage(previous.maxDamage)
        minDamage = previous.minDamage
        maxDamage = previous.maxDamage
    end

    BT._scaledWeaponsB42[weapon] = { minDamage = minDamage, maxDamage = maxDamage }
    local factor = 1 + bonusFraction
    weapon:setMinDamage(minDamage * factor)
    weapon:setMaxDamage(maxDamage * factor)
end

local function updateCarryCapacity(player, state)
    local ranks = BT.GetMasteryRanks(player, Perks.Strength)
    if isServer() then
        -- B42 PlayerDamage packets carry maxWeight in both directions. Always
        -- rebuild the authoritative vanilla value on the server before adding
        -- mastery, so an echoed/stale mastered value can never become a base.
        local bodyDamage = player:getBodyDamage()
        if bodyDamage then bodyDamage:UpdateStrength() end
        local base = tonumber(player:getMaxWeight()) or 0
        local desired = math.max(0, math.floor(base + ranks + 0.5))
        if base ~= desired then player:setMaxWeight(desired) end
        state.lastCarryBase = base
        state.lastCarryValue = desired
        return
    end

    if state.lastCarryValue == nil then
        -- PlayerDamagePacket carries maxWeight in both directions. On the
        -- first MP frame it may already contain the server's previously
        -- mastered value. Rebuild vanilla capacity once before choosing our
        -- baseline, otherwise five mastery ranks could be added twice.
        local bodyDamage = player:getBodyDamage()
        if bodyDamage then bodyDamage:UpdateStrength() end
    end
    local current = tonumber(player:getMaxWeight()) or 0
    local base = current
    if state.lastCarryValue ~= nil and current == state.lastCarryValue then
        base = state.lastCarryBase
    end
    local desired = math.max(0, math.floor(base + ranks + 0.5))
    if current ~= desired then player:setMaxWeight(desired) end
    state.lastCarryBase = base
    state.lastCarryValue = desired
end

local function updateEndurance(player, state)
    local stats = player:getStats()
    if not stats then return end
    local current = BT.Clamp(stats:get(CharacterStat.ENDURANCE), 0, 1)
    local previous = state.lastEndurance
    if previous == nil then
        state.lastEndurance = current
        return
    end

    local delta = current - previous
    if delta < 0 then
        local protection = BT.GetMasteryRanks(player, Perks.Fitness) * 0.02
        if player:isRunning() or player:isSprinting() then
            protection = protection + BT.GetMasteryRanks(player, Perks.Sprinting) * 0.02
        end
        if player:isPlayerMoving() and player:isAiming() then
            protection = protection + BT.GetMasteryRanks(player, Perks.Nimble) * 0.015
        end
        if player:isPlayerMoving() and player:isSneaking() then
            protection = protection + BT.GetMasteryRanks(player, Perks.Sneak) * 0.01
            protection = protection + BT.GetMasteryRanks(player, Perks.Lightfoot) * 0.01
        end
        current = current + (-delta) * math.min(0.35, protection)
    elseif delta > 0 then
        local recovery = BT.GetMasteryRanks(player, Perks.Fitness) * 0.02
        current = current + delta * math.min(0.15, recovery)
    end

    current = BT.Clamp(current, 0, 1)
    if math.abs(current - stats:get(CharacterStat.ENDURANCE)) > 0.000001 then
        stats:set(CharacterStat.ENDURANCE, current)
    end
    state.lastEndurance = current
end

local function updatePlayerBonuses(player, generation)
    if not player or player:isDead() then return end
    local state = BT._bonusPlayersB42[player]
    if not state then
        state = {}
        BT._bonusPlayersB42[player] = state
    end
    if not isClient() then
        updateCarryCapacity(player, state)
    end
    if isServer() then updateMaintenanceProtection(player, generation) end
    -- PlayerStatsPacket is server-to-client in B42. Applying the delta-based
    -- endurance adapter again on an MP client would compound a server bonus
    -- whenever a stats packet arrives. SP and the server are authoritative.
    if not isClient() then updateEndurance(player, state) end
end

local function updatePlayers()
    maintenanceGeneration = maintenanceGeneration + 1
    local generation = maintenanceGeneration
    if isServer() then
        local players = getOnlinePlayers()
        if not players then
            processUnseenMaintenanceTrackers(generation)
            return
        end
        for index = 0, players:size() - 1 do updatePlayerBonuses(players:get(index), generation) end
        processUnseenMaintenanceTrackers(generation)
        return
    end
    for playerIndex = 0, getNumActivePlayers() - 1 do
        updatePlayerBonuses(getSpecificPlayer(playerIndex), generation)
    end
    processUnseenMaintenanceTrackers(generation)
end

local function onTick()
    restoreScaledWeapons()
    updatePlayers()
end

local function resetBonusRuntime()
    restoreScaledWeapons()
    BT._bonusPlayersB42 = setmetatable({}, { __mode = "k" })
    BT._maintenanceAttacksB42 = setmetatable({}, { __mode = "k" })
    BT._maintenanceTrackersB42 = setmetatable({}, { __mode = "k" })
    BT._scaledWeaponsB42 = setmetatable({}, { __mode = "k" })
    maintenanceGeneration = 0
    installTimedActionBonus()
    installReloadingBonus()
end

installTimedActionBonus()
installReloadingBonus()

if not BT._bonusEventsB42Installed then
    BT._bonusEventsB42Installed = true
    Events.OnWeaponSwingHitPoint.Add(onWeaponSwingHitPoint)
    Events.OnPlayerAttackFinished.Add(onPlayerAttackFinished)
    Events.OnTick.Add(onTick)
    if isServer() then
        Events.OnServerStarted.Add(resetBonusRuntime)
        Events.OnWeaponHitXp.Add(onServerWeaponMaintenanceEvent)
        Events.OnWeaponHitTree.Add(onServerWeaponMaintenanceEvent)
    else
        Events.OnGameStart.Add(resetBonusRuntime)
    end
end

print("[BeyondTen/B42] mastery bonuses installed")
