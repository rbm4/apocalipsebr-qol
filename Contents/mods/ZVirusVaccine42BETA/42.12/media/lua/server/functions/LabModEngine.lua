---------------------------------------- Variables ----------------------------------------

local labTestMode = false;

local lastX = -1;
local lastY = -1;

local labEqupmentSquares = {}

-- Radius of blood aging
local bloodRadius = 14;

-- Blood Life in game minutes x 10
local bloodLife = {
	MatInfectedBlood = { Target = "MatTaintedBlood", Time = 3 },
	CmpSyringeWithBlood = { Target = "CmpSyringeWithTaintedBlood", Time = 12 },
	CmpSyringeReusableWithBlood = { Target = "CmpSyringeReusableWithTaintedBlood", Time = 12 },
	CmpTestTubeWithInfectedBlood = { Target = "CmpTestTubeWithTaintedBlood", Time = 12960 },
};

-- Morgue Table transmutations
morgueTable = {
    -- Mesa limpa (Empty)
    location_community_medical_01_76 = { Top = true,  East = true,  Adj = "location_community_medical_01_77", Swap = "demonius_vaccine_01_72", Status = "Empty" },
    location_community_medical_01_77 = { Top = false, East = true,  Adj = "location_community_medical_01_76", Swap = "demonius_vaccine_01_73", Status = "Empty" },
    location_community_medical_01_79 = { Top = true,  East = false, Adj = "location_community_medical_01_78", Swap = "demonius_vaccine_01_75", Status = "Empty" },
    location_community_medical_01_78 = { Top = false, East = false, Adj = "location_community_medical_01_79", Swap = "demonius_vaccine_01_74", Status = "Empty" },

    -- Mesa com corpo (Corpse)
    demonius_vaccine_01_72 = { Top = true,  East = true,  Adj = "demonius_vaccine_01_73", Swap = "demonius_vaccine_01_76", Status = "Corpse" },
    demonius_vaccine_01_73 = { Top = false, East = true,  Adj = "demonius_vaccine_01_72", Swap = "demonius_vaccine_01_77", Status = "Corpse" },
    demonius_vaccine_01_75 = { Top = true,  East = false, Adj = "demonius_vaccine_01_74", Swap = "demonius_vaccine_01_79", Status = "Corpse" },
    demonius_vaccine_01_74 = { Top = false, East = false, Adj = "demonius_vaccine_01_75", Swap = "demonius_vaccine_01_78", Status = "Corpse" },

    -- Mesa com corpo aberto (Remains)
    demonius_vaccine_01_76 = { Top = true,  East = true,  Adj = "demonius_vaccine_01_77", Swap = "demonius_vaccine_01_80", Status = "Remains" },
    demonius_vaccine_01_77 = { Top = false, East = true,  Adj = "demonius_vaccine_01_76", Swap = "demonius_vaccine_01_81", Status = "Remains" },
    demonius_vaccine_01_79 = { Top = true,  East = false, Adj = "demonius_vaccine_01_78", Swap = "demonius_vaccine_01_83", Status = "Remains" },
    demonius_vaccine_01_78 = { Top = false, East = false, Adj = "demonius_vaccine_01_79", Swap = "demonius_vaccine_01_82", Status = "Remains" },

    -- Mesa suja (Dirty)
    demonius_vaccine_01_80 = { Top = true,  East = true,  Adj = "demonius_vaccine_01_81", Swap = "location_community_medical_01_76", Status = "Dirty" },
    demonius_vaccine_01_81 = { Top = false, East = true,  Adj = "demonius_vaccine_01_80", Swap = "location_community_medical_01_77", Status = "Dirty" },
    demonius_vaccine_01_83 = { Top = true,  East = false, Adj = "demonius_vaccine_01_82", Swap = "location_community_medical_01_79", Status = "Dirty" },
    demonius_vaccine_01_82 = { Top = false, East = false, Adj = "demonius_vaccine_01_83", Swap = "location_community_medical_01_78", Status = "Dirty" },
}

--Função
function Lab_MorgueTableSwap(top, bottom, targetStatus)
    if not top or not bottom then return end

    -- Sprite atual
    local sprite = top:getSprite():getName()
    local entry = morgueTable[sprite]
    if not entry then return end

    -- Encontrar o sprite correspondente ao "targetStatus"
    local newSpriteName = nil

    for spr, data in pairs(morgueTable) do
        if data.Status == targetStatus and data.Top == entry.Top and data.East == entry.East then
            newSpriteName = spr
            break
        end
    end

    if not newSpriteName then
        print("[LabMod] ERROR: No sprite for status: "..tostring(targetStatus))
        return
    end

    -- Trocar sprites
    top:setSprite(newSpriteName)

    -- Sprite "adjacente" inferior correspondente
    local adj = morgueTable[newSpriteName].Adj
    if adj then
        bottom:setSprite(adj)
    end

    -- Atualizar aparência no mundo
    top:transmitUpdatedSprite()
    bottom:transmitUpdatedSprite()

    -- Atualizar estado no modData
    local md = top:getModData()
    md.MorgueStatus = targetStatus
    top:transmitModData()
