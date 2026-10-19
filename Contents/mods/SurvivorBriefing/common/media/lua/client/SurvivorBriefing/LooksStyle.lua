-- Styled looks: Agent (Division), Y2K, Hip-hop (90s rap). See Card.lua for what a look is.
SurvivorBriefing = SurvivorBriefing or {}
local SB = SurvivorBriefing
SB.Looks = SB.Looks or {}

local function F() return SB.Fonts end
local function T() return SB.Card.T end

local function allTexts(c, extra)
    local out = { c.header, c.dayText, c.clock, c.date }
    for _, r in ipairs(c.rows) do
        table.insert(out, r.label); table.insert(out, r.value); table.insert(out, r.rawValue)
        if r.sub then table.insert(out, r.sub) end
    end
    for _, s in ipairs(extra or {}) do table.insert(out, s) end
    return out
end

-- ---- Agent (Division) -------------------------------------------------------------------------
-- An ISAC-style panel: dark translucent, an orange edge and corner brackets, the SHD emblem,
-- orange labels and white values. With motion on a scan line sweeps down the panel once.
local OR, OG, OB = 1, 0.43, 0.1

SB.Looks.agent = {
    layout = function(c)
        local Fn, u = F(), c.lu
        c.top = SB.upper(c:L("Agent_Header"))
        local all = allTexts(c, { c.top })
        local function ag(px, game) return Fn.pick(all, Fn.make("sb_agent", px), Fn.make("sb_cond", px * 0.92), Fn.game(game)) end
        c.fTop, c.fBig = ag(c.px * 0.75, "Small"), ag(c.px * 1.65, "Large")
        c.fLabel, c.fValue = ag(c.px * 0.78, "Medium"), ag(c.px * 0.95, "Large")
        local th, bh, vh = Fn.height(c.fTop), Fn.height(c.fBig), Fn.height(c.fValue)
        c.icon = math.floor((th + bh) * 0.85)
        c.textX = c.icon + math.floor(10 * u)
        local y = 0
        c.yTop = y
        c.yBig = th - math.floor(2 * u)
        y = c.yBig + bh + math.floor(4 * u)
        c.yRule = y; y = y + math.floor(8 * u)
        local w = math.max(c.textX + Fn.width(c.fTop, c.top), c.textX + Fn.width(c.fBig, c.header))
        if c.clock or c.date then
            c.yDate = y; y = y + vh + math.floor(4 * u)
            c.clockW = c.clock and (Fn.width(c.fValue, c.clock) + math.floor(10 * u)) or 0
            w = math.max(w, c.clockW + (c.date and Fn.width(c.fLabel, c.date) or 0))
        end
        local labelW = 0
        for _, r in ipairs(c.rows) do labelW = math.max(labelW, Fn.width(c.fLabel, r.label)) end
        c.valueX = math.floor(12 * u) + labelW + math.floor(14 * u)
        for _, r in ipairs(c.rows) do
            r.ay = y; y = y + vh + math.floor(2 * u)
            local vw = Fn.width(c.fValue, r.value)
            if r.sub then r.aySub = y - math.floor(3 * u); y = y + Fn.height(c.fLabel); vw = math.max(vw, Fn.width(c.fLabel, r.sub)) end
            w = math.max(w, c.valueX + vw)
        end
        c.blockW, c.blockH = w + math.floor(8 * u), y
        c.padX, c.padY = math.floor(20 * u), math.floor(16 * u)
        local starts = c:schedule(#c.rows + 1)
        c.dateStart = starts[1]
        for i, r in ipairs(c.rows) do r.start = starts[i + 1] end
    end,
    render = function(c, e, a)
        local Fn, u = F(), c.lu
        local x, y = c:placement()
        local bx, by, bw, bh = x - c.padX, y - c.padY, c.blockW + 2 * c.padX, c.blockH + 2 * c.padY
        c:drawRect(bx, by, bw, bh, a * 0.62, 0.03, 0.04, 0.05)
        local t = math.max(2, math.floor(2.5 * u))
        c:drawRect(bx, by, t, bh, a, OR, OG, OB)
        local L = math.floor(16 * u)
        for _, cnr in ipairs({ { bx + bw, by, -1, 1 }, { bx + bw, by + bh, -1, -1 }, { bx, by + bh, 1, -1 } }) do
            local cx, cy, sx, sy = cnr[1], cnr[2], cnr[3], cnr[4]
            c:drawRect(sx > 0 and cx or (cx - L), sy > 0 and cy or (cy - t), L, t, a, OR, OG, OB)
            c:drawRect(sx > 0 and cx or (cx - t), sy > 0 and cy or (cy - L), t, L, a, OR, OG, OB)
        end
        local icon = getTexture(SB.TEX .. "shd.png")
        if icon then c:drawTextureScaled(icon, x, y + math.floor(2 * u), c.icon, c.icon, a, 1, 1, 1) end
        c:print(c.fTop, c.top, x + c.textX, y + c.yTop, OR, OG, OB, a)
        c:print(c.fBig, c.header, x + c.textX, y + c.yBig, 1, 1, 1, a)
        c:drawRect(x, y + c.yRule, c.blockW, 1, a * 0.45, 1, 1, 1)
        for tx = x, x + c.blockW, math.floor(22 * u) do c:drawRect(tx, y + c.yRule - 3, 1, 7, a * 0.45, 1, 1, 1) end
        if c.yDate then
            local k = SB.smooth((e - c.dateStart) / T().LINE_DUR)
            if c.clock then c:print(c.fValue, c.clock, x, y + c.yDate, 1, 1, 1, a * k) end
            if c.date then
                c:print(c.fLabel, c.date, x + c.clockW, y + c.yDate + (Fn.height(c.fValue) - Fn.height(c.fLabel)) / 2, 0.78, 0.78, 0.78, a * k)
            end
        end
        local sq = math.max(3, math.floor(5 * u))
        local ly = (Fn.height(c.fValue) - Fn.height(c.fLabel)) / 2
        for _, r in ipairs(c.rows) do
            local k = SB.smooth((e - r.start) / T().LINE_DUR)
            if k > 0 then
                c:drawRect(x, y + r.ay + Fn.height(c.fValue) / 2 - sq / 2, sq, sq, a * k, OR, OG, OB)
                c:print(c.fLabel, r.label, x + math.floor(12 * u), y + r.ay + ly, OR, OG, OB, a * k)
                c:print(c.fValue, r.value, x + c.valueX, y + r.ay, 1, 1, 1, a * k)
                if r.sub then c:print(c.fLabel, r.sub, x + c.valueX, y + r.aySub, 0.75, 0.75, 0.75, a * k) end
            end
        end
        if c.motion and e > 0.15 and e < 1.1 then
            local k = (e - 0.15) / 0.95
            c:drawRect(bx + t, by + bh * k, bw - t, math.max(1, math.floor(2 * u)), a * 0.55 * (1 - k), OR, OG, OB)
        end
    end,
}

-- ---- Y2K -----------------------------------------------------------------------------------------
-- Icy frosted glass with a gloss and a silver rim, chrome lettering in a wide techno face, glossy
-- gel pills for the labels, sparkles. Silver, ice blue, lilac, a little pink.
local CHROME = { { 0, 0.42, 1, 1, 1 }, { 0.42, 0.5, 0.73, 0.78, 0.87 }, { 0.5, 0.57, 0.22, 0.26, 0.38 },
                 { 0.57, 0.72, 0.92, 0.96, 1 }, { 0.72, 1, 0.49, 0.71, 0.94 } }
local PILLS = { { 0.45, 0.72, 1 }, { 0.68, 0.58, 1 }, { 1, 0.55, 0.8 } }

SB.Looks.y2k = {
    layout = function(c)
        local Fn, u = F(), c.lu
        c.sub = (c.clock or "") .. ((c.clock and c.date) and "  -  " or "") .. (c.date or "")
        local all = allTexts(c, { c.sub })
        c.fBig = Fn.pick(all, Fn.make("sb_techno", c.px * 1.9), Fn.make("sb_chunky", c.px * 1.45), Fn.game("Large"))
        c.fPill = Fn.pick(all, Fn.make("sb_techno_s", c.px * 0.6), Fn.make("sb_chunky", c.px * 0.52), Fn.game("Small"))
        c.fValue = Fn.pick(all, Fn.make("sb_wide", c.px * 0.92), Fn.make("sb_chunky", c.px * 0.75), Fn.game("Medium"))
        local pad = math.floor(24 * u)
        c.pad = pad
        local bh, vh, ph = Fn.height(c.fBig), Fn.height(c.fValue), Fn.height(c.fPill)
        c.pillH = math.max(ph + math.floor(8 * u), vh)
        local pillW = 0
        for _, r in ipairs(c.rows) do pillW = math.max(pillW, Fn.width(c.fPill, r.label)) end
        c.pillW = pillW + math.floor(26 * u)
        -- the header placed by its capitals: the font's empty space above them would push it low
        local capTop, capH = Fn.capTop(c.fBig), Fn.capH(c.fBig)
        c.yBig = pad - capTop
        local y = pad + capH + math.floor(14 * u)
        if c.sub ~= "" then c.ySub = y; y = y + Fn.height(c.fPill) + math.floor(10 * u) end
        local w = math.max(Fn.width(c.fBig, c.header) + math.floor(60 * u), c.sub ~= "" and Fn.width(c.fPill, c.sub) or 0)
        for _, r in ipairs(c.rows) do
            r.py = y; y = y + c.pillH + math.floor(8 * u)
            local v = r.value .. (r.sub and ("  " .. r.sub) or "")
            r.pv = v
            w = math.max(w, c.pillW + math.floor(14 * u) + Fn.width(c.fValue, v))
        end
        c.yGloss = pad + capH + math.floor(8 * u)
        c.blockW, c.blockH = w + 2 * pad, y + pad - math.floor(8 * u)
        c.padX, c.padY = math.floor(8 * u), math.floor(8 * u)
        local starts = c:schedule(#c.rows, 0.6, 0.25)
        for i, r in ipairs(c.rows) do r.start = starts[i] end
    end,
    render = function(c, e, a)
        local Fn, u = F(), c.lu
        local x, y = c:placement()
        local pad, rad = c.pad, math.floor(24 * u)
        c:roundRect(x + 6 * u, y + 9 * u, c.blockW, c.blockH, rad, 0.08, 0.16, 0.35, a * 0.25)
        c:roundRect(x, y, c.blockW, c.blockH, rad, 0.8, 0.89, 0.97, a * 0.74, { 3 * u, 0.97, 0.99, 1, 0.95 })
        c:roundRect(x + 8 * u, y + 6 * u, c.blockW - 16 * u, c.yGloss, rad * 0.75, 1, 1, 1, a * 0.3)
        -- the chrome header drops in with motion on
        local drop = c.motion and (1 - SB.smooth(e / 0.35)) * 14 * u or 0
        local hx, hy = x + pad, y + c.yBig - drop
        c:print(c.fBig, c.header, hx + 4 * u, hy + 5 * u, 0.47, 0.43, 0.82, a * 0.6)
        local o = math.max(1, math.floor(2 * u))
        for ox = -o, o, o do
            for oy = -o, o, o do
                if ox ~= 0 or oy ~= 0 then Fn.draw(c, c.fBig, c.header, hx + ox, hy + oy, 0.1, 0.14, 0.31, a) end
            end
        end
        c:printBands(c.fBig, c.header, hx, hy, a, CHROME)
        local sp = getTexture(SB.TEX .. "sparkle.png")
        local bw = Fn.width(c.fBig, c.header)
        for i, s in ipairs({ { hx + bw + 10 * u, hy + 4 * u, 22 }, { hx - 6 * u, hy - 4 * u, 13 },
                             { hx + bw - 20 * u, hy + Fn.height(c.fBig) - 8 * u, 11 }, { x + c.blockW - pad, y + pad * 0.6, 16 } }) do
            local tw = 0.55 + 0.45 * math.abs(math.sin(e * 3 + i * 1.7))
            local sz = s[3] * u
            c:drawTextureScaled(sp, s[1] - sz / 2, s[2] - sz / 2, sz, sz, a * tw, 1, 1, 1)
        end
        if c.ySub then c:print(c.fPill, c.sub, x + pad + 4 * u, y + c.ySub, 0.16, 0.22, 0.43, a) end
        local ph = Fn.height(c.fPill)
        for i, r in ipairs(c.rows) do
            local k = SB.smooth((e - r.start) / T().LINE_DUR)
            if k > 0 then
                local col = PILLS[(i - 1) % #PILLS + 1]
                local px, py = x + pad, y + r.py
                c:roundRect(px, py, c.pillW, c.pillH, c.pillH / 2, col[1], col[2], col[3], a * k)
                c:roundRect(px + 5 * u, py + 3 * u, c.pillW - 10 * u, c.pillH * 0.38, c.pillH * 0.19, 1, 1, 1, a * k * 0.45)
                local lw = Fn.width(c.fPill, r.label)
                c:print(c.fPill, r.label, px + (c.pillW - lw) / 2, py + (c.pillH - ph) / 2, 1, 1, 1, a * k,
                    { shadow = { 1, 1, 0.7, 0.12, 0.2, 0.47 } })
                c:print(c.fValue, r.pv, px + c.pillW + 14 * u, py + (c.pillH - Fn.height(c.fValue)) / 2, 0.1, 0.15, 0.33, a * k)
            end
        end
    end,
}

-- ---- Hip-hop (90s rap) -----------------------------------------------------------------------------
-- Black and gold: the day in gold Old English lettering, the town sprayed as a tag with drips, a
-- gold chain, gold labels and white values, and our own "Survival Advisory" sticker slapped on.
local GOLD = { { 0, 0.35, 1, 0.96, 0.75 }, { 0.35, 0.55, 0.98, 0.8, 0.35 }, { 0.55, 0.7, 0.75, 0.51, 0.12 },
               { 0.7, 0.85, 1, 0.88, 0.51 }, { 0.85, 1, 0.63, 0.39, 0.08 } }

SB.Looks.hiphop = {
    layout = function(c)
        local Fn, u, info = F(), c.lu, c.info
        c.tag = SB.titleCase(info.place)
        local rows = {}
        for _, r in ipairs(c.rows) do
            if r.key ~= "Location" then table.insert(rows, { label = r.label, value = r.value }) end
        end
        if info.near then table.insert(rows, math.min(#rows + 1, 3), { label = SB.upper(c:L("Hip_Near")), value = SB.upper(info.near) }) end
        if c.clock or c.date then
            table.insert(rows, 1, { label = SB.upper(c:L("Hip_Time")), value = (c.clock or "") .. ((c.clock and c.date) and "  " or "") .. (c.date or "") })
        end
        local all = allTexts(c, { c.tag })
        for _, r in ipairs(rows) do table.insert(all, r.label); table.insert(all, r.value) end
        c.fGoth = Fn.pick({ c.dayText }, Fn.make("sb_gothic", c.px * 2.1), Fn.make("sb_cond_bold", c.px * 1.6), Fn.game("Large"))
        c.fTag = Fn.pick({ c.tag }, Fn.make("sb_marker", c.px * 1.25), Fn.make("sb_spray", c.px * 1.1), Fn.game("Large"))
        c.fValue = Fn.pick(all, Fn.make("sb_cond_bold", c.px * 0.92), Fn.game("Large"))
        c.fLabel = Fn.pick(all, Fn.make("sb_cond", c.px * 0.72), Fn.game("Medium"))
        local gh, th, vh = Fn.height(c.fGoth), Fn.height(c.fTag), Fn.height(c.fValue)
        local y = 0
        c.yGoth = y; y = y + gh
        if c.tag then c.yTag = y; y = y + th + math.floor(16 * u) end
        c.yChain = y; y = y + math.floor(22 * u)
        local labelW = 0
        for _, r in ipairs(rows) do labelW = math.max(labelW, Fn.width(c.fLabel, r.label)) end
        c.valueX = labelW + math.floor(16 * u)
        local w = math.max(Fn.width(c.fGoth, c.dayText) + math.floor(10 * u), c.tag and Fn.width(c.fTag, c.tag) or 0)
        for _, r in ipairs(rows) do
            r.y = y; y = y + vh + math.floor(2 * u)
            w = math.max(w, c.valueX + Fn.width(c.fValue, r.value))
        end
        c.hipRows = rows
        c.stickerW = math.floor(118 * u)
        c.stickerH = math.floor(c.stickerW * 152 / 254)
        c.textW = w
        c.blockW = w + math.floor(18 * u) + c.stickerW
        c.blockH = math.max(y, c.stickerH)
        c.padX, c.padY = math.floor(28 * u), math.floor(18 * u)
        local starts = c:schedule(#rows, 0.7)
        for i, r in ipairs(rows) do r.start = starts[i] end
        -- once every line is up: the sticker is the punchline, not part of the reveal
        c.stickerAt = (starts[#starts] or 0.7) + T().LINE_DUR + 0.9
    end,
    render = function(c, e, a)
        local Fn, u = F(), c.lu
        local x, y = c:placement()
        local tex = getTexture("media/textures/SurvivorBriefing_Fade.png")
        local bx = math.max(c:viewport(), x - c.padX)
        if tex then
            c:drawTextureScaled(tex, bx, y - c.padY, x - bx + c.blockW + c.padX * 4, c.blockH + c.padY * 2, a * 0.85, 0, 0, 0)
        end
        local o = math.max(1, math.floor(2 * u))
        Fn.draw(c, c.fGoth, c.dayText, x + 4 * u, y + c.yGoth + 4 * u, 0, 0, 0, a)
        for ox = -o, o, o do
            for oy = -o, o, o do
                if ox ~= 0 or oy ~= 0 then Fn.draw(c, c.fGoth, c.dayText, x + ox, y + c.yGoth + oy, 0, 0, 0, a) end
            end
        end
        c:printBands(c.fGoth, c.dayText, x, y + c.yGoth, a, GOLD)
        if c.yTag then
            local kt = SB.smooth((e - 0.35) / T().LINE_DUR)
            c:print(c.fTag, c.tag, x, y + c.yTag, 1, 1, 1, a * kt, { shadow = { 3, 3, 0.85 } })
            local tw = Fn.width(c.fTag, c.tag)
            local base = y + c.yTag + Fn.height(c.fTag) * 0.82
            for i = 1, 5 do
                local dx = x + tw * i / 6
                local len = (((i * 37 + #c.tag * 13) % 9) + 5) * u
                local dw = math.max(2, math.floor(2.5 * u))
                c:drawRect(dx, base, dw, len, a * kt * 0.9, 1, 1, 1)
                c:drawRect(dx - 1, base + len, dw + 2, dw + 1, a * kt * 0.9, 1, 1, 1)
            end
        end
        c:drawTextureTiledX(getTexture(SB.TEX .. "chain.png"), x, y + c.yChain, c.textW, 16, 1, 1, 1, a)
        local ly = (Fn.height(c.fValue) - Fn.height(c.fLabel)) / 2
        for _, r in ipairs(c.hipRows) do
            local k = SB.smooth((e - r.start) / T().LINE_DUR)
            if k > 0 then
                c:print(c.fLabel, r.label, x, y + r.y + ly, 0.92, 0.73, 0.24, a * k)
                c:print(c.fValue, r.value, x + c.valueX, y + r.y, 1, 1, 1, a * k, { shadow = { 2, 2, 0.9 } })
            end
        end
        if e >= c.stickerAt then
            local st = getTexture(SB.TEX .. "sticker_advisory.png")
            if st then
                -- slapped on: big for a moment, then down (a stamp landing, not movement)
                local s = 1 + 0.5 * (1 - SB.smooth((e - c.stickerAt) / 0.12))
                local ka = 1
                local cx = x + c.blockW - c.stickerW / 2
                local cy = y + c.blockH - c.stickerH / 2 - math.floor(6 * c.lu)
                c:drawTextureScaled(st, cx - c.stickerW * s / 2, cy - c.stickerH * s / 2, c.stickerW * s, c.stickerH * s, a * ka, 1, 1, 1)
            end
        end
    end,
}
