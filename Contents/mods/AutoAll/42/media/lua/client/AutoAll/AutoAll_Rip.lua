--[[
    Auto All - Rip Clothing (Build 42 / SP + MP)
    ------------------------------------------------------------------
    "Auto Rip" on any clothing or sheet, in your inventory or sitting in
    a container you have open.

    Ripped Sheets are the single most used material in the game - every
    bandage, every patch, every rope starts as one - and making them means
    opening the crafting menu once per t-shirt. A wardrobe full of looted
    clothing is an afternoon of clicking.

    B42 does this through three vanilla craft recipes, all three used here
    exactly as the crafting menu would:

      * RipClothing      - anything tagged RipClothingCotton, by hand,
                           into Ripped Sheets
      * RipDenimClothing - denim and leather, with scissors or a sharp
                           knife, into Denim Strips or Leather Strips
      * RipSheets        - a bed sheet into ten Ripped Sheets

    Nothing here changes what an item gives back or how long it takes.
    Every craft is the vanilla recipe queued through the vanilla entry
    point. This only removes the clicking.

    ------------------------------------------------------------------
    Two things this job has to be careful about

    1. It destroys clothing. Worn, held, belt clipped and favourited items
       are never touched, and the "everything" entry always says in its
       tooltip how many pieces it is about to take.

    2. Unlike dismantling, the pile is not all one item type. A wardrobe
       is jeans, t-shirts and a leather jacket, and those are three
       different recipes with different inputs - one of which borrows
       scissors. So a round groups the pile by recipe and asks the engine
       for each group separately, rather than asking once about the first
       item and assuming the rest match.

    The two phase gather-then-craft shape, and the round loop around it,
    are there for the same reasons they are in AutoAll_Dismantle: see the
    header of that file. Short version - OnNewCraft decides where to
    return borrowed tools when it is called, so the scissors have to be in
    the inventory before the first craft is queued, and
    getPossibleCraftCount is a minimum across every input, so one answer
    is not the whole job.
]]

--[[
    2026-08-31, from KhaozNZ - six fixes, merged from the Auto All (Fixed)
    fork, Workshop 3792445930. Thank you.

    1. Rip.collect judged each item once. getAllEvalRecurse on the main
       inventory already walks every worn bag, and getContainers hands
       those same bags back as entries of their own, so anything in a bag
       was counted twice - the menu offered 12 where the job then ripped 6.

    2. An item with no container is in transit, not gone. On a client the
       second half of a transfer waits on the server, and the gathering
       phase hands over the instant its queue drains, which is exactly that
       gap. The batch now waits a tick instead of spending a re-plan.

    3. confirmPendingLoot. ISInventoryTransferAction:isValid() drops an
       inconsistent transfer on a client with no error and no log line, so
       a loot round that lost every transfer looked exactly like one that
       worked.

    4. task.stalls resets when real work lands. It was cumulative, so three
       recoveries spread across a long job ended it even though each one
       had worked.

    5. Honest stop messages. Every dead end said "No scissors or sharp
       knife within reach", including the ones where the player was holding
       scissors.

    6. Prefetch, and a re-plan after an empty craft round. The batch is
       planned before the fetching runs, and fetching moves the character -
       which changes what the loot window holds and therefore what counts
       as within reach.
]]

require "AutoAll/AutoAll_Core"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.ripLoaded then return end
AA.ripLoaded = true

AA.Rip = AA.Rip or {}
local Rip = AA.Rip

-- Denim first: an item carrying both tags is worth more as strips.
local RECIPES = {
    "RipDenimClothing",
    "RipSheets",
    "RipClothing",
}

local WANTED = {}
for _, name in ipairs(RECIPES) do WANTED[name] = true end

-- The tags the three recipes accept. Read off ItemTag rather than typed
-- out, so a build that renames one breaks loudly here instead of silently
-- matching nothing. The two odd spellings are vanilla's own: ItemTag
-- carries RIP_CLOTHIG_COTTON and RIP_CLOTHING_COTON alongside the correct
-- one, and items in the wild use them.
local TAG_NAMES = {
    "SHEET",
    "RIP_CLOTHING_COTTON",
    "RIP_CLOTHIG_COTTON",
    "RIP_CLOTHING_COTON",
    "RIP_CLOTHING_DENIM",
    "RIP_CLOTHING_LEATHER",
}

