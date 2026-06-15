-- EbonBuilds: modules/ui/Filters.lua
-- Responsibility: filter bar UI + filter state + list filtering.

EbonBuilds.Filters = {}

local FAMILIES = { "Tank", "Survivability", "Healer", "Caster DPS", "Melee DPS", "Ranged DPS", "No family" }

local function GetUIState()
    return (EbonBuildsDB and EbonBuildsDB.globalSettings and EbonBuildsDB.globalSettings.uiState) or {}
end

local function SaveFiltersUI()
    if not EbonBuildsDB or not EbonBuildsDB.globalSettings then return end
    local ui = EbonBuildsDB.globalSettings.uiState
    if not ui then return end
    ui.filtersSearch   = state.text
    ui.filtersQuality  = state.quality
    ui.filtersFamilies = state.families
    ui.filtersShowAllClasses = state.showAllClasses
end

local state = {
    text            = "",
    quality         = nil,
    families        = {},
    showAllClasses  = false,
}
local changeCallbacks = {}
local searchEditBox = nil

local function Notify()
    SaveFiltersUI()
    for i = 1, #changeCallbacks do
        changeCallbacks[i]()
    end
end

function EbonBuilds.Filters.OnChange(fn)
    changeCallbacks[#changeCallbacks + 1] = fn
end

------------------------------------------------------------------------
-- Apply
------------------------------------------------------------------------

local function FamiliesActive()
    for _ in pairs(state.families) do return true end
    return false
end

local function MatchesFamilies(entry)
    if not next(state.families) then return true end
    local has = {}
    local hasAnyFamily = false
    for _, fam in ipairs(entry.families or {}) do
        has[fam] = true
        hasAnyFamily = true
    end
    for required in pairs(state.families) do
        if required == "No family" then
            if hasAnyFamily then return false end
        else
            if not has[required] then return false end
        end
    end
    return true
end

local function PassesFilters(entry, famActive)
    if state.text ~= "" then
        if not entry.name:lower():find(state.text, 1, true) then return false end
    end
    if state.quality ~= nil then
        if not (entry.qualities and entry.qualities[state.quality]) then return false end
    end
    if famActive then
        if not MatchesFamilies(entry) then return false end
    end
    return true
end

function EbonBuilds.Filters.Apply(echoList)
    local out = {}
    local famActive = FamiliesActive()
    for i = 1, #echoList do
        local entry = echoList[i]
        if PassesFilters(entry, famActive) then
            out[#out + 1] = entry
        end
    end
    return out
end

------------------------------------------------------------------------
-- UI helpers
------------------------------------------------------------------------

local function CreateSearchBox(bar)
    local edit, container = EbonBuilds.UIHelpers.CreateSearchBox(bar, 140, 22, function(text)
        state.text = text
        Notify()
    end, "Search...")
    container:SetPoint("LEFT", bar, "LEFT", 0, 0)
    searchEditBox = edit
    if state.text and state.text ~= "" then
        edit:SetText(state.text)
    end
    return container
end

function EbonBuilds.Filters.FocusSearch()
    if searchEditBox then searchEditBox:SetFocus() end
end

function EbonBuilds.Filters.ShowAllClasses()
    return state.showAllClasses
end

local function CreateQualityDropdown(bar, leftAnchor)
    local dropdown = CreateFrame("Frame", "EbonBuildsFiltersQualityDD", bar, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", leftAnchor, "RIGHT", 0, -2)

    UIDropDownMenu_SetWidth(dropdown, 90)
    local items = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary" }
    if state.quality then
        UIDropDownMenu_SetText(dropdown, items[state.quality + 2] or "All")
    else
        UIDropDownMenu_SetText(dropdown, "All")
    end

    UIDropDownMenu_Initialize(dropdown, function()
        for index, name in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            local selectedQuality = (index == 1) and nil or (index - 2)
            info.checked = (state.quality == selectedQuality)
            info.func = function()
                if index == 1 then state.quality = nil else state.quality = index - 2 end
                UIDropDownMenu_SetText(dropdown, name)
                UIDropDownMenu_Initialize(dropdown, dropdown.initialize)
                Notify()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    return dropdown
end

local function CreateFamilyDropdown(bar, leftAnchor)
    local dropdown = CreateFrame("Frame", "EbonBuildsFiltersFamilyDD", bar, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", leftAnchor, "RIGHT", -6, 0)
    UIDropDownMenu_SetWidth(dropdown, 130)

    local function UpdateFamilyLabel()
        local count = 0
        for _ in pairs(state.families) do count = count + 1 end
        if count == 0 then
            UIDropDownMenu_SetText(dropdown, "All families")
        else
            UIDropDownMenu_SetText(dropdown, "Families (" .. count .. ")")
        end
    end

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, family in ipairs(FAMILIES) do
            local info = UIDropDownMenu_CreateInfo()
            info.text             = family
            info.isNotRadio       = true
            info.keepShownOnClick = true
            info.checked          = state.families[family] and true or false
            info.func             = function(_, _, _, checked)
                if checked then
                    state.families[family] = true
                else
                    state.families[family] = nil
                end
                UpdateFamilyLabel()
                Notify()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UpdateFamilyLabel()
    return dropdown
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------

function EbonBuilds.Filters.Init(parent)
    local ui = GetUIState()
    state.text            = ui.filtersSearch or ""
    state.quality         = ui.filtersQuality
    state.families        = ui.filtersFamilies or {}
    state.showAllClasses  = ui.filtersShowAllClasses or false

    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT",  parent, "TOPLEFT",   10, -34)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -34)
    bar:SetHeight(30)

    local searchContainer = CreateSearchBox(bar)
    local qualityDropdown = CreateQualityDropdown(bar, searchContainer)
    local familyDropdown  = CreateFamilyDropdown(bar, qualityDropdown)

    local cb = EbonBuilds.UIHelpers.CreateCheckButton(bar, "Show all classes", function(self, checked)
        state.showAllClasses = checked
        Notify()
    end)
    cb:SetPoint("LEFT", familyDropdown, "RIGHT", 2, 0)
    if state.showAllClasses then cb:SetChecked(true) end

    return bar
end
