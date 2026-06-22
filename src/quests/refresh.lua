local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local QUEUED_REFRESH_DELAY_SECONDS = 0.15
local QUEUED_PROGRESS_REFRESH_DELAY_SECONDS = 0.50

Quests.questSnapshotDirty = Quests.questSnapshotDirty ~= false
Quests.refreshAfterCombat = Quests.refreshAfterCombat or false
Quests.refreshWorldMapAfterCombat = Quests.refreshWorldMapAfterCombat or false
Quests.refreshRequiresPinRebuild = Quests.refreshRequiresPinRebuild or false
Quests.refreshQueueToken = Quests.refreshQueueToken or 0

local function IsInCombatLockdown()
    return InCombatLockdown and InCombatLockdown()
end

local function AppendCompletedObjectivesSignature(parts, completedObjectives)
    if not completedObjectives then
        return
    end

    local completedObjectiveIndexes = {}
    for objectiveIndex, completed in pairs(completedObjectives) do
        if completed == true then
            completedObjectiveIndexes[#completedObjectiveIndexes + 1] = objectiveIndex
        end
    end
    table.sort(completedObjectiveIndexes)

    for _, objectiveIndex in ipairs(completedObjectiveIndexes) do
        parts[#parts + 1] = tostring(objectiveIndex)
        parts[#parts + 1] = ","
    end
end

local function BuildQuestPinStateSignature(quests)
    local parts = {}

    for _, quest in ipairs(quests or {}) do
        parts[#parts + 1] = tostring(quest.id or "")
        parts[#parts + 1] = ":"
        parts[#parts + 1] = tostring(quest.number or "")
        parts[#parts + 1] = quest.isComplete and ":complete:" or ":active:"
        AppendCompletedObjectivesSignature(parts, quest.completedObjectives)
        parts[#parts + 1] = ";"
    end

    return table.concat(parts)
end

local function BuildActiveQuestSignature(quests)
    local questIds = {}

    for _, quest in ipairs(quests or {}) do
        if quest.id then
            questIds[#questIds + 1] = quest.id
        end
    end
    table.sort(questIds)

    for index, questId in ipairs(questIds) do
        questIds[index] = tostring(questId)
    end

    return table.concat(questIds, ";")
end

function Quests:InvalidateQuestSnapshot()
    self.questSnapshotDirty = true
end

function Quests:GetCachedQuestLogSnapshot()
    if self.questSnapshotDirty or not self.questSnapshot then
        self.questSnapshot = self:GetQuestLogSnapshot()
        self.questSnapshotDirty = false
    end

    return self.questSnapshot
end

local function AddWorldMapPinsForQuests(self, quests, settings)
    if settings.showMapMarkers == false then
        return
    end

    for _, quest in ipairs(quests) do
        local dbQuest = VanillaEnhancedQuestsDB.quests[quest.id]
        if dbQuest and dbQuest.maps and self:ShouldShowQuestOnMaps(dbQuest, settings) then
            local maps = quest.isComplete and dbQuest.turnins or dbQuest.maps
            maps = maps or dbQuest.maps
            for uiMapId, clusters in pairs(maps) do
                self:AddWorldMapPins(uiMapId, clusters, quest)
            end
        end
    end
    if self.AddAvailableQuestPins then
        self:AddAvailableQuestPins(quests)
    end
    if self.RenderMarkerGroups then
        self:RenderMarkerGroups()
    end
    if self.UpdateSelectedQuestAreaFromLog then
        self:UpdateSelectedQuestAreaFromLog()
    elseif self.RefreshQuestAreaVisibility then
        self:RefreshQuestAreaVisibility()
    end
end

function Quests:Refresh()
    local requiresPinRebuild = self.refreshRequiresPinRebuild == true

    self.refreshQueueToken = (self.refreshQueueToken or 0) + 1
    self.refreshQueued = false
    self.refreshQueuedDelaySeconds = nil

    if IsInCombatLockdown() then
        if requiresPinRebuild then
            self.refreshRequiresPinRebuild = true
        end
        self.refreshAfterCombat = true
        return
    end
    self.refreshRequiresPinRebuild = false
    self.refreshAfterCombat = false
    self.refreshWorldMapAfterCombat = false

    local settings = self:GetSettings()
    local quests = self:GetCachedQuestLogSnapshot()
    local activeQuestSignature = BuildActiveQuestSignature(quests)
    local pinStateSignature = BuildQuestPinStateSignature(quests)

    if activeQuestSignature ~= self.availableQuestActiveSignature then
        self.availableQuestActiveSignature = activeQuestSignature
        if self.InvalidateAvailableQuestCache then
            self:InvalidateAvailableQuestCache()
        end
        requiresPinRebuild = true
    end

    if pinStateSignature ~= self.questPinStateSignature then
        self.questPinStateSignature = pinStateSignature
        requiresPinRebuild = true
    end

    if settings.enabled and VanillaEnhancedQuestsDB and VanillaEnhancedQuestsDB.quests then
        self:RebuildUnitTooltipIndex(quests)
        if not requiresPinRebuild and self.RefreshQuestPinTooltipData then
            self:RefreshQuestPinTooltipData(quests)
        end
    else
        self:RebuildUnitTooltipIndex({})
        requiresPinRebuild = true
    end

    if self.RefreshSelectedQuestDirection then
        self:RefreshSelectedQuestDirection(quests, settings)
    end

    if not requiresPinRebuild then
        return
    end

    self:ClearPins()
    if self.ClearMapExplorationCache then
        self:ClearMapExplorationCache()
    end

    if not settings.enabled then
        return
    end

    if not VanillaEnhancedQuestsDB or not VanillaEnhancedQuestsDB.quests then
        return
    end

    if settings.showMapMarkers == false then
        return
    end

    for _, quest in ipairs(quests) do
        local dbQuest = VanillaEnhancedQuestsDB.quests[quest.id]
        if dbQuest and dbQuest.maps and self:ShouldShowQuestOnMaps(dbQuest, settings) then
            local maps = quest.isComplete and dbQuest.turnins or dbQuest.maps
            maps = maps or dbQuest.maps
            for uiMapId, clusters in pairs(maps) do
                self:AddPins(uiMapId, clusters, quest)
            end
        end
    end
    if self.AddAvailableQuestPins then
        self:AddAvailableQuestPins(quests)
    end
    if self.RenderMarkerGroups then
        self:RenderMarkerGroups()
    end
    if self.UpdateSelectedQuestAreaFromLog then
        self:UpdateSelectedQuestAreaFromLog()
    elseif self.RefreshQuestAreaVisibility then
        self:RefreshQuestAreaVisibility()
    end
end

function Quests:RefreshWorldMapPins()
    if IsInCombatLockdown() then
        if not self.refreshAfterCombat then
            self.refreshWorldMapAfterCombat = true
        end
        return
    end
    self.refreshWorldMapAfterCombat = false

    local settings = self:GetSettings()
    self:ClearWorldMapPins()
    if self.ClearMapExplorationCache then
        self:ClearMapExplorationCache()
    end

    if not settings.enabled then
        return
    end

    if not VanillaEnhancedQuestsDB or not VanillaEnhancedQuestsDB.quests then
        return
    end

    AddWorldMapPinsForQuests(self, self:GetCachedQuestLogSnapshot(), settings)
end

function Quests:QueueRefresh()
    self.refreshRequiresPinRebuild = true
    self:QueueQuestProgressRefresh(QUEUED_REFRESH_DELAY_SECONDS)
end

function Quests:QueueQuestProgressRefresh(delaySeconds)
    delaySeconds = delaySeconds or QUEUED_PROGRESS_REFRESH_DELAY_SECONDS

    if self.refreshQueued then
        if C_Timer and C_Timer.After and delaySeconds < (self.refreshQueuedDelaySeconds or delaySeconds) then
            self.refreshQueuedDelaySeconds = delaySeconds
            self.refreshQueueToken = (self.refreshQueueToken or 0) + 1
            local token = self.refreshQueueToken

            C_Timer.After(delaySeconds, function()
                if Quests.refreshQueueToken ~= token then
                    return
                end
                Quests:Refresh()
            end)
        end
        return
    end
    if IsInCombatLockdown() then
        self.refreshAfterCombat = true
        return
    end
    self.refreshQueued = true
    self.refreshQueuedDelaySeconds = delaySeconds
    if C_Timer and C_Timer.After then
        self.refreshQueueToken = (self.refreshQueueToken or 0) + 1
        local token = self.refreshQueueToken

        C_Timer.After(delaySeconds, function()
            if Quests.refreshQueueToken ~= token then
                return
            end
            Quests:Refresh()
        end)
        return
    end

    self:Refresh()
end

function Quests:RunPendingRefreshAfterCombat()
    if self.refreshAfterCombat then
        self.refreshAfterCombat = false
        self.refreshWorldMapAfterCombat = false
        self:QueueQuestProgressRefresh(
            self.refreshRequiresPinRebuild and QUEUED_REFRESH_DELAY_SECONDS or QUEUED_PROGRESS_REFRESH_DELAY_SECONDS
        )
        return
    end

    if self.refreshWorldMapAfterCombat then
        self.refreshWorldMapAfterCombat = false
        self:RefreshWorldMapPins()
    end
end
