local VanillaEnhanced = _G.VanillaEnhanced
local QuestMap = VanillaEnhanced:GetModule("quest-map")

local defaults = {
    enabled = true,
    keepQuestLogWithMap = true,
    scale = 1,
    opacity = 1,
    showCompletedMapObjectives = false,
    showCompletedTooltipObjectives = true,
}

function QuestMap:GetSettings()
    local addonSettings = VanillaEnhanced:GetSettings()
    local moduleSettings = addonSettings.modules and addonSettings.modules["quest-map"]
    local oldShowCompletedObjectives = type(moduleSettings) == "table" and moduleSettings.showCompletedObjectives
    local settings = VanillaEnhanced:GetModuleSettings("quest-map", defaults)

    if not settings.completedObjectiveVisibilitySplitMigrated then
        if oldShowCompletedObjectives ~= nil then
            settings.showCompletedMapObjectives = oldShowCompletedObjectives == true
            settings.showCompletedTooltipObjectives = oldShowCompletedObjectives == true
        end
        settings.showCompletedObjectives = nil
        settings.completedObjectiveVisibilitySplitMigrated = true
    end

    return settings
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
