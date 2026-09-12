--[[
    Auto All - Auto Cook setup window (Build 42 / SP + MP)
    ------------------------------------------------------------------
    The quick "Auto Cook: <dish>" entry on the context menu decides
    everything for you. This window is for when you want a say: which
    dish, what it is for, how big, and exactly how much of each thing
    goes in.

    Nothing here cooks anything by itself. It collects three numbers and
    hands them to Cook.start as a plan; the actual cooking is the same
    vanilla ISAddItemInRecipe loop it has always been.

      goal      which of the four weightings the picker scores with
      maxItems  how many things go in before it stops
      limits    per ingredient, how many of that exact item may be used

    "limits" is the interesting one. Every row starts on "auto", meaning
    "whatever the Same type at most option says". Clicking a row cycles it
    through 0, 1, 2 ... up to however many you actually have, and 0 means
    "leave that one in the fridge". So excluding an ingredient and asking
    for exactly four of another are the same control.

    Weight loss is a scoring weight, not a rule about food: among the
    things already in your kitchen it prefers the ones that fill you up
    without the calories. It does not change what any item is worth.
]]

require "AutoAll/AutoAll_Cook"
require "AutoAll/AutoAll_Cookbook"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.cookUILoaded then return end
AA.cookUILoaded = true

local Cook = AA.Cook
local Cookbook = AA.Cookbook

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

local PAD        = 10
local ROW_HGT    = FONT_HGT_SMALL + 8
local BUTTON_HGT = FONT_HGT_SMALL + 8
local WIDTH      = 470
local LIST_HGT   = 220

AA.CookUI = ISPanel:derive("AutoAllCookUI")
local CookUI = AA.CookUI

CookUI.instance = nil

---------------------------------------------------------------------
-- gathering what the window has to show
---------------------------------------------------------------------

--- The dishes this base item can become right now.
local function recipesFor(player, base, containerList)
    local out = {}
    if not base or base:isNoRecipes(player) then return out end

    local recipes = RecipeManager.getEvolvedRecipe(base, player, containerList, true)
    if not recipes then return out end

    for i = 0, recipes:size() - 1 do
        table.insert(out, recipes:get(i))
    end
    return out
end

--- One row per ingredient type, with how many of it are within reach.
---
--- Grouped by full type rather than listed item by item: eight tomatoes
--- are one line saying eight, not eight lines saying tomato.
local function ingredientRows(player, base, recipe, containerList)
    local rows, byType = {}, {}

    local items = recipe:getItemsCanBeUse(player, base, containerList)
    if not items then return rows end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item:getFullType()
        local row = byType[fullType]
        if not row then
            row = {
                fullType  = fullType,
                name      = item:getDisplayName(),
                texture   = item:getTexture(),
                available = 0,
                limit     = nil,        -- nil = auto
            }
            byType[fullType] = row
            table.insert(rows, row)
        end
        row.available = row.available + 1
    end

    table.sort(rows, function(a, b) return a.name < b.name end)
    return rows
end

---------------------------------------------------------------------
-- the window
---------------------------------------------------------------------

