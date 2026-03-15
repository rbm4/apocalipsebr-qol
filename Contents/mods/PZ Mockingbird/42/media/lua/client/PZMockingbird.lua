PZMockingbird = PZMockingbird or {}

local pzMockingbirdMapaInicial = SandboxVars.Mockingbird.MapAllowed;

local config = {
	keyBind   = nil,
	checkBox  = nil,
	textEntry = nil,
	multiBox  = nil,
	comboBox  = nil,
	colorPick = nil,
	slider	= nil,
	button	= nil
}

local function mockingbirdModOption()
	local mockingbirdModOpt = PZAPI.ModOptions:create("mockingbirdModOpt", getText("UI_PZMockingbirdMod_Options"))
    mockingbirdModOpt:addDescription(getText("UI_PZMockingbirdMod_Options_Desc"))
	config.checkBox	= mockingbirdModOpt:addTickBox("0", getText("UI_Allow_Other_Maps_Ask"), true, getText("UI_Allow_Other_Maps_Ask_tooltip"))
	config.checkBox	= mockingbirdModOpt:addTickBox("1", getText("UI_Allow_Vanilla_Maps_Ask"), true, getText("UI_Allow_Vanilla_Maps_Ask_tooltip"))
end

mockingbirdModOption()

--[[
local function MockingbirdMuerto()
	for playerIndex = 0, getNumActivePlayers() -1 do
		local player = getSpecificPlayer(playerIndex)
		if player:isDead() == true then
			player:getModData().isPZMockingbird = false
		end	
	end
end

local function agregaGhostMap(playerIndex, player)
	for playerIndex = 0, getNumActivePlayers() -1 do
		local player = getSpecificPlayer(playerIndex)
		if pzMockingbirdMapaInicial == true then
			local inv = player:getInventory();
			if (player:getModData().isPZMockingbird == true) then
				return
			else
				player:getModData().isPZMockingbird = false
			end
			if (player:getModData().isPZMockingbird == false) then
				local mapin = instanceItem("Base.MockingbirdMap")
				inv:AddItem(mapin);
				player:getModData().isPZMockingbird = true
			end
		else
			player:getModData().isPZMockingbird = true
		end
	end
end

Events.OnCreatePlayer.Add(agregaGhostMap);
Events.OnPlayerDeath.Add(MockingbirdMuerto)
]]--