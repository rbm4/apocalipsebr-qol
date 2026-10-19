-- The briefing card: what it says (built once from Data.collect's info), when each part appears,
-- where it sits on screen, and the drawing helpers. How it LOOKS is a "look" (SB.Looks): Classic,
-- Inverted and Minimal live in this file, the rest in Looks*.lua. A look has
--   layout(card)        sizes the block (blockW/blockH, padX/padY) and schedules its parts
--   render(card, e, a)  draws it at card time e with overall alpha a
--   place(card)         optional: its own placement (full-width and whole-screen looks)
--
-- By default nothing moves: lines only fade. The game redraws its UI at the "UI render FPS"
-- option, often 20-30, and at that rate anything that moves (lines rising into place, the rule
-- growing, bars sliding in) steps visibly, which players reported as jitter. A fade looks the
-- same at any rate. Movement is behind the "motion" option. Things that change in steps by
-- nature (a stamp landing, typed text, a flicker, a blinking cursor) are not movement.
--
-- Same trick as vanilla's ISSleepingUI: the element itself is 1x1 at 0,0 and draws outside its
-- own bounds (so its coordinates are screen coordinates), and it does not consume mouse events,
-- so it never blocks a click on the world.
require "ISUI/ISUIElement"

SurvivorBriefing = SurvivorBriefing or {}
local SB = SurvivorBriefing
SB.Looks = SB.Looks or {}

-- Look option index -> look, in the order Options > Mods lists them. (Append only: players'
-- saved settings hold the index.)
SB.LOOKS = { "classic", "inverted", "minimal", "camcorder", "journal", "casefile", "broadcast", "agent",
             "y2k", "hiphop", "terminal", "cinematic", "rpg", "quarantine", "newspaper", "military" }

-- Everything on most cards is in capitals. The engine's upper() knows no languages, and Turkish
-- writes the capital of "i" with a dot, so each translation says what that capital is.
local function upper(s)
    local capI = getText("IGUI_SurvivorBriefing_CapitalI")
    if capI ~= "I" and capI ~= "IGUI_SurvivorBriefing_CapitalI" then s = s:gsub("i", capI) end
    return string.upper(s)
end
SB.upper = upper

-- The game's town labels are in capitals ("MULDRAUGH, KY"); the looks that write sentences want
-- "Muldraugh, KY". Words of three letters or more that are all capitals get a capital and then
-- small letters; short ones (KY, NW) are left alone.
function SB.titleCase(s)
    if not s then return s end
    return (s:gsub("%S+", function(w)
        if #w > 2 and w == string.upper(w) and w ~= string.lower(w) then
            return w:sub(1, 1) .. string.lower(w:sub(2))
        end
        return w
    end))
end

local Card = ISUIElement:derive("SurvivorBriefingCard")
SB.Card = Card

-- Position option index -> anchor, in the order Options > Mods lists them.
-- (Append only: players' saved settings hold the index.)
SB.POSITIONS = { "BottomLeft", "TopLeft", "BottomRight", "TopRight", "Centre", "BottomCentre", "TopCentre" }

local T = {
    FADE_IN = 0.5, FADE_OUT = 1.2, DISMISS_OUT = 0.35,
    HEADER_START = 0.05, HEADER_DUR = 1.0,
    RULE_START = 0.25, RULE_DUR = 1.1,
    FIRST_LINE = 0.45,   -- seconds before the first line under the header starts
    LINE_GAP = 0.28,     -- stagger between lines
    LINE_DUR = 0.7,      -- each line's fade (+ rise)
    SUB_DELAY = 0.2,     -- the "near ..." line follows its row
    RISE = 10,           -- px each line rises into place (scaled with the text)
}
Card.T = T

local LABEL = 0.62
-- Black backing, soft at the top and bottom. Which way it fades follows the card's side.
local BG = {
    left = "media/textures/SurvivorBriefing_Fade.png",     -- solid on the left, gone on the right
    right = "media/textures/SurvivorBriefing_FadeL.png",   -- mirrored
    centre = "media/textures/SurvivorBriefing_FadeC.png",  -- solid middle, fades both ways
}
SB.TEX = "media/textures/SurvivorBriefing/"

local function smooth(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return t * t * (3 - 2 * t)
end
SB.smooth = smooth

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
SB.clamp = clamp

-- ---- Classic's fonts ---------------------------------------------------------------------------
-- Text sizes. Small/Medium/Large grow with the game's font-size option and carry every script
-- the game ships (Latin with accents, Cyrillic). The header fonts are fixed-size and do not:
--   Title   32 px typewriter - Latin with accents, no Cyrillic (in Russian the game maps it to
--           the Large body font instead)
--   Massive 47 px            - plain ASCII only: no accents, no Cyrillic
--   Intro   37 px serif      - Latin with accents and Cyrillic
-- So the body is picked by size, and the header is the first font in its preference order that
-- has every character of the header text and is clearly bigger than the values.
--   size 1: labels Small,  values Medium
--   size 2: labels Medium, values Large   (default)
--   size 3: labels Large,  values Large, big header
-- Size comes from the Text size option alone. (Until 0.9.0 the centre position was also one
-- size up, which read as the size "sticking" to whatever position was picked afterwards.)
local BODY = { { "Small", "Medium" }, { "Medium", "Large" }, { "Large", "Large" } }
local LOOK_SIZE = { 1.0, 1.2, 1.45 }
local HEADER = { normal = { "Title", "Intro", "Massive" }, big = { "Massive", "Intro", "Title" } }

-- A font measures a character it has no glyph for as zero wide.
local function hasGlyphs(font, text)
    local tm = getTextManager()
    for i = 1, #text do
        local c = text:sub(i, i)
        if c ~= " " and tm:MeasureStringX(font, c) <= 0 then return false end
    end
    return true
end

local function pickFonts(textSize, headerText)
    local tm = getTextManager()
    local roles = BODY[textSize] or BODY[2]
    local label, value = UIFont[roles[1]], UIFont[roles[2]]
    local need = tm:getFontHeight(value) * 1.15
    local header, tallest = nil, 0
    for _, name in ipairs(textSize >= 3 and HEADER.big or HEADER.normal) do
        local f = UIFont[name]
        if f and hasGlyphs(f, headerText) then
            local h = tm:getFontHeight(f)
            if h >= need then header = f; break end
            if h > tallest then header, tallest = f, h end
        end
    end
    return label, value, header or value
end

-- ---- the card ----------------------------------------------------------------------------------
function Card:new(playerNum, info, holdSeconds, textSize, position, motion, look)
    local o = ISUIElement.new(self, 0, 0, 1, 1)
    o.playerNum = playerNum
    o.motion = motion and true or false
    o.elapsed = 0
    o.hold = holdSeconds
    o.anchor = SB.POSITIONS[position or 1] or SB.POSITIONS[1]
    o.align = (o.anchor:find("Centre") and "centre") or (o.anchor:find("Right") and "right") or "left"
    local id = (type(look) == "number" and SB.LOOKS[look]) or look or "classic"
    if not SB.Looks[id] then id = "classic" end
    o.lookId, o.look = id, SB.Looks[id]
    o:build(info, textSize or 2)
    return o
end

-- What the card says, the same for every look. Rows keep both the capitalised text most looks
-- draw and the text as written (raw*) for the ones that write sentences.
function Card:build(info, textSize)
    self.info = info
    self.textSize = textSize
    local roles = BODY[textSize] or BODY[2]
    local tm = getTextManager()
    self.hBody = tm:getFontHeight(UIFont[roles[2]])
    self.u = self.hBody / 18           -- Classic's spacing and every look's distance from the HUD
    -- The other looks size their text by px (and their spacing by lu). Normal and Large share the
    -- same game body font, so the looks add their own step per Text size, and start bigger than
    -- Classic: their display fonts are narrower and lighter, and at Classic's size they read small.
    self.px = self.hBody * (LOOK_SIZE[textSize] or LOOK_SIZE[2])
    self.lu = self.px / 18

    self.day = info.day or 1
    self.dayText = getText("IGUI_SurvivorBriefing_Day", string.format("%d", self.day))
    self.header = upper(self.dayText)
    -- Any of these can be missing: switched off in the options, or not known to the character.
    self.exactTime = info.exactTime
    self.clock = info.clock and upper(info.clock) or nil
    self.date = info.date and upper(info.date) or nil

    self.rows = {}
    local function row(key, label, value, sub)
        if value and value ~= "" then
            table.insert(self.rows, { key = key, label = upper(label), value = upper(value), sub = sub and upper(sub) or nil,
                rawLabel = label, rawValue = value, rawSub = sub })
        end
    end
    local function add(key, value, sub) row(key, getText("IGUI_SurvivorBriefing_" .. key), value, sub) end
    if info.worldDayLabel then row("WorldDay", info.worldDayLabel, info.worldDay) end
    add("OutbreakDay", info.outbreakDay)
    add("Name", info.name)
    add("Occupation", info.occupation)
    add("Location", info.place, info.near and getText("IGUI_SurvivorBriefing_Near", info.near))
    add("Weather", info.weather)
    add("Kills", info.kills)
    if info.banditKillsLabel then row("BanditKills", info.banditKillsLabel, info.banditKills) end
    add("Deaths", info.deaths)

    self.look.layout(self)
end

-- One line after another from first, `gap` apart; returns their start times and sets the card's
-- length: the last line's fade, the hold, and the fade out.
function Card:schedule(count, first, gap, extra)
    first, gap = first or T.FIRST_LINE, gap or T.LINE_GAP
    local starts = {}
    for i = 1, count do starts[i] = first + (i - 1) * gap end
    local last = count > 0 and starts[count] or first
    self.total = last + (extra or 0) + T.LINE_DUR + self.hold + T.FADE_OUT
    return starts
end

-- When the card starts to fade out (the last moments before it are where a look can end on a
-- flourish: redaction bars, a stamp).
function Card:fadeOutAt() return self.total - T.FADE_OUT end

function Card:initialise()
    ISUIElement.initialise(self)
end

function Card:show()
    self:initialise()
    self:instantiate()
    self.javaObject:setConsumeMouseEvents(false)
    self:addToUIManager()
    self:backMost()
    self.lastMs = getTimestampMs()
end

function Card:dismiss()
    if not self.dismissAt then self.dismissAt = self.elapsed end
end

function Card:isDone()
    if self.dismissAt then return self.elapsed >= self.dismissAt + T.DISMISS_OUT end
    return self.elapsed >= self.total
end

function Card:close()
    self:removeFromUIManager()
    if SB.cards and SB.cards[self.playerNum] == self then SB.cards[self.playerNum] = nil end
end

function Card:update()
    local now = getTimestampMs()
    local dt = (now - (self.lastMs or now)) / 1000
    self.lastMs = now
    if not isGamePaused() then self.elapsed = self.elapsed + clamp(dt, 0, 0.25) end
    local player = getSpecificPlayer(self.playerNum)
    if not player or player:isDead() or player:isAsleep() then self:dismiss() end
    if self:isDone() then self:close() end
end

-- Card time at this exact frame. update() may run at a different rate than render(), so the
-- time since the last update is added here instead of reading a value up to a frame stale.
function Card:time()
    local e = self.elapsed
    if self.lastMs and not isGamePaused() then e = e + clamp((getTimestampMs() - self.lastMs) / 1000, 0, 0.25) end
    return e
end

function Card:alpha(e)
    local a = smooth(e / T.FADE_IN)
    a = math.min(a, 1 - smooth((e - (self.total - T.FADE_OUT)) / T.FADE_OUT))
    if self.dismissAt then a = math.min(a, 1 - smooth((e - self.dismissAt) / T.DISMISS_OUT)) end
    return a
end

-- ---- where it goes -----------------------------------------------------------------------------
-- Screen box of a HUD element, or nil if it is missing or hidden. Each lookup is guarded on its
-- own so one missing element (a mod replacing it, no chat in SP) never skips the others.
local function box(getter)
    local ok, b = pcall(function()
        local el = getter()
        if not el or not el:isVisible() then return nil end
        return { x = el:getX(), y = el:getY(), w = el:getWidth(), h = el:getHeight() }
    end)
    return ok and b or nil
end

local function hits(x, y, w, h, b)
    return b and x < b.x + b.w and b.x < x + w and y < b.y + b.h and b.y < y + h
end
-- The HUD pieces that are there right now. (Not ipairs({ box(a), box(b) }): a missing first
-- piece leaves a hole in that table and the second is never looked at.)
local function boxes(...)
    local out = {}
    for _, getter in ipairs({ ... }) do
        local b = box(getter)
        if b then table.insert(out, b) end
    end
    return out
end
SB.hudBoxes = boxes
SB.hudHits = hits

function Card:viewport()
    local n = self.playerNum
    return getPlayerScreenLeft(n), getPlayerScreenTop(n), getPlayerScreenWidth(n), getPlayerScreenHeight(n)
end

-- The lowest point of the top-right clock and speed buttons, and the top of the hotbar and
-- vehicle dashboard: what a full-width look must stay between.
function Card:hudTopBottom()
    local n = self.playerNum
    local vpL, vpT, vpW, vpH = self:viewport()
    local top, bottom = vpT, vpT + vpH
    for _, b in ipairs(boxes(function() return UIManager.getSpeedControls() end,
                             function() return UIManager.getClock() end)) do
        top = math.max(top, b.y + b.h)
    end
    for _, b in ipairs(boxes(function() return getPlayerHotbar(n) end,
                             function() return getPlayerVehicleDashboard(n) end)) do
        bottom = math.min(bottom, b.y)
    end
    return top, bottom
end

-- Top-left of the block. Corners keep clear of the HUD that lives there: the MP chat box
-- (bottom left), the icon sidebar (left), the speed buttons and watch clock (top right) and
-- the moodle column (right). The card first moves up or down, then sideways.
function Card:placement()
    -- A look may place itself (full-width and whole-screen looks); nil means the usual rules.
    if self.look.place then
        local px, py = self.look.place(self)
        if px then return px, py end
    end
    local n, u = self.playerNum, self.u
    local vpL, vpT, vpW, vpH = self:viewport()
    local w, h = self.blockW, self.blockH
    if self.anchor == "Centre" then
        -- A touch above the middle, which reads as centred.
        return vpL + math.floor((vpW - w) / 2), vpT + math.floor(vpH * 0.46 - h / 2)
    end
    if self.anchor == "BottomCentre" then
        -- Centred, sitting on whatever lives at the bottom middle: the hotbar, and the vehicle
        -- dashboard while driving.
        local x = vpL + math.floor((vpW - w) / 2)
        local y = vpT + vpH - math.floor(22 * u) - self.padY * 2 - h
        for _, b in ipairs(boxes(function() return getPlayerHotbar(n) end,
                                 function() return getPlayerVehicleDashboard(n) end)) do
            if hits(x, y, w, h, b) then y = b.y - math.floor(14 * u) - self.padY * 2 - h end
        end
        return x, math.max(y, vpT + math.floor(20 * u))
    end
    if self.anchor == "TopCentre" then
        -- Centred under the top edge (contributed by Black_Fox on the Workshop). Only a very
        -- wide card on a narrow screen reaches the clock and speed buttons in the corner.
        local x = vpL + math.floor((vpW - w) / 2)
        local y = vpT + math.floor(22 * u) + self.padY
        for _, b in ipairs(boxes(function() return UIManager.getSpeedControls() end,
                                 function() return UIManager.getClock() end)) do
            if hits(x, y, w, h, b) then y = b.y + b.h + math.floor(14 * u) + self.padY end
        end
        return x, clamp(y, vpT + math.floor(20 * u), vpT + vpH - h - math.floor(20 * u))
    end
    local right = self.align == "right"
    local top = self.anchor:find("Top") ~= nil
    local mx, my = math.floor(32 * u), math.floor(22 * u) + self.padY
    local gap = math.floor(14 * u)
    local x = right and (vpL + vpW - mx - w) or (vpL + mx)
    local y = top and (vpT + my) or (vpT + vpH - my - h)

    if top then
        for _, b in ipairs(boxes(function() return UIManager.getSpeedControls() end,
                                 function() return UIManager.getClock() end)) do
            if hits(x, y, w, h, b) then y = b.y + b.h + gap + self.padY end
        end
    elseif n == 0 then
        local b = box(function() return ISChat and ISChat.instance end)
        if hits(x, y, w, h, b) then y = b.y - gap - self.padY - h end
    end
    if right then
        local b = box(function() return UIManager.getMoodleUI(n) end)
        if hits(x, y, w, h, b) then x = b.x - gap - w end
    else
        local b = box(function() return getPlayerData(n) and getPlayerData(n).equipped end)
        if hits(x, y, w, h, b) then x = b.x + b.w + math.floor(24 * u) end
    end
    return x, clamp(y, vpT + math.floor(20 * u), vpT + vpH - h - math.floor(20 * u))
end

-- ---- drawing helpers for the looks ---------------------------------------------------------------
-- Text with a soft drop shadow so it stays readable over snow and daylight. Drawn on whole
-- pixels: bitmap text at a fractional position shimmers.
function Card:text(s, x, y, r, g, b, a, font)
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    self:drawText(s, x + 1, y + 1, 0, 0, 0, a * 0.75, font)
    self:drawText(s, x, y, r, g, b, a, font)
end

-- Text in any font of SB.Fonts. fx (optional):
--   shadow = { dx, dy, alpha [, r, g, b] }    outline = { px, r, g, b, alpha }
function Card:print(F, s, x, y, r, g, b, a, fx)
    if not s or s == "" or a <= 0.001 then return end
    local Fonts = SB.Fonts
    if fx and fx.outline then
        local t, orr, og, ob, oa = fx.outline[1], fx.outline[2], fx.outline[3], fx.outline[4], fx.outline[5]
        for ox = -t, t, t do
            for oy = -t, t, t do
                if ox ~= 0 or oy ~= 0 then Fonts.draw(self, F, s, x + ox, y + oy, orr, og, ob, a * oa) end
            end
        end
    end
    if fx and fx.shadow then
        local sh = fx.shadow
        Fonts.draw(self, F, s, x + sh[1], y + sh[2], sh[4] or 0, sh[5] or 0, sh[6] or 0, a * sh[3])
    end
    Fonts.draw(self, F, s, x, y, r, g, b, a)
end

-- Chrome or gold lettering: the text drawn once per horizontal band of its line, each band its
-- own colour (bands = { { from, to, r, g, b }, ... } as fractions of the line height). A real
-- gradient is not possible with the game's text, and the hard steps are what 90s chrome did.
function Card:printBands(F, s, x, y, a, bands)
    local h, w = SB.Fonts.height(F), SB.Fonts.width(F, s)
    local top, cap = SB.Fonts.capTop(F), SB.Fonts.capH(F)
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    -- fractions of the capitals' height; the first band reaches up to the line's top and the
    -- last down to its bottom, so accents and descenders get a colour too
    local function at(f)
        if f <= 0 then return y end
        if f >= 1 then return y + h end
        return y + top + cap * f
    end
    for _, b in ipairs(bands) do
        local y0, y1 = math.floor(at(b[1])), math.floor(at(b[2]))
        if y1 > y0 then
            self:setStencilRect(x - 6, y0, w + 12, y1 - y0)
            SB.Fonts.draw(self, F, s, x, y, b[3], b[4], b[5], a)
            self:clearStencilRect()
        end
    end
end

-- Text that types itself out: the first n characters, the next few still scrambling.
local JUNK = "#/\\|=+<>X0123456789ABCDEFKNRTZ"
function Card:typed(s, k, scramble)
    local n = math.floor(#s * clamp(k, 0, 1) + 0.0001)
    if n >= #s then return s, true end
    local out = s:sub(1, n)
    if scramble then
        for _ = 1, math.min(3, #s - n) do
            local j = ZombRand and (ZombRand(#JUNK) + 1) or 1
            out = out .. JUNK:sub(j, j)
        end
    end
    return out, false
end

-- A rectangle with rounded corners, filled (and optionally rimmed): rects plus four corner
-- pieces, all tinted (the game draws no rounded shapes).
function Card:roundRect(x, y, w, h, rad, r, g, b, a, rim)
    rad = math.floor(math.min(rad, w / 2, h / 2))
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    local T_ = SB.TEX
    self:drawRect(x + rad, y, w - 2 * rad, h, a, r, g, b)
    self:drawRect(x, y + rad, rad, h - 2 * rad, a, r, g, b)
    self:drawRect(x + w - rad, y + rad, rad, h - 2 * rad, a, r, g, b)
    if rad > 0 then
        self:drawTextureScaled(getTexture(T_ .. "corner_fill_tl.png"), x, y, rad, rad, a, r, g, b)
        self:drawTextureScaled(getTexture(T_ .. "corner_fill_tr.png"), x + w - rad, y, rad, rad, a, r, g, b)
        self:drawTextureScaled(getTexture(T_ .. "corner_fill_bl.png"), x, y + h - rad, rad, rad, a, r, g, b)
        self:drawTextureScaled(getTexture(T_ .. "corner_fill_br.png"), x + w - rad, y + h - rad, rad, rad, a, r, g, b)
    end
    if rim then
        local t = math.max(1, math.floor(rim[1]))
        local rr, rg, rb, ra = rim[2], rim[3], rim[4], rim[5] * (a > 0 and 1 or 0)
        self:drawRect(x + rad, y, w - 2 * rad, t, ra, rr, rg, rb)
        self:drawRect(x + rad, y + h - t, w - 2 * rad, t, ra, rr, rg, rb)
        self:drawRect(x, y + rad, t, h - 2 * rad, ra, rr, rg, rb)
        self:drawRect(x + w - t, y + rad, t, h - 2 * rad, ra, rr, rg, rb)
        if rad > 0 then
            self:drawTextureScaled(getTexture(T_ .. "corner_ring_tl.png"), x, y, rad, rad, ra, rr, rg, rb)
            self:drawTextureScaled(getTexture(T_ .. "corner_ring_tr.png"), x + w - rad, y, rad, rad, ra, rr, rg, rb)
            self:drawTextureScaled(getTexture(T_ .. "corner_ring_bl.png"), x, y + h - rad, rad, rad, ra, rr, rg, rb)
            self:drawTextureScaled(getTexture(T_ .. "corner_ring_br.png"), x + w - rad, y + h - rad, rad, rad, ra, rr, rg, rb)
        end
    end
end

-- A solid black redaction bar over [x, x + w) of a line of height h, drawn from the left like a
-- marker stroke: k is how far along it is (0..1).
Card.WIPE = 0.3     -- seconds one bar takes to cross its words
Card.WIPE_GAP = 0.3 -- seconds between one bar starting and the next
-- With the line's font F the bar covers its letters, whatever room the font leaves above them.
function Card:redact(x, y, w, h, a, k, F)
    k = k or 1
    if k <= 0 then return end
    local full = math.floor(w) + 4
    local top, bh = y + h * 0.18, h * 0.7
    if F then
        local capTop, capH = SB.Fonts.capTop(F), SB.Fonts.capH(F)
        top, bh = y + capTop - capH * 0.28, capH * 1.6
    end
    self:drawRect(math.floor(x) - 2, math.floor(top), math.max(1, math.floor(full * k)), math.floor(bh), a, 0.02, 0.02, 0.02)
end

-- Text with some character ranges left out (the words under a finished redaction bar), the rest
-- drawn where it would have been. Otherwise, as the card fades out and the bars fade with it,
-- the hidden words would show through. skips: { { i, j }, ... } positions in s.
function Card:printSkipping(F, s, x, y, r, g, b, a, fx, skips)
    if not skips or #skips == 0 then return self:print(F, s, x, y, r, g, b, a, fx) end
    table.sort(skips, function(p, q) return p[1] < q[1] end)
    local pos = 1
    for _, sk in ipairs(skips) do
        if sk[1] > pos then self:print(F, s:sub(pos, sk[1] - 1), x + SB.Fonts.width(F, s:sub(1, pos - 1)), y, r, g, b, a, fx) end
        pos = math.max(pos, sk[2] + 1)
    end
    if pos <= #s then self:print(F, s:sub(pos), x + SB.Fonts.width(F, s:sub(1, pos - 1)), y, r, g, b, a, fx) end
end

-- How far along a bar that starts wiping at `at` is at card time e (eases out, like a hand).
function Card:wipe(e, at)
    local t = SB.clamp((e - at) / Card.WIPE, 0, 1)
    return 1 - (1 - t) * (1 - t)
end

-- A look's own text (IGUI_SurvivorBriefing_LK_<key>).
function Card:L(key, ...)
    return getText("IGUI_SurvivorBriefing_LK_" .. key, ...)
end

-- A row's label as a look names it (IGUI_SurvivorBriefing_LK_<prefix>_<row key>, in capitals),
-- or the usual label where the look has no word of its own.
function Card:label(prefix, r)
    local own = getTextOrNull and getTextOrNull("IGUI_SurvivorBriefing_LK_" .. prefix .. "_" .. r.key)
    return own and upper(own) or r.label
end

-- A line's own fade: alpha 0 -> 1. With motion on it also rises from RISE px below its place.
function Card:line(e, start, dur)
    local k = smooth((e - start) / dur)
    return k, self.motion and (1 - k) * T.RISE * self.u or 0
end

-- Live game time, re-read only when the minute changes.
function Card:liveClock()
    local ok, m = pcall(function() return getGameTime():getMinutes() end)
    if ok and m ~= self.clockMinute then
        local ok2, c = pcall(SB.Data.timeText, self.exactTime)
        if ok2 and c then self.clock, self.clockMinute = upper(c), m end
    end
    return self.clock
end

function Card:render()
    local e = self:time()
    local a = self:alpha(e)
    if a <= 0.001 then return end
    self.look.render(self, e, a)
end

-- ---- Classic, Inverted, Minimal --------------------------------------------------------------------
-- One layout, three styles: Classic (white on a dark backing), Inverted (dark on a light band),
-- Minimal (no backing and no rule, the header at the size of the values).
local STYLES = {
    classic = { backing = 0, fg = 1, label = LABEL, date = 0.85, shadow = true, rule = true },
    inverted = { backing = 0.92, fg = 0.08, label = 0.34, date = 0.2, shadow = false, rule = true },
    minimal = { fg = 1, label = 0.78, date = 0.9, shadow = true, rule = false, plainHeader = true },
}

local function classicLayout(self, st)
    local roles = BODY[self.textSize] or BODY[2]
    self.fLabel, self.fValue = UIFont[roles[1]], UIFont[roles[2]]
    local _, _, header = pickFonts(self.textSize, self.header)
    self.fHeader = st.plainHeader and self.fValue or header

    local tm = getTextManager()
    local hValue, hLabel, hHeader = tm:getFontHeight(self.fValue), tm:getFontHeight(self.fLabel), tm:getFontHeight(self.fHeader)
    local u = self.u
    local dateLine = self.clock ~= nil or self.date ~= nil

    -- Vertical layout, relative to the top of the block.
    local y = 0
    self.yHeader = y;       y = y + hHeader + math.floor(4 * u)
    self.yRule = y;         y = y + math.max(1, math.floor(2 * u))
    if dateLine then
        y = y + math.floor(7 * u)
        self.yDate = y;     y = y + hValue
    end
    if #self.rows > 0 then y = y + math.floor((dateLine and 12 or 9) * u) end
    local rowH = math.max(hValue, hLabel) + math.floor(5 * u)
    local labelW, valueW = 0, 0
    for _, r in ipairs(self.rows) do
        r.y = y
        y = y + rowH
        if r.sub then r.ySub = y - math.floor(3 * u); y = y + hLabel end
        r.labelW = tm:MeasureStringX(self.fLabel, r.label)
        labelW = math.max(labelW, r.labelW)
        valueW = math.max(valueW, tm:MeasureStringX(self.fValue, r.value))
        if r.sub then valueW = math.max(valueW, tm:MeasureStringX(self.fLabel, r.sub)) end
    end
    self.blockH = y
    self.labelW = labelW
    self.valueX = labelW + math.floor(16 * u)
    self.tableW = self.valueX + valueW
    self.labelDy = math.floor((hValue - hLabel) / 2)

    -- The clock keeps running, so the date sits after the widest time it could show rather than
    -- after the current one; otherwise the date would shift when 9:59 turns 10:00.
    self.clockW = 0
    if self.clock then
        for _, sample in ipairs(SB.Data.timeSamples(self.exactTime)) do
            self.clockW = math.max(self.clockW, tm:MeasureStringX(self.fValue, upper(sample)))
        end
        if self.date then self.clockW = self.clockW + tm:MeasureStringX(self.fValue, "   ") end
    end
    self.headerW = tm:MeasureStringX(self.fHeader, self.header)
    self.dateLineW = self.clockW + (self.date and tm:MeasureStringX(self.fValue, self.date) or 0)
    self.blockW = math.max(self.headerW, self.dateLineW, self.tableW)
    self.padX, self.padY = math.floor(28 * u), math.floor(18 * u)

    -- Schedule: the date line first (when there is one), then one row after another.
    self.dateStart = T.FIRST_LINE
    local last = T.FIRST_LINE
    for i, r in ipairs(self.rows) do
        r.start = T.FIRST_LINE + (dateLine and i or i - 1) * T.LINE_GAP
        last = r.start + (r.sub and T.SUB_DELAY or 0)
    end
    self.total = last + T.LINE_DUR + self.hold + T.FADE_OUT
end

local function drawBacking(self, x, y, a, tint)
    local u, padX, padY = self.u, self.padX, self.padY
    local vpL, _, vpW = self:viewport()
    local vpR = vpL + vpW
    local bx, bw
    local top, bh = y - padY, self.blockH + padY * 2
    if self.align == "left" then
        -- Near the edge it runs to the edge, so no unshaded sliver is left there.
        bx = x - padX
        if bx - vpL < 40 * u then bx = vpL end
        bw = x - bx + self.blockW + padX * 4
    elseif self.align == "right" then
        local br = x + self.blockW + padX
        if vpR - br < 40 * u then br = vpR end
        bx = x - padX * 4
        bw = br - bx
    else
        bw = self.blockW + padX * 10
        bx = x + self.blockW / 2 - bw / 2
        top, bh = y - padY * 2, self.blockH + padY * 4
    end
    local tex = getTexture(BG[self.align])
    local strength = tint > 0.5 and 0.88 or 0.7
    if tex then
        self:drawTextureScaled(tex, bx, top, bw, bh, a * strength, tint, tint, tint * 0.96)
    else
        self:drawRect(bx, top, bw, bh, a * 0.4, tint, tint, tint)
    end
end

local function classicRender(self, e, a, st)
    local u = self.u
    local x, y = self:placement()
    local centre = self.align == "centre"
    local cx = x + self.blockW / 2
    local fg = st.fg
    local function txt(s, tx, ty, c, alpha, font)
        if st.shadow then self:text(s, tx, ty, c, c, c, alpha, font)
        else self:drawText(s, math.floor(tx + 0.5), math.floor(ty + 0.5), c, c, c, alpha, font) end
    end

    if st.backing then drawBacking(self, x, y, a, st.backing) end

    local k, dy = self:line(e, T.HEADER_START, T.HEADER_DUR)
    if k > 0 then
        txt(self.header, centre and (cx - self.headerW / 2) or x, y + self.yHeader + dy, fg, a * k, self.fHeader)
    end

    -- The rule fades in at full width. With motion on it grows out from the card's anchored
    -- side instead (both ways in the centre).
    local grow = smooth((e - T.RULE_START) / T.RULE_DUR)
    if st.rule and grow > 0 then
        local rw = self.motion and math.floor(self.blockW * grow) or self.blockW
        local rx = (centre and math.floor(cx - rw / 2)) or (self.align == "right" and (x + self.blockW - rw)) or x
        self:drawRect(rx, y + self.yRule, rw, math.max(1, math.floor(2 * u)), a * 0.8 * (self.motion and 1 or grow), fg, fg, fg)
    end

    -- Clock bright (and still running), date a step dimmer. Either can be absent.
    if self.yDate then
        k, dy = self:line(e, self.dateStart, T.LINE_DUR)
        if k > 0 then
            local dx = centre and (cx - self.dateLineW / 2) or x
            if self.clock then txt(self:liveClock(), dx, y + self.yDate + dy, fg, a * k, self.fValue) end
            if self.date then txt(self.date, dx + self.clockW, y + self.yDate + dy, st.date, a * k, self.fValue) end
        end
    end

    -- Rows: a label column and a value column. In the centre the table is centred as a whole
    -- and the labels are right-aligned against the values.
    local tx = centre and (cx - self.tableW / 2) or x
    for _, r in ipairs(self.rows) do
        k, dy = self:line(e, r.start, T.LINE_DUR)
        if k > 0 then
            local lx = centre and (tx + self.labelW - r.labelW) or tx
            txt(r.label, lx, y + r.y + self.labelDy + dy, st.label, a * k, self.fLabel)
            txt(r.value, tx + self.valueX, y + r.y + dy, fg, a * k, self.fValue)
            if r.sub then
                local ks, dys = self:line(e, r.start + T.SUB_DELAY, T.LINE_DUR)
                if ks > 0 then txt(r.sub, tx + self.valueX, y + r.ySub + dys, st.label, a * ks, self.fLabel) end
            end
        end
    end
end

for id, st in pairs(STYLES) do
    SB.Looks[id] = {
        layout = function(self) classicLayout(self, st) end,
        render = function(self, e, a) classicRender(self, e, a, st) end,
    }
end
