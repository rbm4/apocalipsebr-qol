-- Client-side visual smoothing for Biochemical armor.
-- The server owns real condition changes and armor drain. This only restores
-- protected parts locally to the server-saved baseline while the confirmation
-- packet is in flight.

local SAVED_COND_KEY = "biochem:savedCond"
local PART_SLOT_COUNT = 18
local TICK_INTERVAL_MS = 250
local _lastTickTime = 0

local function restoreVisualPart(part)
    local savedCond = part:getModData()[SAVED_COND_KEY]
    if savedCond and part:getCondition() < savedCond then
        part:setCondition(savedCond)
    end
end

local function applyVisualProtection(vehicle, armorPart)
    if armorPart:getCondition() <= 0 then return end

    local armorTable = armorPart:getTable("Biochemical_Armor")
    if not armorTable then return end

    for i = 1, PART_SLOT_COUNT do
        local partId = armorTable["part" .. i]
        if partId then
            local protectedPart = vehicle:getPartById(partId)
            if protectedPart then
                restoreVisualPart(protectedPart)
            end
        end
    end

    local truckBed = vehicle:getPartById("TruckBed")
    if truckBed then
        restoreVisualPart(truckBed)
    end
end

local function onClientTick()
    local now = Calendar.getInstance():getTimeInMillis()
    if now - _lastTickTime < TICK_INTERVAL_MS then return end
    _lastTickTime = now

    local player = getPlayer()
    local vehicle = player and player:getVehicle()
    if vehicle then
        local bumperPart = vehicle:getPartById("Biochemical_BumperPart")
        if bumperPart and bumperPart:getInventoryItem() then
            applyVisualProtection(vehicle, bumperPart)
        end
    end
end

Events.OnTick.Add(onClientTick)
