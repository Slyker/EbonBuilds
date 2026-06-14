-- EbonBuilds: modules/ui/BuildOverview/Init.lua
-- Main orchestrator: shared state, delete dialog, DRY tab helpers,
-- BuildViewFrame, view interface, and Init.

local BO = EbonBuilds.BuildOverview
local UIH = EbonBuilds.UIHelpers

------------------------------------------------------------------------
-- Shared mutable state
------------------------------------------------------------------------

BO.state = { build = nil }

BO.viewFrame = nil
BO.overviewOuter = nil
BO.overviewDescEdit = nil
BO.contentArea = nil
BO.settingsParent = nil

BO.statsValueLabels = nil
BO.statsQualityLabels = nil
BO.statsParent = nil

BO.missingScroll = nil
BO.missingChild = nil
BO.missingBar = nil
BO.missingRows = {}
BO.missingParent = nil

BO.logbookParent = nil

BO.echoesScroll = nil
BO.echoesChild = nil
BO.echoesBar = nil
BO.echoesRows = {}
BO.echoesSearchText = ""
BO.echoesQualityFilter = -1
BO.echoesSortMode = 1
BO.echoesShowAll = false
BO.echoesParent = nil
BO.echoesRefreshTimer = nil

------------------------------------------------------------------------
-- MarkDirty: mark build as modified, refresh build list
------------------------------------------------------------------------

function BO.MarkDirty()
    local build = BO.state.build
    if not build then return end
    build.lastModified = date("%Y-%m-%d %H:%M:%S")
    build._checksum = EbonBuilds.Build.Checksum(build)
    build.validated = false
    if EbonBuilds.BuildList and EbonBuilds.BuildList.Refresh then
        EbonBuilds.BuildList.Refresh()
    end
end

------------------------------------------------------------------------
-- Delete confirmation dialog
------------------------------------------------------------------------

