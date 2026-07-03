local VanillaEnhanced = _G.VanillaEnhanced
local Training = VanillaEnhanced:CreateModule("training", VanillaEnhanced:T("module.training"))

local DISPLAY_TRAINABLE = "trainable"
local DISPLAY_ALL_UNLEARNED = "all-unlearned"

local defaults = {
    enabled = false,
    displayMode = DISPLAY_TRAINABLE,
}

Training.displayModes = {
    DISPLAY_TRAINABLE,
    DISPLAY_ALL_UNLEARNED,
}

Training.spellInfoCache = Training.spellInfoCache or {}
Training.overriddenSpellsMap = Training.overriddenSpellsMap or {}
Training.rankIndex = Training.rankIndex or {}
Training.spells = Training.spells or {}
Training.pages = Training.pages or {}
Training.dirty = true

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function NormalizeDisplayMode(mode)
    if mode == DISPLAY_ALL_UNLEARNED then
        return mode
    end
    return DISPLAY_TRAINABLE
end

function Training:GetSettings()
    local settings = VanillaEnhanced:GetModuleSettings("training", defaults)
    settings.displayMode = NormalizeDisplayMode(settings.displayMode)
    return settings
end

function Training:SetEnabled(enabled)
    VanillaEnhanced:SetModuleEnabled("training", enabled)
    self:MarkDirty()
    self:RefreshSpellbook()
end

function Training:IsEnabled()
    return self:GetSettings().enabled ~= false
end

function Training:MarkDirty()
    self.dirty = true
end

local function IsSpellKnownNow(spellId)
    if type(IsSpellKnown) == "function" and IsSpellKnown(spellId) then
        return true
    end
    if type(IsPlayerSpell) == "function" and IsPlayerSpell(spellId) then
        return true
    end
    return false
end

function Training:IsPreviouslyLearnedAbility(spellId)
    local ranks = self.overriddenSpellsMap and self.overriddenSpellsMap[spellId]
    if not ranks then
        return false
    end

    local spellIndex = 0
    local knownIndex = 0
    for index, otherId in ipairs(ranks) do
        if otherId == spellId then
            spellIndex = index
        end
        if IsSpellKnownNow(otherId) then
            knownIndex = index
        end
    end
    return spellIndex > 0 and spellIndex <= knownIndex
end

function Training:IsAbilityKnown(spellId)
    return IsSpellKnownNow(spellId) or self:IsPreviouslyLearnedAbility(spellId)
end

function Training:BuildOverriddenSpellsMap(classKey)
    local data = VanillaEnhanced.trainingData
    local groups = data and data.overriddenByClass and data.overriddenByClass[classKey]
    local map = {}

    for _, spellIds in ipairs(groups or {}) do
        for _, spellId in ipairs(spellIds) do
            map[spellId] = spellIds
        end
    end

    self.overriddenSpellsMap = map
end

local function PlayerMatchesSpell(spell)
    if spell.faction and UnitFactionGroup and UnitFactionGroup("player") ~= spell.faction then
        return false
    end

    if not spell.race and not spell.races then
        return true
    end

    local playerRace = select(3, UnitRace("player"))
    if spell.race then
        return spell.race == playerRace
    end
    for _, race in ipairs(spell.races or {}) do
        if race == playerRace then
            return true
        end
    end
    return false
end

local function ReadSpellInfo(spellId)
    local name, rank, icon = GetSpellInfo(spellId)
    if not name and type(Spell) == "table" and Spell.CreateFromSpellID then
        local spell = Spell:CreateFromSpellID(spellId)
        if spell and spell.GetSpellName then
            name = spell:GetSpellName()
        end
        if spell and spell.GetSpellSubtext then
            rank = spell:GetSpellSubtext()
        end
        if not icon and spell and spell.GetSpellTexture then
            icon = spell:GetSpellTexture()
        end
    end
    return name, rank, icon
end

