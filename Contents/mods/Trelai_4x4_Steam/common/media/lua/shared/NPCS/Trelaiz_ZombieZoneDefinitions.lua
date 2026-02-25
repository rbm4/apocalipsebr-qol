--[[ require "NPCs/ZombiesZoneDefinition"
Trelaiz_ZombiesZoneDefinition = ZombiesZoneDefinition or {};

--Outfitname? = AcademyT
--ZombiesType? = Academy
--Itemname/ClothingName
--Tshirt_TACADEMY / Tshirt_ACADWhite

ZombiesZoneDefinition.Academy = {
        name="AcademyT",
        chance=75,
		mandatory="true",
    };

table.insert(ZombiesZoneDefinition.Default, {name = "AcademyT", chance=100}); ]]