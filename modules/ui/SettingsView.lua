-- EbonBuilds: modules/ui/SettingsView.lua
-- Responsibility: render the Automation tab (banish protection, echo ban,
-- peak display and auto-behaviour thresholds).
-- Exposes Mount/Unmount. Reads and writes into BuildForm state.settings
-- so unsaved edits persist across tabs.
-- Layout-heavy/declarative: template-file exception applies.

EbonBuilds.SettingsView = {}

local C = EbonBuilds.Constants
local QUALITY_LABELS = {}
for q = 0, 4 do
    QUALITY_LABELS[q] = { name = C.QUALITY_LABELS[q], color = C.QUALITY_HEX[q] }
end

local FAMILY_ORDER = {
    "Tank", "Survivability", "Healer", "Caster", "Melee", "Ranged", "No family",
}

local THRESHOLDS = {
    { key = "autoBanishPct",    label = "Auto-banish %",
      flavor = "When an offered echo's individual score falls below this threshold, the addon will try to banish it. Echoes from protected families are skipped.",
      min = 0, max = 100, step = 1 },
    { key = "autoRerollPct",    label = "Auto-reroll %",
      flavor = "The addon sums the scores of all three offered echoes. If the total is below this threshold, a reroll is triggered.",
      min = 0, max = 300, step = 1 },
    { key = "rerollGuardPct",   label = "Reroll guard %",
      flavor = "Blocks reroll if any single offered echo scores above this threshold, regardless of the sum.",
      min = 0, max = 100, step = 1 },
    { key = "autoFreezePct",    label = "Auto-freeze %",
      flavor = "Triggers when at least two offered echoes score above this threshold. The lowest-scored among them gets frozen, and the highest will be picked afterwards.",
      min = 0, max = 100, step = 1 },
    { key = "freezePenaltyPct", label = "Freeze penalty %",
      flavor = "Reduces a frozen echo's score to give priority to unpicked choices. The penalty is applied once and persists until the echo is selected.",
      min = 0, max = 50,  step = 1 },
}

local viewFrame
local scrollFrame, scrollChild, scrollBar
local thresholdSliders = {}
local peakLabel
local whitelistToggles = {}
local whitelistWarningLabel

local CONTENT_HEIGHT = 1160

-- Quality / family weight editor widgets
local qualityBoxes = {}
local qualityModeToggles = {}
local familyBoxes = {}
local familyModeToggles = {}
local noveltyBox, noveltyModeToggle

local CreateModeToggle = EbonBuilds.UIHelpers.CreateModeToggle

------------------------------------------------------------------------
-- Highlight border helper (shared by toggle buttons)
------------------------------------------------------------------------

local HighlightBorder = EbonBuilds.UIHelpers.HighlightBorder

------------------------------------------------------------------------
-- Peak display
------------------------------------------------------------------------

local function RefreshPeak()
    if not peakLabel then return 0 end
    local settings = EbonBuilds.BuildForm.GetEditingSettings()
    local class    = EbonBuilds.BuildForm.GetEditingClass()
    local name, score = EbonBuilds.Scoring.ComputePeak(class, settings)
    if name then
        peakLabel:SetText(string.format("Peak: %s = %d", name, score))
    else
        peakLabel:SetText("Peak: (no echoes)")
    end
    return score or 0
end

------------------------------------------------------------------------
-- Banish family whitelist section
------------------------------------------------------------------------

local function RefreshWhitelistToggles()
    local settings = EbonBuilds.BuildForm.GetEditingSettings()
    settings.banishFamilyWhitelist = settings.banishFamilyWhitelist or {}
    local allSelected = true
    for _, fam in ipairs(FAMILY_ORDER) do
        local row = whitelistToggles[fam]
        if row and row.checkTex then
            local selected = settings.banishFamilyWhitelist[fam] or false
            if selected then row.checkTex:Show() else row.checkTex:Hide() end
            if not selected then allSelected = false end
        end
    end
    if whitelistWarningLabel then
        if allSelected then
            whitelistWarningLabel:Show()
        else
            whitelistWarningLabel:Hide()
        end
    end
end

local function CommitWhitelistToggle(family)
    local settings = EbonBuilds.BuildForm.GetEditingSettings()
    settings.banishFamilyWhitelist = settings.banishFamilyWhitelist or {}
    if settings.banishFamilyWhitelist[family] then
        settings.banishFamilyWhitelist[family] = nil
    else
        settings.banishFamilyWhitelist[family] = true
    end
    RefreshWhitelistToggles()
