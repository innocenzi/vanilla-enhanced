local VanillaEnhanced = _G.VanillaEnhanced
local Safeguard = VanillaEnhanced:CreateModule("safeguard", VanillaEnhanced:T("module.safeguard"))

local HEARTBEAT_SOUND = VanillaEnhanced.mediaPath .. "heartbeat.ogg"
local SLOW_INTERVAL = 1.65
local FAST_INTERVAL = 0.4
local MAX_SPEED_HEALTH_PERCENT = 20
local DEFAULT_HEARTBEAT_THRESHOLD = 50
local DEFAULT_SOUND_CHANNEL = "SFX"
local HEARTBEAT_GRACE_SECONDS = 3
local OUT_OF_COMBAT_HEARTBEAT_COOLDOWN = 10
local DEFAULT_LOW_HEALTH_MESSAGE_THRESHOLD = 25
local LOW_HEALTH_MESSAGE_COOLDOWN = 10
local LOW_HEALTH_TEMPLATE_DEFAULTS = {
    enUS = "Help! I have less than {percent}% health!",
    frFR = "À l'aide ! J'ai moins de {percent}% de vie !",
}
local LOW_HEALTH_TEMPLATE_VALUES = { percent = true }
local ACCOUNT_SETTING_KEYS = {
    "heartbeatEnabled",
    "heartbeatThreshold",
    "heartbeatSoundChannel",
    "lowHealthPartyMessageEnabled",
    "lowHealthNearbyEmoteEnabled",
    "lowHealthPartyMessageThreshold",
    "partyMessageLanguage",
    "messageDestination",
    "lowHealthPartyMessageFormatEnUS",
    "lowHealthPartyMessageFormatFrFR",
}

local function ClampThreshold(value)
    return math.max(1, math.min(100, tonumber(value) or DEFAULT_HEARTBEAT_THRESHOLD))
end

local function ClampLowHealthMessageThreshold(value)
    return math.max(1, math.min(100, tonumber(value) or DEFAULT_LOW_HEALTH_MESSAGE_THRESHOLD))
end

local function IsBlankString(value)
    return type(value) ~= "string" or not string.find(value, "%S")
end

local function IsHardcoreCharacter()
    if not (C_GameRules and type(C_GameRules.IsHardcoreActive) == "function") then return false end
    local ok, active = pcall(C_GameRules.IsHardcoreActive)
    return ok and active == true
end

function Safeguard:GetSettings()
    local characterSafeguard = VanillaEnhanced:GetCharacterModuleSettings("safeguard", {})

    local addonSettings = VanillaEnhanced:GetSettings()
    addonSettings.modules.safeguard = addonSettings.modules.safeguard or {}
    local accountSafeguard = addonSettings.modules.safeguard
    for _, key in ipairs(ACCOUNT_SETTING_KEYS) do
        if accountSafeguard[key] == nil and characterSafeguard[key] ~= nil then
            accountSafeguard[key] = characterSafeguard[key]
        end
        characterSafeguard[key] = nil
    end

    local settings = VanillaEnhanced:GetModuleSettings("safeguard", {
        heartbeatEnabled = true,
        heartbeatThreshold = DEFAULT_HEARTBEAT_THRESHOLD,
        heartbeatSoundChannel = DEFAULT_SOUND_CHANNEL,
        lowHealthPartyMessageEnabled = false,
        lowHealthNearbyEmoteEnabled = false,
        lowHealthPartyMessageThreshold = DEFAULT_LOW_HEALTH_MESSAGE_THRESHOLD,
        partyMessageLanguage = "enUS",
        messageDestination = "party",
        lowHealthPartyMessageFormatEnUS = LOW_HEALTH_TEMPLATE_DEFAULTS.enUS,
        lowHealthPartyMessageFormatFrFR = LOW_HEALTH_TEMPLATE_DEFAULTS.frFR,
    })
    settings.lowHealthPartyMessageThreshold = ClampLowHealthMessageThreshold(settings.lowHealthPartyMessageThreshold)
    if settings.partyMessageLanguage ~= "auto"
        and settings.partyMessageLanguage ~= "enUS"
        and settings.partyMessageLanguage ~= "frFR" then
        settings.partyMessageLanguage = "enUS"
    end
    if settings.messageDestination == "proximity" or settings.messageDestination == "nearby" then
        settings.lowHealthNearbyEmoteEnabled = true
        settings.messageDestination = "party"
    elseif settings.messageDestination ~= "raid" and settings.messageDestination ~= "party" then
        settings.messageDestination = "raid"
    end
    if IsBlankString(settings.lowHealthPartyMessageFormatEnUS) then
        settings.lowHealthPartyMessageFormatEnUS = LOW_HEALTH_TEMPLATE_DEFAULTS.enUS
    end
    if IsBlankString(settings.lowHealthPartyMessageFormatFrFR) then
        settings.lowHealthPartyMessageFormatFrFR = LOW_HEALTH_TEMPLATE_DEFAULTS.frFR
    end
    return settings
