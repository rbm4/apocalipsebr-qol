-- Looks on paper: Survivor's Journal, Case File, Quarantine Notice, Newspaper. See Card.lua.
SurvivorBriefing = SurvivorBriefing or {}
local SB = SurvivorBriefing
SB.Looks = SB.Looks or {}

local function F() return SB.Fonts end
local function T() return SB.Card.T end

local function shadowBox(c, x, y, w, h, a)
    c:drawRect(x + 6 * c.lu, y + 8 * c.lu, w, h, a * 0.22, 0, 0, 0)
end

-- Greedy word wrap to a width.
local function wrap(Fn, f, text, width)
    local lines, cur = {}, ""
    for word in text:gmatch("%S+") do
        local try = cur == "" and word or (cur .. " " .. word)
        if cur ~= "" and Fn.width(f, try) > width then
            table.insert(lines, cur)
            cur = word
        else
            cur = try
        end
    end
    if cur ~= "" then table.insert(lines, cur) end
    return lines
end

-- ---- Survivor's Journal ------------------------------------------------------------------------
-- A torn notebook page, handwritten as a diary entry, each line inked in after the last.
SB.Looks.journal = {
    layout = function(c)
        local Fn, u, info = F(), c.lu, c.info
        local lines = { c.dayText }
        local when = info.date or ""
        if info.clock then when = when .. (when ~= "" and ", " or "") .. info.clock end
        if when ~= "" then table.insert(lines, when .. ".") end
        if info.place then
            local place = SB.titleCase(info.place)
            table.insert(lines, info.near and c:L("J_PlaceNear", place, info.near) or c:L("J_Place", place))
        end
        if info.weather then table.insert(lines, c:L("J_Weather", info.weather)) end
        if info.kills then table.insert(lines, c:L("J_Kills", info.kills)) end
        if info.banditKills then table.insert(lines, c:L("J_Bandits", info.banditKills)) end
        if info.deaths then table.insert(lines, c:L("J_Deaths", info.deaths)) end
        if info.outbreakDay then table.insert(lines, c:L("J_Outbreak", info.outbreakDay)) end
        if info.worldDayLabel then table.insert(lines, info.worldDayLabel .. ": " .. info.worldDay .. ".") end
        if info.name then
            table.insert(lines, info.occupation and c:L("J_Sign", info.name, info.occupation) or c:L("J_SignName", info.name))
        end
        local zoom = SB.clamp(c.px * 1.15 / 40, 0.7, 2.2)
        c.fHand = Fn.pick(lines, Fn.game("Handwritten", zoom), Fn.game("Large"))
        local lh = math.floor(Fn.height(c.fHand) * 0.92)
        c.margin = math.floor(lh * 1.4)
        local w = 0
        for _, s in ipairs(lines) do w = math.max(w, Fn.width(c.fHand, s)) end
        c.jLines, c.lh = lines, lh
        c.edge = math.floor(10 * u)
        c.blockW = c.margin + w + math.floor(22 * u)
        c.blockH = c.edge + math.floor(10 * u) + (#lines + 1) * lh
        c.padX, c.padY = math.floor(10 * u), math.floor(10 * u)
        c.starts = c:schedule(#lines, 0.35, 0.32)
    end,
    render = function(c, e, a)
        local Fn, u = F(), c.lu
        local x, y = c:placement()
        local pr, pg, pb = 0.95, 0.93, 0.86
        local top = y + c.edge
        shadowBox(c, x, top, c.blockW, c.blockH - c.edge, a)
        c:drawRect(x, top, c.blockW, c.blockH - c.edge, a * 0.95, pr, pg, pb)
        c:drawTextureTiledX(getTexture(SB.TEX .. "torn_edge.png"), x, y, c.blockW, c.edge + 1, pr, pg, pb, a * 0.95)
        local first = top + math.floor(10 * u)
        for i = 1, #c.jLines + 1 do
            c:drawRect(x + 4, first + i * c.lh - 2, c.blockW - 8, 1, a * 0.45, 0.47, 0.59, 0.78)
        end
        c:drawRect(x + c.margin - math.floor(10 * u), top, math.max(1, math.floor(1.5 * u)), c.blockH - c.edge, a * 0.55, 0.78, 0.31, 0.31)
        for i, s in ipairs(c.jLines) do
            local k = SB.smooth((e - c.starts[i]) / T().LINE_DUR)
            if k > 0 then
                Fn.draw(c, c.fHand, s, x + c.margin, first + (i - 1) * c.lh + c.lh - Fn.height(c.fHand) + 2, 0.12, 0.18, 0.43, a * k)
            end
        end
    end,
}

-- ---- Case File ---------------------------------------------------------------------------------
-- A typed dossier on beige paper, classification banners top and bottom. Just before it fades,
-- the surname, the landmark and the source get black bars and a REDACTED stamp lands on it.
local function dots(label, n) return label .. " " .. string.rep(".", math.max(1, n - #label)) .. " " end

SB.Looks.casefile = {
    layout = function(c)
        local Fn, u, info = F(), c.lu, c.info
        local know = info.know or { time = true, date = true }
        local rows = {}
        local function add(labelKey, value, endHide, startHide)
            table.insert(rows, { label = SB.upper(c:L(labelKey)), value = SB.upper(value), endHide = endHide and SB.upper(endHide),
                startHide = startHide and SB.upper(startHide) })
        end
        if info.first or info.last then
            add("Case_Subject", (info.last or "") .. ((info.last and info.first) and ", " or "") .. (info.first or ""), info.last)
        end
        if info.occupation then add("Case_Occupation", info.occupation) end
        if info.month and info.dom and info.exactTime and info.hour then
            add("Case_DTG", string.format("%02d%02d%02d ", info.dom, info.hour, info.min or 0) .. c:L("Mon" .. info.month)
                .. string.format(" %02d", (info.year or 1993) % 100))
        elseif info.realistic then
            add("Case_DTG", "XXXXXX XXX XX", nil, "XXXXXX XXX XX")
        end
        if info.place then add("Case_Location", info.place) end
        if info.x and info.y then
            local grid = string.format("%d-%d", math.floor(info.x), math.floor(info.y))
            add("Case_Grid", grid .. (info.near and ("  " .. info.near) or ""), info.near)
        end
        if info.weather then add("Case_Weather", info.weather) end
        if info.kills then add("Case_Kills", info.kills) end
        for _, r in ipairs(c.rows) do
            if r.key == "BanditKills" or r.key == "Deaths" or r.key == "OutbreakDay" or r.key == "WorldDay" then
                table.insert(rows, { label = r.label, value = r.value })
            end
        end
        local source = c:L("Case_Source" .. tostring(c.day % 3 + 1))
        add("Case_SourceLabel", source, source)
        local n = 0
        for _, r in ipairs(rows) do n = math.max(n, #r.label) end
        for _, r in ipairs(rows) do r.lead = dots(r.label, n + 1) end
        c.banner, c.titleText = SB.upper(c:L("Case_Banner")), SB.upper(c:L("Case_Title"))
        local all = { c.banner, c.titleText, c.header }
        for _, r in ipairs(rows) do table.insert(all, r.lead .. r.value) end
        c.fHead = Fn.pick(all, Fn.make("sb_stencil", c.px * 1.3), Fn.make("sb_cond_bold", c.px * 1.25), Fn.game("Large"))
        c.fBody = Fn.pick(all, Fn.make("sb_typewriter", c.px * 0.95), Fn.make("sb_mono", c.px * 0.85), Fn.game("Medium"))
        c.fBanner = Fn.pick(all, Fn.make("sb_stencil", c.px * 0.72), Fn.make("sb_cond_bold", c.px * 0.72), Fn.game("Small"))
        local lh, hh, bh = Fn.height(c.fBody), Fn.height(c.fHead), Fn.height(c.fBanner)
        local pad = math.floor(18 * u)
        c.pad = pad
        local y = pad + bh + math.floor(6 * u)
        c.yTitle = y; y = y + hh
        c.yDay = y; y = y + hh + math.floor(8 * u)
        local leadW = 0
        for _, r in ipairs(rows) do leadW = math.max(leadW, Fn.width(c.fBody, r.lead)) end
        local w = math.max(Fn.width(c.fHead, c.titleText), Fn.width(c.fBanner, c.banner))
        for _, r in ipairs(rows) do
            r.y = y; y = y + lh
            w = math.max(w, leadW + Fn.width(c.fBody, r.value))
            r.bars = {}
            for _, which in ipairs({ "endHide", "startHide" }) do
                local part = r[which]
                local i = part and r.value:find(part, 1, true)
                if i then
                    table.insert(r.bars, { at = which, x = leadW + Fn.width(c.fBody, r.value:sub(1, i - 1)), w = Fn.width(c.fBody, part),
                        i = i, j = i + #part - 1 })
                end
            end
        end
        c.leadW, c.lh = leadW, lh
        c.caseRows = rows
        c.yBottom = y + math.floor(8 * u)
        c.blockW, c.blockH = w + 2 * pad, c.yBottom + bh + pad
        c.padX, c.padY = math.floor(8 * u), math.floor(8 * u)
        c.starts = c:schedule(#rows, 0.7, 0.22)
    end,
    render = function(c, e, a)
        local Fn, u = F(), c.lu
        local x, y = c:placement()
        local pad = c.pad
        shadowBox(c, x, y, c.blockW, c.blockH, a)
        c:drawRect(x, y, c.blockW, c.blockH, a * 0.94, 0.93, 0.89, 0.80)
        c:drawTextureTiled(getTexture(SB.TEX .. "grain.png"), x, y, c.blockW, c.blockH, 1, 1, 1, a * 0.35)
        local bw = Fn.width(c.fBanner, c.banner)
        c:print(c.fBanner, c.banner, x + (c.blockW - bw) / 2, y + pad * 0.5, 0.75, 0.1, 0.1, a)
        c:print(c.fBanner, c.banner, x + (c.blockW - bw) / 2, y + c.yBottom, 0.75, 0.1, 0.1, a)
        local k = SB.smooth((e - 0.2) / T().LINE_DUR)
        c:print(c.fHead, c.titleText, x + pad, y + c.yTitle, 0.14, 0.13, 0.12, a * k)
        c:print(c.fHead, c.header, x + pad, y + c.yDay, 0.75, 0.1, 0.1, a * k)
        local redactAt = c:fadeOutAt() - 1.8
        local n = 0
        for i, r in ipairs(c.caseRows) do
            local kr = SB.smooth((e - c.starts[i]) / T().LINE_DUR)
            -- how far each bar is across; unknown to the character: struck out right after the line
            -- is typed; the rest just before the card fades
            local bars, skips = {}, {}
            for _, b in ipairs(r.bars) do
                local kb, ab
                if b.at == "endHide" then
                    n = n + 1
                    kb, ab = c:wipe(e, redactAt + (n - 1) * SB.Card.WIPE_GAP), 1
                else
                    kb, ab = (kr > 0) and c:wipe(e, c.starts[i] + T().LINE_DUR * 0.5) or 0, kr
                end
                table.insert(bars, { b = b, k = kb, a = ab })
                if kb >= 1 then table.insert(skips, { b.i, b.j }) end
            end
            if kr > 0 then
                c:print(c.fBody, r.lead, x + pad, y + r.y, 0.14, 0.13, 0.12, a * kr)
                c:printSkipping(c.fBody, r.value, x + pad + c.leadW, y + r.y, 0.14, 0.13, 0.12, a * kr, nil, skips)
            end
            for _, bk in ipairs(bars) do
                c:redact(x + pad + bk.b.x, y + r.y, bk.b.w, c.lh, a * bk.a, bk.k, c.fBody)
            end
        end
        -- the stamp comes down once the last bar is across
        local stampAt = redactAt + math.max(0, n - 1) * SB.Card.WIPE_GAP + SB.Card.WIPE + 0.15
        if e >= stampAt then
            local tex = getTexture(SB.TEX .. "stamp_redacted.png")
            if tex then
                local sw = math.min(c.blockW * 0.55, 190 * u)
                local shh = sw * 140 / 312
                local s = 1 + 0.45 * (1 - SB.smooth((e - stampAt) / 0.12))
                local cx, cy = x + c.blockW - pad - sw / 2, y + c.blockH - pad - shh / 2 - c.lh
                c:drawTextureScaled(tex, cx - sw * s / 2, cy - shh * s / 2, sw * s, shh * s, a * 0.9, 1, 1, 1)
            end
        end
    end,
}

-- ---- Quarantine Notice ---------------------------------------------------------------------------
-- A government notice: hazard stripes top and bottom, a yellow band with the biohazard sign and
-- "KNOX COUNTY EXCLUSION ZONE", the day of quarantine in big letters, the rest as notice fields.
SB.Looks.quarantine = {
    layout = function(c)
        local Fn, u = F(), c.lu
        local rows = {}
        if c.clock or c.date then
            table.insert(rows, { label = SB.upper(c:L("Q_Time")), value = (c.clock or "") .. ((c.clock and c.date) and "  " or "") .. (c.date or "") })
        end
        for _, r in ipairs(c.rows) do
            table.insert(rows, { label = c:label("Q", r), value = r.value .. (r.sub and (", " .. r.sub) or "") })
        end
        c.h1, c.h2 = SB.upper(c:L("Q_Header1")), SB.upper(c:L("Q_Header2"))
        c.big = SB.upper(c:L("Q_Day", string.format("%d", c.day)))
        local all = { c.h1, c.h2, c.big }
        for _, r in ipairs(rows) do table.insert(all, r.label); table.insert(all, r.value) end
        c.fBig = Fn.pick(all, Fn.make("sb_cond_bold", c.px * 1.35), Fn.game("Large"))
        c.fHead = Fn.pick(all, Fn.make("sb_cond_bold", c.px * 0.98), Fn.game("Large"))
        c.fBody = Fn.pick(all, Fn.make("sb_cond", c.px * 0.85), Fn.game("Medium"))
        local pad = math.floor(16 * u)
        c.pad, c.stripe = pad, math.floor(11 * u)
        c.band = Fn.height(c.fHead) + math.floor(12 * u)
        local icon = c.band - math.floor(8 * u)
        c.icon = icon
        local labelW = 0
        for _, r in ipairs(rows) do labelW = math.max(labelW, Fn.width(c.fBody, r.label)) end
        c.valueX = pad + labelW + math.floor(18 * u)
        local w = math.max(pad * 2 + icon + math.floor(10 * u) + Fn.width(c.fHead, c.h1 .. " " .. c.h2), pad * 2 + Fn.width(c.fBig, c.big))
        local y = c.stripe + c.band + math.floor(8 * u)
        c.yBig = y; y = y + Fn.height(c.fBig) + math.floor(4 * u)
        local lh = Fn.height(c.fBody) + math.floor(3 * u)
        for _, r in ipairs(rows) do
            r.y = y; y = y + lh
            w = math.max(w, c.valueX + Fn.width(c.fBody, r.value) + pad)
        end
        c.qRows = rows
        c.blockW, c.blockH = w, y + math.floor(8 * u) + c.stripe
        c.padX, c.padY = math.floor(8 * u), math.floor(8 * u)
        c.starts = c:schedule(#rows, 0.6, 0.22)
    end,
    render = function(c, e, a)
        local Fn, u = F(), c.lu
        local x, y = c:placement()
        local pad = c.pad
        shadowBox(c, x, y, c.blockW, c.blockH, a)
        c:drawRect(x, y, c.blockW, c.blockH, a * 0.95, 0.93, 0.91, 0.84)
        local stripe = getTexture(SB.TEX .. "hazard_stripe.png")
        c:drawTextureTiledX(stripe, x, y, c.blockW, c.stripe, 1, 1, 1, a)
        c:drawTextureTiledX(stripe, x, y + c.blockH - c.stripe, c.blockW, c.stripe, 1, 1, 1, a)
        c:drawRect(x, y + c.stripe, c.blockW, c.band, a, 0.98, 0.8, 0.08)
        c:drawTextureScaled(getTexture(SB.TEX .. "biohazard.png"), x + pad, y + c.stripe + (c.band - c.icon) / 2, c.icon, c.icon, a, 0.08, 0.08, 0.08)
        local hx = x + pad + c.icon + math.floor(10 * u)
        local hy = y + c.stripe + (c.band - Fn.height(c.fHead)) / 2
        c:print(c.fHead, c.h1, hx, hy, 0.08, 0.08, 0.08, a)
        c:print(c.fHead, c.h2, hx + Fn.width(c.fHead, c.h1 .. " "), hy, 0.7, 0.08, 0.08, a)
        local k = SB.smooth((e - 0.3) / T().LINE_DUR)
        c:print(c.fBig, c.big, x + pad, y + c.yBig, 0.08, 0.08, 0.08, a * k)
        for i, r in ipairs(c.qRows) do
            local kr = SB.smooth((e - c.starts[i]) / T().LINE_DUR)
            if kr > 0 then
                c:print(c.fBody, r.label, x + pad, y + r.y, 0.5, 0.12, 0.12, a * kr)
                c:print(c.fBody, r.value, x + c.valueX, y + r.y, 0.1, 0.1, 0.1, a * kr)
            end
        end
    end,
}

-- ---- Newspaper -----------------------------------------------------------------------------------
-- A clipping: a blackletter masthead, the dateline, a headline, and the briefing written up as a
-- short news item in two columns.
SB.Looks.newspaper = {
    layout = function(c)
        local Fn, u, info = F(), c.lu, c.info
        local parts = {}
        if info.name then
            local place = SB.titleCase(info.place)
            table.insert(parts, place and (info.occupation and c:L("N_Seen", info.name, info.occupation, place)
                or c:L("N_SeenNoJob", info.name, place)) or c:L("N_Alive", info.name))
        end
        if info.near then table.insert(parts, c:L("N_Near", info.near)) end
        local when = (info.date or "") .. ((info.date and info.clock) and ", " or "") .. (info.clock or "")
        if when ~= "" then table.insert(parts, c:L("N_Time", when)) end
        if info.weather then table.insert(parts, c:L("N_Weather", info.weather)) end
        if info.kills then table.insert(parts, c:L("N_Kills", info.kills)) end
        if info.banditKills then table.insert(parts, c:L("N_Bandits", info.banditKills)) end
        if info.deaths then table.insert(parts, c:L("N_Deaths", info.deaths)) end
        if info.outbreakDay then table.insert(parts, c:L("N_Outbreak", info.outbreakDay)) end
        table.insert(parts, c:L("N_End"))
        local body = table.concat(parts, " ")
        c.mast = c:L("N_Masthead")
        c.dateline = c.date or ""
        c.edition = SB.upper(c:L("N_Edition"))
        c.head1 = SB.upper(c:L("N_Headline", string.format("%d", c.day)))
        c.head2 = info.place and SB.upper(info.place) or nil
        local zoom = SB.clamp(c.px * 1.05 / 37, 0.6, 2.4)
        c.fMast = Fn.pick({ c.mast }, Fn.make("sb_gothic", c.px * 1.7), Fn.game("Intro", zoom))
        c.fHead = Fn.pick({ c.head1, c.head2 }, Fn.game("Intro", zoom), Fn.game("Large"))
        c.fSmall = Fn.game(c.textSize >= 2 and "Medium" or "Small")
        local pad = math.floor(14 * u)
        c.pad = pad
        local pw = math.floor(300 * u)
        pw = math.max(pw, Fn.width(c.fMast, c.mast) + 2 * pad, Fn.width(c.fHead, c.head1) + 2 * pad)
        local colW = math.floor((pw - 3 * pad) / 2)
        local lines = wrap(Fn, c.fSmall, body, colW)
        local half = math.ceil(#lines / 2)
        c.cols = { {}, {} }
        for i, l in ipairs(lines) do table.insert(c.cols[i <= half and 1 or 2], l) end
        c.colW = colW
        local y = math.floor(6 * u)
        c.yMast = y; y = y + Fn.height(c.fMast)
        c.yRule1 = y; y = y + math.floor(4 * u)
        c.yDate = y; y = y + Fn.height(c.fSmall)
        c.yRule2 = y; y = y + math.floor(8 * u)
        c.yHead1 = y; y = y + Fn.height(c.fHead)
        if c.head2 then c.yHead2 = y; y = y + Fn.height(c.fHead) end
        c.yBody = y + math.floor(8 * u)
        c.lhBody = Fn.height(c.fSmall)
        c.blockW, c.blockH = pw, c.yBody + half * c.lhBody + math.floor(14 * u)
        c.padX, c.padY = math.floor(8 * u), math.floor(8 * u)
        c:schedule(3, 0.5, 0.35)
    end,
    render = function(c, e, a)
        local Fn, u = F(), c.lu
        local x, y = c:placement()
        local pad = c.pad
        local ink = 0.1
        shadowBox(c, x, y, c.blockW, c.blockH, a)
        c:drawRect(x, y, c.blockW, c.blockH - math.floor(6 * u), a * 0.96, 0.89, 0.87, 0.82)
        c:drawTextureTiledX(getTexture(SB.TEX .. "zigzag.png"), x, y + c.blockH - math.floor(6 * u), c.blockW, math.floor(6 * u), 0.89, 0.87, 0.82, a * 0.96)
        c:drawTextureTiled(getTexture(SB.TEX .. "grain.png"), x, y, c.blockW, c.blockH - math.floor(6 * u), 1, 1, 1, a * 0.3)
        local mw = Fn.width(c.fMast, c.mast)
        c:print(c.fMast, c.mast, x + (c.blockW - mw) / 2, y + c.yMast, ink, ink, ink, a)
        c:drawRect(x + pad, y + c.yRule1, c.blockW - 2 * pad, math.max(1, math.floor(2 * u)), a, ink, ink, ink)
        c:print(c.fSmall, c.dateline, x + pad, y + c.yDate, ink, ink, ink, a)
        c:print(c.fSmall, c.edition, x + c.blockW - pad - Fn.width(c.fSmall, c.edition), y + c.yDate, ink, ink, ink, a)
        c:drawRect(x + pad, y + c.yRule2, c.blockW - 2 * pad, 1, a, ink, ink, ink)
        local k1 = SB.smooth((e - 0.5) / T().LINE_DUR)
        c:print(c.fHead, c.head1, x + pad, y + c.yHead1, ink, ink, ink, a * k1)
        if c.head2 then c:print(c.fHead, c.head2, x + pad, y + c.yHead2, ink, ink, ink, a * k1) end
        local k2 = SB.smooth((e - 0.85) / T().LINE_DUR)
        for ci, col in ipairs(c.cols) do
            local cx = x + pad + (ci - 1) * (c.colW + pad)
            for li, l in ipairs(col) do
                c:print(c.fSmall, l, cx, y + c.yBody + (li - 1) * c.lhBody, 0.18, 0.18, 0.18, a * k2)
            end
        end
        if #c.cols[2] > 0 then
            c:drawRect(x + pad + c.colW + pad / 2, y + c.yBody, 1, #c.cols[1] * c.lhBody, a * k2 * 0.6, 0.35, 0.35, 0.35)
        end
    end,
}
