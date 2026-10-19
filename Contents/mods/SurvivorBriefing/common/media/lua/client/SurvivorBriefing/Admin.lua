--[[
    Survivor Briefing - the looks window, and the 1.0 welcome

    Opened from Options > Mods > Survivor Briefing > "Preview the looks", or, if the player switches
    it on there, from the right-click menu in the world ("Survivor Briefing: test looks"; off by
    default since 1.0.1). One button per look: a click shows the briefing in that look straight away, with
    this character's real data, without touching the settings. Position, text size and motion can
    be switched here for the previews; "Use these settings" keeps what is on screen as the
    player's settings. The same for everyone (not tied to the game's debug mode), in single
    player and on servers alike: it only ever draws on the clicking player's own screen.

    Players updating from 0.x get one welcome message, once, in game: the briefing has looks now,
    pick one? "Yes" opens this window.
]]

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISModalDialog"

SurvivorBriefing = SurvivorBriefing or {}
local SB = SurvivorBriefing

local Admin = {}
SB.Admin = Admin

local LOOK_NAMES = { "Classic", "Inverted", "Minimal", "Camcorder", "Journal", "CaseFile", "Broadcast", "Agent",
                     "Y2K", "HipHop", "Terminal", "Cinematic", "RPG", "Quarantine", "Newspaper", "Military" }
local SIZE_NAMES = { "Small", "Normal", "Large" }

Admin.state = nil

local function state()
    if not Admin.state then
        Admin.state = { look = SB.opt("look") or 1, position = SB.opt("position") or 1, textSize = SB.opt("textSize") or 2,
                        motion = SB.opt("motion") and true or false }
    end
    return Admin.state
end

function Admin.preview(index)
    local s = state()
    s.look = index
    SB.show(0, "Preview", { look = index, position = s.position, textSize = s.textSize, motion = s.motion })
end

-- Keep the look, position, text size and motion in the window as the player's settings.
function Admin.useSettings()
    local s = state()
    SB.setOptions({ look = s.look, position = s.position, textSize = s.textSize, motion = s.motion })
    Admin.savedAt = getTimestampMs()
end

SurvivorBriefingLooksWindow = ISCollapsableWindow:derive("SurvivorBriefingLooksWindow")

local PAD = 10
local GAP = 4
local WIDTH = 420
local FONT = UIFont.Small
local HGT = getTextManager():getFontHeight(FONT)
local BUTTON_HGT = HGT + 8

function SurvivorBriefingLooksWindow:button(x, y, width, label, onClick, colour)
    local button = ISButton:new(x, y, width, BUTTON_HGT, label, self, onClick)
    button:initialise()
    if colour == "accept" then button:enableAcceptColor() end
    if colour == "cancel" then button:enableCancelColor() end
    self:addChild(button)
    return button
end

function SurvivorBriefingLooksWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setTitle(getText("IGUI_SurvivorBriefing_LK_Test_Title"))
    self:setResizable(false)
    self.pinButton:setVisible(false)
    self.collapseButton:setVisible(false)
    local y = self:titleBarHeight() + PAD
    self.hintY = y
    y = y + HGT + GAP * 2
    local half = (self.width - PAD * 2 - GAP) / 2
    self.lookButtons = {}
    for i, name in ipairs(LOOK_NAMES) do
        local column = (i - 1) % 2
        local b = self:button(PAD + column * (half + GAP), y, half, i .. ". " .. getText("UI_SurvivorBriefing_Look_" .. name),
            SurvivorBriefingLooksWindow.onLook)
        b.lookIndex = i
        table.insert(self.lookButtons, b)
        if column == 1 then y = y + BUTTON_HGT + GAP end
    end
    y = y + GAP * 2
    local third = (self.width - PAD * 2 - GAP * 2) / 3
    self.positionButton = self:button(PAD, y, third, "", SurvivorBriefingLooksWindow.onPosition)
    self.sizeButton = self:button(PAD + third + GAP, y, third, "", SurvivorBriefingLooksWindow.onSize)
    self.motionButton = self:button(PAD + (third + GAP) * 2, y, third, "", SurvivorBriefingLooksWindow.onMotion)
    y = y + BUTTON_HGT + GAP
    self:button(PAD, y, half, getText("IGUI_SurvivorBriefing_LK_Test_Use"), SurvivorBriefingLooksWindow.onUse, "accept")
    self:button(PAD + half + GAP, y, half, getText("IGUI_SurvivorBriefing_LK_Test_Hide"), SurvivorBriefingLooksWindow.onHide, "cancel")
    y = y + BUTTON_HGT + PAD
    self:setHeight(y)
end

function SurvivorBriefingLooksWindow:onLook(button) Admin.preview(button.lookIndex) end

