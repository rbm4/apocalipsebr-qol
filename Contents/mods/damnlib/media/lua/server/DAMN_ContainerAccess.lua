--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

DAMN = DAMN or {};
DAMN.ContainerAccess = DAMN.ContainerAccess or {};

function DAMN.ContainerAccess.Gunrack(vehicle, part, chr)
	if chr:getVehicle() == vehicle then
		local seat = vehicle:getSeat(chr)
		return seat == 1 or seat == 0;
	elseif chr:getVehicle() then
		return false
	else
		if not vehicle:isInArea(part:getArea(), chr) then return false end
		local doorPart = vehicle:getPartById("DoorFrontRight")
		if doorPart and doorPart:getDoor() and not doorPart:getDoor():isOpen() then
			return false
		end
		return true
	end
end

function DAMN.ContainerAccess.Roofrack(vehicle, part, chr)
    if chr:getVehicle() then return false end
    if not vehicle:isInArea(part:getArea(), chr) then return false end

    local item = part:getInventoryItem()
    if not item then return false end

    local maxCap
    if item.getMaxCapacity then
        maxCap = item:getMaxCapacity()
    else
        maxCap = nil
    end

    if maxCap == nil or maxCap <= 0 then
        return false
    end

    return true
end

function DAMN.ContainerAccess.TruckBed2(vehicle, part, chr)
	if chr:getVehicle() then return false end
	if not vehicle:isInArea(part:getArea(), chr) then return false end
	local doorPart = vehicle:getPartById("TrunkDoor2")
	if doorPart and doorPart:getDoor() then
		if not doorPart:getInventoryItem() then return true end
		if not doorPart:getDoor():isOpen() then return false end
	end
	--
	return true
end

function DAMN.ContainerAccess.TrunkInner(vehicle, part, chr)
    if chr:getVehicle() == vehicle then
        local seat = vehicle:getSeat(chr)
        return seat >= 0;
    elseif chr:getVehicle() then
        return false
    else
        if not vehicle:isInArea(part:getArea(), chr) then return false end
        local doorPart = vehicle:getPartById("TrunkDoor")
        if doorPart and doorPart:getInventoryItem() then
            if doorPart:getDoor() and not doorPart:getDoor():isOpen() then
                return false
            end
        end
        local rearDoor = vehicle:getPartById("DoorRear")
        if rearDoor and rearDoor:getInventoryItem() then
            if rearDoor:getDoor() and not rearDoor:getDoor():isOpen() then
                return false
            end
        end
        return true
    end
end

function DAMN.ContainerAccess.TrunkSecondRow(vehicle, part, chr)
	if chr:getVehicle() == vehicle then
		local seat = vehicle:getSeat(chr)
		return seat == 3 or seat == 2;
	elseif chr:getVehicle() then
		return false
	else
        if not vehicle:isInArea(part:getArea(), chr) then return false end
        local doorPart = vehicle:getPartById("TrunkDoor")
        if doorPart and doorPart:getInventoryItem() then
            if doorPart:getDoor() and not doorPart:getDoor():isOpen() then
                return false
            end
        end
        local rearDoor = vehicle:getPartById("DoorRear")
        if rearDoor and rearDoor:getInventoryItem() then
            if rearDoor:getDoor() and not rearDoor:getDoor():isOpen() then
                return false
            end
        end
        return true
    end
end

function DAMN.ContainerAccess.TrunkThirdRow(vehicle, part, chr)
	if chr:getVehicle() == vehicle then
		local seat = vehicle:getSeat(chr)
		return seat == 5 or seat == 4;
	elseif chr:getVehicle() then
		return false
	else
        if not vehicle:isInArea(part:getArea(), chr) then return false end
        local doorPart = vehicle:getPartById("TrunkDoor")
        if doorPart and doorPart:getInventoryItem() then
            if doorPart:getDoor() and not doorPart:getDoor():isOpen() then
                return false
            end
        end
        local rearDoor = vehicle:getPartById("DoorRear")
        if rearDoor and rearDoor:getInventoryItem() then
            if rearDoor:getDoor() and not rearDoor:getDoor():isOpen() then
                return false
            end
        end
        return true
    end
end

function DAMN.ContainerAccess.ToolboxLeft(vehicle, part, chr)
	if chr:getVehicle() then return false end
	if not vehicle:isInArea(part:getArea(), chr) then return false end
	local doorPart = vehicle:getPartById("ToolboxLidLeft")
	if doorPart and doorPart:getDoor() then
		if not doorPart:getInventoryItem() then return true end
		if not doorPart:getDoor():isOpen() then return false end
	end
	--
	return true
end

function DAMN.ContainerAccess.ToolboxRight(vehicle, part, chr)
	if chr:getVehicle() then return false end
	if not vehicle:isInArea(part:getArea(), chr) then return false end
	local doorPart = vehicle:getPartById("ToolboxLidRight")
	if doorPart and doorPart:getDoor() then
		if not doorPart:getInventoryItem() then return true end
		if not doorPart:getDoor():isOpen() then return false end
	end
	--
	return true
end

function DAMN.ContainerAccess.NoStorage(vehicle, part, chr)
    return false
end
