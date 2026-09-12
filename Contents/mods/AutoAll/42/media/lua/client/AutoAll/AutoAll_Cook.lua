--[[
    Auto All - Cook (Build 42 / SP + MP)
    ------------------------------------------------------------------
    "Auto Cook" on any evolved recipe container (pot, bowl, frying pan,
    griddle pan, bucket...).

    The character keeps queueing the vanilla ISAddItemInRecipe until the
    dish is full. Ingredients are picked one at a time, always re-reading
    what the game says is usable, because every ingredient turns the base
    item into a new item (an empty Bowl becomes a Salad, and so on).

    The picker spreads the food types on purpose: piling five carrots in
    a salad is what makes the meal depressing to eat, so a second copy of
    the same ingredient (or of the same food type) is worth much less
    than a new flavour.

    The finished dish is left in the inventory. Ingredients borrowed from
    a cupboard or a fridge go back there once the meal is done.
]]

require "AutoAll/AutoAll_Core"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.cookLoaded then return end
AA.cookLoaded = true

AA.Cook = AA.Cook or {}
local Cook = AA.Cook

local MAX_ITERATIONS = 30       -- hard stop, no matter what the recipe says

-- Calories vs. hunger weighting for each goal. 1-3 are the values the
-- "priority" option has always used; 4 is the one the setup window adds.
--
-- Slimming down is the same maths with the calorie weight turned negative:
-- among ingredients that fill you up just as well, the leaner one wins.
-- Nothing about the food changes - this only decides which of the things
-- already in your fridge goes in the pot.
local PRIORITY = {
    [1] = { calories =  1.00, hunger = 120 },   -- gain weight (calories)
    [2] = { calories =  0.15, hunger = 600 },   -- fill up (hunger)
    [3] = { calories =  0.60, hunger = 350 },   -- balanced
    [4] = { calories = -0.90, hunger = 500 },   -- lose weight
}

Cook.GOALS = 4

---------------------------------------------------------------------
-- item accessors
--
-- Only Food answers getSpices/getCalories/getFoodType/isRotten and
-- friends. An empty Pot or a script-item spice is a plain InventoryItem,
-- so every Food getter is guarded the same way the vanilla context menu
-- guards them. Calling them blindly inside pcall still dumps a Lua stack
-- trace to the console on every single call, which is what filled the
-- log with errors.
---------------------------------------------------------------------

local function asFood(item)
    if item and instanceof(item, "Food") then return item end
    return nil
end

--- Number of things already inside the dish (ingredients + spices).
local function contentCount(item)
    local food = asFood(item)
    if not food then return 0 end

    local count = 0
    local extras = food:getExtraItems()
    if extras then count = count + extras:size() end
    local spices = food:getSpices()
    if spices then count = count + spices:size() end
    return count
end

local function extraCount(item)
    local food = asFood(item)
    if not food then return 0 end
    local extras = food:getExtraItems()
    return extras and extras:size() or 0
end

--- Same test doEvorecipeMenu uses: Food knows, everything else asks its script.
--- Does the game itself call this a Spice?
---
--- Separate from isSpiceItem below, and the difference matters.
--- isSpiceItem answers "is this only seasoning", which decides which PATH
--- an ingredient takes through the picker. This answers "did the scripts
--- mark it Spice", which is what the cookSpices tickbox is about.
---
--- Reported by Sneed: "auto cook seems to ignore seasoning config: i
--- disabled it but he still uses some seasoning like mustard and
--- jalapeno". Both of those are Spice AND carry calories - Mustard is 510,
--- Jalapeno is 15 - so routing nutritious spices down the food path (which
--- is what makes butter usable, see below) would walk them straight past
--- the tickbox. The switch has to be asked on both paths, not on one.
local function isScriptSpice(item)
    local food = asFood(item)
    if food then return food:isSpice() == true end
    local script = item:getScriptItem()
    return script ~= nil and script:isSpice() == true
end

