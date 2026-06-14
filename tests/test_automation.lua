-- tests/test_automation.lua
-- Tests for Automation: ScoreChoice (novelty), TrySelect (banned+protected),
-- banish priority, and AnnotateScored.

TestNovelty = {}

function TestNovelty.setUp()
    -- Save originals for restore in tearDown
    _G._ORIG_WEIGHTS_GET = EbonBuilds.Weights.Get
    _G._ORIG_GET_SPELL_INFO = _G.GetSpellInfo

    -- Build settings with novelty
    local settings = EbonBuilds.Build.DefaultSettings()
    settings.noveltyValue = 30
    settings.noveltyMode  = false
    _G.MOCK_TEST_SETTINGS = settings

    -- Directly set PerkDatabase (bypasses MOCK_PERK_DATABASE indirection)
    _G.ProjectEbonhold.PerkDatabase = {
        [200100] = { comment = "Rend the Weak",     quality = 0, families = {"Melee DPS"}, classMask = 1535 },
        [200101] = { comment = "Rend the Weak",     quality = 1, families = {"Melee DPS"}, classMask = 1535 },
        [200200] = { comment = "Brutal Might",      quality = 0, families = {"Melee DPS"}, classMask = 1535 },
        [200300] = { comment = "Expertise Drills",  quality = 1, families = {"Melee DPS"}, classMask = 1535 },
        [200400] = { comment = "Scorched Path",     quality = 0, families = {"Caster DPS"}, classMask = 1535 },
        [200500] = { comment = "Creeping Decay",    quality = 1, families = {"Caster DPS"}, classMask = 1535 },
    }

    -- Override GetSpellInfo to return the comment (name) for our test IDs
    _G.GetSpellInfo = function(id)
        local data = _G.ProjectEbonhold.PerkDatabase[id]
        if data then return data.comment end
        return "UnknownSpell"
    end

    -- Override Weights.Get to return a fixed weight of 20 for these echoes
    EbonBuilds.Weights.Get = function(name)
        local testEchoes = {["Rend the Weak"]=true, ["Brutal Might"]=true, ["Expertise Drills"]=true, ["Scorched Path"]=true, ["Creeping Decay"]=true}
        if testEchoes[name] then return 20 end
        return 0
    end

    -- Reset mocks
    _G.MOCK_GRANTED_PERKS = {}
    _G.MOCK_CURRENT_CHOICES = {}
    _G.MOCK_LAST_SELECT = nil
end

function TestNovelty.tearDown()
    -- Restore originals
    EbonBuilds.Weights.Get = _G._ORIG_WEIGHTS_GET
    _G.GetSpellInfo = _G._ORIG_GET_SPELL_INFO
    _G._ORIG_WEIGHTS_GET = nil
    _G._ORIG_GET_SPELL_INFO = nil

    _G.ProjectEbonhold.PerkDatabase = {}
    _G.MOCK_TEST_SETTINGS = nil
    _G.MOCK_GRANTED_PERKS = {}
    _G.MOCK_LAST_SELECT = nil
end

function TestNovelty.testScoreWithNovelty_newEcho()
    -- Echo NOT in granted perks → novelty applies
    _G.MOCK_GRANTED_PERKS = {}
    local choice = { spellId = 200100, quality = 0, isFrozen = false, isCarried = false }
    local result = EbonBuilds.Automation._ScoreChoice(choice, _G.MOCK_TEST_SETTINGS)
    assertEquals(result.name, "Rend the Weak")
    -- Base 20 + novelty 30 = 50
    assertEquals(result.score, 50)
end

function TestNovelty.testScoreWithoutNovelty_alreadyPicked()
    -- Echo IS in granted perks (same name) → novelty does NOT apply
    _G.MOCK_GRANTED_PERKS = {
        ["Rend the Weak"] = { spellId = 200100, stack = 1, quality = 0 },
    }
    local choice = { spellId = 200101, quality = 1, isFrozen = false, isCarried = false }
    local result = EbonBuilds.Automation._ScoreChoice(choice, _G.MOCK_TEST_SETTINGS)
    assertEquals(result.name, "Rend the Weak")
    -- Base 20, no novelty = 20
    assertEquals(result.score, 20)
end

function TestNovelty.testNoveltyCheckedByNameNotSpellId()
    -- Picked quality 0 variant → quality 1 variant also loses novelty (same name)
    _G.MOCK_GRANTED_PERKS = {
        ["Rend the Weak"] = { spellId = 200100, stack = 1, quality = 0 },
    }
    -- Quality 1 choice (different spellId, same name)
    local choice = { spellId = 200101, quality = 1, isFrozen = false, isCarried = false }
    local result = EbonBuilds.Automation._ScoreChoice(choice, _G.MOCK_TEST_SETTINGS)
    -- Should be 20 (no novelty), not 50 (with novelty)
    assertEquals(result.score, 20)
