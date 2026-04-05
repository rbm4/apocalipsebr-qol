-- LabSharedUtils.lua
-- Dados e funções compartilhadas entre cliente e servidor

----------------------------------------
-- Tabela de Sprites da Mesa de Necropsia
----------------------------------------

morgueTable = {
    location_community_medical_01_76 = { Top = true,  East = true,  Adj = "location_community_medical_01_77", Swap = "demonius_vaccine_01_72", Status = "Empty" },
    location_community_medical_01_77 = { Top = false, East = true,  Adj = "location_community_medical_01_76", Swap = "demonius_vaccine_01_73", Status = "Empty" },
    location_community_medical_01_79 = { Top = true,  East = false, Adj = "location_community_medical_01_78", Swap = "demonius_vaccine_01_75", Status = "Empty" },
    location_community_medical_01_78 = { Top = false, East = false, Adj = "location_community_medical_01_79", Swap = "demonius_vaccine_01_74", Status = "Empty" },

    demonius_vaccine_01_72 = { Top = true,  East = true,  Adj = "demonius_vaccine_01_73", Swap = "demonius_vaccine_01_76", Status = "Corpse" },
    demonius_vaccine_01_73 = { Top = false, East = true,  Adj = "demonius_vaccine_01_72", Swap = "demonius_vaccine_01_77", Status = "Corpse" },
    demonius_vaccine_01_75 = { Top = true,  East = false, Adj = "demonius_vaccine_01_74", Swap = "demonius_vaccine_01_79", Status = "Corpse" },
    demonius_vaccine_01_74 = { Top = false, East = false, Adj = "demonius_vaccine_01_75", Swap = "demonius_vaccine_01_78", Status = "Corpse" },

    demonius_vaccine_01_76 = { Top = true,  East = true,  Adj = "demonius_vaccine_01_77", Swap = "demonius_vaccine_01_80", Status = "Remains" },
    demonius_vaccine_01_77 = { Top = false, East = true,  Adj = "demonius_vaccine_01_76", Swap = "demonius_vaccine_01_81", Status = "Remains" },
    demonius_vaccine_01_79 = { Top = true,  East = false, Adj = "demonius_vaccine_01_78", Swap = "demonius_vaccine_01_83", Status = "Remains" },
    demonius_vaccine_01_78 = { Top = false, East = false, Adj = "demonius_vaccine_01_79", Swap = "demonius_vaccine_01_82", Status = "Remains" },

    demonius_vaccine_01_80 = { Top = true,  East = true,  Adj = "demonius_vaccine_01_81", Swap = "location_community_medical_01_76", Status = "Dirty" },
    demonius_vaccine_01_81 = { Top = false, East = true,  Adj = "demonius_vaccine_01_80", Swap = "location_community_medical_01_77", Status = "Dirty" },
    demonius_vaccine_01_83 = { Top = true,  East = false, Adj = "demonius_vaccine_01_82", Swap = "location_community_medical_01_79", Status = "Dirty" },
    demonius_vaccine_01_82 = { Top = false, East = false, Adj = "demonius_vaccine_01_83", Swap = "location_community_medical_01_78", Status = "Dirty" },
}

----------------------------------------
-- Constantes de Itens
-- Listas centralizadas para evitar espalhar 'or getItemFromType(...)' pelo código
----------------------------------------

LabConst = LabConst or {}

-- EPIs
LabConst.MASKS  = { "Hat_SurgicalMask", "Hat_DustMask", "Hat_GasMask", "Hat_BuildersRespirator" }
LabConst.GLOVES = { "Gloves_Surgical", "Gloves_Dish", "Gloves_LeatherGloves", "Gloves_LeatherGlovesBlack" }

-- Recipientes
LabConst.SACKS    = { "Garbagebag", "Bag_TrashBag" }
LabConst.PLASTICS = { "Plasticbag", "Plasticbag_Bags", "Plasticbag_Clothing" }

-- Ferramentas de limpeza
LabConst.TOOLS_CLEAN  = { "DishCloth", "BathTowel" }

