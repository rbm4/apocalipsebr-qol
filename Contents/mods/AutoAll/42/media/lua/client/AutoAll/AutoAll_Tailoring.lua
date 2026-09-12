--[[
    Auto All - Tailoring (Build 42 / SP + MP)
    ------------------------------------------------------------------
    "Train Tailoring": a button on the clothing inspection window (and an
    entry on the clothing context menu).

    The character sews a patch onto every body part the garment covers,
    then unpicks all of them, then starts over. Both halves give Tailoring
    XP in vanilla, so the loop trains the skill for as long as the rags
    and thread last.

    Needed: a needle, thread, and rags (ripped sheets, denim strips or
    leather strips). They may sit in an equipped bag. The garment does not
    have to be worn.

    Materials are spent exactly as vanilla spends them. The mod queues the
    vanilla ISRepairClothing and ISRemovePatch actions and touches nothing
    else - no patch data, no inventory bookkeeping.

    An earlier version tried to keep the rags and thread from being used
    up during training. It broke: after the first few stitches the game
    and the mod disagreed about what was in the inventory, the action
    jammed, rags could not be picked up or dropped, and on a dedicated
    server a reconnect showed them spent anyway. Giving items back behind
    the game's back means fighting the item sync, and the item sync wins.
    Automating the clicking is this mod's job; the economy is the game's.
]]

require "AutoAll/AutoAll_Core"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.tailorLoaded then return end
AA.tailorLoaded = true

AA.Tailor = AA.Tailor or {}
local Tailor = AA.Tailor

local FABRIC_TYPES = { "RippedSheets", "DenimStrips", "LeatherStrips" }

-- How few actions may be left before the next cycle is queued, and how
-- many cycles to keep queued ahead.
--
-- One cycle at a time left a gap between cycles: the queue emptied, the
-- think loop had to notice and refill, and in single player an empty queue
-- ends the fast forward - so the character stopped every few stitches and
-- the clock stopped with it. Auto Reload solved the same thing by queueing
-- a deep batch up front. Same here: keep several cycles in the queue so it
-- never runs dry.
--
-- Single player only for the depth. On a client a long queue holds stale
-- item instances, which is the trap documented at the top of
-- AutoAll_Reload.lua, so there it stays shallow and refills often.
local REFILL_AT      = 12
local QUEUE_AHEAD    = 4
local QUEUE_AHEAD_MP = 1

local function queueAhead()
    return isClient() and QUEUE_AHEAD_MP or QUEUE_AHEAD
end
local STALL_MS  = 20000     -- no stitch finished for this long means something is wrong

---------------------------------------------------------------------
-- resources
---------------------------------------------------------------------

-- These all go through AA.findItem / AA.findItemByTag rather than
-- getItemFromType directly. Same call first, plus a recursive sweep when
-- it comes up empty - a needle or a pile of rags in a backpack used to
-- read as "you have none". See the note on AA.findItem.

function Tailor.findNeedle(player)
    return AA.findItem(player, "Needle")
        or AA.findItemByTag(player, ItemTag.SEWING_NEEDLE)
end

function Tailor.findThread(player)
    return AA.findItem(player, "Thread")
        or AA.findItemByTag(player, ItemTag.THREAD)
end

--- Honours the "fabric" option: 1 = any (cheapest first), 2/3/4 = a specific one.
function Tailor.findFabric(player)
    local choice = AA.opt("tailorFabric") or 1

    if choice > 1 then
        return AA.findItem(player, FABRIC_TYPES[choice - 1])
    end
    for _, fabricType in ipairs(FABRIC_TYPES) do
        local fabric = AA.findItem(player, fabricType)
        if fabric then return fabric end
    end
    return nil
end

function Tailor.canTrain(player, clothing)
    -- getFabricType and getCoveredParts live on Clothing, not on every item.
    if not clothing or not instanceof(clothing, "Clothing") then return false end
    if not clothing:getFabricType() then return false end
    local parts = clothing:getCoveredParts()
    return parts ~= nil and parts:size() > 0
