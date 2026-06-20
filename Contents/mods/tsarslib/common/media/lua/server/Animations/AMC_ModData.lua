-- AMC_ModData.lua
-- Removed: GlobalModData "tsaranimations" init, receive, and cleanup hooks.
--
-- The OnReceiveGlobalModData / ModData.request / ModData.transmit flow was:
--   1. Broken on 42.15 due to an inverted boolean in GlobalModDataPacket.parse()
--      (OnReceiveGlobalModData always fires with `false` instead of the KahluaTable).
--   2. A source of unnecessary network strain (client polled every 100 ticks).
--   3. Dead code — no mod in the pack writes to or reads from the "tsaranimations"
--      GlobalModData table. The actual animation system uses per-vehicle-part ModData
--      ("tsaranimation" singular) via AMC_Commands.lua + transmitPartModData(), and
--      TCLConfig/SetVariable via tsarslib_Anim_Control.lua. Both are unaffected.
--
-- If a future mod needs server-wide animation state shared with clients, use
-- sendClientCommand / sendServerCommand (module 'autotsaranim') instead of
-- GlobalModData, to avoid the network cost of transmitting the entire table.

-- Legacy compatibility: keep an empty "tsaranimations" table alive so that clients
-- still running old tsarslib (workshop item 2392709985) get a valid response instead
-- of triggering "received request for non-existing table" log spam on every poll.
-- The table is intentionally empty; nothing in this pack reads from it.
Events.OnInitGlobalModData.Add(function()
    if not ModData.exists("tsaranimations") then
        ModData.create("tsaranimations")
    end
end)