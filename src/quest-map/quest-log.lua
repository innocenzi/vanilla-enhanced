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
            local objectiveOk, description = CallOptional(GetQuestLogLeaderBoard, objectiveIndex, index)
            if not objectiveOk then
                objectiveOk, description = CallOptional(GetQuestLogLeaderBoard, objectiveIndex)
            end
            if objectiveOk and description and description ~= "" then
                objectives[#objectives + 1] = description
            end
        end
    end

    if previousSelection and SelectQuestLogEntry then
        pcall(SelectQuestLogEntry, previousSelection)
    end

    return objectives
end

function QuestMap:GetQuestLogSnapshot()
    local quests = {}
    local questNumber = 0

    for index = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, isComplete, _, questId = GetQuestLogTitle(index)
        if title and not isHeader then
            questNumber = questNumber + 1
            if questId and questId > 0 then
                quests[#quests + 1] = {
                    id = questId,
                    index = index,
                    title = title,
                    number = questNumber,
                    isComplete = isComplete == 1 or isComplete == true,
                    objectives = GetQuestObjectives(index),
                }
            end
        end
    end

    return quests
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

    if QuestLogFrame and ShowUIPanel then
        ShowUIPanel(QuestLogFrame)
    elseif QuestLogFrame and not QuestLogFrame:IsShown() then
        QuestLogFrame:Show()
    elseif ToggleQuestLog then
        ToggleQuestLog()
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
