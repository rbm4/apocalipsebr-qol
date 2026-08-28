---@class BicycleSidecarAnimal
local SidecarAnimal = {}

SidecarAnimal.BACKREF_MODDATA_KEY = "BicycleSidecarAnimalItemId"

---@type table<string, boolean>
SidecarAnimal.ALLOWED_ANIMAL_TYPES = {
    chick = true,
    hen = true,
    cockerel = true,
    raccoonkit = true,
    raccoonsow = true,
    raccoonboar = true,
    lamb = true,
    piglet = true,
    filly = true,
    mare = true,
    stallion = true,
    rabkitten = true,
    rabdoe = true,
    rabbuck = true,
    turkeypoult = true,
    turkeyhen = true,
    gobblers = true,
}

---@type table<string, string>
SidecarAnimal.SPECIES_PART_TYPE = {
    chick = "SidecarChick",
    hen = "SidecarChicken",
    cockerel = "SidecarChicken",
    raccoonkit = "SidecarRaccoonKit",
    raccoonsow = "SidecarRaccoon",
    raccoonboar = "SidecarRaccoon",
    lamb = "SidecarLamb",
    piglet = "SidecarPiglet",
    filly = "SidecarHorseFoal",
    mare = "SidecarHorse",
    stallion = "SidecarHorse",
    rabkitten = "SidecarRabbitKitten",
    rabdoe = "SidecarRabbit",
    rabbuck = "SidecarRabbit",
    turkeypoult = "SidecarTurkeyPoult",
    turkeyhen = "SidecarTurkey",
    gobblers = "SidecarTurkey",
}

---@type table<string, boolean>
SidecarAnimal.ANIMAL_PART_TYPES = {
    SidecarChicken = true,
    SidecarChick = true,
    SidecarRaccoon = true,
    SidecarRaccoonKit = true,
    SidecarLamb = true,
    SidecarPiglet = true,
    SidecarHorse = true,
    SidecarHorseFoal = true,
    SidecarRabbit = true,
    SidecarRabbitKitten = true,
    SidecarTurkey = true,
    SidecarTurkeyPoult = true,
}

---@type string[]
SidecarAnimal.ANIMAL_PART_TYPE_LIST = {
    "SidecarChicken",
    "SidecarChick",
    "SidecarRaccoon",
    "SidecarRaccoonKit",
    "SidecarLamb",
    "SidecarPiglet",
    "SidecarHorse",
    "SidecarHorseFoal",
    "SidecarRabbit",
    "SidecarRabbitKitten",
    "SidecarTurkey",
    "SidecarTurkeyPoult",
}

