AnimalWildSync = AnimalWildSync or {}

-- Network routing
AnimalWildSync.MODULE = "AnimalWildSync"

-- Commands
AnimalWildSync.CMD_REQUEST   = "RequestAnimalWild"      -- C -> S  { ids = {..} }
AnimalWildSync.CMD_KEEPALIVE = "KeepAliveInterested"    -- C -> S  { ids = {..} }
AnimalWildSync.CMD_STATE     = "AnimalWildState"        -- S -> C  { ids = {..}, wild = {..} }

-- Tunables
AnimalWildSync.FLUSH_MS        = 500     -- client request batching throttle
AnimalWildSync.KEEPALIVE_S     = 60      -- client lease renew interval
AnimalWildSync.PRUNE_AFTER_S   = 120     -- server drops interest if not renewed
AnimalWildSync.PRUNE_TICK_S    = 30      -- server prune cadence
AnimalWildSync.VERIFY_TICK_S   = 2       -- server watch verify cadence
AnimalWildSync.MAX_IDS_PER_MSG = 200     -- chunking

-- Relevancy approximation (tiles). Used only server-side as a safety gate.
AnimalWildSync.RELEVANT_DIST_TILES = 90

function AnimalWildSync.nowMs()
    return (getTimestampMs and getTimestampMs()) or (os.time() * 1000)
end

function AnimalWildSync.nowS()
    return AnimalWildSync.nowMs() / 1000
end

-- set -> list
function AnimalWildSync.setToList(setTbl)
    local out = {}
    for k, v in pairs(setTbl or {}) do
        if v then out[#out+1] = k end
    end
    return out
end

-- chunk a list
function AnimalWildSync.chunkList(list, maxPer)
    local chunks = {}
    if not (list and #list > 0) then return chunks end
    maxPer = maxPer or AnimalWildSync.MAX_IDS_PER_MSG
    local i = 1
    while i <= #list do
        local chunk = {}
        local jEnd = math.min(i + maxPer - 1, #list)
        for j = i, jEnd do chunk[#chunk+1] = list[j] end
        chunks[#chunks+1] = chunk
        i = jEnd + 1
    end
    return chunks
end

function AnimalWildSync.hasAny(t)
    if not t then return false end
    for _, _ in pairs(t) do
        return true
    end
    return false
end

AnimalWildSync.DEBUG = getCore():getDebug()

function AnimalWildSync.dlog(tag, msg)
    if not AnimalWildSync.DEBUG then return end
    if DebugLog and DebugLog.log then
        DebugLog.log(DebugType.General, "[AnimalWildSync][" .. tostring(tag) .. "] " .. tostring(msg))
    end
end
