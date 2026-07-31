

--require 'BuildlFenceAndDoor'


RaccoonCityBuildMenu = RaccoonCityBuildMenu or {}


RaccoonCityBuildMenu.split = string.split



RaccoonCityBuildMenu.RecipeList = 
{
	['Make pointed wooden fences'] = 'Tooltip_MakeWoodenFences',
	['Make pointed wooden door'] = 'Tooltip_MakeWoodenDoor',
	['Make pointed wooden defense fence'] = 'Tooltip_MakeWoodenDefenseFence',
	['Make Restricted area fences'] = 'Tooltip_MakeRestrictedFences',
	['Make Restricted area door'] = 'Tooltip_MakeRestrictedDoor',
	['Make Short fence double door'] = 'Tooltip_MakeShortFenceDoubleDoor',
	['Make Barbed wire mesh'] = 'Tooltip_MakeBarbedWireMesh',
}

--木工12
--烹饪13
--耕作14
--急救15
--电工16
--金工17
--技工18

RaccoonCityBuildMenu.BuildList = 
{
	-- 子菜单1
	{
		tSubMenu = 'ContextMenu_RoundWoodenFence',
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_RoundWoodenWall',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildWoodWall,
			-- 显示图像
			--tSprite = 'shisan_otherfurniture_0',
			tSprite = {'shisan_otherfurniture_0','shisan_otherfurniture_1'},
			-- 提示框文本
			tDescription = 'Tooltip_RoundWoodenFence',
			-- 需要的工具
			--tNeedTool1 = 'Hammer',
			--tNeedTool2 = '',
			tNeedTool = {'Hammer'},
			-- 需要技能
			tNeedSkillNum = 12,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:Woodwork',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			-- 杂志
			tMagazine = 'Make pointed wooden fences',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 2},-- 原木
				{tMaterial = 'Base.RippedSheets' , Amount = 1},-- 碎布条RippedSheets Rope
				{tMaterial = 'Base.Nails' , Amount = 4},-- 钉子
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_RoundWoodenWallA',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildWoodWall,
			-- 显示图像
			--tSprite = 'shisan_otherfurniture_0',
			tSprite = {'shisan_otherfurniture_26','shisan_otherfurniture_27'},
			-- 提示框文本
			tDescription = 'Tooltip_RoundWoodenFence',
			-- 需要的工具
			--tNeedTool1 = 'Hammer',
			--tNeedTool2 = '',
			tNeedTool = {'Hammer'},
			-- 需要技能
			tNeedSkillNum = 12,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:Woodwork',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			-- 杂志
			tMagazine = 'Make pointed wooden fences',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 2},-- 原木
				{tMaterial = 'Base.RippedSheets' , Amount = 1},-- 碎布条RippedSheets Rope
				{tMaterial = 'Base.Nails' , Amount = 4},-- 钉子
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_RoundWoodenObliqueWall',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildWoodWall,
			-- 显示图像
			--tSprite = 'shisan_otherfurniture_2',
			tSprite = {'shisan_otherfurniture_2'},
			-- 提示框文本
			tDescription = 'Tooltip_RoundWoodenFence',
			-- 需要的工具
			tNeedTool = {'Hammer'},
			-- 需要技能
			tNeedSkillNum = 12,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:Woodwork',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			-- 杂志
			tMagazine = 'Make pointed wooden fences',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 4},-- 原木
				{tMaterial = 'Base.RippedSheets' , Amount = 2},-- 绳索
				{tMaterial = 'Base.Nails' , Amount = 8},-- 钉子
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_RoundWoodenColumn',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildWoodWall,
			-- 显示图像
			--tSprite = 'shisan_otherfurniture_3',
			tSprite = {'shisan_otherfurniture_3'},
			-- 提示框文本
			tDescription = 'Tooltip_RoundWoodenFence',
			-- 需要的工具
			tNeedTool = {'Hammer'},
			-- 需要技能
			tNeedSkillNum = 12,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:Woodwork',
			-- 技能经验
			tSkillXp = 5,
			tCorner = true,
			tPillar = true,
			-- 杂志
			tMagazine = 'Make pointed wooden fences',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 1},-- 原木
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_RoundWoodenDoubleDoor',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildDoubleDoor,
			-- 显示图像
			--tSprite = 'shisan_furnace_40',
			tSprite = {'shisan_furnace_'},
			-- 提示框文本
			tDescription = 'Tooltip_RoundWoodenDoubleDoor',
			-- 需要的工具
			tNeedTool = {'Hammer'},
			-- 需要技能
			tNeedSkillNum = 12,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:Woodwork',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			tDoubleDoor = true,
			tSpriteIndex = 48,
			-- 杂志
			tMagazine = 'Make pointed wooden door',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 8},-- 原木
				{tMaterial = 'Base.RippedSheets' , Amount = 4},-- 绳索
				{tMaterial = 'Base.Nails' , Amount = 16},-- 钉子
				{tMaterial = 'Base.Hinge' , Amount = 4},-- 门铰链
				{tMaterial = 'Base.Screws' , Amount = 4},-- 螺丝
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_RoundWoodenDefenseFenceSE',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence,
			-- 显示图像
			--tSprite = 'shisan_metalfence_0',
			tSprite = {'shisan_otherfurniture_10','shisan_otherfurniture_11','shisan_otherfurniture_9','shisan_otherfurniture_8'},
			-- 提示框文本
			tDescription = 'Tooltip_RoundWoodenFence',
			-- 需要的工具
			tNeedTool = {'Hammer'},
			-- 需要技能
			tNeedSkillNum = 12,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:Woodwork',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			-- 杂志
			tMagazine = 'Make pointed wooden defense fence',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 4},-- 原木
				{tMaterial = 'Base.RippedSheets' , Amount = 4},-- 碎布条
				{tMaterial = 'Base.Nails' , Amount = 8},-- 钉子
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_RoundWoodenDefenseFenceNW',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence,
			-- 显示图像
			--tSprite = 'shisan_metalfence_0',
			tSprite = {'shisan_otherfurniture_14','shisan_otherfurniture_15','shisan_otherfurniture_13','shisan_otherfurniture_12'},
			-- 提示框文本
			tDescription = 'Tooltip_RoundWoodenFence',
			-- 需要的工具
			tNeedTool = {'Hammer'},
			-- 需要技能
			tNeedSkillNum = 12,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:Woodwork',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			-- 杂志
			tMagazine = 'Make pointed wooden defense fence',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 4},-- 原木
				{tMaterial = 'Base.RippedSheets' , Amount = 4},-- 碎布条
				{tMaterial = 'Base.Nails' , Amount = 8},-- 钉子
			},
		},
		--{
		--	-- 菜单名字
		--	tMenuName = 'ContextMenu_BambooFloor',
		--	-- 点击函数
		--	tFunc = RaccoonCityBuildMenu.onBuildTwoSpriteFloor,
		--	-- 显示图像
		--	--tSprite = 'shisan_otherfurniture_3',
		--	tSprite = {'shisan_floor_01_2','shisan_floor_01_3'},
		--	-- 提示框文本
		--	tDescription = 'Tooltip_BambooFloor',
		--	-- 需要的工具
		--	tNeedTool = {'Hammer'},
		--	-- 需要技能
		--	tNeedSkillNum = 12,
		--	-- 需要几级
		--	tNeedSkillLevel = 4,
		--	-- 技能经验名
		--	tSkillXpName = 'xp:Woodwork',
		--	-- 技能经验
		--	tSkillXp = 1,
		--	tCorner = false,
		--	tPillar = false,
		--	-- 杂志
		--	tMagazine = '',
		--	-- 需要的材料列表
		--	tNeedMaterials = 
		--	{
		--		{tMaterial = 'Base.SugarcaneDry' , Amount = 1},-- 甘蔗 干
		--		{tMaterial = 'Base.Nails' , Amount = 4},-- 钉子
		--	},
		--},
	},
	-- 子菜单2
	{
		tSubMenu = 'ContextMenu_RestrictedAreaFence',
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_RestrictedAreaFence1',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence,
			-- 显示图像
			--tSprite = 'shisan_metalfence_0',
			tSprite = {'shisan_metalfence_2','shisan_metalfence_3','shisan_metalfence_1','shisan_metalfence_0'},
			-- 提示框文本
			tDescription = 'Tooltip_RestrictedAreaFence',
			-- 需要的工具
			tNeedTool = {'Hammer','WeldingMask'},
			-- 需要技能
			tNeedSkillNum = 24,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:MetalWelding',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			-- 杂志
			tMagazine = 'Make Restricted area fences',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.Wire' , Amount = 4}, -- 铁丝
				{tMaterial = 'Base.MetalPipe' , Amount = 2}, -- 金属管
				{tMaterial = 'Base.ScrapMetal' , Amount = 1}, -- 金属废料
				--{tMaterial = 'Base.Stone2' , Amount = 1}, -- 石块
				{tMaterial = 'Base.WeldingRods' , Amount = 2}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 5}, -- 喷灯
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_RestrictedAreaObliqueFence',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence,
			-- 显示图像
			--tSprite = 'shisan_metalfence_4',
			tSprite = {'shisan_metalfence_4'},
			-- 提示框文本
			tDescription = 'Tooltip_RestrictedAreaFence',
			-- 需要的工具
			tNeedTool = {'Hammer','WeldingMask'},
			-- 需要技能
			tNeedSkillNum = 24,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:MetalWelding',
			-- 技能经验
			tSkillXp = 5,
			tCorner = true,
			tPillar = false,
			-- 杂志
			tMagazine = 'Make Restricted area fences',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.Wire' , Amount = 4}, -- 铁丝
				{tMaterial = 'Base.MetalPipe' , Amount = 2}, -- 金属管
				{tMaterial = 'Base.ScrapMetal' , Amount = 1}, -- 金属废料
				--{tMaterial = 'Base.Stone2' , Amount = 1}, -- 石块
				{tMaterial = 'Base.WeldingRods' , Amount = 2}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 5}, -- 喷灯
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_RestrictedAreaColumn',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence,
			-- 显示图像
			--tSprite = 'shisan_metalfence_5',
			tSprite = {'shisan_metalfence_5'},
			-- 提示框文本
			tDescription = 'Tooltip_RestrictedAreaFence',
			-- 需要的工具
			tNeedTool = {'Hammer','WeldingMask'},
			-- 需要技能
			tNeedSkillNum = 24,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:MetalWelding',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = true,
			-- 杂志
			tMagazine = 'Make Restricted area fences',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.MetalPipe' , Amount = 1}, -- 金属管
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 3}, -- 喷灯
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_RestrictedAreaDoubleDoor',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildDoubleDoor,
			-- 显示图像
			--tSprite = 'shisan_metalfence_8',
			tSprite = {'shisan_metalfence_'},
			-- 提示框文本
			tDescription = 'Tooltip_RestrictedAreaDoubleDoor',
			-- 需要的工具
			tNeedTool = {'Hammer','WeldingMask'},
			-- 需要技能
			tNeedSkillNum = 24,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:MetalWelding',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			tDoubleDoor = true,
			tSpriteIndex = 16,
			-- 杂志
			tMagazine = 'Make Restricted area door',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.Wire' , Amount = 20}, -- 铁丝
				{tMaterial = 'Base.MetalPipe' , Amount = 8}, -- 金属管
				{tMaterial = 'Base.ScrapMetal' , Amount = 10}, -- 金属废料
				{tMaterial = 'Base.SheetMetal' , Amount = 4}, -- 金属板
				{tMaterial = 'Base.Hinge' , Amount = 4},-- 门铰链
				{tMaterial = 'Base.Screws' , Amount = 8},-- 螺丝
				{tMaterial = 'Base.WeldingRods' , Amount = 4}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 10}, -- 喷灯
			},
		},
		--{
		--	-- 菜单名字
		--	tMenuName = 'ContextMenu_ShortFenceGate',
		--	-- 点击函数
		--	tFunc = RaccoonCityBuildMenu.onBuildDoubleDoor,
		--	-- 显示图像
		--	--tSprite = 'shisan_metalfence_8',
		--	tSprite = {'fixtures_doors_fences_01_'},
		--	-- 提示框文本
		--	tDescription = 'Tooltip_ShortFenceGate',
		--	-- 需要的工具
		--	tNeedTool = {'Hammer','WeldingMask'},
		--	-- 需要技能
		--	tNeedSkillNum = 24,
		--	-- 需要几级
		--	tNeedSkillLevel = 4,
		--	-- 技能经验名
		--	tSkillXpName = 'xp:MetalWelding',
		--	-- 技能经验
		--	tSkillXp = 5,
		--	tCorner = false,
		--	tPillar = false,
		--	tDoubleDoor = true,
		--	tSpriteIndex = 120,
		--	-- 杂志
		--	tMagazine = 'Make Short fence double door',
		--	-- 需要的材料列表
		--	tNeedMaterials = 
		--	{
		--		--{tMaterial = 'Base.Wire' , Amount = 10}, -- 铁丝
		--		{tMaterial = 'Base.MetalPipe' , Amount = 8}, -- 金属管
		--		{tMaterial = 'Base.ScrapMetal' , Amount = 10}, -- 金属废料
		--		--{tMaterial = 'Base.SheetMetal' , Amount = 4}, -- 金属板
		--		{tMaterial = 'Base.Hinge' , Amount = 4},-- 门铰链
		--		{tMaterial = 'Base.Screws' , Amount = 8},-- 螺丝
		--		{tMaterial = 'Base.WeldingRods' , Amount = 4}, -- 焊条
		--		{tMaterial = 'Base.BlowTorch' , Amount = 10}, -- 喷灯
		--	},
		--},
		-------------------------------
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_BarbedWireMesh',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence,
			-- 显示图像
			--tSprite = 'shisan_metalfence_0', 
			tSprite = {'shisan_wasteland_58','shisan_wasteland_59','shisan_wasteland_57','shisan_wasteland_56'},
			-- 提示框文本
			tDescription = 'Tooltip_BarbedWireMesh',
			-- 需要的工具
			tNeedTool = {'Hammer','WeldingMask'},
			-- 需要技能
			tNeedSkillNum = 24,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:MetalWelding',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			-- 杂志
			tMagazine = 'Make Barbed wire mesh',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.Wire' , Amount = 4}, -- 铁丝
				{tMaterial = 'Base.MetalPipe' , Amount = 2}, -- 金属管
				{tMaterial = 'Base.ScrapMetal' , Amount = 1}, -- 金属废料
				--{tMaterial = 'Base.Stone2' , Amount = 1}, -- 石块
				{tMaterial = 'Base.WeldingRods' , Amount = 2}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 5}, -- 喷灯
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_BarbedWireMeshCorner',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence,
			-- 显示图像
			--tSprite = 'shisan_metalfence_4',
			tSprite = {'shisan_wasteland_102'},
			-- 提示框文本
			tDescription = 'Tooltip_BarbedWireMesh',
			-- 需要的工具
			tNeedTool = {'Hammer','WeldingMask'},
			-- 需要技能
			tNeedSkillNum = 24,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:MetalWelding',
			-- 技能经验
			tSkillXp = 5,
			tCorner = true,
			tPillar = false,
			-- 杂志
			tMagazine = 'Make Barbed wire mesh',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.Wire' , Amount = 4}, -- 铁丝
				{tMaterial = 'Base.MetalPipe' , Amount = 2}, -- 金属管
				{tMaterial = 'Base.ScrapMetal' , Amount = 1}, -- 金属废料
				--{tMaterial = 'Base.Stone2' , Amount = 1}, -- 石块
				{tMaterial = 'Base.WeldingRods' , Amount = 2}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 5}, -- 喷灯
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_BarbedWireMeshColumn',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence,
			-- 显示图像
			--tSprite = 'shisan_metalfence_5',
			tSprite = {'shisan_wasteland_103'},
			-- 提示框文本
			tDescription = 'Tooltip_BarbedWireMesh',
			-- 需要的工具
			tNeedTool = {'Hammer','WeldingMask'},
			-- 需要技能
			tNeedSkillNum = 24,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:MetalWelding',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = true,
			-- 杂志
			tMagazine = 'Make Barbed wire mesh',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.Wire' , Amount = 2}, -- 铁丝
				{tMaterial = 'Base.MetalPipe' , Amount = 1}, -- 金属管
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 3}, -- 喷灯
			},
		},
	},
	-- 子菜单3
	{
		tSubMenu = 'ContextMenu_WasteSoilShedWall',
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_WasteSoilShedWall1',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildShedWall,
			-- 显示图像
			--tSprite = 'shisan_metalfence_0',
			tSprite = {'shisan_metalfence_33','shisan_metalfence_32'},
			-- 提示框文本
			tDescription = 'Tooltip_WasteSoilShedWall1',
			-- 需要的工具
			tNeedTool = {'Hammer','WeldingMask'},
			-- 需要技能
			tNeedSkillNum = 24,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:MetalWelding',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			-- 杂志
			tMagazine = '',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.SheetMetal' , Amount = 1}, -- 金属板
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 1}, -- 喷灯
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_WasteSoilShedWall2',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildShedWall,
			-- 显示图像
			--tSprite = 'shisan_metalfence_0',
			tSprite = {'shisan_metalfence_35','shisan_metalfence_34'},
			-- 提示框文本
			tDescription = 'Tooltip_WasteSoilShedWall1',
			-- 需要的工具
			tNeedTool = {'Hammer','WeldingMask'},
			-- 需要技能
			tNeedSkillNum = 24,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:MetalWelding',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			-- 杂志
			tMagazine = '',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.SheetMetal' , Amount = 1}, -- 金属板
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 1}, -- 喷灯
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_WasteSoilShedWall3',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildShedWall,
			-- 显示图像
			--tSprite = 'shisan_metalfence_0',
			tSprite = {'shisan_metalfence_37','shisan_metalfence_36'},
			-- 提示框文本
			tDescription = 'Tooltip_WasteSoilShedWall1',
			-- 需要的工具
			tNeedTool = {'Hammer','WeldingMask'},
			-- 需要技能
			tNeedSkillNum = 24,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:MetalWelding',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			-- 杂志
			tMagazine = '',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.SheetMetal' , Amount = 1}, -- 金属板
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 1}, -- 喷灯
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_WasteSoilShedWall4',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildShedWall,
			-- 显示图像
			--tSprite = 'shisan_metalfence_0',
			tSprite = {'shisan_metalfence_39','shisan_metalfence_38'},
			-- 提示框文本
			tDescription = 'Tooltip_WasteSoilShedWall1',
			-- 需要的工具
			tNeedTool = {'Hammer','WeldingMask'},
			-- 需要技能
			tNeedSkillNum = 24,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:MetalWelding',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			-- 杂志
			tMagazine = '',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.SheetMetal' , Amount = 1}, -- 金属板
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 1}, -- 喷灯
			},
		},
		{
			-- 菜单名字
			tMenuName = 'ContextMenu_WasteSoilShedWall5',
			-- 点击函数
			tFunc = RaccoonCityBuildMenu.onBuildShedWall,
			-- 显示图像
			--tSprite = 'shisan_metalfence_0',
			tSprite = {'shisan_metalfence_41','shisan_metalfence_40'},
			-- 提示框文本
			tDescription = 'Tooltip_WasteSoilShedWall1',
			-- 需要的工具
			tNeedTool = {'Hammer','WeldingMask'},
			-- 需要技能
			tNeedSkillNum = 24,
			-- 需要几级
			tNeedSkillLevel = 4,
			-- 技能经验名
			tSkillXpName = 'xp:MetalWelding',
			-- 技能经验
			tSkillXp = 5,
			tCorner = false,
			tPillar = false,
			-- 杂志
			tMagazine = '',
			-- 需要的材料列表
			tNeedMaterials = 
			{
				{tMaterial = 'Base.SheetMetal' , Amount = 1}, -- 金属板
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 1}, -- 喷灯
			},
		},
	},
}

