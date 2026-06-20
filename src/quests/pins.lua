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
    available = "!",
    turnin = "?",
}

local ICON_TEXTURES = {
    talk = [[Interface\GossipFrame\GossipGossipIcon]],
}

local PARENT_MAP_ICON_MERGE_DISTANCE = 13
local MARKER_FRAME_SIZE = 16
local MARKER_COLOR = { 1, 0.82, 0.15 }
local HIGH_LEVEL_AVAILABLE_MARKER_ORANGE_COLOR = { 1, 0.48, 0.05 }
local HIGH_LEVEL_AVAILABLE_MARKER_RED_COLOR = { 1, 0.18, 0.12 }
local HIGH_LEVEL_AVAILABLE_MARKER_ORANGE_LEVEL_DELTA = 3
local HIGH_LEVEL_AVAILABLE_MARKER_RED_LEVEL_DELTA = 6
local LOW_LEVEL_AVAILABLE_MARKER_ALPHA = 0.30
local MARKER_FONT_SIZE = 9
local MARKER_ICON_SIZE = 12
local AREA_COLOR = { 0.5, 0.7, 0.9 }
local AREA_FILL_ALPHA = 0.5
local AREA_FILL_STEP = 4
local AREA_OUTLINE_THICKNESS = 1.5
local MARKER_CLUSTER_PIXEL_DISTANCE = 18
local TOOLTIP_TITLE_COLOR = { 1, 1, 1 }
local TOOLTIP_OBJECTIVE_COLOR = { 0.9, 0.82, 0.55 }
local TOOLTIP_METADATA_COLOR = { 0.56, 0.64, 0.72 }
local TOOLTIP_COUNT_COLOR = { 0.65, 0.85, 1 }
local TOOLTIP_AVAILABLE_FALLBACK_COLOR = { 0.7, 0.9, 0.65 }
local TOOLTIP_DIFFICULTY_COLORS = {
    trivial = { 0.55, 0.55, 0.55 },
    easy = { 0.25, 0.75, 0.25 },
    normal = { 1, 0.82, 0 },
    hard = { 1, 0.45, 0 },
    impossible = { 1, 0.1, 0.1 },
}
local WHITE_TEXTURE = [[Interface\Buttons\WHITE8X8]]
local WORLD_MAP_ID = 947

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
    if self.questsAreaFrames then
        for _, area in ipairs(self.questsAreaFrames) do
            area.questsHovered = hovered == true
            Quests:RefreshQuestAreaVisibility(area)
        end
        return
    end

    local area = self.questsAreaFrame
    if not area then
        return
    end

    area.questsHovered = hovered == true
    Quests:RefreshQuestAreaVisibility(area)
end

local function HideTooltip(self)
    SetHoveredArea(self, false)
    if GameTooltip:IsOwned(self) then
        GameTooltip:Hide()
    end
end

local function OpenQuestLog(self)
    if self.questsPassThroughClicks then
        return
    end

    local data = self.questsData
    if not data or not data.questId then
        return
    end
    Quests:OpenQuestLogToQuest(data.questId)
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

local function AddPinTooltipEntry(tooltip, data)
    if not data then
        return
    end

    local title = data.title
    if data.prefix then
        title = data.prefix .. " " .. title
    end

    AddTooltipLine(tooltip, title, data.titleColor or TOOLTIP_TITLE_COLOR, true)
    AddTooltipLines(tooltip, data.metadataLines, TOOLTIP_METADATA_COLOR)
    AddTooltipLines(tooltip, data.lines, TOOLTIP_OBJECTIVE_COLOR)

    if data.objectives and #data.objectives > 1 then
        AddTooltipLines(tooltip, data.objectives, TOOLTIP_OBJECTIVE_COLOR)
    else
        AddTooltipLine(tooltip, data.objective, TOOLTIP_OBJECTIVE_COLOR, true)
    end

    AddTooltipLine(tooltip, data.countText, TOOLTIP_COUNT_COLOR)
end

local function ShowTooltip(self)
    local data = self.questsData
    if not data then
        return
    end

    SetHoveredArea(self, true)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
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

    local title = data.title
    if data.prefix then
        title = data.prefix .. " " .. title
    end

    local titleColor = data.titleColor or TOOLTIP_TITLE_COLOR
    GameTooltip:SetText(title, titleColor[1], titleColor[2], titleColor[3])
    AddTooltipLines(GameTooltip, data.metadataLines, TOOLTIP_METADATA_COLOR)
    AddTooltipLines(GameTooltip, data.lines, TOOLTIP_OBJECTIVE_COLOR)

    if data.objectives and #data.objectives > 1 then
        AddTooltipLines(GameTooltip, data.objectives, TOOLTIP_OBJECTIVE_COLOR)
    else
        AddTooltipLine(GameTooltip, data.objective, TOOLTIP_OBJECTIVE_COLOR, true)
    end

    AddTooltipLine(GameTooltip, data.countText, TOOLTIP_COUNT_COLOR)
    GameTooltip:Show()
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
        frame.questsAreaFrames = nil
        frame.questsHovered = nil
        frame.questsPassThroughClicks = nil
        frame.UiMapID = nil
        frame.x = nil
        frame.y = nil
        frame:SetAlpha(1)
        frame:EnableMouse(true)
        if frame.SetPropagateMouseClicks then
            frame:SetPropagateMouseClicks(false)
        end
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

