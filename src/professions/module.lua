local VanillaEnhanced = _G.VanillaEnhanced
local Professions = VanillaEnhanced:CreateModule("professions", VanillaEnhanced:T("module.professions"))

local DISPLAY_COMPACT = "compact"
local DISPLAY_RECIPES = "recipes"
local RECIPE_SCOPE_ALL = "all"
local RECIPE_SCOPE_KNOWN = "known"
local PROFESSION_SCOPE_ALL = "all"
local PROFESSION_SCOPE_PLAYER = "player"
local PROFESSION_SCOPE_PLAYER_SKILL = "player-skill"
local MAX_COMPACT_LINES = 6
local MAX_RECIPE_LINES_PER_PROFESSION = 3
local MAX_RECIPE_LINES_PER_PROFESSION_EXPANDED = 30

local defaults = {
    enabled = true,
    displayMode = DISPLAY_COMPACT,
    recipeScope = RECIPE_SCOPE_ALL,
    professionScope = PROFESSION_SCOPE_ALL,
}

local PROFESSION_SORT_ORDER = {
    129,
    185,
    171,
    164,
    165,
    197,
    202,
    333,
    755,
    186,
}

local PROFESSION_ORDER_INDEX = {}
for index, professionID in ipairs(PROFESSION_SORT_ORDER) do
    PROFESSION_ORDER_INDEX[professionID] = index
end

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function NormalizeDisplayMode(mode)
    if mode == DISPLAY_RECIPES then
        return mode
    end
    return DISPLAY_COMPACT
end

local function NormalizeRecipeScope(scope)
    if scope == RECIPE_SCOPE_KNOWN then
        return scope
    end
    return RECIPE_SCOPE_ALL
end

local function NormalizeProfessionScope(scope)
    if scope == PROFESSION_SCOPE_PLAYER or scope == PROFESSION_SCOPE_PLAYER_SKILL then
        return scope
    end
    return PROFESSION_SCOPE_ALL
end

local function SortEntries(left, right)
    local leftOrder = PROFESSION_ORDER_INDEX[left.professionID] or 999
    local rightOrder = PROFESSION_ORDER_INDEX[right.professionID] or 999
    if leftOrder ~= rightOrder then
        return leftOrder < rightOrder
    end
    if left.skill ~= right.skill then
        return left.skill < right.skill
    end
    return left.spellID < right.spellID
end

