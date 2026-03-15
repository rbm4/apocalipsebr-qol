require "DAMN_MechOverlay";
--
--##########90fordF350ambulance##########
--
DAMN.MechOverlay:addParts({
    ["Base.90fordF350ambulance"] = "90fordF350ambulance_",
    ["Base.90fordF350SWAT"] = "90fordF350ambulance_",
}, {
    Battery = {img="battery", x=228,y=113,x2=270,y2=144},
    --
    SuspensionFrontLeft = {img="suspension_front_left", x=13,y=153,x2=55,y2=191},
    SuspensionFrontRight = {img="suspension_front_right", x=228,y=153,x2=270,y2=191},
    SuspensionRearLeft = {img="suspension_rear_left", x=13,y=367,x2=55,y2=406},
    SuspensionRearRight = {img="suspension_rear_right", x=228,y=367,x2=270,y2=406},
    --
    BrakeFrontLeft = {img="brake_front_left", x=14,y=191,x2=55,y2=228},
    BrakeFrontRight = {img="brake_front_right", x=228,y=191,x2=270,y2=228},
    BrakeRearLeft = {img="brake_rear_left", x=13,y=406,x2=55,y2=441},
    BrakeRearRight = {img="brake_rear_right", x=228,y=406,x2=270,y2=441},
    --
    TireFrontLeft = {img="wheel_front_left", x=13,y=228,x2=55,y2=268},
    TireFrontRight = {img="wheel_front_right", x=228,y=228,x2=270,y2=268},
    TireRearLeft = {img="wheel_rear_left", x=13,y=441,x2=55,y2=481},
    TireRearRight = {img="wheel_rear_right", x=228,y=441,x2=270,y2=481},
    --
    DoorFrontLeft = {img="door_front_left", x=86,y=190,x2=89,y2=252},
    DoorFrontRight = {img="door_front_right", x=193,y=190,x2=197,y2=252},
    --
    Engine = {img="engine", x=141,y=106,x2=190,y2=184},
    --
    EngineDoor = {img="hood", x=92,y=106,x2=141,y2=184},
    --
    WindowFrontLeft = {img="window_front_left", x=89,y=202,x2=97,y2=252},
    WindowFrontRight = {img="window_front_right", x=186,y=202,x2=193,y2=252},
    --
    Windshield = {img="window_windshield", x=97,y=185,x2=185,y2=211},
    --
    GasTank = {img="gastank", x=13,y=537,x2=71,y2=574},
    --
    Muffler = {img="muffler", x=199,y=537,x2=270,y2=575},
    --
    DAMNBumperFront = {img="bullbar", x=97,y=27,x2=139,y2=64},
    DAMNWindshieldArmor = {img="windshield_armor", x=144,y=27,x2=185,y2=64},
    DAMNFrontLeftArmor = {img="window_front_left_armor", x=13,y=278,x2=55,y2=316},
    DAMNFrontRightArmor = {img="window_front_right_armor", x=228,y=278,x2=270,y2=316},
    DAMNRearRightArmor = {img="window_rear_right_armor", x=228,y=320,x2=270,y2=356},
    DAMNWindshieldRearArmor = {img="windshield_rear_armor", x=120,y=537,x2=163,y2=574},
}, 10, 10);