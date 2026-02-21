require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ttf_ISCollapsableWindow"
require "TTF_KillStats_UI"
require "TTF_Stats_ModOptions"

local function _getUISettingsForPlayer(p)
    p = p or getPlayer()
    if not p then return nil end
    local md = p:getModData()
    md.TTF_KillStats = md.TTF_KillStats or {}
    md.TTF_KillStats.ui = md.TTF_KillStats.ui or {}
    return md.TTF_KillStats.ui
end

TwisTonFireStats_Chart = TwisTonFireStats_Chart or {}

-- ===== Icon cache / loaders =====
local ICON_H = 38
local _texCacheWeapon = {}
local _texCacheCat    = {}
TTF_UI = TTF_UI or {
    registry = setmetatable({}, { __mode = "k" })
}


local WeaponIconIndex
do
    local ok, idx = pcall(require, "TTF_WeaponIconIndex")
    if ok and type(idx) == "table" then
        WeaponIconIndex = idx
    elseif type(TTF_WeaponIconIndex) == "table" then
        WeaponIconIndex = TTF_WeaponIconIndex
    else
        WeaponIconIndex = {}
        print("[TTF_Stats] WARN: TTF_WeaponIconIndex not found or invalid. Fallback map disabled.")
    end
end

local function _getTexture(name)
    if not name or name == "" then return nil end
    return getTexture(name)
end

local VEHICLE_ICON_CANDIDATES = {
    "media/ui/stats_icons/ttf_icon_vehicle.png",   
    "media/ui/stats_icons/vehicle.png",          
}
local UNARMED_ICON_CANDIDATES = {
    "media/ui/stats_icons/ttf_icon_barehands.png",
    "media/ui/stats_icons/barehands.png",
}

local function _firstExistingTexture(paths)
    for i=1,#paths do
        local t = _getTexture(paths[i])
        if t then return t end
    end
    return nil
end

local function _getPseudoWeaponTex(key)
    if key == "__VEHICLE__" then
        return _firstExistingTexture(VEHICLE_ICON_CANDIDATES)
    elseif key == "__UNARMED__" then
        return _firstExistingTexture(UNARMED_ICON_CANDIDATES)
    end
    return nil
end

local _catToTex = {
    Axe        = "media/ui/stats_icons/axe.png",
    LongBlade  = "media/ui/stats_icons/longblade.png",
    SmallBlade = "media/ui/stats_icons/smallblade.png",
    Spear      = "media/ui/stats_icons/ttfspear.png",
    Blunt      = "media/ui/stats_icons/blunt.png",
    SmallBlunt = "media/ui/stats_icons/smallblunt.png",
    Firearm    = "media/ui/stats_icons/firearm.png",
    Vehicle    = nil,
    Unarmed    = nil,
}

local function GetWeaponIconTexture(fullType)
    if _texCacheWeapon[fullType] ~= nil then return _texCacheWeapon[fullType] end

    -- Pseudo-Icons (Vehicle/Unarmed)
    local pt = _getPseudoWeaponTex(fullType)
    if pt then _texCacheWeapon[fullType] = pt; return pt end

    if fullType and fullType:find("^Base%.") then
        local typePart = fullType:match("%.([^%.]+)$") or fullType
        local t = _getTexture("Item_" .. typePart)
               or _getTexture("Item_" .. string.lower(typePart))
        _texCacheWeapon[fullType] = t
        if t then return t end
    end

    local sm = getScriptManager and getScriptManager()
    local it = sm and sm:getItem(fullType) or nil
    if it and it.getIcon then
        local iconName = it:getIcon()
        if iconName and iconName ~= "" then
            local t = _getTexture("Item_" .. iconName)
                   or _getTexture("Item_" .. string.lower(iconName))
                   or _getTexture("Item_" .. iconName:gsub("%s",""))
            _texCacheWeapon[fullType] = t
            if t then return t end
        end
    end

    local typePart = fullType and (fullType:match("%.([^%.]+)$") or fullType) or ""
    do
        local t = _getTexture("Item_" .. typePart)
               or _getTexture("Item_" .. string.lower(typePart))
               or _getTexture("Item_" .. typePart:gsub("%.", "_"))
        _texCacheWeapon[fullType] = t
        if t then return t end
    end

    do
        local ok, inst = pcall(function()
            if InventoryItemFactory and InventoryItemFactory.CreateItem then
                return InventoryItemFactory.CreateItem(fullType)
            end
            return nil
        end)
        if ok and inst and inst.getTex then
            local t = inst:getTex()
            _texCacheWeapon[fullType] = t
            if t then return t end
            if inst.getIcon then
                local iconName = inst:getIcon()
                if iconName and iconName ~= "" then
                    local t2 = _getTexture("Item_" .. iconName)
                    _texCacheWeapon[fullType] = t2
                    if t2 then return t2 end
                end
            end
        end
    end

    local fileName = WeaponIconIndex and WeaponIconIndex[fullType] or nil
    if fileName and fileName ~= "" then
        local t = _getTexture(fileName)
        _texCacheWeapon[fullType] = t
        return t
    end

    _texCacheWeapon[fullType] = nil
    return nil
end

local function GetCategoryIconTexture(catKey)
    if _texCacheCat[catKey] ~= nil then return _texCacheCat[catKey] end
    local t = _catToTex[catKey] and _getTexture(_catToTex[catKey]) or nil
    if not t then
        if catKey == "Vehicle" then t = _getPseudoWeaponTex("__VEHICLE__") end
        if catKey == "Unarmed" then t = _getPseudoWeaponTex("__UNARMED__") end
    end
    _texCacheCat[catKey] = t
    return t
end

local function DrawIconClipped(panel, tex, x, y, barW, barH)
    if not tex or barW <= 0 then return 0 end
    local tw, th = tex:getWidth(), tex:getHeight()
    if not tw or not th or th <= 0 then return 0 end
    local dh = math.min(barH, ICON_H)
    local scale = dh / th
    local dw = math.max(1, math.floor(tw * scale))
    local dy = y + math.floor((barH - dh) / 2)
    panel:setStencilRect(x, y, barW, barH)
    panel:drawTextureScaled(tex, x + 2, dy, dw, dh, 1.0, 1,1,1)
    panel:clearStencilRect()
    return dw
end

local RANGES = {
    { label = "Week",      days = 7   },
    { label = "Month",     days = 30  },
    { label = "Half-Year", days = 180 },
    { label = "Year",      days = 365 },
    { label = "All",       days = -1  },
}

local KEY_NUMPAD9 = (Keyboard and (Keyboard.KEY_NUMPAD9 or Keyboard.KEY_KP9 or Keyboard.KEY_9)) or 57


local function L(key, ...)
    local argc = select('#', ...)
    if getText then
        local ok, res = pcall(getText, key, ...)
        if ok and res and res ~= "" then
            if argc > 0 and (res:find("%%s") or res:find("%%d") or res:find("%%%.%d")) then
                local ok2, out = pcall(string.format, res, ...)
                if ok2 and out then return out end
            end
            return res
        end
    end
    if argc > 0 then
        local ok3, out2 = pcall(string.format, key, ...)
        if ok3 and out2 then return out2 end
    end
    return key
