--[[
    Auto All - the tab in the character window (Build 42 / SP + MP)
    ------------------------------------------------------------------
    The same ten switches the Mod Options panel has, sitting in the
    character info window between Skills and Health, plus the Discord
    button.

    Why both places: Mod Options is behind the escape menu and is where
    people look once, when they install a mod. This is where they look
    when a menu entry is in the way *right now*. The two are the same
    settings - this panel writes to the same PZAPI options and saves them,
    so ticking a box here shows up there and survives a restart.

    ------------------------------------------------------------------
    Where the tab goes

    ISCharacterInfoWindow builds its tabs in createChildren with
    panel:addView(name, view), which appends. Asked for between Habilidades
    and Saúde, so the entry is moved to index 3 in viewList afterwards.
    That is safe: activateView searches by name and activateViewById by
    id, and neither depends on array position - only ensureVisible uses
    the index, and it wants the display order, which is the point.

    The hook is wrapped in a pcall and the whole tab is optional. A
    character window with no Auto All tab is a small loss; a character
    window that throws is a broken game.
]]

require "AutoAll/AutoAll_Core"
-- Derived from at load time, so it has to exist by load time. Without
-- this the file depends on the game having happened to load ISUI first,
-- and a miss is not a graceful degradation - `nil:derive()` throws and
-- takes the whole tab with it.
require "ISUI/ISPanelJoypad"
require "ISUI/ISTickBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.panelLoaded then return end
AA.panelLoaded = true

local PAD  = 10
local ROW  = 20
local GAP  = 8

---------------------------------------------------------------------
-- a panel whose children stay inside it
--
-- setScrollChildren moves children by the scroll offset. It does not
-- clip them. Scroll down and everything above the top edge carries on
-- being drawn - over the tab strip, over the window title bar, over
-- whatever else is on screen - because a child's drawing is not bounded
-- by its parent unless something says so.
--
-- setStencilRect in prerender and clearStencilRect in render is what
-- says so: the pair brackets the children's drawing. Same shape vanilla
-- uses in ISDebugSubPanelBase and ISChat.
--
-- Shared, because both the character tab and the Advanced Options body
-- scroll and both leaked.
---------------------------------------------------------------------

-- ISPanelJoypad, not ISPanel, and that part is about controllers.
--
-- ISCharacterInfoWindow:onJoypadDown switches tabs on LB/RB and then calls
-- setJoypadFocus(playerNum, activeView). All four vanilla views derive
-- ISPanelJoypad, so focus lands somewhere that knows what to do with a
-- controller. Ours derived plain ISPanel, which has no button list and no
-- direction handlers - so the focus went in and never came out, and the
-- player had to reach for the mouse. That is the "stuck in the Auto All
-- tab, L1/R1 stop working" report.
--
-- ISPanelJoypad handles A/B/X against its child widgets and the four
-- directions between them, and deliberately does *not* consume LB/RB, so
-- those still bubble up to the window and keep changing tabs.
AA.ScrollBody = ISPanelJoypad:derive("AutoAllScrollBody")

function AA.ScrollBody:prerender()
    self:setStencilRect(0, 0, self:getWidth(), self:getHeight())
    ISPanelJoypad.prerender(self)
end

function AA.ScrollBody:render()
    ISPanelJoypad.render(self)
    self:clearStencilRect()
end

---------------------------------------------------------------------
-- the panel
---------------------------------------------------------------------

AA.Panel = AA.ScrollBody:derive("AutoAllPanel")

function AA.Panel:new(x, y, width, height, playerNum)
    -- ISPanelJoypad, so the controller has somewhere to land. See the note
    -- on AA.ScrollBody.
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.playerNum       = playerNum
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
    o.borderColor     = { r = 0, g = 0, b = 0, a = 0.0 }
    o.moduleRows      = {}
    return o
end

