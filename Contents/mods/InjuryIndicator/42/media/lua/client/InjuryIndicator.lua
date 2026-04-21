--by B O B c a t (https://steamcommunity.com/id/the_bobcat/)

--If another mod uses the same names as these global variables, it will break the mod that is loaded first.
--I appended this mod's name to the variable names to fix the issue mention above but it's not ideal.
InjuryIndicator_Options = {}

InjuryIndicator_Options.isSpeech = nil
InjuryIndicator_Options.enableInjureNotify = nil
InjuryIndicator_Options.enableHealNotify = nil

local function InitializeOptions()
	local options = PZAPI.ModOptions:create("InjuryIndicator", "Injury Indicator")
	InjuryIndicator_Options.enableInjureNotify = options:addTickBox("enableInjureNotify", getText("UI_InjuryIndicator_EnableInjureNotify"), true, getText("UI_InjuryIndicator_EnableInjureNotify_Tooltip"))
	InjuryIndicator_Options.isSpeech = options:addTickBox("isSpeech", getText("UI_InjuryIndicator_SpeechSwitch"), false, getText("UI_InjuryIndicator_SpeechSwitch_Tooltip"))
	InjuryIndicator_Options.enableHealNotify = options:addTickBox("enableHealNotify", getText("UI_InjuryIndicator_EnableHealNotify"), false, getText("UI_InjuryIndicator_EnableHealNotify_Tooltip"))
end
InitializeOptions()

local injuredParts = {}
local player = nil
local bodyParts = nil

local function OnCreatePlayer(playerIndex)
	player = getSpecificPlayer(playerIndex)
	bodyParts = player:getBodyDamage():getBodyParts()
end

local function TableContains (tab, val)
	for index, value in ipairs(tab) do
		if value == val then return true end
	end
	return false
end

--Using this instead of the built-in table.remove().
--Because read this (https://stackoverflow.com/a/53038524)
function ArrayRemove(t, fnKeep)
	local j, n = 1, #t;
	for i=1,n do
		if (fnKeep(t, i, j)) then
			if (i ~= j) then
				t[j] = t[i];
				t[i] = nil;
			end
			j = j + 1;
		else
			t[i] = nil;
		end
	end
	return t;
end

--room for improvement (to-do):
--Translation text as variables(%1%2)
--(For speech text, so it's possible to use possessive adjectives)
local function TranslateBodyPart(partString)
	return getText("UI_InjuryIndicator_" .. partString)
end

local function NotifySpeech(string, isGood)
	local index = ZombRand(5)	--the number depends on how many variations are available in the UI_XX file.
	if not isGood then player:Say(getText("UI_InjuryIndicator_HurtSpeech" .. index) .. "! - " .. TranslateBodyPart(string))
	else player:Say(TranslateBodyPart(string) .. " - " .. getText("UI_InjuryIndicator_HealSpeech" .. index) .. ".")
	end
end

local function Notify(string, isGood)
	--"Skill up" style notification
	if not InjuryIndicator_Options.isSpeech.value then
		local r, g, b
		if isGood then
			r = 100
			g = 255
			b = 100
		else
			r = 255
			g = 100
			b = 100
		end
		HaloTextHelper.addTextWithArrow(player, TranslateBodyPart(string) .. " ", isGood, r, g, b)
	--Speech style notification
	else
		NotifySpeech(string, isGood)
	end
end

local function OnPlayerUpdate()
	--Loop through all body parts, put them in injuredParts list and pop a notification.
	--Need that list because we use it's contents as a check to prevent message spam.
	for i=1, bodyParts:size() do
		local bodyPart = bodyParts:get(i-1)
		local queryPart = BodyPartType.ToString(bodyPart:getType())
		if bodyPart:HasInjury() then
			if not TableContains(injuredParts, bodyPart) then
				table.insert(injuredParts, bodyPart)
				--Notify when an injury occurs
				if InjuryIndicator_Options.enableInjureNotify.value then Notify(queryPart, false) end
			end
		else
			if TableContains(injuredParts, bodyPart) then
				ArrayRemove(injuredParts, function(t, i, j)
					--Return true(==) to keep the value, or false(~=) to discard it.
					local v = t[i];
					return (v ~= bodyPart);
				end)
				--Notify when an injury heals
				if InjuryIndicator_Options.enableHealNotify.value then Notify(queryPart, true) end
			end
		end
	end
end

Events.OnCreatePlayer.Add(OnCreatePlayer)
Events.OnPlayerUpdate.Add(OnPlayerUpdate)