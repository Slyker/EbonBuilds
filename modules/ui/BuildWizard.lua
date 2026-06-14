-- EbonBuilds: modules/ui/BuildWizard.lua
-- Responsibility: guided build creation wizard (6 steps). Generates a build
-- configuration via preset buttons, then hands off to manual editing for refinement.

EbonBuilds.BuildWizard = {}

local QUALITY_COLOR = EbonBuilds.Constants.QUALITY_HEX
local QUALITY_BORDER_COLORS = EbonBuilds.Constants.QUALITY_BORDER_COLORS
local EMPTY_SLOT = EbonBuilds.Constants.EMPTY_SLOT_TEXTURE
local ApplyQualityBorder = EbonBuilds.UIHelpers.ApplyQualityBorder
local QUALITY_LABELS = EbonBuilds.Constants.QUALITY_LABELS
local FAMILIES = {
    { key = "Tank",         label = "Tank" },
    { key = "Survivability", label = "Survivability" },
    { key = "Healer",       label = "Healer" },
    { key = "Caster",       label = "Caster DPS" },
    { key = "Melee",        label = "Melee DPS" },
    { key = "Ranged",       label = "Ranged DPS" },
}
local WEIGHT_OPTIONS = {
    { label = "Want it", value = 50 },
    { label = "Good",   value = 40 },
    { label = "OK",     value = 30 },
    { label = "Mehh",   value = 20 },
}

local viewFrame, contentArea
local stepLabel, backBtn, nextBtn

local state = {}

local function BuildFilteredEchoList()
    local best = EbonBuilds.EchoTableRows.BuildBestByName()
    local lockedSet = {}
    for i = 1, 5 do
        if state.locked[i] then
            local n = GetSpellInfo(state.locked[i])
            if n then lockedSet[n] = true end
        end
    end
    local list = {}
    for name, entry in pairs(best) do
        if not state.echoes[name] and not lockedSet[name] then
            list[#list + 1] = {
                spellId = entry.spellId,
                name    = name,
                quality = entry.quality,
            }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local CreateIconButton = EbonBuilds.UIHelpers.CreateIconButton
local HighlightButton = EbonBuilds.UIHelpers.HighlightBorder

local function ClearContent()
    if not contentArea then return end
    for _, child in ipairs({ contentArea:GetChildren() }) do
        child:Hide()
    end
    for _, region in ipairs({ contentArea:GetRegions() }) do
        region:Hide()
    end
end

local function HasAdaptivePower()
    for i = 1, 5 do
        local id = state.locked[i]
        if id then
            local name = GetSpellInfo(id)
            if name and name:lower():find("adaptive power") then
                return true
            end
        end
    end
    return false
end

local function TotalSteps()
    return HasAdaptivePower() and 6 or 5
end

local function UpdateNavButtons()
    local total = TotalSteps()
    local realStep = state.step
    -- If step 2 was skipped (no adaptive power), steps 3-5 are really steps 2-4 and review is 5
    -- We track a displayStep that shifts when adaptive power is absent
    if not HasAdaptivePower() and state.step >= 2 then
        realStep = state.step - 1
    end
    stepLabel:SetText("Step " .. realStep .. "/" .. total)
    if state.step <= 0 then
        backBtn:Disable()
    else
        backBtn:Enable()
    end
    if state.step >= 6 then
        nextBtn:SetText("Create Build")
    else
        nextBtn:SetText("Next")
    end
end

------------------------------------------------------------------------
-- Step 1: Locked Echoes
------------------------------------------------------------------------

local lockedButtons = {}

