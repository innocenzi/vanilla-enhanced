local VanillaEnhanced = _G.VanillaEnhanced
local QuestMap = VanillaEnhanced:CreateModule("quest-map", "Quest Map")

QuestMap.mediaPath = VanillaEnhanced.mediaPath
QuestMap.refreshQueued = QuestMap.refreshQueued or false

local eventFrame = CreateFrame("Frame")

local function RegisterEventIfAvailable(frame, eventName)
    local ok = pcall(frame.RegisterEvent, frame, eventName)
    if not ok and QuestMap.Print then
        QuestMap:Print("skipping unsupported event " .. eventName)
    end
end

RegisterEventIfAvailable(eventFrame, "ADDON_LOADED")
RegisterEventIfAvailable(eventFrame, "PLAYER_LOGIN")
RegisterEventIfAvailable(eventFrame, "PLAYER_ENTERING_WORLD")
RegisterEventIfAvailable(eventFrame, "QUEST_LOG_UPDATE")
RegisterEventIfAvailable(eventFrame, "ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName == VanillaEnhanced.addonName then
        QuestMap:GetSettings()
        QuestMap.hbdPins = LibStub and LibStub("HereBeDragons-Pins-2.0", true)
        if not QuestMap.hbdPins then
            QuestMap:Print("HereBeDragons pins library did not load")
        end
    elseif event == "PLAYER_LOGIN" then
        QuestMap:QueueRefresh()
    elseif event ~= "ADDON_LOADED" then
        QuestMap:QueueRefresh()
    end
end)

if WorldMapFrame then
    hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
        QuestMap:QueueRefresh()
    end)
end
