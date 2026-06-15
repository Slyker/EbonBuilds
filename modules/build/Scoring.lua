-- EbonBuilds: modules/build/Scoring.lua
-- Responsibility: compute echo scores and the class peak from a settings
-- table. Pure — no UI, no SavedVariables mutation.

EbonBuilds.Scoring = {}

local NormFamily = EbonBuilds.Constants.NormFamily
local QUALITY_LABELS = EbonBuilds.Constants.QUALITY_LABELS

local function ApplyModifier(score, baseWeight, value, multiplicative)
    if multiplicative then
        if value == 0 then return score end
        if baseWeight == 0 then
            return score + value
        end
        return score + baseWeight * (value - 1)
    else
        return score + value
    end
end

local function FormatModifier(base, value, multiplicative)
    if multiplicative then
        return base == 0 and "+" .. value or string.format("x%.1f", 1 + (value - 1) / math.max(base, 1))
    else
        return "+" .. value
    end
end

local function ApplyFamilyBonuses(s, base, entry, fb, fm, wl)
    local hasWhitelist = false
    for _ in pairs(wl) do hasWhitelist = true; break end

    if entry.families and #entry.families > 0 then
        for i = 1, #entry.families do
            local key = NormFamily(entry.families[i])
            if key and (not hasWhitelist or wl[key]) then
                s = ApplyModifier(s, base, fb[key] or 0, fm[key])
            end
        end
    else
        if not hasWhitelist or wl["No family"] then
            s = ApplyModifier(s, base, fb["No family"] or 0, fm["No family"])
        end
    end
    return s
end

function EbonBuilds.Scoring.ScorePerQuality(entry, weight, settings, quality)
    local qb = settings.qualityBonus or {}
    local qm = settings.qualityBonusMode or {}
    local fb = settings.familyBonus  or {}
    local fm = settings.familyBonusMode or {}
    local wl = settings.banishFamilyWhitelist or {}
    local base = weight or 0
    local s = base

    s = ApplyModifier(s, base, qb[quality] or 0, qm[quality])
    s = ApplyFamilyBonuses(s, base, entry, fb, fm, wl)
    return s
end

function EbonBuilds.Scoring.Score(entry, weight, settings)
    local s = EbonBuilds.Scoring.ScorePerQuality(entry, weight, settings, entry.quality)
    local base = weight or 0
    s = ApplyModifier(s, base, settings.noveltyValue or 0, settings.noveltyMode)
    return s
end

local function MatchesClass(entry, bitVal)
    if not bitVal then return true end
    if not entry.classMask or entry.classMask == 0 then return true end
    return bit.band(entry.classMask, bitVal) ~= 0
end

function EbonBuilds.Scoring.ComputePeak(classToken, settings)
    if not settings then return nil, 0 end
    local list = EbonBuilds.EchoTableRows.BuildSortedList()
    local bitVal = classToken and EbonBuilds.Constants.CLASS_BITS[classToken]
    local bestName, bestScore = nil, nil
    for i = 1, #list do
        local e = list[i]
        if MatchesClass(e, bitVal) then
            local w  = EbonBuilds.Weights.Get(e.name) or 0
            local sc = EbonBuilds.Scoring.Score(e, w, settings)
            if bestScore == nil or sc > bestScore then
                bestScore, bestName = sc, e.name
            end
        end
    end
    return bestName, bestScore or 0
end

function EbonBuilds.Scoring.GetEffectiveLockedEchoes()
    if EbonBuilds.BuildForm and EbonBuilds.BuildForm.GetEditingLockedEchoes then
        local p = EbonBuilds.BuildForm.GetEditingLockedEchoes()
        if p then return p end
    end
    local build = EbonBuilds.Build.GetCurrent()
    if build and build.lockedEchoes then return build.lockedEchoes end
    return { nil, nil, nil, nil, nil }
end

function EbonBuilds.Scoring.IsLocked(spellId)
    if not spellId then return false end
    local lockeds = EbonBuilds.Scoring.GetEffectiveLockedEchoes()
    if not lockeds then return false end
    for i = 1, EbonBuilds.Build.LOCKED_SLOTS do
        if lockeds[i] and lockeds[i] == spellId then
            return true
        end
    end
    return false
end

function EbonBuilds.Scoring.IsBanned(spellId)
    if not spellId then return false end
    local settings = EbonBuilds.Scoring.GetEffectiveSettings()
    local banList = settings and settings.echoBanList
    return banList and banList[spellId] and true or false
end

function EbonBuilds.Scoring.IsBannedByName(echoName)
    if not echoName then return false end
    local settings = EbonBuilds.Scoring.GetEffectiveSettings()
    local banList = settings and settings.echoBanList
    if not banList then return false end
    local best = EbonBuilds.EchoTableRows and EbonBuilds.EchoTableRows.BuildBestByName and EbonBuilds.EchoTableRows.BuildBestByName()
    if best and best[echoName] and best[echoName].spellIds then
        for _, sid in pairs(best[echoName].spellIds) do
            if banList[sid] then return true end
        end
    end
    return false
end

function EbonBuilds.Scoring.GetEffectiveSettings()
    if EbonBuilds.ViewRouter and EbonBuilds.ViewRouter.Current() == "buildOverview" then
        if EbonBuilds.BuildForm and EbonBuilds.BuildForm.GetEditingSettings then
            local s = EbonBuilds.BuildForm.GetEditingSettings()
            if s then return s end
        end
    end
    local build = EbonBuilds.Build.GetCurrent()
    if build and build.settings then return build.settings end
    return EbonBuilds.Build.DefaultSettings()
end

function EbonBuilds.Scoring.ScoreBreakdown(entry, weight, settings)
    local qb = settings.qualityBonus or {}
    local qm = settings.qualityBonusMode or {}
    local fb = settings.familyBonus  or {}
    local fm = settings.familyBonusMode or {}
    local wl = settings.banishFamilyWhitelist or {}
    local base = weight or 0
    local parts = {}
    local total = base

    parts[#parts + 1] = { label = "Weight", value = base }

    local qbVal = qb[entry.quality] or 0
    if qbVal ~= 0 then
        total = total + (qm[entry.quality] and (base == 0 and qbVal or base * (qbVal - 1)) or qbVal)
        parts[#parts + 1] = { label = QUALITY_LABELS[entry.quality] or "Quality", value = FormatModifier(base, qbVal, qm[entry.quality]) }
    end

    if entry.families and #entry.families > 0 then
        local hasWhitelist = false
        for _ in pairs(wl) do hasWhitelist = true; break end
        for _, fam in ipairs(entry.families) do
            local key = NormFamily(fam)
            if key and (not hasWhitelist or wl[key]) then
                local fVal = fb[key] or 0
                if fVal ~= 0 then
                    total = total + (fm[key] and (base == 0 and fVal or base * (fVal - 1)) or fVal)
                    parts[#parts + 1] = { label = "Family: " .. fam, value = FormatModifier(base, fVal, fm[key]) }
                end
            end
        end
    end

    local nv = settings.noveltyValue or 0
    if nv ~= 0 then
        total = total + (settings.noveltyMode and (base == 0 and nv or base * (nv - 1)) or nv)
        parts[#parts + 1] = { label = "Novelty", value = FormatModifier(base, nv, settings.noveltyMode) }
    end

    return parts, total
end