local TAGS = {}
if ItemTag then
    for _, name in ipairs(TAG_NAMES) do
        if ItemTag[name] then table.insert(TAGS, ItemTag[name]) end
    end
end

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------

local function containersOf(player)
    return ISInventoryPaneContextMenu.getContainers(player) or ArrayList.new()
end

--- Cheap pre-filter: could this item plausibly be ripped?
---
--- Only a shortlist. Asking CraftRecipeManager about every item in a
--- loaded character's inventory is far too slow to do on right click, so
--- the tags narrow it down first and the engine has the final say.
---
--- Clothing without a known tag still gets through, because a modded
--- garment may well be handled by a modded rip recipe.
function Rip.isCandidate(item)
    if not item then return false end
    if Rip.hasRipTag(item) then return true end
    return instanceof(item, "Clothing") == true
end

--- One of the tags the three rip recipes actually match on.
---
--- Stricter than isCandidate: used for clothing still on a body, where the
--- engine cannot be asked for a recipe (see Rip.onCorpse) and a guess has
--- to be made before anything is carried off the corpse.
function Rip.hasRipTag(item)
    if not item then return false end
    for _, tag in ipairs(TAGS) do
        if item:hasTag(tag) then return true end
    end
    return false
end

--- True for clothing still on a dead body.
---
--- This is the "it says the clothes are worn but they are lying in a
--- corpse" report. InventoryItem.isEquipped() is not a flag on the item,
--- it is a question asked of whatever owns the container:
---
---     getContainer() == null                    -> false
---     getContainer().getParent() is a character -> character.isEquipped(item)
---     getContainer().getParent() is IsoDeadBody -> deadBody.isEquipped(item)
---     otherwise                                 -> false
---
--- (read off the bytecode of zombie.inventory.InventoryItem, not guessed)
--- so every garment still on a zombie answers true, protected() treated it
--- as the player's own gear, and the pile came back empty with "Only worn,
--- held or favourite items here".
---
--- It is genuinely not rippable where it lies - RipClothing and
--- RipDenimClothing both carry the IsNotWorn input flag - so it is not
--- enough to stop protecting it. It has to come off the body first, which
--- is what the looting phase does.
function Rip.onCorpse(item)
    if not item then return false end
    local container = item:getContainer()
    if not container then return false end

    local ok, parent = pcall(function() return container:getParent() end)
    if not ok or not parent then return false end
    return instanceof(parent, "IsoDeadBody") == true
end

-- Answers from CraftRecipeManager, keyed by item type, for the length of
-- one menu build or one round.
--
-- This matters. Right clicking a t-shirt asks about every rippable thing
-- in reach twice - once for "this type", once for "everything" - and a
-- looted wardrobe is easily forty garments. Without this that is well
-- over a hundred engine queries between the click and the menu appearing.
-- Which recipe applies depends on the item type and on what tools are
-- around, and neither changes inside a single pass, so one answer per
-- type is enough.
local cache = nil

local function beginCache() cache = {} end
local function endCache()   cache = nil end

--- The rip recipe for this item, if there is one.
---
--- Asked of the game rather than matched against a list of item types, so
--- modded clothing with the right tags is picked up too.
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

Rip.recipeFor = recipeFor

--- Builds the same crafting logic the vanilla context menu would.
local function buildLogic(player, item, recipe)
    local logic = HandcraftLogic.new(player, nil, nil)
    logic:setIsoObject(logic:findCraftSurface(player, 2))
    logic:setContainers(containersOf(player))
    logic:setRecipeFromContextClick(recipe, item)
    return logic
end

