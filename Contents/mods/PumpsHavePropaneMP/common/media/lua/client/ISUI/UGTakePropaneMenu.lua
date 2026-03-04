UGTakePropaneMenu = {}
UGPropaneTruckMenu = {}
UGSnakesPropane = {}
UGWorkshopPropane = {}

function FindNearbyGasPump( target)


	local square = getCell():getGridSquare( target:getX(), target:getY(), target:getZ())

	if not square then return nil end
	for dy=-2,2 do
		for dx=-2,2 do
			-- TODO: check line-of-sight between 2 squares
			local square2 = getCell():getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
			for i=0, square2:getObjects():size()-1 do
				local obj = square2:getObjects():get(i);
				if obj:getPipedFuelAmount() > 0 and obj:getName() ~= "FuelBarrel" then
					return obj
				end
			end
		end
	end
end

UGTakePropaneMenu.OnContextMenu = function( player, context, worldobjects)

	--print( "keyword: TakePropaneMenu.OnContextMenu called")
	local playerObj = getSpecificPlayer( player)

	if ((SandboxVars.AllowExteriorGenerator and playerObj:getSquare():haveElectricity()) or (SandboxVars.ElecShutModifier > -1 and GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier)) then

		for _,v in ipairs(worldobjects) do

			if v:getPipedFuelAmount() > 0 and v:getName() ~= "FuelBarrel" then

				local pump = v
				local dist = pump:getSquare():DistToProper(playerObj)

				if dist > 2 then break end

				local playerInv = playerObj:getInventory()
				local PTList = playerInv:getItemsFromType( "BlowTorch")
				local tank = nil

				for i=0, PTList:size() -1 do

					local item = PTList:get(i);

					if item:getCurrentUsesFloat() < 1 then

						tank = item
						break;
					else

						--context:addOptionOnTop( getText( "ContextMenu_EmptyTorch"), item, UGTakePropaneMenu.EmptyTank)
					end
				end

				local ctx = context:addOptionOnTop( getText( "ContextMenu_FillTorchFromPump"), tank, UGTakePropaneMenu.RefillTorch, playerObj, pump)
				if not tank  then

					local _tooltip = ISToolTip:new()
					_tooltip:initialise()
					_tooltip:setVisible(false)
					_tooltip.description = " <RGB:1,0,0>" .. "You need a not full propane torch"

					ctx.notAvailable = true
					ctx.toolTip = _tooltip
				end


				local EmptyTank = playerInv:getItemFromType( "PropaneTankEmpty")

				if EmptyTank then

					--make a proper propane tank and replace the outdated 'empty' propane tank.
					playerInv:AddItem( "PropaneTank", 0.0)
					playerInv:Remove( EmptyTank)
				end

				EmptyTank = playerInv:getItemFromType( "LTSPropaneTankEmpty")

				if EmptyTank then

					--make a proper propane tank and replace the outdated 'empty' propane tank.
					playerInv:AddItem( "PropaneTank", 0.0)
					playerInv:Remove( EmptyTank)
				end

				EmptyTank = playerInv:getItemFromType( "HCPropanetankempty")

				if EmptyTank then

					--make a proper propane tank and replace the outdated 'empty' propane tank.
					playerInv:AddItem( "PropaneTank", 0.0)
					playerInv:Remove( EmptyTank)
				end

				PTList = playerInv:getItemsFromType( "PropaneTank")

				tank = nil

				for i=0, PTList:size() -1 do

					local item = PTList:get( i);

					if item:getCurrentUsesFloat() < 1 then
						tank = item
						break;
					end
				end

				ctx = context:addOptionOnTop( getText( "ContextMenu_TakePropaneFromPump"), tank, UGTakePropaneMenu.TakePropane, playerObj, pump)
				if not tank  then

					local _tooltip = ISToolTip:new()
					_tooltip:initialise()
					_tooltip:setVisible(false)
					_tooltip.description = " <RGB:1,0,0>" .. "You need a not full BBQ tank"

					ctx.notAvailable = true
					ctx.toolTip = _tooltip
				end

				local mList = getActivatedMods()

				if mList:contains( "TheWorkshop(new version)") then

					PTList = playerInv:getItemsFromType( "LargePropaneTank")
					tank = nil

					for i=0, PTList:size() -1 do

						local item = PTList:get(i);

						if item:getCurrentUsesFloat() < 1 then

							tank = item
							break;
						else

							--context:addOptionOnTop( "Empty Industrial Propane Tank", item, UGTakePropaneMenu.EmptyTank)
						end
					end

					ctx = context:addOptionOnTop( "Fill Industrial Propane Tank From Pump", tank, UGTakePropaneMenu.TakePropane, playerObj, pump)

					if not tank  then

						local _tooltip = ISToolTip:new()
						_tooltip:initialise()
						_tooltip:setVisible(false)
						_tooltip.description = " <RGB:1,0,0>" .. "You need a not full industrial propane tank"

						ctx.notAvailable = true
						ctx.toolTip = _tooltip
					end


					PTList = playerInv:getItemsFromType( "HugePropaneTank")  --propane storage unit
					tank = nil

					for i=0, PTList:size() -1 do

						local item = PTList:get(i);

						if item:getCurrentUsesFloat() < 1 then

							tank = item
							break;
						else

							--context:addOptionOnTop( "Empty Propane Storage Unit", item, UGTakePropaneMenu.EmptyTank)
						end
					end

					ctx = context:addOptionOnTop( "Fill Propane Storage Unit From Pump", tank, UGTakePropaneMenu.TakePropane, playerObj, pump)

					if not tank  then

						local _tooltip = ISToolTip:new()
						_tooltip:initialise()
						_tooltip:setVisible(false)
						_tooltip.description = " <RGB:1,0,0>" .. "You need a not full propane storage unit"

						ctx.notAvailable = true
						ctx.toolTip = _tooltip
					end
				end

				break
			end
		end
	end
