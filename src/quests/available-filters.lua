local Quests = _G.VanillaEnhanced:GetModule("quests")

local DEFAULT_AVAILABLE_QUEST_LEVELS_BELOW_PLAYER = 5
local DEFAULT_AVAILABLE_QUEST_LEVELS_ABOVE_PLAYER = 3
local AVAILABLE_QUEST_LEVEL_WINDOW_MIN = 0
local AVAILABLE_QUEST_LEVEL_WINDOW_MAX = 10
local NEARBY_AVAILABLE_QUEST_RADIUS_YARDS = 1200

local function GetAvailableQuestLevel(dbQuest)
    if not dbQuest then
        return nil
    end
    if dbQuest.ql and dbQuest.ql > 0 then
        return dbQuest.ql
    end
    if dbQuest.rl and dbQuest.rl > 0 then
        return dbQuest.rl
    end
    return nil
end

local function ClampLevelWindowSetting(value, defaultValue)
    value = tonumber(value) or defaultValue
    value = math.floor(value + 0.5)

    if value < AVAILABLE_QUEST_LEVEL_WINDOW_MIN then
        return AVAILABLE_QUEST_LEVEL_WINDOW_MIN
    end
    if value > AVAILABLE_QUEST_LEVEL_WINDOW_MAX then
        return AVAILABLE_QUEST_LEVEL_WINDOW_MAX
    end
    return value
end

function Quests:GetAvailableQuestLevelWindow(context)
    local settings = context and context.settings or (self.GetSettings and self:GetSettings() or nil)
    local below = context and context.availableQuestLevelsBelowPlayer
    local above = context and context.availableQuestLevelsAbovePlayer

    if below == nil and settings then
        below = settings.availableQuestLevelsBelowPlayer
    end
    if above == nil and settings then
        above = settings.availableQuestLevelsAbovePlayer
    end

    return ClampLevelWindowSetting(below, DEFAULT_AVAILABLE_QUEST_LEVELS_BELOW_PLAYER),
        ClampLevelWindowSetting(above, DEFAULT_AVAILABLE_QUEST_LEVELS_ABOVE_PLAYER)
end

function Quests:IsAvailableQuestAroundPlayerLevel(dbQuest, playerLevel, context)
    if not playerLevel or playerLevel <= 0 then
        return true
    end

    local questLevel = GetAvailableQuestLevel(dbQuest)
    if not questLevel or questLevel <= 0 then
        return true
    end

    local levelsBelowPlayer, levelsAbovePlayer = self:GetAvailableQuestLevelWindow(context)
    return questLevel >= playerLevel - levelsBelowPlayer
        and questLevel <= playerLevel + levelsAbovePlayer
end

function Quests:IsAvailableQuestBelowPlayerLevel(dbQuest, context)
    local playerLevel = context and context.playerLevel or (UnitLevel and UnitLevel("player") or 0)
    if not playerLevel or playerLevel <= 0 or not dbQuest then
        return false
    end

    local questLevel = GetAvailableQuestLevel(dbQuest)
    if not questLevel or questLevel <= 0 then
        return false
    end

    local levelsBelowPlayer = self:GetAvailableQuestLevelWindow(context)
    return questLevel < playerLevel - levelsBelowPlayer
end

function Quests:IsAvailableQuestAbovePlayerLevel(dbQuest, context)
    local playerLevel = context and context.playerLevel or (UnitLevel and UnitLevel("player") or 0)
    if not playerLevel or playerLevel <= 0 or not dbQuest then
        return false
    end

    local questLevel = GetAvailableQuestLevel(dbQuest)
    if not questLevel or questLevel <= 0 then
        return false
    end

    local _, levelsAbovePlayer = self:GetAvailableQuestLevelWindow(context)
    return questLevel > playerLevel + levelsAbovePlayer
end

function Quests:ShouldShowAvailableQuestStart(uiMapId, cluster, context)
    if not context or not context.onlyNearby then
        return true
    end
    if not context.hbd or not context.playerMapId or not context.playerX or not context.playerY then
        return false
    end
    if not uiMapId or not cluster or not cluster.x or not cluster.y then
        return false
    end

    local distance = context.hbd:GetZoneDistance(
        context.playerMapId,
        context.playerX,
        context.playerY,
        uiMapId,
        cluster.x / 100,
        cluster.y / 100
    )

    return distance and distance <= NEARBY_AVAILABLE_QUEST_RADIUS_YARDS
end

function Quests:HasVisibleAvailableQuestStart(dbQuest, context)
    if not context.onlyNearby then
        return true
    end

    for uiMapId, clusters in pairs(dbQuest.starts or {}) do
        for _, cluster in ipairs(clusters) do
            if self:ShouldShowAvailableQuestStart(uiMapId, cluster, context) then
                return true
            end
        end
    end

    return false
end
