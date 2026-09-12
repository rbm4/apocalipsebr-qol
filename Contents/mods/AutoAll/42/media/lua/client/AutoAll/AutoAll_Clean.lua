--[[
    Auto All - Clean (Build 42 / SP + MP)
    ------------------------------------------------------------------
    "Clean Everything" on any water source: sinks, barrels, buckets,
    wells, and natural water like the sea, rivers and lakes.

    One click washes the character, every piece of clothing worn or
    carried, every bloodied weapon and tool, and every dirty bandage or
    rag - instead of picking through a separate menu entry for each one.

    Two variants are offered: with cleaning products (soap, bleach,
    cleaning liquid) which is roughly five times faster, and without.
    When there is no soap within reach the first one stays visible but
    greyed out with the reason, rather than quietly disappearing.

    Bandages and rags are washed anywhere there is water, tainted or not.
    This mod used to hold them back from dirty water; that was a mistake.
    The base game gives the same result either way and infection is not
    affected - tainted water only adds a warning line. Sterilising is the
    part that matters, and that is a separate action.

    Everything is queued as the vanilla ISWashYourself and ISWashClothing
    actions, in one batch, so the whole job runs without gaps and single
    player can fast forward straight through it.

    Note for anyone reading the vanilla source: the wash menu in
    ISWorldObjectContextMenu.lua is dead code in B42.20, but the feature
    is not gone - it moved to Java, in ISWorldObjectContextMenuLogic
    (doWashClothingOrYourselfMenu). Both timed actions are still live and
    this module queues them rather than reimplementing any washing.
]]

require "AutoAll/AutoAll_Core"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.cleanLoaded then return end
AA.cleanLoaded = true

AA.Clean = AA.Clean or {}
local Clean = AA.Clean

-- Dirty medical cloth. These are the types ISWashClothing converts back
-- into their clean counterpart via getItemAfterCleaning().
local DIRTY_CLOTH = {
    ["Base.BandageDirty"]       = true,
    ["Base.RippedSheetsDirty"]  = true,
    ["Base.DenimStripsDirty"]   = true,
    ["Base.LeatherStripsDirty"] = true,
}

---------------------------------------------------------------------
-- water sources
---------------------------------------------------------------------

--- How much water an object can actually give us.
---
--- This is deliberately the same number ISWashClothing:isValid() tests
--- against, so anything reported as zero here genuinely cannot wash - no
--- point offering it. IsoObject.getFluidAmount() already resolves every
--- shape a water source comes in:
---   piped fixture, mains still on   -> 10000 (via isWaterInfinite)
---   fixture fed by another object   -> that source's own amount
---   tubs, barrels, wells, kettles   -> its FluidContainer amount
---   toilet cisterns                 -> getReserveWaterAmount()
---   rain puddles on a solid floor   -> puddle depth * 10
--- Rivers, lakes and the sea deliberately report 0 - the vanilla wash
--- actions refuse them, so we must not pretend otherwise.
local function fluidAmountOf(object)
    if not object or not instanceof(object, "IsoObject") then return 0 end
    local ok, amount = pcall(function() return object:getFluidAmount() end)
    if ok and type(amount) == "number" then return amount end
    return 0
end

--- True for anything that is plumbing at all - sink, toilet, bath, rain
--- collector, well - whether or not it currently holds a drop.
---
--- A dry fixture still gets a menu entry, greyed out with the reason.
--- Sinks run dry the moment the water is shut off, and an option that
--- silently disappears reads as a broken mod rather than an empty sink.
function Clean.isWaterFixture(object)
    if not object or not instanceof(object, "IsoObject") then return false end

    local ok, found = pcall(function()
        if object:hasComponent(ComponentType.FluidContainer) then return true end
        if object:getFluidContainer() ~= nil then return true end

        -- Piped fixtures advertise themselves through the sprite even when
        -- the mains are off and they hold nothing at all.
        local sprite = object:getSprite()
        local props = sprite and sprite:getProperties()
        if props and (props:has(IsoFlagType.waterPiped)
                or props:has(IsoPropertyType.WATER_AMOUNT)) then
            return true
        end
        return false
    end)

    return ok and found == true
