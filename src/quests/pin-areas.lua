local Quests = _G.VanillaEnhanced:GetModule("quests")

local MARKER_FRAME_SIZE = 16
local AREA_COLOR = { 0.5, 0.7, 0.9 }
local AREA_FILL_ALPHA = 0.5
local AREA_FILL_STEP = 8
local AREA_OUTLINE_THICKNESS = 1.5
local WHITE_TEXTURE = [[Interface\Buttons\WHITE8X8]]

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

local function HideTextures(textures)
    if not textures then
        return
    end

    for _, texture in ipairs(textures) do
        texture:Hide()
    end
end

local function HideMarkerText(fontString)
    fontString:SetText("")
    fontString:Hide()
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

local function SetAreaRevealed(frame, revealed)
    if not frame or frame.kind ~= "area" then
        return
    end

    if revealed and Quests.PrepareWorldMapPinArea then
        Quests:PrepareWorldMapPinArea(frame)
    end
    frame:SetAlpha(revealed and 1 or 0)
    frame:EnableMouse(false)
end

local function ShouldRevealArea(frame)
    local data = frame and frame.questsData
    if not data then
        return false
    end

    return frame.questsHovered == true
        or (Quests.selectedQuestAreaQuestId and data.questId == Quests.selectedQuestAreaQuestId)
end

local function PinDataMatchesQuestId(data, questId)
    if not data or not questId then
        return false
    end

    if data.questId == questId then
        return true
    end

    if data.entries then
        for _, entry in ipairs(data.entries) do
            if entry.data and entry.data.questId == questId then
                return true
            end
        end
    end

    return false
end

local function ShouldHighlightMarker(frame)
    if not frame or frame.kind ~= "marker" then
        return false
    end

    return PinDataMatchesQuestId(frame.questsData, Quests.selectedQuestAreaQuestId)
end

local function ConfigurePolygonArea(frame, cluster)
    local settings = Quests:GetSettings()
    local color = AREA_COLOR
    local xScale, yScale = Quests:GetWorldMapPixelScale()
    local points = {}
    local maxX = 0
    local maxY = 0
    local minY
    local maxFillY

    local clusterX = Quests:GetClusterX(cluster)
    local clusterY = Quests:GetClusterY(cluster)
    local pointCount = Quests:GetClusterPointCount(cluster)

    for index = 1, pointCount do
        local x, y = Quests:GetClusterPoint(cluster, index)
        local dx = x - clusterX
        local dy = y - clusterY
        local px = dx * xScale
        local py = -dy * yScale

        points[index] = { x = px, y = py }
        maxX = math.max(maxX, math.abs(px))
        maxY = math.max(maxY, math.abs(py))
        minY = minY and math.min(minY, py) or py
        maxFillY = maxFillY and math.max(maxFillY, py) or py
    end

    frame:SetSize(math.max(32, (maxX * 2) + 16), math.max(32, (maxY * 2) + 16))
    ConfigureMarkerFrame(frame, settings, false)
    frame.texture:Hide()
    HideMarkerText(frame.text)

    local firstLine = AcquireAreaLine(frame, 1)
    if not firstLine.SetRotation then
        HideTextures(frame.lines)
        return false
    end

    ConfigurePolygonFill(frame, points, minY or 0, maxFillY or 0, color, math.min(0.28, (settings.opacity or 0.85) * AREA_FILL_ALPHA))

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
        line:SetVertexColor(color[1], color[2], color[3], math.min(0.95, (settings.opacity or 0.85) * 0.95))
    end

    for index = #points + 1, #(frame.lines or {}) do
        frame.lines[index]:Hide()
    end
    return true
end

local function ConfigureCircleArea(frame, radius)
    local settings = Quests:GetSettings()
    local xScale, yScale = Quests:GetWorldMapPixelScale()
    local size = math.max(38, math.min(260, math.floor(((radius or 0) * 2 * math.min(xScale, yScale)) + 12)))
    local color = AREA_COLOR

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
    frame.texture:SetVertexColor(color[1], color[2], color[3], math.min(0.95, (settings.opacity or 0.85) * 0.9))
    HideMarkerText(frame.text)
end

function Quests:GetWorldMapContentFrame()
    if WorldMapFrame then
        if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
            return WorldMapFrame.ScrollContainer.Child
        end
        if WorldMapDetailFrame then
            return WorldMapDetailFrame
        end
    end
    return WorldMapFrame
end

function Quests:GetWorldMapPixelScale()
    local frame = self:GetWorldMapContentFrame()
    local width = frame and frame:GetWidth() or 0
    local height = frame and frame:GetHeight() or 0

    if not width or width <= 0 then
        width = 700
    end
    if not height or height <= 0 then
        height = width
    end

    return width / 100, height / 100
end

function Quests:RefreshQuestAreaVisibility(targetFrame)
    if targetFrame then
        SetAreaRevealed(targetFrame, ShouldRevealArea(targetFrame))
        return
    end

    for _, frame in ipairs(self.frames) do
        if frame.kind == "area" then
            SetAreaRevealed(frame, ShouldRevealArea(frame))
        end
    end
end

function Quests:RefreshQuestMarkerHighlights(targetFrame)
    if targetFrame then
        if self.SetPinMarkerHighlighted then
            self:SetPinMarkerHighlighted(targetFrame, ShouldHighlightMarker(targetFrame))
        end
        return
    end

    if not self.SetPinMarkerHighlighted then
        return
    end

    for _, frame in ipairs(self.frames) do
        if frame.kind == "marker" then
            self:SetPinMarkerHighlighted(frame, ShouldHighlightMarker(frame))
        end
    end
end

function Quests:SetSelectedQuestAreaQuest(questId)
    self.selectedQuestAreaQuestId = questId
    if questId then
        self.selectedQuestDirectionQuestId = questId
    end
    self:RefreshQuestAreaVisibility()
    self:RefreshQuestMarkerHighlights()
    if self.RefreshSelectedQuestDirection then
        self:RefreshSelectedQuestDirection()
    end
end

function Quests:ConfigureWorldMapPinArea(frame, cluster)
    frame.questsAreaCluster = cluster
    frame.questsAreaPreparedKey = nil
    frame:SetSize(1, 1)
    frame.texture:Hide()
    HideTextures(frame.lines)
    HideTextures(frame.fills)
    HideMarkerText(frame.text)
    frame.background:Hide()
end

function Quests:PrepareWorldMapPinArea(frame)
    local cluster = frame and frame.questsAreaCluster
    if not frame or not cluster then
        return false
    end

    local settings = self:GetSettings()
    local xScale, yScale = self:GetWorldMapPixelScale()
    local preparedKey = table.concat({
        tostring(xScale),
        tostring(yScale),
        tostring(settings.scale or 1),
        tostring(settings.opacity or 1),
    }, ":")

    if frame.questsAreaPreparedKey == preparedKey then
        return true
    end

    frame.questsAreaPreparedKey = nil
    if self:GetClusterPointCount(cluster) >= 3 and ConfigurePolygonArea(frame, cluster) then
        frame.questsAreaPreparedKey = preparedKey
        return true
    end

    ConfigureCircleArea(frame, self:GetClusterRadius(cluster))
    frame.questsAreaPreparedKey = preparedKey
    return true
end
