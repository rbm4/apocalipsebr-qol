-- Override the inventory context menu for lab fluid containers
-- When using the "pour out" option on lab items, it returns the dirty version.
-- However, the "empty" and "transfer" context menu does not handle this, so we need to override it here.
-- It won't prevent players from selecting other vanilla/modded conteiners and selecting "transfer" to pour lab fluids into them,
-- but at least it removes the obvious option.
-- Also I can add debug options to add lab fluids directly for testing.

local LAB_ITEMS = {
    ["LabItems.LabFlask"] = true,
    ["LabItems.LabTestTube"] = true,
}

local LAB_FLUIDS = {
    "PurifiedWater",
    "SodiumHypochlorite",
    "HydrogenPeroxide",
    "AmmoniumSulfate",
    "BloodPlasma",
    "BloodCells",
    "Leukocytes",
    "Antibodies",
    "InfectedBlood",
    "TaintedBlood",
}

local Original_ContextFluidContainer = ISInventoryMenuElements.ContextFluidContainer

function ISInventoryMenuElements.ContextFluidContainer()
    local self = Original_ContextFluidContainer()

    local originalCreateMenu = self.createMenu

    function self.addDebugFluid(_p, cont, fluid)
        cont:Empty()
        cont:addFluid(fluid, cont:getCapacity())
    end

    function self.createMenu(_item)
        if instanceof(_item, "InventoryItem") and LAB_ITEMS[_item:getFullType()] then
            local cont = _item:getFluidContainer()
                or (_item:getWorldItem() and _item:getWorldItem():getFluidContainer())

            if cont and cont:canPlayerEmpty() then
                local parent = self.invMenu.context:addOption(
                    _item:getDisplayName(),
                    self.invMenu,
                    nil
                )
                parent.itemForTexture = _item

                local subMenu = ISContextMenu:getNew(self.invMenu.context)
                self.invMenu.context:addSubMenu(parent, subMenu)

                subMenu:addOption(getText("Fluid_Show_Info"), self.invMenu, self.showInfo, cont)

                -- DEBUG APENAS COM FLUIDOS DO MOD
                if getDebug() then
                    local addFluidOption =
                        subMenu:addDebugOption(getText("ContextMenu_AddFluid"), nil, nil)

                    local addFluidSubMenu = ISContextMenu:getNew(subMenu)
                    subMenu:addSubMenu(addFluidOption, addFluidSubMenu)

                    for _, fluidName in ipairs(LAB_FLUIDS) do
                        addFluidSubMenu:addOption(
                            fluidName,
                            self.invMenu,
                            self.addDebugFluid,
                            cont,
                            fluidName
                        )
                    end
                end
            end

            return
        end

        -- fallback vanilla
        originalCreateMenu(_item)
    end

    return self
end