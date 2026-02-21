require "ISUI/ISLayoutManager"
require "ISUI/ISContextMenu"
pcall(require, "TTF_Stats_ModOptions")
-- require "TWITCHSTATS_ContextMenu"

TwisTonFireStats = TwisTonFireStats or {}

STATSTabClass = ISPanel:derive("STATSTab")

-- This table remains global for the UI
STATSTab = {}
STATSTab.showCalendar = true
STATSTab.showKills = true
STATSTab.showTraveled = true
STATSTab.showWeight = true
STATSTab.showDailyKills = true
STATSTab.showAvgKills = true
STATSTab.calendarMode = 1
STATSTab.positions = {
    calendar = -15,
    kills = 25,
    traveled = 65,
    weight = 105,
    dailyKills = 145,
    avgKills = 185,
}

print("----------------LOADING TWITCH STATS UI ------------------")
local modId = "\\twistonfirestats"
local lastPosition = {x = 0, y = 0}
local distanceTracker = 0
local saveInterval = 5
local nextInterval = getTimestamp()

-- Textures
local calendarTexture   		= getTexture("media/ui/calendar.png")
local zedsKillsTexture  		= getTexture("media/ui/zedkills.png")
local traveledTexture   		= getTexture("media/ui/travelled.png")
local weightTexture    		 	= getTexture("media/ui/peso.png")
local dailyTexture      		= getTexture("media/ui/daily.png")
local avgTexture        		= getTexture("media/ui/schnitt.png")
local indicatorHighTexture 		= getTexture("media/ui/indicator_high.png")
local indicatorLowTexture  		= getTexture("media/ui/indicator_low.png")
local indicatorHighHighTexture 	= getTexture("media/ui/indicator_highhigh.png")
local indicatorLowLowTexture  	= getTexture("media/ui/indicator_lowlow.png")
local fontTexture				= getTexture("media/ui/font.png")
local alignTexture				= getTexture("media/ui/align.png")
local SAVE_DIR = "stats/"

local function ensureStatsFolder()
    if createFolder then
        createFolder(SAVE_DIR)
    end
end

local function getFontForStats(fontSizeMode)
    if fontSizeMode == 2 then
        return UIFont.Medium
    elseif fontSizeMode == 3 then
        return UIFont.Small
    else
        return UIFont.Large
    end
end

local colorModes = {
    {1, 1, 1},
    {1, 0.4, 0},
    {0.57, 0.27, 1},
    {0.2, 1, 0.2},
    {0, 0.8, 1},
}

local SAVE_ALIVE    = 1
local SAVE_KILLS    = 2
local SAVE_DISTANCE = 4
local SAVE_ALL      = SAVE_ALIVE + SAVE_KILLS + SAVE_DISTANCE

local function EnsureStatsUi()
    if STATSTab and STATSTab.setVisible then return STATSTab end
    local x, y = LoadUi()
    STATSTab = STATSTabClass:new(x, y, 120, 160)
    STATSTab:addToUIManager()
    STATSTab:setVisible(true)
    if STATSTab.updatePositions then STATSTab:updatePositions() end
    return STATSTab
end

local function HasFlag(value, flag)
    return PZMath.floor(value / flag) % 2 ~= 0
end

local function InitializeMod(playerNum, player)
    print("--------TWITCH STATS LOADED----------")

    -- Ensure the UI is up
    if STATSTab and STATSTab.setVisible then
        STATSTab:setVisible(true)
        return
    end
    local x, y = LoadUi()
    STATSTab = STATSTabClass:new(x, y, 120, 160)
    STATSTab:addToUIManager()
    STATSTab:setVisible(true)
    if STATSTab.updatePositions then STATSTab:updatePositions() end

    -- Monotonic restore from modData ONLY (no file fallback)
    local modData = player and player:getModData() or nil
    if not modData then
        modData = {}
        if player and player.setModData then player:setModData(modData) end
    end

    local persisted = tonumber(modData.distanceTracker) or 0
    local maxMark  = tonumber(modData.distanceMax) or 0

    -- Use the highest known value; never start below it
    local baseline = math.max(persisted, maxMark)
    if baseline < 0 or baseline ~= baseline then baseline = 0 end

    modData.distanceTracker = baseline
    modData.distanceMax     = baseline
    distanceTracker         = baseline

    -- Daily-kill baseline
    if not modData.killsAtMidnight then
        modData.killsAtMidnight = player:getZombieKills()
    end
    killsAtMidnight = modData.killsAtMidnight
end
Events.OnCreatePlayer.Add(InitializeMod)

local function StopStatsUi()
    if STATSTab then
        SaveUi()
        STATSTab:setVisible(false)
    end
end

local killsAtMidnight = 0
local CHARACTER_DAILY_RECORD = "dailyKillRecord"

local function GetPlayerName(player)
    return player:getUsername() or player:getDisplayName() or "Unknown"
end

local function SaveDailyKillRecord(player, record)
    local writer = getFileWriter("daily_kill_record.txt", true, false)
    if writer then
        writer:write(tostring(record))
        writer:close()
    else
        print("Error: Could not write to daily_kill_record.txt (file handle nil).")
    end
end

local function ensureUniqueLogWithHeader(playerObj)
    ensureStatsFolder()

    local uniqueID = SetOrGetPersistentUniqueID(playerObj)
    if not uniqueID then return end

    local path = SAVE_DIR .. uniqueID .. ".txt"
    local exists = false
    local reader = getFileReader(path, false)
    if reader then
        exists = true
        reader:close()
    end
    if not exists then
        local writer = getFileWriter(path, false, false)
        if writer then
            writer:write("forename,surname,zkills,dailykills,averagekills,dayssurvived,date\n")
            writer:close()
        else
            print("Error: Could not write header to " .. path .. " (file handle nil).")
        end
    end
end

