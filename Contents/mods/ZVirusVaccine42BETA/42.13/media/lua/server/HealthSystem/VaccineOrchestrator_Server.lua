-- VaccineOrchestrator_Server.lua
-- Orquestrador SERVER-SIDE

print("[ZVirusVaccine] ========================================")
print("[ZVirusVaccine] INICIALIZING ORCHESTRATOR")
print("[ZVirusVaccine] ========================================")

local function SafeRequire(moduleName)
    local success, result = pcall(require, moduleName)
    if not success then
        print("[ZVirusVaccine] [ERROR] Failed to load " .. moduleName .. ": " .. tostring(result))
        return nil
    end
    if not result then
        print("[ZVirusVaccine] [ERROR] " .. moduleName .. " returned nil")
        return nil
    end
    return result
end

local VaccineLogic = SafeRequire("HealthSystem/VaccineLogic_Server")
local BloodTestLogic = SafeRequire("HealthSystem/BloodTestLogic_Server")
local LabAutopsyLogic = SafeRequire("HealthSystem/LabAutopsyLogic_Server")
local LabCollectBloodLogic = SafeRequire("HealthSystem/LabCollectBloodLogic_Server")
local LabBloodAgingLogic = SafeRequire("HealthSystem/LabBloodAgingLogic_Server")
local LabMorgueLogic = SafeRequire("HealthSystem/LabMorgueLogic_Server")
local LabAlbuminLogic = SafeRequire("HealthSystem/LabAlbuminLogic_Server")
local LabWaterPurification = SafeRequire("HealthSystem/LabWaterPurification_Server")

print("[ZVirusVaccine] LOADED MODULES")
print("[ZVirusVaccine] VaccineLogic: " .. tostring(VaccineLogic ~= nil))
print("[ZVirusVaccine] BloodTestLogic: " .. tostring(BloodTestLogic ~= nil))
print("[ZVirusVaccine] LabAutopsyLogic: " .. tostring(LabAutopsyLogic ~= nil))
print("[ZVirusVaccine] LabCollectBloodLogic: " .. tostring(LabCollectBloodLogic ~= nil))
print("[ZVirusVaccine] LabBloodAgingLogic: " .. tostring(LabBloodAgingLogic ~= nil))
print("[ZVirusVaccine] LabMorgueLogic: " .. tostring(LabMorgueLogic ~= nil))
print("[ZVirusVaccine] LabAlbuminLogic: " .. tostring(LabAlbuminLogic ~= nil))
print("[ZVirusVaccine] LabWaterPurification: " .. tostring(LabWaterPurification ~= nil))
print("[ZVirusVaccine] ========================================")
print("[ZVirusVaccine] MOD VERSION FOR: B42.13 - B42.13.2")

local VaccineOrchestrator = {}

local eventsRegistered = false

local function RegisterBloodAgingEvent()
    if eventsRegistered then 
        return 
    end
    
    local sandbox = SandboxVars.ZombieVirusVaccineBETA
    
    if not sandbox then
        Events.OnTick.Add(function()
            Events.OnTick.Remove(RegisterBloodAgingEvent)
            RegisterBloodAgingEvent()
        end)
        return
    end
    
    local enableBloodAging = sandbox.BloodAgingMode
    enableBloodAging = (enableBloodAging == true)
    
    if enableBloodAging and LabBloodAgingLogic and LabBloodAgingLogic.AdjustBloodCondition then
        Events.EveryTenMinutes.Add(LabBloodAgingLogic.AdjustBloodCondition)
        print("[ZVirusVaccine] Blood Aging Event Enabled")
    end
    
    eventsRegistered = true
end

