--[[
    Auto All - the Advanced Options window (Build 42 / SP + MP)
    ------------------------------------------------------------------
    Every setting the mod has, in a window that can be moved and resized,
    reachable without leaving the game.

    ------------------------------------------------------------------
    It is not a second copy of the settings

    The widgets here read and write the *same* PZAPI option objects the
    pause menu panel uses - AA.options.dict[id] - through their own
    getValue/setValue, and then call ModOptions:save(). Change something
    here and the pause menu shows it; change it there and this shows it on
    its next refresh. There is one set of settings.

    The one thing this must never do is assign `option.element`. That
    field belongs to whichever widget MainOptions built, and setValue()
    pushes changes into it. Stealing it would leave the pause menu panel
    driving a widget that is no longer on screen.

    ------------------------------------------------------------------
    Built from the option list, not written out

    AA.options.data is the same ordered list the pause menu renders:
    titles, descriptions, separators, tick boxes, sliders, combo boxes and
    our own button entries. Walking it is what keeps this window in step
    with AutoAll_Config automatically - a new option added there appears
    here with no work at all.
]]

require "AutoAll/AutoAll_Core"
-- For AA.ScrollBody. Explicit, because the game loads this folder
-- alphabetically and Options comes before Panel.
require "AutoAll/AutoAll_Panel"
-- Same reason as in AutoAll_Panel: these are used at load time, so a
-- missing one is a thrown error rather than a missing feature.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISComboBox"
require "ISUI/ISLabel"
require "RadioCom/ISUIRadio/ISSliderPanel"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.optionsWindowLoaded then return end
AA.optionsWindowLoaded = true

---------------------------------------------------------------------
-- Geometry, copied from the screen that already does this job
--
-- Three attempts at laying this window out by hand, three reports of
-- overlapping rows. The mistake was inventing the geometry at all:
-- vanilla renders the *same* PZAPI option list in MainOptions
-- (`MainOptions:addModOptionsPanel`), and that screen has never had this
-- problem. So this is now its layout, not one of my own.
--
-- The three things it does differently, and each of them is a fix:
--
--  1. LABELS ARE RIGHT ALIGNED, ENDING AT THE SPLIT POINT. Vanilla builds
--     them as `ISLabel:new(x, y, h, name, ..., UIFont.Small)` with the
--     last argument left out - and ISLabel:new does
--
--         if (bLeft ~= true) then o.x = o.x - o.width end
--
--     so the label grows LEFTWARDS, away from the widget. Ours passed
--     `true`, so a long caption grew rightwards straight over the slider
--     next to it. That is the overlap, and widening the column (the
--     previous attempt) only moved the point at which it happens. A right
--     aligned label cannot collide with the widget no matter how long the
--     translation is.
--
--  2. ONE TICK BOX PER ROW, WITH AN EMPTY CAPTION, plus its own ISLabel.
--     Vanilla's addYesNo does `addTickBox(...)` then `addOption("")`. A
--     one-row box has no internal centring to get wrong, which is the
--     whole of the 2026-08-11 bug. Grouping consecutive tick boxes into
--     one multi-option box was a valid way to avoid that maths; using a
--     single-row box avoids it more simply, and it lets every row carry a
--     right aligned label like the others.
--
--  3. ROW HEIGHT IS THE WIDGET'S OWN HEIGHT PLUS ONE BORDER SPACING,
--     asked of the widget after it is built rather than assumed.
--
-- The constants are vanilla's own formulas rather than its variables,
-- because MainOptions.style is a local in that file:
--
--     buttonHeight  = fontHeight(ISButton = Small)  + 6
--     labelHeight   = fontHeight(ISLabel  = Medium) + 6
--     borderSpacing = labelHeight / 10
--
-- Re-derived on every build(), never at file load: the player can change
-- the UI font size after the game has started, and a constant measured at
-- boot is what put the rows back on top of each other the last time.
---------------------------------------------------------------------

local BUTTON_HGT, LABEL_HGT, SPACING

local PAD        = 12
local WIDGET_W   = 220
local MIN_WIDTH  = 560
local MIN_HEIGHT = 360

local function measure()
    BUTTON_HGT = getTextManager():getFontHeight(UIFont.Small) + 6
    LABEL_HGT  = getTextManager():getFontHeight(UIFont.Medium) + 6
    SPACING    = math.max(2, math.floor(LABEL_HGT / 10))
