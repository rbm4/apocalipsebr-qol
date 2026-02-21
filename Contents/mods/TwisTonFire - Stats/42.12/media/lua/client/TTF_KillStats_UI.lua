-- File: TTF_KillStats_UI.lua
-- Scope: client (UI helpers only)
-- Purpose: Map stored keys -> localized labels for charts/menus.

if not TTF_KillStatsUI then TTF_KillStatsUI = {} end
local U = TTF_KillStatsUI

-- ---------- internals ----------
local _weaponNameCache = {}

local function _tryText(key)
    if not key or key == "" then return nil end
    local ok, res = pcall(getText, key)
    if not ok or not res or res == "" or res == key then return nil end
    return res
end

local function _scriptDisplayName(fullType)
    local sm = (getScriptManager and getScriptManager()) or (ScriptManager and ScriptManager.instance) or nil
    if not sm or not sm.getItem then return nil end
    local it = sm:getItem(fullType)
    if it and it.getDisplayName then
        local n = it:getDisplayName()
        if n and n ~= "" then return n end
    end
    return nil
end

local function _prettyFromType(fullType)
    local t = fullType or ""
    local typePart = string.match(t, "%.([^%.]+)$") or t
    typePart = string.gsub(typePart, "([a-z])([A-Z])", "%1 %2")
    typePart = string.gsub(typePart, "_", " ")
    return typePart
end


function U.GetWeaponLabel(fullType)
    if fullType == "__VEHICLE__" then
        return _tryText("UI_TTF_KILLSTAT_VEHICLE") or "Vehicle"
    end
    if fullType == "__UNARMED__" or not fullType or fullType == "" then
        return _tryText("UI_TTF_KILLSTAT_UNARMED") or "Unarmed"
    end

    local cached = _weaponNameCache[fullType]
    if cached then return cached end

    local name = _scriptDisplayName(fullType)

    if not name then
        local ft           = fullType
        local ftLower      = string.lower(ft)
        local dotToUnder   = string.gsub(ft, "%.", "_")
        local dotToUnderLo = string.gsub(ftLower, "%.", "_")

        name = _tryText("ItemName_" .. ft)
            or _tryText("ItemName_" .. ftLower)
            or _tryText("ItemName_" .. dotToUnder)
            or _tryText("ItemName_" .. dotToUnderLo)
    end

    if not name then
        name = _prettyFromType(fullType)
    end

    _weaponNameCache[fullType] = name
    return name
end

local _catToKey = {
    Axe        = "IGUI_perks_Axe",
    LongBlade  = "IGUI_perks_LongBlade",
    SmallBlade = "IGUI_perks_SmallBlade",
    Spear      = "IGUI_perks_Spear",
    Blunt      = "IGUI_perks_Blunt",
    SmallBlunt = "IGUI_perks_SmallBlunt",
    Firearm    = "IGUI_perks_Firearm",
    Vehicle    = "UI_TTF_KILLSTAT_VEHICLE",
    Unarmed    = "UI_TTF_KILLSTAT_UNARMED",
    Other      = "UI_TTF_KILLSTAT_OTHER",
}

function U.GetCategoryLabel(catKey)
    local key = _catToKey[catKey]
    return (_tryText(key) or catKey)
end

function U.GetVehicleKillsLabel()
    return _tryText("UI_TTF_KILLSTAT_VEHICLE") or "Vehicle"
end

function U.ClearCaches()
    _weaponNameCache = {}
end

return TTF_KillStatsUI