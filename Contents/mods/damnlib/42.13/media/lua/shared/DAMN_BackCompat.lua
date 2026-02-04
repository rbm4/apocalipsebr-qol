--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

require "DAMN_Base_Shared";

DAMN = DAMN or {};
DAMN.BackCompat = DAMN.BackCompat or {};

-- moddata fuckery because storing vehicle moddata was wonky when mp was new

DAMN.BackCompat["muleParts"] = DAMN.BackCompat["muleParts"] or {
	"M101A3Trunk",
	"GloveBox",
	"TruckBed",
	"TrailerTrunk",
	"TruckBedOpen",
	"Engine",
};

function DAMN.BackCompat:getModData(vehicle)
	local part = DAMN.BackCompat:getMulePart(vehicle);

	if part
	then
        local modData = part:getModData();

        if DAMN["backCompatDebug"]
        then
            DAMN:logArray(modData);
        end

		return modData;
	else
        if DAMN["backCompatDebug"]
        then
            DAMN:log("DAMN:getModData() -> data mule part NOT found");
        end

		return {};
	end
end

function DAMN.BackCompat:getMulePart(vehicle)
	if vehicle
	then
		for i, partId in ipairs(DAMN.BackCompat["muleParts"])
		do
			local part = vehicle:getPartById(partId);

			if part
			then
				return part;
			end
		end

        if DAMN["backCompatDebug"]
        then
            DAMN:log("DAMN.BackCompat:getMulePart() -> mule part not found");
        end
	elseif DAMN["backCompatDebug"]
    then
		DAMN:log("DAMN.BackCompat:getMulePart() -> vehicle not found");
	end

	return nil;
end

function DAMN.BackCompat:setMulePartData(vehicle, data)
    local part = DAMN.BackCompat:getMulePart(vehicle);

    if part
    then
        if DAMN["backCompatDebug"]
        then
            DAMN:log("DAMN.BackCompat:setMulePartData() -> Setting mule part mod data");
        end

        local modData = part:getModData();

        for k, v in pairs(data)
        do
            if k ~= "_vehicleId" and k ~= "contentAmount"
            then
                if DAMN["backCompatDebug"]
                then
                    DAMN:log("- setting " .. tostring(k) .. " = " .. tostring(v));
                end

                modData[k] = v;
            end
        end

        vehicle:transmitPartModData(part);
    elseif DAMN["backCompatDebug"]
    then
        DAMN:log("DAMN.BackCompat:setMulePartData() -> Unable to find mule part");
    end
end

function DAMN.BackCompat:migrateModData(vehicle)
    if vehicle
    then
        local modData = vehicle:getModData();

        if not modData["damnlib_migrated"]
        then
            if DAMN["backCompatDebug"]
            then
                DAMN:log("DAMN.BackCompat:migrateModData() -> Moddata migration is necessary");
            end

            modData["damnlib_migrated"] = true;

            DAMN:setVehicleModData(vehicle, DAMN.BackCompat:getModData(vehicle));
        elseif DAMN["backCompatDebug"]
        then
            DAMN:log("DAMN.BackCompat:migrateModData() -> Moddata was already migrated");
        end
    end
end

-- obsolete but can be used later on for different migrations

function DAMN.BackCompat:checkLegacyTires(vehicle)
	for i = 0, vehicle:getPartCount() -1
	do
		local part = vehicle:getPartByIndex(i);

		if not DAMN:partIsMissing(part)
		then
			local inventoryItem = part:getInventoryItem();

			if inventoryItem and inventoryItem:getFullType() == "Base.V100Tire2"
			then
                if DAMN["partDefaultsDebug"]
                then
                    DAMN:log("DAMN.BackCompat:checkLegacyTires() -> replacing " .. inventoryItem:getFullType() .. " on vehicle " .. tostring(vehicle:getSqlId()));
                end

				DAMN.Parts:silentInstall(part, "Base.V101Tire2");
				DAMN.Parts:setContainerAmount(part, 35);
			end
		end
	end
end

function DAMN.BackCompat:replaceLegacyItems(vehicle, oldToNewItemList)
    if DAMN["backCompatDebug"]
    then
        DAMN:log("DAMN.BackCompat:replaceLegacyItems()");
        DAMN:logArray(oldToNewItemList);
    end

	for i = 0, vehicle:getPartCount() -1
	do
		local part = vehicle:getPartByIndex(i);

		if not DAMN.Parts:partIsMissing(part)
		then
			local inventoryItem = part:getInventoryItem();
            local itemId = inventoryItem and inventoryItem:getFullType();

            for oldItemId, newItemId in pairs(oldToNewItemList or {})
            do
                if itemId == oldItemId
                then
                    if DAMN["backCompatDebug"]
                    then
                        DAMN:log(" - replacing " .. tostring(itemId) .. " with " .. tostring(newItemId) .. " on vehicle " .. tostring(vehicle:getSqlId()));
                    end

                    DAMN.Parts:silentInstall(part, newItemId);

                    if part:getWheelIndex()
                    then
                        DAMN.Parts:setContainerAmount(part, 35);
                    end
                end
            end
        elseif DAMN["backCompatDebug"]
        then
            DAMN:log(" - part " .. tostring(part) .. " is not installed");
        end
	end
end

function DAMN.BackCompat:replaceLegacyItemsInSlot(vehicle, part, oldToNewItemList)
    if DAMN["backCompatDebug"]
    then
        DAMN:log("DAMN.BackCompat:replaceLegacyItemsInSlot()");
        DAMN:logArray(oldToNewItemList);
    end

    if not DAMN.Parts:partIsMissing(part)
    then
        local inventoryItem = part:getInventoryItem();
        local itemId = inventoryItem and inventoryItem:getFullType();

        for oldItemId, newItemId in pairs(oldToNewItemList or {})
        do
            if itemId == oldItemId
            then
                if DAMN["backCompatDebug"]
                then
                    DAMN:log("DAMN.BackCompat:replaceLegacyItems() -> replacing " .. tostring(itemId) .. " with " .. tostring(newItemId) .. " on vehicle " .. tostring(vehicle:getSqlId()));
                end

                DAMN.Parts:silentInstall(part, newItemId);

                if part:getWheelIndex()
                then
                    DAMN.Parts:setContainerAmount(part, 35);
                end
            end
        end
    elseif DAMN["backCompatDebug"]
    then
        DAMN:log(" - part " .. tostring(part) .. " is not installed");
    end
end

-- repair item scripts broken with 42.13

