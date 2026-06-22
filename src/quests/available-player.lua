local Quests = _G.VanillaEnhanced:GetModule("quests")

local RACE_MASKS = {
    Human = 1,
    Orc = 2,
    Dwarf = 4,
    NightElf = 8,
    Scourge = 16,
    Tauren = 32,
    Gnome = 64,
    Troll = 128,
    BloodElf = 512,
    Draenei = 1024,
}

local CLASS_MASKS = {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 4,
    ROGUE = 8,
    PRIEST = 16,
    SHAMAN = 64,
    MAGE = 128,
    WARLOCK = 256,
    DRUID = 1024,
}

local PROFESSION_NAMES = {
    [129] = "First Aid",
    [164] = "Blacksmithing",
    [165] = "Leatherworking",
    [171] = "Alchemy",
    [182] = "Herbalism",
    [185] = "Cooking",
    [186] = "Mining",
    [197] = "Tailoring",
    [202] = "Engineering",
    [333] = "Enchanting",
    [356] = "Fishing",
    [393] = "Skinning",
    [755] = "Jewelcrafting",
    [762] = "Riding",
}

local PROFESSION_RANK_SPELLS = {
    [129] = {3273, 3274, 7924, 10846, 27028},
    [164] = {2018, 3100, 3538, 9785, 29844},
    [165] = {2108, 3104, 3811, 10662, 32549},
    [171] = {2259, 3101, 3464, 11611, 28596},
    [182] = {2366, 2368, 3570, 11993, 28695},
    [185] = {2550, 3102, 3413, 18260, 33359},
    [186] = {2575, 2576, 3564, 10248, 29354},
    [197] = {3908, 3909, 3910, 12180, 26790},
    [202] = {4036, 4037, 4038, 12656, 30350},
    [333] = {7411, 7412, 7413, 13920, 28029},
    [356] = {7620, 7731, 7732, 18248, 33095},
    [393] = {8613, 8617, 8618, 10768, 32678},
    [755] = {25229, 25230, 28894, 28895, 28897},
    [762] = {33388, 33391, 34090, 34091, 90265},
}

local SPECIALIZATION_GROUPS = {
    [164] = {9788, 9787},
    [165] = {10656, 10658, 10660},
    [171] = {28677, 28675, 28672},
    [197] = {26798, 26801, 26797},
    [202] = {20219, 20222},
}

local SPECIALIZATION_SPELLS = {
    [9787] = true,
    [9788] = true,
    [10656] = true,
    [10658] = true,
    [10660] = true,
    [17039] = true,
    [17040] = true,
    [17041] = true,
    [20219] = true,
    [20222] = true,
    [26797] = true,
    [26798] = true,
    [26801] = true,
    [28672] = true,
    [28675] = true,
    [28677] = true,
}

local FACTIONS_STARTING_BELOW_NEUTRAL = {
    [87] = true,
    [576] = true,
    [910] = true,
    [941] = true,
    [970] = true,
    [978] = true,
    [1015] = true,
}

local RIDING_SKILL_BY_SPELL = {
    [33388] = 75,
    [33391] = 150,
    [34090] = 225,
    [34091] = 300,
    [90265] = 375,
}

local function HasBit(mask, flag)
    if not mask or mask == 0 or not flag or flag == 0 then
        return true
    end
    return (mask % (flag * 2)) >= flag
end

local function PlayerRaceMask()
    local race = UnitRace and select(2, UnitRace("player"))
    return race and RACE_MASKS[race] or nil
end

local function PlayerClassMask()
    local class = UnitClass and select(2, UnitClass("player"))
    return class and CLASS_MASKS[class] or nil
end

local function IsSpellKnownCompat(spellId)
    if not spellId or spellId == 0 then
        return false
    end

    local absoluteSpellId = math.abs(spellId)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, absoluteSpellId)
        if ok then
            return known == true
        end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, absoluteSpellId)
        if ok then
            return known == true
        end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, absoluteSpellId)
        if ok then
            return known == true
        end
    end

    return nil
