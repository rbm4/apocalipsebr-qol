-- LabAutopsyHandler_Client.lua
-- Handler CLIENT-SIDE para receber notificacoes de autopsia
-- Este handler recebe broadcasts do servidor quando corpos sao autopsiados
-- Garante que todos os clientes saibam quais corpos foram autopsiados

function OnServerCommand(module, command, args)
    if module ~= "ZVirusVaccine42BETA" then return end
    
    if command == "CorpseAutopsied" then
        if not args or not args.corpseKey then return end
        
        if LabModEngine and LabModEngine.autopsiedCorpsesCache then
            LabModEngine.autopsiedCorpsesCache[args.corpseKey] = true
        end
    
    elseif command == "CorpseAutopsyStatus" then
        if not args then return end
        
        local corpseKey = args.corpseId
            and string.format("%d_%d_%d_%d", args.corpseX, args.corpseY, args.corpseZ, args.corpseId)
            or string.format("%d_%d_%d", args.corpseX, args.corpseY, args.corpseZ)
        
        if LabModEngine and LabModEngine.autopsiedCorpsesCache then
            LabModEngine.autopsiedCorpsesCache[corpseKey] = args.isAutopsied
        end
    end
end

Events.OnServerCommand.Add(OnServerCommand)