-- 所有需要用到的材料（提前读取只读一次优化右键卡顿）
RaccoonCityBuildMenu.AllMaterialList = 
{
	['Base.Log'] = {0,0},
	--['Base.Rope'] = {0,0},
	['Base.RippedSheets'] = {0,0},
	['Base.Nails'] = {0,0},
	['Base.Hinge'] = {0,0},
	['Base.Screws'] = {0,0},
	['Base.Wire'] = {0,1},
	['Base.MetalPipe'] = {0,0},
	['Base.ScrapMetal'] = {0,0},
	--['Base.Stone2'] = {0,0},
	['Base.SheetMetal'] = {0,0},
	['Base.WeldingRods'] = {0,1},
	['Base.BlowTorch'] = {0,1},
	--['Base.Plank'] = {0,0},
	['Base.SugarcaneDry'] = {0,0},
}


--- 工具列表定义 抄的更多建筑
RaccoonCityBuildMenu.toolsList = {}
RaccoonCityBuildMenu.toolsList['Hammer'] = {'Base.Hammer', 'Base.HammerStone', 'Base.BallPeenHammer', 'Base.WoodenMallet', 'Base.ClubHammer',}
RaccoonCityBuildMenu.toolsList['Screwdriver'] = {'Base.Screwdriver',}
RaccoonCityBuildMenu.toolsList['HandShovel'] = {'farming.HandShovel',}
RaccoonCityBuildMenu.toolsList['Saw'] = {'Base.Saw',}
RaccoonCityBuildMenu.toolsList['Shovel'] = {'Base.Shovel', 'Base.Shovel2',}
RaccoonCityBuildMenu.toolsList['BlowTorch'] = {'Base.BlowTorch',}
RaccoonCityBuildMenu.toolsList['WeldingMask'] = {'Base.WeldingMask',}



