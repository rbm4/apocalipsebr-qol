--***********************************************************
--**                    Trelai Stash Maps                  **
--***********************************************************
--Trelai.Trelaimap3' South
--Trelai.Trelaimap4' North
--Trelai.Trelaimap'  All
--Trelai.TrelaiStory - Image
--Trelai.TrelaiStory2 - Map and image
--Might be bugged in multiplayer due to no translations setup
require "StashDescriptions/StashUtil";

-- Army Roof
local stashMap1 = StashUtil.newStash("TrelaiStashMap8", "Map", "Trelai.trelaimap", "Stash_AnnotedMap");
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 7353;
stashMap1.buildingY = 7087;
stashMap1.zombies = 10;
stashMap1.barricades = 0;
stashMap1.spawnTable = "SurvivorCache1";
stashMap1:addContainer("ToolsBox",nil,"Base.Bag_DuffelBag",nil,"bedroom",nil,nil);
stashMap1:addContainer("ToolsBox","carpentry_01_16",nil,"kitchen",nil,nil,nil);
stashMap1:addContainer("GunBox","carpentry_01_16",nil,nil,nil,nil,nil);
stashMap1:addContainer("ShotgunBox",nil,"Base.Bag_DuffelBag",nil,nil,nil,nil);
stashMap1:addStamp("FaceDead", nil, 7137, 7037, 1, 0, 0)
stashMap1:addStamp("Skull", nil, 7135, 7051, 1, 0, 0)
stashMap1:addStamp(nil, "Trelai Fire Station", 7123, 7019, 1, 0, 0)
stashMap1:addStamp(nil, "Trelai Police Station", 6878, 7017, 1, 0, 0)
stashMap1:addStamp(nil, "Cemetary", 6658, 7135, 1, 0, 0)
stashMap1:addStamp(nil, "Food", 7238, 7059, 1, 0, 0)
stashMap1:addStamp("Burger", nil, 7210, 7055, 1, 0, 0)
stashMap1:addStamp("Burger", nil, 7272, 7040, 1, 0, 0)
stashMap1:addStamp("Skull", nil, 6674, 7124, 1, 0, 0)
stashMap1:addStamp("Skull", nil, 6880, 7043, 1, 0, 0)

stashMap1:addStamp(nil, "Firemen Horde", 7117, 7045, 0, 0, 0);
stashMap1:addStamp("Fire", nil, 7141, 7038, 1, 0, 0);
stashMap1:addStamp("Fire", nil, 7129, 7038, 1, 0, 0);
stashMap1:addStamp("Fire", nil, 7136, 7027, 1, 0, 0);
stashMap1:addStamp(nil, "Gold Vault", 6642, 7421, 1, 0, 0);
stashMap1:addStamp("FaceDead", nil, 6653, 7413, 1, 0, 0);
stashMap1:addStamp("FaceDead", nil, 6685, 7444, 1, 0, 0);
stashMap1:addStamp("Exclamation", nil, 6684, 7415, 1, 0, 0);
stashMap1:addStamp("Exclamation", nil, 6694, 7401, 1, 0, 0);
stashMap1:addStamp("Exclamation", nil, 6657, 7443, 1, 0, 0);
--stashMap1:addStamp(nil, "Trelai_NoTranslations", 7647, 7561, 0, 0, 1);

-- guns ( FIrehouse)
local stashMap1 = StashUtil.newStash("TrelaiStashMap1", "Map", "Trelai.trelaimap4", "Stash_AnnotedMap");
--stashMap1.spawnOnlyOnZed = true;
stashMap1.daysToSpawn = "0";
stashMap1.zombies = 10;
stashMap1.traps = "2";
stashMap1.barricades = 0;
stashMap1.buildingX = 7139;
stashMap1.buildingY = 7045;
stashMap1.spawnTable = "GunCache2";
stashMap1:addContainer("SurvivorCrate", "carpentry_01_16", nil, nil, 13035, 2837, 0);
stashMap1:addContainer("GunBox","floors_interior_tilesandwood_01_62",nil,"firestorage",nil,nil,nil);
stashMap1:addContainer("GunBox","carpentry_01_16",nil,nil,nil,nil,nil);
--stashMap1:addStamp("map_x.png",nil,7139,7045,1,0,0);
stashMap1:addStamp("X",nil,7139,7045,1,0,0);
stashMap1:addStamp(nil, "FireStation", 7121, 7010, 1, 0, 0);
--stashMap1:addStamp(nil, "Trelai_NoTranslations", 7647, 7561, 0, 0, 1);


