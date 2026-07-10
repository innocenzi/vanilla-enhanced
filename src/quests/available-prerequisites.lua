local Quests = _G.VanillaEnhanced:GetModule("quests")

local function GetCompletedQuests()
    if GetQuestsCompleted then
        local ok, completed = pcall(GetQuestsCompleted)
        if ok and type(completed) == "table" then
            return completed, true
        end
    end

    return {}, false
end

local function IsQuestCompleted(questId, completed, completedAuthoritative)
    if not questId then
        return false
    end
    if completedAuthoritative then
        return completed and completed[questId] == true
    end
    if completed and completed[questId] then
        return true
    end
    if IsQuestFlaggedCompleted then
        local ok, done = pcall(IsQuestFlaggedCompleted, questId)
        if ok and done then
            return true
        end
    end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questId)
        if ok and done then
            return true
        end
    end
    return false
end

local function IsActiveOrComplete(questId, active, completed, completedAuthoritative)
    return active[questId] == true or IsQuestCompleted(questId, completed, completedAuthoritative)
end

local function IsPreQuestSingleFulfilled(preQuestSingle, completed, completedAuthoritative)
    if not preQuestSingle then
        return true
    end

    for _, questId in ipairs(preQuestSingle) do
        if IsQuestCompleted(questId, completed, completedAuthoritative) then
            return true
        end
    end

    return false
end

local function IsAnyExclusiveComplete(questId, completed, completedAuthoritative)
    local dbQuest = VanillaEnhancedQuestsDB and VanillaEnhancedQuestsDB.quests and VanillaEnhancedQuestsDB.quests[questId]
    if not dbQuest or not dbQuest.ex then
        return false
    end

    for _, exclusiveQuestId in ipairs(dbQuest.ex) do
        if IsQuestCompleted(exclusiveQuestId, completed, completedAuthoritative) then
            return true
        end
    end

    return false
end

local function IsPreQuestGroupFulfilled(preQuestGroup, completed, completedAuthoritative)
    if not preQuestGroup then
        return true
    end

    for _, questId in ipairs(preQuestGroup) do
        if questId < 0 then
            if not IsQuestCompleted(-questId, completed, completedAuthoritative) then
                return false
            end
        elseif not IsQuestCompleted(questId, completed, completedAuthoritative)
            and not IsAnyExclusiveComplete(questId, completed, completedAuthoritative) then
            return false
        end
    end

    return true
end

local function HasNoExclusiveQuest(dbQuest, active, completed, completedAuthoritative)
    if not dbQuest.ex then
        return true
    end

    for _, questId in ipairs(dbQuest.ex) do
        if IsActiveOrComplete(questId, active, completed, completedAuthoritative) then
            return false
        end
    end

    return true
end

local function HasNoBreadcrumbConflict(dbQuest, active, completed, completedAuthoritative)
    if dbQuest.bf and dbQuest.bf ~= 0
        and IsActiveOrComplete(dbQuest.bf, active, completed, completedAuthoritative) then
        return false
    end

    if dbQuest.bc then
        for _, breadcrumbQuestId in ipairs(dbQuest.bc) do
            if active[breadcrumbQuestId] then
                return false
            end
        end
    end

    return true
end

function Quests:BuildAvailableQuestState(quests)
    local active = {}

    for _, quest in ipairs(quests or {}) do
        if quest.id then
            active[quest.id] = true
        end
    end

    local completed, completedAuthoritative = GetCompletedQuests()
    return active, completed, completedAuthoritative
end

function Quests:MeetsAvailableQuestPrerequisites(questId, dbQuest, active, completed, completedAuthoritative)
    if active[questId] then
        return false, "active"
    end
    local completionStateAvailable = completedAuthoritative == true
        or IsQuestFlaggedCompleted ~= nil
        or (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) ~= nil
    if not completionStateAvailable then
        if dbQuest.pq and not active[dbQuest.pq] then
            return false, "parent-inactive"
        end
        if dbQuest.db and active[dbQuest.db] then
            return false, "disabled-by-active-quest"
        end
        if dbQuest.nc and active[dbQuest.nc] then
            return false, "chain-advanced"
        end
        if dbQuest.ex then
            for _, exclusiveQuestId in ipairs(dbQuest.ex) do
                if active[exclusiveQuestId] then return false, "exclusive" end
            end
        end
        if dbQuest.bf and dbQuest.bf ~= 0 and active[dbQuest.bf] then
            return false, "breadcrumb-conflict"
        end
        if dbQuest.bc then
            for _, breadcrumbQuestId in ipairs(dbQuest.bc) do
                if active[breadcrumbQuestId] then return false, "breadcrumb-conflict" end
            end
        end
        return true, nil, {"completion-unknown"}
    end
    if IsQuestCompleted(questId, completed, completedAuthoritative)
        and (not self:IsRepeatableQuest(dbQuest) or self:IsResettableQuest(dbQuest)) then
        return false, "completed"
    end
    if not IsPreQuestSingleFulfilled(dbQuest.ps, completed, completedAuthoritative) then
        return false, "prerequisite"
    end
    if not dbQuest.ps and not IsPreQuestGroupFulfilled(dbQuest.pg, completed, completedAuthoritative) then
        return false, "prerequisite"
    end
    if not HasNoExclusiveQuest(dbQuest, active, completed, completedAuthoritative) then
        return false, "exclusive"
    end
    if dbQuest.nc and IsActiveOrComplete(dbQuest.nc, active, completed, completedAuthoritative) then
        return false, "chain-advanced"
    end
    if dbQuest.pq and not active[dbQuest.pq] then
        return false, "parent-inactive"
    end
    if dbQuest.au and IsQuestCompleted(dbQuest.au, completed, completedAuthoritative) then
        return false, "availability-ended"
    end
    if dbQuest["as"] and not IsActiveOrComplete(dbQuest["as"], active, completed, completedAuthoritative) then
        return false, "availability-not-started"
    end
    if dbQuest.db and active[dbQuest.db] then
        return false, "disabled-by-active-quest"
    end
    if not HasNoBreadcrumbConflict(dbQuest, active, completed, completedAuthoritative) then
        return false, "breadcrumb-conflict"
    end
    return true
end
