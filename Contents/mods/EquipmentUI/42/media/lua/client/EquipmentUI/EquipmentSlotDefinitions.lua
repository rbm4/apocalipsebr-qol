-- Might need to divide the screen into clothes and armor if we are gonna have this many slots
local unpositioned = {
    "Calf_Left",
    "Calf_Left_Texture",
    "Calf_Right",
    "Calf_Right_Texture",
    "Cuirass",
    "Elbow_Left",
    "Elbow_Right",
    "ForeArm_Left",
    "ForeArm_Right",
    "Gorget",
    "Knee_Left",
    "Knee_Right",
    "LeftArm",
    "RightArm",
    "ShoulderHolster",
    "ShoulderpadLeft",
    "ShoulderpadRight",
    "SportShoulderpad",
    "SportShoulderpadOnTop",
    "Thigh_Left",
    "Thigh_Right",
}

-- Order is important here, the first slot appears on top of the others in the ui
-- It looks nicer to have the outermost layer of clothing on top
return {
    {
        name = "UI_equipment_head",
        position = { x = 44, y = 4 },
        bodyLocations = { "SCBA", "SCBAnotank", "FullTop", "FullHat", "Hat", "FullHelmet", "Head", "powerhorns", "Wig", "Scarf", "Neck"}
    },
    {
        name = "UI_equipment_face",
        position = { x = 100, y = 16 },
        bodyLocations = { "SpecialMask", "MaskFull", "MaskEyes", "Mask", "Pupils", "Eyes", "RightEye", "LeftEye"}
    },
    {
        name = "UI_equipment_torso",
        position = { x = 44, y = 58 },
        bodyLocations = { "FullSuit", "FullSuitHead", "JacketSuit", "Jacket_Down", "JacketHat_Bulky", "Jacket_Bulky", "JacketHat", "Jacket", "BathRobe", "Boilersuit", "Torso1Legs1", "SweaterHat", "Sweater", "Jersey", "LongDress", "Dress", "Shirt", "ShortSleeveShirt", "Tshirt", "TankTop", "UnderwearTop"}
    },
    {
        name = "UI_equipment_vest",
        position = { x = 106, y = 72 },
        bodyLocations = { "SMUIJumpsuitPlus", "SMUITorsoRigPlus", "SMUIWebbingPlus", "Webbing", "TorsoRigPlus2", "TorsoRig", "TorsoRig2", "TorsoExtraVestBullet", "TorsoExtraVest", "VestTexture", "TorsoExtraPlus1", "RifleSling", "AmmoStrap", "TorsoExtra"}
    },
    {
        name = "UI_equipment_back",
        position = { x = -14, y = 16 },
        bodyLocations = {"Back", "LowerBack"},
    },
    {
        name = "UI_equipment_waist",
        position = { x = 44, y = 128 },
        bodyLocations = { "waistbagsComplete", "waistbags", "waistbagsf", "FannyPackBack", "FannyPackFront", "SpecialBelt", "BeltExtraHL", "BeltExtra", "Belt420", "Belt419", "Belt", "Tail"}
    },
    {
        name = "UI_equipment_left_hand",
        position = { x = 100, y = 206 },
        bodyLocations = { "HandsLeft", "Hands", "SMUIGlovesPlus", "LeftWrist", "Left_RingFinger", "Left_MiddleFinger" }
    },
    {
        name = "UI_equipment_right_hand",
        position = { x = -14, y = 206 },
        bodyLocations = { "HandsRight", "Hands", "SMUIGlovesPlus", "RightWrist", "Right_RingFinger", "Right_MiddleFinger" }
    },
    {
        name = "UI_equipment_jewelry",
        position = { x = -20, y = 72 },
        bodyLocations = { "Necklace", "Necklace_Long", "BellyButton", "Nose", "Ears", "EarTop" }
    },
    {
        name = "UI_equipment_legs",
        position = { x = 44, y = 202 },
        bodyLocations = { "Kneepads", "ShinPlateRight", "ShinPlateLeft", "ThighRight" ,"ThighLeft", "PantsExtra", "Pants", "LongSkirt", "Skirt", "ShortPants", "ShortsShort", "Legs1", "LowerBody", "Codpiece", "UnderwearExtra2", "UnderwearExtra1", "UnderwearBottom", "Underwear"}
    },
    {
        name = "UI_equipment_feet",
        position = { x = 44, y = 272 },
        bodyLocations = { "AnkleHolster", "Shoes", "SMUIBootsPlus", "Socks"}
    }
}
