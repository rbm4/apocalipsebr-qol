-- AACSOverrideShared.lua (Build 42 / MP-safe)
-- Patches animal pickup + rope attach + slaughter timed actions to enforce ownership.
-- Validates on BOTH client (for UX feedback) AND server (source of truth).
--
-- CHANGES vs original:
-- [FIX-2] Client-side validation now ALSO blocks (was bypassed by _serverShouldValidate)
-- [FIX-5] Added ISSlaughterAnimal / ISKillAnimal patches for kill protection
-- [FIX-RESTAMP] Added EveryTenMinutes re-stamp logic to restore modData on animals
--               that lost it during pickup/drop cycles

local okBase = pcall(require, "TimedActions/ISBaseTimedAction")
if not okBase then return end
local ok = pcall(require, "AACSShared")
if not ok then return end

-- Some PZ contexts don't define ISInventoryPage on server; mirror AVCS safety.
if isServer() and (not isClient()) and ISInventoryPage == nil then
    ISInventoryPage = {}
end

AACS = AACS or {}

local function _t(key, ...)
    local msg = getText(key)
    local args = { ... }
    for i = 1, #args do
        msg = msg:gsub("%%" .. i, tostring(args[i]))
    end
    return msg
end

local function _notifyDenied(playerObj, msg)
    if not msg then msg = "Denied" end

    -- Prefer server-to-client notify so hosted/dedicated behave the same.
    if isServer() and playerObj and sendServerCommand then
        sendServerCommand(playerObj, "AACS", "notify", { msg = msg, kind = "bad" })
        return
    end

    -- Fallback (client/SP): HaloTextHelper overloads differ in B42; avoid passing ColorRGB directly.
    if isClient() and playerObj then
        if HaloTextHelper and HaloTextHelper.addText then
            if not pcall(HaloTextHelper.addText, playerObj, msg) then
                playerObj:Say(msg)
            end
        else
            playerObj:Say(msg)
        end
    end
end

local function _denyCooldown(playerObj, key)
    local md = playerObj:getModData()
    md.AACS_Deny = md.AACS_Deny or {}
    local now = AACS.Now()
    local last = md.AACS_Deny[key] or 0
    local threshold = (now > 100000000000) and 800 or 1
    if now - last < threshold then
        return true
    end
    md.AACS_Deny[key] = now
    return false
end

-- [FIX-2] CHANGED: Validate on ALL sides (client for UX, server for security)
-- The old _serverShouldValidate() returned false on pure client, meaning
-- client-side patches were no-ops. Now we validate everywhere.
local function _validateAnimalAction(character, animal, action)
    if not character or not animal then 
        AACS.Log(string.format("_validateAnimalAction: character=%s animal=%s - INVALID", 
            tostring(character), tostring(animal)))
        return false 
    end
    
    -- Check if the animal is claimed at all
    local uid = AACS.GetAnimalUID(animal)
    if not uid then return true end -- unclaimed animal, allow
    
    local username = character:getUsername()
    local canDo = AACS.CanPlayerDo(character, animal, action)
    
    if canDo then
        AACS.Log(string.format("_validateAnimalAction: %s CAN %s animal (owner: %s)", 
            username, action, AACS.GetAnimalOwner(animal) or "unclaimed"))
        return true
    end

    local owner = AACS.GetAnimalOwner(animal) or "?"
    local msg = _t("IGUI_AACS_Notify_Protected", owner, uid)
    
    AACS.Log(string.format("_validateAnimalAction: BLOCKED %s from %s animal (owner: %s, uid: %s)", 
        username, action, owner, uid))

    local cdKey = tostring(action) .. ":" .. tostring(uid)
    if not _denyCooldown(character, cdKey) then
        _notifyDenied(character, msg)
    end
    return false
end

-- Patch: Rope / leash
pcall(require, "TimedActions/ISAttachAnimalToPlayer")
if ISAttachAnimalToPlayer then
    AACS.Log("Patching ISAttachAnimalToPlayer...")
    
    if ISAttachAnimalToPlayer.isValid then
        local _oldValid = ISAttachAnimalToPlayer.isValid
        function ISAttachAnimalToPlayer:isValid()
            if not _oldValid(self) then return false end
            return _validateAnimalAction(self.character, self.animal, "leash")
        end
    end
    
    if ISAttachAnimalToPlayer.start then
        local _oldStart = ISAttachAnimalToPlayer.start
        function ISAttachAnimalToPlayer:start()
            if not _validateAnimalAction(self.character, self.animal, "leash") then
                self:forceStop()
                return
            end
            _oldStart(self)
        end
    end
    
    if ISAttachAnimalToPlayer.perform then
        local _oldPerform = ISAttachAnimalToPlayer.perform
        function ISAttachAnimalToPlayer:perform()
            if not _validateAnimalAction(self.character, self.animal, "leash") then
                self:forceStop()
                return
            end
            _oldPerform(self)
        end
    end
