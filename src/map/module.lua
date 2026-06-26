local VanillaEnhanced = _G.VanillaEnhanced
local Map = VanillaEnhanced:CreateModule("map", VanillaEnhanced:T("module.map"))

Map.mediaPath = VanillaEnhanced.mediaPath
Map.worldMapFrames = Map.worldMapFrames or {}
Map.minimapFrames = Map.minimapFrames or {}
Map.directionTargetFrames = Map.directionTargetFrames or {}
Map.directionTargetsByOwner = Map.directionTargetsByOwner or {}
Map.markerProviders = Map.markerProviders or {}
Map.pool = Map.pool or {
    worldMap = {},
    minimap = {},
}
Map.pool.worldMap = Map.pool.worldMap or {}
Map.pool.minimap = Map.pool.minimap or {}
Map.initialized = Map.initialized or false

local eventFrame = CreateFrame("Frame")

local function RegisterEvent(event)
    if eventFrame.RegisterEvent then
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
end

local function Initialize()
    if Map.initialized then
        return
    end

    Map.initialized = true
    Map.hbd = LibStub and LibStub("HereBeDragons-2.0", true)
    Map.hbdPins = LibStub and LibStub("HereBeDragons-Pins-2.0", true)
    Map:GetSettings()

    if Map.HookWorldMapMarkerPlacement then
        Map:HookWorldMapMarkerPlacement()
    end
    if Map.RegisterFlightMasterModifierRefresh then
        Map:RegisterFlightMasterModifierRefresh()
    end
    if Map.Refresh then
        Map:Refresh()
    end
    if Map.RefreshTomTomCommands then
        Map:RefreshTomTomCommands()
    end
end

RegisterEvent("ADDON_LOADED")
RegisterEvent("PLAYER_LOGIN")
RegisterEvent("PLAYER_ENTERING_WORLD")
RegisterEvent("TAXIMAP_OPENED")
RegisterEvent("NEW_TAXI_PATH")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName ~= VanillaEnhanced.addonName then
        if loadedAddonName == "TomTom" then
            if Map.RefreshTomTomCommands then
                Map:RefreshTomTomCommands()
            end
            if VanillaEnhanced.RefreshOptions then
                VanillaEnhanced:RefreshOptions()
            end
        end
        return
    end

    Initialize()
    if event == "TAXIMAP_OPENED" or event == "NEW_TAXI_PATH" then
        if Map.CaptureKnownFlightMasters then
            Map:CaptureKnownFlightMasters()
        end
        return
    end
    if event ~= "ADDON_LOADED" and Map.Refresh then
        Map:Refresh()
    end
    if event ~= "ADDON_LOADED" and Map.RefreshTomTomCommands then
        Map:RefreshTomTomCommands()
    end
end)

if WorldMapFrame then
    hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
        if Map.RefreshWorldMapMarkers then
            Map:RefreshWorldMapMarkers()
        end
        if Map.ScheduleWorldMapMarkersRefresh then
            Map:ScheduleWorldMapMarkersRefresh(0.05)
        elseif Map.Refresh then
            Map:Refresh()
        end
    end)
end
