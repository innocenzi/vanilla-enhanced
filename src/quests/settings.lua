local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local defaults = {
    enabled = true,
    enableQuestTrackerClicks = true,
    keepQuestLogWithMap = true,
    scale = 1,
    opacity = 1,
    showMapMarkers = true,
    showCompletedMapObjectives = false,
    showCompletedTooltipObjectives = true,
    spreadOverlappingMarkers = true,
}

function Quests:GetSettings()
    return VanillaEnhanced:GetModuleSettings("quests", defaults)
end

function Quests:SetEnabled(enabled)
    VanillaEnhanced:SetModuleEnabled("quests", enabled)

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

function Quests:Update()
    if self.ApplyQuestLogWithMapSetting then
        self:ApplyQuestLogWithMapSetting()
    end
    if self.ResetMarkerSpread then
        self:ResetMarkerSpread()
    end
    self:Refresh()
    self:RefreshQuestTrackerClicks()
end
