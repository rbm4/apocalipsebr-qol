require "Drugzz_Core"

local starterProfiles = {
    CANNABIS_CONNOISSEUR = {
        family = "cannabis",
        uses = 6,
        tolerance = 1.5,
        dependence = 0,
        lastUseAgo = 36,
        items = {
            "ZDrugzz.CannabisCultureManual",
            "ZDrugzz.OGKushSeeds",
            "ZDrugzz.NorthernLightsSeeds",
            "ZDrugzz.SourDieselSeeds",
        },
    },
    STONER = {
        family = "cannabis",
        uses = 18,
        tolerance = 4.0,
        dependence = 0.60,
        lastUseAgo = 10,
        recipes = {
            "Drugzz_GrindCannabis",
            "Drugzz_RollJoint",
            "Drugzz_RollBlunt",
        },
        items = {
            "ZDrugzz.Joint",
            "ZDrugzz.Joint",
            "Base.LighterDisposable",
        },
    },
    PSYCHONAUT = {
        family = "psychedelic",
        uses = 4,
        tolerance = 1.0,
        dependence = 0,
        lastUseAgo = 48,
        items = {
            "ZDrugzz.MagicMushroomDried",
            "ZDrugzz.LSDTab",
        },
    },
    COCAINE_DEPENDENT = {
        family = "cocaine",
        uses = 28,
        tolerance = 5.0,
        dependence = 0.78,
        lastUseAgo = 5,
        items = {
            "ZDrugzz.CocaineBaggie",
        },
    },
    CRACK_DEPENDENT = {
        family = "crack",
        uses = 34,
        tolerance = 6.0,
        dependence = 0.90,
        lastUseAgo = 3,
        recipes = {
            "Drugzz_LoadCrackPipe",
        },
        items = {
            "ZDrugzz.GlassPipe",
            "ZDrugzz.CrackRock",
            "ZDrugzz.CrackRock",
            "Base.LighterDisposable",
        },
    },
    METH_DEPENDENT = {
        family = "meth",
        uses = 36,
        tolerance = 6.0,
        dependence = 0.92,
        lastUseAgo = 6,
        recipes = {
            "Drugzz_LoadMethPipe",
        },
        items = {
            "ZDrugzz.MethBaggie",
            "ZDrugzz.GlassPipe",
            "Base.LighterDisposable",
        },
    },
    CLUB_REGULAR = {
        family = "mdma",
        uses = 16,
        tolerance = 3.0,
        dependence = 0.48,
        lastUseAgo = 16,
        items = {
            "ZDrugzz.MollyCapsule",
            "ZDrugzz.EcstasyTablet",
            "Base.WaterBottle",
        },
    },
    PRESCRIPTION_DEPENDENT = {
        family = "prescription",
        uses = 22,
        tolerance = 4.0,
        dependence = 0.65,
        lastUseAgo = 8,
        items = {
            "ZDrugzz.AdderallBottle",
        },
    },
}

local dealerStarterItems = {
    "ZDrugzz.GrowersHandbook",
    "ZDrugzz.StreetChemistryReport",
    "ZDrugzz.CannabisCultureManual",
    "ZDrugzz.OGKushSeeds",
    "ZDrugzz.Joint",
    "ZDrugzz.Joint",
    "ZDrugzz.CocaineBaggie",
    "ZDrugzz.MollyCapsule",
    "ZDrugzz.EmptyBaggie",
    "ZDrugzz.EmptyBaggie",
    "ZDrugzz.EmptyBaggie",
    "ZDrugzz.EmptyBaggie",
    "Base.LighterDisposable",
}

local recipePublications = {
    "ZDrugzz.GrowersHandbook",
    "ZDrugzz.StreetChemistryReport",
    "ZDrugzz.CultivatorsAlmanac",
    "ZDrugzz.CannabisKitchenCookbook",
    "ZDrugzz.ConcentrateExtractionManual",
    "ZDrugzz.RigServiceManual",
    "ZDrugzz.ControlledBotanicalsNotes",
    "ZDrugzz.CannabisCultureManual",
}

local function learnIfMissing(player, recipe)
    if not player or not recipe then
        return
    end

    local knownRecipes = player:getKnownRecipes()
    if not knownRecipes or not knownRecipes:contains(recipe) then
        player:learnRecipe(recipe)
    end
end

local function repairLegacyRecipeKnowledge(player)
    if not player then
        return
    end

    local knownRecipes = player:getKnownRecipes()
    if knownRecipes then
        local legacyRecipes = {}
        for index = 0, knownRecipes:size() - 1 do
            local recipe = tostring(knownRecipes:get(index))
            local plainRecipe = string.match(recipe, "^ZDrugzz:(Drugzz_.+)$")
            if plainRecipe and getScriptManager():getCraftRecipe(plainRecipe) then
                table.insert(legacyRecipes, plainRecipe)
            end
        end
        for _, recipe in ipairs(legacyRecipes) do
            learnIfMissing(player, recipe)
        end
    end

    local alreadyRead = player:getAlreadyReadBook()
    if not alreadyRead then
        return
    end

    for _, fullType in ipairs(recipePublications) do
        if alreadyRead:contains(fullType) then
            local scriptItem = getScriptManager():FindItem(fullType)
            local learnedRecipes = scriptItem and scriptItem:getLearnedRecipes() or nil
            if learnedRecipes then
                for index = 0, learnedRecipes:size() - 1 do
                    learnIfMissing(player, learnedRecipes:get(index))
                end
            end
        end
    end
end

local function learnTraitRecipes(player)
    if not player then
        return
    end

    for traitKey, profile in pairs(starterProfiles) do
        if profile.recipes and Drugzz.hasTrait(player, traitKey) then
            for _, recipe in ipairs(profile.recipes) do
                learnIfMissing(player, recipe)
            end
        end
    end
end

local function initializeTraitStart(player)
    if not player then
        return
    end

    learnTraitRecipes(player)

    if isClient() then
        return
    end

    local state = Drugzz.getState(player)
    if not state then
        return
    end

    local now = Drugzz.getWorldHours()
    local inventory = player:getInventory()
    local grantItems = Drugzz.getOption("EnableTraitStarterItems", true)

    if not state.traitStartInitialized then
        for traitKey, profile in pairs(starterProfiles) do
            if Drugzz.hasTrait(player, traitKey) then
                local familyState = Drugzz.getFamilyState(state, profile.family, now)
                familyState.uses = math.max(familyState.uses or 0, profile.uses)
                familyState.tolerance = math.max(familyState.tolerance or 0, profile.tolerance)
                familyState.dependence = math.max(familyState.dependence or 0, profile.dependence)
                familyState.lastUseHour = now - profile.lastUseAgo

                if grantItems and inventory then
                    for _, fullType in ipairs(profile.items) do
                        inventory:AddItem(fullType)
                    end
                end
            end
        end
        state.traitStartInitialized = true
    end

    if Drugzz.hasProfession(player) and not state.dealerStartInitialized then
        if grantItems and inventory then
            for _, fullType in ipairs(dealerStarterItems) do
                inventory:AddItem(fullType)
            end
        end
        state.dealerStartInitialized = true
    end

    Drugzz.syncState(player, state, true)
end

local function onCreatePlayer(playerNum, player)
    local character = player
    if not character and getSpecificPlayer then
        character = getSpecificPlayer(playerNum)
    end
    repairLegacyRecipeKnowledge(character)
    learnTraitRecipes(character)
    if not isClient() then
        initializeTraitStart(character)
    end
end

Events.OnNewGame.Add(initializeTraitStart)
Events.OnCreatePlayer.Add(onCreatePlayer)
