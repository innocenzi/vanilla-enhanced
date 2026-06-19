local VanillaEnhanced = _G.VanillaEnhanced

local moduleChecks = {}
local settingChecks = {}

local function GetCheckText(check)
    return check.Text or _G[check:GetName() .. "Text"]
end

local function ApplyModuleEnabled(moduleKey, enabled)
    local module = VanillaEnhanced:GetModule(moduleKey)
    if module and module.SetEnabled then
        module:SetEnabled(enabled)
    else
        VanillaEnhanced:SetModuleEnabled(moduleKey, enabled)
    end
end

local function GetModuleOptionSettings(moduleKey)
    local module = VanillaEnhanced:GetModule(moduleKey)
    if module and module.GetSettings then
        return module:GetSettings()
    end
    return VanillaEnhanced:GetModuleSettings(moduleKey, {
        enabled = true,
    })
end

local function ApplyModuleSetting(moduleKey, settingKey, value)
    local settings = GetModuleOptionSettings(moduleKey)
    settings[settingKey] = not not value

    local module = VanillaEnhanced:GetModule(moduleKey)
    if module and module.Update then
        module:Update()
    end

    if VanillaEnhanced.RefreshOptions then
        VanillaEnhanced:RefreshOptions()
    end
end

local function SetCheckEnabled(check, enabled)
    if check.SetEnabled then
        check:SetEnabled(enabled)
    elseif enabled and check.Enable then
        check:Enable()
    elseif check.Disable then
        check:Disable()
    end
end

local function CreatePanel(name, titleText)
    local panel = CreateFrame("Frame", name, UIParent)
    panel.name = titleText

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(titleText)
    panel.title = title

    return panel
end

local function CreateSubtitle(panel, text)
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText(text)
    return subtitle
end

local function CreateModuleEnabledCheck(panel, name, moduleKey, label, anchor)
    local check = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    check.moduleKey = moduleKey

    local text = GetCheckText(check)
    if text then
        text:SetText(label)
    end

    check:SetScript("OnClick", function(self)
        ApplyModuleEnabled(self.moduleKey, self:GetChecked())
    end)

    moduleChecks[moduleKey] = check
    return check
end

local function CreateModuleSettingCheck(panel, name, moduleKey, settingKey, label, anchor)
    local check = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    check.moduleKey = moduleKey
    check.settingKey = settingKey

    local text = GetCheckText(check)
    if text then
        text:SetText(label)
    end

    check:SetScript("OnClick", function(self)
        ApplyModuleSetting(self.moduleKey, self.settingKey, self:GetChecked())
    end)

    table.insert(settingChecks, check)
    return check
end

local mainPanel = CreatePanel("VanillaEnhancedOptionsPanel", VanillaEnhanced.displayName)
CreateSubtitle(mainPanel, "Select a module from the sidebar.")

local questMapPanel = CreatePanel("VanillaEnhancedQuestMapOptionsPanel", "Quest Map")
questMapPanel.parent = VanillaEnhanced.displayName
local questMapSubtitle = CreateSubtitle(questMapPanel, "Module settings")
CreateModuleEnabledCheck(
    questMapPanel,
    "VanillaEnhancedOptionsQuestMapEnabled",
    "quest-map",
    "Enable Quest Map",
    questMapSubtitle
)

local targetThreatPanel = CreatePanel("VanillaEnhancedTargetThreatOptionsPanel", "Target Threat")
targetThreatPanel.parent = VanillaEnhanced.displayName
local targetThreatSubtitle = CreateSubtitle(targetThreatPanel, "Module settings")
local targetThreatEnabledCheck = CreateModuleEnabledCheck(
    targetThreatPanel,
    "VanillaEnhancedOptionsTargetThreatEnabled",
    "target-threat",
    "Enable Target Threat",
    targetThreatSubtitle
)
CreateModuleSettingCheck(
    targetThreatPanel,
    "VanillaEnhancedOptionsTargetThreatAlwaysShow",
    "target-threat",
    "alwaysShow",
    "Show when not in combat",
    targetThreatEnabledCheck
)

function VanillaEnhanced:RefreshOptions()
    for moduleKey, check in pairs(moduleChecks) do
        check:SetChecked(self:IsModuleEnabled(moduleKey))
    end
    for _, check in ipairs(settingChecks) do
        local settings = GetModuleOptionSettings(check.moduleKey)
        check:SetChecked(settings[check.settingKey] == true)
        SetCheckEnabled(check, self:IsModuleEnabled(check.moduleKey))
    end
end

local function RefreshOnShow()
    VanillaEnhanced:RefreshOptions()
end

mainPanel:SetScript("OnShow", RefreshOnShow)
questMapPanel:SetScript("OnShow", RefreshOnShow)
targetThreatPanel:SetScript("OnShow", RefreshOnShow)

local function RegisterLegacyOptions()
    InterfaceOptions_AddCategory(mainPanel)
    InterfaceOptions_AddCategory(questMapPanel)
    InterfaceOptions_AddCategory(targetThreatPanel)
end

local function RegisterSettingsOptions()
    local mainCategory = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)
    Settings.RegisterAddOnCategory(mainCategory)

    VanillaEnhanced.optionsCategories = {
        main = mainCategory,
    }

    if type(Settings.RegisterCanvasLayoutSubcategory) == "function" then
        local questOk, questMapCategory = pcall(
            Settings.RegisterCanvasLayoutSubcategory,
            mainCategory,
            questMapPanel,
            questMapPanel.name
        )
        local targetOk, targetThreatCategory = pcall(
            Settings.RegisterCanvasLayoutSubcategory,
            mainCategory,
            targetThreatPanel,
            targetThreatPanel.name
        )

        if questOk and targetOk then
            VanillaEnhanced.optionsCategories.questMap = questMapCategory
            VanillaEnhanced.optionsCategories.targetThreat = targetThreatCategory
            return
        end
    end

    local questMapCategory = Settings.RegisterCanvasLayoutCategory(questMapPanel, questMapPanel.name)
    local targetThreatCategory = Settings.RegisterCanvasLayoutCategory(targetThreatPanel, targetThreatPanel.name)
    Settings.RegisterAddOnCategory(questMapCategory)
    Settings.RegisterAddOnCategory(targetThreatCategory)

    VanillaEnhanced.optionsCategories.questMap = questMapCategory
    VanillaEnhanced.optionsCategories.targetThreat = targetThreatCategory
end

if type(InterfaceOptions_AddCategory) == "function" then
    RegisterLegacyOptions()
elseif Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    RegisterSettingsOptions()
end