end

local WHITELIST_ROW1 = { "Tank", "Survivability", "Healer", "Caster" }
local WHITELIST_ROW2 = { "Melee", "Ranged", "No family" }

local function BuildBanishWhitelistSection(parent, x, y)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    header:SetText("Banish Protection:")

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    hint:SetText("Checked families are protected from banish.")

    local function CreateWhitelistRow(parent, fam, px, py)
        local row = CreateFrame("Button", nil, parent)
        row:SetWidth(18)
        row:SetHeight(18)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", px, py)
        row.family = fam

        local cb = row:CreateTexture(nil, "ARTWORK")
        cb:SetWidth(14)
        cb:SetHeight(14)
        cb:SetPoint("LEFT", row, "LEFT", 2, 0)
        cb:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        cb:Hide()
        row.checkTex = cb

        local bg = row:CreateTexture(nil, "BORDER")
        bg:SetWidth(14)
        bg:SetHeight(14)
        bg:SetPoint("LEFT", row, "LEFT", 1, 0)
        bg:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        bg:SetAlpha(0.8)

        row:SetScript("OnClick", function(self) CommitWhitelistToggle(self.family) end)
        whitelistToggles[fam] = row

        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetText(fam)
        lbl:SetPoint("LEFT", row, "RIGHT", 4, 0)
        lbl:SetJustifyH("LEFT")
    end

    for i, fam in ipairs(WHITELIST_ROW1) do
        CreateWhitelistRow(parent, fam, x + (i - 1) * 110, y - 32)
    end

    for i, fam in ipairs(WHITELIST_ROW2) do
        CreateWhitelistRow(parent, fam, x + (i - 1) * 110, y - 58)
    end

    whitelistWarningLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    whitelistWarningLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 86)
    whitelistWarningLabel:SetWidth(400)
    whitelistWarningLabel:SetJustifyH("LEFT")
    whitelistWarningLabel:SetText("|cffff0000All families are protected. At least one must be unprotected for banish to work.|r")
    whitelistWarningLabel:Hide()

    local banNote = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    banNote:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 115)
    banNote:SetWidth(490)
    banNote:SetJustifyH("LEFT")
    banNote:SetText("Banned echoes with protected families are deprioritized, not excluded from selection. If all offered are banned, the fallback are applied.")
end

------------------------------------------------------------------------
-- Peak row
------------------------------------------------------------------------

local function BuildPeakRow(parent, x, y)
    peakLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    peakLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    peakLabel:SetText("Peak: -")

    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", peakLabel, "BOTTOMLEFT", 0, -2)
    note:SetWidth(480)
    note:SetJustifyH("LEFT")
    note:SetText("The highest echo score for this class after all bonuses are applied. All automation thresholds are percentages of this value. Locked at run start.")
end

------------------------------------------------------------------------
-- Threshold section (auto-banish / auto-reroll / auto-freeze / penalty)
------------------------------------------------------------------------

local SLIDER_W = 400

local function CreateThresholdSlider(parent, x, y, entry)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(entry.label)

    local flavorY = y - 20
    if entry.flavor then
        local flavor = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        flavor:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 16)
        flavor:SetWidth(SLIDER_W)
        flavor:SetJustifyH("LEFT")
        flavor:SetText(entry.flavor)
        flavorY = y - 58
    end

    local slider = CreateFrame("Slider", nil, parent)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, flavorY)
    slider:SetWidth(SLIDER_W)
    slider:SetHeight(24)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(entry.min, entry.max)
    slider:SetValueStep(entry.step)

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(0.25, 0.25, 0.25, 0.8)
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetPoint("CENTER", slider, "CENTER", 0, 0)
    track:SetHeight(6)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    thumb:SetWidth(16)
    thumb:SetHeight(24)
    slider:SetThumbTexture(thumb)

    local valText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    valText:SetWidth(40)
    valText:SetJustifyH("LEFT")
    slider._valText = valText

    local absLabel = nil
    if entry.key ~= "freezePenaltyPct" then
        absLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        absLabel:SetPoint("LEFT", valText, "RIGHT", 2, 0)
        absLabel:SetWidth(60)
        absLabel:SetJustifyH("LEFT")
    end
    slider._absLabel = absLabel

    slider:SetScript("OnValueChanged", function(self, value)
        local v = math.floor(value + 0.5)
        valText:SetText(v .. "%")
        local settings = EbonBuilds.BuildForm.GetEditingSettings()
        settings[entry.key] = v
        if self._absLabel then
            local peak = RefreshPeak()
            if peak > 0 then
                self._absLabel:SetText("= " .. math.floor(peak * v / 100))
            else
                self._absLabel:SetText("")
            end
        else
            RefreshPeak()
        end
    end)

    return slider
