-- EbonBuilds: core/UIHelpers.lua
-- Shared UI widget factories. Eliminates repetitive frame-creation code.

EbonBuilds.UIHelpers = {}

local C = EbonBuilds.Constants

-- Backdrop ---------------------------------------------------------------

local TOOLTIP_BD = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local DIALOG_BD = {
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

function EbonBuilds.UIHelpers.Backdrop(kind)
    if kind == "tooltip" then
        return TOOLTIP_BD
    end
    return DIALOG_BD
end

-- Window chrome ----------------------------------------------------------

function EbonBuilds.UIHelpers.CreateTitleBar(frame, title)
    local titleStr = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleStr:SetPoint("TOP", frame, "TOP", 0, -16)
    titleStr:SetText(title)
    frame._titleStr = titleStr

    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0,   0)
    drag:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -37, 0)
    drag:SetHeight(30)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() frame:StartMoving() end)
    drag:SetScript("OnDragStop",  function() frame:StopMovingOrSizing() end)

    return titleStr, drag
end

function EbonBuilds.UIHelpers.CreateCloseButton(frame)
    local btn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    btn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    btn:SetFrameLevel(100)
    btn:SetScript("OnClick", function() frame:Hide() end)
    return btn
end

function EbonBuilds.UIHelpers.CreateDialogFrame(parent, width, height, title)
    local f = CreateFrame("Frame", nil, parent or UIParent)
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetBackdrop(DIALOG_BD)
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self:StartMoving() end
    end)
    f:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
    f:Hide()

    if title then
        EbonBuilds.UIHelpers.CreateTitleBar(f, title)
        EbonBuilds.UIHelpers.CreateCloseButton(f)
    end

    return f
end

-- Class icon -------------------------------------------------------------

local CLASS_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local CLASS_SQUARE_TCOORDS = {
    ["WARRIOR"]     = { 0,     0.25,  0,    0.25 },
    ["MAGE"]        = { 0.25,  0.5,   0,    0.25 },
    ["ROGUE"]       = { 0.5,   0.75,  0,    0.25 },
    ["DRUID"]       = { 0.75,  1.0,   0,    0.25 },
    ["HUNTER"]      = { 0,     0.25,  0.25, 0.5  },
    ["SHAMAN"]      = { 0.25,  0.5,   0.25, 0.5  },
    ["PRIEST"]      = { 0.5,   0.75,  0.25, 0.5  },
    ["WARLOCK"]     = { 0.75,  1.0,   0.25, 0.5  },
    ["PALADIN"]     = { 0,     0.25,  0.5,  0.75 },
    ["DEATHKNIGHT"] = { 0.25,  0.5,   0.5,  0.75 },
}

function EbonBuilds.UIHelpers.SetClassIcon(tex, classToken)
    local coords = CLASS_SQUARE_TCOORDS[classToken]
    tex:SetTexture(CLASS_TEXTURE)
    if coords then
        tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
end

-- Icon button ------------------------------------------------------------

function EbonBuilds.UIHelpers.CreateIconButton(parent, size)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(size)
    btn:SetHeight(size)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    icon:SetTexCoord(0, 1, 0, 1)
    btn._icon = icon
    return btn
end

-- Highlight border -------------------------------------------------------

function EbonBuilds.UIHelpers.HighlightBorder(btn, on)
    if not btn._hl then
        local b = btn:CreateTexture(nil, "OVERLAY")
        b:SetAllPoints(btn)
        b:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        b:SetBlendMode("ADD")
        b:Hide()
        btn._hl = b
    end
    if on then btn._hl:Show() else btn._hl:Hide() end
end

-- Tooltip helpers --------------------------------------------------------

