-- === TWF: safe require for MARQUA_Restingmod.lua ===
do
    -- Adjust if your file sits in a subfolder: e.g. "MyModFolder.MARQUA_Restingmod"
    local candidates = { "MARQUA_Restingmod" }  -- try these module names in order
    local loaded = false
    local lastErr = nil

    local function tryAll()
        for _, name in ipairs(candidates) do
            -- already loaded?
            if package and package.loaded and package.loaded[name] then
                loaded = true
                return true
            end
            -- attempt require
            local ok, err = pcall(require, name)
            if ok then
                print("[TWF][Resting] required: " .. tostring(name))
                loaded = true
                return true
            else
                lastErr = err
            end
        end
        if lastErr then
            print("[TWF][Resting] safeRequire failed: " .. tostring(lastErr))
        end
        return false
    end

    -- initial attempt (at script load)
    if not tryAll() then
        -- delayed retry, in case the other file loads later
        local function retryOnce()
            if loaded then return end
            if tryAll() then
                -- stop retrying once it succeeded
                Events.OnGameStart.Remove(retryOnce)
                Events.OnCreatePlayer.Remove(retryOnce)
            end
        end
        Events.OnGameStart.Add(retryOnce)
        Events.OnCreatePlayer.Add(retryOnce)
    end

    -- Optional: create a harmless table so code like MARQUA_RESTINGMOD.* won't explode
    _G.MARQUA_RESTINGMOD = _G.MARQUA_RESTINGMOD or {}
end

-- one-time per-player warning flag
local MARQUA_RESTINGMOD_ArmWarnShown = {}





-- Early warning before engine's hard penalty
local PAIN_CRITICAL = 2.8   -- show once when crossing this
local PAIN_RESET    = 0.5   -- reset once pain clearly reduced

local function _twf_getPlayerKey(player)
    local id = player and player:getOnlineID()
    if id and id ~= 0 then return tostring(id) end
    local desc = player and player:getDescriptor()
    return tostring((desc and desc:getID()) or 1)
end

-- Returns a label for the arm-strain warning, using Restingmod text if available.
local function _twf_getPainLabel()
    local m = _G and _G.MARQUA_RESTINGMOD
    -- Prefer your option text (customStiffnessRightArm) if present
    if m and m.customStiffnessRightArm and m.customStiffnessRightArm.getValue then
        local v = m.customStiffnessRightArm:getValue()
        if v and v ~= "" then return v end
    end
    -- Fallbacks
    if getText then
        return getText("UI_Stiffness_Right_Arm")
            or getText("UI_PAIN")
            or "Pain"
    end
    return "Pain"
end


-- Max pain across the full right arm (hand, forearm, upper arm)
local function _twf_getRightArmMaxPain(player)
    local bd = player and player:getBodyDamage()
    if not bd then return 0 end
    local h = bd:getBodyPart(BodyPartType.Hand_R):getPain() or 0
    local f = bd:getBodyPart(BodyPartType.ForeArm_R):getPain() or 0
    local u = bd:getBodyPart(BodyPartType.UpperArm_R):getPain() or 0
    return math.max(h, f, u)
end

-- One-time warning while standing (no sitting/furniture)
function MARQUA_Resting_WarnOnCombatAffectingStrain(player)
    if not player or player:isDead() or player:isAsleep() then return end

    -- Standing only (safe across builds: check existence + pcall)
    local sitting = false
    local function safeBoolCall(fnName)
        local fn = player[fnName]
        if not fn then return false end
        local ok, v = pcall(fn, player)
        return ok and v == true
    end

    -- Try multiple sitting APIs (Build 42.x changes can move/rename these)
    if safeBoolCall("isSitOnGround") then sitting = true end
    if not sitting and safeBoolCall("isSittingOnGround") then sitting = true end
    if not sitting and safeBoolCall("isSittingOnFurniture") then sitting = true end
    if not sitting and safeBoolCall("isSitting") then sitting = true end

    if sitting then return end

    local key = _twf_getPlayerKey(player)
    local warned  = MARQUA_RESTINGMOD_ArmWarnShown[key] == true
    local maxPain = _twf_getRightArmMaxPain(player)

    if maxPain >= PAIN_CRITICAL then
        if not warned then
            if HaloTextHelper and HaloTextHelper.addBadText then
                HaloTextHelper.addBadText(player, _twf_getPainLabel())
            end
            MARQUA_RESTINGMOD_ArmWarnShown[key] = true
        end
        return
    end

    if warned and maxPain <= PAIN_RESET then
        MARQUA_RESTINGMOD_ArmWarnShown[key] = false
    end
end



-- keep your existing hook; if not present, add:
Events.OnPlayerUpdate.Add(MARQUA_Resting_WarnOnCombatAffectingStrain)