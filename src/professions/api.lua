local VanillaEnhanced = _G.VanillaEnhanced
local Professions = VanillaEnhanced:CreateModule("professions", VanillaEnhanced:T("module.professions"))

local Api = {}
Professions.Api = Api

local PROFESSION_NAMES = {
    [129] = "First Aid",
    [164] = "Blacksmithing",
    [165] = "Leatherworking",
    [171] = "Alchemy",
    [185] = "Cooking",
    [182] = "Herbalism",
    [186] = "Mining",
    [197] = "Tailoring",
    [202] = "Engineering",
    [333] = "Enchanting",
    [755] = "Jewelcrafting",
}

local PROFESSION_SKILL_LINE_NAMES = {
    [129] = {"First Aid", "Secourisme"},
    [164] = {"Blacksmithing", "Forge"},
    [165] = {"Leatherworking", "Travail du cuir"},
    [171] = {"Alchemy", "Alchimie"},
    [185] = {"Cooking", "Cuisine"},
    [182] = {"Herbalism", "Herboristerie"},
    [186] = {"Mining", "Minage"},
    [197] = {"Tailoring", "Couture"},
    [202] = {"Engineering", "Ingénierie"},
    [333] = {"Enchanting", "Enchantement"},
    [755] = {"Jewelcrafting", "Joaillerie"},
}

local PROFESSION_RANK_SPELLS = {
    [129] = {3273, 3274, 7924, 10846, 27028},
    [164] = {2018, 3100, 3538, 9785, 29844},
    [165] = {2108, 3104, 3811, 10662, 32549},
    [171] = {2259, 3101, 3464, 11611, 28596},
    [185] = {2550, 3102, 3413, 18260, 33359},
    [182] = {2366, 2368, 3570, 11993, 28695},
    [186] = {2575, 2576, 3564, 10248, 29354},
    [197] = {3908, 3909, 3910, 12180, 26790},
    [202] = {4036, 4037, 4038, 12656, 30350},
    [333] = {7411, 7412, 7413, 13920, 28029},
    [755] = {25229, 25230, 28894, 28895, 28897},
}

local PROFESSION_RANK_SKILL_FLOORS = {1, 50, 125, 200, 275}
local PROFESSION_RANK_SKILL_CAPS = {75, 150, 225, 300, 375}

local function GetItemIDFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(string.match(link, "item:(%d+)"))
end

local function GetSpellIDFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(string.match(link, "spell:(%d+)")) or tonumber(string.match(link, "enchant:(%d+)"))
end

local localizedProfessionNames = {}
local function GetLocalizedProfessionName(professionID)
    if localizedProfessionNames[professionID] then
        return localizedProfessionNames[professionID]
    end

    local ranks = PROFESSION_RANK_SPELLS[professionID]
    if ranks and type(GetSpellInfo) == "function" then
        local name = GetSpellInfo(ranks[1])
        if name then
            localizedProfessionNames[professionID] = name
            return name
        end
    end

    return nil
end

