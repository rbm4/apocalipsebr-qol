--[[
    Auto All - Dismantle Electronics (Build 42 / SP + MP)
    ------------------------------------------------------------------
    "Dismantle All" on any electronic item, in your inventory or sitting
    in a container you have open.

    Taking apart electronics is how Electrical is trained, and doing it by
    hand means opening the crafting menu once per digital watch. Sitting
    on a boxful of them, that is a lot of clicking for one skill level.

    B42 does all of this through four vanilla craft recipes, and all four
    are used here exactly as the crafting menu would:

      * DismantleElectronics       - anything tagged digital, camera,
                                     miscelectronic or flashlight, so
                                     watches, alarm clocks, headphones,
                                     earbuds and torches       (2 XP)
      * DismantleElectronicsDevice - radios, every walkie talkie, ham
                                     radios and televisions   (10 XP)
      * DismantleMiscElectronics   - CD players, home alarms, remotes
                                     and speakers              (2 XP)
      * DismantlePowerBar          - power bars                (1 XP)

    Nothing here changes what an item gives back, how long it takes or
    what it is worth in XP. Every craft is the vanilla recipe, queued
    through the vanilla entry point, so the skill is earned at exactly
    the rate the base game charges for it. This only removes the clicking.

    ------------------------------------------------------------------
    Why this runs in two phases

    All four recipes take a screwdriver as "mode:keep" - borrowed, not
    consumed. ISInventoryPaneContextMenu.OnNewCraft ends with

        ISCraftingUI.ReturnItemsToOriginalContainer(playerObj, returnToContainer)

    where returnToContainer is every borrowed input that was not already
    in the player's inventory. Queued once per watch, that means the
    character fetches the screwdriver, takes one apart, walks it back to
    the toolbox, fetches it again - once per watch.

    OnNewCraft decides that when it is called, not when the action runs,
    so queueing a transfer first does not help.

    So the job gathers first and crafts second: phase one queues the
    transfers, phase two waits for that queue to drain and only then
    queues the crafts. By then the screwdriver is in the inventory,
    returnToContainer comes out empty, and it goes back once at the end.

    This mirrors AutoAll_Sterilize, which hit the same problem. If a third
    batch-crafting job ever turns up, the two-phase engine is worth
    extracting into AutoAll_Core rather than copying a third time.
]]

--[[
    2026-08-31, from KhaozNZ - four fixes, merged from the Auto All
    (Fixed) fork, Workshop 3792445930. Thank you.

    All four come from one thing: InventoryItem.isEquipped() answers for
    whoever owns the container, and for an item on a body that is the
    corpse. Auto Rip has handled this since the same report was made
    against it; Auto Dismantle never did.

    1. Dismantle.onCorpse(), and inUse() checks it before isEquipped().
       Corpse-worn electronics were counted as the player's own gear, so a
       pile of bodies came back as "Those are being worn or carried".

    2. Dismantle.collect() keeps corpse items away from recipeFor().
       DismantleElectronics carries IsNotWorn, so the engine answered "no"
       for a corpse-worn watch and recipeFor cached that "no" against the
       item TYPE - taking every other watch of that type in reach, the ones
       in the player's own bag included, out of the sweep with it. Reported
       as "does all the red watches, stops when they turn blue".

    3. A looting phase (queueLooting, the "looting" task phase). IsNotWorn
       means a watch cannot be taken apart where it lies whatever the
       collecting does, so the bodies have to be stripped first. Same
       shape, same numbers and the same two message keys as Auto Rip.

    4. Honest stop messages (STOP_TEXT / stopText / task.failReason). Every
       dead end used to say "No screwdriver within reach", including the
       ones where the player was holding a screwdriver. The menu tooltip
       has told noTool and noCount apart for a while - this is the same
       distinction on the message the job actually stops with.
]]

require "AutoAll/AutoAll_Core"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.dismantleLoaded then return end
AA.dismantleLoaded = true

AA.Dismantle = AA.Dismantle or {}
local Dismantle = AA.Dismantle

-- The vanilla dismantling recipes, best XP first so an item that somehow
-- matches more than one is taken apart the most rewarding way.
local RECIPES = {
    "DismantleElectronicsDevice",
    "DismantleMiscElectronics",
    "DismantleElectronics",
    "DismantlePowerBar",
}

local WANTED = {}
for _, name in ipairs(RECIPES) do WANTED[name] = true end

-- The tags DismantleElectronics accepts, read off ItemTag rather than
-- typed out so a build that renames one breaks loudly here instead of
-- silently matching nothing. From the recipe itself:
--
--     item 1 tags[base:camera;base:digital;base:miscelectronic;base:flashlight]
local TAG_NAMES = { "CAMERA", "DIGITAL", "MISC_ELECTRONIC", "FLASHLIGHT" }

local TAGS = {}
if ItemTag then
    for _, name in ipairs(TAG_NAMES) do
        if ItemTag[name] then table.insert(TAGS, ItemTag[name]) end
    end
end

-- The other three recipes name item types instead of tags, and those types
-- carry no tag in common. Every one of them whose ItemType is base:radio -
-- so every television, radio, walkie talkie, ham radio and the CD player -
-- is covered by the instanceof check below; these four are ItemType
-- base:normal and have to be named.
local EXTRA_TYPES = {
    ["Base.HomeAlarm"] = true,
    ["Base.Remote"]    = true,
    ["Base.Speaker"]   = true,
    ["Base.PowerBar"]  = true,
}

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------

