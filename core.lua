local addonName = ...

local VanillaEnhanced = _G.VanillaEnhanced or {}
_G.VanillaEnhanced = VanillaEnhanced

VanillaEnhanced.addonName = addonName or VanillaEnhanced.addonName or "VanillaEnhanced"
VanillaEnhanced.displayName = "Vanilla Enhanced"
VanillaEnhanced.mediaPath = "Interface\\AddOns\\" .. VanillaEnhanced.addonName .. "\\media\\"
VanillaEnhanced.modules = VanillaEnhanced.modules or {}

local DEFAULT_SETTINGS = {
    modules = {},
    chatMessagesEnabled = true,
    showChatMessagePrefix = false,
}

local function CopyDefaults(target, source)
    if type(target) ~= "table" then
        target = {}
    end
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            target[key] = CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

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

function VanillaEnhanced:GetSettings()
    VanillaEnhancedSettings = CopyDefaults(VanillaEnhancedSettings, DEFAULT_SETTINGS)
    if type(VanillaEnhancedSettings.modules) ~= "table" then
        VanillaEnhancedSettings.modules = {}
    end
    return VanillaEnhancedSettings
end

function VanillaEnhanced:GetModuleSettings(moduleKey, defaults)
    local settings = self:GetSettings()
    settings.modules[moduleKey] = CopyDefaults(settings.modules[moduleKey], defaults)
    return settings.modules[moduleKey]
end

function VanillaEnhanced:IsModuleEnabled(moduleKey)
    local settings = self:GetModuleSettings(moduleKey, {
        enabled = true,
    })
    return settings.enabled ~= false
end

function VanillaEnhanced:SetModuleEnabled(moduleKey, enabled)
    local settings = self:GetModuleSettings(moduleKey, {
        enabled = true,
    })
    settings.enabled = not not enabled

    if self.RefreshOptions then
        self:RefreshOptions()
    end
end

function VanillaEnhanced:IsChatMessagePrefixEnabled()
    return self:GetSettings().showChatMessagePrefix ~= false
end

function VanillaEnhanced:AreChatMessagesEnabled()
    return self:GetSettings().chatMessagesEnabled ~= false
end

function VanillaEnhanced:PrintMessage(message)
    if not self:AreChatMessagesEnabled() then
        return
    end

    if not (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage) then
        return
    end

    if self:IsChatMessagePrefixEnabled() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200" .. self.displayName .. ":|r " .. message)
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage(message)
end

function VanillaEnhanced:ResetSettings()
    VanillaEnhancedSettings = nil
    self:GetSettings()

    for _, module in pairs(self.modules or {}) do
        if type(module) == "table" then
            if module.ResetSettings then
                module:ResetSettings()
            elseif module.settings ~= nil then
                module.settings = nil
            end

            if module.GetSettings then
                module:GetSettings()
            end
        end
    end

    for moduleKey, module in pairs(self.modules or {}) do
        if type(module) == "table" then
            if module.SetEnabled then
                module:SetEnabled(self:IsModuleEnabled(moduleKey))
            elseif module.Update then
                module:Update()
            end
        end
    end

    if self.RefreshOptions then
        self:RefreshOptions()
    end

    return VanillaEnhancedSettings
end
