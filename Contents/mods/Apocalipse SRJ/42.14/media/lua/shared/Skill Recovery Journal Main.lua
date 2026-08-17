local SRJ = {}

SRJ.xpPatched = false

SRJ.xpHandler = require "Skill Recovery Journal XP"
SRJ.modDataHandler = require "Skill Recovery Journal ModData"

SRJ.LEGACY_JOURNAL_DATA_VERSION = 0
SRJ.JOURNAL_DATA_VERSION = 1

function SRJ.toNumber(value)
	if value == nil then return nil end
	if type(value) == "number" then return value end
	return tonumber(tostring(value))
end

function SRJ.ensureJournalDataVersion(journalModData)
	if not journalModData then return SRJ.LEGACY_JOURNAL_DATA_VERSION end
	local version = SRJ.toNumber(journalModData["version"])
	if version == nil then
		version = SRJ.LEGACY_JOURNAL_DATA_VERSION
		journalModData["version"] = version
	end
	return version
end

function SRJ.isCurrentJournalDataVersion(journalModData)
	return SRJ.ensureJournalDataVersion(journalModData) >= SRJ.JOURNAL_DATA_VERSION
end

function SRJ.hasJournalRecoveryPayload(journalModData)
	return journalModData and (
		journalModData["author"] or
		journalModData["gainedXP"] or
		journalModData["BeyondTenXP"] or
		journalModData["learnedRecipes"] or
		journalModData["kills"] or
		journalModData["pModData"]
	)
end

function SRJ.isLegacyJournalData(journalModData)
	return SRJ.hasJournalRecoveryPayload(journalModData) and (not SRJ.isCurrentJournalDataVersion(journalModData))
end

function SRJ.resetJournalRecoveryDataForCurrentVersion(journalModData)
	if not journalModData then return end
	journalModData["version"] = SRJ.JOURNAL_DATA_VERSION
	journalModData["gainedXP"] = {}
	journalModData["BeyondTenXP"] = nil
	journalModData["learnedRecipes"] = {}
	journalModData["kills"] = nil
	journalModData["pModData"] = nil
	journalModData["recoveryJournalXpLog"] = nil
	journalModData["beyondTenRecoveryJournalXpLog"] = nil
	return journalModData
end

function SRJ.getBeyondTen()
	if BeyondTen then return BeyondTen end
	pcall(require, "BeyondTen/Shared")
	return BeyondTen
end

function SRJ.isBeyondTenPerkValid(BT, perk)
	return BT and perk and type(BT.IsTrainablePerk) == "function" and BT.IsTrainablePerk(perk)
end

function SRJ.getBeyondTenStoredXP(player, perk)
	local BT = SRJ.getBeyondTen()
	if not SRJ.isBeyondTenPerkValid(BT, perk) then return 0 end
	if type(BT.GetStoredXP) == "function" then
		return SRJ.toNumber(BT.GetStoredXP(player, perk)) or 0
	end
	if type(BT.ExportXP) == "function" then
		local values = BT.ExportXP(player)
		return values and (SRJ.toNumber(values[perk:getId()]) or 0) or 0
	end
	return 0
end

function SRJ.getEffectivePerkXP(player, perk)
	local perkXP = player:getXp():getXP(perk)
	local BT = SRJ.getBeyondTen()
	if not SRJ.isBeyondTenPerkValid(BT, perk) then return perkXP end

	local nativeMaxLevel = BT.NATIVE_MAX_LEVEL or 10
	if player:getPerkLevel(perk) >= nativeMaxLevel then
		local nativeCapXP = perk:getTotalXpForLevel(nativeMaxLevel)
		if type(BT.GetNativeCapXP) == "function" then
			nativeCapXP = BT.GetNativeCapXP(perk)
		end
		return nativeCapXP + SRJ.getBeyondTenStoredXP(player, perk)
	end

	if type(BT.GetVirtualXP) == "function" then
		return BT.GetVirtualXP(player, perk)
	end
	return perkXP
