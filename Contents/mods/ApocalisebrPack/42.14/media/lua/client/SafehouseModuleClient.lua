-- ============================================================
-- ApocBR Safehouse Module - Client
--
-- Two responsibilities:
--  1. Intercept RCON 'servermsg' alerts and relay the claim
--     request to the server via sendClientCommand.
--  2. Mirror server-confirmed safehouses locally so the UI
--     updates immediately without a reconnect.
--
-- RCON format (what your website sends via RCON):
--   servermsg ##APOCBR_SH##<requestId>##<username>##<x>##<y>##<w>##<h>
--
-- x, y  = top-left tile coordinate of the safehouse area
-- w, h  = width and height in tiles
-- ============================================================

local MODULE = "ApocBR_SafehouseModule"
local CMD_CLAIM = "CreateSafehouse"
local CMD_UPGRADE = "UpgradeSafehouse"
local ALERT_PREFIX = "##APOCBR_SH##"
local UPGRADE_PREFIX = "##APOCBR_SH_UPGRADE##"
local DELIMITER = "##"

-- Split str by the literal delimiter string.
local function splitByDelim(str, delim)
    local parts = {}
    local escapedDelim = delim:gsub("([^%w])", "%%%1")
    for part in (str .. delim):gmatch("(.-)" .. escapedDelim) do
        parts[#parts + 1] = part
    end
    return parts
end

-- ----------------------------------------------------------------
-- Events.OnAddMessage fires synchronously before Java checks
-- msg:isServerAlert(), so calling setServerAlert(false) here
-- prevents the red popup from ever appearing.
-- setShowInChat(false) and setText("") suppress the chat tab entry.
-- ----------------------------------------------------------------
local function onAddMessage(msg, tabId)
    if not msg then return end

    local text = msg:getText()
    if type(text) ~= "string" then return end

    local isClaim = text:sub(1, #ALERT_PREFIX) == ALERT_PREFIX
    local isUpgrade = text:sub(1, #UPGRADE_PREFIX) == UPGRADE_PREFIX
    if not isClaim and not isUpgrade then return end

    local targetCommand = isUpgrade and CMD_UPGRADE or CMD_CLAIM
    local prefix = isUpgrade and UPGRADE_PREFIX or ALERT_PREFIX

    -- Suppress the message completely: no popup, no visible chat line.
    msg:setServerAlert(false)
    msg:setShowInChat(false)
    msg:setText("")

    -- Strip prefix, then split remaining by "##"
    local data  = text:sub(#prefix + 1)
    local parts = splitByDelim(data, DELIMITER)

    -- Expected: [1]=requestId, [2]=username, [3]=x, [4]=y, [5]=w, [6]=h
    if #parts < 6 then
        print("[SafehouseModuleClient] Malformed relay message (truncated)")
        return
    end

    local player = getPlayer()
    if not player then return end

    sendClientCommand(player, MODULE, targetCommand, {
        requestId = parts[1],
        username  = parts[2],
        x         = tonumber(parts[3]),
        y         = tonumber(parts[4]),
        w         = tonumber(parts[5]),
        h         = tonumber(parts[6]),
    })
end

Events.OnAddMessage.Add(onAddMessage)

local function findBestSafehouseForUpdate(args)
    if not SafeHouse or not SafeHouse.getSafehouseList then
        return nil
    end

    local x = tonumber(args and args.x)
    local y = tonumber(args and args.y)
    local w = tonumber(args and args.w)
    local h = tonumber(args and args.h)
    local oldX = tonumber(args and args.oldX)
    local oldY = tonumber(args and args.oldY)
    local oldW = tonumber(args and args.oldW)
    local oldH = tonumber(args and args.oldH)
    local owner = tostring(args and args.owner or "")
    if not x or not y or not w or not h then
        return nil
    end

    local function overlapArea(ax, ay, aw, ah, bx, by, bw, bh)
        local left = math.max(ax, bx)
        local top = math.max(ay, by)
        local right = math.min(ax + aw, bx + bw)
        local bottom = math.min(ay + ah, by + bh)
        if right <= left or bottom <= top then
            return 0
        end
        return (right - left) * (bottom - top)
    end

    local list = SafeHouse.getSafehouseList()
    local best, bestArea = nil, 0
    for i = 0, list:size() - 1 do
        local sh = list:get(i)
        if sh then
            local shOwner = tostring(sh:getOwner() or "")
            if owner == "" or shOwner == owner then
                -- Strong match: exact previous rectangle
                if oldX and oldY and oldW and oldH and
                    sh:getX() == oldX and sh:getY() == oldY and sh:getW() == oldW and sh:getH() == oldH then
                    return sh
                end

                local area = overlapArea(x, y, w, h, sh:getX(), sh:getY(), sh:getW(), sh:getH())
                if area > bestArea then
                    bestArea = area
                    best = sh
                end
            end
        end
    end

    return best
end

local function applySafehouseUpdated(args)
    if not args then
        return
    end

    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local w = tonumber(args.w)
    local h = tonumber(args.h)
    if not x or not y or not w or not h then
        return
    end

    local sh = findBestSafehouseForUpdate(args)
    if sh then
        pcall(function()
            sh:setX(x)
            sh:setY(y)
            sh:setW(w)
            sh:setH(h)
            sh:setOnlineID(SafeHouse.getOnlineID(x, y))
            if args.title and sh.setTitle then
                sh:setTitle(args.title)
            end
        end)
    else
        -- Fallback for edge-cases where client did not have the previous entry.
        local owner = tostring(args.owner or "")
        if owner ~= "" and SafeHouse.addSafeHouse then
            pcall(function()
                local newSh = SafeHouse.addSafeHouse(x, y, w, h, owner)
                if newSh and args.title and newSh.setTitle then
                    newSh:setTitle(args.title)
                end
            end)
        end
    end

    if triggerEvent then
        pcall(function() triggerEvent("OnSafehousesChanged") end)
    end
end

local function onServerCommand(module, command, args)
    if module ~= MODULE then
        return
    end

    if command == "SafehouseUpdated" then
        applySafehouseUpdated(args)
    end
end

Events.OnServerCommand.Add(onServerCommand)
