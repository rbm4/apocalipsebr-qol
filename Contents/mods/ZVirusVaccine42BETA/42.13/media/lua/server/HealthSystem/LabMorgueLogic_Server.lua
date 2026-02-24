-- LabMorgueLogic_Server.lua
-- Logica das ações de morgue (SERVER-ONLY)

local LabMorgueLogic = {}
local LabSpriteSynchHandler = require("HealthSystem/LabSpriteSynchHandler_Server")

local _sb = SandboxVars.ZombieVirusVaccineBETA or {}

local function DispatchMorgueFeedback(player, action)
    if not player or not action then return end

    if isServer() then
        sendServerCommand(
            player,
            "ZVirusVaccine42BETA",
            "MorgueFeedback",
            { action = action }
        )
    else
        triggerEvent("OnLabMorgueAction", player, action)
    end
end

local function RemoveCorpseFromWorld(corpseSquare, corpseX, corpseY, corpseZ)
    if not corpseSquare then return false end
    
    local bodies = corpseSquare:getDeadBodys()
    
    if not bodies or bodies:size() == 0 then
        return false
    end
    
    local corpse = bodies:get(0)
    
    if isServer() then
        corpseSquare:removeCorpse(corpse, false)
        corpseSquare:transmitRemoveItemFromSquare(corpse)
        corpseSquare:RecalcAllWithNeighbours(true)
    else
        corpse:removeFromWorld()
        corpse:removeFromSquare()
    end
    
    return true
end

function LabMorgueLogic.PutCorpseOnTable(player, args)
    if not player or not args then return end
    
    local cell = getCell()
    if not cell then return end
    
    local topSquare = cell:getGridSquare(args.topX, args.topY, args.topZ)
    if not topSquare then return end
    
    local top, bottom = nil, nil
    local objs = topSquare:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if instanceof(obj, "IsoThumpable") then
            top, bottom = LabRecipes_GetBedObjects(obj, morgueTable)
            if top and bottom then break end
        end
    end
    
    if not top or not bottom then return end
    
    local deathTime = args.deathTime
    
    if not deathTime or deathTime == 0 or type(deathTime) ~= "number" then
        deathTime = getGameTime():getWorldAgeHours()
    end
    
    local md = top:getModData()
    md.Zombie = args.isZombie or false
    md.Skeleton = args.isSkeleton or false
    md.Autopsy = args.wasAutopsied or false
    md.deathTime = deathTime
    md.DeathTime = deathTime
    
    top:transmitModData()
    
    local corpseSquare = cell:getGridSquare(args.corpseX, args.corpseY, args.corpseZ)
    RemoveCorpseFromWorld(corpseSquare, args.corpseX, args.corpseY, args.corpseZ)
    
    LabSpriteSynchHandler.MorgueTableSwap(top, bottom, "Corpse")
    
    DispatchMorgueFeedback(player, "CorpsePlaced")
end

function LabMorgueLogic.GetRemains(player, args)
    if not player or not args then return end
    
    local inv = player:getInventory()
    local result = "NoContainer"
    local itemAdded = nil
    
    if args.hasSack then
        local sack = inv:getFirstTypeRecurse("Garbagebag")
                    or inv:getFirstTypeRecurse("Bag_TrashBag")
        if sack then
            inv:Remove(sack)
            sendRemoveItemFromContainer(inv, sack)
            
            itemAdded = inv:AddItem("LabItems.LabGarbageBagWithRemains")
            if itemAdded then
                sendAddItemToContainer(inv, itemAdded)
            end
            
            result = "Success"
        end
        
    elseif args.hasTwoPlastics then
        local plasticList = inv:getItemsFromType("Plasticbag")
                            or inv:getItemsFromType("Plasticbag_Bags")
                            or inv:getItemsFromType("Plasticbag_Clothing")
        if plasticList and plasticList:size() >= 2 then
            local removed1 = plasticList:get(0)
            inv:Remove(removed1)
            sendRemoveItemFromContainer(inv, removed1)
            
            local removed2 = plasticList:get(1)
            inv:Remove(removed2)
            sendRemoveItemFromContainer(inv, removed2)
            
            itemAdded = inv:AddItem("LabItems.LabPlasticBagWithRemains")
            local newB = inv:AddItem("LabItems.LabPlasticBagWithRemains")
            
            if itemAdded then sendAddItemToContainer(inv, itemAdded) end
            if newB then sendAddItemToContainer(inv, newB) end
            
            result = "Success"
        end
    end
    
    if itemAdded and result == "Success" then
        player:setPrimaryHandItem(itemAdded)
        player:setSecondaryHandItem(nil)
        triggerEvent("OnRefreshInventoryWindowContainers", player)
    end
    
    local cell = getCell()
    local topSquare = cell:getGridSquare(args.topX, args.topY, args.topZ)
    
    if topSquare then
        local objs = topSquare:getObjects()
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            if instanceof(obj, "IsoThumpable") then
                local top, bottom = LabRecipes_GetBedObjects(obj, morgueTable)
                if top and bottom then
                    LabSpriteSynchHandler.MorgueTableSwap(top, bottom, "Dirty")
                    break
                end
            end
        end
    end
    
    DispatchMorgueFeedback(player, result)
