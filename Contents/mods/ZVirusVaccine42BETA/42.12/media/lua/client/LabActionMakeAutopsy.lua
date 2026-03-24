require "TimedActions/ISBaseTimedAction"

LabActionMakeAutopsy = ISBaseTimedAction:derive("LabActionMakeAutopsy")

function LabActionMakeAutopsy:isValid()
    return true
end

function LabActionMakeAutopsy:waitToStart()
    self.character:faceThisObject(self.corpse or self.bottom)
    return self.character:shouldBeTurning()
end

function LabActionMakeAutopsy:update()
    self.character:faceThisObject(self.corpse or self.bottom)
    self.character:setMetabolicTarget(Metabolics.MediumWork)
end

function LabActionMakeAutopsy:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", not self.corpse and "Mid" or "Low")
    self.character:playSound("Meat_A")
end

function LabActionMakeAutopsy:stop()
    ISBaseTimedAction.stop(self)
end

function LabActionMakeAutopsy:perform()

    -- Larga item da mão secundária
    self.character:removeFromHands(self.character:getSecondaryHandItem())

    local inv  = self.character:getInventory()
    local prof = self.character:getDescriptor():getProfession()
    local isIntern = (prof == "labintern")
    local said = false

    -- XP (mesa dá mais XP) + bônus de 20% para estagiário
    local xp = self.top and 25 or 10

    if isIntern then
        xp = xp * 1.20
    end

    self.character:getXp():AddXP(Perks.Doctor, xp)

    -- Marca no corpse
    if self.corpse then
        local md = self.corpse:getModData()
        md.Autopsy = true
    end

    -- AUTÓPSIA NA MESA
    if self.top and self.bottom then

        local sampleCount = isIntern and 6 or 3
        local hasInfected = false
        local hasTainted  = false

        for i = 1, sampleCount do
            if ZombRand(100) < 50 then
                inv:AddItem("LabItems.MatInfectedBlood")
                hasInfected = true
            else
                inv:AddItem("LabItems.MatTaintedBlood")
                hasTainted = true
            end
        end

        -- fala (apenas 1 por autópsia)
        if hasInfected then
            local key = "IGUI_PlayerText_AutopsyInfected" .. tostring(ZombRand(1,5))
            self.character:Say(getText(key))
        elseif hasTainted then
            local key = "IGUI_PlayerText_AutopsyTainted" .. tostring(ZombRand(1,5))
            self.character:Say(getText(key))
        end

        -- muda para remains
        Lab_MorgueTableSwap(self.top, self.bottom, "Remains")

    -- AUTÓPSIA NO CHÃO
    else
       if isIntern then

            -- ESTAGIÁRIO: 2 AMOSTRAS GARANTIDAS
            local gotInfected = false
            local gotTainted  = false

            for i = 1, 2 do
                if ZombRand(100) < 50 then
                    inv:AddItem("LabItems.MatInfectedBlood")
                    gotInfected = true
                else
                    inv:AddItem("LabItems.MatTaintedBlood")
                    gotTainted = true
                end
            end

             -- fala (apenas 1)
            if gotInfected then
                local key = "IGUI_PlayerText_AutopsyInfected" .. tostring(ZombRand(1,5))
                self.character:Say(getText(key))
            else
                local key = "IGUI_PlayerText_AutopsyTainted" .. tostring(ZombRand(1,5))
                self.character:Say(getText(key))
            end

            -- OUTRAS PROFISSÕES:
            -- INFECTADO
            if ZombRand(100) < 40 then
                inv:AddItem("LabItems.MatInfectedBlood")
                local key = "IGUI_PlayerText_AutopsyInfected" .. tostring(ZombRand(1,5))
                self.character:Say(getText(key))
                said = true

            -- TAINTED
            elseif ZombRand(100) < 60 then
                inv:AddItem("LabItems.MatTaintedBlood")
                local key = "IGUI_PlayerText_AutopsyTainted" .. tostring(ZombRand(1,5))
                self.character:Say(getText(key))
                said = true
            end

            -- NADA
            if not said then
                local key = "IGUI_PlayerText_AutopsyNothing" .. tostring(ZombRand(1,5))
                self.character:Say(getText(key))
            end
        end
    end

    -- Hemofóbico
    if self.character:HasTrait("Hemophobic") then
        local stats = self.character:getStats()
        stats:setPanic(stats:getPanic() + 20)
    end

    -- sangue no chão
    addBloodSplat(self.character:getCurrentSquare(), ZombRand(20))

    LabRecipes_PrintTestInfo(self.character, self.corpse)

    ISBaseTimedAction.perform(self)
end

function LabActionMakeAutopsy:new(character, corpse, square, top, bottom)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.corpse    = corpse
    o.square    = square
    o.top       = top
    o.bottom    = bottom

    --   PROFISSÕES
    o.isDoctor    = character:getDescriptor():getProfession() == "profession_doctor2"
    o.isLabIntern = character:getDescriptor():getProfession() == "labintern"

    -- 1200 ticks = 20 segundos
    o.maxTime = 1200

    --   REDUÇÃO PELO PERK DOCTOR
    o.maxTime = o.maxTime - (character:getPerkLevel(Perks.Doctor) - 1) * 30

    -- PROFISSÃO: MÉDICO: Pequeno bônus
    if o.isDoctor then
        o.maxTime = o.maxTime - 100
    end

    -- PROFISSÃO: ESTAGIÁRIO DO LABORATÓRIO: Faz autópsias 2× mais rápido
    if o.isLabIntern then
        o.maxTime = math.floor(o.maxTime * 0.6)
    end

    --  SE FEITA NA MESA REDUZ O TEMPO
    if top then
        o.maxTime = math.floor(o.maxTime * 0.7)
    end

     --PENALIDADE DE HEMOFOBIA: +20% TEMPO
    if character:HasTrait("Hemophobic") then
        o.maxTime = math.floor(o.maxTime * 1.20)
    end

    o.stopOnWalk = true
    o.stopOnRun  = true
    return o
end