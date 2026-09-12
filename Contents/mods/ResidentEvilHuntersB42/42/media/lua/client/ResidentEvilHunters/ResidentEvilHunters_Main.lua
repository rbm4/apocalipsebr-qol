require "ResidentEvilHunters/ResidentEvilHunters_Config"

local function log(msg)
    if ResidentEvilHunters.Config.DebugLogging then
        print("[ResidentEvilHuntersB42] " .. tostring(msg))
    end
end

local function isHunter(zombie)
    if not zombie then return false end
    local data = zombie:getModData()
    return data and data[ResidentEvilHunters.Config.ModDataKey] == true
end

local function forceHunterSprinter(zombie)
    if not zombie or not isHunter(zombie) then return false end

    -- IMPORTANT:
    -- Do NOT call IsoZombie:doSprinter(). In B42 that appears to interact with
    -- the broader zombie speed setup. Instead, set the walk type directly on
    -- this Hunter instance only.
    local ok, err = pcall(function()
        zombie:setWalkType(ResidentEvilHunters.Config.WalkType)
        zombie:setSpeedTypeFromWalkType()
    end)

    local wt = "?"
    pcall(function() wt = tostring(zombie:getWalkType()) end)

    log("Hunter-only sprinter=" .. tostring(ok) ..
        " walkType=" .. tostring(wt) ..
        " error=" .. tostring(err))

    return ok
end

local function getHunterVariant(zombie)
    if not zombie then return nil end
    local data = zombie:getModData()
    local id = data and data[ResidentEvilHunters.Config.VariantDataKey] or nil

    for _, variant in ipairs(ResidentEvilHunters.Config.Variants or {}) do
        if variant.id == id then
            return variant
        end
    end

    return (ResidentEvilHunters.Config.Variants or {})[1]
end

local function getSandboxHunterSettings()
    local vars = SandboxVars and SandboxVars.ResidentEvilHunters or nil

    return {
        alphaEnabled = (vars == nil or vars.EnableHunterAlpha == nil)
            and true or vars.EnableHunterAlpha,
        betaEnabled = (vars == nil or vars.EnableHunterBeta == nil)
            and true or vars.EnableHunterBeta,
        gammaEnabled = (vars == nil or vars.EnableHunterGamma == nil)
            and true or vars.EnableHunterGamma,
        alphaRate = tonumber(vars and vars.HunterAlphaSpawnRate) or 1.0,
        betaRate = tonumber(vars and vars.HunterBetaSpawnRate) or 1.0,
        gammaRate = tonumber(vars and vars.HunterGammaSpawnRate) or 1.0,
    }
end

local function getVariantById(id)
    for _, variant in ipairs(ResidentEvilHunters.Config.Variants or {}) do
        if variant.id == id then
            return variant
        end
    end
    return nil
end

local function huntersEnabled()
    local s = getSandboxHunterSettings()
    return (s.alphaEnabled and s.alphaRate > 0)
        or (s.betaEnabled and s.betaRate > 0)
        or (s.gammaEnabled and s.gammaRate > 0)
end

local function findHunterItem(zombie)
    if not zombie then return nil end
    local variant = getHunterVariant(zombie)
    if not variant then return nil end

    local inv = zombie:getInventory()
    if not inv then return nil end

    local found = nil
    pcall(function()
        found = inv:getFirstTypeRecurse(variant.visualItemType)
    end)
    return found
end

local function getOrCreateHunterItem(zombie)
    local variant = getHunterVariant(zombie)
    if not variant then return nil, false, "no variant" end

    local item = findHunterItem(zombie)
    if item then
        return item, true, "existing"
    end

    local inv = zombie and zombie:getInventory()
    if not inv then
        return nil, false, "no inventory"
    end

    local ok, result = pcall(function()
        return inv:AddItem(variant.visualItemType)
    end)

    if ok and result then
        return result, true, "inventory:AddItem(" .. tostring(variant.id) .. ")"
    end

    return nil, false, "AddItem failed variant=" .. tostring(variant.id) ..
        " result=" .. tostring(result)
end