end

local function BuildThresholdsSection(parent, x, y)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    header:SetText("Automation Thresholds:")

    local sub = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    sub:SetText("Values are percentages of the Peak score.")

    for i, entry in ipairs(THRESHOLDS) do
        local cy = y - 38 - (i - 1) * 85
        local slider = CreateThresholdSlider(parent, x + 10, cy, entry)
        thresholdSliders[entry.key] = slider
    end
end

------------------------------------------------------------------------
-- Number edit box helper
------------------------------------------------------------------------

local CreateNumberEditBox = EbonBuilds.UIHelpers.CreateNumberEditBox

------------------------------------------------------------------------
-- Global automation toggle
------------------------------------------------------------------------

local globalAutoToggle

local function BuildGlobalAutomationSection(parent, x, y)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    header:SetText("Automation:")

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    hint:SetText("Master switch for all echo picking automation.")

    globalAutoToggle = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    globalAutoToggle:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 10, y - 34)
    globalAutoToggle:SetSize(24, 24)

    local toggleLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toggleLabel:SetPoint("LEFT", globalAutoToggle, "RIGHT", 6, 0)
    toggleLabel:SetText("Enable automation")
    toggleLabel:SetTextColor(0.8, 0.8, 0.8)

    globalAutoToggle:SetScript("OnClick", function(self)
        local gs = EbonBuildsDB.globalSettings
        gs.automationEnabled = self:GetChecked()
    end)

    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 10, y - 60)
    note:SetWidth(480)
    note:SetJustifyH("LEFT")
    note:SetText("When disabled, the addon will not automatically banish, reroll, freeze, or pick echoes.")
end

local function RefreshGlobalAutomationToggle()
    if not globalAutoToggle then return end
    local gs = EbonBuildsDB.globalSettings
    globalAutoToggle:SetChecked(gs.automationEnabled ~= false)
end

------------------------------------------------------------------------
-- Quality bonus section
------------------------------------------------------------------------

local function CommitQualityBox(box)
    local settings = EbonBuilds.BuildForm.GetEditingSettings()
    local num = tonumber(box:GetText())
    if num then
        settings.qualityBonus[box.qIndex] = num
    end
    box:SetText(tostring(settings.qualityBonus[box.qIndex] or 0))
end

local function BuildQualityBonusSection(parent, x, y)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    header:SetText("Rarity Bonus:")

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    hint:SetText("Use + to add the value, |cff19ff19x|r to multiply.")

    for q = 0, 4 do
        local cx = x + q * 80

        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        local info = QUALITY_LABELS[q]
        lbl:SetText("|cff" .. info.color .. info.name .. "|r")
        lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", cx, y - 38)
        lbl:SetWidth(70)
        lbl:SetJustifyH("CENTER")

        local box = CreateNumberEditBox(parent, 38, 22, true, true)
        box:GetParent():SetPoint("TOPLEFT", parent, "TOPLEFT", cx + 5, y - 54)
        box.qIndex = q
        box:SetScript("OnEnterPressed",    function(self) CommitQualityBox(self); self:ClearFocus() end)
        box:SetScript("OnEditFocusLost",   function(self) CommitQualityBox(self) end)
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        qualityBoxes[q] = box

        local toggle = CreateModeToggle(parent, cx + 45, y - 54)
        toggle.onToggle = function()
            local s = EbonBuilds.BuildForm.GetEditingSettings()
            s.qualityBonusMode[q] = toggle.multiplicative
        end
        qualityModeToggles[q] = toggle
    end
end

local function RefreshQualityBoxes()
    local settings = EbonBuilds.BuildForm.GetEditingSettings()
    for q = 0, 4 do
        if qualityBoxes[q] then
            qualityBoxes[q]:SetText(tostring(settings.qualityBonus[q] or 0))
        end
        local toggle = qualityModeToggles[q]
        if toggle then
            toggle.multiplicative = settings.qualityBonusMode[q] or false
            toggle.modeLabel:SetText(toggle.multiplicative and "|cff19ff19x|r" or "+")
        end
    end
end

------------------------------------------------------------------------
-- Family bonus section
------------------------------------------------------------------------

local FAMILY_ROW1 = WHITELIST_ROW1
local FAMILY_ROW2 = WHITELIST_ROW2