--- True when the item must be left alone.
---
--- RipClothing and RipDenimClothing both carry IsNotWorn, so the engine
--- already refuses worn garments - but not the jacket clipped to your
--- belt, and not the one you flagged as a favourite. Ripping is
--- destructive and cannot be undone, so this is deliberately generous.
local function protected(player, item)
    if AA.opt("ripSkipFavorite") and item:isFavorite() then return true end

    -- Worn by a corpse is not worn by you. Checked before isEquipped(),
    -- which answers for whoever owns the container rather than for the
    -- player - see Rip.onCorpse.
    if Rip.onCorpse(item) then return false end

    if item:isEquipped() then return true end
    if player:isEquipped(item) then return true end
    if player:isPrimaryHandItem(item) or player:isSecondaryHandItem(item) then return true end
    if player:isAttachedItem(item) then return true end

    local worn = player:getWornItems()
    if worn and worn:contains(item) then return true end

    return false
end

Rip.protected = protected

--- Everything within reach that this job may rip. The items being carried
--- come first, so a full inventory is used up before anything is fetched.
--- The ground counts as a container: the loot window's floor is in the
--- list getContainers() hands back.
---
--- @param fullType string|nil  one item type only, or nil for everything
--- @return table items, number skipped, table toLoot
---         skipped = worn, held or favourite
---         toLoot  = still on a body, and has to come off it first
function Rip.collect(player, fullType)
    local skipped = 0

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

        if fullType and item:getFullType() ~= fullType then return false end
        if not Rip.isCandidate(item) then return false end
        if protected(player, item) then
            skipped = skipped + 1
            return false
        end
        return true
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

    -- The pre-filter lets unknown clothing through, so drop anything the
    -- engine has no recipe for before the count is shown to the player.
    --
    -- A garment still on a body never reaches the engine at all, and that
    -- is deliberate. The recipes carry IsNotWorn and the corpse counts as
    -- wearing it, so the answer would be "no" - and `recipeFor` caches by
    -- item type, so that "no" would be remembered for every identical
    -- shirt in the crate next to the body and make those disappear too.
    -- Corpse clothing is judged by its tags instead (the same tags the
    -- three recipes match on) and goes on the looting list; once it is in
    -- the inventory it is an ordinary item and takes the normal path.
    local out, toLoot = {}, {}
    for _, item in ipairs(carried) do
        if Rip.onCorpse(item) then
            if Rip.hasRipTag(item) then table.insert(toLoot, item) end
        elseif recipeFor(player, item, containers) then
            table.insert(out, item)
        end
    end

    return out, skipped, toLoot
end

--- Splits a pile into one list per recipe, keeping the order the pile
--- came in so carried items are still used before fetched ones.
--- @return table groups  { { recipe = , name = , items = { ... } }, ... }
local function groupByRecipe(player, items, containers)
    local order, byName = {}, {}

    for _, item in ipairs(items) do
        local recipe, name = recipeFor(player, item, containers)
        if recipe then
            local group = byName[name]
            if not group then
                group = { recipe = recipe, name = name, items = {} }
                byName[name] = group
                table.insert(order, group)
            end
            table.insert(group.items, item)
        end
    end

    return order
end

