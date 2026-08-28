local BicycleOptions = require("Bicycle/BicycleOptions")

---@class BicycleZombieProximity
local BicycleZombieProximity = {}

-- Tuning constants. The contact test mirrors the engine's own collision rule (two bodies overlap when
-- the distance between their centres is below the sum of their widths, IsoMovingObject.separate). The
-- values below bound and shape the slowdown layered on top of that contact.
local DEFAULT_BODY_WIDTH = 0.3
local SPEED_FLOOR = 0.08
local SMOOTH_LERP = 0.15
local KNOCKOFF_THRESHOLD = 4
local KNOCKOFF_SUSTAIN = 0.4
local MAX_CONTACT_BUFFER = 0.6
local CHEAP_REJECT_TILES = 2
local Z_CONTACT_TOLERANCE = 0.4

-- Strong slowdown curve: contact count -> speed multiplier at full strength (1 = slight bump, 4+ near
-- stop). Counts above the table use CONTACT_CURVE_MAX.
local CONTACT_CURVE = {
    [1] = 0.85,
    [2] = 0.60,
    [3] = 0.35,
}
local CONTACT_CURVE_MAX = 0.10

-- Constants the test bridge asserts against.
BicycleZombieProximity.FLOOR = SPEED_FLOOR
BicycleZombieProximity.KNOCKOFF_THRESHOLD = KNOCKOFF_THRESHOLD
BicycleZombieProximity.KNOCKOFF_SUSTAIN = KNOCKOFF_SUSTAIN

-- Per-player transient state, keyed by playerNum. Intentionally NOT persisted: after a Core.ResetLua
-- it simply re-eases from 1.0, which is harmless. Same idiom as RidingSystem's bicycleFallDropScheduled.
---@type table<number, number>
local smoothedMult = {}
---@type table<number, number>
local knockTimer = {}
---@type table<number, boolean>
local knockTriggered = {}
---@type table<number, number>
local lastCount = {}
---@type table<number, number>
local lastMult = {}

---@return number
---@nodiscard
local function strengthScalar()
    local pct = BicycleOptions.getZombieSlowdownStrength()
    if pct == nil then
        return 1.0
    end
    return pct / 100.0
end

---@return number
---@nodiscard
local function contactBufferFrac()
    local sensitivity = BicycleOptions.getZombieContactSensitivity()
    if sensitivity == nil then
        return 0.0
    end
    return (sensitivity / 100.0) * MAX_CONTACT_BUFFER
end

---@param obj IsoMovingObject|IsoGameCharacter
---@return number
---@nodiscard
local function bodyWidth(obj)
    if obj.getWidth then
        local w = obj:getWidth()
        if w and w > 0 then
            return w
        end
    end
    return DEFAULT_BODY_WIDTH
end

-- Count zombies whose body overlaps the player's, using the engine's own contact rule (centre distance
-- below playerWidth + zombieWidth, widened by the configured contact buffer). A cheap per-axis tile
-- reject keeps the precise math bounded to the immediate vicinity even during a horde.
---@param player IsoPlayer|IsoGameCharacter
---@return number
---@nodiscard
function BicycleZombieProximity.countTouchingZombies(player)
    local cell = getCell()
    if not cell then
        return 0
    end
    local zombies = cell:getZombieList()
    if not zombies then
        return 0
    end

    local px = player:getX()
    local py = player:getY()
    local pz = player:getZ()
    local pw = bodyWidth(player)
    local bufferFrac = contactBufferFrac()
    local count = 0

    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and not (zombie.isDead and zombie:isDead()) then
            local dx = px - zombie:getX()
            local dy = py - zombie:getY()
            if dx < CHEAP_REJECT_TILES and dx > -CHEAP_REJECT_TILES
                and dy < CHEAP_REJECT_TILES and dy > -CHEAP_REJECT_TILES then
                if math.abs(zombie:getZ() - pz) < Z_CONTACT_TOLERANCE then
                    local reach = (pw + bodyWidth(zombie)) * (1.0 + bufferFrac)
                    if (dx * dx + dy * dy) < (reach * reach) then
                        count = count + 1
                    end
                end
            end
        end
    end

    return count
