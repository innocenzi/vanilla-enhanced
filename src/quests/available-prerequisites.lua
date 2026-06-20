local Quests = _G.VanillaEnhanced:GetModule("quests")

local function HasFlag(mask, flag)
    return mask and flag and flag > 0 and (mask % (flag * 2)) >= flag
end

local function GetCompletedQuests()
    if GetQuestsCompleted then
        local ok, completed = pcall(GetQuestsCompleted)
        if ok and type(completed) == "table" then
            return completed
        end
    end

    return {}
end

local function IsQuestCompleted(questId, completed)
    if not questId then
        return false
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

local function IsActiveOrComplete(questId, active, completed)
    return active[questId] == true or IsQuestCompleted(questId, completed)
end

local function IsPreQuestSingleFulfilled(preQuestSingle, completed)
    if not preQuestSingle then
        return true
    end

    for _, questId in ipairs(preQuestSingle) do
        if IsQuestCompleted(questId, completed) then
            return true
        end
    end

    return false
end

local function IsAnyExclusiveComplete(questId, completed)
    local dbQuest = VanillaEnhancedQuestsDB and VanillaEnhancedQuestsDB.quests and VanillaEnhancedQuestsDB.quests[questId]
    if not dbQuest or not dbQuest.ex then
        return false
    end

    for _, exclusiveQuestId in ipairs(dbQuest.ex) do
        if IsQuestCompleted(exclusiveQuestId, completed) then
            return true
        end
    end

    return false
end

local function IsPreQuestGroupFulfilled(preQuestGroup, completed)
    if not preQuestGroup then
        return true
    end

    for _, questId in ipairs(preQuestGroup) do
        if questId < 0 then
            if not IsQuestCompleted(-questId, completed) then
                return false
            end
        elseif not IsQuestCompleted(questId, completed) and not IsAnyExclusiveComplete(questId, completed) then
            return false
        end
    end

    return true
end

local function HasNoExclusiveQuest(dbQuest, active, completed)
    if not dbQuest.ex then
        return true
    end

    for _, questId in ipairs(dbQuest.ex) do
        if IsActiveOrComplete(questId, active, completed) then
            return false
        end
    end

    return true
end

local function HasNoBreadcrumbConflict(dbQuest, active, completed)
    if dbQuest.bf and dbQuest.bf ~= 0 and IsActiveOrComplete(dbQuest.bf, active, completed) then
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

    return active, GetCompletedQuests()
end

function Quests:MeetsAvailableQuestPrerequisites(questId, dbQuest, active, completed)
    if active[questId] or IsQuestCompleted(questId, completed) then
        return false
    end
    if not IsPreQuestSingleFulfilled(dbQuest.ps, completed) then
        return false
    end
    if not dbQuest.ps and not IsPreQuestGroupFulfilled(dbQuest.pg, completed) then
        return false
    end
    if not HasNoExclusiveQuest(dbQuest, active, completed) then
        return false
    end
    if HasFlag(dbQuest.sf, 2) then
        return false
    end
    if dbQuest.nc and IsActiveOrComplete(dbQuest.nc, active, completed) then
        return false
    end
    if dbQuest.pq and not active[dbQuest.pq] then
        return false
    end
    if dbQuest.au and IsQuestCompleted(dbQuest.au, completed) then
        return false
    end
    if dbQuest["as"] and not IsActiveOrComplete(dbQuest["as"], active, completed) then
        return false
    end
    if dbQuest.db and active[dbQuest.db] then
        return false
    end
    return HasNoBreadcrumbConflict(dbQuest, active, completed)
end
