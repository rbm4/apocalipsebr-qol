-- TWF_Resting_SitKeybind.lua
-- Safe sit-on-ground keybind + timed action gate.
-- Default keybind is unassigned (0).

if _G.TWF_Resting_SitKeybind_Loaded then return end
_G.TWF_Resting_SitKeybind_Loaded = true

require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISSitOnGround"

-- Safe-require Restingmod so we can read its mod-option keybind later.
do
    local candidates = { "MARQUA_Restingmod" }
    local loaded = false

    local function tryAll()
        for _, name in ipairs(candidates) do
            if package and package.loaded and package.loaded[name] then
                loaded = true
                return true
            end
            local ok = pcall(require, name)
            if ok then
                loaded = true
                return true
            end
        end
        return false
    end

    if not tryAll() then
        local function retryOnce()
            if loaded then return end
            if tryAll() then
                Events.OnGameStart.Remove(retryOnce)
                Events.OnCreatePlayer.Remove(retryOnce)
            end
        end
        Events.OnGameStart.Add(retryOnce)
        Events.OnCreatePlayer.Add(retryOnce)
    end

    _G.MARQUA_RESTINGMOD = _G.MARQUA_RESTINGMOD or {}
end

local UNSAFE_RANGE = 10
local SAY_COOLDOWN_MS = 1500
local _lastUnsafeSayMs = 0

local function _twf_nowMs()
    if getTimeInMillis then
        return getTimeInMillis()
    end
    if getGameTime and getGameTime() and getGameTime().getWorldAgeHours then
        return math.floor(getGameTime():getWorldAgeHours() * 3600000)
    end
    return os.time() * 1000
end

local function _twf_text(key, fallback)
    if getText then
        local t = getText(key)
        if t and t ~= key then return t end
    end
    return fallback
end

local function _twf_getLocalPlayer()
    if getPlayer then
        local p = getPlayer()
        if p then return p end
    end
    if getSpecificPlayer then
        return getSpecificPlayer(0)
    end
    return nil
end

-- Reads the keycode from the mod-option keybind (or falls back to 0).
local function _twf_getSitKeyCode()
    local m = _G.MARQUA_RESTINGMOD
    if not m then return 0 end

    local opt = m.sitKeybind
    if not opt then return 0 end

    local v = nil
    for _, methodName in ipairs({ "getValue", "getKey", "getKeyCode" }) do
        if opt[methodName] then
            local ok, res = pcall(opt[methodName], opt)
            if ok and res ~= nil then
                v = res
                break
            end
        end
    end

    if v == nil then
        v = opt.key or opt.keyCode or (opt.element and opt.element.keyCode)
    end

    if type(v) == "string" then v = tonumber(v) end
    if type(v) ~= "number" then return 0 end
    return v
end

local function _twf_sayUnsafe(player)
    local now = _twf_nowMs()
    if (now - _lastUnsafeSayMs) < SAY_COOLDOWN_MS then return end
    _lastUnsafeSayMs = now

    local msg = _twf_text("UI_RestingMod_SitUnsafe", "It doesn't feel safe to sit down right now.")
    if player and player.Say then
        player:Say(msg)
    end
end

local function _twf_zombieCanSeePlayer(z, player)
    -- Optional: only if such a function exists on this build.
    local fn = z and (z.CanSee or z.canSee)
    if not fn then return nil end
    local ok, v = pcall(fn, z, player)
    if ok and type(v) == "boolean" then return v end
    return nil
end

local function _twf_zombieIsChasingPlayer(z, player)
    if not z or not player then return false end

    local chasing = false

    if z.getTarget then
        local ok, t = pcall(z.getTarget, z)
        if ok and t == player then
            chasing = true
        end
    end

    if (not chasing) and z.target and z.target == player then
        chasing = true
    end

    if not chasing then return false end

    -- If we can verify LOS, require it; otherwise treat "chasing" as sufficient.
    local canSee = _twf_zombieCanSeePlayer(z, player)
    if canSee == false then return false end

    return true
end

