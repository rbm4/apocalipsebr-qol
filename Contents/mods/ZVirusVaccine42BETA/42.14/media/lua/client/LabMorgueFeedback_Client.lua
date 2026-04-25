-- LabMorgueFeedback_Client.lua
-- Feedback de ações de morgue (SP + MP, event-driven)

local LabMorgueFeedback = {}

-- Evento customizado para SP
if not Events.OnLabMorgueAction then
    LuaEventManager.AddEvent("OnLabMorgueAction")
end

local function ShowMorgueFeedback(player, action)
    if not player or not action then return end

    if action == "CorpsePlaced" then
        if not LabModOptions.rollSpeech("speechChanceMorgueCorpsePlaced", 50) then return end
        player:Say(getText("IGUI_PlayerText_MorguePlace" .. ZombRand(1, 6)))

    elseif action == "Success" then
        if not LabModOptions.rollSpeech("speechChanceMorgueSuccess", 50) then return end
        player:Say(getText("IGUI_PlayerText_MorgueGetRemains" .. ZombRand(1, 6)))

    elseif action == "NoContainer" then
        if not LabModOptions.rollSpeech("speechChanceMorgueNoContainer", 50) then return end
        player:Say(getText("IGUI_PlayerText_MorgueNoContainer"))

    elseif action == "TableCleaned" then
        if not LabModOptions.rollSpeech("speechChanceMorgueTableCleaned", 50) then return end
        player:Say(getText("IGUI_PlayerText_MorgueClean" .. ZombRand(1, 6)))

    elseif action == "CorpseRemoved" then
        if not LabModOptions.rollSpeech("speechChanceMorgueCorpseRemoved", 50) then return end
        player:Say(getText("IGUI_PlayerText_MorgueRemoveCorpse" .. ZombRand(1, 6)))

    elseif action == "BodyPartCollected" then
        if not LabModOptions.rollSpeech("speechChanceMorgueBodyPartCollected", 50) then return end
        player:Say(getText("IGUI_PlayerText_MorgueBodyPartCollected" .. ZombRand(1, 6)))
    end
end

-- MP
local function OnServerCommand(module, command, args)
    if module ~= "ZVirusVaccine42BETA" then return end
    if command ~= "MorgueFeedback" then return end
    if not args or not args.action then return end

    local player = getPlayer()
    if not player then return end

    ShowMorgueFeedback(player, args.action)
end

-- SP
local function OnLabMorgueAction(player, action)
    ShowMorgueFeedback(player, action)
end

Events.OnServerCommand.Add(OnServerCommand)
Events.OnLabMorgueAction.Add(OnLabMorgueAction)

return LabMorgueFeedback