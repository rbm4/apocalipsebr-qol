require "Items/ProceduralDistributions"
require "MissingSkillBooks_Core"

MissingSkillBooks = MissingSkillBooks or {}


function MissingSkillBooks.addRunningSkillBooks()

    local settings =
        SandboxVars.MissingSkillBooks

    local books =
        MissingSkillBooks.makeBookList("Running")


    local distributions =
        MissingSkillBooks.getStandardBookDistributions()
        
    distributions.BookstoreBlueCollar = {
        6, 4, 2, 1
    }

    distributions.BookstoreSports = {
        10, 8, 6, 4, 2
    }

    -- Sports / fitness
    distributions.FitnessTrainer = {
        6, 4, 2, 1, 0.5
    }

    distributions.GymLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.ClosetSportsEquipment = {
        6, 4, 2, 1, 0.5
    }

    distributions.SchoolGymSportsGear = {
        2, 1, 0.5
    }

    distributions.SportStoreSneakers = {
        5, 4, 2, 1, 0.5
    }

    distributions.SportStoreAccessories = {
        2, 1, 0.5
    }



    MissingSkillBooks.applyBookLoot(
        books,
        distributions,
        settings.RunningEnabled,
        settings.RunningSpawnMultiplier
    )

end

function MissingSkillBooks.addFitnessSkillBooks()

    local settings =
        SandboxVars.MissingSkillBooks

    local books =
        MissingSkillBooks.makeBookList("Fitness")

    local distributions =
        MissingSkillBooks.getStandardBookDistributions()


    distributions.BookstoreSports = {
        10, 8, 6, 4, 2
    }


    distributions.FitnessTrainer = {
        6, 4, 2, 1, 0.5
    }

    distributions.GymLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.BoxingLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.ClosetSportsEquipment = {
        6, 4, 2, 1, 0.5
    }

    distributions.CrateSports = {
        6, 4, 2, 1, 0.5
    }


    distributions.GymWeights = {
        2, 1, 0.5
    }


    distributions.CrateFitnessWeights = {
        2, 1, 0.5
    }

    distributions.SchoolGymSportsGear = {
        2, 1, 0.5
    }

    distributions.SportStoreAccessories = {
        3, 2, 1, 0.5
    }

    distributions.SportStoreSneakers = {
        3, 2, 1, 0.5
    }

    distributions.SportStorageWeights = {
        3, 2, 1, 0.5
    }

    distributions.SportStoreBoxing = {
        2, 1, 0.5
    }


    MissingSkillBooks.applyBookLoot(
        books,
        distributions,
        settings.FitnessEnabled,
        settings.FitnessSpawnMultiplier
    )

end

function MissingSkillBooks.addStrengthSkillBooks()

    local settings =
        SandboxVars.MissingSkillBooks

    local books =
        MissingSkillBooks.makeBookList("Strength")

    local distributions =
        MissingSkillBooks.getStandardBookDistributions()


    distributions.BookstoreSports = {
        10, 8, 6, 4, 2
    }


    distributions.FitnessTrainer = {
        6, 4, 2, 1, 0.5
    }

    distributions.GymLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.BoxingLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.ClosetSportsEquipment = {
        6, 4, 2, 1, 0.5
    }

    distributions.CrateSports = {
        6, 4, 2, 1, 0.5
    }


    distributions.GymWeights = {
        6, 4, 2, 1, 0.5
    }

    distributions.CrateFitnessWeights = {
        6, 4, 2, 1, 0.5
    }


    distributions.SchoolGymSportsGear = {
        2, 1, 0.5
    }


    distributions.FactoryLockers = {
        1, 0.5, 0.3
    }

    distributions.FireDeptLockers = {
        1, 0.5, 0.3
    }

    distributions.PoliceLockers = {
        1, 0.5, 0.3
    }

    distributions.SportStorageWeights = {
        3, 2, 1, 0.5
    }

    distributions.SportStoreBoxing = {
        3, 2, 1, 0.5
    }

    distributions.SportStoreAccessories = {
        2, 1, 0.5
    }


    MissingSkillBooks.applyBookLoot(
        books,
        distributions,
        settings.StrengthEnabled,
        settings.StrengthSpawnMultiplier
    )

end