end

function Safeguard:GetCharacterSettings()
    local settings = VanillaEnhanced:GetCharacterModuleSettings("safeguard", {})
    if settings.enabled == nil then settings.enabled = IsHardcoreCharacter() end
    return settings
end

function Safeguard:IsEnabled()
    return self:GetCharacterSettings().enabled == true
end

function Safeguard:GetPartyMessageLocale()
    return VanillaEnhanced:NormalizeOutgoingMessageLocale(self:GetSettings().partyMessageLanguage)
end

function Safeguard:GetLowHealthPartyMessageFormatDefault(locale)
    locale = VanillaEnhanced:NormalizeOutgoingMessageLocale(locale)
    return LOW_HEALTH_TEMPLATE_DEFAULTS[locale] or LOW_HEALTH_TEMPLATE_DEFAULTS.enUS
end

function Safeguard:RenderLowHealthPartyMessage(template, percent)
    return VanillaEnhanced:RenderOutgoingMessageTemplate(template, LOW_HEALTH_TEMPLATE_VALUES, {
        percent = tostring(math.floor((tonumber(percent) or 0) + 0.5)),
    })
end

function Safeguard:GetLowHealthPartyMessage(settings, healthPercent)
    local locale = VanillaEnhanced:NormalizeOutgoingMessageLocale(settings.partyMessageLanguage)
    local template = locale == "frFR"
        and settings.lowHealthPartyMessageFormatFrFR
        or settings.lowHealthPartyMessageFormatEnUS
    if IsBlankString(template) then template = self:GetLowHealthPartyMessageFormatDefault(locale) end
    return self:RenderLowHealthPartyMessage(template, healthPercent)
end

function Safeguard:ResetLowHealthMessageState()
    self.previousHealth = nil
    self.previousHealthPercent = nil
    self.lastLowHealthMessageAt = nil
end

function Safeguard:ProcessLowHealthPartyMessage()
    local maximum = UnitHealthMax("player") or 0
    local current = UnitHealth("player") or 0
    local healthPercent = maximum > 0 and (current / maximum) * 100 or nil
    local previousHealth = self.previousHealth
    local previousHealthPercent = self.previousHealthPercent
    self.previousHealth = current
    self.previousHealthPercent = healthPercent

    if previousHealth == nil or previousHealthPercent == nil or not healthPercent then return false end

    local settings = self:GetSettings()
    if not self:IsEnabled() or not settings.lowHealthPartyMessageEnabled or UnitIsDeadOrGhost("player") then
        return false
    end

    local threshold = ClampLowHealthMessageThreshold(settings.lowHealthPartyMessageThreshold)
    local crossedThreshold = previousHealthPercent >= threshold and healthPercent < threshold
    local tookDamageBelowThreshold = current < previousHealth and healthPercent < threshold
    if not crossedThreshold and not tookDamageBelowThreshold then return false end

    local now = type(GetTime) == "function" and GetTime() or 0
    if not crossedThreshold and self.lastLowHealthMessageAt
        and now - self.lastLowHealthMessageAt < LOW_HEALTH_MESSAGE_COOLDOWN then
        return false
    end

    local message = self:GetLowHealthPartyMessage(settings, healthPercent)
    local destination = settings.lowHealthNearbyEmoteEnabled and "nearby" or settings.messageDestination
    if VanillaEnhanced:SendOutgoingMessage(message, destination) then
        self.lastLowHealthMessageAt = now
        return true
    end
    return false
