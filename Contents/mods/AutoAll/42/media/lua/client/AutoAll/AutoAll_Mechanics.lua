--[[
    Auto All - Train Mechanics (Build 42 / SP + MP)
    ------------------------------------------------------------------
    One entry, "Train Mechanics", on the vehicle itself and on the
    mechanics window.

    The character works its way around the car taking one part off and
    putting it straight back on, then moving to the next. Both halves of
    that give Mechanics XP in vanilla, which is how the skill is trained
    by hand - this only removes the thirty right clicks.

    ------------------------------------------------------------------
    What "one part" actually means

    A part pays XP twice: once for coming off, once for going back on.
    After that it is spent, and working it again is time for nothing.

    That is read out of the game rather than assumed.
    IsoPlayer.addMechanicsItem begins, in effect, with

        if (this.mechanicsItem.get(key) != null) return;

    where key is item:getID() .. vehicle:getMechanicalID() .. direction,
    with direction "0" for off and "1" for on. One payout each way, per
    item, per vehicle. updateMechanicsItems() then drops entries older
    than 86400000 ms of game time - 24 in-game hours - so a car becomes
    worth training on again a day later.

    Build 41 let you cycle the same part about ten times. Build 42 does
    not. This is the 42 behaviour.

    ------------------------------------------------------------------
    Four things it can do, in this order of preference

      drop      a part with nothing left to give, out of the inventory
                and onto the floor
      install   put back a part that still has an install to earn from
      uninstall the ordinary work
      clear     take a spent part off, without putting it back, purely
                because it is standing in front of one that can still pay

    "clear" is the one that keeps the job moving. A brake and a suspension
    can only be reached with the tyre off - requireUninstalled says so in
    template_brake.txt - and once that tyre has given both its payouts,
    putting it back on would wall off the brake for good. So it comes off
    and stays off, on the ground next to the car.

    "drop" is why the character does not end up crawling. A car's worth of
    parts weighs far more than a survivor can carry, so nothing spent is
    carried any further than the next tick.

    ------------------------------------------------------------------
    How the work is queued

    The base game already has one function that does a part properly:

        ISVehiclePartMenu.onUninstallPart(player, part)
        ISVehiclePartMenu.onInstallPart(player, part, item)

    Those are what the vanilla context menu calls. Each one fetches the
    tools the part needs, walks the character round to the right side of
    the car, equips the wrench, opens the bonnet if the part is under it,
    runs the vanilla timed action and closes the bonnet again. So this
    module never touches a part directly - it decides which part is next
    and hands it to the same function the menu would have.

    One part at a time, never a queued batch. A car changes shape as you
    work on it: taking a door off exposes the seat behind it, and taking
    the seat out changes whether the next part can be reached at all.

    ------------------------------------------------------------------
    Ordering, and the part that got skipped

    Parts are worked in a fixed order that walks round the car - radio,
    battery, headlights, windscreen, bonnet, then each corner in turn -
    rather than in whatever order getPartByIndex hands them back. Two
    reasons: it groups parts by which tool they need, and it means a part
    that is blocking another one comes off before the thing it blocks.

    The first version of this module asked "what can be done right now"
    and stopped when that list ran out. Anything the game was refusing
    because another part was still in the way - which is most of the
    front of the car until the bonnet is open - was never reached. The
    ordered pass resolves that round by round instead.

    The order is also what satisfies an install's dependencies: a tyre
    needs its brake fitted first and a window needs its door, and both
    come earlier in the list. There was once a "blocker" branch here that
    tried to help with that and had the relationship backwards - it
    *uninstalled* the parts an install required - which walled the tyres
    and windows out of the car and left them in the inventory until the
    character could barely walk. Nothing replaces it. Vehicles.lua:903
    already refuses an install whose requireInstalled parts are missing.

    ------------------------------------------------------------------
    A failed attempt is not a reason to move on

    Failing to get a part off is a normal outcome - it is most of what
    low Mechanics *is*. So the character keeps at the same part until it
    gives, which is how a person works: you do not walk round to the
    other side of the car because a bolt did not shift first time. After
    a long losing streak it lets the rest of the car have a turn, but it
    is never struck off and always comes back round.

    The only thing that ends the job early is a genuine deadlock, and
    losing a roll is not one. What counts is a job the game accepted and
    then ran nothing for - DEADLOCK of those in a row. Bad luck resets
    the count, so the two cannot be confused.

    ------------------------------------------------------------------
    It never ends holding the car

    Whatever is still being carried when the job stops goes on the floor
    beside the car first, and the job waits to see that it landed rather
    than trusting the queue. Only what this job took off this car is ever
    dropped - a spare tyre out of the player's own bag is not ours to
    throw away.

    ------------------------------------------------------------------
    Putting the tools away

    ISVehiclePartMenu drags the tools a part needs into the main
    inventory and equips them, and leaves them there. Work round a whole
    car and the character ends up carrying a screwdriver, a wrench, a lug
    wrench and a jack loose in its hands and pockets.

    So after each part, any tool that no remaining part still needs is
    unequipped and put in a bag. Which items count as tools is read off
    the parts themselves - the type and tag list the game checks - so a
    modded part asking for a modded tool is handled without a word of
    special casing here.

    ------------------------------------------------------------------
    Never take off what you cannot put back

    A door needs a wrench and the car key both to come off and to go on.
    A brake needs a jack and a wrench. Lose the wrench half way round the
    car - it wears out - and the character can still remove things it can
    no longer refit, which is how an inventory ends up full of doors and
    brakes with nowhere to go.

    So the "can this come off" question now also asks "and could it go
    back on", using the game's own install test with the two checks that
    need the part to already be off taken out.

    And in the other direction: the success floor decides what to *start*.
    Once a part is off, putting it back is an obligation, not a choice, so
    no floor is applied to an install. It is retried until it goes on or
    breaks trying, because leaving it in the inventory forever is worse.

    ------------------------------------------------------------------
    What it will not do

    Nothing here changes the odds, the XP, the times or the tools. Parts
    below the success chance you set are not *started*, and the game's own
    chance is what decides. In single player it reads vanilla's own record
    of what has already paid out - the same one the debug overlay reads -
    so a car worked on yesterday is not worked on again for nothing.

    On a server that record is not reliably readable from here, so there
    the count is kept for the session only. The one cost is that a fresh
    session cannot see payouts from an earlier one. Inventing a cooldown
    of our own to cover that would be a rebalance, and this mod does not
    do those.

    It is deliberately quiet. No running commentary, so single player can
    fast forward the clock through the whole job.
]]

--[[
    2026-08-31, from KhaozNZ - two fixes with one cause, merged from the
    Auto All (Fixed) fork, Workshop 3792445930. Thank you.

    wouldBlockWork() deferred a part's install while anything it blocks had
    an unfinished cycle. Unfinished is not the same as workable. A brake
    under the success floor, missing its tool, unreachable, or out of
    retries is unfinished forever, so the tyre in front of it deferred
    forever and rode round the rest of the car in the inventory.

    1. stillHasWork() now gates the deferral on the blocked part actually
       being workable - odds, tools, reach and retries, not just its cycle
       flags. This is the fix for "carries wheels around for the whole
       duration", and for the zig-zag too: ORDER was always a clean
       anti-clockwise lap and was always being followed, but a corner that
       never finished left the character holding the tyre, and the four
       installs then landed in a second lap wherever the sort put them.

    2. A genuinely deferred part now goes on the ground instead of being
       carried round its own corner. Safe because a drop happens where the
       character stands, and because VehicleUtils.getItems reads the loot
       window's floor, so bestItemFor picks it back up when the install
       comes due.
]]

require "AutoAll/AutoAll_Core"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.mechLoaded then return end
AA.mechLoaded = true

AA.Mech = AA.Mech or {}
local Mech = AA.Mech

-- Past this and the character has clearly walked off. Checked only after
-- the first part, so starting from across the street still works.
--
-- Squared, and measured to the vehicle's centre, so it has to allow for
-- standing at the back of a long one: 25 is five tiles.
local MAX_DISTANCE_SQ = 25

-- Jobs in a row that the game accepted and then ran nothing for. Real
-- failures do not count towards this - see sawBusy in think() - so it is
-- purely a silent-refusal detector and does not need slack for bad luck.
local DEADLOCK = 40

