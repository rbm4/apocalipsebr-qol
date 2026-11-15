require("ISUI/ISCollapsableWindowJoypad")
require "TimedActions/ISTimedActionQueue"
require "TimedActions/WalkToTimedAction"

TableSawUI = ISCollapsableWindowJoypad:derive("TableSawUI")


TableSawUI.options = PZAPI.ModOptions:create("TableSaw", getText("IGUI_TableSawTitle"))
-- 添加一个音量滑块，范围 0~10，步长 1，默认值 5
TableSawVolume = TableSawUI.options:addSlider("TableSawVolume",getText("IGUI_Options_TableSawVolume"),0,1,0.1,0.8)
TableSawInterruptSound = TableSawUI.options:addTickBox("TableSawInterruptSound",getText("IGUI_Options_TableSawInterruptSound"),true)




TableSawUI.g_hWnd = nil


TableSawUI.UIWndWidth = 510
TableSawUI.UIWndHight = 530


TableSawUI.SmallHeight = getTextManager():getFontHeight(UIFont.NewSmall)			-- 小字体高度


TableSawUI.Colour = 
{
    -- 0-25%  绿色 → 黄绿色
    {r=0.00, g=1.00, b=0.00, a=0.7},  
    -- 25-50% 黄绿色 → 黄色
    {r=0.50, g=1.00, b=0.00, a=0.7},  
    -- 50-75% 黄色 → 橙色
    {r=1.00, g=1.00, b=0.00, a=0.7},  
    -- 75-100% 橙色 → 红色
    {r=1.00, g=0.50, b=0.00, a=0.7},  
}

--TableSawUI.CanSawLogList = 
--{
--	['Log'] = 'Base.Plank',
--	['LargeBranch'] = 'Base.Plank',
--	['Sapling'] = 'Base.TreeBranch2',
--}


function TableSawUI.openWindow(player, tablesaw)

	local nScreenWidth = getCore():getScreenWidth()
	local nScreenHeight = getCore():getScreenHeight()

	local width = TableSawUI.UIWndWidth
	local hight = TableSawUI.UIWndHight
	local x = nScreenWidth / 2 - TableSawUI.UIWndWidth / 2 
	local y = nScreenHeight / 2 - TableSawUI.UIWndHight / 2

	local modData = player:getModData();

	local UIDataDef = modData.TableSawUIData

	if UIDataDef then 
		x = UIDataDef.x
		y = UIDataDef.y
	end 

	if TableSawUI.g_hWnd then 
		-- 已打开窗口
		HaloTextHelper.addBadText(player, getText("IGUI_PlayerText_CanNotOpen"));
	else 
        local window = TableSawUI:new(x, y, width, hight, player, tablesaw);
        window:initialise()
        window:addToUIManager()
		
		window.borderColor = { r = 0, g = 0, b = 0, a = 0.85 };
		window.backgroundColor.a = 0.85
		
		window.timer = os.time()
		
        TableSawUI.g_hWnd = window

	end 

end 

function TableSawUI:OpenCloseWindow(player)
    local ui = self.g_hWnd;
    if ui and ui:getIsVisible() then
        ui:close();
    else
        self.openWindow(player);
    end
end

-- 初始化
function TableSawUI:initialise()
    ISCollapsableWindowJoypad.initialise(self)
end

