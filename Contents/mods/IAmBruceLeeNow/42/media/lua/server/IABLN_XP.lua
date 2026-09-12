local MODULE = "IABLN"
local COMMAND = "awardMartialArtsXP"
local EXERTION_COMMAND = "applyMartialArtsExertion"
local REQUEST_PROXY_COMMAND = "requestStyleProxy"
local REMOVE_PROXY_COMMAND = "removeStyleProxy"
local WRAPS_TYPE = "IAmBruceLeeNow.MartialArtsHandWraps"
local STYLE_TYPE = "IAmBruceLeeNow.MartialArtsFightingStyle"
local HANDS_LOCATION = ItemBodyLocation.get(ResourceLocation.of("base:hands"))
local MAX_XP_PER_STRIKE = 10
local ENDURANCE_COST_LEVEL_0 = 0.009
local HANDWRAPS_SCRIPT_WEIGHT = 0.1
-- Calibrated martial-arts strain rate: 2x the original baseline.
local STRAIN_WEIGHT_NORMALIZER = 20.0

local function isWearingHandWraps(player)
    local wraps = player and player:getWornItem(HANDS_LOCATION) or nil
    return wraps and wraps:getFullType() == WRAPS_TYPE
end

local function findStyleProxy(player)
    local items = player:getInventory():getItems()
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item and item:getFullType() == STYLE_TYPE then return item end
    end
    return nil
end

local function provideStyleProxy(player)
    if not isWearingHandWraps(player) then return end

    local existing = findStyleProxy(player)
    if existing then
        -- A repeated request can arrive before the first inventory-add packet
        -- reaches the client. Never create a second hidden weapon.
        sendAddItemToContainer(player:getInventory(), existing)
        return
    end

    local style = player:getInventory():AddItem(STYLE_TYPE)
    if not style then return end
    sendAddItemToContainer(player:getInventory(), style)
end

local function removeStyleProxies(player)
    local inventory = player:getInventory()
    local items = inventory:getItems()
    local removed = 0
    for index = items:size() - 1, 0, -1 do
        local item = items:get(index)
        if item and item:getFullType() == STYLE_TYPE then
            player:removeFromHands(item)
            inventory:Remove(item)
            sendRemoveItemFromContainer(inventory, item)
            removed = removed + 1
        end
    end
    if removed > 0 then
        sendEquip(player)
    end
end

local function getComboWorkload(comboId)
    return comboId == 2 and 0.75 or (comboId == 5 and 1.10 or 1.00)
end

local function applyExertion(player, args)
    local comboId = args and tonumber(args.comboId) or 0
    if comboId ~= 1 and comboId ~= 2 and comboId ~= 3 and
            comboId ~= 5 and comboId ~= 6 then return end
    if not isWearingHandWraps(player) then return end

    local perk = Perks.MartialArts or Perks.FromString("MartialArts")
    local level = perk and player:getPerkLevel(perk) or 0
    level = math.max(0, math.min(10, level))
    local workload = getComboWorkload(comboId)
    local enduranceScale = (3.0 - level * 0.1) / 3.0
    local enduranceCost = ENDURANCE_COST_LEVEL_0 * workload * enduranceScale
    player:getStats():remove(CharacterStat.ENDURANCE, enduranceCost)

    local options = SandboxVars and SandboxVars.IAmBruceLeeNow
    local percent = options and tonumber(options.MartialArtsMuscleStrain) or 100
    local strainMultiplier = math.max(0, math.min(300, percent)) / 100
    if strainMultiplier > 0 then
        local wraps = player:getWornItem(HANDS_LOCATION)
        local strengthLevel = math.max(0, math.min(10,
            player:getPerkLevel(Perks.Strength)))
        local strengthMod = (15 - strengthLevel) / 10.0
        -- Hosted servers can deserialize worn clothing with an instance weight of
        -- zero. Fall back to the weight declared by MartialArtsHandWraps.
        local actualWeight = wraps:getActualWeight()
        if not actualWeight or actualWeight <= 0 then
            actualWeight = HANDWRAPS_SCRIPT_WEIGHT
        end
        local painFactor = actualWeight * 0.15 * 0.3 * 4.0 *
            strengthMod * 0.65 * strainMultiplier * workload *
            STRAIN_WEIGHT_NORMALIZER
        if comboId == 1 or comboId == 6 then
            player:addBothArmMuscleStrain(painFactor)
        else
            player:addRightLegMuscleStrain(painFactor)
        end
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE or not player then return end
    if command == REMOVE_PROXY_COMMAND then
        removeStyleProxies(player)
        return
    end
    if command == REQUEST_PROXY_COMMAND then
        provideStyleProxy(player)
        return
    end
    if command == EXERTION_COMMAND then
        applyExertion(player, args)
        return
    end
    if command ~= COMMAND then return end

    local amount = args and tonumber(args.amount) or 0
    local perk = Perks.MartialArts or Perks.FromString("MartialArts")
    if not perk or amount <= 0 or amount > MAX_XP_PER_STRIKE or
            not isWearingHandWraps(player) then
        return
    end

    addXp(player, perk, amount)
end

Events.OnClientCommand.Add(onClientCommand)