local function UniqueCharacterLog(player)
    ensureStatsFolder()

    local uniqueID = SetOrGetPersistentUniqueID(player)
    if not uniqueID then return end

    local desc = player:getDescriptor()
    local forename = desc and desc:getForename() or ""
    local surname  = desc and desc:getSurname()  or ""

    -- Leerzeichen/Tabs aus Namen raus, aber leere Felder erlauben
    local function cleanOrEmpty(s) return (s and s:gsub("[%s\t]", "")) or "" end
    forename = cleanOrEmpty(forename)
    surname  = cleanOrEmpty(surname)

    local zkills = player:getZombieKills()
    local hoursSurvived = player:getHoursSurvived() or 0
    local daysSurvived = math.floor(hoursSurvived / 24)
    local date = os.date("%Y-%m-%d")

    local modData = player:getModData()
    local killsAtMidnight = modData and modData.killsAtMidnight or 0
    local dailyKills = zkills - killsAtMidnight
    local averageKills = (daysSurvived > 0) and (zkills / daysSurvived) or 0

    local newLine = string.format("%s,%s,%d,%d,%.2f,%d,%s",
        forename,
        surname,
        tonumber(zkills) or 0,
        tonumber(dailyKills) or 0,
        averageKills,
        daysSurvived,
        tostring(date)
    )

    local path = SAVE_DIR .. uniqueID .. ".txt"
    local writer = getFileWriter(path, false, true)
    if writer then
        writer:write(newLine .. "\n")
        writer:close()
    else
        print("Error: Could not write to " .. path)
    end
end

local function ResetDailyKills()
    local player = getPlayer()
    if not player then return end

    local modData = player:getModData()
    if not modData then return end

    local currentKills = player:getZombieKills()
    local baseKills = modData.killsAtMidnight or 0
    local dailyKills = math.max(0, currentKills - baseKills)

    UniqueCharacterLog(player)

    if not modData[CHARACTER_DAILY_RECORD] then
        modData[CHARACTER_DAILY_RECORD] = dailyKills
        SaveDailyKillRecord(player, dailyKills)
    elseif dailyKills > (modData[CHARACTER_DAILY_RECORD] or 0) then
        modData[CHARACTER_DAILY_RECORD] = dailyKills
        SaveDailyKillRecord(player, dailyKills)
    end

    modData.killsAtMidnight = currentKills
    killsAtMidnight = modData.killsAtMidnight
end
Events.EveryDays.Add(ResetDailyKills)

local function UpdateDistance(player)
    if not player then return end
    local modData = player:getModData()
    if not modData then
        print('-- NO Player ModData --')
        return
    end

    local persisted = tonumber(modData.distanceTracker) or 0
    local maxMark   = tonumber(modData.distanceMax) or 0

    -- Keep in-memory tracker at least as large as any persisted marks
    if persisted > distanceTracker then distanceTracker = persisted end
    if maxMark   > distanceTracker then distanceTracker = maxMark   end

    -- Position delta
    local currentX = player:getX()
    local currentY = player:getY()
    if lastPosition.x == 0 and lastPosition.y == 0 then
        lastPosition.x = currentX
        lastPosition.y = currentY
        return 0
    end

    local dx = currentX - lastPosition.x
    local dy = currentY - lastPosition.y
    local d  = math.sqrt(dx * dx + dy * dy) or 0
    lastPosition.x = currentX
    lastPosition.y = currentY
    if d ~= d or d < 0 then d = 0 end

    distanceTracker = distanceTracker + d

    -- Monotonic persist: only ever move forward in modData
    local newVal = distanceTracker
    local floorVal = math.max(persisted, maxMark)
    if newVal < floorVal then
        -- Never let memory dip below our best-known value
        newVal = floorVal
        distanceTracker = floorVal
    end

    if newVal > persisted then
        modData.distanceTracker = newVal
    end
    if newVal > maxMark then
        modData.distanceMax = newVal
    end
end
Events.OnPlayerMove.Add(UpdateDistance)

local function GetDistanceTraveled()
    if not distanceTracker then return 0, 0 end
    local km = math.floor(distanceTracker / 1000)
    local meters = math.floor(distanceTracker % 1000)
    return km, meters
end

local function getFatigueColor(fatigue)
    if fatigue < 0.15 then
        return 0.1, 0.5, 0.1
    elseif fatigue < 0.30 then
        return 0.2, 1, 0.2
    elseif fatigue < 0.50 then
        return 1, 1, 0
    elseif fatigue < 0.55 then
        return 1, 0.4, 0
    elseif fatigue < 0.60 then
        return 0.57, 0.27, 1
    else
        return 1, 0, 0
    end
end

local function getColorModeRGB(mode)
    mode = tonumber(mode)
    if not mode or not colorModes[mode] then
        print("Warning: Invalid colorMode: " .. tostring(mode) .. ". Resetting to 1.")
        return 1, 1, 1
    end
    local c = colorModes[mode]
    return c[1], c[2], c[3]
end

local function UpdateAlive()
    local player = getPlayer()
    if not player then return end
    SaveFiles(player, SAVE_ALIVE)
end
Events.EveryTenMinutes.Add(UpdateAlive)

local function UpdateZKill()
    local player = getPlayer()
    if not player then return end
    SaveFiles(player, SAVE_KILLS)
end
Events.OnZombieDead.Add(UpdateZKill)

local function GetPlayerWeight(player)
    if not player or not player:getNutrition() then return 0 end
    return string.format("%.1f", player:getNutrition():getWeight())
end

local function getWeightColor(weight, colorMode)
    local w = tonumber(weight)
    if not w then
        return getColorModeRGB(colorMode)
    end
    if w <= 75 or w >= 85 then
        return 1, 0.2, 0.2
    elseif (w > 75 and w < 76.5) or (w > 83.5 and w < 85) then
        return 1, 0.85, 0
    elseif w >= 76 and w <= 84 then
        return getColorModeRGB(colorMode)
    end
    return getColorModeRGB(colorMode)
end

function SaveFiles(player, flag)
    -- swallow-all helper: open, write, close without ever throwing
    local function tryWrite(path, text, append)
        -- getFileWriter can itself throw; guard it
        local ok, writer = pcall(getFileWriter, path, append == true, false)
        if not ok or not writer then
            return false
        end
        -- writer:write() may NPE internally if the Java writer is nil; guard it
        pcall(function()
            writer:write(text)
        end)
        -- always try to close, but never let it throw
        pcall(function()
            writer:close()
        end)
        return true
    end

    if HasFlag(flag, SAVE_ALIVE) and player then
        local timeSurvived = player:getTimeSurvived()
        if timeSurvived then
            tryWrite("timealive.txt", tostring(timeSurvived), true)
        end
    end

    if HasFlag(flag, SAVE_KILLS) and player then
        local totalKills = player:getZombieKills()
        if totalKills then
            tryWrite("zkills.txt", tostring(totalKills), true)
        end
    end

    if HasFlag(flag, SAVE_DISTANCE) then
        local km, meters = GetDistanceTraveled()
        tryWrite("distance.txt", string.format("%d km %d m", km, meters), true)
    end

    if HasFlag(flag, SAVE_ALL) then
        -- even if PTraits fails, never bubble
        pcall(PTraits)
    end
