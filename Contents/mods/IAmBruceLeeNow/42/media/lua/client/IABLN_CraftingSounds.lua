require "Entity/TimedActions/ISHandcraftAction"

local TARGET_RECIPE = "CraftMartialArtsHandWraps"
local ENLIGHTENMENT_TEXT = "IGUI_IABLN_ForgeEnlightenment"

local originalStart = ISHandcraftAction.start

local function isHandwrapRecipe(action)
    local recipe = action and action.craftRecipe or nil
    local name = recipe and recipe:getName() or nil
    return name == TARGET_RECIPE or name == "IAmBruceLeeNow." .. TARGET_RECIPE
end

function ISHandcraftAction:start()
    originalStart(self)

    if self.craftStarted and isHandwrapRecipe(self) then
        self.character:Say(getText(ENLIGHTENMENT_TEXT))
    end
end