-- 创建UI组件
function TableSawUI:createChildren()
	ISCollapsableWindowJoypad.createChildren(self);
	local titlehight = self:titleBarHeight();
	local resizehight = self:resizeWidgetHeight() or 0
	

	self.repair = ISRepairButton:new(10, self:getHeight() - 83, 120, 25, getText("IGUI_Button_RepairTableSaw"), self, TableSawUI.onRepairTableSaw);
	--self.repair.internal = "REPAIR";
	self.repair.character = self.character
	self.repair:initialise();
	self.repair:instantiate();
	self.repair.borderColor = {r=1, g=1, b=1, a=1};
	--self.repair:setTooltip(getText("Tooltip_RepairTableSaw"));
	self:addChild(self.repair);

	
	self.start = ISButton:new(10, self:getHeight() - 55, 120, 25, getText("IGUI_Button_StartSaw"), self, TableSawUI.onStartSawWood);
	--self.start.internal = "START";
	self.start:initialise();
	self.start:instantiate();
	self.start.borderColor = {r=1, g=1, b=1, a=1};
	--self.start.backgroundColor = {r=1, g=0.7, b=0, a=1};
	self:addChild(self.start);
	--255,165,0
	--self.sawbladeslot = ISSawBladeSlot:new(TableSawUI.UIWndWidth - 55 , titlehight + 5, 50, 50, true)
	--self:addChild(self.sawbladeslot);
	
	local ishavesawblade = true
	local title = getText("IGUI_Button_SawBladeRemove")
	local modData = self.tablesaw:getModData();
	if modData.SawBladeDurable and modData.SawBladeDurable <= 0 then 
		title = getText("IGUI_Button_SawBladeInstall")
		ishavesawblade = false 
	end 
	self.sawbladeslot = ISSawBladeSlot:new(TableSawUI.UIWndWidth - 55 , titlehight + 5, 50, 50, ishavesawblade)
	self:addChild(self.sawbladeslot);
	
	self.sawblade = ISButton:new(TableSawUI.UIWndWidth - 55, titlehight + 58, 50, 20, title, self, TableSawUI.onSawblade);
	--self.sawblade.internal = "SAWBLADE";
	self.sawblade:initialise();
	self.sawblade:instantiate();
	self.sawblade.borderColor = {r=1, g=1, b=1, a=1};
	self:addChild(self.sawblade);
end

-------------------------------------------------------------------------

-- 
function TableSawUI.UpdateRepairDurable(myself, pre)
	--print(pre)
	myself.repairProgress = pre
	myself.isrepair = true
end 

function TableSawUI.EndRepairDurable(myself)
	--print('TableSawUI.EndRepairDurable')
	myself.repairProgress = 0
	myself.isrepair = false
end 

-- 修理
function TableSawUI.onRepairTableSaw(myself)
	local modData = myself.tablesaw:getModData();
	if modData.Durable and (modData.Durable / TableSawMaxDurable) >= 0.7 then 
		HaloTextHelper.addBadText(myself.character, getText("IGUI_PlayerText_NoNeedToRepair"));
		return 
	end 
	if not ISBuildMenu.cheat then 
		for i = 1,#RepairTableSawNeed do 
			--local nCount = TableSawUI.getItemCount(myself.character , RepairTableSawNeed[i][1])
			local nCount = TableSawgetItemCount(myself.character, RepairTableSawNeed[i][1])
			if nCount < RepairTableSawNeed[i][2] then 
				-- 材料不足
				--print('not')
				HaloTextHelper.addBadText(myself.character, getText("IGUI_PlayerText_RepairNotLack"));
				return 
			end 
		end 
	end 
	local sq = myself.tablesaw:getSquare()
	--print('sq:',sq)
	if sq then 
		if luautils.walkAdj(myself.character, sq, true) then
			myself.timer = os.time()
			ISTimedActionQueue.add(ISRepairTableSaw:new(myself.character, sq, myself.tablesaw))
		end 
	end 
end 


-------------------------------------------------------------------------


function TableSawUI.getContainers(playerNum)
	local containers = {}
	for _,v in ipairs(getPlayerInventory(playerNum).inventoryPane.inventoryPage.backpacks) do
		table.insert(containers, v.inventory)
	end
	for _,v in ipairs(getPlayerLoot(playerNum).inventoryPane.inventoryPage.backpacks) do
		table.insert(containers, v.inventory)
	end
	return containers
end

-- 
function TableSawUI.executeSawingActions(tablesaw, player, Sprite)
	--local player = getSpecificPlayer(_playerNum)
	local _playerNum = player:getPlayerNum()
	local containers = TableSawUI.getContainers(_playerNum)
	for _,container in ipairs(containers) do
		for i=1,container:getItems():size() do
			local item = container:getItems():get(i-1)
			if CanSawLogList[item:getType()] then
				TableSawUI.g_hWnd.timer = os.time()
				if luautils.haveToBeTransfered(player, item) then 
					--local transferAction = ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, item:getContainer(), player:getInventory()))
					local transferAction = ISInventoryTransferAction:new(player, item, item:getContainer(), player:getInventory())
					transferAction:setOnComplete(TableSawUI.TransferActionCallback, player, item, tablesaw, Sprite)
					ISTimedActionQueue.add(transferAction);
				else 
					local ntime = 500 * (SandboxVars.SawingWoodAcceleration / 100)
					local SawAction = ISTableSawTimedAction:new(player, item, tablesaw, Sprite, ntime)
					SawAction:setOnComplete(TableSawUI.SawingActionCallback, tablesaw, player, Sprite)
					ISTimedActionQueue.add(SawAction);
				end
				return 
			end
		end 
	end 
	
