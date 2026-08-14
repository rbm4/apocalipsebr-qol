--***********************************************************************
-- Railroader / RR_HudModel  -- PURE layout model for the drive HUD (Task 2.D)
--
-- The HUD is an EMD GP7 control stand: six round gauges, a notched throttle
-- quadrant, an F-N-R reverser and a lamp bar, centred and flush with the bottom
-- of the screen. Everything it DECIDES lives here; client/Railroader/RR_DriveHud.lua
-- only draws what this returns.
--
-- ENGINE-FREE by construction -- no getCore(), no getTextManager(), no UIFont --
-- so the whole thing runs in tests/run_tests.lua under a bare Lua interpreter.
--
-- Design record: docs/HUD_DESIGN.md · docs/HUD_STYLE.md
-- Instrument faces: tools/make_gauges.py -> 42/media/ui/Railroader/rr_g_*.png
--
-- GEOMETRY MODEL. The stand is authored once, in "design units" -- the layout at
-- PZ's small-font rung (Small = 19 px), where the panel is 760 x 208. Everything
-- else is that layout times a single scale `k`. So there is one place to change a
-- position, and the panel tracks the player's Font Size option without a second
-- set of numbers to keep in sync.
--
-- ANCHOR. Copied verbatim from vanilla's own vehicle dashboard
-- (ISVehicleDashboard.lua:432-433): centred horizontally, bottom edge FLUSH with
-- the screen. It therefore covers the back and belt equipment slots exactly as a
-- car's dashboard does -- deliberate, and the owner's requirement.
--***********************************************************************

local HudModel = {}

