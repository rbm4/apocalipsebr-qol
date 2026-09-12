require "TimedActions/ISUnequipAction"

IABLN = IABLN or {}

local WRAPS_TYPE = "IAmBruceLeeNow.MartialArtsHandWraps"
local STYLE_TYPE = "IAmBruceLeeNow.MartialArtsFightingStyle"
local HANDS_LOCATION = ItemBodyLocation.get(ResourceLocation.of("base:hands"))
local STYLE_MIN_DAMAGE = 0.13335
local STYLE_MAX_DAMAGE = 0.33335
local PUNCH_MAX_RANGE = 1.20
local PUNCH_MIN_ANGLE = 0.72
local KICK_MAX_RANGE = 1.45
local KICK_MIN_ANGLE = 0.50
local VANILLA_SHOVE_MAX_RANGE = 1.10
local VANILLA_SHOVE_MIN_ANGLE = 0.50
local VANILLA_SHOVE_PUSHBACK = 0.50
local VANILLA_SHOVE_MAX_HIT_COUNT = 3
local VANILLA_SHOVE_KNOCKDOWN_MOD = 1.0
local VANILLA_SHOVE_ENDURANCE_MOD = 1.7
local MARTIAL_ARTS_ENDURANCE_MOD_LEVEL_0 = 3.0
local MARTIAL_ARTS_ENDURANCE_MOD_LEVEL_10 = 2.0
local MARTIAL_ARTS_ENDURANCE_COST_LEVEL_0 = 0.009
local UPPERCUT_HIT_TIME_MS = 500
local KICK_HIT_TIME_MS = 740
local PRIMARY_COMBO_UPPERCUT_HIT_TIME_MS = 333
local PRIMARY_COMBO_KICK_HIT_TIME_MS = 500
local COMBO03_SECOND_KICK_TIME_MS = 467
local COMBO03_THIRD_KICK_TIME_MS = 700
local COMBO04_KICK_TIME_MS = 367
local COMBO04_BACKFIST_TIME_MS = 700
local XP_PER_SUCCESSFUL_STRIKE = 1.0
local MUSCLE_STRAIN_STANDARD_PERCENT = 100.0
-- The real wraps weigh 0.1. Normalize their native combat-strain calculation
-- to a 1.0-weight unarmed workload without giving the hidden proxy artificial
-- inventory weight.
-- Calibrated normalizer for the lightweight handwraps' unarmed workload.
local MARTIAL_ARTS_STRAIN_WEIGHT_NORMALIZER = 20.0
local MARTIAL_ARTS_PERK = Perks.MartialArts or Perks.FromString("MartialArts")
local comboGateState = {}
local lastAttackAnim = {}
local lastSoundIndex = {}
local bloodSyncState = {}
local queuedCombo = {}
local lastAimButton = {}
local leftStance = {}
local pendingLeftStance = {}
local reconnectRepair = {}
local styleProxyRequestAt = {}
local styleProxyRemovalRequestAt = {}
local RECONNECT_REPAIR_DELAY_MS = 1500
local RECONNECT_REPAIR_TIMEOUT_MS = 15000
local STYLE_PROXY_REQUEST_RETRY_MS = 1000
local OLD_FAVOURITE_WEAPON_KEY = "Fav:Wrapped Fists"
local NEW_FAVOURITE_WEAPON_KEY = "Fav:Enlightenment"

local function migrateFavouriteWeapon(player)
    if not player then return end
    local modData = player:getModData()
    local oldCount = tonumber(modData[OLD_FAVOURITE_WEAPON_KEY]) or 0
    if oldCount > 0 then
        local newCount = tonumber(modData[NEW_FAVOURITE_WEAPON_KEY]) or 0
        modData[NEW_FAVOURITE_WEAPON_KEY] = newCount + oldCount
    end
    modData[OLD_FAVOURITE_WEAPON_KEY] = nil
end

local function getWornWraps(player)
    if not player then return nil end

    local wraps = player:getWornItem(HANDS_LOCATION)
    if wraps and wraps:getFullType() == WRAPS_TYPE then
        return wraps
    end

    -- During multiplayer character restoration, the body-location lookup can
    -- briefly lag behind the loaded worn-item collection. Scan that collection
    -- as a fallback so reconnect repair does not mistake visible wraps for an
    -- unequipped item.
    local wornItems = player:getWornItems()
    if wornItems then
        for index = 0, wornItems:size() - 1 do
            local worn = wornItems:get(index)
            local item = worn and worn:getItem() or nil
            if item and item:getFullType() == WRAPS_TYPE then
                return item
            end
        end
    end

    return nil
