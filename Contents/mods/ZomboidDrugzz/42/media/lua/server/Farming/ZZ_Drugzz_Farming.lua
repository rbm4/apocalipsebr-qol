require "Farming/farming_vegetableconf"
require "Farming/farming_vegetableconf_vegetables"
require "Farming/farming_vegetableconf_vegetables_sprites"

local function copySprites(source)
    local result = {}
    for index, sprite in ipairs(source or {}) do
        result[index] = sprite
    end
    return result
end

farming_vegetableconf.props.Cannabis = {
    icon = "Item_DrugzzCannabisHarvest",
    texture = "vegetation_farming_01b_22",
    waterLvl = 40,
    waterNeeded = 65,
    timeToGrow = 288,
    rotTime = 588,
    minVeg = 2,
    maxVeg = 4,
    minVegAutorized = 4,
    maxVegAutorized = 7,
    vegetableName = "ZDrugzz.CannabisHarvest",
    seedName = "ZDrugzz.CannabisSeeds",
    seedTypes = { "ZDrugzz.CannabisSeeds" },
    seedPerVeg = 1.5,
    harvestLevel = 5,
    mature = 5,
    fullGrown = 6,
    badMonth = { 11, 12, 1, 2 },
    sowMonth = { 3, 4, 5, 6, 7, 8 },
    bestMonth = { 4, 5, 6 },
    riskMonth = { 8 },
    seasonRecipe = "Drugzz_TrimCannabis",
    harvestPosition = "High",
    mothFood = true,
}

-- Cannabis is its own crop and item chain. Reusing the compatible B42
-- broadleaf crop tiles keeps it stable without replacing vanilla hemp.
farming_vegetableconf.sprite.Cannabis =
    copySprites(farming_vegetableconf.sprite.Hemp)
farming_vegetableconf.unhealthySprite.Cannabis =
    copySprites(farming_vegetableconf.unhealthySprite.Hemp)
farming_vegetableconf.dyingSprite.Cannabis =
    copySprites(farming_vegetableconf.dyingSprite.Hemp)
farming_vegetableconf.deadSprite.Cannabis =
    copySprites(farming_vegetableconf.deadSprite.Hemp)
farming_vegetableconf.trampledSprite.Cannabis =
    copySprites(farming_vegetableconf.trampledSprite.Hemp)

local strains = {
    { id = "SourDiesel", crop = "CannabisSourDiesel", water = 70, grow = 276, yieldMin = 2, yieldMax = 5 },
    { id = "DurbanPoison", crop = "CannabisDurbanPoison", water = 62, grow = 264, yieldMin = 2, yieldMax = 5 },
    { id = "JackHerer", crop = "CannabisJackHerer", water = 66, grow = 276, yieldMin = 2, yieldMax = 5 },
    { id = "NorthernLights", crop = "CannabisNorthernLights", water = 58, grow = 300, yieldMin = 3, yieldMax = 6 },
    { id = "GranddaddyPurple", crop = "CannabisGranddaddyPurple", water = 60, grow = 312, yieldMin = 3, yieldMax = 6 },
    { id = "BubbaKush", crop = "CannabisBubbaKush", water = 58, grow = 306, yieldMin = 3, yieldMax = 6 },
    { id = "OGKush", crop = "CannabisOGKush", water = 64, grow = 294, yieldMin = 3, yieldMax = 6 },
    { id = "WhiteWidow", crop = "CannabisWhiteWidow", water = 65, grow = 288, yieldMin = 3, yieldMax = 6 },
    { id = "BlueDream", crop = "CannabisBlueDream", water = 68, grow = 282, yieldMin = 3, yieldMax = 6 },
    { id = "GSC", crop = "CannabisGSC", water = 63, grow = 300, yieldMin = 3, yieldMax = 6 },
}

for _, strain in ipairs(strains) do
    farming_vegetableconf.props[strain.crop] = {
        icon = "Item_Drugzz" .. strain.id .. "Harvest",
        texture = "vegetation_farming_01b_22",
        waterLvl = 40,
        waterNeeded = strain.water,
        timeToGrow = strain.grow,
        rotTime = 588,
        minVeg = strain.yieldMin,
        maxVeg = strain.yieldMax,
        minVegAutorized = strain.yieldMax,
        maxVegAutorized = strain.yieldMax + 3,
        vegetableName = "ZDrugzz." .. strain.id .. "Harvest",
        seedName = "ZDrugzz." .. strain.id .. "Seeds",
        seedTypes = { "ZDrugzz." .. strain.id .. "Seeds" },
        seedPerVeg = 1.4,
        harvestLevel = 5,
        mature = 5,
        fullGrown = 6,
        badMonth = { 11, 12, 1, 2 },
        sowMonth = { 3, 4, 5, 6, 7, 8 },
        bestMonth = { 4, 5, 6 },
        riskMonth = { 8 },
        seasonRecipe = "Drugzz_Cure" .. strain.id,
        harvestPosition = "High",
        mothFood = true,
    }

    farming_vegetableconf.sprite[strain.crop] =
        copySprites(farming_vegetableconf.sprite.Cannabis)
    farming_vegetableconf.unhealthySprite[strain.crop] =
        copySprites(farming_vegetableconf.unhealthySprite.Cannabis)
    farming_vegetableconf.dyingSprite[strain.crop] =
        copySprites(farming_vegetableconf.dyingSprite.Cannabis)
    farming_vegetableconf.deadSprite[strain.crop] =
        copySprites(farming_vegetableconf.deadSprite.Cannabis)
    farming_vegetableconf.trampledSprite[strain.crop] =
        copySprites(farming_vegetableconf.trampledSprite.Cannabis)
end
