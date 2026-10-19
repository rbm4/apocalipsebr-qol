-- Looks that are a screen: Camcorder (VHS), Terminal, 16-bit RPG, Emergency Broadcast,
-- Cinematic and Military Briefing (Black Ops Cold War style). See Card.lua for what a look is.
SurvivorBriefing = SurvivorBriefing or {}
local SB = SurvivorBriefing
SB.Looks = SB.Looks or {}

local function F() return SB.Fonts end
local function T() return SB.Card.T end

-- All the texts a card of this look will draw, for the font glyph check.
local function texts(c, extra)
    local out = { c.header, c.clock, c.date }
    for _, r in ipairs(c.rows) do
        table.insert(out, r.label); table.insert(out, r.value)
        if r.sub then table.insert(out, r.sub) end
    end
    for _, s in ipairs(extra or {}) do table.insert(out, s) end
    return out
end

-- Fade in at start over dur; with motion on and typing asked for, the text types out instead.
local function reveal(c, e, start, dur)
    return SB.smooth((e - start) / dur)
end

-- ---- Camcorder (VHS) ----------------------------------------------------------------------------
-- A 1993 camcorder's on-screen display: white blocky text with a black edge, PLAY in the corner,
-- the date stamped in camcorder yellow, scanlines, and one line caught by a tracking glitch for
-- the first second.
local function monthAbbrev(c, m) return c:L("Mon" .. tostring(m)) end