end

function SRJ.mergeLegacyBeyondTenXP(journalModData)
	if not journalModData or type(journalModData["BeyondTenXP"]) ~= "table" then return journalModData and journalModData["gainedXP"] end

	local BT = SRJ.getBeyondTen()
	if not BT then return journalModData["gainedXP"] end

	local gainedXP = journalModData["gainedXP"] or {}
	local migrated = false
	for perkID,xp in pairs(journalModData["BeyondTenXP"]) do
		local perk = Perks[perkID]
		local legacyXP = SRJ.toNumber(xp) or 0
		if legacyXP > 0 and SRJ.isBeyondTenPerkValid(BT, perk) then
			gainedXP[perkID] = (SRJ.toNumber(gainedXP[perkID]) or 0) + legacyXP
			migrated = true
		end
	end

	if migrated then
		journalModData["gainedXP"] = gainedXP
		journalModData["BeyondTenXP"] = nil
	end
	return journalModData["gainedXP"]
end

--- Check if an item is the full (100%) recovery journal
---@param item InventoryItem
---@return boolean
function SRJ.isFullRecoveryJournal(item)
	return item and item:getType() == "SkillRecoveryBoundJournalFull"
end

--- Check if an item is any type of Skill Recovery Journal
---@param item InventoryItem
---@return boolean
function SRJ.isSkillRecoveryJournal(item)
	local t = item and item:getType()
	return t == "SkillRecoveryBoundJournal" or t == "SkillRecoveryBoundJournalFull"
end


SRJ.maxXPDifferential = {}
function SRJ.getMaxXPDifferential(perk)
	if SRJ.maxXPDifferential[perk] then return SRJ.maxXPDifferential[perk] end
	local maxXPDefault = Perks.PhysicalCategory:getTotalXpForLevel(10)
	local maxXPPerk = Perks[perk]:getTotalXpForLevel(10)

	SRJ.maxXPDifferential[perk] =maxXPDefault/maxXPPerk
	return SRJ.maxXPDifferential[perk]
end


---@param player IsoGameCharacter|IsoPlayer
function SRJ.checkFitnessCanAddXp(player)
	if player:getNutrition():canAddFitnessXp() then return end

	local fitness = player:getPerkLevel(Perks.Fitness)

	local under, extremeUnder = player:hasTrait(CharacterTrait.UNDERWEIGHT), (player:hasTrait(CharacterTrait.EMACIATED) or player:hasTrait(CharacterTrait.VERY_UNDERWEIGHT))
	local over, extremeOver = player:hasTrait(CharacterTrait.OVERWEIGHT), player:hasTrait(CharacterTrait.OBESE)

	local mildIssue = under or over
	local extremeIssue = extremeUnder or extremeOver

	local blockAddXp = false

	if ( fitness >= 9 and (extremeIssue or mildIssue) ) then
		blockAddXp = true

	elseif ( fitness < 6 ) then
		--blockAddXp = false

	elseif extremeIssue then
		blockAddXp = true
	end

	local message = ((under or extremeUnder) and "IGUI_PlayerText_NeedGainWeight") or ((over or extremeOver) and "IGUI_PlayerText_NeedLoseWeight")

	return blockAddXp, message
end


--TODO: Implement this
function SRJ.checkProteinLevelMulti(player)
	local multi = 1
	if player:getNutrition():getProteins() > 50 and player:getNutrition():getProteins() < 300 then multi = 1.5
	elseif player:getNutrition():getProteins() < -300 then multi = 0.7
	end
	return multi
end


