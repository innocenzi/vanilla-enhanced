local VanillaEnhanced = _G.VanillaEnhanced
local Professions = VanillaEnhanced:GetModule("professions")

local HERBALISM_PROFESSION_ID = 182
local MINING_PROFESSION_ID = 186
local COORDINATE_PRECISION = 100000
local PENDING_GATHER_TIMEOUT = 20
local DUPLICATE_NODE_RANGE_YARDS = 15
local DUPLICATE_COORDINATE_DELTA = 0.0015
local MINIMAP_NODE_RANGE_YARDS = 600
local MINIMAP_NODE_LIMIT = 25
local GATHERING_MARKER_SYMBOL = "\226\128\162"
local GATHERING_MARKER_SIZE = 9
local UNAVAILABLE_NODE_COLOR = {0.48, 0.48, 0.48, 0.82}
local RESPAWN_REFRESH_PADDING_SECONDS = 1
local RESPAWN_ESTIMATE_SECONDS = {
    fast = 5 * 60,
    normal = 10 * 60,
    conservative = 15 * 60,
}

local RESOURCE_TYPES = {
    herb = {
        professionId = HERBALISM_PROFESSION_ID,
        spellIds = {2366, 2368, 3570, 11993, 28695},
        symbol = GATHERING_MARKER_SYMBOL,
        color = {0.62, 0.9, 0.62, 1},
        labelKey = "professions.gathering.resource.herb",
    },
    ore = {
        professionId = MINING_PROFESSION_ID,
        spellIds = {2575, 2576, 3564, 10248, 29354},
        symbol = GATHERING_MARKER_SYMBOL,
        color = {0.64, 0.76, 0.92, 1},
        labelKey = "professions.gathering.resource.ore",
    },
}

local RESOURCE_SKILL_GRAY_AT_BY_ITEM_ID = {
    [765] = 100,
    [2447] = 100,
    [2449] = 125,
    [785] = 150,
    [2452] = 150,
    [2450] = 170,
    [2453] = 200,
    [3355] = 215,
    [3369] = 220,
    [3356] = 225,
    [3357] = 250,
    [3818] = 260,
    [3821] = 270,
    [3358] = 285,
    [3819] = 295,
    [4625] = 305,
    [8831] = 310,
    [8836] = 320,
    [8838] = 330,
    [8839] = 335,
    [8845] = 345,
    [8846] = 350,
    [13464] = 360,
    [13463] = 370,
    [13465] = 380,
    [13466] = 385,
    [13467] = 390,
    [13468] = 400,
    [22785] = 400,
    [22786] = 415,
    [22787] = 425,
    [22788] = 435,
    [22789] = 425,
    [22790] = 440,
    [22791] = 450,
    [22792] = 465,
    [22793] = 475,
    [2770] = 100,
    [2771] = 165,
    [2775] = 175,
    [2772] = 225,
    [2776] = 255,
    [3858] = 275,
    [7911] = 330,
    [11370] = 330,
    [10620] = 350,
    [23424] = 400,
    [23425] = 425,
    [23426] = 475,
}

local SPELL_RESOURCE_TYPES = {
    [2366] = "herb",
    [2368] = "herb",
    [3570] = "herb",
    [11993] = "herb",
    [28695] = "herb",
    [2575] = "ore",
    [2576] = "ore",
    [3564] = "ore",
    [10248] = "ore",
    [29354] = "ore",
}

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

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

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local results = {pcall(fn, ...)}
    if not results[1] then
        return nil
    end
    return unpack(results, 2)
end

local function GetVectorPosition(position)
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

local function GetCharacterKey()
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("player")
    end
    if not name and UnitName then
        name = UnitName("player")
    end
    if (not realm or realm == "") and GetRealmName then
        realm = GetRealmName()
    end
    return (name or UNKNOWN or "Player") .. "-" .. (realm or "")
end

local function IsRecent(timestamp, timeout)
    local now = GetTime and GetTime() or 0
    return timestamp and now - timestamp <= (timeout or PENDING_GATHER_TIMEOUT)
end

local function GetUnixTime()
    return time and time() or nil
end