end

function Safeguard:GetHeartbeatInterval(healthPercent)
    local threshold = ClampThreshold(self:GetSettings().heartbeatThreshold)
    if threshold <= MAX_SPEED_HEALTH_PERCENT then
        return FAST_INTERVAL
    end
    local curveRange = threshold - MAX_SPEED_HEALTH_PERCENT
    local progress = (healthPercent - MAX_SPEED_HEALTH_PERCENT) / curveRange
    progress = math.max(0, math.min(1, progress))
    return FAST_INTERVAL + ((SLOW_INTERVAL - FAST_INTERVAL) * progress)
end

function Safeguard:GetHeartbeatHealthState()
    local maximum = UnitHealthMax("player") or 0
    local current = UnitHealth("player") or 0
    if maximum <= 0 or current <= 0 then
        return current, maximum, nil, false
    end
    local healthPercent = (current / maximum) * 100
    return current, maximum, healthPercent, healthPercent < ClampThreshold(self:GetSettings().heartbeatThreshold)
end

function Safeguard:IsRuntimeHeartbeatEnabled()
    local settings = self:GetSettings()
    if not self:IsEnabled() or not settings.heartbeatEnabled or UnitIsDeadOrGhost("player") then
        return false
    end
    local current, maximum = self:GetHeartbeatHealthState()
    return maximum > 0 and current > 0
end

function Safeguard:IsPlayerInCombat()
    if type(UnitAffectingCombat) == "function" then
        return UnitAffectingCombat("player") == true
    end
    return self.inCombat == true
end

function Safeguard:IsHeartbeatActive()
    if not self:IsRuntimeHeartbeatEnabled() then return false end
    local _, _, healthPercent, belowThreshold = self:GetHeartbeatHealthState()
    if not belowThreshold then return false end
    return true, healthPercent
end

function Safeguard:PlayHeartbeat()
    if type(PlaySoundFile) ~= "function" then
        return false
    end
    local played = PlaySoundFile(
        HEARTBEAT_SOUND,
        self:GetSettings().heartbeatSoundChannel or DEFAULT_SOUND_CHANNEL
    )
    return played
end

function Safeguard:CancelHeartbeat()
    self.previewActive = false
    self.heartbeatMode = nil
    self.graceEndsAt = nil
    self.timerGeneration = (self.timerGeneration or 0) + 1
    if self.heartbeatTimer and self.heartbeatTimer.Cancel then
        self.heartbeatTimer:Cancel()
    end
    self.heartbeatTimer = nil
end

function Safeguard:StopRuntimeHeartbeat()
    self.heartbeatMode = nil
    self.graceEndsAt = nil
    self.timerGeneration = (self.timerGeneration or 0) + 1
    if self.heartbeatTimer and self.heartbeatTimer.Cancel then
        self.heartbeatTimer:Cancel()
    end
    self.heartbeatTimer = nil
end

function Safeguard:SchedulePreviewHeartbeat(healthPercent, interval)
    if not (C_Timer and C_Timer.NewTimer) then return end
    local generation = self.timerGeneration or 0
    self.heartbeatTimer = C_Timer.NewTimer(interval, function()
        if generation ~= (Safeguard.timerGeneration or 0) or not Safeguard.previewActive then return end
        Safeguard.heartbeatTimer = nil
        Safeguard:PlayHeartbeat()
        Safeguard:SchedulePreviewHeartbeat(healthPercent, Safeguard:GetHeartbeatInterval(healthPercent))
    end)
