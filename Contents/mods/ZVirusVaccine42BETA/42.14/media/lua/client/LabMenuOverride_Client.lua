-- We hook into vanilla functions to override the inventory context menu for lab fluid containers.
-- I can add debug options to add lab fluids directly for testing.
-- Also overrides the empty action to add a dirty variant of the item.
-- Personally I think this makes the mod very fragile between official updates, because we mess with vanilla code that might change, like it did last time.
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

local function labEmptyFluidContainer(playerObj, owner)
    local fluidType = ""
    if owner:hasComponent(ComponentType.FluidContainer) then
        local fc = owner:getFluidContainer()
        if fc and fc:getPrimaryFluid() then
            fluidType = fc:getPrimaryFluid():getFluidTypeString()
        end
    end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, owner, true)
    ISTimedActionQueue.add(LabActionEmptyFluid:new(playerObj, owner, fluidType)) -- calls our very own empty action, not the vanilla one.
end

local function labAddDebugFluid(cont, fluidName)
    cont:Empty()
    cont:addFluid(fluidName, cont:getCapacity())
    if isServer() then
        cont:syncItemFields()
    end
end

labHook(ISFluidContainerMenu, {
    createMenu = function(orig, context, item, waterContainer, playerObj)
        local owner = item or waterContainer
        if not owner or not instanceof(owner, "InventoryItem") then
            return orig(context, item, waterContainer, playerObj)
        end

        if not LAB_ITEMS[owner:getFullType()] then
            return orig(context, item, waterContainer, playerObj)
        end

        -- item de lab constrói menu próprio
        local cont = owner:getFluidContainer()
            or (owner:getWorldItem() ~= nil and owner:getWorldItem():getFluidContainer())

        if not cont or not cont:canPlayerEmpty() then
            return orig(context, item, waterContainer, playerObj)
        end

        local option = context:addOption(getText("ContextMenu_Fluid"), nil)
        option.iconTexture = getTexture("Item_WaterDrop")
        local subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(option, subMenu)

        local contWrapper = ISFluidContainer:new(cont)
        subMenu:addOption(getText("Fluid_Show_Info"), playerObj, ISFluidContainerMenu.showInfo, contWrapper)
        subMenu:addOption(getText("Fluid_Transfer_Fluids"), playerObj, ISFluidContainerMenu.transferFluids, contWrapper)

        if not cont:isEmpty() then
            subMenu:addOption(getText("Fluid_Empty"), playerObj, labEmptyFluidContainer, owner)
        end

        if getDebug() then
            local addFluidOption = subMenu:addDebugOption(getText("ContextMenu_AddFluid"), nil, nil)
            local addFluidSubMenu = ISContextMenu:getNew(subMenu)
            subMenu:addSubMenu(addFluidOption, addFluidSubMenu)

            for _, fluidName in ipairs(LAB_FLUIDS) do
                addFluidSubMenu:addOption(fluidName, cont, labAddDebugFluid, fluidName)
            end
        end
    end
})