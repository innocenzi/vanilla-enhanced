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

local function GetMarkerSymbol(kind, fallback)
    return MARKER_SYMBOLS[kind] or fallback
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
        self:ConfigurePinIcon(marker, ICON_TEXTURES[kind])
    else
        self:ConfigurePinSymbol(marker, MARKER_SYMBOLS[kind] or quest.number)
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
