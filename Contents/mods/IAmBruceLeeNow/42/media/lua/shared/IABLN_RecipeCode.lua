IABLN_RecipeCodeOnTest = IABLN_RecipeCodeOnTest or {}

local WELDING_MASK_TYPE = "Base.WeldingMask"
local REQUIRED_TAILORING_LEVEL = 5

local function craftableHandwrapsEnabled()
    local options = SandboxVars and SandboxVars.IAmBruceLeeNow
    return options and options.CraftableHandwraps == true
end

local function isWeldingMaskWorn(player)
    local wornItems = player and player:getWornItems() or nil
    if not wornItems then return false end

    for index = 0, wornItems:size() - 1 do
        local worn = wornItems:get(index)
        local item = worn and worn:getItem() or nil
        if item and item:getFullType() == WELDING_MASK_TYPE then
            return true
        end
    end

    return false
end

local function hasRequiredTailoringLevel(player)
    return player
        and Perks
        and Perks.Tailoring
        and player:getPerkLevel(Perks.Tailoring) >= REQUIRED_TAILORING_LEVEL
end

function IABLN_RecipeCodeOnTest.craftMartialArtsHandWraps(recipe, player, item)
    return craftableHandwrapsEnabled()
        and hasRequiredTailoringLevel(player)
        and isWeldingMaskWorn(player)
end
