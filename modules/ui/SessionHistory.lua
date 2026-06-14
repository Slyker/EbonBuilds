-- EbonBuilds: modules/ui/SessionHistory.lua
-- Responsibility: session history UI replacing the Logbook tab content.
-- Top: horizontal row of session cards. Bottom: full-width log table.

EbonBuilds.SessionHistory = {}

local QUALITY_HEX = EbonBuilds.Constants.QUALITY_HEX
local ACTION_COLORS = {
    Banish         = { 1.0, 0.27, 0.27 },
    Reroll         = { 0.27, 0.67, 1.0 },
    Freeze         = { 0.27, 0.80, 1.0 },
    Select         = { 0.27, 1.0, 0.27 },
    ["Select (Locked)"] = { 1.0, 0.53, 0.0 },
}

local CARD_W     = 170
local CARD_H     = 48
local CARD_GAP   = 6
local TOP_H      = 68

local topPanel, bottomPanel
local sessionItems = {}
local logRows      = {}
local selectedSessionId = nil

local sessionChild, sessionClip, scrollOffset = nil, nil, 0
local logScroll, logChild, logBar
local durationTimer
local logRefreshTimer
local echoContextMenu
local WEIGHT_ADJUST = 10
local logActionFilter = nil
local logSearchText = ""

------------------------------------------------------------------------
-- Spell info lookup
------------------------------------------------------------------------

local spellInfoCache

local function EnsureSpellInfoCache()
    if spellInfoCache then return spellInfoCache end
    spellInfoCache = {}

    local bestByName = EbonBuilds.EchoTableRows.BuildBestByName()
    for name, entry in pairs(bestByName) do
        local spellId = entry.spellIds and entry.quality and entry.spellIds[entry.quality]
        if not spellId then spellId = entry.spellId end
        if spellId then
            spellInfoCache[name] = {
                spellId   = spellId,
                quality   = entry.quality,
                families  = entry.families,
                classMask = entry.classMask,
            }
        end
    end

    for spellId, data in pairs(ProjectEbonhold.PerkDatabase) do
        local raw = data.comment
        if raw and raw ~= "" then
            local name = EbonBuilds.Constants.StripQualitySuffix(raw)
            if not spellInfoCache[name] or (data.quality or 0) > (spellInfoCache[name].quality or 0) then
                spellInfoCache[name] = {
                    spellId   = spellId,
                    quality   = data.quality,
                    families  = data.families,
                    classMask = data.classMask,
                }
            end
        end
    end

    return spellInfoCache
end

local function GetSpellInfoForEcho(echoName)
    local cache = EnsureSpellInfoCache()
    return cache and cache[echoName]
end

------------------------------------------------------------------------
-- Echo tooltip (custom frame with icon)
------------------------------------------------------------------------

local QUALITY_LABELS = EbonBuilds.Constants.QUALITY_LABELS
local ICON_SIZE = 32
local LINE_H   = 14

local echoTooltip

local function CreateEchoTooltip()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.95)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f._icon = icon

    f._lines = {}
    f:Hide()
    return f
end

local TOOLTIP_WIDTH = 250

