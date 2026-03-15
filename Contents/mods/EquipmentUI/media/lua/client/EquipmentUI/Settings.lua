if not EQUIPMENT_UI_SETTINGS then
    EQUIPMENT_UI_SETTINGS = { -- Should I do colorblind profiles? No colorpicker in ModOptions unfortunately :(
        GOOD_COLOR = {r=0.0, g=1.0, b=0.0, a=1.0},
        MIDDLE_COLOR = {r=1.0, g=1.0, b=0.0, a=1.0},
        BAD_COLOR = {r=1.0, g=0.0, b=0.0, a=1.0},
    }
    
    -- Doubles as code to initialize the settings at default values
    --

    -- EQUIPMENT UI
        EQUIPMENT_UI_SETTINGS.applyScale = function(self, scale)
            self.EQUIPMENT_WIDTH = 220 * scale
            self.EQUIPMENT_UI_X_OFFSET = 44 * scale
            self.EQUIPMENT_UI_Y_OFFSET = 24 * scale
            self.EQUIPMENT_UI_BOTTOM_PADDING = 8 * scale
            
            self.EQUIPMENT_DYNAMIC_SLOT_MARGIN = 4 * scale
            self.EQUIPMENT_DYNAMIC_SLOT_X_OFFSET = 16 * scale
            self.EQUIPMENT_DYNAMIC_SLOT_Y_OFFSET = 352 * scale
            
            self.SLOT_SIZE = 34 * scale
            self.SUPER_SLOT_SIZE = 38 * scale
            self.SUPER_SLOT_VERTICAL_OFFSET = 10 * scale
            self.SUPER_SLOT_SUB_ITEM_WIDTH = 12 * scale
            self.SUB_SLOT_THING = 5 * scale -- This is why I should take care of magic numbers before I forget what they are for
            
            self.WEAPON_SLOT_SIZE = 46 * scale
            self.WEAPON_SLOT_PRIMARY_SIZE = 32 * scale
            self.WEAPON_SLOT_SECONDARY_SIZE = 24 * scale
            
            self.WEAPON_SLOT_PRIMARY_OFFSET = 22 * scale
            self.WEAPON_SLOT_SECONDARY_X_OFFSET = 25 * scale
            self.WEAPON_SLOT_SECONDARY_Y_OFFSET = 17 * scale
            
            self.HOTBAR_SLOT_Y_OFFSET = 26 * scale
            self.HOTBAR_SLOT_X_OFFSET = 7 * scale
            self.HOTBAR_SLOT_MARGIN = 4 * scale
            
            self.SCALE = scale
                     
            for _, callback in pairs(self.OnScaleChanged) do
                callback(scale)
            end
        end
    
        EQUIPMENT_UI_SETTINGS.OnScaleChanged = {}
        EQUIPMENT_UI_SETTINGS:applyScale(1)

    -- HIDING EQUIPPED ITEMS
        EQUIPMENT_UI_SETTINGS.applyHideEquippedItems = function(self, hide)
            self.HIDE_EQUIPPED_ITEMS = hide
        end
        EQUIPMENT_UI_SETTINGS:applyHideEquippedItems(false)

    -- TOGGLE UI CONTROLLER BIND
        local DEFAULT_CONTROLLER_BIND = getActivatedMods():contains("WookieeGamepadSupport") and 9 or 7

        EQUIPMENT_UI_SETTINGS.applyToggleUiControllerBind = function(self, bindIndex)
            self.TOGGLE_UI_CONTROLLER_BIND = bindIndex - 1 
        end
        EQUIPMENT_UI_SETTINGS:applyToggleUiControllerBind(DEFAULT_CONTROLLER_BIND)
end

return EQUIPMENT_UI_SETTINGS
