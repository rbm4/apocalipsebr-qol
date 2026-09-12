local Random = require("A10YL/core/A10YL_Random")
local Mutations = require("A10YL/core/A10YL_Mutations")
local Validation = require("A10YL/core/A10YL_Validation")
local Context = require("A10YL/core/A10YL_Context")
local BuildingProfile = require("A10YL/core/A10YL_BuildingProfile")
local Protection = require("A10YL/core/A10YL_Protection")

local Fences = {}

local function append(plan, operation)
    operation.system = "fences"
    operation.stage = 5
    plan.operations[#plan.operations + 1] = operation
end

local function salt(square, target, suffix)
    return "fences:" .. tostring(suffix) .. ":" .. Mutations.targetKey(target)
        .. ":" .. tostring(square:getX()) .. ":" .. tostring(square:getY()) .. ":" .. tostring(square:getZ())
end

local function clamp(value, low, high)
    value = tonumber(value) or 0
    if value < low then return low end
    if value > high then return high end
    return value
end

function Fences.planObject(square, obj, cfg, plan, context, profile)
    if not square or Protection.isProtectedObject(obj, square, context) or not obj or not plan then return false end
    if not Validation.isPreservationSafeFence(obj, context) then return false end
    local surface = context and context.surface or Context.classifySurface(square)
    if surface == Context.SURFACE.RAIL then return false end

    local properties = obj:getProperties()
    local target = Mutations.describeTarget(obj)
    if not target then return false end

    if profile == nil then
        profile = BuildingProfile.get(square) or BuildingProfile.getNearby(square)
    end
    local presenceChance = BuildingProfile.weatherChance(cfg.fencePercentage, profile, "fence")
    if Random.coordinatePercent(square:getX(), square:getY(), square:getZ(), salt(square, target, "presence"))
        > presenceChance
    then
        return false
    end

    -- Weather pressure controls whether an aged boundary actually loses a
    -- segment. Point #3 no longer uses BrokenFences sprite-state transitions: in
    -- live B42.20.4 MP those transitions coincided with generic sprite-sync spam.
    -- Sparse physical gaps remain visually convincing and use the same replicated
    -- square-removal primitive already validated for ordinary failed doors.
    local weatherPressure = profile and profile.weatherPressure
        or Random.patchPercent(square:getX(), square:getY(), square:getZ(), "fences:weather", 9)
    local severityFactor = BuildingProfile.getEffect(profile, "fenceSeverity")
    local removeThreshold = clamp(
        (6 + (tonumber(weatherPressure) or 50) * 0.18) * severityFactor,
        5, 38
    )
    local roll = Random.coordinatePercent(square:getX(), square:getY(), square:getZ(), salt(square, target, "action"))
    if roll > removeThreshold then return false end

    -- Only ordinary N/W collision-axis fence objects are eligible. Unsupported
    -- decorative fence-like objects continue to fail closed.
    if not properties:has(IsoFlagType.collideN) and not properties:has(IsoFlagType.collideW) then
        return false
    end
    local action = "remove-segment"

    append(plan, {
        slot = Mutations.semanticSlot(obj),
        action = action,
        target = target,
        buildingKey = profile and profile.key or nil,
        buildingSignature = profile and profile.signature or nil,
    })
    return action
end

function Fences.applyOperation(square, operation)
    if not square or Protection.isProtectedSquare(square) or not operation or operation.action ~= "remove-segment" then
        return false
    end
    if Context.classifySurface(square) == Context.SURFACE.RAIL then return false end
    if not BuildingProfile.matchesSquareOrNearby(square, operation.buildingKey, operation.buildingSignature) then
        return false
    end

    local obj = Mutations.resolveObject(square, operation.target)
    if not obj or Protection.isProtectedObject(obj, square) or not Validation.isPreservationSafeFence(obj) then return false end
    if not Mutations.removeOriginalObject(obj) then return false end
    return true, true
end

return Fences
