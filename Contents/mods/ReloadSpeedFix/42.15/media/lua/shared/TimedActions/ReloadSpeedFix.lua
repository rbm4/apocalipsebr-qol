-- =============================================================================
-- Reload Speed Fix [B42]
-- =============================================================================


require "TimedActions/ISReloadWeaponAction"
require "TimedActions/ISLoadBulletsInMagazine"
require "TimedActions/ISUnloadBulletsFromMagazine"

local MAGAZINE_INSERT_SOUND = "MagazineInsertAmmo"
local MAGAZINE_EJECT_SOUND = "MagazineEjectAmmo"

local originalLoadBulletsAnimEvent = ISLoadBulletsInMagazine.animEvent
local originalUnloadBulletsAnimEvent = ISUnloadBulletsFromMagazine.animEvent

local function playLoopSoundFallback(self, soundName)
    if self.reloadSpeedFixLoopSoundPlayed or not soundName or soundName == "" then
        return
    end
    self.character:playSound(soundName)
    self.reloadSpeedFixLoopSoundPlayed = true
end

local function scaledUpdateLoadingTime(self, loopResetKey)
    local animTimeDeltaR = 0
    local animTimeDelta = self.character:getAnimationTimeDelta() 
    local reloadSpeed = self.character:getVariableFloat("ReloadSpeed", 0.8)
    if reloadSpeed > 0 then
        animTimeDeltaR = animTimeDelta * reloadSpeed
    end
    local oldUpdateLoadBulletsTime = self.updateLoadBulletsTime
    self.updateLoadBulletsTime = (self.updateLoadBulletsTime + animTimeDeltaR) % 0.5 -- <--- 1.0 -> 0.5 to match the TimePc=0.5 event thresholds in the XML clips
    if oldUpdateLoadBulletsTime > self.updateLoadBulletsTime then
        self[loopResetKey] = false
        self.reloadSpeedFixLoopSoundPlayed = false
    end
    self.character:setVariable("UpdateLoadBulletsTime", self.updateLoadBulletsTime)
end

ISLoadBulletsInMagazine.updateLoadingTime = function(self)
    scaledUpdateLoadingTime(self, "loadedThisLoop")
end

ISUnloadBulletsFromMagazine.updateLoadingTime = function(self)
    scaledUpdateLoadingTime(self, "unloadedThisLoop")
end

ISLoadBulletsInMagazine.animEvent = function(self, event, parameter)
    local shouldMarkLoopSoundPlayed = false
    local loadedThisLoopBeforeEvent = self.loadedThisLoop

    if event == "InsertBulletSound" then
        shouldMarkLoopSoundPlayed = not self:isLoadFinished() and (not self:isLocal() or not self.loadedThisLoop)
    end

    originalLoadBulletsAnimEvent(self, event, parameter)

    if shouldMarkLoopSoundPlayed then
        self.reloadSpeedFixLoopSoundPlayed = true
        return
    end

    if event == "InsertBullet" and not loadedThisLoopBeforeEvent and self.loadedThisLoop then
        playLoopSoundFallback(self, MAGAZINE_INSERT_SOUND)
    elseif event == "loadFinished" and self.loadFinished then
        self.reloadSpeedFixLoopSoundPlayed = false
    end
end

ISUnloadBulletsFromMagazine.animEvent = function(self, event, parameter)
    local shouldMarkLoopSoundPlayed = false
    local unloadedThisLoopBeforeEvent = self.unloadedThisLoop

    if event == "RemoveBulletSound" then
        shouldMarkLoopSoundPlayed = self.magazine:getCurrentAmmoCount() > 0 and (not self:isLocal() or not self.unloadedThisLoop)
    end

    originalUnloadBulletsAnimEvent(self, event, parameter)

    if shouldMarkLoopSoundPlayed then
        self.reloadSpeedFixLoopSoundPlayed = true
        return
    end

    if event == "RemoveBullet" and not unloadedThisLoopBeforeEvent and self.unloadedThisLoop then
        playLoopSoundFallback(self, MAGAZINE_EJECT_SOUND)
    elseif event == "unloadFinished" and self.unloadFinished then
        self.reloadSpeedFixLoopSoundPlayed = false
    end
end
