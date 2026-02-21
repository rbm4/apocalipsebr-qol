local MOD = "ConsolidateAllFix"
local DEBUG = getCore():getDebug()

local function log(msg)
	if DEBUG then
		DebugLog.log(DebugType.General, "[" .. MOD .. "][SH] " .. tostring(msg))
	end
end

local MODULE = "EuryBugs" .. "_" .. MOD
local CMD_STEP_REQ = "CAF_StepReq"
local CMD_STEP_RES = "CAF_StepRes"

-- Default: only fix Thread. Set false to apply to all DrainableComboItem consolidate-all.
local THREAD_ONLY = true

local EPS = 1e-6

-- ---------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------

local function isDrainable(item)
	return item and instanceof(item, "DrainableComboItem")
end

local function isThread(item)
	return item and item.getFullType and item:getFullType() == "Base.Thread"
end

local function shouldHandle(item)
	if not isDrainable(item) then return false end
	if not THREAD_ONLY then return true end
	return isThread(item)
end

local function safeId(item)
	return (item and item.getID) and item:getID() or nil
end

local function resolveById(character, id)
	if not (character and id) then return nil end
	local inv = character.getInventory and character:getInventory() or nil
	if not inv then return nil end
	return inv:getItemById(id)
end

-- best-effort sync helpers (existence varies by context / load order)
local function syncItemSafe(character, item)
	if not item then return end

	-- Preferred: item method (no args)
	if item.syncItemFields then
		pcall(item.syncItemFields, item)
	elseif syncItemFields and character then
		-- Fallback: global helper (needs character + item)
		pcall(syncItemFields, character, item)
	end

	if sendItemStats then
		pcall(sendItemStats, item)
	end
end

local function removeItemSafe(inv, item)
	if not (inv and item) then return end
	inv:Remove(item)
	if sendRemoveItemFromContainer then
		pcall(sendRemoveItemFromContainer, inv, item)
	end
end

-- =========================================================
-- SERVER: authoritative step apply + reply
-- =========================================================

local function serverApplyStep(player, args)
	if not (player and args) then return end
	if type(args.fromId) ~= "number" or type(args.toId) ~= "number" then return end
	if args.fromId == args.toId then
		sendServerCommand(player, MODULE, CMD_STEP_RES, { ok = false, reason = "sameId" })
		return
	end

	local inv = player:getInventory()
	if not inv then
		sendServerCommand(player, MODULE, CMD_STEP_RES, { ok = false, reason = "noInv" })
		return
	end

	local fromItem = inv:getItemById(args.fromId)
	local toItem = inv:getItemById(args.toId)

	if not (fromItem and toItem) then
		sendServerCommand(player, MODULE, CMD_STEP_RES, { ok = false, reason = "missingItems", fromId = args.fromId, toId = args.toId })
		return
	end

	if not (isDrainable(fromItem) and isDrainable(toItem)) then
		sendServerCommand(player, MODULE, CMD_STEP_RES, { ok = false, reason = "notDrainable", fromId = args.fromId, toId = args.toId })
		return
	end

	if THREAD_ONLY then
		if not (isThread(fromItem) and isThread(toItem)) then
			sendServerCommand(player, MODULE, CMD_STEP_RES, { ok = false, reason = "notThread", fromId = args.fromId, toId = args.toId })
			return
		end
	end

	local fromU = fromItem:getCurrentUsesFloat() or 0
	local toU = toItem:getCurrentUsesFloat() or 0

	local space = 1.0 - toU
	if space <= EPS or fromU <= EPS then
		sendServerCommand(player, MODULE, CMD_STEP_RES, { ok = true, done = true })
		return
	end

	local move = fromU
	if move > space then move = space end
	if move <= EPS then
		sendServerCommand(player, MODULE, CMD_STEP_RES, { ok = true, done = true })
		return
	end

	-- Apply authoritative change
	fromItem:setCurrentUsesFloat(fromU - move)
	toItem:setCurrentUsesFloat(toU + move)

	-- Remove emptied
	if (fromItem:getCurrentUsesFloat() or 0) <= EPS then
		removeItemSafe(inv, fromItem)
	else
		syncItemSafe(fromItem)
	end
	syncItemSafe(toItem)

	sendServerCommand(player, MODULE, CMD_STEP_RES, {
		ok = true,
		done = false,
		fromId = args.fromId,
		toId = args.toId,
		move = move
	})
end

