
local function CheckDrops(zombie)
    if not zombie:getOutfitName() then return false end
    local outfit = tostring(zombie:getOutfitName())
    local inv = zombie:getInventory()

    if outfit == "Daisycounty_Master" then
        if 10 >= ZombRand(1, 100) then
            inv:AddItem("Base.MasterCrowbar")
        end
        if 100 >= ZombRand(1, 100) then
            inv:AddItem("Base.StockingsBlack")
        end
       if 100 >= ZombRand(1, 100) then
            inv:AddItem("Base.RippedSheetsDirty")
        end
       if 100 >= ZombRand(1, 100) then
            inv:AddItem("Base.MaleKeyRing")
        end
       if 50 >= ZombRand(1, 100) then
            inv:AddItem("Base.manghe")
        end
    end
    if outfit == "Daisycounty_FMaster" then
        if 10 >= ZombRand(1, 100) then
            inv:AddItem("Base.MasterCrowbar")
        end
        if 100 >= ZombRand(1, 100) then
            inv:AddItem("Base.StockingsBlack")
        end
       if 100 >= ZombRand(1, 100) then
            inv:AddItem("Base.RippedSheetsDirty")
        end
       if 100 >= ZombRand(1, 100) then
            inv:AddItem("Base.FemaleKeyRing")
        end
       if 50 >= ZombRand(1, 100) then
            inv:AddItem("Base.manghe")
        end
    end
end
	
 

Events.OnZombieDead.Add(CheckDrops)