local function ShowEchoTooltip(owner, echoName, showIcon)
    if not echoName then return end
    if not echoTooltip then echoTooltip = CreateEchoTooltip() end

    for _, fs in ipairs(echoTooltip._lines) do fs:Hide() end

    local spellData = GetSpellInfoForEcho(echoName)
    local spellId = spellData and spellData.spellId
    local quality = spellData and spellData.quality

    if showIcon then
        if spellId then
            local _, _, tex = GetSpellInfo(spellId)
            echoTooltip._icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
        else
            echoTooltip._icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        echoTooltip._icon:Show()
    else
        echoTooltip._icon:Hide()
    end

    local textW = showIcon and (TOOLTIP_WIDTH - ICON_SIZE - 26) or (TOOLTIP_WIDTH - 20)
    local lineIdx = 0
    local function AddLine(text, r, g, b, isHeader)
        lineIdx = lineIdx + 1
        local fs = echoTooltip._lines[lineIdx]
        if not fs then
            fs = echoTooltip:CreateFontString(nil, "OVERLAY",
                isHeader and "GameFontNormal" or "GameFontNormalSmall")
            echoTooltip._lines[lineIdx] = fs
        end
        fs:SetWidth(textW)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText(text)
        fs:SetTextColor(r or 1, g or 1, b or 1)
        if lineIdx == 1 then
            if showIcon then
                fs:SetPoint("TOPLEFT", echoTooltip._icon, "TOPRIGHT", 8, 0)
            else
                fs:SetPoint("TOPLEFT", echoTooltip, "TOPLEFT", 10, -10)
            end
        else
            fs:SetPoint("TOPLEFT", echoTooltip._lines[lineIdx - 1], "BOTTOMLEFT", 0, -2)
        end
        fs:Show()
    end

    AddLine(echoName, 1, 0.82, 0, true)

    if quality and QUALITY_LABELS[quality] then
        AddLine(QUALITY_LABELS[quality], 0.8, 0.8, 0.8)
    end

    if spellId and utils and utils.GetSpellDescription then
        local desc = utils.GetSpellDescription(spellId, 500, 1)
        if desc and desc ~= "" then
            AddLine(" ")
            AddLine(desc, 1, 1, 1)
        end
    end

    if spellData and spellData.families and #spellData.families > 0 then
        AddLine(" ")
        AddLine("Families: " .. table.concat(spellData.families, ", "), 0.6, 0.8, 1.0)
    end

    if spellData then
        local settings = EbonBuilds.Scoring.GetEffectiveSettings()
        local weight = EbonBuilds.Weights.Get(echoName)
        local parts, total = EbonBuilds.Scoring.ScoreBreakdown(spellData, weight, settings)
        AddLine(" ")
        for _, p in ipairs(parts) do
            AddLine(p.label .. ": " .. tostring(p.value), 0.7, 0.7, 0.7)
        end
        AddLine("Score: " .. string.format("%.0f", total), 1, 0.82, 0, true)

        local peak = EbonBuilds.Automation and EbonBuilds.Automation.GetPeak and EbonBuilds.Automation.GetPeak() or 1
        local banThresh = math.floor(peak * (settings.autoBanishPct or 20) / 100)
        local freezeThresh = math.floor(peak * (settings.autoFreezePct or 80) / 100)
        AddLine(" ")
        AddLine("|cffff6666Banish < " .. banThresh .. "|r  |cff66ccffFreeze > " .. freezeThresh .. "|r", 0.6, 0.6, 0.6)
    end

    local settings2 = EbonBuilds.Scoring.GetEffectiveSettings()
    local banList = settings2 and settings2.echoBanList or {}
    if spellId and banList[spellId] then
        AddLine(" ")
        AddLine("BANNED", 1, 0.27, 0.27)
    end

    AddLine(" ")
    AddLine("|cff888888Right-click for options|r", 0.53, 0.53, 0.53)

    local totalH = 20
    for i = 1, lineIdx do
        totalH = totalH + (echoTooltip._lines[i]:GetStringHeight() or LINE_H) + 2
    end
    if showIcon then
        totalH = math.max(totalH, ICON_SIZE + 20)
    end

    echoTooltip:SetWidth(TOOLTIP_WIDTH)
    echoTooltip:SetHeight(totalH)
    echoTooltip:ClearAllPoints()

    local atRight = true
    echoTooltip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 8, 0)
    local rgt = echoTooltip:GetRight()
    if rgt and rgt > GetScreenWidth() then
        echoTooltip:ClearAllPoints()
        echoTooltip:SetPoint("TOPRIGHT", owner, "TOPLEFT", -8, 0)
        atRight = false
    end
    local btm = echoTooltip:GetBottom()
    if btm and btm < 0 then
        echoTooltip:ClearAllPoints()
        if atRight then
            echoTooltip:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 8, 0)
        else
            echoTooltip:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", -8, 0)
        end
    end

    echoTooltip:Show()
end

local function HideEchoTooltip()
    if echoTooltip then echoTooltip:Hide() end
end

------------------------------------------------------------------------
-- Context menu
------------------------------------------------------------------------

local function CloseMenu()
    if echoContextMenu then echoContextMenu:Hide() end
end

local function ToggleBan(echoName)
    local build = EbonBuilds.Build.GetActive()
    if not build then return end
    EbonBuilds.Build.EnsureSettings(build)
    local settings = build.settings

    local spellData = GetSpellInfoForEcho(echoName)
    if not spellData or not spellData.spellId then return end

    settings.echoBanList = settings.echoBanList or {}
    if settings.echoBanList[spellData.spellId] then
        settings.echoBanList[spellData.spellId] = nil
    else
        settings.echoBanList[spellData.spellId] = true
    end
end

local function AdjustWeight(echoName, delta)
    local current = EbonBuilds.Weights.Get(echoName)
    EbonBuilds.Weights.Set(echoName, current + delta)
end

local function BuildContextMenu()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetWidth(160)
    f:SetBackdrop(EbonBuilds.UIHelpers.TOOLTIP_BD)
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    f._items = {}
    f:Hide()

    -- Click outside to close
    f:SetScript("OnShow", function(self)
        if not self._catcher then
            local catcher = CreateFrame("Frame", nil, UIParent)
            catcher:SetAllPoints(UIParent)
            catcher:EnableMouse(true)
            catcher:SetFrameStrata("FULLSCREEN_DIALOG")
            catcher:SetFrameLevel(f:GetFrameLevel() - 1)
            catcher:SetScript("OnMouseDown", function() CloseMenu() end)
            self._catcher = catcher
        end
        self._catcher:Show()
    end)
    f:SetScript("OnHide", function(self)
        if self._catcher then self._catcher:Hide() end
    end)

    return f
end

