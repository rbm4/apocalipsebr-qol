BAM = BAM or {}
BAM.IsCurrentlyTraining = false
BAM.Vehicle = nil
BAM.WorkDelayTimer = 0
BAM.GameSpeedCheckTimer = 0
BAM.LastWorkedPart = nil
BAM.LastWorkedActionType = nil -- 1 = uninstall, 2 = install
BAM.InaccessibleParts = {}
BAM.WorkedParts = {}
BAM.PrevGameSpeed = 1
BAM.PrevTimeMultiplier = 1


function BAM:StartMechanicsTraining(player, vehicle)
    -- Re-entrancy guard: ignore if already training on the same vehicle with the same player
    if BAM.IsCurrentlyTraining then
        ISTimedActionQueue.clear(player)
        BAM.StopMechanicsTraining(nil)
    end

    DebugLog.log("=================================")
    DebugLog.log("Starting mechanics training!")
    BAM.IsCurrentlyTraining = true
    BAM.Vehicle = vehicle
    BAM.InaccessibleParts = {}
    BAM.workOnNextPart(player, vehicle)
end


function BAM.StopMechanicsTraining(player, msgOverride, r, g, b)
    BAM.IsCurrentlyTraining = false
    BAM.Vehicle = nil
    BAM.WorkDelayTimer = 0
    BAM.LastWorkedPart = nil
    BAM.LastWorkedActionType = nil
    BAM.InaccessibleParts = {}
    BAM.WorkedParts = {}
    BAM.PrevGameSpeed = 1
    BAM.PrevTimeMultiplier = 1
    if not isClient() then
        setGameSpeed(1)
        getGameTime():setMultiplier(1)
    end

    local msg = msgOverride or getText("UI_BAM_message.car_completed")
    r = r or 0
    g = g or 255
    b = b or 0

    -- Display an in-game notification to inform the player that training has finished
    if player then
        HaloTextHelper.addText(player, msg, "[br/]", r, g, b)
    end

    getPlayer():setSneaking(false)

    DebugLog.log("Finished mechanics training!")

    --for i, partInfo in ipairs(BAM.WorkedParts) do
    --    DebugLog.log(i .. ". " .. partInfo)
    --end

    DebugLog.log("=================================")
end


function BAM.workOnNextPart(player, vehicle)
    -- Safety check: ensure player and vehicle are valid
    if not player or not vehicle then
        BAM.StopMechanicsTraining(nil)
        return
    end

    -- First check if we are too far away from the vehicle
    local distanceToCar = player:DistToSquared(vehicle)
    --DebugLog.log("Player distance to vehicle squared: " .. distanceToCar)
    if distanceToCar > 10 and BAM.LastWorkedPart then
        DebugLog.log("Player is too far from vehicle (" .. tostring(distanceToCar) .. " tiles). Stopping training.")
        BAM.StopMechanicsTraining(nil)
        return
    end

    -- Gather info about next parts to install/uninstall
    DebugLog.log("Deciding on next part...")
    local partUninstall = BAM.GetNextUninstallablePart(player, vehicle)
    local partInstall, itemInstall = BAM.GetNextInstallablePartAndItem(player, vehicle)
    --DebugLog.log("Next part to uninstall: " .. (partUninstall and partUninstall:getId() or "None"))
    --DebugLog.log("Next part to install: " .. (partInstall and partInstall:getId() or "None"))

    -- If no parts to install or uninstall, stop training
    if partUninstall == nil and partInstall == nil then
        DebugLog.log("No more parts to work on.")
        BAM.StopMechanicsTraining(player)
        return
    end

    -- Before we install any part, check if it requires other parts to be installed first.
    -- If yes, uninstall those parts first.
    if partInstall then
        local keyvalues = partInstall:getTable("install")
        if keyvalues and keyvalues.requireInstalled then
            local split = keyvalues.requireInstalled:split(";")
            for i, partId in ipairs(split) do
                local requiredPart = vehicle:getPartById(partId)
                if requiredPart and BAM.PartCanBeUninstalled(player, vehicle, requiredPart) then
                    DebugLog.log("Uninstalling " .. partInstall:getId() .. " made part " .. partId .. " available for uninstall.")
                    BAM.UninstallPart(player, requiredPart)
                    return
                end
            end
        end
    end

    -- If we can install any part, do it. We always prioritize installation over uninstallation (except for brakes/suspension above)
    if partInstall and itemInstall then
        BAM.InstallPart(player, partInstall, itemInstall)
        return
    end

    -- Otherwise, uninstall the next part
    if partUninstall then
        BAM.UninstallPart(player, partUninstall)
        return
    end

    -- If we reach here, something went wrong. Probably because we have a part to install but no item for it.
    DebugLog.log("Error: Unable to determine next part to work on.")
    BAM.StopMechanicsTraining(player)
end


function BAM.InstallPart(player, part, item)
    local successChance = BAM.GetPartSuccessChance(player, part, "install")
    DebugLog.log("-> Installing part: " .. part:getId() .. " - Success chance: " .. successChance .. "%")
    BAM.LastWorkedPart = part
    BAM.LastWorkedActionType = 2
    table.insert(BAM.WorkedParts, part:getId() .. " - Install")
    BAM.DropBrokenItems(player)  -- Drop broken items before installing
    ISVehiclePartMenu.onInstallPart(player, part, item)  -- Start timed task
end


function BAM.UninstallPart(player, part)
    local successChance = BAM.GetPartSuccessChance(player, part, "uninstall")
    DebugLog.log("-> Uninstalling part: " .. part:getId() .. " - Success chance: " .. successChance .. "%")
    BAM.LastWorkedPart = part
    BAM.LastWorkedActionType = 1
    table.insert(BAM.WorkedParts, part:getId() .. " - Uninstall")
    BAM.DropBrokenItems(player)  -- Drop broken items before uninstalling
    ISVehiclePartMenu.onUninstallPart(player, part)  -- Start timed task
end


--- Batch-uninstall all parts in a given category.
-- Stops any active training first, then queues vanilla uninstall actions for each matching part.
-- @param playerOrSelf  When called from the mechanics UI context menu, this is the ISVehicleMechanics 'self'.
-- @param player IsoPlayer
-- @param vehicle BaseVehicle
-- @param categoryIds table|nil  Set of part ID strings, or nil for "Everything"
function BAM.UninstallCategory(playerOrSelf, player, vehicle, categoryIds)
    -- Stop any active training session first
    if BAM.IsCurrentlyTraining then
        ISTimedActionQueue.clear(player)
        BAM.StopMechanicsTraining(nil)
    end

    local parts = BAM.GetUninstallablePartsByCategory(player, vehicle, categoryIds)
    if #parts == 0 then return end

    -- Sort parts using the same order as training for consistency
    parts = BAM.SortParts(parts)

    DebugLog.log("BAM: Batch uninstalling " .. #parts .. " parts...")
    for _, part in ipairs(parts) do
        DebugLog.log("  -> Queuing uninstall: " .. part:getId())
        ISVehiclePartMenu.onUninstallPart(player, part)
    end
end