end

local function BuildProfessionLookup()
    local lookup = {}

    for professionId, name in pairs(PROFESSION_NAMES) do
        lookup[name] = professionId
    end

    if GetSpellInfo then
        for professionId, ranks in pairs(PROFESSION_RANK_SPELLS) do
            local spellName = GetSpellInfo(ranks[1])
            if spellName then
                lookup[spellName] = professionId
            end
        end
    end

    return lookup
end

local function BuildPlayerProfessions()
    if not GetNumSkillLines or not GetSkillLineInfo then
        return nil
    end

    if Quests.buildingAvailablePlayerProfessions then
        return Quests.availablePlayerProfessions
    end
    Quests.buildingAvailablePlayerProfessions = true

    if ExpandSkillHeader then
        pcall(ExpandSkillHeader, 0)
    end

    local okCount, count = pcall(GetNumSkillLines)
    if not okCount or type(count) ~= "number" then
        Quests.buildingAvailablePlayerProfessions = false
        return nil
    end

    local lookup = BuildProfessionLookup()
    local professions = {}
    for index = 1, count do
        local ok, skillName, isHeader, isExpanded, skillRank = pcall(GetSkillLineInfo, index)
        if ok and skillName and not isHeader and lookup[skillName] then
            professions[lookup[skillName]] = skillRank or 0
        end
    end

    if not professions[762] then
        for spellId, skillLevel in pairs(RIDING_SKILL_BY_SPELL) do
            local known = IsSpellKnownCompat(spellId)
            if known then
                professions[762] = math.max(professions[762] or 0, skillLevel)
            end
        end
    end

    Quests.availablePlayerProfessions = professions
    Quests.buildingAvailablePlayerProfessions = false
    return professions
end

local function BuildPlayerReputations()
    if not GetNumFactions or not GetFactionInfo then
        return nil
    end

    if Quests.buildingAvailablePlayerReputations then
        return Quests.availablePlayerReputations
    end
    Quests.buildingAvailablePlayerReputations = true

    if ExpandFactionHeader then
        pcall(ExpandFactionHeader, 0)
    end

    local okCount, count = pcall(GetNumFactions)
    if not okCount or type(count) ~= "number" then
        Quests.buildingAvailablePlayerReputations = false
        return nil
    end

    local reputations = {}
    for index = 1, count do
        local ok, name, description, standingId, barMin, barMax, barValue, atWar, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionId = pcall(GetFactionInfo, index)
        if ok and factionId and description then
            reputations[factionId] = barValue or 0
        end
    end

    Quests.availablePlayerReputations = reputations
    Quests.buildingAvailablePlayerReputations = false
    return reputations
end

local function GetReputationValue(requiredRep, context)
    if not requiredRep then
        return nil
    end
    if not context or not context.reputations then
        return nil
    end

    local factionId = requiredRep[1]
    local value = context.reputations[factionId]
    if value ~= nil then
        return value
    end

    if FACTIONS_STARTING_BELOW_NEUTRAL[factionId] then
        return -36000
    end
    return 0
end

local function HasRequiredReputation(dbQuest, context)
    if not dbQuest.rmin and not dbQuest.rmax then
        return true
    end
    if not context or not context.reputations then
        return true
    end

    local minValue = GetReputationValue(dbQuest.rmin, context)
    if dbQuest.rmin and minValue ~= nil and minValue < dbQuest.rmin[2] then
        return false
    end

    local maxValue = GetReputationValue(dbQuest.rmax, context)
    if dbQuest.rmax and maxValue ~= nil and maxValue >= dbQuest.rmax[2] then
        return false
    end

    return true
end

local function HasRequiredSkill(requiredSkill, context)
    if not requiredSkill then
        return true
    end
    if not context or not context.professions then
        return true
    end

    local professionId = requiredSkill[1]
    local requiredLevel = requiredSkill[2]
    local playerLevel = context.professions[professionId]
    return playerLevel ~= nil and playerLevel >= requiredLevel
