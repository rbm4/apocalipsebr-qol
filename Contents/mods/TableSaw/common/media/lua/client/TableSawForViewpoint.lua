
local isok = false
local function onGameStart()
	if not Viewpoint or not Viewpoint.ModelPacks then return end
	if not isok then 
		local ok,res = pcall(Viewpoint.ModelPacks.register,"TableSaw","media/models/tableSaw.properties")
		--print("[TableSaw]ok:",ok)
		--print("[TableSaw]res:",res)
		if ok and res then 
			--print("ok [TableSaw]:"..tostring(res))
			isok = true 
		elseif not ok then
			print("no [TableSaw]:"..tostring(res))
		end 
	end 
end
Events.OnGameBoot.Add(onGameStart)
Events.OnGameStart.Add(onGameStart)
onGameStart()
