local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local MARKER_SYMBOLS = {
    available = "!",
    turnin = "?",
}

local ICON_TEXTURES = {
    talk = [[Interface\GossipFrame\GossipGossipIcon]],
}

local PARENT_MAP_ICON_MERGE_DISTANCE = 13
local MARKER_FRAME_SIZE = 16
local MARKER_COLOR = { 1, 0.82, 0.15 }
local MARKER_FONT_SIZE = 9
local MARKER_ICON_SIZE = 12
local AREA_COLOR = { 0.5, 0.7, 0.9 }
local AREA_FILL_STEP = 4
local AREA_OUTLINE_THICKNESS = 1.5
local MINIMAP_AREA_MIN_SIZE = 14
local MINIMAP_AREA_PADDING = 6
local MINIMAP_AREA_CLIP_PADDING = 3
local MINIMAP_AREA_CLIP_SEGMENTS = 48
local MARKER_CLUSTER_PIXEL_DISTANCE = 18
local WHITE_TEXTURE = [[Interface\Buttons\WHITE8X8]]
local WORLD_MAP_ID = 947
local MINIMAP_SIZE = {
    indoor = {
        [0] = 300,
        [1] = 240,
        [2] = 180,
        [3] = 120,
        [4] = 80,
        [5] = 50,
    },
    outdoor = {
        [0] = 466 + 2 / 3,
        [1] = 400,
        [2] = 333 + 1 / 3,
        [3] = 266 + 2 / 6,
        [4] = 200,
        [5] = 133 + 1 / 3,
    },
}

local function Atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end
    if x > 0 then
        return math.atan(y / x)
    end
    if x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    end
    if x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    end
    if y > 0 then
        return math.pi / 2
    end
    if y < 0 then
        return -math.pi / 2
    end
    return 0
end

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

local function ShouldMergeIcons(uiMapId, kind)
    local currentMapId = GetCurrentMapId()
    return ICON_TEXTURES[kind] and currentMapId and currentMapId ~= uiMapId
end

local function Distance(a, b)
    return math.sqrt(((a.x or 0) - (b.x or 0)) ^ 2 + ((a.y or 0) - (b.y or 0)) ^ 2)
end

