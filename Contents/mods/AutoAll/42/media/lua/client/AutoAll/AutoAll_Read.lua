--[[
    Auto All - Read (Build 42 / SP + MP)
    ------------------------------------------------------------------
    "Read Everything": right click any book or magazine and the character
    works through every skill book and skill magazine within reach, one
    after the other, fetching them from nearby containers and putting
    them back when it is done with each one.

    Only literature that still teaches something is picked up:

      * skill books whose level band matches the character (vanilla's own
        "too complicated" and "too simple" rules), and that are not
        already fully read;
      * recipe magazines that still hold at least one unknown recipe.

    Comics, newspapers, photos and empty notebooks are left alone - they
    are for boredom, not for skills.

    Only the vanilla ISReadABook is queued, so the XP multipliers, the
    page bookkeeping and the multiplayer sync are the base game's.
]]

require "AutoAll/AutoAll_Core"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.readLoaded then return end
AA.readLoaded = true

AA.Read = AA.Read or {}
local Read = AA.Read

-- sort order: lower goes first
local ORDER_UNFINISHED = 0      -- a book already started - finish it
local ORDER_MAGAZINE   = 20     -- recipes are a one-off, do them after the books

local BATCH_BOOKS = 6           -- books queued at a time
local REFILL_AT   = 2           -- queue more once this few are left
local MAX_NO_PROGRESS = 3       -- retries for an action that changes nothing

---------------------------------------------------------------------
-- what is worth reading
---------------------------------------------------------------------

function Read.isLiterature(item)
    return item ~= nil and instanceof(item, "Literature")
end

function Read.skillOf(item)
    local skill = item:getSkillTrained()
    if not skill or skill == "" then return nil end
    local entry = SkillBook[skill]
    if not entry or not entry.perk then return nil end
    if item:getLvlSkillTrained() == -1 then return nil end
    return entry
end

function Read.isRecipeMagazine(item)
    local learned = item:getLearnedRecipes()
    return learned ~= nil and learned:size() > 0
end

--- nil when there is nothing to gain, otherwise { item, order, kind }.
function Read.appraise(player, item)
    if not Read.isLiterature(item) then return nil end
    if item:hasTag(ItemTag.UNINTERESTING) then return nil end

    local skillBook = Read.skillOf(item)
    if skillBook then
        if not AA.opt("readSkillBooks") then return nil end

        -- The two vanilla rules, straight from doLiteratureMenu.
        local level = player:getPerkLevel(skillBook.perk)
        if item:getLvlSkillTrained() > level + 1 then return nil end    -- too complicated
        if item:getMaxLevelTrained() <= level then return nil end       -- too simple

        local pages = item:getNumberOfPages()
        local read  = pages > 0 and player:getAlreadyReadPages(item:getFullType()) or 0
        if pages > 0 and read >= pages then return nil end              -- nothing left in it

        local order = item:getLvlSkillTrained()
        if read > 0 then order = ORDER_UNFINISHED end
        return { item = item, order = order, kind = "book" }
    end

    if Read.isRecipeMagazine(item) then
        if not AA.opt("readMagazines") then return nil end
        local learned = item:getLearnedRecipes()
        local known = item:getKnownRecipes(player)
        if known and known:size() >= learned:size() then return nil end -- all of it is known
        return { item = item, order = ORDER_MAGAZINE, kind = "magazine" }
    end

    return nil
end

---------------------------------------------------------------------
-- finding the books
---------------------------------------------------------------------

local function isLiteraturePredicate(item)
    return instanceof(item, "Literature")
end

local function scan(container, player, found, seen)
    if not container then return end
    local items = container:getAllEvalRecurse(isLiteraturePredicate, ArrayList.new())
    if not items then return end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local id = item:getID()
        if not seen[id] then
            seen[id] = true
            local entry = Read.appraise(player, item)
            if entry then table.insert(found, entry) end
        end
    end
end

--- Everything the character can reach: their own bags, plus the containers
--- the loot window is currently showing.
function Read.collect(player)
    local found, seen = {}, {}

    scan(player:getInventory(), player, found, seen)

    if AA.opt("readNearby") then
        local containers = ISInventoryPaneContextMenu.getContainers(player)
        if containers then
            for i = 0, containers:size() - 1 do
                scan(containers:get(i), player, found, seen)
            end
        end
    end

    return found
end

function Read.pickNext(task)
    local best = nil
    for _, entry in ipairs(Read.collect(task.player)) do
        local id = entry.item:getID()
        if not task.done[id] and not task.inFlight[id] and not task.failed[id] then
            if best == nil or entry.order < best.order then best = entry end
        end
    end
    return best
end

---------------------------------------------------------------------
-- the loop
---------------------------------------------------------------------

local function readProgress(player, item)
    local skill = Read.skillOf(item)
    if skill then
        return player:getAlreadyReadPages(item:getFullType()) or 0
    end
    if Read.isRecipeMagazine(item) then
        local known = item:getKnownRecipes(player)
        return known and known:size() or 0
    end
    return 0
end

