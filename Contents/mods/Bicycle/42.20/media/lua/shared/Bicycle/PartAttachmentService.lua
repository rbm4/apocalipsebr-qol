require("Bicycle/BicycleCore")

local AttachmentActionUtils = require("Bicycle/AttachmentActionUtils")
local BicycleContainers = require("Bicycle/Containers")
local BicycleDebug = require("Bicycle/Debug")
local BicycleUtils = require("Bicycle/Utils")
local BicycleVanillaPartMapping = require("Bicycle/VanillaPartMapping")
local SidecarAnimal = require("Bicycle/SidecarAnimal")

local BicycleContainerManager = nil
if isClient() then
    BicycleContainerManager = nil
elseif isServer() then
    BicycleContainerManager = require("Bicycle/BicycleContainerManager")
else
    BicycleContainerManager = require("Bicycle/BicycleContainerManager")
end

---@class BicyclePartAttachmentService
local Service = {}

Service.SourceModePart = "part"
Service.SourceModeVanilla = "vanilla"
Service.SourceModeTapedFlashlight = "tapedFlashlight"
Service.DuctTapeUsage = 0.1

local HAND_TORCH_FULL_TYPE = "Base.HandTorch"
local CRAFTED_FLASHLIGHT_FULL_TYPE = "Base.Flashlight_Crafted"
local DUCT_TAPE_FULL_TYPE = "Base.DuctTape"
local TAPED_FLASHLIGHT_FULL_TYPE = "Bicycle.Bicycle_TapedFlashlight"
local TAPED_IMPROVISED_FLASHLIGHT_FULL_TYPE = "Bicycle.Bicycle_TapedImprovisedFlashlight"
local SPORTS_BOTTLE_WATER_KEY = "BicycleSportsbottleWater"
local VANILLA_SOURCE_TYPE_KEY = "BicycleVanillaSourceType"
local VANILLA_SOURCE_ID_KEY = "BicycleVanillaSourceID"

---@type table<string, boolean>
local ALLOWED_PART_TYPES = {
    Basket = true,
    Bell = true,
    BottleHolder = true,
    Chain = true,
    Crate = true,
    FrontWheel = true,
    KickstandDown = true,
    KickstandUp = true,
    Lamp = true,
    Pedals = true,
    PlasticBagLeft = true,
    PlasticBagRight = true,
    RearWheel = true,
    Saddlebag = true,
    Sidecar = true,
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
    Sportsbottle = true,
    TapedFlashlight = true,
    Toolbox = true,
}

---@type table<string, boolean>
local WHEEL_PART_TYPES = {
    FrontWheel = true,
    RearWheel = true,
}

---@param partType string|nil
---@return boolean
---@nodiscard
function Service.isAllowedPartType(partType)
    if not partType then
        return false
    end
    return ALLOWED_PART_TYPES[partType] == true
end

---@param partType string|nil
---@return boolean
---@nodiscard
function Service.isWheelPartType(partType)
    if not partType then
        return false
    end
    return WHEEL_PART_TYPES[partType] == true
end

---@param bikeItem InventoryItem|nil
---@param partType string|nil
---@return boolean
---@nodiscard
local function bikeHasPart(bikeItem, partType)
    if not (bikeItem and bikeItem.getWeaponPart and partType) then
        return false
    end
    return bikeItem:getWeaponPart(partType) ~= nil
end

---@param item InventoryItem|nil
---@return string|nil
---@nodiscard
local function getItemFullType(item)
    if not (item and item.getFullType) then
        return nil
    end
    return item:getFullType()
end

---@param item InventoryItem|nil
---@return string|nil
---@nodiscard
local function getItemPartType(item)
    if not (item and item.getPartType) then
        return nil
    end
    return item:getPartType()
end

