--        __     __                   
-- _|_   (_ ||\/|__) /\ _ _ _ _|   _  
--  |    __)||  |__)/--|_| (_(_||_|/_ 
--                     |              

-- SLOTS DE VOZ
local SIMBAproduz_TSY_MaxSlots             = 62     -- quantidade de slots de voz ABMIS (1..128)

-- DISTÂNCIAS (EM TILES)
local SIMBAproduz_TSY_FarRange             = 150    -- distância máxima para grito de descoberta
local SIMBAproduz_TSY_NearRange            = 8      -- distância para grito na cara

-- VOLUME / ESCALA GLOBAL
local SIMBAproduz_TSY_GlobalVolume         = 1.0    -- multiplicador global de volume TSY
local SIMBAproduz_TSY_FarVolume            = 0.08   -- volume base do grito de descoberta
local SIMBAproduz_TSY_NearVolume           = 1.0    -- multiplicador relativo para grito na cara
local SIMBAproduz_TSY_DayVolumeMult        = 1.0    -- multiplicador de volume durante o dia
local SIMBAproduz_TSY_NightVolumeMult      = 1.0    -- multiplicador de volume durante a noite

-- CHANCES (%) DE GRITO
local SIMBAproduz_TSY_DefaultScreechChance = 60     -- chance de grito de descoberta ao ver o player
local SIMBAproduz_TSY_ChaseScreechChance   = 50     -- chance de grito durante perseguição (0 = desligado)

-- ALERTA / HORDA
local SIMBAproduz_TSY_AlertRadiusDefault   = 80     -- raio para puxar horda com addSound
local SIMBAproduz_TSY_AlertEnabledDefault  = true   -- se puxar horda vem ligado por padrão

-- CLUSTER (ANTI-SPAM DE GRITOS)
local SIMBAproduz_TSY_ClusterRadius        = 35     -- raio para agrupar gritos no mesmo cluster
local SIMBAproduz_TSY_ClusterCooldownHours = 0.01   -- ~36 segundos de janela de tempo por cluster
local SIMBAproduz_TSY_MaxClusterScreams    = 1      -- máximo de gritos dentro do mesmo cluster e janela

-- PERSEGUIÇÃO / GRITO NA CARA
local SIMBAproduz_TSY_ChaseCooldownHours   = 0.03   -- cooldown entre tentativas de grito de perseguição
local SIMBAproduz_TSY_NearDelayTicks       = 10     -- ticks de atraso para o grito na cara depois de entrar no range

-- CONTEXTO DIA / NOITE
local SIMBAproduz_TSY_DayNightMode         = 0      -- 0 = dia e noite, 1 = só dia, 2 = só noite
local SIMBAproduz_TSY_NightThreshold       = 0.5    -- nightStrength a partir do qual consideramos "noite"

-- LIMITE / FASE DE PERSEGUIÇÃO
local SIMBAproduz_TSY_MaxScreamsPerZombie  = 3      -- descoberta, na cara, perseguição longa
local SIMBAproduz_TSY_ChaseMinDelayHours   = 0.02   -- tempo mínimo desde o último grito para poder gritar em perseguição

-- PERFORMANCE
local SIMBA_TSY_DefaultTickRate            = 6      -- quantos frames entre cada processamento por zumbi (6 ≈ a cada 0.1s em 60 FPS)
local SIMBA_TSY_DefaultMaxDistance         = 220    -- distância máxima (em tiles) para sequer considerar o zumbi
local SIMBA_TSY_MaxClusterEvents           = 200    -- hard limit na tabela de clusters (segurança extra)

local SIMBAproduz_TSY_ClimateManager = nil
local SIMBAproduz_TSY_Bag            = {}
local SIMBAproduz_TSY_LastVoiceIndex = nil
local SIMBAproduz_TSY_ClusterEvents  = {}

local SIMBA_TSY_CachedWorldHours     = 0
local SIMBA_TSY_TickCounter          = 0

local function SIMBAproduz_TSY_GetSandbox()
    if SandboxVars and SandboxVars.SIMBAproduz_TSY then
        return SandboxVars.SIMBAproduz_TSY
    end
    return nil
end

local function SIMBAproduz_TSY_GetWorldTimeHours()

    return SIMBA_TSY_CachedWorldHours
end

local function SIMBAproduz_TSY_GetNightStrength()
    if not SIMBAproduz_TSY_ClimateManager then
        SIMBAproduz_TSY_ClimateManager = getClimateManager()
    end
    if SIMBAproduz_TSY_ClimateManager then
        return SIMBAproduz_TSY_ClimateManager:getNightStrength()
    end
    return 0
end

local function SIMBAproduz_TSY_GetPeriodVolumeMult()
    local nightStrength = SIMBAproduz_TSY_GetNightStrength()
    if nightStrength > SIMBAproduz_TSY_NightThreshold then
        return SIMBAproduz_TSY_NightVolumeMult
    else
        return SIMBAproduz_TSY_DayVolumeMult
    end
end

local function SIMBAproduz_TSY_TimeAllowed()
    local vars = SIMBAproduz_TSY_GetSandbox()
    local mode = SIMBAproduz_TSY_DayNightMode
    if vars and vars.TimeMode ~= nil then
        mode = vars.TimeMode
    end
    local nightStrength = SIMBAproduz_TSY_GetNightStrength()
    if mode == 1 and nightStrength > SIMBAproduz_TSY_NightThreshold then
        return false 
    end
    if mode == 2 and nightStrength <= SIMBAproduz_TSY_NightThreshold then
        return false 
    end
    return true
end

local function SIMBAproduz_TSY_RefillBag()
    SIMBAproduz_TSY_Bag = {}
    for i = 1, SIMBAproduz_TSY_MaxSlots do
        SIMBAproduz_TSY_Bag[#SIMBAproduz_TSY_Bag + 1] = i
    end
    for i = #SIMBAproduz_TSY_Bag, 2, -1 do
        local j = ZombRand(1, i + 1)
        SIMBAproduz_TSY_Bag[i], SIMBAproduz_TSY_Bag[j] = SIMBAproduz_TSY_Bag[j], SIMBAproduz_TSY_Bag[i]
    end
end

local function SIMBAproduz_TSY_NextVoice()
    if #SIMBAproduz_TSY_Bag == 0 then
        SIMBAproduz_TSY_RefillBag()
    end
    local idx = table.remove(SIMBAproduz_TSY_Bag)
    if SIMBAproduz_TSY_LastVoiceIndex ~= nil and SIMBAproduz_TSY_MaxSlots > 1 and idx == SIMBAproduz_TSY_LastVoiceIndex then
        if #SIMBAproduz_TSY_Bag == 0 then
            SIMBAproduz_TSY_RefillBag()
        end
        local alt = table.remove(SIMBAproduz_TSY_Bag)
        SIMBAproduz_TSY_Bag[#SIMBAproduz_TSY_Bag + 1] = idx
        idx = alt
    end
    SIMBAproduz_TSY_LastVoiceIndex = idx
    return idx
end

local function SIMBAproduz_TSY_GetSoundName(index)
    return "SIMBAproduz_TSY_" .. tostring(index)
end

local function SIMBAproduz_TSY_Delay(func, delay)
    delay = delay or 1
    local ticks = 0
    local canceled = false
    local function onTick()
        if canceled then
            Events.OnTick.Remove(onTick)
            return
        end
        if ticks < delay then
            ticks = ticks + 1
            return
        end
        Events.OnTick.Remove(onTick)
        if not canceled then
            func()
        end
    end
    Events.OnTick.Add(onTick)
    return function()
        canceled = true
    end
end

local function SIMBAproduz_TSY_CanClusterScream(x, y, timeNow, vars)
    local radius    = SIMBAproduz_TSY_ClusterRadius
    local cooldown  = SIMBAproduz_TSY_ClusterCooldownHours
    local maxCluster = SIMBAproduz_TSY_MaxClusterScreams

    if vars then
        if vars.ClusterRadius and vars.ClusterRadius > 0 then
            radius = vars.ClusterRadius
        end
        if vars.ClusterCooldownHours and vars.ClusterCooldownHours > 0 then
            cooldown = vars.ClusterCooldownHours
        end
        if vars.MaxClusterScreams and vars.MaxClusterScreams > 0 then
            maxCluster = vars.MaxClusterScreams
        end
    end

    local radiusSq = radius * radius
    local count = 0
    local i = 1

    while i <= #SIMBAproduz_TSY_ClusterEvents do
        local ev = SIMBAproduz_TSY_ClusterEvents[i]
        if timeNow - ev.t > cooldown then
            table.remove(SIMBAproduz_TSY_ClusterEvents, i)
        else
            local dx = x - ev.x
            local dy = y - ev.y
            if dx * dx + dy * dy <= radiusSq then
                count = count + 1
            end
            i = i + 1
        end
    end

    if count >= maxCluster then
        return false
    end

    return true
end

local function SIMBAproduz_TSY_RegisterClusterScream(x, y, timeNow)
    if #SIMBAproduz_TSY_ClusterEvents >= SIMBA_TSY_MaxClusterEvents then
        table.remove(SIMBAproduz_TSY_ClusterEvents, 1)
    end
    SIMBAproduz_TSY_ClusterEvents[#SIMBAproduz_TSY_ClusterEvents + 1] = { x = x, y = y, t = timeNow }
end

local function SIMBAproduz_TSY_PlayFarScream(zombie, voiceIndex, dist, vars)
    local soundName = SIMBAproduz_TSY_GetSoundName(voiceIndex)
    local maxDist   = SIMBAproduz_TSY_FarRange
    local baseVol   = SIMBAproduz_TSY_FarVolume
    local globalVol = SIMBAproduz_TSY_GlobalVolume

    if vars then
        if vars.FarRange and vars.FarRange > 0 then
            maxDist = vars.FarRange
        end
        if vars.FarVolume and vars.FarVolume > 0 then
            baseVol = vars.FarVolume
        end
        if vars.GlobalVolume and vars.GlobalVolume > 0 then
            globalVol = vars.GlobalVolume
        end
    end

    local periodMult = SIMBAproduz_TSY_GetPeriodVolumeMult()
    local falloff    = math.min(1.0, dist / maxDist)
    local vol        = globalVol * baseVol * periodMult * (1.0 - falloff * 0.6)

    local sq = zombie:getSquare()
    if sq then
        getSoundManager():PlayWorldSound(soundName, sq, 0, vol, 1.0, false)
    end
end

local function SIMBAproduz_TSY_ScheduleNearScream(zombie, voiceIndex, vars)
    local soundName = SIMBAproduz_TSY_GetSoundName(voiceIndex)
    local globalVol = SIMBAproduz_TSY_GlobalVolume
    local nearMult  = SIMBAproduz_TSY_NearVolume
    local useWorld  = false

    if vars then
        if vars.GlobalVolume and vars.GlobalVolume > 0 then
            globalVol = vars.GlobalVolume
        end
        if vars.NearVolume and vars.NearVolume > 0 then
            nearMult = vars.NearVolume
        end
        if vars.NearAsWorldSound ~= nil then
            useWorld = vars.NearAsWorldSound
        end
    end

    local periodMult = SIMBAproduz_TSY_GetPeriodVolumeMult()
    local vol        = globalVol * nearMult * periodMult

    SIMBAproduz_TSY_Delay(function()
        if zombie and not zombie:isDead() then
            if useWorld then
                local sq = zombie:getSquare()
                if sq then
                    getSoundManager():PlayWorldSound(soundName, sq, 0, vol, 1.0, false)
                end
            else
                zombie:playSound(soundName)
            end
        end
    end, SIMBAproduz_TSY_NearDelayTicks)
end

local function SIMBAproduz_TSY_TriggerAlert(playerObj, vars)
    local enabled = SIMBAproduz_TSY_AlertEnabledDefault
    local radius  = SIMBAproduz_TSY_AlertRadiusDefault

    if vars then
        if vars.AlertNearbyZombies ~= nil then
            enabled = vars.AlertNearbyZombies
        end
        if vars.AlertRadius and vars.AlertRadius > 0 then
            radius = vars.AlertRadius
        end
    end

    if not enabled or radius <= 0 then
        return
    end

    local x = playerObj:getX()
    local y = playerObj:getY()

    local function pulse()
        addSound(playerObj, x, y, 0, radius, radius)
    end

    pulse()
    SIMBAproduz_TSY_Delay(pulse, 20)
    SIMBAproduz_TSY_Delay(pulse, 40)
    SIMBAproduz_TSY_Delay(pulse, 60)
    SIMBAproduz_TSY_Delay(pulse, 80)
end

local function SIMBAproduz_TSY_IsSprinter(zombie)

    if not zombie then
        return false
    end

    if zombie:isDead() then
        return false
    end
    if zombie.isFakeDead and zombie:isFakeDead() then
        return false
    end

    if not zombie.getVariableString then
        return false
    end

    local walkType = zombie:getVariableString("zombiewalktype")
    if not walkType then
        return false
    end

    walkType = tostring(walkType)

    if not string.find(walkType, "WTSprint") and not string.find(string.lower(walkType), "sprint") then
        return false
    end

    return true
end


local function SIMBA_TSY_OnZombieUpdate(zombie)

    if not zombie or zombie:isDead() or (zombie.isFakeDead and zombie:isFakeDead()) then
        return
    end

    if not SIMBAproduz_TSY_IsSprinter(zombie) then
        return
    end
    if not SIMBAproduz_TSY_TimeAllowed() then
        return
    end


    local player = getPlayer()
    if not player or player:isDead() then
        return
    end

    local vars = SIMBAproduz_TSY_GetSandbox()

    local tickRate = SIMBA_TSY_DefaultTickRate
    if vars and vars.TickRate and vars.TickRate > 0 then
        tickRate = vars.TickRate
    end

    local modData = zombie:getModData()

    if tickRate and tickRate > 1 then
        local nextTick = modData.SIMBAproduz_TSY_NextTick or 0
        if SIMBA_TSY_TickCounter < nextTick then
            return
        end
        modData.SIMBAproduz_TSY_NextTick = SIMBA_TSY_TickCounter + tickRate
    end

    local maxProcessDist = SIMBA_TSY_DefaultMaxDistance
    if vars and vars.MaxProcessDistance and vars.MaxProcessDistance > 0 then
        maxProcessDist = vars.MaxProcessDistance
    end

    local zx = zombie:getX()
    local zy = zombie:getY()
    local px = player:getX()
    local py = player:getY()

    local dx = zx - px
    local dy = zy - py

    if dx > maxProcessDist or dx < -maxProcessDist or dy > maxProcessDist or dy < -maxProcessDist then
        return
    end

    local farRange = SIMBAproduz_TSY_FarRange
    if vars and vars.FarRange and vars.FarRange > 0 then
        farRange = vars.FarRange
    end

    local dist = zombie:DistTo(player)
    if not dist or dist < 0 or dist > farRange then
        return
    end

    if not zombie:CanSee(player) then
        return
    end

    local voiceIndex = modData.SIMBAproduz_TSY_VoiceIndex
    if not voiceIndex then
        voiceIndex = SIMBAproduz_TSY_NextVoice()
        modData.SIMBAproduz_TSY_VoiceIndex = voiceIndex
    end

    local timeNow  = SIMBAproduz_TSY_GetWorldTimeHours()
    local x        = zx
    local y        = zy

    local lastAny  = modData.SIMBAproduz_TSY_LastAnyScreamTime or 0
    local totalAny = modData.SIMBAproduz_TSY_ScreamCount or 0

    if SIMBAproduz_TSY_MaxScreamsPerZombie and SIMBAproduz_TSY_MaxScreamsPerZombie > 0 then
        if totalAny >= SIMBAproduz_TSY_MaxScreamsPerZombie then
            return
        end
    end

    local screechChance = SIMBAproduz_TSY_DefaultScreechChance
    local chaseChance   = SIMBAproduz_TSY_ChaseScreechChance
    local enableNearScream = true

    if vars then
        local vScreech = tonumber(vars.ScreechChance)
        if vScreech and vScreech >= 0 and vScreech <= 100 then
            screechChance = vScreech
        end

        local vChase = tonumber(vars.ChaseScreechChance)
        if vChase and vChase >= 0 and vChase <= 100 then
            chaseChance = vChase
        end

        if vars.EnableNearScream ~= nil then
            enableNearScream = vars.EnableNearScream
        end
    end

    if not modData.SIMBAproduz_TSY_HasFarScreamed then

        if dist > SIMBAproduz_TSY_NearRange then
            if ZombRand(0, 100) <= screechChance then
                if SIMBAproduz_TSY_CanClusterScream(x, y, timeNow, vars) then
                    SIMBAproduz_TSY_PlayFarScream(zombie, voiceIndex, dist, vars)
                    SIMBAproduz_TSY_RegisterClusterScream(x, y, timeNow)
                    SIMBAproduz_TSY_TriggerAlert(player, vars)

                    totalAny = totalAny + 1
                    modData.SIMBAproduz_TSY_LastAnyScreamTime = timeNow
                    modData.SIMBAproduz_TSY_ScreamCount       = totalAny
                end
            end
        end

        modData.SIMBAproduz_TSY_HasFarScreamed = true

    else

        if enableNearScream and not modData.SIMBAproduz_TSY_HasNearScreamed and dist <= SIMBAproduz_TSY_NearRange then
            if SIMBAproduz_TSY_CanClusterScream(x, y, timeNow, vars) then
                SIMBAproduz_TSY_ScheduleNearScream(zombie, voiceIndex, vars)
                SIMBAproduz_TSY_RegisterClusterScream(x, y, timeNow)

                totalAny = totalAny + 1
                modData.SIMBAproduz_TSY_LastAnyScreamTime = timeNow
                modData.SIMBAproduz_TSY_ScreamCount       = totalAny
            end
            modData.SIMBAproduz_TSY_HasNearScreamed = true

        else

            local readyForChase = modData.SIMBAproduz_TSY_HasNearScreamed or (not enableNearScream)

            if readyForChase and dist > SIMBAproduz_TSY_NearRange then

                if SIMBAproduz_TSY_ChaseMinDelayHours and SIMBAproduz_TSY_ChaseMinDelayHours > 0 then
                    if (timeNow - lastAny) < SIMBAproduz_TSY_ChaseMinDelayHours then
                        return
                    end
                end

                local lastChase = modData.SIMBAproduz_TSY_LastChaseTime or 0
                local cooldown  = SIMBAproduz_TSY_ChaseCooldownHours

                if vars then
                    local vCooldown = tonumber(vars.ChaseCooldownHours)
                    if vCooldown and vCooldown > 0 then
                        cooldown = vCooldown
                    end
                end

                if cooldown and cooldown > 0 and timeNow - lastChase >= cooldown and chaseChance and chaseChance > 0 then
                    local roll = ZombRand(0, 100)
                    if roll <= chaseChance then
                        if SIMBAproduz_TSY_CanClusterScream(x, y, timeNow, vars) then
                            SIMBAproduz_TSY_PlayFarScream(zombie, voiceIndex, dist, vars)
                            SIMBAproduz_TSY_RegisterClusterScream(x, y, timeNow)
                            SIMBAproduz_TSY_TriggerAlert(player, vars)

                            totalAny = totalAny + 1
                            modData.SIMBAproduz_TSY_LastChaseTime      = timeNow
                            modData.SIMBAproduz_TSY_LastAnyScreamTime  = timeNow
                            modData.SIMBAproduz_TSY_ScreamCount        = totalAny
                        end
                    end
                end
            end
        end
    end
end


local function SIMBA_TSY_OnZombieDead(zombie)
    local modData = zombie:getModData()
    modData.SIMBAproduz_TSY_VoiceIndex        = nil
    modData.SIMBAproduz_TSY_HasFarScreamed    = nil
    modData.SIMBAproduz_TSY_HasNearScreamed   = nil
    modData.SIMBAproduz_TSY_LastChaseTime     = nil
    modData.SIMBAproduz_TSY_LastAnyScreamTime = nil
    modData.SIMBAproduz_TSY_ScreamCount       = nil
    modData.SIMBAproduz_TSY_NextTick          = nil
end

local function SIMBA_TSY_OnGameStart()
    SIMBAproduz_TSY_ClimateManager = getClimateManager()
    SIMBA_TSY_CachedWorldHours     = getGameTime():getWorldAgeHours()
end

local function SIMBA_TSY_OnTick()
    SIMBA_TSY_TickCounter     = SIMBA_TSY_TickCounter + 1
    SIMBA_TSY_CachedWorldHours = getGameTime():getWorldAgeHours()
end

Events.OnGameStart.Add(SIMBA_TSY_OnGameStart)
Events.OnZombieDead.Add(SIMBA_TSY_OnZombieDead)
Events.OnZombieUpdate.Add(SIMBA_TSY_OnZombieUpdate)
Events.OnTick.Add(SIMBA_TSY_OnTick)
