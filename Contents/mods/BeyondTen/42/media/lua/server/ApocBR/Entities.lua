-- Server-only entity repositories. No SQL or JDBC objects cross this boundary.
if not isServer() then return end

ApocBREntities = ApocBREntities or {}
local API = ApocBREntities
if API._installed then return API end
API._installed = true

local pending = {}
local Entity = {}
Entity.__index = Entity

local function copy(values)
    local result = {}
    for key, value in pairs(values) do result[key] = value end
    return result
end

local function deliver(callback, result)
    local ok = pcall(callback, result)
    if not ok then print("[ApocBR/Entities] callback failed") end
end

local function bridge()
    if not ApocBRModEntities then error("Server entity bridge is unavailable") end
    return ApocBRModEntities
end

local function request(model, operation, keys, values, revision, callback)
    if type(callback) ~= "function" then error("Entity callback required") end
    local accepted = bridge().submit(model.name, operation, keys, values, revision)
    if not accepted.accepted then
        deliver(callback, { status = accepted.status })
        return false
    end
    pending[accepted.id] = callback
    return true
end

local function keysOf(entity)
    local result = {}
    for name, field in pairs(entity._model.fields) do
        if field.id then result[name] = entity._values[name] end
    end
    return result
end

function Entity:get(name)
    if not self._model.fields[name] then error("Unknown entity field") end
    return self._values[name]
end

function Entity:set(name, value)
    local field = self._model.fields[name]
    if not field then error("Unknown entity field") end
    if field.id then error("Entity IDs are immutable") end
    if value == nil then error("Entity fields are non-null") end
    if self._deleted then error("Entity was deleted") end
    if self._values[name] ~= value then
        self._values[name] = value
        self._generation = self._generation + 1
    end
    return self
end

function Entity:isDirty()
    return self._generation ~= self._savedGeneration
end

function Entity:getRevision()
    return self._revision -- Decimal string: no bigint precision loss through Lua numbers.
end

function Entity:save(callback)
    if type(callback) ~= "function" then error("Entity callback required") end
    if self._inFlight or self._deleted then error("Entity is busy or deleted") end
    self._inFlight = true
    local generation = self._generation
    local ok, accepted = pcall(request, self._model, "save", keysOf(self), copy(self._values), self._revision, function(result)
        self._inFlight = false
        if result.status == "OK" then
            self._revision = result.revision
            self._savedGeneration = generation
        end
        result.entity = self
        deliver(callback, result)
    end)
    if not ok then self._inFlight = false; error(accepted) end
    return accepted
end

function Entity:delete(callback)
    if type(callback) ~= "function" then error("Entity callback required") end
    if self._inFlight or self._deleted then error("Entity is busy or deleted") end
    self._inFlight = true
    local ok, accepted = pcall(request, self._model, "delete", keysOf(self), {}, self._revision, function(result)
        self._inFlight = false
        if result.status == "OK" then self._deleted = true end
        result.entity = self
        deliver(callback, result)
    end)
    if not ok then self._inFlight = false; error(accepted) end
    return accepted
end

local function instance(model, values, revision)
    return setmetatable({
        _model = model, _values = copy(values), _revision = revision or "0",
        _generation = 1, _savedGeneration = revision and 1 or 0,
    }, Entity)
end

function API.define(name, definition)
    local declaration = { table = definition.table, fields = {} }
    for field, spec in pairs(definition.fields) do declaration.fields[field] = copy(spec) end
    bridge().define(name, declaration)
    local model = { name = name, fields = declaration.fields }
    local repository = {}
    function repository:new(values)
        return instance(model, values)
    end
    function repository:validate(callback)
        return request(model, "validate", {}, {}, "0", callback)
    end
    function repository:find(keys, callback)
        if type(callback) ~= "function" then error("Entity callback required") end
        return request(model, "find", keys, {}, "0", function(result)
            if result.status == "OK" then result.entity = instance(model, result.values, result.revision) end
            deliver(callback, result)
        end)
    end
    return repository
end

-- Database completions must also be delivered while PauseEmpty pauses simulation.
-- IngameState fires this event on the server Lua thread before the pause check.
Events.OnTickEvenPaused.Add(function()
    if not ApocBRModEntities then return end
    for _, result in ipairs(ApocBRModEntities.poll()) do
        local callback = pending[result.id]
        pending[result.id] = nil
        if callback then deliver(callback, result) end
    end
end)

return API
