AutoMechanics = AutoMechanics or {}

--AutoMechanics.ModKey, 
function AutoMechanics.OnServerCommand(mod, command, args)
    if AutoMechanics.getVerbose() then print("AutoMechanics.OnServerCommand("..mod.." , "..command.." , args?)") end
    if mod ~= AutoMechanics.ModKey then return end
    
    if command == AutoMechanics.MechanicActionSilentFailKey then
        if AutoMechanics.onAutoMechanicsTrain_started and AutoMechanics.jobOrganisation and AutoMechanics.jobOrganisation.player then
            if AutoMechanics.getVerbose() then print("AutoMechanics.OnServerCommand("..mod.." , "..command..") Forward silent failure.") end
            AutoMechanics.OnMechanicActionDone(AutoMechanics.jobOrganisation.player,false)--all other params to nil
        else
            if AutoMechanics.getVerbose() then print("AutoMechanics.OnServerCommand("..mod.." , "..command.." ) DISCARD silent failure. Started="..tostring(AutoMechanics.onAutoMechanicsTrain_started and 'true' or 'false')) end
        end
    end
end

Events.OnServerCommand.Add(AutoMechanics.OnServerCommand);