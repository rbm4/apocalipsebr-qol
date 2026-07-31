require 'Items/ProceduralDistributions'

-- Standard weight per tier, in the same range vanilla uses for common guns (4-10).
-- The overall loot multiplier affects container loot and foraging (scaled in
-- PZCrossbowsForaging.lua). Crossbows and
-- their matching bolt types are also scaled by their existing tier multiplier.
local LOOT_SPAWN_MULT = SandboxVars.PZCrossbows.LootSpawnMult or 1
local CRUDE_WEIGHT = 4 * LOOT_SPAWN_MULT * SandboxVars.PZCrossbows.CrudeCrossbowSpawnMult
local IMPROVED_WEIGHT = 6 * LOOT_SPAWN_MULT * SandboxVars.PZCrossbows.ImprovedCrossbowSpawnMult
local COMPOUND_WEIGHT = 8 * LOOT_SPAWN_MULT * SandboxVars.PZCrossbows.CompoundCrossbowSpawnMult
local HAND_WEIGHT = 6 * LOOT_SPAWN_MULT * SandboxVars.PZCrossbows.HandCrossbowSpawnMult
local QUIVER_WEIGHT = 6 * LOOT_SPAWN_MULT
-- These spawn as WoodBoltBox/ShortWoodBoltBox (a box of 10), matching how
-- vanilla ammo always spawns as a boxed stack rather than loose rounds.
local WOODBOLT_WEIGHT = 20 * LOOT_SPAWN_MULT * SandboxVars.PZCrossbows.CompoundCrossbowSpawnMult
local SHORTWOODBOLT_WEIGHT = 15 * LOOT_SPAWN_MULT * SandboxVars.PZCrossbows.HandCrossbowSpawnMult

-- Adds all 4 crossbow tiers to a list, so a location never offers only one
-- size/tier of crossbow (mirrors vanilla always offering full+sawnoff shotgun
-- together, full gun roster in FirearmWeapons_Mid/Late, etc). Pass hasAmmo=true
-- for lists that aren't flagged dontSpawnAmmo, to also add both bolt types.
local function addCrossbows(listName, hasAmmo)
	local items = ProceduralDistributions["list"][listName].items
	table.insert(items, "PZCrossbows.Crossbow")
	table.insert(items, CRUDE_WEIGHT)
	table.insert(items, "PZCrossbows.ImprovedCrossBow")
	table.insert(items, IMPROVED_WEIGHT)
	table.insert(items, "PZCrossbows.CompoundCrossBow")
	table.insert(items, COMPOUND_WEIGHT)
	table.insert(items, "PZCrossbows.HandCrossBow")
	table.insert(items, HAND_WEIGHT)
	table.insert(items, "PZCrossbows.BoltQuiver")
	table.insert(items, QUIVER_WEIGHT)
	if hasAmmo then
		table.insert(items, "PZCrossbows.WoodBoltBox")
		table.insert(items, WOODBOLT_WEIGHT)
		table.insert(items, "PZCrossbows.ShortWoodBoltBox")
		table.insert(items, SHORTWOODBOLT_WEIGHT)
	end
end

-- Survivor safehouse/cache loot (vanilla uses the identical gun roster across
-- all three of these, just with different roll counts - do the same here).
addCrossbows("FirearmWeapons", true)
addCrossbows("FirearmWeapons_Mid", true)
addCrossbows("FirearmWeapons_Late", true)

-- Ordinary houses: closets, garages, living rooms, storage units.
addCrossbows("Hunter", false)

-- Pawn Shop weapon racks/lockers (pawnshopoffice room).
addCrossbows("GunStoreGuns", false)

-- Rifle rack/display case (gunstore, hunting store, army surplus rooms).
addCrossbows("GunStoreRifles", false)

-- "Gun under the bar counter" slot - vanilla already mixes full-size and
-- sawnoff shotguns here, so every crossbow size belongs too.
addCrossbows("BarCounterWeapon", true)

-- Ammo shelves/lockers (pawn shop, gun store, hunting store, army surplus -
-- civilian rooms only, verified against Distributions.lua).
table.insert(ProceduralDistributions["list"]["GunStoreAmmunition"].items, "PZCrossbows.WoodBoltBox")
table.insert(ProceduralDistributions["list"]["GunStoreAmmunition"].items, WOODBOLT_WEIGHT)
table.insert(ProceduralDistributions["list"]["GunStoreAmmunition"].items, "PZCrossbows.ShortWoodBoltBox")
table.insert(ProceduralDistributions["list"]["GunStoreAmmunition"].items, SHORTWOODBOLT_WEIGHT)

-- Rare bonus finds in general storage. These lists have no other guns in them,
-- so add the compound crossbow and its quiver as rare surprise items rather
-- than the complete weapon roster.
local function addRareCampingLoot(listName, baseWeight)
	local items = ProceduralDistributions["list"][listName].items
	table.insert(items, "PZCrossbows.CompoundCrossBow")
	table.insert(items, baseWeight * LOOT_SPAWN_MULT * SandboxVars.PZCrossbows.CompoundCrossbowSpawnMult)
	table.insert(items, "PZCrossbows.BoltQuiver")
	table.insert(items, baseWeight * LOOT_SPAWN_MULT)
end

addRareCampingLoot("CampingStoreGear", 3)
addRareCampingLoot("CrateCamping", 0.12)
addRareCampingLoot("CampingLockers", 0.1)
addRareCampingLoot("WardrobeRedneck", 0.1)