--SurvivorHouse guns GrandAve&checkpoints
local stashMap1 = StashUtil.newStash("TrelaiStashMap2", "Map", "Trelai.trelaimap", "Stash_AnnotedMap");
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 7117;
stashMap1.buildingY = 6780;
stashMap1.zombies = 10;
stashMap1.barricades = 0;
stashMap1.spawnTable = "GunCache2";
stashMap1:addContainer("GunBox","floors_interior_tilesandwood_01_62",nil,"bedroom",nil,nil,nil);
stashMap1:addContainer("GunBox","carpentry_01_16",nil,nil,nil,nil,nil);
--stashMap1:addStamp("map_x.png",nil,7117,6780,0,0,0);
stashMap1:addStamp("X", nil, 7117, 6780, 1, 0, 0);
stashMap1:addStamp("House", nil, 7106, 6765, 1, 0, 0);
stashMap1:addStamp(nil, "Survivor House", 7115, 6756, 1, 0, 0);
stashMap1:addStamp("Skull", nil, 7132, 6780, 1, 0, 0);
stashMap1:addStamp(nil, "Checkpoint", 7148, 6807, 1, 0, 0);
stashMap1:addStamp(nil, "Checkpoint", 7026, 6816, 1, 0, 0);
stashMap1:addStamp(nil, "CheckPoint", 6721, 7300, 1, 0, 0);
stashMap1:addStamp(nil, "CheckPoint", 6711, 7426, 1, 0, 0);
stashMap1:addStamp(nil, "Checkpoint", 6966, 7541, 1, 0, 0);
stashMap1:addStamp(nil, "Checkpoint", 6861, 6997, 1, 0, 0);
stashMap1:addStamp(nil, "Checkpoint", 6936, 6997, 1, 0, 0);
stashMap1:addStamp("Question", nil, 6726, 6817, 1, 0, 0);
stashMap1:addStamp("Question", nil, 6999, 6843, 1, 0, 0);
stashMap1:addStamp("Question", nil, 6997, 6799, 1, 0, 0);
stashMap1:addStamp("Question", nil, 7689, 7114, 1, 0, 0);
stashMap1:addStamp("Question", nil, 7672, 7235, 1, 0, 0);
stashMap1:addStamp("Question", nil, 6628, 7728, 1, 0, 0);
stashMap1:addStamp("Question", nil, 6735, 7379, 1, 0, 0);
stashMap1:addStamp("Question", nil, 6723, 7282, 1, 0, 0);
stashMap1:addStamp("Question", nil, 6734, 7261, 1, 0, 0);
stashMap1:addStamp("Question", nil, 6663, 6653, 1, 0, 0);
stashMap1:addStamp("Burger", nil, 6640, 6687, 1, 0, 0);
stashMap1:addStamp("Burger", nil, 6794, 7069, 1, 0, 0);
stashMap1:addStamp("Burger", nil, 7211, 7043, 1, 0, 0);
stashMap1:addStamp("Burger", nil, 7273, 7046, 1, 0, 0);
stashMap1:addStamp("Burger", nil, 6762, 7082, 1, 0, 0);
stashMap1:addStamp("FaceHappy", nil, 6845, 6982, 1, 0, 0);
stashMap1:addStamp("Skull", nil, 7684, 7315, 1, 0, 0);
stashMap1:addStamp(nil, "Airport", 7649, 7283, 1, 0, 0);


 

