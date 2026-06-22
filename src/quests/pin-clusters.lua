local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local PARENT_MAP_ICON_MERGE_DISTANCE = 13
local MERGEABLE_PARENT_MAP_ICON_KINDS = {
    talk = true,
}

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
    return MERGEABLE_PARENT_MAP_ICON_KINDS[kind] and currentMapId and currentMapId ~= uiMapId
end

local function Distance(a, b)
    return math.sqrt(((a.x or 0) - (Quests:GetClusterX(b) or 0)) ^ 2 + ((a.y or 0) - (Quests:GetClusterY(b) or 0)) ^ 2)
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
        x = Quests:GetClusterX(cluster),
        y = Quests:GetClusterY(cluster),
        c = Quests:GetClusterCount(cluster),
        k = Quests:GetClusterKind(cluster),
        r = Quests:GetClusterRadius(cluster),
        objectives = { Quests:GetClusterObjective(cluster) },
        clusters = { cluster },
    }
end

local function AddToClusterGroup(group, cluster)
    local weight = Quests:GetClusterCount(cluster)
    local total = group.c + weight
    local x = Quests:GetClusterX(cluster) or 0
    local y = Quests:GetClusterY(cluster) or 0

    group.x = ((group.x * group.c) + (x * weight)) / total
    group.y = ((group.y * group.c) + (y * weight)) / total
    group.c = total
    group.clusters[#group.clusters + 1] = cluster
    group.r = math.max(group.r or 0, Distance(group, cluster) + Quests:GetClusterRadius(cluster))
    AddUniqueObjective(group.objectives, Quests:GetClusterObjective(cluster))
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

function Quests:MergeParentMapIconClusters(uiMapId, clusters)
    local groups = {}
    local changed = false

    for _, cluster in ipairs(clusters) do
        local kind = self:GetClusterKind(cluster)
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
