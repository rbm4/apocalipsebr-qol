--[[
    This file is part of that DAMN Library (Workshop ID 3171167894) authored by KI5 / bikinihorst.
    No permission is given for redistribution, repacking or modifying this or other files contained within the named
    workshop item, regardless of visibility or target community size, except if explicitly allowed by the author.
    TIS / Steam modding policy: https://projectzomboid.com/blog/modding-policy/
    This mod is "On Lockdown": https://theindiestone.com/forums/index.php?/topic/2530-mod-permissions/#findComment-36479
]]--

DAMN = DAMN or {};

-- arrays

function DAMN:itemIsInArray(array, searchItem)
    for i, item in ipairs(array)
    do
        if string.trim(tostring(item)) == string.trim(tostring(searchItem))
        then
            return true;
        end
    end

    return false;
end

function DAMN:tableIfNotTable(var)
	if type(var) ~= "table"
	then
		return {
			var
		};
	end

	return var;
end

function DAMN:pickRandomItemFromArray(array)
	return array[ZombRandBetween(1, #array + 1)];
end

function DAMN:arrayIsEmpty(array)
    for k, v in pairs(array or {})
    do
        return false;
    end

    return true;
end

-- strings

function DAMN:escapeString(srcString)
	return srcString:gsub("([^%w])", "%%%1");
end

function DAMN:splitString(srcString, separator, convertTo)
    local fragments = {};

    for fragment in srcString:gmatch("([^" .. separator .. "]+)")
    do
        if convertTo == "number"
        then
            fragment = tonumber(fragment);
        end

        table.insert(fragments, fragment);
    end

    return fragments;
end

-- file handling

function DAMN:getFileNameFallback(fileName)
	local fragments = DAMN:splitString(fileName, "/");
	local newFile = table.remove(fragments) or fileName;
	local badStuff = {
		"<", ">", ":", "'", "/", "\\", "|", "?", "*", "%", ".."
	};

	for i, chr in ipairs(badStuff)
	do
		newFile = string.gsub(newFile, DAMN:escapeString(chr), chr == ".."
			and "."
			or "_"
		);
	end

	table.insert(fragments, newFile);

	return table.concat(fragments, "/");
end

function DAMN:getFileWriter(fileName, param1, param2)
    fileName = string.gsub(fileName, "%{timestamp%}", Calendar.getInstance():getTimeInMillis());
	fileName = string.gsub(fileName, "%.%.", ".");

	local file = getFileWriter(fileName, param1, param2);

	if not file or not file["write"]
    then
        file = getFileWriter(DAMN:getFileNameFallback(fileName), param1, param2);
    end

	if not file or not file["write"]
    then
        DAMN:appendLineToFile("damn_errors.log", string.format("Unable to create file [%s]", fileName));

		return false;
	end

	return file;
end

function DAMN:appendLineToFile(fileName, line)
	local file = DAMN:getFileWriter(fileName, true, true);

	if not file
	then
		return;
	end

    for i, line in ipairs(DAMN:tableIfNotTable(line))
    do
        if type(line) ~= "function" and type(line) ~= "table"
        then
            file:write(tostring(line) .. "\n");
        end
    end

    file:close();
end

-- logging

function DAMN:printList(list, tpl)
    for i, item in ipairs(list)
    do
        DAMN:log(string.format(tpl or "%s", tostring(item)));
    end
end

function DAMN:log(message)
    if getDebug()
    then
        DAMN:appendLineToFile("that_damn_" .. (isServer()
			and "server"
			or "client"
		) .. ".log", message);
    end
end

function DAMN:pruneLog()
	local file = DAMN:getFileWriter("that_damn_" .. (isServer()
		and "server"
		or "client"
	) .. ".log", true, false);

	if not file
	then
		return;
	end

	file:write("Starting that DAMN log: " .. tostring(Calendar.getInstance():getTime()) .. "\n");
	file:write(" - isClient() = " .. tostring(isClient()) .. " / isServer() = " .. tostring(isServer()) .. "\n");
	file:close();
end

function DAMN:logArray(array, indent, path)
	indent = indent or "";
	path = path or "";

	for k, v in pairs(array)
	do
		if type(v) == "table"
		then
			DAMN:log(string.format("%s - (%s) %s%s:", indent, type(v), path, tostring(k)));
			DAMN:logArray(v, "   " .. indent, string.format("%s%s.", path, k));
		elseif type(v) == "function"
		then
			DAMN:log(string.format("%s - (%s) %s%s", indent, type(v), path, tostring(k)));
		else
			DAMN:log(string.format("%s - (%s) %s%s = %s", indent, type(v), path, tostring(k), tostring(v)));
		end
	end
end