function CookUI:createChildren()
    ISPanel.createChildren(self)

    local x = PAD
    local y = PAD + FONT_HGT_MEDIUM + PAD
    local w = self.width - PAD * 2
    local labelW = 130

    -- Which dish
    self.recipeCombo = ISComboBox:new(x + labelW, y, w - labelW, ROW_HGT, self, CookUI.onRecipeChanged)
    self.recipeCombo:initialise()
    self:addChild(self.recipeCombo)
    for _, recipe in ipairs(self.recipes) do
        self.recipeCombo:addOptionWithData(Cook.recipeName(recipe), recipe)
    end
    y = y + ROW_HGT + 6

    -- What it is for
    self.goalCombo = ISComboBox:new(x + labelW, y, w - labelW, ROW_HGT, self, CookUI.onGoalChanged)
    self.goalCombo:initialise()
    self:addChild(self.goalCombo)
    self.goalCombo:addOptionWithData(getText("UI_AA_prio_calories"), 1)
    self.goalCombo:addOptionWithData(getText("UI_AA_prio_hunger"), 2)
    self.goalCombo:addOptionWithData(getText("UI_AA_prio_balanced"), 3)
    self.goalCombo:addOptionWithData(getText("UI_AA_goal_slim"), 4)
    self.goalCombo.selected = AA.opt("cookPriority") or 1
    y = y + ROW_HGT + 6

    -- How big
    self.sizeCombo = ISComboBox:new(x + labelW, y, w - labelW, ROW_HGT, self, nil)
    self.sizeCombo:initialise()
    self:addChild(self.sizeCombo)
    self.sizeCombo:addOptionWithData(getText("UI_AA_cook_size_auto"), 0)
    for n = 1, 12 do
        self.sizeCombo:addOptionWithData(tostring(n), n)
    end
    y = y + ROW_HGT + 6

    -- Saved plans. The combo is the cookbook; Load fills the window in
    -- from it and Forget takes the line back out of the file.
    local smallW = 70
    self.savedCombo = ISComboBox:new(x + labelW, y, w - labelW - (smallW + 4) * 2, ROW_HGT, self, nil)
    self.savedCombo:initialise()
    self:addChild(self.savedCombo)

    self.loadBtn = ISButton:new(x + w - (smallW + 4) * 2 + 4, y, smallW, ROW_HGT,
        getText("UI_AA_cook_ui_load"), self, CookUI.onLoadPlan)
    self.loadBtn:initialise()
    self:addChild(self.loadBtn)

    self.forgetBtn = ISButton:new(x + w - smallW, y, smallW, ROW_HGT,
        getText("UI_AA_cook_ui_forget"), self, CookUI.onForgetPlan)
    self.forgetBtn:initialise()
    self:addChild(self.forgetBtn)
    y = y + ROW_HGT + PAD

    self.listY = y

    self.list = ISScrollingListBox:new(x, y, w, LIST_HGT)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = ROW_HGT + 4
    self.list.drawBorder = true
    self.list.font = UIFont.Small
    self.list.doDrawItem = CookUI.drawIngredient
    self.list.target = self
    self.list.onmousedown = CookUI.onIngredientClicked
    self:installRightClick()
    self:addChild(self.list)
    y = y + LIST_HGT + 4

    self.hintY = y
    y = y + FONT_HGT_SMALL + 6

    -- Name it and keep it. Typing over an existing name replaces that
    -- plan rather than adding a second one with the same label.
    local saveW = 90
    self.nameEntry = ISTextEntryBox:new("", x, y, w - saveW - PAD, ROW_HGT)
    self.nameEntry:initialise()
    self.nameEntry:instantiate()
    self.nameEntry:setClearButton(true)
    self:addChild(self.nameEntry)

    self.saveBtn = ISButton:new(x + w - saveW, y, saveW, ROW_HGT,
        getText("UI_AA_cook_ui_save"), self, CookUI.onSavePlan)
    self.saveBtn:initialise()
    self:addChild(self.saveBtn)
    y = y + ROW_HGT + PAD

    local buttonW = (w - PAD) / 2
    self.startBtn = ISButton:new(x, y, buttonW, BUTTON_HGT, getText("UI_AA_cook_ui_start"), self, CookUI.onStart)
    self.startBtn:initialise()
    self:addChild(self.startBtn)

    self.cancelBtn = ISButton:new(x + buttonW + PAD, y, buttonW, BUTTON_HGT, getText("UI_AA_cook_ui_cancel"), self, CookUI.onCancel)
    self.cancelBtn:initialise()
    self:addChild(self.cancelBtn)

    self:setHeight(y + BUTTON_HGT + PAD)

    self:refreshSaved()
    self:refreshIngredients()
end

--- Right click steps a row back down, so overshooting is not a dead end.
---
--- Hung on the list itself rather than on the window, so it reads the
--- click through exactly the same rowAt(x, y) the built in left click
--- does and cannot disagree with it about where the rows are.
function CookUI:installRightClick()
    local window = self
    local list = self.list

    function list:onRightMouseDown(x, y)
        if #self.items == 0 then return end
        local row = self:rowAt(x, y)
        if row < 1 or row > #self.items then return end
        self.selected = row
        window:stepLimit(self.items[row].item, -1)
    end