-- shotgun  -- The Academy
local stashMap1 = StashUtil.newStash("TrelaiStashMap3", "Map", "Trelai.trelaimap3", "Stash_AnnotedMap");
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 7691;
stashMap1.buildingY = 7616;
stashMap1.zombies = 2;
stashMap1.barricades = 25;
stashMap1.spawnTable = "ShotgunCache2";
stashMap1.spawnTable = "SurvivorCache1";
stashMap1:addContainer("ShotgunBox",nil,"Base.Bag_DuffelBag",nil,"bedroom",nil,nil);
stashMap1:addStamp("House", nil, 7689, 7612, 0, 0, 1);
stashMap1:addStamp(nil, "Academy Dorm", 7690, 7589, 0, 0, 1);
stashMap1:addStamp(nil, "Main", 7642, 7660, 0, 0, 1);
stashMap1:addStamp(nil, "Library", 7689, 7660, 0, 0, 1);
stashMap1:addStamp(nil, "Dorms", 7687, 7710, 0, 0, 1);
stashMap1:addStamp(nil, "Dorms", 7600, 7609, 0, 0, 1);
stashMap1:addStamp(nil, "Science", 7684, 7749, 0, 0, 1);
stashMap1:addStamp(nil, "Gym", 7638, 7750, 0, 0, 1);
stashMap1:addStamp(nil, "Workshop", 7594, 7694, 0, 0, 1);
stashMap1:addStamp("Tent", nil, 7675, 7661, 0, 0, 1);
stashMap1:addStamp("Heart", nil, 7676, 7479, 0, 0, 1);
stashMap1:addStamp(nil, "The Fair", 7651, 7452, 0, 0, 1);
stashMap1:addStamp(nil, "Shopping", 6769, 7358, 0, 0, 1);
stashMap1:addStamp(nil, "Industry", 7302, 7659, 0, 0, 1);



 
--Tremapmap4 - Area Stashmap
local stashMap1 = StashUtil.newStash("TrelaiStashMap4", "Map", "Trelai.trelaimap4", "Stash_AnnotedMap");
--stashMap1.spawnOnlyOnZed = true;
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 6781;
stashMap1.buildingY = 6810;
stashMap1.zombies = 10;
stashMap1.barricades = 15;
stashMap1.spawnTable = "ShotgunCache2";
stashMap1:addContainer("ShotgunBox",nil,"Base.Bag_DuffelBag",nil,"bedroom",nil,nil);
stashMap1:addContainer("ShotgunBox","carpentry_01_16",nil,nil,nil,nil,nil);
stashMap1:addStamp("Waves", nil, 6782, 6797, 0, 0, 1);
stashMap1:addStamp(nil, "House With Pool", 6794, 6789, 0, 0, 1);
stashMap1:addStamp("House", nil, 6784, 6807, 0, 0, 1);
stashMap1:addStamp("Gears", nil, 6704, 6826, 0, 0, 1);
stashMap1:addStamp(nil, "Fuel", 6663, 6844, 0, 0, 1);
stashMap1:addStamp("MedCross", nil, 6730, 6983, 0, 0, 1);
stashMap1:addStamp("Wrench", nil, 6777, 6911, 0, 0, 1);
stashMap1:addStamp("Wrench", nil, 6794, 6925, 0, 0, 1);
stashMap1:addStamp("Gun", nil, 6731, 6813, 0, 0, 1);
stashMap1:addStamp("Apple", nil, 6727, 6831, 0, 0, 1);
stashMap1:addStamp("Apple", nil, 6762, 6983, 0, 0, 1);
stashMap1:addStamp(nil, "VHS", 6776, 6977, 0, 0, 1);
stashMap1:addStamp("FaceHappy", nil, 6844, 6981, 0, 0, 1);
stashMap1:addStamp("Exclamation", nil, 6664, 6902, 1, 0, 0);
stashMap1:addStamp("Question", nil, 6817, 6876, 1, 0, 0);


 