function Training:BuildRankIndex(classKey)
    local data = VanillaEnhanced.trainingData
    local spellsByLevel = data and data.spellsByClass and data.spellsByClass[classKey]
    local spellSet = {}
    local spellEntries = {}
    local spellNames = {}
    local previousById = {}
    local childCountById = {}
    local rankIndex = {}

    for _, levelSpells in pairs(spellsByLevel or {}) do
        for _, spell in ipairs(levelSpells) do
            spellSet[spell.id] = true
            spellEntries[#spellEntries + 1] = spell
        end
    end

    for _, spell in ipairs(spellEntries) do
        local name = ReadSpellInfo(spell.id)
        spellNames[spell.id] = name
    end

    for _, spell in ipairs(spellEntries) do
        local spellName = spellNames[spell.id]
        if spellName then
            for _, requiredId in ipairs(spell.requiredIds or {}) do
                if spellSet[requiredId] and spellNames[requiredId] == spellName then
                    previousById[spell.id] = requiredId
                    childCountById[requiredId] = (childCountById[requiredId] or 0) + 1
                    break
                end
            end
        end
    end

    local visiting = {}
    local ResolveRank
    ResolveRank = function(spellId)
        if rankIndex[spellId] then
            return rankIndex[spellId]
        end
        if visiting[spellId] then
            return nil
        end

        visiting[spellId] = true
        local previousId = previousById[spellId]
        if previousId then
            local previousRank = ResolveRank(previousId)
            if previousRank then
                rankIndex[spellId] = previousRank + 1
            end
        elseif childCountById[spellId] then
            rankIndex[spellId] = 1
        end
        visiting[spellId] = nil

        return rankIndex[spellId]
    end

    for _, spell in ipairs(spellEntries) do
        ResolveRank(spell.id)
    end

    self.rankIndex = rankIndex
end

function Training:GetSpellRankText(spellId, rank)
    if rank and rank ~= "" then
        return rank
    end

    local rankNumber = self.rankIndex and self.rankIndex[spellId]
    if rankNumber then
        return T("training.spell.rank", { rank = rankNumber })
    end

    return rank
end

function Training:GetSpellInfo(spell)
    local cached = self.spellInfoCache[spell.id]
    if cached then
        return cached
    end

    local name, rank, icon = ReadSpellInfo(spell.id)
    if not name then
        name = T("training.spell.unknown", { spellID = spell.id })
    end

    cached = {
        id = spell.id,
        name = name,
        rank = self:GetSpellRankText(spell.id, rank),
        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        link = string.format("|cff71d5ff|Hspell:%d:0|h[%s]|h|r", spell.id, name),
    }
    self.spellInfoCache[spell.id] = cached
    return cached
end

function Training:GetRequirementState(spell, playerLevel)
    if spell.requiredTalentId and not self:IsAbilityKnown(spell.requiredTalentId) then
        return "missing-talent"
    end

    for _, requiredId in ipairs(spell.requiredIds or {}) do
        if not self:IsAbilityKnown(requiredId) then
            return "missing-requirement"
        end
    end

    if spell.level > playerLevel then
        return "future"
    end

    return "trainable"
end

function Training:ShouldIncludeSpell(spell, state, playerLevel, settings)
    if settings.displayMode == DISPLAY_ALL_UNLEARNED then
        return true
    end

    return state == "trainable"
end

local function SortSpellEntries(left, right)
    if left.level ~= right.level then
        return left.level < right.level
    end
    if left.name ~= right.name then
        return left.name < right.name
    end
    return left.id < right.id
end

function Training:Rebuild()
    local _, classKey = UnitClass("player")
    local data = VanillaEnhanced.trainingData
    local spellsByLevel = data and data.spellsByClass and data.spellsByClass[classKey]
    local playerLevel = UnitLevel("player") or 1
    local settings = self:GetSettings()
    local spells = {}

    self:BuildOverriddenSpellsMap(classKey)
    self:BuildRankIndex(classKey)

    for level, levelSpells in pairs(spellsByLevel or {}) do
        for _, spell in ipairs(levelSpells) do
            if PlayerMatchesSpell(spell) and not self:IsAbilityKnown(spell.id) then
                spell.level = level
                local state = self:GetRequirementState(spell, playerLevel)
                if self:ShouldIncludeSpell(spell, state, playerLevel, settings) then
                    local info = self:GetSpellInfo(spell)
                    spells[#spells + 1] = {
                        id = spell.id,
                        name = info.name,
                        rank = info.rank,
                        icon = info.icon,
                        link = info.link,
                        cost = spell.cost or 0,
                        level = level,
                        state = state,
                    }
                end
            end
        end
    end

    table.sort(spells, SortSpellEntries)
    self.spells = spells
    self.dirty = false
    self:BuildPages()
end

function Training:BuildPages()
    local perPage = self:GetSpellsPerPage()
    local pages = {}
    local page

    for index, spell in ipairs(self.spells or {}) do
        local pageIndex = math.floor((index - 1) / perPage) + 1
        page = pages[pageIndex]
        if not page then
            page = {}
            pages[pageIndex] = page
        end
        page[#page + 1] = spell
    end

    self.pages = pages
end

function Training:GetSpellsPerPage()
    if type(SPELLS_PER_PAGE) == "number" and SPELLS_PER_PAGE > 0 then
        return SPELLS_PER_PAGE
    end
    return 12
end

function Training:GetPages()
    if self.dirty then
        self:Rebuild()
    end
    return self.pages or {}
end

function Training:GetPageCount()
    return #self:GetPages()
end

function Training:GetPage(index)
    return self:GetPages()[index]
end

function Training:GetStateLabel(state, level)
    if state == "trainable" then
        return T("training.state.trainable")
    end
    if state == "future" then
        return T("training.state.future", { level = level })
    end
    if state == "missing-requirement" then
        return T("training.state.missingRequirement")
    end
    if state == "missing-talent" then
        return T("training.state.missingTalent")
    end
    return ""
end

function Training:RefreshSpellbook()
    if self.UpdateTrainingTab then
        self:UpdateTrainingTab()
    end
    if self.UpdateSpellbook then
        self:UpdateSpellbook()
    end
end

function Training:Update()
    self:MarkDirty()
    self:RefreshSpellbook()
end

local eventFrame = CreateFrame("Frame")
Training.eventFrame = eventFrame

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        Training:MarkDirty()
        if Training.InstallSpellbookOverlay then
            Training:InstallSpellbookOverlay()
        end
    elseif event == "PLAYER_MONEY" then
        Training:RefreshSpellbook()
    else
        Training:Update()
    end
end)

local function RegisterEventIfAvailable(eventName)
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end

RegisterEventIfAvailable("PLAYER_ENTERING_WORLD")
RegisterEventIfAvailable("PLAYER_LEVEL_UP")
RegisterEventIfAvailable("PLAYER_MONEY")
RegisterEventIfAvailable("SPELLS_CHANGED")
RegisterEventIfAvailable("LEARNED_SPELL_IN_SKILL_LINE")