-- Failures in a row on one part before it lets the rest of the car have a
-- turn. It is not struck off: it goes back in the ordinary list and comes
-- round again. This only exists so a part the game will never actually let
-- through cannot hold the whole job forever.
local RETRY_LIMIT = 15

-- Attempts of any kind since anything on the car last moved. The backstop
-- for a genuine livelock, where every attempt is real and every one fails.
local HARD_LIMIT = 200

-- How long to let the vehicle's part state settle after the action queue
-- goes idle, before deciding whether the part moved. On a server the
-- answer comes back from the server, not from the action that just ran.
-- 400 ms is a little over Better Auto Mechanics' 20 ticks.
local SETTLE_MS = 400

-- Failed walks before a part is taken to be physically out of reach and
-- left alone. Two, the same figure Better Auto Mechanics settled on: one
-- can be a zombie or a door in the way, two in a row is a car parked hard
-- against a wall.
local UNREACHABLE = 2

---------------------------------------------------------------------
-- the order the car is worked in
--
-- Walks round the vehicle, grouping parts by the tool they need and
-- putting anything that blocks another part before the thing it blocks.
-- Same idea as Better Auto Mechanics uses, arrived at the same way: it
-- is the order a person would work in.
---------------------------------------------------------------------

local ORDER = {
    -- front
    "Radio", "Battery", "HeadlightLeft", "HeadlightRight", "Windshield", "EngineDoor",
    -- front left
    "BrakeFrontLeft", "SuspensionFrontLeft", "TireFrontLeft",
    -- left doors
    "SeatFrontLeft", "DoorFrontLeft", "WindowFrontLeft",
    "SeatMiddleLeft", "DoorMiddleLeft", "WindowMiddleLeft",
    "SeatRearLeft", "DoorRearLeft", "WindowRearLeft",
    -- rear left
    "BrakeRearLeft", "SuspensionRearLeft", "TireRearLeft",
    -- rear
    "GasTank", "WindshieldRear", "HeadlightRearLeft", "HeadlightRearRight",
    "Muffler", "TrunkDoor", "DoorRear",
    -- rear right
    "BrakeRearRight", "SuspensionRearRight", "TireRearRight",
    -- right doors
    "SeatRearRight", "DoorRearRight", "WindowRearRight",
    "SeatMiddleRight", "DoorMiddleRight", "WindowMiddleRight",
    "SeatFrontRight", "DoorFrontRight", "WindowFrontRight",
    -- front right
    "BrakeFrontRight", "SuspensionFrontRight", "TireFrontRight",
}

local RANK = {}
for index, id in ipairs(ORDER) do RANK[id] = index end

--- Every part of the vehicle, in working order. Anything not on the list
--- above - modded parts, trailers, the engine - goes last rather than
--- being dropped, so a modded car still gets worked on.
local function sortedParts(vehicle)
    local parts = {}
    for i = 0, vehicle:getPartCount() - 1 do
        table.insert(parts, vehicle:getPartByIndex(i))
    end

    table.sort(parts, function(a, b)
        local rankA = RANK[a:getId()] or 999
        local rankB = RANK[b:getId()] or 999
        if rankA ~= rankB then return rankA < rankB end
        return a:getId() < b:getId()
    end)

    return parts
end

---------------------------------------------------------------------
-- what the game will let us do
---------------------------------------------------------------------

--- The game's own chance of getting this part off, or on, in one piece.
--- Read, never written. This is a percentage: 100 is a certainty.
local function successChance(player, part, action)
    local keyvalues = part:getTable(action)
    if not keyvalues then return 0 end

    local perks = keyvalues.skills
    local ok, chance = pcall(function()
        local perksTable = VehicleUtils.getPerksTableForChr(perks, player)
        return VehicleUtils.calculateInstallationSuccess(perks, player, perksTable)
    end)

    if not ok or type(chance) ~= "number" then return 0 end
    return chance
end

Mech.successChance = successChance

local function goodEnough(player, part, action)
    return successChance(player, part, action) >= (AA.opt("mechMinSuccess") or 30)
end

--- Burnt and smashed cars have front windows and seats that cannot be
--- reached, and the game does not always say so up front.
local function unreachableOnWreck(vehicle, part)
    local id = part:getId()
    if not (id:find("WindowFront") or id:find("Seat")) then return false end

    local script = vehicle:getScript()
    local name = script and script:getName() or ""
    return string.find(name, "Burnt") ~= nil or string.find(name, "Smashed") ~= nil
end

--- The best item the character is carrying for an empty part slot.
---
--- "Best" is highest condition, which is what a player picking from the
--- vanilla submenu would do - it lists every matching item with its
--- condition next to it.
local function bestItemFor(part, typeToItem)
    local types = part:getItemType()
    if not types or types:isEmpty() then return nil end

    local best = nil
    for i = 0, types:size() - 1 do
        local matching = typeToItem[types:get(i)]
        if matching then
            for _, item in ipairs(matching) do
                if not item:isBroken()
                        and (not best or item:getCondition() > best:getCondition()) then
                    best = item
                end
            end
        end
    end
    return best
end

--- Why this part could not be put back on, or nil when it could.
---
--- This is Vehicles.InstallTest.Default with the two checks that depend on
--- the part being off right now taken out, so it can be asked about a part
--- that is still bolted on. That is the whole point of it: the game will
--- only answer "can this be installed" once the part is already off, and by
--- then it is too late to decide not to remove it.
---
--- Doors are the case that made this necessary. A door needs a wrench and
--- the car key both ways, so a character with the key can strip one and a
--- character without it cannot put it back - and the only sign was a pile
--- of doors in the inventory.
---
--- `ignoreOdds` separates the two questions this is asked. Deciding whether
--- to *start* on a part, the success floor counts: there is no sense pulling
--- a door you will probably wreck putting back. Deciding whether a part
--- already off the car can ever go back on, it must not - a bad roll is
--- something to keep trying, not a reason to give up on it and drop it.
local function installBlocker(player, part, typeToItem, tagToItem, ignoreOdds)
    local keyvalues = part:getTable("install")
    if not keyvalues then return "no install recipe" end
    if not part:getItemType() or part:getItemType():isEmpty() then return "no item type" end

    if not VehicleUtils.testProfession(player, keyvalues.professions) then return "profession" end
    if not VehicleUtils.testRecipes(player, keyvalues.recipes) then return "recipe not known" end
    if not VehicleUtils.testTraits(player, keyvalues.traits) then return "trait" end
    if not VehicleUtils.testItems(player, keyvalues.items, typeToItem, tagToItem) then return "missing tool" end
    if VehicleUtils.RequiredKeyNotFound(part, player) then return "no car key" end
    if not ignoreOdds and not goodEnough(player, part, "install") then return "odds too low" end

    return nil
end

Mech.installBlocker = installBlocker

--- Can this part come off right now?
---
--- Deliberately also asks whether it could go back on. Taking off what
--- cannot be refitted is how a character ends up carrying four doors and
--- two brakes it can do nothing with, which is exactly what happened.
local function canTakeOff(player, vehicle, part, typeToItem, tagToItem)
    if not part:getInventoryItem() then return false end
    if not part:getTable("uninstall") then return false end
    if unreachableOnWreck(vehicle, part) then return false end
    if not vehicle:canUninstallPart(player, part) then return false end
    if not goodEnough(player, part, "uninstall") then return false end
    if installBlocker(player, part, typeToItem, tagToItem) then return false end
    return true
end

--- Can this part go back on right now, and with what?
---
--- No success floor here, on purpose. The floor decides what to *start*;
--- once a part is off, putting it back is an obligation, not a choice, and
--- it is retried until it goes on or breaks trying. Leaving it in the
--- inventory forever is the worse outcome by a long way.
local function canPutOn(player, vehicle, part, typeToItem)
    if part:getInventoryItem() then return nil end
    if not part:getTable("install") then return nil end
    if unreachableOnWreck(vehicle, part) then return nil end
    if not vehicle:canInstallPart(player, part) then return nil end
    return bestItemFor(part, typeToItem)
end

