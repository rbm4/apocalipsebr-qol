local SQ        = require('TYL_SQUARE_CHECK/TYL_SQUARE_CHECK')

local random_instance = newrandom()

local road = {'blends_street_01_0',
              'blends_street_01_5',
              'blends_street_01_16',
              'blends_street_01_21',
              'blends_street_01_32',
              'blends_street_01_37',
              'blends_street_01_38',
              'blends_street_01_39',
              'blends_street_01_48',
              'blends_street_01_53',
              'blends_street_01_54',
              'blends_street_01_55',
              'blends_street_01_64',
              'blends_street_01_69',
              'blends_street_01_70',
              'blends_street_01_71',
              'blends_street_01_80',
              'blends_street_01_85',
              'blends_street_01_86',
              'blends_street_01_87',
              'blends_street_01_96',
              'blends_street_01_101',
              'blends_street_01_102',
              'blends_street_01_103',
              'floors_exterior_tilesandstone_01_3',
              'floors_exterior_tilesandstone_01_4',
              'floors_exterior_tilesandstone_01_5',
              'floors_exterior_tilesandstone_01_6',
}

local natural = {
    'blends_natural_01_16',
    'blends_natural_01_21',
    'blends_natural_01_22',
    'blends_natural_01_23',
    'blends_natural_01_32',
    'blends_natural_01_37',
    'blends_natural_01_38',
    'blends_natural_01_39',
    'blends_natural_01_48',
    'blends_natural_01_49',
    'blends_natural_01_53',
    'blends_natural_01_54',
    'blends_natural_01_55',
}

local roof_top = {'roofs_01_22','roofs_01_23','roofs_02_22','roofs_02_23','roofs_01_90','roofs_01_91','roofs_01_92','roofs_01_93','roofs_02_90','roofs_02_91','roofs_02_92','roofs_02_93','roofs_05_22','roofs_05_23','roofs_06_22','roofs_06_23','roofs_04_55','floors_exterior_street_01_16','floors_exterior_street_01_17','floors_exterior_street_01_0','floors_exterior_street_01_14','floors_exterior_tilesandstone_01_4','floors_interior_tilesandwood_01_16'}
local roof_destroy = {'roofs_burnt_01_22','roofs_03_22','roofs_03_23','roofs_04_22','roofs_04_23','carpentry_02_58'}

local trees = {
    "e_carolinasilverbell_1_0",
    "e_easternredbud_1_0",
    "e_americanlinden_1_0",
    "e_americanholly_1_1",
    "e_canadianhemlock_1_1",
    "e_riverbirch_1_0",
    "e_virginiapine_1_0",
    "e_redmaple_1_0",
    "e_cockspurhawthorn_1_0",
    "e_dogwood_1_0",
    "e_yellowwood_1_0",

    "e_americanhollyJUMBO_1_0",
    "e_americanlindenJUMBO_1_0",
    "e_canadianhemlockJUMBO_1_0",
    "e_carolinasilverbellJUMBO_1_0",
    "e_cockspurhawthornJUMBO_1_0",
    "e_dogwoodJUMBO_1_0",
    "e_easternredbudJUMBO_1_0",
    "e_redmapleJUMBO_1_0",
    "e_riverbirchJUMBO_1_0",
    "e_virginiapineJUMBO_1_0",
    "e_yellowwoodJUMBO_1_0",

    "e_americanhollyJUMBOXL_1_0",
    "e_americanlindenJUMBOXL_1_0",
    "e_canadianhemlockJUMBOXL_1_0",
    "e_carolinasilverbellJUMBOXL_1_0",
    "e_cockspurhawthornJUMBOXL_1_0",
    "e_dogwoodJUMBOXL_1_0",
    "e_easternredbudJUMBOXL_1_0",
    "e_redmapleJUMBOXL_1_0",
    "e_riverbirchJUMBOXL_1_0",
    "e_virginiapineJUMBOXL_1_0",
    "e_yellowwoodJUMBOXL_1_0",

    "e_americanhollyJUMBOXXL_1_0",
    "e_americanlindenJUMBOXXL_1_0",
    "e_canadianhemlockJUMBOXXL_1_0",
    "e_carolinasilverbellJUMBOXXL_1_0",
    "e_cockspurhawthornJUMBOXXL_1_0",
    "e_dogwoodJUMBOXXL_1_0",
    "e_easternredbudJUMBOXXL_1_0",
    "e_redmapleJUMBOXXL_1_0",
    "e_riverbirchJUMBOXXL_1_0",
    "e_virginiapineJUMBOXXL_1_0",
    "e_yellowwoodJUMBOXXL_1_0",
}

local wallList = {"WallNW","WallW","WallN","WindowN","WindowW","DoorWallW","DoorWallN"}
local vehicleList = {}
local vehicleDirList = {
    "N",
    "E",
    "S",
    "W",
    "NW",
    "NE",
    "SW",
    "SE"
}
local vehiculeSide = {"Front", "Rear", "Left", "Right"}
local grass = {
    "e_newgrass_1_34", 
    "e_newgrass_1_33", 
    "e_newgrass_1_24", 
    "e_newgrass_1_27", 
    "e_newgrass_1_28",
    "e_newgrass_1_29",
    "e_newgrass_1_53", 
    "e_newgrass_1_52", 
    "e_newgrass_1_51", 
    "e_newgrass_1_48",
    "e_newgrass_1_73",
    "e_newgrass_1_74",
    "e_newgrass_1_75"
}

local floorleaves = {
    "d_floorleaves_1_10",
    "d_floorleaves_1_5",
    "d_floorleaves_1_8",
    "d_floorleaves_1_7",
    "d_floorleaves_1_2",
    "d_floorleaves_1_9",
    "d_floorleaves_1_2",
    "d_floorleaves_1_4",
    "d_floorleaves_1_11",
    "d_floorleaves_1_6"
}

local custom_grass = {
    "d_plants_tyl_1_5",
    "d_plants_tyl_1_6",
    "d_plants_tyl_1_7",
    "d_plants_tyl_1_8",
    "d_plants_tyl_1_9",
    "d_plants_tyl_1_10",
    "d_plants_tyl_1_11",
    "d_plants_tyl_1_12",
    "d_plants_tyl_1_13",
    "d_plants_tyl_1_14",
    "d_plants_tyl_1_15",
    "d_plants_tyl_1_16",
    "d_plants_tyl_1_17",
    "d_plants_tyl_1_18",
    "d_plants_tyl_1_19",
    "d_plants_tyl_1_20",
    "d_plants_tyl_1_21",
    "d_plants_tyl_1_22",
    "d_plants_tyl_1_23",
    "d_plants_tyl_1_24",
    "d_plants_tyl_1_25",
    "d_plants_tyl_1_26",
    "d_plants_tyl_1_27",
    "d_plants_tyl_1_28",
    "d_plants_tyl_1_29",
    "d_plants_tyl_1_30",
    "d_plants_tyl_1_31",
    "d_plants_tyl_1_32",
    "d_plants_tyl_1_33",
    "d_plants_tyl_1_34",
    "d_plants_tyl_1_35",
    "d_plants_tyl_1_36",
    "d_plants_tyl_1_37",
    "d_plants_tyl_1_38",
    "d_plants_tyl_1_39",
    "d_plants_tyl_1_40",
    "d_plants_tyl_1_41",
    "d_plants_tyl_1_42",
    "d_plants_tyl_1_43",
    "d_plants_tyl_1_44",
    "d_plants_tyl_1_45",
    "d_plants_tyl_1_46",
    "d_plants_tyl_1_47",
    "d_plants_tyl_1_48",
    "d_plants_tyl_2_0",
    "d_plants_tyl_2_1",
    "d_plants_tyl_2_2",
    "d_plants_tyl_2_3",
    "d_plants_tyl_2_4",
    "d_plants_tyl_2_5",
    "d_plants_tyl_2_6",
    "d_plants_tyl_2_7",
    "d_plants_tyl_2_8",
    "d_plants_tyl_2_9",
    "d_plants_tyl_2_10",
    "d_plants_tyl_2_11",
    "d_plants_tyl_2_12",
    "d_plants_tyl_2_13",
    "d_plants_tyl_2_14",
    "d_plants_tyl_2_15",
    "d_plants_tyl_2_16",
    "d_plants_tyl_2_17",
    "d_plants_tyl_2_18",
    "d_plants_tyl_2_19",
    "d_plants_tyl_2_20",
    "d_plants_tyl_2_21",
    "d_plants_tyl_2_22",
    "d_plants_tyl_2_23",
    "d_plants_tyl_2_24",
    "d_plants_tyl_2_25",
    "d_plants_tyl_2_26",
    "d_plants_tyl_2_27",
    "d_plants_tyl_2_28",
    "d_plants_tyl_2_29",
    "d_plants_tyl_2_30",
    "d_plants_tyl_2_31",
    "d_plants_tyl_2_32",
    "d_plants_tyl_2_33",
    "d_plants_tyl_2_34",
    "d_plants_tyl_2_35",
    "d_plants_tyl_2_36",
    "d_plants_tyl_2_37",
    "d_plants_tyl_2_38",
    "d_plants_tyl_2_39",
    "d_plants_tyl_2_40",
    "d_plants_tyl_2_41",
    "d_plants_tyl_2_42",
    "d_plants_tyl_2_43",
    "d_plants_tyl_2_44",
    "d_plants_tyl_2_45",
    "d_plants_tyl_2_46",
    "d_plants_tyl_2_47",
    "d_plants_tyl_2_48"
}

