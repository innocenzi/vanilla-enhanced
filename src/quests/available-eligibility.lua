local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

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
    if context and context.onlyAroundPlayerLevel and not self:IsAvailableQuestAroundPlayerLevel(dbQuest, playerLevel) then
        return false
    end
    if not self:HasActiveAvailableQuestEventWindow(dbQuest) then
        return false
    end
    if not self:MeetsAvailableQuestPlayerRequirements(dbQuest, context) then
        return false
    end
    if context and not self:HasVisibleAvailableQuestStart(dbQuest, context) then
        return false
    end

    return true
end