end

--- Every object on a square and the ring of squares around it.
local function objectsNear(square, out)
    if not square then return out end
    local cell = getCell()
    if not cell then return out end

    local z = square:getZ()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(square:getX() + dx, square:getY() + dy, z)
            if sq then
                local objects = sq:getObjects()
                for i = 0, objects:size() - 1 do
                    table.insert(out, objects:get(i))
                end
            end
        end
    end
    return out
end

--- The best water source among the objects the player right clicked.
--- Returns the source and its water, plus any dry fixture found instead,
--- so the caller can explain itself rather than showing nothing.
function Clean.findWaterSource(worldobjects)
    local best, bestAmount, dry = nil, 0, nil

    local function consider(object)
        local amount = fluidAmountOf(object)
        if amount > bestAmount then
            best, bestAmount = object, amount
        elseif not dry and amount <= 0 and Clean.isWaterFixture(object) then
            dry = object
        end
    end

    for _, object in ipairs(worldobjects) do
        consider(object)
    end

    -- Nothing on the exact tile that was clicked: look one square out, so
    -- right clicking the floor in front of a sink still finds the sink.
    if not best and not dry then
        local first = worldobjects[1]
        local square = first and first:getSquare()
        for _, object in ipairs(objectsNear(square, {})) do
            consider(object)
        end
    end

    return best, bestAmount, dry
end

--- True for the sea, rivers and lakes, and for any water the game itself
--- calls tainted. Those are the sources that must not touch bandages.
function Clean.isNaturalWater(source)
    if not source then return false end
    local square = source:getSquare()
    if not square then return false end
    local floor = square:getFloor()
    if floor and floor:hasProperty(IsoFlagType.water) then return true end
    local ok, tainted = pcall(function() return source:isTaintedWater() end)
    return ok and tainted == true
end

-- There was a Clean.isInfinite() here, calling source:isWaterInfinite().
-- That method is PRIVATE on IsoObject, so Kahlua cannot reach it: every
-- call failed, and although the pcall swallowed the result the engine
-- still dumped a full Lua stack trace into console.txt each time.
--
-- It was redundant anyway. getFluidAmount() already returns 10000 for a
-- source it considers infinite, so the budget below simply starts from
-- that and counts down - no separate flag needed.
--
-- Lesson: a name showing up in a .class string dump proves neither that
-- the class declares it nor that it is public. Check the access flags.

---------------------------------------------------------------------
-- cleaning products
---------------------------------------------------------------------

--- Soap bars, bleach and cleaning liquid. Mirrors what the vanilla
--- getSoapList() accepts, but usable on containers around the player too.
function Clean.isCleaningProduct(item)
    if not item then return false end
    if item:getFullType() == "Base.Soap2" then return true end

    local container = item:getFluidContainer()
    if container and container:getAmount() > 0 then
        local ok, isCleaner = pcall(function()
            return container:contains(Fluid.CleaningLiquid) or container:contains(Fluid.Bleach)
        end)
        if ok and isCleaner then return true end
    end
    return false
end

--- Soap the character is already carrying, in vanilla's own terms.
local function soapRemaining(player)
    local soaps = player:getInventory():getSoapList(nil, true)
    return ISWashClothing.GetSoapRemaining(soaps)
end

--- Finds soap in the containers in reach so the player does not have to
--- fish it out of the cupboard by hand first.
function Clean.gatherSoap(player)
    local found = {}
    local containers = ISInventoryPaneContextMenu.getContainers(player)
    if not containers then return found end

    for i = 0, containers:size() - 1 do
        local container = containers:get(i)
        if container ~= player:getInventory() then
            local items = container:getAllEvalRecurse(Clean.isCleaningProduct, ArrayList.new())
            if items then
                for j = 0, items:size() - 1 do
                    table.insert(found, items:get(j))
                end
            end
        end
    end
    return found
end

function Clean.hasSoapInReach(player)
    if soapRemaining(player) > 0 then return true end
    return #Clean.gatherSoap(player) > 0
end

---------------------------------------------------------------------
-- what needs washing
---------------------------------------------------------------------

