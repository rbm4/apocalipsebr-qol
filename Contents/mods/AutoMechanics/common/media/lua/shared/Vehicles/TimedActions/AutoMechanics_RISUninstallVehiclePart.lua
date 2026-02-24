AutoMechanics = AutoMechanics or {}

--hook timed actions
local vanilla_ISUninstallVehiclePart_stop = ISUninstallVehiclePart.stop
function ISUninstallVehiclePart:stop()
    vanilla_ISUninstallVehiclePart_stop(self)
    
    if AutoMechanics.onAutoMechanicsTrain_started then
        AutoMechanics.StopMechanicsTrain()
        if AutoMechanics.getVerbose() then print ("AutoMechanics stop from ISUninstallVehiclePart:stop");end
    end
end

--specific B42
local vanilla_ISUninstallVehiclePart_complete = ISUninstallVehiclePart.complete
function ISUninstallVehiclePart:complete()
    if AutoMechanics.getVerbose and AutoMechanics.getVerbose() then print ("AutoMechanics ISUninstallVehiclePart:complete");end

    local player = self.character
    local vehicleId = nil--unused
    local partName = nil--unused
    local item = self.part and self.part:getInventoryItem()
    local itemId = item and item:getID()
    local installing = false
    local param7 = nil

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
    
    vanilla_ISUninstallVehiclePart_complete(self)
    
    mt.sendObjectChange = old_sendObjectChange--release hook
    
    if AutoMechanics.jobOrganisation then
        if AutoMechanics.getVerbose() then print ("AutoMechanics ISUninstallVehiclePart:completed "..tostring(success).." "..tostring(itemId).." "..tostring(player).." "..tostring(self.part).." "..tostring(AutoMechanics.jobOrganisation and AutoMechanics.jobOrganisation.pendingPart));end
        if player and itemId ~= nil and itemId ~= -1 and self.part ~= nil then
            if AutoMechanics.onAutoMechanicsTrain_started then
                if AutoMechanics.getVerbose() then print ("AutoMechanics continue from ISUninstallVehiclePart:perform"); end
                AutoMechanics.jobOrganisation.pendingJob = "Uninstall";
                AutoMechanics.jobOrganisation.pendingPart = self.part
                AutoMechanics.jobOrganisation.pendingTimeSpeed = getGameTime():getTrueMultiplier();
                if AutoMechanics.OPTIONS.VerboseTimeSpeed then print ("AutoMechanics.ISUninstallVehiclePart timespeed = "..getGameTime():getTrueMultiplier()) end
            elseif AutoMechanics.doUntilSuccess() then
                AutoMechanics.untilSuccess.timeSpeed = getGameTime():getTrueMultiplier();
                AutoMechanics.untilSuccess.part = self.part
                AutoMechanics.untilSuccess.player = self.character
                AutoMechanics.untilSuccess.item = nil
            end
        
            AutoMechanics.OnMechanicActionDone(self.character,success,vehicleId,partName,itemId,installing,param7)
        end
    end
end