end

-- Encontra top, bottom e Status da mesa de necrotério a partir de um dos sprites
function LabRecipes_GetBedObjects(source, bedTable)
    if not source or not source:getSprite() then return nil end

    local spriteName = source:getSprite():getName()
    local curBed = bedTable[spriteName]
    if not curBed then return nil end

    local top  = curBed.Top and source or nil
    local bottom = (not curBed.Top) and source or nil

    local x = 0
    local y = 0

    if curBed.East then
        x = curBed.Top and 1 or -1
        y = 0
    else
        x = 0
        y = curBed.Top and 1 or -1
    end

    local sq = source:getSquare()
    if not sq then return nil end

    local adjSq = getCell():getGridSquare(sq:getX() + x, sq:getY() + y, sq:getZ())
    if not adjSq then return nil end

    local objs = adjSq:getObjects()
    for i = 0, objs:size()-1 do
        local obj = objs:get(i)
        if instanceof(obj, "IsoThumpable") and obj:getSprite() and obj:getSprite():getName() == curBed.Adj then
            if curBed.Top then
                bottom = obj
            else
                top = obj
            end
            break
        end
    end

    return top, bottom, curBed.Status
end


---------------------------------------- Helpers (NEW) ----------------------------------------
local function LabRecipes_GetPlayerSafe(player)
    return player or getPlayer()
end

local function LabRecipes_GetInvSafe(player)
    local pl = LabRecipes_GetPlayerSafe(player)
    if pl and pl.getInventory then
        return pl:getInventory()
    end
    print("[LabRecipes] ERRO: Inventário não encontrado (player nulo?)")
    return nil
end

---------------------------------------- Test ----------------------------------------

function LabRecipes_PrintTestInfo(player, obj)
	if not labTestMode then return end

	if player then
		local body = player:getBodyDamage()
		local xp = player:getXp()

		print(string.format("--------- Player (%d) ---------", player:getPlayerNum()))
		print(string.format("Infected: %s", body:isInfected() and "True" or "False"))

		if body:isInfected() then
			print(string.format("Infection rate: %d",
				math.floor(LabRecipes_InfectionRate(player) * 100)))
		end

		print(string.format("Doctor level: %d - %d ( x %1.1f )",
			player:getPerkLevel(Perks.Doctor),
			xp:getXP(Perks.Doctor),
			xp:getMultiplier(Perks.Doctor)))

		print("Albumnin doses left: ", player:getModData().AlbuminDoses or "N/A")
		print("Vaccine recess: ", player:getModData().VaccineRecess or "N/A")
		print("Vaccine time: ", player:getModData().VaccineTime or "N/A")
		print("Vaccine strength: ", player:getModData().VaccineStrength or "N/A")
	end

	if obj then
		print("---------- Object ----------")
		if instanceof(obj, "IsoObject") or instanceof(obj, "InventoryItem") or instanceof(obj, "IsoThumpable") then
			print("Mod Data:")
			for k, v in pairs(obj:getModData()) do
				print(string.format("--- %s = %s", tostring(k), tostring(v)))
			end
			if instanceof(obj, "IsoThumpable") then
				print("Sprite: ", obj:getSprite():getName())
			end
		end
	end

	print("-------------------------------")
end

function LabRecipes_CountCellItems(itemType)
	local cell = getWorld():getCell()
	local total = 0

	for y = cell:getMinY(), cell:getMaxY() do
		for x = cell:getMinX(), cell:getMaxX() do
			for z = cell:getMinZ(), cell:getMaxZ() do
				local sq = cell:getGridSquare(x, y, z)
				if sq then
					local objects = sq:getObjects()
					for i = 0, objects:size() - 1 do
						local cnt = objects:get(i):getContainer()
						if cnt then
							total = total + cnt:getItemCountRecurse(itemType)
						end
					end
				end
			end
		end
	end

	return total
end

function LabRecipes_PrintTestInfoItems()
	if not labTestMode then return end

	local items = {
		"LabSyringe",
		"LabSyringeReusable",
		"LabSyringePack",
		"ChAmmonia",
		"ChSodiumHydroxideBag",
		"ChHydrochloricAcidCan",
		"ChSulfuricAcidCan",
		"Plasticbag",
		"CottonBalls",
	}

	print("---------- Counting ----------")
	for _, v in ipairs(items) do
		print(v .. " = " .. LabRecipes_CountCellItems(v))
	end
	print("----------------------------------")
end

---------------------------------------- Common ----------------------------------------

function LabRecipes_IsPlayerMoved(player)
	local newX = math.floor(player:getX() * 100)
	local newY = math.floor(player:getY() * 100)

	if newX == lastX and newY == lastY then
		return false
	end

	lastX = newX
	lastY = newY
	return true
end