local function needsWashing(item)
    if not item then return false end

    if DIRTY_CLOTH[item:getFullType()] then return true end
    if item:getItemAfterCleaning() then return true end

    if instanceof(item, "Clothing") or instanceof(item, "InventoryContainer") then
        if item:getDirtiness() and item:getDirtiness() > 0 then return true end
        local parts = BloodClothingType.getCoveredParts(item:getBloodClothingType())
        if parts then
            for i = 0, parts:size() - 1 do
                if item:getBlood(parts:get(i)) > 0 then return true end
            end
        end
        return false
    end

    local ok, blood = pcall(function() return item:getBloodLevel() end)
    return ok and type(blood) == "number" and blood > 0
end

--- Kept only so an older call site cannot break; nothing gates on it any
--- more. This mod used to refuse to wash bandages and rags in tainted or
--- natural water, on the theory that rinsing a dressing in a river gets
--- you infected. That was wrong: the base game does not work that way.
--- Washing in tainted water gives the same result as washing in clean
--- water, and infection is unaffected either way - all the tainted water
--- does is trigger a warning line, if the EnableTaintedWaterText sandbox
--- option is on. Sterilising is the part that actually matters, and it is
--- a separate action. So the restriction only blocked something the base
--- game allows, and it is gone.
local function isMedicalCloth(item)
    return DIRTY_CLOTH[item:getFullType()] == true
end

--- Everything on the character worth washing, worn items included.
function Clean.collect(player, allowMedical)
    local found = {}
    local items = player:getInventory():getAllEvalRecurse(needsWashing, ArrayList.new())
    if not items then return found end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if allowMedical or not isMedicalCloth(item) then
            table.insert(found, item)
        end
    end
    return found
end

function Clean.selfNeedsWashing(player)
    local ok, water = pcall(function() return ISWashYourself.GetRequiredWater(player) end)
    return ok and type(water) == "number" and water > 0
end

---------------------------------------------------------------------
-- wringing
--
-- This used to be part of the wash: every garment's unequip, wring and
-- re-wear was queued in the same tick as the washing, before any of it
-- had run. Two things were wrong with that, and together they are the
-- "it only wrings the first piece" report.
--
--   * ISWringClothing:new() ends with
--         o.maxTime = o:getDuration()
--     and getDuration() is math.ceil(item:getWetness() * 5). The wetness
--     is read at construction. A dirty but dry shirt is at 0 when the
--     batch is built - ISWashClothing:complete() is what sets it to 100 -
--     so the action was built with a duration of zero.
--   * ISWringClothing:isValid() is `self.item:getWetness() > 10`, and it
--     never re-resolves the item by id the way ISReloadWeaponAction and
--     ISWearClothing do. On a server the instance queued up front is
--     replaced as transfers settle, and the stale one answers 0.
--
-- Both disappear if the action is simply built at the moment it is
-- needed. So wringing is now its own job, one garment at a time, driven
-- from think() - and because it is its own job it can also be started on
-- its own, without washing anything first.
---------------------------------------------------------------------

-- What ISWringClothing:isValid() wants to see. Below this the game
-- considers the garment dry and refuses the action.
local WET_ENOUGH = 10

-- ...but that is not where wringing actually leaves a garment, and the
-- difference is half of a real report.
--
-- > *TrickterTravvy:* "My character will take them off one by one, wring
-- > some of them, stop and say that the wringing is done. It never puts
-- > any of the items back on and half of them stay wet."
--
-- ISWringClothing:complete() is:
--
--     if self.item:getBodyLocation() == "Shoes" then
--         self.item:setWetness(math.min(self.item:getWetness(), 60))
--     else
--         self.item:setWetness(math.min(self.item:getWetness(), 10))
--     end
--
-- Boots come out of a wring at SIXTY, not ten. So a pair of soaked boots
-- was wrung correctly, still read as "wet" against a threshold of ten,
-- never counted as done, and was offered again by the menu for the rest
-- of the session. That is the "half of them stay wet".
--
-- Worse, a shoe already sitting at 60 still passes isValid() - which only
-- asks for more than 10 - so the action runs, changes nothing, and the
-- job cannot tell the difference between that and a failure.
local SHOE_FLOOR = 60