local bushes = {
    "f_bushes_1_65",
    "f_bushes_1_66",
    "f_bushes_1_97",
    "f_bushes_1_98",
    "f_bushes_1_77",
    "f_bushes_1_78",
    "f_bushes_1_110",
    "f_bushes_1_109",
    "f_bushes_1_99",
    "f_bushes_1_67",
    "f_bushes_1_103",
    "f_bushes_1_71",
    "f_bushes_1_77",
    "f_bushes_1_78",
    "f_bushes_1_110",
    "f_bushes_1_109",
    "f_bushes_1_99",
    "f_bushes_1_67",
    "f_bushes_1_103",
    "f_bushes_1_71",
    "f_bushes_1_77",
    "f_bushes_1_78",
    "f_bushes_1_110",
    "f_bushes_1_109",
    "f_bushes_1_99",
    "f_bushes_1_67",
    "f_bushes_1_103",
    "f_bushes_1_71",
    "f_bushes_1_77",
    "f_bushes_1_78",
    "f_bushes_1_110",
    "f_bushes_1_109",
    "f_bushes_1_99",
    "f_bushes_1_67",
    "f_bushes_1_103",
    "f_bushes_1_71",
    "f_bushes_1_71",
    "f_bushes_1_67",
    "f_bushes_1_69",
    "f_bushes_1_70",
    "f_bushes_1_72",
    "f_bushes_1_73",
    "f_bushes_1_75",
    "f_bushes_1_76",
    "f_bushes_1_79",
    "f_bushes_1_99",
    "f_bushes_1_101",
    "f_bushes_1_102",
    "f_bushes_1_104",
    "f_bushes_1_105",
    "f_bushes_1_107",
    "f_bushes_1_108",
    "f_bushes_1_111",
    "f_bushes_1_64",
    "f_bushes_1_96",
    "f_bushes_1_100",
    "f_bushes_1_68",
    "f_bushes_1_106",
    "f_bushes_1_99",
    "f_bushes_1_67",
    "f_bushes_1_103",
    "f_bushes_1_71",
    "f_bushes_1_100",
    "f_bushes_1_68",
    "f_bushes_1_106",
    "f_bushes_1_99",
    "f_bushes_1_67",
    "f_bushes_1_103",
    "f_bushes_1_71",
    "f_bushes_1_100",
    "f_bushes_1_68",
    "f_bushes_1_106",
    "f_bushes_1_99",
    "f_bushes_1_67",
    "f_bushes_1_103",
    "f_bushes_1_71",
    "f_bushes_1_100",
    "f_bushes_1_68",
    "f_bushes_1_106",
    "f_bushes_1_99",
    "f_bushes_1_67",
    "f_bushes_1_103",
    "f_bushes_1_71",
    "f_bushes_1_74"
}

local customName = {}
customName['d_floorleaves_1_0'] = "Leaves"
customName['d_floorleaves_1_1'] = "Leaves"
customName['d_floorleaves_1_2'] = "Leaves"
customName['d_floorleaves_1_3'] = "Leaves"
customName['d_floorleaves_1_4'] = "Leaves"
customName['d_floorleaves_1_5'] = "Leaves"
customName['d_floorleaves_1_6'] = "Leaves"
customName['d_floorleaves_1_7'] = "Leaves"
customName['d_floorleaves_1_8'] = "Leaves"
customName['d_floorleaves_1_9'] = "Leaves"
customName['d_floorleaves_1_10'] = "Leaves"
customName['d_floorleaves_1_11'] = "Leaves"
customName['d_generic_1_8'] = "Twigs"
customName['d_generic_1_9'] = "Small Stump"
customName['d_generic_1_10'] = "Small Stump"
customName['d_generic_1_11'] = "Twigs"
customName['d_generic_1_12'] = "TreeBranch2"
customName['d_generic_1_13'] = "StoneTwigs"
customName['d_generic_1_14'] = "Twigs"
customName['d_generic_1_15'] = "Twigs"
customName['d_generic_1_22'] = "LargeStone"
customName['d_generic_1_23'] = "FlatStone"
customName['d_generic_1_24'] = "4Stones"
customName['d_generic_1_25'] = "4Stones"
customName['d_generic_1_28'] = "Small Stump"
customName['d_generic_1_31'] = "Log"
customName['d_generic_1_40'] = "4Stones"
customName['d_generic_1_41'] = "Stone2"
customName['d_generic_1_42'] = "Stone2"
customName['d_generic_1_43'] = "4Stones"
customName['d_generic_1_44'] = "Twigs"
customName['d_generic_1_45'] = "Twigs"
customName['e_newgrass_1_0'] = "Hedge"
customName['e_newgrass_1_1'] = "Hedge"
customName['e_newgrass_1_2'] = "Hedge"
customName['e_newgrass_1_3'] = "Hedge"
customName['e_newgrass_1_4'] = "Hedge"
customName['e_newgrass_1_5'] = "Hedge"
customName['e_newgrass_1_24'] = "Hedge"
customName['e_newgrass_1_25'] = "Hedge"
customName['e_newgrass_1_26'] = "Hedge"
customName['e_newgrass_1_27'] = "Hedge"
customName['e_newgrass_1_28'] = "Hedge"
customName['e_newgrass_1_29'] = "Hedge"
customName['e_newgrass_1_48'] = "Hedge"
customName['e_newgrass_1_49'] = "Hedge"
customName['e_newgrass_1_50'] = "Hedge"
customName['e_newgrass_1_51'] = "Hedge"
customName['e_newgrass_1_52'] = "Hedge"
customName['e_newgrass_1_53'] = "Hedge"
customName['e_newgrass_1_72'] = "Hedge"
customName['e_newgrass_1_73'] = "Hedge"
customName['e_newgrass_1_74'] = "Hedge"
customName['e_newgrass_1_75'] = "Hedge"
customName['e_newgrass_1_76'] = "Hedge"
customName['e_newgrass_1_77'] = "Hedge"
customName['e_newgrass_1_96'] = "Hedge"
customName['e_newgrass_1_97'] = "Hedge"
customName['e_newgrass_1_98'] = "Hedge"
customName['e_newgrass_1_99'] = "Hedge"
customName['e_newgrass_1_100'] = "Hedge"
customName['e_newgrass_1_101'] = "Hedge"
customName['f_bushes_1_8'] = "Hedge"
customName['f_bushes_1_9'] = "Hedge"
customName['f_bushes_1_10'] = "Hedge"
customName['f_bushes_1_11'] = "Hedge"
customName['f_bushes_1_12'] = "Hedge"
customName['f_bushes_1_13'] = "Hedge"
customName['f_bushes_1_14'] = "Hedge"
customName['f_bushes_1_15'] = "Hedge"
customName['f_bushes_1_24'] = "Hedge"
customName['f_bushes_1_25'] = "Hedge"
customName['f_bushes_1_26'] = "Hedge"
customName['f_bushes_1_27'] = "Hedge"
customName['f_bushes_1_28'] = "Hedge"
customName['f_bushes_1_29'] = "Hedge"
customName['f_bushes_1_30'] = "Hedge"
customName['f_bushes_1_31'] = "Hedge"
customName['f_bushes_1_96'] = "Hedge"
customName['f_bushes_1_97'] = "Hedge"
customName['f_bushes_1_98'] = "Hedge"
customName['f_bushes_1_99'] = "Hedge"
customName['f_bushes_1_100'] = "Hedge"
customName['f_bushes_1_101'] = "Hedge"
customName['f_bushes_1_102'] = "Hedge"
customName['f_bushes_1_103'] = "Hedge"
customName['f_bushes_1_104'] = "Hedge"
customName['f_bushes_1_105'] = "Hedge"
customName['f_bushes_1_106'] = "Hedge"
customName['f_bushes_1_107'] = "Hedge"
customName['f_bushes_1_108'] = "Hedge"
customName['f_bushes_1_109'] = "Hedge"
customName['f_bushes_1_110'] = "Hedge"
customName['f_bushes_1_111'] = "Hedge"
customName['f_bushes_2_0'] = "Hedge"
customName['f_bushes_2_1'] = "Hedge"
customName['f_bushes_2_2'] = "Hedge"
customName['f_bushes_2_3'] = "Hedge"
customName['f_bushes_2_4'] = "Hedge"
customName['f_bushes_2_5'] = "Hedge"
customName['f_bushes_2_6'] = "Hedge"
customName['f_bushes_2_7'] = "Hedge"
customName['f_bushes_2_8'] = "Ornamental Bush"
customName['f_bushes_2_9'] = "Ornamental Bush"
customName['f_bushes_2_10'] = "Hedge"
customName['f_bushes_2_11'] = "Hedge"
customName['f_bushes_2_12'] = "Hedge"
customName['f_bushes_2_13'] = "Hedge"
customName['f_bushes_2_14'] = "Hedge"
customName['f_bushes_2_15'] = "Hedge"
customName['f_bushes_2_16'] = "Hedge"
customName['f_bushes_2_17'] = "Hedge"
customName['f_bushes_2_18'] = "Ornamental Bush"
customName['f_bushes_2_19'] = "Ornamental Bush"



