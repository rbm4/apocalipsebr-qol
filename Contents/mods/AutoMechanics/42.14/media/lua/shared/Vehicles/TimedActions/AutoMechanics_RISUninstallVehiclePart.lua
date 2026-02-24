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

local vanilla_ISUninstallVehiclePart_start = ISUninstallVehiclePart.start
function ISUninstallVehiclePart:start()
    if AutoMechanics.getVerbose() then print ("AutoMechanics ISUninstallVehiclePart:start "..tostring(self.character).." "..tostring(self.part).." "..tostring(AutoMechanics.jobOrganisation and AutoMechanics.jobOrganisation.pendingPart));end
    vanilla_ISUninstallVehiclePart_start(self)
    if AutoMechanics.jobOrganisation then
        local player = self.character
        local item = self.part and self.part:getInventoryItem()
        local itemId = item and item:getID()
        local installing = false
        local param7 = nil

        if AutoMechanics.getVerbose() then print ("AutoMechanics ISUninstallVehiclePart:start "..tostring(itemId).." "..tostring(player).." "..tostring(self.part).." "..tostring(AutoMechanics.jobOrganisation and AutoMechanics.jobOrganisation.pendingPart));end
        if player and itemId ~= nil and itemId ~= -1 and self.part ~= nil then
            if AutoMechanics.onAutoMechanicsTrain_started then
                if AutoMechanics.getVerbose() then print ("AutoMechanics continue from ISUninstallVehiclePart:start"); end
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
        end
    end
end

local vanilla_ISUninstallVehiclePart_perform = ISUninstallVehiclePart.perform
function ISUninstallVehiclePart:perform()
    if AutoMechanics.getVerbose() then print ("AutoMechanics ISUninstallVehiclePart:perform "..tostring(self.character).." "..tostring(self.part).." "..tostring(AutoMechanics.jobOrganisation and AutoMechanics.jobOrganisation.pendingPart));end
    vanilla_ISUninstallVehiclePart_perform(self)
end

--specific B42
local vanilla_ISUninstallVehiclePart_complete = ISUninstallVehiclePart.complete
function ISUninstallVehiclePart:complete()
    if AutoMechanics.getVerbose() then print ("AutoMechanics ISUninstallVehiclePart:complete");end

    -- hook the result vanilla function from local random
    -- Albion: needs to be the actual class of the object, not the class that declares the method like you may expect
    local mt = __classmetatables[IsoPlayer.class].__index
    local old_sendObjectChange = mt.sendObjectChange

    local mechanicActionDoneCalled = false
    local success = false
    mt.sendObjectChange = function(player, objectChangeEnum, luaTab, ...)
        local mechanicActionDoneCalledNow = objectChangeEnum == IsoObjectChange.MECHANIC_ACTION_DONE
        mechanicActionDoneCalled = mechanicActionDoneCalled or mechanicActionDoneCalledNow
        local successNow = mechanicActionDoneCalledNow and luaTab and luaTab.success
        success = success or successNow
        if AutoMechanics.getVerbose() then print ("AutoMechanics sendObjectChange "..tostring(mechanicActionDoneCalledNow).." "..tostring(successNow));end
        old_sendObjectChange(player, objectChangeEnum, luaTab, ...)
    end

    local playerObj = self.character
    local item = self.part and self.part:getInventoryItem()
    local itemId = item and item:getID()

    local isServerPatchOn = false
    if not ISInventoryPage then--patch up for vanilla 42.13.1
        ISInventoryPage = {}
        isServerPatchOn = true
    end
    local completed = vanilla_ISUninstallVehiclePart_complete(self)
    if isServerPatchOn then--remove patch for vanilla 42.13.1
        ISInventoryPage = nil
    end
    
    mt.sendObjectChange = old_sendObjectChange--release hook
    
    if not mechanicActionDoneCalled then
        --client will not get any answer (no OnMechanicActionDone) from vanilla when there is no success (aka uninstalled) and no failure (aka degrading part) but this never occurs anyway because failure is 100percent
        sendServerCommand(playerObj, AutoMechanics.ModKey, AutoMechanics.MechanicActionSilentFailKey, {})
    elseif not isServer() and not isClient() then --in solo OnMechanicActionDone is never sent / received
        local vehicleId = nil--unused
        local partName = nil--unused
        local installing = false
        local param7 = nil
        print  ("AutoMechanics ISUninstallVehiclePart:complete 2 "..tostring(isServer())..' '..tostring(isClient())..' '..tostring(self.character)..' '..tostring(itemId))
        if playerObj and itemId ~= nil and itemId ~= -1 then
            AutoMechanics.OnMechanicActionDone(playerObj,success,vehicleId,partName,itemId,installing,param7)
        end
    end
    return completed
end

