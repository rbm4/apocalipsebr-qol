require "EURY_TA_Tag"

local DEBUG = getCore():getDebug()

local function enabled()
    return DEBUG
end

Events.OnServerCommand.Add(function(module, command, args)
    if not enabled() then return end
    --if not (args and args.traceId) then return end

    EURY_TA.log("cmd module=" .. tostring(module)
        .. " command=" .. tostring(command)
        --.. " id=" .. tostring(args.traceId)
        --.. " tag=" .. tostring(args.traceTag))
        .. " args=" .. EURY_TA.buildArgString(args))
end)
