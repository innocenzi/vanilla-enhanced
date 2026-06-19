local addonName = ...

local VanillaEnhanced = _G.VanillaEnhanced or {}
_G.VanillaEnhanced = VanillaEnhanced

VanillaEnhanced.addonName = addonName or VanillaEnhanced.addonName or "VanillaEnhanced"
VanillaEnhanced.displayName = "Vanilla Enhanced"
VanillaEnhanced.mediaPath = "Interface\\AddOns\\" .. VanillaEnhanced.addonName .. "\\media\\"
VanillaEnhanced.modules = VanillaEnhanced.modules or {}
VanillaEnhanced.commandHandlers = VanillaEnhanced.commandHandlers or {}

function VanillaEnhanced:CreateModule(key, displayName)
    local module = self.modules[key] or {}
    module.key = key
    module.displayName = displayName or module.displayName or key
    module.addon = self
    self.modules[key] = module
    return module
end

function VanillaEnhanced:GetModule(key)
    return self.modules[key] or self:CreateModule(key)
end

function VanillaEnhanced:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. self.displayName .. "|r: " .. tostring(message))
end

function VanillaEnhanced:RegisterCommand(key, handler, helpText)
    self.commandHandlers[key] = {
        handler = handler,
        helpText = helpText,
    }
end

local function Trim(value)
    if strtrim then
        return strtrim(value or "")
    end
    return string.match(value or "", "^%s*(.-)%s*$")
end

local function SplitCommand(input)
    input = string.lower(Trim(input))
    local key, rest = string.match(input, "^(%S+)%s*(.*)$")
    return key, Trim(rest)
end

local function PrintCommandHelp()
    VanillaEnhanced:Print("commands:")
    for key, command in pairs(VanillaEnhanced.commandHandlers) do
        VanillaEnhanced:Print(command.helpText or ("/ve " .. key))
    end
end

local function SlashCommand(input)
    local key, rest = SplitCommand(input)
    local command = key and VanillaEnhanced.commandHandlers[key]

    if command then
        command.handler(rest)
        return
    end

    local questMapCommand = VanillaEnhanced.commandHandlers["quest-map"]
    if questMapCommand and (key == "on" or key == "off" or key == "refresh" or key == "status") then
        questMapCommand.handler(key .. (rest ~= "" and (" " .. rest) or ""))
        return
    end

    PrintCommandHelp()
end

SlashCmdList.VANILLAENHANCED = SlashCommand
SLASH_VANILLAENHANCED1 = "/vanillaenhanced"
SLASH_VANILLAENHANCED2 = "/ve"