---@class BicycleItemInitializer
BicycleItemInitializer = BicycleItemInitializer or {}

local SIDECAR_FOR_BIKE = {
    Bicycle = "Bicycle.Bicycle_SidecarWhite",
    Bicycle_RedStreet = "Bicycle.Bicycle_SidecarRed",
}

local ATTACHED_SIDECAR_BASE_PERMILLE = 300
local ATTACHED_SIDECAR_ROLL_CEILING = 10000

---@return number
local function getSidecarSpawnRateMultiplier()
    local rate = 100
    if SandboxVars and SandboxVars.Bicycle and SandboxVars.Bicycle.SidecarSpawnRate then
        rate = SandboxVars.Bicycle.SidecarSpawnRate
    end
    if rate >= 100 then
        return 1
    end
    return math.max(0, rate / 100)
end

---@param fullType string
---@return InventoryItem|nil
---@nodiscard
local function createPart(fullType)
    if not instanceItem then
        return nil
    end

    return instanceItem(fullType)
end

---@return number
---@nodiscard
local function rollHighCondition()
    local highConditionFloor = 115
    if ZombRand(100) < 70 then
        return ZombRand(highConditionFloor, 128)
    end

    return ZombRand(0, highConditionFloor + 1)
end

---@type table<string, string>
local normalToFlat = {
    ["Bicycle.Bicycle_StreetWheelFrontItem"] = "Bicycle.Bicycle_StreetWheelFrontFlatItem",
    ["Bicycle.Bicycle_StreetWheelRearItem"] = "Bicycle.Bicycle_StreetWheelRearFlatItem",
    ["Bicycle.Bicycle_OffroadWheelFrontItem"] = "Bicycle.Bicycle_OffroadWheelFrontFlatItem",
    ["Bicycle.Bicycle_OffroadWheelRearItem"] = "Bicycle.Bicycle_OffroadWheelRearFlatItem",
}

---@param fullType string
---@return InventoryItem|nil
---@nodiscard
local function createWheel(fullType)
    local condition = rollHighCondition()

    if ZombRand(100) < 2 then
        local flatType = normalToFlat[fullType]
        if flatType then
            local flatWheel = createPart(flatType)
            if flatWheel and flatWheel.setCondition then
                flatWheel:setCondition(condition)
            end
            return flatWheel
        end
    end

    local wheel = createPart(fullType)
    if not wheel then
        return nil
    end

    if wheel.setCondition then
        wheel:setCondition(condition)
    end

    return wheel
end

---@param item InventoryItem|nil
---@param part InventoryItem|nil
local function attachPart(item, part)
    if item and part and item.attachWeaponPart then
        item:attachWeaponPart(part, true)
    end
end

---@return InventoryItem|nil
---@nodiscard
local function createChain()
    local chain = createPart("Bicycle.Bicycle_Chain")
    if chain and chain.setCondition then
        chain:setCondition(rollHighCondition())
    end

    return chain
end

---@return string
---@return string
---@nodiscard
local function chooseWheelTypes()
    local preferStreet = ZombRand(100) < 75
    if preferStreet then
        return "Bicycle.Bicycle_StreetWheelFrontItem", "Bicycle.Bicycle_StreetWheelRearItem"
    end

    return "Bicycle.Bicycle_OffroadWheelFrontItem", "Bicycle.Bicycle_OffroadWheelRearItem"
end

---@param item InventoryItem|nil
---@param partFullType string
---@param chance number
local function attachOptionalPart(item, partFullType, chance)
    if ZombRand(100) < chance then
        attachPart(item, createPart(partFullType))
    end
end

---@param item InventoryItem|nil
---@return InventoryItem|nil
function BicycleItemInitializer.onCreateBicycle(item)
    if not item then
        return nil
    end

    local frontWheelType, rearWheelType = chooseWheelTypes()
    local frontWheel = createWheel(frontWheelType)
    local rearWheel = createWheel(rearWheelType)

    if not (frontWheel and rearWheel) then
        frontWheel = frontWheel or createWheel("Bicycle.Bicycle_StreetWheelFrontItem")
        rearWheel = rearWheel or createWheel("Bicycle.Bicycle_StreetWheelRearItem")
    end

    attachPart(item, frontWheel)
    attachPart(item, rearWheel)
    attachPart(item, createChain())
    -- Pedals ship fitted on every new bike, like the chain. Unlike the chain they are deliberately NOT in
    -- bicycleHasRideRequirements: bikes already spawned in existing worlds have no pedals and must keep
    -- riding without the player hunting for a pair, and anyone who dislikes the look can just detach them.
    attachPart(item, createPart("Bicycle.Bicycle_Pedals"))
    attachPart(item, createPart("Bicycle.Bicycle_KickstandDown"))

    attachOptionalPart(item, "Bicycle.Bicycle_Bell", 85)
    attachOptionalPart(item, "Bicycle.Bicycle_Saddlebag", 5)
    attachOptionalPart(item, "Bicycle.Bicycle_Lamp", 5)
    attachOptionalPart(item, "Bicycle.Bicycle_BottleHolder", 5)
    attachOptionalPart(item, "Bicycle.Bicycle_Basket", 10)

    if ZombRand(100) < 10 then
        local storagePart = ZombRand(2) == 0 and "Bicycle.Bicycle_Crate" or "Bicycle.Bicycle_Toolbox"
        attachPart(item, createPart(storagePart))
    end

    local bikeType = item.getType and item:getType() or nil
    local sidecarFullType = bikeType and SIDECAR_FOR_BIKE[bikeType] or nil
    if sidecarFullType then
        local threshold = math.floor(ATTACHED_SIDECAR_BASE_PERMILLE * getSidecarSpawnRateMultiplier())
        if threshold > 0 and ZombRand(ATTACHED_SIDECAR_ROLL_CEILING) < threshold then
            attachPart(item, createPart(sidecarFullType))
        end
    end

    return item
end

return BicycleItemInitializer