-- Answers from CraftRecipeManager and from getContainers, held for the
-- length of one menu build or one round.
--
-- This is not a micro-optimisation, it is the fix for "the game freezes
-- when I right click electronics" and for the general right click stutter
-- the BETA had and the published build did not.
--
-- getUniqueRecipeItems is enormously expensive. Read off its bytecode, one
-- call does all of this:
--
--     queryRecipes(IN_HAND_CRAFT, ANY_SURFACE_CRAFT)   -- every such recipe
--     new HandcraftLogic(...)
--     findCraftSurface(character, 2)                   -- scans the squares
--     setContainers(...)
--     for each recipe:  isValidRecipeForCharacter
--                       getValidInputScriptForItem
--                       OnTestItem
--                       setRecipeFromContextClick
--                       canPerformCurrentRecipe       -- full ingredient maths
--
-- The "everything within reach" entry added on 2026-08-11 called that once
-- per item in the inventory and in every open container, twice per right
-- click, with no cache and no pre-filter. In a base that is hundreds of
-- full recipe resolutions between the click and the menu appearing. Auto
-- Rip added exactly the same entry at the same time and did not have the
-- problem, because it had had both of these since the day it was written.
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

local function beginCache()
    cache = {}
    cachedContainers = nil
end

local function endCache()
    cache = nil
    cachedContainers = nil
end

--- Cheap pre-filter: could this item plausibly be taken apart?
---
--- Only a shortlist, and only ever used to narrow "everything within
--- reach" before the engine is asked. Right clicking one item still asks
--- the engine about it directly, so a modded gadget handled by a modded
--- recipe keeps its own menu entry whatever this answers.
function Dismantle.isCandidate(item)
    if not item then return false end

    for _, tag in ipairs(TAGS) do
        if item:hasTag(tag) then return true end
    end

    -- Televisions, radios, walkie talkies, ham radios and the CD player are
    -- all ItemType base:radio, which is the Radio class. Matching the class
    -- rather than the sixteen type names in DismantleElectronicsDevice also
    -- takes in whatever a mod adds as a radio.
    if instanceof(item, "Radio") == true then return true end

    return EXTRA_TYPES[item:getFullType()] == true
end

--- True for an item still on a dead body.
---
--- InventoryItem.isEquipped() is not a flag on the item, it is a question
--- asked of whatever owns the container:
---
---     getContainer() == null                    -> false
---     getContainer().getParent() is a character -> character.isEquipped(item)
---     getContainer().getParent() is IsoDeadBody -> deadBody.isEquipped(item)
---
--- so every watch still on a zombie answers true, and inUse() read that as
--- the player's own gear. getContainers() puts every body in the loot
--- window into the sweep, which is why a pile of corpses came back as
--- "Those are being worn or carried".
---
--- Auto Rip has had Rip.onCorpse since the same report was made against
--- it. This is that function, and the two rules that go with it live in
--- Dismantle.collect and in the looting phase below.
function Dismantle.onCorpse(item)
    if not item then return false end
    local container = item:getContainer()
    if not container then return false end

    local ok, parent = pcall(function() return container:getParent() end)
    if not ok or not parent then return false end
    return instanceof(parent, "IsoDeadBody") == true
end

--- The dismantling recipe for this item, if there is one.
---
--- Deliberately asked of the game rather than matched against a list of
--- item types: that way anything a mod adds with the right tags is
--- picked up too, and nothing here has to be kept in step with vanilla.
---
--- Cached by item type while a cache is open. Which recipe applies depends
--- on the item type and on what tools are within reach, and neither of
--- those changes inside one menu build, so one answer per type is enough.
local function recipeFor(player, item, containers)
    local key = cache and item:getFullType()
    if key then
        local hit = cache[key]
        if hit ~= nil then
            if hit == false then return nil end
            return hit[1], hit[2]
        end
    end

    local available = CraftRecipeManager.getUniqueRecipeItems(item, player, containers)
    if not available then
        if key then cache[key] = false end
        return nil
    end

    local found = {}
    for i = 0, available:size() - 1 do
        local recipe = available:get(i)
        local name = recipe:getName()
        for wanted in pairs(WANTED) do
            -- Matched loosely: depending on the build getName() may or may
            -- not carry the module prefix.
            if name == wanted or string.find(name, wanted, 1, true) then
                found[wanted] = recipe
            end
        end
    end

    for _, name in ipairs(RECIPES) do
        if found[name] then
            if key then cache[key] = { found[name], name } end
            return found[name], name
        end
    end

    if key then cache[key] = false end
    return nil
end

Dismantle.recipeFor = recipeFor

--- Builds the same crafting logic the vanilla context menu would.
local function buildLogic(player, item, recipe)
    local logic = HandcraftLogic.new(player, nil, nil)
    logic:setIsoObject(logic:findCraftSurface(player, 2))
    logic:setContainers(containersOf(player))
    logic:setRecipeFromContextClick(recipe, item)
    return logic
end

--- True when the character is actually using this item right now.
---
--- Worth being thorough about. Of the four recipes only
--- DismantleElectronics carries the IsNotWorn flag - the other three,
--- including the one that covers every walkie talkie, will happily take
--- apart the radio on your belt or the watch on your wrist. Taking a
--- boxful of walkie talkies apart should not cost you the one you are
--- carrying.
local function inUse(player, item)
    -- Worn by a corpse is not worn by you. Checked before isEquipped(),
    -- which answers for whoever owns the container rather than for the
    -- player - see Dismantle.onCorpse.
    if Dismantle.onCorpse(item) then return false end

    if item:isEquipped() then return true end
    if player:isEquipped(item) then return true end
    if player:isPrimaryHandItem(item) or player:isSecondaryHandItem(item) then return true end

    -- Clipped to the belt or the hotbar.
    if player:isAttachedItem(item) then return true end

    local worn = player:getWornItems()
    if worn and worn:contains(item) then return true end

    return false