local function GetAvailableQuestLevel(dbQuest)
    if not dbQuest then
        return nil
    end

    return dbQuest.ql or dbQuest.rl
end

local function PastelizeColor(color)
    if not color then
        return TOOLTIP_AVAILABLE_FALLBACK_COLOR
    end

    local blend = 0.35
    return {
        color[1] + ((1 - color[1]) * blend),
        color[2] + ((1 - color[2]) * blend),
        color[3] + ((1 - color[3]) * blend),
    }
end

local function GetAvailableQuestTitleColor(dbQuest)
    local level = GetAvailableQuestLevel(dbQuest)

    if level and GetQuestDifficultyColor then
        local ok, color = pcall(GetQuestDifficultyColor, level)
        if ok and color then
            local red = color.r or color[1]
            local green = color.g or color[2]
            local blue = color.b or color[3]
            if red and green and blue then
                return PastelizeColor({ red, green, blue })
            end
        end
    end

    local playerLevel = UnitLevel and UnitLevel("player") or nil
    if not level or not playerLevel or playerLevel <= 0 then
        return TOOLTIP_AVAILABLE_FALLBACK_COLOR
    end

    local delta = level - playerLevel
    if delta >= 5 then
        return PastelizeColor(TOOLTIP_DIFFICULTY_COLORS.impossible)
    end
    if delta >= 3 then
        return PastelizeColor(TOOLTIP_DIFFICULTY_COLORS.hard)
    end
    if delta >= -2 then
        return PastelizeColor(TOOLTIP_DIFFICULTY_COLORS.normal)
    end
    if delta >= -5 then
        return PastelizeColor(TOOLTIP_DIFFICULTY_COLORS.easy)
    end
    return PastelizeColor(TOOLTIP_DIFFICULTY_COLORS.trivial)
end

