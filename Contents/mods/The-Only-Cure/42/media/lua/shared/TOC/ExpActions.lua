local DataController = require("TOC/Controllers/DataController")
local CachedDataHandler = require("TOC/Handlers/CachedDataHandler")
local CommonMethods = require("TOC/CommonMethods")
local BeyondTenCompat = require("TOC/BeyondTenCompat")

local XP_PER_TICK = 0.01

---Iterates all valid amputated limbs and calls applyXp(character, perkName) for each.
---Shared logic — no XP mechanism assumed.
---@param action ISBaseTimedAction
---@param applyXp fun(character: IsoPlayer, perkName: string)
local function IterateTOCXp(action, applyXp)
    ---@diagnostic disable-next-line: undefined-field
    if action.skipTOC or action.noExp then return end

    local character = action.character
    local username = character:getUsername()
    local dcInst = DataController.GetInstance(username)
    if not dcInst or not dcInst:getIsAnyLimbCut() then return end

    local amputatedLimbs = CachedDataHandler.GetAmputatedLimbs(username)
    if not amputatedLimbs then return end

    for limbName, _ in pairs(amputatedLimbs) do
        if dcInst:getIsCut(limbName) and dcInst:getIsVisible(limbName) then
            local perkName = "Side_" .. CommonMethods.GetSide(limbName)
            if BeyondTenCompat.GetEffectiveLevel(character, perkName) < BeyondTenCompat.GetMaxLevel() then
                --TOC_DEBUG.print("IterateTOCXp | " .. perkName)
                applyXp(character, perkName)
            end
            if dcInst:getIsProstEquipped(limbName) and BeyondTenCompat.GetEffectiveLevel(character, "ProstFamiliarity") < BeyondTenCompat.GetMaxLevel() then
                --TOC_DEBUG.print("IterateTOCXp | ProstFamiliarity")
                applyXp(character, "ProstFamiliarity")
            end
        end
    end
end

---Adds TOC XP directly. Server and SP only.
---@param action ISBaseTimedAction
local function AddTOCXp(action)
    if isClient() then return end
    IterateTOCXp(action, function(character, perkName)
        BeyondTenCompat.AddXP(character, perkName, XP_PER_TICK)
    end)
end

---Wraps an action class's update() to inject TOC XP each tick.
---Safely skips if the class is nil (e.g. not loaded on this side).
---@param actionClass table
---@param addXpFunc fun(action: ISBaseTimedAction)|nil
local function WrapUpdate(actionClass, addXpFunc)
    if not actionClass or type(actionClass.update) ~= "function" then return end
    local og = actionClass.update
    function actionClass:update()
        og(self)
        if addXpFunc then
            addXpFunc(self)
        else
            AddTOCXp(self)
        end
    end
end

--* Firearms
WrapUpdate(ISReloadWeaponAction)
WrapUpdate(ISInsertMagazine)
WrapUpdate(ISLoadBulletsInMagazine)
WrapUpdate(ISUnloadBulletsFromFirearm)
WrapUpdate(ISUnloadBulletsFromMagazine)
WrapUpdate(ISRackFirearm)
WrapUpdate(ISUpgradeWeapon)
WrapUpdate(ISRemoveWeaponUpgrade)

--* Building / demolition
WrapUpdate(ISBuildAction)
WrapUpdate(ISBarricadeAction)
WrapUpdate(ISUnbarricadeAction)
WrapUpdate(ISChopTreeAction)
WrapUpdate(ISDismantleAction)
WrapUpdate(ISDestroyStuffAction)

--* Crafting
WrapUpdate(ISCraftAction)

--* Medical
WrapUpdate(ISMedicalCheckAction)
WrapUpdate(ISApplyBandage)
WrapUpdate(ISCleanBandage)
WrapUpdate(ISDisinfect)
WrapUpdate(ISRemoveBullet)
WrapUpdate(ISRemoveGlass)
WrapUpdate(ISRemoveBrokenGlass)
WrapUpdate(ISSplint)
WrapUpdate(ISStitch)
WrapUpdate(ISCleanBurn)
WrapUpdate(ISPlantainCataplasm)
WrapUpdate(ISRemovePatch)

--* Item handling
WrapUpdate(ISPickUpGroundCoverItem)
WrapUpdate(ISPickAxeGroundCoverItem)
WrapUpdate(ISGrabItemAction)        -- client-only class, WrapUpdate handles nil safely

return { IterateTOCXp = IterateTOCXp, WrapUpdate = WrapUpdate, AddTOCXp = AddTOCXp, XP_PER_TICK = XP_PER_TICK }
