-- LabEquipmentDetection_client.lua
-- Functions to detect lab equipment nearby / Detecta equipamento

local function addRange(tbl, prefix, startIndex, endIndex, item)
    for i = startIndex, endIndex do
        tbl[string.format("%s_%d", prefix, i)] = item
    end
end

local spriteToEquip = {}
addRange(spriteToEquip, "demonius_vaccine_01", 8, 11, "LabItems.LabSpectrometer")
addRange(spriteToEquip, "appliances_com_01", 72, 75, "DesktopComputer")

local function LabRecipes_LookForNearEquipment(square, equipment)
    if not square then return nil end

    local px, py, pz = square:getX(), square:getY(), square:getZ()

    for y = py - 1, py + 1 do
        for x = px - 1, px + 1 do
            local sqTest = getCell():getGridSquare(x, y, pz)
            if sqTest then
                local objs = sqTest:getObjects()
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if obj and obj.getSprite then
                        local sprite = obj:getSprite()
                        if sprite and sprite.getName then
                            local ok, name = pcall(sprite.getName, sprite)
                            if ok and name and spriteToEquip[name] == equipment then
                                return sqTest
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

function LabRecipes_IsNearLabEquip(equipment)
    local player = getPlayer()
    if not player then return nil end

    return LabRecipes_LookForNearEquipment(
        player:getCurrentSquare(),
        equipment
    )
end

function LabRecipes_IsNearSpectrometer()
    return LabRecipes_IsNearLabEquip("LabItems.LabSpectrometer") ~= nil
end

function LabRecipes_IsNearComputer()
    return LabRecipes_IsNearLabEquip("DesktopComputer") ~= nil
end