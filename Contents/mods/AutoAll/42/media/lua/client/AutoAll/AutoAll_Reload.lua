--[[
    Auto All - Reload (Build 42 / SP + MP)
    ------------------------------------------------------------------
    "Train Reload" on any magazine, on firearms that hold loose rounds
    (shotguns, revolvers, bolt actions), and on magazine fed guns, where
    the training runs on the magazine the gun feeds from.

    The character fills the magazine, empties it again and starts over.
    Vanilla awards Reloading XP on every single round pushed in, so the
    loop is simply the normal reload action repeated - no XP is granted
    by this mod.

    Load and unload actions are queued in batches rather than one at a
    time. Waiting a tick to confirm each action before queueing the next
    left a gap between every reload, which made the training crawl and
    stopped the game from being fast forwarded. With a full queue the
    actions chain straight into each other and single player can run the
    clock forward freely.
]]

require "AutoAll/AutoAll_Core"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.reloadLoaded then return end
AA.reloadLoaded = true

AA.Reload = AA.Reload or {}
local Reload = AA.Reload

local BATCH_PAIRS  = 40     -- load+unload pairs queued at a time
local REFILL_AT    = 16     -- queue more once fewer actions than this are left
local STALL_MS     = 15000  -- no progress for this long means something is wrong
-- No round has moved in or out for this long. Generous on purpose: on a
-- multiplayer client the count is updated by the server and arrives late
-- (ISLoadBulletsInMagazine's animEvent guards the removal with
-- `if not isClient()`), and a slow reloader still moves one a second.
local AMMO_STALL_MS = 12000

