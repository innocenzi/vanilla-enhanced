local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local AVAILABLE_QUEST_LEVEL_WINDOW_MIN = 0
local AVAILABLE_QUEST_LEVEL_WINDOW_MAX = 10
local DEFAULT_AVAILABLE_QUEST_LEVELS_BELOW_PLAYER = 5
local DEFAULT_AVAILABLE_QUEST_LEVELS_ABOVE_PLAYER = 3
local DEFAULT_AUTO_FOLLOW_QUESTS_MODE = "disabled"
local DEFAULT_AUTO_FOLLOW_QUESTS_BEHAVIOR = "replace-distant"
local DEFAULT_AUTO_FOLLOW_QUESTS_RANGE = "nearby"

local AUTO_FOLLOW_QUESTS_MODES = {
    disabled = true,
    movement = true,
    zone = true,
}

local AUTO_FOLLOW_QUESTS_BEHAVIORS = {
    ["replace-distant"] = true,
    ["auto-only"] = true,
    ["fill-empty"] = true,
}

local AUTO_FOLLOW_QUESTS_RANGES = {
    close = true,
    nearby = true,
    wide = true,
}

local defaults = {
    enabled = true,
    enableQuestTrackerClicks = true,
    autoFollowQuestsMode = DEFAULT_AUTO_FOLLOW_QUESTS_MODE,
    autoFollowQuestsBehavior = DEFAULT_AUTO_FOLLOW_QUESTS_BEHAVIOR,
    autoFollowQuestsRange = DEFAULT_AUTO_FOLLOW_QUESTS_RANGE,
    keepQuestLogWithMap = true,
    scale = 1,
    opacity = 1,
    showMapMarkers = true,
    hideMapMarkersInFogOfWar = true,
    showRepeatableQuests = true,
    showAvailableQuests = false,
    showMinimapObjectiveAreas = true,
    dimMinimapMarkersOnOtherFloors = true,
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
    if not AUTO_FOLLOW_QUESTS_MODES[settings.autoFollowQuestsMode] then
        settings.autoFollowQuestsMode = DEFAULT_AUTO_FOLLOW_QUESTS_MODE
    end
    if not AUTO_FOLLOW_QUESTS_BEHAVIORS[settings.autoFollowQuestsBehavior] then
        settings.autoFollowQuestsBehavior = DEFAULT_AUTO_FOLLOW_QUESTS_BEHAVIOR
    end
    if not AUTO_FOLLOW_QUESTS_RANGES[settings.autoFollowQuestsRange] then
        settings.autoFollowQuestsRange = DEFAULT_AUTO_FOLLOW_QUESTS_RANGE
    end
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
    if self.ClearAutoFollowQuestWatches then
        self:ClearAutoFollowQuestWatches()
    end

    if enabled then
        self.refreshRequiresPinRebuild = true
        self:Refresh()
        self:RefreshQuestTrackerClicks()
        if self.QueueAutoFollowQuestUpdate then
            self:QueueAutoFollowQuestUpdate("settings", true)
        end
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
    self.refreshRequiresPinRebuild = true
    self:Refresh()
    self:RefreshQuestTrackerClicks()
    if self.QueueAutoFollowQuestUpdate then
        self:QueueAutoFollowQuestUpdate("settings", true)
    end
end
