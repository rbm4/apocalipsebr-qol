BAM = BAM or {}


-- Add Train Mechanics and Uninstall buttons to vehicle part context menu
local original_doPartContextMenu = ISVehicleMechanics.doPartContextMenu
function ISVehicleMechanics:doPartContextMenu(...)
    local success = original_doPartContextMenu(self, ...)
    BAM.CreateMechanicsButton(self, self.context, self.chr, self.vehicle, BAM.StartMechanicsTraining)
    --BAM.CreateUninstallAllMenu(self, self.context, self.chr, self.vehicle)
    return success
end

-- Create the Train Mechanics button and its tooltip
function BAM.CreateMechanicsButton(self, context, player, vehicle, functionToCall)
    if not context then return end

    -- Don't show the button if the player is already max level in mechanics, always show in debug mode
    local skillLevel = player:getPerkLevel(Perks.Mechanics)
    if skillLevel >= 10 and not getCore():getDebug() then return end

    local trainButton = nil
    if self then
        trainButton = context:addOption(getText("UI_BAM_button.title"), self, functionToCall, player, vehicle)
    else
        trainButton = context:addOption(getText("UI_BAM_button.title"), player, functionToCall, vehicle)
    end
    trainButton.iconTexture = getTexture("Item_Wrench")

    local trainTooltip = ISToolTip:new()
    trainTooltip:initialise()
    trainTooltip:setVisible(true)
    trainTooltip.description = BAM.GenerateDescription(player, vehicle)
    trainButton.toolTip = trainTooltip
end

-- Create the Uninstall All menu with category sub-options
-- Translation keys map to vanilla game translation strings where possible
local uninstallCategoryLabels = {
    everything  = "UI_BAM_Uninstall_Everything",
    tires       = "IGUI_VehiclePartCattire",
    doors       = "IGUI_VehiclePartCatdoor",
    windows     = "IGUI_VehiclePartWindow",  -- todo
    seats       = "IGUI_VehiclePartCatseat",
    lights      = "IGUI_VehiclePartCatlights",
    brakes      = "IGUI_VehiclePartCatbrakes",
    suspension  = "IGUI_VehiclePartCatsuspension",
}

function BAM.CreateUninstallAllMenu(self, context, player, vehicle)
    if not context then return end

    -- Build a parent option: "Uninstall ..."
    local parentOption = context:addOption(getText("UI_BAM_Uninstall_Title"), nil)
    parentOption.iconTexture = getTexture("Item_Wrench")

    -- Create the submenu
    local subMenu = context:getNew(context)
    context:addSubMenu(parentOption, subMenu)

    local anyEnabled = false

    for _, category in ipairs(BAM.UninstallCategories) do
        -- Build a set-like table from the category ids list (or nil for "everything")
        local categoryIds = nil
        if category.ids then
            categoryIds = {}
            for _, id in ipairs(category.ids) do
                categoryIds[id] = true
            end
        end

        -- Check how many parts can actually be uninstalled in this category
        local parts = BAM.GetUninstallablePartsByCategory(player, vehicle, categoryIds)
        local count = #parts

        -- Build the label: "All Tires (3)" or "Everything (12)"
        local label = getText(uninstallCategoryLabels[category.key] or category.key)
        if category.key ~= "everything" then
            label = getText("UI_BAM_Uninstall_All", label)
        end
        label = label .. " (" .. tostring(count) .. ")"

        local option = subMenu:addOption(label, self, BAM.UninstallCategory, player, vehicle, categoryIds)

        if count == 0 then
            option.notAvailable = true
        else
            anyEnabled = true
        end
    end

    -- If no category has any uninstallable parts, grey out the parent option too
    if not anyEnabled then
        parentOption.notAvailable = true
    end
end


-- Adds a "Train Mechanics" button to the world context menu when right-clicking on a vehicle in the world
-- 1. A wrapper function to handle the click from the world
local function onTrainMechanicsFromWorld(playerObj, vehicle)
    -- Because BAM.StartMechanicsTraining was originally designed for the UI, it expects (ui, player, vehicle). We pass 'nil' for the UI.
    BAM.StartMechanicsTraining(nil, playerObj, vehicle)