end

local function chooseNextCombo(secondaryOccupied)
    if secondaryOccupied then
        -- A real secondary-hand item leaves only the primary hand available.
        -- Use the dedicated one-free-hand animation instead of allowing the
        -- two-handed combo animations to carry the item through their poses.
        return 4
    end
    -- All four empty-secondary combos have matching left/right animations.
    -- Internal ID 4 remains reserved for the occupied-secondary attack, so
    -- the fourth random result maps to Combo04's internal ID 6.
    local roll = ZombRand(4) + 1
    return roll == 4 and 6 or roll
end

local function setHitSound(weapon, soundName)
    if not weapon then return false end
    local ok = pcall(function()
        weapon:setZombieHitSound(soundName)
    end)
    return ok
end

local function playCombatSound(player, soundName)
    local emitter = player and player:getEmitter() or nil
    if emitter then emitter:playSound(soundName) end
end

local function randomSound(prefix, count)
    local index = ZombRand(count) + 1
    if count > 1 and index == lastSoundIndex[prefix] then
        -- Randomize the alternative, but never immediately repeat a clip from
        -- the same impact pool. This makes variation audible and testable.
        index = (index + ZombRand(count - 1)) % count + 1
    end
    lastSoundIndex[prefix] = index
    return prefix .. tostring(index)
end

local function randomKickSound()
    local specialRoll = ZombRand(20)
    if specialRoll == 0 then
        lastSoundIndex["IABLN_KickImpact"] = 3
        return "IABLN_KickImpact3"
    end
    return randomSound("IABLN_KickImpact", 2)
end

local function setCombatGeometry(weapon, maxRange, minAngle)
    if not weapon then return false end
    local ok = pcall(function()
        weapon:setMaxRange(maxRange)
        weapon:setMinAngle(minAngle)
    end)
    return ok
end

local function getMartialArtsLevel(player)
    if not MARTIAL_ARTS_PERK then return 0 end
    return math.max(0, math.min(10, player:getPerkLevel(MARTIAL_ARTS_PERK)))
end

local function getMartialArtsDamageMultiplier(player)
    -- Level 0 = 1x, level 5 = 2x, level 10 = 3x.
    return 1.0 + getMartialArtsLevel(player) * 0.2
end

local function getMartialArtsEnduranceMod(player)
    -- Three times the old default cost at level 0, improving linearly to
    -- twice the old cost at level 10. Vanilla character modifiers still apply.
    local level = getMartialArtsLevel(player)
    local range = MARTIAL_ARTS_ENDURANCE_MOD_LEVEL_0 -
        MARTIAL_ARTS_ENDURANCE_MOD_LEVEL_10
    return MARTIAL_ARTS_ENDURANCE_MOD_LEVEL_0 - range * (level / 10.0)
end

local function getMartialArtsMuscleStrainMultiplier()
    local options = SandboxVars and SandboxVars.IAmBruceLeeNow
    local percent = options and
        tonumber(options.MartialArtsMuscleStrain) or
        MUSCLE_STRAIN_STANDARD_PERCENT
    return math.max(0, math.min(300, percent)) /
        MUSCLE_STRAIN_STANDARD_PERCENT
end

local function getComboWorkload(comboId)
    return comboId == 2 and 0.75 or (comboId == 5 and 1.10 or 1.00)
end

local function applyMartialArtsExertion(player, comboId)
    local sandboxMultiplier = getMartialArtsMuscleStrainMultiplier()
    local wraps = getWornWraps(player)
    if not wraps or wraps:getFullType() ~= WRAPS_TYPE then return end

    if isClient() then
        sendClientCommand(player, "IABLN", "applyMartialArtsExertion", {
            comboId = comboId,
        })
        -- The hosted server owns endurance and muscle strain. Applying or
        -- synchronizing either again on the client can overwrite the server's
        -- complete character-stat state.
        return
    end

    local workload = getComboWorkload(comboId)
    local enduranceScale = getMartialArtsEnduranceMod(player) /
        MARTIAL_ARTS_ENDURANCE_MOD_LEVEL_0
    local enduranceCost = MARTIAL_ARTS_ENDURANCE_COST_LEVEL_0 *
        workload * enduranceScale
    player:getStats():remove(CharacterStat.ENDURANCE, enduranceCost)

    -- addCombatMuscleStrain() requires a live vanilla melee-attack state and
    -- ignores its multiplier for non-HandWeapon items. These custom animations
    -- therefore use the direct body-part APIs. Reproduce the vanilla one-hand
    -- weight/Strength basis, then apply the calibrated workload multiplier.
    local strengthLevel = math.max(0, math.min(10,
        player:getPerkLevel(Perks.Strength)))
    local strengthMod = (15 - strengthLevel) / 10.0
    local painFactor = wraps:getActualWeight() * 0.15 * 0.3 * 4.0 *
        strengthMod * 0.65 * sandboxMultiplier * workload *
        MARTIAL_ARTS_STRAIN_WEIGHT_NORMALIZER
    if sandboxMultiplier > 0 then
        pcall(function()
            if comboId == 1 or comboId == 6 then
                player:addBothArmMuscleStrain(painFactor)
            else
                player:addRightLegMuscleStrain(painFactor)
            end
        end)
    end
