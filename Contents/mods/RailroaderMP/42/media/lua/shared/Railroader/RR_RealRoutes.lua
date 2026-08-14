--***********************************************************************
-- Railroader / RR_RealRoutes  (Task 1.B: YOUR hand-authored routes)
--
-- Fill in real rail routes here, in TRUE world tile coords. How to get coords:
--   1. In-game, walk to a spot ON a real rail.
--   2. Press  J  -> the current tile is captured and the WHOLE captured list is
--      printed to console.txt as ready-to-paste  { x=, y=, z=, name= }  lines.
--   3. Walk along the rail, pressing J at each bend / every ~15-30 tiles.
--   4. Press  H  to clear the captured list and start over.
--   5. Copy the printed node lines from console.txt into a Routes.register(...)
--      block below (replace the example), restart the game.
--   6. Press  O  -> the loco spawns ON this route in world space and follows it.
--
-- id "main" is what the O key spawns by default (RR_Routes.DEFAULT_ID). Use other
-- ids for extra routes and spawn them with U (cycles through registered ids).
--***********************************************************************

local Routes = RR and RR.Routes or require("Railroader/RR_Routes")

-- Muldraugh main line (id "main" = what O spawns; coords read from the in-game map,
-- to be cross-checked once in-game with J). z=0 (ground rails).
Routes.register("main", {
    looped = false,
    nodes = {
        -- Clockwise section: the main runs THROUGH the depot. These nodes come first
        -- (cw_end -> depot), so the depot is now a MID-node, not node[1] -- the loco can
        -- drive both ways out of the shed. Depot spawn shifts accordingly (RR_Spawn
        -- DEPOT.distance = 23278 = this section's 23188 tiles + the original 90). The
        -- Muldraugh loop's end (11902,10644) lands on this section between (11902,10363)
        -- and (11902,12154) -- a merge switch there is a later step.
        { x = 1986,  y = 6874,  z = 0, name = "cw_end", open = true },   -- OPEN end: torn-up rails, NO buffer -> derail if run off at speed (Task 1.N)
        { x = 1986,  y = 7885,  z = 0 },
        { x = 1914,  y = 7957,  z = 0 },   -- x+1: exact 45deg (-71,+71)
        { x = 1839,  y = 7957,  z = 0 },
        { x = 548,   y = 9248,  z = 0 },
        { x = 548,   y = 10921, z = 0 },
        { x = 821,   y = 11194, z = 0 },
        { x = 821,   y = 13336, z = 0 },
        { x = 961,   y = 13476, z = 0 },
        { x = 1980,  y = 13476, z = 0 },
        { x = 2580,  y = 14076, z = 0 },   -- SE diagonal now lands on y=14076
        { x = 2658,  y = 14076, z = 0 },
        { x = 2663,  y = 14081, z = 0 },   -- short 45deg step down to the y=14081 run
        { x = 3430,  y = 14081, z = 0 },
        { x = 3488,  y = 14139, z = 0 },
        { x = 4505,  y = 14139, z = 0 },
        { x = 4884,  y = 14518, z = 0 },
        { x = 5355,  y = 14518, z = 0 },
        { x = 5507,  y = 14366, z = 0 },
        { x = 6267,  y = 14366, z = 0 },   -- x-1: exact 45deg (258,258)
        { x = 6525,  y = 14624, z = 0 },
        { x = 7006,  y = 14624, z = 0 },
        { x = 7112,  y = 14518, z = 0 },
        { x = 7901,  y = 14518, z = 0 },
        { x = 8288,  y = 14131, z = 0 },
        { x = 11139, y = 14131, z = 0 },
        { x = 11186, y = 14084, z = 0 },
        { x = 11186, y = 12870, z = 0 },
        { x = 11902, y = 12154, z = 0 },
        { x = 11902, y = 10363, z = 0 },
        { x = 11732, y = 10193, z = 0 },
        { x = 11633, y = 10193, z = 0 },
        { x = 11620, y = 10180, z = 0 },
        { x = 11620, y = 9873,  z = 0 },
        { x = 11606, y = 9859, z = 0, name = "depot" },   -- left rail of the diagonal (was 9856 = right rail)
        { x = 11606, y = 9662, z = 0 },
        { x = 11645, y = 9623, z = 0 },
        { x = 11645, y = 9551, z = 0 },
        { x = 11671, y = 9525, z = 0 },
        { x = 11869, y = 9525, z = 0 },
        { x = 11930, y = 9464, z = 0 },
        { x = 12034, y = 9464, z = 0 },   -- NE diagonal moved onto the left rail (was ~0.5 tile off: needed -0.44 vs NE +0.071)
        { x = 12107, y = 9391, z = 0 },   -- pairs with 12034,9464: exact 45deg on line x+y=21498
        { x = 12107, y = 7760, z = 0 },
        { x = 12179, y = 7688, z = 0 },
        { x = 12179, y = 6836, z = 0 },
        { x = 12197, y = 6818, z = 0 },
        { x = 12252, y = 6818, z = 0 },
        { x = 12295, y = 6775, z = 0 },   -- y-1: exact 45deg (43,-43)
        { x = 12295, y = 6620, z = 0 },
        { x = 12306, y = 6609, z = 0 },
        { x = 12576, y = 6609, z = 0 },
        { x = 12621, y = 6564, z = 0 },   -- y-1: exact 45deg (45,-45)
        { x = 12621, y = 5863, z = 0 },
        { x = 12665, y = 5819, z = 0 },
        { x = 12665, y = 3498, z = 0 },
        { x = 12669, y = 3494, z = 0 },
        { x = 12669, y = 3043, z = 0 },
        { x = 12647, y = 3021, z = 0 },   -- both y +3: this diagonal was mis-measured along the RIGHT rail; moved onto the left rail like the rest
        { x = 12647, y = 2713, z = 0 },
        { x = 12765, y = 2595, z = 0 },
        { x = 12765, y = 2299, z = 0 },
        { x = 12787, y = 2277, z = 0 },
        { x = 12885, y = 2277, z = 0, name = "louisville", open = true },   -- Louisville terminal: torn-up open end -> derail at speed
    },
})

-- ┌── ADD MORE ROUTES BELOW (copy the block above, new id + coords) ───────────────┐
-- └──────────────────────────────────────────────────────────────────────────────┘

-- Switches on "main" (Task: turnouts / multi-node track). require() forces the
-- graph module to load regardless of the shared-file alphabetical order.
local TrackGraph = RR and RR.TrackGraph or require("Railroader/RR_TrackGraph")

-- Net "main": the edge "main" itself is the route registered above; extra edges are
-- listed here. A switch names its THREE legs as (edge, toward) pairs -- the
-- direction each leg leaves the switch point. Facing vs trailing is NOT registered:
-- the graph walk derives it from which leg a train arrives on.
--
-- The Brandenburg Branch leaves the main via a two-switch junction: S1 and S2 each
-- have a short LEAD, and both leads meet the branch at Brandenburg Junction (S3) at
-- (12098,8109). From there brandenburg_branch runs west across the map to Brandenburg.
--
-- S1: turnout at (12107,8117). POINTS face the depot ("start") -> FACING for a train
--     running OUT from the depot (forward). NORMAL = stay on the main; REVERSE =
--     diverge onto s1_lead -> the branch. (Forward-passing trains take it trailing.)
-- S2: turnout at (12107,8103) (stand ~12104,8100). POINTS face the "end" -> FACING
--     only for a train travelling BACKWARD (toward the depot) -- the reverse-direction
--     switch. NORMAL = stay on the main toward the depot; REVERSE = onto s2_lead.
-- S3: Brandenburg Junction at (12098,8109) (stand ~12097,8106). Its POINTS face the
--     branch (west) -> FACING only for a train RETURNING from Brandenburg, which then
--     picks a lead: NORMAL = straight -> s2_lead -> S2 -> main AWAY from the depot;
--     REVERSE = right -> s1_lead -> S1 -> main TO the depot. Trains heading OUT onto
--     the branch (from S1 or S2) pass S3 trailing and just merge west.
TrackGraph.register("main", {
    edges = {
        -- Short leads from each main-line switch to the junction.
        s1_lead = {
            { x = 12107, y = 8117, z = 0 },
            { x = 12098, y = 8109, z = 0 },
        },
        s2_lead = {
            { x = 12107, y = 8103, z = 0 },
            { x = 12101, y = 8109, z = 0 },   -- curve point: the lead swings onto y=8109 BEFORE the junction so the loco tracks the rails round the turnout instead of chording straight across
            { x = 12098, y = 8109, z = 0 },
        },
        -- The shared Brandenburg Branch: from the junction west then north-west across
        -- the map to Brandenburg, ending at a factory in town where the rails are torn up.
        brandenburg_branch = {
            { x = 12098, y = 8109, z = 0 },
            { x = 10761, y = 8109, z = 0 },
            { x = 10724, y = 8072, z = 0 },
            { x = 8699,  y = 8072, z = 0 },
            { x = 8655,  y = 8116, z = 0 },
            -- Re-authored 2026-07-29 (owner): the run from (8456,8116) to (6994,7598) --
            -- the old 8422/8298/7549/7483/7453 dog-leg -- was replaced by these five points.
            { x = 8223,  y = 8116, z = 0 },
            { x = 8215,  y = 8124, z = 0 },   -- y 8125->8124: makes the short jog an exact 45deg (dx=dy=8) AND the next leg dead level
            { x = 7133,  y = 8124, z = 0 },
            { x = 6989,  y = 7980, z = 0 },   -- exact 45deg (dx=dy=144)
            { x = 6989,  y = 7593, z = 0 },

            { x = 6949,  y = 7553, z = 0 },
            { x = 6762,  y = 7553, z = 0 },
            { x = 6725,  y = 7516, z = 0 },
            { x = 6725,  y = 7000, z = 0 },
            { x = 6607,  y = 6882, z = 0 },
            { x = 5323,  y = 6882, z = 0 },
            { x = 5222,  y = 6781, z = 0 },
            { x = 4424,  y = 6781, z = 0 },
            { x = 4351,  y = 6708, z = 0 },
            { x = 4351,  y = 6371, z = 0 },
            { x = 4331,  y = 6351, z = 0 },
            { x = 3729,  y = 6351, z = 0 },
            { x = 3603,  y = 6225, z = 0 },
            { x = 3197,  y = 6225, z = 0 },
            { x = 3138,  y = 6166, z = 0 },
            { x = 2691,  y = 6166, z = 0 },
            { x = 2647,  y = 6210, z = 0 },
            { x = 2647,  y = 6623, z = 0 },
            { x = 2574,  y = 6696, z = 0 },   -- x 2574->2575: makes the diagonal exact 45deg (dx=dy=72)
            { x = 2161,  y = 6696, z = 0, name = "brandenburg", open = true },   -- OPEN end: factory in town, rails torn up, NO buffer -> derail (Task 1.N)
        },
        -- The Muldraugh Branch: a loop off the main. It leaves at s4 (fork 12107,9006,
        -- north of the depot) and rejoins at s5 (11902,10644, on the clockwise section) --
        -- a true balloon loop through the depot. s4 faces depot-bound trains; s5 faces
        -- north-bound trains on the clockwise leg.
        muldraugh_branch = {
            { x = 12107, y = 9006,  z = 0 },   -- fork (= s4.at)
            { x = 12062, y = 9051,  z = 0 },
            { x = 11575, y = 9051,  z = 0 },
            { x = 11547, y = 9079,  z = 0 },
            { x = 11147, y = 9079,  z = 0 },
            { x = 11103, y = 9123,  z = 0 },
            { x = 11103, y = 9564,  z = 0 },
            { x = 11098, y = 9569,  z = 0 },
            { x = 11054, y = 9569,  z = 0 },
            { x = 11036, y = 9587,  z = 0 },   -- y-1: exact 45deg (-18,+18)
            { x = 11036, y = 9735,  z = 0 },
            { x = 11023, y = 9748,  z = 0 },
            { x = 11023, y = 10055, z = 0 },  
            { x = 11390, y = 10422, z = 0 },
            { x = 11815, y = 10422, z = 0 },   -- x back to 11815: exact 45deg (60,60)
            { x = 11875, y = 10482, z = 0 },  
            { x = 11875, y = 10617, z = 0 },
            { x = 11902, y = 10644, z = 0, name = "muldraugh_merge" },  -- = s5.at: rejoins the main (clockwise section)
        },
        -- Depot Siding 1: a passing/holding siding along the main at the depot (first of
        -- several). It leaves the main just north of the depot (s6, ~11643,9618), runs
        -- southeast PAST the depot hangars, and rejoins on the clockwise section (s7,
        -- ~11738,10196) -- a loop around the depot, switched at both ends.
        depot_siding_1 = {
            { x = 11645, y = 9620,  z = 0 },   -- north end (= s6.at, snapped onto the main)
            { x = 11738, y = 9713,  z = 0 },
            { x = 11738, y = 10199, z = 0, name = "depot_siding_1_south" },  -- south end (= s7.at, snapped onto the main)
        },
        -- Depot yard sidings 2 & 3 (short stub tracks off siding_1). They also meet each
        -- other at (11711,9877) via s10. Ends are buffers for now.
        depot_siding_2 = {
            { x = 11738, y = 9850, z = 0 },   -- begin (= s8.at, off depot_siding_1)
            { x = 11711, y = 9879, z = 0 },   -- meets depot_siding_3 here (= s10.at) -- MUST equal siding_3 end
            { x = 11711, y = 9914, z = 0, name = "depot_siding_2_end", open = true },   -- torn-up open end -> derail at speed
        },
        depot_siding_3 = {
            { x = 11689, y = 9661, z = 0 },   -- begin (= s9.at, off depot_siding_1)
            { x = 11689, y = 9857, z = 0 },
            { x = 11711, y = 9879, z = 0, name = "depot_siding_3_end" },   -- meets depot_siding_2 (= s10.at)
        },
        -- Depot Siding 4: a bypass around the depot on the WEST side. Leaves the main just
        -- north of the depot (s11, 11645,9623), runs straight south, and rejoins on the
        -- clockwise section (s12, 11656,10193) -- switched at both ends.
        depot_siding_4 = {
            { x = 11645, y = 9623,  z = 0 },   -- north end (= s11.at, on the main)
            { x = 11645, y = 10184, z = 0 },
            { x = 11654, y = 10193, z = 0, name = "depot_siding_4_south" },  -- south end (= s12.at, on the clockwise main)
        },
        -- Depot Siding 5: short connector from siding_4 (s13) to the main near the depot (s14).
        depot_siding_5 = {
            { x = 11645, y = 9846, z = 0 },   -- (= s13.at, on depot_siding_4)
            { x = 11620, y = 9871, z = 0 },
            { x = 11620, y = 9873, z = 0, name = "depot_siding_5_end" },  -- (= s14.at, on the clockwise main -- coherence)
        },
        -- Hangar 1: a shed track off siding_4, reachable from BOTH directions -- a lead for
        -- south-bound trains (s15) and one for north-bound (s16); the two leads merge at s17
        -- and share the shed track (11646,10028 -> 11671,10028).
        hangar_1_lead_a = {   -- south-approach lead (switch A / s15) = "второй ус"
            { x = 11645, y = 10024, z = 0 },   -- (= s15.at, on siding_4)
            { x = 11646, y = 10028, z = 0 },   -- merge (= s17.at)
        },
        hangar_1_lead_b = {   -- north-approach lead (switch B / s16) = "первый ус"
            { x = 11645, y = 10030, z = 0 },   -- (= s16.at, on siding_4)
            { x = 11646, y = 10028, z = 0 },   -- merge (= s17.at)
        },
        hangar_1 = {          -- the shed track itself
            { x = 11646, y = 10028, z = 0 },   -- merge (= s17.at)
            { x = 11675, y = 10028, z = 0, name = "hangar_1_end", open = true },   -- torn-up open end -> derail at speed
        },
        -- Hangar 2: same double-ended pattern as Hangar 1 -- a south lead (s18) and a
        -- north lead (s19) off siding_4, merging at s20 before the shed track. The two
        -- leads meet at (11646,10103) (Ус2 snapped from 11647 so all three coincide).
        hangar_2_lead_a = {   -- Ус 1, south-approach (switch A / s18)
            { x = 11645, y = 10099, z = 0 },   -- = s18.at, on siding_4
            { x = 11646, y = 10103, z = 0 },   -- merge (= s20.at)
        },
        hangar_2_lead_b = {   -- Ус 2, north-approach (switch B / s19)
            { x = 11645, y = 10105, z = 0 },   -- = s19.at, on siding_4
            { x = 11646, y = 10103, z = 0 },   -- merge (= s20.at)
        },
        hangar_2 = {          -- the shed track itself
            { x = 11646, y = 10103, z = 0 },   -- merge (= s20.at)
            { x = 11675, y = 10103, z = 0, name = "hangar_2_end", open = true },   -- torn-up open end -> derail at speed
        },
        -- Hangar 3: off the MAIN (clockwise leg), double-ended. South lead (s21) and
        -- north lead (s22); Ус2 joins Ус1 at (11615,10056), so a merge switch (s23) is
        -- needed there (user gave only the two entry switches -- s23 inferred).
        hangar_3_lead_a = {   -- Ус 1, south-approach (s21)
            { x = 11620, y = 10054, z = 0 },   -- = s21.at, on the main
            { x = 11618, y = 10056, z = 0 },
            { x = 11615, y = 10056, z = 0 },   -- merge (= s23.at)
        },
        hangar_3_lead_b = {   -- Ус 2, north-approach (s22)
            { x = 11620, y = 10058, z = 0 },   -- = s22.at, on the main
            { x = 11615, y = 10056, z = 0 },   -- merge (= s23.at)
        },
        hangar_3 = {          -- the shed track itself
            { x = 11615, y = 10056, z = 0 },   -- merge (= s23.at)
            { x = 11589, y = 10056, z = 0, name = "hangar_3_end", open = true },   -- torn-up open end -> derail at speed
        },
        -- Hangar 4: off the MAIN (clockwise leg), double-ended. Leads merge at (11615,10130).
        hangar_4_lead_a = {   -- Ус 1, south-approach (s24)
            { x = 11620, y = 10128, z = 0 },   -- = s24.at, on the main
            { x = 11618, y = 10130, z = 0 },
            { x = 11615, y = 10130, z = 0 },   -- merge (= s26.at)
        },
        hangar_4_lead_b = {   -- Ус 2, north-approach (s25)
            { x = 11620, y = 10132, z = 0 },   -- = s25.at, on the main
            { x = 11615, y = 10130, z = 0 },   -- merge (= s26.at)
        },
        hangar_4 = {          -- the shed track itself
            { x = 11615, y = 10130, z = 0 },   -- merge (= s26.at)
            { x = 11589, y = 10130, z = 0, name = "hangar_4_end", open = true },   -- torn-up open end -> derail at speed
        },
        -- Louisville passenger terminal -- terminal branch 1: a TURNING LOOP. A terminal-
        -- bound train diverts off the main at s27 (12697,2663), swings east-north-west, and
        -- rejoins the main at s28 (12765,2340) heading back toward the Muldraugh depot -- so
        -- the loco turns without a runaround. Both ends sit ON the main.
        terminal_branch_1 = {
            { x = 12697, y = 2663, z = 0 },   -- = s27.at, on the main
            { x = 12773, y = 2663, z = 0 },
            { x = 12827, y = 2609, z = 0 },
            { x = 12827, y = 2330, z = 0 },
            { x = 12813, y = 2316, z = 0 },
            { x = 12789, y = 2316, z = 0 },
            { x = 12765, y = 2340, z = 0 },   -- = s28.at, rejoins the main (toward the depot)
        },
        -- Louisville terminal, passenger platform 1: a stub off the main (s29), running
        -- north to a buffer where the train stands at the platform.
        passenger_platform_1 = {
            { x = 12729, y = 2632, z = 0 },   -- = s29.at, on the main
            { x = 12729, y = 2294, z = 0, name = "platform_1_end", open = true },   -- torn-up open end -> derail at speed
        },
        passenger_platform_2 = {   -- second platform stub, parallel to platform 1
            { x = 12738, y = 2623, z = 0 },   -- = s30.at, on the main
            { x = 12738, y = 2294, z = 0, name = "platform_2_end", open = true },   -- torn-up open end -> derail at speed
        },
        -- Terminal branch 2: a chord across the (12765,2595) corner of the main near the
        -- terminal, switched at both ends -- s31 (terminal-bound) and s32 (depot-bound).
        terminal_branch_2 = {
            { x = 12754, y = 2607, z = 0 },   -- = s31.at, on the main
            { x = 12754, y = 2485, z = 0 },
            { x = 12765, y = 2474, z = 0, name = "terminal_branch_2_end" },  -- = s32.at, rejoins the main
        },
        -- Terminal branch 3: connects terminal_branch_1 (s33) to the main (s34) near the
        -- terminal -- another chord, switched at both ends.
        terminal_branch_3 = {
            { x = 12810, y = 2626, z = 0 },   -- = s33.at, on terminal_branch_1
            { x = 12810, y = 2461, z = 0 },
            { x = 12765, y = 2416, z = 0, name = "terminal_branch_3_end" },  -- = s34.at, rejoins the main
        },
        terminal_branch_4 = {   -- chord: terminal_branch_1 (top) -> terminal_branch_3 (bottom)
            { x = 12795, y = 2642, z = 0 },   -- = s35.at, on terminal_branch_1
            { x = 12795, y = 2446, z = 0, name = "terminal_branch_4_end" },  -- = s36.at, on terminal_branch_3
        },
        terminal_branch_5 = {   -- chord: terminal_branch_1 (top) -> terminal_branch_3 (bottom)
            { x = 12781, y = 2655, z = 0 },   -- = s37.at, on terminal_branch_1
            { x = 12781, y = 2432, z = 0, name = "terminal_branch_5_end" },  -- = s38.at, on terminal_branch_3
        },
        terminal_branch_6 = {   -- passing bulge off terminal_branch_1's east straight (both ends on tb1)
            { x = 12827, y = 2591, z = 0 },   -- = s39.at, on terminal_branch_1
            { x = 12841, y = 2577, z = 0 },
            { x = 12841, y = 2468, z = 0 },
            { x = 12827, y = 2454, z = 0, name = "terminal_branch_6_end" },  -- = s40.at, on terminal_branch_1
        },
        terminal_branch_7 = {   -- big east loop-around off terminal_branch_1 (both ends on tb1)
            { x = 12812, y = 2316, z = 0 },   -- = s41.at, on terminal_branch_1 (the y=2316 west-run)
            { x = 12864, y = 2316, z = 0 },
            { x = 12886, y = 2338, z = 0 },
            { x = 12886, y = 2423, z = 0 },
            { x = 12867, y = 2442, z = 0 },
            { x = 12839, y = 2442, z = 0 },
            { x = 12827, y = 2430, z = 0, name = "terminal_branch_7_end" },  -- = s42.at, on tb1 east straight
        },
        terminal_branch_8 = {   -- dead-end spur off the main line (тупик)
            { x = 12765, y = 2311, z = 0 },   -- = s43.at, on the main
            { x = 12789, y = 2287, z = 0 },
            { x = 12885, y = 2287, z = 0, name = "terminal_branch_8_end", open = true },  -- torn-up open end -> derail at speed
        },
        freight_terminal_1 = {   -- Valley Station freight unloading platforms (loop off the main, west side)
            { x = 12665, y = 4478, z = 0 },   -- = s44.at, on the main (south / Louisville-bound end)
            { x = 12651, y = 4464, z = 0 },
            { x = 12651, y = 4238, z = 0 },
            { x = 12665, y = 4224, z = 0, name = "freight_terminal_1_end" },  -- = s45.at, on the main (north end)
        },
        -- Valley Station freight throat (Brandenburg-style): two main entries (s46 Louisville-
        -- bound, s47 from-Louisville) each have a lead to the junction (12670,4452 = s48),
        -- where s48 picks which ус a terminal-exiting train takes back to the main.
        ft2_lead_1 = {   -- Ус1 lead: s46 (Louisville-bound) -> junction
            { x = 12665, y = 4456, z = 0 },   -- = s46.at, on the main
            { x = 12669, y = 4452, z = 0 },
            { x = 12670, y = 4452, z = 0 },   -- junction (= s48.at)
        },
        ft2_lead_2 = {   -- Ус2 lead: s47 (from-Louisville) -> junction
            { x = 12665, y = 4444, z = 0 },   -- = s47.at, on the main
            { x = 12670, y = 4452, z = 0 },   -- junction (= s48.at)
        },
        freight_terminal_2 = {   -- Valley Station freight trunk from the junction east (dead end)
            { x = 12670, y = 4452, z = 0 },   -- junction (= s48.at)
            { x = 12788, y = 4452, z = 0 },
            { x = 12807, y = 4433, z = 0 },
            { x = 12807, y = 4385, z = 0, name = "freight_terminal_2_end", open = true },  -- torn-up open end -> derail at speed
        },
        freight_terminal_3 = {   -- Valley Station freight siding 3 (dead end, off the trunk)
            { x = 12695, y = 4452, z = 0 },   -- = s49.at, on freight_terminal_2
            { x = 12705, y = 4442, z = 0 },
            { x = 12705, y = 4367, z = 0, name = "freight_terminal_3_end", open = true },  -- torn-up open end -> derail at speed
        },
        freight_terminal_4 = {   -- Valley Station freight siding 4 (dead end, off the trunk)
            { x = 12723, y = 4452, z = 0 },   -- = s50.at, on freight_terminal_2
            { x = 12733, y = 4442, z = 0 },
            { x = 12733, y = 4369, z = 0, name = "freight_terminal_4_end", open = true },  -- torn-up open end -> derail at speed
        },
        freight_terminal_5 = {   -- Valley Station freight siding 5 (dead end, off the trunk)
            { x = 12757, y = 4452, z = 0 },   -- = s51.at, on freight_terminal_2
            { x = 12767, y = 4442, z = 0 },
            { x = 12767, y = 4369, z = 0, name = "freight_terminal_5_end", open = true },  -- torn-up open end -> derail at speed
        },
        irvington_branch_1 = {   -- Irvington stub 1 off the far-west main diagonal (dead end)
            { x = 2519, y = 14015, z = 0 },   -- = s52.at, on the main
            { x = 2571, y = 14015, z = 0, name = "irvington_branch_1_end" },  -- buffer stop
        },
        irvington_branch_2 = {   -- Irvington stub 2 off the far-west main diagonal (dead end)
            { x = 2512, y = 14008, z = 0 },   -- = s53.at, on the main
            { x = 2572, y = 14008, z = 0, name = "irvington_branch_2_end" },  -- buffer stop
        },
        -- (removed) brandenburg_freight_1: the freight-platform stub off the branch at
        -- (2301,6696) and its switch s54 (stand ~2302,6693) were dropped -- owner, 2026-07-29.
        -- The turnout SPRITE is vanilla map geometry and still stands there; it is simply not
        -- a working switch any more, so the branch runs straight through.
        -- Brandenburg freight terminal N2: a double-ended TURNING BALLOON off the branch.
        -- Two entries from the branch (s55 Ус1 westbound, s58 Ус2 eastbound) have leads to a
        -- throat (s59) that picks which ус an exiting/northbound train takes back. From the
        -- throat a short stem drops to the balloon throat (s56), where the loop is split into
        -- two halves rejoining at an invisible joint (s57) so the engine can drive the full
        -- loop and exit turned around. (A single self-closing loop edge can't: materialize
        -- indexes a switch once per edge, so the throat can't catch the loco on the way back
        -- out -- verified.)
        bft2_lead_1 = {   -- Ус1 lead: s55 (Brandenburg-bound) -> junction (s59)
            { x = 2227, y = 6696, z = 0 },   -- = s55.at, on brandenburg_branch
            { x = 2223, y = 6700, z = 0 },
            { x = 2223, y = 6701, z = 0 },   -- junction (= s59.at)
        },
        bft2_lead_2 = {   -- Ус2 lead: s58 (return / eastbound) -> junction (s59)
            { x = 2215, y = 6696, z = 0 },   -- = s58.at, on brandenburg_branch
            { x = 2223, y = 6701, z = 0 },   -- junction (= s59.at)
        },
        bft2_stem = {   -- stem from the Ус1/Ус2 junction (s59) down to the balloon throat (s56)
            { x = 2223, y = 6701, z = 0 },   -- junction (= s59.at)
            { x = 2223, y = 6708, z = 0 },   -- balloon throat (= s56.at)
        },
        bft2_loop_a = {   -- loop, south/west half: throat -> far joint (NORMAL / "south" from s56)
            { x = 2223, y = 6708, z = 0 },   -- throat (= s56.at)
            { x = 2223, y = 6762, z = 0 },
            { x = 2231, y = 6770, z = 0 },
            { x = 2253, y = 6770, z = 0 },
            { x = 2263, y = 6761, z = 0 },   -- far joint (= s57.at)
        },
        bft2_loop_b = {   -- loop, east half: far joint -> throat (REVERSE / "east" from s56)
            { x = 2263, y = 6761, z = 0 },   -- far joint (= s57.at)
            { x = 2263, y = 6726, z = 0 },
            { x = 2249, y = 6712, z = 0 },
            { x = 2224, y = 6712, z = 0 },
            { x = 2223, y = 6708, z = 0 },   -- throat (= s56.at)
        },
        -- Brandenburg Depot 1: a double-ended dead-end depot road off the branch. Two entries
        -- (s60 Ус1 westbound, s61 Ус2 eastbound) lead to a junction (s62) that picks which ус
        -- a train leaving the depot takes back to the branch. No balloon -- the depot road is a
        -- straight stub, so no far joint is needed.
        bd1_lead_1 = {   -- Ус1 lead: s60 (Brandenburg-bound) -> junction (s62)
            { x = 2193, y = 6696, z = 0 },   -- = s60.at, on brandenburg_branch
            { x = 2189, y = 6700, z = 0 },
            { x = 2189, y = 6701, z = 0 },
            { x = 2189, y = 6703, z = 0 },   -- junction (= s62.at)
        },
        bd1_lead_2 = {   -- Ус2 lead: s61 (return / eastbound) -> junction (s62)
            { x = 2181, y = 6696, z = 0 },   -- = s61.at, on brandenburg_branch
            { x = 2189, y = 6703, z = 0 },   -- junction (= s62.at)
        },
        brandenburg_depot_1 = {   -- the depot road itself: junction (s62) -> dead end
            { x = 2189, y = 6703, z = 0 },   -- junction (= s62.at)
            { x = 2189, y = 6767, z = 0, name = "brandenburg_depot_1_end", open = true },  -- torn-up open end -> derail at speed
        },
    },
    switches = {
        {
            id = "s1",
            at = { x = 12107, y = 8117, z = 0 },   -- moved 8115->8117 to match re-measured s1_lead start
            throat  = { edge = "main",    toward = "start" },   -- points toward the depot
            through = { edge = "main",    toward = "end"   },   -- NORMAL:  straight on (forward)
            diverge = { edge = "s1_lead", toward = "end"   },   -- REVERSE: onto the lead -> branch
        },
        {
            id = "s2",
            at = { x = 12107, y = 8103, z = 0 },
            throat  = { edge = "main",    toward = "end"   },   -- points toward the far end (faces a backward train)
            through = { edge = "main",    toward = "start" },   -- NORMAL:  straight on toward the depot
            diverge = { edge = "s2_lead", toward = "end"   },   -- REVERSE: onto the lead -> branch
        },
        {
            id = "s3",
            at = { x = 12098, y = 8109, z = 0 },                        -- Brandenburg Junction
            throat  = { edge = "brandenburg_branch", toward = "end"   },-- points to Brandenburg (west)
            through = { edge = "s2_lead",            toward = "start" },-- NORMAL:  straight -> S2 -> main away from depot
            diverge = { edge = "s1_lead",            toward = "start" },-- REVERSE: right    -> S1 -> main to depot
        },
        {
            id = "s4",   -- Muldraugh switch (bare fork -> we PLACE its turnout sprite; see `place`)
            at = { x = 12107, y = 9006, z = 0 },
            throat  = { edge = "main",             toward = "end"   },  -- faces trains heading TO the depot
            through = { edge = "main",             toward = "start" },  -- NORMAL:  continue toward the depot
            diverge = { edge = "muldraugh_branch", toward = "end"   },  -- REVERSE: onto the Muldraugh Branch
            -- No turnout on the map here yet: place the "Стрелка 1" sprite (industry_railroad_05_52)
            -- at the stand tile so the context menu can anchor on it (RR_SwitchPlace).
            place = { x = 12104, y = 9004, z = 0, sprite = "industry_railroad_05_52" },
        },
        {
            id = "s5",   -- Muldraugh MERGE: the loop rejoins the main on the clockwise section
            at = { x = 11902, y = 10644, z = 0 },
            throat  = { edge = "main",             toward = "start" },  -- faces NORTH-bound trains (coming up from the cw/south side)
            through = { edge = "main",             toward = "end"   },  -- NORMAL:  continue north on the main
            diverge = { edge = "muldraugh_branch", toward = "start" },  -- REVERSE: onto the Muldraugh loop (toward s4)
            -- "Стрелка 1" sprite placed at the stand tile so the menu can anchor (RR_SwitchPlace).
            place = { x = 11899, y = 10643, z = 0, sprite = "industry_railroad_05_52" },
        },
        {
            id = "s6",   -- Depot Siding 1 NORTH switch: diverts south-bound (toward-depot) trains onto the siding
            at = { x = 11645, y = 9620, z = 0 },   -- on the main (= siding_1 start)
            throat  = { edge = "main",           toward = "end"   },  -- faces trains heading SOUTH to the depot (coming from Louisville)
            through = { edge = "main",           toward = "start" },  -- NORMAL:  continue south to the depot
            diverge = { edge = "depot_siding_1", toward = "end"   },  -- REVERSE: onto the siding past the hangars
            place = { x = 11642, y = 9614, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s7",   -- Depot Siding 1 SOUTH switch: diverts north-bound (toward-depot) trains onto the siding
            at = { x = 11738, y = 10199, z = 0 },   -- = depot_siding_1 south end; snapped onto the main
            throat  = { edge = "main",           toward = "start" },  -- faces trains heading NORTH to the depot (from the cw/south side)
            through = { edge = "main",           toward = "end"   },  -- NORMAL:  continue north to the depot
            diverge = { edge = "depot_siding_1", toward = "start" },  -- REVERSE: onto the siding (toward s6)
            place = { x = 11741, y = 10198, z = 0, sprites = {   -- Стрелка 2: shifted 1 tile south (see s17)
                { sprite = "industry_railroad_05_54", dx = 0, dy = 1 },
                { sprite = "industry_railroad_05_55", dx = 0, dy = 0 },
            } },
        },
        {
            id = "s8",   -- depot_siding_1 -> depot_siding_2
            at = { x = 11738, y = 9850, z = 0 },
            throat  = { edge = "depot_siding_1", toward = "start" },  -- faces trains running DOWN siding_1 (in from s6)
            through = { edge = "depot_siding_1", toward = "end"   },  -- NORMAL:  stay on siding_1
            diverge = { edge = "depot_siding_2", toward = "end"   },  -- REVERSE: onto siding_2
            place = { x = 11735, y = 9847, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s9",   -- depot_siding_1 -> depot_siding_3
            at = { x = 11689, y = 9664, z = 0 },
            throat  = { edge = "depot_siding_1", toward = "start" },  -- faces trains running DOWN siding_1 (in from s6)
            through = { edge = "depot_siding_1", toward = "end"   },  -- NORMAL:  stay on siding_1
            diverge = { edge = "depot_siding_3", toward = "end"   },  -- REVERSE: onto siding_3
            place = { x = 11686, y = 9664, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s10",  -- depot_siding_2 -> depot_siding_3 (siding-to-siding, at their meeting point)
            at = { x = 11711, y = 9879, z = 0 },   -- = siding_2 mid = siding_3 end (all three coincide)
            throat  = { edge = "depot_siding_2", toward = "end"   },  -- faces NORTH-bound trains on siding_2 (in from the buffer end)
            through = { edge = "depot_siding_2", toward = "start" },  -- NORMAL:  keep on siding_2 north (-> s8 -> siding_1 -> main)
            diverge = { edge = "depot_siding_3", toward = "start" },  -- REVERSE: onto siding_3 (toward s9)
            place = { x = 11708, y = 9878, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s11",  -- main -> depot_siding_4 (north end)
            at = { x = 11645, y = 9623, z = 0 },
            throat  = { edge = "main",           toward = "end"   },  -- faces trains heading toward the depot (in from Louisville)
            through = { edge = "main",           toward = "start" },  -- NORMAL:  continue on the main toward the depot
            diverge = { edge = "depot_siding_4", toward = "end"   },  -- REVERSE: onto siding_4 (south)
            place = { x = 11642, y = 9621, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s12",  -- main (clockwise) -> depot_siding_4 (south end)
            at = { x = 11654, y = 10193, z = 0 },   -- = siding_4 south end, on the clockwise main
            throat  = { edge = "main",           toward = "start" },  -- faces trains heading toward the depot (up the clockwise leg)
            through = { edge = "main",           toward = "end"   },  -- NORMAL:  continue toward the depot
            diverge = { edge = "depot_siding_4", toward = "start" },  -- REVERSE: onto siding_4 (toward s11)
            place = { x = 11655, y = 10190, z = 0, sprites = {   -- Стрелка 2: shifted 1 tile south (see s17)
                { sprite = "industry_railroad_05_54", dx = 0, dy = 1 },
                { sprite = "industry_railroad_05_55", dx = 0, dy = 0 },
            } },
        },
        {
            id = "s13",  -- depot_siding_4 -> depot_siding_5
            at = { x = 11645, y = 9846, z = 0 },
            throat  = { edge = "depot_siding_4", toward = "start" },  -- faces trains running DOWN siding_4 (in from s11)
            through = { edge = "depot_siding_4", toward = "end"   },  -- NORMAL:  stay on siding_4
            diverge = { edge = "depot_siding_5", toward = "end"   },  -- REVERSE: onto siding_5
            place = { x = 11642, y = 9844, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s14",  -- main (into the depot) -> depot_siding_5
            at = { x = 11620, y = 9873, z = 0 },   -- the main node (= siding_5 end) -- coherence
            throat  = { edge = "main",           toward = "start" },  -- faces trains heading INTO the depot (up the clockwise leg)
            through = { edge = "main",           toward = "end"   },  -- NORMAL:  continue into the depot
            diverge = { edge = "depot_siding_5", toward = "start" },  -- REVERSE: onto siding_5 (toward s13)
            place = { x = 11617, y = 9872, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s15",  -- siding_4 (SOUTH-bound) -> hangar 1
            at = { x = 11645, y = 10024, z = 0 },
            throat  = { edge = "depot_siding_4",  toward = "start" },  -- faces SOUTH-bound trains on siding_4
            through = { edge = "depot_siding_4",  toward = "end"   },  -- NORMAL:  stay on siding_4
            diverge = { edge = "hangar_1_lead_a", toward = "end"   },  -- REVERSE: onto the hangar (south lead)
            place = { x = 11642, y = 10023, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s16",  -- siding_4 (NORTH-bound) -> hangar 1
            at = { x = 11645, y = 10030, z = 0 },
            throat  = { edge = "depot_siding_4",  toward = "end"   },  -- faces NORTH-bound trains on siding_4
            through = { edge = "depot_siding_4",  toward = "start" },  -- NORMAL:  stay on siding_4
            diverge = { edge = "hangar_1_lead_b", toward = "end"   },  -- REVERSE: onto the hangar (north lead)
            place = { x = 11642, y = 10029, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s17",  -- hangar 1 lead merge: from the shed, picks which lead (-> which siding_4 direction)
            at = { x = 11646, y = 10028, z = 0 },
            throat  = { edge = "hangar_1",        toward = "end"   },  -- faces trains coming OUT of the shed
            through = { edge = "hangar_1_lead_b", toward = "start" },  -- NORMAL:  first ус (north, -> s16)
            diverge = { edge = "hangar_1_lead_a", toward = "start" },  -- REVERSE: second ус (south, -> s15)
            -- Стрелка 2 (turnout = _54 + _55 pair). Shifted 1 tile SOUTH (dy+1) from the
            -- stand tile so the art lands where the physical switch is; menu anchors on the
            -- stand tile (11647,10025). (_55 stays 1 tile north of _54 -- the pair arrangement.)
            place = { x = 11647, y = 10025, z = 0, sprites = {
                { sprite = "industry_railroad_05_54", dx = 0, dy = 1 },
                { sprite = "industry_railroad_05_55", dx = 0, dy = 0 },
            } },
        },
        {
            id = "s18",  -- siding_4 (SOUTH-bound) -> hangar 2 (Ус 1)
            at = { x = 11645, y = 10099, z = 0 },
            throat  = { edge = "depot_siding_4",  toward = "start" },  -- faces SOUTH-bound trains on siding_4
            through = { edge = "depot_siding_4",  toward = "end"   },  -- NORMAL:  stay on siding_4
            diverge = { edge = "hangar_2_lead_a", toward = "end"   },  -- REVERSE: onto hangar 2 (south lead)
            place = { x = 11642, y = 10098, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s19",  -- siding_4 (NORTH-bound) -> hangar 2 (Ус 2)
            at = { x = 11645, y = 10105, z = 0 },
            throat  = { edge = "depot_siding_4",  toward = "end"   },  -- faces NORTH-bound trains on siding_4
            through = { edge = "depot_siding_4",  toward = "start" },  -- NORMAL:  stay on siding_4
            diverge = { edge = "hangar_2_lead_b", toward = "end"   },  -- REVERSE: onto hangar 2 (north lead)
            place = { x = 11642, y = 10104, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s20",  -- hangar 2 lead merge: from the shed, picks which lead (-> which siding_4 direction)
            at = { x = 11646, y = 10103, z = 0 },
            throat  = { edge = "hangar_2",        toward = "end"   },  -- faces trains coming OUT of the shed
            through = { edge = "hangar_2_lead_b", toward = "start" },  -- NORMAL:  Ус 2 (north, -> s19)
            diverge = { edge = "hangar_2_lead_a", toward = "start" },  -- REVERSE: Ус 1 (south, -> s18)
            place = { x = 11647, y = 10100, z = 0, sprites = {   -- Стрелка 2 (turnout _54+_55, +1 south)
                { sprite = "industry_railroad_05_54", dx = 0, dy = 1 },
                { sprite = "industry_railroad_05_55", dx = 0, dy = 0 },
            } },
        },
        {
            id = "s21",  -- main (SOUTH-bound) -> hangar 3 (Ус 1)
            at = { x = 11620, y = 10054, z = 0 },
            throat  = { edge = "main",            toward = "end"   },  -- faces SOUTH-bound trains (from the depot side)
            through = { edge = "main",            toward = "start" },  -- NORMAL:  stay on the main (south)
            diverge = { edge = "hangar_3_lead_a", toward = "end"   },  -- REVERSE: onto hangar 3 (south lead)
            place = { x = 11617, y = 10052, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s22",  -- main (NORTH-bound) -> hangar 3 (Ус 2)
            at = { x = 11620, y = 10058, z = 0 },
            throat  = { edge = "main",            toward = "start" },  -- faces NORTH-bound trains (up the clockwise leg)
            through = { edge = "main",            toward = "end"   },  -- NORMAL:  stay on the main (north)
            diverge = { edge = "hangar_3_lead_b", toward = "end"   },  -- REVERSE: onto hangar 3 (north lead)
            place = { x = 11617, y = 10059, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s23",  -- hangar 3 lead merge: from the shed, picks which lead (-> which main direction)
            at = { x = 11615, y = 10056, z = 0 },
            throat  = { edge = "hangar_3",        toward = "end"   },  -- faces trains coming OUT of the shed
            through = { edge = "hangar_3_lead_b", toward = "start" },  -- NORMAL:  Ус 2 (north, -> s22)
            diverge = { edge = "hangar_3_lead_a", toward = "start" },  -- REVERSE: Ус 1 (south, -> s21)
            place = { x = 11615, y = 10053, z = 0, sprites = {   -- Стрелка 2 (turnout _54+_55, +1 south)
                { sprite = "industry_railroad_05_54", dx = 0, dy = 1 },
                { sprite = "industry_railroad_05_55", dx = 0, dy = 0 },
            } },
        },
        {
            id = "s24",  -- main (SOUTH-bound) -> hangar 4 (Ус 1)
            at = { x = 11620, y = 10128, z = 0 },
            throat  = { edge = "main",            toward = "end"   },  -- faces SOUTH-bound trains (from the depot side)
            through = { edge = "main",            toward = "start" },  -- NORMAL:  stay on the main (south)
            diverge = { edge = "hangar_4_lead_a", toward = "end"   },  -- REVERSE: onto hangar 4 (south lead)
            place = { x = 11617, y = 10126, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s25",  -- main (NORTH-bound) -> hangar 4 (Ус 2)
            at = { x = 11620, y = 10132, z = 0 },
            throat  = { edge = "main",            toward = "start" },  -- faces NORTH-bound trains (up the clockwise leg)
            through = { edge = "main",            toward = "end"   },  -- NORMAL:  stay on the main (north)
            diverge = { edge = "hangar_4_lead_b", toward = "end"   },  -- REVERSE: onto hangar 4 (north lead)
            place = { x = 11617, y = 10133, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s26",  -- hangar 4 lead merge: from the shed, picks which lead (-> which main direction)
            at = { x = 11615, y = 10130, z = 0 },
            throat  = { edge = "hangar_4",        toward = "end"   },  -- faces trains coming OUT of the shed
            through = { edge = "hangar_4_lead_b", toward = "start" },  -- NORMAL:  Ус 2 (north, -> s25)
            diverge = { edge = "hangar_4_lead_a", toward = "start" },  -- REVERSE: Ус 1 (south, -> s24)
            place = { x = 11615, y = 10127, z = 0, sprites = {   -- Стрелка 2 (turnout _54+_55, +1 south)
                { sprite = "industry_railroad_05_54", dx = 0, dy = 1 },
                { sprite = "industry_railroad_05_55", dx = 0, dy = 0 },
            } },
        },
        {
            id = "s27",  -- main -> terminal loop (Louisville): terminal-bound trains enter here
            at = { x = 12697, y = 2663, z = 0 },
            throat  = { edge = "main",              toward = "start" },  -- faces terminal-bound trains (in from the depot)
            through = { edge = "main",              toward = "end"   },  -- NORMAL:  straight on to the Louisville dead-end
            diverge = { edge = "terminal_branch_1", toward = "end"   },  -- REVERSE: onto the terminal loop
            place = { x = 12703, y = 2660, z = 0, sprites = {   -- Стрелка 2 (turnout _54+_55, +1 south)
                { sprite = "industry_railroad_05_54", dx = 0, dy = 1 },
                { sprite = "industry_railroad_05_55", dx = 0, dy = 0 },
            } },
        },
        {
            id = "s28",  -- main -> terminal loop (Louisville): rejoin near the terminal (toward the depot)
            at = { x = 12765, y = 2340, z = 0 },
            throat  = { edge = "main",              toward = "start" },  -- faces trains heading to the terminal dead-end
            through = { edge = "main",              toward = "end"   },  -- NORMAL:  straight on to the Louisville dead-end
            diverge = { edge = "terminal_branch_1", toward = "start" },  -- REVERSE: onto the terminal loop (toward s27)
            place = { x = 12762, y = 2341, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s29",  -- main -> passenger platform 1 (Louisville terminal)
            at = { x = 12729, y = 2632, z = 0 },
            throat  = { edge = "main",                 toward = "start" },  -- faces terminal-bound trains (from the depot)
            through = { edge = "main",                 toward = "end"   },  -- NORMAL:  on to the Louisville dead-end
            diverge = { edge = "passenger_platform_1", toward = "end"   },  -- REVERSE: onto platform 1
            place = { x = 12726, y = 2628, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s30",  -- main -> passenger platform 2 (Louisville terminal)
            at = { x = 12738, y = 2623, z = 0 },
            throat  = { edge = "main",                 toward = "start" },  -- faces terminal-bound trains (platform goes NORTH, like platform 1)
            through = { edge = "main",                 toward = "end"   },  -- NORMAL:  on to the Louisville dead-end
            diverge = { edge = "passenger_platform_2", toward = "end"   },  -- REVERSE: onto platform 2
            place = { x = 12735, y = 2619, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s31",  -- main -> terminal_branch_2 (terminal-bound entry)
            at = { x = 12754, y = 2607, z = 0 },
            throat  = { edge = "main",              toward = "start" },  -- faces terminal-bound trains (from the depot)
            through = { edge = "main",              toward = "end"   },  -- NORMAL:  on to the Louisville dead-end
            diverge = { edge = "terminal_branch_2", toward = "end"   },  -- REVERSE: onto terminal_branch_2
            place = { x = 12751, y = 2603, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s32",  -- main -> terminal_branch_2 (depot-bound entry / branch rejoin)
            at = { x = 12765, y = 2474, z = 0 },
            throat  = { edge = "main",              toward = "end"   },  -- faces depot-bound trains (from Louisville)
            through = { edge = "main",              toward = "start" },  -- NORMAL:  on toward Muldraugh (depot)
            diverge = { edge = "terminal_branch_2", toward = "start" },  -- REVERSE: onto terminal_branch_2 (toward s31)
            place = { x = 12762, y = 2471, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s33",  -- terminal_branch_1 -> terminal_branch_3
            at = { x = 12810, y = 2626, z = 0 },
            throat  = { edge = "terminal_branch_1", toward = "start" },  -- faces NE-bound trains on terminal_branch_1
            through = { edge = "terminal_branch_1", toward = "end"   },  -- NORMAL:  stay on terminal_branch_1 (the loop)
            diverge = { edge = "terminal_branch_3", toward = "end"   },  -- REVERSE: onto terminal_branch_3
            place = { x = 12807, y = 2621, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s34",  -- main -> terminal_branch_3 (depot-bound entry / branch rejoin)
            at = { x = 12765, y = 2416, z = 0 },
            throat  = { edge = "main",              toward = "end"   },  -- faces depot-bound trains (from Louisville)
            through = { edge = "main",              toward = "start" },  -- NORMAL:  on toward Muldraugh (depot)
            diverge = { edge = "terminal_branch_3", toward = "start" },  -- REVERSE: onto terminal_branch_3 (toward s33)
            place = { x = 12762, y = 2411, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s35",  -- terminal_branch_1 -> terminal_branch_4 (chord to terminal_branch_3)
            at = { x = 12795, y = 2642, z = 0 },
            throat  = { edge = "terminal_branch_1", toward = "start" },  -- faces NE-bound trains on terminal_branch_1
            through = { edge = "terminal_branch_1", toward = "end"   },  -- NORMAL:  stay on terminal_branch_1 (the loop)
            diverge = { edge = "terminal_branch_4", toward = "end"   },  -- REVERSE: onto terminal_branch_4
            place = { x = 12792, y = 2637, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s36",  -- terminal_branch_3 -> terminal_branch_4
            at = { x = 12795, y = 2446, z = 0 },
            throat  = { edge = "terminal_branch_3", toward = "end"   },  -- faces SE-bound trains on terminal_branch_3
            through = { edge = "terminal_branch_3", toward = "start" },  -- NORMAL:  stay on terminal_branch_3
            diverge = { edge = "terminal_branch_4", toward = "start" },  -- REVERSE: onto terminal_branch_4 (toward s35)
            place = { x = 12792, y = 2447, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s37",  -- terminal_branch_1 -> terminal_branch_5 (chord to terminal_branch_3)
            at = { x = 12781, y = 2655, z = 0 },
            throat  = { edge = "terminal_branch_1", toward = "start" },  -- faces NE-bound trains on terminal_branch_1
            through = { edge = "terminal_branch_1", toward = "end"   },  -- NORMAL:  stay on terminal_branch_1 (the loop)
            diverge = { edge = "terminal_branch_5", toward = "end"   },  -- REVERSE: onto terminal_branch_5
            place = { x = 12778, y = 2651, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s38",  -- terminal_branch_3 -> terminal_branch_5
            at = { x = 12781, y = 2432, z = 0 },
            throat  = { edge = "terminal_branch_3", toward = "end"   },  -- faces SE-bound trains on terminal_branch_3
            through = { edge = "terminal_branch_3", toward = "start" },  -- NORMAL:  stay on terminal_branch_3
            diverge = { edge = "terminal_branch_5", toward = "start" },  -- REVERSE: onto terminal_branch_5 (toward s37)
            place = { x = 12778, y = 2432, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s39",  -- terminal_branch_1 -> terminal_branch_6 (passing bulge, north entry)
            at = { x = 12827, y = 2591, z = 0 },
            throat  = { edge = "terminal_branch_1", toward = "start" },  -- faces N-bound trains on terminal_branch_1
            through = { edge = "terminal_branch_1", toward = "end"   },  -- NORMAL:  stay on terminal_branch_1 (straight north)
            diverge = { edge = "terminal_branch_6", toward = "end"   },  -- REVERSE: onto the bulge (toward s40)
            place = { x = 12824, y = 2592, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s40",  -- terminal_branch_1 -> terminal_branch_6 (passing bulge, south entry)
            at = { x = 12827, y = 2454, z = 0 },
            throat  = { edge = "terminal_branch_1", toward = "end"   },  -- faces S-bound trains on terminal_branch_1
            through = { edge = "terminal_branch_1", toward = "start" },  -- NORMAL:  stay on terminal_branch_1 (straight south)
            diverge = { edge = "terminal_branch_6", toward = "start" },  -- REVERSE: onto the bulge (toward s39)
            place = { x = 12824, y = 2448, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s41",  -- terminal_branch_1 -> terminal_branch_7 (east loop-around, east entry)
            at = { x = 12812, y = 2316, z = 0 },
            throat  = { edge = "terminal_branch_1", toward = "end"   },  -- faces E-bound trains on terminal_branch_1
            through = { edge = "terminal_branch_1", toward = "start" },  -- NORMAL:  stay on terminal_branch_1 (curves NE up the loop)
            diverge = { edge = "terminal_branch_7", toward = "end"   },  -- REVERSE: onto terminal_branch_7 (toward s42)
            -- Стрелка 2 (turnout = _54 + _55 pair). Shifted 1 tile SOUTH (dy+1) from the stand tile.
            place = { x = 12809, y = 2313, z = 0, sprites = {
                { sprite = "industry_railroad_05_54", dx = 0, dy = 1 },
                { sprite = "industry_railroad_05_55", dx = 0, dy = 0 },
            } },
        },
        {
            id = "s42",  -- terminal_branch_1 -> terminal_branch_7 (east loop-around, south entry / rejoin)
            at = { x = 12827, y = 2430, z = 0 },
            throat  = { edge = "terminal_branch_1", toward = "end"   },  -- faces S-bound trains on terminal_branch_1
            through = { edge = "terminal_branch_1", toward = "start" },  -- NORMAL:  stay on terminal_branch_1 (straight south)
            diverge = { edge = "terminal_branch_7", toward = "start" },  -- REVERSE: onto terminal_branch_7 (toward s41)
            place = { x = 12824, y = 2425, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s43",  -- main -> terminal_branch_8 (dead-end spur)
            at = { x = 12765, y = 2311, z = 0 },
            throat  = { edge = "main",              toward = "start" },  -- faces N-bound trains (toward Louisville terminal)
            through = { edge = "main",              toward = "end"   },  -- NORMAL:  straight on toward the terminal
            diverge = { edge = "terminal_branch_8", toward = "end"   },  -- REVERSE: onto the spur (dead end)
            place = { x = 12762, y = 2312, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s44",  -- main -> freight_terminal_1 (Valley Station, Louisville-bound entry). Sprite ALREADY on the map.
            at = { x = 12665, y = 4478, z = 0 },
            throat  = { edge = "main",               toward = "start" },  -- faces Louisville-bound (N) trains
            through = { edge = "main",               toward = "end"   },  -- NORMAL:  straight on toward Louisville
            diverge = { edge = "freight_terminal_1", toward = "end"   },  -- REVERSE: onto the freight loop
            -- no `place`: a turnout sprite already exists on the map (stand ~12662,4478); the menu anchors on it.
        },
        {
            id = "s45",  -- main -> freight_terminal_1 (Valley Station, from-Louisville entry)
            at = { x = 12665, y = 4225, z = 0 },
            throat  = { edge = "main",               toward = "end"   },  -- faces from-Louisville (S) trains
            through = { edge = "main",               toward = "start" },  -- NORMAL:  straight on away from Louisville
            diverge = { edge = "freight_terminal_1", toward = "start" },  -- REVERSE: onto the freight loop (toward s44)
            place = { x = 12662, y = 4221, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s46",  -- main -> Ус1 lead (Valley Station freight, Louisville-bound entry). Sprite ALREADY on the map.
            at = { x = 12665, y = 4456, z = 0 },
            throat  = { edge = "main",       toward = "start" },  -- faces Louisville-bound (N) trains
            through = { edge = "main",       toward = "end"   },  -- NORMAL:  straight on toward Louisville
            diverge = { edge = "ft2_lead_1", toward = "end"   },  -- REVERSE: onto the Ус1 lead -> junction
            -- no `place`: a turnout sprite already exists on the map (stand ~12662,4458).
        },
        {
            id = "s47",  -- main -> Ус2 lead (Valley Station freight, from-Louisville entry)
            at = { x = 12665, y = 4444, z = 0 },
            throat  = { edge = "main",       toward = "end"   },  -- faces from-Louisville (S) trains
            through = { edge = "main",       toward = "start" },  -- NORMAL:  straight on away from Louisville
            diverge = { edge = "ft2_lead_2", toward = "end"   },  -- REVERSE: onto the Ус2 lead -> junction
            place = { x = 12662, y = 4441, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s48",  -- Valley Station freight junction: picks which ус a terminal-exiting train takes back. Sprite ALREADY on the map.
            at = { x = 12670, y = 4452, z = 0 },
            throat  = { edge = "freight_terminal_2", toward = "end"   },  -- points east into the terminal (faces exiting trains)
            through = { edge = "ft2_lead_1",         toward = "start" },  -- NORMAL:  Ус1 -> s46 -> main (Louisville-bound)
            diverge = { edge = "ft2_lead_2",         toward = "start" },  -- REVERSE: Ус2 -> s47 -> main (from-Louisville)
            -- no `place`: a turnout sprite already exists on the map (stand ~12671,4449).
        },
        {
            id = "s49",  -- freight_terminal_2 -> freight_terminal_3 (siding 3). Sprite ALREADY on the map.
            at = { x = 12695, y = 4452, z = 0 },
            throat  = { edge = "freight_terminal_2", toward = "start" },  -- faces E-bound trains on the trunk
            through = { edge = "freight_terminal_2", toward = "end"   },  -- NORMAL:  stay on the trunk (east)
            diverge = { edge = "freight_terminal_3", toward = "end"   },  -- REVERSE: onto siding 3 (dead end)
            -- no `place`: a turnout sprite already exists on the map (stand ~12692,4449).
        },
        {
            id = "s50",  -- freight_terminal_2 -> freight_terminal_4 (siding 4). Sprite ALREADY on the map.
            at = { x = 12723, y = 4452, z = 0 },
            throat  = { edge = "freight_terminal_2", toward = "start" },  -- faces E-bound trains on the trunk
            through = { edge = "freight_terminal_2", toward = "end"   },  -- NORMAL:  stay on the trunk (east)
            diverge = { edge = "freight_terminal_4", toward = "end"   },  -- REVERSE: onto siding 4 (dead end)
            -- no `place`: a turnout sprite already exists on the map (stand ~12719,4449).
        },
        {
            id = "s51",  -- freight_terminal_2 -> freight_terminal_5 (siding 5). Sprite ALREADY on the map.
            at = { x = 12757, y = 4452, z = 0 },
            throat  = { edge = "freight_terminal_2", toward = "start" },  -- faces E-bound trains on the trunk
            through = { edge = "freight_terminal_2", toward = "end"   },  -- NORMAL:  stay on the trunk (east)
            diverge = { edge = "freight_terminal_5", toward = "end"   },  -- REVERSE: onto siding 5 (dead end)
            -- no `place`: a turnout sprite already exists on the map (stand ~12754,4449).
        },
        {
            id = "s52",  -- main -> irvington_branch_1 (Irvington stub). Sprite ALREADY on the map.
            at = { x = 2519, y = 14015, z = 0 },
            throat  = { edge = "main",               toward = "start" },  -- faces depot-bound (SE) trains
            through = { edge = "main",               toward = "end"   },  -- NORMAL:  straight on toward the Muldraugh depot
            diverge = { edge = "irvington_branch_1", toward = "end"   },  -- REVERSE: onto the stub (dead end)
            -- no `place`: a turnout sprite already exists on the map (stand ~2523,14012).
        },
        {
            id = "s53",  -- main -> irvington_branch_2 (Irvington stub). Sprite ALREADY on the map.
            at = { x = 2512, y = 14008, z = 0 },
            throat  = { edge = "main",               toward = "start" },  -- faces depot-bound (SE) trains
            through = { edge = "main",               toward = "end"   },  -- NORMAL:  straight on toward the Muldraugh depot
            diverge = { edge = "irvington_branch_2", toward = "end"   },  -- REVERSE: onto the stub (dead end)
            -- no `place`: a turnout sprite already exists on the map (stand ~2516,14005).
        },
        -- (removed) s54 -- brandenburg_branch -> brandenburg_freight_1, at (2301,6696),
        -- stand ~(2302,6693). Dropped with its edge (owner, 2026-07-29); the vanilla turnout
        -- sprite stays on the map but no longer throws. Ids are not renumbered.
        {
            id = "s55",  -- brandenburg_branch -> Ус1 lead (terminal N2, westbound entry). Sprite ALREADY on the map.
            at = { x = 2227, y = 6696, z = 0 },
            throat  = { edge = "brandenburg_branch", toward = "start" },  -- faces westbound trains on the branch
            through = { edge = "brandenburg_branch", toward = "end"   },  -- NORMAL:  straight on west to Brandenburg
            diverge = { edge = "bft2_lead_1",        toward = "end"   },  -- REVERSE: onto the Ус1 lead -> junction
            -- no `place`: a turnout sprite already exists on the map (stand ~2227,6693).
        },
        {
            id = "s58",  -- brandenburg_branch -> Ус2 lead (terminal N2, eastbound entry). Sprite ALREADY on the map.
            at = { x = 2215, y = 6696, z = 0 },
            throat  = { edge = "brandenburg_branch", toward = "end"   },  -- faces eastbound trains on the branch
            through = { edge = "brandenburg_branch", toward = "start" },  -- NORMAL:  straight on east toward the junction
            diverge = { edge = "bft2_lead_2",        toward = "end"   },  -- REVERSE: onto the Ус2 lead -> junction
            -- no `place`: a turnout sprite already exists on the map (stand ~2214,6693).
        },
        {
            id = "s59",  -- terminal N2 Ус1/Ус2 junction: picks which ус a northbound (exiting) train takes back
            at = { x = 2223, y = 6701, z = 0 },
            throat  = { edge = "bft2_stem",   toward = "end"   },  -- points down to the balloon (faces exiting trains)
            through = { edge = "bft2_lead_1", toward = "start" },  -- NORMAL:  Ус1 -> s55 -> branch (west)
            diverge = { edge = "bft2_lead_2", toward = "start" },  -- REVERSE: Ус2 -> s58 -> branch (east)
            place = { x = 2220, y = 6702, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s56",  -- terminal N2 balloon throat: picks which way round the turning loop
            at = { x = 2223, y = 6708, z = 0 },
            throat  = { edge = "bft2_stem",   toward = "start" },  -- points up the stem (faces trains coming down from s59)
            through = { edge = "bft2_loop_a", toward = "end"   },  -- NORMAL:  south around the loop
            diverge = { edge = "bft2_loop_b", toward = "start" },  -- REVERSE: east around the loop
            place = { x = 2220, y = 6706, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
        {
            id = "s57",  -- terminal N2 balloon far joint (invisible: splits the loop so the engine can close it)
            at = { x = 2263, y = 6761, z = 0 },
            throat  = { edge = "bft2_loop_a", toward = "start" },  -- back toward the throat via the south half
            through = { edge = "bft2_loop_b", toward = "end"   },  -- onward around the east half to the throat
            diverge = { edge = "bft2_loop_b", toward = "end"   },  -- degenerate (same leg): a plain rail joint, not a real turnout
            -- no `place`: this is a structural joint, no sprite, no menu.
        },
        {
            id = "s60",  -- brandenburg_branch -> Ус1 lead (Depot 1, westbound entry). Sprite ALREADY on the map.
            at = { x = 2193, y = 6696, z = 0 },
            throat  = { edge = "brandenburg_branch", toward = "start" },  -- faces westbound trains on the branch
            through = { edge = "brandenburg_branch", toward = "end"   },  -- NORMAL:  straight on west to Brandenburg
            diverge = { edge = "bd1_lead_1",         toward = "end"   },  -- REVERSE: onto the Ус1 lead -> junction
            -- no `place`: a turnout sprite already exists on the map (stand ~2193,6693).
        },
        {
            id = "s61",  -- brandenburg_branch -> Ус2 lead (Depot 1, eastbound entry). Sprite ALREADY on the map.
            at = { x = 2181, y = 6696, z = 0 },
            throat  = { edge = "brandenburg_branch", toward = "end"   },  -- faces eastbound trains on the branch
            through = { edge = "brandenburg_branch", toward = "start" },  -- NORMAL:  straight on east toward the junction
            diverge = { edge = "bd1_lead_2",         toward = "end"   },  -- REVERSE: onto the Ус2 lead -> junction
            -- no `place`: a turnout sprite already exists on the map (stand ~2180,6693).
        },
        {
            id = "s62",  -- Depot 1 Ус1/Ус2 junction: picks which ус a train leaving the depot takes back
            at = { x = 2189, y = 6703, z = 0 },
            throat  = { edge = "brandenburg_depot_1", toward = "end"   },  -- points down the depot road (faces trains leaving it)
            through = { edge = "bd1_lead_1",          toward = "start" },  -- NORMAL:  Ус1 -> s60 -> branch (west)
            diverge = { edge = "bd1_lead_2",          toward = "start" },  -- REVERSE: Ус2 -> s61 -> branch (east)
            place = { x = 2186, y = 6703, z = 0, sprite = "industry_railroad_05_52" },  -- Стрелка 1
        },
    },
})

print("[Railroader] RR_RealRoutes.lua: loaded (registered routes: "
      .. tostring(#Routes.ids()) .. ")")