DAMN.BackCompat["recipesByMagazineId"] = {
    ["04vwTouranMagazine"] = "04vwTouran.MakeHood;04vwTouran.MakeFrontDoor;04vwTouran.MakeRearDoor;04vwTouran.MakeTrunkLid;04vwTouran.MakeFrontSeat;04vwTouran.MakeRearSeat;04vwTouran.MakeFrontWindshield;04vwTouran.MakeFrontSideWindow;04vwTouran.MakeRearSideWindow;04vwTouran.MakeBackSideWindow;04vwTouran.MakeRearWindshield;04vwTouran.MakeModernSmallRoofrack;04vwTouran.MakeModernLargeRoofrack,",
    ["49powerWagonMagazine"] = "49powerWagon.MakeHood;49powerWagon.MakeFrontDoor;49powerWagon.MakeRearDoor;49powerWagon.MakeTrunkLid;49powerWagon.MakeFrontSeat;49powerWagon.MakeTruckBedSeat;49powerWagon.MakeFrontWindshield;49powerWagon.MakeFrontSideWindow;49powerWagon.MakeRearWindshield;49powerWagon.MakeFrontFender;49powerWagon.MakeRearFender;49powerWagon.MakeSideskirts,",
    ["ECTO1Magazine"] = "59meteor.MakeTire;59meteor.MakeReinforcedTire;59meteor.MakeHood;59meteor.MakeFrontDoor;59meteor.MakeRearDoor;59meteor.MakeTrunkLid;59meteor.MakeLeftSeat;59meteor.MakeRightSeat;59meteor.MakeSmallRearSeat;59meteor.MakeFrontWindshield;59meteor.MakeSideWindow;59meteor.MakeRearWindshield;59meteor.MakeRoofrack,",
    ["63beetleMagazine"] = "63beetle.MakeHood;63beetle.MakeFrontDoor;63beetle.MakeTrunkLid;63beetle.MakeFrontSeat;63beetle.MakeRearSeat;63beetle.MakeFrontWindshield;63beetle.MakeFrontSideWindow;63beetle.MakeRearSideWindow;63beetle.MakeRearWindshield;63beetle.MakeSidesteps;63beetle.MakeRoofrack,",
    ["63Type2VanMagazine"] = "63Type2Van.MakeHood;63Type2Van.MakeFrontDoor;63Type2Van.MakeRearDoor;63Type2Van.MakeRearSplitDoor;63Type2Van.MakeTrunkLid;63Type2Van.MakeTruckBedLid;63Type2Van.MakeFrontSeat;63Type2Van.MakeRearSeat;63Type2Van.MakeFrontWindshield;63Type2Van.MakeFrontSideWindow;63Type2Van.MakeRearSideWindow;63Type2Van.MakeRearDoubleWindow;63Type2Van.MakeRearWindshield;63Type2Van.MakeSidesteps;63Type2Van.MakeRoofrack;63Type2Van.MakeLargeRoofrack;63Type2Van.MakeBedCover;63Type2Van.MakeMudflaps,",
    ["65bansheeMagazine"] = "65banshee.MakeHood1;65banshee.MakeHood2;65banshee.MakeFrontDoor;65banshee.MakeTrunkLid;65banshee.MakeFrontSeat;65banshee.MakeFrontWindshield;65banshee.MakeFrontSideWindow;65banshee.MakeRearWindshield;65banshee.MakeMetalRoof;65banshee.MakeSmallVintageRoofrack,",
    ["66pontiacLeMansMagazine"] = "66pontiacLeMans.MakeHood;66pontiacGTO.MakeHood;66pontiacLeMans.MakeFrontDoor;66pontiacLeMans.MakeTrunkLid;66pontiacLeMans.MakeFrontSeat;66pontiacLeMans.MakeRearSeat;66pontiacLeMans.MakeFrontWindshield;66pontiacLeMans.MakeFrontSideWindow;66pontiacLeMans.MakeRearWindshield;66pontiacLeMans.MakeRoofrack,",
    ["67commandoMagazine"] = "67commando.MakeFrontDoor;67commando.MakeRearDoor;67commando.MakeHood;67commando.MakeToolboxLid;67commando.MakeLightGuards,",
    ["67gt500Magazine"] = "67gt500.MakeHood;67gt500e.MakeHood;67gt500.MakeFrontDoor;67gt500.MakeTrunkLid;67gt500.MakeFrontSeat;67gt500.MakeRearSeat;67gt500.MakeFrontWindshield;67gt500.MakeFrontSideWindow;67gt500.MakeRearWindshield;67gt500.MakeRoofrack,",
    ["68firebirdMagazine"] = "68firebird.MakeHood1;68firebird.MakeHood2;68firebird.MakeHood3;68firebird.MakeFrontDoor;68firebird.MakeTrunkLid;68firebird.MakeFrontSeat;68firebird.MakeRearSeat;68firebird.MakeFrontWindshield;68firebird.MakeFrontSideWindow;68firebird.MakeRearSideWindow;68firebird.MakeRearWindshield;68firebird.MakeSmallVintageRoofrack;68firebird.MakeFoamSeal1;68firebird.MakeFoamSeal3,",
    ["69camaroMagazine"] = "69camaroRS.MakeHood;69camaroSS.MakeHood;69camaro.MakeFrontDoor;69camaro.MakeTrunkLid;69camaro.MakeFrontSeat;69camaro.MakeRearSeat;69camaro.MakeFrontWindshield;69camaro.MakeFrontSideWindow;69camaro.MakeRearWindshield;69camaro.MakeRoofrack,",
    ["69chargerMagazine"] = "69charger.MakeHood;69charger.MakeFrontDoor;69charger.MakeTrunkLid;69chargerDaytona.MakeTrunkLid;69charger.MakeFrontSeat;69charger.MakeRearSeat;69charger.MakeFrontWindshield;69charger.MakeFrontSideWindow;69charger.MakeRearSideWindow;69charger.MakeRearWindshield;69charger.MakeSmallVintageRoofrack,",
    ["69miniMagazine"] = "69mini.MakeHood;69miniIJ.MakeHood;69miniPS1.MakeHood;69mini.MakeFrontDoor;69mini.MakeTrunkLid;69mini.MakeFrontSeat;69mini.MakeRearSeat;69mini.MakeFrontWindshield;69mini.MakeFrontSideWindow;69mini.MakeRearSideWindow;69mini.MakeRearWindshield;69mini.MakeRoofrack,",
    ["CUDAMagazine"] = "CUDAStock.MakeHood;CUDA.MakeHood;CUDAAAR.MakeHood;CUDA.MakeFrontDoor;CUDA.MakeTrunkLid;CUDA.MakeFrontSeat;CUDA.MakeRearSeat;CUDA.MakeFrontWindshield;CUDA.MakeFrontSideWindow;CUDA.MakeRearWindshield;CUDA.MakeRoofrack,",
    ["DodgeMagazine"] = "70dodgeRT.MakeHood;70dodgePD.MakeHood;70dodgeTA.MakeHood;70dodge.MakeFrontDoor;70dodge.MakeTrunkLid;70dodge.MakeFrontSeat;70dodge.MakeRearSeat;70dodge.MakeFrontWindshield;70dodge.MakeFrontSideWindow;70dodge.MakeRearWindshield;70dodge.MakeRoofrack,",
    ["73fordFalconMagazine"] = "73fordFalcon.MakeHood;73fordFalcon.MakeHoodPS;73fordFalcon.MakeFrontDoor;73fordFalcon.MakeTrunkLid;73fordFalcon.MakeFrontSeat;73fordFalcon.MakeRearSeat;73fordFalcon.MakeFrontWindshield;73fordFalcon.MakeFrontSideWindow;73fordFalcon.MakeRearSideWindow;73fordFalcon.MakeRearWindshield;73fordFalcon.MakeFrontReinforcedBumperPS1;73fordFalcon.MakeFrontReinforcedBumperPS2;73fordFalcon.MakeRoofrack;73fordFalcon.MakeStoragePS;73fordFalcon.MakeMufflerPS,",
    ["75grandPrixMagazine"] = "75grandPrix.MakeHood;75grandPrix.MakeFrontDoor;75grandPrix.MakeTrunkLid;75grandPrix.MakeFrontSeat;75grandPrix.MakeRearSeat;75grandPrix.MakeFrontWindshield;75grandPrix.MakeFrontSideWindow;75grandPrix.MakeRearSideWindow;75grandPrix.MakeRearWindshield;75grandPrix.MakeRoofrack,",
    ["76chevyKseriesMagazine"] = "76chevyKseries.MakeHood;76chevyKseries.MakeTrunkLid;76chevyKseriesFD.MakeTrunkLid;76chevyKseriesFD.MakeStorageLids;76chevyCseries.MakeTrunkLid;76chevyCseries.MakeStorageLid;76chevyKseries.MakeFrontSeat;76chevyKseries.MakeRearSeat;76chevyKseries.MakeRoofrack;76chevyCseries.MakeRoofrack;76chevyKseries.MakeRollbar;76chevyKseries.MakeRollbarT2;76chevyKseries.MakeToolbox;76chevyK10.MakeBedCover;76chevyK20.MakeBedCover;76chevyK10.MakeBedOpenCover;76chevyK20.MakeBedOpenCover;76chevyCK.MakeSidesteps;76chevyCK.MakeSidestepsLong;76chevyCseries.MakeLeftMount;76chevyCseries.MakeRightMount;76chevyKseriesFD.MakeMudflaps;76chevyCseries.MakeMudflaps;76chevyCseries.MakeVisor;3rdGenChevyCKseries.MakeFrontDoor;3rdGenChevyCKseries.MakeRearDoor;3rdGenChevyCKseries.MakeFrontWindshield;3rdGenChevyCKseries.MakeFrontSideWindow;3rdGenChevyCKseries.MakeRearSideWindow;3rdGenChevyCKseries.MakeRearWindshield,",
    ["77firebirdMagazine"] = "77firebird.MakeHood1;77firebird.MakeHood2;77firebird.MakeHood3;77firebird.MakeFrontDoor;77firebird.MakeTrunkLid;77firebird.MakeFrontSeat;77firebird.MakeRearSeat;77firebird.MakeFrontWindshield;77firebird.MakeFrontSideWindow;77firebird.MakeRoofPanels;77firebird.MakeRearWindshield;77firebird.MakeSmallVintageRoofrack,",
    ["M35A2Magazine"] = "78amgeneralM35A2.MakeHood;78amgeneralM35A2.MakeFrontDoor;78amgeneralM35A2.MakeTailgate;78amgeneralM35A2.MakeTrunkLid;78amgeneralM35A2.MakeFrontWindshield;78amgeneralM35A2.MakeFrontSideWindow;78amgeneralM35A2.MakeFrontBumper;78amgeneralM35A2.MakeFrontGrille;78amgeneralM35A2.MakeMudflaps;78amgeneralM35A2.MakeSoftBedCover;78amgeneralM35A2.MakeMuffler;78amgeneralM35A2.MakeHardCabCover;78amgeneralM35A2.MakeSoftCabCover,",
    ["80manKat1Magazine"] = "80manKat1.MakeHood;80manKat1.MakeFrontDoor;80manKat1.MakeTailgate;80manKat1.MakeStorageLid;80manKat1.MakeFrontWindshield;80manKat1.MakeFrontSideWindow;80manKat1.MakeMudflaps;80manKat1.MakeBedTarp;80manKat1.MakeMuffler;80manKat1.MakeRoofrack,",
    ["81deloreanDMC12Magazine"] = "81deloreanDMC12.MakeHood;81deloreanDMC12.MakeFrontDoor;81deloreanDMC12.MakeTrunkLid;81deloreanDMC12.MakeFrontSeat;81deloreanDMC12.MakeFrontWindshield;81deloreanDMC12.MakeFrontSideWindow;81deloreanDMC12.MakeRearSideWindow;81deloreanDMC12.MakeRearWindshield,",
    ["82firebirdMagazine"] = "82firebird.MakeHood1;82firebird.MakeFrontDoor;82firebird.MakeTrunkLid;82firebird.MakeFrontSeat;82firebird.MakeRearSeat;82firebird.MakeFrontWindshield;82firebird.MakeFrontSideWindow;82firebird.MakeRoofPanels;82firebird.MakeRearWindshield;82firebird.MakeSmallVintageRoofrack,",
    ["82JeepJ10Magazine"] = "82jeepJ10.MakeHood;82jeepJ10.MakeFrontDoor;82jeepJ10.MakeTrunkLid;82jeepJ10.MakeTopTrunkLid;82jeepJ10.MakeFrontWindshield;82jeepJ10.MakeFrontSideWindow;82jeepJ10.MakeRearWindshield;82jeepJ10.MakeBedCap;80sPickup.MakeRoofrack;80sPickup.MakeFrontSeat;80sPickup.MakeRearSeat,",
    ["82porsche911Magazine"] = "82porsche911Turbo.MakeHood;82porsche911RWB.MakeHood;82porsche911.MakeFrontDoor;82porsche911.MakeTrunkLid;82porsche911.MakeFrontSeat;82porsche911.MakeFrontWindshield;82porsche911.MakeFrontSideWindow;82porsche911.MakeRearSideWindow;82porsche911.MakeRearWindshield;82porsche911.MakeRoofrack,",
    ["M923Magazine"] = "83amgeneralM923.MakeHood;83amgeneralM923.MakeFrontDoor;83amgeneralM923.MakeTailgate;83amgeneralM923.MakeTrunkLid;83amgeneralM923.MakeFrontWindshield;83amgeneralM923.MakeFrontSideWindow;83amgeneralM923.MakeMudflaps;83amgeneralM923.MakeMuffler;83amgeneralM923.MakeHardCover,",
    ["84buickElectraMagazine"] = "84buickElectra.MakeHood;84buickElectra.MakeTrunkLid;84buickElectra.MakeFrontSeat;84buickElectra.MakeRearSeat;84buickElectra.MakeFrontBumper;84buickElectra.MakeReinforcedFrontBumper;84buickElectra.MakeRearBumper;84gmCbody.MakeFrontDoor;84gmCbody.MakeRearDoor;84gmCbody.MakeFrontWindshield;84gmCbody.MakeFrontSideWindow;84gmCbody.MakeRearSideWindow;84gmCbody.MakeRearWindshield;85gmBbody.MakeRoofrack,",
    ["84cadillacDeVilleMagazine"] = "84cadillacDeVille.MakeHood;84cadillacDeVille.MakeTrunkLid;84cadillacDeVille.MakeFrontSeat;84cadillacDeVille.MakeRearSeat;84cadillacDeVille.MakeFrontBumper;84cadillacDeVille.MakeReinforcedFrontBumper;84cadillacDeVille.MakeRearBumper;84gmCbody.MakeFrontDoor;84gmCbody.MakeRearDoor;84gmCbody.MakeFrontWindshield;84gmCbody.MakeFrontSideWindow;84gmCbody.MakeRearSideWindow;84gmCbody.MakeRearWindshield;85gmBbody.MakeRoofrack,",
    ["84jeepXJMagazine"] = "84jeepXJ.MakeHood;84jeepXJ.MakeFrontDoor;84jeepXJ.MakeRearDoor;84jeepXJ.MakeTrunkLid;84jeepXJ.MakeFrontSeat;84jeepXJ.MakeRearSeat;84jeepXJ.MakeFrontWindshield;84jeepXJ.MakeFrontSideWindow;84jeepXJ.MakeRearSideWindow;84jeepXJ.MakeBackSideWindow;84jeepXJ.MakeRearWindshield;84jeepXJ.MakeRoofrack,",
    ["W460Magazine"] = "84mercW460.MakeHood;84mercW460.MakeFrontDoor;84mercW460.MakeRearDoor;84mercW460.MakeTrunkLid;84mercW460.MakeSplitTrunkLid;84mercW460.MakeFrontSeat;84mercW460.MakeRearSeat;84mercW460.MakeFrontWindshield;84mercW460.MakeSideWindow;84mercW460.MakeRearWindshield;84mercW460.MakeMudflaps;84mercW460.MakeRoofrack;84mercW460.MakeMilitaryRoofrack,",
    ["84oldsmobile98Magazine"] = "84oldsmobile98.MakeHood;84oldsmobile98.MakeTrunkLid;84oldsmobile98.MakeFrontSeat;84oldsmobile98.MakeRearSeat;84oldsmobile98.MakeFrontBumper;84oldsmobile98.MakeReinforcedFrontBumper;84oldsmobile98.MakeRearBumper;84gmCbody.MakeFrontDoor;84gmCbody.MakeRearDoor;84gmCbody.MakeFrontWindshield;84gmCbody.MakeFrontSideWindow;84gmCbody.MakeRearSideWindow;84gmCbody.MakeRearWindshield;85gmBbody.MakeRoofrack,",
    ["85buickLeSabreMagazine"] = "85buickLeSabre.MakeHood;85buickLeSabre.MakeTrunkLid;85buickLeSabre.MakeFrontSeat;85buickLeSabre.MakeRearSeat;85buickLeSabre.MakeFrontBumper;85buickLeSabre.MakeReinforcedFrontBumper;85buickLeSabre.MakeRearBumper;85gmBbody.MakeFrontDoor;85gmBbody.MakeRearDoor;85gmBbody.MakeFrontWindshield;85gmBbody.MakeFrontSideWindow;85gmBbody.MakeRearSideWindow;85gmBbody.MakeRearWindshield;85gmBbody.MakeRoofrack,",
    ["85chevyCapriceMagazine"] = "85chevyCaprice.MakeHood;85chevyCaprice.MakeTrunkLid;85chevyCaprice.MakeFrontSeat;85chevyCaprice.MakeRearSeat;85chevyCaprice.MakeFrontBumper;85chevyCaprice.MakeReinforcedFrontBumper;85chevyCaprice.MakeRearBumper;85gmBbody.MakeFrontDoor;85gmBbody.MakeRearDoor;85gmBbody.MakeFrontWindshield;85gmBbody.MakeFrontSideWindow;85gmBbody.MakeRearSideWindow;85gmBbody.MakeCoupeRearSideWindow;85gmBbody.MakeWagonBackSideWindow;85gmBbody.MakeRearWindshield;85gmBbody.MakeWagonRearWindshield;85gmBbody.MakeTrunkLid;85gmBbody.MakeRoofrack;85gmBbody.MakeRoofRails;85gmBbody.MakeWagonRoofrack;85gmBbody.MakeWagonRoofrack2,",
    ["85chevyStepVanMagazine"] = "85chevyStepVan.MakeHood;85chevyStepVan.MakeFrontDoor;85chevyStepVan.MakeTrunkLid;85chevyStepVan.MakeFrontSeat;85chevyStepVan.MakeFrontWindshield;85chevyStepVan.MakeLeftSideWindow;85chevyStepVan.MakeRightSideWindow;85chevyStepVan.MakeRearWindshield;85chevyStepVan.MakeRoofrack;85chevyStepVan.MakeBarrier,",
    ["85clubManMagazine"] = "85clubMan.MakeFrontSeat;85clubMan.MakeFrontWindshield,",
    ["85oldsmobileDelta88Magazine"] = "85oldsmobileDelta88.MakeHood;85oldsmobileDelta88.MakeTrunkLid;85oldsmobileDelta88.MakeFrontSeat;85oldsmobileDelta88.MakeRearSeat;85oldsmobileDelta88.MakeFrontBumper;85oldsmobileDelta88.MakeReinforcedFrontBumper;85oldsmobileDelta88.MakeRearBumper;85gmBbody.MakeFrontDoor;85gmBbody.MakeRearDoor;85gmBbody.MakeFrontWindshield;85gmBbody.MakeFrontSideWindow;85gmBbody.MakeRearSideWindow;85gmBbody.MakeRearWindshield;85gmBbody.MakeRoofrack,",
    ["85pontiacParisienneMagazine"] = "85pontiacParisienne.MakeHood;85pontiacParisienne.MakeTrunkLid;85pontiacParisienne.MakeFrontSeat;85pontiacParisienne.MakeRearSeat;85pontiacParisienne.MakeFrontBumper;85pontiacParisienne.MakeReinforcedFrontBumper;85pontiacParisienne.MakeRearBumper;85gmBbody.MakeFrontDoor;85gmBbody.MakeRearDoor;85gmBbody.MakeFrontWindshield;85gmBbody.MakeFrontSideWindow;85gmBbody.MakeRearSideWindow;85gmBbody.MakeRearWindshield;85gmBbody.MakeRoofrack,",
    ["86chevyCUCVMagazine"] = "86chevyCUCV.MakeHood;3rdGenChevyCKseries.MakeFrontDoor;3rdGenChevyCKseries.MakeFrontWindshield;3rdGenChevyCKseries.MakeFrontSideWindow;3rdGenChevyCKseries.MakeBackSideWindow;3rdGenChevyCKseries.MakeRearWindshield;3rdGenChevyCKseries.MakeSidesteps;3rdGenChevyCKseries.MakeSunVisor;86chevyM1008.MakeTrunkLid;80chevyM1010.MakeTrunkLid;80chevyM1028.MakeTrunkLid;80chevyM1031.MakeTrunkLid;86chevyK5.MakeTrunkLid;86chevyCUCV.MakeTrunkLid;86chevyCUCV.MakeTrunkLids;86chevyCUCV.MakeFrontSeat;86chevyCUCV.MakeRearSeat;86chevyCUCV.MakeBedTarp;86chevyCUCV.MakeBedPlanks;86chevy1028.MakeMudflaps;M101A2.MakeTrunkLid;M101A2.MakeTarp,",
    ["E150Magazine"] = "86fordE150.MakeHood;86fordE150.MakeFrontDoor;86fordE150.MakeRearDoor;86fordE150.MakeRearDoorWin;86fordE150.MakeTrunkLid;86fordE150.MakeFrontSeat;86fordE150.MakeFrontWindshield;86fordE150.MakeFrontSideWindow;86fordE150.MakeRearSideWindow;86fordE150.MakeRearWindshield;86fordE150.MakeRoofrack,",
    ["P19AMagazine"] = "86oshkoshP19A.MakeHood;86oshkoshP19A.MakeFrontDoor;86oshkoshP19A.MakeRoofHatch;86oshkoshP19A.MakeTrunkLid;86oshkoshP19A.MakeFrontWindshield;86oshkoshP19A.MakeFrontSideWindow;86oshkoshP19A.MakeRoofrack;86oshkoshP19A.MakeSideTireMount;86oshkoshP19A.MakeRoofTireMount;86oshkoshP19A.MakeRearLeftFender;86oshkoshP19A.MakeRearLeftMakeshiftFender;86oshkoshP19A.MakeRearRightFender;86oshkoshP19A.MakeRearRightMakeshiftFender;M1082.MakeTrunkLid;M1082.MakeMudflaps;M1082.MakeBedTarp,",
    ["87buickRegalMagazine"] = "87buickRegal.MakeHood;87buickRegal.MakeFrontDoor;87buickRegal.MakeTrunkLid;87buickRegal.MakeFrontSeat;87buickRegal.MakeRearSeat;87buickRegal.MakeFrontWindshield;87buickRegal.MakeFrontSideWindow;87buickRegal.MakeRearSideWindow;87buickRegal.MakeRearWindshield;87buickRegal.MakeRoofrack,",
    ["87chevySuburbanMagazine"] = "87chevySuburban.MakeHood;87chevySuburban.MakeTrunkLid;87chevySuburban.MakeFrontSeat;87chevySuburban.MakeRearSeat;3rdGenChevyCKseries.MakeFrontDoor;3rdGenChevyCKseries.MakeRearDoor;3rdGenChevyCKseries.MakeFrontWindshield;3rdGenChevyCKseries.MakeFrontSideWindow;3rdGenChevyCKseries.MakeRearSideWindow;3rdGenChevyCKseries.MakeBackSideWindow;3rdGenChevyCKseries.MakeRearWindshield;3rdGenChevyCKseries.MakeSidesteps;87chevySuburban.MakeRoofrack;87chevySuburban.MakeSideStorage,",
    ["87fordBF700Magazine"] = "87fordB700.MakeHood;87fordB700.MakeFrontDoubleDoors;87fordB700.MakeRearDoor;87fordF700.MakeFrontDoor;87fordF700.MakeArmoredFrontDoor;87fordF700.MakeArmoredRearDoor;87fordB700.MakeStorageLid;87fordF700.MakeStorageLid;87fordF700.MakeRollDoor;87fordF700.MakeArmoredTrunkDoor;87fordB700.MakeFrontSeat;87fordF700.MakeFrontSeat;87fordB700.MakeStopSign;87fordB700.MakeFrontWindshield;87fordB700.MakeSideWindow;87fordB700.MakeSideWindows;87fordF700.MakeFrontWindshield;87fordF700.MakeFrontSideWindow;87fordF700.MakeRearWindshield;87fordF700.MakeFrontArmoredWindshield;87fordF700.MakeFrontArmoredWindow;87fordF700.MakeRearArmoredWindow;87fordF700.MakeSmallArmoredWindow;87fordF700.MakeRearArmoredWindshield;87fordB700.MakeRoofrack;87fordF700.MakeSmallMudflaps;87fordF700.MakeLargeMudflaps;87fordB700.MakeGastank,",
    ["87toyotaMR2Magazine"] = "87toyotaMR2.MakeHood;87toyotaMR2.MakeFrontDoor;87toyotaMR2.MakeFrontTrunkLid;87toyotaMR2.MakeRearTrunkLid;87toyotaMR2.MakeFrontSeat;87toyotaMR2.MakeFrontWindshield;87toyotaMR2.MakeFrontSideWindow;87toyotaMR2.MakeRearSideWindow;87toyotaMR2.MakeRearWindshield;87toyotaMR2.MakeSunRoof;87toyotaMR2.MakeRoofrack,",
    ["88ChevyS10Magazine"] = "88ChevyS10.MakeHood;88ChevyS10.MakeFrontDoor;88ChevyS10.MakeTrunkLid;88ChevyS10.MakeTopTrunkLid;88ChevyS10.MakeFrontWindshield;88ChevyS10.MakeFrontSideWindow;88ChevyS10.MakeRearWindshield;88ChevyS10.MakeBedCap;80sPickup.MakeRoofrack;80sPickup.MakeFrontSeat;80sPickup.MakeRearSeat,",
    ["88toyotaHiluxMagazine"] = "88toyotaHilux.MakeHood;88toyotaHilux.MakeFrontDoor;88toyotaHilux.MakeTrunkLid;88toyotaHilux.MakeFrontSeat;88toyotaHilux.MakeRearSeat;88toyotaHilux.MakeFrontWindshield;88toyotaHilux.MakeFrontSideWindow;88toyotaHilux.MakeBackSideWindow;88toyotaHilux.MakeRearWindshield;88toyotaHilux.MakeMudflaps;88toyotaHilux.MakeSidesteps;88toyotaHilux.MakeBedCap;88toyotaHilux.MakeRoofrack,",
    ["89defenderMagazine"] = "89defender.MakeHood;89defender.MakeFrontDoor;89defender.MakeRearDoor;89defender.MakeTrunkDoor;89defender.MakeTrunkLid;89defender.MakeFrontSeat;89defender.MakeRearSeat;89defender.MakeFrontWindshield;89defender.MakeFrontSideWindow;89defender.MakeRearSideWindow;89defender.MakeBackSideWindow;89defender.MakeRearWindshield;89defender.MakeRearWindshield130;89defender.MakeRoofrack;89defender.MakeBedTarp;89defender.MakeBedCap;89defender.MakeSideStepsShort;89defender.MakeSideStepsLong;89defender.MakeMudflaps,",
    ["89dodgeCaravanMagazine"] = "89dodgeCaravan.MakeHood;89dodgeCaravan.MakeFrontDoor;89dodgeCaravan.MakeRearDoor;89dodgeCaravan.MakeTrunkLid;89dodgeCaravan.MakeFrontSeat;89dodgeCaravan.MakeFrontWindshield;89dodgeCaravan.MakeFrontSideWindow;89dodgeCaravan.MakeRearSideWindow;89dodgeCaravan.MakeRearWindshield;89dodgeCaravan.MakeFrontWindshieldArmor;89dodgeCaravan.MakeRoofrack;89dodgeCaravan.MakeMudflaps;89dodgeCaravan.MakeSidesteps,",
    ["89BroncoMagazine"] = "8thGenFordFseries.MakeHood;8thGenFordFseries.MakeFrontDoor;8thGenFordFseries.MakeFrontWindshield;8thGenFordFseries.MakeFrontSideWindow;89Bronco.MakeTrunkLid;89Bronco.MakeRearSideWindow;89Bronco.MakeRearWindshield;89Bronco.MakeBedCap;89Bronco.MakeBedBarrier;80sPickup.MakeRoofrack;80sPickup.MakeFrontSeat;80sPickup.MakeRearSeat,",
    ["89trooperMagazine"] = "89trooper.MakeHood;89trooper.MakeFrontDoor;89trooper.MakeRearDoor;89trooper.MakeTrunkLid;89trooper.MakeFrontSeat;89trooper.MakeRearSeat;89trooper.MakeFrontWindshield;89trooper.MakeSideWindow;89trooper.MakeRearWindshield;89trooper.MakeRoofrack;89trooper.MakeMudflaps;89trooper.MakeSidesteps,",
    ["89volvo200Magazine"] = "89volvo240.MakeHood;89volvo242.MakeHood;89volvo200.MakeFrontDoor;89volvo200.MakeRearDoor;89volvo240.MakeTrunkLid;89volvo245.MakeTrunkLid;89volvo200.MakeFrontSeat;89volvo200.MakeRearSeat;89volvo200.MakeFrontWindshield;89volvo200.MakeFrontSideWindow;89volvo240.MakeRearSideWindow;89volvo242.MakeRearSideWindow;89volvo245.MakeBackSideWindow;89volvo244.MakeBackSideWindow;89volvo240.MakeRearWindshield;89volvo245.MakeRearWindshield;89volvo240.MakeRoofrack;89volvo245.MakeRoofrack;89volvo200.MakeMudflaps,",
    ["90bmwE30Magazine"] = "90bmwE30.MakeHood;90bmwE30Sedan.MakeFrontDoor;90bmwE30Cabrio.MakeFrontDoor;90bmwE30Sedan.MakeRearDoor;90bmwE30Touring.MakeRearDoor;90bmwE30Sedan.MakeTrunkLid;90bmwE30m3.MakeTrunkLid;90bmwE30Touring.MakeTrunkLid;90bmwE30Cabrio.RoofLid;90bmwE30.MakeFrontSeat;90bmwE30.MakeRearSeat;90bmwE30.MakeFrontWindshield;90bmwE30.MakeFrontSideWindow;90bmwE30Cabrio.MakeSideWindows;90bmwE30Sedan.MakeRearSideWindow;90bmwE30Touring.MakeRearSideWindow;90bmwE30Touring.MakeBackSideWindow;90bmwE30.MakeRearWindshield;90bmwE30.MakeRoofrack,",
    ["90fordF350Magazine"] = "8thGenFordFseries.MakeFrontDoor;8thGenFordFseries.MakeHood;8thGenFordFseries.MakeFrontSeat;8thGenFordFseries.MakeFrontWindshield;8thGenFordFseries.MakeFrontSideWindow;90fordF350.MakeRearDoor;90fordF350.MakeBackDoors;90fordF350.MakeRearSideWindow;90fordF350.MakeBackWindows;90fordF350.MakeSidesteps,",
    ["90pierceArrowMagazine"] = "90pierceArrow.MakeHood;90pierceArrow.MakeFrontDoor;90pierceArrow.MakeRearDoor;90pierceArrow.MakeTrunkLid;90pierceArrow.MakeTrunkLidsLeft;90pierceArrow.MakeTrunkLidsRight;90pierceArrow.MakeFrontSeat;90pierceArrow.MakeFrontWindshield;90pierceArrow.MakeSideWindow;90pierceArrow.MakeRearWindshield;90pierceArrow.MakeMudflaps,",
    ["91fordLTDMagazine"] = "91fordLTD.MakeHood;91fordLTD.MakeFrontDoor;91fordLTD.MakeRearDoor;91fordLTD.MakeTrunkLid;91fordLTDWagon.MakeTrunkLid;91fordLTD.MakeFrontSeat;91fordLTD.MakeRearSeat;91fordLTD.MakeFrontWindshield;91fordLTD.MakeFrontSideWindow;91fordLTD.MakeRearSideWindow;91fordLTD.MakeRearWindshield;91fordLTDWagon.MakeBackSideWindow;91fordLTDWagon.MakeRearWindshield;91fordLTD.MakeRoofrack,",
    ["91fordRangerMagazine"] = "91fordRanger.MakeHood;91fordRanger.MakeFrontDoor;91fordRanger.MakeTrunkLid;91fordRanger.MakeFrontSeat;91fordRanger.MakeRearSeat;91fordRanger.MakeFrontWindshield;91fordRanger.MakeFrontSideWindow;91fordRanger.MakeBackSideWindow;91fordRanger.MakeRearWindshield;91fordRanger.MakeMudflaps;91fordRanger.MakeBedCap,",
    ["91geoMetroMagazine"] = "91geoMetro.MakeHood;91geoMetro.MakeFrontDoor;91geoMetro.MakeTrunkLid;91geoMetro.MakeFrontSeat;91geoMetro.MakeRearSeat;91geoMetro.MakeFrontWindshield;91geoMetro.MakeFrontSideWindow;91geoMetro.MakeRearSideWindow;91geoMetro.MakeRearWindshield;91geoMetro.MakeWoodenRoofrack;91geoMetro.MakeMetalRoofrack,",
    ["91nissan240sxMagazine"] = "91nissan240sx.MakeHood;91nissan240sx.MakeFrontDoor;91nissan240sx.MakeTrunkLid;91nissan240sx.MakeFrontSeat;91nissan240sx.MakeRearSeat;91nissan240sx.MakeFrontWindshield;91nissan240sx.MakeFrontSideWindow;91nissan240sx.MakeRearSideWindow;91nissan240sx.MakeRearWindshield;91nissan240sx.MakeSunroof;91nissan240sx.MakeSmallModernRoofrack,",
    ["91rangeMagazine"] = "91range.MakeHood;91range.MakeFrontDoor;91range.MakeRearDoor;91range.MakeTrunkLid;91range.MakeFrontSeat;91range.MakeRearSeat;91range.MakeFrontWindshield;91range.MakeFrontSideWindow;91range.MakeRearSideWindow;91range.MakeSunroofWindow;91range.MakeRearWindshield;91range.MakeRoofrack;91range.MakeMudflaps;91range.MakeSidesteps,",
    ["92amgeneralM998Magazine"] = "92amgeneralM998.MakeRoofrack;92amgeneralM998.MakeHood;92amgeneralM998.MakeFrontDoor;92amgeneralM998.MakeRearDoor;92amgeneralM998.MakeTrunkLid;92amgeneralM998.MakeFrontWindshield;92amgeneralM998.MakeSideWindow;92amgeneralM998.MakeMudflaps;92amgeneralM998.MakeSmallMuffler;92amgeneralM998.MakeLargeMuffler;92amgeneralM998.MakeBackCover;92amgeneralM998.MakeMetalTrunkBarrier;92amgeneralM998.MakeNetTrunkBarrier;M101A3.MakeTrunkLid;M101A3.MakeTarp;M101A3.MakeTopTrunkLid;M101A3.MakeHardCover,",
    ["92fordCVPIMagazine"] = "92fordCVPI.MakeHood;92fordCVPI.MakeFrontDoor;92fordCVPI.MakeRearDoor;92fordCVPI.MakeTrunkLid;92fordCVPI.MakeFrontSeat;92fordCVPI.MakeRearSeat;92fordCVPI.MakeFrontWindshield;92fordCVPI.MakeFrontSideWindow;92fordCVPI.MakeRearSideWindow;92fordCVPI.MakeRearWindshield,",
    ["92jeepYJMagazine"] = "92jeepYJ.MakeHood;92jeepYJ.MakeFrontDoor;92jeepYJ.MakeDoorFrame;92jeepYJ.MakeWindshieldFrame;92jeepYJ.MakeTrunkLid;92jeepYJ.MakeFrontSeat;92jeepYJ.MakeRearSeat;92jeepYJ.MakeFrontWindshield;92jeepYJ.MakeFrontSideWindow;92jeepYJ.MakeRearSideWindow;92jeepYJ.MakeRearWindshield;92jeepYJ.MakeRoofrack;92jeepYJ.MakeFamilyRollbar;92jeepYJ.MakeSportRollbar;92jeepYJ.MakeSoftTop;92jeepYJ.MakeHardTop;92jeepYJ.MakeLightbar;92jeepYJ.MakeWinch,",
    ["R32Magazine"] = "R32.MakeHood;R32.MakeFrontDoor;R32.MakeTrunkLid;R32.MakeFrontSeat;R32.MakeRearSeat;R32.MakeFrontWindshield;R32.MakeFrontSideWindow;R32.MakeRearSideWindow;R32.MakeRearWindshield;R32.MakeMuffler0;R32.MakeMuffler1;R32.MakeRoofrack,",
    ["93chevySuburbanMagazine"] = "93chevySuburban.MakeHood;93chevySuburban.MakeFrontDoor;93chevySuburban.MakeRearDoor;93chevySuburban.MakeTrunkLid;93chevySuburban.MakeSplitTrunkLid;93chevySilverado.MakeTrunkLid;93chevySuburban.MakeFrontSeat;93chevySuburban.MakeRearSeat;93chevySuburban.MakeFrontWindshield;93chevySuburban.MakeFrontSideWindow;93chevySuburban.MakeRearSideWindow;93chevySuburban.MakeBackSideWindow;93chevySuburban.MakeRearWindshield;93chevySuburban.MakeSplitRearWindshield;93chevySilverado.MakeRearWindshield;93chevySuburban.MakeRoofrack;LargePickup.MakeRoofrack;93chevySuburban.MakeMetalSidesteps;93chevySuburban.MakePipeSidesteps;93chevyK3500f.MakeTailgate;93chevyK3500f.MakeToolboxLid;93chevyK3500w.MakeToolboxLid;93chevyK3500.MakeToolbox;93chevyK3500.MakeMudflaps;93chevySilverado.MakeBedTarp;93chevySilverado.MakeBedStakes,",
    ["93fordCF8000Magazine"] = "93fordCF8000.MakeHood;93fordCF8000.MakeFrontDoor;93fordCF8000.MakeFrontSeat;93fordCF8000.MakeFrontWindshield;93fordCF8000.MakeFrontSideWindow;93fordCF8000.MakeRearWindshield;93fordCF8000.MakeMuffler;93fordCF8000.MakeSweepingBrushes,",
    ["93fordF350Magazine"] = "93fordF350.MakeHood;93fordF350.MakeFrontDoor;93fordF350.MakeRearDoor;93fordF350.MakeTrunkLid;93fordF350utility.MakeTrunkLid;93fordF350utility.StorageLids;93fordF350.MakeFrontSeat;93fordF350.MakeRearSeat;93fordF350.MakeFrontWindshield;93fordF350.MakeFrontSideWindow;93fordF350.MakeRearSideWindow;93fordF350.MakeRearWindshield;93fordF350.MakeMudflaps;93fordF350.MakeSidesteps;93fordF350.MakeSidestepsLong;93fordF150.MakeSidesteps;93fordF150.MakeSidestepsLong;93fordF350.MakeBedCover;93fordF350.MakeRoofrack,",
    ["93fordTaurusMagazine"] = "93fordTaurus.MakeHood;93fordTaurus.MakeFrontDoor;93fordTaurus.MakeRearDoor;93fordTaurus.MakeTrunkLid;93fordTaurusWagon.MakeTrunkLid;93fordTaurus.MakeFrontSeat;93fordTaurus.MakeRearSeat;93fordTaurus.MakeFrontWindshield;93fordTaurus.MakeFrontSideWindow;93fordTaurus.MakeRearSideWindow;93fordTaurusWagon.MakeBackSideWindow;93fordTaurus.MakeRearWindshield;93fordTaurusWagon.MakeRearWindshield;93fordTaurus.MakeRoofrack,",
    ["93mustangSSPMagazine"] = "93mustangSSP.MakeHood;93mustangSSP.MakeFrontDoor;93mustangSSP.MakeTrunkLid;93mustangSSP.MakeFrontSeat;93mustangSSP.MakeRearSeat;93mustangSSP.MakeFrontWindshield;93mustangSSP.MakeFrontSideWindow;93mustangSSP.MakeRearSideWindow;93mustangSSP.MakeRearWindshield,",
    ["93townCarMagazine"] = "93townCar.MakeHood;93townCar.MakeFrontDoor;93townCar.MakeRearDoor;93townCar.MakeTrunkLid;93townCar.MakeFrontSeat;93townCar.MakeRearSeat;93townCar.MakeFrontWindshield;93townCar.MakeFrontSideWindow;93townCar.MakeMiddleSideWindow;93townCar.MakeRearSideWindow;93townCar.MakeSunroofWindow;93townCar.MakeRearWindshield;93townCar.MakeTrunkrack,",
    ["97BushmasterMagazine"] = "97bushmaster.MakeHood;97bushmaster.MakeDoor;97bushmaster.MakeHatch;97bushmaster.MakeSmallStorageLid;97bushmaster.MakeLargeStorageLid;97bushmaster.MakeFrontWindshield;97bushmaster.MakeFrontSideWindow;97bushmaster.MakeSideWindow;97bushmaster.MakeRearWindshield;97bushmaster.MakeMudflaps;97bushmaster.MakeGastank;97bushmaster.MakeLeftFender;97bushmaster.MakeRightFender;97bushmaster.MakeLeftStorage;97bushmaster.MakeRightStorage;97bushmaster.MakeSeat;97bushmaster.MakeGunnerSeat,",
    ["98stageaMagazine"] = "98stagea.MakeHood;98stagea.MakeFrontDoor;98stagea.MakeRearDoor;98stagea.MakeTrunkLid;98stagea.MakeFrontSeat;98stagea.MakeRearSeat;98stagea.MakeFrontWindshield;98stagea.MakeFrontSideWindow;98stagea.MakeRearSideWindow;98stagea.MakeBackSideWindow;98stagea.MakeRearWindshield;98stagea.MakeModernSmallRoofrack;98stagea.MakeModernLargeRoofrack,",
    ["99fordCVPIMagazine"] = "99fordCVPI.MakeHood;99fordCVPI.MakeFrontDoor;99fordCVPI.MakeRearDoor;99fordCVPI.MakeTrunkLid;99fordCVPI.MakeFrontSeat;99fordCVPI.MakeRearSeat;99fordCVPI.MakeFrontWindshield;99fordCVPI.MakeFrontSideWindow;99fordCVPI.MakeRearSideWindow;99fordCVPI.MakeRearWindshield,",
    ["KI5trailersMagazine"] = "KI5trailersUtility.MakeTrunkLid;KI5trailersUtility.MakeMudflaps;KI5trailersUtility.MakeTrailerToolbox;KI5trailersUtility.MakeTarp;KI5trailersCargo.MakeRollDoor;KI5trailersCargo.MakeSplitDoors;KI5trailersCargo.Door;KI5trailersLivestock.MakeSplitDoorsRamp;KI5trailersCargo.MakeTrailerFlaresLarge;KI5trailersCargo.MakeTrailerFlaresMedium;KI5trailersCargo.MakeTrailerFlaresSmall,",
};

Events.OnGameBoot.Add(function()
    local allItems = getAllItems();

    for i = 0, allItems:size() - 1
    do
        local itemScript = allItems:get(i);

        if not itemScript:getItemType()
        then
            --DAMN:log("Fixing missing ItemType parameter for " .. tostring(itemScript) .. " / " .. tostring(itemScript:getDisplayCategory()));

            if itemScript:getDisplayCategory() ~= "SkillBook"
            then
                --DAMN:log(" -> adding base:normal");
                itemScript:DoParam("ItemType = base:normal");
            else
                --DAMN:log(" -> adding base:literature");
                itemScript:DoParam("ItemType = base:literature");

                if DAMN.BackCompat["recipesByMagazineId"][itemScript:getName()]
                then
                    --DAMN:log(" -> adding LearnedRecipes parameter");
                    --DAMN:log(" -> adding tag base:magazine");
                    itemScript:DoParam("LearnedRecipes = " .. DAMN.BackCompat["recipesByMagazineId"][itemScript:getName()]);
                    itemScript:DoParam("Tags = base:magazine,");
                end
            end
        end
    end
end);