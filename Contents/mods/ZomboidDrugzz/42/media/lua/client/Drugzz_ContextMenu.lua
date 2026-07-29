require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPaneContextMenu"
require "Drugzz_Core"

DrugzzContextMenu = DrugzzContextMenu or {}

local useTranslationByContext = {
    smoke = "ContextMenu_Drugzz_Smoke",
    sniff = "ContextMenu_Drugzz_Sniff",
    take = "ContextMenu_Drugzz_Take",
    dab = "ContextMenu_Drugzz_Dab",
    vape = "ContextMenu_Drugzz_Vape",
}

local function translated(key, fallback, ...)
    local value = getText and getText(key, ...) or key
    if not value or value == key then
        return fallback or key
    end
    return value
end

local function itemHasUses(item)
    if not item or not item.getCurrentUsesFloat then
        return false
    end
    return item:getCurrentUsesFloat() > 0
end

local function getMissingUseRequirement(player, item)
    local requirements = item:getRequireInHandOrInventory()
    if not requirements or requirements:isEmpty() then
        return nil
    end

    local contextName = item:getCustomMenuOption()
    local isCombustibleSmoke = contextName and string.lower(contextName) == "smoke"
    if isCombustibleSmoke and item:hasTag(ItemTag.SMOKABLE) then
        if player:getVehicle() and player:getVehicle():canLightSmoke(player) then
            return nil
        end
        if ISInventoryPaneContextMenu.hasOpenFlame(player) then
            return nil
        end
    end

    local inventory = player:getInventory()
    local requiredNames = {}
    for index = 0, requirements:size() - 1 do
        local fullType = moduleDotType(item:getModule(), requirements:get(index))
        local requiredItem = inventory:getFirstTypeEvalRecurse(fullType, itemHasUses)
        if requiredItem then
            return nil
        end
        local displayName = getItemNameFromFullType(fullType)
        if displayName and displayName ~= "" then
            table.insert(requiredNames, displayName)
        end
    end

    if #requiredNames > 0 then
        return translated(
            "ContextMenu_Drugzz_Requires",
            "Requires: " .. table.concat(requiredNames, "/"),
            table.concat(requiredNames, "/")
        )
    end
    return translated(
        "ContextMenu_Drugzz_MissingUseRequirement",
        "Requires the appropriate ignition source, battery, or supporting device."
    )
end

local function useActionText(item)
    local contextName = item:getCustomMenuOption()
    local key = contextName and useTranslationByContext[string.lower(contextName)] or nil
    if key then
        return translated(key, contextName .. " " .. item:getDisplayName(), item:getDisplayName())
    end
    if contextName and contextName ~= "" then
        return contextName .. " " .. item:getDisplayName()
    end
    if instanceof(item, "Food") then
        return translated("ContextMenu_Drugzz_Eat", "Eat " .. item:getDisplayName(), item:getDisplayName())
    end
    return translated("ContextMenu_Drugzz_Use", "Use " .. item:getDisplayName(), item:getDisplayName())
end

local function useItem(item, playerNum, percentage)
    if not item or not itemHasUses(item) then
        return
    end
    local player = getSpecificPlayer(playerNum)
    if not player or getMissingUseRequirement(player, item) then
        return
    end
    if instanceof(item, "DrainableComboItem") and item:hasTag(ItemTag.CONSUMABLE) then
        ISInventoryPaneContextMenu.takePill(item, playerNum)
    else
        ISInventoryPaneContextMenu.eatItem(item, percentage or 1.0, playerNum)
    end
end

local function isVanillaUseCallback(callback)
    return callback == ISInventoryPaneContextMenu.onEatItems
        or callback == ISInventoryPaneContextMenu.onPillsItems
end

local function isVanillaUseOption(context, option)
    if isVanillaUseCallback(option.onSelect) then
        return true
    end
    if not option.subOption then
        return false
    end
    local subMenu = context:getSubMenu(option.subOption)
    if not subMenu then
        return false
    end
    for _, subOption in ipairs(subMenu.options) do
        if isVanillaUseCallback(subOption.onSelect) then
            return true
        end
    end
    return false
