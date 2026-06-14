-- EbonBuilds: modules/ui/BuildOverview/MissingTab.lua
-- Missing echoes tab: shows echoes the build is missing, with scoring,
-- drop sources, and ban toggle.

local BO = EbonBuilds.BuildOverview
local UIH = EbonBuilds.UIHelpers
local CLASS_MASK = EbonBuilds.Constants.CLASS_BITS
local QUALITY_COLORS = EbonBuilds.Constants.QUALITY_COLORS
local EchoesData = BO.EchoesData

------------------------------------------------------------------------
-- ComputeMissingEchoes: echoes the build doesn't own
------------------------------------------------------------------------

local function ComputeMissingEchoes(build)
    if not build or not build.class then return nil end

    local classMask = CLASS_MASK[build.class] or 0
    local playerLevel = UnitLevel("player")

    local ownedLower = {}
    local ownedGroups = {}
    local spellbookIds = {}
    local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
    for tabIdx = 1, numTabs do
        local tabName, _, offset, numSpells = GetSpellTabInfo(tabIdx)
        if tabName == "Echoes" then
            for slot = offset + 1, offset + numSpells do
                local link = GetSpellLink(slot, "spell")
                local tomeSpellId = link and tonumber(link:match("spell:(%d+)"))
                if tomeSpellId then
                    spellbookIds[tomeSpellId] = true
                end
            end
            break
        end
    end

    for spellId, data in pairs(ProjectEbonhold.PerkDatabase) do
        local isOwned = spellbookIds[data.requiredSpell] or spellbookIds[spellId + 100000]
        if isOwned then
            local name = GetSpellInfo(spellId)
            local norm = EchoesData.NormalizeEchoName(name)
            if norm then ownedLower[norm] = true end
            if data.groupId then ownedGroups[data.groupId] = true end
        end
    end

    if ProjectEbonhold.PerkService.GetGrantedPerks then
        local granted = ProjectEbonhold.PerkService.GetGrantedPerks()
        for name in pairs(granted or {}) do
            local norm = EchoesData.NormalizeEchoName(name)
            if norm then ownedLower[norm] = true end
        end
    end

    local lockedLower = {}
    if build.lockedEchoes then
        for _, spellId in ipairs(build.lockedEchoes) do
            if spellId then
                local name = GetSpellInfo(spellId)
                if name then lockedLower[EchoesData.NormalizeEchoName(name)] = true end
            end
        end
    end

    local byName = {}
    for spellId, data in pairs(ProjectEbonhold.PerkDatabase) do
        local spellName = GetSpellInfo(spellId)
        if spellName then
            local key = EchoesData.NormalizeEchoName(spellName)
            local isOwned = ownedLower[key] or (data.groupId and ownedGroups[data.groupId])
            if not isOwned then
                if classMask == 0 or bit.band(data.classMask or 0, classMask) ~= 0 then
                    if not data.minLevel or playerLevel >= data.minLevel then
                        local existing = byName[key]
                        if not existing or (data.quality or 0) > (existing.quality or 0) then
                            byName[key] = { spellId = spellId, data = data, displayName = spellName }
                        end
                    end
                end
            end
        end
    end

    local settings = build.settings or EbonBuilds.Build.DefaultSettings()
    local banList = settings.echoBanList or {}
    local weights = build.echoWeights or {}
    local missing = {}
    for key, entry in pairs(byName) do
        local source = ProjectEbonhold.PerkDropSources and ProjectEbonhold.PerkDropSources[entry.spellId]
        if not source and entry.data.groupId and ProjectEbonhold.PerkDropSourceByGroup then
            source = ProjectEbonhold.PerkDropSourceByGroup[entry.data.groupId]
        end
        local needsTome = entry.data.requiredSpell and entry.data.requiredSpell > 0
        if not banList[entry.spellId] and needsTome then
            local scoringEntry = {
                spellId = entry.spellId,
                name = entry.displayName,
                quality = entry.data.quality or 0,
                families = entry.data.families,
                classMask = entry.data.classMask,
            }
            local weight = weights[entry.displayName] or 0
            local score = EbonBuilds.Scoring.Score(scoringEntry, weight, settings)
            missing[#missing + 1] = {
                spellId = entry.spellId,
                name = entry.displayName,
                quality = entry.data.quality or 0,
                dropSource = source or "Unknown",
                isLocked = lockedLower[key] or false,
                score = score,
            }
        end
    end

    table.sort(missing, function(a, b)
        if a.isLocked ~= b.isLocked then
            return a.isLocked
        end
        if a.score ~= b.score then
            return a.score > b.score
        end
        if a.quality ~= b.quality then
            return a.quality > b.quality
        end
        return a.name < b.name
    end)
    return missing
end

------------------------------------------------------------------------
-- BuildMissingTab: construct the missing echoes scroll frame
------------------------------------------------------------------------

local function BuildMissingTab(parent)
    local scroll, child, bar = UIH.CreateScroller(parent)
    scroll:SetPoint("TOPLEFT",     parent, "TOPLEFT",     10, -14)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -18, 8)
    child:SetWidth(460)
    UIH.WireScroller(scroll, bar, 16, child)

    return scroll, child, bar
