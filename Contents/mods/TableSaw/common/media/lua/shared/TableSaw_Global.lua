
ContainerButtonIcons = ContainerButtonIcons or {}

ContainerButtonIcons.tablesaw = getTexture("media/textures/TableSaw.png")


IsTableSawComplete = IsTableSawComplete or false 






TableSawSpriteList = 
{
	['TableSaw_0'] = {0,1,0,-1,0,1,0,0,IsoFlagType.collideN},
	['TableSaw_1'] = {1,0,-1,0,1,0,0,0,IsoFlagType.collideW},
	['TableSaw_2'] = {0,-1,0,1,0,0,0,1,IsoFlagType.collideN},
	['TableSaw_3'] = {-1,0,1,0,0,0,1,0,IsoFlagType.collideW},
}

RepairTableSawNeed = 
{
	{'Base.SmallSheetMetal',2},
	{'Base.SheetMetal',1},
	{'Base.MetalPipe',1},
}

CanSawLogList = 
{
	['Log'] = 'Base.Plank',
	['LargeBranch'] = 'Base.Plank',
	['Sapling'] = 'Base.TreeBranch2',
}

TableSawRepairPer = 0.3 -- 台锯修复率
SawBladeMaxDurable = SandboxVars.TableSawSawBladeDurable -- 锯片最大耐久
TableSawMaxDurable = SandboxVars.TableSawDurable -- 台锯最大耐久


---------------------- 减重 ----------------------
local function SetLogTypeweight()
	if SandboxVars.TableSawIsEnableWeightReduction then 
		local item1 = ScriptManager.instance:FindItem("Base.Log")
		if item1 then 
			item1:setActualWeight(item1:getActualWeight() * (SandboxVars.TableSawLogPro / 100))
		end 
		local item2 = ScriptManager.instance:FindItem("Base.LargeBranch")
		if item2 then 
			item2:setActualWeight(item2:getActualWeight() * (SandboxVars.TableSawLargeBranchPro / 100))
		end 
		local item3 = ScriptManager.instance:FindItem("Base.Sapling")
		if item3 then 
			item3:setActualWeight(item3:getActualWeight() * (SandboxVars.TableSawSaplingPro / 100))
		end 
		local item4 = ScriptManager.instance:FindItem("Base.Plank")
		if item4 then 
			item4:setActualWeight(item4:getActualWeight() * (SandboxVars.TableSawPlankPro / 100))
		end 
		local item5 = ScriptManager.instance:FindItem("Base.TreeBranch2")
		if item5 then 
			item5:setActualWeight(item5:getActualWeight() * (SandboxVars.TableSawTreeBranch2Pro / 100))
		end 
		local item6 = ScriptManager.instance:FindItem("Base.Splinters")
		if item6 then 
			item6:setActualWeight(item6:getActualWeight() * (SandboxVars.TableSawSplintersPro / 100))
		end 
		local item7 = ScriptManager.instance:FindItem("Base.Twigs")
		if item7 then 
			item7:setActualWeight(item7:getActualWeight() * (SandboxVars.TableSawTwigsPro / 100))
		end 
	end 
end 
Events.OnInitGlobalModData.Add(SetLogTypeweight)


--------------------------------------------------

-- 获取玩家身上物品数量
function TableSawgetItemCount(player, materialType)
    local inventory = player:getInventory()
    -- 身上
    local totalCount = inventory:getCountTypeEvalRecurse(materialType, buildUtil.predicateMaterial)
    return totalCount
end

