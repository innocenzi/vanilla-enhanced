local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

Quests.questTrackerButtons = Quests.questTrackerButtons or {}

local hookedQuestWatch = false

local function CleanText(text)
    if not text then
        return nil
    end

    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return text
end

local function GetWatchedQuestIdsByTitle()
    local watched = {}

    if not GetNumQuestWatches or not GetQuestIndexForWatch or not GetQuestLogTitle then
        return watched
    end

    for watchIndex = 1, GetNumQuestWatches() do
        local questIndex = GetQuestIndexForWatch(watchIndex)
        if questIndex then
            local title, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(questIndex)
            if title and not isHeader and questId and questId > 0 then
                watched[CleanText(title)] = questId
            end
        end
    end

    return watched
end

local function AcquireTrackerButton(index)
    local button = Quests.questTrackerButtons[index]
    if button then
        return button
    end

    button = CreateFrame("Button", nil, QuestWatchFrame or UIParent)
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", function(self)
        if self.questId then
            Quests:OpenQuestLogToQuest(self.questId)
        end
    end)
    Quests.questTrackerButtons[index] = button
    return button
end

local function HideUnusedButtons(firstUnusedIndex)
    for index = firstUnusedIndex, #Quests.questTrackerButtons do
        Quests.questTrackerButtons[index]:Hide()
        Quests.questTrackerButtons[index].questId = nil
    end
end

function Quests:RefreshQuestTrackerClicks()
    local settings = self:GetSettings()
    if not settings.enabled or settings.enableQuestTrackerClicks == false or not QuestWatchFrame then
        HideUnusedButtons(1)
        return
    end

    local watched = GetWatchedQuestIdsByTitle()
    local buttonIndex = 1
    local lineIndex = 1

    while true do
        local line = _G["QuestWatchLine" .. lineIndex]
        if not line then
            break
        end

        local questId = line:IsShown() and watched[CleanText(line:GetText())] or nil
        if questId then
            local button = AcquireTrackerButton(buttonIndex)
            button.questId = questId
            button:SetParent(QuestWatchFrame)
            button:SetFrameLevel((QuestWatchFrame:GetFrameLevel() or 0) + 10)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", line, "TOPLEFT", -2, 2)
            button:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 2, -2)
            button:Show()
            buttonIndex = buttonIndex + 1
        end

        lineIndex = lineIndex + 1
    end

    HideUnusedButtons(buttonIndex)
end

local function QueueRefresh()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            Quests:RefreshQuestTrackerClicks()
        end)
    else
        Quests:RefreshQuestTrackerClicks()
    end
end

local function HookQuestWatchUpdate()
    if hookedQuestWatch or not hooksecurefunc then
        return
    end

    if QuestWatch_Update then
        local ok = pcall(hooksecurefunc, "QuestWatch_Update", QueueRefresh)
        hookedQuestWatch = ok or hookedQuestWatch
    end
end

local eventFrame = CreateFrame("Frame")
local function RegisterEventIfAvailable(eventName)
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end

RegisterEventIfAvailable("PLAYER_LOGIN")
RegisterEventIfAvailable("QUEST_LOG_UPDATE")
RegisterEventIfAvailable("QUEST_WATCH_UPDATE")
RegisterEventIfAvailable("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function()
    HookQuestWatchUpdate()
    QueueRefresh()
end)

HookQuestWatchUpdate()
