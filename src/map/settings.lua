local VanillaEnhanced = _G.VanillaEnhanced
local Map = VanillaEnhanced:GetModule("map")

local REACHED_MARKER_DISTANCE_MIN = 5
local REACHED_MARKER_DISTANCE_MAX = 100
local REACHED_MARKER_DISTANCE_STEP = 5
local REACHED_MARKER_DISTANCE_DEFAULT = 20

local defaults = {
    enabled = true,
    showWorldMapMarkers = true,
    showMinimapDirections = true,
    autoRemoveReachedMarkers = true,
    reachedMarkerDistanceYards = REACHED_MARKER_DISTANCE_DEFAULT,
    enableTomTomCommands = false,
    markers = {},
    nextMarkerId = 1,
}

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