--- Seasoning: a spice that is only there for the flavour.
---
--- "Spice" in the scripts is not the same thing as "seasoning", and that
--- difference is the whole of the "it ignores my 20 sticks of butter when
--- I choose to prioritize calories" report. Butter is
---
---     Spice = true, Calories = 3200, HungerChange = -24
---
--- so it went down the spice path: one per dish, inside a budget of three
--- seasonings, no matter what the goal was - while being by a distance the
--- most calorie dense ingredient in the game. Vanilla itself does not
--- treat it as a garnish; its own evolved recipes accept Butter:4.
---
--- Calories separate the two cleanly. Salt and Pepper are Spice with no
--- Calories line at all; Sugar is 387 and Butter is 3200. So a spice with
--- calories is food, gets scored like food, and obeys the ordinary
--- per-ingredient allowance instead of the seasoning budget.
---
--- Nothing about what it costs, gives or how the game consumes it
--- changes. Only our own cap on it does.
local function isSpiceItem(item)
    local food = asFood(item)
    if food then
        if food:isSpice() ~= true then return false end
        local ok, calories = pcall(function() return food:getCalories() end)
        if ok and type(calories) == "number" and calories > 0 then
            return false
        end
        return true
    end
    local script = item:getScriptItem()
    return script ~= nil and script:isSpice() == true
end

local function foodTypeOf(item)
    local food = asFood(item)
    if not food then return nil end
    local foodType = food:getFoodType()
    if type(foodType) == "string" and foodType ~= "" then return foodType end
    return nil
end

---------------------------------------------------------------------
-- recipe lookup
---------------------------------------------------------------------

--- How far out to look for cupboards, counters and fridges, in tiles.
local REACH = 2

--- Every container the character can reasonably reach.
---
--- ISInventoryPaneContextMenu.getContainers() only returns what the UI is
--- currently showing: the player's own bags plus whatever is open in the
--- loot window. That is why the reports said "the only storage it accesses
--- is the one I am standing in front of" - because that was literally
--- true. Standing between a counter and a fridge, only one of them was in
--- the window, so only one was searched.
---
--- So the squares around the character are scanned as well and any
--- container found on them is added. Duplicates are filtered by identity,
--- since the same container is usually in both lists.
function Cook.getContainers(player)
    local list = ISInventoryPaneContextMenu.getContainers(player) or ArrayList.new()

    local square = player:getSquare()
    local cell = getCell()
    if not square or not cell then return list end

    local seen = {}
    for i = 0, list:size() - 1 do
        seen[list:get(i)] = true
    end

    local z = square:getZ()
    for dx = -REACH, REACH do
        for dy = -REACH, REACH do
            local sq = cell:getGridSquare(square:getX() + dx, square:getY() + dy, z)
            if sq then
                local objects = sq:getObjects()
                for j = 0, objects:size() - 1 do
                    local container = objects:get(j):getContainer()
                    if container and not seen[container] then
                        seen[container] = true
                        list:add(container)
                    end
                end
            end
        end
    end

    return list
end

--- Finds the recipe we are cooking again on the *new* base item.
function Cook.findRecipe(player, base, recipeId, containerList)
    if not base then return nil end
    if base:isNoRecipes(player) then return nil end

    local recipes = RecipeManager.getEvolvedRecipe(base, player, containerList, true)
    if not recipes or recipes:size() == 0 then return nil end

    local fallback = nil
    for i = 0, recipes:size() - 1 do
        local recipe = recipes:get(i)
        if recipe:getUntranslatedName() == recipeId then return recipe end
        if fallback == nil and recipe:isResultItem(base) then fallback = recipe end
    end
    return fallback
end

function Cook.recipeName(recipe)
    local key = "ContextMenu_EvolvedRecipe_" .. recipe:getUntranslatedName()
    local name = getText(key)
    if name == key then name = recipe:getUntranslatedName() end
    return name
end

---------------------------------------------------------------------
-- ingredient picking
---------------------------------------------------------------------

--- Unhappiness this ingredient would bring to the dish (0 for non-food).
local function unhappyOf(item)
    local food = asFood(item)
    return food and food:getUnhappyChange() or 0
end

--- True once the character is a good enough cook to get away with
--- ingredients that would otherwise be left in the fridge.
function Cook.canUseBadIngredients(player)
    local from = AA.opt("cookBadFromLevel") or 0
    if from <= 0 then return false end
    return player:getPerkLevel(Perks.Cooking) >= from
end

