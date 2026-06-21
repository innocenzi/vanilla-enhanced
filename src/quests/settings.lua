local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local AVAILABLE_QUEST_LEVEL_WINDOW_MIN = 0
local AVAILABLE_QUEST_LEVEL_WINDOW_MAX = 10
local DEFAULT_AVAILABLE_QUEST_LEVELS_BELOW_PLAYER = 5
local DEFAULT_AVAILABLE_QUEST_LEVELS_ABOVE_PLAYER = 3

local defaults = {
    enabled = true,
    enableQuestTrackerClicks = true,
    keepQuestLogWithMap = true,
    scale = 1,
    opacity = 1,
    showMapMarkers = true,
    showRepeatableQuests = true,
    showAvailableQuests = false,
    showMinimapObjectiveAreas = true,
    onlyShowNearbyAvailableQuests = false,
    onlyShowAvailableQuestsAroundPlayerLevel = false,
    availableQuestLevelsBelowPlayer = DEFAULT_AVAILABLE_QUEST_LEVELS_BELOW_PLAYER,
    availableQuestLevelsAbovePlayer = DEFAULT_AVAILABLE_QUEST_LEVELS_ABOVE_PLAYER,
    showCompletedMapObjectives = false,
    showCompletedTooltipObjectives = true,
}

local function ClampAvailableQuestLevelWindowSetting(value, defaultValue)
    value = tonumber(value) or defaultValue
    value = math.floor(value + 0.5)

    if value < AVAILABLE_QUEST_LEVEL_WINDOW_MIN then
        return AVAILABLE_QUEST_LEVEL_WINDOW_MIN
    end
    if value > AVAILABLE_QUEST_LEVEL_WINDOW_MAX then
        return AVAILABLE_QUEST_LEVEL_WINDOW_MAX
    end
    return value
end

function Quests:GetSettings()
    local settings = VanillaEnhanced:GetModuleSettings("quests", defaults)
    settings.availableQuestLevelsBelowPlayer = ClampAvailableQuestLevelWindowSetting(
        settings.availableQuestLevelsBelowPlayer,
        DEFAULT_AVAILABLE_QUEST_LEVELS_BELOW_PLAYER
    )
    settings.availableQuestLevelsAbovePlayer = ClampAvailableQuestLevelWindowSetting(
        settings.availableQuestLevelsAbovePlayer,
        DEFAULT_AVAILABLE_QUEST_LEVELS_ABOVE_PLAYER
    )
    return settings
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
