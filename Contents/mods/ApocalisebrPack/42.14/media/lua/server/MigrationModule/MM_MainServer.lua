-- Authenticated vehicle migration jobs stored in the game-runtime database.
require "ApocBR/Entities"
local Entities = ApocBREntities

local DEFAULT_Z = 0
local DEFAULT_DIR = IsoDirections.S
local MAX_PAYLOAD_LENGTH = 131072
local MAX_ITEM_ROWS = 2048
local CELL_TIMEOUT_MS = 30000
local RETRY_DELAY_MS = 5000
local MAX_DB_ATTEMPTS = 4
local MAX_QUEUED_JOBS = 32

local function log(message)
    print("[MigrationModule] " .. message)
end

--- Build a lookup table of part containers: { [partId] = ItemContainer }
--- @param vehicle IsoVehicle
--- @return table containers
local function buildContainerMap(vehicle)
    local containers = {}
    local partCount = vehicle:getPartCount()
    for i = 0, partCount - 1 do
        local part = vehicle:getPartByIndex(i)
        if part then
            local container = part:getItemContainer()
            if container then
                local partId = part:getId()
                if partId then
                    containers[partId] = container
                end
            end
        end
    end
    return containers
end

--- Get the first available ItemContainer from a vehicle (for key placement)
--- @param containers table The container map from buildContainerMap
--- @return ItemContainer|nil
local function getFirstContainer(containers)
    -- Prefer GloveBox > SeatFrontRight > any other
    local preferred = { "GloveBox", "SeatFrontRight", "SeatFrontLeft", "TruckBed" }
    for _, partId in ipairs(preferred) do
        if containers[partId] then
            return containers[partId]
        end
    end
    -- Fallback: return whatever is first
    for _, container in pairs(containers) do
        return container
    end
    return nil
end

-----------------------------------------------------------
-- Vehicle Preparation (clear loot + fill gas)
-----------------------------------------------------------

--- Clear all default items from every container and fill the gas tank
--- so the migrated vehicle is ready to drive with only the player's items.
--- @param vehicle BaseVehicle
--- @param containers table Container map from buildContainerMap
local function prepareVehicle(vehicle, containers)
    -- Clear all containers so the spawned default loot doesn't conflict with migrated items
    do
        local clearedCount = 0
        for _, container in pairs(containers) do
            local itemCount = container:getItems():size()
            if itemCount > 0 then
                container:removeAllItems()
                if container:getItems():size() ~= 0 then
                    error("Could not clear default vehicle cargo")
                end
                clearedCount = clearedCount + itemCount
            end
        end
        if clearedCount > 0 then
            log("Cleared " .. clearedCount .. " default items from all containers")
        end
    end

    -- Fill gas tank to full so the player can use the vehicle immediately
    pcall(function()
        local tank = vehicle:getPartById("GasTank")
        if tank then
            local capacity = tank:getContainerCapacity()
            if capacity and capacity > 0 then
                tank:setContainerContentAmount(capacity)
                vehicle:transmitPartCondition(tank)
                log("Filled gas tank to " .. tostring(capacity) .. "L")
            end
        end
    end)

    -- Unlock all doors and trunk so the player can access the vehicle immediately
    pcall(function()
        local unlockedCount = 0
        local partCount = vehicle:getPartCount()
        for i = 0, partCount - 1 do
            local part = vehicle:getPartByIndex(i)
            if part then
                local door = part:getDoor()
                if door and door:isLocked() then
                    door:setLocked(false)
                    unlockedCount = unlockedCount + 1
                end
            end
        end
        if unlockedCount > 0 then
            log("Unlocked " .. unlockedCount .. " doors/trunk")
        end
    end)

    -- Set all vehicle parts to 100% condition so the vehicle is in perfect shape
    pcall(function()
        local repairedCount = 0
        local partCount = vehicle:getPartCount()
        for i = 0, partCount - 1 do
            local part = vehicle:getPartByIndex(i)
            if part then
                local condition = part:getCondition()
                if condition < 100 then
                    part:setCondition(100)
                    vehicle:transmitPartCondition(part)
                    repairedCount = repairedCount + 1
                end
            end
        end
        if repairedCount > 0 then
            log("Repaired " .. repairedCount .. " parts to 100% condition")
        end
    end)
