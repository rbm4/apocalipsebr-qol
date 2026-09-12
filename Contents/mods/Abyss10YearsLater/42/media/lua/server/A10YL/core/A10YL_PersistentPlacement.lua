-- Checkpoint 73 experimental persistence facade for ordinary decorative objects.
--
-- B42.20.4's vanilla moveable placement path performs substantially more world
-- bookkeeping than a raw AddSpecialObject/AddTileObject call: it chooses the
-- correct IsoObject subtype, inserts it through the normal placement routine,
-- replicates it, fires OnObjectAdded and recalculates the square. The Brush Tool
-- Save Fix uses this server-side path to avoid client-only brush placements.
--
-- A10YL deliberately does NOT call buildUtil.setHaveConstruction(). That flag is
-- gameplay/zone state (not a generic persistence-registration primitive) and
-- marking naturally aged squares as player construction would be inappropriate.
local Identity = require("A10YL/A10YL_Identity")
local Debug = require("A10YL/core/A10YL_Debug")

local PersistentPlacement = {}

local runtime = {
    attempted = 0,
    placed = 0,
    failed = 0,
    byType = {},
    failures = {},
    rawFallbacks = 0,
}

local moveableLoaded = false
local moveableAvailable = false

local function isAuthoritativeContext()
    if type(isServer) == "function" and isServer() then return true end
    return type(isClient) ~= "function" or not isClient()
end

local function runtimeAuthorityLabel()
    local server = type(isServer) == "function" and isServer()
    local client = type(isClient) == "function" and isClient()
    return "isServer=" .. tostring(server) .. "; isClient=" .. tostring(client)
end

local function ensureMoveableAPI()
    if moveableLoaded then return moveableAvailable end
    moveableLoaded = true

    -- B42.20+ keeps ISMoveableSpriteProps in shared/Moveables. require() returns
    -- no useful module value; the class is registered globally.
    pcall(require, "Moveables/ISMoveableSpriteProps")
    moveableAvailable = type(ISMoveableSpriteProps) == "table"
        and type(ISMoveableSpriteProps.new) == "function"
    if not moveableAvailable then
        Debug.once(
            "persistent-placement-api-missing",
            "WARN",
            "Persistent placement unavailable: ISMoveableSpriteProps could not be loaded; decorative ageing will use the raw fallback path."
        )
    end
    return moveableAvailable
end

local function bumpType(ownedType, key)
    ownedType = tostring(ownedType or "Unknown")
    local row = runtime.byType[ownedType]
    if not row then
        row = { attempted = 0, placed = 0, failed = 0 }
        runtime.byType[ownedType] = row
    end
    row[key] = (row[key] or 0) + 1
end

local function recordFailure(reason, ownedType, spriteName)
    reason = tostring(reason or "unknown")
    runtime.failed = runtime.failed + 1
    bumpType(ownedType, "failed")
    runtime.failures[reason] = (runtime.failures[reason] or 0) + 1
    Debug.once(
        "persistent-placement-failure:" .. reason,
        "WARN",
        "Persistent placement fallback engaged (" .. reason .. "); first affected sprite=" .. tostring(spriteName)
    )
end

local function markForSave(square, obj)
    if obj and type(obj.flagForHotSave) == "function" then
        pcall(obj.flagForHotSave, obj)
    end
    if square and type(square.setSquareChanged) == "function" then
        pcall(square.setSquareChanged, square)
    end
    if square and type(square.flagForHotSave) == "function" then
        pcall(square.flagForHotSave, square)
    end
    if square and type(square.getChunk) == "function" then
        local okChunk, chunk = pcall(square.getChunk, square)
        if okChunk and chunk and type(chunk.flagForHotSave) == "function" then
            pcall(chunk.flagForHotSave, chunk)
        end
    end
end

