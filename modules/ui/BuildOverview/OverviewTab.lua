-- EbonBuilds: modules/ui/BuildOverview/OverviewTab.lua
-- Overview tab: build icon, title, class/spec selection, meta text,
-- status label, locked echoes, automation toggle, description, delete.

local BO = EbonBuilds.BuildOverview
local UIH = EbonBuilds.UIHelpers
local CreateIconButton = UIH.CreateIconButton
local CLASS_COLORS = EbonBuilds.Constants.CLASS_COLORS
local QUALITY_BORDER_COLORS = EbonBuilds.Constants.QUALITY_BORDER_COLORS
local EMPTY_SLOT = EbonBuilds.Constants.EMPTY_SLOT_TEXTURE
local ApplyQualityBorder = UIH.ApplyQualityBorder

local CLASS_ORDER = EbonBuilds.Constants.CLASS_ORDER

------------------------------------------------------------------------
-- Helpers shared across overview sub-operations
------------------------------------------------------------------------

local function RefreshClassSelection()
    local build = BO.state.build
    local outer = BO.overviewOuter
    if not build or not outer then return end
    for token, btn in pairs(outer._classButtons) do
        local highlight = not build.allClasses and token == build.class
        UIH.HighlightBorder(btn, highlight)
        if build.allClasses then
            btn:SetAlpha(0.35)
        else
            btn:SetAlpha(1.0)
        end
    end
end

local function RefreshSpecButtons()
    local build = BO.state.build
    local outer = BO.overviewOuter
    if not build or not outer then return end
    if build.allClasses then
        for i = 1, 3 do
            outer._specButtons[i]:Hide()
        end
        outer._specLabel:Hide()
        return
    end
    outer._specLabel:Show()
    local specs = build.class and EbonBuilds.SpecData and EbonBuilds.SpecData[build.class]
    for i = 1, 3 do
        local btn = outer._specButtons[i]
        local entry = specs and specs[i]
        local icon  = entry and entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
        if btn._icon then btn._icon:SetTexture(icon) end
        UIH.HighlightBorder(btn, i == build.spec)
        btn:Show()
    end
end

local function MetaText(build)
    if not build then return "" end
    if build.allClasses then
        return string.format("by %s | %s",
            build.author or "Unknown",
            build.lastModified or "")
    end
    local cc = CLASS_COLORS[build.class]
    local classStr
    if cc then
        classStr = string.format("|cff%02x%02x%02x%s|r", cc[1] * 255, cc[2] * 255, cc[3] * 255, build.class or "?")
    else
        classStr = build.class or "?"
    end
    local specs = build.class and EbonBuilds.SpecData and EbonBuilds.SpecData[build.class]
    local specName = specs and specs[build.spec or 1] and specs[build.spec or 1].name or ""
    return string.format("by %s | %s | %s | %s",
        build.author or "Unknown",
        classStr,
        specName,
        build.lastModified or "")
end

local function RefreshMetaAndStatus()
    local build = BO.state.build
    local outer = BO.overviewOuter
    if not build or not outer then return end
    outer._metaLabel:SetText(MetaText(build))

    local publicText = build.isPublic and "|cff19ff19Public|r" or "|cff888888Private|r"
    local validatedText
    if build.validated then
        validatedText = " |cff19ff19(Validated)|r"
    elseif build.isPublic then
        validatedText = " |cffff4444(Not Validated)|r"
    else
        validatedText = ""
    end
    outer._statusLabel:SetText(publicText .. validatedText)
end

------------------------------------------------------------------------
-- RefreshOverview: sync all overview widgets with current build
------------------------------------------------------------------------

