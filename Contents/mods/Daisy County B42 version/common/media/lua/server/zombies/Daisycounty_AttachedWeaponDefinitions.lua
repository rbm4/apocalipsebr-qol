require "Definitions/AttachedWeaponDefinitions"


AttachedWeaponDefinitions.Daisycounty_Master_gun = {
	chance = 5,
	outfit = {"Daisycounty_Master"},
	weaponLocation =  {"Rifle On Back"},
	bloodLocations = nil,
	addHoles = false,
	daySurvived = 365,
	weapons = {
		"Base.OneBarrelShotgun",
	},
}

AttachedWeaponDefinitions.attachedWeaponCustomOutfit.Daisycounty_Master = {
	chance = 2;
	maxitem = 5;
	weapons = {
		AttachedWeaponDefinitions.Daisycounty_Master_gun,
	},
}

AttachedWeaponDefinitions.Daisycounty_FMaster_gun = {
	chance = 5,
	outfit = {"Daisycounty_FMaster"},
	weaponLocation =  {"Rifle On Back"},
	bloodLocations = nil,
	addHoles = false,
	daySurvived = 365,
	weapons = {
		"Base.OneBarrelShotgun",
	},
}

AttachedWeaponDefinitions.attachedWeaponCustomOutfit.Daisycounty_FMaster = {
	chance = 2;
	maxitem = 5;
	weapons = {
		AttachedWeaponDefinitions.Daisycounty_FMaster_gun,
	},
}


