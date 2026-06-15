-- EbonBuilds: core/UIHelpers/FrameFactory.lua
-- Window chrome, icon buttons, highlight borders, class icons.

local Backdrop = EbonBuilds.UIHelpers.Backdrop

-- Title bar ---------------------------------------------------------------

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

-- Close button ------------------------------------------------------------

function EbonBuilds.UIHelpers.CreateCloseButton(frame)
    local btn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    btn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    btn:SetFrameLevel(100)
    btn:SetScript("OnClick", function() frame:Hide() end)
    return btn
end

-- Dialog frame ------------------------------------------------------------

function EbonBuilds.UIHelpers.CreateDialogFrame(parent, width, height, title)
    local f = CreateFrame("Frame", nil, parent or UIParent)
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetBackdrop(Backdrop("dialog"))
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

-- Class icon --------------------------------------------------------------

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

-- Icon button -------------------------------------------------------------

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

-- Quality border (for locked echo slots) ---------------------------------

function EbonBuilds.UIHelpers.CreateQualityBorder(btn, inset)
    inset = inset or 1
    local border = btn:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -inset,  inset)
    border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  inset, -inset)
    border:Hide()
    btn._border = border
    return border
end

function EbonBuilds.UIHelpers.ApplyQualityBorder(border, quality)
    local r, g, b = EbonBuilds.Constants.GetQualityBorderColor(quality)
    border:SetTexture(r, g, b)
    border:Show()
end

-- Highlight border --------------------------------------------------------

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