function MissingSkillBooks.addLightfootedSkillBooks()

    local settings =
        SandboxVars.MissingSkillBooks

    local books =
        MissingSkillBooks.makeBookList("Lightfooted")

    local distributions =
        MissingSkillBooks.getStandardBookDistributions()


    -- Sports bookstore section
    distributions.BookstoreSports = {
        10, 8, 6, 4, 2
    }


    -- Strong thematic locations:
    -- movement technique, balance and footwork.
    distributions.GymMats = {
        3, 2, 1, 0.5
    }

    distributions.BoxingLockers = {
        3, 2, 1, 0.5
    }

    distributions.SportStoreSneakers = {
        3, 2, 1, 0.5
    }

    distributions.SportStoreBoxing = {
        3, 2, 1, 0.5
    }


    distributions.GymLockers = {
        2, 1, 0.5
    }

    distributions.FitnessTrainer = {
        2, 1, 0.5
    }

    distributions.ClosetSportsEquipment = {
        2, 1, 0.5
    }

    distributions.SchoolGymSportsGear = {
        2, 1, 0.5
    }


    distributions.SportStoreBadminton = {
        2, 1, 0.5
    }

    distributions.SportStoreTennis = {
        2, 1, 0.5
    }


    MissingSkillBooks.applyBookLoot(
        books,
        distributions,
        settings.LightfootedEnabled,
        settings.LightfootedSpawnMultiplier
    )

end

function MissingSkillBooks.addNimbleSkillBooks()

    local settings =
        SandboxVars.MissingSkillBooks

    local books =
        MissingSkillBooks.makeBookList("Nimble")

    local distributions =
        MissingSkillBooks.getStandardBookDistributions()


    distributions.BookstoreSports = {
        10, 8, 6, 4, 2
    }

    distributions.GymMats = {
        6, 4, 2, 1, 0.5
    }

    distributions.BoxingLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.SportStoreBoxing = {
        6, 4, 2, 1, 0.5
    }

    distributions.SportStoreTennis = {
        6, 4, 2, 1, 0.5
    }

    distributions.SportStoreBadminton = {
        6, 4, 2, 1, 0.5
    }


    distributions.GymLockers = {
        2, 1, 0.5
    }

    distributions.FitnessTrainer = {
        2, 1, 0.5
    }

    distributions.ClosetSportsEquipment = {
        2, 1, 0.5
    }

    distributions.SchoolGymSportsGear = {
        2, 1, 0.5
    }


    distributions.SportStoreSneakers = {
        2, 1, 0.5
    }

    distributions.PoliceLockers = {
        0.1, 0.05, 0.025
    }


    MissingSkillBooks.applyBookLoot(
        books,
        distributions,
        settings.NimbleEnabled,
        settings.NimbleSpawnMultiplier
    )

end

function MissingSkillBooks.addSneakingSkillBooks()

    local settings =
        SandboxVars.MissingSkillBooks

    local books =
        MissingSkillBooks.makeBookList("Sneaking")

    local distributions =
        MissingSkillBooks.getStandardBookDistributions()


    distributions.BookstoreOutdoors = {
        10, 8, 6, 4, 2
    }

    distributions.CampingStoreBooks = {
        6, 4, 2, 1, 0.5
    }

    distributions.RangerBooks = {
        6, 4, 2, 1, 0.5
    }


    distributions.CampingLockers = {
        2, 1, 0.5
    }

    distributions.CampingStoreGear = {
        2, 1, 0.5
    }

    distributions.HuntingLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.RangerLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.SurvivalGear = {
        2, 1, 0.5
    }

    distributions.OutdoorSupplyMagazines = {
        2, 1, 0.5
    }

    distributions.RangerMagazines = {
        2, 1, 0.5
    }


    distributions.BookstoreCrimeFiction = {
        2, 1, 0.5
    }

    distributions.BookstoreThriller = {
        2, 1, 0.5
    }

    distributions.LibraryCrimeFiction = {
        1, 0.5, 0.25
    }

    distributions.LibraryThriller = {
        1, 0.5, 0.25
    }


    distributions.PoliceLockers = {
        0.1, 0.05, 0.025
    }

    distributions.ArmyBunkerLockers = {
        0.1, 0.05, 0.025
    }

    distributions.SecurityLockers = {
        0.1, 0.05, 0.025
    }

    distributions.ArmySurplusLiterature = {
        6, 4, 2, 1, 0.5
    }


    MissingSkillBooks.applyBookLoot(
        books,
        distributions,
        settings.SneakingEnabled,
        settings.SneakingSpawnMultiplier
    )

end

