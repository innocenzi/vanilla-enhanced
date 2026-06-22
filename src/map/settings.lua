local VanillaEnhanced = _G.VanillaEnhanced
local Map = VanillaEnhanced:GetModule("map")

local defaults = {
    enabled = true,
    showWorldMapMarkers = true,
    showMinimapDirections = true,
    markers = {},
    nextMarkerId = 1,
}

function Map:GetSettings()
    local settings = VanillaEnhanced:GetCharacterModuleSettings("map", defaults)
    if type(settings.markers) ~= "table" then
        settings.markers = {}
    end
    if type(settings.nextMarkerId) ~= "number" or settings.nextMarkerId < 1 then
        settings.nextMarkerId = 1
    end
    return settings
end

function Map:IsEnabled()
    return self:GetSettings().enabled ~= false
end

function Map:SetEnabled(enabled)
    self:GetSettings().enabled = not not enabled
    if self.Refresh then
        self:Refresh()
    end
    if VanillaEnhanced.RefreshOptions then
        VanillaEnhanced:RefreshOptions()
    end
end

function Map:Update()
    if self.Refresh then
        self:Refresh()
    end
end