---------------------------------------------------------------------
-- when a part has given all the XP it is going to
--
-- Read out of the game, not guessed. IsoPlayer.addMechanicsItem starts
-- with, in effect:
--
--     if (this.mechanicsItem.get(key) != null) return;
--
-- so a key already in that map means no XP - and the key is
--
--     item:getID() .. vehicle:getMechanicalID() .. direction
--
-- with direction "0" for taking off and "1" for putting on. It pays out
-- once each way, per item, per vehicle. Not ten times: that was Build 41.
--
-- updateMechanicsItems() drops entries older than 86400000 ms of game
-- time, which is 24 in-game hours. (That is also where Better Auto
-- Mechanics' 24 hour figure comes from - it is vanilla's number, being
-- reimplemented for multiplayer, not something they invented.)
--
-- On a server the map is not reliably readable from here, so there the
-- per session record below is what counts. It cannot see payouts from
-- before the session, which only means the first part of a fresh run may
-- do one unpaid cycle. Inventing a cooldown of our own would be a
-- rebalance, and this mod does not do those.
---------------------------------------------------------------------

local function xpAlreadyPaid(player, vehicle, item, direction)
    if not item then return false end
    local ok, entry = pcall(function()
        return player:getMechanicsItem(item:getID() .. vehicle:getMechanicalID() .. direction)
    end)
    return ok and entry ~= nil
end

local function cycleOf(task, id)
    local entry = task.cycle[id]
    if not entry then
        entry = { off = false, on = false }
        task.cycle[id] = entry
    end
    return entry
end

--- Would taking this part off pay any XP?
local function payingUninstall(task, part)
    if cycleOf(task, part:getId()).off then return false end
    if isClient() then return true end
    return not xpAlreadyPaid(task.player, task.vehicle, part:getInventoryItem(), "0")
end

--- Would putting this item on pay any XP?
local function payingInstall(task, part, item)
    if cycleOf(task, part:getId()).on then return false end
    if isClient() then return true end
    return not xpAlreadyPaid(task.player, task.vehicle, item, "1")
end

--- The item this job itself took off the car for this part, if the
--- character is still carrying it.
---
--- Matched by item id, not by type, and that is the whole point. A survivor
--- who set out to work on a car is quite likely to already have a spare
--- tyre or a spare battery in the bag, and "the first item of the right
--- type in the inventory" would find theirs and throw it in the mud at the
--- end of the job. Only what came off this car is ever dropped.
---
--- Deliberately not bestItemFor either: that one sees the floor and open
--- containers, so a part already lying on the ground would be picked as
--- something to drop and the job would drop it forever.
local function ourCarriedItem(task, part)
    local wanted = task.ours[part:getId()]
    if not wanted then return nil end

    local types = part:getItemType()
    if not types or types:isEmpty() then return nil end

    local inventory = task.player:getInventory()
    for i = 0, types:size() - 1 do
        local items = inventory:getAllTypeRecurse(types:get(i))
        if items then
            for n = 0, items:size() - 1 do
                local item = items:get(n)
                if item and item:getID() == wanted then return item end
            end
        end
    end
    return nil
end

--- Parts that have to be off the car before this one can be worked on.
--- This is the tyre in front of the brake and the suspension.
local function blockersOf(part, action)
    local out = {}
    local keyvalues = part:getTable(action)
    if not keyvalues or not keyvalues.requireUninstalled then return out end

    local vehicle = part:getVehicle()
    for _, id in ipairs(keyvalues.requireUninstalled:split(";")) do
        local other = vehicle:getPartById(id)
        if other then table.insert(out, other) end
    end
    return out
end

--- Would putting this part back on wall off something that still has work
--- left in it?
---
--- Every corner of a car is a knot, read straight out of the templates:
---
---     template_tire.txt        install requireInstalled = Brake;Suspension
---     template_brake.txt       both    requireUninstalled = Tire
---     template_suspension.txt  both    requireUninstalled = Tire
---
--- So the tyre has to be off before the brake or the suspension can be
--- touched at all, and it has to go back on last. But install beats
--- uninstall in the ordering - which is what stops the character carrying
--- half a car - so the moment a tyre came off it went straight back on,
--- sealing the brake and the suspension away again. They were only reached
--- much later by `clear`, which took the same tyre off a second time. A
--- whole lap of wasted work per corner, and the tyre ended up on the
--- ground anyway.
---
--- So an install waits while anything it would block still has something
--- to earn. Only `install` asks this: taking a part off never blocks
--- anything, and neither does dropping one.

--- Is this part actually going to be worked on, as opposed to merely
--- unfinished?
---
--- This distinction is the whole bug. wouldBlockWork used to ask only
--- "has this part finished its cycle", and an unfinished part is not the
--- same as a part with work left in it. A brake whose odds sit under the
--- success floor, whose tool is missing, that cannot be walked to, or that
--- has burnt through its retries never finishes its cycle and never will.
--- The tyre in front of it deferred against that forever.
---
--- Two reports come out of that one line, and they are the same report:
---
---   * "randomly carrying wheels around for the whole duration, hurting
---     the character" - the tyre is never allowed to go back on, so it
---     rides in the inventory for the rest of the car;
---   * "zig-zags around the car rather than a consistent anti-clockwise
---     loop, FL then BL then FR then BR" - ORDER is already a clean
---     anti-clockwise lap, and it was being followed. What broke the lap
---     is that each corner never finished: the character left it still
---     holding the tyre, and the four installs then happened much later,
---     in a second lap, wherever the sort put them.
---
--- Both go away by asking the right question here. A corner where the
--- brake and the suspension are workable holds the tyre for that corner
--- and no longer; a corner where they are not puts the tyre straight back
--- on and the character moves along.
local function stillHasWork(task, part, typeToItem, tagToItem)
    local id = part:getId()

    local cycle = cycleOf(task, id)
    if cycle.off and cycle.on then return false end

    -- Out of turns, or unwalkable. The rest of the car has overtaken it,
    -- and nothing should be held hostage waiting for it.
    if (task.strikes[id] or 0) >= RETRY_LIMIT then return false end
    if (task.unreachable[id] or 0) >= UNREACHABLE then return false end

    if part:getInventoryItem() then
        return payingUninstall(task, part)
                and canTakeOff(task.player, task.vehicle, part, typeToItem, tagToItem)
    end

    local item = canPutOn(task.player, task.vehicle, part, typeToItem)
    return item ~= nil and payingInstall(task, part, item)
end

local function wouldBlockWork(task, part, typeToItem, tagToItem)
    local id = part:getId()
    local vehicle = task.vehicle

    for i = 0, vehicle:getPartCount() - 1 do
        local other = vehicle:getPartByIndex(i)
        if other:getId() ~= id then
            for _, action in ipairs({ "install", "uninstall" }) do
                local keyvalues = other:getTable(action)
                local blocked = keyvalues and keyvalues.requireUninstalled
                if blocked then
                    for _, name in ipairs(blocked:split(";")) do
                        -- `other` needs this part off. Is it going to use
                        -- that, or is it never going to be touched?
                        if name == id
                                and stillHasWork(task, other, typeToItem, tagToItem) then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

--- The item this part left in the inventory, when it is never going back on.
---
--- Three ways a carried part turns into dead weight, and the old code only
--- knew the first:
---
---   * it has already been refitted once, so the install is spent;
---   * it broke - bestItemFor skips a broken item, so nothing will ever
---     offer it for an install again;
---   * the game will not take it back at all: a wrench that wore out
---     halfway round the car, a car key that is not in the pocket, a recipe
---     that was never learned.
---
--- payingInstall must not be the gate on its own, which is what it was.
--- On a client it answers "yes, that could still pay" for anything not yet
--- refitted this session - which describes precisely the part that is
--- stuck. So on the dedicated server the drop never fired for the parts it
--- existed for, and the inventory filled up with tyres and windows.
---
--- The odds are deliberately ignored here. A part that merely rolls badly
--- is retried, not dropped.
local function deadWeight(task, part, typeToItem, tagToItem)
    local carried = ourCarriedItem(task, part)
    if not carried then return nil end

    -- The player marked it. Leave it alone and say so at the end.
    if carried:isFavorite() then return nil end

    if cycleOf(task, part:getId()).on then return carried end
    if carried:isBroken() then return carried end
    if installBlocker(task.player, part, typeToItem, tagToItem, true) then return carried end

    return nil
end

---------------------------------------------------------------------
-- is there anything to do at all
---------------------------------------------------------------------

--- A stand-in task, so the menu asks exactly the same question the job
--- will ask rather than a second opinion that can disagree with it.
local function dryRun(player, vehicle)
    -- `ours` empty on purpose: a survey has not taken anything off the car
    -- yet, so it can never propose dropping something.
    return {
        player = player, vehicle = vehicle,
        cycle = {}, strikes = {}, ours = {}, unreachable = {},
    }
