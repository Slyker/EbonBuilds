-- EbonBuilds: modules/data/Constants.lua
-- Shared constants used across multiple modules.

EbonBuilds.Constants = {}

EbonBuilds.Constants.QUALITY_COLORS = {
    [0] = { 1.0, 1.0, 1.0 },
    [1] = { 30/255, 1.0, 0.0 },
    [2] = { 0.0, 112/255, 221/255 },
    [3] = { 163/255, 53/255, 238/255 },
    [4] = { 1.0, 128/255, 0.0 },
}

EbonBuilds.Constants.QUALITY_HEX = {
    [0] = "ffffff",
    [1] = "19ff19",
    [2] = "0066ff",
    [3] = "cc66ff",
    [4] = "ff8000",
}

EbonBuilds.Constants.QUALITY_LABELS = {
    [0] = "Common",
    [1] = "Uncommon",
    [2] = "Rare",
    [3] = "Epic",
    [4] = "Legendary",
}

EbonBuilds.Constants.CLASS_COLORS = {
    WARRIOR     = { 0.78, 0.61, 0.43 },
    PALADIN     = { 0.96, 0.55, 0.73 },
    HUNTER      = { 0.67, 0.83, 0.45 },
    ROGUE       = { 1.0,  0.96, 0.41 },
    PRIEST      = { 1.0,  1.0,  1.0  },
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    SHAMAN      = { 0.0,  0.44, 0.87 },
    MAGE        = { 0.41, 0.8,  0.94 },
    WARLOCK     = { 0.58, 0.51, 0.79 },
    DRUID       = { 1.0,  0.49, 0.04 },
}

EbonBuilds.Constants.CLASS_BITS = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16,
    DEATHKNIGHT = 32, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024,
}

EbonBuilds.Constants.FAMILY_MAP = {
    Tank = "Tank", Survivability = "Survivability", Healer = "Healer",
    Caster = "Caster", ["Caster DPS"] = "Caster",
    Melee  = "Melee",  ["Melee DPS"]  = "Melee",
    Ranged = "Ranged", ["Ranged DPS"] = "Ranged",
    None   = "No family",
}

EbonBuilds.Constants.QUALITY_BORDER_COLORS = EbonBuilds.Constants.QUALITY_COLORS

function EbonBuilds.Constants.NormFamily(f)
    return EbonBuilds.Constants.FAMILY_MAP[f]
end
