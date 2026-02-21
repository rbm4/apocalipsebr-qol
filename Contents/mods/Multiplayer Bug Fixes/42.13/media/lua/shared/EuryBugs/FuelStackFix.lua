local MOD = "FuelStackFix"

local DEBUG = getCore():getDebug()

local function dlog(msg)
    if DEBUG then
        DebugLog.log(DebugType.General, "[" .. MOD .. "][SH] " .. tostring(msg))
    end
end

require "TimedActions/ISAddFuelAction"
require "TimedActions/ISBBQAddFuel"
require "TimedActions/ISTimedActionQueue"

FuelStackFix = FuelStackFix or {}
FuelStackFix.active = FuelStackFix.active or {}

function FuelStackFix.getTargetKey(target)
    if not target then return nil end

    -- IsoObject path (BBQ/Fireplace)
    if target.getSquare then
        local sq = target:getSquare()
        if sq then
            return sq:getX() .. ":" .. sq:getY() .. ":" .. sq:getZ()
        end
    end

    -- Campfire global-object lua table path (ISAddFuelAction)
    if target.x ~= nil and target.y ~= nil and target.z ~= nil then
        local x = math.floor(tonumber(target.x) or 0)
        local y = math.floor(tonumber(target.y) or 0)
        local z = math.floor(tonumber(target.z) or 0)
        return x .. ":" .. y .. ":" .. z
    end

    return nil
end

-- ============================================================================
-- Server-side completion signal (patched into vanilla actions)
-- ============================================================================

local function patchComplete(cls)
    dlog("Patching complete for: " .. tostring(cls))
    if not cls or cls.__FuelStackFixComplete then return end
    cls.__FuelStackFixComplete = true

    local _complete = cls.complete
    function cls:complete()
        dlog("Complete fired: " .. tostring(self))
        local res = _complete(self)
        local target = self.fireplace or self.campfire
        local key = FuelStackFix.getTargetKey(target)
        if isServer() and key
        then
            sendServerCommand(
                self.character,
                MOD,
                "FuelStepComplete",
                {
                    key = key
                }
            )
            dlog("Sent complete packet")
        end

        return res
    end
    dlog("Patched")
end

patchComplete(ISAddFuelAction)
patchComplete(ISBBQAddFuel)

local function addFuel(playerObj, target, fuel, timedAction, currentFuel, count)
    if fuel:isEmpty() then return end

    local max = fuel:size()
    if count then max = count end
    if max <= 0 then return end

    -- Build list of items to use (same as vanilla)
    local fuelItems = ArrayList.new()
    for i = 1, max do
        fuelItems:add(fuel:get(i - 1))
    end

    -- Vanilla prep: move to inventory
    ISCampingMenu.toPlayerInventory(playerObj, fuelItems)

    -- Vanilla prep: walk check
    if not ISCampingMenu.walkToCampfire(playerObj, target:getSquare()) then
        return
    end

    -- Vanilla prep: unequip any of the fuel items
    for i = 1, fuelItems:size() do
        local fuelItem = fuelItems:get(i - 1)
        if playerObj:isEquipped(fuelItem) then
            ISTimedActionQueue.add(ISUnequipAction:new(playerObj, fuelItem, 50))
        end
    end

    -- ------------------------------------------------------------------
    -- NEW: compute total fuel steps ONCE
    -- ------------------------------------------------------------------

   -- after building fuelItems
    if fuelItems:isEmpty() then return end

    local steps = 0
    local fuelItem = fuelItems:get(0)
    local fuelAmt = ISCampingMenu.getFuelDurationForItem(fuelItem)

    for i = 1, max do
        local item = fuelItems:get(i - 1)
        local uses = ISCampingMenu.getFuelItemUses(item)

        for j = 1, uses do
            if (currentFuel + (fuelAmt * (steps + 1))) > getCampingFuelMax() then
                return
            end
            steps = steps + 1
        end
    end

    if steps <= 0 then return end

    -- ------------------------------------------------------------------
    -- NEW: build a per-step plan (type + per-item duration)
    -- ------------------------------------------------------------------

    -- after building fuelItems
    if fuelItems:isEmpty() then return end

    local plan = {}
    local fuelNow = currentFuel or 0
    local maxFuel = getCampingFuelMax()
    local stop = false

    for i = 1, max do
        if stop then break end

        local item = fuelItems:get(i - 1)
        if item then
            local uses = ISCampingMenu.getFuelItemUses(item)
            local amt  = ISCampingMenu.getFuelDurationForItem(item)
            local typ  = item:getFullType()

            for j = 1, uses do
                if (fuelNow + amt) > maxFuel then
                    stop = true
                    break
                end
                plan[#plan + 1] = { t = typ, a = amt }
                fuelNow = fuelNow + amt
            end
        end
    end

    if #plan <= 0 then return end

    -- ------------------------------------------------------------------
    -- NEW: delegate execution to FuelStackFix
    -- ------------------------------------------------------------------

    FuelStackFix.start(
        playerObj,
        target,
        timedAction, -- ISAddFuelAction or ISBBQAddFuel
        plan
    )
end

local fuelItemList = ArrayList.new() -- used when adding fuel

ISCampingMenu.onAddAllFuel = function(playerObj, target, timedAction, currentFuel)
	local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
	for i=1,containers:size() do
		local container = containers:get(i-1)
		container:getAllEval(ISCampingMenu.isValidFuel, fuelItemList)
	end
	addFuel(playerObj, target, fuelItemList, timedAction, currentFuel)
	fuelItemList:clear() -- dont forget to clear!
end

ISCampingMenu.onAddMultipleFuel = function(playerObj, target, fuelType, timedAction, currentFuel, count)
	local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
	for i=1,containers:size() do
		local container = containers:get(i-1)
		container:getAllTypeEval(fuelType, ISCampingMenu.isValidFuel, fuelItemList)
	end
	addFuel(playerObj, target, fuelItemList, timedAction, currentFuel, count)
	fuelItemList:clear() -- dont forget to clear!
end