local stories = {14,13,4,19,38,28,32,27,29,16}
local fenceDestroyed = {"fencing_damaged_01_128","fencing_damaged_01_129","fencing_damaged_01_130","fencing_damaged_01_131","fencing_damaged_01_136","fencing_damaged_01_137","fencing_damaged_01_138","fencing_damaged_01_139"}
local animals = {9,26,28,25,23,22,20,21,15,11,12,8,27,6,5,0}


local wallW     = {"f_wallvines_1_43","f_wallvines_1_42","f_wallvines_1_37","f_wallvines_1_36","f_wallvines_1_31","f_wallvines_1_30","f_wallvines_1_25","f_wallvines_1_24"}
local wallW_top = {"f_wallvines_1_37","f_wallvines_1_36","f_wallvines_1_31","f_wallvines_1_30","f_wallvines_1_25","f_wallvines_1_24"}
local wallW_low = {"f_wallvines_1_25","f_wallvines_1_24"}
local wallN     = {"f_wallvines_1_45","f_wallvines_1_44","f_wallvines_1_39","f_wallvines_1_38","f_wallvines_1_33","f_wallvines_1_32","f_wallvines_1_27","f_wallvines_1_26"}
local wallN_top = {"f_wallvines_1_39","f_wallvines_1_38","f_wallvines_1_33","f_wallvines_1_32","f_wallvines_1_27","f_wallvines_1_26"}
local wallN_low = {"f_wallvines_1_27","f_wallvines_1_26"}
local wallNW    = {"f_wallvines_1_47","f_wallvines_1_46","f_wallvines_1_41","f_wallvines_1_40","f_wallvines_1_34","f_wallvines_1_35","f_wallvines_1_29","f_wallvines_1_28"}
local wallNW_top = {"f_wallvines_1_41","f_wallvines_1_40","f_wallvines_1_34","f_wallvines_1_35","f_wallvines_1_29","f_wallvines_1_28"}
local wallNW_low = {"f_wallvines_1_29","f_wallvines_1_28"}
local tiles_indoor_tiles = {"floors_interior_carpet_01_4","fixtures_stairs_01_72","fixtures_stairs_01_73","fixtures_stairs_01_74","location_restaurant_spiffos_01_38","location_restaurant_pizzawhirled_01_16","location_shop_mall_01_38","location_shop_mall_01_35","location_shop_mall_01_34","floors_interior_tilesandwood_01_46","location_shop_mall_01_22","floors_rugs_01_21","floors_rugs_01_20","floors_rugs_01_17","floors_rugs_01_23","floors_rugs_01_22","floors_rugs_01_16","camping_01_24", "camping_01_25", "camping_01_38","camping_01_39", "carpentry_02_12", "carpentry_02_13","carpentry_02_14", "carpentry_02_62", "construction_01_4","construction_01_5", "floors_burnt_01_0", "floors_burnt_01_1", "floors_exterior_natural_01_12", "floors_exterior_street_01_16", "floors_exterior_street_01_17", "floors_exterior_tilesandstone_01_2", "floors_exterior_tilesandstone_01_3", "floors_exterior_tilesandstone_01_5", "floors_exterior_tilesandstone_01_7", "floors_interior_carpet_01_10", "floors_interior_carpet_01_11", "floors_interior_carpet_01_12", "floors_interior_carpet_01_13", "floors_interior_carpet_01_2", "floors_interior_carpet_01_3", "floors_interior_carpet_01_5","floors_interior_carpet_01_6", "floors_interior_carpet_01_9", "floors_interior_tilesandwood_01_11", "floors_interior_tilesandwood_01_12", "floors_interior_tilesandwood_01_16", "floors_interior_tilesandwood_01_17", "floors_interior_tilesandwood_01_18", "floors_interior_tilesandwood_01_3", "floors_interior_tilesandwood_01_41", "floors_interior_tilesandwood_01_42", "floors_interior_tilesandwood_01_43", "floors_interior_tilesandwood_01_44", "floors_interior_tilesandwood_01_45", "floors_interior_tilesandwood_01_49", "floors_interior_tilesandwood_01_5", "floors_interior_tilesandwood_01_51", "floors_interior_tilesandwood_01_52", "floors_interior_tilesandwood_01_6", "floors_interior_tilesandwood_01_8", "floors_rugs_01_24", "floors_rugs_01_25", "floors_rugs_01_32", "floors_rugs_01_33","floors_rugs_01_40", "floors_rugs_01_41", "furniture_seating_indoor_02_60", "furniture_seating_indoor_02_61", "furniture_seating_indoor_02_62", "furniture_seating_indoor_02_63", "location_shop_zippee_01_7"}
local tiles_wallW = {"walls_exterior_house_02_88","walls_exterior_house_02_80","location_restaurant_spiffos_01_5","walls_exterior_house_02_0","walls_exterior_house_02_10","location_restaurant_spiffos_01_6","location_restaurant_spiffos_01_4","location_restaurant_spiffos_01_0","location_restaurant_pizzawhirled_01_0","walls_exterior_house_02_52","walls_interior_house_02_8","walls_interior_house_02_0","walls_interior_house_01_32","walls_interior_house_01_0","walls_interior_house_01_10","walls_interior_house_04_0","walls_interior_house_04_76","walls_interior_house_04_68","walls_interior_house_04_52","industry_railroad_05_8","walls_interior_house_02_58","walls_interior_house_03_16","walls_interior_house_01_30","walls_interior_house_01_28","walls_interior_house_01_20","walls_interior_house_01_16","fencing_01_67","fencing_01_66","walls_exterior_house_02_72","walls_exterior_house_02_24","location_community_church_small_01_8","walls_commercial_03_32","walls_commercial_01_40","walls_garage_01_32","walls_exterior_house_02_56","walls_exterior_house_02_48","location_community_church_small_01_0","location_restaurant_spiffos_01_46","location_restaurant_spiffos_01_40","location_restaurant_spiffos_01_8","location_restaurant_spiffos_01_10","location_restaurant_spiffos_01_8","walls_burnt_01_8","walls_garage_01_32","location_trailer_01_32","location_trailer_01_34","location_trailer_01_37","location_trailer_01_36","location_trailer_01_24","location_trailer_01_10","location_trailer_01_8","location_trailer_01_0","location_shop_bargNclothes_01_24","walls_interior_house_03_10","walls_interior_house_02_16","walls_burnt_01_14","walls_burnt_01_0","walls_burnt_01_4","walls_exterior_house_02_20","walls_interior_house_04_26","walls_interior_house_04_24","walls_interior_house_04_16","walls_interior_house_02_36","walls_interior_house_01_52","walls_interior_house_01_60","walls_interior_house_01_48","walls_exterior_wooden_01_32","walls_exterior_wooden_01_34","walls_exterior_wooden_01_24","walls_interior_house_04_4","walls_interior_house_02_36","walls_interior_house_02_20","walls_exterior_house_01_12","walls_exterior_house_01_4","walls_exterior_house_01_56","walls_exterior_house_01_58","walls_exterior_house_01_58","walls_exterior_house_01_56","walls_exterior_house_01_48","walls_exterior_house_01_56","location_trailer_01_10","location_trailer_01_0","location_trailer_01_8","walls_exterior_wooden_01_28","walls_commercial_01_32","walls_commercial_03_0","walls_garage_01_36", "walls_commercial_03_16", "walls_interior_house_03_42", "walls_interior_house_04_64", "walls_interior_house_04_72", "walls_exterior_wooden_01_24", "walls_interior_house_04_78", "walls_interior_house_04_70", "fencing_01_59", "fencing_01_58", "walls_interior_house_04_50", "walls_interior_house_04_58", "walls_exterior_house_02_40", "walls_exterior_house_02_32", "walls_garage_01_16", "walls_exterior_house_01_40", "walls_exterior_house_01_32", "walls_interior_house_02_56", "walls_interior_house_01_36", "walls_interior_house_03_0", "walls_interior_house_03_8", "walls_interior_house_04_20", "walls_interior_house_03_0", "walls_interior_house_04_84", "walls_exterior_house_01_60", "walls_exterior_house_01_52", "walls_interior_house_04_32", "walls_interior_house_03_28", "walls_interior_house_03_20", "walls_interior_house_03_40", "walls_interior_house_03_32", "walls_interior_house_02_48", "walls_commercial_01_48", "walls_exterior_house_01_24", "walls_exterior_house_02_64", "walls_exterior_house_02_16", "walls_commercial_01_112", "walls_exterior_house_01_16", "walls_exterior_house_01_16", "location_community_church_small_01_4", "walls_interior_house_04_80", "walls_exterior_house_02_36", "walls_exterior_house_02_44","fencing_damaged_01_85","fencing_damaged_01_91","carpentry_02_100","carpentry_02_80","carpentry_02_82","location_military_tent_01_0","location_military_tent_01_8"}
local tiles_wallN = {"walls_exterior_house_02_89","walls_exterior_house_02_81","location_restaurant_spiffos_01_16","walls_exterior_house_02_1","location_restaurant_spiffos_01_19","location_restaurant_spiffos_01_18","walls_exterior_house_02_61","walls_exterior_house_02_53","location_restaurant_spiffos_01_17","location_restaurant_spiffos_01_1","location_restaurant_pizzawhirled_01_1","location_community_school_01_11","location_community_school_01_1","fencing_01_89","fencing_01_90","location_community_school_01_1","walls_interior_house_02_1","walls_interior_house_02_11","walls_interior_house_01_41","walls_interior_house_01_33","walls_interior_house_04_1","walls_interior_house_01_25","walls_interior_house_01_17","walls_interior_house_04_53","walls_interior_house_01_47","walls_interior_house_03_27","walls_interior_house_02_59","walls_interior_house_02_53","walls_interior_house_02_57","walls_interior_house_03_17","walls_interior_house_03_1","walls_interior_house_01_57","walls_interior_house_01_21","walls_interior_house_01_29","walls_burnt_01_5","walls_burnt_01_1","walls_burnt_01_13","walls_burnt_01_9","fencing_01_64","fencing_01_65","walls_commercial_03_25","fixtures_doors_frames_01_30","walls_exterior_house_02_73","walls_exterior_house_02_65","location_community_church_small_01_9","fencing_01_57","fencing_01_56","location_community_church_small_01_1","walls_commercial_03_49","walls_commercial_03_33","walls_garage_01_33","walls_exterior_house_02_57","walls_exterior_house_02_49","walls_commercial_01_45","walls_commercial_03_49","walls_commercial_01_41","walls_commercial_01_113","location_community_church_small_01_2","walls_commercial_01_49","location_restaurant_spiffos_01_47","location_restaurant_spiffos_01_41","location_restaurant_spiffos_01_9","walls_burnt_01_15","walls_burnt_01_13","walls_garage_01_33","location_trailer_01_38","location_trailer_01_39","location_trailer_01_25","location_trailer_01_35","location_trailer_01_1","location_trailer_01_15","location_trailer_01_14","location_shop_bargNclothes_01_35","location_shop_bargNclothes_01_25","walls_interior_house_03_9","walls_interior_house_03_11","walls_interior_house_02_27","walls_interior_house_02_17","walls_exterior_house_01_17","walls_exterior_house_01_25","walls_burnt_01_5","walls_burnt_01_9","walls_burnt_01_1","walls_exterior_house_02_21","walls_exterior_house_02_29","walls_exterior_house_02_21","walls_interior_house_04_17","walls_interior_house_04_25","walls_interior_house_04_27","walls_exterior_wooden_01_38","walls_exterior_wooden_01_28","walls_exterior_wooden_01_37","walls_exterior_wooden_01_29","walls_interior_house_02_37","walls_interior_house_01_53","walls_interior_house_01_49","walls_exterior_wooden_01_25","walls_interior_house_04_5","walls_interior_house_02_37","walls_interior_house_02_21","walls_exterior_house_01_15","walls_exterior_house_01_13","walls_exterior_house_01_5","fencing_01_8","fencing_01_9","walls_exterior_house_01_49","walls_exterior_house_01_59","walls_exterior_house_01_57","location_trailer_01_11","location_trailer_01_1","location_trailer_01_9","walls_exterior_wooden_01_29","carpentry_02_101","location_military_tent_01_0","carpentry_02_81","walls_commercial_03_1","fencing_01_10", "fencing_01_11", "walls_interior_house_04_66", "walls_exterior_wooden_01_33", "walls_interior_house_04_49", "walls_interior_house_04_49", "walls_interior_house_04_5 ", "walls_exterior_house_01_41", "walls_exterior_house_01_41", "walls_exterior_house_01_33", "walls_interior_house_04_93", "walls_exterior_house_01_53", "walls_exterior_house_01_61", "walls_exterior_house_01_17", "walls_exterior_house_02_17", "walls_exterior_house_02_25", "walls_interior_house_03_21", "walls_interior_house_02_49", "walls_interior_house_03_33", "walls_interior_house_03_33", "walls_commercial_01_49 cha", "walls_interior_house_04_33", "location_community_church_small_01_5", "walls_interior_house_04_81", "walls_exterior_house_02_37", "walls_exterior_house_02_45", "walls_interior_house_03_1 ", "walls_interior_house_04_21", "walls_interior_house_03_1 ", "walls_interior_house_04_41", "walls_interior_house_01_45", "walls_interior_house_01_37", "walls_interior_house_04_85", "walls_exterior_house_02_33", "walls_exterior_house_02_33", "walls_exterior_house_02_41", "fencing_01_56 chance = 1, ", "fencing_01_57 chance = 1, ", "walls_interior_house_03_41", "walls_interior_house_03_29", "walls_interior_house_04_69", "walls_interior_house_04_79", "walls_commercial_03_17", "walls_commercial_03_27", "walls_garage_01_37", "walls_commercial_01_42", "walls_commercial_01_0", "walls_commercial_01_16"}
local tiles_angle = {"walls_exterior_house_02_2","location_restaurant_spiffos_01_15","location_restaurant_pizzawhirled_01_2","location_community_school_01_2","walls_interior_house_01_22","walls_interior_house_01_34","walls_interior_house_04_54","walls_interior_house_04_2","walls_interior_house_04_49","walls_exterior_house_01_50","walls_interior_house_02_54","walls_interior_house_03_18","walls_commercial_03_18","walls_exterior_house_02_34","walls_commercial_03_34","walls_exterior_house_02_66","walls_commercial_01_97","walls_exterior_house_02_18","walls_exterior_house_02_38","location_restaurant_spiffos_01_42","walls_garage_01_34","walls_exterior_wooden_01_26","location_trailer_01_26","walls_interior_house_02_18","walls_exterior_house_01_18","walls_burnt_01_6","walls_exterior_house_02_22","walls_interior_house_04_18","walls_interior_house_02_38","walls_interior_house_01_54","walls_interior_house_01_50","walls_interior_house_04_6","walls_interior_house_02_38","walls_interior_house_02_28","walls_exterior_house_01_6","fencing_01_12","walls_exterior_wooden_01_30","walls_commercial_03_2","walls_garage_01_38", "walls_exterior_house_01_34", "walls_interior_house_01_38", "walls_interior_house_03_22", "walls_interior_house_04_86", "walls_interior_house_02_50", "walls_interior_house_03_34", "walls_interior_house_02_50", "walls_commercial_01_50", "walls_interior_house_04_34", "location_community_church_small_01_6", "walls_interior_house_04_82", "walls_interior_house_03_2"}

