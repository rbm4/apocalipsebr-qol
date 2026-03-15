-- AACSUITheme.lua (B42) - UI helpers inspired by BurdJournals_UIShared.lua
AACSUITheme = AACSUITheme or {}

AACSUITheme.Colors = {
    panelBg = {r=0.06, g=0.06, b=0.07, a=1.00},
    panelBorder = {r=0.32, g=0.32, b=0.34, a=1.00},

    headerBg = {r=0.09, g=0.09, b=0.11, a=1.00},
    headerAccent = {r=0.22, g=0.58, b=0.48, a=1.00},

    titleText = {r=1, g=1, b=1, a=1},
    normalText = {r=0.92, g=0.92, b=0.92, a=1},
    dimText = {r=0.62, g=0.62, b=0.62, a=1},

    listBg = {r=0.10, g=0.10, b=0.12, a=1.00},
    listAltBg = {r=0.12, g=0.12, b=0.14, a=1.00},
    listHover = {r=0.14, g=0.14, b=0.18, a=1.00},
    listSelected = {r=0.16, g=0.22, b=0.18, a=1.00},

    tabActive = {r=0.16, g=0.24, b=0.22, a=0.95},
    tabInactive = {r=0.12, g=0.12, b=0.14, a=0.85},
    tabActiveBorder = {r=0.32, g=0.55, b=0.38, a=0.95},
    tabInactiveBorder = {r=0.32, g=0.32, b=0.34, a=0.85},

    btnDark = {r=0.12, g=0.12, b=0.14},
    btnDefault = {r=0.18, g=0.18, b=0.20},
    btnDefaultOver = {r=0.22, g=0.22, b=0.25},
    btnSuccess = {r=0.18, g=0.35, b=0.22},
    btnSuccessOver = {r=0.22, g=0.42, b=0.26},
    btnSuccessBorder = {r=0.32, g=0.55, b=0.38},
    btnInfo = {r=0.18, g=0.26, b=0.38},
    btnInfoOver = {r=0.22, g=0.32, b=0.46},
    btnDanger = {r=0.42, g=0.20, b=0.20},
    btnDangerOver = {r=0.52, g=0.24, b=0.24},
    btnWarn = {r=0.38, g=0.30, b=0.10},
    btnWarnOver = {r=0.46, g=0.36, b=0.12},
    btnWarnBorder = {r=0.86, g=0.72, b=0.22},

    searchBg = {r=0.06, g=0.06, b=0.08, a=0.95},
    searchBorder = {r=0.22, g=0.22, b=0.26, a=0.85},

    priceBg = {r=0.08, g=0.08, b=0.10},
}

-- Status indicators (usando = ao invés de emojis para compatibilidade)
AACSUITheme.StatusIcons = {
    ACTIVE = "=",      -- Visto recentemente (verde no código)
    IDLE = "?",        -- Não visto há algum tempo (amarelo no código)  
    LOST = "!",        -- Perdido (vermelho no código)
}

function AACSUITheme.getStatusIcon(lastSeen)
    if not lastSeen then return AACSUITheme.StatusIcons.LOST end
    
    local now = AACS.Now()
    local lastSeenTime = tonumber(lastSeen)
    if not lastSeenTime then return AACSUITheme.StatusIcons.LOST end
    
    -- Convert to milliseconds if needed
    if lastSeenTime < 1000000000000 then
        lastSeenTime = lastSeenTime * 1000
    end
    
    local diff = now - lastSeenTime
    local oneHour = 3600 * 1000
    local oneDay = 24 * oneHour
    
    if diff < oneHour then
        return AACSUITheme.StatusIcons.ACTIVE
    elseif diff < oneDay then
        return AACSUITheme.StatusIcons.IDLE
    else
        return AACSUITheme.StatusIcons.LOST
    end
end

