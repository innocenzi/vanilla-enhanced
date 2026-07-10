local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local AVAILABLE_QUEST_LEVEL_WINDOW_MIN = 0
local AVAILABLE_QUEST_LEVEL_WINDOW_MAX = 10
local DEFAULT_AVAILABLE_QUEST_LEVELS_BELOW_PLAYER = 5
local DEFAULT_AVAILABLE_QUEST_LEVELS_ABOVE_PLAYER = 3
local DEFAULT_AUTO_FOLLOW_QUESTS_MODE = "disabled"
local DEFAULT_AUTO_FOLLOW_QUESTS_RANGE = "nearby"
local DEFAULT_OBJECTIVE_LOCATION_DISPLAY_MODE = "area"
local DEFAULT_GROUP_QUEST_ANNOUNCEMENTS_MODE = "disabled"
local DEFAULT_GROUP_QUEST_ANNOUNCEMENTS_LANGUAGE = "enUS"

local GROUP_QUEST_ANNOUNCEMENT_FORMAT_DEFAULTS = {
    enUS = {
        objective = "[Vanilla Enhanced] I am done with \"{objective}\" ({current}/{total})",
        complete = "[Vanilla Enhanced] I completed quest \"{quest}\"",
    },
    frFR = {
        objective = "[Vanilla Enhanced] J'ai fini \"{objective}\" ({current}/{total})",
        complete = "[Vanilla Enhanced] J'ai terminé la quête \"{quest}\"",
    },
}

local AUTO_FOLLOW_QUESTS_MODES = {
    disabled = true,
    movement = true,
    zone = true,
}

local AUTO_FOLLOW_QUESTS_RANGES = {
    close = true,
    nearby = true,
    wide = true,
}

local OBJECTIVE_LOCATION_DISPLAY_MODES = {
    area = true,
    points = true,
}

local GROUP_QUEST_ANNOUNCEMENTS_MODES = {
    disabled = true,
    objectives = true,
    questComplete = true,
    objectivesAndQuestComplete = true,
}

local GROUP_QUEST_ANNOUNCEMENTS_LANGUAGES = {
    auto = true,
    enUS = true,
    frFR = true,
}

function Quests:NormalizeGroupQuestAnnouncementLocale(locale)
    return VanillaEnhanced:NormalizeOutgoingMessageLocale(locale)
end

function Quests:GetGroupQuestAnnouncementFormatDefault(locale, kind)
    locale = self:NormalizeGroupQuestAnnouncementLocale(locale)
    kind = kind == "complete" and "complete" or "objective"

    local defaultsForLocale = GROUP_QUEST_ANNOUNCEMENT_FORMAT_DEFAULTS[locale]
        or GROUP_QUEST_ANNOUNCEMENT_FORMAT_DEFAULTS.enUS
    return defaultsForLocale[kind] or GROUP_QUEST_ANNOUNCEMENT_FORMAT_DEFAULTS.enUS[kind]
end

local defaults = {
    enabled = true,
    enableQuestTrackerClicks = true,
    enableQuestTrackerItemButtons = true,
    autoFollowQuestsMode = DEFAULT_AUTO_FOLLOW_QUESTS_MODE,
    autoFollowQuestsRange = DEFAULT_AUTO_FOLLOW_QUESTS_RANGE,
    keepQuestLogWithMap = true,
    scale = 1,
    opacity = 1,
    showMapMarkers = true,
    showQuestObjectiveMarkersInFogOfWar = false,
    showAvailableQuestMarkersInFogOfWar = false,
    showRepeatableQuests = false,
    showReputationQuests = false,
    showAvailableQuests = false,
    showSelectedQuestDirection = false,
    showDistantMinimapQuestMarkers = false,
    showIncompleteDungeonTurnins = false,
    showMinimapObjectiveAreas = true,
    objectiveLocationDisplayMode = DEFAULT_OBJECTIVE_LOCATION_DISPLAY_MODE,
    onlyShowNearbyAvailableQuests = false,
    onlyShowAvailableQuestsAroundPlayerLevel = false,
    availableQuestLevelsBelowPlayer = DEFAULT_AVAILABLE_QUEST_LEVELS_BELOW_PLAYER,
    availableQuestLevelsAbovePlayer = DEFAULT_AVAILABLE_QUEST_LEVELS_ABOVE_PLAYER,
    showCompletedMapObjectives = false,
    showCompletedTooltipObjectives = true,
    showObjectiveTooltipHints = true,
    alwaysShowTooltipDropRates = true,
    groupQuestAnnouncementsMode = DEFAULT_GROUP_QUEST_ANNOUNCEMENTS_MODE,
    groupQuestAnnouncementsLanguage = DEFAULT_GROUP_QUEST_ANNOUNCEMENTS_LANGUAGE,
    groupQuestObjectiveAnnouncementFormatEnUS = Quests:GetGroupQuestAnnouncementFormatDefault("enUS", "objective"),
    groupQuestCompleteAnnouncementFormatEnUS = Quests:GetGroupQuestAnnouncementFormatDefault("enUS", "complete"),
    groupQuestObjectiveAnnouncementFormatFrFR = Quests:GetGroupQuestAnnouncementFormatDefault("frFR", "objective"),
    groupQuestCompleteAnnouncementFormatFrFR = Quests:GetGroupQuestAnnouncementFormatDefault("frFR", "complete"),
}

