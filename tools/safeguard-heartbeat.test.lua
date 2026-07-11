local function expect(value, message)
    if not value then error(message or "expectation failed", 2) end
end

local function expectEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function copyDefaults(target, defaults)
    target = type(target) == "table" and target or {}
    for key, value in pairs(defaults or {}) do
        if target[key] == nil then target[key] = value end
    end
    return target
end

local eventFrame
local frameMethods = {}
function frameMethods:SetScript(_, callback) self.callback = callback end
function frameMethods:RegisterEvent() end
function CreateFrame()
    eventFrame = setmetatable({}, { __index = frameMethods })
    return eventFrame
end

local currentHealth = 100
local maximumHealth = 100
local now = 0
local dead = false
local inCombat = false
local sounds = 0
local timers = {}

function UnitHealth() return currentHealth end
function UnitHealthMax() return maximumHealth end
function UnitIsDeadOrGhost() return dead end
function UnitAffectingCombat() return inCombat end
function GetTime() return now end
function PlaySoundFile() sounds = sounds + 1; return true end

C_Timer = {}
function C_Timer.NewTimer(delay, callback)
    local timer = { due = now + delay, callback = callback, cancelled = false }
    function timer:Cancel() self.cancelled = true end
    timers[#timers + 1] = timer
    return timer
end

local function advance(seconds)
    local target = now + seconds
    while true do
        local nextTimer
        for _, timer in ipairs(timers) do
            if not timer.cancelled and timer.due <= target and (not nextTimer or timer.due < nextTimer.due) then
                nextTimer = timer
            end
        end
        if not nextTimer then break end
        nextTimer.cancelled = true
        now = nextTimer.due
        nextTimer.callback()
    end
    now = target
end

local function fire(event, unit)
    eventFrame.callback(eventFrame, event, unit)
end

VanillaEnhancedSettings = { modules = {} }
VanillaEnhancedCharacterSettings = { modules = { safeguard = { enabled = true } } }
VanillaEnhanced = {
    mediaPath = "Interface\\AddOns\\VanillaEnhanced\\media\\",
    modules = {},
    T = function(_, key) return key end,
}
_G.VanillaEnhanced = VanillaEnhanced

function VanillaEnhanced:CreateModule(key)
    self.modules[key] = self.modules[key] or {}
    return self.modules[key]
end
function VanillaEnhanced:GetModule(key) return self.modules[key] end
function VanillaEnhanced:GetSettings() return VanillaEnhancedSettings end
function VanillaEnhanced:GetModuleSettings(key, defaults)
    VanillaEnhancedSettings.modules[key] = copyDefaults(VanillaEnhancedSettings.modules[key], defaults)
    return VanillaEnhancedSettings.modules[key]
end
function VanillaEnhanced:GetCharacterModuleSettings(key, defaults)
    VanillaEnhancedCharacterSettings.modules[key] = copyDefaults(VanillaEnhancedCharacterSettings.modules[key], defaults)
    return VanillaEnhancedCharacterSettings.modules[key]
end
function VanillaEnhanced:RefreshOptions() end
function VanillaEnhanced:NormalizeOutgoingMessageLocale() return "enUS" end
function VanillaEnhanced:RenderOutgoingMessageTemplate(template) return template end
function VanillaEnhanced:SendOutgoingMessage() return false end

assert(loadfile("src/safeguard/module.lua"))()
local safeguard = VanillaEnhanced:GetModule("safeguard")
local settings = safeguard:GetSettings()
settings.heartbeatEnabled = true
settings.heartbeatThreshold = 50

fire("PLAYER_ENTERING_WORLD")
expectEqual(sounds, 0, "healthy login is silent")

currentHealth = 40
fire("UNIT_HEALTH", "player")
expectEqual(sounds, 1, "out-of-combat crossing warns once")
currentHealth = 35
fire("UNIT_HEALTH", "player")
expectEqual(sounds, 1, "further low damage is throttled")
advance(10)
currentHealth = 30
fire("UNIT_HEALTH", "player")
expectEqual(sounds, 2, "further damage warns after cooldown")

maximumHealth = 200
fire("UNIT_MAXHEALTH", "player")
expectEqual(sounds, 2, "maximum-health changes are silent")

currentHealth = 100
maximumHealth = 100
fire("UNIT_HEALTH", "player")
inCombat = true
fire("PLAYER_REGEN_DISABLED")
expectEqual(sounds, 2, "healthy combat entry is silent")
currentHealth = 40
fire("UNIT_HEALTH", "player")
expectEqual(sounds, 3, "combat crossing starts immediately")
advance(2)
expect(sounds > 3, "combat heartbeat repeats")

local beforeExit = sounds
inCombat = false
fire("PLAYER_REGEN_ENABLED")
expectEqual(sounds, beforeExit, "combat exit adds no immediate beat")
advance(2.9)
expect(sounds > beforeExit, "heartbeat continues during grace")
advance(0.2)
local beforeExpiry = sounds
advance(2)
expectEqual(sounds, beforeExpiry, "heartbeat stops after grace")

inCombat = true
fire("PLAYER_REGEN_DISABLED")
expectEqual(sounds, beforeExpiry + 1, "combat entry while low starts immediately")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
advance(1)
inCombat = true
fire("PLAYER_REGEN_DISABLED")
local resumed = sounds
advance(2)
expect(sounds > resumed, "combat resume during grace keeps looping")

currentHealth = 50
fire("UNIT_HEALTH", "player")
local healed = sounds
advance(2)
expectEqual(sounds, healed, "healing to threshold stops heartbeat")

inCombat = false
currentHealth = 40
fire("PLAYER_ENTERING_WORLD")
expectEqual(sounds, healed, "reload while low is silent")
currentHealth = 35
fire("UNIT_HEALTH", "player")
expectEqual(sounds, healed, "reload baseline does not manufacture crossing")
advance(10)
currentHealth = 30
fire("UNIT_HEALTH", "player")
expectEqual(sounds, healed + 1, "later low-health damage can warn")

dead = true
fire("PLAYER_DEAD")
local afterDeath = sounds
advance(5)
expectEqual(sounds, afterDeath, "death cancels heartbeat")

print("safeguard heartbeat assertions passed")
