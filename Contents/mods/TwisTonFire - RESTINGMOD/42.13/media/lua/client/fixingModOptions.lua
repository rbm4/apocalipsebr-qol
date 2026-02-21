local function safeRequire(path)
    local ok = pcall(require, path)
    return ok
end

local function textOr(key, fallback)
    if key == nil then return fallback end
    if type(key) ~= "string" then return tostring(key) end
    if key == "" then return fallback end
    if getTextOrNull then
        local v = getTextOrNull(key)
        if v and v ~= "" then return v end
    end
    return key
end

local function labelText(key)
    return textOr(key, "—")
end

local function tipText(key)
    return textOr(key, nil)
end

local function setTooltip(ctrl, txt)
    if not txt or txt == "" then return end
    if ctrl.setTooltip then
        ctrl:setTooltip(txt)
    elseif ctrl.setToolTipMap then
        ctrl:setToolTipMap({ defaultTooltip = txt })
    else
        ctrl.tooltip = txt
    end
end

local function clamp(v, lo, hi)
    if v == nil then return lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function makeGO(name, control)
    local o = { name = name, control = control }
    function o:storeCurrentValue() end
    function o:restoreOriginalValue() end
    function o:resetLua() MainOptions.instance.resetLua = true end
    function o:restartRequired() MainOptions.instance.restartRequired = true end

    if control and control.isCombobox then
        control.target = o
        control.onChange = function(box)
            o.gameOptions:onChange(o)
            if o.onChange then o:onChange(box) end
        end
    elseif control and control.isTickBox then
        control.changeOptionTarget = o
        control.changeOptionMethod = function(target, index, selected)
            o.gameOptions:onChange(o)
            if o.onChange then o:onChange(index, selected) end
        end
    elseif control and control.isSlider then
        control.target = o
        control.targetFunc = function(target, volume)
            o.gameOptions:onChange(o)
            if o.onChange then o:onChange(control, volume) end
        end
    end
    if control and control.Type == "ISTextEntryBox" then
        control.onTextChange = function()
            o.gameOptions:onChange(o)
            if o.onChange then o:onChange(control:getInternalText()) end
        end
    end
    if control and control.Type == "ISSliderPanel" then
        control.target = o
        control.onValueChange = function(target, val)
            o.gameOptions:onChange(o)
            if o.onChange then o:onChange(val) end
        end
    end
    return o
end