end

---------------------------------------------------------------------
-- parts the character cannot physically walk to
--
-- The game answers "can this part be uninstalled" from tools, skills and
-- what else is bolted on. It does not answer "can the character stand
-- next to it", and a car parked hard against a wall or a fence has parts
-- that are perfectly legal and completely unreachable.
--
-- What happens then is invisible from here. ISPathFindAction gets
-- BehaviorResult.Failed, and with no onFail handler set -
-- onUninstallPart and onInstallPart do not set one - it calls
-- forceStop(), which is ISBaseTimedAction:stop(), which calls
-- resetQueue() and wipes the whole queue. The uninstall that was queued
-- behind it never runs. To think() that is indistinguishable from an
-- ordinary failed roll, so the part goes straight back to the front of
-- the list and the character walks at the wall again.
--
-- That was survivable while a failure sent the part to the back of the
-- queue. It is not survivable now that a failure means "try that one
-- again", which is why this is here.
--
-- The hook is deliberately observational: it only ever sets onFailFunc
-- when there is none, and vanilla still calls forceStop() afterwards
-- exactly as before, because runActionsAfterFailing stays nil. Outside a
-- running mechanics task it does nothing at all - ISPathFindAction is
-- used by half the game.
---------------------------------------------------------------------

local function pathFailed(player)
    local task = AA.getTask(player)
    if not task or task.kind ~= "mechanics" or not task.current then return end

    local count = (task.unreachable[task.current] or 0) + 1
    task.unreachable[task.current] = count

    -- Remembered so the failure sound is not played for it: a part that
    -- could not be walked to never got as far as a roll, and a metal snap
    -- would be describing something that did not happen.
    task.pathFailedAt = task.current

    -- Only records it. think() reads both when it scores the attempt, so
    -- there is one place that decides what to try next.
    print("[AutoAll] mech could not walk to " .. task.current
            .. " (" .. tostring(count) .. " of " .. tostring(UNREACHABLE) .. ")")
end

if not ISPathFindAction then
    print("[AutoAll] ISPathFindAction not found - unreachable parts will not be detected.")
elseif not AA.mechPathHooked then
    AA.mechPathHooked = true

    local original_ISPathFindAction_start = ISPathFindAction.start
    function ISPathFindAction:start(...)
        local result = original_ISPathFindAction_start(self, ...)

        -- Never displace a handler the game or another mod already set:
        -- ISVehiclePartMenu.onPumpGasoline sets one, and overwriting it
        -- would change vanilla behaviour rather than observe it.
        if not self.onFailFunc and self.character
                and instanceof(self.character, "IsoPlayer") then
            local ok, task = pcall(AA.getTask, self.character)
            if ok and task and task.kind == "mechanics" and task.active then
                self:setOnFail(pathFailed, self.character)
            end
        end

        return result
    end
end

---------------------------------------------------------------------
-- the job
---------------------------------------------------------------------

-- Lower goes first when nothing above has separated two candidates.
-- Dropping is nearly free and sheds weight, so it goes ahead of
-- everything; installing comes next so a part just removed goes back on
-- before anything else is touched; clearing is last because it only
-- exists to unblock and costs a part its place on the car.
local PRIORITY = { drop = 1, install = 2, uninstall = 3, clear = 4 }

--- Everything that could be done right now, in the order it should be
--- tried.
---
--- Three keys, in this order:
---
---   1. the part that just failed, if any - the character stays on it
---      until it gives rather than wandering off round the car;
---   2. fewest failures, so once a part has had its RETRY_LIMIT turns the
---      rest of the car goes ahead of it - it is never struck off, only
---      overtaken, and comes back round when the others catch up;
---   3. PRIORITY, then working order.
---
--- Install beating uninstall at (3) is what stops the character ending up
--- carrying the whole car: the part that just came off has no failures
--- against it, so it goes straight back on before anything else is
--- touched.

local function candidates(task)
    local player  = task.player
    local vehicle = task.vehicle
    local typeToItem, tagToItem = VehicleUtils.getItems(player:getPlayerNum())
    typeToItem = typeToItem or {}

    local out = {}
    local function add(entry)
        entry.strikes = task.strikes[entry.part:getId()] or 0
        table.insert(out, entry)
    end

    for index, part in ipairs(sortedParts(vehicle)) do
        -- Both jobs that need the character to stand beside the part are
        -- off the table once it has proved unwalkable. Dropping is not:
        -- that happens where the character already is.
        local reachable = (task.unreachable[part:getId()] or 0) < UNREACHABLE

        if part:getInventoryItem() then
            if reachable and payingUninstall(task, part)
                    and canTakeOff(player, vehicle, part, typeToItem, tagToItem) then
                add({ part = part, action = "uninstall", order = index })
            end
        else
            local item = reachable and canPutOn(player, vehicle, part, typeToItem) or nil
            if item and payingInstall(task, part, item) then
                -- Still a candidate, only a late one: see wouldBlockWork.
                -- Deferring rather than writing it off matters - if the
                -- brake it is blocking turns out to be impossible, the tyre
                -- must still go back on rather than stay off forever.
                local deferred = wouldBlockWork(task, part, typeToItem, tagToItem)

                -- A deferred part goes on the ground rather than round the
                -- corner in the character's arms. A tyre is heavy, the
                -- brake and the suspension behind it are four more actions,
                -- and the whole point of waiting is that it cannot go back
                -- on yet.
                --
                -- Safe to put down because the drop happens where the
                -- character is standing - which is the corner it just came
                -- off - and because VehicleUtils.getItems reads the loot
                -- window, floor included, so bestItemFor picks it straight
                -- back up when the install comes due. Nothing drops twice
                -- either: ourCarriedItem only ever looks in the inventory,
                -- so a part already on the ground is not a candidate.
                if deferred then
                    local held = ourCarriedItem(task, part)
                    if held and not held:isFavorite() then
                        add({ part = part, item = held, action = "drop", order = index })
                    end
                end

                add({
                    part = part, item = item, action = "install", order = index,
                    deferred = deferred,
                })
            else
                -- Nothing left to earn from it, or nothing that will ever
                -- take it back. Put it on the floor rather than carry it
                -- round the rest of the car.
                local dead = deadWeight(task, part, typeToItem, tagToItem)

                -- A part the character cannot walk back to is dead weight
                -- too, whatever its odds would have been.
                if not dead and not reachable then
                    dead = ourCarriedItem(task, part)
                    if dead and dead:isFavorite() then dead = nil end
                end

                -- And anything at all, once the character is over the
                -- limit. Reaching this branch means the part cannot go
                -- back on this turn; carrying it while already overloaded
                -- is how a run ended with a dead character at three times
                -- their carry weight. It is on the ground beside the car,
                -- which is where it can be picked up again.
                if not dead and AA.isOverloaded(player) then
                    dead = ourCarriedItem(task, part)
                    if dead and dead:isFavorite() then dead = nil end
                end

                if dead then
                    add({ part = part, item = dead, action = "drop", order = index })
                end
            end
        end
    end

    -- Only worth working out when there is nothing better to do: a spent
    -- part that is standing in the way of one that can still pay.
    if #out == 0 then
        for index, part in ipairs(sortedParts(vehicle)) do
            if part:getInventoryItem() and payingUninstall(task, part)
                    and not vehicle:canUninstallPart(player, part) then
                for _, blocker in ipairs(blockersOf(part, "uninstall")) do
                    if blocker:getInventoryItem()
                            and (task.unreachable[blocker:getId()] or 0) < UNREACHABLE
                            and not payingUninstall(task, blocker)
                            and goodEnough(player, blocker, "uninstall")
                            and vehicle:canUninstallPart(player, blocker) then
                        add({ part = blocker, action = "clear", order = index })
                    end
                end
            end
        end
    end

    -- The part that just lost its roll goes straight back to the front, so
    -- the character keeps at the same one until it gives - which is what
    -- was asked for, and is how a person works: you do not walk to the
    -- other side of the car because a bolt did not shift first time.
    --
    -- Three things stop this becoming a loop: a part that becomes
    -- impossible leaves the list on its own, RETRY_LIMIT lets the rest of
    -- the car overtake it, and a part the character cannot walk to is
    -- taken out of the running entirely by the pathfinding hook above.
    local retry = task.retry

    table.sort(out, function(a, b)
        local ra = (retry and a.part:getId() == retry) and 0 or 1
        local rb = (retry and b.part:getId() == retry) and 0 or 1
        if ra ~= rb then return ra < rb end
        if a.strikes ~= b.strikes then return a.strikes < b.strikes end

        -- A deferred install sinks below everything except clearing, so
        -- the brake and the suspension get their turn before the tyre
        -- seals them in again - but it is still there to be picked if the
        -- car runs out of anything else to do.
        local pa = a.deferred and (PRIORITY.clear - 0.5) or PRIORITY[a.action]
        local pb = b.deferred and (PRIORITY.clear - 0.5) or PRIORITY[b.action]
        if pa ~= pb then return pa < pb end
        return a.order < b.order
    end)

    return out
