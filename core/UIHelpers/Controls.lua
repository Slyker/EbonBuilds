-- EbonBuilds: core/UIHelpers/Controls.lua
-- Mode toggle and check button widgets.

-- Mode toggle (+/x) ------------------------------------------------------

function EbonBuilds.UIHelpers.CreateModeToggle(parent, x, y)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(20)
    btn:SetHeight(22)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText("+")
    btn.modeLabel = label
    btn.multiplicative = false

    btn:SetScript("OnClick", function()
        btn.multiplicative = not btn.multiplicative
        btn.modeLabel:SetText(btn.multiplicative and "|cff19ff19x|r" or "+")
        if btn.onToggle then btn.onToggle() end
    end)
    return btn
end

-- Check button with label -------------------------------------------------

function EbonBuilds.UIHelpers.CreateCheckButton(parent, label, onClick)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(16, 16)

    local bg = cb:CreateTexture(nil, "BORDER")
    bg:SetAllPoints(cb)
    bg:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")

    local check = cb:CreateTexture(nil, "ARTWORK")
    check:SetSize(14, 14)
    check:SetPoint("CENTER", cb, "CENTER", 0, 0)
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:Hide()
    cb._check = check

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    text:SetText(label)
    text:SetTextColor(0.8, 0.8, 0.8)
    cb._label = text

    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if checked then check:Show() else check:Hide() end
        if onClick then onClick(self, checked) end
    end)

    return cb
end
