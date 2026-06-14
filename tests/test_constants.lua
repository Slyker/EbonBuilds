-- tests/test_constants.lua
-- Tests for Constants: quality colors, class bits, family map, NormFamily.

TestConstants = {}

function TestConstants.testQualityColorsRange()
    local qc = EbonBuilds.Constants.QUALITY_COLORS
    for q = 0, 4 do
        assertNotNil(qc[q])
        assertEquals(#qc[q], 3)
    end
end

function TestConstants.testQualityHexRange()
    local qh = EbonBuilds.Constants.QUALITY_HEX
    for q = 0, 4 do
        assertNotNil(qh[q])
        assertStrMatches(qh[q], "^%x+$")
    end
end

function TestConstants.testQualityLabelsRange()
    local ql = EbonBuilds.Constants.QUALITY_LABELS
    assertEquals(ql[0], "Common")
    assertEquals(ql[1], "Uncommon")
    assertEquals(ql[2], "Rare")
    assertEquals(ql[3], "Epic")
    assertEquals(ql[4], "Legendary")
end

function TestConstants.testClassBitsValues()
    local cb = EbonBuilds.Constants.CLASS_BITS
    assertEquals(cb.WARRIOR, 1)
    assertEquals(cb.PALADIN, 2)
    assertEquals(cb.HUNTER, 4)
    assertEquals(cb.ROGUE, 8)
    assertEquals(cb.PRIEST, 16)
    assertEquals(cb.DEATHKNIGHT, 32)
    assertEquals(cb.SHAMAN, 64)
    assertEquals(cb.MAGE, 128)
    assertEquals(cb.WARLOCK, 256)
    assertEquals(cb.DRUID, 1024)
end

function TestConstants.testClassBitsNoDuplicates()
    local cb = EbonBuilds.Constants.CLASS_BITS
    local seen = {}
    for _, v in pairs(cb) do
        assertNil(seen[v], "Duplicate class bit value: " .. v)
        seen[v] = true
    end
end

function TestConstants.testNormFamilyDirect()
    local NF = EbonBuilds.Constants.NormFamily
    assertEquals(NF("Tank"), "Tank")
    assertEquals(NF("Healer"), "Healer")
    assertEquals(NF("Survivability"), "Survivability")
end

function TestConstants.testNormFamilyAliases()
    local NF = EbonBuilds.Constants.NormFamily
    assertEquals(NF("Caster DPS"), "Caster")
    assertEquals(NF("Melee DPS"), "Melee")
    assertEquals(NF("Ranged DPS"), "Ranged")
    assertEquals(NF("None"), "No family")
end

function TestConstants.testNormFamilyUnknownReturnsNil()
    local NF = EbonBuilds.Constants.NormFamily
    assertNil(NF("InvalidFamily"))
    assertNil(NF(nil))
end

function TestConstants.testFamilyMapKeys()
    local fm = EbonBuilds.Constants.FAMILY_MAP
    local expected = {
        "Tank", "Survivability", "Healer", "Caster", "Caster DPS",
        "Melee", "Melee DPS", "Ranged", "Ranged DPS", "None",
    }
    for _, k in ipairs(expected) do
        assertNotNil(fm[k], "Missing key: " .. k)
    end
end

function TestConstants.testClassColorsExist()
    local cc = EbonBuilds.Constants.CLASS_COLORS
    local classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
                     "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
    for _, cls in ipairs(classes) do
        assertNotNil(cc[cls], "Missing class color: " .. cls)
        assertEquals(#cc[cls], 3)
    end
end
