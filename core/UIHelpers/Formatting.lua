-- EbonBuilds: core/UIHelpers/Formatting.lua
-- Time formatting and color string helpers.

local C = EbonBuilds.Constants

-- Time formatting ---------------------------------------------------------

function EbonBuilds.UIHelpers.FormatDuration(startTime, endTime)
    local t = (endTime or time()) - startTime
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = math.floor(t % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

function EbonBuilds.UIHelpers.FormatTimestamp(ts)
    return date("%H:%M:%S", ts)
end

-- Color string helpers ----------------------------------------------------

function EbonBuilds.UIHelpers.QColorHex(quality)
    return C.QUALITY_HEX[quality] or "ffffff"
end
