--[[
    [B42.20] Muscle Manager (Build 42 / SP + MP)
    ------------------------------------------------------------------
    Adds an AUTO tickbox to the vanilla fitness panel and wires its
    OK / Cancel / Close buttons to the auto loop.
]]

MuscleManager = MuscleManager or {}
local MM = MuscleManager

-- Guard against the file being loaded twice (which would wrap the vanilla
-- panel functions twice and show two tickboxes).
if MM.uiHooked then return end
MM.uiHooked = true

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
MM.uiButtonHgt = BUTTON_HGT
MM.uiBorderSpacing = UI_BORDER_SPACING

---------------------------------------------------------------------
-- AUTO tickbox
---------------------------------------------------------------------

local original_initialise = ISFitnessUI.initialise
function ISFitnessUI:initialise()
    original_initialise(self)

    -- Switched off in Auto All: the vanilla panel is left exactly as it
    -- was. Returning before anything is built is what makes the option
    -- an actual off, rather than a disabled-looking tickbox.
    if not MM.enabled() then return end

    if MM.autoTicked == nil then
        MM.autoTicked = MM.opt("autoDefault") == true
    end

    -- The tickbox goes in the free space at the right of the +/- buttons, on
    -- the row the vanilla panel already reserves. Growing the panel instead
    -- pushes OK/Cancel/Close outside its rectangle, and a child outside the
    -- parent rectangle never receives mouse clicks.
    self.mmAuto = ISTickBox:new(self.minusBtn:getRight() + UI_BORDER_SPACING * 2, self.minusBtn.y,
            140, BUTTON_HGT, "", self, ISFitnessUI.mmOnTickAuto)
    self.mmAuto:initialise()
    self.mmAuto:instantiate()
    self.mmAuto.autoWidth = true
    self.mmAuto.choicesColor = { r = 1, g = 1, b = 1, a = 1 }
    self.mmAuto.tooltip = getText("UI_MM_auto_tt")
    -- addChild before addOption, or getKeepOnScreen() clamps the y position.
    self:addChild(self.mmAuto)
    self.mmAuto:addOption(getText("UI_MM_auto"))
    self.mmAuto:setSelected(1, MM.autoTicked == true)

    -- "Options" button at the right end of the same row, top-anchored like the
    -- +/- buttons. Only top-anchored positions survive here: the panel is
    -- resized after initialise(), so the bottom row (OK/Cancel/Close) is not
    -- where it looks like it is at this point.
    local btnWid = 150
    local btnX = self.width - btnWid - UI_BORDER_SPACING - 1
    if btnX > self.mmAuto:getRight() + UI_BORDER_SPACING then
        self.mmOptions = ISButton:new(btnX, self.minusBtn.y, btnWid, BUTTON_HGT,
                getText("UI_MM_win_button"), self, ISFitnessUI.mmOpenOptions)
        self.mmOptions.internal = "MMOPTIONS"
        self.mmOptions:initialise()
        self.mmOptions:instantiate()
        self.mmOptions.borderColor = self.buttonBorderColor
        self.mmOptions.tooltip = getText("UI_MM_win_button_tt")
        self:addChild(self.mmOptions)
    end
end

function ISFitnessUI:mmOpenOptions()
    MuscleManagerOptionsUI.open(self:getAbsoluteX() + 40, self:getAbsoluteY() - 60)
end

function ISFitnessUI:mmOnTickAuto(index, selected)
    MM.autoTicked = selected == true
end

function ISFitnessUI:mmIsAuto()
    return self.mmAuto ~= nil and self.mmAuto:isSelected(1)
end

---------------------------------------------------------------------
-- buttons
---------------------------------------------------------------------

local original_onClick = ISFitnessUI.onClick
function ISFitnessUI:onClick(button)
    if button.internal == "OK" and self:mmIsAuto() then
        if MM.isRunning(self.player) then return end
        local minutes = tonumber(self.exeTime:getInternalText()) or MM.opt("setMinutes")
        MM.start(self.player, self.selectedExe, minutes, self)
        return
    end

    if button.internal == "CANCEL" and MM.isRunning(self.player) then
        MM.stop(self.player, getText("UI_MM_stopped"), false)
    end

    if button.internal == "CLOSE" and MM.isRunning(self.player) and MM.opt("stopOnClose") then
        MM.stop(self.player, getText("UI_MM_stopped"), false)
    end

    original_onClick(self, button)
end

local original_updateButtons = ISFitnessUI.updateButtons
function ISFitnessUI:updateButtons(currentAction)
    original_updateButtons(self, currentAction)
    if not self:mmIsAuto() then return end

    local player = self.player

    if MM.isRunning(player) then
        self.ok.enable = false
        self.ok.tooltip = getText("UI_MM_running_tt")
        self.cancel.enable = true
        return
    end

    -- In auto mode a tired or seated character is fine: the loop rests first
    -- and stands up on its own. Only the hard blockers stay.
    local enable = true
    if player:getMoodles():getMoodleLevel(MoodleType.HEAVY_LOAD) > 2 then
        enable = false
        self.ok.tooltip = getText("Tooltip_TooHeavyFitness")
    elseif player:getVehicle() then
        enable = false
        self.ok.tooltip = getText("Tooltip_CantDriveAndFitness")
    elseif player:isClimbing() then
        enable = false
    else
        self.ok.tooltip = getText("UI_MM_auto_tt")
    end
    self.ok.enable = enable
end

---------------------------------------------------------------------
-- status line
---------------------------------------------------------------------

--- Shared by the vanilla panel and any reskin (e.g. Neat Rocco's UI) that
--- ends up calling render() on a panel that has our mmAuto tickbox.
function MM.drawFitnessStatusLine(panel)
    if not panel.mmAuto then return end

    local state = MM.getState(panel.player)
    if not state or not state.active then return end

    local endurance = math.floor(MM.getEndurance(panel.player) * 100)
    local text
    if state.phase == "resting" then
        text = getText("UI_MM_status_resting", endurance, state.sets)
    else
        text = getText("UI_MM_status_exercising", endurance, state.sets)
    end

    -- Right of the AUTO box, on the same row: free space that is inside the panel.
    panel:drawText(text, panel.mmAuto:getRight() + UI_BORDER_SPACING,
            panel.mmAuto.y + (BUTTON_HGT - FONT_HGT_SMALL) / 2, 0.6, 1, 0.6, 1, UIFont.Small)
end

local original_render = ISFitnessUI.render
function ISFitnessUI:render()
    original_render(self)
    MM.drawFitnessStatusLine(self)
end
