local VanillaEnhanced = _G.VanillaEnhanced
local Map = VanillaEnhanced:CreateModule("map", VanillaEnhanced:T("module.map"))

Map.mediaPath = VanillaEnhanced.mediaPath
Map.worldMapFrames = Map.worldMapFrames or {}
Map.minimapFrames = Map.minimapFrames or {}
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
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName ~= VanillaEnhanced.addonName then
        return
    end

    Initialize()
    if event ~= "ADDON_LOADED" and Map.Refresh then
        Map:Refresh()
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
