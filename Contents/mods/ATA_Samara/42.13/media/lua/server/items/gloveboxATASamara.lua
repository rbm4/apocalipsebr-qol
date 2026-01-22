local function maybeAddItemOnFill(roomName, containerType, container)
    -- Only target gloveboxes
    if containerType ~= "GloveBox" then return end
    if not container or not container.getVehiclePart then return end

    local part = container:getVehiclePart()
    if not part then return end

    local vehicle = part:getVehicle()
    if not vehicle or not vehicle.getScript then return end

    local script = vehicle:getScript()
    if not script then return end

    local scriptName = script:getName() -- e.g., "CarNormal", "CarLuxury", or a modded script name

    -- Only for a specific car script
    if scriptName ~= "ATASamaraPolice" and scriptName ~= "ATASamaraClassic" then return end

    -- Example: 15% chance to add a ATATuningFMS_S281 to this glovebox instance
    if ZombRandFloat(0.0, 1.0) < 0.15 then
        container:AddItem("ATA2.ATATuningChevalierSamara")
        -- Optional: print for debugging
        -- print(string.format("[MyMod] Added ATATuningFMS_S281 to %s glovebox.", scriptName))
    end
end

Events.OnFillContainer.Add(maybeAddItemOnFill)