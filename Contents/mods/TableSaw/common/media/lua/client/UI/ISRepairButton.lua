
ISRepairButton = ISButton:derive("ISRepairButton")


-- 创建子窗口
function ISRepairButton:createChildren()
    ISButton.createChildren(self);

    self.tooltipnew = ISToolTip:new();
    self.tooltipnew:initialise();
    self.tooltipnew:addToUIManager();
    self.tooltipnew:setAlwaysOnTop(true);
    self.tooltipnew:setOwner(self);
    self.tooltipnew:setVisible(false);
	
	local des = ''
	-- 名字
	des = '<RGB:1,1,0>' .. getText("Tooltip_RepairNeed1") .. ' <LINE>'

	for i = 1,#RepairTableSawNeed do 
		local havenum = TableSawgetItemCount(self.character, RepairTableSawNeed[i][1])
		if havenum < RepairTableSawNeed[i][2] then 
			des = des .. string.format('<RGB:1,0,0>  %s(%d/%d) <LINE>',getItemNameFromFullType(RepairTableSawNeed[i][1]), havenum, RepairTableSawNeed[i][2])
		else 
			des = des .. string.format('<RGB:0,1,0>  %s(%d/%d) <LINE>',getItemNameFromFullType(RepairTableSawNeed[i][1]), havenum, RepairTableSawNeed[i][2])
		end 
	end 
	des = des .. string.format('<RGB:1,0.5,0> %s%d%%',getText("Tooltip_RepairRatio"),TableSawRepairPer*100.0)
	
	self.tooltipnew.description = des
end



-- 显示提示菜单
function ISRepairButton:showTooltip()
    self.tooltipnew:addToUIManager();
    self.tooltipnew:setVisible(true);
end

-- 隐藏提示菜单
function ISRepairButton:hideTooltip()
    self.tooltipnew:setVisible(false);
    self.tooltipnew:removeFromUIManager();
end

function ISRepairButton:update()
    if self:isMouseOver() then       -- 检查鼠标悬停
        if self.tooltipnew or self.tooltipUI then
            self:showTooltip()       -- 显示提示框
        end
    else
        self:hideTooltip()           -- 隐藏提示框
    end
end