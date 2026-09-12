--[[
    Auto All - Open cans and jars (Build 42 / SP + MP)
    ------------------------------------------------------------------
    "Open Every Can and Jar", on any sealed tin or preserved jar - in
    your inventory or sitting in a container you have open.

    > *Dodo31320:* "Option to open canned / jarred food for cooking
    > recipes?"

    Opening one tin is two clicks. Opening the twenty a cooked meal is
    made of, one at a time, before Auto Cook can even see them, is the
    exact busywork this mod exists to remove.

    ------------------------------------------------------------------
    What counts as openable

    Eight vanilla recipes, all `category = Cooking`:

      OpenCannedFood / ...WithKnifeOrSharpStoneFlake  the labelled tins
      OpenCannedFood2                                 corned beef, sardines
      OpenJarOfFood                                   everything preserved
      OpenUnlabeledCan / OpenDentedUnlabeledCan       the mystery tins
      OpenWaterRationCan                              plus knife variants

    Read from `recipes_cannedFood.txt` and `recipes_jarring.txt`. Three
    facts about them are worth writing down, because two of them are not
    what an earlier note in this file's history assumed:

    * `OpenCannedFood`, `OpenCannedFood2` and `OpenJarOfFood` have real
      `outputs` blocks driven by an `itemMapper`, so what comes out is
      decided by the script and can be planned for. Only the mystery,
      dented and water-ration recipes have empty outputs and settle it
      in Java (`RecipeCodeOnCreate.openMysteryCan`).

    * `OnCreate = RecipeCodeOnCreate.openAndEat` does NOT eat the food.
      Its first instruction is `getEatPercentage() <= 0 -> return`, and
      a plain craft carries no eat percentage; that branch only fires
      for vanilla's own "Open and Eat" entry. The tin is opened and left
      alone, which is what a cook wants.

    * Wine and beer bottles also carry an `OpeningRecipe`
      (`OpenBottleOfWine`, `OpenBottleOfBeer`). They are deliberately
      NOT in the list below - "open every can" should not go through
      the drinks cabinet.

    ------------------------------------------------------------------
    Why this runs in two phases

    The same reason Auto Sterilize and Auto Dismantle do, and the note
    at the top of AutoAll_Sterilize.lua is the long version:
    ISInventoryPaneContextMenu.OnNewCraft ends by carrying every
    borrowed input back to the container it came from, decided at queue
    time. Called once per tin with the can opener in a kitchen drawer,
    the character walks to the drawer and back once per tin.

    So the job gathers first and crafts second: phase one queues the
    transfers, phase two waits for the queue to drain and only then
    queues the crafts, by which point `returnToContainer` is empty.

    > This is the third module with that engine in it, and the note in
    > AutoAll.md says a third copy should be an extraction into
    > AutoAll_Core instead. It is not one here, deliberately: the other
    > two are running on live servers and were each fixed the hard way,
    > and rewriting them in the same round that adds a new module would
    > put three things at risk to tidy one. The extraction is still the
    > right next step - this file is written to be one of its callers.
]]

require "AutoAll/AutoAll_Core"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.openLoaded then return end
AA.openLoaded = true

AA.Open = AA.Open or {}
local Open = AA.Open

-- Every vanilla recipe that turns a sealed food container into an open
-- one. Matched by name, so a modded tin that reuses a vanilla recipe is
-- picked up for free and nothing here has to track vanilla's item list.
local RECIPES = {
    "OpenCannedFood",
    "OpenCannedFood2",
    "OpenCannedFoodWithKnifeOrSharpStoneFlake",
    "OpenJarOfFood",
    "OpenUnlabeledCan",
    "OpenUnlabeledCanWithKnifeOrSharpStoneFlake",
    "OpenDentedUnlabeledCan",
    "OpenDentedUnlabeledCanWithKnifeOrSharpStoneFlake",
    "OpenWaterRationCan",
    "OpenWaterRationCanWithKnifeOrSharpStoneFlake",
}

local WANTED = {}
for _, name in ipairs(RECIPES) do WANTED[name] = true end

-- The tins whose script carries no OpeningRecipe line. Everything else
-- either names its recipe (the sixteen labelled tins, corned beef and
-- sardines) or carries base:preservedfood (every jar).
local EXTRA_TYPES = {
    ["Base.MysteryCan"]      = true,
    ["Base.DentedCan"]       = true,
    ["Base.WaterRationCan"]  = true,
}

