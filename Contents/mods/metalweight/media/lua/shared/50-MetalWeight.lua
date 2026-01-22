
local newscript = ScriptManager.instance

local function wy50metalOnGameBoot()
	newscript:getItem("Base.SheetMetal"):DoParam("Weight = 0.75")
    newscript:getItem("Base.MetalBar"):DoParam("Weight = 0.75")
    newscript:getItem("Base.MetalDrum"):DoParam("Weight = 1")
    newscript:getItem("Base.MetalPipe"):DoParam("Weight = 0.75")
    newscript:getItem("Base.ScrapMetal"):DoParam("Weight = 0.05")
    newscript:getItem("Base.SmallSheetMetal"):DoParam("Weight = 0.2")
    newscript:getItem("Base.UnusableMetal"):DoParam("Weight = 0.5")
    newscript:getItem("Base.WeldingRods"):DoParam("Weight = 0.75")
    newscript:getItem("Base.IronIngot"):DoParam("Weight = 2.5")
    newscript:getItem("Base.LeadPipe"):DoParam("Weight = 0.75")
    newscript:getItem("Base.BarbedWire"):DoParam("Weight = 0.5")
    newscript:getItem("Base.Wire"):DoParam("Weight = 0.1")
end

Events.OnGameBoot.Add(wy50metalOnGameBoot)