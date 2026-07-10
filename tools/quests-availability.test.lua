local function expect(value, message)
    if not value then error(message, 2) end
end

local function expectEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local Quests = {}
VanillaEnhanced = {
    GetModule = function() return Quests end,
    T = function(_, key) return key end,
}
_G.VanillaEnhanced = VanillaEnhanced

local playerRace = "Dwarf"
local playerClass = "WARRIOR"
function UnitRace() return "Dwarf", playerRace end
function UnitClass() return "Warrior", playerClass end
function UnitLevel() return 9 end

function Quests:IsRepeatableQuest(dbQuest)
    return dbQuest and dbQuest.sf and dbQuest.sf % 2 == 1
end
function Quests:IsResettableQuest() return false end
function Quests:IsAvailableQuestAroundPlayerLevel() return true end
function Quests:HasVisibleAvailableQuestStart() return true end
function Quests:GetSettings() return {} end
function Quests:GetLocalizedQuestTitle(_, _, fallback) return fallback end

VanillaEnhancedQuestsDB = { quests = {} }

assert(loadfile("src/quests/available-events.lua"))()
assert(loadfile("src/quests/available-player.lua"))()
assert(loadfile("src/quests/available-prerequisites.lua"))()
assert(loadfile("src/quests/available-evaluator.lua"))()
assert(loadfile("src/quests/pin-data.lua"))()

local fallbackCompletionCalls = 0
local completedSnapshot = {}
function GetQuestsCompleted() return completedSnapshot end
function IsQuestFlaggedCompleted()
    fallbackCompletionCalls = fallbackCompletionCalls + 1
    return false
end

local frostmane = {
    t = "Frostmane Hold",
    starts = { [1426] = {{46.73, 53.83}} },
    rl = 7,
    ql = 9,
    rr = 77,
    sf = 2,
}
VanillaEnhancedQuestsDB.quests[287] = frostmane

local active, completed, authoritative = Quests:BuildAvailableQuestState({})
local context = Quests:BuildAvailableQuestEvaluatorContext({}, active, completed, {
    completedAuthoritative = authoritative,
    professions = {},
    reputations = {},
    professionsReliable = true,
    reputationsReliable = true,
    calendarDay = 11,
    calendarMonth = 7,
    calendarYear = 2026,
})
local eligible, reason, uncertainties = Quests:CreateAvailableQuestEvaluator(context):IsEligible(287, frostmane)
expect(eligible, "exploration quests must remain eligible")
expectEqual(reason, nil, "eligible quest has no failure reason")
expectEqual(uncertainties, nil, "fully known quest is not uncertain")
expectEqual(fallbackCompletionCalls, 0, "authoritative completion snapshot avoids per-quest calls")

completedSnapshot = { [287] = true }
active, completed, authoritative = Quests:BuildAvailableQuestState({})
context = Quests:BuildAvailableQuestEvaluatorContext({}, active, completed, {
    completedAuthoritative = authoritative,
    professions = {}, reputations = {}, professionsReliable = true, reputationsReliable = true,
})
eligible, reason = Quests:CreateAvailableQuestEvaluator(context):IsEligible(287, frostmane)
expect(not eligible and reason == "completed", "completed quest has a precise reason")
expectEqual(fallbackCompletionCalls, 0, "completed snapshot remains authoritative")

GetQuestsCompleted = nil
function IsQuestFlaggedCompleted(questId)
    fallbackCompletionCalls = fallbackCompletionCalls + 1
    return questId == 999
end
local fallbackQuest = { starts = { [1] = {{1, 1}} }, ps = {999} }
active, completed, authoritative = Quests:BuildAvailableQuestState({})
expect(not authoritative, "missing bulk API enables fallback")
local prerequisitesMet = Quests:MeetsAvailableQuestPrerequisites(1000, fallbackQuest, active, completed, authoritative)
expect(prerequisitesMet, "fallback completion API satisfies prerequisites")
expect(fallbackCompletionCalls > 0, "fallback completion API was used")

GetQuestsCompleted = function() return { [10] = true, [11] = true } end
active, completed, authoritative = Quests:BuildAvailableQuestState({})
expect(Quests:MeetsAvailableQuestPrerequisites(20, { ps = {9, 10} }, active, completed, authoritative),
    "single prerequisites use alternatives")
expect(Quests:MeetsAvailableQuestPrerequisites(21, { pg = {10, 11} }, active, completed, authoritative),
    "group prerequisites require every quest")
local met, preciseReason = Quests:MeetsAvailableQuestPrerequisites(22, { pg = {10, 12} }, active, completed, authoritative)
expect(not met and preciseReason == "prerequisite", "missing group prerequisite is rejected")
met, preciseReason = Quests:MeetsAvailableQuestPrerequisites(23, { ex = {10} }, active, completed, authoritative)
expect(not met and preciseReason == "exclusive", "completed exclusive quest is rejected")
met, preciseReason = Quests:MeetsAvailableQuestPrerequisites(24, { pq = 50 }, active, completed, authoritative)
expect(not met and preciseReason == "parent-inactive", "inactive parent quest is rejected")
met, preciseReason = Quests:MeetsAvailableQuestPrerequisites(25, { bf = 10 }, active, completed, authoritative)
expect(not met and preciseReason == "breadcrumb-conflict", "completed breadcrumb target rejects breadcrumb")

