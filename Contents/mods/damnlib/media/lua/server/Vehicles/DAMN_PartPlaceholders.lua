--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

DAMN = DAMN or {};
DAMN.Create = DAMN.Create or {};
DAMN.InstallTest = DAMN.InstallTest or {};
DAMN.UninstallTest = DAMN.UninstallTest or {};

-- empty part placeholder


function DAMN.Create.Blank(vehicle, part)
	part:setInventoryItem(nil);
end

-- part requirement check placeholder

function DAMN.InstallTest.Default(vehicle, part, chr)
    if ISVehicleMechanics.cheat then return true end

    local keyvalues = part:getTable("install")
    if not keyvalues then return false end
    if part:getInventoryItem() then return false end
    if not part:getItemType() or part:getItemType():isEmpty() then return false end

    local typeToItem, tagToItem = VehicleUtils.getItems(chr:getPlayerNum())
    typeToItem = typeToItem or {}
    tagToItem = tagToItem or typeToItem.tag or typeToItem.tags or {}

    if keyvalues.requireInstalled then
        for _,v in ipairs(keyvalues.requireInstalled:split(";")) do
            if not vehicle:getPartById(v) or not vehicle:getPartById(v):getInventoryItem() then
                return false
            end
        end
    end

    if not VehicleUtils.testProfession(chr, keyvalues.professions) then return false end
    if not VehicleUtils.testRecipes(chr, keyvalues.recipes) then return false end
    if not VehicleUtils.testTraits(chr, keyvalues.traits) then return false end

    if not VehicleUtils.testItems(chr, keyvalues.items, typeToItem, tagToItem) then return false end

    if VehicleUtils.RequiredKeyNotFound(part, chr) then return false end

    return true
end


function DAMN.UninstallTest.Default(vehicle, part, chr)
    if ISVehicleMechanics.cheat then return true end

    local keyvalues = part:getTable("uninstall")
    if not keyvalues then return false end
    if not part:getInventoryItem() then return false end
    if not part:getItemType() or part:getItemType():isEmpty() then return false end

    local typeToItem, tagToItem = VehicleUtils.getItems(chr:getPlayerNum())
    typeToItem = typeToItem or {}
    tagToItem = tagToItem or typeToItem.tag or typeToItem.tags or {}

    if keyvalues.requireUninstalled then
        local split = keyvalues.requireUninstalled:split(";")
        for _,v in ipairs(split) do
            if vehicle:getPartById(v) and vehicle:getPartById(v):getInventoryItem() then
                return false
            end
        end
    end

    if not VehicleUtils.testProfession(chr, keyvalues.professions) then return false end
    if not VehicleUtils.testRecipes(chr, keyvalues.recipes) then return false end
    if not VehicleUtils.testTraits(chr, keyvalues.traits) then return false end

    if not VehicleUtils.testItems(chr, keyvalues.items, typeToItem, tagToItem) then return false end

    if keyvalues.requireEmpty and round(part:getContainerContentAmount(), 3) > 0 then return false end

    local seatNumber = part:getContainerSeatNumber()
    local seatOccupied = (seatNumber ~= -1) and vehicle:isSeatOccupied(seatNumber)
    if keyvalues.requireEmpty and seatOccupied then return false end

    if VehicleUtils.RequiredKeyNotFound(part, chr) then return false end

    return true
end