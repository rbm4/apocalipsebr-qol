-- LabModData_Shared.lua
-- Dados e funções compartilhadas entre cliente e servidor

----------------------------------------
-- Tabela de Sprites da Mesa de Morgue
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
-- Helpers Compartilhados
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
-- Morgue Table Helpers
----------------------------------------

function LabRecipes_GetBedObjects(source, bedTable)
    if not source or not source:getSprite() then return nil end

    local spriteName = source:getSprite():getName()
    local curBed = bedTable[spriteName]
    if not curBed then return nil end

    local top = curBed.Top and source or nil
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

function LabRecipes_PredicateBleachEnough(item)
    if not item then return false end
    if not item:hasComponent(ComponentType.FluidContainer) then return false end
    local fc = item:getFluidContainer()
    if not fc then return false end
    return fc:contains(Fluid.Bleach) and fc:getAmount() >= 0.2
end