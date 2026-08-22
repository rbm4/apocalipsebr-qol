--***********************************************************************
-- Railroader / RR_CabMenu  -- the cab's radial menu on the vehicle-radial key (V)
--
-- The driving controls are keys (they are held rituals -- crank, brake, horn), but
-- the things you do ONCE while parked belong where a driver already looks for them:
-- the radial menu a car opens on V. Same widget, same textures, same open/close
-- sound -- getPlayerRadialMenu(playerNum) is public and vanilla's own vehicle menu is
-- built from nothing but addSlice (ISVehicleMenu.showRadialMenu).
--
-- WHY WE HAVE TO TAKE THE KEY (and why this also fixes a bug):
-- V is bound TWICE in vanilla (shared/keyBinding.lua) -- "VehicleRadialMenu" and
-- "AnimalRadialMenu" are both KEY_V -- and ISUIHandler.onKeyStartPressed walks both.
-- We are not a vehicle (getVehicle() is nil for an IsoAnimal loco), so the press fell
-- through to the ANIMAL branch, which picks getUseableAnimal() -- and within two tiles
-- of the cab that is our rr_loco or one of its rr_collider segments. Result, before
-- this file: pressing V at the locomotive opened the livestock radial on it -- "Animal
-- Info", "Pet", and with a weapon in hand "Kill Animal". RR_AnimalMenuFilter only
-- wraps AnimalContextMenu.doMenu (the right-click path); the radial goes nowhere near
-- it. So we intercept the key for BOTH bindings: in the cab it opens our menu, and
-- anywhere our own animals are the useable one it opens nothing at all.
--
-- Reassigning ISUIHandler.onKeyStartPressed would NOT work: Events.*.Add captured the
-- function BY VALUE at OnGameStart, so the event keeps calling the original. We
-- remove the vanilla handlers and register guarded wrappers instead -- the same
-- proven trick RR_Ride uses for the "walk here" key. Patched on OnGameStart, which
-- runs after vanilla's own registration.
--
-- We deliberately do NOT put engine start/stop in here: those are HOLD-W / HOLD-S
-- sequences with sound and failure rolls, and a one-click slice would throw that away.
--***********************************************************************

local CabMenu = {}

local TEX_SLEEP     = "media/ui/vehicles/vehicle_sleep.png"
local TEX_LIGHTS_ON = "media/ui/vehicles/vehicle_lightsON.png"
local TEX_LIGHTS_OFF= "media/ui/vehicles/vehicle_lightsOFF.png"
local TEX_EXIT      = "media/ui/vehicles/vehicle_exit.png"
local TEX_ENG_ON    = "media/ui/vehicles/vehicle_ignitionON.png"
local TEX_ENG_OFF   = "media/ui/vehicles/vehicle_ignitionOFF.png"

local OWN_PREFIX = "rr_"    -- our animal types: rr_loco (visual), rr_collider (segments)

--------------------------------------------------------------------------
-- txt(key, fallback): getText returns the KEY itself when a translation is missing,
-- so every label falls back to readable English rather than printing "IGUI_RR_...".
--------------------------------------------------------------------------
local function txt(key, fallback)
    local s = key
    pcall(function() s = getText(key) end)
    if not s or s == "" or s == key then return fallback or key end
    return s
end

