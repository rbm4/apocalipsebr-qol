require "Hotbar/ISHotbarAttachDefinition"

--thank you senny/enobdercas for this bit of code :3

if not ISHotbarAttachDefinition then
	return
end

local size = size
local get = get


local MOD_DATA = {
	SmallBeltLeft = {
		Torch           = "BeltTorchLeft",
		Torchb          = "BeltTorchLeftSmall",
		TorchSmall      = "BeltTorchLeftSmall",
		HandTorchSmall  = "BeltTorchLeftVerySmall",
		HandTorchBig    = "BeltTorchLeftSmall",
		OldFlashlight   = "BeltOldFlashlightLeft",
		TorchAngled     = "BeltTorchLeftAngled",
		AZMilitaryTorch = "AZMilitaryBeltLeft"

	},
	SmallBeltRight = {
		Torch           = "BeltTorchRight",
		Torchb          = "BeltTorchRightSmall",
		TorchSmall      = "BeltTorchRightSmall",
		HandTorchSmall  = "BeltTorchRightVerySmall",
		HandTorchBig    = "BeltTorchRightSmall",
		OldFlashlight   = "BeltOldFlashlightRight",
		TorchAngled     = "BeltTorchRightAngled",
		AZMilitaryTorch = "AZMilitaryBeltRight"
	},
	WebbingLeft = {
		TorchAngled = "WebbingTorchLeftAngled",
		AZMilitaryTorch = "WebbingTorchLeftAngled"
	},
	WebbingRight = {
		TorchAngled = "WebbingTorchRightAngled",
		AZMilitaryTorch = "WebbingTorchRightAngled"
	},
	AZWebbingLeft = {
		TorchAngled = "WebbingTorchLeftAngled",
		AZMilitaryTorch = "WebbingTorchLeftAngled"
	},
	AZWebbingRight = {
		TorchAngled = "WebbingTorchRightAngled",
		AZMilitaryTorch = "WebbingTorchRightAngled"
	}
}
for _, t in pairs(ISHotbarAttachDefinition) do
	if t.type and MOD_DATA[t.type] then
		for k, v in pairs(MOD_DATA[t.type]) do
			if v == 0 and t.replacement then
				t.replacement[k] = nil
			elseif t.attachments then
				t.attachments[k] = v ~= 0 and v or nil
			else
				print('ERROR: Unknown mod data option.')
			end
		end
	end
end