local function OnClientCommand(module, command, player, args)
    if module ~= "ZVirusVaccine42BETA" then return end
    
    if command == "InjectVaccine" then
        if not player or not args or not args.itemType or not VaccineLogic then
            return
        end
        
        VaccineLogic.ProcessInjection(player, args.itemType)
        VaccineLogic.ConsumeSyringe(player, args.itemType)
    
    elseif command == "TestBlood" then
        if not player or not args or not args.itemType or not BloodTestLogic then
            return
        end
        
        BloodTestLogic.ProcessTest(player, args.itemType)
    
    elseif command == "CollectBlood" then
        if not player or not args or not args.itemType or not LabCollectBloodLogic then
            return
        end
        
        LabCollectBloodLogic.ProcessCollection(player, args.itemType)
    
    elseif command == "MakeAutopsy" then
        if not (player and args and LabAutopsyLogic) then
            print("[ERRO][AUTOPSY] Comando inválido")
            return
        end
        
        LabAutopsyLogic.ProcessAutopsy(
            player,
            args.isOnTable,
            args.corpseId,
            args.topX,
            args.topY,
            args.topZ,
            args.corpseX,
            args.corpseY,
            args.corpseZ
        )
    
    elseif command == "TakeAlbumin" then
        if not player or not args or not args.pillsType or not LabAlbuminLogic then
            return
        end
        
        LabAlbuminLogic.TakeAlbumin(player, args.pillsType)
    
    elseif command == "PutCorpseOnTable" then
        if not player or not args or not LabMorgueLogic then
            return
        end
        
        LabMorgueLogic.PutCorpseOnTable(player, args)
    
    elseif command == "GetRemains" then
        if not player or not args or not LabMorgueLogic then
            return
        end
        
        LabMorgueLogic.GetRemains(player, args)

    elseif command == "CollectBodyPart" then
        if not player or not args or not LabMorgueLogic then
            return
        end
        
        LabMorgueLogic.CollectBodyPart(player, args)
    
    elseif command == "ClearTable" then
        if not player or not args or not LabMorgueLogic then
            return
        end
        
        LabMorgueLogic.ClearTable(player, args)
    
    elseif command == "RemoveCorpseFromTable" then
        if not player or not args or not LabMorgueLogic then
            return
        end
        
        LabMorgueLogic.RemoveCorpseFromTable(player, args)
    
    elseif command == "CheckCorpseAutopsied" then
        if not player or not args or not LabAutopsyLogic then
            return
        end
        
        local isAutopsied = LabAutopsyLogic.IsCorpseAutopsied(
            args.corpseX,
            args.corpseY,
            args.corpseZ,
            args.corpseId
        )
        
        sendServerCommand(
            player,
            "ZVirusVaccine42BETA",
            "CorpseAutopsyStatus",
            {
                corpseX = args.corpseX,
                corpseY = args.corpseY,
                corpseZ = args.corpseZ,
                corpseId = args.corpseId,
                isAutopsied = isAutopsied
            }
        )
    end
end

local function OnEveryHour()
    local players = getOnlinePlayers()
    
    if not players or players:size() == 0 then
        local localPlayer = getSpecificPlayer(0)
        if localPlayer then
            players = {localPlayer}
        else
            return
        end
    end
    
    local playerCount = (type(players) == "table") and #players or players:size()
    
    for i = 0, playerCount - 1 do
        local player = (type(players) == "table") and players[i + 1] or players:get(i)
        
        if player then
            local body = player:getBodyDamage()
            local pMod = player:getModData()
            
            if body and pMod then
                local infected = body:isInfected()
                
                if infected and pMod.VaccineRecess and pMod.VaccineRecess > 0 then
                    local infectionRate = 0
                    if VaccineLogic and VaccineLogic.GetInfectionRate then
                        infectionRate = VaccineLogic.GetInfectionRate(player)
                    end
                    
                    if infectionRate >= 0.4 then
                        if VaccineLogic and VaccineLogic.ApplyRecessEffect then
                            VaccineLogic.ApplyRecessEffect(player)
                        end
                        
                        pMod.VaccineRecess = pMod.VaccineRecess - 1
                        
                        if pMod.VaccineRecess <= 0 then
                            if pMod.VaccineStrength and pMod.VaccineStrength > 0 then
                                local rollValue = ZombRand(100)
                                local vaccineStrength = pMod.VaccineStrength
                                
                                if vaccineStrength > rollValue then
                                    if VaccineLogic and VaccineLogic.ProcessInjection then
                                        VaccineLogic.ProcessInjection(player, "CmpSyringeWithCure")
                                    end
                                end
                                
                                pMod.VaccineStrength = 0
                                pMod.VaccineTime = 0
                            end
                        end
                    end
                end
                
                if not infected then
                    if pMod.VaccineTime and pMod.VaccineTime > 0 then
                        pMod.VaccineTime = pMod.VaccineTime - 1
                        
                        if pMod.VaccineTime <= 0 then
                            pMod.VaccineStrength = 0
                        end
                    end
                end
            end
        end
    end
end

----- Events -----
Events.OnClientCommand.Add(OnClientCommand)
Events.EveryHours.Add(OnEveryHour)

Events.OnGameStart.Add(RegisterBloodAgingEvent)

if isServer() then
    print("[ZVirusVaccine] Registering Blood Aging Event on server...")
    Events.OnServerStarted.Add(RegisterBloodAgingEvent)
end

print("[ZVirusVaccine] ========================================")
print("[ZVirusVaccine] ORCHESTRATOR LOADED")
print("[ZVirusVaccine] ========================================")

return VaccineOrchestrator