end


UGTakePropaneMenu.TakePropane = function( tank, player, pump)

	--print( "keyword: TakePropane called")
	ISTimedActionQueue.add( UGTakePropane:new( pump, tank, player, 50, 100, false))
end


UGTakePropaneMenu.RefillTorch = function( tank,  player, pump)

	--print( "keyword: RefillTorch called")
	ISTimedActionQueue.add( UGTakePropane:new( pump, tank, player, 50, 6, true))
end


UGTakePropaneMenu.EmptyTank = function( tank)

	if tank then
		if tank.setCurrentUsesFloat then
			tank:setCurrentUsesFloat(0.0)
		else
			tank:setUsedDelta(0.0)
		end
	end
end





UGPropaneTruckMenu.OnContextMenu = function ( player, context, worldobjects)

	--print( "keyword: PropaneTruckMenu.OnContextMenu called")
	local playerObj = getSpecificPlayer( player)
	local vehicle = ISVehicleMenu.getVehicleToInteractWith(playerObj)

	if not vehicle then return end
	if vehicle:getSquare():DistToProper(playerObj) > 2 then return end

	local fuelStation = ISVehiclePartMenu.getNearbyFuelPump(vehicle)

	if fuelStation and ((SandboxVars.AllowExteriorGenerator and playerObj:getSquare():haveElectricity()) or (SandboxVars.ElecShutModifier > -1 and GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier)) then

		for i=1, vehicle:getPartCount() do

			local part = vehicle:getPartByIndex(i-1)
			if not vehicle:isEngineStarted() and part:isContainer() and part:getContainerContentType() == "Propane Storage" then

				if part:getContainerContentAmount() < part:getContainerCapacity() then

					context:addOptionOnTop( getText( "ContextMenu_FillTruckFromPump"), part, UGPropaneTruckMenu.FillTruck, playerObj)
				end
			end
		end
	end
end


UGPropaneTruckMenu.FillTruck = function ( tank, player)

	--print( "keyword: PropaneTruckMenu.FillTruck called")
	luautils.walkToObject( player, tank, false) --this should be to the 'gas' location on the truck
	ISTimedActionQueue.add( UGFillPropaneTruck:new( tank, player, 50))
