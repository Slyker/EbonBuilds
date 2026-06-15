-- EbonBuilds: modules/ui/BuildOverview/EchoesTab.lua
-- Echoes tab: currently active/owned echoes with search, quality filter,
-- sort options, and a grid display.

local BO = EbonBuilds.BuildOverview
local UIH = EbonBuilds.UIHelpers
local QUALITY_COLORS = EbonBuilds.Constants.QUALITY_COLORS
local EchoesData = BO.EchoesData

local ECHO_QUALITY_LABELS = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local ECHO_SORT_LABELS = { "Quality", "Name", "Stacks", "Timestamp", "Score" }

local ECHO_ICON_SIZE   = 52
local ECHO_ICON_PAD    = 20
local ECHO_COL_GAP     = 14
local ECHO_NAME_H      = 26
local ECHO_CELL_W      = ECHO_ICON_SIZE + ECHO_COL_GAP
local ECHO_CELL_H      = ECHO_ICON_SIZE + 6 + ECHO_NAME_H
local ECHO_COLS        = 6

------------------------------------------------------------------------
-- BuildEchoesTab: construct the echoes header + scroll frame
------------------------------------------------------------------------

local function BuildEchoesTab(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -8)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -8)
    header:SetHeight(28)

    local edit, searchFrame = UIH.CreateSearchBox(header, 160, 22, function(text)
        BO.echoesSearchText = text
        BO.RefreshEchoes()
    end)
    searchFrame:SetPoint("LEFT", header, "LEFT", 0, 0)
    BO.echoesSearchBox = edit

    local qualityDD = CreateFrame("Frame", "EbonBuildsEchoQualityDD", header, "UIDropDownMenuTemplate")
    qualityDD:SetPoint("LEFT", searchFrame, "RIGHT", -4, -2)
    UIDropDownMenu_Initialize(qualityDD, function()
        for i, name in ipairs(ECHO_QUALITY_LABELS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.func = function()
                BO.echoesQualityFilter = i - 2
                UIDropDownMenu_SetText(qualityDD, name)
                BO.RefreshEchoes()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(qualityDD, 80)
    UIDropDownMenu_SetText(qualityDD, "All")

    local sortDD = CreateFrame("Frame", "EbonBuildsEchoSortDD", header, "UIDropDownMenuTemplate")
    sortDD:SetPoint("LEFT", qualityDD, "RIGHT", -8, 0)
    UIDropDownMenu_Initialize(sortDD, function()
        for i, name in ipairs(ECHO_SORT_LABELS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.func = function()
                BO.echoesSortMode = i
                UIDropDownMenu_SetText(sortDD, name)
                BO.RefreshEchoes()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(sortDD, 80)
    UIDropDownMenu_SetText(sortDD, "Quality")

    local showAllCB = UIH.CreateCheckButton(header, "All", function(self, checked)
        BO.echoesShowAll = checked
        BO.RefreshEchoes()
    end)
    showAllCB:SetPoint("LEFT", sortDD, "RIGHT", 8, 0)
    showAllCB:SetChecked(BO.echoesShowAll)

    local scroll, child, bar = UIH.CreateScroller(parent)
    scroll:SetPoint("TOPLEFT",     header, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -18, 8)
    child:SetWidth(460)
    UIH.WireScroller(scroll, bar, 16, child)

    return scroll, child, bar
end

------------------------------------------------------------------------
-- RefreshEchoes: rebuild the echoes grid
------------------------------------------------------------------------

local function RefreshEchoes()
    local echoesChild = BO.echoesChild
    local echoesBar = BO.echoesBar
    local echoesScroll = BO.echoesScroll
    local echoesRows = BO.echoesRows
    if not echoesChild then return end
    for _, btn in ipairs(echoesRows) do btn:Hide() end

    local owned = BO.echoesShowAll and EchoesData.ComputeAllEchoes() or EchoesData.ComputeOwnedEchoes()

    local filtered = {}
    for _, entry in ipairs(owned) do
        local matchSearch = BO.echoesSearchText == "" or entry.name:lower():find(BO.echoesSearchText, 1, true)
        local matchQuality = BO.echoesQualityFilter == -1 or entry.quality == BO.echoesQualityFilter
        if matchSearch and matchQuality then
            filtered[#filtered + 1] = entry
        end
    end

    if BO.echoesSortMode == 1 then
        table.sort(filtered, function(a, b)
            if a.quality ~= b.quality then return a.quality > b.quality end
            return a.name < b.name
        end)
    elseif BO.echoesSortMode == 2 then
        table.sort(filtered, function(a, b) return a.name < b.name end)
    elseif BO.echoesSortMode == 3 then
        table.sort(filtered, function(a, b)
            return (a.stack or 1) > (b.stack or 1)
        end)
    elseif BO.echoesSortMode == 4 then
        local timestamps = EchoesData.ComputeLastPickedTimestamps()
        table.sort(filtered, function(a, b)
            local ta = timestamps[a.name] or 0
            local tb = timestamps[b.name] or 0
            if ta ~= tb then return ta > tb end
            if a.quality ~= b.quality then return a.quality > b.quality end
            return a.name < b.name
        end)
    elseif BO.echoesSortMode == 5 then
        local settings = EbonBuilds.Scoring.GetEffectiveSettings()
        table.sort(filtered, function(a, b)
            local sa = EbonBuilds.Scoring.Score(a, EbonBuilds.Weights.Get(a.name), settings)
            local sb = EbonBuilds.Scoring.Score(b, EbonBuilds.Weights.Get(b.name), settings)
            if sa ~= sb then return sa > sb end
            if a.quality ~= b.quality then return a.quality > b.quality end
            return a.name < b.name
        end)
    end

    for i, entry in ipairs(filtered) do
        local idx = #echoesRows + 1
        while #echoesRows < idx do
            local n = #echoesRows + 1
            local btn = CreateFrame("Button", nil, echoesChild)
            btn:SetSize(ECHO_CELL_W, ECHO_CELL_H)

            local border = btn:CreateTexture(nil, "BORDER")
            border:SetTexture("Interface\\Buttons\\WHITE8x8")
            border:SetVertexColor(0.5, 0.5, 0.5, 1)
            border:SetSize(ECHO_ICON_SIZE + 4, ECHO_ICON_SIZE + 4)
            border:SetPoint("TOP", btn, "TOP", 0, -2)
            btn._border = border

            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(ECHO_ICON_SIZE, ECHO_ICON_SIZE)
            icon:SetPoint("CENTER", border, "CENTER", 0, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            btn._icon = icon

            local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
            highlight:SetBlendMode("ADD")
            highlight:SetSize(ECHO_ICON_SIZE, ECHO_ICON_SIZE)
            highlight:SetPoint("CENTER", icon, "CENTER", 0, 0)

            local bannedOverlay = btn:CreateTexture(nil, "OVERLAY")
            bannedOverlay:SetTexture("Interface\\Buttons\\WHITE8x8")
            bannedOverlay:SetVertexColor(0.8, 0.1, 0.1, 0.45)
            bannedOverlay:SetSize(ECHO_ICON_SIZE, ECHO_ICON_SIZE)
            bannedOverlay:SetPoint("CENTER", icon, "CENTER", 0, 0)
            bannedOverlay:Hide()
            btn._bannedOverlay = bannedOverlay

            local bannedText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            bannedText:SetPoint("CENTER", icon, "CENTER", 0, 0)
            bannedText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
            bannedText:SetText("BANNED")
            bannedText:SetTextColor(1, 0.3, 0.3, 1)
            bannedText:Hide()
            btn._bannedText = bannedText

            local lockIcon = btn:CreateTexture(nil, "OVERLAY")
            lockIcon:SetTexture("Interface\\Buttons\\UI-ActionButton-Borders")
            lockIcon:SetSize(18, 18)
            lockIcon:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
            lockIcon:SetTexCoord(0.25, 0.5, 0.25, 0.5)
            lockIcon:SetVertexColor(1, 0.84, 0, 0.8)
            lockIcon:Hide()
            btn._lockIcon = lockIcon

            local stackText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            stackText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
            stackText:SetTextColor(1, 1, 1)
            stackText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
            btn._stackText = stackText

            local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameText:SetPoint("TOP", icon, "BOTTOM", 0, -2)
            nameText:SetWidth(ECHO_CELL_W + 10)
            nameText:SetHeight(ECHO_NAME_H)
            nameText:SetJustifyH("CENTER")
            nameText:SetJustifyV("TOP")
            nameText:SetWordWrap(true)
            nameText:SetFont("Fonts\\FRIZQT__.TTF", 11)
            btn._nameText = nameText

            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:SetScript("OnEnter", function(self)
                if self._echoName then
                    EbonBuilds.SessionHistory.ShowEchoTooltip(self, self._echoName, false)
                end
            end)
            btn:SetScript("OnLeave", function()
                EbonBuilds.SessionHistory.HideEchoTooltip()
            end)
            btn:SetScript("OnMouseDown", function(self, button)
                if button == "RightButton" and self._echoName then
                    EbonBuilds.SessionHistory.ShowContextMenu(self, self._echoName)
                end
            end)

            echoesRows[n] = btn
        end

        local btn = echoesRows[idx]
        btn._echoName = entry.name

        local qc = QUALITY_COLORS[entry.quality] or QUALITY_COLORS[0]

        local tex = select(3, GetSpellInfo(entry.spellId))
        btn._icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")

        local stack = entry.stack or 0
        local maxStack = entry.maxStack or 1
        if maxStack > 1 then
            if stack > 0 then
                btn._stackText:SetText(stack .. "/" .. maxStack)
            else
                btn._stackText:SetText("0/" .. maxStack)
            end
            btn._stackText:Show()
        else
            if stack > 0 then
                btn._stackText:SetText("x" .. stack)
            else
                btn._stackText:SetText("0")
            end
            btn._stackText:Show()
        end

        btn._nameText:SetText(entry.name)
        btn._nameText:SetTextColor(qc[1], qc[2], qc[3])

        local banned = EbonBuilds.Scoring and EbonBuilds.Scoring.IsBanned and EbonBuilds.Scoring.IsBanned(entry.spellId)
        if banned then
            btn._icon:SetDesaturated(true)
            btn._icon:SetAlpha(0.5)
            btn._border:SetVertexColor(0.6, 0.1, 0.1, 1)
            btn._bannedOverlay:Show()
            btn._bannedText:Show()
        else
            btn._icon:SetDesaturated(false)
            btn._icon:SetAlpha(1)
            btn._border:SetVertexColor(qc[1], qc[2], qc[3], 1)
            btn._bannedOverlay:Hide()
            btn._bannedText:Hide()
        end

        if entry.locked then
            btn._lockIcon:Show()
        else
            btn._lockIcon:Hide()
        end

        if BO.echoesShowAll and not entry.owned then
            btn:SetAlpha(0.5)
        else
            btn:SetAlpha(1)
        end

        local col = (i - 1) % ECHO_COLS
        local row = math.floor((i - 1) / ECHO_COLS)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", echoesChild, "TOPLEFT",
            10 + col * ECHO_CELL_W,
            -10 - row * ECHO_CELL_H)
        btn:Show()
    end

    local numRows = math.ceil(#filtered / ECHO_COLS)
    local totalH = numRows * ECHO_CELL_H + 20
    echoesChild:SetHeight(math.max(1, totalH))
    echoesBar:SetMinMaxValues(0, math.max(0, totalH - (echoesScroll:GetHeight() or 0)))
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

BO.BuildEchoesTab = BuildEchoesTab
BO.RefreshEchoes = RefreshEchoes
