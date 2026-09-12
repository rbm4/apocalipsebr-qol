--[[
    Auto All - Cook, Tailoring and Reload (Build 42 / SP + MP)
    ------------------------------------------------------------------
    Shared runtime for the three automations.

    A player runs at most one task at a time. The task only decides what
    to do next while the vanilla timed action queue is idle, and every
    step it takes is a vanilla timed action, which is why XP, stiffness,
    animations, sounds and multiplayer sync are exactly the base game's.
]]

--[[
    2026-08-31, from KhaozNZ - diagnostics, merged from the Auto All
    (Fixed) fork, Workshop 3792445930. Thank you.

    A start line per job, so starts and stops pair up in console.txt, and a
    one-off "waiting on X" notice when an action holds the queue for longer
    than WAIT_NOTICE without its job delta moving.

    The notice exists because task.stallTimeout is deliberately long:
    clearing a queue is heavy-handed, so a job that sticks for ten seconds
    and is then rescued by the player reaching for the mouse never reached
    it and was invisible.

    Worth reading the note above FINISHED_DELTA before touching this. The
    obvious recovery - "job delta is 1.0 and the action is still at the
    head, so clear it" - was tried in that fork and reverted, because on a
    multiplayer client an ISInventoryTransferAction legitimately sits at
    1.0 while it waits for the server to confirm the move. It fired 1.8
    seconds into an Auto Sterilize gathering phase and threw away the
    alcohol it was fetching.
]]

require "AutoAll/AutoAll_Config"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.coreLoaded then return end
AA.coreLoaded = true

AA.tasks = AA.tasks or {}       -- [playerNum] = task

---------------------------------------------------------------------
-- the ten automations
--
-- AA.MODULES itself is defined in AutoAll_Config, which has to run first
-- because it builds the options panel from it. Everything that reads it
-- lives here.
---------------------------------------------------------------------

local MODULE = {}
for _, entry in ipairs(AA.MODULES or {}) do MODULE[entry.key] = entry end

--- Is this automation switched on?
---
--- Two switches, and both have to agree. The player's own tickbox decides
--- what they want to see; the sandbox option lets a server take a module
--- away from everyone. A server that never touches its sandbox option
--- changes nothing, because the default there is on as well.
---
--- Note this is the one place the mod is allowed to make an entry vanish
--- rather than grey it out. Design rule §2.5 is about an automation that
--- cannot run *right now* - a menu entry disappearing then reads as a
--- broken mod. An automation the player switched off should genuinely be
--- gone; leaving a greyed line behind for each of ten modules is the menu
--- clutter they asked to be rid of.
--- The sandbox override is a tri-state integer, and that is the fix for a
--- bug this very function caused.
---
---     -1  the server has no opinion (default)
---      0  forced off for everyone
---      1  forced on for everyone
---
--- It used to be a boolean, and a boolean cannot tell "the server has not
--- said anything" apart from "the server said no". On a save that predates
--- these options the value came back false, and six modules switched
--- themselves off for a player who had never touched them - while
--- ModOptions.ini still read `true` for all ten. That is the "the options
--- just disappear" and "works in a new world but not my old save" report,
--- and it was this line.
---
--- Anything that is not exactly 0 or 1 is now ignored rather than obeyed,
--- so a missing, stale or garbage value cannot silently disable anything.
local function sandboxOverride(entry)
    if not (SandboxVars and SandboxVars.AutoAll) then return nil end

    local value = SandboxVars.AutoAll[entry.sandbox]
    if value == 0 then return false end
    if value == 1 then return true end
    return nil
end

function AA.enabled(key)
    local entry = MODULE[key]
    if not entry then return true end

    local forced = sandboxOverride(entry)
    if forced ~= nil then
        -- Said out loud, once per session per module. A server switching a
        -- module off is a legitimate thing to do and an impossible thing to
        -- diagnose from the client without a line in the log.
        if not entry.loggedOverride then
            entry.loggedOverride = true
            print("[AutoAll] " .. key .. ": server sandbox forces it "
                    .. (forced and "on" or "off"))
        end
        return forced
    end

    return AA.opt(entry.option) ~= false
end

local iconCache = {}

--- The context menu icon for an automation, or nil.
--- Looked up once: getTexture goes to the texture manager every call.
function AA.icon(key)
    local entry = MODULE[key]
    if not entry or not entry.icon then return nil end

    if iconCache[key] == nil then
        local ok, texture = pcall(getTexture, entry.icon)
        iconCache[key] = (ok and texture) or false
    end
    return iconCache[key] or nil
end

