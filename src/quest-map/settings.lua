local VanillaEnhanced = _G.VanillaEnhanced
local QuestMap = VanillaEnhanced:GetModule("quest-map")

local defaults = {
    enabled = true,
    scale = 1,
    opacity = 1,
    showCompletedObjectives = true,
}

local function CopyDefaults(target, source)
    if type(target) ~= "table" then
        target = {}
    end
    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = value
        end
    end
    return target
end

function QuestMap:GetSettings()
    VanillaEnhancedSettings = VanillaEnhancedSettings or {}
    VanillaEnhancedSettings.modules = VanillaEnhancedSettings.modules or {}
    VanillaEnhancedSettings.modules["quest-map"] = CopyDefaults(VanillaEnhancedSettings.modules["quest-map"], defaults)
    return VanillaEnhancedSettings.modules["quest-map"]
end
