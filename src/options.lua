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

local function IsCheckEnabled(check)
    if check.IsEnabled then
        local enabled = check:IsEnabled()
        return enabled ~= false and enabled ~= 0
    end
    return true
end

local function ClickCheck(check)
    if not IsCheckEnabled(check) then
        return
    end

    if check.Click then
        check:Click()
        return
    end

    check:SetChecked(not check:GetChecked())
    local onClick = check.GetScript and check:GetScript("OnClick")
    if onClick then
        onClick(check)
    end
end

local function RegisterCheckClickTarget(check, target)
    check.clickTargets = check.clickTargets or {}
    check.clickTargets[#check.clickTargets + 1] = target
    target:EnableMouse(true)
    target:SetScript("OnClick", function()
        ClickCheck(check)
    end)
end

local function GetRegionWidth(region, fallback)
    local width = region.GetStringWidth and region:GetStringWidth() or nil
    if not width or width <= 0 then
        width = region.GetWidth and region:GetWidth() or fallback
    end
    return width or fallback
end

local function GetRegionHeight(region, fallback)
    local height = region.GetStringHeight and region:GetStringHeight() or nil
    if not height or height <= 0 then
        height = region.GetHeight and region:GetHeight() or fallback
    end
    return height or fallback
end

local function CreateCheckTextClickTarget(check, text)
    if not text or not check.GetParent then
        return
    end

    local target = CreateFrame("Button", nil, check:GetParent())
    local width = GetRegionWidth(text, 1)
    local height = GetRegionHeight(text, 12)
    target:SetPoint("LEFT", text, "LEFT", 0, 0)
    target:SetSize(math.max(1, width), math.max(12, height))
    target:SetFrameLevel((check:GetFrameLevel() or 0) + 1)
    RegisterCheckClickTarget(check, target)
end

local function CreateHelpClickTarget(help, check)
    if not help or not check or not check.GetParent then
        return
    end

    local target = CreateFrame("Button", nil, check:GetParent())
    local width = GetRegionWidth(help, 430)
    local height = GetRegionHeight(help, 12)
    target:SetPoint("TOPLEFT", help, "TOPLEFT", 0, 0)
    target:SetSize(math.max(1, width), math.max(12, height))
    target:SetFrameLevel((check:GetFrameLevel() or 0) + 1)
    RegisterCheckClickTarget(check, target)
end

local function ConfigureCheckText(check, label)
    local text = GetCheckText(check)
    if not text then
        return
    end

    text:SetText(label)
    text:ClearAllPoints()
    text:SetPoint("LEFT", check, "RIGHT", CHECK_TEXT_OFFSET_X, 0)
    CreateCheckTextClickTarget(check, text)
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
    for _, target in ipairs(check.clickTargets or {}) do
        if target.SetEnabled then
            target:SetEnabled(enabled)
        end
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

    if anchor.GetChecked and anchor.SetChecked then
        CreateHelpClickTarget(help, anchor)
    end

    return help
end

local mainPanel = CreatePanel("VanillaEnhancedOptionsPanel", VanillaEnhanced.displayName)
CreateSubtitle(mainPanel, "Turn modules on or off and adjust their options.")

local questsPanel = CreatePanel("VanillaEnhancedQuestsOptionsPanel", "Quests")
questsPanel.parent = VanillaEnhanced.displayName
local questsSubtitle = CreateSubtitle(questsPanel, "Improves the quest tracker, quest log, maps, and tooltips.")
local questsEnabledCheck = CreateModuleEnabledCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsEnabled",
    "quests",
    "Enable",
    questsSubtitle
)
CreateHelpText(
    questsPanel,
    "Turn on the quest tracker, map, and tooltip changes.",
    questsEnabledCheck
)
local questsKeepQuestLogWithMapCheck = CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsKeepQuestLogWithMap",
    "quests",
    "keepQuestLogWithMap",
    "Show quest log with map",
    questsEnabledCheck
)
AnchorBelowHelp(questsKeepQuestLogWithMapCheck, questsEnabledCheck)
CreateHelpText(
    questsPanel,
    "Open the quest log beside the world map when possible.",
    questsKeepQuestLogWithMapCheck
)
local questsEnableQuestTrackerClicksCheck = CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsEnableQuestTrackerClicks",
    "quests",
    "enableQuestTrackerClicks",
    "Clickable quest tracker",
    questsKeepQuestLogWithMapCheck
)
AnchorBelowHelp(questsEnableQuestTrackerClicksCheck, questsKeepQuestLogWithMapCheck)
CreateHelpText(
    questsPanel,
    "Click a watched quest to open it in your quest log.",
    questsEnableQuestTrackerClicksCheck
)
local questsShowMapMarkersCheck = CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsShowMapMarkers",
    "quests",
    "showMapMarkers",
    "Quest markers on maps",
    questsEnableQuestTrackerClicksCheck
)
AnchorBelowHelp(questsShowMapMarkersCheck, questsEnableQuestTrackerClicksCheck)
CreateHelpText(
    questsPanel,
    "Show quest locations on the world map and minimap.",
    questsShowMapMarkersCheck
)
local questsSpreadOverlappingMarkersCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsSpreadOverlappingMarkers",
    "quests",
    "spreadOverlappingMarkers",
    "Separate stacked markers",
    questsShowMapMarkersCheck
), "quests", "showMapMarkers")
AnchorBelowHelp(questsSpreadOverlappingMarkersCheck, questsShowMapMarkersCheck)
CreateHelpText(
    questsPanel,
    "Spread nearby world map markers while you hover one.",
    questsSpreadOverlappingMarkersCheck
)
local questsShowCompletedMapObjectivesCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsShowCompletedMapObjectives",
    "quests",
    "showCompletedMapObjectives",
    "Completed objectives on maps",
    questsSpreadOverlappingMarkersCheck
), "quests", "showMapMarkers")
AnchorBelowHelp(questsShowCompletedMapObjectivesCheck, questsSpreadOverlappingMarkersCheck)
CreateHelpText(
    questsPanel,
    "Keep finished objective locations visible. Turn-in locations still appear.",
    questsShowCompletedMapObjectivesCheck
)
local questsShowCompletedTooltipObjectivesCheck = CreateModuleSettingCheck(
    questsPanel,
    "VanillaEnhancedOptionsQuestsShowCompletedTooltipObjectives",
    "quests",
    "showCompletedTooltipObjectives",
    "Completed objectives in tooltips",
    questsShowCompletedMapObjectivesCheck
)
AnchorBelowHelp(questsShowCompletedTooltipObjectivesCheck, questsShowCompletedMapObjectivesCheck)
CreateHelpText(
    questsPanel,
    "Keep tooltip hints for objectives you have already finished.",
    questsShowCompletedTooltipObjectivesCheck
)