end

-----------------------------------------------------------
-- Missing Parts Installation
-----------------------------------------------------------

--- Install all missing parts defined in the vehicle script.
--- Some modded vehicles define parts (e.g. roof racks, extra containers) that
--- may not have their inventory items installed after addVehicleDebug.
--- This ensures every part slot is populated so its container is available.
--- Must be called BEFORE buildContainerMap so new containers are included.
--- @param vehicle IsoVehicle
local function installMissingParts(vehicle)
    local ok, err = pcall(function()
        local installedCount = 0
        local partCount = vehicle:getPartCount()
        for i = 0, partCount - 1 do
            local part = vehicle:getPartByIndex(i)
            if part and not part:getInventoryItem() then
                -- getItemType() returns a Java ArrayList<String>, not a plain string
                local itemTypes = part:getItemType()
                if itemTypes and not itemTypes:isEmpty() then
                    local itemType = itemTypes:get(0)
                    if itemType and itemType ~= "" then
                        -- Validate the item exists in script definitions before creating
                        local scriptItem = ScriptManager.instance:FindItem(itemType)
                        if scriptItem then
                            local item = instanceItem(itemType)
                            if item then
                                item:setCondition(item:getConditionMax())
                                part:setInventoryItem(item)
                                vehicle:transmitPartItem(part)

                                local installTable = part:getTable("install")
                                if installTable and installTable.complete then
                                    VehicleUtils.callLua(installTable.complete, vehicle, part)
                                end

                                part:setCondition(100)
                                vehicle:transmitPartCondition(part)
                                vehicle:transmitPartModData(part)
                                installedCount = installedCount + 1
                            end
                        else
                            log("WARNING: Item type '" .. tostring(itemType) .. "' for part '" .. (part:getId() or "?") .. "' not found in script definitions, skipping")
                        end
                    end
                end
            end
        end
        if installedCount > 0 then
            log("Installed " .. installedCount .. " missing parts on vehicle")
        end
    end)

    if not ok then
        log("ERROR: Failed to install missing parts: " .. tostring(err))
    end
end

local function getFullArmorModel(vehicle, part)
    if type(ATA2TuningTable) ~= "table" then
        return nil
    end

    local vehicleTable = ATA2TuningTable[vehicle:getScript():getName()]
    local partTable = vehicleTable and vehicleTable.parts and vehicleTable.parts[part:getId()]
    if not partTable then
        return nil
    end

    local selectedModel = nil
    local selectedStrength = nil
    for modelName, modelInfo in pairs(partTable) do
        if type(modelInfo) == "table" and modelInfo.protection then
            local strength = tonumber(modelInfo.protectionHealthDelta) or 0
            if not selectedModel or strength > selectedStrength or
                    (strength == selectedStrength and tostring(modelName) > tostring(selectedModel)) then
                selectedModel = modelName
                selectedStrength = strength
            end
        end
    end
    return selectedModel
end

local function installFullArmor(vehicle)
    if type(ATA2Commands) ~= "table" or type(ATA2Commands.installTuning) ~= "function" then
        return
    end

    local ok, err = pcall(function()
        local installedCount = 0
        for i = 0, vehicle:getPartCount() - 1 do
            local part = vehicle:getPartByIndex(i)
            local modelName = part and getFullArmorModel(vehicle, part)
            if modelName then
                local tuningData = part:getModData().tuning2
                local currentModel = tuningData and tuningData.model
                if not part:getInventoryItem() or currentModel ~= modelName then
                    if part:getInventoryItem() and currentModel and
                            type(ATA2Commands.uninstallTuning) == "function" then
                        ATA2Commands.uninstallTuning(vehicle, part, currentModel, nil)
                    end
                    ATA2Commands.installTuning(vehicle, part, modelName, 100)
                    if part:getInventoryItem() then
                        installedCount = installedCount + 1
                    end
                end
            end
        end
        if installedCount > 0 then
            log("Installed or upgraded " .. installedCount .. " TsarLib armor parts to full armor")
        end
    end)

    if not ok then
        log("ERROR: Failed to install full TsarLib armor: " .. tostring(err))
    end