end

--- Is there anything to do on this car, and how much is the odds floor
--- holding back?
---
--- Asks candidates() rather than repeating its rules, so the menu can
--- never disagree with the job about whether there is work.
---
--- @return boolean anyWork, number skippedForOdds
function Mech.survey(player, vehicle)
    local probe = dryRun(player, vehicle)
    local anyWork = #candidates(probe) > 0

    local typeToItem, tagToItem = VehicleUtils.getItems(player:getPlayerNum())
    typeToItem = typeToItem or {}

    local skipped = 0
    for _, part in ipairs(sortedParts(vehicle)) do
        if part:getInventoryItem() and part:getTable("uninstall")
                and not unreachableOnWreck(vehicle, part)
                and vehicle:canUninstallPart(player, part)
                and payingUninstall(probe, part) then
            if not goodEnough(player, part, "uninstall")
                    or installBlocker(player, part, typeToItem, tagToItem) then
                skipped = skipped + 1
            end
        end
    end

    return anyWork, skipped
end

--- Picks the next thing to do and hands it to the vanilla menu function.
--- @return boolean didSomething
local function workNext(task)
    local player  = task.player
    local vehicle = task.vehicle

    -- Cleared before every attempt and set by think() the moment the action
    -- queue is seen running. It is the difference between "the roll went
    -- against us", which costs the part nothing, and "the game took the job
    -- and did nothing with it", which is the only thing that ends the run.
    task.sawBusy = false
    task.pathFailedAt = nil
    -- Fresh attempt, fresh settle window.
    task.settleUntil = nil

    local list = candidates(task)
    local choice = list[1]
    if not choice then return false end

    -- There used to be a "blocker" branch here, and it was backwards.
    --
    -- It read the install table's `requireInstalled` - the parts that must
    -- be **on** the car before this one can go on - and uninstalled them.
    -- A tyre needs its brake fitted, so the job pulled the brake back off
    -- the moment it wanted to refit the tyre; a window needs its door, so
    -- it pulled the door. The tyre and the window could then never go on
    -- and rode round in the inventory until the character was at three
    -- times their carry limit. From a real log:
    --
    --     mech uninstall TireFrontLeft (try 1)
    --     mech uninstall BrakeFrontLeft (blocking TireFrontLeft)
    --     mech install   BrakeFrontLeft (try 1)
    --     mech uninstall BrakeFrontLeft (blocking TireFrontLeft)
    --     mech drop      BrakeFrontLeft (try 1)
    --
    -- Nothing replaces it, because nothing needs to. Vehicles.lua:903, in
    -- InstallTest.Default, already refuses an install whose
    -- `requireInstalled` parts are missing, so canPutOn never offers one -
    -- and the working ORDER puts the brake before the tyre and the door
    -- before the window, so the dependency is satisfied on the way past.

    task.current = choice.part:getId()
    task.action  = choice.action

    -- Read before the part comes off, because afterwards the slot is empty
    -- and there is no way back to which item it was. This is what lets the
    -- sweep tell our tyre from the player's own spare.
    local onCar = choice.part:getInventoryItem()
    task.pendingItem = onCar and onCar:getID() or nil

    -- One line per attempt. A whole car is under a hundred lines, and it is
    -- the difference between a report that can be acted on and a guess:
    -- every stall so far has been diagnosed from this file, not from the
    -- screenshot.
    print("[AutoAll] mech " .. choice.action .. " " .. choice.part:getId()
            .. " (try " .. tostring((task.strikes[choice.part:getId()] or 0) + 1) .. ")")

    if choice.action == "install" then
        ISVehiclePartMenu.onInstallPart(player, choice.part, choice.item)
    elseif choice.action == "drop" then
        -- The vanilla drop, so an equipped part is unequipped first and a
        -- server sees the same transfer it would from the context menu.
        ISInventoryPaneContextMenu.dropItem(choice.item, player:getPlayerNum())
    else
        -- uninstall and clear are the same action; only the bookkeeping
        -- afterwards differs.
        ISVehiclePartMenu.onUninstallPart(player, choice.part)
    end
    return true
end

---------------------------------------------------------------------
-- putting the tools away
--
-- The vanilla helpers pull a part's tools into the main inventory and
-- equip them, and never put them back. Over a whole car that is a
-- screwdriver, a wrench, a lug wrench and a jack all riding along.
--
-- Which items count as tools is read off the parts themselves, from the
-- same type and tag list VehicleUtils.testItems checks, so a modded part
-- asking for a modded tool needs nothing added here.
---------------------------------------------------------------------

--- The types and tags named by an items list on a part.
---
--- Tags are collected once each. A car's parts name the same handful of
--- tools over and over, and every duplicate is another Java call for
--- every item in the inventory later on.
local function addRequirement(req, items)
    if not items then return end
    for _, entry in pairs(items) do
        if entry.type then req.types[entry.type] = true end
        if entry.tags then
            for _, name in ipairs(entry.tags:split(";")) do
                if not req.seen[name] then
                    req.seen[name] = true
                    local ok, tag = pcall(function()
                        return ItemTag.get(ResourceLocation.of(name))
                    end)
                    if ok and tag then table.insert(req.tags, tag) end
                end
            end
        end
    end
end

local function newRequirement()
    return { types = {}, tags = {}, seen = {} }
end

local function matchesRequirement(item, req)
    if req.types[item:getFullType()] then return true end
    for _, tag in ipairs(req.tags) do
        if item:hasTag(tag) then return true end
    end
    return false
end

--- Every tool this vehicle asks for anywhere. Worked out once, and used
--- only to answer "is this thing in my pockets a tool at all".
local function allTools(vehicle)
    local req = newRequirement()
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        addRequirement(req, (part:getTable("install") or {}).items)
        addRequirement(req, (part:getTable("uninstall") or {}).items)
    end
    return req
end

--- The tools the rest of this job still needs.
---
--- A part that is off and still has an install to earn from needs its
--- install tools, which is why this is not simply "the parts we have not
--- done yet". Stow the wrench the moment the door comes off and the door
--- cannot go back on.
local function toolsStillNeeded(task)
    local req = newRequirement()
    for i = 0, task.vehicle:getPartCount() - 1 do
        local part = task.vehicle:getPartByIndex(i)
        local cycle = task.cycle[part:getId()]
        if not part:getInventoryItem() then
            if not (cycle and cycle.on) then
                addRequirement(req, (part:getTable("install") or {}).items)
            end
        elseif not (cycle and cycle.off) then
            addRequirement(req, (part:getTable("uninstall") or {}).items)
        end
    end
    return req
end

--- A worn bag with room for this item.
local function bagFor(player, item)
    local worn = player:getWornItems()
    if not worn then return nil end

    for i = 0, worn:size() - 1 do
        local candidate = worn:getItemByIndex(i)
        if candidate and instanceof(candidate, "InventoryContainer") then
            local container = candidate:getInventory()
            if container and container ~= item:getContainer()
                    and container:hasRoomFor(player, item) then
                return container
            end
        end
    end
    return nil
end

--- Puts away every tool nothing else is waiting on.
--- @return boolean queuedSomething
local function stowIdleTools(task)
    local player    = task.player
    local inventory = player:getInventory()
    local needed    = toolsStillNeeded(task)
    local queued    = false

    local items = inventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item:getContainer() == inventory
                and not item:isFavorite()
                and matchesRequirement(item, task.tools)
                and not matchesRequirement(item, needed) then
            local bag = bagFor(player, item)
            if bag then
                if player:isEquipped(item) then
                    ISTimedActionQueue.add(ISUnequipAction:new(player, item, 50))
                end
                ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, inventory, bag))
                queued = true
            end
        end
    end

    return queued