-- Returns true if a movement-blocking obstacle (fence/wall/closed door, etc.)
-- is between zombie and player. We only treat it as "safe" if the block is
-- right next to either side (common "across a fence" case).
local function _twf_hasBlockingObstacleBetween(z, player, cell)
    if not z or not player then return false end
    if not LosUtil or not LosUtil.lineClearCollideCount then return false end

    cell = cell or (getCell and getCell()) or (player.getCell and player:getCell())
    if not cell then return false end

    local zx, zy = z:getX(), z:getY()
    local zz = (z.getZ and z:getZ()) or player:getZ()
    local px, py, pz = player:getX(), player:getY(), player:getZ()

    if zz ~= pz then return false end

    local directSteps = math.max(math.abs(zx - px), math.abs(zy - py), math.abs(zz - pz))
    if directSteps <= 0 then return false end

    -- Check from player -> zombie: obstacle right next to player?
    do
        local ok, steps = pcall(LosUtil.lineClearCollideCount, player, cell, zx, zy, zz, px, py, pz)
        if ok and type(steps) == "number" then
            if steps < directSteps and steps <= 1 then
                return true
            end
        end
    end

    -- Check from zombie -> player: obstacle right next to zombie?
    do
        local ok, steps = pcall(LosUtil.lineClearCollideCount, z, cell, px, py, pz, zx, zy, zz)
        if ok and type(steps) == "number" then
            if steps < directSteps and steps <= 1 then
                return true
            end
        end
    end

    return false
end

local function _twf_isUnsafeToSit(player, range)
    if not player then return true end
    range = range or UNSAFE_RANGE

    local cell = (getCell and getCell()) or (player.getCell and player:getCell())
    if not cell or not cell.getZombieList then return false end

    local ok, zlist = pcall(cell.getZombieList, cell)
    if not ok or not zlist or not zlist.size then return false end

    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local rangeSq = range * range

    for i = 0, zlist:size() - 1 do
        local z = zlist:get(i)
        if z and (not z.isDead or not z:isDead()) then
            local zx, zy = z:getX(), z:getY()
            local zz = (z.getZ and z:getZ()) or pz

            if zz == pz then
                local dx = zx - px
                local dy = zy - py
                if (dx * dx + dy * dy) <= rangeSq then
                    if _twf_zombieIsChasingPlayer(z, player) then
                        -- NEW: if a fence/wall/closed door blocks movement between us, allow sitting.
                        if not _twf_hasBlockingObstacleBetween(z, player, cell) then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

-- New gated timed action (keeps vanilla behavior, but blocks if unsafe).
TWF_ISSitOnGroundSafe = ISSitOnGround:derive("TWF_ISSitOnGroundSafe")

function TWF_ISSitOnGroundSafe:start()
    if not self.character or (self.character.isDead and self.character:isDead()) then
        self:forceComplete()
        return
    end

    if _twf_isUnsafeToSit(self.character, self.unsafeRange) then
        _twf_sayUnsafe(self.character)
        self:forceComplete()
        return
    end

    -- Same effect as vanilla sit: reportEvent("EventSitOnGround")
    self.character:reportEvent("EventSitOnGround")
    if self.bed then self.character:setBed(self.bed) end
end

function TWF_ISSitOnGroundSafe:new(character, bed, unsafeRange)
    local o = ISSitOnGround.new(self, character, bed)
    o.unsafeRange = unsafeRange or UNSAFE_RANGE
    return o
end

local function _twf_isAlreadySitting(player)
    local function safeBoolCall(fnName)
        local fn = player and player[fnName]
        if not fn then return false end
        local ok, v = pcall(fn, player)
        return ok and v == true
    end
    return safeBoolCall("isSitOnGround")
        or safeBoolCall("isSittingOnGround")
        or safeBoolCall("isSittingOnFurniture")
        or safeBoolCall("isSitting")
end

local function _twf_onKeyPressed(key)
    local sitKey = _twf_getSitKeyCode()
    if not sitKey or sitKey <= 0 then return end
    if tonumber(key) ~= sitKey then return end

    local player = _twf_getLocalPlayer()
    if not player or (player.isDead and player:isDead()) then return end
    if player.isAsleep and player:isAsleep() then return end
    if player.getVehicle and player:getVehicle() then return end

    if _twf_isAlreadySitting(player) then return end

    if _twf_isUnsafeToSit(player, UNSAFE_RANGE) then
        _twf_sayUnsafe(player)
        return
    end

    ISTimedActionQueue.add(TWF_ISSitOnGroundSafe:new(player, nil, UNSAFE_RANGE))
end

Events.OnKeyPressed.Add(_twf_onKeyPressed)