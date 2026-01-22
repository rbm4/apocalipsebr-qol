


function CDCsuitcaseSEV_OnCreate(item)
    if not item then return end

    local container = item:getItemContainer()
    if not container then return end

    local md = item:getModData()
    if md.filled then return end

    -- 100% garantizado, 1 de cada
    container:AddItem("SpecialEmergencyVehicles.SEV_CDCnote1")
    container:AddItem("SpecialEmergencyVehicles.SEV_CDCnote2")
    container:AddItem("SpecialEmergencyVehicles.SEV_CDCnote3")
    container:AddItem("SpecialEmergencyVehicles.SEV_CDCnote4")	
    container:AddItem("base.Paperclip")
    md.filled = true
end


function CDCsamplesuitcaseSEV_OnCreate(item)
    if not item then return end

    local container = item:getItemContainer()
    if not container then return end

    local md = item:getModData()
    if md.filled then return end

    -- 100% garantizado, 1 de cada
    container:AddItem("base.sevCDCbloodsample")
    container:AddItem("base.sevCDCbloodsample")
    container:AddItem("base.sevCDCbloodsample")
    md.filled = true
end

function CDC556ammosuitcaseSEV_OnCreate(item)
    if not item then return end

    local container = item:getItemContainer()
    if not container then return end

    local md = item:getModData()
    if md.filled then return end

    -- 100% garantizado, 12 cajas
    container:AddItems("Base.556Box", 12)

    md.filled = true
end