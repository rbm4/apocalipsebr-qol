-- Tidy Up Meister (workshop 2769706949) watches a timed-action queue and, on the assumption that any
-- equipment or container change was temporary preparation, restores the player's hands and worn slots
-- and moves transferred items back to their source container once the queue drains.
--
-- Every Bicycle action below ends in an INTENTIONAL final state: mounting equips the bike in both
-- hands, dismounting clears them, throwing puts the bike over a fence, attach/detach moves a part
-- between the player and the bike, and the sidecar actions move an animal in or out. Registering each
-- as `ignore` stops it arming a restore session, so none of that gets undone.
--
-- `ignore` short-circuits the policy read in P4TidyUpMeister.observeAction, so no other policy field
-- (restoreHands / restoreWorn / restoreOnCancel / queueRestoreOnCancel) has any effect next to it.
--
-- Optional: nothing here depends on Tidy Up Meister being installed. Registration runs on OnGameStart
-- so it never depends on Lua file load order.

Bicycle = Bicycle or {}
Bicycle.TidyUpMeisterCompat = Bicycle.TidyUpMeisterCompat or {}

Bicycle.TidyUpMeisterCompat.IGNORED_ACTION_TYPES = {
    "BicycleHopOnAction",
    "BicycleDismountAction",
    "BicycleThrowOverFenceAction",
    "BicycleAttachPartAction",
    "BicycleDetachPartAction",
    "BicycleStowAnimalAction",
    "BicycleReleaseAnimalAction",
}

-- Read through _G at call time: the global only exists when Tidy Up Meister is installed, and it is
-- published by a mod whose load order relative to this file is not guaranteed.
---@return number
function Bicycle.TidyUpMeisterCompat.register()
    local tidyUpMeister = _G["P4TidyUpMeister"]
    if type(tidyUpMeister) ~= "table" or type(tidyUpMeister.registerActionPolicy) ~= "function" then
        return 0
    end

    local actionTypes = Bicycle.TidyUpMeisterCompat.IGNORED_ACTION_TYPES
    local registered = 0
    for i = 1, #actionTypes do
        if tidyUpMeister.registerActionPolicy(actionTypes[i], { ignore = true }) then
            registered = registered + 1
        end
    end

    return registered
end

Events.OnGameStart.Add(Bicycle.TidyUpMeisterCompat.register)