--- Registers a module's context menu handler.
---
--- Replaces a bare Events.X.Add(fn) and earns three things for the one
--- line: the handler is skipped entirely when the module is switched off,
--- every option it adds is stamped with that module's icon without the
--- module having to know, and it runs inside a pcall - so one automation
--- erroring cannot take the other nine out of the menu with it, which is
--- exactly what Better Auto Mechanics had to fix in their v1.22.
--- `key` may be a list, for a handler that serves more than one
--- automation - tailoring and repair share a menu and switch off
--- separately. The handler then runs while *any* of them is on, and each
--- entry inside is responsible for asking about its own.
function AA.registerMenu(key, event, handler)
    local keys = type(key) == "table" and key or { key }

    event.Add(function(...)
        local active = nil
        for _, name in ipairs(keys) do
            if AA.enabled(name) then
                active = name
                break
            end
        end
        if not active then return end

        local previous = AA.currentModule
        AA.currentModule = active
        local ok, err = pcall(handler, ...)
        AA.currentModule = previous

        if not ok then
            print("[AutoAll] " .. tostring(active) .. " menu error: " .. tostring(err))
        end
    end)
end

local THINK_INTERVAL = 250      -- ms between two decisions
local START_GRACE    = 1200     -- ms of "manual input" ignored after a task starts

---------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------

local function now()
    return getTimestampMs()
end
AA.now = now

function AA.getQueue(player)
    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    return queue and queue.queue or nil
end

function AA.currentAction(player)
    local queue = AA.getQueue(player)
    return queue and queue[1] or nil
end

function AA.isQueueBusy(player)
    local queue = AA.getQueue(player)
    return queue ~= nil and #queue > 0
end

function AA.getTask(player)
    return AA.tasks[player:getPlayerNum()]
end

--- Finds an item of this type anywhere on the character, bags included.
---
--- `getItemFromType(type, true, true)` is what the vanilla clothing window
--- uses (ISGarmentUI.lua:180-184) and what this mod copied - but the two
--- booleans are not "search bags". The three argument form delegates to
--- the five argument one with `false` for the last flag, and a separate
--- `getItemFromTypeRecurse` exists precisely because that one does not
--- recurse. So a needle, a spool of thread or a pile of rags inside a
--- backpack reads as "you do not have one", which is the "the mod says I
--- have no tool when it is right there in my inventory" report.
---
--- The vanilla call is still tried first, so the item it would have picked
--- is still the item picked - the recursive sweep is only a fallback when
--- that finds nothing. It can only ever find more, never fewer, and it
--- changes nothing about what is then consumed.
function AA.findItem(player, itemType)
    if not player or not itemType then return nil end

    local inventory = player:getInventory()
    if not inventory then return nil end

    local ok, found = pcall(function()
        return inventory:getItemFromType(itemType, true, true)
    end)
    if ok and found then return found end

    local deep, recursed = pcall(function()
        return inventory:getFirstTypeRecurse(itemType)
    end)
    return (deep and recursed) or nil
end

--- The tag equivalent of AA.findItem, with the same reasoning.
function AA.findItemByTag(player, tag)
    if not player or not tag then return nil end

    local inventory = player:getInventory()
    if not inventory then return nil end

    local ok, found = pcall(function()
        return inventory:getItemFromTag(tag, true, true)
    end)
    if ok and found then return found end

    local deep, recursed = pcall(function()
        return inventory:getFirstTagRecurse(tag)
    end)
    return (deep and recursed) or nil
end

--- Does the character have this item anywhere on them?
---
--- `getInventory():contains(item)` is **not** the answer, and every module
--- used it as if it were. Disassembled, it is one line:
---
---     return this.items.contains(item);      // ArrayList.contains
---
--- - the main inventory only, and by object identity. So anything in a
--- backpack reads as "the player does not have it". That is what stopped
--- Train Tailoring on every garment except the one being worn (worn items
--- live in the main inventory), and what stopped Auto Cook returning
--- ingredients that had been put in a bag.
---
--- `containsRecursive` walks the bags. The id lookup after it covers the
--- multiplayer case where the instance was replaced as a transfer settled
--- and the object no longer matches by identity.
function AA.holds(player, item)
    if not player or not item then return false end

    local inventory = player:getInventory()
    if not inventory then return false end

    local ok, found = pcall(function() return inventory:containsRecursive(item) end)
    if ok and found == true then return true end

    local byId, resolved = pcall(function() return inventory:getItemById(item:getID()) end)
    return byId and resolved ~= nil
end

--- True when this player is already running an automation (of `kind`, if given).
function AA.isRunning(player, kind)
    local task = AA.tasks[player:getPlayerNum()]
    if not task or not task.active then return false end
    return kind == nil or task.kind == kind
end

---------------------------------------------------------------------
-- messages
---------------------------------------------------------------------

function AA.say(task, text, bad)
    local mode = AA.opt("notify")
    if mode == 3 or not text or not task or not task.player then return end

    -- Say() only draws a chat bubble, it does not emit a world sound, so it
    -- will not attract zombies.
    if mode == 2 then
        task.player:Say(text)
        return
    end

    -- Same overloads the base game uses for halo text.
    local ok = pcall(function()
        if bad then
            HaloTextHelper.addBadText(task.player, text)
        else
            HaloTextHelper.addGoodText(task.player, text, "[br/]")
        end
    end)
    if not ok then
        task.player:Say(text)
    end
