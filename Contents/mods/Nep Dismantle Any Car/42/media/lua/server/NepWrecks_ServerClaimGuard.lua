-- The B42 networked timed-action system reconstructs ISRemoveBurntVehicle on
-- the server and invokes complete() there.  A modified client can bypass menu
-- and isValid() checks, so the final destructive operation must be guarded at
-- this server-owned boundary.
require "NepWrecks_DismantleAction"
require "VehicleClaim_ServerCommands"

local originalComplete = ISRemoveBurntVehicle.complete

function ISRemoveBurntVehicle:complete()
    local vehicle = self.vehicle
    if not vehicle then
        return false
    end

    -- The global registry is the authority.  Do not trust the claim table
    -- copied into vehicle ModData, because clients receive a copy of it.
    if not VehicleClaim or not VehicleClaim.getServerRegistryClaim then
        print("NepWrecks: VehicleClaim registry unavailable. Dismantle blocked.")
        return false
    end
    local entry, vehicleHash = VehicleClaim.getServerRegistryClaim(vehicle)
    if entry then
        local playerName = self.character and self.character:getUsername() or "unknown"
        local ownerName = entry and entry.ownerName or "unknown"

        VehicleClaim.log(string.format(
            "[SECURITY] Blocked vehicle dismantle: player=%s vehicleHash=%s owner=%s",
            tostring(playerName), tostring(vehicleHash), tostring(ownerName)))
        return false
    end

    return originalComplete(self)
end
