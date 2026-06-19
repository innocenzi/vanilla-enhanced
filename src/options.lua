local VanillaEnhanced = _G.VanillaEnhanced

local moduleChecks = {}
local settingChecks = {}
local dropdowns = {}
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

local function IsSettingEnabled(moduleKey, settingKey)
    local settings = GetModuleOptionSettings(moduleKey)
    return settings[settingKey] ~= false
end

local function ApplyModuleDropdownSetting(moduleKey, settingKey, value)
    local settings = GetModuleOptionSettings(moduleKey)
    settings[settingKey] = value

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

local function SetSettingCheckEnabledWhen(check, moduleKey, settingKey)
    check.enabledWhen = function()
        return IsSettingEnabled(moduleKey, settingKey)
    end
    return check
end

local function CreateModuleDropdown(panel, name, moduleKey, settingKey, label, options, anchor)
    local labelText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    labelText:SetPoint("TOPLEFT", anchor.optionHelpBottomAnchor or anchor, "BOTTOMLEFT", 0, -18)
    labelText:SetText(label)

    local dropdown = CreateFrame("Frame", name, panel, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", -16, -4)
    dropdown.moduleKey = moduleKey
    dropdown.settingKey = settingKey
    dropdown.options = options
    dropdown.labelText = labelText
    dropdown.enabledWhen = nil
    dropdown.optionHelpTextAnchor = labelText
    dropdown.optionHelpLeftOffset = 0
    dropdown.optionHelpNextOffset = -22

    local helpPointAnchor = CreateFrame("Frame", nil, panel)
    helpPointAnchor:SetSize(1, 1)
    helpPointAnchor:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 16, 0)
    dropdown.optionHelpPointAnchor = helpPointAnchor
    dropdown.optionHelpBottomAnchor = helpPointAnchor

    UIDropDownMenu_SetWidth(dropdown, 150)
    UIDropDownMenu_Initialize(dropdown, function(self)
        local settings = GetModuleOptionSettings(self.moduleKey)
        local selected = settings[self.settingKey]

        for _, option in ipairs(self.options) do
            local optionValue = option.value
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = optionValue
            info.checked = selected == optionValue
            info.func = function()
                ApplyModuleDropdownSetting(self.moduleKey, self.settingKey, optionValue)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    table.insert(dropdowns, dropdown)
    return dropdown
end

local function CreateHelpText(panel, text, anchor)
    local help = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    local textAnchor = anchor.optionHelpTextAnchor or GetCheckText(anchor) or anchor
    local checkWidth = anchor.GetWidth and anchor:GetWidth() or 0
    local textLeftOffset = anchor.optionHelpLeftOffset
        or (checkWidth > 0 and checkWidth + CHECK_TEXT_OFFSET_X or CHECK_TEXT_LEFT_FALLBACK)
    local bottomAnchor = CreateFrame("Frame", nil, panel)
    local nextOffset = anchor.optionHelpNextOffset or 0

    help:SetPoint("TOPLEFT", anchor.optionHelpPointAnchor or anchor.optionHelpBottomAnchor or textAnchor, "BOTTOMLEFT", 0, -5)
    help:SetWidth(430)
    help:SetJustifyH("LEFT")
    help:SetText(text)
    bottomAnchor:SetSize(1, 1)
    bottomAnchor:SetPoint("TOPLEFT", help, "BOTTOMLEFT", -textLeftOffset, nextOffset)
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

local bagsPanel = CreatePanel("VanillaEnhancedBagsOptionsPanel", "Bags")
bagsPanel.parent = VanillaEnhanced.displayName
local bagsSubtitle = CreateSubtitle(bagsPanel, "Provides inventory improvements.")
local bagsSortEnabledCheck = CreateModuleSettingCheck(
    bagsPanel,
    "VanillaEnhancedOptionsBagsSortEnabled",
    "bags",
    "sortEnabled",
    "Enable sort",
    bagsSubtitle
)
CreateHelpText(
    bagsPanel,
    "Enable bag sorting features.",
    bagsSortEnabledCheck
)
local bagsShowSortButtonCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    bagsPanel,
    "VanillaEnhancedOptionsBagsShowSortButton",
    "bags",
    "showSortButton",
    "Show sort button",
    bagsSortEnabledCheck
), "bags", "sortEnabled")
AnchorBelowHelp(bagsShowSortButtonCheck, bagsSortEnabledCheck)
CreateHelpText(
    bagsPanel,
    "Shows the sort button below the backpack.",
    bagsShowSortButtonCheck
)
local bagsAutoSortAfterLootCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    bagsPanel,
    "VanillaEnhancedOptionsBagsAutoSortAfterLoot",
    "bags",
    "autoSortAfterLoot",
    "Auto sort after looting",
    bagsShowSortButtonCheck
), "bags", "sortEnabled")
AnchorBelowHelp(bagsAutoSortAfterLootCheck, bagsShowSortButtonCheck)
CreateHelpText(
    bagsPanel,
    "Starts sorting after loot is closed.",
    bagsAutoSortAfterLootCheck
)
local bagsAutoSortOnOpenCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    bagsPanel,
    "VanillaEnhancedOptionsBagsAutoSortOnOpen",
    "bags",
    "autoSortOnOpen",
    "Auto sort when bags open",
    bagsAutoSortAfterLootCheck
), "bags", "sortEnabled")
AnchorBelowHelp(bagsAutoSortOnOpenCheck, bagsAutoSortAfterLootCheck)
CreateHelpText(
    bagsPanel,
    "Starts sorting when your bags are opened.",
    bagsAutoSortOnOpenCheck
)
local bagsSortOrderDropdown = CreateModuleDropdown(
    bagsPanel,
    "VanillaEnhancedOptionsBagsSortOrder",
    "bags",
    "sortOrder",
    "Sort order",
    {
        { value = "category", label = "Category" },
        { value = "quality", label = "Quality" },
        { value = "name", label = "Name" },
    },
    bagsAutoSortOnOpenCheck
)
bagsSortOrderDropdown.enabledWhen = function()
    return IsSettingEnabled("bags", "sortEnabled")