end

local function _rangeLabel(days)
    if     days == 7   then return L("UI_TTF_RANGE_WEEK")
    elseif days == 30  then return L("UI_TTF_RANGE_MONTH")
    elseif days == 180 then return L("UI_TTF_RANGE_HALFYEAR")
    elseif days == 365 then return L("UI_TTF_RANGE_YEAR")
    else                    return L("UI_TTF_RANGE_ALL")
    end
end

-- -------- CSV helpers --------
local function splitCSV(line)
    local out, i, start = {}, 1, 1
    for j = 1, #line do
        local c = line:sub(j, j)
        if c == "," then
            out[i] = line:sub(start, j - 1)
            i = i + 1
            start = j + 1
        end
    end
    out[i] = line:sub(start)
    return out
end

local function ymd_to_time(s)
    local y,m,d = s:match("^(%d+)%-(%d+)%-(%d+)$")
    if not y then return nil end
    return os.time{ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12, min = 0, sec = 0 }
end

local function time_to_ymd(t)
    return os.date("%Y-%m-%d", t)
end

-- ===== Bars panels (horizontal bars, highest on top) =====

local function _getKillStats()
    return (TTF_KillStats and TTF_KillStats.Get and TTF_KillStats.Get(0)) or nil
end

-- ---------- base helpers ----------
local function _anyMouseDown()
    return isMouseButtonDown(0) or isMouseButtonDown(1) or isMouseButtonDown(2)
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi else return v end
end

