require 'Items/ProceduralDistributions'

local function addItems(listName, ...)
    local dist = ProceduralDistributions.list[listName]
    if not dist then return end
    local args = {...}
    for i = 1, #args do
        table.insert(dist.items, args[i])
    end
end

local function addVehicleItems(dist, ...)
    if not dist then return end
    local args = {...}
    for i = 1, #args do
        table.insert(dist.items, args[i])
    end
end

addItems("ArmyHangarOutfit", "Hat_CrashHelmet_Police", 0.5, "Hat_CrashHelmet_Stars", 0.5)
addItems("FireStorageOutfit", "Hat_CrashHelmetFULL", 0.5, "Hat_CrashHelmet", 0.5)

addItems("MechanicShelfOutfit",
    "Hat_CrashHelmet_Police", 0.5, "Hat_CrashHelmetFULL", 0.5,
    "Hat_CrashHelmet", 0.5, "Hat_CrashHelmet_Stars", 0.5)

addItems("PoliceStorageOutfit",
    "Hat_CrashHelmet_Police", 0.5, "Hat_CrashHelmetFULL", 0.5,
    "Hat_CrashHelmet", 0.5, "Hat_CrashHelmet_Stars", 0.5)

addItems("CrateRandomJunk",
    "Hat_CrashHelmet_Police", 0.02, "Hat_CrashHelmetFULL", 0.02,
    "Hat_CrashHelmet", 0.02, "Hat_CrashHelmet_Stars", 0.02)

addItems("CrateSports",
    "Hat_CrashHelmet_Police", 0.02, "Hat_CrashHelmetFULL", 0.02,
    "Hat_CrashHelmet", 0.02, "Hat_CrashHelmet_Stars", 0.02)

addItems("WardrobeMan",
    "Hat_CrashHelmet_Police", 0.5, "Hat_CrashHelmetFULL", 0.5,
    "Hat_CrashHelmet", 0.5, "Hat_CrashHelmet_Stars", 0.5)

addItems("SportStorageHelmets",
    "Hat_CrashHelmet_Police", 0.5, "Hat_CrashHelmetFULL", 0.5,
    "Hat_CrashHelmet", 0.5, "Hat_CrashHelmet_Stars", 0.5)

if VehicleDistributions and VehicleDistributions.SurvivalistTruckBed then
    addVehicleItems(VehicleDistributions.SurvivalistTruckBed,
        "Hat_CrashHelmet_Police", 0.5, "Hat_CrashHelmetFULL", 0.5,
        "Hat_CrashHelmet", 0.5, "Hat_CrashHelmet_Stars", 0.5)
end

--tires
addItems("MechanicShelfWheels",
    "ATAMotoBMWOldTire", 2.5, "ATAMotoBMWNormalTire", 2, "ATAMotoBMWModernTire", 1.3,
    "ATAMotoHarleyOldTire", 2.5, "ATAMotoHarleyNormalTire", 2, "ATAMotoHarleyModernTire", 1.3)

--CarTiresNormal - ATAMotoBMWNormalTire
addItems("CarTiresNormal1", "ATAMotoBMWNormalTire", 5, "ATAMotoBMWNormalTire", 5, "ATAMotoBMWNormalTire")
addItems("CarTiresNormal2", "ATAMotoBMWNormalTire", 5, "ATAMotoBMWNormalTire", 5)
addItems("CarTiresNormal3", "ATAMotoBMWNormalTire", 5, "ATAMotoBMWNormalTire", 5)

--CarTiresNormal - ATAMotoHarleyNormalTire
addItems("CarTiresNormal1", "ATAMotoHarleyNormalTire", 5, "ATAMotoHarleyNormalTire", 5)
addItems("CarTiresNormal2", "ATAMotoHarleyNormalTire", 5, "ATAMotoHarleyNormalTire", 5)
addItems("CarTiresNormal3", "ATAMotoHarleyNormalTire", 5, "ATAMotoHarleyNormalTire", 5)

--CarTiresModern - ATAMotoBMWModernTire
addItems("CarTiresModern1", "ATAMotoBMWModernTire", 5, "ATAMotoBMWModernTire", 5)
addItems("CarTiresModern2", "ATAMotoBMWModernTire", 5, "ATAMotoBMWModernTire", 5)
addItems("CarTiresModern3", "ATAMotoBMWModernTire", 5, "ATAMotoBMWModernTire", 5)

--CarTiresModern - ATAMotoHarleyModernTire
addItems("CarTiresModern1", "ATAMotoHarleyModernTire", 5, "ATAMotoHarleyModernTire", 5)
addItems("CarTiresModern2", "ATAMotoHarleyModernTire", 5, "ATAMotoHarleyModernTire", 5)
addItems("CarTiresModern3", "ATAMotoHarleyModernTire", 5, "ATAMotoHarleyModernTire", 5)

--mufflers
addItems("MechanicShelfMufflers",
    "ATAMotoBMWClassicMuffler", 2, "ATAMotoBMWCustomMuffler", 1,
    "ATAMotoHarleyMuffler", 2, "ATAMotoHarleyMuffler", 1)

--bags
addItems("CrateMechanics",
    "ATAMotoBagBMW1", 1, "ATAMotoBagBMW2", 1,
    "ATAMotoHarleyBag", 1, "ATAMotoHarleyHolster", 1)
