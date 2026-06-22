local VanillaEnhanced = _G.VanillaEnhanced
local Map = VanillaEnhanced:CreateModule("map", VanillaEnhanced:T("module.map"))

Map.mediaPath = VanillaEnhanced.mediaPath
Map.worldMapFrames = Map.worldMapFrames or {}
Map.minimapFrames = Map.minimapFrames or {}
Map.directionTargetFrames = Map.directionTargetFrames or {}
Map.directionTargetsByOwner = Map.directionTargetsByOwner or {}
Map.pool = Map.pool or {
    worldMap = {},
    minimap = {},
}
Map.pool.worldMap = Map.pool.worldMap or {}
Map.pool.minimap = Map.pool.minimap or {}
Map.initialized = Map.initialized or false

local eventFrame = CreateFrame("Frame")

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
    if Map.Refresh then
        Map:Refresh()
    end
    if Map.RefreshTomTomCommands then
        Map:RefreshTomTomCommands()
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
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
        elseif Map.Refresh then
            Map:Refresh()
        end
    end)
end