function MissingSkillBooks.addAxeSkillBooks()

    local settings =
        SandboxVars.MissingSkillBooks

    local books =
        MissingSkillBooks.makeBookList("Axe")

    local distributions =
        MissingSkillBooks.getStandardBookDistributions()


    distributions.BookstoreBlueCollar = {
        10, 8, 6, 4, 2
    }

    distributions.BookstoreOutdoors = {
        10, 8, 6, 4, 2
    }


    distributions.RangerBooks = {
        10, 8, 6, 4, 2
    }

    distributions.CampingStoreBooks = {
        10, 8, 6, 4, 2
    }


    distributions.FiremanTools = {
        6, 4, 2, 1, 0.5
    }

    distributions.FireStorageTools = {
        6, 4, 2, 1, 0.5
    }

    distributions.FireDeptLockers = {
        6, 4, 2, 1, 0.5
    }


    distributions.RangerTools = {
        6, 4, 2, 1, 0.5
    }

    distributions.HuntingLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.RangerLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.CampingStoreTools = {
        2, 1, 0.5
    }

    distributions.CampingStoreGear = {
        2, 1, 0.5
    }

    distributions.SurvivalGear = {
        2, 1, 0.5
    }

    distributions.ToolStoreTools = {
        0.5, 0.25, 0.1
    }

    distributions.CrateTools = {
        0.1, 0.05, 0.025
    }

    distributions.MedievalBooks = {
        2, 1, 0.5
    }

    distributions.MedievalTools = {
        0.5, 0.25, 0.1
    }

    MissingSkillBooks.applyBookLoot(
        books,
        distributions,
        settings.AxeEnabled,
        settings.AxeSpawnMultiplier
    )

end

function MissingSkillBooks.addLongBluntSkillBooks()

    local settings =
        SandboxVars.MissingSkillBooks

    local books =
        MissingSkillBooks.makeBookList("LongBlunt")

    local distributions =
        MissingSkillBooks.getStandardBookDistributions()


    distributions.BookstoreSports = {
        10, 8, 6, 4, 2
    }


    distributions.BaseballStoreShelves = {
        10, 8, 6, 4, 2
    }


    distributions.SportStoreBaseball = {
        6, 4, 2, 1, 0.5
    }

    distributions.SportStorageBats = {
        6, 4, 2, 1, 0.5
    }


    distributions.BaseballLockers = {
        6, 4, 2, 1, 0.5
    }


    distributions.CrateSports = {
        2, 1, 0.5
    }


    distributions.BatFactoryBats = {
        0.5, 0.25, 0.1
    }


    distributions.BarCratePool = {
        2, 1, 0.5
    }


    distributions.ToolStoreTools = {
        0.5, 0.25, 0.1
    }

    distributions.ConstructionWorkerTools = {
        0.1, 0.05, 0.025
    }

    distributions.CrateTools = {
        0.1, 0.05, 0.025
    }


    MissingSkillBooks.applyBookLoot(
        books,
        distributions,
        settings.LongBluntEnabled,
        settings.LongBluntSpawnMultiplier
    )

end

function MissingSkillBooks.addShortBluntSkillBooks()

    local settings =
        SandboxVars.MissingSkillBooks

    local books =
        MissingSkillBooks.makeBookList("ShortBlunt")

    local distributions =
        MissingSkillBooks.getStandardBookDistributions()


    -- Blue-collar / trades literature
    distributions.BookstoreBlueCollar = {
        10, 8, 6, 4, 2
    }


    -- Police / security:
    -- strong thematic source because of nightsticks.
    distributions.PoliceTools = {
        6, 4, 2, 1, 0.5
    }

    distributions.PoliceStateTools = {
        6, 4, 2, 1, 0.5
    }

    distributions.PoliceLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.SecurityStorage = {
        6, 4, 2, 1, 0.5
    }

    distributions.SecurityLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.PrisonGuardLockers = {
        6, 4, 2, 1, 0.5
    }


    -- Riot storage is highly relevant to blunt weapons,
    -- but not really a literature location.
    distributions.PrisonRiotStorage = {
        2, 1, 0.5
    }


    -- Construction / carpentry:
    -- hammers are among the most common Short Blunt tools.
    distributions.ConstructionWorkerTools = {
        2, 1, 0.5
    }

    distributions.ToolStoreCarpentry = {
        2, 1, 0.5
    }

    distributions.CrateCarpentry = {
        2, 1, 0.5
    }


    -- Metalworking / workshop tools:
    -- ball-peen and club hammers fit especially well.
    distributions.MetalWorkerTools = {
        2, 1, 0.5
    }

    distributions.ToolStoreMetalwork = {
        2, 1, 0.5
    }

    distributions.CrateMetalwork = {
        2, 1, 0.5
    }


    -- General tool storage.
    distributions.ToolStoreTools = {
        0.5, 0.25, 0.1
    }

    distributions.CrateTools = {
        0.1, 0.05, 0.025
    }

    distributions.GarageTools = {
        0.1, 0.05, 0.025
    }


    MissingSkillBooks.applyBookLoot(
        books,
        distributions,
        settings.ShortBluntEnabled,
        settings.ShortBluntSpawnMultiplier
    )

