-- EbonBuilds: modules/data/IconList.lua
-- Runtime icon scanner. Discovers icon textures by scanning spell IDs
-- via OnUpdate batching so the UI never freezes.

EbonBuilds.IconList = {}

local MAX_SPELL_ID = 80000
local BATCH_SIZE = 500
local nextScanId = 1
local seen = {}

-- Hidden frame drives the scan frame by frame
local scannerFrame = CreateFrame("Frame")

local function BatchScan()
    local done = false
    for i = 1, BATCH_SIZE do
        local id = nextScanId
        nextScanId = id + 1
        if id > MAX_SPELL_ID then
            done = true
            break
        end
        local name, _, icon = GetSpellInfo(id)
        if name and icon and not seen[icon] then
            seen[icon] = true
            tinsert(EbonBuilds.IconList, icon)
        end
    end
    if done then
        scannerFrame:SetScript("OnUpdate", nil)
    end
end

scannerFrame:SetScript("OnUpdate", BatchScan)