-- Variant fullType per (animalType, breed.name). Multiple variants share a
-- partType (one slot, many visual options) — same pattern as the colored
-- Sidecar variants. Breed names come from the vanilla AnimalDefinitions files.
---@type table<string, table<string, string>>
SidecarAnimal.VARIANT_BY_TYPE_BREED = {
    chick = {
        rhodeisland = "Bicycle.ChickInSidecar",
        leghorn = "Bicycle.ChickInSidecar",
    },
    hen = {
        rhodeisland = "Bicycle.ChickenBrownInSidecar",
        leghorn = "Bicycle.ChickenWhiteInSidecar",
    },
    cockerel = {
        rhodeisland = "Bicycle.CockerelBrownInSidecar",
        leghorn = "Bicycle.CockerelWhiteInSidecar",
    },
    raccoonkit = { grey = "Bicycle.RaccoonKitInSidecar" },
    raccoonsow = { grey = "Bicycle.RaccoonInSidecar" },
    raccoonboar = { grey = "Bicycle.RaccoonInSidecar" },
    lamb = {
        suffolk = "Bicycle.LambBrownInSidecar",
        rambouillet = "Bicycle.LambWhiteInSidecar",
        friesian = "Bicycle.LambWhiteInSidecar",
    },
    piglet = {
        landrace = "Bicycle.PigletPinkInSidecar",
        largeblack = "Bicycle.PigletBlackInSidecar",
    },
    -- Horses: HorseMod defines 8 breeds. Texture is the same across age/sex
    -- per breed, so filly/mare/stallion all map to the same variant by breed.
    filly = {
        AmericanQuarterPalomino = "Bicycle.HorseAmericanQuarterPalominoFoalInSidecar",
        AmericanQuarterBlueRoan = "Bicycle.HorseAmericanQuarterBlueRoanFoalInSidecar",
        AmericanPaintTobiano = "Bicycle.HorseAmericanPaintTobianoFoalInSidecar",
        AmericanPaintOvero = "Bicycle.HorseAmericanPaintOveroFoalInSidecar",
        AppaloosaGrullaBlanket = "Bicycle.HorseAppaloosaGrullaBlanketFoalInSidecar",
        AppaloosaLeopard = "Bicycle.HorseAppaloosaLeopardFoalInSidecar",
        ThoroughbredBay = "Bicycle.HorseThoroughbredBayFoalInSidecar",
        ThoroughbredFleaBittenGrey = "Bicycle.HorseThoroughbredFleaBittenGreyFoalInSidecar",
    },
    mare = {
        AmericanQuarterPalomino = "Bicycle.HorseAmericanQuarterPalominoInSidecar",
        AmericanQuarterBlueRoan = "Bicycle.HorseAmericanQuarterBlueRoanInSidecar",
        AmericanPaintTobiano = "Bicycle.HorseAmericanPaintTobianoInSidecar",
        AmericanPaintOvero = "Bicycle.HorseAmericanPaintOveroInSidecar",
        AppaloosaGrullaBlanket = "Bicycle.HorseAppaloosaGrullaBlanketInSidecar",
        AppaloosaLeopard = "Bicycle.HorseAppaloosaLeopardInSidecar",
        ThoroughbredBay = "Bicycle.HorseThoroughbredBayInSidecar",
        ThoroughbredFleaBittenGrey = "Bicycle.HorseThoroughbredFleaBittenGreyInSidecar",
    },
    stallion = {
        AmericanQuarterPalomino = "Bicycle.HorseAmericanQuarterPalominoInSidecar",
        AmericanQuarterBlueRoan = "Bicycle.HorseAmericanQuarterBlueRoanInSidecar",
        AmericanPaintTobiano = "Bicycle.HorseAmericanPaintTobianoInSidecar",
        AmericanPaintOvero = "Bicycle.HorseAmericanPaintOveroInSidecar",
        AppaloosaGrullaBlanket = "Bicycle.HorseAppaloosaGrullaBlanketInSidecar",
        AppaloosaLeopard = "Bicycle.HorseAppaloosaLeopardInSidecar",
        ThoroughbredBay = "Bicycle.HorseThoroughbredBayInSidecar",
        ThoroughbredFleaBittenGrey = "Bicycle.HorseThoroughbredFleaBittenGreyInSidecar",
    },
    -- Rabbits: kittens use the Rabbit_Kitten_<breed> texture, adults use
    -- Rabbit_<breed>. Same mesh shared across age and sex.
    rabkitten = {
        swamp = "Bicycle.RabbitKittenSwampInSidecar",
        appalachian = "Bicycle.RabbitKittenAppalachianInSidecar",
        cottontail = "Bicycle.RabbitKittenCottontailInSidecar",
    },
    rabdoe = {
        swamp = "Bicycle.RabbitSwampInSidecar",
        appalachian = "Bicycle.RabbitAppalachianInSidecar",
        cottontail = "Bicycle.RabbitCottontailInSidecar",
    },
    rabbuck = {
        swamp = "Bicycle.RabbitSwampInSidecar",
        appalachian = "Bicycle.RabbitAppalachianInSidecar",
        cottontail = "Bicycle.RabbitCottontailInSidecar",
    },
    -- Turkeys: one breed (meleagris); 3 textures (Poult / Hen / male = Turkey).
    turkeypoult = {
        meleagris = "Bicycle.TurkeyPoultInSidecar",
    },
    turkeyhen = {
        meleagris = "Bicycle.TurkeyHenInSidecar",
    },
    gobblers = {
        meleagris = "Bicycle.TurkeyGobblerInSidecar",
    },
}

-- Fallback variant if the breed is unrecognized (e.g., a future PZ patch adds a
-- new breed). The species slot is still correct, the visual is just the
-- default for that species.
---@type table<string, string>
SidecarAnimal.DEFAULT_VARIANT_BY_TYPE = {
    chick = "Bicycle.ChickInSidecar",
    hen = "Bicycle.ChickenBrownInSidecar",
    cockerel = "Bicycle.CockerelBrownInSidecar",
    raccoonkit = "Bicycle.RaccoonKitInSidecar",
    raccoonsow = "Bicycle.RaccoonInSidecar",
    raccoonboar = "Bicycle.RaccoonInSidecar",
    lamb = "Bicycle.LambBrownInSidecar",
    piglet = "Bicycle.PigletPinkInSidecar",
    filly = "Bicycle.HorseAmericanQuarterPalominoFoalInSidecar",
    mare = "Bicycle.HorseAmericanQuarterPalominoInSidecar",
    stallion = "Bicycle.HorseAmericanQuarterPalominoInSidecar",
    rabkitten = "Bicycle.RabbitKittenSwampInSidecar",
    rabdoe = "Bicycle.RabbitSwampInSidecar",
    rabbuck = "Bicycle.RabbitSwampInSidecar",
    turkeypoult = "Bicycle.TurkeyPoultInSidecar",
    turkeyhen = "Bicycle.TurkeyHenInSidecar",
    gobblers = "Bicycle.TurkeyGobblerInSidecar",
}

