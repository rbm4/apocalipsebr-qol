--***********************************************************
--**                   KI5 / bikinihorst                   **
--***********************************************************

require "Hooks/DAMN_EnterAnimations";

DAMN = DAMN or {};
DEF89 = DEF89 or {};
DEF89.truckBedAddon = {};

function DEF89.truckBedAddon.Open(vehicle, part, chr)

    local vanillaOpen = ISOpenVehicleDoor["start"];

    ISOpenVehicleDoor["start"] = function(self)

        local vehicle = self.vehicle
        local trunkDoor = vehicle:getPartById("TrunkDoor")
        local trunkCover = vehicle:getPartById("DEF89TruckBedAddon")

        if vehicle and trunkDoor and self.part:getId() == "TrunkDoor" and trunkCover and (
            string.find( vehicle:getScriptName(), "89defender130" ) or
            string.find( vehicle:getScriptName(), "Trailer89defender" )) then

            vehicle:playPartAnim(trunkCover, "Open")
            vehicle:playPartSound(trunkCover, character, "Open")
            trunkCover:getDoor():setOpen(true)
            vehicle:transmitPartDoor(trunkCover)
        end
        
    vanillaOpen(self);

    end
end

function DEF89.truckBedAddon.Close(vehicle, part, chr)

    local vanillaClose = ISCloseVehicleDoor["start"];

    ISCloseVehicleDoor["start"] = function(self)

        local vehicle = self.vehicle
        local trunkDoor = vehicle:getPartById("TrunkDoor")
        local trunkCover = vehicle:getPartById("DEF89TruckBedAddon")

        if vehicle and trunkDoor and self.part:getId() == "TrunkDoor" and trunkCover and (
            string.find( vehicle:getScriptName(), "89defender130" ) or
            string.find( vehicle:getScriptName(), "Trailer89defender" )) then

            vehicle:playPartAnim(trunkCover, "Close")
            vehicle:playPartSound(trunkCover, character, "Close")
            trunkCover:getDoor():setOpen(false)
            vehicle:transmitPartDoor(trunkCover)
        end
        
    vanillaClose(self);

    end
end

Events.OnGameStart.Add(DEF89.truckBedAddon.Open);
Events.OnGameStart.Add(DEF89.truckBedAddon.Close);