function LabRecipes_LookForNearEquipment(square, equipment, custom)
	local px, py, pz = square:getX(), square:getY(), square:getZ()

	for y = py - 1, py + 1 do
		for x = px - 1, px + 1 do
			local sqTest = getCell():getGridSquare(x, y, pz)
			if sqTest then
				local objs = sqTest:getObjects()
				for i = 0, objs:size() - 1 do
					local obj = objs:get(i)
					local sprite = obj and obj:getSprite()
					if sprite then
						local props = sprite:getProperties()

						if equipment
							and props:Is("CustomItem")
							and props:Val("CustomItem") == equipment then
							return sqTest
						end

						if custom
							and props:Is("GroupName")
							and props:Is("CustomName")
							and (props:Val("GroupName") .. " " .. props:Val("CustomName")) == custom then
							return sqTest
						end
					end
				end
			end
		end
	end

	return nil
end

function LabRecipes_IsNearLabEquip(equipment)
	local player = getPlayer()

	labEqupmentSquares.SkipCheck =
		not LabRecipes_IsPlayerMoved(player)
		and labEqupmentSquares.LastEquipment == equipment

	if labEqupmentSquares.SkipCheck then
		return labEqupmentSquares[equipment]
	end

	labEqupmentSquares.LastEquipment = equipment
	labEqupmentSquares[equipment] =
		LabRecipes_LookForNearEquipment(player:getCurrentSquare(), "LabItems." .. equipment, nil)

	return labEqupmentSquares[equipment]
end

function LabRecipes_TransformBed(top, bottom, bed)
	top:setSpriteFromName(bed[top:getSprite():getName()].Swap)
	top:transmitUpdatedSpriteToServer()

	bottom:setSpriteFromName(bed[bottom:getSprite():getName()].Swap)
	bottom:transmitUpdatedSpriteToServer()
end

function LabRecipes_RandNorm(min, max, mean, dev)
	local u1 = ZombRandFloat(0.01, 0.99)
	local u2 = ZombRandFloat(0.01, 0.99)
	local rnd = mean * math.abs(1 + math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2) * dev)
	return min + math.floor(rnd / 2 * (max - min) + 0.5)
end

---------------------------------------- OnTest ----------------------------------------
-- Microscope nearby?
function LabRecipes_IsNearMicroscope(sourceItem, result)
    return LabRecipes_IsNearLabEquip("LabMicroscope") ~= nil
end

-- Chromatograph + Desktop Computer nearby?
function LabRecipes_IsNearChromatographWithComputer(sourceItem, result)
    local square = LabRecipes_IsNearLabEquip("LabChromatograph")

    if not square then
        labEqupmentSquares.DesktopComputer = nil
    elseif not labEqupmentSquares.SkipCheck then
        labEqupmentSquares.DesktopComputer =
            LabRecipes_LookForNearEquipment(square, nil, "Desktop Computer")
    end

    return labEqupmentSquares.DesktopComputer ~= nil
end

-- Spectrometer nearby?
function LabRecipes_IsNearSpectrometer(sourceItem, result)
    return LabRecipes_IsNearLabEquip("LabSpectrometer") ~= nil
end

-- Chemistry Set nearby? (requires clean water)
function LabRecipes_IsNearChemistrySet(sourceItem, result)
    return LabRecipes_IsNearLabEquip("LabChemistrySet") ~= nil
end

-- Centrifuge nearby?
function LabRecipes_IsNearCentrifuge(sourceItem, result)
    return LabRecipes_IsNearLabEquip("LabCentrifuge") ~= nil
end

-- Muffle Furnace nearby?
function LabRecipes_IsNearMuffleFurnace(sourceItem, result)
    return LabRecipes_IsNearLabEquip("LabMuffleFurnace") ~= nil
end

-- Workbench nearby?
function LabRecipes_IsNearWorkbench(sourceItem, result)
    return LabRecipes_IsNearLabEquip("LabWorkbench") ~= nil
end

-- Easel nearby?
function LabRecipes_IsNearEasel(sourceItem, result)
    return LabRecipes_IsNearLabEquip("LabEasel") ~= nil
end

-- LISTA DE TIPOS DE VACINAS E CURA
local vaccineTypes = {
    CmpSyringeWithPlainVaccine = true,
    CmpSyringeWithQualityVaccine = true,
    CmpSyringeWithAdvancedVaccine = true,
    CmpSyringeWithCure = true,

    CmpSyringeReusableWithPlainVaccine = true,
    CmpSyringeReusableWithQualityVaccine = true,
    CmpSyringeReusableWithAdvancedVaccine = true,
    CmpSyringeReusableWithCure = true,
    }

---------------------------------------- Inventory Context Menus ----------------------------------------

