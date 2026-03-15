require "DAMN_MechOverlay";
--
--##########63beetle##########
--
DAMN.MechOverlay:addParts({
    ["Base.63beetle"] = "63beetle_",
    ["Base.63beetleHP"] = "63beetle_",
    ["Base.63beetleBuggy"] = "63beetle_",
}, {
    Battery = {img="battery", x=228,y=317,x2=270,y2=348},
    --
    HeadlightLeft = {img="headlight_left", x=83,y=141,x2=104,y2=157},
    HeadlightRight = {img="headlight_right", x=178,y=141,x2=200,y2=157};
    --
    SuspensionFrontLeft = {img="suspension_front_left", x=13,y=143,x2=55,y2=181},
    SuspensionFrontRight = {img="suspension_front_right", x=228,y=143,x2=270,y2=181},
    SuspensionRearLeft = {img="suspension_rear_left", x=13,y=357,x2=55,y2=396},
    SuspensionRearRight = {img="suspension_rear_right", x=228,y=357,x2=270,y2=396},
    --
    BrakeFrontLeft = {img="brake_front_left", x=14,y=181,x2=55,y2=218},
    BrakeFrontRight = {img="brake_front_right", x=228,y=181,x2=270,y2=218},
    BrakeRearLeft = {img="brake_rear_left", x=13,y=396,x2=55,y2=431},
    BrakeRearRight = {img="brake_rear_right", x=228,y=396,x2=270,y2=431},
    --
    TireFrontLeft = {img="wheel_front_left", x=13,y=218,x2=55,y2=258},
    TireFrontRight = {img="wheel_front_right", x=228,y=218,x2=270,y2=258},
    TireRearLeft = {img="wheel_rear_left", x=13,y=431,x2=55,y2=471},
    TireRearRight = {img="wheel_rear_right", x=228,y=431,x2=270,y2=471},
    --
    DoorFrontLeft = {img="door_front_left", x=81,y=239,x2=85,y2=317},
    DoorFrontRight = {img="door_front_right", x=196,y=239,x2=200,y2=317},
    --
    Engine = {img="engine", x=204,y=527,x2=269,y2=568},
    --
    EngineDoor = {img="hood", x=106,y=429,x2=175,y2=480},
    --
    TrunkDoor = {img="trunk", x=81,y=157,x2=200,y2=238},
    --
    WindowFrontLeft = {img="window_front_left", x=85,y=259,x2=92,y2=317},
    WindowFrontRight = {img="window_front_right", x=190,y=259,x2=196,y2=317},
    WindowRearLeft = {img="window_rear_left", x=85,y=328,x2=92,y2=384},
    WindowRearRight = {img="window_rear_right", x=190,y=328,x2=196,y2=384},
    --
    Windshield = {img="window_windshield", x=97,y=243,x2=185,y2=264},
    WindshieldRear = {img="window_rear_windshield", x=103,y=392,x2=179,y2=425},
    --
    GasTank = {img="gastank", x=13,y=48,x2=70,y2=87},
    --
    Muffler = {img="muffler", x=13,y=527,x2=83,y2=564},
    --
    DAMNBumperFront = {img="bullbar", x=98,y=48,x2=141,y2=86},
    DAMNBumperRear = {img="bullbarr", x=146,y=526,x2=187,y2=564},
    DAMNWindshieldArmor = {img="windshield_armor", x=144,y=48,x2=187,y2=86},
    DAMNFrontLeftArmor = {img="window_front_left_armor", x=13,y=268,x2=55,y2=306},
    DAMNFrontRightArmor = {img="window_front_right_armor", x=228,y=268,x2=270,y2=306},
    DAMNWindshieldRearArmor = {img="windshield_rear_armor", x=99,y=526,x2=140,y2=564},
}, 10, 0);
--