
PasswordDoorUI    = ISPanel:derive("PasswordDoorUI")

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)


PasswordDoorUIData = PasswordDoorUIData or {}
PasswordDoorUIData.BorderColor = { r = 1, g = 1, b = 1, a = 0.5 }
PasswordDoorUIData.BackColor = { r = 0, g = 0, b = 0, a = 0.5 }


PasswordDoorUIData.strInputPassWord = ''

PasswordDoorUIData.NumList = {}

PasswordDoorUIData.NumList['0'] = '0'
PasswordDoorUIData.NumList['1'] = '1'
PasswordDoorUIData.NumList['2'] = '2'
PasswordDoorUIData.NumList['3'] = '3'
PasswordDoorUIData.NumList['4'] = '4'
PasswordDoorUIData.NumList['5'] = '5'
PasswordDoorUIData.NumList['6'] = '6'
PasswordDoorUIData.NumList['7'] = '7'
PasswordDoorUIData.NumList['8'] = '8'
PasswordDoorUIData.NumList['9'] = '9'



function PasswordDoorUI:initialise()
    ISPanel.initialise(self)

	-- 每次打开密码窗口清空
	PasswordDoorUIData.strInputPassWord = ''

	--print('self:getWidth()=',self:getWidth())
	--print('self:getHeight()=',self:getHeight())

    local buttonWid  = getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_Button_Close1")) + 10
    local buttonHgt  = FONT_HGT_SMALL + 5
    local padBottom  = 10

    self.no          = ISButton:new(self:getWidth() / 2 - buttonWid / 2, self:getHeight() - padBottom - buttonHgt, buttonWid, buttonHgt, getText("IGUI_Button_Close1"), self, PasswordDoorUI.onClick)
    self.no.internal = "CANCEL"
    self.no:initialise()
    self.no:instantiate()
    self.no.borderColor = PasswordDoorUIData.BorderColor
    self:addChild(self.no)

	local nTop = 60
	local nLeft = 13
	-- 编辑框
	local height    = FONT_HGT_MEDIUM + 5
	local width     = 130
	self.password      = ISTextEntryBox:new("", 60, nTop , width, height)
	self.password.font = UIFont.Medium
	self.password:initialise()
	self.password:instantiate()
	self.password:setOnlyNumbers(true)
	self:addChild(self.password)
	
	local numButtonWide  = getTextManager():MeasureStringX(UIFont.Small, "0") + 30
	local numButtonHigh  = FONT_HGT_SMALL + 5
	for x = 1,3 do 
		for y = 1,3 do 
			local strButton = ''..(x + (y - 1) * 3)
			self.num = ISButton:new(nLeft + x * (numButtonWide + 10), nTop + y * (numButtonHigh + 10) , numButtonWide, numButtonHigh, strButton, self, PasswordDoorUI.onClick)
			self.num.internal = strButton
			self.num:initialise()
			self.num:instantiate()
			self:addChild(self.num)
		end 
	end 
	-- 0
	self.num0 = ISButton:new(nLeft + 1 * (numButtonWide + 10), nTop + 4 * (numButtonHigh + 10) , numButtonWide, numButtonHigh, "0", self, PasswordDoorUI.onClick)
	self.num0.internal = "0"
	self.num0:initialise()
	self.num0:instantiate()
	self:addChild(self.num0)
	-- 清除 为了整洁就不根据文字来计算按钮大小了
	self.clean = ISButton:new(nLeft + 2 * (numButtonWide + 10), nTop + 4 * (numButtonHigh + 10) , numButtonWide, numButtonHigh, getText("IGUI_Button_Clean1"), self, PasswordDoorUI.onClick)
	self.clean.internal = "clean"
	self.clean:initialise()
	self.clean:instantiate()
	self:addChild(self.clean)
	-- 开启 为了整洁就不根据文字来计算按钮大小了
	self.open = ISButton:new(nLeft + 3 * (numButtonWide + 10), nTop + 4 * (numButtonHigh + 10) , numButtonWide, numButtonHigh, getText("IGUI_Button_Open1"), self, PasswordDoorUI.onClick)
	self.open.internal = "open"
	self.open:initialise()
	self.open:instantiate()
	self:addChild(self.open)
	


	
end

function PasswordDoorUI:destroy()
    UIManager.setShowPausedMessage(true)
    self:setVisible(false)
    self:removeFromUIManager()
end

function PasswordDoorUI:AddSprite(x, y, z, SpriteName,player)
	local _square1 = getCell():getGridSquare(x, y, z)
	local cursor1 = ISBrushToolTileCursor:new(SpriteName, SpriteName, player)
	cursor1:create(_square1:getX(), _square1:getY(), _square1:getZ(), nil, SpriteName)