end

local function isMultiHitEnabled()
    return SandboxVars and SandboxVars.MultiHitZombies == true
end

local function awardMartialArtsXP(player, amount)
    if not player or not MARTIAL_ARTS_PERK or amount <= 0 then return end

    -- Combat detection lives on the owning client. Multiplayer XP must be
    -- granted by the server or the next synchronization overwrites it.
    if isClient() then
        sendClientCommand(player, "IABLN", "awardMartialArtsXP", {
            amount = amount,
        })
        return
    end

    player:getXp():AddXP(MARTIAL_ARTS_PERK, amount)
end

local function setMaxHitCount(weapon, count)
    if not weapon then return false end
    local ok = pcall(function()
        weapon:setMaxHitCount(count)
    end)
    return ok
end

local function setKnockdownMod(weapon, value)
    if not weapon then return false end
    local ok = pcall(function()
        weapon:setKnockdownMod(value)
    end)
    return ok
end

local function setEnduranceMod(weapon, value)
    if not weapon then return false end
    local ok = pcall(function()
        weapon:setEnduranceMod(value)
    end)
    return ok
end

local function findControlledTarget(player, state, maxRange, minAngle)
    local forwardX = player:getForwardDirectionX()
    local forwardY = player:getForwardDirectionY()
    local candidates = {}
    local zombies = player:getCell():getZombieList()
    for index = 0, zombies:size() - 1 do
        local zombie = zombies:get(index)
        if zombie and not zombie:isDead() and not zombie:isOnFloor() and
                math.abs(zombie:getZ() - player:getZ()) < 0.5 then
            local deltaX = zombie:getX() - player:getX()
            local deltaY = zombie:getY() - player:getY()
            local distanceSquared = deltaX * deltaX + deltaY * deltaY
            if distanceSquared > 0.0001 and
                    distanceSquared <= maxRange * maxRange then
                local distance = math.sqrt(distanceSquared)
                local dot = (deltaX * forwardX + deltaY * forwardY) / distance
                if dot >= minAngle then
                    candidates[#candidates + 1] = {
                        target = zombie,
                        distanceSquared = distanceSquared,
                        dot = dot,
                    }
                end
            end
        end
    end
    table.sort(candidates, function(a, b)
        return a.distanceSquared < b.distanceSquared
    end)
    if isMultiHitEnabled() then
        for _, candidate in ipairs(candidates) do
            if not state.comboTargets[candidate.target] then return candidate end
        end
    elseif state.lockedTarget then
        for _, candidate in ipairs(candidates) do
            if candidate.target == state.lockedTarget then return candidate end
        end
        -- Vanilla multi-hit is off: the combo is committed to its first
        -- zombie and may not retarget a second zombie mid-animation.
        return nil
    end
    return candidates[1]
end

