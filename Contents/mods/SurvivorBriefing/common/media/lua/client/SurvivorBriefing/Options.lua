-- Options > Mods > Survivor Briefing. Client-side, per player, changeable mid-game.
require "PZAPI/ModOptions"

SurvivorBriefing = SurvivorBriefing or {}
local SB = SurvivorBriefing

local DEFAULTS = {
    onArrival = true, onMidnight = true, dailyHour = 0, dailySunrise = false, onWake = true, onLoadSave = true, onResume = false, onTown = false,
    showTime = true, showDate = true, showName = true, showOccupation = true,
    showLocation = true, showWeather = true, showKills = true, showBanditKills = true, showDeaths = false, showOutbreakDay = false, realistic = false,
    dayCounter = 1, dayRule = 1,
    look = 1, looksRightClick = false, duration = 7, position = 1, textSize = 2, motion = false, showKey = 0,
}

local options
if PZAPI and PZAPI.ModOptions then
    options = PZAPI.ModOptions:create("SurvivorBriefing", "UI_SurvivorBriefing_Title")
    local function tick(id)
        options:addTickBox(id, "UI_SurvivorBriefing_" .. id, DEFAULTS[id], "UI_SurvivorBriefing_" .. id .. "_tooltip")
    end

    options:addTitle("UI_SurvivorBriefing_SectionWhen")
    tick("onArrival")
    tick("onMidnight")
    options:addSlider("dailyHour", "UI_SurvivorBriefing_DailyHour", 0, 23, 1, DEFAULTS.dailyHour, "UI_SurvivorBriefing_DailyHour_tooltip")
    tick("dailySunrise")
    tick("onWake")
    -- Was "onLoad", off by default, until 0.3.1. A new id so the new default reaches everyone
    -- whose ModOptions.ini already holds the old one.
    tick("onLoadSave")
    tick("onResume")
    tick("onTown")

    -- The day of survival is the one line that is always shown.
    options:addTitle("UI_SurvivorBriefing_SectionWhat")
    local counter = options:addComboBox("dayCounter", "UI_SurvivorBriefing_DayCounter", "UI_SurvivorBriefing_DayCounter_tooltip")
    counter:addItem("UI_SurvivorBriefing_DayCounter_Survival", true)
    counter:addItem("UI_SurvivorBriefing_DayCounter_World", false)
    counter:addItem("UI_SurvivorBriefing_DayCounter_Both", false)
    local rule = options:addComboBox("dayRule", "UI_SurvivorBriefing_DayRule", "UI_SurvivorBriefing_DayRule_tooltip")
    rule:addItem("UI_SurvivorBriefing_DayRule_Midnight", true)
    rule:addItem("UI_SurvivorBriefing_DayRule_Elapsed", false)
    tick("showTime")
    tick("showDate")
    tick("showOutbreakDay")
    tick("showName")
    tick("showOccupation")
    tick("showLocation")
    tick("showWeather")
    tick("showKills")
    tick("showBanditKills")
    tick("showDeaths")
    tick("realistic")

    options:addTitle("UI_SurvivorBriefing_SectionLook")
    -- Same order as SB.LOOKS in Card.lua (append only: the saved setting is the index).
    local look = options:addComboBox("look", "UI_SurvivorBriefing_Look", "UI_SurvivorBriefing_Look_tooltip")
    for i, id in ipairs({ "Classic", "Inverted", "Minimal", "Camcorder", "Journal", "CaseFile", "Broadcast", "Agent",
                          "Y2K", "HipHop", "Terminal", "Cinematic", "RPG", "Quarantine", "Newspaper", "Military" }) do
        look:addItem("UI_SurvivorBriefing_Look_" .. id, i == 1)
    end
    -- The looks window. The game sits behind the options screen, so it opens once the player is
    -- back in the game (Admin.openSoon).
    options:addButton("previewLooks", "UI_SurvivorBriefing_PreviewLooks", "UI_SurvivorBriefing_PreviewLooks_tooltip",
        function() if SB.Admin then SB.Admin.openSoon() end end)
    -- Was "looksMenu", on by default, in 1.0.0 (Workshop: "way too many things in the context
    -- menu"). A new id so the new default reaches everyone whose settings already hold the old one.
    options:addTickBox("looksRightClick", "UI_SurvivorBriefing_looksMenu", DEFAULTS.looksRightClick, "UI_SurvivorBriefing_looksMenu_tooltip")
    options:addSlider("duration", "UI_SurvivorBriefing_Duration", 3, 20, 1, DEFAULTS.duration, "UI_SurvivorBriefing_Duration_tooltip")
    local pos = options:addComboBox("position", "UI_SurvivorBriefing_Position", "UI_SurvivorBriefing_Position_tooltip")
    pos:addItem("UI_SurvivorBriefing_Position_BottomLeft", true)
    pos:addItem("UI_SurvivorBriefing_Position_TopLeft", false)
    pos:addItem("UI_SurvivorBriefing_Position_BottomRight", false)
    pos:addItem("UI_SurvivorBriefing_Position_TopRight", false)
    pos:addItem("UI_SurvivorBriefing_Position_Centre", false)
    pos:addItem("UI_SurvivorBriefing_Position_BottomCentre", false)
    pos:addItem("UI_SurvivorBriefing_Position_TopCentre", false)
    local size = options:addComboBox("textSize", "UI_SurvivorBriefing_TextSize", "UI_SurvivorBriefing_TextSize_tooltip")
    size:addItem("UI_SurvivorBriefing_TextSize_Small", false)
    size:addItem("UI_SurvivorBriefing_TextSize_Normal", true)
    size:addItem("UI_SurvivorBriefing_TextSize_Large", false)
    tick("motion")
    -- The name must be the DISPLAYED text, not a translation key. Vanilla labels the row with
    -- getText(name) but finds it again by the raw name (MainOptions.keyPressHandler), so a key
    -- here makes assigning the bind throw "attempted index of non-table".
    options:addKeyBind("showKey", getText("UI_SurvivorBriefing_ShowKey"), DEFAULTS.showKey, "UI_SurvivorBriefing_ShowKey_tooltip")
end

-- ---- Keeping the settings ---------------------------------------------------------------------
-- The game's own ModOptions.ini loses them. PZAPI.ModOptions:save() writes the lines of every mod
-- that is NOT loaded at that moment back without line breaks, so they come out glued into one
-- line that the next load cannot read. A mod that is only switched on for a server is "not
-- loaded" at the main menu, so any options save there wipes what the player chose in game
-- (reported on the Workshop: "position and size reset every time I join my server").
-- So the settings also live in a file of their own. It keeps two things per option: our value,
-- and what the game's file said for that option the last time we looked ("game.<id>"). After
-- every load by the game:
--   the game's file says something new       -> it was saved or edited since: that wins
--   it says the same, or nothing it can read -> our own value wins
-- 0.8.0 let our file win always, and wrote it only from apply(). The Mod Manager mod's options
-- screen saves, RELOADS and only then calls apply(), so the reload put the old values straight
-- back (Workshop: "hit Apply and it resets all the options I change"). Hence the rule above,
-- and our file is now also written right after every save by the game.
local OWN_FILE, GAME_FILE = "SurvivorBriefing.ini", "ModOptions.ini"

local IDS = {}
for id in pairs(DEFAULTS) do table.insert(IDS, id) end
table.sort(IDS)

-- id -> what the game's file held for it at the last look (nil: nothing readable).
local seen = {}

-- On the game's own options screen a new key sits on its row until the game's save copies it
-- over, and apply() runs before that save.
local function getPending(o)
    if o.type == "keybind" and type(o.element) == "table" and o.element.keyCode ~= nil then return o.element.keyCode end
    return o:getValue()
end

local function getStored(o) return o:getValue() end

local function setStored(o, v)
    if o.type == "combobox" then o.selected = v
    elseif o.type == "keybind" then o.key = v
    else o.value = v end
end

-- A value with anything stuck on its end, as in a glued line.
local function parse(default, text)
    if type(default) == "boolean" then
        if text:sub(1, 4) == "true" then return true end
        if text:sub(1, 5) == "false" then return false end
        return nil
    end
    return tonumber(text:match("^%-?%d+%.?%d*"))
end

-- A value that has to be the whole text.
local function exact(default, text)
    if type(default) == "boolean" then
        if text == "true" then return true end
        if text == "false" then return false end
        return nil
    end
    return tonumber(text)
end

local function readAll(name)
    local ok, reader = pcall(getFileReader, name, false)
    if not ok or not reader then return nil end
    local lines = {}
    while true do
        local line = reader:readLine()
        if line == nil then break end
        table.insert(lines, line)
    end
    reader:close()
    return lines
end

-- The game's file as the game itself can read it: whole lines holding one option each. If an
-- option is there twice, the first counts: the game writes the loaded mods' lines first and
-- fresh, and anything further down is a leftover.
local function readGameFile()
    local clean, lines = {}, readAll(GAME_FILE)
    for _, line in ipairs(lines or {}) do
        local id, text = line:match("^%a+|SurvivorBriefing|([%w_]+)|([^|]*)$")
        if id and DEFAULTS[id] ~= nil and clean[id] == nil then clean[id] = exact(DEFAULTS[id], text) end
    end
    return clean, lines
end

local function write(valueOf)
    local ok, writer = pcall(getFileWriter, OWN_FILE, true, false)
    if not ok or not writer then return end
    for _, id in ipairs(IDS) do
        local o = options:getOption(id)
        if o then
            writer:write(id .. "=" .. tostring(valueOf(o)) .. "\r\n")
            if seen[id] ~= nil then writer:write("game." .. id .. "=" .. tostring(seen[id]) .. "\r\n") end
        end
    end
    writer:close()
end

-- From apply(): the options screen has the new values, the game may not have saved them yet.
function SB.saveOptions()
    if options then write(getPending) end
end

-- Right after a save by the game: its file and ours now say the same.
function SB.afterGameSave()
    if not options then return end
    seen = readGameFile()
    write(getStored)
end

-- The first time, there is no file of our own yet: besides what the game could read, take what
-- its file still holds glued together, by looking for "|SurvivorBriefing|<id>|<value>" anywhere.
local function recoverGlued(lines, clean)
    if not lines then return 0 end
    local text, found = table.concat(lines, "\n"), 0
    for _, id in ipairs(IDS) do
        local o = options:getOption(id)
        if o and clean[id] ~= nil then
            setStored(o, clean[id])
            found = found + 1
        elseif o then
            local needle, from, last = "|SurvivorBriefing|" .. id .. "|", 1, nil
            while true do
                local s, e = text:find(needle, from, true)
                if not s then break end
                last, from = e, e + 1
            end
            if last then
                local v = parse(DEFAULTS[id], text:sub(last + 1, last + 24))
                if v ~= nil then setStored(o, v); found = found + 1 end
            end
        end
    end
    return found
end

-- A few things the mod remembers that are not settings (whether the 1.0 welcome was shown).
local STATE_FILE = "SurvivorBriefing_state.ini"

function SB.readState()
    local out = {}
    for _, line in ipairs(readAll(STATE_FILE) or {}) do
        local k, v = line:match("^([%w_]+)=(.*)$")
        if k then out[k] = v end
    end
    return out
end

function SB.writeState(key, value)
    local st = SB.readState()
    st[key] = tostring(value)
    local ok, writer = pcall(getFileWriter, STATE_FILE, true, false)
    if not ok or not writer then return end
    for k, v in pairs(st) do writer:write(k .. "=" .. v .. "\r\n") end
    writer:close()
end

-- Settings changed outside the options screen (the looks window's "Use these settings"): set
-- them and save, through the game's save, which also writes our own file.
function SB.setOptions(values)
    if not options then return end
    for id, v in pairs(values) do
        local o = options:getOption(id)
        if o then setStored(o, v) end
    end
    local ok = pcall(function() PZAPI.ModOptions:save() end)
    if not ok then pcall(SB.saveOptions) end
end

function SB.restoreOptions()
    if not options then return end
    local inGame, gameLines = readGameFile()
    local lines = readAll(OWN_FILE)
    if not lines then
        local found = recoverGlued(gameLines, inGame)
        seen = inGame
        print("[SurvivorBriefing] settings: first run, " .. found .. " value(s) taken from " .. GAME_FILE)
        write(getStored)
        -- Nothing found: a new player, not one updating from 0.x, so no "what's new" for them.
        if found == 0 then SB.writeState("welcome", "1.0") end
        return
    end
    local own, base = {}, {}
    for _, line in ipairs(lines) do
        local into, id, text = base, line:match("^game%.([%w_]+)=(.*)$")
        if not id then
            into = own
            id, text = line:match("^([%w_]+)=(.*)$")
        end
        if id and DEFAULTS[id] ~= nil then into[id] = parse(DEFAULTS[id], text) end
    end
    local ours, theirs, dirty = 0, 0, false
    for _, id in ipairs(IDS) do
        local o = options:getOption(id)
        if o then
            if inGame[id] ~= nil and inGame[id] ~= base[id] then
                setStored(o, inGame[id])
                theirs = theirs + 1
            elseif own[id] ~= nil then
                setStored(o, own[id])
                ours = ours + 1
            end
            if own[id] ~= getStored(o) or base[id] ~= inGame[id] then dirty = true end
        end
    end
    seen = inGame
    if dirty then write(getStored) end
    print("[SurvivorBriefing] settings: " .. ours .. " value(s) from " .. OWN_FILE .. ", " .. theirs .. " newer in " .. GAME_FILE)
end

if options then
    -- The options screen calls this on every options object when the player applies.
    options.apply = function() pcall(SB.saveOptions) end
    local gameLoad, gameSave = PZAPI.ModOptions.load, PZAPI.ModOptions.save
    if type(gameLoad) == "function" then
        PZAPI.ModOptions.load = function(self, ...)
            gameLoad(self, ...)
            local ok, err = pcall(SB.restoreOptions)
            if not ok then print("[SurvivorBriefing] settings not restored: " .. tostring(err)) end
        end
    end
    if type(gameSave) == "function" then
        PZAPI.ModOptions.save = function(self, ...)
            gameSave(self, ...)
            local ok, err = pcall(SB.afterGameSave)
            if not ok then print("[SurvivorBriefing] settings not kept: " .. tostring(err)) end
        end
    end
end

function SB.opt(id)
    local o = options and options:getOption(id)
    if o then
        local v = o:getValue()
        if v ~= nil then return v end
    end
    return DEFAULTS[id]
end