-- tools -- evacd houses
local stashMap1 = StashUtil.newStash("TrelaiStashMap5", "Map", "Trelai.trelaimap", "Stash_AnnotedMap");
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 6811;
stashMap1.buildingY = 6670;
stashMap1.zombies = 25;
stashMap1.barricades = 25;
stashMap1.spawnTable = "ToolsCache1";
stashMap1:addStamp("Circle",nil,6811,6670,1,0,0);
stashMap1:addStamp("Exclamation",nil,6815,6660,0,0,0);
stashMap1:addStamp("Exclamation", nil, 11785, 6896, 0, 0, 0);
stashMap1:addStamp("FaceHappy", nil, 7660, 7668, 1, 0, 0);
stashMap1:addStamp("FaceHappy", nil, 7716, 7672, 1, 0, 0);
stashMap1:addStamp("FaceHappy", nil, 7701, 7711, 1, 0, 0);
stashMap1:addStamp("FaceHappy", nil, 7695, 7753, 1, 0, 0);
stashMap1:addStamp("FaceHappy", nil, 7684, 7623, 1, 0, 0);
stashMap1:addStamp("FaceHappy", nil, 7638, 7625, 1, 0, 0);
stashMap1:addStamp(nil, "T-Town Were Here", 7647, 7561, 0, 0, 1);
stashMap1:addStamp(nil, "Scholars", 7641, 7576, 0, 0, 1);
stashMap1:addStamp(nil, "Bigz Waz Here", 7581, 6703, 0, 0, 1);
stashMap1:addStamp(nil, "Truth Waz Here", 7584, 6723, 0, 0, 1);
stashMap1:addStamp(nil, "Straty Waz Here", 7593, 6744, 0, 0, 1);
stashMap1:addStamp(nil, "Special Thanks", 7597, 6786, 1, 0, 0);
stashMap1:addStamp(nil, "To All Residents", 7598, 6807, 1, 0, 0);
stashMap1:addStamp(nil, "Trelai_Credits", 7571, 6657, 1, 0, 0);
stashMap1:addStamp(nil, "Grand Avenue", 7087, 6747, 1, 0, 0);
stashMap1:addStamp(nil, "Cows Bridge Road", 6991, 6997, 1, 0, 0);
stashMap1:addStamp(nil, "Trelai Road", 6667, 7190, 1, 0, 0);
stashMap1:addStamp(nil, "Trelai Road", 6926, 7539, 1, 0, 0);
stashMap1:addStamp(nil, "Elderberry Road", 6680, 7711, 1, 0, 0);
stashMap1:addStamp(nil, "The Airport", 7619, 7298, 1, 0, 0);
stashMap1:addStamp(nil, "CrossRoads", 6856, 6823, 1, 0, 0);
stashMap1:addStamp(nil, "Country Lane", 6971, 7510, 1, 0, 0);
stashMap1:addStamp(nil, "Country Lane", 6980, 7036, 1, 0, 0);
stashMap1:addStamp(nil, "Seaview Avenue", 7610, 7471, 1, 0, 0);
stashMap1:addStamp(nil, "Trelai Drive", 7293, 7088, 1, 0, 0);
stashMap1:addStamp(nil, "Aqua road", 7288, 7184, 1, 0, 0);
stashMap1:addStamp(nil, "Discord Street", 7419, 6909, 1, 0, 0);
stashMap1:addStamp(nil, "Stadium", 6648, 7355, 1, 0, 0);
stashMap1:addStamp(nil, "Mall Centre", 6760, 7360, 1, 0, 0);
stashMap1:addStamp(nil, "Bank And Museum", 6644, 7416, 1, 0, 0);
stashMap1:addStamp(nil, "Gas", 6692, 7470, 1, 0, 0);
stashMap1:addStamp("Skull", nil, 6717, 7334, 1, 0, 0);
stashMap1:addStamp("Skull", nil, 6724, 7375, 1, 0, 0);
stashMap1:addStamp(nil, "Fairground", 7666, 7452, 0, 0, 1);
stashMap1:addStamp(nil, "Hell Road", 7109, 7452, 1, 0, 0);
stashMap1:addStamp(nil, "North Entrance", 6972, 6608, 1, 0, 0);
stashMap1:addStamp(nil, "West Entrance", 6612, 6759, 1, 0, 0);
stashMap1:addStamp(nil, "South Entrance", 7000, 7762, 1, 0, 0);
stashMap1:addStamp(nil, "South East Entrance", 7491, 7781, 1, 0, 0);
stashMap1:addStamp(nil, "East Entrance", 7716, 7114, 1, 0, 0);
stashMap1:addStamp(nil, "Yacht Club Was Here", 7553, 7131, 1, 0, 0);
stashMap1:addStamp("House", nil, 7610, 7161, 0, 0, 1);
stashMap1:addStamp("Fire", nil, 6685, 6847, 0, 0, 1);
stashMap1:addStamp("DollarSign", nil, 7152, 6798, 0, 0, 1);
stashMap1:addStamp(nil, "Grove Street", 6766, 6873, 1, 0, 0);
stashMap1:addStamp("FaceHappy", nil, 6776, 6861, 1, 0, 0);
stashMap1:addStamp(nil, "Dirk Road", 7146, 7558, 1, 0, 0);