end

--- Same message is only repeated every "notifyEvery" seconds.
function AA.reason(task, text)
    local every = (AA.opt("notifyEvery") or 20) * 1000
    if task.lastReason == text and now() - (task.lastReasonAt or 0) < every then return end
    task.lastReason = text
    task.lastReasonAt = now()
    AA.say(task, text, false)
end

---------------------------------------------------------------------
-- game speed (single player only - the server owns game speed in MP)
---------------------------------------------------------------------

-- Vanilla drives the speed with TWO calls, always paired. Straight from
-- SpeedControlsHandler.onKeyPressed:
--
--     setGameSpeed(1); getGameTime():setMultiplier(1)     -- normal
--     setGameSpeed(2); getGameTime():setMultiplier(5)     -- fast forward 1
--     setGameSpeed(3); getGameTime():setMultiplier(20)    -- fast forward 2
--     setGameSpeed(4); getGameTime():setMultiplier(40)    -- fast forward 3
--
-- So setGameSpeed takes the button SLOT, 0 to 4. It is not a multiplier,
-- and on its own it does not change how fast time runs at all.
--
-- This module used to pass multipliers - {1, 2, 3, 5} - and never touched
-- getGameTime() at all. The "5x" setting therefore called setGameSpeed(5),
-- which is not a slot that exists, and none of the settings ever moved the
-- clock. That is the whole of the "the speed config does not work" report.
--
-- option index -> { slot, multiplier }
local SPEEDS = {
    [2] = { 2, 5 },
    [3] = { 3, 20 },
    [4] = { 4, 40 },
}

local function canChangeSpeed()
    return not isClient() and not isServer()
end

local function currentSlot()
    local ok, slot = pcall(getGameSpeed)
    if ok and type(slot) == "number" then return slot end
    return nil
end

local function setSpeed(slot, multiplier)
    pcall(function()
        setGameSpeed(slot)
        getGameTime():setMultiplier(multiplier)
    end)
end

--- Takes the game speed up, once, and then leaves the player alone.
---
--- The second half of the same report was "the mod keeps preventing me
--- from manually setting a faster game speed" - because this ran on every
--- think tick and wrote the configured speed back over whatever had just
--- been chosen. Now it only ever re-applies a speed it set itself and
--- that nobody has touched since; the first manual change stands the mod
--- down for the rest of the job.
function AA.applySpeed(task)
    if not canChangeSpeed() then return end
    if task.speedGaveUp then return end

    local wanted = SPEEDS[AA.opt("fastForward") or 1]
    if not wanted then return end

    local slot = currentSlot()
    if slot == nil then return end

    if task.speedHeld then
        -- Still ours? If the slot is no longer the one we set, the player
        -- moved it. Hands off for the rest of this job.
        if slot ~= wanted[1] then
            task.speedHeld   = false
            task.speedGaveUp = true
            task.speedFollow = true
        end
        return
    end

    -- Only ever taken from a standing start. Anything else is the player's
    -- choice: a faster speed they picked, or a pause (slot 0) that we must
    -- never quietly undo.
    if slot ~= 1 then
        task.speedGaveUp = true
        -- Their speed, not ours - so it is never written to. But vanilla's
        -- reset would knock it back to normal after the job's first action
        -- and keep doing it, which reads as the mod refusing to let them
        -- speed the game up. Standing down means not writing the speed, not
        -- letting something else undo what they chose while our job runs.
        task.speedFollow = true
        return
    end

    setSpeed(wanted[1], wanted[2])
    task.speedHeld = true

    -- Disarmed here as well as on every tick, and this one closes a real
    -- gap: the latch may already be set from an action the player ran
    -- before the job started, in which case vanilla would reset the speed
    -- on the very next tick - possibly before holdGameSpeed gets a turn -
    -- and the next think would read that as the player overriding us.
    if ISTimedActionQueue then
        ISTimedActionQueue.shouldResetGameSpeed = false
    end
end

function AA.releaseSpeed(task)
    if not canChangeSpeed() then return end
    if not task.speedHeld then return end
    task.speedHeld = false
    setSpeed(1, 1)
end

