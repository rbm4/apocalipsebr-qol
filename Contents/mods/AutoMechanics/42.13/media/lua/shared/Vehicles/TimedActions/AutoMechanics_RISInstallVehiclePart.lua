AutoMechanics = AutoMechanics or {}

local vanilla_ISInstallVehiclePart_stop = ISInstallVehiclePart.stop
function ISInstallVehiclePart:stop()
    vanilla_ISInstallVehiclePart_stop(self)
    
    if AutoMechanics.onAutoMechanicsTrain_started then
        --B42.13 Broken: stop is called instead of perform on valid complete cases (with mechanicActionDone sent)
        --AutoMechanics.StopMechanicsTrain()
        --if AutoMechanics.getVerbose() then print ("AutoMechanics stop from ISInstallVehiclePart:stop"); end
    end
end

local vanilla_ISInstallVehiclePart_start = ISInstallVehiclePart.start
function ISInstallVehiclePart:start()
    if AutoMechanics.getVerbose() then print ("AutoMechanics ISInstallVehiclePart:start "..tostring(self.character).." "..tostring(self.part).." "..tostring(AutoMechanics.jobOrganisation and AutoMechanics.jobOrganisation.pendingPart));end
    vanilla_ISInstallVehiclePart_start(self)
    
    if AutoMechanics.jobOrganisation then
        if AutoMechanics.onAutoMechanicsTrain_started then
            if AutoMechanics.getVerbose() then print ("AutoMechanics continue from ISInstallVehiclePart:perform"); end
            AutoMechanics.jobOrganisation.pendingJob = "Install";
            AutoMechanics.jobOrganisation.pendingPart = self.part
            AutoMechanics.jobOrganisation.pendingTimeSpeed = getGameTime():getTrueMultiplier();
            if AutoMechanics.OPTIONS.VerboseTimeSpeed then print ("AutoMechanics.ISInstallVehiclePart timespeed = "..getGameTime():getTrueMultiplier()) end
        elseif AutoMechanics.doUntilSuccess() then
            AutoMechanics.untilSuccess.timeSpeed = getGameTime():getTrueMultiplier();
            AutoMechanics.untilSuccess.part = self.part
            AutoMechanics.untilSuccess.player = self.character
            AutoMechanics.untilSuccess.item = self.item
        end
    end
end

local vanilla_ISInstallVehiclePart_perform = ISInstallVehiclePart.perform
function ISInstallVehiclePart:perform()
    if AutoMechanics.getVerbose() then print ("AutoMechanics ISInstallVehiclePart:perform "..tostring(self.character).." "..tostring(self.part).." "..tostring(AutoMechanics.jobOrganisation and AutoMechanics.jobOrganisation.pendingPart));end
    vanilla_ISInstallVehiclePart_perform(self)
end

local vanilla_ISInstallVehiclePart_complete = ISInstallVehiclePart.complete
function ISInstallVehiclePart:complete()
    if AutoMechanics.getVerbose() then print ("AutoMechanics ISInstallVehiclePart:complete");end
    -- hook the result vanilla function from local random
    -- Albion: needs to be the actual class of the object, not the class that declares the method like you may expect
    local mt = __classmetatables[IsoPlayer.class].__index
    local old_sendObjectChange = mt.sendObjectChange
    
    local mechanicActionDoneCalled = false
    local success = false
    mt.sendObjectChange = function(player, str, luaTab, ...)
        local mechanicActionDoneCalledNow = str == 'mechanicActionDone'
        mechanicActionDoneCalled = mechanicActionDoneCalled or mechanicActionDoneCalledNow
        local successNow = mechanicActionDoneCalledNow and luaTab and luaTab.success
        success = success or successNow
        if AutoMechanics.getVerbose() then print ("AutoMechanics sendObjectChange "..tostring(mechanicActionDoneCalledNow).." "..tostring(successNow));end
        old_sendObjectChange(player, str, luaTab, ...)
    end
    
    local completed = vanilla_ISInstallVehiclePart_complete(self)
    
    mt.sendObjectChange = old_sendObjectChange--release hook
    
    if not mechanicActionDoneCalled then
        --client will not get any answer (no OnMechanicActionDone) from vanilla when there is no success (aka uninstalled) and no failure (aka degrading part)
        sendServerCommand(self.character, AutoMechanics.ModKey, AutoMechanics.MechanicActionSilentFailKey, {})
    elseif AutoMechanics.jobOrganisation and not isServer() and not isClient() then --in solo OnMechanicActionDone is never sent / received
        local player = self.character
        local vehicleId = nil--unused
        local partName = nil--unused
        local item = self.part and self.part:getInventoryItem()
        local itemId = item and item:getID()
        local installing = true
        local param7 = nil
        if AutoMechanics.getVerbose() then print ("AutoMechanics ISInstallVehiclePart:completed "..tostring(success).." "..tostring(itemId).." "..tostring(player).." "..tostring(self.part and self.part:getItemType()).." "..tostring(self.part).." "..tostring(AutoMechanics.jobOrganisation and AutoMechanics.jobOrganisation.pendingPart));end
        if player and self.part == AutoMechanics.jobOrganisation.pendingPart then--and itemId ~= nil and itemId ~= -1 
            AutoMechanics.OnMechanicActionDone(player,success,vehicleId,partName,itemId,installing,param7)
        end
    end
    
    return completed
end

