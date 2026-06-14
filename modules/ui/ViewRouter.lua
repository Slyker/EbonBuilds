-- EbonBuilds: modules/ui/ViewRouter.lua
-- Responsibility: register named views and swap which one fills the right panel.
-- A view is a table with Show(container, context) and Hide() methods.

EbonBuilds.ViewRouter = {}

local views       = {}
local currentName = nil
local container   = nil

function EbonBuilds.ViewRouter.SetContainer(frame)
    container = frame
end

function EbonBuilds.ViewRouter.Register(name, view)
    views[name] = view
end

function EbonBuilds.ViewRouter.Show(name, context)
    if not container then return end
    local view = views[name]
    if not view then return end

    if currentName and currentName ~= name then
        local prev = views[currentName]
        if prev and prev.Hide then prev.Hide() end
    end
    currentName = name
    view.Show(container, context)
end

function EbonBuilds.ViewRouter.Current()
    return currentName
end

function EbonBuilds.ViewRouter.ShowActiveOrWelcome()
    local active = EbonBuilds.Build.GetActive()
    if active then
        EbonBuilds.ViewRouter.Show("buildOverview", { build = active })
    else
        EbonBuilds.ViewRouter.Show("welcome")
    end
end