function AACSUITheme.styleButton(btn, variant)
    if not btn then return end
    local c = AACSUITheme.Colors

    if variant == "success" then
        btn.backgroundColor = {r=c.btnSuccess.r, g=c.btnSuccess.g, b=c.btnSuccess.b, a=0.90}
        btn.backgroundColorMouseOver = {r=c.btnSuccessOver.r, g=c.btnSuccessOver.g, b=c.btnSuccessOver.b, a=0.95}
        btn.borderColor = {r=c.btnSuccessBorder.r, g=c.btnSuccessBorder.g, b=c.btnSuccessBorder.b, a=0.95}
        btn.textColor = {r=1, g=1, b=1, a=1}
    elseif variant == "warning" then
        btn.backgroundColor = {r=c.btnWarn.r, g=c.btnWarn.g, b=c.btnWarn.b, a=0.90}
        btn.backgroundColorMouseOver = {r=c.btnWarnOver.r, g=c.btnWarnOver.g, b=c.btnWarnOver.b, a=0.95}
        btn.borderColor = {r=c.btnWarnBorder.r, g=c.btnWarnBorder.g, b=c.btnWarnBorder.b, a=0.95}
        btn.textColor = {r=1, g=1, b=1, a=1}
    elseif variant == "info" then
        btn.backgroundColor = {r=c.btnInfo.r, g=c.btnInfo.g, b=c.btnInfo.b, a=0.90}
        btn.backgroundColorMouseOver = {r=c.btnInfoOver.r, g=c.btnInfoOver.g, b=c.btnInfoOver.b, a=0.95}
        btn.borderColor = {r=c.panelBorder.r, g=c.panelBorder.g, b=c.panelBorder.b, a=0.85}
        btn.textColor = {r=1, g=1, b=1, a=1}
    elseif variant == "dangerTiny" then
        btn.backgroundColor = {r=c.btnDefault.r, g=c.btnDefault.g, b=c.btnDefault.b, a=0.85}
        btn.backgroundColorMouseOver = {r=c.btnDangerOver.r, g=c.btnDangerOver.g, b=c.btnDangerOver.b, a=0.95}
        btn.borderColor = {r=c.panelBorder.r, g=c.panelBorder.g, b=c.panelBorder.b, a=0.85}
        btn.textColor = {r=0.9, g=0.85, b=0.85, a=1}
    else
        -- default
        btn.backgroundColor = {r=c.btnDefault.r, g=c.btnDefault.g, b=c.btnDefault.b, a=0.90}
        btn.backgroundColorMouseOver = {r=c.btnDefaultOver.r, g=c.btnDefaultOver.g, b=c.btnDefaultOver.b, a=0.95}
        btn.borderColor = {r=c.panelBorder.r, g=c.panelBorder.g, b=c.panelBorder.b, a=0.85}
        btn.textColor = {r=0.95, g=0.95, b=0.95, a=1}
    end
end

function AACSUITheme.styleTabButton(btn, active)
    if not btn then return end
    local c = AACSUITheme.Colors
    if active then
        btn.backgroundColor = {r=c.tabActive.r, g=c.tabActive.g, b=c.tabActive.b, a=c.tabActive.a}
        btn.backgroundColorMouseOver = {r=c.tabActive.r + 0.05, g=c.tabActive.g + 0.05, b=c.tabActive.b + 0.05, a=1}
        btn.borderColor = {r=c.tabActiveBorder.r, g=c.tabActiveBorder.g, b=c.tabActiveBorder.b, a=c.tabActiveBorder.a}
        btn.textColor = {r=1, g=1, b=1, a=1}
    else
        btn.backgroundColor = {r=c.tabInactive.r, g=c.tabInactive.g, b=c.tabInactive.b, a=c.tabInactive.a}
        btn.backgroundColorMouseOver = {r=c.btnDefaultOver.r, g=c.btnDefaultOver.g, b=c.btnDefaultOver.b, a=0.95}
        btn.borderColor = {r=c.tabInactiveBorder.r, g=c.tabInactiveBorder.g, b=c.tabInactiveBorder.b, a=c.tabInactiveBorder.a}
        btn.textColor = {r=c.dimText.r, g=c.dimText.g, b=c.dimText.b, a=1}
    end
end

function AACSUITheme.truncateText(text, maxWidth, font)
    if not text then return "" end
    local tm = getTextManager()
    local f = font or UIFont.Small
    if tm:MeasureStringX(f, text) <= maxWidth then return text end
    local ellipsis = "..."
    local targetWidth = maxWidth - tm:MeasureStringX(f, ellipsis)
    local s = text
    while #s > 0 and tm:MeasureStringX(f, s) > targetWidth do
        s = string.sub(s, 1, -2)
    end
    return s .. ellipsis
end

function AACSUITheme.normQuery(q)
    if not q then return nil end
    q = tostring(q)
    q = q:gsub("^%s+", ""):gsub("%s+$", "")
    if q == "" then return nil end
    return string.lower(q)
end

function AACSUITheme.matchesSearch(normQuery, text)
    if not normQuery then return true end
    local name = string.lower(tostring(text or ""))
    return string.find(name, normQuery, 1, true) ~= nil
end


-- ===== Extra UI polish helpers =====
function AACSUITheme.styleTextEntry(entry)
    if not entry then return end
    local c = AACSUITheme.Colors
    entry.backgroundColor = {r=c.searchBg.r, g=c.searchBg.g, b=c.searchBg.b, a=c.searchBg.a}
    entry.borderColor = {r=c.searchBorder.r, g=c.searchBorder.g, b=c.searchBorder.b, a=c.searchBorder.a}
    entry.textColor = {r=c.normalText.r, g=c.normalText.g, b=c.normalText.b, a=1}
    -- cursorColor exists in newer builds; guard just in case
    if entry.cursorColor ~= nil then
        entry.cursorColor = {r=c.headerAccent.r, g=c.headerAccent.g, b=c.headerAccent.b, a=1}
    end
