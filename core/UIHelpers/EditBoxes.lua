-- EbonBuilds: core/UIHelpers/EditBoxes.lua
-- Edit box, search box, number input, scrollable edit, description editor.

local Backdrop = EbonBuilds.UIHelpers.Backdrop

-- Backdrop edit box -------------------------------------------------------

function EbonBuilds.UIHelpers.CreateEditBox(parent, width, height, opts)
    opts = opts or {}
    local c = CreateFrame("Frame", nil, parent)
    if width then c:SetSize(width, height) end

    local bd = Backdrop(opts.backdrop == "chat" and "chat" or "tooltip")
    c:SetBackdrop(bd)
    c:SetBackdropColor(opts.bgColor or 0, opts.bgColor or 0, opts.bgColor or 0, 0.6)
    c:SetBackdropBorderColor(opts.borderColor or 0.4, opts.borderColor or 0.4, opts.borderColor or 0.4, 1)

    local box = CreateFrame("EditBox", nil, c)
    box:SetPoint("TOPLEFT",     c, "TOPLEFT",     4, -4)
    box:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -4,  4)
    box:SetFont("Fonts\\FRIZQT__.TTF", opts.fontSize or 12, "")
    box:SetTextColor(opts.textColorR or 1, opts.textColorG or 1, opts.textColorB or 1, opts.textColorA or 1)
    box:SetAutoFocus(false)

    if opts.multiLine then
        box:SetMultiLine(true)
        box:SetMaxLetters(0)
        box:EnableMouse(true)
    else
        box:SetMaxLetters(opts.maxLetters or 40)
    end

    if opts.justifyH then box:SetJustifyH(opts.justifyH) end
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    box:SetScript("OnEditFocusGained", function(self)
        if opts.onFocusGained then opts.onFocusGained(self) end
    end)
    box:SetScript("OnEditFocusLost", function(self)
        if opts.onFocusLost then opts.onFocusLost(self) end
    end)

    return box, c
end

-- Search box --------------------------------------------------------------

function EbonBuilds.UIHelpers.CreateSearchBox(parent, width, height, onChange)
    height = height or 22
    width = width or 140

    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(width, height)
    c:SetBackdrop(Backdrop("tooltip"))
    c:SetBackdropColor(0, 0, 0, 0.6)
    c:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local edit = CreateFrame("EditBox", nil, c)
    edit:SetSize(width - 6, height - 4)
    edit:SetPoint("CENTER", c, "CENTER", 0, 0)
    edit:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    edit:SetTextColor(1, 1, 1, 1)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(60)

    if onChange then
        edit:SetScript("OnTextChanged", function(self) onChange(self:GetText():lower()) end)
    end
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    return edit, c
end

-- Number-only edit box ----------------------------------------------------

function EbonBuilds.UIHelpers.CreateNumberEditBox(parent, width, height, allowNegative, allowDecimal)
    local box, c = EbonBuilds.UIHelpers.CreateEditBox(parent, width, height, {
        justifyH = "CENTER",
        maxLetters = 6,
    })
    c:SetBackdropColor(0, 0, 0, 0.6)
    c:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    box:SetScript("OnChar", function(self, char)
        local valid = (char >= "0" and char <= "9")
        if allowDecimal and char == "." then
            if not self:GetText():find("%.") then valid = true end
        end
        if allowNegative and char == "-" then
            if self:GetCursorPosition() == 0 then valid = true end
        end
        if not valid then
            local pos = self:GetCursorPosition()
            local text = self:GetText()
            self:SetText(string.sub(text, 1, pos) .. string.sub(text, pos + 2))
            self:SetCursorPosition(pos)
        end
    end)
    return box
end

-- Scrollable edit box (for Export/Import dialogs) -------------------------

function EbonBuilds.UIHelpers.CreateScrollableEditBox(parent, topAnchor, bottomAnchor)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOP",    topAnchor,    "BOTTOM", 0, -8)
    scroll:SetPoint("BOTTOM", bottomAnchor, "TOP",    0,  8)
    scroll:SetPoint("LEFT",   parent,       "LEFT",   14, 0)
    scroll:SetPoint("RIGHT",  parent,       "RIGHT", -14,  0)

    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
    box:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    box:SetWidth(640)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function() parent:Hide() end)
    scroll:SetScrollChild(box)

    return scroll, box
end

-- Scrollable multi-line description editor --------------------------------

function EbonBuilds.UIHelpers.CreateDescriptionEditor(parent, onChange)
    local c = CreateFrame("Frame", nil, parent)
    c:SetBackdrop(Backdrop("chat"))
    c:SetBackdropColor(0, 0, 0, 0.6)
    c:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local scroll = CreateFrame("ScrollFrame", nil, c)
    scroll:SetPoint("TOPLEFT",     c, "TOPLEFT",     6, -6)
    scroll:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -26, 6)
    scroll:EnableMouseWheel(true)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(1)
    child:SetHeight(1)
    scroll:SetScrollChild(child)

    local edit = CreateFrame("EditBox", nil, child)
    edit:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    edit:SetWidth(400)
    edit:SetHeight(1)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("GameFontNormalSmall")
    edit:SetMaxLetters(10000)
    edit:EnableMouseWheel(false)

    local measure = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    measure:SetWidth(400)
    measure:Hide()

    local bar = CreateFrame("Slider", nil, scroll, "UIPanelScrollBarTemplate")
    bar:SetPoint("TOPLEFT",    scroll, "TOPRIGHT",    2, -4)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 2,  4)
    bar:SetValueStep(20)

    local isUpdating = false
    local function syncBar(value)
        if isUpdating then return end
        isUpdating = true
        bar:SetValue(value)
        isUpdating = false
    end

    bar:SetScript("OnValueChanged", function(self, value)
        if isUpdating then return end
        isUpdating = true
        scroll:SetVerticalScroll(value)
        isUpdating = false
    end)

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local v = scroll:GetVerticalScroll()
        local _, max = bar:GetMinMaxValues()
        local new = math.max(0, math.min(max or 0, v - delta * 20))
        scroll:SetVerticalScroll(new)
        syncBar(new)
    end)

    scroll:SetScript("OnShow", function(self)
        local w = self:GetWidth()
        if w and w > 0 then
            edit:SetWidth(w)
            measure:SetWidth(w)
        end
    end)

    edit:SetScript("OnTextChanged", function(self)
        if onChange then onChange(self, self:GetText()) end
        measure:SetText(self:GetText())
        local th = measure:GetStringHeight() or 0
        local sh = scroll:GetHeight()
        local eh = math.max(th + 10, sh)
        child:SetHeight(eh)
        self:SetHeight(eh)
        bar:SetMinMaxValues(0, math.max(0, eh - sh))
    end)

    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    return {
        backdrop  = c,
        scroll    = scroll,
        child     = child,
        editBox   = edit,
        measure   = measure,
        bar       = bar,
    }
end