-- The queue can also hold an equip or a transfer we asked for, so progress is
-- measured by counting our own actions rather than the whole queue.
local OUR_ACTIONS = {
    ISLoadBulletsInMagazine     = true,
    ISUnloadBulletsFromMagazine = true,
    ISReloadWeaponAction        = true,
    ISUnloadBulletsFromFirearm  = true,
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

---------------------------------------------------------------------
-- what can be trained
---------------------------------------------------------------------

local function ammoKeyOf(item)
    local ammoType = item:getAmmoType()
    if not ammoType then return nil end
    return ammoType:getItemKey()
end

--- A magazine: anything that holds rounds and is not the gun itself.
--- Same test the vanilla context menu uses (tests.magazine).
function Reload.isMagazine(item)
    if not item or not instanceof(item, "InventoryItem") then return false end
    if instanceof(item, "HandWeapon") then return false end
    return item:getMaxAmmo() > 0 and ammoKeyOf(item) ~= nil
end

--- A firearm loaded round by round: revolvers, shotguns, bolt actions.
function Reload.isLooseRoundFirearm(item)
    if not item or not instanceof(item, "HandWeapon") then return false end
    local magazineType = item:getMagazineType()
    if magazineType and magazineType ~= "" then return false end
    return item:getMaxAmmo() > 0 and ammoKeyOf(item) ~= nil
end

--- A magazine fed firearm. The rounds go into the magazine, so that is what
--- gets trained - either the one already in the gun or the best spare.
function Reload.isMagazineFedFirearm(item)
    if not item or not instanceof(item, "HandWeapon") then return false end
    local magazineType = item:getMagazineType()
    return magazineType ~= nil and magazineType ~= ""
end

--- The item the loop will actually load and unload.
function Reload.resolveTarget(player, item)
    if Reload.isMagazine(item) or Reload.isLooseRoundFirearm(item) then
        return item
    end
    if Reload.isMagazineFedFirearm(item) then
        return item:getBestMagazine(player)
    end
    return nil
end

--- The gun has a magazine in it and there is no spare to train on.
---
--- This is the "the entry is only available when the magazine is already
--- partly loaded" report. HandWeapon.getBestMagazine is, in full:
---
---     if (StringUtils.isNullOrEmpty(getMagazineType())) return null;
---     return character.getInventory()
---            .getBestTypeRecurse(getMagazineType(), magazineComparator);
---
--- (read off the bytecode of zombie.inventory.types.HandWeapon). It looks
--- in the *inventory*. The magazine seated in the gun is not in the
--- inventory, so a gun carrying its only magazine answers nil, and the
--- entry greyed itself out over a perfectly trainable weapon.
---
--- Vanilla hits the same wall and deals with it the same way:
--- ISReloadWeaponAction.BeginAutomaticReload tests isContainsClip() and
--- queues ISEjectMagazine before asking again. So does this.
function Reload.needsEject(player, item)
    if not Reload.isMagazineFedFirearm(item) then return false end
    if item:getBestMagazine(player) ~= nil then return false end

    local ok, contains = pcall(function() return item:isContainsClip() end)
    return ok and contains == true
end

function Reload.canTrain(item)
    return Reload.isMagazine(item)
        or Reload.isLooseRoundFirearm(item)
        or Reload.isMagazineFedFirearm(item)
end

local function ammoInInventory(player, item)
    local key = ammoKeyOf(item)
    if not key then return 0 end
    return player:getInventory():getItemCountRecurse(key)
end

---------------------------------------------------------------------
-- the loop
---------------------------------------------------------------------

--- Re-reads the item being trained straight out of the inventory.
---
--- This is what multiplayer needs. ISReloadWeaponAction:isValid() does
---
---     if isClient() then
---         self.gun = self.character:getInventory():getItemById(self.gun:getID())
---     end
---     return self.character:getPrimaryHandItem() == self.gun
---
--- so on a server every queued action re-resolves the gun by id and then
--- compares it against what is in the hand. Item instances get replaced
--- as transactions settle, so a whole batch queued up front is holding a
--- stale object by the time it runs: the comparison fails, the action is
--- dropped, and the player sees "the reload did not go through" with
--- nothing obviously wrong. Looking the item up again by id each time is
--- exactly what the engine itself does.
local function currentItem(task)
    local player = task.player
    local item   = task.item
    if not item then return nil end

    local ok, fresh = pcall(function()
        return player:getInventory():getItemById(item:getID())
    end)
    if ok and fresh then
        task.item = fresh
        return fresh
    end
    return item
end

--- Queues another run of load/unload pairs.
local function queueBatch(task)
    local player = task.player
    local item   = currentItem(task)
    if not item then return false end

    -- Single player can safely have a long batch queued in one go, which
    -- is what lets the clock be fast forwarded through a whole session.
    -- On a server the batch has to be short, because each action holds the
    -- item instance it was built with - see currentItem above.
    --
    -- Seated in a vehicle counts as "cannot batch" for now. Both reload
    -- actions run on `maxTime = -1` and finish only when an animation
    -- event fires (ISLoadBulletsInMagazine waits for 'InsertBullet' and
    -- 'loadFinished'); nothing here can prove those events behave the same
    -- from a car seat, and a whole batch queued against that assumption is
    -- what a player reported ripping through in seconds with nothing
    -- loaded. One pair at a time, each verified before the next, gives the
    -- same result either way - only slower. Vanilla itself supports
    -- reloading while seated (a driver reloads at 0.8 speed,
    -- ISReloadWeaponAction.setReloadSpeed), so this deliberately does not
    -- refuse the job, it only stops trusting a batch.
    local seated   = player:getVehicle() ~= nil
    local pairsLeft = (isClient() or seated) and 1 or BATCH_PAIRS
    local maxCycles = AA.opt("reloadMaxCycles") or 0
    if maxCycles > 0 then
        pairsLeft = math.min(pairsLeft, maxCycles - task.cyclesQueued)
    end
    if pairsLeft <= 0 then return false end

    for _ = 1, pairsLeft do
        if task.isMagazine then
            ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(player, item, task.roundsPerCycle))
            ISTimedActionQueue.add(ISUnloadBulletsFromMagazine:new(player, item))
        else
            ISTimedActionQueue.add(ISReloadWeaponAction:new(player, item))
            ISTimedActionQueue.add(ISUnloadBulletsFromFirearm:new(player, item))
        end
    end

    task.cyclesQueued = task.cyclesQueued + pairsLeft
    task.queued       = task.queued + pairsLeft * 2
    return true
end

-- How many think ticks the magazine gets to appear in the inventory after
-- the gun has been told to eject it.
local EJECT_ATTEMPTS = 8

