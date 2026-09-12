--[[
    Auto All - VHS (Build 42 / SP + MP)
    ------------------------------------------------------------------
    "Watch Every VHS": the character feeds a video player one tape after
    another, watches each programme all the way through, takes it out and
    puts the next one in.

    Only tapes that still teach something are picked up. A tape is worth
    watching when it has at least one line that

      * the character has not already heard (isKnownMediaLine), and
      * carries a skill code the character can still gain from, or a
        recipe code for a recipe they do not know.

    Tapes that only move a moodle - boredom, stress, panic, unhappiness -
    are ignored, which is what "ignore tapes that give no skill" means.

    Nothing here grants XP, learns a recipe or advances a tape. All of
    that is the base game's: the device plays its lines, the lines fire
    Events.OnDeviceText, and vanilla's ISRadioInteractions hands out the
    XP. This module only presses the same buttons the radio window's own
    media panel presses, in order, without the player having to.
]]

require "AutoAll/AutoAll_Core"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.vhsLoaded then return end
AA.vhsLoaded = true

AA.VHS = AA.VHS or {}
local VHS = AA.VHS

-- deviceData:getMediaType(): 0 is a CD player, 1 is a video player.
-- Straight out of RWMMedia:readFromObject.
local MEDIA_VHS = 1

-- How far a video player may be from the character for the menu entry to
-- offer itself. Kept close to the five tiles the media system itself uses
-- (playerInRange in ISRadioInteractions) - a machine further away than
-- this is one the character would have to cross a room to reach.
local SEARCH_RADIUS = 6

-- Real milliseconds a phase may wait for the device to answer before it
-- is tried again. Generous on purpose: on a client every one of these
-- state changes is a round trip to the server.
local STEP_TIMEOUT = 20000
local STEP_RETRIES = 3

-- Real milliseconds a single tape may take. This is a backstop for a
-- machine that stops answering, not a mechanism - a tape ends on its own
-- when DeviceData.updateMediaPlaying runs out of lines and calls
-- StopPlayMedia.
local WATCH_LIMIT = 15 * 60 * 1000

---------------------------------------------------------------------
-- what a tape can teach
--
-- The codes are read from ISRadioInteractions.lua, which is the file that
-- will actually run when a line plays. Its `Interactions` table is a
-- local, so it cannot be read at run time and the mapping is written out
-- here instead - every entry below is one that calls doSkill there.
--
-- Codes NOT in this table are the stat ones: ANG BOR END FAT FIT HUN MOR
-- STS PAN SAN SIC PAI DRU THI UHP. They move a moodle and teach nothing,
-- so a tape carrying only those is exactly the tape this module skips.
-- RCP is handled separately - it is a recipe, not a skill.
---------------------------------------------------------------------

local SKILL_CODES = {
    -- agility
    SPR = "Sprinting", LFT = "Lightfoot", NIM = "Nimble", SNE = "Sneak",
    -- blade / blunt
    BAA = "Axe", BUA = "Blunt",
    -- crafting
    CRP = "Woodwork", COO = "Cooking", FRM = "Farming", DOC = "Doctor",
    ELC = "Electricity", MTL = "MetalWelding", FKN = "FlintKnapping",
    CRV = "Carving",
    -- firearm
    AIM = "Aiming", REL = "Reloading",
    -- survivalist
    FIS = "Fishing", TRA = "Trapping", FOR = "PlantScavenging",
    -- the rest
    TAI = "Tailoring", MEC = "Mechanics", CMB = "Combat", SPE = "Spear",
    SBU = "SmallBlunt", LBA = "LongBlade", SBA = "SmallBlade",
    MAS = "Masonry", POT = "Pottery", BLA = "Blacksmith",
    GLA = "Glassmaking", HUS = "Husbandry", BUT = "Butchering",
    TRK = "Tracking",
}

-- Perks.X is looked up once per code and remembered. A perk this build
-- does not have resolves to nil and the code is then treated as one we
-- cannot judge, which keeps a future rename from erroring in a loop that
-- runs over every line of every tape.
local perkCache = {}

local function perkFor(code)
    local name = SKILL_CODES[code]
    if not name then return nil end

    if perkCache[code] == nil then
        local ok, perk = pcall(function() return Perks[name] end)
        perkCache[code] = (ok and perk) or false
    end
    return perkCache[code] or nil
