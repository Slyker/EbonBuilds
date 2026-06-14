-- EbonBuilds: modules/ui/BuildList.lua
-- Responsibility: render the left-column list of builds as class-colored cards
-- plus a "+ New Build" button. Clicking a card opens that build for editing.

EbonBuilds.BuildList = {}

local ROW_SINGLE   = 56
local ROW_DOUBLE   = 74
local CARD_MARGIN  = 3
local CLASS_COLORS = EbonBuilds.Constants.CLASS_COLORS

local container
local rowPool     = {}
local scrollFrame
local scrollChild
local newBuildBtn
local importBtn
local publicBuildsBtn
local titleMeasureFont

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local TITLE_MAX_W = 136

local function NeedsTwoLines(text)
    if not text or text == "" then return false end
    titleMeasureFont:SetText(text)
    local w = titleMeasureFont:GetStringWidth() or 0
    return w > TITLE_MAX_W
end

local CreateIconButton = EbonBuilds.UIHelpers.CreateIconButton

------------------------------------------------------------------------
-- Row factory
------------------------------------------------------------------------

local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetPoint("LEFT",  parent, "LEFT",  0, 0)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:SetHeight(ROW_SINGLE)

    -- Left accent stripe
    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetPoint("TOPLEFT",      row, "TOPLEFT",      2, -2)
    stripe:SetPoint("BOTTOMLEFT",   row, "BOTTOMLEFT",   2,  2)
    stripe:SetWidth(4)
    row._stripe = stripe

    -- Class-colored background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT",      row, "TOPLEFT",      6, -2)
    bg:SetPoint("BOTTOMRIGHT",  row, "BOTTOMRIGHT", -2,  2)
    row._bg = bg

    -- Selected highlight
    local selected = row:CreateTexture(nil, "BACKGROUND")
    selected:SetAllPoints(row)
    selected:SetTexture(0.2, 0.5, 0.9, 0.18)
    selected:Hide()
    row._selected = selected

    -- Hover highlight
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT",      row, "TOPLEFT",      6, -2)
    hl:SetPoint("BOTTOMRIGHT",  row, "BOTTOMRIGHT", -2,  2)
    hl:SetTexture(1, 1, 1, 0.08)
    hl:Hide()
    row:SetScript("OnEnter", function() hl:Show() end)
    row:SetScript("OnLeave", function() hl:Hide() end)

    -- Build icon button (18x18, top-left, hidden if no custom icon)
    local buildBtn = CreateIconButton(row, 18)
    buildBtn:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -6)
    buildBtn:Hide()
    row._buildBtn = buildBtn

    -- Class icon button (22x22, bottom-right)
    local classBtn = CreateIconButton(row, 22)
    classBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 4)
    row._classBtn = classBtn

    -- Spec icon button (22x22, to the left of class icon, side-by-side at bottom)
    local specBtn = CreateIconButton(row, 22)
    specBtn:SetPoint("BOTTOMRIGHT", classBtn, "BOTTOMLEFT", -4, 0)
    row._specBtn = specBtn

    -- Title label (top area, after build icon, before active badge)
    local titleLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT",  row, "TOPLEFT",  10, -2)
    titleLabel:SetPoint("RIGHT",    row, "RIGHT",   -60, 0)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetHeight(0)
    row._titleLabel = titleLabel

    -- Locked echo icon buttons (22x22, bottom row)
    row._lockedBtns = {}
    for i = 1, 5 do
        local btn = CreateIconButton(row, 22)
        btn:Hide()
        row._lockedBtns[i] = btn
    end

    -- Active badge
    local activeBadge = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    activeBadge:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
    activeBadge:SetText("|cff19ff19ACTIVE|r")
    activeBadge:Hide()
    row._activeBadge = activeBadge

    return row
end

local function WireNavigate(btn, build)
    btn:SetScript("OnClick", function()
        EbonBuilds.ViewRouter.Show("buildOverview", { build = build })
    end)
end

local LOCKED_X_START = 10
local LOCKED_STEP    = 28

