-- LabMorgueLogic_Server.lua
-- Logica das ações de necropsia (SERVER)

local LabMorgueLogic = {}
local LabSpriteSynchHandler = require("HealthSystem/LabSpriteSynchHandler_Server")
local LabSandboxOptions = require("Util/LabSandboxOptions")

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
        local sack = LabRecipes_GetFirstEquip(inv, LabConst.SACKS)
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
        local plastics = LabRecipes_CollectItemsFromList(inv, LabConst.PLASTICS, 2)
        if plastics then
            for _, p in ipairs(plastics) do
                inv:Remove(p)
                sendRemoveItemFromContainer(inv, p)
            end
            
            itemAdded = inv:AddItem("LabItems.LabPlasticBagWithRemains")
            local newB = inv:AddItem("LabItems.LabPlasticBagWithRemains")
            
            if itemAdded then sendAddItemToContainer(inv, itemAdded) end
            if newB then sendAddItemToContainer(inv, newB) end
            
            result = "Success"
        end
    end
    
    if itemAdded and result == "Success" then
        player:setPrimaryHandItem(itemAdded)
        player:setSecondaryHandItem(newB)
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
        local sack = LabRecipes_GetFirstEquip(inv, LabConst.SACKS)
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
        local plastics = LabRecipes_CollectItemsFromList(inv, LabConst.PLASTICS, 2)
        if plastics then
            for _, p in ipairs(plastics) do
                inv:Remove(p)
                sendRemoveItemFromContainer(inv, p)
            end
            
            itemAdded = inv:AddItem("LabItems.LabPlasticBagWithRemains")
            local newB = inv:AddItem("LabItems.LabPlasticBagWithRemains")
            
            if itemAdded then sendAddItemToContainer(inv, itemAdded) end
            if newB then sendAddItemToContainer(inv, newB) end
            
            result = "Success"
        end
    end
    
    if itemAdded and result == "Success" then
        player:setPrimaryHandItem(itemAdded)
        player:setSecondaryHandItem(newB)
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
        -- ======================================================
        -- PROBABILIDADE DINÂMICA DE QUALIDADE DO CÉREBRO
        -- ======================================================
        local butchering = player:getPerkLevel(Perks.Butchering)  -- 0~10
        local firstAid   = player:getPerkLevel(Perks.Doctor)      -- 0~10

        local skillScore = (butchering * 2) + (firstAid * 2)      -- Máx: 40

        -- Profissão e trait são mutuamente exclusivos:
        local prof          = player:getDescriptor():getCharacterProfession()
        local isDoctor      = (prof == CharacterProfession.DOCTOR)
        local isIntern      = RLP and RLP.CharacterTrait and RLP.CharacterTrait.AUTOPSY_SPECIALIST and player:hasTrait(RLP.CharacterTrait.AUTOPSY_SPECIALIST) or false

        local profBonus = 0
        if isIntern then
            profBonus = 30
        elseif isDoctor then
            profBonus = 18
        end

        -- Hemofóbico penaliza independente da profissão
        local hemophobicDebuff = 0
        if player:hasTrait(CharacterTrait.HEMOPHOBIC) then
            hemophobicDebuff = -LabSandboxOptions.GetHemophobicDebuff()
        end

        local SQ = math.max(0, skillScore + profBonus + hemophobicDebuff)

        -- SQ_MAX e teto de High% são definidos por profissão
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

		-- ==========================================
		-- Science bonus: +0.5% por nível (máx +5%)
		-- ==========================================
		if Perks.Science then
			local scienceLevel = player:getPerkLevel(Perks.Science) -- it's ssssssccccccccciiiiiieeeeeeence, biiiiitch!
			if scienceLevel > 0 then
				local scienceBonus = math.min(scienceLevel * 0.5, 5) -- Máx +5%. Maybe increase this later. I need to play first to see how it feels.
				ceiling = ceiling + scienceBonus
			end
		end
		
        local t = math.min(SQ / SQ_MAX, 1.0)

        local offset     = LabSandboxOptions.GetBrainHighOffset()
        local chanceHigh = offset + (t ^ 1.2) * (ceiling - offset)
        local remaining  = 100 - chanceHigh

        -- Mid e Low dividem o espaço restante proporcionalmente
        local midRatio     = 0.33 + (t ^ 0.8) * (0.57 - 0.33)
        local chanceMedium = remaining * midRatio
        local chanceLow    = remaining * (1 - midRatio)
        local roll = ZombRand(1000) / 10  -- Precisão de 0.1%

        if roll < chanceHigh then
            finalItemType = "LabItems.HumanBrainHigh"
        elseif roll < (chanceHigh + chanceMedium) then
            finalItemType = "LabItems.HumanBrainMid"
        else
            finalItemType = "LabItems.HumanBrainLow"
        end
		
        if LabSandboxOptions.IsDebugMode() then -- só porque eu quis
			local finalItemName = "Unknown Brain Quality"

            if finalItemType == "LabItems.HumanBrainLow" then
                finalItemName = "Low Quality Brain"

                elseif finalItemType == "LabItems.HumanBrainMid" then
                    finalItemName = "Medium Quality Brain"

                elseif finalItemType == "LabItems.HumanBrainHigh" then
                    finalItemName = "Perfect Extracted Brain"
            end
            
            if LabSandboxOptions.IsDebugMode() then
                print("========== BRAIN QUALITY DEBUG ==========")
                print("Butchering     :", butchering)
                print("First Aid      :", firstAid)
                print("Skill Score    :", skillScore)
                print("Prof Bonus     :", profBonus, "(Doctor:", isDoctor, "/ Intern:", isIntern, ")")
                print("Hemophobic     :", hemophobicDebuff ~= 0)
                print("SQ Final       :", SQ)
                print("t (normalized) :", string.format("%.3f", t))
                print("Chance High    :", string.format("%.1f%%", chanceHigh))
                print("Chance Medium  :", string.format("%.1f%%", chanceMedium))
                print("Chance Low     :", string.format("%.1f%%", chanceLow))
                print("Roll           :", roll)
                print("Brain Result   :", finalItemName)
                print("==========================================")
            end
        end
    end
    
    if LabSandboxOptions.IsScalpelDegradeAllowed() then
        local scalpel = inv:getFirstTypeRecurse("Scalpel")
        if scalpel then
            scalpel:setCondition(scalpel:getCondition() - 1)
            if scalpel:getCondition() <= 0 then
                inv:Remove(scalpel)
                sendRemoveItemFromContainer(inv, scalpel)
            else
                scalpel:syncItemFields()
            end
        end
    end
    
    if LabSandboxOptions.IsSawDegradeAllowed() then
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
        local sack = LabRecipes_GetFirstEquip(inv, LabConst.SACKS)
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
        local plastics = LabRecipes_CollectItemsFromList(inv, LabConst.PLASTICS, 2)
        if plastics then
            for _, p in ipairs(plastics) do
                inv:Remove(p)
                sendRemoveItemFromContainer(inv, p)
            end
            
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

        -- XP variável por qualidade do cérebro coletado
        local baseXp = LabSandboxOptions.GetCollectPartXP()

        local brainXpMultiplier = {
            ["LabItems.HumanBrainHigh"] = 1.5, -- +50%
            ["LabItems.HumanBrainMid"]  = 1.2, -- +20%
            ["LabItems.HumanBrainLow"]  = 0.5, -- 1/2
        }

        local isBrain = brainXpMultiplier[finalItemType] ~= nil

        if isBrain then
            -- Cérebro: XP de Butchering e Doctor, variável por qualidade
            local xpMult       = brainXpMultiplier[finalItemType]
            local xpButchering = baseXp * xpMult
            local xpDoctor     = math.floor(xpButchering * 0.5)

            addXp(player, Perks.Butchering, xpButchering)
            addXp(player, Perks.Doctor,     xpDoctor)
            if LabSandboxOptions.IsDebugMode() then
                print(string.format("Granted XP - Butchering: %.1f, Doctor: %d (multiplier: %.1f)", xpButchering, xpDoctor, xpMult))
            end
        else
            -- Outra parte: só Butchering
            addXp(player, Perks.Butchering, baseXp)
            if LabSandboxOptions.IsDebugMode() then
                print(string.format("Granted XP - Butchering: %.1f (non-brain part)", baseXp))
            end
        end
    end
    
    local playerSquare = player:getCurrentSquare()
    if playerSquare then
        addBloodSplat(playerSquare, ZombRand(15))
    end

    if player:hasTrait(CharacterTrait.HEMOPHOBIC) then
        player:getStats():add(CharacterStat.PANIC, 25)
        syncPlayerStats(player, 0x00000100)
    end
        
    -- Troca sprite da mesa para "Dirty"
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
    
    -- Envia feedback ao cliente
    DispatchMorgueFeedback(
        player,
        result == "Success" and "BodyPartCollected" or result
    )
end

return LabMorgueLogic