-- Líquidos de limpeza aceitos (espelha predicateCleaningLiquid do vanilla)
LabConst.FLUIDS_CLEAN = { Fluid.Bleach, Fluid.CleaningLiquid }

-- Tempo
LabConst.AUTOPSY_MAX_HOURS = 12

----------------------------------------
-- Helpers de Player / Inventário
----------------------------------------

function LabRecipes_GetPlayerSafe(player)
    return player or getPlayer()
end

function LabRecipes_GetInvSafe(player)
    local pl = LabRecipes_GetPlayerSafe(player)
    if pl and pl.getInventory then
        return pl:getInventory()
    end
    return nil
end

----------------------------------------
-- Helpers de Item
----------------------------------------

--- Retorna o primeiro nome encontrado numa lista de tipos.
function LabRecipes_GetFirstItemName(types, moduleName)
    local prefix = moduleName and (moduleName .. ".") or ""
    for _, t in ipairs(types) do
        local name = getItemNameFromFullType(prefix .. t)
        if name then return name end
    end
    return types[1] -- fallback: retorna o próprio tipo se nenhum nome for encontrado
end

--- Busca o primeiro item encontrado numa lista de tipos dentro do inventário.
function LabRecipes_GetFirstEquip(inv, types, predicate)
    for _, t in ipairs(types) do
        local item = predicate
            and inv:getFirstTypeEvalRecurse(t, predicate)
            or  inv:getFirstTypeRecurse(t)
        if item then return item end
    end
    return nil
end

--- Conta o total de itens somando todos os tipos da lista.
function LabRecipes_CountItemsFromList(inv, types)
    local total = 0
    for _, t in ipairs(types) do
        local list = inv:getItemsFromType(t)
        if list then total = total + list:size() end
    end
    return total
end

--- Retorna uma tabela com os itens encontrados, ou nil se não atingir o limite.
function LabRecipes_CollectItemsFromList(inv, types, limit)
    local collected = {}
    for _, t in ipairs(types) do
        local list = inv:getItemsFromType(t)
        if list then
            for i = 0, list:size()-1 do
                table.insert(collected, list:get(i))
                if #collected >= limit then return collected end
            end
        end
    end
    return #collected >= limit and collected or nil
end

----------------------------------------
-- Morgue Table Helpers
----------------------------------------

function LabRecipes_GetBedObjects(source, bedTable)
    if not source or not source:getSprite() then return nil end

    local spriteName = source:getSprite():getName()
    local curBed = bedTable[spriteName]
    if not curBed then return nil end

    local top    = curBed.Top and source or nil
    local bottom = (not curBed.Top) and source or nil

    local x, y = 0, 0
    if curBed.East then
        x = curBed.Top and 1 or -1
    else
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

----------------------------------------
-- Predicates Compartilhados
----------------------------------------

function LabRecipes_PredicateNotBroken(item)
    return item and not item:isBroken()
end

function LabRecipes_PredicateCleaningLiquidEnough(item)
    if not item then return false end
    if not item:hasComponent(ComponentType.FluidContainer) then return false end
    local fc = item:getFluidContainer()
    if not fc then return false end
    for _, fluid in ipairs(LabConst.FLUIDS_CLEAN) do
        if fc:contains(fluid) and fc:getAmount() >= 0.2 then
            return true
        end
    end
    return false
end

function LabRecipes_PredicateBleachEnough(item)
    return LabRecipes_PredicateCleaningLiquidEnough(item)
end

----------------------------------------
-- HOOK
----------------------------------------
function labHook(obj, hooks)
    if not obj or not hooks then return end

    for methodName, wrapper in pairs(hooks) do
        local orig = obj[methodName]
        if type(orig) == "function" then
            if type(wrapper) == "function" then
                obj[methodName] = function(...)
                    return wrapper(orig, ...)
                end
            else
                print("[ZVirusVaccine]: " .. tostring(methodName) .. " IS NOT A WRAPPER: " .. tostring(type(wrapper)))
            end
        else
            print("[ZVirusVaccine]: " .. tostring(methodName) .. " IS NOT A FUNCTION: " .. tostring(type(orig)))
        end
    end
end