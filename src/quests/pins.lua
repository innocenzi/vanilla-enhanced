local Quests = _G.VanillaEnhanced:GetModule("quests")

function Quests:AddPins(uiMapId, clusters, quest)
    local visibleClusters = {}

    for _, cluster in ipairs(clusters) do
        if self:ShouldShowObjectiveCluster(quest, cluster, "map") then
            visibleClusters[#visibleClusters + 1] = cluster
        end
    end

    for _, cluster in ipairs(self:MergeParentMapIconClusters(uiMapId, visibleClusters)) do
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
        for _, cluster in ipairs(self:MergeParentMapIconClusters(uiMapId, visibleClusters)) do
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
    if self:IsQuestObjectiveAreaKind(kind) then
        if self:GetSettings().showMinimapObjectiveAreas == false then
            return
        end
        self:AddMinimapArea(uiMapId, x, y, pinData, cluster)
        return
    end

    local marker = self:AcquirePinFrame("marker", "minimapMarker", Minimap)
    marker.questsData = pinData
    local texture = self:GetPinMarkerTexture(kind)
    if texture then
        self:ConfigurePinIcon(marker, texture)
    else
        self:ConfigurePinSymbol(marker, self:GetPinMarkerSymbol(kind, quest.number))
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
    local areaOnly = self:IsQuestObjectiveAreaKind(kind)
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

    self:AddMarkerCandidate(
        uiMapId,
        x,
        y,
        pinData,
        self:GetPinMarkerSymbol(kind, quest.number),
        area,
        nil,
        nil,
        self:GetPinMarkerTexture(kind)
    )
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
        self:GetPinMarkerSymbol(cluster.k, self:GetPinMarkerSymbol("available")),
        nil,
        opacityMultiplier,
        color
    )
end