function EbonBuilds.UIHelpers.WireLockedIconTooltip(frame)
    frame:SetScript("OnEnter", function(self)
        local id = self.spellId or self._spellId
        if not id then return end
        local spellName = GetSpellInfo(id)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        if spellName then GameTooltip:AddLine(spellName, 1, 0.82, 0) end
        if utils and utils.GetSpellDescription then
            local desc = utils.GetSpellDescription(id, 500, 1)
            if desc and desc ~= "" then GameTooltip:AddLine(desc, 1, 1, 1, true) end
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Backdrop edit box ------------------------------------------------------

local CHAT_BD = {
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function EbonBuilds.UIHelpers.CreateEditBox(parent, width, height, opts)
    opts = opts or {}
    local c = CreateFrame("Frame", nil, parent)
    if width then c:SetSize(width, height) end

    local bd
    if opts.backdrop == "chat" then
        bd = CHAT_BD
    else
        bd = TOOLTIP_BD
    end
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

-- Search box -------------------------------------------------------------

function EbonBuilds.UIHelpers.CreateSearchBox(parent, width, height, onChange)
    height = height or 22
    width = width or 140

    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(width, height)
    c:SetBackdrop(TOOLTIP_BD)
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

-- Number-only edit box ---------------------------------------------------

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

-- Scrollable edit box (for Export/Import dialogs) -----------------------

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

-- Scrollbar wiring -------------------------------------------------------

function EbonBuilds.UIHelpers.WireScrollBar(scrollFrame, scrollBar, stepSize, onScroll)
    stepSize = stepSize or 20
    scrollBar:SetValueStep(stepSize)

    scrollBar:SetScript("OnValueChanged", function(self, value)
        if onScroll then onScroll(value) end
    end)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local v = scrollBar:GetValue()
        local mn, mx = scrollBar:GetMinMaxValues()
        scrollBar:SetValue(math.max(mn, math.min(mx, v - delta * stepSize)))
    end)
end

-- Time formatting --------------------------------------------------------

function EbonBuilds.UIHelpers.FormatDuration(startTime, endTime)
    local t = (endTime or time()) - startTime
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = math.floor(t % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

function EbonBuilds.UIHelpers.FormatTimestamp(ts)
    return date("%H:%M:%S", ts)
end

-- Color string helpers ---------------------------------------------------

function EbonBuilds.UIHelpers.QColorHex(quality)
    return C.QUALITY_HEX[quality] or "ffffff"
end

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

-- Generic tooltip wiring ------------------------------------------------

function EbonBuilds.UIHelpers.WireTooltip(frame, enterFn)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        if enterFn(self) ~= false then
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ScrollFrame + child + bar combo ---------------------------------------

function EbonBuilds.UIHelpers.CreateScroller(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(1)
    child:SetHeight(1)
    scroll:SetScrollChild(child)

    local bar = CreateFrame("Slider", nil, scroll, "UIPanelScrollBarTemplate")
    bar:SetPoint("TOPLEFT",    scroll, "TOPRIGHT",    -2, -4)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", -2,  4)
    bar:SetValueStep(20)

    return scroll, child, bar
end

-- Wire scroll bar to target (nil=SetVerticalScroll, frame=SetPoint, fn=callback)

function EbonBuilds.UIHelpers.WireScroller(scrollFrame, bar, stepSize, target)
    stepSize = stepSize or 20
    bar:SetValueStep(stepSize)

    local onScroll
    if type(target) == "function" then
        onScroll = target
    elseif target then
        onScroll = function(value) target:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, value) end
    else
        onScroll = function(value) scrollFrame:SetVerticalScroll(value) end
    end

    bar:SetScript("OnValueChanged", function(self, value) onScroll(value) end)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local v = bar:GetValue()
        local mn, mx = bar:GetMinMaxValues()
        bar:SetValue(math.max(mn, math.min(mx, v - delta * stepSize)))
    end)
end

-- Icon picker (searchable, scrollable icon grid) -------------------------
--
-- opts:
--   onPick(iconPath)   – called when user clicks an icon
--   cols / size / gap / pad / height – layout tuning
--   iconList           – table of icon paths (default EbonBuilds.IconList)
--   backdropColor      – { r, g, b, a } (default 0.08, 0.08, 0.08, 1)
--   borderColor        – { r, g, b, a } (default 1, 0.82, 0, 0.8)
-- Returns { frame, catcher, searchBox, scrollFrame, scrollBar, pool, scanMsg }

function EbonBuilds.UIHelpers.CreateIconPicker(opts)
    opts = opts or {}
    local onPick     = opts.onPick
    local cols       = opts.cols       or 5
    local size       = opts.size       or 28
    local gap        = opts.gap        or 4
    local pad        = opts.pad        or 6
    local pickerW    = cols * (size + gap) + pad * 2 + 26
    local pickerH    = opts.height     or 350
    local iconList   = opts.iconList   or EbonBuilds.IconList
    local bg         = opts.backdropColor or { 0.08, 0.08, 0.08, 1 }
    local bc         = opts.borderColor   or { 1, 0.82, 0, 0.8 }

    -- Picker frame
    local picker = CreateFrame("Frame", nil, UIParent)
    picker:SetSize(pickerW, pickerH)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetToplevel(true)
    picker:EnableMouse(true)
    picker:SetClampedToScreen(true)
    picker:SetBackdrop{
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    }
    picker:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    picker:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4])

    -- Catcher – below the picker at the same strata
    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetFrameLevel(picker:GetFrameLevel())
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown",  function() picker:Hide() end)
    catcher:SetScript("OnMouseWheel", function() picker:Hide() end)
    catcher:Hide()
    picker:SetFrameLevel(catcher:GetFrameLevel() + 1)
    picker:SetScript("OnHide", function() catcher:Hide() end)

    -- Search box
    local searchBox = CreateFrame("EditBox", nil, picker, "InputBoxTemplate")
    searchBox:SetPoint("TOPLEFT",  picker, "TOPLEFT",  6, -6)
    searchBox:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -24, -6)
    searchBox:SetHeight(20)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        picker:Hide()
    end)

    -- Scroll frame (viewport)
    local scrollFrame = CreateFrame("ScrollFrame", nil, picker)
    scrollFrame:SetPoint("TOPLEFT",     searchBox, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", picker,    "BOTTOMRIGHT", -6, 6)
    scrollFrame:EnableMouseWheel(true)

    local viewportRows = math.max(1, math.floor((pickerH - 36) / (size + gap)) + 2)

    -- Pool buttons (virtual scrolling)
    local pool = {}
    for i = 1, viewportRows * cols do
        local btn = CreateFrame("Button", nil, scrollFrame)
        btn:SetSize(size, size)
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(btn)
        btn._tex = tex
        btn:SetScript("OnClick", function(self)
            if onPick then onPick(self._path) end
            picker:Hide()
        end)
        if opts.onMakePoolBtn then opts.onMakePoolBtn(btn) end
        pool[i] = btn
    end

    -- "Scanning…" overlay
    local scanMsg = scrollFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scanMsg:SetPoint("CENTER")
    scanMsg:SetText("Scanning icons...")
    scanMsg:SetTextColor(0.6, 0.6, 0.6)

    -- State
    local filteredIndices
    local topIdx = 1

    -- Scrollbar
    local scrollBar = CreateFrame("Slider", nil, scrollFrame, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPLEFT",    scrollFrame, "TOPRIGHT",   -4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -4, 0)
    scrollBar:SetValueStep(1)

    local function RepositionVisible()
        local list = filteredIndices or iconList
        local n = #list
        if #iconList > 0 then scanMsg:Hide() end
        for pi, btn in ipairs(pool) do
            local col = (pi - 1) % cols
            local row = math.floor((pi - 1) / cols)
            local iconIdx = topIdx + row * cols + col
            if iconIdx <= n then
                local raw = list[iconIdx]
                local path = filteredIndices and iconList[raw] or raw
                btn._path = path
                btn._tex:SetTexture(path)
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT",
                    pad + col * (size + gap),
                    -(pad + row * (size + gap)))
                btn:Show()
            else
                btn:Hide()
            end
        end
    end

    scrollBar:SetScript("OnValueChanged", function(self, value)
        topIdx = math.floor(value + 0.5) * cols + 1
        RepositionVisible()
    end)

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local mn, mx = scrollBar:GetMinMaxValues()
        local v = scrollBar:GetValue()
        scrollBar:SetValue(math.max(mn, math.min(mx, v - delta)))
    end)

    local function UpdateScrollRange()
        local list = filteredIndices or iconList
        local totalRows = math.max(1, math.ceil(#list / cols))
        scrollBar:SetMinMaxValues(0, math.max(0, totalRows - viewportRows + 2))
    end

    -- Filter
    local function ApplyFilter(text)
        text = text:lower()
        if text == "" then
            filteredIndices = nil
        else
            filteredIndices = {}
            for idx = 1, #iconList do
                if iconList[idx]:lower():find(text, 1, true) then
                    tinsert(filteredIndices, idx)
                end
            end
        end
        topIdx = 1
        UpdateScrollRange()
        scrollBar:SetValue(0)
        RepositionVisible()
    end

    searchBox:SetScript("OnTextChanged", function(self)
        ApplyFilter(self:GetText())
    end)

    picker:SetScript("OnShow", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
        filteredIndices = nil
        topIdx = 1
        UpdateScrollRange()
        scrollBar:SetValue(0)
        if #iconList == 0 then scanMsg:Show() else scanMsg:Hide() end
    end)

    picker:Hide()

    return {
        frame       = picker,
        catcher     = catcher,
        searchBox   = searchBox,
        scrollFrame = scrollFrame,
        scrollBar   = scrollBar,
        pool        = pool,
        scanMsg     = scanMsg,
    }
end

-- Check button with label ------------------------------------------------

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

-- Scrollable multi-line description editor -------------------------------

function EbonBuilds.UIHelpers.CreateDescriptionEditor(parent, onChange)
    local c = CreateFrame("Frame", nil, parent)
    c:SetBackdrop(CHAT_BD)
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