local function TYL_RemoveVinesFromBrokenFence(square)
    if not square then
        return
    end

    local objects = square:getObjects()

    if not objects then
        return
    end

    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)

        if obj then
            local spriteName = obj:getSpriteName()

            if spriteName and luautils.stringStarts(tostring(spriteName), "f_wallvines_") then
                square:transmitRemoveItemFromSquare(obj)
                square:RemoveTileObject(obj)
            end
        end
    end
end

local function LoadGridsquare(square)

    local sandbox = getSandboxOptions()

    local treePercentageOnRoad              = sandbox:getOptionByName('TYL.treePercentageOnRoad'):getValue() or 0
    local bushesPercentageOnRoad            = sandbox:getOptionByName('TYL.bushesPercentageOnRoad'):getValue() or 1
    local grassPercentageOnRoad             = sandbox:getOptionByName('TYL.grassPercentageOnRoad'):getValue() or 50
    local floorleavesPercentageOnRoad       = sandbox:getOptionByName('TYL.floorleavesPercentageOnRoad'):getValue() or 10
    local customGrassPercentageOnRoad       = sandbox:getOptionByName('TYL.customGrassPercentageOnRoad'):getValue() or 0

    local vinePercentage                    = sandbox:getOptionByName('TYL.vinePercentage'):getValue() or 80
    local bushesPercentage                  = sandbox:getOptionByName('TYL.bushesPercentage'):getValue() or 10
    local grassPercentage                   = sandbox:getOptionByName('TYL.grassPercentage'):getValue() or 50
    local floorleavesPercentage             = sandbox:getOptionByName('TYL.floorleavesPercentage'):getValue() or 10
    local customGrassPercentage             = sandbox:getOptionByName('TYL.customGrassPercentage'):getValue() or 0

    local treePercentage                    = sandbox:getOptionByName('TYL.treePercentage'):getValue() or 1
    local wallPercentage                    = sandbox:getOptionByName('TYL.wallPercentage'):getValue() or 0
    local barricadePercentage               = sandbox:getOptionByName('TYL.barricadePercentage'):getValue() or 60
    local trashPercentage                   = sandbox:getOptionByName('TYL.trashPercentage'):getValue() or 10
    local trashPercentageInterior           = sandbox:getOptionByName('TYL.trashPercentageInterior'):getValue() or 25
    local roofPercentage                    = sandbox:getOptionByName('TYL.roofPercentage'):getValue() or 0
    local vehiclePercentage                 = sandbox:getOptionByName('TYL.vehiclePercentage'):getValue() or 1
    local storiesPercentage                 = sandbox:getOptionByName('TYL.storiesPercentage'):getValue() or 1
    local fencePercentage                   = sandbox:getOptionByName('TYL.fencePercentage'):getValue() or 50
    local animalsPercentage                 = sandbox:getOptionByName('TYL.animalsPercentage'):getValue() or 5
    local dirtCrackOverlayPercentage        = sandbox:getOptionByName('TYL.dirtCrackOverlayPercentage'):getValue() or 25
    local roadCrackOverlayPercentage        = sandbox:getOptionByName('TYL.roadCrackOverlayPercentage'):getValue() or 25

    if square and not square:getModData()["TYLVEG"] then

        if square:getZ() == 0 then

            if SQ.checkRoad(square) then

                if vehiclePercentage >= random_instance:random(1, 1001) then

                    if random_instance:random(1,5) == 2 then

                        local vehicle = addVehicleDebug(
                                tostring(vehicleList[random_instance:random(1, #vehicleList + 1)]),
                                IsoDirections[vehicleDirList[random_instance:random(#vehicleDirList) + 1]]

                        ,
                                nil, square
                        )
                        vehicle:setRust(1.0)

                        for i = 1, #vehiculeSide do
                            local v = vehiculeSide[i]
                            vehicle:setBloodIntensity(v, random_instance:random(0.0,1.0))
                        end

                    end

                end

            end

            if animalsPercentage >= random_instance:random(1, 500) then

                if random_instance:random(0,100) == 1 then

                    local rzs = animals[ZombRand(1, #animals + 1)]

                    local animal = addAnimal(getCell(),
                            square:getX(),
                            square:getY(),
                            square:getZ(),
                            getAllAnimalsDefinitions():get(rzs):getAnimalType(),
                            getAllAnimalsDefinitions():get(rzs):getRandomBreed(),
                            false)
                    animal:addToWorld()


                end

            end

        end

        if SQ.checkSquare(square) and square:isSolidFloor() and square:getZ() == 0 then

            if SQ.checkRoad(square) then

                if treePercentageOnRoad >= random_instance:random(1, 101) then
                    local randomTree = trees[ZombRand(1, #trees + 1)]
                    local newTree = IsoTree.new(square, getSprite(randomTree))
                    square:AddSpecialObject(newTree)
                    newTree:setAttachedAnimSprite(ArrayList.new())

                    local treeSpriteName = newTree:getSprite():getName()

                    local foliageIndex = tostring(random_instance:random(4, 16))
                    local foliageSpriteName = ""

                    if foliageIndex ~= "4" and foliageIndex ~= "5" and foliageIndex ~= "6" and foliageIndex ~= "7" then

                        foliageSpriteName = treeSpriteName:gsub("_(%d+)$", "_" .. foliageIndex)

                        local foliageSprite = getSprite(foliageSpriteName)
                        if foliageSprite then
                            newTree:getAttachedAnimSprite():add(foliageSprite:newInstance())
                        end
                    end

                    newTree:transmitCompleteItemToClients()
                    newTree:transmitModData()
                end

                if bushesPercentageOnRoad >= random_instance:random(1, 101) then
                    local currentFloorTile = square:getFloor() and square:getFloor():getSprite():getName()
                    if currentFloorTile ~= nil then
                        local randomBushes = bushes[ZombRand(1, #bushes + 1)]
                        local obj = IsoObject.new(getCell(), square, randomBushes)
                        square:AddSpecialObject(obj)
                        obj:transmitCompleteItemToClients()
                        obj:transmitModData()
                    end
                end

                if grassPercentageOnRoad >= random_instance:random(1, 101) then
                    local currentFloorTile = square:getFloor() and square:getFloor():getSprite():getName()
                    if currentFloorTile ~= nil then
                        local randomGrass = grass[ZombRand(1, #grass + 1)]
                        local obj = IsoObject.new(getCell(), square, randomGrass)
                        square:AddSpecialObject(obj)
                        obj:transmitCompleteItemToClients()
                        obj:transmitModData()
                    end
                end

                if floorleavesPercentageOnRoad >= random_instance:random(1, 101) then
                    local currentFloorTile = square:getFloor() and square:getFloor():getSprite():getName()
                    if currentFloorTile ~= nil then
                        local randomGrass = floorleaves[ZombRand(1, #grass + 1)]
                        local obj = IsoObject.new(getCell(), square, randomGrass)
                        square:AddSpecialObject(obj)
                        obj:transmitCompleteItemToClients()
                        obj:transmitModData()
                    end
                end

                if customGrassPercentageOnRoad >= random_instance:random(1, 101) then
                    local currentFloorTile = square:getFloor() and square:getFloor():getSprite():getName()
                    if currentFloorTile ~= nil then
                        local randomGrass = custom_grass[ZombRand(1, #custom_grass + 1)]
                        local obj = IsoObject.new(getCell(), square, randomGrass)
                        square:AddSpecialObject(obj)
                        obj:transmitCompleteItemToClients()
                        obj:transmitModData()
                    end
                end

            else

                local floor = square:getFloor()

                if floor and floor:getSprite() then
                    local floorSpriteName = floor:getSprite():getName()

                    local isGrass = luautils.stringStarts(floorSpriteName, "blends_natural_01")
                    local isDirt = luautils.stringStarts(floorSpriteName, "blends_natural_01")

                    if (isGrass or isDirt)
                        and treePercentage >= random_instance:random(1, 101) then

                        local randomTree = trees[ZombRand(1, #trees + 1)]
                        local treeSprite = getSprite(randomTree)

                        if treeSprite then

                            local newTree = IsoTree.new(square, treeSprite)
                            square:AddSpecialObject(newTree)
                            newTree:setAttachedAnimSprite(ArrayList.new())

                            local treeSpriteName = newTree:getSprite():getName()

                            local isPine =
                                luautils.stringStarts(treeSpriteName, "e_virginiapine")

                            if not isPine then

                                for leafIndex = 4, 16 do

                                    if leafIndex ~= 0 and leafIndex ~= 1 then

                                        local leafSpriteName = treeSpriteName:gsub(
                                            "_(%d+)$",
                                            "_" .. tostring(leafIndex)
                                        )

                                        local leafSprite = getSprite(leafSpriteName)

                                        if leafSprite then
                                            newTree:getAttachedAnimSprite():add(
                                                leafSprite:newInstance()
                                            )
                                        end
                                    end
                                end
                            end

                            newTree:transmitCompleteItemToClients()
                            newTree:transmitModData()
                        end
                    end
                end
            end

        end

        if SQ.checkWater(square) then

                    if square:isSolidFloor() then
            
                        local currentFloorTile = square:getFloor() and square:getFloor():getSprite():getName()
                        
                        local isInterior = not square:isOutside() or square:getRoom() ~= nil

                        if (square:getZ() == 0 and not SQ.checkRoad(square)) or square:getZ() ~= 0 then
                            
                            if not isInterior then

                                if bushesPercentage >= random_instance:random(1, 101) then
                                    if currentFloorTile ~= nil then
                                        local randomBushes = bushes[ZombRand(1, #bushes + 1)]
                                        local obj = IsoObject.new(getCell(), square, randomBushes)
                                        square:AddSpecialObject(obj)
                                        obj:transmitCompleteItemToClients()
                                        obj:transmitModData()
                                    end
                                end

                                if grassPercentage >= random_instance:random(1, 101) then
                                    if currentFloorTile ~= nil then
                                        local randomGrass = grass[ZombRand(1, #grass + 1)]
                                        local obj = IsoObject.new(getCell(), square, randomGrass)
                                        square:AddSpecialObject(obj)
                                        obj:transmitCompleteItemToClients()
                                        obj:transmitModData()
                                    end
                                end

                                if floorleavesPercentage >= random_instance:random(1, 101) then
                                    if currentFloorTile ~= nil then
                                        local randomLeaves = floorleaves[ZombRand(1, #floorleaves + 1)]
                                        local obj = IsoObject.new(getCell(), square, randomLeaves)
                                        square:AddSpecialObject(obj)
                                        obj:transmitCompleteItemToClients()
                                        obj:transmitModData()
                                    end
                                end

                                if customGrassPercentage >= random_instance:random(1, 101) then
                                    if currentFloorTile ~= nil then
                                        local randomGrass = custom_grass[ZombRand(1, #custom_grass + 1)]
                                        local obj = IsoObject.new(getCell(), square, randomGrass)
                                        square:AddSpecialObject(obj)
                                        obj:transmitCompleteItemToClients()
                                        obj:transmitModData()
                                    end
                                end
                                
                            end 
                        end


                        local isInterior = not square:isOutside() or square:getRoom() ~= nil

                        local currentTrashChance = trashPercentage 
                        if isInterior then
                            currentTrashChance = trashPercentageInterior
                        end

                        currentTrashChance = tonumber(currentTrashChance) or 0

                        if currentTrashChance > 0 and currentTrashChance >= random_instance:random(1, 101) then
                            local floor = square:getFloor()
                            local currentFloorTile = floor and floor:getSprite():getName()

                            if currentFloorTile then
                                local roll = random_instance:random(0, 51)
                                local sprite_type = "trash_01_" .. tostring(roll)
                                local newSprite = IsoObject.new(getCell(), square, sprite_type)

                                if newSprite then
                                    square:AddSpecialObject(newSprite)
                                    square:RecalcProperties()
                                    newSprite:transmitCompleteItemToClients()
                                    newSprite:transmitModData()
                                end
                            end
                        end

                if square:getZ() == 0 then

                    if storiesPercentage >= random_instance:random(1, 1001) then

                        if random_instance:random(0,200) == 1 then

                            local zone = square:getZone()
                            local square_chunk = square:getChunk()
                            local rzs = getWorld():getRandomizedZoneList():get(stories[ZombRand(1, #stories + 1)])

                            if zone and square_chunk then

                                if square:getObjects() then

                                    for i = square:getObjects():size(), 1, -1 do
                                        local object = square:getObjects():get(i-1);

                                        if object and object:getProperties():has(IsoFlagType.canBeRemoved) then
                                            square:transmitRemoveItemFromSquare(object)
                                        end


                                    end

                                end

                                local zone = Zone.new("debugstoryzone", "debugstoryzone", square:getX() - 20, square:getY() - 20, square:getZ(), square:getX() + 20, square:getX() + 20)
                                zone:setPickedXForZoneStory(square:getX())
                                zone:setPickedYForZoneStory(square:getY())
                                zone:setX(square:getX() - (rzs:getMinimumWidth() / 2))
                                zone:setY(square:getY() - (rzs:getMinimumHeight() / 2))
                                zone:setW(rzs:getMinimumWidth() + 2)
                                zone:setH(rzs:getMinimumHeight() + 2)
                                rzs:randomizeZoneStory(zone)

                            end

                        end

                    end

                end

            end

            local objectList = {}

            local objects = square:getObjects()
            if objects then
                local size = objects:size()
                for i = 0, size - 1 do
                    local obj = objects:get(i)
                    if obj then
                        table.insert(objectList, obj)
                    end
                end

            end

            for _, obj in ipairs(objectList) do
                if obj and obj:getSprite() then
                    local spriteName = obj:getSprite():getName()
                    local sprite = getSprite(spriteName)

                    if square:getZ() > 1 then
                        if SQ.isTileInArray(spriteName,roof_top) then

                            if roofPercentage >= random_instance:random(1, 101) then

                                sledgeDestroy(obj)
                                square:transmitRemoveItemFromSquare(obj)

                                if  80 >= random_instance:random(1, 101) then
                                    local randomRoofDestroy = roof_destroy[ZombRand(1, #roof_destroy + 1)]
                                    local obj2 = IsoObject.new(getCell(), square, randomRoofDestroy)
                                    square:AddSpecialObject(obj2)
                                    obj2:transmitCompleteItemToClients()
                                    obj2:transmitModData()
                                end

                                break

                            end

                        end
                    end

                    if SQ.isTileInArray(spriteName,road) then

                        if roadCrackOverlayPercentage >= random_instance:random(1, 101) then

                            local blendsType = "street"

                            if random_instance:random(1,10) == 1 then

                                blendsType = 'dirt'

                            end

                            local overlayId = tostring(random_instance:random(0, 31))
                            local overlayName = "blends_".. blendsType .."overlays_01_" .. overlayId
                            local overlaySprite = getSprite(overlayName)

                            if overlaySprite then

                                obj:setAttachedAnimSprite(ArrayList.new())
                                obj:getAttachedAnimSprite():add(overlaySprite:newInstance())
                                obj:transmitCompleteItemToClients()
                                obj:transmitModData()
                                break

                            end

                        end


                    end

                    if SQ.isTileInArray(spriteName,natural) then

                        if dirtCrackOverlayPercentage >= random_instance:random(1, 101) then

                            local blendsType = "dirt"

                            local overlayId = tostring(random_instance:random(0, 31))
                            local overlayName = "blends_".. blendsType .."overlays_01_" .. overlayId
                            local overlaySprite = getSprite(overlayName)

                            if overlaySprite then

                                obj:setAttachedAnimSprite(ArrayList.new())
                                obj:getAttachedAnimSprite():add(overlaySprite:newInstance())
                                obj:transmitCompleteItemToClients()
                                obj:transmitModData()
                                break

                            end

                        end


                    end

                    if wallPercentage >= random_instance:random(1, 101) then

                        local textureName = obj:getTextureName()

                        if textureName then

                            if luautils.stringStarts(textureName, "walls_interior_") or (luautils.stringStarts(textureName, "walls_exterior_") and not luautils.stringStarts(textureName, "walls_exterior_roofs_")) then

                                if sprite then
                                    local properties = sprite:getProperties()
                                    if properties then
                                        local property = properties:getPropertyNames()
                                        if property and tostring(property) ~= "" then
                                            local property_str = tostring(property):sub(2, -2)
                                            for prop in string.gmatch(property_str, "[^,]+") do
                                                prop = prop:gsub("%s+", "")
                                                if SQ.isTileInArray(prop, wallList) then
                                                    local texture_selected
                                                    if prop == "WallNW" then
                                                        texture_selected = {"walls_exterior_wooden_01_70", "walls_burnt_01_2"}
                                                    elseif prop == "WallN" then
                                                        texture_selected = {"walls_exterior_wooden_01_69", "walls_burnt_01_1"}
                                                    elseif prop == "WallW" then
                                                        texture_selected = {"walls_exterior_wooden_01_68", "walls_burnt_01_0"}
                                                    elseif prop == "WindowN" then
                                                        texture_selected = {"walls_exterior_wooden_01_77", "walls_burnt_01_13"}
                                                    elseif prop == "WindowW" then
                                                        texture_selected = {"walls_exterior_wooden_01_76", "walls_burnt_01_12"}
                                                    elseif prop == "DoorWallW" then
                                                        texture_selected = {"walls_exterior_wooden_01_78", "walls_burnt_01_10"}
                                                    elseif prop == "DoorWallN" then
                                                        texture_selected = {"walls_exterior_wooden_01_75", "walls_burnt_01_15"}
                                                    end
                                                    if texture_selected then
                                                        obj:setSpriteFromName(texture_selected[ZombRand(1, #texture_selected + 1)])
                                                        obj:transmitCompleteItemToClients()
                                                        obj:transmitModData()
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end

                            end

                        end

                    end
                if square:getRoom() == nil then
                    if vinePercentage >= random_instance:random(1, 101) then

                        local textureName = obj:getTextureName()

                        if textureName then

                            if square:getZ() == 0 then

                                if textureName and (
                                    luautils.stringStarts(textureName, "walls_")
                                    or luautils.stringStarts(textureName, "fixtures_")
                                    or luautils.stringStarts(textureName, "fencing_")
                                    or (
                                        luautils.stringStarts(textureName, "location_")
                                        and not luautils.stringStarts(textureName, "walls_detailling")
                                    )
                                ) then

                                    local tiles_properties =
                                        tostring(getSprite(tostring(textureName)):getProperties():getPropertyNames())

                                    if tiles_properties:contains('WallNW') then

                                        local isLowWall =
                                            luautils.stringStarts(textureName, "fixtures_railings")
                                            or tiles_properties:contains('FenceTypeLow')

                                        local randomOverlay

                                        if isLowWall then
                                            randomOverlay =
                                                wallNW_low[ZombRand(1, #wallNW_low + 1)]
                                        else
                                            randomOverlay =
                                                wallNW[ZombRand(1, #wallNW + 1)]
                                        end

                                        local obj2 =
                                            IsoObject.new(getCell(), square, randomOverlay)

                                        square:AddTileObject(obj2)

                                        if not isLowWall
                                            and (
                                                randomOverlay == 'f_wallvines_1_47'
                                                or randomOverlay == 'f_wallvines_1_46'
                                            )
                                        then

                                            local neighbour =
                                                getCell():getGridSquare(
                                                    square:getX(),
                                                    square:getY(),
                                                    square:getZ() + 1
                                                )

                                            if neighbour then

                                                local neighbourObj =
                                                    neighbour:getObjects()

                                                if neighbourObj then

                                                    for i2 = 0, neighbourObj:size() - 1 do

                                                        local obj3 =
                                                            neighbourObj:get(i2):getSpriteName()

                                                        if
                                                            luautils.stringStarts(tostring(obj3), "walls_")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_detailling")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_exterior_roofs")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_interior")
                                                        then

                                                            local randomOverlay2 =
                                                                wallNW_top[
                                                                    ZombRand(1, #wallNW_top + 1)
                                                                ]

                                                            local obj4 =
                                                                IsoObject.new(
                                                                    getCell(),
                                                                    neighbour,
                                                                    randomOverlay2
                                                                )

                                                            neighbour:AddSpecialObject(obj4)

                                                            break
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end


                                    if
                                        tiles_properties:contains('WallW')
                                        or tiles_properties:contains('WindowW')
                                        or tiles_properties:contains('doorW')
                                        or tiles_properties:contains('DoorWallW')
                                        or tiles_properties:contains('attachedW')
                                        or tiles_properties:contains('WallWTrans')
                                    then

                                        local isLowWall =
                                            luautils.stringStarts(textureName, "fixtures_railings")
                                            or tiles_properties:contains('FenceTypeLow')

                                        local randomOverlay

                                        if isLowWall then
                                            randomOverlay =
                                                wallW_low[ZombRand(1, #wallW_low + 1)]
                                        else
                                            randomOverlay =
                                                wallW[ZombRand(1, #wallW + 1)]
                                        end

                                        local obj2 =
                                            IsoObject.new(getCell(), square, randomOverlay)

                                        square:AddTileObject(obj2)

                                        if not isLowWall
                                            and (
                                                randomOverlay == 'f_wallvines_1_43'
                                                or randomOverlay == 'f_wallvines_1_42'
                                            )
                                        then

                                            local neighbour =
                                                getCell():getGridSquare(
                                                    square:getX(),
                                                    square:getY(),
                                                    square:getZ() + 1
                                                )

                                            if neighbour then

                                                local neighbourObj =
                                                    neighbour:getObjects()

                                                if neighbourObj then

                                                    for i2 = 0, neighbourObj:size() - 1 do

                                                        local obj3 =
                                                            neighbourObj:get(i2):getSpriteName()

                                                        if
                                                            luautils.stringStarts(tostring(obj3), "walls_")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_detailling")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_exterior_roofs")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_interior")
                                                        then

                                                            local randomOverlay2 =
                                                                wallW_top[
                                                                    ZombRand(1, #wallW_top + 1)
                                                                ]

                                                            local obj4 =
                                                                IsoObject.new(
                                                                    getCell(),
                                                                    neighbour,
                                                                    randomOverlay2
                                                                )

                                                            neighbour:AddSpecialObject(obj4)

                                                            break
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end

                                    if
                                        tiles_properties:contains('WallN')
                                        or tiles_properties:contains('WindowN')
                                    then

                                        local isLowWall =
                                            luautils.stringStarts(textureName, "fixtures_railings")
                                            or tiles_properties:contains('FenceTypeLow')

                                        local randomOverlay

                                        if isLowWall then
                                            randomOverlay =
                                                wallN_low[ZombRand(1, #wallN_low + 1)]
                                        else
                                            randomOverlay =
                                                wallN[ZombRand(1, #wallN + 1)]
                                        end

                                        local obj2 =
                                            IsoObject.new(getCell(), square, randomOverlay)

                                        square:AddTileObject(obj2)

                                        if not isLowWall
                                            and (
                                                randomOverlay == 'f_wallvines_1_44'
                                                or randomOverlay == 'f_wallvines_1_45'
                                            )
                                        then

                                            local neighbour =
                                                getCell():getGridSquare(
                                                    square:getX(),
                                                    square:getY(),
                                                    square:getZ() + 1
                                                )

                                            if neighbour then

                                                local neighbourObj =
                                                    neighbour:getObjects()

                                                if neighbourObj then

                                                    for i2 = 0, neighbourObj:size() - 1 do

                                                        local obj3 =
                                                            neighbourObj:get(i2):getSpriteName()

                                                        if
                                                            luautils.stringStarts(tostring(obj3), "walls_")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_detailling")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_exterior_roofs")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_interior")
                                                        then

                                                            local randomOverlay2 =
                                                                wallN_top[
                                                                    ZombRand(1, #wallN_top + 1)
                                                                ]

                                                            local obj4 =
                                                                IsoObject.new(
                                                                    getCell(),
                                                                    neighbour,
                                                                    randomOverlay2
                                                                )

                                                            neighbour:AddSpecialObject(obj4)

                                                            break
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end

                                end

                            else

                                if
                                    textureName
                                    and luautils.stringStarts(tostring(textureName), "walls_")
                                    and not luautils.stringStarts(tostring(textureName), "walls_detailling")
                                    and not luautils.stringStarts(tostring(textureName), "walls_exterior_roofs")
                                    and not luautils.stringStarts(tostring(textureName), "walls_interior")
                                then

                                    local tiles_properties =
                                        tostring(getSprite(tostring(textureName)):getProperties():getPropertyNames())


                                    if tiles_properties:contains('WallNW') then

                                        local isLowWall =
                                            luautils.stringStarts(textureName, "fixtures_railings")
                                            or tiles_properties:contains('FenceTypeLow')

                                        local randomOverlay

                                        if isLowWall then
                                            randomOverlay =
                                                wallNW_low[ZombRand(1, #wallNW_low + 1)]
                                        else
                                            randomOverlay =
                                                wallNW[ZombRand(1, #wallNW + 1)]
                                        end

                                        local obj2 =
                                            IsoObject.new(getCell(), square, randomOverlay)

                                        square:AddTileObject(obj2)

                                        if not isLowWall
                                            and (
                                                randomOverlay == 'f_wallvines_1_47'
                                                or randomOverlay == 'f_wallvines_1_46'
                                            )
                                        then

                                            local neighbour =
                                                getCell():getGridSquare(
                                                    square:getX(),
                                                    square:getY(),
                                                    square:getZ() + 1
                                                )

                                            if neighbour then

                                                local neighbourObj =
                                                    neighbour:getObjects()

                                                if neighbourObj then

                                                    for i2 = 0, neighbourObj:size() - 1 do

                                                        local obj3 =
                                                            neighbourObj:get(i2):getSpriteName()

                                                        if
                                                            luautils.stringStarts(tostring(obj3), "walls_")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_detailling")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_exterior_roofs")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_interior")
                                                        then

                                                            local randomOverlay2 =
                                                                wallNW_top[
                                                                    ZombRand(1, #wallNW_top + 1)
                                                                ]

                                                            local obj4 =
                                                                IsoObject.new(
                                                                    getCell(),
                                                                    neighbour,
                                                                    randomOverlay2
                                                                )

                                                            neighbour:AddSpecialObject(obj4)

                                                            break
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end

                                    if
                                        tiles_properties:contains('WallW')
                                        or tiles_properties:contains('WindowW')
                                        or tiles_properties:contains('doorW')
                                        or tiles_properties:contains('DoorWallW')
                                        or tiles_properties:contains('attachedW')
                                        or tiles_properties:contains('WallWTrans')
                                    then

                                        local isLowWall =
                                            luautils.stringStarts(textureName, "fixtures_railings")
                                            or tiles_properties:contains('FenceTypeLow')

                                        local randomOverlay

                                        if isLowWall then
                                            randomOverlay =
                                                wallW_low[ZombRand(1, #wallW_low + 1)]
                                        else
                                            randomOverlay =
                                                wallW[ZombRand(1, #wallW + 1)]
                                        end

                                        local obj2 =
                                            IsoObject.new(getCell(), square, randomOverlay)

                                        square:AddTileObject(obj2)

                                        if not isLowWall
                                            and (
                                                randomOverlay == 'f_wallvines_1_43'
                                                or randomOverlay == 'f_wallvines_1_42'
                                            )
                                        then

                                            local neighbour =
                                                getCell():getGridSquare(
                                                    square:getX(),
                                                    square:getY(),
                                                    square:getZ() + 1
                                                )

                                            if neighbour then

                                                local neighbourObj =
                                                    neighbour:getObjects()

                                                if neighbourObj then

                                                    for i2 = 0, neighbourObj:size() - 1 do

                                                        local obj3 =
                                                            neighbourObj:get(i2):getSpriteName()

                                                        if
                                                            luautils.stringStarts(tostring(obj3), "walls_")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_detailling")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_exterior_roofs")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_interior")
                                                        then

                                                            local randomOverlay2 =
                                                                wallW_top[
                                                                    ZombRand(1, #wallW_top + 1)
                                                                ]

                                                            local obj4 =
                                                                IsoObject.new(
                                                                    getCell(),
                                                                    neighbour,
                                                                    randomOverlay2
                                                                )

                                                            neighbour:AddSpecialObject(obj4)

                                                            break
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end

                                    if
                                        tiles_properties:contains('WallN')
                                        or tiles_properties:contains('WindowN')
                                    then

                                        local isLowWall =
                                            luautils.stringStarts(textureName, "fixtures_railings")
                                            or tiles_properties:contains('FenceTypeLow')

                                        local randomOverlay

                                        if isLowWall then
                                            randomOverlay =
                                                wallN_low[ZombRand(1, #wallN_low + 1)]
                                        else
                                            randomOverlay =
                                                wallN[ZombRand(1, #wallN + 1)]
                                        end

                                        local obj2 =
                                            IsoObject.new(getCell(), square, randomOverlay)

                                        square:AddTileObject(obj2)

                                        if not isLowWall
                                            and (
                                                randomOverlay == 'f_wallvines_1_44'
                                                or randomOverlay == 'f_wallvines_1_45'
                                            )
                                        then

                                            local neighbour =
                                                getCell():getGridSquare(
                                                    square:getX(),
                                                    square:getY(),
                                                    square:getZ() + 1
                                                )

                                            if neighbour then

                                                local neighbourObj =
                                                    neighbour:getObjects()

                                                if neighbourObj then

                                                    for i2 = 0, neighbourObj:size() - 1 do

                                                        local obj3 =
                                                            neighbourObj:get(i2):getSpriteName()

                                                        if
                                                            luautils.stringStarts(tostring(obj3), "walls_")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_detailling")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_exterior_roofs")
                                                            and not luautils.stringStarts(tostring(obj3), "walls_interior")
                                                        then

                                                            local randomOverlay2 =
                                                                wallN_top[
                                                                    ZombRand(1, #wallN_top + 1)
                                                                ]

                                                            local obj4 =
                                                                IsoObject.new(
                                                                    getCell(),
                                                                    neighbour,
                                                                    randomOverlay2
                                                                )

                                                            neighbour:AddSpecialObject(obj4)

                                                            break
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end

                                end
                            end
                        end
                    end
                end

            local TYL_BrokenFences = BrokenFences.getInstance()

            if fencePercentage >= random_instance:random(1, 101) then

                local properties = obj:getProperties()

                local isLowFence =
                    properties:has('FenceTypeLow')
                    and properties:get("FenceTypeLow") ~= 'Barbwire'

                local isHighFence =
                    properties:getPropertyNames():contains('FenceTypeHigh')

                if isLowFence or isHighFence then


                    local damageRoll = random_instance:random(1, 100)


                    if damageRoll <= 25 then

                        TYL_BrokenFences:updateSprite(obj, true, false)

                    elseif damageRoll <= 60 then

                        TYL_BrokenFences:updateSprite(obj, false, true)


                    else

                        local direction = nil

                        if properties:has(IsoFlagType.collideN) then

                            if random_instance:random(0, 1) == 0 then
                                direction = IsoDirections.N
                            else
                                direction = IsoDirections.S
                            end

                        elseif properties:has(IsoFlagType.collideW) then

                            if random_instance:random(0, 1) == 0 then
                                direction = IsoDirections.W
                            else
                                direction = IsoDirections.E
                            end

                        end

                        if direction then

                            TYL_BrokenFences:destroyFence(obj, direction)


                            TYL_RemoveVinesFromBrokenFence(square)

                        end
                    end
                end
            end


            if TYL_BrokenFence then
                TYL_RemoveVinesFromBrokenFence(square)
            end

                if shouldBarricade then

                    if instanceof(obj, "IsoWindow") then
                        obj:smashWindow()
                    end

                    if barricadePercentage >= random_instance:random(1, 101) then

                        if instanceof(obj, "IsoWindow") then

                            local isMetal =
                                (random_instance:random(0, 5) == 0)

                            obj:addBarricadesDebug(
                                random_instance:random(2, 5),
                                isMetal
                            )

                            break

                        end

                        if instanceof(obj, "IsoDoor") then

                            obj:addRandomBarricades()

                            break

                        end
                    end
                end
                    if obj:getTextureName() and luautils.stringStarts(tostring(obj:getTextureName()), "d_generic_") then
                        square:transmitRemoveItemFromSquare(obj)

                        local obj2 = IsoObject.new(getCell(), square, tostring(obj:getTextureName()))
                        square:AddSpecialObject(obj2)

                        if customName[tostring(obj:getTextureName())] ~= nil then
                            obj2:getProperties():set('CustomName',customName[tostring(obj:getTextureName())])
                        end

                        obj2:transmitCompleteItemToClients()
                        obj2:transmitModData()


                    end

                end
            end

        end

        square:getModData()['TYLVEG'] = true
        square:transmitModdata()

    end



end

Events.LoadGridsquare.Add(LoadGridsquare)