local function CommitFamilyBox(box)
    local settings = EbonBuilds.BuildForm.GetEditingSettings()
    local num = tonumber(box:GetText())
    if num then
        settings.familyBonus[box.famKey] = num
    end
    box:SetText(tostring(settings.familyBonus[box.famKey] or 0))
end

local function BuildFamilyBonusSection(parent, x, y)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    header:SetText("Family Bonus:")

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    hint:SetText("Use + to add the value, |cff19ff19x|r to multiply.")

    for i, fam in ipairs(FAMILY_ROW1) do
        local cx = x + (i - 1) * 100

        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetText(fam)
        lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", cx, y - 38)
        lbl:SetWidth(55)
        lbl:SetJustifyH("CENTER")

        local box = CreateNumberEditBox(parent, 38, 22, true, true)
        box:GetParent():SetPoint("TOPLEFT", parent, "TOPLEFT", cx + 5, y - 54)
        box.famKey = fam
        box:SetScript("OnEnterPressed",    function(self) CommitFamilyBox(self); self:ClearFocus() end)
        box:SetScript("OnEditFocusLost",   function(self) CommitFamilyBox(self) end)
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        familyBoxes[fam] = box

        local toggle = CreateModeToggle(parent, cx + 45, y - 54)
        toggle.onToggle = function()
            local s = EbonBuilds.BuildForm.GetEditingSettings()
            s.familyBonusMode[fam] = toggle.multiplicative
        end
        familyModeToggles[fam] = toggle
    end

    for i, fam in ipairs(FAMILY_ROW2) do
        local cx = x + (i - 1) * 100

        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetText(fam)
        lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", cx, y - 84)
        lbl:SetWidth(55)
        lbl:SetJustifyH("CENTER")

        local box = CreateNumberEditBox(parent, 38, 22, true, true)
        box:GetParent():SetPoint("TOPLEFT", parent, "TOPLEFT", cx + 5, y - 100)
        box.famKey = fam
        box:SetScript("OnEnterPressed",    function(self) CommitFamilyBox(self); self:ClearFocus() end)
        box:SetScript("OnEditFocusLost",   function(self) CommitFamilyBox(self) end)
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        familyBoxes[fam] = box

        local toggle = CreateModeToggle(parent, cx + 45, y - 100)
        toggle.onToggle = function()
            local s = EbonBuilds.BuildForm.GetEditingSettings()
            s.familyBonusMode[fam] = toggle.multiplicative
        end
        familyModeToggles[fam] = toggle
    end
end

local function RefreshFamilyBoxes()
    local settings = EbonBuilds.BuildForm.GetEditingSettings()
    for _, fam in ipairs(FAMILY_ORDER) do
        if familyBoxes[fam] then
            familyBoxes[fam]:SetText(tostring(settings.familyBonus[fam] or 0))
        end
        local toggle = familyModeToggles[fam]
        if toggle then
            toggle.multiplicative = settings.familyBonusMode[fam] or false
            toggle.modeLabel:SetText(toggle.multiplicative and "|cff19ff19x|r" or "+")
        end
    end
end

------------------------------------------------------------------------
-- Novelty bonus section
------------------------------------------------------------------------

local function CommitNoveltyBox()
    local settings = EbonBuilds.BuildForm.GetEditingSettings()
    local num = tonumber(noveltyBox:GetText())
    if num then
        settings.noveltyValue = num
    end
    noveltyBox:SetText(tostring(settings.noveltyValue or 0))
end

local function BuildNoveltyBonusSection(parent, x, y)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    header:SetText("Novelty Bonus:")

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    hint:SetText("Unique echoes (seen for the first time) gain this bonus.")

    local valLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valLabel:SetText("Value:")
    valLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 32)

    noveltyBox = CreateNumberEditBox(parent, 50, 22, true, true)
    noveltyBox:GetParent():SetPoint("TOPLEFT", parent, "TOPLEFT", x + 40, y - 34)
    noveltyBox:SetScript("OnEnterPressed",    function(self) CommitNoveltyBox(); self:ClearFocus() end)
    noveltyBox:SetScript("OnEditFocusLost",   function(self) CommitNoveltyBox() end)
    noveltyBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    noveltyModeToggle = CreateModeToggle(parent, x + 95, y - 32)
    noveltyModeToggle.onToggle = function()
        local s = EbonBuilds.BuildForm.GetEditingSettings()
        s.noveltyMode = noveltyModeToggle.multiplicative
    end
end