local function predicateDrainableUsesInt(item, count)
    return item:getDrainableUsesInt() >= count
end

local function getBlowTorchWithMostUses(container)
    return container:getBestTypeEvalRecurse("Base.BlowTorch", comparatorDrainableUsesInt)
end

local function getFirstBlowTorchWithUses(container, uses)
    return container:getFirstTypeEvalArgRecurse("Base.BlowTorch", predicateDrainableUsesInt, uses)
end

RaccoonCityBuildMenu.addToolTip = function()
	local toolTip = ISToolTip:new();
	toolTip:initialise();
	toolTip:setVisible(false);
	return toolTip;
end

--- 检查物品是否损坏
--- @param item string: 需检查的物品名称
--- @return boolean: 如果物品未损坏返回true, 否则返回false
local function predicateNotBroken2(item)
	return not item:isBroken()
end

--- 获取玩家库存内的可用工具
--- @param inv ItemContainer: 玩家ItemContainer实例
--- @param tool string: 工具类型
--- @return InventoryItem: 获取的工具实例, 如空或已损坏返回nil
RaccoonCityBuildMenu.getAvailableTools = function(inv, tool)
	local tools = nil
	local toolList = RaccoonCityBuildMenu.toolsList[tool]
	for _, type in pairs (toolList) do
		tools = inv:getFirstTypeEval(type, predicateNotBroken2)
		if tools then
			return tools
		end
	end
