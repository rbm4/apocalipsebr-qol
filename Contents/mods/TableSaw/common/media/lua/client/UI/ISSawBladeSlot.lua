
ISSawBladeSlot = ISUIElement:derive("ISSawBladeSlot")




function ISSawBladeSlot:render()
	self:drawRect(0, 0, self.width, self.height, 0.3, 0.4, 0.4, 0.4)
	
	if self.issawblade then 
		if self.ntype == 1 then 
			local newheight = self.height * self.sawbladeProgress
			self:drawRect(0, self.height - newheight, self.width, newheight, 0.7, 0, 1, 0)
		elseif self.ntype == 2 then 
			local newheight = self.height * (1 - self.sawbladeProgress)
			self:drawRect(0, self.height - newheight, self.width, newheight, 0.7, 0, 1, 0)
		end 
	end 
	
	self:drawRectBorder(0, 0, self.width, self.height, 2, 1, 1, 1, 1)
	
	if self.isshow then 
		self:drawTexture(self.texture, 0, 0, 1, 1, 1, 1)
	end 
end 


function ISSawBladeSlot.UpdateSawblade(myself,pre,ntype)
	--print(pre)
	myself.sawbladeProgress = pre
	myself.issawblade = true
	myself.ntype = ntype
end 

function ISSawBladeSlot.EndSawblade(myself)
	--print('ISSawBladeSlot.EndSawblade')
	myself.sawbladeProgress = 0
	myself.issawblade = false
	myself.ntype = 0
end 

function ISSawBladeSlot:SetTextureShow(isshow)
	self.isshow = isshow
end 

function ISSawBladeSlot:new(x, y, w, h, isshow)
	local o = ISUIElement.new(self, x, y, w, h)

	o.texture = getScriptManager():FindItem('Base.CircularSawblade'):getNormalTexture()

    o.texture:setWidth(44)
    o.texture:setHeight(44)
	o.isshow = isshow
	return o
end