function AA.Panel:createChildren()
    ISPanelJoypad.createChildren(self)

    -- The tab is shorter than its contents, and without this the rows past
    -- the bottom edge are drawn but sit outside the panel's hit test - so
    -- Tailoring, Mechanics, Reload and Dismantle were visible and dead.
    -- Same three calls the Skills tab uses (ISCharacterInfo.lua:20-21,192).
    self:setScrollChildren(true)
    self:addScrollBars()

    local y = PAD

    -- A real child, not a drawText in render().
    --
    -- drawText draws in panel coordinates and is neither moved by the
    -- scroll offset nor clipped to the panel, so the heading and the two
    -- description lines stayed put while everything else scrolled, and
    -- painted straight over the tab strip above. Children do both for
    -- free. The long descriptions are gone entirely - they were also
    -- running off the right edge, and this panel is narrow.
    local title = ISLabel:new(PAD, y, ROW, getText("UI_AA_opt_titleModules"),
            1, 1, 1, 1, UIFont.Medium, true)
    title:initialise()
    self:addChild(title)
    y = y + ROW + 6

    -- One tick box holding all ten, so the rows line up on their own and
    -- there is a single change callback to route.
    self.tickBox = ISTickBox:new(PAD, y, self.width - PAD * 2, ROW,
            "", self, AA.Panel.onModuleToggled)
    self.tickBox:initialise()
    self.tickBox.autoWidth = true
    self:addChild(self.tickBox)

    for index, entry in ipairs(AA.MODULES) do
        self.tickBox:addOption(getText(entry.label))
        self.moduleRows[index] = entry
    end

    y = y + self.tickBox:getHeight() + PAD + 6

    local advanced = getText("UI_AA_opt_advanced_btn")
    local advWidth = getTextManager():MeasureStringX(UIFont.Small, advanced) + 24
    self.advancedBtn = ISButton:new(PAD, y, advWidth, 25, advanced, self, AA.Panel.onAdvanced)
    self.advancedBtn:initialise()
    self.advancedBtn:instantiate()
    self.advancedBtn.borderColor = { r = 0.4, g = 0.4, b = 0.6, a = 1 }
    self:addChild(self.advancedBtn)

    y = y + 25 + GAP

    local label = getText("UI_AA_opt_discord_btn")
    local width = getTextManager():MeasureStringX(UIFont.Small, label) + 24
    self.discordBtn = ISButton:new(PAD, y, width, 25, label, self, AA.Panel.onDiscord)
    self.discordBtn:initialise()
    self.discordBtn:instantiate()
    self.discordBtn.borderColor = { r = 0.4, g = 0.4, b = 0.6, a = 1 }
    self:addChild(self.discordBtn)

    y = y + 25 + PAD

    -- What the scrollbar measures against. Everything above has to be
    -- accounted for or the last rows cannot be reached.
    self:setScrollHeight(y)

    -- The order a controller walks with up/down. Without a button list
    -- ISPanelJoypad has nothing to move between, and the focus that
    -- ISCharacterInfoWindow hands over on a tab change has nowhere to go.
    self:insertNewLineOfButtons(self.tickBox)
    self:insertNewLineOfButtons(self.advancedBtn)
    self:insertNewLineOfButtons(self.discordBtn)

    self:refresh()
end

-- The settings can change behind this panel's back - from Mod Options, or
-- from a server pushing a sandbox value - so the boxes are re-read rather
-- than trusted. Twice a second is far more often than a human can change
-- a setting and far less often than a frame: reading all ten every frame
-- is six hundred option lookups a second to show something that changes
-- once a session.
local REFRESH_INTERVAL = 500

--- Reads the live option values into the boxes.
function AA.Panel:refresh()
    if not self.tickBox then return end
    self.nextRefresh = getTimestampMs() + REFRESH_INTERVAL

    for index, entry in ipairs(self.moduleRows) do
        self.tickBox:setSelected(index, AA.opt(entry.option) ~= false)
    end
end

function AA.Panel:onModuleToggled(index, selected)
    local entry = self.moduleRows[index]
    if not entry then return end

    -- Written straight to the PZAPI option and saved, so this and the Mod
    -- Options panel are one setting rather than two that drift apart.
    local ok = pcall(function()
        local option = AA.options and AA.options:getOption(entry.option)
        if option then option:setValue(selected == true) end
        if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then
            PZAPI.ModOptions:save()
        end
    end)

    if not ok then
        print("[AutoAll] could not save the " .. entry.key .. " switch")
    end

    -- A server can veto a module, and then the box has to snap back
    -- rather than lie about what will happen.
    self:refresh()
end

function AA.Panel:onDiscord()
    AA.openDiscord()
end

