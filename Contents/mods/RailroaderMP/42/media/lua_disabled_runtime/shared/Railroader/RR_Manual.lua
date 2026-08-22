--***********************************************************************
-- Railroader / RR_Manual  -- the engineer's notebook: THE MOD'S MANUAL, carried
-- in the pocket of the man who took the Railroader profession.
--
-- The Railroader starts with two things. One is the photo album (RR_Album) --
-- who he was; that one is pure flavour. This is the other, and it is the
-- opposite: a working CRIB SHEET. Eight pages, ordered by what the survivor
-- needs first -- where the 800 stands and how to get in it, how to crank it,
-- how to move it and stop it, how to read the control stand, signals and lights,
-- fuel and battery, switches and what hitting things costs, derailment and the
-- cab.
--
-- HOUSE STYLE, DECIDED BY THE OWNER (2026-07-29) AND NOT TO BE DRIFTED FROM:
-- ONE FACT PER LINE. No anecdotes, no dated entries, no second handwriting, no
-- character in it at all. The earlier cut was written in the voice of a 1968
-- fireman taking notes off an engineer named Hank, with the apocalypse facts
-- arriving in a second hand -- it read well and taught slowly, which is the
-- wrong trade for the one item a player opens when he does not know which key
-- starts the engine. Keep new lines terse, keep them true, and put the thing
-- the player needs soonest nearest the front.
--
-- PURE LUA, NO ENGINE DEPENDENCIES -- unit-tested in a bare interpreter
-- (tests/run_tests.lua). The client adapter (RR_ManualPlace) does the engine
-- work: create the item and write the pages into it.
--
-- WHERE THE TEXT LIVES: not here. Each page is one translation key in
-- Translate/{EN,RU}/IG_UI.json, with "\n" (a literal backslash-n) for line
-- breaks -- the convention vanilla itself uses for multi-line strings (see
-- Print_Text.json + ISReadABook:displayPrintMedia, which gsubs exactly this).
-- Manual.unescape() is that gsub. Consequence worth knowing: the pages are
-- written into the item at character creation, so they are baked into the save
-- in the language the game was in at that moment -- which is what a handwritten
-- notebook should do anyway.
--
-- THE FIT RULES (MAX_LINES/MAX_COLS) ARE NOT DECORATION. The vanilla journal UI
-- (ISUIWriteJournal, opened from ISInventoryPaneContextMenu with lineNumber=15
-- and a 350px window) hands the page to an ISTextEntryBox with setMaxLines(15)
-- and setMaxTextLength(15*80). Text past that is not scrolled to -- it is simply
-- not seen. So the unit tests wrap every authored page, in EVERY language, and
-- fail if one would spill. ulen() counts CHARACTERS, not bytes: the Russian
-- pages are UTF-8 and #s would over-count them by two.
--***********************************************************************

local Manual = {}

-- The item, and the once-per-save flag (same global ModData table as the album's
-- and the depot loco's: "RR_World").
Manual.ITEM_TYPE = "Base.RR_EngineerNotebook"
Manual.MD_FLAG   = "rrNotebookPlaced"

-- Keep in sync with PageToWrite in media/scripts/railroader_items.txt. Blank
-- pages past our own are the survivor's to fill.
Manual.PAGE_SLOTS = 16

-- The journal UI's real limits, with a line of slack (it draws 15).
Manual.MAX_LINES = 14
Manual.MAX_COLS  = 50

--------------------------------------------------------------------------
-- The pages, IN ORDER OF NEED -- page 1 answers "where is it and how do I get
-- in", and nothing further forward than that. Each entry is an id (stable, used
-- in modData so a page can be identified later) and the translation key holding
-- the whole page.
--------------------------------------------------------------------------
Manual.PAGES = {
    { id = "place",   key = "IGUI_RR_Note_Place"   },  -- where the 800 is; board/leave (E); the cab menu (V)
    { id = "start",   key = "IGUI_RR_Note_Start"   },  -- reverser N, tap W, prime/crank/catch, tap S
    { id = "run",     key = "IGUI_RR_Note_Run"     },  -- reverser R, throttle W/S, the interlock, brake
    { id = "panel",   key = "IGUI_RR_Note_Panel"   },  -- the six dials and the five lamps (RR_HudModel)
    { id = "signals", key = "IGUI_RR_Note_Signals" },  -- horn Q, bell L (air!), headlight F, cab light
    { id = "fuel",    key = "IGUI_RR_Note_Fuel"    },  -- the can, the depot tank, the battery
    { id = "track",   key = "IGUI_RR_Note_Track"   },  -- switches; what a hit costs; OUT OF ORDER
    { id = "derail",  key = "IGUI_RR_Note_Derail"  },  -- the two triggers; it is terminal
}

