--***********************************************************************
-- Railroader / RR_DriveHud  -- the EMD GP7 control stand RENDERER (Task 2.D)
--
-- This file draws. It decides nothing: shared/Railroader/RR_HudModel.lua answers
-- every layout question (scale, anchor, gauge readings, quadrant, lamps, alarm)
-- and this turns the returned table into draw calls.
--
-- Design: docs/HUD_DESIGN.md · docs/HUD_STYLE.md
-- Faces:  tools/make_gauges.py -> media/ui/Railroader/rr_g_*.png
--
-- HOW THE ROUND INSTRUMENTS ARE POSSIBLE AT ALL (PZ has no circle primitive):
--   * dial faces are TEXTURES, blitted with drawTextureScaled so one authored
--     size serves every Font Size rung;
--   * needles are TINTED QUADS -- drawTextureAllPoint(nil, ...8 points..., r,g,b,a).
--     Passing a nil texture fills a solid quad (this is exactly how vanilla's own
--     drawLine2 works, ISUIElement.lua:1229), so a needle can be any length, any
--     angle and any colour with no asset at all. DrawTextureAngle was rejected:
--     it draws at the texture's NATIVE size, and this panel has to scale.
--   * indicator lenses are one WHITE texture, tinted per lamp.
--
-- DRAW-CALL TRAPS (verified in ISUIElement.lua):
--   * argument order FLIPS: drawRect(x,y,w,h, a,r,g,b) vs drawText(s,x,y, r,g,b,a, font)
--   * drawRectBorder is hardcoded 1 px (four 1-px rects, :1219) -- a hairline at
--     the 4x font set. Borders here are explicit rects.
--   * MeasureFont() is not the real height -- always getFontHeight().
--
-- LOAD ORDER: ISUIElement may not exist when the mod first loads, so the class is
-- built lazily on OnGameStart. (Deriving at file scope once killed this file.)
--***********************************************************************

require("Railroader/RR_Drive")
require("Railroader/RR_Engine")
require("Railroader/RR_Lights")
require("Railroader/RR_HudModel")

local MODES = { "full", "compact", "off" }
local SETTINGS_FILE = "railroader_hud.ini"
local TEXPATH = "media/ui/Railroader/"

--------------------------------------------------------------------------
-- Palette. The stand is a machine, not a webpage: never themed.
--------------------------------------------------------------------------
local PAL = {
    plate    = { 0.086, 0.094, 0.098, 0.95 },
    navy     = { 0.106, 0.227, 0.420, 1.0 },   -- the K&L 800 livery navy
    navyLit  = { 0.376, 0.549, 0.804, 1.0 },
    box      = { 0.122, 0.129, 0.133, 1.0 },
    boxEdge  = { 0.180, 0.192, 0.196, 1.0 },
    cell     = { 0.102, 0.110, 0.118, 1.0 },
    cellEdge = { 0.235, 0.243, 0.251, 1.0 },

    cream    = { 0.808, 0.792, 0.745, 1.0 },
    dim      = { 0.502, 0.494, 0.463, 1.0 },
    dark     = { 0.055, 0.063, 0.071, 1.0 },

    power    = { 0.910, 0.639, 0.239, 1.0 },   -- lit notch
    powerDim = { 0.588, 0.361, 0.110, 1.0 },   -- notch the ramp has not reached
    safe     = { 0.298, 0.776, 0.420, 1.0 },
    caution  = { 0.910, 0.639, 0.239, 1.0 },
    danger   = { 0.898, 0.325, 0.239, 1.0 },
    terminal = { 1.000, 0.231, 0.184, 1.0 },
    lamp     = { 0.910, 0.816, 0.471, 1.0 },
    lampOff  = { 0.110, 0.118, 0.125, 1.0 },

    needle   = { 0.910, 0.894, 0.847, 1.0 },
    needleCw = { 0.620, 0.173, 0.133, 1.0 },   -- the counterweight tail
    hub      = { 0.204, 0.212, 0.212, 1.0 },
    -- Instruction, not instrumentation: a colour used by nothing else on
    -- the stand, so a hint can never be mistaken for a reading.
    hint     = { 0.478, 0.827, 0.918, 1.0 },
}
local TONE = { power = PAL.power, caution = PAL.caution, idle = PAL.dim,
               off = PAL.dim, safe = PAL.safe, danger = PAL.danger,
               lamp = PAL.lamp, terminal = PAL.terminal }

