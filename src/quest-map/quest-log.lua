local VanillaEnhanced = _G.VanillaEnhanced
local QuestMap = VanillaEnhanced:GetModule("quest-map")

local function CallOptional(func, ...)
    if not func then
        return false, nil
    end
    return pcall(func, ...)
end

local function GetQuestObjectives(index)
    local objectives = {}
    local completedByIndex = {}
    local previousSelection

    if GetQuestLogSelection then
        local ok, selected = pcall(GetQuestLogSelection)
        if ok then
            previousSelection = selected
        end
    end

    if SelectQuestLogEntry then
        pcall(SelectQuestLogEntry, index)
    end

    local ok, count = CallOptional(GetNumQuestLeaderBoards, index)
    if not ok or type(count) ~= "number" then
        ok, count = CallOptional(GetNumQuestLeaderBoards)
    end

    if ok and type(count) == "number" then
        for objectiveIndex = 1, count do
            local objectiveOk, description, _, isComplete = CallOptional(GetQuestLogLeaderBoard, objectiveIndex, index)
            if not objectiveOk then
                objectiveOk, description, _, isComplete = CallOptional(GetQuestLogLeaderBoard, objectiveIndex)
            end
            if objectiveOk and description and description ~= "" then
                objectives[#objectives + 1] = description
                if isComplete ~= nil then
                    completedByIndex[objectiveIndex] = isComplete == true or isComplete == 1
                else
                    local current, total = string.match(description, "(%d+)%s*/%s*(%d+)")
                    current = tonumber(current)
                    total = tonumber(total)
                    if current and total and total > 0 then
                        completedByIndex[objectiveIndex] = current >= total
                    end
                end
            end
        end
    end

    if previousSelection and SelectQuestLogEntry then
        pcall(SelectQuestLogEntry, previousSelection)
    end

    return objectives, completedByIndex
end

function QuestMap:GetQuestLogSnapshot()
    local quests = {}
    local questNumber = 0

    for index = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, isComplete, _, questId = GetQuestLogTitle(index)
        if title and not isHeader then
            questNumber = questNumber + 1
            if questId and questId > 0 then
                local objectives, completedObjectives = GetQuestObjectives(index)
                quests[#quests + 1] = {
                    id = questId,
                    index = index,
                    title = title,
                    number = questNumber,
                    isComplete = isComplete == 1 or isComplete == true,
                    objectives = objectives,
                    completedObjectives = completedObjectives,
                }
            end
        end
    end

    return quests
end

function QuestMap:ShouldShowObjectiveCluster(quest, cluster, surface)
    if not quest or not cluster then
        return true
    end

    local settings = self:GetSettings()
    if surface == "tooltip" and settings.showCompletedTooltipObjectives then
        return true
    end
    if surface ~= "tooltip" and settings.showCompletedMapObjectives then
        return true
    end

    local objectiveIndex = cluster.oi
    if not objectiveIndex or not quest.completedObjectives then
        return true
    end

    return quest.completedObjectives[objectiveIndex] ~= true
end

local function FindQuestLogIndex(questId)
    if not questId then
        return nil
    end

    for index = 1, GetNumQuestLogEntries() do
        local _, _, _, isHeader, _, _, _, currentQuestId = GetQuestLogTitle(index)
        if not isHeader and currentQuestId == questId then
            return index
        end
    end
    return nil
end

function QuestMap:OpenQuestLogToQuest(questId)
    local index = FindQuestLogIndex(questId)
    if not index then
        return
    end

    local openedWithMap = QuestMap.IsQuestLogWithMapEnabled
        and QuestMap:IsQuestLogWithMapEnabled()
        and WorldMapFrame
        and WorldMapFrame.IsShown
        and WorldMapFrame:IsShown()
        and QuestMap.ShowQuestLogWithMap
        and QuestMap:ShowQuestLogWithMap()

    if not openedWithMap then
        if QuestLogFrame and ShowUIPanel then
            ShowUIPanel(QuestLogFrame)
        elseif QuestLogFrame and not QuestLogFrame:IsShown() then
            QuestLogFrame:Show()
        elseif ToggleQuestLog then
            ToggleQuestLog()
        end
    end

    if QuestLog_SetSelection then
        pcall(QuestLog_SetSelection, index)
    end
    if SelectQuestLogEntry then
        pcall(SelectQuestLogEntry, index)
    end
    if QuestLog_Update then
        pcall(QuestLog_Update)
    end
end
