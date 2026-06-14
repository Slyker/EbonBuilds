-- EbonBuilds: modules/weights/Weights.lua
-- Responsibility: read/write echo weights stored on the active build.

EbonBuilds.Weights = {}

function EbonBuilds.Weights.Init()
    -- Storage now lives on each build; nothing to pre-allocate globally.
end

-- Returns the weight for the named echo on the current build, or 0.
function EbonBuilds.Weights.Get(echoName)
    local weights = EbonBuilds.Build.GetCurrentWeights()
    if not weights then return 0 end
    return weights[echoName] or 0
end

-- Persists a weight value. value must be an integer; invalid input is ignored.
-- No-op if there is no current build.
function EbonBuilds.Weights.Set(echoName, value)
    if type(value) ~= "number" then return end
    local intVal = math.floor(value)
    local weights = EbonBuilds.Build.GetCurrentWeights()
    if not weights then return end
    weights[echoName] = intVal
end
