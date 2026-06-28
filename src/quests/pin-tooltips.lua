local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local TOOLTIP_TITLE_COLOR = { 1, 1, 1 }
local TOOLTIP_OBJECTIVE_COLOR = { 0.9, 0.82, 0.55 }
local TOOLTIP_METADATA_COLOR = { 0.56, 0.64, 0.72 }
local TOOLTIP_COUNT_COLOR = { 0.65, 0.85, 1 }
local MAX_TOOLTIP_NPC_NAMES = 3
local AVAILABLE_QUEST_MARKER_SOURCE = "availableQuest"
local MARKER_SOURCE_COORDINATE_PRECISION = 100000

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

local AddExpandedTooltipLines
local AddTooltipTitleLine
local IsTooltipDetailsExpanded

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

    AddTooltipTitleLine(tooltip, data)
    AddTooltipLines(tooltip, data.metadataLines, TOOLTIP_METADATA_COLOR)
    AddExpandedTooltipLines(tooltip, data, nil, data.objectives or (data.objective and { data.objective } or nil))
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

IsTooltipDetailsExpanded = function()
    if VanillaEnhanced.IsTooltipDetailsExpanded then
        return VanillaEnhanced:IsTooltipDetailsExpanded()
    end
    return type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
end

local function GetQuestLevel(dbQuest)
    if not dbQuest then
        return nil
    end
    if dbQuest.ql and dbQuest.ql > 0 then
        return dbQuest.ql
    end
    if dbQuest.rl and dbQuest.rl > 0 then
        return dbQuest.rl
    end
    return nil
end

local function GetDbQuest(data)
    local questId = data and (data.questId or data.availableQuestId)
    if not questId or not VanillaEnhancedQuestsDB or not VanillaEnhancedQuestsDB.quests then
        return nil
    end
    return VanillaEnhancedQuestsDB.quests[questId]
end

local function FormatCoordinate(value)
    value = tonumber(value)
    if not value then
        return nil
    end
    return string.format("%.1f", math.floor((value * 10) + 0.5) / 10)
end

local function GetCoordinateText(data)
    local cluster = data and data.cluster
    local x = FormatCoordinate(Quests:GetClusterX(cluster))
    local y = FormatCoordinate(Quests:GetClusterY(cluster))
    if not x or not y then
        return nil
    end
    return VanillaEnhanced:T("map.marker.tooltipCoordinates", { x = x, y = y })
end

local function IsAltLeftClick(button)
    return button == "LeftButton" and type(IsAltKeyDown) == "function" and IsAltKeyDown()
end

local function GetMapModule()
    local map = VanillaEnhanced.modules and VanillaEnhanced.modules.map
    if map and map.ToggleSourcedMarker then
        return map
    end
    return nil
end

local function FindAvailableQuestPinData(data)
    if not data then
        return nil
    end
    if data.availableQuestId then
        return data
    end
    if data.entries then
        for _, entry in ipairs(data.entries) do
            local availableData = FindAvailableQuestPinData(entry and entry.data)
            if availableData then
                return availableData
            end
        end
    end
    return nil
end

local function RoundMarkerSourceCoordinate(value)
    value = tonumber(value) or 0
    return math.floor((value * MARKER_SOURCE_COORDINATE_PRECISION) + 0.5)
end

local function BuildAvailableQuestMarkerSourceId(data)
    if not data or not data.availableQuestId or not data.markerUiMapId or not data.markerX or not data.markerY then
        return nil
    end

    return table.concat({
        tostring(data.availableQuestId),
        tostring(data.markerUiMapId),
        tostring(RoundMarkerSourceCoordinate(data.markerX)),
        tostring(RoundMarkerSourceCoordinate(data.markerY)),
    }, ":")
end

AddTooltipTitleLine = function(tooltip, data)
    if not data then
        return
    end

    local color = data.titleColor or TOOLTIP_TITLE_COLOR
    local title = FormatTooltipTitle(data)
    local coordinateText = IsTooltipDetailsExpanded() and GetCoordinateText(data) or nil

    if coordinateText and tooltip.AddDoubleLine then
        tooltip:AddDoubleLine(
            title,
            coordinateText,
            color[1],
            color[2],
            color[3],
            TOOLTIP_METADATA_COLOR[1],
            TOOLTIP_METADATA_COLOR[2],
            TOOLTIP_METADATA_COLOR[3]
        )
        return
    end

    AddTooltipLine(tooltip, title, color, true)
end

