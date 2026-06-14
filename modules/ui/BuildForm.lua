-- EbonBuilds: modules/ui/BuildForm.lua
-- Responsibility: create/edit build form with class, spec, title, comments,
-- and 4 indicative locked-echo slots. Declarative/widget-layout heavy:
-- template-file exception applies, so the 200-line hard limit is waived here.

EbonBuilds.BuildForm = {}

local classChangeCallbacks = {}

local function NotifyClassChange()
    for i = 1, #classChangeCallbacks do classChangeCallbacks[i]() end
end

function EbonBuilds.BuildForm.OnClassChanged(fn)
    classChangeCallbacks[#classChangeCallbacks + 1] = fn
end

local CLASS_ORDER = {
    "WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST",
    "DEATHKNIGHT","SHAMAN","MAGE","WARLOCK","DRUID",
}
local QUALITY_COLOR = EbonBuilds.Constants.QUALITY_HEX
local QUALITY_BORDER_COLORS = EbonBuilds.Constants.QUALITY_BORDER_COLORS

local viewFrame
local state = {
    mode     = "create",
    id       = nil,
    title    = "",
    class    = nil,
    spec     = 1,
    comments = "",
    locked = { nil, nil, nil, nil, nil },
    settings  = nil,
    isPublic  = false,
}
function EbonBuilds.BuildForm.GetEditingClass()
    return state.class
end
function EbonBuilds.BuildForm.GetEditingSettings()
    if not state.settings then
        state.settings = EbonBuilds.Build.DefaultSettings()
    end
    return state.settings
end

function EbonBuilds.BuildForm.GetEditingLockedEchoes()
    if not state.mode then return nil end
    return state.locked
end

local classButtons = {}
local specButtons  = {}
local slotButtons  = {}
local titleBox, commentsBox, publicToggle

-- Global single-install hook: shift-click links go into the comments editbox
-- when it is focused. Guarded so we never install twice.
local _linkHookInstalled = false

local function InstallLinkHook()
    if _linkHookInstalled then return end
    _linkHookInstalled = true
    if not ChatEdit_InsertLink then return end
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if not link then return end
        local focus = GetCurrentKeyBoardFocus()
        if focus and focus == commentsBox then
            commentsBox:Insert(link)
        end
    end)
end

------------------------------------------------------------------------
-- Widget helpers
------------------------------------------------------------------------

local HighlightBorder = EbonBuilds.UIHelpers.HighlightBorder

local function RefreshClassSelection()
    for token, btn in pairs(classButtons) do
        HighlightBorder(btn, token == state.class)
    end
end

local function RefreshSpecButtons()
    local specs = state.class and EbonBuilds.SpecData and EbonBuilds.SpecData[state.class]
    for i = 1, 3 do
        local btn = specButtons[i]
        local entry = specs and specs[i]
        local icon  = entry and entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
        local name  = entry and entry.name or ("Spec " .. i)
        if btn._icon then btn._icon:SetTexture(icon) end
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(name)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        HighlightBorder(btn, i == state.spec)
    end
end

local CreateIconButton = EbonBuilds.UIHelpers.CreateIconButton

------------------------------------------------------------------------
-- Class grid
------------------------------------------------------------------------

local function BuildClassGrid(parent, xAnchor, yAnchor)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", xAnchor, yAnchor)
    label:SetText("Class:")
    for i, token in ipairs(CLASS_ORDER) do
        local btn = CreateIconButton(parent, 28)
        EbonBuilds.UIHelpers.SetClassIcon(btn._icon, token)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xAnchor + 56 + (i - 1) * 30, yAnchor + 6)
        btn:SetScript("OnClick", function()
            if state.class == token then return end
            state.class = token
            if state.spec > 3 then state.spec = 1 end
            RefreshClassSelection()
            RefreshSpecButtons()
            NotifyClassChange()
        end)
        classButtons[token] = btn
    end
end

local function BuildSpecGrid(parent, xAnchor, yAnchor)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", xAnchor, yAnchor)
    label:SetText("Spec:")
    for i = 1, 3 do
        local btn = CreateIconButton(parent, 36)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xAnchor + 56 + (i - 1) * 40, yAnchor + 6)
        btn:SetScript("OnClick", function()
            state.spec = i
            RefreshSpecButtons()
        end)
        specButtons[i] = btn
    end
