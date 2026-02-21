local PZVersion = {}

-- Cached parsed values
local _major, _minor, _patch

local function parseVersion()
    if _major then return end

    local v = getCore():getVersion() or ""
    local maj, min, pat = v:match("(%d+)%.(%d+)%.?(%d*)")

    _major = tonumber(maj) or 0
    _minor = tonumber(min) or 0
    _patch = tonumber(pat) or 0
end

local function parseTestVersion(versionString)
    local s = tostring(versionString or ""):lower():gsub("%s+", "")
    local maj, min, pat = s:match("^(%d+)%.(%d+)%.(%d+)$")
    if maj then
        return { major = tonumber(maj), minor = tonumber(min), patch = tonumber(pat), wildMinor = false, wildPatch = false }
    end

    maj, min, pat = s:match("^(%d+)%.(%d+)%.([x%*])$")
    if maj then
        return { major = tonumber(maj), minor = tonumber(min), patch = 0, wildMinor = false, wildPatch = true }
    end

    maj, min = s:match("^(%d+)%.(%d+)$")
    if maj then
        return { major = tonumber(maj), minor = tonumber(min), patch = 0, wildMinor = false, wildPatch = true } -- no patch specified => any patch
    end

    maj, min = s:match("^(%d+)%.([x%*])$")
    if maj then
        return { major = tonumber(maj), minor = 0, patch = 0, wildMinor = true, wildPatch = true }
    end

    maj = s:match("^(%d+)$")
    if maj then
        return { major = tonumber(maj), minor = 0, patch = 0, wildMinor = true, wildPatch = true }
    end

    return nil
end

PZVersion.isExact = function(versionString)
    parseVersion()

    local t = parseTestVersion(versionString)
    if not t then return false end

    if _major ~= t.major then return false end
    if not t.wildMinor and _minor ~= t.minor then return false end
    if not t.wildPatch and _patch ~= t.patch then return false end

    return true
end

PZVersion.isAtLeast = function(versionString)
    parseVersion()

    local t = parseTestVersion(versionString)
    if not t then return false end

    if _major ~= t.major then
        return _major > t.major
    end

    if t.wildMinor then
        return true
    end
    if _minor ~= t.minor then
        return _minor > t.minor
    end

    -- If patch is wildcard (e.g. "42.13", "42.13.x"), lower bound is 42.13.0
    if t.wildPatch then
        return true
    end

    return _patch >= (t.patch or 0)
end

PZVersion.isAtMax = function(versionString)
    parseVersion()

    local t = parseTestVersion(versionString)
    if not t then return false end

    if _major ~= t.major then
        return _major < t.major
    end

    if t.wildMinor then
        return true
    end
    if _minor ~= t.minor then
        return _minor < t.minor
    end

    -- If patch is wildcard (e.g. "42.13", "42.13.x"), then any patch is allowed.
    if t.wildPatch then
        return true
    end

    return _patch <= (t.patch or 0)
end

return PZVersion
