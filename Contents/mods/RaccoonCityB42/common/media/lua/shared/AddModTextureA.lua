

IsRaccoonCityAddComplete = IsRaccoonCityAddComplete or false 


-- 木栅栏
local function ModTextureDataWoodFence()
	local ModDataLocal = 
	{

		-- 
		{
			Sprite = {'shisan_otherfurniture_0','shisan_otherfurniture_1'},
			Func = BuildingCraftObject.BuildPlainWall,
			Magazine = 'Make pointed wooden fences',
			NeedSkill = Perks.Woodwork,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:Woodwork',
			SkillXp = 1,
			Action = 'Build',
			ProcessSound = 'Hammering',
			EndSound  = 'BuildWoodenStructureLarge',
			NeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 2},
				{tMaterial = 'Base.RippedSheets' , Amount = 1},
				{tMaterial = 'Base.Nails' , Amount = 4},
			},
			FaceTool = '',
			NeedTools = 
			{
				{'Hammer','HammerForged','BallPeenHammer','BallPeenHammerForged'},
			}
		},
		{
			Sprite = {'shisan_otherfurniture_26','shisan_otherfurniture_27'},
			Func = BuildingCraftObject.BuildPlainWall,
			Magazine = 'Make pointed wooden fences',
			NeedSkill = Perks.Woodwork,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:Woodwork',
			SkillXp = 1,
			Action = 'Build',
			ProcessSound = 'Hammering',
			EndSound  = 'BuildWoodenStructureLarge',
			
			NeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 2},
				{tMaterial = 'Base.RippedSheets' , Amount = 1},
				{tMaterial = 'Base.Nails' , Amount = 4},
			},
			FaceTool = '',
			NeedTools = 
			{
				{'Hammer','HammerForged','BallPeenHammer','BallPeenHammerForged'},
			}
		},
		{
			Sprite = {'shisan_otherfurniture_2','shisan_otherfurniture_2'},
			Func = BuildingCraftObject.BuildPlainWall,
			Magazine = 'Make pointed wooden fences',
			NeedSkill = Perks.Woodwork,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:Woodwork',
			SkillXp = 1,
			Action = 'Build',
			ProcessSound = 'Hammering',
			EndSound  = 'BuildWoodenStructureLarge',
			
			NeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 4},
				{tMaterial = 'Base.RippedSheets' , Amount = 2},
				{tMaterial = 'Base.Nails' , Amount = 8},
			},
			FaceTool = '',
			NeedTools = 
			{
				{'Hammer','HammerForged','BallPeenHammer','BallPeenHammerForged'},
			}
		},
		{
			Sprite = {'shisan_otherfurniture_3','shisan_otherfurniture_3'},
			Func = BuildingCraftObject.BuildColumn,
			IsUnBlock = true,
			Magazine = 'Make pointed wooden fences',
			NeedSkill = Perks.Woodwork,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:Woodwork',
			SkillXp = 1,
			Action = 'Build',
			ProcessSound = 'Hammering',
			EndSound  = 'BuildWoodenStructureLarge',
			
			NeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 1},
			},
			FaceTool = '',
			NeedTools = 
			{
				{'Hammer','HammerForged','BallPeenHammer','BallPeenHammerForged'},
			}
		},
		{
			Sprite = {'shisan_furnace_41'},
			Func = BuildingCraftObject.BuildDoubleDoor,
			Magazine = 'Make pointed wooden fences',
			NeedSkill = Perks.Woodwork,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:Woodwork',
			SkillXp = 1,
			spriteIndex = 48,
			Action = 'Build',
			ProcessSound = 'Hammering',
			EndSound  = 'BuildWoodenStructureLarge',
			NeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 8},-- 原木
				{tMaterial = 'Base.RippedSheets' , Amount = 4},
				{tMaterial = 'Base.Nails' , Amount = 16},-- 钉子
				{tMaterial = 'Base.Hinge' , Amount = 4},-- 门铰链
				{tMaterial = 'Base.Screws' , Amount = 4},-- 螺丝
			},
			FaceTool = '',
			NeedTools = 
			{
				{'Hammer','HammerForged','BallPeenHammer','BallPeenHammerForged'},
			}
		},
		{
			Sprite = {'shisan_furnace_65'},
			Func = BuildingCraftObject.BuildDoubleDoor,
			Magazine = 'Make pointed wooden fences',
			NeedSkill = Perks.Woodwork,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:Woodwork',
			SkillXp = 1,
			spriteIndex = 72,
			Action = 'Build',
			ProcessSound = 'Hammering',
			EndSound  = 'BuildWoodenStructureLarge',
			NeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 8},-- 原木
				{tMaterial = 'Base.RippedSheets' , Amount = 4},
				{tMaterial = 'Base.Nails' , Amount = 16},-- 钉子
				{tMaterial = 'Base.Hinge' , Amount = 4},-- 门铰链
				{tMaterial = 'Base.Screws' , Amount = 4},-- 螺丝
			},
			FaceTool = '',
			NeedTools = 
			{
				{'Hammer','HammerForged','BallPeenHammer','BallPeenHammerForged'},
			}
		},
		{
			Sprite = {'shisan_otherfurniture_10','shisan_otherfurniture_11','shisan_otherfurniture_8','shisan_otherfurniture_9'},
			Func = BuildingCraftObject.BuildTwoTileFurniture,
			Magazine = 'Make pointed wooden fences',
			NeedSkill = Perks.Woodwork,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:Woodwork',
			SkillXp = 1,
			Action = 'Build',
			ProcessSound = 'Hammering',
			EndSound  = 'BuildWoodenStructureLarge',
			NeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 4},-- 原木
				{tMaterial = 'Base.RippedSheets' , Amount = 4},-- 碎布条
				{tMaterial = 'Base.Nails' , Amount = 8},-- 钉子
			},
			FaceTool = '',
			NeedTools = 
			{
				{'Hammer','HammerForged','BallPeenHammer','BallPeenHammerForged'},
			}
		},
		{
			Sprite = {'shisan_otherfurniture_14','shisan_otherfurniture_15','shisan_otherfurniture_12','shisan_otherfurniture_13'},
			Func = BuildingCraftObject.BuildTwoTileFurniture,
			Magazine = 'Make pointed wooden fences',
			NeedSkill = Perks.Woodwork,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:Woodwork',
			SkillXp = 1,
			Action = 'Build',
			ProcessSound = 'Hammering',
			EndSound  = 'BuildWoodenStructureLarge',
			NeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 4},-- 原木
				{tMaterial = 'Base.RippedSheets' , Amount = 4},-- 碎布条
				{tMaterial = 'Base.Nails' , Amount = 8},-- 钉子
			},
			FaceTool = '',
			NeedTools = 
			{
				{'Hammer','HammerForged','BallPeenHammer','BallPeenHammerForged'},
			}
		},
		{
			Sprite = {'shisan_furnace_80','shisan_furnace_81','shisan_furnace_82','shisan_furnace_83'},
			Func = BuildingCraftObject.BuildOneTileFurniture,
			Magazine = 'Make Fence Support',
			NeedSkill = Perks.Woodwork,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:Woodwork',
			SkillXp = 1,
			Action = 'Build',
			ProcessSound = 'Hammering',
			EndSound  = 'BuildWoodenStructureLarge',
			NeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 2},-- 原木
				{tMaterial = 'Base.RippedSheets' , Amount = 2},-- 碎布条
				{tMaterial = 'Base.TirePiece' , Amount = 3},-- 轮胎碎片
				{tMaterial = 'Base.Nails' , Amount = 4},-- 钉子
			},
			FaceTool = '',
			NeedTools = 
			{
				{'Hammer','HammerForged','BallPeenHammer','BallPeenHammerForged'},
			}
		},
		{
			Sprite = {'shisan_furnace_84','shisan_furnace_85','shisan_furnace_86','shisan_furnace_87'},
			Func = BuildingCraftObject.BuildOneTileFurniture,
			Magazine = 'Make Fence Support',
			NeedSkill = Perks.Woodwork,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:Woodwork',
			SkillXp = 1,
			Action = 'Build',
			ProcessSound = 'Hammering',
			EndSound  = 'BuildWoodenStructureLarge',
			NeedMaterials = 
			{
				{tMaterial = 'Base.Log' , Amount = 2},-- 原木
				{tMaterial = 'Base.RippedSheets' , Amount = 2},-- 碎布条
				{tMaterial = 'Base.TirePiece' , Amount = 3},-- 轮胎碎片
				{tMaterial = 'Base.Nails' , Amount = 4},-- 钉子
			},
			FaceTool = '',
			NeedTools = 
			{
				{'Hammer','HammerForged','BallPeenHammer','BallPeenHammerForged'},
			}
		},
	}
	return ModDataLocal
