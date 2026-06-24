local VanillaEnhanced = _G.VanillaEnhanced
local Map = VanillaEnhanced:GetModule("map")

local REACHED_MARKER_DISTANCE_MIN = 5
local REACHED_MARKER_DISTANCE_MAX = 100
local REACHED_MARKER_DISTANCE_STEP = 5
local REACHED_MARKER_DISTANCE_DEFAULT = 20
local KNOWN_FLIGHT_MASTERS_CACHE_VERSION = 5
local NEIGHBORING_FLIGHT_MASTERS_OPTIONS_VERSION = 1

local defaults = {
    enabled = true,
    showWorldMapMarkers = true,
    showMinimapDirections = true,
    showKnownFlightMasters = false,
    autoRemoveReachedMarkers = true,
    reachedMarkerDistanceYards = REACHED_MARKER_DISTANCE_DEFAULT,
    enableTomTomCommands = false,
    markers = {},
    knownFlightMasters = {},
    knownFlightMastersVersion = 0,
    nextMarkerId = 1,
}

local function GetCurrentPresetMapDefaults()
    local addonSettings = VanillaEnhanced.GetSettings and VanillaEnhanced:GetSettings() or nil
    local presetKey = addonSettings and addonSettings.configurationPreset or nil
    if VanillaEnhanced.GetConfigurationPresetModuleDefaultsForPreset then
        return VanillaEnhanced:GetConfigurationPresetModuleDefaultsForPreset(presetKey, "map")
    end
    return nil
end

local function InitializePresetDefault(settings, settingKey, fallback)
    if settings[settingKey] ~= nil then
        return
    end

    local presetDefaults = GetCurrentPresetMapDefaults()
    if presetDefaults and presetDefaults[settingKey] ~= nil then
        settings[settingKey] = presetDefaults[settingKey] == true
        return
    end
    settings[settingKey] = fallback == true
end

local function ClampReachedMarkerDistance(value)
    value = tonumber(value) or REACHED_MARKER_DISTANCE_DEFAULT
    value = REACHED_MARKER_DISTANCE_MIN
        + (math.floor(((value - REACHED_MARKER_DISTANCE_MIN) / REACHED_MARKER_DISTANCE_STEP) + 0.5) * REACHED_MARKER_DISTANCE_STEP)

    if value < REACHED_MARKER_DISTANCE_MIN then
        return REACHED_MARKER_DISTANCE_MIN
    end
    if value > REACHED_MARKER_DISTANCE_MAX then
        return REACHED_MARKER_DISTANCE_MAX
    end
    return value
end

function Map:GetSettings()
    local settings = VanillaEnhanced:GetCharacterModuleSettings("map", defaults)
    if type(settings.markers) ~= "table" then
        settings.markers = {}
    end
    if type(settings.knownFlightMasters) ~= "table" then
        settings.knownFlightMasters = {}
    end
    if settings.knownFlightMastersVersion ~= KNOWN_FLIGHT_MASTERS_CACHE_VERSION then
        settings.knownFlightMasters = {}
        settings.knownFlightMastersVersion = KNOWN_FLIGHT_MASTERS_CACHE_VERSION
    end
    InitializePresetDefault(settings, "showNeighboringFlightMasters", false)
    InitializePresetDefault(settings, "showNeighboringFlightMastersWithShift", false)
    if settings.neighboringFlightMastersOptionsVersion ~= NEIGHBORING_FLIGHT_MASTERS_OPTIONS_VERSION then
        if settings.showNeighboringFlightMastersWithShift == true and settings.showNeighboringFlightMasters ~= true then
            settings.showNeighboringFlightMasters = true
        end
        settings.neighboringFlightMastersOptionsVersion = NEIGHBORING_FLIGHT_MASTERS_OPTIONS_VERSION
    end
    if type(settings.nextMarkerId) ~= "number" or settings.nextMarkerId < 1 then
        settings.nextMarkerId = 1
    end
    settings.reachedMarkerDistanceYards = ClampReachedMarkerDistance(settings.reachedMarkerDistanceYards)
    return settings
end

function Map:GetReachedMarkerDistanceYards()
    return self:GetSettings().reachedMarkerDistanceYards
end

function Map:IsEnabled()
    return self:GetSettings().enabled ~= false
end

function Map:SetEnabled(enabled)
    self:GetSettings().enabled = not not enabled
    if self.Refresh then
        self:Refresh()
    end
    if self.RefreshTomTomCommands then
        self:RefreshTomTomCommands()
    end
    if VanillaEnhanced.RefreshOptions then
        VanillaEnhanced:RefreshOptions()
    end
end

function Map:Update()
    if self.Refresh then
        self:Refresh()
    end
    if self.RefreshTomTomCommands then
        self:RefreshTomTomCommands()
    end
end
