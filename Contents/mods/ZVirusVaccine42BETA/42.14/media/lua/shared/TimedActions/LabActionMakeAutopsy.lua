-- LabActionMakeAutopsy_Client.lua
-- TimedAction para autopsia

require "TimedActions/ISBaseTimedAction"

local _sb = SandboxVars.ZombieVirusVaccineBETA or {}

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
    self.sound = self.character:getEmitter():playSound("Meat_A")
end

function LabActionMakeAutopsy:stop()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound)
        self.sound = nil
    end
    
    ISBaseTimedAction.stop(self)
end

function LabActionMakeAutopsy:perform()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound)
        self.sound = nil
    end
    
    ISBaseTimedAction.perform(self)
end

function LabActionMakeAutopsy:complete()
    local isOnTable = (self.top and self.bottom) and true or false
    
    local corpseId = nil
    if self.corpse then
        -- Tenta getOnlineID primeiro, depois getID
        if self.corpse.getOnlineID then
            local ok, id = pcall(function() return self.corpse:getOnlineID() end)
            if ok and id then
                corpseId = id
            end
        end
        
        -- Fallback para ID interno
        if not corpseId and self.corpse.getID then
            corpseId = self.corpse:getID()
        end
    end
    
    local corpseX, corpseY, corpseZ = nil, nil, nil
    
    if isOnTable then
        if self.top and self.top:getSquare() then
            corpseX = self.top:getSquare():getX()
            corpseY = self.top:getSquare():getY()
            corpseZ = self.top:getSquare():getZ()
        end
    else
        if self.corpse and self.corpse:getSquare() then
            corpseX = self.corpse:getSquare():getX()
            corpseY = self.corpse:getSquare():getY()
            corpseZ = self.corpse:getSquare():getZ()
        elseif self.square then
            corpseX = self.square:getX()
            corpseY = self.square:getY()
            corpseZ = self.square:getZ()
        end
    end

    -- Envia comando ao servidor
    sendClientCommand(
        self.character,
        "ZVirusVaccine42BETA",
        "MakeAutopsy",
        {
            isOnTable = isOnTable,
            corpseId = corpseId,
            topX = self.top and self.top:getSquare():getX(),
            topY = self.top and self.top:getSquare():getY(),
            topZ = self.top and self.top:getSquare():getZ(),
            corpseX = corpseX,
            corpseY = corpseY,
            corpseZ = corpseZ
        }
    )
    -- Marca o cadáver como autopsiado no cache local
    if not isServer() and corpseId and corpseX and corpseY and corpseZ then
        if LabModEngine and LabModEngine.autopsiedCorpsesCache then
            local corpseKey = string.format("%d_%d_%d_%d", corpseX, corpseY, corpseZ, corpseId)
            LabModEngine.autopsiedCorpsesCache[corpseKey] = true
        end
    end

    return true
end

function LabActionMakeAutopsy:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    
    -- Usar velocidade base do sandbox
    local time = _sb.AutopsySpeed or 1200

    -- Redução por nível de Primeiros Socorros
    local perk = self.character:getPerkLevel(Perks.Doctor)
    if perk > 1 then
        local reduction = _sb.TicksDecreasedByPerkLv or 30
        time = time - (perk - 1) * reduction
    end

    -- Bônus de profissão (Doctor = 15% mais rápido)
    if self.character:getDescriptor():getCharacterProfession() == CharacterProfession.DOCTOR then
        time = math.floor(time * 0.85)
    end

    -- Bônus da mesa de autópsia
    if self.top then
        -- TableSpeedBonus: enum 1-7, default 6 → (value-1)*10 = % de redução
        local bonusPercent = ((_sb.TableSpeedBonus or 6) - 1) * 10
        local multiplier = 1.0 - (bonusPercent / 100)
        time = math.floor(time * multiplier)
    end
    
    -- Penalidade para hemofóbicos
    if self.character:hasTrait(CharacterTrait.HEMOPHOBIC) then
        time = math.floor(time * 1.20)
    end
    
    -- Mod RLP
    if _G.RLPTraitEffects then
        time = _G.RLPTraitEffects.ModifyAutopsyDuration(self.character, time)
    end

    return math.max(1, time)
end

function LabActionMakeAutopsy:new(character, corpse, square, top, bottom)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    
    o.character = character
    o.corpse = corpse
    o.square = square
    o.top = top
    o.bottom = bottom
    
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    
    return o
end