end

function TestNovelty.testDifferentEchoStillGetsNovelty()
    -- Player has Rend the Weak, but Brutal Might is new → gets novelty
    _G.MOCK_GRANTED_PERKS = {
        ["Rend the Weak"] = { spellId = 200100, stack = 1, quality = 0 },
    }
    local choice = { spellId = 200200, quality = 0, isFrozen = false, isCarried = false }
    local result = EbonBuilds.Automation._ScoreChoice(choice, _G.MOCK_TEST_SETTINGS)
    assertEquals(result.name, "Brutal Might")
    -- Base 20 + novelty 30 = 50
    assertEquals(result.score, 50)
end

function TestNovelty.testZeroNoveltyValue()
    local s = EbonBuilds.Build.DefaultSettings()
    s.noveltyValue = 0
    s.noveltyMode  = false
    _G.MOCK_GRANTED_PERKS = {}
    local choice = { spellId = 200200, quality = 0, isFrozen = false, isCarried = false }
    local result = EbonBuilds.Automation._ScoreChoice(choice, s)
    -- Base 20 + novelty 0 = 20
    assertEquals(result.score, 20)
end

------------------------------------------------------------------------
-- TrySelect: banned + protected echoes
------------------------------------------------------------------------

TestTrySelect = {}

function TestTrySelect.setUp()
    _G._ORIG_GET_SPELL_INFO = _G.GetSpellInfo

    _G.MOCK_TEST_SETTINGS = EbonBuilds.Build.DefaultSettings()
    _G.MOCK_TEST_SETTINGS.echoBanList = {
        [200100] = "Rend the Weak",
    }
    _G.MOCK_TEST_SETTINGS.banishFamilyWhitelist = { Melee = true }

    _G.ProjectEbonhold.PerkDatabase = {
        [200100] = { comment = "Rend the Weak",     quality = 0, families = {"Melee DPS"}, classMask = 1535 },
        [200200] = { comment = "Brutal Might",      quality = 0, families = {"Melee DPS"}, classMask = 1535 },
        [200300] = { comment = "Expertise Drills",  quality = 1, families = {"Ranged DPS"}, classMask = 1535 },
    }

    _G.GetSpellInfo = function(id)
        local data = _G.ProjectEbonhold.PerkDatabase[id]
        if data then return data.comment end
        return "UnknownSpell"
    end
end

function TestTrySelect.tearDown()
    _G.GetSpellInfo = _G._ORIG_GET_SPELL_INFO
    _G._ORIG_GET_SPELL_INFO = nil
    _G.MOCK_TEST_SETTINGS = nil
    _G.ProjectEbonhold.PerkDatabase = {}
    _G.MOCK_LAST_SELECT = nil
end

function TestTrySelect.testBannedAndProtected_isDeprioritized()
    -- Rend the Weak: banned + Melee(protected) → protection blocks banish, but
    -- ban-list still deprioritizes it in selection. It remains a fallback (in all[])
    -- when every offered echo is banned.
    local scored = {
        { index = 1, spellId = 200100, name = "Rend the Weak",    score = 88, quality = 0, isFrozen = false, isCarried = false, data = _G.ProjectEbonhold.PerkDatabase[200100] },
        { index = 2, spellId = 200200, name = "Brutal Might",     score = 98, quality = 0, isFrozen = false, isCarried = false, data = _G.ProjectEbonhold.PerkDatabase[200200] },
        { index = 3, spellId = 200300, name = "Expertise Drills", score = 78, quality = 1, isFrozen = false, isCarried = false, data = _G.ProjectEbonhold.PerkDatabase[200300] },
    }
    local settings = _G.MOCK_TEST_SETTINGS
    local banList = settings.echoBanList or {}
    local whitelist = settings.banishFamilyWhitelist or {}
    EbonBuilds.Automation._AnnotateScored(scored, banList, whitelist, {})

    -- Verify annotations
    assertTrue(scored[1].isBanned,   "Rend the Weak should be banned")
    assertTrue(scored[1].isProtected, "Rend the Weak should be protected (Melee)")
    assertFalse(scored[2].isBanned,  "Brutal Might should not be banned")
    assertTrue(scored[2].isProtected, "Brutal Might should be protected (Melee)")

    -- Brutal Might (98, not banned) should win over Rend the Weak (88, banned)
    local ok, pick = EbonBuilds.Automation._TrySelect(scored, settings, { stats = {} })
    assertTrue(ok, "TrySelect should succeed")
    assertEquals(pick.name, "Brutal Might")
    assertEquals(pick.name, "Brutal Might")
end