end

function Safeguard:PreviewHeartbeat(healthPercent)
    self:CancelHeartbeat()
    local threshold = ClampThreshold(self:GetSettings().heartbeatThreshold)
    if healthPercent <= 0 or healthPercent >= threshold then
        return
    end
    self.previewActive = true
    self:PlayHeartbeat()
    self:SchedulePreviewHeartbeat(healthPercent, self:GetHeartbeatInterval(healthPercent))
end

function Safeguard:ScheduleHeartbeat(interval)
    if not (C_Timer and C_Timer.NewTimer) then return end
    local generation = self.timerGeneration or 0
    self.heartbeatTimer = C_Timer.NewTimer(interval, function()
        if generation ~= (Safeguard.timerGeneration or 0) then return end
        Safeguard.heartbeatTimer = nil
        local active, healthPercent = Safeguard:IsHeartbeatActive()
        if not active then Safeguard:StopRuntimeHeartbeat(); return end
        if Safeguard.heartbeatMode == "grace" then
            local now = type(GetTime) == "function" and GetTime() or 0
            if not Safeguard.graceEndsAt or now >= Safeguard.graceEndsAt then
                Safeguard:StopRuntimeHeartbeat()
                return
            end
        elseif Safeguard.heartbeatMode ~= "combat" or not Safeguard:IsPlayerInCombat() then
            Safeguard:StopRuntimeHeartbeat()
            return
        end
        Safeguard:PlayHeartbeat()
        local nextInterval = Safeguard:GetHeartbeatInterval(healthPercent)
        if Safeguard.heartbeatMode == "grace" then
            local remaining = Safeguard.graceEndsAt - (type(GetTime) == "function" and GetTime() or 0)
            nextInterval = math.min(nextInterval, remaining)
        end
        Safeguard:ScheduleHeartbeat(nextInterval)
    end)
end

function Safeguard:StartCombatHeartbeat(playImmediately)
    local active, healthPercent = self:IsHeartbeatActive()
    if not active or not self:IsPlayerInCombat() then self:StopRuntimeHeartbeat(); return end
    self.heartbeatMode = "combat"
    self.graceEndsAt = nil
    if self.heartbeatTimer then return end
    if playImmediately then self:PlayHeartbeat() end
    self:ScheduleHeartbeat(self:GetHeartbeatInterval(healthPercent))
end

function Safeguard:EnterHeartbeatGrace()
    local active, healthPercent = self:IsHeartbeatActive()
    if not active or self.heartbeatMode ~= "combat" then self:StopRuntimeHeartbeat(); return end
    self.heartbeatMode = "grace"
    self.graceEndsAt = (type(GetTime) == "function" and GetTime() or 0) + HEARTBEAT_GRACE_SECONDS
    if not self.heartbeatTimer then
        self:ScheduleHeartbeat(math.min(self:GetHeartbeatInterval(healthPercent), HEARTBEAT_GRACE_SECONDS))
    end
end

function Safeguard:InitializeHeartbeatState()
    self:StopRuntimeHeartbeat()
    self.inCombat = self:IsPlayerInCombat()
    local current, _, healthPercent, belowThreshold = self:GetHeartbeatHealthState()
    self.previousHeartbeatHealth = current
    self.previousHeartbeatHealthPercent = healthPercent
    if not self.inCombat and belowThreshold then
        self.lastOutOfCombatHeartbeatAt = type(GetTime) == "function" and GetTime() or 0
    end
    if self.inCombat then self:StartCombatHeartbeat(true) end
end

