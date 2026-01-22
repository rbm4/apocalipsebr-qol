-- define weapons to be attached to zombies when creating them
-- random knives inside their neck, spear in their stomach, meatcleaver in their back...
-- this is used in IsoZombie.addRandomAttachedWeapon()
require "Definitions/AttachedWeaponDefinitions"


-- random weapon on fbi zombies holster
AttachedWeaponDefinitions.handgunHolsterfbi = {
	id = "handgunHolsterfbi",
	chance = 45,
	outfit = {"Fbiofficer", "Fbiofficer2", "AntiriotofficerLG"},
	weaponLocation =  {"Holster Right"},
	bloodLocations = nil,
	addHoles = false,
	daySurvived = 0,
	ensureItem = "Base.HolsterSimple",
	weapons = {
		"Base.Pistol",
		"Base.Pistol2",
		"Base.Pistol3",
		"Base.Revolver",
		"Base.Revolver_Long",
		"Base.Revolver_Short",
	},
}

-- shotgun on police's back
AttachedWeaponDefinitions.shotgunPoliceFBI = {
	id = "shotgunPoliceFBI",
	chance = 15,
	outfit = {"Fbiofficer", "Fbiofficer2", "AntiriotofficerLG"},
	weaponLocation =  {"Rifle On Back"},
	bloodLocations = nil,
	addHoles = false,
	daySurvived = 0,
	weapons = {
		"Base.Shotgun",
	},
}

-- assault rifle on back
AttachedWeaponDefinitions.assaultRifleOnBackFBI = {
	id = "assaultRifleOnBackFBI",
	chance = 15,
	outfit = {"Fbiofficer", "Fbiofficer2", "AntiriotofficerLG"},
	weaponLocation =  {"Rifle On Back"},
	bloodLocations = nil,
	addHoles = false,
	daySurvived = 0,
	weapons = {
		"Base.AssaultRifle",
		"Base.AssaultRifle2",
	},
}


AttachedWeaponDefinitions.nightstickfbi = {
	id = "nightstickfbi",
	chance = 20,
	outfit = {"Fbiofficer", "Fbiofficer2", "AntiriotofficerLG"},
	weaponLocation = {"Nightstick Left"},
	bloodLocations = nil,
	addHoles = false,
	daySurvived = 0,
	weapons = {
		"Base.Nightstick",
	},
}

AttachedWeaponDefinitions.attachedWeaponCustomOutfit.Fbiofficer = {
	chance = 45;
	weapons = {
		AttachedWeaponDefinitions.handgunHolsterfbi,
	},
}
AttachedWeaponDefinitions.attachedWeaponCustomOutfit.Fbiofficer = {
	chance = 35;
	weapons = {
		AttachedWeaponDefinitions.shotgunPoliceFBI,
	},
}
AttachedWeaponDefinitions.attachedWeaponCustomOutfit.Fbiofficer = {
	chance = 25;
	weapons = {
		AttachedWeaponDefinitions.assaultRifleOnBackFBI,
	},
}
AttachedWeaponDefinitions.attachedWeaponCustomOutfit.Fbiofficer = {
	chance = 50;
	weapons = {
		AttachedWeaponDefinitions.nightstickfbi,
	},
}

AttachedWeaponDefinitions.attachedWeaponCustomOutfit.Fbiofficer2 = {
	chance = 45;
	weapons = {
		AttachedWeaponDefinitions.handgunHolsterfbi,
	},
}
AttachedWeaponDefinitions.attachedWeaponCustomOutfit.Fbiofficer2 = {
	chance = 35;
	weapons = {
		AttachedWeaponDefinitions.shotgunPoliceFBI,
	},
}
AttachedWeaponDefinitions.attachedWeaponCustomOutfit.Fbiofficer2 = {
	chance = 25;
	weapons = {
		AttachedWeaponDefinitions.assaultRifleOnBackFBI,
	},
}
AttachedWeaponDefinitions.attachedWeaponCustomOutfit.Fbiofficer2 = {
	chance = 50;
	weapons = {
		AttachedWeaponDefinitions.nightstickfbi,
	},
}

AttachedWeaponDefinitions.attachedWeaponCustomOutfit.AntiriotofficerLG = {
	chance = 45;
	weapons = {
		AttachedWeaponDefinitions.handgunHolsterfbi,
	},
}
AttachedWeaponDefinitions.attachedWeaponCustomOutfit.AntiriotofficerLG = {
	chance = 35;
	weapons = {
		AttachedWeaponDefinitions.shotgunPoliceFBI,
	},
}
AttachedWeaponDefinitions.attachedWeaponCustomOutfit.AntiriotofficerLG = {
	chance = 25;
	weapons = {
		AttachedWeaponDefinitions.assaultRifleOnBackFBI,
	},
}
AttachedWeaponDefinitions.attachedWeaponCustomOutfit.AntiriotofficerLG = {
	chance = 90;
	weapons = {
		AttachedWeaponDefinitions.nightstickfbi,
	},
}