end

-- 2. The function that builds the world context menu
local function BAM_WorldVehicleMenu(player, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end

    -- Loop through what the player clicked on to find the vehicle
    local vehicle = nil
    for _, obj in ipairs(worldobjects) do
        if instanceof(obj, "BaseVehicle") then
            vehicle = obj
            break
        elseif obj:getSquare() and obj:getSquare():getVehicleContainer() then
            vehicle = obj:getSquare():getVehicleContainer()
            break
        end
    end

    -- If we found a vehicle, build the button
    if vehicle then
        local playerObj = getSpecificPlayer(player)
        BAM.CreateMechanicsButton(nil, context, playerObj, vehicle, onTrainMechanicsFromWorld)
    end
end

Events.OnFillWorldObjectContextMenu.Add(BAM_WorldVehicleMenu)


-- ### Button Design ###
function BAM.GenerateDescription(player, vehicle)
    local newline = " <LINE>"
    local msg = getText("UI_BAM_button_desc.needs") .. ":"

    -- Tool check
    local hasScrewdriver = false
    local hasWrench = false
    local hasLugWrench = false
    if BAM.GameVersionNewerThanOrEqual(42, 13, 0) then
        hasScrewdriver = player:getInventory():getFirstTagRecurse(ItemTag.SCREWDRIVER)
        hasWrench = player:getInventory():getFirstTagRecurse(ItemTag.WRENCH)
        hasLugWrench = player:getInventory():getFirstTagRecurse(ItemTag.LUG_WRENCH)
    else
        hasScrewdriver = player:getInventory():getFirstTagRecurse("Screwdriver")
        hasWrench = player:getInventory():getFirstTagRecurse("Wrench")
        hasLugWrench = player:getInventory():getFirstTagRecurse("LugWrench")
    end
    local hasJack = player:getInventory():getFirstTypeRecurse("Jack")

    local nameScrewdriver = getScriptManager():getItem("Base.Screwdriver"):getDisplayName()
    local nameMultitool = getScriptManager():getItem("Base.Multitool"):getDisplayName()
    local nameHandiknife = getScriptManager():getItem("Base.Handiknife"):getDisplayName()
    local nameWrench = getScriptManager():getItem("Base.Wrench"):getDisplayName()
    local nameRatchetWrench = getScriptManager():getItem("Base.Ratchet"):getDisplayName()
    local nameLugWrench = getScriptManager():getItem("Base.LugWrench"):getDisplayName()
    local nameTireIron = getScriptManager():getItem("Base.TireIron"):getDisplayName()
    local nameJack = getScriptManager():getItem("Base.Jack"):getDisplayName()

    local color = hasScrewdriver and "<GREEN>" or "<RED>"
    msg = msg .. newline .. color .. " - " .. nameScrewdriver .. " / " .. nameMultitool .. " / " .. nameHandiknife

    color = hasWrench and "<GREEN>" or "<RED>"
    msg = msg .. newline .. color .. " - " .. nameWrench .. " / " .. nameRatchetWrench

    color = hasLugWrench and "<GREEN>" or "<RED>"
    msg = msg .. newline .. color .. " - " .. nameLugWrench .. " / " .. nameTireIron

    color = hasJack and "<GREEN>" or "<RED>"
    msg = msg .. newline .. color .. " - " .. nameJack

    -- Recipe check v2
    local requiredRecipes = BAM.GetRequiredRecipes(vehicle)
    msg = msg .. newline
    msg = msg .. newline .. "<RGB:1,1,1>" .. getText("UI_BAM_button_desc.recipes_required") .. ":"
    for recipe, _ in pairs(requiredRecipes) do
        local recipeDisplayName = getText("Tooltip_vehicle_requireRecipe", getRecipeDisplayName(recipe))
        local knowsRecipe = player:isRecipeKnown(recipe, true)
        color = knowsRecipe and "<GREEN>" or "<RED>"
        msg = msg .. newline .. color .. " - " .. recipeDisplayName
    end

    -- Skill check
    local skillLevel = player:getPerkLevel(Perks.Mechanics)
    local minSuccessChance = BAM.GetOptionMinPartSuccessChance()
    msg = msg .. newline
    msg = msg ..
    newline .. "<RGB:1,1,1>" .. getText("UI_BAM_button_desc.mechanics_level") .. ": " .. tostring(skillLevel)
    if minSuccessChance == 30 then  -- This is the default value, so show more detailed info
        if skillLevel < 2 then
            msg = msg .. newline .. "<RED> - " .. getText("UI_BAM_button_desc.parts_will_break") .. "!"
            msg = msg .. newline .. "<RED> - " .. getText("UI_BAM_button_desc.use_disposable_vehicles") .. "!"
            msg = msg ..
            newline .. "<RED> - " .. "(" .. getText("UI_BAM_button_desc.success_chance", minSuccessChance) .. ")"
        elseif skillLevel < 7 then
            msg = msg .. newline .. "<ORANGE> - " .. getText("UI_BAM_button_desc.parts_might_break")
            msg = msg .. newline .. "<ORANGE> - " .. getText("UI_BAM_button_desc.use_disposable_vehicles")
        else
            msg = msg .. newline .. "<GREEN> - " .. getText("UI_BAM_button_desc.parts_safe")
            msg = msg .. newline .. "<GREEN> - " .. getText("UI_BAM_button_desc.vehicle_safe")
        end
    else  -- Otherwise just show the minimum success chance and some edge case details
        msg = msg .. newline .. "<RGB:1,1,1> - " .. getText("UI_BAM_button_desc.success_chance", minSuccessChance)
        if minSuccessChance == 100 then
            msg = msg .. newline .. "<GREEN> - " .. getText("UI_BAM_button_desc.parts_safe")
            msg = msg .. newline .. "<GREEN> - " .. getText("UI_BAM_button_desc.vehicle_safe")
        end
    end

    ---- Car Key check
    if not BAM.PlayerHasCarAccess(player, vehicle) then
        msg = msg .. newline
        msg = msg .. newline .. "<RGB:1,1,1>" .. getText("UI_BAM_button_desc.no_car_access")
        msg = msg .. newline .. "<ORANGE> - " .. getText("UI_BAM_button_desc.parts_inaccessible")
    end


    -- Notes
    msg = msg .. newline
    msg = msg .. newline .. "<RGB:1,1,1>" .. getText("UI_BAM_button_desc.empty_seats")

    if BAM.IsServerOverwritingOptionMinPartSuccessChance() then
        msg = msg .. newline
        msg = msg .. newline .. "<RGB:0.5,0.5,0.5>" .. getText("UI_BAM_button_desc.server_enforce")
        msg = msg .. newline .. "<RGB:0.5,0.5,0.5>" .. "  - " .. getText("UI_BAM_options_title.min_success_chance") .. ": " .. BAM.GetOptionMinPartSuccessChance() .. "%"
    end

    return msg
end


function BAM.GetRequiredRecipes(vehicle)
    local recipes = {}
    recipes["Basic Mechanics"] = false
    recipes["Intermediate Mechanics"] = false
    recipes["Advanced Mechanics"] = false

    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        local keyvalues = part:getTable("uninstall")
        if keyvalues and keyvalues.recipes and keyvalues.recipes ~= "" then
            for _, recipe in ipairs(keyvalues.recipes:split(";")) do
                recipes[recipe] = true
            end
        end
    end

    for recipe, required in pairs(recipes) do
        if not required then
            recipes[recipe] = nil
        end
    end
    return recipes
end


function BAM.PlayerHasCarAccess(player, vehicle)
    local needsKey = false
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        if VehicleUtils.RequiredKeyNotFound(part, player) then
            needsKey = true
            break
        end
    end
    return not needsKey
end

