-- LabModRecipes_Server.lua

-- OnCreate Functions
function Lab_Recipes_ChmCollectInfectedBlood(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabTestTube")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("InfectedBlood", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
    end
end

function Lab_Recipes_OthClearWithChlorineTablets(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabFlask")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("PurifiedWater", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
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
            plasmaFlask:syncItemFields()
            sendItemStats(plasmaFlask)
            
            if isServer() then
                sendAddItemToContainer(inv, plasmaFlask)
            end
        end
    end

    local cellsFlask = inv:AddItem("LabItems.LabFlask")
    if cellsFlask then
        local fc2 = cellsFlask:getFluidContainer()
        if fc2 then
            fc2:Empty()
            fc2:addFluid("BloodCells", fc2:getCapacity())
            cellsFlask:syncItemFields()
            sendItemStats(cellsFlask)
            
            if isServer() then
                sendAddItemToContainer(inv, cellsFlask)
            end
        end
    end
end

function Lab_Recipes_ChmMixFlaskOfSodiumHypochlorite(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabFlask")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("SodiumHypochlorite", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
    end
end

function Lab_Recipes_ChmMixTestTubeOfSodiumHypochlorite(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabTestTube")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("SodiumHypochlorite", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
    end
end

function Lab_Recipes_ChmMixFlaskOfAmmoniumSulfate(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabFlask")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("AmmoniumSulfate", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
    end
end

function Lab_Recipes_ChmMixFlaskOfHydrogenPeroxide(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabFlask")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("HydrogenPeroxide", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
    end
end

function Lab_Recipes_ChmExtractAntibodiesFromLeukocytes(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabTestTube")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("Antibodies", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
    end
end

function Lab_Recipes_ChmExtractLeukocytesFromBloodCells(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabFlask")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("Leukocytes", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
    end
end

function Lab_Recipes_ChmExtractBrainFromSkull(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local roll = ZombRand(100)
    local chosen

    if roll < 50 then
        chosen = "LabItems.HumanBrainLow"
    elseif roll < 80 then
        chosen = "LabItems.HumanBrainMid"
    else
        chosen = "LabItems.HumanBrainHigh"
    end

    local newItem = inv:AddItem(chosen)

    if isServer() then
        sendAddItemToContainer(inv, newItem)
    end
end

function Lab_Recipes_Lab_Recipes_ChmAddTransferBrainFluidLow(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabTestTube")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("BrainFluidLow", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
    end
end

function Lab_Recipes_Lab_Recipes_ChmAddTransferBrainFluidMid(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabTestTube")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("BrainFluidMid", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
    end
end

function Lab_Recipes_Lab_Recipes_ChmAddTransferBrainFluidHigh(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabTestTube")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("BrainFluidHigh", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
    end
end

-- TEMPORARY FUNCTIONS
function Lab_Recipes_TradeOldItems3(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabFlask")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("BloodCells", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
    end
end

function Lab_Recipes_TradeOldItems4(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabFlask")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("BloodPlasma", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
    end
end

function Lab_Recipes_TradeOldItems2(recipeData, character)
    local inv = character:getInventory()
    if not inv then return end

    local newTube = inv:AddItem("LabItems.LabTestTube")
    local fc = newTube:getFluidContainer()

    fc:Empty()
    fc:addFluid("TaintedBlood", fc:getCapacity())
    
    newTube:syncItemFields()
    sendItemStats(newTube)
    
    if isServer() then
        sendAddItemToContainer(inv, newTube)
    end
end