---@param inventory ItemContainer|nil
---@param item InventoryItem|nil
---@return boolean
---@nodiscard
local function inventoryContainsItem(inventory, item)
    if not (inventory and item) then
        return false
    end
    if item.getID and inventory.containsID then
        return inventory:containsID(item:getID())
    end
    return inventory:contains(item)
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param item InventoryItem|nil
---@return boolean
---@nodiscard
local function characterOwnsItem(character, item)
    if not (character and item) then
        return false
    end
    return inventoryContainsItem(character:getInventory(), item)
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@return boolean
---@nodiscard
function Service.canAccessBike(character, bikeItem)
    if not (character and bikeItem and BicycleUtils.isBicycleItem(bikeItem)) then
        return false
    end
    return AttachmentActionUtils.isBikeInInventory(character, bikeItem)
        or AttachmentActionUtils.isWorldBikeReachable(character, bikeItem)
end

---@param sourceItem InventoryItem|nil
---@return string|nil
---@nodiscard
function Service.getTapedFlashlightPartFullType(sourceItem)
    local fullType = getItemFullType(sourceItem)
    if fullType == HAND_TORCH_FULL_TYPE then
        return TAPED_FLASHLIGHT_FULL_TYPE
    end
    if fullType == CRAFTED_FLASHLIGHT_FULL_TYPE then
        return TAPED_IMPROVISED_FLASHLIGHT_FULL_TYPE
    end
    return nil
end

---@param inventory ItemContainer|nil
---@return InventoryItem|nil
---@nodiscard
function Service.findDuctTapeWithCharges(inventory)
    if not inventory then
        return nil
    end
    local ductTape = inventory:getFirstTypeRecurse(DUCT_TAPE_FULL_TYPE)
    if ductTape and ductTape.getCurrentUsesFloat and ductTape:getCurrentUsesFloat() >= Service.DuctTapeUsage then
        return ductTape
    end
    return nil
end

---@param bikeItem InventoryItem|nil
---@param sourceItem InventoryItem|nil
---@param fallbackPartType string|nil
---@param sourceMode string|nil
---@return string|nil
---@nodiscard
function Service.resolveAttachPartType(bikeItem, sourceItem, fallbackPartType, sourceMode)
    if sourceMode == Service.SourceModeTapedFlashlight then
        return "TapedFlashlight"
    end

    local partType = AttachmentActionUtils.resolveUpgradePartType(bikeItem, sourceItem, fallbackPartType)
    if Service.isAllowedPartType(partType) then
        return partType
    end
    return nil
end

---@param bikeItem InventoryItem|nil
---@param partType string|nil
---@return boolean
---@nodiscard
local function hasCompatibleBikeState(bikeItem, partType)
    if not Service.isAllowedPartType(partType) then
        return false
    end
    if bikeHasPart(bikeItem, partType) then
        return false
    end
    if partType == "Lamp" and bikeHasPart(bikeItem, "TapedFlashlight") then
        return false
    end
    if partType == "TapedFlashlight" and bikeHasPart(bikeItem, "Lamp") then
        return false
    end
    if partType == "Sportsbottle" and not bikeHasPart(bikeItem, "BottleHolder") then
        return false
    end
    if SidecarAnimal.isAnimalPartType(partType) and not bikeHasPart(bikeItem, "Sidecar") then
        return false
    end
    if SidecarAnimal.isAnimalPartType(partType) and SidecarAnimal.bikeHasAnyAnimalPart(bikeItem) then
        return false
    end
    if partType == "Crate" and bikeHasPart(bikeItem, "Toolbox") then
        return false
    end
    if partType == "Toolbox" and bikeHasPart(bikeItem, "Crate") then
        return false
    end
    return true
end

