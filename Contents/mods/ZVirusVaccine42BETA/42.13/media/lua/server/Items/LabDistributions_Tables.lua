-- LabDistributions_Tables.lua
-- Tabelas para distribuição de itens
-- Separado da lógica para facilitar manutenção

local LabDistributionsTables = {}

--==============================================
-- TABELAS DE LOCAIS (onde os itens aparecem)
-- Facilita a inclusão/exclusão de novas tabelas
--==============================================

LabDistributionsTables.chemicalsTables = {
    SafehouseMedical = 50,
    SafehouseMedical_Mid = 30,
    SafehouseMedical_Late = 15,
    TestingLab = 50,
    ArmyStorageMedical = 25,
    BathroomShelf = 10,
    DerelictHouseDrugs = 8,
    DoctorTools = 3,
    DrugShackDrugs = 8,
    MedicalClinicDrugs = 2,
    MedicalClinicOutfit = 2,
    MedicalStorageDrugs = 2,
    MedicalStorageTools = 10,
    ArmyBunkerStorage = 20,
    CrateTools = 10,
    CrateToolsOld = 10,
    DrugShackTools = 10,
    FireStorageTools = 5,
    GarageTools = 12,
    JanitorTools = 20,
    LoggingFactoryTools = 12,
    PawnShopTools = 2,
    StoreKitchenCleaning = 20,
    PoliceEvidence = 2,
    UniversityStorageScience = 50,
    ArmyBunkerMedical = 20,
    CortmanOfficeDesk = 2,
    HospitalRoomCleaning = 20,
    HospitalRoomShelves = 8,
    MorgueTools = 10,
    MorgueChemicals = 50,
    Chemistry = 10,
    DrugShackMisc = 5,
    FridgeDrugLab = 10,
    GigamartCleaning = 15,
    HospitalLockers = 1,
    JanitorMisc = 8,
    LaboratoryGasStorage = 1,
    LaundryCleaning = 8,
    ScienceMisc = 12,
    LaboratoryLockers = 10,
    LaundryHospital = 10,
}

LabDistributionsTables.expandedChemicalsTables = {
    ArmyBunkerKitchen = 5,
    ArmyHangarTools = 5,
    BakeryKitchenStorage = 5,
    BathroomCounter = 5,
    BathroomCounterEmpty = 5,
    CarpenterTools = 5,
    CrateMetalwork = 5,
    CratePetSupplies = 5,
    CrateRandomJunk = 5,
    CrateSalonSupplies = 5,
    GardenStoreTools = 5,
    Gas2GoCounterCleaning = 5,
    GasStorageCombo = 5,
    GigamartFarming = 5,
    KitchenRandom = 5,
    GolfFactoryTools = 5,
    KnifeFactoryTools = 5,
}

-- also for albumin
LabDistributionsTables.syringesTables = {
    TestingLab = 30,
    DerelictHouseDrugs = 20,
    DrugShackDrugs = 25,
    DoctorTools = 15,
    HospitalRoomShelves = 25,
    UniversityStorageScience = 30,
    ArmyBunkerMedical = 40,
    MorgueTools = 20,
    MedicalStorageDrugs = 30,
    MedicalStorageTools = 20,
    MedicalClinicDrugs = 20,
}

LabDistributionsTables.syringePackTables = {
    SafehouseMedical = 50,
    SafehouseMedical_Mid = 30,
    SafehouseMedical_Late = 20,
    TestingLab = 30,
    ArmyStorageMedical = 30,
    DoctorTools = 10,
    MedicalClinicDrugs = 12,
    DrugLabSupplies = 20,
    DrugShackDrugs = 15,
    DrugShackMisc = 5,
    HospitalLockers = 5,
    HospitalRoomCounter = 3,
    HospitalRoomShelves = 5,
    LaboratoryGasStorage = 2,
    LaboratoryLockers = 2,
    MedicalStorageDrugs = 20,
    MedicalStorageTools = 20,
    SurvivalGear = 1,
    UniversityStorageScience = 5,
}