local function truncateToWidth(str, font, maxW)
    local tm = getTextManager()
    if not str or str == "" then return "" end
    if maxW <= 8 then return "…" end
    local w = tm:MeasureStringX(font, str)
    if w <= maxW then return str end
    local ell = "…"
    local ellW = tm:MeasureStringX(font, ell)
    local target = maxW - ellW
    local lo, hi, mid = 1, #str, nil
    while lo < hi do
        mid = math.floor((lo + hi) / 2)
        local sub = string.sub(str, 1, mid)
        local sw = tm:MeasureStringX(font, sub)
        if sw > target then
            hi = mid - 1
        else
            lo = mid + 1
        end
    end
    local cut = math.max(1, math.min(#str, lo - 1))
    return string.sub(str, 1, cut) .. ell
end


local function _sortedPairsByCount(tbl)
    local arr = {}
    for k,v in pairs(tbl or {}) do
        table.insert(arr, { key=k, n=tonumber(v) or 0 })
    end
    table.sort(arr, function(a,b)
        if a.n == b.n then return tostring(a.key) < tostring(b.key) end
        return a.n > b.n
    end)
    return arr
end

local function _tooltip(panel, lines, mx, my)
    local tm, f = getTextManager(), UIFont.Small
    local w = 0
    for _,L in ipairs(lines) do
        w = math.max(w, tm:MeasureStringX(f, L))
    end
    w = w + 12
    local h = #lines * tm:getFontFromEnum(f):getLineHeight() + 10
    local x = mx + 16
    local y = my + 16
    if x + w > panel.width - 6 then x = panel.width - 6 - w end
    if y + h > panel.height - 6 then y = panel.height - 6 - h end
    if x < 6 then x = 6 end
    if y < 6 then y = 6 end
    panel:drawRect(x, y, w, h, 0.95, 0,0,0)
    panel:drawRectBorder(x, y, w, h, 0.8, 1,1,1)
    local tx, ty = x+6, y+5
    for _,L in ipairs(lines) do
        panel:drawText(L, tx, ty, 1,1,1,1, f)
        ty = ty + tm:getFontFromEnum(f):getLineHeight()
    end
end

-- ---------- Categories panel ----------
local CategoryBarsPanel = ISPanel:derive("TTF_CategoryBarsPanel")

function CategoryBarsPanel:new(x,y,w,h)
    local o = ISPanel:new(x,y,w,h)
    setmetatable(o, self); self.__index = self
    o.background = false
    o.clip = true
    return o
end

function CategoryBarsPanel:refreshData()
    self.items = {}
    self.maxVal = 0
    local ks = _getKillStats()
    if not ks or not ks.categories then return end
    local list = _sortedPairsByCount(ks.categories)
    for _,it in ipairs(list) do
        if it.n and it.n >= 1 then
            local label = TTF_KillStatsUI.GetCategoryLabel(it.key)
            table.insert(self.items, { key=it.key, label=label, n=it.n })
            if it.n > self.maxVal then self.maxVal = it.n end
        end
    end
end

function CategoryBarsPanel:prerender()
    ISPanel.prerender(self)
end

function CategoryBarsPanel:render()
    ISPanel.render(self)

    local chartsOnly = (self.ownerWindow and self.ownerWindow:isAdornmentsVisible() == false)
    local showTitle  = not chartsOnly
    local title      = L("UI_TTF_TITLE_CATS")
    local titleH     = showTitle and 26 or 0

    local pad = 10
    local left, top, right, bottom = pad, pad + titleH, self.width - pad, self.height - pad
    local cw, ch = right - left, bottom - top
    if cw < 40 or ch < 40 then return end

    if showTitle then
        local maxTitleW = math.max(1, self.width - 16)
        local tdraw = truncateToWidth(title, UIFont.Medium, maxTitleW)
        self:drawText(tdraw, 8, 6, 1,1,1,1, UIFont.Medium)
    end
    if #self.items == 0 then
        self:drawTextCentre(L("UI_TTF_NO_DATA"), self.width/2, self.height/2 - 8, 1,1,1,1, UIFont.Small)
        return
    end

    local barH = (cw >= 420 and 32) or (cw >= 300 and 24) or 20
    local rowH, gap = barH + 4, 1
    local visCount = math.min(#self.items, math.max(1, math.floor((ch - 8) / (rowH + gap))))

    if not chartsOnly then
        local usedH = math.max(0, (visCount * (rowH + gap)) - gap + 4)
        self:drawRectBorder(left, top, cw, math.min(ch, usedH), 0.8, 1,1,1)
    end

    local maxY = math.max(1, self.maxVal)
    local tm = getTextManager()
    local countW = tm:MeasureStringX(UIFont.Small, tostring(self.maxVal or 0))
    local rightGap = countW + 12
    local innerPad = 16

    local labelFont = UIFont.Small
    local lineH = tm:getFontFromEnum(labelFont):getLineHeight()
    local rawMaxLabelW = 0
    for i = 1, visCount do
        local it = self.items[i]
        local wLab = tm:MeasureStringX(labelFont, it.label or it.key)
        if wLab > rawMaxLabelW then rawMaxLabelW = wLab end
    end
    local minBarW  = 24
    local maxLabelW = clamp(rawMaxLabelW, 0, math.max(0, cw - (minBarW + rightGap + innerPad + 24)))
    local labelPad = (maxLabelW > 0) and 8 or 4

    local hovering = self:isMouseOver()
    local mx = getMouseX() - self:getAbsoluteX()
    local my = getMouseY() - self:getAbsoluteY()
    local hoverRect = nil

    for i = 1, visCount do
        local it = self.items[i]
        local y0 = top + (i-1) * (rowH + gap)

        local xLabelRight = left + 8 + maxLabelW
        local x0 = xLabelRight + labelPad

        local wMax = math.max(1, (left + cw) - x0 - innerPad - rightGap)
        local w = math.floor((it.n / maxY) * wMax)
        if w < 1 then w = 1 end

        local yBar = y0 + 2

        self:drawRect(x0, yBar, w, barH, 0.95, 1.00, 0.42, 0.00)
        if not chartsOnly then self:drawRectBorder(x0, yBar, w, barH, 0.45, 0,0,0) end

        local tex = GetCategoryIconTexture(it.key)
        if tex then DrawIconClipped(self, tex, x0, yBar, w, barH) end

        local label = it.label or it.key
        local labelDraw = (maxLabelW > 0) and truncateToWidth(label, labelFont, maxLabelW) or ""
        local ly = yBar + math.floor((barH - lineH) / 2)
        if labelDraw ~= "" then
            self:drawTextRight(labelDraw, xLabelRight, ly, 1,1,1,1, labelFont)
        end

        self:drawText(tostring(it.n), x0 + w + 6, yBar - 1, 1,1,1,1, UIFont.Small)

        if hovering and mx >= x0 and mx <= x0+w and my >= yBar and my <= yBar+barH then
            hoverRect = { x=x0, y=yBar, w=w, h=barH, it=it }
        end
    end

    if (not chartsOnly) and hoverRect then
        self:drawRect(hoverRect.x, hoverRect.y, hoverRect.w, hoverRect.h, 0.10, 1,1,1)
        self:drawRectBorder(hoverRect.x, hoverRect.y, hoverRect.w, hoverRect.h, 0.5, 1,1,1)

        local lines = {
            L("UI_TTF_CAT") .. ": " .. (hoverRect.it.label or hoverRect.it.key),
            L("UI_TTF_KILLS_FMT", tonumber(hoverRect.it.n) or 0)
        }
        if self.ownerWindow and self.ownerWindow.queueTooltip then
            self.ownerWindow:queueTooltip(lines, getMouseX(), getMouseY())
        else
            _tooltip(self, lines, mx, my)
        end
    end
end
-- ---------- Weapons panel ----------
local WeaponBarsPanel = ISPanel:derive("TTF_WeaponBarsPanel")

function WeaponBarsPanel:new(x,y,w,h)
    local o = ISPanel:new(x,y,w,h)
    setmetatable(o, self); self.__index = self
    o.background = false
    o.clip = true
    o._buttons = {}
    o.topN = o.topN or 10
    return o
end

function WeaponBarsPanel:createChildren()
    ISPanel.createChildren(self)

    self._buttons = self._buttons or {}
    for _, b in ipairs(self._buttons) do
        if b and b.parent == self then self:removeChild(b) end
    end
    self._buttons = {}

    local labels = { {5,"Top 5"}, {10,"Top 10"}, {20,"Top 20"} }
    local x, y, w, h, pad = 8, 6, 64, 20, 6

    for _,entry in ipairs(labels) do
        local n, title = entry[1], entry[2]
        local b = ISButton:new(x, y, w, h, title, self, function(_self)
            self.topN = n
            self:refreshData()
        end)
        b:initialise()
        b.borderColor = {r=1,g=1,b=1,a=0.2}
        self:addChild(b)
        table.insert(self._buttons, b)
        x = x + w + pad
    end
end

function WeaponBarsPanel:refreshData()
    self.items = {}
    self.maxVal = 0
    local ks = _getKillStats()
    if not ks or not ks.weapons then return end

    local arr = _sortedPairsByCount(ks.weapons)
    local limit = math.min(self.topN or 10, 20)
    for i, it in ipairs(arr) do
        if i > limit then break end
        local label = TTF_KillStatsUI.GetWeaponLabel(it.key)
        table.insert(self.items, { key=it.key, label=label, n=it.n })
        if it.n > self.maxVal then self.maxVal = it.n end
    end
end

function WeaponBarsPanel:prerender()
    ISPanel.prerender(self)
    local chartsOnly = (self.ownerWindow and self.ownerWindow:isAdornmentsVisible() == false)

    if chartsOnly then
        for _,b in ipairs(self._buttons or {}) do b:setVisible(false) end
        self._buttonsUsedH = 0
    else
        local titleH = 26
        local padX, padY = 6, 4
        local x, y = 8, 6 + titleH
        local rowH = 20
        local maxW = self.width - 16
        local row, maxRow = 1, 1
        for _,b in ipairs(self._buttons or {}) do
            local txtW = getTextManager():MeasureStringX(UIFont.Small, b.title)
            b:setWidth(math.max(56, math.min(96, txtW + 14)))
            if x + b.width > maxW then
                x = 8; y = y + rowH + padY; row = row + 1; if row > maxRow then maxRow = row end
            end
            b:setX(x); b:setY(y); b:setVisible(true)
            x = x + b.width + padX
        end
        self._buttonsUsedH = (maxRow * rowH) + ((maxRow - 1) * padY)
    end
end

function WeaponBarsPanel:render()
    ISPanel.render(self)

    local chartsOnly = (self.ownerWindow and self.ownerWindow:isAdornmentsVisible() == false)
    local showTitle  = not chartsOnly
    local title      = L("UI_TTF_TITLE_WEAP", tonumber(self.topN) or 10)
    local titleH     = showTitle and 26 or 0
    local buttonsH   = chartsOnly and 0 or (self._buttonsUsedH or 20)
    local afterButtonsGap = chartsOnly and 0 or 8

    local pad = 10
    local left  = pad
    local top   = pad + titleH + buttonsH + afterButtonsGap
    local right = self.width - pad
    local bottom= self.height - pad
    local cw, ch = right - left, bottom - top

    if showTitle then
        local maxTitleW = math.max(1, self.width - 16)
        local tdraw = truncateToWidth(title, UIFont.Medium, maxTitleW)
        self:drawText(tdraw, 8, 6, 1,1,1,1, UIFont.Medium)
    end
    if #self.items == 0 then
        self:drawTextCentre(L("UI_TTF_NO_DATA"), self.width/2, self.height/2 - 8, 1,1,1,1, UIFont.Small)
        return
    end

    -- *** Änderung: dynamische Balkenhöhe wie bei Kategorien ***
    local barH = (cw >= 420 and 32) or (cw >= 300 and 24) or 20
    local rowH, gap = barH + 4, 1

    local visCount = math.min(#self.items, math.floor((ch - 8) / (rowH + gap)))

    if not chartsOnly then
        local usedH = math.max(0, (visCount * (rowH + gap)) - gap + 4)
        self:drawRectBorder(left, top, cw, math.min(ch, usedH), 0.8, 1,1,1)
    end

    local maxY = math.max(1, self.maxVal)
    local tm = getTextManager()
    local countW = tm:MeasureStringX(UIFont.Small, tostring(self.maxVal or 0))
    local rightGap = countW + 12
    local innerPad = 16

    local labelFont = UIFont.Small
    local lineH = tm:getFontFromEnum(labelFont):getLineHeight()
    local rawMaxLabelW = 0
    for i = 1, visCount do
        local it = self.items[i]
        local wLab = tm:MeasureStringX(labelFont, it.label or it.key)
        if wLab > rawMaxLabelW then rawMaxLabelW = wLab end
    end
    local minBarW  = 24
    local maxLabelW = clamp(rawMaxLabelW, 0, math.max(0, cw - (minBarW + rightGap + innerPad + 24)))
    local labelPad = (maxLabelW > 0) and 8 or 4

    local hovering = self:isMouseOver()
    local mx = getMouseX() - self:getAbsoluteX()
    local my = getMouseY() - self:getAbsoluteY()
    local hoverRect = nil

    for i = 1, visCount do
        local it = self.items[i]
        local y0 = top + (i-1) * (rowH + gap)

        local xLabelRight = left + 8 + maxLabelW
        local x0 = xLabelRight + labelPad

        local wMax = math.max(1, (left + cw) - x0 - innerPad - rightGap)
        local w = math.floor((it.n / maxY) * wMax)
        if w < 1 then w = 1 end

        local yBar = y0 + math.floor((rowH - barH) / 2)

        self:drawRect(x0, yBar, w, barH, 0.95, 1.00, 0.42, 0.00)
        if not chartsOnly then self:drawRectBorder(x0, yBar, w, barH, 0.45, 0,0,0) end

        local tex = GetWeaponIconTexture(it.key)
        if tex then DrawIconClipped(self, tex, x0, yBar, w, barH) end

        local labelDraw = (maxLabelW > 0) and truncateToWidth(it.label or it.key, labelFont, maxLabelW) or ""
        local ly = yBar + math.floor((barH - lineH) / 2)
        if labelDraw ~= "" then
            self:drawTextRight(labelDraw, xLabelRight, ly, 1,1,1,1, labelFont)
        end

        self:drawText(tostring(it.n), x0 + w + 6, yBar - 1, 1,1,1,1, UIFont.Small)

        if hovering and mx >= x0 and mx <= x0+w and my >= yBar and my <= yBar+barH then
            hoverRect = { x=x0, y=yBar, w=w, h=barH, it=it }
        end
    end

    if (not chartsOnly) and hoverRect then
        self:drawRect(hoverRect.x, hoverRect.y, hoverRect.w, hoverRect.h, 0.10, 1,1,1)
        self:drawRectBorder(hoverRect.x, hoverRect.y, hoverRect.w, hoverRect.h, 0.5, 1,1,1)
        local lines = {
            L("UI_TTF_WEAPON") .. ": " .. (hoverRect.it.label or hoverRect.it.key),
            L("UI_TTF_KILLS_FMT", tonumber(hoverRect.it.n) or 0)
        }
        if self.ownerWindow and self.ownerWindow.queueTooltip then
            self.ownerWindow:queueTooltip(lines, getMouseX(), getMouseY())
        else
            _tooltip(self, lines, mx, my)
        end
    end
end

-- -------- Data loader (reads stats/<UniqueID>.txt) --------
local function readDailySeries(rangeDays)
    if not TwisTonFireStats or not TwisTonFireStats.GetStatsFilePath then
        return {}, 0
    end
    local path = TwisTonFireStats.GetStatsFilePath()
    if not path then return {}, 0 end

    local reader = getFileReader(path, false)
    if not reader then return {}, 0 end

    -- Sammle pro 'dayssurvived' den MAX zkills + optional dailykills aus CSV
    local zByDay, dailyCSV = {}, {}
    reader:readLine() -- header skip
    while true do
        local line = reader:readLine()
        if not line then break end
        line = line:gsub("\r","")
        if line ~= "" then
            local c   = splitCSV(line)
            -- CSV: forename(1), surname(2), zkills(3), dailykills(4), averagekills(5), dayssurvived(6), date(7)
            local z   = tonumber(c[3] or "")
            local dk  = tonumber(c[4] or "")
            local day = tonumber(c[6] or "")
            if z and day and day >= 0 then
                if not zByDay[day] or z > zByDay[day] then zByDay[day] = z end
                if dk and dk >= 0 then dailyCSV[day] = math.max(dailyCSV[day] or 0, dk) end
            end
        end
    end
    reader:close()

    local days = {}
    for d,_ in pairs(zByDay) do table.insert(days, d) end
    table.sort(days)
    if #days == 0 then return {}, 0 end

    -- Window: nur letzte N vorhandene Tage (nicht zwingend lückenlos)
    local startIdx = 1
    if rangeDays and rangeDays > 0 and #days > rangeDays then
        startIdx = #days - (rangeDays - 1)
    end

    local series = {}
    local prevZ, havePrev = 0, false
    for i = startIdx, #days do
        local idx = i - startIdx + 1
        local d   = days[i]
        local z   = zByDay[d] or 0

        -- DAILY: bevorzugt CSV; Fallback Δzkills
        local dk
        if dailyCSV[d] ~= nil then
            dk = math.max(0, dailyCSV[d])
        elseif havePrev then
            dk = math.max(0, z - prevZ)
        else
            dk = 0
        end

        -- AVG: absolut (Mod später installiert? egal) → zkills / dayssurvived
        local av = z / math.max(1, d)

        prevZ, havePrev = z, true
        series[idx] = { day = d, daily = dk, avg = av }
    end

    -- ------- ROBUSTE Y-SKALIERUNG --------
    local n = #series
    local function maxOf(tbl, field, fromIdx)
        local m = 0
        for i = (fromIdx or 1), #tbl do
            local v = tonumber(tbl[i][field] or 0) or 0
            if v > m then m = v end
        end
        return m
    end
    local function percentile95(tbl, field, fromIdx)
        local arr = {}
        for i = (fromIdx or 1), #tbl do
            arr[#arr+1] = tonumber(tbl[i][field] or 0) or 0
        end
        table.sort(arr)
        if #arr == 0 then return 0 end
        local k = math.floor(#arr * 0.95 + 0.5)
        if k < 1 then k = 1 elseif k > #arr then k = #arr end
        return arr[k]
    end

    local avgMax  = maxOf(series, "avg", 1)
    local dailyMaxAll = maxOf(series, "daily", 1)

    -- Join-Spike-Heuristik: erster Punkt >> Rest und day > 0
    local JOIN_SPIKE_FACTOR = 4.0
    local firstIsSpike = false
    if n >= 2 then
        local firstDay   = series[1].day or 0
        local firstDaily = series[1].daily or 0
        local restMax    = maxOf(series, "daily", 2)
        local restP95    = percentile95(series, "daily", 2)
        local restAnchor = math.max(restMax, restP95, 1)
        if firstDay > 0 and firstDaily >= (restAnchor * JOIN_SPIKE_FACTOR) then
            firstIsSpike = true
            series[1].__joinSpike = true  -- (optional: Tooltip/Debug)
        end
    end

    -- displayMax ignoriert Spike für die Achsen-Skalierung
    local displayDaily = dailyMaxAll
    if firstIsSpike then
        local withoutFirstMax = maxOf(series, "daily", 2)
        local withoutFirstP95 = percentile95(series, "daily", 2)
        displayDaily = math.max(withoutFirstMax, withoutFirstP95)
    end
    local windowMax = math.max(1, math.max(displayDaily, avgMax))

    return series, windowMax
end

-- -------- Chart panel --------
local ChartPanel = ISPanel:derive("ChartPanel")

function ChartPanel:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.noBackground = false
    o.backgroundColor = {r=0, g=0, b=0, a=0.6}
    o.borderColor = {r=1, g=1, b=1, a=0.2}
    o.series = {}
    o.maxVal = 0
    o.clip = true
    return o
end

function ChartPanel:setRangeDays(d)
    self.rangeDays = d
    self.series, self.maxVal = readDailySeries(d)
end

function ChartPanel:prerender()
    ISPanel.prerender(self)
    local chartsOnly = (self.ownerWindow and self.ownerWindow:isAdornmentsVisible() == false)
    if not chartsOnly then
        self:drawRectBorder(0, 0, self.width, self.height, 0.8, 1,1,1)
    end
end

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end

function ChartPanel:render()
    ISPanel.render(self)

    local chartsOnly = (self.ownerWindow and self.ownerWindow:isAdornmentsVisible() == false)
    local showTitle  = not chartsOnly
    local titleBase  = L("UI_TTF_TITLE_CHART_BASE")
    local titleH     = showTitle and 26 or 0

    local left, top, right, bottom = 44, titleH + 10, self.width - 12, self.height - 28
    local cw  = math.max(1, right - left)
    local ch  = math.max(1, bottom - top)
    local n   = #self.series

    local function drawTruncatedTitle(txt)
        local maxTitleW = math.max(1, self.width - 16)
        local out = truncateToWidth(txt, UIFont.Medium, maxTitleW)
        self:drawText(out, 8, 6, 1,1,1,1, UIFont.Medium)
    end

    if n == 0 then
        self:drawTextCentre(L("UI_TTF_NO_DATA"), self.width/2, self.height/2 - 8, 1,1,1,1, UIFont.Small)
        if showTitle then
            local title = titleBase
            if self.rangeDays and self.rangeDays > 0 then
                title = L("UI_TTF_TITLE_CHART_LASTDAYS", title, self.rangeDays)
            else
                title = L("UI_TTF_TITLE_CHART_ALLTIME", title)
            end
            drawTruncatedTitle(title)
        end
        return
    end

    local maxY = math.max(1, tonumber(self.maxVal) or 0)

    if not chartsOnly then
        local gy = 4
        local stepY = math.max(1, math.floor(maxY / gy))
        for i = 0, gy do
            local v  = i * stepY
            local yy = bottom - math.floor((v / maxY) * (ch - 1)) - 1
            self:drawRect(left, yy, cw, 1, 0.35, 1,1,1)
        end
    end

    local step    = cw / n
    local baseR, baseG, baseB = 1.00, 0.42, 0.00
    local showAvg = (self.rangeDays ~= 7) and (not chartsOnly)

    local mx = getMouseX() - self:getAbsoluteX()
    local my = getMouseY() - self:getAbsoluteY()
    local hovering = self:isMouseOver()

    local hoverIdx, hoverX0, hoverW = nil, nil, nil

    for i = 1, n do
        local v = self.series[i].daily or 0
        local w = math.max(1, math.floor(step - 1))
        local x0 = math.floor(left + (i - 1) * step + (step - w) / 2)
        local h = math.floor((v / maxY) * (ch - 1))
        if h < 0 then h = 0 end
        if h > ch - 1 then h = ch - 1 end
        local y = top + (ch - h)

        local mul = 0.75 + 0.25 * (i / n)
        local r = math.min(1, math.max(0, baseR * mul))
        local g = math.min(1, math.max(0, baseG * mul))
        local b = math.min(1, math.max(0, baseB * mul))

        self:drawRect(x0, y, w, h, 0.95, r, g, b)
        if not chartsOnly and h >= 2 then
            local hi = math.max(1, math.floor(h * 0.18))
            self:drawRect(x0, y, w, hi, 0.14, 1,1,1)
            self:drawRectBorder(x0, y, w, h, 0.35, 0,0,0)
        end

        if showAvg then
            local av  = self.series[i].avg or 0
            local hA  = math.floor((av / maxY) * (ch - 1))
            if hA < 0 then hA = 0 elseif hA > ch - 1 then hA = ch - 1 end
            local yA  = top + (ch - hA)
            local wA  = math.max(1, math.floor(w * 0.10))
            local xA  = x0 + math.floor((w - wA) / 2)
            self:drawRect(xA, yA, wA, hA, 0.95, 0.90, 0.23, 0.26)
            if not chartsOnly then
                self:drawRectBorder(xA, yA, wA, hA, 0.45, 0,0,0)
            end
        end

        if hovering and mx >= x0 and mx <= x0+w and my >= top and my <= top+ch then
            hoverIdx, hoverX0, hoverW = i, x0, w
        end
    end

    if (not chartsOnly) and hoverIdx then
        self:drawRect(hoverX0, top, hoverW, ch, 0.08, 1,1,1)
        self:drawRectBorder(hoverX0, top, hoverW, ch, 0.35, 1,1,1)

        local v   = self.series[hoverIdx].daily or 0
        local av  = self.series[hoverIdx].avg or 0
        local d   = self.series[hoverIdx].day  or hoverIdx

        local l1 = L("UI_TTF_TOOLTIP_DAY",  tostring(d))
        local l2 = L("UI_TTF_TOOLTIP_KILLS", tonumber(v) or 0)
        local l3 = showAvg and L("UI_TTF_TOOLTIP_AVG",   av) or nil
        local lines = l3 and { l1, l2, l3 } or { l1, l2 }

        if self.ownerWindow and self.ownerWindow.queueTooltip then
            self.ownerWindow:queueTooltip(lines, getMouseX(), getMouseY())
        else
            local tm, fnt = getTextManager(), UIFont.Small
            local wT = math.max(tm:MeasureStringX(fnt, l1), tm:MeasureStringX(fnt, l2))
            if l3 then wT = math.max(wT, tm:MeasureStringX(fnt, l3)) end
            local hT = (l3 and 3 or 2) * tm:getFontFromEnum(fnt):getLineHeight() + 10
            local tx = math.min(self.width - 6 - wT - 6, hoverX0 + hoverW + 12)
            local ty = math.max(6, my + 16)
            if ty + hT > self.height - 6 then ty = self.height - 6 - hT end
            self:drawRect(tx-6, ty-5, wT+12, hT, 0.95, 0,0,0)
            self:drawRectBorder(tx-6, ty-5, wT+12, hT, 0.8, 1,1,1)
            self:drawText(l1, tx, ty, 1,1,1,1, fnt)
            ty = ty + tm:getFontFromEnum(fnt):getLineHeight()
            self:drawText(l2, tx, ty, 1,1,1,1, fnt)
            if l3 then
                ty = ty + tm:getFontFromEnum(fnt):getLineHeight()
                self:drawText(l3, tx, ty, 1,1,1,1, fnt)
            end
        end
    end

    if not chartsOnly then
        self:drawTextRight(tostring(0), left-6, bottom-7, 1,1,1,1, UIFont.Small)
        self:drawTextRight(tostring(maxY), left-6, top-7, 1,1,1,1, UIFont.Small)

        local firstDay = self.series[1].day or 0
        local lastDay  = self.series[n].day or (firstDay + n - 1)
        self:drawText(tostring(firstDay), left, bottom+4, 1,1,1,1, UIFont.Small)
        self:drawTextRight(tostring(lastDay), right, bottom+4, 1,1,1,1, UIFont.Small)
        if n >= 14 then
            local midDay = self.series[math.floor(n/2)].day or math.floor((firstDay + lastDay)/2)
            self:drawTextCentre(tostring(midDay), left + cw/2, bottom+4, 1,1,1,1, UIFont.Small)
        end

        local title = titleBase
        if self.rangeDays and self.rangeDays > 0 then
            title = L("UI_TTF_TITLE_CHART_LASTDAYS", title, self.rangeDays)
        else
            title = L("UI_TTF_TITLE_CHART_ALLTIME", title)
        end
        drawTruncatedTitle(title)
    end
end

-- -------- Window --------
local ChartWindow = ttf_ISCollapsableWindow:derive("TTFStatsChartWindow")

function ChartWindow:new(x, y, w, h)
    local o = ttf_ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.title = L("UI_TTF_STATS_TITLE")
    o.resizable = true
    o.pin = true
    o.clearStentil = true

    o._adornmentsVisible = true
    o._hoverHideEnabled  = false
    return o
end

function ChartWindow:_drawActiveTabBG()
    if not self._adornmentsVisible then return end
    local btn = nil
    if     self.activeTab == "chart"      then btn = self.tabChart
    elseif self.activeTab == "categories" then btn = self.tabCat
    elseif self.activeTab == "weapons"    then btn = self.tabWeap
    end
    if not (btn and btn:getIsVisible()) then return end

    local x = btn:getX() - 4
    local y = btn:getY() - 3
    local w = btn:getWidth()  + 8
    local h = btn:getHeight() + 6

    self:drawRect(x, y, w, h, 0.22, 1,1,1)
    self:drawRectBorder(x, y, w, h, 0.55, 1,1,1)
end

function ChartWindow:_drawTooltipWindow(lines, screenX, screenY)
    local tm, f = getTextManager(), UIFont.Small
    local w = 0
    for _,L in ipairs(lines) do
        w = math.max(w, tm:MeasureStringX(f, L))
    end
    w = w + 12
    local h = #lines * tm:getFontFromEnum(f):getLineHeight() + 10

    local mx = screenX - self:getAbsoluteX()
    local my = screenY - self:getAbsoluteY()
    local x  = mx + 16
    local y  = my + 16

    if x + w > self.width  - 6 then x = self.width  - 6 - w end
    if y + h > self.height - 6 then y = self.height - 6 - h end
    if x < 6 then x = 6 end
    if y < 6 then y = 6 end

    self:clearStencilRect()

    self:drawRect(x, y, w, h, 0.95, 0,0,0)
    self:drawRectBorder(x, y, w, h, 0.8, 1,1,1)

    local tx, ty = x+6, y+5
    for _,L in ipairs(lines) do
        self:drawText(L, tx, ty, 1,1,1,1, f)
        ty = ty + tm:getFontFromEnum(f):getLineHeight()
    end
end

function ChartWindow:render()
    ttf_ISCollapsableWindow.render(self)

    local q = self._queuedTooltip
    if q then
        self:_drawTooltipWindow(q.lines, q.sx, q.sy)
        self._queuedTooltip = nil
    end
end

function ChartWindow:queueTooltip(lines, screenX, screenY)
    self._queuedTooltip = { lines = lines, sx = screenX, sy = screenY }
end

function ChartWindow:isAdornmentsVisible()
    return self._adornmentsVisible == true
end

function ChartWindow:setAdornmentsVisible(visible)
    if self._adornmentsVisible == visible then return end
    self._adornmentsVisible = visible

    self:setDrawFrame(visible)
    if self.pinButton      then self.pinButton:setVisible(false)      end
    if self.collapseButton then self.collapseButton:setVisible(false) end

    local tabs = { self.tabChart, self.tabCat, self.tabWeap }
    for _, t in ipairs(tabs) do if t then t:setVisible(visible) end end
    if self.btnStealth then self.btnStealth:setVisible(visible) end
    if self.btnRepair  then self.btnRepair:setVisible(visible)  end  -- NEW

    if visible then
        self:updateRangeButtonsVisibility()
    else
        for _, b in ipairs(self.buttons or {}) do b:setVisible(false) end
        self._rangeButtonsH = 0
    end

    self:doLayout()
end

function ChartWindow:_syncResizeWidgets()
    local rh = self:resizeWidgetHeight() 
    if self.resizeWidget then
        self.resizeWidget:setX(self.width  - rh)
        self.resizeWidget:setY(self.height - rh)
        self.resizeWidget:setWidth(rh)
        self.resizeWidget:setHeight(rh)
        self.resizeWidget:bringToTop()
    end
    if self.resizeWidget2 then
        self.resizeWidget2:setX(0)
        self.resizeWidget2:setY(self.height - rh)
        self.resizeWidget2:setWidth(self.width - rh)
        self.resizeWidget2:setHeight(rh)
        self.resizeWidget2:bringToTop()
    end
end

function ChartWindow:setActiveTab(tabKey)
    self.activeTab = tabKey

    local isChart = (tabKey == "chart")
    self.chart:setVisible(isChart)
    self.catPanel:setVisible(tabKey == "categories")
    self.weapPanel:setVisible(tabKey == "weapons")

    for _,b in ipairs(self.buttons or {}) do b:setVisible(isChart) end

    if tabKey == "categories" then
        self.catPanel:refreshData()
    elseif tabKey == "weapons" then
        self.weapPanel:refreshData()
    elseif tabKey == "chart" then
        self.chart:setRangeDays(self.chart.rangeDays or 30)
    end
end

function ChartWindow:refreshVisibleTabData()
    if     self.activeTab == "categories" and self.catPanel then
        self.catPanel:refreshData()
    elseif self.activeTab == "weapons" and self.weapPanel then
        self.weapPanel:refreshData()
    elseif self.activeTab == "chart"   and self.chart then
        self.chart:setRangeDays(self.chart.rangeDays or 30)
    end
end

function ChartWindow:createChildren()
    ttf_ISCollapsableWindow.createChildren(self)

    self.isCollapsed = false
    if self.pinButton      then self.pinButton:setVisible(false);      self.pinButton:setEnable(false)      end
    if self.collapseButton then self.collapseButton:setVisible(false); self.collapseButton:setEnable(false) end
    if self.setForceHidePinCollapse then self:setForceHidePinCollapse(true) end

    self.activeTab = "chart"

    -- === Range buttons (header) ===
    local btnW, btnH = 84, 22
    self.buttons = {}
    for _, r in ipairs(RANGES) do
        local b = ISButton:new(0, 0, btnW, btnH, _rangeLabel(r.days), self, function()
            self.chart:setRangeDays(r.days)
        end)
        b:initialise()
        b.borderColor = { r=1,g=1,b=1,a=0.2 }
        b._rangeDays = r.days
        self:addChild(b)
        table.insert(self.buttons, b)
    end

    -- === Panels (center) ===
    self.chart = ChartPanel:new(8, 56, self.width - 16 - 112, self.height - 56 - 8)
    self:addChild(self.chart)
    self.chart.ownerWindow = self
    self.chart:setRangeDays(30)

    self.catPanel = CategoryBarsPanel:new(8, 56, self.width - 16 - 112, self.height - 56 - 8)
    self.catPanel:initialise()
    self.catPanel:setVisible(false)
    self:addChild(self.catPanel)
    self.catPanel.ownerWindow = self

    self.weapPanel = WeaponBarsPanel:new(8, 56, self.width - 16 - 112, self.height - 56 - 8)
    self.weapPanel:initialise()
    self.weapPanel:setVisible(false)
    self:addChild(self.weapPanel)
    self.weapPanel.ownerWindow = self

    -- === Right-side icon buttons ===
    local ICON_BTN_SIZE = 48
    local function makeIconButton(texPath, tooltipKey, onClick)
        local b = ISButton:new(0, 0, ICON_BTN_SIZE, ICON_BTN_SIZE, "", self, onClick)
        b:initialise()
        b:setDisplayBackground(false)
        b.borderColor.a = 0
        b:setImage(getTexture(texPath))
        b:forceImageSize(ICON_BTN_SIZE, ICON_BTN_SIZE)
        b.tooltip = L(tooltipKey)
        return b
    end
    self.tabChart = makeIconButton("media/ui/ttfgraph.png",    "UI_TTF_TAB_CHART",      function() self:setActiveTab("chart")      end); self:addChild(self.tabChart)
    self.tabCat   = makeIconButton("media/ui/ttfcategory.png", "UI_TTF_TAB_CATEGORIES", function() self:setActiveTab("categories") end); self:addChild(self.tabCat)
    self.tabWeap  = makeIconButton("media/ui/ttfweapon.png",   "UI_TTF_TAB_WEAPONS",    function() self:setActiveTab("weapons")    end); self:addChild(self.tabWeap)

    self.btnStealth = makeIconButton("media/ui/ttfhide_off.png", "UI_TTF_TOGGLE_HIDE", function()
        self._hoverHideEnabled = not self._hoverHideEnabled
        self:_saveHoverHideToModData()
        self:_applyToggleButtonText()
        if not self._hoverHideEnabled then self:setAdornmentsVisible(true) end
        self:doLayout()
    end)
    self:addChild(self.btnStealth)

    -- === NEW: bottom-right REPAIR button ===
    self.btnRepair = ISButton:new(0, 0, 84, 24, "REPAIR", self, function()
        if TwisTonFireStats and TwisTonFireStats.RepairStatsFile then
            local ok = TwisTonFireStats.RepairStatsFile({ backup = true })
            if ok then
                -- nach Reparatur Daten neu laden
                self:refreshVisibleTabData()
                if self.chart then self.chart:setRangeDays(self.chart.rangeDays or 30) end
            else
                print("[TTF_Stats] REPAIR failed (no valid rows or write error).")
            end
        else
            print("[TTF_Stats] REPAIR unavailable: TwisTonFireStats.RepairStatsFile missing.")
        end
    end)
    self.btnRepair:initialise()
    self.btnRepair.borderColor = { r=1,g=1,b=1,a=0.2 }
    self:addChild(self.btnRepair)
    self.btnRepair:setVisible(self._adornmentsVisible == true)

    self:setActiveTab("chart")
    self:_loadHoverHideFromModData()
    self:_applyToggleButtonText()
end

function ChartWindow:_loadHoverHideFromModData()
    local ui = _getUISettingsForPlayer()
    self._hoverHideEnabled = (ui and ui.hoverHideEnabled == true) or false
end

function ChartWindow:_saveHoverHideToModData()
    local ui = _getUISettingsForPlayer()
    if ui then ui.hoverHideEnabled = (self._hoverHideEnabled == true) end
end

function ChartWindow:_applyToggleButtonText()
    if not self.btnStealth then return end
    local on = (self._hoverHideEnabled == true)
    self.btnStealth:setImage(getTexture(on and "media/ui/ttfhide_on.png" or "media/ui/ttfhide_off.png"))
    self.btnStealth.tooltip = on and
        L("UI_TTF_TOGGLE_HIDE_TT_ON") or
        L("UI_TTF_TOGGLE_HIDE_TT_OFF")
end

-- Hard-disable collapsing forever (window always expanded)
function ChartWindow:collapse() end
function ChartWindow:setCollapsed(_b) self.isCollapsed = false end

function ChartWindow:updateRangeButtonsVisibility()
    if not self._adornmentsVisible then
        for _, b in ipairs(self.buttons or {}) do b:setVisible(false) end
        self._rangeButtonsH = 0
        return
    end

    local isChartTab = (self.activeTab == "chart")

    local player = getPlayer()
    local days   = player and math.floor((player:getHoursSurvived() or 0) / 24) or 0
    local MIN_REQ = { [7]=0, [30]=8, [180]=31, [365]=181, [-1]=0 }
    local function allowed(d) return days >= (MIN_REQ[d] or 0) end

    local headerH = 24
    local padX, padY = 6, 4
    local y = headerH + 6
    local rowH = 22
    local row, maxRow = 1, 1
    local x = 8

    local sideW  = self._adornmentsVisible and (self.sideW or 132) or 0
    local innerW = math.max(1, self.width - 16 - sideW)
    local maxW   = 8 + innerW - 8

    local anyShown = false
    for _, b in ipairs(self.buttons or {}) do
        local show = (isChartTab and allowed(b._rangeDays))
        b:setVisible(show)
        if show then
            anyShown = true
            local txtW = getTextManager():MeasureStringX(UIFont.Small, b.title or "")
            b:setWidth(math.max(64, math.min(110, txtW + 18)))

            if x + b.width > maxW then
                x = 8
                y = y + rowH + padY
                row = row + 1
                if row > maxRow then maxRow = row end
            end

            b:setX(x); b:setY(y)
            b:setHeight(rowH)
            x = x + b.width + padX
        end
    end

    local computedH = anyShown and ((maxRow * rowH) + ((maxRow - 1) * padY)) or 0
    local afterButtonsGap = 6
    local predictedInnerH = self.height - (headerH + computedH + afterButtonsGap) - 8
    local tooShort = (predictedInnerH < 70)

    if (not isChartTab) or (not anyShown) or tooShort then
        for _, b in ipairs(self.buttons or {}) do b:setVisible(false) end
        self._rangeButtonsH = 0
    else
        self._rangeButtonsH = computedH
    end

    if self.chart and isChartTab then
        local cur = self.chart.rangeDays or 30
        if not allowed(cur) then
            local fallback
            if     allowed(30) then fallback = 30
            elseif allowed(7)  then fallback = 7
            else   fallback = -1
            end
            self.chart:setRangeDays(fallback)
        end
    end
end

function ChartWindow:_doMinClampAndScreenClamp()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local minW, minH = 360, 260
    if not _anyMouseDown() then
        if self.width  < minW then self:setWidth(minW) end
        if self.height < minH then self:setHeight(minH) end
    end
    local nx = math.max(0, math.min(self.x, sw - math.max(120, self.width)))
    local ny = math.max(0, math.min(self.y, sh - math.max(80,  self.height)))
    if nx ~= self.x then self:setX(nx) end
    if ny ~= self.y then self:setY(ny) end
end

function ChartWindow:doLayout()
    local ICON_BTN_SIZE   = 48
    local ICON_GAP        = 0
    local SIDE_INNER_PAD  = 8
    local SIDE_RIGHT_PAD  = 14
    local minInnerW       = 220

    if self._adornmentsVisible then
        self.sideW = ICON_BTN_SIZE + SIDE_INNER_PAD + SIDE_RIGHT_PAD
    else
        self.sideW = 0
    end

    self:updateRangeButtonsVisibility()
    local headerH = self._adornmentsVisible and 24 or 0

    local cy      = headerH + (self._adornmentsVisible and (self._rangeButtonsH or 0) or 0) + 6
    local innerW  = self.width - 16 - (self._adornmentsVisible and self.sideW or 0)
    if innerW < minInnerW then
        self.sideW = math.max(0, self.width - 16 - minInnerW)
        innerW     = math.max(1, self.width - 16 - (self._adornmentsVisible and self.sideW or 0))
    end
    local innerH  = math.max(0, self.height - cy - 8)

    if self.chart     then self.chart:setX(8);     self.chart:setY(cy); self.chart:setWidth(innerW); self.chart:setHeight(innerH) end
    if self.catPanel  then self.catPanel:setX(8);  self.catPanel:setY(cy); self.catPanel:setWidth(innerW); self.catPanel:setHeight(innerH) end
    if self.weapPanel then self.weapPanel:setX(8); self.weapPanel:setY(cy); self.weapPanel:setWidth(innerW); self.weapPanel:setHeight(innerH) end

    if not self._adornmentsVisible then
        if self.tabChart   then self.tabChart:setVisible(false)   end
        if self.tabCat     then self.tabCat:setVisible(false)     end
        if self.tabWeap    then self.tabWeap:setVisible(false)    end
        if self.btnStealth then self.btnStealth:setVisible(false) end
        if self.btnRepair  then self.btnRepair:setVisible(false)  end
        self:_syncResizeWidgets()
        return
    end

    local sx = self.width - self.sideW + SIDE_INNER_PAD
    local sy = headerH + 6

    local function placeIcon(btn)
        if not btn then return end
        btn:setVisible(true)
        btn:setX(sx); btn:setY(sy)
        btn:setWidth(ICON_BTN_SIZE); btn:setHeight(ICON_BTN_SIZE)
        sy = sy + ICON_BTN_SIZE + ICON_GAP
    end
    placeIcon(self.btnStealth)
    placeIcon(self.tabChart)
    placeIcon(self.tabCat)
    placeIcon(self.tabWeap)

    if self.btnRepair then
        local pad = 8
        local rh  = (self.resizeWidget and self:resizeWidgetHeight()) or 0
        local bh  = self.btnRepair:getHeight()
        self.btnRepair:setWidth(ICON_BTN_SIZE)  
        self.btnRepair:setX(sx)              
        self.btnRepair:setY(self.height - pad - rh - 2 - bh) 
        self.btnRepair:setVisible(true)
    end

    self:_syncResizeWidgets()
end

function ChartWindow:resetWindowState()
    self.isCollapsed = false
    self:clearMaxDrawHeight()
    self.pin = true
    ttf_ISCollapsableWindow.pin(self)

    if self.pinButton      then self.pinButton:setVisible(false)      end
    if self.collapseButton then self.collapseButton:setVisible(false) end

    self:_doMinClampAndScreenClamp()
    self:doLayout()
end

function ChartWindow:onResize()
    self:_doMinClampAndScreenClamp()
    self:doLayout()
end

function ChartWindow:prerender()
    ttf_ISCollapsableWindow.prerender(self)

    self:_doMinClampAndScreenClamp()
    self:doLayout()

    local over =
        (self:isMouseOver() == true) or
        (self.chart     and self.chart:isMouseOver()     == true) or
        (self.catPanel  and self.catPanel:isMouseOver()  == true) or
        (self.weapPanel and self.weapPanel:isMouseOver() == true) or
        (self.tabChart  and self.tabChart:isMouseOver()  == true) or
        (self.tabCat    and self.tabCat:isMouseOver()    == true) or
        (self.tabWeap   and self.tabWeap:isMouseOver()   == true) or
        (self.resizeWidget  and self.resizeWidget:isMouseOver()  == true) or
        (self.resizeWidget2 and self.resizeWidget2:isMouseOver() == true)

    if self._hoverHideEnabled then
        self:setAdornmentsVisible(over == true)
    else
        if not self._adornmentsVisible then self:setAdornmentsVisible(true) end
    end

    self:_drawActiveTabBG()

    if self.resizeWidget  then self.resizeWidget:bringToTop()  end
    if self.resizeWidget2 then self.resizeWidget2:bringToTop() end
end

-- -------- Singleton + Keybind --------
local g_win = nil

function TwisTonFireStats_Chart.toggle()
    if not g_win then
        local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
        local w, h = math.floor(sw * 0.38), math.floor(sh * 0.34)
        local x, y = math.floor(sw*0.5 - w*0.5), math.floor(sh*0.5 - h*0.5)
        g_win = ChartWindow:new(x, y, w, h)
        g_win:initialise()
        if g_win.setForceHidePinCollapse then g_win:setForceHidePinCollapse(true) end
        g_win:addToUIManager()
        g_win:setVisible(true)
        g_win:bringToTop()
        g_win:refreshVisibleTabData()
    else
        local vis = g_win:getIsVisible()
        g_win:setVisible(not vis)
        if not vis then
            g_win:resetWindowState()
            g_win:bringToTop()
            g_win:refreshVisibleTabData()
        end
    end
end

local function onKeyPressed(key)
    if not getPlayer() then return end
    local toggleKey =
        (TTF_StatsOptions and TTF_StatsOptions.GetToggleKey and TTF_StatsOptions.GetToggleKey())
        or KEY_NUMPAD9
    if key == toggleKey then
        TwisTonFireStats_Chart.toggle()
    end
end
Events.OnKeyPressed.Add(onKeyPressed)

local function _onZombieDeadRefresh(_zombie)
    if not g_win or not g_win:getIsVisible() then return end
    if g_win.activeTab == "categories" and g_win.catPanel then
        g_win.catPanel:refreshData()
    elseif g_win.activeTab == "weapons" and g_win.weapPanel then
        g_win.weapPanel:refreshData()
    end
end
Events.OnZombieDead.Add(_onZombieDeadRefresh)

function TTF_UI.register(win)
    if win then TTF_UI.registry[win] = true end
end

function TTF_UI.unregister(win)
    if win then TTF_UI.registry[win] = nil end
end

function TTF_UI.closeAll()
    for win,_ in pairs(TTF_UI.registry) do
        if win then
            if win.removeFromUIManager then win:removeFromUIManager() end
            if win.setVisible then win:setVisible(false) end
        end
    end
    if g_win and g_win.setVisible then g_win:setVisible(false) end
end

local function _TTF_CloseUI_OnPlayerDeath(playerObj)
    if not playerObj or playerObj ~= getPlayer() then return end
    TTF_UI.closeAll()
end
Events.OnPlayerDeath.Add(_TTF_CloseUI_OnPlayerDeath)