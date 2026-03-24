-- LabModRecipes_Server.lua
local LabModRecipes = {}
local LabSandboxOptions = require("Util/LabSandboxOptions")

-- OnCreate Functions
function Lab_Recipes_ChmCollectInfectedBlood(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabTestTube")
    if not newTube then return end
    local fc = newTube:getFluidContainer()
    if not fc then return end

    fc:Empty()
    fc:addFluid("InfectedBlood", fc:getCapacity())

    sendAddItemToContainer(inv, newTube)
    if isServer() then
        newTube:syncItemFields()
    end
end

function Lab_Recipes_OthClearWithChlorineTablets(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabFlask")
    if not newTube then return end
    local fc = newTube:getFluidContainer()
    if not fc then return end

    fc:Empty()
    fc:addFluid("PurifiedWater", fc:getCapacity())

    sendAddItemToContainer(inv, newTube)
    if isServer() then
        newTube:syncItemFields()
    end
end

function Lab_Recipes_DivideBloodIntoComponents(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local plasmaFlask = inv:AddItem("LabItems.LabFlask")
    if plasmaFlask then
        local fc1 = plasmaFlask:getFluidContainer()
        if fc1 then
            fc1:Empty()
            fc1:addFluid("BloodPlasma", fc1:getCapacity())
            sendAddItemToContainer(inv, plasmaFlask)
            if isServer() then
                plasmaFlask:syncItemFields()
            end
        end
    end

    local cellsFlask = inv:AddItem("LabItems.LabFlask")
    if cellsFlask then
        local fc2 = cellsFlask:getFluidContainer()
        if fc2 then
            fc2:Empty()
            fc2:addFluid("BloodCells", fc2:getCapacity())
            sendAddItemToContainer(inv, cellsFlask)
            if isServer() then
                cellsFlask:syncItemFields()
            end
        end
    end
end

function Lab_Recipes_ChmMixFlaskOfSodiumHypochlorite(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabFlask")
    if not newTube then return end
    local fc = newTube:getFluidContainer()
    if not fc then return end

    fc:Empty()
    fc:addFluid("SodiumHypochlorite", fc:getCapacity())

    sendAddItemToContainer(inv, newTube)
    if isServer() then
        newTube:syncItemFields()
    end
end

function Lab_Recipes_ChmMixFlaskOfAmmoniumSulfate(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabFlask")
    if not newTube then return end
    local fc = newTube:getFluidContainer()
    if not fc then return end

    fc:Empty()
    fc:addFluid("AmmoniumSulfate", fc:getCapacity())

    sendAddItemToContainer(inv, newTube)
    if isServer() then
        newTube:syncItemFields()
    end
end

function Lab_Recipes_ChmMixFlaskOfHydrogenPeroxide(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabFlask")
    if not newTube then return end
    local fc = newTube:getFluidContainer()
    if not fc then return end

    fc:Empty()
    fc:addFluid("HydrogenPeroxide", fc:getCapacity())

    sendAddItemToContainer(inv, newTube)
    if isServer() then
        newTube:syncItemFields()
    end
end

function Lab_Recipes_ChmExtractAntibodiesFromLeukocytes(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabTestTube")
    if not newTube then return end
    local fc = newTube:getFluidContainer()
    if not fc then return end

    fc:Empty()
    fc:addFluid("Antibodies", fc:getCapacity())

    sendAddItemToContainer(inv, newTube)
    if isServer() then
        newTube:syncItemFields()
    end
end

function Lab_Recipes_ChmExtractLeukocytesFromBloodCells(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabFlask")
    if not newTube then return end
    local fc = newTube:getFluidContainer()
    if not fc then return end

    fc:Empty()
    fc:addFluid("Leukocytes", fc:getCapacity())

    sendAddItemToContainer(inv, newTube)
    if isServer() then
        newTube:syncItemFields()
    end
end

function Lab_Recipes_ChmExtractBrainFromSkull(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local butchering = character:getPerkLevel(Perks.Butchering)
    local firstAid   = character:getPerkLevel(Perks.Doctor)

    local skillScore = (butchering * 2) + (firstAid * 2)

    local prof     = character:getDescriptor():getCharacterProfession()
    local isDoctor = (prof == CharacterProfession.DOCTOR)
    local isIntern = _G.RLPTraitEffects and character:hasTrait(RLP.CharacterTrait.AUTOPSY_SPECIALIST) or false

    local profBonus = 0
    if isIntern then
        profBonus = 30
    elseif isDoctor then
        profBonus = 18
    end

    local hemophobicDebuff = 0
    if character:hasTrait(CharacterTrait.HEMOPHOBIC) then
        hemophobicDebuff = -LabSandboxOptions.GetHemophobicDebuff()
    end

    local SQ = math.max(0, skillScore + profBonus + hemophobicDebuff)

    local SQ_MAX, ceiling
    if isIntern then
        SQ_MAX  = 70
        ceiling = 50
    elseif isDoctor then
        SQ_MAX  = 58
        ceiling = 40
    else
        SQ_MAX  = 40
        ceiling = 30
    end

    if Perks.Science then
        local scienceLevel = character:getPerkLevel(Perks.Science)
        if scienceLevel > 0 then
            local scienceBonus = math.min(scienceLevel * 0.5, 5)
            ceiling = ceiling + scienceBonus
        end
    end

    local t            = math.min(SQ / SQ_MAX, 1.0)
    local offset       = LabSandboxOptions.GetBrainHighOffset()
    local chanceHigh   = offset + (t ^ 1.2) * (ceiling - offset)
    local remaining    = 100 - chanceHigh
    local midRatio     = 0.33 + (t ^ 0.8) * (0.57 - 0.33)
    local chanceMedium = remaining * midRatio
    local chanceLow    = remaining * (1 - midRatio)

    local roll   = ZombRand(1000) / 10
    local chosen

    if roll < chanceHigh then
        chosen = "LabItems.HumanBrainHigh"
    elseif roll < (chanceHigh + chanceMedium) then
        chosen = "LabItems.HumanBrainMid"
    else
        chosen = "LabItems.HumanBrainLow"
    end

    local newItem = inv:AddItem(chosen)
    if newItem then
        sendAddItemToContainer(inv, newItem)
    end

    local baseXp = LabSandboxOptions.GetCollectPartXP()

    local brainXpMultiplier = {
        ["LabItems.HumanBrainHigh"] = 1.0,
        ["LabItems.HumanBrainMid"]  = 0.6,
        ["LabItems.HumanBrainLow"]  = 0.3,
    }

    local xpMult       = brainXpMultiplier[chosen]
    local xpButchering = baseXp * xpMult
    local xpDoctor     = math.floor(xpButchering * 0.5)

    addXp(character, Perks.Butchering, xpButchering)
    addXp(character, Perks.Doctor,     xpDoctor)
end

return LabModRecipes