end

Dismantle.inUse = inUse

--- Every item of this type within reach - the ones being carried first,
--- then the ones in open containers, so a full inventory is used up
--- before anything is fetched. The ground counts as a container: the loot
--- window's floor is in the list getContainers() hands back.
---
--- @return table items, number skipped   skipped = worn or held, left alone
function Dismantle.collect(player, fullType)
    local skipped = 0

    -- `fullType == nil` means "everything in reach", the same shape Auto
    -- Rip uses for its own all-in-one entry. Eligibility is still decided
    -- by asking the engine for the item's recipes further down, never by a
    -- hardcoded list, so a modded gadget with the right tags is included
    -- without anything being kept in step here.
    local inventory = player:getInventory()
    local reachable = containersOf(player)

    -- `fullType == nil` means "everything in reach", the same shape Auto
    -- Rip uses for its own all-in-one entry. Eligibility is still decided
    -- by asking the engine which recipes an item has, never by a hardcoded
    -- list, so a modded gadget with the right tags is included without
    -- anything being kept in step here.
    --
    -- The engine is only asked about items that pass isCandidate first.
    -- Without that this predicate ran a full recipe resolution against
    -- every apple, bullet and sock within reach - see the note on the
    -- cache above. The shortlist can only ever cost a modded item its
    -- place in the "everything" sweep; right clicking it still offers its
    -- own entry, which goes to the engine directly.
    local seen = {}
    local matches = function(item)
        -- Judge each item exactly once.
        --
        -- getAllEvalRecurse on the main inventory already walks every worn
        -- bag, and getContainers hands those same bags back as entries of
        -- its own, so the loop below offers their contents a second time.
        -- The only guard was `item:getContainer() ~= inventory`, which is
        -- true for a bag, so anything in one was counted twice - the menu
        -- offered 12 where the job then took 6 apart. The skipped tally
        -- doubled with it, since this predicate is where it is counted.
        if seen[item] then return false end
        seen[item] = true

        if item:isBroken() then return false end

        if fullType then
            if item:getFullType() ~= fullType then return false end
        elseif not Dismantle.isCandidate(item) then
            return false
        end

        -- Still on a body. It has already passed the type test or the
        -- shortlist above, and the engine must NOT be asked about it.
        --
        -- DismantleElectronics carries IsNotWorn and a corpse counts as
        -- wearing what it has on, so the answer would be "no" - and
        -- recipeFor caches by item TYPE, so that "no" is then remembered
        -- for every identical watch in reach, the ones in the player's own
        -- bag included, and takes them out of the sweep too. Reported as
        -- "it does all the red watches and stops when they turn blue":
        -- the inventory is walked first, so a type the player already
        -- carries is cached as workable and survives, and a type that only
        -- exists on the corpses is cached as hopeless and vanishes.
        --
        -- Judged by the shortlist instead and put on the looting list, the
        -- same rule Rip.collect uses.
        if Dismantle.onCorpse(item) then return true end

        if not fullType and not recipeFor(player, item, reachable) then
            return false
        end

        if inUse(player, item) then
            skipped = skipped + 1
            return false
        end

        return true
    end

    local carried, stored = {}, {}

    local mine = inventory:getAllEvalRecurse(matches, ArrayList.new())
    if mine then
        for i = 0, mine:size() - 1 do
            table.insert(carried, mine:get(i))
        end
    end

    local containers = reachable
    for i = 0, containers:size() - 1 do
        local container = containers:get(i)
        if container and container ~= inventory then
            local found = container:getAllEvalRecurse(matches, ArrayList.new())
            if found then
                for j = 0, found:size() - 1 do
                    local item = found:get(j)
                    -- getContainers can hand back the same container twice
                    -- and recursing into bags can reach an item already
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

    -- Split the pile: what can be taken apart where it lies, and what has
    -- to come off a body first.
    local out, toLoot = {}, {}
    for _, item in ipairs(carried) do
        if Dismantle.onCorpse(item) then
            table.insert(toLoot, item)
        else
            table.insert(out, item)
        end
    end

    return out, skipped, toLoot
end

