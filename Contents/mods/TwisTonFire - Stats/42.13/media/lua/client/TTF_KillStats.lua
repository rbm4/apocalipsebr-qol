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

    local fullType = weapon.getFullType and weapon:getFullType() or nil

    local wtype = weapon.getType and weapon:getType() or ""
    if wtype == "BareHands" or fullType == "Base.BareHands" then
        return "Unarmed", nil
    end

    if weapon.isRanged and weapon:isRanged() then
        return "Firearm", fullType
    end

    local si = weapon.getScriptItem and weapon:getScriptItem() or nil
    if si and si.containsWeaponCategory and WeaponCategory then
        if WeaponCategory.AXE and si:containsWeaponCategory(WeaponCategory.AXE) then
            return "Axe", fullType
        end
        if WeaponCategory.LONG_BLADE and si:containsWeaponCategory(WeaponCategory.LONG_BLADE) then
            return "LongBlade", fullType
        end
        if WeaponCategory.SMALL_BLADE and si:containsWeaponCategory(WeaponCategory.SMALL_BLADE) then
            return "SmallBlade", fullType
        end
        if WeaponCategory.SPEAR and si:containsWeaponCategory(WeaponCategory.SPEAR) then
            return "Spear", fullType
        end
        if WeaponCategory.BLUNT and si:containsWeaponCategory(WeaponCategory.BLUNT) then
            return "Blunt", fullType
        end
        if WeaponCategory.SMALL_BLUNT and si:containsWeaponCategory(WeaponCategory.SMALL_BLUNT) then
            return "SmallBlunt", fullType
        end
    end

    -- legacy / mod fallback (older category strings)
    if weapon.getCategories then
        local cats = weapon:getCategories()
        if cats then
            for i = 0, cats:size() - 1 do
                local c = cats:get(i)
                if c and c ~= "Improvised" then
                    return c, fullType
                end
            end
        end
    end

    if weapon.getSubCategory then
        local sub = weapon:getSubCategory()
        if sub and sub ~= "" then
            return sub, fullType
        end
    end

    return "Other", fullType
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

        local w = (lastHit[zombie] and lastHit[zombie].weapon)
            or (killer.getPrimaryHandItem and killer:getPrimaryHandItem())
            or nil

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