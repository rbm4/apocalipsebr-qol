local pZMockingbird = pZMockingbird or {};
pZMockingbird.OnNewGame = pZMockingbird.OnNewGame or {};

function pZMockingbird.OnNewGame(playerObj, square)
	if isClient() then
		return
	end
	local inv = playerObj:getInventory();
	local paqueteSobreviviente
	if SandboxVars.Mockingbird.MapAllowed then
		local mapin = instanceItem("Base.MockingbirdMap")
		inv:AddItem(mapin);
		sendAddItemToContainer(inv, mapin)
	end
end

Events.OnNewGame.Add(pZMockingbird.OnNewGame)
