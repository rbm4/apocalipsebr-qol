require "TimedActions/ISBaseTimedAction"

LabActionInjectVaccine = ISBaseTimedAction:derive("LabActionInjectVaccine")

-- TABELA GLOBAL DE VACINAS/CURA (usa a lógica original)
vaccineEffect = {
    CmpSyringeWithPlainVaccine = {
        Min = 0.15, Max = 0.86,
        CureChance = 5, InfectChance = 40,
        Time = 0, Strength = 0,
        AlbuminMin = 3, AlbuminDelta = 4,
        Recess = 0
    },

    CmpSyringeWithQualityVaccine = {
        Min = 0.10, Max = 0.91,
        CureChance = 10, InfectChance = 10,
        Time = 168, Strength = 20,
        AlbuminMin = 5, AlbuminDelta = 5,
        Recess = 1
    },

    CmpSyringeWithAdvancedVaccine = {
        Min = 0.05, Max = 0.96,
        CureChance = 15, InfectChance = 1,
        Time = 504, Strength = 65,
        AlbuminMin = 8, AlbuminDelta = 6,
        Recess = 2
    },

    CmpSyringeWithCure = {
        Min = -1, Max = 0.99,
        CureChance = 105, InfectChance = 0,
        Time = 0, Strength = 0,
        AlbuminMin = 0, AlbuminDelta = 0,
        Recess = 0
    },

    CmpSyringeReusableWithPlainVaccine = {
        Min = 0.15, Max = 0.86,
        CureChance = 5, InfectChance = 40,
        Time = 0, Strength = 0,
        AlbuminMin = 3, AlbuminDelta = 4,
        Recess = 0
    },

    CmpSyringeReusableWithQualityVaccine = {
        Min = 0.10, Max = 0.91,
        CureChance = 10, InfectChance = 10,
        Time = 168, Strength = 20,
        AlbuminMin = 5, AlbuminDelta = 5,
        Recess = 1
    },

    CmpSyringeReusableWithAdvancedVaccine = {
        Min = 0.05, Max = 0.96,
        CureChance = 15, InfectChance = 1,
        Time = 504, Strength = 65,
        AlbuminMin = 8, AlbuminDelta = 6,
        Recess = 2
    },

    CmpSyringeReusableWithCure = {
        Min = -1, Max = 0.99,
        CureChance = 105, InfectChance = 0,
        Time = 0, Strength = 0,
        AlbuminMin = 0, AlbuminDelta = 0,
        Recess = 0
    },
}

-- FUNÇÕES ORIGINAIS DE LÓGICA DE VACINA/CURA
function LabRecipes_InfectionRate(player)
    local body = player:getBodyDamage()
    return (player:getHoursSurvived() - body:getInfectionTime()) / body:getInfectionMortalityDuration()
end

function LabRecipes_CurePlayer(body)
    body:setInfected(false)
    body:setInfectionLevel(0)
    body:setInfectionMortalityDuration(-1)
    body:setInfectionTime(-1)

    local parts = body:getBodyParts()
    for i = 0, parts:size() - 1 do
        parts:get(i):SetInfected(false)
    end
end

function LabRecipes_DoInjection(player, vaccine)
    local body = player:getBodyDamage()
    local pMod = player:getModData()

    pMod.AlbuminDoses   = 0
    pMod.VaccineRecess  = 0
    pMod.VaccineTime    = 0
    pMod.VaccineStrength= 0

    if body:isInfected() then
        -- TENTATIVA DE CURA IMEDIATA
        if vaccine.CureChance > ZombRand(100) then
            LabRecipes_CurePlayer(body)
        else
            local rate = LabRecipes_InfectionRate(player)
            if rate > vaccine.Min and rate <= vaccine.Max then
                -- Ajusta InfectionTime para "voltar" a uma fase mais inicial
                body:setInfectionTime(
                    player:getHoursSurvived() - vaccine.Min * body:getInfectionMortalityDuration()
                )
                -- Prepara sinergia com Albumina
                if vaccine.AlbuminMin > 0 then
                    pMod.AlbuminDoses = vaccine.AlbuminMin + ZombRand(vaccine.AlbuminDelta)
                end
                pMod.VaccineRecess = vaccine.Recess
            end
        end

    elseif vaccine.InfectChance > ZombRand(100) then
        -- Jogador NÃO estava infectado: chance de "acidente" e infecção
        body:setInfected(true)
        body:setInfectionMortalityDuration(body:pickMortalityDuration())
        body:setInfectionTime(player:getHoursSurvived())

    else
        -- VACINA PROFILÁTICA (sem infecção) → efeito retardado
        pMod.VaccineTime     = vaccine.Time
        pMod.VaccineStrength = vaccine.Strength
    end
end

-- EFEITOS CONTÍNUOS DA VACINA (chamado por Events)

function LabRecipes_AdjustPlayerHealth()
    local player = getPlayer()
    if not player then return end

    local body = player:getBodyDamage()
    local pMod = player:getModData()
    if not body or not pMod then return end

    if body:isInfected() then
        -- Recess delay (enquanto já infectado)
        if pMod.VaccineRecess and pMod.VaccineRecess > 0 and LabRecipes_InfectionRate(player) > 0.4 then
            pMod.VaccineRecess = pMod.VaccineRecess - 1
            body:setInfectionTime(
                body:getInfectionTime()
                + body:getInfectionMortalityDuration()
                  * LabRecipes_RandNorm(0, 30, 1.1, 0.35) / 100
            )
        end

        -- Tentativa de cura atrasada
        if pMod.VaccineTime and pMod.VaccineTime > 0 then
            pMod.VaccineTime = 0
            if pMod.VaccineStrength > ZombRand(100) then
                LabRecipes_CurePlayer(body)
            end
        end
    end

    -- Contagem decrescente de efeito
    if pMod.VaccineTime and pMod.VaccineTime > 0 then
        pMod.VaccineTime = pMod.VaccineTime - 1
    end
end

-- TIMED ACTION: INJEÇÃO DA VACINA/CURA
function LabActionInjectVaccine:isValid()
    return self.character
       and self.item
       and self.character:getInventory():contains(self.item)
end

function LabActionInjectVaccine:update()
    self.item:setJobDelta(self:getJobDelta())
end

function LabActionInjectVaccine:start()
    self.item:setJobType(getText("ContextMenu_Inject"))
    self.item:setJobDelta(0.0)
    self:setOverrideHandModels(nil, self.item)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.character:playSound("Pills_A")
end

function LabActionInjectVaccine:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
end

function LabActionInjectVaccine:perform()
    self.item:setJobDelta(0.0)

    local t    = self.item:getType()
    local data = vaccineEffect[t]

    if not data then
        print("[Lab] ERRO: sem dados para vacina/cura: " .. tostring(t))
        ISBaseTimedAction.perform(self)
        return
    end

    -- Usa A LÓGICA ORIGINAL CENTRALIZADA
    LabRecipes_DoInjection(self.character, data)

    -- Consome a seringa e troca por suja
    local inv = self.character:getInventory()

    if t:find("Reusable") then
        inv:AddItem("LabItems.LabSyringeReusableUsed")
    else
        inv:AddItem("LabItems.LabSyringeUsed")
    end

    self.item:Use()

    if LabRecipes_PrintTestInfo then
        LabRecipes_PrintTestInfo(self.character, nil)
    end

    ISBaseTimedAction.perform(self)
end

function LabActionInjectVaccine:new(character, item)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character   = character
    o.item        = item
    o.maxTime     = 120
    o.stopOnWalk  = false
    o.stopOnRun   = false
    return o
end