--- How much of the pile can actually be ripped right now.
--- @return number doable, number total, number skipped, number lootable
function Rip.countDoable(player, fullType)
    local items, skipped, toLoot = Rip.collect(player, fullType)
    local lootable = #toLoot
    if #items == 0 then return 0, 0, skipped, lootable end

    local containers = containersOf(player)
    local doable = 0

    for _, group in ipairs(groupByRecipe(player, items, containers)) do
        local logic = buildLogic(player, group.items[1], group.recipe)
        if logic:canPerformCurrentRecipe() then
            -- The argument is "recalculate", not a filter: with false the
            -- engine skips the maths and hands back a cached zero.
            local possible = logic:getPossibleCraftCount(true) or 0
            if possible > 0 then
                doable = doable + math.min(possible, #group.items)
            end
        end
    end

    return doable, #items, skipped, lootable
end

---------------------------------------------------------------------
-- the job
---------------------------------------------------------------------

--- The borrowed inputs a craft would otherwise carry straight back to the
--- container it took them from - here, the scissors or the knife.
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

    -- Garments for later rounds, fetched now. See the note in planRound.
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

    -- Reached both from inside a cached round and straight from think(),
    -- so it starts a cache only when there is not one already.
    local owned = cache == nil
    if owned then beginCache() end

    for _, item in ipairs(task.items) do
        -- Re-checked per item: an item may have been dropped, worn or
        -- ripped by hand while the queue was running.
        local container = item:getContainer()
        local guarded = container and protected(player, item)
        local recipe = (container and not guarded)
                and recipeFor(player, item, containers) or nil

        if recipe then
            ISInventoryPaneContextMenu.OnNewCraft(item, recipe, playerNum, false, nil)
            queued = queued + 1
            table.insert(pending, item)
        elseif not container then
            -- In transit, not gone. Same as Auto Dismantle: a transfer
            -- removes the item from the source before the destination takes
            -- it, and on a client the second half waits on the server. The
            -- gathering phase hands over the instant its queue drains, which
            -- is exactly that gap. Wait a tick rather than spend a re-plan.
            unsettled = unsettled + 1
        else
            -- Which of the three it was. "The batch queued nothing" has
            -- completely different causes depending on whether the garment
            -- went missing, got picked up and worn, or stopped resolving.
            print("[AutoAll] rip cannot craft " .. tostring(item:getFullType())
                    .. ": container=" .. tostring(container and "yes" or "GONE")
                    .. " protected=" .. tostring(guarded and "yes" or "no")
                    .. " recipe=" .. tostring(recipe and "yes" or "NONE")
                    .. " containers=" .. tostring(containers and containers:size() or -1))
        end
    end

    if owned then endCache() end
    task.pendingItems = pending
    return queued, unsettled
end

-- Rounds in a row where nothing was actually consumed before the job is
-- called stuck. From Mickey's maintenance fork (Workshop 3781695662).
local MAX_NO_PROGRESS = 3

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
    print("[AutoAll] rip: loot round moved none of " .. tostring(#pending)
            .. " (" .. tostring(task.lootStalls) .. "/"
            .. tostring(MAX_LOOT_STALLS) .. ")")
    return task.lootStalls < MAX_LOOT_STALLS
end


--- Did the crafts queued last round actually happen?
---
--- The queue draining is not evidence: ISHandcraftAction:isValid() checks
--- only the craft bench and that a recipe exists, so an action completes
--- whether or not it had anything to work with. All three rip recipes consume the selected garment or sheet,
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

--- Puts the scissors back where they came from, once, after the whole
--- batch instead of after every single garment.
local function returnSupplies(task)
    if not AA.opt("ripReturnItems") then return end

    local player = task.player
    for _, entry in ipairs(task.borrowedFrom) do
        if entry.item and entry.item:getContainer() == player:getInventory() then
            ISCraftingUI.ReturnItemToOriginalContainer(player, entry.item)
        end
    end
end

--- Everything sitting in the main inventory right now, as a set. Taken
--- the moment before the crafting starts, so whatever is not in it
--- afterwards is something the ripping produced.
local function snapshot(player)
    local seen = {}
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        seen[items:get(i)] = true
    end
    return seen
end

--- Sends the strips and sheets back to the wardrobe, crate or patch of
--- floor the clothing was taken from, so a big batch does not leave the
--- character loaded down.
---
--- Which items are "the results" is worked out by comparing the inventory
--- against the snapshot rather than against a list of expected outputs:
--- RipDenimClothing picks its output through an itemMapper, and a modded
--- recipe could produce anything at all.
local function returnResults(task)
    if not AA.opt("ripResultsToSource") then return end

    local dest = task.destination
    local player = task.player
    local inventory = player:getInventory()
    if not dest or dest == inventory then return end

    local items = inventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and not task.before[item] and not protected(player, item) then
            ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, inventory, dest))
        end
    end
end

