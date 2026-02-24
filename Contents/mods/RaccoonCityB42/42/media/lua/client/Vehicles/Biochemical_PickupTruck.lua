local function info()

    ISCarMechanicsOverlay.CarList["Base.Biochemical_PickupTruck"] = {imgPrefix = "Biochemical_PickupTruck_", x=10,y=0};

end


Events.OnInitWorld.Add(info);