end

---------------------------------------------------------------------
-- finishing, and saying why
--
-- "It stopped and I do not know why, and my inventory is full of doors"
-- is not a report anyone can act on, so every ending writes a line to
-- console.txt naming the reason, and every part left off writes a line
-- naming what is blocking it.
---------------------------------------------------------------------

--- Parts the character is still carrying that it could not fit back, with
--- the reason.
---
--- Only what is actually being carried. A part left on the floor because
--- it had nothing more to give is the job working as intended, not a
--- problem to report - and neither is one that was cleared out of the way
--- of something else.
local function strandedParts(task)
    local player = task.player
    local typeToItem, tagToItem = VehicleUtils.getItems(player:getPlayerNum())
    typeToItem = typeToItem or {}

    local out = {}
    for i = 0, task.vehicle:getPartCount() - 1 do
        local part = task.vehicle:getPartByIndex(i)
        local carried = not part:getInventoryItem() and ourCarriedItem(task, part)
        if carried and part:getTable("install") then
            -- Odds ignored: a part that only rolled badly is not stranded,
            -- it just ran out of turns, and calling that "could not be
            -- refitted" would be a lie in the log.
            local why = installBlocker(player, part, typeToItem, tagToItem, true)
            if not why and carried:isBroken() then
                why = "it broke"
            end
            if not why and not task.vehicle:canInstallPart(player, part) then
                why = "the game refuses it"
            end
            if why then
                table.insert(out, { id = part:getId(), why = why })
            end
        end
    end
    return out
end

--- Every part of this vehicle the character is still carrying, whatever the
--- reason. What the closing sweep works from.
local function carriedParts(task)
    local player = task.player
    local out = {}
    for i = 0, task.vehicle:getPartCount() - 1 do
        local part = task.vehicle:getPartByIndex(i)
        if not part:getInventoryItem() then
            local carried = ourCarriedItem(task, part)
            if carried then table.insert(out, { part = part, item = carried }) end
        end
    end
    return out
end

-- Rounds of dropping before the job stops caring. Three is plenty: a drop
-- that is going to work works first time.
local SWEEP_ATTEMPTS = 3