end

function CookUI:onRecipeChanged()
    self:refreshIngredients()
end

function CookUI:onGoalChanged()
    -- Nothing to rebuild: the goal only changes how rows are scored while
    -- cooking, not which of them are on offer.
end


---------------------------------------------------------------------
-- the cookbook
--
-- The window already holds a whole plan - dish, goal, size and one
-- number per ingredient - so saving is just handing that table to
-- AutoAll_Cookbook, and loading is putting it back into the same four
-- controls. Nothing here knows about the file format.
---------------------------------------------------------------------

--- Refills the saved-plans combo from the file.
function CookUI:refreshSaved()
    if not self.savedCombo then return end

    local wanted = self:selectedPlanName()

    self.savedCombo:clear()
    self.plans = Cookbook.list()

    if #self.plans == 0 then
        -- A combo with no options at all draws as a blank box with no
        -- hint that anything is missing.
        self.savedCombo:addOptionWithData(getText("UI_AA_cook_ui_nosaved"), nil)
        self.savedCombo.selected = 1
        return
    end

    for i, plan in ipairs(self.plans) do
        self.savedCombo:addOptionWithData(plan.name, plan)
        if plan.name == wanted then self.savedCombo.selected = i end
    end
    if self.savedCombo.selected > #self.plans then self.savedCombo.selected = 1 end
end

--- The plan the combo is pointing at, or nil when the book is empty.
function CookUI:selectedPlan()
    local option = self.savedCombo and self.savedCombo.options[self.savedCombo.selected]
    return option and option.data or nil
end

function CookUI:selectedPlanName()
    local plan = self:selectedPlan()
    return plan and plan.name or nil
end

--- Everything the window currently says, as a plan.
function CookUI:currentPlan()
    local recipe = self:selectedRecipe()
    if not recipe then return nil end

    local limits = {}
    for _, row in ipairs(self.rows or {}) do
        if row.limit ~= nil then limits[row.fullType] = row.limit end
    end
    -- Choices made for ingredients this dish does not use are kept too:
    -- the window remembers them across dish changes, and a saved plan
    -- that forgot them would come back subtly different.
    for fullType, value in pairs(self.limits or {}) do
        if limits[fullType] == nil and value ~= nil then limits[fullType] = value end
    end

    local goalOption = self.goalCombo.options[self.goalCombo.selected]
    local sizeOption = self.sizeCombo.options[self.sizeCombo.selected]

    return {
        recipeId = recipe:getUntranslatedName(),
        goal     = goalOption and goalOption.data or 1,
        maxItems = sizeOption and sizeOption.data or 0,
        limits   = limits,
    }
end

function CookUI:onSavePlan()
    local name = Cookbook.cleanName(self.nameEntry and self.nameEntry:getInternalText())
    if not name then
        -- Falling back to the dish name means the button always does
        -- something, which is better than a button that silently ignores
        -- you because a box above it is empty.
        local recipe = self:selectedRecipe()
        name = recipe and Cookbook.cleanName(Cook.recipeName(recipe)) or nil
    end
    if not name then return end

    local plan = self:currentPlan()
    if not plan then return end

    if Cookbook.save(name, plan) then
        if self.nameEntry then self.nameEntry:setText(name) end
        self:refreshSaved()
        for i, saved in ipairs(self.plans or {}) do
            if saved.name == name then self.savedCombo.selected = i end
        end
    end
end

function CookUI:onForgetPlan()
    local plan = self:selectedPlan()
    if not plan then return end
    Cookbook.delete(plan.name)
    self:refreshSaved()
end

