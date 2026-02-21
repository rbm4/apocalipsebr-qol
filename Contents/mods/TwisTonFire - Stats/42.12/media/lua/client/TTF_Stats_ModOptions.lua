TTF_StatsOptions = TTF_StatsOptions or {}

local DEFAULT_KEY =
    (Keyboard and (Keyboard.KEY_NUMPAD9 or Keyboard.KEY_KP9 or Keyboard.KEY_9))
    or 57

local displayName = (getText and getText("UI_optionscreen_title_TwisTonFireStats")) or "TwisTonFire — Stats"
TTF_StatsOptions.options = PZAPI.ModOptions:create("TwisTonFireStats", displayName)

local DEFAULT_KEY_MAIN =
    (Keyboard and (Keyboard.KEY_NUMPAD8 or Keyboard.KEY_KP8 or Keyboard.KEY_8))
    or 56

-- ADD: a second keybind option in the same options group
TTF_StatsOptions.toggleMainKeyOption = TTF_StatsOptions.options:addKeyBind(
  "TwisTonFireStats_ToggleMainUI",
  (getText and getText("UI_optionscreen_binding_TwisTonFireStats_ToggleMainUI")) or "Toggle Main Stats",
  DEFAULT_KEY_MAIN
)

TTF_StatsOptions.toggleKeyOption = TTF_StatsOptions.options:addKeyBind(
  "TwisTonFireStats_ToggleUI",
  (getText and getText("UI_optionscreen_binding_TwisTonFireStats_ToggleUI")) or "Toggle Stats Window",
  DEFAULT_KEY
)

function TTF_StatsOptions.GetToggleMainKey()
    local opt = TTF_StatsOptions.toggleMainKeyOption
    if opt and opt.getValue then return opt:getValue() end
    return DEFAULT_KEY_MAIN
end

function TTF_StatsOptions.GetToggleKey()
    local opt = TTF_StatsOptions.toggleKeyOption
    if opt and opt.getValue then return opt:getValue() end
    return DEFAULT_KEY
end


