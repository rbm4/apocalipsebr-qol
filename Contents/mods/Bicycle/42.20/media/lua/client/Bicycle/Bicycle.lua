local BicycleDebug = require("Bicycle/Debug")
require("Bicycle/BicycleSyncClient")
require("Bicycle/TimedAction/BicycleAttachPartAction")
require("Bicycle/TimedAction/BicycleDetachPartAction")
require("Bicycle/TimedAction/BicycleStowAnimalAction")
require("Bicycle/TimedAction/BicycleReleaseAnimalAction")
local BicycleMenu = require("Bicycle/BicycleMenu")
require("Bicycle/ContextMenu/SidecarAnimalContextMenu")

BicycleDebug.log("client bootstrap loaded Bicycle.lua")

return BicycleMenu
