-- LabCollectBloodFeedback_Client.lua
-- Feedback de coleta de sangue (SP + MP, event-driven)

local LabCollectBloodFeedback = {}

-- Declara evento customizado para SP
if not Events.OnLabCollectBloodComplete then
    LuaEventManager.AddEvent("OnLabCollectBloodComplete")
end

local function ShowCollectBloodFeedback(player)
    if not player then return end

    player:Say(getText("IGUI_PlayerText_PainFromNeedle" .. ZombRand(1, 6)))

end

-- MP
local function OnServerCommand(module, command, args)
    if module ~= "ZVirusVaccine42BETA" then return end
    if command ~= "CollectBloodFeedback" then return end

    local player = getPlayer()
    if not player then return end

    ShowCollectBloodFeedback(player)
end

-- SP
local function OnLabCollectBloodComplete(player)
    ShowCollectBloodFeedback(player)
end

Events.OnServerCommand.Add(OnServerCommand)
Events.OnLabCollectBloodComplete.Add(OnLabCollectBloodComplete)

return LabCollectBloodFeedback