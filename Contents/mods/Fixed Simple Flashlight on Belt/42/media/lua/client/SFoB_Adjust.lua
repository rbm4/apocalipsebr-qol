Events.OnInitWorld.Add(function()
    local function Adjust(Name, Property, Value)
        local item = ScriptManager.instance:getItem(Name)
        if item then
            item:DoParam(Property .. " = " .. Value)
        else
            print("Error: No item found with name " .. Name)
        end
    end

    Adjust("Base.Torch", "AttachmentType", "HandTorchSmall")
    Adjust("Base.HandTorch", "AttachmentType", "HandTorchSmall")
    Adjust("Base.Flashlight_Crafted", "AttachmentType", "HandTorchSmall")
    Adjust("Base.FlashLight_AngleHead", "AttachmentType", "TorchAngled")
    Adjust("Base.FlashLight_AngleHead_Army", "AttachmentType", "TorchAngled")
    Adjust("AuthenticZClothing.Torch2", "AttachmentType", "HandTorchSmall")
    Adjust("AuthenticZClothing.Authentic_MilitaryFlashlightGreen", "AttachmentType", "AZMilitaryTorch")
    Adjust("AuthenticZClothing.Authentic_MilitaryFlashlightGrey", "AttachmentType", "AZMilitaryTorch")
end)