---@param sourceItem InventoryItem|nil
---@param partType string|nil
---@param sourceMode string|nil
---@param ductTape InventoryItem|nil
---@param partFullType string|nil
---@return boolean
---@nodiscard
local function hasCompatibleSourceItem(sourceItem, partType, sourceMode, ductTape, partFullType)
    if sourceMode == Service.SourceModeTapedFlashlight then
        local resolvedPartFullType = Service.getTapedFlashlightPartFullType(sourceItem)
        if not resolvedPartFullType then
            return false
        end
        if partFullType and partFullType ~= resolvedPartFullType then
            return false
        end
        if not (ductTape and ductTape.getCurrentUsesFloat) then
            return false
        end
        return ductTape:getCurrentUsesFloat() >= Service.DuctTapeUsage
    end

    if not sourceItem then
        return false
    end
    if sourceItem.isBroken and sourceItem:isBroken() then
        return false
    end
    if sourceMode == Service.SourceModeVanilla then
        return BicycleVanillaPartMapping.isVanillaSourceForPartType(sourceItem, partType)
    end

    local sourcePartType = getItemPartType(sourceItem)
    if sourcePartType == partType then
        return sourcePartType ~= nil
    end
    return Service.isWheelPartType(sourcePartType) and Service.isWheelPartType(partType)
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@param sourceItem InventoryItem|nil
---@param partType string|nil
---@param sourceMode string|nil
---@param ductTape InventoryItem|nil
---@param partFullType string|nil
---@return boolean
---@nodiscard
function Service.canAttachPart(character, bikeItem, sourceItem, partType, sourceMode, ductTape, partFullType)
    if not (character and bikeItem and sourceItem and partType) then
        return false
    end
    if not Service.canAccessBike(character, bikeItem) then
        return false
    end
    if not hasCompatibleBikeState(bikeItem, partType) then
        return false
    end
    if not characterOwnsItem(character, sourceItem) then
        return false
    end
    if sourceMode == Service.SourceModeTapedFlashlight and not characterOwnsItem(character, ductTape) then
        return false
    end
    if not hasCompatibleSourceItem(sourceItem, partType, sourceMode, ductTape, partFullType) then
        return false
    end
    if sourceMode == Service.SourceModeVanilla then
        return AttachmentActionUtils.isValidatedVanillaAttach(bikeItem, sourceItem, partType)
    end
    if sourceMode == Service.SourceModeTapedFlashlight then
        return true
    end

    local sourcePartType = getItemPartType(sourceItem)
    if sourcePartType == partType then
        return sourceItem.canAttach and sourceItem:canAttach(character, bikeItem)
    end
    return Service.isWheelPartType(sourcePartType) and Service.isWheelPartType(partType)
end

---@param item InventoryItem|nil
---@return number
---@nodiscard
local function getSportsbottleAmount(item)
    if not (item and item.getFluidContainer) then
        return 0
    end

    local fluidContainer = item:getFluidContainer()
    if not (fluidContainer and fluidContainer.getAmount) then
        return 0
    end

    local amount = fluidContainer:getAmount()
    if amount < 0 then
        return 0
    end
    return amount
end

---@param item InventoryItem|nil
---@param amount number
local function setSportsbottleAmount(item, amount)
    if not (item and item.getFluidContainer) then
        return
    end

    local fluidContainer = item:getFluidContainer()
    if not fluidContainer then
        return
    end

    local clamped = amount
    if clamped < 0 then
        clamped = 0
    end
    if fluidContainer.getCapacity then
        local capacity = fluidContainer:getCapacity()
        if clamped > capacity then
            clamped = capacity
        end
    elseif clamped > 1 then
        clamped = 1
    end

    if fluidContainer.Empty then
        fluidContainer:Empty()
    end
    if clamped <= 0 then
        return
    end

    if Fluid and Fluid.Water and fluidContainer.addFluid then
        fluidContainer:addFluid(Fluid.Water, clamped)
    elseif fluidContainer.adjustAmount then
        fluidContainer:adjustAmount(clamped)
    end
end