local function ShowContextMenu(owner, echoName)
    if not echoContextMenu then
        echoContextMenu = BuildContextMenu()
    end

    echoContextMenu._echoName = echoName

    -- Clear previous items
    for _, item in ipairs(echoContextMenu._items) do
        item:Hide()
    end
    echoContextMenu._items = {}

    -- Check current ban status
    local build = EbonBuilds.Build.GetActive()
    local spellData = GetSpellInfoForEcho(echoName)
    local isBanned = false
    if build and spellData and spellData.spellId then
        EbonBuilds.Build.EnsureSettings(build)
        local banList = build.settings and build.settings.echoBanList or {}
        isBanned = banList[spellData.spellId] and true or false
    end

    local function AddItem(text, onClick)
        local idx = #echoContextMenu._items
        local item = CreateFrame("Button", nil, echoContextMenu)
        item:SetPoint("TOPLEFT", echoContextMenu, "TOPLEFT", 4, -(8 + idx * 18))
        item:SetPoint("TOPRIGHT", echoContextMenu, "TOPRIGHT", -4, -(8 + idx * 18))
        item:SetHeight(16)

        local fs = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", item, "LEFT", 6, 0)
        fs:SetText(text)

        item:SetScript("OnEnter", function(self) fs:SetTextColor(1, 0.82, 0) end)
        item:SetScript("OnLeave", function(self) fs:SetTextColor(1, 1, 1) end)
        item:SetScript("OnClick", function(self)
            CloseMenu()
            onClick()
        end)

        echoContextMenu._items[idx + 1] = item
    end

    if isBanned then
        AddItem("Unban Echo", function() ToggleBan(echoName) end)
    else
        AddItem("Ban Echo", function() ToggleBan(echoName) end)
    end

    AddItem("Increase Weight (+" .. WEIGHT_ADJUST .. ")", function()
        AdjustWeight(echoName, WEIGHT_ADJUST)
    end)

    AddItem("Decrease Weight (-" .. WEIGHT_ADJUST .. ")", function()
        AdjustWeight(echoName, -WEIGHT_ADJUST)
    end)

    local currentWeight = EbonBuilds.Weights.Get(echoName)
    AddItem("Set Weight to... (current: " .. currentWeight .. ")", function()
        EbonBuilds._pendingWeightEcho = echoName
        StaticPopup_Show("EBONBUILDS_SET_WEIGHT")
    end)

    if currentWeight ~= 0 then
        AddItem("Reset Weight to 0", function()
            EbonBuilds.Weights.Set(echoName, 0)
        end)
    end

    echoContextMenu:SetHeight(#echoContextMenu._items * 18 + 16)

    echoContextMenu:ClearAllPoints()
    echoContextMenu:SetPoint("TOPLEFT", owner, "TOPRIGHT", 4, 0)
    echoContextMenu:Show()
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local FormatDuration = EbonBuilds.UIHelpers.FormatDuration
local FormatTimestamp = EbonBuilds.UIHelpers.FormatTimestamp

------------------------------------------------------------------------
-- Duration timer (updates active session card every ~1s)
------------------------------------------------------------------------

local activeSessionCard = nil

local function OnDurationTick(self, dt)
    self._elapsed = (self._elapsed or 0) + dt
    if self._elapsed < 1 then return end
    self._elapsed = 0

    if not activeSessionCard then
        self:Hide()
        return
    end
    if not activeSessionCard._isActive then
        activeSessionCard = nil
        self:Hide()
        return
    end
    activeSessionCard._durationLabel:SetText(FormatDuration(activeSessionCard._startTime, nil))
end

local function StartDurationTimer(card)
    activeSessionCard = card
    if not durationTimer then
        durationTimer = CreateFrame("Frame")
        durationTimer:SetScript("OnUpdate", OnDurationTick)
    end
    durationTimer._elapsed = 0
    durationTimer:Show()
end

------------------------------------------------------------------------
-- Session cards (horizontal row at top)
------------------------------------------------------------------------

local function ClearSessionItems()
    for _, item in ipairs(sessionItems) do
        item:Hide()
    end
end

local function SelectSession(id)
    selectedSessionId = id
    for _, item in ipairs(sessionItems) do
        if item._id == id then
            item:SetBackdropBorderColor(1.0, 0.84, 0.0, 1)
        else
            local isActive = item._isActive
            item:SetBackdropBorderColor(isActive and 0.27 or 0.4, isActive and 1.0 or 0.4, isActive and 0.27 or 0.4, 1)
        end
    end
    EbonBuilds.SessionHistory.RefreshLogView()
end

local function BuildCard(parent)
    local item = CreateFrame("Frame", nil, parent)
    item:SetSize(CARD_W, CARD_H)

    item:SetBackdrop(EbonBuilds.UIHelpers.TOOLTIP_BD)
    item:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    item:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    item:EnableMouse(true)

    item._levelLabel = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item._levelLabel:SetPoint("TOPLEFT", item, "TOPLEFT", 6, -4)
    item._levelLabel:SetPoint("RIGHT", item, "RIGHT", -6, 0)
    item._levelLabel:SetTextColor(0.7, 0.7, 0.7, 1)

    item._soulLabel = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item._soulLabel:SetPoint("TOPLEFT", item._levelLabel, "BOTTOMLEFT", 0, -2)
    item._soulLabel:SetPoint("RIGHT", item, "RIGHT", -6, 0)
    item._soulLabel:SetTextColor(0.7, 0.7, 0.7, 1)

    item._durationLabel = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item._durationLabel:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 6, 4)
    item._durationLabel:SetTextColor(0.5, 0.5, 0.5, 1)

    -- Delete button (hidden for active sessions)
    local delBtn = CreateFrame("Button", nil, item)
    delBtn:SetSize(14, 14)
    delBtn:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -6, 4)
    delBtn:SetNormalFontObject("GameFontHighlightSmall")
    delBtn:SetText("|cff888888X|r")
    delBtn:SetScript("OnClick", function()
        if item._id then
            StaticPopupDialogs["EBONBUILDS_DELETE_SESSION"] = {
                text = "Delete this session and all its logs?",
                button1 = "Yes", button2 = "No",
                OnAccept = function()
                    EbonBuilds.Session.DeleteSession(item._id)
                    selectedSessionId = nil
                    EbonBuilds.SessionHistory.RefreshSessionList()
                    EbonBuilds.SessionHistory.RefreshLogView()
                end,
                timeout = 0, whileDead = true, hideOnEscape = true,
            }
            StaticPopup_Show("EBONBUILDS_DELETE_SESSION")
        end
    end)
    item._delBtn = delBtn

    item:SetScript("OnMouseDown", function()
        if item._id then SelectSession(item._id) end
    end)

    item:Hide()
    return item