local function addDirectVisual(zombie, item)
    if not zombie or not item then return false, "missing zombie/item" end

    local visuals = nil
    local okList, listErr = pcall(function()
        visuals = zombie:getItemVisuals()
    end)
    if not okList or not visuals then
        return false, "getItemVisuals failed: " .. tostring(listErr)
    end

    local visual = nil
    local okVisual, visualErr = pcall(function()
        visual = item:getVisual()
    end)
    if not okVisual or not visual then
        return false, "item:getVisual failed: " .. tostring(visualErr)
    end

    -- Add the Hunter body visual without affecting non-Hunter zombies.
    local okAdd, addErr = pcall(function()
        visuals:add(visual)
    end)

    return okAdd, addErr
end

local function clearVanillaBodyVisuals(zombie)
    if not zombie then return false end

    local ok, err = pcall(function()
        local humanVisual = zombie:getHumanVisual()
        if not humanVisual then return end

        -- Vanilla wounds, bandages and other body overlays live separately
        -- from worn clothing/item visuals. Hunters use a complete custom body
        -- model, so none of those underlying zombie overlays should remain.
        local bodyVisuals = humanVisual:getBodyVisuals()
        if bodyVisuals then
            bodyVisuals:clear()
        end

        humanVisual:removeBlood()
        humanVisual:removeDirt()
    end)

    log("Clear vanilla body visuals=" .. tostring(ok) ..
        " error=" .. tostring(err))
    return ok
end

local function removeVanillaClothing(zombie, reason)
    if not zombie then return false end

    local removedCount = 0
    local ok, err = pcall(function()
        local worn = zombie:getWornItems()
        if worn then
            worn:clear()
        end

        local visuals = zombie:getItemVisuals()
        if visuals then
            visuals:clear()
        end

        clearVanillaBodyVisuals(zombie)

        local inv = zombie:getInventory()
        if inv then
            local items = inv:getItems()
            if items then
                for i = items:size() - 1, 0, -1 do
                    local item = items:get(i)
                    if item then
                        local fullType = nil
                        pcall(function() fullType = item:getFullType() end)

                        local isHunterVisual = false
                        for _, variant in ipairs(ResidentEvilHunters.Config.Variants or {}) do
                            if fullType == variant.visualItemType then
                                isHunterVisual = true
                                break
                            end
                        end

                        if not isHunterVisual then

                            local isClothing = false
                            pcall(function()
                                isClothing = instanceof(item, "Clothing")
                            end)

                            local clothingName = nil
                            local bodyLocation = nil
                            pcall(function() clothingName = item:getClothingItemName() end)
                            pcall(function() bodyLocation = item:getBodyLocation() end)

                            if isClothing or clothingName ~= nil or bodyLocation ~= nil then
                                inv:Remove(item)
                                removedCount = removedCount + 1
                            end
                        end
                    end
                end
            end
        end
    end)

    log("Remove vanilla clothing[" .. tostring(reason) .. "]=" .. tostring(ok) ..
        " removed=" .. tostring(removedCount) ..
        " error=" .. tostring(err))
    return ok
end


local function applyHunterVisual(zombie, reason)
    if not zombie then return false end

    if reason ~= "initial" then
        removeVanillaClothing(zombie, reason)
    end

    local item, itemOk, itemHow = getOrCreateHunterItem(zombie)
    log("visual[" .. tostring(reason) .. "] body item created/found=" ..
        tostring(itemOk) .. " via=" .. tostring(itemHow) ..
        " item=" .. tostring(item))

    if not item then return false end

    local directOk, directErr = addDirectVisual(zombie, item)
    log("visual[" .. tostring(reason) .. "] direct visual add=" ..
        tostring(directOk) .. " error=" .. tostring(directErr))

    local resetOk, resetErr = pcall(function()
        zombie:resetModel()
        zombie:resetModelNextFrame()
    end)
    log("visual[" .. tostring(reason) .. "] resetModel=" ..
        tostring(resetOk) .. " error=" .. tostring(resetErr))

    return directOk
end

