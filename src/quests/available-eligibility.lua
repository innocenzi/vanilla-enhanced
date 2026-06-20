local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

local AVAILABLE_QUEST_LEVELS_BELOW_PLAYER = 5
local AVAILABLE_QUEST_LEVELS_ABOVE_PLAYER = 3
local NEARBY_AVAILABLE_QUEST_RADIUS_YARDS = 1200

local function IsQuestAroundPlayerLevel(dbQuest, playerLevel)
    if not playerLevel or playerLevel <= 0 then
        return true
    end

    local questLevel = dbQuest.ql or dbQuest.rl
    if not questLevel or questLevel <= 0 then
        return true
    end

    return questLevel >= playerLevel - AVAILABLE_QUEST_LEVELS_BELOW_PLAYER
        and questLevel <= playerLevel + AVAILABLE_QUEST_LEVELS_ABOVE_PLAYER
end

local function HasVisibleAvailableQuestStart(dbQuest, context)
    if not context.onlyNearby then
        return true
    end

    for uiMapId, clusters in pairs(dbQuest.starts or {}) do
        for _, cluster in ipairs(clusters) do
            if Quests:ShouldShowAvailableQuestStart(uiMapId, cluster, context) then
                return true
            end
        end
    end

    return false
end

function Quests:BuildAvailableQuestEligibilityContext(settings)
    local playerContext = self:BuildAvailableQuestPlayerContext()

    return {
        settings = settings,
        playerLevel = UnitLevel and UnitLevel("player") or 0,
        onlyNearby = false,
        onlyAroundPlayerLevel = settings.onlyShowAvailableQuestsAroundPlayerLevel == true,
        professions = playerContext.professions,
        reputations = playerContext.reputations,
    }
end

function Quests:IsAvailableQuestBelowPlayerLevel(dbQuest, context)
    local playerLevel = context and context.playerLevel or (UnitLevel and UnitLevel("player") or 0)
    if not playerLevel or playerLevel <= 0 or not dbQuest then
        return false
    end

    local questLevel = dbQuest.ql or dbQuest.rl
    if not questLevel or questLevel <= 0 then
        return false
    end

    return questLevel < playerLevel - AVAILABLE_QUEST_LEVELS_BELOW_PLAYER
end

function Quests:IsAvailableQuestAbovePlayerLevel(dbQuest, context)
    local playerLevel = context and context.playerLevel or (UnitLevel and UnitLevel("player") or 0)
    if not playerLevel or playerLevel <= 0 or not dbQuest then
        return false
    end

    local questLevel = dbQuest.ql or dbQuest.rl
    if not questLevel or questLevel <= 0 then
        return false
    end

    return questLevel > playerLevel + AVAILABLE_QUEST_LEVELS_ABOVE_PLAYER
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

function Quests:IsQuestAvailable(questId, dbQuest, active, completed, context)
    if not dbQuest or not dbQuest.starts then
        return false
    end
    if not self:MeetsAvailableQuestPrerequisites(questId, dbQuest, active, completed) then
        return false
    end

    local playerLevel = context and context.playerLevel or (UnitLevel and UnitLevel("player") or 0)
    if dbQuest.rl and playerLevel > 0 and playerLevel < dbQuest.rl then
        return false
    end
    if dbQuest.mx and playerLevel > 0 and playerLevel > dbQuest.mx then
        return false
    end
    if context and context.onlyAroundPlayerLevel and not IsQuestAroundPlayerLevel(dbQuest, playerLevel) then
        return false
    end
    if not self:HasActiveAvailableQuestEventWindow(dbQuest) then
        return false
    end
    if not self:MeetsAvailableQuestPlayerRequirements(dbQuest, context) then
        return false
    end
    if context and not HasVisibleAvailableQuestStart(dbQuest, context) then
        return false
    end

    return true
end