---------------------------------------------------------------------
-- and the reason the speed would not stay up
--
-- ISTimedActionQueue.lua:284-304 runs on OnTick:
--
--     if not getCore():getOptionTimedActionGameSpeedReset() then return end
--     ...
--     if isDoingAction then
--         ISTimedActionQueue.shouldResetGameSpeed = true
--     elseif ISTimedActionQueue.shouldResetGameSpeed then
--         ISTimedActionQueue.shouldResetGameSpeed = false
--         if UIManager.getSpeedControls():getCurrentGameSpeed() > 1 then
--             UIManager.getSpeedControls():SetCurrentGameSpeed(1)
--         end
--     end
--
-- "Reset game speed when a timed action ends" is a vanilla option and it is
-- on by default. It fires the moment the action queue goes idle - and every
-- automation in this mod is idle between rounds by design, because think()
-- only decides the next step once the queue has drained. Auto Mechanics is
-- the worst case: one part per cycle plus a 400 ms settle window, so the
-- speed was reset after literally every part.
--
-- That is three separate reports, all the same line of vanilla:
--   * "after each successful or unsuccessful action, time rewinding stops"
--   * "each time a progress bar finishes the speed goes back to normal"
--   * "the mod does not speed up the game and fights me when I speed it up"
--
-- The third one was ours making it worse: applySpeed saw the slot it had
-- set replaced by 1, concluded the *player* had moved it, and stood down
-- for the rest of the job (task.speedGaveUp). One queue gap and fast
-- forward was dead until the next job.
--
-- So the latch is disarmed every tick while a job is holding the speed.
-- The player's option is not touched, nothing else in the game changes,
-- and it stops as soon as the job does. Clearing it every tick makes this
-- independent of whether our handler runs before or after vanilla's: the
-- flag can never survive from one tick into the next, which is the only
-- way the reset branch is ever reached.
---------------------------------------------------------------------

local function holdGameSpeed()
    if not canChangeSpeed() then return end
    if not ISTimedActionQueue then return end

    for _, task in pairs(AA.tasks) do
        -- speedHeld  = a speed this mod set and still owns
        -- speedFollow = a speed the player set for themselves, which we do
        --               not write but do defend for the length of the job
        if task.active and (task.speedHeld or task.speedFollow) then
            ISTimedActionQueue.shouldResetGameSpeed = false
            return
        end
    end
end

---------------------------------------------------------------------
-- start / stop
---------------------------------------------------------------------

--- Registers and starts a task. `task` must carry:
---   player, kind, think(task) and optionally startText, onStop(task).
function AA.startTask(task)
    local player = task.player
    if not player then return false end

    if AA.isRunning(player) then
        AA.stop(player, getText("UI_AA_stop_replaced"), false)
    end

    task.playerNum  = player:getPlayerNum()
    task.active     = true
    task.startedAt  = now()
    task.cycles     = task.cycles or 0
    task.lastHealth = player:getBodyDamage():getOverallBodyHealth()
    task.nextThink  = 0

    AA.tasks[task.playerNum] = task

    -- Every job announces itself, so starts and stops pair up in the log.
    -- Without this a job that hangs writes nothing at all: AA.stop is the only
    -- thing that logs, and a job that never stops never reaches it. That is
    -- why "it sticks at 100% and I have to click away" could not be told apart
    -- from "the mod finished and something else wedged".
    print("[AutoAll] " .. tostring(task.kind) .. " started"
            .. (task.fullType and (" type=" .. tostring(task.fullType)) or " (everything in reach)"))

    AA.say(task, task.startText, false)
    AA.applySpeed(task)
    return true
end

function AA.stop(player, reason, bad)
    if not player then return end
    local playerNum = player:getPlayerNum()
    local task = AA.tasks[playerNum]
    if not task then return end

    AA.tasks[playerNum] = nil
    task.active = false
    AA.releaseSpeed(task)

    -- Every ending leaves a line, not just the ones a module reports on
    -- itself. A job that ends through checkSafety - zombies, damage, a
    -- movement key, ESC - used to leave console.txt completely empty, so a
    -- run that stopped early and a run that never ended looked identical in
    -- the log. They need different fixes, so they have to be told apart.
    print("[AutoAll] " .. tostring(task.kind) .. " stopped: " .. tostring(reason))

    -- A running automation owns the player's action queue, so stopping it
    -- clears that queue - unless the task opts out with
    -- clearQueueOnStop = false. It used to be the other way round, opt-in,
    -- which meant a stopped job carried on working through whatever it had
    -- already queued.
    --
    -- Cleared *before* onStop, not after, so a task whose onStop queues its
    -- own cleanup - putting borrowed ingredients back, say - does not have
    -- that cleanup wiped by the very clear that was meant to cancel the
    -- abandoned work.
    --
    -- From Mickey's maintenance fork (Workshop 3781695662).
    if task.clearQueueOnStop ~= false then
        pcall(function() ISTimedActionQueue.clear(player) end)
    end
    if task.onStop then
        pcall(task.onStop, task)
    end
    if reason then
        AA.say(task, reason, bad ~= false)
    end
end

--- Stops whatever is running for every local player. Used by the ESC hook.
function AA.stopAll(reason, bad)
    for playerNum, task in pairs(AA.tasks) do
        if task.player then
            AA.stop(task.player, reason, bad)
        else
            AA.tasks[playerNum] = nil
        end
    end
end

---------------------------------------------------------------------
-- safety
---------------------------------------------------------------------

--- True when the character is carrying more than it is rated for.
function AA.isOverloaded(player)
    local ok, over = pcall(function()
        return player:getInventoryWeight() > player:getMaxWeight()
    end)
    return ok and over == true