local function PopulateRow(row, build, activeId, yOffset)
    local isActive = (build.id == activeId)
    local classToken = build.class
    local cc = CLASS_COLORS[classToken] or { 0.5, 0.5, 0.5 }

    local twoLines = NeedsTwoLines(build.title)
    local rowHeight = twoLines and ROW_DOUBLE or ROW_SINGLE
    row:SetHeight(rowHeight)

    row:ClearAllPoints()
    row:SetPoint("LEFT",  scrollChild, "LEFT",  0, 0)
    row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
    row:SetPoint("TOP",   scrollChild, "TOP",   0, -yOffset)

    -- Stripe and background
    if isActive then
        row._stripe:SetWidth(6)
        row._stripe:SetTexture(cc[1], cc[2], cc[3], 1.0)
        row._bg:SetTexture(cc[1], cc[2], cc[3], 0.12)
        row._selected:Show()
        row._activeBadge:Show()
    else
        row._stripe:SetWidth(4)
        row._stripe:SetTexture(cc[1], cc[2], cc[3], 0.6)
        row._bg:SetTexture(cc[1], cc[2], cc[3], 0.06)
        row._selected:Hide()
        row._activeBadge:Hide()
    end

    -- Build icon (if set)
    if build.buildIcon then
        row._buildBtn._icon:SetTexture(build.buildIcon)
        row._buildBtn:Show()
        EbonBuilds.UIHelpers.WireTooltip(row._buildBtn, function(self)
            GameTooltip:SetText("Build icon", 1, 0.82, 0)
        end)
        WireNavigate(row._buildBtn, build)
    else
        row._buildBtn:Hide()
    end

    -- Class icon (hide when allClasses)
    if not build.allClasses and classToken then
        EbonBuilds.UIHelpers.SetClassIcon(row._classBtn._icon, classToken)
        row._classBtn:Show()
        EbonBuilds.UIHelpers.WireTooltip(row._classBtn, function(self)
            GameTooltip:SetText(classToken or "Unknown", 1, 1, 1)
        end)
        WireNavigate(row._classBtn, build)
    else
        row._classBtn:Hide()
    end

    -- Spec icon (hide when allClasses, side-by-side with class)
    local specs = not build.allClasses and classToken and EbonBuilds.SpecData and EbonBuilds.SpecData[classToken]
    local specEntry = specs and specs[build.spec or 1]
    if specEntry then
        row._specBtn._icon:SetTexture(specEntry.icon)
        row._specBtn:Show()
        EbonBuilds.UIHelpers.WireTooltip(row._specBtn, function(self)
            GameTooltip:SetText(specEntry.name, 1, 1, 1)
        end)
        WireNavigate(row._specBtn, build)
    else
        row._specBtn:Hide()
    end

    -- Title anchors after build icon (class/spec are at bottom row)
    if build.buildIcon and row._buildBtn:IsShown() then
        row._titleLabel:ClearAllPoints()
        row._titleLabel:SetPoint("TOPLEFT", row._buildBtn, "TOPRIGHT", 6, -2)
        row._titleLabel:SetPoint("RIGHT", row, "RIGHT", -60, 0)
    else
        row._titleLabel:ClearAllPoints()
        row._titleLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -2)
        row._titleLabel:SetPoint("RIGHT", row, "RIGHT", -60, 0)
    end

    -- Title (class-colored)
    local title = build.title or "Untitled"
    row._titleLabel:SetText(title)
    row._titleLabel:SetTextColor(cc[1], cc[2], cc[3], 1)
    if twoLines then
        row._titleLabel:SetWidth(TITLE_MAX_W)
        row._titleLabel:SetHeight(28)
    else
        row._titleLabel:SetWidth(0)
        row._titleLabel:SetHeight(0)
    end

    -- Locked echo icons
    local lockeds = build.lockedEchoes
    for i = 1, 5 do
        local btn = row._lockedBtns[i]
        local spellId = lockeds and lockeds[i]
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", LOCKED_X_START + (i - 1) * LOCKED_STEP, 4)
        if spellId then
            btn._icon:SetTexture(select(3, GetSpellInfo(spellId)))
            btn._spellId = spellId
            btn:Show()

            EbonBuilds.UIHelpers.WireLockedIconTooltip(btn)
            WireNavigate(btn, build)
        else
            btn:Hide()
        end
    end

    WireNavigate(row, build)
    row:Show()
end

------------------------------------------------------------------------
-- Render
------------------------------------------------------------------------

local function Render()
    local builds   = EbonBuilds.Build.List()
    local activeId = EbonBuildsCharDB.activeBuildId
    local yOffset = 0
    for i = 1, #builds do
        if not rowPool[i] then rowPool[i] = CreateRow(scrollChild) end
        PopulateRow(rowPool[i], builds[i], activeId, yOffset)
        yOffset = yOffset + (NeedsTwoLines(builds[i].title) and ROW_DOUBLE or ROW_SINGLE) + CARD_MARGIN
    end
    for i = #builds + 1, #rowPool do rowPool[i]:Hide() end

    scrollChild:SetHeight(math.max(1, yOffset))
end

EbonBuilds.BuildList.Refresh = Render

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------

local function CreatePublicBuildsButton(parent)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetHeight(24)
    btn:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    btn:SetText("Public Builds")
    btn:SetScript("OnClick", function()
        EbonBuilds.ViewRouter.Show("publicBuilds")
    end)
    return btn
end

local function CreateImportButton(parent)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetHeight(24)
    btn:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    btn:SetText("Import Build")
    btn:SetScript("OnClick", function()
        EbonBuilds.ExportImport.ShowImportDialog()
    end)
    return btn
end

local function CreateNewBuildButton(parent, topAnchor)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetHeight(24)
    btn:SetPoint("TOPLEFT",  topAnchor, "BOTTOMLEFT",  0, -2)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    btn:SetText("+ New Build")
    btn:SetScript("OnClick", function()
        EbonBuilds.ViewRouter.Show("buildWizard")
    end)
    return btn
end

local function CreateScrollArea(parent, topAnchor)
    local sf = CreateFrame("ScrollFrame", "EbonBuildsBuildListSF", parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     topAnchor, "BOTTOMLEFT",  0, -4)
    sf:SetPoint("BOTTOMRIGHT", parent,    "BOTTOMRIGHT", -22, 0)

    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(1)
    child:SetHeight(1)
    sf:SetScrollChild(child)
    return sf, child
end

function EbonBuilds.BuildList.Init(parent)
    container       = parent
    publicBuildsBtn = CreatePublicBuildsButton(parent)
    importBtn       = CreateImportButton(parent)
    newBuildBtn     = CreateNewBuildButton(parent, importBtn)
    scrollFrame, scrollChild = CreateScrollArea(parent, newBuildBtn)

    importBtn:SetPoint("TOPLEFT",  publicBuildsBtn, "BOTTOMLEFT",  0, -2)
    importBtn:SetPoint("TOPRIGHT", parent,          "TOPRIGHT",    0,  0)

    titleMeasureFont = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleMeasureFont:Hide()

    scrollChild:SetWidth(parent:GetWidth() - 22)
    parent:SetScript("OnSizeChanged", function()
        scrollChild:SetWidth(parent:GetWidth() - 22)
        Render()
    end)

    Render()

    if EbonBuilds.Build and EbonBuilds.Build.OnActiveChanged then
        EbonBuilds.Build.OnActiveChanged(Render)
    end
end
