-- EbonBuilds: modules/ui/BuildWizard.lua
-- Responsibility: simple new-build prompt. Asks for a name, creates
-- the build with the player's current class/spec, then opens the editor.

EbonBuilds.BuildWizard = {}

local viewFrame, editBox, nameInput

------------------------------------------------------------------------
-- Create build from name
------------------------------------------------------------------------

local function CreateBuild(name)
    if not name or name == "" then name = "New Build" end

    local b = EbonBuilds.Build.Create({
        title    = name,
        class    = EbonBuilds.Build.PlayerClassToken(),
        spec     = EbonBuilds.Build.PlayerTopTalentTab(),
        comments = "",
        lockedEchoes = { nil, nil, nil, nil, nil },
        settings = EbonBuilds.Build.DefaultSettings(),
        isPublic = false,
    })
    EbonBuilds.Build.SetActive(b.id)

    if EbonBuilds.BuildList and EbonBuilds.BuildList.Refresh then
        EbonBuilds.BuildList.Refresh()
    end
    EbonBuilds.ViewRouter.Show("buildOverview", { build = b })
end

------------------------------------------------------------------------
-- View interface
------------------------------------------------------------------------

local view = {}

function view.Show(container, context)
    viewFrame:SetParent(container)
    viewFrame:ClearAllPoints()
    viewFrame:SetAllPoints(container)
    editBox:SetText("")
    viewFrame:Show()
    editBox:SetFocus()
end

function view.Hide()
    if viewFrame then viewFrame:Hide() end
end

------------------------------------------------------------------------
-- Build view frame
------------------------------------------------------------------------

local function BuildViewFrame()
    local f = CreateFrame("Frame", nil, UIParent)

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(64)
    icon:SetHeight(64)
    icon:SetPoint("TOP", f, "TOP", 0, -60)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", icon, "BOTTOM", 0, -12)
    title:SetText("New Build")

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -8)
    sub:SetText("Enter a name for your build:")

    local inputBg = CreateFrame("Frame", nil, f)
    inputBg:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", -4, -12)
    inputBg:SetPoint("TOPRIGHT", sub, "BOTTOMRIGHT", 4, -12)
    inputBg:SetHeight(26)
    inputBg:SetBackdrop(EbonBuilds.UIHelpers.TOOLTIP_BD)
    inputBg:SetBackdropColor(0, 0, 0, 0.6)
    inputBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    editBox = CreateFrame("EditBox", nil, inputBg)
    editBox:SetPoint("TOPLEFT", inputBg, "TOPLEFT", 6, 0)
    editBox:SetPoint("BOTTOMRIGHT", inputBg, "BOTTOMRIGHT", -6, 0)
    editBox:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    editBox:SetTextColor(1, 1, 1, 1)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(40)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEnterPressed", function()
        CreateBuild(editBox:GetText())
    end)

    local createBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    createBtn:SetSize(120, 28)
    createBtn:SetPoint("TOP", inputBg, "BOTTOM", 0, -16)
    createBtn:SetText("Create Build")
    createBtn:SetScript("OnClick", function()
        CreateBuild(editBox:GetText())
    end)

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(120, 28)
    cancelBtn:SetPoint("TOP", createBtn, "BOTTOM", 0, -6)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function()
        EbonBuilds.ViewRouter.ShowActiveOrWelcome()
    end)

    f:Hide()
    return f
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------

function EbonBuilds.BuildWizard.Init()
    viewFrame = BuildViewFrame()
    EbonBuilds.ViewRouter.Register("buildWizard", view)
end