end

-- Patch: Pickup animal
pcall(require, "TimedActions/Animals/ISPickupAnimal")
if ISPickupAnimal then
    AACS.Log("Patching ISPickupAnimal...")
    
    if ISPickupAnimal.isValid then
        local _oldValid2 = ISPickupAnimal.isValid
        function ISPickupAnimal:isValid()
            if not _oldValid2(self) then return false end
            return _validateAnimalAction(self.character, self.animal, "pickup")
        end
    end
    
    if ISPickupAnimal.start then
        local _oldStart2 = ISPickupAnimal.start
        function ISPickupAnimal:start()
            if not _validateAnimalAction(self.character, self.animal, "pickup") then
                self:forceStop()
                return
            end
            _oldStart2(self)
        end
    end
    
    if ISPickupAnimal.perform then
        local _oldPerform2 = ISPickupAnimal.perform
        function ISPickupAnimal:perform()
            if not _validateAnimalAction(self.character, self.animal, "pickup") then
                self:forceStop()
                return
            end
            _oldPerform2(self)
        end
    end
end

-- [FIX-5] Patch: Slaughter / Kill animal
pcall(require, "TimedActions/Animals/ISSlaughterAnimal")
if ISSlaughterAnimal then
    AACS.Log("Patching ISSlaughterAnimal...")
    
    if ISSlaughterAnimal.isValid then
        local _oldValidKill = ISSlaughterAnimal.isValid
        function ISSlaughterAnimal:isValid()
            if not _oldValidKill(self) then return false end
            return _validateAnimalAction(self.character, self.animal, "kill")
        end
    end
    
    if ISSlaughterAnimal.start then
        local _oldStartKill = ISSlaughterAnimal.start
        function ISSlaughterAnimal:start()
            if not _validateAnimalAction(self.character, self.animal, "kill") then
                self:forceStop()
                return
            end
            _oldStartKill(self)
        end
    end
    
    if ISSlaughterAnimal.perform then
        local _oldPerformKill = ISSlaughterAnimal.perform
        function ISSlaughterAnimal:perform()
            if not _validateAnimalAction(self.character, self.animal, "kill") then
                self:forceStop()
                return
            end
            _oldPerformKill(self)
        end
    end
end

-- [FIX-5] Patch: ISKillAnimal (alternative class name in some B42 builds)
pcall(require, "TimedActions/Animals/ISKillAnimal")
if ISKillAnimal then
    AACS.Log("Patching ISKillAnimal...")
    
    if ISKillAnimal.isValid then
        local _oldValidKill2 = ISKillAnimal.isValid
        function ISKillAnimal:isValid()
            if not _oldValidKill2(self) then return false end
            return _validateAnimalAction(self.character, self.animal, "kill")
        end
    end
    
    if ISKillAnimal.start then
        local _oldStartKill2 = ISKillAnimal.start
        function ISKillAnimal:start()
            if not _validateAnimalAction(self.character, self.animal, "kill") then
                self:forceStop()
                return
            end
            _oldStartKill2(self)
        end
    end
    
    if ISKillAnimal.perform then
        local _oldPerformKill2 = ISKillAnimal.perform
        function ISKillAnimal:perform()
            if not _validateAnimalAction(self.character, self.animal, "kill") then
                self:forceStop()
                return
            end
            _oldPerformKill2(self)
        end
    end
end