local function isSingleTileSprite(sprite)
    if not sprite or type(sprite.getSpriteGrid) ~= "function" then return true end
    local okGrid, grid = pcall(sprite.getSpriteGrid, sprite)
    if not okGrid or not grid then return true end

    -- A10YL's current decorative pools are single-square assets. Refuse an
    -- unexpected multi-tile asset here rather than asking vanilla to place only
    -- one piece of a sprite grid and creating an indestructible fragment.
    local width, height, levels = 1, 1, 1
    if type(grid.getWidth) == "function" then
        local ok, value = pcall(grid.getWidth, grid)
        if ok then width = tonumber(value) or width end
    end
    if type(grid.getHeight) == "function" then
        local ok, value = pcall(grid.getHeight, grid)
        if ok then height = tonumber(value) or height end
    end
    if type(grid.getLevels) == "function" then
        local ok, value = pcall(grid.getLevels, grid)
        if ok then levels = tonumber(value) or levels end
    end
    return width <= 1 and height <= 1 and levels <= 1
end

-- Place one ordinary A10YL decorative sprite through B42's normal server-side
-- moveable-placement machinery. Returns:
--   true, object, "moveable-internal" on success
--   false, nil, reason on a safe refusal/failure
-- No raw fallback occurs in this module; Mutations owns that policy so systems
-- can remain deterministic and the experiment is easy to remove or compare.
function PersistentPlacement.placeOwnedDecoration(square, spriteName, ownedType, operationKey)
    runtime.attempted = runtime.attempted + 1
    bumpType(ownedType, "attempted")

    if not square or type(spriteName) ~= "string" or spriteName == ""
        or type(ownedType) ~= "string" or ownedType == ""
        or type(operationKey) ~= "string" or operationKey == ""
    then
        recordFailure("invalid-arguments", ownedType, spriteName)
        return false, nil, "invalid-arguments"
    end

    if not isAuthoritativeContext() then
        Debug.once(
            "persistent-placement-authority-state",
            "WARN",
            "Persistent placement refused non-authoritative runtime; " .. runtimeAuthorityLabel()
        )
        recordFailure("client-authority", ownedType, spriteName)
        return false, nil, "client-authority"
    end

    if not ensureMoveableAPI() then
        recordFailure("moveable-api-unavailable", ownedType, spriteName)
        return false, nil, "moveable-api-unavailable"
    end

    local sprite = getSprite(spriteName)
    if not sprite then
        recordFailure("missing-sprite", ownedType, spriteName)
        return false, nil, "missing-sprite"
    end
    if not isSingleTileSprite(sprite) then
        recordFailure("multi-tile-sprite", ownedType, spriteName)
        return false, nil, "multi-tile-sprite"
    end

    local probe = IsoObject.new(getCell(), square, spriteName)
    if not probe or not probe.getSprite then
        recordFailure("probe-create-failed", ownedType, spriteName)
        return false, nil, "probe-create-failed"
    end

    local okProps, props = pcall(ISMoveableSpriteProps.new, probe:getSprite())
    if not okProps or not props or type(props.placeMoveableInternal) ~= "function" then
        recordFailure("moveable-props-unavailable", ownedType, spriteName)
        return false, nil, "moveable-props-unavailable"
    end

    -- Keep this experiment on the ordinary-object branch of vanilla placement.
    -- Floor tiles, wall overlays, windows and specialised IsoTypes can replace
    -- or attach to existing map objects; invoking those branches would mix a
    -- persistence test with new visual/destructive semantics.
    local specialTypes = {
        FloorTile = true, WallOverlay = true, Window = true, WindowObject = true,
    }
    if props.type and specialTypes[tostring(props.type)] then
        recordFailure("special-moveable-type", ownedType, spriteName)
        return false, nil, "special-moveable-type"
    end
    if props.isoType and tostring(props.isoType) ~= "IsoObject" then
        recordFailure("special-iso-type", ownedType, spriteName)
        return false, nil, "special-iso-type"
    end

    local spriteProps = sprite.getProperties and sprite:getProperties() or nil
    if spriteProps and IsoFlagType then
        local okSolid, solid = pcall(function()
            return spriteProps:has(IsoFlagType.solid) or spriteProps:has(IsoFlagType.solidtrans)
        end)
        if not okSolid or solid then
            recordFailure("solid-decoration", ownedType, spriteName)
            return false, nil, "solid-decoration"
        end
    end

    -- The internal vanilla routine expects an item so it can restore component
    -- and modData state. A disposable plank is intentionally not inserted into
    -- any inventory and is never persisted as an item; it is only the neutral
    -- carrier used by the placement API, matching vanilla prop-building usage.
    local item = type(instanceItem) == "function" and instanceItem("Base.Plank") or nil
    if not item then
        recordFailure("carrier-item-unavailable", ownedType, spriteName)
        return false, nil, "carrier-item-unavailable"
    end

    -- Vanilla placeMoveableInternal copies ordinary item modData to the placed
    -- object before its complete-item network packet is sent. Seed the neutral
    -- carrier with A10YL ownership so the authoritative object is born with its
    -- identity rather than being annotated only after replication.
    local carrierData = item.getModData and item:getModData() or nil
    if not carrierData then
        recordFailure("carrier-moddata-unavailable", ownedType, spriteName)
        return false, nil, "carrier-moddata-unavailable"
    end
    carrierData.A10YL_Owner = Identity.OWNER
    carrierData.A10YL_Type = tostring(ownedType)
    carrierData.A10YL_OpKey = tostring(operationKey)

    props.rawWeight = 10
    local okPlace, placed = pcall(props.placeMoveableInternal, props, square, item, spriteName)
    if not okPlace then
        recordFailure("place-call-error", ownedType, spriteName)
        return false, nil, "place-call-error"
    end
    if not placed or not placed.getSquare or placed:getSquare() ~= square then
        recordFailure("place-returned-no-object", ownedType, spriteName)
        return false, nil, "place-returned-no-object"
    end

    local placedSprite = placed.getSpriteName and placed:getSpriteName() or nil
    if tostring(placedSprite or "") ~= spriteName then
        -- The routine is allowed to face/snap genuine moveables. A10YL's world
        -- ageing plans require the exact deterministic sprite, so reject an
        -- unexpected substitution rather than silently changing the outcome.
        if type(square.transmitRemoveItemFromSquare) == "function" then
            pcall(square.transmitRemoveItemFromSquare, square, placed, true)
        end
        recordFailure("sprite-substituted", ownedType, spriteName)
        return false, nil, "sprite-substituted"
    end

    if not Identity.tagOwnedObject(placed, ownedType, operationKey) then
        if type(square.transmitRemoveItemFromSquare) == "function" then
            pcall(square.transmitRemoveItemFromSquare, square, placed, true)
        end
        recordFailure("ownership-tag-failed", ownedType, spriteName)
        return false, nil, "ownership-tag-failed"
    end

    -- placeMoveableInternal already performs the complete-item replication,
    -- OnObjectAdded event and neighbour recalculation. Do not retransmit here;
    -- just make the ownership tag and resulting object eligible for the next
    -- authoritative chunk save.
    markForSave(square, placed)

    runtime.placed = runtime.placed + 1
    bumpType(ownedType, "placed")
    Debug.once(
        "persistent-placement-first-success:" .. tostring(ownedType),
        nil,
        "Persistent placement active for " .. tostring(ownedType) .. "; first sprite=" .. spriteName
    )
    return true, placed, "moveable-internal"
end


function PersistentPlacement.noteRawFallback(ownedType, reason)
    runtime.rawFallbacks = runtime.rawFallbacks + 1
    local row = runtime.byType[tostring(ownedType or "Unknown")]
    if not row then
        row = { attempted = 0, placed = 0, failed = 0 }
        runtime.byType[tostring(ownedType or "Unknown")] = row
    end
    row.rawFallbacks = (row.rawFallbacks or 0) + 1
    if reason then
        local key = "fallback:" .. tostring(reason)
        runtime.failures[key] = (runtime.failures[key] or 0) + 1
    end
end

function PersistentPlacement.logSummary(reason)
    if runtime.attempted <= 0 and runtime.rawFallbacks <= 0 then return end
    print("[A10YL] PERSISTENT PLACEMENT SUMMARY (" .. tostring(reason or "runtime")
        .. "): attempted=" .. tostring(runtime.attempted)
        .. "; vanillaPlaced=" .. tostring(runtime.placed)
        .. "; vanillaFailed=" .. tostring(runtime.failed)
        .. "; rawFallbacks=" .. tostring(runtime.rawFallbacks))
end

function PersistentPlacement.getStats()
    return runtime
end

return PersistentPlacement
