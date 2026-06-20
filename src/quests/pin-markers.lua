local Quests = _G.VanillaEnhanced:GetModule("quests")

local MARKER_SYMBOLS = {
    available = "!",
    turnin = "?",
}
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

    if frame.SetPropagateMouseClicks then
        frame:EnableMouse(true)
        frame:SetPropagateMouseClicks(passThrough == true)
    else
        frame:EnableMouse(passThrough ~= true)
    end
end

local function BuildCombinedMarkerSymbol(entries)
    local hasTurnin
    local hasAvailable
    local hasOther
    local fallbackSymbol

    for _, entry in ipairs(entries) do
        if entry.symbol == MARKER_SYMBOLS.turnin then
            hasTurnin = true
        elseif entry.symbol == MARKER_SYMBOLS.available then
            hasAvailable = true
        else
            hasOther = true
            fallbackSymbol = fallbackSymbol or entry.symbol
        end
    end

    local symbol = ""
    if hasTurnin then
        symbol = symbol .. MARKER_SYMBOLS.turnin
    end
    if hasAvailable then
        symbol = symbol .. MARKER_SYMBOLS.available
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

local function FindFirstQuestId(entries)
    for _, entry in ipairs(entries) do
        if entry.data and entry.data.questId then
            return entry.data.questId
        end
    end
    return nil
end

local function BuildCombinedMarkerData(entries)
    return {
        questId = FindFirstQuestId(entries),
        entries = entries,
    }
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

    return renderCandidate
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
        AddMarkerRenderCandidate(groupsByMap, BuildMarkerRenderCandidate(self, candidate, currentMapId), xScale, yScale)
    end

    for uiMapId, groups in pairs(groupsByMap) do
        local showFlag = currentMapId and uiMapId == currentMapId
            and (HBD_PINS_WORLDMAP_SHOW_CURRENT or -1)
            or (HBD_PINS_WORLDMAP_SHOW_WORLD or 3)
        for _, group in ipairs(groups) do
            local marker = self:AcquirePinFrame("marker", "marker", WorldMapFrame)
            local first = group.entries[1]

            marker.questsAreaFrame = nil
            marker.questsAreaFrames = nil
            SetMarkerPassThroughClicks(marker, currentMapId and uiMapId == currentMapId and GroupContainsChildMapEntries(group, uiMapId))

            if #group.entries == 1 then
                marker.questsData = first.data
                marker.questsAreaFrame = first.areaFrame
                if first.texture then
                    self:ConfigurePinIcon(marker, first.texture)
                else
                    self:ConfigurePinSymbol(marker, first.symbol, first.opacityMultiplier, first.color)
                end
            else
                local symbol = BuildCombinedMarkerSymbol(group.entries)

                marker.questsData = BuildCombinedMarkerData(group.entries)
                if #group.areaFrames > 0 then
                    marker.questsAreaFrames = group.areaFrames
                end
                self:ConfigurePinSymbol(marker, symbol)
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
            self.hbdPins:AddWorldMapIconMap(self, marker, uiMapId, group.x / 100, group.y / 100, showFlag)
            self:TrackWorldMapPinFrame(marker)
        end
    end
end
