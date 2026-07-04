local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local MODE_DISABLED = "disabled"
local MODE_OBJECTIVES = "objectives"
local MODE_QUEST_COMPLETE = "questComplete"
local MODE_OBJECTIVES_AND_QUEST_COMPLETE = "objectivesAndQuestComplete"
local DEBUG_SEND_TO_SELF_ONLY = false

local TEMPLATE_VALUES = {
    quest = true,
    objective = true,
    current = true,
    total = true,
}

local function ResolveAnnouncementLocale(settings)
    return Quests:NormalizeGroupQuestAnnouncementLocale(settings and settings.groupQuestAnnouncementsLanguage)
end

local function ShouldAnnounceObjectives(mode)
    return mode == MODE_OBJECTIVES or mode == MODE_OBJECTIVES_AND_QUEST_COMPLETE
end

local function ShouldAnnounceQuestComplete(mode)
    return mode == MODE_QUEST_COMPLETE or mode == MODE_OBJECTIVES_AND_QUEST_COMPLETE
end

local function IsInGroupCategory(category)
    if type(IsInGroup) ~= "function" then
        return false
    end

    if category ~= nil then
        local ok, inGroup = pcall(IsInGroup, category)
        return ok and inGroup == true
    end

    local ok, inGroup = pcall(IsInGroup)
    return ok and inGroup == true
end

local function IsInstanceGroup()
    local instanceCategory = _G.LE_PARTY_CATEGORY_INSTANCE
    if instanceCategory ~= nil then
        if IsInGroupCategory(instanceCategory) then
            return true
        end
    end

    return false
end

local function IsPartyOnly()
    if type(IsInRaid) == "function" and IsInRaid() then
        return false
    end
    if IsInstanceGroup() then
        return false
    end

    local homeCategory = _G.LE_PARTY_CATEGORY_HOME
    if homeCategory ~= nil and IsInGroupCategory(homeCategory) then
        return true
    end

    if IsInGroupCategory(nil) then
        return true
    end

    if type(GetNumSubgroupMembers) == "function" then
        local count = GetNumSubgroupMembers()
        if type(count) == "number" and count > 0 then
            return true
        end
    end

    if type(GetNumPartyMembers) == "function" then
        local count = GetNumPartyMembers()
        if type(count) == "number" and count > 0 then
            return true
        end
    end

    return type(UnitExists) == "function" and UnitExists("party1") == true
end

local function SendPartyMessage(message)
    if not message or message == "" then
        return
    end

    if DEBUG_SEND_TO_SELF_ONLY then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(message)
        end
        return
    end

    if not IsPartyOnly() then
        return
    end
    
    if type(SendChatMessage) == "function" then
        SendChatMessage(message, "PARTY")
    end
end

local function ParseObjectiveProgress(objectiveText)
    if not objectiveText then
        return nil, nil
    end

    local current, total = string.match(objectiveText, "(%d+)%s*/%s*(%d+)")
    current = tonumber(current)
    total = tonumber(total)
    if current and total then
        return current, total
    end
    return nil, nil
end

local function StripObjectiveProgress(objective)
    if not objective or objective == "" then
        return objective
    end
    return (string.gsub(objective, "%s*[:%-]?%s*%d+%s*/%s*%d+%s*$", ""))
end