local function RenderStep1()
    ClearContent()

    local title = contentArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", contentArea, "TOP", 0, -20)
    title:SetText("Select your 5 locked echoes")

    local total, unfilled = EbonBuilds.Build.AutoDetectLockedSlots()
    if total > 0 then
        local hint = contentArea:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOP", contentArea, "TOP", 0, -42)
        hint:SetText(total .. " locked echoes detected on this character.")

        local useCurrentBtn = CreateFrame("Button", nil, contentArea, "UIPanelButtonTemplate")
        useCurrentBtn:SetWidth(140)
        useCurrentBtn:SetHeight(20)
        useCurrentBtn:SetPoint("TOP", contentArea, "TOP", 0, -58)
        useCurrentBtn:SetText("Use Current Locks")
        useCurrentBtn:SetScript("OnClick", function()
            local serverLocked = EbonBuilds.Build.GetServerLockedPerks()
            for _, inst in ipairs(serverLocked) do
                if inst.spellId then
                    for i = 1, 5 do
                        if not state.locked[i] then
                            state.locked[i] = inst.spellId
                            break
                        end
                    end
                end
            end
            RenderStep1()
        end)
    end

    local slotSize = 48
    local spacing  = 10
    local totalW   = 5 * slotSize + 4 * spacing
    local startX   = -math.floor(totalW / 2)

    for i = 1, 5 do
        local btn = CreateIconButton(contentArea, slotSize)
        btn:SetPoint("TOP", contentArea, "TOP", startX + (i - 1) * (slotSize + spacing), -90)
        btn._icon:SetTexture(EMPTY_SLOT)
        btn.spellId = nil
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        EbonBuilds.EchoTableRows.WireIconTooltip(btn)

        EbonBuilds.UIHelpers.CreateQualityBorder(btn, 3)

        if state.locked[i] then
            btn.spellId = state.locked[i]
            btn._icon:SetTexture(select(3, GetSpellInfo(state.locked[i])))
            local data = ProjectEbonhold.PerkDatabase[state.locked[i]]
            local quality = data and data.quality or 0
            ApplyQualityBorder(btn._border, quality)
        end

        local idx = i
        btn:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                state.locked[idx] = nil
                btn.spellId = nil
                btn._icon:SetTexture(EMPTY_SLOT)
                btn._border:Hide()
                return
            end
            local filtered = BuildFilteredEchoList()
            local deduped = {}
            for _, entry in ipairs(filtered) do
                local alreadyLocked = false
                for j = 1, 5 do
                    if j ~= idx and state.locked[j] and state.locked[j] == entry.spellId then
                        alreadyLocked = true
                        break
                    end
                end
                if not alreadyLocked then
                    deduped[#deduped + 1] = entry
                end
            end
            EbonBuilds.EchoPicker.Show(function(spellId, quality, _)
                state.locked[idx] = spellId
                btn.spellId = spellId
                btn._icon:SetTexture(select(3, GetSpellInfo(spellId)))
                ApplyQualityBorder(btn._border, quality)
            end, deduped)
        end)
        lockedButtons[i] = btn
    end
end

------------------------------------------------------------------------
-- Step 2: Adaptive Power (conditional)
------------------------------------------------------------------------

local noveltySlider, noveltyValueLabel

local function RenderStep2()
    ClearContent()

    local title = contentArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", contentArea, "TOP", 0, -30)
    title:SetText("Adaptive Power detected!")

    local desc = contentArea:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOP", contentArea, "TOP", 0, -52)
    desc:SetText("Adaptive Power gains bonus for echoes you haven't picked yet.")

    local slider = CreateFrame("Slider", "EbonBuildsWizardNoveltySlider", contentArea, "OptionsSliderTemplate")
    slider:SetPoint("TOP", contentArea, "TOP", 0, -110)
    slider:SetWidth(300)
    slider:SetHeight(24)
    slider:SetMinMaxValues(0, 100)
    slider:SetValueStep(1)
    slider:SetValue(state.noveltyValue or 30)
    local sliderName = slider:GetName()
    if sliderName then
        _G[sliderName .. "Low"]:SetText("0")
        _G[sliderName .. "High"]:SetText("100")
    end

    local valLabel = contentArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    valLabel:SetPoint("TOP", slider, "BOTTOM", 0, -10)
    valLabel:SetText(tostring(state.noveltyValue or 30))
    noveltyValueLabel = valLabel

    local hint = contentArea:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOP", valLabel, "BOTTOM", 0, -8)
    hint:SetText("Suggested: 30 points")

    slider:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v)
        state.noveltyValue = v
        noveltyValueLabel:SetText(tostring(v))
    end)
    noveltySlider = slider
end

------------------------------------------------------------------------
-- Step 3: Family Bonuses
------------------------------------------------------------------------

local familyCycleLabels = { [0] = "|cff888888None|r", [10] = "Secondary +10", [20] = "Primary +20" }
local familyCycleValues = { 0, 10, 20 }

