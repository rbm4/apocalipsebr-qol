-- Safe additive structural weathering.
-- Point #5 enables vanilla cosmetic wall-crack overlays on preservation-safe,
-- map-authored walls. It never replaces/removes walls and roof failure remains
-- reserved until a separately verified non-destructive implementation exists.
local Data = require("A10YL/core/A10YL_Data")
local Random = require("A10YL/core/A10YL_Random")
local Mutations = require("A10YL/core/A10YL_Mutations")
local Validation = require("A10YL/core/A10YL_Validation")
local Context = require("A10YL/core/A10YL_Context")
local BuildingProfile = require("A10YL/core/A10YL_BuildingProfile")
local Protection = require("A10YL/core/A10YL_Protection")

local Structures = {}
local WALL_CRACK_PREFIX = "d_wallcracks_1_"

local function planWeathering(kind, square, obj, baseChance, plan, context, profile)
    if not square or Protection.isProtectedObject(obj, square, context) or not obj or not plan then return false end
    if not Validation.isPreservationSafeStructure(obj, kind, context) then return false end

    local orientation = nil
    if kind == "wall" then
        orientation = Validation.getOriginalWallOrientation(obj)
        if not orientation then return false end
        -- Respect either native erosion cracks or an already-generated A10YL
        -- crack. A wall should never accumulate multiple crack overlays.
        if Mutations.hasSpritePrefix(square, WALL_CRACK_PREFIX) then return false end
    end

    local pool = Data.getStructureWeatheringPool(kind, orientation)
    if type(pool) ~= "table" or #pool == 0 then return false end

    local surface = context and context.surface or Context.classifySurface(square)
    if surface == Context.SURFACE.RAIL then return false end

    if profile == nil then profile = BuildingProfile.get(square) end
    local chance = BuildingProfile.weatherChance(baseChance, profile, "structure")
    chance = tonumber(chance) or 0
    if chance <= 0 then return false end

    local target = Mutations.describeTarget(obj)
    if not target then return false end

    local x, y, z = square:getX(), square:getY(), square:getZ()
    local targetKey = Mutations.targetKey(target)
    if Random.coordinatePercent(
        x, y, z, "structures:" .. kind .. ":presence:" .. targetKey
    ) > chance then
        return false
    end

    local overlay = Random.coordinateElement(
        pool, x, y, z,
        "structures:" .. kind .. ":overlay:" .. tostring(orientation or "U") .. ":" .. targetKey
    )
    -- Vanilla assets are intentionally checked at runtime as well as in source
    -- research. A missing/renamed future sprite simply fails closed.
    if not overlay or not getSprite(overlay) then return false end

    plan.operations[#plan.operations + 1] = {
        system = "structures",
        stage = 6,
        action = "weather-overlay",
        slot = Mutations.semanticSlot(obj),
        kind = kind,
        orientation = orientation,
        spriteName = overlay,
        target = target,
        expectedTextureName = tostring(obj:getTextureName() or ""),
        buildingKey = profile and profile.key or nil,
        buildingSignature = profile and profile.signature or nil,
    }
    return true
end

function Structures.planRoof(square, obj, cfg, plan, context, profile)
    if not cfg or not cfg.features or not cfg.features.roofs then return false end
    return planWeathering("roof", square, obj, cfg.roofPercentage, plan, context, profile)
end

function Structures.planWall(square, obj, cfg, plan, context, profile)
    if not cfg or not cfg.features or not cfg.features.walls then return false end
    return planWeathering("wall", square, obj, cfg.wallPercentage, plan, context, profile)
end

function Structures.applyOperation(square, operation)
    if not square or Protection.isProtectedSquare(square) or not operation or operation.action ~= "weather-overlay" then return false end
    if not operation.spriteName or not getSprite(operation.spriteName) then return false end
    if not BuildingProfile.matches(square, operation.buildingKey, operation.buildingSignature) then
        return false
    end

    local obj = Mutations.resolveObject(square, operation.target)
    if not obj or Protection.isProtectedObject(obj, square)
        or not Validation.isPreservationSafeStructure(obj, operation.kind) then
        return false
    end
    if tostring(obj:getTextureName() or "") ~= tostring(operation.expectedTextureName or "") then
        return false
    end

    if operation.kind == "wall" then
        local currentOrientation = Validation.getOriginalWallOrientation(obj)
        if not currentOrientation or currentOrientation ~= operation.orientation then
            return false, false
        end
    end

    local legacy = Mutations.findOwnedByOperationKey(square, operation.id, "StructureOverlay")
    if legacy == false then return false, false end
    if legacy then Mutations.removeOwnedObject(square, legacy) end

    if Mutations.hasAttachedSprite(obj, operation.spriteName) then
        return true, false
    end

    -- If vanilla erosion (or another compatible system) added a crack after the
    -- plan was built, accept that visual state rather than stacking another one.
    if operation.kind == "wall" and Mutations.hasSpritePrefix(square, WALL_CRACK_PREFIX) then
        return true, false
    end

    -- Cosmetic structural ageing is attached to the persistent map-authored
    -- object instead of creating a separate save-sensitive tile object. Existing
    -- attachments are preserved.
    if not Mutations.addAttachedSprite(obj, operation.spriteName, operation.id, "StructureOverlay") then
        return false, false
    end
    return true, true
end

return Structures