function AA.Panel:onAdvanced()
    AA.openAdvancedOptions(self.playerNum)
end

--- Keeps the panel exactly the size of the tab body it sits in.
---
--- Views are handed `window.height - 8` when they are created, which is
--- not the same as the space left under the tab strip, and the character
--- window is resizable on top of that. Being taller than the visible area
--- is what made the bottom rows draw but not accept a click: they were
--- outside the panel's own hit test. The scroll region has to be the
--- visible region or the scrollbar measures against the wrong thing.
function AA.Panel:prerender()
    local tabs = self.parent
    if tabs and tabs.tabHeight then
        local w = tabs:getWidth()
        local h = tabs:getHeight() - tabs.tabHeight
        if w > 0 and math.abs(w - self:getWidth()) > 1 then self:setWidth(w) end
        if h > 0 and math.abs(h - self:getHeight()) > 1 then self:setHeight(h) end
    end

    -- Sets the stencil, so this has to run after the resize above or the
    -- clip would be a frame behind the panel it is clipping.
    AA.ScrollBody.prerender(self)
end

--- The tab panel's owner: our parent is the view list, its parent is the
--- character window.
function AA.Panel:characterWindow()
    return self.parent and self.parent.parent
end

--- Lets the controller out again.
---
--- The old comment here said "ISPanelJoypad does not consume LB/RB, so
--- they reach the window and change tabs as normal". That was wrong, and
--- it is the "with a controller I get stuck on that tab" report.
---
--- What actually happens to a bumper press: ISPanelJoypad:onJoypadDown
--- matches none of its cases and falls through to
--- ISUIElement.onJoypadDown, which does
---
---     self.parent:onJoypadDown_Descendant(self, button, joypadData)
---
--- and that bubbles up the *Descendant* chain. ISCharacterInfoWindow
--- implements `onJoypadDown`, not `onJoypadDown_Descendant`, so the press
--- travels all the way to the top and nobody ever switches the tab. The
--- joypad focus is on this view, so there is no other route out.
---
--- Handing the bumpers to the window by hand is the fix. B is kept as
--- well: the vanilla views close the window with it, and a view that
--- ignores it is a room with no door.
function AA.Panel:onJoypadDown(button, joypadData)
    local window = self:characterWindow()

    if (button == Joypad.LBumper or button == Joypad.RBumper)
            and window and window.onJoypadDown then
        window:onJoypadDown(button)
        return
    end

    if button == Joypad.BButton and window and window.close then
        window:close()
        return
    end

    ISPanelJoypad.onJoypadDown(self, button, joypadData)
end

function AA.Panel:render()
    AA.ScrollBody.render(self)

    if getTimestampMs() >= (self.nextRefresh or 0) then
        self:refresh()
    end
end

---------------------------------------------------------------------
-- putting it in the character window
---------------------------------------------------------------------

-- Last, after every vanilla tab.
--
-- It sat between Skills and Health at first, which put a mod tab in the
-- middle of the two people use most and pushed Health along by one. Being
-- last is also what addView already does, so there is nothing to reorder.

if not ISCharacterInfoWindow then
    print("[AutoAll] ISCharacterInfoWindow not found - the character window tab is disabled.")
elseif not AA.charTabHooked then
    AA.charTabHooked = true

    local original_createChildren = ISCharacterInfoWindow.createChildren
    function ISCharacterInfoWindow:createChildren(...)
        local result = original_createChildren(self, ...)

        local ok, err = pcall(function()
            if not self.panel or not self.panel.viewList then return end

            -- Asked for by a controller player who only wanted the tab out
            -- of the rotation. The bumper fix above means it is no longer
            -- a trap, but one fewer tab to cycle past is a fair thing to
            -- want, and the mod works entirely from Mod Options without it.
            if not AA.opt("showTab") then return end

            local view = AA.Panel:new(0, 8, self.width, self.height - 8, self.playerNum)
            view:initialise()
            view.infoText = getTextOrNull("UI_AA_opt_modules_desc")
            self.aaPanel = view

            -- Appends, which is where it belongs: last of all the tabs.
            self.panel:addView(getText("UI_AA_tab_name"), view)
        end)

        if not ok then
            print("[AutoAll] character window tab failed: " .. tostring(err))
        end

        return result
    end
end
