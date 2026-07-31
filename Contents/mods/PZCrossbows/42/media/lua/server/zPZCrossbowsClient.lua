local hasModelReset = false
local hasModelResetDrawn = false

local CrossbowItems = {
	"Crossbow",
	"ImprovedCrossBow",
	"CompoundCrossBow",
	"HandCrossBow",
}

local function CheckIsCrossbow(weapon)
	if not weapon then return false end
	for i = 1, #CrossbowItems do
		if weapon:getType() == CrossbowItems[i] then
			return true
		end
	end
	return false
end

local function PZCrossbowsClampRecoveryChance(value)
	value = tonumber(value) or 0
	if value < 0 then return 0 end
	if value > 100 then return 100 end
	return value
end

local function PZCrossbowsAddItemsToZombieInventory(zombie, itemType, count)
	local inventory = zombie and zombie:getInventory()
	if not inventory or not itemType then return end
	for i = 1, count do
		inventory:AddItem(itemType)
	end
	if zombie and zombie.sync then
		zombie:sync()
	end
end

local function PZCrossbowsGetItemCount(inventory, itemType)
	if not inventory or not itemType then return 0 end
	local items = inventory:getItemsFromFullType(itemType)
	if not items then return 0 end
	return items:size()
end

local function PZCrossbowsRemoveItemsByType(inventory, itemType)
	if not inventory or not itemType then return end
	local items = inventory:getItemsFromFullType(itemType)
	if not items then return end
	for i = items:size() - 1, 0, -1 do
		local item = items:get(i)
		if item then
			inventory:DoRemoveItem(item)
		end
	end
end

local PZCrossbowsBoltPairs = {
	{ intact = "PZCrossbows.WoodBolt", broken = "PZCrossbows.BrokenBolt" },
	{ intact = "PZCrossbows.ShortWoodBolt", broken = "PZCrossbows.BrokenShortBolt" },
}

local function PZCrossbowsCleanupCorpseBoltDuplicates(zombie)
	local inventory = zombie and zombie:getInventory()
	if not inventory then return end
	for i = 1, #PZCrossbowsBoltPairs do
		local pair = PZCrossbowsBoltPairs[i]
		if PZCrossbowsGetItemCount(inventory, pair.intact) > 0 then
			PZCrossbowsRemoveItemsByType(inventory, pair.broken)
		end
	end
end

local PZCrossbowsPendingCorpseCleanups = {}
local PZCrossbowsPendingWeaponSyncs = {}

local function PZCrossbowsQueueCorpseCleanup(zombie)
	if not zombie then return end
	table.insert(PZCrossbowsPendingCorpseCleanups, { zombie = zombie, ticks = 20 })
end

local function PZCrossbowsQueueWeaponSync(character, weapon)
	if not character or not weapon then return end
	table.insert(PZCrossbowsPendingWeaponSyncs, { character = character, weapon = weapon, ticks = 20 })
end

local function PZCrossbowsOnTick()
	for i = #PZCrossbowsPendingCorpseCleanups, 1, -1 do
		local pending = PZCrossbowsPendingCorpseCleanups[i]
		PZCrossbowsCleanupCorpseBoltDuplicates(pending.zombie)
		pending.ticks = pending.ticks - 1
		if pending.ticks <= 0 then
			table.remove(PZCrossbowsPendingCorpseCleanups, i)
		end
	end
	for i = #PZCrossbowsPendingWeaponSyncs, 1, -1 do
		local pending = PZCrossbowsPendingWeaponSyncs[i]
		local weapon = pending.weapon
		local character = pending.character
		if character and weapon then
			syncItemFields(character, weapon)
			syncHandWeaponFields(character, weapon)
		end
		pending.ticks = pending.ticks - 1
		if pending.ticks <= 0 then
			table.remove(PZCrossbowsPendingWeaponSyncs, i)
		end
	end
end

local function PZCrossbowsRecoverBoltBatch(zombie, modData, countKey, spawnedKey, intactItem, brokenItem, baseChance, scaling)
	local count = tonumber(modData[countKey]) or 0
	if count <= 0 or modData[spawnedKey] == true then return end
	local inventory = zombie and zombie:getInventory()
	if not inventory then return end
	if PZCrossbowsGetItemCount(inventory, intactItem) > 0 then
		PZCrossbowsRemoveItemsByType(inventory, brokenItem)
		modData[countKey] = 0
		modData[spawnedKey] = true
		return
	end
	if PZCrossbowsGetItemCount(inventory, brokenItem) > 0 then
		modData[countKey] = 0
		modData[spawnedKey] = true
		return
	end
	local maintenanceLevel = tonumber(modData.MaintenanceLevel) or 0
	local recoveryChance = PZCrossbowsClampRecoveryChance((tonumber(baseChance) or 0) + maintenanceLevel * (tonumber(scaling) or 0))
	local itemType = brokenItem
	if ZombRand(1, 100) <= recoveryChance then
		itemType = intactItem
	end
	PZCrossbowsAddItemsToZombieInventory(zombie, itemType, count)
	modData[countKey] = 0
	modData[spawnedKey] = true
end