--------------------------------------------------------------------------
-- The stand, in design units. Mirrors tools/make_gauges.py -- if a dial size
-- changes there it changes here.
--------------------------------------------------------------------------
-- NOTE on the vertical numbers: PZ's SMALLEST font is 19 px at the rung these
-- design units assume (Small = 19 => k = 1), so every text row here is 19 tall.
-- The first draft was sketched with 11 px labels and the words would have burst
-- out of their boxes in game -- there is no smaller face to fall back to.
local D = {
    -- WIDTH IS DERIVED, not chosen. The control row needs
    --   QUAD 300 + GAP + REVERSER 126 + GAP + INDICATORS 238 = 684,
    -- so the panel is 684 + 2 x MARGIN, and the gauge gap is then set so the six
    -- faces span that same 684. Both rows therefore run edge to edge and the
    -- empty shoulders the first cut had above the cluster are gone.
    -- (The builder's plate that used to sit left of the throttle is gone with
    -- them -- the marque is now plain text in the panel's top corners.)
    W = 704, H = 226, H_COMPACT = 144,
    BORDER = 3,
    CORNER_R = 10,               -- top corners only; the panel sits on the screen edge
    TEXT_H = 19,                 -- getFontHeight(UIFont.Small) at k = 1
    MARGIN = 10,

    MARQUE_Y = 5,                -- "K&L 800" / "EMD GP7", in the corners
    GAUGE_Y = 8, GAUGE_H = 128, GAUGE_GAP = 19,
    CTRL_Y = 142, CTRL_H = 54,
    ALARM_Y = 200, ALARM_H = 22,

    QUAD_X = 10, QUAD_W = 300,
    REV_W = 126, REV_CELL = 34, REV_STEP = 38,
    PAD = 8, GAP = 10,

    BOX_LABEL_Y = 3,             -- inside a control box
    NOTCH_W = 32, NOTCH_GAP = 3, NOTCH_Y = 25, NOTCH_H = 26,
    NEEDLE_FRAC = 0.40,          -- needle length as a fraction of the dial
    -- Lamp labels sit UNDER their lens, not beside it. Beside, five labelled
    -- lenses need ~353 units and the box is 238; under, a cell is the label's
    -- width (~46) and five fit in 230. It also matches how a real switch panel
    -- is captioned. The INDICATORS box therefore has no header of its own --
    -- the lamps caption themselves, and the header was the least useful text
    -- on the stand.
    LAMP_D = 18, LAMP_Y = 6, LAMP_LABEL_GAP = 2, LAMP_CELL_GAP = 6,
}
HudModel.D = D

-- The six faces, left to right. `size` is the design size; the PNG is 2x that.
local GAUGES = {
    { id = "amp",   tex = "rr_g_amp",   size = 92  },
    { id = "air",   tex = "rr_g_air",   size = 92  },
    { id = "speed", tex = "rr_g_speed", size = 128 },
    { id = "rpm",   tex = "rr_g_rpm",   size = 92  },
    { id = "fuel",  tex = "rr_g_fuel",  size = 92  },
    { id = "water", tex = "rr_g_water", size = 92  },
}
HudModel.GAUGES = GAUGES

local C = {
    DESIGN_S    = 19,      -- the small-font height the design units assume
    ARC0        = 150,     -- needle sweep start, degrees (0 = east, clockwise)
    ARC1        = 390,
    SPEED_MAX   = 80,      -- mph, the face's full scale
    AMP_MAX     = 1200,
    AIR_MAX     = 90,      -- psi
    RPM_IDLE    = 275,     -- a GP7's 567 at idle
    RPM_RUN8    = 835,
    RPM_MAX     = 900,     -- the face's full scale
    WATER_MAX_F = 240,
    LOW_FUEL    = 0.25,    -- below this the fuel dial gets an advisory readout
    MAX_W_FRAC  = 0.86,    -- never wider than this much of the screen
    MAX_H_FRAC  = 0.30,    -- nor taller than this much of it
    MPH         = 2.2369363,
    KMH         = 3.6,
}
HudModel.C = C

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi else return x end
end
local function round(x) return math.floor(x + 0.5) end

--------------------------------------------------------------------------
-- scale(S, screenW, screenH, compact) -> k
--
-- k follows the player's Font Size so the stand grows with the rest of the UI,
-- then is CLAMPED so it can never outgrow the screen. That clamp replaces the
-- old text HUD's auto-Compact height rule: a gauge cluster has no rows to drop,
-- so it shrinks instead of reflowing.
--------------------------------------------------------------------------
function HudModel.scale(S, screenW, screenH, compact)
    local k = (S or C.DESIGN_S) / C.DESIGN_S
    local h = compact and D.H_COMPACT or D.H
    if screenW and screenW > 0 then k = math.min(k, screenW * C.MAX_W_FRAC / D.W) end
    if screenH and screenH > 0 then k = math.min(k, screenH * C.MAX_H_FRAC / h) end
    if k < 0.5 then k = 0.5 end
    return k
end

--------------------------------------------------------------------------
-- anchor(w, h, screenL, screenT, screenW, screenH) -> x, y
-- Vanilla's vehicle-dashboard placement, verbatim.
--------------------------------------------------------------------------
function HudModel.anchor(w, h, screenL, screenT, screenW, screenH)
    screenL = screenL or 0; screenT = screenT or 0
    screenW = screenW or 1920; screenH = screenH or 1080
    return round(screenL + (screenW - w) / 2), round(screenT + screenH - h)
end

--------------------------------------------------------------------------
-- Gauge readings. Every one is a 0..1 fraction of its printed face, derived
-- from a value the sim already computes -- there are no decorative dials.
--------------------------------------------------------------------------
function HudModel.speedValue(v, units)
    return math.abs(v or 0) * ((units == "kmh") and C.KMH or C.MPH)
end

-- Load meter. Reads the effective notch through the traction multiplier AND the
-- reverser, because current only reaches the traction motors when the reverser is
-- thrown. Two things fall out of that, both of them true to the machine:
--   * an immobilized loco sits at zero with the throttle wide open;
--   * so does a loco whose reverser is still centred -- which is the first hint a
--     new driver gets that notching up is not going to move them.
-- Missing the reverser here was a lie: the panel showed 60% load on a locomotive
-- making no power at all, and hid the very problem the driver was looking at.
function HudModel.ampFrac(notchEff, tractionMult, running, reverser)
    if not running then return 0 end
    if reverser == "N" or reverser == 0 then return 0 end
    return clamp((notchEff or 0) / 8, 0, 1) * clamp(tractionMult or 1, 0, 1)
end

function HudModel.rpmFrac(notchEff, running)
    if not running then return 0 end
    local rpm = C.RPM_IDLE + (C.RPM_RUN8 - C.RPM_IDLE) * clamp((notchEff or 0) / 8, 0, 1)
    return clamp(rpm / C.RPM_MAX, 0, 1)
end

function HudModel.waterFrac(waterC)
    if waterC == nil then return 0 end
    return clamp((waterC * 9 / 5 + 32) / C.WATER_MAX_F, 0, 1)
end

-- fuelMinutes: the one consequence the stand still spells out, and only when it
-- matters. A real cab has a fuel gauge and no range computer, so this appears
-- under the dial ONLY below LOW_FUEL -- authentic when things are fine, helpful
-- when they are not.
function HudModel.fuelMinutes(fuel, notch, idleBurn, loadBurn)
    local burn = (idleBurn or 0.03) + (loadBurn or 0.20) * clamp((notch or 0) / 8, 0, 1)
    if burn <= 0 then return nil end
    return math.floor((fuel or 0) / burn / 60 + 0.5)
end

--------------------------------------------------------------------------
-- needleAngle(frac) -> degrees
--------------------------------------------------------------------------
function HudModel.needleAngle(frac)
    return C.ARC0 + (C.ARC1 - C.ARC0) * clamp(frac or 0, 0, 1)
end

--------------------------------------------------------------------------
-- quadrant(input) -- the throttle quadrant, which DOUBLES as the starter while
-- the diesel is not running. Same eight blocks either way, so the panel never
-- changes size during a start sequence -- exactly when a resizing panel would be
-- worst, because that is when the driver is staring at it holding W.
--------------------------------------------------------------------------
function HudModel.quadrant(input)
    local eng   = input.engine
    local phase = (eng and eng.phase) or "off"

    if input.derailed then
        return { labelKey = "IGUI_RR_HudThrottle", notch = 0, ghost = 0,
                 rightKey = "IGUI_RR_HudDead", tone = "off" }
    end

    if phase == "off" then
        -- The only place the HUD teaches a control, and the one a new driver
        -- needs: on a dead engine W is the starter, not the throttle.
        return { labelKey = "IGUI_RR_HudStarter", notch = 0, ghost = 0,
                 progress = 0, rightKey = "IGUI_RR_HudStart", tone = "idle" }
    end

    local prog, key
    if phase == "priming" then
        prog = clamp((eng.primeTime or 0) / (input.primeFull or 1.5), 0, 1)
        key = "IGUI_RR_HudPrime"
    elseif phase == "cranking" then
        prog = clamp((eng.crankTime or 0) / (input.crankFull or 1.6), 0, 1)
        key = "IGUI_RR_HudCrank"
    elseif phase == "warmup" then
        prog = clamp((eng.warmupTime or 0) / (input.warmFull or 4.0), 0, 1)
        key = "IGUI_RR_HudWarming"
    end
    if prog then
        return { labelKey = "IGUI_RR_HudStarter", notch = 0, ghost = 0,
                 progress = prog, rightKey = key, tone = "caution" }
    end

    -- Running: the real throttle. `notch` is what the driver commanded; `ghost`
    -- is how far the 2 notch/s ramp has actually got, so the lag is visible
    -- instead of the panel claiming power the loco is not making yet.
    local notch = clamp(math.floor((input.throttle or 0) + 0.5), 0, 8)
    local eff   = clamp(input.notchEff or notch, 0, 8)
    local ghost = (eff < notch) and math.floor(eff + 0.5) or 0
    if notch == 0 then
        return { labelKey = "IGUI_RR_HudThrottle", notch = 0, ghost = 0,
                 rightKey = "IGUI_RR_HudIdle", tone = "idle" }
    end
    return { labelKey = "IGUI_RR_HudThrottle", notch = notch, ghost = ghost,
             rightKey = "IGUI_RR_HudRun", rightArg = notch, tone = "power" }
end

--------------------------------------------------------------------------
-- Indicator lamps. Two kinds share the row, deliberately:
--
--   * STATUS (head / cab / gen) -- lit or dark, a switch position.
--   * BANDED (batt / cond) -- always lit, GREEN / AMBER / RED by threshold.
--
-- The banded pair is a UX decision over prototype fidelity (owner, 2026-07-28).
-- A real GP7 has neither a battery lamp nor anything for "condition" -- it has
-- WHEEL SLIP, GROUND RELAY, PCS OPEN and a hot-engine alarm. But both values
-- gate the machine hard and were invisible on the stand's first cut, which is
-- the very defect the HUD rework set out to fix:
--     battery  < CUTOFF   the lights die · < CRANK_MIN the starter will not turn
--     condition < 0.50    tractive effort tapers · < STALL_AT it can stall on its own
-- A lamp that silently changes colour costs no space and states all of it.
--------------------------------------------------------------------------
local function band(v, amberAt, redAt)
    if v == nil then return "off" end
    if v < redAt then return "danger" end
    if v < amberAt then return "caution" end
    return "safe"
end

function HudModel.lamps(input)
    local eng     = input.engine
    local running = eng and (eng.phase == "running" or eng.phase == "warmup")
    local head    = input.lights or "OFF"
    local out = {
        { id = "head", labelKey = "IGUI_RR_HudLampHead", tone = "lamp",
          on = (head == "DIM" or head == "BRIGHT") },
        { id = "cab",  labelKey = "IGUI_RR_HudLampCab",  tone = "lamp",
          on = input.cabLight == true },
        { id = "gen",  labelKey = "IGUI_RR_HudLampGen",  tone = "safe",
          on = running == true },
    }
    if eng then
        out[#out+1] = {
            id = "batt", labelKey = "IGUI_RR_HudLampBatt", on = true, banded = true,
            tone = band(eng.battery, input.lightCutoff or 0.44, input.crankMin or 0.15),
        }
        out[#out+1] = {
            id = "cond", labelKey = "IGUI_RR_HudLampCond", on = true, banded = true,
            tone = band(eng.condition, input.tractionFull or 0.50, input.stallAt or 0.25),
        }
    end
    return out
end

--------------------------------------------------------------------------
-- hint(input) -> { id, key, where } | nil          the teaching layer
--
-- Names the NEXT action, and names it IN THE BOX where that action lives, so the
-- hint points at the control instead of describing it. `where` is "quad" (the
-- throttle/starter readout) or "rev" (the reverser box header).
--
-- Why this exists: the diesel starts only with the reverser CENTRED, so every
-- first-time driver arrives at a running engine, notches up, and goes nowhere.
-- The chain walks them out of it: start -> throw the reverser -> open the
-- throttle -> (later) shut down.
--
-- `input.hintsDone` is the set of hints the player has already performed
-- (RR_HudHints, backed by save ModData). A hint shown forever is nagging, not
-- teaching -- each one retires the first time its action is done.
--------------------------------------------------------------------------
function HudModel.hint(input)
    local done = input.hintsDone or {}
    if input.derailed or input.licensed == false then return nil end

    local eng   = input.engine
    local phase = (eng and eng.phase) or "off"

    if phase == "off" then
        if done.start then return nil end
        return { id = "start", key = "IGUI_RR_HintStart", where = "quad" }
    end
    -- mid-sequence the quadrant is already showing PRIME / CRANK progress
    if phase == "priming" or phase == "cranking" then return nil end

    if (input.reverser or "N") == "N" then
        if done.reverser then return nil end
        return { id = "reverser", key = "IGUI_RR_HintReverser", where = "rev" }
    end

    if (input.throttle or 0) == 0 then
        if not done.throttle then
            return { id = "throttle", key = "IGUI_RR_HintThrottle", where = "quad" }
        end
        -- Lowest priority, and only once they have actually driven: shutting down is
        -- never urgent, so this hint waits for a quiet moment and never competes.
        if not done.stop and input.stopped then
            return { id = "stop", key = "IGUI_RR_HintStop", where = "quad" }
        end
    end
    return nil
end

--------------------------------------------------------------------------
-- Alarms, most severe first. The strip carries exactly ONE line -- that is what
-- keeps the panel's height fixed, and a derailed loco does not also need to be
-- told its driver is unlicensed.
--------------------------------------------------------------------------
function HudModel.alarm(input)
    if input.derailed then
        return { key = "IGUI_RR_Derailed", level = "terminal" }
    end
    local eng = input.engine
    if eng and eng.condition and eng.condition <= (input.immobilizeAt or 0) then
        return { key = "IGUI_RR_OutOfOrder", level = "danger" }
    end
    if input.licensed == false then
        return { key = "IGUI_RR_NoLicense", level = "danger" }
    end
    return nil
end

--------------------------------------------------------------------------
-- build(input, metrics, opts) -> layout
--
-- metrics = { S, screenL, screenT, screenW, screenH }
-- opts    = { mode = "full"|"compact"|"off" }
--
-- Returned coordinates are SCREEN pixels for the panel box, and DESIGN units for
-- everything inside it -- the renderer multiplies by `k`. Keeping the interior in
-- design units is what makes the layout assertable in tests without a font.
--------------------------------------------------------------------------
function HudModel.build(input, metrics, opts)
    input = input or {}; metrics = metrics or {}; opts = opts or {}
    local mode = opts.mode or "full"
    if mode == "off" then return { visible = false, mode = "off" } end

    local compact = (mode == "compact")
    local k = HudModel.scale(metrics.S, metrics.screenW, metrics.screenH, compact)
    local w = round(D.W * k)
    local h = round((compact and D.H_COMPACT or D.H) * k)
    local x, y = HudModel.anchor(w, h, metrics.screenL, metrics.screenT,
                                 metrics.screenW, metrics.screenH)

    local eng     = input.engine
    local running = eng and (eng.phase == "running" or eng.phase == "warmup") or false
    local notchEff = input.notchEff or input.throttle or 0
    local fuelCap  = input.fuelCap or 600
    local fuelFrac = clamp((eng and eng.fuel or 0) / fuelCap, 0, 1)

    local reading = {
        speed = clamp(HudModel.speedValue(input.speed, input.units) / C.SPEED_MAX, 0, 1),
        amp   = HudModel.ampFrac(notchEff, input.tractionMult, running,
                                 input.reverser),
        air   = clamp(input.brake or 0, 0, 1),
        rpm   = HudModel.rpmFrac(notchEff, running),
        fuel  = fuelFrac,
        water = HudModel.waterFrac(input.waterC),
    }

    -- lay the faces out centred in the gauge band, in design units
    local total = -D.GAUGE_GAP
    for _, g in ipairs(GAUGES) do total = total + g.size + D.GAUGE_GAP end
    local gx = (D.W - total) / 2
    local gauges = {}
    for _, g in ipairs(GAUGES) do
        gauges[#gauges+1] = {
            id = g.id, tex = g.tex, size = g.size,
            x = round(gx), y = round(D.GAUGE_Y + (D.GAUGE_H - g.size) / 2),
            frac = reading[g.id] or 0,
            angle = HudModel.needleAngle(reading[g.id] or 0),
        }
        gx = gx + g.size + D.GAUGE_GAP
    end

    -- the one advisory the stand still spells out (see fuelMinutes)
    local lowFuelMin
    if fuelFrac < C.LOW_FUEL and eng then
        lowFuelMin = HudModel.fuelMinutes(eng.fuel, input.throttle,
                                          input.idleBurn, input.loadBurn)
    end

    -- Durability readout: the banded COND lamp tells health by colour, but the
    -- owner wanted the NUMBER -- current condition as 0-100 (v1.0.3).
    local condPct
    if eng and eng.condition ~= nil then
        condPct = round(clamp(eng.condition, 0, 1) * 100)
    end

    return {
        visible = true, mode = mode, compact = compact,
        k = k, x = x, y = y, w = w, h = h,
        gauges  = gauges,
        quad    = HudModel.quadrant(input),
        rev     = input.reverser or "N",
        lampRow = HudModel.lamps(input),
        alarm   = HudModel.alarm(input),
        hint    = HudModel.hint(input),
        lowFuelMin = lowFuelMin,
        condPct = condPct,
        colorblind = opts.colorblind == true,
    }
end

RR = RR or {}
RR.HudModel = HudModel

return HudModel