local function runControlledStrike(player, state, strike)
    local doneKey = strike == 2 and "uppercutDone" or "kickDone"
    if state[doneKey] then return end
    state[doneKey] = true
    local isKick = state.comboId == 3 or
        (state.comboId == 6 and strike == 2) or
        (state.comboId ~= 6 and strike == 3)
    local candidate = findControlledTarget(player, state,
        isKick and KICK_MAX_RANGE or PUNCH_MAX_RANGE,
        isKick and KICK_MIN_ANGLE or PUNCH_MIN_ANGLE)
    if not candidate then return end

    local target = candidate.target
    local damage = state.lastVanillaDamage or state.weapon:getMinDamage()
    local healthBefore = target:getHealth()
    local firstContact = not state.reactedTargets[target]
    local ok, result = pcall(function()
        if firstContact then
            return target:Hit(
                state.weapon, player, damage, false, 1.0, false)
        end
        local damageResult = target:processHitDamage(
            state.weapon, player, damage, false, 1.0)
        target:setHealth(math.max(0, healthBefore - damageResult))
        if target:isDead() then
            -- Complete vanilla kill bookkeeping without applying damage twice.
            target:hitConsequences(state.weapon, player, true, 0, false)
        end
        local deltaX = target:getX() - player:getX()
        local deltaY = target:getY() - player:getY()
        local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)
        if distance > 0.001 then
            target:getHitDir():set(deltaX / distance, deltaY / distance)
            target:setHitForce(isKick and 0.50 or 0.15)
        end
        return damageResult
    end)
    local healthAfter = target:getHealth()
    local damageApplied = ok and healthAfter < healthBefore - 0.0001
    if damageApplied then
        state.reactedTargets[target] = true
        state.comboTargets[target] = true
        local xpAward = XP_PER_SUCCESSFUL_STRIKE
        awardMartialArtsXP(player, xpAward)
        if not state.impactPlayed[strike] then
            local soundName = state.selectedImpact[strike]
            if soundName then playCombatSound(player, soundName) end
            state.impactPlayed[strike] = true
        end
    end
end

local function isType(item, fullType)
    return item and item:getFullType() == fullType
end

local function isEmptyCombatHand(item)
    return item == nil or item:getFullType() == "Base.BareHands"
end

local function removeStyleItems(player)
    local equippedStyleRemoved = false
    if isType(player:getPrimaryHandItem(), STYLE_TYPE) then
        player:setPrimaryHandItem(nil)
        equippedStyleRemoved = true
    end
    if isType(player:getSecondaryHandItem(), STYLE_TYPE) then
        player:setSecondaryHandItem(nil)
        equippedStyleRemoved = true
    end
    if equippedStyleRemoved and isClient() then
        sendEquip(player)
    end

    local inventory = player:getInventory()
    if isClient() then
        -- The proxy is created by the dedicated server and must also be deleted
        -- by it. A client-side synchronized-item deletion is rejected by B42's
        -- anti-cheat (`SyncedItemDelete: no capability`).
        local playerNum = player:getPlayerNum()
        local hasInventoryStyle = false
        local items = inventory:getItems()
        for index = 0, items:size() - 1 do
            if isType(items:get(index), STYLE_TYPE) then
                hasInventoryStyle = true
                break
            end
        end
        if not equippedStyleRemoved and not hasInventoryStyle then
            styleProxyRemovalRequestAt[playerNum] = nil
            return
        end
        local now = getTimestampMs()
        local lastRequest = styleProxyRemovalRequestAt[playerNum] or 0
        if now - lastRequest >= STYLE_PROXY_REQUEST_RETRY_MS then
            styleProxyRemovalRequestAt[playerNum] = now
            sendClientCommand(player, "IABLN", "removeStyleProxy", {})
        end
        return
    end

    local items = inventory:getItems()
    for index = items:size() - 1, 0, -1 do
        local item = items:get(index)
        if isType(item, STYLE_TYPE) then
            inventory:Remove(item)
        end
    end
end

local function findInventoryItem(player, fullType)
    local items = player:getInventory():getItems()
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if isType(item, fullType) then return item end
    end
    return nil
end

local function requestStyleProxy(player, playerNum)
    local now = getTimestampMs()
    local lastRequest = styleProxyRequestAt[playerNum] or 0
    if now - lastRequest < STYLE_PROXY_REQUEST_RETRY_MS then return end
    styleProxyRequestAt[playerNum] = now
    sendClientCommand(player, "IABLN", "requestStyleProxy", {})
end

