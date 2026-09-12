--[[
    [B42.20] Muscle Manager (Build 42 / SP + MP)
    ------------------------------------------------------------------
    The mod's own options window, opened from the fitness panel.

    It edits the very same PZAPI.ModOptions entries that show up under
    Options -> Mods, so both screens always agree and the values land in
    ModOptions.ini. It never touches option.element: that field belongs to
    whatever screen built the widget, and writing to a dead widget would
    throw.

    The window is resizable. Every position is recomputed from the current
    size instead of relying on anchors, which is the only thing that behaves
    predictably while the resize widget is being dragged.
]]

MuscleManager = MuscleManager or {}
local MM = MuscleManager

-- Loaded twice when the standalone mod and the Auto All copy are both
-- installed. This file only defines a class, so a second pass is
-- harmless - but the guard is the idiom the rest of the mod uses and
-- costs nothing.
if MM.optionsUILoaded then return end
MM.optionsUILoaded = true

MuscleManagerOptionsUI = ISCollapsableWindow:derive("MuscleManagerOptionsUI")
MuscleManagerOptionsUI.instance = nil

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local BUTTON_HGT = FONT_HGT_SMALL + 6
local ROW_HGT = BUTTON_HGT + 8
local PAD = 14
local WIDGET_WID = 150
local VALUE_WID = 46
local SCROLLBAR_WID = 18
local BOTTOM_HGT = BUTTON_HGT + PAD * 2
local BTN_WID = 150
local MIN_WID = 540   -- room for three bottom buttons: Defaults, Discord, Close
local MIN_HGT = 240

-- Size and position survive closing and reopening the window.
MM.winRect = MM.winRect or { x = nil, y = nil, w = 560, h = 560 }

---------------------------------------------------------------------
-- reading / writing the options
---------------------------------------------------------------------

local function saveOptions()
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then
        pcall(function() PZAPI.ModOptions:save() end)
    end
end

---------------------------------------------------------------------
-- widgets
---------------------------------------------------------------------

function MuscleManagerOptionsUI:addLabel(x, y, text, font)
    local label = ISLabel:new(x, y, BUTTON_HGT, text, 1, 1, 1, 1, font or UIFont.Small, true)
    label:initialise()
    self.content:addChild(label)
    return label
end

function MuscleManagerOptionsUI:addTickBoxRow(y, option)
    local label = self:addLabel(PAD, y, getText(option.name))

    local tick = ISTickBox:new(0, y, BUTTON_HGT, BUTTON_HGT, "", self,
            MuscleManagerOptionsUI.onTick, option)
    tick:initialise()
    tick:instantiate()
    tick.choicesColor = { r = 1, g = 1, b = 1, a = 1 }
    if option.tooltip then tick.tooltip = getText(option.tooltip) end
    -- addChild before addOption, or getKeepOnScreen() clamps the y position.
    self.content:addChild(tick)
    tick:addOption("")
    tick:setSelected(1, option.value == true)

    return { kind = "tickbox", option = option, label = label, widget = tick, wid = BUTTON_HGT }
end

function MuscleManagerOptionsUI:addSliderRow(y, option)
    local label = self:addLabel(PAD, y, getText(option.name))

    local valueLabel = ISLabel:new(0, y, BUTTON_HGT, tostring(option.value), 1, 1, 1, 1, UIFont.Small, true)
    valueLabel:initialise()
    self.content:addChild(valueLabel)

    local slider = ISSliderPanel:new(0, y, WIDGET_WID, BUTTON_HGT, self, MuscleManagerOptionsUI.onSlider)
    slider:initialise()
    slider:instantiate()
    slider:setValues(option.min, option.max, option.step, option.step * 5)
    slider:setCurrentValue(option.value, true)
    slider.mmOption = option
    slider.mmLabel = valueLabel
    if option.tooltip then slider.tooltip = getText(option.tooltip) end
    self.content:addChild(slider)

    return { kind = "slider", option = option, label = label, widget = slider, value = valueLabel, wid = WIDGET_WID }
end

