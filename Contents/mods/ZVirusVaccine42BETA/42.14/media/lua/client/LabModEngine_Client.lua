-- LabModEngine_Client.lua
-- UI, Context Menus e Interações do Cliente

----------------------------------------
-- Cache Local
----------------------------------------
local _sb = SandboxVars.ZombieVirusVaccineBETA or {}
local allowAutopsyOnGround   = _sb.AllowAutopsyOnGround;   if allowAutopsyOnGround   == nil then allowAutopsyOnGround   = true  end
local debugMode              = _sb.DebugMode;              if debugMode              == nil then debugMode              = false end

local autopsiedCorpsesCache = {}
local LabRecipes_LastContextBuild = 0

local predicateNotBroken = LabRecipes_PredicateNotBroken
local predicateBleachEnough = LabRecipes_PredicateBleachEnough

local getCell = getCell
local math_floor = math.floor
local math_min = math.min
local tostring = tostring

----------------------------------------
-- Helpers de Verificação
----------------------------------------
local function debugPrint(...)
    if debugMode then print("[ZVirusVaccine]", ...) end
end

function LabRecipes_IsCorpseAutopsied(corpseX, corpseY, corpseZ, corpseId)
    if not corpseX or not corpseY or not corpseZ then
        return false
    end
    
    -- Cria chave com corpseId quando disponível
    local corpseKey = corpseId
        and string.format("%d_%d_%d_%d", corpseX, corpseY, corpseZ, corpseId)
        or string.format("%d_%d_%d", corpseX, corpseY, corpseZ)
    
    -- Verifica cache primeiro
    if autopsiedCorpsesCache[corpseKey] then
        return true
    end
    
    local cell = getCell()
    if not cell then return false end
    
    local square = cell:getGridSquare(corpseX, corpseY, corpseZ)
    if not square then return false end
    
    local bodies = square:getDeadBodys()
    if not bodies or bodies:size() == 0 then
        return false
    end
    
    -- CASO 1: Se tem corpseId, verifica APENAS esse corpo específico
    if corpseId then
        for i = 0, bodies:size() - 1 do
            local body = bodies:get(i)
            
            -- Verifica se é o corpo correto
            local bodyId = nil
            
            -- Tenta getOnlineID primeiro (MP)
            if body and body.getOnlineID then
                local ok, id = pcall(function() return body:getOnlineID() end)
                if ok then bodyId = id end
            end
            
            -- Fallback para getID (SP)
            if not bodyId and body and body.getID then
                bodyId = body:getID()
            end
            
            -- Encontrou o corpo específico
            if bodyId and bodyId == corpseId then
                if body.getModData then
                    local ok, md = pcall(function() return body:getModData() end)
                    if ok and md and md.Autopsy then
                        autopsiedCorpsesCache[corpseKey] = true
                        return true
                    end
                end
                -- Corpo encontrado mas NÃO autopsiado
                return false
            end
        end
        
        -- Corpo com esse ID não foi encontrado no square
        return false
    end

    -- CASO 2: corpseId == nil (fallback)
    if bodies:size() > 0 then
        local mostRecentBody = bodies:get(bodies:size() - 1)
        
        if mostRecentBody and mostRecentBody.getModData then
            local ok, md = pcall(function() return mostRecentBody:getModData() end)
            if ok and md and md.Autopsy then
                autopsiedCorpsesCache[corpseKey] = true
                return true
            end
        end
    end

    return false
end

----------------------------------------
-- Inventory Context Menus
----------------------------------------

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

