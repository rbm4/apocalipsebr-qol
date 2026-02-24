require "Vehicles/ISUI/ISCarMechanicsOverlay"

ISCarMechanicsOverlay.CarList["Base.Biochemical_PickupTruck"] = {imgPrefix = "Biochemical_PickupTruck_", x=10,y=0};

ISCarMechanicsOverlay.PartList["TireFrontLeft"].vehicles["Biochemical_PickupTruck_"] = {x=30,y=170,x2=69,y2=260};
ISCarMechanicsOverlay.PartList["TireFrontRight"].vehicles["Biochemical_PickupTruck_"] = {x=222,y=170,x2=260,y2=260};
ISCarMechanicsOverlay.PartList["TireRearLeft"].vehicles["Biochemical_PickupTruck_"] = {x=30,y=394,x2=61,y2=490};
ISCarMechanicsOverlay.PartList["TireRearRight"].vehicles["Biochemical_PickupTruck_"] = {x=228,y=394,x2=259,y2=490};

ISCarMechanicsOverlay.PartList["WindowFrontLeft"].vehicles["Biochemical_PickupTruck_"] = {x=72,y=285,x2=78,y2=341};
ISCarMechanicsOverlay.PartList["WindowFrontRight"].vehicles["Biochemical_PickupTruck_"] = {x=215,y=285,x2=220,y2=341};
ISCarMechanicsOverlay.PartList["WindowRearLeft"].vehicles["Biochemical_PickupTruck_"] = {x=72,y=342,x2=78,y2=384};
ISCarMechanicsOverlay.PartList["WindowRearRight"].vehicles["Biochemical_PickupTruck_"] = {x=215,y=342,x2=220,y2=384};

ISCarMechanicsOverlay.PartList["DoorFrontLeft"].vehicles["Biochemical_PickupTruck_"] = {x=63,y=285,x2=71,y2=341};
ISCarMechanicsOverlay.PartList["DoorFrontRight"].vehicles["Biochemical_PickupTruck_"] = {x=221,y=285,x2=229,y2=341};
ISCarMechanicsOverlay.PartList["DoorRearLeft"].vehicles["Biochemical_PickupTruck_"] = {x=63,y=342,x2=71,y2=384};
ISCarMechanicsOverlay.PartList["DoorRearRight"].vehicles["Biochemical_PickupTruck_"] = {x=221,y=342,x2=229,y2=384};

ISCarMechanicsOverlay.PartList["EngineDoor"].vehicles["Biochemical_PickupTruck_"] = {x=71,y=118,x2=220,y2=244};
ISCarMechanicsOverlay.PartList["TruckBed"].vehicles["Biochemical_PickupTruck_"] = {x=63,y=438,x2=226,y2=501};

ISCarMechanicsOverlay.PartList["Windshield"].vehicles["Biochemical_PickupTruck_"] = {x=80,y=245,x2=210,y2=278};

ISCarMechanicsOverlay.PartList["BrakeFrontLeft"].vehicles["Biochemical_PickupTruck_"] = {x=12,y=80,x2=52,y2=118};
ISCarMechanicsOverlay.PartList["BrakeFrontRight"].vehicles["Biochemical_PickupTruck_"] = {x=230,y=80,x2=270,y2=118};
ISCarMechanicsOverlay.PartList["BrakeRearLeft"].vehicles["Biochemical_PickupTruck_"] = {x=12,y=537,x2=52,y2=575};
ISCarMechanicsOverlay.PartList["BrakeRearRight"].vehicles["Biochemical_PickupTruck_"] = {x=230,y=537,x2=270,y2=575};

ISCarMechanicsOverlay.PartList["SuspensionFrontLeft"].vehicles["Biochemical_PickupTruck_"] = {x=12,y=43,x2=52,y2=79};
ISCarMechanicsOverlay.PartList["SuspensionFrontRight"].vehicles["Biochemical_PickupTruck_"] = {x=230,y=43,x2=270,y2=79};
ISCarMechanicsOverlay.PartList["SuspensionRearLeft"].vehicles["Biochemical_PickupTruck_"] = {x=12,y=500,x2=52,y2=536};
ISCarMechanicsOverlay.PartList["SuspensionRearRight"].vehicles["Biochemical_PickupTruck_"] = {x=230,y=500,x2=270,y2=536};

ISCarMechanicsOverlay.PartList["Battery"].vehicles["Biochemical_PickupTruck_"] = {x=60,y=59,x2=105,y2=92};
ISCarMechanicsOverlay.PartList["Engine"].vehicles["Biochemical_PickupTruck_"] = {x=123,y=28,x2=224,y2=89};
ISCarMechanicsOverlay.PartList["GasTank"].vehicles["Biochemical_PickupTruck_"] = {x=71,y=518,x2=158,y2=575};
ISCarMechanicsOverlay.PartList["Muffler"].vehicles["Biochemical_PickupTruck_"] = {x=18,y=313,x2=54,y2=381};

ISCarMechanicsOverlay.PartList["Biochemical_BumperPart"] = {img="Bumper", vehicles = {"Biochemical_PickupTruck_"}};
ISCarMechanicsOverlay.PartList["Biochemical_BumperPart"].vehicles = ISCarMechanicsOverlay.PartList["Biochemical_BumperPart"].vehicles or {};
ISCarMechanicsOverlay.PartList["Biochemical_BumperPart"].vehicles["Biochemical_PickupTruck_"] = {x=76,y=104,x2=213,y2=117};


--ISCarMechanicsOverlay.PartList["Biochemical_PickupTruck_RooftrackPart"] = {img="trunk", vehicles = {"Biochemical_PickupTruck_"}};
--ISCarMechanicsOverlay.PartList["Biochemical_PickupTruck_RooftrackPart"].vehicles = ISCarMechanicsOverlay.PartList["Biochemical_PickupTruck_RooftrackPart"].vehicles or {};
--ISCarMechanicsOverlay.PartList["Biochemical_PickupTruck_RooftrackPart"].vehicles["Biochemical_PickupTruck_"] = {x=96,y=265,x2=185,y2=455};