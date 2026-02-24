-- BloodTestFeedback_Client.lua
-- Feedback de teste sanguíneo (SP + MP, event-driven)

local BloodTestFeedback = {}

-- Declara evento customizado para SP
if not Events.OnLabBloodTestComplete then
    LuaEventManager.AddEvent("OnLabBloodTestComplete")
end

local function ShowBloodTestFeedback(player, result, rate)
    if not player or not result then return end

    if result == "InvalidSample" then
        player:Say(getText("IGUI_PlayerText_InvalidSample"))

    elseif result == "Negative" then
        player:Say(getText("IGUI_PlayerText_TestNegative" .. ZombRand(1, 6)))

    elseif result == "Positive" then
        if rate and rate > 0 then
            local mainText = getText("IGUI_PlayerText_TestPositive" .. ZombRand(1, 7)) -- Fala principal
            local extraText = getText("IGUI_PlayerText_InfectionRate") -- Taxa de infecção
            player:Say(mainText .. " " .. tostring(rate) .. extraText)
        else
            player:Say(getText("IGUI_PlayerText_TestPositive"))
        end
    end
end

-- MP
local function OnServerCommand(module, command, args)
    if module ~= "ZVirusVaccine42BETA" then return end
    if command ~= "BloodTestFeedback" then return end
    if not args or not args.result then return end

    local player = getPlayer()
    if not player then return end

    ShowBloodTestFeedback(player, args.result, args.rate)
end

-- SP
local function OnLabBloodTestComplete(player, result, rate)
    ShowBloodTestFeedback(player, result, rate)
end

Events.OnServerCommand.Add(OnServerCommand)
Events.OnLabBloodTestComplete.Add(OnLabBloodTestComplete)

return BloodTestFeedback