local function PZCrossbowsOnZombieDead(zombie)
	if not zombie then return end
	local modData = zombie:getModData()
	if not modData then return end
	local vars = SandboxVars and SandboxVars.PZCrossbows
	if not vars then return end
	PZCrossbowsRecoverBoltBatch(zombie, modData, "BoltNumW", "WSpawned", "PZCrossbows.WoodBolt", "PZCrossbows.BrokenBolt", vars.BoltWBaseBreakChance, vars.BoltWBreakChanceScaling)
	PZCrossbowsRecoverBoltBatch(zombie, modData, "BoltNumSW", "SWSpawned", "PZCrossbows.ShortWoodBolt", "PZCrossbows.BrokenShortBolt", vars.BoltSWBaseBreakChance, vars.BoltSWBreakChanceScaling)
	PZCrossbowsCleanupCorpseBoltDuplicates(zombie)
	PZCrossbowsQueueCorpseCleanup(zombie)
end

local function PZCrossbowsHitCrossbow(attacker, target, weapon, damage)
	if not CheckIsCrossbow(weapon) then return end
	local ammoTypeObj = weapon:getAmmoType()
	if not ammoTypeObj then return end
	local ammoType = ammoTypeObj:toString()
	local modData = target:getModData()
	if ammoType == "pzcrossbows:wood_bolt" then
		modData.BoltNumW = (tonumber(modData.BoltNumW) or 0) + 1
		modData.MaintenanceLevel = attacker:getPerkLevel(Perks.Maintenance)
		modData.WSpawned = false
		target:sync()
	elseif ammoType == "pzcrossbows:short_wood_bolt" then
		modData.BoltNumSW = (tonumber(modData.BoltNumSW) or 0) + 1
		modData.MaintenanceLevel = attacker:getPerkLevel(Perks.Maintenance)
		modData.SWSpawned = false
		target:sync()
	end
end

if ISReloadWeaponAction and ISReloadWeaponAction.loadAmmo and not ISReloadWeaponAction.PZCrossbowsLoadAmmoPatched then
	local PZCrossbowsOriginalLoadAmmo = ISReloadWeaponAction.loadAmmo
	ISReloadWeaponAction.loadAmmo = function(self)
		PZCrossbowsOriginalLoadAmmo(self)
		if self and self.gun and CheckIsCrossbow(self.gun) then
			syncItemFields(self.character, self.gun)
			syncHandWeaponFields(self.character, self.gun)
			PZCrossbowsQueueWeaponSync(self.character, self.gun)
		end
	end
	ISReloadWeaponAction.PZCrossbowsLoadAmmoPatched = true
end

local function PZCrossbowsOnPlayerUpdate(player)
	local weapon = player:getPrimaryHandItem()
	if weapon == nil or not CheckIsCrossbow(weapon) then return end
	if weapon:getType() == "HandCrossBow" then
		if weapon:getCurrentAmmoCount() > 0 and hasModelReset == false then
			weapon:setWeaponSprite("PZCrossbows.HandCrossBowDrawn")
			weapon:setTexture(getTexture("media/textures/Item_HandCrossBowDrawn.png"))
			player:resetEquippedHandsModels()
			hasModelReset = true
			hasModelResetDrawn = false
		elseif weapon:getCurrentAmmoCount() <= 0 and hasModelResetDrawn == false then
			weapon:setWeaponSprite("PZCrossbows.HandCrossBow")
			weapon:setTexture(getTexture("media/textures/Item_HandCrossBow.png"))
			player:resetEquippedHandsModels()
			hasModelResetDrawn = true
			hasModelReset = false
		end
		return
	end
	if weapon:getCurrentAmmoCount() == 0 and hasModelReset == false then
		if weapon:getType() == "Crossbow" then
			weapon:setWeaponSprite("PZCrossbows.CrossBow")
			weapon:setTexture(getTexture("media/textures/Item_CrossBow.png"))
		elseif weapon:getType() == "ImprovedCrossBow" then
			weapon:setWeaponSprite("PZCrossbows.ImprovedCrossBow")
			weapon:setTexture(getTexture("media/textures/Item_ImprovedCrossBow.png"))
		elseif weapon:getType() == "CompoundCrossBow" then
			weapon:setWeaponSprite("PZCrossbows.CompoundCrossBow")
			weapon:setTexture(getTexture("media/textures/Item_CompoundCrossBow.png"))
		end
		player:resetEquippedHandsModels()
		hasModelReset = true
		hasModelResetDrawn = false
	elseif weapon:getCurrentAmmoCount() == 1 and hasModelResetDrawn == false then
		if weapon:getType() == "Crossbow" then
			weapon:setWeaponSprite("PZCrossbows.CrossBowDrawn")
			weapon:setTexture(getTexture("media/textures/Item_CrossBowDrawn.png"))
		elseif weapon:getType() == "ImprovedCrossBow" then
			weapon:setWeaponSprite("PZCrossbows.ImprovedCrossBowDrawn")
			weapon:setTexture(getTexture("media/textures/Item_ImprovedCrossBowDrawn.png"))
		elseif weapon:getType() == "CompoundCrossBow" then
			weapon:setWeaponSprite("PZCrossbows.CompoundCrossBowDrawn")
			weapon:setTexture(getTexture("media/textures/Item_CompoundCrossBowDrawn.png"))
		end
		player:resetEquippedHandsModels()
		hasModelResetDrawn = true
		hasModelReset = false
	end
end

Events.OnPlayerUpdate.Add(PZCrossbowsOnPlayerUpdate)
Events.OnZombieDead.Add(PZCrossbowsOnZombieDead)
Events.OnWeaponHitCharacter.Add(PZCrossbowsHitCrossbow)
Events.OnTick.Add(PZCrossbowsOnTick)
