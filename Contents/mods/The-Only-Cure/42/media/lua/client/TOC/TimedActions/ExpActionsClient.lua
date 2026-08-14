local ExpActions = require("TOC/ExpActions")
local CommandsData = require("TOC/CommandsData")

local XP_PER_TICK = ExpActions.XP_PER_TICK or 0.01

---Adds TOC XP via relay for client-side actions (MP client only).
---@param action ISBaseTimedAction
local function AddTOCXpRelay(action)
    if not isClient() then return end
    ExpActions.IterateTOCXp(action, function(_, perkName)
        sendClientCommand(CommandsData.modules.TOC_RELAY, CommandsData.server.Relay.RelayAddXp, {perkName = perkName, xp = XP_PER_TICK})
    end)
end

--* Client-side timed actions need an MP relay because the server owns XP.
ExpActions.WrapUpdate(ISInventoryTransferAction, AddTOCXpRelay)

--* Firearms
ExpActions.WrapUpdate(ISReloadWeaponAction, AddTOCXpRelay)
ExpActions.WrapUpdate(ISInsertMagazine, AddTOCXpRelay)
ExpActions.WrapUpdate(ISLoadBulletsInMagazine, AddTOCXpRelay)
ExpActions.WrapUpdate(ISUnloadBulletsFromFirearm, AddTOCXpRelay)
ExpActions.WrapUpdate(ISUnloadBulletsFromMagazine, AddTOCXpRelay)
ExpActions.WrapUpdate(ISRackFirearm, AddTOCXpRelay)
ExpActions.WrapUpdate(ISUpgradeWeapon, AddTOCXpRelay)
ExpActions.WrapUpdate(ISRemoveWeaponUpgrade, AddTOCXpRelay)

--* Building / demolition
ExpActions.WrapUpdate(ISBuildAction, AddTOCXpRelay)
ExpActions.WrapUpdate(ISBarricadeAction, AddTOCXpRelay)
ExpActions.WrapUpdate(ISUnbarricadeAction, AddTOCXpRelay)
ExpActions.WrapUpdate(ISChopTreeAction, AddTOCXpRelay)
ExpActions.WrapUpdate(ISDismantleAction, AddTOCXpRelay)
ExpActions.WrapUpdate(ISDestroyStuffAction, AddTOCXpRelay)

--* Crafting
ExpActions.WrapUpdate(ISCraftAction, AddTOCXpRelay)

--* Medical
ExpActions.WrapUpdate(ISMedicalCheckAction, AddTOCXpRelay)
ExpActions.WrapUpdate(ISApplyBandage, AddTOCXpRelay)
ExpActions.WrapUpdate(ISCleanBandage, AddTOCXpRelay)
ExpActions.WrapUpdate(ISDisinfect, AddTOCXpRelay)
ExpActions.WrapUpdate(ISRemoveBullet, AddTOCXpRelay)
ExpActions.WrapUpdate(ISRemoveGlass, AddTOCXpRelay)
ExpActions.WrapUpdate(ISRemoveBrokenGlass, AddTOCXpRelay)
ExpActions.WrapUpdate(ISSplint, AddTOCXpRelay)
ExpActions.WrapUpdate(ISStitch, AddTOCXpRelay)
ExpActions.WrapUpdate(ISCleanBurn, AddTOCXpRelay)
ExpActions.WrapUpdate(ISPlantainCataplasm, AddTOCXpRelay)
ExpActions.WrapUpdate(ISRemovePatch, AddTOCXpRelay)

--* Item handling
ExpActions.WrapUpdate(ISPickUpGroundCoverItem, AddTOCXpRelay)
ExpActions.WrapUpdate(ISPickAxeGroundCoverItem, AddTOCXpRelay)
ExpActions.WrapUpdate(ISGrabItemAction, AddTOCXpRelay)