end

measure()
---------------------------------------------------------------------
-- the window
---------------------------------------------------------------------

AA.OptionsWindow = ISCollapsableWindow:derive("AutoAllOptionsWindow")

function AA.OptionsWindow:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.title       = getText("UI_AA_opt_advanced_title")
    o.resizable   = true
    o.drawFrame   = true
    o.minimumWidth  = MIN_WIDTH
    o.minimumHeight = MIN_HEIGHT
    o.rows        = {}
    return o
end

function AA.OptionsWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()

    -- Everything lives on a scrolling body rather than on the window, so
    -- resizing the window moves one child instead of fifty.
    -- AA.ScrollBody, not a plain ISPanel: it clips its children, without
    -- which the headings scroll straight out of the window and paint over
    -- the title bar and whatever is behind it.
    self.body = AA.ScrollBody:new(0, th, self.width, self.height - th - rh)
    self.body:initialise()
    self.body.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
    self.body.borderColor     = { r = 0, g = 0, b = 0, a = 0.0 }
    self.body:setAnchorRight(true)
    self.body:setAnchorBottom(true)
    self:addChild(self.body)

    -- **After** addChild, and that is the whole trick. Both of these open
    -- with `if self.javaObject == nil then return end` and say nothing:
    --
    --     ISUIElement:setScrollChildren   (ISUIElement.lua:1646)
    --     ISUIElement:setScrollHeight     (ISUIElement.lua:1627)
    --
    -- An element has no javaObject until it is instantiated, which is what
    -- addChild does. Called before, setScrollChildren is a silent no-op -
    -- the scrollbar still appears and still drags, it just scrolls nothing,
    -- which is exactly how this was reported. AA.Panel got away with the
    -- same calls only because they sit in createChildren, which runs from
    -- instantiate() and is therefore always too late to be too early.
    self.body:setScrollChildren(true)
    self.body:addScrollBars()

    self:build()
end

--- Muscle Manager's own option list, appended after Auto All's.
---
--- Auto Exercise is the bundled Muscle Manager, and it keeps its OWN
--- PZAPI.ModOptions namespace rather than being folded into this one.
--- That is deliberate: five of its ids - fastForward, notify, notifyEvery,
--- stopZombie, stopDamage - are names this mod already uses, so a single
--- namespace would need them renamed, and renaming an option id is how
--- every existing Muscle Manager player silently loses their saved
--- settings. Two PZAPI pages, one window.
---
--- Returns the entries to render, or an empty list when the module is off
--- or the standalone mod is not there.
local function exerciseEntries()
    if not (MuscleManager and MuscleManager.options and MuscleManager.options.data) then
        return {}
    end
    if AA.enabled and AA.enabled("exercise") == false then return {} end
    return MuscleManager.options.data
end

--- Walks AA.options.data and makes a widget for each entry.
---
--- Row by row, exactly the way MainOptions:addModOptionsPanel does it: a
--- right aligned caption ending at the split point, the widget starting
--- there, and the next row placed by the height the widget reports.
function AA.OptionsWindow:build()
    local data = AA.options and AA.options.data
    if type(data) ~= "table" then
        print("[AutoAll] advanced options: no option list to build from")
        return
    end

    -- Re-measured here, not at file load: the player may have changed the
    -- UI font size since the game started.
    measure()

    -- Where the captions end and the widgets begin. Vanilla uses a third
    -- of the page width; the same fraction here, with a floor so a narrow
    -- window still leaves room for a caption.
    self.splitX = math.max(180, math.floor(self.width / 3) + PAD)

    local y = SPACING + 1        -- vanilla's INITIAL_Y

    local sections = { data, exerciseEntries() }

    for _, list in ipairs(sections) do
    for _, entry in ipairs(list) do
        if entry.type == "title" then
            y = self:addTitleRow(entry, y)

        elseif entry.type == "separator" then
            y = y + SPACING * 2

        elseif entry.type == "description" then
            -- Skipped, deliberately.
            --
            -- These are full sentences written for the pause menu, which
            -- is far wider than this window. Wrapping them here is what
            -- produced the overlapping text and the tall empty gaps: the
            -- wrap was measured against the window width at build time,
            -- so a resize or a longer translation put lines where the
            -- next widget already was. Every option keeps its tooltip,
            -- which is where the same explanation belongs.

        elseif entry.type == "tickbox" then
            y = self:addTickRow(entry, y)

        elseif entry.type == "slider" then
            y = self:addSliderRow(entry, y)

        elseif entry.type == "combobox" then
            y = self:addComboRow(entry, y)

        elseif entry.type == "button" then
            y = self:addButtonRow(entry, y)
        end
        end
    end

    self.body:setScrollHeight(y + PAD)

    -- So a controller can walk the window too. Generated rather than
    -- listed: this body is built from the option list, and writing the
    -- rows out by hand would be one more thing to forget when an option
    -- is added.
    pcall(function() self.body:autoGenerateJoypadButtonsLists() end)
