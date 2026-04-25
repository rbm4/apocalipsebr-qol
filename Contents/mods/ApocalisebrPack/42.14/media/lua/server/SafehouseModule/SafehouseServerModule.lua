-- ============================================================
-- ApocBR Safehouse Module - Server
-- Handles safehouse creation triggered by RCON relay.
--
-- RCON usage (via servermsg):
--   servermsg ##APOCBR_SH##<requestId>##<username>##<x>##<y>##<w>##<h>
--
-- Example:
--   servermsg ##APOCBR_SH##req001##PlayerName##1234##5678##30##30
--
-- Any online client that receives the alert relays it here via
-- sendClientCommand. The server deduplicates by requestId and
-- creates the safehouse with SafeHouse.addSafeHouse(x, y, w, h, username).
-- Coordinates are the TOP-LEFT corner; w and h are tile counts.
-- ============================================================

local MODULE = "ApocBR_SafehouseModule"
local CMD_CLAIM = "CreateSafehouse"

-- Prevent multiple online clients from processing the same relay.
local processedRequests = {}

-- ----------------------------------------------------------------
-- Broadcast the new safehouse to every connected client so the UI
-- mirrors the new safehouse immediately without a reconnect.
-- ----------------------------------------------------------------
local function broadcastSafehouseCreated(x, y, w, h, username, title)
    sendServerCommand(MODULE, "SafehouseCreated", {
        x        = x,
        y        = y,
        w        = w,
        h        = h,
        username = username,
        title    = title,
    })
end

-- ----------------------------------------------------------------
-- Returns true if the given rect overlaps any existing safehouse.
-- ----------------------------------------------------------------
local function overlapsExisting(x, y, w, h)
    local list = SafeHouse.getSafehouseList()
    for i = 0, list:size() - 1 do
        local sh = list:get(i)
        local sx, sy, sw, shh = sh:getX(), sh:getY(), sh:getW(), sh:getH()
        if not (x + w <= sx or sx + sw <= x or y + h <= sy or sy + shh <= y) then
            return true, sh
        end
    end
    return false
end

-- ----------------------------------------------------------------
-- Create the safehouse via the Java API and broadcast to clients.
-- ----------------------------------------------------------------
local function createSafehouse(x, y, w, h, username)
    local overlaps, existing = overlapsExisting(x, y, w, h)
    if overlaps then
        local owner = existing and existing:getOwner() or "?"
        print("[SafehouseModule] DENIED " .. username .. ": overlaps safehouse owned by " .. owner)
        return false
    end

    local sh = SafeHouse.addSafeHouse(x, y, w, h, username)
    if not sh then
        print("[SafehouseModule] FAILED " .. username .. ": addSafeHouse returned nil")
        return false
    end

    local title = username .. "'s Safehouse"
    sh:setTitle(title)
    sh:syncSafehouse()
    sh:sync()

    broadcastSafehouseCreated(x, y, w, h, username, title)
    print("[SafehouseModule] CREATED safehouse for " .. username
        .. " at " .. x .. "," .. y .. " size " .. w .. "x" .. h)
    return true
end

-- ----------------------------------------------------------------
-- OnClientCommand: receives the relayed RCON claim from any client.
-- ----------------------------------------------------------------
local function onClientCommand(module, command, playerObj, args)
    if module ~= MODULE or command ~= CMD_CLAIM then return end

    if not args then
        print("[SafehouseModule] " .. CMD_CLAIM .. " received with no args")
        return
    end

    -- Deduplicate: only handle the first relay for each requestId.
    local reqId = tostring(args.requestId or "")
    if reqId ~= "" then
        if processedRequests[reqId] then return end
        processedRequests[reqId] = true
    end

    local username = tostring(args.username or "")
    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local w = tonumber(args.w)
    local h = tonumber(args.h)

    if username == "" or not x or not y or not w or not h then
        print("[SafehouseModule] REJECTED: invalid args (reqId=" .. reqId .. ")")
        return
    end

    if w <= 0 or h <= 0 then
        print("[SafehouseModule] REJECTED: w/h must be positive (reqId=" .. reqId .. ")")
        return
    end

    createSafehouse(x, y, w, h, username)
end

-- Clear the dedup table periodically to avoid unbounded growth.
Events.EveryTenMinutes.Add(function()
    processedRequests = {}
end)

Events.OnClientCommand.Add(onClientCommand)