--- Hard filter: things the game or the options forbid outright.
local function isAllowed(task, recipe, item)
    if item == nil or item == task.base then return false end
    if item:getID() == task.base:getID() then return false end

    -- Vanilla greys out the option when this returns false ("needs cooking").
    if not recipe:needToBeCooked(item) then return false end

    if AA.opt("cookSkipFavorite") and item:isFavorite() then return false end

    local food = asFood(item)
    if not food then return true end

    if food:isFrozen() and not recipe:isAllowFrozenItem() then return false end

    -- A skilled cook knows what to do with the sad end of the pantry.
    -- Poison is never on the table, however good you are.
    local skilled = task.badIngredients

    if AA.opt("cookSkipRotten") and not skilled then
        if food:isRotten() or food:isBurnt() or food:isTainted() then return false end
    end

    if AA.opt("cookSkipPoison") then
        if food:isPoison() or food:getPoisonPower() > 0 then return false end
    end

    return true
end

--- How many of this ingredient the dish may take.
---
--- The setup window writes one number per ingredient here, and 0 means
--- "leave that one alone". Anything it did not mention falls back to the
--- "same type at most" option, which is what the quick entry uses for
--- everything.
local function allowanceFor(task, item)
    local limit = task.limits and task.limits[item:getFullType()]
    if limit ~= nil then return limit end
    return AA.opt("cookSameTypeMax") or 2
end

---------------------------------------------------------------------
-- using up what is about to turn
--
-- > *Tourette:* "maybe also an option to use ingredients sorted by
-- > freshest (so a tomato that has only 2 hours freshness will be
-- > prioritized)"
--
-- The example is the definition: the tomato with two hours left goes in
-- the pot before the one with six days, because in six days the second
-- one is still food and the first is compost.
--
-- The number comes off the item rather than out of a formula. age,
-- offAge and offAgeMax are all in in-game hours; HowRotten() is
-- (age - offAge) / (offAgeMax - offAge), read from the bytecode, so it
-- only starts moving once the food is already stale. What matters here
-- is the hours left before it is stale at all, which is offAge - age.
--
-- Frozen food does not age, and food the game says cannot age has no
-- clock to run down; both are simply not urgent.
---------------------------------------------------------------------

-- How close to spoiling something has to be before it starts jumping the
-- queue, in in-game hours. Two days: long enough to catch the vegetables
-- a fridge is about to lose, short enough that a fresh tin of beans is
-- never treated as an emergency.
local SPOIL_WINDOW = 48

-- Deliberately larger than the variety penalties (250 for a repeated
-- item, 120 for a repeated food type), so something genuinely about to
-- turn outranks a more varied choice - which is the whole point of the
-- option - while still losing to a rotten or depressing ingredient,
-- because those are excluded before the scoring rather than by it.
local SPOIL_WEIGHT = 1000

--- 0 for anything with its life ahead of it, rising to 1 as the last
--- hours run out.
local function urgencyOf(item)
    local food = asFood(item)
    if not food then return 0 end

    local ok, urgency = pcall(function()
        if food:isFrozen() then return 0 end
        if not food:canAge() then return 0 end

        local offAge = food:getOffAge() or 0
        if offAge <= 0 then return 0 end

        local left = offAge - (food:getAge() or 0)
        if left <= 0 then return 1 end
        if left >= SPOIL_WINDOW then return 0 end
        return 1 - (left / SPOIL_WINDOW)
    end)

    return (ok and type(urgency) == "number") and urgency or 0
end

local function scoreOf(task, item)
    local weights = PRIORITY[task.goal] or PRIORITY[AA.opt("cookPriority")] or PRIORITY[1]
    local food = asFood(item)

    local score = 0
    if food then
        local calories = food:getCalories()
        local hunger   = -food:getHungChange()      -- positive = fills you up
        score = calories * weights.calories + hunger * weights.hunger
        score = score - food:getUnhappyChange() * 12 - food:getBoredomChange() * 6
        if food:isCooked() then score = score + 60 end
    end

    -- Use it before it is lost. Off by default; see urgencyOf.
    if AA.opt("cookSpoilFirst") == true then
        score = score + urgencyOf(item) * SPOIL_WEIGHT
    end
    -- Variety. This is the whole point of the picker: the same ingredient
    -- twice, or the same food type twice, is worth far less than a new one.
    score = score - (task.usedTypes[item:getFullType()] or 0) * 250
    local foodType = foodTypeOf(item)
    if foodType then
        score = score - (task.usedFoodTypes[foodType] or 0) * 120
    end

    return score
