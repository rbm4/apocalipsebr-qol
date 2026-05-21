--[[
    Generic Armor Protection - part of that DAMN Library (Workshop ID 3171167894)
    authored by KI5 / bikinihorst.

    Provides a shared armor handler that runs automatically for all damnlib-managed
    vehicles. For each DAMN armor part installed on the vehicle, if any of its
    covered vanilla parts have taken damage (condition < saveCond), the armor
    part absorbs the damage and the vanilla part is restored.

    This handler runs alongside per-vehicle custom armor handlers registered via
    DAMN.Armor:add, and is safe to run concurrently with them (no double-drain).
    It is called from DAMN.inVehicleUpdateTask once per OnPlayerUpdate cycle.
]] --
DAMN = DAMN or {}
DAMN.ArmorProtection = DAMN.ArmorProtection or {}

-- Maps each DAMN armor part ID to the list of vanilla vehicle part IDs it protects.
-- The armor part must have an inventory item installed AND condition > 0 to activate.
-- Protected parts whose condition falls below their saved condition (saveCond) are
-- restored to saveCond and the armor part is drained by a random amount.
DAMN.ArmorProtection.map = {
    -- Front collision armor: pedestrian hits and frontal crashes damage EngineDoor,
    -- Windshield, and occasionally headlights (see addDamageFrontHitAChr).
    DAMNBumperFront = {"EngineDoor", "Windshield", "HeadlightLeft", "HeadlightRight"},
    damnBullbarFront = {"EngineDoor", "Windshield", "HeadlightLeft", "HeadlightRight"},
    damnMetalArmor = {"EngineDoor", "Windshield"},

    -- Rear collision armor: rear pedestrian hits damage TrunkDoor and WindshieldRear.
    DAMNBumperRear = {"TrunkDoor", "WindshieldRear", "HeadlightRearLeft", "HeadlightRearRight"},
    damnBullbarRear = {"TrunkDoor", "WindshieldRear", "HeadlightRearLeft", "HeadlightRearRight"},

    -- Windshield armor: explicit glass protection independent of bumper state.
    DAMNWindshieldArmor = {"Windshield"},
    damnWindshieldFrontArmor = {"Windshield"},
    DAMNWindshieldRearArmor = {"WindshieldRear"},

    -- Side window armor: protects individual windows from zombie melee attacks.
    DAMNFrontLeftArmor = {"WindowFrontLeft"},
    DAMNFrontRightArmor = {"WindowFrontRight"},
    DAMNRearLeftArmor = {"WindowRearLeft"},
    DAMNRearRightArmor = {"WindowRearRight"},
    DAMNBackLeftArmor = {"WindowRearLeft"},
    DAMNBackRightArmor = {"WindowRearRight"},

    -- Side body armor: protects door panels from side collisions and zombie hits.
    damnSideArmor = {"DoorFrontLeft", "DoorFrontRight", "DoorRearLeft", "DoorRearRight"},

    -- Vehicle-specific guards: not standard DAMN IDs but used in DAMN-registered vehicles.
    -- 89 Defender Wolf: "Light Guards" — metal headlight protection grilles.
    DEF89Guards = {"HeadlightLeft", "HeadlightRight"}
}

-- Maximum condition drain (random 0..max) from the armor part per protection event.
-- Drain fires at most once per armor part per OnPlayerUpdate tick, regardless of
-- how many protected parts needed healing in that tick.
DAMN.ArmorProtection.drainMax = {
    DAMNBumperFront = 5,
    damnBullbarFront = 5,
    damnMetalArmor = 4,
    DAMNBumperRear = 5,
    damnBullbarRear = 5,
    DAMNWindshieldArmor = 3,
    damnWindshieldFrontArmor = 3,
    DAMNWindshieldRearArmor = 3,
    DAMNFrontLeftArmor = 2,
    DAMNFrontRightArmor = 2,
    DAMNRearLeftArmor = 2,
    DAMNRearRightArmor = 2,
    DAMNBackLeftArmor = 2,
    DAMNBackRightArmor = 2,
    damnSideArmor = 3,
    DEF89Guards = 2
}

-- Applies generic armor protection for all DAMN armor parts present on the vehicle.
-- Called from DAMN.inVehicleUpdateTask for every damnlib-managed vehicle.
-- Throttled to run at most once per second to avoid flooding the part-update buffer.
function DAMN.ArmorProtection.apply(vehicle)
    -- Throttle: run at most once per second to match partUpdateInterval.
    DAMN.ArmorProtection._lastRun = DAMN.ArmorProtection._lastRun or 0
    local now = Calendar.getInstance():getTimeInMillis()
    if now - DAMN.ArmorProtection._lastRun < 1000 then
        return
    end
    DAMN.ArmorProtection._lastRun = now

    for armorPartId, protectedPartIds in pairs(DAMN.ArmorProtection.map) do
        local armor = vehicle:getPartById(armorPartId)
        if armor and armor:getInventoryItem() and armor:getCondition() > 0 then
            local maxDrain = DAMN.ArmorProtection.drainMax[armorPartId] or 2
            -- Only drain this armor part once per tick, even if multiple protected parts needed healing.
            local armorDrained = false

            for _, ppId in ipairs(protectedPartIds) do
                local pp = vehicle:getPartById(ppId)
                if pp then
                    local md = pp:getModData()
                    -- Support both the current key and the legacy key for saveCond.
                    local saveCond = tonumber(md["damn:savedCondition"] or md["saveCond"])
                    if saveCond and pp:getCondition() < saveCond then
                        -- Restore the protected part to the condition it was at when the player entered.
                        DAMN.Armor:setPartCondition(pp, saveCond)

                        if not armorDrained then
                            local drain = ZombRandBetween(0, maxDrain)
                            if drain > 0 then
                                DAMN.Armor:setPartCondition(armor, math.max(0, armor:getCondition() - drain))
                            end
                            armorDrained = true
                        end
                    end
                end
            end
        end
    end
end
