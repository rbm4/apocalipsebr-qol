require "DAMN_MechOverlay";
--
--##########88toyotaHilux##########
--
DAMN.MechOverlay:addParts({
    ["Base.88toyotaHiluxSC"] = "88toyotaHilux_",
    ["Base.88toyotaHiluxXC"] = "88toyotaHilux_",
    ["Base.88toyotaHiluxXCS"] = "88toyotaHilux_",
}, {
    Battery = {img="battery", x=228,y=111,x2=270,y2=143},
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
    DoorFrontLeft = {img="door_front_left", x=77,y=230,x2=84,y2=308},
    DoorFrontRight = {img="door_front_right", x=199,y=230,x2=205,y2=308},
    --
    Engine = {img="engine", x=141,y=134,x2=193,y2=211},
    --
    EngineDoor = {img="hood", x=89,y=134,x2=141,y2=211},
    --
    TrunkDoor = {img="trunk", x=86,y=475,x2=197,y2=480},
    --
    WindowFrontLeft = {img="window_front_left", x=84,y=259,x2=95,y2=308},
    WindowFrontRight = {img="window_front_right", x=188,y=259,x2=199,y2=308},
    --
    Windshield = {img="window_windshield", x=90,y=223,x2=195,y2=259},
    WindshieldRear = {img="window_rear_windshield", x=95,y=329,x2=188,y2=334},
    --
    GasTank = {img="gastank", x=13,y=537,x2=70,y2=575},
    --
    Muffler = {img="muffler", x=200,y=537,x2=269,y2=575},
    --
    DAMNBumperFront = {img="bullbar", x=95,y=25,x2=137,y2=63},
    DAMNBumperRear = {img="bullbarr", x=146,y=536,x2=187,y2=574},
    DAMNWindshieldArmor = {img="windshield_armor", x=144,y=25,x2=187,y2=63},
    DAMNFrontLeftArmor = {img="window_front_left_armor", x=13,y=278,x2=55,y2=316},
    DAMNFrontRightArmor = {img="window_front_right_armor", x=228,y=278,x2=270,y2=316},
    DAMNWindshieldRearArmor = {img="windshield_rear_armor", x=95,y=536,x2=137,y2=574},
}, 10, 10);
--