local function AppendLocalizedObjectivesFromCluster(objectives, seen, quest, cluster, objectiveIndex, locale)
    if not cluster then
        return
    end

    if cluster.parts then
        for _, part in ipairs(cluster.parts) do
            AppendLocalizedObjectivesFromCluster(objectives, seen, quest, part, objectiveIndex, locale)
        end
        return
    end

    if Quests:GetClusterObjectiveIndex(cluster) ~= objectiveIndex then
        return
    end

    for _, objective in ipairs(Quests:GetLocalizedObjectives(quest, cluster, locale) or {}) do
        objective = StripObjectiveProgress(objective)
        if objective and objective ~= "" and not seen[objective] then
            seen[objective] = true
            objectives[#objectives + 1] = objective
        end
    end
end

local function GetObjectiveText(quest, dbQuest, objectiveIndex, locale)
    local liveObjective = quest and quest.objectives and quest.objectives[objectiveIndex] or nil

    if dbQuest and dbQuest.maps and objectiveIndex then
        local objectives = {}
        local seen = {}
        for _, clusters in pairs(dbQuest.maps) do
            for _, cluster in ipairs(clusters) do
                AppendLocalizedObjectivesFromCluster(objectives, seen, quest, cluster, objectiveIndex, locale)
            end
        end
        if #objectives > 0 then
            return table.concat(objectives, ", ")
        end
    end

    return StripObjectiveProgress(liveObjective)
end

local function GetTemplate(settings, locale, kind)
    local template
    if kind == "objective" then
        if locale == "frFR" then
            template = settings and settings.groupQuestObjectiveAnnouncementFormatFrFR
            return type(template) == "string" and string.find(template, "%S") and template
                or Quests:GetGroupQuestAnnouncementFormatDefault(locale, "objective")
        end
        template = settings and settings.groupQuestObjectiveAnnouncementFormatEnUS
        return type(template) == "string" and string.find(template, "%S") and template
            or Quests:GetGroupQuestAnnouncementFormatDefault(locale, "objective")
    end

    if locale == "frFR" then
        template = settings and settings.groupQuestCompleteAnnouncementFormatFrFR
        return type(template) == "string" and string.find(template, "%S") and template
            or Quests:GetGroupQuestAnnouncementFormatDefault(locale, "complete")
    end
    template = settings and settings.groupQuestCompleteAnnouncementFormatEnUS
    return type(template) == "string" and string.find(template, "%S") and template
        or Quests:GetGroupQuestAnnouncementFormatDefault(locale, "complete")
end

function Quests:RenderGroupQuestAnnouncementTemplate(template, values)
    if type(template) ~= "string" or not string.find(template, "%S") then
        return nil
    end

    local invalid = false
    local message = string.gsub(template, "{([%w_]+)}", function(name)
        if not TEMPLATE_VALUES[name] then
            invalid = true
            return ""
        end
        return values[name] or ""
    end)

    if invalid or string.find(message, "{.-}") or not string.find(message, "%S") then
        return nil
    end
    return message
end

local function BuildQuestState(quest)
    local state = {
        isComplete = quest and quest.isComplete == true,
        completedObjectives = {},
    }

    for objectiveIndex, completed in pairs(quest and quest.completedObjectives or {}) do
        if completed == true then
            state.completedObjectives[objectiveIndex] = true
        end
    end

    return state
end

local function BuildStateByQuestId(quests)
    local state = {}
    for _, quest in ipairs(quests or {}) do
        if quest.id then
            state[quest.id] = BuildQuestState(quest)
        end
    end
    return state
end

local function BuildAnnouncementValues(quest, dbQuest, objectiveIndex, locale)
    local liveObjective = quest and quest.objectives and quest.objectives[objectiveIndex] or nil
    local current, total = ParseObjectiveProgress(liveObjective)

    return {
        quest = Quests:GetLocalizedQuestTitle(quest, quest and quest.id, dbQuest and dbQuest.t, locale) or "",
        objective = objectiveIndex and (GetObjectiveText(quest, dbQuest, objectiveIndex, locale) or "") or "",
        current = current and tostring(current) or "",
        total = total and tostring(total) or "",
    }
end

local function AnnounceObjective(quest, dbQuest, objectiveIndex, locale, settings)
    local title = Quests:GetLocalizedQuestTitle(quest, quest and quest.id, dbQuest and dbQuest.t, locale)
    if title == "" then
        return
    end

    local template = GetTemplate(settings, locale, "objective")
    local message = Quests:RenderGroupQuestAnnouncementTemplate(
        template,
        BuildAnnouncementValues(quest, dbQuest, objectiveIndex, locale)
    )
    SendPartyMessage(message)
end

local function AnnounceQuestComplete(quest, dbQuest, locale, settings)
    local title = Quests:GetLocalizedQuestTitle(quest, quest and quest.id, dbQuest and dbQuest.t, locale)
    if title == "" then
        return
    end

    local template = GetTemplate(settings, locale, "complete")
    local message = Quests:RenderGroupQuestAnnouncementTemplate(
        template,
        BuildAnnouncementValues(quest, dbQuest, nil, locale)
    )
    SendPartyMessage(message)
end

function Quests:ProcessGroupQuestAnnouncements(quests, settings)
    local nextState = BuildStateByQuestId(quests)
    local mode = settings and settings.groupQuestAnnouncementsMode or MODE_DISABLED

    if not settings or settings.enabled == false or mode == MODE_DISABLED then
        self.groupQuestAnnouncementState = nextState
        return
    end

    local previousState = self.groupQuestAnnouncementState
    self.groupQuestAnnouncementState = nextState
    if not previousState then
        return
    end

    local announceObjectives = ShouldAnnounceObjectives(mode)
    local announceQuestComplete = ShouldAnnounceQuestComplete(mode)
    if not announceObjectives and not announceQuestComplete then
        return
    end

    local locale = ResolveAnnouncementLocale(settings)
    local questDB = VanillaEnhancedQuestsDB and VanillaEnhancedQuestsDB.quests or nil

    for _, quest in ipairs(quests or {}) do
        local questId = quest.id
        local previousQuestState = questId and previousState[questId] or nil
        if previousQuestState then
            local dbQuest = questDB and questDB[questId] or nil
            if announceObjectives then
                for objectiveIndex, completed in pairs(quest.completedObjectives or {}) do
                    if completed == true and previousQuestState.completedObjectives[objectiveIndex] ~= true then
                        AnnounceObjective(quest, dbQuest, objectiveIndex, locale, settings)
                    end
                end
            end

            if announceQuestComplete and quest.isComplete == true and previousQuestState.isComplete ~= true then
                AnnounceQuestComplete(quest, dbQuest, locale, settings)
            end
        end
    end
end