-- Safety net on the round loop. Each round does at least one item, so
-- this caps batch size rather than being a limit anyone will meet.
-- On a client every round is a single craft (see planRound), so the round
-- budget has to cover a whole wardrobe rather than a handful of batches.
local MAX_ROUNDS = 40
local MAX_ROUNDS_CLIENT = 300

local function roundBudget()
    return isClient() and MAX_ROUNDS_CLIENT or MAX_ROUNDS
end

-- Stripping bodies. Bounded twice over: by how many garments one trip
-- takes, and by how much the character can still carry. A looted corpse
-- is easily forty pounds of leather and boots, and an overloaded
-- character loses health for as long as it stays overloaded - which is
-- how a mechanics run once carried a character to death.
local LOOT_BATCH        = isClient() and 3 or 12
local MAX_LOOT_ROUNDS   = 40

--- Takes rippable clothing off the bodies in reach and into the inventory,
--- so the next round can treat it as an ordinary pile. Returns false when
--- it could not move anything.
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

        -- At least one garment always goes, even when the character is
        -- already loaded: it is about to be ripped into something lighter.
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

--- Works out what can be ripped right now and queues the fetching for it.
--- Returns false when there is nothing left to do.
---
--- Shared by Rip.start and by think(), so follow-up rounds are set up
--- exactly the way the first one is.
-- Rounds in a row that planned a batch and then queued no craft at all.
local MAX_EMPTY_CRAFTS = 3

-- Ticks a batch may wait for a transfer to land before it is treated as a
-- stale plan rather than a slow one.
local MAX_UNSETTLED = 5

-- How many garments beyond this round's batch to pull in while we are already
-- waiting on a transfer. They ride the same server round trip.
local PREFETCH = 6

-- Why the last round could not be planned. Auto Dismantle got this first;
-- Rip had the same problem and the same single answer for every dead end,
-- which is how "No scissors or sharp knife within reach" ended up being
-- shown to a player holding scissors.
local STOP_TEXT = {
    -- "nothing found" and "everything found is protected" are different
    -- answers. Mapping the first onto UI_AA_rip_protected told players their
    -- clothes were worn when the real answer was that the sweep came back
    -- empty, or that a transfer had not landed yet.
    nothing = "UI_AA_rip_nothing",
    notool  = "UI_AA_rip_notool",
    blocked = "UI_AA_rip_blocked",
}

local function stopText(task)
    print("[AutoAll] rip stopping: reason=" .. tostring(task.failReason or "unset")
            .. " items=" .. tostring(task.lastItems)
            .. " toLoot=" .. tostring(task.lastToLoot)
            .. " batch=" .. tostring(task.batchSize)
            .. " queued=" .. tostring(task.queued)
            .. " succeeded=" .. tostring(task.succeeded)
            .. " rounds=" .. tostring(task.rounds)
            .. " loot=" .. tostring(task.lootRounds) .. "/" .. tostring(task.lootStalls or 0)
            .. " emptyCrafts=" .. tostring(task.emptyCrafts or 0))
    return getText(STOP_TEXT[task.failReason] or "UI_AA_rip_blocked")
end

