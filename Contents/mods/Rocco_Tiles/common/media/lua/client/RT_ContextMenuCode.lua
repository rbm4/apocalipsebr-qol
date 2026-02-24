RT_ContextMenuCode = RT_ContextMenuCode or {}

local function AddWaterBottle (playerObj, waterdispenser, bottle)
	if luautils.walkAdj(playerObj, waterdispenser:getSquare(), false) then
		ISTimedActionQueue.add(RT_AddTakeDispenserBottle:new(playerObj, waterdispenser, bottle))
	end
end

function RT_ContextMenuCode.AddDispenserBottle(context, param)
    local option = param.option
    local waterdispenser = param.entity
    local playerObj = param.playerObj
    local extraParam = param.extraParam

    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(option, subMenu)
    
    if not playerObj:getInventory():contains("WaterDispenserBottle") then
        option.notAvailable = true
    else
	    local bottlesList = playerObj:getInventory():getAllTypeRecurse("WaterDispenserBottle")
	    for n = 0,bottlesList:size()-1 do
		    local bottle = bottlesList:get(n)
		    bottleOption = subMenu:addGetUpOption(bottle:getName(), playerObj, AddWaterBottle, waterdispenser, bottle)
		    bottleOption.itemForTexture = bottle
	    end
    end
end

function RT_ContextMenuCode.TakeDispenserBottle(context, entity, character, param)
	if luautils.walkAdj(character, entity:getSquare(), false) then
		ISTimedActionQueue.add(RT_AddTakeDispenserBottle:new(character, entity, bottle))
	end
end