end

-- Map a contact count to the strength-scaled, floored target speed multiplier.
---@param count number
---@return number
---@nodiscard
function BicycleZombieProximity.targetForCount(count)
    if count <= 0 then
        return 1.0
    end

    local base = CONTACT_CURVE[count]
    if base == nil then
        base = CONTACT_CURVE_MAX
    end

    local target = 1.0 - strengthScalar() * (1.0 - base)
    if target < SPEED_FLOOR then
        target = SPEED_FLOOR
    end
    if target > 1.0 then
        target = 1.0
    end
    return target
end

-- Smoothly ease the player's live multiplier toward the target for `count` (one step per call). Returns
-- the new multiplier and stores it for getLastMultiplier / getLastCount.
---@param player IsoPlayer|IsoGameCharacter
---@param count number
---@return number
function BicycleZombieProximity.computeMultiplier(player, count)
    local target = BicycleZombieProximity.targetForCount(count)
    local playerNum = player:getPlayerNum()

    local current = smoothedMult[playerNum]
    if current == nil then
        current = 1.0
    end

    current = current + (target - current) * SMOOTH_LERP
    if current < SPEED_FLOOR then
        current = SPEED_FLOOR
    end
    if current > 1.0 then
        current = 1.0
    end

    smoothedMult[playerNum] = current
    lastCount[playerNum] = count
    lastMult[playerNum] = current
    return current
end

-- Knock the rider off once `count` >= KNOCKOFF_THRESHOLD has been sustained for KNOCKOFF_SUSTAIN
-- seconds. Reuses the mod's existing BumpFall path: RidingSystem.bicycleFallOff picks these variables
-- up next tick and schedules the drop. `dtOverride` lets a test inject deterministic time. Returns true
-- on the single tick it fires.
---@param player IsoPlayer|IsoGameCharacter
---@param count number
---@param dtOverride number|nil
---@return boolean
function BicycleZombieProximity.maybeKnockOff(player, count, dtOverride)
    local playerNum = player:getPlayerNum()

    if count < KNOCKOFF_THRESHOLD then
        knockTimer[playerNum] = 0
        knockTriggered[playerNum] = nil
        return false
    end

    local dt = dtOverride
    if dt == nil then
        dt = GameTime.getInstance():getTimeDelta()
    end

    knockTimer[playerNum] = (knockTimer[playerNum] or 0) + dt
    if knockTimer[playerNum] < KNOCKOFF_SUSTAIN then
        return false
    end
    if knockTriggered[playerNum] then
        return false
    end

    knockTriggered[playerNum] = true
    player:setVariable("BumpFall", true)
    player:setVariable("BumpDone", false)
    player:setVariable("TripObstacleType", "zombie")
    player:setBumpType("left")
    return true
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return number
---@nodiscard
function BicycleZombieProximity.getLastCount(player)
    if not player then
        return 0
    end
    return lastCount[player:getPlayerNum()] or 0
end

---@param player IsoPlayer|IsoGameCharacter|nil
---@return number
---@nodiscard
function BicycleZombieProximity.getLastMultiplier(player)
    if not player then
        return 1.0
    end
    return lastMult[player:getPlayerNum()] or 1.0
end

-- Clear all per-player transient state (call when the player stops riding or the feature is disabled).
---@param player IsoPlayer|IsoGameCharacter|nil
---@return nil
function BicycleZombieProximity.reset(player)
    if not player then
        return
    end
    local playerNum = player:getPlayerNum()
    smoothedMult[playerNum] = nil
    knockTimer[playerNum] = nil
    knockTriggered[playerNum] = nil
    lastCount[playerNum] = nil
    lastMult[playerNum] = nil
end

return BicycleZombieProximity
