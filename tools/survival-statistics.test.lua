local function AssertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local health = 100
local maximumHealth = 100
local money = 12345
local now = 100
local dead = false
local requestTimePlayedCalls = 0
local completedQuests = { [1] = true, [2] = true, [3] = false }
local unitGuids = { player = "Player-1" }
local unitClassifications = {}
local combatEvent
local eventHandler
local Unpack = unpack or table.unpack

local function CopyDefaults(target, source)
    target = type(target) == "table" and target or {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            target[key] = CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

_G.VanillaEnhanced = {
    modules = {},
    characterSettings = { modules = {} },
}

function _G.VanillaEnhanced:T(key) return key end
function _G.VanillaEnhanced:CreateModule(key)
    local module = { key = key }
    self.modules[key] = module
    return module
end
function _G.VanillaEnhanced:GetCharacterSettings() return self.characterSettings end
function _G.VanillaEnhanced:GetCharacterModuleSettings(key, defaults)
    local modules = self.characterSettings.modules
    modules[key] = CopyDefaults(modules[key], defaults)
    return modules[key]
end

function CreateFrame()
    local frame = {}
    function frame:SetScript(_, handler)
        eventHandler = handler
    end
    function frame:RegisterEvent() end
    return frame
end

function UnitHealth() return health end
function UnitHealthMax() return maximumHealth end
function UnitGUID(unit) return unitGuids[unit] end
function UnitClassification(unit) return unitClassifications[unit] or "normal" end
function UnitIsDeadOrGhost() return dead end
function GetMoney() return money end
function GetTime() return now end
function RequestTimePlayed() requestTimePlayedCalls = requestTimePlayedCalls + 1 end
function GetQuestsCompleted() return completedQuests end
function CombatLogGetCurrentEventInfo() return Unpack(combatEvent) end

bit = {}
function bit.band(left, right)
    local result = 0
    local place = 1
    while left > 0 and right > 0 do
        local leftBit = left % 2
        local rightBit = right % 2
        if leftBit == 1 and rightBit == 1 then result = result + place end
        left = math.floor(left / 2)
        right = math.floor(right / 2)
        place = place * 2
    end
    return result
end

dofile("src/survival-statistics/module.lua")

local statisticsModule = _G.VanillaEnhanced.modules.survivalStatistics
local function Fire(event, argument)
    eventHandler(statisticsModule.eventFrame, event, argument)
end

Fire("PLAYER_LOGIN")
local statistics = statisticsModule:GetStatistics()
AssertEqual(statistics.goldAccumulatedCopper, 12345, "initial gold baseline")
AssertEqual(statistics.goldSpentCopper, 0, "initial spent gold")
AssertEqual(statistics.questsCompleted, 2, "completed quests initialized from API")

completedQuests[4] = true
Fire("QUEST_TURNED_IN")
AssertEqual(statistics.questsCompleted, 3, "completed quests refreshed after turn-in")

health = 12
Fire("UNIT_HEALTH", "player")
health = 9
Fire("UNIT_HEALTH", "player")
AssertEqual(statistics.nearDeathExperiences, 1, "first near-death crossing")
health = 8
Fire("UNIT_HEALTH", "player")
health = 15
Fire("UNIT_HEALTH", "player")
health = 9
Fire("UNIT_HEALTH", "player")
AssertEqual(statistics.nearDeathExperiences, 1, "near-death remains disarmed below recovery threshold")
health = 20
Fire("UNIT_HEALTH", "player")
health = 9
Fire("UNIT_HEALTH", "player")
AssertEqual(statistics.nearDeathExperiences, 2, "near-death re-arms at twenty percent")
AssertEqual(statistics.lowestHealthPercent, 8, "lowest non-zero health")

Fire("PLAYER_DEAD")
Fire("PLAYER_DEAD")
AssertEqual(statistics.deaths, 1, "duplicate death events")
Fire("PLAYER_ALIVE")
Fire("PLAYER_DEAD")
AssertEqual(statistics.deaths, 2, "death after resurrection")

unitGuids.target = "Creature-Normal"
unitClassifications.target = "normal"
Fire("PLAYER_TARGET_CHANGED")
combatEvent = { 0, "PARTY_KILL", false, "Player-1", nil, 0, 0, "Creature-Normal", nil, 0x00000800 }
Fire("COMBAT_LOG_EVENT_UNFILTERED")
AssertEqual(statistics.enemyKills, 1, "normal enemy kill")
AssertEqual(statistics.eliteKills, 0, "normal enemy is not elite")

unitGuids.mouseover = "Creature-Elite"
unitClassifications.mouseover = "rareelite"
Fire("UPDATE_MOUSEOVER_UNIT")
combatEvent = { 0, "PARTY_KILL", false, "Player-1", nil, 0, 0, "Creature-Elite", nil, 0x00000800 }
Fire("COMBAT_LOG_EVENT_UNFILTERED")
AssertEqual(statistics.enemyKills, 2, "elite included in enemy kills")
AssertEqual(statistics.eliteKills, 1, "observed elite kill")

combatEvent = { 0, "PARTY_KILL", false, "Player-1", nil, 0, 0, "Creature-Unobserved", nil, 0x00000800 }
Fire("COMBAT_LOG_EVENT_UNFILTERED")
AssertEqual(statistics.enemyKills, 3, "unobserved enemy kill")
AssertEqual(statistics.eliteKills, 1, "unobserved enemy does not reuse stale classification")

money = 13345
Fire("PLAYER_MONEY")
AssertEqual(statistics.goldAccumulatedCopper, 13345, "accumulated gold increase")
money = 12000
Fire("PLAYER_MONEY")
AssertEqual(statistics.goldSpentCopper, 1345, "spent gold decrease")
statisticsModule:ResetStatistics()
AssertEqual(statistics.goldAccumulatedCopper, 12000, "reset gold baseline")
AssertEqual(statistics.goldSpentCopper, 0, "reset spent gold")
AssertEqual(statistics.questsCompleted, 3, "reset preserves completed quests")
money = 11000
Fire("PLAYER_MONEY")
AssertEqual(statistics.goldSpentCopper, 1000, "post-reset money baseline")

AssertEqual(statisticsModule:EnsurePlayedTimeInitialized(), true, "first played-time request")
AssertEqual(statisticsModule:EnsurePlayedTimeInitialized(), false, "played-time request remains pending")
AssertEqual(requestTimePlayedCalls, 1, "one played-time request")
Fire("TIME_PLAYED_MSG", 5000)
AssertEqual(statistics.playedTimeInitialized, true, "played time initialized")
now = 106
AssertEqual(statisticsModule:GetPlayedTimeSeconds(), 5006, "current session playtime")
statisticsModule:CheckpointPlayedTime()
AssertEqual(statistics.totalPlayedSeconds, 5006, "checkpointed playtime")
AssertEqual(statisticsModule:EnsurePlayedTimeInitialized(), false, "initialized playtime is not requested again")
AssertEqual(requestTimePlayedCalls, 1, "played-time request stays one-shot")

print("survival statistics runtime tests passed")