function MuscleManagerOptionsUI:addComboRow(y, option)
    local label = self:addLabel(PAD, y, getText(option.name))

    local combo = ISComboBox:new(0, y, WIDGET_WID, BUTTON_HGT, self, MuscleManagerOptionsUI.onCombo)
    combo:initialise()
    combo:instantiate()
    for _, value in ipairs(option.values) do
        combo:addOption(value)
    end
    combo.selected = option.selected or 1
    combo.mmOption = option
    if option.tooltip then combo.tooltip = getText(option.tooltip) end
    self.content:addChild(combo)

    return { kind = "combobox", option = option, label = label, widget = combo, wid = WIDGET_WID }
end

---------------------------------------------------------------------
-- callbacks
---------------------------------------------------------------------

function MuscleManagerOptionsUI:onTick(index, selected, option)
    if option then
        option.value = selected == true
        saveOptions()
    end
end

function MuscleManagerOptionsUI:onSlider(value, slider)
    if slider and slider.mmOption then
        slider.mmOption.value = value
        -- setName() would snap the label back to its original x (0 here, since
        -- the rows are positioned afterwards), throwing the number into the
        -- left edge of the window. setNameWithoutMoving() keeps the position.
        if slider.mmLabel then slider.mmLabel:setNameWithoutMoving(tostring(value)) end
        saveOptions()
    end
end

function MuscleManagerOptionsUI:onCombo(combo)
    if combo and combo.mmOption then
        combo.mmOption.selected = combo.selected
        saveOptions()
    end
end

function MuscleManagerOptionsUI:onDefaults()
    for _, option in ipairs(MM.options and MM.options.data or {}) do
        local default = option.id and MM.defaults[option.id]
        if default ~= nil then
            if option.type == "combobox" then
                option.selected = default
            else
                option.value = default
            end
        end
    end
    saveOptions()

    -- Push the restored values into the existing widgets. Clearing and
    -- rebuilding the panel would drop its scroll bars with it.
    for _, row in ipairs(self.rows or {}) do
        local option = row.option
        if option then
            if row.kind == "tickbox" then
                row.widget:setSelected(1, option.value == true)
            elseif row.kind == "slider" then
                row.widget:setCurrentValue(option.value, true)
                if row.value then row.value:setName(tostring(option.value)) end
            elseif row.kind == "combobox" then
                row.widget.selected = option.selected or 1
            end
        end
    end
end

function MuscleManagerOptionsUI:close()
    self:rememberRect()
    saveOptions()
    MuscleManagerOptionsUI.instance = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

---------------------------------------------------------------------
-- layout
---------------------------------------------------------------------

function MuscleManagerOptionsUI:rememberRect()
    MM.winRect.x = self.x
    MM.winRect.y = self.y
    MM.winRect.w = self.width
    MM.winRect.h = self.height
end

