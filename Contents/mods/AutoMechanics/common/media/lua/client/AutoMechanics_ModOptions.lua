require "AutoMechanics"

-- Storage array for all of our options
AutoMechanics.OPTIONS = {
    Verbose        = nil,
    EndPause       = nil,
    UntilSuccess   = nil,
    FailThreshold  = nil,
}

-- Hello! In this example, I'll be showing you all of the new Native ModOptions that is available to us!
-- I've tried to document all of the available options, and I recommend enabling the mod to check it out in action.
-- Settings are saved at: Zomboid\Lua\modOptions.ini
-- For translations, you can use `getText()` for each of the below options as well.  For this example, I opted to not.
local function ModOptions() 
    -- Create the options object! This is required when adding the new Mod Options
    --- "UNIQUEID" should be replaced with your own unique ID. Possibly best to just use your mod's ID
    -- create(UID, name)
    local id = "AutoMechanics"
    local options = PZAPI.ModOptions:create(id, getText("Sandbox_AutoMechanics"))
    -- addTickBox(ID, name, value, _tooltip)
    -- addSlider(ID, name, min, max, step, value, _tooltip)
    AutoMechanics.OPTIONS.FailThreshold = options:addSlider("0",  getText("UI_AutoMechanics_FailThreshold"), 0, 100, 1, 100, getText("UI_AutoMechanics_Tooltip_FailThreshold"))
    AutoMechanics.OPTIONS.EndPause      = options:addTickBox("1", getText("UI_AutoMechanics_EndPause"), false, getText("UI_AutoMechanics_Tooltip_EndPause"))
    AutoMechanics.OPTIONS.UntilSuccess  = options:addTickBox("2", getText("UI_AutoMechanics_UntilSuccess"), true, getText("UI_AutoMechanics_Tooltip_UntilSuccess"))
    AutoMechanics.OPTIONS.Verbose       = options:addTickBox("3", getText("UI_Verbose"), false, getText("UI_Tooltip_Verbose"))

    -- NOTE:
    --- You DO NOT have to store the items like I have.
    --- You can retrieve your `options` object at anytime by doing: 
    ------ local options = PZAPI.ModOptions:getOptions(id)
    
    --- You can retrieve each individual option by doing:
    ------ local option = options:getOption(ID)
    ------- Where "ID" is the ID of the option you want to get.
    -------- In the above exemple, doing options:getOption("2") would return the FailThreshold
end

ModOptions()



function AutoMechanics.getWaitCycle()--TODO implement when MP comes
    return 0
end

function AutoMechanics.getConditionLossPercentageThresholdServer()
    local serverThreshold = 100--do as you please in solo if no sandbox settings
    if isClient() or AutoMechanics.OPTIONS.Verbose then--activates sandbox check in solo with verbose
        serverThreshold = 0--strict limit in MP to protect from noobs (not from trolls though. trolls always find ways in PZ, sorry) in cas the server was started before the variable existed
        if SandboxVars and SandboxVars.AutoMechanics and SandboxVars.AutoMechanics.ConditionLossPercentageThreshold then
            serverThreshold = SandboxVars.AutoMechanics.ConditionLossPercentageThreshold--if the parameter exists, apply it. usefull for private servers that allow anyone to do anything.
        end
    end
    return serverThreshold
end

function AutoMechanics.getConditionLossPercentageThreshold()
    local clientThreshold = AutoMechanics.getConditionLossPercentageThresholdClient()
    local serverThreshold = AutoMechanics.getConditionLossPercentageThresholdServer()
    if AutoMechanics.OPTIONS.Verbose then print ("Engine threshold. client="..clientThreshold.." server="..serverThreshold) end
    if serverThreshold < clientThreshold then
        return serverThreshold
    else
        return clientThreshold
    end
end

function AutoMechanics.getEndPause()
    return AutoMechanics.OPTIONS.EndPause and AutoMechanics.OPTIONS.EndPause:getValue()
end

function AutoMechanics.doUntilSuccess()
    return AutoMechanics.OPTIONS.UntilSuccess and AutoMechanics.OPTIONS.UntilSuccess:getValue()
end

function AutoMechanics.getConditionLossPercentageThresholdClient()
    return AutoMechanics.OPTIONS.FailThreshold and AutoMechanics.OPTIONS.FailThreshold:getValue()
end

function AutoMechanics.getVerbose()
    return AutoMechanics.OPTIONS.Verbose and AutoMechanics.OPTIONS.Verbose:getValue()
end

