-- When the briefing shows up. There is no "woke up" or "new character" event, so each local
-- player is polled once per tick; all of these are cheap comparisons.
--   Arrival  - a new IsoPlayer appears with (almost) no hours survived: new game, respawn,
--              first join to a server, split-screen player joining.
--   Load     - a new IsoPlayer appears that has already survived a while: loading a save,
--              rejoining a server. On by default, so someone who adds the mod to a running save
--              sees it work straight away instead of waiting for midnight.
--              Arrival vs Load is decided when the card is due, not on the first tick: on an MP
--              join the server's copy of hours survived may reach the client after the player
--              object does, and deciding early would greet a returning player as "Day 1".
--   Resume   - the pause menu closes (off by default).
--   Midnight - the daily card: at the chosen hour (midnight by default) while the player is
--              awake. Skipped if they woke up within the last two game hours on the same date,
--              because the wake card was their morning briefing.
--   Wake     - isAsleep() goes true -> false. Sleeping through midnight lands here, so the
--              player gets one card on waking instead of one they could not see.
SurvivorBriefing = SurvivorBriefing or {}
local SB = SurvivorBriefing
SB.VERSION = "1.0.1"

SB.cards = SB.cards or {}
SB.state = SB.state or {}

SB.ARRIVAL_DELAY_MS = 3000   -- let the game's own fade-in from black finish first
SB.WAKE_DELAY_MS = 1500
SB.RESUME_DELAY_MS = 400
SB.DAILY_AFTER_WAKE_HOURS = 2
SB.NEW_CHARACTER_HOURS = 0.25

-- A few lines in console.txt, so a bug report can be read without guessing: which version ran,
-- with which switches, and what each load decided.
local function log(msg) print("[SurvivorBriefing] " .. msg) end

-- The time of day the daily briefing is due, in hours: the chosen hour, or the game's own dawn
-- when "at sunrise" is on (asked for on the Workshop). Dawn moves with the season. Under the
-- Endless Day / Endless Night sandbox settings the game has no dawn and reports 0; the chosen
-- hour is used then. Second result: whether it is the sunrise.
local function gameDawn() return getClimateManager():getSeason():getDawn() end
function SB.dailyTime()
    if SB.opt("dailySunrise") then
        local ok, dawn = pcall(gameDawn)
        if ok and type(dawn) == "number" and dawn > 0 and dawn < 24 then return dawn, true end
    end
    return SB.opt("dailyHour") or 0, false
end

-- A number that changes once a day, at the time the daily briefing is set to: the day number
-- of the date it "belongs" to. With the time at 6, 05:59 still counts as yesterday.
function SB.dailyKey(timeSetting)
    local gt = getGameTime()
    local key = SB.Data.dayNumber(gt:getYear(), gt:getMonth() + 1, gt:getDay() + 1)
    if gt:getTimeOfDay() < (timeSetting or 0) then key = key - 1 end
    return key
end

-- Entering a town (asked for on the Workshop). Looked up every couple of seconds, not every tick.
-- A new town has to hold for a few seconds, so skirting an edge or a border flicker is not an
-- arrival, and the same town shows again only after some game hours (leaving to loot a farm and
-- coming back is not a new arrival). The town a player starts in counts as already shown.
SB.TOWN_CHECK_MS = 2000
SB.TOWN_SETTLE_MS = 4000
SB.TOWN_AGAIN_HOURS = 6

local function spot(player)
    local ok, v = pcall(function() return player:getVehicle() end)
    if ok and v then return v:getX(), v:getY() end
    return player:getX(), player:getY()
end

function SB.stepTown(s, player, now, schedule)
    if not SB.opt("onTown") then s.townKnown = nil; return end
    if s.pending or (s.townCheckAt and now < s.townCheckAt) then return end
    s.townCheckAt = now + SB.TOWN_CHECK_MS
    local x, y = spot(player)
    local ok, town = pcall(SB.Places.town, x, y)
    if not ok then return end
    town = town or false
    local age = getGameTime():getWorldAgeHours()
    if not s.townKnown then
        s.townKnown, s.town, s.candidate, s.candidateSince = true, town, town, now
        s.shownTowns = s.shownTowns or {}
        if town then s.shownTowns[town] = age end
        return
    end
    if town ~= s.candidate then s.candidate, s.candidateSince = town, now end
    if town == s.town or now - s.candidateSince < SB.TOWN_SETTLE_MS then return end
    s.town = town
    if not town or player:isAsleep() then return end
    local last = s.shownTowns[town]
    if last and age - last >= 0 and age - last < SB.TOWN_AGAIN_HOURS then return end
    s.shownTowns[town] = age
    log("entered " .. tostring(town))
    schedule(s, "Town", 0, now)
end

