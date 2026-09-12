ResidentEvilHunters = ResidentEvilHunters or {}

ResidentEvilHunters.Config = {
    PackMinSize = 1,
    PackMaxSize = 3,
    PackRadius = 8.0,
    PendingPackCreateEvents = 20,

    ModDataKey = "ResidentEvilHunters_IsHunter",
    VariantDataKey = "ResidentEvilHunters_Variant",
    BodyLocation = "base:fullsuit",

    WalkType = "sprint1",

    HealthMultiplier = 3.0,

    Variants = {
        {
            id = "Beta",
            weight = 50,
            visualItemType = "ResidentEvilHunters.HunterBetaBody",
        },
        {
            id = "Alpha",
            weight = 50,
            visualItemType = "ResidentEvilHunters.HunterAlphaBody",
        },
        {
            id = "Gamma",
            weight = 50,
            visualItemType = "ResidentEvilHunters.HunterGammaBody",
        },
    },

    VisualRetryCount = 4,
    VisualRetryEveryUpdates = 30,
    DebugLogging = false,
}
