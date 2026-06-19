local VanillaEnhanced = _G.VanillaEnhanced
local QuestMap = VanillaEnhanced:GetModule("quest-map")

local defaults = {
    enabled = true,
    scale = 1,
    opacity = 1,
    showCompletedObjectives = true,
}

function QuestMap:GetSettings()
    return VanillaEnhanced:GetModuleSettings("quest-map", defaults)
end

function QuestMap:SetEnabled(enabled)
    VanillaEnhanced:SetModuleEnabled("quest-map", enabled)

    if enabled then
        self:Refresh()
        self:RefreshQuestTrackerClicks()
        return
    end

    self:ClearPins()
    self:RebuildUnitTooltipIndex({})
    self:RefreshQuestTrackerClicks()
end