end

local function removeOptionAt(context, index)
    local option = table.remove(context.options, index)
    if option and context.optionPool then
        table.insert(context.optionPool, option)
    end
    for optionIndex, remainingOption in ipairs(context.options) do
        remainingOption.id = optionIndex
    end
    context.numOptions = #context.options + 1
end

local function suppressVanillaUseOptions(context)
    local removed = false
    for index = #context.options, 1, -1 do
        if isVanillaUseOption(context, context.options[index]) then
            removeOptionAt(context, index)
            removed = true
        end
    end
    if removed then
        context:calcHeight()
        context:setWidth(context:calcWidth())
    end
end

local function suppressVanillaPreparationOptions(context, recipes)
    if #recipes == 0 then
        return
    end

    local recipeNames = {}
    for _, recipe in ipairs(recipes) do
        recipeNames[recipe:getName()] = true
    end

    local function isDuplicateRecipeOption(option)
        if option.onSelect ~= ISInventoryPaneContextMenu.OnNewCraft or not option.param1 then
            return false
        end
        return recipeNames[option.param1:getName()] == true
    end

    local removed = false
    for index = #context.options, 1, -1 do
        local option = context.options[index]
        if isDuplicateRecipeOption(option) then
            removeOptionAt(context, index)
            removed = true
        elseif option.subOption then
            local subMenu = context:getSubMenu(option.subOption)
            if subMenu then
                local removedFromSubMenu = false
                for subIndex = #subMenu.options, 1, -1 do
                    if isDuplicateRecipeOption(subMenu.options[subIndex]) then
                        removeOptionAt(subMenu, subIndex)
                        removedFromSubMenu = true
                        removed = true
                    end
                end
                if removedFromSubMenu then
                    subMenu:calcHeight()
                    subMenu:setWidth(subMenu:calcWidth())
                    if #subMenu.options == 0 then
                        removeOptionAt(context, index)
                    end
                end
            end
        end
    end
    if removed then
        context:calcHeight()
        context:setWidth(context:calcWidth())
    end
end

local function canQuickPrepare(player, item, recipe)
    if not recipe or not item then
        return false
    end
    if player:isDriving() then
        return false
    end
    if recipe:needToBeLearn() and not player:isRecipeActuallyKnown(recipe) then
        return false
    end
    if not recipe:characterHasRequiredSkills(player) and not recipe:couldBenefitFromRecipeAtHand(player) then
        return false
    end
    if not CraftRecipeManager.getValidInputScriptForItem(recipe, item) then
        return false
    end

    local ok, canPerform = pcall(function()
        local containers = ISInventoryPaneContextMenu.getContainers(player)
        local logic = HandcraftLogic.new(player, nil, nil)
        logic:setIsoObject(logic:findCraftSurface(player, 2))
        logic:setContainers(containers)
        logic:setRecipeFromContextClick(recipe, item)
        return logic:canPerformCurrentRecipe()
    end)
    return ok and canPerform == true
end

local function getAvailablePreparationRecipes(player, item)
    local available = {}
    local containers = ISInventoryPaneContextMenu.getContainers(player)
    local ok, recipeList = pcall(
        CraftRecipeManager.getUniqueRecipeItems,
        item,
        player,
        containers
    )
    if not ok or not recipeList then
        return available
    end

    for index = 0, recipeList:size() - 1 do
        local recipe = recipeList:get(index)
        local recipeName = recipe and recipe:getName() or ""
        if string.sub(recipeName, 1, 7) == "Drugzz_" and canQuickPrepare(player, item, recipe) then
            table.insert(available, recipe)
        end
    end
    table.sort(available, function(left, right)
        return left:getTranslationName() < right:getTranslationName()
    end)
    return available
end

local function addUnavailableTooltip(option, description)
    option.notAvailable = true
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.description = description or translated(
        "ContextMenu_Drugzz_MissingUseRequirement",
        "Requires the appropriate ignition source, battery, or supporting device."
    )
    option.toolTip = tooltip
end