end


--- 装备主要工具
--- @param object IsoObject: IsoObject实例
--- @param player number: IsoPlayer索引
--- @param tool string: 工具类型
RaccoonCityBuildMenu.equipToolPrimary = function(object, player, tool)
	local tools = nil
	local inv = getSpecificPlayer(player):getInventory()
	tools = RaccoonCityBuildMenu.getAvailableTools(inv, tool)
	if tools then
		ISInventoryPaneContextMenu.equipWeapon(tools, true, false, player)
		object.noNeedHammer = true
	end
end

--- 装备次要工具
--- @param object Isoobject: Isoobject实例
--- @param player number: IsoPlayer索引
--- @param tool string: 工具类型
--- @info 未使用
RaccoonCityBuildMenu.equipToolSecondary = function(object, player, tool)
	local tools = nil
	local inv = getSpecificPlayer(player):getInventory()
	tools = RaccoonCityBuildMenu.getAvailableTools(inv, tool)
	if tools then
		ISInventoryPaneContextMenu.equipWeapon(tools, false, false, player)
	end
end

-- 建造木墙回调
RaccoonCityBuildMenu.onBuildWoodWall = function(ignoreThisArgument, i,k,sprite , player)
	local _wall = ISWoodenWall:new(sprite.sprite1, sprite.sprite2, sprite.sprite3)
	--
	_wall.canBePlastered = false
	_wall.canBarricade = false
	if RaccoonCityBuildMenu.BuildList[i][k].tCorner then 
		_wall.modData['wallType'] = 'pillar'
	else 
		_wall.modData['wallType'] = 'wall'
	end 
	--_wall.modData['wallType'] = 'wall'
	_wall.player = player
	_wall.pillar = RaccoonCityBuildMenu.BuildList[i][k].tPillar
	_wall.isCorner = RaccoonCityBuildMenu.BuildList[i][k].tCorner
	
	for i, _MaterialList in pairs (RaccoonCityBuildMenu.BuildList[i][k].tNeedMaterials) do
		local str = ''
		if RaccoonCityBuildMenu.AllMaterialList[_MaterialList.tMaterial][2] ~= 0 then 
			str = 'use:'
		else 
			str = 'need:'
		end 
		str = str .. _MaterialList.tMaterial
		_wall.modData[str] = _MaterialList.Amount
	end 
	--_wall.modData['need:Base.Plank'] = 3
	--_wall.modData['need:Base.Nails'] = 3
	_wall.modData[RaccoonCityBuildMenu.BuildList[i][k].tSkillXpName] = RaccoonCityBuildMenu.BuildList[i][k].tSkillXp
	--_wall.modData['xp:Woodwork'] = 5
	--tNeedTool
	--RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[1]
	if RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[1] then 
		RaccoonCityBuildMenu.equipToolPrimary(_wall, player, RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[1])
	end 
	if RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[2] then 
		RaccoonCityBuildMenu.equipToolSecondary(_wall, player, RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[2])
	end 
	

	getCell():setDrag(_wall, player)
