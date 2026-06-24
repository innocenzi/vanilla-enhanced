local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local AUTO_FOLLOW_DISABLED = "disabled"
local AUTO_FOLLOW_MOVEMENT = "movement"
local AUTO_FOLLOW_ZONE = "zone"
local FALLBACK_MAX_QUEST_WATCHES = 5
local AUTO_FOLLOW_RANGE_YARDS = {
    close = 600,
    nearby = 1200,
    wide = 2400,
}
local MOVEMENT_UPDATE_INTERVAL_SECONDS = 2.0
local MOVEMENT_MIN_DISTANCE_YARDS = 80
local QUEUED_UPDATE_DELAY_SECONDS = 0.15

Quests.autoFollowQuestUpdateQueued = Quests.autoFollowQuestUpdateQueued or false
Quests.autoFollowQuestWatchApplying = Quests.autoFollowQuestWatchApplying or false
Quests.autoFollowQuestTrackerOrder = Quests.autoFollowQuestTrackerOrder or nil
Quests.autoFollowQuestTrackerOrderSignature = Quests.autoFollowQuestTrackerOrderSignature or nil

local eventFrame = CreateFrame("Frame")
local movementFrame = CreateFrame("Frame")
local movementElapsed = 0

local function GetAutoFollowQuestIds()
    local characterSettings = VanillaEnhanced.GetCharacterSettings and VanillaEnhanced:GetCharacterSettings() or nil
    if type(characterSettings) ~= "table" then
        Quests.autoFollowQuestIds = Quests.autoFollowQuestIds or {}
        return Quests.autoFollowQuestIds
    end

    if type(characterSettings.modules) ~= "table" then
        characterSettings.modules = {}
    end
    if type(characterSettings.modules.quests) ~= "table" then
        characterSettings.modules.quests = {}
    end
    if type(characterSettings.modules.quests.autoFollowQuestIds) ~= "table" then
        characterSettings.modules.quests.autoFollowQuestIds = {}
    end

    local owned = characterSettings.modules.quests.autoFollowQuestIds
    for questId, value in pairs(owned) do
        local normalizedQuestId = tonumber(questId)
        if value ~= true or not normalizedQuestId or normalizedQuestId <= 0 then
            owned[questId] = nil
        else
            normalizedQuestId = math.floor(normalizedQuestId)
            if normalizedQuestId ~= questId then
                owned[questId] = nil
                owned[normalizedQuestId] = true
            end
        end
    end

    Quests.autoFollowQuestIds = owned
    return owned
end

Quests.autoFollowQuestIds = GetAutoFollowQuestIds()

local function GetHBD()
    return Quests.hbd or (LibStub and LibStub("HereBeDragons-2.0", true))
end

local function GetMode()
    local settings = Quests:GetSettings()
    if not settings.enabled then
        return AUTO_FOLLOW_DISABLED
    end
    return settings.autoFollowQuestsMode or AUTO_FOLLOW_DISABLED
end

local function IsEnabled()
    return GetMode() ~= AUTO_FOLLOW_DISABLED
end

local function GetRangeYards()
    local settings = Quests:GetSettings()
    return AUTO_FOLLOW_RANGE_YARDS[settings.autoFollowQuestsRange] or AUTO_FOLLOW_RANGE_YARDS.nearby
end

local function GetQuestWatchLimit()
    local limit = tonumber(MAX_QUEST_WATCHES) or FALLBACK_MAX_QUEST_WATCHES
    if limit < 1 then
        return FALLBACK_MAX_QUEST_WATCHES
    end
    return math.floor(limit)
end

