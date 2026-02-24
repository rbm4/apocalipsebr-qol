-- LabAutopsyFeedback_Client.lua
-- Feedback de autópsia (CLIENT-ONLY, EVENT-DRIVEN)

local LabAutopsyFeedback = {}

-- Declara o evento customizado
if not Events.OnLabAutopsyComplete then
    LuaEventManager.AddEvent("OnLabAutopsyComplete")
end

local function ShowAutopsyFeedback(player, result)
    if not player or not result then return end
    
    if result == "AlreadyAutopsied" then
        player:Say(getText("IGUI_PlayerText_AutopsyAlready" .. ZombRand(1, 6)))
        return
    end

    --Chance de fala (30%)
    if ZombRand(100) >= 30 then
        return
    end
    
    if result == "Infected" then
        player:Say(getText("IGUI_PlayerText_AutopsyInfected" .. ZombRand(1, 6)))
        
    elseif result == "Tainted" then
        player:Say(getText("IGUI_PlayerText_AutopsyTainted" .. ZombRand(1, 6)))
        
    elseif result == "Nothing" then
        player:Say(getText("IGUI_PlayerText_AutopsyNothing" .. ZombRand(1, 6)))
    end
end

local function OnServerCommand(module, command, args)
    if module ~= "ZVirusVaccine42BETA" then return end
    if command ~= "AutopsyFeedback" then return end
    if not args or not args.result then return end
    
    local player = getPlayer()
    if not player then return end
    
    ShowAutopsyFeedback(player, args.result)
end

local function OnLabAutopsyComplete(player, result)
    ShowAutopsyFeedback(player, result)
end

Events.OnServerCommand.Add(OnServerCommand)
Events.OnLabAutopsyComplete.Add(OnLabAutopsyComplete)

return LabAutopsyFeedback