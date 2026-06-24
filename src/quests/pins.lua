local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local SELECTED_QUEST_DIRECTION_OWNER = "quests-selected"

local function GetMapModule()
    local map = VanillaEnhanced.modules and VanillaEnhanced.modules.map
    if map and map.SetDirectionTargets then
        return map
    end
    return nil
end

local function ClearSelectedQuestDirectionTarget()
    local map = GetMapModule()
    if map and map.ClearDirectionTargets then
        map:ClearDirectionTargets(SELECTED_QUEST_DIRECTION_OWNER)
    end
end

local function FindQuestById(quests, questId)
    if not questId then
        return nil
    end

    for _, quest in ipairs(quests or {}) do
        if quest.id == questId then
            return quest
        end
    end
    return nil
end

local function GetPlayerPosition(self)
    if not self.hbd or not self.hbd.GetPlayerZonePosition then
        return nil
    end

    local x, y, uiMapId = self.hbd:GetPlayerZonePosition(true)
    if not x or not y or not uiMapId then
        return nil
    end

    return {
        x = x,
        y = y,
        uiMapId = uiMapId,
    }
end

local function GetClusterDistance(self, position, uiMapId, cluster)
    if not position or not self.hbd or not self.hbd.GetZoneDistance then
        return nil
    end
    local x = self:GetClusterX(cluster)
    local y = self:GetClusterY(cluster)
    if not x or not y then
        return nil
    end

    return self.hbd:GetZoneDistance(
        position.uiMapId,
        position.x,
        position.y,
        uiMapId,
        x / 100,
        y / 100
    )
end

local function IsSelectedDirectionClusterVisible(self, quest, dbQuest, cluster)
    return quest.isComplete or self:ShouldShowObjectiveCluster(quest, cluster, "map", dbQuest)
end

local function GetBestSelectedDirectionCluster(self, quest, dbQuest, maps)
    local position = GetPlayerPosition(self)
    local best
    local bestDistance

    for uiMapId, clusters in pairs(maps or {}) do
        for _, cluster in ipairs(clusters or {}) do
            if self:GetClusterX(cluster) and self:GetClusterY(cluster) and IsSelectedDirectionClusterVisible(self, quest, dbQuest, cluster) then
                local distance = GetClusterDistance(self, position, uiMapId, cluster)
                if distance then
                    if not bestDistance or distance < bestDistance then
                        best = {
                            uiMapId = uiMapId,
                            cluster = cluster,
                        }
                        bestDistance = distance
                    end
                elseif not best then
                    best = {
                        uiMapId = uiMapId,
                        cluster = cluster,
                    }
                end
            end
        end
    end

    return best
end

local function BuildSelectedQuestDirectionTarget(self, quest, dbQuest)
    local maps = quest.isComplete and dbQuest.turnins or dbQuest.maps
    maps = maps or dbQuest.maps
    local best = GetBestSelectedDirectionCluster(self, quest, dbQuest, maps)
    local cluster = best and best.cluster
    if not best or not cluster then
        return nil
    end

    return {
        uiMapId = best.uiMapId,
        x = self:GetClusterX(cluster) / 100,
        y = self:GetClusterY(cluster) / 100,
        title = quest.title,
    }
end

function Quests:RefreshSelectedQuestDirection(quests, settings)
    settings = settings or self:GetSettings()
    local selectedQuestId = self.selectedQuestAreaQuestId or self.selectedQuestDirectionQuestId

    if not settings.enabled
        or settings.showMapMarkers == false
        or settings.showSelectedQuestDirection ~= true
        or not selectedQuestId then
        ClearSelectedQuestDirectionTarget()
        return
    end

    if not VanillaEnhancedQuestsDB or not VanillaEnhancedQuestsDB.quests then
        ClearSelectedQuestDirectionTarget()
        return
    end

    local quest = FindQuestById(quests or self:GetCachedQuestLogSnapshot(), selectedQuestId)
    local dbQuest = quest and VanillaEnhancedQuestsDB.quests[quest.id]
    if not quest or not dbQuest or not dbQuest.maps or not self:ShouldShowQuestOnMaps(dbQuest, settings) then
        ClearSelectedQuestDirectionTarget()
        return
    end

    local map = GetMapModule()
    local target = BuildSelectedQuestDirectionTarget(self, quest, dbQuest)
    if map and target then
        map:SetDirectionTargets(SELECTED_QUEST_DIRECTION_OWNER, { target })
        return
    end

    ClearSelectedQuestDirectionTarget()
end

local function HasAreaGeometry(cluster)
    return Quests:GetClusterPointCount(cluster) >= 3 or Quests:GetClusterRadius(cluster) > 0
end