end

------------------------------------------------------------------------
-- RefreshMissing: rebuild missing echoes row list
------------------------------------------------------------------------

local function RefreshMissing()
    local build = BO.state.build
    local missingChild = BO.missingChild
    local missingBar = BO.missingBar
    local missingScroll = BO.missingScroll
    local missingRows = BO.missingRows
    if not build or not missingChild then return end
    for _, btn in ipairs(missingRows) do btn:Hide() end
    local missing = ComputeMissingEchoes(build)
    if missing == nil then
        missingChild.loadingLabel = missingChild.loadingLabel or missingChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        missingChild.loadingLabel:SetPoint("TOPLEFT", missingChild, "TOPLEFT", 4, -2)
        missingChild.loadingLabel:SetText("Requesting data...")
        missingChild.loadingLabel:Show()
        missingChild:SetHeight(20)
        return
    end
    if missingChild.loadingLabel then
        missingChild.loadingLabel:Hide()
    end
    local currY = 0
    for _, entry in ipairs(missing) do
        local rowIdx = #missingRows + 1
        while #missingRows < rowIdx do
            local n = #missingRows + 1
            local btn = CreateFrame("Button", nil, missingChild)
            btn:SetPoint("LEFT", missingChild, "LEFT", 4, 0)
            btn:SetPoint("RIGHT", missingChild, "RIGHT", -4, 0)
            btn:RegisterForClicks("LeftButtonUp")
            btn:SetScript("OnEnter", function(self)
                if not self._spellId then return end
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:ClearLines()
                local spellName = GetSpellInfo(self._spellId)
                if spellName then
                    GameTooltip:AddLine(spellName, 1, 0.82, 0)
                end
                if utils and utils.GetSpellDescription then
                    local desc = utils.GetSpellDescription(self._spellId, 500, 1)
                    if desc and desc ~= "" then
                        GameTooltip:AddLine(desc, 1, 1, 1, true)
                    end
                end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetWidth(24)
            icon:SetHeight(24)
            icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            btn._icon = icon
            local labelName = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            labelName:SetPoint("TOPLEFT", icon, "TOPRIGHT", 2, 0)
            labelName:SetWidth(160)
            labelName:SetJustifyH("LEFT")
            btn._labelName = labelName
            local labelSource = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            labelSource:SetPoint("TOPLEFT", labelName, "TOPRIGHT", 4, 0)
            labelSource:SetWidth(200)
            labelSource:SetJustifyH("LEFT")
            labelSource:SetTextColor(0.6, 0.6, 0.6, 1)
            btn._labelSource = labelSource
            local labelScore = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            labelScore:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -70, -2)
            labelScore:SetWidth(54)
            labelScore:SetJustifyH("RIGHT")
            btn._labelScore = labelScore
            local banBtn = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
            banBtn:SetSize(56, 18)
            banBtn:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -4, -3)
            banBtn:SetText("Ban")
            banBtn:SetScript("OnClick", function(self)
                local spellId = self:GetParent()._spellId
                if not spellId then return end
                local b = BO.state.build
                if not b then return end
                EbonBuilds.Build.EnsureSettings(b)
                b.settings.echoBanList = b.settings.echoBanList or {}
                if b.settings.echoBanList[spellId] then
                    b.settings.echoBanList[spellId] = nil
                else
                    b.settings.echoBanList[spellId] = true
                end
                RefreshMissing()
            end)
            btn._banBtn = banBtn
            missingRows[n] = btn
        end
        local btn = missingRows[rowIdx]
        btn:ClearAllPoints()
        btn._spellId = entry.spellId
        btn._icon:SetTexture(select(3, GetSpellInfo(entry.spellId)))
        local cc = QUALITY_COLORS[entry.quality] or QUALITY_COLORS[0]
        btn._labelName:SetText(entry.name)
        btn._labelName:SetTextColor(cc[1], cc[2], cc[3], 1)
        local cleanSource = (entry.dropSource or ""):gsub("^Can be found on ", "")
        btn._labelSource:SetText(cleanSource)
        btn._labelScore:SetText(string.format("%.0f", entry.score))
        local b = BO.state.build
        if b then
            EbonBuilds.Build.EnsureSettings(b)
            local banList = b.settings and b.settings.echoBanList or {}
            if banList[entry.spellId] then
                btn._banBtn:SetText("Unban")
            else
                btn._banBtn:SetText("Ban")
            end
        end
        local srcH = btn._labelSource:GetStringHeight() or 16
        local rowH = math.max(26, srcH + 4)
        btn:SetHeight(rowH)
        btn:SetPoint("TOPLEFT", missingChild, "TOPLEFT", 0, -currY)
        btn:SetPoint("RIGHT", missingChild, "RIGHT", -4, 0)
        btn:Show()
        currY = currY + rowH + 2
    end
    missingChild:SetHeight(math.max(1, currY))
    missingBar:SetMinMaxValues(0, math.max(0, missingChild:GetHeight() - missingScroll:GetHeight()))
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

BO.ComputeMissingEchoes = ComputeMissingEchoes
BO.BuildMissingTab = BuildMissingTab
BO.RefreshMissing = RefreshMissing
