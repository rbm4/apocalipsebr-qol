require 'NPCs/ZombiesZoneDefinition'

Daisycounty_ZombiesZoneDefinition = ZombiesZoneDefinition or {};

-- name of the zone for the zone type ZombiesType (in worldzed)
ZombiesZoneDefinition.Master = {
	Master = {
		name="Daisycounty_Master",
		gender="male",
		chance=10,
	},
}

ZombiesZoneDefinition.FMaster = {
	FMaster = {
		name="Daisycounty_FMaster",
		gender="female",
		chance=10,
	},
}


-- Use this to add zombie type to general pop
-------------------------- General Zombies --------------------------
table.insert(ZombiesZoneDefinition.Default,{name = "Daisycounty_Master", chance=0.001, gender="male"});
table.insert(ZombiesZoneDefinition.Default,{name = "Daisycounty_FMaster", chance=0.001, gender="female"});