---@param item InventoryItem|nil
---@return boolean
---@nodiscard
function SidecarAnimal.isAnimalItem(item)
    if not item then
        return false
    end
    return instanceof(item, "AnimalInventoryItem")
end

---@param animalItem InventoryItem|nil
---@return string|nil
---@nodiscard
function SidecarAnimal.getAnimalTypeFromItem(animalItem)
    if not SidecarAnimal.isAnimalItem(animalItem) then
        return nil
    end
    local animal = animalItem:getAnimal()
    if not animal then
        return nil
    end
    return animal:getAnimalType()
end

---@param animalType string|nil
---@return boolean
---@nodiscard
function SidecarAnimal.isAllowedAnimalType(animalType)
    if not animalType then
        return false
    end
    return SidecarAnimal.ALLOWED_ANIMAL_TYPES[animalType] == true
end

---@param item InventoryItem|nil
---@return boolean
---@nodiscard
function SidecarAnimal.isAllowedAnimalItem(item)
    if not SidecarAnimal.isAnimalItem(item) then
        return false
    end
    local animalType = SidecarAnimal.getAnimalTypeFromItem(item)
    return SidecarAnimal.isAllowedAnimalType(animalType)
end

---@param animalType string|nil
---@return string|nil
---@nodiscard
function SidecarAnimal.getPartTypeForAnimalType(animalType)
    if not animalType then
        return nil
    end
    return SidecarAnimal.SPECIES_PART_TYPE[animalType]
end

---@param animalType string|nil
---@param breedName string|nil
---@return string|nil
---@nodiscard
function SidecarAnimal.getVariantFullType(animalType, breedName)
    if not animalType then
        return nil
    end
    local breedMap = SidecarAnimal.VARIANT_BY_TYPE_BREED[animalType]
    if breedMap and breedName then
        local variant = breedMap[breedName]
        if variant then
            return variant
        end
    end
    return SidecarAnimal.DEFAULT_VARIANT_BY_TYPE[animalType]
end

---@param animal IsoAnimal|nil
---@return string|nil
---@nodiscard
function SidecarAnimal.getFullTypeForAnimal(animal)
    if not animal then
        return nil
    end
    local animalType = animal:getAnimalType()
    local breed = animal:getBreed()
    local breedName = breed and breed.name or nil
    return SidecarAnimal.getVariantFullType(animalType, breedName)
end

---@param partType string|nil
---@return boolean
---@nodiscard
function SidecarAnimal.isAnimalPartType(partType)
    if not partType then
        return false
    end
    return SidecarAnimal.ANIMAL_PART_TYPES[partType] == true
end

---@param bikeItem InventoryItem|nil
---@return boolean
---@nodiscard
function SidecarAnimal.bikeHasAnyAnimalPart(bikeItem)
    if not (bikeItem and bikeItem.getWeaponPart) then
        return false
    end
    for i = 1, #SidecarAnimal.ANIMAL_PART_TYPE_LIST do
        if bikeItem:getWeaponPart(SidecarAnimal.ANIMAL_PART_TYPE_LIST[i]) then
            return true
        end
    end
    return false
end

---@param bikeItem InventoryItem|nil
---@return InventoryItem|nil
---@nodiscard
function SidecarAnimal.getAttachedAnimalPart(bikeItem)
    if not (bikeItem and bikeItem.getWeaponPart) then
        return nil
    end
    for i = 1, #SidecarAnimal.ANIMAL_PART_TYPE_LIST do
        local part = bikeItem:getWeaponPart(SidecarAnimal.ANIMAL_PART_TYPE_LIST[i])
        if part then
            return part
        end
    end
    return nil
end

---@param sidecarContainerItem InventoryItem|nil
---@return InventoryItem|nil
---@nodiscard
function SidecarAnimal.findStoredAnimalItem(sidecarContainerItem)
    if not (sidecarContainerItem and sidecarContainerItem.getItemContainer) then
        return nil
    end
    local inventory = sidecarContainerItem:getItemContainer()
    if not inventory then
        return nil
    end
    local items = inventory:getItems()
    if not items then
        return nil
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if SidecarAnimal.isAnimalItem(item) then
            return item
        end
    end
    return nil
end

return SidecarAnimal