end

function EbonBuilds.SessionHistory.RefreshSessionList()
    ClearSessionItems()

    local sessions = EbonBuilds.Session.GetSessions()
    local activeSession = EbonBuilds.Session.GetActiveSession()

    local sorted = {}
    for i, s in ipairs(sessions) do
        sorted[#sorted + 1] = s
    end
    table.sort(sorted, function(a, b)
        if a == activeSession then return true end
        if b == activeSession then return false end
        return (a.startTime or 0) > (b.startTime or 0)
    end)

    if not selectedSessionId and activeSession then
        selectedSessionId = activeSession.id
    end

    local activeCard = nil
    local x = 4
    for i, s in ipairs(sorted) do
        if #sessionItems < i then
            sessionItems[i] = BuildCard(sessionChild)
        end
        local item = sessionItems[i]

        item._id        = s.id
        item._isActive  = (s.endTime == nil)
        item._startTime = s.startTime
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", sessionChild, "TOPLEFT", x, -2)
        item:SetSize(CARD_W, CARD_H)

        local isActive = (s.endTime == nil)

        if isActive then
            item:SetBackdropBorderColor(0.27, 1.0, 0.27, 1)
            item._levelLabel:SetText(("|cff44ff44[Active]|r  Level %d"):format(s.maxLevel or UnitLevel("player")))
            item._durationLabel:SetText(FormatDuration(s.startTime, nil))
            if item._delBtn then item._delBtn:Hide() end
            activeCard = item
        else
            item:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            item._levelLabel:SetText(("Level %d"):format(s.maxLevel or UnitLevel("player")))
            item._durationLabel:SetText(FormatDuration(s.startTime, s.endTime))
            if item._delBtn then item._delBtn:Show() end
        end
        item._levelLabel:SetTextColor(0.7, 0.7, 0.7, 1)

        item._soulLabel:SetText(("Soul Ashes: %s"):format(isActive and "..." or tostring(s.soulAshes)))

        if s.id == selectedSessionId then
            item:SetBackdropBorderColor(1.0, 0.84, 0.0, 1)
        end

        item:Show()
        x = x + CARD_W + CARD_GAP
    end

    sessionChild:SetWidth(math.max(x, 1))

    -- Start or stop the duration timer for the active session
    if activeCard then
        StartDurationTimer(activeCard)
    elseif durationTimer then
        durationTimer:Hide()
        activeSessionCard = nil
    end

    -- Reset scroll offset if content is smaller than viewport now
    local clipW = sessionClip:GetWidth()
    if x <= clipW then
        scrollOffset = 0
        sessionChild:SetPoint("TOPLEFT", sessionClip, "TOPLEFT", 0, -2)
    end
end

------------------------------------------------------------------------
-- Log table (full width below)
------------------------------------------------------------------------

local function ClearLogRows()
    for _, row in ipairs(logRows) do
        row:Hide()
    end
end

local function BuildLogRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(16)

    -- Timestamp
    local timeFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeFs:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -1)
    timeFs:SetWidth(48)
    row._timeFs = timeFs

    -- Action
    local actionFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    actionFs:SetPoint("LEFT", timeFs, "RIGHT", 3, 0)
    actionFs:SetWidth(58)
    row._actionFs = actionFs

    -- Echo columns (with optional action-colored border)
    row._echoFrames = {}
    row._echoNameFonts  = {}
    row._echoScoreFonts = {}
    local echoAnchor = actionFs
    for i = 1, 3 do
        local echoFrame = CreateFrame("Frame", nil, row)
        echoFrame:SetHeight(20)
        echoFrame:SetWidth(120)
        echoFrame:SetPoint("LEFT", echoAnchor, "RIGHT", 3, 0)
        echoFrame:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        echoFrame:SetBackdropBorderColor(0, 0, 0, 0)
        echoFrame:EnableMouse(true)

        -- Score label (right side, fixed, always visible)
        local scoreFont = echoFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        scoreFont:SetPoint("TOPRIGHT", echoFrame, "TOPRIGHT", -4, -2)
        scoreFont:SetPoint("BOTTOMRIGHT", echoFrame, "BOTTOMRIGHT", -4, 2)
        scoreFont:SetWidth(35)
        scoreFont:SetJustifyH("RIGHT")

        -- Name label (left side, truncated when too long)
        local nameFont = echoFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFont:SetPoint("TOPLEFT", echoFrame, "TOPLEFT", 4, -2)
        nameFont:SetPoint("RIGHT", scoreFont, "LEFT", -2, 0)
        nameFont:SetJustifyH("LEFT")

        -- Tooltip and context menu
        echoFrame:SetScript("OnEnter", function(self)
            if self._echoName then
                ShowEchoTooltip(self, self._echoName, true)
            end
        end)
        echoFrame:SetScript("OnLeave", function() HideEchoTooltip() end)
        echoFrame:SetScript("OnMouseDown", function(self, button)
            if button == "RightButton" and self._echoName then
                ShowContextMenu(self, self._echoName)
            end
        end)

        row._echoFrames[i]      = echoFrame
        row._echoNameFonts[i]   = nameFont
        row._echoScoreFonts[i]  = scoreFont
        echoAnchor = echoFrame
    end

    -- Charges
    local chargesFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chargesFs:SetPoint("LEFT", echoAnchor, "RIGHT", 6, 0)
    chargesFs:SetWidth(80)
    chargesFs:SetJustifyH("LEFT")
    row._chargesFs = chargesFs

    row:Hide()
    return row