end

local function validCoordinate(value)
    return type(value) == "number" and value >= 0 and value <= 1000000
end

local function validateEntry(entry)
    if type(entry) ~= "table" or type(entry.scriptName) ~= "string" or entry.scriptName == "" or
            not ScriptManager.instance:getVehicle(entry.scriptName) then
        error("Unknown or missing vehicle script")
    end
    if not validCoordinate(entry.x) or not validCoordinate(entry.y) then
        error("Invalid destination coordinates")
    end
    if entry.createKey ~= nil and type(entry.createKey) ~= "boolean" then
        error("createKey must be a boolean")
    end

    if entry.items == nil then
        entry.items = {}
    elseif type(entry.items) ~= "table" then
        error("items must be an array")
    end
    local size = #entry.items
    if size > MAX_ITEM_ROWS then
        error("Too many cargo rows")
    end
    local rows = 0
    for index, item in pairs(entry.items) do
        if type(index) ~= "number" or index < 1 or index > size or index ~= math.floor(index) then
            error("items must be a dense array")
        end
        if type(item) ~= "table" or type(item.fullType) ~= "string" or item.fullType == "" or
                type(item.container) ~= "string" or item.container == "" then
            error("Invalid cargo row " .. index)
        end
        local count = item.count
        if count ~= nil and (type(count) ~= "number" or count < 1 or count > 2147483647 or
                count ~= math.floor(count)) then
            error("Invalid quantity in cargo row " .. index)
        end
        rows = rows + 1
    end
    if rows ~= size then
        error("items must be a dense array")
    end
end

local function spawnMigration(job, square)
    local entry = job.entry
    local vehicle = addVehicleDebug(entry.scriptName, DEFAULT_DIR, nil, square)
    if not vehicle or not vehicle:getSquare() or vehicle:getSqlId() < 0 then
        error("Engine did not register the spawned vehicle")
    end
    job.vehicleId = vehicle:getSqlId()

    installMissingParts(vehicle)
    installFullArmor(vehicle)
    local containers = buildContainerMap(vehicle)
    local keyContainer = entry.createKey ~= false and getFirstContainer(containers)
    if entry.createKey ~= false and not keyContainer then
        error("No container available for the vehicle key")
    end
    local options = SandboxVars and SandboxVars.APOCALISEBR_PACK
    local restoreCargo = not options or options.EnableMigrationItemGeneration ~= false
    if restoreCargo then
        for _, item in ipairs(entry.items) do
            if not containers[item.container] then
                error("Missing vehicle container: " .. item.container)
            end
        end
    end
    prepareVehicle(vehicle, containers)
    if restoreCargo then
        for _, item in ipairs(entry.items) do
            local instance = instanceItem(item.fullType)
            if not instance then
                error("Could not create cargo item: " .. item.fullType)
            end
            local count = item.count or 1
            instance:setCount(count)
            if containers[item.container]:AddItem(instance) ~= instance or instance:getCount() ~= count then
                error("Could not place cargo item: " .. item.fullType)
            end
        end
    end
    if keyContainer then
        local key = vehicle:createVehicleKey()
        if not key or keyContainer:AddItem(key) ~= key then
            error("Could not place the vehicle key")
        end
    end
    return restoreCargo or #entry.items == 0
end

local repository, scope
local waiting, queued = {}, {}
local current
local startupAttempts = 0
local startupAt
local onTick
local tickSubscribed = false

