local Quests = _G.VanillaEnhanced:GetModule("quests")

local MARKER_FRAME_SIZE = 16
local AREA_COLOR = { 0.5, 0.7, 0.9 }
local AREA_FILL_STEP = 4
local AREA_OUTLINE_THICKNESS = 1.5
local MINIMAP_AREA_MIN_SIZE = 14
local MINIMAP_AREA_PADDING = 6
local MINIMAP_AREA_CLIP_PADDING = 3
local MINIMAP_AREA_CLIP_SEGMENTS = 48
local WHITE_TEXTURE = [[Interface\Buttons\WHITE8X8]]
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

local function HideMarkerText(fontString)
    fontString:SetText("")
    fontString:Hide()
end

local function HideTextures(textures)
    if not textures then
        return
    end

    for _, texture in ipairs(textures) do
        texture:Hide()
    end
end

local function ConfigureMarkerFrame(frame, settings, resizeFrame)
    local size = math.max(12, math.floor(MARKER_FRAME_SIZE * (settings.scale or 1)))

    if resizeFrame then
        frame:SetSize(size, size)
    end
    frame.background:Hide()
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
    if Quests.SetPinFramePropagateMouseClicks then
        Quests:SetPinFramePropagateMouseClicks(frame, true)
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
    area.questsMinimapUiMapId = uiMapId
    ConfigureMinimapArea(area, uiMapId, cluster)
    self:ApplyMinimapFloorDimming(area)

    area:Hide()
    self.hbdPins:AddMinimapIconMap(self, area, uiMapId, x / 100, y / 100, true, true)
    self:TrackMinimapPinFrame(area)
    return area
end