function LabRecipes_BuildInventoryCM(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    for _, entry in ipairs(items) do
        local item = entry
        if not instanceof(item, "InventoryItem") then
            item = entry.items and entry.items[1]
        end
        if not item then
            -- ignore
        else
            if item:getType() == "CmpAlbuminPills" then
                context:addOption(getText("ContextMenu_Take_pills"), item, LabRecipes_CMOnTakeAlbuminPills, player, items)
            end

            if vaccineTypes[item:getType()] then
                context:addOption(getText("ContextMenu_LabInjectVaccine"), item, LabRecipes_CMOnInjectVaccine, player)
            end

            if item:getType() == "LabSyringe" or item:getType() == "LabSyringeReusable" then
                local opt = context:addOption(getText("ContextMenu_LabCollectBloodBlood"), item, LabRecipes_CMOnCollectBlood, player, items)
                LabRecipes_CreateCollectBloodTooltip(opt, player, item)
            end

            if item:getType() == "CmpSyringeReusableWithBlood" or item:getType() == "CmpSyringeWithBlood" then
                local opt = context:addOption(getText("ContextMenu_TestBlood"), item, LabRecipes_CMOnTestBlood, player, items)
                LabRecipes_CreateBloodTestTooltip(opt, player)
            end
        end
    end
end

function LabRecipes_WMOnPutCorpseFromDragging(player, top, bottom)
    if not bottom or not bottom:getSquare() then return end
    if not luautils.walkAdj(player, bottom:getSquare()) then return end
    
    -- Soltar o cadáver
    local dropAction = ISDropCorpseAction:new(player, bottom:getSquare())
    ISTimedActionQueue.add(dropAction)
    
    -- Definir tempo de espera baseado em SP vs MP
    -- Isso é necessário porque no MP o cadáver demora mais para ser criado no mundo
    local waitFrames = isClient() and 280 or 140
    
    -- Aguardar alguns frames e então adicionar ação de colocar na mesa
    local frameCount = 0
    local waitTimer = nil
    
    waitTimer = function()
        frameCount = frameCount + 1
        
        -- Aguarda os frames necessários para o cadáver ser criado
        if frameCount >= waitFrames then
            Events.OnTick.Remove(waitTimer)
            
            -- Procurar cadáver próximo à mesa
            local sq = bottom:getSquare()
            local foundCorpse = nil
            
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local sq2 = getCell():getGridSquare(sq:getX()+dx, sq:getY()+dy, sq:getZ())
                    if sq2 then
                        local bodies = sq2:getDeadBodys()
                        if bodies and bodies:size() > 0 then
                            -- Pega o cadáver mais recente
                            foundCorpse = bodies:get(bodies:size() - 1)
                            break
                        end
                    end
                end
                if foundCorpse then break end
            end
            
            if foundCorpse then
                ISTimedActionQueue.add(LabActionPutCorpseOnTable:new(player, top, bottom, foundCorpse))
            end
        end
    end
    
    Events.OnTick.Add(waitTimer)
end

function LabRecipes_CMOnTakeAlbuminPills(item, player, items)
    if not player then return end
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    ISTimedActionQueue.add(LabActionTakeAlbumin:new(player, item))
end

function LabRecipes_CMOnInjectVaccine(item, player, items)
    if not player then return end
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    ISTimedActionQueue.add(LabActionInjectVaccine:new(player, item))
end

function LabRecipes_CMOnCollectBlood(item, player)
    if not player then return end
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    ISTimedActionQueue.add(LabActionCollectBlood:new(player, item))
end

function LabRecipes_CMOnTestBlood(item, player, items)
    if not player then return end
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    ISTimedActionQueue.add(LabActionTestBlood:new(player, item))
end

function LabRecipes_CreateBloodTestTooltip(option, player)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip = tooltip
    tooltip.description = tooltip.description .. getText("ContextMenu_LabMustHaveItems")
    local nearSpectro = LabRecipes_IsNearSpectrometer()
    tooltip.description = tooltip.description .. string.format("  <%s> %s <RGB:1,1,1> <LINE>", nearSpectro and "GREEN" or "RED", getText("ContextMenu_LabNeedSpectrometer"))
    option.notAvailable = not nearSpectro
end

function LabRecipes_CreateCollectBloodTooltip(option, player, syringe)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip = tooltip
    tooltip.description = tooltip.description .. getText("ContextMenu_LabMustHaveItems")
    local inv = player:getInventory()
    local hasCotton = inv and inv:contains("AlcoholedCottonBalls")
    local hasSyringe = syringe ~= nil
    tooltip.description = tooltip.description .. string.format("  <%s> %s <RGB:1,1,1> <LINE>", hasSyringe and "GREEN" or "RED", getText("ContextMenu_LabNeedSyringe"))
    tooltip.description = tooltip.description .. string.format("  <%s> %s <RGB:1,1,1> <LINE>", hasCotton and "GREEN" or "RED", getText("ContextMenu_LabNeedAlcoholCotton"))
    option.notAvailable = not (hasSyringe and hasCotton)
end

----------------------------------------
-- World Context Menu Helpers
----------------------------------------

local function wearIfNeeded(player, clothing)
    if clothing and not player:isEquippedClothing(clothing) then
        ISInventoryPaneContextMenu.wearItem(clothing, player:getPlayerNum())
    end
end

function LabRecipes_CreateBleachCheckTooltip(option, inventory)
    local bleach = inventory and inventory:getFirstEvalRecurse(predicateBleachEnough)
    local color = bleach and "GREEN" or "RED"
    local name  = getItemNameFromFullType("Base.Bleach")
    option.toolTip.description = option.toolTip.description .. string.format("   <%s> %s (0.2 L) <RGB:1,1,1> <LINE>", color, name)
    return bleach ~= nil
end

local function GetCorpseAgeHours(corpse, player)
    if not corpse or not player then return 999 end
    
    local deathTime = nil
    
    local md = corpse.getModData and corpse:getModData() or {}
    deathTime = md.DeathTime or md.deathTime or md.death_time
    
    if not deathTime and corpse.getDeathTime then
        local ok, t = pcall(function() return corpse:getDeathTime() end)
        if ok and t then deathTime = t end
    end
    
    if not deathTime then
        return 0
    end
    
    local currentTime = getGameTime():getWorldAgeHours()
    local ageHours = currentTime - deathTime
    
    return math.max(0, ageHours)
end

----------------------------------------
-- World Context Menu (Principal)
----------------------------------------

function LabRecipes_BuildZombieWM(playerNum, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then
        return true
    end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local inv = player:getInventory()

    local now = getTimestampMs()
    if LabRecipes_LastContextBuild == now then
        return
    end
    LabRecipes_LastContextBuild = now

    local function safeGetModData(obj)
        if not obj then return {} end
        local ok, md = pcall(function() return obj:getModData() end)
        return (ok and md) and md or {}
    end

    local function safeGetDeathTime(obj)
        if not obj then return nil end
        local md = safeGetModData(obj)
        return md.DeathTime or md.deathTime or md.death_time or nil
    end

    local function isZombieSafe(obj)
        if not obj then return false end
        if obj.isZombie and type(obj.isZombie) == "function" then
            local ok, res = pcall(function() return obj:isZombie() end)
            if ok and res ~= nil then return res end
        end
        local md = safeGetModData(obj)
        return md.Zombie or false
    end

    local function isSkeletonSafe(obj)
        if not obj then return false end
        if obj.isSkeleton and type(obj.isSkeleton) == "function" then
            local ok, res = pcall(function() return obj:isSkeleton() end)
            if ok and res ~= nil then return res end
        end
        local md = safeGetModData(obj)
        return md.Skeleton or false
    end

    local function GetCorpsesFromSquare(sq)
        local result = {}
        local seen = {}

        if not sq then return result end

        local bodies = sq:getDeadBodys()
        if bodies and bodies:size() > 0 then
            for i = 0, bodies:size()-1 do
                local db = bodies:get(i)
                if instanceof(db, "IsoDeadBody") then
                    local id = tostring(db)
                    if not seen[id] then
                        seen[id] = true
                        table.insert(result, db)
                    end
                end
            end
        end

        if #result == 0 then
            local mobs = sq:getStaticMovingObjects()
            if mobs and mobs:size() > 0 then
                for i = 0, mobs:size()-1 do
                    local db = mobs:get(i)
                    if instanceof(db, "IsoDeadBody") then
                        local id = tostring(db)
                        if not seen[id] then
                            seen[id] = true
                            table.insert(result, db)
                        end
                    end
                end
            end
        end

        return result
    end

    for _, v in ipairs(worldobjects) do
        local sq = nil
        if v and type(v.getSquare) == "function" then
            local ok, s = pcall(function() return v:getSquare() end)
            sq = ok and s or nil
        end

        if sq then
            local objsArr = sq:getObjects()
            if objsArr and objsArr:size() > 0 then
                for i = 0, objsArr:size()-1 do
                    local obj = objsArr:get(i)
                    if instanceof(obj, "IsoThumpable") then
                        local sprite = obj:getSprite()
                        local spriteName = sprite and sprite:getName() or nil

                        if spriteName and morgueTable[spriteName] then
                            local top, bottom, status = LabRecipes_GetBedObjects(obj, morgueTable)

                            if top and bottom and status then
                                 if status == "Empty" then
                                    local isDragging = player:isDraggingCorpse()
                                    
                                    -- CASO 1: Jogador está arrastando um cadáver
                                    if isDragging then
                                        context:addOption(
                                            getText("ContextMenu_LabPutCorpseOnTable"),
                                            player,
                                            LabRecipes_WMOnPutCorpseFromDragging,
                                            top, bottom
                                        )
                                    else
                                        -- CASO 2: Cadáver está no chão próximo
                                        local foundCorpse = nil
                                        for dy = -1, 1 do
                                            for dx = -1, 1 do
                                                local sq2 = getCell():getGridSquare(sq:getX()+dx, sq:getY()+dy, sq:getZ())
                                                if sq2 then
                                                    local corpses = GetCorpsesFromSquare(sq2)
                                                    if #corpses > 0 then
                                                        foundCorpse = corpses[1]
                                                        break
                                                    end
                                                end
                                            end
                                            if foundCorpse then break end
                                        end

                                        if foundCorpse then
                                            context:addOption(
                                                getText("ContextMenu_LabPutCorpseOnTable"),
                                                player,
                                                LabRecipes_WMOnPutCorpseOnTable,
                                                top, bottom, foundCorpse
                                            )
                                        end
                                    end

                                elseif status == "Corpse" then
                                    local md = safeGetModData(top)

                                    local deathTime = md.deathTime or md.DeathTime
                                    local currentTime = getGameTime():getWorldAgeHours()

                                    local ageHours = 0
                                    if deathTime then
                                        ageHours = currentTime - deathTime
                                    end

                                    local notFresh = (md.Skeleton == true) or (ageHours > 12)
                                    local wasZombie = md.Zombie
                                    if wasZombie == nil then wasZombie = true end
                                    local notZombie = not wasZombie
                                    local notOrgans = md.Autopsy == true

                                    local opt = context:addOption(
                                        getText("ContextMenu_LabCorpseAutopsy"),
                                        player, LabRecipes_WMOnCorpseAutopsy,
                                        nil, bottom:getSquare(), top, bottom
                                    )

                                    LabRecipes_CreateCorpseAutopsyTooltip(opt, inv, notFresh, notZombie, notOrgans)

                                    local optRemove = context:addOption(
                                        getText("ContextMenu_LabRemoveCorpseFromTable"),
                                        player, LabRecipes_WMOnRemoveCorpseFromTable,
                                        top, bottom
                                    )

                                    LabRecipes_CreateCommonTooltip(optRemove)

                                    local ok = false
                                    ok = LabRecipes_CreateCheckTooltip(optRemove, inv, "Base", {"Garbagebag", "Bag_TrashBag"}, 1) or ok
                                    optRemove.toolTip.description = optRemove.toolTip.description .. getText("ContextMenu_LabMustHaveItemsOr") .. " <LINE>"
                                    ok = LabRecipes_CreateCheckTooltip(optRemove, inv, "Base", {"Plasticbag", "Plasticbag_Bags", "Plasticbag_Clothing"}, 2) or ok

                                    optRemove.notAvailable = not ok

                                elseif status == "Remains" then
                                    local opt = context:addOption(
                                        getText("ContextMenu_LabPutRemainsIntoSack"),
                                        player, LabRecipes_WMOnGrabRemainsFromTable,
                                        top, bottom
                                    )

                                    LabRecipes_CreateCommonTooltip(opt)

                                    local ok = false
                                    ok = LabRecipes_CreateCheckTooltip(opt, inv, "Base", {"Garbagebag", "Bag_TrashBag"}, 1) or ok
                                    opt.toolTip.description = opt.toolTip.description .. getText("ContextMenu_LabMustHaveItemsOr") .. " <LINE>"
                                    ok = LabRecipes_CreateCheckTooltip(opt, inv, "Base", {"Plasticbag", "Plasticbag_Bags", "Plasticbag_Clothing"}, 2) or ok

                                    opt.notAvailable = not ok

                                    -- Submenu para coletar partes específicas
                                    local subMenu = context:addOption(
                                        getText("ContextMenu_LabCollectBodyParts"),
                                        nil, nil
                                    )
                                    
                                    local subContext = ISContextMenu:getNew(context)
                                    context:addSubMenu(subMenu, subContext)
                                    
                                    -- Verificar itens necessários para coleta de partes
                                    local hasScalpel = inv:containsTypeRecurse("Scalpel")
                                    local hasSaw = inv:containsTypeRecurse("Saw")
                                    local hasSack = inv:containsTypeRecurse("Garbagebag")
                                                    or inv:containsTypeRecurse("Bag_TrashBag")
                                    local plasticList = inv:getItemsFromType("Plasticbag")
                                                        or inv:getItemsFromType("Plasticbag_Bags")
                                                        or inv:getItemsFromType("Plasticbag_Clothing")
                                    local hasTwoPlastics = plasticList and plasticList:size() >= 2
                                    
                                    -- Define as partes que podem ser coletadas
                                    local bodyParts = {
                                        {itemType = "RANDOM_BRAIN", text = "ContextMenu_LabCollectBrain"},
                                        {itemType = "LabItems.LabHumanBoneLargeWP", text = "ContextMenu_LabCollectLargeBones"},
                                        {itemType = "LabItems.LabHumanTeeth", text = "ContextMenu_LabCollectTeeth"},
                                        {itemType = "LabItems.LabHumanSkullWithBrain", text = "ContextMenu_LabCollectSkull"},
                                        {itemType = "LabItems.LabSmallRandomHumanBones", text = "ContextMenu_LabCollectSmallBones"},
                                        {itemType = "LabItems.LabRegularHumanBoneWP", text = "ContextMenu_LabCollectRegularBones"},
                                    }
                                    
                                    -- Adicionar cada opção de parte ao submenu
                                    for _, part in ipairs(bodyParts) do
                                        local partOpt = subContext:addOption(
                                            getText(part.text),
                                            player,
                                            LabRecipes_WMOnCollectBodyPart,
                                            top, bottom, part.itemType
                                        )
                                        
                                        LabRecipes_CreateCollectPartTooltip(partOpt, inv, hasScalpel, hasSaw, hasSack, hasTwoPlastics)
                                    end

                                elseif status == "Dirty" then
                                    local opt = context:addOption(
                                        getText("ContextMenu_LabClearMorgueTable"),
                                        player, LabRecipes_WMOnClearMorgueTable,
                                        top, bottom
                                    )

                                    LabRecipes_CreateCommonTooltip(opt)

                                    local okBleach = LabRecipes_CreateBleachCheckTooltip(opt, inv)
                                    opt.toolTip.description = opt.toolTip.description .. getText("ContextMenu_LabMustHaveItemsAnd") .. " <LINE>"

                                    local ok2 = LabRecipes_CreateCheckTooltip(opt, inv, "Base", {"DishCloth"}, 1)
                                    opt.toolTip.description = opt.toolTip.description .. getText("ContextMenu_LabMustHaveItemsOr") .. " <LINE>"
                                    ok2 = LabRecipes_CreateCheckTooltip(opt, inv, "Base", {"BathTowel"}, 1) or ok2

                                    opt.notAvailable = not (okBleach and ok2)
                                end
                            end
                        end
                    end
                end
            end

            local corpsesFound = {}

            for y = sq:getY()-1, sq:getY()+1 do
                for x = sq:getX()-1, sq:getX()+1 do
                    local sq2 = getCell():getGridSquare(x, y, sq:getZ())
                    if sq2 then
                        for _, dead in ipairs(GetCorpsesFromSquare(sq2)) do
                            table.insert(corpsesFound, { dead = dead, sq = sq2 })
                        end
                    end
                end
            end

            if allowAutopsyOnGround == true then
                if #corpsesFound > 0 then
                    local parent = context:addOption(getText("ContextMenu_LabCorpseAutopsy"), worldobjects, nil)
                    local subMenu = ISContextMenu:getNew(context)
                    context:addSubMenu(parent, subMenu)

                    for _, entry in ipairs(corpsesFound) do
                        local dead = entry.dead
                        local sq2 = entry.sq

                        local ageHours = GetCorpseAgeHours(dead, player)
                        local notFresh = isSkeletonSafe(dead) or (ageHours > 12)
                        local notZombie = not isZombieSafe(dead)
                        local mdDead = safeGetModData(dead)
                        local corpseId = nil
                        if dead and dead.getOnlineID then
                            local ok, id = pcall(function() return dead:getOnlineID() end)
                            if ok then corpseId = id end
                        end

                        -- Cria chave COM corpseId
                        local corpseKey = corpseId
                            and string.format("%d_%d_%d_%d", sq2:getX(), sq2:getY(), sq2:getZ(), corpseId)
                            or string.format("%d_%d_%d", sq2:getX(), sq2:getY(), sq2:getZ())

                        -- Verifica cache
                        local notOrgans = mdDead.Autopsy or autopsiedCorpsesCache[corpseKey]

                        local opt = subMenu:addOption(
                            getText("ContextMenu_LabCorpse"),
                            player, LabRecipes_WMOnCorpseAutopsy,
                            dead, sq2, nil, nil
                        )

                        local hc = getCore():getGoodHighlitedColor()

                        opt.onHighlightParams = { dead, hc }

                        opt.onHighlight = function(_option, _menu, _isHighlighted, _object, _color)
                            if not _object then return end

                            if _isHighlighted then
                                _object:setHighlightColor(_menu.player, _color)
                                _object:setOutlineHighlightCol(_menu.player, _color)
                            end

                            _object:setHighlighted(_menu.player, _isHighlighted, false)
                            _object:setOutlineHighlight(_menu.player, _isHighlighted)
                            _object:setOutlineHlAttached(_menu.player, _isHighlighted)

                            ISInventoryPage.OnObjectHighlighted(_menu.player, _object, _isHighlighted)
                        end

                        LabRecipes_CreateCorpseAutopsyTooltip(opt, inv, notFresh, notZombie, notOrgans)
                    end
                end
            end
        end
        
        break
    end
end

----------------------------------------
-- Tooltips / Checks
----------------------------------------
function LabRecipes_CreateCheckTooltip(option, inventory, moduleName, itemName, count, noBroken)
    local itemNames = {}
    if type(itemName) == "table" then
        itemNames = itemName
    else
        itemNames = {itemName}
    end
    
    if not option.toolTip then
        option.toolTip = ISInventoryPaneContextMenu.addToolTip()
        option.toolTip.description = getText("ContextMenu_LabMustHaveItems")
    else
        if option.toolTip.description == "" then
            option.toolTip.description = getText("ContextMenu_LabMustHaveItems")
        end
    end
    
    local totalCount = 0
    for _, iName in ipairs(itemNames) do
        local n = 0
        if noBroken then
            n = inventory:getCountTypeEvalRecurse(iName, predicateNotBroken)
        else
            n = inventory:getItemCountRecurse(iName)
        end
        totalCount = totalCount + n
    end
    
    local displayName = getItemNameFromFullType(moduleName .. "." .. itemNames[1])
    
    option.toolTip.description = option.toolTip.description .. string.format(
        "   <%s> %s ( %d / %d ) <RGB:1,1,1> <LINE>", 
        (totalCount < count) and "RED" or "GREEN", 
        displayName, 
        math_min(totalCount, count), 
        count
    )
    
    return totalCount >= count
end

function LabRecipes_CreateGlovesCheckTooltip(option, inventory, moduleName, itemTypes, noBroken)
    option.toolTip.description = option.toolTip.description .. string.format("%s <LINE>", getText("ContextMenu_LabCategoryGloves"))
    
    local hasAny = false
    for _, v in ipairs(itemTypes) do
        local n
        if noBroken then 
            n = inventory:getCountTypeEvalRecurse(v, predicateNotBroken) 
        else 
            n = inventory:getItemCountRecurse(v) 
        end
        
        if n > 0 then hasAny = true end
        
        local fullType = moduleName .. "." .. v
        local dispName = getItemNameFromFullType(fullType)
        if dispName then
            option.toolTip.description = option.toolTip.description .. string.format("    <%s> %s <RGB:1,1,1> <LINE>", (n < 1) and "RED" or "GREEN", dispName)
        end
    end
    
    return hasAny
end

function LabRecipes_CreateMaskCheckTooltip(option, inventory, moduleName, itemTypes, noBroken)
    option.toolTip.description = option.toolTip.description .. string.format("%s <LINE>", getText("ContextMenu_LabCategoryMask"))
    
    local hasAny = false
    for _, v in ipairs(itemTypes) do
        local n
        if noBroken then 
            n = inventory:getCountTypeEvalRecurse(v, predicateNotBroken) 
        else 
            n = inventory:getItemCountRecurse(v) 
        end
        
        if n > 0 then hasAny = true end
        
        local fullType = moduleName .. "." .. v
        local dispName = getItemNameFromFullType(fullType)
        if dispName then
            option.toolTip.description = option.toolTip.description .. string.format("    <%s> %s <RGB:1,1,1> <LINE>", (n < 1) and "RED" or "GREEN", dispName)
        end
    end
    
    return hasAny
end

function LabRecipes_CreateToolsCheckTooltip(option, inventory, moduleName, itemName, count, noBroken)
    local s = moduleName .. "." .. itemName
    local n
    if noBroken then
        n = inventory:getCountTypeEvalRecurse(itemName, predicateNotBroken)
    else
        n = inventory:getItemCountRecurse(itemName)
    end
    
    option.toolTip.description = option.toolTip.description .. string.format("    <%s> %s ( %d / %d ) <RGB:1,1,1> <LINE>", (n < count) and "RED" or "GREEN", getItemNameFromFullType(s), math_min(n, count), count)
    
    return n >= count
end

function LabRecipes_CreateCorpseAutopsyTooltip(option, inventory, notFresh, notZombie, notOrgans)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip = tooltip
    tooltip.description = tooltip.description .. string.format("%s:  <%s> %s12 %s <LINE> <RGB:1,1,1>", getText("ContextMenu_LabCorpseAge"), notFresh and "RED" or "GREEN", notFresh and ">" or "<", getText("ContextMenu_LabHrs"))
    tooltip.description = tooltip.description .. string.format("%s:  <%s> %s <LINE> <RGB:1,1,1>", getText("ContextMenu_LabWasZombie"), notZombie and "RED" or "GREEN", notZombie and getText("ContextMenu_LabNo") or getText("ContextMenu_LabYes"))
    tooltip.description = tooltip.description .. string.format("%s:  <%s> %s <LINE> <RGB:1,1,1>", getText("ContextMenu_LabAutopsyDone"), notOrgans and "RED" or "GREEN", notOrgans and getText("ContextMenu_LabYes") or getText("ContextMenu_LabNo"))
    tooltip.description = tooltip.description .. getText("ContextMenu_LabMustHaveItems")

    local ok = true
    ok = LabRecipes_CreateMaskCheckTooltip(option, inventory, "Base", {"Hat_SurgicalMask","Hat_DustMask","Hat_GasMask","Hat_BuildersRespirator"}, true) and ok
    ok = LabRecipes_CreateGlovesCheckTooltip(option, inventory, "Base", {"Gloves_Surgical","Gloves_Dish", "Gloves_LeatherGloves","Gloves_LeatherGlovesBlack"}, true) and ok
    
    tooltip.description = tooltip.description .. string.format("%s <LINE>", getText("ContextMenu_LabCategoryTools"))
    ok = LabRecipes_CreateToolsCheckTooltip(option, inventory, "Base", "Scalpel", 1, true) and ok
    ok = LabRecipes_CreateToolsCheckTooltip(option, inventory, "Base", "Tweezers", 1, false) and ok
    
    option.notAvailable = notFresh or notZombie or notOrgans or not ok
end

function LabRecipes_CreateCommonTooltip(option)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip = tooltip
    tooltip.description = tooltip.description .. getText("ContextMenu_LabMustHaveItems")
end

function LabRecipes_CreateCollectPartTooltip(option, inventory, hasScalpel, hasSaw, hasSack, hasTwoPlastics)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip = tooltip
    tooltip.description = tooltip.description .. getText("ContextMenu_LabMustHaveItems")
    
    local ok = true
    
    tooltip.description = tooltip.description .. string.format("%s <LINE>", getText("ContextMenu_LabCategoryTools"))
    
    local scalpelName = getItemNameFromFullType("Base.Scalpel")
    tooltip.description = tooltip.description .. string.format(
        "    <%s> %s ( %d / 1 ) <RGB:1,1,1> <LINE>",
        hasScalpel and "GREEN" or "RED",
        scalpelName,
        hasScalpel and 1 or 0
    )
    ok = ok and hasScalpel
    
    local sawName = getItemNameFromFullType("Base.Saw")
    tooltip.description = tooltip.description .. string.format(
        "    <%s> %s ( %d / 1 ) <RGB:1,1,1> <LINE>",
        hasSaw and "GREEN" or "RED",
        sawName,
        hasSaw and 1 or 0
    )
    ok = ok and hasSaw
    
    local sackName = getItemNameFromFullType("Base.Garbagebag")
                    or getItemNameFromFullType("Base.Bag_TrashBag")
    tooltip.description = tooltip.description .. string.format(
        "  <%s> %s <RGB:1,1,1> <LINE>",
        hasSack and "GREEN" or "RED",
        sackName
    )
    
    tooltip.description = tooltip.description .. getText("ContextMenu_LabMustHaveItemsOr") .. " <LINE>"
    
    local plasticName = getItemNameFromFullType("Base.Plasticbag")
                        or getItemNameFromFullType("Base.Plasticbag_Bags")
                        or getItemNameFromFullType("Base.Plasticbag_Clothing")
    tooltip.description = tooltip.description .. string.format(
        "  <%s> %s (x2) <RGB:1,1,1> <LINE>",
        hasTwoPlastics and "GREEN" or "RED",
        plasticName
    )
    
    ok = ok and (hasSack or hasTwoPlastics)
    
    option.notAvailable = not ok
end

----------------------------------------
-- WM Actions
----------------------------------------

function LabRecipes_WMOnPutCorpseOnTable(player, top, bottom, corpse)
    ISTimedActionQueue.add(LabActionPutCorpseOnTable:new(player, top, bottom, corpse))
end

function LabRecipes_WMOnGrabRemainsFromTable(player, top, bottom)
    if not bottom or not bottom:getSquare() then return end
    if not luautils.walkAdj(player, bottom:getSquare()) then return end
    ISTimedActionQueue.add(LabActionMorgueTableGetRemains:new(player, top, bottom))
end

function LabRecipes_WMOnCollectBodyPart(player, top, bottom, itemType)
    if not bottom or not bottom:getSquare() then return end
    if not luautils.walkAdj(player, bottom:getSquare()) then return end
    
    local inv = player:getInventory()
    if not inv then return end
    
    local scalpel = inv:getFirstTypeEvalRecurse("Scalpel", predicateNotBroken)
    local saw = inv:getFirstTypeRecurse("Saw")
    
    if not scalpel or not saw then return end
    
    ISInventoryPaneContextMenu.transferIfNeeded(player, scalpel)
    ISInventoryPaneContextMenu.transferIfNeeded(player, saw)
       
    ISInventoryPaneContextMenu.equipWeapon(saw, true, false, player:getPlayerNum())
    ISInventoryPaneContextMenu.equipWeapon(scalpel, false, false, player:getPlayerNum())
    
    ISTimedActionQueue.add(LabActionMorgueTableCollectPart:new(player, top, bottom, itemType))
end

function LabRecipes_WMOnClearMorgueTable(player, top, bottom)
    if not bottom or not bottom:getSquare() then return end
    if not luautils.walkAdj(player, bottom:getSquare()) then return end

    local inv = player:getInventory()
    if not inv then return end

    local rag = inv:getFirstTypeRecurse("DishCloth") or inv:getFirstTypeRecurse("BathTowel")
    local bleach = inv:getFirstTypeRecurse("Bleach")

    ISInventoryPaneContextMenu.transferIfNeeded(player, rag)
    ISInventoryPaneContextMenu.transferIfNeeded(player, bleach)

    if rag then ISInventoryPaneContextMenu.equipWeapon(rag, true, false, player:getPlayerNum()) end
    if bleach then ISInventoryPaneContextMenu.equipWeapon(bleach, false, false, player:getPlayerNum()) end

    ISTimedActionQueue.add(LabActionMorgueTableClear:new(player, top, bottom))
end

function LabRecipes_WMOnCorpseAutopsy(player, corpse, square, top, bottom)
    local canCorpse = corpse and corpse:getSquare() and luautils.walkAdj(player, corpse:getSquare())
    local canTable  = bottom and bottom:getSquare() and luautils.walkAdj(player, bottom:getSquare())
    if not (canCorpse or canTable) then return end

    local inv = player:getInventory()
    if not inv then return end

    local mask = inv:getFirstTypeEvalRecurse("Hat_SurgicalMask", predicateNotBroken)
              or inv:getFirstTypeEvalRecurse("Hat_DustMask", predicateNotBroken)
              or inv:getFirstTypeEvalRecurse("Hat_GasMask", predicateNotBroken)
              or inv:getFirstTypeEvalRecurse("Hat_BuildersRespirator", predicateNotBroken)

    local gloves = inv:getFirstTypeEvalRecurse("Gloves_Surgical", predicateNotBroken)
              or inv:getFirstTypeEvalRecurse("Gloves_Dish", predicateNotBroken)
              or inv:getFirstTypeEvalRecurse("Gloves_LeatherGloves", predicateNotBroken)
              or inv:getFirstTypeEvalRecurse("Gloves_LeatherGlovesBlack", predicateNotBroken)

    local scalpel  = inv:getFirstTypeEvalRecurse("Scalpel",  predicateNotBroken)
    local tweezers = inv:getFirstTypeEvalRecurse("Tweezers", predicateNotBroken)
    if not scalpel or not tweezers then return end

    wearIfNeeded(player, mask)
    wearIfNeeded(player, gloves)
    
    ISInventoryPaneContextMenu.equipWeapon(scalpel, true, false, player:getPlayerNum())
    ISInventoryPaneContextMenu.equipWeapon(tweezers, false, false, player:getPlayerNum())

    ISTimedActionQueue.add(LabActionMakeAutopsy:new(player, corpse, square, top, bottom))
end

function LabRecipes_WMOnRemoveCorpseFromTable(player, top, bottom)
    if not bottom or not bottom:getSquare() then return end
    if not luautils.walkAdj(player, bottom:getSquare()) then return end
    ISTimedActionQueue.add(LabActionMorgueTableRemoveCorpse:new(player, top, bottom))
end

----------------------------------------
-- Event Registration
----------------------------------------

Events.OnFillWorldObjectContextMenu.Add(LabRecipes_BuildZombieWM)
Events.OnFillInventoryObjectContextMenu.Add(LabRecipes_BuildInventoryCM)

----------------------------------------
-- Export
----------------------------------------

LabModEngine = LabModEngine or {}
LabModEngine.autopsiedCorpsesCache = autopsiedCorpsesCache