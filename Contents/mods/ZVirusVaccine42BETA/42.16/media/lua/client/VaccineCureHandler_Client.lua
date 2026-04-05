-- VaccineCureHandler_Client.lua
-- Monitora confirmacoes de cura do servidor

local VaccineCureHandler = {}

local function OnServerCommand(module, command, args)
    if module ~= "ZVirusVaccine42BETA" then return end
    
    if command == "ConfirmCure" then
        if not args then return end
        
        local player = getPlayer()
        if not player then return end
        
        if args.playerOnline and player:getOnlineID() ~= args.playerOnline then
            return
        end
        
        local body = player:getBodyDamage()
        if not body then return end
        
        -- Verifica status (apenas para log interno se necessario)
        local stillInfected = false
        if body.isInfected then
            local ok, res = pcall(function() return body:isInfected() end)
            if ok then stillInfected = res end
        end
    end
end

Events.OnServerCommand.Add(OnServerCommand)

return VaccineCureHandler