
ResidentEvilPoliceMusic = ResidentEvilPoliceMusic or {}

ResidentEvilPoliceMusic.Music = nil



-- 是否在警局内
function ResidentEvilPoliceMusic.IsInPoliceStation(px,py,pz)
	if pz == -1 then 
		if px >= 10203 and px <= 10245 and py >= 10349 and py <= 10430 then 
			return true 
		end 
	elseif pz == 0 then 
		if px >= 10209 and px <= 10235 and py >= 10389 and py <= 10413 then
			return true 
		elseif px >= 10212 and px <= 10236 and py >= 10376 and py <= 10391 then
			return true 
		elseif px >= 10211 and px <= 10235 and py >= 10355 and py <= 10377 then
			return true 
		elseif px >= 10211 and px <= 10228 and py >= 10349 and py <= 10354 then
			return true 
		elseif px >= 10209 and px <= 10210 and py >= 10373 and py <= 10377 then
			return true 
		end 
	else 
		if px >= 10203 and px <= 10244 and py >= 10349 and py <= 10414 then
			return true 
		end 
	end 

	return false
end 


function ResidentEvilPoliceMusic.OnPlayerUpdate(player)

	local isPlay = SandboxVars.DisablePoliceMusic
	if not isPlay then 
		local px = math.floor(player:getX())
		local py = math.floor(player:getY())
		local pz = math.floor(player:getZ())
		if ResidentEvilPoliceMusic.IsInPoliceStation(px,py,pz) then 
			if ResidentEvilPoliceMusic.Music == nil then 
				ResidentEvilPoliceMusic.Music = player:getEmitter():playSoundImpl("ResidentEvilPolice", IsoObject.new())
			end 
		else 
			if ResidentEvilPoliceMusic.Music then 
				player:stopOrTriggerSound(ResidentEvilPoliceMusic.Music)
				ResidentEvilPoliceMusic.Music = nil
			end 
		end 
	else 
		if ResidentEvilPoliceMusic.Music then 
			player:stopOrTriggerSound(ResidentEvilPoliceMusic.Music)
			ResidentEvilPoliceMusic.Music = nil
		end 
	end 
end 




Events.OnPlayerUpdate.Add(ResidentEvilPoliceMusic.OnPlayerUpdate)