--- Ends the job - but never while the character is still holding the car.
---
--- The job used to end with whatever it could not refit still in the
--- inventory, which is how a session finished at 49/17 weight carrying two
--- tyres and two windows. Everything left goes on the floor beside the car
--- first.
---
--- Queuing those drops and trusting them is not enough. A drop is an
--- ISInventoryTransferAction like any other, and on a client
--- isItemTransactionConsistent can discard it without a word or a log line -
--- the same trap Auto Cook hit returning ingredients to a container. So this
--- is a phase, not a parting shot: queue the drops, let the queue drain,
--- look again, and only finish once the character is actually empty.
local function finish(task, text, bad)
    local player = task.player

    -- Worked out once, before anything is dropped. After the sweep nothing
    -- is being carried any more, so a report built then would come out
    -- empty and cheerful with four parts lying in the mud.
    if not task.ending then
        task.ending = { text = text, bad = bad, stranded = strandedParts(task) }
    end

    -- Favourites are the player's business, not ours. They are counted
    -- separately so a bag holding nothing but favourites does not burn
    -- every sweep round achieving nothing and then report a failure.
    local carried, keeping = {}, 0
    for _, entry in ipairs(carriedParts(task)) do
        if entry.item:isFavorite() then
            keeping = keeping + 1
        else
            table.insert(carried, entry)
        end
    end

    if #carried > 0 and (task.sweeps or 0) < SWEEP_ATTEMPTS then
        task.sweeps = (task.sweeps or 0) + 1
        print("[AutoAll] mechanics sweep " .. tostring(task.sweeps) .. ": "
                .. tostring(#carried) .. " part(s) still carried")
        for _, entry in ipairs(carried) do
            ISInventoryPaneContextMenu.dropItem(entry.item, player:getPlayerNum())
        end
        return
    end

    local stranded = task.ending.stranded
    print("[AutoAll] mechanics finished after " .. tostring(task.done)
            .. " parts: " .. tostring(task.ending.text))
    for _, entry in ipairs(stranded) do
        print("[AutoAll]   " .. entry.id .. " is still off - " .. entry.why)
    end
    if keeping > 0 then
        print("[AutoAll]   " .. tostring(keeping) .. " part(s) kept - marked favourite")
    end
    if #carried > 0 then
        print("[AutoAll]   " .. tostring(#carried) .. " part(s) could not be dropped")
    end

    local ending = task.ending
    task.ending = nil

    if #stranded > 0 then
        AA.stop(player, getText("UI_AA_mech_left_off", task.done, #stranded), true)
    else
        AA.stop(player, ending.text, ending.bad)
    end
end

local function think(task)
    local player  = task.player
    local vehicle = task.vehicle

    if AA.isQueueBusy(player) then
        -- Something is actually running. That is what separates a lost roll
        -- from a job the game accepted and quietly dropped.
        task.sawBusy = true
        task.settleUntil = nil
        return
    end

    -- The queue just went idle. Give the part state a moment to settle
    -- before reading it.
    --
    -- ISUninstallVehiclePart:complete() ends with transmitPartItem and
    -- sendObjectChange(MECHANIC_ACTION_DONE), so on a server the authority
    -- for what actually happened is the server, and it answers a moment
    -- later. Scoring the instant the queue drains reads the old state,
    -- calls a successful uninstall a failure, and leaves cycle.off unset -
    -- which is how a part comes off and never goes back on.
    --
    -- Better Auto Mechanics waits the same way and for the same reason
    -- (WorkOnNextPartInXTicks(20) from its OnMechanicActionDone handler,
    -- and 10 ticks in single player).
    if task.current then
        local settle = task.settleUntil
        if not settle then
            task.settleUntil = AA.now() + SETTLE_MS
            return
        end
        if AA.now() < settle then return end
    end

    if not vehicle then
        AA.stop(player, getText("UI_AA_mech_novehicle"), true)
        return
    end

    -- An ending that is waiting on its sweep. Nothing else is worth
    -- deciding until the character has put the car down.
    if task.ending then
        finish(task, task.ending.text, task.ending.bad)
        return
    end

    if task.current and player:DistToSquared(vehicle) > MAX_DISTANCE_SQ then
        finish(task, getText("UI_AA_mech_toofar"), true)
        return
    end

    -- Score the part that was just worked on. The queue draining is not
    -- proof it succeeded - a failed uninstall leaves the part where it
    -- was - so the vehicle is asked rather than assumed.
    if task.current then
        local part = vehicle:getPartById(task.current)
        local moved = false

        if part then
            if task.action == "install" then
                moved = part:getInventoryItem() ~= nil
            elseif task.action == "drop" then
                moved = ourCarriedItem(task, part) == nil
            else
                -- uninstall and clear
                moved = part:getInventoryItem() == nil
            end
        end

        if moved then
            task.done = task.done + 1
            task.strikes[task.current] = nil
            task.sinceProgress = 0
            task.sinceMoved    = 0
            task.retry         = nil

            -- Who owns the item now. A part that came off is ours to put
            -- back or, failing that, to drop; one that went back on or was
            -- already dropped is not being carried at all.
            if task.action == "uninstall" or task.action == "clear" then
                task.ours[task.current] = task.pendingItem
            else
                task.ours[task.current] = nil
            end

            -- The half of the cycle that just paid out. Recorded per part
            -- for this session; single player also reads vanilla's own
            -- record, so a part done on a previous visit is not redone.
            local cycle = cycleOf(task, task.current)
            if task.action == "uninstall" then
                cycle.off = true
            elseif task.action == "install" then
                cycle.on = true
            elseif task.action == "clear" then
                -- Already spent, so nothing is earned - but it must not be
                -- put back on, or it would block the same part again.
                cycle.off = true
                cycle.on  = true
            end
        else
            local failures = (task.strikes[task.current] or 0) + 1
            task.strikes[task.current] = failures
            task.sinceMoved = (task.sinceMoved or 0) + 1

            -- A part that was actually worked on and lost, as opposed to
            -- one the character could not walk to or the game silently
            -- refused. Only this deserves a failure sound.
            local failedRoll = task.sawBusy
                    and task.pathFailedAt ~= task.current
                    and task.action ~= "drop"

            -- Stay on the same part and try again. It steps aside only
            -- after a long losing streak, and even then it is not struck
            -- off - it goes back in the list and comes round again once the
            -- others have had their turn.
            --
            -- Except when the failure was the walk rather than the work.
            -- Insisting on a part the character cannot reach is a lap of
            -- the car for nothing, over and over.
            local outOfReach = (task.unreachable[task.current] or 0) >= UNREACHABLE
            task.retry = (not outOfReach and failures < RETRY_LIMIT) and task.current or nil

            -- The part was reached, worked on and the roll went against us.
            -- That is the moment vanilla means to play a metal snap, and in
            -- single player it never does - playServerSound is
            -- GameServer.PlayWorldSound, which returns immediately unless
            -- this process is the server. So it is played here instead, as
            -- a local emitter sound: audible, but not a world sound, so it
            -- does not call zombies over the way the server's does.
            if failedRoll and AA.opt("mechFailSound") and not isClient() and not isServer() then
                pcall(function() player:playSound("PZ_MetalSnap") end)
            end

            -- A roll that went against us is the job working. Only a job
            -- the game took without running anything counts towards
            -- stopping, which is what sawBusy distinguishes.
            if task.sawBusy then
                task.sinceProgress = 0
            else
                task.sinceProgress = task.sinceProgress + 1
            end
        end

        task.current = nil
        task.action  = nil

        -- Silent refusals only, so this no longer has to be scaled to the
        -- success floor: bad luck resets it. Reaching it means the game is
        -- taking the job and doing nothing with it.
        if task.sinceProgress >= DEADLOCK then
            print("[AutoAll] mechanics: " .. tostring(task.sinceProgress)
                    .. " jobs in a row queued nothing")
            finish(task, getText("UI_AA_mech_stuck", task.done), true)
            return
        end

        -- And the backstop for the other shape of stuck: everything is
        -- really being attempted, and none of it ever works.
        if (task.sinceMoved or 0) >= HARD_LIMIT then
            print("[AutoAll] mechanics: " .. tostring(task.sinceMoved)
                    .. " attempts since anything last moved")
            finish(task, getText("UI_AA_mech_stuck", task.done), true)
            return
        end

        -- Hands and pockets emptied of anything the rest of the job is not
        -- waiting on, before deciding what to do next. If that queued a
        -- transfer there is nothing to decide this tick.
        if stowIdleTools(task) then return end
    end

    local cap = AA.opt("mechMax") or 0
    if cap > 0 and task.done >= cap then
        finish(task, getText("UI_AA_mech_done", task.done), false)
        return
    end

    -- Deliberately silent in between. A line of halo text every few
    -- seconds is unreadable at 5x and gets in the way of watching the
    -- clock run.
    if not workNext(task) then
        finish(task, getText("UI_AA_mech_done", task.done), false)
    end
end

function Mech.start(player, vehicle)
    if not player or not vehicle then return end

    if player:getVehicle() then
        HaloTextHelper.addBadText(player, getText("UI_AA_mech_inside"))
        return
    end

    local anyWork = Mech.survey(player, vehicle)
    if not anyWork then
        HaloTextHelper.addBadText(player, getText("UI_AA_mech_nothing"))
        return
    end

    local task = {
        kind      = "mechanics",
        player    = player,
        vehicle   = vehicle,
        done      = 0,
        -- [partId] = { off = paid for coming off, on = paid for going on }
        cycle     = {},
        strikes   = {},     -- [partId] = failures in a row, only ever a sort key
        retry     = nil,    -- the part to go straight back to after a failure
        -- [partId] = id of the item this job took off the car for it. The
        -- only items the closing sweep is allowed to drop, so a spare the
        -- player brought along is never thrown away.
        ours      = {},
        -- [partId] = failed walks. At UNREACHABLE the part is left alone;
        -- the game says it is legal, the pathfinder says otherwise.
        unreachable = {},
        sinceProgress = 0,  -- jobs in a row the game queued nothing for
        sinceMoved    = 0,  -- attempts of any kind since anything last moved
        sweeps    = 0,      -- rounds of dropping what is still being carried
        tools     = allTools(vehicle),
        current   = nil,
        action    = nil,
        think     = think,
        -- The queue is this job's whole heartbeat: think() does nothing
        -- while it is busy. A vanilla ISPathFindAction is built with
        -- maxTime = -1 and an isValid() that is hardcoded true, so a path
        -- that neither arrives nor fails holds it open forever and the job
        -- freezes without a word. See AA.queueStalled.
        stallTimeout = 45000,
        -- The character walks itself around the car between parts.
        allowMove = true,
        -- And it will be over its carry limit for most of the job - see
        -- carryingItOff in AutoAll_Core. Being heavy is not a reason to
        -- stop; being bitten still is.
        allowHeavy = true,
        -- Health never stops this job. Requested outright: a mechanic
        -- carrying a tyre, a brake and four tools is doing the job, and
        -- the muscle strain that costs kept being read as a wound. Safety
        -- now rests on shedding weight instead - candidates() drops a part
        -- that cannot go back on as soon as the character is overloaded -
        -- and on the zombie, movement and ESC stops, which are untouched.
        ignoreDamage = true,
        startText = getText("UI_AA_mech_started"),
    }

    AA.startTask(task)

    if not workNext(task) then
        AA.stop(player, getText("UI_AA_mech_nothing"), true)
    end
end

Mech.onStart = function(player, vehicle)
    Mech.start(player, vehicle)
end

Mech.onStop = function(player)
    AA.stop(player, getText("UI_AA_stopped"), false)
end

---------------------------------------------------------------------
-- the tooltip
--
-- Same information Better Auto Mechanics puts on its button, because it
-- is the right information: which tools are missing, which recipes you
-- have not learned, and whether your level is high enough to do this
-- without wrecking the car.
---------------------------------------------------------------------

local NL = " <LINE>"

local function itemName(fullType)
    local script = getScriptManager():getItem(fullType)
    return script and script:getDisplayName() or fullType
end

--- One "needs" line, green when the character has one of the listed
--- tools and red when it has none.
local function toolLine(has, ...)
    local names = {}
    for _, fullType in ipairs({ ... }) do
        table.insert(names, itemName(fullType))
    end
    return NL .. (has and "<GREEN>" or "<RED>") .. " - " .. table.concat(names, " / ")
end

--- Every recipe any part of this car asks for.
local function requiredRecipes(vehicle)
    local found, order = {}, {}

    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        for _, action in ipairs({ "install", "uninstall" }) do
            local keyvalues = part:getTable(action)
            if keyvalues and keyvalues.recipes and keyvalues.recipes ~= "" then
                for _, recipe in ipairs(keyvalues.recipes:split(";")) do
                    if not found[recipe] then
                        found[recipe] = true
                        table.insert(order, recipe)
                    end
                end
            end
        end
    end

    return order
end

--- True when at least one part of this car is locked behind a key the
--- character does not have.
local function needsKey(player, vehicle)
    if not VehicleUtils.RequiredKeyNotFound then return false end
    for i = 0, vehicle:getPartCount() - 1 do
        if VehicleUtils.RequiredKeyNotFound(vehicle:getPartByIndex(i), player) then
            return true
        end
    end
    return false
end

function Mech.describe(player, vehicle, anyWork, skipped)
    local inv = player:getInventory()
    local msg = ""

    if not anyWork then
        msg = "<RED>" .. getText("UI_AA_mech_nothing") .. NL .. NL .. "<RGB:1,1,1>"
    end

    msg = msg .. getText("UI_AA_mech_needs") .. ":"
    msg = msg .. toolLine(inv:getFirstTagRecurse(ItemTag.SCREWDRIVER),
                          "Base.Screwdriver", "Base.Multitool", "Base.Handiknife")
    msg = msg .. toolLine(inv:getFirstTagRecurse(ItemTag.WRENCH),
                          "Base.Wrench", "Base.Ratchet")
    msg = msg .. toolLine(inv:getFirstTagRecurse(ItemTag.LUG_WRENCH),
                          "Base.LugWrench", "Base.TireIron")
    msg = msg .. toolLine(inv:getFirstTypeRecurse("Jack"), "Base.Jack")

    local recipes = requiredRecipes(vehicle)
    if #recipes > 0 then
        msg = msg .. NL .. NL .. "<RGB:1,1,1>" .. getText("UI_AA_mech_recipes") .. ":"
        for _, recipe in ipairs(recipes) do
            local known = player:isRecipeKnown(recipe, true)
            msg = msg .. NL .. (known and "<GREEN>" or "<RED>") .. " - "
                .. getText("Tooltip_vehicle_requireRecipe", getRecipeDisplayName(recipe))
        end
    end

    local level = player:getPerkLevel(Perks.Mechanics)
    local floor = AA.opt("mechMinSuccess") or 30
    msg = msg .. NL .. NL .. "<RGB:1,1,1>" .. getText("UI_AA_mech_level") .. ": " .. tostring(level)
    msg = msg .. NL .. "<RGB:1,1,1> - " .. getText("UI_AA_mech_minchance", floor)

    if floor >= 100 then
        msg = msg .. NL .. "<GREEN> - " .. getText("UI_AA_mech_parts_safe")
    elseif level < 2 then
        msg = msg .. NL .. "<RED> - " .. getText("UI_AA_mech_will_break")
        msg = msg .. NL .. "<RED> - " .. getText("UI_AA_mech_disposable")
    elseif level < 7 then
        msg = msg .. NL .. "<ORANGE> - " .. getText("UI_AA_mech_might_break")
        msg = msg .. NL .. "<ORANGE> - " .. getText("UI_AA_mech_disposable")
    else
        msg = msg .. NL .. "<GREEN> - " .. getText("UI_AA_mech_parts_safe")
    end

    if (skipped or 0) > 0 then
        msg = msg .. NL .. "<RGB:1,0.75,0.4> - " .. getText("UI_AA_mech_skipping", skipped)
    end

    if needsKey(player, vehicle) then
        msg = msg .. NL .. NL .. "<ORANGE>" .. getText("UI_AA_mech_nokey")
    end

    msg = msg .. NL .. NL .. "<RGB:1,1,1>" .. getText("UI_AA_mech_seats")

    return msg
end

---------------------------------------------------------------------
-- menus
---------------------------------------------------------------------

--- The one entry, added the same way in both places it appears.
local function addTrainOption(context, player, vehicle)
    if AA.isRunning(player, "mechanics") then
        AA.addOption(context, getText("UI_AA_mech_stop"), player, Mech.onStop)
        return
    end

    local option = AA.addOption(context, getText("UI_AA_mech_train"), player, Mech.onStart, vehicle)
    option.iconTexture = getTexture("Item_Wrench")

    local anyWork, skipped = Mech.survey(player, vehicle)
    option.notAvailable = not anyWork

    -- The tooltip is still shown while greyed out, which is the whole
    -- point: it is the thing that says what is missing.
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    tooltip.description = Mech.describe(player, vehicle, anyWork, skipped)
    option.toolTip = tooltip
end

Mech.addTrainOption = addTrainOption

---------------------------------------------------------------------
-- right clicking the car in the world
---------------------------------------------------------------------

local function vehicleFrom(worldobjects)
    for _, object in ipairs(worldobjects) do
        if instanceof(object, "BaseVehicle") then return object end
        local square = object:getSquare()
        local vehicle = square and square:getVehicleContainer()
        if vehicle then return vehicle end
    end
    return nil
end

local function addWorldMenu(playerNum, context, worldobjects, test)
    if test then return end

    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() or player:getVehicle() then return end

    local vehicle = vehicleFrom(worldobjects)
    if not vehicle then return end

    local ok, err = pcall(addTrainOption, context, player, vehicle)
    if not ok then print("[AutoAll] mechanics menu error: " .. tostring(err)) end
end

AA.registerMenu("mechanics", Events.OnFillWorldObjectContextMenu, addWorldMenu)

---------------------------------------------------------------------
-- and from inside the mechanics window
---------------------------------------------------------------------

-- Mods load after the base game, so this is normally already there. The
-- guard is for the case where it is not: an error at load time would take
-- the whole module down with it, and losing the window entry is a lot
-- better than losing the world entry as well.
if not ISVehicleMechanics then
    print("[AutoAll] ISVehicleMechanics not found - the mechanics window entry is disabled.")
elseif not AA.mechUIHooked then
    AA.mechUIHooked = true

---------------------------------------------------------------------
-- Naming the mod that breaks the mechanics menu
--
-- Reported by KeirosDragon as an Auto All conflict with that DAMN
-- Library: an error every time any part is right clicked in the
-- mechanics window. The stack was
--
--     Lua(Vanilla).doPartContextMenu(ISVehicleMechanics.lua:223)
--     Lua(MOD Auto All BETA).doPartContextMenu(AutoAll_Mechanics.lua:1621)
--     Lua(Vanilla).onListRightMouseUp(ISVehicleMechanics.lua:202)
--
-- Read bottom up, that is vanilla calling our wrapper calling vanilla,
-- and the throw is in the deepest frame - vanilla's own function. Our
-- line is the pcall around it. We are in the trace because we are the
-- caller, which is why the mod gets the blame.
--
-- ISVehicleMechanics.lua:223 is
--
--     local fixingList = FixingManager.getFixes(part:getInventoryItem())
--
-- and FixingManager.getFixes is, in full bytecode, a loop over every
-- Fixing script doing
--
--     fixing.getRequiredItem().contains(item.getFullType())
--
-- There is exactly one way that throws: a Fixing script whose Require
-- list did not parse, leaving getRequiredItem() null. It then throws for
-- EVERY part with an inventory item, in any mod, with or without this
-- one installed.
--
-- damnlib's own eight fixing blocks all declare Require correctly, so
-- the malformed one is in one of the KI5 vehicle mods that library
-- serves, not in the library itself.
--
-- Nothing here can repair someone else's script. What it can do is stop
-- the player having to guess: when the original throws, every Fixing
-- script is checked and the broken ones are named, once per session.
local reportedBadFixing = false

local function nameBrokenFixing()
    if reportedBadFixing then return end
    reportedBadFixing = true

    local broken = {}
    local checked = 0

    local ok = pcall(function()
        local all = getScriptManager():getAllFixing(ArrayList.new())
        if not all then return end
        for i = 0, all:size() - 1 do
            local fixing = all:get(i)
            if fixing then
                checked = checked + 1
                -- Both the nil and the throw are the same fault from the
                -- caller's side, so both are collected.
                local fine, required = pcall(function() return fixing:getRequiredItem() end)
                if not fine or required == nil then
                    local named, name = pcall(function() return fixing:getName() end)
                    broken[#broken + 1] = named and tostring(name) or "?"
                end
            end
        end
    end)

    if not ok then
        print("[AutoAll] mechanics: could not inspect the Fixing scripts")
        return
    end

    if #broken > 0 then
        print("[AutoAll] mechanics: " .. tostring(#broken) .. " of " .. tostring(checked)
                .. " Fixing scripts have no Require list, which is what makes"
                .. " vanilla's FixingManager.getFixes throw. This is not Auto All."
                .. " The broken script(s): " .. table.concat(broken, ", "))
    else
        print("[AutoAll] mechanics: all " .. tostring(checked)
                .. " Fixing scripts look well formed, so the error in vanilla's"
                .. " doPartContextMenu came from something else. Please report"
                .. " the full error text, not just the stack.")
    end
end

    local original_doPartContextMenu = ISVehicleMechanics.doPartContextMenu
    function ISVehicleMechanics:doPartContextMenu(part, x, y)
        -- The original is wrapped because it is not always ours to trust:
        -- a broken Fixing script from another vehicle mod throws in here,
        -- and an unguarded call would take our entry down with the rest of
        -- the menu. Better Auto Mechanics hit exactly this (their v1.22).
        local ok, result = pcall(original_doPartContextMenu, self, part, x, y)
        if not ok then
            print("[AutoAll] another mod errored building the mechanics menu: " .. tostring(result))
            -- Say WHICH mod, rather than leaving the player to guess from a
            -- stack trace that has our name in it. Once per session.
            nameBrokenFixing()
            result = nil
        end

        -- This entry is built from the vehicle window rather than from a
        -- context menu event, so it does not go through AA.registerMenu and
        -- has to ask about the switch itself.
        if AA.enabled("mechanics") and self.context and self.chr and self.vehicle then
            local ok, err = pcall(addTrainOption, self.context, self.chr, self.vehicle)
            if not ok then print("[AutoAll] mechanics menu error: " .. tostring(err)) end
        end

        return result
    end
end