local function BuildAvailablePinData(questId, dbQuest)
    local metadataLines = {}

    local hasQuestLevel = dbQuest.ql and dbQuest.ql > 0
    local questLabel = VanillaEnhanced:T("quests.static.available")
    local levelLabel

    if hasQuestLevel then
        metadataLines[#metadataLines + 1] = VanillaEnhanced:T("quests.static.availableQuestLevel", { level = dbQuest.ql })
    elseif dbQuest.rl and dbQuest.rl > 0 then
        levelLabel = VanillaEnhanced:T("quests.static.requiresLevel", { level = dbQuest.rl })
    end

    if not hasQuestLevel then
        metadataLines[#metadataLines + 1] = levelLabel and (questLabel .. " - " .. levelLabel) or questLabel
    end
    if hasQuestLevel and dbQuest.rl and dbQuest.rl > 0 and UnitLevel and UnitLevel("player") < dbQuest.rl then
        metadataLines[#metadataLines + 1] = VanillaEnhanced:T("quests.static.requiresLevel", { level = dbQuest.rl })
    end

    return {
        availableQuestId = questId,
        title = Quests:GetLocalizedQuestTitle(nil, questId, dbQuest.t),
        titleColor = GetAvailableQuestTitleColor(dbQuest),
        metadataLines = metadataLines,
    }
end

local function MarkerCandidateDistance(a, b, xScale, yScale)
    return math.sqrt(((((a.x or 0) - (b.x or 0)) * xScale) ^ 2) + ((((a.y or 0) - (b.y or 0)) * yScale) ^ 2))
end

local function GetMarkerSymbol(kind, fallback)
    return MARKER_SYMBOLS[kind] or fallback
end

local function InterpolateColor(fromColor, toColor, progress)
    return {
        fromColor[1] + ((toColor[1] - fromColor[1]) * progress),
        fromColor[2] + ((toColor[2] - fromColor[2]) * progress),
        fromColor[3] + ((toColor[3] - fromColor[3]) * progress),
    }
end

local function GetHighLevelAvailableMarkerColor(dbQuest, context)
    local playerLevel = context and context.playerLevel or (UnitLevel and UnitLevel("player") or 0)
    local questLevel = GetAvailableQuestLevel(dbQuest)

    if not playerLevel or playerLevel <= 0 or not questLevel or questLevel <= 0 then
        return nil
    end

    local levelDelta = questLevel - playerLevel
    if levelDelta < HIGH_LEVEL_AVAILABLE_MARKER_ORANGE_LEVEL_DELTA then
        return nil
    end
    if levelDelta >= HIGH_LEVEL_AVAILABLE_MARKER_RED_LEVEL_DELTA then
        return HIGH_LEVEL_AVAILABLE_MARKER_RED_COLOR
    end

    local progress = (levelDelta - HIGH_LEVEL_AVAILABLE_MARKER_ORANGE_LEVEL_DELTA)
        / (HIGH_LEVEL_AVAILABLE_MARKER_RED_LEVEL_DELTA - HIGH_LEVEL_AVAILABLE_MARKER_ORANGE_LEVEL_DELTA)
    return InterpolateColor(HIGH_LEVEL_AVAILABLE_MARKER_ORANGE_COLOR, HIGH_LEVEL_AVAILABLE_MARKER_RED_COLOR, progress)
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
    local xScale, yScale = GetMapPixelScale()
    local groupsByMap = {}

    for _, candidate in ipairs(self.markerCandidates) do
        AddMarkerRenderCandidate(groupsByMap, BuildMarkerRenderCandidate(candidate, currentMapId), xScale, yScale)
    end

    for uiMapId, groups in pairs(groupsByMap) do
        local showFlag = currentMapId and uiMapId == currentMapId
            and (HBD_PINS_WORLDMAP_SHOW_CURRENT or -1)
            or (HBD_PINS_WORLDMAP_SHOW_WORLD or 3)
        for _, group in ipairs(groups) do
            local marker = AcquireFrame("marker", "marker", WorldMapFrame)
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
            self.frames[#self.frames + 1] = marker
        end
    end
end

function Quests:ClearPins()
    if self.hbdPins then
        for _, frame in ipairs(self.frames) do
            self.hbdPins:RemoveWorldMapIcon(self, frame)
            frame.questsData = nil
            frame.questsAreaFrame = nil
            frame.questsAreaFrames = nil
            frame.questsHovered = nil
            frame.questsPassThroughClicks = nil
            frame:SetAlpha(1)
            frame:EnableMouse(true)
            if frame.SetPropagateMouseClicks then
                frame:SetPropagateMouseClicks(false)
            end
            frame:Hide()
            self.pool[frame.poolKind][#self.pool[frame.poolKind] + 1] = frame
        end
        for _, frame in ipairs(self.minimapFrames) do
            self.hbdPins:RemoveMinimapIcon(self, frame)
            frame.questsData = nil
            frame.questsAreaFrame = nil
            frame.questsAreaFrames = nil
            frame.questsHovered = nil
            frame.questsPassThroughClicks = nil
            frame:SetAlpha(1)
            frame:EnableMouse(true)
            if frame.SetPropagateMouseClicks then
                frame:SetPropagateMouseClicks(false)
            end
            frame:Hide()
            self.pool[frame.poolKind][#self.pool[frame.poolKind] + 1] = frame
        end
    end
    wipe(self.frames)
    wipe(self.minimapFrames)
    self.markerCandidates = {}
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

    local kind = cluster.k or "object"
    local areaOnly = kind == "slay" or kind == "loot"
    local pinData = BuildPinData(quest, cluster)
    local area

    if areaOnly or (cluster.r or 0) > 2 then
        area = AcquireFrame("area", "area", WorldMapFrame)
        area.questsData = pinData
        area.questsHovered = false
        ConfigureArea(area, cluster, quest, kind)
        self.hbdPins:AddWorldMapIconMap(self, area, uiMapId, x / 100, y / 100, HBD_PINS_WORLDMAP_SHOW_CURRENT or -1)
        self.frames[#self.frames + 1] = area
        self:RefreshQuestAreaVisibility(area)
    end

    self:AddMarkerCandidate(uiMapId, x, y, pinData, GetMarkerSymbol(kind, quest.number), area, nil, nil, ICON_TEXTURES[kind])
end

function Quests:AddAvailablePin(uiMapId, x, y, questId, dbQuest, cluster, context)
    if not self.hbdPins or not uiMapId or not x or not y then
        return
    end

    local opacityMultiplier = self.IsAvailableQuestBelowPlayerLevel
        and self:IsAvailableQuestBelowPlayerLevel(dbQuest, context)
        and LOW_LEVEL_AVAILABLE_MARKER_ALPHA
        or 1
    local color = GetHighLevelAvailableMarkerColor(dbQuest, context)

    self:AddMarkerCandidate(
        uiMapId,
        x,
        y,
        BuildAvailablePinData(questId, dbQuest),
        GetMarkerSymbol(cluster.k, MARKER_SYMBOLS.available),
        nil,
        opacityMultiplier,
        color
    )
end