local function FormatDuration(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    if seconds >= 3600 then
        return T("professions.gathering.node.respawn.hours", {
            hours = math.ceil(seconds / 3600),
        })
    end
    if seconds >= 60 then
        return T("professions.gathering.node.respawn.minutes", {
            minutes = math.ceil(seconds / 60),
        })
    end
    return T("professions.gathering.node.respawn.seconds", {
        seconds = math.ceil(seconds),
    })
end

local function ExtractLootItemName(message)
    if type(message) ~= "string" then
        return nil
    end

    return Trim(string.match(message, "|h%[(.-)%]|h") or string.match(message, "%[(.-)%]"))
end

local function ExtractItemIdFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(string.match(link, "item:(%d+)"))
end

local function ExtractLootItemId(message)
    if type(message) ~= "string" then
        return nil
    end
    return ExtractItemIdFromLink(message)
end

local function IsCastGuidString(value)
    return type(value) == "string" and string.find(value, "^Cast%-") ~= nil
end

local function GetResourceGraySkill(node)
    if not node then
        return nil
    end

    local itemId = tonumber(node.itemId)
    if itemId and RESOURCE_SKILL_GRAY_AT_BY_ITEM_ID[itemId] then
        return RESOURCE_SKILL_GRAY_AT_BY_ITEM_ID[itemId]
    end

    return nil
end

local function GetOpenLootItemInfo()
    if type(GetNumLootItems) ~= "function" or type(GetLootSlotInfo) ~= "function" then
        return nil, nil
    end

    local count = tonumber(SafeCall(GetNumLootItems)) or 0
    local fallbackName
    local fallbackItemId
    for slot = 1, count do
        local _, itemName = SafeCall(GetLootSlotInfo, slot)
        itemName = Trim(itemName)
        local itemLink = SafeCall(GetLootSlotLink, slot)
        local itemId = ExtractItemIdFromLink(itemLink)
        if itemId and RESOURCE_SKILL_GRAY_AT_BY_ITEM_ID[itemId] then
            return itemName, itemId
        end
        if itemName and not fallbackName then
            fallbackName = itemName
            fallbackItemId = itemId
        end
    end
    return fallbackName, fallbackItemId
end

local function AddNodeByDistance(nodes, node, distance)
    nodes[#nodes + 1] = {
        node = node,
        distance = distance,
    }
end

local function SortNodesByDistance(left, right)
    return (left.distance or 0) < (right.distance or 0)
end

local function IsKnownGatheringSpell(spellId)
    local Professions = VanillaEnhanced:GetModule("professions")
    if Professions and Professions.Api and Professions.Api.IsSpellKnown then
        return Professions.Api:IsSpellKnown(spellId)
    end

    spellId = tonumber(spellId)
    if not spellId then
        return false
    end

    if C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellId)
        if ok and known ~= nil then
            return known == true
        end
    end
    if type(IsSpellKnown) == "function" then
        local ok, known = pcall(IsSpellKnown, spellId)
        if ok and known ~= nil then
            return known == true
        end
    end
    if type(IsPlayerSpell) == "function" then
        local ok, known = pcall(IsPlayerSpell, spellId)
        if ok and known ~= nil then
            return known == true
        end
    end

    return false
end

local function IsSameMapPosition(node, uiMapId, x, y)
    if not node or node.uiMapId ~= uiMapId or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end

    local existingX = tonumber(node.x)
    local existingY = tonumber(node.y)
    if not existingX or not existingY then
        return false
    end

    local hbd = Professions:GetHBD()
    if hbd and hbd.GetWorldCoordinatesFromZone then
        local oldX, oldY, oldInstanceId = hbd:GetWorldCoordinatesFromZone(existingX, existingY, node.uiMapId)
        local newX, newY, newInstanceId = hbd:GetWorldCoordinatesFromZone(x, y, uiMapId)
        if oldX and oldY and newX and newY and oldInstanceId == newInstanceId then
            if hbd.GetWorldDistance then
                local distance = hbd:GetWorldDistance(oldInstanceId, oldX, oldY, newX, newY)
                if distance then
                    return distance <= DUPLICATE_NODE_RANGE_YARDS
                end
            end

            local xDist = oldX - newX
            local yDist = oldY - newY
            return math.sqrt((xDist * xDist) + (yDist * yDist)) <= DUPLICATE_NODE_RANGE_YARDS
        end
    end

    return math.abs(existingX - x) <= DUPLICATE_COORDINATE_DELTA
        and math.abs(existingY - y) <= DUPLICATE_COORDINATE_DELTA
