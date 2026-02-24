AutoMechanics = AutoMechanics or {}

local vanilla_ISInstallVehiclePart_stop = ISInstallVehiclePart.stop
function ISInstallVehiclePart:stop()
    vanilla_ISInstallVehiclePart_stop(self)
    
    if AutoMechanics.onAutoMechanicsTrain_started then
        AutoMechanics.StopMechanicsTrain()
        if AutoMechanics.getVerbose() then print ("AutoMechanics stop from ISInstallVehiclePart:stop"); end
    end
end

local vanilla_ISInstallVehiclePart_complete = ISInstallVehiclePart.complete
function ISInstallVehiclePart:complete()
    if AutoMechanics.getVerbose() then print ("AutoMechanics ISInstallVehiclePart:complete");end
    -- hook the result vanilla function from local random
    -- Albion: needs to be the actual class of the object, not the class that declares the method like you may expect
    local mt = __classmetatables[IsoPlayer.class].__index
    local old_sendObjectChange = mt.sendObjectChange
    local success = nil
    mt.sendObjectChange = function(player, str, luaTab, ...)--I do not handle "public void sendObjectChange(String var1, Object... var2)"
        success = str == 'mechanicActionDone' and luaTab.success
        if AutoMechanics.getVerbose() then print ("AutoMechanics sendObjectChange "..tostring(str).." "..tostring(success));end
        old_sendObjectChange(player, str, luaTab, ...)
    end
    
    vanilla_ISInstallVehiclePart_complete(self)
    
    mt.sendObjectChange = old_sendObjectChange--release hook
    
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
end