function Safeguard:HandleHeartbeatHealthChanged(event)
    local current, _, healthPercent, belowThreshold = self:GetHeartbeatHealthState()
    local previousHealth = self.previousHeartbeatHealth
    local previousPercent = self.previousHeartbeatHealthPercent
    self.previousHeartbeatHealth = current
    self.previousHeartbeatHealthPercent = healthPercent

    if not self:IsRuntimeHeartbeatEnabled() or not belowThreshold then
        self:StopRuntimeHeartbeat()
        return
    end
    if self:IsPlayerInCombat() then
        self.inCombat = true
        self:StartCombatHeartbeat(self.heartbeatMode ~= "combat")
        return
    end
    self.inCombat = false
    if self.heartbeatMode == "grace" then return end
    self:StopRuntimeHeartbeat()
    if event ~= "UNIT_HEALTH" or previousHealth == nil or previousPercent == nil or current >= previousHealth then return end

    local now = type(GetTime) == "function" and GetTime() or 0
    local crossedThreshold = previousPercent >= ClampThreshold(self:GetSettings().heartbeatThreshold)
    local cooldownElapsed = self.lastOutOfCombatHeartbeatAt == nil
        or now - self.lastOutOfCombatHeartbeatAt >= OUT_OF_COMBAT_HEARTBEAT_COOLDOWN
    if crossedThreshold or cooldownElapsed then
        self:PlayHeartbeat()
        self.lastOutOfCombatHeartbeatAt = now
    end
end

function Safeguard:HandleCombatStarted()
    self.inCombat = true
    if self.previewActive then self:CancelHeartbeat() end
    self:StartCombatHeartbeat(true)
end

function Safeguard:HandleCombatEnded()
    self.inCombat = false
    if self.previewActive then return end
    self:EnterHeartbeatGrace()
end

function Safeguard:Update()
    self:ProcessLowHealthPartyMessage()
    if self.previewActive then self:CancelHeartbeat() end
    local current, _, healthPercent = self:GetHeartbeatHealthState()
    self.previousHeartbeatHealth = current
    self.previousHeartbeatHealthPercent = healthPercent
    if self:IsPlayerInCombat() then
        self.inCombat = true
        self:StartCombatHeartbeat(true)
    else
        self.inCombat = false
        self:StopRuntimeHeartbeat()
    end
end

function Safeguard:SetEnabled(enabled)
    self:GetCharacterSettings().enabled = not not enabled
    if enabled then self:Update() else self:CancelHeartbeat() end
    if VanillaEnhanced.RefreshOptions then VanillaEnhanced:RefreshOptions() end
end

function Safeguard:OnOptionChanged(settingKey)
    self:CancelHeartbeat()
    local current, _, healthPercent = self:GetHeartbeatHealthState()
    self.previousHeartbeatHealth = current
    self.previousHeartbeatHealthPercent = healthPercent
    if settingKey == "lowHealthPartyMessageEnabled" or settingKey == "lowHealthPartyMessageThreshold" then
        self:ResetLowHealthMessageState()
    end
end

local eventFrame = CreateFrame("Frame")
Safeguard.eventFrame = eventFrame
eventFrame:SetScript("OnEvent", function(_, event, unit)
    if (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and unit ~= "player" then
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        Safeguard:ResetLowHealthMessageState()
        Safeguard.lastOutOfCombatHeartbeatAt = nil
        Safeguard:InitializeHeartbeatState()
        return
    elseif event == "PLAYER_ALIVE" then
        Safeguard:InitializeHeartbeatState()
        return
    elseif event == "PLAYER_DEAD" then
        Safeguard:StopRuntimeHeartbeat()
        return
    elseif event == "PLAYER_REGEN_DISABLED" then
        Safeguard:HandleCombatStarted()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        Safeguard:HandleCombatEnded()
        return
    end
    Safeguard:ProcessLowHealthPartyMessage()
    Safeguard:HandleHeartbeatHealthChanged(event)
end)
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