local stashMap1 = StashUtil.newStash("TrelaiStory2", "Map", "Trelai.TrelaiStory2", "Stash_AnnotedMap");
stashMap1.daysToSpawn = "0";
stashMap1.spawnOnlyOnZed = true;
stashMap1.buildingX = 6975;
stashMap1.buildingY = 7514;
stashMap1.zombies = 55;
stashMap1.spawnTable = "GunCache1";
stashMap1:addContainer("GunBox",nil,"Base.Bag_DuffelBagTINT",nil,nil,nil,nil);
stashMap1:addStamp("Star", nil, 6975, 7514, 0, 0, 0);
stashMap1:addStamp("Star", nil, 6850, 6726, 0, 0, 0);
stashMap1:addStamp("Star", nil, 7151, 6801, 0, 0, 0);
stashMap1:addStamp("Star", nil, 6658, 6910, 0, 0, 0);
stashMap1:addStamp("Star", nil, 7660, 7669, 0, 0, 0);
stashMap1:addStamp("Star", nil, 7156, 7687, 0, 0, 0);
stashMap1:addStamp("Star", nil, 7769, 7164, 0, 0, 0);
stashMap1:addStamp("Star", nil, 6653, 7422, 0, 0, 0);
stashMap1:addStamp("Star", nil, 7562, 7204, 0, 0, 0);
stashMap1:addStamp("Star", nil, 7448, 6621, 0, 0, 0);
stashMap1:addStamp("Question", nil, 6669, 6910, 1, 0, 0);
stashMap1:addStamp("Question", nil, 7158, 6801, 1, 0, 0);
stashMap1:addStamp("Question", nil, 6856, 6725, 1, 0, 0);
stashMap1:addStamp("Question", nil, 7453, 6620, 1, 0, 0);
stashMap1:addStamp("Question", nil, 6663, 7422, 1, 0, 0);
stashMap1:addStamp("Question", nil, 7573, 7205, 1, 0, 0);
stashMap1:addStamp("Question", nil, 6985, 7513, 1, 0, 0);
stashMap1:addStamp("Question", nil, 7668, 7667, 1, 0, 0);
stashMap1:addStamp("Question", nil, 7779, 7164, 1, 0, 0);
stashMap1:addStamp(nil, "Story Locations", 7568, 6695, 0, 0, 0);
stashMap1:addStamp("Question", nil, 7163, 7685, 1, 0, 0);