local function planRound(task)
    local player = task.player

    local items, _, toLoot = Rip.collect(player, task.fullType)
    task.lastItems, task.lastToLoot = #items, #toLoot

    -- Nothing ready to rip, but there is still a body wearing some. Strip
    -- it and come back: the next round sees ordinary inventory items.
    if #items == 0 then
        if #toLoot > 0 and task.lootRounds < MAX_LOOT_ROUNDS then
            task.lootRounds = task.lootRounds + 1
            if queueLooting(task, toLoot) then return true end
        end
        task.failReason = (#toLoot > 0) and "blocked" or "nothing"
        return false
    end

    local containers = containersOf(player)
    local batch, supplies = {}, {}

    local cap = AA.opt("ripMax") or 0
    local room = nil
    if cap > 0 then
        -- The cap is for the whole job, not for each round.
        room = math.max(0, cap - task.queued)
        if room == 0 then return false end
    end

    -- On a client the batch is only as big as the last round earned. This
    -- is the fix for extra cloth.
    --
    -- ISHandcraftAction:isValid() checks two things and neither of them is
    -- whether the inputs still exist:
    --
    --     if self.craftBench then ... end
    --     if (not self.craftRecipe) then return false end
    --     return true
    --
    -- So a batch queued in one tick is validated once, against the
    -- inventory as it looked before any of it ran. Every action in that
    -- batch then completes whether or not there is anything left to
    -- consume - which is output without input. In single player the
    -- inventory is consistent the instant an action finishes and the
    -- planned count holds; on a client transfers settle asynchronously and
    -- the plan is made against a stale view.
    --
    -- It used to be a flat one per round here, which was safe and painfully
    -- slow on a wardrobe. AA.batchSize starts at one and only grows after a
    -- round the game confirmed in full - see the core for the reasoning.
    -- Not named `batch`: that is the list of items this round will rip,
    -- declared above, and shadowing it with a number turns the loop below
    -- into table.insert(number, item).
    local clientCap = AA.batchSize(task)
    if clientCap then
        room = math.min(room or clientCap, clientCap)
    end

    for _, group in ipairs(groupByRecipe(player, items, containers)) do
        local logic = buildLogic(player, group.items[1], group.recipe)
        if logic:canPerformCurrentRecipe() then
            local possible = logic:getPossibleCraftCount(true) or 0
            local doable = math.min(possible, #group.items)
            if room then doable = math.min(doable, room - #batch) end

            if doable > 0 then
                for i = 1, doable do
                    table.insert(batch, group.items[i])
                end
                for _, item in ipairs(borrowedSupplies(player, logic)) do
                    table.insert(supplies, item)
                end
            end
        end
    end

    if #batch == 0 then return false end

    -- Fetch ahead of the batch.
    --
    -- Same reasoning as Auto Dismantle. On a client the CRAFT batch is held
    -- small on purpose, because ISHandcraftAction does not check its inputs
    -- still exist. Transfers have no such problem, so there is no reason to pay
    -- a server round trip per garment just because few are ripped per round -
    -- and on a client that round trip is a two to three second wait on a full
    -- progress bar, once per item.
    --
    -- Bounded by carry weight, which matters more here than for electronics: a
    -- wardrobe of leather and boots is heavy, and an overloaded character loses
    -- health for as long as it stays overloaded.
    local inBatch = {}
    for _, item in ipairs(batch) do inBatch[item] = true end

    local prefetch = {}
    local gotCarry, carry = pcall(function()
        return player:getMaxWeight() - player:getInventoryWeight()
    end)
    if not gotCarry or type(carry) ~= "number" then carry = 0 end

    for _, ahead in ipairs(items) do
        if #prefetch >= PREFETCH then break end
        if not inBatch[ahead] and ahead:getContainer() ~= player:getInventory() then
            local weight = 0
            local gotWeight, value = pcall(function() return ahead:getWeight() end)
            if gotWeight and type(value) == "number" then weight = value end
            if (carry - weight) < 0 then break end
            carry = carry - weight
            table.insert(prefetch, ahead)
        end
    end
    task.prefetch = prefetch

    -- Remember where each borrowed item came from before it is moved.
    -- Later rounds usually add nothing: the scissors are already here.
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
        return queued > 0
    end

    return true
end

--- planRound with the recipe answers cached for its duration, which is
--- what every caller wants. Kept as a wrapper rather than folded in so
--- the cache is guaranteed to be cleared even when the round throws.
local function beginRound(task)
    beginCache()
    local ok, result = pcall(planRound, task)
    endCache()

    if not ok then
        print("[AutoAll] rip round error: " .. tostring(result))
        return false
    end
    return result
end

local function think(task)
    local player = task.player

    if AA.isQueueBusy(player) then return end

    if not confirmPendingCrafts(task) then
        -- Three rounds where the game consumed nothing. Say the numbers, so
        -- "something went wrong" is diagnosable instead of just discouraging.
        task.failReason = task.failReason or "blocked"
        print("[AutoAll] rip: no progress in " .. tostring(MAX_NO_PROGRESS) .. " rounds")
        AA.stop(player, stopText(task), true)
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
        AA.reason(task, getText("UI_AA_rip_working"))
        -- Snapshot only on the first round: everything fetched during
        -- gathering is already in the inventory, so it will not be
        -- mistaken for a result later. Later rounds must keep the original
        -- snapshot, or the strips made so far would look like they were
        -- always there and would never be sent home.
        if not task.before then task.before = snapshot(player) end
        local queued, unsettled = queueCrafting(task)
        task.queued = task.queued + queued

        -- Nothing queued, but only because a transfer had not landed. Come
        -- back next tick with the same batch instead of spending a re-plan.
        if queued == 0 and unsettled > 0
                and (task.unsettled or 0) < MAX_UNSETTLED then
            task.unsettled = (task.unsettled or 0) + 1
            task.phase = "gathering"
            return
        end
        task.unsettled = 0

        if queued == 0 then
            -- The batch was planned before the fetching ran, and fetching
            -- moves the character. containersOf reads the loot window, so
            -- walking to a wardrobe changes what counts as within reach. A
            -- stale batch is not an impossible pile: plan again against the
            -- world as it is now. Bounded, so a pile that genuinely cannot
            -- be worked still ends rather than spinning.
            task.emptyCrafts = (task.emptyCrafts or 0) + 1
            if task.emptyCrafts < MAX_EMPTY_CRAFTS and task.rounds < roundBudget() then
                print("[AutoAll] rip re-planning after an empty craft round ("
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
        -- the minimum across every input of the recipe, and the denim
        -- recipe has a kept pair of scissors alongside the clothing, so
        -- the first answer can be far smaller than the pile allows.
        if task.rounds < roundBudget() then
            task.rounds = task.rounds + 1
            if beginRound(task) then return end
        end

        task.phase = "returning"
        returnSupplies(task)
        returnResults(task)
        return
    end

    AA.stop(player, getText("UI_AA_rip_done", task.succeeded), false)
end

function Rip.start(player, fullType, label, destination)
    if not player then return end

    beginCache()
    local items, skipped, toLoot = Rip.collect(player, fullType)
    endCache()

    if #items == 0 and #toLoot == 0 then
        -- Say in the log what was actually looked at and why it was
        -- turned down. Reports of "it will not rip the clothes in this
        -- container" have no way to be told apart otherwise: an empty
        -- pile looks the same whether the items were protected, had no
        -- recipe, or were never in reach in the first place.
        local seen, noRecipe = 0, 0
        local containers = containersOf(player)
        for i = 0, containers:size() - 1 do
            local container = containers:get(i)
            if container then
                local found = container:getAllEvalRecurse(function(candidate)
                    return (not fullType or candidate:getFullType() == fullType)
                        and Rip.isCandidate(candidate)
                end, ArrayList.new())
                if found then
                    for j = 0, found:size() - 1 do
                        seen = seen + 1
                        local candidate = found:get(j)
                        if not Rip.onCorpse(candidate)
                                and not protected(player, candidate)
                                and not recipeFor(player, candidate, containers) then
                            noRecipe = noRecipe + 1
                        end
                    end
                end
            end
        end
        print("[AutoAll] rip found nothing: type=" .. tostring(fullType)
            .. " candidates=" .. tostring(seen)
            .. " protected=" .. tostring(skipped or 0)
            .. " no_recipe=" .. tostring(noRecipe)
            .. " containers=" .. tostring(containers:size()))

        local why = (skipped or 0) > 0 and "UI_AA_rip_protected" or "UI_AA_rip_nothing"
        HaloTextHelper.addBadText(player, getText(why))
        return
    end

    local task = {
        kind         = "rip",
        player       = player,
        fullType     = fullType,      -- nil means "everything in reach"
        items        = {},
        supplies     = {},
        borrowedFrom = {},
        borrowedSeen = {},
        -- Where the strips go at the end. Falls back to the container the
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
        startText    = getText("UI_AA_rip_started", #items + #toLoot, label),
    }

    AA.startTask(task)

    if not beginRound(task) then
        AA.stop(player, stopText(task), true)
    end
end

Rip.onStart = function(player, fullType, label, destination)
    Rip.start(player, fullType, label, destination)
end

Rip.onStop = function(player)
    AA.stop(player, getText("UI_AA_stopped"), false)
end

---------------------------------------------------------------------
-- context menu
---------------------------------------------------------------------

--- One entry, greyed out with a reason rather than hidden when it cannot
--- run, so it never looks like the option is missing.
local function addEntry(context, player, text, fullType, label, destination)
    local doable, total, skipped, lootable = Rip.countDoable(player, fullType)
    skipped  = skipped or 0
    lootable = lootable or 0

    if total == 0 and skipped == 0 and lootable == 0 then return end

    local option = AA.addOption(context, text, player, Rip.onStart, fullType, label, destination)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()

    if total == 0 and lootable > 0 then
        -- Everything rippable is still on a body. The job can do this: it
        -- strips the bodies first. Greying it out here is what made the
        -- pile look untouchable.
        tooltip.description = getText("UI_AA_rip_from_body", lootable)
    elseif total == 0 then
        option.notAvailable = true
        tooltip.description = getText("UI_AA_rip_protected")
    elseif doable == 0 then
        option.notAvailable = true
        tooltip.description = getText("UI_AA_rip_notool")
    else
        tooltip.description = getText("UI_AA_rip_option_tt", doable, total)
        if lootable > 0 then
            tooltip.description = tooltip.description .. " <LINE> <RGB:0.7,0.85,1> "
                .. getText("UI_AA_rip_from_body", lootable)
        end
    end

    if skipped > 0 and not option.notAvailable then
        tooltip.description = tooltip.description .. " <LINE> <RGB:0.7,0.85,1> "
            .. getText("UI_AA_rip_keeping", skipped)
    end

    option.toolTip = tooltip
    return option
end

local function buildRipMenu(player, context, item)
    -- Only offer this on something the game will actually rip. A garment
    -- still on a body is asked about by tag rather than by recipe, and is
    -- deliberately kept away from recipeFor - see Rip.collect for why that
    -- would poison the answer for every other garment of the same type.
    if Rip.onCorpse(item) then
        if not Rip.hasRipTag(item) then return end
    elseif not recipeFor(player, item, containersOf(player)) then
        return
    end

    -- Right clicking one inside a wardrobe, a crate or on the floor sends
    -- the strips back there. Used on something already carried, they stay
    -- in the inventory.
    -- A corpse is never a destination, however the option is set: stuffing
    -- fresh rags into the body they came off is not "back where it came
    -- from", it is losing them.
    local clicked = item:getContainer()
    local destination = nil
    if clicked and clicked ~= player:getInventory() and not Rip.onCorpse(item) then
        destination = clicked
    end

    local label = item:getDisplayName()
    addEntry(context, player, getText("UI_AA_rip_option", label),
             item:getFullType(), label, destination)

    -- The wardrobe emptying entry. Separate and explicitly labelled,
    -- because unlike the one above it will take apart things the player
    -- did not right click on.
    addEntry(context, player, getText("UI_AA_rip_option_all"),
             nil, getText("UI_AA_rip_label_all"), destination)
end

local function addRipMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local actual = ISInventoryPane.getActualItems(items)
    local item = actual and actual[1]
    if not item or not Rip.isCandidate(item) then return end

    if AA.isRunning(player, "rip") then
        AA.addOption(context, getText("UI_AA_rip_stop"), player, Rip.onStop)
        return
    end

    -- One cache for the whole menu build: both entries below walk the
    -- same pile, and without this the click would visibly hang on a
    -- character standing in front of a full wardrobe.
    beginCache()
    local ok, err = pcall(buildRipMenu, player, context, item)
    endCache()

    if not ok then print("[AutoAll] rip menu error: " .. tostring(err)) end
end

AA.registerMenu("rip", Events.OnFillInventoryObjectContextMenu, addRipMenu)