local function updateComboCollisionGates(player, playerNum, active)
    local state = comboGateState[playerNum]
    if not active or not state then
        comboGateState[playerNum] = nil
        return
    end

    local elapsed = getTimestampMs() - state.startedAt
    if elapsed > 1000 then
        if state.weapon then
            state.weapon:setPushBackMod(0.15)
            setHitSound(state.weapon, "IABLN_SilentImpact")
            setCombatGeometry(state.weapon, PUNCH_MAX_RANGE,
                PUNCH_MIN_ANGLE)
        end
        comboGateState[playerNum] = nil
        return
    end
    if state.comboId == 2 then
        -- Combo02 is one native collision at frame 10. Vanilla's Multi-Hit
        -- Zombies setting decides whether that collision reaches one or as
        -- many as three targets.
        if not state.whoosh3 and elapsed >= 400 then
            state.whoosh3 = true
            playCombatSound(player, "IABLN_WhooshHeavy")
        end
        return
    end
    if state.comboId == 5 then
        -- ChopKick01 is one native floor collision. Vanilla chooses the floor
        -- target; the controller only supplies full-combo damage and sound.
        if not state.whoosh3 and elapsed >= 250 then
            state.whoosh3 = true
            playCombatSound(player, "IABLN_WhooshHeavy")
        end
        return
    end
    local primaryCombo = state.comboId == 4
    local tripleKickCombo = state.comboId == 3
    local combo04 = state.comboId == 6
    local reset2Time = primaryCombo and 230 or 400
    local reset3Time = primaryCombo and 400 or 600
    if tripleKickCombo then
        reset2Time = 330
        reset3Time = 560
    elseif combo04 then
        reset2Time = 267
        reset3Time = 600
    end
    local strike2Time = combo04 and COMBO04_KICK_TIME_MS or
        (tripleKickCombo and COMBO03_SECOND_KICK_TIME_MS or
        (primaryCombo and PRIMARY_COMBO_UPPERCUT_HIT_TIME_MS or
            UPPERCUT_HIT_TIME_MS))
    local strike3Time = combo04 and COMBO04_BACKFIST_TIME_MS or
        (tripleKickCombo and COMBO03_THIRD_KICK_TIME_MS or
        (primaryCombo and PRIMARY_COMBO_KICK_HIT_TIME_MS or KICK_HIT_TIME_MS)
        )
    if not state.whoosh2 and elapsed >=
            (combo04 and 250 or
                (tripleKickCombo and 250 or
                    (primaryCombo and 180 or 340))) then
        state.whoosh2 = true
        playCombatSound(player, (tripleKickCombo or combo04) and
            "IABLN_WhooshHeavy" or "IABLN_WhooshLight")
    end
    if not state.whoosh3 and elapsed >=
            (combo04 and 550 or
                (tripleKickCombo and 500 or
                    (primaryCombo and 350 or 600))) then
        state.whoosh3 = true
        playCombatSound(player, "IABLN_WhooshHeavy")
    end
    local shouldReset = nil
    if not state.reset2 and elapsed >= reset2Time then
        state.reset2 = true
        shouldReset = 2
    elseif not state.reset3 and elapsed >= reset3Time then
        state.reset3 = true
        shouldReset = 3
    end

    if shouldReset then
        -- ATTACKED only controls whether another collision check may run.
        -- Vanilla also remembers every target hit during the current swing;
        -- clear that list so this combo's next strike may hit the same zombie.
        pcall(function()
            player:clearHitInfo()
        end)
        if state.weapon then
            local isKickStrike = tripleKickCombo or
                (combo04 and shouldReset == 2) or
                (not combo04 and shouldReset == 3)
            state.weapon:setPushBackMod(isKickStrike and 0.50 or 0.15)
            if isKickStrike then
                setCombatGeometry(state.weapon, KICK_MAX_RANGE,
                    KICK_MIN_ANGLE)
            else
                setCombatGeometry(state.weapon, PUNCH_MAX_RANGE,
                    PUNCH_MIN_ANGLE)
            end
            local selectedHitSound =
                isKickStrike and
                randomKickSound() or
                randomSound("IABLN_SmackImpact", 4)
            state.currentStrike = shouldReset
            state.selectedImpact[shouldReset] = selectedHitSound
        end
        -- Follow-up strikes are delivered by Lua so repeated contact can add
        -- damage without restarting an existing zombie hit reaction.
    end
    if elapsed >= strike2Time then
        runControlledStrike(player, state, 2)
    end
    if elapsed >= strike3Time then
        runControlledStrike(player, state, 3)
    end
end

local function syncWrapBlood(playerNum, wraps, proxy)
    if not isType(wraps, WRAPS_TYPE) or not isType(proxy, STYLE_TYPE) then
        bloodSyncState[playerNum] = nil
        return
    end
    -- Clothing stores blood as 0..100, while weapons store it as 0..1.
    -- Compare and remember normalized values so the visible wraps remain a
    -- real, washable clothing item while the equipped proxy mirrors them.
    local wrapBlood = wraps:getBloodLevelAdjustedLow()
    local proxyBlood = proxy:getBloodLevelAdjustedLow()
    local previous = bloodSyncState[playerNum]
    local epsilon = 0.0001

    local function setWrapBlood(level)
        level = math.max(0, math.min(1, level))
        wraps:setBloodLevel(level * 100)
        wraps:synchWithVisual()
        return level
    end

    local function setProxyBlood(level)
        level = math.max(0, math.min(1, level))
        proxy:setBloodLevel(level)
        return level
    end

    if not previous then
        local reconciled = math.max(wrapBlood, proxyBlood)
        wrapBlood = setWrapBlood(reconciled)
        proxyBlood = setProxyBlood(reconciled)
    else
        local wrapsWereCleaned = wrapBlood < previous.wrapBlood - epsilon
        local proxyGainedBlood = proxyBlood > previous.proxyBlood + epsilon
        if wrapsWereCleaned and not proxyGainedBlood then
            proxyBlood = setProxyBlood(wrapBlood)
        elseif proxyGainedBlood or proxyBlood > wrapBlood + epsilon then
            wrapBlood = setWrapBlood(math.max(wrapBlood, proxyBlood))
        elseif wrapBlood > proxyBlood + epsilon then
            proxyBlood = setProxyBlood(wrapBlood)
        end
    end

    bloodSyncState[playerNum] = {
        wrapBlood = wrapBlood,
        proxyBlood = proxyBlood,
    }
