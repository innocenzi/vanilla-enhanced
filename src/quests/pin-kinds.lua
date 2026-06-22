local Quests = _G.VanillaEnhanced:GetModule("quests")

local MARKER_SYMBOLS = {
    available = "!",
    turnin = "?",
}

local REPEATABLE_MARKER_COLOR = { 0.55, 0.85, 1 }
local SPECIAL_FLAG_REPEATABLE = 1
local QUEST_FLAG_DAILY = 4096
local QUEST_FLAG_WEEKLY = 32768
local QUEST_FLAG_MONTHLY = 65536

local MARKER_TEXTURES = {
    talk = [[Interface\GossipFrame\GossipGossipIcon]],
}

local AREA_KINDS = {
    loot = true,
    slay = true,
}

local function HasFlag(mask, flag)
    return mask and flag and flag > 0 and (mask % (flag * 2)) >= flag
end

function Quests:GetPinMarkerSymbol(kind, fallback)
    return MARKER_SYMBOLS[kind] or fallback
end

function Quests:GetPinMarkerTexture(kind)
    return MARKER_TEXTURES[kind]
end

function Quests:IsRepeatableQuest(dbQuest)
    return HasFlag(dbQuest and dbQuest.sf, SPECIAL_FLAG_REPEATABLE)
end

function Quests:IsResettableQuest(dbQuest)
    local flags = dbQuest and dbQuest.rf
    return HasFlag(flags, QUEST_FLAG_DAILY) or HasFlag(flags, QUEST_FLAG_WEEKLY) or HasFlag(flags, QUEST_FLAG_MONTHLY)
end

function Quests:IsReputationQuest(dbQuest)
    return dbQuest and dbQuest.rq == 1
end

function Quests:GetRepeatableQuestMarkerColor(dbQuest)
    if self:IsRepeatableQuest(dbQuest) then
        return REPEATABLE_MARKER_COLOR
    end
    return nil
end

function Quests:ShouldShowQuestOnMaps(dbQuest, settings)
    settings = settings or self:GetSettings()
    if self:IsRepeatableQuest(dbQuest) and settings.showRepeatableQuests == false then
        return false
    end
    if self:IsReputationQuest(dbQuest) and settings.showReputationQuests == false then
        return false
    end
    return true
end

function Quests:IsQuestObjectiveAreaKind(kind)
    return AREA_KINDS[kind] == true
end