local function RefreshOverview()
    local build = BO.state.build
    local outer = BO.overviewOuter
    local descEdit = BO.overviewDescEdit
    if not build or not outer then return end

    if build.buildIcon then
        outer._classIcon:SetTexture(build.buildIcon)
        outer._classIcon:SetTexCoord(0, 1, 0, 1)
    else
        UIH.SetClassIcon(outer._classIcon, build.class)
    end

    if not outer._titleBox:HasFocus() then
        outer._titleBox:SetText(build.title or "Untitled")
    end

    if outer._allClassesCB then
        outer._allClassesCB:SetChecked(build.allClasses)
    end

    RefreshClassSelection()
    RefreshSpecButtons()
    RefreshMetaAndStatus()

    local isActive = (build.id == EbonBuildsCharDB.activeBuildId)
    if outer._activateBtn then
        outer._activateBtn:SetShown(not isActive)
    end

    local desc = build.comments or ""
    if not descEdit:HasFocus() then
        descEdit._skip = true
        descEdit:SetText(desc)
        descEdit._skip = nil
    end
    outer._descMeasure:SetText(desc)
    local th = outer._descMeasure:GetStringHeight() or 0
    local sh = outer._descScroll:GetHeight()
    local eh = math.max(th + 10, sh)
    outer._descChild:SetHeight(eh)
    descEdit:SetHeight(eh)
    outer._descBar:SetMinMaxValues(0, math.max(0, eh - sh))
    outer._descScroll:SetVerticalScroll(0)
    outer._descBar:SetValue(0)

    for i = 1, 5 do
        local btn = outer._lockedButtons[i]
        local spellId = build.lockedEchoes and build.lockedEchoes[i]
        if spellId then
            btn._icon:SetTexture(select(3, GetSpellInfo(spellId)))
            btn._spellId = spellId
            btn:Show()
            local data = ProjectEbonhold.PerkDatabase[spellId]
            local quality = data and data.quality or 0
            ApplyQualityBorder(btn._border, quality)
        else
            btn._icon:SetTexture(EMPTY_SLOT)
            btn._spellId = nil
            btn._border:Hide()
            btn:Show()
        end
    end
end

------------------------------------------------------------------------
-- BuildOverviewTab: construct the overview content frame
------------------------------------------------------------------------

