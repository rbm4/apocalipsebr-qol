--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

require "DAMN_ScriptTweaker";

DAMN = DAMN or {};

Events.OnGameStart.Add(function()
    for sbVar, scriptFile in pairs({
        ["AllowVanillaVehicleDismantling"] = "recipes_damnDismantleVanillaVehicles.txt",
        ["AllowVanillaWorldItemDismantling"] = "recipes_damnDismantleWorldItems.txt",
    })
    do
        if SandboxVars.DAMN[sbVar]
        then
            DAMN.ScriptTools:loadScriptInModFolder("damnlib", "dynamicScripts/" .. scriptFile);
        end
    end
end);