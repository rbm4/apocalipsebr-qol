local function info()

    ISCarMechanicsOverlay.CarList["Base.Biochemical_PickupTruck"] = {imgPrefix = "Biochemical_PickupTruck_", x=10,y=0};

end


-- Fix for Biochemical PickupTruck door staying open in multiplayer.
-- ISCloseVehicleDoor's NetTimedAction on the server has getDuration()=0 (immediate)
-- but may fail silently if start()/perform() deserialization is incomplete, or if
-- ISEnterVehicle action stalls due to showPassenger=false suppressing the enter
-- animation, preventing ISCloseVehicleDoor from ever being queued.
-- This sends a server command to force-close all open doors after the player enters.
local function onEnterBiochemicalTruck(player)
    if not isClient() then return end
    if player:getPlayerNum() < 0 then return end -- skip remote players
    local vehicle = player:getVehicle()
    if not vehicle then return end
    if vehicle:getScriptName() ~= "Base.Biochemical_PickupTruck" then return end
    sendClientCommand(player, "RaccoonCityCommand", "closeBiochemicalDoor", {})
end


Events.OnInitWorld.Add(info);
Events.OnEnterVehicle.Add(onEnterBiochemicalTruck);