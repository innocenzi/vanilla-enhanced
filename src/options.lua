local VanillaEnhanced = _G.VanillaEnhanced

local moduleChecks = {}
local settingChecks = {}
local OPTION_WITH_HELP_OFFSET = -15
local CHECK_TEXT_OFFSET_X = 3
local CHECK_TEXT_LEFT_FALLBACK = 27

local function GetCheckText(check)
    return check.Text or _G[check:GetName() .. "Text"]
end

local function ConfigureCheckText(check, label)
    local text = GetCheckText(check)
    if not text then
        return
    end

    text:SetText(label)
    text:ClearAllPoints()
    text:SetPoint("LEFT", check, "RIGHT", CHECK_TEXT_OFFSET_X, 0)
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
    subtitle:SetWidth(430)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(text)
    return subtitle
end

local function AnchorBelowHelp(check, anchor)
    local bottomAnchor = anchor.optionHelpBottomAnchor or anchor

    check:ClearAllPoints()
    check:SetPoint("TOPLEFT", bottomAnchor, "BOTTOMLEFT", 0, OPTION_WITH_HELP_OFFSET)
end

local function CreateModuleEnabledCheck(panel, name, moduleKey, label, anchor)
    local check = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    check.moduleKey = moduleKey

    ConfigureCheckText(check, label)

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

    ConfigureCheckText(check, label)

    check:SetScript("OnClick", function(self)
        ApplyModuleSetting(self.moduleKey, self.settingKey, self:GetChecked())
    end)

    table.insert(settingChecks, check)
    return check
end

local function CreateHelpText(panel, text, anchor)
    local help = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    local textAnchor = GetCheckText(anchor) or anchor
    local checkWidth = anchor.GetWidth and anchor:GetWidth() or 0
    local textLeftOffset = checkWidth > 0 and checkWidth + CHECK_TEXT_OFFSET_X or CHECK_TEXT_LEFT_FALLBACK
    local bottomAnchor = CreateFrame("Frame", nil, panel)

    help:SetPoint("TOPLEFT", textAnchor, "BOTTOMLEFT", 0, -5)
    help:SetWidth(430)
    help:SetJustifyH("LEFT")
    help:SetText(text)
    bottomAnchor:SetSize(1, 1)
    bottomAnchor:SetPoint("TOPLEFT", help, "BOTTOMLEFT", -textLeftOffset, 0)
    anchor.optionHelpBottomAnchor = bottomAnchor

    return help
end

local mainPanel = CreatePanel("VanillaEnhancedOptionsPanel", VanillaEnhanced.displayName)
CreateSubtitle(mainPanel, "Choose which Vanilla Enhanced modules are active and tune how they behave.")

local questMapPanel = CreatePanel("VanillaEnhancedQuestMapOptionsPanel", "Quest Map")
questMapPanel.parent = VanillaEnhanced.displayName
local questMapSubtitle = CreateSubtitle(questMapPanel, "Shows quest objective locations on maps and adds quest hints to relevant unit tooltips.")
local questMapEnabledCheck = CreateModuleEnabledCheck(
    questMapPanel,
    "VanillaEnhancedOptionsQuestMapEnabled",
    "quest-map",
    "Enable Quest Map",
    questMapSubtitle
)
CreateHelpText(
    questMapPanel,
    "Adds numbered world-map markers and nearby minimap pins for active quests.",
    questMapEnabledCheck
)
local questMapKeepQuestLogWithMapCheck = CreateModuleSettingCheck(
    questMapPanel,
    "VanillaEnhancedOptionsQuestMapKeepQuestLogWithMap",
    "quest-map",
    "keepQuestLogWithMap",
    "Keep quest log open with map",
    questMapEnabledCheck
)
AnchorBelowHelp(questMapKeepQuestLogWithMapCheck, questMapEnabledCheck)
CreateHelpText(
    questMapPanel,
    "Keeps the quest log visible beside the world map when both can be shown.",
    questMapKeepQuestLogWithMapCheck
)
local questMapSpreadOverlappingMarkersCheck = CreateModuleSettingCheck(
    questMapPanel,
    "VanillaEnhancedOptionsQuestMapSpreadOverlappingMarkers",
    "quest-map",
    "spreadOverlappingMarkers",
    "Spread overlapping markers on hover",
    questMapKeepQuestLogWithMapCheck
)
AnchorBelowHelp(questMapSpreadOverlappingMarkersCheck, questMapKeepQuestLogWithMapCheck)
CreateHelpText(
    questMapPanel,
    "Temporarily fans out nearby world-map markers while hovering one of them.",
    questMapSpreadOverlappingMarkersCheck
)
local questMapShowCompletedMapObjectivesCheck = CreateModuleSettingCheck(
    questMapPanel,
    "VanillaEnhancedOptionsQuestMapShowCompletedMapObjectives",
    "quest-map",
    "showCompletedMapObjectives",
    "Show completed objectives on maps",
    questMapSpreadOverlappingMarkersCheck
)
AnchorBelowHelp(questMapShowCompletedMapObjectivesCheck, questMapSpreadOverlappingMarkersCheck)
CreateHelpText(
    questMapPanel,
    "When unchecked, completed objective pins are hidden from the world map and minimap. Completed quests still show turn-in locations.",
    questMapShowCompletedMapObjectivesCheck
)
local questMapShowCompletedTooltipObjectivesCheck = CreateModuleSettingCheck(
    questMapPanel,
    "VanillaEnhancedOptionsQuestMapShowCompletedTooltipObjectives",
    "quest-map",
    "showCompletedTooltipObjectives",
    "Show completed objectives in tooltips",
    questMapShowCompletedMapObjectivesCheck
)
AnchorBelowHelp(questMapShowCompletedTooltipObjectivesCheck, questMapShowCompletedMapObjectivesCheck)
CreateHelpText(
    questMapPanel,
    "When unchecked, unit tooltips only show quest hints for objectives that still need progress.",
    questMapShowCompletedTooltipObjectivesCheck
)

local targetThreatPanel = CreatePanel("VanillaEnhancedTargetThreatOptionsPanel", "Target Threat")
targetThreatPanel.parent = VanillaEnhanced.displayName
local targetThreatSubtitle = CreateSubtitle(targetThreatPanel, "Shows your current threat percentage on the target frame.")
local targetThreatEnabledCheck = CreateModuleEnabledCheck(
    targetThreatPanel,
    "VanillaEnhancedOptionsTargetThreatEnabled",
    "target-threat",
    "Enable Target Threat",
    targetThreatSubtitle
)
CreateHelpText(
    targetThreatPanel,
    "Adds a compact threat percentage near your current target.",
    targetThreatEnabledCheck
)
local targetThreatAlwaysShowCheck = CreateModuleSettingCheck(
    targetThreatPanel,
    "VanillaEnhancedOptionsTargetThreatAlwaysShow",
    "target-threat",
    "alwaysShow",
    "Show when not in combat",
    targetThreatEnabledCheck
)
AnchorBelowHelp(targetThreatAlwaysShowCheck, targetThreatEnabledCheck)
CreateHelpText(
    targetThreatPanel,
    "Keeps the threat widget visible outside combat when you have a target.",
    targetThreatAlwaysShowCheck
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