LabDistributionsTables.chlorineTabletsTables = {
    SafehouseMedical = 10,
    SafehouseMedical_Mid = 8,
    SafehouseMedical_Late = 6,
    TestingLab = 20,
    ArmyStorageMedical = 8,
    DoctorTools = 8,
    MedicalClinicDrugs = 8,
    DrugLabSupplies = 6,
    DrugShackDrugs = 5,
    DrugShackMisc = 3,
    HospitalLockers = 3,
    HospitalRoomCounter = 3,
    HospitalRoomShelves = 3,
    LaboratoryGasStorage = 2,
    LaboratoryLockers = 2,
    MedicalStorageDrugs = 6,
    MedicalStorageTools = 6,
    SurvivalGear = 1,
    UniversityStorageScience = 10,
    ArmyBunkerMedical = 20,
}

LabDistributionsTables.equipmentBookTables = {
    ShelfGeneric = 2,
    AmbulanceDriverOutfit = 1,
    AmbulanceDriverTools = 1,
    BookstoreCrafts = 3,
    ArmySurplusLiterature = 3,
    BookstoreMisc = 2,
    BookstoreOutdoors = 1,
    CabinetFactoryTools = 1,
    CampingStoreBooks = 1,
    CarpenterTools = 1,
    ComicStoreMagazines = 1,
    CrateBooks = 4,
    CrateMagazines = 2,
    CrateNewspapers = 0.5,
    CrateNewspapersNew = 0.5,
    ConstructionWorkerTools = 0.5,
    ElectronicStoreMagazines = 1,
    GarageCarpentry = 2,
    GarageMechanics = 0.5,
    GarageTools = 0.5,
    GeneratorRoom = 2,
    GigamartLiterature = 6,
    GunStoreLiterature = 3,
    LibraryBooks = 8,
    LibraryBiography = 1,
    LibraryBusiness = 2,
    LibraryCounter = 3,
    LibraryMagazines = 2,
    LibraryOutdoors = 2,
    LivingRoomShelf = 0.05,
    LivingRoomShelfClassy = 0.05,
    LivingRoomShelfRedneck = 0.05,
    LivingRoomSideTable = 0.05,
    LivingRoomSideTableClassy = 0.01,
    LivingRoomSideTableRedneck = 0.05,
    LivingRoomWardrobe = 0.1,
    MagazineRackMixed = 0.1,
    MetalWorkerOutfit = 1,
    MetalWorkerTools = 1,
    PostOfficeBooks = 3,
    PostOfficeMagazines = 1,
    RecRoomShelf = 0.01,
    SafehouseArmor = 1,
    SafehouseBookShelf = 1,
    SafehouseFireplace = 0.1,
    SafehouseFireplace_Late = 0.1,
    SurvivalGear = 1,
    ToolStoreBooks = 8,
    UniversityLibraryBooks = 3,
    --UniversityLibraryMedical = 3,
}

LabDistributionsTables.chemistryCourseTables = {
    BookstoreScience = 0.5,
    LibraryMedical = 0.2,
    LibraryScience = 1,
    MedicalOfficeBooks = 0.2,
    ScienceMisc = 0.5,
    DoctorOutfit = 1,
    HospitalLockers = 0.01,
    HospitalMagazineRack = 0.5,
    LaboratoryBooks = 2,
    UniversityLibraryBooks = 6,
    UniversityLibraryMagazines = 4,
    UniversityLibraryMedical = 12,
    UniversityLibraryScience = 20,
    UniversityStorageScience = 30,
    TestingLab = 20,
}

LabDistributionsTables.virologyBooksTables = {
    TestingLab = 15,
    ArmyStorageMedical = 25,
    UniversityStorageScience = 25,
    UniversityLibraryBooks = 5,
    UniversityLibraryMagazines = 5,
    UniversityLibraryMedical = 12,
    UniversityLibraryScience = 30,
}

-- Expands to clinics, hospitals, science, medical locations. Also expands to a few bookstores categories.
LabDistributionsTables.virologyExpandedTables = {
    BookstoreMedical = 1,
    BookstoreMilitaryHistory = 2,
    BookstoreScience = 2,
    DoctorOutfit = 1,
    HospitalLockers = 0.01,
    HospitalMagazineRack = 0.5,
    LaboratoryBooks = 6,
    LibraryMedical = 0.2,
    LibraryScience = 1,
    MedicalOfficeBooks = 0.2,
    ScienceMisc = 1,
}