end 
-- 注册下函数
RaccoonCityBuildMenu.BuildList[1][1].tFunc = RaccoonCityBuildMenu.onBuildWoodWall
RaccoonCityBuildMenu.BuildList[1][2].tFunc = RaccoonCityBuildMenu.onBuildWoodWall
RaccoonCityBuildMenu.BuildList[1][3].tFunc = RaccoonCityBuildMenu.onBuildWoodWall
RaccoonCityBuildMenu.BuildList[1][4].tFunc = RaccoonCityBuildMenu.onBuildWoodWall

-- 高金属栅栏
RaccoonCityBuildMenu.onBuildHighMetalFence = function(ignoreThisArgument, i,k,sprite, player)
	local _metalFence = BuildlMetalFence:new(sprite.sprite1, sprite.sprite2, sprite.sprite3, sprite.sprite4)
	
	_metalFence.player = player
	_metalFence.blockAllTheSquare = false
	_metalFence.completionSound = 'BuildMetalStructureMedium'
	_metalFence.pillar = RaccoonCityBuildMenu.BuildList[i][k].tPillar
	_metalFence.isCorner = RaccoonCityBuildMenu.BuildList[i][k].tCorner

	for i, _MaterialList in pairs (RaccoonCityBuildMenu.BuildList[i][k].tNeedMaterials) do
		local str = ''
		if RaccoonCityBuildMenu.AllMaterialList[_MaterialList.tMaterial][2] ~= 0 then 
			str = 'use:'
		else 
			str = 'need:'
		end 
		str = str .. _MaterialList.tMaterial
		_metalFence.modData[str] = _MaterialList.Amount
	end 
	
	_metalFence.modData[RaccoonCityBuildMenu.BuildList[i][k].tSkillXpName] = RaccoonCityBuildMenu.BuildList[i][k].tSkillXp

	if RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[1] then 
		RaccoonCityBuildMenu.equipToolPrimary(_metalFence, player, RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[1])
	end 
	if RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[2] then 
		if RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[2] == 'WeldingMask' then 
			local playerInv = getSpecificPlayer(player)
		
			local mask = playerInv:getInventory():getFirstTypeRecurse("WeldingMask")
			if mask then
				ISInventoryPaneContextMenu.wearItem(mask, playerInv:getPlayerNum())
			end
		else 
			RaccoonCityBuildMenu.equipToolSecondary(_metalFence, player, RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[2])
		end 
	end 

	getCell():setDrag(_metalFence, player)
