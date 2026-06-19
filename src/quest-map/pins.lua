local VanillaEnhanced = _G.VanillaEnhanced
local QuestMap = VanillaEnhanced:GetModule("quest-map")

QuestMap.frames = QuestMap.frames or {}
QuestMap.minimapFrames = QuestMap.minimapFrames or {}
QuestMap.pool = QuestMap.pool or {
    area = {},
    marker = {},
    minimapMarker = {},
}

local MARKER_SYMBOLS = {
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
local AREA_FILL_ALPHA = 0.5
local AREA_FILL_STEP = 4
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
        o = #group.objectives > 1 and "Multiple objectives" or group.objectives[1],
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

local function HideTooltip(self)
    if GameTooltip:IsOwned(self) then
        GameTooltip:Hide()
    end
end

local function OpenQuestLog(self)
    local data = self.questMapData
    if not data or not data.questId then
        return
    end
    QuestMap:OpenQuestLogToQuest(data.questId)
end

local function ShowTooltip(self)
    local data = self.questMapData
    if not data then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(data.number .. ". " .. data.title, 1, 1, 1)
    if data.objectives and #data.objectives > 1 then
        for _, objective in ipairs(data.objectives) do
            GameTooltip:AddLine(objective, 0.9, 0.82, 0.55, true)
        end
    elseif data.objective and data.objective ~= "" then
        GameTooltip:AddLine(data.objective, 0.9, 0.82, 0.55, true)
    end
    if data.countText then
        GameTooltip:AddLine(data.countText, 0.65, 0.85, 1)
    end
    GameTooltip:Show()
end

local function ConfigureMarkerText(fontString, symbol, settings)
    fontString:SetText(tostring(symbol))
    fontString:SetTextColor(MARKER_COLOR[1], MARKER_COLOR[2], MARKER_COLOR[3], settings.opacity or 1)
    fontString:SetFont(STANDARD_TEXT_FONT, math.max(8, math.floor(MARKER_FONT_SIZE * (settings.scale or 1))), "OUTLINE")
    fontString:SetShadowColor(0, 0, 0, 0.9)
    fontString:SetShadowOffset(1, -1)
end

local HideTextures

local function ConfigureMarkerFrame(frame, settings, resizeFrame)
    local size = math.max(12, math.floor(MARKER_FRAME_SIZE * (settings.scale or 1)))

    if resizeFrame then
        frame:SetSize(size, size)
    end
    frame.background:Hide()
end

local function ConfigureSymbol(frame, symbol)
    local settings = QuestMap:GetSettings()

    ConfigureMarkerFrame(frame, settings, true)
    frame.texture:Hide()
    HideTextures(frame.lines)
    HideTextures(frame.fills)
    ConfigureMarkerText(frame.text, symbol, settings)
end

local function ConfigureIcon(frame, texture)
    local settings = QuestMap:GetSettings()
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

local function GetWorldMapContentFrame()
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

local function GetMapPixelScale()
    local frame = GetWorldMapContentFrame()
    local width = frame and frame:GetWidth() or 700
    local height = frame and frame:GetHeight() or width
    return width / 100, height / 100
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

local function ConfigurePolygonFill(frame, points, minY, maxY, color, alpha)
    local fillIndex = 1

    for y = minY, maxY, AREA_FILL_STEP do
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
            fill:SetSize(width, AREA_FILL_STEP + 1)
            fill:SetPoint("CENTER", frame, "CENTER", x1 + (width / 2), y)
            fill:SetVertexColor(color[1], color[2], color[3], alpha)
            fillIndex = fillIndex + 1
        end
    end

    for index = fillIndex, #(frame.fills or {}) do
        frame.fills[index]:Hide()
    end
end

local function ConfigurePolygonArea(frame, cluster, quest)
    local settings = QuestMap:GetSettings()
    local color = AREA_COLOR
    local xScale, yScale = GetMapPixelScale()
    local points = {}
    local maxX = 0
    local maxY = 0
    local minY
    local maxFillY

    for index, point in ipairs(cluster.p) do
        local x = point[1] or point.x
        local y = point[2] or point.y
        local dx = x - cluster.x
        local dy = y - cluster.y
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
    ConfigureMarkerText(frame.text, quest.number, settings)

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

local function ConfigureCircleArea(frame, radius, quest)
    local settings = QuestMap:GetSettings()
    local xScale, yScale = GetMapPixelScale()
    local size = math.max(38, math.min(260, math.floor(((radius or 0) * 2 * math.min(xScale, yScale)) + 12)))
    local color = AREA_COLOR

    HideTextures(frame.lines)
    HideTextures(frame.fills)
    frame:SetSize(size, size)
    ConfigureMarkerFrame(frame, settings, false)
    frame.texture:Show()
    frame.texture:SetTexture(QuestMap.mediaPath .. "area-circle")
    if frame.texture.SetDrawLayer then
        frame.texture:SetDrawLayer("ARTWORK", -7)
    end
    if frame.texture.SetBlendMode then
        frame.texture:SetBlendMode("BLEND")
    end
    frame.texture:SetAllPoints(frame)
    frame.texture:SetVertexColor(color[1], color[2], color[3], math.min(0.95, (settings.opacity or 0.85) * 0.9))
    ConfigureMarkerText(frame.text, quest.number, settings)
end

local function ConfigureArea(frame, cluster, quest, kind)
    if cluster.p and #cluster.p >= 3 and ConfigurePolygonArea(frame, cluster, quest) then
        return
    end

    ConfigureCircleArea(frame, cluster.r, quest)
end

local function AcquireFrame(kind, poolKind, parent)
    local frame = table.remove(QuestMap.pool[poolKind])
    if frame then
        frame.kind = kind
        frame.poolKind = poolKind
        frame:Show()
        return frame
    end

    frame = CreateFrame("Button", nil, parent)
    frame.kind = kind
    frame.poolKind = poolKind
    frame.background = frame:CreateTexture(nil, "ARTWORK")
    frame.background:Hide()
    frame.texture = frame:CreateTexture(nil, kind == "area" and "ARTWORK" or "OVERLAY")
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame:SetScript("OnEnter", ShowTooltip)
    frame:SetScript("OnLeave", HideTooltip)
    frame:SetScript("OnClick", OpenQuestLog)
    frame:RegisterForClicks("LeftButtonUp")
    frame:EnableMouse(true)
    return frame
end

local function BuildPinData(quest, cluster)
    local localizedObjectives = QuestMap:GetLocalizedObjectives(quest, cluster)
    local localizedObjective = localizedObjectives and localizedObjectives[1] or cluster.o
    local kind = cluster.k or "object"
    local countText

    if kind ~= "slay" and kind ~= "loot" then
        countText = QuestMap:GetLocalizedCountText(cluster.merged and "nearby" or "area", cluster.c)
    end

    return {
        questId = quest.id,
        number = quest.number,
        title = QuestMap:GetLocalizedQuestTitle(quest, quest.id, quest.title),
        objective = localizedObjective,
        objectives = localizedObjectives,
        merged = cluster.merged,
        count = cluster.c,
        countText = countText,
    }
end

function QuestMap:ClearPins()
    if self.hbdPins then
        for _, frame in ipairs(self.frames) do
            self.hbdPins:RemoveWorldMapIcon(self, frame)
            frame.questMapData = nil
            frame:Hide()
            self.pool[frame.poolKind][#self.pool[frame.poolKind] + 1] = frame
        end
        for _, frame in ipairs(self.minimapFrames) do
            self.hbdPins:RemoveMinimapIcon(self, frame)
            frame.questMapData = nil
            frame:Hide()
            self.pool[frame.poolKind][#self.pool[frame.poolKind] + 1] = frame
        end
    end
    wipe(self.frames)
    wipe(self.minimapFrames)
end

function QuestMap:AddPins(uiMapId, clusters, quest)
    for _, cluster in ipairs(MergeIconClusters(uiMapId, clusters)) do
        self:AddPin(uiMapId, cluster.x, cluster.y, quest, cluster)
    end
    for _, cluster in ipairs(clusters) do
        self:AddMinimapPin(uiMapId, cluster.x, cluster.y, quest, cluster)
    end
end

function QuestMap:AddMinimapPin(uiMapId, x, y, quest, cluster)
    if not self.hbdPins or not uiMapId or not x or not y then
        return
    end

    local kind = cluster.k or "object"
    if kind == "slay" or kind == "loot" or kind == "turnin" then
        return
    end

    local marker = AcquireFrame("marker", "minimapMarker", Minimap)
    marker.questMapData = BuildPinData(quest, cluster)
    if ICON_TEXTURES[kind] then
        ConfigureIcon(marker, ICON_TEXTURES[kind])
    else
        ConfigureSymbol(marker, MARKER_SYMBOLS[kind] or quest.number)
    end

    marker:Hide()
    self.hbdPins:AddMinimapIconMap(self, marker, uiMapId, x / 100, y / 100, true, false)
    self.minimapFrames[#self.minimapFrames + 1] = marker
end

function QuestMap:AddPin(uiMapId, x, y, quest, cluster)
    if not self.hbdPins or not uiMapId or not x or not y then
        return
    end

    local showFlag = HBD_PINS_WORLDMAP_SHOW_WORLD or 3
    local kind = cluster.k or "object"
    local areaOnly = kind == "slay" or kind == "loot"
    local pinData = BuildPinData(quest, cluster)

    if areaOnly or (cluster.r or 0) > 2 then
        local area = AcquireFrame("area", "area", WorldMapFrame)
        area.questMapData = pinData
        ConfigureArea(area, cluster, quest, kind)
        self.hbdPins:AddWorldMapIconMap(self, area, uiMapId, x / 100, y / 100, showFlag)
        self.frames[#self.frames + 1] = area
    end

    if areaOnly then
        return
    end

    local marker = AcquireFrame("marker", "marker", WorldMapFrame)
    marker.questMapData = pinData
    if ICON_TEXTURES[kind] then
        ConfigureIcon(marker, ICON_TEXTURES[kind])
    else
        ConfigureSymbol(marker, MARKER_SYMBOLS[kind] or quest.number)
    end
    self.hbdPins:AddWorldMapIconMap(self, marker, uiMapId, x / 100, y / 100, showFlag)
    self.frames[#self.frames + 1] = marker
end
