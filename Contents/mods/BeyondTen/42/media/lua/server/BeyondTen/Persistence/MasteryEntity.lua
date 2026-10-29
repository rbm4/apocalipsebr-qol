-- Startup schema validation only; gameplay persistence remains a scaffold.
-- Does not read/write BeyondTen's existing global or player ModData.
if not isServer() then return end
require "ApocBR/Entities"

BeyondTenPersistence = BeyondTenPersistence or {}
local function masteryRepository()
    if BeyondTenPersistence.Mastery then return BeyondTenPersistence.Mastery end
    BeyondTenPersistence.Mastery = ApocBREntities.define("BeyondTen.Mastery", {
        table = "beyondten_mastery",
        fields = {
            character_id = { type = "uuid", id = true },
            perk_id = { type = "string", id = true },
            xp = { type = "number" },
        },
    })
    return BeyondTenPersistence.Mastery
end

local validationStarted = false
Events.OnServerStarted.Add(function()
    if validationStarted then return end
    validationStarted = true

    local prefix = "[BeyondTen/Persistence] BeyondTen.Mastery -> mod_data.beyondten_mastery: "
    if not ApocBRModEntities then
        print(prefix .. "validation FAILED (server entity bridge unavailable); server startup continues")
        return
    end

    -- Definition and admission can throw before the async callback is installed.
    -- Database validation runs on the Java worker; delivery uses OnTickEvenPaused.
    local ok, failure = pcall(function()
        local repository = masteryRepository()
        print(prefix .. "validation requested")
        repository:validate(function(result)
            if result.status == "OK" then
                print(prefix .. "validation OK (character_id: uuid, perk_id: string, xp: number; "
                    .. "primary key: character_id + perk_id; revision: bigint)")
            else
                print(prefix .. "validation FAILED (" .. tostring(result.status) .. "); server startup continues")
            end
        end)
    end)
    if not ok then
        print(prefix .. "validation FAILED (" .. tostring(failure) .. "); server startup continues")
    end
end)

-- Future integration must obtain character_id from trusted server reconstruction,
-- validate the active incarnation on completion, and establish transfer ownership.
-- Example (explicit invocation only):
-- local repository = BeyondTenPersistence.Mastery
-- repository:find({ character_id = trustedCharacterId, perk_id = "Aiming" }, function(result)
--     if result.status == "OK" then
--         local entity = result.entity
--         entity:set("xp", entity:get("xp") + 5)
--         entity:save(function(saved) -- OK means committed; CONFLICT requires reload.
--         end)
--     end
-- end)
