local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local defaults = {
    enabled = true,
    enableQuestTrackerClicks = true,
    keepQuestLogWithMap = true,
    scale = 1,
    opacity = 1,
    showMapMarkers = true,
    showAvailableQuests = false,
    onlyShowNearbyAvailableQuests = false,
    onlyShowAvailableQuestsAroundPlayerLevel = false,
    showCompletedMapObjectives = false,
    showCompletedTooltipObjectives = true,
}

function Quests:GetSettings()
    return VanillaEnhanced:GetModuleSettings("quests", defaults)
end

function Quests:SetEnabled(enabled)
    VanillaEnhanced:SetModuleEnabled("quests", enabled)

    if self.InvalidateQuestSnapshot then
        self:InvalidateQuestSnapshot()
    end
    if self.InvalidateAvailableQuestCache then
        self:InvalidateAvailableQuestCache()
    end

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
    if self.InvalidateQuestSnapshot then
        self:InvalidateQuestSnapshot()
    end
    if self.InvalidateAvailableQuestCache then
        self:InvalidateAvailableQuestCache()
    end

    if self.ApplyQuestLogWithMapSetting then
        self:ApplyQuestLogWithMapSetting()
    end
    self:Refresh()
    self:RefreshQuestTrackerClicks()
end