local function queueRead(task, item)
    local player = task.player
    local home = item:getContainer()

    ISInventoryPaneContextMenu.transferIfNeeded(player, item)

    local action = ISReadABook:new(player, item)
    ISTimedActionQueue.add(action)
    table.insert(task.pendingReads, {
        item = item,
        action = action,
        before = readProgress(player, item),
    })
    task.inFlight[item:getID()] = true

    if AA.opt("readReturnItems") then
        ISCraftingUI.ReturnItemToContainer(player, item, home)
    end

    return action
end

local function confirmPendingReads(task)
    local waiting = {}
    local progressed = false

    for _, entry in ipairs(task.pendingReads) do
        if ISTimedActionQueue.hasAction(entry.action) then
            table.insert(waiting, entry)
        else
            local item = entry.item
            local id = item:getID()
            task.inFlight[id] = nil

            if Read.appraise(task.player, item) == nil then
                task.done[id] = true
                task.read = task.read + 1
                task.noProgress[id] = nil
                progressed = true
            else
                local after = readProgress(task.player, item)
                if after > entry.before then
                    task.noProgress[id] = nil
                    progressed = true
                else
                    local failures = (task.noProgress[id] or 0) + 1
                    task.noProgress[id] = failures
                    if failures >= MAX_NO_PROGRESS then
                        task.failed[id] = true
                    end
                end
            end
        end
    end

    task.pendingReads = waiting
    return #waiting, progressed
end

--- Queues a run of books in one go.
---
--- Reading used to be confirmed one book at a time, which left a gap
--- between each one and stopped the clock from being fast forwarded.
--- The books are independent, so a batch can go in up front.
local function queueBatch(task)
    local maxBooks = AA.opt("readMaxBooks") or 0
    local queued = 0

    for _ = 1, BATCH_BOOKS do
        if maxBooks > 0 and task.read + #task.pendingReads >= maxBooks then break end

        local entry = Read.pickNext(task)
        if not entry then break end

        queueRead(task, entry.item)
        task.queued = task.queued + 1
        queued = queued + 1
    end

    return queued
end

local function think(task)
    local player = task.player

    local remaining = confirmPendingReads(task)

    if player:isAsleep() then
        AA.stop(player, getText("UI_AA_read_stopped"), true)
        return
    end
    if player:tooDarkToRead() then
        AA.stop(player, getText("UI_AA_read_toodark"), true)
        return
    end

    local maxBooks = AA.opt("readMaxBooks") or 0
    if maxBooks > 0 and task.read >= maxBooks and remaining == 0 then
        AA.stop(player, getText("UI_AA_read_done", task.read), false)
        return
    end

    for _, failures in pairs(task.noProgress) do
        if failures >= MAX_NO_PROGRESS then
            AA.stop(player, getText("UI_AA_stop_error"), true)
            return
        end
    end

    if remaining > REFILL_AT then return end

    if queueBatch(task) == 0 and remaining == 0 and not AA.isQueueBusy(player) then
        AA.stop(player, getText("UI_AA_read_done", task.read), false)
    end
end

function Read.start(player)
    if not player then return end

    if player:hasTrait(CharacterTrait.ILLITERATE) then
        HaloTextHelper.addBadText(player, getText("UI_AA_read_illiterate"))
        return
    end
    if player:tooDarkToRead() then
        HaloTextHelper.addBadText(player, getText("UI_AA_read_toodark"))
        return
    end

    local found = Read.collect(player)
    if #found == 0 then
        HaloTextHelper.addBadText(player, getText("UI_AA_read_nothing"))
        return
    end

    local task = {
        kind      = "read",
        player    = player,
        done      = {},
        inFlight  = {},
        failed    = {},
        noProgress = {},
        pendingReads = {},
        read      = 0,
        queued    = 0,
        think     = think,
        allowMove = true,   -- reading fetches books from shelves on its own
        startText = getText("UI_AA_read_started", #found),
    }

    AA.startTask(task)
    queueBatch(task)
end

Read.onStart = function(player)
    Read.start(player)
end

Read.onStop = function(player)
    AA.stop(player, getText("UI_AA_stopped"), false)
end

---------------------------------------------------------------------
-- context menu
---------------------------------------------------------------------

local function addReadMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local actual = ISInventoryPane.getActualItems(items)
    if not actual or not Read.isLiterature(actual[1]) then return end

    if AA.isRunning(player, "read") then
        AA.addOption(context, getText("UI_AA_read_stop"), player, Read.onStop)
        return
    end

    local option = AA.addOption(context, getText("UI_AA_read_option"), player, Read.onStart)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()

    if player:hasTrait(CharacterTrait.ILLITERATE) then
        option.notAvailable = true
        tooltip.description = getText("UI_AA_read_illiterate")
    elseif player:tooDarkToRead() then
        option.notAvailable = true
        tooltip.description = getText("UI_AA_read_toodark")
    else
        local found = Read.collect(player)
        local books, magazines = 0, 0
        for _, entry in ipairs(found) do
            if entry.kind == "magazine" then magazines = magazines + 1 else books = books + 1 end
        end
        if #found == 0 then
            option.notAvailable = true
            tooltip.description = getText("UI_AA_read_nothing")
        else
            tooltip.description = getText("UI_AA_read_option_tt", books, magazines)
        end
    end
    option.toolTip = tooltip
end

AA.registerMenu("read", Events.OnFillInventoryObjectContextMenu, addReadMenu)