StaticPopupDialogs["EBONBUILDS_DELETE_BUILD"] = {
    text = "",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function()
        local build = BO.state.build
        if not build or not build.id then return end
        local id = build.id
        EbonBuilds.Build.Delete(id)
        if EbonBuilds.BuildList and EbonBuilds.BuildList.Refresh then
            EbonBuilds.BuildList.Refresh()
        end
        local builds = EbonBuilds.Build.List()
        if #builds > 0 then
            EbonBuilds.Build.SetActive(builds[1].id)
            EbonBuilds.ViewRouter.Show("buildOverview", { build = builds[1] })
        else
            EbonBuilds.ViewRouter.Show("welcome")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

------------------------------------------------------------------------
-- DRY: generic tab creation helper
------------------------------------------------------------------------

local function CreateTab(f, id, text, prevTab, onClick)
    local tab = CreateFrame("Button", "EbonBuildsBuildOverviewTab" .. id, f, "OptionsFrameTabButtonTemplate")
    tab:SetID(id)
    tab:SetText(text)
    if prevTab then
        tab:SetPoint("LEFT", prevTab, "RIGHT", -16, 0)
    else
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", 10, 0)
    end
    PanelTemplates_TabResize(tab, 0)
    tab:SetScript("OnClick", onClick)
    return tab
end

------------------------------------------------------------------------
-- DRY: generic tab switching helper
------------------------------------------------------------------------

local function HideAllContent()
    if BO.overviewOuter then BO.overviewOuter:Hide() end
    if BO.statsParent then BO.statsParent:Hide() end
    if BO.missingParent then BO.missingParent:Hide() end
    if BO.logbookParent then BO.logbookParent:Hide() end
    if BO.echoesParent then BO.echoesParent:Hide() end
    if BO.settingsParent then BO.settingsParent:Hide() end
    if BO.echoesRefreshTimer then BO.echoesRefreshTimer:Hide() end
end

local function SwitchTab(f, tabIndex, parent, showDelete, ...)
    HideAllContent()
    if BO.overviewOuter and BO.overviewOuter._deleteBtn then
        if showDelete then
            BO.overviewOuter._deleteBtn:Show()
        else
            BO.overviewOuter._deleteBtn:Hide()
        end
    end
    parent:Show()
    PanelTemplates_SetTab(f, tabIndex)
    for i = 1, 5 do
        if i ~= tabIndex then
            PanelTemplates_EnableTab(f, i)
        end
    end
    for _, fn in ipairs({...}) do fn() end
end

------------------------------------------------------------------------
-- BuildViewFrame: construct the main frame with tabs
------------------------------------------------------------------------

local function BuildViewFrame()
    local f = CreateFrame("Frame", "EbonBuildsBuildOverview", UIParent)

    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT",     f, "TOPLEFT",     0, -24)
    box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0,  10)
    box:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    BO.contentArea = CreateFrame("Frame", nil, box)
    BO.contentArea:SetPoint("TOPLEFT",     box, "TOPLEFT",     6, -6)
    BO.contentArea:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6,  6)

    BO.overviewOuter, BO.overviewDescEdit = BO.BuildOverviewTab(BO.contentArea)

    BO.statsParent = CreateFrame("Frame", nil, BO.contentArea)
    BO.statsParent:SetAllPoints(BO.contentArea)
    BO.statsParent:Hide()
    BO.statsValueLabels, BO.statsQualityLabels = BO.BuildStatsTab(BO.statsParent)

    BO.missingParent = CreateFrame("Frame", nil, BO.contentArea)
    BO.missingParent:SetAllPoints(BO.contentArea)
    BO.missingParent:Hide()
    BO.missingScroll, BO.missingChild, BO.missingBar = BO.BuildMissingTab(BO.missingParent)

    BO.logbookParent = CreateFrame("Frame", nil, BO.contentArea)
    BO.logbookParent:SetAllPoints(BO.contentArea)
    BO.logbookParent:Hide()
    BO.BuildLogbookTab(BO.logbookParent)

    BO.echoesParent = CreateFrame("Frame", nil, BO.contentArea)
    BO.echoesParent:SetAllPoints(BO.contentArea)
    BO.echoesParent:Hide()
    BO.echoesScroll, BO.echoesChild, BO.echoesBar = BO.BuildEchoesTab(BO.echoesParent)

    BO.settingsParent = CreateFrame("Frame", nil, BO.contentArea)
    BO.settingsParent:SetAllPoints(BO.contentArea)
    BO.settingsParent:Hide()

    -- Tab switching functions (stored on BO for view.Show access)
    BO.SwitchOverview = function()
        SwitchTab(f, 1, BO.overviewOuter, true, BO.RefreshOverview)
    end

    BO.SwitchStats = function()
        SwitchTab(f, 2, BO.statsParent, false, BO.RefreshStats)
    end

    BO.SwitchMissing = function()
        SwitchTab(f, 3, BO.missingParent, false, BO.RefreshMissing)
    end

    BO.SwitchLogbook = function()
        SwitchTab(f, 4, BO.logbookParent, false, function()
            EbonBuilds.SessionHistory.Show(BO.logbookParent)
        end)
    end

    BO.SwitchEchoes = function()
        SwitchTab(f, 5, BO.echoesParent, false, BO.RefreshEchoes)
        if not BO.echoesRefreshTimer then
            BO.echoesRefreshTimer = CreateFrame("Frame")
            BO.echoesRefreshTimer._elapsed = 0
            BO.echoesRefreshTimer:SetScript("OnUpdate", function(self, dt)
                self._elapsed = self._elapsed + dt
                if self._elapsed < 2 then return end
                self._elapsed = 0
                if BO.echoesParent and BO.echoesParent:IsShown() then
                    BO.RefreshEchoes()
                end
            end)
        end
        BO.echoesRefreshTimer._elapsed = 0
        BO.echoesRefreshTimer:Show()
    end

    BO.SwitchSettings = function()
        SwitchTab(f, 6, BO.settingsParent, false, function()
            EbonBuilds.SettingsView.Mount(BO.settingsParent)
        end)
    end

    -- Create tabs using DRY helper
    local tab1 = CreateTab(f, 1, "Overview",  nil, function() BO.SwitchOverview() end)
    local tab2 = CreateTab(f, 2, "Stats",     tab1, function() BO.SwitchStats() end)
    local tab3 = CreateTab(f, 3, "Missing",   tab2, function() BO.SwitchMissing() end)
    local tab4 = CreateTab(f, 4, "Logbook",   tab3, function() BO.SwitchLogbook() end)
    local tab5 = CreateTab(f, 5, "Echoes",    tab4, function() BO.SwitchEchoes() end)
    CreateTab(f, 6, "Settings",  tab5, function() BO.SwitchSettings() end)

    PanelTemplates_SetNumTabs(f, 6)
    PanelTemplates_SetTab(f, 1)

    return f
end

------------------------------------------------------------------------
-- View interface
------------------------------------------------------------------------

local view = {}

function view.Show(container, context)
    BO.viewFrame:SetParent(container)
    BO.viewFrame:ClearAllPoints()
    BO.viewFrame:SetAllPoints(container)

    context = context or {}
    BO.state.build = context.build
    if BO.SwitchOverview then BO.SwitchOverview() end
    BO.viewFrame:Show()
end

function view.Hide()
    if BO.viewFrame then BO.viewFrame:Hide() end
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------

function BO.Init()
    BO.viewFrame = BuildViewFrame()
    BO.viewFrame:Hide()
    EbonBuilds.ViewRouter.Register("buildOverview", view)
end
