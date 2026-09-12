--[[
    [B42.20] Muscle Manager (Build 42 / SP + MP)
    ------------------------------------------------------------------
    A tiny popup that shows the Discord invite link so the player can copy
    it. Opened from a button on the mod's options window.
]]

MuscleManager = MuscleManager or {}
local MM = MuscleManager

-- Loaded twice when the standalone mod and the Auto All copy are both
-- installed. This file only defines a class, so a second pass is
-- harmless - but the guard is the idiom the rest of the mod uses and
-- costs nothing.
if MM.discordUILoaded then return end
MM.discordUILoaded = true

MM.DISCORD_URL = "https://discord.gg/XJMKptpphq"

MuscleManagerDiscordUI = ISCollapsableWindow:derive("MuscleManagerDiscordUI")
MuscleManagerDiscordUI.instance = nil

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6
local PAD = 14
local WIDTH = 430
local HEIGHT = 150

function MuscleManagerDiscordUI:close()
    MuscleManagerDiscordUI.instance = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

function MuscleManagerDiscordUI:onCopy()
    if Clipboard and Clipboard.setClipboard then
        Clipboard.setClipboard(MM.DISCORD_URL)
    end
    self.entry:focus()
    self.entry:selectAll()
    self.copyBtn:setTitle(getText("UI_MM_discord_copied"))
end

function MuscleManagerDiscordUI:createChildren()
    ISCollapsableWindow.createChildren(self)

    local top = self:titleBarHeight() + PAD
    local label = ISLabel:new(PAD, top, BUTTON_HGT, getText("UI_MM_discord_hint"), 1, 1, 1, 1, UIFont.Small, true)
    label:initialise()
    self:addChild(label)

    local entryY = top + BUTTON_HGT + 8
    self.entry = ISTextEntryBox:new(MM.DISCORD_URL, PAD, entryY, self.width - PAD * 2, BUTTON_HGT)
    self.entry:initialise()
    self.entry:instantiate()
    self.entry:setEditable(false)
    self.entry:setSelectable(true)
    self:addChild(self.entry)

    local btnY = self.height - BUTTON_HGT - PAD
    self.copyBtn = ISButton:new(PAD, btnY, 180, BUTTON_HGT, getText("UI_MM_discord_copy"), self,
            MuscleManagerDiscordUI.onCopy)
    self.copyBtn:initialise()
    self.copyBtn:instantiate()
    self:addChild(self.copyBtn)

    self.closeBtn = ISButton:new(self.width - 150 - PAD, btnY, 150, BUTTON_HGT, getText("UI_MM_win_close"), self,
            MuscleManagerDiscordUI.close)
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self:addChild(self.closeBtn)
end

function MuscleManagerDiscordUI.open(x, y)
    if MuscleManagerDiscordUI.instance then
        MuscleManagerDiscordUI.instance:close()
    end

    local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()
    x = math.max(10, math.min(x or 0, screenW - WIDTH - 10))
    y = math.max(10, math.min(y or 0, screenH - HEIGHT - 10))

    local window = MuscleManagerDiscordUI:new(x, y, WIDTH, HEIGHT)
    window:initialise()
    window:instantiate()
    window:setTitle(getText("UI_MM_discord_title"))
    window:setResizable(false)
    window:addToUIManager()
    MuscleManagerDiscordUI.instance = window

    window.entry:focus()
    window.entry:selectAll()
    return window
end

function MuscleManagerDiscordUI:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = getText("UI_MM_discord_title")
    o.resizable = false
    o.drawFrame = true
    return o
end
