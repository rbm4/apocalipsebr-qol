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
local ALERT_PREFIX = "##APOCBR_SH##"
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
    if text:sub(1, #ALERT_PREFIX) ~= ALERT_PREFIX then return end

    -- Suppress the message completely: no popup, no visible chat line.
    msg:setServerAlert(false)
    msg:setShowInChat(false)
    msg:setText("")

    -- Strip prefix, then split remaining by "##"
    local data  = text:sub(#ALERT_PREFIX + 1)
    local parts = splitByDelim(data, DELIMITER)

    -- Expected: [1]=requestId, [2]=username, [3]=x, [4]=y, [5]=w, [6]=h
    if #parts < 6 then
        print("[SafehouseModuleClient] Malformed relay message (truncated)")
        return
    end

    local player = getPlayer()
    if not player then return end

    sendClientCommand(player, MODULE, CMD_CLAIM, {
        requestId = parts[1],
        username  = parts[2],
        x         = tonumber(parts[3]),
        y         = tonumber(parts[4]),
        w         = tonumber(parts[5]),
        h         = tonumber(parts[6]),
    })
end

Events.OnAddMessage.Add(onAddMessage)
