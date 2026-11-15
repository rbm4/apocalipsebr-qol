
TableSawServerCommand = TableSawServerCommand or {}



function TableSawServerCommand.onClientCommand(_module, _command, _player, _args)
    if _module ~= "TableSaw" then return end
    if _command == 'PlaySound' then 
		sendServerCommand("TableSaw", "PlaySound", {x = _args.rx, y = _args.ry, z = _args.rz})
	elseif _command == 'StopPlaySound' then 
		sendServerCommand("TableSaw", "StopPlaySound", {x = _args.rx, y = _args.ry, z = _args.rz})
	end 
end

Events.OnClientCommand.Add(TableSawServerCommand.onClientCommand)
