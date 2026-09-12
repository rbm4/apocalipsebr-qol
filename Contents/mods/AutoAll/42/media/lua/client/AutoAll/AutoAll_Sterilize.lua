--[[
    Auto All - Sterilize (Build 42 / SP + MP)
    ------------------------------------------------------------------
    "Sterilize All Bandages" and "Sterilize All Rags", on any bandage or
    rag - in your inventory or sitting in a container you have open.

    Doing this by hand means opening the crafting menu once per single
    bandage, which is the definition of busywork when you are sitting on
    a pile of them.

    B42 turned sterilising into two craft recipes, and both are used here
    exactly as the crafting menu would:

      * DisinfectRag     - 0.1 of rubbing alcohol, vodka or whiskey
      * DisinfectBandage - 0.5 of hot water

    Whichever one the character can actually perform right now is the one
    that gets used, alcohol first because it is quicker.

    ------------------------------------------------------------------
    Why this runs in two phases

    ISInventoryPaneContextMenu.OnNewCraft - the vanilla entry point this
    mod queues its crafts through - ends with:

        ISCraftingUI.ReturnItemsToOriginalContainer(playerObj, returnToContainer)

    where returnToContainer is every borrowed input that was not already
    in the player's inventory. Called once per bandage, that means the
    character fetches the alcohol, sterilises one, walks it back to the
    cupboard, fetches it again... once per bandage. Which is exactly what
    it looked like.

    OnNewCraft decides that at the moment it is called, not at the moment
    the action runs, so queueing a transfer first does not help: the item
    is still in the cupboard while the crafts are being queued.

    So the job gathers first and crafts second. Phase one queues the
    transfers - the alcohol, and the bandages that are still in a
    container. Phase two waits for that queue to drain, and only then
    queues the crafts. By then everything is already in the inventory,
    returnToContainer comes out empty, and nothing is carried back and
    forth. Whatever is left over goes back at the end, once.

    How many to fetch is not guessed at either. HandcraftLogic knows -
    getPossibleCraftCount(true) is the same maths the crafting window uses
    to fill in its "max" - so the character takes exactly as many as the
    alcohol and the water on hand can actually cover. Mind the argument:
    it means "recalculate", and passing false returns a cached zero.
]]

require "AutoAll/AutoAll_Core"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.sterilizeLoaded then return end
AA.sterilizeLoaded = true

AA.Sterilize = AA.Sterilize or {}
local Sterilize = AA.Sterilize

-- The vanilla recipes, quickest first.
local RECIPES = { "DisinfectRag", "DisinfectBandage" }

-- What each option covers. Vanilla maps both through the same two
-- recipes, so the split is purely about what the player asked for.
local BANDAGES = { ["Base.Bandage"] = true }
local RAGS     = { ["Base.RippedSheets"] = true }

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------

local function containersOf(player)
    return ISInventoryPaneContextMenu.getContainers(player) or ArrayList.new()
end

--- The recipes this item can currently be sterilised with.
local function recipesFor(player, item, containers)
    local usable = {}
    local available = CraftRecipeManager.getUniqueRecipeItems(item, player, containers)
    if not available then return usable end

    for i = 0, available:size() - 1 do
        local recipe = available:get(i)
        local name = recipe:getName()
        for _, wanted in ipairs(RECIPES) do
            -- Matched loosely: depending on the build getName() may or may
            -- not carry the module prefix.
            if name == wanted or string.find(name, wanted, 1, true) then
                usable[wanted] = recipe
            end
        end
    end
    return usable
end

--- Picks the recipe to use, preferring alcohol over boiling water.
local function pickRecipe(usable)
    for _, name in ipairs(RECIPES) do
        if usable[name] then return usable[name], name end
    end
    return nil
end

--- Builds the same crafting logic the vanilla context menu would, so we
--- can ask it questions before committing to anything.
local function buildLogic(player, item, recipe)
    local logic = HandcraftLogic.new(player, nil, nil)
    logic:setIsoObject(logic:findCraftSurface(player, 2))
    logic:setContainers(containersOf(player))
    logic:setRecipeFromContextClick(recipe, item)
    return logic
end

--- Every bandage (or rag) within reach that still needs sterilising -
--- the ones being carried first, then the ones in open containers, so a
--- full inventory is used up before anything is fetched.
function Sterilize.collect(player, wanted)
    local matches = function(item) return wanted[item:getFullType()] == true end

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
                    -- getContainers can hand back the same container twice
                    -- and recursing into bags can reach an item we already
                    -- counted, so only take what is genuinely elsewhere.
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

