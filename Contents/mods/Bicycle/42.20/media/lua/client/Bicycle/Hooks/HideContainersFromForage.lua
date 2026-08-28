require("Foraging/ISSearchManager")

local INVISIBLE_CONTAINER_TYPES = {
    ["Bicycle.Saddlebag"] = true,
    ["Bicycle.Basket"] = true,
    ["Bicycle.Crate"] = true,
    ["Bicycle.ToolboxContainer"] = true,
    ["Bicycle.PlasticBagLeft"] = true,
    ["Bicycle.PlasticBagRight"] = true,
}

local function hideBicycleContainersFromForage()
    for fullType, _ in pairs(INVISIBLE_CONTAINER_TYPES) do
        ISSearchManager.ignoredItemTypes[fullType] = true
    end
end

Events.OnGameStart.Add(hideBicycleContainersFromForage)
