AutoMechanics = AutoMechanics or {}

AutoMechanics.DelayTimer = AutoMechanics.DelayTimer or 0
--AutoMechanics "until success" management
AutoMechanics.untilSuccess = {}
AutoMechanics.untilSuccess.timeSpeed = 1
AutoMechanics.untilSuccess.part = nil
AutoMechanics.untilSuccess.player = nil
AutoMechanics.untilSuccess.item = nil

--AutoMechanics job management
AutoMechanics.uninstallOnly = false;
AutoMechanics.onAutoMechanicsTrain_started = false;
AutoMechanics.jobOrganisation = nil
function AutoMechanics.StopMechanicsTrain()
    local freeze = AutoMechanics.getEndPause()
    if AutoMechanics.onAutoMechanicsTrain_started == false then
        print ("ERROR AutoMechanics.StopMechanicsTrain called while not started.");
    end
    AutoMechanics.uninstallOnly = false;
    AutoMechanics.onAutoMechanicsTrain_started = false;
    AutoMechanics.jobOrganisation = nil
    if freeze == true then setGameSpeed(0);getGameTime():setMultiplier(1);--freeze game
    else setGameSpeed(1);getGameTime():setMultiplier(1); end--speed 1 game
    if AutoMechanics.getVerbose() then print ("AutoMechanics.StopMechanicsTrain"); end
end

local function sortMechanicJobListByPosition(jobList, vehicle)
    local orderedJobList = {};
    local iterOrdered = 0
    local iterRaw = 0
    local iterRawDone = false
    local areaOrder = {"Engine", "TireFrontLeft", "SeatFrontLeft", "SeatMiddleLeft", "SeatRearLeft", "TireRearLeft", "TruckBed", "GasTank", "TireRearRight","SeatRearRight","SeatMiddleRight","SeatFrontRight","TireFrontRight"}
    for luaItArea, area in ipairs(areaOrder) do
        for luaItMb,partItMb in ipairs(jobList) do
            local part = vehicle:getPartByIndex(partItMb)
            if part:getArea() == area then
                table.insert(orderedJobList,partItMb)
                iterOrdered = iterOrdered + 1
                if AutoMechanics.getVerbose() then print ("sortMechanicJobListByPosition : "..iterOrdered.." "..tostring(part:getItemType() or "nil").." id="..part:getId().." area="..part:getArea()) end
            end
            if not iterRawDone then iterRaw = iterRaw + 1 end
        end
        iterRawDone = true
    end
    if iterRaw ~= iterOrdered then --error
        print ("ERROR sortMechanicJobListByPosition sort "..iterOrdered.." items instead of "..iterRaw);
        if iterRaw > iterOrdered then
            
            for luaItMb,partItMb in ipairs(jobList) do
                local partIsSort = false
                for luaItSort,partItSort in ipairs(jobList) do
                    if partItMb == partItSort then
                        partIsSort = true
                        break
                    end
                end
                if not partIsSort then
                    table.insert(orderedJobList,partItMb)
                    local part = vehicle:getPartByIndex(partItMb)
                    print ("sortMechanicJobListByPosition : unexpected Area for"..tostring(part:getItemType() or "nil").." "..part:getArea())
                end
            end
        end
    end

    return orderedJobList
end

