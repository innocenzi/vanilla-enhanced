local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

function Quests:Refresh()
    self.refreshQueued = false

    local settings = self:GetSettings()
    self:ClearPins()

    if not settings.enabled then
        self:RebuildUnitTooltipIndex({})
        return
    end

    if not VanillaEnhancedQuestsDB or not VanillaEnhancedQuestsDB.quests then
        self:RebuildUnitTooltipIndex({})
        return
    end

    local quests = self:GetQuestLogSnapshot()
    self:RebuildUnitTooltipIndex(quests)

    if settings.showMapMarkers == false then
        return
    end

    for _, quest in ipairs(quests) do
        local dbQuest = VanillaEnhancedQuestsDB.quests[quest.id]
        if dbQuest and dbQuest.maps then
            local maps = quest.isComplete and dbQuest.turnins or dbQuest.maps
            maps = maps or dbQuest.maps
            for uiMapId, clusters in pairs(maps) do
                self:AddPins(uiMapId, clusters, quest)
            end
        end
    end
    if self.UpdateSelectedQuestAreaFromLog then
        self:UpdateSelectedQuestAreaFromLog()
    elseif self.RefreshQuestAreaVisibility then
        self:RefreshQuestAreaVisibility()
    end
end

function Quests:QueueRefresh()
    if self.refreshQueued then
        return
    end
    self.refreshQueued = true
    C_Timer.After(0.15, function()
        Quests:Refresh()
    end)
end
