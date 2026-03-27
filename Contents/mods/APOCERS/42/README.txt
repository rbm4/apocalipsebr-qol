ERS FRAMEWORK – OPTION 2

===========================

This option documents the API contract for external mods.
ERS Core already exposes producer and battery registration through its API.

CORE PATH

Shared:

media/lua/shared/EnergyRouting/Registry.lua

media/lua/shared/EnergyRouting/API.lua

media/lua/shared/EnergyRouting/ProducerBase.lua

PUBLIC API

Require:

require "EnergyRouting/API"


Register producer:

EnergyRouting.API.RegisterProducer(def)

Recommended fields for def:

id (string, required, unique)

displayName (string, optional)

category (string: "solar" | "wind" | "hydro" | "other")

sortOrder (number, optional)

controllerListKey (string, optional if using CollectObjects)

idPrefix (string, optional if using CollectObjects)

IsObject(obj) -> bool (function, optional if using CollectObjects)

CollectObjects(self, controller, runtimeContext) -> {obj...} (optional)

CalculateOutput(obj, weatherSnapshot, networkContext, runtimeContext, def) -> watts (required)

OnFailure(obj, networkContext) (optional)

Register battery:

EnergyRouting.API.RegisterBattery(def)

Recommended battery fields:

id (string, required, unique)

displayName (string, optional)

sortOrder (number, optional)

capacity (number, optional)

GetCapacity(obj, def) -> number (optional, overrides capacity if defined)

FAILURE PROCESS

To execute producer-defined failures:

EnergyRouting.ProcessFailure(producerObject, networkContext)

RUNTIME CONTEXT (CalculateOutput)
weatherSnapshot:

label

multiplier (if applicable)

networkContext:

id (network id)

controller (controller table)

runtimeContext:

solarEfficiency

solarNetworkBonus

solarBonusPercent

windWeather

windNetworkBonus

windBonusPercent

weatherSnapshot

network

COMPATIBILITY NOTES

ERS keeps the following core producers registered:

core_solar_panel

core_wind_turbine

core_hydro_turbine

ERS keeps the following core batteries registered:

core_solar_battery

core_wind_battery

External module production is accumulated into:

otherProduction

otherCount

MINIMAL EXAMPLE (EXTERNAL PRODUCER)
require "EnergyRouting/API"

EnergyRouting.API.RegisterProducer({
    id = "mini_reactor_mk1",
    displayName = "Mini Reactor",
    category = "other",
    sortOrder = 200,

    CollectObjects = function(self, controller, runtimeContext)
        -- Return world objects belonging to this producer
        return {}
    end,

    CalculateOutput = function(obj, weather, network, runtimeContext, def)
        -- Return watts (number >= 0)
        return 2500
    end,

    OnFailure = function(obj, network)
        -- Optional failure event
    end,
})
