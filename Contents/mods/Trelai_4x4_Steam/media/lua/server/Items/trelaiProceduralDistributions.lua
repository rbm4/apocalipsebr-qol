--ProceduralDistributions = distributionTable;
--Custom Loot Rooms for trelai
local function preDistributionMerge()
    ProceduralDistributions.list.vaultgoldstack = {
        rolls = 50,
        items = {
            "Trelai.TrelaiGoldBar", 5,
            "Trelai.TrelaiGoldBar", 5,
            "Trelai.TrelaiGoldBar", 5,
            "Trelai.TrelaiGoldBar", 5,
            "Trelai.TrelaiGoldBar", 5,
            "Trelai.TrelaiGoldBar", 5,
            "Trelai.TrelaiGoldBar", 5,
            "Money", 10000,
        },
   }

--LootCrate For Roomzone
    ProceduralDistributions.list.BedroomAcademy = {
        rolls = 15,
        items = {
            "Trelai.Tshirt_TACADEMY", 100,          
        },
    }
    ProceduralDistributions.list.Crown = {
        rolls = 2,
        items = {
            --Vanilla Items
            --Trelai Items
            "Trelai.Hat_Crown1", 200,
            "Trelai.Hat_Crown2", 200,    
        },
    }

    ProceduralDistributions.list.PoliceClothes = {
        rolls = 6,
        items = {
            --Vanilla Items
            --Trelai Items
            "Trelai.TrelaiJacket_Police", 100,
            "Trelai.TrelaiJacket_Police", 100,
            "Trelai.Trousers_TrelaiPolice", 100,
            "Trelai.Trousers_TrelaiPolice", 100,
            "Trelai.Hat_TrelaiPolice", 100,
            "Trelai.Hat_TrelaiPolice", 100,
        },
    }

    ProceduralDistributions.list.FireClothes = {
        rolls = 6,
        items = {
            --Vanilla Items
            --Trelai Items
            "Trelai.Trousers_TFireman", 100,
            "Trelai.Trousers_TFireman", 100,
            "Trelai.Jacket_TFireman", 100,
            "Trelai.Jacket_TFireman", 100,
            "Trelai.Hat_TFireman", 100,
            "Trelai.Hat_TFireman", 100,
        },
    }
    ProceduralDistributions.list.StoryNote = {
        rolls = 1,
        items = {
            --Vanilla Items
            --Trelai Items
            "Trelai.TrelaiGuidePage0", 200,
            "Trelai.trelainotes_01", 200,
            "Trelai.trelainotes_02", 200,
        },
    }
    ProceduralDistributions.list.bat = {
        rolls = 1,
        items = {
            --Vanilla Items
            --Trelai Items
            "Trelai.BaseballBatTrelai", 200,
        },
    }
    ProceduralDistributions.list.treasurechest = {
        rolls = 3,
        items = {
            --Vanilla Items
            --Trelai Items
            "AssaultRifle", 20,
            "AssaultRifle2", 20,
            "NoiseTrapTriggered", 20, 
            "Katana", 10, 
            "Machete", 10, 
            "BarBell", 1, 
            "308Box", 20, 
            "556Box", 20, 
            "HottieZ", 10,
            "FirstAidKit", 2,
            "Bag_ShotgunBag", 1,
            "Bag_ShotgunDblBag", 1,
            "Bag_ShotgunDblSawnoffBag", 1,
            "Bag_ShotgunSawnoffBag", 1,
            "BeefJerky", 8,
            "Chocolate", 8,
            "Crisps", 10,
            "Crisps2", 10,
            "Crisps3", 10,
            "Crisps4", 10,
            "Crowbar", 1,
            "PeanutButter", 10,
            "TinnedBeans", 10,
            "TinnedSoup", 10,
            "TunaTin", 10,
            "WaterBottleFull", 10,
            "WaterBottleFull", 10,
            "Sledgehammer2", 0.5,
            --Vanilla Items
            "Money", 10000,
            "Money", 10000,
            "Pistol", 0.5,
            "Pistol2", 0.1,
            "Bag_BigHikingBag", 0.005,
            "PistolCase1", 0.50,
            "PistolCase2", 0.005,
            "PistolCase3", 0.001,
            "Radio.CDplayer", 1,
            "Radio.RadioBlack", 0.5,
            "Radio.RadioRed", 0.2,
            "BaseballBat", 1,
            "SewingKit", 4,
            --Trelai Items
            "Trelai.Tshirt_TACADEMY", 1,
            "Trelai.ThickBoxers_Hearts", 2,
            "Trelai.trelaimap", 1,
            "Trelai.BaseballBatTrelai", 2,
        },
    }
    --Insert into Vanilla Tables
    table.insert(ProceduralDistributions.list.MagazineRackMaps.items, "Trelai.trelaimap");
    table.insert(ProceduralDistributions.list.MagazineRackMaps.items, 10);
	table.insert(ProceduralDistributions.list.MagazineRackMaps.items, "Trelai.trelaimap4");
    table.insert(ProceduralDistributions.list.MagazineRackMaps.items, 10);
	table.insert(ProceduralDistributions.list.MagazineRackMaps.items, "Trelai.trelaimap3");
    table.insert(ProceduralDistributions.list.MagazineRackMaps.items, 10);
    table.insert(ProceduralDistributions.list.MagazineRackMaps.items, "Trelai.TrelaiGazette");
    table.insert(ProceduralDistributions.list.MagazineRackMaps.items, 10);

    table.insert(ProceduralDistributions.list.BedroomSideTable.items, "Trelai.Tshirt_TACADEMY");
    table.insert(ProceduralDistributions.list.BedroomSideTable.items, 1);
end

Events.OnPreDistributionMerge.Add(preDistributionMerge);