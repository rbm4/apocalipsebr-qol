require "DAMN_MechOverlay";
--
--##########85chevyStepVan##########
--
DAMN.MechOverlay:addParts({
    ["Base.85chevyStepVan"] = "85chevyStepVan_",
    ["Base.85chevyStepVanSWAT"] = "85chevyStepVan_",
}, {
    Battery = {img="battery", x=14,y=103,x2=54,y2=134},
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
    TireFrontLeft = {img="wheel_front_left", x=13,y=218,x2=55,y2=256},
    TireFrontRight = {img="wheel_front_right", x=228,y=218,x2=270,y2=256},
    TireRearLeft = {img="wheel_rear_left", x=13,y=431,x2=55,y2=471},
    TireRearRight = {img="wheel_rear_right", x=228,y=431,x2=270,y2=471},
    --
    DoorFrontLeft = {img="door_front_left", x=76,y=192,x2=80,y2=251},
    DoorFrontRight = {img="door_front_right", x=202,y=192,x2=207,y2=251},
    --
    Engine = {img="engine", x=91,y=34,x2=191,y2=96},
    --
    EngineDoor = {img="hood", x=90,y=133,x2=191,y2=161},
    --
    TrunkDoor = {img="trunk", x=109,y=466,x2=174,y2=469},
    --
    Windshield = {img="window_windshield", x=81,y=165,x2=200,y2=179},
    --
    GasTank = {img="gastank", x=14,y=478,x2=50,y2=535},
    --
    Muffler = {img="muffler", x=61,y=527,x2=131,y2=564},
    --
    DAMNBumperFront = {img="bullbar", x=227,y=54,x2=269,y2=92},
    DAMNWindshieldArmor = {img="windshield_armor", x=227,y=98,x2=269,y2=135},
    DAMNFrontLeftArmor = {img="window_front_left_armor", x=13,y=268,x2=55,y2=306},
    DAMNFrontRightArmor = {img="window_front_right_armor", x=228,y=268,x2=270,y2=306},
    DAMNWindshieldRearArmor = {img="windshield_rear_armor", x=228,y=478,x2=270,y2=516},
}, 10, 0);
--