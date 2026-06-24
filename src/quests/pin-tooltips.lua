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

local function AddTooltipObjectiveLines(tooltip, data)
    if not data then
        return
    end

    if data.objectives and #data.objectives > 1 then
        AddTooltipLines(tooltip, data.objectives, TOOLTIP_OBJECTIVE_COLOR)
        return
    end

    AddTooltipLine(tooltip, data.objective, TOOLTIP_OBJECTIVE_COLOR, true)
end

local function AddPinTooltipEntry(tooltip, data)
    if not data then
        return
    end

    AddTooltipLine(tooltip, FormatTooltipTitle(data), data.titleColor or TOOLTIP_TITLE_COLOR, true)
    AddTooltipLines(tooltip, data.metadataLines, TOOLTIP_METADATA_COLOR)
    AddTooltipLines(tooltip, data.lines, TOOLTIP_OBJECTIVE_COLOR)
    AddTooltipObjectiveLines(tooltip, data)
    AddTooltipLine(tooltip, data.countText, TOOLTIP_COUNT_COLOR)
end

local function AddUniqueLine(lines, seen, line)
    if not line or line == "" or seen[line] then
        return
    end

    seen[line] = true
    lines[#lines + 1] = line
end

local function AddUniqueLines(lines, seen, sourceLines)
    if not sourceLines then
        return
    end

    for _, line in ipairs(sourceLines) do
        AddUniqueLine(lines, seen, line)
    end
end

local function IsGroupableQuestTooltipData(data)
    return data and data.questId and not data.availableQuestId
end

local function AddQuestTooltipGroupObjective(group, data)
    if data.objectives and #data.objectives > 1 then
        AddUniqueLines(group.objectives, group.objectivesSeen, data.objectives)
        return
    end

    AddUniqueLine(group.objectives, group.objectivesSeen, data.objective)
end

local function AddQuestTooltipGroupEntry(group, data)
    AddUniqueLines(group.metadataLines, group.metadataSeen, data.metadataLines)
    AddUniqueLines(group.lines, group.linesSeen, data.lines)
    AddQuestTooltipGroupObjective(group, data)
    AddUniqueLine(group.countTexts, group.countTextsSeen, data.countText)
end

local function BuildQuestTooltipGroup(data)
    local group = {
        kind = "quest",
        data = data,
        metadataLines = {},
        metadataSeen = {},
        lines = {},
        linesSeen = {},
        objectives = {},
        objectivesSeen = {},
        countTexts = {},
        countTextsSeen = {},
    }

    AddQuestTooltipGroupEntry(group, data)
    return group
end

local function BuildClusterTooltipEntries(entries)
    local displayEntries = {}
    local groupsByQuestId = {}

    for _, entry in ipairs(entries or {}) do
        local entryData = entry.data
        local group

        if IsGroupableQuestTooltipData(entryData) then
            group = groupsByQuestId[entryData.questId]
            if group then
                AddQuestTooltipGroupEntry(group, entryData)
            else
                group = BuildQuestTooltipGroup(entryData)
                groupsByQuestId[entryData.questId] = group
                displayEntries[#displayEntries + 1] = group
            end
        else
            displayEntries[#displayEntries + 1] = {
                kind = "single",
                data = entryData,
            }
        end
    end

    return displayEntries
end

local function AddQuestTooltipGroup(tooltip, group)
    local data = group and group.data
    if not data then
        return
    end

    AddTooltipLine(tooltip, FormatTooltipTitle(data), data.titleColor or TOOLTIP_TITLE_COLOR, true)
    AddTooltipLines(tooltip, group.metadataLines, TOOLTIP_METADATA_COLOR)
    AddTooltipLines(tooltip, group.lines, TOOLTIP_OBJECTIVE_COLOR)
    AddTooltipLines(tooltip, group.objectives, TOOLTIP_OBJECTIVE_COLOR)
    AddTooltipLines(tooltip, group.countTexts, TOOLTIP_COUNT_COLOR)
end

local function AddClusterTooltipEntry(tooltip, entry)
    if not entry then
        return
    end

    if entry.kind == "quest" then
        AddQuestTooltipGroup(tooltip, entry)
        return
    end

    AddPinTooltipEntry(tooltip, entry.data)
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
        local entries = BuildClusterTooltipEntries(data.entries)

        GameTooltip:SetText(VanillaEnhanced:T("quests.static.nearbyMarkers"), 1, 1, 1)
        GameTooltip:AddLine(" ")
        for index, entry in ipairs(entries) do
            if index > 1 then
                GameTooltip:AddLine(" ")
            end
            AddClusterTooltipEntry(GameTooltip, entry)
        end
        GameTooltip:Show()
        return
    end

    local titleColor = data.titleColor or TOOLTIP_TITLE_COLOR
    GameTooltip:SetText(FormatTooltipTitle(data), titleColor[1], titleColor[2], titleColor[3])
    AddTooltipLines(GameTooltip, data.metadataLines, TOOLTIP_METADATA_COLOR)
    AddTooltipLine(GameTooltip, GetFloorHintTooltipLine(frame), TOOLTIP_METADATA_COLOR, true)
    AddTooltipLines(GameTooltip, data.lines, TOOLTIP_OBJECTIVE_COLOR)
    AddTooltipObjectiveLines(GameTooltip, data)
    AddTooltipLine(GameTooltip, data.countText, TOOLTIP_COUNT_COLOR)
    GameTooltip:Show()
end
