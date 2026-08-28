require "Items/InventoryItemFactory"

local function RegisterBicycleItems()
    local itemNames = {
        "Bicycle.Bicycle",
        "Bicycle.Bicycle_RedStreet",
    }

    for _, itemName in ipairs(itemNames) do
        if InventoryItemFactory.CreateItem(itemName) then
            -- print("Successfully registered item:", itemName)
        else
            -- print("Failed to register item:", itemName)
        end
    end
end

Events.OnGameStart.Add(RegisterBicycleItems)