local function IsBlankString(value)
    return type(value) ~= "string" or not string.find(value, "%S")
end

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

local function NormalizeGroupQuestAnnouncementFormats(settings)
    if IsBlankString(settings.groupQuestObjectiveAnnouncementFormatEnUS) then
        settings.groupQuestObjectiveAnnouncementFormatEnUS =
            Quests:GetGroupQuestAnnouncementFormatDefault("enUS", "objective")
    end
    if IsBlankString(settings.groupQuestCompleteAnnouncementFormatEnUS) then
        settings.groupQuestCompleteAnnouncementFormatEnUS =
            Quests:GetGroupQuestAnnouncementFormatDefault("enUS", "complete")
    end
    if IsBlankString(settings.groupQuestObjectiveAnnouncementFormatFrFR) then
        settings.groupQuestObjectiveAnnouncementFormatFrFR =
            Quests:GetGroupQuestAnnouncementFormatDefault("frFR", "objective")
    end
    if IsBlankString(settings.groupQuestCompleteAnnouncementFormatFrFR) then
        settings.groupQuestCompleteAnnouncementFormatFrFR =
            Quests:GetGroupQuestAnnouncementFormatDefault("frFR", "complete")
    end
end

function Quests:GetSettings()
    local rawSettings = VanillaEnhancedSettings
        and VanillaEnhancedSettings.modules
        and VanillaEnhancedSettings.modules.quests
        or nil
    local migrateFogSettings = type(rawSettings) == "table"
        and rawSettings.fogOfWarMarkerSettingsVersion ~= 1
    local hadObjectiveFogSetting = migrateFogSettings
        and rawSettings.showQuestObjectiveMarkersInFogOfWar ~= nil
    local hadAvailableFogSetting = migrateFogSettings
        and rawSettings.showAvailableQuestMarkersInFogOfWar ~= nil
    local legacyHideMarkersInFog = migrateFogSettings and rawSettings.hideMapMarkersInFogOfWar

    local settings = VanillaEnhanced:GetModuleSettings("quests", defaults)
    if migrateFogSettings then
        local legacyShowMarkersInFog = legacyHideMarkersInFog == false
        if not hadObjectiveFogSetting then
            settings.showQuestObjectiveMarkersInFogOfWar = legacyShowMarkersInFog
        end
        if not hadAvailableFogSetting then
            settings.showAvailableQuestMarkersInFogOfWar = legacyShowMarkersInFog
        end
        settings.fogOfWarMarkerSettingsVersion = 1
    end
    if settings.showTooltipDropRates ~= nil then
        settings.alwaysShowTooltipDropRates = settings.showTooltipDropRates
        settings.showTooltipDropRates = nil
    end
    NormalizeGroupQuestAnnouncementFormats(settings)
    if not AUTO_FOLLOW_QUESTS_MODES[settings.autoFollowQuestsMode] then
        settings.autoFollowQuestsMode = DEFAULT_AUTO_FOLLOW_QUESTS_MODE
    end
    if not AUTO_FOLLOW_QUESTS_RANGES[settings.autoFollowQuestsRange] then
        settings.autoFollowQuestsRange = DEFAULT_AUTO_FOLLOW_QUESTS_RANGE
    end
    if not OBJECTIVE_LOCATION_DISPLAY_MODES[settings.objectiveLocationDisplayMode] then
        settings.objectiveLocationDisplayMode = DEFAULT_OBJECTIVE_LOCATION_DISPLAY_MODE
    end
    if not GROUP_QUEST_ANNOUNCEMENTS_MODES[settings.groupQuestAnnouncementsMode] then
        settings.groupQuestAnnouncementsMode = DEFAULT_GROUP_QUEST_ANNOUNCEMENTS_MODE
    end
    if not GROUP_QUEST_ANNOUNCEMENTS_LANGUAGES[settings.groupQuestAnnouncementsLanguage] then
        settings.groupQuestAnnouncementsLanguage = DEFAULT_GROUP_QUEST_ANNOUNCEMENTS_LANGUAGE
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
    if self.RefreshSelectedQuestDirection then
        self:RefreshSelectedQuestDirection()
    end
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