local function subscribeTick()
    if tickSubscribed then return end
    Events.OnTickEvenPaused.Add(onTick)
    tickSubscribed = true
end

local function finish(job)
    queued[job.id] = nil
    current = nil
end

local function enqueue(id, entity)
    if queued[id] then return end
    if #waiting + (current and 1 or 0) >= MAX_QUEUED_JOBS then
        log("Queue full. Job " .. id .. " remains in PostgreSQL.")
        return
    end
    queued[id] = true
    table.insert(waiting, { id = id, entity = entity })
    subscribeTick()
end

local function setOutcome(job, status, detail, cargoRestored)
    job.entity:set("status", status)
    job.entity:set("detail", string.sub(detail, 1, 512))
    job.entity:set("vehicle_id", job.vehicleId or -1)
    job.entity:set("cargo_restored", cargoRestored == true)
    job.phase = "record_outcome"
    job.attempts = 0
end

local function recordOutcome(job, now)
    job.attempts = job.attempts + 1
    job.phase = "writing_outcome"
    job.entity:patch(function(result)
        if result.status == "OK" then
            log("Job " .. job.id .. " recorded as " .. job.entity:get("status"))
            finish(job)
        elseif result.status ~= "CONFLICT" and job.attempts < MAX_DB_ATTEMPTS then
            job.phase = "record_outcome"
            job.retryAt = now + RETRY_DELAY_MS
        else
            log("Job " .. job.id .. " outcome could not be recorded (" .. result.status .. "). Review before replay.")
            finish(job)
        end
    end)
end

local function prepareJob(job, now)
    local status = job.entity:get("status")
    if status ~= "pending" then
        if status == "applying" then
            log("Job " .. job.id .. " was interrupted during application. Review before replay.")
        end
        finish(job)
        return
    end
    local ok, entry = pcall(function()
        local payload = job.entity:get("payload")
        if #payload > MAX_PAYLOAD_LENGTH then error("Payload is too large") end
        local decoded = Entities.decode(payload)
        validateEntry(decoded)
        local options = SandboxVars and SandboxVars.APOCALISEBR_PACK
        if not options or options.EnableMigrationItemGeneration ~= false then
            for _, item in ipairs(decoded.items) do
                if not ScriptManager.instance:FindItem(item.fullType) then
                    error("Unknown cargo item: " .. item.fullType)
                end
            end
        end
        return decoded
    end)
    if not ok then
        setOutcome(job, "review_required", tostring(entry))
        return
    end
    job.entry = entry
    job.deadline = now + CELL_TIMEOUT_MS
    job.phase = "waiting_for_cell"
end

-- Claim before entering any native spawn code. A lost claim response leaves an
-- applying row for review, so the next startup cannot accidentally spawn twice.
local function claim(job)
    job.phase = "claiming"
    job.entity:set("status", "applying")
    job.entity:patch(function(result)
        if result.status == "OK" then
            job.claimed = true
            job.deadline = getTimestampMs() + CELL_TIMEOUT_MS
            job.phase = "waiting_for_cell"
        else
            log("Job " .. job.id .. " could not be claimed (" .. result.status .. ")")
            finish(job)
        end
    end)
end

local function waitForCell(job, now)
    local x, y = math.floor(job.entry.x), math.floor(job.entry.y)
    local status = ApocBRLobbyStreaming.keepCellLoaded(x, y)
    if status < 0 then
        setOutcome(job, "review_required", "Invalid destination cell")
        return
    end
    local square = status == 1 and getCell():getGridSquare(x, y, DEFAULT_Z)
    if not square then
        if now >= job.deadline then
            if job.claimed then
                setOutcome(job, "pending", "Destination cell load timed out before spawn")
            else
                log("Job " .. job.id .. " is still pending after destination cell load timeout")
                finish(job)
            end
        end
        return
    end
    if not job.claimed then
        claim(job)
        return
    end
    local ok, result = pcall(spawnMigration, job, square)
    if ok then
        local detail = result and "Vehicle delivery finished" or "Vehicle delivery finished with cargo disabled by sandbox"
        setOutcome(job, "delivered", detail, result)
    else
        setOutcome(job, "review_required", tostring(result))
    end