--- How many of them the supplies in reach can actually cover.
--- @return number doable, number total
function Sterilize.countDoable(player, wanted)
    local items = Sterilize.collect(player, wanted)
    if #items == 0 then return 0, 0 end

    local containers = containersOf(player)
    local recipe = pickRecipe(recipesFor(player, items[1], containers))
    if not recipe then return 0, #items end

    local logic = buildLogic(player, items[1], recipe)
    if not logic:canPerformCurrentRecipe() then return 0, #items end

    -- The same number the crafting window would show as its maximum. It
    -- already accounts for the alcohol, the water and the rags, so it
    -- only needs capping to what the player actually asked for.
    -- The argument is "recalculate", not a filter. With false the engine
    -- skips the maths entirely and hands back its cached figure, which on
    -- a logic we just built is still zero - so every batch looked
    -- impossible no matter how much alcohol was on hand. The crafting
    -- window can pass false because its logic is long lived and something
    -- else has already refreshed it; a one-shot check has to pass true.
    local possible = logic:getPossibleCraftCount(true) or 0
    if possible < 0 then possible = 0 end

    return math.min(possible, #items), #items
end

---------------------------------------------------------------------
-- the job
---------------------------------------------------------------------

--- The borrowed inputs a craft would otherwise carry straight back to
--- the container it took them from - the alcohol bottle, the water pot.
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

--- Phase one: bring everything the job needs into the inventory.
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

--- Phase two: with everything in hand, queue the crafts back to back.
local function queueCrafting(task)
    local player     = task.player
    local playerNum  = player:getPlayerNum()
    local containers = containersOf(player)
    local queued     = 0
    local pending    = {}

    for _, item in ipairs(task.items) do
        -- Re-checked per item: the supplies are consumed as the queue
        -- runs, and an item may have been dropped or used in the meantime.
        if item:getContainer() then
            local recipe = pickRecipe(recipesFor(player, item, containers))
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

-- Rounds in a row where nothing was actually consumed before the job is
-- called stuck. From Mickey's maintenance fork (Workshop 3781695662).
local MAX_NO_PROGRESS = 3

--- Did the crafts queued last round actually happen?
---
--- The queue draining is not evidence: ISHandcraftAction:isValid() checks
--- only the craft bench and that a recipe exists, so an action completes
--- whether or not it had anything to work with. Both sterilize recipes destroy the plain rag or bandage,
--- so an input that still has a container was never consumed.
---
--- This is what makes the finish message a count of real work rather than
--- a count of actions queued, and it is what stops a job looping over a
--- pile it cannot actually process.
local function confirmPendingCrafts(task)
    if #task.pendingItems == 0 then return true end

    local succeeded = 0
    for _, item in ipairs(task.pendingItems) do
        if not item:getContainer() then succeeded = succeeded + 1 end
    end

    -- The same count decides whether the next batch may be bigger.
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

--- Puts the leftover alcohol or water back where it came from, once,
--- after the whole batch instead of after every single bandage.
local function returnSupplies(task)
    if not AA.opt("sterilReturnItems") then return end

    local player = task.player
    local leftovers = {}
    for _, entry in ipairs(task.borrowedFrom) do
        if entry.item and entry.item:getContainer() == player:getInventory() then
            table.insert(leftovers, entry.item)
        end
    end

    for _, item in ipairs(leftovers) do
        ISCraftingUI.ReturnItemToOriginalContainer(player, item)
    end
end

-- Safety net on the round loop below. Each round does at least one item,
-- so this is a cap on batch size, not a real limit anyone will meet.
-- A client does one craft per round (see below), so the budget has to
-- cover a whole pile rather than a handful of batches.
local MAX_ROUNDS = 40
local MAX_ROUNDS_CLIENT = 300

local function roundBudget()
    return isClient() and MAX_ROUNDS_CLIENT or MAX_ROUNDS
end

--- Works out what can be done right now and queues the fetching for it.
--- Returns false when there is nothing left to do.
---
--- Shared by Sterilize.start and by think(), so the follow-up rounds are
--- prepared exactly the same way the first one is.
local function beginRound(task)
    local player = task.player

    local items = Sterilize.collect(player, task.wanted)
    if #items == 0 then return false end

    local containers = containersOf(player)
    local recipe = pickRecipe(recipesFor(player, items[1], containers))
    if not recipe then return false end

    local logic = buildLogic(player, items[1], recipe)
    if not logic:canPerformCurrentRecipe() then return false end

    -- The argument is "recalculate", not a filter. With false the engine
    -- skips the maths entirely and hands back its cached figure, which on
    -- a logic we just built is still zero.
    local possible = logic:getPossibleCraftCount(true) or 0
    local doable = math.min(possible, #items)

    -- On a client the batch is only as big as the last round earned, and
    -- it starts at one. See AA.batchSize in the core for the whole reason
    -- - short version, ISHandcraftAction:isValid() never checks that the
    -- inputs still exist. Single player is not capped at all: there the
    -- inventory is consistent the moment an action ends.
    local clientCap = AA.batchSize(task)
    if clientCap then doable = math.min(doable, clientCap) end
    if doable <= 0 then return false end

    local batch = {}
    for i = 1, doable do
        batch[i] = items[i]
    end

    local supplies = borrowedSupplies(player, logic)

    -- Remember where each borrowed item came from before it is moved.
    -- Later rounds usually add nothing here, because by then the alcohol
    -- is already in the inventory.
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
        -- Nothing had to be fetched, so there is nothing to wait for.
        task.phase = "crafting"
        local queued = queueCrafting(task)
        task.queued = task.queued + queued
        return queued > 0
    end

    return true
end

local function think(task)
    local player = task.player

    if AA.isQueueBusy(player) then return end

    if not confirmPendingCrafts(task) then
        AA.stop(player, getText("UI_AA_stop_error"), true)
        return
    end

    if task.phase == "gathering" then
        task.phase = "crafting"
        AA.reason(task, getText("UI_AA_steril_working"))
        local queued = queueCrafting(task)
        task.queued = task.queued + queued
        if queued == 0 then
            AA.stop(player, getText("UI_AA_steril_nosupplies"), true)
        end
        return
    end

    -- A round is done. Ask the game again rather than trusting the first
    -- answer: getPossibleCraftCount is the minimum across every input of
    -- the recipe, and for these two recipes that includes a wildcard
    -- "item 1 [*]" slot as well as the rags and the fluid. It can come
    -- back with a small number - two was the report - even when there is
    -- plenty of alcohol and a pile of rags. Whatever the reason for the
    -- cap, doing another round is correct: if the game still says more is
    -- possible, more is possible.
    if task.rounds < roundBudget() then
        task.rounds = task.rounds + 1
        if beginRound(task) then return end
    end

    -- A returning phase, the way Auto Rip and Auto Dismantle already do it.
    --
    -- This used to queue the alcohol's trip home and stop in the same tick.
    -- That was harmless while AA.stop only cleared the queue on request; it
    -- is not harmless now that stopping clears it by default, because the
    -- clear would wipe the return that was queued a line earlier and the
    -- leftovers would stay in the character's bag forever. Queue it, let
    -- the queue drain, then stop.
    if task.phase ~= "returning" then
        task.phase = "returning"
        returnSupplies(task)
        return
    end

    AA.stop(player, getText("UI_AA_steril_done", task.succeeded), false)
end

function Sterilize.start(player, wanted, label)
    if not player then return end

    if #Sterilize.collect(player, wanted) == 0 then
        HaloTextHelper.addBadText(player, getText("UI_AA_steril_nothing"))
        return
    end

    local task = {
        kind         = "sterilize",
        player       = player,
        wanted       = wanted,
        items        = {},
        supplies     = {},
        borrowedFrom = {},
        borrowedSeen = {},
        queued       = 0,
        succeeded    = 0,
        pendingItems = {},
        noProgress   = 0,
        rounds       = 0,
        -- A single action that never ends freezes the whole job in
        -- silence: think() is gated on the queue draining, so nothing
        -- is ever said and nothing is written to the log. Reported by
        -- Talkierplacebo2 on a hosted game - ripping and healing
        -- "gets to 99% done and never continues". AA.queueStalled
        -- clears a head that has not moved in this long, and gives up
        -- with a message after three of them rather than grinding on.
        stallTimeout = 30000,
        phase        = "gathering",
        think        = think,
        allowMove    = true,
        startText    = getText("UI_AA_steril_started", label),
    }

    AA.startTask(task)

    if not beginRound(task) then
        AA.stop(player, getText("UI_AA_steril_nosupplies"), true)
    end
end

Sterilize.onBandages = function(player)
    Sterilize.start(player, BANDAGES, getText("UI_AA_steril_bandages"))
end

Sterilize.onRags = function(player)
    Sterilize.start(player, RAGS, getText("UI_AA_steril_rags"))
end

Sterilize.onStop = function(player)
    AA.stop(player, getText("UI_AA_stopped"), false)
end

---------------------------------------------------------------------
-- context menu
---------------------------------------------------------------------

local function addEntry(context, player, label, wanted, callback)
    local doable, total = Sterilize.countDoable(player, wanted)
    if total == 0 then return end

    local option = AA.addOption(context, label, player, callback)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()

    if doable == 0 then
        -- Greyed out with the reason rather than hidden, so it is clear
        -- the option exists and only the alcohol is missing.
        option.notAvailable = true
        tooltip.description = getText("UI_AA_steril_nosupplies")
    else
        tooltip.description = getText("UI_AA_steril_option_tt", doable, total)
    end
    option.toolTip = tooltip
end

local function addSterilizeMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local actual = ISInventoryPane.getActualItems(items)
    local item = actual and actual[1]
    if not item then return end

    local fullType = item:getFullType()
    if not BANDAGES[fullType] and not RAGS[fullType] then return end

    if AA.isRunning(player, "sterilize") then
        AA.addOption(context, getText("UI_AA_steril_stop"), player, Sterilize.onStop)
        return
    end

    addEntry(context, player, getText("UI_AA_steril_bandages_option"), BANDAGES, Sterilize.onBandages)
    addEntry(context, player, getText("UI_AA_steril_rags_option"), RAGS, Sterilize.onRags)
end

AA.registerMenu("sterilize", Events.OnFillInventoryObjectContextMenu, addSterilizeMenu)