local function isPortionableFood(item)
    return instanceof(item, "Food")
        and not item:getCustomMenuOption()
        and item:getHungerChange() < 0
end

local function addPortionOption(menu, text, item, playerNum, percentage)
    local option = menu:addOption(text, item, useItem, playerNum, percentage)
    option.iconTexture = item:getTexture()
    return option
end

local function addUseOptions(rootMenu, player, playerNum, item)
    local missingRequirement = getMissingUseRequirement(player, item)
    local unavailableDescription = missingRequirement
    if not itemHasUses(item) then
        unavailableDescription = translated("ContextMenu_Drugzz_Empty", "This item is empty.")
    elseif isPortionableFood(item)
        and player:getMoodles():getMoodleLevel(MoodleType.FOOD_EATEN) >= 3 then
        unavailableDescription = getText("Tooltip_CantEatMore")
    end

    if isPortionableFood(item) then
        local useOption = rootMenu:addOption(useActionText(item), item, nil)
        useOption.iconTexture = item:getTexture()
        local portionMenu = ISContextMenu:getNew(rootMenu)
        rootMenu:addSubMenu(useOption, portionMenu)

        addPortionOption(portionMenu, getText("ContextMenu_Eat_All"), item, playerNum, 1.0)
        local baseHunger = math.abs(item:getBaseHunger() * 100) + 0.001
        local hungerChange = math.abs(item:getHungerChange() * 100) + 0.001
        if hungerChange >= 2 and hungerChange >= baseHunger / 2 then
            addPortionOption(portionMenu, getText("ContextMenu_Eat_Half"), item, playerNum, 0.5)
        end
        if hungerChange >= 4 and hungerChange >= baseHunger / 4 then
            addPortionOption(portionMenu, getText("ContextMenu_Eat_Quarter"), item, playerNum, 0.25)
        end

        if unavailableDescription then
            addUnavailableTooltip(useOption, unavailableDescription)
        end
        return
    end

    local useOption = rootMenu:addOption(useActionText(item), item, useItem, playerNum, 1.0)
    useOption.iconTexture = item:getTexture()
    if unavailableDescription then
        addUnavailableTooltip(useOption, unavailableDescription)
    end
end

function DrugzzContextMenu.onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then
        return
    end

    local actualItems = ISInventoryPane.getActualItems(items)
    if #actualItems ~= 1 then
        return
    end

    local selectedItem = actualItems[1]
    local definition = Drugzz.DRUGS[selectedItem:getType()]
    local availableRecipes = getAvailablePreparationRecipes(player, selectedItem)
    if not definition and #availableRecipes == 0 then
        return
    end

    if definition then
        suppressVanillaUseOptions(context)
    end
    suppressVanillaPreparationOptions(context, availableRecipes)

    local rootOption = context:addOptionOnTop(
        translated("ContextMenu_Drugzz", "Cannabis & Contraband"),
        selectedItem,
        nil
    )
    rootOption.iconTexture = selectedItem:getTexture()
    local rootMenu = ISContextMenu:getNew(context)
    context:addSubMenu(rootOption, rootMenu)

    if definition then
        addUseOptions(rootMenu, player, playerNum, selectedItem)
    end

    if #availableRecipes > 0 then
        local prepareOption = rootMenu:addOption(
            translated("ContextMenu_Drugzz_QuickPrepare", "Quick Prepare"),
            selectedItem,
            nil
        )
        local prepareMenu = ISContextMenu:getNew(rootMenu)
        rootMenu:addSubMenu(prepareOption, prepareMenu)

        for _, recipe in ipairs(availableRecipes) do
            local recipeOption = prepareMenu:addOption(
                recipe:getTranslationName(),
                selectedItem,
                ISInventoryPaneContextMenu.OnNewCraft,
                recipe,
                playerNum,
                false
            )
            local recipeIcon = getRecipeIcon and getRecipeIcon(recipe:getName()) or nil
            if recipeIcon then
                recipeOption.iconTexture = recipeIcon
            end
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(DrugzzContextMenu.onFillInventoryObjectContextMenu)
