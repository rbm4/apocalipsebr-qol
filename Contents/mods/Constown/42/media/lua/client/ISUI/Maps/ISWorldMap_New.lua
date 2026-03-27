--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************



function ISWorldMap:prerender()
    ISPanelJoypad.prerender(self)
    self.symbolsUI:prerenderMap()
    if self.mapAPI:getBoolean("ColorblindPatterns") ~= getCore():getOptionColorblindPatterns() then
        MapUtils.initDefaultStyleV1(self)
        MapUtils.overlayPaper(self)
    end
    self:renderPrintMedia()
    self:renderStashMaps()
    self:positionStashMap()

    if MapUtils and MapUtils.renderDarkModeOverlay and self.mapAPI then
        MapUtils.renderDarkModeOverlay(self)
    end
end