end

function EbonBuilds.SessionHistory.RefreshLogView()
    ClearLogRows()

    if not logScroll or not logChild then return end
    logChild:SetWidth(math.max(logScroll:GetWidth() or 0, 450))

    -- Track session switch so we only reset scroll when the session changes
    local prevSessionId = logChild._sessionId
    local sessionSwitched = (selectedSessionId ~= prevSessionId)

    if not selectedSessionId then
        logChild:SetHeight(1)
        logChild._sessionId = nil
        if logBar then logBar:SetMinMaxValues(0, 0) end
        return
    end

    local sessions = EbonBuilds.Session.GetSessions()
    local session
    for _, s in ipairs(sessions) do
        if s.id == selectedSessionId then session = s; break end
    end
    if not session then
        logChild:SetHeight(1)
        logChild._sessionId = nil
        if logBar then logBar:SetMinMaxValues(0, 0) end
        return
    end

    logChild._sessionId = selectedSessionId

    -- Only reset scroll position when switching sessions
    local savedScroll = logBar and logBar:GetValue() or 0
    if sessionSwitched and logBar then
        savedScroll = 0
        logBar:SetValue(0)
    end

    local logs = session.logs or {}
    if logActionFilter or logSearchText ~= "" then
        local filtered = {}
        for _, entry in ipairs(logs) do
            local matchAction = not logActionFilter or entry.action == logActionFilter or (entry.action == "Select (Locked)" and logActionFilter == "Select")
            local matchSearch = logSearchText == ""
            if not matchSearch and entry.choices then
                for _, ch in ipairs(entry.choices) do
                    if ch.name and ch.name:lower():find(logSearchText, 1, true) then
                        matchSearch = true
                        break
                    end
                end
            end
            if matchAction and matchSearch then
                filtered[#filtered + 1] = entry
            end
        end
        logs = filtered
    end
    local ROW_H = 24

    local numLogs = #logs
    for i = 1, numLogs do
        local entry = logs[numLogs - i + 1]
        if #logRows < i then
            logRows[i] = BuildLogRow(logChild)
        end
        local row = logRows[i]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", logChild, "TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetPoint("RIGHT", logChild, "RIGHT", 0, 0)
        row:SetHeight(ROW_H)

        -- Timestamp
        row._timeFs:SetText(("|cff888888%s|r"):format(FormatTimestamp(entry.timestamp)))

        -- Action
        local ac = ACTION_COLORS[entry.action] or { 1, 1, 1 }
        local acHex = string.format("%02x%02x%02x", math.floor(ac[1]*255), math.floor(ac[2]*255), math.floor(ac[3]*255))
        row._actionFs:SetText(("|cff%s%s|r"):format(acHex, entry.action))

        -- Echoes
        for j = 1, 3 do
            local ch = entry.choices[j]
            local echoFrame      = row._echoFrames[j]
            local nameFont       = row._echoNameFonts[j]
            local scoreFont      = row._echoScoreFonts[j]

            if ch then
                local hex = QUALITY_HEX[ch.quality] or "ffffff"
                nameFont:SetText(("|cff%s%s|r"):format(hex, ch.name))
                scoreFont:SetText(("|cff%s(%.0f)|r"):format(hex, ch.score))

                echoFrame._echoName  = ch.name
                echoFrame._echoScore = ch.score

                if j == entry.targetIndex then
                    echoFrame:SetBackdropBorderColor(ac[1], ac[2], ac[3], 1)
                else
                    echoFrame:SetBackdropBorderColor(0, 0, 0, 0)
                end
                echoFrame:Show()
            else
                nameFont:SetText("")
                scoreFont:SetText("")
                echoFrame._echoName  = nil
                echoFrame._echoScore = nil
                echoFrame:SetBackdropBorderColor(0, 0, 0, 0)
                echoFrame:Show()
            end
        end

        -- Charges
        local ch = entry.charges or {}
        row._chargesFs:SetText(("|cff888888B:%d R:%d F:%d|r"):format(
            ch.ban or 0, ch.reroll or 0, ch.freeze or 0))

        row:Show()
    end

    local totalH = math.max(#logs * ROW_H + 4, logScroll:GetHeight())
    logChild:SetHeight(totalH)
    if logBar then
        local mx = math.max(0, totalH - logScroll:GetHeight())
        logBar:SetMinMaxValues(0, mx)
        -- Restore scroll position after content refresh (clamp to new max)
        if not sessionSwitched then
            logBar:SetValue(math.min(savedScroll, mx))
        end
    end
end

------------------------------------------------------------------------
-- Export dialog
------------------------------------------------------------------------

local exportDialog

local function BuildExportDialog()
    local f = CreateFrame("Frame", "EbonBuildsExportDialog", UIParent)
    f:SetSize(800, 550)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self:StartMoving() end
    end)
    f:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
    f:SetScript("OnHide", function(self) self:StopMovingOrSizing() end)
    f:Hide()

    -- Title
    EbonBuilds.UIHelpers.CreateTitleBar(f, "Session Export")

    -- Close button
    EbonBuilds.UIHelpers.CreateCloseButton(f)

    -- ScrollFrame wrapping an EditBox
    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -8)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 10)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetTextInsets(6, 6, 4, 4)
    editBox:SetAutoFocus(false)
    scroll:SetScrollChild(editBox)

    local bar = CreateFrame("Slider", nil, scroll, "UIPanelScrollBarTemplate")
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", -2, -4)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", -2, 4)

    EbonBuilds.UIHelpers.WireScroller(scroll, bar, 18, function(value)
        editBox:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, value)
    end)

    f._editBox = editBox
    f._scroll  = scroll
    f._bar     = bar

    return f
