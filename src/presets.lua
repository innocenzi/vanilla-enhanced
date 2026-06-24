local VanillaEnhanced = _G.VanillaEnhanced

local DEFAULT_PRESET_KEY = "explorer"

local PRESET_ORDER = {
    "explorer",
    "adventurer",
    "guide",
}

local PRESETS = {
    explorer = {
        labelKey = "options.main.configurationPreset.explorer",
        descriptionKey = "options.main.configurationPreset.explorer.description",
        modules = {
            quests = {
                enabled = true,
                keepQuestLogWithMap = true,
                enableQuestTrackerClicks = true,
                showMapMarkers = false,
                hideMapMarkersInFogOfWar = true,
                showSelectedQuestDirection = false,
                showMinimapObjectiveAreas = false,
                showRepeatableQuests = false,
                showReputationQuests = false,
                showAvailableQuests = true,
                showIncompleteDungeonTurnins = false,
                onlyShowNearbyAvailableQuests = true,
                onlyShowAvailableQuestsAroundPlayerLevel = true,
                showCompletedMapObjectives = false,
                showCompletedTooltipObjectives = false,
                showObjectiveTooltipHints = false,
                alwaysShowTooltipDropRates = true,
                autoFollowQuestsMode = "disabled",
            },
            map = {
                enabled = true,
                showWorldMapMarkers = true,
                showMinimapDirections = false,
                showKnownFlightMasters = false,
                showNeighboringFlightMasters = false,
                showNeighboringFlightMastersWithShift = true,
                autoRemoveReachedMarkers = true,
                reachedMarkerDistanceYards = 20,
            },
            training = {
                enabled = false,
                displayMode = "trainable",
            },
            professions = {
                enabled = true,
                displayMode = "recipes",
                recipeScope = "known",
                professionScope = "all",
            },
            bags = {
                showQuestIcon = true,
                showBoundIcon = true,
                showScrapIcon = true,
            },
        },
    },
    adventurer = {
        labelKey = "options.main.configurationPreset.adventurer",
        descriptionKey = "options.main.configurationPreset.adventurer.description",
        modules = {
            quests = {
                enabled = true,
                keepQuestLogWithMap = true,
                enableQuestTrackerClicks = true,
                showMapMarkers = true,
                hideMapMarkersInFogOfWar = true,
                showSelectedQuestDirection = true,
                showMinimapObjectiveAreas = true,
                showRepeatableQuests = false,
                showReputationQuests = false,
                showAvailableQuests = true,
                showIncompleteDungeonTurnins = false,
                onlyShowNearbyAvailableQuests = true,
                onlyShowAvailableQuestsAroundPlayerLevel = true,
                availableQuestLevelsBelowPlayer = 3,
                availableQuestLevelsAbovePlayer = 3,
                showCompletedMapObjectives = false,
                showCompletedTooltipObjectives = true,
                showObjectiveTooltipHints = true,
                alwaysShowTooltipDropRates = true,
                autoFollowQuestsMode = "zone",
                autoFollowQuestsRange = "wide",
            },
            map = {
                enabled = true,
                showWorldMapMarkers = true,
                showMinimapDirections = true,
                showKnownFlightMasters = true,
                showNeighboringFlightMasters = true,
                showNeighboringFlightMastersWithShift = true,
                autoRemoveReachedMarkers = true,
                reachedMarkerDistanceYards = 20,
            },
            training = {
                enabled = true,
                displayMode = "trainable",
            },
            professions = {
                enabled = true,
                displayMode = "recipes",
                recipeScope = "known",
                professionScope = "all",
            },
            bags = {
                showQuestIcon = true,
                showBoundIcon = true,
                showScrapIcon = true,
            },
        },
    },
    guide = {
        labelKey = "options.main.configurationPreset.guide",
        descriptionKey = "options.main.configurationPreset.guide.description",
        modules = {
            quests = {
                enabled = true,
                keepQuestLogWithMap = true,
                enableQuestTrackerClicks = true,
                showMapMarkers = true,
                hideMapMarkersInFogOfWar = false,
                showSelectedQuestDirection = true,
                showMinimapObjectiveAreas = true,
                showRepeatableQuests = true,
                showReputationQuests = true,
                showAvailableQuests = true,
                showIncompleteDungeonTurnins = false,
                onlyShowAvailableQuestsAroundPlayerLevel = true,
                availableQuestLevelsBelowPlayer = 3,
                availableQuestLevelsAbovePlayer = 3,
                showCompletedMapObjectives = false,
                showCompletedTooltipObjectives = true,
                showObjectiveTooltipHints = true,
                alwaysShowTooltipDropRates = true,
                autoFollowQuestsMode = "movement",
                autoFollowQuestsRange = "wide",
            },
            map = {
                enabled = true,
                showWorldMapMarkers = true,
                showMinimapDirections = true,
                showKnownFlightMasters = true,
                showNeighboringFlightMasters = true,
                showNeighboringFlightMastersWithShift = false,
                autoRemoveReachedMarkers = true,
                reachedMarkerDistanceYards = 20,
            },
            training = {
                enabled = true,
                displayMode = "all-unlearned",
            },
            professions = {
                enabled = true,
                displayMode = "recipes",
                recipeScope = "all",
                professionScope = "all",
            },
            bags = {
                showQuestIcon = true,
                showBoundIcon = true,
                showScrapIcon = true,
            },
        },
    },
}

