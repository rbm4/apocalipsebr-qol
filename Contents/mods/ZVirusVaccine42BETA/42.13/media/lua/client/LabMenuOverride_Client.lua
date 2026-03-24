-- Overrides the inventory context menu for lab fluid containers.
-- I can add debug options to add lab fluids directly for testing.
-- Also overrides the empty action to add a dirty variant of the item.
-- Personally I think this makes the mod very fragile between official updates, because we mess with vanilla code that might change.
-- But I do love logical things, and having LabTestTubes and LabFlasks that can actually contain fluids and be emptied returning dirty version is just too good to pass up. So here we are.

require "Util/LabSharedUtils"

local LAB_ITEMS = {
    ["LabItems.LabFlask"]    = true,
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

    function self.addLabDebugFluid(_p, cont, fluidName)
        cont:Empty()
        cont:addFluid(fluidName, cont:getCapacity())
    end

    function self.labEmptyFluidContainer(_p, _container)
        local owner = _container:getOwner()
        local fluidType = ""
        if owner and owner:hasComponent(ComponentType.FluidContainer) then
            local fc = owner:getFluidContainer()
            if fc and fc:getPrimaryFluid() then
                fluidType = fc:getPrimaryFluid():getFluidTypeString()
            end
        end
        ISInventoryPaneContextMenu.transferIfNeeded(_p.player, owner, true)
        ISTimedActionQueue.add(LabActionEmptyFluid:new(_p.player, owner, fluidType))
    end

    function self.createMenu(_item)
        if not instanceof(_item, "InventoryItem") or not LAB_ITEMS[_item:getFullType()] then
            return originalCreateMenu(_item)
        end

        local cont = _item:getFluidContainer()
            or (_item:getWorldItem() ~= nil and _item:getWorldItem():getFluidContainer())

        if not cont or not cont:canPlayerEmpty() then
            return originalCreateMenu(_item)
        end

        local parent = self.invMenu.context:addOption(_item:getDisplayName(), self.invMenu, nil)
        parent.itemForTexture = _item
        local subMenu = ISContextMenu:getNew(self.invMenu.context)
        self.invMenu.context:addSubMenu(parent, subMenu)

        subMenu:addOption(getText("Fluid_Show_Info"), self.invMenu, self.showInfo, cont)
        subMenu:addOption(getText("Fluid_Transfer_Fluids"), self.invMenu, self.transferFluids, cont)

        if not cont:isEmpty() then
            subMenu:addOption(getText("Fluid_Empty"), self.invMenu, self.labEmptyFluidContainer, cont)
        end

        if getDebug() then
            local addFluidOption = subMenu:addDebugOption(getText("ContextMenu_AddFluid"), nil, nil)
            local addFluidSubMenu = ISContextMenu:getNew(subMenu)
            subMenu:addSubMenu(addFluidOption, addFluidSubMenu)

            for _, fluidName in ipairs(LAB_FLUIDS) do
                addFluidSubMenu:addOption(fluidName, self.invMenu, self.addLabDebugFluid, cont, fluidName)
            end
        end
    end

    return self
end