local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local STATIC_LABELS = {
    frFR = {
        turnin = "Rendre la quête",
        nearby = "objectifs proches",
        area = "points d'objectif dans cette zone",
    },
    enUS = {
        turnin = "Turn in",
        nearby = "nearby objectives",
        area = "objective points in this area",
    },
}

local function CurrentLocale()
    local locale = GetLocale and GetLocale() or "enUS"
    return locale == "frFR" and "frFR" or "enUS"
end

local function LocaleData()
    local locale = CurrentLocale()
    if locale == "frFR" and VanillaEnhancedQuestsLocaleDB and VanillaEnhancedQuestsLocaleDB.frFR then
        return VanillaEnhancedQuestsLocaleDB.frFR, locale
    end
    return nil, "enUS"
end

local function QuestLocaleData(questId)
    local localeData = LocaleData()
    return localeData and localeData.quests and localeData.quests[questId] or nil
end

local function LookupSource(cluster)
    local localeData = LocaleData()
    if not localeData or not cluster or not cluster.st or not cluster.sid then
        return nil
    end

    if cluster.st == "npc" and localeData.npcs then
        return localeData.npcs[cluster.sid]
    end
    if cluster.st == "object" and localeData.objects then
        return localeData.objects[cluster.sid]
    end
    if cluster.st == "item" and localeData.items then
        return localeData.items[cluster.sid]
    end
    return nil
end

local function ObjectiveFromQuestLog(quest, cluster)
    if not quest or not cluster or not cluster.oi or not quest.objectives then
        return nil
    end
    return quest.objectives[cluster.oi]
end

function Quests:GetLocalizedQuestTitle(quest, questId, fallback)
    if quest and quest.title and quest.title ~= "" then
        return quest.title
    end

    local questLocale = QuestLocaleData(questId)
    if questLocale and questLocale.t and questLocale.t ~= "" then
        return questLocale.t
    end

    return fallback or ""
end

function Quests:GetLocalizedSourceName(cluster)
    local sourceName = LookupSource(cluster)
    if sourceName and sourceName ~= "" then
        return sourceName
    end

    if cluster and cluster.o and cluster.o ~= "" then
        return cluster.o
    end

    return nil
end

function Quests:GetLocalizedObjective(quest, cluster)
    local questObjective = ObjectiveFromQuestLog(quest, cluster)
    if questObjective and questObjective ~= "" then
        return questObjective
    end

    local sourceName = LookupSource(cluster)
    if sourceName and sourceName ~= "" then
        return sourceName
    end

    local _, locale = LocaleData()
    if cluster and cluster.k == "turnin" then
        return STATIC_LABELS[locale].turnin
    end

    if cluster and cluster.o and cluster.o ~= "" then
        return cluster.o
    end

    local questLocale = quest and QuestLocaleData(quest.id)
    if questLocale and questLocale.d and questLocale.d[1] then
        return questLocale.d[1]
    end

    return nil
end

function Quests:GetLocalizedObjectives(quest, cluster)
    if cluster and cluster.parts then
        local objectives = {}
        local seen = {}
        for _, part in ipairs(cluster.parts) do
            local objective = self:GetLocalizedObjective(quest, part)
            if objective and objective ~= "" and not seen[objective] then
                seen[objective] = true
                objectives[#objectives + 1] = objective
            end
        end
        return objectives
    end

    local objective = self:GetLocalizedObjective(quest, cluster)
    if objective and objective ~= "" then
        return { objective }
    end
    return nil
end

function Quests:GetLocalizedCountText(kind, count)
    if not count or count <= 1 then
        return nil
    end

    local _, locale = LocaleData()
    local labels = STATIC_LABELS[locale]
    if kind == "nearby" then
        return count .. " " .. labels.nearby
    end
    return count .. " " .. labels.area
end
