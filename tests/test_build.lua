-- tests/test_build.lua
-- Tests for Build: DefaultSettings, EnsureSettings, CloneSettings, Checksum,
-- NewObjectId, NewObject.

TestBuild = {}

function TestBuild.testDefaultSettingsStructure()
    local s = EbonBuilds.Build.DefaultSettings()
    assertNotNil(s)
    assertNotNil(s.qualityBonus)
    assertNotNil(s.qualityBonusMode)
    assertNotNil(s.familyBonus)
    assertNotNil(s.familyBonusMode)
    assertNotNil(s.banishFamilyWhitelist)
    assertNotNil(s.echoBanList)
end

function TestBuild.testDefaultSettingsQualityRange()
    local s = EbonBuilds.Build.DefaultSettings()
    for q = 0, 4 do
        assertEquals(s.qualityBonus[q], 0)
        assertEquals(s.qualityBonusMode[q], false)
    end
end

function TestBuild.testDefaultSettingsFamilyKeys()
    local s = EbonBuilds.Build.DefaultSettings()
    local families = { "Tank", "Survivability", "Healer", "Caster", "Melee", "Ranged", "No family" }
    for _, f in ipairs(families) do
        assertEquals(s.familyBonus[f], 0)
        assertEquals(s.familyBonusMode[f], false)
    end
end

function TestBuild.testDefaultSettingsThresholds()
    local s = EbonBuilds.Build.DefaultSettings()
    assertEquals(s.autoBanishPct, 20)
    assertEquals(s.autoRerollPct, 120)
    assertEquals(s.rerollGuardPct, 90)
    assertEquals(s.autoFreezePct, 80)
    assertEquals(s.freezePenaltyPct, 10)
end

function TestBuild.testEnsureSettingsFillsMissingKeys()
    local build = { settings = { autoBanishPct = 50 } }
    EbonBuilds.Build.EnsureSettings(build)
    assertEquals(build.settings.autoBanishPct, 50)
    assertNotNil(build.settings.qualityBonus)
    assertEquals(build.settings.qualityBonus[2], 0)
end

function TestBuild.testEnsureSettingsFillsMissingNested()
    local build = { settings = { qualityBonus = { [0] = 10 } } }
    EbonBuilds.Build.EnsureSettings(build)
    assertEquals(build.settings.qualityBonus[0], 10)
    assertEquals(build.settings.qualityBonus[1], 0)  -- filled by default
    assertNotNil(build.settings.familyBonus)
end

function TestBuild.testCloneSettingsDeep()
    local original = { a = 1, b = { c = 2, d = { 3 } } }
    local copy = EbonBuilds.Build.CloneSettings(original)
    assertEquals(copy.a, 1)
    assertEquals(copy.b.c, 2)
    assertEquals(copy.b.d[1], 3)
    copy.b.c = 99
    assertEquals(original.b.c, 2)
end

function TestBuild.testCloneSettingsLeavesOriginalUnchanged()
    local s = EbonBuilds.Build.DefaultSettings()
    local clone = EbonBuilds.Build.CloneSettings(s)
    assertEquals(clone.autoBanishPct, s.autoBanishPct)
    clone.autoBanishPct = 99
    assertNotEquals(clone.autoBanishPct, s.autoBanishPct)
end

