local VanillaEnhanced = _G.VanillaEnhanced
local QuestMap = VanillaEnhanced:GetModule("quest-map")

local function SlashCommand(input)
    input = string.lower(strtrim(input or ""))
    local settings = QuestMap:GetSettings()

    if input == "on" then
        settings.enabled = true
        QuestMap:Print("quest-map enabled")
        QuestMap:Refresh()
        QuestMap:RefreshQuestTrackerClicks()
    elseif input == "off" then
        settings.enabled = false
        QuestMap:Print("quest-map disabled")
        QuestMap:ClearPins()
        QuestMap:RebuildUnitTooltipIndex({})
        QuestMap:RefreshQuestTrackerClicks()
    elseif input == "refresh" then
        QuestMap:Refresh()
        QuestMap:RefreshQuestTrackerClicks()
        QuestMap:Print("quest-map refreshed")
    elseif input == "status" then
        QuestMap:Status()
    else
        QuestMap:Print("/ve quest-map on, /ve quest-map off, /ve quest-map refresh, /ve quest-map status")
    end
end

VanillaEnhanced:RegisterCommand("quest-map", SlashCommand, "/ve quest-map on|off|refresh|status")