--- The wetness the game will actually leave this garment at.
local function wringFloor(item)
    local ok, location = pcall(function() return item:getBodyLocation() end)
    if ok and location == "Shoes" then return SHOE_FLOOR end
    return WET_ENOUGH
end

--- Wet enough that a wring would actually change something.
local function stillWet(item)
    return item:getWetness() > wringFloor(item)
end

local function isWorn(player, item)
    local worn = player:getWornItems()
    return worn ~= nil and worn:contains(item) == true
end

--- Every piece of clothing on the character wet enough to be worth
--- wringing, worn ones included.
function Clean.collectWet(player)
    local found = {}
    if not player then return found end

    local wet = player:getInventory():getAllEvalRecurse(function(item)
        return instanceof(item, "Clothing") and stillWet(item)
    end, ArrayList.new())
    if not wet then return found end

    for i = 0, wet:size() - 1 do
        table.insert(found, wet:get(i))
    end
    return found
end

--- Queues the one garment this round is about to deal with.
---
--- The item is looked up again by id rather than kept from the start of
--- the job, for the reason in the header above: on a server the instance
--- is not the same object a few actions later.
-- Attempts at putting one garment back on before the job gives up on it
-- and moves along. Two, because a wear that failed twice in a row is not
-- going to work on the third.
local MAX_WEAR_TRIES = 2

local function itemOf(task, id)
    if not id then return nil end
    return task.player:getInventory():getItemById(id)
end

--- Queues the one garment this round is about to deal with.
---
--- The item is looked up again by id rather than kept from the start of
--- the job, for the reason in the header above: on a server the instance
--- is not the same object a few actions later. getItemById does recurse
--- into worn bags (verified in the bytecode), so a wet shirt in a
--- backpack is still found.
---
--- The re-wear is deliberately NOT queued here. It used to be, in the
--- same tick as the unequip and the wring, and that is the other half of
--- TrickterTravvy's report: three actions queued up front, only the
--- outcome of the first two ever checked, and nothing anywhere noticing
--- that the character was left standing in its underwear. Putting the
--- clothes back on is now its own phase with its own verification, the
--- same rule the rest of this mod already follows - ask the game whether
--- the work landed, never assume the queue draining means it did.
local function queueOneWring(task)
    local player = task.player
    local id     = task.ids[task.index]
    if not id then return false end

    local item = itemOf(task, id)
    if not item or not instanceof(item, "Clothing") then return false end
    if not stillWet(item) then return false end

    if isWorn(player, item) then
        -- Remembered for the whole job, so the final sweep can put back
        -- anything an individual round failed to.
        task.wornIds[id] = true
        ISTimedActionQueue.add(ISUnequipAction:new(player, item, 50))
    end
    ISTimedActionQueue.add(ISWringClothing:new(player, item))

    task.current = id
    task.phase   = "wringing"
    return true
end

--- Puts one garment back on. Returns false when it cannot be found.
local function queueWear(task, id)
    local item = itemOf(task, id)
    if not item or not instanceof(item, "Clothing") then return false end
    if isWorn(task.player, item) then return true end
    if item:isBroken() then return false end

    ISTimedActionQueue.add(ISWearClothing:new(task.player, item))
    return true
end

--- Anything that was taken off and is still off, at the end of the job.
--- One last pass, because a garment left on the floor of the inventory
--- is the single most annoying way for this job to fail.
local function queueRedress(task)
    local queued = 0
    for id in pairs(task.wornIds) do
        local item = itemOf(task, id)
        if item and not isWorn(task.player, item) and not item:isBroken() then
            ISTimedActionQueue.add(ISWearClothing:new(task.player, item))
            queued = queued + 1
        end
    end
    return queued
end