-- FULL SPAWN MODE: Loots between 0.01-2%
LabDistributionsTables.virologyBooksFullTables = {
    AmbulanceDriverOutfit = 1,
    AmbulanceDriverTools = 1,
    ArmySurplusLiterature = 1,
    BookstoreBooks = 1,
    BookstoreCrafts = 1,
    BookstoreMedical = 1,
    BookstoreMilitaryHistory = 1,
    BookstoreMisc = 2,
    BookstoreOutdoors = 1,
    BookstoreScience = 1,
    CabinetFactoryTools = 1,
    CampingStoreBooks = 1,
    CarpenterTools = 1,
    ClassroomDesk = 2,
    ClassroomMisc = 2,
    ClassroomShelves = 2,
    ClassroomSecondaryDesk = 2,
    ClassroomSecondaryMisc = 2,
    ClassroomSecondaryShelves = 2,
    ComicStoreMagazines = 1,
    ConstructionWorkerTools = 0.5,
    CrateBooks = 2,
    CrateMagazines = 2,
    CrateNewspapers = 0.5,
    CrateNewspapersNew = 0.5,
    DoctorOutfit = 1,
    ElectronicStoreMagazines = 1,
    GarageCarpentry = 2,
    GarageMechanics = 0.5,
    GarageTools = 0.5,
    GeneratorRoom = 2,
    GigamartLiterature = 2,
    GunStoreLiterature = 1,
    HospitalLockers = 0.01,
    HospitalMagazineRack = 0.5,
    LaboratoryBooks = 1,
    LibraryBiography = 1,
    LibraryBooks = 1,
    LibraryBusiness = 2,
    LibraryCounter = 2,
    LibraryMagazines = 2,
    LibraryMedical = 0.2,
    LibraryOutdoors = 2,
    LibraryScience = 1,
    LivingRoomShelf = 0.05,
    LivingRoomShelfClassy = 0.05,
    LivingRoomShelfRedneck = 0.05,
    LivingRoomSideTable = 0.05,
    LivingRoomSideTableClassy = 0.01,
    LivingRoomSideTableRedneck = 0.05,
    LivingRoomWardrobe = 0.1,
    MagazineRackMixed = 0.1,
    MedicalOfficeBooks = 0.2,
    MetalWorkerOutfit = 1,
    MetalWorkerTools = 1,
    PostOfficeBooks = 1,
    PostOfficeMagazines = 1,
    RecRoomShelf = 0.01,
    SafehouseArmor = 1,
    SafehouseBookShelf = 1,
    SafehouseFireplace = 0.1,
    SafehouseFireplace_Late = 0.1,
    ScienceMisc = 1,
    ShelfGeneric = 2,
    SurvivalGear = 1,
    ToolStoreBooks = 1,
    UniversitySideTable = 2,
    --UniversityLibraryBooks = 1, -- it's already in the standard spawn, no need to add it here
    --UniversityLibraryMedical = 1,
}

LabDistributionsTables.paintLightsTables = {
    ShelfGeneric = 2,
    AmbulanceDriverOutfit = 1,
    AmbulanceDriverTools = 1,
    BookstoreCrafts = 3,
    ArmySurplusLiterature = 3,
    BookstoreMisc = 2,
    BookstoreOutdoors = 1,
    CabinetFactoryTools = 1,
    CampingStoreBooks = 1,
    CarpenterTools = 1,
    ComicStoreMagazines = 1,
    ConstructionWorkerTools = 0.5,
    CrateBooks = 4,
    CrateMagazines = 2,
    CrateNewspapers = 0.5,
    CrateNewspapersNew = 0.5,
    ElectronicStoreMagazines = 1,
    GarageCarpentry = 2,
    GarageMechanics = 0.5,
    GarageTools = 0.5,
    GeneratorRoom = 2,
    GigamartLiterature = 6,
    GunStoreLiterature = 3,
    LibraryBooks = 8,
    LibraryBiography = 1,
    LibraryBusiness = 2,
    LibraryCounter = 3,
    LibraryMagazines = 2,
    LibraryOutdoors = 2,
    LivingRoomShelf = 0.05,
    LivingRoomShelfClassy = 0.05,
    LivingRoomShelfRedneck = 0.05,
    LivingRoomSideTable = 0.05,
    LivingRoomSideTableClassy = 0.01,
    LivingRoomSideTableRedneck = 0.05,
    LivingRoomWardrobe = 0.1,
    MagazineRackMixed = 0.1,
    RecRoomShelf = 0.01,
    MetalWorkerOutfit = 1,
    MetalWorkerTools = 1,
    PostOfficeBooks = 3,
    PostOfficeMagazines = 1,
    SafehouseArmor = 1,
    SafehouseBookShelf = 1,
    SafehouseFireplace = 0.1,
    SafehouseFireplace_Late = 0.1,
    SurvivalGear = 1,
    ToolStoreBooks = 4,
    UniversityLibraryBooks = 8,
    UniversityLibraryMedical = 8,
}