function TestBuild.testNewObjectIdFormat()
    local id = EbonBuilds.Build.NewObjectId()
    assertNotNil(id)
    assertEquals(#id, 24)
    assertStrMatches(id, "^%x+$")  -- hex characters only
end

function TestBuild.testNewObjectIdUniqueness()
    local seen = {}
    for _ = 1, 100 do
        local id = EbonBuilds.Build.NewObjectId()
        assertNil(seen[id], "Duplicate ObjectId: " .. id)
        seen[id] = true
    end
end

function TestBuild.testNewObjectDefaults()
    local build = EbonBuilds.Build.NewObject({ title = "Test" })
    assertEquals(build.title, "Test")
    assertNotNil(build.id)
    assertEquals(#build.id, 24)
    assertNotNil(build.settings)
    assertNil(build.stats)
    assertEquals(build.automationEnabled, true)
    assertEquals(build.version, 1)
end

function TestBuild.testChecksum()
    local build1 = EbonBuilds.Build.NewObject({ title = "Test Build", class = "WARRIOR", spec = 1 })
    local build2 = EbonBuilds.Build.NewObject({ title = "Test Build", class = "WARRIOR", spec = 1 })
    assertEquals(EbonBuilds.Build.Checksum(build1), EbonBuilds.Build.Checksum(build2))
end

function TestBuild.testChecksumDiffersOnTitleChange()
    local build = EbonBuilds.Build.NewObject({ title = "Test A" })
    local cs1 = EbonBuilds.Build.Checksum(build)
    build.title = "Test B"
    local cs2 = EbonBuilds.Build.Checksum(build)
    assertNotEquals(cs1, cs2)
end

function TestBuild.testChecksumDiffersOnClassChange()
    local build = EbonBuilds.Build.NewObject({ class = "WARRIOR" })
    local cs1 = EbonBuilds.Build.Checksum(build)
    build.class = "MAGE"
    local cs2 = EbonBuilds.Build.Checksum(build)
    assertNotEquals(cs1, cs2)
end

function TestBuild.testChecksumIndependentOfId()
    local build1 = EbonBuilds.Build.NewObject({ title = "Test" })
    local build2 = EbonBuilds.Build.NewObject({ title = "Test" })
    assertEquals(EbonBuilds.Build.Checksum(build1), EbonBuilds.Build.Checksum(build2))
end

------------------------------------------------------------------------
-- CRUD operations
------------------------------------------------------------------------

TestBuildCRUD = {}

function TestBuildCRUD.setUp()
    EbonBuildsDB.builds = {}
    EbonBuildsCharDB.activeBuildId = nil
end

function TestBuildCRUD.tearDown()
    EbonBuildsDB.builds = {}
    EbonBuildsCharDB.activeBuildId = nil
end

function TestBuildCRUD.testListEmpty()
    local list = EbonBuilds.Build.List()
    assertEquals(#list, 0)
end

function TestBuildCRUD.testCreateAndList()
    local build = EbonBuilds.Build.Create({ title = "My Build", class = "WARRIOR" })
    assertNotNil(build)
    assertNotNil(build.id)
    assertEquals(build.title, "My Build")
    local list = EbonBuilds.Build.List()
    assertEquals(#list, 1)
    assertEquals(list[1].title, "My Build")
end

function TestBuildCRUD.testGet()
    local build = EbonBuilds.Build.Create({ title = "Test Get" })
    local got = EbonBuilds.Build.Get(build.id)
    assertNotNil(got)
    assertEquals(got.title, "Test Get")
end

function TestBuildCRUD.testGetNilId()
    assertNil(EbonBuilds.Build.Get(nil))
end

function TestBuildCRUD.testSetActiveAndGetActive()
    local build = EbonBuilds.Build.Create({ title = "Active Test" })
    EbonBuilds.Build.SetActive(build.id)
    local active = EbonBuilds.Build.GetActive()
    assertNotNil(active)
    assertEquals(active.id, build.id)
end

function TestBuildCRUD.testDelete()
    local build = EbonBuilds.Build.Create({ title = "Delete Me" })
    EbonBuilds.Build.Delete(build.id)
    assertNil(EbonBuilds.Build.Get(build.id))
    assertNil(EbonBuilds.Build.GetActive())
end

function TestBuildCRUD.testDeleteActiveClearsActive()
    local build = EbonBuilds.Build.Create({ title = "Delete Active" })
    EbonBuilds.Build.SetActive(build.id)
    EbonBuilds.Build.Delete(build.id)
    assertNil(EbonBuildsCharDB.activeBuildId)
end

function TestBuildCRUD.testListSortsByTitle()
    EbonBuilds.Build.Create({ title = "Charlie" })
    EbonBuilds.Build.Create({ title = "Alpha" })
    EbonBuilds.Build.Create({ title = "Bravo" })
    local list = EbonBuilds.Build.List()
    assertEquals(#list, 3)
    assertEquals(list[1].title, "Alpha")
    assertEquals(list[2].title, "Bravo")
    assertEquals(list[3].title, "Charlie")
end

function TestBuildCRUD.testSaveUpdatesFields()
    local build = EbonBuilds.Build.Create({ title = "Original" })
    local id = build.id
    EbonBuilds.Build.Save(id, { title = "Updated", comments = "new comment" })
    local updated = EbonBuilds.Build.Get(id)
    assertEquals(updated.title, "Updated")
    assertEquals(updated.comments, "new comment")
end

function TestBuildCRUD.testSavePreservesUnchangedFields()
    local build = EbonBuilds.Build.Create({ title = "Preserve", class = "MAGE", spec = 2 })
    local id = build.id
    EbonBuilds.Build.Save(id, { title = "New Title" })
    local updated = EbonBuilds.Build.Get(id)
    assertEquals(updated.title, "New Title")
    assertEquals(updated.class, "MAGE")
    assertEquals(updated.spec, 2)
end

function TestBuildCRUD.testGetActiveWeights()
    local build = EbonBuilds.Build.Create({ title = "Weights Test" })
    EbonBuilds.Build.SetActive(build.id)
    local weights = EbonBuilds.Build.GetActiveWeights()
    assertNotNil(weights)
    weights["Fireball"] = 100
    assertEquals(build.echoWeights["Fireball"], 100)
end

function TestBuildCRUD.testGetActiveWeightsEditingMode()
    local build = EbonBuilds.Build.Create({ title = "Editing Test" })
    EbonBuilds.Build.SetActive(build.id)
    EbonBuildsDB._isEditingBuild = true
    local weights = EbonBuilds.Build.GetActiveWeights()
    assertNotNil(weights)
    weights["Test"] = 50
    assertEquals(EbonBuildsDB.pendingWeights["Test"], 50)
    EbonBuildsDB._isEditingBuild = false
end

function TestBuildCRUD.testOnActiveChangedCallback()
    local called = false
    EbonBuilds.Build.OnActiveChanged(function() called = true end)
    local build = EbonBuilds.Build.Create({ title = "Callback Test" })
    EbonBuilds.Build.SetActive(build.id)
    assertTrue(called)
end

function TestBuildCRUD.testUpdateFromPublic()
    local localBuild = EbonBuilds.Build.NewObject({ title = "Local", class = "WARRIOR" })
    local publicBuild = EbonBuilds.Build.NewObject({
        title = "Public",
        class = "MAGE",
        spec = 3,
        echoWeights = { ["Fireball"] = 100 },
        settings = EbonBuilds.Build.DefaultSettings(),
    })
    EbonBuilds.Build.UpdateFromPublic(localBuild, publicBuild)
    assertEquals(localBuild.title, "Public")
    assertEquals(localBuild.class, "MAGE")
    assertEquals(localBuild.spec, 3)
    assertEquals(localBuild.echoWeights["Fireball"], 100)
end