-----------------------------------------------------------------------
-- [FIX-4/RESTAMP] Server-side: periodically re-stamp animals that lost
-- modData during pickup/drop cycles. This runs only on server.
-----------------------------------------------------------------------
if isServer() then
    local function _isAnimalObject(o)
        if not o then return false end
        local isA = false
        pcall(function() isA = instanceof(o, "IsoAnimal") end)
        if isA then return true end
        local isBlack = false
        pcall(function()
            isBlack = instanceof(o, "IsoZombie") or instanceof(o, "IsoPlayer") or
                      instanceof(o, "IsoSurvivor") or instanceof(o, "IsoVehicle") or
                      instanceof(o, "IsoDeadBody")
        end)
        if isBlack then return false end
        local isMoving = false
        pcall(function() isMoving = instanceof(o, "IsoMovingObject") end)
        if isMoving and o.isAnimal and type(o.isAnimal) == "function" then
            local ok2, res = pcall(function() return o:isAnimal() end)
            if ok2 and res == true then return true end
        end
        return false
    end

    local function _getAnimalBestName(animal)
        if not animal then return nil end
        local function safeCall(fn)
            local ok2, res = pcall(fn)
            if ok2 and res ~= nil then
                local s = tostring(res)
                if s ~= "" then return s end
            end
            return nil
        end
        return safeCall(function() return animal:getFullName() end)
            or safeCall(function() return animal:getDisplayName() end)
            or safeCall(function() return animal:getName() end)
    end

    local function _normName(s)
        if not s then return nil end
        s = tostring(s):gsub("<[^>]+>", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        return s:lower()
    end

    --- Re-stamp animals: if an animal near a registry entry's location has NO
    --- claim modData, re-apply it from the registry. This fixes the pickup/drop
    --- bug where modData is lost when the IsoAnimal is recreated.
    function AACS.RestampAnimalsFromRegistry()
        local cell = getCell()
        if not cell then return end
        local reg = ModData.getOrCreate(AACS.REGISTRY_KEY)
        if not reg then return end

        local restamped = 0

        for uid, entry in pairs(reg) do
            if entry and entry.LastX and entry.LastY and entry.LastZ then
                local ex = tonumber(entry.LastX) or 0
                local ey = tonumber(entry.LastY) or 0
                local ez = tonumber(entry.LastZ) or 0

                -- Search in a radius around last known position (reduced to 4 for safety)
                for dx = -4, 4 do
                    for dy = -4, 4 do
                        local sq = cell:getGridSquare(ex + dx, ey + dy, ez)
                        if sq then
                            local mov = sq.getMovingObjects and sq:getMovingObjects() or nil
                            if mov then
                                for i = 0, mov:size() - 1 do
                                    local o = mov:get(i)
                                    if _isAnimalObject(o) then
                                        local existingUID = AACS.GetAnimalUID(o)
                                        if not existingUID then
                                            -- Animal has no claim data. Check if it matches this entry by name/type.
                                            local anName = _normName(_getAnimalBestName(o))
                                            local entryName = _normName(entry.AnimalName)
                                            local match = false
                                            
                                            if anName and entryName then
                                                if anName == entryName then
                                                    match = true
                                                elseif anName:find(entryName, 1, true) or entryName:find(anName, 1, true) then
                                                    match = true
                                                end
                                            end
                                            
                                            -- Use stricter type matching
                                            if not match and entry.AnimalType then
                                                local anType = nil
                                                pcall(function() anType = tostring(o:getAnimalType()):lower() end)
                                                if anType and anType ~= "" then
                                                    local entryType = tostring(entry.AnimalType):lower()
                                                    if entryType ~= "animal" and entryType:find(anType, 1, true) then
                                                        match = true
                                                    end
                                                end
                                            end
                                            
                                            if match then
                                                -- Re-stamp the animal with claim data
                                                AACS.SetAnimalClaimModData(o, entry)
                                                -- Update last known position
                                                local anSq = o:getSquare()
                                                if anSq then
                                                    entry.LastX = anSq:getX()
                                                    entry.LastY = anSq:getY()
                                                    entry.LastZ = anSq:getZ()
                                                end
                                                entry.LastSeen = AACS.Now()
                                                reg[uid] = entry
                                                restamped = restamped + 1
                                                AACS.Log(string.format("RESTAMP: Re-applied claim UID=%s to animal '%s' at %d,%d,%d",
                                                    uid, entry.AnimalName or "?", ex+dx, ey+dy, ez))
                                            end
                                        elseif existingUID == uid then
                                            -- Animal already stamped with this UID; update position
                                            local anSq = o:getSquare()
                                            if anSq then
                                                entry.LastX = anSq:getX()
                                                entry.LastY = anSq:getY()
                                                entry.LastZ = anSq:getZ()
                                                reg[uid] = entry
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if restamped > 0 then
            AACS.Log("Restamp pass: re-applied claim data to " .. tostring(restamped) .. " animal(s).")
            if ModData and ModData.transmit then
                ModData.transmit(AACS.REGISTRY_KEY)
            end
        end
    end

    -- Hook into EveryTenMinutes (same timer the expiry check uses)
    local function _aacsRestampTick()
        pcall(AACS.RestampAnimalsFromRegistry)
    end
    Events.EveryTenMinutes.Add(_aacsRestampTick)
end
