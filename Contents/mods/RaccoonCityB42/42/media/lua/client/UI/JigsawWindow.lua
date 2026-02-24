
JigsawWindow = ISPanel:derive("JigsawWindow");

local WINDOW_WIDTH = 403
local WINDOW_HEIGHT = 530
JigsawWindow.MainWnd = nil


function JigsawWindow:setVisible(visible)
    self.javaObject:setVisible(visible);
end

function JigsawWindow:prerender()
    ISPanel.prerender(self)
end


function JigsawWindow:render()
    self:drawText(getText("IGUI_PuzzleWindowTitle"), self.width/2 - (getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_PuzzleWindowTitle")) / 2), 10, 1,1,1,1, UIFont.Small);
    self:drawRectBorder(0, 30, WINDOW_WIDTH, WINDOW_HEIGHT - 65, 1, 0.4, 0.4, 0.4)

end


function JigsawWindow:RemoveSprite(x, y, z, SpriteName)
    local _square = getCell():getGridSquare(x, y, z)
    local sqObjs     = _square:getObjects()
    local tbl        = {}
    for i = 0, sqObjs:size() - 1 do
        if not instanceof(sqObjs:get(i), "IsoWorldInventoryObject") then
            table.insert(tbl, sqObjs:get(i))
        end
    end
    for k, v in pairs(tbl) do
        if v:getSprite() ~= nil and v:getSprite():getName() == SpriteName then
            if isClient() then
                sledgeDestroy(v)
            else
                _square:transmitRemoveItemFromSquare(v)
            end
        end
    end
end

function JigsawWindow:onOptionMouseDown(button, x, y)
    if button.internal == "CANCEL" then
        self:setVisible(false);
        self:removeFromUIManager();
        self:close()
		JigsawWindow.MainWnd = nil
	elseif button.internal == "Last" then 
		--ISRe2Widget.RandomIndex()
		local player = getPlayer()
		local inv = player:getInventory()
		local re2_09 = inv:getItemFromType('re2_09')
		if re2_09 then 
			local removelist = {}
			local it = inv:getItems();
			
			for j = 0, it:size()-1 do
				local item = it:get(j);
				local strType = item:getType()
				if strType == 're2_09' then 
					table.insert(removelist, item)
				end 
			end
			for _, item in ipairs(removelist) do
				inv:DoRemoveItem(item)
			end 
			self:addChild(ISRe2Widget:new(self,3,3))
			--10223,10380,3
			-- 文字提示
			--HaloTextHelper.addText(player, getText("IGUI_PlayerText_OpenShimen"), HaloTextHelper.getColorRed())
			HaloTextHelper.addGoodText(player, getText("IGUI_PlayerText_OpenShimen"));
			-- 播放音效
			player:getEmitter():playSoundImpl("Shimen", IsoObject.new())
			-- 删除墙
			JigsawWindow:RemoveSprite(10223,10380,3, 'd_shisan_cannotdamaged_16')
			
			self:removeChild(button)
			local gameTime = getGameTime()
			local modData = gameTime:getModData()
			modData.JigsawCompleteNum = 3
		else 
			--HaloTextHelper.addText(player, getText("IGUI_PlayerText_NoRe2_09"), HaloTextHelper.getColorRed())
			HaloTextHelper.addBadText(player, getText("IGUI_PlayerText_NoRe2_09"));
			-- 播放音效
			player:getEmitter():playSoundImpl("PassWordError", IsoObject.new())
		end 
    end
end


function JigsawWindow:close()
	--print('JigsawWindow:close')
    ISPanel.close(self)
end


function JigsawWindow:createWindow(playerObj)
	if JigsawWindow.MainWnd then 
		local player = getSpecificPlayer(playerObj)
		HaloTextHelper.addText(player, getText("IGUI_PlayerText_CanNotOpen"), HaloTextHelper.getColorRed())
		return 
	end 
	local modal = JigsawWindow:new(Core:getInstance():getScreenWidth() - WINDOW_WIDTH - 100  , Core:getInstance():getScreenHeight()/2 - WINDOW_HEIGHT/2 - 50, WINDOW_WIDTH, WINDOW_HEIGHT)
	modal.character = playerObj
	
	modal:initialise()
	modal:addToUIManager()
	JigsawWindow.MainWnd = modal
end


function JigsawWindow:initialise()
    ISPanel.initialise(self);
	
    self.cancel = ISButton:new(self:getWidth()  - 110, self:getHeight() - 25, 100, 20, getText("IGUI_Button_Close1"), self, JigsawWindow.onOptionMouseDown);
    self.cancel.internal = "CANCEL";
    self.cancel:initialise();
    self.cancel:instantiate();
    self.cancel.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.cancel);
	
    --self.last = ISButton:new(10, self:getHeight() - 25, 100, 20, getText("IGUI_Button_PutLast"), self, JigsawWindow.onOptionMouseDown);
    --self.last.internal = "Last";
    --self.last:initialise();
    --self.last:instantiate();
    --self.last.borderColor = {r=1, g=1, b=1, a=0.1};
    --self:addChild(self.last);
	local gameTime = getGameTime()
	local modData = gameTime:getModData()
	if modData.JigsawCompleteNum and modData.JigsawCompleteNum == 2 then 
		--JigsawWindow:AddPutButton()
		self.last = ISButton:new(10, self:getHeight() - 25, 100, 20, getText("IGUI_Button_PutLast"), self, JigsawWindow.onOptionMouseDown);
		self.last.internal = "Last";
		self.last:initialise();
		self.last:instantiate();
		self.last.borderColor = {r=1, g=1, b=1, a=0.1};
		self:addChild(self.last);
	end 
	
	ISRe2Widget.addPicWnd(self)
end

function JigsawWindow:AddPutButton()
    self.last = ISButton:new(10, self:getHeight() - 25, 100, 20, getText("IGUI_Button_PutLast"), self, JigsawWindow.onOptionMouseDown);
    self.last.internal = "Last";
    self.last:initialise();
    self.last:instantiate();
    self.last.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.last);
end 


function JigsawWindow:new(x, y, width, height)
    local o = {};
    o = ISPanel:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;
    o.variableColor={r=0.9, g=0.55, b=0.1, a=1};
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
    o.backgroundColor = {r=0, g=0, b=0, a=0.8};

    o.zOffsetSmallFont = 25;
    o.moveWithMouse = true;
    o:setWantKeyEvents(true)
    return o;
end