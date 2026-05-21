--[[
    Biochemical_Armor.lua  (shared — loads on both client and server)

    The armor protection logic has been moved to the server-side
    Biochemical_Armor_Server.lua (lua { update = Biochemical_Armor.Update }).

    This file only declares the namespace so that any other shared/client code
    that references "Biochemical_Armor" doesn't error before the server file loads.
    The old OnPlayerUpdate / sendClientCommand approach has been removed because:
      - VehiclePart:setCondition() from a client context is not authoritative in B42.18.
      - sendClientCommand("vehicle","setPartCondition",...) no longer works for this use-case.
      - The server-side lua { update = ... } callback is the correct B42 pattern.
]] --
Biochemical_Armor = Biochemical_Armor or {}