--------------------------------------------------------------------------
-- unescape(s): the translation files carry "\n" as two characters (backslash,
-- n), because that is how PZ's own multi-line strings are written. Turn them
-- into real line breaks. Anything else is left alone.
--------------------------------------------------------------------------
function Manual.unescape(s)
    if type(s) ~= "string" then return "" end
    local out = string.gsub(s, "\\n", "\n")
    return out
end

--------------------------------------------------------------------------
-- ulen(s): length in CHARACTERS for UTF-8 text. A byte is a continuation byte
-- iff it is 0x80..0xBF; every other byte starts a character. (#s would count
-- Cyrillic twice and would happily "prove" a Russian page fits when it does
-- not.)
--------------------------------------------------------------------------
function Manual.ulen(s)
    if type(s) ~= "string" then return 0 end
    local n = 0
    for i = 1, #s do
        local b = string.byte(s, i)
        if b < 128 or b >= 192 then n = n + 1 end
    end
    return n
end

--------------------------------------------------------------------------
-- wrap(text, cols): the lines the journal will actually draw. Honours the
-- authored line breaks first, then word-wraps what is still too wide, the way
-- a text box does. A single word longer than the column count is left on its
-- own line (it will be clipped in-game -- the tests catch that as an overflow
-- of width, see fits()).
--------------------------------------------------------------------------
function Manual.wrap(text, cols)
    cols = cols or Manual.MAX_COLS
    local lines = {}
    text = tostring(text or "")

    -- split on newlines, keeping empty lines (they are spacing, and they cost a
    -- line of the budget just like any other)
    local paras = {}
    local start = 1
    while true do
        local i = string.find(text, "\n", start, true)
        if not i then
            paras[#paras + 1] = string.sub(text, start)
            break
        end
        paras[#paras + 1] = string.sub(text, start, i - 1)
        start = i + 1
    end

    for _, para in ipairs(paras) do
        if Manual.ulen(para) <= cols then
            lines[#lines + 1] = para
        else
            -- keep the leading indent of a wrapped paragraph, so a hanging
            -- "1. ..." list still measures the way it looks
            local cur = nil
            for word in string.gmatch(para, "%S+") do
                if cur == nil then
                    cur = word
                elseif Manual.ulen(cur) + 1 + Manual.ulen(word) <= cols then
                    cur = cur .. " " .. word
                else
                    lines[#lines + 1] = cur
                    cur = word
                end
            end
            if cur then lines[#lines + 1] = cur end
        end
    end

    return lines
end

--------------------------------------------------------------------------
-- fits(text, maxLines, cols) -> ok, lineCount, widest
-- Would this page be fully visible in the journal? ok is false if it needs more
-- lines than the UI draws, or if any single unbreakable word is wider than the
-- box.
--------------------------------------------------------------------------
function Manual.fits(text, maxLines, cols)
    maxLines = maxLines or Manual.MAX_LINES
    cols     = cols     or Manual.MAX_COLS
    local lines = Manual.wrap(text, cols)
    local widest = 0
    for _, l in ipairs(lines) do
        local n = Manual.ulen(l)
        if n > widest then widest = n end
    end
    return (#lines <= maxLines) and (widest <= cols), #lines, widest
end

--------------------------------------------------------------------------
-- pageCount() / keys(): the notebook's shape. pageCount must never exceed
-- PAGE_SLOTS, or the journal UI cannot page as far as the last page we wrote.
--------------------------------------------------------------------------
function Manual.pageCount()
    return #Manual.PAGES
end

function Manual.keys()
    local t = {}
    for i, p in ipairs(Manual.PAGES) do t[i] = p.key end
    return t
end

RR = RR or {}
RR.Manual = Manual

return Manual
