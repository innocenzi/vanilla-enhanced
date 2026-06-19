local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

Quests.suppressQuestLogSelectionSync = Quests.suppressQuestLogSelectionSync or 0

local function CallOptional(func, ...)
    if not func then
        return false, nil
    end
    return pcall(func, ...)
end

local function IsQuestLogShown()
    return QuestLogFrame and QuestLogFrame.IsShown and QuestLogFrame:IsShown()
end

local function HookFrameScript(frame, scriptName, handler)
    if not frame or not handler then
        return false
    end

    if frame.HookScript then
        frame:HookScript(scriptName, handler)
        return true
    end

    local previous = frame:GetScript(scriptName)
    frame:SetScript(scriptName, function(...)
        if previous then
            previous(...)
        end
        handler(...)
    end)
    return true
end

local function QueueSelectedQuestRefresh()
    if (Quests.suppressQuestLogSelectionSync or 0) > 0 then
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            Quests:UpdateSelectedQuestAreaFromLog()
        end)
    else
        Quests:UpdateSelectedQuestAreaFromLog()
    end
end

local function PushSelectionSuppression()
    Quests.suppressQuestLogSelectionSync = (Quests.suppressQuestLogSelectionSync or 0) + 1
end

local function PopSelectionSuppression()
    Quests.suppressQuestLogSelectionSync = math.max((Quests.suppressQuestLogSelectionSync or 1) - 1, 0)
end

local function GetSelectedQuestId()
    if not IsQuestLogShown() or not GetQuestLogSelection or not GetQuestLogTitle then
        return nil
    end

    local ok, selected = pcall(GetQuestLogSelection)
    if not ok or not selected then
        return nil
    end

    local title, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(selected)
    if title and not isHeader and questId and questId > 0 then
        return questId
    end
    return nil
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
        PushSelectionSuppression()
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
    if SelectQuestLogEntry then
        PopSelectionSuppression()
    end

    return objectives, completedByIndex
end

function Quests:GetQuestLogSnapshot()
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

function Quests:ShouldShowObjectiveCluster(quest, cluster, surface)
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

function Quests:OpenQuestLogToQuest(questId)
    local index = FindQuestLogIndex(questId)
    if not index then
        return
    end

    local openedWithMap = Quests.IsQuestLogWithMapEnabled
        and Quests:IsQuestLogWithMapEnabled()
        and WorldMapFrame
        and WorldMapFrame.IsShown
        and WorldMapFrame:IsShown()
        and Quests.ShowQuestLogWithMap
        and Quests:ShowQuestLogWithMap()

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
    self:UpdateSelectedQuestAreaFromLog()
end

function Quests:UpdateSelectedQuestAreaFromLog()
    if (self.suppressQuestLogSelectionSync or 0) > 0 then
        return
    end
    if not self.SetSelectedQuestAreaQuest then
        return
    end

    self:SetSelectedQuestAreaQuest(GetSelectedQuestId())
end

function Quests:ClearSelectedQuestAreaQuest()
    if self.SetSelectedQuestAreaQuest then
        self:SetSelectedQuestAreaQuest(nil)
    else
        self.selectedQuestAreaQuestId = nil
    end
end

function Quests:HookQuestLogSelection()
    local hookedFunction = false

    if not self.questLogSelectionFunctionHooksInstalled and type(hooksecurefunc) == "function" then
        if QuestLog_SetSelection then
            local ok = pcall(hooksecurefunc, "QuestLog_SetSelection", QueueSelectedQuestRefresh)
            hookedFunction = hookedFunction or ok
        end
        if SelectQuestLogEntry then
            local ok = pcall(hooksecurefunc, "SelectQuestLogEntry", QueueSelectedQuestRefresh)
            hookedFunction = hookedFunction or ok
        end
        self.questLogSelectionFunctionHooksInstalled = hookedFunction
    end

    if not self.questLogSelectionFrameHooksInstalled and QuestLogFrame then
        local hookedShow = HookFrameScript(QuestLogFrame, "OnShow", QueueSelectedQuestRefresh)
        local hookedHide = HookFrameScript(QuestLogFrame, "OnHide", function()
            Quests:ClearSelectedQuestAreaQuest()
        end)
        self.questLogSelectionFrameHooksInstalled = hookedShow or hookedHide
    end

    self:UpdateSelectedQuestAreaFromLog()
end

Quests:HookQuestLogSelection()