end

--- The level at which media stops teaching a skill.
---
--- doSkill's first line is
---     if getPerkLevel(perk) >= SandboxVars.LevelForMediaXPCutoff then return
--- so a tape about a skill the character has already taken past the cutoff
--- is worth nothing at all. Reading it here is what keeps the module from
--- sitting a level 10 carpenter through a carpentry tape. Same shape as
--- Auto Read's "too simple" rule, and for the same reason: it is the base
--- game's own rule, not one of ours.
local function xpCutoff()
    local ok, value = pcall(function() return SandboxVars.LevelForMediaXPCutoff end)
    if ok and type(value) == "number" then return value end
    return 100      -- cannot see the sandbox: assume nothing is cut off
end

--- Splits "COO+1,BOR-1" the way ISRadioInteractions.split does.
local function splitCodes(text)
    local out = {}
    string.gsub(text, "([^,]+)", function(part) out[#out + 1] = part end)
    return out
end

--- True when this one code entry would give the character something.
---
--- Parsed exactly the way ISRadioInteractions.checkPlayer parses it,
--- because that is the function that will run when the line plays:
--- entries shorter than five characters are ignored, characters 1-3 are
--- the code, character 4 is the operator and the rest is the amount.
local function codeTeaches(player, entry)
    if string.len(entry) <= 4 then return false end

    local code = string.sub(entry, 1, 3)
    local op   = string.sub(entry, 4, 4)
    local rest = string.sub(entry, 5)

    if code == "RCP" then
        if rest == "" then return false end
        local ok, known = pcall(function() return player:isRecipeKnown(rest) end)
        -- A recipe we cannot ask about counts as unknown: the worst case
        -- is one tape watched for nothing, and the alternative is silently
        -- skipping tapes that do teach.
        return not (ok and known == true)
    end

    local perk = perkFor(code)
    if not perk then return false end       -- a stat code, or one we cannot judge

    local amount = tonumber(rest)
    if not amount then return false end

    -- checkPlayer negates the amount for "-", and doSkill drops anything
    -- that is not positive. So a "COO-1" teaches nothing.
    if op == "-" or amount <= 0 then return false end

    local ok, level = pcall(function() return player:getPerkLevel(perk) end)
    if ok and type(level) == "number" and level >= xpCutoff() then return false end

    return true
end

function VHS.isTape(item)
    if not item then return false end
    local ok, tape = pcall(function()
        return item:isRecordedMedia() and item:getMediaType() == MEDIA_VHS
    end)
    return ok and tape == true
end

--- nil when the tape has nothing left to teach, otherwise
--- { item, index, lines }, where `lines` counts the unheard lines that
--- still give something and `index` identifies the recording.
function VHS.appraise(player, item)
    if not VHS.isTape(item) then return nil end

    local ok, media = pcall(function() return item:getMediaData() end)
    if not ok or not media then return nil end

    local count = media:getLineCount() or 0
    local teaching = 0

    for i = 0, count - 1 do
        local line = media:getLine(i)
        if line then
            local guid = line:getTextGuid()
            -- A line with no guid is never written into the character's
            -- known list, so counting it would leave the tape "worth
            -- watching" for ever. Vanilla skips the bookkeeping for those
            -- too (checkPlayer only records a guid that is not empty).
            if guid and guid ~= "" and not player:isKnownMediaLine(guid) then
                local codes = line:getCodes()
                if codes and codes ~= "" then
                    for _, entry in ipairs(splitCodes(codes)) do
                        if codeTeaches(player, entry) then
                            teaching = teaching + 1
                            break
                        end
                    end
                end
            end
        end
    end

    if teaching == 0 then return nil end

    -- The recording's own index is what the tape is tracked by. A modded
    -- recording that cannot produce one would put nil in a table key and
    -- error the whole job, so the item type stands in for it - two tapes of
    -- the same type hold the same programme, which is all this is for.
    local ok, index = pcall(function() return media:getIndexForLua() end)
    if not ok or index == nil then index = item:getFullType() end

    return { item = item, index = index, lines = teaching }
end

---------------------------------------------------------------------
-- finding the tapes
---------------------------------------------------------------------

local function isRecordedPredicate(item)
    return item:isRecordedMedia()
end

local function scan(container, player, found, seen)
    if not container then return end

    local items = container:getAllEvalRecurse(isRecordedPredicate, ArrayList.new())
    if not items then return end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local id = item:getID()
        if not seen[id] then
            seen[id] = true
            local entry = VHS.appraise(player, item)
            if entry then table.insert(found, entry) end
        end
    end
end

--- Every tape within reach: the character's own inventory and bags, plus
--- the containers the loot window is showing.
function VHS.collect(player)
    local found, seen = {}, {}

    scan(player:getInventory(), player, found, seen)

    if AA.opt("vhsNearby") then
        local containers = ISInventoryPaneContextMenu.getContainers(player)
        if containers then
            for i = 0, containers:size() - 1 do
                scan(containers:get(i), player, found, seen)
            end
        end
    end

    return found
end

--- The next tape to put in, or nil.
---
--- Skipped by recording, not by item: two copies of the same tape hold the
--- same lines, so once one has been watched the other teaches nothing. It
--- is also the only identity that survives the machine - the item that
--- comes back out of the slot is a different object (see below).
function VHS.pickNext(task)
    local best = nil

    for _, entry in ipairs(VHS.collect(task.player)) do
        if not task.done[entry.index] and not task.failed[entry.index] then
            -- The tape the player actually right clicked goes in first.
            if task.first and entry.item:getID() == task.first then
                task.first = nil
                return entry
            end
            if best == nil or entry.lines > best.lines then best = entry end
        end
    end

    return best
end

---------------------------------------------------------------------
-- finding the machine
---------------------------------------------------------------------

local function deviceOn(square)
    if not square then return nil end
    local ok, data = pcall(function() return square:getDeviceData() end)
    if not ok then return nil end
    return data
end

--- The IsoObject on this square that owns the device.
---
--- Needed as well as the device data because ISRadioAction is built from
--- the object, while ISDeviceMediaAction is built from the square (see
--- ISDeviceBatteryAction:getDeviceDataParameter, which hands back
--- device:getSquare() for anything that is not an inventory item).
local function deviceObjectOn(square)
    local objects = square:getObjects()
    if not objects then return nil end

    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if instanceof(object, "IsoWaveSignal") and object:getDeviceData() then
            return object
        end
    end
    return nil
end

--- The nearest video player the character could use, or nil.
function VHS.findDevice(player)
    local cell = getCell()
    if not cell then return nil end

    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())

    local best, bestDist = nil, nil

    for dx = -SEARCH_RADIUS, SEARCH_RADIUS do
        for dy = -SEARCH_RADIUS, SEARCH_RADIUS do
            local square = cell:getGridSquare(px + dx, py + dy, pz)
            local data = deviceOn(square)
            if data and data:getMediaType() == MEDIA_VHS then
                local object = deviceObjectOn(square)
                if object then
                    local dist = dx * dx + dy * dy
                    if bestDist == nil or dist < bestDist then
                        best = { object = object, square = square }
                        bestDist = dist
                    end
                end
            end
        end
    end

    return best
end

--- Can this machine be switched on at all?
local function hasPower(data)
    if data:getIsTurnedOn() then return true end
    if data:getIsBatteryPowered() and data:getPower() > 0 then return true end
    return data:canBePoweredHere() == true
end

--- The five tile rule the media system itself applies.
---
--- ISRadioInteractions.playerInRange: same floor, and within five tiles on
--- both axes. Outside that the lines play to nobody and the tape is spent
--- for nothing, so the job stops rather than pretending to work.
local function inRange(player, square)
    if not square then return false end
    if math.floor(player:getZ()) ~= math.floor(square:getZ()) then return false end
    return math.abs(player:getX() - square:getX()) <= 5
       and math.abs(player:getY() - square:getY()) <= 5
end

---------------------------------------------------------------------
-- the tape that comes back out is a different item
--
-- DeviceData.removeMediaItem does not hand the original object back. It
-- builds a fresh one:
--
--     InventoryItemFactory.CreateItem(this.mediaItem)
--     item.setRecordedMediaIndex(this.mediaIndex)
--     container.AddItem(item)
--
-- (and on a client it does not even do that - the server makes the item
-- and syncs it). So the id that went in is gone, and the only way to
-- recognise what came out is that its id was not in the inventory a
-- moment ago.
---------------------------------------------------------------------

local function tapeIdsInMain(player)
    local ids = {}
    local inventory = player:getInventory()
    if not inventory then return ids end

    local items = inventory:getItems()
    if not items then return ids end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and VHS.isTape(item) then ids[item:getID()] = true end
    end
    return ids
end

local function ejectedTape(player, before)
    local inventory = player:getInventory()
    if not inventory then return nil end

    local items = inventory:getItems()
    if not items then return nil end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and VHS.isTape(item) and not before[item:getID()] then
            return item
        end
    end
    return nil
end

---------------------------------------------------------------------
-- the loop
--
-- Every other automation in this mod finishes a step when the timed
-- action queue drains. This one cannot: a tape plays out on the machine
-- over in game minutes with the character's queue empty the whole time.
-- So each phase asks the device whether it is done rather than asking the
-- queue, and the queue is only consulted to know when the character has
-- finished pressing a button.
--
--   insert -> hasMedia()          the tape is in the slot
--   play   -> isPlayingMedia()    the programme has started
--   watch  -> not isPlayingMedia()  it ran out of lines and stopped itself
--   eject  -> not hasMedia()      the slot is empty again
---------------------------------------------------------------------

local act        -- forward declaration: enter() calls it

local function enter(task, phase, data)
    task.phase = phase
    task.phaseAt = AA.now()
    task.tries = 0
    return act(task, data)
end

--- Walks the character back to the machine.
---
--- A no-op in the usual case: walkAdj returns true without queueing
--- anything when they are already within reach of it.
local function walkToDevice(task)
    return luautils.walkAdj(task.player, task.square, true) == true
end

--- Queues the work for the current phase. Returns "ok", "done" when there
--- is nothing left to watch, "nopower" when the machine cannot run, or
--- "unreachable" when the character cannot get back to it.
act = function(task, data)
    local player = task.player

    if task.phase == "insert" then
        local entry = VHS.pickNext(task)
        if not entry then return "done" end

        task.current = entry
        task.home = entry.item:getContainer()

        -- Fetching the tape can send the character across the room:
        -- transferIfNeeded goes through luautils.haveToBeTransfered, which
        -- calls walkToContainer. So the walk back to the machine has to be
        -- queued after it, not before - which is the order vanilla's own
        -- RWMMedia:addMediaAux uses for exactly this reason.
        ISInventoryPaneContextMenu.transferIfNeeded(player, entry.item)
        if not walkToDevice(task) then return "unreachable" end

        ISTimedActionQueue.add(ISDeviceMediaAction:new(player, false, entry.item, task.param))
        return "ok"
    end

    if task.phase == "play" then
        if not hasPower(data) then return "nopower" end
        if not walkToDevice(task) then return "unreachable" end

        if not data:getIsTurnedOn() then
            ISTimedActionQueue.add(ISRadioAction:new("ToggleOnOff", player, task.device))
            -- Remembered so a clean finish can put it back the way it was.
            task.turnedOn = true
        end

        -- TogglePlayMedia is a toggle. Queueing it while the machine is
        -- already playing would stop the tape, which is exactly what a
        -- retry would do on a client whose "it started" message arrived
        -- late.
        if not data:isPlayingMedia() then
            ISTimedActionQueue.add(ISRadioAction:new("TogglePlayMedia", player, task.device))
        end
        return "ok"
    end

    if task.phase == "eject" then
        if not walkToDevice(task) then return "unreachable" end
        task.tapesBefore = tapeIdsInMain(player)
        ISTimedActionQueue.add(ISDeviceMediaAction:new(player, true, nil, task.param))
        return "ok"
    end

    -- "watch" queues no work of its own, but the character still has to be
    -- standing by the machine: the media system only credits players within
    -- five tiles of it, so watching from across the room spends the tape
    -- for nothing.
    if not walkToDevice(task) then return "unreachable" end
    return "ok"
end

-- "eject" is missing on purpose: what follows it is bookkeeping (count the
-- tape, put it back) and only then another insert, so it is handled apart.
local NEXT_PHASE = {
    insert = "play",
    play   = "watch",
    watch  = "eject",
}

local function ready(task, data)
    if task.phase == "insert" then return data:hasMedia() end
    if task.phase == "play"   then return data:isPlayingMedia() end
    if task.phase == "watch"  then return not data:isPlayingMedia() end
    if task.phase == "eject"  then return not data:hasMedia() end
    return true
end

--- Ends the job, having watched everything there was to watch.
---
--- The machine is put back the way it was found from onStop, not here.
--- AA.stop clears the action queue *before* it calls onStop, so a toggle
--- queued at this point would be wiped by the very stop that follows it -
--- the same ordering Auto Cook's ingredient returns rely on.
local function finish(task)
    task.cleanFinish = true
    AA.stop(task.player, getText("UI_AA_vhs_done", task.watched), false)
end

--- Switches the machine off again, but only after a job that ran to the
--- end. A job that stopped for zombies, damage or ESC leaves everything
--- exactly as it stands: the player is dealing with something, and one
--- more queued action at that moment is the last thing they want.
local function onTaskStop(task)
    if not task.cleanFinish or not task.turnedOn then return end

    local data = deviceOn(task.square)
    if data and data:getIsTurnedOn() then
        ISTimedActionQueue.add(ISRadioAction:new("ToggleOnOff", task.player, task.device))
    end
end

--- Acts on what act() reported. Returns true when the job has ended.
local function handle(task, status)
    if status == "ok" then return false end

    if status == "done" then
        finish(task)
        return true
    end

    AA.stop(task.player,
            getText(status == "nopower" and "UI_AA_vhs_nopower" or "UI_AA_vhs_unreachable"),
            true)
    return true
end

--- Books the tape that just came out and lines the next one up.
local function tapeFinished(task, data)
    local player = task.player
    local entry = task.current

    if entry then
        task.done[entry.index] = true
        task.watched = task.watched + 1

        if AA.opt("vhsReturnItems") and task.home then
            local tape = ejectedTape(player, task.tapesBefore or {})
            -- A courtesy, not correctness: on a client the item is made by
            -- the server and may not have arrived yet. Missing it costs
            -- the player nothing but a tape left in their inventory.
            if tape and task.home ~= player:getInventory() then
                pcall(function()
                    ISCraftingUI.ReturnItemToContainer(player, tape, task.home)
                end)
            end
        end

        AA.say(task, getText("UI_AA_vhs_watching", task.watched), false)
    end

    task.current = nil
    task.home = nil

    local maxTapes = AA.opt("vhsMaxTapes") or 0
    if maxTapes > 0 and task.watched >= maxTapes then
        finish(task)
        return
    end

    handle(task, enter(task, "insert", data))
end

local function think(task)
    local player = task.player

    local data = deviceOn(task.square)
    if not data or data:getMediaType() ~= MEDIA_VHS then
        AA.stop(player, getText("UI_AA_vhs_gone"), true)
        return
    end

    -- The character is still walking to the machine or pressing a button.
    -- The phase clock measures the device's answer, not their work, so it
    -- is held while they are busy.
    if AA.isQueueBusy(player) then
        task.phaseAt = AA.now()
        return
    end

    if task.phase == "watch" and not inRange(player, task.square) then
        AA.stop(player, getText("UI_AA_vhs_toofar"), true)
        return
    end

    if ready(task, data) then
        if task.phase == "eject" then
            tapeFinished(task, data)
            return
        end

        local nextPhase = NEXT_PHASE[task.phase]
        if nextPhase then handle(task, enter(task, nextPhase, data)) end
        return
    end

    -- Waiting. A tape gets the long limit, a button press the short one.
    local limit = (task.phase == "watch") and WATCH_LIMIT or STEP_TIMEOUT
    if AA.now() - task.phaseAt < limit then return end

    -- Re-pressing a button can help; re-watching cannot, so a tape that
    -- has not ended in fifteen real minutes is a machine that stopped
    -- answering rather than a slow programme.
    if task.phase == "watch" then
        print("[AutoAll] vhs: the tape never ended - the device is still "
                .. "reporting isPlayingMedia after " .. tostring(WATCH_LIMIT) .. "ms")
        AA.stop(player, getText("UI_AA_vhs_stuck"), true)
        return
    end

    task.tries = task.tries + 1
    if task.tries > STEP_RETRIES then
        print("[AutoAll] vhs: phase '" .. tostring(task.phase) .. "' gave up after "
                .. tostring(task.tries) .. " tries")
        AA.stop(player, getText("UI_AA_vhs_stuck"), true)
        return
    end

    -- A tape that will not go into the slot is set aside rather than tried
    -- for ever. One bad tape should cost the job that tape, not the rest of
    -- the shelf.
    if task.phase == "insert" and task.current then
        print("[AutoAll] vhs: a tape would not go in - skipping it")
        task.failed[task.current.index] = true
        task.current = nil
    end

    task.phaseAt = AA.now()
    handle(task, act(task, data))
end

---------------------------------------------------------------------
-- start / stop
---------------------------------------------------------------------

--- `device` is { object, square }; found automatically when not given.
--- `firstItem` is the tape the player right clicked, which goes in first.
function VHS.start(player, device, firstItem)
    if not player then return end

    device = device or VHS.findDevice(player)
    if not device or not device.object or not device.square then
        HaloTextHelper.addBadText(player, getText("UI_AA_vhs_nodevice"))
        return
    end

    local data = deviceOn(device.square)
    if not data or data:getMediaType() ~= MEDIA_VHS then
        HaloTextHelper.addBadText(player, getText("UI_AA_vhs_nodevice"))
        return
    end
    if not hasPower(data) then
        HaloTextHelper.addBadText(player, getText("UI_AA_vhs_nopower"))
        return
    end

    local found = VHS.collect(player)
    if #found == 0 then
        HaloTextHelper.addBadText(player, getText("UI_AA_vhs_nothing"))
        return
    end

    local task = {
        kind      = "vhs",
        player    = player,
        device    = device.object,
        square    = device.square,
        param     = ISDeviceBatteryAction:getDeviceDataParameter(player, device.object, "IsoObject"),
        done      = {},
        failed    = {},
        watched   = 0,
        tries     = 0,
        first     = firstItem and firstItem:getID() or nil,
        think     = think,
        onStop    = onTaskStop,
        allowMove = true,   -- it fetches tapes and walks back on its own
        startText = getText("UI_AA_vhs_started", #found),
    }

    -- Everything below queues actions, so it has to happen after the task
    -- is registered: AA.startTask clears the queue when it replaces a job
    -- that was already running, and that would take this work with it.
    if not AA.startTask(task) then return end

    -- Whatever is already in the slot is dealt with before ours goes in.
    -- A tape that is playing is left to finish rather than yanked out half
    -- way: the character gets its lines too, and it is what the player
    -- would have done. task.current stays nil, so it is not counted and
    -- not put away - it was never ours.
    if data:hasMedia() then
        handle(task, enter(task, data:isPlayingMedia() and "watch" or "eject", data))
        return
    end

    handle(task, enter(task, "insert", data))
end

VHS.onStart = function(player, item)
    VHS.start(player, nil, item)
end

VHS.onStop = function(player)
    AA.stop(player, getText("UI_AA_stopped"), false)
end

---------------------------------------------------------------------
-- context menu: right click any tape
---------------------------------------------------------------------

local function addVHSMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local actual = ISInventoryPane.getActualItems(items)
    if not actual or not VHS.isTape(actual[1]) then return end

    if AA.isRunning(player, "vhs") then
        AA.addOption(context, getText("UI_AA_vhs_stop"), player, VHS.onStop)
        return
    end

    local option = AA.addOption(context, getText("UI_AA_vhs_option"), player,
            VHS.onStart, actual[1])
    local tooltip = ISInventoryPaneContextMenu.addToolTip()

    local device = VHS.findDevice(player)
    if not device then
        option.notAvailable = true
        tooltip.description = getText("UI_AA_vhs_nodevice")
    else
        local data = deviceOn(device.square)
        if data and not hasPower(data) then
            option.notAvailable = true
            tooltip.description = getText("UI_AA_vhs_nopower")
        else
            local found = VHS.collect(player)
            if #found == 0 then
                option.notAvailable = true
                tooltip.description = getText("UI_AA_vhs_nothing")
            else
                tooltip.description = getText("UI_AA_vhs_option_tt", #found)
            end
        end
    end

    option.toolTip = tooltip
end

AA.registerMenu("vhs", Events.OnFillInventoryObjectContextMenu, addVHSMenu)

---------------------------------------------------------------------
-- a button in the machine's own window
--
-- RWMMedia is the media section of the radio/TV window - the one with the
-- tape slot and the play button. The button goes directly under those,
-- because that is where a player already is when they are looking at a
-- video player.
--
-- The height is set in readFromObject rather than in update, and that is
-- deliberate: RWMElement only re-measures its subpanel from
-- calculateHeights, which readFromObject calls and update does not.
-- Growing the panel from update would leave the element the old size and
-- the button would draw over the section below it.
---------------------------------------------------------------------

local BUTTON_GAP = 4
local PANEL_TAIL = 11       -- what vanilla's createChildren leaves below the last row
local LABEL_INTERVAL = 500  -- ms between two "is there anything to watch" checks

local function panelBase(panel)
    return panel.toggleOnOffButton:getY() + panel.toggleOnOffButton:getHeight()
end

local function installMediaPanelButton()
    if not RWMMedia or RWMMedia.autoAllHooked then return end
    RWMMedia.autoAllHooked = true

    function RWMMedia:onAutoAllVHS()
        if not self.player then return end

        if AA.isRunning(self.player, "vhs") then
            VHS.onStop(self.player)
            return
        end

        VHS.start(self.player, { object = self.device, square = self.device:getSquare() })
    end

    local createChildren = RWMMedia.createChildren
    function RWMMedia:createChildren()
        createChildren(self)

        -- If a future build lays this panel out differently, the button is
        -- simply absent and the vanilla panel is untouched.
        if not self.toggleOnOffButton then return end

        local base = panelBase(self)
        local button = ISButton:new(
                self.toggleOnOffButton:getX(), base + BUTTON_GAP,
                self.toggleOnOffButton:getWidth(), self.toggleOnOffButton:getHeight(),
                getText("UI_AA_vhs_button"), self, RWMMedia.onAutoAllVHS)
        button:initialise()
        button.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
        button.backgroundColorMouseOver = { r = 1.0, g = 1.0, b = 1.0, a = 0.1 }
        button.borderColor = { r = 1.0, g = 1.0, b = 1.0, a = 0.3 }
        button:setVisible(false)
        self:addChild(button)
        self.autoAllVHS = button
    end

    local readFromObject = RWMMedia.readFromObject
    function RWMMedia:readFromObject(player, deviceObject, deviceData, deviceType)
        local read = readFromObject(self, player, deviceObject, deviceData, deviceType)

        if self.autoAllVHS and self.toggleOnOffButton then
            local wanted = read and AA.enabled("vhs") and deviceType == "IsoObject"
                    and deviceData and deviceData:getMediaType() == MEDIA_VHS

            self.autoAllVHS:setVisible(wanted and true or false)

            local base = panelBase(self)
            if wanted then
                self.autoAllVHS:setY(base + BUTTON_GAP)
                self:setHeight(base + BUTTON_GAP + self.autoAllVHS:getHeight() + PANEL_TAIL)
            else
                self:setHeight(base + PANEL_TAIL)
            end
        end

        return read
    end

    local update = RWMMedia.update
    function RWMMedia:update()
        update(self)

        local button = self.autoAllVHS
        if not button or not button:getIsVisible() or not self.player then return end

        if AA.isRunning(self.player, "vhs") then
            button:setTitle(getText("UI_AA_vhs_stopbtn"))
            button:setEnable(true)
            self.autoAllNext = nil
            return
        end

        -- Sweeping every container for tapes is far too much work to do on
        -- a frame. Twice a second is more often than a player can move a
        -- tape and a hundred times less often than this runs.
        local now = getTimestampMs()
        if not self.autoAllNext or now >= self.autoAllNext then
            self.autoAllNext = now + LABEL_INTERVAL
            local ok, found = pcall(VHS.collect, self.player)
            self.autoAllHasTapes = ok and #found > 0
        end

        button:setTitle(getText("UI_AA_vhs_button"))
        button:setEnable(self.autoAllHasTapes == true)
    end
end

-- Installed from OnGameStart so it cannot depend on this file loading
-- after vanilla's RadioCom folder.
Events.OnGameStart.Add(installMediaPanelButton)
