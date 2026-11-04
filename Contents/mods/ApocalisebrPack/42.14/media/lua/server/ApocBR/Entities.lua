-- Server-only entity repositories. No SQL or JDBC objects cross this boundary.
if not isServer() then return end

ApocBREntities = ApocBREntities or {}
local API = ApocBREntities
if API._installed then return API end
API._installed = true

local pending = {}
local deferred = {}
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

-- This helper is server-only. The client command protocol never accepts these IDs.
function API.resolveCharacter(player, callback)
    if type(callback) ~= "function" then error("Entity callback required") end
    local result = bridge().character(player)
    deferred[#deferred + 1] = function() deliver(callback, result) end
end

function API.isCurrentCharacter(player, context)
    local current = bridge().character(player)
    return current.status == "OK" and current.session == context.session
        and current.characterId == context.characterId
end

-- Opaque Java capability; no character UUID supplied by Lua is trusted for append.
function API.messageContext(player)
    return bridge().messageContext(player)
end

function API.newMessageId()
    return bridge().newMessageId()
end

local function characterRequest(model, operation, player, context, rows, callback)
    if type(callback) ~= "function" then error("Entity callback required") end
    local accepted = bridge().submitCharacter(model.name, operation, player, context.session, rows)
    if not accepted.accepted then
        deliver(callback, { status = accepted.status })
        return false
    end
    pending[accepted.id] = function(result)
        if not API.isCurrentCharacter(player, context) then
            deliver(callback, { status = "STALE_SESSION" })
            return
        end
        deliver(callback, result)
    end
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
    if not self._snapshot then return true end
    for name in pairs(self._model.fields) do
        if self._values[name] ~= self._snapshot[name] then return true end
    end
    return false
end

function Entity:getRevision()
    return self._revision -- Decimal string: no bigint precision loss through Lua numbers.
end

function Entity:save(callback)
    if type(callback) ~= "function" then error("Entity callback required") end
    if self._inFlight or self._deleted then error("Entity is busy or deleted") end
    self._inFlight = true
    local generation = self._generation
    local captured = copy(self._values)
    local ok, accepted = pcall(request, self._model, "save", keysOf(self), captured, self._revision, function(result)
        self._inFlight = false
        if result.status == "OK" then
            self._revision = result.revision
            self._savedGeneration = generation
            self._snapshot = captured
        end
        result.entity = self
        deliver(callback, result)
    end)
    if not ok then self._inFlight = false; error(accepted) end
    return accepted
end

function Entity:patch(callback)
    if type(callback) ~= "function" then error("Entity callback required") end
    if self._inFlight or self._deleted then error("Entity is busy or deleted") end
    if self._revision == "0" then return self:save(callback) end
    local captured = copy(self._values)
    local changes = {}
    for name, spec in pairs(self._model.fields) do
        if not spec.id and captured[name] ~= self._snapshot[name] then changes[name] = captured[name] end
    end
    if next(changes) == nil then
        deliver(callback, { status = "OK", unchanged = true, revision = self._revision, entity = self })
        return true
    end
    self._inFlight = true
    local ok, accepted = pcall(request, self._model, "patch", keysOf(self), changes, self._revision, function(result)
        self._inFlight = false
        if result.status == "OK" then
            self._revision = result.revision
            self._snapshot = captured
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
        _snapshot = revision and copy(values) or nil,
        _generation = 1, _savedGeneration = revision and 1 or 0,
    }, Entity)
end