local PRESERVED = ItemTag and ItemTag.PRESERVED_FOOD or nil

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------

-- Answers from CraftRecipeManager and from getContainers, held for the
-- length of one menu build or one round. Straight from Auto Dismantle,
-- and for the same reason: getUniqueRecipeItems resolves every in-hand
-- and any-surface recipe against the item, and calling it once per thing
-- in a stocked base is what froze the game on right click.
local cache = nil
local cachedContainers = nil

local function containersOf(player)
    if cache then
        if not cachedContainers then
            cachedContainers = ISInventoryPaneContextMenu.getContainers(player) or ArrayList.new()
        end
        return cachedContainers
    end
    return ISInventoryPaneContextMenu.getContainers(player) or ArrayList.new()
end

-- Counted rather than a plain flag: the menu handler opens a cache and
-- then calls countDoable twice, and countDoable has to work on its own
-- as well. Without the depth the first inner endCache would throw away
-- the outer cache and the second entry would pay full price again.
local cacheDepth = 0

local function beginCache()
    cacheDepth = cacheDepth + 1
    if cacheDepth == 1 then
        cache = {}
        cachedContainers = nil
    end
end

local function endCache()
    cacheDepth = cacheDepth - 1
    if cacheDepth <= 0 then
        cacheDepth = 0
        cache = nil
        cachedContainers = nil
    end
end

--- Runs fn inside a cache and closes the cache whatever happens.
---
--- Every caller used to do begin/work/end by hand, and an error in the
--- middle - a menu handler is already inside a pcall, so it would not
--- even be noticed - left the depth above zero and the stale cache in
--- place for the rest of the session. Wrong recipes, permanently.
local function withCache(fn, a, b)
    beginCache()
    local ok, first, second = pcall(fn, a, b)
    endCache()
    if not ok then
        print("[AutoAll] open: " .. tostring(first))
        return nil
    end
    return first, second
end

--- Cheap pre-filter: could this item plausibly be a sealed tin or jar?
---
--- Three script-level facts, none of which cost anything to read:
--- the item names its own opening recipe, or it carries the
--- base:preservedfood tag, or it is one of the three unlabelled tins
--- that do neither.
---
--- Only ever used to narrow "everything within reach" before the
--- crafting engine is asked. The engine still has the final say.
function Open.isCandidate(item)
    if not item then return false end

    local ok, named = pcall(function() return item:getOpeningRecipe() end)
    if ok and type(named) == "string" and WANTED[named] then return true end

    if PRESERVED then
        local okTag, tagged = pcall(function() return item:hasTag(PRESERVED) end)
        if okTag and tagged == true then return true end
    end

    return EXTRA_TYPES[item:getFullType()] == true
end

--- The opening recipe for this item, if the game will give us one.
---
--- Asked of the game rather than matched against a type list, exactly
--- as Auto Dismantle does, so the answer accounts for whether a can
--- opener or a sharp knife is actually within reach.
---
--- Cached by item type while a cache is open: which recipe applies
--- depends on the type and on the tools in reach, and neither changes
--- inside one menu build.
local function recipeFor(player, item, containers)
    local key = cache and item:getFullType()
    if key then
        local hit = cache[key]
        if hit ~= nil then
            if hit == false then return nil end
            return hit
        end
    end

    local available = CraftRecipeManager.getUniqueRecipeItems(item, player, containers)
    if not available then
        if key then cache[key] = false end
        return nil
    end

    for i = 0, available:size() - 1 do
        local recipe = available:get(i)
        local name = recipe:getName()
        -- Matched loosely: depending on the build getName() may or may
        -- not carry the module prefix.
        for _, wanted in ipairs(RECIPES) do
            if name == wanted or string.find(name, wanted, 1, true) then
                if key then cache[key] = recipe end
                return recipe
            end
        end
    end

    if key then cache[key] = false end
    return nil
end

--- Builds the same crafting logic the vanilla context menu would.
local function buildLogic(player, item, recipe)
    local logic = HandcraftLogic.new(player, nil, nil)
    logic:setIsoObject(logic:findCraftSurface(player, 2))
    logic:setContainers(containersOf(player))
    logic:setRecipeFromContextClick(recipe, item)
    return logic
end