local function GetPreset(presetKey)
    return PRESETS[presetKey] or PRESETS[DEFAULT_PRESET_KEY]
end

local function GetPresetKey(presetKey)
    if PRESETS[presetKey] then
        return presetKey
    end
    return DEFAULT_PRESET_KEY
end

local function GetModuleSettings(addon, moduleKey)
    local module = addon:GetModule(moduleKey)
    if module and module.GetSettings then
        return module:GetSettings()
    end
    return addon:GetModuleSettings(moduleKey, {
        enabled = true,
    })
end

local function RefreshModule(addon, moduleKey, moduleSettings)
    local module = addon:GetModule(moduleKey)
    if module and module.SetEnabled and moduleSettings.enabled ~= nil then
        module:SetEnabled(moduleSettings.enabled == true)
    elseif moduleSettings.enabled ~= nil then
        addon:SetModuleEnabled(moduleKey, moduleSettings.enabled == true)
        if module and module.Update then
            module:Update()
        end
    elseif module and module.Update then
        module:Update()
    end
end

function VanillaEnhanced:GetConfigurationPresetOptions()
    local options = {}
    for _, presetKey in ipairs(PRESET_ORDER) do
        local preset = PRESETS[presetKey]
        options[#options + 1] = {
            value = presetKey,
            labelKey = preset.labelKey,
            descriptionKey = preset.descriptionKey,
        }
    end
    return options
end

function VanillaEnhanced:GetDefaultConfigurationPresetKey()
    return DEFAULT_PRESET_KEY
end

function VanillaEnhanced:GetConfigurationPresetModuleDefaults(moduleKey)
    local preset = GetPreset(DEFAULT_PRESET_KEY)
    return preset.modules and preset.modules[moduleKey] or nil
end

function VanillaEnhanced:GetConfigurationPresetModuleDefaultsForPreset(presetKey, moduleKey)
    local preset = GetPreset(presetKey)
    return preset.modules and preset.modules[moduleKey] or nil
end

function VanillaEnhanced:GetConfigurationPresetLabel(presetKey)
    local preset = GetPreset(presetKey)
    return self:T(preset.labelKey)
end

function VanillaEnhanced:NormalizeConfigurationPresetKey(presetKey)
    return GetPresetKey(presetKey)
end

function VanillaEnhanced:ApplyConfigurationPreset(presetKey)
    local normalizedPresetKey = GetPresetKey(presetKey)
    local preset = GetPreset(normalizedPresetKey)
    local settings = self:GetSettings()
    settings.configurationPreset = normalizedPresetKey

    for moduleKey, moduleSettings in pairs(preset.modules or {}) do
        local settingsTable = GetModuleSettings(self, moduleKey)
        for settingKey, value in pairs(moduleSettings) do
            settingsTable[settingKey] = value
        end
    end

    for moduleKey, moduleSettings in pairs(preset.modules or {}) do
        RefreshModule(self, moduleKey, moduleSettings)
    end

    if self.RefreshOptions then
        self:RefreshOptions()
    end

    return normalizedPresetKey
end
