local MOD = "ThermoFix"

local DEBUG = getCore():getDebug()

local function log(msg)
    if DEBUG then
        DebugLog.log(DebugType.General, "[" .. MOD .. "][C] " .. tostring(msg))
    end
end

local thermoDirty = true
local tickCounter = 0
local TICKS_PER_CHECK = 5

local function isLocalPlayer(p)
    return p and p.isLocalPlayer and p:isLocalPlayer()
end

local function tryThermoUpdate(player)
    if not (player and player.getBodyDamage) then return false end
    local bd = player:getBodyDamage()
    if not (bd and bd.getThermoregulator) then return false end
    local thermo = bd:getThermoregulator()
    if not (thermo and thermo.update) then return false end

    thermo:update()
    return true
end

local function onPlayerUpdate(player)
    -- Bug is MP-client only; don't do anything in SP / server-host context.
    if not isClient() then return end
    if not isLocalPlayer(player) then return end

    tickCounter = tickCounter + 1
    if tickCounter < TICKS_PER_CHECK then return end
    tickCounter = 0

    if thermoDirty then
        local ok = tryThermoUpdate(player)
        if ok then
            thermoDirty = false
            -- log("Thermoregulator updated")
        else
            -- Keep dirty if we couldn't update yet (e.g. early boot).
            thermoDirty = true
            -- log("Thermoregulator update skipped (not ready)")
        end
    end
end

local function onClothingUpdated(player)
    if not isClient() then return end
    if not isLocalPlayer(player) then return end
    thermoDirty = true
    -- log("Clothing updated; marking thermo dirty")
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)

Events.OnClothingUpdated.Add(onClothingUpdated)