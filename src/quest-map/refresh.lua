local VanillaEnhanced = _G.VanillaEnhanced
local QuestMap = VanillaEnhanced:GetModule("quest-map")

function QuestMap:Refresh()
    self.refreshQueued = false

    local settings = self:GetSettings()
    self:ClearPins()

    if not settings.enabled then
        self:RebuildUnitTooltipIndex({})
        return
    end

    if not VanillaEnhancedQuestMapDB or not VanillaEnhancedQuestMapDB.quests then
        self:RebuildUnitTooltipIndex({})
        return
    end

    local quests = self:GetQuestLogSnapshot()
    self:RebuildUnitTooltipIndex(quests)
    for _, quest in ipairs(quests) do
        local dbQuest = VanillaEnhancedQuestMapDB.quests[quest.id]
        if dbQuest and dbQuest.maps then
            local maps = quest.isComplete and dbQuest.turnins or dbQuest.maps
            maps = maps or dbQuest.maps
            for uiMapId, clusters in pairs(maps) do
                self:AddPins(uiMapId, clusters, quest)
            end
        end
    end
end

function QuestMap:QueueRefresh()
    if self.refreshQueued then
        return
    end
    self.refreshQueued = true
    C_Timer.After(0.15, function()
        QuestMap:Refresh()
    end)
end
