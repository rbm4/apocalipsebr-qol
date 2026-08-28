if not Bicycle then Bicycle = {} end

Bicycle.SidecarRoomDefs = {
    ["storageunit"]    = 20,
    ["garage"]         = 10,
    ["garage_storage"] = 10,
    ["garagestorage"]  = 10,
    ["shed"]           = 5,
    ["woodshed"]       = 5,
}

Bicycle.SidecarSpiffoRoomDefs = {
    ["spiffosstorage"] = 10, -- Fixed Spiffo rate: ignores the SidecarSpawnRate sandbox slider (see SpawnSidecar.computeSpawnChance)
}

Bicycle.SidecarVariants = {
    "Bicycle.Bicycle_SidecarRed",
    "Bicycle.Bicycle_SidecarWhite",
    "Bicycle.Bicycle_SidecarPink",
    "Bicycle.Bicycle_SidecarBlack",
    "Bicycle.Bicycle_SidecarBlue",
}

Bicycle.SidecarSpiffoFullType = "Bicycle.Bicycle_SidecarSpiffo"

return Bicycle.SidecarRoomDefs
