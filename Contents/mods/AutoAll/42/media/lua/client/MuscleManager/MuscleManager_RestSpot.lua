--[[
    [B42.20] Muscle Manager (Build 42 / SP + MP)
    ------------------------------------------------------------------
    Rests on nearby furniture (bed, couch, gym mat - anything the game
    itself considers a valid seat) instead of always sitting on the floor,
    then walks back to where training was happening for the next set.

    "Valid seat" is not a guessed sprite list: SeatingManager is the exact
    same registry ISRestAction and the vanilla right-click "Rest" option
    already use (SeatingManager.getInstance():getTilePositionCount(obj) > 0),
    so this recognizes whatever furniture the game itself would let the
    player rest on. Resting itself is queued through
    ISWorldObjectContextMenu.onRest(furniture, player) - the very same
    function "Rest" in the right-click menu calls - so pathing, seat
    orientation and animation are exactly vanilla's, not a re-derived copy
    of that math.

    One honest caveat: the game does distinguish "sitting on furniture" from
    "sitting on the ground" internally (isSittingOnFurniture(), setIsResting()),
    but the exact endurance-recovery-rate difference between them lives in
    compiled Java this mod can't decompile, so it isn't independently
    verified here - only the mechanism itself is real.
]]

MuscleManager = MuscleManager or {}
local MM = MuscleManager

if MM.restSpotLoaded then return end
MM.restSpotLoaded = true

local RETURN_DIST = 2 -- tiles; close enough to "home" that walking back is pointless

--- Nearest object within reach that the game itself would offer "Rest" on -
--- beds, couches, benches, mats... whatever SeatingManager already knows
--- about - skipping anything already occupied.
local function findRestFurniture(player)
    if not SeatingManager then return nil end
    local square = player:getSquare()
    if not square or not getCell() then return nil end
    local seating = SeatingManager.getInstance()
    local radius = MM.opt("travelRange") or 6

    local best, bestDist = nil, nil
    for dx = -radius, radius do
        for dy = -radius, radius do
            local dist = math.max(math.abs(dx), math.abs(dy))
            if not bestDist or dist < bestDist then
                local s = getCell():getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
                if s then
                    local objects = s:getObjects()
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        local ok, count = pcall(function() return seating:getTilePositionCount(obj) end)
                        if ok and count and count > 0 then
                            local free = true
                            local okOcc, occupied = pcall(function() return obj:isFurnitureOccupied(player) end)
                            if okOcc then free = not occupied end
                            if free then
                                best, bestDist = obj, dist
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

--- Starts resting on furniture if any is in reach; returns true when it
--- queued something (the caller should not also sit on the ground itself).
function MM.tryRestOnFurniture(state)
    if not MM.opt("restOnFurniture") then return false end
    local player = state.player
    if player:isSitOnGround() or player:isSittingOnFurniture() then return true end

    local furniture = findRestFurniture(player)
    if not furniture then return false end

    state.restFurniture = furniture
    ISWorldObjectContextMenu.onRest(furniture, player:getPlayerNum())
    return true
end

--- Cancels a rest action still in progress (safety stop, or the character
--- has recovered enough to train again).
function MM.stopRestAction(player)
    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    local action = queue and queue.queue[1]
    if action and (action.Type == "ISRestAction" or action.Type == "ISPathFindAction") and action.action then
        action.action:forceStop()
    end
end

--- Called once a set is about to start again: if the last rest happened on
--- furniture away from the training spot, walk back there first. Vanilla's
--- own ISFitnessAction:waitToStart() already handles standing back up.
function MM.returnFromRestSpot(state)
    if not state.restFurniture then return end
    state.restFurniture = nil
    local player = state.player
    local home = state.homeSquare
    if not home then return end
    local square = player:getSquare()
    if square and square:DistToProper(home) <= RETURN_DIST then return end
    ISTimedActionQueue.add(ISWalkToTimedAction:new(player, home))
end