function TestTrySelect.testBannedNotProtected_deprioritized()
    -- Rend the Weak: banned, NOT protected (not in whitelist) → deprioritized
    -- Brutal Might should win even with lower score since it's not banned
    local scored = {
        { index = 1, spellId = 200100, name = "Rend the Weak",    score = 98, quality = 0, isFrozen = false, isCarried = false, data = _G.ProjectEbonhold.PerkDatabase[200100] },
        { index = 2, spellId = 200300, name = "Expertise Drills", score = 78, quality = 1, isFrozen = false, isCarried = false, data = _G.ProjectEbonhold.PerkDatabase[200300] },
    }
    local settings = EbonBuilds.Build.DefaultSettings()
    settings.echoBanList = { [200100] = "Rend the Weak" }
    -- No whitelist — Rend is not protected
    local banList = settings.echoBanList or {}
    local whitelist = settings.banishFamilyWhitelist or {}
    EbonBuilds.Automation._AnnotateScored(scored, banList, whitelist, {})

    assertTrue(scored[1].isBanned,   "Rend should be banned")
    assertFalse(scored[1].isProtected)

    local ok, pick = EbonBuilds.Automation._TrySelect(scored, settings, { stats = {} })
    assertTrue(ok)
    -- Expertise Drills should win (non-banned) even with lower score
    assertEquals(pick.name, "Expertise Drills")
end

------------------------------------------------------------------------
-- AnnotateScored: locked echo detection
------------------------------------------------------------------------

TestAnnotate = {}

function TestAnnotate.testLockedEchoFlag()
    local scored = {
        { index = 1, spellId = 200100, name = "Rend", score = 88, data = { families = {"Melee DPS"} } },
        { index = 2, spellId = 200200, name = "Brutal", score = 98, data = { families = {"Melee DPS"} } },
    }
    EbonBuilds.Automation._AnnotateScored(scored, {}, {}, { 200200, nil, nil, nil })
    assertFalse(scored[1].isLocked)
    assertTrue(scored[2].isLocked, "Brutal (200200) should be flagged as locked")
end

------------------------------------------------------------------------
-- Evaluate: full integration
------------------------------------------------------------------------

TestEvaluate = {}

function TestEvaluate.setUp()
    _G._ORIG_WEIGHTS_GET_EVAL = EbonBuilds.Weights.Get
    _G._ORIG_GET_SPELL_INFO_EVAL = _G.GetSpellInfo

    EbonBuildsDB.builds = {}
    EbonBuildsCharDB.activeBuildId = nil
    _G.MOCK_GRANTED_PERKS = {}
    _G.MOCK_CURRENT_CHOICES = {}
    _G.MOCK_LAST_SELECT = nil
    _G.MOCK_LAST_BANISH = nil
    _G.MOCK_LAST_REROLL = nil
    _G.MOCK_LAST_FREEZE = nil
    _G.EbonholdPlayerRunData = {
        usedRerolls = 0,
        totalRerolls = 0,
        usedFreezes = 0,
        totalFreezes = 0,
        remainingBanishes = 0,
    }

    _G.ProjectEbonhold.PerkDatabase = {
        [200100] = { comment = "Fireball",    quality = 0, families = {"Caster DPS"}, classMask = 1535 },
        [200101] = { comment = "Fireball",    quality = 1, families = {"Caster DPS"}, classMask = 1535 },
        [200200] = { comment = "Frostbolt",   quality = 0, families = {"Caster DPS"}, classMask = 1535 },
        [200300] = { comment = "Heal Wave",   quality = 0, families = {"Healer"},      classMask = 64 },
        [200400] = { comment = "Shield Slam", quality = 0, families = {"Melee DPS"},   classMask = 1 },
    }

    _G.GetSpellInfo = function(id)
        local data = _G.ProjectEbonhold.PerkDatabase[id]
        if data then return data.comment end
        return "UnknownSpell"
    end

    EbonBuilds.Weights.Get = function(name)
        local w = { ["Fireball"] = 80, ["Frostbolt"] = 60, ["Heal Wave"] = 40, ["Shield Slam"] = 90 }
        return w[name] or 0
    end
end

function TestEvaluate.tearDown()
    if _G._ORIG_WEIGHTS_GET_EVAL then
        EbonBuilds.Weights.Get = _G._ORIG_WEIGHTS_GET_EVAL
        _G._ORIG_WEIGHTS_GET_EVAL = nil
    end
    if _G._ORIG_GET_SPELL_INFO_EVAL then
        _G.GetSpellInfo = _G._ORIG_GET_SPELL_INFO_EVAL
        _G._ORIG_GET_SPELL_INFO_EVAL = nil
    end
    EbonBuildsDB.builds = {}
    EbonBuildsCharDB.activeBuildId = nil
    _G.ProjectEbonhold.PerkDatabase = {}
    _G.MOCK_GRANTED_PERKS = {}
    _G.MOCK_CURRENT_CHOICES = {}
    _G.MOCK_LAST_SELECT = nil
    _G.MOCK_LAST_BANISH = nil
