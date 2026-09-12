local lowCaliberSound = "SilencedShot_LowCaliber"
local highCaliberSound = "SilencedShot"
local sniperSound = "SilencedShot_Snipers"

local SupressorDefinitions = {
    Canon = {
        SupressorSlim = {
            volume = 0.3,
            radius = 0.1,
        },
        SupressorBulk = {
            volume = 0.3,
            radius = 0.1,
        },
        SupressorOsprey = {
            volume = 0.3,
            radius = 0.1,
        },
    }
}

-- rifles sniper
local sniperWeapons = {
    ["AWP"] = true,
    ["SSG 69"] = true,
    ["G3SG1"] = true,
}

-- armas de alto calibre
local heavyWeapons = {
    ["SCAR-20"] = true,

    ["AK-47"] = true,
    ["AUG"] = true,
    ["FAMAS"] = true,
    ["Galil AR"] = true,
    ["M4A1-S"] = true,
    ["M4A4"] = true,
    ["SG 552"] = true,

    ["M249"] = true,
    ["Negev"] = true,

    ["MAG-7"] = true,
    ["Nova"] = true,
    ["Sawed-Off"] = true,
    ["XM1014"] = true,

    ["Desert Eagle"] = true,
    ["R8 Revolver"] = true,
}

local function UpdateWeaponSound(weapon)
    if not weapon or not weapon:IsWeapon() then return end
    if not weapon:isRanged() then return end

    local scriptItem = weapon:getScriptItem()

    local soundVolume = scriptItem:getSoundVolume()
    local soundRadius = scriptItem:getSoundRadius()
    local swingSound = scriptItem:getSwingSound()

    for partName, partSupressors in pairs(SupressorDefinitions) do
        local part = weapon:getWeaponPart(partName)

        if part then
            local supressor = partSupressors[part:getType()]

            if supressor then
                local weaponType = weapon:getType()

                if sniperWeapons[weaponType] then
                    swingSound = sniperSound

                elseif heavyWeapons[weaponType] then
                    swingSound = highCaliberSound

                else
                    swingSound = lowCaliberSound
                end

                soundVolume = soundVolume * supressor.volume
                soundRadius = soundRadius * supressor.radius
                break
            end
        end
    end

    weapon:setSoundVolume(soundVolume)
    weapon:setSoundRadius(soundRadius)
    weapon:setSwingSound(swingSound)
end

local function OnPlayerUpdate(player)
    local weapon = player:getPrimaryHandItem()

    if weapon then
        UpdateWeaponSound(weapon)
    end
end

Events.OnPlayerUpdate.Add(OnPlayerUpdate)