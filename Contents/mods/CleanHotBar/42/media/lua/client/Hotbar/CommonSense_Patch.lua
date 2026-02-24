-- disable CommonSense Ammo Count
local function disableCommonSenseGunUI()
    if SandboxVars and SandboxVars.CommonSense then
        SandboxVars.CommonSense.GunStats = false
    end
    local Ammo_Background = NinePatchTexture.getSharedTexture("media/ui/CleanHotBar/CleanHotbar_Ammo_BG.png")
end

Events.OnGameStart.Add(disableCommonSenseGunUI)
Events.OnCreatePlayer.Add(disableCommonSenseGunUI)
Events.OnInitGlobalModData.Add(disableCommonSenseGunUI)