function MuscleManagerOptionsUI:buildRows()
    self.rows = {}
    local y = PAD

    for _, option in ipairs(MM.options and MM.options.data or {}) do
        if option.type == "title" then
            if #self.rows > 0 then y = y + 8 end
            local label = self:addLabel(PAD, y, getText(option.name), UIFont.Medium)
            label:setColor(0.75, 1, 0.75)
            self.rows[#self.rows + 1] = { kind = "title", label = label }
            y = y + math.max(ROW_HGT, FONT_HGT_MEDIUM + 8)
        elseif option.type == "tickbox" then
            self.rows[#self.rows + 1] = self:addTickBoxRow(y, option)
            y = y + ROW_HGT
        elseif option.type == "slider" then
            self.rows[#self.rows + 1] = self:addSliderRow(y, option)
            y = y + ROW_HGT
        elseif option.type == "combobox" then
            self.rows[#self.rows + 1] = self:addComboRow(y, option)
            y = y + ROW_HGT
        end
    end

    self.contentHeight = y + PAD
end

--- Keeps every widget glued to the right edge of the current window width.
function MuscleManagerOptionsUI:layoutRows()
    local right = self.content:getWidth() - SCROLLBAR_WID - PAD
    for _, row in ipairs(self.rows or {}) do
        if row.widget then
            row.widget:setX(math.max(PAD + 40, right - row.wid))
            local labelRight = row.widget.x
            if row.value then
                row.value:setX(row.widget.x - VALUE_WID)
                -- ISLabel uses originalX whenever the text changes, so it has
                -- to follow the row instead of keeping the creation position.
                row.value.originalX = row.value.x
                labelRight = row.widget.x - VALUE_WID
            end
            row.label:setWidth(math.max(40, labelRight - PAD - 8))
        end
    end
    self.content:setScrollHeight(self.contentHeight or 0)
end

function MuscleManagerOptionsUI:createChildren()
    ISCollapsableWindow.createChildren(self)

    local top = self:titleBarHeight()
    self.content = ISPanel:new(0, top, self.width, math.max(40, self.height - top - BOTTOM_HGT))
    self.content:initialise()
    self.content:instantiate()
    self.content.background = false
    -- Clip the rows to the panel, otherwise scrolled-out rows draw over the
    -- title bar and the button row.
    self.content.doStencilRender = true
    self:addChild(self.content)
    self.content:setScrollChildren(true)
    self.content:addScrollBars()

    self:buildRows()

    self.defaultsBtn = ISButton:new(PAD, 0, BTN_WID, BUTTON_HGT, getText("UI_MM_win_defaults"), self,
            MuscleManagerOptionsUI.onDefaults)
    self.defaultsBtn:initialise()
    self.defaultsBtn:instantiate()
    self:addChild(self.defaultsBtn)

    self.discordBtn = ISButton:new(0, 0, BTN_WID, BUTTON_HGT, getText("UI_MM_discord_button"), self,
            MuscleManagerOptionsUI.onDiscord)
    self.discordBtn:initialise()
    self.discordBtn:instantiate()
    self.discordBtn.tooltip = getText("UI_MM_discord_button_tt")
    self:addChild(self.discordBtn)

    self.closeBtn = ISButton:new(0, 0, BTN_WID, BUTTON_HGT, getText("UI_MM_win_close"), self,
            MuscleManagerOptionsUI.close)
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self:addChild(self.closeBtn)

    self:updateLayout(true)
end

function MuscleManagerOptionsUI:onDiscord()
    MuscleManagerDiscordUI.open(self:getAbsoluteX() + (self.width - 430) / 2, self:getAbsoluteY() + 60)
end

--- Everything that depends on the window size, recomputed instead of anchored.
function MuscleManagerOptionsUI:updateLayout(force)
    if not self.content then return end
    if not force and self.lastWid == self.width and self.lastHgt == self.height then return end
    self.lastWid, self.lastHgt = self.width, self.height

    local top = self:titleBarHeight()
    self.content:setX(0)
    self.content:setY(top)
    self.content:setWidth(self.width)
    self.content:setHeight(math.max(40, self.height - top - BOTTOM_HGT))

    local btnY = self.height - BUTTON_HGT - PAD
    self.defaultsBtn:setX(PAD)
    self.defaultsBtn:setY(btnY)
    self.discordBtn:setX((self.width - BTN_WID) / 2)
    self.discordBtn:setY(btnY)
    self.closeBtn:setX(self.width - BTN_WID - PAD)
    self.closeBtn:setY(btnY)

    self:layoutRows()
end

function MuscleManagerOptionsUI:prerender()
    self:updateLayout(false)
    ISCollapsableWindow.prerender(self)
end

---------------------------------------------------------------------
-- open
---------------------------------------------------------------------

function MuscleManagerOptionsUI.open(x, y)
    if MuscleManagerOptionsUI.instance then
        MuscleManagerOptionsUI.instance:close()
    end
    if not (MM.options and MM.options.data) then return nil end

    local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()
    local width = math.max(MIN_WID, math.min(MM.winRect.w or 560, screenW - 40))
    local height = math.max(MIN_HGT, math.min(MM.winRect.h or 560, screenH - 60))

    x = MM.winRect.x or x or 0
    y = MM.winRect.y or y or 0
    x = math.max(10, math.min(x, screenW - width - 10))
    y = math.max(10, math.min(y, screenH - height - 10))

    local window = MuscleManagerOptionsUI:new(x, y, width, height)
    window:initialise()
    window:instantiate()
    window:setTitle(getText("UI_MM_win_title"))
    window:setResizable(true)
    window:addToUIManager()
    MuscleManagerOptionsUI.instance = window
    return window
end

function MuscleManagerOptionsUI:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = getText("UI_MM_win_title")
    o.resizable = true
    o.drawFrame = true
    o.minimumWidth = MIN_WID
    o.minimumHeight = MIN_HGT
    o.rows = {}
    return o
end
