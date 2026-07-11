local VanillaEnhanced = _G.VanillaEnhanced
local SurvivalStatistics = VanillaEnhanced:CreateModule("survivalStatistics", VanillaEnhanced:T("module.survivalStatistics"))

local NEAR_DEATH_THRESHOLD = 10
local NEAR_DEATH_REARM_THRESHOLD = 20
local defaults = {
    enemyKills = 0,
    eliteKills = 0,
    deaths = 0,
    nearDeathExperiences = 0,
    lowestHealthPercent = nil,
    totalPlayedSeconds = 0,
    playedTimeInitialized = false,
    goldAccumulatedCopper = 0,
    goldSpentCopper = 0,
}

local function NormalizeCounter(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    return math.floor(value)
end

local function GetCurrentMoney()
    if type(GetMoney) ~= "function" then return 0 end
    return NormalizeCounter(GetMoney())
end

local function SetGoldBaseline(statistics)
    local currentMoney = GetCurrentMoney()
    statistics.goldAccumulatedCopper = currentMoney
    statistics.goldSpentCopper = 0
    return currentMoney
end

function SurvivalStatistics:GetStatistics()
    if self.statistics then return self.statistics end
    local characterSettings = VanillaEnhanced:GetCharacterSettings()
    local existing = characterSettings.modules and characterSettings.modules.survivalStatistics
    local hasRecordedAccumulatedGold = type(existing) == "table" and existing.goldAccumulatedCopper ~= nil
    local statistics = VanillaEnhanced:GetCharacterModuleSettings("survivalStatistics", defaults)
    statistics.enemyKills = NormalizeCounter(statistics.enemyKills)
    statistics.eliteKills = NormalizeCounter(statistics.eliteKills)
    statistics.deaths = NormalizeCounter(statistics.deaths)
    statistics.nearDeathExperiences = NormalizeCounter(statistics.nearDeathExperiences)
    statistics.goldAccumulatedCopper = NormalizeCounter(statistics.goldAccumulatedCopper)
    statistics.goldSpentCopper = NormalizeCounter(statistics.goldSpentCopper)
    if not hasRecordedAccumulatedGold then
        SetGoldBaseline(statistics)
    end
    statistics.totalPlayedSeconds = NormalizeCounter(statistics.totalPlayedSeconds)
    if statistics.lowestHealthPercent ~= nil then
        statistics.lowestHealthPercent = tonumber(statistics.lowestHealthPercent)
    end
    self.statistics = statistics
    return self.statistics
end

function SurvivalStatistics:ResetSettings()
    self:CheckpointPlayedTime()
    self.statistics = nil
    self.previousHealthPercent = nil
    self.nearDeathArmed = nil
    self.playedTimeRequestPending = nil
    self.playedTimeStartedAt = nil
    self.previousMoney = nil
    self:StartPlayedTime()
    self:InitializeMoney()
end

function SurvivalStatistics:NotifyOptionsChanged()
    if VanillaEnhanced.RefreshSurvivalStatisticsOptions then
        VanillaEnhanced:RefreshSurvivalStatisticsOptions()
    end
end

function SurvivalStatistics:ResetStatistics()
    local statistics = self:GetStatistics()
    statistics.enemyKills = 0
    statistics.eliteKills = 0
    statistics.deaths = 0
    statistics.nearDeathExperiences = 0
    statistics.lowestHealthPercent = nil
    self.previousMoney = SetGoldBaseline(statistics)
    self:NotifyOptionsChanged()
end

function SurvivalStatistics:StartPlayedTime()
    if type(GetTime) == "function" then self.playedTimeStartedAt = GetTime() end
end

function SurvivalStatistics:CheckpointPlayedTime()
    if not self.playedTimeStartedAt or type(GetTime) ~= "function" then return end
    local now = GetTime()
    local elapsed = math.floor(math.max(0, now - self.playedTimeStartedAt))
    if elapsed > 0 then
        local statistics = self:GetStatistics()
        statistics.totalPlayedSeconds = statistics.totalPlayedSeconds + elapsed
        self.playedTimeStartedAt = self.playedTimeStartedAt + elapsed
    end
end

function SurvivalStatistics:GetPlayedTimeSeconds()
    local total = self:GetStatistics().totalPlayedSeconds
    if self.playedTimeStartedAt and type(GetTime) == "function" then
        total = total + math.floor(math.max(0, GetTime() - self.playedTimeStartedAt))
    end
    return total
end

function SurvivalStatistics:EnsurePlayedTimeInitialized()
    local statistics = self:GetStatistics()
    if statistics.playedTimeInitialized == true or self.playedTimeRequestPending then return false end
    if type(RequestTimePlayed) ~= "function" then return false end

    self.playedTimeRequestPending = true
    RequestTimePlayed()
    return true
end

function SurvivalStatistics:ProcessPlayedTime(totalTime)
    local statistics = self:GetStatistics()
    if statistics.playedTimeInitialized == true then return end

    statistics.totalPlayedSeconds = NormalizeCounter(totalTime)
    statistics.playedTimeInitialized = true
    self.playedTimeRequestPending = false
    self:StartPlayedTime()
    self:NotifyOptionsChanged()
end

function SurvivalStatistics:InitializeMoney()
    if type(GetMoney) == "function" then self.previousMoney = GetCurrentMoney() end
end

function SurvivalStatistics:ProcessMoney()
    if type(GetMoney) ~= "function" then return end
    local currentMoney = GetCurrentMoney()
    local previousMoney = self.previousMoney
    self.previousMoney = currentMoney
    if previousMoney == nil or currentMoney == previousMoney then return end

    local statistics = self:GetStatistics()
    if currentMoney > previousMoney then
        statistics.goldAccumulatedCopper = statistics.goldAccumulatedCopper + currentMoney - previousMoney
    else
        statistics.goldSpentCopper = statistics.goldSpentCopper + previousMoney - currentMoney
    end
    self:NotifyOptionsChanged()
end

local function IsEliteClassification(classification)
    return classification == "elite" or classification == "rareelite" or classification == "worldboss"
end

function SurvivalStatistics:ObserveUnit(unit, cacheKey)
    if type(UnitGUID) ~= "function" or type(UnitClassification) ~= "function" then return end
    local guid = UnitGUID(unit)
    if not guid then return end
    self[cacheKey .. "GUID"] = guid
    self[cacheKey .. "Elite"] = IsEliteClassification(UnitClassification(unit))
end

function SurvivalStatistics:IsObservedElite(guid)
    return guid ~= nil and (
        (guid == self.targetGUID and self.targetElite == true)
        or (guid == self.mouseoverGUID and self.mouseoverElite == true)
    )
end

function SurvivalStatistics:InitializeHealthState()
    local maximum = UnitHealthMax("player") or 0
    local current = UnitHealth("player") or 0
    if maximum <= 0 then
        self.previousHealthPercent = nil
        return
    end
    local percent = (current / maximum) * 100
    self.previousHealthPercent = percent
    self.nearDeathArmed = percent >= NEAR_DEATH_REARM_THRESHOLD
end

function SurvivalStatistics:ProcessHealth(allowNearDeath)
    local maximum = UnitHealthMax("player") or 0
    local current = UnitHealth("player") or 0
    if maximum <= 0 then return end

    local percent = (current / maximum) * 100
    local previousPercent = self.previousHealthPercent
    self.previousHealthPercent = percent
    if percent >= NEAR_DEATH_REARM_THRESHOLD then self.nearDeathArmed = true end
    if current <= 0 then return end

    local statistics = self:GetStatistics()
    local changed = false
    if statistics.lowestHealthPercent == nil or percent < statistics.lowestHealthPercent then
        statistics.lowestHealthPercent = percent
        changed = true
    end
    if allowNearDeath and self.nearDeathArmed and previousPercent ~= nil
        and previousPercent >= NEAR_DEATH_THRESHOLD and percent < NEAR_DEATH_THRESHOLD then
        statistics.nearDeathExperiences = statistics.nearDeathExperiences + 1
        self.nearDeathArmed = false
        changed = true
    end
    if changed then self:NotifyOptionsChanged() end
end

function SurvivalStatistics:ProcessCombatLog()
    if type(CombatLogGetCurrentEventInfo) ~= "function" then return end
    local _, subevent, _, sourceGUID, _, _, _, destinationGUID, _, destinationFlags = CombatLogGetCurrentEventInfo()
    if subevent ~= "PARTY_KILL" or sourceGUID ~= self.playerGUID then return end
    if type(bit) ~= "table" or type(bit.band) ~= "function" then return end

    local npcFlag = COMBATLOG_OBJECT_TYPE_NPC or 0x00000800
    if bit.band(destinationFlags or 0, npcFlag) == 0 then return end

    local statistics = self:GetStatistics()
    statistics.enemyKills = statistics.enemyKills + 1
    if self:IsObservedElite(destinationGUID) then statistics.eliteKills = statistics.eliteKills + 1 end
    self:NotifyOptionsChanged()
end

local eventFrame = CreateFrame("Frame")
SurvivalStatistics.eventFrame = eventFrame
eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        SurvivalStatistics:ProcessCombatLog()
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if unit == "player" then SurvivalStatistics:ProcessHealth(event == "UNIT_HEALTH") end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        SurvivalStatistics.playerGUID = UnitGUID("player")
        SurvivalStatistics.isDead = UnitIsDeadOrGhost("player") == true
        SurvivalStatistics:GetStatistics()
        SurvivalStatistics:InitializeHealthState()
        if SurvivalStatistics.previousMoney == nil then SurvivalStatistics:InitializeMoney() end
        SurvivalStatistics:ObserveUnit("target", "target")
        SurvivalStatistics:ObserveUnit("mouseover", "mouseover")
        if not SurvivalStatistics.playedTimeStartedAt then SurvivalStatistics:StartPlayedTime() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        SurvivalStatistics:ObserveUnit("target", "target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        SurvivalStatistics:ObserveUnit("mouseover", "mouseover")
    elseif event == "PLAYER_MONEY" then
        SurvivalStatistics:ProcessMoney()
    elseif event == "PLAYER_DEAD" then
        if not SurvivalStatistics.isDead then
            SurvivalStatistics.isDead = true
            local statistics = SurvivalStatistics:GetStatistics()
            statistics.deaths = statistics.deaths + 1
            SurvivalStatistics:NotifyOptionsChanged()
        end
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        SurvivalStatistics.isDead = false
        SurvivalStatistics:InitializeHealthState()
    elseif event == "PLAYER_LOGOUT" then
        SurvivalStatistics:CheckpointPlayedTime()
    elseif event == "TIME_PLAYED_MSG" then
        SurvivalStatistics:ProcessPlayedTime(unit)
    end
end)

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_UNGHOST")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("TIME_PLAYED_MSG")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("PLAYER_MONEY")