-- Farm house   DragonBalls
local stashMap1 = StashUtil.newStash("TrelaiStashMap7", "Map", "Trelai.dragonballmap", "Stash_AnnotedMap");
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 6912;
stashMap1.buildingY = 7183;
stashMap1.zombies = 25;
stashMap1.barricades = 25;
stashMap1.spawnTable = "SurvivorCache1";
stashMap1:addContainer("ToolsBox",nil,"Base.Bag_DuffelBag",nil,nil,nil,nil);
stashMap1:addContainer("ToolsBox","carpentry_01_16",nil,nil,nil,nil,nil);
stashMap1:addContainer("GunBox","carpentry_01_16",nil,nil,nil,nil,nil);
stashMap1:addContainer("ShotgunBox",nil,"Base.Bag_DuffelBag",nil,nil,nil,nil);
stashMap1:addStamp("House",nil,6912,7184,0,0,0);
stashMap1:addStamp(nil, "Farm House", 6920, 7170, 0, 0, 1);
stashMap1:addStamp("house", nil, 6912, 7184, 0, 0, 0);
stashMap1:addStamp(nil, "Farm House", 6920, 7170, 0, 0, 1);
stashMap1:addStamp("Target", nil, 6940, 7227, 0, 0, 0);
stashMap1:addStamp("Target", nil, 6805, 7382, 0, 0, 0);
stashMap1:addStamp("Target", nil, 6657, 6906, 0, 0, 0);
stashMap1:addStamp("Target", nil, 7658, 7663, 0, 0, 0);
stashMap1:addStamp("Target", nil, 7340, 7331, 0, 0, 0);
stashMap1:addStamp("Target", nil, 6635, 7732, 0, 0, 0);
stashMap1:addStamp("Target", nil, 7259, 6781, 0, 0, 0);
stashMap1:addStamp("Target", nil, 7578, 6673, 0, 0, 0);
stashMap1:addStamp(nil, "Strange Orbs", 7597, 6664, 0, 0, 0);
stashMap1:addStamp(nil, "Bowling Alley", 6762, 7324, 0, 0, 1);
stashMap1:addStamp(nil, "School Roof", 7326, 7306, 0, 0, 1);
stashMap1:addStamp(nil, "Uni Roof", 7630, 7640, 0, 0, 1);
stashMap1:addStamp(nil, "Creepy House", 6609, 7640, 0, 0, 1);
stashMap1:addStamp(nil, "Residential House", 7239, 6756, 0, 0, 1);
stashMap1:addStamp(nil, "Mayors House", 6652, 6880, 0, 0, 1);
stashMap1:addStamp("FaceHappy", nil, 7684, 6676, 0, 0, 1);


-- peny rd survivor house 6
-- local stashMap1 = StashUtil.newStash("TrelaiStashMap6", "Map", "Base.trelaimap", "Stash_AnnotedMap");
-- stashMap1.daysToSpawn = "0";
-- stashMap1.buildingX = 7294;
-- stashMap1.buildingY = 6827;
-- stashMap1.zombies = 25;
-- stashMap1.barricades = 25;
-- stashMap1.spawnTable = "ToolsCache1";
-- stashMap1:addContainer("ToolsBox",nil,"Base.Bag_DuffelBag",nil,nil,nil,nil);
-- stashMap1:addContainer("ToolsBox","carpentry_01_16",nil,nil,nil,nil,nil);
-- stashMap1:addStamp("map_exclamation.png",nil,7294,6827,0,0,0);
-- stashMap1:addStamp("Circle", nil, 7294, 6827, 0, 0, 0)
 

-- peny rd survivor house 7
-- local stashMap1 = StashUtil.newStash("TrelaiStashMap7", "Map", "Base.trelaimap", "Stash_AnnotedMap");
-- stashMap1.daysToSpawn = "0";
-- stashMap1.buildingX = 7297;
-- stashMap1.buildingY = 6859;
-- stashMap1.zombies = 25;
-- stashMap1.barricades = 25;
-- stashMap1.spawnTable = "SurvivorCache1";
-- stashMap1:addContainer("GunBox","carpentry_01_16",nil,nil,nil,nil,nil);
-- stashMap1:addContainer("ShotgunBox",nil,"Base.Bag_DuffelBag",nil,nil,nil,nil);
-- stashMap1:addStamp("map_house.png",nil,7294,6827,0,0,0);
-- stashMap1:addStamp("map_arrowsouth.png",nil,2300,6840,0,0,0);