local function CycleNext(values, current)
    for i, v in ipairs(values) do
        if v == current then
            return values[i % #values + 1]
        end
    end
    return values[1]
end

local function CyclePrev(values, current)
    for i, v in ipairs(values) do
        if v == current then
            return values[(i - 2) % #values + 1]
        end
    end
    return values[1]
end

local function FamilyNextValue(current) return CycleNext(familyCycleValues, current) end
local function FamilyPrevValue(current) return CyclePrev(familyCycleValues, current) end

local function CreateArrowButton(parent, direction, anchor, anchorOffset)
    local arrow = CreateFrame("Button", nil, parent)
    arrow:SetWidth(18)
    arrow:SetHeight(18)
    arrow:SetPoint(direction == "LEFT" and "RIGHT" or "LEFT", anchor, direction == "LEFT" and "LEFT" or "RIGHT", anchorOffset, 0)
    arrow:SetNormalFontObject("GameFontNormal")
    arrow:SetText(direction == "LEFT" and "<" or ">")
    return arrow
end

local function RenderFamilyRow(familyEntry, anchorY)
    local rowW = 360
    local row = CreateFrame("Frame", nil, contentArea)
    row:SetPoint("TOP", contentArea, "TOP", 0, anchorY)
    row:SetWidth(rowW)
    row:SetHeight(26)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    label:SetWidth(130)
    label:SetJustifyH("RIGHT")
    label:SetText(familyEntry.label)

    local famKey = familyEntry.key
    local currentVal = state.familyPriorities[famKey] or 0

    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btn:SetWidth(100)
    btn:SetHeight(22)
    btn:SetPoint("LEFT", label, "RIGHT", 32, 0)
    btn:SetText(familyCycleLabels[currentVal])

    local function RefreshBtn()
        btn:SetText(familyCycleLabels[state.familyPriorities[famKey] or 0])
    end

    local leftArrow = CreateArrowButton(row, "LEFT", btn, -8)
    leftArrow:SetScript("OnClick", function()
        state.familyPriorities[famKey] = FamilyPrevValue(state.familyPriorities[famKey] or 0)
        RefreshBtn()
    end)

    local rightArrow = CreateArrowButton(row, "RIGHT", btn, 8)
    rightArrow:SetScript("OnClick", function()
        state.familyPriorities[famKey] = FamilyNextValue(state.familyPriorities[famKey] or 0)
        RefreshBtn()
    end)

    btn:SetScript("OnClick", function()
        state.familyPriorities[famKey] = FamilyNextValue(state.familyPriorities[famKey] or 0)
        RefreshBtn()
    end)

    return row
end

local function RenderStep3()
    ClearContent()

    local title = contentArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", contentArea, "TOP", 0, -20)
    title:SetText("Choose your families")

    local desc = contentArea:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOP", contentArea, "TOP", 0, -42)
    desc:SetText("Defaults are good for most builds. Change only if you really need to.")

    for i, entry in ipairs(FAMILIES) do
        RenderFamilyRow(entry, -72 - (i - 1) * 30)
    end
end

------------------------------------------------------------------------
-- Step 4: Quality Bonuses
------------------------------------------------------------------------

local qualityValues = { 0, 5, 10, 15, 20, 25, 30, 35, 40 }

local function NextQualityValue(current) return CycleNext(qualityValues, current) end
local function PrevQualityValue(current) return CyclePrev(qualityValues, current) end

local function RenderQualityRow(q, anchorY)
    local row = CreateFrame("Frame", nil, contentArea)
    row:SetPoint("TOP", contentArea, "TOP", 0, anchorY)
    row:SetWidth(360)
    row:SetHeight(28)

    local colorHex = QUALITY_COLOR[q] or "ffffff"
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    label:SetWidth(130)
    label:SetJustifyH("RIGHT")
    label:SetText("|cff" .. colorHex .. QUALITY_LABELS[q + 1] .. "|r")

    local currentVal = state.qualityBonus[q]
    if currentVal == nil then currentVal = q * 10 end
    state.qualityBonus[q] = currentVal

    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btn:SetWidth(100)
    btn:SetHeight(22)
    btn:SetPoint("LEFT", label, "RIGHT", 32, 0)
    btn:SetText("+" .. tostring(currentVal))

    local function RefreshBtn()
        btn:SetText("+" .. tostring(state.qualityBonus[q]))
    end

    local leftArrow = CreateArrowButton(row, "LEFT", btn, -8)
    leftArrow:SetScript("OnClick", function()
        state.qualityBonus[q] = PrevQualityValue(state.qualityBonus[q])
        RefreshBtn()
    end)

    local rightArrow = CreateArrowButton(row, "RIGHT", btn, 8)
    rightArrow:SetScript("OnClick", function()
        state.qualityBonus[q] = NextQualityValue(state.qualityBonus[q])
        RefreshBtn()
    end)

    btn:SetScript("OnClick", function()
        state.qualityBonus[q] = NextQualityValue(state.qualityBonus[q])
        RefreshBtn()
    end)
end

local function RenderStep4()
    ClearContent()

    local title = contentArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", contentArea, "TOP", 0, -20)
    title:SetText("Rate each quality tier")

    local desc = contentArea:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOP", contentArea, "TOP", 0, -42)
    desc:SetText("Defaults are good for most builds. Change only if you really need to.")

    for i, q in ipairs({ 0, 1, 2, 3, 4 }) do
        RenderQualityRow(q, -72 - (i - 1) * 32)
    end
end

------------------------------------------------------------------------
-- Step 5: Echo Weights
------------------------------------------------------------------------

local echoRows = {}

local function RenderEchoRow(parent, entry, index, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
    row:SetPoint("RIGHT",   parent, "RIGHT",   -6, 0)
    row:SetHeight(28)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(22)
    icon:SetHeight(22)
    icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(select(3, GetSpellInfo(entry.spellId)))

    local color = QUALITY_COLOR[entry.quality] or "ffffff"
    local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("LEFT",  icon, "RIGHT", 4, 0)
    nameLabel:SetWidth(140)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetText("|cff" .. color .. entry.name .. "|r")

    local btns = {}
    local currentVal = state.echoes[entry.name] and state.echoes[entry.name].weight or 40
    local btnStartX = 170

    for j, opt in ipairs(WEIGHT_OPTIONS) do
        local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btn:SetWidth(55)
        btn:SetHeight(18)
        btn:SetPoint("LEFT", row, "LEFT", btnStartX + (j - 1) * 60, -2)
        btn:SetText(opt.label)
        btn._val = opt.value

        if opt.value == currentVal then
            HighlightButton(btn, true)
        end

        btn:SetScript("OnClick", function(self)
            state.echoes[entry.name].weight = self._val
            for _, b in ipairs(btns) do
                HighlightButton(b, b._val == self._val)
            end
        end)
        btns[j] = btn
    end

    local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    removeBtn:SetWidth(56)
    removeBtn:SetHeight(18)
    removeBtn:SetPoint("LEFT", row, "LEFT", btnStartX + 4 * 60 + 6, -2)
    removeBtn:SetText("Remove")
    removeBtn:SetScript("OnClick", function()
        state.echoes[entry.name] = nil
        RenderCurrentStep()
    end)

    table.insert(echoRows, row)
    return row
end

local function RenderStep5()
    ClearContent()
    for _, row in ipairs(echoRows) do row:Hide() end
    echoRows = {}

    local title = contentArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", contentArea, "TOP", 0, -20)
    title:SetText("Which echoes matter most?")

    local subtitle = contentArea:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subtitle:SetPoint("TOP", contentArea, "TOP", 0, -42)
    subtitle:SetText("Add echoes and rate how much you want them.")

    local addBtn = CreateFrame("Button", nil, contentArea, "UIPanelButtonTemplate")
    addBtn:SetWidth(120)
    addBtn:SetHeight(20)
    addBtn:SetPoint("TOP", contentArea, "TOP", 0, -64)
    addBtn:SetText("+ Add Echo")
    addBtn:SetScript("OnClick", function()
        EbonBuilds.EchoPicker.Show(function(spellId, quality, name)
            state.echoes[name] = { spellId = spellId, quality = quality, name = name, weight = 40 }
            RenderStep5()
        end, BuildFilteredEchoList())
    end)

    local presetHint = contentArea:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    presetHint:SetPoint("TOPLEFT", addBtn, "TOPRIGHT", 12, 0)
    presetHint:SetText("Presets:")

    local presets = { { label = "Balanced", w = 40 }, { label = "Aggressive", w = 70 }, { label = "Conservative", w = 20 } }
    local presetAnchor = addBtn
    for _, p in ipairs(presets) do
        local btn = CreateFrame("Button", nil, contentArea, "UIPanelButtonTemplate")
        btn:SetWidth(80)
        btn:SetHeight(20)
        btn:SetPoint("LEFT", presetAnchor, "RIGHT", 8, 0)
        btn:SetText(p.label)
        btn:SetScript("OnClick", function()
            for _, entry in pairs(state.echoes) do
                entry.weight = p.w
            end
            RenderStep5()
        end)
        presetAnchor = btn
    end

    local sf = CreateFrame("ScrollFrame", "EbonBuildsWizardEchoScroll", contentArea)
    sf:SetPoint("TOPLEFT",     contentArea, "TOPLEFT",     10, -90)
    sf:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -20,   0)

    -- Backdrop
    sf:SetBackdrop(EbonBuilds.UIHelpers.TOOLTIP_BD)
    sf:SetBackdropColor(0, 0, 0, 0.4)
    sf:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- ScrollBar (inset vertically to keep up/down buttons inside backdrop)
    local sb = CreateFrame("Slider", "EbonBuildsWizardEchoScrollBar", sf, "UIPanelScrollBarTemplate")
    sb:SetPoint("TOPRIGHT",    sf, "TOPRIGHT",    -4, -20)
    sb:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", -4,  20)
    sb:SetOrientation("VERTICAL")
    sb:SetValueStep(30)
    sb:SetMinMaxValues(0, 0)
    sb:SetValue(0)
    sb:SetScript("OnValueChanged", function(self, value)
        sf:SetVerticalScroll(value)
    end)

    local child = CreateFrame("Frame", nil, sf)

    local sorted = {}
    for _, entry in pairs(state.echoes) do
        sorted[#sorted + 1] = entry
    end
    table.sort(sorted, function(a, b) return a.name < b.name end)

    if #sorted == 0 then
        local hint = contentArea:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOP", contentArea, "TOP", 0, -96)
        hint:SetText("No echoes added yet. Click \"+ Add Echo\" to start.")
    end

    child:SetWidth(contentArea:GetWidth() - 54)
    child:SetHeight(1)
    sf:SetScrollChild(child)

    for i, entry in ipairs(sorted) do
        RenderEchoRow(child, entry, i, -(i - 1) * 30)
    end
    child:SetHeight(math.max(1, #sorted * 30))

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local childH = child:GetHeight()
        local sfH = self:GetHeight()
        local range = math.max(0, childH - sfH)
        if range <= 0 then return end
        local newPos = self:GetVerticalScroll() - delta * 30
        if newPos < 0 then newPos = 0
        elseif newPos > range then newPos = range end
        self:SetVerticalScroll(newPos)
        sb:SetValue(newPos)
    end)

    -- Update scrollbar range after layout settles
    local function UpdateRange()
        local childH = child:GetHeight()
        local sfH = sf:GetHeight()
        local range = math.max(0, childH - sfH)
        sb:SetMinMaxValues(0, range)
        if range > 0 then
            sb:Show()
        else
            sb:Hide()
        end
    end
    sf:SetScript("OnSizeChanged", UpdateRange)
    UpdateRange()
end

------------------------------------------------------------------------
-- Step 6: Title & Description
------------------------------------------------------------------------

local function RenderStep6()
    ClearContent()

    local title = contentArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", contentArea, "TOP", 0, -20)
    title:SetText("Name and describe your build")

    local desc = contentArea:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOP", contentArea, "TOP", 0, -44)
    desc:SetText("You can link items, spells, and echoes in the description.")

    -- Title field
    local titleLabel = contentArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 40, -80)
    titleLabel:SetText("Title:")

    local titleBox = CreateFrame("EditBox", nil, contentArea)
    titleBox:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 40, -100)
    titleBox:SetPoint("RIGHT", contentArea, "RIGHT", -40, 0)
    titleBox:SetHeight(22)
    titleBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    titleBox:SetTextColor(1, 1, 1, 1)
    titleBox:SetAutoFocus(false)
    titleBox:SetMaxLetters(40)
    titleBox:SetText(state.wizardTitle or "")
    titleBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    titleBox:SetScript("OnTextChanged", function(self)
        state.wizardTitle = self:GetText()
    end)

    local titleBg = CreateFrame("Frame", nil, contentArea)
    titleBg:SetPoint("TOPLEFT",     titleBox, "TOPLEFT",     -2,  2)
    titleBg:SetPoint("BOTTOMRIGHT", titleBox, "BOTTOMRIGHT",  2, -2)
    titleBg:SetBackdrop(EbonBuilds.UIHelpers.TOOLTIP_BD)
    titleBg:SetBackdropColor(0, 0, 0, 0.6)
    titleBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    titleBg:SetFrameLevel(titleBox:GetFrameLevel() - 1)

    -- Description field
    local descLabel = contentArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 40, -140)
    descLabel:SetText("Description:")

    local descBox = CreateFrame("EditBox", nil, contentArea)
    descBox:SetMultiLine(true)
    descBox:SetMaxLetters(0)
    descBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    descBox:SetPoint("TOPLEFT",     contentArea, "TOPLEFT",     40, -160)
    descBox:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -40,  16)
    descBox:SetAutoFocus(false)
    descBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    descBox:SetText(state.wizardDescription or "")

    local descBg = CreateFrame("Frame", nil, contentArea)
    descBg:SetPoint("TOPLEFT",     descBox, "TOPLEFT",     -2,  2)
    descBg:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT",  2, -2)
    descBg:SetBackdrop(EbonBuilds.UIHelpers.TOOLTIP_BD)
    descBg:SetBackdropColor(0, 0, 0, 0.6)
    descBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    descBg:SetFrameLevel(descBox:GetFrameLevel() - 1)

    local placeHolder = descBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    placeHolder:SetPoint("TOPLEFT",     descBox, "TOPLEFT",     2, -2)
    placeHolder:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -2,  2)
    placeHolder:SetJustifyH("LEFT")
    placeHolder:SetJustifyV("TOP")
    placeHolder:SetTextColor(0.5, 0.5, 0.5, 1)
    placeHolder:SetText("List important items, strategies, and affixes that work well with this build. You can shift-click items to link them.")

    descBox:SetScript("OnEditFocusGained", function() placeHolder:Hide() end)
    descBox:SetScript("OnEditFocusLost", function(self)
        if (self:GetText() or "") == "" then placeHolder:Show() end
    end)
    descBox:SetScript("OnTextChanged", function(self)
        if self:HasFocus() then
            placeHolder:Hide()
        else
            if (self:GetText() or "") == "" then placeHolder:Show() else placeHolder:Hide() end
        end
        state.wizardDescription = self:GetText()
    end)

    -- Show placeholder if empty
    if (descBox:GetText() or "") == "" then placeHolder:Show() else placeHolder:Hide() end
