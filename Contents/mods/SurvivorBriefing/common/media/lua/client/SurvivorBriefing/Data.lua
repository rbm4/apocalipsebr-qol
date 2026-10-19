-- Gathers everything the briefing card shows into plain strings.
SurvivorBriefing = SurvivorBriefing or {}
local SB = SurvivorBriefing

local Data = {}
SB.Data = Data

-- Julian day number of a Gregorian date (month 1-12, day 1-31).
function Data.dayNumber(y, m, d)
    local a = math.floor((14 - m) / 12)
    local yy = y + 4800 - a
    local mm = m + 12 * a - 3
    return d + math.floor((153 * mm + 2) / 5) + 365 * yy + math.floor(yy / 4)
        - math.floor(yy / 100) + math.floor(yy / 400) - 32045
end

-- The Knox Event began on July 4, 1993: a caller on KnoxTalk Radio says so in game, and the usual
-- start, July 9, is the day the outbreak is officially confirmed. July 4 is outbreak day 1, the
-- way a character's first day is Day 1. Nothing before it.
Data.OUTBREAK_JDN = Data.dayNumber(1993, 7, 4)
function Data.outbreakDay(jdn)
    local n = jdn - Data.OUTBREAK_JDN + 1
    if n >= 1 then return n end
    return nil
end

-- 1 = Monday ... 7 = Sunday
function Data.weekday(jdn)
    return jdn % 7 + 1
end

-- Calendar day of survival: the day you arrived is Day 1 and it turns over at midnight, so
-- someone who spawned at 23:00 is on Day 2 an hour later. Derived from hours survived rather
-- than stored, so it is right for existing characters and after an MP rejoin.
function Data.survivalDay(jdnNow, timeOfDay, hoursSurvived)
    local spawnDay = math.floor(jdnNow + timeOfDay / 24 - hoursSurvived / 24 + 1e-6)
    return math.max(1, jdnNow - spawnDay + 1)
end

-- The other way to count your own days: Day 2 starts once 24 hours have been survived. This
-- stays in step with the "Survived for" time on the character panel, where the calendar count
-- above can be one or two ahead (39 hours survived across two midnights is calendar Day 3).
function Data.survivalDayElapsed(hoursSurvived)
    return math.floor(hoursSurvived / 24) + 1
end

-- Bandits (Workshop 3268487204) keeps a bandit kill count per character, the one it draws on
-- the character screen. Shown when that mod is loaded and its own "Bandit kill counter" sandbox
-- option is on; nothing here needs Bandits to be installed.
function Data.banditKills(player)
    if type(GetBanditModData) ~= "function" or type(BanditUtils) ~= "table"
        or type(BanditUtils.GetCharacterID) ~= "function" then
        return nil
    end
    if SandboxVars and SandboxVars.Bandits and SandboxVars.Bandits.General_KillCounter == false then return nil end
    local gmd = GetBanditModData()
    if type(gmd) ~= "table" or type(gmd.Kills) ~= "table" then return nil end
    local n = gmd.Kills[BanditUtils.GetCharacterID(player)]
    return type(n) == "number" and n or 0
end

-- "Only what your character can know": nobody keeps an exact tally for long. Up to a hundred
-- the number is exact; after that it is a floor ("Over 300", "Over a thousand").
function Data.killsText(n, realistic)
    if not realistic or n < 100 then return string.format("%d", n) end
    if n < 1000 then return getText("IGUI_SurvivorBriefing_Over", string.format("%d", math.floor(n / 100) * 100)) end
    if n < 2000 then return getText("IGUI_SurvivorBriefing_OverThousand") end
    return getText("IGUI_SurvivorBriefing_OverThousands", string.format("%d", math.floor(n / 1000)))
end