--- Puts a saved plan back into the four controls.
---
--- The dish is matched by its untranslated name, and it can genuinely
--- be missing: the combo only lists what this base item can become with
--- what is within reach right now, so a stir fry saved in a stocked
--- kitchen is not on offer in an empty one. Everything else is applied
--- regardless, so the plan is still there when the ingredients are.
function CookUI:onLoadPlan()
    local plan = self:selectedPlan()
    if not plan then return end

    for i, recipe in ipairs(self.recipes or {}) do
        if recipe:getUntranslatedName() == plan.recipeId then
            self.recipeCombo.selected = i
            break
        end
    end

    for i, option in ipairs(self.goalCombo.options) do
        if option.data == plan.goal then self.goalCombo.selected = i break end
    end

    for i, option in ipairs(self.sizeCombo.options) do
        if option.data == (plan.maxItems or 0) then self.sizeCombo.selected = i break end
    end

    -- Replaced wholesale rather than merged: loading a plan should give
    -- you that plan, not that plan plus whatever was on screen before.
    self.limits = {}
    for fullType, value in pairs(plan.limits or {}) do
        self.limits[fullType] = value
    end

    if self.nameEntry then self.nameEntry:setText(plan.name) end
    self:refreshIngredients()
end
function CookUI:selectedRecipe()
    local option = self.recipeCombo and self.recipeCombo.options[self.recipeCombo.selected]
    return option and option.data or self.recipes[1]
end

--- Rebuilds the ingredient list, keeping whatever the player already
--- decided about each one.
---
--- The keeping is the fix for "it included ingredients I set to be left
--- out". This function rebuilds self.rows from scratch, and it runs on
--- every dish change - so setting butter to skip and then picking a
--- different dish threw the choice away silently, with the window still
--- looking like it had been made. The player had no way to see it had
--- been lost.
---
--- The decisions live on the window keyed by item type, not on the row
--- objects, so they survive any number of rebuilds. A type that is not on
--- offer for the new dish simply never gets asked about, and its entry
--- sits there harmlessly in case the player switches back.
function CookUI:refreshIngredients()
    self.list:clear()
    self.limits = self.limits or {}

    local recipe = self:selectedRecipe()
    if not recipe then return end

    local containerList = Cook.getContainers(self.player)
    self.rows = ingredientRows(self.player, self.base, recipe, containerList)

    for _, row in ipairs(self.rows) do
        local remembered = self.limits[row.fullType]
        if remembered ~= nil then
            -- Clamped, because the count within reach can have changed
            -- since the choice was made - something was eaten, or a bag
            -- was closed. "Skip" is 0 and always survives.
            row.limit = math.min(remembered, row.available)
        end
        self.list:addItem(row.name, row)
    end
end

--- Cycles one row: auto -> 0 -> 1 -> ... -> however many you have -> auto.
function CookUI:stepLimit(row, direction)
    if not row then return end

    local steps = { false }         -- false stands in for "auto"
    for n = 0, row.available do
        table.insert(steps, n)
    end

    local at = 1
    for i, value in ipairs(steps) do
        if (value == false and row.limit == nil) or (value ~= false and row.limit == value) then
            at = i
            break
        end
    end

    at = at + direction
    if at > #steps then at = 1 end
    if at < 1 then at = #steps end

    local chosen = steps[at]
    row.limit = (chosen == false) and nil or chosen

    -- Remembered on the window, so a dish change does not throw it away.
    self.limits = self.limits or {}
    self.limits[row.fullType] = row.limit
end

function CookUI.onIngredientClicked(self, row)
    self:stepLimit(row, 1)
end

--- One list row: the icon, the name, how many you have, and what the
--- window is going to do with them.
function CookUI.drawIngredient(list, y, item, alt)
    local row = item.item
    if not row then return y + item.height end

    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), item.height - 1, 0.3, 0.7, 0.35, 0.15)
    elseif alt then
        list:drawRect(0, y, list:getWidth(), item.height - 1, 0.1, 1, 1, 1)
    end

    local textY = y + (item.height - FONT_HGT_SMALL) / 2

    if row.texture then
        list:drawTextureScaled(row.texture, 4, y + 2, item.height - 6, item.height - 6, 1, 1, 1, 1)
    end

    list:drawText(row.name, item.height + 4, textY, 1, 1, 1, 1, UIFont.Small)

    local right
    if row.limit == nil then
        right = getText("UI_AA_cook_ui_auto", row.available)
        list:drawTextRight(right, list:getWidth() - 8, textY, 0.75, 0.75, 0.75, 1, UIFont.Small)
    elseif row.limit == 0 then
        right = getText("UI_AA_cook_ui_skip")
        list:drawTextRight(right, list:getWidth() - 8, textY, 1, 0.5, 0.5, 1, UIFont.Small)
    else
        right = getText("UI_AA_cook_ui_use", row.limit, row.available)
        list:drawTextRight(right, list:getWidth() - 8, textY, 0.5, 1, 0.5, 1, UIFont.Small)
    end

    return y + item.height