end


function TableSawUI.TransferActionCallback(player, item, tablesaw, Sprite)
	--ISTimedActionQueue.add(ISTableSawTimedAction:new(_playerNum, item, myself, Sprite, TableSawUI.SawingActionCallback))
	local ntime = 500 * (SandboxVars.SawingWoodAcceleration / 100)
	local SawAction = ISTableSawTimedAction:new(player, item, tablesaw, Sprite, ntime)
	SawAction:setOnComplete(TableSawUI.SawingActionCallback, tablesaw, player, Sprite)
	ISTimedActionQueue.add(SawAction);
end 

function TableSawUI.SawingActionCallback(tablesaw, player, Sprite)
	--print('SawingActionCallback')
	TableSawUI.executeSawingActions(tablesaw, player, Sprite)
end 

-- 开始锯木头
function TableSawUI.walkToSaw(myself, destination)
	local pending = myself.walkToSawAction
	if pending and ISTimedActionQueue.hasAction(pending) then return end
	local character = myself.character
	if character:getVehicle() then return end
	local sawSquare = myself.tablesaw:getSquare()
	local action = ISWalkToTimedAction:new(character, destination)
	myself.walkToSawAction = action

	local function current()
		return myself.walkToSawAction == action and TableSawUI.g_hWnd == myself
			and myself:getIsVisible() and not character:isDead()
			and myself.tablesaw:getSquare() == sawSquare
			and myself.tablesaw:getObjectIndex() >= 0
	end
	local originalIsValid = action.isValid
	function action:isValid()
		return current() and originalIsValid(self)
	end
	local function clearPending()
		if myself.walkToSawAction == action then myself.walkToSawAction = nil end
	end
	local originalStop = action.stop
	function action:stop()
		clearPending()
		originalStop(self)
	end
	local originalForceCancel = action.forceCancel
	function action:forceCancel()
		clearPending()
		originalForceCancel(self)
	end
	action:setOnComplete(function()
		local arrived = current() and character:getSquare() == destination
		clearPending()
		if arrived then TableSawUI.onStartSawWood(myself) end
	end)
	ISTimedActionQueue.add(action)
	if not ISTimedActionQueue.hasAction(action) then clearPending() end
end

function TableSawUI.onStartSawWood(myself)
	local Square = myself.tablesaw:getSquare()
	if Square then 
		if not Square:haveElectricity() then 
			if Square:hasGridPower() then 
				if not Square:getRoom() then 
					HaloTextHelper.addBadText(myself.character, getText("IGUI_PlayerText_NotHaveElectricity"))
					return
				end
			else 
				HaloTextHelper.addBadText(myself.character, getText("IGUI_PlayerText_NotHaveElectricity"))
				return
			end
		end
	end 
	local modData = myself.tablesaw:getModData();
	if modData.SawBladeDurable and modData.SawBladeDurable <= 0.0 then 
		HaloTextHelper.addBadText(myself.character, getText("IGUI_PlayerText_NoSawbladeInstalled"));
		return 
	end 
	if modData.Durable and modData.Durable <= (TableSawMaxDurable * 0.1) then 
		HaloTextHelper.addBadText(myself.character, getText("IGUI_PlayerText_TableSawOld"));
		return 
	end 

	local tablesaw = myself.tablesaw:getSprite()
	local Sprite = tablesaw:getName()
	if Square and Sprite then 
		--if Square:has(TableSawSpriteList[Sprite][5]) then 
		--	HaloTextHelper.addBadText(myself.character, getText("IGUI_PlayerText_CanNotReach"));
		--	return 
		--end 
	
		local newsq = getCell():getGridSquare(
			Square:getX() + TableSawSpriteList[Sprite][1],
			Square:getY() + TableSawSpriteList[Sprite][2],
			Square:getZ()
		)
		local newsq2 = getCell():getGridSquare(
			Square:getX() + TableSawSpriteList[Sprite][5],
			Square:getY() + TableSawSpriteList[Sprite][6],
			Square:getZ()
		)
		if not newsq or not newsq2 then 
			HaloTextHelper.addBadText(myself.character, getText("IGUI_PlayerText_CanNotReach"));
			return 
		end 
		
		if newsq:has(IsoFlagType.solid) or newsq:has(IsoFlagType.solidtrans) then 
			HaloTextHelper.addBadText(myself.character, getText("IGUI_PlayerText_CanNotReach"));
			return 
		end 
		if newsq2:has(TableSawSpriteList[Sprite][9]) then 
			HaloTextHelper.addBadText(myself.character, getText("IGUI_PlayerText_CanNotReach"));
			return 
		end 
		--myself:onToggleCollapse()
		if myself.character:getSquare() == newsq then
			-- 地块相同强制居中
			myself.character:setX(newsq:getX()+0.5)
			myself.character:setY(newsq:getY()+0.5)
			myself.character:setZ(newsq:getZ())
			myself.executeSawingActions(myself.tablesaw, myself.character, Sprite)
		else
			myself.walkToSaw(myself, newsq)
		end 
	end 