end

function EbonBuilds.SessionHistory.ExportSession()
    if not exportDialog then
        exportDialog = BuildExportDialog()
    end

    local session
    if selectedSessionId then
        for _, s in ipairs(EbonBuilds.Session.GetSessions()) do
            if s.id == selectedSessionId then session = s; break end
        end
    end

    if not session then
        exportDialog._editBox:SetText("No session selected.")
        exportDialog._editBox:SetWidth(exportDialog._scroll:GetWidth() - 12)
        exportDialog._editBox:SetHeight(40)
    else
        local lines = {}
        lines[#lines + 1] = string.format("Session: Level %d | Duration: %s | Soul Ashes: %s",
            session.maxLevel or UnitLevel("player"),
            FormatDuration(session.startTime, session.endTime),
            session.soulAshes or 0)
        lines[#lines + 1] = ""

        local logs = session.logs or {}
        for _, entry in ipairs(logs) do
            local parts = {}
            parts[#parts + 1] = FormatTimestamp(entry.timestamp)
            parts[#parts + 1] = string.format("%-16s", entry.action)

            for j, ch in ipairs(entry.choices) do
                local text = string.format("%s (%.0f)", ch.name, ch.score)
                if j == entry.targetIndex then
                    text = ">>" .. text .. "<<"
                end
                parts[#parts + 1] = string.format("%-34s", text)
            end

            local ch = entry.charges or {}
            parts[#parts + 1] = string.format("B:%d  R:%d  F:%d",
                ch.ban or 0, ch.reroll or 0, ch.freeze or 0)

            lines[#lines + 1] = table.concat(parts, "")
        end

        local text = table.concat(lines, "\n")
        exportDialog._editBox:SetText(text)

        local editW = exportDialog._scroll:GetWidth() - 12
        exportDialog._editBox:SetWidth(editW)
        -- Estimate height: ~14px per line + padding
        local lineCount = #lines + 1
        local estH = math.max(lineCount * 14 + 12, exportDialog._scroll:GetHeight())
        exportDialog._editBox:SetHeight(estH)
        exportDialog._bar:SetMinMaxValues(0, math.max(0, estH - exportDialog._scroll:GetHeight()))
    end

    exportDialog:Show()
end

------------------------------------------------------------------------
-- Main UI construction
------------------------------------------------------------------------

local function ScrollCards(delta)
    local childW = sessionChild:GetWidth() or 0
    local clipW  = sessionClip:GetWidth() or 1
    local maxScroll = childW - clipW
    if maxScroll <= 0 then
        scrollOffset = 0
    else
        scrollOffset = math.max(0, math.min(maxScroll, scrollOffset + delta * 30))
    end
    sessionChild:SetPoint("TOPLEFT", sessionClip, "TOPLEFT", -scrollOffset, -2)
end

local function BuildUI(container)
    -- Top panel: session cards row
    topPanel = CreateFrame("Frame", nil, container)
    topPanel:SetPoint("TOPLEFT",     container, "TOPLEFT",  0, -4)
    topPanel:SetPoint("TOPRIGHT",    container, "TOPRIGHT", 0,  0)
    topPanel:SetHeight(TOP_H)

    -- Bottom panel: log table (created early so partial failures don't break Show)
    bottomPanel = CreateFrame("Frame", nil, container)
    bottomPanel:SetPoint("TOPLEFT",     topPanel, "BOTTOMLEFT", 0, -6)
    bottomPanel:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 4)

    local topHeader = topPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    topHeader:SetPoint("TOPLEFT", topPanel, "TOPLEFT", 4, -2)
    topHeader:SetText("|cff888888Click a session to view its logs|r")

    -- Export button
    local exportBtn = CreateFrame("Button", nil, topPanel)
    exportBtn:SetSize(60, 18)
    exportBtn:SetPoint("TOPRIGHT", topPanel, "TOPRIGHT", -110, -2)
    exportBtn:SetNormalFontObject("GameFontHighlightSmall")
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function()
        EbonBuilds.SessionHistory.ExportSession()
    end)

    -- Clear All button (right side)
    local clearBtn = CreateFrame("Button", nil, topPanel)
    clearBtn:SetSize(100, 18)
    clearBtn:SetPoint("TOPRIGHT", topPanel, "TOPRIGHT", -4, -2)
    clearBtn:SetNormalFontObject("GameFontHighlightSmall")
    clearBtn:SetText("Clear All")
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("EBONBUILDS_CLEAR_SESSIONS")
    end)

    -- Horizontal scroll buttons for session cards
    local scrollLeft = CreateFrame("Button", nil, topPanel)
    scrollLeft:SetSize(16, CARD_H)
    scrollLeft:SetPoint("BOTTOMLEFT", topPanel, "BOTTOMLEFT", 2, 0)
    scrollLeft:SetNormalFontObject("GameFontNormal")
    scrollLeft:SetText("|cff888888<|r")
    scrollLeft:SetScript("OnMouseDown", function() ScrollCards(-1) end)

    local scrollRight = CreateFrame("Button", nil, topPanel)
    scrollRight:SetSize(16, CARD_H)
    scrollRight:SetPoint("BOTTOMRIGHT", topPanel, "BOTTOMRIGHT", -2, 0)
    scrollRight:SetNormalFontObject("GameFontNormal")
    scrollRight:SetText("|cff888888>|r")
    scrollRight:SetScript("OnMouseDown", function() ScrollCards(1) end)

    -- ScrollFrame for session cards: clips children and supports mouse wheel
    sessionClip = CreateFrame("ScrollFrame", nil, topPanel)
    sessionClip:SetPoint("TOP",    topHeader,   "BOTTOM",   0, -4)
    sessionClip:SetPoint("BOTTOM", topPanel,    "BOTTOM",   0,  2)
    sessionClip:SetPoint("LEFT",   scrollLeft,  "RIGHT",    2,  0)
    sessionClip:SetPoint("RIGHT",  scrollRight, "LEFT",    -2,  0)
    sessionClip:EnableMouse(true)
    sessionClip:EnableMouseWheel(true)
    sessionClip:SetScript("OnMouseWheel", function(self, delta) ScrollCards(delta) end)

    sessionChild = CreateFrame("Frame", nil, sessionClip)
    sessionChild:SetPoint("TOPLEFT", sessionClip, "TOPLEFT", 0, -2)
    sessionChild:SetHeight(CARD_H)
    sessionClip:SetScrollChild(sessionChild)

    -- Filter bar + log header + log scroll inside bottomPanel

    local filterBar = CreateFrame("Frame", nil, bottomPanel)
    filterBar:SetPoint("TOPLEFT", bottomPanel, "TOPLEFT", 4, -2)
    filterBar:SetHeight(28)

    local actionFilterDD = CreateFrame("Frame", "EbonBuildsLogActionFilterDD", filterBar, "UIDropDownMenuTemplate")
    actionFilterDD:SetPoint("LEFT", filterBar, "LEFT", -8, -2)
    UIDropDownMenu_Initialize(actionFilterDD, function()
        local actions = { "All", "Banish", "Reroll", "Freeze", "Select" }
        for _, action in ipairs(actions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = action
            info.func = function()
                if action == "All" then
                    logActionFilter = nil
                    UIDropDownMenu_SetText(actionFilterDD, "All Actions")
                else
                    logActionFilter = action
                    UIDropDownMenu_SetText(actionFilterDD, action)
                end
                EbonBuilds.SessionHistory.RefreshLogView()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(actionFilterDD, 100)
    UIDropDownMenu_SetText(actionFilterDD, "All Actions")

    local logSearchEdit, logSearchContainer = EbonBuilds.UIHelpers.CreateSearchBox(filterBar, 140, 22, function(text)
        logSearchText = text
        EbonBuilds.SessionHistory.RefreshLogView()
    end)
    logSearchContainer:SetPoint("LEFT", actionFilterDD, "RIGHT", 80, 0)

    local logHeader = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    logHeader:SetPoint("TOPLEFT", bottomPanel, "TOPLEFT", 4, -32)
    logHeader:SetText("|cff888888Time       Action         Echo 1                Echo 2                Echo 3                Charges|r")

    logScroll = CreateFrame("ScrollFrame", nil, bottomPanel)
    logScroll:SetPoint("TOPLEFT",     logHeader, "BOTTOMLEFT", 0, -4)
    logScroll:SetPoint("BOTTOMRIGHT", bottomPanel, "BOTTOMRIGHT", -2, 2)

    logChild = CreateFrame("Frame", nil, logScroll)
    logScroll:SetScrollChild(logChild)

    logBar = CreateFrame("Slider", nil, logScroll, "UIPanelScrollBarTemplate")
    logBar:SetPoint("TOPLEFT",    logScroll, "TOPRIGHT",    -2, -4)
    logBar:SetPoint("BOTTOMLEFT", logScroll, "BOTTOMRIGHT", -2,  4)

    EbonBuilds.UIHelpers.WireScroller(logScroll, logBar, 20, logChild)
end

------------------------------------------------------------------------
-- Public interface
------------------------------------------------------------------------

function EbonBuilds.SessionHistory.Show(container)
    if not topPanel then
        BuildUI(container)
        -- Defer data refresh by one frame so parents resolve their sizes first.
        -- Without this, the initial render after /reload may produce hidden rows.
        local defer = CreateFrame("Frame")
        defer:SetScript("OnUpdate", function(self)
            self:Hide()
            logChild:SetWidth(math.max(logScroll:GetWidth() or 0, 450))
            EbonBuilds.SessionHistory.RefreshSessionList()
            EbonBuilds.SessionHistory.RefreshLogView()
        end)
        return
    end

    topPanel:SetParent(container)
    bottomPanel:SetParent(container)
    topPanel:Show()
    bottomPanel:Show()

    logChild:SetWidth(math.max(logScroll:GetWidth() or 0, 450))
    EbonBuilds.SessionHistory.RefreshSessionList()
    EbonBuilds.SessionHistory.RefreshLogView()

    -- Periodic refresh while visible so new automation actions appear live
    if not logRefreshTimer then
        logRefreshTimer = CreateFrame("Frame")
        logRefreshTimer._elapsed = 0
        logRefreshTimer:SetScript("OnUpdate", function(self, dt)
            self._elapsed = self._elapsed + dt
            if self._elapsed < 2 then return end
            self._elapsed = 0
            EbonBuilds.SessionHistory.RefreshSessionList()
            EbonBuilds.SessionHistory.RefreshLogView()
        end)
    end
    logRefreshTimer._elapsed = 0
    logRefreshTimer:Show()
end

function EbonBuilds.SessionHistory.Hide()
    if topPanel    then topPanel:Hide()    end
    if bottomPanel then bottomPanel:Hide() end
    if exportDialog then exportDialog:Hide() end
    if echoContextMenu then echoContextMenu:Hide() end
    if durationTimer then
        durationTimer:Hide()
        activeSessionCard = nil
    end
    if logRefreshTimer then
        logRefreshTimer:Hide()
    end
    HideEchoTooltip()
end

EbonBuilds.SessionHistory.ShowEchoTooltip    = ShowEchoTooltip
EbonBuilds.SessionHistory.HideEchoTooltip    = HideEchoTooltip
EbonBuilds.SessionHistory.ShowContextMenu    = ShowContextMenu

function EbonBuilds.SessionHistory.Init()
    StaticPopupDialogs["EBONBUILDS_CLEAR_SESSIONS"] = {
        text = "Delete all session history? This cannot be undone.",
        button1 = "Yes", button2 = "No",
        OnAccept = function()
            EbonBuilds.Session.ClearAllSessions()
            selectedSessionId = nil
            EbonBuilds.SessionHistory.RefreshSessionList()
            EbonBuilds.SessionHistory.RefreshLogView()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    StaticPopupDialogs["EBONBUILDS_SET_WEIGHT"] = {
        text = "Set echo weight:",
        button1 = "Set", button2 = "Cancel",
        hasEditBox = 1,
        editBoxWidth = 200,
        OnShow = function(self)
            local echoName = EbonBuilds._pendingWeightEcho
            local current = echoName and EbonBuilds.Weights.Get(echoName) or 0
            self.editBox:SetText(tostring(current))
            self.editBox:SetFocus()
            self.editBox:HighlightText()
        end,
        OnAccept = function(self)
            local echoName = EbonBuilds._pendingWeightEcho
            if not echoName then return end
            local val = tonumber(self.editBox:GetText())
            if val then
                EbonBuilds.Weights.Set(echoName, math.floor(val))
            end
            EbonBuilds._pendingWeightEcho = nil
        end,
        OnCancel = function(self)
            EbonBuilds._pendingWeightEcho = nil
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
        preferredIndex = 3,
    }
end