end

function LabMorgueLogic.RemoveCorpseFromTable(player, args)
    if not player or not args then return end
    
    local inv = player:getInventory()
    local result = "NoContainer"
    local itemAdded = nil
    
    if args.hasSack then
        local sack = inv:getFirstTypeRecurse("Garbagebag")
                    or inv:getFirstTypeRecurse("Bag_TrashBag")
        if sack then
            inv:Remove(sack)
            sendRemoveItemFromContainer(inv, sack)
            
            itemAdded = inv:AddItem("LabItems.LabGarbageBagWithRemains")
            if itemAdded then
                sendAddItemToContainer(inv, itemAdded)
            end
            
            result = "Success"
        end
        
    elseif args.hasTwoPlastics then
        local plasticList = inv:getItemsFromType("Plasticbag")
                            or inv:getItemsFromType("Plasticbag_Bags")
                            or inv:getItemsFromType("Plasticbag_Clothing")
        if plasticList and plasticList:size() >= 2 then
            local removed1 = plasticList:get(0)
            inv:Remove(removed1)
            sendRemoveItemFromContainer(inv, removed1)
            
            local removed2 = plasticList:get(1)
            inv:Remove(removed2)
            sendRemoveItemFromContainer(inv, removed2)
            
            itemAdded = inv:AddItem("LabItems.LabPlasticBagWithRemains")
            local newB = inv:AddItem("LabItems.LabPlasticBagWithRemains")
            
            if itemAdded then sendAddItemToContainer(inv, itemAdded) end
            if newB then sendAddItemToContainer(inv, newB) end
            
            result = "Success"
        end
    end
    
    if itemAdded and result == "Success" then
        player:setPrimaryHandItem(itemAdded)
        player:setSecondaryHandItem(nil)
        triggerEvent("OnRefreshInventoryWindowContainers", player)
    end
    
    local cell = getCell()
    local topSquare = cell:getGridSquare(args.topX, args.topY, args.topZ)
    
    if topSquare then
        local objs = topSquare:getObjects()
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            if instanceof(obj, "IsoThumpable") then
                local top, bottom = LabRecipes_GetBedObjects(obj, morgueTable)
                if top and bottom then
                    local md = top:getModData()
                    md.Zombie = nil
                    md.Skeleton = nil
                    md.Autopsy = nil
                    md.deathTime = nil
                    md.DeathTime = nil
                    top:transmitModData()
                    
                    LabSpriteSynchHandler.MorgueTableSwap(top, bottom, "Dirty")
                    break
                end
            end
        end
    end
    
    DispatchMorgueFeedback(
        player,
        result == "Success" and "CorpseRemoved" or result
    )
end

function LabMorgueLogic.ClearTable(player, args)
    if not player or not args then return end
    
    if args.bleachType then
        local inv = player:getInventory()
        local bleach = inv:getFirstTypeRecurse(args.bleachType)
        
        if bleach and bleach:getFluidContainer() then
            local fc = bleach:getFluidContainer()
            fc:removeFluid(0.2, false)
            syncItemFields(player, bleach)
        end
    end
    
    local cell = getCell()
    local topSquare = cell:getGridSquare(args.topX, args.topY, args.topZ)
    
    if topSquare then
        local objs = topSquare:getObjects()
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            if instanceof(obj, "IsoThumpable") then
                local top, bottom = LabRecipes_GetBedObjects(obj, morgueTable)
                if top and bottom then
                    LabSpriteSynchHandler.MorgueTableSwap(top, bottom, "Empty")
                    break
                end
            end
        end
    end
    
   DispatchMorgueFeedback(player, "TableCleaned")
