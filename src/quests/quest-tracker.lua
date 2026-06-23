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

local function CaptureLineState(line)
    local red, green, blue, alpha
    if line.GetTextColor then
        red, green, blue, alpha = line:GetTextColor()
    end

    return {
        text = line.GetText and line:GetText() or "",
        shown = line.IsShown and line:IsShown() == true,
        red = red,
        green = green,
        blue = blue,
        alpha = alpha,
        height = line.GetHeight and line:GetHeight() or nil,
        lineAlpha = line.GetAlpha and line:GetAlpha() or nil,
    }
end

local function ApplyLineState(line, state)
    if not line then
        return
    end

    if not state or not state.shown then
        if line.SetText then
            line:SetText("")
        end
        line:Hide()
        return
    end

    if line.SetText then
        line:SetText(state.text or "")
    end
    if line.SetTextColor and state.red and state.green and state.blue then
        line:SetTextColor(state.red, state.green, state.blue, state.alpha or 1)
    end
    if line.SetAlpha and state.lineAlpha then
        line:SetAlpha(state.lineAlpha)
    end
    if line.SetHeight and state.height and state.height > 0 then
        line:SetHeight(state.height)
    end
    line:Show()
end

local function AppendLineStates(target, source)
    for _, state in ipairs(source or {}) do
        target[#target + 1] = state
    end
end

local function BuildQuestTrackerBlocks(lineStates, watched)
    local prefix = {}
    local blocks = {}
    local blocksByQuestId = {}
    local currentBlock

    for _, state in ipairs(lineStates) do
        local questId = watched[CleanText(state.text)]
        if questId then
            currentBlock = {
                questId = questId,
                lines = { state },
            }
            blocks[#blocks + 1] = currentBlock
            blocksByQuestId[questId] = blocksByQuestId[questId] or currentBlock
        elseif currentBlock then
            currentBlock.lines[#currentBlock.lines + 1] = state
        else
            prefix[#prefix + 1] = state
        end
    end

    return prefix, blocks, blocksByQuestId
end

local function ApplyAutoFollowQuestTrackerOrder(watched)
    local order = Quests.autoFollowQuestTrackerOrder
    if not order or #order <= 1 or not QuestWatchFrame then
        return false
    end

    local lines = {}
    local lineStates = {}
    local lineIndex = 1
    while true do
        local line = _G["QuestWatchLine" .. lineIndex]
        if not line then
            break
        end
        lines[#lines + 1] = line
        if line.IsShown and line:IsShown() then
            lineStates[#lineStates + 1] = CaptureLineState(line)
        end
        lineIndex = lineIndex + 1
    end

    if #lineStates == 0 then
        return false
    end

    local prefix, blocks, blocksByQuestId = BuildQuestTrackerBlocks(lineStates, watched)
    if #blocks <= 1 then
        return false
    end

    local orderedBlocks = {}
    local orderedQuestIds = {}
    for _, questId in ipairs(order) do
        local block = blocksByQuestId[questId]
        if block then
            orderedQuestIds[questId] = true
            orderedBlocks[#orderedBlocks + 1] = block
        end
    end

    if #orderedBlocks <= 1 then
        return false
    end

    local sortedLineStates = {}
    local orderedBlockIndex = 1
    AppendLineStates(sortedLineStates, prefix)
    for _, block in ipairs(blocks) do
        if orderedQuestIds[block.questId] then
            local sortedBlock = orderedBlocks[orderedBlockIndex]
            if sortedBlock then
                AppendLineStates(sortedLineStates, sortedBlock.lines)
            end
            orderedBlockIndex = orderedBlockIndex + 1
        else
            AppendLineStates(sortedLineStates, block.lines)
        end
    end

    local changed = false
    for index, state in ipairs(sortedLineStates) do
        if lineStates[index] ~= state then
            changed = true
            break
        end
    end
    if not changed then
        return false
    end

    for index, line in ipairs(lines) do
        ApplyLineState(line, sortedLineStates[index])
    end

    return true
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
    if not settings.enabled or not QuestWatchFrame then
        HideUnusedButtons(1)
        return
    end

    local watched = GetWatchedQuestIdsByTitle()
    ApplyAutoFollowQuestTrackerOrder(watched)

    if settings.enableQuestTrackerClicks == false then
        HideUnusedButtons(1)
        return
    end

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
