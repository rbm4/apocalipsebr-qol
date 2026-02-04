require "DAMN_MechOverlay";
--
--##########TrailerM101A3cargo##########
--
DAMN.MechOverlay:addParts({
    ["Base.TrailerM101A3cargo"] = "TrailerM101A3cargo_",
}, {
    SuspensionFrontLeft = {img="suspension_front_left", x=13,y=188,x2=55,y2=225},
    SuspensionFrontRight = {img="suspension_front_right", x=228,y=188,x2=270,y2=225},
    --
    TireFrontLeft = {img="wheel_front_left", x=13,y=225,x2=55,y2=263},
    TireFrontRight = {img="wheel_front_right", x=228,y=225,x2=270,y2=263},
    --
    TrunkDoor = {img="trunk", x=94,y=289,x2=187,y2=294},
}, 10, 0);
--