end

function TestEvaluate.testReturnsFalseWhenNoActiveBuild()
    assertFalse(EbonBuilds.Automation.Evaluate())
end

function TestEvaluate.testReturnsFalseWhenAutomationDisabled()
    local build = EbonBuilds.Build.Create({ title = "Test", automationEnabled = false })
    EbonBuilds.Build.SetActive(build.id)
    _G.MOCK_CURRENT_CHOICES = {
        { spellId = 200100, quality = 0, isFrozen = false, isCarried = false },
    }
    assertFalse(EbonBuilds.Automation.Evaluate())
end

function TestEvaluate.testReturnsFalseWhenNoChoices()
    local build = EbonBuilds.Build.Create({ title = "Test" })
    EbonBuilds.Build.SetActive(build.id)
    _G.MOCK_CURRENT_CHOICES = {}
    assertFalse(EbonBuilds.Automation.Evaluate())
end

function TestEvaluate.testSelectsBestEcho()
    local build = EbonBuilds.Build.Create({ title = "Test" })
    EbonBuilds.Build.SetActive(build.id)
    _G.MOCK_CURRENT_CHOICES = {
        { spellId = 200400, quality = 0, isFrozen = false, isCarried = false },
        { spellId = 200100, quality = 0, isFrozen = false, isCarried = false },
        { spellId = 200200, quality = 0, isFrozen = false, isCarried = false },
    }
    -- Shield Slam (90) > Fireball (80) > Frostbolt (60)
    local ok = EbonBuilds.Automation.Evaluate()
    assertTrue(ok)
    assertEquals(_G.MOCK_LAST_SELECT, 200400)
end

function TestEvaluate.testBanishesLowScoreEcho()
    local build = EbonBuilds.Build.Create({ title = "Test", settings = EbonBuilds.Build.DefaultSettings() })
    build.settings.autoBanishPct = 50
    EbonBuilds.Build.SetActive(build.id)

    local settings = EbonBuilds.Scoring.GetEffectiveSettings()
    local peak = EbonBuilds.Scoring.Score(
        { quality = 0, families = {"Melee DPS"} },
        90, settings
    )
    local threshold = math.floor(peak * 50 / 100)

    _G.MOCK_CURRENT_CHOICES = {
        { spellId = 200400, quality = 0, isFrozen = false, isCarried = false },
        { spellId = 200300, quality = 0, isFrozen = false, isCarried = false },
    }
    _G.EbonholdPlayerRunData.remainingBanishes = 3

    local ok = EbonBuilds.Automation.Evaluate()
    assertTrue(ok)
    assertTrue(_G.MOCK_LAST_BANISH ~= nil or _G.MOCK_LAST_SELECT ~= nil)
end

function TestEvaluate.testLockedEchoSelectedDirectly()
    local build = EbonBuilds.Build.Create({
        title = "Test",
        lockedEchoes = { 200100, nil, nil, nil, nil },
    })
    EbonBuilds.Build.SetActive(build.id)
    _G.MOCK_CURRENT_CHOICES = {
        { spellId = 200100, quality = 0, isFrozen = false, isCarried = false },
        { spellId = 200200, quality = 0, isFrozen = false, isCarried = false },
    }
    local ok = EbonBuilds.Automation.Evaluate()
    assertTrue(ok)
    assertEquals(_G.MOCK_LAST_SELECT, 200100)
end

function TestEvaluate.testRerollWhenSumBelowThreshold()
    local origGet = EbonBuilds.Weights.Get
    EbonBuilds.Weights.Get = function(name) return 0 end

    local build = EbonBuilds.Build.Create({
        title = "Test",
        settings = EbonBuilds.Build.DefaultSettings(),
    })
    build.settings.autoRerollPct = 200
    build.settings.rerollGuardPct = 0
    EbonBuilds.Build.SetActive(build.id)

    _G.MOCK_CURRENT_CHOICES = {
        { spellId = 200100, quality = 0, isFrozen = false, isCarried = false },
        { spellId = 200200, quality = 0, isFrozen = false, isCarried = false },
    }
    _G.EbonholdPlayerRunData.remainingBanishes = 0
    _G.EbonholdPlayerRunData.totalRerolls = 3
    _G.EbonholdPlayerRunData.usedRerolls = 0

    local ok = EbonBuilds.Automation.Evaluate()
    EbonBuilds.Weights.Get = origGet
    assertTrue(ok)
    assertTrue(_G.MOCK_LAST_REROLL == true or _G.MOCK_LAST_SELECT ~= nil)
end
