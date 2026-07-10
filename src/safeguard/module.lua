local VanillaEnhanced = _G.VanillaEnhanced
local Safeguard = VanillaEnhanced:CreateModule("safeguard", VanillaEnhanced:T("module.safeguard"))

local HEARTBEAT_SOUND = VanillaEnhanced.mediaPath .. "heartbeat.ogg"
local SLOW_INTERVAL = 1.65
local FAST_INTERVAL = 0.4
local MAX_SPEED_HEALTH_PERCENT = 20
local DEFAULT_HEARTBEAT_THRESHOLD = 50
local DEFAULT_SOUND_CHANNEL = "SFX"
local ACCOUNT_SETTING_KEYS = { "heartbeatEnabled", "heartbeatThreshold", "heartbeatSoundChannel" }

local function ClampThreshold(value)
    return math.max(1, math.min(100, tonumber(value) or DEFAULT_HEARTBEAT_THRESHOLD))
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

    return VanillaEnhanced:GetModuleSettings("safeguard", {
        heartbeatEnabled = true,
        heartbeatThreshold = DEFAULT_HEARTBEAT_THRESHOLD,
        heartbeatSoundChannel = DEFAULT_SOUND_CHANNEL,
    })
end

function Safeguard:GetCharacterSettings()
    local settings = VanillaEnhanced:GetCharacterModuleSettings("safeguard", {})
    if settings.enabled == nil then settings.enabled = IsHardcoreCharacter() end
    return settings
end

function Safeguard:IsEnabled()
    return self:GetCharacterSettings().enabled == true
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

function Safeguard:IsHeartbeatActive()
    local settings = self:GetSettings()
    if not self:IsEnabled() or not settings.heartbeatEnabled or UnitIsDeadOrGhost("player") then
        return false
    end
    local maximum = UnitHealthMax("player") or 0
    if maximum <= 0 then
        return false
    end
    local current = UnitHealth("player") or 0
    if current <= 0 then
        return false
    end
    local healthPercent = (current / maximum) * 100
    local threshold = ClampThreshold(settings.heartbeatThreshold)
    if healthPercent >= threshold then
        return false
    end
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
        if not active then return end
        Safeguard:PlayHeartbeat()
        Safeguard:ScheduleHeartbeat(Safeguard:GetHeartbeatInterval(healthPercent))
    end)
end

function Safeguard:Update()
    if self.previewActive then self:CancelHeartbeat() end
    local active, healthPercent = self:IsHeartbeatActive()
    if not active then self:CancelHeartbeat(); return end
    if self.heartbeatTimer then return end
    self:PlayHeartbeat()
    self:ScheduleHeartbeat(self:GetHeartbeatInterval(healthPercent))
end

function Safeguard:SetEnabled(enabled)
    self:GetCharacterSettings().enabled = not not enabled
    if enabled then self:Update() else self:CancelHeartbeat() end
    if VanillaEnhanced.RefreshOptions then VanillaEnhanced:RefreshOptions() end
end

function Safeguard:OnOptionChanged()
    self:CancelHeartbeat()
end

local eventFrame = CreateFrame("Frame")
Safeguard.eventFrame = eventFrame
eventFrame:SetScript("OnEvent", function(_, event, unit)
    if (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and unit ~= "player" then
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        Safeguard:CancelHeartbeat()
    end
    Safeguard:Update()
end)
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