function LabRecipes_BuildInventoryCM(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- percorre os itens clicados
    for _, entry in ipairs(items) do
        local item = entry
        if not instanceof(item, "InventoryItem") then
            item = entry.items and entry.items[1]
        end

        if not item then
            -- item inválido, ignora
        else

            -- 1) ALBUMINA
            if item:getType() == "CmpAlbuminPills" then
                context:addOption(
                    getText("ContextMenu_Take_pills"),
                    item,
                    LabRecipes_CMOnTakeAlbuminPills,
                    player,
                    items
                )
            end

			-- 2) VACINAS / CURA
			if vaccineTypes[item:getType()] then
				context:addOption(
					getText("ContextMenu_LabInjectVaccine"),
					item,
					LabRecipes_CMOnInjectVaccine,
					player
				)
			end

			-- 3) COLETA DE SANGUE (SERINGA REUTILIZÁVEL)
			if item:getType() == "LabSyringe" or item:getType() == "LabSyringeReusable" then
				local opt = context:addOption(
					getText("ContextMenu_LabCollectBloodBlood"),
					item,
					LabRecipes_CMOnCollectBlood,
					player,
					items
				)

				LabRecipes_CreateCollectBloodTooltip(opt, player, item)
			end

			-- 4) TESTE SANGUÍNEO
			if item:getType() == "CmpSyringeReusableWithBlood"
			or item:getType() == "CmpSyringeWithBlood" then
				local opt = context:addOption(
					getText("ContextMenu_TestBlood"),
					item,
					LabRecipes_CMOnTestBlood,
					player,
					items
				)

				-- tooltip
				LabRecipes_CreateBloodTestTooltip(opt, player)
			end

        end
    end
end

-- Quando o jogador clica para tomar albumina
function LabRecipes_CMOnTakeAlbuminPills(item, player, items)
    if not player then return end

    -- garante que o item está no inventário e equipado corretamente
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)

    -- adiciona a ação temporizada
    ISTimedActionQueue.add(LabActionTakeAlbumin:new(player, item))
end

-- Quando o jogador usa uma vacina/cura
function LabRecipes_CMOnInjectVaccine(item, player, items)
    if not player then return end

    -- Garante que o item está no inventário (pega da mão, etc.)
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)

    -- Executa a animação de injeção
    ISTimedActionQueue.add(LabActionInjectVaccine:new(player, item))
end

-- Quando o jogador clica na seringa SEM SANGUE
function LabRecipes_CMOnCollectBlood(item, player)
    if not player then return end
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    ISTimedActionQueue.add(LabActionCollectBlood:new(player, item))
end

-- Quando o jogador clica na seringa com sangue
function LabRecipes_CMOnTestBlood(item, player, items)
    if not player then return end
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    ISTimedActionQueue.add(LabActionTestBlood:new(player, item))
end

-- Tooltip para TESTE DE SANGUE (inventário)
function LabRecipes_CreateBloodTestTooltip(option, player)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip = tooltip

    tooltip.description = tooltip.description .. getText("ContextMenu_LabMustHaveItems")

    local nearSpectro = LabRecipes_IsNearSpectrometer()

    tooltip.description =
        tooltip.description ..
        string.format(" - <%s> %s <RGB:1,1,1> <LINE>",
            nearSpectro and "GREEN" or "RED",
            getText("ContextMenu_LabNeedSpectrometer")
        )

    option.notAvailable = not nearSpectro
end

-- Tooltip para COLETA DE SANGUE
function LabRecipes_CreateCollectBloodTooltip(option, player, syringe)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip = tooltip

    tooltip.description = tooltip.description .. getText("ContextMenu_LabMustHaveItems")

    local inv = player:getInventory()
    local hasCotton = inv:contains("AlcoholedCottonBalls")
    local hasSyringe = syringe ~= nil

    -- Seringa
    tooltip.description =
        tooltip.description ..
        string.format(" - <%s> %s <RGB:1,1,1> <LINE>",
            hasSyringe and "GREEN" or "RED",
            getText("ContextMenu_LabNeedSyringe")
        )

    -- Algodão com álcool
    tooltip.description =
        tooltip.description ..
        string.format(" - <%s> %s <RGB:1,1,1> <LINE>",
            hasCotton and "GREEN" or "RED",
            getText("ContextMenu_LabNeedAlcoholCotton")
        )

    -- Bloquear se faltar algo
    option.notAvailable = not (hasSyringe and hasCotton)
end

---------------------------------------- World Context Menus ----------------------------------------

local function predicateNotBroken(item)
    return item and not item:isBroken()
end

-- Equip mask if needed
local function wearIfNeeded(player, clothing)
    if clothing and not player:isEquippedClothing(clothing) then
        ISInventoryPaneContextMenu.wearItem(clothing, player:getPlayerNum())
    end
end

-- MORGUE TABLE HELPERS
-- Bleach suficiente (≥ 0.2L)
local function LabRecipes_PredicateBleachEnough(item)
    if not item then return false end
    if not item:hasComponent(ComponentType.FluidContainer) then return false end

    local fc = item:getFluidContainer()
    if not fc then return false end

    return fc:contains(Fluid.Bleach) and fc:getAmount() >= 0.2
end

function LabRecipes_CreateBleachCheckTooltip(option, inventory)
    local bleach = inventory:getFirstEvalRecurse(LabRecipes_PredicateBleachEnough)

    local color = bleach and "GREEN" or "RED"
    local name  = getItemNameFromFullType("Base.Bleach")

    option.toolTip.description =
        option.toolTip.description ..
        string.format(" -  <%s> %s (0.2 L) <RGB:1,1,1> <LINE>", color, name)

    return bleach ~= nil
end