-- How many think ticks the fetching gets to land before the job gives up
-- and says there is no ammunition. Eight quarter-second ticks is two
-- seconds, which is far longer than a transfer needs even on a busy
-- server, and short enough that a genuinely empty inventory is reported
-- quickly rather than sat on.
local PREPARE_ATTEMPTS = 8

---------------------------------------------------------------------
-- Modern Firearms System (Workshop 3633421539)
--
-- Reported by Firestorm: "Auto Reload stops mid-way within the first
-- reload cycle." Two things about that mod matter here.
--
-- It replaces ISReloadWeaponAction.ReloadBestMagazine and
-- .BeginAutomaticReload, but this module never calls either of those - it
-- queues ISLoadBulletsInMagazine and ISUnloadBulletsFromMagazine directly,
-- the way the vanilla context menu does - so those overrides do not
-- collide with anything here.
--
-- What does matter is where it keeps ammunition. An "AmmoBag" holds rounds
-- as a COUNT IN MOD DATA, not as items in a container, so
-- transferBullets finds nothing, the inventory does not contain the ammo
-- type, and ISLoadBulletsInMagazine:start() stops itself on its own
-- containsWithModule check. Its own reload handles this by calling
-- AmmoBagFunction.ItemOut, which instantiates the rounds into the
-- inventory - and that is exactly what is done here, through its own
-- function, taking the same number of rounds it would take. Nothing about
-- what a round costs changes; the mod is only being asked for the ammo the
-- same way its own menu asks.
--
-- Guarded on the global existing, so this is inert without the mod.
local function drawFromAmmoBag(player, key, wanted)
    if not key or not AmmoBagFunction then return 0 end
    if type(AmmoBagFunction.GetLoadType) ~= "function"
            or type(AmmoBagFunction.ItemOut) ~= "function"
            or type(AmmoBagFunction.GetNum) ~= "function" then
        return 0
    end

    local moved = 0
    local ok = pcall(function()
        local items = player:getInventory():getItems()
        for i = 0, items:size() - 1 do
            local candidate = items:get(i)
            if candidate and candidate:getType() == "AmmoBag"
                    and AmmoBagFunction.GetLoadType(candidate) == key then
                local available = AmmoBagFunction.GetNum(candidate) or 0
                local take = math.min(available, wanted)
                if take > 0 then
                    AmmoBagFunction.ItemOut(candidate, take)
                    moved = moved + take
                    break
                end
            end
        end
    end)

    if ok and moved > 0 then
        print("[AutoAll] reload: drew " .. tostring(moved)
                .. " x " .. tostring(key) .. " from a Modern Firearms AmmoBag")
    end
    return moved
end

--- Phase one: bring the magazine and the loose rounds into the inventory.
---
--- This used to be the first half of beginCycling, with the load queued in
--- the same tick right behind the transfers. That is the bug behind two
--- reports:
---
---   "Reloading doesn't work for me at all. The on-screen text appears,
---    but it doesn't actually reload. This only happens on the multiplayer
---    server, it works perfectly in singleplayer."          - Ducci
---   "Auto Reload stops mid-way within the first reload cycle."
---                                                          - Firestorm
---
--- transferIfNeeded and transferBullets QUEUE timed actions - the
--- character walks over and moves the items. Queueing the load behind them
--- in the same tick means the load is built and validated against an
--- inventory the transfers have not reached yet. In single player that is
--- harmless, because the inventory is consistent the instant an action
--- ends. On a client transfers settle through the server, and
--- ISLoadBulletsInMagazine:start() opens with
---
---     local itemKey = self.magazine:getAmmoType():getItemKey()
---     if not self.character:getInventory():containsWithModule(itemKey) then
---         self:forceStop()
---         return
---     end
---
--- so it stops itself, silently. ISUnloadBulletsFromMagazine:start() then
--- finds ammoCountStart == 0 and forceComplete()s. The queue drains, the
--- halo text appears, and not one round has moved - which is exactly what
--- both reports describe.
---
--- roundsPerCycle had the same ordering fault: it was worked out from
--- ammoInInventory BEFORE the rounds were fetched, so it counted what the
--- character was already carrying and nothing that was about to arrive.
---
--- So the transfers get a phase of their own now, and the batch is built
--- once the queue is idle - the same gather-then-work shape Auto Sterilize
--- and Auto Dismantle use, and for the same reason.
local function prepareCycling(task, item)
    local player = task.player

    task.item        = item
    task.isMagazine  = Reload.isMagazine(item)
    task.phase       = "preparing"
    task.prepareTries = 0

    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    ISInventoryPaneContextMenu.transferBullets(player, ammoKeyOf(item), 0, item:getMaxAmmo())
    if not task.isMagazine then
        ISInventoryPaneContextMenu.equipWeapon(item, true, false, player:getPlayerNum())
    end