end

--- True when the health this task is losing is the weight it is carrying,
--- and the task said in advance that it expects to be carrying it.
---
--- The health check exists to catch a zombie chewing on you. Carrying too
--- much also costs health, through muscle strain, and that is a problem
--- for exactly one job: a mechanic working round a car is holding a tyre,
--- a brake, a screwdriver, a wrench, a lug wrench and a jack, and there is
--- no strength or fitness level at which that is light. Worse, the drift
--- is slow in game time but the safety check runs on real time, so at 5x
--- fast forward a tick covers enough strain to look like a wound.
---
--- Zombies are still covered: stopZombie is a separate check, it runs
--- first, and it is on by default.
--- Below this the body is genuinely in trouble and no task's opinion about
--- its own workload outranks that.
---
--- getOverallBodyHealth() is 0-100. Muscle strain from an overloaded
--- inventory does real, accumulating damage, and allowHeavy used to waive
--- the damage stop outright - which is how a mechanics run carried a
--- character at three times their limit until it killed them. Being heavy
--- is still not a reason to stop; being heavy and hurt is.
local HEALTH_FLOOR = 70

local function carryingItOff(task, health)
    if task.allowHeavy ~= true then return false end
    if not AA.isOverloaded(task.player) then return false end
    return health >= HEALTH_FLOOR
end

--- True when this task said in advance that the health it is watching go
--- down is the thing it was started to deal with.
---
--- One job needs this and it needs it badly. Auto Medicine treats an open
--- wound, an open wound bleeds, and bleeding is overall body health going
--- down every tick - so "stop when taking damage" fired on the first
--- think and the treatment never got past its first step. Reported by
--- Barbiehunter: *"it always stops with the Message of stopping, of
--- taking damage. This is quiet confusing, as that's the whole Point
--- about it is to fix the damage"*, and they are right.
---
--- This is not the same as ignoreDamage. A task setting this hook stays
--- responsible for deciding what damage is still worth stopping for -
--- Auto Medicine stops the instant a part is bitten or scratched, which
--- is something attacking the character rather than the wound it is
--- already treating.
local function expectedDamage(task)
    if type(task.expectedDamage) ~= "function" then return false end
    local ok, expected = pcall(task.expectedDamage, task)
    return ok and expected == true
end

--- Returns a message when the task must end, nil otherwise.
function AA.checkSafety(task)
    local player = task.player

    if player:isDead() then return getText("UI_AA_stop_generic") end

    if AA.opt("stopZombie") then
        local stats = player:getStats()
        if stats:getNumVisibleZombies() > 0 or stats:getNumChasingZombies() > 0
                or stats:getNumVeryCloseZombies() > 0 then
            return getText("UI_AA_stop_zombie")
        end
    end

    local health = player:getBodyDamage():getOverallBodyHealth()
    local damaged = health < (task.lastHealth or health) - 0.05
    task.lastHealth = health

    -- ignoreDamage tasks never stop for health at all. Asked for
    -- explicitly, twice, for Auto Mechanics: a mechanic is carrying a
    -- tyre, a brake and four tools, that is the job rather than a danger
    -- signal, and the muscle strain it costs kept reading as a wound.
    --
    -- What keeps a character alive is no longer this check. It is that the
    -- mechanics job now sheds weight the moment it is overloaded - a part
    -- that cannot go back on this turn goes on the ground - so the strain
    -- never builds. Zombies, movement and ESC still stop everything.
    if not task.ignoreDamage then
        if health < HEALTH_FLOOR and AA.isOverloaded(player) then
            return getText("UI_AA_stop_hurt")
        end
        if AA.opt("stopDamage") and damaged
                and not carryingItOff(task, health)
                and not expectedDamage(task) then
            return getText("UI_AA_stop_damage")
        end
    end

    if now() - (task.startedAt or 0) > START_GRACE then
        if AA.opt("stopOnMove") then
            -- A movement key is always the player taking over. Actually moving
            -- only counts when the task does not walk around by itself (auto
            -- cooking fetches ingredients from counters and fridges).
            if player:pressedMovement(false) then
                return getText("UI_AA_stop_manual")
            end
            if not task.allowMove and player:isPlayerMoving() then
                return getText("UI_AA_stop_manual")
            end
        end
        if AA.opt("stopOnAim") and (player:isAiming() or player:pressedAim()) then
            return getText("UI_AA_stop_manual")
        end
        if player:pressedCancelAction() then
            return getText("UI_AA_stop_manual")
        end
    end

    return nil
end

