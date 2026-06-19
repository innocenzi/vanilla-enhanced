local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

Quests.frames = Quests.frames or {}
Quests.minimapFrames = Quests.minimapFrames or {}
Quests.pool = Quests.pool or {
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
local MARKER_SPREAD_DETECTION_RADIUS = 8
local MARKER_SPREAD_RADIUS = 6
local MARKER_SPREAD_RESET_DELAY = 0.08
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

local function SetAreaRevealed(frame, revealed)
    if not frame or frame.kind ~= "area" then
        return
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

function Quests:SetSelectedQuestAreaQuest(questId)
    self.selectedQuestAreaQuestId = questId
    self:RefreshQuestAreaVisibility()
end

local function SetHoveredArea(self, hovered)
    local area = self.questsAreaFrame
    if not area then
        return
    end

    area.questsHovered = hovered == true
    Quests:RefreshQuestAreaVisibility(area)
end

local function IsWorldMapMarker(frame)
    return frame and frame.kind == "marker" and frame.poolKind == "marker"
end

local function GetMarkerAnchorCenter(frame)
    local parent = frame and frame:GetParent()
    if parent and parent.GetCenter then
        return parent:GetCenter()
    end
    if frame and frame.GetCenter then
        return frame:GetCenter()
    end
    return nil, nil
end

local function ResetMarkerOffset(frame)
    if not IsWorldMapMarker(frame) then
        return
    end

    local parent = frame:GetParent()
    if not parent then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
    frame.questsSpreadActive = nil
    frame.questsSpreadHovered = nil
end

local function ApplyMarkerOffset(frame, xOffset, yOffset)
    if not IsWorldMapMarker(frame) then
        return
    end

    local parent = frame:GetParent()
    if not parent then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", parent, "CENTER", xOffset or 0, yOffset or 0)
    frame.questsSpreadActive = true
end

local function CompareMarkerAngles(a, b)
    if a.angle == b.angle then
        return tostring(a.frame) < tostring(b.frame)
    end
    return a.angle < b.angle
end

function Quests:ResetMarkerSpread()
    for _, frame in ipairs(self.markerSpreadFrames or {}) do
        ResetMarkerOffset(frame)
    end
    wipe(self.markerSpreadFrames or {})
end

local function HasHoveredSpreadMarker()
    for _, frame in ipairs(Quests.markerSpreadFrames or {}) do
        if frame.questsSpreadHovered then
            return true
        end
    end
    return false
end

function Quests:ScheduleMarkerSpreadReset()
    self.markerSpreadResetToken = (self.markerSpreadResetToken or 0) + 1
    local token = self.markerSpreadResetToken

    if not C_Timer or not C_Timer.After then
        self:ResetMarkerSpread()
        return
    end

    C_Timer.After(MARKER_SPREAD_RESET_DELAY, function()
        if Quests.markerSpreadResetToken == token and not HasHoveredSpreadMarker() then
            Quests:ResetMarkerSpread()
        end
    end)
end

function Quests:SpreadNearbyMarkers(origin)
    if not IsWorldMapMarker(origin) then
        return
    end

    local settings = self:GetSettings()
    if settings.spreadOverlappingMarkers ~= true then
        return
    end

    self.markerSpreadResetToken = (self.markerSpreadResetToken or 0) + 1
    self:ResetMarkerSpread()
    self.markerSpreadFrames = self.markerSpreadFrames or {}

    local originX, originY = GetMarkerAnchorCenter(origin)
    if not originX or not originY then
        return
    end

    local cluster = {}
    for _, frame in ipairs(self.frames) do
        if IsWorldMapMarker(frame) and frame:IsShown() then
            local x, y = GetMarkerAnchorCenter(frame)
            if x and y then
                local distance = math.sqrt(((x - originX) ^ 2) + ((y - originY) ^ 2))
                if distance <= MARKER_SPREAD_DETECTION_RADIUS then
                    local angle = Atan2(y - originY, x - originX)
                    cluster[#cluster + 1] = {
                        frame = frame,
                        angle = angle,
                    }
                end
            end
        end
    end

    if #cluster < 2 then
        return
    end

    table.sort(cluster, CompareMarkerAngles)
    local step = (math.pi * 2) / #cluster
    local start = -math.pi / 2

    for index, entry in ipairs(cluster) do
        local frame = entry.frame
        local angle = start + ((index - 1) * step)
        local radius = frame == origin and 0 or MARKER_SPREAD_RADIUS

        ApplyMarkerOffset(frame, math.cos(angle) * radius, math.sin(angle) * radius)
        frame.questsSpreadHovered = frame == origin
        self.markerSpreadFrames[#self.markerSpreadFrames + 1] = frame
    end
end

local function HideTooltip(self)
    SetHoveredArea(self, false)
    if IsWorldMapMarker(self) then
        self.questsSpreadHovered = false
        Quests:ScheduleMarkerSpreadReset()
    end
    if GameTooltip:IsOwned(self) then
        GameTooltip:Hide()
    end
end

local function OpenQuestLog(self)
    local data = self.questsData
    if not data or not data.questId then
        return
    end
    Quests:OpenQuestLogToQuest(data.questId)
end

local function ShowTooltip(self)
    local data = self.questsData
    if not data then
        return
    end

    SetHoveredArea(self, true)
    if IsWorldMapMarker(self) then
        self.questsSpreadHovered = true
        if not self.questsSpreadActive then
            Quests:SpreadNearbyMarkers(self)
        end
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
    fontString:Show()
    fontString:SetText(tostring(symbol))
    fontString:SetTextColor(MARKER_COLOR[1], MARKER_COLOR[2], MARKER_COLOR[3], settings.opacity or 1)
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

local function ConfigureSymbol(frame, symbol)
    local settings = Quests:GetSettings()

    ConfigureMarkerFrame(frame, settings, true)
    frame.texture:Hide()
    HideTextures(frame.lines)
    HideTextures(frame.fills)
    ConfigureMarkerText(frame.text, symbol, settings)
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
    local settings = Quests:GetSettings()
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

local function ConfigureCircleArea(frame, radius, quest)
    local settings = Quests:GetSettings()
    local xScale, yScale = GetMapPixelScale()
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

local function ConfigureArea(frame, cluster, quest, kind)
    if cluster.p and #cluster.p >= 3 and ConfigurePolygonArea(frame, cluster, quest) then
        return
    end

    ConfigureCircleArea(frame, cluster.r, quest)
end

local function AcquireFrame(kind, poolKind, parent)
    local frame = table.remove(Quests.pool[poolKind])
    if frame then
        frame.kind = kind
        frame.poolKind = poolKind
        frame.questsAreaFrame = nil
        frame.questsHovered = nil
        frame.questsSpreadActive = nil
        frame.questsSpreadHovered = nil
        frame:SetAlpha(1)
        frame:EnableMouse(true)
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
    local localizedObjectives = Quests:GetLocalizedObjectives(quest, cluster)
    local localizedObjective = localizedObjectives and localizedObjectives[1] or cluster.o
    local kind = cluster.k or "object"
    local countText

    if kind ~= "slay" and kind ~= "loot" then
        countText = Quests:GetLocalizedCountText(cluster.merged and "nearby" or "area", cluster.c)
    end

    return {
        questId = quest.id,
        number = quest.number,
        title = Quests:GetLocalizedQuestTitle(quest, quest.id, quest.title),
        objective = localizedObjective,
        objectives = localizedObjectives,
        merged = cluster.merged,
        count = cluster.c,
        countText = countText,
    }
end

function Quests:ClearPins()
    if self.ResetMarkerSpread then
        self:ResetMarkerSpread()
    end

    if self.hbdPins then
        for _, frame in ipairs(self.frames) do
            self.hbdPins:RemoveWorldMapIcon(self, frame)
            frame.questsData = nil
            frame.questsAreaFrame = nil
            frame.questsHovered = nil
            frame.questsSpreadActive = nil
            frame.questsSpreadHovered = nil
            frame:SetAlpha(1)
            frame:EnableMouse(true)
            frame:Hide()
            self.pool[frame.poolKind][#self.pool[frame.poolKind] + 1] = frame
        end
        for _, frame in ipairs(self.minimapFrames) do
            self.hbdPins:RemoveMinimapIcon(self, frame)
            frame.questsData = nil
            frame.questsAreaFrame = nil
            frame.questsHovered = nil
            frame.questsSpreadActive = nil
            frame.questsSpreadHovered = nil
            frame:SetAlpha(1)
            frame:EnableMouse(true)
            frame:Hide()
            self.pool[frame.poolKind][#self.pool[frame.poolKind] + 1] = frame
        end
    end
    wipe(self.frames)
    wipe(self.minimapFrames)
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

function Quests:AddMinimapPin(uiMapId, x, y, quest, cluster)
    if not self.hbdPins or not uiMapId or not x or not y then
        return
    end

    local kind = cluster.k or "object"
    if kind == "slay" or kind == "loot" or kind == "turnin" then
        return
    end

    local marker = AcquireFrame("marker", "minimapMarker", Minimap)
    marker.questsData = BuildPinData(quest, cluster)
    if ICON_TEXTURES[kind] then
        ConfigureIcon(marker, ICON_TEXTURES[kind])
    else
        ConfigureSymbol(marker, MARKER_SYMBOLS[kind] or quest.number)
    end

    marker:Hide()
    self.hbdPins:AddMinimapIconMap(self, marker, uiMapId, x / 100, y / 100, true, false)
    self.minimapFrames[#self.minimapFrames + 1] = marker
end

function Quests:AddPin(uiMapId, x, y, quest, cluster)
    if not self.hbdPins or not uiMapId or not x or not y then
        return
    end

    local showFlag = HBD_PINS_WORLDMAP_SHOW_WORLD or 3
    local kind = cluster.k or "object"
    local areaOnly = kind == "slay" or kind == "loot"
    local pinData = BuildPinData(quest, cluster)
    local area

    if areaOnly or (cluster.r or 0) > 2 then
        area = AcquireFrame("area", "area", WorldMapFrame)
        area.questsData = pinData
        area.questsHovered = false
        ConfigureArea(area, cluster, quest, kind)
        self.hbdPins:AddWorldMapIconMap(self, area, uiMapId, x / 100, y / 100, showFlag)
        self.frames[#self.frames + 1] = area
        self:RefreshQuestAreaVisibility(area)
    end

    local marker = AcquireFrame("marker", "marker", WorldMapFrame)
    marker.questsData = pinData
    marker.questsAreaFrame = area
    if ICON_TEXTURES[kind] then
        ConfigureIcon(marker, ICON_TEXTURES[kind])
    else
        ConfigureSymbol(marker, MARKER_SYMBOLS[kind] or quest.number)
    end
    self.hbdPins:AddWorldMapIconMap(self, marker, uiMapId, x / 100, y / 100, showFlag)
    self.frames[#self.frames + 1] = marker
end