end

--- Points a task at the magazine it will cycle and gets the first batch
--- moving. Runs once the fetching above has actually landed.
local function beginCycling(task, item)
    local player     = task.player
    local isMagazine = Reload.isMagazine(item)
    local spare      = ammoInInventory(player, item)

    task.item           = item
    task.isMagazine     = isMagazine
    task.roundsPerCycle = math.min(item:getMaxAmmo(), spare + item:getCurrentAmmoCount())
    task.phase          = "cycling"
    task.lastProgress   = AA.now()
    task.lastAmmo       = item:getCurrentAmmoCount()
    task.lastAmmoAt     = AA.now()

    queueBatch(task)
end

local function think(task)
    local player = task.player

    -- The magazine was inside the gun. Wait for the ejection to land, then
    -- carry on as normal - it is an ordinary magazine in a pocket now.
    if task.phase == "ejecting" then
        if AA.isQueueBusy(player) then return end

        local magazine = task.gun and task.gun:getBestMagazine(player)
        if magazine then
            prepareCycling(task, magazine)
            return
        end

        task.ejectTries = task.ejectTries + 1
        if task.ejectTries > EJECT_ATTEMPTS then
            AA.stop(player, getText("UI_AA_reload_nomagazine"), true)
        end
        return
    end


    -- Phase one has queued the walk-and-fetch. Nothing may be built
    -- against the inventory until that has actually landed - see the long
    -- note on prepareCycling.
    if task.phase == "preparing" then
        if AA.isQueueBusy(player) then return end

        local item = currentItem(task)
        if not item then
            AA.stop(player, getText("UI_AA_reload_lost"), true)
            return
        end

        -- The exact test ISLoadBulletsInMagazine:start() is about to make.
        -- Asking it here means a load that would forceStop() itself is
        -- never queued in the first place, and the player is told why
        -- instead of watching the queue drain with nothing happening.
        local key = ammoKeyOf(item)
        local ready = key ~= nil
                and item:getCurrentAmmoCount() < item:getMaxAmmo()
                and player:getInventory():containsWithModule(key)

        -- A magazine that is already full has nothing to load but plenty
        -- to unload, so it is ready by definition.
        if key and item:getCurrentAmmoCount() >= item:getMaxAmmo() then
            ready = true
        end

        if ready then
            beginCycling(task, item)
            return
        end

        -- Modern Firearms keeps its rounds inside an AmmoBag, where
        -- transferBullets cannot see them. Ask the mod for them the
        -- way its own reload does, then let the next tick re-check.
        if key and drawFromAmmoBag(player, key, item:getMaxAmmo()) > 0 then
            return
        end

        -- The transfer may simply not have caught up yet on a client.
        task.prepareTries = (task.prepareTries or 0) + 1
        if task.prepareTries > PREPARE_ATTEMPTS then
            print("[AutoAll] reload not ready: ammo=" .. tostring(key)
                    .. " inInventory=" .. tostring(key and player:getInventory():containsWithModule(key))
                    .. " item=" .. tostring(item:getFullType())
                    .. " count=" .. tostring(item:getCurrentAmmoCount())
                    .. "/" .. tostring(item:getMaxAmmo()))
            AA.stop(player, getText("UI_AA_reload_noammo"), true)
        end
        return
    end
    -- Looked up again rather than trusted: on a server the instance the
    -- task started with is replaced as item transactions settle, and
    -- contains() on the old object would report the magazine as lost
    -- while it is sitting right there in the inventory.
    local item = currentItem(task)

    if not item or not AA.holds(player, item) then
        AA.stop(player, getText("UI_AA_reload_lost"), true)
        return
    end

    -- Rounds actually moved, which is NOT the same thing as actions
    -- consumed. Both reload actions end on an animation event, and PZ's
    -- own queue treats a stalled action as finished: ISTimedActionQueue
    -- :tick() calls onCompleted() on `action.action:hasStalled()`, and
    -- onCompleted never calls complete(). So a batch that cannot make
    -- progress drains at full speed while moving no ammunition at all -
    -- which is the "it makes the sounds, just far far too fast, and
    -- nothing happens" report from a player training in a vehicle.
    --
    -- The old check below measured the queue draining and called that
    -- progress, so it would have watched that happen for as long as the
    -- batch lasted. Same lesson as Auto Rip's confirmPendingCrafts: ask
    -- the world what changed, not the queue.
    local ammoNow = item:getCurrentAmmoCount()
    if ammoNow ~= task.lastAmmo then
        task.moved      = task.moved + math.abs(ammoNow - task.lastAmmo)
        task.lastAmmo   = ammoNow
        task.lastAmmoAt = AA.now()
    elseif AA.now() - task.lastAmmoAt > AMMO_STALL_MS then
        -- The weapon and its reload type are named because the most likely
        -- way for the animation events to stop arriving is that the anim
        -- node which carries them did not load. Those nodes are chosen by
        -- exactly this value: LoadRifle.xml matches
        -- `WeaponReloadType == boltaction`, and every reload action sets
        -- the variable with tostring(gun:getWeaponReloadType()).
        --
        -- Not hypothetical. A dedicated server log from 2026-08-15 shows
        -- Hot Brass (Workshop 3610677934) failing to parse its Unload
        -- nodes for exactly rifle, no-mag rifle, roller-delay and both
        -- shotguns, while handgun, revolver, MP5 and the levers loaded
        -- fine. If a stall ever tracks a reload type that way, this line
        -- is what shows it.
        local gun = task.gun
        local reloadType = "?"
        if gun then
            local ok, value = pcall(function() return tostring(gun:getWeaponReloadType()) end)
            if ok then reloadType = value end
        end

        print("[AutoAll] reload stuck: " .. tostring(task.queued - countOurActions(player))
            .. " actions consumed, " .. tostring(task.moved) .. " rounds moved, vehicle="
            .. tostring(player:getVehicle() ~= nil)
            .. ", weapon=" .. tostring(gun and gun:getFullType() or "none")
            .. ", reloadType=" .. reloadType)
        AA.stop(player, getText("UI_AA_reload_stuck"), true)
        return
    end

    local remaining = countOurActions(player)
    local finished  = task.queued - remaining

    if finished > task.finished then
        task.finished     = finished
        task.lastProgress = AA.now()
        task.cycles       = math.floor(finished / 2)
    elseif AA.now() - task.lastProgress > STALL_MS then
        AA.stop(player, getText("UI_AA_reload_interrupted"), true)
        return
    end

    local maxCycles = AA.opt("reloadMaxCycles") or 0
    if maxCycles > 0 and task.cycles >= maxCycles then
        AA.stop(player, getText("UI_AA_reload_done", task.cycles, task.cycles * task.roundsPerCycle), false)
        return
    end

    if remaining > REFILL_AT then return end

    if item:getCurrentAmmoCount() + ammoInInventory(player, item) <= 0 then
        AA.stop(player, getText("UI_AA_reload_noammo"), true)
        return
    end

    AA.reason(task, getText("UI_AA_reload_cycling", task.cycles))

    if not queueBatch(task) and remaining == 0 then
        AA.stop(player, getText("UI_AA_reload_done", task.cycles, task.cycles * task.roundsPerCycle), false)
    end