end

local function FindExistingNode(nodes, resourceType, uiMapId, x, y)
    for index = #(nodes or {}), 1, -1 do
        local node = nodes[index]
        if node and node.resourceType == resourceType and IsSameMapPosition(node, uiMapId, x, y) then
            return node
        end
    end
    return nil
end

function Professions:GetResourceTypeInfo(resourceType)
    return RESOURCE_TYPES[resourceType]
end

function Professions:GetResourceTypeLabel(resourceType)
    local info = self:GetResourceTypeInfo(resourceType)
    return info and T(info.labelKey) or T("professions.gathering.resource.unknown")
end

function Professions:HasResourceProfession(resourceType)
    local info = self:GetResourceTypeInfo(resourceType)
    if not info then
        return false
    end

    local professions = self:GetPlayerProfessions()
    if professions and professions[info.professionId] ~= nil then
        return true
    end

    for _, spellId in ipairs(info.spellIds or {}) do
        if IsKnownGatheringSpell(spellId) then
            return true
        end
    end

    return false
end

function Professions:IsNodeProfessionKnown(node)
    return node and self:HasResourceProfession(node.resourceType)
end

function Professions:GetNodeGraySkill(node)
    return GetResourceGraySkill(node)
end

function Professions:DetectResourceTypeFromSpell(spellId, spellName)
    spellId = tonumber(spellId)
    if spellId and SPELL_RESOURCE_TYPES[spellId] then
        return SPELL_RESOURCE_TYPES[spellId]
    end

    spellName = Trim(spellName)
    if not spellName then
        return nil
    end

    local lowerName = string.lower(spellName)
    local Professions = VanillaEnhanced:GetModule("professions")
    if Professions and Professions.GetProfessionName then
        local herbalismName = Professions:GetProfessionName(HERBALISM_PROFESSION_ID)
        local miningName = Professions:GetProfessionName(MINING_PROFESSION_ID)
        if herbalismName and string.find(lowerName, string.lower(herbalismName), 1, true) then
            return "herb"
        end
        if miningName and string.find(lowerName, string.lower(miningName), 1, true) then
            return "ore"
        end
    end
    if string.find(lowerName, "herb", 1, true) then
        return "herb"
    end
    if string.find(lowerName, "mining", 1, true) then
        return "ore"
    end
    return nil
end