end

------------------------------------------------------------------------
-- Title + Comments + Locked Echoes
------------------------------------------------------------------------

local function BuildTitleField(parent, x, y)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText("Title:")
    local box = EbonBuilds.UIHelpers.CreateEditBox(parent, 300, 22)
    box:GetParent():SetPoint("TOPLEFT", parent, "TOPLEFT", x + 56, y + 6)
    titleBox = box
end

local function BuildLockedSlots(parent, x, y)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText("Locked Echoes:")

    local detectBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    detectBtn:SetSize(80, 18)
    detectBtn:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    detectBtn:SetText("Detect")
    detectBtn:SetScript("OnClick", function()
        local total, unfilled = EbonBuilds.Build.AutoDetectLockedSlots()
        if total == 0 then
            print("|cffFF6600EbonBuilds:|r No locked echoes found on this character.")
            return
        end
        local serverLocked = EbonBuilds.Build.GetServerLockedPerks()
        local current = EbonBuilds.Scoring.GetEffectiveLockedEchoes()
        local filled = {}
        for i = 1, 5 do
            if current[i] then filled[current[i]] = true end
        end
        local added = 0
        for _, inst in ipairs(serverLocked) do
            if inst.spellId and not filled[inst.spellId] then
                for i = 1, 5 do
                    if not state.locked[i] then
                        state.locked[i] = inst.spellId
                        local btn = slotButtons[i]
                        if btn then
                            btn.spellId = inst.spellId
                            btn._quality = inst.quality or 0
                            btn._icon:SetTexture(select(3, GetSpellInfo(inst.spellId)))
                            local bc = QUALITY_BORDER_COLORS[inst.quality or 0] or QUALITY_BORDER_COLORS[0]
                            btn._qualityBorder:SetTexture(bc[1], bc[2], bc[3])
                            btn._qualityBorder:Show()
                        end
                        added = added + 1
                        filled[inst.spellId] = true
                        break
                    end
                end
            end
        end
        print("|cff19ff19EbonBuilds:|r Auto-detected " .. total .. " locked echoes, added " .. added .. " to build.")
    end)

    for i = 1, 5 do
        local btn = CreateIconButton(parent, 36)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 140 + (i - 1) * 44, y + 6)
        btn._icon:SetTexture("Interface\\Buttons\\UI-EmptySlot")
        btn.spellId = nil
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        EbonBuilds.EchoTableRows.WireIconTooltip(btn)

        local border = btn:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -2,  2)
        border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  2, -2)
        border:Hide()
        btn._qualityBorder = border

        btn:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                state.locked[i] = nil
                btn.spellId = nil
                btn._quality = nil
                btn._icon:SetTexture("Interface\\Buttons\\UI-EmptySlot")
                btn._qualityBorder:Hide()
                return
            end
            local settings = EbonBuilds.BuildForm.GetEditingSettings()
            local banList = settings and settings.echoBanList or {}
            local allList = EbonBuilds.EchoTableRows.BuildAllQualitiesList()
            local filtered = {}
            for _, entry in ipairs(allList) do
                if not banList[entry.spellId] then
                    local alreadyLocked = false
                    for j = 1, 5 do
                        if j ~= i and state.locked[j] == entry.spellId then
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
                state.locked[i] = spellId
                btn.spellId = spellId
                btn._quality = quality
                btn._icon:SetTexture(select(3, GetSpellInfo(spellId)))
                local bc = QUALITY_BORDER_COLORS[quality] or QUALITY_BORDER_COLORS[0]
                btn._qualityBorder:SetTexture(bc[1], bc[2], bc[3])
                btn._qualityBorder:Show()
            end, filtered)
        end)
        slotButtons[i] = btn
    end
end

local descriptionPlaceholder

local function RefreshDescriptionPlaceholder()
    if not descriptionPlaceholder or not commentsBox then return end
    if commentsBox:HasFocus() then
        descriptionPlaceholder:Hide()
        return
    end
    if (commentsBox:GetText() or "") == "" then
        descriptionPlaceholder:Show()
    else
        descriptionPlaceholder:Hide()
    end
end