end

local function updatePlayer(player)
    if not player or not IsoPlayer.isLocalPlayer(player) then return end

    local playerNum = player:getPlayerNum()
    local wraps = getWornWraps(player)

    local hasWraps = isType(wraps, WRAPS_TYPE)
    if hasWraps and wraps:getCondition() < wraps:getConditionMax() then
        -- Wraps unlock the fighting style; they are not expendable armor.
        wraps:setCondition(wraps:getConditionMax())
    end
    wraps = getWornWraps(player)
    local wearingWraps = isType(wraps, WRAPS_TYPE)

    local repair = reconnectRepair[playerNum]
    if repair then
        local now = getTimestampMs()
        if now >= repair.notBefore and wearingWraps then
            -- The dedicated server owns the hidden proxy. Reuse the restored
            -- authoritative item if present; the normal logic below requests a
            -- replacement only when it is actually absent.
            reconnectRepair[playerNum] = nil
        elseif now >= repair.expiresAt then
            reconnectRepair[playerNum] = nil
        end
    end

    local primary = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()
    local secondaryOccupied = not isEmptyCombatHand(secondary) and
        not isType(secondary, STYLE_TYPE)
    local doShove = player:getVariableBoolean("bDoShove")
    local active = false

    if not wearingWraps then
        removeStyleItems(player)
        styleProxyRequestAt[playerNum] = nil
        player:setVariable("IABLNActive", false)
    elseif isEmptyCombatHand(primary) then
        local style
        if isClient() then
            -- A dedicated server must create the combat weapon so its network
            -- item ID is authoritative. Equip only the copy delivered into the
            -- client's inventory by the server.
            style = findInventoryItem(player, STYLE_TYPE)
            if not style then requestStyleProxy(player, playerNum) end
        else
            style = player:getInventory():AddItem(STYLE_TYPE)
        end
        if style then
            styleProxyRemovalRequestAt[playerNum] = nil
            player:setPrimaryHandItem(style)
            if isClient() then
                styleProxyRequestAt[playerNum] = nil
                sendEquip(player)
            end
            primary = style
            active = true
        end
    else
        active = isType(primary, STYLE_TYPE)
    end

    player:setVariable("IABLNActive", active)
    -- Choose a stance only on the rising edge of RMB. Keep it after release so
    -- unaimed attacks use the last choice. A choice made during an attack is
    -- deferred until that attack ends, preventing a mid-combo family swap.
    local aimButtonDown = isMouseButtonDown(1)
    local wasAimButtonDown = lastAimButton[playerNum] == true
    local selectingDuringAttack = player:getVariableBoolean("AttackAnim")
    if active and not secondaryOccupied and aimButtonDown and
            not wasAimButtonDown then
        local selectedLeft = ZombRand(2) == 0
        if selectingDuringAttack then
            pendingLeftStance[playerNum] = selectedLeft
        else
            leftStance[playerNum] = selectedLeft
            -- Re-select with the new stance so the queued animation and its
            -- return stance always belong to the same family.
            queuedCombo[playerNum] = chooseNextCombo(false)
        end
    end
    if active and not secondaryOccupied and not selectingDuringAttack and
            pendingLeftStance[playerNum] ~= nil then
        leftStance[playerNum] = pendingLeftStance[playerNum]
        queuedCombo[playerNum] = chooseNextCombo(false)
        pendingLeftStance[playerNum] = nil
    end
    if not active then
        pendingLeftStance[playerNum] = nil
    end
    -- Occupied secondary always uses the existing prop-safe fixed side. The
    -- remembered empty-secondary stance remains intact for when the item is
    -- cleared again.
    player:setVariable("IABLNLeftStance",
        active and not secondaryOccupied and leftStance[playerNum] == true)
    lastAimButton[playerNum] = aimButtonDown
    -- Keep animation nodes mutually exclusive. Without this selector PZ may
    -- run collision events from Combo01 underneath Combo02's visible motion.
    if active and not queuedCombo[playerNum] then
        queuedCombo[playerNum] = chooseNextCombo(secondaryOccupied)
    elseif active and not selectingDuringAttack and
            secondaryOccupied and queuedCombo[playerNum] ~= 4 then
        queuedCombo[playerNum] = 4
    elseif active and not selectingDuringAttack and
            not secondaryOccupied and queuedCombo[playerNum] == 4 then
        queuedCombo[playerNum] = chooseNextCombo(false)
    elseif not active then
        queuedCombo[playerNum] = nil
    end
    player:setVariable("IABLNCombo", tostring(queuedCombo[playerNum] or 0))
    if active then
        syncWrapBlood(playerNum, wraps, primary)
    else
        bloodSyncState[playerNum] = nil
    end
    if active and not doShove then
        -- The calculated melee critical roll can still become true despite a
        -- negative weapon chance. Never allow vanilla's one-shot crit node to
        -- replace the martial-arts combo.
        player:setVariable("CriticalHit", false)
    end
    if active and isType(primary, STYLE_TYPE) and doShove then
        -- Space-bar shove must remain vanilla combat. The hidden martial-arts
        -- weapon otherwise leaks its lower strike pushback into this path.
        primary:setPushBackMod(VANILLA_SHOVE_PUSHBACK)
        setCombatGeometry(primary, VANILLA_SHOVE_MAX_RANGE,
            VANILLA_SHOVE_MIN_ANGLE)
        setMaxHitCount(primary, VANILLA_SHOVE_MAX_HIT_COUNT)
        setKnockdownMod(primary, VANILLA_SHOVE_KNOCKDOWN_MOD)
        setEnduranceMod(primary, VANILLA_SHOVE_ENDURANCE_MOD)
    elseif active and isType(primary, STYLE_TYPE) and
            not comboGateState[playerNum] then
        local damageMultiplier = getMartialArtsDamageMultiplier(player)
        primary:setPushBackMod(0.15)
        setCombatGeometry(primary, PUNCH_MAX_RANGE, PUNCH_MIN_ANGLE)
        -- Combo01 is three separate contacts. Its native jab must hit only one
        -- zombie; the Lua uppercut and kick may select other zombies when the
        -- vanilla multi-hit option is enabled.
        setMaxHitCount(primary, 1)
        setHitSound(primary, "IABLN_SilentImpact")
        -- HandWeapon stats are serialized into saves. Enforce balance values
        -- so an existing hidden proxy does not retain an older item definition.
        primary:setMinDamage(STYLE_MIN_DAMAGE * damageMultiplier)
        primary:setMaxDamage(STYLE_MAX_DAMAGE * damageMultiplier)
        -- Zero is only a base chance; vanilla skill modifiers can still make the
        -- final roll critical. Keep it negative enough to forbid that branch.
        primary:setCriticalChance(-100.0)
        setKnockdownMod(primary, 1.5)
        setEnduranceMod(primary, getMartialArtsEnduranceMod(player))
    end
    local attackAnim = active and not doShove and
        player:getVariableBoolean("AttackAnim")
    local wasAttackAnim = lastAttackAnim[playerNum]
    if attackAnim and not wasAttackAnim and
            isType(primary, STYLE_TYPE) then
        local floorAttack = player:getVariableBoolean("AimFloorAnim")
        local comboId = floorAttack and 5 or (queuedCombo[playerNum] or 1)
        applyMartialArtsExertion(player, comboId)
        local damageMultiplier = getMartialArtsDamageMultiplier(player)
        local selectedHitSound
        if comboId == 2 then
            primary:setPushBackMod(0.50)
            setCombatGeometry(primary, KICK_MAX_RANGE, KICK_MIN_ANGLE)
            -- Combo02 is one sweeping contact and follows vanilla multi-hit.
            setMaxHitCount(primary, isMultiHitEnabled() and 3 or 1)
            primary:setMinDamage(STYLE_MIN_DAMAGE * damageMultiplier * 3.0)
            primary:setMaxDamage(STYLE_MAX_DAMAGE * damageMultiplier * 3.0)
            selectedHitSound = randomKickSound()
        elseif comboId == 3 then
            primary:setPushBackMod(0.50)
            setCombatGeometry(primary, KICK_MAX_RANGE, KICK_MIN_ANGLE)
            setMaxHitCount(primary, 1)
            selectedHitSound = randomKickSound()
        elseif comboId == 5 then
            primary:setPushBackMod(0.50)
            setCombatGeometry(primary, KICK_MAX_RANGE, KICK_MIN_ANGLE)
            setMaxHitCount(primary, 1)
            primary:setMinDamage(STYLE_MIN_DAMAGE * damageMultiplier * 3.0)
            primary:setMaxDamage(STYLE_MAX_DAMAGE * damageMultiplier * 3.0)
            selectedHitSound = randomKickSound()
        else
            primary:setPushBackMod(0.15)
            setCombatGeometry(primary, PUNCH_MAX_RANGE, PUNCH_MIN_ANGLE)
            setMaxHitCount(primary, 1)
            selectedHitSound = randomSound("IABLN_SmackImpact", 4)
        end
        setHitSound(primary, "IABLN_SilentImpact")
        local initialStrike = comboId == 2 and 3 or 1
        comboGateState[playerNum] = {
            comboId = comboId,
            startedAt = getTimestampMs(),
            reset2 = false,
            reset3 = false,
            whoosh2 = false,
            whoosh3 = false,
            currentStrike = initialStrike,
            selectedImpact = { [initialStrike] = selectedHitSound },
            impactPlayed = {},
            reactedTargets = {},
            comboTargets = {},
            uppercutDone = false,
            kickDone = false,
            lastVanillaDamage = nil,
            weapon = primary,
        }
    end
    if not attackAnim and wasAttackAnim and active then
        secondary = player:getSecondaryHandItem()
        secondaryOccupied = not isEmptyCombatHand(secondary) and
            not isType(secondary, STYLE_TYPE)
        queuedCombo[playerNum] = chooseNextCombo(secondaryOccupied)
        player:setVariable("IABLNCombo", tostring(queuedCombo[playerNum]))
    end
    lastAttackAnim[playerNum] = attackAnim
    updateComboCollisionGates(player, playerNum, active)
