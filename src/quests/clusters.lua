local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local CLUSTER_X = 1
local CLUSTER_Y = 2
local CLUSTER_RADIUS = 3
local CLUSTER_COUNT = 4
local CLUSTER_KIND = 5
local CLUSTER_OBJECTIVE = 6
local CLUSTER_SOURCE_TYPE = 7
local CLUSTER_SOURCE_ID = 8
local CLUSTER_TOOLTIP_NPCS = 9
local CLUSTER_DROP_RATES = 10
local CLUSTER_OBJECTIVE_INDEX = 11
local CLUSTER_POINTS = 12

local KIND_BY_ID = {
    "slay",
    "loot",
    "event",
    "object",
    "talk",
    "turnin",
    "available",
}

local SOURCE_TYPE_BY_ID = {
    "npc",
    "object",
    "item",
}

local function Decode(value, lookup)
    if type(value) == "number" then
        return lookup[value]
    end
    return value
end

function Quests:GetClusterX(cluster)
    return cluster and (cluster.x or cluster[CLUSTER_X])
end

function Quests:GetClusterY(cluster)
    return cluster and (cluster.y or cluster[CLUSTER_Y])
end

function Quests:GetClusterRadius(cluster)
    return cluster and (cluster.r or cluster[CLUSTER_RADIUS]) or 0
end

function Quests:GetClusterCount(cluster)
    return cluster and (cluster.c or cluster[CLUSTER_COUNT]) or 1
end

function Quests:GetClusterKind(cluster)
    return Decode(cluster and (cluster.k or cluster[CLUSTER_KIND]), KIND_BY_ID) or "object"
end

function Quests:GetClusterObjective(cluster)
    return cluster and (cluster.o or cluster[CLUSTER_OBJECTIVE])
end

function Quests:GetClusterSourceType(cluster)
    return Decode(cluster and (cluster.st or cluster[CLUSTER_SOURCE_TYPE]), SOURCE_TYPE_BY_ID)
end

function Quests:GetClusterSourceId(cluster)
    return cluster and (cluster.sid or cluster[CLUSTER_SOURCE_ID])
end

function Quests:GetClusterTooltipNpcIds(cluster)
    return cluster and (cluster.n or cluster[CLUSTER_TOOLTIP_NPCS])
end

function Quests:GetClusterDropRates(cluster)
    return cluster and (cluster.dr or cluster[CLUSTER_DROP_RATES])
end

function Quests:GetClusterObjectiveIndex(cluster)
    return cluster and (cluster.oi or cluster[CLUSTER_OBJECTIVE_INDEX])
end

function Quests:GetClusterPoints(cluster)
    return cluster and (cluster.p or cluster[CLUSTER_POINTS])
end

function Quests:GetClusterPointCount(cluster)
    local points = self:GetClusterPoints(cluster)
    if not points then
        return 0
    end
    if points[1] and type(points[1]) == "table" then
        return #points
    end
    return math.floor(#points / 2)
end

function Quests:GetClusterPoint(cluster, index)
    local points = self:GetClusterPoints(cluster)
    if not points then
        return nil, nil
    end

    local point = points[index]
    if type(point) == "table" then
        return point[1] or point.x, point[2] or point.y
    end

    local offset = (index * 2) - 1
    return points[offset], points[offset + 1]
end

function Quests:GetClusterDropRate(cluster, npcId)
    local dropRates = self:GetClusterDropRates(cluster)
    if not dropRates or not npcId then
        return nil
    end

    if type(dropRates[1]) == "table" then
        for _, entry in ipairs(dropRates) do
            if entry[1] == npcId then
                return entry[2]
            end
        end
        return nil
    end

    for index = 1, #dropRates, 2 do
        if dropRates[index] == npcId then
            return dropRates[index + 1]
        end
    end
    return nil
end