end

---------------------------------------------------------------------
-- the loop
---------------------------------------------------------------------

local function partsOf(clothing)
    local parts = {}
    local covered = clothing:getCoveredParts()
    for i = 0, covered:size() - 1 do
        table.insert(parts, covered:get(i))
    end
    return parts
end

--- Sewing order for one cycle: real holes go first when the option asks
--- for it, so an interrupted session still leaves the garment repaired.
local function sewingOrder(task)
    if not AA.opt("tailorHolesFirst") then return task.parts end

    local clothing = task.clothing
    local holes, intact = {}, {}
    for _, part in ipairs(task.parts) do
        if clothing:getVisual():getHole(part) > 0 then
            table.insert(holes, part)
        else
            table.insert(intact, part)
        end
    end
    for _, part in ipairs(intact) do
        table.insert(holes, part)
    end
    return holes
end

-- Only our own two actions count as progress; transfers the vanilla
-- helpers queue alongside them must not be mistaken for stitches.
local OUR_ACTIONS = {
    ISRepairClothing = true,
    ISRemovePatch    = true,
}

local function countOurActions(player)
    local queue = AA.getQueue(player)
    if not queue then return 0 end
    local count = 0
    for _, action in ipairs(queue) do
        if OUR_ACTIONS[action.Type] then count = count + 1 end
    end
    return count
end

--- Queues a whole cycle at once: a patch on every bare part, then an
--- unpick for every one of them.
---
--- This used to queue a single stitch and wait a tick to confirm it,
--- which left a gap between every action and stopped the clock from
--- being fast forwarded. The vanilla actions validate themselves when
--- their turn comes, so a whole cycle can safely go in up front.
local function queueCycle(task)
    local player   = task.player
    local clothing = task.clothing

    local needle = Tailor.findNeedle(player)
    local thread = Tailor.findThread(player)
    local fabric = AA.findItem(player, task.fabricType)
    if not needle or not thread or not fabric then return false end

    local queued = 0
    local toUnpick = {}

    for _, part in ipairs(sewingOrder(task)) do
        if clothing:getPatchType(part) == nil then
            ISInventoryPaneContextMenu.repairClothing(player, clothing, part, fabric, thread, needle)
            queued = queued + 1
        end
        table.insert(toUnpick, part)
    end

    for _, part in ipairs(toUnpick) do
        ISInventoryPaneContextMenu.removePatch(player, clothing, part, needle)
        queued = queued + 1
    end

    if queued == 0 then return false end

    task.queued = task.queued + queued
    task.cyclesQueued = task.cyclesQueued + 1
    return true
end

--- Re-finds the garment being trained on, by id, every tick.
---
--- What this replaces was `player:getInventory():contains(clothing)`, and
--- it was wrong twice over:
---
---  * `contains` only looks in the **main inventory**. A garment inside a
---    backpack fails it, so training stopped instantly with "the garment
---    is gone" on everything except the jacket the character was wearing -
---    worn items sit in the main inventory, which is why that one case
---    worked and made the fault look like a lock-up on one item.
---  * on a client, item instances are replaced as transfers settle, so
---    even the right garment in the right place stops matching by
---    identity. Auto Reload already solves exactly this by re-resolving
---    from the id (see the note at the top of AutoAll_Reload.lua); this is
---    the same fix.
---
--- getItemById searches the whole inventory tree, so a garment in a bag,
--- in a bag, is still found.
local function currentGarment(task)
    local found = task.player:getInventory():getItemById(task.clothingId)
    if found then task.clothing = found end
    return found
end

