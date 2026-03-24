-- LabAutopsyLogic_Server.lua
-- Logica de autopsia (SERVER-SIDE)

local LabAutopsyLogic = {}
local LabSpriteSynchHandler = require("HealthSystem/LabSpriteSynchHandler_Server")
local LabSandboxOptions = require("Util/LabSandboxOptions")

local function MarkCorpseAsAutopsied(corpseX, corpseY, corpseZ, corpseId)
    if not corpseX or not corpseY or not corpseZ then
        return false
    end

    local cell = getCell()
    if not cell then
        return false
    end

    local square = cell:getGridSquare(corpseX, corpseY, corpseZ)
    if not square then
        return false
    end

    local bodies = square:getDeadBodys()
    if not bodies or bodies:size() == 0 then
        return false
    end

    local targetCorpse = nil

    -- Seleção por corpseId
    if corpseId then
        for i = 0, bodies:size() - 1 do
            local body = bodies:get(i)
            
            -- Tenta getOnlineID primeiro (MP)
            if body and body.getOnlineID then
                local ok, id = pcall(function() return body:getOnlineID() end)
                if ok and id == corpseId then
                    targetCorpse = body
                    break
                end
            end
            
            -- Fallback para getID (SP)
            if not targetCorpse and body and body.getID then
                local id = body:getID()
                if id == corpseId then
                    targetCorpse = body
                    break
                end
            end
        end
    else
        -- Fallback: pega o mais recente
        if bodies:size() > 0 then
            targetCorpse = bodies:get(bodies:size() - 1)
        end
    end

    if not targetCorpse then
        return false
    end

    -- Marca como autopsiado
    local md = targetCorpse:getModData()
    md.Autopsy = true

    -- Replica para clientes
    if isServer() and targetCorpse.transmitModData then
        targetCorpse:transmitModData()
    end
    
    -- Broadcast para todos os clientes conectados
    if isServer() then
        local corpseKey = corpseId
            and string.format("%d_%d_%d_%d", corpseX, corpseY, corpseZ, corpseId)
            or string.format("%d_%d_%d", corpseX, corpseY, corpseZ)
        
        local players = getOnlinePlayers()
        if players and players:size() > 0 then
            for i = 0, players:size() - 1 do
                local player = players:get(i)
                if player then
                    sendServerCommand(
                        player,
                        "ZVirusVaccine42BETA",
                        "CorpseAutopsied",
                        { corpseKey = corpseKey }
                    )
                end
            end
        end
    end

    return true
end

