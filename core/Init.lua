-- EbonBuilds: core/Init.lua
-- Responsibility: addon bootstrap, saved-variable initialisation, module wiring.

EbonBuilds = EbonBuilds or {}

local eventFrame = CreateFrame("Frame")

local function OnAddonLoaded(addonName)
    if addonName ~= "EbonBuilds" then return end

    if not ProjectEbonhold then
        return
    end

    EbonBuildsDB = EbonBuildsDB or {
        builds        = {},
        minimapAngle  = 220,
        globalSettings = {
            evalDelay       = 2,
            toastDuration   = 3,
            automationEnabled = true,
        },
    }
    EbonBuildsDB.minimapAngle = EbonBuildsDB.minimapAngle or 220
    EbonBuildsDB.globalSettings = EbonBuildsDB.globalSettings or {}
    EbonBuildsDB.globalSettings.evalDelay       = EbonBuildsDB.globalSettings.evalDelay       or 2
    EbonBuildsDB.globalSettings.toastDuration   = EbonBuildsDB.globalSettings.toastDuration   or 3
    if EbonBuildsDB.globalSettings.automationEnabled == nil then
        EbonBuildsDB.globalSettings.automationEnabled = true
    end

    EbonBuildsDB.globalSettings.uiState = EbonBuildsDB.globalSettings.uiState or {
        windowOpen      = false,
        leftPanelOpen   = true,
        echoesQuality   = nil,
        echoesSortMode  = 1,
        echoesShowMode  = "owned",
        echoesSearch    = "",
        filtersSearch   = "",
        filtersQuality  = nil,
        filtersFamilies = {},
        filtersShowAllClasses = false,
    }

    EbonBuildsCharDB = EbonBuildsCharDB or {
        activeBuildId = nil,
    }

    EbonBuilds.Build.Migrate()
    EbonBuilds.Session.Init()
    EbonBuilds.SessionHistory.Init()
    EbonBuilds.Weights.Init()
    EbonBuilds.Toast.Init()
    EbonBuilds.WelcomeView.Init()
    EbonBuilds.BuildWizard.Init()
    EbonBuilds.MinimapButton.Init()
    EbonBuilds.MainWindow.Init()
    EbonBuilds.Automation.Init()
    EbonBuilds.Sync.Init()

    -- Dropdown close-on-outside-click: transparent catcher at the lowest
    -- frame level within FULLSCREEN_DIALOG so it intercepts clicks on
    -- everything below the open dropdown list but not the list itself.
    local dropCatcher = CreateFrame("Frame", nil, UIParent)
    dropCatcher:SetAllPoints(UIParent)
    dropCatcher:EnableMouse(true)
    dropCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
    dropCatcher:SetFrameLevel(0)
    dropCatcher:Hide()
    dropCatcher:SetScript("OnMouseDown", function()
        CloseDropDownMenus()
    end)

    hooksecurefunc("ToggleDropDownMenu", function()
        if UIDROPDOWNMENU_OPEN then
            dropCatcher:Show()
        else
            dropCatcher:Hide()
        end
    end)
    hooksecurefunc("CloseDropDownMenus", function()
        dropCatcher:Hide()
    end)
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    end
end)
