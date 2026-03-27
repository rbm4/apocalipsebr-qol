--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************





function ISMiniMapInner:prerender()
    -- 防御性修复：检查 MapUtils 和函数是否存在
    if MapUtils and MapUtils.renderDarkModeOverlay and self.mapAPI then
        MapUtils.renderDarkModeOverlay(self)
    end
end