---------------------------------------------------------------------
-- a queue that never drains
--
-- Every task uses the same heartbeat: decide nothing while the timed
-- action queue is busy. That is what keeps the automations in step with
-- the base game, and it has one failure mode - an action that never ends
-- freezes the task in total silence. think() returns on every tick, no
-- message is ever shown, and nothing is written to the log.
--
-- It is reachable from vanilla. ISPathFindAction is built with
-- maxTime = -1 and an isValid() that returns true unconditionally, and
-- ISTimedActionQueue:tick() only recovers from an action whose
-- action:hasStalled() is true. A path that neither arrives nor reports
-- failure sits at the head of the queue indefinitely.
--
-- Opt-in per task via task.stallTimeout, because a long single action is
-- perfectly normal elsewhere - reading a book is minutes of one action,
-- and clearing that queue would be the bug rather than the fix.
---------------------------------------------------------------------

---------------------------------------------------------------------
-- how big a batch a server may be trusted with
--
-- ISHandcraftAction:isValid() checks the craft bench and that a recipe
-- exists. It never checks whether the inputs are still there. So a batch
-- queued in one tick is validated once, against the inventory as it
-- looked before any of it ran, and every action in it completes whether
-- or not there is anything left to consume. In single player that never
-- shows, because the inventory is consistent the instant an action ends;
-- on a client transfers settle asynchronously and the plan is made
-- against a stale view. That is output without input.
--
-- The fix was one craft per round on a client, confirmed before the next
-- was queued. Correct, but it turned a looted wardrobe into an afternoon.
--
-- So the batch earns its size now. It starts at one; a round where the
-- game confirms it consumed every input doubles it; a round that leaves
-- anything behind drops it straight back to one. A server keeping up
-- reaches the cap in three rounds. A server that is not never gets above
-- one, which is exactly the safe behaviour it had before - and the
-- confirmation deciding this is the same one each job already uses to
-- count its own work, so nothing new has to be trusted.
---------------------------------------------------------------------

AA.BATCH_MAX_CLIENT = 8

--- How many crafts this round may queue, or nil for "no cap".
function AA.batchSize(task)
    if not isClient() then return nil end
    return task.batchSize or 1
end

--- Reports a finished round back. `queued` is how many crafts went out,
--- `confirmed` how many of them the game actually consumed.
function AA.batchFeedback(task, queued, confirmed)
    if not isClient() then return end

    if queued > 0 and confirmed >= queued then
        task.batchSize = math.min((task.batchSize or 1) * 2, AA.BATCH_MAX_CLIENT)
    else
        task.batchSize = 1
    end
end

--- True when the same action has held the head of the queue for longer
--- than the task allows.
-- How long an action may hold the queue before it is worth a log line.
--
-- Deliberately short. Nobody watches a stuck bar for thirty seconds: a player
-- cancels a stalled action after about five, so a notice that arrives later
-- than that describes something the player already gave up on.
local WAIT_NOTICE = 2500

-- An action whose bar is full but which has not finished.
--
-- This REPORTS ONLY. It used to clear the queue, and that was wrong.
--
-- The reasoning was that a job delta of 1.0 means the work is done, so an
-- action still at the head a moment later must be stuck, and that a walk
-- never sits at 1.0 while queued. The walk part is true. The conclusion was
-- not: on a multiplayer client an ISInventoryTransferAction legitimately
-- sits at 1.0 while it waits for the server to confirm the move.
--
-- So this fired 1.8 seconds into an Auto Sterilize gathering phase, cleared
-- the queue, and the alcohol it was fetching never arrived - which the job
-- then correctly reported as "not enough rubbing alcohol within reach". A
-- recovery that breaks a working job is worse than the hang it was aimed at.
--
-- Until there is evidence of which action actually wedges, and for how long,
-- this only writes a line. The blunt stallTimeout remains the only thing
-- allowed to clear a queue.
local FINISHED_DELTA = 0.99
local DONE_GRACE     = 3000

-- How long a job delta must sit unchanged before the action counts as not
-- progressing. Comfortably more than one THINK_INTERVAL.
local STALLED_DELTA_WINDOW = 2000

--- Is the head action's progress bar actually moving?
---
--- The first version of the wait notice fired on time alone, and a healthy
--- dismantle takes longer than the threshold, so it reported every normal
--- craft as a wait. A line that fires when nothing is wrong is worse than no
--- line: it is what made a working job look broken in the log.
---
--- Slow and stuck are different, and the delta says which.
function AA.actionIsProgressing(task)
    local head = AA.currentAction(task.player)
    if not head then return false end

    local ok, delta = pcall(function() return head:getJobDelta() end)
    if not ok or type(delta) ~= "number" then return true end  -- unreadable: assume fine

    if task.lastDelta == nil or delta > task.lastDelta + 0.001 then
        task.lastDelta, task.deltaSince = delta, now()
        return true
    end

    -- Unchanged since the last sample is not evidence. Samples are one
    -- THINK_INTERVAL apart, which is 250ms, and a job delta does not
    -- necessarily move on that timescale - which is why this reported every
    -- healthy five second craft as a wait. Only a delta that has not budged
    -- for a sustained stretch means anything.
    return now() - (task.deltaSince or now()) < STALLED_DELTA_WINDOW
