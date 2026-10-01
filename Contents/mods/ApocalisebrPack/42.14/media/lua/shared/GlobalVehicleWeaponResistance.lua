local GlobalVehicleWeaponResistance = {}

-- Vehicle weapon damage is divided by the durability of the part that was hit.
-- Collision damage, zombie attacks, and the Smash Window timed action bypass it.
GlobalVehicleWeaponResistance.DURABILITY_MULTIPLIER = 5

local function getBaseDurability(part)
    local item = part:getInventoryItem()
    if item and item:getDurability() > 0 then
        return item:getDurability()
    end

    local scriptPart = part:getScriptPart()
    if scriptPart and scriptPart:getDurability() > 0 then
        return scriptPart:getDurability()
    end

    return nil
end

local function strengthenVehicle(vehicle)
    if not vehicle then return end

    for index = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(index)
        if part then
            local baseDurability = getBaseDurability(part)
            if baseDurability then
                part:setDurability(
                    baseDurability * GlobalVehicleWeaponResistance.DURABILITY_MULTIPLIER
                )
            end
        end
    end
end

local function strengthenLoadedVehicles()
    local cell = getCell()
    if not cell then return end

    local vehicles = cell:getVehicles()
    if not vehicles then return end

    local iterator = vehicles:iterator()
    while iterator:hasNext() do
        strengthenVehicle(iterator:next())
    end
end

-- Run on both clients and the authoritative server. The periodic pass also
-- reapplies resistance after a vehicle part is installed or replaced.
-- Events.OnGameStart.Add(strengthenLoadedVehicles)
-- Events.LoadChunk.Add(strengthenLoadedVehicles)
-- Events.EveryOneMinute.Add(strengthenLoadedVehicles)

-- if Events.OnServerStarted then
--     Events.OnServerStarted.Add(strengthenLoadedVehicles)
-- end