end
-- 注册下函数
RaccoonCityBuildMenu.BuildList[1][6].tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence
RaccoonCityBuildMenu.BuildList[1][7].tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence
RaccoonCityBuildMenu.BuildList[2][1].tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence
RaccoonCityBuildMenu.BuildList[2][2].tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence
RaccoonCityBuildMenu.BuildList[2][3].tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence

RaccoonCityBuildMenu.BuildList[2][5].tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence
RaccoonCityBuildMenu.BuildList[2][6].tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence
RaccoonCityBuildMenu.BuildList[2][7].tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence
--RaccoonCityBuildMenu.BuildList[2][8].tFunc = RaccoonCityBuildMenu.onBuildHighMetalFence


-- 棚瓦墙
RaccoonCityBuildMenu.onBuildShedWall = function(ignoreThisArgument, i,k,sprite, player)
	local _wall = ISWoodenWall:new(sprite.sprite1, sprite.sprite2, sprite.sprite3)
	--
	_wall.canBePlastered = false
	_wall.canBarricade = false
	_wall.modData['wallType'] = 'wall'
	_wall.player = player
	_wall.pillar = RaccoonCityBuildMenu.BuildList[i][k].tPillar
	_wall.isCorner = RaccoonCityBuildMenu.BuildList[i][k].tCorner
	
	for i, _MaterialList in pairs (RaccoonCityBuildMenu.BuildList[i][k].tNeedMaterials) do
		local str = ''
		if RaccoonCityBuildMenu.AllMaterialList[_MaterialList.tMaterial][2] ~= 0 then 
			str = 'use:'
		else 
			str = 'need:'
		end 
		str = str .. _MaterialList.tMaterial
		_wall.modData[str] = _MaterialList.Amount
	end 
	
	_wall.modData[RaccoonCityBuildMenu.BuildList[i][k].tSkillXpName] = RaccoonCityBuildMenu.BuildList[i][k].tSkillXp
	
	if RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[1] then 
		RaccoonCityBuildMenu.equipToolPrimary(_wall, player, RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[1])
	end 
	if RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[2] then 
		if RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[2] == 'WeldingMask' then 
			local playerInv = getSpecificPlayer(player)
		
			local mask = playerInv:getInventory():getFirstTypeRecurse("WeldingMask")
			if mask then
				ISInventoryPaneContextMenu.wearItem(mask, playerInv:getPlayerNum())
			end
		else 
			RaccoonCityBuildMenu.equipToolSecondary(_wall, player, RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[2])
		end 
	end 
	

	getCell():setDrag(_wall, player)
end
RaccoonCityBuildMenu.BuildList[3][1].tFunc = RaccoonCityBuildMenu.onBuildShedWall
RaccoonCityBuildMenu.BuildList[3][2].tFunc = RaccoonCityBuildMenu.onBuildShedWall
RaccoonCityBuildMenu.BuildList[3][3].tFunc = RaccoonCityBuildMenu.onBuildShedWall
RaccoonCityBuildMenu.BuildList[3][4].tFunc = RaccoonCityBuildMenu.onBuildShedWall
RaccoonCityBuildMenu.BuildList[3][5].tFunc = RaccoonCityBuildMenu.onBuildShedWall

-- 双门
RaccoonCityBuildMenu.onBuildDoubleDoor = function(ignoreThisArgument, i,k,sprite,spriteIndex, player)
    local _doubleDoor = ISDoubleDoor:new(sprite.sprite1, spriteIndex);
	--canBarricade = false,
	--ignoreNorth = true,
	_doubleDoor.completionSound = 'BuildMetalStructureLargeWiredFence'
	_doubleDoor.player = player
	
	for i, _MaterialList in pairs (RaccoonCityBuildMenu.BuildList[i][k].tNeedMaterials) do
		local str = ''
		if RaccoonCityBuildMenu.AllMaterialList[_MaterialList.tMaterial][2] ~= 0 then 
			str = 'use:'
		else 
			str = 'need:'
		end 
		str = str .. _MaterialList.tMaterial
		_doubleDoor.modData[str] = _MaterialList.Amount
	end 
	
	_doubleDoor.modData[RaccoonCityBuildMenu.BuildList[i][k].tSkillXpName] = RaccoonCityBuildMenu.BuildList[i][k].tSkillXp

	if RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[1] then 
		RaccoonCityBuildMenu.equipToolPrimary(_doubleDoor, player, RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[1])
	end 
	if RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[2] then 
		RaccoonCityBuildMenu.equipToolSecondary(_doubleDoor, player, RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[2])
	end 

	getCell():setDrag(_doubleDoor, player)
