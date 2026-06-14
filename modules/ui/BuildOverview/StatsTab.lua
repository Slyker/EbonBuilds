-- EbonBuilds: modules/ui/BuildOverview/StatsTab.lua
-- Stats tab: build statistics, quality distribution, most picked/banned.

local BO = EbonBuilds.BuildOverview
local QUALITY_LABELS = EbonBuilds.Constants.QUALITY_LABELS

local STAT_ROWS = {
    { key = "echoesSeen",    label = "Echoes Seen" },
    { key = "runsCompleted", label = "Runs Completed" },
    { key = "runsReset",     label = "Runs Reset" },
    { key = "picks",         label = "Picks" },
    { key = "rerollsUsed",   label = "Rerolls Used" },
    { key = "banishesUsed",  label = "Banishes Used" },
    { key = "freezesUsed",   label = "Freezes Used" },
}

------------------------------------------------------------------------
-- BuildStatsTab: construct the stats content frame
------------------------------------------------------------------------

local function BuildStatsTab(parent)
    local y = -10

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
    header:SetText("Build Statistics")

    y = y - 30
    local valueLabels = {}
    for i, row in ipairs(STAT_ROWS) do
        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y)
        lbl:SetText(row.label .. ":")
        lbl:SetWidth(160)
        lbl:SetJustifyH("LEFT")

        local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        val:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
        val:SetText("0")
        val:SetWidth(60)
        val:SetJustifyH("RIGHT")
        valueLabels[row.key] = val

        y = y - 22
    end

    y = y - 8
    local mostPickedLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mostPickedLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y)
    mostPickedLbl:SetText("Most Picked:")
    mostPickedLbl:SetWidth(100)
    mostPickedLbl:SetJustifyH("LEFT")
    local mostPickedVal = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mostPickedVal:SetPoint("LEFT", mostPickedLbl, "RIGHT", 4, 0)
    mostPickedVal:SetText("-")
    mostPickedVal:SetWidth(150)
    mostPickedVal:SetJustifyH("LEFT")
    valueLabels.mostPicked = mostPickedVal

    y = y - 18
    local mostBannedLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mostBannedLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y)
    mostBannedLbl:SetText("Most Banned:")
    mostBannedLbl:SetWidth(100)
    mostBannedLbl:SetJustifyH("LEFT")
    local mostBannedVal = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mostBannedVal:SetPoint("LEFT", mostBannedLbl, "RIGHT", 4, 0)
    mostBannedVal:SetText("-")
    mostBannedVal:SetWidth(150)
    mostBannedVal:SetJustifyH("LEFT")
    valueLabels.mostBanned = mostBannedVal

    local qy = -10
    local qHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 270, qy)
    qHeader:SetText("Quality Distribution:")

    qy = qy - 26
    local qualityLabels = {}
    for q = 0, 4 do
        local qlbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        qlbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 274, qy)
        qlbl:SetText(QUALITY_LABELS[q] .. ":")
        qlbl:SetWidth(90)
        qlbl:SetJustifyH("LEFT")

        local qval = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        qval:SetPoint("LEFT", qlbl, "RIGHT", 4, 0)
        qval:SetText("0 (0%)")
        qval:SetWidth(80)
        qval:SetJustifyH("RIGHT")
        qualityLabels[q] = qval

        qy = qy - 18
    end

    return valueLabels, qualityLabels
end

------------------------------------------------------------------------
-- RefreshStats: update stat labels from build data
------------------------------------------------------------------------

local function RefreshStats()
    local build = BO.state.build
    if not build or not BO.statsValueLabels then return end
    local st = build.stats or {}
    for _, row in ipairs(STAT_ROWS) do
        if BO.statsValueLabels[row.key] then
            BO.statsValueLabels[row.key]:SetText(tostring(st[row.key] or 0))
        end
    end
    for q = 0, 4 do
        if BO.statsQualityLabels[q] then
            local count = (st.qualityPicks or {})[q] or 0
            local total = st.picks or 0
            local pct = total > 0 and math.floor(count / total * 100) or 0
            BO.statsQualityLabels[q]:SetText(string.format("%d (%d%%)", count, pct))
        end
    end
    local mostPickedName = next(st.mostPicked or {}) or "-"
    BO.statsValueLabels.mostPicked:SetText(type(mostPickedName) == "string" and mostPickedName or tostring(mostPickedName))
    local mostBannedName = next(st.mostBanned or {}) or "-"
    BO.statsValueLabels.mostBanned:SetText(type(mostBannedName) == "string" and mostBannedName or tostring(mostBannedName))
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

BO.BuildStatsTab = BuildStatsTab
BO.RefreshStats = RefreshStats
