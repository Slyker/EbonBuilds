-- EbonBuilds: modules/ui/BuildOverview/StatsTab.lua
-- Stats tab: build statistics derived from session logbook.
-- Shows two columns: All Time (left) and Current Session (right).

local BO = EbonBuilds.BuildOverview
local QUALITY_LABELS = EbonBuilds.Constants.QUALITY_LABELS
local QUALITY_COLORS = EbonBuilds.Constants.QUALITY_COLORS

local STAT_ROWS = {
    { key = "echoesSeen",    label = "Echoes Seen" },
    { key = "runsCompleted", label = "Runs Completed" },
    { key = "picks",         label = "Picks" },
    { key = "rerollsUsed",   label = "Rerolls Used" },
    { key = "banishesUsed",  label = "Banishes Used" },
    { key = "freezesUsed",   label = "Freezes Used" },
}

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function FindTopEntry(map)
    local bestName, bestCount = nil, 0
    for name, count in pairs(map) do
        if count > bestCount then
            bestCount = count
            bestName = name
        end
    end
    if bestName then
        return string.format("%s (%d)", bestName, bestCount)
    end
    return "-"
end

------------------------------------------------------------------------
-- BuildStatsTab: two-column layout
------------------------------------------------------------------------

local function BuildStatsTab(parent)
    local leftCol = CreateFrame("Frame", nil, parent)
    leftCol:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -8)
    leftCol:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 8)
    leftCol:SetPoint("TOPRIGHT", parent, "TOP", -4, 0)
    leftCol:SetPoint("BOTTOMRIGHT", parent, "BOTTOM", -4, 8)

    local rightCol = CreateFrame("Frame", nil, parent)
    rightCol:SetPoint("TOPLEFT", parent, "TOP", 4, -8)
    rightCol:SetPoint("BOTTOMLEFT", parent, "BOTTOM", 4, 8)
    rightCol:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -8)
    rightCol:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 8)

    local allLabels = {}
    local sessionLabels = {}

    local function AddSection(col, title, labels)
        local y = 0

        local hdr = col:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        hdr:SetPoint("TOPLEFT", col, "TOPLEFT", 4, y)
        hdr:SetText(title)
        y = y - 26

        for _, row in ipairs(STAT_ROWS) do
            local lbl = col:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("TOPLEFT", col, "TOPLEFT", 8, y)
            lbl:SetText(row.label .. ":")
            lbl:SetWidth(130)
            lbl:SetJustifyH("LEFT")

            local val = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            val:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
            val:SetText("0")
            val:SetWidth(60)
            val:SetJustifyH("RIGHT")
            labels[row.key] = val

            y = y - 20
        end

        y = y - 4
        local mpLbl = col:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mpLbl:SetPoint("TOPLEFT", col, "TOPLEFT", 8, y)
        mpLbl:SetText("Most Picked:")
        mpLbl:SetWidth(100)
        mpLbl:SetJustifyH("LEFT")
        local mpVal = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mpVal:SetPoint("LEFT", mpLbl, "RIGHT", 4, 0)
        mpVal:SetText("-")
        mpVal:SetWidth(200)
        mpVal:SetJustifyH("LEFT")
        labels.mostPicked = mpVal
        y = y - 18

        local mbLbl = col:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mbLbl:SetPoint("TOPLEFT", col, "TOPLEFT", 8, y)
        mbLbl:SetText("Most Banned:")
        mbLbl:SetWidth(100)
        mbLbl:SetJustifyH("LEFT")
        local mbVal = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mbVal:SetPoint("LEFT", mbLbl, "RIGHT", 4, 0)
        mbVal:SetText("-")
        mbVal:SetWidth(200)
        mbVal:SetJustifyH("LEFT")
        labels.mostBanned = mbVal
        y = y - 22

        local qLbl = col:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        qLbl:SetPoint("TOPLEFT", col, "TOPLEFT", 8, y)
        qLbl:SetText("Quality Distribution:")
        qLbl:SetWidth(140)
        qLbl:SetJustifyH("LEFT")
        y = y - 16

        labels.qualityLines = {}
        for q = 0, 4 do
            local ql = col:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            ql:SetPoint("TOPLEFT", col, "TOPLEFT", 14, y)
            ql:SetWidth(300)
            ql:SetJustifyH("LEFT")
            local qc = QUALITY_COLORS[q] or { 1, 1, 1 }
            ql:SetTextColor(qc[1], qc[2], qc[3])
            labels.qualityLines[q] = ql
            y = y - 16
        end

        y = y - 4
        local barBg = CreateFrame("Frame", nil, col)
        barBg:SetPoint("TOPLEFT", col, "TOPLEFT", 14, y)
        barBg:SetSize(200, 10)
        barBg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        barBg:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
        barBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        labels.qualityBar = barBg

        labels.qualitySegments = {}
        local barW = 196
        for q = 0, 4 do
            local seg = barBg:CreateTexture(nil, "ARTWORK")
            seg:SetTexture("Interface\\Buttons\\WHITE8x8")
            local qc = QUALITY_COLORS[q] or { 1, 1, 1 }
            seg:SetVertexColor(qc[1], qc[2], qc[3])
            seg:SetHeight(6)
            seg:SetPoint("LEFT", barBg, "LEFT", 3, 0)
            seg:SetWidth(0)
            seg:Hide()
            labels.qualitySegments[q] = seg
        end
        y = y - 18
    end

    AddSection(leftCol, "All Time", allLabels)
    AddSection(rightCol, "Current Session", sessionLabels)

    BO.statsAllLabels = allLabels
    BO.statsSessionLabels = sessionLabels
