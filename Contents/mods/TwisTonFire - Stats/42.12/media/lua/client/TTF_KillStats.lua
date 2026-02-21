if not TTF_KillStats then TTF_KillStats = {} end
local M = TTF_KillStats

local PSEUDO_WEAPON_VEHICLE = "__VEHICLE__"
local PSEUDO_WEAPON_UNARMED = "__UNARMED__"

local CATEGORY_KEYS = {
    "Axe","LongBlade","SmallBlade","Spear","Blunt","SmallBlunt",
    "Firearm","Vehicle","Unarmed","Other"
}


local lastHit = setmetatable({}, { __mode = "k" })

-- ===== helpers =====
local function ensureKillTables(player)
    if not player or not instanceof(player, "IsoPlayer") then return nil end
    local md = player:getModData()
    md.TTF_KillStats = md.TTF_KillStats or {}
    local ks = md.TTF_KillStats
    ks.categories  = ks.categories  or {}
    ks.weapons     = ks.weapons     or {}
    ks.vehicleKills = tonumber(ks.vehicleKills) or 0
	
    for _,k in ipairs(CATEGORY_KEYS) do
        if ks.categories[k] == nil then ks.categories[k] = 0 end
    end
    return ks
end

local function incCategory(player, cat)
    local ks = ensureKillTables(player); if not ks then return end
    cat = cat or "Other"
    ks.categories[cat] = (tonumber(ks.categories[cat]) or 0) + 1
end

local function incWeapon(player, fullType)
    local ks = ensureKillTables(player); if not ks then return end
    if not fullType or fullType == "" then fullType = "Unknown" end
    ks.weapons[fullType] = (tonumber(ks.weapons[fullType]) or 0) + 1
end

local function incVehicle(player)
    local ks = ensureKillTables(player); if not ks then return end
    ks.vehicleKills = (tonumber(ks.vehicleKills) or 0) + 1
end

local function classifyWeapon(weapon)
    if not weapon then return "Unarmed", nil end

    local wtype = weapon:getType() or ""
    if wtype == "BareHands" then
        return "Unarmed", nil
    end

    if weapon.isRanged and weapon:isRanged() then
        return "Firearm", weapon:getFullType()
    end

    local si = weapon.getScriptItem and weapon:getScriptItem() or nil
    if si and si.containsWeaponCategory then
        if si:containsWeaponCategory("Axe")        then return "Axe",        weapon:getFullType() end
        if si:containsWeaponCategory("LongBlade")  then return "LongBlade",  weapon:getFullType() end
        if si:containsWeaponCategory("SmallBlade") then return "SmallBlade", weapon:getFullType() end
        if si:containsWeaponCategory("Spear")      then return "Spear",      weapon:getFullType() end
        if si:containsWeaponCategory("Blunt")      then return "Blunt",      weapon:getFullType() end
        if si:containsWeaponCategory("SmallBlunt") then return "SmallBlunt", weapon:getFullType() end
    end

    if weapon.getCategories then
        local cats = weapon:getCategories()
        if cats then
            for i=0,cats:size()-1 do
                local c = cats:get(i)
                if c and c ~= "Improvised" then
                    return c, weapon:getFullType()
                end
            end
        end
    end
    if weapon.getSubCategory then
        local sub = weapon:getSubCategory()
        if sub and sub ~= "" then
            return sub, weapon:getFullType()
        end
    end

    return "Other", weapon:getFullType()
end

local function playerDriving(player)
    local veh = player and player.getVehicle and player:getVehicle() or nil
    if not veh then return nil, false end
    if veh.getDriverRegardlessOfTow and veh:getDriverRegardlessOfTow() == player then return veh, true end
    if veh.getDriver and veh:getDriver() == player then return veh, true end
    if veh.getSeat and veh:getSeat(player) == 0 then return veh, true end
    if veh.getCharacter and veh:getCharacter(0) == player then return veh, true end
    return veh, false
end

-- ===== events =====
local function onWeaponHitCharacter(attacker, target, weapon, damage)
    if not attacker or not target then return end
    if not instanceof(attacker, "IsoPlayer") then return end
    if not instanceof(target, "IsoZombie") then return end
    lastHit[target] = { player = attacker, weapon = weapon }
end

local function onZombieDead(zombie)
    if not zombie or zombie:isFakeDead() then return end

    local killer = zombie.getAttackedBy and zombie:getAttackedBy() or nil
    if killer and instanceof(killer, "IsoPlayer") then
        local veh, isDriver = playerDriving(killer)
        if veh and isDriver then

            incVehicle(killer)
            incCategory(killer, "Vehicle")
            incWeapon(killer, PSEUDO_WEAPON_VEHICLE)
            lastHit[zombie] = nil
            return
        end


        local w = lastHit[zombie] and lastHit[zombie].weapon or (killer.getPrimaryHandItem and killer:getPrimaryHandItem()) or nil
        local cat, full = classifyWeapon(w)
        if not full and cat == "Unarmed" then full = PSEUDO_WEAPON_UNARMED end
        incCategory(killer, cat)
        if full then incWeapon(killer, full) end
        lastHit[zombie] = nil
        return
    end


    local lh = lastHit[zombie]
    if lh and lh.player and instanceof(lh.player, "IsoPlayer") then
        local cat, full = classifyWeapon(lh.weapon)
        if not full and cat == "Unarmed" then full = PSEUDO_WEAPON_UNARMED end
        incCategory(lh.player, cat)
        if full then incWeapon(lh.player, full) end
    end

    lastHit[zombie] = nil
end

local function onCreatePlayer(_idx, player)
    ensureKillTables(player)
end

-- ===== API for UI/other modules =====
function TTF_KillStats.Get(playerNum)
    local p = getSpecificPlayer(playerNum or 0) or getPlayer()
    if not p then return nil end
    return (p:getModData().TTF_KillStats or nil)
end

-- ===== wire up =====
Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
Events.OnZombieDead.Add(onZombieDead)
Events.OnCreatePlayer.Add(onCreatePlayer)