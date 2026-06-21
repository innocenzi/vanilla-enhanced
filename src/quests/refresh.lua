local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

Quests.questSnapshotDirty = Quests.questSnapshotDirty ~= false
Quests.refreshAfterCombat = Quests.refreshAfterCombat or false
Quests.refreshWorldMapAfterCombat = Quests.refreshWorldMapAfterCombat or false

local function IsInCombatLockdown()
    return InCombatLockdown and InCombatLockdown()
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
        if dbQuest and dbQuest.maps and self:ShouldShowRepeatableQuestOnMaps(dbQuest, settings) then
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
    self.refreshQueued = false

    if IsInCombatLockdown() then
        self.refreshAfterCombat = true
        return
    end
    self.refreshAfterCombat = false
    self.refreshWorldMapAfterCombat = false

    local settings = self:GetSettings()
    self:ClearPins()
    if self.ClearMapExplorationCache then
        self:ClearMapExplorationCache()
    end

    if not settings.enabled then
        self:RebuildUnitTooltipIndex({})
        return
    end

    if not VanillaEnhancedQuestsDB or not VanillaEnhancedQuestsDB.quests then
        self:RebuildUnitTooltipIndex({})
        return
    end

    local quests = self:GetCachedQuestLogSnapshot()
    self:RebuildUnitTooltipIndex(quests)

    if settings.showMapMarkers == false then
        return
    end

    for _, quest in ipairs(quests) do
        local dbQuest = VanillaEnhancedQuestsDB.quests[quest.id]
        if dbQuest and dbQuest.maps and self:ShouldShowRepeatableQuestOnMaps(dbQuest, settings) then
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
    if self.refreshQueued then
        return
    end
    if IsInCombatLockdown() then
        self.refreshAfterCombat = true
        return
    end
    self.refreshQueued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, function()
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
        self:QueueRefresh()
        return
    end

    if self.refreshWorldMapAfterCombat then
        self.refreshWorldMapAfterCombat = false
        self:RefreshWorldMapPins()
    end
end
