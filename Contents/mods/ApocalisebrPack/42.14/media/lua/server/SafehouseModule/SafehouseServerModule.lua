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
local CMD_UPGRADE = "UpgradeSafehouse"

-- Track successfully-created safehouses by requestId for idempotent claim handling.
-- requestId → { x, y, w, h, username, timestamp, success }
-- This ensures that:
--   1. Multiple clients sending the same RCON request only create one safehouse
--   2. Retries of the same requestId return success gracefully
--   3. Different requestIds for overlapping areas are rejected as expected
local createdClaims = {}

-- ----------------------------------------------------------------
-- Compute overlap area between two rectangles.
-- ----------------------------------------------------------------
local function getOverlapArea(ax, ay, aw, ah, bx, by, bw, bh)
    local left = math.max(ax, bx)
    local top = math.max(ay, by)
    local right = math.min(ax + aw, bx + bw)
    local bottom = math.min(ay + ah, by + bh)
    if right <= left or bottom <= top then
        return 0
    end
    return (right - left) * (bottom - top)
end

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
-- Find the best matching overlapping safehouse owned by username.
-- Returns SafeHouse or nil.
-- ----------------------------------------------------------------
local function findOwnerOverlappingSafehouse(x, y, w, h, username)
    local bestSafehouse = nil
    local bestArea = 0
    local overlaps = getOverlappingSafehouses(x, y, w, h)
    for _, sh in ipairs(overlaps) do
        local owner = sh:getOwner()
        if owner and tostring(owner) == tostring(username) then
            local area = getOverlapArea(x, y, w, h, sh:getX(), sh:getY(), sh:getW(), sh:getH())
            if area > bestArea then
                bestArea = area
                bestSafehouse = sh
            end
        end
    end
    return bestSafehouse
end

-- ----------------------------------------------------------------
-- Broadcast a custom in-place safehouse update for connected clients.
-- This keeps currently connected clients in sync after server-side resize.
-- ----------------------------------------------------------------
local function broadcastSafehouseUpdated(oldX, oldY, oldW, oldH, sh)
    local players = getOnlinePlayers and getOnlinePlayers()
    if not players then
        return
    end

    local payload = {
        oldX = oldX,
        oldY = oldY,
        oldW = oldW,
        oldH = oldH,
        x = sh:getX(),
        y = sh:getY(),
        w = sh:getW(),
        h = sh:getH(),
        owner = sh:getOwner(),
        title = sh:getTitle()
    }

    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then
            sendServerCommand(p, MODULE, "SafehouseUpdated", payload)
        end
    end
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
-- Upgrade an existing safehouse in-place (preferred path).
-- Identifies target by overlap + same owner username.
-- ----------------------------------------------------------------
local function upgradeSafehouse(x, y, w, h, username, requestId)
    if requestId then
        local cached = createdClaims[requestId]
        if cached and cached.success then
            print("[SafehouseModule] IDEMPOTENT: requestId " .. requestId .. " already processed")
            return true
        elseif cached and not cached.success then
            print("[SafehouseModule] IDEMPOTENT: requestId " .. requestId .. " already failed")
            return false
        end
    end

    local target = findOwnerOverlappingSafehouse(x, y, w, h, username)
    if not target then
        print("[SafehouseModule] UPGRADE REJECTED: no overlapping safehouse owned by " .. username)
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

    local oldX, oldY, oldW, oldH = target:getX(), target:getY(), target:getW(), target:getH()

    -- Website claims still have priority: remove overlapping safehouses
    -- from other owners before resizing.
    local overlaps = getOverlappingSafehouses(x, y, w, h)
    for _, sh in ipairs(overlaps) do
        if sh ~= target then
            local owner = sh:getOwner() or "?"
            if tostring(owner) ~= tostring(username) then
                print("[SafehouseModule] UPGRADE: removing overlapping safehouse owned by " .. owner ..
                          " at " .. sh:getX() .. "," .. sh:getY())
                SafeHouse.removeSafeHouse(sh)
            end
        end
    end

    local okResize = pcall(function()
        target:setX(x)
        target:setY(y)
        target:setW(w)
        target:setH(h)
        target:setOnlineID(SafeHouse.getOnlineID(x, y))
    end)

    if not okResize then
        -- Emergency fallback if runtime behavior changes in a future build.
        local members = {}
        local memberList = target:getPlayers()
        if memberList then
            for i = 0, memberList:size() - 1 do
                local m = memberList:get(i)
                if m and tostring(m) ~= tostring(username) then
                    table.insert(members, tostring(m))
                end
            end
        end

        local oldTitle = target:getTitle()
        SafeHouse.removeSafeHouse(target)
        target = SafeHouse.addSafeHouse(x, y, w, h, username)
        if not target then
            print("[SafehouseModule] UPGRADE FAILED: fallback addSafeHouse returned nil")
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

        if target.setTitle and oldTitle then
            target:setTitle(oldTitle)
        end
        for _, member in ipairs(members) do
            target:addPlayer(member)
        end
    end

    broadcastSafehouseUpdated(oldX, oldY, oldW, oldH, target)

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

    print("[SafehouseModule] UPGRADED safehouse for " .. username .. " from " .. oldX .. "," .. oldY ..
              " " .. oldW .. "x" .. oldH .. " to " .. x .. "," .. y .. " " .. w .. "x" .. h ..
              " (requestId=" .. tostring(requestId) .. ")")
    return true
end

local function claimNewSafehouse(args)
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

local function upgradeExistingSafehouse(args)
    if not args then
        print("[SafehouseModule] " .. CMD_UPGRADE .. " received with no args")
        return
    end

    local reqId = tostring(args.requestId or "")
    local username = tostring(args.username or "")
    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local w = tonumber(args.w)
    local h = tonumber(args.h)

    if username == "" or not x or not y or not w or not h then
        print("[SafehouseModule] UPGRADE REJECTED: invalid args")
        return
    end

    if w <= 0 or h <= 0 then
        print("[SafehouseModule] UPGRADE REJECTED: w/h must be positive")
        return
    end

    upgradeSafehouse(x, y, w, h, username, reqId)
end

-- ----------------------------------------------------------------
-- OnClientCommand: receives the relayed RCON claim from any client.
-- ----------------------------------------------------------------
local function onClientCommand(module, command, playerObj, args)
    if module ~= MODULE then
        return
    end

    if command == CMD_CLAIM then
        claimNewSafehouse(args)
        return
    end

    if command == CMD_UPGRADE then
        upgradeExistingSafehouse(args)
        return
    end
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