--- How many of them can actually be taken apart right now.
--- @return number doable, number total, number skipped, boolean noTool,
---         boolean noCount, number lootable
function Dismantle.countDoable(player, fullType)
    local items, skipped, toLoot = Dismantle.collect(player, fullType)
    local lootable = #toLoot
    if #items == 0 then return 0, 0, skipped, false, false, lootable end

    local containers = containersOf(player)

    -- Counted per recipe and summed, because "everything in reach" mixes
    -- radios, watches and power bars in one pile. Asking once about
    -- items[1] would report the whole pile as whatever the first item
    -- happened to be.
    --
    -- Grouped by recipe NAME, not by the recipe object, the way Auto Rip
    -- does it. getUniqueRecipeItems hands back entries out of a shared
    -- static list that it clears on every call, so keying a table on one
    -- of those is asking for a group per item - and a group per item is a
    -- HandcraftLogic and a getPossibleCraftCount per item.
    local byName, order = {}, {}
    for _, item in ipairs(items) do
        local recipe, name = recipeFor(player, item, containers)
        if recipe then
            local group = byName[name]
            if not group then
                group = { recipe = recipe, items = {} }
                byName[name] = group
                table.insert(order, group)
            end
            table.insert(group.items, item)
        end
    end

    local doable = 0
    -- Why doable came out zero, for the message and for the log. Reported
    -- by Falcon_BR: "It always say I do not have a screwdriver when I click
    -- auto train electronics, but I have the canivete or the multitool".
    --
    -- Both of those genuinely carry base:screwdriver - checked in
    -- weapon.txt - so the tool was never the problem. The message was: it
    -- was the only thing UI_AA_dismantle_notool could say, and it is shown
    -- for ANY reason the count is zero. getPossibleCraftCount is the
    -- minimum across every input of the recipe, so the zero can just as
    -- easily be the electronics side - a worn watch fails the IsNotWorn
    -- flag, a broken one fails NoBrokenItems.
    local blockedByTool = false
    local blockedByCount = false

    for _, group in ipairs(order) do
        local logic = buildLogic(player, group.items[1], group.recipe)
        if logic:canPerformCurrentRecipe() then
            -- The argument is "recalculate", not a filter: with false the
            -- engine skips the maths and hands back a cached zero.
            local possible = logic:getPossibleCraftCount(true) or 0
            if possible > 0 then
                doable = doable + math.min(possible, #group.items)
            else
                blockedByCount = true
            end
        else
            blockedByTool = true
        end
    end

    return doable, #items, skipped, blockedByTool, blockedByCount, lootable
end

---------------------------------------------------------------------
-- the job
---------------------------------------------------------------------

--- The borrowed inputs a craft would otherwise carry straight back to
--- the container it took them from - here, the screwdriver.
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

    -- Items for later rounds, fetched now. See the note in planRound.
    for _, item in ipairs(task.prefetch or {}) do
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
    local unsettled  = 0
    local pending    = {}

    for _, item in ipairs(task.items) do
        -- Re-checked per item: an item may have been dropped, broken or
        -- used while the queue was running.
        local container = item:getContainer()
        local recipe = container and recipeFor(player, item, containers) or nil

        if recipe then
            ISInventoryPaneContextMenu.OnNewCraft(item, recipe, playerNum, false, nil)
            queued = queued + 1
            table.insert(pending, item)
        elseif not container then
            -- Not gone: in transit.
            --
            -- ISInventoryTransferAction removes the item from the source
            -- before the destination takes it, and on a client the second
            -- half waits on the server. An item caught in that gap has no
            -- container for a moment, and the gathering phase hands over the
            -- instant its queue drains - which is exactly that moment.
            --
            -- This was costing every single job its first round: the log
            -- showed `container=GONE` half a second after start, on the one
            -- item the job had just fetched, every time. Waiting a tick is
            -- free; re-planning from scratch is not, and it burned the
            -- re-plan budget that exists for genuinely stale batches.
            unsettled = unsettled + 1
        else
            -- Which of the two it was. The round diagnostic can already say
            -- the batch was planned and then queued nothing; it cannot say
            -- whether the item went missing or the engine stopped offering
            -- the recipe, and those have completely different causes.
            print("[AutoAll] dismantle cannot craft " .. tostring(item:getFullType())
                    .. ": container=" .. tostring(container and "yes" or "GONE")
                    .. " recipe=" .. tostring(recipe and "yes" or "NONE")
                    .. " inInventory=" .. tostring(container == player:getInventory())
                    .. " containers=" .. tostring(containers and containers:size() or -1))
        end
    end

    task.pendingItems = pending
    return queued, unsettled
end

-- Rounds in a row where nothing was actually consumed before the job is
-- called stuck. From Mickey's maintenance fork (Workshop 3781695662).
local MAX_NO_PROGRESS = 3

-- Rounds in a row that planned a batch and then queued no craft at all.
local MAX_EMPTY_CRAFTS = 3

-- Ticks a batch may wait for a transfer to land before it is treated as a
-- stale plan rather than a slow one.
local MAX_UNSETTLED = 5

-- How many items beyond this round's batch to pull in while we are already
-- waiting on a transfer. Costs nothing extra: they ride the same round trip.
local PREFETCH = 6

--- Did the crafts queued last round actually happen?
---
--- The queue draining is not evidence: ISHandcraftAction:isValid() checks
--- only the craft bench and that a recipe exists, so an action completes
--- whether or not it had anything to work with. Every supported dismantle recipe destroys its selected input,
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
        -- Real work landed, so the stall count starts over. Without this the
        -- counter is cumulative and three recoveries spread across a whole
        -- job end it, even though each one worked and the job kept going.
        task.stalls = 0
        return true
    end

    task.noProgress = task.noProgress + 1
    return task.noProgress < MAX_NO_PROGRESS
end

--- Puts the screwdriver back where it came from, once, after the whole
--- batch instead of after every single item.
local function returnSupplies(task)
    if not AA.opt("dismantleReturnItems") then return end

    local player = task.player
    for _, entry in ipairs(task.borrowedFrom) do
        if entry.item and entry.item:getContainer() == player:getInventory() then
            ISCraftingUI.ReturnItemToOriginalContainer(player, entry.item)
        end
    end
end

--- Everything sitting in the main inventory right now, as a set.
--- Taken the moment before the crafting starts, so whatever is not in it
--- afterwards is something the dismantling produced.
local function snapshot(player)
    local seen = {}
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        seen[items:get(i)] = true
    end
    return seen
end

--- Sends the scrap back to the crate, cupboard or patch of floor the
--- electronics were taken from, so a big batch does not leave the
--- character loaded down with parts.
---
--- Which items are "the scrap" is worked out by comparing the inventory
--- against the snapshot rather than against a list of expected outputs:
--- one of these recipes picks its output through an itemMapper, and a
--- modded recipe could produce anything at all.
local function returnResults(task)
    if not AA.opt("dismantleResultsToSource") then return end

    local dest = task.destination
    local player = task.player
    local inventory = player:getInventory()
    if not dest or dest == inventory then return end

    local items = inventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and not task.before[item] and not inUse(player, item) then
            ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, inventory, dest))
        end
    end
end