end

--- Picks the next thing to drop in the pot, or nil when the dish is done.
--- Returns item, isSpice.
function Cook.pickNext(task, recipe, containerList)
    local items = recipe:getItemsCanBeUse(task.player, task.base, containerList)
    if not items or items:size() == 0 then return nil end

    local maxItems = recipe:getMaxItems() or 0
    local configMax = task.maxItems or AA.opt("cookMaxIngredients") or 0
    if configMax > 0 and (maxItems == 0 or configMax < maxItems) then maxItems = configMax end

    local roomForFood = maxItems == 0 or extraCount(task.base) < maxItems
    local spicesOn    = AA.opt("cookSpices") == true
    local spiceMax    = AA.opt("cookSpiceMax") or 3

    local food, foodScore = nil, nil
    -- A spice that carries calories - butter, mustard, sugar, oil. It is
    -- scored as food, because that is the only way butter competes at all,
    -- but it is picked only when there is no real ingredient left and it
    -- still spends a place from the seasoning budget. See the block above
    -- isSpiceItem, and the 2026-08-31 note in AutoAll.md.
    local spiceFood, spiceFoodScore = nil, nil
    local spice = nil
    local hasKindOption = false     -- some candidate does not make the meal sadder

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        -- "Season the dish" off means nothing the scripts call a Spice goes
        -- in, whichever path it would have taken. Checked here, once, so
        -- neither branch below can leak.
        if isAllowed(task, recipe, item) and (spicesOn or not isScriptSpice(item)) then
            if isSpiceItem(item) then
                -- One of each spice, never the same one twice - unless the
                -- setup window asked for a different number.
                if spicesOn and spice == nil and task.spices < spiceMax
                        and (task.usedTypes[item:getFullType()] or 0) < math.max(1, allowanceFor(task, item))
                        and allowanceFor(task, item) > 0 then
                    spice = item
                end
            elseif roomForFood and (task.usedTypes[item:getFullType()] or 0) < allowanceFor(task, item) then
                if unhappyOf(item) <= 0 then
                    hasKindOption = true
                end
                local score = scoreOf(task, item)
                if isScriptSpice(item) then
                    -- Still a seasoning, however many calories it carries.
                    if task.spices < spiceMax
                            and (spiceFoodScore == nil or score > spiceFoodScore) then
                        spiceFood, spiceFoodScore = item, score
                    end
                elseif foodScore == nil or score > foodScore then
                    food, foodScore = item, score
                end
            end
        end
    end

    -- Only refuse depressing ingredients while a pleasant one is still on
    -- the table: an all-raw-vegetables pantry should still get cooked.
    -- A skilled cook does not bother being fussy at all.
    if food and hasKindOption and AA.opt("cookSkipUnhappy")
            and not task.badIngredients and unhappyOf(food) > 0 then
        food, foodScore = nil, nil
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if isAllowed(task, recipe, item) and not isScriptSpice(item)
                    and (task.usedTypes[item:getFullType()] or 0) < allowanceFor(task, item)
                    and unhappyOf(item) <= 0 then
                local score = scoreOf(task, item)
                if foodScore == nil or score > foodScore then
                    food, foodScore = item, score
                end
            end
        end
    end

    -- Order matters, and this is the whole of the seasoning report.
    --
    -- > *Poodmund:* "when I Auto Cook a Salad, it ends up adding too many
    -- > seasonings i.e. 6 ingredients + 11 seasonings"
    -- > *Serfis:* "it puts all seasonings it has available before adding
    -- > the normal ingredients"
    --
    -- Both come from the same line. Ketchup, mustard, mayonnaise, sugar,
    -- oil and butter are all Spice with calories, so the 2026-08-19 butter
    -- fix sent every one of them down the food path - where they obeyed
    -- the per-ingredient allowance instead of the seasoning budget, and
    -- where, with the default "pick for calories" goal, they outscored
    -- every vegetable in the fridge and went in first.
    --
    -- A real ingredient now always wins the slot, a seasoning is taken
    -- only when nothing else is left, and the budget applies to it
    -- whichever path it took.
    if food then return food, false end
    if spiceFood then return spiceFood, true end
    if spice then return spice, true end
    return nil