end 

-------------------------------------------------------------------------

-- 
function TableSawUI.UpdateSawblade(myself, pre, ntype)
	--print(pre)
	myself.sawbladeslot.UpdateSawblade(myself.sawbladeslot,pre, ntype)
end 

function TableSawUI.EndSawblade(myself)
	--print('TableSawUI.EndRepairDurable')
	myself.sawbladeslot.EndSawblade(myself.sawbladeslot)
end 

-- 装拆锯片
function TableSawUI.onSawblade(myself)
	--local modData = myself.tablesaw:getModData();
	--modData.SawBladeDurable = 0

	local sq = myself.tablesaw:getSquare()
	--print('sq:',sq)
	if sq then 
		local modData = myself.tablesaw:getModData();
		local ntype = 1
		if modData.SawBladeDurable and modData.SawBladeDurable > 0 then 
			ntype = 2
		else 
			ntype = 1
			local nCount = TableSawgetItemCount(myself.character, 'Base.CircularSawblade')
			if nCount < 1 then 
				HaloTextHelper.addBadText(myself.character, getText("IGUI_PlayerText_HaveNoSawblade"));
				return 
			end 
		end 
		if luautils.walkAdj(myself.character, sq, true) then
			myself.timer = os.time()
			ISTimedActionQueue.add(ISInstallRemoveSawBlade:new(myself.character, sq, myself.tablesaw, ntype))
		end 
	end 
end 

-------------------------------------------------------------------------

function TableSawUI:onToggleCollapse()
    self:collapse()
end

-- 绘制垂直进度条
function TableSawUI:drawProgressBarVertical(x, y, w, h, progress, fg)
    if progress < 0.0 then progress = 0.0 end
    if progress > 1.0 then progress = 1.0 end
   
    local fillHeight = math.floor(h * progress)
    if progress > 0 then fillHeight = math.max(fillHeight, 1) end

    local bg = { r=0.15, g=0.15, b=0.15, a=1.0 }
    self:drawRect(x, y, w, h - fillHeight, bg.a, bg.r, bg.g, bg.b)
    
    self:drawRect(x, y + (h - fillHeight), w, fillHeight, fg.a, fg.r, fg.g, fg.b)
end

function TableSawUI:drawProgressBarHorizontal(x, y, w, h, progress, fg)
    if progress < 0.0 then progress = 0.0 end
    if progress > 1.0 then progress = 1.0 end
    local done = math.floor(w * progress)
    if progress > 0 then done = math.max(done, 1) end
    self:drawRect(x, y, done, h, fg.a, fg.r, fg.g, fg.b);
    local bg = {r=0.15, g=0.15, b=0.15, a=1.0};
	local rx = x + done
	local wide = w - done
    self:drawRect(rx, y, wide, h, bg.a, bg.r, bg.g, bg.b);

	if self.isrepair and self.repairProgress then
		local maxRepairWidth = w - done
		local repairWidth = math.floor(w * TableSawRepairPer * self.repairProgress)
		repairWidth = math.min(repairWidth, maxRepairWidth)
		
		if repairWidth > 0 then
			local repairColor = {r=0.2, g=0.5, b=1.0, a=0.8}
			self:drawRect(x + done, y, repairWidth, h, repairColor.a, repairColor.r, repairColor.g, repairColor.b)
		end
	end
end

