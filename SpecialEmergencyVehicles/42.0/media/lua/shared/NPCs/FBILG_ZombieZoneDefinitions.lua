ZombiesZoneDefinition = ZombiesZoneDefinition or {};
require 'NPCs/ZombiesZoneDefinition'

-------------------------------- IF STFR MAIN IT NOT ACTIVATED--------------------------------
if (not (getActivatedMods():contains("STFR"))) then


local AntiriotofficerLG = {
		name="AntiriotofficerLG",	
		chance=3,
	};
local Fbiofficer = {
		name="Fbiofficer",	
		chance=2,
	};
local Fbiofficer2 = {
		name="Fbiofficer2",
		chance=2,
	};
local AntiriotofficerLGgen = {
		name="AntiriotofficerLGgen",
		chance=4,
	};
local ATFofficer = {
		name="ATFofficer",
		chance=1,
	};
local USMSHofficer = {
		name="USMSHofficer",
		chance=2,
	};
local DEAofficer = {
		name="DEAofficer",
		chance=1,
	};
ZombiesZoneDefinition.Police[Fbiofficer] = Fbiofficer;
ZombiesZoneDefinition.Police[Fbiofficer2] = Fbiofficer2;
ZombiesZoneDefinition.Police[AntiriotofficerLG] = AntiriotofficerLG;
ZombiesZoneDefinition.Police[AntiriotofficerLGgen] = AntiriotofficerLGgen;
ZombiesZoneDefinition.Police[ATFofficer] = ATFofficer;
ZombiesZoneDefinition.Police[USMSHofficer] = USMSHofficer;
ZombiesZoneDefinition.Police[DEAofficer] = DEAofficer;
ZombiesZoneDefinition.Prison[AntiriotofficerLGgen] = AntiriotofficerLGgen;
end