local function patch_MainOptions()
    safeRequire("OptionScreens/MainOptions")
    if not MainOptions then return end
    if MainOptions._TWF_ModOptionsPatched then return end

    local old = MainOptions.addModOptionsPanel

    function MainOptions:addModOptionsPanel()
        if not PZAPI or not PZAPI.ModOptions then
            return old and old(self)
        end
		
		local _GRAW = rawget
		local INITIAL_Y      = _GRAW(_G, "INITIAL_Y")
		local BUTTON_HGT     = _GRAW(_G, "BUTTON_HGT")
		local FONT_HGT_SMALL = _GRAW(_G, "FONT_HGT_SMALL")

		if type(INITIAL_Y) ~= "number" then INITIAL_Y = 20 end
		if type(BUTTON_HGT) ~= "number" then BUTTON_HGT = 25 end
		if type(FONT_HGT_SMALL) ~= "number" then
			FONT_HGT_SMALL = (getTextManager() and getTextManager():getFontHeight(UIFont.Small)) or 18
		end
        PZAPI.ModOptions:load()
        self:addPage(getText("UI_mainscreen_mods"))

        local comboWidth = 45 * (getCore():getOptionFontSizeReal() + 1) + 60
        local splitpoint = self:getWidth() / 3
        local y = INITIAL_Y
        self.addY = 0

        for _, options in ipairs(PZAPI.ModOptions.Data or {}) do
            self:addHorizontalLine(y, labelText(options.name))

            for _, option in ipairs(options.data or {}) do
                local oname    = labelText(option.name)
                local otooltip = tipText(option.tooltip)

                if option.type == "title" then
                    self:addTitle(splitpoint, y, oname)

                elseif option.type == "separator" then
                    self:addHorizontalLineSmall(y)

                elseif option.type == "description" then
                    self:addDescription(splitpoint, y, textOr(option.text, " "))

                elseif option.type == "tickbox" then
                    local tickbox = self:addYesNo(splitpoint, y, BUTTON_HGT, BUTTON_HGT, oname)
                    setTooltip(tickbox, otooltip)
                    option.element = tickbox
                    if option.isEnabled == false then tickbox:setEnable(false) end

                    local go = makeGO(options.modOptionsID .. "." .. option.id, tickbox)
                    function go:toUI()
                        self.control:setSelected(1, option.value and true or false)
                    end
                    function go:apply()
                        local sel = self.control:isSelected(1)
                        if option.onChangeApply and option.value ~= sel then
                            option:onChangeApply(sel)
                        end
                        option.value = sel
                    end
                    function go:onChange(selected)
                        if option.onChange then option:onChange(selected) end
                    end
                    self.gameOptions:add(go)

                elseif option.type == "multipletickbox" then
                    local label = ISLabel:new(splitpoint, y + self.addY, FONT_HGT_SMALL, oname, 1, 1, 1, 1, UIFont.Small, false)
                    label:initialise()
                    self.mainPanel:addChild(label)

                    local multipleTickBox = ISTickBox:new(splitpoint + 20, y + self.addY, BUTTON_HGT, BUTTON_HGT, "")
                    setTooltip(multipleTickBox, otooltip)
                    multipleTickBox:initialise()
                    self.mainPanel:addChild(multipleTickBox)
                    self.mainPanel:insertNewLineOfButtons(multipleTickBox)

                    option.values = option.values or {}
                    for i, value in ipairs(option.values) do
                        multipleTickBox:addOption(labelText(value.name), value.name)
                    end
                    self.addY = self.addY + multipleTickBox:getHeight() + 4
                    for _, v in ipairs(option.values) do
                        if v.isEnabled == false and type(v.name) == "string" then
                            multipleTickBox:disableOption(v.name, true)
                        end
                    end
                    option.element = multipleTickBox

                    local go = makeGO(options.modOptionsID .. "." .. option.id, multipleTickBox)
                    function go:toUI()
                        for i = 1, #self.control.options do
                            self.control:setSelected(i, option.values[i] and option.values[i].value and true or false)
                        end
                    end
                    function go:apply()
                        for i = 1, #self.control.options do
                            local sel = self.control:isSelected(i)
                            if option.onChangeApply and option.values[i] and (option.values[i].value ~= sel) then
                                option:onChangeApply(i, sel)
                            end
                            if option.values[i] then option.values[i].value = sel end
                        end
                    end
                    function go:onChange(index, selected)
                        if option.onChange then option:onChange(index, selected) end
                    end
                    self.gameOptions:add(go)

                elseif option.type == "textentry" then
                    local entry = self:addTextEntry(splitpoint, y, oname, option.value or "")
                    setTooltip(entry, otooltip)
                    option.element = entry
                    if option.isEnabled == false then entry:setEditable(false) end

                    local go = makeGO(options.modOptionsID .. "." .. option.id, entry)
                    function go:toUI()
                        self.control:setText(option.value or "")
                    end
                    function go:apply()
                        local txt = self.control:getInternalText()
                        if option.onChangeApply and (option.value ~= txt) then
                            option:onChangeApply(txt)
                        end
                        option.value = txt
                    end
                    function go:onChange(txt)
                        if option.onChange then option:onChange(txt) end
                    end
                    self.gameOptions:add(go)

                elseif option.type == "combobox" then
                local rawValues = option.values or {}
                local values = {}

                for _, v in ipairs(rawValues) do
                    if type(v) == "table" then
                        table.insert(values, labelText(v.name))
                    else
                        table.insert(values, labelText(v))
                    end
                end

                if #values == 0 then
                    values = { "—" }
                end

                local selected = clamp(tonumber(option.selected) or 1, 1, #values)

                local combo = self:addCombo(splitpoint, y, comboWidth, 20, oname, values, selected)
                option.element = combo
                if option.isEnabled == false then combo.disabled = true end

                if otooltip then
                    if combo.setToolTipMap then
                        combo:setToolTipMap({ defaultTooltip = otooltip })
                    else
                        setTooltip(combo, otooltip)
                    end
                end

                local go = makeGO(options.modOptionsID .. "." .. option.id, combo)
                function go:toUI()
                    local sel = clamp(tonumber(option.selected) or 1, 1, #values)
                    self.control.selected = sel
                    option.selected = sel
                end
                function go:apply()
                    local sel = clamp(tonumber(self.control.selected) or 1, 1, #values)
                    if option.onChangeApply and (option.selected ~= sel) then
                        option:onChangeApply(sel)
                    end
                    option.selected = sel
                end
                function go:onChange(box)
                    local sel = clamp(tonumber(box.selected) or 1, 1, #values)
                    if option.onChange then option:onChange(sel) end
                end
                self.gameOptions:add(go)

                elseif option.type == "colorpicker" then
                    local col = option.color or { r = 1, g = 1, b = 1, a = 1 }
                    local btn = self:addColorButton(splitpoint, y, oname, col, MainOptions.onModColorPick)
                    option.element = btn
                    if option.isEnabled == false then btn:setEnable(false) end
                    setTooltip(btn, otooltip)

                    btn.colorPicker = ISColorPicker:new(0, 0)
                    btn.colorPicker:initialise()
                    btn.colorPicker.pickedTarget = self
                    btn.colorPicker.resetFocusTo = self
                    btn.colorPicker:setInitialColor(ColorInfo.new(col.r, col.g, col.b, col.a or 1))
                    btn.optionID = options.modOptionsID .. "." .. option.id

                    local go = makeGO(btn.optionID, btn)
                    function go:toUI()
                        self.control.backgroundColor = option.color
                    end
                    function go:apply()
                        local oc = option.color or { r=0,g=0,b=0,a=1 }
                        local nc = self.control.backgroundColor or oc
                        if option.onChangeApply and (oc.r ~= nc.r or oc.g ~= nc.g or oc.b ~= nc.b or (oc.a or 1) ~= (nc.a or 1)) then
                            option:onChangeApply(nc)
                        end
                        option.color = nc
                    end
                    function go:onChange(color)
                        if option.onChange then option:onChange(color) end
                    end
                    self.gameOptions:add(go)

                elseif option.type == "button" then
                    local button = self:addButton(splitpoint, y, oname)
                    option.element = button
                    button.id = options.modOptionsID .. "." .. option.id
                    button.target = option.target
                    if option.args then
                        button:setOnClick(option.onclick, option.args[1], option.args[2], option.args[3], option.args[4])
                    else
                        button:setOnClick(option.onclick)
                    end
                    setTooltip(button, otooltip)
                    if option.isEnabled == false then button:setEnable(false) end

                elseif option.type == "keybind" then
                    local keyTextElement = {}
                    local label = ISLabel:new(splitpoint, y + self.addY, FONT_HGT_SMALL + 2, oname, 1, 1, 1, 1, UIFont.Small)
                    label:initialise()
                    label:setAnchorLeft(false)
                    label:setAnchorRight(true)
                    self.mainPanel:addChild(label)

                    local keyCode = tonumber(option.key) or 0
                    local keyName = (keyCode ~= 0 and getKeyName and getKeyName(keyCode)) or textOr("UI_optionscreen_bindingUnassigned", "Unassigned")

                    local btn = ISButton:new(splitpoint + 20, y + self.addY, self.keyButtonWidth, FONT_HGT_SMALL + 2, keyName, self, MainOptions.onKeyBindingBtnPress)
                    btn.internal = option.name
                    btn.isModBind = true
                    btn:initialise()
                    btn:instantiate()
                    setTooltip(btn, otooltip)
                    self.mainPanel:addChild(btn)

                    option.element = btn
                    if option.isEnabled == false then btn:setEnable(false) end

                    keyTextElement.txt = label
                    keyTextElement.keyCode = keyCode
                    keyTextElement.defaultKeyCode = tonumber(option.defaultkey) or 0
                    keyTextElement.altCode = 0
                    keyTextElement.btn = btn
                    keyTextElement.shift = option.shift
                    keyTextElement.ctrl = option.ctrl
                    keyTextElement.left = true
                    keyTextElement.isModBind = true
                    table.insert(MainOptions.keyText, keyTextElement)
                    option.element = keyTextElement

                    self.addY = self.addY + FONT_HGT_SMALL + 2 + 6

                elseif option.type == "slider" then
                    local omin  = tonumber(option.min)  or 0
                    local omax  = tonumber(option.max)  or 100
                    if omax < omin then omax, omin = omin, omax end
                    local ostep = tonumber(option.step) or 1
                    local oval  = tonumber(option.value) or omin

                    local slider = self:addSlider(splitpoint, y, comboWidth, oname, omin, omax, ostep, clamp(oval, omin, omax))
                    option.element = slider
                    setTooltip(slider, otooltip)
                    if option.isEnabled == false then slider.disabled = true end

                    local go = makeGO(options.modOptionsID .. "." .. option.id, slider)
                    function go:toUI()
                        local v = clamp(option.value or omin, omin, omax)
                        self.control.label:setName(tostring(v))
                        self.control:setCurrentValue(v, true)
                    end
                    function go:apply()
                        local cur = self.control:getCurrentValue()
                        if option.onChangeApply and option.value ~= cur then
                            option:onChangeApply(cur)
                        end
                        option.value = cur
                    end
                    function go:onChange(value)
                        self.control.label:setName(tostring(value))
                        if option.onChange then option:onChange(value) end
                    end
                    self.gameOptions:add(go)
                end
            end
        end

        self.mainPanel:setScrollHeight(y + self.addY + 20)
    end

    MainOptions._TWF_ModOptionsPatched = true
    print("[TwisTonFire] MainOptions:addModOptionsPanel patched (no local GameOption dependency).")
end

Events.OnGameBoot.Add(patch_MainOptions)
if Events.OnMainMenuEnter then
    Events.OnMainMenuEnter.Add(patch_MainOptions)
end