local PertsRoomDef = {
-- use all for specific containers that spawn the same loot reguardless of location
-- Lu5ck 3 hours ago I don't know why a tile pack now has distribution table....

    all = {
	
		TrophyCase = {
			rolls = 5,
			items = {
				"Perts.Trophy1", 50,
				"Perts.Trophy2", 50,
			}
		},
	
		FireplaceToolsRack = {
			rolls = 4,
			items = {
				"Base.CrazedRamblings", 100,				
			}
		},
			
        PaperTray = {
            rolls = 20,
            items = {
                "Perts.CrazedRamblings", 100,
				"Perts.CrazedRamblings2", 75,
				"Perts.CrazedRamblings3", 50,
				"Perts.CrazedRamblings4", 75,
                   }
            },
			
		EmergencyAxe = {
			rolls = 2,
			items = {
				"Perts.OverlookFireAxe", 100,
			}
		},
		
		spongeshelf = {
			rolls = 20,
			items = {
					"Base.Sponge", 5,
			}
		},
		
		LegalShelf = {
			rolls = 10,
			items = {
				"Perts.LegalBook", 50,
				"BluePen", 8,
				"Eraser", 8,
				"Magazine", 10,
				"MagazineCrossword1", 2,
				"MagazineCrossword2", 2,
				"MagazineCrossword3", 2,
				"MagazineWordsearch1", 2,
				"MagazineWordsearch2", 2,
				"MagazineWordsearch3", 2,
			}
		},
	
				
    },
	
	-- internal room name
	crochroom = {
	isShop = false,
		counter = {
			rolls = 1,
			items = {
				"Base.Cockroach",0.5
				}
			},
		
		stove  = {
			rolls = 1,
			items = {
				"Base.Cockroach",0.5
				}
			},
			
		crate  = {
			rolls = 1,
			items = {
				"Base.Cockroach",0.5
				}
			},
		
		medicine  = {
			rolls = 1,
			items = {
				"Base.Cockroach",0.5
				}
			},
	},
	
	furyroad = {
	isShop = true,
	
		shelves = {
			rolls = 3,
			items = {
				"Hat_RidingHelmet", 0.2,
				"Hat_CrashHelmet_Police", 0.01,
				"Hat_Bandana", 1,
				"Hat_BandanaMask", 1,
				"Hat_BandanaTINT", 1,
				"Hat_CrashHelmetFULL", 0.01,
				"Jacket_Black", 6,
				"Shoes_ArmyBoots", 6,
				"Shoes_BlackBoots", 6,
				"Trousers_Denim", 6,
				"Trousers_JeanBaggy", 10,
				"JacketLong_Random", 10,
				"Jacket_LeatherBarrelDogs", 0.5,
				"Jacket_LeatherIronRodent", 0.5,
				"Jacket_LeatherWildRacoons", 0.5,
				"TrousersMesh_Leather", 4,
				"Trousers_LeatherBlack", 4,
				"Gloves_FingerlessGloves", 0.1,
				"Gloves_LeatherGloves", 0.05,
				"Gloves_LeatherGlovesBlack", 0.05,
				"Glasses_Aviators", 1,
				"Shirt_Denim", 0.8,
				"Perts.Pert_BulletBelt", 1,
				}
				
		
		},
		
		metal_shelves = {
			rolls = 5,
			items = {
				"Hat_RidingHelmet", 0.2,
				"Hat_CrashHelmet_Police", 0.01,
				"Hat_Bandana", 1,
				"Hat_BandanaMask", 1,
				"Hat_BandanaTINT", 1,
				"Hat_CrashHelmetFULL", 0.01,
				"Jacket_Black", 6,
				"Shoes_ArmyBoots", 6,
				"Shoes_BlackBoots", 6,
				"Trousers_Denim", 6,
				"Trousers_JeanBaggy", 10,
				"JacketLong_Random", 10,
				"Jacket_LeatherBarrelDogs", 0.5,
				"Jacket_LeatherIronRodent", 0.5,
				"Jacket_LeatherWildRacoons", 0.5,
				"TrousersMesh_Leather", 4,
				"Trousers_LeatherBlack", 4,
				"Gloves_FingerlessGloves", 0.1,
				"Gloves_LeatherGloves", 0.05,
				"Gloves_LeatherGlovesBlack", 0.05,
				"Glasses_Aviators", 1,
				"Shirt_Denim", 0.8,
				"Perts.Pert_BulletBelt", 1,
			}
		
		},
		
		clothingrack = {
			rolls = 10,
			items = {
				"Jacket_Black", 6,
				"Trousers_Denim", 6,
				"Trousers_JeanBaggy", 10,
				"JacketLong_Random", 10,
				"Jacket_LeatherBarrelDogs", 0.5,
				"Jacket_LeatherIronRodent", 0.5,
				"Jacket_LeatherWildRacoons", 0.5,
				"TrousersMesh_Leather", 4,
				"Trousers_LeatherBlack", 4,
				"Gloves_FingerlessGloves", 0.1,
				"Gloves_LeatherGloves", 0.05,
				"Gloves_LeatherGlovesBlack", 0.05,
				"Shirt_Denim", 0.8,
				"Perts.Pert_BulletBelt", 1,
			}
		
		},
		
		displaycase = {
			rolls = 5,
			items = {
				"Hat_Bandana", 1,
				"Hat_BandanaMask", 1,
				"Hat_BandanaTINT", 1,
				"Gloves_FingerlessGloves", 0.1,
				"Gloves_LeatherGloves", 0.05,
				"Gloves_LeatherGlovesBlack", 0.05,
				"Glasses_Aviators", 1,
				"Perts.Pert_BulletBelt", 0.01,
			}
		},
		
		militarycrate = {
			rolls = 3,
			items = {
				"Jacket_Black", 6,
				"Shoes_ArmyBoots", 6,
				"Shoes_BlackBoots", 6,
				"Trousers_Denim", 6,
				"Trousers_JeanBaggy", 10,
				"JacketLong_Random", 10,
				"Gloves_FingerlessGloves", 0.1,
				"Gloves_LeatherGloves", 0.05,
				"Gloves_LeatherGlovesBlack", 0.05,
				"Shirt_Denim", 0.8,
			}
		
		},
		
		crate = {
			rolls = 15,
			items = {
				"Hat_RidingHelmet", 0.2,
				"Hat_CrashHelmet_Police", 0.01,
				"Hat_Bandana", 1,
				"Hat_BandanaMask", 1,
				"Hat_BandanaTINT", 1,
				"Hat_CrashHelmetFULL", 0.01,
				"Jacket_Black", 6,
				"Shoes_ArmyBoots", 6,
				"Shoes_BlackBoots", 6,
				"Trousers_Denim", 6,
				"Trousers_JeanBaggy", 10,
				"JacketLong_Random", 10,
				"Jacket_LeatherBarrelDogs", 0.5,
				"Jacket_LeatherIronRodent", 0.5,
				"Jacket_LeatherWildRacoons", 0.5,
				"TrousersMesh_Leather", 4,
				"Trousers_LeatherBlack", 4,
				"Gloves_FingerlessGloves", 0.1,
				"Gloves_LeatherGloves", 0.05,
				"Gloves_LeatherGlovesBlack", 0.05,
				"Glasses_Aviators", 1,
				"Shirt_Denim", 0.8,
				"Perts.Pert_BulletBelt", 1,
			}
		},
	
	},
	
	safteyfirst = {
		isShop = true,
		   counter = {
            procedural = true,
            procList = {
                {name="ToolStoreAccessories", min=0, max=7, weightChance=20},
                {name="ClothingStoresGlovesLeather", min=0, max=1, weightChance=40},
                {name="StoreCounterCleaning", min=0, max=99, forceForTiles="location_shop_accessories_01_0;location_shop_accessories_01_1;location_shop_accessories_01_2;location_shop_accessories_01_3;location_shop_accessories_01_20;location_shop_accessories_01_21;location_shop_accessories_01_22;location_shop_accessories_01_23;fixtures_sinks_01_0;fixtures_sinks_01_1;fixtures_sinks_01_2;fixtures_sinks_01_3;fixtures_sinks_01_4;fixtures_sinks_01_5;fixtures_sinks_01_6;fixtures_sinks_01_7;fixtures_sinks_01_8;fixtures_sinks_01_9;fixtures_sinks_01_10;fixtures_sinks_01_11;fixtures_sinks_01_16;fixtures_sinks_01_17;fixtures_sinks_01_18;fixtures_sinks_01_19"},
   
            }
        },
        clothingrack = {
            procedural = true,
            procList = {
                {name="ToolStoreAccessories", min=0, max=7, weightChance=20},
                {name="ClothingStoresGlovesLeather", min=0, max=1, weightChance=40},
            }
        },
        crate = {
            procedural = true,
            procList = {
                {name="ToolStoreAccessories", min=0, max=7, weightChance=20},
                {name="ClothingStoresGlovesLeather", min=0, max=1, weightChance=40},
            }
        },

        metal_shelves = {
            procedural = true,
            procList = {
                {name="ToolStoreAccessories", min=0, max=7, weightChance=20},
                {name="ClothingStoresGlovesLeather", min=0, max=1, weightChance=40},
				{name="CrateRandomJunk", min=0, max=1, weightChance=40},
            }
        },
        shelves = {
            procedural = true,
            procList = {
                {name="ToolStoreAccessories", min=0, max=7, weightChance=20},
                {name="ClothingStoresGlovesLeather", min=0, max=1, weightChance=40},
				{name="CrateRandomJunk", min=0, max=1, weightChance=40},
            }
        }
    },
	
	
	ciggycity = {
		metal_shelves = {
			procedural = true,
				procList = {
				{name="BarCounterMisc", min=1, max=10, weightChance=40},
				{name="CrateCigarettes", min=1, max=10, weightChance=40},
				{name="StoreCounterTobacco", min=1, max=10, weightChance=100},
			}
		},
		shelves = {
			procedural = true,
				procList = {
				{name="BarCounterMisc", min=1, max=10, weightChance=40},
				{name="CrateCigarettes", min=1, max=10, weightChance=40},
				{name="StoreCounterTobacco", min=1, max=10, weightChance=100},
			}
		},
		displaycase = {
			procedural = true,
				procList = {
				{name="BarCounterMisc", min=1, max=10, weightChance=20},
				{name="CrateCigarettes", min=1, max=10, weightChance=20},
				{name="StoreCounterTobacco", min=1, max=10, weightChance=100},
			}
		},
	},
		
		
	spongefactory = {
		 metal_shelves = {
            rolls = 20,
            items = {
                "Base.Sponge", 5,
            }
        },
		shelves = {
			rolls = 20,
			items = {
				"Base.Sponge", 10,
			}
		},
		crate = {
			rolls = 20,
			items = {
				"Base.Sponge", 10,
			}
		},
	},
	
	moo = {
		fridge = {
			rolls = 10,
			items = {
				"Base.Milk", 2,
				"Base.Yoghurt",1,
			}
		},
		
		shelves = {
			rolls = 5,
			items = {
				"Base.CannedMilk", 2,
				"Base.Chocolate", 1,
			}
		},
		crate = {
			rolls = 10,
			items = {
				"Base.CannedMilk", 2,
				"Base.Chocolate", 1,
			}
		},
		
	},
	
	oofbrick = {
		 shelves = {
            rolls = 20,
            items = {
                "Base.Bricktoys", 15,
            }
        },
		crate = {
			rolls = 20,
			items = {
				"Base.Bricktoys", 15,
			}
		},
		metal_shelves = {
			rolls = 20,
			items = {
				"Base.Bricktoys", 15,
			}
		},
	},
	
	bagstore = {
		shelves = {
			rolls = 5,
			items = {
				"Base.Bag_BigHikingBag", 5,
				"Base.Bag_DuffelBag", 15,
				"Base.Bag_DuffelBagTINT", 15,
				"Base.Bag_FannyPackFront", 1,
				"Base.Bag_NormalHikingBag", 10,
				"Base.Bag_ALICEpack", 1,
				"Base.Bag_Satchel", 20,
				"Base.Bag_Schoolbag", 25,
				"Base.Bag_GolfBag", 5,
				"Base.Handbag", 30,
				"Base.Purse", 30,
			}
		},
		
		clothingrack = {
			rolls = 5,
			items = {
				"Base.Bag_BigHikingBag", 5,
				"Base.Bag_DuffelBag", 15,
				"Base.Bag_DuffelBagTINT", 15,
				"Base.Bag_FannyPackFront", 1,
				"Base.Bag_NormalHikingBag", 10,
				"Base.Bag_ALICEpack", 1,
				"Base.Bag_Satchel", 20,
				"Base.Bag_Schoolbag", 25,
				"Base.Bag_GolfBag", 5,
				"Base.Handbag", 30,
				"Base.Purse", 30,
			}
		},
		crate = {
			rolls = 15,
			items = {
				"Base.Bag_BigHikingBag", 5,
				"Base.Bag_DuffelBag", 15,
				"Base.Bag_DuffelBagTINT", 15,
				"Base.Bag_FannyPackFront", 1,
				"Base.Bag_NormalHikingBag", 10,
				"Base.Bag_ALICEpack", 1,
				"Base.Bag_Satchel", 20,
				"Base.Bag_Schoolbag", 25,
				"Base.Bag_GolfBag", 5,
				"Base.Handbag", 30,
				"Base.Purse", 30,
			}
		}
	},
	
	SurvivorWarhouse = {
	
		
		shelves = {
			procedural = true,
			procList = {
			 {name="CrateCannedFoodSpoiled", min=1, max=4, weightChance=100},
			 {name="CrateCannedFood", min=1, max=99, weightChance=100},
			 {name="GigamartCannedFood", min=1, max=99, weightChance=100},
			 {name="GroceryStorageCrate1", min=1, max=99, weightChance=100},
			 {name="GroceryStorageCrate2", min=1, max=99, weightChance=100},
			 {name="GroceryStorageCrate3", min=1, max=99, weightChance=100},
			 {name="KitchenCannedFood", min=1, max=99, weightChance=100},
			}
		},
	},
}

table.insert(Distributions, 2, PertsRoomDef);