local function addMountOn(part, weaponToAdd)
    local weaponPart = instanceItem(part)
    local mountOn = weaponPart and weaponPart:getMountOn()
    local item = getItem(part)
    if not mountOn or not item then return end

    local str = ""
    for i = 1, mountOn:size(), 1 do
        local mountedWeapon = mountOn:get(i - 1)
        if mountedWeapon == weaponToAdd then
            return
        end
        str = str .. mountedWeapon .. ";"
    end
    item:DoParam("MountOn = " .. str .. weaponToAdd)
end

addMountOn("Base.x2Scope", "PZCrossbows.CompoundCrossBow")
addMountOn("Base.x4Scope", "PZCrossbows.CompoundCrossBow")
addMountOn("Base.x8Scope", "PZCrossbows.CompoundCrossBow")