function Professions:ExtractGatherSpellEvent(event, ...)
    local count = select("#", ...)
    local unit = select(1, ...)
    if unit ~= "player" then
        return nil
    end

    local spellId
    local spellName
    local targetName
    local strings = {}

    for index = 2, count do
        local value = select(index, ...)
        if type(value) == "number" and not spellId then
            spellId = value
        elseif type(value) == "string" and not IsCastGuidString(value) then
            value = Trim(value)
            if value then
                strings[#strings + 1] = value
            end
        end
    end

    if spellId and GetSpellInfo then
        spellName = GetSpellInfo(spellId) or spellName
    end
    if not spellName then
        for _, value in ipairs(strings) do
            if self:DetectResourceTypeFromSpell(nil, value) then
                spellName = value
                break
            end
        end
    end
    spellName = spellName or strings[1]

    if event == "UNIT_SPELLCAST_SENT" then
        for index = #strings, 1, -1 do
            local value = strings[index]
            if value ~= spellName and not self:DetectResourceTypeFromSpell(nil, value) then
                targetName = value
                break
            end
        end
        if not targetName and spellId and strings[1] ~= spellName then
            targetName = strings[1]
        end
    end

    local resourceType = self:DetectResourceTypeFromSpell(spellId, spellName)
    return resourceType, spellId, spellName, targetName
end

function Professions:TrackGatherCast(event, ...)
    local settings = self:GetSettings()
    if not self:IsEnabled() or settings.trackGatheredNodes == false then
        if self.RecordGatheringDebugEvent then
            self:RecordGatheringDebugEvent("trackCast:ignored", "disabledOrTrackingOff")
        end
        return
    end

    local resourceType, spellId, spellName, targetName = self:ExtractGatherSpellEvent(event, ...)
    if not resourceType then
        if self.RecordGatheringDebugEvent then
            self:RecordGatheringDebugEvent("trackCast:noResourceType", "event=" .. tostring(event) .. " spellId=" .. tostring(spellId) .. " spellName=" .. tostring(spellName))
        end
        return
    end
    if not self:HasResourceProfession(resourceType) then
        if self.RecordGatheringDebugEvent then
            self:RecordGatheringDebugEvent("trackCast:professionMissing", "type=" .. tostring(resourceType) .. " spellId=" .. tostring(spellId))
        end
        return
    end

    self.pendingGather = {
        resourceType = resourceType,
        spellId = spellId,
        spellName = spellName,
        targetName = targetName or (self.pendingGather and self.pendingGather.resourceType == resourceType and self.pendingGather.targetName or nil),
        time = GetTime and GetTime() or 0,
    }
    if self.RecordGatheringDebugEvent then
        self:RecordGatheringDebugEvent("trackCast:pending", "type=" .. tostring(resourceType) .. " spellId=" .. tostring(spellId) .. " spellName=" .. tostring(spellName) .. " target=" .. tostring(targetName))
    end
end

function Professions:GetPlayerMapPosition()
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local uiMapId = SafeCall(C_Map.GetBestMapForUnit, "player")
        local position = uiMapId and SafeCall(C_Map.GetPlayerMapPosition, uiMapId, "player") or nil
        local x, y = GetVectorPosition(position)
        local map = self:GetMapModule()
        if uiMapId and x and y and map and map.CanPlaceMarker and map:CanPlaceMarker(uiMapId, x, y) then
            return uiMapId, RoundCoordinate(x), RoundCoordinate(y)
        end
    end

    local hbd = self:GetHBD()
    local map = self:GetMapModule()
    if hbd and hbd.GetPlayerZonePosition then
        local x, y, uiMapId = hbd:GetPlayerZonePosition()
        if uiMapId and x and y and map and map.CanPlaceMarker and map:CanPlaceMarker(uiMapId, x, y) then
            return uiMapId, RoundCoordinate(x), RoundCoordinate(y)
        end
    end
    return nil, nil, nil
end

function Professions:MarkGatherLootOpened()
    local pending = self.pendingGather
    if not pending or not IsRecent(pending.time) then
        if self.RecordGatheringDebugEvent then
            self:RecordGatheringDebugEvent("lootOpened:ignored", pending and "stalePending" or "noPending")
        end
        return
    end

    local uiMapId, x, y = self:GetPlayerMapPosition()
    pending.lootOpened = true
    pending.lootOpenedTime = GetTime and GetTime() or pending.time
    pending.uiMapId = uiMapId
    pending.x = x
    pending.y = y
    local lootName, lootItemId = GetOpenLootItemInfo()
    pending.lootName = pending.lootName or lootName
    pending.lootItemId = pending.lootItemId or lootItemId
    if self.RecordGatheringDebugEvent then
        self:RecordGatheringDebugEvent("lootOpened:captured", "map=" .. tostring(uiMapId) .. " x=" .. tostring(x) .. " y=" .. tostring(y) .. " lootName=" .. tostring(pending.lootName) .. " itemId=" .. tostring(pending.lootItemId))
    end
end

function Professions:CaptureGatherLootMessage(message)
    local pending = self.pendingGather
    if not pending or not IsRecent(pending.time) then
        if self.RecordGatheringDebugEvent then
            self:RecordGatheringDebugEvent("lootMessage:ignored", pending and "stalePending" or "noPending")
        end
        return
    end

    pending.lootName = pending.lootName or ExtractLootItemName(message)
    pending.lootItemId = pending.lootItemId or ExtractLootItemId(message)
    if self.RecordGatheringDebugEvent then
        self:RecordGatheringDebugEvent("lootMessage:captured", "name=" .. tostring(pending.lootName) .. " itemId=" .. tostring(pending.lootItemId) .. " message=" .. tostring(message))
    end
end

function Professions:GetNextPersonalNodeId()
    local settings = self:GetGatheringCharacterSettings()
    local nodeId = settings.nextNodeId
    settings.nextNodeId = nodeId + 1
    return nodeId
end

function Professions:GetNextSharedNodeId()
    local settings = self:GetGatheringSharedSettings()
    local nodeId = settings.nextSharedNodeId
    settings.nextSharedNodeId = nodeId + 1
    return nodeId
end

function Professions:BuildNodeName(resourceType, explicitName)
    explicitName = Trim(explicitName)
    if explicitName then
        return explicitName
    end
    return self:GetResourceTypeLabel(resourceType)
end

function Professions:UpdateGatheredNode(node, resourceType, x, y, options)
    if not node then
        return nil
    end

    local gatheredAt = GetUnixTime()
    local nodeName = self:BuildNodeName(resourceType, options and (options.objectName or options.itemName))
    local genericName = self:GetResourceTypeLabel(resourceType)

    node.x = RoundCoordinate(x or node.x)
    node.y = RoundCoordinate(y or node.y)
    node.name = (nodeName ~= genericName and nodeName) or node.name or nodeName
    node.itemName = (options and options.itemName) or node.itemName
    node.itemId = (options and options.itemId) or node.itemId
    node.gatheredAt = gatheredAt or node.gatheredAt

    return node
end

function Professions:AddSharedNodeFromPersonalNode(node)
    local settings = self:GetGatheringSharedSettings()
    local existing = FindExistingNode(settings.sharedNodes, node.resourceType, node.uiMapId, node.x, node.y)
    if existing then
        existing.professionId = node.professionId or existing.professionId
        existing.owner = node.owner or existing.owner
        existing.personalId = node.id or existing.personalId
        existing.scope = "shared"
        return self:UpdateGatheredNode(existing, node.resourceType, node.x, node.y, {
            objectName = node.name,
            itemName = node.itemName,
            itemId = node.itemId,
        })
    end

    local sharedNode = {
        id = self:GetNextSharedNodeId(),
        uiMapId = node.uiMapId,
        x = node.x,
        y = node.y,
        resourceType = node.resourceType,
        professionId = node.professionId,
        name = node.name,
        itemName = node.itemName,
        itemId = node.itemId,
        gatheredAt = node.gatheredAt,
        owner = node.owner,
        personalId = node.id,
        scope = "shared",
    }
    settings.sharedNodes[#settings.sharedNodes + 1] = sharedNode
    return sharedNode
end

function Professions:AddGatheredNode(resourceType, uiMapId, x, y, options)
    local resourceInfo = self:GetResourceTypeInfo(resourceType)
    if not resourceInfo or not self:HasResourceProfession(resourceType) then
        self.lastGatherCommit = {
            status = "failed",
            reason = "resourceOrProfession",
            resourceType = resourceType,
            uiMapId = uiMapId,
            x = x,
            y = y,
        }
        if self.RecordGatheringDebugEvent then
            self:RecordGatheringDebugEvent("addNode:failed", "resourceOrProfession type=" .. tostring(resourceType))
        end
        return nil
    end
    if type(uiMapId) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        self.lastGatherCommit = {
            status = "failed",
            reason = "invalidPosition",
            resourceType = resourceType,
            uiMapId = uiMapId,
            x = x,
            y = y,
        }
        if self.RecordGatheringDebugEvent then
            self:RecordGatheringDebugEvent("addNode:failed", "invalidPosition map=" .. tostring(uiMapId) .. " x=" .. tostring(x) .. " y=" .. tostring(y))
        end
        return nil
    end

    local settings = self:GetSettings()
    local characterSettings = self:GetGatheringCharacterSettings()
    x = RoundCoordinate(x)
    y = RoundCoordinate(y)

    local existing = FindExistingNode(characterSettings.nodes, resourceType, uiMapId, x, y)
    if existing then
        existing.professionId = resourceInfo.professionId
        existing.owner = existing.owner or GetCharacterKey()
        existing.scope = "personal"
        self:UpdateGatheredNode(existing, resourceType, x, y, options)
        if settings.saveSharedNodes ~= false then
            self:AddSharedNodeFromPersonalNode(existing)
        end
        self:RefreshMap()

        self.lastGatherCommit = {
            status = "updated",
            reason = "existingNode",
            resourceType = resourceType,
            uiMapId = uiMapId,
            x = x,
            y = y,
            nodeId = existing.id,
        }
        if self.RecordGatheringDebugEvent then
            self:RecordGatheringDebugEvent("addNode:updated", "id=" .. tostring(existing.id) .. " type=" .. tostring(resourceType) .. " map=" .. tostring(uiMapId) .. " x=" .. tostring(x) .. " y=" .. tostring(y))
        end
        return existing
    end

    local node = {
        id = self:GetNextPersonalNodeId(),
        uiMapId = uiMapId,
        x = x,
        y = y,
        resourceType = resourceType,
        professionId = resourceInfo.professionId,
        name = self:BuildNodeName(resourceType, options and (options.objectName or options.itemName)),
        itemName = options and options.itemName or nil,
        itemId = options and options.itemId or nil,
        gatheredAt = GetUnixTime(),
        owner = GetCharacterKey(),
        scope = "personal",
    }

    characterSettings.nodes[#characterSettings.nodes + 1] = node
    if settings.saveSharedNodes ~= false then
        self:AddSharedNodeFromPersonalNode(node)
    end

    self:RefreshMap()

    self.lastGatherCommit = {
        status = "added",
        reason = "ok",
        resourceType = resourceType,
        uiMapId = uiMapId,
        x = x,
        y = y,
        nodeId = node.id,
    }
    if self.RecordGatheringDebugEvent then
        self:RecordGatheringDebugEvent("addNode:added", "id=" .. tostring(node.id) .. " type=" .. tostring(resourceType) .. " map=" .. tostring(uiMapId) .. " x=" .. tostring(x) .. " y=" .. tostring(y))
    end
    VanillaEnhanced:PrintMessage(T("professions.gathering.nodes.added", {resource = node.name}))
    return node
end

function Professions:CommitPendingGather()
    local pending = self.pendingGather
    self.pendingGather = nil
    if not pending or not IsRecent(pending.time) then
        self.lastGatherCommit = {
            status = "failed",
            reason = pending and "stalePending" or "noPending",
        }
        if self.RecordGatheringDebugEvent then
            self:RecordGatheringDebugEvent("commit:ignored", pending and "stalePending" or "noPending")
        end
        return nil
    end
    if not pending.lootOpened and not pending.lootName then
        self.lastGatherCommit = {
            status = "failed",
            reason = "noLootSignal",
            resourceType = pending.resourceType,
            spellId = pending.spellId,
            spellName = pending.spellName,
            targetName = pending.targetName,
        }
        if self.RecordGatheringDebugEvent then
            self:RecordGatheringDebugEvent("commit:ignored", "noLootSignal type=" .. tostring(pending.resourceType))
        end
        return nil
    end

    local uiMapId = pending.uiMapId
    local x = pending.x
    local y = pending.y
    if not uiMapId or not x or not y then
        uiMapId, x, y = self:GetPlayerMapPosition()
    end

    self.lastGatherCommit = {
        status = "attempting",
        reason = "lootClosed",
        resourceType = pending.resourceType,
        spellId = pending.spellId,
        spellName = pending.spellName,
        targetName = pending.targetName,
        lootName = pending.lootName,
        itemId = pending.lootItemId,
        uiMapId = uiMapId,
        x = x,
        y = y,
    }
    if self.RecordGatheringDebugEvent then
        self:RecordGatheringDebugEvent("commit:attempt", "type=" .. tostring(pending.resourceType) .. " map=" .. tostring(uiMapId) .. " x=" .. tostring(x) .. " y=" .. tostring(y))
    end
    return self:AddGatheredNode(pending.resourceType, uiMapId, x, y, {
        objectName = pending.targetName,
        itemName = pending.lootName,
        itemId = pending.lootItemId,
    })
end

function Professions:BuildNodeDisplayKey(node)
    if not node then
        return nil
    end

    return table.concat({
        tostring(node.resourceType or ""),
        tostring(node.uiMapId or ""),
        tostring(node.x or ""),
        tostring(node.y or ""),
        tostring(node.name or ""),
        tostring(node.itemId or ""),
    }, ":")
end

function Professions:IsNodeTrivial(node)
    local info = self:GetResourceTypeInfo(node and node.resourceType)
    if not info then
        return false
    end

    local graySkill = GetResourceGraySkill(node)
    if not graySkill then
        return false
    end

    local professions = self:GetPlayerProfessions()
    local playerSkill = professions and professions[info.professionId] or nil
    return playerSkill ~= nil and playerSkill >= graySkill
end

function Professions:GetRespawnEstimateSeconds()
    local settings = self:GetSettings()
    return RESPAWN_ESTIMATE_SECONDS[settings.respawnEstimate] or RESPAWN_ESTIMATE_SECONDS.fast
end

function Professions:GetNodeRespawnRemainingSeconds(node)
    local settings = self:GetSettings()
    if settings.grayFreshNodes == false or not node then
        return nil
    end

    local gatheredAt = tonumber(node.gatheredAt)
    local now = GetUnixTime()
    if not gatheredAt or not now then
        return nil
    end

    local remaining = gatheredAt + self:GetRespawnEstimateSeconds() - now
    if remaining <= 0 then
        return nil
    end
    return remaining
end

function Professions:IsNodeEstimatedAvailable(node)
    return self:GetNodeRespawnRemainingSeconds(node) == nil
end

function Professions:ScheduleRespawnRefresh(remainingSeconds)
    if not C_Timer or not C_Timer.After then
        return
    end

    remainingSeconds = tonumber(remainingSeconds)
    if not remainingSeconds or remainingSeconds <= 0 then
        return
    end

    local now = GetTime and GetTime() or 0
    local targetTime = now + remainingSeconds + RESPAWN_REFRESH_PADDING_SECONDS
    if self.nextRespawnRefreshTime and self.nextRespawnRefreshTime <= targetTime then
        return
    end

    self.respawnRefreshToken = (self.respawnRefreshToken or 0) + 1
    local token = self.respawnRefreshToken
    self.nextRespawnRefreshTime = targetTime
    C_Timer.After(remainingSeconds + RESPAWN_REFRESH_PADDING_SECONDS, function()
        if Professions.respawnRefreshToken ~= token then
            return
        end

        Professions.nextRespawnRefreshTime = nil
        if Professions.RefreshMap then
            Professions:RefreshMap()
        end
    end)
end

function Professions:ShouldDisplayNode(node)
    if not self:IsNodeProfessionKnown(node) then
        return false
    end
    if self:GetSettings().hideTrivialNodes == true and self:IsNodeTrivial(node) then
        return false
    end
    return true
end

function Professions:AddDisplayNode(nodes, seen, node)
    if not self:ShouldDisplayNode(node) then
        return
    end

    local displayKey = self:BuildNodeDisplayKey(node)
    local existingIndex = seen[displayKey]
    if not existingIndex then
        nodes[#nodes + 1] = node
        seen[displayKey] = #nodes
        return
    end

    local existing = nodes[existingIndex]
    if (tonumber(node.gatheredAt) or 0) > (tonumber(existing and existing.gatheredAt) or 0) then
        nodes[existingIndex] = node
    end
end

function Professions:GetDisplayNodes()
    local settings = self:GetSettings()
    local characterSettings = self:GetGatheringCharacterSettings()
    local nodes = {}
    local seen = {}

    if settings.includePersonalNodes ~= false then
        for _, node in ipairs(characterSettings.nodes or {}) do
            self:AddDisplayNode(nodes, seen, node)
        end
    end

    if settings.includeSharedNodes ~= false then
        local sharedSettings = self:GetGatheringSharedSettings()
        for _, node in ipairs(sharedSettings.sharedNodes or {}) do
            self:AddDisplayNode(nodes, seen, node)
        end
    end

    return nodes
end

function Professions:GetNodeWorldPosition(node)
    local hbd = self:GetHBD()
    if not hbd or not hbd.GetWorldCoordinatesFromZone or not node then
        return nil, nil, nil
    end
    return hbd:GetWorldCoordinatesFromZone(node.x, node.y, node.uiMapId)
end

function Professions:GetNodeDistanceToPlayer(node, playerX, playerY, playerInstanceId)
    local hbd = self:GetHBD()
    if not hbd or not node then
        return nil
    end

    playerX = playerX
    playerY = playerY
    playerInstanceId = playerInstanceId
    if not playerX or not playerY or not playerInstanceId then
        if not hbd.GetPlayerWorldPosition then
            return nil
        end
        playerX, playerY, playerInstanceId = hbd:GetPlayerWorldPosition()
    end

    local nodeX, nodeY, nodeInstanceId = self:GetNodeWorldPosition(node)
    if not playerX or not playerY or not playerInstanceId or not nodeX or not nodeY or nodeInstanceId ~= playerInstanceId then
        return nil
    end

    if hbd.GetWorldDistance then
        return hbd:GetWorldDistance(playerInstanceId, playerX, playerY, nodeX, nodeY)
    end

    local xDist = playerX - nodeX
    local yDist = playerY - nodeY
    return math.sqrt((xDist * xDist) + (yDist * yDist))
end

function Professions:BuildNodeMarker(node, options)
    local info = self:GetResourceTypeInfo(node and node.resourceType)
    if not info then
        return nil
    end

    options = options or {}
    local symbol = options.symbol or info.symbol
    local color = options.color or info.color
    local tooltipLines = {}
    if options.tooltipLine then
        tooltipLines = {options.tooltipLine}
    end

    for _, line in ipairs(options.tooltipLines or {}) do
        tooltipLines[#tooltipLines + 1] = line
    end

    local respawnRemaining = self:GetNodeRespawnRemainingSeconds(node)
    if respawnRemaining then
        color = UNAVAILABLE_NODE_COLOR
        tooltipLines[#tooltipLines + 1] = {
            text = T("professions.gathering.node.respawn.estimate", {
                time = FormatDuration(respawnRemaining),
            }),
            r = 0.62,
            g = 0.62,
            b = 0.62,
        }
        self:ScheduleRespawnRefresh(respawnRemaining)
    end

    return {
        id = options.id or ("professions:gathering:" .. tostring(node.scope or "node") .. ":" .. tostring(node.id or self:BuildNodeDisplayKey(node))),
        uiMapId = node.uiMapId,
        x = node.x,
        y = node.y,
        title = options.title or node.name or self:GetResourceTypeLabel(node.resourceType),
        source = "professions:gathering",
        symbol = symbol,
        size = options.size or GATHERING_MARKER_SIZE,
        color = color,
        tooltipLines = #tooltipLines > 0 and tooltipLines or nil,
        worldMapCurrentOnly = true,
        minimapHideWhenOffMap = options.minimapHideWhenOffMap == true,
        minimapShowOnlyAtEdge = options.minimapShowOnlyAtEdge == true,
    }
end

function Professions:GetWorldMapMarkers()
    local settings = self:GetSettings()
    if not self:IsEnabled() then
        return nil
    end

    local markers = {}
    if settings.showWorldMapNodes ~= false then
        for _, node in ipairs(self:GetDisplayNodes()) do
            local marker = self:BuildNodeMarker(node)
            if marker then
                markers[#markers + 1] = marker
            end
        end
    end

    return markers
end

function Professions:GetMinimapMarkers()
    local settings = self:GetSettings()
    if not self:IsEnabled() or settings.showMinimapNodes ~= true then
        return nil
    end

    local hbd = self:GetHBD()
    if not hbd or not hbd.GetPlayerWorldPosition then
        return nil
    end

    local playerX, playerY, playerInstanceId = hbd:GetPlayerWorldPosition()
    if not playerX or not playerY or not playerInstanceId then
        return nil
    end

    local nearby = {}
    for _, node in ipairs(self:GetDisplayNodes()) do
        local distance = self:GetNodeDistanceToPlayer(node, playerX, playerY, playerInstanceId)
        if distance and distance <= MINIMAP_NODE_RANGE_YARDS then
            AddNodeByDistance(nearby, node, distance)
        end
    end

    table.sort(nearby, SortNodesByDistance)

    local markers = {}
    for index, entry in ipairs(nearby) do
        if index > MINIMAP_NODE_LIMIT then
            break
        end
        local marker = self:BuildNodeMarker(entry.node, {
            size = GATHERING_MARKER_SIZE,
            minimapHideWhenOffMap = true,
        })
        if marker then
            markers[#markers + 1] = marker
        end
    end

    if settings.showMinimapNodeDirection == true and nearby[1] then
        local marker = self:BuildNodeMarker(nearby[1].node, {
            id = "professions:gathering:closest-minimap-direction",
            size = GATHERING_MARKER_SIZE,
            minimapShowOnlyAtEdge = true,
        })
        if marker then
            markers[#markers + 1] = marker
        end
    end

    return markers
end