end 


function PasswordDoorUI:RemoveSprite(x, y, z, SpriteName)
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

function PasswordDoorUI:onClick(_button)
    if _button.internal == "CANCEL" then
        self:destroy()
        return
	elseif PasswordDoorUIData.NumList[_button.internal] then 
		if string.len(PasswordDoorUIData.strInputPassWord) < 6 then
			PasswordDoorUIData.strInputPassWord = PasswordDoorUIData.strInputPassWord .. PasswordDoorUIData.NumList[_button.internal]
		end 
		-- 更新编辑框
		self.password:setText(PasswordDoorUIData.strInputPassWord);
		local player = getPlayer()
		player:getEmitter():playSoundImpl("PassWordBotton", IsoObject.new())
		return 
	elseif _button.internal == "clean" then
		PasswordDoorUIData.strInputPassWord = ''
		-- 更新编辑框
		self.password:setText(PasswordDoorUIData.strInputPassWord);
		local player = getPlayer()
		player:getEmitter():playSoundImpl("PassWordBotton", IsoObject.new())
		return 
	elseif _button.internal == "open" then
		-- 判断密码是否正确
		local istrue = false
		local gameTime = getGameTime()
		local modData = gameTime:getModData()
		if modData.strPassWord and modData.strPassWord ~= '' then -- 改为全局永久储存
		--if RaccoonCityPasswordData.strPassWord and RaccoonCityPasswordData.strPassWord ~= '' then 
			--if PasswordDoorUIData.strInputPassWord and PasswordDoorUIData.strInputPassWord == RaccoonCityPasswordData.strPassWord then 
			if PasswordDoorUIData.strInputPassWord and PasswordDoorUIData.strInputPassWord == modData.strPassWord then 
				istrue = true
			end 
		end 
		local player = getPlayer()
		if istrue then 
			--HaloTextHelper.addText(player, getText("IGUI_PlayerText_PassWordCorrect"), HaloTextHelper.getColorRed())
			HaloTextHelper.addGoodText(player, getText("IGUI_PlayerText_PassWordCorrect"));
			PasswordDoorUI:RemoveSprite(10155,9926,0, 'd_shisan_cannotdamaged_8')
			PasswordDoorUI:RemoveSprite(10156,9926,0, 'd_shisan_cannotdamaged_9')
			PasswordDoorUI:RemoveSprite(10157,9926,0, 'd_shisan_cannotdamaged_10')
			PasswordDoorUI:RemoveSprite(10158,9926,0, 'd_shisan_cannotdamaged_11')
			PasswordDoorUI:RemoveSprite(10159,9926,0, 'd_shisan_cannotdamaged_12')
			
			PasswordDoorUI:AddSprite(10155,9926,0, 'shisan_newbuild_48' , player)
			PasswordDoorUI:AddSprite(10156,9926,0, 'shisan_newbuild_49' , player)
			PasswordDoorUI:AddSprite(10157,9926,0, 'shisan_newbuild_50' , player)
			PasswordDoorUI:AddSprite(10158,9926,0, 'shisan_newbuild_51' , player)
			PasswordDoorUI:AddSprite(10159,9926,0, 'shisan_newbuild_52' , player)
			
			player:getEmitter():playSoundImpl("GarageGateOpen", IsoObject.new())

		else
			--HaloTextHelper.addText(player, getText("IGUI_PlayerText_PassWordError"), HaloTextHelper.getColorRed())
			HaloTextHelper.addBadText(player, getText("IGUI_PlayerText_PassWordError"));
			player:getEmitter():playSoundImpl("PassWordError", IsoObject.new())
		end 
		-- 关闭窗口
		self:destroy()
		return
    end
end

function PasswordDoorUI:render()
	self:drawTextCentre(getText("IGUI_Text_PassWordDoor"), self:getWidth() / 2, 10, 1, 1, 1, 1, UIFont.NewLarge)
end

function PasswordDoorUI:new( _width, _height, _player)
	local o = {}
	local x = getCore():getScreenWidth() / 2 - (_width / 2)
	local y = getCore():getScreenHeight() / 2 - (_height / 2)
	o       = ISPanel:new(x, y, _width, _height)
	setmetatable(o, self)
	self.__index      = self
	o.moveWithMouse   = true
	o.borderColor     = PasswordDoorUIData.BorderColor
	o.backgroundColor = PasswordDoorUIData.BackColor
	
	self.player       = _player
	return o
end