end

function PTraits()
    local player = getPlayer()
    if not player then return end
    local tempvar = player:getTraits()
    local writer = getFileWriter("PlayerTraits.txt", true, false)
    if not writer then
        print("Error: Could not write to PlayerTraits.txt")
        return
    end

    local alltraits = TraitFactory
    local CleanTraits = ""
    local stuff = string.gsub(tostring(tempvar), "TraitCollection", "")
    writer:write("Build: ")
    CleanTraits = string.sub(stuff, 2, -2)
    CleanTraits = string.gsub(CleanTraits, ", ", ",")
    for k in string.gmatch(CleanTraits, "([^,]+)") do
        local trait = alltraits.getTrait(k)
        if trait then
            local label = trait:getLabel()
            writer:write(label .. " | ")
        end
    end
    writer:close()
end

--########################## Interface ################################
-- Initializes, Render and Events
function STATSTabClass:initialise()
    ISPanel.initialise(self)

    -- Read user settings only (Lua path). No mod-folder usage.
    local settingsReader = getFileReader("TWSTATSsettings.txt", false)
    if settingsReader then
        self.showCalendar   = settingsReader:readLine() == "true"
        self.showKills      = settingsReader:readLine() == "true"
        self.showTraveled   = settingsReader:readLine() == "true"
        self.showWeight     = settingsReader:readLine() == "true"
        self.showDailyKills = settingsReader:readLine() == "true"
        self.showAvgKills   = settingsReader:readLine() == "true"

        local colorModeLine    = settingsReader:readLine()
        local fontSizeLine     = settingsReader:readLine()
        local alignLine        = settingsReader:readLine()
        local calendarModeLine = settingsReader:readLine()
        settingsReader:close()

        self.colorMode     = tonumber(colorModeLine)
        self.fontSizeMode  = tonumber(fontSizeLine)
        self.alignmentMode = (alignLine == "right") and "right" or (alignLine == "left" and "left" or nil)
        self.calendarMode  = tonumber(calendarModeLine)
    end

    -- Script defaults (your chosen standards), used if file missing or values invalid
    if self.showCalendar   == nil then self.showCalendar   = true end
    if self.showKills      == nil then self.showKills      = true end
    if self.showTraveled   == nil then self.showTraveled   = true end
    if self.showWeight     == nil then self.showWeight     = true end
    if self.showDailyKills == nil then self.showDailyKills = true end
    if self.showAvgKills   == nil then self.showAvgKills   = true end

    if type(self.colorMode)     ~= "number" then self.colorMode     = 2 end
    if type(self.fontSizeMode)  ~= "number" then self.fontSizeMode  = 1 end
    if self.alignmentMode       ~= "right" and self.alignmentMode ~= "left" then
        self.alignmentMode = "left"
    end
    if type(self.calendarMode)  ~= "number" then self.calendarMode  = 1 end

    -- Panel internals
    self.positions = {
        calendar   = -15,
        kills      = 25,
        traveled   = 65,
        weight     = 105,
        dailyKills = 145,
        avgKills   = 185,
    }
    self.lastCalendarWidth = 120

    -- Safe call; will early-return if UI not yet fully ready.
    if self.updatePositions then self:updatePositions() end
end

function STATSTabClass:new(x, y, w, h)     
    local stats = ISPanel:new(x, y, w, h)     
    setmetatable(stats, self)     
    self.__index = self
    stats.background = false     
    stats.moveWithMouse = true
	stats.lastCalendarWidth = 120
    stats:initialise()
    return stats 
end

local function drawTextCenteredVertical(ui, text, x, y, w, h, r, g, b, a, font, alignRight)
    local fontHeight = getTextManager():getFontHeight(font)
    local textY = y + (h - fontHeight) / 2
    if alignRight then
        ui:drawTextRight(text, x + w, textY, r, g, b, a, font)
    else
        ui:drawText(text, x, textY, r, g, b, a, font)
    end
end