end

function AA.queueStalled(task)
    if not task.stallTimeout then return false end

    if not AA.isQueueBusy(task.player) then
        task.queueHead, task.queueSince = nil, nil
        task.waitNoticed, task.lastDelta, task.deltaSince = nil, nil, nil
        return false
    end

    -- Identity, not elapsed time alone: a queue working steadily through a
    -- dozen actions is not stalled, however long the whole run takes.
    local head = AA.currentAction(task.player)
    if head ~= task.queueHead then
        task.queueHead, task.queueSince = head, now()
        task.waitNoticed, task.lastDelta, task.deltaSince = nil, nil, nil
        return false
    end

    return now() - (task.queueSince or now()) > task.stallTimeout
end

---------------------------------------------------------------------
-- main loop
---------------------------------------------------------------------

local function onPlayerUpdate(player)
    if not player or not instanceof(player, "IsoPlayer") or not player:isLocalPlayer() then return end

    local task = AA.tasks[player:getPlayerNum()]
    if not task or not task.active then return end
    if now() < (task.nextThink or 0) then return end
    task.nextThink = now() + THINK_INTERVAL
    task.player = player

    local stopReason = AA.checkSafety(task)
    if stopReason then
        AA.stop(player, stopReason, true)
        return
    end

    -- One line the first time an action holds the queue for a noticeable
    -- while. task.stallTimeout is deliberately long, because clearing a queue
    -- is a heavy-handed recovery - but a job that sticks for ten seconds and
    -- is then rescued by the player reaching for the mouse never reaches it,
    -- and so was invisible. This is cheap: once per action, not per tick.
    if task.queueSince and not task.waitNoticed
            and AA.isQueueBusy(player)
            and now() - task.queueSince > WAIT_NOTICE
            and not AA.actionIsProgressing(task) then
        local waiting = AA.currentAction(player)
        task.waitNoticed = true

        -- Say whether the bar is full, because "slow" and "finished but not
        -- letting go" point at different causes. Reported, never acted on:
        -- see the note on DONE_GRACE.
        local full = false
        if waiting then
            local ok, delta = pcall(function() return waiting:getJobDelta() end)
            full = ok and type(delta) == "number" and delta >= FINISHED_DELTA
        end

        print("[AutoAll] " .. tostring(task.kind) .. ": waiting on '"
                .. tostring(waiting and waiting.Type or "?") .. "' for "
                .. tostring(math.floor((now() - task.queueSince) / 1000)) .. "s"
                .. ", phase=" .. tostring(task.phase)
                .. (full and " (bar full, action not finishing)" or ""))
    end

    if AA.queueStalled(task) then
        local head = AA.currentAction(player)
        task.stalls = (task.stalls or 0) + 1
        print("[AutoAll] " .. tostring(task.kind) .. ": action '"
                .. tostring(head and head.Type or "?") .. "' "
                .. "held the queue for " .. tostring(task.stallTimeout) .. "ms"
                .. " - clearing it (stall " .. tostring(task.stalls)
                .. ", phase=" .. tostring(task.phase) .. ")")

        pcall(function() ISTimedActionQueue.clear(player) end)
        task.queueHead, task.queueSince = nil, nil

        -- Clearing it once is a recovery. Doing it over and over means the
        -- task cannot make progress, and grinding on silently is exactly
        -- the behaviour being fixed here.
        if task.stalls >= (task.maxStalls or 3) then
            AA.stop(player, getText("UI_AA_stop_stuck"), true)
            return
        end
    end

    AA.applySpeed(task)

    local ok, err = pcall(task.think, task)
    if not ok then
        print("[AutoAll] task error: " .. tostring(err))
        AA.stop(player, getText("UI_AA_stop_error"), true)
    end
end

local function onPlayerDeath(player)
    if player then
        AA.stop(player, nil)
    end
end

local function onKeyPressed(key)
    if key == Keyboard.KEY_ESCAPE and AA.opt("stopOnEsc") then
        AA.stopAll(getText("UI_AA_stopped"), false)
    end
end

---------------------------------------------------------------------
-- context menu placement
--
-- Every automation adds its entry through AA.addOption, which tags the
-- option so it can be found again, and a single pass afterwards lifts
-- all of them to the top of the menu.
--
-- ISContextMenu:addOptionOnTop exists, but each call puts itself in
-- front of the last one, so using it in every module would list the
-- automations in reverse. Adding them normally and reordering once
-- keeps them in a fixed, predictable order instead.
--
-- The reordering pass is registered from OnGameStart rather than at
-- load: event handlers run in the order they were added, so this way it
-- runs after every module has had its say.
---------------------------------------------------------------------

