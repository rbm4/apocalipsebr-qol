local MOD = "CampfireHeatFix"

local DEBUG = getCore():getDebug()

local function dlog(msg)
    if not DEBUG then return end
    DebugLog.log(DebugType.General, "[" .. MOD .. "] " .. tostring(msg))
end

if not SCampfireGlobalObject then
    return
end

-- Keep: bake radius into the IsoFire on creation (fixes initial lighting transmit)
if SCampfireGlobalObject.addFireObject then
    local _vanilla_addFireObject = SCampfireGlobalObject.addFireObject

    function SCampfireGlobalObject:addFireObject()
        _vanilla_addFireObject(self)

        local fireObj = self:getFireObject()
        if fireObj and self.radius and fireObj:getLightRadius() ~= self.radius then
            fireObj:setLightRadius(self.radius)
        end
    end
end

-- NEW: vanilla uses the wrong change-key 'lightRadius' for IsoFire.
-- We call vanilla, then re-send using the correct key: 'LightRadius'.
if SCampfireGlobalObject.changeFireLvl then
    local _vanilla_changeFireLvl = SCampfireGlobalObject.changeFireLvl

    function SCampfireGlobalObject:changeFireLvl()
        _vanilla_changeFireLvl(self)

        if not isServer() then return end

        local fireObj = self:getFireObject()
        if not fireObj then return end

        -- Ensure clients apply the update (IsoFire expects 'LightRadius' as the change name).
        fireObj:sendObjectChange("LightRadius")
    end
end

dlog("Installed campfire heat/light MP fix (IsoFire LightRadius change key)")