-- over (optional): look, position, textSize, motion to use instead of the options (the looks
-- test window shows a look without changing the player's settings).
function SB.show(playerNum, kind, over)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    local old = SB.cards[playerNum]
    if old then old:close() end
    over = over or {}
    local function pick(id) if over[id] ~= nil then return over[id] end return SB.opt(id) end
    local ok, err = pcall(function()
        local card = SB.Card:new(playerNum, SB.Data.collect(player), SB.opt("duration"), pick("textSize"),
            pick("position"), pick("motion"), pick("look"))
        card:show()
        SB.cards[playerNum] = card
        return card.lookId
    end)
    if ok then
        log("briefing shown for player " .. playerNum .. " (" .. tostring(kind) .. ", look " .. tostring(err) .. ")")
    else
        log("could not show the briefing: " .. tostring(err))
    end
end

local function schedule(s, kind, delayMs, now)
    -- A newer reason replaces an older pending one; a new player's first card is never replaced.
    if s.pending and s.pending.kind == "Spawn" then return end
    s.pending = { kind = kind, at = now + delayMs }
end

-- New character or an existing one? Hours survived that grew only by the game time passed
-- since the player object appeared (plus a margin) mean a new character.
local function spawnKind(s, player)
    local passed = getGameTime():getWorldAgeHours() - s.seenAge
    if player:getHoursSurvived() <= passed + SB.NEW_CHARACTER_HOURS then
        if SB.opt("onArrival") then return "Arrival" end
        log("new character, but 'Show on a new character' is off: no briefing")
        return nil
    end
    if SB.opt("onLoadSave") then return "Load" end
    log("existing character loaded, but 'Show when loading a save' is off: next briefing at midnight or after sleep")
    return nil
end

-- One poll of one local player. Split out from the tick handler so it can be tested.
function SB.step(i, player, now, today)
    local s = SB.state[i]
    if not s or s.player ~= player then
        s = { player = player, day = today, asleep = player:isAsleep(), seenAge = getGameTime():getWorldAgeHours() }
        SB.state[i] = s
        schedule(s, "Spawn", SB.ARRIVAL_DELAY_MS, now)
        return
    end

    local asleep = player:isAsleep()
    local age = getGameTime():getWorldAgeHours()
    if s.asleep and not asleep then
        s.day = today
        s.wokeAge = age
        s.wokeDate = SB.dailyKey(0)
        if SB.opt("onWake") then schedule(s, "Wake", SB.WAKE_DELAY_MS, now) end
    end
    s.asleep = asleep
    if today ~= s.day then
        s.day = today
        -- Only when the wake card already showed today's date; a nap that ends before midnight
        -- must not swallow the midnight card.
        local justWoke = s.wokeAge ~= nil and age - s.wokeAge >= 0 and age - s.wokeAge < SB.DAILY_AFTER_WAKE_HOURS
            and s.wokeDate == SB.dailyKey(0)
        if not asleep and not justWoke and SB.opt("onMidnight") then schedule(s, "Midnight", 0, now) end
    end

    if s.pending and now >= s.pending.at and not asleep then
        local kind = s.pending.kind
        s.pending = nil
        if kind == "Spawn" then kind = spawnKind(s, player) end
        if kind then SB.show(i, kind) end
    end
    SB.stepTown(s, player, now, schedule)
end

local function onTick()
    local now = getTimestampMs()
    local time, sunrise = SB.dailyTime()
    local today = SB.dailyKey(time)
    -- Moving the hour in the options, or switching to sunrise, shifts the key by itself; that is
    -- not a new day. (Dawn itself drifts by a minute or two a day, which is not a change.)
    local setting = sunrise and "sunrise" or time
    if SB.lastDailyHour ~= setting then
        SB.lastDailyHour = setting
        for i = 0, 3 do
            if SB.state[i] then SB.state[i].day = today end
        end
    end
    for i = 0, 3 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            SB.step(i, player, now, today)
        end
    end
end

-- The in-game pause menu is the main screen shown over the game (the same test vanilla's
-- ISSleepingUI uses). In single player the game is paused while it is up, so this runs on the
-- event that keeps firing when paused.
function SB.menuOpen()
    local ok, open = pcall(function()
        return MainScreen.instance ~= nil and MainScreen.instance.inGame == true and MainScreen.instance:isReallyVisible()
    end)
    return ok and open == true
end

function SB.stepMenu(open, now)
    if SB.menuWasOpen and not open and SB.opt("onResume") then
        for i = 0, 3 do
            local s = SB.state[i]
            if s then schedule(s, "Resume", SB.RESUME_DELAY_MS, now) end
        end
    end
    SB.menuWasOpen = open
end

local function onTickEvenPaused()
    SB.stepMenu(SB.menuOpen(), getTimestampMs())
end

local function onKeyPressed(key)
    local bound = SB.opt("showKey")
    if not bound or bound == 0 or key ~= bound then return end
    local player = getSpecificPlayer(0)
    if not player or player:isDead() or player:isAsleep() then return end
    local card = SB.cards[0]
    if card and not card.dismissAt then
        card:dismiss()
    else
        SB.show(0, "Manual")
    end
end

local function onGameStart()
    -- Not read from mod.info: the copy on the Workshop was found carrying a mod.info from 0.1.5
    -- next to 0.9.1 code, which made every log say the wrong version. pack.sh keeps the two equal.
    local version = SB.VERSION
    local on = {}
    for _, id in ipairs({ "onArrival", "onMidnight", "onWake", "onLoadSave", "onResume", "onTown", "realistic", "motion" }) do
        if SB.opt(id) then table.insert(on, id) end
    end
    SB.lastDailyHour = nil
    log("v" .. tostring(version) .. " ready; on: " .. table.concat(on, ", ")
        .. "; daily at " .. (SB.opt("dailySunrise") and "sunrise" or (tostring(SB.opt("dailyHour")) .. ":00")) .. "; position "
        .. tostring(SB.POSITIONS[SB.opt("position")] or "?") .. ", text size " .. tostring(SB.opt("textSize"))
        .. ", look " .. tostring(SB.LOOKS and SB.LOOKS[SB.opt("look")] or "?"))
end

Events.OnGameStart.Add(onGameStart)
Events.OnTick.Add(onTick)
if Events.OnTickEvenPaused then Events.OnTickEvenPaused.Add(onTickEvenPaused) end
Events.OnKeyPressed.Add(onKeyPressed)
