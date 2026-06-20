local VanillaEnhanced = _G.VanillaEnhanced
local Quests = VanillaEnhanced:GetModule("quests")

function Quests:BuildAvailableQuestEligibilityContext(settings, active, completed, extraContext)
    return self:BuildAvailableQuestEvaluatorContext(settings, active, completed, extraContext)
end

function Quests:IsQuestAvailable(questId, dbQuest, active, completed, context)
    context = self:BuildAvailableQuestEvaluatorContext(
        context and context.settings or nil,
        active,
        completed,
        context
    )

    local evaluator = self:CreateAvailableQuestEvaluator(context)
    return evaluator:IsRenderable(questId, dbQuest)
end