local function BuildDescriptionField(parent, x, y, height)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText("Description:")

    local insertBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    insertBtn:SetWidth(110)
    insertBtn:SetHeight(20)
    insertBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 90, y + 2)
    insertBtn:SetText("+ Insert Echo Link")
    insertBtn:SetScript("OnClick", function()
        EbonBuilds.EchoPicker.Show(function(spellId, quality, name)
            local color = QUALITY_COLOR[quality] or "ffffff"
            local link  = "|cff" .. color .. "|Hecho:" .. spellId .. "|h[" .. name .. "]|h|r"
            if commentsBox:HasFocus() then
                commentsBox:Insert(link)
            else
                commentsBox:SetText((commentsBox:GetText() or "") .. link)
            end
        end)
    end)
    insertBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Insert Echo Link", 1, 0.82, 0, 1)
        GameTooltip:AddLine("Inserts a clickable echo reference into the description.", 0.8, 0.8, 0.8, 1)
        GameTooltip:AddLine(" ", 1, 1, 1, 1)
        GameTooltip:AddLine("To configure echo weights and bonuses for this build,", 0.6, 0.6, 0.6, 1)
        GameTooltip:AddLine("use the Echoes and Bonus tabs after saving.", 0.6, 0.6, 0.6, 1)
        GameTooltip:Show()
    end)
    insertBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT",     parent, "TOPLEFT",     x,   y - 24)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 50)
    container:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    container:SetBackdropColor(0, 0, 0, 0.6)
    container:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local scroll = CreateFrame("ScrollFrame", "EbonBuildsBuildFormDescriptionSF", container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     container, "TOPLEFT",      4, -4)
    scroll:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4,  4)

    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
    box:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    box:SetWidth(420)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(box)
    commentsBox = box

    -- Hidden FontString used to measure wrapped text height for scroll range
    local descMeasure = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descMeasure:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    descMeasure:SetWidth(410)
    descMeasure:Hide()

    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    hint:SetPoint("TOPLEFT",  box, "TOPLEFT",   2, -2)
    hint:SetPoint("TOPRIGHT", box, "TOPRIGHT", -2, -2)
    hint:SetJustifyH("LEFT")
    hint:SetJustifyV("TOP")
    hint:SetTextColor(0.5, 0.5, 0.5, 1)
    hint:SetText("Explain your build strategy here. Use the Echoes and Bonus tabs to configure weights.")
    descriptionPlaceholder = hint

    box:SetScript("OnEditFocusGained", function() descriptionPlaceholder:Hide() end)
    box:SetScript("OnEditFocusLost", function(self)
        if (self:GetText() or "") == "" then descriptionPlaceholder:Show() end
    end)
    box:SetScript("OnTextChanged", function(self)
        if self:HasFocus() then
            descriptionPlaceholder:Hide()
        else
            if (self:GetText() or "") == "" then
                descriptionPlaceholder:Show()
            else
                descriptionPlaceholder:Hide()
            end
        end

        -- Auto-resize to fit content and track cursor visibility
        descMeasure:SetText(self:GetText() or "")
        local textHeight = descMeasure:GetStringHeight() or 0
        local contentH = math.max(textHeight + 10, scroll:GetHeight())
        self:SetHeight(contentH)

        local sbar = _G["EbonBuildsBuildFormDescriptionSFScrollBar"]
        if sbar then
            local maxScroll = math.max(0, contentH - scroll:GetHeight())
            sbar:SetMinMaxValues(0, maxScroll)

            -- Measure cursor Y position within the text
            local cursorByte = self:GetCursorPosition() or 0
            local textBefore = (self:GetText() or ""):sub(1, cursorByte)
            descMeasure:SetText(textBefore)
            local cursorY = descMeasure:GetStringHeight() or 0

            local scrollTop = sbar:GetValue() or 0
            local visibleH = scroll:GetHeight()
            local cursorScreenY = cursorY - scrollTop

            if cursorScreenY > visibleH - 20 then
                sbar:SetValue(math.min(maxScroll, cursorY - visibleH + 20))
            elseif cursorScreenY < 4 then
                sbar:SetValue(math.max(0, cursorY - 20))
            end
        end
    end)
end

------------------------------------------------------------------------
-- Footer
------------------------------------------------------------------------

local function CollectFromInputs()
    state.title    = titleBox:GetText() or ""
    state.comments = commentsBox:GetText() or ""
