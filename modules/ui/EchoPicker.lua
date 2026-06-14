-- EbonBuilds: modules/ui/EchoPicker.lua
-- Responsibility: modal echo picker. Shows a searchable list of unique echoes
-- (highest-quality spellId per name) and invokes a callback with the picked id.

EbonBuilds.EchoPicker = {}

local QUALITY_COLOR = EbonBuilds.Constants.QUALITY_HEX
local ROW_HEIGHT = 24

local frame, searchBox, scrollFrame, scrollChild, scrollBar
local allEntries   = {}
local filtered     = {}
local rowPool      = {}
local onPick
local searchText   = ""

------------------------------------------------------------------------
-- Data
------------------------------------------------------------------------

local function BuildEntries()
    local best = EbonBuilds.EchoTableRows.BuildBestByName()
    local list = {}
    for name, entry in pairs(best) do
        list[#list + 1] = {
            spellId = entry.spellId,
            name    = name,
            quality = entry.quality,
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function ApplySearch()
    filtered = {}
    if searchText == "" then
        for i = 1, #allEntries do filtered[i] = allEntries[i] end
        return
    end
    for i = 1, #allEntries do
        local e = allEntries[i]
        if e.name:lower():find(searchText, 1, true) then
            filtered[#filtered + 1] = e
        end
    end
end

------------------------------------------------------------------------
-- Row pool / render
------------------------------------------------------------------------

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetTexture(1, 1, 1, 0.1)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row._icon = icon

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT",  icon, "RIGHT", 6, 0)
    label:SetPoint("RIGHT", row,  "RIGHT", -4, 0)
    label:SetJustifyH("LEFT")
    row._label = label
    return row
end

local function PopulateRow(row, index, entry)
    row:ClearAllPoints()
    row:SetPoint("LEFT",  scrollChild, "LEFT",  0, 0)
    row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
    row:SetPoint("TOP",   scrollChild, "TOP",   0, -(index - 1) * ROW_HEIGHT)
    row._icon:SetTexture(select(3, GetSpellInfo(entry.spellId)))
    local color = QUALITY_COLOR[entry.quality] or "ffffff"
    row._label:SetText("|cff" .. color .. entry.name .. "|r")
    row:SetScript("OnClick", function()
        if onPick then onPick(entry.spellId, entry.quality, entry.name) end
        frame:Hide()
    end)
    row:Show()
end

local function Render()
    for i = 1, #filtered do
        if not rowPool[i] then rowPool[i] = CreateRow(scrollChild, i) end
        PopulateRow(rowPool[i], i, filtered[i])
    end
    for i = #filtered + 1, #rowPool do rowPool[i]:Hide() end
    scrollChild:SetHeight(math.max(1, #filtered * ROW_HEIGHT))
end

------------------------------------------------------------------------
-- Frame construction
------------------------------------------------------------------------

local function ApplyBackdrop(f)
    f:SetBackdrop(EbonBuilds.UIHelpers.Backdrop())
end

local function CreateSearchBox(parent)
    local searchW = 360
    local box, container = EbonBuilds.UIHelpers.CreateSearchBox(parent, searchW, 22, function(text)
        searchText = text
        ApplySearch()
        Render()
    end)
    container:SetPoint("TOP", parent, "TOP", 0, -36)
    return box
end

local function BuildFrame()
    local f = CreateFrame("Frame", "EbonBuildsEchoPicker", UIParent)
    f:SetWidth(400)
    f:SetHeight(500)
    f:SetPoint("CENTER", UIParent, "CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    ApplyBackdrop(f)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("Pick an Echo")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() f:Hide() end)

    searchBox = CreateSearchBox(f)

    scrollFrame = CreateFrame("ScrollFrame", "EbonBuildsEchoPickerSF", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     f, "TOPLEFT",      16, -70)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -36,  16)
    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(340)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    f:Hide()
    return f
end

------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------

function EbonBuilds.EchoPicker.Show(callback, dataSource)
    if not frame then
        frame = BuildFrame()
    end
    if type(dataSource) == "table" then
        allEntries = dataSource
    elseif dataSource then
        allEntries = EbonBuilds.EchoTableRows.BuildAllQualitiesList()
    else
        allEntries = BuildEntries()
    end
    onPick = callback
    searchBox:SetText("")
    searchText = ""
    ApplySearch()
    Render()
    frame:Show()
    searchBox:SetFocus()
end

function EbonBuilds.EchoPicker.Hide()
    if frame then frame:Hide() end
end
