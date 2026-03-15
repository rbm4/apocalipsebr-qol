BAM = BAM or {}

-- Generates a consistent ID string: "CarID-PartIndex-ActionType" or "PartItemIDCarIDActionType"
local function getXPKey(vehicle, part, actionType)
    -- Singleplayer: Key always uses "1" (uninstall) because RecordXPAction only tracks
    -- uninstalls (actionType 2 returns early). This matches the vanilla getMechanicsItem key format.
    if not isClient() then
        return part:getInventoryItem():getID() .. vehicle:getMechanicalID() .. "1"
    end

    -- Multiplayer
    return vehicle:getMechanicalID() .. "-" .. part:getIndex() .. "-" .. actionType
end

-- CHECK: Can the player gain XP?
function BAM.CanGainXP(player, vehicle, part, actionType)
    -- If the part has no item installed, we ignore it
    if not part:getInventoryItem() then
        return false
    end

    --DebugLog.log("Checking if player " .. tostring(player) .. " can gain XP for action type " .. tostring(actionType) .. " on part " .. part:getId() .. " on vehicle " .. vehicle:getMechanicalID())
    local key = getXPKey(vehicle, part, actionType)

    -- In singleplayer we use the build-in XP check
    if not isClient() then
        local canGainXP = player:getMechanicsItem(key) == nil
        return canGainXP
    end

    -- in multiplayer we use our custom cooldown system
    local modData = player:getModData()

    -- Ensure the table exists (important for new players/respawns)
    if not modData.BAM_History then
        modData.BAM_History = {}
    end


    -- If key doesn't exist, they have never worked on it -> YES
    local lastWorkedOn = modData.BAM_History[key]
    if not lastWorkedOn then
        --DebugLog.log("-> No history found for key " .. key .. ". Player can gain XP.")
        return true
    end

    -- Calculate hours passed
    local currentHours = getGameTime():getWorldAgeHours()

    -- Handle edge case: If WorldAge resets (server wipe/admin reset), reset our history
    if currentHours < lastWorkedOn then
        modData.BAM_History[key] = nil
        --DebugLog.log("-> World age reset detected. Clearing history for key " .. key .. ". Player can gain XP.")
        return true
    end

    -- Check if 24 hours have passed
    if (currentHours - lastWorkedOn) >= 24 then
        --DebugLog.log("-> More than 24 hours have passed since last work on key " .. key .. ". Player can gain XP.")
        return true
    end

    --DebugLog.log("-> Less than 24 hours since last work on key " .. key .. ". Player cannot gain XP.")
    return false
end

-- RECORD: Mark this part as "Done" for the next 24 hours
function BAM.RecordXPAction(player, vehicle, part, actionType)
    -- actionType: 1 = Uninstall, 2 = Install
    -- We only track uninstall actions for XP cooldowns, since we always install regardless of XP gain
    -- This is to prevent good parts from laying on the floor
    if actionType == 2 then
        return
    end

    local modData = player:getModData()
    local dataChanged = false  -- Track if we actually change anything

    if not modData.BAM_History then
        modData.BAM_History = {}
        dataChanged = true
    end

    -- Loop over all mod data entries and remove any that are older than 24 hours
    local currentHours = getGameTime():getWorldAgeHours()
    for key, lastWorkedOn in pairs(modData.BAM_History) do
        if currentHours - lastWorkedOn >= 24 then
            modData.BAM_History[key] = nil
            dataChanged = true
            --DebugLog.log("-> Removed old history entry for key " .. key)
        end
    end

    -- Save the exact hour we finished, but only if no mod data entry for this part exists
    local key = getXPKey(vehicle, part, actionType)
    local lastWorkedOn = modData.BAM_History[key]
    if not lastWorkedOn then
        --DebugLog.log("Recorded XP action type " .. tostring(actionType) .. " for part " .. part:getId() .. " for player " .. tostring(player) .. " on vehicle " .. vehicle:getMechanicalID())
        modData.BAM_History[key] = getGameTime():getWorldAgeHours()
        dataChanged = true
    end

    -- Force the game to sync this change to the server immediately, but only sync if we actually touched the table
    if dataChanged then
        player:transmitModData()
    end
end


function BAM.PrintDebugHistory()
    local player = getPlayer()
    local history = player:getModData().BAM_History
    if history then
        DebugLog.log("=== BAM XP HISTORY ===")
        for key, time in pairs(history) do
            DebugLog.log(key .. " : " .. time)
        end
    else
        DebugLog.log("=== NO HISTORY FOUND ===")
    end
end