end

local function recoverJobs()
    startupAttempts = startupAttempts + 1
    startupAt = nil
    repository:listForServer(function(result)
        if result.status ~= "OK" then
            log("Startup recovery query failed (" .. result.status .. ")")
            if startupAttempts < MAX_DB_ATTEMPTS then
                startupAt = getTimestampMs() + RETRY_DELAY_MS
                subscribeTick()
            end
            return
        end
        for _, entity in ipairs(result.entities) do
            local id = entity:get("job_id")
            local status = entity:get("status")
            if status == "pending" then
                enqueue(id, entity)
            elseif status == "applying" then
                log("Job " .. id .. " was interrupted during application. Review before replay.")
            end
        end
    end)
end

local function advanceJob(job, now)
    if not job.phase then
        job.phase = "finding"
        if job.entity then
            prepareJob(job, now)
        else
            repository:find({ server_id = scope.server_id, world = scope.world, job_id = job.id }, function(result)
                if result.status == "OK" then
                    job.entity = result.entity
                    prepareJob(job, getTimestampMs())
                else
                    log("Job " .. job.id .. " lookup returned " .. result.status)
                    finish(job)
                end
            end)
        end
    elseif job.phase == "waiting_for_cell" then
        waitForCell(job, now)
    elseif job.phase == "record_outcome" and (not job.retryAt or now >= job.retryAt) then
        recordOutcome(job, now)
    end
end

onTick = function()
    local now = getTimestampMs()
    if startupAt and now >= startupAt then
        recoverJobs()
    end
    if not current then current = table.remove(waiting, 1) end
    if current then
        local job = current
        local ok, err = pcall(advanceJob, job, now)
        if not ok then
            log("Job " .. job.id .. " stopped: " .. tostring(err))
            finish(job)
        end
    end
    if not startupAt and not current and #waiting == 0 then
        Events.OnTickEvenPaused.Remove(onTick)
        tickSubscribed = false
    end
end

local function onServerCommand(metadata)
    if type(metadata) ~= "string" then return end
    local id = metadata:match("^vehicle%-migration%s+(%S+)%s*$")
    if not id then return end
    local a, b, c, d, e = id:match("^(%x+)%-(%x+)%-(%x+)%-(%x+)%-(%x+)$")
    if not a or #a ~= 8 or #b ~= 4 or #c ~= 4 or #d ~= 4 or #e ~= 12 then
        log("Ignored vehicle-migration command with invalid job UUID")
        return
    end
    if not repository then
        log("Vehicle migration queue is unavailable")
        return
    end
    enqueue(string.lower(id))
end

local function onServerStarted()
    if not isServer() then return end
    if not ApocBRModEntities or not ApocBRLobbyStreaming or not Events.OnApocBRServerCommand then
        log("Disabled: the servercommand, entity, and cell streaming hooks are required")
        return
    end
    local ok, err = pcall(function()
        scope = Entities.serverScope()
        local jobs = Entities.define("VehicleMigration.Job", {
            table = "vehicle_migration_job",
            fields = {
                server_id = { type = "integer", id = true },
                world = { type = "string", id = true },
                job_id = { type = "uuid", id = true },
                status = { type = "string" },
                payload = { type = "text" },
                detail = { type = "string" },
                vehicle_id = { type = "integer" },
                cargo_restored = { type = "boolean" },
            }
        })
        Events.OnApocBRServerCommand.Add(onServerCommand)
        repository = jobs
        recoverJobs()
    end)
    if not ok then log("Could not initialize vehicle migration: " .. tostring(err)) end
end

Events.OnServerStarted.Add(onServerStarted)