local function TableSawBuildAll(_obj, i, k, num, player)
	_obj.isBetterBuilding = true
	_obj.player = player
	
	-- 全部无敌
	if SandboxVars.IsAllTileInvincible then 
		_obj.isThumpable = false;
	end 
	local ObjectList = Building_Data.BuildingList[i].subBuildData[k].ItemDate[num]

	local isfind = false
	
	for i = 1,#ObjectList.NeedTools do 
		for k = 1,#ObjectList.NeedTools[i] do 
			local totalCount = getTotalItemCount(getSpecificPlayer(player), 'Base.'..ObjectList.NeedTools[i][k])
			if totalCount > 0 then 
				_obj.firstItem = ObjectList.NeedTools[i][k]
				isfind = true
				break
			end 
		end 
		if isfind then break end 
	end 
	local isHaveHammer = false
	for i = 1,#ObjectList.NeedTools do 
		for k = 1,#ObjectList.NeedTools[i] do 
			if ObjectList.NeedTools[i][k] == 'Hammer' then 
				isHaveHammer = true
				break
			end 
		end 
	end 
	if isHaveHammer then 
		_obj.noNeedHammer = false
	else 
		_obj.noNeedHammer = true
	end 
	-- 脸部工具修改-----------------------------
	--if ObjectList.FaceTool and ObjectList.FaceTool ~= '' then 
	--	_obj.secondItem = ObjectList.FaceTool
	--end 
	for k = 1,#ObjectList.FaceTool do 
		local totalCount = getTotalItemCount(getSpecificPlayer(player), 'Base.'..ObjectList.FaceTool[k])
		if totalCount > 0 then 
			_obj.secondItem = ObjectList.FaceTool[k]
			break
		end 
	end 
	-- -----------------------------------------
	
	local MaterialList = ObjectList.NeedMaterials
	
	for i, _MaterialData in pairs (MaterialList) do
		local str = ''
		if Building_Data.MaterialIsUse[_MaterialData.tMaterial] then 
			str = 'use:'
		else 
			str = 'need:'
		end 
		str = str .. _MaterialData.tMaterial
		_obj.modData[str] = _MaterialData.Amount
	end 

	local SkillXpName = ObjectList.SkillXpName
	if SkillXpName ~= '' then 
		_obj.modData[SkillXpName] = ObjectList.SkillXp
	end 
	_obj.actionAnim = ObjectList.Action
	_obj.processSound = ObjectList.ProcessSound
	_obj.completionSound = ObjectList.EndSound

	getCell():setDrag(_obj, player)
end 

-- 台锯
function BuildTableSaw(i, k, num, sprite, player)
	local _tablesaw = ISBuildTableSaw:new(sprite.sprite1, sprite.sprite2, sprite.sprite3, sprite.sprite4, i, k, num)
	local ObjectList = Building_Data.BuildingList[i].subBuildData[k].ItemDate[num]
	if ObjectList.ContainerType and ObjectList.ContainerType ~= '' then 
		_tablesaw.containerType = ObjectList.ContainerType
	end 
	TableSawBuildAll(_tablesaw, i, k, num, player)
end 


local function ModTextureData1()
	local ModDataLocal = 
	{
		-- 
		[16] = 
		{
			{
				Sprite = {'TableSaw_0','TableSaw_1','TableSaw_2','TableSaw_3'},
				Func = BuildTableSaw,
				Magazine = 'Make TableSaw',
				NeedSkill = Perks.MetalWelding,
				NeedSkillLevel = 5,
				SkillXpName = 'xp:MetalWelding',
				SkillXp = 1,
				ContainerType = 'tablesaw',
				DirCount = 1,
				Action = 'BlowTorch',
				ProcessSound = 'BlowTorch',
				EndSound  = 'BuildMetalStructureMedium',
				NeedMaterials = 
				{
					{tMaterial = 'Base.CircularSawblade' , Amount = 1},
					{tMaterial = 'Base.AgedMotor' , Amount = 1},
					{tMaterial = 'Base.SheetMetal' , Amount = 8},
					{tMaterial = 'Base.Screws' , Amount = 8},
					{tMaterial = 'Base.MetalPipe' , Amount = 6},
					{tMaterial = 'Base.ElectricWire' , Amount = 4},
					{tMaterial = 'Base.WeldingRods' , Amount = 4},
					{tMaterial = 'Base.BlowTorch' , Amount = 4},
				},
				--FaceTool = 'WeldingMask',
				FaceTool = {'WeldingMask','Glasses_OldWeldingGoggles'},
				NeedTools = 
				{
					{'BlowTorch'},
				}
			},
		},
	}
	return ModDataLocal
end 


-- 设置容器属性
local function setContainerInfoLocal()
	if IsTableSawComplete then return end 
	if Building_Data.ContainerIcon then 
		Building_Data.ContainerIcon['tablesaw'] = {'media/textures/TableSaw.png', 'Tooltip_TypeTableSaw'}
	end 
end 

-- 设置材料类型
local function setMaterialIsUseLocal()
	if IsTableSawComplete then return end 
	if Building_Data.MaterialIsUse then 
		Building_Data.MaterialIsUse['Base.CircularSawblade'] = false
		Building_Data.MaterialIsUse['Base.AgedMotor'] = false
	end 
end

local function OnGameStart()
	if IsTableSawComplete then return end 
	if Building_Data then 
		Building_Data.RecipeList['Make TableSaw'] = 'Tooltip_Des_Make_TableSaw'
		
		setContainerInfoLocal()
		setMaterialIsUseLocal()
		
		BuildingCraft_AddItemData(ModTextureData1(), 11)
	end 
	

	
	IsTableSawComplete = true 
end

-- 
Events.OnGameStart.Add(OnGameStart)
Events.OnServerStarted.Add(OnGameStart)