--- Adds a context menu option and marks it as one of ours.
function AA.addOption(context, name, target, onSelect, param1, param2, param3, param4)
    local option = context:addOption(name, target, onSelect, param1, param2, param3, param4)
    if option then
        option.autoAllOption = true

        -- The icon comes from whichever module's handler is running, so no
        -- module has to name its own. A module that sets one explicitly -
        -- mechanics does, because it also builds its entry from the vehicle
        -- window, outside any handler - keeps it.
        if not option.iconTexture and AA.currentModule then
            option.iconTexture = AA.icon(AA.currentModule)
        end
    end
    return option
end


local function liftOurOptions(_, context, _, test)
    -- Exposed as AA.liftOptions below: the Health window builds its menu
    -- through ISHealthPanel:doBodyPartContextMenu, not through either of the
    -- two events this is registered on, so Auto Medicine has to run the
    -- same pass by hand.

    if test then return end
    if not context or not context.options then return end

    local ours, theirs = {}, {}
    for _, option in ipairs(context.options) do
        if option.autoAllOption then
            table.insert(ours, option)
        else
            table.insert(theirs, option)
        end
    end

    if #ours == 0 or #theirs == 0 then return end

    -- Options carry their own index in .id, so both the table and the
    -- ids have to be rebuilt for the menu to draw in the new order.
    local rebuilt, n = {}, 0
    for _, list in ipairs({ ours, theirs }) do
        for _, option in ipairs(list) do
            n = n + 1
            option.id = n
            rebuilt[n] = option
        end
    end

    context.options = rebuilt
end

--- The ordering pass, for a menu that is not one of the two events.
---
--- Every automation except Auto Medicine hangs off
--- OnFillInventoryObjectContextMenu or OnFillWorldObjectContextMenu,
--- and installMenuOrdering below covers both. The Health window is
--- neither: ISHealthPanel builds its own context menu directly, so a
--- module hooking that has to call this itself or its entry lands at
--- the bottom of a menu with thirteen vanilla options above it.
function AA.liftOptions(context)
    liftOurOptions(nil, context, nil, nil)
end

local function installMenuOrdering()
    Events.OnFillInventoryObjectContextMenu.Add(liftOurOptions)
    Events.OnFillWorldObjectContextMenu.Add(liftOurOptions)
end

---------------------------------------------------------------------
-- load report
--
-- Players reporting "I don't see any options" have no way of telling
-- whether the mod failed to load, loaded but found nothing to offer, or
-- was never enabled. One line in console.txt settles it, and a missing
-- module name says exactly which file gave up.
---------------------------------------------------------------------

local MODULES = {
    { "cookLoaded",     "Cook"      },
    { "cookUILoaded",   "Cook menu" },
    { "readLoaded",     "Read"      },
    { "cleanLoaded",    "Clean"     },
    { "sterilizeLoaded","Sterilize" },
    { "dismantleLoaded","Dismantle" },
    { "ripLoaded",      "Rip"       },
    { "tailorLoaded",   "Tailoring" },
    { "mechLoaded",     "Mechanics" },
    { "reloadLoaded",   "Reload"    },
    { "vhsLoaded",      "VHS"       },
    { "medicineLoaded", "Medicine"  },
    { "openLoaded",     "Open"      },
    { "cookbookLoaded", "Cookbook"  },
    { "panelLoaded",    "Panel"     },
}

-- Auto Exercise is the bundled Muscle Manager, so its "did it load"
-- flag lives on that namespace instead of on AA. Kept out of the
-- MODULES table above rather than faked, because a table of AA flags
-- that quietly contains one that is not an AA flag is how a report
-- starts lying.
local function exerciseLoaded()
    return MuscleManager ~= nil and MuscleManager.coreLoaded == true
end

local function reportLoad()
    local ready, missing = {}, {}
    for _, entry in ipairs(MODULES) do
        table.insert(AA[entry[1]] and ready or missing, entry[2])
    end

    table.insert(exerciseLoaded() and ready or missing, "Exercise")

    print("[AutoAll] loaded: " .. table.concat(ready, ", "))
    if #missing > 0 then
        print("[AutoAll] NOT loaded: " .. table.concat(missing, ", "))
    end

    -- Loaded and switched on are different things now, and "I see no menu
    -- entry" is the report both of them produce. Say which is which.
    local off = {}
    for _, entry in ipairs(AA.MODULES) do
        if not AA.enabled(entry.key) then table.insert(off, entry.key) end
    end
    if #off > 0 then
        print("[AutoAll] switched off in options: " .. table.concat(off, ", "))
    end
    if SandboxVars and SandboxVars.AutoAll then
        print("[AutoAll] server sandbox options for AutoAll are present.")
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnPlayerDeath.Add(onPlayerDeath)
Events.OnKeyPressed.Add(onKeyPressed)
-- Every tick, not every think tick: vanilla's reset runs on OnTick and the
-- think loop only wakes every 250 ms, which is long enough for the reset to
-- land and be read back as a manual change.
Events.OnTick.Add(holdGameSpeed)
Events.OnGameStart.Add(installMenuOrdering)
Events.OnGameStart.Add(reportLoad)
