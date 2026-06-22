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
                showAvailableQuests = true,
                onlyShowNearbyAvailableQuests = true,
                onlyShowAvailableQuestsAroundPlayerLevel = true,
                showCompletedMapObjectives = false,
                showCompletedTooltipObjectives = false,
                showObjectiveTooltipHints = false,
                showTooltipDropRates = true,
                autoFollowQuestsMode = "disabled",
            },
            map = {
                enabled = true,
                showWorldMapMarkers = true,
                showMinimapDirections = false,
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
                showRepeatableQuests = true,
                showAvailableQuests = true,
                onlyShowNearbyAvailableQuests = true,
                onlyShowAvailableQuestsAroundPlayerLevel = true,
                availableQuestLevelsBelowPlayer = 5,
                availableQuestLevelsAbovePlayer = 3,
                showCompletedMapObjectives = false,
                showCompletedTooltipObjectives = true,
                showObjectiveTooltipHints = true,
                showTooltipDropRates = true,
                autoFollowQuestsMode = "zone",
                autoFollowQuestsBehavior = "auto-only",
                autoFollowQuestsRange = "nearby",
            },
            map = {
                enabled = true,
                showWorldMapMarkers = true,
                showMinimapDirections = true,
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
                showAvailableQuests = true,
                onlyShowNearbyAvailableQuests = false,
                onlyShowAvailableQuestsAroundPlayerLevel = false,
                showCompletedMapObjectives = true,
                showCompletedTooltipObjectives = true,
                showObjectiveTooltipHints = true,
                showTooltipDropRates = true,
                autoFollowQuestsMode = "movement",
                autoFollowQuestsBehavior = "replace-distant",
                autoFollowQuestsRange = "wide",
            },
            map = {
                enabled = true,
                showWorldMapMarkers = true,
                showMinimapDirections = true,
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