end

function Reload.start(player, selected)
    if not player then return end

    local item  = Reload.resolveTarget(player, selected)
    local eject = false

    if not item then
        if not Reload.needsEject(player, selected) then
            HaloTextHelper.addBadText(player, getText("UI_AA_reload_nomagazine"))
            return
        end
        eject = true
    end

    -- With the magazine still seated, the gun is the thing that knows how
    -- many rounds there are.
    local counted = item or selected
    local spare   = ammoInInventory(player, counted)
    if counted:getCurrentAmmoCount() <= 0 and spare <= 0 then
        HaloTextHelper.addBadText(player, getText("UI_AA_reload_noammo"))
        return
    end

    local task = {
        kind             = "reload",
        player           = player,
        gun              = selected,
        item             = item,
        isMagazine       = item ~= nil and Reload.isMagazine(item) or false,
        roundsPerCycle   = 0,
        cycles           = 0,
        cyclesQueued     = 0,
        queued           = 0,
        finished         = 0,
        ejectTries       = 0,
        moved            = 0,      -- rounds actually loaded or unloaded
        lastAmmo         = 0,
        lastAmmoAt       = AA.now(),
        phase            = eject and "ejecting" or "cycling",
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
        startText        = getText("UI_AA_reload_started", counted:getDisplayName()),
    }

    AA.startTask(task)

    -- Everything below happens *after* startTask, and that ordering is the
    -- whole point: startTask replaces whatever automation was running, and
    -- replacing one clears the action queue. Setting this up first meant
    -- the replacement wiped the transfer and the equip before the new job
    -- had queued a thing.
    if eject then
        ISInventoryPaneContextMenu.equipWeapon(selected, true, false, player:getPlayerNum())
        ISTimedActionQueue.add(ISEjectMagazine:new(player, selected))
        AA.reason(task, getText("UI_AA_reload_ejecting"))
    else
        prepareCycling(task, item)
    end