local function isOurAnimal(a)
    if not a then return false end
    local t
    pcall(function() t = a:getAnimalType() end)
    return t ~= nil and string.sub(t, 1, #OWN_PREFIX) == OWN_PREFIX
end

--------------------------------------------------------------------------
-- radialVisible(): is the shared radial menu on screen for player 0? RR_Ride asks
-- this too -- while the menu is up, the held-RMB "look at the cursor" must not swing
-- the driver around as the player picks a slice.
--------------------------------------------------------------------------
function CabMenu.radialVisible()
    local vis = false
    pcall(function()
        local p = getPlayer()
        local m = p and getPlayerRadialMenu(p:getPlayerNum())
        vis = (m ~= nil) and m:isReallyVisible()
    end)
    return vis
end

--------------------------------------------------------------------------
-- addSleepSlice: the reason for this file. Three shapes, all vanilla idiom:
--   * refused with a reason -> a DEAD slice whose text says why (that is exactly how
--     the car radial explains "Not tired enough" / "Not safe");
--   * allowed, with a caveat -> the live slice with the warning on a second line
--     (vanilla puts multi-line text in slices too);
--   * sleep switched off server-side / no cab -> no slice at all.
--------------------------------------------------------------------------
local function addSleepSlice(menu, e)
    local Sleep = RR and RR.Sleep
    if not Sleep then return end
    local ok, reason = Sleep.check(e)
    if not ok then
        if reason then
            -- A DEAD slice (nil command) is vanilla's idiom, but a radial only shows a
            -- slice's text while the cursor is ON it -- so a click landed on silence and
            -- read as "the sleep entry is broken". Ours stays CLICKABLE and answers with
            -- the same red halo every other refusal in this cab uses, plus a console line
            -- naming the gate (that is how a tester reports it).
            menu:addSlice(txt(reason, "You can't sleep now"), getTexture(TEX_SLEEP),
                          CabMenu.onSleepRefused, reason, e)
        end
        return
    end
    local label = txt("IGUI_RR_SleepInCab", "Sleep in the cab")
    for _, w in ipairs(Sleep.warnings(e)) do
        label = label .. "\n" .. txt(w, "")
    end
    menu:addSlice(label, getTexture(TEX_SLEEP), CabMenu.onSleep, e)
end

function CabMenu.onSleep(e)
    if RR.Sleep then RR.Sleep.confirm(e) end
end

--------------------------------------------------------------------------
-- onSleepRefused: the click on a refusal. Says WHY in the player's channel (red halo)
-- and dumps the numbers behind the verdict to the log, so "the sleep entry does
-- nothing" is answerable from console.txt alone. Every gate here is vanilla's own --
-- a fresh character genuinely cannot sleep (fatigue <= 0.3, and hoursSurvived minus
-- lastHourSleeped is 0 on a new save, which is vanilla's anti-pill-exploit rule).
--------------------------------------------------------------------------
function CabMenu.onSleepRefused(reason, e)
    local p = getPlayer()
    if p then
        pcall(function() HaloTextHelper.addBadText(p, txt(reason, "You can't sleep now")) end)
    end
    local Sleep = RR and RR.Sleep
    local s = Sleep and Sleep.state(e)
    if s then
        print(string.format(
            "[Railroader] sleep refused: %s  (fatigue %.2f, %.1f h since last sleep, "
            .. "zombies=%s, pain=%d, panic=%d, speed=%.2f m/s)",
            tostring(reason), s.fatigue or 0,
            (s.hoursSurvived or 0) - (s.lastHourSleeped or 0), tostring(s.zombies),
            s.painLevel or 0, s.panicLevel or 0, s.speed or 0))
    end
end

--------------------------------------------------------------------------
-- addHeadlightSlice: ONE slice for the headlight, walking the real three-position switch
-- OFF -> DIM (one sealed beam) -> BRIGHT (both) -> OFF, exactly as the F key does.
--
-- The bug this slice had was never the cycling -- it was the LABEL. It read
-- "Headlight: OFF", i.e. the position the switch was in and the click was about to
-- LEAVE, so it looked like "turn it off" and turned it on; and with the state named
-- rather than the action, there was nothing on screen to say that clicking again
-- would give you BRIGHT rather than darkness. Vanilla never names the state: a car's
-- slice reads "Headlights On" when they are off (ISVehicleMenu.showRadialMenu).
--
-- So we ask RR_Lights where the switch WOULD land (nextHead, which doesn't move it),
-- label the slice with that position, and hand setHead THE SAME ANSWER as the
-- command. The slice therefore cannot do anything other than what it says, and one
-- slice still reaches all three positions. Which position it is in right now is the
-- HUD's LIGHTS row -- the menu doesn't have to spend a slice restating it.
--
-- On a flat battery the slice stays LIVE: the switch is mechanical, RR_Lights
-- .effective never moves the driver's switch (it just stops answering it) and the
-- light comes back by itself once the engine runs. We say so on a second line rather
-- than pretend the click did nothing.
--
-- The CAB DOME LIGHT is deliberately NOT here (owner, 2026-07-28): it is a two-position
-- switch nobody parks to reach, it stays on Shift+F, and a radial that lists it puts a
-- second, near-identical lamp icon next to the headlight for a click that changes
-- nothing a driver needs the menu for.
--------------------------------------------------------------------------
local function addHeadlightSlice(menu, e)
    local Lights = RR and RR.Lights
    if not (Lights and RR.LightsRender and e.lightState) then return end

    local POSITION = {
        [Lights.OFF]    = { key = "IGUI_RR_HeadlightOff",    fb = "Turn the headlight off",  tex = TEX_LIGHTS_OFF },
        [Lights.DIM]    = { key = "IGUI_RR_HeadlightDim",    fb = "Turn on the dim beam",    tex = TEX_LIGHTS_ON  },
        [Lights.BRIGHT] = { key = "IGUI_RR_HeadlightBright", fb = "Turn on the bright beam", tex = TEX_LIGHTS_ON  },
    }
    local nxt = Lights.nextHead(e.lightState)
    local s   = POSITION[nxt]
    if s then
        local label = txt(s.key, s.fb)
        if nxt ~= Lights.OFF and not Lights.powered(e.engine) then
            label = label .. "\n" .. txt("IGUI_RR_HeadlightNoPower", "(no power - it won't come on)")
        end
        menu:addSlice(label, getTexture(s.tex), CabMenu.onSetHead, e, nxt)
    end
end

function CabMenu.onSetHead(e, mode)
    if RR.LightsRender then RR.LightsRender.setHead(e, mode) end
end

function CabMenu.onLeave(e)
    if RR.Ride then RR.Ride.requestDismount() end
end

--------------------------------------------------------------------------
-- addEngineSlice: start / shut down the diesel.
--
-- This REVERSES the decision at the top of this file (owner, 2026-07-28). That
-- decision rested on start being a HOLD-W ritual "a one-click slice would throw
-- away" -- but the hold is gone: a TAP of W now latches the sequence and it runs
-- itself, because holding a key through several seconds the player cannot
-- influence taught nothing and read as "W does nothing". With the ritual already
-- one press, a slice costs the mechanic nothing and gains the driver who never
-- found the key. Nothing about the simulation changes: the slice calls the same
-- Ride.startEngine the key does, so the catch roll, the battery drain per attempt
-- and the cold/wet penalties are all still there.
--
-- A refusal is a CLICKABLE slice naming the reason, not a dead one -- a radial
-- only shows a slice's text on hover, so a silent click reads as broken. Same
-- shape the sleep refusal uses.
--------------------------------------------------------------------------
local function addEngineSlice(menu, e)
    local Ride = RR and RR.Ride
    local eng  = e and e.engine
    if not Ride or not eng or not Ride.startEngine then return end

    if eng.running then
        if Ride.canStop(e) then
            menu:addSlice(txt("IGUI_RR_StopEngine", "Shut down the diesel"),
                          getTexture(TEX_ENG_OFF), CabMenu.onStopEngine, e)
        else
            menu:addSlice(txt("IGUI_RR_StopEngineBusy",
                              "Come to a stop and close the throttle first"),
                          getTexture(TEX_ENG_OFF), CabMenu.onStartRefused,
                          "IGUI_RR_StopEngineBusy")
        end
        return
    end

    local why = Ride.startRefusal(e)
    if why then
        menu:addSlice(txt(why, "The starter won't turn"),
                      getTexture(TEX_ENG_ON), CabMenu.onStartRefused, why)
        return
    end
    menu:addSlice(txt("IGUI_RR_StartEngine", "Start the diesel"),
                  getTexture(TEX_ENG_ON), CabMenu.onStartEngine, e)
end

function CabMenu.onStartEngine(e)
    if RR.Ride then RR.Ride.startEngine(e) end
end

function CabMenu.onStopEngine(e)
    if RR.Ride then RR.Ride.stopEngine(e) end
end

function CabMenu.onStartRefused(why)
    local p = getPlayer()
    if p then
        pcall(function()
            HaloTextHelper.addBadText(p, txt(why, "The starter won't turn"))
        end)
    end
    print("[Railroader] engine slice refused: " .. tostring(why))
end

--------------------------------------------------------------------------
-- show(e): build and display the cab menu. Toggling (a second press closes it) and
-- the paused-game guard are copied from ISVehicleMenu.showRadialMenu.
--------------------------------------------------------------------------
function CabMenu.show(e)
    local p = getPlayer()
    if not p or not e then return end

    local paused = false
    pcall(function()
        paused = UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0
    end)
    if paused then return end

    local num  = p:getPlayerNum()
    local menu = getPlayerRadialMenu(num)
    if not menu then return end

    if menu:isReallyVisible() then
        if menu.joyfocus then pcall(function() setJoypadFocus(num, nil) end) end
        menu:undisplay()
        return
    end
    menu:clear()

    -- First slice: the diesel. It is the thing a driver who has just sat down in a
    -- cold cab needs, and the one control they cannot deduce from the panel alone.
    addEngineSlice(menu, e)

    addSleepSlice(menu, e)

    -- The headlight. Duplicating F on purpose: the radial is where a player who never
    -- read the key list will look for it. Which end it burns on still follows the
    -- reverser (RR_LightsRender.leadSign). The cab dome light and the control-stand
    -- mode are NOT slices -- Shift+F and RR.HudMode.set() own them.
    addHeadlightSlice(menu, e)

    menu:addSlice(txt("IGUI_RR_LeaveCab", "Leave the cab"), getTexture(TEX_EXIT), CabMenu.onLeave, e)

    menu:setX(getPlayerScreenLeft(num) + getPlayerScreenWidth(num) / 2 - menu:getWidth() / 2)
    menu:setY(getPlayerScreenTop(num) + getPlayerScreenHeight(num) / 2 - menu:getHeight() / 2)
    menu:addToUIManager()

    pcall(function()
        getSoundManager():playUISound("UIVehicleMenuOpen")
        menu.sounds.undisplay = "UIVehicleMenuClose"
    end)
    pcall(function()
        if JoypadState.players[num + 1] then
            menu:setHideWhenButtonReleased(Joypad.DPadUp)
            setJoypadFocus(num, menu)
            p:setJoypadIgnoreAimUntilCentered(true)
        end
    end)
end

--------------------------------------------------------------------------
-- Key interception. `claimed(key)` answers "this press is ours" for BOTH V bindings;
-- everything else (and every press we don't claim) goes to the vanilla handler
-- unchanged, so Toggle UI / real vehicles / real animals behave exactly as before.
--------------------------------------------------------------------------
local function claimed(key)
    local hit = false
    pcall(function()
        hit = getCore():isKey("VehicleRadialMenu", key) or getCore():isKey("AnimalRadialMenu", key)
    end)
    return hit
end

-- returns true if this file handled the press (vanilla must not see it)
local function handle(key)
    if not claimed(key) then return false end
    local p = getPlayer()
    if not p or p:isDead() then return false end
    -- Asleep in the cab: no menu (vanilla blocks every UI the same way).
    if RR.Sleep and RR.Sleep.isAsleep() then return true end
    local e = RR.Ride and RR.Ride.current
    if e then
        CabMenu.show(e)
        return true
    end
    -- On foot: swallow the press when the "useable animal" is one of ours, so the
    -- livestock radial never opens on a locomotive.
    local a
    pcall(function() a = p:getUseableAnimal() end)
    if isOurAnimal(a) then return true end
    return false
end

local function claimRadialKey()
    -- Stood down on a client: leave V entirely to vanilla. Claiming a key for a mod that
    -- will never answer is the one thing worse than the mod being off (RR_MP).
    if RR.MP and RR.MP.blocked() and not RR.MPClient then return end
    if not ISUIHandler or ISUIHandler.rrRadialPatched then return end
    local vanillaStart   = ISUIHandler.onKeyStartPressed
    local vanillaPressed = ISUIHandler.onKeyPressed
    if not vanillaStart or not vanillaPressed then return end

    local function guardedStart(key)
        if handle(key) then return end
        return vanillaStart(key)
    end
    -- The release half: with "radial menu key toggle" off, vanilla re-shows/hides the
    -- menu when V comes back up. Ours is a toggle either way, so we simply swallow the
    -- release for a press we claimed -- otherwise vanilla would rebuild the ANIMAL menu
    -- over the top of ours.
    local function guardedPressed(key)
        if claimed(key) then
            local p = getPlayer()
            local ours = (RR.Ride and RR.Ride.current) ~= nil
            if not ours and p then
                local a
                pcall(function() a = p:getUseableAnimal() end)
                ours = isOurAnimal(a)
            end
            if ours then return end
        end
        return vanillaPressed(key)
    end

    pcall(function() Events.OnKeyStartPressed.Remove(vanillaStart) end)
    pcall(function() Events.OnKeyPressed.Remove(vanillaPressed) end)
    Events.OnKeyStartPressed.Add(guardedStart)
    Events.OnKeyPressed.Add(guardedPressed)
    ISUIHandler.rrRadialPatched = true
    print("[Railroader] cab radial menu: V claimed (vehicle + animal bindings).")
end
Events.OnGameStart.Add(claimRadialKey)

RR = RR or {}
RR.CabMenu = CabMenu
print("[Railroader] RR_CabMenu.lua: loaded OK.")

return CabMenu
