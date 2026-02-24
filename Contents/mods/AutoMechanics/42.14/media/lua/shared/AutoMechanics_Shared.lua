AutoMechanics = AutoMechanics or {}
AutoMechanics.ModKey = 'AutoMechanics'
AutoMechanics.MechanicActionSilentFailKey = 'mechanicActionSilentFail'


function AutoMechanics.getVerbose()
    if not isServer() then return AutoMechanics.getVerboseClient() end
    return false--change this to true for server to go verbose
end