local function BuildAutoFollowQuestSignature(quests)
    local parts = {}

    for _, quest in ipairs(quests or {}) do
        parts[#parts + 1] = tostring(quest.id or "")
        parts[#parts + 1] = quest.isComplete and ":complete:" or ":active:"

        local completedObjectiveIndexes = {}
        for objectiveIndex, completed in pairs(quest.completedObjectives or {}) do
            if completed == true then
                completedObjectiveIndexes[#completedObjectiveIndexes + 1] = objectiveIndex
            end
        end
        table.sort(completedObjectiveIndexes)
        for _, objectiveIndex in ipairs(completedObjectiveIndexes) do
            parts[#parts + 1] = tostring(objectiveIndex)
            parts[#parts + 1] = ","
        end
        parts[#parts + 1] = ";"
    end

    return table.concat(parts)
end

local function FindQuestLogIndex(questId)
    if not questId or not GetNumQuestLogEntries or not GetQuestLogTitle then
        return nil
    end

    for index = 1, GetNumQuestLogEntries() do
        local _, _, _, isHeader, _, _, _, currentQuestId = GetQuestLogTitle(index)
        if not isHeader and currentQuestId == questId then
            return index
        end
    end
    return nil
end

local function GetWatchedQuestIndexes()
    local watched = {}
    local count = 0

    if not GetNumQuestWatches or not GetQuestIndexForWatch or not GetQuestLogTitle then
        return watched, count
    end

    for watchIndex = 1, GetNumQuestWatches() do
        local questIndex = GetQuestIndexForWatch(watchIndex)
        if questIndex then
            local _, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(questIndex)
            if not isHeader and questId and questId > 0 then
                watched[questId] = questIndex
                count = count + 1
            end
        end
    end

    return watched, count
end

local function PruneAutoFollowQuestOwnership(watched)
    local owned = GetAutoFollowQuestIds()
    local changed = false

    watched = watched or GetWatchedQuestIndexes()
    for questId in pairs(owned) do
        if not watched[questId] then
            owned[questId] = nil
            changed = true
        end
    end

    return owned, changed
end

local function ReconcileAutoFollowQuestOwnership()
    if Quests.autoFollowQuestWatchApplying then
        return false
    end

    local watched = GetWatchedQuestIndexes()
    local _, changed = PruneAutoFollowQuestOwnership(watched)
    return changed
end

local function AddQuestWatchByIndex(questIndex)
    if not questIndex or not AddQuestWatch then
        return false
    end

    local ok = pcall(AddQuestWatch, questIndex)
    return ok == true
end

local function RemoveQuestWatchByIndex(questIndex)
    if not questIndex or not RemoveQuestWatch then
        return false
    end

    local ok = pcall(RemoveQuestWatch, questIndex)
    return ok == true
end

local function RefreshQuestWatchDisplay()
    if QuestWatch_Update then
        pcall(QuestWatch_Update)
    end
    if Quests.RefreshQuestTrackerClicks then
        Quests:RefreshQuestTrackerClicks()
    end
end

local function UpdateAutoFollowQuestTrackerOrder(quests, questDistances)
    if not quests or not questDistances then
        if Quests.autoFollowQuestTrackerOrderSignature then
            Quests.autoFollowQuestTrackerOrder = nil
            Quests.autoFollowQuestTrackerOrderSignature = nil
            return true
        end
        return false
    end

    local watched = GetWatchedQuestIndexes()
    local known = {}
    local unknown = {}
    local signatureParts = {}

    for _, quest in ipairs(quests) do
        if quest.id and watched[quest.id] then
            local entry = {
                id = quest.id,
                number = quest.number or 0,
                distance = questDistances[quest.id],
            }
            if entry.distance then
                known[#known + 1] = entry
            else
                unknown[#unknown + 1] = entry
            end
        end
    end

    table.sort(known, function(left, right)
        if left.distance ~= right.distance then
            return left.distance < right.distance
        end
        if left.number ~= right.number then
            return left.number < right.number
        end
        return left.id < right.id
    end)

    table.sort(unknown, function(left, right)
        if left.number ~= right.number then
            return left.number < right.number
        end
        return left.id < right.id
    end)

    local order = {}
    for _, entry in ipairs(known) do
        order[#order + 1] = entry.id
        signatureParts[#signatureParts + 1] = tostring(entry.id)
    end
    for _, entry in ipairs(unknown) do
        order[#order + 1] = entry.id
        signatureParts[#signatureParts + 1] = tostring(entry.id)
    end

    local signature
    if #order > 1 then
        signature = table.concat(signatureParts, ";")
    end
    if signature == Quests.autoFollowQuestTrackerOrderSignature then
        return false
    end

    Quests.autoFollowQuestTrackerOrder = signature and order or nil
    Quests.autoFollowQuestTrackerOrderSignature = signature
    return true
end

local function GetPlayerPosition()
    local hbd = GetHBD()
    if not hbd or not hbd.GetPlayerZonePosition or not hbd.GetZoneDistance then
        return nil
    end

    local playerX, playerY, playerMapId = hbd:GetPlayerZonePosition(true)
    if not playerX or not playerY or not playerMapId then
        return nil
    end

    return {
        hbd = hbd,
        x = playerX,
        y = playerY,
        mapId = playerMapId,
    }
end

local function DistanceToCluster(position, uiMapId, cluster)
    local x = Quests:GetClusterX(cluster)
    local y = Quests:GetClusterY(cluster)
    if not position or not uiMapId or not cluster or not x or not y then
        return nil
    end

    return position.hbd:GetZoneDistance(
        position.mapId,
        position.x,
        position.y,
        uiMapId,
        x / 100,
        y / 100
    )
end

local function IsIncompleteObjectiveCluster(quest, cluster)
    local objectiveIndex = Quests:GetClusterObjectiveIndex(cluster)
    if not objectiveIndex or not quest or not quest.completedObjectives then
        return true
    end
    return quest.completedObjectives[objectiveIndex] ~= true
end

local function GetBestQuestDistance(quest, dbQuest, position, currentZoneOnly)
    if dbQuest.dq == 1 and quest.isComplete ~= true then
        if not Quests.IsCurrentQuestDungeon or not Quests:IsCurrentQuestDungeon(dbQuest) then
            return nil
        end
    end

    local maps = quest.isComplete and dbQuest.turnins or dbQuest.maps
    if not maps then
        return nil
    end

    local bestDistance
    for uiMapId, clusters in pairs(maps) do
        if not currentZoneOnly or uiMapId == position.mapId then
            for _, cluster in ipairs(clusters) do
                if quest.isComplete or IsIncompleteObjectiveCluster(quest, cluster) then
                    local distance = DistanceToCluster(position, uiMapId, cluster)
                    if distance and (not bestDistance or distance < bestDistance) then
                        bestDistance = distance
                    end
                end
            end
        end
    end

    return bestDistance
end

local function BuildRankedQuestCandidates(position, rangeYards, quests, currentZoneOnly)
    local candidates = {}
    local questDistances = {}
    if not VanillaEnhancedQuestsDB or not VanillaEnhancedQuestsDB.quests then
        return candidates, questDistances
    end

    quests = quests
        or Quests.GetCachedQuestLogSnapshot and Quests:GetCachedQuestLogSnapshot()
        or (Quests.GetQuestLogSnapshot and Quests:GetQuestLogSnapshot())
        or {}

    for _, quest in ipairs(quests) do
        local dbQuest = quest.id and VanillaEnhancedQuestsDB.quests[quest.id]
        if dbQuest then
            local distance = GetBestQuestDistance(quest, dbQuest, position, currentZoneOnly)
            if distance and (currentZoneOnly or distance <= rangeYards) then
                questDistances[quest.id] = distance
                candidates[#candidates + 1] = {
                    id = quest.id,
                    index = quest.index,
                    number = quest.number or 0,
                    title = quest.title or "",
                    distance = distance,
                }
            elseif distance then
                questDistances[quest.id] = distance
            end
        end
    end

    table.sort(candidates, function(left, right)
        if left.distance ~= right.distance then
            return left.distance < right.distance
        end
        if left.number ~= right.number then
            return left.number < right.number
        end
        return left.id < right.id
    end)

    return candidates, questDistances
end

local function ShouldRunMovementUpdate(position, force)
    if force then
        return true
    end

    local now = GetTime and GetTime() or 0
    if now > 0
        and Quests.lastAutoFollowQuestUpdateTime
        and now - Quests.lastAutoFollowQuestUpdateTime < MOVEMENT_UPDATE_INTERVAL_SECONDS then
        return false
    end

    local previous = Quests.lastAutoFollowQuestUpdatePosition
    if previous and previous.mapId == position.mapId then
        local distance = position.hbd:GetZoneDistance(position.mapId, previous.x, previous.y, position.mapId, position.x, position.y)
        if distance and distance < MOVEMENT_MIN_DISTANCE_YARDS then
            return false
        end
    end

    return true
end

local function RememberUpdatePosition(position)
    Quests.lastAutoFollowQuestUpdatePosition = {
        x = position.x,
        y = position.y,
        mapId = position.mapId,
    }
    if GetTime then
        Quests.lastAutoFollowQuestUpdateTime = GetTime()
    end
end

local function StopMovementUpdates()
    movementFrame:SetScript("OnUpdate", nil)
    movementElapsed = 0
end

local function StartMovementUpdates()
    if GetMode() ~= AUTO_FOLLOW_MOVEMENT then
        StopMovementUpdates()
        return
    end

    movementElapsed = 0
    movementFrame:SetScript("OnUpdate", function(_, elapsed)
        movementElapsed = movementElapsed + (elapsed or 0)
        if movementElapsed < MOVEMENT_UPDATE_INTERVAL_SECONDS then
            return
        end

        movementElapsed = 0
        Quests:QueueAutoFollowQuestUpdate("movement", false)
    end)
end

function Quests:ClearAutoFollowQuestWatches()
    local owned = GetAutoFollowQuestIds()
    local watched = GetWatchedQuestIndexes()
    local changed = false

    self.autoFollowQuestWatchApplying = true
    for questId in pairs(owned) do
        local questIndex = watched[questId] or FindQuestLogIndex(questId)
        if questIndex and RemoveQuestWatchByIndex(questIndex) then
            changed = true
        end
        owned[questId] = nil
    end
    self.autoFollowQuestIds = owned
    self.autoFollowQuestWatchApplying = false
    if self.autoFollowQuestTrackerOrderSignature then
        self.autoFollowQuestTrackerOrder = nil
        self.autoFollowQuestTrackerOrderSignature = nil
        changed = true
    end

    if changed then
        RefreshQuestWatchDisplay()
    end
end

function Quests:UpdateAutoFollowQuestWatches(reason, force)
    if not IsEnabled() then
        self:ClearAutoFollowQuestWatches()
        StopMovementUpdates()
        return
    end

    local quests
    if reason == "quest-log" then
        quests = self.GetCachedQuestLogSnapshot and self:GetCachedQuestLogSnapshot()
            or (self.GetQuestLogSnapshot and self:GetQuestLogSnapshot())
            or {}

        local questSignature = BuildAutoFollowQuestSignature(quests)
        if not force and questSignature == self.autoFollowQuestSignature then
            return
        end
        self.autoFollowQuestSignature = questSignature
    end

    local mode = GetMode()
    if reason == "movement" and mode ~= AUTO_FOLLOW_MOVEMENT then
        return
    end
    if reason == "zone" and mode ~= AUTO_FOLLOW_ZONE and mode ~= AUTO_FOLLOW_MOVEMENT then
        return
    end
    if mode ~= AUTO_FOLLOW_ZONE and mode ~= AUTO_FOLLOW_MOVEMENT and self.autoFollowQuestTrackerOrderSignature then
        self.autoFollowQuestTrackerOrder = nil
        self.autoFollowQuestTrackerOrderSignature = nil
        RefreshQuestWatchDisplay()
    end

    local position = GetPlayerPosition()
    if not position then
        return
    end
    if reason == "movement" and not ShouldRunMovementUpdate(position, force) then
        return
    end

    local rangeYards = GetRangeYards()
    local watched = GetWatchedQuestIndexes()
    local owned = GetAutoFollowQuestIds()
    self.autoFollowQuestIds = owned
    quests = quests
        or self.GetCachedQuestLogSnapshot and self:GetCachedQuestLogSnapshot()
        or (self.GetQuestLogSnapshot and self:GetQuestLogSnapshot())
        or {}
    local currentZoneOnly = mode == AUTO_FOLLOW_ZONE
    local candidates, questDistances = BuildRankedQuestCandidates(position, rangeYards, quests, currentZoneOnly)
    local changed = false

    owned = PruneAutoFollowQuestOwnership(watched)
    self.autoFollowQuestIds = owned

    self.autoFollowQuestWatchApplying = true

    local desired = {}
    local desiredList = {}
    local manualWatchCount = 0

    for questId in pairs(watched) do
        if not owned[questId] then
            manualWatchCount = manualWatchCount + 1
        end
    end

    local autoWatchLimit = GetQuestWatchLimit() - manualWatchCount
    if autoWatchLimit < 0 then
        autoWatchLimit = 0
    end

    for _, candidate in ipairs(candidates) do
        if not watched[candidate.id] or owned[candidate.id] then
            if #desiredList >= autoWatchLimit then
                break
            end
            desired[candidate.id] = candidate
            desiredList[#desiredList + 1] = candidate
        end
    end

    for questId in pairs(owned) do
        if not desired[questId] then
            local questIndex = watched[questId] or FindQuestLogIndex(questId)
            if questIndex and RemoveQuestWatchByIndex(questIndex) then
                changed = true
            end
            owned[questId] = nil
        end
    end

    watched = GetWatchedQuestIndexes()
    for _, candidate in ipairs(desiredList) do
        local questIndex = watched[candidate.id] or candidate.index or FindQuestLogIndex(candidate.id)
        if watched[candidate.id] or AddQuestWatchByIndex(questIndex) then
            owned[candidate.id] = true
            changed = changed or not watched[candidate.id]
        end
    end

    if (mode == AUTO_FOLLOW_ZONE or mode == AUTO_FOLLOW_MOVEMENT)
        and UpdateAutoFollowQuestTrackerOrder(quests, questDistances) then
        changed = true
    end

    self.autoFollowQuestWatchApplying = false
    RememberUpdatePosition(position)

    if changed then
        RefreshQuestWatchDisplay()
    end

    if mode == AUTO_FOLLOW_MOVEMENT then
        StartMovementUpdates()
    end
end

function Quests:QueueAutoFollowQuestUpdate(reason, force)
    if self.autoFollowQuestUpdateQueued then
        if force then
            self.autoFollowQuestUpdateReason = reason
            self.autoFollowQuestUpdateForce = true
        end
        return
    end

    self.autoFollowQuestUpdateQueued = true
    self.autoFollowQuestUpdateReason = reason
    self.autoFollowQuestUpdateForce = force == true
    if C_Timer and C_Timer.After then
        C_Timer.After(QUEUED_UPDATE_DELAY_SECONDS, function()
            local queuedReason = Quests.autoFollowQuestUpdateReason
            local queuedForce = Quests.autoFollowQuestUpdateForce == true
            Quests.autoFollowQuestUpdateQueued = false
            Quests.autoFollowQuestUpdateReason = nil
            Quests.autoFollowQuestUpdateForce = nil
            Quests:UpdateAutoFollowQuestWatches(queuedReason, queuedForce)
        end)
        return
    end

    self.autoFollowQuestUpdateQueued = false
    self.autoFollowQuestUpdateReason = nil
    self.autoFollowQuestUpdateForce = nil
    self:UpdateAutoFollowQuestWatches(reason, force)
end

local function RegisterEventIfAvailable(eventName)
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end

RegisterEventIfAvailable("PLAYER_LOGIN")
RegisterEventIfAvailable("PLAYER_ENTERING_WORLD")
RegisterEventIfAvailable("ZONE_CHANGED_NEW_AREA")
RegisterEventIfAvailable("ZONE_CHANGED")
RegisterEventIfAvailable("ZONE_CHANGED_INDOORS")
RegisterEventIfAvailable("PLAYER_STARTED_MOVING")
RegisterEventIfAvailable("PLAYER_STOPPED_MOVING")
RegisterEventIfAvailable("QUEST_LOG_UPDATE")
RegisterEventIfAvailable("QUEST_WATCH_UPDATE")
RegisterEventIfAvailable("QUEST_ACCEPTED")
RegisterEventIfAvailable("QUEST_REMOVED")
RegisterEventIfAvailable("QUEST_TURNED_IN")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_STARTED_MOVING" then
        StartMovementUpdates()
        return
    end

    if event == "PLAYER_STOPPED_MOVING" then
        StopMovementUpdates()
        Quests:QueueAutoFollowQuestUpdate("movement", false)
        return
    end

    if event == "QUEST_LOG_UPDATE" then
        if Quests.InvalidateQuestSnapshot then
            Quests:InvalidateQuestSnapshot()
        end
        ReconcileAutoFollowQuestOwnership()
        Quests:QueueAutoFollowQuestUpdate("quest-log", false)
        return
    end

    if event == "QUEST_WATCH_UPDATE" then
        ReconcileAutoFollowQuestOwnership()
        return
    end

    if event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then
        if Quests.InvalidateQuestSnapshot then
            Quests:InvalidateQuestSnapshot()
        end
        ReconcileAutoFollowQuestOwnership()
        Quests:QueueAutoFollowQuestUpdate("quest-log", true)
        return
    end

    if event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_INDOORS" then
        Quests:QueueAutoFollowQuestUpdate("zone", true)
    elseif IsEnabled() then
        Quests:QueueAutoFollowQuestUpdate(event, true)
    end
end)
