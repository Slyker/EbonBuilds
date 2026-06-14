-- EbonBuilds: modules/ui/BuildOverview/LogbookTab.lua
-- Logbook tab: thin wrapper around SessionHistory.

EbonBuilds.BuildOverview.BuildLogbookTab = function(parent)
    EbonBuilds.SessionHistory.Show(parent)
end
