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

SuburbsDistributions.foresthut = {
	crate =
	{
		rolls = 1,
		items = {
			"ApocalypseMagazineWood", 100,
		}
	},
}

SuburbsDistributions.metalfence = {
	shelves =
	{
		rolls = 1,
		items = {
			"ApocalypseMagazineMetal", 100,
		}
	},
}

SuburbsDistributions.passwordbook = {
	crate =
	{
		rolls = 1,
		items = {
			"RaccoonCityPassWordBook", 100,
		}
	},
}

local function GunstoreDabaojian()
	SuburbsDistributions.gunstorehide = {
		knifeshelf = 
		{
			rolls = 1,
			items = {
				"dabaojian", 100
			}
		},
		militarycrate = 
		{
			rolls = 1,
			items = {
				"dabaojian", 50
			}
		}
	}
end 



SuburbsDistributions.rpackroom = {
	backpack_rack =
	{
		rolls = 1,
		items = {
			"ResidentEvilBackPack", 100,
		}
	},
}

SuburbsDistributions.SolarEnergy = {
	metal_shelves =
	{
		rolls = 9,
		items = {
			"ISA.SolarPanel", 27,
			"MetalBar", 27,
			"ElectricWire", 37,
			"ISA.WiredCarBattery", 3,
			"ISA.DIYBattery", 3,
			"ISA.ISAMag1", 3,
		}
	},
}

SuburbsDistributions.tissueshop = {
	shelves =
	{
		rolls = 10,
		items = {
			"ToiletPaper", 100,
		}
	},
}

SuburbsDistributions.swordshop = {
    shelves = {
        rolls = 1,
        items = {
            "Machete", 90,
            "Katana", 9,
        }
    }
}
local function SwordshopDabaojian()
	table.insert(SuburbsDistributions.swordshop.shelves.items, {"dabaojian", 1})
end 



local function BiochemlabVaccines()
	SuburbsDistributions.biochemlab = {
		VaccineCabinet = 
		{
			rolls = 1,
			items = {
				"BiochemicalVaccines", 100
			}
		},
		metal_shelves = 
		{
			rolls = 1,
			items = {
				"BiochemicalVaccines", 100
			}
		}
	}
end 



SuburbsDistributions.seafood = {
	seafoodshelves =
	{
		rolls = 10,
		items = {
			"Panfish", 20,
			"BaitFish", 20,
			"Squid", 20,
			"Catfish", 20,
			"Trout", 19,
			"Pike", 1,
		}
	},
}

SuburbsDistributions.secretslaughter = {
	metal_shelves =
	{
		rolls = 3,
		items = {
			"LargeHook", 100,
		}
	},
}

SuburbsDistributions.DeanSecureRoom = {
	crate =
	{
		rolls = 1,
		items = {
			"ResidentEvilSuspenders", 100,
		}
	},
}

SuburbsDistributions.basketball = {
	cardboardbox =
	{
		rolls = 20,
		items = {
			"Basketball", 100,
		}
	},
}

SuburbsDistributions.tophidden2 = {
	militarylocker =
	{
		rolls = 12,
		items = {
			"223Box", 11,
			"308Box", 11,
			"Bullets38Box", 11,
			"Bullets44Box", 11,
			"Bullets45Box", 11,
			"556Box", 11,
			"Bullets9mmBox", 11,
			"ShotgunShellsBox", 14,
			"223Carton", 1,
			"308Carton", 1,
			"Bullets38Carton", 1,
			"Bullets44Carton", 1,
			"Bullets45Carton", 1,
			"556Carton", 1,
			"Bullets9mmCarton", 1,
			"ShotgunShellsCarton", 2,
		}
	},
	militarycrate =
	{
		rolls = 12,
		items = {
			"223Box", 11,
			"308Box", 11,
			"Bullets38Box", 11,
			"Bullets44Box", 11,
			"Bullets45Box", 11,
			"556Box", 11,
			"Bullets9mmBox", 11,
			"ShotgunShellsBox", 14,
			"223Carton", 1,
			"308Carton", 1,
			"Bullets38Carton", 1,
			"Bullets44Carton", 1,
			"Bullets45Carton", 1,
			"556Carton", 1,
			"Bullets9mmCarton", 1,
			"ShotgunShellsCarton", 2,
		}
	},
	metal_shelves =
	{
		rolls = 12,
		items = {
			"223Box", 11,
			"308Box", 11,
			"Bullets38Box", 11,
			"Bullets44Box", 11,
			"Bullets45Box", 11,
			"556Box", 11,
			"Bullets9mmBox", 11,
			"ShotgunShellsBox", 14,
			"223Carton", 1,
			"308Carton", 1,
			"Bullets38Carton", 1,
			"Bullets44Carton", 1,
			"Bullets45Carton", 1,
			"556Carton", 1,
			"Bullets9mmCarton", 1,
			"ShotgunShellsCarton", 2,
		}
	},
}

SuburbsDistributions.HideTyrant = {
	militarycrate =
	{
		rolls = 3,
		items = {
			"223Box", 11,
			"308Box", 11,
			"Bullets38Box", 11,
			"Bullets44Box", 11,
			"Bullets45Box", 11,
			"556Box", 11,
			"Bullets9mmBox", 11,
			"ShotgunShellsBox", 14,
			"223Carton", 1,
			"308Carton", 1,
			"Bullets38Carton", 1,
			"Bullets44Carton", 1,
			"Bullets45Carton", 1,
			"556Carton", 1,
			"Bullets9mmCarton", 1,
			"ShotgunShellsCarton", 2,
		}
	},
}

SuburbsDistributions.ConstructionSite = {
	Cement =
	{
		rolls = 3,
		items = {
			"ConcretePowder", 100,
		}
	},
}

SuburbsDistributions.charcoalstore = {
	crate =
	{
		rolls = 6,
		items = {
			"Charcoal", 50,
			"CharcoalCrafted", 50,
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

Events.OnPreDistributionMerge.Add(SpawnAll)