function SurvivorBriefingLooksWindow:onPosition()
    local s = state()
    s.position = s.position % #SB.POSITIONS + 1
end

function SurvivorBriefingLooksWindow:onSize()
    local s = state()
    s.textSize = s.textSize % 3 + 1
end

function SurvivorBriefingLooksWindow:onMotion()
    local s = state()
    s.motion = not s.motion
end

function SurvivorBriefingLooksWindow:onUse() Admin.useSettings() end

function SurvivorBriefingLooksWindow:onHide()
    local card = SB.cards and SB.cards[0]
    if card then card:close() end
end

function SurvivorBriefingLooksWindow:prerender()
    ISCollapsableWindow.prerender(self)
    local s = state()
    self.positionButton:setTitle(getText("UI_SurvivorBriefing_Position_" .. (SB.POSITIONS[s.position] or "BottomLeft")))
    self.sizeButton:setTitle(getText("UI_SurvivorBriefing_TextSize_" .. SIZE_NAMES[s.textSize]))
    self.motionButton:setTitle(getText(s.motion and "IGUI_SurvivorBriefing_LK_Test_MotionOn" or "IGUI_SurvivorBriefing_LK_Test_MotionOff"))
    for _, b in ipairs(self.lookButtons) do
        if b.lookIndex == s.look then b:enableAcceptColor() else b:restoreDefaultColors() end
    end
end

function SurvivorBriefingLooksWindow:render()
    ISCollapsableWindow.render(self)
    local saved = Admin.savedAt and getTimestampMs() - Admin.savedAt < 3000
    local text = getText(saved and "IGUI_SurvivorBriefing_LK_Test_Saved" or "IGUI_SurvivorBriefing_LK_Test_Hint")
    local g = saved and 1 or 0.85
    self:drawText(text, PAD, self.hintY, saved and 0.5 or 0.85, g, saved and 0.5 or 0.85, 1, FONT)
end

function SurvivorBriefingLooksWindow:new(x, y)
    local o = ISCollapsableWindow.new(self, x, y, WIDTH, 300)
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.5 }
    return o
end

local window = nil

function Admin.openWindow()
    if not window then
        window = SurvivorBriefingLooksWindow:new(getCore():getScreenWidth() - WIDTH - 80, 110)
        window:initialise()
        window:addToUIManager()
    end
    Admin.state = nil
    window:setVisible(true)
    window:bringToTop()
end

-- From the options screen: the game is behind it (and paused, in single player), so the window
-- waits until the player is back in the game. Clicked at the main menu, it opens in the next game.
function Admin.openSoon()
    Admin.openPending = true
end

function Admin.stepPending()
    if not Admin.openPending or not getSpecificPlayer(0) or SB.menuOpen() then return end
    Admin.openPending = false
    Admin.openWindow()
end

function Admin.toggleWindow()
    if window and window:getIsVisible() then
        window:setVisible(false)
        return
    end
    Admin.openWindow()
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test or playerNum ~= 0 or not SB.opt("looksRightClick") then return end
    context:addOption(getText("IGUI_SurvivorBriefing_LK_Test_Menu"), nil, Admin.toggleWindow)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

-- ---- the 1.0 welcome --------------------------------------------------------------------------------
-- Once per computer, for players who had the mod before 1.0 (new players are marked as welcomed
-- when their settings file is first made). Shown a little after the game starts, once the first
-- briefing card is gone, so the two do not sit on top of each other.
Admin.WELCOME_AFTER_MS = 8000

function Admin.welcomeDue()
    return SB.readState().welcome ~= "1.0"
end

local function onWelcomeAnswer(_, button)
    if button and button.internal == "YES" then Admin.openWindow() end
end

function Admin.showWelcome()
    SB.writeState("welcome", "1.0")
    local w, h = 460, 190
    local modal = ISModalDialog:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2, w, h,
        getText("IGUI_SurvivorBriefing_LK_Welcome"), true, nil, onWelcomeAnswer, 0)
    modal:initialise()
    modal:addToUIManager()
    modal:bringToTop()
    print("[SurvivorBriefing] 1.0 welcome shown")
end

local function onGameStart()
    Admin.welcomeAt = Admin.welcomeDue() and (getTimestampMs() + Admin.WELCOME_AFTER_MS) or nil
end

local function onTick()
    Admin.stepPending()
    if not Admin.welcomeAt or getTimestampMs() < Admin.welcomeAt then return end
    if SB.cards and SB.cards[0] then return end   -- wait for the card on screen to finish
    Admin.welcomeAt = nil
    if Admin.welcomeDue() then pcall(Admin.showWelcome) end
end

Events.OnGameStart.Add(onGameStart)
Events.OnTick.Add(onTick)
