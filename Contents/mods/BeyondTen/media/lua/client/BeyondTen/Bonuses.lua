require "BeyondTen/Shared"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISReloadWeaponAction"

local BT = BeyondTen

BT._bonusPlayers = BT._bonusPlayers or setmetatable({}, { __mode = "k" })
BT._maintenanceAttacks = BT._maintenanceAttacks or setmetatable({}, { __mode = "k" })
BT._scaledWeapons = BT._scaledWeapons or setmetatable({}, { __mode = "k" })

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
    ISRipClothing = Perks.Tailoring,
    ISFishingAction = Perks.Fishing,
    ISCheckFishingNetAction = Perks.Fishing,
    ISForageAction = Perks.PlantScavenging,
    ISScavengeAction = Perks.PlantScavenging,
    ISCheckTrapAction = Perks.Trapping,
    ISAddBaitAction = Perks.Trapping,
    ISRemoveBaitAction = Perks.Trapping,
    ISRemoveTrapAction = Perks.Trapping,
    ISPlaceTrap = Perks.Trapping,
    ISTakeTrap = Perks.Trapping,
    ISCureFliesAction = Perks.Farming,
    ISCureMildewAction = Perks.Farming,
    ISFertilizeAction = Perks.Farming,
    ISHarvestPlantAction = Perks.Farming,
    ISPlantInfoAction = Perks.Farming,
    ISPlowAction = Perks.Farming,
    ISSeedAction = Perks.Farming,
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
    local recipe = action and action.recipe
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

    if actionType == "ISMultiStageBuild" and action.stage then
        local bestPerk = nil
        local bestRanks = -1
        local stagePerks = action.stage:getPerksLua()
        for perkId, _requiredLevel in pairs(stagePerks or {}) do
            local perk = BT.ResolvePerk(perkId)
            local ranks = perk and BT.GetMasteryRanks(action.character, perk) or 0
            if perk and ranks > bestRanks then
                bestRanks = ranks
                bestPerk = perk
            end
        end
        if bestPerk then return bestPerk end
    elseif actionType == "ISBarricadeAction" then
        if action.isMetal or action.isMetalBar then return Perks.MetalWelding end
        return Perks.Woodwork
    elseif actionType == "ISUnbarricadeAction" and action.item then
        local barricade = action.item:getBarricadeForCharacter(action.character)
        if barricade and (barricade:isMetal() or barricade:isMetalBar()) then return Perks.MetalWelding end
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
    if ISBaseTimedAction.adjustMaxTime == BT._timedActionBonusWrapper then return end

    local originalAdjustMaxTime = ISBaseTimedAction.adjustMaxTime
    if type(originalAdjustMaxTime) ~= "function" then return end
    BT._timedActionBonusWrapper = function(action, maxTime)
        local adjusted = originalAdjustMaxTime(action, maxTime)
        if adjusted == -1 or not action.character then return adjusted end

        local perk = BT.ResolveActionPerk(action)
        local ranks = perk and BT.GetMasteryRanks(action.character, perk) or 0
        if ranks <= 0 then return adjusted end
        return math.max(1, adjusted * (1 - 0.025 * ranks))
    end
    ISBaseTimedAction.adjustMaxTime = BT._timedActionBonusWrapper
end

local function installReloadingBonus()
    if ISReloadWeaponAction.setReloadSpeed == BT._reloadingBonusWrapper then return end

    local originalSetReloadSpeed = ISReloadWeaponAction.setReloadSpeed
    if type(originalSetReloadSpeed) ~= "function" then return end
    BT._reloadingBonusWrapper = function(character, rack)
        originalSetReloadSpeed(character, rack)
        local ranks = BT.GetMasteryRanks(character, Perks.Reloading)
        if ranks <= 0 then return end

        local rate = rack and 0.03 or 0.07
        local panicPenalty = rack and 0 or character:getMoodles():getMoodleLevel(MoodleType.Panic) * 0.05
        local nativeBase = math.max(0.1, 1 + BT.GetNativeLevel(character, Perks.Reloading) * rate - panicPenalty)
        local extendedBase = nativeBase + ranks * rate
        local currentSpeed = character:getVariableFloat("ReloadSpeed", 1)
        character:setVariable("ReloadSpeed", currentSpeed * (extendedBase / nativeBase))
    end
    ISReloadWeaponAction.setReloadSpeed = BT._reloadingBonusWrapper
end

local function weaponPerk(weapon)
    if not weapon then return nil end

    local scriptItem = weapon:getScriptItem()
    local categories = scriptItem and scriptItem:getCategories() or nil
    local categoryMap = {
        Axe = Perks.Axe,
        Blunt = Perks.Blunt,
        SmallBlunt = Perks.SmallBlunt,
        LongBlade = Perks.LongBlade,
        SmallBlade = Perks.SmallBlade,
        Spear = Perks.Spear,
    }

    if weapon:isRanged() then
        -- Brita/GunFighter firearms may also carry Spear or SmallBlunt for a
        -- bayonet/stock. Only a genuinely custom category may override Aiming
        -- on a ranged weapon; vanilla melee tags must not do so.
        if categories then
            for index = 0, categories:size() - 1 do
                local customPerk = BT.ResolvePerk(tostring(categories:get(index)))
                local ok, isCustom = pcall(function() return customPerk and customPerk:isCustom() end)
                if ok and isCustom and BT.IsTrainablePerk(customPerk) then return customPerk end
            end
        end
        return Perks.Aiming
    end

    for category, perk in pairs(categoryMap) do
        if categories and categories:contains(category) then return perk end
    end

    if categories then
        for index = 0, categories:size() - 1 do
            local customPerk = BT.ResolvePerk(tostring(categories:get(index)))
            if customPerk and BT.IsTrainablePerk(customPerk) then return customPerk end
        end
    end
    return nil