end

function AACSUITheme.styleComboBox(combo)
    if not combo then return end
    local c = AACSUITheme.Colors
    combo.backgroundColor = {r=c.btnDark.r, g=c.btnDark.g, b=c.btnDark.b, a=0.90}
    combo.borderColor = {r=c.panelBorder.r, g=c.panelBorder.g, b=c.panelBorder.b, a=0.85}
    combo.textColor = {r=c.normalText.r, g=c.normalText.g, b=c.normalText.b, a=1}
end

function AACSUITheme.styleListBox(list)
    if not list then return end
    local c = AACSUITheme.Colors
    list.backgroundColor = {r=c.listBg.r, g=c.listBg.g, b=c.listBg.b, a=c.listBg.a}
    list.borderColor = {r=c.panelBorder.r, g=c.panelBorder.g, b=c.panelBorder.b, a=0.75}
    -- Style the vertical scrollbar so it doesn't overlap the list content
    if list.vscrollBar then
        local sb = list.vscrollBar
        sb.backgroundColor = {r=c.panelBg.r, g=c.panelBg.g, b=c.panelBg.b, a=1}
        sb.borderColor = {r=c.panelBorder.r, g=c.panelBorder.g, b=c.panelBorder.b, a=0.6}
        if sb.btnUp then
            sb.btnUp.backgroundColor = {r=c.btnDefault.r, g=c.btnDefault.g, b=c.btnDefault.b, a=0.8}
            sb.btnUp.borderColor = {r=c.panelBorder.r, g=c.panelBorder.g, b=c.panelBorder.b, a=0.5}
        end
        if sb.btnDown then
            sb.btnDown.backgroundColor = {r=c.btnDefault.r, g=c.btnDefault.g, b=c.btnDefault.b, a=0.8}
            sb.btnDown.borderColor = {r=c.panelBorder.r, g=c.panelBorder.g, b=c.panelBorder.b, a=0.5}
        end
        if sb.btnThumb then
            sb.btnThumb.backgroundColor = {r=c.headerAccent.r, g=c.headerAccent.g, b=c.headerAccent.b, a=0.7}
            sb.btnThumb.borderColor = {r=c.headerAccent.r, g=c.headerAccent.g, b=c.headerAccent.b, a=0.9}
        end
    end
end


-- ===== Premium chrome =====
AACSUITheme.Textures = AACSUITheme.Textures or {}

function AACSUITheme.drawPremiumHeader(panel, x, y, w, h, title, iconTex)
    local c = AACSUITheme.Colors
    -- soft shadow under header
    panel:drawRect(x, y + h, w, 2, 0.35, 0, 0, 0)

    panel:drawRect(x, y, w, h, c.headerBg.a, c.headerBg.r, c.headerBg.g, c.headerBg.b)
    -- subtle highlight strip
    panel:drawRect(x, y + 8, w, 2, 0.10, 1, 1, 1)

    -- accent line
    panel:drawRect(x, y + h - 2, w, 2, c.headerAccent.a, c.headerAccent.r, c.headerAccent.g, c.headerAccent.b)

    -- icon (optional)
    local tx = x + 16
    if iconTex and panel.drawTextureScaled then
        panel:drawTextureScaled(iconTex, tx, y + 12, 28, 28, 1, 1, 1, 1)
        tx = tx + 34
    end

    -- title with shadow
    panel:drawText(title, tx + 1, y + 11, 0, 0, 0, 0.55, UIFont.Large)
    panel:drawText(title, tx,     y + 10, c.titleText.r, c.titleText.g, c.titleText.b, c.titleText.a, UIFont.Large)
end

function AACSUITheme.drawSoftPanel(panel, x, y, w, h)
    local c = AACSUITheme.Colors
    -- outer shadow
    panel:drawRect(x + 2, y + 2, w, h, 0.15, 0, 0, 0)
    -- body
    panel:drawRect(x, y, w, h, c.panelBg.a, c.panelBg.r, c.panelBg.g, c.panelBg.b)
    panel:drawRectBorder(x, y, w, h, c.panelBorder.a, c.panelBorder.r, c.panelBorder.g, c.panelBorder.b)
end


-- ===== Adaptive font helpers (B42) =====
function AACSUITheme.pickFonts(panelWidth)
    -- returns: titleFont, labelFont, listFont
    if panelWidth >= 1080 then
        return UIFont.Large, UIFont.Medium, UIFont.Medium
    elseif panelWidth >= 860 then
        return UIFont.Large, UIFont.Small, UIFont.Medium
    else
        return UIFont.Medium, UIFont.Small, UIFont.Small
    end
end

function AACSUITheme.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