-- Safety net on the round loop. Each round does at least one item, so
-- this caps batch size rather than being a limit anyone will meet.
-- A client does one craft per round (see below), so the budget has to
-- cover a whole pile rather than a handful of batches.
local MAX_ROUNDS = 40
local MAX_ROUNDS_CLIENT = 300

local function roundBudget()
    return isClient() and MAX_ROUNDS_CLIENT or MAX_ROUNDS
end

-- Stripping bodies. Bounded twice over: by how many items one trip takes,
-- and by how much the character can still carry. Same shape and the same
-- numbers as Auto Rip.
local LOOT_BATCH      = isClient() and 3 or 12
local MAX_LOOT_ROUNDS = 40

--- Takes electronics off the bodies in reach and into the inventory, so
--- the next round can treat them as an ordinary pile. Returns false when
--- it could not move anything.
---
--- This has to exist rather than just letting the corpse items through:
--- DismantleElectronics carries IsNotWorn, so a watch cannot be taken
--- apart where it lies however the collecting is written.
---
--- The two messages are Auto Rip's own keys, deliberately. They read
--- correctly for electronics ("Taking 3 off the bodies") and every shipped
--- language already has them, so nothing here needs translating.
local function queueLooting(task, toLoot)
    local player = task.player
    local moved  = 0
    -- What this round asked to move, so the next tick can tell a transfer
    -- that happened from one the client threw away. See confirmPendingLoot.
    local asked  = {}

    local ok, room = pcall(function()
        return player:getMaxWeight() - player:getInventoryWeight()
    end)
    if not ok or type(room) ~= "number" then room = 0 end

    for _, item in ipairs(toLoot) do
        local weight = 0
        local gotWeight, value = pcall(function() return item:getWeight() end)
        if gotWeight and type(value) == "number" then weight = value end

        -- At least one always goes, even when the character is already
        -- loaded: it is about to be turned into scrap.
        if moved > 0 and (room - weight) < 0 then break end

        table.insert(asked, { item = item, from = item:getContainer() })
        ISInventoryPaneContextMenu.transferIfNeeded(player, item)
        room  = room - weight
        moved = moved + 1
        if moved >= LOOT_BATCH then break end
    end

    if moved == 0 then return false end

    task.phase       = "looting"
    task.pendingLoot = asked
    task.looted      = task.looted + moved
    AA.reason(task, getText("UI_AA_rip_looting", moved))
    return true
end

--- Works out what can be done right now and queues the fetching for it.
--- Returns false when there is nothing left to do.
---
--- Shared by Dismantle.start and by think(), so follow-up rounds are set
--- up exactly the way the first one is.
---
--- Wrapped rather than cached inline: a round walks the same pile several
--- times over - collect, then the search for a workable recipe, then the
--- filter down to that recipe - and every one of those passes asked the
--- engine again.

-- Loot rounds in a row that moved nothing before the job gives up.
local MAX_LOOT_STALLS = 3