local repeatable = { sf = 1 }
expect(Quests:MeetsAvailableQuestPrerequisites(10, repeatable, active, completed, authoritative),
    "ordinary repeatable quest remains available after completion")
function Quests:IsResettableQuest(dbQuest) return dbQuest and dbQuest.daily == true end
met, preciseReason = Quests:MeetsAvailableQuestPrerequisites(10, { sf = 1, daily = true }, active, completed, authoritative)
expect(not met and preciseReason == "completed", "completed resettable quest waits for reset")

local professionQuest = { starts = { [1] = {{1, 1}} }, sk = {202, 200} }
context = Quests:BuildAvailableQuestEvaluatorContext({}, {}, {}, {
    completedAuthoritative = true,
    professions = {}, reputations = {}, professionsReliable = false, reputationsReliable = true,
})
eligible, reason, uncertainties = Quests:CreateAvailableQuestEvaluator(context):IsEligible(1001, professionQuest)
expect(eligible and reason == nil, "unknown profession state fails open")
expect(uncertainties and uncertainties[1] == "profession-unknown", "unknown profession is reported")

local knownSpells = {}
function IsSpellKnown(spellId) return knownSpells[spellId] == true end
local omarion = { starts = { [1] = {{1, 1}} }, rk = {{197, -4}, {164, -4}, {165, -4}} }
context = Quests:BuildAvailableQuestEvaluatorContext({}, {}, {}, {
    completedAuthoritative = true,
    professions = {}, reputations = {}, professionsReliable = true, reputationsReliable = true,
})
eligible = Quests:CreateAvailableQuestEvaluator(context):IsEligible(9233, omarion)
expect(eligible, "negative ranks allow players without a prohibited artisan rank")
knownSpells[12180] = true
context.professions = { [197] = 300 }
eligible, reason = Quests:CreateAvailableQuestEvaluator(context):IsEligible(9233, omarion)
expect(not eligible and reason == "profession-rank", "negative rank excludes a matching artisan")
knownSpells[12180] = nil

local reputationQuest = { starts = { [1] = {{1, 1}} }, rmin = {529, 21000} }
context = Quests:BuildAvailableQuestEvaluatorContext({}, {}, {}, {
    completedAuthoritative = true,
    professions = {}, reputations = { [529] = 9000 }, professionsReliable = true, reputationsReliable = true,
})
eligible, reason = Quests:CreateAvailableQuestEvaluator(context):IsEligible(2000, reputationQuest)
expect(not eligible and reason == "reputation", "known reputation threshold is enforced")
context.reputations = {}
context.reputationsReliable = false
eligible, reason, uncertainties = Quests:CreateAvailableQuestEvaluator(context):IsEligible(2000, reputationQuest)
expect(eligible and reason == nil and uncertainties[1] == "reputation-unknown",
    "unknown reputation remains visible and annotated")

playerRace = "Orc"
context = Quests:BuildAvailableQuestEvaluatorContext({}, {}, {}, {
    completedAuthoritative = true,
    professions = {}, reputations = {}, professionsReliable = false, reputationsReliable = false,
})
eligible, reason = Quests:CreateAvailableQuestEvaluator(context):IsEligible(287, frostmane)
expect(not eligible and reason == "race", "definite failure overrides unknown state")
playerRace = "Dwarf"

local inactive, eventReason = Quests:GetAvailableQuestEventState({ z = -368 }, {
    calendarDay = 1, calendarMonth = 1, calendarYear = 2026,
})
expect(inactive == false and eventReason == "event-inactive", "historical event stays inactive")
local activeEvent = Quests:GetAvailableQuestEventState({ z = -21 }, {
    calendarDay = 20, calendarMonth = 10, calendarYear = 2026,
})
expect(activeEvent == true, "event date range is active")
local wrappedEvent = Quests:GetAvailableQuestEventState({ z = -404 }, {
    calendarDay = 31, calendarMonth = 12, calendarYear = 2026,
})
expect(wrappedEvent == true, "event date range supports year boundaries")

local pinContext = { uncertaintyReasons = {"profession-unknown"} }
local pinData = Quests:BuildAvailableQuestPinData(1001, professionQuest, {1, 1}, 1, 1, 1, pinContext)
expect(pinData.availabilityUncertaintyReasons, "pin data carries uncertainty")
expectEqual(pinData.metadataLines[#pinData.metadataLines], "quests.static.availabilityUncertain",
    "uncertain pin explains its state")
expect(Quests:GetAvailableQuestMarkerOpacity(professionQuest, pinContext) < 1,
    "uncertain marker is visually subdued")
expect(Quests:GetAvailableQuestMarkerColor(professionQuest, pinContext) ~= nil,
    "uncertain marker has a distinct color")

GetQuestsCompleted = nil
IsQuestFlaggedCompleted = nil
C_QuestLog = nil
active, completed, authoritative = Quests:BuildAvailableQuestState({})
context = Quests:BuildAvailableQuestEvaluatorContext({}, active, completed, {
    completedAuthoritative = authoritative,
    professions = {}, reputations = {}, professionsReliable = true, reputationsReliable = true,
})
eligible, reason, uncertainties = Quests:CreateAvailableQuestEvaluator(context):IsEligible(3000, {
    starts = { [1] = {{1, 1}} }, ps = {2999},
})
expect(eligible and reason == nil and uncertainties[1] == "completion-unknown",
    "missing completion APIs fail open with an explicit uncertainty")

print("quest availability assertions passed")