end

Events.OnPlayerUpdate.Add(updatePlayer)

local function queueReconnectRepair(playerNum, player)
    migrateFavouriteWeapon(player)
    if not isClient() then return end

    local now = getTimestampMs()
    reconnectRepair[playerNum] = {
        notBefore = now + RECONNECT_REPAIR_DELAY_MS,
        expiresAt = now + RECONNECT_REPAIR_TIMEOUT_MS,
    }
end

Events.OnCreatePlayer.Add(queueReconnectRepair)

local function onWeaponHitXp(owner, weapon, target, damage, hitCount)
    if not owner or not IsoPlayer.isLocalPlayer(owner) then return end
    if not isType(weapon, STYLE_TYPE) or not target then return end
    migrateFavouriteWeapon(owner)
    local soundState = comboGateState[owner:getPlayerNum()]
    if soundState then
        local strike = soundState.currentStrike or 1
        soundState.lastVanillaDamage = damage
        if soundState.comboId == 1 and not isMultiHitEnabled() and
                not soundState.lockedTarget then
            soundState.lockedTarget = target
        end
        soundState.reactedTargets[target] = true
        soundState.comboTargets[target] = true
        if not soundState.impactPlayed[strike] then
            local soundName = soundState.selectedImpact[strike]
            if soundName then
                playCombatSound(owner, soundName)
                soundState.impactPlayed[strike] = true
            end
        end
    end
    local xpAward = XP_PER_SUCCESSFUL_STRIKE
    awardMartialArtsXP(owner, xpAward)
end

Events.OnWeaponHitXp.Add(onWeaponHitXp)

-- The primary-hand icon represents a hidden weapon proxy, but players
-- reasonably understand "Unequip" on that icon as taking off the wraps.
-- Hook only the explicit vanilla unequip action; ordinary weapon swaps use
-- ISEquipWeaponAction and therefore continue to leave the real wraps worn.
if not IABLN.originalUnequipComplete then
    IABLN.originalUnequipComplete = ISUnequipAction.complete
    ISUnequipAction.complete = function(action)
        local character = action and action.character or nil
        local isStyleUnequip = action and isType(action.item, STYLE_TYPE)
        local completed = IABLN.originalUnequipComplete(action)
        if completed and isStyleUnequip and character then
            local wraps = getWornWraps(character)
            if isType(wraps, WRAPS_TYPE) then
                character:removeWornItem(wraps, false)
                triggerEvent("OnClothingUpdated", character)
                if ISInventoryPage then ISInventoryPage.renderDirty = true end
            end
        end
        return completed
    end
end
