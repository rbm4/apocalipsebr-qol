local alertSystem = require "chuckleberryFinnModdingAlertSystem"
Events.OnMainMenuEnter.Add(function() alertSystem.display(true) end)
Events.OnLoad.Add(function() alertSystem.display(true) end)
--Events.OnResolutionChange.Add(alertSystem.onResolutionChange)