-- Retorna top, bottom, status da mesa, se o objeto fizer parte de uma morgue table
local function Lab_MorgueTableGetPair(obj)
    if not obj or not obj:getSprite() or not morgueTable then return nil end

    local name = obj:getSprite():getName()
    local entry = morgueTable[name]
    if not entry then return nil end

    local sq = obj:getSquare()
    if not sq then return nil end

    local top, bottom

    if entry.Top then
        top = obj
        -- procurar o bottom pelo sprite Adj
        for i = 0, sq:getObjects():size()-1 do
            local o = sq:getObjects():get(i)
            if o ~= obj and o:getSprite() and o:getSprite():getName() == entry.Adj then
                bottom = o
                break
            end
        end
    else
        bottom = obj
        for i = 0, sq:getObjects():size()-1 do
            local o = sq:getObjects():get(i)
            if o ~= obj and o:getSprite() and o:getSprite():getName() == entry.Adj then
                top = o
                break
            end
        end
    end

    if not top or not bottom then return nil end

    return top, bottom, entry.Status
end

-- Colocar cadáver na mesa
function LabRecipes_WMOnPutCorpseOnTable(player, top, bottom, corpse)
    ISTimedActionQueue.add(
        LabActionPutCorpseOnTable:new(player, top, bottom, corpse)
    )
end

-- Pegar restos da mesa
function LabRecipes_WMOnGrabRemainsFromTable(player, top, bottom)
    if not bottom or not bottom:getSquare() then return end
    if not luautils.walkAdj(player, bottom:getSquare()) then return end

    ISTimedActionQueue.add(LabActionMorgueTableGetRemains:new(player, top, bottom))
end

-- Limpar mesa de necrotério
function LabRecipes_WMOnClearMorgueTable(player, top, bottom)
    if not bottom or not bottom:getSquare() then return end
    if not luautils.walkAdj(player, bottom:getSquare()) then return end

    local inv = player:getInventory()
    if not inv then return end

    local rag =
        inv:getFirstTypeRecurse("DishCloth") or
        inv:getFirstTypeRecurse("BathTowel")
    local bleach = inv:getFirstTypeRecurse("Bleach")

    ISInventoryPaneContextMenu.transferIfNeeded(player, rag)
    ISInventoryPaneContextMenu.transferIfNeeded(player, bleach)

    if rag then
        ISInventoryPaneContextMenu.equipWeapon(rag, true, false, player:getPlayerNum())
    end
    if bleach then
        ISInventoryPaneContextMenu.equipWeapon(bleach, false, false, player:getPlayerNum())
    end

    ISTimedActionQueue.add(LabActionMorgueTableClear:new(player, top, bottom))
end

-- AUTÓPSIA
function LabRecipes_WMOnCorpseAutopsy(player, corpse, square, top, bottom)
    local canCorpse = corpse and corpse:getSquare() and luautils.walkAdj(player, corpse:getSquare())
    local canTable  = bottom and bottom:getSquare() and luautils.walkAdj(player, bottom:getSquare())

    if not (canCorpse or canTable) then
        return
    end

    local inv = player:getInventory()
    if not inv then return end

    local mask =
        inv:getFirstTypeEvalRecurse("Hat_SurgicalMask",      predicateNotBroken) or
        inv:getFirstTypeEvalRecurse("Hat_DustMask",          predicateNotBroken) or
        inv:getFirstTypeEvalRecurse("Hat_GasMask",           predicateNotBroken) or
        inv:getFirstTypeEvalRecurse("Hat_BuildersRespirator", predicateNotBroken)

    local scalpel  = inv:getFirstTypeEvalRecurse("Scalpel",  predicateNotBroken)
    local tweezers = inv:getFirstTypeEvalRecurse("Tweezers", predicateNotBroken)

    -- Falta Scalpel → aborta
    if not scalpel then
        return
    end

    -- Falta Tweezers → aborta
    if not tweezers then
        return
    end

    -- Equipar máscara (se necessário)
    wearIfNeeded(player, mask)

    -- Equipar Scalpel na mão primária
    ISInventoryPaneContextMenu.equipWeapon(scalpel, true, false, player:getPlayerNum())

    -- Equipar Tweezers na mão secundária
    ISInventoryPaneContextMenu.equipWeapon(tweezers, false, false, player:getPlayerNum())

    -- Iniciar timed action (bed/morgueTable não é mais usado, será nil)
    ISTimedActionQueue.add(LabActionMakeAutopsy:new(player, corpse, square, top, bottom))
end

-- I feel... I feel better now...
function LabRecipes_GetObjValue(obj, field)
    local n = getNumClassFields(obj)
    for i = 0, n-1 do
        local meth = getClassField(obj, i)
        if string.find(tostring(meth), field) then
            return getClassFieldVal(obj, meth)
        end
    end
    return getPlayer():getHoursSurvived()
end

