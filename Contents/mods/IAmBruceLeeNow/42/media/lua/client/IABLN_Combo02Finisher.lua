local config = require "IABLN_Combo02FinisherConfig"

local STYLE_TYPE = "IAmBruceLeeNow.MartialArtsFightingStyle"
local IMPULSE_PROFILE_TYPE = "Base.PipeBomb"
local IMPULSE_PHYSICS_OBJECT = "Base.PipeBomb"
local pendingByTarget = {}
local attackStateByPlayer = {}
local impulseProfile = nil

local function getImpulseOriginSquare(owner, dx, dy)
    -- Explosive ragdoll profiles derive their direction from an attack-target
    -- square, not target:getHitDir(). Put that origin behind the attacker so
    -- the resulting native impulse continues straight through the zombie.
    local originX = math.floor(owner:getX() - dx * 2.0)
    local originY = math.floor(owner:getY() - dy * 2.0)
    local originZ = math.floor(owner:getZ())
    local square = getCell():getGridSquare(originX, originY, originZ)
    if not square then
        square = owner:getSquare()
    end
    return square
end

local function isEligible(owner, target, weapon)
    return owner and target and weapon and IsoPlayer.isLocalPlayer(owner) and
        weapon:getFullType() == STYLE_TYPE and instanceof(target, "IsoZombie") and
        owner:getVariableString("IABLNCombo") == "2" and
        not owner:isDoShove() and not target:isOnFloor() and
        not target:isCrawling()
end

local function setLaunchDirection(owner, target)
    local dx = target:getX() - owner:getX()
    local dy = target:getY() - owner:getY()
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0.0001 then
        dx = owner:getForwardDirectionX()
        dy = owner:getForwardDirectionY()
        length = math.sqrt(dx * dx + dy * dy)
    end
    if length > 0.0001 then
        dx = dx / length
        dy = dy / length
        target:getHitDir():set(dx, dy)
    end
    target:setHitForce(config.HIT_FORCE)
    return dx, dy
end

local function requestDeathRagdoll(owner, target)
    local dx, dy = setLaunchDirection(owner, target)
    local impulseOrigin = getImpulseOriginSquare(owner, dx, dy)
    target:setRagdollFall(true)
    target:setUsePhysicHitReaction(true)
    -- isRagdollFall selects a transition; it does not start physics alone.
    -- Lethal melee can otherwise bypass the knockdown/stagger route entirely.
    target:setKnockedDown(true)
    target:setStaggerBack(true)
    target:setHitReaction("")
    target:reportEvent("wasHit")
    -- Do not inspect or edit BallisticsTarget from Lua. Ensure that the native
    -- object exists, then let the stock ranged-hit consequence populate its
    -- private CombatDamageData and request a pelvis impulse for this target.
    local previousReaction = owner:getVariableString("ZombieHitReaction")
    local profileFailure = nil
    local ok = pcall(function()
        if not impulseProfile then
            local scriptItem = getScriptManager():FindItem(IMPULSE_PROFILE_TYPE)
            if not scriptItem then
                profileFailure = "stock-profile-not-found"
                return
            end
            impulseProfile = scriptItem:InstanceItem(nil)
        end
        if not impulseProfile then
            profileFailure = "stock-profile-instance-failed"
            return
        end
        -- This object exists only in memory. Making this instance ranged lets
        -- CombatManager create native ragdoll combat data. The registered
        -- vanilla PipeBomb physics object supplies a known 700/70 impulse,
        -- without throwing, placing, or detonating anything.
        impulseProfile:setRanged(true)
        impulseProfile:setPhysicsObject(IMPULSE_PHYSICS_OBJECT)
        impulseProfile:setAttackTargetSquare(impulseOrigin)
        target:ensureExistsBallisticsTarget(target)
        owner:setVariable("ZombieHitReaction", "ShotBelly")
        target:hitConsequences(impulseProfile, owner, true, 0, false)
    end)
    if previousReaction and previousReaction ~= "" then
        owner:setVariable("ZombieHitReaction", previousReaction)
    else
        owner:clearVariable("ZombieHitReaction")
    end
    if not ok then return false end
    if profileFailure then
        return false
    end
    target:setRagdollFall(true)
    target:setKnockedDown(true)
    target:setStaggerBack(true)
    target:reportEvent("wasHit")
    return true
end

local function getAttackState(owner)
    local playerNum = owner:getPlayerNum()
    local now = getTimestampMs()
    local state = attackStateByPlayer[playerNum]
    -- Multi-Hit contacts arrive together. A later contact separated by more
    -- than 250 ms belongs to a new Combo 02 even when the next attack starts
    -- less than 1.5 seconds after the preceding one.
    if not state or now - (state.lastContactAt or state.startedAt) > 250 then
        local finisherRoll = ZombRandFloat(0.0, 1.0)
        state = {
            startedAt = now,
            prepared = 0,
            enlightened = finisherRoll < config.FINISHER_CHANCE,
            finisherVoicePlayed = false,
        }
        attackStateByPlayer[playerNum] = state
    end
    state.lastContactAt = now
    return state
end

local function onWeaponHitCharacter(owner, target, weapon, rawDamage)
    if not isEligible(owner, target, weapon) then return end

    local state = getAttackState(owner)
    local withinLimit = state.prepared < config.MAX_LAUNCHED_PER_ATTACK
    local selected = withinLimit and state.enlightened
    setLaunchDirection(owner, target)

    -- The flag is set before vanilla resolves death. If this hit is nonlethal,
    -- the post-hit handler clears it immediately so a living zombie cannot
    -- retain a future ragdoll fall.
    if not isClient() and selected then
        target:setRagdollFall(true)
        target:setUsePhysicHitReaction(true)
    end
    if not isClient() and selected then
        state.prepared = state.prepared + 1
    end

    pendingByTarget[target] = {
        owner = owner,
        weapon = weapon,
        state = state,
        selected = selected,
    }

end

local function playFinisherVoice(owner, state)
    if state.finisherVoicePlayed then return end
    local emitter = owner:getEmitter()
    if not emitter then return end
    emitter:playSound("IABLN_Waayaaaa")
    state.finisherVoicePlayed = true
end

local function onWeaponHitXp(owner, weapon, target, reportedDamage, hitCount)
    local pending = target and pendingByTarget[target] or nil
    if not pending or pending.owner ~= owner or pending.weapon ~= weapon then
        return
    end
    pendingByTarget[target] = nil

    local healthAfter = target:getHealth()
    local naturallyLethal = target:isDead() or healthAfter <= 0

    if naturallyLethal and pending.selected and not isClient() then
        local impulseReady = requestDeathRagdoll(owner, target)
        if impulseReady then
            playFinisherVoice(owner, pending.state)
        end
    elseif not naturallyLethal and not isClient() then
        target:setRagdollFall(false)
        target:setUsePhysicHitReaction(false)
    end

end

Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
Events.OnWeaponHitXp.Add(onWeaponHitXp)
