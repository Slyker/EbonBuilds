-- EbonBuilds: modules/ui/WeightsView.lua
-- Responsibility: host the Filters bar + EchoTable. Exposes Mount/Unmount so
-- any container (e.g. a tab page) can embed it on demand.

EbonBuilds.WeightsView = {}

local viewFrame

local function BuildViewFrame(parent)
    local f = CreateFrame("Frame", nil, parent)

    local header = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    header:SetText("Echo Weights")
    f._header = header

    local suggestBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    suggestBtn:SetSize(120, 20)
    suggestBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -8)
    suggestBtn:SetText("Suggest Weights")
    suggestBtn:SetScript("OnClick", function()
        local build = EbonBuilds.Build.GetActive()
        if not build then return end
        EbonBuilds.Build.EnsureSettings(build)
        local settings = build.settings
        local fb = settings.familyBonus or {}
        local qb = settings.qualityBonus or {}

        local list = EbonBuilds.EchoTableRows.BuildSortedList()
        local count = 0
        for _, entry in ipairs(list) do
            local weight = 20
            if entry.families and #entry.families > 0 then
                for _, fam in ipairs(entry.families) do
                    local key = fam
                    if fam == "Caster DPS" then key = "Caster"
                    elseif fam == "Melee DPS" then key = "Melee"
                    elseif fam == "Ranged DPS" then key = "Ranged" end
                    local fbVal = fb[key] or 0
                    if fbVal > 0 then weight = weight + fbVal end
                end
            end
            local qBonus = qb[entry.quality] or 0
            weight = weight + qBonus
            weight = math.max(0, math.floor(weight))
            EbonBuilds.Weights.Set(entry.name, weight)
            count = count + 1
        end
        print("|cff19ff19EbonBuilds:|r Suggested weights set for " .. count .. " echoes.")
    end)

    return f
end

local function EnsureBuilt(container)
    if viewFrame then return end
    viewFrame = BuildViewFrame(container)
    EbonBuilds.Filters.Init(viewFrame)
    EbonBuilds.EchoTable.Init(viewFrame)
end

local function RefreshHeader()
    if not viewFrame then return end
    local build = EbonBuilds.Build.GetActive()
    if build then
        viewFrame._header:SetText("Echo Weights - " .. (build.title or ""))
    else
        viewFrame._header:SetText("Echo Weights")
    end
end

function EbonBuilds.WeightsView.Mount(container)
    EnsureBuilt(container)
    viewFrame:SetParent(container)
    viewFrame:ClearAllPoints()
    viewFrame:SetAllPoints(container)
    RefreshHeader()
    viewFrame:Show()
    EbonBuilds.Filters.FocusSearch()
end

function EbonBuilds.WeightsView.Unmount()
    if viewFrame then viewFrame:Hide() end
end

function EbonBuilds.WeightsView.Init()
    if EbonBuilds.Build and EbonBuilds.Build.OnActiveChanged then
        EbonBuilds.Build.OnActiveChanged(RefreshHeader)
    end
end