end

Reload.onStart = function(player, item)
    Reload.start(player, item)
end

Reload.onStop = function(player)
    AA.stop(player, getText("UI_AA_stopped"), false)
end

---------------------------------------------------------------------
-- context menu
---------------------------------------------------------------------

local function addReloadMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local actual = ISInventoryPane.getActualItems(items)
    local item = actual and actual[1]
    if not Reload.canTrain(item) then return end

    if AA.isRunning(player, "reload") then
        AA.addOption(context, getText("UI_AA_reload_stop"), player, Reload.onStop)
        return
    end
    if not AA.holds(player, item) then return end

    local option = AA.addOption(context, getText("UI_AA_reload_option"), player, Reload.onStart, item)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()

    -- On a magazine fed gun the rounds go into the magazine, so that is what
    -- the tooltip has to describe.
    local target = Reload.resolveTarget(player, item)
    if not target and Reload.needsEject(player, item) then
        -- The only magazine is the one in the gun. The job takes it out
        -- first; greying this out is what hid the option on every gun
        -- carrying its own magazine and no spare.
        local spare = ammoInInventory(player, item)
        if item:getCurrentAmmoCount() <= 0 and spare <= 0 then
            option.notAvailable = true
            tooltip.description = getText("UI_AA_reload_noammo")
        else
            tooltip.description = getText("UI_AA_reload_ejecting") .. " <LINE> "
                .. getText("UI_AA_reload_option_tt",
                        item:getCurrentAmmoCount(), item:getMaxAmmo(), spare)
        end
    elseif not target then
        option.notAvailable = true
        tooltip.description = getText("UI_AA_reload_nomagazine")
    else
        local spare = ammoInInventory(player, target)
        if target:getCurrentAmmoCount() <= 0 and spare <= 0 then
            option.notAvailable = true
            tooltip.description = getText("UI_AA_reload_noammo")
        elseif target ~= item then
            tooltip.description = getText("UI_AA_reload_option_mag_tt",
                    target:getDisplayName(), target:getCurrentAmmoCount(), target:getMaxAmmo(), spare)
        else
            tooltip.description = getText("UI_AA_reload_option_tt",
                    target:getCurrentAmmoCount(), target:getMaxAmmo(), spare)
        end
    end
    option.toolTip = tooltip
end

AA.registerMenu("reload", Events.OnFillInventoryObjectContextMenu, addReloadMenu)
