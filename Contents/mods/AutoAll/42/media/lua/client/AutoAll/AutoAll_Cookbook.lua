--[[
    Auto All - the cookbook (Build 42 / SP + MP)
    ------------------------------------------------------------------
    Saved Auto Cook plans, by name.

    > *Tourette:* "Is there any chance, that it would be possible, for
    > auto-cooking, to add 'recipes'? So that for example, wenn i make a
    > stir-fry and select the exact ingredients i want in there, i can
    > somehow write it down (maybe with a cook book and pen) and then
    > later easily recreate/share it, instead of every time selecting the
    > ingredients again? ... since TIS added Zombies to our SIMS game,
    > it's a bit of a hassle."

    A plan is the four things the setup window collects:

      recipeId   which dish
      goal       which of the four weightings the picker scores with
      maxItems   how many things go in before it stops
      limits     per ingredient type, how many of it may be used

    ------------------------------------------------------------------
    Where it is kept, and why not in ModData

    `Zomboid\Lua\AutoAll_Cookbook.txt`, through getFileWriter /
    getFileReader - the same pair the base game keeps layout.ini and
    emote.ini in.

    ModData was the obvious choice and is the wrong one here. Player mod
    data dies with the character; global mod data is per save and, on a
    server, belongs to the server. A cookbook that survives a death, a
    new save and a different world is what was asked for - and the last
    word in the request was **share**. A plain text file in a known
    folder can be sent to someone; a table inside a save file cannot.

    The format is one plan per line, deliberately readable:

        name|recipeId|goal|maxItems|Base.Tomato=2;Base.Butter=0

    A name is stripped of the two characters that would break that, and
    a line that does not parse is skipped rather than throwing - a
    hand-edited or hand-shared file must never stop the window opening.
]]

require "AutoAll/AutoAll_Core"

AutoAll = AutoAll or {}
local AA = AutoAll

if AA.cookbookLoaded then return end
AA.cookbookLoaded = true

AA.Cookbook = AA.Cookbook or {}
local Cookbook = AA.Cookbook

local FILE = "AutoAll_Cookbook.txt"

-- Someone will eventually paste a wall of text in as a name. This is
-- long enough for "Grandma's stir fry with everything" and short enough
-- to fit the combo box.
local MAX_NAME = 40

-- A guard on the file, not on anybody's cooking.
local MAX_PLANS = 200

---------------------------------------------------------------------
-- reading and writing
---------------------------------------------------------------------

--- Takes out the two characters the line format uses, and trims.
function Cookbook.cleanName(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("[|\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    if #name > MAX_NAME then name = name:sub(1, MAX_NAME) end
    return name
end

local function encodeLimits(limits)
    if not limits then return "" end

    -- Sorted, so saving the same plan twice produces the same line and a
    -- shared file diffs cleanly.
    local keys = {}
    for fullType in pairs(limits) do table.insert(keys, fullType) end
    table.sort(keys)

    local parts = {}
    for _, fullType in ipairs(keys) do
        local value = limits[fullType]
        if type(value) == "number" then
            table.insert(parts, fullType .. "=" .. tostring(math.floor(value)))
        end
    end
    return table.concat(parts, ";")
end

local function decodeLimits(text)
    local limits = {}
    if type(text) ~= "string" or text == "" then return limits end

    for part in text:gmatch("[^;]+") do
        local fullType, value = part:match("^([^=]+)=(%-?%d+)$")
        if fullType then limits[fullType] = tonumber(value) end
    end
    return limits
end

--- Every saved plan, in the order the file holds them.
---
--- Re-read on every call rather than held in memory: the file is the
--- point of the feature, and someone dropping a friend's cookbook into
--- the folder should see it the next time they open the window.
function Cookbook.list()
    local plans = {}

    local reader = getFileReader(FILE, true)
    if not reader then return plans end

    local line = reader:readLine()
    while line do
        -- Five fields, and the last one may legitimately be empty.
        local name, recipeId, goal, maxItems, limits =
            line:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")

        if name and name ~= "" and recipeId ~= "" then
            table.insert(plans, {
                name     = name,
                recipeId = recipeId,
                goal     = tonumber(goal) or 1,
                maxItems = tonumber(maxItems) or 0,
                limits   = decodeLimits(limits),
            })
        end

        if #plans >= MAX_PLANS then break end
        line = reader:readLine()
    end
    reader:close()

    return plans
end

local function writeAll(plans)
    local writer = getFileWriter(FILE, true, false)   -- create, overwrite
    if not writer then return false end

    for _, plan in ipairs(plans) do
        writer:write(table.concat({
            plan.name,
            plan.recipeId,
            tostring(plan.goal or 1),
            tostring(plan.maxItems or 0),
            encodeLimits(plan.limits),
        }, "|") .. "\r\n")
    end
    writer:close()
    return true
end

--- Saves a plan under a name, replacing one already using that name.
--- @return boolean saved
function Cookbook.save(name, plan)
    name = Cookbook.cleanName(name)
    if not name or not plan or not plan.recipeId then return false end

    local plans = Cookbook.list()

    local replaced = false
    for _, existing in ipairs(plans) do
        if existing.name == name then
            existing.recipeId = plan.recipeId
            existing.goal     = plan.goal
            existing.maxItems = plan.maxItems
            existing.limits   = plan.limits
            replaced = true
            break
        end
    end

    if not replaced then
        if #plans >= MAX_PLANS then return false end
        table.insert(plans, {
            name     = name,
            recipeId = plan.recipeId,
            goal     = plan.goal,
            maxItems = plan.maxItems,
            limits   = plan.limits,
        })
    end

    return writeAll(plans)
end

--- Forgets one plan by name.
function Cookbook.delete(name)
    if type(name) ~= "string" then return false end

    local plans = Cookbook.list()
    local kept = {}
    local removed = false

    for _, plan in ipairs(plans) do
        if plan.name == name then
            removed = true
        else
            table.insert(kept, plan)
        end
    end

    if not removed then return false end
    return writeAll(kept)
end

--- One plan by name, or nil.
function Cookbook.get(name)
    for _, plan in ipairs(Cookbook.list()) do
        if plan.name == name then return plan end
    end
    return nil
end
