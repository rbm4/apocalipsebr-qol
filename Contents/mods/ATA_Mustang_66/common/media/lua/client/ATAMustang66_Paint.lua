local oldISVehicleMenu = ISVehicleMenu.FillMenuOutsideVehicle

local paintTable = {}
paintTable["Base.ATAMustang66"] = 1
paintTable["Base.ATAMustang66Custom"] = 1

local paintBus = function(playerObj, vehicle, newSkinIndex)
    ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(playerObj, vehicle, "Engine"))
    ISTimedActionQueue.add(ISPaintBus:new(playerObj, vehicle, "Engine", newSkinIndex))
end

function ISVehicleMenu.FillMenuOutsideVehicle(player, context, vehicle, test)
    oldISVehicleMenu(player, context, vehicle, test)
    local playerObj = getSpecificPlayer(player)
    local playerInv = playerObj:getInventory()
    local paintBrush = playerInv:getFirstTypeRecurse("Paintbrush")
    if vehicle and paintBrush then
        if (paintTable[vehicle:getScriptName()]) and (vehicle:getSkinIndex()%2) ~= 1 then
            local paintCan = playerInv:getFirstTypeRecurse("PaintYellow")
            if paintCan then
                context:addOption(getText("ContextMenu_Vehicle_STRAYS"), playerObj, paintBus, vehicle, vehicle:getSkinIndex()+1)
            end
        end
    end
end