end
-- 注册下函数
RaccoonCityBuildMenu.BuildList[1][5].tFunc = RaccoonCityBuildMenu.onBuildDoubleDoor
RaccoonCityBuildMenu.BuildList[2][4].tFunc = RaccoonCityBuildMenu.onBuildDoubleDoor
--RaccoonCityBuildMenu.BuildList[2][5].tFunc = RaccoonCityBuildMenu.onBuildDoubleDoor

-- 地板
RaccoonCityBuildMenu.onBuildTwoSpriteFloor = function(ignoreThisArgument, i , k ,sprite, player)
	
	local _floor = ISWoodenFloor:new(sprite.sprite1, sprite.sprite2)
	--print(sprite.sprite1)
	--print(sprite.sprite2)
	--_floor.name = name
	
	_floor.player = player
	
	for i, _MaterialList in pairs (RaccoonCityBuildMenu.BuildList[i][k].tNeedMaterials) do
		local str = ''
		if RaccoonCityBuildMenu.AllMaterialList[_MaterialList.tMaterial][2] ~= 0 then 
			str = 'use:'
		else 
			str = 'need:'
		end 
		str = str .. _MaterialList.tMaterial
		_floor.modData[str] = _MaterialList.Amount
	end 

	_floor.modData[RaccoonCityBuildMenu.BuildList[i][k].tSkillXpName] = RaccoonCityBuildMenu.BuildList[i][k].tSkillXp
	
	if RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[1] then 
		RaccoonCityBuildMenu.equipToolPrimary(_floor, player, RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[1])
	end 
	if RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[2] then 
		RaccoonCityBuildMenu.equipToolSecondary(_floor, player, RaccoonCityBuildMenu.BuildList[i][k].tNeedTool[2])
	end 
	

	--_floor.modData['need:Base.Plank'] = 1
	--_floor.modData['need:Base.Nails'] = 1
	--_floor.modData['xp:Woodwork'] = 5

	getCell():setDrag(_floor, player)

end
--RaccoonCityBuildMenu.BuildList[1][5].tFunc = RaccoonCityBuildMenu.onBuildTwoSpriteFloor


-- 判断是否已读
RaccoonCityBuildMenu.IsReadMagazine = function(player , recipe)
	if recipe ~= nil then
		local recipes = getSpecificPlayer(player):getKnownRecipes();
		if recipe ~= "NONE" then
			if not recipes:contains(recipe) then
				return false
			else
				return true
			end
		else
			return true
		end
	end 
	return false
end 