SB.Looks.camcorder = {
    layout = function(c)
        local Fn, u, info = F(), c.lu, c.info
        c.play = c:L("Cam_Play")
        local stamp
        if info.month and info.dom then
            stamp = c:L("Cam_Stamp", monthAbbrev(c, info.month), string.format("%d", info.dom), string.format("%d", info.year))
        end
        local clock = (c.exactTime and c.clock) or "--:--"
        c.stamp = SB.upper((stamp and (stamp .. "  ") or "") .. clock)
        local all = texts(c, { c.play, c.stamp })
        local px = c.px * 1.15
        c.fBody = Fn.pick(all, Fn.make("sb_vcr", px), Fn.make("sb_mono", px * 0.82), Fn.game("Large"))
        c.fBig = Fn.pick(all, Fn.make("sb_vcr", px * 1.45), Fn.make("sb_mono", px * 1.2), Fn.game("Large"))
        local lh, hb = Fn.height(c.fBody), Fn.height(c.fBig)
        c.lines = {}
        local labelW = 0
        for _, r in ipairs(c.rows) do labelW = math.max(labelW, Fn.width(c.fBody, r.label)) end
        c.valueX = labelW + Fn.width(c.fBody, "  ")
        local w = 0
        local y = hb + math.floor(6 * u)
        for _, r in ipairs(c.rows) do
            local value = r.value .. (r.sub and ("  " .. r.sub) or "")
            table.insert(c.lines, { label = r.label, value = value, y = y })
            w = math.max(w, c.valueX + Fn.width(c.fBody, value))
            y = y + lh
        end
        c.yStamp = y + math.floor(lh * 0.5)
        c.tri = math.floor(hb * 0.6)
        c.dayX = c.tri + math.floor(8 * u) + Fn.width(c.fBig, c.play) + math.floor(36 * u)
        w = math.max(w, c.dayX + Fn.width(c.fBig, c.header), Fn.width(c.fBig, c.stamp))
        c.blockW, c.blockH = w, c.yStamp + hb
        c.padX, c.padY = math.floor(14 * u), math.floor(12 * u)
        c.starts = c:schedule(#c.lines + 1)
    end,
    render = function(c, e, a)
        local Fn, u = F(), c.lu
        local x, y = c:placement()
        local edge = { outline = { math.max(1, math.floor(u + 0.5)), 0, 0, 0, 0.9 } }
        local hb = Fn.height(c.fBig)
        c:drawTextureScaled(getTexture(SB.TEX .. "play.png"), x, y + (hb - c.tri) / 2, c.tri, c.tri, a, 1, 1, 1)
        c:print(c.fBig, c.play, x + c.tri + 8 * u, y, 0.96, 0.96, 0.96, a, edge)
        c:print(c.fBig, c.header, x + c.dayX, y, 0.96, 0.96, 0.96, a, edge)
        local glitchRow = math.min(3, #c.lines)
        local glitch = e > 0.4 and e < 1.5 and math.floor(e * 9) % 3 == 0
        for i, l in ipairs(c.lines) do
            local k = reveal(c, e, c.starts[i], T().LINE_DUR)
            if k > 0 then
                local dx = (glitch and i == glitchRow) and math.floor(3 * u) or 0
                if glitch and i == glitchRow then
                    for _, ghost in ipairs({ { 4, 1, 0.16, 0.16 }, { -4, 0.16, 1, 1 } }) do
                        c:print(c.fBody, l.label, x + ghost[1] * u, y + l.y, ghost[2], ghost[3], ghost[4], a * k * 0.55)
                        c:print(c.fBody, l.value, x + c.valueX + ghost[1] * u, y + l.y, ghost[2], ghost[3], ghost[4], a * k * 0.55)
                    end
                end
                c:print(c.fBody, l.label, x + dx, y + l.y, 0.96, 0.96, 0.96, a * k, edge)
                c:print(c.fBody, l.value, x + c.valueX + dx, y + l.y, 0.96, 0.96, 0.96, a * k, edge)
            end
        end
        local ks = reveal(c, e, c.starts[#c.lines + 1], T().LINE_DUR)
        c:print(c.fBig, c.stamp, x, y + c.yStamp, 1, 0.84, 0.28, a * ks, edge)
        c:drawTextureTiled(getTexture(SB.TEX .. "scanlines.png"), x - c.padX, y - c.padY,
            c.blockW + 2 * c.padX, c.blockH + 2 * c.padY, 1, 1, 1, a * 0.45)
    end,
}

-- ---- Terminal -----------------------------------------------------------------------------------
-- Green phosphor on black: the briefing printed line by line by a DOS program, dot leaders, a
-- blinking block cursor at the prompt.
SB.Looks.terminal = {
    layout = function(c)
        local Fn, u = F(), c.lu
        local lines = { { s = c:L("Term_Prompt"), dim = true }, { s = "" } }
        local function pair(label, value) table.insert(lines, { label = label, value = value }) end
        pair(SB.upper(c:L("Term_Day")), string.format("%d", c.day))
        if c.clock then pair(SB.upper(c:L("Term_Time")), c.clock) end
        if c.date then pair(SB.upper(c:L("Term_Date")), c.date) end
        for _, r in ipairs(c.rows) do
            pair(r.label, r.value)
            if r.sub then table.insert(lines, { label = "", value = r.sub, dim = true }) end
        end
        table.insert(lines, { s = "" })
        table.insert(lines, { s = c:L("Term_Ready"), dim = true, cursor = true })
        local n = 0
        for _, l in ipairs(lines) do if l.label then n = math.max(n, #l.label) end end
        for _, l in ipairs(lines) do
            if l.label then
                if l.label == "" then l.s = string.rep(" ", n + 2) .. l.value
                else l.s = l.label .. " " .. string.rep(".", n - #l.label + 1) .. " " .. l.value end
            end
        end
        local all = {}
        for _, l in ipairs(lines) do table.insert(all, l.s) end
        c.fMono = Fn.pick(all, Fn.make("sb_mono", c.px * 0.95), Fn.game("Medium"))
        local lh = math.floor(Fn.height(c.fMono) * 1.05)
        local w = 0
        for i, l in ipairs(lines) do
            l.y = (i - 1) * lh
            w = math.max(w, Fn.width(c.fMono, l.s) + (l.cursor and lh or 0))
        end
        c.lines, c.lh = lines, lh
        c.blockW, c.blockH = w, #lines * lh
        c.padX, c.padY = math.floor(16 * u), math.floor(14 * u)
        c.starts = c:schedule(#lines, 0.3, 0.13)
    end,
    render = function(c, e, a)
        local Fn = F()
        local x, y = c:placement()
        local bx, by, bw, bh = x - c.padX, y - c.padY, c.blockW + 2 * c.padX, c.blockH + 2 * c.padY
        c:drawRect(bx, by, bw, bh, a * 0.88, 0.016, 0.055, 0.024)
        c:drawRectBorder(bx, by, bw, bh, a * 0.8, 0.24, 0.67, 0.31)
        for i, l in ipairs(c.lines) do
            if e >= c.starts[i] and l.s ~= "" then
                local r, g, b = 0.43, 1, 0.55
                if l.dim then r, g, b = 0.24, 0.67, 0.31 end
                Fn.draw(c, c.fMono, l.s, x - 1, y + l.y, r, g, b, a * 0.25)
                Fn.draw(c, c.fMono, l.s, x + 1, y + l.y, r, g, b, a * 0.25)
                Fn.draw(c, c.fMono, l.s, x, y + l.y, r, g, b, a)
                if l.cursor and math.floor(e * 2) % 2 == 0 then
                    local cx = x + Fn.width(c.fMono, l.s) + 2
                    c:drawRect(cx, y + l.y + c.lh * 0.15, c.lh * 0.45, c.lh * 0.7, a, 0.43, 1, 0.55)
                end
            end
        end
        c:drawTextureTiled(getTexture(SB.TEX .. "scanlines.png"), bx, by, bw, bh, 1, 1, 1, a * 0.4)
    end,
}

-- ---- 16-bit RPG -------------------------------------------------------------------------------------
-- A blue gradient window with a white double border and a pixel font, like an old JRPG text
-- box. With motion on the text types out a letter at a time; a blinking arrow waits at the end.
local function pixelSize(px) return math.max(8, math.floor(px / 8 + 0.5) * 8) end

SB.Looks.rpg = {
    layout = function(c)
        local Fn, u = F(), c.lu
        local rows = {}
        for _, r in ipairs(c.rows) do
            table.insert(rows, { label = c:label("RPG", r), value = r.value .. (r.sub and (" " .. r.sub) or "") })
        end
        local stamp = c.clock and (c.clock .. (c.date and ("  " .. c.date) or "")) or c.date
        local all = texts(c, { stamp })
        for _, r in ipairs(rows) do table.insert(all, r.label); table.insert(all, r.value) end
        c.fText = Fn.pick(all, Fn.make("sb_pixel", pixelSize(c.px * 0.6)), Fn.game("Large"))
        c.fHead = Fn.pick(all, Fn.make("sb_pixel", pixelSize(c.px * 1.0)), Fn.game("Large"))
        local lh, hh = math.floor(Fn.height(c.fText) * 1.55), Fn.height(c.fHead)
        local labelW = 0
        for _, r in ipairs(rows) do labelW = math.max(labelW, Fn.width(c.fText, r.label)) end
        c.valueX = labelW + math.floor(18 * u)
        local w = Fn.width(c.fHead, c.header)
        c.stamp = stamp
        local y = hh + math.floor(10 * u)
        if stamp then
            c.yStamp = y; y = y + lh
            w = math.max(w, Fn.width(c.fText, stamp))
        end
        for _, r in ipairs(rows) do
            r.y = y; y = y + lh
            w = math.max(w, c.valueX + Fn.width(c.fText, r.value))
        end
        c.rpgRows = rows
        c.blockW, c.blockH = w + math.floor(20 * u), y + math.floor(6 * u)
        c.padX, c.padY = math.floor(20 * u), math.floor(18 * u)
        c.starts = c:schedule(#rows + 1, T().FIRST_LINE, c.motion and 0.55 or T().LINE_GAP)
    end,
    render = function(c, e, a)
        local Fn, u = F(), c.lu
        local x, y = c:placement()
        local bx, by, bw, bh = x - c.padX, y - c.padY, c.blockW + 2 * c.padX, c.blockH + 2 * c.padY
        local rad = math.floor(10 * u)
        c:roundRect(bx, by, bw, bh, rad, 0.12, 0.17, 0.55, a * 0.94, { 3 * u, 1, 1, 1, 1 })
        -- lighter at the top, behind the header only (a hard edge through the text looked broken)
        c:drawRect(bx + rad, by + 3 * u, bw - 2 * rad, c.padY + Fn.height(c.fHead) + 4 * u, a * 0.35, 0.33, 0.42, 0.95)
        c:roundRect(bx + 6 * u, by + 6 * u, bw - 12 * u, bh - 12 * u, rad * 0.6, 0, 0, 0, 0, { math.max(1, 1.5 * u), 0.67, 0.71, 0.9, 1 })
        local sh = { shadow = { math.max(1, math.floor(2 * u)), math.max(1, math.floor(2 * u)), 0.9, 0, 0, 0.15 } }
        c:print(c.fHead, c.header, x, y, 1, 1, 1, a, sh)
        local function show(s, start)
            if not c.motion then return s, SB.smooth((e - start) / T().LINE_DUR) end
            local k = (e - start) / math.max(0.2, #s / 32)
            if k <= 0 then return nil, 0 end
            return c:typed(s, k, false), 1
        end
        if c.stamp then
            local s, k = show(c.stamp, c.starts[1])
            if s and k > 0 then c:print(c.fText, s, x, y + c.yStamp, 1, 0.9, 0.47, a * k, sh) end
        end
        local done = true
        for i, r in ipairs(c.rpgRows) do
            local start = c.starts[i + 1]
            local s, k = show(r.label .. "\t" .. r.value, start)
            if s and k > 0 then
                local tab = s:find("\t", 1, true)
                local lab = tab and s:sub(1, tab - 1) or s
                local val = tab and s:sub(tab + 1) or nil
                c:print(c.fText, lab, x, y + r.y, 0.75, 0.79, 1, a * k, sh)
                if val then c:print(c.fText, val, x + c.valueX, y + r.y, 1, 1, 1, a * k, sh) end
            end
            if not s or (c.motion and s ~= r.label .. "\t" .. r.value) then done = false end
        end
        if done and math.floor(e * 2.5) % 2 == 0 then
            local s = math.floor(12 * u)
            c:drawTextureScaled(getTexture(SB.TEX .. "arrow_down.png"), bx + bw - 3 * s, by + bh - 2.2 * s, s, s, a, 1, 1, 1)
        end
    end,
}

-- ---- Emergency Broadcast ----------------------------------------------------------------------
-- A TV emergency alert. In a corner it is an alert box: a red header strip, the briefing on
-- black as bulletin rows, a grey strip whose public-safety message changes every few seconds
-- (changes, not scrolls: a crawl would stutter at the game's UI frame rate). In the centre
-- positions it is a full-width bar (under the clock at the top, over the hotbar at the bottom,
-- across the middle in the centre), its items split into pages that change the same way.
local MESSAGES = 4
local FULL = { Centre = true, TopCentre = true, BottomCentre = true }

local function ebsItems(c)
    local items = { c.header }
    for _, r in ipairs(c.rows) do
        local s = r.value
        if r.key == "Location" and r.sub then s = s .. ", " .. r.sub end
        if r.key == "Kills" or r.key == "BanditKills" or r.key == "Deaths" or r.key == "OutbreakDay" or r.key == "WorldDay" then
            s = r.label .. " " .. r.value
        end
        table.insert(items, s)
        if r.key == "Location" and (c.clock or c.date) then
            table.insert(items, (c.date or "") .. ((c.date and c.clock) and "  " or "") .. (c.clock or ""))
        end
    end
    return items
end

SB.Looks.broadcast = {
    layout = function(c)
        local Fn, u = F(), c.lu
        c.full = FULL[c.anchor] or false
        c.title, c.notTest = SB.upper(c:L("EBS_Title")), SB.upper(c:L("EBS_NotATest"))
        c.msgs = {}
        for i = 1, MESSAGES do c.msgs[i] = SB.upper(c:L("EBS_Msg" .. i)) end
        local rows = {}
        for _, r in ipairs(c.rows) do
            table.insert(rows, { label = c:label("EBS", r), value = r.value .. ((r.key == "Location" and r.sub) and (", " .. r.sub) or "") })
        end
        c.ebsRows = rows
        local all = texts(c, { c.title, c.notTest })
        for _, m in ipairs(c.msgs) do table.insert(all, m) end
        for _, r in ipairs(rows) do table.insert(all, r.label); table.insert(all, r.value) end
        c.fHead = Fn.pick(all, Fn.make("sb_cond_bold", c.px * 1.0), Fn.game("Large"))
        c.fBig = Fn.pick(all, Fn.make("sb_cond_bold", c.px * 1.7), Fn.game("Large"))
        c.fBody = Fn.pick(all, Fn.make("sb_cond", c.px * 0.95), Fn.game("Medium"))
        c.fSmall = Fn.pick(all, Fn.make("sb_cond_bold", c.px * 0.72), Fn.game("Medium"))
        local pad = math.floor(12 * u)
        c.pad = pad
        c.hHead = Fn.height(c.fHead) + math.floor(8 * u)
        c.hMsg = Fn.height(c.fSmall) + math.floor(12 * u)
        if c.full then
            -- one line of items under the header strip, in pages that fit the screen
            local _, _, vpW = c:viewport()
            local items, pages, cur, w = ebsItems(c), {}, {}, pad * 2
            local sep = math.floor(30 * u)
            for _, s in ipairs(items) do
                local iw = Fn.width(c.fBody, s) + sep
                if #cur > 0 and w + iw > vpW then table.insert(pages, cur); cur, w = {}, pad * 2 end
                table.insert(cur, s); w = w + iw
            end
            if #cur > 0 then table.insert(pages, cur) end
            c.pages, c.sep = pages, sep
            c.hLine = Fn.height(c.fBody) + math.floor(14 * u)
            c.blockW, c.blockH = vpW, c.hHead + c.hLine
            c.padX, c.padY = 0, 0
            c:schedule(1)
            return
        end
        local labelW = 0
        for _, r in ipairs(rows) do labelW = math.max(labelW, Fn.width(c.fSmall, r.label)) end
        c.valueX = pad + labelW + math.floor(14 * u)
        local stamp = (c.date or "") .. ((c.date and c.clock) and "   " or "") .. (c.clock or "")
        c.stampText = stamp ~= "" and stamp or nil
        local w = math.max(pad * 2 + Fn.width(c.fHead, c.title) + math.floor(30 * u) + Fn.width(c.fSmall, c.notTest),
            pad * 2 + Fn.width(c.fBig, c.header) + math.floor(16 * u) + Fn.width(c.fBody, stamp))
        for _, m in ipairs(c.msgs) do w = math.max(w, pad * 3 + Fn.width(c.fSmall, m) + math.floor(10 * u)) end
        local y = c.hHead + math.floor(4 * u)
        c.yBig = y
        y = y + Fn.height(c.fBig)
        local lh = Fn.height(c.fBody) + math.floor(2 * u)
        for _, r in ipairs(rows) do
            r.y = y; y = y + lh
            w = math.max(w, c.valueX + Fn.width(c.fBody, r.value) + pad)
        end
        c.yMsg = y + math.floor(8 * u)
        c.blockW, c.blockH = w, c.yMsg + c.hMsg
        c.padX, c.padY = math.floor(4 * u), math.floor(4 * u)
        c.starts = c:schedule(#rows + 1, 0.55)
    end,
    place = function(c)
        if not c.full then return nil end
        local vpL, vpT, _, vpH = c:viewport()
        local top, bottom = c:hudTopBottom()
        local gap = math.floor(10 * c.lu)
        if c.anchor == "TopCentre" then return vpL, top + gap end
        if c.anchor == "BottomCentre" then return vpL, bottom - gap - c.blockH end
        return vpL, vpT + math.floor(vpH * 0.42 - c.blockH / 2)
    end,
    render = function(c, e, a)
        local Fn, u = F(), c.lu
        local x, y = c:placement()
        local pad = c.pad
        -- the red strip cuts in first, the rest follows
        local kBody = SB.smooth((e - 0.25) / 0.35)
        c:drawRect(x, y, c.blockW, c.hHead, a * 0.96, 0.8, 0.09, 0.09)
        local hy = y + (c.hHead - Fn.height(c.fHead)) / 2
        c:print(c.fHead, c.title, x + pad, hy, 1, 1, 1, a)
        local ny = y + (c.hHead - Fn.height(c.fSmall)) / 2
        c:print(c.fSmall, c.notTest, x + c.blockW - pad - Fn.width(c.fSmall, c.notTest), ny, 1, 0.86, 0.86, a)
        if c.full then
            c:drawRect(x, y + c.hHead, c.blockW, c.hLine, a * 0.9 * kBody, 0.03, 0.03, 0.03)
            local page = c.pages[math.floor(e / 3.5) % #c.pages + 1] or {}
            local ix, iy = x + pad, y + c.hHead + (c.hLine - Fn.height(c.fBody)) / 2
            local sq = math.floor(8 * u)
            for _, s in ipairs(page) do
                c:drawRect(ix, iy + Fn.height(c.fBody) / 2 - sq / 2, sq, sq, a * kBody, 0.8, 0.09, 0.09)
                ix = ix + sq + math.floor(10 * u)
                c:print(c.fBody, s, ix, iy, 1, 1, 1, a * kBody)
                ix = ix + Fn.width(c.fBody, s) + c.sep - sq - math.floor(10 * u)
            end
            return
        end
        c:drawRect(x, y + c.hHead, c.blockW, c.yMsg - c.hHead, a * 0.9 * kBody, 0.03, 0.03, 0.03)
        local k0 = SB.smooth((e - c.starts[1]) / T().LINE_DUR)
        c:print(c.fBig, c.header, x + pad, y + c.yBig, 1, 1, 1, a * k0)
        if c.stampText then
            local sx = x + pad + Fn.width(c.fBig, c.header) + math.floor(16 * u)
            local sy = y + c.yBig + Fn.height(c.fBig) - Fn.height(c.fBody) - math.floor(4 * u)
            c:print(c.fBody, c.stampText, sx, sy, 0.84, 0.84, 0.84, a * k0)
        end
        local ly = (Fn.height(c.fBody) - Fn.height(c.fSmall)) / 2
        for i, r in ipairs(c.ebsRows) do
            local k = SB.smooth((e - c.starts[i + 1]) / T().LINE_DUR)
            if k > 0 then
                c:print(c.fSmall, r.label, x + pad, y + r.y + ly, 0.92, 0.27, 0.27, a * k)
                c:print(c.fBody, r.value, x + c.valueX, y + r.y, 1, 1, 1, a * k)
            end
        end
        c:drawRect(x, y + c.yMsg, c.blockW, c.hMsg, a * 0.92 * kBody, 0.16, 0.16, 0.16)
        local msg = c.msgs[math.floor(e / 2.5) % #c.msgs + 1]
        local my = y + c.yMsg + (c.hMsg - Fn.height(c.fSmall)) / 2
        local sq = math.floor(8 * u)
        c:drawRect(x + pad, y + c.yMsg + c.hMsg / 2 - sq / 2, sq, sq, a * kBody, 0.8, 0.09, 0.09)
        c:print(c.fSmall, msg, x + pad + sq + math.floor(10 * u), my, 1, 1, 1, a * kBody)
    end,
}

-- ---- Cinematic ------------------------------------------------------------------------------------
-- The whole screen: letterbox bars (sliding in with motion on, fading in without), the place as
-- a wide-spaced title in the middle, the date and day under it, the rest small in the bottom bar.
-- It ignores the position setting.
local function spacedWidth(Fn, f, s, sp)
    local w = 0
    for i = 1, #s do w = w + Fn.width(f, s:sub(i, i)) + sp end
    return w - sp
end

local function drawSpaced(c, f, s, x, y, sp, r, g, b, a)
    local Fn = F()
    for i = 1, #s do
        local ch = s:sub(i, i)
        if ch ~= " " then c:print(f, ch, x, y, r, g, b, a, { shadow = { 1, 2, 0.6 } }) end
        x = x + Fn.width(f, ch) + sp
    end
end

SB.Looks.cinematic = {
    layout = function(c)
        local Fn, u = F(), c.lu
        local place
        for _, r in ipairs(c.rows) do if r.key == "Location" then place = r.value end end
        c.title = place or c.header
        c.sub = c.date and (c.date .. "   -   " .. c.header) or c.header
        local bits = {}
        for _, r in ipairs(c.rows) do
            if r.key ~= "Location" then
                table.insert(bits, (r.key == "Name" or r.key == "Occupation" or r.key == "Weather") and r.value or (r.label .. " " .. r.value))
            end
        end
        if c.clock then table.insert(bits, 1, c.clock) end
        local all = { c.title, c.sub }
        for _, s in ipairs(bits) do table.insert(all, s) end
        c.fTitle = Fn.pick(all, Fn.make("sb_cond_light", c.px * 2.4), Fn.game("Intro"), Fn.game("Large"))
        c.fSub = Fn.pick(all, Fn.make("sb_cond", c.px * 0.9), Fn.game("Medium"))
        c.fLow = Fn.pick(all, Fn.make("sb_cond", c.px * 0.8), Fn.game("Medium"))
        local _, _, vpW, vpH = c:viewport()
        c.spT, c.spS = math.floor(9 * u), math.floor(4 * u)
        -- the third line, under the date: as many pieces as fit (not in the bottom bar, where the
        -- hotbar sits)
        local low, gap = "", "      "
        for _, s in ipairs(bits) do
            local try = low == "" and s or (low .. gap .. s)
            if spacedWidth(Fn, c.fLow, try, math.floor(2 * u)) > vpW * 0.8 then break end
            low = try
        end
        c.low = low
        c.blockW, c.blockH = vpW, vpH
        c.padX, c.padY = 0, 0
        c:schedule(3, 0.6, 0.4)
    end,
    place = function(c)
        local vpL, vpT = c:viewport()
        return vpL, vpT
    end,
    render = function(c, e, a)
        local Fn, u = F(), c.lu
        local x, y = c:placement()
        local w, h = c.blockW, c.blockH
        c:drawRect(x, y, w, h, a * 0.18, 0, 0, 0)
        local bar = math.floor(h * 0.11)
        local slide = c.motion and (1 - SB.smooth(e / 0.7)) * bar or 0
        local ba = c.motion and a or a * SB.smooth(e / 0.5)
        c:drawRect(x, y - slide, w, bar, ba, 0, 0, 0)
        c:drawRect(x, y + h - bar + slide, w, bar, ba, 0, 0, 0)
        local k1 = SB.smooth((e - 0.6) / 1.0)
        local tw = spacedWidth(Fn, c.fTitle, c.title, c.spT)
        drawSpaced(c, c.fTitle, c.title, x + (w - tw) / 2, y + h * 0.5 - Fn.height(c.fTitle), c.spT, 1, 1, 1, a * k1)
        local k2 = SB.smooth((e - 1.0) / 1.0)
        local sw = spacedWidth(Fn, c.fSub, c.sub, c.spS)
        drawSpaced(c, c.fSub, c.sub, x + (w - sw) / 2, y + h * 0.5 + math.floor(10 * u), c.spS, 0.88, 0.88, 0.88, a * k2)
        local k3 = SB.smooth((e - 1.4) / 1.0)
        if c.low ~= "" then
            local lw = spacedWidth(Fn, c.fLow, c.low, math.floor(2 * u))
            drawSpaced(c, c.fLow, c.low, x + (w - lw) / 2, y + h * 0.5 + math.floor(18 * u) + Fn.height(c.fSub),
                math.floor(2 * u), 0.78, 0.78, 0.78, a * k3)
        end
    end,
}

-- ---- Military Briefing (Black Ops Cold War style) --------------------------------------------
-- A condensed bold title on a dark band, the place and the day as an operation name; mixed-case
-- lines under it. With motion on, everything types out with a few scrambled characters at the
-- cursor; without, lines fade in. Just before the card fades, black bars snap over the codename
-- and surname and the coordinates. With "Only what your character can know" on, what the
-- character does not know (date, exact time, temperature) is a bar from the start.
local function latLon(x, y)
    -- A least-squares fit of real latitude/longitude to the game map, from the real towns on it
    -- (Muldraugh, West Point, Brandenburg, Ekron, Irvington, Louisville, Valley Station); within
    -- 2-8 km of the real places, plausible in between.
    local lat = 38.186807 + 0.000004276 * x - 0.000026292 * y
    local lon = 86.046836 - 0.000022465 * x + 0.000019921 * y
    return string.format("%.4f", lat), string.format("%.4f", lon)
end
SB.latLon = latLon

local REDACT_FILL = "XXXXXXXX"

SB.Looks.military = {
    layout = function(c)
        local Fn, u, info = F(), c.lu, c.info
        local know = info.know or { time = true, date = true, temperature = true }
        local realistic = info.realistic
        local place, near = info.place, info.near
        local title = SB.upper(((near and (near .. ", ")) or "") .. (place or "")) .. ', "' .. c.header .. '"'
        if not place then title = c.header end
        local lines = {}
        local function add(s, endBars, startBars)
            table.insert(lines, { s = s, endBars = endBars or {}, startBars = startBars or {} })
        end
        if info.first or info.last then
            local first, last, occ = info.first or "", info.last or "", info.occupation
            local s = occ and c:L("Mil_Subject", first, occ, last) or c:L("Mil_SubjectNoCode", first, last)
            local hide = occ and ('"' .. occ .. '" ' .. last) or last
            add(s, { hide })
        end
        if info.x and info.y and place then
            local lat, lon = latLon(info.x, info.y)
            place = SB.titleCase(place)
            local s = c:L("Mil_Coords", lat, lon, place)
            local i = s:find(lat, 1, true)
            local j = s:find(lon, 1, true)
            local k = s:find(place, 1, true)
            local hide
            if i and j then
                local stop = (k and k > j) and (k - 3) or (j + #lon - 1)
                hide = s:sub(i, math.max(i, stop))
            end
            add(s, { hide })
        end
        if SB.opt("showTime") or SB.opt("showDate") then
            local datePart = info.date or (realistic and REDACT_FILL .. " XX, XXXX") or nil
            local timePart = (info.exactTime and info.clock) or (realistic and "XX:XX") or info.clock
            local s = (datePart or "") .. ((datePart and timePart) and ", " or "") .. (timePart or "")
            if s ~= "" then
                local starts = {}
                if realistic and not info.date and datePart then table.insert(starts, datePart) end
                if realistic and not info.exactTime and timePart then table.insert(starts, timePart) end
                add(s, {}, starts)
            end
        end
        if info.weather then
            if realistic and not know.temperature then add(info.weather .. ", XX\176", {}, { "XX\176" })
            else add(info.weather) end
        end
        if info.kills then add(c:L("Mil_Kills", info.kills)) end
        if info.banditKills then add(c:L("Mil_Bandits", info.banditKills)) end
        if info.deaths then add(c:L("Mil_Deaths", info.deaths)) end
        if info.outbreakDay then add(c:L("Mil_Outbreak", info.outbreakDay)) end
        if info.worldDayLabel then add(info.worldDayLabel .. " " .. info.worldDay) end

        local all = { title }
        for _, l in ipairs(lines) do table.insert(all, l.s) end
        c.fTitle = Fn.pick(all, Fn.make("sb_cond_bold", c.px * 1.45), Fn.game("Large"))
        c.fLine = Fn.pick(all, Fn.make("sb_cond", c.px * 0.95), Fn.game("Large"))
        local th, lh = Fn.height(c.fTitle), Fn.height(c.fLine) + math.floor(2 * u)
        c.title, c.milLines, c.lh = title, lines, lh
        local w = Fn.width(c.fTitle, title) + math.floor(24 * u)
        local y = th + math.floor(12 * u)
        for _, l in ipairs(lines) do
            l.y = y; y = y + lh
            w = math.max(w, Fn.width(c.fLine, l.s) + math.floor(16 * u))
            -- where each bar goes, in pixels from the line's start
            l.bars = {}
            for _, part in ipairs(l.endBars) do
                local i = part and l.s:find(part, 1, true)
                if i then table.insert(l.bars, { x = Fn.width(c.fLine, l.s:sub(1, i - 1)), w = Fn.width(c.fLine, part), i = i, j = i + #part - 1 }) end
            end
            l.now = {}
            for _, part in ipairs(l.startBars) do
                local i = l.s:find(part, 1, true)
                if i then table.insert(l.now, { x = Fn.width(c.fLine, l.s:sub(1, i - 1)), w = Fn.width(c.fLine, part), i = i, j = i + #part - 1 }) end
            end
        end
        c.blockW, c.blockH = w, y
        c.padX, c.padY = math.floor(16 * u), math.floor(12 * u)
        -- typing takes longer than fading, so the lines are further apart with motion on
        c.starts = c:schedule(#lines, c.motion and 0.9 or T().FIRST_LINE, c.motion and 0.6 or T().LINE_GAP, c.motion and 0.4 or 0)
    end,
    render = function(c, e, a)
        local Fn, u = F(), c.lu
        local x, y = c:placement()
        local th = Fn.height(c.fTitle)
        local sh = { shadow = { 1, 2, 0.8 } }
        local function typedText(s, start)
            if not c.motion then return s, SB.smooth((e - start) / T().LINE_DUR), true end
            local k = (e - start) / math.max(0.25, #s / 55)
            if k <= 0 then return nil, 0, false end
            local out, done = c:typed(s, k, true)
            return out, 1, done
        end
        local ts, tk = typedText(c.title, 0.1)
        if ts then
            local bandW = Fn.width(c.fTitle, c.title) + math.floor(24 * u)
            c:drawRect(x - math.floor(12 * u), y - math.floor(2 * u), bandW, th + math.floor(4 * u), a * 0.62 * math.max(tk, c.motion and 1 or 0), 0.04, 0.05, 0.06)
            c:print(c.fTitle, ts, x, y, 1, 1, 1, a * tk, sh)
        end
        local redactAt = c:fadeOutAt() - 1.5
        local barN = 0
        for i, l in ipairs(c.milLines) do
            local s, k, done = typedText(l.s, c.starts[i])
            -- how far each bar is across: what the character does not know is struck out as soon
            -- as the line is written, the rest just before the card fades
            local written = c.motion and (c.starts[i] + math.max(0.25, #l.s / 55)) or (c.starts[i] + T().LINE_DUR * 0.5)
            local bars, skips = {}, {}
            for j, b in ipairs(l.now) do
                local kb = done and c:wipe(e, written + (j - 1) * 0.15) or 0
                table.insert(bars, { b = b, k = kb, a = k })
                if kb >= 1 then table.insert(skips, { b.i, b.j }) end
            end
            for _, b in ipairs(l.bars) do
                barN = barN + 1
                local kb = c:wipe(e, redactAt + (barN - 1) * SB.Card.WIPE_GAP)
                table.insert(bars, { b = b, k = kb, a = 1 })
                if kb >= 1 then table.insert(skips, { b.i, b.j }) end
            end
            if s and k > 0 then
                local lw = Fn.width(c.fLine, s)
                c:drawRect(x - math.floor(8 * u), y + l.y + math.floor(2 * u), lw + math.floor(16 * u), c.lh - math.floor(3 * u), a * 0.32 * k, 0.04, 0.05, 0.06)
                c:printSkipping(c.fLine, s, x, y + l.y, 0.95, 0.95, 0.95, a * k, sh, done and skips or nil)
                if not done then
                    c:drawRect(x + lw + 3, y + l.y + c.lh * 0.18, c.lh * 0.4, c.lh * 0.62, a, 1, 1, 1)
                end
            end
            for _, bk in ipairs(bars) do
                c:redact(x + bk.b.x, y + l.y, bk.b.w, c.lh, a * bk.a, bk.k, c.fLine)
            end
        end
    end,
}
