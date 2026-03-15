require "Hotbar/ISHotbar"
Events.OnGameBoot.Add(function()

    local og_refresh = ISHotbar.refresh
    function ISHotbar:refresh()
        og_refresh(self)
        if self.notloc_onRefresh then
            self.notloc_onRefresh(self)
        end
    end
end)