local function advance(task)
    task.current   = nil
    task.wearTries = 0
    task.index     = task.index + 1

    while task.ids[task.index] do
        if queueOneWring(task) then
            AA.reason(task, getText("UI_AA_wring_working", task.wrung, #task.ids))
            return true
        end
        task.index = task.index + 1
    end
    return false
end

local function wringThink(task)
    local player = task.player

    if AA.isQueueBusy(player) then return end

    -- Waiting on a garment to go back on.
    if task.phase == "wearing" then
        local item = itemOf(task, task.current)
        if item and isWorn(player, item) then
            if not advance(task) then task.phase = "redressing" end
            if task.phase ~= "redressing" then return end
        elseif task.wearTries < MAX_WEAR_TRIES and queueWear(task, task.current) then
            task.wearTries = task.wearTries + 1
            return
        else
            print("[AutoAll] wring: could not put " .. tostring(task.current)
                    .. " back on after " .. tostring(task.wearTries) .. " tries")
            if not advance(task) then task.phase = "redressing" end
            if task.phase ~= "redressing" then return end
        end
    end

    -- A garment has just been wrung.
    if task.phase == "wringing" then
        -- Scored by asking the game, not by the queue draining: an action
        -- that was refused drains exactly the same way.
        local item = itemOf(task, task.current)
        if not item or not stillWet(item) then
            task.wrung = task.wrung + 1
        end

        -- Put it back on before moving to the next one, and check that it
        -- actually went on.
        if task.wornIds[task.current] and item and not isWorn(player, item) then
            if queueWear(task, task.current) then
                task.phase     = "wearing"
                task.wearTries = 1
                return
            end
        end

        if not advance(task) then task.phase = "redressing" end
        if task.phase ~= "redressing" then return end
    end

    -- Nothing left to wring. One last sweep for anything still off, then
    -- stop - and in that order, because AA.stop clears the action queue,
    -- so queueing the wear and stopping in the same tick would throw the
    -- wear away.
    if task.phase == "redressing" then
        task.phase = "done"
        if queueRedress(task) > 0 then return end
    end

    AA.stop(player, getText("UI_AA_wring_done", task.wrung), false)
end

function Clean.startWring(player)
    if not player then return end

    local wet = Clean.collectWet(player)
    if #wet == 0 then
        HaloTextHelper.addBadText(player, getText("UI_AA_wring_nothing"))
        return
    end

    -- Ids, not items, for the same multiplayer reason as above.
    local ids = {}
    for _, item in ipairs(wet) do
        table.insert(ids, item:getID())
    end

    local task = {
        kind      = "wring",
        player    = player,
        ids       = ids,
        index     = 0,
        wrung     = 0,
        current   = nil,
        phase     = "wringing",
        -- Every garment this job took off, for the final re-dress sweep.
        wornIds   = {},
        wearTries = 0,
        think     = wringThink,
        -- A wring is seconds long (getDuration is wetness * 5), so an
        -- action still at the head of the queue after twenty is not
        -- working. Opt-in, and the job only gets two recoveries.
        stallTimeout = 20000,
        maxStalls    = 2,
        startText = getText("UI_AA_wring_started", #ids),
    }

    AA.startTask(task)
end

Clean.onWring = function(player)
    Clean.startWring(player)
end

Clean.onStopWring = function(player)
    AA.stop(player, getText("UI_AA_stopped"), false)
end

---------------------------------------------------------------------
-- the job
---------------------------------------------------------------------

local function completedWashCount(task)
    local completed = 0
    if task.washSelf and not Clean.selfNeedsWashing(task.player) then
        completed = completed + 1
    end
    for _, item in ipairs(task.washTargets) do
        if not item:getContainer() or not needsWashing(item) then
            completed = completed + 1
        end
    end
    return completed
end

--- Queues the whole wash in one go, stopping when the water runs out.
local function queueEverything(task)
    local player  = task.player
    local source  = task.source
    local useSoap = task.useSoap

    -- An "infinite" source simply reports 10000, so this counts down from
    -- whatever the game says is there and needs no special case.
    local budget = fluidAmountOf(source)

    if useSoap then
        for _, soap in ipairs(Clean.gatherSoap(player)) do
            ISInventoryPaneContextMenu.transferIfNeeded(player, soap)
        end
    end

    if AA.opt("cleanSelf") and Clean.selfNeedsWashing(player) then
        ISTimedActionQueue.add(ISWashYourself:new(player, source))
        budget = budget - ISWashYourself.GetRequiredWater(player)
    end

    local soapLeft = useSoap and soapRemaining(player) or 0

    for _, item in ipairs(task.items) do
        local water = ISWashClothing.GetRequiredWater(item)
        if budget < water then
            task.ranDry = true
            break
        end
        budget = budget - water

        -- Same handwave the vanilla menu uses: the last use of a bar is
        -- allowed to finish an item off.
        local noSoap = true
        if soapLeft > 0 then
            noSoap = false
            soapLeft = soapLeft - math.min(soapLeft, ISWashClothing.GetRequiredSoap(item))
        end

        ISInventoryPaneContextMenu.transferIfNeeded(player, item)

        local blood, dirt = 0, 0
        if instanceof(item, "Clothing") or instanceof(item, "InventoryContainer") then
            local parts = BloodClothingType.getCoveredParts(item:getBloodClothingType())
            if parts then
                for i = 0, parts:size() - 1 do
                    blood = blood + item:getBlood(parts:get(i))
                end
            end
            if item:getDirtiness() then dirt = item:getDirtiness() end
        else
            local ok, level = pcall(function() return item:getBloodLevel() end)
            if ok and type(level) == "number" then blood = level end
        end

        ISTimedActionQueue.add(ISWashClothing:new(player, source, item, blood, dirt, noSoap))
        table.insert(task.washTargets, item)
    end
end

local function think(task)
    local player = task.player

    if AA.isQueueBusy(player) then return end

    -- A formal stop removes the task before this callback can run again.
    -- Only an active, still-registered task may recover a silently reset queue.
    if not task.active or AA.tasks[task.playerNum] ~= task then return end

    task.washed = completedWashCount(task)

    if task.ranDry then
        AA.stop(player, getText("UI_AA_clean_dry", task.washed), false)
    else
        AA.stop(player, getText("UI_AA_clean_done", task.washed), false)
    end

    -- Handed over rather than queued alongside the wash: the wringing job
    -- builds one action at a time against the wetness the garment actually
    -- has, which is the whole point of it being a separate job. Off by
    -- default now - the standalone entry is the way to ask for it.
    if AA.opt("cleanWring") and #Clean.collectWet(player) > 0 then
        Clean.startWring(player)
    end
end

function Clean.start(player, source, useSoap)
    if not player or not source then return end

    -- walkAdjObject queues a path action. Replace the previous automation
    -- first, otherwise AA.startTask would clear this new task's own walk.
    if AA.isRunning(player) then
        AA.stop(player, getText("UI_AA_stop_replaced"), false)
    end

    if not luautils.walkAdjObject(player, source, true, true) then
        HaloTextHelper.addBadText(player, getText("UI_AA_clean_unreachable"))
        return
    end

    local items = Clean.collect(player, true)
    local washSelf = AA.opt("cleanSelf") and Clean.selfNeedsWashing(player)

    if #items == 0 and not washSelf then
        HaloTextHelper.addBadText(player, getText("UI_AA_clean_nothing"))
        return
    end

    local task = {
        kind      = "clean",
        player    = player,
        source    = source,
        useSoap   = useSoap,
        items     = items,
        washSelf  = washSelf,
        washTargets = {},
        washed    = 0,
        ranDry    = false,
        think     = think,
        allowMove = true,   -- the character walks to the sink on its own
        startText = getText("UI_AA_clean_started", #items + (washSelf and 1 or 0)),
    }

    AA.startTask(task)
    queueEverything(task)
end

Clean.onStart = function(player, source, useSoap)
    Clean.start(player, source, useSoap)
end

Clean.onStop = function(player)
    AA.stop(player, getText("UI_AA_stopped"), false)
end

---------------------------------------------------------------------
-- context menu
---------------------------------------------------------------------

--- The standalone "wring everything out" entry.
---
--- Shared by the water source menu and the inventory menu, so the two
--- cannot drift apart. `addToolTip` differs between the two menus, hence
--- the argument.
function Clean.addWringOption(context, player, addToolTip)
    local wet = Clean.collectWet(player)
    if #wet == 0 then return end

    local option = AA.addOption(context, getText("UI_AA_wring_option"), player, Clean.onWring)
    local tooltip = addToolTip()
    tooltip.description = getText("UI_AA_wring_option_tt", #wet)
    option.toolTip = tooltip
    return option
end

local function addWringInventoryMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local actual = ISInventoryPane.getActualItems(items)
    local item = actual and actual[1]
    if not item or not instanceof(item, "Clothing") then return end

    if AA.isRunning(player, "wring") then
        AA.addOption(context, getText("UI_AA_wring_stop"), player, Clean.onStopWring)
        return
    end
    if AA.isRunning(player) then return end

    -- Only offered off something that is itself wet, so a right click on a
    -- dry shirt does not grow an entry about a different garment.
    if item:getWetness() <= WET_ENOUGH then return end

    Clean.addWringOption(context, player, ISInventoryPaneContextMenu.addToolTip)
end

AA.registerMenu("clean", Events.OnFillInventoryObjectContextMenu, addWringInventoryMenu)

local function addCleanMenu(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local source, amount, dry = Clean.findWaterSource(worldobjects)
    if not source and not dry then return end

    if AA.isRunning(player, "clean") then
        AA.addOption(context, getText("UI_AA_clean_stop"), player, Clean.onStop)
        return
    end
    if AA.isRunning(player, "wring") then
        AA.addOption(context, getText("UI_AA_wring_stop"), player, Clean.onStopWring)
        return
    end

    -- Wringing needs no water, but this is where a soaked character is
    -- standing, so the entry belongs here too.
    Clean.addWringOption(context, player, ISWorldObjectContextMenu.addToolTip)

    -- Plumbing with nothing in it, most often a sink after the water has
    -- been shut off. Say so instead of vanishing from the menu.
    if not source or amount <= 0 then
        local empty = AA.addOption(context, getText("UI_AA_clean_option"))
        empty.notAvailable = true
        local emptyTip = ISWorldObjectContextMenu.addToolTip()
        emptyTip.description = getText("UI_AA_clean_no_water")
        empty.toolTip = emptyTip
        return
    end

    local items = Clean.collect(player, true)
    local washSelf = Clean.selfNeedsWashing(player)
    local total = #items + (washSelf and 1 or 0)

    local option = AA.addOption(context, getText("UI_AA_clean_option"))

    -- Nothing to wash. Say so and stop here: the submenu is deliberately
    -- not created, because attaching an empty one to a disabled option
    -- leaves the menu with a submenu that has no entries to draw.
    if total == 0 then
        option.notAvailable = true
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = getText("UI_AA_clean_nothing")
        option.toolTip = tooltip
        return
    end

    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)

    -- With cleaning products: kept visible and greyed out when there is
    -- none around, so it is obvious the option exists and what it wants.
    local withSoap = subMenu:addOption(getText("UI_AA_clean_with_soap"), player, Clean.onStart, source, true)
    local soapTip = ISWorldObjectContextMenu.addToolTip()
    if Clean.hasSoapInReach(player) then
        soapTip.description = getText("UI_AA_clean_with_soap_tt", total)
    else
        withSoap.notAvailable = true
        soapTip.description = getText("UI_AA_clean_no_soap")
    end
    withSoap.toolTip = soapTip

    local withoutSoap = subMenu:addOption(getText("UI_AA_clean_without_soap"), player, Clean.onStart, source, false)
    local plainTip = ISWorldObjectContextMenu.addToolTip()
    plainTip.description = getText("UI_AA_clean_without_soap_tt", total)
    withoutSoap.toolTip = plainTip

    -- Tainted water is still worth mentioning, but only as a note now:
    -- the base game washes exactly the same either way, so nothing is
    -- held back from it.
    if Clean.isNaturalWater(source) then
        local note = ISWorldObjectContextMenu.addToolTip()
        note.description = soapTip.description .. " <LINE> <RGB:1,0.6,0.6> " .. getText("UI_AA_clean_natural_note")
        withSoap.toolTip = note
        local note2 = ISWorldObjectContextMenu.addToolTip()
        note2.description = plainTip.description .. " <LINE> <RGB:1,0.6,0.6> " .. getText("UI_AA_clean_natural_note")
        withoutSoap.toolTip = note2
    end
end

AA.registerMenu("clean", Events.OnFillWorldObjectContextMenu, addCleanMenu)