end
CreateHelpText(
    bagsPanel,
    "Controls how the manual sorter orders items when native bag sorting is unavailable.",
    bagsSortOrderDropdown
)

function VanillaEnhanced:RefreshOptions()
    for moduleKey, check in pairs(moduleChecks) do
        check:SetChecked(self:IsModuleEnabled(moduleKey))
    end
    for _, check in ipairs(settingChecks) do
        local settings = GetModuleOptionSettings(check.moduleKey)
        local enabled = self:IsModuleEnabled(check.moduleKey)
        if check.enabledWhen then
            enabled = enabled and check.enabledWhen()
        end
        check:SetChecked(settings[check.settingKey] == true)
        SetCheckEnabled(check, enabled)
    end
    for _, dropdown in ipairs(dropdowns) do
        local settings = GetModuleOptionSettings(dropdown.moduleKey)
        local selected = settings[dropdown.settingKey]
        local selectedLabel = selected
        local enabled = self:IsModuleEnabled(dropdown.moduleKey)
        if dropdown.enabledWhen then
            enabled = enabled and dropdown.enabledWhen()
        end

        for _, option in ipairs(dropdown.options) do
            if option.value == selected then
                selectedLabel = option.label
                break
            end
        end

        UIDropDownMenu_SetText(dropdown, selectedLabel)
        if enabled then
            UIDropDownMenu_EnableDropDown(dropdown)
            if dropdown.labelText then
                dropdown.labelText:SetTextColor(1, 1, 1)
            end
        else
            UIDropDownMenu_DisableDropDown(dropdown)
            if dropdown.labelText then
                dropdown.labelText:SetTextColor(0.5, 0.5, 0.5)
            end
        end
    end
end

local function RefreshOnShow()
    VanillaEnhanced:RefreshOptions()
end

mainPanel:SetScript("OnShow", RefreshOnShow)
questMapPanel:SetScript("OnShow", RefreshOnShow)
targetThreatPanel:SetScript("OnShow", RefreshOnShow)
bagsPanel:SetScript("OnShow", RefreshOnShow)

local function RegisterLegacyOptions()
    InterfaceOptions_AddCategory(mainPanel)
    InterfaceOptions_AddCategory(questMapPanel)
    InterfaceOptions_AddCategory(targetThreatPanel)
    InterfaceOptions_AddCategory(bagsPanel)
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
        local bagsOk, bagsCategory = pcall(
            Settings.RegisterCanvasLayoutSubcategory,
            mainCategory,
            bagsPanel,
            bagsPanel.name
        )

        if questOk and targetOk and bagsOk then
            VanillaEnhanced.optionsCategories.questMap = questMapCategory
            VanillaEnhanced.optionsCategories.targetThreat = targetThreatCategory
            VanillaEnhanced.optionsCategories.bags = bagsCategory
            return
        end
    end

    local questMapCategory = Settings.RegisterCanvasLayoutCategory(questMapPanel, questMapPanel.name)
    local targetThreatCategory = Settings.RegisterCanvasLayoutCategory(targetThreatPanel, targetThreatPanel.name)
    local bagsCategory = Settings.RegisterCanvasLayoutCategory(bagsPanel, bagsPanel.name)
    Settings.RegisterAddOnCategory(questMapCategory)
    Settings.RegisterAddOnCategory(targetThreatCategory)
    Settings.RegisterAddOnCategory(bagsCategory)

    VanillaEnhanced.optionsCategories.questMap = questMapCategory
    VanillaEnhanced.optionsCategories.targetThreat = targetThreatCategory
    VanillaEnhanced.optionsCategories.bags = bagsCategory
end

if type(InterfaceOptions_AddCategory) == "function" then
    RegisterLegacyOptions()
elseif Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    RegisterSettingsOptions()
end
