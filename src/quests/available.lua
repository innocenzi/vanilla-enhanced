local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local NEARBY_AVAILABLE_REFRESH_MIN_INTERVAL = 1.0
local NEARBY_AVAILABLE_REFRESH_MIN_DISTANCE_YARDS = 80

if Quests.availableQuestCacheDirty == nil then
    Quests.availableQuestCacheDirty = true
end

local function GetHBD()
    return Quests.hbd or (LibStub and LibStub("HereBeDragons-2.0", true))
end

local function BuildAvailableQuestRenderContext(settings, eligibilityContext)
    local context = {
        settings = settings,
        playerLevel = eligibilityContext and eligibilityContext.playerLevel or (UnitLevel and UnitLevel("player") or 0),
        onlyNearby = settings.onlyShowNearbyAvailableQuests == true,
        onlyAroundPlayerLevel = settings.onlyShowAvailableQuestsAroundPlayerLevel == true,
    }

    if context.onlyNearby then
        context.hbd = GetHBD()
        if context.hbd and context.hbd.GetPlayerZonePosition then
            context.playerX, context.playerY, context.playerMapId = context.hbd:GetPlayerZonePosition(true)
        end
    end

    return context
end

function Quests:InvalidateAvailableQuestCache()
    self.availableQuestCache = nil
    self.availableQuestCacheDirty = true
end

local function RebuildAvailableQuestCache(self, quests, settings)
    local active, completed = self:BuildAvailableQuestState(quests)
    local context = self:BuildAvailableQuestEligibilityContext(settings)
    local questIds = {}

    for questId, dbQuest in pairs(VanillaEnhancedQuestsDB.quests) do
        if self:IsQuestAvailable(questId, dbQuest, active, completed, context) then
            questIds[#questIds + 1] = questId
        end
    end

    self.availableQuestCache = {
        questIds = questIds,
        eligibilityContext = context,
    }
    self.availableQuestCacheDirty = false
    return self.availableQuestCache
end

function Quests:AddAvailableQuestPins(quests)
    local settings = self:GetSettings()
    if settings.showAvailableQuests ~= true then
        return
    end
    if not self.AddAvailablePins or not VanillaEnhancedQuestsDB or not VanillaEnhancedQuestsDB.quests then
        return
    end

    local cache = self.availableQuestCache
    if self.availableQuestCacheDirty or not cache then
        cache = RebuildAvailableQuestCache(self, quests, settings)
    end

    local context = BuildAvailableQuestRenderContext(settings, cache.eligibilityContext)
    for _, questId in ipairs(cache.questIds or {}) do
        local dbQuest = VanillaEnhancedQuestsDB.quests[questId]
        if dbQuest then
            self:AddAvailablePins(questId, dbQuest, context)
        end
    end
end

function Quests:ShouldRefreshNearbyAvailableQuestsOnMovement()
    local settings = self:GetSettings()
    if not (settings.enabled ~= false
        and settings.showMapMarkers ~= false
        and settings.showAvailableQuests == true
        and settings.onlyShowNearbyAvailableQuests == true) then
        return false
    end

    local now = GetTime and GetTime() or 0
    if now > 0
        and self.lastNearbyAvailableQuestRefreshTime
        and now - self.lastNearbyAvailableQuestRefreshTime < NEARBY_AVAILABLE_REFRESH_MIN_INTERVAL then
        return false
    end

    local hbd = GetHBD()
    if hbd and hbd.GetPlayerZonePosition then
        local playerX, playerY, playerMapId = hbd:GetPlayerZonePosition(true)
        local previous = self.lastNearbyAvailableQuestRefresh

        if playerX and playerY and playerMapId and previous and previous.mapId == playerMapId then
            local distance
            if hbd.GetZoneDistance then
                distance = hbd:GetZoneDistance(playerMapId, previous.x, previous.y, playerMapId, playerX, playerY)
            end

            if distance and distance < NEARBY_AVAILABLE_REFRESH_MIN_DISTANCE_YARDS then
                return false
            end
        end

        if playerX and playerY and playerMapId then
            self.lastNearbyAvailableQuestRefresh = {
                x = playerX,
                y = playerY,
                mapId = playerMapId,
            }
        end
    end

    if now > 0 then
        self.lastNearbyAvailableQuestRefreshTime = now
    end
    return true
end
