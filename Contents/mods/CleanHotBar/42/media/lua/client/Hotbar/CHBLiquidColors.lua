CHBLiquidColors = {}

CHBLiquidColors.Colors = {
    ["Water"] = {0.4, 0.7, 1.0, 0.6},                -- 清亮淡蓝
    ["TaintedWater"] = {0.6, 0.5, 0.3, 0.6},         -- 淡褐
    ["CarbonatedWater"] = {0.7, 0.9, 1.0, 0.6},      -- 清浅蓝

    -- Milk
    ["CowMilk"] = {1.0, 1.0, 1.0, 0.6},              -- 纯白
    ["MilkChocolate"] = {0.75, 0.55, 0.35, 0.7},     -- 柔棕
    ["SpiffoMilk"] = {1.0, 1.0, 0.7, 0.6},           -- 奶黄

    -- Alcoholic
    ["Alcohol"] = {0.9, 0.9, 0.95, 0.6},             -- 微蓝白
    ["Beer"] = {0.95, 0.8, 0.4, 0.6},                -- 金黄
    ["Wine"] = {0.75, 0.2, 0.3, 0.7},                -- 柔红
    ["Whiskey"] = {0.8, 0.5, 0.2, 0.7},              -- 琥珀
    ["Vodka"] = {0.95, 0.95, 0.95, 0.4},             -- 清白
    ["Rum"] = {0.7, 0.4, 0.2, 0.6},                  -- 淡棕
    ["Brandy"] = {0.8, 0.6, 0.3, 0.7},               -- 金棕
    ["Scotch"] = {0.7, 0.5, 0.3, 0.7},               -- 淡琥珀
    ["Gin"] = {0.95, 0.95, 1.0, 0.4},                -- 冰蓝白
    ["Tequila"] = {1.0, 0.95, 0.6, 0.5},             -- 亮黄
    ["CoffeeLiqueur"] = {0.45, 0.3, 0.2, 0.7},       -- 深棕
    ["Champagne"] = {1.0, 0.95, 0.7, 0.5},           -- 气泡黄
    ["Sherry"] = {0.8, 0.6, 0.3, 0.6},               -- 深金
    ["Port"] = {0.6, 0.2, 0.3, 0.7},                 -- 深红
    ["Curacao"] = {0.3, 0.6, 1.0, 0.6},              -- 鲜蓝
    ["Cider"] = {1.0, 0.9, 0.4, 0.6},                -- 苹果黄
    ["Mead"] = {1.0, 0.85, 0.5, 0.6},                -- 蜂蜜金
    ["Vermouth"] = {0.9, 0.8, 0.6, 0.6},             -- 香槟黄

    -- Juice
    ["JuiceLemon"] = {1.0, 1.0, 0.4, 0.7},           -- 明黄
    ["JuiceOrange"] = {1.0, 0.7, 0.2, 0.7},          -- 橙黄
    ["JuiceFruitpunch"] = {1.0, 0.4, 0.6, 0.7},      -- 粉红
    ["JuiceTomato"] = {0.9, 0.3, 0.2, 0.7},          -- 番茄红
    ["JuiceApple"] = {1.0, 1.0, 0.7, 0.6},           -- 淡黄
    ["JuiceGrape"] = {0.7, 0.3, 0.7, 0.7},           -- 柔紫
    ["JuiceCranberry"] = {0.8, 0.2, 0.3, 0.7},       -- 蔓红
    ["SpiffoJuice"] = {0.2, 0.9, 0.4, 0.7},          -- 鲜绿

    -- Pop
    ["Cola"] = {0.4, 0.2, 0.1, 0.6},                 -- 柔棕
    ["ColaDiet"] = {0.45, 0.3, 0.2, 0.6},            -- 稍浅
    ["GingerAle"] = {1.0, 0.9, 0.6, 0.5},            -- 姜黄
    ["SodaPop"] = {0.5, 0.9, 1.0, 0.7},              -- 天蓝
    ["SodaStrewberry"] = {1.0, 0.5, 0.5, 0.7},       -- 草莓粉
    ["SodaPineapple"] = {1.0, 0.95, 0.5, 0.7},       -- 菠萝黄
    ["SodaGrape"] = {0.7, 0.4, 0.9, 0.7},            -- 亮紫
    ["SodaBlueberry"] = {0.4, 0.5, 1.0, 0.7},        -- 浅蓝
    ["SodaLime"] = {0.7, 1.0, 0.5, 0.7},             -- 青柠绿

    -- Hotdrink
    ["Coffee"] = {0.4, 0.3, 0.2, 0.7},               -- 深棕
    ["Tea"] = {0.7, 0.5, 0.3, 0.6},                  -- 淡茶棕

    -- Chemical Fluid
    ["Petrol"] = {1.0, 0.85, 0.2, 0.7},              -- 明黄
    ["Bleach"] = {0.95, 0.95, 1.0, 0.6},             -- 微蓝白
    ["CleaningLiquid"] = {0.4, 0.8, 1.0, 0.6},       -- 洁净蓝
    ["Acid"] = {0.9, 1.0, 0.3, 0.7},                 -- 明绿黄
    ["Paint"] = {0.8, 0.3, 0.3, 0.8},                -- 红棕
    ["Dye"] = {0.6, 0.2, 0.9, 0.7},                  -- 紫
    ["HairDye"] = {0.3, 0.3, 0.3, 0.8},              -- 深灰
    ["Cologne"] = {0.8, 0.8, 1.0, 0.5},              -- 淡紫蓝
    ["Perfume"] = {1.0, 0.8, 0.95, 0.5},             -- 淡粉紫

    -- Poison
    ["PoisonWeak"] = {0.6, 0.9, 0.3, 0.6},           -- 亮绿
    ["PoisonNormal"] = {0.5, 0.8, 0.3, 0.7},         -- 青绿
    ["PoisonStrong"] = {0.4, 0.7, 0.2, 0.8},         -- 深绿
    ["PoisonPotent"] = {0.3, 0.6, 0.2, 0.9},         -- 墨绿

    -- Other
    ["Blood"] = {0.8, 0.1, 0.1, 0.8},                -- 红
    ["AnimalBlood"] = {0.7, 0.2, 0.2, 0.7},          -- 暗红
    ["AnimalGrease"] = {1.0, 1.0, 0.7, 0.5},         -- 油黄
    ["Honey"] = {1.0, 0.85, 0.3, 0.7},               -- 金色
    ["SecretFlavoring"] = {0.9, 0.3, 0.9, 0.6},      -- 魔法紫
    ["Grenadine"] = {1.0, 0.2, 0.4, 0.7},            -- 石榴红
    ["SimpleSyrup"] = {1.0, 1.0, 0.95, 0.5}          -- 淡白黄
    
}

function CHBLiquidColors:getLiquidColor(fluidContainer)
    if not fluidContainer then 
        return 0.2, 0.5, 0.9, 0.7 
    end
    
    local fluid = fluidContainer:getPrimaryFluid()
    if not fluid then 
        return 0.2, 0.5, 0.9, 0.7
    end

    local fluidType = fluid:getFluidType()
    local fluidTypeString = tostring(fluidType)

    local typeName = fluidTypeString:match("FluidType%.(.+)")
    if typeName and self.Colors[typeName] then
        local color = self.Colors[typeName]
        return color[1], color[2], color[3], color[4]
    end

    local fluidName = fluid:getFluidTypeString()
    if fluidName and self.Colors[fluidName] then
        local color = self.Colors[fluidName]
        return color[1], color[2], color[3], color[4]
    end

    return 0.2, 0.5, 0.9, 0.7
end

return CHBLiquidColors