function Quests:AddPins(uiMapId, clusters, quest)
    local visibleClusters = {}
    local dbQuest = VanillaEnhancedQuestsDB and VanillaEnhancedQuestsDB.quests and VanillaEnhancedQuestsDB.quests[quest.id]

    for _, cluster in ipairs(clusters) do
        if self:ShouldShowObjectiveCluster(quest, cluster, "map", dbQuest) then
            visibleClusters[#visibleClusters + 1] = cluster
        end
    end

    self:AddVisibleWorldMapPins(uiMapId, visibleClusters, quest)
    for _, cluster in ipairs(visibleClusters) do
        self:AddMinimapPin(uiMapId, self:GetClusterX(cluster), self:GetClusterY(cluster), quest, cluster)
    end
end

function Quests:AddVisibleWorldMapPins(uiMapId, visibleClusters, quest)
    for _, cluster in ipairs(self:MergeParentMapIconClusters(uiMapId, visibleClusters)) do
        self:AddPin(uiMapId, self:GetClusterX(cluster), self:GetClusterY(cluster), quest, cluster)
    end
end

function Quests:AddWorldMapPins(uiMapId, clusters, quest)
    local visibleClusters = {}
    local dbQuest = VanillaEnhancedQuestsDB and VanillaEnhancedQuestsDB.quests and VanillaEnhancedQuestsDB.quests[quest.id]

    for _, cluster in ipairs(clusters) do
        if self:ShouldShowObjectiveCluster(quest, cluster, "map", dbQuest) then
            visibleClusters[#visibleClusters + 1] = cluster
        end
    end

    self:AddVisibleWorldMapPins(uiMapId, visibleClusters, quest)
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
            self:AddAvailablePin(uiMapId, self:GetClusterX(cluster), self:GetClusterY(cluster), questId, dbQuest, cluster, context)
        end
    end
end

function Quests:AddMinimapPin(uiMapId, x, y, quest, cluster)
    if not self.hbdPins or not uiMapId or not x or not y then
        return
    end

    local kind = self:GetClusterKind(cluster)
    local dbQuest = VanillaEnhancedQuestsDB and VanillaEnhancedQuestsDB.quests and VanillaEnhancedQuestsDB.quests[quest.id]
    if kind == "turnin" then
        return
    end

    local pinData = self:BuildQuestPinData(quest, cluster)
    if HasAreaGeometry(cluster) and (self:IsQuestObjectiveAreaKind(kind) or self:GetClusterRadius(cluster) > 2) then
        if self:GetSettings().showMinimapObjectiveAreas == false then
            return
        end
        if self:AddMinimapArea(uiMapId, x, y, pinData, cluster) then
            return
        end
    end

    local marker = self:AcquirePinFrame("marker", "minimapMarker", Minimap)
    marker.questsData = pinData
    marker.questsMinimapUiMapId = uiMapId
    local texture = self:GetPinMarkerTexture(kind)
    local color = self:GetRepeatableQuestMarkerColor(dbQuest)
    if texture then
        self:ConfigurePinIcon(marker, texture, nil, color)
    else
        self:ConfigurePinSymbol(marker, self:GetPinMarkerSymbol(kind, quest.number), nil, color)
    end
    self:ApplyMinimapFloorDimming(marker)

    marker:Hide()
    self:RaiseMinimapMarkerFrame(marker)
    self.hbdPins:AddMinimapIconMap(self, marker, uiMapId, x / 100, y / 100, true, false)
    self:TrackMinimapPinFrame(marker)
end

function Quests:AddPin(uiMapId, x, y, quest, cluster)
    if not self.hbdPins or not uiMapId or not x or not y then
        return
    end
    if self.IsQuestWorldMapLocationVisible and not self:IsQuestWorldMapLocationVisible(uiMapId, x, y, true) then
        return
    end

    local kind = self:GetClusterKind(cluster)
    local areaOnly = self:IsQuestObjectiveAreaKind(kind)
    local dbQuest = VanillaEnhancedQuestsDB and VanillaEnhancedQuestsDB.quests and VanillaEnhancedQuestsDB.quests[quest.id]
    local pinData = self:BuildQuestPinData(quest, cluster)
    local area

    if HasAreaGeometry(cluster) and (areaOnly or self:GetClusterRadius(cluster) > 2) then
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
        self:GetRepeatableQuestMarkerColor(dbQuest),
        self:GetPinMarkerTexture(kind)
    )
end
function Quests:AddAvailablePin(uiMapId, x, y, questId, dbQuest, cluster, context)
    if not self.hbdPins or not uiMapId or not x or not y then
        return
    end
    if self.IsQuestWorldMapLocationVisible and not self:IsQuestWorldMapLocationVisible(uiMapId, x, y, true) then
        return
    end

    local opacityMultiplier = self:GetAvailableQuestMarkerOpacity(dbQuest, context)
    local color = self:GetRepeatableQuestMarkerColor(dbQuest) or self:GetAvailableQuestMarkerColor(dbQuest, context)

    self:AddMarkerCandidate(
        uiMapId,
        x,
        y,
        self:BuildAvailableQuestPinData(questId, dbQuest, cluster, uiMapId, x, y),
        self:GetPinMarkerSymbol(self:GetClusterKind(cluster), self:GetPinMarkerSymbol("available")),
        nil,
        opacityMultiplier,
        color
    )
end
