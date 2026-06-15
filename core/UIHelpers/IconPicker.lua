-- EbonBuilds: core/UIHelpers/IconPicker.lua
-- Searchable, scrollable icon grid picker.

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
    local searchEdit, searchContainer = EbonBuilds.UIHelpers.CreateSearchBox(picker, nil, 22, nil, "Search icons...")
    searchContainer:SetPoint("TOPLEFT",  picker, "TOPLEFT",  6, -6)
    searchContainer:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -6, -6)

    searchEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        picker:Hide()
    end)

    -- Scroll frame (viewport)
    local scrollFrame = CreateFrame("ScrollFrame", nil, picker)
    scrollFrame:SetPoint("TOPLEFT",     searchContainer, "BOTTOMLEFT", 0, -4)
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

    searchEdit:SetScript("OnTextChanged", function(self)
        ApplyFilter(self:GetText())
    end)

    picker:SetScript("OnShow", function()
        searchEdit:SetText("")
        searchEdit:ClearFocus()
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
        searchBox   = searchEdit,
        scrollFrame = scrollFrame,
        scrollBar   = scrollBar,
        pool        = pool,
        scanMsg     = scanMsg,
    }
end