end 

-- 金属栅栏
local function ModTextureDataMetalFence()
	local ModDataLocal = 
	{

		-- 
		{
			Sprite = {'shisan_metalfence_2','shisan_metalfence_3','shisan_metalfence_0','shisan_metalfence_1'},
			Func = BuildingCraftObject.BuildHightMetalFence,
			Magazine = 'Make Restricted area fences',
			NeedSkill = Perks.MetalWelding,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:MetalWelding',
			SkillXp = 1,
			Action = 'BlowTorch',
			ProcessSound = 'BlowTorch',
			EndSound  = 'BuildMetalStructureMedium',
			NeedMaterials = 
			{
				{tMaterial = 'Base.Wire' , Amount = 4}, -- 铁丝
				{tMaterial = 'Base.MetalPipe' , Amount = 2}, -- 金属管
				{tMaterial = 'Base.ScrapMetal' , Amount = 1}, -- 金属废料
				{tMaterial = 'Base.WeldingRods' , Amount = 2}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 5}, -- 喷灯
			},
			FaceTool = 'WeldingMask',
			NeedTools = 
			{
				{'BlowTorch'},
			}
		},
		{
			Sprite = {'shisan_metalfence_4','shisan_metalfence_4'},
			Func = BuildingCraftObject.BuildPlainWall,
			Magazine = 'Make Restricted area fences',
			NeedSkill = Perks.MetalWelding,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:MetalWelding',
			SkillXp = 1,
			Action = 'BlowTorch',
			ProcessSound = 'BlowTorch',
			EndSound  = 'BuildMetalStructureMedium',
			NeedMaterials = 
			{
				{tMaterial = 'Base.Wire' , Amount = 4}, -- 铁丝
				{tMaterial = 'Base.MetalPipe' , Amount = 2}, -- 金属管
				{tMaterial = 'Base.ScrapMetal' , Amount = 1}, -- 金属废料
				{tMaterial = 'Base.WeldingRods' , Amount = 2}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 5}, -- 喷灯
			},
			FaceTool = 'WeldingMask',
			NeedTools = 
			{
				{'BlowTorch'},
			}
		},
		{
			Sprite = {'shisan_metalfence_5','shisan_metalfence_5'},
			Func = BuildingCraftObject.BuildColumn,
			IsUnBlock = true,
			Magazine = 'Make Restricted area fences',
			NeedSkill = Perks.MetalWelding,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:MetalWelding',
			SkillXp = 1,
			Action = 'BlowTorch',
			ProcessSound = 'BlowTorch',
			EndSound  = 'BuildMetalStructureMedium',
			NeedMaterials = 
			{
				{tMaterial = 'Base.MetalPipe' , Amount = 1}, -- 金属管
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 3}, -- 喷灯
			},
			FaceTool = 'WeldingMask',
			NeedTools = 
			{
				{'BlowTorch'},
			}
		},
		-- 
		{
			Sprite = {'shisan_wasteland_58','shisan_wasteland_59','shisan_wasteland_56','shisan_wasteland_57'},
			Func = BuildingCraftObject.BuildHightMetalFence,
			Magazine = 'Make Barbed wire mesh',
			NeedSkill = Perks.MetalWelding,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:MetalWelding',
			SkillXp = 1,
			Action = 'BlowTorch',
			ProcessSound = 'BlowTorch',
			EndSound  = 'BuildMetalStructureMedium',
			NeedMaterials = 
			{
				{tMaterial = 'Base.Wire' , Amount = 4}, -- 铁丝
				{tMaterial = 'Base.MetalPipe' , Amount = 2}, -- 金属管
				{tMaterial = 'Base.ScrapMetal' , Amount = 1}, -- 金属废料
				{tMaterial = 'Base.WeldingRods' , Amount = 2}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 5}, -- 喷灯
			},
			FaceTool = 'WeldingMask',
			NeedTools = 
			{
				{'BlowTorch'},
			}
		},
		{
			Sprite = {'shisan_wasteland_102','shisan_wasteland_102'},
			Func = BuildingCraftObject.BuildPlainWall,
			Magazine = 'Make Barbed wire mesh',
			NeedSkill = Perks.MetalWelding,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:MetalWelding',
			SkillXp = 1,
			Action = 'BlowTorch',
			ProcessSound = 'BlowTorch',
			EndSound  = 'BuildMetalStructureMedium',
			NeedMaterials = 
			{
				{tMaterial = 'Base.Wire' , Amount = 4}, -- 铁丝
				{tMaterial = 'Base.MetalPipe' , Amount = 2}, -- 金属管
				{tMaterial = 'Base.ScrapMetal' , Amount = 1}, -- 金属废料
				{tMaterial = 'Base.WeldingRods' , Amount = 2}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 5}, -- 喷灯
			},
			FaceTool = 'WeldingMask',
			NeedTools = 
			{
				{'BlowTorch'},
			}
		},
		{
			Sprite = {'shisan_wasteland_103','shisan_wasteland_103'},
			Func = BuildingCraftObject.BuildColumn,
			IsUnBlock = true,
			Magazine = 'Make Barbed wire mesh',
			NeedSkill = Perks.MetalWelding,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:MetalWelding',
			SkillXp = 1,
			Action = 'BlowTorch',
			ProcessSound = 'BlowTorch',
			EndSound  = 'BuildMetalStructureMedium',
			NeedMaterials = 
			{
				{tMaterial = 'Base.Wire' , Amount = 2}, -- 铁丝
				{tMaterial = 'Base.MetalPipe' , Amount = 1}, -- 金属管
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 3}, -- 喷灯
			},
			FaceTool = 'WeldingMask',
			NeedTools = 
			{
				{'BlowTorch'},
			}
		},
		--
		{
			Sprite = {'shisan_metalfence_9'},
			Func = BuildingCraftObject.BuildDoubleDoor,
			Magazine = 'Make Restricted area door',
			NeedSkill = Perks.MetalWelding,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:MetalWelding',
			SkillXp = 1,
			spriteIndex = 16,
			Action = 'BlowTorch',
			ProcessSound = 'BlowTorch',
			EndSound  = 'BuildMetalStructureMedium',
			NeedMaterials = 
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
			FaceTool = 'WeldingMask',
			NeedTools = 
			{
				{'BlowTorch'},
			}
		},
		--
		--{
		--	Sprite = {'fixtures_doors_fences_01_113'},
		--	Func = BuildingCraftObject.BuildDoubleDoor,
		--	Magazine = 'Make Restricted area door',
		--	NeedSkill = Perks.MetalWelding,
		--	NeedSkillLevel = 4,
		--	SkillXpName = 'xp:MetalWelding',
		--	SkillXp = 1,
		--	spriteIndex = 120,
		--	Action = 'BlowTorch',
		--	ProcessSound = 'BlowTorch',
		--	EndSound  = 'BuildMetalStructureMedium',
		--	NeedMaterials = 
		--	{
		--		{tMaterial = 'Base.MetalPipe' , Amount = 8}, -- 金属管
		--		{tMaterial = 'Base.ScrapMetal' , Amount = 10}, -- 金属废料
		--		{tMaterial = 'Base.Hinge' , Amount = 4},-- 门铰链
		--		{tMaterial = 'Base.Screws' , Amount = 8},-- 螺丝
		--		{tMaterial = 'Base.WeldingRods' , Amount = 4}, -- 焊条
		--		{tMaterial = 'Base.BlowTorch' , Amount = 10}, -- 喷灯
		--	},
		--	FaceTool = 'WeldingMask',
		--	NeedTools = 
		--	{
		--		{'BlowTorch'},
		--	}
		--},
	}
	return ModDataLocal
