--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

require "Vehicles/TimedActions/ISEnterVehicle";

local orgEnterVehicleStart = ISEnterVehicle["start"];

ISEnterVehicle["start"] = function(self)
    if DAMN:vehicleIsManaged(self["vehicle"]:getScript():getFullName())
    then
        -- original code from Vehicles/TimedActions/ISEnterVehicle.lua start
            if not isServer() then
                local playerNum = self.character:getPlayerNum()
                getCell():setDrag(nil, playerNum)
                local contextMenu = getPlayerContextMenu(playerNum)
                if contextMenu and contextMenu:isAnyVisible() then
                    contextMenu:hideAndChildren()
                end
            end
            self.started = true
            local outside = self.vehicle:getPassengerPosition(self.seat, "outside")
            local worldPos = Vector3f.new()
            self.vehicle:getWorldPos(outside:getOffset(), worldPos)
        -- original code from Vehicles/TimedActions/ISEnterVehicle.lua end

        -- use a distance calculation method that does not operate with grid / int coordinates
            -- if self.character:DistTo(worldPos:x(), worldPos:y()) > 2 then
            if math.sqrt(self.character:DistToSquared(worldPos:x(), worldPos:y())) > 2 then
                return
            end

        -- original code from Vehicles/TimedActions/ISEnterVehicle.lua continued
            self.action:setBlockMovementEtc(true) -- ignore 'E' while entering
            self.vehicle:enter(self.seat, self.character)
            self.vehicle:playPassengerSound(self.seat, "enter")
            self.character:SetVariable("bEnteringVehicle", "true")
            self.character:triggerMusicIntensityEvent("VehicleEnter")
            if (self.character:getPrimaryHandItem() and self.character:getPrimaryHandItem():hasTag(ItemTag.HEAVY_ITEM)) or (self.character:getSecondaryHandItem() and self.character:getSecondaryHandItem():hasTag(ItemTag.HEAVY_ITEM)) then
                if isClient() then
                    local args = { id = self.character:getOnlineID() }
                    sendClientCommand(self.character, 'player', 'onDropHeavyItem', args)
                else
                    forceDropHeavyItems(self.character)
                end
            end
        -- original code from Vehicles/TimedActions/ISEnterVehicle.lua end
    else
        orgEnterVehicleStart(self);
    end
end