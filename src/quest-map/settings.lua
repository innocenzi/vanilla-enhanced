local VanillaEnhanced = _G.VanillaEnhanced
local QuestMap = VanillaEnhanced:GetModule("quest-map")

local defaults = {
    enabled = true,
    keepQuestLogWithMap = true,
    scale = 1,
    opacity = 1,
    showCompletedObjectives = true,
}

function QuestMap:GetSettings()
    return VanillaEnhanced:GetModuleSettings("quest-map", defaults)
end

function QuestMap:SetEnabled(enabled)
    VanillaEnhanced:SetModuleEnabled("quest-map", enabled)

    if self.ApplyQuestLogWithMapSetting then
        self:ApplyQuestLogWithMapSetting()
    end

    if enabled then
        self:Refresh()
        self:RefreshQuestTrackerClicks()
        return
    end

    self:ClearPins()
    self:RebuildUnitTooltipIndex({})
    self:RefreshQuestTrackerClicks()
end

function QuestMap:Update()
    if self.ApplyQuestLogWithMapSetting then
        self:ApplyQuestLogWithMapSetting()
    end
    self:Refresh()
end