--- Did the last loot round actually take anything off a body?
---
--- The queue draining is not evidence, for the same reason
--- confirmPendingCrafts exists. ISInventoryTransferAction:isValid() ends
--- with, on a client:
---
---     if not self.started and not isItemTransactionConsistent(...) then
---         return false
---     end
---
--- and a false there drops the action without a word, a log line or a
--- failed animation - the trap Auto Cook hit returning ingredients. A loot
--- round that lost every transfer that way looked exactly like a
--- successful one, so the job planned another identical round on top of
--- it, and another, until the round budget ran out and it stopped with a
--- message about the pile rather than about the transfer.
local function confirmPendingLoot(task)
    local pending = task.pendingLoot
    task.pendingLoot = nil
    if not pending or #pending == 0 then return true end

    local arrived = 0
    for _, entry in ipairs(pending) do
        if entry.item:getContainer() ~= entry.from then arrived = arrived + 1 end
    end

    if arrived > 0 then
        task.lootStalls = 0
        return true
    end

    task.lootStalls = (task.lootStalls or 0) + 1
    print("[AutoAll] dismantle: loot round moved none of " .. tostring(#pending)
            .. " (" .. tostring(task.lootStalls) .. "/"
            .. tostring(MAX_LOOT_STALLS) .. ")")
    return task.lootStalls < MAX_LOOT_STALLS
end

-- Why the last round could not be planned.
--
-- All three keys already existed. What did not exist was anything choosing
-- between them at runtime, so every dead end said "No screwdriver within
-- reach" - including the dead ends where the player was holding a
-- screwdriver, which is most of them. countDoable has told noTool and
-- noCount apart in the menu tooltip for a while; this is the same
-- distinction on the message the job stops with.
local STOP_TEXT = {
    nothing = "UI_AA_dismantle_nothing",
    notool  = "UI_AA_dismantle_notool",
    blocked = "UI_AA_dismantle_blocked",
}

local function stopText(task)
    -- One line naming the dead end, because "Nothing here can be taken
    -- apart right now" is the honest message and still not a diagnosis.
    -- Everything the planner decided from, in the order it decided it.
    print("[AutoAll] dismantle stopping: reason=" .. tostring(task.failReason or "unset")
            .. " items=" .. tostring(task.lastItems)
            .. " toLoot=" .. tostring(task.lastToLoot)
            .. " doable=" .. tostring(task.lastDoable)
            .. " possible=" .. tostring(task.lastPossible)
            .. " batch=" .. tostring(task.batchSize)
            .. " queued=" .. tostring(task.queued)
            .. " succeeded=" .. tostring(task.succeeded)
            .. " rounds=" .. tostring(task.rounds)
            .. " loot=" .. tostring(task.lootRounds) .. "/" .. tostring(task.lootStalls or 0)
            .. " emptyCrafts=" .. tostring(task.emptyCrafts or 0))
    return getText(STOP_TEXT[task.failReason] or "UI_AA_dismantle_blocked")
end

local planRound

local function beginRound(task)
    local owned = not cache
    if owned then beginCache() end
    local ok, result = pcall(planRound, task)
    if owned then endCache() end

    if not ok then
        print("[AutoAll] dismantle round error: " .. tostring(result))
        return false
    end
    return result
end

planRound = function(task)
    local player = task.player

    local items, _, toLoot = Dismantle.collect(player, task.fullType)
    task.lastItems, task.lastToLoot = #items, #toLoot
    task.lastDoable, task.lastPossible = nil, nil

    -- Nothing ready to take apart, but there is still a body wearing some.
    -- Strip it and come back: the next round sees ordinary inventory items.
    if #items == 0 then
        if #toLoot > 0 and task.lootRounds < MAX_LOOT_ROUNDS then
            task.lootRounds = task.lootRounds + 1
            if queueLooting(task, toLoot) then return true end
        end
        task.failReason = (#toLoot > 0) and "blocked" or "nothing"
        return false
    end

    local containers = containersOf(player)

    -- Ask about the *first workable* item rather than items[1].
    --
    -- With a single type in the pile they were the same thing. "Everything
    -- in reach" makes the pile heterogeneous - a radio, a watch and a
    -- power bar are three different recipes - and asking once about
    -- items[1] would decide the whole round from whichever item happened
    -- to be first. Auto Rip hit exactly this and groups by recipe; here a
    -- round simply takes the items that share the recipe it settled on,
    -- and the next round picks up the rest.
    local recipe, recipeName, logic, first
    local sawRecipe = false
    for index, item in ipairs(items) do
        local candidate, name = recipeFor(player, item, containers)
        if candidate then
            sawRecipe = true
            local built = buildLogic(player, item, candidate)
            if built:canPerformCurrentRecipe() then
                recipe, recipeName, logic, first = candidate, name, built, index
                break
            end
        end
    end
    if not recipe then
        -- Something had a recipe but the logic would not run it: that is
        -- the tool. Nothing had a recipe at all: that is the pile.
        task.failReason = sawRecipe and "notool" or "blocked"
        return false
    end

    -- Only the items this round's recipe actually covers. Compared by name
    -- rather than by object, for the reason in countDoable.
    local sameRecipe = {}
    for index = first, #items do
        local _, name = recipeFor(player, items[index], containers)
        if name == recipeName then
            table.insert(sameRecipe, items[index])
        end
    end
    items = sameRecipe

    local possible = logic:getPossibleCraftCount(true) or 0
    local doable = math.min(possible, #items)
    task.lastPossible = possible


    -- On a client the batch is only as big as the last round earned, and
    -- it starts at one. See AA.batchSize in the core for the whole reason
    -- - short version, ISHandcraftAction:isValid() never checks that the
    -- inputs still exist. Single player is not capped at all: there the
    -- inventory is consistent the moment an action ends.
    -- Not named `batch`: that name is the item list further down.
    local clientCap = AA.batchSize(task)
    if clientCap then doable = math.min(doable, clientCap) end

    local cap = AA.opt("dismantleMax") or 0
    if cap > 0 then
        -- The cap is for the whole job, not for each round.
        doable = math.min(doable, math.max(0, cap - task.queued))
    end

    task.lastDoable = doable

    if doable <= 0 then
        task.failReason = "blocked"
        return false
    end

    task.failReason = nil

    local batch = {}
    for i = 1, doable do
        batch[i] = items[i]
    end

    -- Fetch ahead of the batch.
    --
    -- On a client the CRAFT batch starts at one and has to: ISHandcraftAction
    -- does not check its inputs still exist, so queueing several crafts against
    -- a stale view is output without input. Transfers have no such problem,
    -- each is validated on its own, so there is no reason to pay a server round
    -- trip per item merely because only one is crafted per round.
    --
    -- That round trip is what "it takes the first one, stalls at 100% for a
    -- while, then gets re-stuck" actually is. The log shows it plainly:
    --
    --     waiting on 'ISInventoryTransferAction' for 2s, phase=gathering
    --     (bar full, action not finishing)
    --
    -- The transfer's bar fills and then waits two or three seconds for the
    -- server to confirm the move, once per item. Pulling the next few in during
    -- the same gathering phase means later rounds find them already carried and
    -- skip the wait entirely.
    --
    -- Bounded by carry weight, because the whole point is not to trade a stall
    -- for an overloaded character.
    local prefetch = {}
    local gotRoom, room = pcall(function()
        return player:getMaxWeight() - player:getInventoryWeight()
    end)
    if not gotRoom or type(room) ~= "number" then room = 0 end

    for index = doable + 1, math.min(#items, doable + PREFETCH) do
        local ahead = items[index]
        if ahead:getContainer() ~= player:getInventory() then
            local weight = 0
            local gotWeight, value = pcall(function() return ahead:getWeight() end)
            if gotWeight and type(value) == "number" then weight = value end
            if (room - weight) < 0 then break end
            room = room - weight
            table.insert(prefetch, ahead)
        end
    end
    task.prefetch = prefetch

    local supplies = borrowedSupplies(player, logic)

    -- Remember where each borrowed item came from before it is moved.
    -- Later rounds usually add nothing: the screwdriver is already here.
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
        if not task.before then task.before = snapshot(player) end
        local queued = queueCrafting(task)
        task.queued = task.queued + queued
        if queued == 0 then
            task.failReason = "blocked"
        else
            task.emptyCrafts = 0
        end
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

    -- The bodies have been emptied into the inventory. Plan an ordinary
    -- round on top of it; planRound sets the phase itself.
    if task.phase == "looting" then
        if not confirmPendingLoot(task) then
            task.failReason = "blocked"
            AA.stop(player, stopText(task), true)
            return
        end

        if task.rounds < roundBudget() then
            task.rounds = task.rounds + 1
            if beginRound(task) then return end
        end

        task.phase = "returning"
        returnSupplies(task)
        returnResults(task)
        return
    end

    if task.phase == "gathering" then
        task.phase = "crafting"
        AA.reason(task, getText("UI_AA_dismantle_working"))
        -- Snapshot only on the first round: everything fetched during
        -- gathering is already in the inventory, so it will not be
        -- mistaken for scrap later. Later rounds must keep the original
        -- snapshot, or the scrap made so far would look like it was
        -- always there and would never be sent home.
        if not task.before then task.before = snapshot(player) end
        local queued, unsettled = queueCrafting(task)
        task.queued = task.queued + queued

        -- Nothing queued, but only because a transfer had not landed yet.
        -- Come back next tick with the same batch instead of spending a
        -- re-plan on it. Bounded, so an item that really has gone still
        -- falls through to the re-plan below.
        if queued == 0 and unsettled > 0
                and (task.unsettled or 0) < MAX_UNSETTLED then
            task.unsettled = (task.unsettled or 0) + 1
            task.phase = "gathering"
            return
        end
        task.unsettled = 0

        if queued == 0 then
            -- The plan was made before the fetching ran, and fetching moves
            -- the character. Walking to a shelf changes which containers the
            -- loot window holds, and containersOf reads that window - so a
            -- recipe that resolved while standing in front of the shelf can
            -- stop resolving once the character has stepped away from it.
            -- On a client a transfer can also be discarded in silence.
            --
            -- Either way the batch is stale, not impossible. Re-plan against
            -- the world as it is now instead of declaring the whole pile
            -- untouchable, which is the "the items were on shelves and it
            -- just would not dismantle" report. Bounded, so a pile that
            -- genuinely cannot be worked still ends rather than spinning.
            task.emptyCrafts = (task.emptyCrafts or 0) + 1
            if task.emptyCrafts < MAX_EMPTY_CRAFTS and task.rounds < roundBudget() then
                print("[AutoAll] dismantle re-planning after an empty craft round ("
                        .. tostring(task.emptyCrafts) .. "/"
                        .. tostring(MAX_EMPTY_CRAFTS) .. ")")
                task.rounds = task.rounds + 1
                if beginRound(task) then return end
            end

            task.failReason = task.failReason or "blocked"
            AA.stop(player, stopText(task), true)
        else
            task.emptyCrafts = 0
        end
        return
    end

    if task.phase == "crafting" then
        -- Ask the game again before finishing. getPossibleCraftCount is
        -- the minimum across every input of the recipe, and these recipes
        -- have a kept screwdriver alongside the electronics, so the first
        -- answer can be far smaller than the pile actually allows. Auto
        -- Sterilize was reported doing two at a time for this reason.
        if task.rounds < roundBudget() then
            task.rounds = task.rounds + 1
            if beginRound(task) then return end
        end

        task.phase = "returning"
        returnSupplies(task)
        returnResults(task)
        return
    end

    AA.stop(player, getText("UI_AA_dismantle_done", task.succeeded), false)
end

function Dismantle.start(player, fullType, label, destination)
    if not player then return end

    beginCache()
    local ok, items, skipped, toLoot = pcall(Dismantle.collect, player, fullType)
    endCache()
    if not ok then
        print("[AutoAll] dismantle start error: " .. tostring(items))
        return
    end
    toLoot = toLoot or {}

    if #items == 0 and #toLoot == 0 then
        local why = (skipped or 0) > 0 and "UI_AA_dismantle_inuse" or "UI_AA_dismantle_nothing"
        HaloTextHelper.addBadText(player, getText(why))
        return
    end

    local task = {
        kind         = "dismantle",
        player       = player,
        fullType     = fullType,
        items        = {},
        supplies     = {},
        borrowedFrom = {},
        borrowedSeen = {},
        -- Where the scrap goes at the end. Falls back to the container the
        -- first of the batch came from when the option was used on
        -- something already in the inventory.
        destination  = destination or (items[1] and items[1]:getContainer()),
        before       = nil,
        queued       = 0,
        succeeded    = 0,
        pendingItems = {},
        noProgress   = 0,
        rounds       = 0,
        looted       = 0,
        lootRounds   = 0,
        lootStalls   = 0,
        pendingLoot  = nil,
        emptyCrafts  = 0,
        unsettled    = 0,
        prefetch     = {},
        failReason   = nil,
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
        startText    = getText("UI_AA_dismantle_started", #items + #toLoot, label),
    }

    AA.startTask(task)

    if not beginRound(task) then
        AA.stop(player, stopText(task), true)
    end
end

Dismantle.onStart = function(player, fullType, label, destination)
    Dismantle.start(player, fullType, label, destination)
end

Dismantle.onStop = function(player)
    AA.stop(player, getText("UI_AA_stopped"), false)
end

---------------------------------------------------------------------
-- context menu
---------------------------------------------------------------------

local function buildDismantleMenu(player, context, item)
    -- Only offer this on something the game will actually take apart. An
    -- item still on a body is asked about by the shortlist rather than by
    -- recipe, and is deliberately kept away from recipeFor - see
    -- Dismantle.collect for why that answer would poison every other item
    -- of the same type.
    if Dismantle.onCorpse(item) then
        if not Dismantle.isCandidate(item) then return end
    elseif not recipeFor(player, item, containersOf(player)) then
        return
    end

    local fullType = item:getFullType()
    local label = item:getDisplayName()
    local doable, total, skipped, noTool, noCount, lootable =
            Dismantle.countDoable(player, fullType)
    -- Belt and braces: a missing third return value used to reach the
    -- comparisons below as nil and throw on right click.
    skipped  = skipped or 0
    lootable = lootable or 0

    -- Nothing but the one on your wrist. Say so rather than showing
    -- nothing, otherwise it reads as the option being broken.
    if total == 0 and lootable == 0 then
        if skipped == 0 then return end
        local none = AA.addOption(context, getText("UI_AA_dismantle_option", label))
        none.notAvailable = true
        local noneTip = ISInventoryPaneContextMenu.addToolTip()
        noneTip.description = getText("UI_AA_dismantle_inuse")
        none.toolTip = noneTip
        return
    end

    -- Right clicking one inside a crate, a cupboard or on the floor sends
    -- the scrap back there. Used on something already carried, the scrap
    -- stays in the inventory.
    -- A corpse is never a destination, however the option is set: pushing
    -- fresh scrap into the body the watch came off is not "back where it
    -- came from", it is losing it.
    local clicked = item:getContainer()
    local destination = nil
    if clicked and clicked ~= player:getInventory() and not Dismantle.onCorpse(item) then
        destination = clicked
    end

    local option = AA.addOption(context, getText("UI_AA_dismantle_option", label),
                                player, Dismantle.onStart, fullType, label, destination)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()

    if total == 0 and lootable > 0 then
        -- Everything in reach is still on a body. The job can do this: it
        -- strips them first. Greying it out here is what made a pile of
        -- corpses look untouchable.
        tooltip.description = getText("UI_AA_rip_from_body", lootable)
    elseif doable == 0 then
        -- Greyed out with the reason rather than hidden - and with the
        -- RIGHT reason. "You need a screwdriver" used to be shown whatever
        -- made the count zero, which is how a player holding a multitool
        -- was told they had no screwdriver. See countDoable.
        option.notAvailable = true
        if noTool then
            tooltip.description = getText("UI_AA_dismantle_notool")
        elseif noCount then
            tooltip.description = getText("UI_AA_dismantle_blocked")
        else
            tooltip.description = getText("UI_AA_dismantle_notool")
        end
        print("[AutoAll] dismantle greyed out: type=" .. tostring(fullType)
                .. " candidates=" .. tostring(total)
                .. " cannotPerform=" .. tostring(noTool == true)
                .. " craftCountZero=" .. tostring(noCount == true))
    else
        tooltip.description = getText("UI_AA_dismantle_option_tt", doable, total)
        if lootable > 0 then
            tooltip.description = tooltip.description .. " <LINE> <RGB:0.7,0.85,1> "
                .. getText("UI_AA_rip_from_body", lootable)
        end
    end

    if skipped > 0 and not option.notAvailable then
        tooltip.description = tooltip.description .. " <LINE> <RGB:0.7,0.85,1> "
            .. getText("UI_AA_dismantle_keeping", skipped)
    end

    option.toolTip = tooltip

    -- And a second entry for everything in reach, not just this type.
    --
    -- Same destination rule as above: used on something sitting in a crate
    -- or on the floor, the scrap goes back there. The pile is
    -- heterogeneous, so collect() and the round planner ask the engine per
    -- item rather than deciding the whole batch from the first one.
    local allDoable, allTotal, allSkipped, allNoTool, allNoCount, allLootable =
            Dismantle.countDoable(player, nil)
    allSkipped  = allSkipped or 0
    allLootable = allLootable or 0

    if (allTotal + allLootable) > (total + lootable) then
        local everything = AA.addOption(context, getText("UI_AA_dismantle_option_all"),
                player, Dismantle.onStart, nil,
                getText("UI_AA_dismantle_label_all"), destination)
        local allTip = ISInventoryPaneContextMenu.addToolTip()

        if allTotal == 0 and allLootable > 0 then
            allTip.description = getText("UI_AA_rip_from_body", allLootable)
        elseif allDoable == 0 then
            everything.notAvailable = true
            allTip.description = allNoTool and getText("UI_AA_dismantle_notool")
                    or getText("UI_AA_dismantle_blocked")
        else
            allTip.description = getText("UI_AA_dismantle_option_tt", allDoable, allTotal)
            if allLootable > 0 then
                allTip.description = allTip.description .. " <LINE> <RGB:0.7,0.85,1> "
                    .. getText("UI_AA_rip_from_body", allLootable)
            end
        end

        if allSkipped > 0 and not everything.notAvailable then
            allTip.description = allTip.description .. " <LINE> <RGB:0.7,0.85,1> "
                .. getText("UI_AA_dismantle_keeping", allSkipped)
        end
        everything.toolTip = allTip
    end
end

local function addDismantleMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local actual = ISInventoryPane.getActualItems(items)
    local item = actual and actual[1]
    if not item or item:isBroken() then return end

    if AA.isRunning(player, "dismantle") then
        AA.addOption(context, getText("UI_AA_dismantle_stop"), player, Dismantle.onStop)
        return
    end

    -- One cache for the whole menu build. Both entries below walk the same
    -- pile - once for this item's type, once for everything within reach -
    -- and without this the click visibly froze the game in front of a
    -- looted electronics store. See the note at the top of the file.
    beginCache()
    local ok, err = pcall(buildDismantleMenu, player, context, item)
    endCache()

    if not ok then print("[AutoAll] dismantle menu error: " .. tostring(err)) end
end

AA.registerMenu("dismantle", Events.OnFillInventoryObjectContextMenu, addDismantleMenu)