local function BuildOverviewTab(parent)
    local outer = CreateFrame("Frame", nil, parent)
    outer:SetAllPoints(parent)
    outer:EnableMouse(true)
    outer:SetScript("OnMouseDown", function()
        outer._titleBox:ClearFocus()
        outer._descEdit:ClearFocus()
    end)

    local classIconBtn = CreateFrame("Button", nil, outer)
    classIconBtn:SetWidth(28)
    classIconBtn:SetHeight(28)
    classIconBtn:SetPoint("TOPLEFT", outer, "TOPLEFT", 10, -10)
    local classIcon = classIconBtn:CreateTexture(nil, "ARTWORK")
    classIcon:SetAllPoints(classIconBtn)

    local iconPicker = UIH.CreateIconPicker{
        onPick = function(path)
            local b = BO.state.build
            if not b then return end
            b.buildIcon = path
            classIcon:SetTexture(path)
            classIcon:SetTexCoord(0, 1, 0, 1)
            BO.MarkDirty()
        end,
        onMakePoolBtn = function(btn)
            UIH.WireTooltip(btn, function(self)
                if not self._path then return false end
                local name = self._path:match("([^\\]+)$")
                GameTooltip:AddLine(name or self._path, 1, 0.82, 0)
            end)
        end,
    }
    local picker = iconPicker.frame
    local catcher = iconPicker.catcher
    outer._iconPicker = picker

    classIconBtn:SetScript("OnClick", function()
        local build = BO.state.build
        if not build then return end
        if picker:IsShown() then
            picker:Hide()
        else
            picker:ClearAllPoints()
            picker:SetPoint("TOPLEFT", classIconBtn, "BOTTOMLEFT", -2, -2)
            catcher:Show()
            picker:Show()
        end
    end)
    UIH.WireTooltip(classIconBtn, function()
        GameTooltip:AddLine("Choose build icon", 1, 0.82, 0)
    end)
    outer._classIconBtn = classIconBtn
    outer._classIcon = classIcon

    local titleBox, titleBg = UIH.CreateEditBox(outer, nil, 26, {
        backdrop = "chat",
        fontSize = 13,
        textColorR = 1, textColorG = 0.82, textColorB = 0,
        maxLetters = 80,
    })
    titleBg:SetPoint("TOPLEFT",  classIcon, "TOPRIGHT", 4, -2)
    titleBg:SetPoint("RIGHT",    outer,     "RIGHT",    -12, 0)
    titleBg:SetHeight(26)
    titleBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local build = BO.state.build
        if not build then return end
        local new = self:GetText() or ""
        if new ~= (build.title or "") then
            build.title = new
            BO.MarkDirty()
            BO.overviewOuter._metaLabel:SetText(MetaText(build))
        end
    end)
    titleBox:SetScript("OnEditFocusLost", function(self)
        local build = BO.state.build
        if not build then return end
        local new = self:GetText() or ""
        if new ~= (build.title or "") then
            build.title = new
            BO.MarkDirty()
        end
    end)
    outer._titleBox = titleBox

    local classLabel = outer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classLabel:SetPoint("TOPLEFT", classIcon, "BOTTOMLEFT", 0, -6)
    classLabel:SetText("Class:")
    outer._classLabel = classLabel

    local classButtons = {}
    for i, token in ipairs(CLASS_ORDER) do
        local btn = UIH.CreateIconButton(outer, 28)
        UIH.SetClassIcon(btn._icon, token)
        btn:SetPoint("TOPLEFT", classLabel, "BOTTOMLEFT", (i - 1) * 30 + 6, -4)
        btn:SetScript("OnClick", function()
            local build = BO.state.build
            if not build or build.allClasses or build.class == token then return end
            build.class = token
            if build.spec and build.spec > 3 then build.spec = 1 end
            RefreshClassSelection()
            RefreshSpecButtons()
            RefreshMetaAndStatus()
            BO.MarkDirty()
        end)
        UIH.WireTooltip(btn, function() GameTooltip:AddLine(token, 1, 0.82, 0) end)
        classButtons[token] = btn
    end
    outer._classButtons = classButtons

    local lastBtn = classButtons[CLASS_ORDER[#CLASS_ORDER]]
    local allClassesCB = CreateFrame("CheckButton", nil, outer, "UICheckButtonTemplate")
    allClassesCB:SetPoint("LEFT", lastBtn, "RIGHT", 10, 0)
    allClassesCB:SetPoint("TOP", lastBtn, "TOP", 0, 0)
    allClassesCB:SetHitRectInsets(0, 0, -6, 6)
    local cbText = allClassesCB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbText:SetPoint("LEFT", allClassesCB, "RIGHT", 4, 0)
    cbText:SetText("All Classes")
    cbText:SetTextColor(0.8, 0.8, 0.8)
    allClassesCB:SetScript("OnClick", function(self)
        local build = BO.state.build
        if not build then return end
        build.allClasses = self:GetChecked()
        RefreshClassSelection()
        RefreshSpecButtons()
        RefreshMetaAndStatus()
        BO.MarkDirty()
    end)
    outer._allClassesCB = allClassesCB

    local specLabel = outer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    specLabel:SetPoint("TOPLEFT", classLabel, "BOTTOMLEFT", 0, -32)
    specLabel:SetText("Spec:")
    outer._specLabel = specLabel

    local specButtons = {}
    for i = 1, 3 do
        local btn = UIH.CreateIconButton(outer, 30)
        btn._icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        btn:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", (i - 1) * 34 + 6, -4)
        btn:SetScript("OnClick", function()
            local build = BO.state.build
            if not build or build.allClasses then return end
            if build.spec == i then return end
            build.spec = i
            RefreshSpecButtons()
            RefreshMetaAndStatus()
            BO.MarkDirty()
        end)
        UIH.WireTooltip(btn, function()
            local build = BO.state.build
            local specs = build and EbonBuilds.SpecData and EbonBuilds.SpecData[build.class]
            local name = specs and specs[i] and specs[i].name or ("Spec " .. i)
            GameTooltip:AddLine(name, 1, 0.82, 0)
        end)
        specButtons[i] = btn
    end
    outer._specButtons = specButtons

    local metaLabel = outer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    metaLabel:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", -40, 10)
    metaLabel:SetJustifyH("RIGHT")
    outer._metaLabel = metaLabel

    local statusFrame = CreateFrame("Button", nil, outer)
    statusFrame:SetPoint("BOTTOMRIGHT", metaLabel, "TOPRIGHT", 0, 4)
    statusFrame:SetWidth(200)
    statusFrame:SetHeight(16)
    local statusLabel = statusFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusLabel:SetAllPoints(statusFrame)
    statusLabel:SetJustifyH("RIGHT")
    UIH.WireTooltip(statusFrame, function(self)
        local build = BO.state.build
        if not build or not build.isPublic then return false end
        GameTooltip:AddLine("Public Build", 1, 0.82, 0, 1)
        GameTooltip:AddLine("Public builds require validation to appear in the browser.", 0.8, 0.8, 0.8, 1)
        GameTooltip:AddLine("Level a character from 1 to 80 using this build to validate it.", 0.6, 0.6, 0.6, 1)
    end)
    outer._statusLabel = statusLabel

    local lockedHeader = outer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lockedHeader:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -44)
    lockedHeader:SetText("Locked Echoes:")
    outer._lockedHeader = lockedHeader

    local detectBtn = CreateFrame("Button", nil, outer, "UIPanelButtonTemplate")
    detectBtn:SetSize(80, 18)
    detectBtn:SetPoint("LEFT", lockedHeader, "RIGHT", 8, 0)
    detectBtn:SetText("Detect")
    detectBtn:SetScript("OnClick", function()
        local build = BO.state.build
        if not build then return end
        local total = EbonBuilds.Build.AutoDetectLockedSlots()
        if total == 0 then
            print("|cffFF6600EbonBuilds:|r No locked echoes found on this character.")
            return
        end
        local serverLocked = EbonBuilds.Build.GetServerLockedPerks()
        local current = build.lockedEchoes or {}
        local filled = {}
        for i = 1, 5 do
            if current[i] then filled[current[i]] = true end
        end
        local added = 0
        for _, inst in ipairs(serverLocked) do
            if inst.spellId and not filled[inst.spellId] then
                for i = 1, 5 do
                    if not build.lockedEchoes or not build.lockedEchoes[i] then
                        build.lockedEchoes = build.lockedEchoes or {}
                        build.lockedEchoes[i] = inst.spellId
                        filled[inst.spellId] = true
                        added = added + 1
                        break
                    end
                end
            end
        end
        BO.MarkDirty()
        RefreshOverview()
        print("|cff19ff19EbonBuilds:|r Auto-detected " .. total .. " locked echoes, added " .. added .. " to build.")
    end)

    local lockedButtons = {}
    for i = 1, 5 do
        local btn = CreateIconButton(outer, 36)
        btn:SetPoint("TOPLEFT", lockedHeader, "BOTTOMLEFT", (i - 1) * 42, -6)
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        UIH.CreateQualityBorder(btn)
        UIH.WireLockedIconTooltip(btn)

        local idx = i
        btn:SetScript("OnClick", function(_, button)
            local build = BO.state.build
            if not build then return end
            build.lockedEchoes = build.lockedEchoes or {}

            if button == "RightButton" then
                build.lockedEchoes[idx] = nil
                btn._icon:SetTexture(EMPTY_SLOT)
                btn._spellId = nil
                btn._border:Hide()
                BO.MarkDirty()
                return
            end

            local banList = build.settings and build.settings.echoBanList or {}
            local allList = EbonBuilds.EchoTableRows.BuildAllQualitiesList()
            local filtered = {}
            for _, entry in ipairs(allList) do
                if not banList[entry.spellId] then
                    local alreadyLocked = false
                    for j = 1, 5 do
                        if j ~= idx and build.lockedEchoes[j] == entry.spellId then
                            alreadyLocked = true
                            break
                        end
                    end
                    if not alreadyLocked then
                        filtered[#filtered + 1] = entry
                    end
                end
            end
            EbonBuilds.EchoPicker.Show(function(spellId, quality, name)
                build.lockedEchoes[idx] = spellId
                btn._spellId = spellId
                btn._icon:SetTexture(select(3, GetSpellInfo(spellId)))
                ApplyQualityBorder(btn._border, quality)
                BO.MarkDirty()
            end, filtered)
        end)

        lockedButtons[i] = btn
    end
    outer._lockedButtons = lockedButtons

    local activateBtn = CreateFrame("Button", nil, outer, "UIPanelButtonTemplate")
    activateBtn:SetWidth(120)
    activateBtn:SetHeight(22)
    activateBtn:SetPoint("TOPLEFT", lockedButtons[1], "BOTTOMLEFT", 0, -22)
    activateBtn:SetText("Activate")
    activateBtn:SetScript("OnClick", function()
        local build = BO.state.build
        if not build then return end
        EbonBuilds.Build.SetActive(build.id)
        if EbonBuilds.BuildList and EbonBuilds.BuildList.Refresh then
            EbonBuilds.BuildList.Refresh()
        end
        outer._activateBtn:Hide()
        print("|cff19ff19EbonBuilds:|r Activated \"" .. (build.title or "Untitled") .. "\"")
    end)
    outer._activateBtn = activateBtn

    local descHeader = outer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descHeader:SetPoint("TOPLEFT", activateBtn, "BOTTOMLEFT", 0, -14)
    descHeader:SetText("Description:")
    outer._descHeader = descHeader

    local desc = UIH.CreateDescriptionEditor(outer, function(self, text)
        local b = BO.state.build
        if b and not self._skip then b.comments = text end
    end)
    desc.backdrop:SetPoint("TOPLEFT",     descHeader, "BOTTOMLEFT", 0, -4)
    desc.backdrop:SetPoint("BOTTOMRIGHT", outer,      "BOTTOMRIGHT", -10, 28)
    outer._descEdit = desc.editBox
    outer._descScroll = desc.scroll
    outer._descChild  = desc.child
    outer._descBar    = desc.bar
    outer._descMeasure = desc.measure
    local descEdit = desc.editBox

    local deleteBtn = CreateFrame("Button", nil, outer, "UIPanelButtonTemplate")
    deleteBtn:SetSize(64, 20)
    deleteBtn:SetPoint("BOTTOMLEFT", outer, "BOTTOMLEFT", 10, 4)
    deleteBtn:SetText("Delete")
    deleteBtn:SetScript("OnClick", function()
        local build = BO.state.build
        if not build then return end
        local name = build.title or "Untitled"
        StaticPopupDialogs["EBONBUILDS_DELETE_BUILD"].text = "Delete build \"" .. name .. "\"?\n\nThis action cannot be undone."
        StaticPopup_Show("EBONBUILDS_DELETE_BUILD")
    end)
    outer._deleteBtn = deleteBtn

    return outer, descEdit
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

BO.BuildOverviewTab = BuildOverviewTab
BO.RefreshOverview = RefreshOverview
BO.RefreshClassSelection = RefreshClassSelection
BO.RefreshSpecButtons = RefreshSpecButtons
BO.MetaText = MetaText
BO.RefreshMetaAndStatus = RefreshMetaAndStatus