end

------------------------------------------------------------------------
-- Build creation
------------------------------------------------------------------------

local function CreateBuildFromWizard()
    EbonBuildsDB.pendingWeights = EbonBuildsDB.pendingWeights or {}

    -- Apply echo weights
    for name, entry in pairs(state.echoes) do
        EbonBuildsDB.pendingWeights[name] = entry.weight
    end

    -- Build settings from wizard
    local settings = EbonBuilds.Build.DefaultSettings()

    -- Quality bonus
    for q = 0, 4 do
        settings.qualityBonus[q] = state.qualityBonus[q] or (q * 10)
    end

    -- Family bonus
    for _, entry in ipairs(FAMILIES) do
        local val = state.familyPriorities[entry.key] or 0
        if val > 0 then
            settings.familyBonus[entry.key] = val
        end
    end

    -- Novelty
    if HasAdaptivePower() then
        settings.noveltyValue = state.noveltyValue or 30
    else
        settings.noveltyValue = 0
    end

    -- Locked echoes
    local locked = { state.locked[1], state.locked[2], state.locked[3], state.locked[4], state.locked[5] }

    local playerClass = EbonBuilds.Build.PlayerClassToken()

    -- Store wizard data so BuildForm can load it in create mode
    EbonBuildsDB._wizardPrefill = {
        title        = state.wizardTitle ~= "" and state.wizardTitle or "New Build",
        class        = playerClass,
        spec         = EbonBuilds.Build.PlayerTopTalentTab(),
        comments     = state.wizardDescription or "",
        lockedEchoes = locked,
        settings     = settings,
        isPublic     = false,
    }
    EbonBuildsDB._isEditingBuild = true

    EbonBuilds.ViewRouter.Show("buildOverview", { mode = "create", fromWizard = true })
