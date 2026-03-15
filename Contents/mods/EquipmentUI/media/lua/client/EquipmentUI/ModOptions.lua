require "EquipmentUI/Settings"

if not EQUIPMENT_UI_MOD_OPTIONS then
    local DEFAULT_CONTROLLER_BIND = getActivatedMods():contains("WookieeGamepadSupport") and 9 or 7

    EQUIPMENT_UI_MOD_OPTIONS = {
        options = {
            EQUIPMENT_UI_SCALE_INDEX = 2,
            HIDE_EQUIPPED_ITEMS = false,
            TOGGLE_UI_CONTROLLER_BIND_INDEX = DEFAULT_CONTROLLER_BIND, -- Default to SELECT, or LS if WookieeGamepadSupport is active
        },
        names = {
            EQUIPMENT_UI_SCALE_INDEX = "UI_equipment_options_scale",
            HIDE_EQUIPPED_ITEMS = "UI_equipment_options_hide_equipped_items",
            TOGGLE_UI_CONTROLLER_BIND_INDEX = "UI_equipment_options_toggle_ui_controller_bind",
        },
        mod_id = "EQUIPMENT_UI",
        mod_shortname = getText("UI_optionscreen_binding_EquipmentUI"),
    }
end

if ModOptions and ModOptions.getInstance then
    local settings = ModOptions:getInstance(EQUIPMENT_UI_MOD_OPTIONS)
    ModOptions:loadFile() -- Load the mod options file right away

    local uiScale = settings:getData("EQUIPMENT_UI_SCALE_INDEX")
    uiScale[1] = getText("0.5x")
    uiScale[2] = getText("1x")
    uiScale[3] = getText("1.5x")
    uiScale[4] = getText("2x")
    uiScale[5] = getText("2.5x")
    uiScale[6] = getText("3x")
    uiScale[7] = getText("3.5x")
    uiScale[8] = getText("4x")

    function uiScale:OnApplyInGame(val)
        EQUIPMENT_UI_MOD_OPTIONS.options.EQUIPMENT_UI_SCALE_INDEX = val
        EQUIPMENT_UI_SETTINGS:applyScale(val * 0.5)
    end

    EQUIPMENT_UI_SETTINGS:applyScale(EQUIPMENT_UI_MOD_OPTIONS.options.EQUIPMENT_UI_SCALE_INDEX * 0.5)


    local toggleUiControllerBind = settings:getData("TOGGLE_UI_CONTROLLER_BIND_INDEX")
    toggleUiControllerBind[1] =  getText(" A  /  X ")
    toggleUiControllerBind[2] =  getText(" B  /  O ")
    toggleUiControllerBind[3] =  getText(" X  /  [ ] ")
    toggleUiControllerBind[4] =  getText(" Y  /  /\\ ")
    toggleUiControllerBind[5] =  getText(" LB /  L1 ")
    toggleUiControllerBind[6] =  getText(" RB /  R1 ")
    toggleUiControllerBind[7] =  getText("  < /  - ")
    toggleUiControllerBind[8] =  getText("  > /  + ")
    toggleUiControllerBind[9] =  getText(" LS /  L3 ")
    toggleUiControllerBind[10] = getText(" RS /  R3 ")

    -- Use left and right triangles as iconography for the start and select buttons

    function toggleUiControllerBind:OnApplyInGame(val)
        EQUIPMENT_UI_MOD_OPTIONS.options.TOGGLE_UI_CONTROLLER_BIND_INDEX = val
        EQUIPMENT_UI_SETTINGS:applyToggleUiControllerBind(val)
    end


    local hideEquippedItems = settings:getData("HIDE_EQUIPPED_ITEMS")

    function hideEquippedItems:OnApplyInGame(val)
        EQUIPMENT_UI_MOD_OPTIONS.options.HIDE_EQUIPPED_ITEMS = val
        EQUIPMENT_UI_SETTINGS:applyHideEquippedItems(val)
    end

    EQUIPMENT_UI_SETTINGS:applyHideEquippedItems(EQUIPMENT_UI_MOD_OPTIONS.options.HIDE_EQUIPPED_ITEMS)
end