if isServer() then
	Events.OnClientCommand.Add(function(module, command, player, args)
		if module ~= MODULE then return end
		if command ~= CMD_STEP_REQ then return end
		serverApplyStep(player, args)
	end)

	log("Server handler installed.")
end

-- =========================================================
-- CLIENT: session + local timed action + menu patch
-- =========================================================

if not isClient() then
	return
end

require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISBaseTimedAction"
require "ISUI/ISInventoryPaneContextMenu"
require "TimedActions/ISConsolidateDrainable"

local ST = {
	active = nil,     -- { ids = {..}, waiting = bool, cancelled = bool }
	waitingReq = nil, -- { fromId, toId }
}

local function clearSession(why)
	if ST.active then
		log("Session cleared why " .. tostring(why))
	end
	ST.active = nil
	ST.waitingReq = nil
end

local function gatherCandidateIds(clicked, consolidateList)
	local ids = {}

	local function add(it)
		if not shouldHandle(it) then return end
		local id = safeId(it)
		if not id then return end
		ids[#ids + 1] = id
	end

	add(clicked)
	if consolidateList then
		for i = 1, #consolidateList do
			add(consolidateList[i])
		end
	end

	-- de-dupe
	local seen = {}
	local out = {}
	for i = 1, #ids do
		local id = ids[i]
		if id and not seen[id] then
			seen[id] = true
			out[#out + 1] = id
		end
	end
	return out
end

-- Choose next live (from,to) pair based on current inventory state.
local function chooseNextPair(player, ids)
	if not (player and ids and #ids >= 2) then return nil end

	local live = {}
	for i = 1, #ids do
		local it = resolveById(player, ids[i])
		if it and shouldHandle(it) then
			live[#live + 1] = it
		end
	end
	if #live < 2 then return nil end

	-- Pick a "full-ish" anchor first (largest uses)
	local best, bestU = nil, -1
	for i = 1, #live do
		local it = live[i]
		local u = it:getCurrentUsesFloat() or 0
		if u > bestU then
			best, bestU = it, u
		end
	end
	if not best then return nil end

	-- Now pick a source that is the smallest non-zero (ideally) that can feed into best if best not full
	local target = best
	local targetU = bestU
	if targetU >= 1.0 - EPS then
		-- If the fullest is already full, target should be the fullest NOT full.
		target, targetU = nil, -1
		for i = 1, #live do
			local it = live[i]
			local u = it:getCurrentUsesFloat() or 0
			if u < 1.0 - EPS and u > targetU then
				target, targetU = it, u
			end
		end
		if not target then return nil end
	end

	local source, sourceU = nil, 2
	for i = 1, #live do
		local it = live[i]
		if it ~= target then
			local u = it:getCurrentUsesFloat() or 0
			if u > EPS and u < sourceU then
				source, sourceU = it, u
			end
		end
	end
	if not source then return nil end

	-- Enforce direction: always pour smaller -> larger
	local tU = target:getCurrentUsesFloat() or 0
	local sU = source:getCurrentUsesFloat() or 0
	if tU + EPS < sU then
		-- swap
		local tmp = source; source = target; target = tmp
		sU = source:getCurrentUsesFloat() or 0
		tU = target:getCurrentUsesFloat() or 0
	end

	-- Now ensure it's a meaningful move
	local space = 1.0 - tU
	local take = sU
	if space <= EPS or take <= EPS then return nil end

	-- Also require target >= source (post-swap) so we don't get oscillation
	if tU + EPS < sU then return nil end

	return source, target
end

-- LOCAL feel action (client-only). Does NOT mutate inventory.
local CAF_LocalStep = ISBaseTimedAction:derive("CAF_LocalStep")

function CAF_LocalStep:isValid()
	return true
end

function CAF_LocalStep:start()
	-- Set job type to match vanilla-ish UI
	self.action:setUseProgressBar(true)
end

function CAF_LocalStep:update()
	local player = self.character
	if not player then
		self:forceComplete()
		return
	end

	local fromItem = resolveById(player, self.fromId)
	local toItem = resolveById(player, self.toId)
	if not (fromItem and toItem) then
		self:forceComplete()
		return
	end

	local d = self:getJobDelta()
	fromItem:setJobDelta(d)
	toItem:setJobDelta(d)
end

function CAF_LocalStep:stop()
	-- Clear deltas
	local player = self.character
	if player then
		local fromItem = resolveById(player, self.fromId)
		local toItem = resolveById(player, self.toId)
		if fromItem then fromItem:setJobDelta(0.0) end
		if toItem then toItem:setJobDelta(0.0) end
	end

	-- User cancelled (ESC / moved / etc). End the whole session.
	if ST.active then
		ST.active.cancelled = true
	end
	clearSession("cancelled")
	ISBaseTimedAction.stop(self)
end

function CAF_LocalStep:perform()
	-- Clear deltas
	local player = self.character
	if player then
		local fromItem = resolveById(player, self.fromId)
		local toItem = resolveById(player, self.toId)
		if fromItem then fromItem:setJobDelta(0.0) end
		if toItem then toItem:setJobDelta(0.0) end
	end

	-- Send authoritative request to server; wait for response before next step.
	if ST.active then
		ST.active.waiting = true
		ST.waitingReq = { fromId = self.fromId, toId = self.toId }
		sendClientCommand(player, MODULE, CMD_STEP_REQ, { fromId = self.fromId, toId = self.toId })
		log("Sent step req fromId " .. tostring(self.fromId) .. " toId " .. tostring(self.toId))
	end

	ISBaseTimedAction.perform(self)
end

function CAF_LocalStep:new(player, fromId, toId, maxTime)
	local o = ISBaseTimedAction.new(self, player)
	o.stopOnWalk = true
	o.stopOnRun = true
	o.stopOnAim = true
	o.maxTime = maxTime or 50
	o.fromId = fromId
	o.toId = toId
	return o
end

local function getVanillaDuration(player, fromItem, toItem)
	-- Use vanilla duration formula if available
	if ISConsolidateDrainable and ISConsolidateDrainable.getDuration then
		local shim = { character = player, drainable = fromItem, intoItem = toItem }
		local ok, dur = pcall(ISConsolidateDrainable.getDuration, shim)
		if ok and type(dur) == "number" and dur > 0 then
			return dur
		end
	end
	return 50
end

local function queueNextLocalStep(player)
	if not ST.active then return end
	if ST.active.waiting then return end

	local ids = ST.active.ids
	local fromItem, toItem = chooseNextPair(player, ids)
	if not (fromItem and toItem) then
		clearSession("done")
		return
	end

	local fromId = safeId(fromItem)
	local toId = safeId(toItem)
	if not (fromId and toId) then
		clearSession("badIds")
		return
	end

	local dur = getVanillaDuration(player, fromItem, toItem)
	ISTimedActionQueue.add(CAF_LocalStep:new(player, fromId, toId, dur))
	log("Queued local step fromId " .. tostring(fromId) .. " toId " .. tostring(toId) .. " dur " .. tostring(dur))
end

-- Server response handler
Events.OnServerCommand.Add(function(module, command, args)
	if module ~= MODULE then return end
	if command ~= CMD_STEP_RES then return end

	-- If we have no session, ignore.
	if not ST.active then return end

	-- Clear waiting flag no matter what.
	ST.active.waiting = false

	if not (args and args.ok) then
		log("Step res fail reason " .. tostring(args and args.reason))
		clearSession("serverFail")
		return
	end

	if args.done then
		clearSession("serverDone")
		return
	end

	if args.move and type(args.move) == "number" and args.move <= EPS then
		clearSession("zeroMove")
		return
	end

	-- Success: queue next step based on live inventory.
	queueNextLocalStep(getPlayer())
end)

-- Patch the context menu
local function patchMenu()
	if not ISInventoryPaneContextMenu then return end
	if ISInventoryPaneContextMenu.__CAF_Patched then return end
	ISInventoryPaneContextMenu.__CAF_Patched = true

	local vanilla = ISInventoryPaneContextMenu.onConsolidateAll

	ISInventoryPaneContextMenu.onConsolidateAll = function(drainable, consolidateList, playerObj)
		if not shouldHandle(drainable) then
			return vanilla(drainable, consolidateList, playerObj)
		end

		local ids = gatherCandidateIds(drainable, consolidateList)
		if not ids or #ids < 2 then
			return vanilla(drainable, consolidateList, playerObj)
		end

		ST.active = { ids = ids, waiting = false, cancelled = false }
		ST.waitingReq = nil

		log("Session started ids " .. tostring(#ids))

		queueNextLocalStep(playerObj)
	end

	log("Patched ISInventoryPaneContextMenu.onConsolidateAll (Angle B).")
end

patchMenu()
Events.OnGameStart.Add(patchMenu)

log("Client installed.")