end

------------------------------------------------------------------------
-- Navigation
------------------------------------------------------------------------

local function GoNext()
    if state.step >= 6 then
        CreateBuildFromWizard()
        return
    end

    -- Validate: require at least 1 locked echo on step 1
    if state.step == 1 then
        local lockedCount = 0
        for i = 1, 5 do
            if state.locked[i] then lockedCount = lockedCount + 1 end
        end
        if lockedCount == 0 then
            if not EbonBuilds._wizardWarned then
                EbonBuilds._wizardWarned = true
                print("|cffFF6600EbonBuilds:|r Please select at least one locked echo to continue.")
                C_Timer.After(3, function() EbonBuilds._wizardWarned = nil end)
            end
            return
        end
    end

    -- Skip step 2 if no Adaptive Power
    if state.step == 1 and not HasAdaptivePower() then
        state.step = 3
    else
        state.step = state.step + 1
    end

    RenderCurrentStep()
end

local function GoBack()
    if state.step <= 1 then
        EbonBuilds.ViewRouter.ShowActiveOrWelcome()
        return
    end

    -- Skip step 2 going back if no Adaptive Power
    if state.step == 3 and not HasAdaptivePower() then
        state.step = 1
    else
        state.step = state.step - 1
    end

    RenderCurrentStep()
