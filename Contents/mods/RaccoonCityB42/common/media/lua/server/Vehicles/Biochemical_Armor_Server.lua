--[[
    Biochemical_Armor_Server.lua
    Server-side armor protection for the Biochemical_PickupTruck.

    VehiclePart:setCondition() from client Lua is not authoritative in B42 MP,
    so all protection work happens on the server. The bumper part declares the
    parts it protects through table Biochemical_Armor in the vehicle script.

    Baselines are seeded when the vehicle spawns and when the armor is installed.
    When a protected part falls below its saved baseline, the server restores it
    to that exact baseline and drains bumper condition by the protected damage
    absorbed. This keeps a hood that was 100 before impact returning to 100,
    while avoiding free upgrades for parts that were already damaged at install.
]]--

Biochemical_Armor = Biochemical_Armor or {}

local SAVED_COND_KEY = "biochem:savedCond"
local ARMOR_DRAIN_CARRY_KEY = "biochem:armorDrainCarry"

local PART_SLOT_COUNT = 18

-- Default armor drain per point of protected damage when the script table does
-- not provide Biochemical_ArmorRate.Biochemical_Bumper.
local DEFAULT_ARMOR_DRAIN_RATE = 0.04

-- Game-time milliseconds. This runs much faster than the normal vehicle-part
-- update callback, which only fires once per in-game minute.
local TICK_INTERVAL_MS = 250
local _lastTickTime = 0

local function clampCondition(value)
    return math.max(0, math.min(100, math.floor((tonumber(value) or 0) + 0.5)))
end

local function getArmorDrainRate(armorPart)
    local armorTable = armorPart:getTable("Biochemical_Armor")
    local rateTable = armorTable and armorTable["Biochemical_ArmorRate"]
    local rate = rateTable and rateTable["Biochemical_Bumper"]
    return tonumber(rate) or DEFAULT_ARMOR_DRAIN_RATE
end

local function saveBaseline(vehicle, part, condition)
    part:getModData()[SAVED_COND_KEY] = clampCondition(condition or part:getCondition())
    vehicle:transmitPartModData(part)
end

local function ensureBaseline(vehicle, part)
    local md = part:getModData()
    local savedCond = md[SAVED_COND_KEY]
    if savedCond == nil then
        savedCond = part:getCondition()
        saveBaseline(vehicle, part, savedCond)
    elseif part:getCondition() > savedCond then
        savedCond = part:getCondition()
        saveBaseline(vehicle, part, savedCond)
    end
    return clampCondition(savedCond)
end

local function seedProtectedBaselines(vehicle, armorPart)
    local armorTable = armorPart:getTable("Biochemical_Armor")
    if not armorTable then return end

    for i = 1, PART_SLOT_COUNT do
        local partId = armorTable["part" .. i]
        if partId then
            local protectedPart = vehicle:getPartById(partId)
            if protectedPart then
                saveBaseline(vehicle, protectedPart)
            end
        end
    end

    local truckBed = vehicle:getPartById("TruckBed")
    if truckBed then
        saveBaseline(vehicle, truckBed)
    end
end

local function drainArmor(vehicle, armorPart, damageDelta)
    local armorMd = armorPart:getModData()
    local drainCarry = (tonumber(armorMd[ARMOR_DRAIN_CARRY_KEY]) or 0)
        + (damageDelta * getArmorDrainRate(armorPart))
    local drainWhole = math.floor(drainCarry)

    armorMd[ARMOR_DRAIN_CARRY_KEY] = drainCarry - drainWhole
    vehicle:transmitPartModData(armorPart)

    if drainWhole <= 0 then
        return false
    end

    local newArmorCond = math.max(0, armorPart:getCondition() - drainWhole)
    armorPart:setCondition(newArmorCond)
    vehicle:transmitPartCondition(armorPart)
    return newArmorCond <= 0
end

local function restoreProtectedPart(vehicle, armorPart, protectedPart, savedCond)
    local damageDelta = savedCond - protectedPart:getCondition()
    if damageDelta <= 0 then
        return false
    end

    protectedPart:setCondition(savedCond)
    vehicle:transmitPartCondition(protectedPart)

    return drainArmor(vehicle, armorPart, damageDelta)
end

local function applyProtection(vehicle, armorPart)
    if armorPart:getCondition() <= 0 then return end

    local armorTable = armorPart:getTable("Biochemical_Armor")
    if not armorTable then return end

    for i = 1, PART_SLOT_COUNT do
        local partId = armorTable["part" .. i]
        if partId then
            local protectedPart = vehicle:getPartById(partId)
            if protectedPart then
                local savedCond = ensureBaseline(vehicle, protectedPart)
                local armorExhausted = restoreProtectedPart(vehicle, armorPart, protectedPart, savedCond)
                if armorExhausted then return end
            end
        end
    end

    -- The truck bed is treated as structural armor. It restores to its saved
    -- baseline, but does not consume bumper condition.
    local truckBed = vehicle:getPartById("TruckBed")
    if truckBed then
        local savedCond = ensureBaseline(vehicle, truckBed)
        if truckBed:getCondition() < savedCond then
            truckBed:setCondition(savedCond)
            vehicle:transmitPartCondition(truckBed)
        end
    end
end

function Biochemical_Armor.Create(vehicle, part)
    Vehicles.Create.Default(vehicle, part)
    seedProtectedBaselines(vehicle, part)
end

function Biochemical_Armor.InstallComplete(vehicle, part)
    seedProtectedBaselines(vehicle, part)
end

function Biochemical_Armor.Update(vehicle, part, elapsedMinutes)
    if not part:getInventoryItem() then return end
    applyProtection(vehicle, part)
end

local function onServerTick()
    local now = Calendar.getInstance():getTimeInMillis()
    if now - _lastTickTime < TICK_INTERVAL_MS then return end
    _lastTickTime = now

    local processed = {}
    local playerList = getOnlinePlayers()
    for i = 0, playerList:size() - 1 do
        local player = playerList:get(i)
        local vehicle = player:getVehicle()
        if vehicle and not processed[vehicle] then
            processed[vehicle] = true
            local bumperPart = vehicle:getPartById("Biochemical_BumperPart")
            if bumperPart and bumperPart:getInventoryItem() then
                applyProtection(vehicle, bumperPart)
            end
        end
    end
end

Events.OnTick.Add(onServerTick)