-- The world's day: Day 1 is the world's first day (the server's, in multiplayer), however
-- many characters have lived and died since. The start date is the sandbox start date, which
-- SandboxOptions.applySettings copies into GameTime on servers and clients alike; GameTime's own
-- world age is not sent to multiplayer clients, so it can't be used for this.
function Data.worldDay(jdnNow, gt)
    local y, m, d = gt:getStartYear(), gt:getStartMonth() + 1, gt:getStartDay() + 1
    if not y or y < 1000 then return nil end
    return math.max(1, jdnNow - Data.dayNumber(y, m, d) + 1)
end

function Data.clock(hour, minute, use24)
    if use24 then return string.format("%02d:%02d", hour, minute) end
    local h = hour % 12
    if h == 0 then h = 12 end
    return getText(hour < 12 and "IGUI_SurvivorBriefing_AM" or "IGUI_SurvivorBriefing_PM",
        string.format("%d:%02d", h, minute))
end

-- Without a watch a survivor can still read the sky.
Data.DAY_PARTS = { "Night", "EarlyMorning", "Morning", "Midday", "Afternoon", "Evening" }

function Data.dayPart(hour)
    if hour < 5 or hour >= 22 then return "Night" end
    if hour < 8 then return "EarlyMorning" end
    if hour < 12 then return "Morning" end
    if hour < 14 then return "Midday" end
    if hour < 18 then return "Afternoon" end
    return "Evening"
end

-- The time as the card shows it: the clock, or only the part of the day when the character
-- has no way to tell the time. The card re-reads it whenever the game minute changes, so it
-- keeps running while the briefing is on screen.
function Data.timeText(exact)
    local gt = getGameTime()
    if exact then return Data.clock(gt:getHour(), gt:getMinutes(), getCore():getOptionClock24Hour()) end
    return getText("IGUI_SurvivorBriefing_Part_" .. Data.dayPart(gt:getHour()))
end

-- Every shape timeText can take, so the card can reserve room for the widest one.
function Data.timeSamples(exact)
    local out = {}
    if exact then
        local use24 = getCore():getOptionClock24Hour()
        for _, h in ipairs({ 0, 10, 12, 20, 23 }) do
            for _, m in ipairs({ 0, 48, 58 }) do table.insert(out, Data.clock(h, m, use24)) end
        end
    else
        for _, part in ipairs(Data.DAY_PARTS) do table.insert(out, getText("IGUI_SurvivorBriefing_Part_" .. part)) end
    end
    return out
end

-- Does the character carry a timepiece, and is it digital? This is the vanilla HUD clock's own
-- rule (zombie.ui.Clock.resize): a watch or clock counts only while worn or held in a hand, not
-- sitting in a bag, and only a digital one also tells the date and the temperature.
function Data.watch(player)
    local has, digital = false, false
    local function look(item)
        if item and (instanceof(item, "AlarmClock") or instanceof(item, "AlarmClockClothing")) then
            has = true
            if item:hasTag(ItemTag.DIGITAL) then digital = true end
        end
    end
    local worn = player:getWornItems()
    for i = 0, worn:size() - 1 do look(worn:getItemByIndex(i)) end
    if not has then
        local items = player:getInventory():getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item:isWorn() or item:isEquipped() then look(item) end
        end
    end
    return has, digital
end

-- What the character can know. With the "realistic" option off, everything.
function Data.knowledge(player, realistic)
    if not realistic then return { time = true, date = true, temperature = true } end
    local ok, has, digital = pcall(Data.watch, player)
    if not ok then
        print("[SurvivorBriefing] " .. tostring(has))
        return { time = true, date = true, temperature = true }
    end
    return { time = has, date = has and digital, temperature = has and digital }
end

function Data.skyKey(storm, precip, snow, wind, fog, cloud)
    if storm then return "Storm" end
    if precip > 0.05 then
        if snow then
            if precip > 0.6 and wind > 0.5 then return "Blizzard" end
            return precip > 0.5 and "HeavySnow" or "Snow"
        end
        if precip > 0.6 then return "HeavyRain" end
        return precip < 0.25 and "LightRain" or "Rain"
    end
    if fog > 0.4 then return "Fog" end
    if cloud < 0.2 then return "Clear" end
    if cloud < 0.5 then return "PartlyCloudy" end
    if cloud < 0.8 then return "Cloudy" end
    return "Overcast"
end

local function weather(withTemperature)
    local cm = getClimateManager()
    local key = Data.skyKey(cm:getIsThunderStorming(), cm:getPrecipitationIntensity(),
        cm:getPrecipitationIsSnow(), cm:getWindIntensity(), cm:getFogIntensity(), cm:getCloudIntensity())
    if not withTemperature then return getText("IGUI_SurvivorBriefing_Sky_" .. key) end
    local t = cm:getTemperature()
    local temp = string.format("%d", Temperature.getRoundedDisplayTemperature(t)) .. Temperature.getTemperaturePostfix()
    return getText("IGUI_SurvivorBriefing_WeatherLine", getText("IGUI_SurvivorBriefing_Sky_" .. key), temp)
end

local function occupation(desc)
    local prof = desc:getCharacterProfession()
    if not prof then return nil end
    local def = CharacterProfessionDefinition.getCharacterProfessionDefinition(prof)
    return def and def:getUIName() or nil
end

-- Each lookup is guarded separately: a failure in one line must not cost the whole card.
local function try(fn, ...)
    local ok, v, v2 = pcall(fn, ...)
    if ok then return v, v2 end
    print("[SurvivorBriefing] " .. tostring(v))
    return nil
end

-- Every line except the day can be switched off in the options; a line the character cannot
-- know (see Data.knowledge) is left out or made vaguer.
function Data.collect(player)
    local gt = getGameTime()
    local jdn = Data.dayNumber(gt:getYear(), gt:getMonth() + 1, gt:getDay() + 1)
    local know = Data.knowledge(player, SB.opt("realistic"))
    if SB.opt("realistic") then
        print("[SurvivorBriefing] character knows: time " .. tostring(know.time) .. ", date " .. tostring(know.date)
            .. ", temperature " .. tostring(know.temperature) .. " (a worn watch or a held clock; digital for date and temperature)")
    end
    local info = {}
    -- Day counter: 1 your day of survival, 2 the world's day, 3 both (world day as a row).
    -- Day rule: 1 a new day at midnight (calendar), 2 a new day every 24 hours survived.
    local survival
    if SB.opt("dayRule") == 2 then
        survival = Data.survivalDayElapsed(player:getHoursSurvived())
    else
        survival = Data.survivalDay(jdn, gt:getTimeOfDay(), player:getHoursSurvived())
    end
    local counter = SB.opt("dayCounter") or 1
    local world = counter ~= 1 and try(Data.worldDay, jdn, gt) or nil
    info.day = (counter == 2 and world) or survival
    if counter == 3 and world then
        info.worldDay = string.format("%d", world)
        info.worldDayLabel = getText(isClient() and "IGUI_SurvivorBriefing_ServerDay" or "IGUI_SurvivorBriefing_WorldDay")
    end
    -- Worked out from the date, so it needs the date known, like the date line.
    if SB.opt("showOutbreakDay") and know.date then
        local n = Data.outbreakDay(jdn)
        if n then info.outbreakDay = string.format("%d", n) end
    end
    if SB.opt("showTime") then
        info.exactTime = know.time
        info.clock = Data.timeText(know.time)
    end
    if SB.opt("showDate") and know.date then
        info.date = getText("IGUI_SurvivorBriefing_Date",
            getText("IGUI_SurvivorBriefing_Weekday" .. Data.weekday(jdn)),
            getText("IGUI_SurvivorBriefing_Month" .. (gt:getMonth() + 1)),
            string.format("%d", gt:getDay() + 1), string.format("%d", gt:getYear()))
    end
    -- For the looks that need the parts: what the character knows, the date and time as
    -- numbers (only when known), first and last name, where on the map.
    info.know = know
    info.realistic = SB.opt("realistic") and true or false
    if SB.opt("showDate") and know.date then
        info.month, info.dom, info.year = gt:getMonth() + 1, gt:getDay() + 1, gt:getYear()
    end
    if SB.opt("showTime") and know.time then info.hour, info.min = gt:getHour(), gt:getMinutes() end
    local desc = player:getDescriptor()
    if SB.opt("showName") then
        info.name = try(function() return (desc:getForename() .. " " .. desc:getSurname()):match("^%s*(.-)%s*$") end)
        info.first = try(function() return desc:getForename() end)
        info.last = try(function() return desc:getSurname() end)
    end
    if SB.opt("showOccupation") then info.occupation = try(occupation, desc) end
    if SB.opt("showLocation") then
        -- In a vehicle, ask the vehicle where it is.
        local x, y = player:getX(), player:getY()
        local vehicle = try(function() return player:getVehicle() end)
        if vehicle then x, y = vehicle:getX(), vehicle:getY() end
        info.x, info.y = x, y
        info.place, info.near = try(SB.Places.describe, x, y, getCore():getOptionDisplayAsCelsius())
    end
    if SB.opt("showWeather") then info.weather = try(weather, know.temperature) end
    if SB.opt("showKills") then
        info.kills = try(function() return Data.killsText(player:getZombieKills(), SB.opt("realistic")) end)
    end
    if SB.opt("showBanditKills") then
        local n = try(Data.banditKills, player)
        if n then
            info.banditKills = Data.killsText(n, SB.opt("realistic"))
            -- Bandits' own label where it has one, so it reads the same as on its character screen.
            local ok, own = pcall(getTextOrNull, "IGUI_Bandits_Bandits_Killed")
            info.banditKillsLabel = (ok and own and own ~= "" and own) or getText("IGUI_SurvivorBriefing_BanditKills")
        end
    end
    if SB.opt("showDeaths") then
        info.deaths = try(function() return string.format("%d", SB.Deaths.count()) end)
    end
    return info
end
