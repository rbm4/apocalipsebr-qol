-- BloodTestLogic_Server.lua
-- Logica de teste de sangue (SERVER-ONLY)

local BloodTestLogic = {}
local LabSandboxOptions = require("Util/LabSandboxOptions")

function BloodTestLogic.ProcessTest(player, itemType)
    if not player then return end

    local inv = player:getInventory()
    if not inv then return end
    
    local syringeItem = inv:getItemFromType(itemType)
    if not syringeItem then return end
    
    local md = syringeItem:getModData()
    local isInfected = md.IsInfected
    local infectionRate = md.InfectionRate or 0

    local finalResult
    local rate = nil

    if isInfected == nil then
        finalResult = "InvalidSample"
        BloodTestLogic.ReplaceSyringe(player, itemType)
    else
        rate = math.floor(infectionRate * 100)

        if isInfected then
            local resultItem = inv:AddItem("LabItems.LabTestResultPositive")
            if resultItem then
                local scriptItem = ScriptManager.instance:getItem("LabItems.LabTestResultPositive")
                local baseName = Translator.getText(scriptItem:getDisplayName())
                local customName = baseName .. " (" .. tostring(rate) .. "%)"

                resultItem:setName(customName)
                resultItem:setCustomName(true)

                sendAddItemToContainer(inv, resultItem)
                resultItem:syncItemFields()
            end

            finalResult = "Positive"
        else
            local resultItem = inv:AddItem("LabItems.LabTestResultNegative")
            if resultItem then
                sendAddItemToContainer(inv, resultItem)
            end

            finalResult = "Negative"
        end

        BloodTestLogic.ReplaceSyringe(player, itemType)
    end

    -- FEEDBACK
    if isServer() then
        -- MP
        sendServerCommand(
            player,
            "ZVirusVaccine42BETA",
            "BloodTestFeedback",
            {
                result = finalResult,
                rate = rate
            }
        )
    else
        -- SP
        triggerEvent("OnLabBloodTestComplete", player, finalResult, rate)
    end

    if LabSandboxOptions.IsDebugMode() then
        print("BloodTest: " .. finalResult .. (rate and " " .. rate .. "%" or ""))
    end
    return finalResult
end

function BloodTestLogic.ReplaceSyringe(player, itemType)
    local inv = player:getInventory()
    
    local syringeToRemove = inv:getItemFromType(itemType)
    if syringeToRemove then
        player:removeFromHands(syringeToRemove)
        inv:Remove(syringeToRemove)
        sendRemoveItemFromContainer(inv, syringeToRemove)
    end
    
    local newType
    if itemType == "CmpSyringeReusableWithBlood" then
        newType = "LabItems.LabSyringeReusableUsed"
    else
        newType = "LabItems.LabSyringeUsed"
    end
    
    local newSyringe = inv:AddItem(newType)
    if newSyringe then
        sendAddItemToContainer(inv, newSyringe)
    end
end

return BloodTestLogic