function startAutoMechanicsTraining(player,vehicle)
    local jobListAvailable = {}
    local jobListMaybe = {}
    local iterJobAvailable = 0
    local iterJobMaybe = 0
    for i=0,vehicle:getPartCount()-1 do
        local part = vehicle:getPartByIndex(i)
        local jobAvailability = AutoMechanics.getPartValidForTrainingState(player, part)
        if jobAvailability == 2 then
            iterJobAvailable = iterJobAvailable + 1--remember iterJobs is lua index
            jobListAvailable[iterJobAvailable] = i--remember i is java index
            if AutoMechanics.getVerbose() then print ("startAutoMechanicsTraining Job available "..iterJobAvailable.." on partId "..i.." "..tostring(part)); end
        elseif jobAvailability == 1 then
            iterJobMaybe = iterJobMaybe + 1--remember iterJobs is lua index
            jobListMaybe[iterJobMaybe] = i--remember i is java index
            if AutoMechanics.getVerbose() then print ("startAutoMechanicsTraining Job maybe "..iterJobMaybe.." on partId "..i.." "..tostring(part)); end
        else
            if AutoMechanics.getVerbose() then print ("startAutoMechanicsTraining Job impossible on partId "..i.." "..tostring(part)); end
        end
    end
    
    jobListAvailable = sortMechanicJobListByPosition(jobListAvailable,vehicle)
    
    AutoMechanics.jobOrganisation = {}
    AutoMechanics.jobOrganisation.jobListAvailable = jobListAvailable--ok for main job list
    AutoMechanics.jobOrganisation.jobListMaybe = jobListMaybe--look for job dependency ? or maybe just reparse that table after each uninstall.
    AutoMechanics.jobOrganisation.jobListDone = {}--I prefer [keeping track of jobs done and wasting time parsing] to [managing lua table removing]
    AutoMechanics.jobOrganisation.jobListUninstalled = {}--I prefer [keeping track of jobs done and wasting time parsing] to [managing lua table removing]
    AutoMechanics.jobOrganisation.player = player
    AutoMechanics.jobOrganisation.vehicle = vehicle
    AutoMechanics.jobOrganisation.pendingJob = nil
    AutoMechanics.jobOrganisation.pendingPart = nil
    AutoMechanics.jobOrganisation.pendingTimeSpeed = 1;
    AutoMechanics.jobOrganisation.jobPriorityUninstall = nil
    AutoMechanics.jobOrganisation.jobPriorityInstall = nil
    AutoMechanics.jobOrganisation.currentArea = nil
    
    AutoMechanics.onAutoMechanicsTrain_started = true;
end
function AutoMechanics.isAutoMechanicsTrain_started()
    return AutoMechanics.onAutoMechanicsTrain_started
end
function AutoMechanics.getVehicle()
    return AutoMechanics.jobOrganisation.vehicle
end

function AutoMechanics.setPartUninstalled(uninstalledpart,vehicle)
    local partFound = false;
    for i=0,vehicle:getPartCount()-1 do
        local part = vehicle:getPartByIndex(i)
        if part == uninstalledpart then
            partFound = true;
            local wasJob = false
            if AutoMechanics.jobOrganisation.jobPriorityUninstall ~= nil and AutoMechanics.jobOrganisation.jobPriorityUninstall == i then
                AutoMechanics.jobOrganisation.jobPriorityUninstall = nil;
                AutoMechanics.jobOrganisation.jobPriorityInstall = i;
                wasJob = true;
            else
                for luaIt,partIt in ipairs(AutoMechanics.jobOrganisation.jobListAvailable) do
                    if partIt == i then
                        wasJob = true;
                        if AutoMechanics.getVerbose() then print("AutoMechanics.setPartUninstalled job "..luaIt.." done, part "..i.." uninstalled."); end
                        table.insert(AutoMechanics.jobOrganisation.jobListUninstalled,i);
                        break;
                    end
                end
            end
            if not wasJob then--handle the error
                print ("ERROR AutoMechanics.setPartUninstalled job not found for part "..i);
            end
            break;
        end
    end
    if not partFound then--handle the error
        print ("ERROR AutoMechanics.setPartUninstalled part not found for "..tostring(uninstalledpart or "nil"));
    end
end

function AutoMechanics.setPartInstalled(installedpart,vehicle)
    local partFound = false;
    for i=0,vehicle:getPartCount()-1 do
        local part = vehicle:getPartByIndex(i)
        if part == installedpart then
            partFound = true;
            local wasJob = false
            if AutoMechanics.jobOrganisation.jobPriorityInstall ~= nil and AutoMechanics.jobOrganisation.jobPriorityInstall == i then
                AutoMechanics.jobOrganisation.jobPriorityInstall = nil;
                wasJob = true;
            else
                for luaIt,partIt in ipairs(AutoMechanics.jobOrganisation.jobListUninstalled) do
                    if partIt == i then
                        wasJob = true;
                        if AutoMechanics.getVerbose() then print("AutoMechanics.setPartInstalled job "..luaIt.." done, part "..i.." installed."); end
                        table.insert(AutoMechanics.jobOrganisation.jobListDone,i);
                        break;
                    end
                end
            end
            if not wasJob then--handle the error
                print ("ERROR AutoMechanics.setPartInstalled job not found for part "..i);
            end
            break;
        end
    end
    if not partFound then--handle the error
        print ("ERROR AutoMechanics.setPartInstalled part not found for "..tostring(installedpart or "nil"));
    end