-- 创建菜单
RaccoonCityBuildMenu.CreateBuildMenu = function(player, context, worldobjects)
	if SandboxVars.DisableResidentEvilRightClickMenu then 
		return 
	end 
	if SandboxVars.ResidentEvilBuildAddBuildingCraft and Building_Data then 
		return 
	end 
	local playerObj = getSpecificPlayer(player)
	if playerObj:getVehicle() then
		return 
	end 
	
	local menuBuildOption = context:addOption(getText('ContextMenu_ResidentEvilBuild'))
	local subMenu = ISContextMenu:getNew(context)
	context:addSubMenu(menuBuildOption, subMenu)
	
	-- 提前获取库存
	local haveItem = getSpecificPlayer(player):getInventory()
	local groundItem = ISBuildMenu.materialOnGround
	-- 优化右键卡顿所有材料只预读1次
	for Key, Value in pairs(RaccoonCityBuildMenu.AllMaterialList) do
		if Value[2] == 0 then 
			Value[1] = haveItem:getItemCountFromTypeRecurse(Key)
		else 
			Value[1] = haveItem:getUsesTypeRecurse(Key);
		end 
		local strType = RaccoonCityBuildMenu.split(Key, '\\.')[2]
		-- 遍历地面材料（好像是包含容器内）
		if Value[2] == 0 then 
			if groundItem then 
				--print('ground have item')
				for groundItemType, groundItemCount in pairs(groundItem) do
					if groundItemType == strType then
						Value[1] = Value[1] + groundItemCount
					end
				end
			end 
		else 
			-- 消耗品
			local groundItems = buildUtil.getMaterialOnGround(playerObj:getCurrentSquare());
			local groundItemCountMap = {};
			groundItemCountMap = buildUtil.getMaterialOnGroundUses(groundItems);
			if groundItemCountMap[Key] then
				Value[1] = Value[1] + groundItemCountMap[Key];
			end
		end 
		--print('num:',Value)
	end
	
	for i, _subMenuList in pairs (RaccoonCityBuildMenu.BuildList) do
		
		local menuWoodenFence = subMenu:addOption(getText(_subMenuList.tSubMenu))
		local subMenuWooden = ISContextMenu:getNew(subMenu)
		context:addSubMenu(menuWoodenFence, subMenuWooden)
		
		for k, __subMenuList in pairs (_subMenuList) do
			--if __subMenuList.tMenuName and (isStartSnake == true or __subMenuList.tMenuName ~= 'ContextMenu_BambooFloor')then 
			if __subMenuList.tMenuName then 
				local _sprite = {}
				if __subMenuList.tSprite[1] then 
					_sprite.sprite1 = __subMenuList.tSprite[1]
				end 
				if __subMenuList.tSprite[2] then 
					_sprite.sprite2 = __subMenuList.tSprite[2]
				end 
				if __subMenuList.tSprite[3] then 
					_sprite.sprite3 = __subMenuList.tSprite[3]
				end 
				if __subMenuList.tSprite[4] then 
					_sprite.sprite4 = __subMenuList.tSprite[4]
				end 
				
				-- 添加菜单
				local menuName1 = getText(__subMenuList.tMenuName)
				local menuOption1 = nil
				if __subMenuList.tDoubleDoor then 
					menuOption1 = subMenuWooden:addOption(menuName1, worldobjects, __subMenuList.tFunc, i, k,_sprite, __subMenuList.tSpriteIndex, player);
				else 
					menuOption1 = subMenuWooden:addOption(menuName1, worldobjects, __subMenuList.tFunc, i, k,_sprite, player);
				end 
				-- 添加显示页面
				local tooltip1 = RaccoonCityBuildMenu.addToolTip()
				-- 设置菜单显示页面
				menuOption1.toolTip = tooltip1;
				-- 设置显示页面名字
				tooltip1:setName(menuName1);
				
				-- 显示页面文本
				tooltip1.description = getText(__subMenuList.tDescription);
				local isCan = true
				-- 判断是否已读杂志
				if __subMenuList.tMagazine == '' or RaccoonCityBuildMenu.IsReadMagazine(player,__subMenuList.tMagazine) then 
					tooltip1.description = tooltip1.description .. getText("Tooltip_FenceNeedMaterial")
					-- 显示需要的材料
					-- 遍历之前先保存好工具临时表 妈的这个遍历会移动指针
					local tempToollist = __subMenuList.tNeedTool
					local nNeedSkillNum = __subMenuList.tNeedSkillNum -- 需要的技能序号
					local nNeedSkillLevel = __subMenuList.tNeedSkillLevel -- 需要几级
					
					for ___, ___MaterialList in pairs (__subMenuList.tNeedMaterials) do
	
						if RaccoonCityBuildMenu.AllMaterialList[___MaterialList.tMaterial] then 
							--print('aa:',RaccoonCityBuildMenu.AllMaterialList[___MaterialList.tMaterial][1])
							local strColour = ''
							if RaccoonCityBuildMenu.AllMaterialList[___MaterialList.tMaterial][1] < ___MaterialList.Amount then 
								strColour = '<RGB:1,0,0>'
								isCan = false
							else 
								strColour = '<RGB:0,1,0>'
							end 
							tooltip1.description = tooltip1.description.. strColour .. getItemNameFromFullType(___MaterialList.tMaterial)
							if RaccoonCityBuildMenu.AllMaterialList[___MaterialList.tMaterial][2] ~= 0 then 
							--if ___MaterialList.tConsumeType ~= 0 then 
								tooltip1.description = tooltip1.description .. getText("Tooltip_UseType")
							end 
							tooltip1.description = tooltip1.description .. ' ' .. RaccoonCityBuildMenu.AllMaterialList[___MaterialList.tMaterial][1]..'/'..___MaterialList.Amount..' <LINE>'
						end 
					end 
					-- 显示需要的工具
					for _k, _currentTool in pairs (tempToollist) do
						local tools = RaccoonCityBuildMenu.getAvailableTools(haveItem, _currentTool)
						local strColour = ''
						if tools then 
							strColour = '<RGB:0,1,0>'
						else 
							strColour = '<RGB:1,0,0>'
							isCan = false
						end 
						for _, type in pairs (RaccoonCityBuildMenu.toolsList[_currentTool]) do
							tooltip1.description = tooltip1.description.. strColour .. getItemNameFromFullType(type) .. ' <LINE>'
							break
						end
					end 
					-- 显示技能需求
					--local playerObj = getSpecificPlayer(player)
					if not playerObj:getVehicle() then
						--print('skillnum:',nNeedSkillNum)
						local perks = PerkFactory.PerkList
						local nLevel = playerObj:getPerkLevel(perks:get(nNeedSkillNum))
						local perkType = perks:get(nNeedSkillNum):getType()
						if nLevel < nNeedSkillLevel then 
							tooltip1.description = tooltip1.description.. '<RGB:1,0,0>' .. PerkFactory.getPerkName(perkType) .. ''..nLevel..'/'..nNeedSkillLevel..'' .. ' <LINE>'
							isCan = false
						else 
							tooltip1.description = tooltip1.description.. '<RGB:0,1,0>' .. PerkFactory.getPerkName(perkType) .. ' <LINE>'
						end 
					end 
					-- 已读显示
					if __subMenuList.tMagazine ~= '' then 
						tooltip1.description = tooltip1.description.. " <LINE> <RGB:1,1,1>" .. getText("Tooltip_NeedRecipe") .. " <RGB:0,1,0>" .. getText(RaccoonCityBuildMenu.RecipeList[__subMenuList.tMagazine]) .. getText("Tooltip_AlreadyReadMagazines")
					end 
				else 
					isCan = false
					-- 没读
					if __subMenuList.tMagazine ~= '' then 
						tooltip1.description = tooltip1.description.. " <LINE> <RGB:1,1,1>" .. getText("Tooltip_NeedRecipe") .. " <RGB:1,0,0>" .. getText(RaccoonCityBuildMenu.RecipeList[__subMenuList.tMagazine])
					end 
				end 

				
				-- 是否禁用
				if isCan == false then 
					menuOption1.onSelect = nil;
					menuOption1.notAvailable = true;
				end 
				-- 设置显示页面图像纹理
				if __subMenuList.tDoubleDoor then 
					tooltip1:setTexture(_sprite.sprite1 .. __subMenuList.tSpriteIndex)
				else 
					tooltip1:setTexture(_sprite.sprite1)
				end 
			end 
		end 
	end 
end 


Events.OnFillWorldObjectContextMenu.Add(RaccoonCityBuildMenu.CreateBuildMenu);



