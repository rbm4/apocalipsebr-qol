--[[
    [B42.20] Muscle Manager (Build 42 / SP + MP)
    ------------------------------------------------------------------
    Compatibility with "Neat Rocco's UI [B42]" (Steam Workshop 3723726293),
    an addon for the NeatUI Framework that reskins several vanilla panels,
    including the Fitness panel.

    How it actually works (read from the mod's own source, not guessed):
    NR_Patch.lua calls NR_MakePatch(ISFitnessUI, NR_FitnessPanel, "Fitness"),
    which - only while that mod's own per-window "Fitness" toggle is on -
    replaces ISFitnessUI.new so that opening the panel constructs an
    NR_FitnessPanel instance instead of a plain ISFitnessUI one.
    NR_FitnessPanel = ISFitnessUI:derive(...), and its own initialise() calls
    ISFitnessUI.initialise(self) first - which is the function we hook in
    MuscleManager_UI.lua - so our AUTO tickbox and Options button DO get
    added as children. NR_FitnessPanel then resizes and repositions the
    whole window to fit its own layout, so our widgets (placed using the
    vanilla panel's original size) end up sitting at the wrong spot.

    Unlike initialise(), NR_FitnessPanel's own render()/prerender() do NOT
    call through to ISFitnessUI's versions - they fully replace them - so
    the render() hook in MuscleManager_UI.lua never runs for a reskinned
    panel either. Both problems are fixed here, only when NR_FitnessPanel
    actually exists (i.e. Neat Rocco's UI is installed).

    Deferred to OnGameStart because mod load order is not guaranteed: our
    file may run before NR_FitnessPanel is even defined.
]]

MuscleManager = MuscleManager or {}
local MM = MuscleManager

if MM.neatCompatLoaded then return end
MM.neatCompatLoaded = true

--- Grows the reskinned window by one row and moves our widgets into it,
--- using Neat Rocco's own computed layout (self._layout) so the fit is
--- correct at any resolution/theme. Runs once per panel instance.
local function fitNeatPanel(panel)
    if panel.mmNeatFitted then return end
    local layout = panel._layout
    -- self._layout / self.header only exist once NR_FitnessPanel's own
    -- initialise() has finished; both are vanilla-ISFitnessUI-agnostic markers
    -- that this instance really is the reskinned class.
    if not layout or not panel.header then return end
    panel.mmNeatFitted = true

    local pad = layout.pad or MM.uiBorderSpacing
    local rowHgt = MM.uiButtonHgt
    local extraHgt = rowHgt + pad * 2

    -- Make sure the row is wide enough for the tickbox + the Options button,
    -- in case Neat Rocco's own window is narrower than that (short titles,
    -- some languages).
    local needed = pad
    if panel.mmAuto then needed = needed + panel.mmAuto:getWidth() + pad end
    if panel.mmOptions then needed = needed + panel.mmOptions:getWidth() + pad end

    local oldWidth, oldHeight = panel.width, panel.height
    if needed > oldWidth then
        panel:setWidth(needed)
        panel:setX(panel:getX() - math.floor((needed - oldWidth) / 2))
    end
    panel:setHeight(oldHeight + extraHgt)
    -- Grow downward from the middle so the window stays visually centred
    -- instead of drifting off-screen after several fitness sessions.
    panel:setY(panel:getY() - math.floor(extraHgt / 2))

    local rowY = oldHeight + pad
    if panel.mmAuto then
        panel.mmAuto:setX(pad)
        panel.mmAuto:setY(rowY)
    end
    if panel.mmOptions then
        panel.mmOptions:setX(panel.width - panel.mmOptions:getWidth() - pad)
        panel.mmOptions:setY(rowY)
    end
end

local function applyNeatRoccoCompat()
    if not NR_FitnessPanel then return end -- Neat Rocco's UI not installed
    -- OnGameStart can fire more than once per process (new game after
    -- quitting to the menu); never wrap the same functions twice.
    if NR_FitnessPanel._mmPatched then return end
    NR_FitnessPanel._mmPatched = true

    -- Runs first: the window is at its final size before Neat Rocco's own
    -- prerender draws the background, so there is no one-frame flash.
    local original_NR_prerender = NR_FitnessPanel.prerender
    function NR_FitnessPanel:prerender()
        fitNeatPanel(self)
        original_NR_prerender(self)
    end

    local original_NR_render = NR_FitnessPanel.render
    function NR_FitnessPanel:render()
        original_NR_render(self)
        MM.drawFitnessStatusLine(self)
    end
end

Events.OnGameStart.Add(applyNeatRoccoCompat)