end

--AutoMechanics training
function ISVehicleMechanics:onAutoMechanicsTrain(player,vehicle)
    if AutoMechanics.getVerbose() then print("ISVehicleMechanics:onAutoMechanicsTrain "..tostring(vehicle)); end

    AutoMechanics.uninstallOnly = false;--whatever the previous state we are currently training
    startAutoMechanicsTraining(player,vehicle)--organise the job
    AutoMechanics.doPendingJob(player,vehicle);--go to work Kaylee Frye !
end

--AutoMechanics uninstall all
function ISVehicleMechanics:onAutoMechanicsUninstallAll(player,vehicle)
    if AutoMechanics.getVerbose() then print("ISVehicleMechanics:onAutoMechanicsUninstallAll "..tostring(vehicle)); end

    AutoMechanics.uninstallOnly = true;--whatever the previous state we are currently training
    startAutoMechanicsTraining(player,vehicle)--organise the job
    AutoMechanics.doPendingJob(player,vehicle);--go to work Kaylee Frye !
end


function AutoMechanics.doPendingJob(player,vehicle)
    local jobOrganisation = AutoMechanics.jobOrganisation;
    if not jobOrganisation then
        print ("ERROR AutoMechanics.doPendingJob with job organisation.");
        return
    end
    
    if not player then player = AutoMechanics.jobOrganisation.player end
    if not vehicle then vehicle = AutoMechanics.jobOrganisation.vehicle end
    
    --uninstall first job available
    local invalidPartId = vehicle:getPartCount();
    local partIdToDo = invalidPartId;
    local doInstall = false;
    
    if AutoMechanics.jobOrganisation.jobPriorityUninstall ~= nil then
        partIdToDo = AutoMechanics.jobOrganisation.jobPriorityUninstall;
        if AutoMechanics.getVerbose() then print ("AutoMechanics.doPendingJob Uninstall Priority part "..partIdToDo);end
    elseif AutoMechanics.jobOrganisation.jobPriorityInstall ~= nil then
        partIdToDo = AutoMechanics.jobOrganisation.jobPriorityInstall;
        if AutoMechanics.getVerbose() then print ("AutoMechanics.doPendingJob Install Priority part "..partIdToDo);end
        doInstall = true;
    else
        for luaIt,partIt in ipairs(jobOrganisation.jobListAvailable) do
            local alreadyDone = false
            for luaItDone,partItDone in ipairs(jobOrganisation.jobListDone) do
                if partIt == partItDone then
                    alreadyDone = true;
                    break
                end
            end
            --decide if we need to install, uninstall or do a dependency search on jobListMaybe
            if alreadyDone == false then
                local alreadyUninstalled = false
                for luaItUn,partItUn in ipairs(jobOrganisation.jobListUninstalled) do
                    if partIt == partItUn then
                        alreadyUninstalled = true;
                        break
                    end
                end
                if alreadyUninstalled then--that's the time to do a dependency search
                    local maybeJobAvailable = false
                    for luaItMb,partItMb in ipairs(jobOrganisation.jobListMaybe) do
                        local part = vehicle:getPartByIndex(partItMb)
                        local jobAvailability = AutoMechanics.getPartValidForTrainingState(player, part)
                        if jobAvailability == 2 then
                            jobOrganisation.jobListMaybe[luaItMb] = invalidPartId;
                            jobOrganisation.jobPriorityUninstall = partItMb;
                            maybeJobAvailable = true
                            partIt = partItMb--start doing it now in priority
                            if AutoMechanics.getVerbose() then print ("AutoMechanics.doPendingJob Activate and Uninstall maybe part "..partIt.." "..tostring(part and part:getId() or nil));end
                            break
                        end
                    end
                    if not maybeJobAvailable then
                        if AutoMechanics.getVerbose() then
                            local part = vehicle:getPartByIndex(partIt)
                            print ("AutoMechanics.doPendingJob Install part "..partIt.." "..tostring(part and part:getId() or nil));
                        end
                        doInstall = true;--for now we just do install
                    end
                else
                    if AutoMechanics.getVerbose() then
                        local part = vehicle:getPartByIndex(partIt)
                        print ("AutoMechanics.doPendingJob Uninstall part "..partIt.." "..tostring(part and part:getId() or nil));
                    end
                end
                
                partIdToDo = partIt;
                break;
            end
        end
    end
    
    if partIdToDo == invalidPartId then --job is done
        if AutoMechanics.getVerbose() then print ("AutoMechanics.doPendingJob job's done"); end
        AutoMechanics.StopMechanicsTrain()
        return
    end
    
    local part = vehicle:getPartByIndex(partIdToDo);
    if not part then --Bug
        print ("ERROR AutoMechanics.doPendingJob job's bugged invalid part id "..partIdToDo);
        AutoMechanics.StopMechanicsTrain()
        return
    end
    
    if doInstall then
        local item = getAnyItemOnPlayerThatMatchesThatPart(player, part);
        local isInstallStillPossible = part:getVehicle():canInstallPart(player, part);--it was possible at start but it can have changed. e.g. for a wheel if we broke suspension
        if not AutoMechanics.uninstallOnly and item and isInstallStillPossible then
            
            --avoid useless movements when area has not changed
            local targetArea = part:getArea();
            local sameArea = targetArea == AutoMechanics.jobOrganisation.currentArea;--compare previous and target
            AutoMechanics.jobOrganisation.currentArea = targetArea;--save area for next action
            local vanilla_ISPathFindAction_pathToVehicleArea = ISPathFindAction.pathToVehicleArea--store for unhook
            if sameArea then ISPathFindAction.pathToVehicleArea = ISPathFindAction.pathToVehicleArea_inactive end --hook to inhibit
            
            if AutoMechanics.getVerbose() then print ("AutoMechanics.doPendingJob Install part it "..partIdToDo.." "..tostring(part and part:getId() or nil).." on area "..tostring(targetArea)..tostring(sameArea and " unchanged" or " changed") );end
            
            ISVehiclePartMenu.onInstallPart(player, part, item);--asynchronous job start vanilla way
            
            if sameArea then ISPathFindAction.pathToVehicleArea = vanilla_ISPathFindAction_pathToVehicleArea end --unhook
            
        else
            if AutoMechanics.getVerbose() and not isInstallStillPossible then print ("AutoMechanics.doPendingJob job Install not possible, missing access to the part for it "..partIdToDo.." "..tostring(part and part:getId() or nil)); end
            if AutoMechanics.getVerbose() and isInstallStillPossible and not AutoMechanics.uninstallOnly then print ("AutoMechanics.doPendingJob job Install not possible, missing valid item for part it "..partIdToDo.." "..tostring(part and part:getId() or nil)); end
            if AutoMechanics.getVerbose() and AutoMechanics.uninstallOnly then print ("AutoMechanics.doPendingJob job not reinstalling as requested by Deadly_Shadow "..partIdToDo.." "..tostring(part and part:getId() or nil)); end
            
            --Test auto drop
            if not isInstallStillPossible then
                AutoMechanics.dropItem(player, item);
            end
            
            AutoMechanics.setPartInstalled(part,vehicle);--only uninstall or we probably just removed a broken item set jobs done for this part
            
            AutoMechanics.doPendingJob(player,vehicle)--go to next part
        end
    else
        if AutoMechanics.getVerbose() then print ("AutoMechanics.doPendingJob Uninstall part it "..partIdToDo.." "..tostring(part and part:getId() or nil));end
        
        --avoid useless movements when area has not changed
        local targetArea = part:getArea();
        local sameArea = targetArea == AutoMechanics.jobOrganisation.currentArea;--compare previous and target
        AutoMechanics.jobOrganisation.currentArea = targetArea;--save area for next action
        local vanilla_ISPathFindAction_pathToVehicleArea = ISPathFindAction.pathToVehicleArea--store for unhook
        if sameArea then ISPathFindAction.pathToVehicleArea = ISPathFindAction.pathToVehicleArea_inactive end --hook to inhibit
        
        ISVehiclePartMenu.onUninstallPart(player, part);--asynchronous job start vanilla way
        
        if sameArea then ISPathFindAction.pathToVehicleArea = vanilla_ISPathFindAction_pathToVehicleArea end --unhook
    end
    
    if AutoMechanics.OPTIONS.VerboseTimeSpeed then print ("AutoMechanics.doPendingJob timespeed = "..getGameTime():getTrueMultiplier()) end