--- Every sealed tin and jar within reach - the ones being carried
--- first, so a full inventory is used up before anything is fetched.
---
--- `fullType` narrows it to one kind, the way "Open All Beans" does.
--- nil means everything.
function Open.collect(player, fullType)
    local matches = function(item)
        if fullType and item:getFullType() ~= fullType then return false end
        return Open.isCandidate(item)
    end

    local carried, stored = {}, {}
    local inventory = player:getInventory()

    local mine = inventory:getAllEvalRecurse(matches, ArrayList.new())
    if mine then
        for i = 0, mine:size() - 1 do
            table.insert(carried, mine:get(i))
        end
    end

    local containers = containersOf(player)
    for i = 0, containers:size() - 1 do
        local container = containers:get(i)
        if container and container ~= inventory then
            local found = container:getAllEvalRecurse(matches, ArrayList.new())
            if found then
                for j = 0, found:size() - 1 do
                    local item = found:get(j)
                    -- getContainers can hand back the same container
                    -- twice, and recursing into bags can reach an item
                    -- already counted.
                    if item:getContainer() ~= inventory then
                        table.insert(stored, item)
                    end
                end
            end
        end
    end

    for _, item in ipairs(stored) do
        table.insert(carried, item)
    end
    return carried
end

--- How many of them can actually be opened right now, and how many
--- there are. Runs inside a cache: this is the count the menu shows.
--- @return number doable, number total
local function countDoableNow(player, fullType)
    local items = Open.collect(player, fullType)
    if #items == 0 then return 0, 0 end

    local containers = containersOf(player)
    local doable = 0
    for _, item in ipairs(items) do
        if recipeFor(player, item, containers) then doable = doable + 1 end
    end
    return doable, #items
end

function Open.countDoable(player, fullType)
    local doable, total = withCache(countDoableNow, player, fullType)
    return doable or 0, total or 0
end

---------------------------------------------------------------------
-- the job
---------------------------------------------------------------------

--- The borrowed inputs a craft would carry straight back - the can
--- opener, the knife.
local function borrowedSupplies(player, logic)
    local out = {}
    local data = logic:getRecipeData()
    if not data then return out end

    local putBack = data:getAllPutBackInputItems()
    if not putBack then return out end

    local inventory = player:getInventory()
    for i = 0, putBack:size() - 1 do
        local item = putBack:get(i)
        if item and item:getContainer() ~= inventory then
            table.insert(out, item)
        end
    end
    return out
end

--- Phase one: bring the tool and the tins into the inventory.
local function queueGathering(task)
    local player = task.player
    local moved = 0

    for _, item in ipairs(task.supplies) do
        ISInventoryPaneContextMenu.transferIfNeeded(player, item)
        moved = moved + 1
    end

    for _, item in ipairs(task.items) do
        if item:getContainer() ~= player:getInventory() then
            ISInventoryPaneContextMenu.transferIfNeeded(player, item)
            moved = moved + 1
        end
    end

    return moved
end

--- A snapshot of the main inventory, used to work out what the crafts
--- actually produced. Same approach as Auto Dismantle: the outputs of
--- three of these recipes come from an itemMapper and two more are
--- decided in Java, so an expected-type list would be wrong.
local function snapshotInventory(player)
    local seen = {}
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        seen[items:get(i)] = true
    end
    return seen
end

--- Phase two: with everything in hand, queue the crafts back to back.
local function queueCrafting(task)
    local player     = task.player
    local playerNum  = player:getPlayerNum()
    local containers = containersOf(player)
    local queued     = 0
    local pending    = {}

    task.before = snapshotInventory(player)
    task.awaitingResults = true

    for _, item in ipairs(task.items) do
        -- Re-checked per item: an item may have been eaten, dropped or
        -- opened by hand while the transfers ran.
        if item:getContainer() then
            local recipe = recipeFor(player, item, containers)
            if recipe then
                ISInventoryPaneContextMenu.OnNewCraft(item, recipe, playerNum, false, nil)
                queued = queued + 1
                table.insert(pending, item)
            end
        end
    end

    task.pendingItems = pending
    return queued
end

-- Rounds in a row where nothing was consumed before the job is called
-- stuck. Same figure the other two batch jobs use.
local MAX_NO_PROGRESS = 3