end

local function RenderCurrentStep()
    ClearContent()
    backBtn:Show()
    nextBtn:Show()
    UpdateNavButtons()
    if state.step == 1 then
        RenderStep1()
    elseif state.step == 2 then
        RenderStep2()
    elseif state.step == 3 then
        RenderStep3()
    elseif state.step == 4 then
        RenderStep4()
    elseif state.step == 5 then
        RenderStep5()
    elseif state.step == 6 then
        RenderStep6()
    end
end

------------------------------------------------------------------------
-- View interface
------------------------------------------------------------------------

local view = {}

function view.Show(container, context)
    viewFrame:SetParent(container)
    viewFrame:ClearAllPoints()
    viewFrame:SetAllPoints(container)

    -- Reset state
    state.step = 1
    state.locked = { nil, nil, nil, nil, nil }
    state.noveltyValue = 30
    state.qualityBonus = { [0] = 0, [1] = 10, [2] = 20, [3] = 30, [4] = 40 }
    state.familyPriorities = {}
    state.echoes = {}
    state.wizardTitle = ""
    state.wizardDescription = ""

    RenderCurrentStep()
    viewFrame:Show()
end

function view.Hide()
    if viewFrame then viewFrame:Hide() end
end

------------------------------------------------------------------------
-- Build view frame
------------------------------------------------------------------------

local function BuildViewFrame()
    local f = CreateFrame("Frame", nil, UIParent)

    -- Header
    local header = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    header:SetText("Build Wizard")

    -- Step indicator
    stepLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stepLabel:SetPoint("TOP", f, "TOP", 0, -10)

    -- Content area
    contentArea = CreateFrame("Frame", nil, f)
    contentArea:SetPoint("TOPLEFT",     f, "TOPLEFT",     0, -40)
    contentArea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0,  50)

    -- Navigation buttons
    backBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    backBtn:SetWidth(80)
    backBtn:SetHeight(22)
    backBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 20)
    backBtn:SetText("Back")
    backBtn:SetScript("OnClick", GoBack)

    nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextBtn:SetWidth(80)
    nextBtn:SetHeight(22)
    nextBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 100, 20)
    nextBtn:SetText("Next")
    nextBtn:SetScript("OnClick", GoNext)

    f:Hide()
    return f
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------

function EbonBuilds.BuildWizard.Init()
    viewFrame = BuildViewFrame()
    EbonBuilds.ViewRouter.Register("buildWizard", view)
end