local function AddUniqueNpcName(names, seen, name)
    if not name or name == "" or seen[name] then
        return
    end

    seen[name] = true
    names[#names + 1] = name
end

local function AddNpcNamesFromCluster(names, seen, cluster)
    if not cluster then
        return
    end

    if cluster.parts then
        for _, part in ipairs(cluster.parts) do
            AddNpcNamesFromCluster(names, seen, part)
        end
        return
    end

    local sourceType = Quests:GetClusterSourceType(cluster)
    local sourceId = Quests:GetClusterSourceId(cluster)
    if sourceType == "npc" and sourceId then
        AddUniqueNpcName(names, seen, Quests:GetLocalizedNpcName(sourceId) or Quests:GetClusterObjective(cluster))
    end

    local tooltipNpcIds = Quests:GetClusterTooltipNpcIds(cluster)
    if tooltipNpcIds then
        for _, npcId in ipairs(tooltipNpcIds) do
            AddUniqueNpcName(names, seen, Quests:GetLocalizedNpcName(npcId))
        end
    end
end

local function BuildSkippedNpcLookup(lines)
    local skipped = {}
    for _, line in ipairs(lines or {}) do
        if line and line ~= "" then
            skipped[line] = true
        end
    end
    return skipped
end

local function IsNpcNamePrefixOfObjective(name, objective)
    if not name or name == "" or not objective or objective == "" then
        return false
    end
    if objective == name then
        return true
    end
    if string.sub(objective, 1, string.len(name)) ~= name then
        return false
    end

    local nextCharacter = string.sub(objective, string.len(name) + 1, string.len(name) + 1)
    return nextCharacter == " " or nextCharacter == ":" or nextCharacter == "-" or nextCharacter == "("
end

local function ShouldSkipNpcName(name, skippedNpcNames)
    if not skippedNpcNames then
        return false
    end
    if skippedNpcNames[name] then
        return true
    end

    for objective in pairs(skippedNpcNames) do
        if IsNpcNamePrefixOfObjective(name, objective) then
            return true
        end
    end
    return false
end

local function BuildExpandedTooltipLines(data, skippedNpcNames)
    local lines = {}
    local dbQuest = GetDbQuest(data)

    if data and data.questId then
        local questLevel = GetQuestLevel(dbQuest)
        if questLevel then
            lines[#lines + 1] = VanillaEnhanced:T("quests.static.activeQuestLevel", { level = questLevel })
        end
    end

    local npcNames = {}
    local visibleNpcNames = {}
    AddNpcNamesFromCluster(npcNames, {}, data and data.cluster)
    for _, name in ipairs(npcNames) do
        if not ShouldSkipNpcName(name, skippedNpcNames) then
            visibleNpcNames[#visibleNpcNames + 1] = name
        end
    end

    if #visibleNpcNames == 1 then
        lines[#lines + 1] = visibleNpcNames[1]
    elseif #visibleNpcNames > 1 then
        local shown = {}
        local shownCount = math.min(#visibleNpcNames, MAX_TOOLTIP_NPC_NAMES)
        for index = 1, shownCount do
            shown[#shown + 1] = visibleNpcNames[index]
        end
        lines[#lines + 1] = table.concat(shown, ", ")
        if #visibleNpcNames > shownCount then
            lines[#lines + 1] = VanillaEnhanced:T("quests.static.moreNpcs", { count = #visibleNpcNames - shownCount })
        end
    end

    return lines
end

AddExpandedTooltipLines = function(tooltip, data, seen, skippedNpcNames)
    if not IsTooltipDetailsExpanded() then
        return
    end

    local lines = BuildExpandedTooltipLines(data, BuildSkippedNpcLookup(skippedNpcNames))
    for _, line in ipairs(lines) do
        if seen then
            AddUniqueLine(seen.lines, seen.keys, line)
        else
            AddTooltipLine(tooltip, line, TOOLTIP_METADATA_COLOR, true)
        end
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
    group.entryData[#group.entryData + 1] = data
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
        entryData = {},
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

    AddTooltipTitleLine(tooltip, data)
    AddTooltipLines(tooltip, group.metadataLines, TOOLTIP_METADATA_COLOR)
    local expandedSeen = { lines = {}, keys = {} }
    for _, entryData in ipairs(group.entryData) do
        AddExpandedTooltipLines(tooltip, entryData, expandedSeen, group.objectives)
    end
    AddTooltipLines(tooltip, expandedSeen.lines, TOOLTIP_METADATA_COLOR)
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

function Quests:ToggleAvailableQuestCustomMarker(frame)
    if not frame or frame.poolKind ~= "marker" or frame.questsPassThroughClicks then
        return false
    end

    local data = FindAvailableQuestPinData(frame.questsData)
    local sourceId = BuildAvailableQuestMarkerSourceId(data)
    local map = GetMapModule()
    if not data or not sourceId or not map then
        return false
    end

    if not map:ToggleSourcedMarker(data.markerUiMapId, data.markerX, data.markerY, AVAILABLE_QUEST_MARKER_SOURCE, sourceId, {
        title = data.title,
        hideWorldMap = true,
    }) then
        return false
    end

    if self.HidePinTooltip then
        self:HidePinTooltip(frame)
    end
    return true
end

function Quests:HandlePinClick(frame, button)
    if IsAltLeftClick(button) and self:ToggleAvailableQuestCustomMarker(frame) then
        return
    end

    self:OpenPinQuestLog(frame)
end

function Quests:ShowPinTooltip(frame)
    if self.RefreshQuestPinTooltipFrameData then
        self:RefreshQuestPinTooltipFrameData(frame)
    end

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

    AddTooltipTitleLine(GameTooltip, data)
    AddTooltipLines(GameTooltip, data.metadataLines, TOOLTIP_METADATA_COLOR)
    AddTooltipLine(GameTooltip, GetFloorHintTooltipLine(frame), TOOLTIP_METADATA_COLOR, true)
    AddExpandedTooltipLines(GameTooltip, data, nil, data.objectives or (data.objective and { data.objective } or nil))
    AddTooltipLines(GameTooltip, data.lines, TOOLTIP_OBJECTIVE_COLOR)
    AddTooltipObjectiveLines(GameTooltip, data)
    AddTooltipLine(GameTooltip, data.countText, TOOLTIP_COUNT_COLOR)
    GameTooltip:Show()
end

local function RefreshQuestPinTooltips()
    if not GameTooltip or not GameTooltip.IsOwned then
        return
    end

    for _, frame in ipairs(Quests.frames or {}) do
        if GameTooltip:IsOwned(frame) then
            Quests:ShowPinTooltip(frame)
            return
        end
    end
    for _, frame in ipairs(Quests.minimapFrames or {}) do
        if GameTooltip:IsOwned(frame) then
            Quests:ShowPinTooltip(frame)
            return
        end
    end
end

if VanillaEnhanced.RegisterTooltipDetailsRefresh then
    VanillaEnhanced:RegisterTooltipDetailsRefresh(RefreshQuestPinTooltips)
end