local targetThreatPanel = CreatePanel("VanillaEnhancedTargetThreatOptionsPanel", "Target threat")
targetThreatPanel.parent = VanillaEnhanced.displayName
local targetThreatSubtitle = CreateSubtitle(targetThreatPanel, "Shows your threat percentage on the target frame.")
local targetThreatEnabledCheck = CreateModuleEnabledCheck(
    targetThreatPanel,
    "VanillaEnhancedOptionsTargetThreatEnabled",
    "target-threat",
    "Enable",
    targetThreatSubtitle
)
CreateHelpText(
    targetThreatPanel,
    "Show your threat percentage near the target frame.",
    targetThreatEnabledCheck
)
local targetThreatAlwaysShowCheck = CreateModuleSettingCheck(
    targetThreatPanel,
    "VanillaEnhancedOptionsTargetThreatAlwaysShow",
    "target-threat",
    "alwaysShow",
    "Show out of combat",
    targetThreatEnabledCheck
)
AnchorBelowHelp(targetThreatAlwaysShowCheck, targetThreatEnabledCheck)
CreateHelpText(
    targetThreatPanel,
    "Keep the threat text visible when you have a target, even outside combat.",
    targetThreatAlwaysShowCheck
)

local bagsPanel = CreatePanel("VanillaEnhancedBagsOptionsPanel", "Bags")
bagsPanel.parent = VanillaEnhanced.displayName
local bagsSubtitle = CreateSubtitle(bagsPanel, "Adds bag sorting options.")
local bagsSortEnabledCheck = CreateModuleSettingCheck(
    bagsPanel,
    "VanillaEnhancedOptionsBagsSortEnabled",
    "bags",
    "sortEnabled",
    "Enable sorting",
    bagsSubtitle
)
CreateHelpText(
    bagsPanel,
    "Turn on bag sorting.",
    bagsSortEnabledCheck
)
local bagsShowSortButtonCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    bagsPanel,
    "VanillaEnhancedOptionsBagsShowSortButton",
    "bags",
    "showSortButton",
    "Sort button",
    bagsSortEnabledCheck
), "bags", "sortEnabled")
AnchorBelowHelp(bagsShowSortButtonCheck, bagsSortEnabledCheck)
CreateHelpText(
    bagsPanel,
    "Show a sort button near the backpack.",
    bagsShowSortButtonCheck
)
local bagsAutoSortAfterLootCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    bagsPanel,
    "VanillaEnhancedOptionsBagsAutoSortAfterLoot",
    "bags",
    "autoSortAfterLoot",
    "Sort after looting",
    bagsShowSortButtonCheck
), "bags", "sortEnabled")
AnchorBelowHelp(bagsAutoSortAfterLootCheck, bagsShowSortButtonCheck)
CreateHelpText(
    bagsPanel,
    "Sort your bags after the loot window closes.",
    bagsAutoSortAfterLootCheck
)
local bagsAutoSortOnOpenCheck = SetSettingCheckEnabledWhen(CreateModuleSettingCheck(
    bagsPanel,
    "VanillaEnhancedOptionsBagsAutoSortOnOpen",
    "bags",
    "autoSortOnOpen",
    "Sort when bags open",
    bagsAutoSortAfterLootCheck
), "bags", "sortEnabled")
AnchorBelowHelp(bagsAutoSortOnOpenCheck, bagsAutoSortAfterLootCheck)
CreateHelpText(
    bagsPanel,
    "Sort your bags when you open them.",
    bagsAutoSortOnOpenCheck
)
local bagsSortOrderDropdown = CreateModuleDropdown(
    bagsPanel,
    "VanillaEnhancedOptionsBagsSortOrder",
    "bags",
    "sortOrder",
    "Sort by",
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
    "Choose how items are ordered when the addon sorts your bags.",
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
questsPanel:SetScript("OnShow", RefreshOnShow)
targetThreatPanel:SetScript("OnShow", RefreshOnShow)
bagsPanel:SetScript("OnShow", RefreshOnShow)

local function RegisterInterfaceOptions()
    InterfaceOptions_AddCategory(mainPanel)
    InterfaceOptions_AddCategory(questsPanel)
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
        local questOk, questsCategory = pcall(
            Settings.RegisterCanvasLayoutSubcategory,
            mainCategory,
            questsPanel,
            questsPanel.name
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
            VanillaEnhanced.optionsCategories.quests = questsCategory
            VanillaEnhanced.optionsCategories.targetThreat = targetThreatCategory
            VanillaEnhanced.optionsCategories.bags = bagsCategory
            return
        end
    end

    local questsCategory = Settings.RegisterCanvasLayoutCategory(questsPanel, questsPanel.name)
    local targetThreatCategory = Settings.RegisterCanvasLayoutCategory(targetThreatPanel, targetThreatPanel.name)
    local bagsCategory = Settings.RegisterCanvasLayoutCategory(bagsPanel, bagsPanel.name)
    Settings.RegisterAddOnCategory(questsCategory)
    Settings.RegisterAddOnCategory(targetThreatCategory)
    Settings.RegisterAddOnCategory(bagsCategory)

    VanillaEnhanced.optionsCategories.quests = questsCategory
    VanillaEnhanced.optionsCategories.targetThreat = targetThreatCategory
    VanillaEnhanced.optionsCategories.bags = bagsCategory
end

if type(InterfaceOptions_AddCategory) == "function" then
    RegisterInterfaceOptions()
elseif Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    RegisterSettingsOptions()
end