end

local function HasRankLevel(professionId, rankLevel, exactRank)
    local ranks = PROFESSION_RANK_SPELLS[professionId]
    if not ranks then
        return nil
    end

    local maxRank = exactRank and rankLevel or #ranks
    local checkedAny = false
    for index = rankLevel, maxRank do
        local spellId = ranks[index]
        if spellId then
            checkedAny = true
            local known = IsSpellKnownCompat(spellId)
            if known == nil then
                return nil
            end
            if known then
                return true
            end
        end
    end

    if not checkedAny then
        return nil
    end
    return false
end

local function HasRequiredRanks(requiredRanks, context)
    if not requiredRanks then
        return true
    end
    if not context or not context.professions then
        return true
    end

    local hasProfession = false
    local hasRankLevel = false
    local hasNegativeRanks = false

    for _, requirement in ipairs(requiredRanks) do
        local professionId = requirement[1]
        local rankLevel = requirement[2]
        if rankLevel > 0 then
            if context.professions[professionId] ~= nil then
                hasProfession = true
                local rankMatches = HasRankLevel(professionId, rankLevel, false)
                if rankMatches == nil then
                    return true
                end
                if not hasRankLevel and rankMatches then
                    hasRankLevel = true
                end
            end
        else
            rankLevel = math.abs(rankLevel)
            hasNegativeRanks = true
            if context.professions[professionId] ~= nil then
                hasProfession = true
                local rankMatches = HasRankLevel(professionId, rankLevel, true)
                if rankMatches == nil then
                    return true
                end
                if not hasRankLevel and rankMatches then
                    hasRankLevel = true
                end
            end
        end
    end

    if hasNegativeRanks and hasProfession then
        hasRankLevel = not hasRankLevel
    end

    if hasNegativeRanks then
        return not (hasProfession and not hasRankLevel)
    end
    return hasProfession and hasRankLevel
end

local function HasNoSpecializationFromGroup(professionId)
    local spells = SPECIALIZATION_GROUPS[professionId]
    if not spells then
        return true
    end

    for _, spellId in ipairs(spells) do
        local known = IsSpellKnownCompat(spellId)
        if known == nil then
            return true
        end
        if known then
            return false
        end
    end

    return true
end

local function HasRequiredSpecialization(requiredSpecialization, context)
    if not requiredSpecialization or requiredSpecialization <= 0 then
        return true
    end

    if PROFESSION_RANK_SPELLS[requiredSpecialization] then
        if not context or not context.professions then
            return true
        end
        if context.professions[requiredSpecialization] == nil then
            return false
        end
        return HasNoSpecializationFromGroup(requiredSpecialization)
    end

    if SPECIALIZATION_SPELLS[requiredSpecialization] then
        local known = IsSpellKnownCompat(requiredSpecialization)
        return known == nil or known == true
    end

    return true
end

local function HasRequiredSpell(requiredSpell)
    if not requiredSpell or requiredSpell == 0 then
        return true
    end

    local known = IsSpellKnownCompat(requiredSpell)
    if known == nil then
        return true
    end
    if requiredSpell > 0 then
        return known == true
    end
    return known ~= true
end

function Quests:BuildAvailableQuestPlayerContext()
    return {
        professions = BuildPlayerProfessions(),
        reputations = BuildPlayerReputations(),
    }
end

function Quests:MeetsAvailableQuestPlayerRequirements(dbQuest, context)
    if not HasBit(dbQuest.rr, PlayerRaceMask()) or not HasBit(dbQuest.rc, PlayerClassMask()) then
        return false
    end
    if not HasRequiredReputation(dbQuest, context) then
        return false
    end
    if not HasRequiredSkill(dbQuest.sk, context) or not HasRequiredRanks(dbQuest.rk, context) then
        return false
    end
    if not HasRequiredSpecialization(dbQuest.spec, context) or not HasRequiredSpell(dbQuest.spell) then
        return false
    end
    return true
end
