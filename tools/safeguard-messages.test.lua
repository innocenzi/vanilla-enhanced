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

local frameMethods = {}
function frameMethods:SetScript(_, callback) self.callback = callback end
function frameMethods:RegisterEvent() end
function CreateFrame() return setmetatable({}, { __index = frameMethods }) end

local currentHealth = 100
local maximumHealth = 100
local now = 0
local dead = false
local inHomeParty = true
local inInstanceParty = false
local inRaid = false
local sent = {}

LE_PARTY_CATEGORY_HOME = 1
LE_PARTY_CATEGORY_INSTANCE = 2
function IsInGroup(category)
    if category == LE_PARTY_CATEGORY_HOME then return inHomeParty end
    if category == LE_PARTY_CATEGORY_INSTANCE then return inInstanceParty end
    return inHomeParty or inInstanceParty
end
function IsInRaid() return inRaid end
function SendChatMessage(message, channel) sent[#sent + 1] = { message, channel } end
C_ChatInfo = {
    SendChatMessage = function(message, channel) sent[#sent + 1] = { message, channel } end,
}
function UnitHealth() return currentHealth end
function UnitHealthMax() return maximumHealth end
function UnitIsDeadOrGhost() return dead end
function GetTime() return now end

VanillaEnhancedSettings = { modules = {} }
VanillaEnhancedCharacterSettings = { modules = { safeguard = { enabled = true } } }
VanillaEnhanced = {
    addonName = "VanillaEnhanced",
    mediaPath = "Interface\\AddOns\\VanillaEnhanced\\media\\",
    modules = {},
    T = function(_, key) return key end,
    GetLocaleKey = function() return "frFR" end,
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

assert(loadfile("src/outgoing-messages.lua"))()

expectEqual(VanillaEnhanced:NormalizeOutgoingMessageLocale("auto"), "frFR", "auto locale")
expectEqual(VanillaEnhanced:NormalizeOutgoingMessageLocale("deDE"), "enUS", "unsupported locale")
expectEqual(
    VanillaEnhanced:RenderOutgoingMessageTemplate("Health {percent}%", { percent = true }, { percent = "24" }),
    "Health 24%",
    "template rendering"
)
expect(not VanillaEnhanced:RenderOutgoingMessageTemplate("{unknown}", { percent = true }, {}), "unknown placeholder")
expect(not VanillaEnhanced:RenderOutgoingMessageTemplate("   ", {}, {}), "blank template")

expect(VanillaEnhanced:SendPartyMessage("party"), "home party delivery")
expectEqual(sent[#sent][2], "PARTY", "party channel")
inRaid = true
expect(not VanillaEnhanced:SendPartyMessage("raid"), "raid rejected")
inRaid = false
inHomeParty = false
inInstanceParty = true
expect(not VanillaEnhanced:SendPartyMessage("instance"), "instance party rejected")
expect(VanillaEnhanced:SendOutgoingMessage("nearby", "nearby"), "nearby emote delivery")
expectEqual(sent[#sent][2], "EMOTE", "nearby emote channel")
expect(not VanillaEnhanced:SendOutgoingMessage("raid", "raid"), "raid destination requires raid")
inRaid = true
expect(VanillaEnhanced:SendOutgoingMessage("raid", "raid"), "raid delivery")
expectEqual(sent[#sent][2], "RAID", "raid channel")
inRaid = false
inHomeParty = true
inInstanceParty = false
sent = {}

assert(loadfile("src/safeguard/module.lua"))()
local safeguard = VanillaEnhanced:GetModule("safeguard")
local settings = safeguard:GetSettings()
expectEqual(settings.messageDestination, "party", "party is the default destination")
expect(settings.lowHealthNearbyEmoteEnabled == false, "nearby emote is disabled by default")
settings.messageDestination = "party"
settings.lowHealthPartyMessageEnabled = true
settings.lowHealthPartyMessageThreshold = 25

safeguard:ResetLowHealthMessageState()
currentHealth = 20
expect(not safeguard:ProcessLowHealthPartyMessage(), "initial low state suppressed")
expectEqual(#sent, 0, "no initial message")

currentHealth = 30
safeguard:ProcessLowHealthPartyMessage()
currentHealth = 24
expect(safeguard:ProcessLowHealthPartyMessage(), "threshold crossing sends")
expectEqual(sent[#sent][1], "Help! I have less than 24% health!", "english default")

now = 5
currentHealth = 20
expect(not safeguard:ProcessLowHealthPartyMessage(), "damage throttled")
now = 10
currentHealth = 19
expect(safeguard:ProcessLowHealthPartyMessage(), "damage after cooldown sends")

now = 11
currentHealth = 30
safeguard:ProcessLowHealthPartyMessage()
currentHealth = 23
expect(safeguard:ProcessLowHealthPartyMessage(), "new crossing bypasses cooldown")

settings.partyMessageLanguage = "frFR"
now = 12
currentHealth = 30
safeguard:ProcessLowHealthPartyMessage()
currentHealth = 24
expect(safeguard:ProcessLowHealthPartyMessage(), "french crossing sends")
expectEqual(sent[#sent][1], "À l'aide ! J'ai moins de 24% de vie !", "french default")

settings.lowHealthNearbyEmoteEnabled = true
inHomeParty = false
now = 13
currentHealth = 30
safeguard:ProcessLowHealthPartyMessage()
currentHealth = 24
expect(safeguard:ProcessLowHealthPartyMessage(), "nearby emote overrides party destination")
expectEqual(sent[#sent][2], "EMOTE", "low-health nearby emote channel")
settings.lowHealthNearbyEmoteEnabled = false
inHomeParty = true

dead = true
now = 30
currentHealth = 10
expect(not safeguard:ProcessLowHealthPartyMessage(), "dead player suppressed")
dead = false
settings.lowHealthPartyMessageEnabled = false
currentHealth = 5
expect(not safeguard:ProcessLowHealthPartyMessage(), "disabled warning suppressed")

print("safeguard message assertions passed")
