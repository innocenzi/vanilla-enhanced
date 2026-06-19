local addonName = ...

local VanillaEnhanced = _G.VanillaEnhanced or {}
_G.VanillaEnhanced = VanillaEnhanced

VanillaEnhanced.addonName = addonName or VanillaEnhanced.addonName or "VanillaEnhanced"
VanillaEnhanced.displayName = "Vanilla Enhanced"
VanillaEnhanced.mediaPath = "Interface\\AddOns\\" .. VanillaEnhanced.addonName .. "\\media\\"
VanillaEnhanced.modules = VanillaEnhanced.modules or {}

local function CopyDefaults(target, source)
    if type(target) ~= "table" then
        target = {}
    end
    for key, value in pairs(source or {}) do
        if target[key] == nil then
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
    VanillaEnhancedSettings = CopyDefaults(VanillaEnhancedSettings, {
        modules = {},
    })
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