end

local function OnSave()
    CollectFromInputs()
    if state.title == "" then return end
    local weights = EbonBuildsDB.pendingWeights
    if state.mode == "create" then
        local b = EbonBuilds.Build.Create({
            title = state.title, class = state.class, spec = state.spec,
            comments = state.comments, lockedEchoes = { unpack(state.locked) },
            settings = state.settings,
            isPublic = state.isPublic,
            echoWeights = weights,
        })
        state.mode = "edit"
        state.id   = b.id
        EbonBuilds.Build.SetActive(b.id)
    else
        EbonBuilds.Build.Save(state.id, {
            title = state.title, class = state.class, spec = state.spec,
            comments = state.comments, lockedEchoes = { unpack(state.locked) },
            settings = state.settings,
            isPublic = state.isPublic,
            echoWeights = weights,
        })
    end
    EbonBuildsDB._isEditingBuild = nil
    EbonBuildsDB.pendingWeights = nil
    EbonBuildsDB._wizardPrefill = nil
    if EbonBuilds.BuildList and EbonBuilds.BuildList.Refresh then
        EbonBuilds.BuildList.Refresh()
    end
    local active = EbonBuilds.Build.GetActive()
    if active then
        EbonBuilds.ViewRouter.Show("buildOverview", { build = active })
    end
end

local LoadFromBuild, ApplyStateToInputs

local function OnCancel()
    EbonBuildsDB._isEditingBuild = nil
    EbonBuildsDB.pendingWeights = nil
    EbonBuildsDB._wizardPrefill = nil

    -- Revert state and inputs to original build so dirty edits don't survive Cancel
    if state.mode == "edit" and state.id then
        local build = EbonBuilds.Build.Get(state.id)
        if build then
            LoadFromBuild(build)
            ApplyStateToInputs()
        end
    end

    local active = EbonBuilds.Build.GetActive()
    if active then
        EbonBuilds.ViewRouter.Show("buildOverview", { build = active })
    else
        EbonBuilds.ViewRouter.Show("welcome")
    end
end

local function OnDelete()
    if not state.id then return end
    EbonBuildsDB._isEditingBuild = nil
    EbonBuildsDB.pendingWeights = nil
    EbonBuildsDB._wizardPrefill = nil
    EbonBuilds.Build.Delete(state.id)
    if EbonBuilds.BuildList and EbonBuilds.BuildList.Refresh then
        EbonBuilds.BuildList.Refresh()
    end
    local active = EbonBuilds.Build.GetActive()
    if active then
        EbonBuilds.ViewRouter.Show("buildOverview", { build = active })
    else
        EbonBuilds.ViewRouter.Show("welcome")
    end
end

EbonBuilds.BuildForm.Save   = OnSave
EbonBuilds.BuildForm.Cancel = OnCancel
EbonBuilds.BuildForm.Delete = OnDelete

------------------------------------------------------------------------
-- Load/Reset state
------------------------------------------------------------------------

ApplyStateToInputs = function()
    titleBox:SetText(state.title or "")
    commentsBox:SetText(state.comments or "")
    RefreshDescriptionPlaceholder()
    RefreshClassSelection()
    RefreshSpecButtons()
    publicToggle:SetText(state.isPublic and "Public" or "Make Public")
    for i = 1, 5 do
        local id = state.locked[i]
        local btn = slotButtons[i]
        btn.spellId = id
        if id then
            btn._icon:SetTexture(select(3, GetSpellInfo(id)))
            local data = ProjectEbonhold.PerkDatabase[id]
            local quality = data and data.quality or 0
            btn._quality = quality
            local bc = QUALITY_BORDER_COLORS[quality] or QUALITY_BORDER_COLORS[0]
            btn._qualityBorder:SetTexture(bc[1], bc[2], bc[3])
            btn._qualityBorder:Show()
        else
            btn._icon:SetTexture("Interface\\Buttons\\UI-EmptySlot")
            btn._quality = nil
            btn._qualityBorder:Hide()
        end
    end
end

local function CloneSettings(src)
    local dst = EbonBuilds.Build.DefaultSettings()
    if not src then return dst end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = dst[k] or {}
            for k2, v2 in pairs(v) do dst[k][k2] = v2 end
        else
            dst[k] = v
        end
    end
    return dst