--- Did the crafts queued last round actually happen?
---
--- The queue draining is not evidence - ISHandcraftAction:isValid()
--- never checks that the inputs still exist. Every one of these recipes
--- consumes the sealed container, so an input that still has a
--- container was never opened.
local function confirmPendingCrafts(task)
    if #task.pendingItems == 0 then return true end

    local succeeded = 0
    for _, item in ipairs(task.pendingItems) do
        if not item:getContainer() then succeeded = succeeded + 1 end
    end

    AA.batchFeedback(task, #task.pendingItems, succeeded)

    task.pendingItems = {}
    task.succeeded = task.succeeded + succeeded

    if succeeded > 0 then
        task.noProgress = 0
        return true
    end

    task.noProgress = task.noProgress + 1
    return task.noProgress < MAX_NO_PROGRESS
end

--- Puts the can opener back where it came from, once, at the end.
local function returnSupplies(task)
    if not AA.opt("openReturnItems") then return end

    local player = task.player
    for _, entry in ipairs(task.borrowedFrom) do
        if entry.item and entry.item:getContainer() == player:getInventory() then
            ISCraftingUI.ReturnItemToOriginalContainer(player, entry.item)
        end
    end
end

--- Notes what the last round of crafts actually produced.
---
--- Run once per round and accumulated, because task.before is replaced
--- every time crafts are queued: diffing only at the end would see just
--- the final round and leave every earlier tin in the character's bag.
local function collectResults(task)
    if not task.awaitingResults then return end
    task.awaitingResults = false

    local after = snapshotInventory(task.player)
    for item in pairs(after) do
        if not task.before[item] then task.results[item] = true end
    end
    task.before = {}
end

--- Sends the opened food back to the container the sealed one came
--- from, so emptying a fridge of tins does not end with the character
--- carrying every one of them.
local function returnResults(task)
    if not AA.opt("openResultsToSource") then return end

    local player      = task.player
    local destination = task.destination
    local inventory   = player:getInventory()
    if not destination or destination == inventory then return end

    for item in pairs(task.results) do
        -- Still there, and still ours to move: the character may have
        -- eaten one while the job ran.
        if item:getContainer() == inventory then
            ISTimedActionQueue.add(
                ISInventoryTransferAction:new(player, item, inventory, destination))
        end
    end
end

-- Safety net on the round loop. Each round does at least one tin.
local MAX_ROUNDS = 40
local MAX_ROUNDS_CLIENT = 300

local function roundBudget()
    return isClient() and MAX_ROUNDS_CLIENT or MAX_ROUNDS
end

--- Works out what can be opened right now and queues the fetching for
--- it. Returns false when there is nothing left to do.
local function planRound(task)
    local player = task.player

    local items = Open.collect(player, task.fullType)
    if #items == 0 then return false end

    local containers = containersOf(player)

    -- Only the ones the game will actually give a recipe for, and the
    -- logic is built from the first of those rather than from the first
    -- item found - a jar and a tin do not share a recipe.
    local openable, first, recipe = {}, nil, nil
    for _, item in ipairs(items) do
        local r = recipeFor(player, item, containers)
        if r then
            if not first then first, recipe = item, r end
            table.insert(openable, item)
        end
    end
    if not first then return false end

    local logic = buildLogic(player, first, recipe)
    if not logic:canPerformCurrentRecipe() then return false end

    local doable = #openable

    local configMax = AA.opt("openMax") or 0
    if configMax > 0 then doable = math.min(doable, configMax - task.succeeded) end

    -- On a client the batch is only as big as the last round earned.
    -- See AA.batchSize in the core.
    local clientCap = AA.batchSize(task)
    if clientCap then doable = math.min(doable, clientCap) end
    if doable <= 0 then return false end

    local batch = {}
    for i = 1, doable do
        batch[i] = openable[i]
    end

    local supplies = borrowedSupplies(player, logic)
    for _, item in ipairs(supplies) do
        if not task.borrowedSeen[item] then
            task.borrowedSeen[item] = true
            task.borrowedFrom[#task.borrowedFrom + 1] =
                { item = item, container = item:getContainer() }
        end
    end

    task.items    = batch
    task.supplies = supplies
    task.phase    = "gathering"

    if queueGathering(task) == 0 then
        task.phase = "crafting"
        local queued = queueCrafting(task)
        task.queued = task.queued + queued
        return queued > 0
    end

    return true
end

--- One round, inside a cache. Every recipe lookup a round makes asks
--- the same question of the same item types, so one cache per round is
--- the difference between a lookup per tin and a lookup per type.
local function beginRound(task)
    return withCache(planRound, task) == true
end

local function think(task)
    local player = task.player

    if AA.isQueueBusy(player) then return end

    collectResults(task)

    if not confirmPendingCrafts(task) then
        AA.stop(player, getText("UI_AA_stop_error"), true)
        return
    end

    if task.phase == "gathering" then
        task.phase = "crafting"
        AA.reason(task, getText("UI_AA_open_working"))
        local queued = withCache(queueCrafting, task) or 0
        task.queued = task.queued + queued
        if queued == 0 then
            AA.stop(player, getText("UI_AA_open_notool"), true)
        end
        return
    end

    if task.rounds < roundBudget() then
        task.rounds = task.rounds + 1
        if beginRound(task) then return end
    end

    -- The tool goes home first, then the food, then the job ends. Each
    -- of those is its own pass through think() because AA.stop clears
    -- the action queue: queueing a transfer and stopping in the same
    -- tick wipes the transfer.
    if task.phase ~= "returning" then
        task.phase = "returning"
        returnSupplies(task)
        return
    end

    if task.phase ~= "results" then
        task.phase = "results"
        returnResults(task)
        return
    end

    AA.stop(player, getText("UI_AA_open_done", task.succeeded), false)
end

function Open.start(player, fullType, label, destination)
    if not player then return end

    local items = withCache(Open.collect, player, fullType) or {}

    if #items == 0 then
        HaloTextHelper.addBadText(player, getText("UI_AA_open_nothing"))
        return
    end

    local task = {
        kind         = "open",
        player       = player,
        fullType     = fullType,        -- nil means "everything in reach"
        items        = {},
        supplies     = {},
        borrowedFrom = {},
        borrowedSeen = {},
        -- Where the opened food goes at the end. Falls back to the
        -- container the first of the batch came from when the option
        -- was used on something already carried.
        destination  = destination or items[1]:getContainer(),
        before       = {},
        results      = {},
        queued       = 0,
        succeeded    = 0,
        pendingItems = {},
        noProgress   = 0,
        rounds       = 0,
        -- A single action that never ends freezes the whole job in
        -- silence: think() is gated on the queue draining, so nothing
        -- is ever said and nothing is written to the log.
        stallTimeout = 30000,
        phase        = "gathering",
        think        = think,
        allowMove    = true,
        startText    = getText("UI_AA_open_started", #items, label),
    }

    AA.startTask(task)

    if not beginRound(task) then
        AA.stop(player, getText("UI_AA_open_notool"), true)
    end
end

Open.onStartAll = function(player)
    Open.start(player, nil, getText("UI_AA_open_label_all"))
end

Open.onStartOne = function(player, args)
    Open.start(player, args.fullType, args.label, args.destination)
end

Open.onStop = function(player)
    AA.stop(player, getText("UI_AA_stopped"), false)
end

---------------------------------------------------------------------
-- context menu
---------------------------------------------------------------------

local function addEntry(context, player, label, fullType, callback, args)
    local doable, total = Open.countDoable(player, fullType)
    if total == 0 then return end

    local option = AA.addOption(context, label, player, callback, args)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()

    if doable == 0 then
        -- Greyed with the reason rather than hidden, so it is clear the
        -- option exists and only the can opener is missing.
        option.notAvailable = true
        tooltip.description = getText("UI_AA_open_notool")
    else
        tooltip.description = getText("UI_AA_open_option_tt", doable, total)
    end
    option.toolTip = tooltip
end

local function addOpenMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local actual = ISInventoryPane.getActualItems(items)
    local item = actual and actual[1]
    if not item or not instanceof(item, "InventoryItem") then return end

    -- The whole menu hangs off the clicked item being a sealed
    -- container. Nothing below this line runs on a right click
    -- anywhere else, which is what keeps the cost off every menu.
    if not Open.isCandidate(item) then return end

    if AA.isRunning(player, "open") then
        AA.addOption(context, getText("UI_AA_open_stop"), player, Open.onStop)
        return
    end

    -- One cache around both entries. Each of them counts what is within
    -- reach, and both ask the crafting engine about the same item types.
    withCache(function()
        local fullType = item:getFullType()
        addEntry(context, player,
            getText("UI_AA_open_option", item:getDisplayName()),
            fullType, Open.onStartOne,
            { fullType = fullType, label = item:getDisplayName(), destination = item:getContainer() })

        addEntry(context, player, getText("UI_AA_open_option_all"), nil, Open.onStartAll)
    end)
end

AA.registerMenu("open", Events.OnFillInventoryObjectContextMenu, addOpenMenu)
