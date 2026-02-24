AutoMechanics = AutoMechanics or {}

function AutoMechanics.OnMechanicActionDone(player,success,vehicleId,partName,itemId,installing,param7)
    if AutoMechanics.getVerbose() then print ("AutoMechanics.OnMechanicActionDone "..tostring(player)..' '..tostring(success)..' '..tostring(vehicleId)..' '..tostring(partName)..' '..tostring(itemId)..' '..tostring(installing)..' '..tostring(param7)); end
    if AutoMechanics.onAutoMechanicsTrain_started and AutoMechanics.jobOrganisation.player == player then
        local vehicle = AutoMechanics.jobOrganisation.vehicle
        if AutoMechanics.jobOrganisation.pendingJob and AutoMechanics.jobOrganisation.pendingPart then
            local part = AutoMechanics.jobOrganisation.pendingPart
            if AutoMechanics.jobOrganisation.pendingJob == "Install" then
                AutoMechanics.jobOrganisation.pendingJob = nil;
                if success and itemId ~= -1 then
                    AutoMechanics.setPartInstalled(part,vehicle);
                end
            elseif AutoMechanics.jobOrganisation.pendingJob == "Uninstall" then
                AutoMechanics.jobOrganisation.pendingJob = nil;
                if success and itemId ~= -1 then
                    AutoMechanics.setPartUninstalled(part,vehicle);
                    
                    local invItem = AutoMechanics.getInventoryItem(player, itemId)
                    if invItem and (AutoMechanics.uninstallOnly or invItem:isBroken()) then --drop the item when uninstalling or when item is broken
                        AutoMechanics.dropItem(player, invItem)
                    end
                end
            else
                print ("ERROR AutoMechanics.OnMechanicActionDone called with invalid pendingJob "..AutoMechanics.jobOrganisation.pendingJob);
                AutoMechanics.StopMechanicsTrain();
                return
            end
        else
            print ("ERROR AutoMechanics.OnMechanicActionDone called while no pendingJob.");
            AutoMechanics.StopMechanicsTrain();
            return
        end
        if AutoMechanics.OPTIONS.VerboseTimeSpeed then print ("AutoMechanics.OnMechanicActionDone timespeed = "..getGameTime():getTrueMultiplier()) end
        if AutoMechanics.jobOrganisation.pendingTimeSpeed > getGameTime():getTrueMultiplier() then
            --re-activate the game speed we had before vanilla deactivated it
            setGameSpeed(AutoMechanics.gameSpeedMultiplierToGameSpeed(AutoMechanics.jobOrganisation.pendingTimeSpeed));
            getGameTime():setMultiplier(AutoMechanics.jobOrganisation.pendingTimeSpeed);
        end

        AutoMechanics.DelayTimer = AutoMechanics.getWaitCycle()
        Events.OnTick.Add(AutoMechanics.OnTick);-- Timed callback
        
    elseif AutoMechanics.doUntilSuccess() and not success and not AutoMechanics.onAutoMechanicsTrain_started then
        local part = AutoMechanics.untilSuccess.part
        if AutoMechanics.getVerbose() then print ("AutoMechanics.OnMechanicActionDone, starting repeat "..tostring(installing and "install" or "unsinstall").." for part="..tostring(part or "nil").." timespeed="..tostring(AutoMechanics.untilSuccess.timeSpeed or "nil")); end
        if part and player == AutoMechanics.untilSuccess.player then
            AutoMechanics.DelayTimer = AutoMechanics.getWaitCycle()
            AutoMechanics.untilSuccess.isInstall = installing
            if itemId then AutoMechanics.untilSuccess.item = AutoMechanics.getInventoryItem(player, itemId) end--the item can change on server side
            Events.OnTick.Add(AutoMechanics.OnTickUntilSuccess);-- Timed callback
            
            if AutoMechanics.untilSuccess.timeSpeed and AutoMechanics.untilSuccess.timeSpeed > getGameTime():getTrueMultiplier() then
                --re-activate the game speed we had before vanilla deactivated it
                setGameSpeed(AutoMechanics.gameSpeedMultiplierToGameSpeed(AutoMechanics.untilSuccess.timeSpeed));
                getGameTime():setMultiplier(AutoMechanics.untilSuccess.timeSpeed);
            end
        end
    end
end