function SRJ.getFreeLevelsFromTraitsAndProfession(player)
	local bonusLevels = {}

	-- xp granted by profession
	local playerDesc = player:getDescriptor()
	local playerProfessionID = playerDesc:getCharacterProfession()
	local profDef = CharacterProfessionDefinition.getCharacterProfessionDefinition(playerProfessionID)
	local profXpBoost = transformIntoKahluaTable(profDef:getXpBoosts())
	if profXpBoost then
		for perk,level in pairs(profXpBoost) do
			local perky = tostring(perk)
			local levely = tonumber(tostring(level))
			bonusLevels[perky] = levely
		end
	end

	-- xp granted by trait
	local playerTraits = player:getCharacterTraits()
	for i=0, playerTraits:getKnownTraits():size()-1 do
		local traitTrait = playerTraits:getKnownTraits():get(i)
		local traitDef = CharacterTraitDefinition.getCharacterTraitDefinition(traitTrait)
		local traitXpBoost = transformIntoKahluaTable(traitDef:getXpBoosts())
		if traitXpBoost then
			for perk,level in pairs(traitXpBoost) do
				local perky = tostring(perk)
				local levely = tonumber(tostring(level))
				bonusLevels[perky] = (bonusLevels[perky] or 0) + levely
			end
		end
	end

	return bonusLevels
end


function SRJ.correctSandBoxOptions(ID)
	if SandboxVars.SkillRecoveryJournal[ID] == false then
		SandboxVars.SkillRecoveryJournal[ID] = 0
		return 0
	elseif SandboxVars.SkillRecoveryJournal[ID] == true then
		local recoverRate = SandboxVars.SkillRecoveryJournal.RecoveryPercentage or 100
		SandboxVars.SkillRecoveryJournal[ID] = recoverRate
		return recoverRate
	end
end


function SRJ.bSkillValid(perk, isFullJournal)
	-- Full recovery journal: always valid, always 100%
	if isFullJournal then
		return true, 1.0
	end

	local ID = perk and perk:isPassiv() and "Passive" or perk:getParent():getId()

	local correction = SRJ.correctSandBoxOptions("Recover"..ID.."Skills")

	local specific = SandboxVars.SkillRecoveryJournal["Recover"..ID.."Skills"]
	
	--if getDebug() then print("bSkillValid check sandbox option 'SkillRecoveryJournal.Recover"..ID.."Skills' -> ".. tostring(specific)) end
	if specific and type(specific)~="number" then specific = correction end

	local default = SandboxVars.SkillRecoveryJournal.RecoveryPercentage or 100

	local recoverPercentage = ((specific==nil) or (specific==-1)) and default or specific

	return (not (recoverPercentage <= 0)), (recoverPercentage/100)
end


-- returns all gained skills as per config or false if no valid skill xp gained
function SRJ.calculateGainedSkill(player, perk, passiveSkillsInit, startingLevels, deductibleXP, isFullJournal)

	if not passiveSkillsInit then
		passiveSkillsInit = SRJ.modDataHandler.getPassiveLevels(player)
	end

	if not startingLevels then
		startingLevels = SRJ.getFreeLevelsFromTraitsAndProfession(player)
	end

	if not deductibleXP then
		deductibleXP = SRJ.modDataHandler.getDeductedXP(player)
	end

	if perk and perk:getParent():getId()~="None" then
		local perkXP = SRJ.getEffectivePerkXP(player, perk)
		if perkXP > 0 then
			local perkID = perk:getId()
			--if getDebug() then print("perkXP: ",perkID," = ",perkXP) end

			---figure out how much XP was present at player start
			local passivePerkFixLevel = passiveSkillsInit and passiveSkillsInit[perkID]
			local passiveFixXP = passivePerkFixLevel and perk:getTotalXpForLevel(passivePerkFixLevel)
			--if getDebug() then print(" -passiveFixXP:",passiveFixXP,"  (",passivePerkFixLevel,")") end

			local startingPerkLevel = startingLevels[perkID]
			local startingPerkXP = startingPerkLevel and perk:getTotalXpForLevel(startingPerkLevel) or 0
			--if getDebug() then print(" -startingPerkXP:",startingPerkXP,  "(",startingPerkLevel,")") end

			local deductedXP = (SandboxVars.SkillRecoveryJournal.TranscribeTVXP==false) and deductibleXP[perkID] or 0
			--if getDebug() then print(" -deductedXP:",deductedXP) end

			local sandboxOptionRecover, recoveryPercentage = SRJ.bSkillValid(perk, isFullJournal)

			local recoverableXP = sandboxOptionRecover and perkXP-(passiveFixXP or startingPerkXP)-deductedXP or 0
			--if getDebug() then print(" -recoverableXP-deductions: ",recoverableXP) end

			if recoverableXP > 0 then

				local gainedXP = recoverableXP * recoveryPercentage
				--if getDebug() then print(" FINAL: ", gainedXP) end
				return gainedXP
			end
		end
	end

	return false