---@param part InventoryItem|nil
---@param sourceItem InventoryItem|nil
local function copySportsbottleWaterToPart(part, sourceItem)
    if not (part and part.getModData) then
        return
    end
    local md = part:getModData()
    md[SPORTS_BOTTLE_WATER_KEY] = getSportsbottleAmount(sourceItem)
    if part.transmitModData then
        part:transmitModData()
    end
end

---@param part InventoryItem|nil
---@return number
---@nodiscard
local function getPartSportsbottleWater(part)
    if not (part and part.getModData) then
        return 0
    end
    local amount = tonumber(part:getModData()[SPORTS_BOTTLE_WATER_KEY])
    if not amount then
        return 0
    end
    if amount < 0 then
        return 0
    end
    return amount
end

---@param part InventoryItem|nil
---@param vanillaItem InventoryItem|nil
local function markPartVanillaSource(part, vanillaItem)
    if not (part and vanillaItem and part.getModData and vanillaItem.getFullType) then
        return
    end

    local md = part:getModData()
    md[VANILLA_SOURCE_TYPE_KEY] = vanillaItem:getFullType()
    if vanillaItem.getID then
        md[VANILLA_SOURCE_ID_KEY] = vanillaItem:getID()
    else
        md[VANILLA_SOURCE_ID_KEY] = nil
    end
    if part.transmitModData then
        part:transmitModData()
    end
end

---@param part InventoryItem|nil
local function resetWheelDisplayName(part)
    if not (part and Service.isWheelPartType(getItemPartType(part)) and part.getScriptItem) then
        return
    end

    part:setName(part:getScriptItem():getDisplayName())
    part:setCustomName(false)
end

---@param sourceItem InventoryItem|nil
---@param partType string|nil
---@param sourceMode string|nil
---@param partFullType string|nil
---@return InventoryItem|nil
function Service.createPartForAttach(sourceItem, partType, sourceMode, partFullType)
    if not (sourceItem and partType) then
        return nil
    end
    if sourceMode == Service.SourceModeVanilla then
        local mappedPartFullType = BicycleVanillaPartMapping.getPartFullType(partType)
        if not mappedPartFullType then
            return nil
        end
        local mappedPart = instanceItem(mappedPartFullType)
        if mappedPart then
            markPartVanillaSource(mappedPart, sourceItem)
        end
        return mappedPart
    end
    if sourceMode == Service.SourceModeTapedFlashlight then
        local resolvedPartFullType = partFullType or Service.getTapedFlashlightPartFullType(sourceItem)
        if not resolvedPartFullType then
            return nil
        end
        local tapedPart = instanceItem(resolvedPartFullType)
        if tapedPart and sourceItem.getUsedDelta and tapedPart.setUsedDelta then
            tapedPart:setUsedDelta(sourceItem:getUsedDelta())
        end
        return tapedPart
    end
    return AttachmentActionUtils.createPartForAttach(sourceItem, partType)
end

---@param part InventoryItem|nil
---@param partType string|nil
---@return InventoryItem|nil
function Service.convertDetachedPartToReturnItem(part, partType)
    local detachedItem = AttachmentActionUtils.convertDetachedPartToVanillaItem(part, partType)
    if not detachedItem then
        return part
    end
    if partType == "Sportsbottle" then
        setSportsbottleAmount(detachedItem, getPartSportsbottleWater(part))
    end
    resetWheelDisplayName(detachedItem)
    return detachedItem
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param item InventoryItem|nil
local function syncModifiedItem(character, item)
    if not item then
        return
    end
    if isServer() then
        syncItemFields(character, item)
    elseif item.syncItemFields then
        item:syncItemFields()
    end
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param ductTape InventoryItem|nil
local function consumeDuctTape(character, ductTape)
    if not (character and ductTape and ductTape.getCurrentUsesFloat and ductTape.setCurrentUsesFloat) then
        return
    end

    local newDelta = ductTape:getCurrentUsesFloat() - Service.DuctTapeUsage
    if newDelta < 0 then
        newDelta = 0
    end

    ductTape:setCurrentUsesFloat(newDelta)
    if newDelta <= 0 then
        AttachmentActionUtils.clearItemFromHands(character, ductTape)
        AttachmentActionUtils.removeInventoryItem(character:getInventory(), ductTape)
        return
    end

    syncModifiedItem(character, ductTape)