end

---------------------------------------------------------------------
-- the loop
---------------------------------------------------------------------

--- Counted here rather than from the picker's own answer, because the
--- picker has two paths a seasoning can take and only one of them used to
--- reach the seasoning budget. The scripts decide, once, for both.
local function rememberUsed(task, item)
    local fullType = item:getFullType()
    task.usedTypes[fullType] = (task.usedTypes[fullType] or 0) + 1
    local foodType = foodTypeOf(item)
    if foodType then
        task.usedFoodTypes[foodType] = (task.usedFoodTypes[foodType] or 0) + 1
    end
    if isScriptSpice(item) then
        task.spices = task.spices + 1
    else
        task.ingredients = task.ingredients + 1
    end
end

local function queueAdd(task, recipe, item)
    local player = task.player

    if not AA.holds(player, item) then
        -- Remember where it came from so leftovers can go home afterwards.
        --
        -- Keyed by id, not by the item object. On a server the instance is
        -- replaced as the transfer settles, so the object stored here is a
        -- different Lua/Java pair from the one sitting in the inventory a
        -- moment later - which is why the returning phase kept reporting
        -- nothing left to send back while the ingredients were plainly
        -- still in the bag.
        local home = item:getContainer()
        if home and home ~= player:getInventory() then
            task.borrowed[item:getID()] = { home = home, name = item:getFullType() }
        end
        ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(
                player, item, item:getContainer(), player:getInventory(), nil))
        if instanceof(item, "Food") then item:setChef(player:getUsername()) end
    end
    if not AA.holds(player, task.base) then
        ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(
                player, task.base, task.base:getContainer(), player:getInventory(), nil))
        if instanceof(task.base, "Food") then task.base:setChef(player:getUsername()) end
    end

    local action = ISAddItemInRecipe:new(player, recipe, task.base, item)

    -- Vanilla's ISAddItemInRecipe plays a sound but never sets an action
    -- animation, so the character just stands there. Craft is the stock
    -- animation for working on something held, so the cooking finally looks
    -- like cooking. Patched on this instance only - adding an ingredient by
    -- hand keeps behaving exactly as the base game does.
    local originalStart = action.start
    action.start = function(self)
        originalStart(self)
        self:setActionAnim(CharacterActionAnims.Craft)
    end

    ISTimedActionQueue.add(action)

    task.pending      = action
    task.pendingItem  = item
    task.lastCount    = contentCount(task.base)
end

---------------------------------------------------------------------
-- putting the leftovers back
--
-- This is where multiplayer differs, and it is worth writing down.
--
-- ISInventoryTransferAction:isValid() contains
--
--     if not self.started and not isItemTransactionConsistent(...) then
--         return false
--     end
--
-- and isItemTransactionConsistent starts with "if not GameClient.client
-- then return true". So in single player the check does not exist at
-- all, while on a server it asks the TransactionManager whether that
-- item still has a transfer in flight. Queue the trip home too soon
-- after the ingredient was fetched and the action is simply thrown away
-- - no error, no message, the food just never goes back.
--
-- Rather than special casing multiplayer, the job now checks whether the
-- leftovers actually arrived and asks again if they did not. Single
-- player succeeds first time and notices no difference.
---------------------------------------------------------------------

local RETURN_ATTEMPTS = 5

