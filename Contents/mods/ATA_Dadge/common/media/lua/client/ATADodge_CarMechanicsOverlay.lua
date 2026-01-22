ISCarMechanicsOverlay.CarList["Base.ATADodge"] = {imgPrefix = "atadodge_", x=0,y=0};
ISCarMechanicsOverlay.CarList["Base.ATADodgePpg"] = {imgPrefix = "atadodge_", x=0,y=0};

ISCarMechanicsOverlay.PartList["EngineDoor"].vehicles["atadodge_"] = {x=85,y=171,x2=180,y2=244};
ISCarMechanicsOverlay.PartList["DoorFrontLeft"].vehicles["atadodge_"] = {x=65,y=255,x2=75,y2=355};
ISCarMechanicsOverlay.PartList["DoorFrontRight"].vehicles["atadodge_"] = {x=190,y=255,x2=205,y2=355};
ISCarMechanicsOverlay.PartList["WindowFrontLeft"].vehicles["atadodge_"] = {x=76,y=275,x2=90,y2=350};
ISCarMechanicsOverlay.PartList["WindowFrontRight"].vehicles["atadodge_"] = {x=175,y=275,x2=189,y2=350};
ISCarMechanicsOverlay.PartList["WindshieldRear"].vehicles["atadodge_"] = {x=90,y=365,x2=175,y2=425};
ISCarMechanicsOverlay.PartList["Windshield"].vehicles["atadodge_"] = {x=91,y=245,x2=174,y2=295};
ISCarMechanicsOverlay.PartList["TruckBed"].vehicles["atadodge_"] = {x=91,y=426,x2=174,y2=470};

ISCarMechanicsOverlay.PartList["TireFrontLeft"].vehicles["atadodge_"] = {x=60,y=185,x2=70,y2=245};
ISCarMechanicsOverlay.PartList["TireFrontRight"].vehicles["atadodge_"] = {x=195,y=185,x2=205,y2=245};
ISCarMechanicsOverlay.PartList["TireRearLeft"].vehicles["atadodge_"] = {x=60,y=370,x2=70,y2=430};
ISCarMechanicsOverlay.PartList["TireRearRight"].vehicles["atadodge_"] = {x=195,y=370,x2=205,y2=430};

if not ISCarMechanicsOverlay.PartList["HeadlightLeft"].vehicles then
	ISCarMechanicsOverlay.PartList["HeadlightLeft"].vehicles = {}
end
if not ISCarMechanicsOverlay.PartList["HeadlightRight"].vehicles then
	ISCarMechanicsOverlay.PartList["HeadlightRight"].vehicles = {}
end
if not ISCarMechanicsOverlay.PartList["GasTank"].vehicles then
	ISCarMechanicsOverlay.PartList["GasTank"].vehicles = {}
end
if not ISCarMechanicsOverlay.PartList["Muffler"].vehicles then
	ISCarMechanicsOverlay.PartList["Muffler"].vehicles = {}
end

ISCarMechanicsOverlay.PartList["HeadlightLeft"].vehicles["atadodge_"] = {x=75,y=145,x2=105,y2=170};
ISCarMechanicsOverlay.PartList["HeadlightRight"].vehicles["atadodge_"] = {x=160,y=145,x2=190,y2=170};

ISCarMechanicsOverlay.PartList["GasTank"].vehicles["atadodge_"] = {x=150,y=495,x2=235,y2=555};
ISCarMechanicsOverlay.PartList["Muffler"].vehicles["atadodge_"] = {x=65,y=490,x2=105,y2=555};
