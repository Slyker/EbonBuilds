-- EbonBuilds: modules/ui/BuildOverview/EchoesData.lua
-- Shared echo data computation helpers.
-- DRY: extracts common perk-fetching and sorting logic used by
-- ComputeOwnedEchoes, ComputeAllEchoes, and ComputeMissingEchoes.

EbonBuilds.BuildOverview = {}

local BO = EbonBuilds.BuildOverview

------------------------------------------------------------------------
-- Echo name normalization (strips cosmetic prefixes/suffixes)
------------------------------------------------------------------------

local PREFIXES = { "tome of ", "codex of ", "scroll of ", "manual of ", "grimoire of ", "libram of ", "tablet of " }
local QUALITY_SUFFIXES = { " %- common", " %- uncommon", " %- rare", " %- epic", " %- legendary" }

local function NormalizeEchoName(name)
    if not name then return nil end
    local n = strlower(name)
    for _, prefix in ipairs(PREFIXES) do
        if n:sub(1, #prefix) == prefix then
            n = n:sub(#prefix + 1)
            break
        end
    end
    for _, suffix in ipairs(QUALITY_SUFFIXES) do
        if n:sub(-#suffix) == suffix then
            n = n:sub(1, -(#suffix + 1))
            break
        end
    end
    return n
end

------------------------------------------------------------------------
-- DRY: shared perk fetching
------------------------------------------------------------------------

local function FetchPerkInstances()
    local granted = {}
    if ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetGrantedPerks then
        granted = ProjectEbonhold.PerkService.GetGrantedPerks() or {}
    end
    local locked = {}
    if ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetLockedPerks then
        locked = ProjectEbonhold.PerkService.GetLockedPerks() or {}
    end
    return granted, locked
end

local function SortEchoList(list)
    table.sort(list, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        return a.name < b.name
    end)
    return list
end

------------------------------------------------------------------------
-- ComputeOwnedEchoes: currently active/owned echoes from granted perks
------------------------------------------------------------------------

local function ComputeOwnedEchoes()
    if not ProjectEbonhold or not ProjectEbonhold.PerkDatabase then return {} end

    local granted, locked = FetchPerkInstances()

    local bySpellId = {}

    for spellName, instances in pairs(granted) do
        for _, inst in ipairs(instances) do
            local sid = inst.spellId
            if sid and sid ~= 0 then
                local db = ProjectEbonhold.PerkDatabase[sid]
                local quality = inst.quality or (db and db.quality) or 0
                local existing = bySpellId[sid]
                if not existing or quality > existing.quality then
                    bySpellId[sid] = {
                        spellId   = sid,
                        name      = spellName,
                        quality   = quality,
                        stack     = inst.stack or 1,
                        maxStack  = inst.maxStack or (db and db.maxStack) or 1,
                        families  = db and db.families or {},
                        classMask = db and db.classMask or 0,
                    }
                elseif quality == existing.quality then
                    existing.stack = (existing.stack or 1) + (inst.stack or 1)
                end
            end
        end
    end

    for _, inst in ipairs(locked) do
        local sid = inst.spellId
        if sid and sid ~= 0 then
            local db = ProjectEbonhold.PerkDatabase[sid]
            local spellName = GetSpellInfo(sid) or ("Spell " .. sid)
            local quality = inst.quality or (db and db.quality) or 0
            local existing = bySpellId[sid]
            if not existing or quality > existing.quality then
                bySpellId[sid] = {
                    spellId   = sid,
                    name      = spellName,
                    quality   = quality,
                    stack     = inst.stack or 1,
                    maxStack  = inst.maxStack or (db and db.maxStack) or 1,
                    families  = db and db.families or {},
                    classMask = db and db.classMask or 0,
                    locked    = true,
                }
            elseif quality == existing.quality then
                existing.stack = (existing.stack or 1) + (inst.stack or 1)
            end
        end
    end

    local list = {}
    for _, entry in pairs(bySpellId) do
        list[#list + 1] = entry
    end
    return SortEchoList(list)
end

------------------------------------------------------------------------
-- ComputeAllEchoes: all echoes from PerkDatabase with ownership status
------------------------------------------------------------------------

local function ComputeAllEchoes()
    if not ProjectEbonhold or not ProjectEbonhold.PerkDatabase then return {} end

    local granted, locked = FetchPerkInstances()

    local ownedStacks = {}
    for spellName, instances in pairs(granted) do
        for _, inst in ipairs(instances) do
            if inst.spellId then
                ownedStacks[inst.spellId] = (ownedStacks[inst.spellId] or 0) + (inst.stack or 1)
            end
        end
    end
    for _, inst in ipairs(locked) do
        if inst.spellId then
            ownedStacks[inst.spellId] = (ownedStacks[inst.spellId] or 0) + (inst.stack or 1)
        end
    end

    local bySpellId = {}
    for spellId, data in pairs(ProjectEbonhold.PerkDatabase) do
        if data.comment and data.comment ~= "" then
            local quality = data.quality or 0
            local existing = bySpellId[spellId]
            if not existing or quality > existing.quality then
                local stack = ownedStacks[spellId] or 0
                bySpellId[spellId] = {
                    spellId   = spellId,
                    name      = data.comment,
                    quality   = quality,
                    stack     = stack,
                    maxStack  = data.maxStack or 1,
                    families  = data.families or {},
                    classMask = data.classMask or 0,
                    owned     = stack > 0,
                }
            elseif quality == existing.quality then
                existing.stack = (existing.stack or 0) + (ownedStacks[spellId] or 0)
                if existing.stack > 0 then existing.owned = true end
            end
        end
    end

    local list = {}
    for _, entry in pairs(bySpellId) do
        list[#list + 1] = entry
    end
    return SortEchoList(list)
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

BO.EchoesData = {
    NormalizeEchoName = NormalizeEchoName,
    ComputeOwnedEchoes = ComputeOwnedEchoes,
    ComputeAllEchoes = ComputeAllEchoes,
}
