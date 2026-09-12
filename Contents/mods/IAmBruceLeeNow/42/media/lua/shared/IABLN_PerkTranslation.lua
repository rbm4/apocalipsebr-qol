-- Custom perks are registered after the game's first translation pass in B42.
-- Refresh the cached perk names once all script-defined perks are available.
local function refreshPerkTranslations()
    local perk = Perks.MartialArts or Perks.FromString("MartialArts")
    if perk and perk:getName() == "IGUI_perks_MartialArts" then
        PerkFactory.initTranslations()
    end
end

refreshPerkTranslations()
Events.OnGameBoot.Add(refreshPerkTranslations)
