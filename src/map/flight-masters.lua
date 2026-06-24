local VanillaEnhanced = _G.VanillaEnhanced
local Map = VanillaEnhanced:GetModule("map")

local COORDINATE_PRECISION = 100000
local LEARNED_TAXI_NODE_TYPES = {
    CURRENT = true,
    REACHABLE = true,
}

local function RoundCoordinate(value)
    value = tonumber(value) or 0
    return math.floor((value * COORDINATE_PRECISION) + 0.5) / COORDINATE_PRECISION
end

local function Trim(value)
    if type(value) ~= "string" then
        return nil
    end

    value = string.gsub(value, "^%s*(.-)%s*$", "%1")
    if value == "" then
        return nil
    end
    return value
end

local function NormalizeName(value)
    value = Trim(value)
    if not value then
        return nil
    end
    value = string.lower(value)
    value = string.gsub(value, "^les%s+", "")
    value = string.gsub(value, "^le%s+", "")
    value = string.gsub(value, "^la%s+", "")
    value = string.gsub(value, "^l['’]", "")
    return value
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local results = { pcall(fn, ...) }
    if not results[1] then
        return nil
    end
    return unpack(results, 2)
end

local function AddMapCandidate(candidates, seen, uiMapId)
    uiMapId = tonumber(uiMapId)
    if not uiMapId or seen[uiMapId] then
        return
    end

    seen[uiMapId] = true
    candidates[#candidates + 1] = uiMapId
end

local function AddMapAndParents(candidates, seen, uiMapId)
    while uiMapId and uiMapId ~= 0 do
        AddMapCandidate(candidates, seen, uiMapId)
        if not C_Map or not C_Map.GetMapInfo then
            return
        end

        local info = SafeCall(C_Map.GetMapInfo, uiMapId)
        uiMapId = info and info.parentMapID or nil
    end
end

local function GetFrameMapId(frame)
    if not frame then
        return nil
    end
    if frame.GetMapID then
        local uiMapId = SafeCall(frame.GetMapID, frame)
        if uiMapId then
            return uiMapId
        end
    end
    return frame.mapID or frame.mapId or frame.uiMapID or frame.uiMapId
end

local function GetCurrentWorldMapId()
    if WorldMapFrame then
        if WorldMapFrame.mapID then
            return WorldMapFrame.mapID
        end
        if WorldMapFrame.mapId then
            return WorldMapFrame.mapId
        end
        if WorldMapFrame.uiMapID then
            return WorldMapFrame.uiMapID
        end
        if WorldMapFrame.uiMapId then
            return WorldMapFrame.uiMapId
        end
        if WorldMapFrame.GetMapID then
            local uiMapId = SafeCall(WorldMapFrame.GetMapID, WorldMapFrame)
            if uiMapId then
                return uiMapId
            end
        end
    end
    return nil
end

local function GetMapArea(data)
    if not data then
        return 0
    end
    return (tonumber(data[1]) or 0) * (tonumber(data[2]) or 0)
end

local function IsContinentMap(uiMapId)
    local data = Map.hbd and Map.hbd.mapData and Map.hbd.mapData[uiMapId] or nil
    if not data or not Enum or not Enum.UIMapType then
        return false
    end
    return data.mapType == Enum.UIMapType.Continent
end

local function FilterContinentMaps(candidates)
    local continentMaps = {}
    for _, uiMapId in ipairs(candidates or {}) do
        if IsContinentMap(uiMapId) then
            continentMaps[#continentMaps + 1] = uiMapId
        end
    end
    return continentMaps
end

local function SortMapsByAreaDescending(candidates)
    if Map.hbd and Map.hbd.mapData then
        table.sort(candidates, function(left, right)
            return GetMapArea(Map.hbd.mapData[left]) > GetMapArea(Map.hbd.mapData[right])
        end)
    end
    return candidates
end

local function GetTaxiSourceMapCandidates(continentOnly)
    local candidates = {}
    local seen = {}

    AddMapAndParents(candidates, seen, GetFrameMapId(_G.FlightMapFrame))
    AddMapAndParents(candidates, seen, GetFrameMapId(_G.TaxiFrame))
    AddMapAndParents(candidates, seen, GetCurrentWorldMapId())

    if C_Map and C_Map.GetBestMapForUnit then
        AddMapAndParents(candidates, seen, SafeCall(C_Map.GetBestMapForUnit, "player"))
    end

    candidates = SortMapsByAreaDescending(candidates)
    if continentOnly then
        local continentMaps = FilterContinentMaps(candidates)
        if #continentMaps > 0 then
            return continentMaps
        end
    end
    return candidates
end

local function IsTargetMapType(mapType)
    if not Enum or not Enum.UIMapType then
        return true
    end

    if mapType == Enum.UIMapType.Dungeon or mapType == Enum.UIMapType.Micro then
        return false
    end
    if mapType == Enum.UIMapType.Cosmic or mapType == Enum.UIMapType.World or mapType == Enum.UIMapType.Continent then
        return false
    end
    return mapType == Enum.UIMapType.Zone or mapType == Enum.UIMapType.Orphan or mapType == nil
end

local function GetTaxiNodeZoneHint(name)
    name = Trim(name)
    if not name then
        return nil
    end

    local hint
    for part in string.gmatch(name, "[^,]+") do
        hint = Trim(part)
    end
    return NormalizeName(hint)
end

local function GetMapName(uiMapId)
    if Map.hbd and Map.hbd.GetLocalizedMap then
        local name = Map.hbd:GetLocalizedMap(uiMapId)
        if name and name ~= "" then
            return name
        end
    end
    if C_Map and C_Map.GetMapInfo then
        local info = SafeCall(C_Map.GetMapInfo, uiMapId)
        if info and info.name then
            return info.name
        end
    end
    return nil
end

function Map:FindFlightMasterTargetMapByName(name)
    local hint = GetTaxiNodeZoneHint(name)
    if not hint or not self.hbd or not self.hbd.mapData then
        return nil
    end

    for uiMapId, data in pairs(self.hbd.mapData) do
        if data and IsTargetMapType(data.mapType) then
            local mapName = NormalizeName(GetMapName(uiMapId))
            if mapName and (mapName == hint or string.find(mapName, hint, 1, true) or string.find(hint, mapName, 1, true)) then
                return uiMapId
            end
        end
    end
    return nil
end

function Map:GetKnownFlightMasterStore()
    local settings = self:GetSettings()
    if type(settings.knownFlightMasters) ~= "table" then
        settings.knownFlightMasters = {}
    end
    return settings.knownFlightMasters
end

function Map:GetFlightMasterTargetMaps()
    if self.flightMasterTargetMaps then
        return self.flightMasterTargetMaps
    end

    local targetMaps = {}
    local hbd = self.hbd
    if not hbd or not hbd.mapData then
        return targetMaps
    end

    for uiMapId, data in pairs(hbd.mapData) do
        if data and data[1] and data[2] and data[1] > 0 and data[2] > 0 and IsTargetMapType(data.mapType) then
            targetMaps[#targetMaps + 1] = {
                id = uiMapId,
                area = GetMapArea(data),
            }
        end
    end

    table.sort(targetMaps, function(left, right)
        return left.area < right.area
    end)

    self.flightMasterTargetMaps = targetMaps
    return targetMaps
end

local function ResolveWorldPositionToTargetMap(worldX, worldY, instanceId)
    if not Map.hbd or not Map.hbd.GetZoneCoordinatesFromWorld or not Map.hbd.GetWorldCoordinatesFromZone then
        return nil, nil, nil
    end

    for _, targetMap in ipairs(Map:GetFlightMasterTargetMaps()) do
        local x, y = Map.hbd:GetZoneCoordinatesFromWorld(worldX, worldY, targetMap.id)
        if x and y then
            local _, _, targetInstanceId = Map.hbd:GetWorldCoordinatesFromZone(x, y, targetMap.id)
            if targetInstanceId == instanceId then
                return targetMap.id, RoundCoordinate(x), RoundCoordinate(y)
            end
        end
    end
    return nil, nil, nil
end

local function ResolveNodePositionFromMap(uiMapId, x, y)
    if not Map.hbd or not Map.hbd.GetWorldCoordinatesFromZone then
        return nil, nil, nil
    end
    if type(uiMapId) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil, nil, nil
    end
    if x < 0 or x > 1 or y < 0 or y > 1 then
        return nil, nil, nil
    end

    local worldX, worldY, instanceId = Map.hbd:GetWorldCoordinatesFromZone(x, y, uiMapId)
    if not worldX or not worldY or not instanceId then
        return nil, nil, nil
    end

    local targetMapId, targetX, targetY = ResolveWorldPositionToTargetMap(worldX, worldY, instanceId)
    if targetMapId then
        return targetMapId, targetX, targetY
    end

    if Map.CanPlaceMarker and Map:CanPlaceMarker(uiMapId, x, y) then
        return uiMapId, RoundCoordinate(x), RoundCoordinate(y)
    end
    return nil, nil, nil
end

local function ResolveNodePositionOnTargetMap(sourceMapId, x, y, targetMapId)
    if not Map.hbd or not Map.hbd.GetWorldCoordinatesFromZone or not Map.hbd.GetZoneCoordinatesFromWorld then
        return nil, nil, nil
    end
    if type(sourceMapId) ~= "number" or type(targetMapId) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        return nil, nil, nil
    end
    if x < 0 or x > 1 or y < 0 or y > 1 then
        return nil, nil, nil
    end

    local worldX, worldY, instanceId = Map.hbd:GetWorldCoordinatesFromZone(x, y, sourceMapId)
    local data = Map.hbd.mapData and Map.hbd.mapData[targetMapId] or nil
    if not worldX or not worldY or not instanceId or not data or data.instance ~= instanceId then
        return nil, nil, nil
    end

    local targetX, targetY = Map.hbd:GetZoneCoordinatesFromWorld(worldX, worldY, targetMapId)
    if targetX and targetY and Map.CanPlaceMarker and Map:CanPlaceMarker(targetMapId, targetX, targetY) then
        return targetMapId, RoundCoordinate(targetX), RoundCoordinate(targetY)
    end
    return nil, nil, nil
end

local function ResolveNodePosition(sourceMapId, x, y, candidates, targetMapId)
    local uiMapId, mapX, mapY = ResolveNodePositionOnTargetMap(sourceMapId, x, y, targetMapId)
    if uiMapId then
        return uiMapId, mapX, mapY
    end

    uiMapId, mapX, mapY = ResolveNodePositionFromMap(sourceMapId, x, y)
    if uiMapId then
        return uiMapId, mapX, mapY
    end

    for _, candidateMapId in ipairs(candidates or {}) do
        uiMapId, mapX, mapY = ResolveNodePositionFromMap(candidateMapId, x, y)
        if uiMapId then
            return uiMapId, mapX, mapY
        end
    end
    return nil, nil, nil
end

local function IsCurrentTaxiNodeState(state)
    if type(state) == "string" then
        return string.upper(state) == "CURRENT"
    end

    local stateEnum = Enum and Enum.FlightPathState
    return stateEnum and state == stateEnum.Current or false
end

local function IsLearnedTaxiNodeState(state)
    if type(state) == "string" then
        return LEARNED_TAXI_NODE_TYPES[string.upper(state)] == true
    end

    local stateEnum = Enum and Enum.FlightPathState
    if not stateEnum then
        return false
    end
    return state == stateEnum.Current
        or state == stateEnum.Reachable
end

local GetVectorPosition

local function GetPlayerMapPosition()
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local uiMapId = SafeCall(C_Map.GetBestMapForUnit, "player")
        local position = uiMapId and SafeCall(C_Map.GetPlayerMapPosition, uiMapId, "player") or nil
        local x, y = GetVectorPosition(position)
        if uiMapId and x and y and Map.CanPlaceMarker and Map:CanPlaceMarker(uiMapId, x, y) then
            return uiMapId, RoundCoordinate(x), RoundCoordinate(y)
        end
    end

    if Map.hbd and Map.hbd.GetPlayerZonePosition then
        local x, y, uiMapId = Map.hbd:GetPlayerZonePosition()
        if uiMapId and x and y and Map.CanPlaceMarker and Map:CanPlaceMarker(uiMapId, x, y) then
            return uiMapId, RoundCoordinate(x), RoundCoordinate(y)
        end
    end
    return nil, nil, nil
end

function GetVectorPosition(position)
    if type(position) ~= "table" and type(position) ~= "userdata" then
        return nil, nil
    end
    if position.GetXY then
        local x, y = SafeCall(position.GetXY, position)
        if x and y then
            return x, y
        end
    end
    if type(position) ~= "table" then
        return nil, nil
    end
    return position.x or position[1], position.y or position[2]
end

local function GetTaxiNodePosition(node)
    if type(node) ~= "table" then
        return nil, nil
    end

    local x, y = GetVectorPosition(node.position or node.pos or node.mapPosition)
    if x and y then
        return tonumber(x), tonumber(y)
    end
    return tonumber(node.x or node[1]), tonumber(node.y or node[2])
end

local function GetTaxiNodeName(node)
    if type(node) ~= "table" then
        return nil
    end
    return Trim(node.name or node.nodeName or node.displayName)
end

local function GetTaxiNodeId(node)
    if type(node) ~= "table" then
        return nil
    end
    return node.nodeID or node.nodeId or node.id
end

local function IsPreferredFactionTaxiNode(node)
    if type(node) ~= "table" then
        return false
    end

    local factionGroup = UnitFactionGroup and UnitFactionGroup("player") or nil
    local atlasName = type(node.atlasName) == "string" and string.lower(node.atlasName) or ""
    local faction = tonumber(node.faction)

    if faction == 0 or string.find(atlasName, "neutral", 1, true) then
        return true
    end
    if factionGroup == "Horde" then
        return faction == 1 or string.find(atlasName, "horde", 1, true) ~= nil
    end
    if factionGroup == "Alliance" then
        return faction == 2 or string.find(atlasName, "alliance", 1, true) ~= nil
    end
    return true
end

local function GetCMapTaxiNodeQuality(node)
    if IsPreferredFactionTaxiNode(node) then
        return 2
    end
    return 1
end

function Map:GetCMapTaxiNodesByName()
    local lookup = {}
    if not C_TaxiMap or not C_TaxiMap.GetTaxiNodesForMap then
        return lookup
    end

    for _, sourceMapId in ipairs(GetTaxiSourceMapCandidates(true)) do
        local nodes = SafeCall(C_TaxiMap.GetTaxiNodesForMap, sourceMapId)
        if type(nodes) == "table" then
            for _, node in pairs(nodes) do
                local name = NormalizeName(GetTaxiNodeName(node))
                local x, y = GetTaxiNodePosition(node)
                if name and x and y then
                    local existing = lookup[name]
                    local quality = GetCMapTaxiNodeQuality(node)
                    if not existing or quality > existing.quality then
                        lookup[name] = {
                            node = node,
                            sourceMapId = sourceMapId,
                            quality = quality,
                        }
                    end
                end
            end
        end
    end
    return lookup
end

local function BuildFlightMasterKey(nodeId, name, uiMapId, x, y)
    if nodeId then
        return "node:" .. tostring(nodeId)
    end

    return table.concat({
        "coord",
        tostring(uiMapId),
        tostring(x),
        tostring(y),
        name or "",
    }, ":")
end

local function GetFlightMasterRecordQuality(record)
    if type(record) ~= "table" then
        return 0
    end
    if record.positionSource == "player" then
        return 4
    end
    if record.nodeId then
        return 3
    end
    if record.uiMapId and record.x and record.y then
        return 2
    end
    return 1
end

local function RemoveStaleFlightMasterRecords(store, key, nodeId, name)
    if type(store) ~= "table" then
        return
    end

    local normalizedName = NormalizeName(name)
    for existingKey, existing in pairs(store) do
        if existingKey ~= key and type(existing) == "table" then
            if nodeId and existing.nodeId == nodeId then
                store[existingKey] = nil
            elseif normalizedName and NormalizeName(existing.name) == normalizedName then
                store[existingKey] = nil
            end
        end
    end
end

function Map:CleanKnownFlightMasterStore()
    local store = self:GetKnownFlightMasterStore()
    local bestKeysByIdentity = {}
    local removed = false

    for key, record in pairs(store) do
        if type(record) ~= "table" or not record.uiMapId or not record.x or not record.y then
            store[key] = nil
            removed = true
        else
            local nodeKey = record.nodeId and tostring(record.nodeId) or nil
            local nameKey = NormalizeName(record.name)
            local groupKey = nameKey or nodeKey
            if groupKey then
                local existingKey = bestKeysByIdentity[groupKey]
                local existing = existingKey and store[existingKey] or nil
                if not existing or GetFlightMasterRecordQuality(record) >= GetFlightMasterRecordQuality(existing) then
                    if existingKey and existingKey ~= key then
                        store[existingKey] = nil
                        removed = true
                    end
                    bestKeysByIdentity[groupKey] = key
                else
                    store[key] = nil
                    removed = true
                end
            end
        end
    end
    return removed
end

function Map:LearnKnownFlightMaster(node, sourceMapId, candidates)
    if not self.hbd then
        self.hbd = LibStub and LibStub("HereBeDragons-2.0", true)
    end
    if type(node) ~= "table" or not IsLearnedTaxiNodeState(node.state or node.nodeType) then
        return false
    end

    local state = node.state or node.nodeType
    local uiMapId, x, y
    local positionSource
    if IsCurrentTaxiNodeState(state) then
        uiMapId, x, y = GetPlayerMapPosition()
        if uiMapId then
            positionSource = "player"
        end
    end
    if not uiMapId then
        local nodeX, nodeY = GetTaxiNodePosition(node)
        local nodeSourceMapId = tonumber(node.uiMapID or node.uiMapId or node.mapID or node.mapId)
        if not IsContinentMap(nodeSourceMapId) then
            nodeSourceMapId = sourceMapId
        end
        uiMapId, x, y = ResolveNodePosition(nodeSourceMapId, nodeX, nodeY, candidates, self:FindFlightMasterTargetMapByName(GetTaxiNodeName(node)))
        if uiMapId then
            positionSource = "taxi"
        end
    end
    if not uiMapId then
        return false
    end

    local nodeId = GetTaxiNodeId(node)
    local name = GetTaxiNodeName(node)
    local key = BuildFlightMasterKey(nodeId, name, uiMapId, x, y)
    local store = self:GetKnownFlightMasterStore()
    local existing = store[key]

    if existing
        and existing.uiMapId == uiMapId
        and existing.x == x
        and existing.y == y
        and existing.name == name
        and existing.nodeId == nodeId then
        return false
    end

    RemoveStaleFlightMasterRecords(store, key, nodeId, name)
    store[key] = {
        key = key,
        uiMapId = uiMapId,
        x = x,
        y = y,
        name = name,
        nodeId = nodeId,
        positionSource = positionSource,
    }
    return true
end

function Map:CaptureKnownFlightMastersFromCMap()
    return false
end

function Map:CaptureKnownFlightMastersFromLegacyApi()
    if type(NumTaxiNodes) ~= "function" then
        return false
    end

    local count = tonumber(SafeCall(NumTaxiNodes)) or 0
    if count <= 0 then
        return false
    end

    local changed = false
    local candidates = GetTaxiSourceMapCandidates(true)
    local cMapNodesByName = self:GetCMapTaxiNodesByName()
    for index = 1, count do
        local x, y = SafeCall(TaxiNodePosition, index)
        local name = SafeCall(TaxiNodeName, index)
        local cMapMatch = cMapNodesByName[NormalizeName(name or "")]
        local cMapNode = cMapMatch and cMapMatch.node or nil
        local cMapX, cMapY = GetTaxiNodePosition(cMapNode)
        local node = {
            name = name,
            state = SafeCall(TaxiNodeGetType, index),
            nodeID = GetTaxiNodeId(cMapNode),
            uiMapID = cMapMatch and cMapMatch.sourceMapId or candidates[1],
            x = tonumber(cMapX or x),
            y = tonumber(cMapY or y),
        }

        if self:LearnKnownFlightMaster(node, nil, candidates) then
            changed = true
        end
    end
    return changed
end

function Map:CaptureKnownFlightMasters()
    local changed = false

    if self:CaptureKnownFlightMastersFromCMap() then
        changed = true
    end
    if self:CaptureKnownFlightMastersFromLegacyApi() then
        changed = true
    end
    if self:CleanKnownFlightMasterStore() then
        changed = true
    end

    if changed and self.RefreshWorldMapMarkers then
        self:RefreshWorldMapMarkers()
    end
    return changed
end