end 

-- 废土棚瓦墙
local function ModTextureDataWasteSoil()
	local ModDataLocal = 
	{

		-- 
		{
			Sprite = {'shisan_metalfence_33','shisan_metalfence_32'},
			Func = BuildingCraftObject.BuildPlainWall,
			NeedSkill = Perks.MetalWelding,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:MetalWelding',
			SkillXp = 1,
			Action = 'BlowTorch',
			ProcessSound = 'BlowTorch',
			EndSound  = 'BuildMetalStructureMedium',
			NeedMaterials = 
			{
				{tMaterial = 'Base.SheetMetal' , Amount = 1}, -- 金属板
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 1}, -- 喷灯
			},
			FaceTool = 'WeldingMask',
			NeedTools = 
			{
				{'BlowTorch'},
			}
		},
		{
			Sprite = {'shisan_metalfence_35','shisan_metalfence_34'},
			Func = BuildingCraftObject.BuildPlainWall,
			NeedSkill = Perks.MetalWelding,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:MetalWelding',
			SkillXp = 1,
			Action = 'BlowTorch',
			ProcessSound = 'BlowTorch',
			EndSound  = 'BuildMetalStructureMedium',
			NeedMaterials = 
			{
				{tMaterial = 'Base.SheetMetal' , Amount = 1}, -- 金属板
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 1}, -- 喷灯
			},
			FaceTool = 'WeldingMask',
			NeedTools = 
			{
				{'BlowTorch'},
			}
		},
		{
			Sprite = {'shisan_metalfence_37','shisan_metalfence_36'},
			Func = BuildingCraftObject.BuildPlainWall,
			NeedSkill = Perks.MetalWelding,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:MetalWelding',
			SkillXp = 1,
			Action = 'BlowTorch',
			ProcessSound = 'BlowTorch',
			EndSound  = 'BuildMetalStructureMedium',
			NeedMaterials = 
			{
				{tMaterial = 'Base.SheetMetal' , Amount = 1}, -- 金属板
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 1}, -- 喷灯
			},
			FaceTool = 'WeldingMask',
			NeedTools = 
			{
				{'BlowTorch'},
			}
		},
		{
			Sprite = {'shisan_metalfence_39','shisan_metalfence_38'},
			Func = BuildingCraftObject.BuildPlainWall,
			NeedSkill = Perks.MetalWelding,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:MetalWelding',
			SkillXp = 1,
			Action = 'BlowTorch',
			ProcessSound = 'BlowTorch',
			EndSound  = 'BuildMetalStructureMedium',
			NeedMaterials = 
			{
				{tMaterial = 'Base.SheetMetal' , Amount = 1}, -- 金属板
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 1}, -- 喷灯
			},
			FaceTool = 'WeldingMask',
			NeedTools = 
			{
				{'BlowTorch'},
			}
		},
		{
			Sprite = {'shisan_metalfence_41','shisan_metalfence_40'},
			Func = BuildingCraftObject.BuildPlainWall,
			NeedSkill = Perks.MetalWelding,
			NeedSkillLevel = 4,
			SkillXpName = 'xp:MetalWelding',
			SkillXp = 1,
			Action = 'BlowTorch',
			ProcessSound = 'BlowTorch',
			EndSound  = 'BuildMetalStructureMedium',
			NeedMaterials = 
			{
				{tMaterial = 'Base.SheetMetal' , Amount = 1}, -- 金属板
				{tMaterial = 'Base.WeldingRods' , Amount = 1}, -- 焊条
				{tMaterial = 'Base.BlowTorch' , Amount = 1}, -- 喷灯
			},
			FaceTool = 'WeldingMask',
			NeedTools = 
			{
				{'BlowTorch'},
			}
		},
	}
	return ModDataLocal
