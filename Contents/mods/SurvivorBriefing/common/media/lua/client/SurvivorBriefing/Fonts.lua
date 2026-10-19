-- Fonts for the looks. A font here is a small table, one of:
--   { ui = UIFont.X, zoom = k }               the game's own font (zoom 1 unless asked)
--   { own = AngelCodeFont, scale = k, ... }   a bitmap font the mod ships (tools/make_fonts.py)
-- The mod's fonts are drawn from one big atlas and scaled to the size the card needs, so they
-- follow the Text size option and the game's font-size option like the game's fonts do.
-- (A mod loading its own font this way: The Ark, Workshop 3707475814, does the same.)
--
-- Most of the free fonts have no Cyrillic, and none has Chinese. Fonts.pick() takes the first
-- font in a list that has every character of the texts it will draw; the last one in the list
-- is the fallback and is always a font that has them (a game font, or one of ours with Cyrillic).
SurvivorBriefing = SurvivorBriefing or {}
local SB = SurvivorBriefing

local Fonts = {}
SB.Fonts = Fonts

local DIR = "media/fonts/SurvivorBriefing/"
local cache = {}

local function load(id)
    if cache[id] == nil then
        local ok, f = pcall(function() return AngelCodeFont.new(DIR .. id .. ".fnt", DIR .. id .. "_0.png") end)
        cache[id] = (ok and f) or false
        if not cache[id] then print("[SurvivorBriefing] font " .. id .. " could not be loaded: " .. tostring(f)) end
    end
    return cache[id] or nil
end

function Fonts.game(name, zoom)
    return { ui = UIFont[name] or UIFont.Medium, zoom = zoom or 1 }
end

-- One of the mod's fonts, drawn px tall (its line height). nil if it could not be loaded.
function Fonts.make(id, px)
    local data = SB.FONTS_DATA and SB.FONTS_DATA[id]
    local f = data and load(id)
    if not f then return nil end
    return { own = f, id = id, scale = math.max(0.2, px / data.line), top = data.top }
end

-- Where the capitals sit in a line: from the top of the line, and how tall. Display fonts keep a
-- lot of space above their letters, so aligning by the line box puts them visibly low.
function Fonts.capTop(F)
    if F.own then
        local data = SB.FONTS_DATA[F.id]
        return math.floor((data.capTop or data.line * 0.25) * F.scale + 0.5)
    end
    return math.floor(Fonts.height(F) * 0.26 + 0.5)
end

function Fonts.capH(F)
    if F.own then
        local data = SB.FONTS_DATA[F.id]
        return math.floor((data.capH or data.line * 0.55) * F.scale + 0.5)
    end
    return math.floor(Fonts.height(F) * 0.5 + 0.5)
end

function Fonts.height(F)
    if F.own then return math.floor(F.own:getLineHeight() * F.scale + 0.5) end
    return math.floor(getTextManager():getFontHeight(F.ui) * (F.zoom or 1) + 0.5)
end

function Fonts.width(F, s)
    if not s or s == "" then return 0 end
    if F.own then return math.floor(F.own:getWidth(s) * F.scale + 0.5) end
    return math.floor(getTextManager():MeasureStringX(F.ui, s) * (F.zoom or 1) + 0.5)
end

-- Every character of s has a glyph. A missing glyph measures zero wide; past the highest
-- character an atlas holds the game would draw '?', so those count as missing too.
function Fonts.has(F, s)
    if not s then return true end
    local tm = not F.own and getTextManager()
    for i = 1, #s do
        local c = s:sub(i, i)
        if c ~= " " then
            if F.own then
                if s:byte(i) > F.top or F.own:getWidth(c) <= 0 then return false end
            elseif tm:MeasureStringX(F.ui, c) <= 0 then
                return false
            end
        end
    end
    return true
end

-- The first of the fonts that can draw all the texts; the last one otherwise. nil fonts (one
-- that failed to load) are skipped, which is why they come as arguments and not in a table:
-- a nil in a table would end ipairs there.
function Fonts.pick(texts, ...)
    local last
    for i = 1, select("#", ...) do
        local F = select(i, ...)
        if F then
            last = F
            local ok = true
            for _, s in ipairs(texts) do
                if s and not Fonts.has(F, s) then ok = false; break end
            end
            if ok then return F end
        end
    end
    return last
end

-- Drawn on whole pixels: bitmap text at a fractional position shimmers.
function Fonts.draw(el, F, s, x, y, r, g, b, a)
    if not s or s == "" or a <= 0 then return end
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    if F.own then
        F.own:drawString(x, y, F.scale, s, r, g, b, a)
    elseif (F.zoom or 1) ~= 1 then
        el:drawTextZoomed(s, x, y, F.zoom, r, g, b, a, F.ui)
    else
        el:drawText(s, x, y, r, g, b, a, F.ui)
    end
end
