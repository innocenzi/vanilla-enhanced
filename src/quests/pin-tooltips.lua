local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local TOOLTIP_TITLE_COLOR = { 1, 1, 1 }
local TOOLTIP_OBJECTIVE_COLOR = { 0.9, 0.82, 0.55 }
local TOOLTIP_METADATA_COLOR = { 0.56, 0.64, 0.72 }
local TOOLTIP_COUNT_COLOR = { 0.65, 0.85, 1 }

local function GetFloorHintTooltipLine(frame)
    if not frame or not Quests.IsMinimapPinOnOtherFloor or not Quests:IsMinimapPinOnOtherFloor(frame) then
        return nil
    end

    return VanillaEnhanced:T("quests.static.objectiveDifferentLevel")
end

local function AddTooltipLine(tooltip, text, color, wrap)
    if not text or text == "" then
        return
    end

    color = color or TOOLTIP_TITLE_COLOR
    tooltip:AddLine(text, color[1], color[2], color[3], wrap == true)
end

local function AddTooltipLines(tooltip, lines, color)
    if not lines then
        return
    end

    for _, line in ipairs(lines) do
        AddTooltipLine(tooltip, line, color, true)
    end
end

local function FormatTooltipTitle(data)
    local title = data.title

    if data.prefix then
        title = data.prefix .. " " .. title
    end
    if data.titleIcon then
        title = "|T" .. data.titleIcon .. ":12:12:0:0|t " .. title
    end

    return title
end

local function AddPinTooltipEntry(tooltip, data)
    if not data then
        return
    end

    AddTooltipLine(tooltip, FormatTooltipTitle(data), data.titleColor or TOOLTIP_TITLE_COLOR, true)
    AddTooltipLines(tooltip, data.metadataLines, TOOLTIP_METADATA_COLOR)
    AddTooltipLines(tooltip, data.lines, TOOLTIP_OBJECTIVE_COLOR)

    if data.objectives and #data.objectives > 1 then
        AddTooltipLines(tooltip, data.objectives, TOOLTIP_OBJECTIVE_COLOR)
    else
        AddTooltipLine(tooltip, data.objective, TOOLTIP_OBJECTIVE_COLOR, true)
    end

    AddTooltipLine(tooltip, data.countText, TOOLTIP_COUNT_COLOR)
end

function Quests:SetHoveredPinArea(frame, hovered)
    if frame.questsAreaFrames then
        for _, area in ipairs(frame.questsAreaFrames) do
            area.questsHovered = hovered == true
            self:RefreshQuestAreaVisibility(area)
        end
        return
    end

    local area = frame.questsAreaFrame
    if not area then
        return
    end

    area.questsHovered = hovered == true
    self:RefreshQuestAreaVisibility(area)
end

function Quests:HidePinTooltip(frame)
    self:SetHoveredPinArea(frame, false)
    if GameTooltip:IsOwned(frame) then
        GameTooltip:Hide()
    end
end

function Quests:OpenPinQuestLog(frame)
    if frame.questsPassThroughClicks then
        return
    end

    local data = frame.questsData
    if not data or not data.questId then
        return
    end
    self:OpenQuestLogToQuest(data.questId)
end

function Quests:ShowPinTooltip(frame)
    local data = frame.questsData
    if not data then
        return
    end

    self:SetHoveredPinArea(frame, true)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    if data.entries then
        GameTooltip:SetText(VanillaEnhanced:T("quests.static.nearbyMarkers"), 1, 1, 1)
        GameTooltip:AddLine(" ")
        for index, entry in ipairs(data.entries) do
            local entryData = entry.data
            if index > 1 then
                GameTooltip:AddLine(" ")
            end
            AddPinTooltipEntry(GameTooltip, entryData)
        end
        GameTooltip:Show()
        return
    end

    local titleColor = data.titleColor or TOOLTIP_TITLE_COLOR
    GameTooltip:SetText(FormatTooltipTitle(data), titleColor[1], titleColor[2], titleColor[3])
    AddTooltipLines(GameTooltip, data.metadataLines, TOOLTIP_METADATA_COLOR)
    AddTooltipLine(GameTooltip, GetFloorHintTooltipLine(frame), TOOLTIP_METADATA_COLOR, true)
    AddTooltipLines(GameTooltip, data.lines, TOOLTIP_OBJECTIVE_COLOR)

    if data.objectives and #data.objectives > 1 then
        AddTooltipLines(GameTooltip, data.objectives, TOOLTIP_OBJECTIVE_COLOR)
    else
        AddTooltipLine(GameTooltip, data.objective, TOOLTIP_OBJECTIVE_COLOR, true)
    end

    AddTooltipLine(GameTooltip, data.countText, TOOLTIP_COUNT_COLOR)
    GameTooltip:Show()
end