end

LoadFromBuild = function(build)
    state.mode     = "edit"
    state.id       = build.id
    state.title    = build.title    or ""
    state.class    = build.class
    state.spec     = build.spec     or 1
    state.comments = build.comments or ""
    state.settings = CloneSettings(build.settings)
    state.isPublic = build.isPublic or false
    for i = 1, 5 do state.locked[i] = build.lockedEchoes and build.lockedEchoes[i] or nil end
    EbonBuildsDB._isEditingBuild = true
    EbonBuildsDB.pendingWeights = {}
    if build.echoWeights then
        for name, weight in pairs(build.echoWeights) do
            EbonBuildsDB.pendingWeights[name] = weight
        end
    end
end

local function LoadDefaults()
    state.mode     = "create"
    state.id       = nil
    state.title    = ""
    state.class    = EbonBuilds.Build.PlayerClassToken()
    state.spec     = EbonBuilds.Build.PlayerTopTalentTab()
    state.comments = ""
    state.settings = EbonBuilds.Build.DefaultSettings()
    state.isPublic = false
    for i = 1, 5 do state.locked[i] = nil end
    EbonBuildsDB._isEditingBuild = true
    EbonBuildsDB.pendingWeights = {}
    EbonBuildsDB._wizardPrefill = nil
end

local function LoadFromWizardPrefill()
    local pre = EbonBuildsDB._wizardPrefill
    state.mode     = "create"
    state.id       = nil
    state.title    = pre.title or ""
    state.class    = pre.class or EbonBuilds.Build.PlayerClassToken()
    state.spec     = pre.spec or EbonBuilds.Build.PlayerTopTalentTab()
    state.comments = pre.comments or ""
    state.settings = pre.settings or EbonBuilds.Build.DefaultSettings()
    state.isPublic = pre.isPublic or false
    for i = 1, 5 do state.locked[i] = (pre.lockedEchoes and pre.lockedEchoes[i]) or nil end
    EbonBuildsDB._isEditingBuild = true
    EbonBuildsDB.pendingWeights = EbonBuildsDB.pendingWeights or {}
end

------------------------------------------------------------------------
-- Public Mount/Unmount
------------------------------------------------------------------------

local function TargetMatchesState(context)
    if context.mode == "edit" and context.build then
        return state.mode == "edit" and state.id == context.build.id
    end
    return false
end

function EbonBuilds.BuildForm.Mount(container, context)
    viewFrame:SetParent(container)
    viewFrame:ClearAllPoints()
    viewFrame:SetAllPoints(container)

    context = context or {}
    local keepState = TargetMatchesState(context)
    if not keepState then
        if context.mode == "create" and context.fromWizard and EbonBuildsDB._wizardPrefill then
            LoadFromWizardPrefill()
        elseif context.mode == "edit" and context.build then
            LoadFromBuild(context.build)
        else
            LoadDefaults()
        end
    end

    ApplyStateToInputs()
    NotifyClassChange()
    viewFrame:Show()
end

function EbonBuilds.BuildForm.Unmount()
    if viewFrame and titleBox and commentsBox then
        state.title    = titleBox:GetText() or state.title
        state.comments = commentsBox:GetText() or state.comments
    end
    if viewFrame then viewFrame:Hide() end
end

------------------------------------------------------------------------
-- Build view frame (deferred until Init so parent is known)
------------------------------------------------------------------------

local function BuildViewFrame()
    local f = CreateFrame("Frame", nil, UIParent)

    local header = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    header:SetText("Build")

    publicToggle = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    publicToggle:SetSize(120, 22)
    publicToggle:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    publicToggle:SetText("Make Public")
    publicToggle:SetScript("OnClick", function(self)
        state.isPublic = not state.isPublic
        self:SetText(state.isPublic and "Public" or "Make Public")
    end)

    BuildClassGrid(f, 10, -36)
    BuildSpecGrid(f, 10, -76)
    BuildTitleField(f, 10, -124)
    BuildLockedSlots(f, 10, -160)
    BuildDescriptionField(f, 10, -210, 180)
    return f
end

function EbonBuilds.BuildForm.Init()
    viewFrame = BuildViewFrame()
    viewFrame:Hide()
    InstallLinkHook()
end