local function AddEntry(groups, entry)
    local group = groups[entry.professionID]
    if not group then
        group = {
            professionID = entry.professionID,
            entries = {},
        }
        groups[entry.professionID] = group
    end
    group.entries[#group.entries + 1] = entry
end

local function IsRecipeTooltipExpanded()
    if type(IsShiftKeyDown) == "function" and IsShiftKeyDown() then
        return true
    end
    return false
end

local function GetMaxRecipeLinesPerProfession()
    if IsRecipeTooltipExpanded() then
        return MAX_RECIPE_LINES_PER_PROFESSION_EXPANDED
    end
    return MAX_RECIPE_LINES_PER_PROFESSION
end

function Professions:GetSettings()
    local settings = VanillaEnhanced:GetModuleSettings("professions", defaults)
    settings.displayMode = NormalizeDisplayMode(settings.displayMode)
    settings.recipeScope = NormalizeRecipeScope(settings.recipeScope)
    settings.professionScope = NormalizeProfessionScope(settings.professionScope)
    return settings
end

function Professions:IsEnabled()
    return self:GetSettings().enabled ~= false
end

function Professions:SetEnabled(enabled)
    VanillaEnhanced:SetModuleEnabled("professions", enabled)
end

function Professions:Update()
    self.playerProfessions = nil
end

function Professions:GetPlayerProfessions()
    if not self.playerProfessions then
        self.playerProfessions = self.Api and self.Api:BuildPlayerProfessions() or {}
    end
    return self.playerProfessions
end

function Professions:RefreshPlayerProfessions()
    self.playerProfessions = self.Api and self.Api:BuildPlayerProfessions() or {}
end

function Professions:RefreshKnownRecipeCache()
    self.knownRecipeCache = self.Api and self.Api:ScanOpenTradeSkillRecipes(self.knownRecipeCache) or self.knownRecipeCache
end

function Professions:IsRecipeKnown(spellID)
    if self.Api and self.Api:IsSpellKnown(spellID) then
        return true
    end
    return self.knownRecipeCache and self.knownRecipeCache[spellID] == true
end

function Professions:GetRecipeName(spellID)
    return (self.Api and self.Api:GetSpellName(spellID)) or T("professions.recipeFallback", { spellID = spellID })
end

function Professions:GetProfessionName(professionID)
    return (self.Api and self.Api:GetProfessionName(professionID)) or T("professions.professionFallback", {
        professionID = professionID,
    })
end

function Professions:ShouldIncludeEntry(entry, settings)
    if settings.recipeScope == RECIPE_SCOPE_KNOWN and not entry.known then
        return false
    end

    if settings.professionScope == PROFESSION_SCOPE_ALL then
        return true
    end

    local playerProfessions = self:GetPlayerProfessions()
    local playerSkill = playerProfessions and playerProfessions[entry.professionID]
    if playerSkill == nil then
        return false
    end

    if settings.professionScope == PROFESSION_SCOPE_PLAYER_SKILL then
        return playerSkill >= (entry.skill or 0)
    end

    return true
end

function Professions:GetRecipeGroupsForItem(itemID)
    if not self:IsEnabled() then
        return nil
    end

    itemID = tonumber(itemID)
    local db = _G.VanillaEnhancedProfessionRecipesDB
    local entries = db and db.reagents and db.reagents[itemID]
    if not entries then
        return nil
    end

    local settings = self:GetSettings()
    local groupsByProfession = {}
    local groups = {}
    local included = 0

    for _, rawEntry in ipairs(entries) do
        local entry = {
            spellID = rawEntry.s,
            professionID = rawEntry.p,
            quantity = rawEntry.q or 1,
            skill = rawEntry.r or 0,
        }
        entry.known = self:IsRecipeKnown(entry.spellID)
        if self:ShouldIncludeEntry(entry, settings) then
            AddEntry(groupsByProfession, entry)
            included = included + 1
        end
    end

    if included == 0 then
        return nil
    end

    for _, group in pairs(groupsByProfession) do
        table.sort(group.entries, SortEntries)
        groups[#groups + 1] = group
    end
    table.sort(groups, function(left, right)
        return (PROFESSION_ORDER_INDEX[left.professionID] or 999) < (PROFESSION_ORDER_INDEX[right.professionID] or 999)
    end)

    return groups
end

function Professions:AddCompactTooltipLines(tooltip, groups)
    local shown = 0
    local hidden = 0

    for _, group in ipairs(groups) do
        if shown < MAX_COMPACT_LINES then
            local knownCount = 0
            for _, entry in ipairs(group.entries) do
                if entry.known then
                    knownCount = knownCount + 1
                end
            end
            tooltip:AddLine(T("professions.tooltip.compactLine", {
                profession = self:GetProfessionName(group.professionID),
                count = #group.entries,
                known = knownCount,
            }), 0.8, 0.8, 0.8, true)
            shown = shown + 1
        else
            hidden = hidden + 1
        end
    end

    if hidden > 0 then
        tooltip:AddLine(T("professions.tooltip.moreProfessions", { count = hidden }), 0.55, 0.55, 0.55, true)
    end
end

function Professions:AddRecipeTooltipLines(tooltip, groups, settings)
    local expanded = IsRecipeTooltipExpanded()
    local maxLines = GetMaxRecipeLinesPerProfession()
    local shownGroups = 0
    local hasMore = false
    local totalProfessions = #groups

    for _, group in ipairs(groups) do
        local knownCount = 0
        for _, entry in ipairs(group.entries) do
            if entry.known then
                knownCount = knownCount + 1
            end
        end

        if settings.recipeScope == RECIPE_SCOPE_ALL and not expanded and knownCount == 0 then
            hasMore = true
        else
            if shownGroups > 0 then
                tooltip:AddLine(" ")
            end
            shownGroups = shownGroups + 1

            tooltip:AddLine(self:GetProfessionName(group.professionID), 0.9, 0.82, 0.55, true)

            local shown = 0
            for _, entry in ipairs(group.entries) do
                if shown < maxLines then
                    local r, g, b = 0.8, 0.8, 0.8
                    if settings.recipeScope == RECIPE_SCOPE_ALL and not entry.known then
                        r, g, b = 0.45, 0.45, 0.45
                    end
                    tooltip:AddLine(T("professions.tooltip.recipeLine", {
                        recipe = self:GetRecipeName(entry.spellID),
                        quantity = entry.quantity,
                    }), r, g, b, true)
                    shown = shown + 1
                end
            end

            local hidden = #group.entries - shown
            if hidden > 0 then
                hasMore = true
                tooltip:AddLine(T("professions.tooltip.moreRecipes", { count = hidden }), 0.55, 0.55, 0.55, true)
            end
        end
    end

    if hasMore and not expanded then
        if shownGroups > 0 then
            tooltip:AddLine(" ")
        elseif totalProfessions > 0 then
            local summaryKey = totalProfessions == 1 and "professions.tooltip.summaryLine.one" or "professions.tooltip.summaryLine"
            tooltip:AddLine(T(summaryKey, { count = totalProfessions }), 0.9, 0.82, 0.55, true)
        end
        tooltip:AddLine(T("professions.tooltip.shiftHint"), 0.55, 0.55, 0.55, true)
    end
end

function Professions:AddTooltipLines(tooltip, itemID)
    local groups = self:GetRecipeGroupsForItem(itemID)
    if not groups then
        return false
    end

    local settings = self:GetSettings()
    if settings.displayMode == DISPLAY_RECIPES then
        tooltip:AddLine(" ")
        self:AddRecipeTooltipLines(tooltip, groups, settings)
    else
        tooltip:AddLine(" ")
        local summaryKey = #groups == 1 and "professions.tooltip.summaryLine.one" or "professions.tooltip.summaryLine"
        tooltip:AddLine(T(summaryKey, { count = #groups }), 0.9, 0.82, 0.55, true)
        self:AddCompactTooltipLines(tooltip, groups)
    end

    return true
end

local eventFrame = CreateFrame("Frame")
Professions.eventFrame = eventFrame

eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName ~= VanillaEnhanced.addonName then
        return
    end

    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
        Professions:RefreshKnownRecipeCache()
    end
    if event == "SKILL_LINES_CHANGED" or event == "LEARNED_SPELL_IN_SKILL_LINE" or event == "PLAYER_ENTERING_WORLD" then
        Professions:RefreshPlayerProfessions()
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("TRADE_SKILL_UPDATE")