--------------------------------------------------------------------------
-- Localised strings. Every word the renderer draws goes through getText; the
-- words engraved on the dial faces are part of the machine, not the UI.
--------------------------------------------------------------------------
local TXT = {}
local function T(key, arg)
    if arg ~= nil then
        local ok, s = pcall(getText, key, arg)
        return ok and s or (tostring(key) .. " " .. tostring(arg))
    end
    local v = TXT[key]
    if v == nil then
        local ok, s = pcall(getText, key)
        v = (ok and s) or key
        TXT[key] = v
    end
    return v
end

--------------------------------------------------------------------------
-- Player setting. A display preference is per-PLAYER, not per-save, so it lives
-- in a small ini beside the game's own layout.ini rather than in world ModData.
--------------------------------------------------------------------------
local mode = "full"

local function loadMode()
    pcall(function()
        local r = getFileReader(SETTINGS_FILE, true)
        if not r then return end
        local line = r:readLine()
        r:close()
        if not line then return end
        line = line:gsub("%s", "")
        for _, m in ipairs(MODES) do
            if line == "mode=" .. m then mode = m end
        end
    end)
end

local function saveMode()
    pcall(function()
        local w = getFileWriter(SETTINGS_FILE, true, false)
        if not w then return end
        w:write("mode=" .. mode .. "\r\n")
        w:close()
    end)
end

--------------------------------------------------------------------------
local RRHud, hud
local TEX = {}
local function tex(name)
    local t = TEX[name]
    if t == nil then
        local ok, v = pcall(getTexture, TEXPATH .. name .. ".png")
        t = (ok and v) or false
        TEX[name] = t
        if not t then print("[Railroader] HUD: missing texture " .. TEXPATH .. name .. ".png") end
    end
    return t or nil
end