local function applyHunterStats(zombie)
    if not zombie then return false end

    local ok, err = pcall(function()
        -- Multiply whatever health PZ generated for this zombie rather than
        -- assuming a fixed base value.
        local currentHealth = zombie:getHealth()
        if currentHealth and currentHealth > 0 then
            zombie:setHealth(currentHealth * (ResidentEvilHunters.Config.HealthMultiplier or 3.0))
        end
    end)

    local hp = "?"
    pcall(function() hp = tostring(zombie:getHealth()) end)

    log("Applied Hunter stats=" .. tostring(ok) ..
        " health=" .. tostring(hp) ..
        " error=" .. tostring(err))
    return ok
end

local function makeHunter(zombie, requestedVariantId)
    if not zombie or isHunter(zombie) then return end

    local data = zombie:getModData()
    data[ResidentEvilHunters.Config.ModDataKey] = true

    local chosenVariant = getVariantById(requestedVariantId)
    if not chosenVariant then
        data[ResidentEvilHunters.Config.ModDataKey] = nil
        return
    end

    data[ResidentEvilHunters.Config.VariantDataKey] = chosenVariant.id

    data.ResidentEvilHunters_VisualRetries = ResidentEvilHunters.Config.VisualRetryCount or 0
    data.ResidentEvilHunters_VisualRetryTick = 0

    -- Hunters should not retain the original zombie outfit or clothing loot.
    removeVanillaClothing(zombie, "initial")

    local visualOk = applyHunterVisual(zombie, "initial")
    applyHunterStats(zombie)
    forceHunterSprinter(zombie)

    local zid = "?"
    pcall(function() zid = tostring(zombie:getOnlineID()) end)
    log("Converted zombie " .. zid ..
        " into Hunter " .. tostring(data[ResidentEvilHunters.Config.VariantDataKey]) ..
        " visualOk=" .. tostring(visualOk) ..
        " retries=" .. tostring(data.ResidentEvilHunters_VisualRetries))
end

local pendingPacks = {}
local zombieCreateSerial = 0

local function distanceSq2D(a, x, y)
    local dx = a.x - x
    local dy = a.y - y
    return dx * dx + dy * dy
end

local function prunePendingPacks()
    for i = #pendingPacks, 1, -1 do
        local pack = pendingPacks[i]
        if pack.remaining <= 0 or zombieCreateSerial > pack.expiresAt then
            table.remove(pendingPacks, i)
        end
    end
end

local function tryJoinPendingPack(zombie)
    if not zombie or isHunter(zombie) then return false end

    local zx, zy, zz = zombie:getX(), zombie:getY(), zombie:getZ()
    local radiusSq = (ResidentEvilHunters.Config.PackRadius or 8.0) ^ 2

    for i = #pendingPacks, 1, -1 do
        local pack = pendingPacks[i]
        if pack.remaining > 0 and zz == pack.z then
            local dx = zx - pack.x
            local dy = zy - pack.y
            if (dx * dx + dy * dy) <= radiusSq then
                makeHunter(zombie, pack.variantId)
                pack.remaining = pack.remaining - 1
                log("Added spawned zombie to Hunter pack; remaining=" ..
                    tostring(pack.remaining))
                if pack.remaining <= 0 then
                    table.remove(pendingPacks, i)
                end
                return true
            end
        end
    end

    return false
end