end

function LabMorgueLogic.CollectBodyPart(player, args)
    if not player or not args then return end
    
    local inv = player:getInventory()
    local result = "NoContainer"
    local bagAdded = nil
    
    local finalItemType = args.itemType
    
    if finalItemType == "RANDOM_BRAIN" then
        local roll = ZombRand(100)
        if roll < 50 then
            finalItemType = "LabItems.HumanBrainLow"
        elseif roll < 80 then
            finalItemType = "LabItems.HumanBrainMid"
        else
            finalItemType = "LabItems.HumanBrainHigh"
        end
    end
    
    -- Usar e desgastar ferramentas conforme sandbox
    if _sb.AllowScalpelDegrade == true then
        local scalpel = inv:getFirstTypeRecurse("Scalpel")
        if scalpel then
            scalpel:setCondition(scalpel:getCondition() - 1)
            if scalpel:getCondition() <= 0 then
                inv:Remove(scalpel)
                sendRemoveItemFromContainer(inv, scalpel)
            else
                syncItemFields(player, scalpel)
            end
        end
    end
    
    if _sb.AllowSawDegrade ~= false then
        local saw = inv:getFirstTypeRecurse("Saw")
        if saw then
            saw:setCondition(saw:getCondition() - 1)
            if saw:getCondition() <= 0 then
                inv:Remove(saw)
                sendRemoveItemFromContainer(inv, saw)
            else
                syncItemFields(player, saw)
            end
        end
    end
    
    if args.hasSack then
        local sack = inv:getFirstTypeRecurse("Garbagebag")
                    or inv:getFirstTypeRecurse("Bag_TrashBag")
        if sack then
            inv:Remove(sack)
            sendRemoveItemFromContainer(inv, sack)
            
            bagAdded = inv:AddItem("LabItems.LabGarbageBagWithRemains")
            if bagAdded then
                sendAddItemToContainer(inv, bagAdded)
            end
            
            local bodyPart = inv:AddItem(finalItemType)
            if bodyPart then
                sendAddItemToContainer(inv, bodyPart)
            end
            
            result = "Success"
        end
        
    elseif args.hasTwoPlastics then
        local plasticList = inv:getItemsFromType("Plasticbag")
                            or inv:getItemsFromType("Plasticbag_Bags")
                            or inv:getItemsFromType("Plasticbag_Clothing")
        if plasticList and plasticList:size() >= 2 then
            local removed1 = plasticList:get(0)
            inv:Remove(removed1)
            sendRemoveItemFromContainer(inv, removed1)
            
            local removed2 = plasticList:get(1)
            inv:Remove(removed2)
            sendRemoveItemFromContainer(inv, removed2)
            
            bagAdded = inv:AddItem("LabItems.LabPlasticBagWithRemains")
            local bagB = inv:AddItem("LabItems.LabPlasticBagWithRemains")
            
            if bagAdded then sendAddItemToContainer(inv, bagAdded) end
            if bagB then sendAddItemToContainer(inv, bagB) end
            
            local bodyPart = inv:AddItem(finalItemType)
            if bodyPart then
                sendAddItemToContainer(inv, bodyPart)
            end
            
            result = "Success"
        end
    end
    
    if bagAdded and result == "Success" then
        player:setPrimaryHandItem(bagAdded)
        player:setSecondaryHandItem(nil)
        triggerEvent("OnRefreshInventoryWindowContainers", player)
    end
    
    local playerSquare = player:getCurrentSquare()
    if playerSquare then
        addBloodSplat(playerSquare, ZombRand(15))
    end
    
    -- Trocar sprite da mesa para "Dirty"
    local cell = getCell()
    local topSquare = cell:getGridSquare(args.topX, args.topY, args.topZ)
    
    if topSquare then
        local objs = topSquare:getObjects()
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            if instanceof(obj, "IsoThumpable") then
                local top, bottom = LabRecipes_GetBedObjects(obj, morgueTable)
                if top and bottom then
                    LabSpriteSynchHandler.MorgueTableSwap(top, bottom, "Dirty")
                    break
                end
            end
        end
    end
    
    -- Enviar feedback ao cliente
    DispatchMorgueFeedback(
        player,
        result == "Success" and "BodyPartCollected" or result
    )
end

return LabMorgueLogic