end

function CookUI:render()
    self:drawText(getText("UI_AA_cook_ui_title"), PAD, PAD, 1, 1, 1, 1, UIFont.Medium)

    local labelY = PAD + FONT_HGT_MEDIUM + PAD
    local dy = ROW_HGT + 6
    local pad = (ROW_HGT - FONT_HGT_SMALL) / 2

    self:drawText(getText("UI_AA_cook_ui_dish"), PAD, labelY + pad, 1, 1, 1, 1, UIFont.Small)
    self:drawText(getText("UI_AA_cook_ui_goal"), PAD, labelY + dy + pad, 1, 1, 1, 1, UIFont.Small)
    self:drawText(getText("UI_AA_cook_ui_size"), PAD, labelY + dy * 2 + pad, 1, 1, 1, 1, UIFont.Small)
    self:drawText(getText("UI_AA_cook_ui_saved"), PAD, labelY + dy * 3 + pad, 1, 1, 1, 1, UIFont.Small)

    self:drawText(getText("UI_AA_cook_ui_hint"), PAD, self.hintY, 0.7, 0.7, 0.7, 1, UIFont.Small)
end

function CookUI:onStart()
    local recipe = self:selectedRecipe()
    if not recipe then
        self:onCancel()
        return
    end

    local limits = {}
    for _, row in ipairs(self.rows or {}) do
        if row.limit ~= nil then limits[row.fullType] = row.limit end
    end

    local goalOption = self.goalCombo.options[self.goalCombo.selected]
    local sizeOption = self.sizeCombo.options[self.sizeCombo.selected]

    local plan = {
        goal     = goalOption and goalOption.data or nil,
        maxItems = sizeOption and sizeOption.data or 0,
        limits   = limits,
    }
    if plan.maxItems == 0 then plan.maxItems = nil end

    local player = self.player
    local base   = self.base
    local id     = recipe:getUntranslatedName()

    self:onCancel()
    Cook.start(player, base, id, plan)
end

function CookUI:onCancel()
    self:setVisible(false)
    self:removeFromUIManager()
    if CookUI.instance == self then CookUI.instance = nil end
end

function CookUI:new(player, base, recipes)
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()

    local o = ISPanel:new((screenW - WIDTH) / 2, (screenH - 500) / 2, WIDTH, 500)
    setmetatable(o, self)
    self.__index = self

    o.player  = player
    o.base    = base
    o.recipes = recipes
    o.rows    = {}

    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    o.borderColor     = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.moveWithMouse   = true

    return o
end

--- Opens the window, replacing one already on screen.
function CookUI.open(player, base)
    if CookUI.instance then CookUI.instance:onCancel() end

    local containerList = Cook.getContainers(player)
    local recipes = recipesFor(player, base, containerList)
    if #recipes == 0 then
        HaloTextHelper.addBadText(player, getText("UI_AA_cook_noingredients"))
        return
    end

    local window = CookUI:new(player, base, recipes)
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    CookUI.instance = window
end

---------------------------------------------------------------------
-- context menu
---------------------------------------------------------------------

Cook.onSetup = function(player, base)
    CookUI.open(player, base)
end

local function addCookSetupMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    if AA.isRunning(player, "cook") then return end

    local actual = ISInventoryPane.getActualItems(items)
    local base = actual and actual[1]
    if not base or not instanceof(base, "InventoryItem") then return end
    if base:isNoRecipes(player) then return end

    local containerList = Cook.getContainers(player)
    local recipes = RecipeManager.getEvolvedRecipe(base, player, containerList, true)
    if not recipes or recipes:size() == 0 then return end

    local option = AA.addOption(context, getText("UI_AA_cook_setup"), player, Cook.onSetup, base)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.description = getText("UI_AA_cook_setup_tt")
    option.toolTip = tooltip
end

AA.registerMenu("cook", Events.OnFillInventoryObjectContextMenu, addCookSetupMenu)