local function convertNearbyPackMembers(leader, wanted, variantId)
    if wanted <= 0 then return 0 end

    local cell = getCell and getCell() or nil
    if not cell then return 0 end

    local list = nil
    pcall(function() list = cell:getZombieList() end)
    if not list then return 0 end

    local lx, ly, lz = leader:getX(), leader:getY(), leader:getZ()
    local radiusSq = (ResidentEvilHunters.Config.PackRadius or 8.0) ^ 2
    local candidates = {}

    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z and z ~= leader and not isHunter(z) and z:getZ() == lz then
            local dx = z:getX() - lx
            local dy = z:getY() - ly
            local d2 = dx * dx + dy * dy
            if d2 <= radiusSq then
                candidates[#candidates + 1] = { zombie = z, d2 = d2 }
            end
        end
    end

    table.sort(candidates, function(a, b) return a.d2 < b.d2 end)

    local converted = 0
    for i = 1, math.min(wanted, #candidates) do
        makeHunter(candidates[i].zombie, variantId)
        converted = converted + 1
    end

    return converted
end

local function startHunterPack(leader, variantId)
    if not huntersEnabled() then
        return
    end

    local minSize = tonumber(ResidentEvilHunters.Config.PackMinSize) or 1
    local maxSize = tonumber(ResidentEvilHunters.Config.PackMaxSize) or 3
    if maxSize < minSize then maxSize = minSize end

    local packSize = ZombRand(minSize, maxSize + 1)

    makeHunter(leader, variantId)

    local remaining = packSize - 1
    if remaining > 0 then
        local converted = convertNearbyPackMembers(leader, remaining, variantId)
        remaining = remaining - converted
    end

    if remaining > 0 then
        pendingPacks[#pendingPacks + 1] = {
            x = leader:getX(),
            y = leader:getY(),
            z = leader:getZ(),
            variantId = variantId,
            remaining = remaining,
            expiresAt = zombieCreateSerial +
                (ResidentEvilHunters.Config.PendingPackCreateEvents or 20),
        }
    end

    log("Started Hunter " .. tostring(variantId) ..
        " pack requestedSize=" .. tostring(packSize) ..
        " pending=" .. tostring(remaining))
end

local function onZombieCreate(zombie)
    if not zombie then return end

    zombieCreateSerial = zombieCreateSerial + 1
    prunePendingPacks()

    if tryJoinPendingPack(zombie) then
        return
    end

    local s = getSandboxHunterSettings()
    local hits = {}

    if s.alphaEnabled and s.alphaRate > 0
        and ZombRandFloat(0.0, 100.0) < s.alphaRate then
        hits[#hits + 1] = "Alpha"
    end

    if s.betaEnabled and s.betaRate > 0
        and ZombRandFloat(0.0, 100.0) < s.betaRate then
        hits[#hits + 1] = "Beta"
    end

    if s.gammaEnabled and s.gammaRate > 0
        and ZombRandFloat(0.0, 100.0) < s.gammaRate then
        hits[#hits + 1] = "Gamma"
    end

    if #hits > 0 then
        local chosen = hits[ZombRand(#hits) + 1]
        startHunterPack(zombie, chosen)
    end
end

local function onZombieUpdate(zombie)
    if not isHunter(zombie) then return end

    local data = zombie:getModData()


    -- Reapply the visual briefly after creation so the custom model persists.
    local retries = tonumber(data.ResidentEvilHunters_VisualRetries) or 0
    if retries > 0 then
        data.ResidentEvilHunters_VisualRetryTick = (data.ResidentEvilHunters_VisualRetryTick or 0) + 1

        if data.ResidentEvilHunters_VisualRetryTick >= (ResidentEvilHunters.Config.VisualRetryEveryUpdates or 30) then
            data.ResidentEvilHunters_VisualRetryTick = 0
            local ok = applyHunterVisual(zombie, "retry-" .. tostring(retries))
            data.ResidentEvilHunters_VisualRetries = retries - 1
            log("Delayed Hunter visual retry success=" .. tostring(ok) ..
                " remaining=" .. tostring(data.ResidentEvilHunters_VisualRetries))
        end
    end
end





local function logHunterSandboxSettings()
    local s = getSandboxHunterSettings()
    log("SANDBOX Alpha enabled=" .. tostring(s.alphaEnabled) ..
        " rate=" .. tostring(s.alphaRate) ..
        "% | Beta enabled=" .. tostring(s.betaEnabled) ..
        " rate=" .. tostring(s.betaRate) ..
        "% | Gamma enabled=" .. tostring(s.gammaEnabled) ..
        " rate=" .. tostring(s.gammaRate) .. "%")
end

Events.OnGameStart.Add(logHunterSandboxSettings)

Events.OnZombieCreate.Add(onZombieCreate)
Events.OnZombieUpdate.Add(onZombieUpdate)

log("Resident Evil Hunters loaded")
