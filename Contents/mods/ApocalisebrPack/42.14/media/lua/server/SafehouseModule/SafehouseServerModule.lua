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

-- Track successfully-created safehouses by requestId for idempotent claim handling.
-- requestId → { x, y, w, h, username, timestamp, success }
-- This ensures that:
--   1. Multiple clients sending the same RCON request only create one safehouse
--   2. Retries of the same requestId return success gracefully
--   3. Different requestIds for overlapping areas are rejected as expected
local createdClaims = {}

-- ----------------------------------------------------------------
-- Find all safehouses that overlap with the given rect.
-- Returns table of overlapping SafeHouse objects.
-- ----------------------------------------------------------------
local function getOverlappingSafehouses(x, y, w, h)
    local overlaps = {}
    local list = SafeHouse.getSafehouseList()
    for i = 0, list:size() - 1 do
        local sh = list:get(i)
        local sx, sy, sw, shh = sh:getX(), sh:getY(), sh:getW(), sh:getH()
        if not (x + w <= sx or sx + sw <= x or y + h <= sy or sy + shh <= y) then
            table.insert(overlaps, sh)
        end
    end
    return overlaps
end

-- ----------------------------------------------------------------
-- Create the safehouse via the Java API and broadcast to clients.
-- Purges overlapping safehouses (admin claim has priority).
-- Supports idempotent retries by requestId.
-- ----------------------------------------------------------------
local function createSafehouse(x, y, w, h, username, requestId)
    -- Idempotency: if this requestId was already processed successfully,
    -- return true immediately (multi-player relay of same RCON message).
    if requestId then
        local cached = createdClaims[requestId]
        if cached and cached.success then
            -- Same request was already successfully created.
            print("[SafehouseModule] IDEMPOTENT: requestId " .. requestId .. " already created")
            return true
        elseif cached and not cached.success then
            -- Same requestId was already attempted and failed (invalid params, etc.)
            print("[SafehouseModule] IDEMPOTENT: requestId " .. requestId .. " already failed")
            return false
        end
    end

    -- Check for overlapping safehouses. Website claims have priority, so purge them.
    local overlaps = getOverlappingSafehouses(x, y, w, h)
    if #overlaps > 0 then
        print("[SafehouseModule] Purging " .. tostring(#overlaps) ..
                  " overlapping safehouse(s) to make room for admin claim by " .. username)
        for _, sh in ipairs(overlaps) do
            local owner = sh:getOwner() or "?"
            print("[SafehouseModule]   - Removing safehouse owned by " .. owner .. " at " .. sh:getX() .. "," ..
                      sh:getY())
            SafeHouse.removeSafeHouse(sh)
        end
    end

    local sh = SafeHouse.addSafeHouse(x, y, w, h, username)
    if not sh then
        print("[SafehouseModule] FAILED " .. username .. ": addSafeHouse returned nil")
        if requestId then
            createdClaims[requestId] = {
                x = x,
                y = y,
                w = w,
                h = h,
                username = username,
                timestamp = os.time(),
                success = false
            }
        end
        return false
    end

    local title = username .. "'s Safehouse"
    if sh.setTitle then
        sh:setTitle(title)
    end

    -- Sync to all clients via BetterSafehouse's SafehouseAdded broadcast.
    -- BetterSafehouse.CustomClaim.NET_MODULE == "BetterSafehouseCC"
    local players = getOnlinePlayers and getOnlinePlayers()
    if players then
        local payload = {
            x = x,
            y = y,
            w = w,
            h = h,
            owner = username,
            title = title
        }
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p then
                sendServerCommand(p, "BetterSafehouseCC", "SafehouseAdded", payload)
            end
        end
    end

    -- Cache successful creation for idempotent retries.
    if requestId then
        createdClaims[requestId] = {
            x = x,
            y = y,
            w = w,
            h = h,
            username = username,
            timestamp = os.time(),
            success = true
        }
    end

    print(
        "[SafehouseModule] CREATED safehouse for " .. username .. " at " .. x .. "," .. y .. " size " .. w .. "x" .. h ..
            " (requestId=" .. tostring(requestId) .. ")")
    return true
end

-- ----------------------------------------------------------------
-- OnClientCommand: receives the relayed RCON claim from any client.
-- ----------------------------------------------------------------
local function onClientCommand(module, command, playerObj, args)
    if module ~= MODULE or command ~= CMD_CLAIM then
        return
    end

    if not args then
        print("[SafehouseModule] " .. CMD_CLAIM .. " received with no args")
        return
    end

    local reqId = tostring(args.requestId or "")
    local username = tostring(args.username or "")
    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local w = tonumber(args.w)
    local h = tonumber(args.h)

    if username == "" or not x or not y or not w or not h then
        print("[SafehouseModule] REJECTED: invalid args")
        return
    end

    if w <= 0 or h <= 0 then
        print("[SafehouseModule] REJECTED: w/h must be positive")
        return
    end

    createSafehouse(x, y, w, h, username, reqId)
end

-- Clean up old cached claims periodically to prevent unbounded memory growth.
-- Keep claims for up to 1 hour after creation/failure for idempotent handling.
Events.EveryTenMinutes.Add(function()
    local now = os.time()
    local maxAgeSec = 3600 -- 1 hour
    for reqId, info in pairs(createdClaims) do
        if now - (info.timestamp or 0) > maxAgeSec then
            createdClaims[reqId] = nil
        end
    end
end)

Events.OnClientCommand.Add(onClientCommand)