-- 渲染
function TableSawUI:render()
	ISCollapsableWindowJoypad.render(self)
	--print(self.isCollapsed)
	--if self.isCollapsed then 
	--	print(self.isCollapsed)
	--end 
	if not self.isCollapsed then 
		local titlehight = self:titleBarHeight();
		-- 绘制台锯
		self:drawTexture(self.texture, 0, titlehight, 1, 1, 1, 1)
		
		self:drawTexture(self.Logtexture, 5, titlehight + 230, 1, 1, 1, 1)
		self:drawTexture(self.Planktexture, 55, titlehight + 230, 1, 1, 1, 1)
		self:drawText('=>', 40 , titlehight + 235, 1,1,1,1, UIFont.NewSmall);
		
		self:drawTexture(self.LargeBranchtexture, 5, titlehight + 270, 1, 1, 1, 1)
		self:drawTexture(self.Planktexture, 55, titlehight + 270, 1, 1, 1, 1)
		self:drawText('=>', 40 , titlehight + 275, 1,1,1,1, UIFont.NewSmall);
		
		self:drawTexture(self.Saplingtexture, 5, titlehight + 310, 1, 1, 1, 1)
		self:drawTexture(self.TreeBranch2texture, 55, titlehight + 310, 1, 1, 1, 1)
		self:drawText('=>', 40 , titlehight + 315, 1,1,1,1, UIFont.NewSmall);
		
		--local Square = self.tablesaw:getSquare()
		--if Square then 
		--	self.shownum = (self.shownum + 1) % 20
		--	local shouldShow = self.shownum < 10
		--	if shouldShow then 
		--		if Square:haveElectricity() or (Square:hasGridPower() and Square:getRoom()) then 
		--			self:drawTexture(self.Electricity, 100, titlehight + 360, 1, 1, 1, 1) 
		--		else 
		--			self:drawTexture(self.UnElectricity, 100, titlehight + 360, 1, 1, 1, 1) 
		--		end 
		--	end 
		--end 
		local Square = self.tablesaw:getSquare()
		if Square then 
			self.shownum = (self.shownum + 1) % 20 

			local isPowered = Square:haveElectricity() or (Square:hasGridPower() and Square:getRoom())
			local shouldShow = isPowered or (self.shownum < 10)  
		
			if shouldShow then 
				if isPowered then 
					self:drawTexture(self.Electricity, 100, titlehight + 360, 1, 1, 1, 1)  
				else 
					self:drawTexture(self.UnElectricity, 100, titlehight + 360, 1, 1, 1, 1) 
				end 
			end 
		end
	
		local isneed = true
		local modData = self.tablesaw:getModData();
		if modData.SawBladeDurable and modData.SawBladeDurable <= 0 then 
			self.sawbladeslot.isshow = false
			self.sawblade.title = getText("IGUI_Button_SawBladeInstall")
			isneed = false 
		else 
			self.sawbladeslot.isshow = true
			self.sawblade.title = getText("IGUI_Button_SawBladeRemove")
		end 
		if isneed then 
			self:drawTexture(self.texture2, 315, titlehight + 93, 1, 1, 1, 1)
		end 
		local TableSawPer = 0.00
		if modData.Durable then 
			TableSawPer = modData.Durable / TableSawMaxDurable
		else 
			--TableSawPer = 1.00
			modData.Durable = TableSawMaxDurable - ZombRandFloat(0.00,5.00)
			TableSawPer = modData.Durable / TableSawMaxDurable
		end 
		
		local SawBladePer = 0.00
		if modData.SawBladeDurable then 
			SawBladePer = modData.SawBladeDurable / SawBladeMaxDurable
		else 
			SawBladePer = 1.00
			modData.SawBladeDurable = SawBladeMaxDurable - ZombRandFloat(0.00,8.00)
			SawBladePer = modData.SawBladeDurable / SawBladeMaxDurable
		end 
		local TableSawColour = TableSawUI.Colour[1]
		if TableSawPer > 0.75 then 
			TableSawColour = TableSawUI.Colour[1]
		elseif TableSawPer > 0.5 then 
			TableSawColour = TableSawUI.Colour[2]
		elseif TableSawPer > 0.25 then 
			TableSawColour = TableSawUI.Colour[3]
		else
			TableSawColour = TableSawUI.Colour[4]
		end 
		local SawBladeColour = TableSawUI.Colour[1]
		if SawBladePer > 0.75 then 
			SawBladeColour = TableSawUI.Colour[1]
		elseif SawBladePer > 0.5 then 
			SawBladeColour = TableSawUI.Colour[2]
		elseif SawBladePer > 0.25 then 
			SawBladeColour = TableSawUI.Colour[3]
		else
			SawBladeColour = TableSawUI.Colour[4]
		end 
		
		-- 锯片耐久
		self:drawProgressBarVertical(TableSawUI.UIWndWidth - 67 , titlehight + 5, 10, 50, SawBladePer, SawBladeColour)
		
		
		-- 台锯耐久
		self:drawProgressBarHorizontal(1, TableSawUI.UIWndHight - (TableSawUI.SmallHeight + 1), TableSawUI.UIWndWidth - 2, TableSawUI.SmallHeight, TableSawPer, TableSawColour)
		
		--TableSawUI.UIWndWidth
		-- 居中文本
		local text = getText("IGUI_TableSawDurable", round(TableSawPer * 100.00, 2))
		local textWidth = getTextManager():MeasureStringX(UIFont.NewSmall, text)
		local centerX = (TableSawUI.UIWndWidth - textWidth) / 2
		-- 文本
		self:drawText(text, centerX , TableSawUI.UIWndHight - (TableSawUI.SmallHeight + 1), 1,1,1,1, UIFont.NewSmall);
	end 
