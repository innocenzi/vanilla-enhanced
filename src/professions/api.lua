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
    [186] = "Mining",
    [197] = "Tailoring",
    [202] = "Engineering",
    [333] = "Enchanting",
    [755] = "Jewelcrafting",
}

local PROFESSION_RANK_SPELLS = {
    [129] = {3273, 3274, 7924, 10846, 27028},
    [164] = {2018, 3100, 3538, 9785, 29844},
    [165] = {2108, 3104, 3811, 10662, 32549},
    [171] = {2259, 3101, 3464, 11611, 28596},
    [185] = {2550, 3102, 3413, 18260, 33359},
    [186] = {2575, 2576, 3564, 10248, 29354},
    [197] = {3908, 3909, 3910, 12180, 26790},
    [202] = {4036, 4037, 4038, 12656, 30350},
    [333] = {7411, 7412, 7413, 13920, 28029},
    [755] = {25229, 25230, 28894, 28895, 28897},
}

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

local function BuildProfessionLookup()
    local lookup = {}

    for professionID, name in pairs(PROFESSION_NAMES) do
        lookup[name] = professionID
    end

    if type(GetSpellInfo) == "function" then
        for professionID, ranks in pairs(PROFESSION_RANK_SPELLS) do
            local spellName = GetSpellInfo(ranks[1])
            if spellName then
                lookup[spellName] = professionID
            end
        end
    end

    return lookup
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
    if not GetNumSkillLines or not GetSkillLineInfo then
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
    local professions = {}
    for index = 1, count do
        local ok, skillName, isHeader, _, skillRank = pcall(GetSkillLineInfo, index)
        if ok and skillName and not isHeader and lookup[skillName] then
            professions[lookup[skillName]] = skillRank or 0
        end
    end

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
