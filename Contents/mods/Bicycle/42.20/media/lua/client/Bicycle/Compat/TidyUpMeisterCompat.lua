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