end

--this allows to continue until success (with a delay)
AutoMechanics.OnTickUntilSuccess = function ()
    if AutoMechanics.DelayTimer <= 0 then
        if AutoMechanics.getVerbose() then print ("AutoMechanics.OnTickUntilSuccess, starting delayed job "..getTableString(AutoMechanics.untilSuccess)); end
        Events.OnTick.Remove(AutoMechanics.OnTickUntilSuccess);
        if AutoMechanics.untilSuccess.isInstall then
            local item = AutoMechanics.untilSuccess.item
            if item and not item:isBroken() then
                --ISVehiclePartMenu.onInstallPart(AutoMechanics.untilSuccess.player, AutoMechanics.untilSuccess.part, item)
                local playerObj = AutoMechanics.untilSuccess.player
                local part = AutoMechanics.untilSuccess.part
                local keyvalues = part:getTable('install')
                if not keyvalues or not keyvalues.time then
                    keyvalues = part:getTable('uninstall')--some mods break install table but not uninstall one
                end
                local time = tonumber(keyvalues.time) or 50
                ISTimedActionQueue.add(ISInstallVehiclePart:new(playerObj, part, item, time))
            else
                stop = true
            end
        else
            --ISVehiclePartMenu.onUninstallPart(AutoMechanics.untilSuccess.player, AutoMechanics.untilSuccess.part)
            local playerObj = AutoMechanics.untilSuccess.player
            local part = AutoMechanics.untilSuccess.part
            local keyvalues = part:getTable('uninstall')
            local time = tonumber(keyvalues.time) or 50
            ISTimedActionQueue.add(ISUninstallVehiclePart:new(playerObj, part, time))
        end
    end
    AutoMechanics.DelayTimer = AutoMechanics.DelayTimer - 1
    
    if stop then
        AutoMechanics.untilSuccess.timeSpeed = 1
        setGameSpeed(1);getGameTime():setMultiplier(1);
    else
        if AutoMechanics.untilSuccess.timeSpeed and AutoMechanics.untilSuccess.timeSpeed > getGameTime():getTrueMultiplier() then
            --re-activate the game speed we had before vanilla deactivated it
            setGameSpeed(AutoMechanics.gameSpeedMultiplierToGameSpeed(AutoMechanics.untilSuccess.timeSpeed));
            getGameTime():setMultiplier(AutoMechanics.untilSuccess.timeSpeed);
        end
    end
end

--this allows to continue the training / uninstalling job (with a delay)
AutoMechanics.OnTick = function ()
    if AutoMechanics.DelayTimer <= 0 then
        if AutoMechanics.getVerbose() then print ("AutoMechanics.OnTick, starting delayed job"); end
        Events.OnTick.Remove(AutoMechanics.OnTick);
        --if new broken item, drop it
        if AutoMechanics.jobOrganisation then
            AutoMechanics.dropBrokenItems(AutoMechanics.jobOrganisation.player)
        end
        AutoMechanics.doPendingJob(nil,nil)--try again or do next job
    end
    AutoMechanics.DelayTimer = AutoMechanics.DelayTimer - 1
end

local keyEscape = Keyboard.KEY_ESCAPE
function AutoMechanics.OnKeyStartPressed(key)
    if key == keyEscape and AutoMechanics.onAutoMechanicsTrain_started then
        AutoMechanics.StopMechanicsTrain()
    end
end

