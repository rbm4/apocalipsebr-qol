local Store = require("AdaptiveTraits/Store")

local M = {}

M.notify = function(player, trait, gained, positive)
    local color = positive and HaloTextHelper.getColorGreen() or HaloTextHelper.getColorRed()
    local definition = CharacterTraitDefinition.getCharacterTraitDefinition(trait)
    local message = table.concat({
        gained and "Gained" or "Lost",
        definition:getUIName(),
    }, " ")
    HaloTextHelper.addTextWithArrow(player, message, positive, color)
    local timeStamp = getTimestamp()
    local lastUpdated = Store.getValue(player, "Notification.LastPlayed", 0)
    if timeStamp - lastUpdated < 20 then
        return
    end
    local soundName = positive and "GainExperienceLevel" or "AT_EmGuitarChordStrum8"
    player:playSoundLocal(soundName)
    Store.setValue(player, "Notification.LastPlayed", timeStamp)
end

return M
