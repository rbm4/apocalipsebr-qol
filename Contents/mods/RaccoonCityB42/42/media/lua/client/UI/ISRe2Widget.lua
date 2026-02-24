
ISRe2Widget = ISUIElement:derive("ISRe2Widget")

ISRe2Widget.IsFirst = false


ISRe2Widget.Texture = 
{
	'media/textures/re2/re2_01.png',
	'media/textures/re2/re2_02.png',
	'media/textures/re2/re2_03.png',
	'media/textures/re2/re2_04.png',
	'media/textures/re2/re2_05.png',
	'media/textures/re2/re2_06.png',
	'media/textures/re2/re2_07.png',
	'media/textures/re2/re2_08.png',
	'media/textures/re2/re2_09.png',
}

ISRe2Widget.WndData = ISRe2Widget.WndData or
{
	-- 第一行
	{
		{x = 0   , y = 0   , index = 1},
		{x = 133 , y = 0   , index = 2},
		{x = 266 , y = 0   , index = 3},
	},
	-- 第二行
	{
		{x = 0   , y = 154 , index = 4},
		{x = 133 , y = 154 , index = 5},
		{x = 266 , y = 154 , index = 6},
	},
	-- 第三行
	{
		{x = 0   , y = 308 , index = 7},
		{x = 133 , y = 308 , index = 8},
		{x = 266 , y = 308 , index = 9},
	},
}

ISRe2Widget.IndexList = {1,2,3,4,5,6,7,8,9}



-- 检查是否拼图完成
function ISRe2Widget:inspectComplete()
    local WndData = ISRe2Widget.WndData
    -- 遍历WndData，检查index是否按顺序排列
    for row = 1, #WndData do
        for col = 1, #WndData[row] do
            local expectedIndex = (row - 1) * 3 + col
            if WndData[row][col].index ~= expectedIndex then
                -- 一旦发现index不按顺序，立即返回false
                return false
            end
        end
    end
    -- 如果所有index都按顺序，则返回true
    return true
end

-- 随机打乱拼图直到找到一个可解的拼图
function ISRe2Widget.RandomIndex()
	local arr = ISRe2Widget.IndexList
	
	for i = #arr-1, 2, -1 do
		local j = ZombRand(0, i - 1) + 1
		-- 交换数组arr中的第i与第j个元素
		arr[i], arr[j] = arr[j], arr[i]
	end
	--print(arr[1],arr[2],arr[3],arr[4],arr[5],arr[6],arr[7],arr[8])
	local inversions = 0
	for i = 1, #arr-1 do
		--for j = i + 1, #arr do
		for j = i, #arr-1 do
			if arr[i] > arr[j] then
				inversions = inversions + 1
			end
		end
	end
	--print("inversions:",inversions)
	if inversions % 2 == 0 then
		--print("oushu")
	else
		-- 交换第1和第2项使其变成偶数逆序数
		local temp = arr[1]
		arr[1] = arr[2]
		arr[2] = temp
		--print("qishu")
	end
	-- 更新WndData中的index属性
	local currentIndex = 1
	for rowIndex, row in ipairs(ISRe2Widget.WndData) do
		for elemIndex, elem in ipairs(row) do
			elem.index = arr[currentIndex]
			currentIndex = currentIndex + 1
		end
	end
end



-- 添加图片窗口
function ISRe2Widget.addPicWnd(parent)
	local gameTime = getGameTime()
	local modData = gameTime:getModData()
	if ISRe2Widget.IsFirst == false and modData.JigsawCompleteNum ~= 2 then 
		ISRe2Widget.RandomIndex()
		ISRe2Widget.IsFirst = true
	end 
	for row = 1,3 do 
		for col = 1,3 do
			if not (ISRe2Widget.WndData[row][col].index == 9) then 
				parent:addChild(ISRe2Widget:new(parent,row,col))
			end 
		end 
	end 
end 

-- 获取移动位置
function ISRe2Widget:GetMovePos(row,col)
	if row < 3 and ISRe2Widget.WndData[row + 1][col].index == 9 then 
		return row + 1,col
	elseif row > 1 and ISRe2Widget.WndData[row - 1][col].index == 9 then 
		return row - 1,col
	elseif col < 3 and ISRe2Widget.WndData[row][col + 1].index == 9 then 
		return row,col + 1
	elseif col > 1 and ISRe2Widget.WndData[row][col - 1].index == 9 then 
		return row,col - 1
	end 
	return 0,0
end 


-- 鼠标按下消息
function ISRe2Widget:onMouseDown(x, y)
	local gameTime = getGameTime()
	local modData = gameTime:getModData()
	--if not modData.IsJigsawComplete or modData.IsJigsawComplete == false then 
	if modData.JigsawCompleteNum < 2 then 
		local nRow,nCol = ISRe2Widget:GetMovePos(self.row,self.col)
		if nRow ~= 0 and nCol ~= 0 then 
			ISRe2Widget.WndData[nRow][nCol].index = ISRe2Widget.WndData[self.row][self.col].index
			ISRe2Widget.WndData[self.row][self.col].index = 9
			
			self.parent:addChild(ISRe2Widget:new(self.parent,nRow,nCol))
			--self.parent:removeChild(self.parent.selectedWire)
			self.parent:removeChild(self)
			local player = getPlayer()
			player:getEmitter():playSoundImpl("slide", IsoObject.new())
			-- 每次变动都检查下是否完成
			if ISRe2Widget:inspectComplete() then 
				--print('JigsawComplete')
				-- 拼图完成

				--modData.IsJigsawComplete = true
				modData.JigsawCompleteNum = 2
				
				self.parent:AddPutButton()
			end 
		end 
	end 
	return true
end


function ISRe2Widget:render()
	self:drawTexture(self.texture, 0, 0, 1, 1, 1, 1)
end

function ISRe2Widget:new(parent,row,col)
	local texture = getTexture(ISRe2Widget.Texture[ISRe2Widget.WndData[row][col].index])
	local width = texture:getWidth()
	local height = texture:getHeight()
	local x = ISRe2Widget.WndData[row][col].x
	local y = ISRe2Widget.WndData[row][col].y
	local o = ISUIElement.new(self, x + 2 , y + 30, width, height)
	o.width = width
	o.height = height
	o.isShow = false
	o.parent = parent
	o.texture = texture
	o.row = row 
	o.col = col
	return o
end