end

local function weaponTypeId(weapon)
    if not weapon then return nil end
    local ok, fullType = pcall(function() return weapon:getFullType() end)
    if ok and fullType then return tostring(fullType) end
    return nil
end

local function trackMaintenanceAttack(player, weapon)
    if not player or not weapon or weapon:isUseSelf() then return end
    local ranks = BT.GetMasteryRanks(player, Perks.Maintenance)
    local condition = tonumber(weapon:getCondition()) or 0
    if ranks <= 0 or condition <= 0 then return end

    local current = BT._maintenanceAttacks[player]
    if current and current.weapon == weapon then return end
    BT._maintenanceAttacks[player] = {
        weapon = weapon,
        fullType = weaponTypeId(weapon),
        conditionBefore = condition,
        wasPrimary = player:getPrimaryHandItem() == weapon,
        wasSecondary = player:getSecondaryHandItem() == weapon,
    }
end

local function onPlayerAttackFinished(player, eventWeapon)
    if not player or not isLocalPlayer(player) then return end
    local attack = BT._maintenanceAttacks[player]
    BT._maintenanceAttacks[player] = nil
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
    -- Native B41 removes a weapon from the hands as soon as condition reaches
    -- zero. If mastery restored it, put that exact instance back where it was.
    local inventory = player:getInventory()
    if lowestCondition <= 0 and inventory and inventory:contains(candidate) then
        if attack.wasPrimary then player:setPrimaryHandItem(candidate) end
        if attack.wasSecondary then player:setSecondaryHandItem(candidate) end
    end
end

local function restoreScaledWeapons()
    for weapon, original in pairs(BT._scaledWeapons) do
        if weapon and original then
            weapon:setMinDamage(original.minDamage)
            weapon:setMaxDamage(original.maxDamage)
        end
        BT._scaledWeapons[weapon] = nil
    end
end

local function onWeaponSwingHitPoint(attacker, weapon)
    if not attacker or not weapon or not isLocalPlayer(attacker) then return end
    if attacker:isDoShove() and not attacker:isAimAtFloor() then return end
    trackMaintenanceAttack(attacker, weapon)

    local perk = weaponPerk(weapon)
    local weaponRanks = perk and BT.GetMasteryRanks(attacker, perk) or 0
    local strengthRanks = weapon:isRanged() and 0 or BT.GetMasteryRanks(attacker, Perks.Strength)
    local bonusFraction = weaponRanks * 0.03 + strengthRanks * 0.02
    if bonusFraction <= 0 then return end

    -- ConnectSwing fires this event immediately before it reads min/max damage
    -- and resolves every target. Restoring on OnTick keeps death handling, hit
    -- packets, kill credit and modded NPC damage inside the native attack path.
    local minDamage = tonumber(weapon:getMinDamage())
    local maxDamage = tonumber(weapon:getMaxDamage())
    if not BT.IsFinite(minDamage) or not BT.IsFinite(maxDamage) then return end
    if minDamage < 0 or maxDamage < minDamage then return end

    -- A weapon cannot normally connect twice before the next OnTick, but undo
    -- a stale scale defensively before applying a fresh mastery multiplier.
    local previous = BT._scaledWeapons[weapon]
    if previous then
        weapon:setMinDamage(previous.minDamage)
        weapon:setMaxDamage(previous.maxDamage)
        minDamage = previous.minDamage
        maxDamage = previous.maxDamage
    end

    local factor = 1 + bonusFraction
    BT._scaledWeapons[weapon] = {
        minDamage = minDamage,
        maxDamage = maxDamage,
    }
    weapon:setMinDamage(minDamage * factor)
    weapon:setMaxDamage(maxDamage * factor)
end

local function updateCarryCapacity(player, state)
    local ranks = BT.GetMasteryRanks(player, Perks.Strength)
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
    local current = BT.Clamp(stats:getEndurance(), 0, 1)
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
    if math.abs(current - stats:getEndurance()) > 0.000001 then stats:setEndurance(current) end
    state.lastEndurance = current
end

local function updatePlayerBonuses(player)
    if not player or player:isDead() or not isLocalPlayer(player) then return end
    local state = BT._bonusPlayers[player]
    if not state then
        state = {}
        BT._bonusPlayers[player] = state
    end

    updateCarryCapacity(player, state)
    updateEndurance(player, state)
end

local function onTick()
    restoreScaledWeapons()
    for playerIndex = 0, getNumActivePlayers() - 1 do
        updatePlayerBonuses(getSpecificPlayer(playerIndex))
    end
end

local function resetBonusRuntime()
    restoreScaledWeapons()
    BT._bonusPlayers = setmetatable({}, { __mode = "k" })
    BT._maintenanceAttacks = setmetatable({}, { __mode = "k" })
    BT._scaledWeapons = setmetatable({}, { __mode = "k" })
    -- All mod Lua files are loaded by this point. Re-wrap the final functions
    -- so later file replacements such as GunFighter's reload action are kept.
    installTimedActionBonus()
    installReloadingBonus()
end

installTimedActionBonus()
installReloadingBonus()

if not BT._bonusEventsInstalled then
    BT._bonusEventsInstalled = true
    Events.OnWeaponSwingHitPoint.Add(onWeaponSwingHitPoint)
    Events.OnPlayerAttackFinished.Add(onPlayerAttackFinished)
    -- OnTick runs after IsoWorld.update. This lets endurance and condition
    -- adapters observe the completed frame and reapplies carry capacity after
    -- BodyDamage recalculates the vanilla value.
    Events.OnTick.Add(onTick)
    Events.OnGameStart.Add(resetBonusRuntime)
end

print("[BeyondTen] mastery bonuses installed")