-- Length-prefixed composite keys avoid delimiter collisions without depending on a mod's IDs.
local function rowKey(model, values)
    local parts = {}
    for _, name in ipairs(model.keys) do
        local value = values[name]
        if value == nil then error("Entity ID required: " .. name) end
        local text = tostring(value)
        parts[#parts + 1] = type(value) .. ":" .. tostring(#text) .. ":" .. text
    end
    return table.concat(parts, "|")
end

local function checkedValues(model, values)
    local result = {}
    for name, value in pairs(values) do
        if not model.fields[name] then error("Unknown entity field") end
        if type(value) == "table" then error("Entity fields must be scalar") end
        result[name] = value
    end
    for name in pairs(model.fields) do if result[name] == nil then error("Entity field required: " .. name) end end
    return result
end

local CharacterSnapshot = {}
CharacterSnapshot.__index = CharacterSnapshot

function CharacterSnapshot:patch(player, context, rows, callback)
    if type(callback) ~= "function" then error("Entity callback required") end
    if self._inFlight then error("Character snapshot is busy") end
    if context.characterId ~= self._characterId then error("Character snapshot belongs to another life") end
    if not API.isCurrentCharacter(player, context) then
        deliver(callback, { status = "STALE_SESSION" })
        return false
    end
    local changes, captured, seen, observed = {}, {}, {}, {}
    local count = 0
    for key, row in pairs(self._previous) do
        count = count + 1
        observed[key] = { values = copy(row.values), revision = row.revision }
    end
    for index, row in ipairs(rows) do
        if index > 256 then error("Too many character rows") end
        if row.values.character_id ~= nil then error("Character ID is server managed") end
        local values = copy(row.values)
        values.character_id = self._characterId
        values = checkedValues(self._model, values)
        local key = rowKey(self._model, values)
        if seen[key] then error("Duplicate character row") end
        seen[key] = true
        local previous = self._previous[key]
        if not previous then count = count + 1 end
        if count > 256 then error("Too many character rows") end
        local delta, changed = {}, not previous
        for name, spec in pairs(self._model.fields) do
            if name ~= "character_id" then
                if spec.id then delta[name] = values[name]
                elseif not previous or previous.values[name] ~= values[name] then
                    delta[name] = values[name]
                    changed = true
                end
            end
        end
        observed[key] = { values = copy(values), revision = previous and previous.revision or "0" }
        if changed then
            changes[#changes + 1] = { values = delta, revision = previous and previous.revision or "0" }
            captured[key] = values
        end
    end
    self._current = observed
    if #changes == 0 then
        deliver(callback, { status = "OK", unchanged = true, rows = {} })
        return true
    end
    self._inFlight = true
    local ok, accepted = pcall(characterRequest, self._model, "patch", player, context, changes, function(result)
        self._inFlight = false
        if result.status == "OK" then
            -- Advance only acknowledged captured rows, never the caller's newer live values.
            local acknowledged = {}
            local valid = pcall(function()
                for _, row in ipairs(result.rows) do
                    local key = rowKey(self._model, row.values)
                    if not captured[key] or acknowledged[key] or type(row.revision) ~= "string" then
                        error("Invalid patch acknowledgement")
                    end
                    acknowledged[key] = { values = captured[key], revision = row.revision }
                end
                for key in pairs(captured) do if not acknowledged[key] then error("Missing patch acknowledgement") end end
            end)
            if not valid then result = { status = "INVALID_DATA" }
            else
                for key, row in pairs(acknowledged) do
                    self._previous[key] = row
                    self._current[key].revision = row.revision
                end
            end
        end
        deliver(callback, result)
    end)
    if not ok then self._inFlight = false; error(accepted) end
    return accepted
end

function API.define(name, definition)
    local declaration = { table = definition.table, appendOnly = definition.appendOnly == true, fields = {} }
    for field, spec in pairs(definition.fields) do declaration.fields[field] = copy(spec) end
    bridge().define(name, declaration)
    local model = { name = name, fields = declaration.fields, keys = {} }
    for field, spec in pairs(model.fields) do if spec.id then model.keys[#model.keys + 1] = field end end
    table.sort(model.keys)
    local repository = {}
    function repository:append(context, messageId, values, callback)
        if not declaration.appendOnly then error("Append-only mapping required") end
        if type(callback) ~= "function" then error("Entity callback required") end
        local accepted = bridge().append(model.name, context.token, messageId, copy(values))
        if not accepted.accepted then
            deliver(callback, { status = accepted.status })
            return false
        end
        pending[accepted.id] = callback
        return true
    end
    function repository:new(values)
        return instance(model, values)
    end
    function repository:validate(callback)
        return request(model, "validate", {}, {}, "0", callback)
    end
    function repository:loadOrCreateForCharacter(player, context, seeds, callback)
        return characterRequest(model, "loadOrCreate", player, context, seeds, callback)
    end
    function repository:saveAllForCharacter(player, context, rows, callback)
        return characterRequest(model, "saveAll", player, context, rows, callback)
    end
    function repository:characterSnapshot(rows)
        local previous, current, characterId = {}, {}, nil
        for index, row in ipairs(rows) do
            if index > 256 then error("Too many character rows") end
            local values = checkedValues(model, row.values)
            if not values.character_id or (characterId and characterId ~= values.character_id) then
                error("Character snapshot requires one character")
            end
            characterId = values.character_id
            if type(row.revision) ~= "string" or row.revision == "0" then error("Persisted revision required") end
            local key = rowKey(model, values)
            if previous[key] then error("Duplicate character row") end
            previous[key] = { values = values, revision = row.revision }
            current[key] = { values = copy(values), revision = row.revision }
        end
        if not characterId then error("Character snapshot requires persisted rows") end
        return setmetatable({ _model = model, _characterId = characterId,
            _previous = previous, _current = current }, CharacterSnapshot)
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
    local callbacks = deferred
    deferred = {}
    for _, callback in ipairs(callbacks) do callback() end
    if not ApocBRModEntities then return end
    for _, result in ipairs(ApocBRModEntities.poll()) do
        local callback = pending[result.id]
        pending[result.id] = nil
        if callback then deliver(callback, result) end
    end
end)

return API
