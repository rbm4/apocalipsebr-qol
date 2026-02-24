-- LabAlbuminLogic_Server.lua
-- Logica de albumina (SERVER-ONLY)

local LabAlbuminLogic = {}

local albuminEff = {
    [1] = 2,
    [2] = 3,
    [3] = 5,
    [4] = 7,
    [5] = 9,
    [6] = 11,
    [7] = 12,
    [8] = 11,
    [9] = 9,
    [10] = 8,
}

local function InfectionRate(player)
    local body = player:getBodyDamage()
    if not body:isInfected() then return 0 end
    
    local deathTime = body:getInfectionMortalityDuration()
    if deathTime <= 0 then return 0 end
    
    return (player:getHoursSurvived() - body:getInfectionTime()) / deathTime
end

function LabAlbuminLogic.TakeAlbumin(player, pillsType)
    if not player or not pillsType then return end
    
    local body = player:getBodyDamage()
    local health = body:getOverallBodyHealth()
    local pMod = player:getModData()
    
    if health < 99 then
        local newHealth = math.min(100, health + 14)
        body:AddGeneralHealth(newHealth - health)
    end
    
    if body:isInfected() and pMod.AlbuminDoses and pMod.AlbuminDoses > 0 then
        local rate = math.ceil((InfectionRate(player) * 100 - 14) / 7)
        rate = math.max(1, math.min(10, rate))
        
        local eff = albuminEff[rate]
        if eff then
            body:setInfectionTime(
                body:getInfectionTime() +
                body:getInfectionMortalityDuration() * eff / 100
            )
        end
        
        pMod.AlbuminDoses = math.max(0, pMod.AlbuminDoses - 1)
    end

    local inv = player:getInventory()
    local pills = inv:getItemFromType(pillsType)
    
    -- correção no uso da albumina
    if pills then
        pills:Use() -- sincroniza nativamente o uso do item
    end
end

return LabAlbuminLogic