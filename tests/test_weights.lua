-- tests/test_weights.lua
-- Tests for Weights: Get/Set on active build.

TestWeights = {}

function TestWeights.setUp()
    _G._ORIG_WEIGHTS_GET_TW = EbonBuilds.Weights.Get
    EbonBuilds.Weights.Get = function(echoName)
        local weights = EbonBuilds.Build.GetActiveWeights()
        if not weights then return 0 end
        return weights[echoName] or 0
    end
    EbonBuildsDB.builds = {}
    EbonBuildsDB.pendingWeights = nil
    EbonBuildsCharDB.activeBuildId = nil
end

function TestWeights.tearDown()
    EbonBuilds.Weights.Get = _G._ORIG_WEIGHTS_GET_TW
    _G._ORIG_WEIGHTS_GET_TW = nil
    EbonBuildsDB.builds = {}
    EbonBuildsCharDB.activeBuildId = nil
end

function TestWeights.testGetNoActiveBuild()
    local w = EbonBuilds.Weights.Get("Fireball")
    assertEquals(w, 0)
end

function TestWeights.testGetReturnsZeroForUnset()
    local build = EbonBuilds.Build.Create({ title = "Test" })
    EbonBuilds.Build.SetActive(build.id)
    assertEquals(EbonBuilds.Weights.Get("Fireball"), 0)
end

function TestWeights.testSetAndGet()
    local build = EbonBuilds.Build.Create({ title = "Test" })
    EbonBuilds.Build.SetActive(build.id)
    EbonBuilds.Weights.Set("Fireball", 100)
    assertEquals(EbonBuilds.Weights.Get("Fireball"), 100)
end

function TestWeights.testSetTruncatesToInteger()
    local build = EbonBuilds.Build.Create({ title = "Test" })
    EbonBuilds.Build.SetActive(build.id)
    EbonBuilds.Weights.Set("Fireball", 42.7)
    assertEquals(EbonBuilds.Weights.Get("Fireball"), 42)
end

function TestWeights.testSetNegativeValue()
    local build = EbonBuilds.Build.Create({ title = "Test" })
    EbonBuilds.Build.SetActive(build.id)
    EbonBuilds.Weights.Set("Fireball", -10)
    assertEquals(EbonBuilds.Weights.Get("Fireball"), -10)
end

function TestWeights.testSetNonNumberIgnored()
    local build = EbonBuilds.Build.Create({ title = "Test" })
    EbonBuilds.Build.SetActive(build.id)
    EbonBuilds.Weights.Set("Fireball", "bad")
    assertEquals(EbonBuilds.Weights.Get("Fireball"), 0)
end

function TestWeights.testSetNoBuildNoError()
    EbonBuilds.Weights.Set("Fireball", 100)
    -- Should not error, just no-op
end

function TestWeights.testMultipleEchoes()
    local build = EbonBuilds.Build.Create({ title = "Test" })
    EbonBuilds.Build.SetActive(build.id)
    EbonBuilds.Weights.Set("Fireball", 100)
    EbonBuilds.Weights.Set("Frostbolt", 50)
    EbonBuilds.Weights.Set("Heal", -20)
    assertEquals(EbonBuilds.Weights.Get("Fireball"), 100)
    assertEquals(EbonBuilds.Weights.Get("Frostbolt"), 50)
    assertEquals(EbonBuilds.Weights.Get("Heal"), -20)
    assertEquals(EbonBuilds.Weights.Get("Unknown"), 0)
end