local function defineClass()
    RRHud = ISUIElement:derive("RR_DriveHud")

    function RRHud:new()
        local o = ISUIElement:new(0, 0, 400, 200)   -- real geometry comes from the model
        setmetatable(o, self)
        self.__index = self
        return o
    end

    ----------------------------------------------------------------------
    -- primitives (all coordinates already in screen px)
    ----------------------------------------------------------------------
    function RRHud:fill(x, y, w, h, c, a)
        if w <= 0 or h <= 0 then return end
        self:drawRect(x, y, w, h, a or c[4], c[1], c[2], c[3])
    end

    ----------------------------------------------------------------------
    -- roundedTop: the plate, with the TOP corners rounded and the bottom two
    -- square -- the panel sits flush on the screen edge, so rounding the bottom
    -- would only carve notches out of nothing.
    --
    -- PZ has no rounded-rect and no circle. This walks the corner arc one pixel
    -- row at a time and fades the boundary pixel by its fractional coverage,
    -- which is enough anti-aliasing that the curve does not read as a staircase.
    -- Cost is 2 * radius extra rects, drawn once a frame.
    ----------------------------------------------------------------------
    function RRHud:roundedTop(w, h, r, fillC, edgeC, th)
        r = math.max(0, math.floor(r))
        th = math.max(1, th)
        for iy = 0, r - 1 do
            local dy   = r - iy - 0.5
            local dx   = r - math.sqrt(math.max(0, r * r - dy * dy))
            local xi   = math.floor(dx)
            local frac = dx - xi
            -- body between the two arcs
            self:fill(xi + 1, iy, w - 2 * (xi + 1), 1, fillC)
            -- the boundary pixel, faded by coverage
            self:fill(xi, iy, 1, 1, fillC, fillC[4] * (1 - frac))
            self:fill(w - xi - 1, iy, 1, 1, fillC, fillC[4] * (1 - frac))
            -- the navy arc rides the same curve
            self:fill(xi, iy, th, 1, edgeC, edgeC[4] * (1 - frac * 0.5))
            self:fill(w - xi - th, iy, th, 1, edgeC, edgeC[4] * (1 - frac * 0.5))
        end
        self:fill(0, r, w, h - r, fillC)
        -- straight edges: sides from the arc down, and the bottom
        self:fill(0, r, th, h - r, edgeC)
        self:fill(w - th, r, th, h - r, edgeC)
        self:fill(0, h - th, w, th, edgeC)
    end

    -- Explicit border: drawRectBorder is 1 px and vanishes at large font sets.
    function RRHud:frame(x, y, w, h, th, c)
        th = math.max(1, th)
        self:fill(x, y, w, th, c)
        self:fill(x, y + h - th, w, th, c)
        self:fill(x, y + th, th, h - 2 * th, c)
        self:fill(x + w - th, y + th, th, h - 2 * th, c)
    end

    function RRHud:label(s, x, y, c, font)
        self:drawText(s, x, y, c[1], c[2], c[3], c[4], font or UIFont.Small)
    end

    function RRHud:labelC(s, cx, y, c, font)
        font = font or UIFont.Small
        local w = getTextManager():MeasureStringX(font, s)
        self:label(s, cx - w / 2, y, c, font)
    end

    -- A solid quad from four points. nil texture => flat fill, the trick vanilla
    -- uses in drawLine2. This is what makes rotatable needles possible.
    --
    -- ⚠ THE 8-POINT DrawTexture TAKES **ABSOLUTE SCREEN** COORDINATES. Unlike
    -- DrawText and DrawTextureScaledColor (which drawRect uses), it hands the
    -- points straight to SpriteRenderer.render with NO getAbsoluteX/Y added
    -- (UIElement.java:283-293). Inside one widget, therefore, drawRect is
    -- element-relative and this is not. Passing element coords put every needle
    -- in the top-left corner of the screen. vanilla's own drawLine2 has the same
    -- quirk. We add the offset here so callers can stay element-relative.
    function RRHud:quad(x1,y1, x2,y2, x3,y3, x4,y4, c)
        local ox, oy = self:getAbsoluteX(), self:getAbsoluteY()
        self:drawTextureAllPoint(nil,
            x1+ox, y1+oy, x2+ox, y2+oy, x3+ox, y3+oy, x4+ox, y4+oy,
            c[1], c[2], c[3], c[4])
    end

    -- One needle: a tapered blade with a short counterweight behind the pivot.
    function RRHud:needle(cx, cy, angleDeg, len)
        local a  = math.rad(angleDeg)
        local dx, dy = math.cos(a), math.sin(a)
        local px, py = -dy, dx                     -- perpendicular
        local wb = math.max(1.2, len * 0.075)      -- half width at the pivot
        local wt = math.max(0.6, len * 0.022)      -- half width at the tip
        local tail = len * 0.24

        local bx, by = cx - dx * tail, cy - dy * tail
        local tx, ty = cx + dx * len,  cy + dy * len
        self:quad(bx + px*wb, by + py*wb,  tx + px*wt, ty + py*wt,
                  tx - px*wt, ty - py*wt,  bx - px*wb, by - py*wb, PAL.needle)
        -- counterweight, drawn over the blade root
        local cwx, cwy = cx - dx * tail, cy - dy * tail
        local rx, ry   = cx + dx * (len * 0.06), cy + dy * (len * 0.06)
        self:quad(cwx + px*wb, cwy + py*wb,  rx + px*wb*0.8, ry + py*wb*0.8,
                  rx - px*wb*0.8, ry - py*wb*0.8, cwx - px*wb, cwy - py*wb, PAL.needleCw)
        local hub = math.max(2, len * 0.11)
        self:fill(cx - hub, cy - hub, hub * 2, hub * 2, PAL.hub)
    end

    ----------------------------------------------------------------------
    function RRHud:render()
        local L = self.layout
        if not L or not L.visible then return end
        local k  = L.k
        local D  = RR.HudModel.D
        local cb = L.colorblind
        local function u(v) return v * k end        -- design units -> px

        self:setX(L.x); self:setY(L.y)
        self.width, self.height = L.w, L.h

        -- plate + navy edge
        self:roundedTop(L.w, L.h, u(D.CORNER_R), PAL.plate, PAL.navy,
                        math.max(2, u(D.BORDER)))

        -- Marque, no box. It used to be a framed plate left of the throttle,
        -- which ate 118 units of the control row and left the gauge row with
        -- empty shoulders. As plain text it lives in the dead space above the
        -- two outer dials, and both rows now run the full width of the panel.
        self:label("K&L 800", u(D.MARGIN + 4), u(D.MARQUE_Y), PAL.navyLit)
        do
            local s  = "EMD GP7"
            local sw = getTextManager():MeasureStringX(UIFont.Small, s)
            self:label(s, L.w - u(D.MARGIN + 4) - sw, u(D.MARQUE_Y), PAL.dim)
        end

        ------------------------------------------------------------------
        -- instrument cluster
        ------------------------------------------------------------------
        for _, g in ipairs(L.gauges) do
            local t = tex(g.tex)
            local gx, gy, gs = u(g.x), u(g.y), u(g.size)
            if t then
                self:drawTextureScaled(t, gx, gy, gs, gs, 1, 1, 1, 1)
            else
                self:frame(gx, gy, gs, gs, 2, PAL.boxEdge)     -- asset missing: still legible
            end
            self:needle(gx + gs / 2, gy + gs / 2, g.angle, gs * D.NEEDLE_FRAC)
        end

        -- low-fuel advisory: the one consequence the stand spells out, and only
        -- when it matters (a real cab has a gauge, not a range computer)
        if L.lowFuelMin then
            for _, g in ipairs(L.gauges) do
                if g.id == "fuel" then
                    self:labelC(T("IGUI_RR_HudRange", L.lowFuelMin),
                                u(g.x + g.size / 2), u(g.y + g.size) - u(4), PAL.caution)
                end
            end
        end

        -- durability readout: 0-100 under the rightmost dial (the water face has
        -- no advisory of its own), coloured with the same band as the COND lamp so
        -- the number and the lens never disagree
        if L.condPct then
            local condTone = PAL.cream
            for _, lamp in ipairs(L.lampRow) do
                if lamp.id == "cond" and lamp.banded then
                    condTone = TONE[lamp.tone] or PAL.cream
                end
            end
            for _, g in ipairs(L.gauges) do
                if g.id == "water" then
                    self:labelC(T("IGUI_RR_HudLampCond") .. " " .. L.condPct .. "%",
                                u(g.x + g.size / 2), u(g.y + g.size) - u(4), condTone)
                end
            end
        end

        if L.compact then return end

        ------------------------------------------------------------------
        -- throttle quadrant (doubles as the starter while the diesel is off)
        ------------------------------------------------------------------
        local cy, ch = u(D.CTRL_Y), u(D.CTRL_H)
        local qx, qw = u(D.QUAD_X), u(D.QUAD_W)
        self:fill(qx, cy, qw, ch, PAL.box)
        self:frame(qx, cy, qw, ch, math.max(1, u(1)), PAL.cellEdge)
        local q = L.quad
        self:label(T(q.labelKey), qx + u(6), cy + u(D.BOX_LABEL_Y), PAL.dim)

        local nw, ng = u(D.NOTCH_W), u(D.NOTCH_GAP)
        local ny, nh = cy + u(D.NOTCH_Y), u(D.NOTCH_H)
        for i = 1, 8 do
            local bx = qx + u(8) + (i - 1) * (nw + ng)
            local lit, ghosted
            if q.progress then
                lit = ((i - 0.5) / 8) <= q.progress
                ghosted = false
            else
                lit = i <= q.notch
                ghosted = (q.ghost > 0) and lit and (i > q.ghost)
            end
            local c = (lit and not ghosted) and PAL.power or (lit and PAL.powerDim or PAL.cell)
            self:fill(bx, ny, nw, nh, c)
            self:frame(bx, ny, nw, nh, 1, PAL.cellEdge)
            -- Numerals live INSIDE the block: engraved on the quadrant, clear of
            -- the frame, and they invert on a lit notch so the ramp reads at a glance.
            self:labelC(tostring(i), bx + nw / 2, ny + (nh - u(D.TEXT_H)) / 2,
                        (lit and not ghosted) and PAL.dark or PAL.dim)
        end
        do
            -- The quadrant's right-hand slot is the panel's teaching channel: when a
            -- hint targets it, the hint REPLACES the readout and is drawn in the hint
            -- colour, so instruction never reads as an instrument value.
            local s, tone
            if L.hint and L.hint.where == "quad" then
                s, tone = T(L.hint.key), PAL.hint
            else
                s, tone = T(q.rightKey, q.rightArg), (TONE[q.tone] or PAL.dim)
                if cb and q.tone == "caution" then s = "! " .. s end
            end
            local w = getTextManager():MeasureStringX(UIFont.Small, s)
            self:label(s, qx + qw - u(8) - w, cy + u(D.BOX_LABEL_Y), tone)
        end

        ------------------------------------------------------------------
        -- reverser: three cells, the selected one filled AND notch-marked so the
        -- position survives desaturation
        ------------------------------------------------------------------
        local rx, rw = qx + qw + u(D.GAP), u(D.REV_W)
        self:fill(rx, cy, rw, ch, PAL.box)
        self:frame(rx, cy, rw, ch, math.max(1, u(1)), PAL.cellEdge)
        if L.hint and L.hint.where == "rev" then
            self:label(T(L.hint.key), rx + u(6), cy + u(D.BOX_LABEL_Y), PAL.hint)
        else
            self:label(T("IGUI_RR_HudReverser"), rx + u(6), cy + u(D.BOX_LABEL_Y), PAL.dim)
        end
        local cells = { { "F", "IGUI_RR_HudRevF", PAL.safe },
                        { "N", "IGUI_RR_HudRevN", PAL.dim  },
                        { "R", "IGUI_RR_HudRevR", PAL.caution } }
        for i = 1, 3 do
            local c  = cells[i]
            local bx = rx + u(8) + (i - 1) * u(D.REV_STEP)
            local cw = u(D.REV_CELL)
            local on = (L.rev == c[1])
            self:fill(bx, ny, cw, nh, on and c[3] or PAL.cell)
            self:frame(bx, ny, cw, nh, 1, PAL.cellEdge)
            if on then self:fill(bx, ny - math.max(2, u(3)), cw, math.max(2, u(2)), PAL.cream) end
            self:labelC(T(c[2]), bx + cw / 2, ny + (nh - u(D.TEXT_H)) / 2,
                        on and PAL.dark or PAL.dim)
        end

        ------------------------------------------------------------------
        -- indicator lamps
        ------------------------------------------------------------------
        local lx = rx + rw + u(D.GAP)
        local lw = L.w - lx - u(D.MARGIN)
        self:fill(lx, cy, lw, ch, PAL.box)
        self:frame(lx, cy, lw, ch, math.max(1, u(1)), PAL.cellEdge)
        -- No box header here: the lamps caption themselves, and the space buys
        -- room for five of them. Label goes UNDER the lens (see RR_HudModel.D).
        local lens = tex("rr_g_lamp")
        local ld   = u(D.LAMP_D)
        local n    = math.max(1, #L.lampRow)
        -- Cell width is MEASURED: "HEAD" and "ПРОЖ" differ, and a baked step is
        -- exactly how the lenses ended up printed over their own labels.
        local widest = ld
        for _, lamp in ipairs(L.lampRow) do
            widest = math.max(widest,
                getTextManager():MeasureStringX(UIFont.Small, T(lamp.labelKey)))
        end
        local cell = math.min(widest + u(D.LAMP_CELL_GAP), (lw - u(8)) / n)
        local lyy  = cy + u(D.LAMP_Y)
        for i, lamp in ipairs(L.lampRow) do
            local cx = lx + u(4) + (i - 1) * cell + cell / 2
            local c  = lamp.on and (TONE[lamp.tone] or PAL.lamp) or PAL.lampOff
            if lens then
                self:drawTextureScaled(lens, cx - ld / 2, lyy, ld, ld, 1, c[1], c[2], c[3])
            else
                self:fill(cx - ld / 2, lyy, ld, ld, c)
            end
            -- Second channel: a banded lamp that is not green gets a ring, so the
            -- warning survives desaturation and colourblind play. COLOURBLIND
            -- ONLY (SP v1.0.2): it used to be drawn always, and a square box
            -- around a round lens reads as a UI glitch on a panel whose every
            -- other part is a machined shape -- colour is the primary channel
            -- now that the danger/terminal tones render correctly.
            if cb and lamp.banded and lamp.tone ~= "safe" then
                self:frame(cx - ld / 2 - u(2), lyy - u(2), ld + u(4), ld + u(4),
                           math.max(1, u(1)), c)
            elseif cb and not lamp.on then
                self:frame(cx - ld / 2, lyy, ld, ld, 1, PAL.dim)
            end
            self:labelC(T(lamp.labelKey), cx, lyy + ld + u(D.LAMP_LABEL_GAP),
                        lamp.on and PAL.cream or PAL.dim)
        end

        ------------------------------------------------------------------
        -- alarm strip -- reserved height, so nothing above it ever moves
        ------------------------------------------------------------------
        if L.alarm then
            local c = (L.alarm.level == "terminal") and PAL.terminal or PAL.danger
            local ay, ah = u(D.ALARM_Y), u(D.ALARM_H)
            self:fill(u(D.BORDER), ay, L.w - 2 * u(D.BORDER), ah, c, 0.18)
            local s = T(L.alarm.key)
            if cb then s = "! " .. s end
            self:label(s, u(D.MARGIN), ay + (ah - u(D.TEXT_H)) / 2, c)
        end
    end
end

--------------------------------------------------------------------------
-- Gather the model's inputs. Everything engine-facing happens here and nowhere
-- else; the model only ever sees plain numbers and strings.
--------------------------------------------------------------------------
local function gather()
    local Ride   = RR and RR.Ride
    local Drive  = RR and RR.Drive
    local Engine = RR and RR.Engine
    local Lights = RR and RR.Lights
    local e = Ride and Ride.current
    if not e or not Drive then return nil end

    local eng = e.engine
    local EC  = (Engine and Engine.C) or {}

    local tractionMult = 1
    if Engine and Engine.tractionMult and eng then
        pcall(function() tractionMult = Engine.tractionMult(eng.condition) or 1 end)
    end

    return {
        speed        = (e.drive and e.drive.v) or 0,
        units        = "mph",
        reverser     = Drive.reverserLabel(e.reverser),
        throttle     = e.throttle or 0,
        notchEff     = e.drive and e.drive.notchEff,
        brake        = (e.drive and e.drive.brakeLevel) or 0,
        engine       = eng,
        tractionMult = tractionMult,
        derailed     = e.derailed == true,
        licensed     = (Ride == nil) or (Ride.isLicensed == nil) or Ride.isLicensed(e),
        lights       = Lights and Lights.headLabel(e.lightState, eng) or "OFF",
        cabLight     = (e.lightState and e.lightState.cab) == true,
        waterC       = e.cab and e.cab.waterC,
        stopped      = math.abs((e.drive and e.drive.v) or 0) <= 0.05,
        hintsDone    = RR.HudHints and RR.HudHints.doneSet() or nil,
        fuelCap      = EC.FUEL_CAP,
        idleBurn     = EC.IDLE_BURN, loadBurn = EC.LOAD_BURN,
        primeFull    = EC.PRIME_TIME, crankFull = EC.CRANK_TIME, warmFull = EC.WARMUP_TIME,
        immobilizeAt = EC.IMMOBILIZE_AT,
        -- thresholds the banded lamps colour themselves against
        crankMin     = EC.CRANK_MIN, tractionFull = EC.TRACTION_FULL_AT,
        stallAt      = EC.STALL_AT,
        lightCutoff  = (Lights and Lights.C and Lights.C.CUTOFF) or 0.44,
    }
end

--------------------------------------------------------------------------
-- Lay out once per tick, not once per render: render() can run more often than
-- the sim advances, and there is no reason to redo the arithmetic per frame.
--------------------------------------------------------------------------
local function tick()
    if not hud then return end
    hud.layout = nil

    -- Asleep in the cab (RR_Sleep): the screen is faded and vanilla's sleeping UI
    -- owns it. A control stand floating over that reads as a bug.
    if RR.Sleep and RR.Sleep.isAsleep() then return end

    if RR.HudHints then RR.HudHints.observe(RR.Ride and RR.Ride.current) end

    local input = gather()
    if not input then return end

    local core = getCore()
    local n = 0
    local metrics = {
        S       = getTextManager():getFontHeight(UIFont.Small),
        screenL = getPlayerScreenLeft(n),  screenT = getPlayerScreenTop(n),
        screenW = getPlayerScreenWidth(n), screenH = getPlayerScreenHeight(n),
    }

    local cb = false
    pcall(function() cb = core:getOptionColorblindPatterns() == true end)

    hud.layout = RR.HudModel.build(input, metrics, { mode = mode, colorblind = cb })
end

--------------------------------------------------------------------------
-- Mode. NOT a keybind: V is the cab radial menu (Task 1.O, RR_CabMenu claims
-- both the vehicle and animal radial bindings), so the toggle is a slice in that
-- radial -- which is where a "give me a result" control belongs anyway.
--------------------------------------------------------------------------
local function setMode(m)
    for _, v in ipairs(MODES) do
        if v == m then mode = m; saveMode(); return true end
    end
    return false
end

local function cycleMode()
    local i = 1
    for n, m in ipairs(MODES) do if m == mode then i = n end end
    setMode(MODES[(i % #MODES) + 1])
    return mode
end

local function modeKey(m)
    return (m == "full" and "IGUI_RR_HudModeFull")
        or (m == "compact" and "IGUI_RR_HudModeCompact")
        or "IGUI_RR_HudModeOff"
end

--------------------------------------------------------------------------
local function createHud()
    if hud then return end
    if not ISUIElement then
        print("[Railroader] drive HUD: ISUIElement still missing; HUD not created.")
        return
    end
    local ok, err = pcall(function()
        if not RRHud then defineClass() end
        loadMode()
        hud = RRHud:new()
        hud:initialise()
        hud:addToUIManager()
        hud:setVisible(true)
    end)
    if ok then
        RR = RR or {}
        RR.DriveHud = hud
        print("[Railroader] control stand ready (bottom-centre; mode via RR.HudMode.set).")
    else
        print("[Railroader] control stand failed to init: " .. tostring(err))
        hud = nil
    end
end

Events.OnGameStart.Add(createHud)
Events.OnTick.Add(tick)

RR = RR or {}
RR.createDriveHud = createHud
-- console-only since the HUD slice left the cab radial (owner, 2026-07-28):
-- RR.HudMode.set("full"|"compact"|"off") / .cycle()
RR.HudMode = { get = function() return mode end, set = setMode,
               cycle = cycleMode, key = modeKey, list = MODES }
