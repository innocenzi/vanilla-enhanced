local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local function T(key, vars, locale)
    if locale and VanillaEnhanced.TForLocale then
        return VanillaEnhanced:TForLocale(locale, key, vars)
    end
    return VanillaEnhanced:T(key, vars)
end

local localeDataCache = {}

local function NormalizeLocale(locale)
    if locale then
        return locale == "frFR" and "frFR" or "enUS"
    end
    return VanillaEnhanced:GetLocaleKey()
end

local function LocaleData(locale)
    locale = NormalizeLocale(locale)
    if localeDataCache[locale] ~= nil then
        return localeDataCache[locale], locale
    end

    local localeData
    if locale == "frFR" and VanillaEnhancedQuestsLocaleDB and VanillaEnhancedQuestsLocaleDB.frFR then
        localeData = VanillaEnhancedQuestsLocaleDB.frFR
    end

    localeDataCache[locale] = localeData or false
    return localeData, locale
end

local function QuestLocaleData(questId, locale)
    local localeData = LocaleData(locale)
    return localeData and localeData.quests and localeData.quests[questId] or nil
end

local function LookupSource(cluster, locale)
    local localeData = LocaleData(locale)
    local sourceType = Quests:GetClusterSourceType(cluster)
    local sourceId = Quests:GetClusterSourceId(cluster)
    if not localeData or not cluster or not sourceType or not sourceId then
        return nil
    end

    if sourceType == "npc" and localeData.npcs then
        return localeData.npcs[sourceId]
    end
    if sourceType == "object" and localeData.objects then
        return localeData.objects[sourceId]
    end
    if sourceType == "item" and localeData.items then
        return localeData.items[sourceId]
    end
    return nil
end

local function LookupNpc(npcId, locale)
    local localeData = LocaleData(locale)
    return localeData and localeData.npcs and localeData.npcs[npcId] or nil
end

local function ObjectiveFromQuestLog(quest, cluster)
    local objectiveIndex = Quests:GetClusterObjectiveIndex(cluster)
    if not quest or not cluster or not objectiveIndex or not quest.objectives then
        return nil
    end
    return quest.objectives[objectiveIndex]
end

local function ObjectiveFromQuestLocale(quest, cluster, locale)
    if not quest or not cluster or Quests:GetClusterKind(cluster) ~= "event" then
        return nil
    end
    if Quests:GetClusterSourceType(cluster) or Quests:GetClusterSourceId(cluster) then
        return nil
    end

    local questLocale = QuestLocaleData(quest.id, locale)
    return questLocale and questLocale.d and questLocale.d[1] or nil
end

function Quests:GetLocalizedQuestTitle(quest, questId, fallback, locale)
    if locale == "frFR" then
        local questLocale = QuestLocaleData(questId, locale)
        if questLocale and questLocale.t and questLocale.t ~= "" then
            return questLocale.t
        end
    elseif locale == "enUS" and fallback and fallback ~= "" then
        return fallback
    end

    if quest and quest.title and quest.title ~= "" then
        return quest.title
    end

    local questLocale = QuestLocaleData(questId, locale)
    if questLocale and questLocale.t and questLocale.t ~= "" then
        return questLocale.t
    end

    return fallback or ""
end

function Quests:GetLocalizedSourceName(cluster, locale)
    local sourceName = LookupSource(cluster, locale)
    if sourceName and sourceName ~= "" then
        return sourceName
    end

    local objective = Quests:GetClusterObjective(cluster)
    if objective and objective ~= "" then
        return objective
    end

    return nil
end

function Quests:GetLocalizedNpcName(npcId, locale)
    return LookupNpc(npcId, locale)
end

function Quests:GetLocalizedObjective(quest, cluster, locale)
    if not locale then
        local questObjective = ObjectiveFromQuestLog(quest, cluster)
        if questObjective and questObjective ~= "" then
            return questObjective
        end
    end

    local normalizedLocale = NormalizeLocale(locale)
    local sourceName = LookupSource(cluster, normalizedLocale)
    if sourceName and sourceName ~= "" then
        return sourceName
    end

    if Quests:GetClusterKind(cluster) == "turnin" then
        return T("quests.static.turnin", nil, normalizedLocale)
    end

    if normalizedLocale ~= "frFR" then
        local objective = Quests:GetClusterObjective(cluster)
        if objective and objective ~= "" then
            return objective
        end
    end

    local localeObjective = ObjectiveFromQuestLocale(quest, cluster, normalizedLocale)
    if localeObjective and localeObjective ~= "" then
        return localeObjective
    end

    local questLocale = quest and QuestLocaleData(quest.id, normalizedLocale)
    if questLocale and questLocale.d and questLocale.d[1] then
        return questLocale.d[1]
    end

    local questObjective = ObjectiveFromQuestLog(quest, cluster)
    if questObjective and questObjective ~= "" then
        return questObjective
    end

    local objective = Quests:GetClusterObjective(cluster)
    if objective and objective ~= "" then
        return objective
    end

    return nil
end

function Quests:GetLocalizedObjectives(quest, cluster, locale)
    if cluster and cluster.parts then
        local objectives = {}
        local seen = {}
        for _, part in ipairs(cluster.parts) do
            local objective = self:GetLocalizedObjective(quest, part, locale)
            if objective and objective ~= "" and not seen[objective] then
                seen[objective] = true
                objectives[#objectives + 1] = objective
            end
        end
        return objectives
    end

    local objective = self:GetLocalizedObjective(quest, cluster, locale)
    if objective and objective ~= "" then
        return { objective }
    end
    return nil
end

function Quests:GetLocalizedCountText(kind, count)
    if not count or count <= 1 then
        return nil
    end

    if kind == "nearby" then
        return count .. " " .. T("quests.static.nearbyObjectives")
    end
    return count .. " " .. T("quests.static.areaObjectives")
end
