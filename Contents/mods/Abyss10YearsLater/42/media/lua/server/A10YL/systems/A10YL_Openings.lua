local Random = require("A10YL/core/A10YL_Random")
local Mutations = require("A10YL/core/A10YL_Mutations")
local Validation = require("A10YL/core/A10YL_Validation")
local BuildingProfile = require("A10YL/core/A10YL_BuildingProfile")
local Protection = require("A10YL/core/A10YL_Protection")

local Openings = {}

local function append(plan, operation)
    operation.system = "openings"
    operation.stage = 7
    plan.operations[#plan.operations + 1] = operation
end

local function salt(square, target, suffix)
    return "openings:" .. tostring(suffix) .. ":" .. Mutations.targetKey(target)
        .. ":" .. tostring(square:getX()) .. ":" .. tostring(square:getY()) .. ":" .. tostring(square:getZ())
end

local function nativeEffectSatisfied(obj, action)
    if not obj then return false end
    if action == "smash-window" and instanceof(obj, "IsoWindow") then
        return obj:isSmashed() or obj:isDestroyed() or obj:isGlassRemoved()
    elseif action == "open-door" and instanceof(obj, "IsoDoor") then
        return obj:IsOpen()
    elseif action == "destroy-door" and instanceof(obj, "IsoDoor") then
        return obj:isDestroyed()
    elseif (action == "barricade-window" or action == "barricade-door")
        and (instanceof(obj, "IsoWindow") or instanceof(obj, "IsoDoor"))
    then
        return obj:isBarricaded()
    end
    return false
end

local function profileFields(profile)
    return profile and profile.key or nil, profile and profile.signature or nil
end

local function addDamage(square, target, isWindow, profile, plan)
    -- Windows use the explicit dedicated-server smash path. Ordinary doors use
    -- a separate replicated square-removal operation when a missing door is
    -- selected; IsoDoor:destroy() itself remains unused.
    if not isWindow then return false end
    local key, signature = profileFields(profile)
    append(plan, {
        action = "smash-window",
        slot = Mutations.semanticSlot(target.object),
        target = target.descriptor,
        buildingKey = key,
        buildingSignature = signature,
    })
    return true
end

local function addOpenDoor(target, profile, plan, exterior)
    local key, signature = profileFields(profile)
    append(plan, {
        action = "open-door",
        slot = Mutations.semanticSlot(target.object),
        target = target.descriptor,
        exterior = exterior == true,
        buildingKey = key,
        buildingSignature = signature,
    })
    return true
end

local function addDestroyedDoor(target, profile, plan, exterior)
    local key, signature = profileFields(profile)
    append(plan, {
        action = "destroy-door",
        slot = Mutations.semanticSlot(target.object),
        target = target.descriptor,
        exterior = exterior == true,
        buildingKey = key,
        buildingSignature = signature,
    })
    return true
end

local function addBarricade(square, target, isWindow, profile, plan, remnant)
    local key, signature = profileFields(profile)
    local operation = {
        action = isWindow and "barricade-window" or "barricade-door",
        slot = Mutations.semanticSlot(target.object),
        target = target.descriptor,
        buildingKey = key,
        buildingSignature = signature,
    }
    -- Windows and ordinary doors use the same deterministic material decision;
    -- no random convenience barricade API is used.
    local plankIndex = Random.coordinateIndex(
        square:getX(), square:getY(), square:getZ(), salt(square, target.descriptor, "planks"), 3
    )
    if remnant == true then
        operation.planks = (plankIndex or 1) <= 2 and 1 or 2
        operation.metal = false
        operation.remnant = true
    else
        operation.planks = (plankIndex or 1) + 1
        operation.metal = (Random.coordinateHash(
            square:getX(), square:getY(), square:getZ(), salt(square, target.descriptor, "metal")
        ) % 5) == 0
    end
    append(plan, operation)
end

function Openings.planObject(square, obj, cfg, plan, context, profile)
    if not square or Protection.isProtectedObject(obj, square, context)
        or not obj or not plan or not Validation.isPreservationSafeOpening(obj, context) then
        return false
    end

    local isWindow = instanceof(obj, "IsoWindow")
    local isDoor = instanceof(obj, "IsoDoor")
    if not isWindow and not isDoor then return false end

    local exterior = obj:isExterior() == true
    local descriptor = Mutations.describeTarget(obj)
    if not descriptor then return false end
    local target = { object = obj, descriptor = descriptor }
    if profile == nil then profile = BuildingProfile.get(square) end
    local signature = profile and profile.signature or BuildingProfile.SIGNATURE.DISTURBED

    local damageBase = isWindow and cfg.ruinedWindowPercentage or cfg.ruinedDoorPercentage
    local damageChance = BuildingProfile.humanChance(damageBase, profile, "openingDamage")
    local barricadeChance = exterior
        and BuildingProfile.humanChance(cfg.barricadePercentage, profile, "barricade") or 0

    local damageRoll = Random.coordinatePercent(
        square:getX(), square:getY(), square:getZ(), salt(square, descriptor, "damage")
    )
    local barricadeRoll = Random.coordinatePercent(
        square:getX(), square:getY(), square:getZ(), salt(square, descriptor, "barricade")
    )
    local roleRoll = Random.coordinatePercent(
        square:getX(), square:getY(), square:getZ(), salt(square, descriptor, "history-role")
    )
    local doorOpenRoll = Random.coordinatePercent(
        square:getX(), square:getY(), square:getZ(), salt(square, descriptor, "door-open")
    )
    local doorDestroyRoll = Random.coordinatePercent(
        square:getX(), square:getY(), square:getZ(), salt(square, descriptor, "door-destroy")
    )

    local canDamage = isWindow and exterior and not obj:isInvincible()
    local canBarricade = exterior and Validation.canBarricadeOpening(obj, context)
    local canOpenDoor = isDoor and Validation.canOpenDoorForAgeing(obj, context)
    local wantsDamage = canDamage and damageRoll <= damageChance
    local wantsBarricade = canBarricade and barricadeRoll <= barricadeChance

    -- Door state is intentionally profile-driven. Interior doors are much more
    -- likely to be left open than exterior doors; breached/looted buildings are
    -- visibly less sealed than quiet/defended ones. Missing-door selection is a
    -- separate, lower-frequency path below.
    local openFactor = exterior and 0.45 or 0.72
    if signature == BuildingProfile.SIGNATURE.QUIET_ABANDONED then
        openFactor = exterior and 0.22 or 0.50
    elseif signature == BuildingProfile.SIGNATURE.LOOTED_BREACHED then
        openFactor = exterior and 0.85 or 0.90
    elseif signature == BuildingProfile.SIGNATURE.DEFENDED then
        openFactor = exterior and 0.08 or 0.35
    elseif signature == BuildingProfile.SIGNATURE.DEFENDED_BREACHED then
        openFactor = exterior and 0.60 or 0.78
    end
    local doorOpenChance = isDoor and math.min(100, damageChance * openFactor) or 0
    local wantsOpenDoor = canOpenDoor and doorOpenRoll <= doorOpenChance

    -- A minority of ordinary original doors are physically gone after ten years.
    -- Breached/looted histories carry most of this pressure; quiet and defended
    -- buildings remain predominantly intact. Interior doors use a lower factor
    -- so rooms look disturbed without every doorway becoming empty.
    local destroyFactor = exterior and 0.22 or 0.14
    if signature == BuildingProfile.SIGNATURE.QUIET_ABANDONED then
        destroyFactor = exterior and 0.08 or 0.04
    elseif signature == BuildingProfile.SIGNATURE.LOOTED_BREACHED then
        destroyFactor = exterior and 0.55 or 0.38
    elseif signature == BuildingProfile.SIGNATURE.DEFENDED then
        destroyFactor = exterior and 0.04 or 0.06
    elseif signature == BuildingProfile.SIGNATURE.DEFENDED_BREACHED then
        destroyFactor = exterior and 0.38 or 0.28
    end
    local doorDestroyChance = isDoor and math.min(70, damageChance * destroyFactor) or 0
    local canDestroyDoor = isDoor and Validation.canRemoveDoorForAgeing(obj, context)
    local wantsDestroyedDoor = canDestroyDoor and doorDestroyRoll <= doorDestroyChance

    -- Exterior ordinary doors can also show partial remnants of historical
    -- barricades. This is intentionally more common than Fix 7 so doors read as
    -- part of the abandoned building rather than untouched scenery.
    local doorRemnantFactor = 0.62
    if signature == BuildingProfile.SIGNATURE.DEFENDED then doorRemnantFactor = 0.85 end
    if signature == BuildingProfile.SIGNATURE.DEFENDED_BREACHED then doorRemnantFactor = 0.78 end
    local doorRemnantChance = (isDoor and exterior)
        and math.min(100, damageChance * doorRemnantFactor) or 0
    local wantsDoorRemnant = isDoor and exterior and canBarricade
        and damageRoll <= doorRemnantChance

    if isWindow then
        -- Defended histories favour barricades; breached/ordinary abandonment
        -- favours broken glazing. Extreme settings therefore affect the vast
        -- majority of exposed windows without making every building identical.
        if signature == BuildingProfile.SIGNATURE.DEFENDED then
            if wantsBarricade then
                addBarricade(square, target, true, profile, plan, false)
                return true
            elseif wantsDamage and roleRoll > 35 then
                addDamage(square, target, true, profile, plan)
                return true
            end
        elseif signature == BuildingProfile.SIGNATURE.DEFENDED_BREACHED then
            if wantsDamage and roleRoll > 28 then
                addDamage(square, target, true, profile, plan)
                return true
            elseif wantsBarricade then
                addBarricade(square, target, true, profile, plan, false)
                return true
            end
        elseif wantsDamage then
            addDamage(square, target, true, profile, plan)
            return true
        elseif wantsBarricade and signature == BuildingProfile.SIGNATURE.DISTURBED then
            addBarricade(square, target, true, profile, plan, false)
            return true
        end
        return false
    end

    -- Interior doors: a smaller breached subset is completely missing; the
    -- remainder can be left open. No implausible indoor barricades are created.
    if not exterior then
        if wantsDestroyedDoor then
            addDestroyedDoor(target, profile, plan, false)
            return true
        elseif wantsOpenDoor then
            addOpenDoor(target, profile, plan, false)
            return true
        end
        return false
    end

    -- Exterior ordinary doors. Defended histories prioritise barricades and
    -- intact geometry; looted/breached histories can lose the door completely.
    if signature == BuildingProfile.SIGNATURE.DEFENDED then
        if wantsBarricade then
            addBarricade(square, target, false, profile, plan, false)
            return true
        elseif wantsDoorRemnant then
            addBarricade(square, target, false, profile, plan, true)
            return true
        elseif wantsDestroyedDoor and roleRoll > 92 then
            addDestroyedDoor(target, profile, plan, true)
            return true
        elseif wantsOpenDoor and roleRoll > 80 then
            addOpenDoor(target, profile, plan, true)
            return true
        end
    elseif signature == BuildingProfile.SIGNATURE.DEFENDED_BREACHED then
        if wantsDestroyedDoor and roleRoll > 38 then
            addDestroyedDoor(target, profile, plan, true)
            return true
        elseif wantsOpenDoor and roleRoll > 28 then
            addOpenDoor(target, profile, plan, true)
            return true
        elseif wantsBarricade and roleRoll <= 55 then
            addBarricade(square, target, false, profile, plan, false)
            return true
        elseif wantsDoorRemnant then
            addBarricade(square, target, false, profile, plan, true)
            return true
        end
    elseif signature == BuildingProfile.SIGNATURE.LOOTED_BREACHED then
        if wantsDestroyedDoor then
            addDestroyedDoor(target, profile, plan, true)
            return true
        elseif wantsOpenDoor then
            addOpenDoor(target, profile, plan, true)
            return true
        elseif wantsDoorRemnant then
            addBarricade(square, target, false, profile, plan, true)
            return true
        end
    elseif signature == BuildingProfile.SIGNATURE.QUIET_ABANDONED then
        if wantsDestroyedDoor and roleRoll > 84 then
            addDestroyedDoor(target, profile, plan, true)
            return true
        elseif wantsDoorRemnant and roleRoll > 45 then
            addBarricade(square, target, false, profile, plan, true)
            return true
        elseif wantsOpenDoor and roleRoll > 55 then
            addOpenDoor(target, profile, plan, true)
            return true
        end
    else -- DISTURBED / profile unavailable
        if wantsDestroyedDoor and roleRoll > 32 then
            addDestroyedDoor(target, profile, plan, true)
            return true
        elseif wantsOpenDoor then
            addOpenDoor(target, profile, plan, true)
            return true
        elseif wantsBarricade then
            addBarricade(square, target, false, profile, plan, false)
            return true
        elseif wantsDoorRemnant then
            addBarricade(square, target, false, profile, plan, true)
            return true
        end
    end

    return false
end

function Openings.applyOperation(square, operation)
    if not square or Protection.isProtectedSquare(square) or not operation then return false end
    if Mutations.hasEffectKey(square, operation.id) then return true, false end

    local obj = Mutations.resolveObject(square, operation.target)
    if nativeEffectSatisfied(obj, operation.action) then return true, false end
    if not obj or not Validation.isPreservationSafeOpening(obj) then return false end
    if not BuildingProfile.matches(square, operation.buildingKey, operation.buildingSignature) then
        return false
    end

    -- #42 uses exact/native B42.20.4 replication paths through Mutations.
    if operation.action == "smash-window" then
        if not instanceof(obj, "IsoWindow") or obj:isInvincible() then return false end
        local applied = Mutations.smashWindow(obj)
        return applied, applied
    elseif operation.action == "open-door" then
        if not instanceof(obj, "IsoDoor") or not Validation.canOpenDoorForAgeing(obj) then return false end
        if operation.exterior ~= (obj:isExterior() == true) then return false end
        local applied = Mutations.openDoor(obj)
        return applied, applied
    elseif operation.action == "barricade-window" then
        if not instanceof(obj, "IsoWindow") or not Validation.canBarricadeOpening(obj) then return false end
        local applied = Mutations.addBarricade(obj, operation.planks or 2, operation.metal == true)
        return applied, applied
    elseif operation.action == "barricade-door" then
        if not instanceof(obj, "IsoDoor") or Validation.isSpecialDoor(obj)
            or not Validation.canBarricadeOpening(obj)
        then
            return false
        end
        local applied = Mutations.addBarricade(obj, operation.planks or 2, operation.metal == true)
        return applied, applied
    elseif operation.action == "destroy-door" then
        if not instanceof(obj, "IsoDoor") or not Validation.canRemoveDoorForAgeing(obj) then
            return false
        end
        if operation.exterior ~= (obj:isExterior() == true) then return false end
        local applied = Mutations.removeDoor(obj)
        return applied, applied
    end

    return false
end

return Openings