-- Add check line to Option tooltip
function LabRecipes_CreateCheckTooltip(option, inventory, moduleName, itemTypes, count, noBroken)
    local n = 0
    for _, v in ipairs(itemTypes) do
        if noBroken then
            n = n + inventory:getCountTypeEvalRecurse(v, predicateNotBroken)
        else
            n = n + inventory:getItemCountRecurse(v)
        end
    end

    local s = moduleName.."."..itemTypes[1]
    if count == 1 then
        option.toolTip.description =
            option.toolTip.description..
            string.format(" -  <%s> %s <RGB:1,1,1> <LINE>",
                (n<count) and "RED" or "GREEN",
                getItemNameFromFullType(s))
    else
        option.toolTip.description =
            option.toolTip.description..
            string.format(" -  <%s> %s ( %d / %d ) <RGB:1,1,1> <LINE>",
                (n<count) and "RED" or "GREEN",
                getItemNameFromFullType(s),
                math.min(n, count),
                count)
    end

    return n >= count
end

-- monta nome combinado para várias máscaras em uma linha
local function LabRecipes_GetCombinedMaskName(moduleName, itemTypes)
    local names = {}
    for _, v in ipairs(itemTypes) do
        local fullType = moduleName .. "." .. v
        local dispName = getItemNameFromFullType(fullType)
        if dispName then
            table.insert(names, dispName)
        end
    end

    if #names == 0 then
        return "Máscara"
    elseif #names == 1 then
        return names[1]
    elseif #names == 2 then
        return string.format("%s %s", names[1], names[2])
    else
        local last = names[#names]
        table.remove(names, #names)
        return string.format("%s %s", table.concat(names, ", "), last)
    end
end

-- Versão específica de check só para máscaras, com todos os nomes na mesma linha
local function LabRecipes_CreateMaskCheckTooltip(option, inventory, moduleName, itemTypes, noBroken)
    local n = 0
    for _, v in ipairs(itemTypes) do
        if noBroken then
            n = n + inventory:getCountTypeEvalRecurse(v, predicateNotBroken)
        else
            n = n + inventory:getItemCountRecurse(v)
        end
    end

    local combinedName = LabRecipes_GetCombinedMaskName(moduleName, itemTypes)

    option.toolTip.description =
        option.toolTip.description..
        string.format(" -  <%s> %s <RGB:1,1,1> <LINE>",
            (n < 1) and "RED" or "GREEN",
            combinedName)

    return n >= 1
end

-- Create corpse autopsy option tooltip
function LabRecipes_CreateCorpseAutopsyTooltip(option, inventory, notFresh, notZombie, notOrgans)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip = tooltip

    tooltip.description =
        tooltip.description..
        string.format(
            "%s:  <%s> %s12 %s <LINE> <RGB:1,1,1>",
            getText("ContextMenu_LabCorpseAge"),
            notFresh and "RED" or "GREEN",
            notFresh and ">" or "<",
            getText("ContextMenu_LabHrs")
        )

    tooltip.description =
        tooltip.description..
        string.format(
            "%s:  <%s> %s <LINE> <RGB:1,1,1>",
            getText("ContextMenu_LabWasZombie"),
            notZombie and "RED" or "GREEN",
            notZombie and getText("ContextMenu_LabNo") or getText("ContextMenu_LabYes")
        )

    tooltip.description =
        tooltip.description..
        string.format(
            "%s:  <%s> %s <LINE> <RGB:1,1,1>",
            getText("ContextMenu_LabAutopsyDone"),
            notOrgans and "RED" or "GREEN",
            notOrgans and getText("ContextMenu_LabYes") or getText("ContextMenu_LabNo")
        )

    tooltip.description =
        tooltip.description..
        getText("ContextMenu_LabMustHaveItems")

    local ok = true

    -- Máscaras: qualquer uma destas serve, nome combinado em uma linha só
    ok = LabRecipes_CreateMaskCheckTooltip(option, inventory, "Base",
        {"Hat_SurgicalMask","Hat_DustMask","Hat_GasMask","Hat_BuildersRespirator"}, true) and ok

    -- Bisturi
    ok = LabRecipes_CreateCheckTooltip(option, inventory, "Base", {"Scalpel"}, 1, true) and ok

    -- Tweezers
    ok = LabRecipes_CreateCheckTooltip(option, inventory, "Base", {"Tweezers"}, 1) and ok

    option.notAvailable = notFresh or notZombie or notOrgans or not ok
end

-- Create common style tooltip
function LabRecipes_CreateCommonTooltip(option)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip = tooltip
    tooltip.description = tooltip.description..getText("ContextMenu_LabMustHaveItems")
end

-- WORLD MENU PRINCIPAL
function LabRecipes_BuildZombieWM(playerNum, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then
        return true
    end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local inv     = player:getInventory()
    local subMenu = nil

    -- DEBUG
    if labTestMode then
        context:addOption(getText("ContextMenu_LabTestInfo"),      player, LabRecipes_PrintTestInfo,      nil)
        context:addOption(getText("ContextMenu_LabTestInfoItems"), nil,    LabRecipes_PrintTestInfoItems, nil)
    end

    -- 1) MESA DE NECROTÉRIO
    for _, v in ipairs(worldobjects) do
        local sq = v:getSquare()
        if sq then
            -- Verifica se algum objeto da tile é uma morgueTable
            for i = 0, sq:getObjects():size()-1 do
                local obj = sq:getObjects():get(i)
                if instanceof(obj, "IsoThumpable") and obj:getSprite() and morgueTable[obj:getSprite():getName()] then
                    local top, bottom, status = LabRecipes_GetBedObjects(obj, morgueTable)
                    if top and bottom and status then

                        -- EMPTY → colocar cadáver na mesa
                        if status == "Empty" then
                        local foundCorpse = nil

                        -- Procura cadáver em 1 tile ao redor da mesa
                        for dy = -1, 1 do
                            for dx = -1, 1 do
                                local sq2 = getCell():getGridSquare(sq:getX()+dx, sq:getY()+dy, sq:getZ())
                                if sq2 then
                                    local mobs = sq2:getStaticMovingObjects()
                                    for i = 0, mobs:size()-1 do
                                        local obj = mobs:get(i)
                                        if instanceof(obj, "IsoDeadBody") then
                                            foundCorpse = obj
                                            break
                                        end
                                    end
                                end
                                if foundCorpse then break end
                            end
                            if foundCorpse then break end
                        end

                        -- Se encontrou cadáver no chão → oferece a opção
                        if foundCorpse then
                            context:addOption(
                                getText("ContextMenu_LabPutCorpseOnTable"),
                                player,
                                LabRecipes_WMOnPutCorpseOnTable,
                                top,
                                bottom,
                                foundCorpse   -- <<=== agora passamos o cadáver real!
                            )
                        end

                        -- CORPSE → autópsia na mesa
                        elseif status == "Corpse" then
                            local md = top:getModData()
                            local deathTime = md.DeathTime or player:getHoursSurvived()
                            local notFresh = md.Skeleton or (player:getHoursSurvived() - deathTime > 12)
                            local notZombie = not md.Zombie
                            local notOrgans = md.Autopsy

                            local opt = context:addOption(
                                getText("ContextMenu_LabCorpseAutopsy"),
                                player, LabRecipes_WMOnCorpseAutopsy, nil, bottom:getSquare(), top, bottom
                            )
                            LabRecipes_CreateCorpseAutopsyTooltip(opt, inv, notFresh, notZombie, notOrgans)

                        -- pegar restos (Garbagebag ou 2x Plasticbag)
                        elseif status == "Remains" then
                            local opt = context:addOption(
                                getText("ContextMenu_LabPutRemainsIntoSack"),
                                player, LabRecipes_WMOnGrabRemainsFromTable, top, bottom
                            )
                            LabRecipes_CreateCommonTooltip(opt)

                            local ok = false
                            ok = LabRecipes_CreateCheckTooltip(opt, inv, "Base", {"Garbagebag"}, 1) or ok
                            opt.toolTip.description =
                                opt.toolTip.description..getText("ContextMenu_LabMustHaveItemsOr").." <LINE>"
                            ok = LabRecipes_CreateCheckTooltip(opt, inv, "Base", {"Plasticbag"}, 2) or ok

                            opt.notAvailable = not ok

                        -- limpar mesa (Bleach + DishCloth/BathTowel)
                        elseif status == "Dirty" then
                            local opt = context:addOption(
                                getText("ContextMenu_LabClearMorgueTable"),
                                player, LabRecipes_WMOnClearMorgueTable, top, bottom
                            )
                            LabRecipes_CreateCommonTooltip(opt)

                            local ok = LabRecipes_CreateBleachCheckTooltip(opt, inv)
                            opt.toolTip.description =
                                opt.toolTip.description..getText("ContextMenu_LabMustHaveItemsAnd").." <LINE>"

                            local ok2 = LabRecipes_CreateCheckTooltip(opt, inv, "Base", {"DishCloth"}, 1)
                            opt.toolTip.description =
                                opt.toolTip.description..getText("ContextMenu_LabMustHaveItemsOr").." <LINE>"
                            ok2 = LabRecipes_CreateCheckTooltip(opt, inv, "Base", {"BathTowel"}, 1) or ok2

                            opt.notAvailable = not (ok and ok2)
                        end
                    end
                end
            end

            -- 2) AUTÓPSIA EM CADÁVER NO CHÃO (SEU BLOCO ORIGINAL)
            for y = sq:getY()-1, sq:getY()+1 do
                for x = sq:getX()-1, sq:getX()+1 do
                    local sq2 = getCell():getGridSquare(x, y, sq:getZ())
                    if not sq2 then break end

                    local mobs = sq2:getStaticMovingObjects()
                    for i2 = 0, mobs:size()-1 do
                        local dead = mobs:get(i2)
                        if instanceof(dead, "IsoDeadBody") then
                            if not subMenu then
                                subMenu = ISContextMenu:getNew(context)
                                context:addSubMenu(
                                    context:addOption(getText("ContextMenu_LabCorpseAutopsy"), worldobjects, nil),
                                    subMenu
                                )
                            end

                            local notFresh  = dead:isSkeleton()
                                or player:getHoursSurvived() - LabRecipes_GetObjValue(dead, "deathTime") > 12
                            local notZombie = not dead:isZombie()
                            local notOrgans = dead:getModData().Autopsy

                            local opt = subMenu:addOption(
                                getText("ContextMenu_LabCorpse"),
                                player, LabRecipes_WMOnCorpseAutopsy, dead, sq2, nil, nil
                            )
                            LabRecipes_CreateCorpseAutopsyTooltip(opt, inv, notFresh, notZombie, notOrgans)
                        end
                    end
                end
            end
        end

        break
    end
end

---------------------------------------- Blood Aging ----------------------------------------
-- Atualiza idade do sangue; container pode ser "floor" ou um ItemContainer
function LabRecipes_UpdateBloodAge(item, container, square)
    if not item then return end

    local obj = bloodLife[item:getType()]
    if not obj then return end

    local md = item:getModData()

    -- Inicializa condição
    if md.Condition == nil then
        md.Condition = obj.Time
        return
    end

    -- Decrementa
    md.Condition = md.Condition - 1

    -- Ainda não estragou
    if md.Condition > 0 then return end

    -- Item estragou → substituir pelo item alvo
    local targetType = "LabItems." .. obj.Target

    -- CASO 1: Item está dentro de um container (inventário/baú)
    if type(container) ~= "string" then
        if container and container.DoRemoveItem then
            container:DoRemoveItem(item)
            container:removeItemOnServer(item)

            local newItem = container:AddItem(targetType)
            if newItem then
                container:addItemOnServer(newItem)
            end
        end
        return
    end

    -- CASO 2: Item está no chão
    if container == "floor" then
        if not square then return end

        local worldItem = item.getWorldItem and item:getWorldItem() or nil
        if worldItem then
            square:transmitRemoveItemFromSquare(worldItem)
            worldItem:removeFromSquare()
        end

        if InventoryItemFactory and InventoryItemFactory.CreateItem and square.AddWorldInventoryItem then
            local newItem = InventoryItemFactory.CreateItem(targetType)
            if newItem then
                square:AddWorldInventoryItem(newItem, 0.5, 0.5, 0)
            end
        end
    end
end

-- Percorre um container (e containers dentro dele) procurando sangue
function LabRecipes_LookForBloodInContainer(container)
    if not container then return end

    local items = container:getItems()
    if not items then return end

    for i = 0, items:size() - 1 do
        local item = items:get(i)

        if item then
            -- Se o item é um container dentro de outro
            if item:getCategory() == "Container" then
                local inner = item:getItemContainer()
                if inner then
                    LabRecipes_LookForBloodInContainer(inner)
                end
            else
                -- Item normal
                LabRecipes_UpdateBloodAge(item, container, nil)
            end
        end
    end
end

-- Passa por todos os itens do chão dentro do radius
function LabRecipes_LookForBloodOnGround()
    local player = getPlayer()
    if not player then return end

    local px = player:getX()
    local py = player:getY()
    local pz = player:getZ()

    for x = px - bloodRadius, px + bloodRadius do
        for y = py - bloodRadius, py + bloodRadius do
            local square = getCell():getGridSquare(x, y, pz)
            if square then
                local worldItems = square:getWorldObjects()
                if worldItems then
                    for i = 0, worldItems:size() - 1 do
                        local wo = worldItems:get(i)
                        local item = wo and wo:getItem()
                        if item then
                            LabRecipes_UpdateBloodAge(item, "floor", square)
                        end
                    end
                end
            end
        end
    end
end

-- Evento principal que verifica tudo a cada 10 minutos
function LabRecipes_AdjustBloodCondition()
    local player = getPlayer()
    if not player then return end

    -- Verifica inventário do jogador
    LabRecipes_LookForBloodInContainer(player:getInventory())

    -- Verifica containers equipados (mochilas)
    local worn = player:getWornItems()
    if worn then
        for i = 0, worn:size() - 1 do
            local wi = worn:get(i)
            local item = wi and wi:getItem()
            if item and item:getCategory() == "Container" then
                local inner = item:getItemContainer()
                if inner then
                    LabRecipes_LookForBloodInContainer(inner)
                end
            end
        end
    end

    -- Verifica itens no chão ao redor
    LabRecipes_LookForBloodOnGround()
end

---------------------------------------- Export ----------------------------------------
LabModEngine = {}
LabModEngine.vaccineEffect = vaccineEffect
LabModEngine.GetUsedSyringe = LabRecipes_GetUsedSyringe
---------------------------------------- Events ----------------------------------------
Events.EveryTenMinutes.Add(LabRecipes_AdjustBloodCondition)
Events.EveryHours.Add(LabRecipes_AdjustPlayerHealth)
Events.OnFillWorldObjectContextMenu.Add(LabRecipes_BuildZombieWM)
Events.OnFillInventoryObjectContextMenu.Add(LabRecipes_BuildInventoryCM)

print("=====================================================")
print("[ZVirusVaccine] WARNING: THIS FILE SHOULD NOT BE LOADING IN MULTIPLAYER!")
print("[ZVirusVaccine] If you see this message while playing multiplayer (B42.13-14), please report.")
print("=====================================================")