local function AddUniqueObjective(objectives, objective)
    if not objective or objective == "" then
        return
    end

    for _, existing in ipairs(objectives) do
        if existing == objective then
            return
        end
    end
    objectives[#objectives + 1] = objective
end

local function NewClusterGroup(cluster)
    return {
        x = cluster.x,
        y = cluster.y,
        c = cluster.c or 1,
        k = cluster.k,
        r = cluster.r or 0,
        objectives = { cluster.o },
        clusters = { cluster },
    }
end

local function AddToClusterGroup(group, cluster)
    local weight = cluster.c or 1
    local total = group.c + weight

    group.x = ((group.x * group.c) + ((cluster.x or 0) * weight)) / total
    group.y = ((group.y * group.c) + ((cluster.y or 0) * weight)) / total
    group.c = total
    group.clusters[#group.clusters + 1] = cluster
    group.r = math.max(group.r or 0, Distance(group, cluster) + (cluster.r or 0))
    AddUniqueObjective(group.objectives, cluster.o)
end

local function BuildMergedCluster(group)
    return {
        x = group.x,
        y = group.y,
        r = 0,
        c = group.c,
        k = group.k,
        o = #group.objectives > 1 and VanillaEnhanced:T("quests.static.multipleObjectives") or group.objectives[1],
        objectives = group.objectives,
        parts = group.clusters,
        merged = true,
    }
end

local function MergeIconClusters(uiMapId, clusters)
    local groups = {}
    local changed = false

    for _, cluster in ipairs(clusters) do
        local kind = cluster.k or "object"
        local target

        if ShouldMergeIcons(uiMapId, kind) then
            for _, group in ipairs(groups) do
                if group.k == kind and Distance(group, cluster) <= PARENT_MAP_ICON_MERGE_DISTANCE then
                    target = group
                    break
                end
            end
        end

        if target then
            AddToClusterGroup(target, cluster)
            changed = true
        else
            groups[#groups + 1] = NewClusterGroup(cluster)
        end
    end

    if not changed then
        return clusters
    end

    local merged = {}
    for _, group in ipairs(groups) do
        merged[#merged + 1] = #group.clusters > 1 and BuildMergedCluster(group) or group.clusters[1]
    end
    return merged
end

local function ConfigureMarkerText(fontString, symbol, settings, opacityMultiplier, color)
    local opacity = (settings.opacity or 1) * (opacityMultiplier or 1)
    color = color or MARKER_COLOR

    fontString:Show()
    fontString:SetText(tostring(symbol))
    fontString:SetTextColor(color[1], color[2], color[3], opacity)
    fontString:SetFont(STANDARD_TEXT_FONT, math.max(8, math.floor(MARKER_FONT_SIZE * (settings.scale or 1))), "OUTLINE")
    fontString:SetShadowColor(0, 0, 0, 0.9)
    fontString:SetShadowOffset(1, -1)
end

local function HideMarkerText(fontString)
    fontString:SetText("")
    fontString:Hide()
end

local HideTextures

local function ConfigureMarkerFrame(frame, settings, resizeFrame)
    local size = math.max(12, math.floor(MARKER_FRAME_SIZE * (settings.scale or 1)))

    if resizeFrame then
        frame:SetSize(size, size)
    end
    frame.background:Hide()
end

local function ConfigureSymbol(frame, symbol, opacityMultiplier, color)
    local settings = Quests:GetSettings()

    ConfigureMarkerFrame(frame, settings, true)
    frame.texture:Hide()
    HideTextures(frame.lines)
    HideTextures(frame.fills)
    ConfigureMarkerText(frame.text, symbol, settings, opacityMultiplier, color)
end

local function ConfigureIcon(frame, texture)
    local settings = Quests:GetSettings()
    local size = math.max(10, math.floor(MARKER_ICON_SIZE * (settings.scale or 1)))

    ConfigureMarkerFrame(frame, settings, true)
    HideTextures(frame.lines)
    HideTextures(frame.fills)
    frame.text:SetText("")
    frame.texture:Show()
    frame.texture:SetTexture(texture)
    frame.texture:ClearAllPoints()
    frame.texture:SetSize(size, size)
    frame.texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.texture:SetVertexColor(1, 1, 1, settings.opacity or 1)
end

function HideTextures(textures)
    if not textures then
        return
    end

    for _, texture in ipairs(textures) do
        texture:Hide()
    end
end

local function AcquireAreaLine(frame, index)
    frame.lines = frame.lines or {}
    local line = frame.lines[index]
    if not line then
        line = frame:CreateTexture(nil, "OVERLAY")
        line:SetTexture(WHITE_TEXTURE)
        if line.SetBlendMode then
            line:SetBlendMode("BLEND")
        end
        frame.lines[index] = line
    end
    line:Show()
    return line
end

local function AcquireAreaFill(frame, index)
    frame.fills = frame.fills or {}
    local fill = frame.fills[index]
    if not fill then
        fill = frame:CreateTexture(nil, "ARTWORK")
        fill:SetTexture(WHITE_TEXTURE)
        if fill.SetBlendMode then
            fill:SetBlendMode("BLEND")
        end
        frame.fills[index] = fill
    end
    fill:Show()
    return fill
end

local function ConfigurePolygonFill(frame, points, minY, maxY, color, alpha, fillStep)
    local fillIndex = 1
    local step = fillStep or AREA_FILL_STEP

    for y = minY, maxY, step do
        local intersections = {}

        for index, point in ipairs(points) do
            local nextPoint = points[(index % #points) + 1]
            if (point.y <= y and nextPoint.y > y) or (nextPoint.y <= y and point.y > y) then
                local t = (y - point.y) / (nextPoint.y - point.y)
                intersections[#intersections + 1] = point.x + (t * (nextPoint.x - point.x))
            end
        end

        table.sort(intersections)
        for index = 1, #intersections - 1, 2 do
            local x1 = intersections[index]
            local x2 = intersections[index + 1]
            local width = math.max(1, x2 - x1)
            local fill = AcquireAreaFill(frame, fillIndex)

            fill:ClearAllPoints()
            fill:SetSize(width, step + 1)
            fill:SetPoint("CENTER", frame, "CENTER", x1 + (width / 2), y)
            fill:SetVertexColor(color[1], color[2], color[3], alpha)
            fillIndex = fillIndex + 1
        end
    end

    for index = fillIndex, #(frame.fills or {}) do
        frame.fills[index]:Hide()
    end
end

local function GetMinimapMapRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local radius = C_Minimap.GetViewRadius()
        if type(radius) == "number" and radius > 0 then
            return radius
        end
    end

    if not Minimap or not Minimap.GetZoom or not GetCVar then
        return nil
    end

    local zoom = Minimap:GetZoom()
    local minimapZoom = tonumber(GetCVar("minimapZoom"))
    local zoomKind = minimapZoom == zoom and "outdoor" or "indoor"
    local size = MINIMAP_SIZE[zoomKind] and MINIMAP_SIZE[zoomKind][zoom]

    return size and size / 2 or nil
end

local function GetMinimapAreaScale(uiMapId)
    if not Quests.hbd or not Quests.hbd.GetZoneSize or not Minimap then
        return nil, nil, nil
    end

    local zoneWidth, zoneHeight = Quests.hbd:GetZoneSize(uiMapId)
    local mapRadius = GetMinimapMapRadius()
    local minimapWidth = Minimap.GetWidth and Minimap:GetWidth() or 140
    local minimapHeight = Minimap.GetHeight and Minimap:GetHeight() or minimapWidth

    if not zoneWidth or not zoneHeight or zoneWidth <= 0 or zoneHeight <= 0 or not mapRadius then
        return nil, nil, nil
    end

    return (zoneWidth / 100 / mapRadius) * ((minimapWidth or 140) / 2),
        (zoneHeight / 100 / mapRadius) * ((minimapHeight or 140) / 2),
        math.min((minimapWidth or 140) / 2, (minimapHeight or 140) / 2) * 0.9
end

local function Cross(a, b, c)
    return ((b.x - a.x) * (c.y - a.y)) - ((b.y - a.y) * (c.x - a.x))
end

local function IntersectLines(a, b, c, d)
    local x1, y1 = a.x, a.y
    local x2, y2 = b.x, b.y
    local x3, y3 = c.x, c.y
    local x4, y4 = d.x, d.y
    local denominator = ((x1 - x2) * (y3 - y4)) - ((y1 - y2) * (x3 - x4))

    if math.abs(denominator) < 0.0001 then
        return { x = b.x, y = b.y }
    end

    local px = (((x1 * y2) - (y1 * x2)) * (x3 - x4) - (x1 - x2) * ((x3 * y4) - (y3 * x4))) / denominator
    local py = (((x1 * y2) - (y1 * x2)) * (y3 - y4) - (y1 - y2) * ((x3 * y4) - (y3 * x4))) / denominator

    return { x = px, y = py }
end

local function ClipPolygonAgainstEdge(points, edgeStart, edgeEnd)
    local clipped = {}
    local previous = points[#points]
    local previousInside = Cross(edgeStart, edgeEnd, previous) >= 0

    for _, current in ipairs(points) do
        local currentInside = Cross(edgeStart, edgeEnd, current) >= 0

        if currentInside then
            if not previousInside then
                clipped[#clipped + 1] = IntersectLines(previous, current, edgeStart, edgeEnd)
            end
            clipped[#clipped + 1] = current
        elseif previousInside then
            clipped[#clipped + 1] = IntersectLines(previous, current, edgeStart, edgeEnd)
        end

        previous = current
        previousInside = currentInside
    end

    return clipped
end

local function BuildMinimapClipPolygon(frame)
    if not Minimap or not frame or not frame.GetCenter or not Minimap.GetCenter then
        return nil
    end

    local frameX, frameY = frame:GetCenter()
    local minimapX, minimapY = Minimap:GetCenter()
    local radius = frame.questsMinimapClipRadius

    if not frameX or not frameY or not minimapX or not minimapY or not radius or radius <= 0 then
        return nil
    end

    local centerX = minimapX - frameX
    local centerY = minimapY - frameY
    local clipRadius = math.max(1, radius - MINIMAP_AREA_CLIP_PADDING)
    local polygon = {}

    for index = 1, MINIMAP_AREA_CLIP_SEGMENTS do
        local angle = ((index - 1) / MINIMAP_AREA_CLIP_SEGMENTS) * math.pi * 2
        polygon[index] = {
            x = centerX + (math.cos(angle) * clipRadius),
            y = centerY + (math.sin(angle) * clipRadius),
        }
    end

    return polygon
end

local function ClipPolygonToMinimap(frame, points)
    local clipPolygon = BuildMinimapClipPolygon(frame)
    local clipped = points

    if not clipPolygon then
        return clipped
    end

    for index, edgeStart in ipairs(clipPolygon) do
        if #clipped < 3 then
            return clipped
        end
        clipped = ClipPolygonAgainstEdge(clipped, edgeStart, clipPolygon[(index % #clipPolygon) + 1])
    end

    return clipped
end

local function GetMinimapEdgeOffset(frame)
    local pins = Quests.hbdPins
    local activePins = pins and pins.activeMinimapPins
    local data = activePins and activePins[frame]

    if not data or data.onEdge ~= true or not data.distanceFromMinimapCenter then
        return 0, 0
    end
    if not Minimap or not frame or not frame.GetCenter or not Minimap.GetCenter then
        return 0, 0
    end

    local frameX, frameY = frame:GetCenter()
    local minimapX, minimapY = Minimap:GetCenter()
    local minimapRadius = frame.questsMinimapClipRadius or 0
    if not frameX or not frameY or not minimapX or not minimapY or minimapRadius <= 0 then
        return 0, 0
    end

    local dx = frameX - minimapX
    local dy = frameY - minimapY
    local distance = math.sqrt((dx * dx) + (dy * dy))
    if distance <= 0 then
        return 0, 0
    end

    local overflow = math.max(0, (data.distanceFromMinimapCenter - 1) * minimapRadius)
    return (dx / distance) * overflow, (dy / distance) * overflow
end

local function OffsetPoints(points, offsetX, offsetY)
    if (offsetX == 0 and offsetY == 0) or not points then
        return points
    end

    local offsetPoints = {}
    for index, point in ipairs(points) do
        offsetPoints[index] = {
            x = point.x + offsetX,
            y = point.y + offsetY,
        }
    end
    return offsetPoints
end

local function DrawMinimapPolygonArea(frame, points)
    local settings = Quests:GetSettings()
    local color = AREA_COLOR
    local maxX = 0
    local maxY = 0
    local maxDistance = 0
    local minY
    local maxFillY

    if not points or #points < 3 then
        HideTextures(frame.lines)
        HideTextures(frame.fills)
        frame.texture:Hide()
        return false
    end

    for _, point in ipairs(points) do
        maxX = math.max(maxX, math.abs(point.x))
        maxY = math.max(maxY, math.abs(point.y))
        maxDistance = math.max(maxDistance, math.sqrt((point.x * point.x) + (point.y * point.y)))
        minY = minY and math.min(minY, point.y) or point.y
        maxFillY = maxFillY and math.max(maxFillY, point.y) or point.y
    end

    frame:SetSize(
        math.max(MINIMAP_AREA_MIN_SIZE, (maxX * 2) + MINIMAP_AREA_PADDING),
        math.max(MINIMAP_AREA_MIN_SIZE, (maxY * 2) + MINIMAP_AREA_PADDING)
    )
    ConfigureMarkerFrame(frame, settings, false)
    frame.texture:Hide()
    HideMarkerText(frame.text)

    local firstLine = AcquireAreaLine(frame, 1)
    if not firstLine.SetRotation then
        HideTextures(frame.lines)
        return false
    end

    ConfigurePolygonFill(frame, points, minY or 0, maxFillY or 0, color, math.min(0.10, (settings.opacity or 0.85) * 0.16), 1)

    for index, point in ipairs(points) do
        local nextPoint = points[(index % #points) + 1]
        local dx = nextPoint.x - point.x
        local dy = nextPoint.y - point.y
        local length = math.sqrt((dx * dx) + (dy * dy))
        local line = AcquireAreaLine(frame, index)

        line:ClearAllPoints()
        line:SetSize(length, AREA_OUTLINE_THICKNESS)
        line:SetPoint("CENTER", frame, "CENTER", point.x + (dx / 2), point.y + (dy / 2))
        line:SetRotation(Atan2(dy, dx))
        line:SetVertexColor(color[1], color[2], color[3], math.min(0.65, (settings.opacity or 0.85) * 0.65))
    end

    for index = #points + 1, #(frame.lines or {}) do
        frame.lines[index]:Hide()
    end

    frame.questsMinimapAreaRadius = maxDistance + (MINIMAP_AREA_PADDING / 2)
    return true
end

local function BuildMinimapPolygonPoints(cluster, xScale, yScale)
    local points = {}

    for index, point in ipairs(cluster.p) do
        local x = point[1] or point.x
        local y = point[2] or point.y

        points[index] = {
            x = (x - cluster.x) * xScale,
            y = -(y - cluster.y) * yScale,
        }
    end

    return points
end

local function UpdateMinimapPolygonArea(frame)
    if not frame or not frame.questsMinimapArea or not frame.questsMinimapBasePoints then
        return
    end

    local offsetX, offsetY = GetMinimapEdgeOffset(frame)
    local points = OffsetPoints(frame.questsMinimapBasePoints, offsetX, offsetY)

    DrawMinimapPolygonArea(frame, ClipPolygonToMinimap(frame, points))
end

local function ConfigureMinimapPolygonArea(frame, cluster, xScale, yScale, minimapRadius)
    frame.questsMinimapBasePoints = BuildMinimapPolygonPoints(cluster, xScale, yScale)
    frame.questsMinimapClipRadius = minimapRadius
    frame:SetScript("OnUpdate", UpdateMinimapPolygonArea)
    return DrawMinimapPolygonArea(frame, ClipPolygonToMinimap(frame, frame.questsMinimapBasePoints))
end

local function ConfigureMinimapCircleArea(frame, cluster, xScale, yScale, minimapRadius)
    local settings = Quests:GetSettings()
    local color = AREA_COLOR
    local radius = (cluster.r or 0) * math.min(xScale or 0, yScale or 0)
    local size = math.max(MINIMAP_AREA_MIN_SIZE, math.floor((radius * 2) + MINIMAP_AREA_PADDING))

    HideTextures(frame.lines)
    HideTextures(frame.fills)
    frame:SetSize(size, size)
    ConfigureMarkerFrame(frame, settings, false)
    frame.texture:Show()
    frame.texture:SetTexture(Quests.mediaPath .. "area-circle")
    if frame.texture.SetDrawLayer then
        frame.texture:SetDrawLayer("ARTWORK", -7)
    end
    if frame.texture.SetBlendMode then
        frame.texture:SetBlendMode("BLEND")
    end
    frame.texture:SetAllPoints(frame)
    frame.texture:SetVertexColor(color[1], color[2], color[3], math.min(0.18, (settings.opacity or 0.85) * 0.24))
    HideMarkerText(frame.text)
    frame.questsMinimapAreaRadius = size / 2
    frame.questsMinimapClipRadius = minimapRadius
end

local function ConfigureMinimapArea(frame, uiMapId, cluster)
    local xScale, yScale, minimapRadius = GetMinimapAreaScale(uiMapId)

    HideTextures(frame.lines)
    HideTextures(frame.fills)
    frame.questsMinimapArea = true
    frame.questsMinimapBasePoints = nil
    frame.questsMinimapAreaRadius = 0
    frame.questsMinimapClipRadius = minimapRadius or 0
    frame:SetScript("OnUpdate", nil)
    frame.texture.a = 1

    if xScale and yScale and cluster.p and #cluster.p >= 3 and ConfigureMinimapPolygonArea(frame, cluster, xScale, yScale, minimapRadius) then
        frame.texture:Hide()
    else
        ConfigureMinimapCircleArea(frame, cluster, xScale or 0, yScale or 0, minimapRadius or 0)
    end

    frame.questsPassThroughClicks = true
    frame:EnableMouse(true)
    if frame.SetPropagateMouseClicks then
        frame:SetPropagateMouseClicks(true)
    end
end

local function MarkerCandidateDistance(a, b, xScale, yScale)
    return math.sqrt(((((a.x or 0) - (b.x or 0)) * xScale) ^ 2) + ((((a.y or 0) - (b.y or 0)) * yScale) ^ 2))
end

local function GetMarkerSymbol(kind, fallback)
    return MARKER_SYMBOLS[kind] or fallback
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

local function BuildMarkerRenderCandidate(candidate, currentMapId)
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

    if currentMapId and Quests.hbd and Quests.hbd.TranslateZoneCoordinates then
        local displayX, displayY = Quests.hbd:TranslateZoneCoordinates(
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

function Quests:RenderMarkerGroups()
    if not self.hbdPins or not self.markerCandidates then
        return
    end

    local currentMapId = GetCurrentMapId()
    local xScale, yScale = self:GetWorldMapPixelScale()
    local groupsByMap = {}

    for _, candidate in ipairs(self.markerCandidates) do
        AddMarkerRenderCandidate(groupsByMap, BuildMarkerRenderCandidate(candidate, currentMapId), xScale, yScale)
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
                    ConfigureIcon(marker, first.texture)
                else
                    ConfigureSymbol(marker, first.symbol, first.opacityMultiplier, first.color)
                end
            else
                local symbol = BuildCombinedMarkerSymbol(group.entries)

                marker.questsData = BuildCombinedMarkerData(group.entries)
                if #group.areaFrames > 0 then
                    marker.questsAreaFrames = group.areaFrames
                end
                ConfigureSymbol(marker, symbol)
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

function Quests:AddPins(uiMapId, clusters, quest)
    local visibleClusters = {}

    for _, cluster in ipairs(clusters) do
        if self:ShouldShowObjectiveCluster(quest, cluster, "map") then
            visibleClusters[#visibleClusters + 1] = cluster
        end
    end

    for _, cluster in ipairs(MergeIconClusters(uiMapId, visibleClusters)) do
        self:AddPin(uiMapId, cluster.x, cluster.y, quest, cluster)
    end
    for _, cluster in ipairs(visibleClusters) do
        self:AddMinimapPin(uiMapId, cluster.x, cluster.y, quest, cluster)
    end
end

function Quests:AddAvailablePins(questId, dbQuest, context)
    if not dbQuest or not dbQuest.starts then
        return
    end

    for uiMapId, clusters in pairs(dbQuest.starts) do
        local visibleClusters = {}
        for _, cluster in ipairs(clusters) do
            if not self.ShouldShowAvailableQuestStart or self:ShouldShowAvailableQuestStart(uiMapId, cluster, context) then
                visibleClusters[#visibleClusters + 1] = cluster
            end
        end
        for _, cluster in ipairs(MergeIconClusters(uiMapId, visibleClusters)) do
            self:AddAvailablePin(uiMapId, cluster.x, cluster.y, questId, dbQuest, cluster, context)
        end
    end
end

function Quests:AddMinimapArea(uiMapId, x, y, pinData, cluster)
    if not self.hbdPins or not uiMapId or not x or not y then
        return nil
    end
    if not cluster then
        return nil
    end
    if (not cluster.p or #cluster.p < 3) and (not cluster.r or cluster.r <= 0) then
        return nil
    end

    local area = self:AcquirePinFrame("area", "minimapArea", Minimap)
    area.questsData = pinData
    area.questsHovered = false
    ConfigureMinimapArea(area, uiMapId, cluster)

    area:Hide()
    self.hbdPins:AddMinimapIconMap(self, area, uiMapId, x / 100, y / 100, true, true)
    self:TrackMinimapPinFrame(area)
    return area
end

function Quests:AddMinimapPin(uiMapId, x, y, quest, cluster)
    if not self.hbdPins or not uiMapId or not x or not y then
        return
    end

    local kind = cluster.k or "object"
    if kind == "turnin" then
        return
    end

    local pinData = self:BuildQuestPinData(quest, cluster)
    if kind == "slay" or kind == "loot" then
        if self:GetSettings().showMinimapObjectiveAreas == false then
            return
        end
        self:AddMinimapArea(uiMapId, x, y, pinData, cluster)
        return
    end

    local marker = self:AcquirePinFrame("marker", "minimapMarker", Minimap)
    marker.questsData = pinData
    if ICON_TEXTURES[kind] then
        ConfigureIcon(marker, ICON_TEXTURES[kind])
    else
        ConfigureSymbol(marker, MARKER_SYMBOLS[kind] or quest.number)
    end

    marker:Hide()
    self.hbdPins:AddMinimapIconMap(self, marker, uiMapId, x / 100, y / 100, true, false)
    self:TrackMinimapPinFrame(marker)
end

function Quests:AddPin(uiMapId, x, y, quest, cluster)
    if not self.hbdPins or not uiMapId or not x or not y then
        return
    end

    local kind = cluster.k or "object"
    local areaOnly = kind == "slay" or kind == "loot"
    local pinData = self:BuildQuestPinData(quest, cluster)
    local area

    if areaOnly or (cluster.r or 0) > 2 then
        area = self:AcquirePinFrame("area", "area", WorldMapFrame)
        area.questsData = pinData
        area.questsHovered = false
        self:ConfigureWorldMapPinArea(area, cluster)
        self.hbdPins:AddWorldMapIconMap(self, area, uiMapId, x / 100, y / 100, HBD_PINS_WORLDMAP_SHOW_CURRENT or -1)
        self:TrackWorldMapPinFrame(area)
        self:RefreshQuestAreaVisibility(area)
    end

    self:AddMarkerCandidate(uiMapId, x, y, pinData, GetMarkerSymbol(kind, quest.number), area, nil, nil, ICON_TEXTURES[kind])
end

function Quests:AddAvailablePin(uiMapId, x, y, questId, dbQuest, cluster, context)
    if not self.hbdPins or not uiMapId or not x or not y then
        return
    end

    local opacityMultiplier = self:GetAvailableQuestMarkerOpacity(dbQuest, context)
    local color = self:GetAvailableQuestMarkerColor(dbQuest, context)

    self:AddMarkerCandidate(
        uiMapId,
        x,
        y,
        self:BuildAvailableQuestPinData(questId, dbQuest),
        GetMarkerSymbol(cluster.k, MARKER_SYMBOLS.available),
        nil,
        opacityMultiplier,
        color
    )
end