end


-- returns all gained skills as per config or nil if no valid skill xp gained
function SRJ.calculateAllGainedSkills(player, isFullJournal)
	local gainedXP

	local passiveSkillsInit = SRJ.modDataHandler.getPassiveLevels(player)
	local startingLevels = SRJ.getFreeLevelsFromTraitsAndProfession(player)
	local deductibleXP = SRJ.modDataHandler.getDeductedXP(player)

	for i=1, Perks.getMaxIndex()-1 do
		---@type PerkFactory.Perk
		local perk = Perks.fromIndex(i)
		local gained = SRJ.calculateGainedSkill(player, perk, passiveSkillsInit, startingLevels, deductibleXP, isFullJournal)
		if gained then
			--if getDebug() then print("calculateAllGainedSkills gained " .. gained) end
			gainedXP = gainedXP or {}
			gainedXP[perk:getId()] = gained
		end
	end

	return gainedXP
end


function SRJ.calculateGainedBeyondTenSkill(player, perk, isFullJournal)
	local BT = SRJ.getBeyondTen()
	if not SRJ.isBeyondTenPerkValid(BT, perk) then return false end
	if player:getPerkLevel(perk) < (BT.NATIVE_MAX_LEVEL or 10) then return false end

	local storedXP = SRJ.getBeyondTenStoredXP(player, perk)
	if storedXP <= 0 then return false end

	local sandboxOptionRecover, recoveryPercentage = SRJ.bSkillValid(perk, isFullJournal)
	if not sandboxOptionRecover then return false end

	local gainedXP = storedXP * recoveryPercentage
	return gainedXP > 0 and gainedXP or false
end


function SRJ.calculateAllGainedBeyondTenSkills(player, isFullJournal)
	local BT = SRJ.getBeyondTen()
	if not BT or type(BT.GetTrainablePerks) ~= "function" then return nil end

	local gainedXP
	for _, perk in ipairs(BT.GetTrainablePerks()) do
		local gained = SRJ.calculateGainedBeyondTenSkill(player, perk, isFullJournal)
		if gained then
			gainedXP = gainedXP or {}
			gainedXP[perk:getId()] = gained
		end
	end

	return gainedXP
end


function SRJ.getGainedRecipes(player)
	local gainedRecipes = {}

	-- get all recipes known by player
	---@type ArrayList
	local knownRecipes = player:getKnownRecipes()
	for i=0, knownRecipes:size()-1 do
		local recipeID = knownRecipes:get(i)
		gainedRecipes[recipeID] = true
		
		--if getDebug() then print("Adding known recipe " .. tostring(recipeID)) end
	end

	--- return iterable list
	local returnedGainedRecipes = {}
	for recipeID,_ in pairs(gainedRecipes) do
		-- TODO: remove auto learned recipes from skills (maybe we had higher level/xpBoost last life)
		table.insert(returnedGainedRecipes, recipeID)
		--if getDebug() then print("Resulting gained recipe " .. tostring(recipeID) .. " -> " .. tostring(_)) end
	end

	return returnedGainedRecipes
end


return SRJ
