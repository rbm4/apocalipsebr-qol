local old_ISOpenCloseVehicleWindow_complete = ISOpenCloseVehicleWindow.complete

--TODO check if this even makes sense now

function ISOpenCloseVehicleWindow:complete()
    -- TODO удалить после перевода всех машин на тюнинг 2.0
    self.Wprotection = self.vehicle:getPartById("ATAProtection" .. self.part:getId())
    if self.Wprotection then
        print('tsarLib ISOpenCloseVehicleWindow hack applied part='..tostring("ATAProtection" .. self.part:getId()))
        local animString = self.open and "Open" or "Close"
        self.vehicle:playPartAnim(self.Wprotection, animString)
        local part = self.Wprotection
        local door = part:getDoor()
        if door then
            door:setOpen(self.open)
            self.vehicle:transmitPartDoor(part)
        end
    end
    
    self.Wprotection = self.vehicle:getPartById("ATA2Protection" .. self.part:getId())
    if self.Wprotection then
        print('tsarLib ISOpenCloseVehicleWindow hack applied part='..tostring("ATA2Protection" .. self.part:getId()))
        local animString = self.open and "Open" or "Close"
        self.vehicle:playPartAnim(self.Wprotection, animString)
        local part = self.Wprotection
        local door = part:getDoor()
        if door then
            door:setOpen(self.open)
            self.vehicle:transmitPartDoor(part)
        end
    end
    return old_ISOpenCloseVehicleWindow_complete(self)-- TODO check if vanilla should be called in addition to ATA2. log 'no such vehicle id=' should help.
end