local function think(task)
    local player   = task.player
    local clothing = currentGarment(task)

    if not clothing then
        AA.stop(player, getText("UI_AA_tailor_lost"), true)
        return
    end

    local remaining = countOurActions(player)
    local finished  = task.queued - remaining

    if finished > task.stitches then
        task.stitches = finished
        task.lastProgress = AA.now()
    elseif remaining > 0 and AA.now() - task.lastProgress > STALL_MS then
        AA.stop(player, getText("UI_AA_tailor_interrupted"), true)
        return
    end

    task.cycles = math.floor(task.stitches / math.max(1, #task.parts * 2))

    local maxCycles = AA.opt("tailorMaxCycles") or 0
    if maxCycles > 0 and task.cyclesQueued >= maxCycles and remaining == 0 then
        AA.stop(player, getText("UI_AA_tailor_done", task.cyclesQueued), false)
        return
    end

    if remaining > REFILL_AT then return end
    if maxCycles > 0 and task.cyclesQueued >= maxCycles then return end

    if not Tailor.findNeedle(player) then
        AA.stop(player, getText("UI_AA_tailor_noneedle"), true)
        return
    end
    if not Tailor.findThread(player) then
        AA.stop(player, getText("UI_AA_tailor_nothread"), true)
        return
    end
    if not AA.findItem(player, task.fabricType) then
        AA.stop(player, getText("UI_AA_tailor_nofabric"), true)
        return
    end

    -- No running commentary. A line of halo text every few seconds is
    -- unreadable at 5x and, more to the point, it was asked to go: it
    -- interrupts the single player fast forward. Only the start and the
    -- finish speak now, the same way Auto Mechanics was quietened.

    -- Several cycles go in at once so the queue never runs dry between
    -- them. An empty queue is what ends the fast forward, which is why the
    -- character kept stopping halfway.
    local queued = false
    for _ = 1, queueAhead() do
        if maxCycles > 0 and task.cyclesQueued >= maxCycles then break end
        if not queueCycle(task) then break end
        queued = true
    end

    if not queued and remaining == 0 then
        AA.stop(player, getText("UI_AA_tailor_interrupted"), true)
    end
end

function Tailor.start(player, clothing)
    if not player or not Tailor.canTrain(player, clothing) then return end

    if not Tailor.findNeedle(player) then
        HaloTextHelper.addBadText(player, getText("UI_AA_tailor_noneedle"))
        return
    end
    if not Tailor.findThread(player) then
        HaloTextHelper.addBadText(player, getText("UI_AA_tailor_nothread"))
        return
    end
    local fabric = Tailor.findFabric(player)
    if not fabric then
        HaloTextHelper.addBadText(player, getText("UI_AA_tailor_nofabric"))
        return
    end

    local task = {
        kind             = "tailoring",
        player           = player,
        clothing         = clothing,
        -- The garment is re-found from this every tick rather than held
        -- by reference. See currentGarment.
        clothingId       = clothing:getID(),
        parts            = partsOf(clothing),
        fabricType       = fabric:getType(),
        stitches         = 0,
        cycles           = 0,
        cyclesQueued     = 0,
        queued           = 0,
        -- A single action that never ends freezes the whole job in
        -- silence: think() is gated on the queue draining, so nothing
        -- is ever said and nothing is written to the log. Reported by
        -- Talkierplacebo2 on a hosted game - ripping and healing
        -- "gets to 99% done and never continues". AA.queueStalled
        -- clears a head that has not moved in this long, and gives up
        -- with a message after three of them rather than grinding on.
        stallTimeout     = 30000,
        lastProgress     = AA.now(),
        think            = think,
        clearQueueOnStop = true,
        startText        = getText("UI_AA_tailor_started"),
    }

    AA.startTask(task)
    queueCycle(task)
end

Tailor.onStart = function(player, clothing)
    Tailor.start(player, clothing)
end

Tailor.onStop = function(player)
    AA.stop(player, getText("UI_AA_stopped"), false)
end

---------------------------------------------------------------------
-- Auto Repair: find the holes and sew them shut
--
-- Training and repairing are two different jobs. The loop above patches
-- intact parts purely to earn XP and unpicks them again; this one hunts
-- for actual damage and stops when there is none left.
--
-- Holes are read from the garment's visual, which is where the game
-- keeps them and where the inspection window reads them from. A part
-- that already carries a patch is skipped: ISRepairClothing refuses it
-- (getPatchType(part) == nil is part of its isValid) and the hole under
-- an existing patch is already covered.
---------------------------------------------------------------------

--- Every covered part of this garment that has an open hole.
local function holedParts(clothing)
    local out = {}
    if not instanceof(clothing, "Clothing") then return out end

    local covered = clothing:getCoveredParts()
    local visual  = clothing:getVisual()
    if not covered or not visual then return out end

    for i = 0, covered:size() - 1 do
        local part = covered:get(i)
        local hole = visual:getHole(part)
        if hole and hole > 0 and clothing:getPatchType(part) == nil then
            table.insert(out, part)
        end
    end
    return out
end

Tailor.holedParts = holedParts

--- The fabric to sew this particular hole with.
---
--- Prefers one that closes the hole completely - leather wants leather -
--- and only then falls back to the order the fabric option asks for.
--- Choosing the better patch is not a rebalance: the game offers exactly
--- these fabrics for exactly this part, and tells us which one restores
--- it, through canFullyRestore. This just stops picking the worse one.
function Tailor.findFabricFor(player, clothing, part)
    local inv = player:getInventory()
    local choice = AA.opt("tailorFabric") or 1

    local order = {}
    if choice > 1 then
        order[1] = FABRIC_TYPES[choice - 1]
    else
        for _, fabricType in ipairs(FABRIC_TYPES) do
            table.insert(order, fabricType)
        end
    end

    local first = nil
    for _, fabricType in ipairs(order) do
        local fabric = AA.findItem(player, fabricType)
        if fabric then
            if not first then first = fabric end
            local ok, full = pcall(function()
                return clothing:canFullyRestore(player, part, fabric)
            end)
            if ok and full then return fabric end
        end
    end
    return first
end

--- Everything within reach with at least one open hole. Worn and carried
--- garments come first - they are already in the inventory, so they cost
--- nothing to reach - then whatever is sitting in open containers.
---
--- @param single InventoryItem|nil  one garment only, or nil for all
--- @return table garments, number holes
function Tailor.collectHoled(player, single)
    if single then
        local holes = #holedParts(single)
        if holes == 0 then return {}, 0 end
        return { single }, holes
    end

    local matches = function(item)
        return #holedParts(item) > 0
    end

    local garments, holes = {}, 0
    local inventory = player:getInventory()

    local mine = inventory:getAllEvalRecurse(matches, ArrayList.new())
    if mine then
        for i = 0, mine:size() - 1 do
            local item = mine:get(i)
            table.insert(garments, item)
            holes = holes + #holedParts(item)
        end
    end

    local containers = ISInventoryPaneContextMenu.getContainers(player) or ArrayList.new()
    for i = 0, containers:size() - 1 do
        local container = containers:get(i)
        if container and container ~= inventory then
            local found = container:getAllEvalRecurse(matches, ArrayList.new())
            if found then
                for j = 0, found:size() - 1 do
                    local item = found:get(j)
                    -- getContainers can hand back the same container twice,
                    -- and recursing into a worn bag reaches items already
                    -- counted above.
                    if item:getContainer() ~= inventory then
                        table.insert(garments, item)
                        holes = holes + #holedParts(item)
                    end
                end
            end
        end
    end

    return garments, holes
end

--- Counts the holes still open across a set of garments.
local function remainingHoles(garments)
    local total = 0
    for _, clothing in ipairs(garments) do
        total = total + #holedParts(clothing)
    end
    return total
end

--- Phase one: bring the holed garments in from wherever they are sitting.
local function queueFetching(task)
    local player = task.player
    local inventory = player:getInventory()
    local moved = 0

    for _, clothing in ipairs(task.garments) do
        if clothing:getContainer() ~= inventory then
            -- Remembered before the move, so it can go home afterwards.
            task.cameFrom[clothing] = clothing:getContainer()
            ISInventoryPaneContextMenu.transferIfNeeded(player, clothing)
            moved = moved + 1
        end
    end

    return moved
end

--- Phase two: one stitch per open hole, queued back to back.
---
--- Every action is queued up front rather than one at a time. The vanilla
--- action validates itself when its turn comes, so if the thread runs out
--- half way the rest are simply dropped - which is why the finishing
--- message counts the holes that are actually gone instead of trusting
--- the number queued.
local function queueRepairs(task)
    local player = task.player
    local queued = 0

    local needle = Tailor.findNeedle(player)
    local thread = Tailor.findThread(player)
    if not needle or not thread then return 0 end

    for _, clothing in ipairs(task.garments) do
        if AA.holds(player, clothing) then
            for _, part in ipairs(holedParts(clothing)) do
                local fabric = Tailor.findFabricFor(player, clothing, part)
                if fabric then
                    ISInventoryPaneContextMenu.repairClothing(player, clothing, part, fabric, thread, needle)
                    queued = queued + 1
                end
            end
        end
    end

    return queued
end

--- Sends the mended garments back to the wardrobe they came from.
local function queueReturns(task)
    local player = task.player
    local inventory = player:getInventory()

    for clothing, container in pairs(task.cameFrom) do
        if container and container ~= inventory
                and AA.holds(player, clothing)
                and not player:isEquipped(clothing) then
            ISTimedActionQueue.add(ISInventoryTransferAction:new(player, clothing, inventory, container))
        end
    end
end

local function repairThink(task)
    local player = task.player

    if AA.isQueueBusy(player) then return end

    if task.phase == "fetching" then
        task.phase = "sewing"
        -- Silent in between, like the training loop above and like Auto
        -- Mechanics: an in-progress message breaks the single player fast
        -- forward, which is the whole point of batching the work.
        if queueRepairs(task) == 0 then
            AA.stop(player, getText("UI_AA_repair_nomaterials"), true)
        end
        return
    end

    if task.phase == "sewing" then
        -- Another pass: a garment fetched late, or a hole whose fabric was
        -- not in the inventory the first time round, can still be done now.
        if task.rounds < 20 and remainingHoles(task.garments) > 0 then
            task.rounds = task.rounds + 1
            if queueRepairs(task) > 0 then return end
        end

        task.phase = "returning"
        queueReturns(task)
        return
    end

    local left   = remainingHoles(task.garments)
    local mended = math.max(0, task.holes - left)

    if left > 0 then
        AA.stop(player, getText("UI_AA_repair_partial", mended, left), true)
    else
        AA.stop(player, getText("UI_AA_repair_done", mended), false)
    end
end

function Tailor.startRepair(player, single)
    if not player then return end

    local garments, holes = Tailor.collectHoled(player, single)
    if holes == 0 then
        HaloTextHelper.addBadText(player, getText("UI_AA_repair_noholes"))
        return
    end
    if not Tailor.findNeedle(player) then
        HaloTextHelper.addBadText(player, getText("UI_AA_tailor_noneedle"))
        return
    end
    if not Tailor.findThread(player) then
        HaloTextHelper.addBadText(player, getText("UI_AA_tailor_nothread"))
        return
    end
    if not Tailor.findFabric(player) then
        HaloTextHelper.addBadText(player, getText("UI_AA_tailor_nofabric"))
        return
    end

    local task = {
        kind      = "repair",
        player    = player,
        garments  = garments,
        holes     = holes,
        cameFrom  = {},
        rounds    = 0,
        -- Same stall guard as the other batch jobs: an action that never
        -- ends would otherwise freeze the whole repair in silence.
        stallTimeout = 30000,
        phase     = "fetching",
        think     = repairThink,
        allowMove = true,
        startText = getText("UI_AA_repair_started", holes, #garments),
    }

    AA.startTask(task)

    if queueFetching(task) == 0 then
        task.phase = "sewing"
        if queueRepairs(task) == 0 then
            AA.stop(player, getText("UI_AA_repair_nomaterials"), true)
        end
    end
end

Tailor.onStartRepair = function(player, single)
    Tailor.startRepair(player, single)
end

---------------------------------------------------------------------
-- "Train Tailoring" button on the clothing inspection window
---------------------------------------------------------------------

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT     = FONT_HGT_SMALL + 6
local BUTTON_PAD     = 8

if not AA.tailorUIHooked then
    AA.tailorUIHooked = true

    local original_initialise = ISGarmentUI.initialise
    function ISGarmentUI:initialise()
        original_initialise(self)

        local function makeButton(label, onClick, tag)
            local width = math.max(120, getTextManager():MeasureStringX(UIFont.Small, getText(label)) + 30)
            local button = ISButton:new(0, self.height, width, BUTTON_HGT, getText(label), self, onClick)
            button.internal = tag
            button:initialise()
            button:instantiate()
            button.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
            self:addChild(button)
            return button
        end

        -- This window is where the holes are drawn, so it is the natural
        -- place to offer mending them. Both buttons share one row so the
        -- window grows by the same amount it always did.
        self.aaRepairBtn = makeButton("UI_AA_repair_button", ISGarmentUI.aaOnRepair, "AUTOALL_REPAIR")
        self.aaTrainBtn  = makeButton("UI_AA_tailor_button", ISGarmentUI.aaOnTrain, "AUTOALL_TRAIN")
    end

    function ISGarmentUI:aaOnTrain(button)
        if AA.isRunning(self.chr, "tailoring") then
            AA.stop(self.chr, getText("UI_AA_stopped"), false)
        else
            AA.Tailor.start(self.chr, self.clothing)
        end
    end

    function ISGarmentUI:aaOnRepair(button)
        if AA.isRunning(self.chr, "repair") then
            AA.stop(self.chr, getText("UI_AA_stopped"), false)
        else
            AA.Tailor.startRepair(self.chr, self.clothing)
        end
    end

    local original_render = ISGarmentUI.render
    function ISGarmentUI:render()
        original_render(self)

        local train  = self.aaTrainBtn
        local repair = self.aaRepairBtn
        if not train or not repair then return end

        -- These two are separate automations and switch off separately.
        -- They are buttons on a vanilla window rather than context menu
        -- entries, so they do not go through AA.registerMenu and have to
        -- ask about the switches here.
        local showTrain  = AA.enabled("tailoring")
        local showRepair = AA.enabled("repair")
        train:setVisible(showTrain)
        repair:setVisible(showRepair)

        -- Both off: leave the window exactly as vanilla drew it. Growing it
        -- for a row with nothing in it would be the clutter this is meant
        -- to remove.
        if not showTrain and not showRepair then return end

        -- The vanilla render() recomputes the window height from scratch every
        -- frame, so growing it here stays stable instead of accumulating.
        self:setHeight(self:getHeight() + BUTTON_HGT + BUTTON_PAD)

        local row   = self:getHeight() - BUTTON_HGT - (BUTTON_PAD / 2)
        local total = (showRepair and repair:getWidth() or 0)
                    + (showTrain and train:getWidth() or 0)
                    + ((showRepair and showTrain) and BUTTON_PAD or 0)
        local left  = (self:getWidth() - total) / 2

        if showRepair then
            repair:setX(left)
            repair:setY(row)
            left = left + repair:getWidth() + BUTTON_PAD
        end
        if showTrain then
            train:setX(left)
            train:setY(row)
        end

        local training  = AA.isRunning(self.chr, "tailoring")
        local repairing = AA.isRunning(self.chr, "repair")

        train:setTitle(training and getText("UI_AA_tailor_button_stop") or getText("UI_AA_tailor_button"))
        train:setEnable(AA.Tailor.canTrain(self.chr, self.clothing))

        local holes = #AA.Tailor.holedParts(self.clothing)
        repair:setTitle(repairing and getText("UI_AA_repair_button_stop") or getText("UI_AA_repair_button"))
        repair:setEnable(repairing or holes > 0)

        if training then
            local task = AA.getTask(self.chr)
            local text = getText("UI_AA_tailor_status", task.cycles, task.stitches)
            self:drawText(text, 10, row + (BUTTON_HGT - FONT_HGT_SMALL) / 2,
                    0.6, 1, 0.6, 1, UIFont.Small)
        end
    end
end

---------------------------------------------------------------------
-- context menu
---------------------------------------------------------------------

local function addTailorMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local actual = ISInventoryPane.getActualItems(items)
    local clothing = actual and actual[1]
    if not Tailor.canTrain(player, clothing) then return end

    if AA.isRunning(player, "tailoring") then
        AA.addOption(context, getText("UI_AA_tailor_button_stop"), player, Tailor.onStop)
        return
    end
    if AA.isRunning(player, "repair") then
        AA.addOption(context, getText("UI_AA_repair_stop"), player, Tailor.onStop)
        return
    end

    -- Why the supplies are checked once and reused below: all three
    -- entries need exactly the same needle, thread and fabric, and each
    -- lookup walks the whole inventory.
    local needle = Tailor.findNeedle(player)
    local thread = Tailor.findThread(player)
    local fabric = Tailor.findFabric(player)

    local missing = nil
    if not needle then
        missing = "UI_AA_tailor_noneedle"
    elseif not thread then
        missing = "UI_AA_tailor_nothread"
    elseif not fabric then
        missing = "UI_AA_tailor_nofabric"
    end

    --- One entry, greyed out with the reason rather than hidden, so a
    --- missing needle never reads as a missing feature.
    local function entry(text, onSelect, param, description)
        local option = AA.addOption(context, text, player, onSelect, param)
        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        if missing then
            option.notAvailable = true
            tooltip.description = getText(missing)
        else
            tooltip.description = description
        end
        option.toolTip = tooltip
        return option
    end

    -- Two automations share this file and this menu, and they switch off
    -- separately. The handler is registered under "tailoring", so that one
    -- is already known to be on by the time we get here; repair has to be
    -- asked about on its own. Each carries its own icon for the same
    -- reason - a needle for mending, thread for the training loop.
    local repairOn = AA.enabled("repair")

    local function repairEntry(text, param, description)
        local previous = AA.currentModule
        AA.currentModule = "repair"
        local option = entry(text, Tailor.onStartRepair, param, description)
        AA.currentModule = previous
        return option
    end

    -- Repairing comes first: it is the one with a reason to be used now.
    local thisHoles = #Tailor.holedParts(clothing)
    if repairOn and thisHoles > 0 then
        repairEntry(getText("UI_AA_repair_option", clothing:getDisplayName()),
                    clothing, getText("UI_AA_repair_option_tt", thisHoles))
    end

    if repairOn then
        local _, allHoles = Tailor.collectHoled(player, nil)
        if allHoles > thisHoles then
            repairEntry(getText("UI_AA_repair_option_all"),
                        nil, getText("UI_AA_repair_option_all_tt", allHoles))
        end
    end

    if AA.enabled("tailoring") then
        local previous = AA.currentModule
        AA.currentModule = "tailoring"
        entry(getText("UI_AA_tailor_button"), Tailor.onStart, clothing,
              getText("UI_AA_tailor_button_tt"))
        AA.currentModule = previous
    end
end

-- Both, because either one of them alone is reason enough to build the
-- menu: a player who wants mending but not the training loop still gets
-- the Repair entries.
AA.registerMenu({ "tailoring", "repair" }, Events.OnFillInventoryObjectContextMenu, addTailorMenu)
