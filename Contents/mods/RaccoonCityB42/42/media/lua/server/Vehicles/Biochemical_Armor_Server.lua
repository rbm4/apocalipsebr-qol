--[[
    Biochemical_Armor_Server.lua
    Server-side armor protection for the Biochemical_PickupTruck.

    Replaces the old client-side OnPlayerUpdate approach that broke in B42.18 because
    VehiclePart:setCondition() called from a client-side shared script no longer syncs
    to the server. All condition changes now happen on the server via the vehicle part
    update callback (lua { update = ... }), which is the authoritative B42 pattern.

    The Biochemical_BumperPart declares which parts it protects through the script-side
    "table Biochemical_Armor { part1 = ..., part2 = ..., ... }" block. On each server
    update tick (every game minute), we:
      1. Lazy-init a saved baseline condition for each protected part (first run only).
      2. Heal any protected part whose condition fell below its baseline back to that
         baseline, and drain the armor bumper by 1 per healed part.
      3. Apply the same baseline-restore logic to TruckBed (was a broken sendClientCommand
         hack before) so that the structural bed of the truck is also protected.
]]--

Biochemical_Armor = Biochemical_Armor or {}

-- Key used to store the per-part saved-condition baseline in modData.
local SAVED_COND_KEY = "biochem:savedCond"

-- Number of protected slots declared in the Biochemical_Armor script table.
local PART_SLOT_COUNT = 18

-- Real-time interval (game-time ms) between fast-path tick checks.
-- Protection fires at most once per this interval for player-occupied vehicles,
-- in addition to the normal once-per-game-minute lua { update } callback.
local TICK_INTERVAL_MS = 1000
local _lastTickTime = 0

-- Saves the current condition of a VehiclePart as its protection baseline.
local function saveBaseline(vehicle, part)
    part:getModData()[SAVED_COND_KEY] = part:getCondition()
    vehicle:transmitPartModData(part)
end

-- Restore a protected part to its saved baseline and drain the armor part by 1.
-- Returns true if armor was drained (caller should check armor reached 0).
local function absorbDamage(vehicle, armorPart, protectedPart, savedCond)
    protectedPart:setCondition(savedCond)
    vehicle:transmitPartCondition(protectedPart)

    local newArmorCond = math.max(0, armorPart:getCondition() - 1)
    armorPart:setCondition(newArmorCond)
    vehicle:transmitPartCondition(armorPart)

    return newArmorCond <= 0
end

-- -----------------------------------------------------------------------
-- applyProtection  (internal)
-- Core protection loop shared by the minute-update callback and the
-- fast-path OnTick handler.  Safe to call at any frequency: the bumper
-- only drains when a protected part's condition has actually dropped below
-- its saved baseline; once restored, subsequent calls are no-ops.
-- -----------------------------------------------------------------------
local function applyProtection(vehicle, part)
    if part:getCondition() <= 0 then return end

    local armorTable = part:getTable("Biochemical_Armor")
    if not armorTable then return end

    for i = 1, PART_SLOT_COUNT do
        local partId = armorTable["part" .. i]
        if partId then
            local pp = vehicle:getPartById(partId)
            if pp then
                local md = pp:getModData()

                -- Lazy-init baseline on first update (handles parts that existed
                -- before this code was deployed onto a live save).
                if not md[SAVED_COND_KEY] then
                    saveBaseline(vehicle, pp)
                end

                local savedCond = md[SAVED_COND_KEY]
                if pp:getCondition() < savedCond then
                    local armorExhausted = absorbDamage(vehicle, part, pp, savedCond)
                    if armorExhausted then return end
                end
            end
        end
    end

    -- TruckBed protection: the structural bed of the Biochemical truck is treated
    -- as part of its armored chassis — keep it at its saved condition.
    local truckBed = vehicle:getPartById("TruckBed")
    if truckBed then
        local md = truckBed:getModData()
        if not md[SAVED_COND_KEY] then
            saveBaseline(vehicle, truckBed)
        end
        local savedCond = md[SAVED_COND_KEY]
        if truckBed:getCondition() < savedCond then
            -- TruckBed restoration does NOT drain armor (it's structural, not absorbed).
            truckBed:setCondition(savedCond)
            vehicle:transmitPartCondition(truckBed)
        end
    end
end

-- -----------------------------------------------------------------------
-- Biochemical_Armor.Create
-- Called server-side when the vehicle is first spawned (create callback).
-- Seeds the protection baseline for all parts immediately so that the very
-- first Update tick has a valid reference rather than a lazy-init value.
-- -----------------------------------------------------------------------
function Biochemical_Armor.Create(vehicle, part)
    Vehicles.Create.Default(vehicle, part)

    local armorTable = part:getTable("Biochemical_Armor")
    if not armorTable then return end

    for i = 1, PART_SLOT_COUNT do
        local partId = armorTable["part" .. i]
        if partId then
            local pp = vehicle:getPartById(partId)
            if pp then saveBaseline(vehicle, pp) end
        end
    end

    -- Also seed TruckBed baseline on creation.
    local truckBed = vehicle:getPartById("TruckBed")
    if truckBed then saveBaseline(vehicle, truckBed) end
end

-- -----------------------------------------------------------------------
-- Biochemical_Armor.Update
-- Called server-side every game minute for the installed Biochemical_BumperPart.
-- Serves as the fallback guarantee that protection is applied even for
-- vehicles that no player is actively riding in.
-- -----------------------------------------------------------------------
function Biochemical_Armor.Update(vehicle, part, elapsedMinutes)
    local item = part:getInventoryItem()
    if not item then return end
    applyProtection(vehicle, part)
end

-- -----------------------------------------------------------------------
-- Fast-path OnTick handler
-- Fires every TICK_INTERVAL_MS game-milliseconds for each online player's
-- current vehicle.  This ensures that zombie hits are absorbed within ~1
-- game-second rather than waiting up to a full game minute, making the
-- bumper feel like it provides real-time protection.
--
-- Draining is safe at this frequency: absorbDamage only fires when
-- pp:getCondition() < savedCond — once a part is restored to its baseline,
-- subsequent ticks are no-ops until new damage arrives.
-- -----------------------------------------------------------------------
local function onServerTick()
    local now = Calendar.getInstance():getTimeInMillis()
    if now - _lastTickTime < TICK_INTERVAL_MS then return end
    _lastTickTime = now

    local playerList = getOnlinePlayers()
    for i = 0, playerList:size() - 1 do
        local player = playerList:get(i)
        local vehicle = player:getVehicle()
        if vehicle then
            local bumperPart = vehicle:getPartById("Biochemical_BumperPart")
            if bumperPart and bumperPart:getInventoryItem() then
                applyProtection(vehicle, bumperPart)
            end
        end
    end
end

Events.OnTick.Add(onServerTick)