end 


-- 更新UI
function TableSawUI:update()
	--print(self.tablesaw:getSquare())
    if not self.tablesaw then
        self:CloseWnd()
        return
    end
	local Square = self.tablesaw:getSquare()
	if Square then 
		local isfind = false
		local objList = Square:getObjects()
		for i = 0, objList:size() - 1 do
			local obj = objList:get(i)
			if obj == self.tablesaw then 
				isfind = true
				break
			end 
		end 
		if not isfind then 
			self:CloseWnd()
			return
		end 
	else 
		self:CloseWnd()
		return
	end 
	local timer = os.time()
	if math.abs(timer - self.timer) > 120 then 
		self:CloseWnd()
		return
	end 
	--local bodyPart = self.character:getBodyDamage():getBodyPart(BodyPartType.Hand_R)

end

-- 关闭回调
function TableSawUI:close()
	-- Invalidate the approach; its native validity check cancels further walking.
	self.walkToSawAction = nil
    local modData = self.character:getModData();
    modData.TableSawUIData = { x = self:getX(), y = self:getY()};

	if self.character then
		local queue = ISTimedActionQueue.getTimedActionQueue(self.character)
		for i,action in ipairs(queue.queue) do
			--print(action.Type)
			if action.Type == "ISRepairTableSaw" then
				action:forceCancel()
				action:forceStop()
			elseif action.Type == "ISInstallRemoveSawBlade" then
				action:forceCancel()
				action:forceStop()
			end
		end
	end
	
    TableSawUI.g_hWnd = nil;
    self:setVisible(false);
    self:removeFromUIManager();

end

-- 关闭窗口
function TableSawUI:CloseWnd()
    local ui = self.g_hWnd;
    if ui and ui:getIsVisible() then
        ui:close();
	end 
end 

-- 
function TableSawUI:new(x, y, width, height, character, tablesaw)
	local o = {};
	o = ISCollapsableWindowJoypad.new(self, x, y, width, height);
	o.playerNum = character:getPlayerNum() or -1;
	o.character = character;
	o.tablesaw = tablesaw;
	o:setResizable(false);
	o.title = getText("IGUI_TableSawTitle");
	--o.minimumWidth = TableSawUI.UIWndWidth;
	--o.minimumHeight = TableSawUI.UIWndHight;
	o.shownum = 0;
	o.texture = getTexture('media/textures/TableSaw_UI.png')
	o.texture2 = getTexture('media/textures/SawBlade_UI.png')
	o.Electricity = getTexture('media/textures/Electricity.png')
	o.UnElectricity = getTexture('media/textures/UnElectricity.png')
	
	o.Logtexture = getScriptManager():FindItem('Base.Log'):getNormalTexture();
	o.LargeBranchtexture = getScriptManager():FindItem('Base.LargeBranch'):getNormalTexture();
	o.Saplingtexture = getScriptManager():FindItem('Base.Sapling'):getNormalTexture();
	o.Planktexture = getScriptManager():FindItem('Base.Plank'):getNormalTexture();
	o.TreeBranch2texture = getScriptManager():FindItem('Base.TreeBranch2'):getNormalTexture();
	return o;
end 