end

---@return BicycleContainerManager|nil
local function getBicycleContainerManager()
    if BicycleContainerManager then
        return BicycleContainerManager
    end
    if isClient() then
        return nil
    end
    BicycleContainerManager = require("Bicycle/BicycleContainerManager")
    return BicycleContainerManager
end

---@param character IsoPlayer|IsoGameCharacter|nil
local function notifyContainerUpdated(character)
    if isServer() and character and character.getOnlineID then
        sendServerCommand(Bicycle.Core.SyncModule, "ContainerUpdated", {
            id = character:getOnlineID()
        })
    end
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@param partType string|nil
local function syncContainerState(character, bikeItem, partType)
    local containerManager = getBicycleContainerManager()
    if not (containerManager and character and bikeItem and partType) then
        return
    end
    containerManager.syncBikeContainers(character, bikeItem, AttachmentActionUtils.resolveBikeSquare(character, bikeItem), partType)
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@param sourceItem InventoryItem|nil
---@param partType string|nil
---@param sourceMode string|nil
---@param ductTape InventoryItem|nil
---@param partFullType string|nil
---@return boolean
function Service.applyClientAttachPreview(character, bikeItem, sourceItem, partType, sourceMode, ductTape, partFullType)
    if not (character and bikeItem and sourceItem and partType) then
        return false
    end
    if isClient() and bikeItem:getWorldItem() then
        return true
    end
    if bikeItem:getWeaponPart(partType) then
        AttachmentActionUtils.refreshBikeWorldModel(bikeItem)
        return true
    end

    local partToAttach = Service.createPartForAttach(sourceItem, partType, sourceMode, partFullType)
    if not partToAttach then
        return false
    end
    if partType == "Sportsbottle" and sourceMode == Service.SourceModeVanilla then
        copySportsbottleWaterToPart(partToAttach, sourceItem)
    end

    bikeItem:attachWeaponPart(character, partToAttach)
    AttachmentActionUtils.refreshBikeWorldModel(bikeItem)
    return true
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@param partType string|nil
---@return boolean
function Service.applyClientDetachPreview(character, bikeItem, partType)
    if not (character and bikeItem and partType) then
        return false
    end
    if isClient() and bikeItem:getWorldItem() then
        return true
    end
    local part = bikeItem:getWeaponPart(partType)
    if not part then
        AttachmentActionUtils.refreshBikeWorldModel(bikeItem)
        return true
    end

    bikeItem:detachWeaponPart(character, part)
    AttachmentActionUtils.refreshBikeWorldModel(bikeItem)
    return true
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@param sourceItem InventoryItem|nil
---@param partType string|nil
---@param sourceMode string|nil
---@param ductTape InventoryItem|nil
---@param partFullType string|nil
---@return boolean
function Service.executeAttach(character, bikeItem, sourceItem, partType, sourceMode, ductTape, partFullType)
    if not Service.canAttachPart(character, bikeItem, sourceItem, partType, sourceMode, ductTape, partFullType) then
        BicycleDebug.log(
            "BicyclePartAttachmentService:executeAttach validation failed bike="
                .. BicycleDebug.describeItem(bikeItem)
                .. ", source=" .. BicycleDebug.describeItem(sourceItem)
                .. ", partType=" .. tostring(partType)
                .. ", sourceMode=" .. tostring(sourceMode)
        )
        return false
    end

    local partToAttach = Service.createPartForAttach(sourceItem, partType, sourceMode, partFullType)
    if not partToAttach then
        return false
    end
    if partType == "Sportsbottle" and sourceMode == Service.SourceModeVanilla then
        copySportsbottleWaterToPart(partToAttach, sourceItem)
    end

    BicycleDebug.log(
        "BicyclePartAttachmentService:executeAttach bike=" .. BicycleDebug.describeItem(bikeItem)
            .. ", source=" .. BicycleDebug.describeItem(sourceItem)
            .. ", partToAttach=" .. BicycleDebug.describeItem(partToAttach)
            .. ", partType=" .. tostring(partType)
            .. ", sourceMode=" .. tostring(sourceMode)
    )

    bikeItem:attachWeaponPart(character, partToAttach)

    local containerManager = getBicycleContainerManager()
    if BicycleContainers.isContainerPartType(partType) and containerManager then
        containerManager.attachContainerPartNow(
            character,
            bikeItem,
            partType,
            sourceItem,
            sourceMode == Service.SourceModeVanilla,
            AttachmentActionUtils.resolveBikeSquare(character, bikeItem)
        )
    end

    AttachmentActionUtils.clearItemFromHands(character, sourceItem)
    if sourceMode == Service.SourceModeTapedFlashlight then
        AttachmentActionUtils.removeInventoryItem(character:getInventory(), sourceItem)
        consumeDuctTape(character, ductTape)
    else
        AttachmentActionUtils.removeInventoryItem(character:getInventory(), sourceItem)
    end

    AttachmentActionUtils.refreshBikeState(character, bikeItem)
    syncContainerState(character, bikeItem, partType)
    notifyContainerUpdated(character)
    character:setSecondaryHandItem(nil)
    return true
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@param partType string|nil
---@return boolean
function Service.canDetachPart(character, bikeItem, partType)
    if not (character and bikeItem and partType and BicycleUtils.isBicycleItem(bikeItem)) then
        return false
    end
    if not Service.isAllowedPartType(partType) then
        return false
    end
    if not Service.canAccessBike(character, bikeItem) then
        return false
    end

    if SidecarAnimal.isAnimalPartType(partType) then
        return false
    end
    if partType == "Sidecar" and SidecarAnimal.bikeHasAnyAnimalPart(bikeItem) then
        return false
    end

    local part = bikeItem:getWeaponPart(partType)
    if not part then
        return false
    end
    return part:canDetach(character, bikeItem)
