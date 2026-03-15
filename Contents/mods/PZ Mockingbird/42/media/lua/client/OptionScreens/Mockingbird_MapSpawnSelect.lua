require "ISUI/ISScrollingListBox"

oldMapSpawnSelect_fillList = MapSpawnSelect.fillList

local function getModOptValue(optId)
    local modOption = PZAPI.ModOptions:getOptions("mockingbirdModOpt")
    return modOption:getOption(optId):getValue()
end

function MapSpawnSelect:fillList()
	self.listbox:clear()
	WORLD_MAP = nil
	self.mapPanel:clear()
	local spawnSelectImagePyramid = nil
	
	self.sortedList = {};
	self.notSortedList = {};
	
	local regions = self:getSpawnRegions()
	if not regions then return end
	for _,v in ipairs(regions) do
		local info = getMapInfo(v.name)
		if info then
			local item = {};
			item.name = info.title or getText("IGUI_NO_TITLE");
			item.region = v;
			item.dir = v.name;
			item.desc = info.description or getText("IGUI_NO_DESCRIPTION");
			if info.spawnSelectImagePyramid then
				spawnSelectImagePyramid = info.spawnSelectImagePyramid
			end
			item.zoomX = info.zoomX
			item.zoomY = info.zoomY
			item.zoomS = info.zoomS
			item.demoVideo = info.demoVideo
			self:checkSorted(item);
		else
			local item = {}
			item.name = v.name;
			item.region = v;
			item.dir = "";
			item.desc = "";
			item.worldimage = nil;
			self:checkSorted(item);
		end
	end
	
	if #self.listbox.items > 1 then
        local item = {}
        item.name = getText("UI_mapspawn_random");
        item.region = nil;
        item.dir = "";
        item.desc = "";
        item.worldimage = nil;
		table.insert(self.notSortedList, item);
    end

	if getModOptValue("0") then
		spawnSelectImagePyramid = getMapInfo("Mockingbird").dir .. "\\spawnSelectImagePyramid.zip"
	elseif not getModOptValue("1") then
		spawnSelectImagePyramid = nil
	end

	if spawnSelectImagePyramid then
		self.mapPanel:setImagePyramid(spawnSelectImagePyramid)
	else
		for _,v in ipairs(regions) do
			local info = getMapInfo(v.name)
			if info then
				self.mapPanel:initMapData('media/maps/'..v.name)
				for _,dir in ipairs(info.lots) do
					self.mapPanel:initMapData('media/maps/'..dir)
				end
			end
		end
	end
	
	-- list has been sorted with MapsOrder
	for i,v in ipairs(self.sortedList) do
		self.listbox:addItem(v.name, v);
	end
	
	for i,v in ipairs(self.notSortedList) do
		self.listbox:addItem(v.name, v);
	end
	
	self:hideOrShowSaveName()
	self:recalculateMapSize()
	
    if self.textEntry ~= nil and self.textEntry:getInternalText() == "" then
        local sdf = SimpleDateFormat.new("yyyy-MM-dd_HH-mm-ss", Locale.ENGLISH);
        self.textEntry:setText(sdf:format(Calendar.getInstance():getTime()));
    end
	
	self.mapPanel.shownInitialLocation = false
end
