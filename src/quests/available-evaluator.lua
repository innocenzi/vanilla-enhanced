local Quests = _G.VanillaEnhanced:GetModule("quests")

local AvailableQuestEvaluator = {}
AvailableQuestEvaluator.__index = AvailableQuestEvaluator

local function CopyTable(source)
    local target = {}

    for key, value in pairs(source or {}) do
        target[key] = value
    end

    return target
end

local function GetPlayerLevel(context)
    return context and context.playerLevel or (UnitLevel and UnitLevel("player") or 0)
end

function AvailableQuestEvaluator:Create(owner, context)
    return setmetatable({
        owner = owner,
        context = context or {},
    }, self)
end

function AvailableQuestEvaluator:HasAvailableStart(dbQuest)
    return dbQuest and dbQuest.starts ~= nil
end

function AvailableQuestEvaluator:MeetsRequiredLevel(dbQuest)
    local playerLevel = GetPlayerLevel(self.context)
    return not (dbQuest.rl and playerLevel > 0 and playerLevel < dbQuest.rl)
end

function AvailableQuestEvaluator:MeetsMaximumLevel(dbQuest)
    local playerLevel = GetPlayerLevel(self.context)
    return not (dbQuest.mx and playerLevel > 0 and playerLevel > dbQuest.mx)
end

function AvailableQuestEvaluator:MeetsConfiguredLevelWindow(dbQuest)
    local context = self.context
    if not context.onlyAroundPlayerLevel then
        return true
    end

    return self.owner:IsAvailableQuestAroundPlayerLevel(dbQuest, GetPlayerLevel(context), context)
end

function AvailableQuestEvaluator:IsEligible(questId, dbQuest)
    if not self:HasAvailableStart(dbQuest) then
        return false, "missing-start"
    end

    local context = self.context
    local active = context.active or {}
    local completed = context.completed or {}

    if not self.owner:MeetsAvailableQuestPrerequisites(questId, dbQuest, active, completed) then
        return false, "prerequisites"
    end
    if not self:MeetsRequiredLevel(dbQuest) then
        return false, "required-level"
    end
    if not self:MeetsMaximumLevel(dbQuest) then
        return false, "maximum-level"
    end
    if not self:MeetsConfiguredLevelWindow(dbQuest) then
        return false, "level-window"
    end
    if not self.owner:HasActiveAvailableQuestEventWindow(dbQuest) then
        return false, "event-window"
    end
    if not self.owner:MeetsAvailableQuestPlayerRequirements(dbQuest, context) then
        return false, "player-requirements"
    end

    return true
end

function AvailableQuestEvaluator:HasVisibleStart(dbQuest)
    local context = self.context
    if not context.onlyNearby then
        return true
    end

    return self.owner:HasVisibleAvailableQuestStart(dbQuest, context)
end

function AvailableQuestEvaluator:IsRenderable(questId, dbQuest)
    local eligible, reason = self:IsEligible(questId, dbQuest)
    if not eligible then
        return false, reason
    end
    if not self:HasVisibleStart(dbQuest) then
        return false, "visible-start"
    end

    return true
end

function Quests:CreateAvailableQuestEvaluator(context)
    return AvailableQuestEvaluator:Create(self, context)
end

function Quests:BuildAvailableQuestEvaluatorContext(settings, active, completed, extraContext)
    local context = CopyTable(extraContext)
    local playerContext
    settings = settings or context.settings

    if context.professions == nil or context.reputations == nil then
        playerContext = self:BuildAvailableQuestPlayerContext()
    else
        playerContext = {}
    end

    context.settings = settings
    context.active = active or context.active or {}
    context.completed = completed or context.completed or {}
    context.playerLevel = context.playerLevel or (UnitLevel and UnitLevel("player") or 0)
    context.professions = context.professions or playerContext.professions
    context.reputations = context.reputations or playerContext.reputations

    if settings then
        context.onlyAroundPlayerLevel = settings.onlyShowAvailableQuestsAroundPlayerLevel == true
        context.availableQuestLevelsBelowPlayer = settings.availableQuestLevelsBelowPlayer
        context.availableQuestLevelsAbovePlayer = settings.availableQuestLevelsAbovePlayer
    elseif context.onlyAroundPlayerLevel == nil then
        context.onlyAroundPlayerLevel = false
    end
    if context.onlyNearby == nil then
        context.onlyNearby = false
    end

    return context
end

function Quests:IsAvailableQuestEligible(questId, dbQuest, context)
    local evaluator = self:CreateAvailableQuestEvaluator(context)
    return evaluator:IsEligible(questId, dbQuest)
end

Quests.AvailableQuestEvaluator = AvailableQuestEvaluator