--==============================
-- TABELAS DE VEÍCULOS
--==============================

LabDistributionsTables.vehicleEquipmentContainers = {
    SurvivalistGloveBox = 1,
    SurvivalistTruckBed = 2,
    CarpenterGloveBox = 1,
    CarpenterTruckBed = 1.5,
    ElectricianGloveBox = 1,
    ElectricianTruckBed = 1.5,
}

LabDistributionsTables.vehicleVirologyContainers = {
    AmbulanceGloveBox = 1,
    NurseGloveBox = 1,
    AmbulanceTruckBed = 0.5,
    NurseTruckBed = 0.5,
}

LabDistributionsTables.vehicleChemicalContainers = {
    AmbulanceTruckBed = 1,
    SurvivalistTruckBed = 1,
}

LabDistributionsTables.medicalVehicleContainers = {
    AmbulanceGloveBox = 2,
    AmbulanceTruckBed = 1,
    NurseGloveBox = 2,
    NurseTruckBed = 1,
}

--==============================
-- TABELAS DE MOCHILAS/BAGS
--==============================

LabDistributionsTables.bagEquipmentBookTables = {
    SurvivorItems = 2,
}

LabDistributionsTables.bagVirologyTables = {
    SurvivorItems = 1,
}

--==============================
-- TABELAS DE ITENS
-- Facilita a inclusão/exclusão de novos itens
--==============================

LabDistributionsTables.chemicalItems = {
    "LabItems.ChAmmonia",
    "LabItems.ChHydrochloricAcidCan",
    "LabItems.ChSodiumHydroxideBag",
    "LabItems.ChSulfuricAcidCan",
}

LabDistributionsTables.labEquipmentBooks = {
    "LabBooks.BkLaboratoryEquipment1",
    "LabBooks.BkLaboratoryEquipment2",
    "LabBooks.BkLaboratoryEquipment3",
}

LabDistributionsTables.labVirologybooks = {
    "LabBooks.BkVirologyCourses1",
    "LabBooks.BkVirologyCourses2",
}

LabDistributionsTables.bagVirologyBooks = {
    "LabBooks.BkVirologyCourses1",
    "LabBooks.BkVirologyCourses2",
    "LabBooks.BkChemistryCourse",
}

LabDistributionsTables.medicalItems = {
    "LabItems.CmpChlorineTablets",
    "LabItems.LabSyringe",
    "LabItems.LabSyringePack",
}

LabDistributionsTables.bagChemicalItems = {
    { item = "LabItems.CmpChlorineTablets", chance = 0.5 },
    { item = "LabItems.LabFlask",           chance = 0.1 },
    { item = "LabItems.LabTestTube",        chance = 0.1 },
}

--==============================
-- ZONAS RESTRITAS
--==============================
LabDistributionsTables.restrictedZones = {
    {
        name = "WestPointPoliceBasementLab",
        xMin = 11885,
        xMax = 11890,
        yMin = 6930,
        yMax = 6940,
        z = -1,
        -- items é preenchido em runtime no LabDistributions.lua usando labVirologybooks
    },

    -- Adicionar mais zonas aqui seguindo o formato acima, se necessário
}

return LabDistributionsTables