end

--- A caption for one row: right aligned so it ends at the split point and
--- grows away from the widget instead of into it.
---
--- `bLeft` is left nil on purpose. ISLabel:new subtracts its own measured
--- width from x unless that argument is exactly true, which is how vanilla
--- gets a right aligned label and is the reason its rows never collide.
function AA.OptionsWindow:addCaption(text, y, height)
    local label = ISLabel:new(self.splitX - SPACING * 2, y, height, text,
                              1, 1, 1, 1, UIFont.Small)
    label:initialise()
    self.body:addChild(label)
    return label
end

function AA.OptionsWindow:addTitleRow(entry, y)
    y = y + SPACING

    -- Titles are the one thing that stays left aligned, because a heading
    -- has no widget beside it to collide with.
    local label = ISLabel:new(PAD, y, LABEL_HGT, getText(entry.name),
                              1, 1, 1, 1, UIFont.Medium, true)
    label:initialise()
    self.body:addChild(label)

    return y + LABEL_HGT + SPACING
end

function AA.OptionsWindow:addTickRow(entry, y)
    -- One option, empty caption. The text is the ISLabel beside it, so the
    -- box never has to lay out a row of its own.
    --
    -- The call ORDER below is vanilla MainOptions:addTickBox / addYesNo,
    -- followed exactly: new -> choicesColor -> initialise -> addChild ->
    -- addOption. It used to addOption before addChild, which is the one
    -- thing this differed from the screen that works, and "some options
    -- have no checkbox" is the report that came back. addOption calls
    -- setHeight, and setHeight before the element has a javaObject only
    -- writes the Lua field - so the box was instantiated at whatever size
    -- it happened to have rather than at the size its own row needs.
    local tick = ISTickBox:new(self.splitX, y, BUTTON_HGT, BUTTON_HGT, "",
                               self, AA.OptionsWindow.onTick, entry)

    -- Vanilla overrides both of these on its own tick boxes. The defaults
    -- are a 20 per cent white border on a half-transparent black square,
    -- which is close to invisible on a light background.
    tick.choicesColor = { r = 1, g = 1, b = 1, a = 1 }
    tick.borderColor  = { r = 1, g = 1, b = 1, a = 0.7 }

    tick:initialise()
    self.body:addChild(tick)
    tick:addOption("")
    tick:setSelected(1, entry:getValue() == true)

    local height = tick:getHeight()
    local label = self:addCaption(getText(entry.name), y, height)
    label:setHeight(height)

    table.insert(self.rows, { kind = "tickbox", entry = entry, widget = tick })
    return y + height + SPACING
end

function AA.OptionsWindow:addSliderRow(entry, y)
    local slider = ISSliderPanel:new(self.splitX + 40, y, WIDGET_W, BUTTON_HGT,
                                     self, AA.OptionsWindow.onSlider)
    slider:initialise()
    slider:setValues(entry.min, entry.max, entry.step, entry.step * 10)
    slider:setCurrentValue(entry:getValue(), true)
    slider.aaEntry = entry
    self.body:addChild(slider)

    -- The live value sits between the caption and the slider, left aligned
    -- so it does not push into either.
    local value = ISLabel:new(self.splitX, y, BUTTON_HGT, tostring(entry:getValue()),
                              1, 1, 1, 1, UIFont.Small, true)
    value:initialise()
    self.body:addChild(value)
    slider.aaLabel = value

    self:addCaption(getText(entry.name), y, BUTTON_HGT)

    table.insert(self.rows, { kind = "slider", entry = entry, widget = slider, label = value })
    return y + BUTTON_HGT + SPACING
