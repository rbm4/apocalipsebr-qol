local CTPDef = {
-- use all for specific containers that spawn the same loot reguardless of location

    all = {
		
		 ExoticPot = {
            rolls = 1,
            items = {        
                "TheBong", 50, 
                "Greenfire.Cannabis", 100,
                "Greenfire.Cannabis", 100,
                "Greenfire.Cannabis", 100,                      
            }
        },
		
		Rusty = {
            rolls = 1,
            items = {        
                "Rusty", 100,                     
            }
        },
		
		WireShelves = {
			procedural = true,
			procList = {
				{name="Antiques", min=0, max=1, weightChance=1},
				{name="BurglarTools", min=0, max=1, weightChance=1},
				{name="CrateCamping", min=0, max=1, weightChance=1},
				{name="CrateCostume", min=0, max=1, weightChance=1},
				{name="CrateMannequins", min=0, max=1, weightChance=1},
				{name="Hiker", min=0, max=1, weightChance=1},
				{name="Homesteading", min=0, max=1, weightChance=1},
				{name="Hunter", min=0, max=1, weightChance=1},
				{name="MechanicSpecial", min=0, max=1, weightChance=1},
				{name="SurvivalGear", min=0, max=1, weightChance=1},
				{name="Trapper", min=0, max=1, weightChance=1},
				{name="ArtSupplies", min=0, max=1, weightChance=5},
				{name="Chemistry", min=0, max=1, weightChance=5},
				{name="CrateCanning", min=0, max=1, weightChance=5},
				{name="CrateDishes", min=0, max=1, weightChance=5},
				{name="CrateInstruments", min=0, max=1, weightChance=5},
				{name="CrateLinens", min=0, max=1, weightChance=5},
				{name="CratePetSupplies", min=0, max=1, weightChance=5},
				{name="CratePhotos", min=0, max=1, weightChance=5},
				{name="CrateSports", min=0, max=1, weightChance=5},
				{name="CrateToys", min=0, max=1, weightChance=5},
				{name="EngineerTools", min=0, max=1, weightChance=5},
				{name="FitnessTrainer", min=0, max=1, weightChance=5},
				{name="Gifts", min=0, max=1, weightChance=5},
				{name="Hobbies", min=0, max=1, weightChance=5},
				{name="HolidayStuff", min=0, max=1, weightChance=5},
				{name="ImprovisedCrafts", min=0, max=1, weightChance=5},
				{name="JunkHoard", min=0, max=1, weightChance=5},
				{name="Photographer", min=0, max=1, weightChance=5},
				{name="PlumbingSupplies", min=0, max=1, weightChance=5},
				{name="ScienceMisc", min=0, max=1, weightChance=5},
				{name="VacationStuff", min=0, max=1, weightChance=5},
				{name="WallDecor", min=0, max=1, weightChance=5},
				{name="CrateComputer", min=0, max=1, weightChance=10},
				{name="CrateTV", min=0, max=1, weightChance=10},
				{name="CrateTVWide", min=0, max=1, weightChance=10},
				{name="CrateElectronics", min=0, max=1, weightChance=10},
				{name="ClothingStorageWinter", min=0, max=1, weightChance=10},
				{name="CrateClothesRandom", min=0, max=1, weightChance=10},
				{name="CrateFootwearRandom", min=0, max=1, weightChance=10},
				{name="CrateBlacksmithing", min=0, max=1, weightChance=1},
				{name="CrateCarpentry", min=0, max=1, weightChance=10},
				{name="CrateFarming", min=0, max=1, weightChance=10},
				{name="CrateFishing", min=0, max=1, weightChance=10},
				{name="CrateMechanics", min=0, max=1, weightChance=10},
				{name="CrateMetalwork", min=0, max=1, weightChance=10},
				{name="CrateTailoring", min=0, max=1, weightChance=10},
				{name="CrateTools", min=0, max=1, weightChance=10},
				{name="CrateToolsOld", min=0, max=1, weightChance=20},
				{name="CrateFabric_Cotton", min=0, max=1, weightChance=1},
				{name="CrateFabric_DenimBlack", min=0, max=1, weightChance=1},
				{name="CrateFabric_DenimBlue", min=0, max=1, weightChance=1},
				{name="CrateFabric_DenimDarkBlue", min=0, max=1, weightChance=1},
				{name="CrateRandomJunk", min=0, max=4, weightChance=60},
			}
		},
		
		extinguisher_box = {
			rolls = 1,
			items = {
				"Extinguisher",100,
			}
		},
		
		SpoonRack = {
			rolls = 8,
			items = {
				"Ladle", 25,
				"Ladle", 25,
				"Whisk", 10,
				"GrillBrush", 10,
				"Spatula", 10,
				"CarvingFork2", 10,
				"BreadKnife", 5,
				"MeatCleaver", 5,
				"KitchenTongs", 1,
				"PizzaCutter", 1,
				"SteakKnife", 1,
				"LargeKnife", 1,
				"KitchenKnife", 1,
				"KnifeFillet", 1,
				"KnifeParing", 1,
			}
		},		
		
		StandingToolbox = {
			procedural = true,
			procList = {
				{name="ToolCabinetMechanics", min=0, max=99, weightChance=20},
				{name="Bag_JanitorToolbox", min=0, max=99, weightChance=20},
				{name="CrateTools", min=0, max=99, weightChance=20},
				{name="WeldingWorkshopTools", min=0, max=99, weightChance=20},
				{name="CarSupplyTools", min=0, max=99, weightChance=20},
				{name="CrateToolsOld", min=0, max=1, weightChance=10},
			}
		},
		
		ToolTray = {
			procedural = true,
			procList = {
				{name="ToolCabinetMechanics", min=0, max=99, weightChance=20},
				{name="Bag_JanitorToolbox", min=0, max=99, weightChance=20},
				{name="CrateTools", min=0, max=99, weightChance=20},
				{name="WeldingWorkshopTools", min=0, max=99, weightChance=20},
				{name="CarSupplyTools", min=0, max=99, weightChance=20},
				{name="BurglarTools", min=0, max=1, weightChance=10},
				{name="CrateToolsOld", min=0, max=1, weightChance=10},
				{name="EngineerTools", min=0, max=1, weightChance=10},
			}
		},
		
		Safe = {
			procedural = true,
			procList = {
				{name="BankDeposit", min=0, max=1, weightChance=10},
				{name="CarDealerDesk", min=0, max=1, weightChance=10},
				{name="DerelictHouseCrime", min=0, max=1, weightChance=10},
				{name="DrugLabMoney", min=0, max=1, weightChance=10},
				{name="PlankStashMoney", min=0, max=1, weightChance=10},
				{name="PoliceEvidence", min=0, max=1, weightChance=10},
			}
		},
		
	},
	
	kitchen = {
		WireShelves = {
			rolls = 10,
			items = {
				"Pot", 20,
				"BakingPan", 20,
				"BakingTray", 20,
				"MuffinTray", 20,
				"Bowl", 10,
				"Saucepan", 8,
				"SaucepanCopper", 5,
			}
		},
	},
}

table.insert(Distributions, 2, CTPDef);