end 

-- 设置容器属性
local function setContainerInfoLocal()
	if IsRaccoonCityAddComplete then return end 
	if Building_Data.ContainerIcon then 
		--['barbecue'] = {'media/ui/Container_Oven.png', 'Tooltip_TypeBarbecue'},
	end 
end 

-- 设置材料类型
local function setMaterialIsUseLocal()
	if IsRaccoonCityAddComplete then return end 
	if Building_Data.MaterialIsUse then 
		--['Base.TreeBranch2'] = false,              -- 树枝（true表示是消耗耐久的道具）
	end 
end


-- 添加数据
local function addModTextureLocal()
	if IsRaccoonCityAddComplete then return end 
	if not Building_Data then 
		return 
	end 

	local tabindex = BuildingCraft_AddTabData(getText("IGUI_Building_RaccoonCity"))
	local ListRow1 = BuildingCraft_AddListData(getText("ContextMenu_RoundWoodenFence"), 'shisan_otherfurniture_26', tabindex)
	BuildingCraft_AddItemDataForIndex(ModTextureDataWoodFence(), tabindex, ListRow1)
	
	local ListRow2 = BuildingCraft_AddListData(getText("ContextMenu_RestrictedAreaFence"), 'shisan_metalfence_4', tabindex)
	BuildingCraft_AddItemDataForIndex(ModTextureDataMetalFence(), tabindex, ListRow2)

	local ListRow3 = BuildingCraft_AddListData(getText("ContextMenu_WasteSoilShedWall"), 'shisan_metalfence_35', tabindex)
	BuildingCraft_AddItemDataForIndex(ModTextureDataWasteSoil(), tabindex, ListRow3)
end


local function OnGameStart()
	-- 需要时调用
	--setContainerInfoLocal()
	--setMaterialIsUseLocal()
	if SandboxVars.ResidentEvilBuildAddBuildingCraft then 
		-- 添加MOD材质数据
		addModTextureLocal()
		IsRaccoonCityAddComplete = true
	end 

end

-- 启动游戏时加载确保主MOD已加载
Events.OnGameStart.Add(OnGameStart)
Events.OnServerStarted.Add(OnGameStart)
