local alertSystem = require "chuckleberryFinnModdingAlertSystem"
Events.OnMainMenuEnter.Add(function() alertSystem.display(true) end)