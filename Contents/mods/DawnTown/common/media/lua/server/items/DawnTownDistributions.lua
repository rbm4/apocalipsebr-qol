require "Items/Distributions"

SuburbsDistributions.stonewarehouse = {
	metal_shelves =
	{
		rolls = 8,
		items = {
			"Stone2", 100,
		}
	},
	stoneshelves =
	{
		rolls = 8,
		items = {
			"Stone2", 100,
		}
	},
}


local function SpawnAll()
	if not SandboxVars.DisableDaBaoJian then 
		GunstoreDabaojian()
	end 
	if not SandboxVars.DisableDaBaoJian then 
		SwordshopDabaojian()
	end 
	if not SandboxVars.DisableVaccines then 
		BiochemlabVaccines()
	end 
end 

--Events.OnPreDistributionMerge.Add(SpawnAll)
