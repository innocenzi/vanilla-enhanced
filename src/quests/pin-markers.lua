local Quests = _G.VanillaEnhanced:GetModule("quests")

local MARKER_CLUSTER_PIXEL_DISTANCE = 18
local WORLD_MAP_ID = 947

local function GetCurrentMapId()
    if WorldMapFrame then
        if WorldMapFrame.GetMapID then
            return WorldMapFrame:GetMapID()
        end
        if WorldMapFrame.mapID then
            return WorldMapFrame.mapID
        end
    end
    return nil
end

local function MarkerCandidateDistance(a, b, xScale, yScale)
    return math.sqrt(((((a.x or 0) - (b.x or 0)) * xScale) ^ 2) + ((((a.y or 0) - (b.y or 0)) * yScale) ^ 2))
end

local function AddUniqueAreaFrame(areaFrames, area)
    if not area then
        return
    end

    for _, existing in ipairs(areaFrames) do
        if existing == area then
            return
        end
    end

    areaFrames[#areaFrames + 1] = area
end

local function AddMarkerToGroup(group, candidate)
    local count = #group.entries

    group.x = ((group.x * count) + candidate.x) / (count + 1)
    group.y = ((group.y * count) + candidate.y) / (count + 1)
    group.entries[#group.entries + 1] = candidate
    AddUniqueAreaFrame(group.areaFrames, candidate.areaFrame)
end

local function GroupContainsChildMapEntries(group, uiMapId)
    for _, entry in ipairs(group.entries) do
        if entry.uiMapId ~= uiMapId then
            return true
        end
    end
    return false
end

local function SetMarkerPassThroughClicks(frame, passThrough)
    frame.questsPassThroughClicks = passThrough == true

    if Quests.SetPinFramePropagateMouseClicks then
        Quests:SetPinFramePropagateMouseClicks(frame, passThrough == true)
    end
end

local function BuildCombinedMarkerSymbol(entries)
    local hasTurnin
    local hasAvailable
    local hasOther
    local fallbackSymbol
    local turninSymbol = Quests:GetPinMarkerSymbol("turnin")
    local availableSymbol = Quests:GetPinMarkerSymbol("available")

    for _, entry in ipairs(entries) do
        if entry.symbol == turninSymbol then
            hasTurnin = true
        elseif entry.symbol == availableSymbol then
            hasAvailable = true
        else
            hasOther = true
            fallbackSymbol = fallbackSymbol or entry.symbol
        end
    end

    local symbol = ""
    if hasTurnin then
        symbol = symbol .. turninSymbol
    end
    if hasAvailable then
        symbol = symbol .. availableSymbol
    end
    if hasOther then
        if symbol ~= "" then
            symbol = symbol .. "+"
        elseif #entries == 1 then
            symbol = fallbackSymbol or "+"
        else
            symbol = "+"
        end
    end

    return symbol ~= "" and symbol or "+"
end

local function SameColor(left, right)
    if not left or not right then
        return false
    end

    return left[1] == right[1] and left[2] == right[2] and left[3] == right[3]
end

local function BuildCombinedMarkerColor(entries)
    local color

    for _, entry in ipairs(entries) do
        if entry.color then
            if not color then
                color = entry.color
            elseif not SameColor(color, entry.color) then
                return nil
            end
        elseif color then
            return nil
        end
    end

    return color
end

local function FindFirstQuestId(entries)
    for _, entry in ipairs(entries) do
        if entry.data and entry.data.questId then
            return entry.data.questId
        end
    end
    return nil
end

local function AddDedupeKeyPart(parts, value)
    if value and value ~= "" then
        parts[#parts + 1] = tostring(value)
    end
end

local function BuildMarkerTooltipEntryKey(entry)
    local data = entry and entry.data
    if not data then
        return nil
    end

    local parts = {}
    AddDedupeKeyPart(parts, data.questId or data.availableQuestId)
    AddDedupeKeyPart(parts, data.title)

    if data.objectives then
        for _, objective in ipairs(data.objectives) do
            AddDedupeKeyPart(parts, objective)
        end
    else
        AddDedupeKeyPart(parts, data.objective)
    end

    if #parts == 0 then
        return nil
    end
    return table.concat(parts, "\031")
end

local function BuildUniqueMarkerTooltipEntries(entries)
    local uniqueEntries = {}
    local seen = {}

    for _, entry in ipairs(entries) do
        local key = BuildMarkerTooltipEntryKey(entry)
        if not key or not seen[key] then
            if key then
                seen[key] = true
            end
            uniqueEntries[#uniqueEntries + 1] = entry
        end
    end

    return uniqueEntries
end

local function BuildCombinedMarkerData(entries, tooltipEntries)
    return {
        questId = FindFirstQuestId(entries),
        entries = tooltipEntries or BuildUniqueMarkerTooltipEntries(entries),
    }
end

local function AssignMarkerAreaFrames(marker, group, entry)
    if #group.areaFrames > 1 then
        marker.questsAreaFrames = group.areaFrames
        return
    end

    marker.questsAreaFrame = entry.areaFrame or group.areaFrames[1]
end

local function ConfigureSingleMarker(self, marker, group, entry)
    marker.questsData = entry.data
    AssignMarkerAreaFrames(marker, group, entry)

    if entry.texture then
        self:ConfigurePinIcon(marker, entry.texture, entry.opacityMultiplier, entry.color)
        return
    end

    self:ConfigurePinSymbol(marker, entry.symbol, entry.opacityMultiplier, entry.color)
end

local function ConfigureCombinedMarker(self, marker, group, tooltipEntries)
    local symbol = BuildCombinedMarkerSymbol(tooltipEntries)
    local color = BuildCombinedMarkerColor(tooltipEntries)

    marker.questsData = BuildCombinedMarkerData(group.entries, tooltipEntries)
    if #group.areaFrames > 0 then
        marker.questsAreaFrames = group.areaFrames
    end
    self:ConfigurePinSymbol(marker, symbol, nil, color)
end

local function BuildMarkerRenderCandidate(self, candidate, currentMapId)
    local renderCandidate = {
        uiMapId = candidate.uiMapId,
        renderMapId = candidate.uiMapId,
        x = candidate.x,
        y = candidate.y,
        data = candidate.data,
        symbol = candidate.symbol,
        areaFrame = candidate.areaFrame,
        opacityMultiplier = candidate.opacityMultiplier,
        color = candidate.color,
        texture = candidate.texture,
    }

    if currentMapId and self.hbd and self.hbd.TranslateZoneCoordinates then
        local displayX, displayY = self.hbd:TranslateZoneCoordinates(
            (candidate.x or 0) / 100,
            (candidate.y or 0) / 100,
            candidate.uiMapId,
            currentMapId,
            false
        )

        if displayX and displayY then
            renderCandidate.renderMapId = currentMapId
            renderCandidate.x = displayX * 100
            renderCandidate.y = displayY * 100
        end
    end

    if currentMapId
        and renderCandidate.renderMapId ~= currentMapId
        and self.hbd
        and self.hbd.GetWorldCoordinatesFromZone
        and self.hbd.GetZoneCoordinatesFromWorld then
        local worldX, worldY, sourceInstance = self.hbd:GetWorldCoordinatesFromZone(
            (candidate.x or 0) / 100,
            (candidate.y or 0) / 100,
            candidate.uiMapId
        )
        local targetData = self.hbd.mapData and self.hbd.mapData[currentMapId]
        if worldX and worldY and targetData and targetData.instance == sourceInstance then
            local displayX, displayY = self.hbd:GetZoneCoordinatesFromWorld(worldX, worldY, currentMapId)
            if displayX and displayY then
                renderCandidate.renderMapId = currentMapId
                renderCandidate.x = displayX * 100
                renderCandidate.y = displayY * 100
            end
        end
    end

    return renderCandidate
end

local function GetMarkerFogFilterPosition(self, candidate, renderCandidate)
    if self.DoesQuestMapHaveFogData and self:DoesQuestMapHaveFogData(candidate.uiMapId) then
        return candidate.uiMapId, candidate.x, candidate.y, true
    end

    if self.DoesQuestMapHaveFogData and self:DoesQuestMapHaveFogData(renderCandidate.renderMapId) then
        return renderCandidate.renderMapId,
            renderCandidate.x,
            renderCandidate.y,
            renderCandidate.renderMapId == candidate.uiMapId
    end

    return candidate.uiMapId, candidate.x, candidate.y, true
end

local function AddMarkerRenderCandidate(groupsByMap, candidate, xScale, yScale)
    local groups = groupsByMap[candidate.renderMapId]
    if not groups then
        groups = {}
        groupsByMap[candidate.renderMapId] = groups
    end

    for _, group in ipairs(groups) do
        if MarkerCandidateDistance(group, candidate, xScale, yScale) <= MARKER_CLUSTER_PIXEL_DISTANCE then
            AddMarkerToGroup(group, candidate)
            return
        end
    end

    groups[#groups + 1] = {
        x = candidate.x,
        y = candidate.y,
        entries = { candidate },
        areaFrames = {},
    }
    AddUniqueAreaFrame(groups[#groups].areaFrames, candidate.areaFrame)
end

function Quests:AddMarkerCandidate(uiMapId, x, y, data, symbol, areaFrame, opacityMultiplier, color, texture)
    self.markerCandidates = self.markerCandidates or {}

    self.markerCandidates[#self.markerCandidates + 1] = {
        uiMapId = uiMapId,
        x = x,
        y = y,
        data = data,
        symbol = symbol,
        areaFrame = areaFrame,
        opacityMultiplier = opacityMultiplier,
        color = color,
        texture = texture,
    }
end

function Quests:RenderMarkerGroups()
    if not self.hbdPins or not self.markerCandidates then
        return
    end

    local currentMapId = GetCurrentMapId()
    local xScale, yScale = self:GetWorldMapPixelScale()
    local groupsByMap = {}

    for _, candidate in ipairs(self.markerCandidates) do
        local renderCandidate = BuildMarkerRenderCandidate(self, candidate, currentMapId)

        if not self.IsQuestWorldMapLocationVisible then
            AddMarkerRenderCandidate(groupsByMap, renderCandidate, xScale, yScale)
        else
            local filterMapId, filterX, filterY, hideIfExplorationApiHasNoData =
                GetMarkerFogFilterPosition(self, candidate, renderCandidate)
            if self:IsQuestWorldMapLocationVisible(filterMapId, filterX, filterY, hideIfExplorationApiHasNoData) then
                AddMarkerRenderCandidate(groupsByMap, renderCandidate, xScale, yScale)
            end
        end
    end

    for uiMapId, groups in pairs(groupsByMap) do
        local showFlag = currentMapId and uiMapId == currentMapId
            and (HBD_PINS_WORLDMAP_SHOW_CURRENT or -1)
            or (HBD_PINS_WORLDMAP_SHOW_WORLD or 3)
        for _, group in ipairs(groups) do
            local marker = self:AcquirePinFrame("marker", "marker", WorldMapFrame)
            local tooltipEntries = BuildUniqueMarkerTooltipEntries(group.entries)
            local first = tooltipEntries[1]

            marker.questsAreaFrame = nil
            marker.questsAreaFrames = nil
            SetMarkerPassThroughClicks(marker, currentMapId and uiMapId == currentMapId and GroupContainsChildMapEntries(group, uiMapId))

            if #tooltipEntries == 1 then
                ConfigureSingleMarker(self, marker, group, first)
            else
                ConfigureCombinedMarker(self, marker, group, tooltipEntries)
            end

            if uiMapId == WORLD_MAP_ID and currentMapId == WORLD_MAP_ID then
                -- HBD's world-map path can use explicit Azeroth map coordinates from the icon.
                marker.UiMapID = WORLD_MAP_ID
                marker.x = group.x
                marker.y = group.y
            else
                marker.UiMapID = nil
                marker.x = nil
                marker.y = nil
            end
            if self.RefreshQuestMarkerHighlights then
                self:RefreshQuestMarkerHighlights(marker)
            end
            self.hbdPins:AddWorldMapIconMap(self, marker, uiMapId, group.x / 100, group.y / 100, showFlag)
            self:RaiseWorldMapMarkerFrame(marker)
            self:TrackWorldMapPinFrame(marker)
        end
    end
end
