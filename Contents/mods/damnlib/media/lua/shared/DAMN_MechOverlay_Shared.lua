--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

DAMN = DAMN or {};
DAMN.MechOverlay = DAMN.MechOverlay or {};

function DAMN.MechOverlay:addParts(scriptAndImgPrefix, partLocations, mainX, mainY)
    if not ISCarMechanicsOverlay or not ISCarMechanicsOverlay.CarList or not ISCarMechanicsOverlay.PartList
    then
        return false;
    end

    for fullScript, imgPrefix in pairs(scriptAndImgPrefix)
    do
        ISCarMechanicsOverlay.CarList[fullScript] = ISCarMechanicsOverlay.CarList[fullScript] or {}

        ISCarMechanicsOverlay.CarList[fullScript]["imgPrefix"] = imgPrefix;
        ISCarMechanicsOverlay.CarList[fullScript]["x"] = ISCarMechanicsOverlay.CarList[fullScript]["x"]
            and ISCarMechanicsOverlay.CarList[fullScript]["x"]
            or (mainX or 0);
        ISCarMechanicsOverlay.CarList[fullScript]["y"] = ISCarMechanicsOverlay.CarList[fullScript]["y"]
            and ISCarMechanicsOverlay.CarList[fullScript]["y"]
            or (mainY or 0);

        for partName, config in pairs(partLocations)
        do
            ISCarMechanicsOverlay.PartList[partName] = ISCarMechanicsOverlay.PartList[partName] or {};
            ISCarMechanicsOverlay.PartList[partName]["vehicles"] = ISCarMechanicsOverlay.PartList[partName]["vehicles"] or {};
            ISCarMechanicsOverlay.PartList[partName]["vehicles"][imgPrefix] = ISCarMechanicsOverlay.PartList[partName]["vehicles"][imgPrefix] or {};

            for k, v in pairs(config)
            do
                if k == "img" and not ISCarMechanicsOverlay.PartList[partName][k]
                then
                    ISCarMechanicsOverlay.PartList[partName][k] = v;
                end

                ISCarMechanicsOverlay.PartList[partName]["vehicles"][imgPrefix][k] = v;
            end
        end
    end
end