function STATSTabClass:render()
    local player = getPlayer()
    if not player then return end

    if not self.positions then
        print("ERROR: positions is nil in render!")
        return
    end

    -- Robust font height here as well
    local font       = getFontForStats(self.fontSizeMode or 1)
    local tm         = getTextManager()
    local fontHeight = 24
    if tm and tm.getFontHeight and font then
        local fh = tm:getFontHeight(font)
        fh = tonumber(fh) or 24
        if fh > 0 then fontHeight = fh end
    end

    local boxHeight   = fontHeight + 10
    local iconSize    = math.max(20, math.min(math.floor(fontHeight * 1.25), 68))
    local iconTextGap = math.floor(iconSize * 0.10)
    local iconX       = (self.alignmentMode == "right") and (self:getWidth() - iconSize) or 0
    local padding_stats = 1
    local textAlignRight = (self.alignmentMode == "right")

    -- (…keep the **rest** of your existing render() body exactly as-is…)
    -- Everything below is unchanged in your file; no logic changes required.
    -- ─────────────────────────────────────────────────────────────────────
    -- === showCalendar ===
    if self.showCalendar then
        local iconY = self.positions.calendar
        local boxY  = iconY + (iconSize - boxHeight) / 2

        local text = ""
        if self.calendarMode == 1 then
            text = player:getTimeSurvived()
        else
            local hours = math.floor(player:getHoursSurvived() or 0)
            local totalDays = math.floor(hours / 24)
            local years = math.floor(totalDays / 360)
            local daysInYear = totalDays % 360
            local months = math.floor(daysInYear / 30)
            local days = daysInYear % 30
            local remainingHours = hours % 24

            text = ""
            if years > 0 then text = text .. years .. getText("UI_TWIST_STATS_YEAR") .. ", " end
            if months > 0 or years > 0 then text = text .. months .. getText("UI_TWIST_STATS_MONTH") .. ", " end
            if days > 0 or months > 0 or years > 0 then text = text .. days .. getText("UI_TWIST_STATS_DAYS") .. ", " end
            text = text .. remainingHours .. getText("UI_TWIST_STATS_HOURS")
        end

        local textWidth = getTextManager():MeasureStringX(font, text) + padding_stats
        local textX, boxX
        if textAlignRight then
            textX = iconX - iconTextGap - textWidth
            boxX  = textX
        else
            textX = iconX + iconSize + iconTextGap
            boxX  = textX
        end

        local r, g, b = getColorModeRGB(self.colorMode)

        self:drawTextureScaled(calendarTexture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
        self:drawRect(boxX, boxY, textWidth, boxHeight, 0.6, 0, 0, 0)
        drawTextCenteredVertical(self, text, textX, boxY, textWidth, boxHeight, r, g, b, 1, font, textAlignRight)
    end

    -- === showKills ===
    if self.showKills then
    local iconY = self.positions.kills
    local boxY  = iconY + (iconSize - boxHeight) / 2

    local totalKills = player:getZombieKills()
    local text = tostring(totalKills)
    local textWidth = getTextManager():MeasureStringX(font, text) + padding_stats


    local textAlignRight = false
    local textX, boxX

    if self.alignmentMode == "right" then
        textAlignRight = true

        textX = iconX - iconTextGap - textWidth
        boxX  = textX
    else

        textX = iconX + iconSize + iconTextGap
        boxX  = textX
    end

    local r, g, b = getColorModeRGB(self.colorMode)


    self:drawTextureScaled(zedsKillsTexture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
    self:drawRect(boxX, boxY, textWidth, boxHeight, 0.6, 0, 0, 0)
    drawTextCenteredVertical(self, text, textX, boxY, textWidth, boxHeight, r, g, b, 1, font, textAlignRight)
	end

    -- === showTraveled ===
   if self.showTraveled then
    local iconY = self.positions.traveled
    local boxY  = iconY + (iconSize - boxHeight) / 2

    local km, meters = GetDistanceTraveled()
    local text = string.format("%d km %d m", km, meters)
    local textWidth = getTextManager():MeasureStringX(font, text) + padding_stats

    local fatigue = player:getStats():getFatigue()
    local r, g, b = getFatigueColor(fatigue)
    local rText, gText, bText = getColorModeRGB(self.colorMode)

    local indicatorSize = math.floor(iconSize / 3)
    local textAlignRight = false
    local textX, boxX, indicatorX

    if self.alignmentMode == "right" then
        textAlignRight = true
        textX = iconX - iconTextGap - textWidth
        boxX = textX
        indicatorX = textX - iconTextGap - indicatorSize
    else
        textX = iconX + iconSize + iconTextGap
        boxX = textX
        indicatorX = textX + textWidth + iconTextGap
    end
    local indicatorY = boxY + (boxHeight - indicatorSize) / 2

    self:drawTextureScaled(traveledTexture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
    self:drawRect(boxX, boxY, textWidth, boxHeight, 0.6, 0, 0, 0)
    drawTextCenteredVertical(self, text, textX, boxY, textWidth, boxHeight, rText, gText, bText, 1, font, textAlignRight)
    self:drawRect(indicatorX, indicatorY, indicatorSize, indicatorSize, 1, r, g, b)
	end

    -- === showWeight ===
	if self.showWeight then
    local iconY = self.positions.weight
    local boxY  = iconY + (iconSize - boxHeight) / 2

    local nutrition = player:getNutrition()
    local weight = GetPlayerWeight(player)
    local calories = nutrition and nutrition:getCalories() or 0
    local text = weight .. " kg"
    local textWidth = getTextManager():MeasureStringX(font, text) + padding_stats

    local indicatorTexture = nil
    if calories < -2000 then
        indicatorTexture = indicatorLowLowTexture
    elseif calories < -1000 then
        indicatorTexture = indicatorLowTexture
    elseif calories > 3000 then
        indicatorTexture = indicatorHighHighTexture
    elseif calories > 2000 then
        indicatorTexture = indicatorHighTexture
    end
    local indicatorSize = math.floor(iconSize / 2)
    local iconWidth = indicatorTexture and (indicatorSize + iconTextGap) or 0

    local textAlignRight = false
    local textX, boxX, indicatorX
    local rectWidth = textWidth + (indicatorTexture and iconWidth or 0)

    if self.alignmentMode == "right" then
        textAlignRight = true
        if indicatorTexture then
            boxX = (iconX - iconTextGap - textWidth) - (iconTextGap + indicatorSize)
            indicatorX = boxX
            textX = boxX + iconWidth
        else
            boxX = iconX - iconTextGap - textWidth
            textX = boxX
        end
    else
        textX = iconX + iconSize + iconTextGap
        boxX = textX
        if indicatorTexture then
            indicatorX = textX + textWidth + iconTextGap
        end
    end

    local indicatorY = boxY + (boxHeight - indicatorSize) / 2

    self:drawTextureScaled(weightTexture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
    self:drawRect(boxX, boxY, rectWidth, boxHeight, 0.6, 0, 0, 0)
    local r, g, b = getWeightColor(weight, self.colorMode)
    drawTextCenteredVertical(self, text, textX, boxY, textWidth, boxHeight, r, g, b, 1, font, textAlignRight)

    if indicatorTexture then
        self:drawTextureScaled(indicatorTexture, indicatorX, indicatorY, indicatorSize, indicatorSize, 1, 1, 1, 1)
    end
end

    -- === showDailyKills ===
    if self.showDailyKills then
    local iconY = self.positions.dailyKills
    local boxY  = iconY + (iconSize - boxHeight) / 2

    local currentKills = player:getZombieKills()
    local modData = player:getModData()
    local baseKills = modData and modData.killsAtMidnight or 0
    local dailyKills = currentKills - baseKills

    local dailyText = getText("UI_TWIST_STATS_DAILY_UI_ELEMENT") .. tostring(dailyKills)
    local textWidth = getTextManager():MeasureStringX(font, dailyText) + padding_stats
    local r, g, b = getColorModeRGB(self.colorMode)

    local textAlignRight = false
    local textX, boxX

    if self.alignmentMode == "right" then
        textAlignRight = true
        textX = iconX - iconTextGap - textWidth
        boxX  = textX
    else
        textX = iconX + iconSize + iconTextGap
        boxX  = textX
    end

    self:drawTextureScaled(dailyTexture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
    self:drawRect(boxX, boxY, textWidth, boxHeight, 0.6, 0, 0, 0)
    drawTextCenteredVertical(self, dailyText, textX, boxY, textWidth, boxHeight, r, g, b, 1, font, textAlignRight)
	end

    -- === showAvgKills ===
    if self.showAvgKills then
    local iconY = self.positions.avgKills
    local boxY  = iconY + (iconSize - boxHeight) / 2

    local totalKills = player:getZombieKills()
    local daysSurvived = player:getHoursSurvived() / 24
    local avgKills = (daysSurvived > 0) and string.format("%.1f", totalKills / daysSurvived) or "0.0"

    local avgText = getText("UI_TWIST_STATS_AVERAGE_UI_ELEMENT_1") .. avgKills .. getText("UI_TWIST_STATS_AVERAGE_UI_ELEMENT_2")
    local textWidth = getTextManager():MeasureStringX(font, avgText) + padding_stats
    local r, g, b = getColorModeRGB(self.colorMode)

    local textAlignRight = false
    local textX, boxX

    if self.alignmentMode == "right" then
        textAlignRight = true
        textX = iconX - iconTextGap - textWidth
        boxX  = textX
    else
        textX = iconX + iconSize + iconTextGap
        boxX  = textX
    end

    self:drawTextureScaled(avgTexture, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
    self:drawRect(boxX, boxY, textWidth, boxHeight, 0.6, 0, 0, 0)
    drawTextCenteredVertical(self, avgText, textX, boxY, textWidth, boxHeight, r, g, b, 1, font, textAlignRight)
	end

    -- === Autosave as usual ===
    local currentTime = getTimestamp()
    if currentTime > nextInterval then
        SaveFiles(player, SAVE_ALL)
        nextInterval = currentTime + (saveInterval * 60)
    end
end

    function STATSTabClass:onMouseDoubleClick(x, y)
    self.colorMode = self.colorMode + 1
    if self.colorMode > #colorModes then
    self.colorMode = 1
    end
    SaveUi()
    end

function STATSTabClass:updatePositions()
    -- Hard guard: if the panel isn’t fully formed yet, bail once.
    if type(self.getX) ~= "function" then
        print("[TWF][Stats] getX missing on UI element – aborting updatePositions() once.")
        return
    end

    -- Robust font height: never nil / <= 0
    local font       = getFontForStats(self.fontSizeMode or 1)
    local tm         = getTextManager()
    local fontHeight = 24
    if tm and tm.getFontHeight and font then
        local fh = tm:getFontHeight(font)
        fh = tonumber(fh) or 24
        if fh > 0 then fontHeight = fh end
    end

    local iconSize    = math.max(18, math.min(math.floor(fontHeight * 1.25), 68))
    local iconTextGap = math.max(4,  math.floor(iconSize * 0.10))
    local minWidth    = 60
    local maxTextWidth = 0

    local player = getPlayer()

    -- Calendar line width (compute text even if hidden so panel keeps a sane min width)
    local calendarText = ""
    if player then
        if self.calendarMode == 1 then
            calendarText = player:getTimeSurvived()
        elseif self.calendarMode == 2 then
            calendarText = os.date("%Y-%m-%d")
        else
            local h     = math.floor((player:getHoursSurvived() or 0))
            local days  = math.floor(h / 24)
            local hours = h % 24
            calendarText = getText("UI_TWIST_STATS_ALIVE_DAYS", tostring(days), tostring(hours))
        end
    else
        calendarText = getText("UI_TWIST_STATS_ALIVE_DAYS", "0", "0")
    end

    local calWidth = iconSize + iconTextGap + getTextManager():MeasureStringX(font, calendarText) + 14
    if self.showCalendar then
        if calWidth > maxTextWidth then maxTextWidth = calWidth end
        self.lastCalendarWidth = calWidth
    end

    -- Kills
    if self.showKills and player then
        local text = tostring(player:getZombieKills() or 0)
        local w = iconSize + iconTextGap + getTextManager():MeasureStringX(font, text) + 14
        if w > maxTextWidth then maxTextWidth = w end
    end

    -- Distance
    if self.showTraveled and player then
        local km, meters = GetDistanceTraveled()
        local text = string.format("%d km %d m", km or 0, meters or 0)
        local w = iconSize + iconTextGap + getTextManager():MeasureStringX(font, text) + 34
        if w > maxTextWidth then maxTextWidth = w end
    end

    -- Weight
    if self.showWeight and player then
        local text = tostring(GetPlayerWeight(player) or "0.0") .. " kg"
        local w = iconSize + iconTextGap + getTextManager():MeasureStringX(font, text) + 34
        if w > maxTextWidth then maxTextWidth = w end
    end

    -- Daily kills
    if self.showDailyKills and player then
        local md   = player:getModData()
        local base = (md and md.killsAtMidnight) or 0
        local dk   = (player:getZombieKills() or 0) - base
        local text = getText("UI_TWIST_STATS_DAILY_UI_ELEMENT") .. tostring(dk)
        local w = iconSize + iconTextGap + getTextManager():MeasureStringX(font, text) + 14
        if w > maxTextWidth then maxTextWidth = w end
    end

    -- Average kills
    if self.showAvgKills and player then
        local total = player:getZombieKills() or 0
        local days  = (player:getHoursSurvived() or 0) / 24
        local avg   = (days > 0) and string.format("%.1f", total / days) or "0.0"
        local text  = getText("UI_TWIST_STATS_AVERAGE_UI_ELEMENT_1") .. avg .. getText("UI_TWIST_STATS_AVERAGE_UI_ELEMENT_2")
        local w = iconSize + iconTextGap + getTextManager():MeasureStringX(font, text) + 14
        if w > maxTextWidth then maxTextWidth = w end
    end

    -- Keep last calendar width if everything is hidden
    if not (self.showCalendar or self.showKills or self.showTraveled or self.showWeight or self.showDailyKills or self.showAvgKills) then
        maxTextWidth = self.lastCalendarWidth or maxTextWidth
    end

    -- Width: single safe call
    local finalWidth = tonumber(math.max(minWidth, maxTextWidth)) or minWidth
    self:setWidth(finalWidth)

    -- Alignment
    if self.alignmentMode == "right" then
        local rightX = self.savedRightX or (self:getX() + self:getWidth())
        self:setX(rightX - self:getWidth())
    else
        local leftX = self.savedLeftX or self:getX()
        self:setX(leftX)
    end

    -- Vertical layout
    local boxHeight  = fontHeight + 10
    local minSpacing = math.max(2, math.floor(fontHeight * 0.10))
    local step       = math.max(boxHeight + minSpacing, iconSize + 2)
    local y          = -7
    local visible    = 0

    if self.showCalendar   then self.positions.calendar   = y; y = y + step; visible = visible + 1 end
    if self.showKills      then self.positions.kills      = y; y = y + step; visible = visible + 1 end
    if self.showTraveled   then self.positions.traveled   = y; y = y + step; visible = visible + 1 end
    if self.showWeight     then self.positions.weight     = y; y = y + step; visible = visible + 1 end
    if self.showDailyKills then self.positions.dailyKills = y; y = y + step; visible = visible + 1 end
    if self.showAvgKills   then self.positions.avgKills   = y; y = y + step; visible = visible + 1 end

    self:setHeight((visible * step) + 10)
end



function STATSTabClass:onMouseUp(x, y)
    ISPanel.onMouseUp(self, x, y)
    if self.alignmentMode == "right" then
        self.savedRightX = self:getX() + self:getWidth()
    else
        self.savedLeftX = self:getX()
    end
    SaveUi()
end

local randomMessages = {
    "UI_TWIST_RANDOM_MESSAGE1",
    "UI_TWIST_RANDOM_MESSAGE2",
    "UI_TWIST_RANDOM_MESSAGE3"
}

local function ensureAtLeastOneStatVisible(target)
    if not (target.showCalendar or target.showKills or target.showTraveled or target.showWeight or target.showDailyKills or target.showAvgKills) then
			target.showKills = true
        if getPlayer() then
            local idx = ZombRand(#randomMessages) + 1
            getPlayer():Say(getText(randomMessages[idx]))
        end
    end
end

function STATSTabClass:onRightMouseUp(x, y)
    if not self:isMouseOver() then return end
    local context = ISContextMenu.get(0, getMouseX(), getMouseY())

    local chartTexture = getTexture("media/ui/stats.png")
    local chartOption = context:addOption(getText("UI_TWIST_STATS_OPEN_CHART"), self, function()
        require "TwisTonFireStats_Chart"
        if TwisTonFireStats_Chart and TwisTonFireStats_Chart.toggle then
            TwisTonFireStats_Chart.toggle()
        end
    end)
    chartOption.iconTexture = chartTexture

    -- === existing entries ===
    local calendarOption = context:addOption(getText("UI_TWIST_STATS_TIMEALIVE"), nil)
    calendarOption.iconTexture = calendarTexture
    local subContext = ISContextMenu:getNew(context)
    context:addSubMenu(calendarOption, subContext)

    subContext:addOption(self.showCalendar and getText("UI_TWIST_STATS_HIDE") or getText("UI_TWIST_STATS_SHOW"), self, function(target)
        target.showCalendar = not target.showCalendar
        ensureAtLeastOneStatVisible(target)
        target:updatePositions()
        SaveUi()
    end)

    if self.showCalendar then
        subContext:addOption(getText("UI_TWIST_STATS_SWITCHCALENDAR"), self, function(target)
            target.calendarMode = (target.calendarMode == 1) and 2 or 1
            target:updatePositions()
            SaveUi()
        end)
    end

    local killsOption = context:addOption(getText("UI_TWIST_STATS_ZOMBIEKILLS"), nil)
    killsOption.iconTexture = zedsKillsTexture
    subContext = ISContextMenu:getNew(context)
    context:addSubMenu(killsOption, subContext)
    subContext:addOption(self.showKills and getText("UI_TWIST_STATS_HIDE") or getText("UI_TWIST_STATS_SHOW"), self, function(target)
        target.showKills = not target.showKills
        ensureAtLeastOneStatVisible(target)
        target:updatePositions()
        SaveUi()
    end)

    local traveledOption = context:addOption(getText("UI_TWIST_STATS_TRAVELED"), nil)
    traveledOption.iconTexture = traveledTexture
    subContext = ISContextMenu:getNew(context)
    context:addSubMenu(traveledOption, subContext)
    subContext:addOption(self.showTraveled and getText("UI_TWIST_STATS_HIDE") or getText("UI_TWIST_STATS_SHOW"), self, function(target)
        target.showTraveled = not target.showTraveled
        ensureAtLeastOneStatVisible(target)
        target:updatePositions()
        SaveUi()
    end)

    local weightOption = context:addOption(getText("UI_TWIST_STATS_WEIGHT"), nil)
    weightOption.iconTexture = weightTexture
    subContext = ISContextMenu:getNew(context)
    context:addSubMenu(weightOption, subContext)
    subContext:addOption(self.showWeight and getText("UI_TWIST_STATS_HIDE") or getText("UI_TWIST_STATS_SHOW"), self, function(target)
        target.showWeight = not target.showWeight
        ensureAtLeastOneStatVisible(target)
        target:updatePositions()
        SaveUi()
    end)

    local dailyOption = context:addOption(getText("UI_TWIST_STATS_DAILYKILLS"), nil)
    dailyOption.iconTexture = dailyTexture
    subContext = ISContextMenu:getNew(context)
    context:addSubMenu(dailyOption, subContext)
    subContext:addOption(self.showDailyKills and getText("UI_TWIST_STATS_HIDE") or getText("UI_TWIST_STATS_SHOW"), self, function(target)
        target.showDailyKills = not target.showDailyKills
        ensureAtLeastOneStatVisible(target)
        target:updatePositions()
        SaveUi()
    end)

    local averageOption = context:addOption(getText("UI_TWIST_STATS_AVERAGE"), nil)
    averageOption.iconTexture = avgTexture
    subContext = ISContextMenu:getNew(context)
    context:addSubMenu(averageOption, subContext)
    subContext:addOption(self.showAvgKills and getText("UI_TWIST_STATS_HIDE") or getText("UI_TWIST_STATS_SHOW"), self, function(target)
        target.showAvgKills = not target.showAvgKills
        ensureAtLeastOneStatVisible(target)
        target:updatePositions()
        SaveUi()
    end)

    local fontOption = context:addOption(getText("UI_TWIST_STATS_FONTSIZE"), nil)
    fontOption.iconTexture = fontTexture
    local fontSubMenu = ISContextMenu:getNew(context)
    context:addSubMenu(fontOption, fontSubMenu)

    fontSubMenu:addOption(getText("UI_TWIST_STATS_LARGE"), self, function(target)
        target.fontSizeMode = 1
        target:updatePositions()
        SaveUi()
    end)
    fontSubMenu:addOption(getText("UI_TWIST_STATS_MEDIUM"), self, function(target)
        target.fontSizeMode = 2
        target:updatePositions()
        SaveUi()
    end)
    fontSubMenu:addOption(getText("UI_TWIST_STATS_SMALL"), self, function(target)
        target.fontSizeMode = 3
        target:updatePositions()
        SaveUi()
    end)

    local alignOption = context:addOption(getText("UI_TWIST_STATS_ALIGNMENT"), nil)
    alignOption.iconTexture = alignTexture
    local alignSubMenu = ISContextMenu:getNew(context)
    context:addSubMenu(alignOption, alignSubMenu)

    if self.alignmentMode == "right" then
        alignSubMenu:addOption(getText("UI_TWIST_STATS_ALIGN_LEFT"), self, function(target)
            local leftEdge = target:getX()
            target.alignmentMode = "left"
            target:updatePositions()
            target:setX(leftEdge)
            SaveUi()
        end)
    else
        alignSubMenu:addOption(getText("UI_TWIST_STATS_ALIGN_RIGHT"), self, function(target)
            local rightEdge = target:getX() + target:getWidth()
            target.alignmentMode = "right"
            target:updatePositions()
            target:setX(rightEdge - target:getWidth())
            SaveUi()
        end)
    end
end
------------------------- Load/Save Interface Positions -----------------------------
function SaveUi()
    if not STATSTab then return end
    local x = STATSTab:getX()
    local y = STATSTab:getY()
    if STATSTab.alignmentMode == "right" then
        x = x + STATSTab:getWidth()
    end
    print("Saving UI position (Lua path): ", x, y)

    -- Write to user/Lua path so it persists across mod updates
    local writer = getFileWriter("TWSTATSpos.txt", true, false) -- create=true, append=false
    if not writer then
        print("Error: Could not open Lua writer for TWSTATSpos.txt")
        return
    end
    writer:write(tostring(x) .. "\n" .. tostring(y) .. "\n")
    writer:close()

    -- keep writing settings to Lua path (already correct)
    local settingsWriter = getFileWriter("TWSTATSsettings.txt", true, false)
    if settingsWriter then
        settingsWriter:write(tostring(STATSTab.showCalendar) .. "\n")
        settingsWriter:write(tostring(STATSTab.showKills) .. "\n")
        settingsWriter:write(tostring(STATSTab.showTraveled) .. "\n")
        settingsWriter:write(tostring(STATSTab.showWeight) .. "\n")
        settingsWriter:write(tostring(STATSTab.showDailyKills) .. "\n")
        settingsWriter:write(tostring(STATSTab.showAvgKills) .. "\n")
        settingsWriter:write(tostring(STATSTab.colorMode) .. "\n")
        settingsWriter:write(tostring(STATSTab.fontSizeMode or 1) .. "\n")
        settingsWriter:write(tostring(STATSTab.alignmentMode or "left") .. "\n")
        settingsWriter:write(tostring(STATSTab.calendarMode or 1) .. "\n")
        settingsWriter:close()
    end
end

function LoadUi()
    -- Read from user/Lua path only.
    local reader = getFileReader("TWSTATSpos.txt", false)
    if reader then
        local mx = reader:readLine()
        local my = reader:readLine()
        reader:close()
        local x = tonumber(mx)
        local y = tonumber(my)
        if x and y then
            -- Clamp to screen, so bad files never push the panel off-screen
            local core = getCore and getCore() or nil
            local sw   = (core and core.getScreenWidth  and core:getScreenWidth())  or 1920
            local sh   = (core and core.getScreenHeight and core:getScreenHeight()) or 1080
            local clx  = math.max(0, math.min(x, sw - 32))
            local cly  = math.max(0, math.min(y, sh - 32))
            return clx, cly
        else
            print("[TWF][Stats] Bad TWSTATSpos.txt (x="..tostring(mx)..", y="..tostring(my)..") -> using script defaults.")
        end
    end

    -- Script defaults (your chosen standards); no mod-folder fallback.
    return 16, 582
end

function SetOrGetPersistentUniqueID(playerObj)
    if not playerObj or type(playerObj) ~= "userdata" or not playerObj.getDescriptor then
        print("[TwisTonFireStats] Player object is NIL or getDescriptor is missing!")
        return nil
    end

    local desc = playerObj:getDescriptor()
    if not desc then
        print("[TwisTonFireStats] Descriptor is nil!")
        return nil
    end

    local rawForename = desc:getForename()
    local rawSurname  = desc:getSurname()

    local function clean(s)
        if not s or s == "" then return nil end
        s = tostring(s):gsub("[%s\t]", "")
        if s == "" then return nil end
        return s
    end

    local forename = clean(rawForename)
    local surname  = clean(rawSurname)

    local parts = {}
    if forename then table.insert(parts, forename) end
    if surname  then table.insert(parts, surname)  end
    if #parts == 0 then parts = { "Unknown" } end

    local modData = playerObj:getModData()
    if not modData then
        print("[TwisTonFireStats] modData is nil!")
        return nil
    end

    if not modData.PersistentUniqueID then
        local timestamp = tostring(os.time())
        local uniqueID = table.concat(parts, "_") .. "_" .. timestamp
        modData.PersistentUniqueID = uniqueID
        print("[TwisTonFireStats] Created PersistentUniqueID: " .. uniqueID)
    end

    TwisTonFireStats.UniquePlayerID = modData.PersistentUniqueID
    return modData.PersistentUniqueID
end

Events.OnCreatePlayer.Add(function(playerIndex, playerObj)
    SetOrGetPersistentUniqueID(playerObj)
    ensureUniqueLogWithHeader(playerObj)
end)

local function OnGameStart_SaveDailyRecord()
    local player = getPlayer()
    if player then
        local modData = player:getModData()
        local dailyRecord = modData and modData["dailyKillRecord"] or 0
        SaveDailyKillRecord(player, dailyRecord)
    end
end

function TwisTonFireStats.GetUniqueID()
    return TwisTonFireStats.UniquePlayerID
end

function TwisTonFireStats.ToggleMainUI()
    local ui = EnsureStatsUi()
    if not ui then return end
    local vis = ui:isVisible()
    if vis then
        SaveUi()                 -- persist position when hiding
        ui:setVisible(false)
    else
        ui:setVisible(true)
        if ui.updatePositions then ui:updatePositions() end
    end
end

function TwisTonFireStats.GetStatsFilePath()
    local player = getPlayer()
    if not player then return nil end
    local id = TwisTonFireStats.UniquePlayerID or SetOrGetPersistentUniqueID(player)
    if not id then return nil end
    return ( "stats/" .. id .. ".txt" )
end

function TwisTonFireStats.GetTodayDailyKills()
    local p = getPlayer()
    if not p then return 0 end
    local md = p:getModData()
    if not md then return 0 end
    local base = md.killsAtMidnight or 0
    local now  = p:getZombieKills() or 0
    local diff = now - base
    return (diff >= 0) and diff or 0
end

function TwisTonFireStats.RepairStatsFile(opts)
    opts = opts or {}
    local path = TwisTonFireStats.GetStatsFilePath and TwisTonFireStats.GetStatsFilePath()
    if not path then print("[TTF_Stats] Repair: no stats file path."); return false end

    local r = getFileReader(path, false)
    if not r then print("[TTF_Stats] Repair: cannot open " .. tostring(path)); return false end

    local zByDay, dateByDay = {}, {}
    local firstForename, firstSurname = nil, nil
    local uniqueInDays = {}
    local header = r:readLine() -- skip header
    while true do
        local line = r:readLine()
        if not line then break end
        line = line:gsub("\r","")
        if line ~= "" then
            -- naive CSV split (we don't expect commas in names)
            local cols = {}
            for part in string.gmatch(line, "([^,]+)") do cols[#cols+1] = part end
            local fn, sn = cols[1] or "", cols[2] or ""
            if not firstForename then firstForename = fn end
            if not firstSurname  then firstSurname  = sn end

            local z   = tonumber(cols[3] or "")
            local day = tonumber(cols[6] or "")
            local ds  = cols[7] or ""
            if z and z >= 0 and day and day >= 0 then
                uniqueInDays[day] = true
                if (not zByDay[day]) or (z > zByDay[day]) then zByDay[day] = z end
                if ds ~= "" then
                    local cur = dateByDay[day]
                    if (not cur) or (ds < cur) then dateByDay[day] = ds end -- earliest date wins
                end
            end
        end
    end
    r:close()

    local inDayCount = 0; for _ in pairs(uniqueInDays) do inDayCount = inDayCount + 1 end
    local days = {}; for d,_ in pairs(zByDay) do table.insert(days, d) end
    table.sort(days)
    if #days == 0 then print("[TTF_Stats] Repair: no valid rows found."); return false end

    -- SAFETY: Don’t drop lots of days unless forced
    if not opts.force and #days < math.floor(inDayCount * 0.9) then
        print(string.format("[TTF_Stats] Repair aborted: would drop too many rows (%d of %d). Use {force=true}.", #days, inDayCount))
        return false
    end

    -- Always keep original name if present; fallback to descriptor only if empty/missing
    if (not firstForename or firstForename == "") or (not firstSurname or firstSurname == "") then
        local p = getPlayer()
        local desc = p and p:getDescriptor() or nil
        firstForename = firstForename or (desc and desc:getForename()) or ""
        firstSurname  = firstSurname  or (desc and desc:getSurname())  or ""
    end

    -- Backup original
    if opts.backup ~= false then
        local ts  = os.date("%Y%m%d_%H%M%S")
        local bak = path .. ".bak." .. ts
        local r2  = getFileReader(path, false)
        local w2  = getFileWriter(bak, false, false)
        if r2 and w2 then
            local ln = r2:readLine()
            while ln do w2:write(ln .. "\n"); ln = r2:readLine() end
            r2:close(); w2:close()
            print("[TTF_Stats] Backup written: " .. bak)
        else
            print("[TTF_Stats] WARN: backup failed, continuing anyway.")
        end
    end

    -- Rewrite cleaned file
    local w = getFileWriter(path, false, false)
    if not w then print("[TTF_Stats] Repair: cannot write " .. tostring(path)); return false end
    w:write("forename,surname,zkills,dailykills,averagekills,dayssurvived,date\n")

    local prevZ, relIdx = 0, 0
    for i=1,#days do
        relIdx = relIdx + 1
        local d   = days[i]
        local z   = zByDay[d] or 0
        local dk  = z - prevZ ; if dk < 0 then dk = 0 end
        local av  = z / relIdx  -- matches your CSV semantics (per entry/day average)
        local dat = dateByDay[d] or os.date("%Y-%m-%d")
        local line = string.format("%s,%s,%d,%d,%.2f,%d,%s",
            firstForename, firstSurname, z, dk, av, d, tostring(dat))
        w:write(line .. "\n")
        prevZ = z
    end
    w:close()

    print(string.format("[TTF_Stats] Repair: done. Wrote %d rows to %s", #days, path))
    return true
end

local function _onKeyPressed_TTFStats_Main(key)
    local want =
        (TTF_StatsOptions and TTF_StatsOptions.GetToggleMainKey and TTF_StatsOptions.GetToggleMainKey())
        or (Keyboard and (Keyboard.KEY_NUMPAD8 or Keyboard.KEY_KP8 or Keyboard.KEY_8))
        or 56
    if key == want then
        TwisTonFireStats.ToggleMainUI()
    end
end
Events.OnKeyPressed.Add(_onKeyPressed_TTFStats_Main)

Events.OnGameStart.Add(OnGameStart_SaveDailyRecord)

Events.OnGameStart.Add(function() if STATSTab and STATSTab.updatePositions then STATSTab:updatePositions() end end)
