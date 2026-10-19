-- How many characters the player has lost in this world. Nothing in the game keeps that count
-- where a client can read it, so the mod keeps its own: one "world=count" line per world in
-- Zomboid/Lua/SurvivorBriefing_deaths.ini, counted from the day this was installed.
-- A world is a single-player save, or one username on one server.
SurvivorBriefing = SurvivorBriefing or {}
local SB = SurvivorBriefing

local Deaths = {}
SB.Deaths = Deaths

local FILE = "SurvivorBriefing_deaths.ini"
local counts

local function clean(s) return (tostring(s):gsub("[=\r\n]", "_")) end

function Deaths.worldKey()
    if isClient() then
        return clean("MP/" .. tostring(getServerIP()) .. ":" .. tostring(getServerPort()) .. "/" .. tostring(getOnlineUsername()))
    end
    return clean(tostring(getCore():getGameMode()) .. "/" .. tostring(getWorld():getWorld()))
end

local function load()
    counts = {}
    local ok, reader = pcall(getFileReader, FILE, false)
    if not ok or not reader then return end
    while true do
        local line = reader:readLine()
        if line == nil then break end
        local key, n = line:match("^(.-)=(%d+)%s*$")
        if key and key ~= "" then counts[key] = tonumber(n) end
    end
    reader:close()
end

local function save()
    local ok, writer = pcall(getFileWriter, FILE, true, false)
    if not ok or not writer then return end
    for key, n in pairs(counts) do writer:write(key .. "=" .. string.format("%d", n) .. "\r\n") end
    writer:close()
end

function Deaths.count()
    if not counts then load() end
    return counts[Deaths.worldKey()] or 0
end

function Deaths.onPlayerDeath(player)
    local ok, err = pcall(function()
        if not player or not player:isLocalPlayer() then return end
        if not counts then load() end
        local key = Deaths.worldKey()
        counts[key] = (counts[key] or 0) + 1
        save()
        print("[SurvivorBriefing] death recorded: " .. counts[key] .. " in this world")
    end)
    if not ok then print("[SurvivorBriefing] death not recorded: " .. tostring(err)) end
end

-- Test hook: forget what was read.
function Deaths.reset() counts = nil end

Events.OnPlayerDeath.Add(Deaths.onPlayerDeath)
