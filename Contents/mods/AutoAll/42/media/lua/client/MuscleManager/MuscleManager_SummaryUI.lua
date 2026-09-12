--[[
    [B42.20] Muscle Manager (Build 42 / SP + MP)
    ------------------------------------------------------------------
    A small card that appears on screen when an auto training session ends,
    stays for a few seconds, fades out and removes itself. Purely
    informational: no buttons, nothing to click, nothing to dismiss.
]]

MuscleManager = MuscleManager or {}
local MM = MuscleManager

-- Loaded twice when the standalone mod and the Auto All copy are both
-- installed. This file only defines a class, so a second pass is
-- harmless - but the guard is the idiom the rest of the mod uses and
-- costs nothing.
if MM.summaryUILoaded then return end
MM.summaryUILoaded = true

MuscleManagerSummaryUI = ISPanel:derive("MuscleManagerSummaryUI")
MuscleManagerSummaryUI.instance = nil

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local ROW_HGT = FONT_HGT_SMALL + 6
local PAD = 14
local WIDTH = 300

local HOLD_MS = 4500   -- fully visible
local FADE_MS = 1200   -- then fades out over this long

---------------------------------------------------------------------
-- formatting
---------------------------------------------------------------------

local function formatElapsed(ms)
    local totalSeconds = math.floor(ms / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    if minutes >= 60 then
        return string.format("%dh %02dm", math.floor(minutes / 60), minutes % 60)
    end
    return string.format("%d:%02d", minutes, seconds)
end

local function formatXP(value)
    return string.format("+%.1f", value)
end

---------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------

function MuscleManagerSummaryUI:close()
    if MuscleManagerSummaryUI.instance == self then
        MuscleManagerSummaryUI.instance = nil
    end
    self:setVisible(false)
    self:removeFromUIManager()
end

function MuscleManagerSummaryUI:prerender()
    local elapsed = getTimestampMs() - self.shownAt
    if elapsed >= HOLD_MS + FADE_MS then
        self:close()
        return
    end
    if elapsed <= HOLD_MS then
        self.alpha = 1
    else
        self.alpha = 1 - (elapsed - HOLD_MS) / FADE_MS
    end
end

function MuscleManagerSummaryUI:render()
    local a = self.alpha or 1
    if a <= 0 then return end

    self:drawRect(0, 0, self.width, self.height, 0.85 * a, 0.08, 0.1, 0.09)
    self:drawRectBorder(0, 0, self.width, self.height, a, 0.55, 0.81, 0.51)
    self:drawRect(0, 0, self.width, 4, a, 0.55, 0.81, 0.51)

    local y = PAD
    self:drawTextCentre(self.headerText, self.width / 2, y, 1, 1, 1, a, UIFont.Medium)
    y = y + FONT_HGT_MEDIUM + 6
    self:drawRect(PAD, y, self.width - PAD * 2, 1, 0.4 * a, 1, 1, 1)
    y = y + 8

    for _, row in ipairs(self.rows) do
        self:drawText(row.label, PAD, y, 0.85, 0.85, 0.85, a, UIFont.Small)
        self:drawTextRight(row.value, self.width - PAD, y, row.r or 1, row.g or 1, row.b or 1, a, UIFont.Small)
        y = y + ROW_HGT
    end
end

---------------------------------------------------------------------
-- build
---------------------------------------------------------------------

--- data = { sets, elapsedMs, xpStrength, xpFitness, levelStrength, levelFitness,
---          leveledStrength, leveledFitness }
function MuscleManagerSummaryUI.show(data)
    if MuscleManagerSummaryUI.instance then
        MuscleManagerSummaryUI.instance:close()
    end

    local rows = {
        { label = getText("UI_MM_summary_sets"), value = tostring(data.sets) },
        { label = getText("UI_MM_summary_time"), value = formatElapsed(data.elapsedMs) },
    }

    local strengthLabel = getText("UI_MM_summary_strength")
    if data.leveledStrength then
        strengthLabel = getText("UI_MM_summary_levelUp", strengthLabel, data.levelStrength)
    end
    rows[#rows + 1] = { label = strengthLabel, value = formatXP(data.xpStrength),
            r = 0.7, g = 1, b = 0.7 }

    local fitnessLabel = getText("UI_MM_summary_fitness")
    if data.leveledFitness then
        fitnessLabel = getText("UI_MM_summary_levelUp", fitnessLabel, data.levelFitness)
    end
    rows[#rows + 1] = { label = fitnessLabel, value = formatXP(data.xpFitness),
            r = 0.7, g = 1, b = 0.7 }

    local height = PAD + FONT_HGT_MEDIUM + 6 + 8 + (#rows * ROW_HGT) + PAD

    local x = (getCore():getScreenWidth() - WIDTH) / 2
    local y = 54

    local window = MuscleManagerSummaryUI:new(x, y, WIDTH, height)
    window.headerText = getText("UI_MM_summary_title")
    window.rows = rows
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    MuscleManagerSummaryUI.instance = window
    return window
end

function MuscleManagerSummaryUI:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.moveWithMouse = false
    o.alpha = 1
    o.shownAt = getTimestampMs()
    return o
end