--- Borrowed items that are still sitting in the inventory.
---
--- Every one is looked up again by id. That is the multiplayer fix: the
--- object handed to us when the ingredient was fetched is not the object
--- the inventory holds once the transfer has settled, so both the "is it
--- still here" test and the transfer itself have to use the current one.
local function pendingReturns(task)
    local player = task.player
    local inventory = player:getInventory()
    local baseId = task.base and task.base:getID()
    local out = {}

    for id, entry in pairs(task.borrowed) do
        if id ~= baseId and entry.home then
            local ok, item = pcall(function() return inventory:getItemById(id) end)
            if ok and item and item:getContainer() ~= entry.home then
                out[#out + 1] = { item = item, home = entry.home }
            end
        end
    end
    return out
end

local function queueReturns(task)
    local player = task.player

    -- Vanilla's own rule, kept: a disorganized character does not tidy up
    -- after itself. ISCraftingUI.ReturnItemToContainer opens with the same
    -- test, and honouring it is the difference between automating the
    -- clicking and rewriting the trait.
    if player:hasTrait(CharacterTrait.DISORGANIZED) then return 0 end

    local pending = pendingReturns(task)
    for _, entry in ipairs(pending) do
        -- Not ISCraftingUI.ReturnItemToContainer: that one hardcodes the
        -- main inventory as the source container, and an ingredient that
        -- settled into a backpack is then transferred from somewhere it is
        -- not. The action's own source has to be where the item actually
        -- is. setAllowMissingItems is what ReturnItemToContainer sets too,
        -- and it is what stops a half-eaten ingredient from failing the
        -- whole transfer.
        local action = ISInventoryTransferUtil.newInventoryTransferAction(
                player, entry.item, entry.item:getContainer(), entry.home, nil)
        if action then
            action:setAllowMissingItems(true)
            ISTimedActionQueue.add(action)
        end
    end
    return #pending
end

--- The dish is done. Hand over to the returning phase instead of
--- stopping outright, so the leftovers can be chased up.
local function finish(task, text)
    if not AA.opt("cookReturnItems") then
        AA.stop(task.player, text, false)
        return
    end
    task.doneText = text
    task.phase    = "returning"
end

local function think(task)
    local player = task.player

    -- Waiting on the action we queued last tick.
    if task.pending then
        if ISTimedActionQueue.hasAction(task.pending) then return end

        local newBase = task.pending.baseItem
        local grew = newBase ~= nil and contentCount(newBase) > task.lastCount

        if not grew then
            AA.stop(player, getText("UI_AA_cook_interrupted"), true)
            return
        end

        rememberUsed(task, task.pendingItem)
        task.base    = newBase
        task.pending = nil
        task.pendingItem = nil
    end

    -- Transfers, walking to a counter, anything else: let the queue finish.
    if AA.isQueueBusy(player) then return end

    -- Cooking is over; see the leftovers home before finishing.
    if task.phase == "returning" then
        local left = #pendingReturns(task)
        if left == 0 then
            AA.stop(player, task.doneText, false)
            return
        end

        task.returnTries = (task.returnTries or 0) + 1
        if task.returnTries > RETURN_ATTEMPTS then
            -- Refused every time. Say so rather than quietly leaving the
            -- ingredients in a bag the player thought was empty.
            AA.stop(player, getText("UI_AA_cook_return_failed", left), true)
            return
        end

        queueReturns(task)
        return
    end

    if task.ingredients + task.spices >= MAX_ITERATIONS then
        finish(task, getText("UI_AA_cook_done", task.ingredients, task.spices))
        return
    end

    local containerList = Cook.getContainers(player)
    local recipe = Cook.findRecipe(player, task.base, task.recipeId, containerList)
    if not recipe then
        finish(task, getText("UI_AA_cook_done", task.ingredients, task.spices))
        return
    end

    local item = Cook.pickNext(task, recipe, containerList)
    if not item then
        finish(task, getText("UI_AA_cook_done", task.ingredients, task.spices))
        return
    end

    AA.reason(task, getText("UI_AA_cook_adding", item:getDisplayName()))
    queueAdd(task, recipe, item)
end

--- Tidies up once the dish is finished.
---
--- The finished dish stays in the inventory - it is what the player asked
--- for, and putting the pot back on a counter just means fetching it again.
--- What does go home is the leftovers: a part used spice or an ingredient
--- the recipe did not swallow whole, taken out of someone's cupboard.
--- Called on every stop, including when the player walks off or presses
--- ESC. The returning phase above handles the tidy ending; this is the
--- best effort for an abort, where there is no loop left to check up on.
local function onStop(task)
    if not AA.opt("cookReturnItems") then return end
    queueReturns(task)
end

--- @param plan table|nil  what the setup window collected:
---        { goal = 1..4, maxItems = n, limits = { [fullType] = n } }
---        nil means "use the mod options", which is what the quick
---        context menu entry does.
function Cook.start(player, base, recipeId, plan)
    if not player or not base then return end

    local containerList = Cook.getContainers(player)
    local recipe = Cook.findRecipe(player, base, recipeId, containerList)
    if not recipe then return end

    plan = plan or {}

    local task = {
        kind          = "cook",
        phase         = "cooking",
        returnTries   = 0,
        player        = player,
        base          = base,
        recipeId      = recipeId,
        goal          = plan.goal,
        maxItems      = plan.maxItems,
        limits        = plan.limits,
        borrowed      = {},     -- [item] = the container it was taken from
        badIngredients = Cook.canUseBadIngredients(player),
        usedTypes     = {},
        usedFoodTypes = {},
        ingredients   = 0,
        spices        = 0,
        -- A single action that never ends freezes the whole job in
        -- silence: think() is gated on the queue draining, so nothing
        -- is ever said and nothing is written to the log. Reported by
        -- Talkierplacebo2 on a hosted game - ripping and healing
        -- "gets to 99% done and never continues". AA.queueStalled
        -- clears a head that has not moved in this long, and gives up
        -- with a message after three of them rather than grinding on.
        stallTimeout  = 45000,
        lastCount     = contentCount(base),
        think         = think,
        onStop        = onStop,
        allowMove     = true,   -- cooking walks to counters and fridges on its own
        startText     = getText("UI_AA_cook_started", Cook.recipeName(recipe)),
    }

    AA.startTask(task)
end

---------------------------------------------------------------------
-- context menu
---------------------------------------------------------------------

Cook.onStart = function(player, base, recipeId)
    Cook.start(player, base, recipeId)
end

Cook.onStop = function(player)
    AA.stop(player, getText("UI_AA_stopped"), false)
end

local function addCookMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local actual = ISInventoryPane.getActualItems(items)
    local base = actual and actual[1]
    if not base or not instanceof(base, "InventoryItem") then return end

    if AA.isRunning(player, "cook") then
        AA.addOption(context, getText("UI_AA_cook_stop"), player, Cook.onStop)
        return
    end
    -- "Hide recipes" is set on this item, so say so instead of vanishing.
    --
    -- This is the likeliest cause of "Auto Cook just disappeared for some
    -- players". isNoRecipes reads the item's own modData and compares the
    -- stored value against player:getFullName():
    --
    --     rawget(getNoRecipesModDataString()) == player:getFullName()
    --
    -- It is vanilla's own "Don't show recipes" toggle, one click away in
    -- the same right click menu and easy to hit by accident. The flag
    -- lives on the *item*, so on a server it travels with the pot from
    -- container to container and player to player, and it is matched by
    -- character name rather than by id. Vanilla's evolved-recipe menu
    -- checks it too (ISInventoryPaneContextMenu.lua:332), so the base
    -- game's cooking options vanish at the same moment - which is exactly
    -- why this gets reported as a mod bug.
    --
    -- Nothing here touches the flag. It just stops being a silent exit.
    if base:isNoRecipes(player) then
        local hidden = AA.addOption(context, getText("UI_AA_cook_option_hidden"))
        hidden.notAvailable = true
        local hiddenTip = ISInventoryPaneContextMenu.addToolTip()
        hiddenTip.description = getText("UI_AA_cook_norecipes")
        hidden.toolTip = hiddenTip
        return
    end

    local containerList = Cook.getContainers(player)
    local recipes = RecipeManager.getEvolvedRecipe(base, player, containerList, true)
    if not recipes or recipes:size() == 0 then return end

    for i = 0, recipes:size() - 1 do
        local recipe = recipes:get(i)
        local usable = recipe:getItemsCanBeUse(player, base, containerList)
        local count = usable and usable:size() or 0

        local option = AA.addOption(context,
                getText("UI_AA_cook_option", Cook.recipeName(recipe)),
                player, Cook.onStart, base, recipe:getUntranslatedName())
        local tooltip = ISInventoryPaneContextMenu.addToolTip()

        -- Greyed out with the reason instead of vanishing: an option that
        -- silently disappears looks like a broken mod.
        if count == 0 then
            option.notAvailable = true
            tooltip.description = getText("UI_AA_cook_noingredients")
        else
            tooltip.description = getText("UI_AA_cook_option_tt", recipe:getMaxItems() or 0, count)
            if Cook.canUseBadIngredients(player) then
                tooltip.description = tooltip.description .. " <LINE> " .. getText("UI_AA_cook_skilled")
            end
        end
        option.toolTip = tooltip
    end
end

AA.registerMenu("cook", Events.OnFillInventoryObjectContextMenu, addCookMenu)