end





UGSnakesPropane.OnContextMenu = function( player, context, worldobjects)

	local playerObj = getSpecificPlayer(player)
	local propanetankobject = nil
	for _, object in ipairs(worldobjects) do
		if instanceof(object, "IsoObject") then
			local sprite = object:getSprite()
			if sprite then
				local props = sprite:getProperties()
				if props and props.Val and props:Val("CustomName") == "Propane Tank" then
					propanetankobject = object
					break
				end
			end
		end
	end

	if not propanetankobject then return end

    local objectData = propanetankobject:getModData()

	if propanetankobject ~= nil then

		if not objectData.PropaneContent then return end

		local fuelStation = FindNearbyGasPump( propanetankobject)

		if fuelStation and objectData.PropaneContent < 100 then

			--context:addOptionOnTop( "Empty Tank", propanetankobject, UGSnakesPropane.EmptyLargeTank, playerObj)
			context:addOptionOnTop( getText( "ContextMenu_FillLargeTankfromPump"), propanetankobject, UGSnakesPropane.FillLargeTank, playerObj)
		end
	end
end

UGSnakesPropane.FillLargeTank = function( tank, player)

	--print( "keyword: UGSnakesPropane.FillLargeTank called")
	luautils.walkToObject( player, tank, false)
	ISTimedActionQueue.add( UGFillLargeTank:new( tank, player, 250))
end

UGSnakesPropane.EmptyLargeTank = function( tank, player)

	--print( "keyword: UGSnakesPropane.FillLargeTank called")
	tank:getModData().PropaneContent = 0
	tank:transmitModData()
end





UGWorkshopPropane.OnContextMenu = function( player, context, worldobjects)

	local playerObj = getSpecificPlayer( player)
	local propanetankobject = nil

	for _, object in ipairs(worldobjects) do

		if instanceof(object, "IsoObject") and object:getType() == "LargePropaneTank" then

			propanetankobject = object
			break
		end

		if not propanetankobject then return end

		local fuelStation = FindNearbyGasPump( propanetankobject)

		if fuelStation and propanetankobject:getCurrentUsesFloat() < 1 then

			context:addOptionOnTop( getText( "ContextMenu_FillLargeTankfromPump"), propanetankobject, UGWorkshopPropane.FillLargePropaneTank, playerObj, fuelStation)
		end
	end
end


 UGWorkshopPropane.FillLargePropaneTank = function( tank, player, pump)

	--print( "keyword: UGWorkshopPropane.FillLargePropaneTank called")
	ISTimedActionQueue.add( UGTakePropane:new( pump, tank, player, 50, 100, false))
 end


Events.OnFillWorldObjectContextMenu.Add( UGTakePropaneMenu.OnContextMenu)
Events.OnFillWorldObjectContextMenu.Add( UGPropaneTruckMenu.OnContextMenu)
Events.OnFillWorldObjectContextMenu.Add( UGSnakesPropane.OnContextMenu)
Events.OnFillWorldObjectContextMenu.Add( UGWorkshopPropane.OnContextMenu)

-- MP sync for ISConsolidateDrainable (transfer between drainables like tank -> torch)
local hasConsolidateOverride = false
local function overrideConsolidateAction()
	if hasConsolidateOverride then return end
	if not ISConsolidateDrainable then return end
	hasConsolidateOverride = true
	local originalPerform = ISConsolidateDrainable.perform
	function ISConsolidateDrainable:perform()
		local drainable = self.drainable
		local intoItem = self.intoItem
		local character = self.character
		originalPerform(self)
		if isClient() then
			if drainable and drainable:getContainer() then
				sendClientCommand(character, "PumpsHavePropaneMP", "syncItem", {
					itemId = drainable:getID()
				})
			end
			if intoItem and intoItem:getContainer() then
				sendClientCommand(character, "PumpsHavePropaneMP", "syncItem", {
					itemId = intoItem:getID()
				})
			end
		end
	end
end
Events.OnGameStart.Add(overrideConsolidateAction)