local function IsSpellKnownCompat(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return false
    end

    if C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and known ~= nil then
            return known == true
        end
    end
    if type(IsSpellKnown) == "function" then
        local ok, known = pcall(IsSpellKnown, spellID)
        if ok and known ~= nil then
            return known == true
        end
    end
    if type(IsPlayerSpell) == "function" then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and known ~= nil then
            return known == true
        end
    end

    return false
end

local function NormalizeProfessionLookupName(name)
    if type(name) ~= "string" then
        return nil
    end

    name = string.gsub(name, "%s*%b()", "")
    name = string.gsub(name, "^%s*(.-)%s*$", "%1")
    if name == "" then
        return nil
    end
    return name
end

local function AddProfessionLookupName(lookup, name, professionID)
    if type(name) ~= "string" then
        return
    end

    lookup[name] = professionID

    local normalizedName = NormalizeProfessionLookupName(name)
    if normalizedName then
        lookup[normalizedName] = professionID
    end
end

local function BuildProfessionLookup()
    local lookup = {}

    for professionID, name in pairs(PROFESSION_NAMES) do
        AddProfessionLookupName(lookup, name, professionID)
    end

    for professionID, names in pairs(PROFESSION_SKILL_LINE_NAMES) do
        for _, name in ipairs(names) do
            AddProfessionLookupName(lookup, name, professionID)
        end
    end

    if type(GetSpellInfo) == "function" then
        for professionID, ranks in pairs(PROFESSION_RANK_SPELLS) do
            for _, spellID in ipairs(ranks) do
                local spellName = GetSpellInfo(spellID)
                AddProfessionLookupName(lookup, spellName, professionID)
            end
        end
    end

    return lookup
end

local function AddPlayerProfession(professions, professionID, skillRank)
    professionID = tonumber(professionID)
    if not professionID or not PROFESSION_NAMES[professionID] then
        return false
    end

    skillRank = tonumber(skillRank) or 0
    if not professions[professionID] or skillRank > professions[professionID] then
        professions[professionID] = skillRank
    end
    return true
end

local function ScanProfessionApi(professions)
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        return
    end

    local results = {pcall(GetProfessions)}
    if not results[1] then
        return
    end

    for index = 2, #results do
        local professionIndex = results[index]
        if professionIndex then
            local info = {pcall(GetProfessionInfo, professionIndex)}
            if info[1] then
                local skillLevel = info[4]
                local skillLine = info[8]
                AddPlayerProfession(professions, skillLine, skillLevel)
            end
        end
    end
end

local function ScanSkillLines(professions)
    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
        return
    end

    if ExpandSkillHeader then
        pcall(ExpandSkillHeader, 0)
    end

    local okCount, count = pcall(GetNumSkillLines)
    if not okCount or type(count) ~= "number" then
        return
    end

    local lookup = BuildProfessionLookup()
    for index = 1, count do
        local ok, skillName, isHeader, _, skillRank = pcall(GetSkillLineInfo, index)
        local normalizedSkillName = NormalizeProfessionLookupName(skillName)
        local professionID = (ok and skillName and not isHeader) and (lookup[skillName] or lookup[normalizedSkillName]) or nil
        if professionID then
            AddPlayerProfession(professions, professionID, skillRank)
        end
    end
end

local function CollectSkillLineCandidates()
    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
        return nil
    end

    if ExpandSkillHeader then
        pcall(ExpandSkillHeader, 0)
    end

    local okCount, count = pcall(GetNumSkillLines)
    if not okCount or type(count) ~= "number" then
        return nil
    end

    local lookup = BuildProfessionLookup()
    local candidates = {}
    for index = 1, count do
        local ok, skillName, isHeader, _, skillRank, _, _, skillMaxRank = pcall(GetSkillLineInfo, index)
        skillRank = tonumber(skillRank)
        skillMaxRank = tonumber(skillMaxRank)
        if ok and not isHeader and skillRank and skillMaxRank and skillMaxRank > 0 then
            local normalizedSkillName = NormalizeProfessionLookupName(skillName)
            candidates[#candidates + 1] = {
                index = index,
                name = skillName,
                professionID = lookup[skillName] or lookup[normalizedSkillName],
                rank = skillRank,
                maxRank = skillMaxRank,
            }
        end
    end
    return candidates
end

local function FindUnambiguousSkillLineRank(candidates, assignedCandidates, rankIndex)
    if type(candidates) ~= "table" then
        return nil
    end

    local floor = PROFESSION_RANK_SKILL_FLOORS[rankIndex]
    local cap = PROFESSION_RANK_SKILL_CAPS[rankIndex]
    if not floor or not cap then
        return nil
    end

    local match
    local matches = 0
    for _, candidate in ipairs(candidates) do
        if not assignedCandidates[candidate.index]
            and candidate.maxRank == cap
            and candidate.rank >= floor
            and candidate.rank <= cap then
            matches = matches + 1
            match = candidate
        end
    end

    if matches == 1 and match then
        assignedCandidates[match.index] = true
        return match.rank
    end
    return nil
end

local function ScanKnownProfessionSpells(professions)
    local candidates = CollectSkillLineCandidates()
    local assignedCandidates = {}
    if type(candidates) == "table" then
        for _, candidate in ipairs(candidates) do
            if candidate.professionID and professions[candidate.professionID] ~= nil then
                assignedCandidates[candidate.index] = true
            end
        end
    end

    for professionID, ranks in pairs(PROFESSION_RANK_SPELLS) do
        for index = #ranks, 1, -1 do
            if IsSpellKnownCompat(ranks[index]) then
                AddPlayerProfession(professions, professionID, FindUnambiguousSkillLineRank(candidates, assignedCandidates, index) or PROFESSION_RANK_SKILL_FLOORS[index])
                break
            end
        end
    end
end

function Api:GetItemIDFromLink(link)
    return GetItemIDFromLink(link)
end

function Api:GetTooltipItemID(tooltip)
    if not tooltip or type(tooltip.GetItem) ~= "function" then
        return nil
    end

    local _, link = tooltip:GetItem()
    return GetItemIDFromLink(link)
end

function Api:IsSpellKnown(spellID)
    return IsSpellKnownCompat(spellID)
end

function Api:GetSpellName(spellID)
    if type(GetSpellInfo) == "function" then
        local name = GetSpellInfo(spellID)
        if name then
            return name
        end
    end
    return nil
end

function Api:GetProfessionName(professionID)
    return GetLocalizedProfessionName(professionID) or PROFESSION_NAMES[professionID]
end

function Api:BuildPlayerProfessions()
    if self.buildingPlayerProfessions then
        return Professions.playerProfessions
    end
    self.buildingPlayerProfessions = true

    local professions = {}
    ScanProfessionApi(professions)
    ScanSkillLines(professions)
    ScanKnownProfessionSpells(professions)

    self.buildingPlayerProfessions = false
    return professions
end

function Api:ScanOpenTradeSkillRecipes(cache)
    if type(GetNumTradeSkills) ~= "function" or type(GetTradeSkillInfo) ~= "function" then
        return cache
    end

    cache = cache or {}
    local okCount, count = pcall(GetNumTradeSkills)
    if not okCount or type(count) ~= "number" then
        return cache
    end

    for index = 1, count do
        local ok, name, kind = pcall(GetTradeSkillInfo, index)
        if ok and name and kind ~= "header" and type(GetTradeSkillRecipeLink) == "function" then
            local linkOk, link = pcall(GetTradeSkillRecipeLink, index)
            local spellID = linkOk and GetSpellIDFromLink(link) or nil
            if spellID then
                cache[spellID] = true
            end
        end
    end

    return cache
end
