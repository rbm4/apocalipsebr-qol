-- LabCollectBloodLogic_Server.lua
-- Logica de coleta de sangue (SERVER-ONLY)

local LabCollectBloodLogic = {}

local function InfectionRate(player)
    if not player then return 0 end
    
    local body = player:getBodyDamage()
    if not body then return 0 end
    if not body.isInfected then return 0 end
    
    local ok, isInf = pcall(function() return body:isInfected() end)
    if not ok or not isInf then return 0 end
    
    local deathTime = body:getInfectionMortalityDuration()
    if not deathTime or deathTime <= 0 then return 0 end
    
    return (player:getHoursSurvived() - body:getInfectionTime()) / deathTime
end

function LabCollectBloodLogic.ProcessCollection(player, itemType)
    if not player or not itemType then return end
    
    local body = player:getBodyDamage()
    if not body then return end
    
    local inv = player:getInventory()
    if not inv then return end
    
    local newType
    if itemType == "LabSyringeReusable" then
        newType = "LabItems.CmpSyringeReusableWithBlood"
    else
        newType = "LabItems.CmpSyringeWithBlood"
    end
    
    local newItem = inv:AddItem(newType)
    if newItem then
        sendAddItemToContainer(inv, newItem)
        
        local md = newItem:getModData()
        
        local isInfected = false
        if body.isInfected then
            local ok, result = pcall(function() return body:isInfected() end)
            if ok then isInfected = result end
        end
        
        md.IsInfected = isInfected
        md.InfectionRate = isInfected and InfectionRate(player) or 0
        
        if newItem.transmitModData then
            newItem:transmitModData()
        end
    end
    
    local syringeToRemove = inv:getItemFromType(itemType)
    if syringeToRemove then
        if player.removeFromHands then
            player:removeFromHands(syringeToRemove)
        end
        
        inv:Remove(syringeToRemove)
        sendRemoveItemFromContainer(inv, syringeToRemove)
    end
    
    local arm = body:getBodyPart(BodyPartType.ForeArm_R)
             or body:getBodyPart(BodyPartType.ForeArm_L)
    
    if arm then
        arm:setScratched(true, false)
        arm:setScratchTime(0.03)
        arm:setBleedingTime(0)
        player:getStats():add(CharacterStat.PAIN, 5)
    end
    
    local cotton = inv:FindAndReturn("AlcoholedCottonBalls")
    if cotton then
        inv:Remove(cotton)
        sendRemoveItemFromContainer(inv, cotton)
    end

    if isServer() then
        sendServerCommand(
            player,
            "ZVirusVaccine42BETA",
            "CollectBloodFeedback",
            {}
        )
    else
        triggerEvent("OnLabCollectBloodComplete", player)
    end
end

return LabCollectBloodLogic