end

function AA.OptionsWindow:addComboRow(entry, y)
    local combo = ISComboBox:new(self.splitX, y, WIDGET_W, BUTTON_HGT,
                                 self, AA.OptionsWindow.onCombo)
    combo:initialise()
    for _, name in ipairs(entry.values or {}) do
        combo:addOption(name)
    end
    combo.selected = entry:getValue() or 1
    combo.aaEntry = entry
    self.body:addChild(combo)

    local height = combo:getHeight()
    self:addCaption(getText(entry.name), y, height)

    table.insert(self.rows, { kind = "combobox", entry = entry, widget = combo })
    return y + height + SPACING
end

function AA.OptionsWindow:addButtonRow(entry, y)
    local text = getText(entry.name)
    local width = getTextManager():MeasureStringX(UIFont.Small, text) + 24

    local button = ISButton:new(self.splitX, y, width, BUTTON_HGT, text,
                                self, AA.OptionsWindow.onButton)
    button:initialise()
    button:instantiate()
    button.borderColor = { r = 0.4, g = 0.4, b = 0.6, a = 1 }
    button.aaEntry = entry
    self.body:addChild(button)

    return y + BUTTON_HGT + SPACING
end
---------------------------------------------------------------------
-- changes
---------------------------------------------------------------------

--- Writes a value back and persists it. Never touches option.element:
--- that belongs to the pause menu's own widget, and setValue() already
--- pushes the change into it when one exists.
local function commit(entry, value)
    local ok, err = pcall(function()
        entry:setValue(value)
        if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then
            PZAPI.ModOptions:save()
        end
    end)
    if not ok then
        print("[AutoAll] advanced options could not save " .. tostring(entry.id) .. ": " .. tostring(err))
    end
end

--- One row, one option.
---
--- ISTickBox calls this as `method(target, index, selected, arg1, arg2)`
--- and never passes the widget itself, so each box is handed the option it
--- belongs to as `arg1` at construction. It used to be handed a whole list
--- because consecutive tick boxes shared one grouped widget; every box now
--- has a single row, so the index is always 1 and the entry is the arg.
function AA.OptionsWindow:onTick(index, selected, entry)
    if entry then commit(entry, selected == true) end
end

function AA.OptionsWindow:onSlider(value, slider)
    if not slider or not slider.aaEntry then return end
    commit(slider.aaEntry, value)
    if slider.aaLabel then slider.aaLabel:setName(tostring(value)) end
end

function AA.OptionsWindow:onCombo(combo)
    if not combo or not combo.aaEntry then return end
    commit(combo.aaEntry, combo.selected)
end

function AA.OptionsWindow:onButton(button)
    if not button or not button.aaEntry then return end
    local entry = button.aaEntry
    if type(entry.onclick) == "function" then
        pcall(entry.onclick, entry.target, button)
    end
end

---------------------------------------------------------------------
-- opening it
---------------------------------------------------------------------

--- One window, reused. Opening it twice should raise the one that exists
--- rather than stack a second set of widgets over the first.
function AA.openAdvancedOptions(playerNum)
    if AA.optionsWindow then
        if AA.optionsWindow:getIsVisible() then
            AA.optionsWindow:setVisible(false)
            AA.optionsWindow:removeFromUIManager()
            AA.optionsWindow = nil
        else
            AA.optionsWindow:setVisible(true)
            AA.optionsWindow:addToUIManager()
            return AA.optionsWindow
        end
    end

    local ok, err = pcall(function()
        local w = math.min(700, getCore():getScreenWidth() - 80)
        local h = math.min(620, getCore():getScreenHeight() - 80)

        local window = AA.OptionsWindow:new(
                getCore():getScreenWidth() / 2 - w / 2,
                getCore():getScreenHeight() / 2 - h / 2, w, h)
        window:initialise()
        window:addToUIManager()
        window:setVisible(true)
        AA.optionsWindow = window
    end)

    if not ok then
        print("[AutoAll] advanced options window failed: " .. tostring(err))
        AA.optionsWindow = nil
    end

    return AA.optionsWindow
end
