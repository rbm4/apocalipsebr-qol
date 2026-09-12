-- Contextual debris planner. Human-collapse history drives building debris;
-- roads/hardscape use physical context instead of the old generic urban roll.
local Data = require("A10YL/core/A10YL_Data")
local Random = require("A10YL/core/A10YL_Random")
local SquareCheck = require("A10YL/core/A10YL_SquareCheck")
local Mutations = require("A10YL/core/A10YL_Mutations")
local Context = require("A10YL/core/A10YL_Context")
local BuildingProfile = require("A10YL/core/A10YL_BuildingProfile")
local Compatibility = require("A10YL/core/A10YL_Compatibility")
local Protection = require("A10YL/core/A10YL_Protection")
local AreaContext = require("A10YL/core/A10YL_AreaContext")

local Debris = {}

local function chance(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 100 then return 100 end
    return value
end

local function shouldPlace(square, percent, salt, patchScale)
    percent = chance(percent)
    if percent <= 0 then return false end
    if percent >= 100 then return true end

    local x, y, z = square:getX(), square:getY(), square:getZ()
    local localRoll = Random.coordinatePercent(x, y, z, salt)
    local patchRoll = Random.patchPercent(x, y, z, salt, patchScale or 5)
    local shift = math.floor((patchRoll - 50) * 0.30)
    local shiftedRoll = ((localRoll + shift - 1) % 100) + 1
    return shiftedRoll <= percent
end

local function hasBuiltContext(square)
    if not square then return false end
    local objects = square:getObjects()
    if not objects then return false end
    for i = 0, objects:size() - 1 do
        if Context.isBuiltContextObject(objects:get(i)) then return true end
    end
    return false
end

local function contextualChance(square, cfg, context, profile, profileIsNearby)
    local surface = context.surface
    local areaType = context.areaType or AreaContext.TYPE.UNKNOWN
    if surface == Context.SURFACE.RAIL then
        -- Keep track corridors clear; rail-specific debris can be added later
        -- only with a dedicated classifier/asset audit.
        return 0
    elseif surface == Context.SURFACE.INTERIOR then
        local value = BuildingProfile.humanChance(
            cfg.trashPercentageInterior, profile, "interiorDebris"
        )
        if context.exposure == Context.EXPOSURE.SEALED_INTERIOR then
            return value * 0.65
        elseif context.exposure == Context.EXPOSURE.HEAVILY_EXPOSED_INTERIOR then
            return math.min(100, value * 1.40)
        end
        return math.min(100, value * 1.15)
    elseif surface == Context.SURFACE.ROAD then
        local value = tonumber(cfg.trashOnRoadPercentage) or 0
        if context.roadClass == "ROAD_EDGE" then value = math.min(100, value * 1.5)
        else value = value * 0.70 end
        return value * AreaContext.roadDebrisMultiplier(areaType)
    elseif surface == Context.SURFACE.HARDSCAPE then
        local value = tonumber(cfg.trashPercentage) or 0
        if hasBuiltContext(square) then
            value = math.max(value, tonumber(cfg.trashNearObjectsPercentage) or 0)
        elseif profileIsNearby then
            -- Doorsteps, patios and hardscape immediately beside a building get
            -- a restrained share of the near-object litter pressure rather than
            -- looking cleaner than the rooms just inside them.
            value = math.max(value, (tonumber(cfg.trashNearObjectsPercentage) or 0) * 0.55)
        end
        if profile then value = BuildingProfile.humanChance(value, profile, "exteriorDebris") end
        if context.hardscapeClass == "EXTERIOR_HARDSCAPE_EDGE" then
            value = math.min(100, value * 1.15)
        end
        return value * AreaContext.hardscapeDebrisMultiplier(areaType)
    elseif surface == Context.SURFACE.NATURAL then
        return (tonumber(cfg.trashPercentage) or 0) * 0.55 * AreaContext.naturalDebrisMultiplier(areaType)
    elseif surface == Context.SURFACE.UPPER_EXPOSED then
        -- Roof / exposed upper-floor litter is disabled. Upper building-envelope
        -- ageing remains eligible, but plain roof surfaces do not receive loose
        -- debris and therefore no longer consume mutation budget.
        return 0
    end

    -- Unknown/protected/invalid surfaces are not guessed. Compatibility addons
    -- can provide a terrain class when they know what a custom surface means.
    return 0
end

function Debris.planSquare(square, cfg, plan, context, profile)
    if not square or Protection.isProtectedSquare(square, context) or not cfg or not plan
        or Compatibility.isSquareExcluded("debris", square, context)
        or not square:isSolidFloor()
    then
        return
    end

    context = context or Context.describeSquare(square)
    if not SquareCheck.checkWater(square, context.surface) then return end
    local profileIsNearby = false
    if profile == nil then
        profile = BuildingProfile.get(square)
        if not profile and context.surface == Context.SURFACE.HARDSCAPE then
            profile = BuildingProfile.getNearby(square)
            profileIsNearby = profile ~= nil
        end
    end
    local placementChance = contextualChance(square, cfg, context, profile, profileIsNearby)
    if not shouldPlace(
        square, placementChance,
        "debris:placement:" .. tostring(context.surface) .. ":" .. tostring(context.areaType),
        (context.surface == Context.SURFACE.INTERIOR) and 4 or 7
    ) then
        return
    end

    local spriteName = Random.coordinateElement(
        Data.getOutputPool("debris"),
        square:getX(), square:getY(), square:getZ(),
        "debris:sprite:" .. tostring(context.surface) .. ":" .. tostring(context.builtUse) .. ":" .. tostring(context.areaType)
    )
    if not spriteName then return end

    plan.operations[#plan.operations + 1] = {
        system = "debris",
        stage = 2,
        action = "spawn",
        slot = "primary",
        spriteName = spriteName,
        expectedSurface = context.surface,
        expectedExposure = context.exposure,
        areaType = context.areaType,
        buildingKey = profile and profile.key or nil,
        buildingSignature = profile and profile.signature or nil,
    }
end

function Debris.applyOperation(square, operation)
    if Mutations.hasOwnedOperation(square, operation.id, "Debris") then return true, false end
    if not square or Protection.isProtectedSquare(square) or not operation or operation.action ~= "spawn"
        or Compatibility.isSquareExcluded("debris", square)
        or not operation.spriteName or not getSprite(operation.spriteName)
        or not SquareCheck.checkWater(square) or not square:isSolidFloor()
        or Mutations.hasSpriteObject(square, operation.spriteName)
    then
        return false
    end

    if Context.classifySurface(square) ~= operation.expectedSurface then return false end
    if operation.expectedSurface == Context.SURFACE.INTERIOR
        and Context.getExposure(square) ~= operation.expectedExposure
    then
        return false
    end

    if not BuildingProfile.matchesSquareOrNearby(square, operation.buildingKey, operation.buildingSignature) then
        return false
    end

    local placed, obj = Mutations.placePersistentDecoration(
        square, operation.spriteName, "Debris", operation.id, "special"
    )
    if not placed or not obj then return false, false end
    return true, true
end

return Debris
