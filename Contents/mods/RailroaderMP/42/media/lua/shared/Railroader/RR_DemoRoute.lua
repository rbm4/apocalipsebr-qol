--***********************************************************************
-- Railroader / RR_DemoRoute
-- A hardcoded polyline used by the vertical slice. Coordinates are placeholder
-- world tiles forming a simple L then a diagonal -- to be replaced with real
-- nodes laid along actual rails in-game. Kept in shared so both the test harness
-- and the (future) spawn code can use the exact same data.
--***********************************************************************

local TrackData = RR and RR.TrackData or require("Railroader/RR_TrackData")

local N = TrackData.node
local DEMO_NODES = {
    N(0,   0,  0, "start"),
    N(10,  0,  0),
    N(10,  10, 0),
    N(20,  20, 0, "end"),
}

local RR_DemoRoute = {
    nodes = DEMO_NODES,
    build = function()
        return TrackData.buildRoute(DEMO_NODES, { looped = false })
    end,
}

RR = RR or {}
RR.DemoRoute = RR_DemoRoute

return RR_DemoRoute