end

------------------------------------------------------------------------
-- RefreshStats: compute from logbook and update labels
------------------------------------------------------------------------

local function RefreshStats()
    if not BO.statsAllLabels then return end

    local sessions = EbonBuilds.Session.GetSessions()
    local allStats = EbonBuilds.Session.ComputeStats(sessions)

    local currentSession = EbonBuilds.Session.GetActiveSession()
    local sessionStats = currentSession and EbonBuilds.Session.ComputeStats({ currentSession })
        or {
            echoesSeen = 0, runsCompleted = 0, picks = 0,
            rerollsUsed = 0, banishesUsed = 0, freezesUsed = 0,
            qualityPicks = { 0, 0, 0, 0, 0 },
            mostPicked = {}, mostBanned = {},
        }

    local function UpdateLabels(labels, stats)
        for _, row in ipairs(STAT_ROWS) do
            if labels[row.key] then
                labels[row.key]:SetText(tostring(stats[row.key] or 0))
            end
        end
        labels.mostPicked:SetText(FindTopEntry(stats.mostPicked))
        labels.mostBanned:SetText(FindTopEntry(stats.mostBanned))
        if labels.qualityLines then
            local total = stats.picks or 0
            for q = 0, 4 do
                local count = stats.qualityPicks[q + 1] or 0
                local pct = total > 0 and math.floor(count / total * 100) or 0
                labels.qualityLines[q]:SetText(
                    string.format("%s: %d (%d%%)", QUALITY_LABELS[q], count, pct)
                )
            end
        end
        if labels.qualitySegments then
            local total = stats.picks or 0
            local barW = 196
            local offset = 0
            for q = 0, 4 do
                local count = stats.qualityPicks[q + 1] or 0
                local w = total > 0 and (count / total * barW) or 0
                local seg = labels.qualitySegments[q]
                seg:ClearAllPoints()
                if w > 0.5 then
                    seg:SetPoint("LEFT", labels.qualityBar, "LEFT", 3 + offset, 0)
                    seg:SetWidth(w)
                    seg:Show()
                    offset = offset + w
                else
                    seg:SetWidth(0)
                    seg:Hide()
                end
            end
        end
    end

    UpdateLabels(BO.statsAllLabels, allStats)
    UpdateLabels(BO.statsSessionLabels, sessionStats)
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

BO.BuildStatsTab = BuildStatsTab
BO.RefreshStats = RefreshStats