end

function MissingSkillBooks.addShortBladeSkillBooks()

    local settings =
        SandboxVars.MissingSkillBooks

    local books =
        MissingSkillBooks.makeBookList("ShortBlade")

    local distributions =
        MissingSkillBooks.getStandardBookDistributions()


    -- Outdoors / survival literature
    distributions.BookstoreOutdoors = {
        10, 8, 6, 4, 2
    }

    distributions.CampingStoreBooks = {
        10, 8, 6, 4, 2
    }

    distributions.RangerBooks = {
        6, 4, 2, 1, 0.5
    }

    distributions.ArmySurplusLiterature = {
        6, 4, 2, 1, 0.5
    }


    -- Hunting / survival equipment
    distributions.HuntingLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.RangerLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.CampingStoreTools = {
        2, 1, 0.5
    }


    -- Dedicated knife retail.
    distributions.GunStoreKnives = {
        6, 4, 2, 1, 0.5
    }

    distributions.PawnShopKnives = {
        6, 4, 2, 1, 0.5
    }

    distributions.KnifeStoreCutlery = {
        6, 4, 2, 1, 0.5
    }


    -- Cooking / butchery.
    distributions.ButcherTools = {
        2, 1, 0.5
    }

    distributions.ChefTools = {
        2, 1, 0.5
    }


    -- Fishing / fillet knives.
    distributions.FishingLockers = {
        2, 1, 0.5
    }

    distributions.FishermanTools = {
        2, 1, 0.5
    }

    distributions.FishingStoreGear = {
        2, 1, 0.5
    }


    distributions.PrisonCellRandom = {
        0.25, 0.1, 0.05
    }

    distributions.PrisonCellRandomClassy = {
        0.25, 0.1, 0.05
    }

    distributions.DerelictHouseCrime = {
        0.25, 0.1, 0.05
    }

    distributions.DrugShackWeapons = {
        0.25, 0.1, 0.05
    }


    MissingSkillBooks.applyBookLoot(
        books,
        distributions,
        settings.ShortBladeEnabled,
        settings.ShortBladeSpawnMultiplier
    )

end

function MissingSkillBooks.addSpearSkillBooks()

    local settings =
        SandboxVars.MissingSkillBooks

    local books =
        MissingSkillBooks.makeBookList("Spear")

    local distributions =
        MissingSkillBooks.getStandardBookDistributions()


    -- Outdoor / survival literature
    distributions.BookstoreOutdoors = {
        10, 8, 6, 4, 2
    }

    distributions.LibraryOutdoors = {
        8, 6, 4, 2, 1
    }

    distributions.CampingStoreBooks = {
        10, 8, 6, 4, 2
    }

    distributions.RangerBooks = {
        6, 4, 2, 1, 0.5
    }


    -- Hunting / ranger contexts
    distributions.HuntingLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.RangerLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.RangerTools = {
        6, 4, 2, 1, 0.5
    }


    -- Fishing:
    -- very strong thematic fit because crafted spears
    -- can be used as fishing spears.
    distributions.FishermanTools = {
        6, 4, 2, 1, 0.5
    }

    distributions.FishingLockers = {
        6, 4, 2, 1, 0.5
    }

    distributions.FishingStoreGear = {
        6, 4, 2, 1, 0.5
    }

    distributions.CrateFishing = {
        2, 1, 0.5
    }


    -- General survival / camping gear
    distributions.CampingStoreTools = {
        2, 1, 0.5
    }

    distributions.CampingStoreGear = {
        2, 1, 0.5
    }

    distributions.SurvivalGear = {
        2, 1, 0.5
    }


    -- Primitive / historical interest.
    distributions.AnthropologyBooks = {
        2, 1, 0.5
    }

    distributions.MedievalBooks = {
        2, 1, 0.5
    }

    distributions.AnthropologyDisplayTools = {
        0.5, 0.25, 0.1
    }

    distributions.MedievalTools = {
        0.5, 0.25, 0.1
    }


    MissingSkillBooks.applyBookLoot(
        books,
        distributions,
        settings.SpearEnabled,
        settings.SpearSpawnMultiplier
    )

end