end

---@param character IsoPlayer|IsoGameCharacter|nil
---@param bikeItem InventoryItem|nil
---@param partType string|nil
---@return boolean
function Service.executeDetach(character, bikeItem, partType)
    if not Service.canDetachPart(character, bikeItem, partType) then
        BicycleDebug.log(
            "BicyclePartAttachmentService:executeDetach validation failed bike="
                .. BicycleDebug.describeItem(bikeItem)
                .. ", partType=" .. tostring(partType)
        )
        return false
    end

    local part = bikeItem:getWeaponPart(partType)
    if not part then
        return false
    end

    BicycleDebug.log(
        "BicyclePartAttachmentService:executeDetach bike=" .. BicycleDebug.describeItem(bikeItem)
            .. ", part=" .. BicycleDebug.describeItem(part)
            .. ", partType=" .. tostring(partType)
    )

    bikeItem:detachWeaponPart(character, part)
    local detachedItem = Service.convertDetachedPartToReturnItem(part, partType)
    AttachmentActionUtils.addInventoryItem(character:getInventory(), detachedItem)

    local containerManager = getBicycleContainerManager()
    if BicycleContainers.isContainerPartType(partType) and containerManager then
        containerManager.detachContainerPartNow(
            character,
            bikeItem,
            partType,
            detachedItem,
            AttachmentActionUtils.resolveBikeSquare(character, bikeItem)
        )
    end

    AttachmentActionUtils.refreshBikeState(character, bikeItem)
    syncContainerState(character, bikeItem, partType)
    notifyContainerUpdated(character)
    return true
end

return Service