local function RefreshNoveltyBox()
    local settings = EbonBuilds.BuildForm.GetEditingSettings()
    if noveltyBox then
        noveltyBox:SetText(tostring(settings.noveltyValue or 0))
    end
    if noveltyModeToggle then
        noveltyModeToggle.multiplicative = settings.noveltyMode or false
        noveltyModeToggle.modeLabel:SetText(noveltyModeToggle.multiplicative and "|cff19ff19x|r" or "+")
    end
end

------------------------------------------------------------------------
-- Refresh (called on Mount)
------------------------------------------------------------------------

local function RefreshInputs()
    RefreshGlobalAutomationToggle()
    local settings = EbonBuilds.BuildForm.GetEditingSettings()
    for _, entry in ipairs(THRESHOLDS) do
        local slider = thresholdSliders[entry.key]
        if slider then
            local val = settings[entry.key] or 0
            slider:SetValue(val)
            slider._valText:SetText(val .. "%")
        end
    end
    RefreshWhitelistToggles()
    RefreshQualityBoxes()
    RefreshFamilyBoxes()
    RefreshNoveltyBox()
    local peak = RefreshPeak()
    for _, entry in ipairs(THRESHOLDS) do
        local slider = thresholdSliders[entry.key]
        if slider and slider._absLabel then
            local val = settings[entry.key] or 0
            if peak > 0 then
                slider._absLabel:SetText("= " .. math.floor(peak * val / 100))
            else
                slider._absLabel:SetText("")
            end
        end
    end
end

local function CommitFocusedBoxes()
    for _, box in pairs(qualityBoxes) do if box:HasFocus() then CommitQualityBox(box) end end
    for _, box in pairs(familyBoxes)  do if box:HasFocus() then CommitFamilyBox(box)  end end
    if noveltyBox and noveltyBox:HasFocus() then CommitNoveltyBox() end
end

------------------------------------------------------------------------
-- Scroll helpers
------------------------------------------------------------------------

local function UpdateScrollRange()
    if not scrollFrame or not scrollBar then return end
    local sfHeight = scrollFrame:GetHeight()
    local range = math.max(0, CONTENT_HEIGHT - sfHeight)
    scrollBar:SetMinMaxValues(0, range)
    if scrollBar:GetValue() > range then scrollBar:SetValue(range) end
end

------------------------------------------------------------------------
-- Frame
------------------------------------------------------------------------

local function BuildViewFrame(parent)
    local f = CreateFrame("Frame", nil, parent)

    local header = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    header:SetText("Settings")

    scrollFrame = CreateFrame("ScrollFrame", nil, f)
    scrollFrame:SetPoint("TOPLEFT",     f, "TOPLEFT",     0, -28)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 10)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(520)
    scrollChild:SetHeight(CONTENT_HEIGHT)
    scrollFrame:SetScrollChild(scrollChild)

    scrollBar = CreateFrame("Slider", nil, scrollFrame, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPLEFT",     scrollFrame, "TOPRIGHT",     -2, -4)
    scrollBar:SetPoint("BOTTOMLEFT",  scrollFrame, "BOTTOMRIGHT",  -2,  4)
    scrollBar:SetValueStep(20)
    scrollBar:SetValue(0)

    EbonBuilds.UIHelpers.WireScroller(scrollFrame, scrollBar, 20, scrollChild)

    scrollFrame:SetScript("OnSizeChanged", UpdateScrollRange)

    BuildGlobalAutomationSection  (scrollChild, 10,  -5)
    BuildQualityBonusSection     (scrollChild, 10, -75)
    BuildFamilyBonusSection      (scrollChild, 10, -165)
    BuildNoveltyBonusSection     (scrollChild, 10, -305)
    BuildBanishWhitelistSection  (scrollChild, 10, -370)
    BuildPeakRow                 (scrollChild, 10, -515)
    BuildThresholdsSection       (scrollChild, 10, -565)

    return f
end

local function EnsureBuilt(container)
    if viewFrame then return end
    viewFrame = BuildViewFrame(container)
end

function EbonBuilds.SettingsView.Mount(container)
    EnsureBuilt(container)
    viewFrame:SetParent(container)
    viewFrame:ClearAllPoints()
    viewFrame:SetAllPoints(container)
    RefreshInputs()
    viewFrame:Show()
    UpdateScrollRange()
    scrollBar:SetValue(0)
end

function EbonBuilds.SettingsView.Unmount()
    if not viewFrame then return end
    CommitFocusedBoxes()
    viewFrame:Hide()
end

function EbonBuilds.SettingsView.Init()
end