function LabAutopsyLogic.ProcessAutopsy(player, isOnTable, corpseId, topX, topY, topZ, corpseX, corpseY, corpseZ)
    if not player then
        return nil
    end

    local cell = getCell()
    local targetCorpse = nil
    local alreadyAutopsied = false

    local inv = player:getInventory()
    local finalResult = "Nothing"

    -- LOCALIZA O CORPO (SE FOR NO CHÃO)
    if not isOnTable and corpseX and corpseY and corpseZ and cell then
        local square = cell:getGridSquare(corpseX, corpseY, corpseZ)
        if square then
            local bodies = square:getDeadBodys()
            if bodies and bodies:size() > 0 then

                if corpseId then
                    for i = 0, bodies:size() - 1 do
                        local body = bodies:get(i)

                        if body and body.getOnlineID then
                            local ok, id = pcall(function()
                                return body:getOnlineID()
                            end)

                            if ok and id == corpseId then
                                targetCorpse = body
                                break
                            end
                        end

                        if not targetCorpse and body and body.getID then
                            if body:getID() == corpseId then
                                targetCorpse = body
                                break
                            end
                        end
                    end
                else
                    targetCorpse = bodies:get(bodies:size() - 1)
                end

                if targetCorpse then
                    local md = targetCorpse:getModData()

                    -- Só considera "AlreadyAutopsied" se recompensa já foi concedida
                    if md and md.AutopsyRewarded == true then
                        alreadyAutopsied = true
                    end
                end
            end
        end
    end

    local sec = player:getSecondaryHandItem()
    if sec then
        player:removeFromHands(sec)
    end

    -- CASO JÁ AUTOPSIADO (SEM RECOMPENSA)
    if alreadyAutopsied then
        if corpseX and corpseY and corpseZ then
            MarkCorpseAsAutopsied(corpseX, corpseY, corpseZ, corpseId)
        end

        if isServer() then
            sendServerCommand(
                player,
                "ZVirusVaccine42BETA",
                "AutopsyFeedback",
                { result = "AlreadyAutopsied" }
            )
        else
            triggerEvent("OnLabAutopsyComplete", player, "AlreadyAutopsied")
        end

        local square = player:getCurrentSquare()
        if square then
            addBloodSplat(square, ZombRand(5))
        end

        return "AlreadyAutopsied"
    end

    -- AUTÓPSIA VÁLIDA (PRIMEIRA VEZ)
    local inv = player:getInventory()
    local prof = player:getDescriptor():getCharacterProfession()
    local isDoctor = (prof == CharacterProfession.DOCTOR)
	local scienceLevel = 0
	
	if Perks.Science then
		scienceLevel = player:getPerkLevel(Perks.Science) -- Science, bitch!
	end

    local xp = isOnTable
        and LabSandboxOptions.GetAutopsyTableXP()
        or  LabSandboxOptions.GetAutopsyGroundXP()

    local xpMultiplier = 1.0

    if _G.RLPTraitEffects then
        xpMultiplier = _G.RLPTraitEffects.ModifyAutopsyXPMultiplier(player, xpMultiplier)
    end

    if isDoctor then
        xpMultiplier = xpMultiplier * 1.10
    end

    xp = xp * xpMultiplier

    if isOnTable then        local sampleCount = isDoctor and 4 or 3

        if _G.RLPTraitEffects then
            sampleCount = _G.RLPTraitEffects.ModifyAutopsySampleCount(player, sampleCount)
        end
		
		if scienceLevel > 0 then
			local extraChance = math.min(scienceLevel * 3, 30)

			if ZombRand(100) < extraChance then
				sampleCount = sampleCount + 1
			end
		end

        -- Chance dinâmica de sangue infectado na mesa
        -- Base: 50%
        -- +1% por nível de First Aid (máx +10%)
        -- +5% se Doctor
        -- +15% se Estagiário
        -- -5% se Hemofóbico
        local firstAidLevel = player:getPerkLevel(Perks.Doctor)
        local infectedChance = 50
        infectedChance = infectedChance + firstAidLevel  -- +1% por nível

        if isDoctor then
            infectedChance = infectedChance + 5
        end

        if player:hasTrait(CharacterTrait.HEMOPHOBIC) then
            infectedChance = infectedChance - 5
        end

        if _G.RLPTraitEffects then
            infectedChance = _G.RLPTraitEffects.ModifyAutopsyInfectedBloodChance(player, infectedChance)
        end
        
		if LabSandboxOptions.IsDebugMode() then -- desn't really necessary
            print("========== AUTOPSY TABLE DEBUG ==========")
            print("First Aid Level  :", firstAidLevel)
            print("Is Doctor        :", isDoctor)
            print("Is Intern        :", _G.RLPTraitEffects and player:hasTrait(RLP.CharacterTrait.AUTOPSY_SPECIALIST) or false)
            print("Is Hemophobic    :", player:hasTrait(CharacterTrait.HEMOPHOBIC))
            print("Infected Chance  :", infectedChance .. "%")
            print("Tainted Chance   :", (100 - infectedChance) .. "%")
            print("==========================================")
        end

        local hasInf, hasTnt = false, false
        local xpPerSample = xp / sampleCount  -- XP base dividida por amostra

        for i = 1, sampleCount do
            if ZombRand(100) < infectedChance then
                local it = inv:AddItem("LabItems.MatInfectedBlood")
                if it then sendAddItemToContainer(inv, it) end
                hasInf = true
                addXp(player, Perks.Doctor, xpPerSample * 1.3)  -- amostra boa = +30%
            else
                local it = inv:AddItem("LabItems.MatTaintedBlood")
                if it then sendAddItemToContainer(inv, it) end
                hasTnt = true
                addXp(player, Perks.Doctor, xpPerSample * 0.8)  -- amostra ruim = -20%
            end
        end

        if hasInf then
            finalResult = "Infected"
        elseif hasTnt then
            finalResult = "Tainted"
        end

        -- AUTÓPSIA NA MESA: troca sprite para "Remains"
        if topX and topY and topZ then
            local cell = getCell()
            if cell then
                local square = cell:getGridSquare(topX, topY, topZ)
                
                if square then
                    local objs = square:getObjects()
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if instanceof(obj, "IsoThumpable") then
                            local foundTop, foundBottom = LabRecipes_GetBedObjects(obj, morgueTable)
                            if foundTop and foundBottom then
                                local mdTop = foundTop:getModData()
                                mdTop.Autopsy = true
                                LabSpriteSynchHandler.MorgueTableSwap(foundTop, foundBottom, "Remains")
                                break
                            end
                        end
                    end
                end
            end
        end
    else

        -- PROBABILIDADE DINÂMICA (CHÃO)
        local baseInfected = 40
        local baseTainted  = 36
        local baseNothing  = 24

        local firstAidLevel = player:getPerkLevel(Perks.Doctor)

		-- Redução por First Aid
		local skillReduction = 1.2 * firstAidLevel

		-- Science reduz apenas Nothing
		-- 0.5% por nível (máx 5)
		local scienceReduction = scienceLevel * 0.5
		local totalReduction = skillReduction + scienceReduction

        -- Permite trait modificar
        if _G.RLPTraitEffects then
			totalReduction = _G.RLPTraitEffects.ModifyGroundAutopsyNothingReduction(player, totalReduction)
		end

        -- Clamp estrutural
		if totalReduction > baseNothing then
			totalReduction = baseNothing
		end

		-- Separar o que veio de skill e o que veio de science
		local appliedSkillReduction   = math.min(skillReduction, totalReduction)
		local appliedScienceReduction = totalReduction - appliedSkillReduction

		-- Distribuição final
		local finalNothing  = baseNothing - totalReduction

		local finalInfected =
			baseInfected + (appliedSkillReduction * 0.6) + appliedScienceReduction   -- 100% vai para infected

		local finalTainted =
			baseTainted + (appliedSkillReduction * 0.4)

        if LabSandboxOptions.IsDebugMode() then
            local hasSpecialist = _G.RLPTraitEffects and player:hasTrait(RLP.CharacterTrait.AUTOPSY_SPECIALIST) or false
            print("========== AUTOPSY GROUND DEBUG ==========")
            print("Chances Base:")
            print("Infected:", baseInfected)
            print("Tainted :", baseTainted)
            print("Nothing :", baseNothing)

            print("Profissao:", prof)
            print("Trait Specialist:", hasSpecialist)
            print("Nivel First Aid:", firstAidLevel)
			print("Science Level:", scienceLevel)

            print("Reducao Base (Skill):", skillReduction)
            print("Reducao Total Aplicada:", totalReduction)

            print("Probabilidades Finais:")
            print("Infected:", finalInfected)
            print("Tainted :", finalTainted)
            print("Nothing :", finalNothing)

            print("Soma Final:", finalInfected + finalTainted + finalNothing)
        end

        local extraRolls = 1

		if scienceLevel > 0 then
			local extraChance = math.min(scienceLevel * 3, 30) -- Máx 30% de chance para +1 roll
			if ZombRand(100) < extraChance then
				extraRolls = 2
			end
		end

		for i = 1, extraRolls do
			local roll = ZombRand(100)
			
			if LabSandboxOptions.IsDebugMode() then
				print("[AUTOPSY DEBUG] Roll:", roll)
			end

			if roll < finalInfected then
				local it = inv:AddItem("LabItems.MatInfectedBlood")
				if it then sendAddItemToContainer(inv, it) end
				finalResult = "Infected"

			elseif roll < (finalInfected + finalTainted) then
				local it = inv:AddItem("LabItems.MatTaintedBlood")
				if it then sendAddItemToContainer(inv, it) end
				if finalResult ~= "Infected" then
					finalResult = "Tainted"
				end
			end
		end

        if LabSandboxOptions.IsDebugMode() then
            print("[AUTOPSY DEBUG] Final Result:", finalResult)
            print("------------------------------------------------")
        end
    end

    if LabSandboxOptions.IsDebugMode() then
        print("[AUTOPSY DEBUG] Total XP Calc:", xp)
    end
    -- XP dinâmica por qualidade do resultado (chão apenas)
    -- Na mesa a XP já foi dada por amostra individual no loop acima
    if not isOnTable then
        if finalResult == "Tainted" then
            xp = xp * 0.5
        elseif finalResult == "Nothing" then
            xp = xp * 0.2
        end

        if LabSandboxOptions.IsDebugMode() then
            print("[AUTOPSY DEBUG] XP Final:", xp, "| Resultado:", finalResult)
        end

        addXp(player, Perks.Doctor, xp)
    end

    if targetCorpse then
        local md = targetCorpse:getModData()
        md.Autopsy = true            -- trava lógica
        md.AutopsyRewarded = true    -- recompensa já concedida
    end

    if corpseX and corpseY and corpseZ then
        MarkCorpseAsAutopsied(corpseX, corpseY, corpseZ, corpseId)
    end

    if isServer() then
        sendServerCommand(
            player,
            "ZVirusVaccine42BETA",
            "AutopsyFeedback",
            { result = finalResult }
        )
    else
        triggerEvent("OnLabAutopsyComplete", player, finalResult)
    end

    if player:hasTrait(CharacterTrait.HEMOPHOBIC) then
        player:getStats():add(CharacterStat.PANIC, 25)
        syncPlayerStats(player, 0x00000100)
    end

    local square = player:getCurrentSquare()
    if square then
        addBloodSplat(square, ZombRand(20))
    end

    return finalResult
end

return LabAutopsyLogic