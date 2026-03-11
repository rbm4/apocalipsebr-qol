local shortrestdistributionTable = {


	all = {
			
		armyclothingrackmt = {
        rolls = 6,
        items = {
            "Jacket_ArmyCamoGreen", 6,
            "Jacket_CoatArmy", 4,
            "Jacket_PaddedDOWN", 8,
            "LongJohns", 4,
            "LongJohns_Bottoms", 4,
            "PonchoGreenDOWN", 6,
            "Shirt_CamoDesert", 1,
            "Shirt_CamoGreen", 8,
            "Shirt_CamoUrban", 1,
            "Shirt_Lumberjack", 8,
            "Tshirt_ArmyGreen", 10,
            "Tshirt_CamoDesert", 1,
            "Tshirt_CamoGreen", 10,
            "Tshirt_CamoUrban", 1,
            "Tshirt_Profession_VeterenGreen", 4,
            "Tshirt_Profession_VeterenRed", 4,
            "Vest_BulletArmy", 2,
			"Vest_Hunting_CamoGreen", 6,
            "Vest_Hunting_Orange", 6,			
			}
        },
		ashtraymt = {
        rolls = 6,
        items = {
            "Cigarettes", 2,
			}
        },
		bowlingshoeshelfmt = {
        rolls = 6,
        items = {
            "Shoes_RedTrainers", 20,
            "Shoes_BlueTrainers", 20,
            "Shoes_TrainerTINT", 20,
			}
        },
		breaddisplaymt = {
        rolls = 6,
        items = {
            "Bread", 20,
			"Bread", 20,
			"Bread", 20,
			"Baguette", 20,
            "Croissant", 5,
            "Toast", 20,
            }
        },
		buffetmt = {
            procedural = true,
            procList = {
                {name="KitchenBaking", min=0, max=1, weightChance=40},
                {name="KitchenBreakfast", min=0, max=1, weightChance=80},
                {name="KitchenCannedFood", min=0, max=1, weightChance=100},
                {name="KitchenDryFood", min=0, max=1, weightChance=100},				
			}	
        },
		cigshelfmt = {
        rolls = 4,
        items = {
            "Cigarettes", 50,
            "Cigarettes", 20,
            "Cigarettes", 20,
            "Cigarettes", 10,
            "Cigarettes", 10,
			"Cigarettes", 50,
            "Cigarettes", 20,
            "Cigarettes", 20,
            "Cigarettes", 10,
            "Cigarettes", 10,
			"Cigarettes", 50,
            "Cigarettes", 20,
            "Cigarettes", 20,
            "Cigarettes", 10,
            "Cigarettes", 10,
			},
        },
		clothespilemt = {
            procedural = true,
            procList = {
                {name="ClothingStorageAllJackets", min=0, max=1, weightChance=100},
                {name="ClothingStorageHeadwear", min=0, max=1, weightChance=100},
                {name="ClothingStorageWinter", min=0, max=1, weightChance=100},	
                {name="ClothingStorageWinter", min=0, max=1, weightChance=100},	
                {name="ClothingStorageWinter", min=0, max=1, weightChance=100},	
                {name="ClothingStorageWinter", min=0, max=1, weightChance=100},
				{name="ClothingStoresDress", min=0, max=99, weightChance=20},
                {name="ClothingStoresJackets", min=0, max=99, weightChance=40},
                {name="ClothingStoresJacketsFormal", min=0, max=99, weightChance=10},
                {name="ClothingStoresJumpers", min=0, max=99, weightChance=60},
                {name="ClothingStoresOvershirts", min=0, max=99, weightChance=80},
                {name="ClothingStoresPants", min=0, max=99, weightChance=100},
                {name="ClothingStoresPantsFormal", min=0, max=99, weightChance=10},
                {name="ClothingStoresShirts", min=0, max=99, weightChance=100},
                {name="ClothingStoresShirtsFormal", min=0, max=99, weightChance=10},
                {name="ClothingStoresSport", min=0, max=99, weightChance=40},
                {name="ClothingStoresSummer", min=0, max=99, weightChance=40},				
			}	
        },
		coathangermt = {
            procedural = true,
            procList = {
                {name="ClothingStorageAllJackets", min=0, max=1, weightChance=100},
                {name="ClothingStorageFootwear", min=0, max=1, weightChance=80},
                {name="ClothingStorageHeadwear", min=0, max=1, weightChance=100},
                {name="ClothingStorageWinter", min=0, max=1, weightChance=100},	
                {name="ClothingStoresBoots", min=0, max=1, weightChance=100},	
                {name="ClothingStorageWinter", min=0, max=1, weightChance=100},	
                {name="ClothingStorageWinter", min=0, max=1, weightChance=100},	
                {name="ClothingStorageWinter", min=0, max=1, weightChance=100},				
			}	
        },
		corpseanimal = {
        rolls = 6,
        items = {
			"Centipede", 6,
			"Centipede2", 6,
            "ChickenFoot", 6,
			"Cockroach", 6,
            "Cricket", 4,
            "Grasshopper", 6,
            "KeyRing", 4,
            "Maggots", 4,
            "Maggots2", 6,
            "MuttonChop", 6,
            "SawflyLarva", 6,
            "Steak", 4,
			}
        },
		corpsestalker = {
        rolls = 6,
        items = {
			"Maggots", 4,
            "Maggots2", 6,
			"Dogfood", 5,
			"Apple", 5,
			"CheeseSandwich", 4,
			"Peanuts", 4,
			"Sausage", 4,
			"RippedSheetsDirty", 4,
			"Flute", 4,
			"Banjo", 4,
			"Cigarettes", 5,
			"Toothbrush", 4,
			"Dice", 4,
			"Razor", 4,
			"BeerCanEmpty", 4,
			"Cube", 4,
			"CardDeck", 5,
			"TheBible", 5,
			"HottieZ", 3,
			"Twine", 5,
			"Rope", 5,
			"BaseballBat", 5,
			"TennisBall", 5,
			"Pistol", 5,
			"Bullets9mm", 5,
			"DeadMouse", 2,
            "DeadRat", 4,
            "BeerBottle", 10,
            "BeerBottle", 10,
			}
        },
		corpsehuman = {
        rolls = 6,
        items = {
			"Maggots", 4,
            "Maggots2", 6,      
			"Bag_SurvivorBag", 1,
			"DeadMouse", 10,
            "DeadRat", 40,
            "BeerBottle", 10,
            }
        },
		corpsefunghi = {
        rolls = 6,
        items = {
			"Maggots", 10,
            "Maggots2", 10,
			"MushroomGeneric1", 10,
            "MushroomGeneric2", 10,
            "MushroomGeneric3", 10,
            "MushroomGeneric4", 10,
            "MushroomGeneric5", 10,
            "MushroomGeneric6", 10,
            "MushroomGeneric7", 10,}
        },
		firewoodstackmt = {
        rolls = 6,
        items = {
            "AmericanLadyCaterpillar",  0.5,
            "Centipede",  0.5,
            "Centipede2",  0.5,
            "Cockroach",  0.5,
            "Cricket",  0.5,
            "Grasshopper",  0.5,
            "Log",  20,
            "Maggots",  0.5,
            "Plank", 20,
            "Slug",  0.5,
            "Slug",  0.5,
            "Slug2",  0.5,
            "WoodenStick", 5,
            "TreeBranch",  5,
            }
        },
		firewoodstashmt = {
        rolls = 6,
        items = {
            "Log",  5,
            "Plank", 5,
            "WoodenStick", 10,
            "TreeBranch",  10,
            }
        },
		gumdispensermt = {
        rolls = 6,
            items = {
            "Cockroach", 2,            
			"Gum", 10,
            "Gum", 10,
            "Gum", 10,
            "Gum", 10,
            "Gum", 10,
            "Gum", 10,
            "Gum", 10,
            "Gum", 10,
            "Gum", 10,            
            }
        },
		grapevinesmt = {
        rolls = 6,
        items = {
            "Grapes", 20,
            "Grapes", 10,
            "Grapes", 20,
            "Grapes", 10,
            }
        },
		icecreamfreezermt = {
        rolls = 6,
        items = {
            "Icecream", 10,
            "Icecream", 10,
            "Icecream", 10,
            "Icecream", 10,
            "Icecream", 10,
            "Icecream", 10,
            "Icecream", 10,
            }
        },
		junkstashmt = {
        rolls = 6,
        items = {
            "brokenglass_1_0", 1,
            "brokenglass_1_1", 1,
			"DeadMouse", 2,
            "DeadRabbit", 2,
            "DeadRat", 4,
            "DeadSquirrel", 2,
            "Garbagebag", 20,
			"Generator",  1,
			"ModernTire1", 8,
            "ModernTire2", 6,
            "ModernTire3", 4,
            "NormalTire1", 10,
            "NormalTire2", 8,
            "NormalTire3", 6,
			"ScrapMetal", 2,
            "SmashedBottle", 4,
            "TinCanEmpty", 4,            
            }
        },
		laundryrackmt = {
            procedural = true,
            procList = {
                {name="CostumeStoreClothingAZ", min=0, max=99, weightChance=10},
				{name="GymLaundry", min=0, max=99, weightChance=10},
                {name="LaundryLoad1", min=0, max=1, weightChance=10},
                {name="LaundryLoad2", min=0, max=1, weightChance=10},
                {name="LaundryLoad3", min=0, max=1, weightChance=10},
                {name="LaundryLoad4", min=0, max=1, weightChance=10},
                {name="LaundryLoad5", min=0, max=1, weightChance=10},
                {name="LaundryLoad6", min=0, max=1, weightChance=10},
                {name="LaundryLoad7", min=0, max=1, weightChance=10},
                {name="LaundryLoad8", min=0, max=1, weightChance=10},
            }
        },
		newspaperholdermt = {
        rolls = 6,
        items = {
            "ComicBook", 8,
            "ComicBook", 8,
            "ComicBook", 8,
            "ComicBook", 8,
            "CookingMag1", 1,
            "CookingMag2", 1,
            "Earring_LoopLrg_Gold", 10,
            "Earring_LoopMed_Gold", 10,
            "ElectronicsMag1", 1,
            "ElectronicsMag2", 1,
            "ElectronicsMag3", 1,
            "ElectronicsMag4", 1,
            "ElectronicsMag5", 1,
            "EngineerMagazine1", 1,
            "EngineerMagazine2", 1,
            "FarmingMag1", 1,
            "FishingMag1", 1,
            "FishingMag2", 1,
            "Glasses_Reading", 1,
            "HerbalistMag", 1,
            "HottieZ", 0.5,
            "HuntingMag1", 1,
            "HuntingMag2", 1,
            "HuntingMag3", 1,
            "LouisvilleMap1", 10,
			"Magazine", 20,
            "Magazine", 20,
            "Magazine", 10,
            "Magazine", 10,
            "MagazineCrossword1", 4,
            "MagazineCrossword2", 4,
            "MagazineCrossword3", 4,
            "MagazineWordsearch1", 4,
            "MagazineWordsearch2", 4,
            "MagazineWordsearch3", 4,
            "MarchRidgeMap", 10,
            "MechanicMag1", 1,
            "MechanicMag2", 1,
            "MechanicMag3", 1,
            "MetalworkMag1", 1,
            "MetalworkMag2", 1,
            "MetalworkMag3", 1,
            "MetalworkMag4", 1,
			"Money", 1,
            "MuldraughMap", 5,
            "Newspaper", 50,
            "Newspaper", 20,
            "Newspaper", 20,
            "Newspaper", 10,
            "Newspaper", 100,
            "Paperclip", 2,
            "Pencil", 2,
            "RosewoodMap", 5,
            "RiversideMap", 5,
            "TheBible", 1,
			"Tissue", 2,
            "WestpointMap", 20,
            }
        },
		pizzaboxmt = {
        rolls = 6,
        items = {
            "BaloneySlice",  10,
			"Base.PKCheeseExpanded_CheesePizza", 6,
            "Base.PKCheeseExpanded_MeatPizza", 6,
            "Base.PKCheeseExpanded_HawaiianPizza", 6,
            "Base.PKCheeseExpanded_CheesePizzaSlice", 6,
            "Base.PKCheeseExpanded_MeatPizzaSlice", 6,
            "Base.PKCheeseExpanded_HawaiianPizzaSlice", 6,
            "Basil", 6,
            "Broccoli", 1,
            "Cheese", 10,
            "ChickenFoot", 1,
			"Cockroach", 2,
            "DeadMouse", 4,
            "farming.Bacon", 8,
			"farming.BaconBits ", 6,
			"farming.Tomato ", 8,
            "HamSlice", 2,
            "Maggots", 1,
            "MushroomGeneric5", 4,
            "OnionRings", 4,
			"Oregano", 4,
            "Pepperoni", 20,
            "Pepperoni", 10,
            "Pineapple", 1,
            "Pizza", 10,
            "PizzaWhole", 0.1,
			"SalamiSlice", 8,
            "TomatoPaste", 20,
            }
        },
		recyclebinmt = {
        rolls = 6,
        items = {
            "Apple", 2,
            "BandageDirty", 1,
            "BeerCanEmpty", 2,
            "BeerEmpty", 1,
            "brokenglass_1_0", 1,
            "brokenglass_1_1", 1,
            "brokenglass_1_2", 1,
            "brokenglass_1_3", 1,
            "Cigarettes", 8,
            "Cockroach", 2,
            "Cockroach", 2,
            "CottonBalls", 2,
            "DeadMouse", 2,
            "DeadRat", 4,
            "FountainCup", 2,
            "Gloves_Surgical", 3,
            "GranolaBar", 1,
            "Gum", 2,
            "Hairspray", 6,
            "Hat_SurgicalMask_Blue", 3,
            "JarLid", 0.5,
            "MushroomGeneric7", 20,
            "PaperBag", 3,
            "PaperBag", 1,
			"PaperNapkins", 2,
            "Pills", 0.5,
            "Plasticbag", 10,
            "PopBottleEmpty", 2,
            "PopEmpty", 4,
            "SmashedBottle", 1,
            "Straw", 1,
			"Teabag2", 5,
            "TinCanEmpty", 4,
			"Tissue", 30,
            "Toothbrush", 1,
            "WaterBottleEmpty", 2,
			}
        },
		sewingbasketmt = {
        rolls = 6,
            items = {
            "Needle", 20,
            "Scissors", 10,
            "SutureNeedle", 10,
            "SutureNeedleHolder", 10,
            "Thread", 20,
            "Thread", 20,
            "Thread", 20,
            "Thread", 10,
            "Tweezers", 10,
            "Twine", 10,
            }
        },
		shelveplatessmt = {
        rolls = 6,
            items = {
            "Plate", 50,
            "Plate", 50,
            "Plate", 50,
            "Plate", 50,
            "Plate", 50,
            "PlateBlue", 20,
            "PlateOrange", 20,
            "PlateFancy", 10,
            "Plate", 10,
            }
        },
		shelvesmagemptymt = {
        rolls = 4,
        items = {
            "Cockroach", 2,
            "Newspaper", 1,
			},
        },
		toiletpapershelfmt = {
        rolls = 6,
        items = {
            "Bandage", 6,
            "Bandaid", 10,
            "Comb", 4,
            "FirstAidKit", 2,
            "Mirror", 8,
            "Rubberducky", 4,
            "Soap2", 10,
            "ToiletPaper", 20,
            "ToiletPaper", 20,
            "ToiletPaper", 20,
            "ToiletPaper", 20,
            "ToiletPaper", 20,
            "ToiletPaper", 20,
            }
        },
		toiletpaperholdermt = {
        rolls = 6,
        items = {
            "Cockroach", 2,
			"ToiletPaper", 20,
			}
        },
		towelholdermt = {
        rolls = 6,
        items = {
            "BathTowel", 20,
            "BathTowel", 10,
            "BathTowel", 20,
            "BathTowel", 10,
            "BathTowel", 20,
            "BathTowel", 10,
            "DishCloth", 20,
            "DishCloth", 10,
            "Sheet", 20,
            "Sheet", 10,      
            }
        },
		traybinmt = {
        rolls = 6,
        items = {
            "Apple", 8,
            "Banana", 8,
            "BellPepper", 1,
            "Blackbeans", 1,
            "BreadKnife", 8,
            "Broccoli", 2,
            "Butter", 4,
            "ButterKnife", 20,
            "ButterKnife", 10,
            "DeadMouse", 2,
            "DeadRat", 4,
            "Carrots", 8,
            "Cheese", 4,
            "Cherry", 8,
            "Chicken", 6,
            "Corn", 4,
            "Eggplant", 2,
            "farming.Bacon", 6,
            "farming.Cabbage", 2,
            "farming.Cabbage", 2,
            "farming.MayonnaiseFull", 1,
            "farming.RedRadish", 2,
            "farming.Tomato", 4,
            "FishFillet", 6,
            "FountainCup", 20,
            "FountainCup", 10,
            "Fork", 10,
            "Fork", 20,
            "Ham", 6,
            "Hotsauce", 1,
            "Ketchup", 1,
            "Lard", 2,
            "Leek", 2,
            "Lemon", 2,
            "Lettuce", 4,
            "Lime", 2,
            "Margarine", 4,
            "MeatPatty", 6,
            "Milk", 10,
            "MincedMeat", 6,
            "MushroomGeneric7", 20,
            "Mustard", 1,
            "Onion", 4,
            "Orange", 8,
            "PaperBag", 20,
            "PaperBag", 10,
			"PaperNapkins", 20,
            "PaperNapkins", 10,
            "Peach", 8,
            "PepperJalapeno", 1,
            "Pickles", 6,
            "Pineapple", 8,
			"PlasticTray", 20,
            "PlasticTray", 20,
            "PlasticTray", 20,
            "PlasticTray", 20,
            "PlasticTray", 20,   
			"PorkChop", 6,
            "Processedcheese", 10,
            "Salmon", 4,
            "Shrimp", 4,
            "SmashedBottle", 1,
            "Soysauce", 1,
            "Spoon", 20,
            "Spoon", 10,
            "Steak", 4,
            "Straw", 20,
            "Straw", 10,
			"Teabag2", 6,
            "TinCanEmpty", 4,
			"TunaTinOpen", 4,
			"Zucchini", 2,		
			}
        },
		vinylcratemt = {
        procedural = true,
            procList = {
                {name="MusicStoreCDs", min=1, max=4, weightChance=100},
            }
        },
		vinylshelfmt = {
        procedural = true,
            procList = {
                {name="MusicStoreCDs", min=1, max=4, weightChance=100},
            }
        },
		
    },	
	garagestorage = {
			
		buffetmt = {
            procedural = true,
            procList = {
                {name="GarageTools", min=0, max=1, weightChance=100},
                {name="JanitorTools", min=0, max=2, weightChance=100},
                {name="PlankStashMagazine", min=0, max=2, weightChance=100},
                {name="ToolStoreMisc", min=0, max=99, weightChance=20},
            }
        },
	},
	srbathroomdirty = {
			
		locker = {
        rolls = 6,
        items = {
            "MetalPipe", 20,
            "MetalPipe", 10,
            "PipeWrench", 10,
            "Plunger", 10,
			"DuctTape", 8,
            "DuctTape", 8,
            "Hammer", 6,
            "Screwdriver", 10,
            "ScrewsBox", 8,
            "Hat_DustMask", 8,
            "Glasses_SafetyGoggles", 8,
            "Tissue", 10,
            "DishCloth", 10,
            
            },
		},
	},
	srboysmoveout = {
			
		crate = {
            procedural = true,
            procList = {
                {name="CrateClothesRandom", min=0, max=99, weightChance=100},
				{name="CrateComputer", min=0, max=99, weightChance=100},
				{name="CratePaint", min=0, max=99, weightChance=100},
				{name="CrateSpiffoMerch", min=0, max=99, weightChance=100},
				{name="CrateSports", min=0, max=99, weightChance=100},
				{name="CrateToys", min=0, max=99, weightChance=100},
				{name="PlankStashMagazine", min=0, max=99, weightChance=100},				
			}	
        },
	},
	srclockrepair = {
			
		counter = {
            procedural = true,
            procList = {
                {name="MedicalClinicTools", min=0, max=99},
				{name="ToolStoreMetalwork", min=0, max=99},
				{name="ToolStoreMisc", min=0, max=99},
				{name="EngineerTools", min=0, max=99},
				{name="StoreDisplayWatches", min=0, max=99},
            }
        },
		displaycase = {
            procedural = true,
            procList = {
                {name="StoreDisplayWatches", min=0, max=99},
            }
        },
		filingcabinet = {
            procedural = true,
            procList = {
                {name="DeskGeneric", min=0, max=99},
				{name="MedicalClinicTools", min=0, max=99},
				{name="ToolStoreMetalwork", min=0, max=99},
				{name="ToolStoreMisc", min=0, max=99},
				{name="EngineerTools", min=0, max=99},
				{name="StoreDisplayWatches", min=0, max=99},
            }
        },		
		metal_shelves = {
        rolls = 6,
        items = {
            "AlarmClock2", 20,
			"BeerCan", 20,
            "BeerCan", 20,
            "BluePen", 8,
            "CardDeck",  1,
            "Cigarettes", 8,
            "ElectronicsMag1", 2,
            "ElectronicsMag2", 2,
            "Eraser", 8,
			"Glasses_SafetyGoggles", 8,
			},
		},
		toolcabinet = {
            procedural = true,
            procList = {
                {name="MedicalClinicTools", min=0, max=99},
				{name="ToolStoreMetalwork", min=0, max=99},
				{name="ToolStoreMisc", min=0, max=99},
				{name="EngineerTools", min=0, max=99},
				{name="StoreDisplayWatches", min=0, max=99},
            }
        },
		
    },
	srelectronicstoreBreakroom = {
			
		locker = {
        rolls = 6,
        items = {
            "BeerCan", 20,
            "BeerCan", 20,
            "BluePen", 8,
            "CardDeck",  1,
            "Cigarettes", 8,
            "Dungarees", 4,
            "ElectronicsMag1", 2,
            "ElectronicsMag2", 2,
            "Eraser", 8,
			"Glasses_SafetyGoggles", 8,            
            "HoodieDOWN_WhiteTINT", 1,
            "Lunchbox", 1,
            "Shoes_Random", 2,
            "Shoes_TrainerTINT", 2,
            "Shorts_LongDenim", 1,            
			},
		},
	},
	srelectronicstore = {
			
		counter = {
        rolls = 4,
        items = {
            "BaseballBat", 10,
            "Battery", 20,
            "Battery", 20,
            "Battery", 10,
            "Battery", 10,
            "BluePen", 8,
            "Book", 10,
            "CordlessPhone", 8,
            "ElectronicsMag1", 2,
            "ElectronicsMag2", 2,
            "ElectronicsMag3", 2,
            "ElectronicsMag4", 2,
            "ElectronicsMag5", 2,
            "ElectronicsScrap", 20,
            "ElectronicsScrap", 10,
            "EngineerMagazine1", 2,
            "EngineerMagazine2", 2,
            "Eraser", 8,
            "Glue", 2,
            "HandTorch", 8,
            "HolePuncher", 4,
            "Magazine", 10,
            "MagazineCrossword1", 2,
            "MagazineCrossword2", 2,
            "MagazineCrossword3", 2,
            "MagazineWordsearch1", 2,
            "MagazineWordsearch2", 2,
            "MagazineWordsearch3", 2,
            "Notebook", 10,
            "Paperclip", 10,
            "PaperclipBox", 1,
            "Pen", 8,
            "Pencil", 10,
            "Radio.RadioBlack", 6,
            "Radio.RadioRed", 4,
            "Radio.WalkieTalkie1", 6,
            "Radio.WalkieTalkie2", 4,
            "Radio.WalkieTalkie3", 1,
            "Remote", 10,
            "Remote", 10,
            "Remote", 10,
            "Remote", 10,
            "RedPen", 8,
            "RubberBand", 6,
            "Scissors", 2,
            "Scotchtape", 4,
            "SheetPaper2", 20,
            "SheetPaper2", 10,
            "Stapler", 4,
            "Staples", 4,"Torch", 4,
			"Torch", 4,
			"Torch", 4,
			},
        },
        crate = {
            procedural = true,
            procList = {
                {name="ArmyStorageElectronics", min=0, max=99, weightChance=100},
				{name="CrateComputer", min=0, max=99, weightChance=100},
				{name="CrateTV", min=0, max=99, weightChance=100},
				{name="CrateTVWide", min=0, max=99, weightChance=100},				
			}
        },
		metal_shelves = {
            procedural = true,
            procList = {
                {name="ElectronicStoreLights", min=0, max=99, weightChance=100},
				{name="CrateCompactDiscs", min=0, max=99, weightChance=100},
				{name="CrateCameraFilm", min=0, max=99, weightChance=100},
				{name="CrateBatteries", min=0, max=99, weightChance=100},
			}
        },	
    },
	srelectronicstorage = {

        bin = {
        rolls = 6,
        items = {
            "BandageDirty", 1,
            "BandageDirty", 1,
            "BandageDirty", 1,
            "brokenglass_1_0", 1,
            "brokenglass_1_1", 1,
            "brokenglass_1_2", 1,
            "brokenglass_1_3", 1,
            "Cockroach", 2,
            "Cockroach", 2,
            "Cockroach", 2,
            "Cockroach", 2,
            "DishCloth", 10,
            "DishCloth", 10,
            "ElectronicsScrap", 2,
            "ElectronicsScrap", 2,
            "ElectronicsScrap", 2,
            "HottieZ", 1,
            "HottieZ", 2,
            "Newspaper", 6,
            "Newspaper", 6,
            "Plasticbag", 10,
            "Plasticbag", 10,
            "PopBottleEmpty", 1,
            "PopBottleEmpty", 1,
            "PopBottleEmpty", 1,
            "TinCanEmpty", 4,
            "TinCanEmpty", 4,
            "TinCanEmpty", 4,
			"UnusableMetal", 10,
            "UnusableWood", 10,            
            }
        },
		crate = {
            procedural = true,
            procList = {
                {name="ArmyStorageElectronics", min=0, max=99, weightChance=100},
				{name="ElectronicStoreLights", min=0, max=99, weightChance=100},
				{name="CrateBatteries", min=0, max=99, weightChance=100},	
				{name="CrateCameraFilm", min=0, max=99, weightChance=100},
				{name="CrateCompactDiscs", min=0, max=99, weightChance=100},
				{name="CrateComputer", min=0, max=99, weightChance=100},
				{name="CrateTV", min=0, max=99, weightChance=100},
				{name="CrateTVWide", min=0, max=99, weightChance=100},			
            }
        },
		locker = {
        rolls = 6,
        items = {
            "Bandage", 10,
            "Bandaid", 20,
            "Bandaid", 10,			
            "BaseballBat", 10,
			"Boilersuit_BlueRed", 20,
            "Boilersuit_BlueRed", 20,
            "BucketEmpty", 2,
            "Crackers", 10,
            "Crackers", 10,
            "DishCloth", 10,
            "DishCloth", 10,
			"Extinguisher", 6,
            "HottieZ", 0.5,
            "HuntingKnife", 6,
			"Lighter", 4,
            "Matches", 8,
			"PillsAntiDep", 20,
            "PillsAntiDep", 10,
            "RippedSheetsDirty", 20,
            "RippedSheetsDirty", 10,	
			"Rope", 8,
			"Torch", 4,
            "TortillaChips", 4,		
            "Tweezers", 10,
			"WhiskeyFull", 0.1,            
            }
        },
		metal_shelves = {
            procedural = true,
            procList = {
                {name="ArmyStorageElectronics", min=0, max=99, weightChance=100},
				{name="CrateElectronics", min=0, max=99, weightChance=100},
				{name="CrateBatteries", min=0, max=99, weightChance=100},
				{name="CrateComputer", min=0, max=99, weightChance=100},
				{name="ElectronicStoreHAMRadio", min=0, max=99, weightChance=100},
			}
        },
		shelves = {
        rolls = 6,
        items = {
            "BookElectrician1", 6,
            "BookElectrician2", 4,
            "BookElectrician3", 2,
            "BookElectrician4", 1,
            "BookElectrician5", 0.5,
			"BookMechanic1", 6,
            "BookMechanic2", 4,
            "BookMechanic3", 2,
            "BookMechanic4", 1,
            "BookMechanic5", 0.5,
			"Book", 20,
            "Book", 20,
            "Book", 10,
            "Book", 10,			
            "ElectronicsMag1", 1,
            "ElectronicsMag2", 1,
            "ElectronicsMag3", 1,
            "ElectronicsMag4", 1,
            "ElectronicsMag5", 1,
            "EmptyJar", 20,
            "EmptyJar", 20,
            "HottieZ", 0.5,
            "HottieZ", 0.5,
            "Magazine", 10,
            "Newspaper", 10,          
            }
        },
		toolcabinet = {
        rolls = 6,
        items = {
            "BluePen", 8,
            "Corkscrew", 4,
            "Eraser", 8,
            "Glasses_SafetyGoggles", 8,
            "Glue", 2,
            "Hammer", 8,
            "HolePuncher", 10,
            "LetterOpener", 1,
            "NailsBox", 20,
            "NailsBox", 10,
            "NailsBox", 20,
            "NailsBox", 10,
            "Notebook", 10,
            "Paperclip", 10,
            "PaperclipBox", 1,
            "Pen", 8,
            "Pencil", 10,
            "RedPen", 8,
            "RubberBand", 6,
            "Scissors", 2,
            "Scotchtape", 4,
            "Screwdriver", 10,
            "ScrewsBox", 30,
            "ScrewsBox", 30,
            "ScrewsBox", 8,
            "ScrewsBox", 8,
            "ScrewsBox", 8,
            "ScrewsBox", 8,
            "SheetPaper2", 10,
			"Stapler", 10,
            "Staples", 10,
            "TinOpener", 8,
            "Woodglue", 8,
            "Woodglue", 8,
            "Woodglue", 8,
            "Woodglue", 8,
            "Woodglue", 8,
            "Wrench", 8,            
            }
        },
    },
    sremptyabandoned = {

        counter = {
            procedural = true,
            procList = {
                {name="BinBar", min=0, max=99, weightChance=100},
			}	
        },
		shelves = {
            rolls = 0,
            items = {

            }
        },
    },
	srgardenshed = {
			
		counter = {
            procedural = true,
            procList = {
                {name="BarShelfLiquor", min=0, max=99, weightChance=100},
                {name="StoreShelfSnacks", min=0, max=99, weightChance=100},
				{name="StoreCounterBags", min=0, max=1, weightChance=100},
				{name="KitchenCannedFood", min=1, max=1, weightChance=100},
                {name="KitchenDishes", min=1, max=1, weightChance=80},
                {name="KitchenDryFood", min=0, max=1, weightChance=100},
				{name="KitchenRandom", min=0, max=1, weightChance=20},
            }
        },
        fridge = {
            procedural = true,
            procList = {
                {name="FridgeBeer", min=0, max=99},
				{name="FridgeWater", min=0, max=12},
				{name="FridgeOther", min=1, max=99, weightChance=40},
                {name="FridgeSnacks", min=1, max=99, weightChance=100},
				{name="GroceryStandVegetables1", min=1, max=99, weightChance=100},
                {name="GroceryStandVegetables2", min=1, max=99, weightChance=100},
                {name="GroceryStandFruits1", min=1, max=99, weightChance=100},
                {name="GroceryStandFruits2", min=1, max=99, weightChance=100},
                {name="GroceryStandFruits3", min=1, max=99, weightChance=100},
                {name="GroceryStandLettuce", min=1, max=99, weightChance=25},                
            }
        },
        locker = {
            procedural = true,
            procList = {
                {name="ArmyStorageGuns", min=0, max=99, weightChance=100},
			}	
        },
		metal_shelves = {
            procedural = true,
            procList = {
                {name="GardenStoreTools", min=0, max=99, weightChance=100},
                {name="GardenStoreMisc", min=0, max=99, weightChance=100},
				{name="Homesteading", min=0, max=1, weightChance=10},                
            }
        },
        shelves = {
            procedural = true,
            procList = {
                {name="GardenStoreTools", min=0, max=99, weightChance=100},
                {name="GardenStoreMisc", min=0, max=99, weightChance=100},
				{name="Homesteading", min=0, max=1, weightChance=10},                
            }
        },
    },
	srgroceriesmtcheese = {
			
		crate = {
        rolls = 6,
        items = {
            "Cheese", 20,
            "Cheese", 20,
            "Processedcheese", 20,
            "Processedcheese", 20,
            "Base.PKCheeseExpanded_CheesePizza", 6,
            "Base.PKCheeseExpanded_MeatPizza", 6,
            "Base.PKCheeseExpanded_HawaiianPizza", 6,
            "Base.PKCheeseExpanded_CheesePizzaSlice", 6,
            "Base.PKCheeseExpanded_MeatPizzaSlice", 6,
            "Base.PKCheeseExpanded_HawaiianPizzaSlice", 6,            
			}
        },
		displaycasebutcher = {
        rolls = 6,
        items = {
            "Cheese", 20,
            "Cheese", 20,
            "Processedcheese", 20,
            "Processedcheese", 20,
            "Yoghurt", 10,
            "Base.PKCheeseExpanded_CheesePizza", 6,
            "Base.PKCheeseExpanded_MeatPizza", 6,
            "Base.PKCheeseExpanded_HawaiianPizza", 6,
            "Base.PKCheeseExpanded_CheesePizzaSlice", 6,
            "Base.PKCheeseExpanded_MeatPizzaSlice", 6,
            "Base.PKCheeseExpanded_HawaiianPizzaSlice", 6,            
			}
        },
		metal_shelves = {
        rolls = 6,
        items = {
            "PaperBag", 8,
            "PaperBag", 8,
            "PaperBag", 8,
            "PaperBag", 8,
            "PaperBag", 8,
            "PaperBag", 8,
            "PaperNapkins", 50,
            "PaperNapkins", 20,
            "PaperNapkins", 20,
            "PaperNapkins", 10,
            "PaperNapkins", 10,
			"Plasticbag", 8,
            "Plasticbag", 8,
            "Plasticbag", 8,
            "Plasticbag", 8,
            "Plasticbag", 8,
            "Plasticbag", 8,
            }
        },
		Storage = {
        rolls = 6,
        items = {
            "Cheese", 20,
            "Cheese", 20,
            "Processedcheese", 20,
            "Processedcheese", 20,
            "Base.PKCheeseExpanded_CheesePizza", 6,
            "Base.PKCheeseExpanded_MeatPizza", 6,
            "Base.PKCheeseExpanded_HawaiianPizza", 6,
            "Base.PKCheeseExpanded_CheesePizzaSlice", 6,
            "Base.PKCheeseExpanded_MeatPizzaSlice", 6,
            "Base.PKCheeseExpanded_HawaiianPizzaSlice", 6,            
			}
        },
		wardrobe = {
        rolls = 6,
        items = {
            "Bag_DuffelBagTINT", 0.5,
            "Bag_FannyPackFront", 2,
            "Bag_Satchel", 0.2,
            "Belt2", 4,
            "Briefcase", 0.2,
            "Disc_Retail", 2,
            "Earbuds", 1,
            "Headphones", 1,
            "Jacket_Chef", 2,
            "Jacket_WhiteTINT", 0.5,
            "Jumper_DiamondPatternTINT", 0.1,
            "Jumper_PoloNeck", 0.5,
            "Jumper_RoundNeck", 0.5,
            "Jumper_VNeck", 0.5,
            "Lunchbag", 1,
            "Lunchbox", 1,
            "Lunchbox2", 0.001,
            "Radio.CDplayer", 2,
            "Shirt_FormalTINT", 0.5,
            "Shirt_FormalWhite", 0.5,
            "Shirt_FormalWhite_ShortSleeve", 1,
            "Shirt_FormalWhite_ShortSleeveTINT", 1,
             "Shoes_Random", 2,
            "Shoes_TrainerTINT", 2,
            "Socks_Ankle", 1,
            "Socks_Ankle", 1,
            "Socks_Long", 0.5,
            "Suitcase", 0.2,
            "Trousers_Scrubs", 8,
            "Trousers_Scrubs", 8,
            "Trousers_Suit", 0.5,
            "Trousers_SuitTEXTURE", 0.5,
            "Tshirt_WhiteTINT", 2,
            "Vest_DefaultTEXTURE_TINT", 1,}
        },
    },
	srgroceriesmtfish = {
			
		counter = {
            procedural = true,
            procList = {
                {name="StoreCounterCleaning", min=0, max=99, forceForTiles="location_shop_accessories_01_0;location_shop_accessories_01_1;location_shop_accessories_01_2;location_shop_accessories_01_3;location_shop_accessories_01_20;location_shop_accessories_01_21;location_shop_accessories_01_22;location_shop_accessories_01_23;fixtures_sinks_01_0;fixtures_sinks_01_1;fixtures_sinks_01_2;fixtures_sinks_01_3;fixtures_sinks_01_4;fixtures_sinks_01_5;fixtures_sinks_01_6;fixtures_sinks_01_7;fixtures_sinks_01_8;fixtures_sinks_01_9;fixtures_sinks_01_10;fixtures_sinks_01_11;fixtures_sinks_01_16;fixtures_sinks_01_17;fixtures_sinks_01_18;fixtures_sinks_01_19"},
                {name="SushiKitchenButcher", min=1, max=2, weightChance=100},
                {name="StoreKitchenTrays", min=0, max=2, weightChance=50},
                {name="SushiKitchenSauce", min=1, max=1, weightChance=100},
            }
        },
		crate = {
            procedural = true,
            procList = {
                {name="ButcherFish", min=1, max=99, weightChance=100},
				{name="ServingTrayMaki", min=0, max=99, weightChance=80},
                {name="ServingTrayOnigiri", min=0, max=99, weightChance=80},
                {name="ServingTraySpringRolls", min=0, max=99, weightChance=40},
                {name="ServingTraySushiEgg", min=1, max=99, weightChance=100},
                {name="ServingTraySushiFish", min=1, max=99, weightChance=100},
				{name="SushiKitchenFridge", min=0, max=99},
            }
        },
		displaycasebutcher = {
            procedural = true,
            procList = {
                {name="ButcherFish", min=1, max=99, weightChance=100},
				{name="ServingTrayMaki", min=0, max=99, weightChance=80},
                {name="ServingTrayOnigiri", min=0, max=99, weightChance=80},
                {name="ServingTraySpringRolls", min=0, max=99, weightChance=40},
                {name="ServingTraySushiEgg", min=1, max=99, weightChance=100},
                {name="ServingTraySushiFish", min=1, max=99, weightChance=100},
				{name="SushiKitchenFridge", min=0, max=99},
            }
        },
    },
	srgroceriesmtfood = {
			
		crate = {
            procedural = true,
            procList = {
                {name="CrateCandyPackage", min=0, max=1, weightChance=40},
                {name="CrateChips", min=0, max=1, weightChance=100},
                {name="CrateChocolate", min=0, max=1, weightChance=40},
                {name="CrateCigarettes", min=0, max=1, weightChance=60},
                {name="CrateCoffee", min=0, max=1, weightChance=100},
                {name="CrateComics", min=0, max=1, weightChance=100},
                {name="CrateFlour", min=0, max=1, weightChance=100},
                {name="CrateGum", min=0, max=1, weightChance=40},
                {name="CrateGravyMix", min=0, max=1, weightChance=100},
                {name="CrateMagazines", min=0, max=1, weightChance=100},
                {name="CrateMarinara", min=0, max=2, weightChance=100},
                {name="CrateOilOlive", min=0, max=1, weightChance=100},
                {name="CrateOilVegetable", min=0, max=1, weightChance=100},
                {name="CratePasta", min=0, max=2, weightChance=100},
                {name="CratePeanuts", min=0, max=1, weightChance=40},
                {name="CrateSodaBottles", min=0, max=99, weightChance=100},
                {name="CrateSodaCans", min=0, max=99, weightChance=100},
				{name="CrateSugar", min=0, max=1, weightChance=100},
                {name="CrateSunflowerSeeds", min=0, max=1, weightChance=40},
                {name="CrateTea", min=0, max=1, weightChance=100},
                {name="CrateTortillaChips", min=0, max=2, weightChance=100},
				{name="CrateYeast", min=0, max=1, weightChance=100},
                {name="GigamartBottles", min=2, max=99, weightChance=20},
                {name="GigamartCrisps", min=2, max=99, weightChance=20},
                {name="GigamartCandy", min=1, max=99, weightChance=20},
                {name="GigamartBakingMisc", min=1, max=99, weightChance=20},
                {name="GigamartDryGoods", min=2, max=99, weightChance=100},
                {name="GigamartCannedFood", min=2, max=99, weightChance=100},
                {name="GigamartSauce", min=1, max=99, weightChance=20},
            }
        },
		metal_shelves = {
            procedural = true,
            procList = {
                {name="CrateCandyPackage", min=0, max=1, weightChance=40},
                {name="CrateChips", min=0, max=1, weightChance=100},
                {name="CrateChocolate", min=0, max=1, weightChance=40},
                {name="CrateCigarettes", min=0, max=1, weightChance=60},
                {name="CrateCoffee", min=0, max=1, weightChance=100},
                {name="CrateComics", min=0, max=1, weightChance=100},
                {name="CrateFlour", min=0, max=1, weightChance=100},
                {name="CrateGum", min=0, max=1, weightChance=40},
                {name="CrateGravyMix", min=0, max=1, weightChance=100},
                {name="CrateMagazines", min=0, max=1, weightChance=100},
                {name="CrateMarinara", min=0, max=2, weightChance=100},
                {name="CrateOilOlive", min=0, max=1, weightChance=100},
                {name="CrateOilVegetable", min=0, max=1, weightChance=100},
                {name="CratePasta", min=0, max=2, weightChance=100},
                {name="CratePeanuts", min=0, max=1, weightChance=40},
                {name="CrateSodaBottles", min=0, max=99, weightChance=100},
                {name="CrateSodaCans", min=0, max=99, weightChance=100},
				{name="CrateSugar", min=0, max=1, weightChance=100},
                {name="CrateSunflowerSeeds", min=0, max=1, weightChance=40},
                {name="CrateTea", min=0, max=1, weightChance=100},
                {name="CrateTortillaChips", min=0, max=2, weightChance=100},
				{name="CrateYeast", min=0, max=1, weightChance=100},
                {name="GigamartBottles", min=2, max=99, weightChance=20},
                {name="GigamartCrisps", min=2, max=99, weightChance=20},
                {name="GigamartCandy", min=1, max=99, weightChance=20},
                {name="GigamartBakingMisc", min=1, max=99, weightChance=20},
                {name="GigamartDryGoods", min=2, max=99, weightChance=100},
                {name="GigamartCannedFood", min=2, max=99, weightChance=100},
                {name="GigamartSauce", min=1, max=99, weightChance=20},
            }
        },
		Storage = {
            procedural = true,
            procList = {
                {name="CrateCandyPackage", min=0, max=1, weightChance=40},
                {name="CrateChips", min=0, max=1, weightChance=100},
                {name="CrateChocolate", min=0, max=1, weightChance=40},
                {name="CrateCigarettes", min=0, max=1, weightChance=60},
                {name="CrateCoffee", min=0, max=1, weightChance=100},
                {name="CrateComics", min=0, max=1, weightChance=100},
                {name="CrateFlour", min=0, max=1, weightChance=100},
                {name="CrateGum", min=0, max=1, weightChance=40},
                {name="CrateGravyMix", min=0, max=1, weightChance=100},
                {name="CrateMagazines", min=0, max=1, weightChance=100},
                {name="CrateMarinara", min=0, max=2, weightChance=100},
                {name="CrateOilOlive", min=0, max=1, weightChance=100},
                {name="CrateOilVegetable", min=0, max=1, weightChance=100},
                {name="CratePasta", min=0, max=2, weightChance=100},
                {name="CratePeanuts", min=0, max=1, weightChance=40},
                {name="CrateSodaBottles", min=0, max=99, weightChance=100},
                {name="CrateSodaCans", min=0, max=99, weightChance=100},
				{name="CrateSugar", min=0, max=1, weightChance=100},
                {name="CrateSunflowerSeeds", min=0, max=1, weightChance=40},
                {name="CrateTea", min=0, max=1, weightChance=100},
                {name="CrateTortillaChips", min=0, max=2, weightChance=100},
				{name="CrateYeast", min=0, max=1, weightChance=100},
                {name="GigamartBottles", min=2, max=99, weightChance=20},
                {name="GigamartCrisps", min=2, max=99, weightChance=20},
                {name="GigamartCandy", min=1, max=99, weightChance=20},
                {name="GigamartBakingMisc", min=1, max=99, weightChance=20},
                {name="GigamartDryGoods", min=2, max=99, weightChance=100},
                {name="GigamartCannedFood", min=2, max=99, weightChance=100},
                {name="GigamartSauce", min=1, max=99, weightChance=20},
            }
        },
    },
	srgroceriesmtfridges = {
			
		fridge = {
            procedural = true,
            procList = {
			
            }
        },
		freezer = {
            procedural = true,
            procList = {
			
            }
        },
    },
	srgroceriesmthardware = {
			
		crate = {
            procedural = true,
            procList = {
                {name="GigamartHouseElectronics", min=1, max=2, weightChance=60},
                {name="GigamartHousewares", min=1, max=2, weightChance=60},
                {name="GigamartLightbulb", min=0, max=1, weightChance=20},
                {name="GigamartPots", min=1, max=2, weightChance=60},
                {name="GigamartToys", min=0, max=2, weightChance=40},
                
            }
        },
		metal_shelves = {
            procedural = true,
            procList = {
                {name="GigamartHouseElectronics", min=1, max=2, weightChance=60},
                {name="GigamartHousewares", min=1, max=2, weightChance=60},
                {name="GigamartLightbulb", min=0, max=1, weightChance=20},
                {name="GigamartPots", min=1, max=2, weightChance=60},
                {name="GigamartToys", min=0, max=2, weightChance=40},
                
            }
        },
    },
	srgroceriesmthouseware = {
		
		bin = {
            rolls = 4,
            items = {
			
            },
            
        },
		crates = {
            procedural = true,
            procList = {
                {name="CrateFountainCups", min=0, max=1, weightChance=60},
                {name="CrateNapkins", min=0, max=1, weightChance=60},
                {name="CrateOfficeSupplies", min=0, max=99},
				{name="CratePaperBagSpiffos", min=0, max=1, weightChance=60},
                {name="CratePlasticTrays", min=0, max=1, weightChance=60},
                {name="CrateSpiffoMerch", min=0, max=1, weightChance=5},
                {name="GigamartHousewares", min=1, max=99, weightChance=20},
                {name="GigamartSchool", min=1, max=99, weightChance=20},
                {name="GigamartPots", min=1, max=99, weightChance=20},
                {name="GigamartLightbulb", min=1, max=99, weightChance=10},
                {name="GigamartHouseElectronics", min=1, max=99, weightChance=10},
				{name="MotelTowels", min=0, max=99, weightChance=100},
            }
        },
		recyclebinmt = {
            rolls = 4,
            items = {
			
            },
            
        },		
		metal_shelves = {
            procedural = true,
            procList = {
                {name="CrateFountainCups", min=0, max=1, weightChance=60},
                {name="CrateNapkins", min=0, max=1, weightChance=60},
                {name="CrateOfficeSupplies", min=0, max=99},
				{name="CratePaperBagSpiffos", min=0, max=1, weightChance=60},
                {name="CratePlasticTrays", min=0, max=1, weightChance=60},
                {name="CrateSpiffoMerch", min=0, max=1, weightChance=5},
                {name="GigamartHousewares", min=1, max=99, weightChance=20},
                {name="GigamartSchool", min=1, max=99, weightChance=20},
                {name="GigamartPots", min=1, max=99, weightChance=20},
                {name="GigamartLightbulb", min=1, max=99, weightChance=10},
                {name="GigamartHouseElectronics", min=1, max=99, weightChance=10},
				{name="MotelTowels", min=0, max=99, weightChance=100},
            }
        },
		shelves = {
            procedural = true,
            procList = {
                {name="CrateFountainCups", min=0, max=1, weightChance=60},
                {name="CrateNapkins", min=0, max=1, weightChance=60},
                {name="CrateOfficeSupplies", min=0, max=99},
				{name="CratePaperBagSpiffos", min=0, max=1, weightChance=60},
                {name="CratePlasticTrays", min=0, max=1, weightChance=60},
                {name="CrateSpiffoMerch", min=0, max=1, weightChance=5},
                {name="GigamartHousewares", min=1, max=99, weightChance=20},
                {name="GigamartSchool", min=1, max=99, weightChance=20},
                {name="GigamartPots", min=1, max=99, weightChance=20},
                {name="GigamartLightbulb", min=1, max=99, weightChance=10},
                {name="GigamartHouseElectronics", min=1, max=99, weightChance=10},
				{name="MotelTowels", min=0, max=99, weightChance=100},
            }
        },
    },
	srgroceriesmtmain = {
			
		wardrobe = {
        rolls = 6,
        items = {
            "Banana", 5,
			"DeadRat", 2,
			"Cigarettes", 10,
            }
        },
		clothingrack = {
            procedural = true,
            procList = {
                {name="ArmySurplusOutfit", min=0, max=4, weightChance=100},
                {name="ClothingStorageAllJackets", min=0, max=99, weightChance=10},
                {name="ClothingStorageAllShirts", min=0, max=99, weightChance=10},
                {name="ClothingStorageLegwear", min=0, max=99, weightChance=10},
                {name="ClothingStoresDress", min=0, max=2, weightChance=40},
                {name="ClothingStoresJacketsFormal", min=0, max=2, weightChance=40},
                {name="ClothingStoresPantsFormal", min=0, max=2, weightChance=40},
                {name="ClothingStoresShirtsFormal", min=0, max=2, weightChance=40},
            }
        },
		counter = {
            procedural = true,
            procList = {
                {name="StoreCounterCleaning", min=0, max=99, forceForTiles="location_shop_accessories_01_0;location_shop_accessories_01_1;location_shop_accessories_01_2;location_shop_accessories_01_3;location_shop_accessories_01_20;location_shop_accessories_01_21;location_shop_accessories_01_22;location_shop_accessories_01_23;fixtures_sinks_01_0;fixtures_sinks_01_1;fixtures_sinks_01_2;fixtures_sinks_01_3;fixtures_sinks_01_4;fixtures_sinks_01_5;fixtures_sinks_01_6;fixtures_sinks_01_7;fixtures_sinks_01_8;fixtures_sinks_01_9;fixtures_sinks_01_10;fixtures_sinks_01_11;fixtures_sinks_01_16;fixtures_sinks_01_17;fixtures_sinks_01_18;fixtures_sinks_01_19"},
                {name="StoreCounterBags", min=0, max=1, weightChance=100},
            }
        },
		freezer = {
            procedural = true,
            procList = {
                {name="BakeryCake", min=0, max=99, weightChance=80},
                {name="BakeryDoughnuts", min=0, max=1, weightChance=20},
                {name="DeepFryKitchenFreezer", min=0, max=99},
				{name="FreezerGeneric", min=0, max=99, weightChance=100},
                {name="FreezerIceCream", min=0, max=99, weightChance=100},
				{name="ServingTrayFries", min=1, max=2, weightChance=60},
                {name="ServingTrayOmelettes", min=1, max=2, weightChance=60},
                {name="ServingTrayPancakes", min=1, max=4, weightChance=100},
                {name="ServingTrayPie", min=0, max=1, weightChance=40},
                {name="ServingTrayPizza", min=0, max=99, weightChance=100},
				{name="ServingTrayPotatoPancakes", min=1, max=4, weightChance=100},
                {name="ServingTrayScrambledEggs", min=1, max=2, weightChance=60},
                {name="ServingTrayWaffles", min=1, max=4, weightChance=100},
            }
        },
		shelves = {
            procedural = true,
            procList = {
                {name="GigamartBottles", min=2, max=99, weightChance=20},
                {name="GigamartCrisps", min=2, max=99, weightChance=20},
                {name="GigamartCandy", min=1, max=99, weightChance=20},
                {name="GigamartBakingMisc", min=1, max=99, weightChance=20},
                {name="GigamartDryGoods", min=2, max=99, weightChance=100},
                {name="GigamartHousewares", min=1, max=99, weightChance=20},
                {name="GigamartCannedFood", min=2, max=99, weightChance=100},
                {name="GigamartSauce", min=1, max=99, weightChance=20},
                {name="GigamartToys", min=1, max=99, weightChance=20},
                {name="GigamartSchool", min=1, max=99, weightChance=20},
                {name="GigamartLightbulb", min=1, max=99, weightChance=10},
                {name="GigamartHouseElectronics", min=1, max=99, weightChance=10},
                {name="StoreShelfCombo", min=0, max=99, forceForTiles="location_shop_generic_01_0;location_shop_generic_01_1"},
            }
        },
		Storage = {
            procedural = true,
            procList = {
                {name="GigamartBottles", min=2, max=99, weightChance=20},
                {name="GigamartCrisps", min=2, max=99, weightChance=20},
                {name="GigamartCandy", min=1, max=99, weightChance=20},
                {name="GigamartBakingMisc", min=1, max=99, weightChance=20},
                {name="GigamartDryGoods", min=2, max=99, weightChance=100},
                {name="GigamartHousewares", min=1, max=99, weightChance=20},
                {name="GigamartCannedFood", min=2, max=99, weightChance=100},
                {name="GigamartSauce", min=1, max=99, weightChance=20},
                {name="GigamartToys", min=1, max=99, weightChance=20},
                {name="GigamartSchool", min=1, max=99, weightChance=20},
                {name="GigamartLightbulb", min=1, max=99, weightChance=10},
                {name="GigamartHouseElectronics", min=1, max=99, weightChance=10},
                {name="StoreShelfCombo", min=0, max=99, forceForTiles="location_shop_generic_01_0;location_shop_generic_01_1"},
            }
        },
    },
	srgroceriesmtmeat = {
			
		counter = {
            procedural = true,
            procList = {
                {name="ButcherTools", min=0, max=99, weightChance=100},
                {name="StoreCounterCleaning", min=0, max=99, forceForTiles="location_shop_accessories_01_0;location_shop_accessories_01_1;location_shop_accessories_01_2;location_shop_accessories_01_3;location_shop_accessories_01_20;location_shop_accessories_01_21;location_shop_accessories_01_22;location_shop_accessories_01_23;fixtures_sinks_01_0;fixtures_sinks_01_1;fixtures_sinks_01_2;fixtures_sinks_01_3;fixtures_sinks_01_4;fixtures_sinks_01_5;fixtures_sinks_01_6;fixtures_sinks_01_7;fixtures_sinks_01_8;fixtures_sinks_01_9;fixtures_sinks_01_10;fixtures_sinks_01_11;fixtures_sinks_01_16;fixtures_sinks_01_17;fixtures_sinks_01_18;fixtures_sinks_01_19"},
                {name="StoreCounterBags", min=0, max=1, weightChance=100},
            }
        },
        displaycasebutcher = {
            procedural = true,
            procList = {
                {name="ButcherChops", min=1, max=99, weightChance=100},
                {name="ButcherFreezer", min=0, max=99},
				{name="ButcherGround", min=1, max=99, weightChance=60},
                {name="ButcherChicken", min=1, max=99, weightChance=80},
                {name="ButcherSmoked", min=1, max=99, weightChance=40},
				{name="ButcherSnacks", min=0, max=99, weightChance=100},
                
            }
        },
        freezer = {
            procedural = true,
            procList = {
                {name="ButcherFreezer", min=0, max=99},
            }
        },
        fridge = {
            procedural = true,
            procList = {
                {name="ButcherFreezer", min=0, max=99},
            }
        },
        metal_shelves = {
            procedural = true,
            procList = {
                {name="ButcherTools", min=0, max=99, weightChance=100},
            }
        },
        shelves = {
            procedural = true,
            procList = {
                {name="ButcherSnacks", min=0, max=99, weightChance=100},
                {name="GrillAcessories", min=0, max=99, weightChance=100},
                {name="StoreShelfCombo", min=0, max=99, forceForTiles="location_shop_generic_01_0;location_shop_generic_01_1"},
            }
        },
    },
	srgroceriesmtmeatfishstorage = {
			
		crate = {
            procedural = true,
            procList = {
                {name="ButcherFish", min=1, max=99, weightChance=100},
				{name="ButcherFreezer", min=0, max=99},
				{name="ServingTrayMaki", min=0, max=99, weightChance=80},
                {name="ServingTrayOnigiri", min=0, max=99, weightChance=80},
                {name="ServingTraySpringRolls", min=0, max=99, weightChance=40},
                {name="ServingTraySushiEgg", min=1, max=99, weightChance=100},
                {name="ServingTraySushiFish", min=1, max=99, weightChance=100},
				{name="SushiKitchenFridge", min=0, max=99},
            }
        },
		freezer = {
            procedural = true,
            procList = {
                {name="ButcherFish", min=1, max=99, weightChance=100},
				{name="ButcherFreezer", min=0, max=99},
            }
        },
		Storage = {
            procedural = true,
            procList = {
                {name="ButcherFish", min=1, max=99, weightChance=100},
				{name="ButcherFreezer", min=0, max=99},
				{name="ServingTrayMaki", min=0, max=99, weightChance=80},
                {name="ServingTrayOnigiri", min=0, max=99, weightChance=80},
                {name="ServingTraySpringRolls", min=0, max=99, weightChance=40},
                {name="ServingTraySushiEgg", min=1, max=99, weightChance=100},
                {name="ServingTraySushiFish", min=1, max=99, weightChance=100},
				{name="SushiKitchenFridge", min=0, max=99},
            }
        },
    },
	srgroceriesmtproduce = {
			
		smallcrate = {
            procedural = true,
            procList = {
                {name="GroceryStandVegetables1", min=1, max=99, weightChance=100},
                {name="GroceryStandVegetables2", min=1, max=99, weightChance=100},
                {name="GroceryStandVegetables3", min=1, max=99, weightChance=100},
                {name="GroceryStandVegetables4", min=1, max=99, weightChance=100},
                {name="GroceryStandFruits1", min=1, max=99, weightChance=100},
                {name="GroceryStandFruits2", min=1, max=99, weightChance=100},
                {name="GroceryStandFruits3", min=1, max=99, weightChance=100},
                {name="GroceryStandLettuce", min=1, max=99, weightChance=25},
            }
        },
		grocerstand = {
            procedural = true,
            procList = {
                {name="GroceryStandVegetables1", min=1, max=99, weightChance=100},
                {name="GroceryStandVegetables2", min=1, max=99, weightChance=100},
                {name="GroceryStandVegetables3", min=1, max=99, weightChance=100},
                {name="GroceryStandVegetables4", min=1, max=99, weightChance=100},
                {name="GroceryStandFruits1", min=1, max=99, weightChance=100},
                {name="GroceryStandFruits2", min=1, max=99, weightChance=100},
                {name="GroceryStandFruits3", min=1, max=99, weightChance=100},
                {name="GroceryStandLettuce", min=1, max=99, weightChance=25},
            }
        },
    },
	srgunstash = {

        crate = {
            procedural = true,
            procList = {
                {name="ArmyStorageGuns", min=0, max=99, weightChance=100},
			}	
        },
		locker = {
            procedural = true,
            procList = {
                {name="ArmyStorageGuns", min=0, max=99, weightChance=100},
			}	
        },
    },
	srherbshop = {

        counter = {
        rolls = 6,
        items = {
            "MortarPestle", 10,
            "PillsVitamins", 10,
            "Cigarettes", 10,
            "Antibiotics", 10,
            "PillsAntiDep", 10,
            "PillsBeta", 10,
            "Pills", 10,
            "PillsSleepingTablets", 10,
            "BookFirstAid1", 10,
            "BookFirstAid2", 10,
            "BookFarming1", 10,
            "BookFarming5", 10,
            "HerbalistMag", 10,
            "CookingMag1", 10,
            "Magazine", 10,
            "Nettles", 10,
            "Oregano", 10,
            "Parsley", 10,
            "Plantain", 10,
            "Rosehips", 10,
            "Rosemary", 10,
            "Sage", 10,
            "SunflowerSeeds", 10,
            "Thistle", 10,
            "Thyme", 10,
            "Violets", 10,
            "WildGarlic", 10,
            }
        },
		crate = {
            procedural = true,
            procList = {
                {name="CrateFertilizer", min=0, max=1, weightChance=100},
                {name="CrateSunflowerSeeds", min=0, max=1, weightChance=100},
                {name="GardenStoreMisc", min=0, max=99, weightChance=100},
            }
        },
		fridge = {
            procedural = true,
            procList = {
                {name="GroceryStandFruits1", min=0, max=1, weightChance=100},
                {name="GroceryStandFruits2", min=0, max=1, weightChance=100},
                {name="GroceryStandFruits3", min=0, max=99, weightChance=100},
            }
        },
		
		shelves = {
        rolls = 6,
        items = {
            "Acorn", 10,
            "Basil", 10,
            "BlackSage", 10,
            "Chives", 10,
            "Cilantro", 10,
            "Comfrey", 10,
            "CommonMallow", 10,
            "GingerRoot", 10,
            "Dandelions", 10,
            "Ginseng", 10,
            "GrapeLeaves", 10,
            "LemonGrass", 10,
            "Nettles", 10,
            "Oregano", 10,
            "Parsley", 10,
            "Plantain", 10,
            "Rosehips", 10,
            "Rosemary", 10,
            "Sage", 10,
            "SunflowerSeeds", 10,
            "Thistle", 10,
            "Thyme", 10,
            "Twigs", 10,
            "Violets", 10,
            "WildGarlic", 10,
            }
        },
		shelvesmag = {
        rolls = 6,
        items = {
            "HerbalistMag", 10,
            "CookingMag1", 10,
            "Magazine", 10,
            }
        },
    },
	srhousewareChangeroom = {
			
		locker = {
        rolls = 6,
        items = {
            "Apple", 10,
			"DeadRat", 10,
			"ChocoCakes", 10,
            "Underpants_White", 10,
            }
        },
    },
	srhousewarestore = {

        shelves = {
            procedural = true,
            procList = {
                {name="CrateFountainCups", min=0, max=99, weightChance=100},
				{name="CratePlasticTrays", min=0, max=99, weightChance=100},
				{name="GrillAcessories", min=0, max=99, weightChance=100},
				{name="StoreKitchenCutlery", min=0, max=99, weightChance=100},
				{name="StoreKitchenBags", min=0, max=99, weightChance=100},
				{name="StoreKitchenCups", min=0, max=99, weightChance=100},
				{name="StoreKitchenDishes", min=0, max=99, weightChance=100},
				{name="StoreKitchenGlasses", min=0, max=99, weightChance=100},
				{name="StoreKitchenPots", min=0, max=99, weightChance=100},
			}	
        },
    },
	srhousewarestorage = {

        crate = {
            procedural = true,
            procList = {
                {name="CrateFountainCups", min=0, max=99, weightChance=100},
				{name="CratePlasticTrays", min=0, max=99, weightChance=100},
				{name="CrateRedBBQ", min=0, max=99, weightChance=100},
				{name="ElectronicStoreAppliances", min=0, max=99, weightChance=100},
				{name="GrillAcessories", min=0, max=99, weightChance=100},
				{name="StoreKitchenCutlery", min=0, max=99, weightChance=100},
				{name="StoreKitchenBags", min=0, max=99, weightChance=100},
				{name="StoreKitchenCups", min=0, max=99, weightChance=100},
				{name="StoreKitchenDishes", min=0, max=99, weightChance=100},
				{name="StoreKitchenGlasses", min=0, max=99, weightChance=100},
				{name="StoreKitchenPots", min=0, max=99, weightChance=100},
            }
        },
		metal_shelves = {
            procedural = true,
            procList = {
                {name="CrateFountainCups", min=0, max=99, weightChance=100},
				{name="CratePlasticTrays", min=0, max=99, weightChance=100},
				{name="ElectronicStoreAppliances", min=0, max=99, weightChance=100},
				{name="GrillAcessories", min=0, max=99, weightChance=100},
				{name="StoreKitchenCutlery", min=0, max=99, weightChance=100},
				{name="StoreKitchenBags", min=0, max=99, weightChance=100},
				{name="StoreKitchenCups", min=0, max=99, weightChance=100},
				{name="StoreKitchenDishes", min=0, max=99, weightChance=100},
				{name="StoreKitchenGlasses", min=0, max=99, weightChance=100},
				{name="StoreKitchenPots", min=0, max=99, weightChance=100},
            }
        },	
    },
	sricecream = {

        counter = {
        rolls = 4,
        items = {
            "BaseballBat", 10,
            "BluePen", 8,
            "Book", 10,
            "Cone", 50,
            "Cone", 50,
            "Cone", 20,
            "Cone", 20,
            "Cone", 20,
			"Eraser", 8,
            "Glue", 2,
            "Notebook", 10,
            "Pen", 8,
            "Pencil", 10,
            "PaperNapkins", 20,
            "PaperNapkins", 10,
			"PlasticTray", 50,
            "PlasticTray", 20,
            "PlasticTray", 20,
            "PlasticTray", 10,
            "PlasticTray", 10,
			"RedPen", 8,
            "RubberBand", 6,
            "Scissors", 2,
			},
        },
		crate = {
            procedural = true,
            procList = {
                {name="CrateConesIceCream", min=0, max=99, weightChance=100},
				{name="CratePaperNapkins", min=0, max=99, weightChance=100},				
            }
        },
		icecreamfreezermt = {
            procedural = true,
            procList = {
                {name="FreezerIceCream", min=0, max=99, weightChance=100},				
            }
        },
    },
	srmagstore = {

        cigshelfmt = {
        rolls = 4,
        items = {
            "Cigarettes", 50,
            "Cigarettes", 20,
            "Cigarettes", 20,
            "Cigarettes", 10,
            "Cigarettes", 10,
			"Cigarettes", 50,
            "Cigarettes", 20,
            "Cigarettes", 20,
            "Cigarettes", 10,
            "Cigarettes", 10,
			"Cigarettes", 50,
            "Cigarettes", 20,
            "Cigarettes", 20,
            "Cigarettes", 10,
            "Cigarettes", 10,
			},
        },
		counter = {
            procedural = true,
            procList = {
                {name="StoreCounterBags", min=0, max=1, weightChance=20},
				{name="StoreCounterCleaning", min=0, max=1, weightChance=20},
				{name="StoreCounterTobacco", min=0, max=1, weightChance=20},
            }
        },
		crate = {
            procedural = true,
            procList = {
                {name="CrateCandyPackage", min=0, max=1, weightChance=40},
                {name="CrateChips", min=0, max=1, weightChance=100},
                {name="CrateChocolate", min=0, max=1, weightChance=40},
                {name="CrateCigarettes", min=0, max=1, weightChance=60},
                {name="CrateGum", min=0, max=1, weightChance=40},
                {name="CratePeanuts", min=0, max=1, weightChance=40},
                {name="CrateSodaBottles", min=0, max=1, weightChance=100},
                {name="CrateSodaCans", min=0, max=1, weightChance=100},
                {name="CrateSunflowerSeeds", min=0, max=1, weightChance=40},
                {name="CrateTortillaChips", min=0, max=1, weightChance=40},
            }
        },
		fridge = {
            procedural = true,
            procList = {
                {name="FridgeOther", min=1, max=99, weightChance=40},
                {name="FridgeSnacks", min=1, max=99, weightChance=100},
                {name="FridgeSoda", min=1, max=99, weightChance=100},
                {name="FridgeWater", min=1, max=99, weightChance=60},
            }
        },
		shelves = {
            procedural = true,
            procList = {
                {name="BarShelfLiquor", min=0, max=99},
            }
        },
    },
	srmelosrecords = {
		
		counter = {
            procedural = true,
            procList = {
                {name="StoreCounterCleaning", min=0, max=7, weightChance=100},
            }
        },	
		clothingrack = {
            procedural = true,
            procList = {
                {name="ArmySurplusOutfit", min=0, max=99, weightChance=100},
				{name="BandMerchClothes", min=0, max=99, weightChance=100},
				{name="ClothingStoresJacketsLeather", min=0, max=99, weightChance=100},
				{name="ClothingStoresSport", min=0, max=99, weightChance=100},
            }
        },
        metal_shelves = {
            procedural = true,
            procList = {
                {name="MusicStoreCDs", min=0, max=99, weightChance=100},
            }
        },	
		shelves = {
            procedural = true,
            procList = {
                {name="CrateChips", min=0, max=15, weightChance=100},
                {name="CratePeanuts", min=0, max=15, weightChance=40},
				{name="CrateSodaBottles", min=0, max=5, weightChance=100},
				{name="CrateSodaCans", min=0, max=5, weightChance=100},
            }
        },	
		shelvesmag = {
            procedural = true,
            procList = {
                {name="MagazineRackMixed", min=0, max=99, forceForRooms="hospitalroom"},
                {name="MagazineRackMaps", min=0, max=99, forceForRooms="mapfactory"},
            }
        },
		Storage = {
            procedural = true,
            procList = {
                {name="MusicStoreCDs", min=0, max=99, weightChance=100},
            }
        },	
		vinylcratemt = {
        procedural = true,
            procList = {
                {name="MusicStoreCDs", min=1, max=99, weightChance=100},
            }
        },
		vinylshelfmt = {
        procedural = true,
            procList = {
                {name="MusicStoreCDs", min=1, max=99, weightChance=100},
            }
        },
		wardrobe = {
        procedural = true,
            procList = {
                {name="WardrobeRedneck", min=4, max=99, weightChance=100},
            }
        },
    },
	srmodelagency = {

        bin = {
            rolls = 1,
            items = {
                "HottieZ", 2,
				"Tissue", 10,
                "Sausage", 1,
                   
            },
        },
		crate = {
            procedural = true,
            procList = {
                {name="CrateVHSTapes", min=0, max=99, weightChance=100},
				{name="CrateSpiffoMerch", min=0, max=99, weightChance=100},
				{name="Photographer", min=0, max=99, weightChance=100},
				{name="PoolLockers", min=0, max=99, weightChance=100},
				{name="PlankStashMagazine", min=0, max=99, weightChance=100},
				{name="LingerieStoreOutfits", min=0, max=99, weightChance=100},
				
			}	
        },
		filingcabinet = {
            rolls = 1,
            items = {
                "HottieZ", 10,
            },
        },
		locker = {
            procedural = true,
            procList = {
                {name="CrateCostume", min=0, max=99, weightChance=100},
				{name="ClothingStoresSummer", min=0, max=99, weightChance=100},
				{name="StripClubDressers", min=0, max=99, weightChance=100},
				{name="LingerieStoreOutfits", min=0, max=99, weightChance=100},
			}	
        },
		shelves = {
            rolls = 1,
            items = {
                "HottieZ", 30,
            },
        },
		wardrobe = {
            procedural = true,
            procList = {
                {name="CrateCostume", min=0, max=99, weightChance=100},
				{name="ClothingStoresSummer", min=0, max=99, weightChance=100},
				{name="StripClubDressers", min=0, max=99, weightChance=100},
				{name="LingerieStoreOutfits", min=0, max=99, weightChance=100},
			}	
        },
    },
	srmodelchangeroom = {

        bin = {
            rolls = 1,
            items = {
                "HottieZ", 2,
				"Tissue", 10,
                "Sausage", 1,
                   
            },
        },
		clothingrack = {
            procedural = true,
            procList = {
                {name="BandMerchClothes", min=0, max=99, weightChance=100},
				{name="CrateCostume", min=0, max=99, weightChance=100},
				{name="ClothingStoresSummer", min=0, max=99, weightChance=100},
				{name="StripClubDressers", min=0, max=99, weightChance=100},
				{name="LingerieStoreOutfits", min=0, max=99, weightChance=100},
            }
        },        
		crate = {
            procedural = true,
            procList = {
                {name="CrateVHSTapes", min=0, max=99, weightChance=100},
				{name="CrateSpiffoMerch", min=0, max=99, weightChance=100},
				{name="Photographer", min=0, max=99, weightChance=100},
				{name="PoolLockers", min=0, max=99, weightChance=100},
				{name="PlankStashMagazine", min=0, max=99, weightChance=100},
				
			}	
        },
		dresser = {
            procedural = true,
            procList = {
                {name="SalonCounter", min=0, max=99},
				{name="SalonShelfHaircare", min=0, max=99, weightChance=100},
                {name="SalonShelfTowels", min=0, max=99, weightChance=10},
				{name="MedicalClinicDrugs", min=1, max=10, weightChance=70},
				{name="CrateCigarettes", min=0, max=1, weightChance=60},
				{name="LingerieStoreOutfits", min=0, max=99, weightChance=100},
            }
        },
		filingcabinet = {
            rolls = 1,
            items = {
                "HottieZ", 10,
            },
        },
		locker = {
            procedural = true,
            procList = {
                {name="CrateCostume", min=0, max=99, weightChance=100},
				{name="ClothingStoresSummer", min=0, max=99, weightChance=100},
				{name="StripClubDressers", min=0, max=99, weightChance=100},
				{name="SalonCounter", min=0, max=99},
				{name="SalonShelfHaircare", min=0, max=99, weightChance=100},
                {name="SalonShelfTowels", min=0, max=99, weightChance=10},
				{name="MedicalClinicDrugs", min=1, max=10, weightChance=70},
				{name="CrateCigarettes", min=0, max=1, weightChance=60},
				{name="LingerieStoreOutfits", min=0, max=99, weightChance=100},
			}	
        },
		shelves = {
            rolls = 1,
            items = {
                "HottieZ", 30,
            },
        },
		wardrobe = {
            procedural = true,
            procList = {
                {name="CrateCostume", min=0, max=99, weightChance=100},
				{name="ClothingStoresSummer", min=0, max=99, weightChance=100},
				{name="StripClubDressers", min=0, max=99, weightChance=100},
				{name="SalonCounter", min=0, max=99},
				{name="SalonShelfHaircare", min=0, max=99, weightChance=100},
                {name="SalonShelfTowels", min=0, max=99, weightChance=10},
				{name="MedicalClinicDrugs", min=1, max=10, weightChance=70},
				{name="CrateCigarettes", min=0, max=1, weightChance=60},
				{name="LingerieStoreOutfits", min=0, max=99, weightChance=100},
			}	
        },
    },
	srmotelroom = {
        bin = {
            rolls = 0,
            items = {

            },
        },
        counter = {
            procedural = true,
            procList = {
                {name="StoreCounterCleaning", min=0, max=7, weightChance=100},
            }
        },
		dresser = {
            rolls = 0,
            items = {

            },
        },
        freezer = {
            rolls = 0,
            items = {

            },
        },
        fridge = {
            rolls = 0,
            items = {

            },
        },
        locker = {
            rolls = 1,
            items = {
                "HuntingMag1", 1,
				"HuntingMag2", 1,
				"HuntingMag3", 1,
				"HuntingKnife", 6,
				"Revolver", 6,            
            },
        },
		metal_shelves = {
            procedural = true,
            procList = {
                {name="MotelLinens", min=0, max=99, weightChance=100},
                {name="MotelTowels", min=0, max=99, weightChance=100},
            }
        },
        shelves = {
            procedural = true,
            procList = {
                {name="BookstoreBooks", min=0, max=99, weightChance=100},
				{name="BookstoreMisc", min=0, max=99, weightChance=100},
            }
        },
		sidetable = {
            rolls = 1,
            items = {
                "Book", 200,
            },
        },
        wardrobe = {
            procedural = true,
            procList = {
                {name="MotelLinens", min=0, max=1, weightChance=100},
                {name="MotelTowels", min=0, max=1, weightChance=100},
            }
        },
    },
	srmotelroombathroom = {
        bin = {
            rolls = 0,
            items = {

            },
        },
        counter = {
            procedural = true,
            procList = {
                {name="StoreCounterCleaning", min=0, max=7, weightChance=100},
            }
        },
		medicine = {
            rolls = 1,
            items = {
                "FirstAidKit", 2,
            },
        },
    },	
	srmotelroomkitchen = {
        bin = {
            rolls = 0,
            items = {

            },
        },
        counter = {
            procedural = true,
            procList = {
                {name="StoreCounterCleaning", min=0, max=7, weightChance=100},
            }
        },
		freezer = {
            rolls = 0,
            items = {

            },
        },
        fridge = {
            rolls = 0,
            items = {

            },
        },
    },
	srmotelroomkitchentrashed = {
        bin = {
            rolls = 0,
            items = {

            },
        },
        counter = {
            rolls = 1,
            items = {
                "DeadSquirrel", 20,
            },
        },
    },
	srmotelroomtrashed = {
        bin = {
            rolls = 0,
            items = {

            },
        },
        counter = {
            procedural = true,
            procList = {
                {name="StoreCounterCleaning", min=0, max=7, weightChance=100},
            }
        },
		dresser = {
            rolls = 0,
            items = {

            },
        },
        freezer = {
            rolls = 0,
            items = {

            },
        },
        fridge = {
            rolls = 0,
            items = {

            },
        },
        metal_shelves = {
            procedural = true,
            procList = {
                {name="MotelLinens", min=0, max=99, weightChance=100},
                {name="MotelTowels", min=0, max=99, weightChance=100},
            }
        },
        shelves = {
            rolls = 1,
            items = {
                "HottieZ", 2,
            },
        },
		sidetable = {
            rolls = 1,
            items = {
                
            },
        },
        wardrobe = {
            procedural = true,
            procList = {
                {name="MotelLinens", min=0, max=1, weightChance=100},
                {name="MotelTowels", min=0, max=1, weightChance=100},
            }
        },
    },
	srpaintshop = {
		
		counter = {
            procedural = true,
            procList = {
                {name="StoreCounterCleaning", min=0, max=7, weightChance=100},
            }
        },	
		clothingrack = {
            procedural = true,
            procList = {
                {name="ArmySurplusOutfit", min=0, max=99, weightChance=100},
				{name="BandMerchClothes", min=0, max=99, weightChance=100},
				{name="ClothingStoresJacketsLeather", min=0, max=99, weightChance=100},
				{name="ClothingStoresSport", min=0, max=99, weightChance=100},				  
            }
        },
        crate = {
            procedural = true,
            procList = {
                {name="ArtSupplies", min=0, max=99, weightChance=100},
				{name="Chemistry", min=0, max=99, weightChance=100},
				{name="CratePaint", min=0, max=99, weightChance=100},
				{name="WallDecor", min=0, max=99, weightChance=100},
            }
        },
		metal_shelves = {
            procedural = true,
            procList = {
                {name="ArtSupplies", min=0, max=99, weightChance=100},
				{name="Chemistry", min=0, max=99, weightChance=100},
				{name="CratePaint", min=0, max=99, weightChance=100},
				{name="WallDecor", min=0, max=99, weightChance=100},
            }
        },	
		shelves = {
            procedural = true,
            procList = {
                {name="ArtSupplies", min=0, max=99, weightChance=100},
				{name="Chemistry", min=0, max=99, weightChance=100},
				{name="CratePaint", min=0, max=99, weightChance=100},
				{name="WallDecor", min=0, max=99, weightChance=100},
            }
        },	
		shelvesmag = {
            procedural = true,
            procList = {
                {name="MagazineRackMixed", min=0, max=99, forceForRooms="hospitalroom"},
                {name="MagazineRackMaps", min=0, max=99, forceForRooms="mapfactory"},
            }
        },
		Storage = {
            procedural = true,
            procList = {
                {name="ArtSupplies", min=0, max=99, weightChance=100},
				{name="Chemistry", min=0, max=99, weightChance=100},
				{name="CratePaint", min=0, max=99, weightChance=100},
				{name="WallDecor", min=0, max=99, weightChance=100},
            }
        },			
    },
	srpetfoodstore = {

        counter = {
            procedural = true,
            procList = {
                {name="StoreCounterCleaning", min=0, max=1, weightChance=100},
            }
        },
		crate = {
            procedural = true,
            procList = {
                {name="ButcherSnacks", min=0, max=99},
				{name="DogFoodFactoryCans", min=0, max=99, weightChance=100},				
            }
        },
		freezer = {
            procedural = true,
            procList = {
                {name="ButcherFreezer", min=0, max=1, weightChance=100},
            }
        },
		locker = {
            procedural = true,
            procList = {
                {name="HuntingLockers", min=0, max=99,},
            }
        },
		metal_shelves = {
            procedural = true,
            procList = {
                {name="ButcherSnacks", min=0, max=99},
				{name="CratePetSupplies", min=0, max=99},
				{name="DogFoodFactoryCans", min=0, max=99},
            }
        },
		shelves = {
            procedural = true,
            procList = {
                {name="ButcherSnacks", min=0, max=99},
				{name="CratePetSupplies", min=0, max=99},
				{name="DogFoodFactoryCans", min=0, max=99},
            }
        },
		shelvesmag = {
            procedural = true,
            procList = {
                {name="CampingStoreBooks", min=0, max=4, weightChance=80},
				{name="MagazineRackMaps", min=0, max=1, weightChance=50},
                {name="MagazineRackNewspaper", min=0, max=1, weightChance=50},
                {name="MagazineRackMixed", min=0, max=99, weightChance=100},
            }
        },
		Storage = {
            procedural = true,
            procList = {
                {name="ButcherSnacks", min=0, max=99},
				{name="DogFoodFactoryCans", min=0, max=99, weightChance=100},				
            }
        },
    },
	srpharmacystorage = {
        isShop = true,
        counter = {
            procedural = true,
            procList = {
                {name="MedicalClinicDrugs", min=1, max=4, weightChance=100},
                {name="MedicalClinicTools", min=1, max=2, weightChance=100},
                {name="MedicalClinicOutfit", min=1, max=2, weightChance=100},
            }
        },
		crate = {
            procedural = true,
            procList = {
                {name="MedicalClinicDrugs", min=1, max=4, weightChance=100},
                {name="MedicalClinicTools", min=1, max=2, weightChance=100},
                {name="MedicalClinicOutfit", min=1, max=2, weightChance=100},
				{name="Chemistry", min=1, max=99, weightChance=100},
				{name="ScienceMisc", min=1, max=99, weightChance=100},
				{name="TestingLab", min=1, max=99, weightChance=100},
            }
        },
		desk = {
            procedural = true,
            procList = {
                {name="MedicalClinicDrugs", min=1, max=4, weightChance=100},
                {name="MedicalClinicTools", min=1, max=2, weightChance=100},
				{name="Chemistry", min=1, max=99, weightChance=100},
				{name="ScienceMisc", min=1, max=99, weightChance=100},
				{name="TestingLab", min=1, max=99, weightChance=100},
            }
        },
        freezer = {
            rolls = 1,
            items = {

            }
        },
        fridge = {
            procedural = true,
            procList = {
                {name="FridgeWater", min=0, max=12},
            }
        },
        metal_shelves = {
            procedural = true,
            procList = {
                {name="MedicalStorageDrugs", min=1, max=6, weightChance=100},
                {name="MedicalStorageTools", min=1, max=4, weightChance=100},
                {name="MedicalStorageOutfit", min=1, max=2, weightChance=100},				
				{name="Chemistry", min=1, max=99, weightChance=100},
				{name="ScienceMisc", min=1, max=99, weightChance=100},
				{name="TestingLab", min=1, max=99, weightChance=100},
            }
        },
        shelves = {
            procedural = true,
            procList = {
                {name="MedicalStorageDrugs", min=1, max=6, weightChance=100},
                {name="MedicalStorageTools", min=1, max=4, weightChance=100},
                {name="MedicalStorageOutfit", min=1, max=2, weightChance=100},
				{name="Chemistry", min=1, max=99, weightChance=100},
				{name="ScienceMisc", min=1, max=99, weightChance=100},
				{name="TestingLab", min=1, max=99, weightChance=100},
            }
        },
    },
	srspiffomerchfactory = {

        crate = {
            procedural = true,
            procList = {
                {name="CrateSpiffoMerch", min=0, max=99},			
            }
        },
		locker = {
            procedural = true,
            procList = {
                {name="FactoryLockers", min=0, max=99,},
            }
        },
		metal_shelves = {
            procedural = true,
            procList = {
                {name="JanitorCleaning", min=0, max=99},
				{name="JanitorMisc", min=0, max=99},
				{name="JanitorTools", min=0, max=99},
            }
        },
		Storage = {
            procedural = true,
            procList = {
                {name="CrateSpiffoMerch", min=0, max=99},			
            }
        },
		toolcabinet = {
            procedural = true,
            procList = {
                {name="CrateTools", min=0, max=99, weightChance=20},
            }
        },
    },
	srswimlaundry = {

        counter = {
            procedural = true,
            procList = {
                {name="JanitorChemicals", min=0, max=99, weightChance=100},
				{name="JanitorCleaning", min=0, max=99, weightChance=100},
            }
        },
		clothingdryer = {
        rolls = 4,
        items = {
            "BathTowel", 20,
            "BathTowel", 20,
            "BathTowel", 10,
            "BathTowel", 10,
            "Bikini_Pattern01", 0.2,
            "Bikini_TINT", 0.2,
            "DishCloth", 20,
            "DishCloth", 10,
            "LongCoat_Bathrobe", 0.1,
            "LongCoat_Bathrobe", 0.1,
            "LongCoat_Bathrobe", 0.1,
            "Socks_Ankle", 20,
            "Socks_Ankle", 10,
            "Socks_Long", 10,
			"Sheet", 20,
            "Sheet", 10,
            "Swimsuit_TINT", 10,
			"SwimTrunks_Blue", 0.1,
            "SwimTrunks_Green", 0.1,
            "SwimTrunks_Red", 0.1,
            "SwimTrunks_Yellow", 0.1,
            },
        },
		clothingwasher = {
        rolls = 4,
        items = {
            "BathTowel", 20,
            "BathTowel", 20,
            "BathTowel", 10,
            "BathTowel", 10,
            "Bikini_Pattern01", 0.2,
            "Bikini_TINT", 0.2,
            "DishCloth", 20,
            "DishCloth", 10,
            "LongCoat_Bathrobe", 0.1,
            "LongCoat_Bathrobe", 0.1,
            "LongCoat_Bathrobe", 0.1,
            "Socks_Ankle", 20,
            "Socks_Ankle", 10,
            "Socks_Long", 10,
			"Sheet", 20,
            "Sheet", 10,
            "Swimsuit_TINT", 10,
			"SwimTrunks_Blue", 0.1,
            "SwimTrunks_Green", 0.1,
            "SwimTrunks_Red", 0.1,
            "SwimTrunks_Yellow", 0.1,
            },
        },
		laundryrackmt = {
        rolls = 4,
        items = {
            "BathTowel", 20,
            "BathTowel", 20,
            "BathTowel", 10,
            "BathTowel", 10,
            "Bikini_Pattern01", 0.2,
            "Bikini_TINT", 0.2,
            "DishCloth", 20,
            "DishCloth", 10,
            "LongCoat_Bathrobe", 0.1,
            "LongCoat_Bathrobe", 0.1,
            "LongCoat_Bathrobe", 0.1,
            "Socks_Ankle", 20,
            "Socks_Ankle", 10,
            "Socks_Long", 10,
			"Sheet", 20,
            "Sheet", 10,
            "Swimsuit_TINT", 10,
			"SwimTrunks_Blue", 0.1,
            "SwimTrunks_Green", 0.1,
            "SwimTrunks_Red", 0.1,
            "SwimTrunks_Yellow", 0.1,
            },
        },
		laundrydryerbasic = {
        rolls = 4,
        items = {
            "BathTowel", 20,
            "BathTowel", 20,
            "BathTowel", 10,
            "BathTowel", 10,
            "Bikini_Pattern01", 0.2,
            "Bikini_TINT", 0.2,
            "DishCloth", 20,
            "LongCoat_Bathrobe", 0.1,
            "LongCoat_Bathrobe", 0.1,
            "LongCoat_Bathrobe", 0.1,
            "DishCloth", 10,
            "Socks_Ankle", 20,
            "Socks_Ankle", 10,
            "Socks_Long", 10,
			"Sheet", 20,
            "Sheet", 10,
            "Swimsuit_TINT", 10,
			"SwimTrunks_Blue", 0.1,
            "SwimTrunks_Green", 0.1,
            "SwimTrunks_Red", 0.1,
            "SwimTrunks_Yellow", 0.1,
            },
        },
		metal_shelves = {
            procedural = true,
            procList = {
                {name="JanitorChemicals", min=0, max=99, weightChance=100},
				{name="JanitorCleaning", min=0, max=99, weightChance=100},
				{name="JanitorMisc", min=0, max=99, weightChance=100},
				{name="JanitorTools", min=0, max=99, weightChance=100},				
            }
        },
    },
	srtheatrelobby = {

        counter = {
        rolls = 4,
        items = {
			"CandyPackage", 20,
            "CandyPackage", 10,
            "Chocolate", 8,
            "Gum", 10,
            "GummyBears", 10,
            "GummyWorms", 10,
            "JellyBeans", 10,
            "Jujubes", 10,
            "LicoriceBlack", 4,
            "LicoriceRed", 10,
			"Popcorn", 50,
            "Popcorn", 20,
            "Popcorn", 20,
            "Popcorn", 10,
            "Popcorn", 10,
            "Pop", 20,
            "Pop", 10,
            "Pop2", 20,
            "Pop2", 10,
            "Pop3", 20,
            "Pop3", 10,
            "PopBottle", 20,
            "PopBottle", 20,
            "PopBottle", 10,
            "PopBottle", 10,
			},
        },
		crate = {
            procedural = true,
            procList = {
                {name="CrateConesIceCream", min=0, max=99, weightChance=100},
				{name="CratePaperNapkins", min=0, max=99, weightChance=100},				
            }
        },
		freezer = {
            procedural = true,
            procList = {
                {name="FreezerIceCream", min=0, max=99, weightChance=100},				
            }
        },
    },
	srtinkasflowers = {

        counter = {
            procedural = true,
            procList = {
                {name="GardenStoreMisc", min=0, max=99, weightChance=100},
				{name="StoreCounterCleaning", min=0, max=99, weightChance=100},
            }
        },
		crate = {
            procedural = true,
            procList = {
                {name="CrateFertilizer", min=0, max=99, weightChance=100},
				{name="CrateSunflowerSeeds", min=0, max=99, weightChance=100},				
            }
        },
		metal_shelves = {
            procedural = true,
            procList = {
                {name="GardenStoreMisc", min=0, max=99, weightChance=100},				
            }
        },
    },
	srwarehouseyellow = {

        counter = {
            procedural = true,
            procList = {
                {name="OfficeCounter", min=0, max=99},
            }
        },
		crate = {
            procedural = true,
            procList = {
                {name="CrateCanning", min=0, max=99, weightChance=100},
				{name="StoreKitchenDishes", min=0, max=1, weightChance=20},
                {name="StoreKitchenGlasses", min=0, max=1, weightChance=20},
                {name="StoreKitchenPots", min=0, max=1, weightChance=20},                
            }
        },
		metal_shelves = {
            procedural = true,
            procList = {
                {name="JanitorTools", min=0, max=99, weightChance=100},				
            }
        },
		shelves = {
            procedural = true,
            procList = {
                {name="CrateCanning", min=0, max=99, weightChance=100},
				{name="StoreKitchenDishes", min=0, max=1, weightChance=20},
                {name="StoreKitchenGlasses", min=0, max=1, weightChance=20},
                {name="StoreKitchenPots", min=0, max=1, weightChance=20},                
            }
        },
    },
}


table.insert(Distributions, 2, shortrestdistributionTable);